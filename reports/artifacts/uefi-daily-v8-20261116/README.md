# uefi-daily-v8-20261116 —— ESP 归位件 + a 槽暖启复验

日常用嵌入菜单 GRUB 上 ESP 并做 a 槽暖启验证的证据档（2026-11-16 14:03–14:08）。

## 件

| 项 | 值 |
|---|---|
| EFI | `out/grub-arm64-arming-20261116/grubaa64-daily-v8.efi`，sha256 `f5dcf5999b7f7c1e02d8d36858eeb7a1742d639b668aaec01a2c6101785ee9f8`，9 527 296 B |
| 菜单源 | `out/grub-arm64-arming-20261116/arming-daily-v8.cfg`（`timeout=10`，5 个 `menuentry`） |
| 构建 | `scripts/grub-arm64-arming-build.sh --cfg … --out …`（自校验 OK machine=0xaa64 menuentry=5） |
| 装法 | `scripts/esp-install-grub.sh --efi … --tag daily-v8-20261116 --activate`（旧件备份 `BOOTAA64.EFI.daily-v8-20261116.bak` = 验证件 `cc6391b3…`） |

菜单语义：臂 0（默认）= 直载 `/boot/Image`（vk192 守卫核）+ `elden.dtb`（含 ramoops）+ 64 MB initrd + 全量 `earlycon=efifb keep_bootcon` cmdline；
臂 1 = 同内核 + `elden-noramoops.dtb`（诊断）；臂 2 = chainload `\EFI\elden\Loader.efi`（r73 → `\boot\boot.img`，11-08 那条链）；reboot / poweroff。
每步写 `grubenv`（`50/51/5A` 前缀），宿主机可直读，不依赖拍屏。

## 证据文件

- `00-pre-state.txt`：改前设备态（`uname -r` = vk192 UTS、`Active slot: _b`）。
- `10-a-slot-v8.txt`：a 槽启动后 —— `uname -r` 同上、`Active slot: _a`、cmdline 含 `elden_bootmenu=grub-daily`、
  `grubenv` = `51-daily-vk192-initrd-ok-booting`、ramoops 三段 `ignoring … overlaps the initrd (0xc1ab0000-0xc584a5e0)` + `ramoops disabled for this boot`、
  `Unpacking initramfs…` → `Run /init`。
- `11-slot-attr-after-a.txt`：`slot-attr.py show` — `boot_a` retry 7→6 succ=0（a 槽已被 ABL 计数）⇒ 随即 `mark-successful a` 回 `retry=7 succ=1`。
- `20-back-to-b.txt`：`fastboot set_active b` 后 —— `Active slot: _b`、`uname -r` = vk192。本次 b 槽无 ramoops 冲突行（initrd 未覆盖该区）。

## 时序

| 时刻 | 事件 |
|---|---|
| 14:03 | `esp-install-grub.sh --activate` 装新件（sha 读回一致） |
| 14:04:17 | `reboot bootloader` |
| 14:04:35 | `fastboot set_active a` + `fastboot reboot` |
| 14:05:53 | SSH 回（**44 s**，GRUB 默认臂第 0 项） |
| 14:06 | `slot-attr.py mark-successful a` |
| 14:07:18 | 再次 `set_active b` + reboot |
| 14:07:48 | SSH 回（**16 s**，vk192 / `_b`） |

## 仍未做（需用户物理动作）

1. **`boot_a` 冷启动（POR）回归**：断电 → 长按电源开机 → 应仍在 `_a`，44 s 级进系统（暖启已过，冷启未验）。
2. **菜单屏照**：`timeout=10` 停在菜单时拍一张（5 个条目 + 大字体），留档本目录，作「菜单交互/显式可选臂」的取证。
   判据：能看见 5 条；不选则默认臂自走；`grubenv` 的 `50/51` 打点与屏上条目一致。
3. 回滚口径：`scripts/esp-install-grub.sh --rollback`，或手工把 `EFI/BOOT/BOOTAA64.EFI.daily-v8-20261116.bak` 拷回。
