# 替代引导器评估（systemd-boot / Limine）—— EFI-stub 后掉电这个卡点下

> lane: 20261111-bootloader-alternatives。纯主机侧调研，未做任何设备操作。
> 每条结论附 URL 或 file:line；抓取失败明确标注「抓取失败，不采信」。

## §0 结论表
（待填）

## §1 systemd-boot
### 1.1 是否需要 EFI-stub
### 1.2 arm64 现状
### 1.3 EBS / 内存属性行为
### 1.4 内存分配策略
### 1.5 硬依赖协议
### 1.6 能否 chainload 自定义 EFI app

## §2 Limine
### 2.1 是否需要 EFI-stub
### 2.2 arm64 现状
### 2.3 EBS / 内存属性行为
### 2.4 内存分配策略
### 2.5 硬依赖协议
### 2.6 能否 chainload 自定义 EFI app

## §3 EBS 后掉电的公开先例与绕过手段（含 cmdline 旋钮表）

## §4 对我们这套固件的可执行建议

## §5 抓取失败 / 未能核实清单

## §1 systemd-boot（含 systemd-stub）

核对基线：systemd master @ commit 725d40dff2123fa8737b22c58eb8bce9f6a15206（本地浅克隆 `~/.cache/bootres/systemd`，src/boot/*.c）。

### 1.1 是否需要 EFI-stub
- sd-boot 的 `linux`/`initrd`/`options` 条目走「内核 PE/EFI 入口」：`src/boot/linux.c:1-19` 注释明说 "Generic Linux boot protocol using the EFI/PE entry point of the kernel … works for Linux 5.8 and newer on ARM/Aarch64, x86/x68_64 and RISC-V"。
- 机制 = `BS->LoadImage` + `BS->StartImage`（`src/boot/linux.c:75`、`linux.c:105`），即把内核当 EFI 应用启动 → **必须 EFI-stub 内核**。initrd 通过 LoadFile2 LINUX_INITRD_MEDIA_GUID device path 注册（`src/boot/linux.c` 走 `initrd.c` 注册逻辑；cmdline 经 LoadedImageProtocol 传入，`linux.c:2-5`）。
- **结论：是，硬性要求 EFI-stub。我们现在的 Image 带 EFI-stub，直接兼容。**

### 1.2 arm64 现状
- meson 一等公民：`meson.build:1933-1934` `'aarch64' : 'aa64'`，EFI 构建含 aarch64。
- 发行版现状：Debian 出 `systemd-boot-efi-arm64-signed` 257.9（https://tracker.debian.org/news/1680669/accepted-systemd-boot-efi-arm64-signed-25791deb13u1-source-into-proposed-updates/ ）；Ubuntu oracular arm64 有包但一处 SRU 被撤（https://launchpad.net/ubuntu/oracular/arm64/systemd-boot ，bug https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/2098183 ）；buildroot 2026-05 起允许 aarch64 编 sd-boot（https://ratatoskr.run/buildroot/2026/06/17109309 ）。
- 258 NEWS 提到为 arm64 Snapdragon 设备导入 hwid DTB 匹配表（本地 NEWS:2254，"A first set of hwid files for arm64 Snapdragon devices has been imported"）→ 上游已认真对待 arm64+DTB 场景。
- **结论：arm64 支持成熟（v25x 线），无明显「arm64 不可用」缺陷记录。**

### 1.3 EBS / 内存属性行为
- 全 `src/boot/` 中 `ExitBootServices` 只出现在注释/文档语境（`boot-secret.c:13,139`、`tofu.c:191`），**没有任何调用点** → sd-boot 自己不调 EBS、不调 SetVirtualAddressMap、不注册 EBS 事件。它把内核作为 PE 镜像 StartImage，EBS 完全由内核 EFI-stub 自己做。
- 内存属性：仅当固件提供 EFI_MEMORY_ATTRIBUTE_PROTOCOL 时做 W^X 标记（`src/boot/linux.c:110-160`，LocateProtocol 失败即跳过）；DTB 放 EfiACPIReclaimMemory + InstallConfigurationTable（`src/boot/devicetree.c:9-19,105,256,266`），DT_FIXUP 协议可选（`devicetree.c:28-31` 找不到就跳过）。
- **结论：与 GRUB 同一交接形态（不碰 EBS）→ 换 sd-boot 大概率不会改变「EBS 后 60–70 s 掉电」这个现象。判别价值低。**

### 1.4 内存分配策略
- initrd：x86 上先 AllocateMaxAddress UINT32_MAX（below 4G），失败回落 AllocateAnyPages；**非 x86 直接 AllocateAnyPages，无 4 GiB 限制**（`src/boot/util.h:113-131`，注释明说 "On other architectures we do not bother with any restriction on this, in particular as some of them don't even have RAM mapped to such low addresses"）。
- 内核镜像：走 LoadImage（固件分配），另有 "plain AllocatePages() with no extra over-allocation"（`src/boot/linux.c:287`）。DTB：AllocateAnyPages（`devicetree.c:15`）。
- **结论：arm64 上无 4 GiB 下限分配限制，没有 GRUB 那条高位内存问题的对等 quirk。**

### 1.5 硬依赖协议
必须：SimpleFileSystem（读 ESP）、BlockIo/DevicePath（间接）、LoadImage/StartImage、LoadedImage、AllocatePages/Pool。条件性：LoadFile2（initrd，新版 sd-boot 给内核传 initrd 的主通道）、EFI_DT_FIXUP_PROTOCOL（可选，devicetree.c:28）、EFI_MEMORY_ATTRIBUTE_PROTOCOL（可选，linux.c:110-160）、RNG（random-seed，失败有 fallback，`src/boot/random-seed.c`）、TPM（可选，measure.c 全程判存在）、GOP（菜单显示，无显示会退化但 boot 有 timeout 自动走默认条目）。文件系统走 FAT 驱动 = 需要 SimpleFileSystem。
- **对最小 UEFI（BDS 扫 ESP、能起 GRUB）**：SimpleFileSystem+BlockIo+LoadImage+StartImage 已被 GRUB 验证可用；LoadFile2 与 DT_FIXUP 若缺失，sd-boot 的 initrd 传法可能退化（旧内核用 LoadImage 的 initrd 路径），需要实测。

### 1.6 能否 chainload 自定义 EFI app
- 能：sd-boot 自动枚举 ESP/`\EFI/*/` 下 `.efi` 文件作为条目（`type: efi` 或自动发现；文档 https://docs.kernel.org 与 https://www.freedesktop.org/wiki/Software/systemd/systemd-boot/ 之 "loader/entries"，man systemd-boot(7) https://www.freedesktop.org/software/systemd/man/latest/systemd-boot.html ）。也可把我们的 LinuxLoader 放 `\EFI/Linux/` 或 `\EFI/BOOT/` 之外任意目录配 entry。
- **价值判断：仅 chainload 时 sd-boot 与 GRUB 完全等价（都不碰 EBS）→ 单独 chainload 没有判别价值；只有用它的 `linux` 条目直启 EFI-stub 内核（替代 GRUB 的 linux 命令）才有 A/B 价值，而两者交接路径几乎相同。**

## §2 Limine

核对基线：limine master @ commit 89a9512c623a4779cc73e3869383876d54264b28（本地浅克隆 `~/.cache/bootres/limine`）。

### 2.1 是否需要 EFI-stub
- **不需要**。arm64 `linux` 协议走裸内核头（`ARM\x64` magic，Linux booting.rst 的 image header）：`common/protos/linux_risc.c:37-50`（__aarch64__ 的 struct linux_header）、`:151-155`（LINUX_HEADER_MAGIC2 = 0x644d5241）。
- 内核入口 = 裸跳转：关 MMU（SCTLR_EL1/EL2 M 位清零）后 `br kernel_entry`，x0=dtb（`linux_risc.c:576-613`）。**不经过 PE/EFI stub 入口**。
- 但 UEFI 相关数据仍按 EFI-stub 约定写进 /chosen：`linux,uefi-system-table`（:297）、`linux,uefi-mmap-*`（:498-516）、secure-boot 状态（:302-305）、initrd 走 LINUX_EFI_INITRD_TABLE config table（:399-410）。**⇒ 前提是固件在 EBS 前这些 boot services 都健在；它自己 EBS（见 2.3）。**

### 2.2 arm64 现状
- 上游直接支持 aarch64 UEFI 构建：`GNUmakefile.in:187,362-368`（limine-uefi-aarch64 / BOOTAA64.EFI）；README.md:54 "All x86-64, aarch64, riscv64 and loongarch64 (UEFI) systems are supported."
- Linux 直启在 aarch64 上由 `linux_risc.c` 一并实现（文件头 `#if defined(__riscv) || defined(__aarch64__) || defined(__loongarch__)`，:1；`linux_load` :659 为全 arch 入口，menu.c:2505-2506 路由 `PROTOCOL: linux`）。
- CONFIG.md:486 允许 `ARCH: aarch64`；CONFIG.md:325 分页模式 `4level/5level` 支持 aarch64。
- DTB 传递：条目级 `dtb_path` / 全局 `global_dtb`，必填（required=true，`common/protos/linux_risc.c:776` p.dtb = get_device_tree_blob(...)；实现 `common/lib/misc.c:216-`）。initrd 用 `MODULE_PATH`（:203-245）。
- **结论：Limine on arm64 UEFI + Linux 直启 = 上游一等支持，且有 recent arm64 专门代码（cache 清理、EL1/EL2 分支）。**

### 2.3 EBS / 内存属性行为
- **Limine 自己调 EBS**：`common/lib/misc.c:483` `gBS->ExitBootServices(efi_image_handle, efi_mmap_key)`（带 stale-map-key 重试循环 :441-489），EBS 后 arch 层关中断（aarch64 `msr daifset, #15`，:511-513）。
- **它还自己调 SetVirtualAddressMap**（`linux_risc.c:540-543`：runtime 描述符 VirtualStart=PhysicalStart 1:1 后调 gRT->SetVirtualAddressMap）；失败则 `mark_runtime_unmapped()`（:483-497）把 runtime 项 VirtualStart=UINT64_MAX，**「booting without runtime services」**（:545）。
- DTB 在 EBS 前被 fdt_set_chosen 拷好（:498-516 注释 "it gets was copied out before ExitBootServices()"）。
- **判别价值高**：这是三条路线里唯一「bootloader 主动调 EBS + SetVirtualAddressMap」的。若掉电根因在「我们固件的 EBS 实现之后」或「内核 libstub 的 EBS 调用序列」，Limine 自己做 EBS 会走一条完全不同的路径（包括它 failure 时直接无 runtime services 续命）。

### 2.4 内存分配策略
- 全仓无 4 GiB 上限分配；内存图重建逻辑见 misc.c:440-530（按 owned region 切分 EBS 后 map）。内核头要求 PHYS_PLACEMENT 位时按 booting.rst 物理放置规则放内核（linux_risc.c:156-158），未发现 UINT32_MAX 式 below-4G 限制。
- 证据局限：分配走 `mm/pmm.c`（未逐行核）；如需精确到 allocator 页大小需再读（见 §5）。

### 2.5 硬依赖协议
- UEFI 侧：SimpleFileSystem、BlockIo（fs 层）、LoadImage/StartImage 仅在 chainload 用（chainload.c:522,556）、GetMemoryMap/ExitBootServices/SetVirtualAddressMap（直启必需）、AllocatePool/AllocatePages。TPM 仅测到才用（common/lib/tpm.c）。GOP/framebuffer 用于菜单。
- **没有 GRUB/sd-boot 那种 LoadFile2、DT_FIXUP、MEMORY_ATTRIBUTE 硬依赖**；RNG 只做 seed（common/lib/rng_seed.c:168 注释提到 EBS 前读）。
- 最小 UEFI 风险点：它要调 `gRT->SetVirtualAddressMap` —— 我们的 Mu 系固件 Runtime 层是否实现了 SetVirtualAddressMap（以及 GRUB/内核路径从未走过它）需要确认，否则会落到「no runtime services」分支（可接受，见 2.3）。

### 2.6 能否 chainload 自定义 EFI app
- 能：`PROTOCOL: efi`（别名 `uefi`/`efi_chainload`），`path` 指向任意 EFI 应用（CONFIG.md:285-286,349-355）；实现 gBS->LoadImage + StartImage（common/protos/chainload.c:522-556）。
- **价值判断：chainload 模式下 Limine 也不碰 EBS → 无判别价值；判别价值全在 `PROTOCOL: linux` 直启（2.3）——它替我们固件提前做了 EBS+SetVirtualAddressMap，且可走「无 runtime services」交接，直接对「EBS 后掉电」做定性实验。**
