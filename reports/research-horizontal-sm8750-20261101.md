# 横向同芯片调研：SM8750/SM8750P 平台上的 Linux/UEFI 真机进展（截至 2026-11-01）

> **性质**：只读 + 联网。**未接触设备**（无 ssh/fastboot/adb/reboot）、**未构建**、**未下载大文件**，
> 未改 `TASKS`/`INDEX`/`PITFALLS`/`DEVICE`/`AGENTS.md`/`versions/`，未 git add/commit。
> 唯一的本地"接触" = 读已在本仓库的 `build/uefi-woa-prep/repos/7-mu-lenovo/**`（`llvm-objdump`/`cmp`），
> 用于核对同行设备包里的 DXE 二进制补丁点（§2.6/§4）。
> **证据等级**：`已证` = 本次亲手取到的 URL 原文/文件行/命令输出；`外部` = 仅项目自述、未独立复核；
> `未证` = 推断，或缺一手证据。
> **联网手段**：`web_fetch`（Exa/Firefox/AnySearch）+ `gh api`（GitHub 只读 API，账号 `xiaquwan1001`）。
> **口径**：不重开本项目 UEFI 线可行性论证（那在 `reports/uefi-consolidated-20261030.md` + `TASKS` §4 N1/§5 Q25）；
> 本文件只回答"同芯片别人做到哪、怎么做的、我们能抄什么"。

---

## §0 结论先行（10 条，每条带证据等级 + URL）

| # | 结论 | 等级 | 证据 |
|---|---|---|---|
| **1** | **"SM8750 上 `fastboot boot` 是否真执行自定义载荷" = 已证「是」**，而且不是推测：小米平板 8 Pro（`piano`，**SM8750P**，与我们同 SoC 同档）的文档化「临时启动」路径就是 `fastboot boot SunUEFI-UEFI-Fastboot.img`，之后用 `fastboot -s SunUEFI-piano getvar product` 应返回 `piano-sunuefi`。文档还明确写出我们当初的那句疑虑："返回 `OKAY` 只说明原厂 Bootloader 收下了镜像。接着确认 UEFI 在运行……" | **已证** | https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/user/temporary-boot.md |
| **2** | **"早期可见性"有现成答案：把可见性搬到 USB，而不是屏幕/UART。** SunUEFI 在 UEFI 运行期常驻一个 **UEFI 侧 Fastboot 服务**（序列号 `SunUEFI-piano`），**屏幕白屏、没有菜单时也能用**：`oem ramlog`（≤256 KiB）、`oem screenshot`（读 framebuffer 出 24-bit BMP）、`fetch`（只读分区，≤64 KiB/次）、`oem status`；`flash`/`erase` 一律拒绝。 | **已证** | https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/user/fastboot.md ；同文 `docs/devel/uefi-core.md` §"常驻 USB Fastboot 服务" |
| **3** | **同芯片第二套独立实现（piano-uefi / Visor）给出更狠的一条通道**：`fastboot -s piano-uefi oem dump 81CE4000 10000` 可读出**原厂 bootloader（XBL/ABL）自己的启动日志**；还能 `oem log`（屏幕内容）、`oem debuglog`（DEBUG 构建把所有驱动输出留内存）、以及 **`boot app.efi`（从 RAM 直接跑一个 EFI 应用）**。 | **外部**（仓库文档原文，未在设备复核） | https://github.com/xiaomi-pad-8-pro-development/android_device_xiaomi_piano-uefi/blob/main/docs/DETAILS.md |
| **4** | **UFS 在 SM8750 UEFI 里"能读"，靠的是三个字节级旁路，而不是真修**（我们 10-05 撞的两层故障，社区的处理方式是绕过）：`0xa998` 把 UFS **Sleep 调用换成 Wakeup**、`0x114c4` 绕过 gear/link 检查、`0x1b080` 把 **`EnableUfsIOC`（UFS IOMMU/SMMU 域创建）整函数 stub 成 `mov w0,#0; ret`**。本次用 `cmp`/`llvm-objdump` 在**我们本地的 lenovo-y700g4 设备包**上逐字节复核成立。 | **已证**（本地二进制） | `build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/{Binaries,PatchedBinaries}/UFSDxe.efi`；与我们 `reports/uefi-consolidated-20261030.md` §2 F7/F8/F9 结论**互相独立地一致** |
| **5** | **"UEFI 白屏/灰屏"在 piano 上已定到指令级**：问题在**原厂 `ClockDxe` 的启动期初始化**，不在菜单、不在 GOP。修法 5 字节：`ClockDxe` RVA **`0xc784`** 的 `BL 0xc540` 改 `MOV w0,#0`（延后 CESTA/media 自动初始化）+ RVA **`0x3ead0`** 的 DCD 启动依赖开关 **1→0**。派生件 sha256 `abb63e6c…`。 | **已证** | https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/devel/boot/uefi-display.md |
| **6** | **平板侧不再"未证实"**：`piano` 不是 Mu-Silicium `Status.md` 的受支持设备（该表 SM8750 只有 `dodge`/`pagani` 两台手机），但它有**两套独立 UEFI + 一个已跑起来的 Debian/GNOME/SteamOS**（**UEFI 侧** UFS 分区可读；**Linux 侧** 触屏/键盘/Wi-Fi/BT/四扬/相机/传感器全通）。⇒ "SM8750 平板 UEFI 不可行"这个判断在 2026-10 之后已经过期。 | **已证**（Status.md + SunUEFI `docs/status.md`） | https://raw.githubusercontent.com/Project-Silicium/Mu-Silicium/main/Status.md ；https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/status.md |
| **7** | **`mu_wide_platforms` 里已经有我们这台机器的设备包**（`Platforms/PakalaPkg/Device/lenovo-y700g4`，2026-07-19 "add pakala pkg" 加入，与 `xiaomi-piano`/`oneplus-erhai`/`oneplus-dodge`/`nubia-nx789j` 并列），且**自带一整套 patched 厂商 DXE**：`ClockDxe` / `UFSDxe` / `QcomWDogDxe` / `PmicDxeLa` / `SPMIDxe` / `UsbConfigDxe` / `FeatureEnablerDxe`；`APRIORI.inc` 里 `QcomWDogDxe`/`ClockDxe`/`SPMIDxe`/`PmicDxeLa` 走 `PatchedBinaries`，原厂件被注释掉。 | **已证**（`gh api` 列目录 + 读 `APRIORI.inc`） | https://github.com/sunflower2333/mu_wide_platforms/tree/main/Platforms/PakalaPkg/Device/lenovo-y700g4 |
| **8** | **"载荷被执行"的最廉价判据在 Mu 的 issue 里被写成实验**：一台 OnePlus 8T 上，`fastboot boot` 一个 **72 字节只执行 `wfi` 的 ARM64 stub**，手机仍离开 fastboot ~6 s、~8 s 回来 ⇒ **ABL 确实执行了我们的镜像**；且 ~8 s 复位指向**看门狗**（`QcomWDogDxe`/APSS WDT），不是载荷没跑。与旁观者的"跑不起来"叙事相反。 | **已证**（issue 正文实验表） | https://github.com/Project-Silicium/Mu-Silicium/issues/2163 |
| **9** | **上游主线 DTS 现状**：`arch/arm64/boot/dts/qcom` 里有 `sm8750.dtsi` / `sm8750-mtp.dts` / `sm8750-qrd.dts` / `sm8750-pmics.dtsi` + `kaanapali*`（SoC 级、Qualcomm 官方），**没有任何机型 DTS**（无 `elden`、无 `piano`、无 `oneplus-13`）。我们的 `sm8750-lenovo-elden.dts` 只在本地树里（`qcom/Makefile:401`）。 | **已证**（对 `torvalds/master` 列目录 + 本地 grep） | https://github.com/torvalds/linux/tree/master/arch/arm64/boot/dts/qcom ；https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/Makefile |
| **10** | **没有任何 SM8750 机型走 Ubuntu Touch / postmarketOS 官方设备列表**：Mu 的 `Status.md` 只给 `dodge`/`infiniti` 的 pmOS **wiki 页链接**（页面本体被 Anubis 挡，未能取正文）；Ubuntu Touch 侧 0 命中。⇒ 这条生态对我们 **无现成资产可借**，只有"用 UEFI 起 Debian/Arch/SteamOS"这一条被 piano 走通了。 | **外部**（链接存在）/ **未证**（正文） | Status.md 同上；Ubuntu Touch 检索 0 命中（2026-11-01） |

**一句话**：**同一颗 SoC（含同档 SM8750P 平板）在 2026-10 已经有 2 套可用的 UEFI，两条"早期可见性"答案（UEFI 侧 USB fastboot、ABL 日志 dump），
以及一份针对我们机型的设备包 + 二进制补丁集；我们缺的既不是 SoC 支持也不是亮屏，而是「可见性通道」与「UFS/Clock 那三个字节级旁路要不要照抄」这两个具体决定。**

---

## §1 机型全景表（SM8750 / SM8750P，含同代对照）

> `SoC` 一列严格区分：**SM8750/SM8750P = Snapdragon 8 Elite = Pakala/Kanaapali 系**；
> `SM8850` = Snapdragon 8 **Elite Gen 5** = **不同芯片**（Mu 表里 OnePlus 15/15R 属此列，勿混）。

| 机型 / codename | SoC | UEFI 项目 | 装载路径 | UFS | 屏幕可见性 | 状态（谁的证据） |
|---|---|---|---|---|---|---|
| 联想拯救者 Y700 四代 `TB322FC` / **elden**（**我们**） | SM8750P | Mu-Silicium 设备包（`lenovo-y700g4`）+ 自编 | `fastboot boot`（v0 header，`kernel_addr=0x10000000` 才真交棒） | ❌ 两层故障（`0x402` GPTListener / `UFS.c+2326` UFSSmmuConfig） | 10-05 出过 EDK2 异常文字（已证亮屏）；现 silent | 本项目 `reports/uefi-consolidated-20261030.md` |
| 小米平板 8 Pro `piano`（`25091RP04C`，**SM8750P** 16 GB） | SM8750P | **Project SunUEFI**（`slwyts/`，55★，10-27 push） | ①合体 BOOT（原厂 GKI + selector + UEFI，**ABL 走正常 boot 路径**）②`fastboot boot SunUEFI-UEFI-Fastboot.img`（纯 UEFI，零写入） | ✅ GPT/BlockIO/ESP 可读（靠 §0#4 三处旁路） | ✅ 3200×2136 120 Hz 菜单 + Debian/GNOME；`fastboot boot` 后即使白屏也能 USB 取证 | `docs/status.md`（2026-10-28 更新，**外部**） |
| 小米平板 8 Pro `piano`（第二套） | SM8750P | **piano-uefi / Visor**（`xiaomi-pad-8-pro-development/`，10-30 push） | 包装 `boot.img`（v3/v4，selector 跟在 kernel 后）：`fastboot boot` 试跑 / 刷 `boot_a+boot_b` 持久 | ✅（ESP 上跑 Visor，Android 从 Visor 无重启启动） | ✅ 菜单可用；**UEFI 阶段触屏被移除**（其 SMMU stream 会挡住 Android 启动） | 该仓 `docs/DETAILS.md`（**外部**） |
| OnePlus 13 `dodge` | SM8750 | Mu-Silicium（**Active/Inactive**，`Display ✅ / UFS ✅ / Linux Boot ✅`）；设备包被 piano 当基线 | `fastboot boot` / flash boot（Mu 通用流程） | ✅ | ✅（`SimpleFbDxe` 源码 + 4 个 PCD） | `Status.md` 段 798–919（**已证**） |
| OnePlus 13s `pagani` | SM8750 | Mu-Silicium（Active，`Display ✅ / UFS ✅`，**Linux Boot ❌**，ARB v1 要求） | 同上 | ✅ | ✅ | 同上 |
| OnePlus Pad 2 Pro `oneplus-erhai`（**平板**） | SM8750 | `mu_wide_platforms` 设备包（含 `DisplayDxe` + patched `ClockDxe`） | Mu 通用 | 包内 patched `UFSDxe` | 包内 PCD 3392×2400 / ConOut 已配；**无公开实机记录** | `gh api` 目录（**已证**包存在；**未证**上机） |
| 红魔 `nubia-nx789j` | SM8750 | `mu_wide_platforms` 设备包（另有 `LinuxLoader.efi` 643 072 B） | Mu 通用 | 包内 patched `UFSDxe`（与 y700g4 **逐字节相同**） | 无公开记录 | `gh api`（**已证**同一 blob `1829e748…`） |
| OnePlus 15 `infiniti` / 15R `macan` | **SM8850**（8 Elite **Gen 5**） | Mu-Silicium（`infiniti` 有 `Linux Boot ✅`，显示仅 framebuffer） | — | ✅ | framebuffer only | `Status.md`（**仅作同代参考**） |

**关键读法**：真正"上机跑通"的只有 3 台（`piano`×2 条独立路线 + `dodge`）；`pagani`/`erhai`/`nx789j` **只有设备包，没有公开实机日志**。

---

## §2 逐机型细节（装载路径 / UFS / 可见性 / DXE 替换件 / 踩坑文档）

### 2.1 小米平板 8 Pro `piano` —— Project SunUEFI（最完整的公开记录）

**装载路径（两条，都不动原厂分区）**
1. **合体 BOOT**（推荐态）：原厂 GKI 保留在 BOOT 原位，**只把内核第一条分支改向一个 3 秒选择器**，selector + UEFI 接在 kernel 之后，由 ABL 按 header 的 `kernel_size` **整段加载**——即 **ABL 走的是正常 boot 路径**（不是 recovery 分支、不是自造分区）。选 Android 就跳回原厂内核入口；选 UEFI 才进 EDK2。
2. **`fastboot boot SunUEFI-UEFI-Fastboot.img`**（纯试用，零写入）：镜像**不含 Android 内核**，与产品核心同一份 UEFI 核。

**为什么必须"合体"而不是直接换 BOOT**（对我们有直接参考价值，属 ABL 行为差异）：
> 原厂 ABL 在**"Recovery 自带内核"**时**不会加载 `pvmfw`**，导致 Recovery 无法启动；直接替换 BOOT 内核又会让 HyperOS 起不来。
> —— 所以他们的独立 Recovery 安装路径**被主动放弃**（安装器拒绝 `--recovery`，`docs/status.md`「启动与安装」表）。

**UFS**：`docs/status.md`「存储与保护」= **能读取 UFS 的 GPT、BlockIO 和 ESP 文件**；原厂关键分区由代码强制只读（`uefi/core/PianoReadOnlyBlock.c`，只对自建 `sunuefi_esp`/`sunuefi_root` 开写）。交接前要"清理 USB、UFS、时钟与 SMMU，无法确认安全时**拒绝交接**"。

**屏幕可见性（三层，逐层可抄）**
| 层 | 做法 | 出处 |
|---|---|---|
| L1 亮屏 | **不改 GOP、不关 UFS/USB**，只**延后原厂 `ClockDxe` 的 CESTA/media 与 DCD 启动初始化**（5 字节，见 §0#5） | `docs/devel/boot/uefi-display.md` |
| L2 早期出字 | 阶段**色块 + 大字编号**诊断：`BEFORE DRIVERS`(蓝)/`BEFORE CLOCK`(蓝)/`AFTER CLOCK`(绿)/`AFTER DRIVERS`(橙)/`AFTER UFS`(紫)/`BEFORE SIMPLEINIT`(青)，每点停 3 s，记录 `PIANO_DISPLAY_CHECKPOINT`（阶段/GOP 地址/帧缓冲/模式/返回码）；`SUNUEFI_DISPLAY_DIAGNOSTIC=1..2` | 同上 |
| L3 **不管屏幕** | **UEFI 侧 USB fastboot**（§0#2）：`oem ramlog` / `oem screenshot` / `oem status`；"屏幕白屏、没有菜单时也能用" | `docs/user/fastboot.md` |

**DXE 替换件**：厂商 DXE 从**本机原厂 `uefi.img` 提取 + 打补丁**（`tools/extract-qcom-dxe.py`、`tools/patch-qcom-dxe.sh`，`Binaries/piano/` 自带 patched 件）；Mu 侧只打一枚 696 B 的 `patches/firmware/mu-silicium.patch`（`SiliciumPkg.dsc.inc`），其余改在自有组件。自研件：`uefi/core/PianoFastboot.c`（BSD-2-Clause-Patent，fastboot 0.4 命令层）、`PianoSmmu.c`/`PianoOwnedSmmu.c`（SMMU 自主持有）、`components/{linux-loader,os-boot,ext4,guarded-read,...}`。

**踩坑文档**：`docs/user/known-issues.md`、`docs/archive/display-clock/*`（7 份，时钟/显示定位过程）、`docs/archive/fastboot-ram-boot/*`（RAM boot 计划 + 37 条 CLI 审计 + 49 descriptor 内存审计）、`docs/devel/architecture.md`。

**两处"别照抄"的负面结论**（他们自己写下来的）：
- **1 GiB RAM-boot 池不可用**：raw DT 非零内存 15.34 GiB，但 **EFI Linux-usable 只有 383.7 MiB**、Conventional **282.2 MiB**（最大连续 281.1 MiB）；高段 `[0x8C0000000,0xC00000000)` 13 GiB 连续但 `safe_to_use=false`（`debug_kinfo_region`/`dump_mem_region` 的 alloc-ranges 覆盖 + 无 stage 所有权证明）。`PIANO_FASTBOOT_MAX_DOWNLOAD` 仍 **64 MiB**，`boot` 命令**仍未实现**。
- **`fastboot boot APP.efi` 不是 raw PE 直传**：AOSP `fastboot.cpp` 对非 `ANDROID!` 输入会**包成 Android 容器**（`bootimg_utils.cpp`），所以"raw EFI 直传/执行"要另立命令——他们用 `stage` + 显式 EFI 执行。

### 2.2 小米平板 8 Pro `piano` —— piano-uefi / Visor（第二套，10-30 仍在 push）

- **装载**：`selector/` 放在**任何 v3/v4 `boot.img` 的 kernel 之后**（Android 内核须是 raw arm64 GKI Image；EvoX/LineageOS/HyperOS 都行），把**内核第一条分支改向 selector**；selector 在 Mi logo 期间读按键，再起 Mu-Silicium 的 `uefi/pianoPkg`，由 ESP 上的 Visor 菜单选 Android/Linux。
- **试跑**：`python3 tools/pack.py boot.img out/selector.bin --uefi Mu-piano.img -o boot-uefi.img && fastboot boot boot-uefi.img` —— 原文注明 **"The image has no AVB footer, so the bootloader must be unlocked"** ⇒ **解锁的 SM8750 ABL 会执行没有 AVB footer 的自制 boot.img**（**已证**文档级）。
- **可见性**：`fastboot -s piano-uefi` 调试服务，**由 Qualcomm 自己的 USB 驱动提供**；支持 `oem screenshot` / `oem log` / `oem debuglog` / **`oem dump`（内存读取，`81CE4000 10000` = 原厂 bootloader 启动日志）** / **`boot app.efi`（从 RAM 起 EFI 应用）**。
- **Android 无重启回跳**：`AndroidBoot.efi` 直接在 UEFI 内启动 **ABL 已经载入内存的那个内核**，不重启。
- **反面经验（直接对我们有用）**：**UEFI 阶段触屏被移除**，原因写得很清楚——"its SMMU streams keep Android from starting from Visor"（触屏的 SMMU stream 会污染后继 Android 启动）。

### 2.3 OnePlus 13 `dodge`（Mu-Silicium 的 SM8750 基线，也是我们设备包的祖先）

- `Status.md`：`Display ✅ / Internal Storage ✅ / USB Device ✅ / Mass Storage ✅ / Linux Boot ✅`；Linux 侧 23 项中 `Display ✅ / Touchscreen ✅ / CPU ✅ / Internal Storage ✅`，GPU/WLAN/Camera/Battery ❌。
- 上游要求：`github.com/index986/sm8750-mainline`（mainline 内核）；pmOS wiki 页 `OnePlus_13_(oneplus-dodge)`。
- 知乎级踩坑文档没有；**真正的"文档"在二进制补丁里**（§2.6）。

### 2.4 `oneplus-erhai` / `nubia-nx789j`（只有设备包）

- 两者都在 `mu_wide_platforms` 的 `PakalaPkg/Device/` 下，**无 Status 行、无 CI 产物、无作者报告** ⇒ **未证**上机。
- 但两者携带的二进制信息很有价值：`erhai` 带 `DisplayDxe.efi`（421 888 B）+ patched `ClockDxe`；`nx789j` 带 `LinuxLoader.efi`（643 072 B）+ 与 y700g4 **完全同 blob** 的 patched `UFSDxe`/`ClockDxe`/`QcomWDogDxe`。

### 2.5 我们的设备包 `lenovo-y700g4`（第三方已建，2026-07-19）

来源：`sunflower2333/mu_wide_platforms`，commit message `add pakala pkg.`（2026-07-19T06:26:31Z，作者 `KancyJoe`）。

| 项 | 内容（**已证**） |
|---|---|
| 目录 | `Platforms/PakalaPkg/Device/lenovo-y700g4/{ACPI,APRIORI.inc,Binaries,DXE.inc,DXE.dsc.inc,Defines.dsc.inc,DeviceTreeBlob,Library,PatchedBinaries,PcdsFixedAtBuild.dsc.inc}` |
| PCD | `PcdABLProduct="sun"`；`1904×3040`（横/纵）；`ConOut 180×166`、`Setup 180×166`（=1904/8、3040/19） |
| PatchedBinaries | `ClockDxe.efi`(278 528) `UFSDxe.efi`(151 552) `QcomWDogDxe.efi`(28 672) `PmicDxeLa.efi`(274 432)（另有 `PmicDxeLA.efi` 266 240 两份）`SPMIDxe.efi`(45 056) `UsbConfigDxe.efi`(90 112) `FeatureEnablerDxe.efi`(32 768) |
| APRIORI | `QcomWDogDxe` / `ClockDxe` / `SPMIDxe` / `PmicDxeLa` 全部指 `PatchedBinaries`，原厂 `QcomPkg/Drivers/...` 行**被注释**；`DiskIoDxe` 也被注释 |
| **跨设备同 blob 事实** | `UFSDxe`：y700g4 ≡ nx789j（git blob `1829e748…`，151 552 B）；**piano 另一份**（`0dc7a7dd…`，155 648 B，多 4 KiB `.extra` 节）；dodge 又一份（`6e7d975b…`）。`ClockDxe`：y700g4 ≡ piano ≡ erhai ≡ nx789j（`06cc8e6b…`）；**dodge 没有 patched ClockDxe**。`QcomWDogDxe`：5 个设备**完全同一个 blob**（`bdc7d47c…`）⇒ **看门狗处理是平台级共性，不是机型差异** |

### 2.6 我们有本地副本的"字节级真相"（本次 `cmp` + `llvm-objdump` 实测）

`Platforms/PakalaPkg/Device/lenovo-y700g4`：`Binaries/QcomPkg/Drivers/UFSDxe/UFSDxe.efi`（sha256 `dac620ac…`）
vs `PatchedBinaries/UFSDxe.efi`（sha256 `00ae059f…`，与 `Project-Silicium/Mu-Silicium` 的 `PatchedBinaries/UFSDxe.efi` 同）：
**共 32 字节不同，落在 3 段**（1-based 偏移）：

```
43417-43424   0xa998   原: bl 0xbfa4                     补: mov x1,#1 ; bl 0xc0d0      ← UFS Sleep → Wakeup
70853-70868   0x114c4  原: mov w1,#0x1f ... (gear 检查)   补: mov w1,#0 ; bl 0x106d0 ; b ← 绕过 gear/link 检查
110721-110728 0x1b080  原: sub sp,sp,#0x40 (整函数)       补: mov w0,#0 ; ret            ← EnableUfsIOC 恒成功
```

其中第三段与我们自己的静态结论**完全对上**（`reports/uefi-consolidated-20261030.md` §2 F8：`0x1b080` = 把 `EnableUfsIOC`
（`UFS IOMMU domain create/configure/attach`）整函数 stub，唯一调用者经 `UfsSmmuConfigForOtherBootDev` 守卫 ⇒ 使 `UFSSmmuConfig` 恒成功）。
**结论：我们 10-05 的 `UFS.c+2326 ASSERT(UFSSmmuConfig failed)`，社区答案不是修 SMMU 域，而是把这个断言的上游函数废掉。**

`ClockDxe`：`Binaries`(`5265f1f8…`) vs `PatchedBinaries`(`3e439a7a…`) 差 108 759 字节 ⇒ **两者不是同一构建血统**，不能直接逐字节 diff；
可以确认的只是"patched ClockDxe 是跨 4 台 Pakala 设备共用的一份构建"。**要做字节级 Clock 修复，用 §0#5 的 SunUEFI 口径（对**本机原厂** ClockDxe 打 5 字节）而不是这份外来 patched 件。**

---

## §3 与我们的差异点（含核心疑点专答）

### 3.1 结构差异表

| 维度 | piano（SunUEFI / piano-uefi） | 我们（TB322FC / Lenovo ABL） |
|---|---|---|
| SoC | **SM8750P**（同） | SM8750P |
| 存储 | UFS（同） | UFS（同） |
| ABL | **小米 ABL**（两条路都吃：正常 boot 的合体镜像、`fastboot boot` 无 AVB footer 的镜像） | **联想 ABL**：header **v3 静默忽略**（`Booting OKAY` 但 fastboot 仍应答）、v0 必须 `--base 0x10000000`（PITFALLS #418） |
| 我们的独有故障 | piano 无 | `0x402`→`GPTListenerReadSectors` 的 `ctx+4` 空解引用（`PC=UFSDxe+0x13224`，FAR `0xD6ABB038`）——**这一条在 piano/社区补丁里没有对应项**，因为它发生在 patched 件里也没被触碰（F10） |
| 早期可见性 | UEFI 侧 USB fastboot（USB 级，与屏幕无关） | 只有屏幕（10-05 出过字）+ `logfs`（每次启动重写 ⇒ 失败那发取不到） |
| 我们更有利的地方 | — | **我们本地已有 y700g4 设备包全量**（`build/uefi-woa-prep/repos/7-mu-lenovo/...`）+ 9 枚待上机镜像 + 完整静态取证链；piano 那边是"从 dodge 抄 + 自己试" |

### 3.2 核心疑点专答：**有没有 SM8750 机型在 `fastboot boot` 路径下真的执行过自定义载荷？**

**有，三份独立证据，等级递增：**

1. **`外部`（文档级、可操作）**：SunUEFI `docs/user/temporary-boot.md` —— `fastboot boot SunUEFI-UEFI-Fastboot.img` 后
   `fastboot -s SunUEFI-piano getvar product` 必须返回 `piano-sunuefi`；且明确写出"`OKAY` 只代表收下镜像"这一疑虑，
   并给出**执行成功的判据 = UEFI 自己重新枚举成一个新的 fastboot 设备**。这比"看屏幕"强得多：**屏幕全黑也能判定**。
2. **`外部`（第二套实现、同一结论）**：piano-uefi `docs/DETAILS.md` —— `fastboot boot boot-uefi.img`（无 AVB footer）
   可直接试跑，"A normal reboot returns to the installed boot image"；UEFI 运行期出现 `piano-uefi` 调试 fastboot。
3. **`已证`（我们自己的历史，反证"联想 ABL 不执行"）**：
   - 2026-10-05 CI 件 `lenovo-y700g4_NOSB.img` `fastboot boot` 后屏上出现 **EDK2 `Synchronous Exception` 文字并刷屏**（用户当时抱怨字号太小）⇒ **我们这台机器的 ABL 执行过自定义载荷**；
   - 10-24/10-26 的 **v0 repack 被真交棒**（`Booting OKAY` 之后 UEFI 侧有可观测行为），只是**交棒后 ~60 s 静默、~82 s 回落 stock**。
   ⇒ **疑点本身应关闭**：问题从来不是"载荷没跑"，而是 **"跑了但看不见、且活不长"**。

**唯一仍未证的部分**：**联想 ABL 对 `fastboot boot` 的自定义载荷有没有 size/地址/签名上限**（我们没有 v3 被忽略的机理级解释，
只有"v3 被忽略、v0 生效"的现象）。这条**没有任何外部资料**，只能自测（见 §6 #1 的 `wfi` stub 判据）。

### 3.3 三条"我们与 piano 的语义差"（容易踩）

1. **"合体 BOOT" 在我们这里是可行的，但前提是 `kernel_size` 语义**：piano 明确依赖 "ABL 按 header 的 `kernel_size` 整段加载"。
   我们的 ABL 行为未知（v3 被忽略这件事说明 header 字段解读不同）⇒ **照抄前先做一次只读验证**：改 `kernel_size` 但不改 kernel，看
   `fastboot boot` 是否会加载更多/更少（零写盘、可逆）。
2. **"Recovery 自带内核 ⇒ ABL 不加载 `pvmfw`/`vendor_boot`"** 是 piano 的 ABL 结论，**联想侧未证**；但它解释了一类"卡在 fastboot"现象，
   我们若做"独立 Recovery"必须先验这条。
3. **UEFI 里别开触屏**：piano-uefi 因"触屏 SMMU stream 挡住 Android 启动"而**移除**了 UEFI 阶段触屏；piano(SunUEFI) 则是
   UEFI 阶段触屏未接通（只在 Linux 里可用）。**我们 10-05 的 `SMMU` 层故障（`ESR 0x96000005`）与这条同族**，值得当"已知坑"记下。

---

## §4 可复用证据清单（仓库 / 文档路径 / 关键行 / 一句话）

| 证据 | 位置 | 一句话结论 |
|---|---|---|
| **E1** `fastboot boot` 执行判据 | `slwyts/Project-SunUEFI` → `docs/user/temporary-boot.md`（第 2、3 节） | `OKAY` ≠ 执行；**判据 = `fastboot -s <UEFI 名> getvar product` 返回固件自报值** |
| **E2** UEFI 侧 fastboot 能力表 | 同仓 `docs/user/fastboot.md`（首表 + 命令表） | `oem ramlog`(≤256 KiB) / `oem screenshot`(BMP) / `fetch`(只读 ≤64 KiB) / `oem status` / 拒绝 `flash`/`erase` |
| **E3** UEFI 核心结构 | 同仓 `docs/devel/uefi-core.md`（"常驻 USB Fastboot 服务"、"安全退出 ExitBootServices"） | 交接前必须清 USB→UFS→时钟→SMMU，**任一步不能确认就拒绝交接** |
| **E4** ClockDxe 5 字节补丁 | 同仓 `docs/devel/boot/uefi-display.md`（"修复与实机结果"节） | RVA `0xc784` `BL 0xc540`→`MOV w0,#0`；RVA `0x3ead0` DCD 开关 1→0；派生 sha256 `abb63e6c…` |
| **E5** 阶段色块诊断法 | 同上（首表 + "ClockDxe 内部对照"） | 6 个阶段的颜色/名称 + `PIANO_DISPLAY_CHECKPOINT` 记录；**屏幕观察不能由 RAM 截图替代** |
| **E6** RAM boot 上限 | 同仓 `docs/archive/fastboot-ram-boot/fastboot-ram-boot-plan.md` | usable 383.7 MiB / Conventional 282.2 MiB；1 GiB 池 `safe_to_use=false`；`MAX_DOWNLOAD`=64 MiB |
| **E7** 合体 BOOT 布局法 | 同仓 `docs/devel/boot/combined-boot.md` | BOOT4 header 只改 `kernel_size`；kernel 后接 NEXTv1 请求页 + selector + shim + FD + APP + `RSTRv1` 恢复目录；**用 `RSTRv1` 保证可无损还原** |
| **E8** ABL 日志可 dump | `xiaomi-pad-8-pro-development/android_device_xiaomi_piano-uefi` → `docs/DETAILS.md`（"Debug fastboot"节） | `oem dump 81CE4000 10000` = **原厂 bootloader 启动日志**；`boot app.efi` 可从 RAM 起 EFI 应用 |
| **E9** 无 AVB footer 也能 `fastboot boot` | 同上（"Test"节） | 解锁的小米 ABL 接受无 AVB footer 的自制 boot.img |
| **E10** 触屏 SMMU 副作用 | 同上（"Status"表末行） | UEFI 阶段触屏的 SMMU stream 会让后继 Android 起不来 ⇒ 已移除 |
| **E11** 我们机型设备包 | `sunflower2333/mu_wide_platforms` → `Platforms/PakalaPkg/Device/lenovo-y700g4/**` | 1904×3040 PCD + 7 个 patched 厂商 DXE；`APRIORI` 用 patched `QcomWDogDxe`/`ClockDxe`/`SPMIDxe`/`PmicDxeLa` |
| **E12** UFS 三处旁路（本机复核） | 本地 `…/lenovo-y700g4/{Binaries,PatchedBinaries}/UFSDxe.efi`（§2.6 三条 `cmp` 段 + 反汇编） | `0xa998` Sleep→Wakeup、`0x114c4` 绕 gear 检查、`0x1b080` `EnableUfsIOC`→`mov w0,#0;ret` |
| **E13** 看门狗是共性 | `QcomWDogDxe.efi` 在 5 个 Pakala 设备包里**同一 blob** | 8 s 复位这类现象先查 WDT，不要先怀疑"没执行" |
| **E14** `wfi` stub 判据 | `Project-Silicium/Mu-Silicium` **issue #2163**（正文"在硬件上验证了什么"表） | 72 B `wfi` stub 也让设备离开 fastboot ~6 s ⇒ **ABL 执行了载荷**；~8 s 回落 = 看门狗 |
| **E15** SM8750 支持面 | `Project-Silicium/Mu-Silicium` → `Status.md`（`Snapdragon 8 Elite Devices` 段） | 只有 `dodge`（Linux Boot ✅）/`pagani`（❌）；**平板 0 条目** |
| **E16** 上游 DTS 现状 | `torvalds/linux` → `arch/arm64/boot/dts/qcom/`（本次列目录） | SoC 级齐（`sm8750.dtsi`/`mtp`/`qrd`/`kaanapali*`），**机型 DTS 0 个** |

---

## §5 SM8750 上游主线 DTS 支持现状（本次实查）

**方法**：`gh api repos/torvalds/linux/contents/arch/arm64/boot/dts/qcom?ref=master`（2026-11-01）+ 本地树 `grep`。

| 文件 | 上游 master | 本地 `linux/` | 说明 |
|---|---|---|---|
| `sm8750.dtsi` | ✅ | ✅ | SoC 级（Qualcomm 2024，BSD-3-Clause） |
| `sm8750-pmics.dtsi` | ✅ | ✅ | PMIC 组合 |
| `sm8750-mtp.dts` / `sm8750-qrd.dts` | ✅ | ✅ | Qualcomm 参考板（`Copyright (c) 2024 Qualcomm Innovation Center`） |
| `kaanapali.dtsi` / `kaanapali-{mtp,qrd}.dts` / `pm*-kaanapali.dtsi` | ✅ | ✅ | 同族代号（Kanaapali）平台树 |
| **`sm8750-lenovo-elden.dts`** | ❌ **不在** | ✅ 有（`qcom/Makefile:401`：`dtb-$(CONFIG_ARCH_QCOM) += sm8750-lenovo-elden.dtb`） | 我们的板 DTS，**本地增量**；`compatible = "lenovo,elden","qcom,sm8750"`，`chassis-type = "tablet"`；文件头版权含 **Pengyu Luo**（2025-2026） |
| `piano` / `oneplus-13` / 任何机型 DTS | ❌ | ❌ | **上游 0 个 SM8750 机型 DTS** |

**补充（本项目台账口径，非本次上网所得）**：`TASKS/README.md` §5 记录"上游正在评审并新增我们同名的 `sm8750-lenovo-elden.dts`（v2, 1170 行）⇒ DT 必须以其为基做 delta"。
即：**elden 板 DTS 在邮件列表上已被他人（Pengyu Luo）推进，但尚未进 `master`**（本次列目录证实不在）。
⇒ **上游化线（M3）与 UEFI 线在 DTS 上是解耦的**：UEFI 用 Mu 设备包 + 我们自己的 DT，不依赖上游评审进度。

---

## §6 对我们可立即复用的三条

### #1 【最高优先，零风险】把"早期可见性"从屏幕搬到 **UEFI 侧 USB fastboot**

**做什么**：在现有 UEFI FD 里加一个最小 fastboot 服务端（只实现 `getvar product` / `oem ramlog` / `oem status` 三条），
在启动早期（`PianoProductCoreEntry` 等价位置，即 **UFS 初始化之前**）就注册 USB 设备，序列号自报 `elden-uefi`。

**为什么这条最值**：
- 它**绕开我们全部的可见性死结**：UART 全 0、无 `UsbSerial*Dxe`、`logfs` 每次重写、屏幕在 ClockDxe 之后变灰 —— 这些都不影响 USB 枚举；
- 它把"载荷是否执行"变成**一个命令的返回值**（§0#1 的口径），而不是"猜屏幕"；
- 它是**唯一能把失败那发的证据带回来**的通道（`oem ramlog` 留在 RAM，屏幕黑也读得到）。

**现成可抄**：
- 命令层语义：`slwyts/Project-SunUEFI` → `uefi/core/PianoFastboot.c`（**BSD-2-Clause-Patent**，与我们许可兼容）+ `docs/user/fastboot.md`；
- 传输层：piano-uefi 明确写了"**served by Qualcomm's own USB driver**" ⇒ 用 **本机原厂 `uefi.img` 里的 `UsbConfigDxe`（我们设备包里已有，`53a6829f…`）**，不必自己写 DWC3；
- 判据：`fastboot -s elden-uefi getvar product` 返回预期串 = **载荷执行 + USB 栈活 + 代码跑到我们能控制的点**。

**加分项（同一条通道顺手做）**：`oem dump` 读 **ABL/XBL 日志区**。piano 的地址是 `0x81CE4000`/64 KiB；我们**必须先在本机验证地址**
（用已知能出字的 10-05 口径镜像 + 我们的 DDR 黑盒取证工具 `reports/uefi-ddr-blackbox-20261101.md`），但一旦命中，
就能拿到"ABL 到底把控制交给了谁、几点交的"这一手证据。

**先验的 30 分钟实验（零写盘）**：`fastboot boot` 一个 **72 字节 `wfi` stub**（照 Mu #2163 的做法），用**秒表**记录"离开 fastboot → 回到 fastboot"的时长：
- 若 ≈ 8 s（或我们观测到的 ~60/82 s 档）⇒ **ABL 执行了**，问题在看门狗/交棒；
- 若立刻回来 ⇒ 问题在 header/地址，先修 §PITFALLS #418 那一层。
这条判据**不需要屏幕、不需要 UEFI 成功**，是所有后续实验的地基。

### #2 【直接可用资产】照抄 `lenovo-y700g4` 设备包的 **UFS 三处旁路**，但**只抄两处**

**事实**（§2.6，本机字节级）：我们本地就有一份"给我们这台机器准备的" patched `UFSDxe`
（`PatchedBinaries/UFSDxe.efi`，sha256 `00ae059f…`），三处改动：
1. `0xa998` UFS **Sleep → Wakeup**（`mov x1,#1; bl 0xc0d0`）；
2. `0x114c4` **绕过 gear/link 检查**；
3. `0x1b080` **`EnableUfsIOC` → `mov w0,#0; ret`** ⇒ 让 `UFSSmmuConfig` 恒成功（这就是我们 10-05 `UFS.c+2326` 断言的消音器）。

**处置建议**：
- **抄 1+2**（纯时钟/链路时序，是本机 UFS 冷起必需的 wakeup 语义）；
- **不抄 3**（把 UFS IOMMU 域创建变成空实现 = 关掉 SMMU 保护换能读；piano 两套实现里，SunUEFI 的做法是**自己持有 SMMU**
  `uefi/core/PianoOwnedSmmu.c`，而不是 stub 掉）。**我们可以先抄 3 换"能读 GPT/ESP"这一步的可跑性，但在报告里必须标成 workaround**，
  否则以后没法解释"为什么 UFS 能读但 SMMU 域从未建立"。
- **顺带装 `QcomWDogDxe`（patched 版，5 设备同 blob `bdc7d47c…`）**：`APRIORI.inc` 里它是**第一梯队**（`DxeMain`/`Pcd`/`RuntimeDxe` 之后第一件事）。
  Mu #2163 的 8 s 复位、我们 10-24/10-26 的"~60 s 静默 / ~82 s 回落"，**第一条要排除的都是看门狗**。

### #3 【精确到字节】用 SunUEFI 的 **ClockDxe 5 字节**补丁修"白屏/灰屏"，并用阶段色块定位

**做什么**（对**本机原厂** `ClockDxe.efi` 打，不要用那份外来 patched 件）：
- RVA **`0xc784`**：把启动期调用 `0xc540` 的 `BL` 改成 `MOV w0,#0`（**延后整个 CESTA/media 自动初始化**）；
- RVA **`0x3ead0`**：**DCD 启动依赖开关 1 → 0**；
- 合计 **5 字节**，派生件 sha256 应为已知值（piano 的是 `abb63e6c…`；我们算出来的必须与我们的原厂件一一对应并记录）。

**为什么这条对我们是"对症"而不是"碰运气"**：
- piano 的定位过程与我们完全同构：**先亮（`BEFORE DRIVERS`/`BEFORE CLOCK` 蓝色可见）→ `AFTER CLOCK` 之后变灰**；
  我们的历史观测是"10-05 能出 EDK2 文字 → 后续 silent"，**同一形态**；
- 他们已排除的两个替代假设，正好省掉我们两轮实验：① "只清显示实例自动初始化标志"不够；② "把 `+0xd0` 申请数量 4→0" 也**不够**（都试过、都只到 `BEFORE CLOCK`）；
- 真正的答案是"**延后 CESTA/media 整个块 + 延后 DCD 依赖**"。

**配套的诊断法（比补丁本身更值钱）**：6 个阶段色块 + `PIANO_DISPLAY_CHECKPOINT` 记录（阶段/GOP 地址/帧缓冲/模式/返回码），
并在**进入 SimpleInit 之前**画最后一个检查点。判读规则他们写死了两条，值得照抄：
> "如果色块在进入 SimpleInit 前消失，先定位最后可见的驱动阶段；如果所有检查点都可见、菜单接管才消失，再针对 SimpleInit 的 GOP 选择/模式/刷新路径做对照。
> **RAM 截图不能代替物理屏幕结果。**"

**顺序建议**：`#1（USB 可见性）→ #2（UFS 两处 + WDT）→ #3（Clock 5 字节）`。
理由：#1 一旦成立，#2/#3 的每一发实验都**自带证据回传**，不再依赖"这一次屏幕有没有亮"。

---

## §7 本次未取到 / 明确留白（不猜）

| 项 | 状态 | 说明 |
|---|---|---|
| postmarketOS `dodge` 设备页正文 | **未取到** | `wiki.postmarketos.org` 与 `gitlab.postmarketos.org` 均被 **Anubis** 挡（含 `api.php`）；仅经 `Status.md` 得知页面存在 |
| pmaports 里 `linux-oneplus-dodge` 是否存在 | **未核** | GitLab API 同上被挡 |
| SunUEFI / piano-uefi 的**实机视频/日志原文** | **未取** | 只有仓库内文字与截图链接（`docs/assets/gallery/*.webp`）；未下载 |
| `piano` 的 `fastboot boot` 镜像 header 版本 / `kernel_addr` | **未证** | 文档只说"不含原厂 Android 内核的独立镜像"；二进制未下载 |
| 联想 ABL 对 `fastboot boot` 载荷的 size/地址/签名上限 | **未证** | 全网 0 资料；只能自测（§6 #1 的 `wfi` stub） |
| `mu_wide_platforms` 的 `lenovo-y700g4` 有没有人真上机 | **未证** | 无 CI 工作流、无 issue、无报告；`pushed_at` 2026-10-01（整仓） |
| Ubuntu Touch SM8750 | **0 命中** | 检索无任何 SM8750 UBports 端口 |

---

## §8 源清单（本次实际打开过的 URL，按取证顺序）

1. https://github.com/lmnduy/SunUEFI （README；**注意**：0★，10-25 建的 fork，pushed 10-26 ⇒ 内容以 `slwyts/Project-SunUEFI` 为准）
2. https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/user/temporary-boot.md ★核心
3. https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/user/fastboot.md ★核心
4. https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/status.md ★核心
5. https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/devel/boot/uefi-display.md ★核心（ClockDxe 5 字节）
6. https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/devel/boot/combined-boot.md
7. https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/devel/uefi-core.md
8. https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/devel/patches.md
9. https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/archive/fastboot-ram-boot/fastboot-ram-boot-plan.md
10. https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/archive/memory-dma/piano-native-independent-smmu.md
11. https://raw.githubusercontent.com/slwyts/Project-SunUEFI/main/docs/user/known-issues.md
12. https://github.com/xiaomi-pad-8-pro-development/android_device_xiaomi_piano-uefi → `README.md`、`docs/DETAILS.md` ★核心
13. https://raw.githubusercontent.com/Project-Silicium/Mu-Silicium/main/Status.md ★核心
14. https://github.com/Project-Silicium/Mu-Silicium/issues/2163 ★核心（`wfi` stub 判据）
15. https://github.com/sunflower2333/mu_wide_platforms → `Platforms/PakalaPkg/Device/{lenovo-y700g4,xiaomi-piano,oneplus-dodge,oneplus-erhai,nubia-nx789j}/**` ★核心
16. https://github.com/torvalds/linux/tree/master/arch/arm64/boot/dts/qcom （DTS 现状）
17. 本地：`build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/**`（`cmp`/`llvm-objdump`，§2.6）

DONE
