# 286 — PSCI 暖复位进 fastboot 后立刻 `fastboot boot` 不可靠（黑屏 + 崩坏/core dump）

## #650 用 `eldroid-bootctl reboot bootloader`（PSCI SYSTEM_RESET2 暖复位）进 fastboot 后马上 `fastboot boot`，实测 1 次黑屏 + 屏幕崩坏/core dump 告警；改 `ssh elden-root 'reboot bootloader'`（systemd 正常关机路径）后同镜像一次通过

- **时间线（2026-11-13 20:4x）**：`scripts/to-fastboot.sh --boot out/boot-elden-vk191.img`
  → 设备确实进了 fastboot → `fastboot boot` 之后**屏幕立刻失去背光**，随后出现「系统崩坏 + core dump」类告警，
  几十秒后设备自行回到正常槽位启动（journal 里那一段**没有**新 boot 条目 ⇒ 崩在挂根之前）。
- **对照（同镜像、同一天）**：`ssh elden-root 'sync; reboot bootloader'` → 等 fastboot →
  `fastboot boot out/boot-elden-vk191.img` ⇒ **一次成功**（SSH 20 s 内回来、`Run /init`、
  `Unpacking initramfs...` 无 `no cpio magic`、DSI connected、gadget `iSerial=HA2EXB0E`）。
- **两条路径的机制差异**：`eldroid-bootctl` 走 `syscall(SYS_reboot, …, LINUX_REBOOT_CMD_RESTART2, "bootloader")`
  = PSCI 厂商暖复位，**跳过 systemd 关机序列**（服务不停、UFS/PMIC 不做有序下电）；
  `reboot bootloader` 走 systemd → `kernel_restart()` 正常关机路径。⇒ 暖复位后立刻灌新内核，
  硬件状态与驱动假设不一致（RAM boot 的 `fastboot boot` 还要重走一遍 UFS/PMIC 初始化）是最可疑的一层。
- **处置**：**上机默认用 `ssh elden-root 'reboot bootloader'`**；`scripts/to-fastboot.sh --boot` 暂标「不推荐」，
  脚本头已加 WARNING。若必须用暖复位路径，进 fastboot 后先 `fastboot reboot-bootloader`（让 ABL 重新初始化）
  再 `fastboot boot`，或改用 `reboot -f bootloader`。
- **残留未解释**：这次崩坏的屏上文字只由人目击（无 pstore 记录：`/sys/fs/pstore` 为空，ramoops 存在但
  panic 未落盘——因为崩在 early userspace 之前？未定）。**不得**据此断言「v191 镜像坏」：同镜像对照已通过。
- 出处：`reports/device-session-20261113-vk191.md`。
