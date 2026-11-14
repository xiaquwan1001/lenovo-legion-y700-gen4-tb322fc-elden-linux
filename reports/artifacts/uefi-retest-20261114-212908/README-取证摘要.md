# UEFI 复测中断：崩溃真因 = 隔壁项目残留 fastboot 进程抢同一 USB 设备

日期：2026-11-14 21:29–21:44（本会话）
状态：**未完成任何 UEFI 复测**；设备现处安全态（Linux / b 槽 / `_a` Active0 Succ0 Bootable1 / `_b` Active1 Succ1）。

## 结论（一句话）
三次崩溃（21:29 `fastboot boot` 前、21:35 `fastboot reboot-bootloader`、21:43 仅 `getvar`）
**都不是 fastboot 命令写法问题，也不是 UEFI 载荷问题**：主机上有 **13 个孤儿 `fastboot oem dump-emmc ptable`
进程**（来自 `kirin-tool-linux`，PPID=systemd --user 2043，父进程已死，最早 11:37 起存活 10 h），
持续对 USB 总线上的 fastboot 设备发命令 ⇒ 与我们的 `fastboot -s HA2EXB0E` 争抢同一台设备的
USB 端点/传输，导致设备侧 ABL 崩溃并回落。

## 关键证据
| 项 | 实测 |
|---|---|
| 孤儿进程 | `pgrep -f "fastboot oem dump-emmc"` = **13 个**，PPID 全是 2043（systemd --user）；cwd 分别落在 `~/src/wt/kt-warnB1`(deleted)、`~/src/wt/kt-warnBplus`(deleted)、`~/gitlab-runner/builds/OZBE_geh6/0/xqh/kirin-tool-linux-refresh`；stdin = 各仓库 `tests/suites.txt`（已删） |
| 它们状态 | `wchan=hrtimer_nanosleep`（在 `fastboot` 自己的重试 sleep 里），无 USB fd 常驻 —— 即**周期性重新打开设备重试** |
| 崩溃点 1 | 21:29:26 设备从 fastboot(18d1:d00d) 消失 → 21:30:19 以 `1d6b:0104 TB322FC mainline` 回 Linux（boot_id 换新、`_b` 槽） |
| 崩溃点 2 | 21:35:11 进 fastboot 成功；`fastboot reboot-bootloader` 输出 `< waiting for HA2EXB0E>` 后设备崩溃 |
| 崩溃点 3 | 21:43 进 fastboot 成功；**只发 `getvar product` 三次** 全部 `< waiting for HA2EXB0E>` ⇒ 崩溃 |
| 反证 | 三次崩溃前 `fastboot devices` 都能正常列出 `HA2EXB0E` ⇒ USB 枚举正常，问题在**命令通道被抢** |
| 排除 | `reboot-bootloader` 是合法命令（`fastboot --help` 明确 `reboot [bootloader]`），与崩溃无关；本会话未执行任何写盘动作 |

## 命令写法（供参考，非根因）
`fastboot reboot-bootloader` 与 `fastboot reboot bootloader` 在本版 platform-tools 37.0.1 下等价；
本项目脚本统一用 `ssh elden-root 'sync; reboot bootloader'`（systemd 路径，PITFALLS #650）。

## 本会话已取到的 UEFI 侧事实（只读，有效）
- `boot_a` = **pc1 UEFI 载荷**，前 67186688 B 的 sha256 = `40d43397c14ce4ca18e99f553e618b40e901ed90d0c536dbed4fec76defb18de`，与 `out/r21-sbstop-pc1/uefi-preamblec1-r1.img` **逐字节一致**（原样在位）。
- `dtbo_a` 首 64 B 全 0（UEFI 前置态仍成立）；`dtbo_b` 全 0。
- ESP `/dev/sda18`（`ELDENESP`）：`\EFI\BOOT\BOOTAA64.EFI` = **`244c5f65…` = v3b-bigfont GRUB**（非 Loader-r73），`\EFI\elden\Loader.efi` = `6e51fc60…`（r73）；
  `\boot\boot.img` = `54e84588…`（vk190）、`\boot\dtbo.img` 32 MiB、`\boot\vendor_boot.img` 96 MiB；avail 77 MiB。
  ⇒ **DEVICE/README.md:39-40 与 :47/:65 的「BOOTAA64.EFI = Loader-r73」记述是错的**，实际是 v3b GRUB。
- ESP 里 `\boot\grub\grub.cfg` = 11-11 的 **A/B/C/D 四臂 EFI-stub 实验菜单**（`set timeout=20`、`default=0` = A 臂基线，无 `earlycon=efifb keep_bootcon`）；
  `grubenv` 留痕 = `elden_grub_log=11-A2-initrd-ok-booting`（11-12 那次）。
  ⇒ **`set_active a` 后会自动进 A 臂（无 earlycon）⇒ 预期黑屏/无字**，这是复测前必须先改的项。
- `/boot/initrd.img`（11-12 12:58，`3282ae6c…`）= 真 gzip+cpio，解压后 181 MB，**已修**（原 `zeros602` 坏件另有备份）；
  `/boot/Image` = `7.3.1-debug-vk188-sysfbfb-…`；内核 config 已含 `CONFIG_SYSFB_SIMPLEFB=y`、`CONFIG_FB_EFI=y`、`CONFIG_FRAMEBUFFER_CONSOLE=y`。
- 崩溃后回落的每次都是 **b 槽**（cmdline 无 `elden_bootloader=esp`），`boot_a` 从未被写，`qbootctl` 属性未变 ⇒ 无损伤。

## 恢复操作前的待办（等隔壁项目隔离完成）
1. 清掉 13 个孤儿进程：`pkill -f "fastboot oem dump-emmc"`（**注意** 模式要写字符组避免自匹配）。
2. 确认 `gitlab-runner` 没有排队中的 `kirin-tool-linux-refresh` job 会重启它们（runner 是常驻，需检查/暂停该 project 的 runner）。
3. 复测前把 ESP `\boot\grub\grub.cfg` 的 `default=0` 指到带 `earlycon=efifb keep_bootcon panic=0` 的臂（或用 `menu.cfg` 走 Loader 路径），否则 a 槽起来必然黑屏。
4. 修 `DEVICE/README.md:39-40`/`:47`/`:65` 的 ESP 身份矛盾。
