# G1-29 路线 B **打通**：ESP 上放 `boot.img`，Mu `LinuxLoader` 变体直接读起（零写盘）

> 线：G1-29（拓展，非主线）。设备 = U2 `HA2EXB0E`。**零写盘**：只改 ESP（`/dev/sda18` FAT）上的文件，
> `boot_b` sha `4e38bc2c…` 全程未变。固件沿用 `p59`（p58 + R54-espfirst），**没有重刷任何分区**。
> 承接 `reports/uefi-espboot-r55-indeterminate-20261108.md`（首试判 indeterminate）与
> `archive/plans-20261110/2026-11-08-g1-29-route-b-espboot.md`。

---

## 0. 结论（判据三条全中）

```
# 设备侧（2026-11-08 19:25:06 起的这一发）
$ uname -r        → 7.3.1-debug-vk184-00002-g4da9a8b69fc8        (★ = ESP boot.img 的内核；boot_b 是 00003)
$ cat /proc/cmdline → … elden_nocamera=1 elden_bootloader=esp …   (★ 令牌只写在 ESP 的 boot.img 里)
$ findmnt -no SOURCE / → /dev/sda17
$ sha256sum /dev/disk/by-partlabel/boot_b → 4e38bc2c…              (★ 与上机前一致)
```

ESP 侧两份日志（**这才是决定性证据通道**）：

```
/loader.log                     /espboot.log
[L] entry                       [E] esp in
[L] pre-boardinit               [E] esp boot 85594112     ← /boot/boot.img
[L] boardinit st 0              [E] esp boot 100663296    ← /boot/vendor_boot.img
[L] pre-vmdata                  [E] esp dtbo 33554432     ← /boot/dtbo.img
[L] force-boot                  [E] esp done 0
[L] bootfastboot 0
[L] pre-auth
[L] post-auth st 0              ← LoadImageAndAuth 走 ESP-first 并成功（跳过 AVB）
[L] pre-bootlinux               ← 随后 LinuxKernel() 跳转，不再返回（无 post 是**预期**）
```

⇒ **「从 ESP 的 FAT 读走 kernel/initrd/dtb 并起完整 Linux」这条验收成立**，且不碰 `boot.img` 槽。
G1-29 原始验收的另一半（启动菜单）仍缺，见 §4。

## 1. 这一发怎么从「indeterminate」变成「打通」——四步，全部有日志

| # | 版本 | 现象 | 归因 |
|---|---|---|---|
| 1 | R55（`Loader.efi`，RELEASE 构建） | 屏上仍是 EFI-stub 墙那三行、随后掉电 | **不可判**：RELEASE 剥了 `DEBUG()` 串（`PITFALLS #559`） |
| 2 | R56（加面板 `[E] esp …` 标记 + `#561` 的 `Info->Pname` 修复） | 屏上只见 `ASSERT String.c +37`、落到 Mu fastboot | 仍不可判：面板通道被打断 |
| 3 | R58（`\loader.log` 落盘 + 各阶段打点） | `loader.log` 只有 6 行、结尾 `bootfastboot 1` → `to-fastboot`，**`LoadImageAndAuth` 根本没跑** | **真因**：本树 `LinuxLoader.c:295` 把 `BootIntoFastboot = TRUE` **写死**（历史记的「漏发 fastboot continue」就是它）⇒ `fastboot boot` 的 UEFI 件永远不进 `BootLinux` |
| 4 | R58b（`\espboot.force` 存在即强制 `BootIntoFastboot = FALSE`）+ ESP 备齐 `boot/vendor_boot/dtbo` | `force-boot` → `bootfastboot 0` → `post-auth st 0` → `pre-bootlinux` → **Linux 起来** | 打通 |

**第 3 步是整条线的转折**：之前所有「ESP-first 失败」的推断都建立在一个**从未执行**的分支上。

## 2. 三个新发现（已进 `PITFALLS`）

1. **`BootIntoFastboot` 写死 TRUE**（`LinuxLoader.c:295`，`GetKeyPress` 那段被注释掉后留下裸赋值）
   ⇒ 任何 `fastboot boot` 起的 UEFI 件都会在 `BootLinux` 前直接跳 fastboot。判据：`loader.log` 里 `bootfastboot 1`。
2. **`extra_cmdline`（头偏移 608）不会被 Mu 拼进内核 cmdline**：把令牌写在 extra 区时 `/proc/cmdline` 干净无令牌；
   改写到**主 cmdline**（偏移 64，512 B 内）后立刻出现。⇒ 令牌一律写主 cmdline。
   （另：Mu 的 `boot_img_hdr_v0` 用 `UINT32 id[8]`，所以本平台的 extra 偏移是 **608**，与 AOSP 的 584 不同，本项目工具已一致。）
3. **面板（`SerialPortWrite`）不是可靠证据通道**：这轮同一份代码在某一发能出面版标记、另一发直接 `ASSERT String.c +37`
   → 递归异常/掉电。**落盘到 ESP 的日志才是**（掉电也不丢，重启后 `cat` 即可）。

## 3. 实现清单（当前在机件）

| 件 | 值 |
|---|---|
| 固件 | `out/r21-sbstop-p59/uefi-preamble59-r1.img`（`cd73fbdc…`）= p58 + R54-espfirst（BDS 定向连 BlockIo 后优先起 ESP 的 `\EFI\BOOT\BOOTAA64.EFI`） |
| ESP loader | `out/espboot-20261108/Loader-r58b.efi`（`ea8e0cfb…`，179 712 B）= R55（ESP-first `LoadImageAndAuth`）+ R56（面板标记/`Pname` 修复）+ R57（`\espboot.log`）+ R58/R58b（`\loader.log` + `\espboot.force`） |
| ESP 内容 | `/EFI/BOOT/BOOTAA64.EFI`（= 上面的 loader；GRUB 备份 `BOOTAA64.EFI.grub.bak` `7993adfc…`）、`/boot/boot.img`（`27bd6ddd…`，vk184 + 主 cmdline 令牌 `elden_bootloader=esp`）、`/boot/vendor_boot.img`（`aa98d194…`，`vendor_boot_b` 整分区）、`/boot/dtbo.img`（`27d54050…`，`dtbo_b` 整分区）、`/espboot.force`（0 字节开关）、`/loader.log`、`/espboot.log` |
| 源码改动（Mu 树工作区，未提交 git） | `Library/avb/VerifiedBoot.c`（ESP-first + 日志）、`Application/LinuxLoader/LinuxLoader.c`（`\loader.log`、`\espboot.force`）、`Library/BootLib/BootLib.inf`（+`SerialPortLib`）、`Library/FrameBufferSerialPortLib.c`（R21/R28 屏显初始化） |
| 构建 | `~/.local/bin/stuart_build -c Platforms/PakalaPkg/PlatformBuildNoSb.py TARGET=RELEASE TARGET_DEVICE=lenovo-y700g4`（增量 12–17 s，ccache 热；日志 `reports/artifacts/espboot-20261108/build-r5*.log`） |

## 4. G1-29 还差什么

| 项 | 状态 |
|---|---|
| 从 FAT 读 kernel/initrd/dtb 并起 Linux | ✅ **本轮打通**（判据见 §0） |
| 不依赖 `boot_b` 槽（绕开 96 MiB 限制） | ✅ |
| **启动菜单**（G1-29 原始验收的另一半） | ⬜ 未做。GRUB 那条路撞 EFI-stub 墙（`#558`）；本 loader 目前**无菜单**（固定读 `/boot/boot.img`）。下一步二选一：① loader 自己接音量键/电源键做菜单（读 `\boot\*.cfg`，多内核可选）；② 让 loader 支持多个 boot.img 文件（`boot.img` / `boot2.img` 超时/按键选择） |
| 落地方式（写成默认启动，写 `uefi_a` 或保留 `fastboot boot`） | ⬜ 未做，属**写盘**，要单独批准 + 备份 |
| `fastboot boot` 语义 vs 强制 boot | ⚠️ 现在靠 `\espboot.force` 开关覆盖写死的 `BootIntoFastboot`；**这只能用于实验**，正式落地时要么改源码里那行写死赋值，要么走正常启动路径 |

## 5. 顺手发现的两个小问题

- **`dtbo.img` 曾在 ESP 上消失过一次**（14:28 有、15:43 没）：`fsck.vfat -a` 清 dirty bit 时丢的，已重新 dump。
  纪律：ESP 上每个文件落盘后 `sync` + `umount`，再 `fsck -n` 核对文件数。
- **`[E] esp boot` 两行标签重复**（boot 与 vendor_boot 共用标签）：日志里靠尺寸区分（85 594 112 / 100 663 296），
  下轮把标签改成 `[E] esp <name> <size>` 更清楚（非阻塞）。

## 6. 复现（从零到这一发）

```bash
# 1) 固件：p59（已固化，--verify PASS）
scripts/uefi-r21-p7-ladder.sh --gen p59 --verify
# 2) loader：Mu 树已打 R55/R56/R57/R58b 改动
cd build/uefi-woa-prep/repos/7-mu-lenovo
~/.local/bin/stuart_build -c Platforms/PakalaPkg/PlatformBuildNoSb.py TARGET=RELEASE TARGET_DEVICE=lenovo-y700g4
# 3) ESP 备件（设备在 Linux 时）
ssh root@192.168.7.1 'mount /dev/sda18 /mnt/esp'
scp out/espboot-20261108/Loader-r58b.efi root@192.168.7.1:/mnt/esp/EFI/BOOT/BOOTAA64.EFI
scp out/espboot-20261108/boot-elden-vk184-espb2.img root@192.168.7.1:/mnt/esp/boot/boot.img
ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/vendor_boot_b of=/mnt/esp/boot/vendor_boot.img bs=1M
                      dd if=/dev/disk/by-partlabel/dtbo_b        of=/mnt/esp/boot/dtbo.img        bs=1M
                      touch /mnt/esp/espboot.force; sync; umount /mnt/esp'
# 4) 上机（零写盘）
ssh root@192.168.7.1 'eldroid-bootctl reboot bootloader'
fastboot boot out/r21-sbstop-p59/uefi-preamble59-r1.img
# 5) 判据
ssh root@192.168.7.1 'grep -o "elden_bootloader=esp" /proc/cmdline; mount /dev/sda18 /mnt/esp && cat /mnt/esp/loader.log /mnt/esp/espboot.log'
```

## 7. 证据指针

- trial record：`reports/trials/20261108T112506Z-uefi-p59-espboot-seal.json`（`verdict=ESPBOOT_TAGGED`）
- 本轮各阶段日志：`reports/artifacts/uefi-boot-20261108-r58b-clean/`、`reports/artifacts/uefi-boot-20261108-seal/`、
  `reports/artifacts/espboot-20261108/{build-r55…r58b.log,deploy-r56.log,deploy-r57.log}`
- 失败链（保留）：`reports/uefi-espboot-r55-indeterminate-20261108.md`
- 静态发现：`reports/uefi-route-b-static-findings-20261108.md`
- 坑：`PITFALLS #559/#560/#561`（前一轮）+ 本轮新增（`BootIntoFastboot` 写死 / `extra_cmdline` 不生效 / 面板非可靠通道）
