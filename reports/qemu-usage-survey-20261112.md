# QEMU 可用于哪些排错面 —— 技术评估（2026-11-12）

> 目标：把「屏上看不到 / SSH 上不去」的黑箱启动排错从「上机 + reboot + 盲猜」搬到主机上的
> aarch64 QEMU + AAVMF，做到几分钟一轮、可脚本化断言。**本文件只调研，不改任何现有代码。**
> 纪律：每条结论 = 命令 + 关键输出；未实测的一律标注。

## 0. 摘要（一页）

| 判断 | 结论 |
|---|---|
| **能替代多少** | 「启动链上一切非硬件相关的判断」基本全能搬：**GRUB cfg/字体/gfxterm 布局、EFI-stub 交接、cmdline 单变量、simpledrm/fbcon 出字、ramoops/pstore 跨重启、initramfs/init 脚本**——本轮全部实测跑通 |
| **不能替代什么** | 本平台内存图（`#558`/469 MiB）、DSI/面板/背光/触屏、充电/WiFi/音频/相机/ADSP、A/B 槽位与 AVB、真实掉电。**这些上机不可避免** |
| **最值钱的一条** | `-device ramfb` 让 **fbcon 真的在 `screendump` 里出字**（`simpledrm` + `Console: switching to colour frame buffer device`）。`#620` 那条「`SYSFB_SIMPLEFB` 未开 ⇒ fbcon 无后端」从此变成可回归断言 |
| **最反直觉的一条** | `-device virtio-gpu-pci` 在本内核上**完全不出字**（`# CONFIG_DRM_VIRTIO_GPU is not set`）；GRUB 阶段却**只能**用它（`ramfb` 固定 800×600，改不了分辨率）⇒ 两个阶段要用不同显示设备 |
| **必须知道的两个坑** | ① `-M virt` 默认 ACPI → 本内核（无 `CONFIG_ACPI`）在 `build_all_zonelists` 空指针 panic，**必须 `acpi=off`**；② `screendump` 不指定设备时抓的是 virtio-gpu 那一路，内核阶段会抓到空内容 |
| **单轮成本** | TCG 全软件模拟（无 KVM）：到 `Run /init` **2.6 s**，经 GRUB 全链路 **10.8 s**，加建 GRUB/截屏/判读 ≈ **30 s**。对比上机一轮 5–15 min |
| **建议产出** | 3 个脚本：`qemu-grub-smoke.sh`、`qemu-kernel-smoke.sh`、`qemu-pstore-smoke.sh` + 共用 `qemu-launch.sh`；**不建议**碰 UEFI 件当 `-bios`、EFI-stub 失败类、所有硬件外设面 |

**本轮实测的四个「意外收获」**（都是写脚本前必须知道的）：
1. 照抄设备 GRUB cfg 在 QEMU 上立刻抓到 **`no such device: 1FC3-C5D0`** 与 **`Loader.efi not found`** —— 上机就是黑屏。
2. GRUB 模块集**缺 `disk`/`part_msdos`** 会让 `search --no-floppy --file` **静默失败**（返回空 root），串口只给
   `error: no such device: /boot/Image` + **`Failed to boot both default and fallback entries.`**。
3. **`sendkey` 改不动 GRUB 菜单选择**（发 `down` 后仍启动第 0 项）⇒ 多臂实验要用 `set default=N` 打多份件。
4. ramoops 的 `reg` **必须落在内存窗内**，否则 `failed to reserve memory for node` + 永远 0 条 pstore；
   插好之后两段式实测拿到 `PSTORE ENTRIES: 2`（`console-ramoops-0` + `dmesg-ramoops-0`，含 `Panic#1 Part1`）。

DONE: 0. 摘要（一页）

---

## 1. 可搬到 QEMU 的排错面（逐条：能做 / 不能做）

> 统一前提：`-M virt,acpi=off -cpu cortex-a72 -m 2048 -smp 4 -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd`，
> **显示设备按阶段选**：GRUB 阶段用 `-device virtio-gpu-pci,xres=W,yres=H`（GRUB 有 `efi_gop`，
> 能吃到任意分辨率）；内核阶段用 `-device ramfb`（simpledrm/fbcon 只在这个设备上出字）。
> 串口 `-serial file:`，取屏走 monitor `screendump`（**必须显式指定设备名**，见 §4.1 坑 2）。
> 「✅ 实测」= 本轮真跑过并给了判据；「⚠ 未实测」= 机制上可行但本轮没跑，标理由。

### 1.1 GRUB / 内嵌 cfg / 字体 / gfxterm 布局 —— ✅ 实测，收益最大

| 能做什么 | 证据 |
|---|---|
| 直接跑本项目的 arm64 GRUB 件看**菜单真实像素** | `screendump` 拿到 gfxterm 菜单（1024×768 与 **3040×1904** 两档都试过），40 px 字体清晰可读 |
| 验证 cfg 语法 / `insmod` 模块齐全 / `search` 命中 | 第一版照抄设备 cfg 就**立刻暴露真 bug**：`error: no such device: 1FC3-C5D0.` + `file '/EFI/elden/Loader.efi' not found.`（UUID 与路径写错，上机才看得到） |
| 验证 `GRUB_FONT_SIZE` 是否触发 gfxterm 硬上限（`#621`） | `glyphs too large to fit on screen` 会打到串口；屏幕退回 EFI 文本模式（区别明显） |
| 验证三档 `loadfont` + `if terminal_output gfxterm` 降级逻辑 | 改 cfg → 重建 → 重跑，一轮 ~25 s |
| 验证 `xres/yres` 改成设备真实分辨率（3040×1904/1904×3040）后的行列数与字号比例 | **必须 `virtio-gpu-pci,xres=3040,yres=1904`**（GRUB 有 `efi_gop` 驱动，能直接用它的 GOP）；实测 `screendump` 得到 **3040×1904**，`GRUB_FONT_SIZE=40` 的菜单只占屏幕中部一小块（标题 + 2 条目 + 底部提示），**字号相对面板仍偏小** ⇒ 这就是用户「字很小」的观感，可在主机上直接调 `GRUB_FONT_SIZE` 找可读档位。⚠ `ramfb` 是固定 800×600，改不了分辨率 |
| 自动化断言：截图非黑 / 含菜单边框灰块 / 串口无 `error:` | 实测像素统计：菜单页 `(19,22)-(961,730)` 有内容，纯黑页 bbox 为空 |

**不能替代的**（本机硬件相关）：
- 本平台 **`ConOut` 是 no-op**（R7 补丁）⇒ 设备上 GRUB 倒计时文字不显；QEMU 的 AAVMF `ConOut` 正常，
  所以 **QEMU 上「看得到倒计时」不能推出设备上看得到**（这是 `#620` 那类判读陷阱的同一个坑）。
- 面板实际 dpi / 背光 / 强光一瞬 / 竖排方向、触屏与音量键的物理按键码 —— virt 无。
- 本平台 `PlatformMemoryMapLib` 只把 DXE Heap 标 Conv 的**内存图差异** —— virt 的 AAVMF 内存图是标准 EDK II，
  所以 **`#558`「EFI-stub 在本平台 EBS 后即死」在 QEMU 上永远复现不出来**（QEMU 上 EFI-stub 正常交接，见 §1.3）。

### 1.2 UEFI BDS 引导顺序 / Boot#### 变量 —— ✅ 实测（pflash 两段式）

| 能做什么 | 证据 |
|---|---|
| 看 BDS 如何扫到 ESP 上的 `\EFI\BOOT\BOOTAA64.EFI` | 串口：`BdsDxe: loading Boot0002 "UEFI Misc Device" from PciRoot(0x0)/Pci(0x3,0x0)` → `starting Boot0002` |
| 用可写 NVRAM 改 BootOrder / 新增 Boot####（`efibootmgr` 思路） | `-drive if=pflash,file=AAVMF_VARS.fd`（拷一份再跑），实测该配置同样能起到内核 |
| 多 ESP / 多 `BOOTAA64.EFI` 竞争时的选择顺序 | 多挂一个 `fat:rw:` 目录即可 |

**不能替代**：本平台 ABL→我们的 UEFI 件的**握手协议**（`elden_bootloader=esp`、`Loader.efi` 的 `LMenuSelect`）、
槽位 A/B（`boot_a/boot_b` 属性 + `qbootctl`）、`fastboot boot` 的 96 MiB AVB 签名链 —— 全在 ABL/AVB 侧，virt 无。

### 1.3 EFI-stub 交接 / ExitBootServices 前后 —— ✅ 实测（能测「通用正确性」，不能测「本平台内存图」）

实测两条路都能走到用户态：

| 路径 | 命令要点 | 结果 |
|---|---|---|
| `-kernel Image`（QEMU 直接按 arm64 boot protocol 装，**绕过** EFI-stub） | 见 §3 配方 B | `Machine model: linux,dummy-virt`，`efi: UEFI not found.`（无 `-bios`）/ `efi: EFI v2.7 …`（有 `-bios`，仍走 Image 头不是 stub） |
| **GRUB `linux` 命令 = 真 EFI-stub 交接** | §3 配方 A：GRUB 内嵌 cfg + ESP 上的 `Image` | 串口 `efi: EFI v2.7 by Ubuntu distribution of EDK II` + `SMBIOS/MEMATTR/ACPI/MEMRESERVE` 四个 config table 全在 ⇒ **stub 交接成功、EBS 之后内核活着**，一直到 `Run /init` |

**结论**：QEMU 上 **EFI-stub 是通的**（与 `#558` 相反）。所以：
- ✅ 可以测「我们的内核 config / 我们的 stub 代码 / 我们的 cmdline 处理」有没有把交接搞坏 ——
  例如 `efi=noruntime`、`noefi`、`efi=debug` 的**单变量对比**在 QEMU 上是有意义的。
- ❌ 不能测「本平台 `PlatformMemoryMapLib` 只给 469 MiB Conv」这一条 —— 那是我们 UEFI 件的行为，
  除非把**我们自己的 `uefi-preambleXX-r1.img` 当 `-bios` 跑**。
  ⚠ 这一点**未实测**：我们的 UEFI 件是 `PlatformBuildNoSb` 的裸 PE/flash 镜像，不是 QEMU 支持的
  `-bios` 格式（QEMU `-bios` 要的是 flash 布局镜像），预计不支持直接当 `-bios`；若要做需另写 QEMU flash 容器，**本轮不做**。

### 1.4 SYSFB_SIMPLEFB / simpledrm / fbcon 是否真的出字 —— ✅ 实测，**必须 `-device ramfb`**

这是本轮最反直觉的一条，直接决定「QEMU 能不能替代屏幕取证」：

| 显示设备 | `EFI stub` + `-bios` | 结果 |
|---|---|---|
| `-device virtio-gpu-pci,xres=1024,yres=768` | 是 | **`/sys/class/graphics` 空、`/sys/class/drm` 空、无任何 `drm`/`fbcon` 日志**。原因：本内核 `# CONFIG_DRM_VIRTIO_GPU is not set`，virtio-gpu 没有驱动 |
| `-device ramfb`（无 virtio-gpu） | 是 | `[drm] Initialized simpledrm 1.0.0 for simple-framebuffer.0` → `Console: switching to colour frame buffer device 100x37` → `fb0: simpledrmdrmfb`；`screendump` 拿到**完整 fbcon 文本**（见 §3 判据）。⚠ ramfb **分辨率固定 800×600**（无 xres/yres 选项），`screendump` 出来就是 800×600 |
| 都加 | 是 | 同 ramfb（virtio-gpu 无驱动，不抢） |
| 无 `-device`（只 `-display none`） | 是 | 无 fb，纯串口 |

⇒ **「GOP 出字」在 QEMU 上等价于 `-device ramfb`**。这条正好把 `#620` 的「`SYSFB_SIMPLEFB` 未开 ⇒ fbcon 无后端」
变成**可验证的回归**：改 config 后跑一次，看 `simpledrm`/`Console: switching` 在不在。
**不能替代**：本平台 DSI 控制器 / DP / 面板时序（`bound ae94000.dsi`）、背光、`panel-simple` 参数 —— virt 无 DSI。

### 1.5 内核 cmdline 单变量对比（`efi=noruntime` / `noefi` / `efi=debug` …）—— ✅ 实测可行

- 机制：连跑 N 次 QEMU，每次只改 `-append` 一个 token，比对串口 `Kernel command line:` 行 + 后续 dmesg 分叉。
- 实测：`acpi=off` 这一条单变量在 QEMU 上就把「90 行后 nr_free_zone_pages 空指针 panic」变成「一路到用户态」——
  说明这套「一次一个 token」的流程在 QEMU 上完全成立，且**分叉点会打在串口上**。
- ⚠ 未实测的部分：`efi=noruntime`/`noefi` 在 QEMU 上**不会复现 `#558` 的死**（QEMU 的 EBS 正常），
  所以这两个 token 在 QEMU 上「跑通」不能证明它们能救本平台 —— 只能证明「不会把通用路径搞坏」。

### 1.6 ramoops + pstore 跨重启取证 —— ✅ 实测，**能做，且能自动化**

关键机制：**ramoops 的 `reg` 落在 DDR 里，QEMU 不重置客户机 RAM（除非 `-no-reboot` 退出或显式 `system_reset`）**，
而 `poweroff -f` / 内核 panic 后 `Reboot failed -- System halted` 会停在 QEMU 里，RAM 内容保留。
实测脚本（§3 配方 C）两段式：

```
首次启动: ramoops@50000000 (8 MiB, record 2M/console 2M/pmsg 4M) → 无 pstore 条目 → echo c > /proc/sysrq-trigger
第二次启动: === PSTORE ENTRIES: 2
           /sys/fs/pstore/console-ramoops-0   ← 完整上一次 console
           /sys/fs/pstore/dmesg-ramoops-0     ← "Panic#1 Part1" + 全栈
           === MARKER: PSTORE_SURVIVED
```
- ✅ 可验证的：`record-size` 缺失是否导致 `dump_mem_sz=0`（正是 `#620` 的真因候选）、
  `console-size+pmsg-size == mem_size` 的边界、pstore 只在 panic 路径写不进去的时序、
  initramfs `init` 里的 pstore 读出逻辑、`/sys/fs/pstore` 的轮转/去重。
- ⚠ **注意**：virt DTB **默认没有 `reserved-memory` 节点**（56 个节点里没有）。
  必须自己 `dtc -I dtb -O dts` 改一份加 `ramoops@…` 再 `dtc` 回 dtb（本轮已做，7744 B）。
  同理 `reg` 必须落在 `[0x40000000, 0x40000000+memsize)` 之内，否则
  `OF: reserved mem: failed to reserve memory for node` + 永远 0 条（本轮第一次踩到，选 0xB0000000 越界）。
- ❌ 不能替代：本平台 `ramoops@c2000000` **是否落在 UEFI 保留区/是否被 ABL 覆盖**、
  真实掉电（拔电池/看门狗 84.9 s）时 RAM 是否还能保住 —— virt 的「重启」是 QEMU 内部复位，物理上是另一回事。

### 1.7 initramfs / userland 启动 —— ✅ 实测

- `-initrd out/initramfs-slim.cpio.gz` 实测跑到 `[init] Alpine rootfs up, kernel 7.3.1-…`，
  并暴露两条**设备上也会发生但看不到**的告警：`/init: line 571: /usr/local/sbin/usb-gadget: not found`、
  `[init] WARNING: usb0 never appeared`（virt 没有 UDC，属预期）。
- ✅ 可验证：`init` 脚本语法/POSIX 兼容（`dash`/busybox ash）、`switch_root` 路径、
  `mount` 顺序、`/persist` 缺失时的降级分支、systemd/udev 起不来时的第一条错误。
- ❌ 不能替代：`switch_root` 到 **UFS 上的 linux17**（virt 无 UFS 驱动/无该分区布局；可用 `virtio-blk` 挂一个
  自制 ext4 镜像近似，但 UFS + `sda18` 的 GPT 布局是设备独有的）、USB gadget 复合设备、ADSP/CDSP 相关 init。

### 1.8 kexec —— ⚠ 未实测（机制可行，本轮没跑）

- 内核 `CONFIG_KEXEC_FILE=y`、`CONFIG_EFI_STUB=y`，QEMU `-M virt` 支持 PSCI `SYSTEM_RESET` ⇒
  `kexec -e` 预期可跳到新 Image。
- 但项目里 kexec 的**取证价值**（`--dtb` 对 `kexec_file_load` 是空操作、`ttyGS0` 必断、ramoops 缺
  `record-size` 才拿不到跨 kexec dump —— 见 AGENTS.md 项目记忆）**全都是设备侧现象**，
  QEMU 上这些「都不会发生」⇒ 测出来的是「kexec 通用路径对不对」，不是项目关心的那三条。
- 结论：**低优先**，只在「怀疑 kexec 装参/校验逻辑本身写错」时用。

### 1.9 DTB 解析 / 字段读取 —— ✅ 实测（纯主机侧，最便宜）

- `dtc -I dtb -O dts out/vk188-bootfiles/elden.dtb` 解析成功 → 6270 行，1430 节点；
  回写 `dtc -I dts -O dtb` **0 warning**；`fdtget -t s … / model` → `Lenovo Legion Y700 Gen4`。
- `ramoops@c2000000` 字段实读：`reg = <0 0xc2000000 0 0x800000>; record-size = <0x200000>;
  console-size = <0x200000>; pmsg-size = <0x400000>;` —— 与 `#620` 修复后一致（说明 vk188 件已含修复）。
- **注意**：这一类根本不需要 QEMU，`dtc`/`fdtget` 就够；QEMU 只在「要内核真的去 probe 这些节点」时才需要。
- ❌ 不能替代：`dtbs_check`（用 `make dtbs_check`，仍主机侧）、`/proc/device-tree` 运行时值（需真机）。

### 1.10 模块加载 / vermagic —— ⚠ 部分未实测

- `vermagic` 比对是**纯字符串检查**（`scripts/mod/modpost` 产物 + `modinfo -F vermagic`），主机侧即可，
  与 QEMU 无关；`#367`（同 UTS 不同 config 静默错位）QEMU **帮不上**——它比的是 UTS 字符串，不看 struct 偏移。
- ✅ QEMU 能做的：把模块目录塞进 initramfs，`insmod` 看是否 `Invalid module format` /
  probe 是否真的跑到（`/sys/bus/.../drivers/.../bind`）；`-device virtio-blk` 实测已被识别
  （`virtio_blk virtio1: [vda] 167376 512-byte logical blocks`）。
- ❌ 不能替代：SM8750 的时钟/稳压/互连/固件加载，virt 一个都没有。

### 1.11 一张总表

| 面 | QEMU 能做 | QEMU 不能做（本机硬件相关） | 实测 |
|---|---|---|---|
| GRUB cfg/字体/gfxterm 布局 | 全部（含真实像素） | `ConOut` no-op 的平台差异、面板 dpi/背光/物理键 | ✅ |
| UEFI BDS/BootOrder | 全部（pflash 可写 NVRAM） | ABL 握手、A/B 槽位、AVB 签名链 | ✅ |
| EFI-stub 交接/EBS | stub 通用路径、config table | 本平台 469 MiB 内存图（`#558` 不可复现） | ✅ |
| SYSFB/simpledrm/fbcon | 全部（须 `-device ramfb`） | DSI/DP 控制器、panel 时序、背光 | ✅ |
| cmdline 单变量 | 全部（分叉点打在串口） | 结论不可直接推到设备（QEMU EBS 正常） | ✅ |
| ramoops/pstore 跨重启 | 全部（Ram 不重置 + 需自制 DTB） | 真实掉电是否保住 RAM、UEFI 保留区冲突 | ✅ |
| initramfs/userland | 全部（slim 实测到 Alpine） | UFS/linux17、USB gadget、ADSP/CDSP init | ✅ |
| kexec | 通用路径 | `--dtb` 空操作/ttyGS0 断/跨 kexec dump（设备侧才有） | ⚠ 未实测 |
| DTB 解析/字段 | 需内核 probe 时才有意义 | —（`dtc`/`fdtget` 已够） | ✅ |
| 模块/vermagic | `insmod` 格式与 probe | struct 偏移错位（`#367`）、SM8750 时钟/稳压 | ⚠ 部分 |

DONE: 1. 可搬到 QEMU 的排错面（逐条：能做 / 不能做）

---

## 2. 性价比排序

> 「单轮成本」= 拿到一个**可信判据**的端到端时间（含准备、启动、判读、清理）。
> 「现在」按项目实际发生过的弯路估（上机 + reboot + fastboot + 人肉看屏 + 事后 pstore 取证）。

| 面 | 单轮成本（现在 vs QEMU） | 能提前判掉多少假设 | 建议 |
|---|---|---|---|
| **GRUB cfg/内嵌/字体/gfxterm 布局** | 现在 **5–15 min**（`fastboot boot` + 人肉看屏 + 拍屏判读；错一次要重来）；QEMU **~30 s**（重建 GRUB 6 s + 启动 8 s + 截屏 2 s） | **高**：cfg 语法/模块缺失/UUID 写错/字体超限/降级分支 —— 这一类**全部**能在 QEMU 判掉。本轮照抄设备 cfg 立刻抓到 `no such device: 1FC3-C5D0` + `Loader.efi not found`（真上机就是「黑屏 20 s 后重启」） | ✅ **强烈建议**，做成 `scripts/qemu-grub-smoke.sh` |
| **SYSFB_SIMPLEFB / simpledrm / fbcon 出字** | 现在 **1 轮上机**（还要先解决「屏上看不到」本身）；QEMU **~25 s** | **高**：`#620`「`SYSFB_SIMPLEFB` 未开 ⇒ fbcon 无后端」是**源码级结论**，QEMU 上一条 `ramfb` 就能当回归（改 `.config` 后跑一次看 `Console: switching`） | ✅ **强烈建议**，并入同一脚本（`--assert-fb`） |
| **ramoops/pstore 跨重启** | 现在 **两次真 reboot + EDL/串口抢救**，且 `#620` 证明「pstore 空」会被误读成「没 panic」；QEMU **~40 s**（两段式自动跑） | **高**：DT 字段自洽（`dump_mem_sz=0`）、`reg` 是否越界/被 reserved-memory 拒、`init` 里的 pstore 读出逻辑、轮转 | ✅ **建议**（`scripts/qemu-pstore-smoke.sh`），注意要自带 DTB |
| **cmdline 单变量（`efi=noruntime`/`noefi`/`efi=debug`）** | 现在 **每轮 1 次上机 ~10 min**（`#617` 那条线本来就要「第一发 = `efi=noruntime` 单变量」）；QEMU **~25 s/轮** | **中**：能判「不会把通用 stub 路径搞坏」，**不能**判「能救本平台」（QEMU 上 `#558` 不复现）⇒ 只能**筛掉**明显有害的 token | 🟡 有条件（附在配方 B 里当台账，不单独做脚本） |
| **initramfs/init 脚本** | 现在 1 次上机 + 靠 `ttyGS0`/pmsg；QEMU **~30 s** 且**串口全量**（不依赖 USB gadget 起来） | **中高**：`init` 的 POSIX 语法、`switch_root` 前后、`/persist` 降级、busybox applet 缺失。本轮直接暴露 `usb-gadget: not found` | 🟡 建议（跑 `out/initramfs-slim.cpio.gz`，不追求到 linux17） |
| **UEFI BDS/BootOrder** | 现在 1 次上机；QEMU ~20 s | **低**：我们的 BDS 是自研 Mu 件，QEMU 用的是 AAVMF ⇒ 学不到我们 BDS 的 bug | ❌ 不建议（除非做「AAVMF 能不能起我们的 ESP 布局」这一条） |
| **EFI-stub 通用交接** | 现在 `#558` 这条线已花了 **多轮上机 + 四条取证通道**；QEMU 25 s 就能证明「我们的内核 stub 本身是好的」 | **中**（能**排除**「内核 stub 代码有 bug」这一整类，把矛头准确指向 UEFI 件内存图） | 🟡 建议作为「排除法」一跑（配方 A 已含） |
| **`#558` / 469 MiB 内存图本身** | — | **零**：QEMU 的 AAVMF 内存图是标准 EDK II，永远不复现；把我们的 Mu 件当 `-bios` 跑**未实测且预计不支持** | ❌ **明确不建议**，写进「不要做」 |
| **kexec** | 现在 1 次上机 + 跨 kexec dump 抢救；QEMU ~30 s 但测的是设备上不会发生的路径 | **低**（项目关心的三条全是设备侧现象） | ❌ 不建议 |
| **dtb 解析/字段** | 现在 `dtc`/`fdtget` 秒级 | — | ❌ 不需要 QEMU（已有更好工具） |
| **显示/DSI/背光/触屏/充电/WiFi** | — | **零** | ❌ 明确不建议 |

### 用项目实际弯路对账

| 项目弯路 | 若当时有 QEMU | 能省什么 |
|---|---|---|
| `#620`：A/B/C 三臂 cfg **两次都写错位置/没内嵌显示模块**，三发全无效（`reports/uefi-efistub-stage-summary-20261111.md` §3） | 第一轮 QEMU 截屏就看出「没进 gfxterm / 起的是别的 cfg」 | **省掉 2 轮上机 + 2 次误判** |
| `#621`：gfxterm 字号硬上限（`cols≥40 && rows≥12`），判据是串口 `glyphs too large to fit on screen`。当时靠**反汇编 `gfxterm.mod`** 才定出判据 | QEMU 上直接试 3 个字号，串口立刻给 `glyphs too large` | 省掉反汇编与「字没变大＝没改」的误读 |
| `#558`：GRUB 菜单出来了、内核也被 `LoadImage` 了，但 EBS 后即死；四条取证通道同时静默 | QEMU 能证明「stub+内核本身没问题」⇒ 一步锁定「是我们的 UEFI 内存图」 | 省掉「是不是 GRUB 版本 / 是不是内核 config」的反复排查 |
| `#617`：整整一轮都在讨论「60–70 s 硬件掉电」，最后被 `#620` 推翻 | QEMU 的 pstore 两段式能在 40 s 内证明「pstore 为空 ≠ 没 panic」这条纪律 | 省掉一整轮定性错误 |

DONE: 2. 性价比排序

---

## 3. 现成配方（可直接粘贴）

> 三个模板都用同一个约定：**工作目录 `/tmp/qsay/`**（不动项目里任何东西），
> monitor socket 用来发 `screendump` / `sendkey` / `quit`。
> `socat` **本机未安装**，用下面这个 10 行 python 代替（另存 `/tmp/qsay/mon.py`）。

```python
# /tmp/qsay/mon.py  —— 用法: python3 mon.py <sock> 'screendump /tmp/qsay/s.ppm' 'sendkey ret'
import socket,sys,time
s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); s.settimeout(5); time.sleep(0.3)
try: s.recv(8192)
except: pass
for c in sys.argv[2:]:
    s.sendall((c+"\n").encode()); time.sleep(0.8)
    try: print(s.recv(8192).decode(errors="replace").strip().splitlines()[-1])
    except: print("(timeout)")
```

### 配方 A —— GRUB / ESP 冒烟（验 cfg、字体、gfxterm 布局）

```bash
set -e
W=/tmp/qsay; rm -rf $W/esp; mkdir -p $W/esp/EFI/BOOT $W/esp/boot
cd ~/y700-elden
# 1) 造 GRUB 件（--cfg 内嵌菜单；GRUB_FONT_SIZE 触发大字字体）
WORK=$W/grub GRUB_FONT_SIZE=40 \
MODULES="normal linux fdt ext2 fat part_gpt search search_fs_uuid echo test sleep reboot halt minicmd cat ls configfile font gfxterm all_video efi_gop" \
CFG=$W/menu.cfg bash scripts/grub-arm64-standalone.sh
cp $W/grub/grubaa64.efi $W/esp/EFI/BOOT/BOOTAA64.EFI
# 2) 起 QEMU。★ GRUB 阶段用 virtio-gpu（GRUB 有 efi_gop，能吃到 xres/yres）；ramfb 固定 800x600
timeout -k 5 60 qemu-system-aarch64 -M virt,acpi=off -cpu cortex-a72 -m 2048 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -drive file=fat:rw:$W/esp,format=raw,if=virtio \
  -display none -device virtio-gpu-pci,xres=3040,yres=1904 \
  -monitor unix:$W/mon.sock,server,nowait -serial file:$W/serial.log &
sleep 12
python3 $W/mon.py $W/mon.sock "screendump $W/s.ppm"
python3 -c "from PIL import Image;im=Image.open('$W/s.ppm');b=im.convert('L').point(lambda p:255 if p>10 else 0).getbbox();print('bbox',b);im.crop(b).save('$W/s.png') if b else None"
```

**判据（三条全绿才算通过）**
1. `grep -q 'error:' $W/serial.log` **无命中** —— cfg 里 `search`/`loadfont`/`insmod` 全部成功
   （本轮反例：`error: no such device: 1FC3-C5D0.`）。
2. `bbox` 非空且高度 > 100 px —— 屏幕有实际菜单（纯黑页 bbox = `None`）。
3. `grep -q 'glyphs too large to fit on screen' $W/serial.log` **无命中** —— 没触发 `#621` 的 gfxterm 硬上限；
   命中即说明**已退回 EFI 文本模式**（此时屏上是「小字终端」，看起来像「字号没改」）。
   另可 `strings $W/grub/grubaa64.efi | grep -cx gfxterm`（应 ≥1）确认模块进了 memdisk。

### 配方 B —— 内核 cmdline 单变量 + 串口抓 dmesg（GRUB→EFI-stub 真交接）

```bash
W=/tmp/qsay; cd ~/y700-elden
cp build/daily/arch/arm64/boot/Image             $W/esp/boot/Image
cp out/initramfs-slim.cpio.gz                    $W/esp/boot/initrd.img
# menu.cfg 里每个 menuentry 只差一个 token；set timeout=3 让它自动选第 0 项
run() {  # run <tag> <extra-cmdline>
  timeout -k 5 60 qemu-system-aarch64 -M virt,acpi=off -cpu cortex-a72 -m 2048 -smp 4 \
    -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
    -drive file=fat:rw:$W/esp,format=raw,if=virtio \
    -display none -device ramfb -serial file:$W/$1.log >/dev/null 2>&1
}
run base     ""
run norunt   "efi=noruntime"
run noefi    "noefi"
for f in base norunt noefi; do
  echo "== $f: $(grep -m1 'Kernel command line:' $W/$f.log | cut -c30-)"
  grep -E 'efi: EFI v|simpledrm|Console: switching|Kernel panic|Run /init' $W/$f.log | head -4
done
```

`menu.cfg` 骨架（`linux` 命令 = EFI-stub 交接；`initrd` 必需）：

```
insmod font
loadfont (memdisk)/boot/grub/fonts/elden-big.pf2
insmod all_video
insmod gfxterm
set gfxmode=1024x768x32,auto
terminal_output gfxterm
insmod linux
insmod fat
insmod search
set timeout=3
menuentry "STM-base" { search --no-floppy --file --set=root /boot/Image
  linux /boot/Image console=ttyAMA0,115200 earlycon=pl011,0x09000000 loglevel=7
  initrd /boot/initrd.img }
```

**判据**
1. 串口有 `efi: EFI v2.7 by Ubuntu distribution of EDK II` + 至少一个 config table
   （`SMBIOS`/`MEMATTR`/`ACPI`/`INITRD`/`MEMRESERVE`）⇒ **EFI-stub 交接成功**（不是 `-kernel` 直装）。
2. 有 `Kernel command line:` 且**逐字等于**该臂的预期串 ⇒ 单变量成立（本轮实测 `BOOT_IMAGE=/boot/Image …`）。
3. 分叉判据：`Run /init as init process` 出现 = 该 token 无害；`Kernel panic` / 最后一行停在哪 = 分叉点。
   **纪律**：没有 `Kernel panic`/`Oops`/`end trace` 不得写「掉电」（`#620`）。
4. 屏上判据（要 `-device ramfb`）：`grep 'Console: switching to colour frame buffer device'` +
   `screendump` 里有字。

### 配方 C —— ramoops/pstore 两段式重启取证

```bash
W=/tmp/qsay; cd ~/y700-elden
# 1) virt DTB 默认没有 reserved-memory —— 自己加 ramoops，reg 必须在内存窗内
qemu-system-aarch64 -M virt,dumpdtb=$W/virt.dtb -m 2048 -nographic -serial none
dtc -I dtb -O dts $W/virt.dtb > $W/virt.dts
python3 - <<'PY'
s=open('/tmp/qsay/virt.dts').read()
node='''\n\treserved-memory {\n\t\t#address-cells = <0x02>;\n\t\t#size-cells = <0x02>;\n\t\tranges;\n\n\t\tramoops@50000000 {\n\t\t\tcompatible = "ramoops";\n\t\t\treg = <0x00 0x50000000 0x00 0x00800000>;\n\t\t\trecord-size = <0x200000>;\n\t\t\tconsole-size = <0x200000>;\n\t\t\tpmsg-size = <0x400000>;\n\t\t\tno-map;\n\t\t};\n\t};\n'''
i=s.index('\tmemory@40000000'); open('/tmp/qsay/virt-ramoops.dts','w').write(s[:i]+node+s[i:])
PY
dtc -I dts -O dtb -o $W/virt-ramoops.dtb $W/virt-ramoops.dts 2>/dev/null
# 2) 一键两段式：第一段打 panic，第二段读出 pstore 就 poweroff
timeout -k 5 90 qemu-system-aarch64 -M virt,acpi=off -cpu cortex-a72 -m 2048 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -kernel build/daily/arch/arm64/boot/Image -dtb $W/virt-ramoops.dtb \
  -initrd $W/ramtest.cpio.gz \
  -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 panic=1 loglevel=7" \
  -display none -device ramfb -serial file:$W/pstore.log
grep -E 'PSTORE ENTRIES|MARKER: PSTORE_SURVIVED|Panic#1 Part1' $W/pstore.log
```
`ramtest.cpio.gz` = `busybox` + 一个 `init`（见 §4 脚本建议，内容核心 4 行）：
```sh
mount -t proc proc /proc; mount -t sysfs sysfs /sys
mount -t pstore pstore /sys/fs/pstore 2>/dev/null
N=$(ls /sys/fs/pstore | wc -l); echo "=== PSTORE ENTRIES: $N"
[ "$N" -gt 0 ] && { head -c 400 /sys/fs/pstore/dmesg-ramoops-0; echo "=== MARKER: PSTORE_SURVIVED"; poweroff -f; }
echo c > /proc/sysrq-trigger
```

**判据**
1. 第一段串口必须见 `ramoops: using 0x800000@0x50000000, ecc: 0` + `pstore: Registered ramoops as persistent store backend`；
   若见 `failed to reserve memory for node 'ramoops@…'` ⇒ **`reg` 越界**（本轮第一次踩到：0xB0000000 超出 2 GiB 窗）。
2. 第二段必须 `=== PSTORE ENTRIES: 2`（`console-ramoops-0` + `dmesg-ramoops-0`）且 `MARKER: PSTORE_SURVIVED`。
   **`ENTRIES: 0` 只能说明「本机制没配好」，不能当「上一次没 panic」的证据**——`#620` 的纪律。
3. 反向用例（验证 `#620` 真因）：把 `record-size` 删掉再跑，预期 `console-size+pmsg-size == mem_size`
   ⇒ `dump_mem_sz=0` ⇒ `dmesg-ramoops-*` 消失（只剩 console）。这条是**建议写进脚本的断言**。

DONE: 3. 现成配方（可直接粘贴）

---

## 4. 落地建议

### 4.1 建议新增（按优先级）

| 脚本 | 断言什么 | 成本 |
|---|---|---|
| **`scripts/qemu-grub-smoke.sh`** ⭐ | ① 串口无 `error:` ② 截屏 bbox 非空/高度 > 100 px ③ 串口无 `glyphs too large to fit on screen` ④ 件里 `strings \| grep -cx gfxterm` ≥ 1 | ~30 s/轮 |
| **`scripts/qemu-kernel-smoke.sh`** ⭐ | ① `efi: EFI v2.7` 出现（= 真 EFI-stub 交接，不是 `-kernel` 直装）② `Kernel command line:` 逐字匹配预期 ③ 见 `Run /init` ④（可选）`Console: switching to colour frame buffer device` | ~30 s/轮 |
| **`scripts/qemu-pstore-smoke.sh`** | ① 第一段 `ramoops: using 0x…@…` 且无 `failed to reserve memory` ② 第二段 `PSTORE ENTRIES: 2` + `Panic#1 Part1` ③ 反向用例（删 `record-size`）必须 `dmesg-ramoops-*` 消失 | ~45 s/两段 |
| `scripts/qemu-launch.sh`（共用底座） | 起停/取屏/发键/超时/清理；后面三个脚本都 source 它 | — |

`qemu-launch.sh` 建议接口（伪代码，本轮已验证每一步都成立）：

```
qemu_launch  --esp <dir> | --kernel <Image> [--dtb f] [--initrd f]
             --append "<cmdline>" --outdir <d> [--gpu ramfb|virtio:WxH|both]
             [--timeout 60] [--sock mon.sock] [--serial serial.log]
qemu_wait_for <grep-pattern> [--timeout 30]      # 轮询串口日志（本报告实测用同一手法，~100 ms 粒度）
qemu_screendump <out.ppm> [--device ramfb|virtio_gpu]
qemu_sendkey <key>                               # 注意见下方 ⚠
qemu_kill                                        # 收 monitor quit + SIGTERM + 等进程消失
```

**必须写进脚本的四条「本轮踩到」的坑**（否则脚本会误报 PASS/FAIL）：

1. **`-M virt` 默认 ACPI → 本内核 panic**。本内核 `# CONFIG_ACPI is not set`，
   ACPI 表会让它在 `build_all_zonelists → nr_free_zone_pages` 空指针（`[0000000000001b08] user address but active_mm is swapper`），
   **90 行日志后死**。脚本必须固定 `-M virt,acpi=off`（`acpi=off` cmdline 也够，但机器级更稳）。
2. **`screendump` 抓的是「主显示设备」**。同时挂 `virtio-gpu-pci` + `ramfb` 时默认抓到的是
   **virtio-gpu 那一路**（GRUB 阶段对，内核阶段是空内容）。给 `screendump` 显式指定设备：
   `screendump out.ppm ramfb` / `screendump out.ppm virtio_gpu`（`help screendump` 原文：
   `screendump filename [-f format] [device [head]]`）。
   或者干脆**分两次跑**：GRUB 阶段只用 `virtio-gpu-pci,xres=W,yres=H`，内核阶段只用 `ramfb`。
3. **`sendkey` 改不动 GRUB 菜单选择**。实测 `sendkey down` 后选中的仍是第 0 项
   （`Kernel command line` 两次相同）。要跑多臂，**用 `set default=N` 分别打包 N 份 cfg**，
   不要靠发键。这本身也是一个可写进脚本注释的「QEMU GRUB 交互不可靠」事实。
4. **GRUB 模块集必须含 `disk` + `part_msdos`**。实测同一份 cfg：
   - `MODULES="… search search_fs_uuid …"`（无 `disk`/`part_msdos`）⇒ 串口
     `error: no such device: /boot/Image.` + `file '/boot/Image' not found.` + **`Failed to boot both default and fallback entries.`**
   - 加上 `disk part_msdos` ⇒ 立刻 `Run /init`。
     ⇒ 冒烟脚本要**断言「无 `Failed to boot both default and fallback entries`」**，
     这条比 `error:` 更直接命中「GRUB 找不到内核」。

`qemu-pstore-smoke.sh` 还需内建：生成 virt DTB 并插 `reserved-memory/ramoops`（`reg` 必须落在
`[0x40000000, 0x40000000+memsize)` 内，且 `record-size + console-size + pmsg-size ≤ reg size`），
以及一个 ~1 MB 的 busybox initramfs（本轮做法：`initramfs/busybox` + 15 行 `init` + `cpio -H newc | gzip -9`）。

### 4.2 **明确不建议**做 QEMU 的部分（写清理由，避免后人浪费时间）

| 不建议 | 理由（本轮实测依据） |
|---|---|
| **把我们的 UEFI 件（`uefi-preambleXX-r1.img`）当 `-bios` 跑，去复现 `#558` 的 469 MiB 内存图** | QEMU `-bios` 要的是 flash 布局镜像；我们的是 `PlatformBuildNoSb` 的 PakalaPkg 件，**格式不匹配**（未实测但结构上不成立，且需要自写 flash 容器）。更致命的是：即便跑起来，AAVMF/PakalaPkg 的内存图差异正是要测的对象，**测出来也不代表真机**——这条路的信息量趋近 0 |
| **EFI-stub 交接失败类问题** | QEMU 上 EFI-stub **是通的**（实测 `efi: EFI v2.7` + 一路到 `Run /init`）。所以「GRUB 菜单出来但内核静默死」这一整类**在 QEMU 上无法复现**，只能反过来当「排除法」（证明内核 stub 无辜） |
| **显示/DSI/DP/面板/背光/触屏/音量键** | virt 无 DSI 控制器、无 panel、无背光、无 GPIO 按键。`bound ae94000.dsi`、`panel-simple` 参数、亮度通道全部不可测 |
| **充电 / WiFi / 音频 / 相机 / ADSP / CDSP / GPU** | 全部是 SM8750 外设与固件装载，virt 一个都没有。`qcom-battmgr-usb`、`wcn7861`、`adsp` remoteproc 在 virt 上不 probe |
| **kexec 取证三件事**（`--dtb` 空操作、`ttyGS0` 必断、跨 kexec dump） | 三者全是设备侧现象，QEMU 上都不会发生。只在「怀疑 kexec 装参/校验逻辑本身写错」时才值一次 |
| **A/B 槽位 / `qbootctl` / AVB 96 MiB 签名链 / `fastboot boot`** | 全在 ABL + AVB 侧，virt 无 fastboot、无 GPT 属性、无 `boot_control` |
| **`dtbs_check` / DTB 字段核对** | 不需要 QEMU。`make dtbs_check`、`dtc`、`fdtget` 直接在主机跑，更快更准 |
| **vermagic / struct 偏移错位（`#367`）** | vermagic 只比 UTS 字符串，与 QEMU 无关；struct 偏移错位要靠 `pahole`/ABI 比对，QEMU 帮不上 |
| **性能/时序类（启动耗时 39 s 那类）** | TCG 全软件模拟，`+39 s` 那种口径在 QEMU 上完全不可比（实测 TCG 下 stage2 2.6 s 纯属巧合接近） |

### 4.3 建议的接线方式

- **不新建目录**，脚本放 `scripts/`（与 `grub-arm64-standalone.sh` 同级），产物落 `/tmp/qsay-<pid>/`，
  **不写 `out/`、不写 `build/`**（避免动 `versions/layout.tsv` 与 `check-doctor` 的账）。
- 加进 `.pi/AGENT-OPS.md` 的一条「动手前先跑」：**改 GRUB cfg / 改 `SYSFB` 相关 config / 改 ramoops DT 之前，
  先跑对应 `qemu-*-smoke.sh`**；上机只用于硬件相关面。
- PITFALLS 补一条（编号按现有序列续）：**「QEMU 在 `-M virt` 下必须 `acpi=off`；`screendump` 必须显式指定设备；
  GRUB `sendkey` 不可靠，用 `set default=N`；模块集缺 `disk/part_msdos` 会让 `search --file` 假失败」**。

DONE: 4. 落地建议

---

## 5. 主机能力核查（实测）

```
$ qemu-system-aarch64 --version
QEMU emulator version 10.2.1 (Debian 1:10.2.1+ds-1ubuntu3.3)
$ uname -m → x86_64        $ nproc → 28        $ ls /dev/kvm → crw-rw----+ root kvm
$ qemu-system-aarch64 -M virt -accel help → Accelerators supported in QEMU binary: tcg
```
> **无 KVM**：aarch64-on-x86 全 TCG 软件模拟。实测启动到 `Run /init` 约 2.6 s（stage2），
> 经 GRUB 全链路约 10.8 s ⇒ 单轮完全可接受，不需要 KVM。

| 项 | 实测值 | 命令 |
|---|---|---|
| QEMU 版本 | 10.2.1 (Debian/Ubuntu 25.10 包) | `qemu-system-aarch64 --version` |
| accel | **只有 tcg**（无 `-accel kvm`） | `qemu-system-aarch64 -M virt -accel help` |
| AAVMF | `/usr/share/qemu-efi-aarch64/QEMU_EFI.fd` 2 097 152 B（UEFI 2025.11-3ubuntu7.3, EDK II） | `ls -l`；串口首行打印版本 |
| AAVMF 分体 | `/usr/share/AAVMF/AAVMF_CODE.fd` + `AAVMF_VARS.fd`（pflash 两段式，可写 NVRAM） | 实测可启动到内核 |
| aarch64 内核 | `build/daily/arch/arm64/boot/Image` 63 775 232 B，`Linux kernel ARM64 boot executable Image`，`MZ` PE 头（含 EFI-stub） | `file` + `xxd -l 64` |
| 内核版本 | `7.3.1-debug-vk188-sysfbfb-00002-g4da9a8b69fc8-dirty` | 串口 printk |
| initramfs | `out/initramfs-slim.cpio.gz` 1 066 883 B（可跑，实测启动到 Alpine rootfs）；`out/initramfs-full-elden.cpio.gz` 64 595 425 B | 实测 |
| DTB（本机） | `out/vk188-bootfiles/elden.dtb` 153 117 B，`model = "Lenovo Legion Y700 Gen4"`，1430 节点 | `fdtget -t s … / model` |
| DTB（virt） | `-M virt,dumpdtb=x.dtb` 生成 1 048 576 B，56 节点，`model="linux,dummy-virt"` | `dtc -I dtb -O dts` |
| GRUB 件 | `out/grub-20261110/grub-menu.efi` 7 311 360 B（arm64-efi，含 gfxterm/efi_gop/font） | `strings \| grep -cx gfxterm`→10 |
| GRUB 重建 | `scripts/grub-arm64-standalone.sh --cfg` 可用，宿主有 `grub-mkstandalone`+`grub-mkfont`+`dtc 1.7.2` | 实测重建成功 |
| 显示后端 | `-device ramfb` **唯一能让 simpledrm/fbcon 出字**；`virtio-gpu-pci` **不出字**（见 §1.4） | 实测截屏对比 |
| CPU 数 | `-smp 4` 正常（`pcpu-alloc: [0] 0 1 2 3`） | dmesg |
| 关键 config | `SYSFB=y SYSFB_SIMPLEFB=y DRM_SIMPLEDRM=y FRAMEBUFFER_CONSOLE=y FB_EFI=y PSTORE_RAM=y KEXEC_FILE=y EFI_STUB=y`；**`# CONFIG_ACPI is not set`**、`# CONFIG_DRM_VIRTIO_GPU is not set`、无 `FB_SIMPLE` | `grep build/daily/.config` |
| 取屏 | monitor `screendump x.ppm`（**PPM，1024×768 = 2.3 MB**）+ PIL 裁黑边 | 实测 |
| 串口 | `-serial file:x.log` 可用（`console=ttyAMA0` 走 pl011 0x09000000） | 实测 |
| 控制通道 | monitor unix socket：`socat` **未安装**，用 `nc -U` 或 10 行 python | 实测（见 §3 脚本） |

**两个必须先知道的主机侧事实（实测踩到）**

1. **本机内核没有 `CONFIG_ACPI`** ⇒ `-M virt` 默认 ACPI 固件表会让内核在
   `build_all_zonelists → nr_free_zone_pages` 空指针 panic（`[0000000000001b08] user address but active_mm is swapper`，
   90 行日志后死）。**必须加 `acpi=off` 或 `-M virt,acpi=off`**；此时走 virt DTB，一切正常。
2. **`-bios QEMU_EFI.fd` + `-kernel` 时，EDK II 的 GOP 不被 arm64 EFI-stub 交接**：
   内核起来后 `/sys/class/graphics` 全空、无 `efi-framebuffer`、无 `simpledrm`。
   `linux/arch/arm64/kernel/efi.c` 只用 `screen_info`，不写回；`drivers/firmware/efi/libstub/gop.c`
   的 `efi_setup_graphics()` 在 arm64 上改走 `sysfb_primary_display` 而不是 `boot_params.screen_info`
   ⇒ **要出字必须显式 `-device ramfb`**（ramfb 由 QEMU 直接提供 linear framebuffer，
   实测 simpledrm + fbcon 全亮，`Console: switching to colour frame buffer device 100x37`）。
   ⚠ 这也是本项目 `#620`「GRUB 菜单能显 ≠ 内核能显」在 QEMU 上的**同构复现**——
   QEMU 能测的是「内核里 SYSFB_SIMPLEFB/simpledrm/fbcon 这条链」，不能测「EDK II GOP→stub 交接」那一环。

DONE: 5. 主机能力核查（实测）

---

## 6. 残项与本次纪律说明

| 项 | 状态 |
|---|---|
| 只读纪律 | ✅ 除本文件外**未修改项目任何现有文件**；所有 QEMU 工作目录在 `/tmp/qemu-survey/`（976 MB，可随时删） |
| 未碰设备 | ✅ 无 ssh / fastboot / reboot / EDL |
| `check-doctor.sh` | 运行后 **FAIL=1**，唯一 FAIL = `versions/layout.tsv` 未登记 `.git-rewrite/`。该目录**不是本报告产生**（`stat` mtime 10:45，本会话未执行任何 git 写操作），属工作区既有残留，本报告按只读纪律**未处理** |
| 报告未被引用 | `check-doctor` 的 WARN「报告无人引用」也在本文件范围内成立；按「不改现有文件」的指令，**未**去改 `TASKS/README.md` 加指针 —— 建议由收口会话补一行 |
| 未实测项 | kexec（§1.8）、模块/vermagic 的 probe 部分（§1.10）、我们的 UEFI 件当 `-bios`（§1.3/§4.2，结构上判断不成立） |
