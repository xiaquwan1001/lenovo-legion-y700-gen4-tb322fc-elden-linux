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

## 冷启动（POR）回归 —— 2026-11-16 14:46，通过（含两处异常）

用户物理断电冷启（`set_active a` 后停在 fastboot），结果：

1. **GRUB 菜单正常显示** —— 屏照 `30-cold-por-grub-menu.jpg`（GNU GRUB 2.14，5 条：`Linux vk192（UEFI 直载…）` / `Linux vk192（诊断：无 ramoops 的 DTB）` /
   `ESP Loader.efi 链（r73 → ESP \boot\boot.img）` / reboot / poweroff；默认高亮第 1 条）。**菜单交互取证到此完成**。
2. **进了 Linux**（默认臂）；`grubenv` = `elden_grub_log=51-daily-vk192-initrd-ok-booting`、cmdline 含 `elden_bootmenu=grub-daily`、`Active slot: _a`。
3. **异常 A（已定因并修复）**：约 100 s 后「自己关机」= **我们自己的 `q28-boot-watchdog` 误判**。走 UEFI/GRUB 路径时 efifb 先注册成 DRM `card0`
   再注销，msm 拿到 **`card1`**，而看门狗只认 `card0` ⇒ `sess=yes card=no` ⇒ 命中 Q28 坏发判据 ⇒ `reboot`（两次后预算耗尽才停下）。
   全账 = `41-q28-wd-unit.txt`、`42-q28-watchdog-log.txt`（`attempt 1/2`、`attempt 2/2`、`budget exhausted` 三行）、`PITFALLS #667`；
   修 = `have_card()` 认任一 `cardN`（源 `packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh`，已部署 sha `d694c147…`）。
4. **异常 B（真 Q28 坏发，未修）**：其中一次启动走到 `Unpacking initramfs…` → `Freeing initrd memory` 后**屏全白 → 只剩背光**、
   msm 根本没 bind（一个 `cardN` 都没有）。那就是 #228 记的 Q28（DYN pclk 域闩住），与本次 EFI 无关；看门狗对这一发的重启判定是对的。
5. **第三次启动成功**（14:57，`Active slot: _a`、`card1`、phoc+phosh 在）；随后 `15:02:49 set_active b` → **12 s 回 SSH**，
   `Active slot: _b`、`card0`、vk192 ⇒ 日常线已恢复。

**串口通道（本轮打通）**：`scripts/serial-tap.py` 常驻可抓 `ttyACM0`（host 侧加了 `/etc/udev/rules.d/99-elden-ttyacm.rules` 给 `MODE=0666`，
并临时停 `ModemManager`）；本次抓到的是 b 槽那次启动的前段（`logs/serial-a-slot-loop-20261116-145745.log`，含 `--- tap open` 与丢字节提示）。
**下次要抓失败现场，必须在按电源前就把 tap 起起来**（本轮起晚了，loop 的现场只留在屏照 + journal 里）。

## 回滚口径

`scripts/esp-install-grub.sh --rollback`，或手工把 `EFI/BOOT/BOOTAA64.EFI.daily-v8-20261116.bak`（= 验证件 `cc6391b3…`）拷回。

## v9 / v10：菜单中文标题（2026-11-16 15:20-15:36）

用户要求「改标题以便加载中文」。**v8 的标题含中文/全角括号，而原 `big.pf2`（DejaVu 系）没有 CJK 字形** ⇒ 屏上全是「点」
（见 `30-cold-por-grub-menu.jpg`）。两条一起改：

1. **字体**：`scripts/grub-arm64-cjk-font.sh`（本轮新增）—— 从 `/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc`
   用 `pyftsubset` **只抽菜单用到的字形**（130–134 个），`grub-mkfont` 造 pf2（72 px ≈ **29.6 KB**；整份 Noto CJK 96 px 会到十几 MB，
   而 ESP 只剩 ~64 MB 余量，PITFALLS #664）。带自校验：每个标题里的非 ASCII 码位必须真的出现在 pf2 里。
   构建侧给 `scripts/grub-arm64-arming-build.sh` 加了 `--bigfont FILE`（默认仍是原 `big.pf2`）。
2. **标题变短**：GRUB 菜单项**不折行**，v9 用长标题（~1900-2400 px @96）⇒ 尾巴被截掉（用户：「条目不分行导致选项字不全」）。

| 版本 | 主字体 | 标题 | 结果 |
|---|---|---|---|
| v8 | DejaVu `big.pf2` 96 px | 中文长标题 | 中文渲染成「点」 |
| v9 | Noto CJK 子集 96 px（`big-cjk.pf2`，54 KB） | 中文长标题 | **中文出来了**，但间距过大 + 条目被截断 |
| **v10（现役）** | Noto CJK 子集 **72 px**（`big-cjk72.pf2`，29.6 KB） | 短标题（≤1098 px @72，屏宽 1904） | `启动 vk192（直载 initrd）` / `启动 vk192（无 ramoops 诊断）` / `加载 ESP Loader.efi（r73）` / `重启` / `关机` |

**v10 真机验证（同日）**：

| 项 | 值 |
|---|---|
| 件 | `out/grub-arm64-arming-20261116/grubaa64-daily-v10-cjk.efi`，sha256 `15a8ddf8…`，8 204 288 B，`menuentry=5` |
| 装 | `scripts/esp-install-grub.sh --efi … --tag daily-v10-cjk-20261116 --activate`（ESP 读回 sha 一致；ESP 用量 448M/511M） |
| a 槽暖启 | `reboot` 15:32:32 → SSH 15:34:12（**68 s**，含 GRUB `timeout=10`）；`grubenv=51-daily-vk192-initrd-ok-booting`、`Active slot: _a`、DRM `card1` |
| **q28 看门狗修复验证** | 该发在 a 槽上活过 **160 s+** 且 `/var/log/q28-watchdog.log` 无新行（修前 100 s 必触发）⇒ `PITFALLS #667` 的修法在真机成立 |
| 回 b | `set_active b` → **20 s** 到 SSH，`Active slot: _b`，vk192 |

ESP 现役件链：v8 `f5dcf599…` → v9 `82fb1f8f…` → **v10 `15a8ddf8…`**（前两版都在 `EFI/grub/grub-*.efi` 与 `*.bak` 里可回滚）。
