
# 替代引导器评估（systemd-boot / Limine）—— EFI-stub 后掉电这个卡点下

> lane: 20261111-bootloader-alternatives。纯主机侧调研，未做任何设备操作。
> 每条结论附 URL 或 file:line；抓取失败明确标注「抓取失败，不采信」。


## §0 结论表（先读这里）
| 路线 | 有价值？ | 怎么用 | 风险 | 证据 |
|---|---|---|---|---|
| systemd-boot | **低**（判别增量≈0） | 仅当需要统一菜单；`linux` 条目直启 EFI-stub 内核或 chainload 均可 | arm64 成熟；无 4G 限制；但交接形态与 GRUB 相同（不碰 EBS） | §1（src/boot/linux.c:1-19,75,105；util.h:113-131；全 src/boot 无 ExitBootServices 调用） |
| Limine | **高** | `PROTOCOL: linux` 直启，自己做 EBS+SetVirtualAddressMap，失败时无 runtime services 续命 | 需要固件提供健全 GetMemoryMap/EBS；SetVirtualAddressMap 依赖 RT 表 | §2（common/lib/misc.c:483；common/protos/linux_risc.c:1,151-155,540-543,576-613,776；GNUmakefile.in:362-368） |
| cmdline 实验组 | **最高·零成本** | `efi=noruntime`（一发判定 RT remap 是否卡点）、`noefi` | 都只作用于 EBS 之后的内核阶段 | §3.3（efi.c:79-84,106；arm-runtime.c:130-152） |
| 固件侧 watchdog 审计 | **高** | 对照 iPXE 先例审 EBS 里 SetWatchdogTimer/平台定时器处理 | 需要改固件 | §3.2（ipxe 9062544；denx 507614） |

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

## §3 EBS 后掉电的公开先例与绕过手段

内核基线：torvalds/linux @ 067c5c24cef23d913b67eaaf71ae67e7169a6620（sparse clone `~/.cache/bootres/linux`）。

### 3.1 内核侧 EBS 调用链（arm64，file:line）
1. stub 里 EBS 封装：`drivers/firmware/efi/libstub/efi-stub.c:391-457` `efi_exit_boot_services()`（stale map key 时 GetMemoryMap+EBS 重试）。
2. `SetVirtualAddressMap` 若固件 RT 表缺该项则强制 `efi_novamap`：`libstub/efi-stub.c:186-188`；novamap 时跳过 RT 描述符映射（:250-254）。
3. 进入 kernel proper 后第一次「碰 EFI」的 initcall：`drivers/firmware/efi/arm-runtime.c:139` `pr_info("Remapping and enabling EFI services.\n")`（arm64 与 arm32 共用 arm-runtime.c）→ `efi_virtmap_init()` 检查 stub 留下的映射，`efi_native_runtime_setup()` 装函数指针，置 EFI_RUNTIME_SERVICES 位（arm-runtime.c:139-152，`early_initcall(arm_enable_runtime_services)`）。
4. **之后 kernel proper 从不再主动调 boot services**；下一个固件交互点 = 第一次运行时服务调用（典型：shutdown/reboot 路径的 `RS->ResetSystem()`，`drivers/firmware/efi/reboot.c:13-49`）。
- 推论：我们日志里 "Remapping and enabling EFI services" 之后、掉电前 ~60-70 s，kernel proper 理论上不碰固件 —— 掉电源更像是**固件/平台侧一个未关闭的计时器**（PMIC/AP watchdog），而不是内核在 EBS 后又调了什么。

### 3.2 公开先例
- **iPXE：固件在 EBS 时忘记关 UEFI watchdog → OS 起来 ~5 分钟后整机重启**（Hyper-V 观测，反例方向= watchdog 忘关；我们的固件方向相反，但证明「EBS 时固件没正确处理 watchdog → 定时整机复位」是一类真实 bug）：
  https://github.com/ipxe/ipxe/commit/9062544f6a0c69c249b90d21a08d05518aafc2ec
- UEFI spec 规定 EBS 成功即禁用 boot-services watchdog：systemd issue 讨论（poettering 引 spec 2.6 p.224 "On successful completion of ExitBootServices() the watchdog timer is disabled"，且 stub 侧在起内核前 SetWatchdogTimer）：https://github.com/systemd/systemd/issues/20623
- **Qualcomm QCS9075：RuntimeServices->ResetSystem() 在 EBS 后 dead-loop，固件挂死**（meta-qcom #2680，「any OS that calls RuntimeServices->ResetSystem() after ExitBootServices hangs in firmware, by construction」）：https://github.com/qualcomm-linux/meta-qcom/issues/2680
- Surface Pro X（arm64）：EFI ResetSystem() 在内核侧崩溃，绕过 = 禁用 efi power-off/reboot（linux-surface 补丁 b294014）：https://github.com/linux-surface/kernel/commit/b294014b26416f247e66d6ed63d4f76bd0c5d233
- Qualcomm X Elite 笔电（Lenovo Yoga Slim 7x）：UEFI app 读地址 0 → **固件直接 reset 回 logo**（AArch64 UEFI 不映射 page 0）：https://github.com/seuros/meridian/pull/6
- 「EBS 后 ~60-70 s 整机硬件掉电」**未找到完全同款公开报告**（上面最接近的是「定时复位」类）。
- 一类「固件在 EBS 里停硬件 watchdog」的争议（U-Boot 邮件列表，Tom Rini 立场：不许停 hw watchdog，ExitBootServices 应最后一次喂狗）：https://lists.denx.de/pipermail/u-boot/2023-February/507614.html

### 3.3 cmdline 旋钮表（都是 kernel proper 侧，作用域注明）
| 旋钮 | 作用 | 证据 | 对「EBS 后掉电」的预期 |
|---|---|---|---|
| `noefi` | kernel proper 完全不用 EFI（RT 不安装） | `drivers/firmware/efi/efi.c:79-84` `early_param("noefi", setup_noefi)` | stub 早已 EBS 完成；只影响 initcall 后的 RT 使用。掉电若是固件计时器，无帮助；若是 RT remap 触发，可证实 |
| `efi=noruntime` | disable_runtime=true，arm_enable_runtime_services 走 "runtime services will be disabled" 分支 | `efi.c:106`；`arm-runtime.c:130-133` | **一发判定「掉电是否发生在 RT remap 之后」**：noruntime 后仍掉电 ⇒ 与 RT 无关，指向固件计时器/PMIC |
| `efi=debug` | EFI_DBG，打印 memmap/调用细节 | `efi.c:102-104` | 取证用 |
| `efi=novamap`（stub 侧） | 让 stub 跳过 SetVirtualAddressMap | `libstub/efi-stub.c:186-188`（RT 表缺 SetVirtualAddressMap 时自动 novamap） | 判定是否 S/VAM 阶段触发固件雷区 |
| `memmap=` / `efi_fake_mem=` | 改内存图 | Documentation/admin-guide/kernel-parameters.txt（本次 sparse clone 未含该文件，见 §5） | 缩小 memmap 项数，试「固件对 map 项数/大小过敏」假设 |
| `efi=old_memmap` | x86-only，不适用 arm64 | efi.c | 不适用 |

注意：以上所有旋钮都在 **EBS 之后** 才生效；如果掉电根因在固件 EBS 内部或 stub 阶段，cmdline 全部无效。

## §4 可执行建议（按「一发就能证实/排除」排序）
1. **低成本·纯 cmdline 实验组**（一次内核启动改参数即可）：`efi=noruntime` + `noefi` 对比跑。若 `efi=noruntime` 下不掉电 ⇒ 卡点在 RT remap/首次 RT 调用；仍掉电 ⇒ 与内核 EFI 使用无关，指向固件侧计时器（PMIC watchdog / AP watchdog），固件 bug。成本：改 1 行 cmdline，≈0。
2. **Limine 直启实验（判别价值最高）**：Limine `PROTOCOL: linux` 直启同一 EFI-stub Image（甚至可试不带 stub 的裸 Image）。它**自己调 EBS+SetVirtualAddressMap**（`~/.cache/bootres/limine common/lib/misc.c:483`、`common/protos/linux_risc.c:540-543`），交接路径与 GRUB→stub 完全不同；且 SetVirtualAddressMap 失败时走「无 runtime services」续命。若 Limine 直启正常 ⇒ 墙在我们固件「EBS 前的最后一段/stub 的 EBS 调用序列」；若同样 60-70 s 掉电 ⇒ 固件计时器坐实。成本：编 limine-uefi-aarch64（已有构建系统，~10 min）+ 配置条目。
3. **固件侧审计**（我们的 Mu 系 UEFI）：查 EBS 实现里 SetWatchdogTimer 的处理、以及有没有「EBS 后启动一个平台定时器但没人喂」的路径；对照 iPXE 先例（3.2 第一条）。成本：源码审计，≈1 h。
4. sd-boot：只做 chainload 或 `linux` 条目直启都行，但**交接形态与 GRUB 几乎相同（不碰 EBS）**，判别增量 ≈ 0，除非前两条都跑完仍需对照。成本中等（要给最小 UEFI 补 LoadFile2 等）。
5. u-boot 邮件线程同款思路的固件改动：让我们的固件在 EBS 时**最后一次喂平台 watchdog 而不是停它**（Rini 立场），或明确停掉 PMIC watchdog 并在内核侧接管。需要固件改动，成本最高，放最后。

## §5 抓取失败 / 未能核实清单
- `Documentation/admin-guide/kernel-parameters.txt`：sparse clone 未包含，`memmap=`/`efi_fake_mem=` 精确语法未逐字核对（https://docs.kernel.org/admin-guide/kernel-parameters.html 可补查）——**不采信为逐字证据，仅作指针**。
- Limine `mm/pmm.c` 分配器细节（是否全 64-bit AllocateAnyPages 落到固件 AllocatePages）：未逐行核。
- systemd-boot 何时首次加入 aarch64 构建支持（NEWS 检索未见明说；Debian/Ubuntu/Arch ARM 现状证明 ≥257 已成熟）：未定位到具体版本号。
- 「EBS 后 60-70 s 硬件掉电」完全同款报告：未找到，不虚构。

