# GRUB 项目扫描（上游 2.14 线 + 同机型社区）——在「EFI-stub 直启 ~60–70 s 硬件掉电」这个新事实下

日期：2026-11-11 晚 · 线：G1-29 路线 B 收尾调研 · **纯主机侧，零设备动作**（无 ssh / 无 fastboot / 无 ESP 写 / 无构建）
时间盒：3 h（实际联网约 2 h，抓取失败项见 §6）
证据级别词：**实测**（本仓/同机型机上数据）｜**静态**（源码/二进制/邮件原文可复核）｜**推断**（无直接证据）

---

## §0 结论（先看这 8 行）

| 问题 | 结论 | 依据 |
|---|---|---|
| **上游有没有「不经 EFI-stub 直跳 arm64 Image」的现成做法？** | **没有**。2.14 == master（`linux.c` 逐字相同），arm64 侧只有 `efi/linux.c`（LoadImage+StartImage）、`arm64/xen_boot.c`（同样要求 PE/EFI-stub 头）、`efi/chainloader.c`（只能 chainload 另一个 EFI 应用）、`efi/fdt.c`；且 `linux` 对裸 Image **显式报错拒绝** | `grub-2.14/grub-core/loader/efi/linux.c:106-108`；`ls grub-core/loader/arm64` = 仅 `xen_boot.c`；master 与 2.14 的 `linux.c` `diff` 为空 |
| **要不要换新版本（2.15/2.16）？** | **不用**。最新发布就是 **2.14（2026-01-16）**，GNU FTP 镜像只有到 2.14；master 的 `linux.c` 与 2.14 无差异 ⇒ 换版不会改变 EFI-stub 交接行为 | `lists.gnu.org/…/2026-01/msg00029.html`；`mirrors.edge.kernel.org/gnu/grub/` 列表止于 `grub-2.14.tar.gz`；diff 空 |
| **社区同机型怎么跑的？** | **retro98boy 走的就是直启**：Project Aloha(Mu) → ESP → **GRUB `linux` → EFI-stub 内核（带 `devicetree`）**，同一台 TB322FC 上列进「已支持硬件」，**未见掉电记录** | PR #820 正文（§2 引用原文） |
| **那我们的墙在哪？** | 不在机型/SoC，也不在 GRUB；在**我们自己这套 UEFI 件的「EBS 之后行为」**（详见 §3 M1–M6） | 反证：同机型 Aloha+GRUB 可用；同 SoC OnePlus 13 Mu-Silicium+GRUB 可用 |
| **上游有没有可用的一条补丁线索？** | **有两条未合并的相关件**：① `arm64: Limit memory allocations to 4GB boundary`（Qualcomm X Elite 上「用 >4 GiB 就炸」，2025-04 提出，**master 至今仍是 `0xffffffffffffULL`**）；② `loader/efi/fdt: Ensure FDT blob is 8-byte aligned`（2026-02，`devicetree` 命令的 libfdt 8 字节对齐） | 两条均在 §1.4 给了 MID 与现码位置 |
| **下一发实验（最短路径）** | **`efi=noruntime` 单变量**：一发把「EFI runtime 服务在 EBS 后被内核调用 → 固件侧掉电」整类证实/排除 | §4 E1 |
| **被本报告否掉/收紧的旧结论** | **6 条**（§3.3 列表） | — |

---

## §1 上游 GRUB 现状（全部真实抓取；出处到 file:line / MID）

### 1.1 我们实际在跑的版本

- 主机侧件：`build/grub-arm64/grubaa64.efi`，`strings` → **`GRUB 2.14-2ubuntu1`**；来源 deb `grub-efi-arm64-bin_2.14-2ubuntu1_arm64.deb`（`scripts/grub-arm64-standalone.sh:24-25`，sha256 `532decc2…` 自校验）。
- 上游源码对照件：`grub-2.14.tar.gz`（sha 由 `mirrors.edge.kernel.org` 取，14 445 329 B），`configure.ac:37` = `AC_INIT([GRUB],[2.14],…)`。
  （抓取命令：`curl -sSL -o grub-2.14.tar.gz https://mirrors.edge.kernel.org/gnu/grub/grub-2.14.tar.gz`）

### 1.2 ①「arm64 能不能不经 EFI-stub 直接跳 Image」——**否（上游无此路径）**

| 事实 | 文件:行（grub-2.14 源码，可复核） |
|---|---|
| `linux` 读内核头，**非 PE/COFF 直接报错退出**：`"plain image kernel not supported - rebuild with CONFIG_(U)EFI_STUB enabled"` | `grub-core/loader/efi/linux.c:106-108` |
| 唯一「非 EFI-stub」分支是 **x86 legacy loader**，且只在 legacy shim-lock 协议下走：`grub_cmd_linux_x86_legacy`；非 x86 编译时只打一行 `"using legacy shim lock protocol on non-x86, only db verifiable kernels will work"` 然后照旧走 EFI-stub | `linux.c:486-500` |
| arm64 目录下**只有一个 loader**：`grub-core/loader/arm64/xen_boot.c`，而它自己也调用 `grub_arch_efi_linux_load_image_header()`（同样要求 EFI-stub 头） | `arm64/xen_boot.c:460` |
| 「裸跳」路线的唯一合法替代 = **`chainloader` 另一个 EFI 应用**（不是内核） | `grub-core/loader/efi/chainloader.c`（文件存在即函数面）；这就是「二级 loader」在 GRUB 里的形态 |
| 2024 年有人提过 `--noefistub`（x86 语义：强制走 legacy loader），**2.14 树里 grep `noefistub` = 0 命中**（未合入） | `grep -rn noefistub grub-2.14/` → 空 |
| arm64 `linux` 的启动动作固定为：`load_image(0, grub_efi_image_handle, mempath(LoaderData), addr, size, &h)` → 设 `loaded_image->load_options`（UCS-2）→ `start_image(h,0,NULL)`；**GRUB 自己从不调 `ExitBootServices`**，也不碰内存属性/`SetVirtualAddressMap` | `linux.c:193-268`（`grub_arch_efi_linux_boot_image`），`:270-278`（`grub_linux_boot`） |
| 内核副本是 **`grub_efi_allocate_any_pages()`**（Typecode 由固件定，地址不限，见 1.4①），即「同一份 Image 在内存里两份」（GRUB 的 LoaderData 副本 + 固件 LoadImage 的 LoaderCode 副本） | `linux.c:537`、`:194-231` |

> **结论**：想让 arm64 上「GRUB 自己调 EBS 再按 `x0=0,x2=dtb` 跳 Image」，**上游没有这条路**，只能自己写一个 EFI 应用把它 chainload 进去（= 我们已有的 `LinuxLoader` 形态）。

### 1.3 ②「`linux` 对 LoaderCode 内存属性 / ExitBootServices 的现状」

- **不设属性**：全程无 `SetMemoryAttributes` / `EFI_MEMORY_ATTRIBUTE_PROTOCOL` / `clear XP` 调用（`grep -n "MemoryAttributes\|SetMemoryAttributes" grub-core/loader/efi/*.c` → 空）。
- **不接管 EBS**：无 `ExitBootServices` 调用（同上 grep → 空）；由内核 stub 自己调（设计如此，Ard Biesheuvel 原话见 `reports/grub-direct-vs-secondstage-20261110.md` §2.1 的 2023-05 邮件引用）。
- **不注册 EBS 事件**、不做 `SetVirtualAddressMap`。
- ⇒ 与我们 11-10 报告 §2.1 的判读**一致且已用 2.14 源码逐条复核**，无新变化。

### 1.4 ③ 值不值得换 2.15/2.16 + 近两年与本卡点相关的上游改动

**版本面**：
- 2.14 = 当前最新发布，`[ANNOUNCE] GRUB 2.14 released`，Daniel Kiper，2026-01-16，MID 页面 `https://lists.gnu.org/archive/html/grub-devel/2026-01/msg00029.html`（原文：*"GRUB maintainers are proud to announce GRUB 2.14 that has been just released."*）。
- `https://mirrors.edge.kernel.org/gnu/grub/` 目录列表：`2.00 / 2.02 / 2.04 / 2.06 / 2.12 / 2.14` —— **无 2.15/2.16**。
- master 的 `grub-core/loader/efi/linux.c` 与 2.14 **逐字相同**（`diff` 空输出）⇒ 2.14 之后的改动与本 loader 无关。
- ⚠️ 搜索摘要里出现过「GNU GRUB Manual 2.16」，**未能验证**（`www.gnu.org` 本机抓取三次全超时，见 §6），按「抓取失败」处理，不采信。

**近两年与本卡点相关的上游线程（逐条给 MID）**：

| # | 线程 | 结论/状态 | 对我们的意义 |
|---|---|---|---|
| A | `[PATCH] arm64: Limit memory allocations to 4GB boundary`，Tobias Heider（Canonical），2025-04-07 — `2025-04/msg00072`、回复 `msg00074/msg00076` | **未合入**：master 仍是 `GRUB_EFI_MAX_USABLE_ADDRESS 0xffffffffffffULL`（`include/grub/arm64/efi/memory.h:4`，2.14 与 master 同）。作者原话：*"Some Qualcomm Snapdragon X Elite based machines like the Lenovo Thinkpad T14s crash when trying to use memory above 0xffffffff. Enforcing the same 4GB limit as we do on x86_64 fixes the issue."*，且 *"it crashes super early on before anything is even visible on screen. I think it is essentially a firmware error where they advertise memory that isn't actually usable."*；维护者反对理由：*"Arm is trickier than x64 … we can't be sure that there is any memory under 4GiB mark."* | **唯一一条「Qualcomm + GRUB + 高位内存 → 炸」的公开先例**。但它的签名是「屏上什么都没有就炸」，与我们「跑完 1297 个 device_initcall、60–70 s 才掉电」不同 ⇒ 只作**低权重候选**（§4 E5，需重编 GRUB，超出本次授权） |
| B | `[PATCH] loader/efi/fdt: Ensure FDT blob is 8-byte aligned`，Mikhail Lappo，2026-02-26 — `2026-02/msg00084` | 2.14 里还是 `grub_malloc`（`grub-core/loader/efi/fdt.c:148`）；master 未见 8 字节对齐版（本报告未复核 master 的 fdt.c，见 §6） | 我们 cfg 用 `devicetree /boot/elden.dtb`；这条若命中，现象应是 **GRUB 直接报错/拒载**，不是掉电 ⇒ 与我们无关（但可 10 秒排除，见 §4 E0） |
| C | `loader/efi/linux: Return correct size from LoadFile`（v4，2025-07 `msg00173`）、`loader/efi/linux: Fix memory leak`（2025-05）、`Correctly terminate LoadOptions field`（2025-06）、`unload previous linux before updating kernel size`（2025-06）、`Fix Compile Error With Clang`（2025-10 `msg00367`） | 全是**尺寸/泄漏/编译**类修补，**没有一条触碰 EBS、内存属性、地址选择** | ⇒ 换 2.14→master 对「交接后掉电」无收益 |
| D | `[PATCH v3 10/16] 10_linux.in: Add devicetree loading`（2024-09/10）、`fdtdump`（2024-06） | 上游早已把「GRUB 传 DT」做成正规路径（`fdt` 模块 + `devicetree` 命令） | 我们的用法就是标准用法，不是偏门 |

### 1.5 grub-devel 归档可用性（影响「近 2 年」的完整性）

抓取 `https://lists.gnu.org/archive/html/grub-devel/<YYYY-MM>/threads.html` 全月表：2024-01 … **2026-03 有内容**；**2026-04 / 05 / 06 / 07 / 08 / 09 / 10 全部只有导航骨架（2.3–3.7 KB，0 封邮件）**；2026-11 返回 **404**。
⇒ 2026-02 之后的上游讨论**无法用归档核对**（不是「没有讨论」，是归档里没有）。这一点写进 §6，不作结论。

---

## §2 社区先例（每条 URL + 原文关键句）

### 2.1 retro98boy（同一台 TB322FC / SM8750）——**走的是直启，不是二级 loader**

- **PR #820 `Initial support for the Lenovo Legion Y700 Gen4 (no ACPI, FDT platform for Linux)`**
  <https://github.com/Project-Aloha/mu_aloha_platforms/pull/820>（2026-11-07 开，2026-11-09 closed/未合）
  原文（body）：*"Tested on physical hardware: **Booting Armbian through Aloha → GRUB → Linux with a DTB**. EFI boot from both UFS and SD cards."*
  ⇒ **Aloha(Mu) UEFI → ESP 上的 GRUB → `linux` 命令 → EFI-stub 内核 + `devicetree`**，与我们走的是**同一条路**，同一机型，**可用**；整串 review 评论（remtrik / qaz6750 / sunflower2333 / retro98boy）**一次也没提掉电/看门狗**，讨论全在「要不要接受 sm8750、UFSDxe 用 OEM 二进制还是自己写源码」。
- **Armbian build PR #11044**（同作者）<https://github.com/armbian/build/pull/11044>
  原文：*"Booting via ABL does not work, so this setup uses an EFI environment (Project Aloha) together with GRUB instead. Project Aloha can load GRUB from a microSD card and boot the kernel."*
  ⇒ 支撑两点：(a) 这机器上 **ABL 直起 Linux 不行**（与我们的机理一致）；(b) 他们的**替代路线就是 GRUB**，且是生产化的（Armbian 镜像 + 分区镜像工具）。
- **设备说明**（同作者）：<https://github.com/retro98boy/qualcomm-devices/blob/main/devices/lenovo-y700-gen4/README_EN.md>
  原文：*"Project Aloha will scan the card's EFI partition, launch GRUB, and boot the kernel."*；同页列出的「Current supported peripherals」是成品级清单（Wi-Fi/BT、显示+背光、触屏、扬声器、USB、microSD、充电）。
  ⚠️ 该仓库里**没有 `grub.cfg`**（`git trees` 检索 y700 目录只有 README/pictures/sound）⇒ 他们的 GRUB 配置来自 **Armbian 标准 EFI 镜像**，不是自定义补丁。

**与我们的差异点（都是可核对的文件级差异，不是猜测）**：
1. Aloha 的 elden 平台有**自己的 `PlatformMemoryMapLib.c`**（71 行，来自 stock `xbl_config.elf`）+ **`Override/AndromedaPkg/Driver/RamPartitionDxe`**（176 行），注释明确写 *"RamPartitionDxe discovers high RAM through the stock RAM partition protocol … Keep the entire tail reserved … when adding the surrounding RAM"*
   <https://github.com/Project-Aloha/mu_aloha_platforms/blob/refs/pull/820/head/Platforms/PakalaPkg/Device/lenovo-elden/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c>
   ⇒ 他们是**按 stock xbl 内存表逐条重建 map，并把高位 DRAM 交给 RamPartitionDxe 加进来**；我们这边 11-11 实测也是 11.6 GiB 可用，所以**这一条不构成我们的致死差异**（只解释「为什么我们先前以为只有 469 MiB」）。
2. 我们的件是 **QcomModulePkg 血统 + 一长串诊断补丁**（`patches/uefi/pc1-recipe.txt`：R7 `noop ConOut`、R71 串口静默、R4 真启动、R54 ESP-first…），Aloha 是 **PalakaPkg 重写平台**。这是两条**不同的固件实现**，只在「都调 `LoadImage+StartImage`」这一点上相同。

### 2.2 同 SoC（SM8750）其它 GRUB 直启公开记录

- **OnePlus 13（CPH2653 / sm8750-dodge）**，XDA 长贴 *"My attempts to boot linux"*（2025-11-09 起）
  <https://xdaforums.com/t/my-attempts-to-boot-linux.4767261/>
  原文：*"Now I can finally boot stuff and see log messages without flashing anything. **Grub works just fine.**"*；随后 *"I now managed to boot devuan linux with plasma mobile on it from an external USB drive without flashing anything."*
  配方与 11-10 报告 §2.1 完全同构：Mu-Silicium（`build_uefi.sh -d dodge -r DEBUG`）→ GRUB（`grub-install --removable`，`grub.d/05_devicetree` 里 `echo devicetree /boot/sm8750-oneplus-dodge.dtb`）→ `linux /boot/vmlinuz…`，cmdline `earlycon console=tty1 acpi=off clk_ignore_unused pd_ignore_unused ignore_loglevel loglevel=7`。
  ⇒ **SM8750 + Mu 系 UEFI + GRUB + EFI-stub 直启 = 可用**，第三方独立复现。**全程无「跑一阵掉电」记录**。
- 另一条同机型（非 GRUB）参照：`Lianghao93/tb322fc-linux` <https://github.com/Lianghao93/tb322fc-linux> —— 明确 *"no GRUB or Debian device packages are…"*，走 `fastboot boot boot.img`（= ABL `LinuxLoader` 直跳），是**另一条**已知可用路。
- 同 SoC 平板（小米平板 8 Pro / piano，SM8750P）`liang-sang/xiaomipad-8pro-mainline` 用的是 **Project-SunUEFI** + slot-A 镜像集轮换（不是 GRUB→EFI-stub），其 boot 走的是 stock ABL 的 v4 boot.img 契约 ⇒ **不能**拿来当 EFI-stub 对照，但说明「同一颗 SoC 上多种引导栈都能成」。

### 2.3 社区面小结

| 平台/栈 | 引导方式 | 结果 | 是否撞到我们的掉电 |
|---|---|---|---|
| TB322FC / Aloha(Mu) | GRUB `linux`（EFI-stub）+ `devicetree` | 日常可用（Armbian） | **没有记录** |
| OnePlus 13 / Mu-Silicium | GRUB `linux`（EFI-stub）+ `devicetree` | 起到 Plasma Mobile | **没有记录** |
| 小米平板 8 Pro / SunUEFI | slot-A boot.img（非 EFI-stub） | 日常可用 Ubuntu | 不适用 |
| **本机 / 我们这套 QcomModulePkg 件** | GRUB `linux`（EFI-stub）+ `devicetree` | **60–70 s 硬件掉电** | **只有我们** |

⇒ **不能对外说「本平台原理上不能 EFI-stub 直起」**（`reports/grub-direct-vs-secondstage-20261110.md` §6.8 的告诫仍然有效，本报告进一步坐实）。墙在**我们这套固件实现**。

---

## §3 机制判定

### 3.1 新事实（本轮必须写进前提）

1. EFI-stub 路径下内核**很健康**：`Total pages: 3037793`（≈11.6 GiB）、`Memory: 14229904K/15351172K available`、`Remapping and enabling EFI services`、`efivars: Registered`；`initcall_debug` 那一发文字滚了 **100 s 量级**，即**跑完数百个 device_initcall**（`vmlinux` 里 device_initcall 共 1297 个）。
2. 死法 = **硬件级掉电**：E4（`initcall_debug` + `panic_on_oops=1` + `softlockup_panic=1` + `panic=1` + 补 `record-size` 的 DTB）跑完，`/sys/fs/pstore/` **仍为空**；`dmesg` 有 `watchdog: Hard watchdog permanently disabled`、无 `/dev/watchdog`；下次起机 `uptime` 显示**重新上电**。
3. GRUB 侧不是变量：GRUB 只做 `LoadImage+StartImage`，EBS 由内核 stub 自己调（§1.2/§1.3，2.14 源码逐条复核）。

### 3.2 路线 A / B / C 重评（口径取 `archive/topics/BOOTCHAIN-2026-10-05.md` §4）

| 路线 | 原定义 | 现状 | 判定 |
|---|---|---|---|
| **A**「自建 SM8750 可自举 UEFI 卷塞 `boot.img`」 | 用 `scripts/grubfat-build-uefi-bootimg.sh` 把 UEFI 卷包成 arm64 Image 壳 → `boot.img` | **已达成**：现在每一发 UEFI 实验（`out/r21-sbstop-pc1/uefi-preamblec1-r1.img`）就是这条路；BDS 能扫 ESP、能起 GRUB、能起内核 | **成立且已收口**，不再是「待验证路线」 |
| **B**「替换 `uefi_a` 为自定义 UEFI」 | 写 `uefi_a`/`imagefv_a`（不可逆风险） | **不需要**：A 已能给同一份 UEFI 卷，且 GRUB/内核都能起；写 `uefi_a` 换来的只是「免 fastboot」，与当前卡点无关 | **维持搁置**（理由从「机制未证」变成「与卡点无关 + 不可逆」） |
| **C**「最小 initramfs + `switch_root`」 | 解 96 MiB `boot.img` 体积卡死 | 已由 G1-30 独立解决（`boot_b` 现在装 vk187b + nftables 常驻），**与 GRUB 线正交** | **已完成，退出本线** |
| **D**「等 DT 进 mainline / Mu 加支持」 | 被动等 | 事实层面已发生（同机型社区两个项目都跑起来了），但我们**不需要等**（我们自己的 UEFI 已经能起 GRUB） | 不适用 |

⇒ **A/B/C 三条路线在「能不能起来」这个层面全部不再有信息量**；剩下的是**单点机制**：*为什么这套 UEFI 件在 EBS 之后 60–70 s 会把整机电源切掉*。

### 3.3 被否掉 / 被收紧的旧结论（**共 6 条**）

| # | 旧结论 | 出处 | 现在的判定 |
|---|---|---|---|
| 1 | 「主根因 = EFI 只给 469 MiB Conv ⇒ 必然死」 | 11-10 报告 §1 / `PITFALLS #558` | **否**（实测 11.6 GiB 可用 + EFI runtime 正常；11-11 session 已收回，本报告复核并给出 Aloha 侧文件级对照） |
| 2 | 「死点在 `efi_init` 之后、printk 起来之前」 | 11-10 报告 §6.2/§7 | **否**：已跑到 device_initcall 末段（raid6 之后还有数百个） |
| 3 | 「`ExitBootServices` 之后**立即**死」 | `PITFALLS #558` 措辞 | **收紧**：EBS 之后还有 **60–70 s** 的内核活动 |
| 4 | 「= `panic=15` 计时 ⇒ panic 复位」 | 11-11 上午 session §3 | **已收回**（11-11 下午 session §4） |
| 5 | 「E2a 白闪与 msm 无关」 | 11-11 上午 session §2 | **已收回**（该发 cmdline 展开失效，实验无效） |
| 6 | 「`SetVirtualAddressMap` / 看门狗定时器」（H3/H4） | 11-10 报告 §3 | **维持否**：`ARM64_VA_BITS=52` ⇒ `efi_novamap` 自动为真；同一发 EBS 能跑 39 s；`R18/R20 sbstop` 世代在 EBS 之后 `CpuDeadLoop()` 能长时间存活（时长口径见 §3.4 M5 ②，未复核 15 min 这个具体数字） |

（另有 H5「GRUB 双份持 Image 造成内存紧张」：11.6 GiB 可用后**彻底失效**，不单列计数。）

### 3.4 「为什么是掉电而不是 panic」——候选机制清单（每条标可测性 + 判据）

> 共同前提：`ramoops` 落在 **DRAM 保留区**，SoC **暖复位**不会清它、**真掉电**才丢；本轮 pstore 空 + 下次起机是冷上电 ⇒ 电源在「内核写 ramoops」之前就被切掉。所以问题等价于**谁切了电**。

| # | 机制 | 为什么与本板相容 | 可测？ | 判据（命令 / 观测） |
|---|---|---|---|---|
| **M1** | **EFI runtime 服务在 EBS 后被调用** → 固件 runtime 代码/数据已被回收或 handler 里复位（Qualcomm 自家 runtime `ResetSystem` 有 `CpuDeadLoop` 先例） | 内核在 60–70 s 里会走到 efivars 写、`efi.get_time`、`efi_runtime` 映射等；我们这套件的 runtime 区在 DXE heap 之外，且 GRUB 从未替内核「让路」 | **可测（最便宜）** | GRUB cmdline 加 `efi=noruntime`：**跨过 70 s 且能进 initramfs/登录** ⇒ M1 成立；仍在 ~70 s 掉且 pstore 空 ⇒ M1 否（§4 E1） |
| **M2** | **固件遗留的 secure/EL3 事件**（PIMEM/QTEE/SCM 侧）在 EBS 后触发 SoC 复位/断电 | 该类复位**不经过 OS**，正是「pstore 全空 + 冷上电」的形态 | **不可直接测**（无安全世界观测通道）；只能靠 M1/M3 都排除后提权 | 与 M1/M3 同臂叠加；另可读**下次起机的 PON reason**（`qcom-pon` 只注册 reboot-mode、不导出 reason ⇒ 需固件侧打印，见 §6） |
| **M3** | **固件留下的 DMA/中断源仍在跑**（UFS、xHCI、ADSP/GLINK）→ SMMU/NoC 错误 → XPU/NoC 硬复位（Qualcomm 典型「NOC error → crashdump reset」） | 我们这套件用 stock Qcom DXE 驱动 UFS/USB，且 `patches/uefi` 里有 `R10-noqrks`（拿掉 QRKS）等裁剪；GRUB 又从 UFS/ESP 读过内核 | **可测** | ① `iommu.passthrough=1` + `arm-smmu.disable_bypass=0`（后者已在）；② `initcall_blacklist=ufshcd_pltfrm_init,xhci_pci_driver_init,msm_drm_register` 最小负载臂：死亡时刻若**从 70 s 变成别的值或不再发生** ⇒ M3 权重上升（§4 E3） |
| **M4** | **电源轨/时钟投票过期**（RPMh/NPA vote 依赖 Boot Services 期间的 keep-alive；EBS 后无人续投） | `clk_ignore_unused pd_ignore_unused` 已在 cmdline 仍掉电；但 **display/UFS 专用 rail** 未必被 Linux 接管 | **可测（弱）** | 同上最小负载臂 + `initcall_blacklist=msm_drm_register`：屏是否在白闪→背光→黑之后**更早**掉；以及掉电时刻是否随「谁在跑」变化 |
| **M5** | **看门狗 / PSHOLD 定时器** | 现象（固定墙钟、无 OS 记录）确实像 | **已基本否，可再证一次** | ① 3 发同一 entry 的秒级重复性；② **EBS 之后自旋仍能活**：`patches/uefi/20261104R18-haltbeforejump`（`LinuxKernel()` 之前 `CpuDeadLoop()`，位置在 `BootLinux` 的 `ExitBootServices` 之后）与 R20 `sbstop` 世代上机能长时间停在屏上（11-10 报告 §3 H4 行记为「故障自旋活 15 min」，本轮未复核该计时本身）；③ 若「E1 快臂 / E3 最小臂」死亡时刻**恒定**才重新提权 |
| **M6** | **PON/PMIC 欠压**（USB PD 供电波动；掉电后一插 USB 就自动开机 = PON reason 走 VBUS） | 该平板「接 USB 即自动开机」是平台特性，与「掉电后靠 USB 自动开机」完全相容 | **不可测（需硬件/电源表）**；可用稳定电源 + 满电复现做弱判据 | 满电、拔掉其它外设、同一发重复 3 次：若某次不死 ⇒ M6 提权 |

**排序**：M1 > M3 ≈ M4 > M2 > M6 > M5。

---

## §4 实验清单（≤5 条，按「信息量 / 成本」排序；默认零写盘形态）

> 所有上机动作由**总管**执行；本 lane 只给命令与判据。ESP 写入仅限 `\EFI\grub\` + `BOOTAA64.EFI`（有 `.bak` 备份 + `--rollback`），**不碰 boot_a/boot_b/GPT**。
> 世代 cfg 全部照抄 `out/grub-20261111/e4-pstore.cfg` 的字面量风格（**禁止 GRUB 变量拼 cmdline**，见 11-11 session 的 E2a 事故）。

### E0（免费，纯主机，5 min）：先把「上游两条补丁线索」对自己这套件排除

```bash
# ① 我们的 GRUB 里 fdt 模块是否已经是 8 字节对齐版（2.14 = 否，等同「devicetree 走 malloc」）
strings build/grub-arm64/grubaa64.efi | grep -c 'GRUB 2.14-2ubuntu1'          # 期望 1
# ② 现有 cfg 是否用了 devicetree 命令（是 ⇒ 若 libfdt 因对齐拒载，GRUB 会报错，不会静默）
grep -c '^ *devicetree ' out/grub-20261111/e4-pstore.cfg                     # 期望 1/条目
```
**判据**：① 输出 ≥1 ⇒ 确认 2.14-2ubuntu1；② 若上机时 GRUB 菜单**能显示且能 load 内核**（历史已证），则 libfdt 对齐问题**已排除**，不必再试 3+ 发。

### E1（**首推**，1 发，单变量）：`efi=noruntime`

- **目的**：把 M1（EFI runtime 类致死）一次性证实/排除——这是目前唯一「整类」而非「某驱动」的假设。
- **命令（主机）**：
  ```bash
  sed 's/elden_boot=grub_e4_fast/elden_boot=grub_e5_noruntime/; s/panic=1 panic_on_oops=1/panic=1 panic_on_oops=1 efi=noruntime/' \
      out/grub-20261111/e4-pstore.cfg > out/grub-20261111/e5-noruntime.cfg
  grep -c 'efi=noruntime' out/grub-20261111/e5-noruntime.cfg   # 期望 ≥1
  scripts/grub-arm64-standalone.sh --cfg out/grub-20261111/e5-noruntime.cfg
  sha256sum build/grub-arm64/grubaa64.efi
  ```
- **命令（上机，总管）**：`scripts/esp-install-grub.sh --activate` → `fastboot boot out/r21-sbstop-pc1/uefi-preamblec1-r1.img` → 菜单选「E4-1 同 E4-0 但去掉 initcall_debug」那条（已含 `efi=noruntime`）。
- **期望输出 / 判据**：屏上出现 `Run /sbin/init`、`EXT4-fs`、登录提示，或 SSH/`ttyGS0` 起来 ⇒ **M1 成立**（EFI runtime 是杀手），下一步直接做「runtime 服务白名单」臂。仍 ~70 s 掉电且下次起机 `ls /sys/fs/pstore/` 为空 ⇒ **M1 否**，转 E3。
- **回退**：`scripts/esp-install-grub.sh --rollback`（ESP 上 `BOOTAA64.EFI.<tag>.bak`）；设备侧 `reboot` 回 `boot_b`（vk187b）。

### E2（1 发，零新件）：重复性量化——固定定时器 vs 负载相关

- **目的**：给 M5/M6 一个硬边界。同一 entry 连跑 3 发，用手机逐帧录像/秒表记录「GRUB 倒计时结束 → 掉电」的秒数。
- **命令**：同上 E1 但**不进菜单**（`set default=0` 已经是 E4-0），每发记录 t。
- **判据**：3 发 t 的极差 **< 3 s** ⇒ 强指向**固定墙钟定时器**（M5 复活，值得读 PON）；极差 **> 10 s** 或随 entry 不同 ⇒ 负载相关（M1/M3/M4）。
- **回退**：无需（不写任何东西）。

### E3（1 发，零新件）：最小负载臂（`iommu.passthrough=1` + 大 `initcall_blacklist`）

- **目的**：M3/M4——「是不是某个驱动 probe 把 NoC/电源打崩」。
- **命令（主机）**：在 E4-1 基础上把 cmdline 改成
  `… iommu.passthrough=1 initcall_blacklist=msm_drm_register,ufshcd_pltfrm_init,xhci_pci_driver_init,a6xx_gpu_init`（其余不动），另存 `e6-min-load.cfg`，重建 GRUB 后同上 stage。
- **判据**：掉电时刻**显著位移或消失** ⇒ M3/M4 提权，随后逐个加回定位；**完全不变（仍在同秒）** ⇒ 归 M5/M6 或 M2（此时 E2 的重复性数据是主要依据）。
- **回退**：同上。

### E4（1 发，零写盘）：GRUB 只 chainload「EBS 后自旋」的 EFI 应用（不加载内核）

- **目的**：把「EBS 之后**不干任何事**能不能活」这条基线钉死。若基线能活 ≥5 min，则 60–70 s 的死**只可能来自内核 EBS 后的动作**（M1/M3/M4），M2/M5/M6 集体降权。
- **命令**：用 `patches/uefi/20261104R18-haltbeforejump`（或 R20 `sbstop`）形态重建一发 UEFI 件：在 `BootLinux()` 的 `ExitBootServices()` 之后、`LinuxKernel()` 之前 `CpuDeadLoop()`，即「EBS 已完成、内核未进入」；`fastboot boot` 后计时。旁证：`patches/uefi/20261107R52-wdtprobe2` 是同一路径上的只读 wdt 探测（**非**自旋），11-10 报告 §3 H4 行把该世代的存活时间记为 15 min（本轮未复核计时本身）。
- **判据**：活 ≥5 min ⇒ 基线成立（本轮已基本成立，故排序靠后）；~70 s 掉 ⇒ M2/M5/M6 立即提权。注意本臂是**固件**调 EBS，而掉电那发是**内核 stub** 调 EBS ⇒ 两者结果若不同，差异点正是「谁调 EBS / 调之前的固件状态」，这也就把 E5 想分离的变量分离了。
- **回退**：`reboot2 bootloader` / 长按电源。

### E5（需授权，可能超约束）：GRUB 4 GiB 上限臂

- **目的**：验证上游 1.4-A 那条 Qualcomm 先例在我们板上的适用性。
- **代价**：要**重编 GRUB**（`include/grub/arm64/efi/memory.h` 一行改成 `0xffffffff`），与本次「不重编」约束冲突 ⇒ **列为待批准**，不排进本轮。
- **判据**：若能过 70 s ⇒ 强结论（GRUB 高位分配 + 本板固件内存表冲突）；若签名不变（`0xffffffffffff`）却也能过 ⇒ 说明与地址无关，回 M1/M3。

**收敛路径**：**E0 → E1 → E2/E3**。E1 一发就能砍掉最大的一类；E2+E3 两发把「定时器 vs 负载 vs runtime」三角定死。

---

## §5 证据级别标注

| 论断 | 级别 | 复核方式 |
|---|---|---|
| arm64 无「不经 EFI-stub 直跳」路径；`linux` 拒裸 Image | **静态** | 本报告 §1.2 的 `grub-2.14` 文件:行；下载件 `grub-2.14.tar.gz`（14 445 329 B）可重取 |
| 2.14 = master = 最新发布 | **静态** | `diff` 空 + FTP 镜像目录 + 2026-01 发布邮件 |
| `linux` 不设内存属性、不调 EBS、不注册 EBS 事件 | **静态** | `grep` 空集 + `linux.c:193-268` 全函数阅读 |
| Aloha+GRUB 在同机型可用 | **实测（第三方）** | PR #820 正文 + Armbian PR #11044 正文（原文已引） |
| OnePlus 13（SM8750）Mu+GRUB 可用 | **实测（第三方论坛）** | XDA 贴原文（已引） |
| 我们的死法 = 硬件掉电（非 panic） | **实测（本机）** | 11-11 下午 session §2/§3（pstore 空 + 冷上电 + 无 /dev/watchdog） |
| 「EFI 只给 469 MiB」不成立 | **实测（本机）** | 11-11 session §4（`Total pages: 3037793`、`Memory: 14229904K/15351172K available`） |
| Aloha 用 RamPartitionDxe 加高位 DRAM | **静态** | 上述 GitHub 文件（71 行 map + 注释） |
| M1–M6 的权重排序 | **推断** | 无直接证据；每条的判据已给出（§3.4/§4） |
| 「60–70 s 是固定定时器」 | **未证实** | 待 E2 的 3 发重复性数据 |

---

## §6 未完成项

1. **`www.gnu.org` / `ftp.gnu.org` 直连抓取失败**：`https://www.gnu.org/software/grub/`、`…/manual/grub/grub.html`、`https://ftp.gnu.org/gnu/grub/` 连续 3–4 次 `curl (28) Connection timed out after 20001 ms`（含 `-4` 强制 IPv4）。**替代证据**：`mirrors.edge.kernel.org`（同内容，200/14 MB 成功）。⇒ 搜索结果里那句「GNU GRUB Manual 2.16」**未能验证，按抓取失败处理**。
2. **grub-devel 2026-04 之后无归档**（0 封邮件，2026-11 = 404）⇒ 2026-02 之后的上游动态**无法核对**；本报告对「近 2 年」的覆盖实到 **2026-03**。
3. **master 的 `grub-core/loader/efi/fdt.c` 未取**（只核了 `linux.c` 与 `arm64/efi/memory.h`）⇒ 1.4-B 那条 8 字节对齐补丁是否已进 master 未确认（对结论无影响：2.14 里没有）。
4. **`qcom-pon` 的 PON reason 在主线上不导出**（`drivers/power/reset/qcom-pon.c:41-90` 只注册 reboot-mode；`CONFIG_POWER_RESET_QCOM_PON=y` 已开）⇒ 「上次掉电是不是 PON 复位」需要**固件侧打印**（我们这套件有 `PwrUtilsDxe`/PMIC 驱动），属新增 UEFI 补丁，本轮未做。
5. **Aloha 的 grub.cfg 原文拿不到**（他们仓库里没有；来自 Armbian 标准 EFI 镜像生成）⇒ §2.1 只到「走的是 `linux`+`devicetree`」这一级，逐行 cmdline 未核。
6. **E5（4 GiB 臂）未做**：需重编 GRUB，超出本次「不重编」约束。

### ★SSOT 待并入（本 lane 不写台账）

- **`PITFALLS`（建议新条）**：「GRUB/EFI-stub 直启在本板 = **EBS 之后 60–70 s 硬件掉电**，判据 = `pstore` 空 + 下次起机为冷上电；**同机型 Aloha(Mu)+GRUB 与同 SoC OnePlus13 Mu-Silicium+GRUB 均可用** ⇒ 病根在我们这套 QcomModulePkg 件的 EBS 之后行为，不在机型/GRUB。第一发实验 = `efi=noruntime`。」
- **`TASKS/README.md` §5（G1-29）**：「路线 A/B/C 在『能不能起来』层面已无信息量（A 已达成、B 与卡点无关、C 已完成）；当前唯一未解 = 本板 UEFI 件 EBS 之后 60–70 s 掉电，候选机制 M1–M6 见 `reports/grub-project-scan-20261111.md` §3.4。」
- **`reports/grub-direct-vs-secondstage-20261110.md` 的作废标记**（只建议、未改该文）：§1 主根因（469 MiB）、§6.2「死点在 printk 之前」、§7.1「EB 之后立即死」三条应标「已作废/已收紧」。
- **`PITFALLS #558` 的措辞**：「`ExitBootServices` 后立即死」→「`ExitBootServices` 后 60–70 s 硬件掉电」。
