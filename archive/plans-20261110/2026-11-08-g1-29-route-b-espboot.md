# 计划：G1-29 路线 B —— ESP 上放 `boot.img`，由 Mu `LinuxLoader` 变体直接读起（2026-11-08）

> ✅ **已执行完成（2026-11-08 晚）**：判据 `verdict=ESPBOOT_TAGGED`（`reports/uefi-espboot-r58b-success-20261108.md`）。
> 本文件留作方案与判据底稿；现状一律以 `TASKS/README.md` §5 与 `DEVICE/README.md` §1.1 为准。

> 承接 `reports/uefi-grub-esp-handoff-wall-20261108.md`（EFI-stub 交棒撞墙）与
> `reports/uefi-p58-sdccdxe-handoff-success-20261107.md`（`LinuxKernel(dtb,0,0,0)` 这条路已验证）。
> 本文件只写**方案与验收**，不动 SSOT；状态数字以 `TASKS/README.md` 为准。

---

## 0. 为什么是「B + GRUBón」而不是 A

| 事实 | 出处 |
|---|---|
| GRUB 已能从 ESP 起、菜单可用（音量上/下 + 电源确认）、内核 PE 被 LoadImage | 本轮屏照（`[K] esp ld=Success i=1`） |
| 之后 `DBI dump table info not found` + `App Log Flush` 即死，四通道全空 | 同上 + sunuefi 同芯片同型记录 |
| 平台侧差异 = `PlatformMemoryMapLib` 只给 ~469 MiB Conv | `Platforms/PakalaPkg/Device/lenovo-y700g4/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c` |
| `LinuxLoader` 的 `LinuxKernel(dtb,0,0,0)` 路径能跑满到用户态 | p58（`elden_bootpath=uefi`，桌面/WiFi/Waydroid/SD 全在） |

⇒ 不用改固件内存表（A 的风险面），**把已验证的那次跳转做成能从 ESP 读件即可**：
`GRUB 菜单 → chainloader 我们的 LinuxLoader 变体（在 ESP 上）→ 读 \boot\boot.img → 走 p58 同一条 BootLinux()`。

好处：菜单、多内核、免 `boot.img` 槽限制全到手；失败面完全落在已验证路径上；
固件层**零新增**（继续用 p59 世代：`SdccDxe` 已摘、R54 已能定向连 BlockIo）。

## 1. 关键代码事实（2026-11-08 静态核对，`build/uefi-woa-prep/repos/7-mu-lenovo`）

- `BootLinux()` 的取件接口是 `GetImage (Info, &buf, &size, "boot")`，实现（`BootLinux.c:1445`）
  只是**查 `Info->Images[]` 表**——不是直接读分区。
- 表由 `LoadImageAndAuth (BootInfo *Info)`（`Library/avb/VerifiedBoot.c:1658`）填：
  它读 `boot`/`dtbo`/`vbmeta` 分区并做 AVB 校验，再填 `Images[]`。
- `BootLinux()` 内部（`BaseMem` / `UpdateBootParams` / `SetandGetLoadAddr` / `GZipPkgCheck`）
  负责内存图、DTB 修补、ramdisk 装载地址——**这段全部复用，不重写**。
- ⇒ 改动面 = **`LoadImageAndAuth` 增加「ESP 优先」分支**：从**自身所在卷**（`LoadedImage->DeviceHandle`
  上的 `SimpleFileSystem`）读 `\boot\boot.img`（+ 可选 `\boot\dtbo.img`），填 `Images[]`，**跳过 AVB**
  （自签件本来就过不了 AVB；`eden_bootloader=esp` 令牌写进 cmdline 作判据）。

## 2. 交付件（D1–D5）

| # | 动作 | 判据 |
|---|---|---|
| **D1** | 补丁 `patches/uefi/20261108R55-espboot/`：`VerifiedBoot.c` 的 ESP 优先分支（含 `\boot\boot.img` 存在性探测 + 失败回落原分区路径） | 静态：`espfile` 分支在 `LoadImageAndAuth` 入口先试、`EFI_NOT_FOUND` 时走原逻辑 |
| **D2** | 构建 LinuxLoader 变体（`Build/PakalaPkg/RELEASE_CLANGPDB/AARCH64/.../LinuxLoader.efi`），作为 **PE 应用放 ESP**：`\EFI\elden\Loader.efi` | sha256 + `objdump -h` 见 `.text`，体积 ≤ 8 MiB |
| **D3** | ESP 上放 `\boot\boot.img`（`out/boot-elden-vk184.img`，85.6 MB）+ `\boot\cmdline.txt`（可选 `elden_bootloader=esp` 令牌） | `fsck.fat` 干净、`mdir` 可见、sha 与主机件一致 |
| **D4** | `grub.cfg` 增条目：`chainloader ($root)/EFI/elden/Loader.efi` | 菜单可见、选中后链式装载（屏上串口 `[K]` 行） |
| **D5** | 上机 1 发（`fastboot boot` p59 世代 + 菜单选 B 项） | `scripts/uefi-boot-trial.sh` 给 `VERDICT=…`；`/proc/cmdline` 含 `elden_bootloader=esp` 且 `findmnt /` = `/dev/sda17`，`boot_b` sha 不变 |

## 3. 回退（零写盘优先）

- 全程 `fastboot boot`，**不写** `boot_b`/`uefi_a`；`boot_b` sha 作为不变式每发前后比对。
- GRUB 菜单保留「Elden Linux（GRUB 直启）」与「UEFI 设置 / 关机」两项；B 项失败 ⇒ 超时/手选回 A 项或直接断电重启回 `boot_b`（R54 fallback 已验证会回 Linux）。
- ESP 侧新增文件均可单个删除回退；ESP 本身是 GPT 尾部纯追加，删分区即回到 11-08 上午状态。

## 4. 与「可见性」的关系（为什么还留一枚 diag 内核）

B 路线**不需要** fbcon 早期可见性（内核一旦起来，`msm` DRM 自己点屏）。
但若 D5 失败仍要看早期死亡点，备用件已就绪：`out/fbdiag-20261108/Image.fbdiag`
（vk184 同源 + `CONFIG_SYSFB_SIMPLEFB=y`，UTS `7.3.1-debug-fbdiag-00003-gec74c4795a43`）。
注意：**本平台 UEFI 不给 GOP，屏是 Mu 自己用 `Display Reserved` 直涂**（`FrameBufferSerialPortLib`），
所以 `simpledrm` 很可能仍绑不上；它的价值只在「若哪天有 GOP/EFI framebuffer 描述」时。

## 5. 边界

- 固件只出 p60 配方（p59 + R55 若有固件侧改动；R55 本身是**应用到 `boot_a` 之外的 PE 件**，严格说不需要重刷 `uefi_a`）。
- 不碰 `userdata`/GPT 结构；不动机器身份。
- 上机由总管排他执行、走 `scripts/device-lock.sh`；物理动作（按键、插拔、断电）由用户执行。
