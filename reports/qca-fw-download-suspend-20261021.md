# BT 固件下载窗口 × suspend：根因、修复与副作用（2026-10-21）

- **日期**：2026-10-21 14:00–15:10
- **主题**：T9 的「真阻塞」从 PCIe L2 修正为 **WCN7850 固件下载窗口**；给出内核修复（vk131/vk132）与用户态兜底（elogind 钩子）
- **结论（一句话）**：`qca_suspend()` 等 `QCA_IBS_DISABLED` 只有 **3 s**，而 WCN7850 的 FW+NVM 下载实测 **25.4 s** ⇒
  任何落在下载窗口内的 suspend 必然 `-110` 并 abort 整机挂起。修复后该场景 **suspend 成功、fail=0**。
- **副作用（如实记账）**：被打断的下载**不会自愈**；唤醒后 `hci0` 停 `DOWN`，`hciconfig up` 报 `Not supported (95)`。
  试过 resume 里 `device_release_driver()+device_attach()` 强制 re-probe ⇒ **整机挂死**（需长按电源键），已回退。

---

## 1. 数字结论

| 实验 | 条件 | 结果 |
|---|---|---|
| 固件下载耗时（两次实测） | `setting up wcn7850` → `QCA setup on UART is completed` | **23.0 s**（191→214 s）、**25.4 s**（19909.99→19935.41） |
| 驱动预算 | `FW_DOWNLOAD_TIMEOUT` | **3 s**（`msecs_to_jiffies(3000)`） |
| 改前（vk130）窗口内 suspend | BT 刚 unblock ≤3 s 就挂 | `qca_suspend returns -110` → `Some devices failed to suspend` → **3.5 s 弹出**，`last_failed_dev=serial0-0` |
| 改前 BT 稳定后 | BT 已完成下载 | **21.7 / 22.0 / 22.0 s**（RTC 闹钟准点唤醒），5 min 一发 **held 302 129 ms** |
| 改前 WiFi 单变量 | A wifi on / B wifi rfkill / C wifi+bt rfkill / D unblock 后立刻挂 | 21.9 / 21.8 / 21.9 / **3.5 s（D 命中下载窗口）** |
| 改后（vk131）窗口内 suspend | 同上场景 | held **361 711 ms**、`success=1 fail=0`、日志 `FW download still running, skipping in-band sleep` |
| 改后（vk132）窗口内 suspend | 同上 | held **385 858 ms**、`success=1 fail=0`、多一条 `restarting controller after interrupted FW download` |
| 改后（vk133）resume 强制 re-probe | `device_release_driver()+device_attach()` | **整机挂死**（14:58:08 起 USB gadget 不再出现） ⇒ 已回退到 vk132 |
| 钩子端到端 | 解封 BT 后立刻 `loginctl suspend` | `pre: BT settled after 24s` → 挂起成功（success 12→13，fail 不变，`qca110` 不增） |

---

## 2. 根因（代码定位）

`drivers/bluetooth/hci_qca.c` 的 `qca_suspend()`：

```c
if (test_bit(QCA_IBS_DISABLED, &qca->flags) || test_bit(QCA_SSR_TRIGGERED, &qca->flags)) {
    wait_timeout = test_bit(QCA_SSR_TRIGGERED, &qca->flags)
                 ? IBS_DISABLE_SSR_TIMEOUT          /* 8 s dump + 3 s = 11 s */
                 : FW_DOWNLOAD_TIMEOUT;             /* ★ 只有 3 s */
    wait_on_bit_timeout(&qca->flags, QCA_IBS_DISABLED, TASK_UNINTERRUPTIBLE, wait_timeout);
    if (test_bit(QCA_IBS_DISABLED, &qca->flags)) {
        bt_dev_err(hu->hdev, "SSR or FW download time out");
        ret = -ETIMEDOUT;      /* ★ 直接把整机 suspend 打断 */
        goto error;
    }
}
```

`QCA_IBS_DISABLED` 在 `qca_uart_setup()` 开始下载前 set、下载完成后 clear。
上游写 3 s 的时代 WCN399x 固件小、串口快；WCN7850 的 `brhbtfw20.tlv` + `brhbtnv20.bin` 需 ~25 s。

---

## 3. 修复（`build/m1-73/drivers/bluetooth/hci_qca.c`）

```c
#define FW_DOWNLOAD_TIMEOUT		msecs_to_jiffies(3000)
#define FW_DOWNLOAD_SUSPEND_TIMEOUT	msecs_to_jiffies(40000)   /* 新增：实测 ~25 s */
```
以及 `qca_suspend()` 的等待块：
- SSR 分支保持严苛（`IBS_DISABLE_SSR_TIMEOUT`，超时仍 `-ETIMEDOUT`，因为掉电会丢 RAM dump）；
- 下载分支用 40 s；仍超时则 **不再打断整机 suspend**，改为
  `bt_dev_warn("FW download still running, skipping in-band sleep")` + `set_bit(QCA_RESUME_RESET_NEEDED)` + `return 0`。
- `qca_resume()` 里 `test_and_clear_bit(QCA_RESUME_RESET_NEEDED)` 后
  `bt_dev_info("restarting controller after interrupted FW download")` + `hci_reset_dev(hu->hdev)`。

编译门：`make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-vk127 W=1 drivers/bluetooth/hci_qca.o` → rc=0、**0 warning**。
镜像门：`kbuild-sanity.sh --before/--after` 全绿；全量 `Image.gz` 构建 rc=0、0 ICE/段错误。

---

## 4. 副作用与边界（重要）

1. **被打断的下载不自愈**：suspend 冻结 serdev 后下载不再推进，唤醒时控制器处于半初始化态，
   `hci0` 为 `DOWN`，`hciconfig hci0 up` → `Not supported (95)`。
2. **resume 强制 re-probe 会挂死整机**（vk133 实测）：在 resume 上下文拆 serdev 父设备不可行 ⇒ **不要走这条路**。
3. 因此**推荐组合**：
   - 内核侧（vk132 行为）：不打断整机 suspend + resume 打日志提示；
   - 用户态兜底：唤醒后 `rc-service bluetooth restart`（安全、可脚本化），或直接用下面的 elogind 钩子把窗口等过去。

---

## 5. 用户态兜底：elogind system-sleep 钩子（任务 2，已上机验收）

- 源：`rootfs/persistent-overlay/usr-libexec-elogind-system-sleep/50-elden-bt-guard`
- 部署/自检：`scripts/deploy-bt-suspend-guard.sh`（`--check` / `--remove`）
- 单测：`scripts/test-bt-guard.sh`（伪造 `dmesg`/`rfkill` 注入，5 个用例含负向，全绿）
- 判据：**dmesg 行序**（最后一次 `setting up wcn7850` vs `QCA setup on UART is completed`）。
  两个已踩坑：① 下载期间 `hci0` 根本不存在；② `hciconfig hci0 | head -2` 会截掉第 3 行的 `UP RUNNING`。
- 行为：`pre` 等下载窗口（默认 45 s，实测 24 s 命中）；`post` 恢复 rfkill 原状态；非 `suspend` 不介入。
- 端到端实测：`14:28:59 unblock` → `14:29:00 loginctl suspend` → `14:29:25 pre: BT settled after 24s` → 挂起成功。

> 注意：`loginctl suspend` 是**异步**的 —— DBus 调用 3 ms 就返回，看不出是否真挂起。
> 校验必须看 `/sys/power/suspend_stats/success` 与 `dmesg | grep -c "PM: suspend entry"` 是否增加。
> elogind 自己直接写 `/sys/power/state`（无独立 sleep helper 二进制），与 PID1/OpenRC 无关。

---

## 6. 仍未修（非阻塞）

| 项 | 现象 | 次数 |
|---|---|---|
| `dwc3-qcom a600000.usb: port-1 HS-PHY not in L2` | USB HS PHY 状态机未到 L2，疑与 M3-1 双连接器 HS mux 拓扑相关 | 每次 suspend 1 条 |
| `hwmon hwmonNN: PM: parent phy0 should not be sleeping` | ath12k 把 hwmon 注册在 `wiphy->dev` 下，而 suspend 时父设备已 prepared（`drivers/base/power/main.c:158`） | 每次 1 条 |
| `ath12k` `restart complete` 超时 | vk130 出现过一例（长挂起后 resume `-110`）；vk131–133 未复现 | 0（本轮） |

---

## 7. 镜像台账（全部 `fastboot boot` 零写盘，`boot_b` 未改）

| 版本 | 内容 | sha256（boot-elden-*.img） | 上机结果 |
|---|---|---|---|
| vk130 | vk127 树 + `pcie-qcom skip_l23_ready` | `f5a6c6b9…` | L2 超时归零；暴露 BT 窗口问题 |
| vk131 | + `hci_qca` 40 s 预算 + 跳过 in-band sleep | `9f1bc9be…` | 窗口内 suspend 成功（361 711 ms） |
| vk132 | + resume `QCA_RESUME_RESET_NEEDED`（`hci_reset_dev`） | `87b73d2c…` | 窗口内 suspend 成功（385 858 ms），resume 提示出现 |
| vk133 | + resume 强制 serdev re-probe | `2955438d…` | **设备挂死**，已回退 |

`boot_b` 始终未写入；设备断电重启即回到原镜像。
