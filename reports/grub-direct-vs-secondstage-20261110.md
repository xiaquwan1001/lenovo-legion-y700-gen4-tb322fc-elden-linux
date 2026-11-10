# 直接 GRUB → EFI-stub 内核 为什么掉电，而「二级 Loader」没事

日期：2026-11-10 · 线：G1-29（GRUB/EFI-stub 交接墙，`PITFALLS #558`）· 纯联网调研 + 静态分析（**未碰设备**）
证据级别标注：**实测**（本仓或同芯片项目的机上数据）／**静态**（源码/反汇编/构建物可复核）／**推断**（无直接证据）
时间盒：45 min，已用完；未取证项见 §6。

---

## §1 一句话结论

**直接 GRUB 掉电的根因不是 GRUB 做得不好，而是「走 EFI-stub 这条数据结构」在我们平台上必然落到一个薄内存契约上：**

1. **主根因（实测＋静态，置信最高）＝ EFI 内存契约**：EFI 路径 `reserve_regions()` 会 `memblock_remove(0, PHYS_ADDR_MAX)` 丢掉 DT 声明的 ~15 GiB，只用 EFI map 重建，而我们的 `PlatformMemoryMapLib.c` **只把 DXE Heap（0xB90C0000+0x1D500000 ≈ 469 MiB）标 Conv**，其余 DDR 全 Reserv ⇒ 内核只看到 ~469 MiB（同芯片项目实测可用 WB **383.7 MiB**）。我们的二级 loader **完全不走这条路**（见 `pc2` 实验：把它加到 612 MiB 后现象从「全静默」变成「只剩背光→掉电」，说明这条链确实是致死路径的第一环）。
2. **结构性差异（静态，置信最高）＝ 我们其实没用 EFI-stub**：GRUB 的 arm64 `linux` 命令必须 `LoadImage`+`StartImage` 内核 PE，由**内核自己的 stub** 做初始化并调 `ExitBootServices`（GRUB 源码＋Ard Biesheuvel 的原文都这么说）；而我们的 `LinuxLoader` 是**自己调 EB、再按旧 arm64 协议 `x0=0,x1=0,x2=dtb` 直接跳 `Image`**（本仓反汇编实证），内核侧 `dmesg` 稳定打印 `efi: UEFI not found.`。⇒ 二级 loader 不是「更聪明」，而是**根本不在那条路上**：不重建 EFI memblock、不用 EFI runtime、不靠 FDT config table、不走 LoadFile2 initrd、不在 LoaderCode 页上重映射属性。

**次根因（实测）＝ 观测盲区**：EFI 路径下四条取证通道同时失效（无 `CONFIG_SYSFB_SIMPLEFB` 早期 fbcon、ramoops 0.08 s 才注册、SSH 由 initramfs 起、`ConOut` 被 R7 补丁设成 no-op ⇒ stub 的 `efi_info()` 也全丢），所以「死在哪一步」目前**没有**任何直接证据。

---

## §2 机制层事实（源码级）

### 2.1 GRUB 侧（arm64 = 通用 EFI loader）

文件：`grub-core/loader/efi/linux.c`（上游同构；可读镜像 <https://github.com/erofs/grub-erofs/blob/master/grub-core/loader/efi/linux.c>）

| 事实 | 位置/证据 |
|---|---|
| `linux` 命令**先把内核文件整份读进 `grub_efi_allocate_any_pages(kernel_size)` 的一份拷贝**（→ LoaderData），再 `LoadImage`（Mu 的 PE loader 又分配一份 LoaderCode）⇒ **同一份 Image 在内存里存两份**（≈40–63 MB ×2） | `grub_cmd_linux()`：`kernel_addr = grub_efi_allocate_any_pages(...)` → `grub_file_read()`；随后 `grub_arch_efi_linux_boot_image(kernel_addr, kernel_size, args)` |
| 交给固件的是一个 **memory-mapped device path**（`start=addr,end=addr+size`, `memory_type=GRUB_EFI_LOADER_DATA`）+ `SourceBuffer=addr`，然后 `boot_services->load_image(...)`，再 **`start_image(image_handle,0,NULL)`** | `grub_arch_efi_linux_boot_image()` |
| cmdline 通过 `loaded_image->load_options` 以 **UCS-2** 传入（不是 DT `/chosen/bootargs`） | 同上（`grub_utf8_to_utf16`） |
| initrd 走两条路：`major_image_version>=1` ⇒ 安装 **`EFI_LOAD_FILE2_PROTOCOL`**（`LINUX_EFI_INITRD_MEDIA_GUID`）；否则 arm64 把 initrd 拷到内存并写 `/chosen` 的 `linux,initrd-start/-end` | `grub_cmd_initrd()` / `finalize_params_linux()` |
| 引导前 `finalize_params_linux()` 调用 `grub_fdt_load(EXTRA_SPACE)`（取固件 DT config table 的**副本**）→ 改 `/chosen` → `grub_fdt_install()`（**重装 DT config table，不是把 dtb 指针塞进 x0**） | 同上 |
| **GRUB 自己不调 `ExitBootServices`（arm64/x86-efi 通用 loader）**；x86 legacy loader 才由 GRUB 调 EB | Ard Biesheuvel, `[PATCH v2 6/6]`：*"This will launch the Linux kernel via its EFI stub, which performs its own initialization in the EFI boot services context before calling ExitBootServices() and performing the bare metal Linux boot."* — <https://lists.nongnu.org/archive/html/grub-devel/2023-05/msg00053.html> |
| GRUB **不注册** ExitBootServices 事件、不做 `SetVirtualAddressMap`、不碰内存属性；它的 heap/模块/内核副本在 EB 后按其内存类型（LoaderData/BSData）由固件回收或交给内核 | 同源码（无相关调用）；属静态缺失 |

### 2.2 内核 EFI-stub 侧（本仓 `linux/`，7.3 线）

| 事实 | 位置 |
|---|---|
| 群里函数：`efi_pe_entry` → `handle_kernel_image()`（arm64 只做重定位决策）→ `efi_boot_kernel()` → `allocate_new_fdt_and_exit_boot()` → `efi_exit_boot_services()` → `efi_enter_kernel()` | `drivers/firmware/efi/libstub/arm64-stub.c:17-44`、`fdt.c:344-362` |
| **FDT 来源顺序**：`dtb=` cmdline（需关 SecureBoot）→ **EFI DT config table**（`get_fdt()` = `get_efi_config_table(DEVICE_TREE_GUID)`）→ 否则「Generating empty DTB」 | `fdt.c:249-272`、`fdt.c:364-378` |
| 新建 FDT：`efi_allocate_pages(MAX_FDT_SIZE = SZ_2M)`，`update_fdt()` 写入 cmdline + `linux,uefi-system-table` + `linux,uefi-mmap-*`，**并在 EBS 那一发里 `update_fdt_memmap()` 把最终 map 塞进 FDT** | `fdt.c:276-292`、`fdt.c:191-206`、`fdt.c:208-210` |
| **arm64 上 `SetVirtualAddressMap` 通常根本不调**：`VA_BITS_MIN >= 48 && !system_needs_vamap()` ⇒ `efi_novamap = true`；我们 `CONFIG_ARM64_VA_BITS=52` ⇒ 满足 | `libstub/arm64.c:60-68`；配置见 `patches/config-vk163-modular-20261025:474-477` |
| `efi=novamap` 也可由 cmdline 强制（`parse_option_str(val,"novamap")`）；novamap 时连 `efi_alloc_virtmap()` 都跳过 | `efi-stub-helper.c:94`、`fdt.c:235-241`、`fdt.c:297-298` |
| 执行位置决策：KASLR 需要 `EFI_RNG_PROTOCOL`，拿不到就 `efi_nokaslr=true` ⇒ **就地执行**（只要 2 MiB 对齐且 `_end < EFI_ALLOC_LIMIT`），否则 `efi_allocate_pages_aligned(2 MiB, EFI_LOADER_CODE)` + `memcpy` + `efi_icache_sync` + `efi_remap_image` | `libstub/kaslr.c:126-154` |
| `efi_remap_image()`：只 **warn 不 fail**。若固件有 `EFI_MEMORY_ATTRIBUTE_PROTOCOL` 且该页当前带 `XP`，则 `clear_memory_attributes(XP)` 让代码可执行；失败**继续跑**（后果=跳进不可执行页） | `efi-stub-helper.c:725-777` |
| 内核侧 `reserve_regions()`：**`memblock_remove(0, PHYS_ADDR_MAX)` 丢弃 DT memory，再按 EFI map `early_init_dt_add_memory_arch()`**；usable 还要求 `EFI_MEMORY_WB` | `drivers/firmware/efi/efi-init.c:166`、`:138-160` |
| ⇒ **EFI 路径下 DT 的 `/memory`（15 GiB）完全作废**；DT 的 `/reserved-memory` 仍在 `arm64_memblock_init()` 里处理（`no-map` 落到 memblock 之外时静默失败） | 同上 + `arch/arm64/mm/init.c` |

### 2.3 我们的二级 loader 到底做了什么（本仓实证）

| 事实 | 证据 |
|---|---|
| `BootLinux` **自己** `GetMemoryMap` → `gBS->ExitBootServices(gImageHandle, MapKey)`，之后才跳内核 | `patches/uefi/20261107R33-true-nobs/0001-eb-true-nobs-and-markers.patch:191-211`（"Don't do anything between the GetMemoryMap() and ExitBootServices()"）；R41 眉注："`eb-go`/`eb-ret st=` 都出现过 ⇒ `ExitBootServices()` 本身完全正常" |
| 跳转有**三条互斥出口**，主路径是**旧 arm64 协议**：`0x5c9c blr x8`，`x0=0, x1=0, x2=dtb`；另有 `0x5d44 blr x19`（`x0=dtb,x1=x2=x3=0`）与 AArch32 路径 | `reports/uefi-p38-static-verify-20261107.md:95-99`（反汇编 179 条指令可达性分析） |
| 工作路径的内核侧自证：**`efi: UEFI not found.`**（内核根本没拿到 systab）、`[Firmware Bug]: Kernel image misaligned at boot`（连 2 MiB 对齐都不满足也照跑） | `reports/trials/20261023T121128Z-q28disp-v2/dmesg.txt:7-8`（同类多份一致） |
| 所以二级 loader **不重建 EFI memblock**（用 DT 15 GiB）、**不注册 EFI runtime**、**不靠 FDT config table**（直接把 ABL 的 DTB 物理地址放 x2）、**不需要 LoadFile2**（initrd 打进 boot.img）、**不在 LoaderCode 页上做任何属性重映射** | 由上两条直接推出（静态） |

**这张表就是「为什么二级 loader 更稳」的全部答案**：两条路在 `ExitBootServices` 之后**不再共享任何一行代码与任何一个数据结构**。

---

## §3 假设表

> 列：假设 / 支持证据 / 反对证据 / 判别实验 / 证据级别

| # | 假设 | 支持证据 | 反对证据 | 判别实验（成本） | 级别 |
|---|---|---|---|---|---|
| **H1** | **EFI 内存映射贫瘠**（只有 DXE Heap ≈469 MiB Conv；内核丢 15 GiB，memblock 在薄内存上重建，后续 CMA/shared-dma-pool/paging 阶段炸） | `PlatformMemoryMapLib-lenovo-y700g4.c`（DXE Heap 是唯一 `Conv`，其余 Reserv）；`efi-init.c:166` 丢 DT memory；同芯片项目 **实测** usable WB 仅 383.7 MiB 且 EFI map **无高地址 DRAM**；本仓 DT 的 12 个动态 shared-dma-pool 合计 **584 MiB** + 90 MiB dump 区要求 >4 GiB（EFI map 里没有）；**pc2（+612 MiB Conv）现象改变**（全静默 → 只剩背光后掉电） | 同芯片项目在 383.7 MiB 下**已越过** `efi_init`/`reserve_regions`（六 marker 全出）⇒ 容量本身**不足以**解释「EBS 后立刻死」；pc2 加内存后**仍然死** | **E1+E2**（§5）：带 `SYSFB_SIMPLEFB` 的 Image 走 GRUB，pc1/pc2 两臂比「最后一行日志」 | **实测（部分）/主根因** |
| **H2** | **代码页不可执行**（DXE Heap 在平台表里是 `WRITE_BACK_XN`；若固件有 `EFI_MEMORY_ATTRIBUTE_PROTOCOL` 且 `clear XP` 失败，`efi_remap_image` 只 warn，跳进去即 IABT→整机复位） | `PlatformMemoryMapLib` 里 DXE Heap `ArmAttributes = WRITE_BACK_XN`；`efi-stub-helper.c:725-777` 失败只 warn；现象「无任何输出直接掉电」与 IABT/SError 相容 | 我们自己的 `Loader.efi`/GRUB 都从同一 heap 执行且正常 ⇒ heap 默认可执行；**只有走重定位分支才会调 `efi_remap_image`**，而 Mu 很可能没有 `EFI_RNG_PROTOCOL` ⇒ 走「就地执行」分支，函数根本不被调用 | **E5**（静态：`grep -i RngProtocol build.log`、`strings SM8750_EFI.fd \| grep -i MemoryAttribute`）＋ E1 的日志（若最后一行是 paging 之前则降权） | 静态/推断 |
| **H3** | **`SetVirtualAddressMap`／EFI runtime 打挂** | Qualcomm 自家 UEFI 的 runtime 服务**故意 `CpuDeadLoop()`**：`ResetRuntimeDxe` 把 `ResetSystem` 挂成 runtime，`ResetSystemLib` LAA 版 `if (EfiAtRuntime()) CpuDeadLoop();` ⇒ 任何 OS 在 EB 后调 runtime 就**吊死在固件里**（<https://github.com/qualcomm-linux/meta-qcom/issues/2680>） | **arm64 + `VA_BITS_MIN>=48` 时 `efi_novamap` 自动为真**（`libstub/arm64.c:67`；我们 `ARM64_VA_BITS=52`）⇒ stub **不调** SVM；novamap 下 runtime 区 1:1 映射；同芯片项目 SVM 也未拦路（六 marker 已过 `efi_init`） | **E3**（零成本：GRUB cmdline 加 `efi=novamap`；预期**无变化**＝证伪，若变好＝立刻锁定 runtime 一类问题） | **静态（基本可证伪）** |
| **H4** | **看门狗**（ABL/PMIC WDT 未被喂；EB 后停喂导致 1–4 s 掉电） | `PITFALLS #480`（1–2 s 整机掉电）；p54 时 `console-ramoops` 记 `PM: Reset by PSHOLD / Hard Reset`；`QcomWDogDxe` 注册了 EBS 回调/RSC handler | **同一发 EB 在可用路径上跑了 39 s 到 SSH**（`reports/uefi-clean-pc1-and-grub-menu-20261110.md` §0）⇒ EB 本身不触发 WDT；R52 逐字读 wdt 寄存器 + 故障自旋活 15 min ⇒ 「没人喂就必咬」的独立定时器不成立；`#480` 实测把 `QcomWDogDxe` 摘掉也没救 | **E6**（零成本：冷 POR vs 暖 `fastboot boot` 对比掉电时刻/形态） | **实测（已基本证伪）** |
| **H5** | **GRUB 自己的状态害事**（GRUB 保留的页、页表、未关的东西；内核副本双份占内存） | GRUB 确实**双份**持有 Image（先 `allocate_any_pages` 再 `LoadImage`）＋自己的 heap＋2 MiB FDT ⇒ 在 469 MiB 世界里多占 ~60–100 MB；GRUB 无 `ExitBootServices` 处理 | **同芯片项目用「自家 EFI 应用」`LoadImage+StartImage` 到同一内核，也死在同一处**（六 marker 之后无 printk）⇒ GRUB 专有状态不可能是根因；只有「内存更紧」这一条还站得住（并入 H1） | 并入 E2；要单独分离需写一个 20 行 EFI 应用只做 `LoadImage+StartImage`（D 级成本） | 静态/推断（降权） |
| **H6** | **冷启动 vs 暖复位**（`fastboot boot`/`reboot bootloader` 与物理 POR 的硬件状态不同；PMIC/UFS/时钟残留） | 本仓 `#599/#600` 有「同一份镜像 `_a` 掉电 / `_b` 无缝回 bl」的分支差异先例；本线 EFI 实验**全部是暖复位** | 可用路径在同一暖复位下成功 ⇒ 暖复位本身不致命 | **E6**（零成本）：同一 `grub-stub.efi` 分别用 POR 与 `fastboot boot` 各一发 | 推断（**必须补**） |
| **H7** | **FDT 内容被改写导致语义不符**（GRUB 装的是固件 config table 的 DT，stub 又重建一份并加 `linux,uefi-mmap-*`；DT 的 `/memory` 15 GiB 与 EFI 469 MiB 自相矛盾） | `fdt.c:266/282`；本仓 `#558` 只看了「进程能不能起来」，未审 FDT 语义；DT 里 `ramoops@0xc2000000`(4–8 MiB) 与 `hwfence-shbuf@0xd4e23000`(2932 KiB) **正落在唯一 Conv 窗口内**（`reports/trials/…/dmesg.txt:49,54`），EFI map 不知道它们 | 本仓 `§6.1` 已证「GRUB 侧 DTB 字节与可用路径同一份」⇒ **字节**不是差异项；差异只在「stub 重建后的那份」 | E1 的日志能直接看出 `Processing EFI memory map` 与 reserved-mem 结果（需 `efi=debug`/`loglevel`） | 推断 |

**排序**：H1 >> H2 ≈ H7 > H6 > H5 > H4 > H3（H3/H4 已基本被静态/实测证伪，留作对照臂）。

---

## §4 业界先例与链接（均已 `web_fetch` 核实可访问）

1. **Qualcomm 官方参考路径本身就是「UEFI→EFI-stub 内核」，不需要二级 loader**（说明「ABL 不能 chainload」这个说法是错的；墙在平台内存图/Mu 实现，而非 ABL）：
   *Qualcomm Linux boots without a conventional second-stage boot loader. The kernel itself is compiled as an EFI application using the EFI boot stub, and the UEFI firmware (or systemd-boot) executes it directly from the ESP.*
   — <https://dragonwingdocs.qualcomm.com/archives/2.0/System/Kernel/efi-stub-and-boot-partitions>
   同族：`EFI/BOOT/BOOTAA64.EFI` 位置放的是 **systemd-boot**，内核是 UKI（`.linux/.initrd/.cmdline`）。
2. **Qualcomm 自家 UEFI 的 runtime 服务可以在 EB 后直接 `CpuDeadLoop()`**（runtime 类假设的现实依据）：
   *"So any OS that calls `RuntimeServices->ResetSystem()` after `ExitBootServices` hangs in firmware, by construction."* — <https://github.com/qualcomm-linux/meta-qcom/issues/2680>
3. **GRUB 的 arm64 `linux` = 让内核 stub 自己进 EB**（源码级设计声明，作者本人）：
   <https://lists.nongnu.org/archive/html/grub-devel/2023-05/msg00053.html>
4. **GRUB 该 loader 的现行源码**（`load_image`+`start_image`、FDT config table、LoadFile2 initrd）：
   <https://github.com/erofs/grub-erofs/blob/master/grub-core/loader/efi/linux.c>
5. **lk2nd = 社区对「固件不能替换」的标准答案：塞进 Android boot image 的二级引导**，它自己按各平台老协议跳内核，不经 EFI-stub：
   <https://github.com/msm8916-mainline/lk2nd>（README：*"It does not replace the stock bootloader. Instead, it is packed into an Android boot image, which is then loaded by the stock bootloader just like the original Android image."*）
6. **edk2-msm（Snapdragon 上的 EDK2 UEFI 移植，被广泛用于 multi-boot mainline Linux）**：证明「Qualcomm SoC + EDK2 UEFI + 常规 EFI 引导器」在**别的平台实现**上是能跑通的 —— 差异点是固件实现（内存图、runtime、属性协议），不是 SoC 原理：
   <https://github.com/edk2-porting/edk2-msm>
7. （同芯片项目内部证据，非公开链接）`external/ext-repos/sunuefi/docs/archive/linux-bringup/linux-efi-handoff-audit.md`：
   test78 实测 **`EBS_RETURN status=0 success=1`**、最终 map 49 条、strict usable WB **383.707 MiB**、全部 Conv 都在 DXE heap、**无高地址 DRAM**；test81 六个入口 marker 全出（进 `primary_entry`、过 `efi_init`/`reserve_regions`）后**仍无 printk banner/PID1**。⇒ 「EBS 没返回」与「容量小到进不去内核」都已被排除，剩下的是 **`efi_init` 之后、printk 起来之前**那一段。

> 未找到「ABL→GRUB→kernel 必然不行、必须二级 loader」的公开明确结论。公开资料的方向相反（第 1、6 条）：**多数 Qualcomm 平台是能 EFI-stub 直起的**。所以本线的墙应定位为「Mu/QcomModulePkg 这条平台实现的内存图与引导环境」，而不是平台的普遍性质。

---

## §5 最小判别实验序列（按成本排序；E1 是唯一「一发换掉全部盲区」的实验）

| 序 | 改什么 | 期望看到什么 | 排除/确认哪个假设 | 需要刷写？ |
|---|---|---|---|---|
| **E0** | **纯静态**：`grep -ci "RngProtocol" build.log`；`strings SM8750_EFI.fd \| grep -ci MemoryAttribute`；`grep -c "EFI_MEMORY_ATTRIBUTE_PROTOCOL" build.log` | 无 RNG ⇒ stub 走「就地执行」⇒ **H2 直接降权到 ~0**；有 MemoryAttributeProtocol ⇒ H2 仍需 E1 日志判 | H2 | 否 |
| **E1** | 把已存在的 `out/fbdiag-20261108/Image.fbdiag`（`CONFIG_SYSFB_SIMPLEFB=y`）放到 linux17 的 `/boot/`，GRUB 条目 2 改指它 | 屏上出现内核自己的早期日志（`Processing EFI memory map` / reserved-mem / `Memory:` 行）；**死前最后一行 = 死亡阶段** | 一举把 H1/H2/H7 **全部**变成可判；这是唯一能把「四通道静默」变「有日志」的一发 | **否**（只写 ext4 上的一个文件 + ESP 的 grub.cfg） |
| **E2** | 同 E1，但把引导层换成 **pc2**（+612 MiB Conv 的 R74）再做一发 | 若最后一行比 E1 更靠后 ⇒ **H1 确认**；若完全一致 ⇒ H1 降为「非充分」 | H1 | 否（RAM 启动 `fastboot boot`） |
| **E3** | GRUB cmdline 加 `efi=novamap efi=debug` | 预期**完全无变化**（我们的 `VA_BITS=52` 早已 novamap；`efi=debug` 走 `ConOut`＝no-op 看不到） | H3（+ 顺手证明「stub 的打印在本平台永远看不到」，避免以后再拿它当判据） | 否 |
| **E4** | GRUB cmdline 加 `nokaslr` + 删掉 initrd（用最小 cmdline） | 两臂若都不变 ⇒ KASLR/重定位与 initrd 交付被排除，把范围压到 `efi_init` 之后 | H2/H5/H7 | 否 |
| **E5** | 同一 `grub-stub.efi`，**冷 POR**（断电再开）与**暖 `fastboot boot`** 各一发 | 掉电时刻/形态若不同 ⇒ 硬件残留参与；若一致 ⇒ H6 排除 | H6 | 否 |
| **E6** | 给 Mu 加 ~50 行 **EB tracer**（包 `GetMemoryMap`/`ExitBootServices`，把最终 map 的 type/pages/attr 快照进 `SbLogPut` 环），沿用 R33/R41 的插桩范式；同芯片项目已有同款实现可抄 | 拿到**EFI 路径**的最终 map（不是 loader 路径的）：确认 Conv 总量、ramoops/hwfence 是否被固件当 Conv 交出去、EBS 是否 `Success` | H1（定案）+ 顺手验 H7 | 需要重建 UEFI 但**走 RAM 启动，不写分区** |
| **E7** | 只有在 E1–E6 之后仍无结论，才做：给内核加 6 个入口 marker（照 `sunuefi` 的 `PIANO_EFI_ENTRY_DEBUG`：`efi_enter_kernel`/`primary_entry`/`efi_init` 前后/`reserve_regions` 前后），落到 ramoops | 直接读出死在哪个阶段 | 全部 | 需要新内核 + ESP 换文件（不刷分区） |

**「收敛到 1–2 个假设」的最短路径**：E0 + E1 + E2。E0 免费砍掉 H2 的一半，E1 给出死亡阶段，E2 直接判定 H1 是主因还是旁观者。

---

## §6 未取证清单（诚实边界）

1. **EFI 路径下的最终 EFI memory map 我们没抓过**（只有同芯片项目那份 383.7 MiB 的，且是另一块板/另一份 `MemoryMapLib`）。我们的 469 MiB 窗口里 `ramoops@0xc2000000`、`hwfence-shbuf@0xd4e23000` 是否被固件当 Conv 交出去，**未知**。
2. **死亡阶段完全未知**：EFI 路径「EBS 原生尾巴（`DBI dump table info not found` + `App Log Flush`）之后无输出」只能证明「stub 调过 EB」，**不能**证明「EB 返回了」（同芯片项目专门写了返回 wrapper 才区分开）。
3. **`EBS_RETURN` 是否成功**：本线没有对应证据。`#558` 的表述「EB 之后立即死」严格说是「EB 期间/之后」。
4. **Mu 是否有 `EFI_RNG_PROTOCOL` / `EFI_MEMORY_ATTRIBUTE_PROTOCOL`**：未查（E0 一发即知）。
5. **`pc2` 那发的现场不完整**：`fastboot boot` 被 `Command aborted` 打断、pstore 没取到（`reports/…-20261110.md` §7）⇒ 「只剩背光」这条唯一有区分度的观测**没有留档**。
6. **冷/暖复位从未对比过**（本线全部暖复位）。
7. **GRUB 是否把 `linux,uefi-mmap-*` 之外的 DT 语义改坏**（比如 reserve map/`/memory` 一致性）未审。
8. 未找到任何公开的「Qualcomm ABL + GRUB 直连 EFI-stub 失败」的第三方报告；第 4 节的先例方向反而是「能跑通」，所以**不要**据此向用户/上游断言「本平台原理上不行」。

---

## §7 给 Main 的三句话

1. **别把病根记在 GRUB 头上**：GRUB 的 arm64 `linux` 就是把内核 PE `LoadImage`+`StartImage` 出去、让内核自己的 stub 进 EB，所以任何 EFI-stub 交接（含同芯片项目自家 loader）在本平台都会死在同一处 —— 我们的二级 loader 之所以没事，是因为它**自己调 EB 后按 `x0=0,x2=dtb` 旧协议直接跳 `Image`**，`dmesg` 里那句 `efi: UEFI not found.` 就是它在另一条路上的证据。
2. **要收敛假设，只需两发零刷写实验**：先把 `Image.fbdiag`（已开 `SYSFB_SIMPLEFB`）挂到 GRUB 条目 2 上，让内核自己在屏上说出死在哪一行（这一发同时干掉「四通道静默」这个最大的方法论障碍）；再把它分别配 `pc1`／`pc2`（+612 MiB Conv）跑一次，就能判定「只给 469 MiB 的 EFI 内存图」是主因还是旁观者。
3. **目前只该对外说两件事**：EFI 路径的可用内存实测级只有几百 MiB（同芯片 383.7 MiB、我们是 469 MiB 的窗口）、而 EFI 路径在 `efi_init` 之后到 printk 起来之前的那一段**我们完全没有证据**；看门狗与 `SetVirtualAddressMap` 这两条已分别被「同一发 EB 能跑到 39 s」和「`ARM64_VA_BITS=52` ⇒ stub 自动 novamap」证伪，不要再往这两条上投设备时间。
