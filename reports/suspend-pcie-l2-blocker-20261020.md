# suspend 待不住的真根因：`qcom-pcie` L2 进入超时 ⇒ WiFi 重探 ⇒ 立即唤醒（2026-10-20）

- **结论**：本机 suspend **只能维持约 1.4 秒**，原因是 `qcom-pcie` 进 L2 超时导致 PCIe link 重拉，
  把 WiFi（ath12k）重新上电/重探，随即触发唤醒源退出挂起。
- **影响**：**T9 掉电率测量在解决此问题前无法进行** —— 挂 1.4 秒的能耗≈0，任何 `%/h` 都是噪声。
- **排除了**：RTC 唤醒能力、s2idle 特有、人工按键残留。

## 1. 数字结论

| 实验 | mem_sleep | 挂起时长 | 结论 |
|---|---|---|---|
| 人工按键唤醒（17:00） | s2idle | 1.5 s 后已 exit，人按键只是恢复 SSH | **不是真挂起 12 分钟** |
| `rtcwake -m mem -s 30` | s2idle | 1.4 s | RTC 未参与，是被别的东西弹出 |
| 直写 `wakealarm` | s2idle | 1.47 s | 同上 |
| 切 `deep` 后 `echo mem` | **deep** | **1.43 s** | **deep 也一样 ⇒ 不是 s2idle 特有** |
| 卸载 ath12k 后 | deep | 3–4 s | 内核在 resume 时**自己重探 WiFi** |

**四次 suspend 全部同型**（424.90s / 789.39s / 822.30s / 991.37s），确定性复现，非偶发。

## 2. 完整因果链（dmesg 原文）

```
[991.340862] PM: suspend entry (deep)
[991.358772] wlan0: deauthenticating ... (Reason: 3=DEAUTH_LEAVING)
[991.369880] dwc3-qcom a600000.usb: request ... was not queued to ep3in
[991.370154] dwc3-qcom a600000.usb: port-1 HS-PHY not in L2          ← USB PHY 进不了 L2
[991.608302] qcom-pcie 1c00000.pcie: Timeout waiting for L2 entry! LTSSM: 0x12   ★根因
[991.611976] Disabling non-boot CPUs ...
[991.612362] psci: CPU7 killed (polled 0 ms)                          ← 刚关完 CPU
[991.616875] Enabling non-boot CPUs ...                               ← 0.004 s 后立刻恢复
[991.617399] CPU1 is up
[991.930234] qcom-pcie 1c00000.pcie: PCIe Gen.3 x2 link up            ← link 重拉
[992.1  ]    mhi mhi0: Requested to power ON                          ← WiFi 被重新上电
[992.2  ]    ath12k_wifi7_pci 0000:01:00.0: chip_id 0x2 ...           ← WiFi 重探
[992.2  ]    hwmon hwmon57: PM: parent phy0 should not be sleeping    ← 睡眠中的 parent 被访问
[992.28 ]    elogind: Power key pressed short.                        ← 唤醒事件
[992.768653] PM: suspend exit
```

关键点：**CPU 刚 `killed` 完 4 ms 内就被 `Enabling non-boot CPUs` 拉回来** —— 说明
`suspend_devices_and_enter()` 在 platform 阶段（PCIe 的 `.suspend_noirq`）就返回了错误，
根本没进到「真正睡下去」那一步。

## 3. 为什么 WiFi 会「卸载了还回来」

`modprobe -r ath12k` 只卸载**驱动模块**，不改变 **PCIe 拓扑**。
resume 时 PCIe link 重拉 ⇒ 总线重扫 ⇒ `ath12k_wifi7_pci` 通过 modalias 自动 probe 回来
（dmesg `1103.83` 有完整初始化日志）。

⇒ 想用「卸载 WiFi」做对照是**无效**的。有效的对照只能是：
- 内核参数/设备树层面**禁用 PCIe 端点**（`pcie_port_pm=off` 或 DT `status = "disabled"`），或
- 修好 `qcom-pcie` 的 L2 进入逻辑。

## 4. 两个可疑的次生问题（待独立处理）

### 4.1 `hwmon: parent phy0 should not be sleeping`
`ath12k` 的 hwmon 在 resume 阶段访问处于睡眠态的 phy 父设备。这是**驱动 bug**，
即使 PCIe L2 修好也可能留下问题。

### 4.2 `amba *.tpda/*.tmc: Unbalanced pm_runtime_enable!`
coresight 的 TPDA/TMC 设备有 pm_runtime 引用不平衡（4 个设备）。
README 里的 `tmc`/`tpda` 是我们刚加载的 coresight 栈带来的 —— 这会**干扰 suspend**
（引用计数不归零 ⇒ 相关设备拒绝进入低功耗）。

**⚠️ 这条可能是本轮我引入的**：先加载 `modprobe coresight` 再测 suspend，
TPDA/TMC 的 pm_runtime 不平衡会让 suspend 更难成功。
**下一轮测 suspend 前应先不加载 coresight**，或先修这个不平衡。

## 5. 下一步（按代价排序）

| # | 动作 | 代价 | 判据 |
|---|---|---|---|
| 1 | **不加载 coresight 重测 suspend**（排除 §4.2 干扰） | 5 min | 挂起时长 > 60 s ? |
| 2 | 内核参数 `pcie_port_pm=off` 或 `pcie_aspm=off` 重测 | 一次重启 | 若待住 ⇒ 确认 PCIe L2 是唯一原因 |
| 3 | 修 `qcom-pcie` L2（DT 加 `qcom,l1ss-supported` 等，参考上游 sm8750） | 需构建 | LTSSM 不再 timeout |
| 4 | 修 ath12k hwmon parent 睡眠访问 | 驱动改动 | 无 `should not be sleeping` |

**在 1–2 有结果前，不得记录任何掉电率数字。**

## 6. 关联

- `reports/t9-rtc-wake-limit-20261020.md`（本报告更正了它对「12 分钟挂起」的误判）
- `reports/vk129-abi-fix-verified-20261020.md` §3.5
- `scripts/suspend-drain-rate.sh`、`TASKS/README.md` T9
