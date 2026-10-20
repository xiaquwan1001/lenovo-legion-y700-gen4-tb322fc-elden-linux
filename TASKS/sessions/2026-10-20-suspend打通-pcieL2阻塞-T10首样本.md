# 2026-10-20 suspend 线打通 + T9 被 PCIe L2 阻塞 + T10 首样本

- **日期**：2026-10-20
- **主题**：① vk128/vk129「suspend 启动即死」根因取证与实证修复；② suspend 能力固化；③ T9 掉电率被新根因阻塞；④ T10（N5b 相机扩样）首轮有效样本
- **结论**：**suspend 可用（s2idle + deep）**；但**待不住约 1.4 s**，真因是 `qcom-pcie` L2 进入超时 → WiFi 重探 → 立即唤醒；T9 因此无法测掉电率。T10 只拿到 n=1 有效样本。
- **证据指针**：`reports/suspend-panic-rootcause-20261020.md`、`reports/vk129-abi-fix-verified-20261020.md`、`reports/kernel-abi-variants-20261020.md`、`reports/suspend-pcie-l2-blocker-20261020.md`、`reports/artifacts/vk129-*.txt`
- **★SSOT 待并入**：`TASKS/README.md` 的 T8（已闭环）/ T9（被阻塞）/ T10（n=1）

---

## 1. 数字结论

| 项 | 结果 |
|---|---|
| vk129 启动 | ❌ 修前 `[0.55 s]` panic → ✅ 修后完整起机、`oops=0` |
| 根因 | **ABI 失配**：`dev->fwnode` 偏移 632→688（差 56 B），`CONFIG_MODVERSIONS` 未开无 CRC 门 |
| 单变量性 | 内核 `Image.gz` sha `f2d073bd…` **全程未变**（= vk129 镜像内 kernel） |
| 决定性日志 | `cs_system_cfg: CoreSight Configuration manager initialised` |
| suspend 能力 | ✅ `/sys/power/state` = `freeze mem`；`mem_sleep` = `[s2idle] deep` |
| 实挂起 | ✅ `PM: suspend entry (s2idle)` → `PM: suspend exit`，`success=1/fail=0`，`boot_id` 不变 |
| **挂起时长** | 🔴 **仅约 1.4 s**（s2idle 与 deep 同型，4/4 确定性复现） |
| **阻塞真因** | 🔴 `qcom-pcie 1c00000.pcie: Timeout waiting for L2 entry! LTSSM: 0x12` |
| T10 有效样本 | **n=1**（Round 1 ALIVE：vk64 + 19 相机模块 + `dpms On→Off`） |
| 宿主文件损坏 | ⚠️ **第二次复现**，14 个文件（AMD/nouveau/ov02e10/mwifiex），已修 `corrupt=0` |

## 2. suspend 线的完整因果链

```
[0.551493] （修前）Unable to handle kernel paging request at 0003201faafe03f1
           pc : software_node_notify+0x54/0x110 ← device_add ← cscfg_init [coresight]
           x1 : d503201faafe03e9   ← d503201f = nop 指令
           x2 : a9be7bfd6a5233f    ← a9be7bfd = stp 指令
```

**改 config 就是改 ABI**：`struct dev_pm_info` 对 `CONFIG_PM_SLEEP` 是真 `#ifdef`，
而它在 `struct device` 里排在 `fwnode` **之前**：

| 树 | `CONFIG_PM_SLEEP` | `sizeof(dev_pm_info)` | `dev->fwnode` |
|---|---|---|---|
| `build/vk83-tree`（vk127 配方） | 0 | 280 | **632** |
| `build/m1-73`（vk129 配置） | 1 | 336 | **688** |

设备上 `coresight.ko` 仍是 vk127 布局（143 032 B），新内核按 688 布局 ⇒
模块读到相邻字段（PCIe hwmon 结构），把内核代码段当指针解引用。
`# CONFIG_MODVERSIONS is not set` ⇒ 无 CRC 门，静默加载后 panic。

**修复 = 只重编模块树**（内核一字节没动）⇒ 起机成功，`coresight.ko` 变为 3 456 536 B。

## 3. T9 为什么测不了：suspend 待不住 1.4 秒

```
[991.340862] PM: suspend entry (deep)
[991.370154] dwc3-qcom a600000.usb: port-1 HS-PHY not in L2
[991.608302] qcom-pcie 1c00000.pcie: Timeout waiting for L2 entry! LTSSM: 0x12   ★
[991.611976] Disabling non-boot CPUs ...
[991.616875] Enabling non-boot CPUs ...            ← 4 ms 后立刻恢复
[991.930234] qcom-pcie 1c00000.pcie: PCIe Gen.3 x2 link up
[992.1   ]  mhi mhi0: Requested to power ON          ← WiFi 重新上电
[992.2   ]  ath12k_wifi7_pci 0000:01:00.0: chip_id 0x2 ...
[992.2   ]  hwmon hwmon57: PM: parent phy0 should not be sleeping
[992.28  ]  elogind: Power key pressed short.
[992.768653] PM: suspend exit
```

**已排除**：
- RTC 唤醒能力（设备根本没睡那么久；「挂起 12 分钟」是误判 —— 822.27 entry → 823.74 exit 只 1.47 s，
  之后只是 USB gadget/WiFi 没恢复导致 SSH 不可达）
- coresight `tpda/tmc` 的 `pm_runtime` 不平衡（卸载 coresight 后仍 3 s）
- `pcie_aspm=performance`（写报 `Resource busy`；L2 是 `qcom-pcie` 驱动主动请求，与 ASPM policy 无关）
- 「卸载 WiFi」做对照（**无效**：`modprobe -r` 只卸驱动，resume 时 PCIe 重扫按 modalias 自动 probe 回来）

## 4. 本日新增/修改的脚本

| 脚本 | 作用 | 状态 |
|---|---|---|
| `scripts/switch-kernel-abi.sh`（新） | **内核镜像 + 模块树原子切换**（`--list`/`--to`/`--check`） | `--list`/`--check` 已验；fastboot 分支未真跑 |
| `scripts/serial-fanout.sh`（改） | 自轮询重连（去掉 `BindsTo` 依赖）；等节点上限 600 s→**3600 s** | ✅ 实测跨设备重启存活 |
| `scripts/install-serial-logger.sh`（改） | unit 去掉 `BindsTo=`（它触发 normal-stop，`Restart=always` 不覆盖） | ✅ 已装 |
| `scripts/suspend-boot-panic-capture.sh`（改） | 串口探针失败改**硬失败** | ✅ |
| `scripts/suspend-drain-rate.sh`（改） | 唤醒段改人工按键（RTC 不可靠）+ `DEV` 可覆盖 | 待 PCIe L2 修好后用 |
| `scripts/n5b-vk64-death-rate.sh`（改） | 已在 vk64 则跳过 boot；**轮内复核内核**；连续 SETUP-FAIL 达 2 次退出 | ✅ 语法过，待下轮验 |

## 5. 本轮踩到的坑（均已进 PITFALLS）

| # | 坑 | 一句话 |
|---|---|---|
| **#360** | 改 config 改 ABI | 模块不重编 ⇒ 早期 panic；已有上机实证 |
| **#361** | `BindsTo=` + `Restart=always` 不重连 | 串口日志静默停摆（假阴性第二来源） |
| **#362** | `make olddefconfig` 不带 `ARCH` | 把 arm64 `.config` 写成 **x86**；靠镜像内嵌 ikconfig 才发现 |
| **#363** | `nohup` 起的设备脚本不随终端中断而死 | 会持续重启设备直到耗尽 `slot-retry-count` |

宿主机**静默文件损坏第二次复现**（14 文件），已 `git cat-file` 修复至 `corrupt=0`；
`memtest86+` 仍未跑，用户已确认后续单独处理。

## 6. 未做 / 下一步

| 项 | 状态 | 前置 |
|---|---|---|
| **T9** 掉电率 | 🔴 阻塞 | 修 `qcom-pcie` L2（DT/驱动，参考上游 sm8750）+ 修 ath12k hwmon parent 睡眠访问 |
| **T10** N5b 扩样 | 🟡 n=1 | 需要设备稳定在 vk64；RAM 内核每轮要 `fastboot boot`，需人在场 |
| `CONFIG_MODVERSIONS=y` | 建议 | 把 ABI 失配从「随机 panic」变成「加载时明确报 CRC 不匹配」 |
| EDL 真机验证 | 未做 | 需用户同意承担一次进 9008；且 EDL 出口工具链未备 |

**T10 本轮的 5 个 round**：1 ALIVE（有效）· 2 INVALID-NO-BLANK · 3 SETUP-FAIL · 4 WRONG-KERNEL（跑成 vk127）· 5 SETUP-FAIL。
后四轮全因**残留后台脚本**反复重启设备所致（PITFALLS #363），不计入 n。
