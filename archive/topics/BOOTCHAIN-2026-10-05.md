# BOOTCHAIN-2026-10-05：四代 TB322FC「间接引导层（GRUB/UEFI）」机制判定 + 路线

> 承接 `TASKS.md` §1 **G1-29**（间接引导层）与 §1 **G1-30**（boot.img 瘦身缓解）。
> 引用凭据：`archive/topics/GPT槽位元数据-2026-09-30.md`、`.pi/skills/qualcomm-android-flashing/references/uefi-boot-chain-vm-bootsys.md`、
> `.../grub-uefi-dual-boot.md`、`.../tb322fc-dualboot-2026-09.md`、`../qualcomm-edl-flashing/references/tb322fc-y700-gen4.md`。
> 本文是**研究证据 + 路线判定**，只增不改。**本 lane 纯主机侧，未写设备。**

## 0. 一句话结论

**四代（SM8750/elden）的固件里"UEFI 是有的"，但它被拆成了独立分区（`uefi_a` = EDK2 核，`imagefv_a` = DXE 驱动卷，`abl_a` = LinuxLoader 应用），
由 XBL 加载，而不是像三代那样把整包 UEFI 塞在 `boot.img` 的内核槽里。** 因此：
- 三代 GUF296 的"`boot.img` == 一个自举 UEFI 载荷"这一**成色最好、代价最低**的路线，四代上**没有现成镜像可抄**，但**机制上可以自建**（把 SM8750 的可自举 UEFI 卷包成 arm64-Image 壳再打 `boot.img`）。
- 四代**没有任何现成分区是"被 ABL/BDS 当启动 FAT 扫描的"**：`logfs`/`qmcs`/`spunvm` 都是固件数据分区；ABL/LinuxLoader 本身**不扫 FAT**（它是直接内核启动器）。要 GRUB 从 FAT/ext4 读 kernel+initramfs，**必须先让自己的一套 UEFI（BDS+FS 驱动）跑起来**。
- **现在立刻可做（零 UEFI、纯主机）**：路线 **C**（G1-30：最小 initramfs + `switch_root` 到 `linux17`），把 `boot.img` 从 96 MiB 压到 ~22 MB —— 直接解卡体积。**真正的 UEFI/GRUB 间接层**需要先做**路线 A**（自建 SM8750 可自举 UEFI 载荷，或采用 Mu-Silicium 的 SM8750 移植）——**主机可原型，上机验证需排期**。

---

## 1. 本地既证事实（直接引用，不重推）

| # | 事实 | 出处 |
|---|---|---|
| L1 | 三代链路：`XBL→ABL→boot_a/b boot.img（内含完整 Qualcomm UEFI DXE 环境）→BDS→bootloader LUN 上 FAT(vm-bootsys_a, 537MB, Y700BOOT)→EFI/BOOT/BOOTAA64.EFI(outer GRUB)→chainload QCOMRAMP.EFI→linuxdirect /Image root=PARTLABEL=…` | `uefi-boot-chain-vm-bootsys.md` |
| L2 | 三代 LUN0 上自建 `grubfat` **永远不被读**；真正被读的 FAT 在 bootloader LUN（`vm-bootsys_a`） | 同上 |
| L3 | **四代无 `vm-bootsys_a/b`**；`SKILL.md` 明写「SM8750-era (no vm-bootsys) 的三代链不能照搬」 | `SKILL.md` §Linux dual-boot；`tb322fc-y700-gen4.md` |
| L4 | 四代已解锁（`unlocked:yes`+`critical unlocked`），`secure:yes`，`product:elden_prc_wifi`，无 rollback 保护 | `backup/HA2EXB0E-16+512/getvar-*.txt`；`tb322fc-y700-gen4.md` |
| L5 | **四代 ABL 接受非 OEM mainline 内核**（`fastboot boot` mainline → OKAY，内核接管）；当前 `boot_b` 持久直启 mainline 已实证可用 | `tb322fc-dualboot-2026-09.md` §Verdicts；HINDSIGHT/DEVICE |
| L6 | 现状 `boot_b` = 96 MiB（100663296 B）；瓶颈是 **~80 MB rootfs ramdisk**，内核 `Image.gz` 仅 20.5 MB | 派发词；本轮实测（§2） |
| L7 | 三代 GUF296 的 `boot.img` 是**仓库内提交的预构建资产**（`source/boot-image/boot.img.7z`），CI 不构建它 | GUF296 README（本轮取证） |

## 2. 本轮新取证（关键证据）

### 2.1 三代 UEFI `boot.img` 的精确结构（已证实 / 亲手解析）

拉取并解包 GUF296 `source/boot-image/boot.img.7z`（sha256 `45f923bc…a58f`，100663296 B）：

```
Android boot header v3；kernel_size=2413234（gzip），ramdisk_size=0，header_size=1596
kernel 段 = gzip( 4,194,416 B )
    偏移 0        : code0   = 0x10000381     ← 非标准分支指令
    偏移 4        : code1   = 0x1400000f
    偏移 8        : text_offset = 0xf3800000
    偏移 16       : image_size  = 0x400000 (4 MiB)
    偏移 56       : magic  = 0x644d5241 ("ARMd")   ← 合法 arm64 Image 头
    偏移 152      : "_FVH"  ← EDK2 固件卷(FV)头；卷内含 41 个 PE (MZ) 驱动
内嵌配置字符串: DefaultBDSBootApp = "LinuxLoader"，EnableShell = 0x1，PlatConfigFileName="uefiplatLA.cfg"
```

**解读**：三代这份 `boot.img` 的"内核"是一个 **arm64-Image 外壳 + 完整 EDK2 DXE 环境（含平台 BDS）**。
ABL/LinuxLoader 把它当作"长得像 Linux 内核的东西"加载并跳入（Linaro 公开描述的标准 chainload 手法），
这份 UEFI 的 BDS 再扫 FAT 找 `/EFI/BOOT/BOOTAA64.EFI`。**"0x10000381" 是这份 UEFI 镜像 `code0` 处的字面值（很可能是其入口指令），
并不是 ABL 里硬编码的 `if (code0==0x10000381)` 之类的魔数分支**——见 §2.3。

### 2.2 四代固件栈：UEFI 被拆成独立分区（已证实）

本机存在**完整四代固件包** `~/下载/tb322fc/`（ZUXOS 073 line，Jun-18；`rawprogram*.xml` 明文 + `gpt_*.bin`）：

| 文件 | 大小 | sha256(前 16) | 落到分区（`rawprogram4.xml`） | 结构（实测） |
|---|---|---|---|---|
| `uefi.elf` | 5,242,880 | `fc68d2f91a713722` | **`uefi_a`** (0x500000=5 MiB) | **ELF64 aarch64**（entry `0xa7000000`），内含 FV（FvLength `0x2a8000`）；字符串 `DxeCore.efi`/`UEFI DXE`/`uefiplat.cfg`/`RamPartitionTableLib.c` → **EDK2 核** |
| `abl.elf` | 1,048,576 | `e7062378a1fe977d` | `abl_a` (0x100000=1 MiB) | ELF32-ARM 外壳 + FV（`_FVH@4096`），内含 1 个 FFS(type 0xb)→**LZMA 段**解出 **663,752 B 的 LinuxLoader 应用**（详见 §2.3） |
| `imagefv.elf` | 2,097,152 | `30a0fc74ebe4f149` | `imagefv_a` (0x200000=2 MiB) | FV，含 LZMA 驱动段（解出 ~32 MB，4×PE）→ **DXE 驱动卷**（BDS/FS 驱动所在，名字因二次编码未能完全提取） |
| `tools.fv` | 1,048,576 | `781e24034efbe75f` | `toolsfv` (0x100000) | 裸 FV（`_FVH@40`，2×PE） |
| `boot.img` | 100,663,296 | `d4772c1189b5d438` | `boot_a` | **Android v4**，kernel=36,731,392 B **裸 arm64 Image**（magic `0x644d5241@56`，含 `Linux version` 串），**ramdisk=0**，**无 0x10000381、无 `_FVH`** |

交叉核对：`backup/stock-259/boot_a.img` 与本包 `boot.img` **sha256 完全相同**（`d4772c11…`）→ 本轮解析的就是本机现行原厂 boot。

`fastboot getvar`（`getvar-locked.txt`）确认四代分区尺寸与固件类型：`uefi_a/b 0x500000`、`imagefv_a/b 0x200000`、
`uefisecapp_a/b 0x200000`、`toolsfv 0x100000`、`abl_a/b 0x100000`、`qmcs 0x1E00000`、`logfs 0x800000`、`spunvm 0x2000000`（全部 GPT type=`raw`）。

### 2.3 四代 ABL 的语义（已证实 / 强证据）

把 `abl.elf` 的 FV→FFS→GUID-guid(LZMA) 段解出 **663,752 B 纯文本可读**的 ABL（`scripts/grubfat-inspect.sh` 可复现）。关键字符串：

```
LinuxLoader / LinuxLoaderEntry Address / LinuxLoader Load Address to debug ABL
Local EFI_RAMPARTITION_Protocol / WARNING: Unsupported EFI_RAMPARTITION_PROTOCOL
Android! / ANDROID! / Android boot header / Boot Image Header Info...
Kernel mode check 32/64: KernelLoadAddr->magic_64 (%x) KERNEL64_HDR_MAGIC = %x
Device Magic does not match / Invalid boot image header / Decompressing kernel image failed
LoadImageFromPartition / LoadImageAndAuth / LoadImageNoAuthWrapper
avb_slot_verify / vbmeta / slot_suffix / "Active Slot %s is bootable, retry count"
```

**判定**：四代 `abl_a` 就是 Qualcomm 的 **`LinuxLoader` 应用本体**（QcomModulePkg/Application/LinuxLoader，路径字符串可见）：
它做 AVB 校验 + A/B slot + 直接内核启动。**它内部没有平台 BDS / 没有 FAT-EFI 扫描（无 `Bds*`/`SimpleFileSystem`/`Boot####` 逻辑）。**
搜索整包 **未发现字面量 `0x10000381`**（LE/BE 皆无）→ 三代那套"魔数"并非 ABL 硬编码分支；ABL 只是"验合法 arm64 头（magic `0x644d5241`）→ 加载→跳入"。

对照：三代那份 UEFI 载荷**自带** BDS（`DefaultBDSBootApp="LinuxLoader"`、`EnableShell=1`）。**真正会扫 FAT 的是"载荷里的" BDS，不是常驻 ABL。**

### 2.4 常驻 UEFI 是否已经扫 FAT？——证据倾向"否/不确定"

- 四代 `uefi_a`（EDK2 核）+ `imagefv_a`（DXE 驱动）由 **XBL** 加载（Linaro 对 RB3 Gen2 同款架构的描述：`uefi_a` = EDK2 核所在独立分区）。
- 但四代正常启动是 **XBL→EDK2→`LinuxLoader`(ABL) 直接起 Android/ mainline 内核**（L5、§2.3），
  即平台 BDS 的默认 app 是 `LinuxLoader`，**没有走"扫 FAT 找 BOOTAA64.EFI"**。
- 本机 `backup/slot-probe/uefivarstore_S1.bin`（512 KB UEFI 变量存储）**未检出 `Boot####`/`BootOrder` 字符串** → 倾向没有已注册的 FAT EFI 启动项。

> 结论：**四代"常驻 UEFI 自动扫 FAT 起 GRUB" 未被任何证据支持；不能作为路线前提。** 要 GRUB 起来，需自供 BDS（路线 A）或替换 UEFI（路线 B）。

### 2.5 上游/社区现状（本轮取证）

- **Mu-Silicium**（Project-Silicium，511★，2026-10-04 仍活跃）：**SM8750 有基线** —— OnePlus 13("dodge")：`Linux Boot ✅`、`Display ✅`、`Internal Storage ✅`，State `Inactive`，Linux 需 `index986/sm8750-mainline`；OnePlus 13s 亦在列。**Lenovo Y700 条目仅 2023 `9707f`**（非 TB322FC）。→ TB322FC 需在 SM8750 基线上做**设备移植**（UFS/memory map/panel/touch）。
- **Linaro**：Qualcomm 启动流 `PBL→XBL(SBL1→EDK2)→ABL EFI app(LinuxLoader.efi)`；**chainload 就是"让 U-Boot 长得像 Linux 内核"**；RB3 Gen2 起 `uefi_a` = EDK2 核，可直接把 U-Boot 签好刷进 `uefi_a` 当一级引导。**这直接支撑路线 A/B。**
- GUF296 仓库本身**不构建** UEFI `boot.img`（预构建资产），其 FAT/GRUB 侧脚本（`build-grub-image.sh`/`y700-direct-grub.sh`）可**原样复用**到四代（外挂 GRUB + `qcomramp.cfg` 逻辑与 SoC 无关）。

---

## 3. 机制判定（回答交付判据 1 & 2）

### 3.1 判据 1：四代 ABL 如何加载下一级？

| 问题 | 判定 | 证据等级 |
|---|---|---|
| 四代是否同三代"boot.img 内核槽装 UEFI DXE"机制？ | **机制存在于固件层（EDK2 在 `uefi_a`），但 ABL 自身不做 UEFI 引导**。四代 stock `boot.img` 是**真内核**，不是 UEFI 包 | **已证实**（§2.2/§2.3） |
| `uefi_a`/`imagefv_a` 是被读的固件卷吗？ | **是**——被 **XBL** 读（EDK2 核 + DXE 驱动卷）；**不是**被 ABL 读，**不是**启动 FAT | **已证实/强证据**（§2.2–2.4；Linaro RB3 Gen2 同构） |
| `abl_a` 是什么？ | 被 XBL 加载的 **LinuxLoader 应用**（AVB+slot+直接内核启动）；**不扫 FAT** | **已证实**（§2.3） |
| 四代 BDS 会扫哪个 FAT？ | **目前无任何 FAT 被扫描**（常驻链不经 BDS 扫盘；uefivarstore 无 Boot####）。要扫盘必须**注入自带 BDS 的 UEFI 载荷** | **强证据**（§2.4） |

### 3.2 判据 2：可被"读"的 FAT 载体候选

| 载体 | 是否会被当启动 FAT？ | 代价/风险 |
|---|---|---|
| `logfs`(8M)/`qmcs`(30M)/`spunvm`(32M) | **否**。它们是固件数据分区（GPT type=raw），非启动 FAT；无 BDS 扫描它们 | 不能用（除非自供 BDS 且驱动恰好枚举该卷） |
| `linux17`(ext4,193G) | GRUB 可读 **ext2/4** —— **是 GRUB（不是 BDS）读 kernel/initramfs 的理想载体** | 零成本；但 GRUB 自己仍需一个 FAT 来放 `BOOTAA64.EFI`（EFI 规范要求 FAT ESP） |
| 新建小 FAT32（如 LUN0 加 `grubfat` 1 GiB，或复用空闲 GPT 槽 16–31） | **是**（自供 BDS 时，它是最标准的 ESP） | 需 GPT 手术（本仓已有 TB322FC 脚本与备份，见 `scripts/gpt-surgery-tb322fc.py`）；可回退 |
| 把 FAT 直接嵌进 `boot.img` 载荷（initrd 位 = 小 ESP 镜像） | 可能（有先例：把 FAT 当 initrd 由 UEFI 挂载） | 增加复杂度；备选 |

> **要点**：GRUB 的 kernel/initramfs **可以**来自 `linux17`（ext4）——这正是用户要的"摆脱 boot.img 体积限制"。真正需要一个小 FAT 的地方**只是 GRUB 自身的 `BOOTAA64.EFI`**（~几百 KB）。所以可以：`boot.img`(≤5 MB UEFI 载荷) + 一个小 FAT(仅放 GRUB) + `linux17`(放 Image/initramfs)。

---

## 4. 路线（按代价排序，回答交付判据 3）

### 路线 C〔现在就能做，零 UEFI〕——G1-30：最小 initramfs + switch_root
- **产物**：busybox(~1 MB) initramfs，`/init` 挂 `linux17`(ext4) → `switch_root`；内核 `Image.gz`(20.5 MB) 仍在 `boot.img`。
- **构建（主机）**：`mkbootimg` 打 `boot.img`（kernel=Image.gz，ramdisk=busybox cpio.gz，cmdline `root=LABEL=linux17`）。**`scripts/grubfat-*` 之外，另有 G1-30 拟建脚本。**
- **烧写/回退**：`fastboot flash boot_b` / 回退现 `out/boot_b-vk49.img`（sha256 `87a1f8f2…`）。**无 GPT 改动。**
- **验证**：`/proc/cmdline`、`findmnt /`、相机模块 boot 自动加载不回归。
- **风险**：**低**。缺点：kernel 仍受 96 MiB 限制（但足以容纳 20.5 MB 内核 + 1 MB init）。
- **这直接解决"体积卡死"这一根因**（ramdisk 从 ~80 MB → ~1 MB），且不引入 UEFI 变量。

### 路线 A〔GRUB/UEFI 间接层，Gen3 同构〕——自建 SM8750 可自举 UEFI 载荷塞 `boot.img`
- **产物**：
  1. 一个**可自举的 SM8750 UEFI 卷**（含平台 BDS + UFS/Fat DXE 驱动 + 可选 GRUB EFI）。
     来源优先级：(a) **Mu-Silicium SM8750 移植**（最干净，OP13 `dodge` 基线，需适配 TB322FC 的 UFS/内存映射/面板）；(b) 由四代自带 `uefi.elf`(核)+`imagefv.elf`(驱动)+`tools.fv` **重组**成一个 bootable FV（**未验证能否当 ABL 载荷启动**）。
  2. 外壳：arm64-Image 头（`magic 0x644d5241@56`）+ 该 UEFI 卷 → gzip → **Android v3/v4 `boot.img`**。
  3. 一个小 FAT32（新 GPT 分区，放 `/EFI/BOOT/BOOTAA64.EFI`=GRUB + `grub.cfg`）；kernel/initramfs 放 `linux17` ext4。
- **构建（主机草案）**：`scripts/grubfat-build-uefi-bootimg.sh <uefi.fv> <out.img>`（本 lane 已提供）+ GUF296 的 `build-grub-image.sh` 造 GRUB FAT。
- **烧写/回退**：`fastboot flash boot_b`（载荷 ≤5 MB，远小于 96 MiB）；GPT 若动 → 用 `backup/gpt*` 回退。**
- **验证判据**：出现 BDS/GRUB 菜单 → `cat /proc/cmdline` 中 `root=LABEL=linux17` → `kernel+initramfs` 来自分区而非 boot.img（`boot.img` 里不再有 ramdisk）。
- **风险**：**中高**。核心不确定性 = ①SM8750 可自举 UEFI 是否可得/可启动；②四代 ABL 是否愿意"跳入"非标准 arm64 壳（三代已证可行，四代**未验证**，但四代无 region/prevent-flash 门，ABL 已接受自编 boot.img，**倾向可行**）。
- **不承诺**：在拿到"可启动的 SM8750 UEFI 卷"之前，路线 A 只是**机制可行的原型**，不是现成结果。

### 路线 B〔最符合 UEFI 标准〕——替换 `uefi_a` 为自定义 UEFI（U-Boot / Mu-Silicium）
- **产物**：SM8750 U-Boot 或 Mu-Silicium UEFI，按 Qualcomm 镜像头签名（`qtestsign` v6/v7）。
- **构建**：需 SM8750 U-Boot 端口 + DTB；或 Mu-Silicium 设备移植。
- **烧写/回退**：EDL `w uefi_a`（bootloader LUN）→ 回退刷回 `uefi.elf`（有原厂包）。
- **验证**：直接进 UEFI 菜单 / `EFI Shell` → GRUB。
- **风险**：**高**。①`secure:yes` 下 **non-HLOS（`uefi_a`）大概率仍受 Qualcomm secure boot 校验**，解锁通常只放开 Android AVB，别预设它能被替换；②需要能签名非开发镜像的工具+密钥；③最坏砖（可 EDL 救回）。
- **评级**：需上游移植 + 新工具，**非现在可承诺**。

### 路线 D〔兜底〕——等 TB322FC DT 进 mainline / Mu-Silicium 增加 TB322FC 条目
- 现状：DT 补丁（Pengyu Luo）未合并；Mu-Silicium 无 TB322FC。**长期最稳，短期阻塞。**

---

## 5. 判据 4：现在就能做 vs 需上游

| 项 | 现在可做（主机/零写盘可原型） | 需新硬件/上游 |
|---|---|---|
| 摆脱 96 MiB 体积卡死 | **✅ 路线 C**（最小 initramfs→linux17） | — |
| GRUB 从 ext4 读 kernel+initramfs | ✅ **本 lane 已提供**：GRUB 侧 FAT 产线（复用 GUF296 脚本） | — |
| 自举 UEFI 载荷（SM8750） | ◐ **主机可拼壳/可原型**（`grubfat-build-uefi-bootimg.sh`；重组四代 FV） | **要一个"真能启动的 SM8750 UEFI"**（Mu-Silicium 移植 / Qualcomm EDK2 构建） |
| 替换 `uefi_a` | ◐ 主机可准备镜像 | **签名工具+密钥 + `secure:yes` 是否放行（未证）** |
| Mu-Silicium TB322FC | — | **需设备移植（UFS/memory map/panel/touch）** |
| 三代 GUF296 FAT/GRUB 脚本 | ✅ 可**原样复用**（与 SoC 无关） | — |

**必须说清**：四代没有"现成可抄的三代 UEFI `boot.img`"。**路线 A 的缺环是"一个 SM8750 可自举 UEFI 卷"**，这需要 Mu-Silicium/Qualcomm EDK2 侧的工作，或验证四代自带 `uefi.elf`+`imagefv.elf` 重组的可行性。**不预设任何一路"不可能"。**

---

## 6. 最小设备实验清单（交父 agent 排期；本 lane 不上机）

> 原则：先**零写盘 / 只读**，后写；每条给出判据与回退。

| ID | 实验 | 命令/做法 | 判据 | 风险/回退 |
|---|---|---|---|---|
| **E1** | **只读**核对 `uefi_a`/`imagefv_a`/`abl_a` 实机内容 = 固件包 | EDL `read-part uefi_a` / `imagefv_a` / `abl_a`（bootloader LUN）→ 比对 sha256（本包 `uefi.elf fc68d2f9…` 等） | 一致 → 后续可安全回退 | 无（只读） |
| **E2** | 标记实验：常驻 UEFI 是否扫 FAT | 在某个现有 vfat（如 `spunvm`，反正在 Linux 下用不到）放 `/EFI/BOOT/BOOTAA64.EFI`（带显眼菜单的 GRUB）→ 冷启动 | 菜单出现=BDS 会扫；不出现=需自供 BDS | 写固件数据分区；**先做 E1 备份**，回退=写回原镜像 |
| **E3** | 读 `uefivarstore` 判断有无 FAT 启动项 | 只读 `read-part uefivarstore`；`strings -e l` 找 `Boot####`/`BootOrder` | 有 → 可注册 EFI 启动项（另一条路）；无 → 印证 §2.4 | 无（只读） |
| **E4** | 判四代 ABL 是否接受"非标准 arm64 壳" | **零写盘** `fastboot boot` 一个 `boot.img`：kernel = **现用 Image.gz** 但把 image 头 `code0` 置 `0x10000381`（其余不变）。看是否仍能起（说明 ABL 不挑 code0） | 仍能起 → 路线 A 壳可行 | `fastboot boot` 不写盘；失败回 fastboot |
| **E5** | 路线 C 上机（优先）| `fastboot flash boot_b` C-版 `boot.img`（min initramfs + Image.gz，cmdline `root=LABEL=linux17`） | 起桌面、`findmnt /`=linux17、相机模块自动加载 | 回退刷现 `out/boot_b-vk49.img` |
| **E6** | 路线 A 原型上机 | `fastboot flash boot_b` A-版 `boot.img`（含**任意** SM8750 UEFI 卷），外加一个含 GRUB 的小 FAT | 出现 GRUB/BDS 或串口有 UEFI 输出 | 回退同上；先 `fastboot boot` 试（零写盘） |

**排期建议**：**E1+E3（纯只读，先做）→ E4（零写盘判 ABL 壳）→ E5（路线 C，解体积卡死）→ E6/E2（UEFI 路线验证）**。

---

## 7. 附录

### 7.1 本 lane 主机侧产物
- `scripts/grubfat-inspect.sh <boot.img|firmware-dir>`：解析 Android boot 头、检测 UEFI 载荷（`code0`/magic@56/`_FVH`）、解 ABL 的 FV/LZMA、列 FV/FFS/PE、grep LinuxLoader/BDS/FS 驱动。**（本轮 §2 全部结论即由此产出）**
- `scripts/grubfat-build-uefi-bootimg.sh <uefi.fv|uefi.elf> <out.img> [--code0 HEX]`：把任意 UEFI 卷包成 arm64-Image(壳) → Android v3 `boot.img`（即路线 A 的"打壳"步骤，纯 python，无 mkbootimg 依赖）。

### 7.2 复现命令
```sh
# 三代 UEFI boot.img 拉取
curl --noproxy '*' -H 'Accept: application/vnd.github.raw' \
  https://api.github.com/repos/GUF296/ubuntu-y700-build-ci/contents/source/boot-image/boot.img.7z -o boot.img.7z
# 解包/解析
scripts/grubfat-inspect.sh ./boot.img
scripts/grubfat-inspect.sh ~/下载/tb322fc/        # 四代固件包
```
