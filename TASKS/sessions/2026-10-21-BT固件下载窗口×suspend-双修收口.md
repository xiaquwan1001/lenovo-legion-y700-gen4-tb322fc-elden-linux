# 2026-10-21 任务2/3 收口：BT 固件下载窗口 × suspend（钩子 + 内核双修）

- **日期**：2026-10-21 14:00–15:15
- **pi 会话 id**：见 `$PI_SESSION_ID`
- **主题**：按用户「做 2、3」的指令完成 ①suspend 前自动处理 BT（用户态钩子）②根治 `qca_suspend` 3 s 超时；顺带纠正 T9 的归因
- **结论**：真因 = **WCN7850 固件+NVM 下载 23.0/25.4 s ≫ `FW_DOWNLOAD_TIMEOUT` 3 s**，不是 BT 睡眠握手本身，也不是 PCIe L2。
  修复后（vk131/vk132）下载窗口内 suspend **成功、fail=0**（held 361 711 / 385 858 ms）；用户态钩子端到端 24 s 命中。
  **已知副作用**：被打断的下载不自愈（`hci0` 留 `DOWN`）；resume 强制 serdev re-probe **会挂死整机**（vk133 实测，已回退）。
- **证据指针**：`reports/qca-fw-download-suspend-20261021.md`（权威）、`reports/t9-vk130-pcie-l2-live-20261021.md`（顶部已加修正告示）
- **★SSOT 待并入**：`TASKS/README.md` §4 T9（已并入）

## 1. 交付物

| 文件 | 作用 |
|---|---|
| `build/m1-73/drivers/bluetooth/hci_qca.c` | 改 3 处：`FW_DOWNLOAD_SUSPEND_TIMEOUT`=40 s；下载未完成时 warn + `return 0`（不再 `-ETIMEDOUT`）并置 `QCA_RESUME_RESET_NEEDED`；`qca_resume()` 里 `hci_reset_dev` 重试 |
| `rootfs/persistent-overlay/usr-libexec-elogind-system-sleep/50-elden-bt-guard` | elogind system-sleep 钩子（pre 等窗口 / post 恢复 rfkill） |
| `scripts/deploy-bt-suspend-guard.sh` | 部署 + 自检（`--check`/`--remove`） |
| `scripts/test-bt-guard.sh` | 伪造 `dmesg`/`rfkill` 注入的单测，5 用例含负向，全绿 |
| `reports/qca-fw-download-suspend-20261021.md` | 本轮权威报告 |

## 2. 关键数字

| 项 | 值 |
|---|---|
| 固件下载耗时 | 23.0 s / **25.4 s** |
| 原预算 | 3 s（`FW_DOWNLOAD_TIMEOUT`），SSR 11 s |
| 改前窗口内 suspend | 3.5 s 弹出，`-110`，`fail+1`，`last_failed_dev=serial0-0` |
| 改后（vk131） | held **361 711 ms**，`success=1 fail=0`，`FW download still running, skipping in-band sleep` |
| 改后（vk132） | held **385 858 ms**，`success=1 fail=0`，+`restarting controller after interrupted FW download` |
| vk133（re-probe） | **整机挂死** ⇒ 回退 |
| 钩子端到端 | unblock→`loginctl suspend` 1 s 后发起，`pre: BT settled after 24s`，success 12→13，`qca110` 不增 |
| BT 稳定后对照 | 21.7/22.0/22.0 s；5 min 一发 held 302 129 ms；wifi rfkill 单变量 21.8 s |

## 3. 方法论坑（已入 PITFALLS）

- **#365**：`loginctl suspend` 异步 —— DBus 3 ms 返回 0 ≠ 没挂起，须比对 `suspend_stats`/`PM: suspend entry` 计数。elogind 自己写 `/sys/power/state`，无独立 sleep helper，与 PID1/OpenRC 无关。
- 钩子判据不能用 `hci0`/`hciconfig`：下载期间 `hci0` 不存在；`hciconfig hci0 | head -2` 会截掉第 3 行的 `UP RUNNING`。改用 dmesg 行序。

## 4. 设备状态

- 全程 `fastboot boot` 零写盘，**`boot_b` 未改**。
- vk133 挂死后设备离线（14:58:08 起 USB gadget 消失），需长按电源键；重启后回到原镜像（`boot_b`/m1-baseline-f3 一脉）。
- 钩子已部署到设备 `/usr/libexec/elogind/system-sleep/50-elden-bt-guard`（持久根，重启保留）。

## 5. 下一步

1. 设备恢复后：确认 `hci0` 能起来（`rc-service bluetooth restart` 兜底被打断的下载），复测一发正常 suspend 作回归。
2. 可选：把 `rc-service bluetooth restart` 写进钩子的 `post`（比内核 re-probe 安全），或等上游对 `qca_suspend` 预算的正式方案。
3. T9 原始目标（掉电率 `%/h`）仍待：需拔 USB + RTC-epoch 长闹钟 + 人工唤醒。
