# 同芯片平板 UEFI「亮屏」回挖：SM8750 设备普查与早期可见性可搬性评估

日期：2026-10-28　性质：**纯主机、只读、零写盘**（不上机、不 fastboot、不 ssh 设备）
lane：UEFI 线专项回挖（用户 2026-10-28 提出：「同芯片的小米/一加平板有 UEFI 驱动，曾做出一个可以亮屏的项目」）
结论口径：**已证 / 未证实 / 未上机**。大文件只记 URL + sha256 + 大小。

---

## 0. 结论（先数字）

| 项 | 数字/结论 |
|---|---|
| Mu-Silicium `Status.md` 的 **SM8750（Snapdragon 8 Elite）** 段设备总数 | **2**（OnePlus 13 `dodge`、OnePlus 13s `pagani`） |
| 其中**平板** | **0** ← 见 §1.3，用户记忆需修正 |
| Display 判 ✅ | **2/2**（dodge、pagani） |
| `mu_wide_platforms` 的 SM8750 设备包数 | **5**（含 2 台平板：`xiaomi-piano`=Pad 8 Pro、`oneplus-erhai`=Pad 2 Pro） |
| 平板设备包的显示配置是否就绪 | **是**（PCD 分辨率/ConOut 列行全配，3200×2136 / 3392×2400） |
| 平板亮屏是否有公开验证记录 | **未证实**（无 Status 行、无 CI 产物下载、无作者报告） |
| 亮屏驱动是什么 | **`AndromedaPkg/Driver/SimpleFbDxe`（源码）**，非厂商 `DisplayDxe` 二进制（后者的 INF 在所有 Pakala 设备包里都被注释掉） |
| 亮屏是否依赖 UFS 先起 | **不依赖**（SimpleFbDxe 只吃 ABL 交来的 GOP/framebuffer 描述 + PCD，UFSDxe 在 APRIORI 更后） |
| 最小实验变量个数 | **1**（E-1：只用 CI 双跑构建口径复现 10-05，见 §4.2） |
| 我们的 UEFI 是否曾亮屏 | ✅ **已证：2026-10-05 屏上出现 EDK2 异常文字并刷屏**（用户抱怨「字号太小」）⇒ 亮屏不是缺环 |
| 早期可见性通道是什么 | **`FrameBufferSerialPortLib`**（`USE_SCREEN_FOR_SERIAL_OUTPUT=1`）直接写 `Display Reserved`，**不需要 GOP、不需要 UFS** |
| 「UFSDxe 代次差」结论 | ❌ **已否证（本机）**：Mu 件与厂商件只差 6 字节（全是 build 路径串） |
| 上游「link state = Sleep」 | 🟡 **上游主张、我方未证实**；只能解释 link/gear 层，解释不了 `ESR 0x96000005` SMMU 层 |

**一句话**：用户记忆里的「同芯片小米/一加平板 UEFI 已亮屏」在**平板**上是**未证实**；真正**已证亮屏**的是**同 SoC 的两台手机**（dodge/pagani，`Status.md` Display ✅）。
但**关键的好消息**是：这三条线（手机 2 + 平板 2）与**我们的 `lenovo-y700g4`** 用的是**同一套亮屏机制 = `SimpleFbDxe` 源码 + 4 个 PCD**，
而我们的设备包里这套 PCD **已经按 1904×3040 配好了**。

**更强的结论（本次回挖最重要）**：**我们自己的 Y700g4 UEFI 在 2026-10-05 就已经亮过屏** —— 屏上出现了 EDK2 的 `Synchronous Exception` 文字块并刷屏，用户当时抱怨「字号太小/看不清」。
⇒ 「找亮屏方案」是**伪需求**；真正要做的是 **复现 10-05**（§4.2，1 个变量）。
⇒ 同时 **「早期可见性依赖 GOP」这一旧结论被推翻**：实际通道是 `FrameBufferSerialPortLib` 直接写 framebuffer，**在 GOP 之前就能出字**。

---

## 1. 设备普查（Mu-Silicium Status.md，SM8750 段）

### 1.1 Status.md 的 SM8750 段逐条（**只有 2 台，都是手机**）

来源：`https://raw.githubusercontent.com/Project-Silicium/Mu-Silicium/main/Status.md`（本次拉取 5 696 行，`Snapdragon 8 Elite Devices` 段 = 第 798–919 行）。

| codename | 机型 | State | Display | Internal Storage | USB Host | USB Device | Mass Storage | Windows Boot | Linux Boot | 平板? |
|---|---|---|---|---|---|---|---|---|---|---|
| `dodge` | OnePlus 13 | Inactive | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ | 否 |
| `pagani` | OnePlus 13s | **Active** | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ | 否 |

补充事实：
- `dodge` 的 Linux 侧**另有 23 项表**，其中 `Display ✅`、`Touchscreen ✅`、`CPU ✅`、`Internal Storage ✅`；GPU/WLAN/Camera/Battery 全 ❌ ⇒ **亮屏 + UFS + 触摸**是该端口的「已完成面」。
- `dodge` 注记要求 **mainline 内核** `github.com/index986/sm8750-mainline`，并有 pmOS wiki 页 `OnePlus_13_(oneplus-dodge)`。
- `pagani` 顶部有 `> [!CAUTION] ARB Version 1 is Required`（防回滚版本 1）。
- **整个 Status.md 里没有任何 SM8750 平板条目**（已用 `grep -i 'piano\|erhai\|pad\|plk110'` 全表扫过：命中的 `Xiaomi Pad 5/6/7 Pro` 属 SM8150/SM8250 段，`Xiaomi Pad 6 Pro/S6 Pro` 属 SM8450/SM8550 段，均非 8 Elite）。

### 1.2 `mu_wide_platforms` 的 SM8750 设备包（含平板，但**无状态表**）

来源：`sunflower2333/mu_wide_platforms`（fork of `Project-Aloha/mu_aloha_platforms`）。`Platforms/PakalaPkg/Device/` 实测 5 项：

| codename | 机型（SMBIOS/Retail） | framebuffer PCD | ConOut 列×行 | 平板? | PatchedBinaries 差异 | CI 工作流 |
|---|---|---|---|---|---|---|
| **`xiaomi-piano`** | Xiaomi **Pad 8 Pro**（`pinao` / `8pro` / sku `MP` / `PcdABLProduct=sun`） | **3200×2136** | 400×112 | **是** | 与下面同 + 无 Phoenix | **`sm8750_xiaomi_pad8p.yml`**（唯一 SM8750 工作流，产物名 `uefi-images-plk110`） |
| **`oneplus-erhai`** | OnePlus **Pad 2 Pro**（`OPD2413` / `OP615EL1`） | **3392×2400** | 424×126 | **是** | 同下 + `PhoenixDxe` | 无 |
| `lenovo-y700g4` | Lenovo **Y700 4th**（`Y700` / `4`）← **本机 TB322FC** | **1904×3040** | 180×166 | 是 | 基准 | 无 |
| `oneplus-dodge` | OnePlus 13（`PJZ110`） | 1440×3168 | 180×166 | 否 | 基准 | 无（走 Mu-Silicium 主仓） |
| `nubia-nx789j` | RedMagic 10（`RM10`） | 1216×2688 | 180×166 | 否 | 基准 | 无 |

**共同点（关键）**：5 个包的 `DXE.inc` 前 3 行**逐字相同**：
```
INF AndromedaPkg/Driver/SimpleFbDxe/SimpleFbDxe.inf
INF AndromedaPkg/Driver/RamPartitionDxe/RamPartitionDxe.inf
INF $(PACKAGE_NAME)/Device/$(TARGET_DEVICE)/Binaries/QcomPkg/Drivers/EnvDxe/EnvDxeEnhanced.inf
```
⇒ **显示路径完全同源**，差别**只在 4 个 PCD（宽/高/ConOut 列/行）**。

**PatchedBinaries 共同点**：5 个包都启用 `SPMIDxe / UFSDxe / UsbConfigDxe / ClockDxe / PmicDxeLa / QcomWDogDxe`，
**都注释掉了 `ButtonsDxe` 与 `DisplayDxe`**，`DisplayCallerDxe` 也注释掉。
⇒ 「亮屏」**不需要**任何厂商 DisplayDxe 二进制补丁。

### 1.3 对用户记忆的核对（口径修正）

| 用户原话 | 核对结果 |
|---|---|
| 「同芯片的小米和一加平板有 UEFI 的驱动」 | **部分已证**：`xiaomi-piano`（Pad 8 Pro）与 `oneplus-erhai`（Pad 2 Pro）设备包**确实存在**，且显示 PCD 已配、CI 工作流 `sm8750_xiaomi_pad8p.yml` 存在 |
| 「曾经做出了一个可以亮屏的项目」 | **未证实于平板**：Mu-Silicium 官方状态表 SM8750 段**没有平板行**；平板无 CI 产物下载记录、无作者报告。**已证亮屏的是同 SoC 的两台手机**（dodge/pagani） |
| 「能否搬来解早期可见性」 | **可以，但搬的不是「平板的亮屏」而是「手机的亮屏机制」= `SimpleFbDxe` + 4 PCD，而我们已经全有** ⇒ 见 §3/§4：真正缺的是「活到 SimpleFbDxe」 |

## 2. 亮屏实现层

### 2.1 结论先行：亮屏驱动是 **`SimpleFbDxe`**（纯源码，无厂商二进制），它**不初始化显示硬件**

三个候选全部核对完毕：

| 候选 | 是否存在 | 在 Pakala 设备包里的实际状态 |
|---|---|---|
| `AndromedaPkg/Driver/SimpleFbDxe` | **存在，源码 254 行**（`Platforms/AndromedaPkg/Driver/SimpleFbDxe/SimpleFbDxe.{c,inf}`） | **5 个 SM8750 设备包全部 `INF` 启用**（`DXE.inc` 第 1 行、`APRIORI.inc` 第 165 行） |
| `$(DEVICE)/PatchedBinaries/DisplayDxe.inf`（厂商二进制） | 文件存在于 `PatchedBinaries/` | **5 个包里全被注释掉** `#INF` |
| `AndromedaPkg/Driver/DisplayCallerDxe` | 存在 | **5 个包里全被注释掉** `#INF` |
| `DisplayReEnablerDxe`（Mu-Silicium） | 存在（`Silicon/Qualcomm/QcomPkg/Drivers/`，C 仅 41 行 + INF 25 行） | **Pakala 设备包不用它**；它只是「ExitBootServices 前把 `EFIDisplayPwr` off→on 一次」的**补丁级**驱动 |

### 2.2 `SimpleFbDxe` 到底做了什么（源码级已证）

`SimpleFbDxeInitialize()` 全文只有 4 步，**没有任何 DSI/panel/PHY/clock 初始化代码**：

```c
LocateMemoryMapAreaByName("Display Reserved", &DisplayMemoryRegion);   // ← 从内存映射表按名字取已存在的 framebuffer
UINT32 MipiFrameBufferAddr   = DisplayMemoryRegion.Address;
UINT32 MipiFrameBufferWidth  = FixedPcdGet32(PcdMipiFrameBufferWidth);  // ← PCD
UINT32 MipiFrameBufferHeight = FixedPcdGet32(PcdMipiFrameBufferHeight); // ← PCD
...
mDisplay.Mode->Info->PixelsPerScanLine = MipiFrameBufferWidth;   // stride = width（无 padding）
mDisplay.Mode->Info->PixelFormat = PixelBlueGreenRedReserved8BitPerColor;  // BGRA8888 / 32bpp
mDisplay.Mode->FrameBufferBase = FrameBufferAddress;
...
ZeroMem((VOID *)FrameBufferAddress, FrameBufferSize);   // ← 清屏
InstallMultipleProtocolInterfaces(&h, ..., &gEfiGraphicsOutputProtocolGuid, &mDisplay, NULL);  // ← 装 GOP
```

**因此「亮屏」的真实含义 = 「ABL 交来的 `Display Reserved` 区域本来就是一块被点亮的面板显存」**。
UEFI 侧只是把这块**已有的** framebuffer 包装成 `EFI_GRAPHICS_OUTPUT_PROTOCOL`，让 `GraphicsConsoleDxe` 能在上面画字。

| 项 | 来源（已证） |
|---|---|
| 谁真正点亮面板 | **ABL（厂商 XBL/ABL 的 Display 驱动）**，在 `fastboot boot` 交棒**之前**就已初始化 DSI + panel + backlight |
| framebuffer 物理基址 | 内存映射表条目 **`"Display Reserved"`**，`LocateMemoryMapAreaByName` 按名字查 |
| 分辨率 | **`gAndromedaPkgTokenSpaceGuid.PcdMipiFrameBufferWidth/Height`**（编译期 FixedPcd） |
| stride | **= width**（源码硬编码 `PixelsPerScanLine = Width`，无对齐 padding） |
| 像素格式 | **BGRA8888 32bpp**（`PixelBlueGreenRedReserved8BitPerColor`）硬编码 |
| 是否用 DTB chosen / ACPI | **都不用**。DTB 在设备包里是 6 字节 `dummy` 占位符（§5）；ACPI 只在 OS 阶段用 |
| 是否需要厂商二进制补丁 | **不需要**。`DisplayDxe`/`DisplayCallerDxe` 全被注释 |

### 2.3 五设备的关键参数对比（**全部相同，除 PCD**）

| 项 | lenovo-y700g4 | xiaomi-piano | oneplus-erhai | oneplus-dodge | nubia-nx789j |
|---|---|---|---|---|---|
| `Display Reserved` 基址 | `0xFC800000` | `0xFC800000` | `0xFC800000` | `0xFC800000` | `0xFC800000` |
| 长度 | `0x02B00000` (43 MiB) | 同 | 同 | 同 | 同 |
| ArmAttributes | `WRITE_THROUGH_XN` | 同 | 同 | 同 | 同 |
| `Display Demura` | `0xA3500000` `0x02C80000` | 同 | 同 | 同 | 同 |
| 分辨率 PCD | **1904×3040** | **3200×2136** | **3392×2400** | 1440×3168 | 1216×2688 |
| framebuffer 需求 | 1904·3040·4 = **23.1 MB** | 3200·2136·4 = **27.3 MB** | 3392·2400·4 = **32.6 MB** | 18.3 MB | 13.1 MB |
| 43 MiB 区域够吗 | ✅ 富余 | ✅ | ✅（32.6 ≤ 43） | ✅ | ✅ |

⇒ **我们的显示参数不是缺环**：基址、大小、属性、驱动代码与已证亮屏的 dodge **完全一致**；分辨率 PCD 已按 1904×3040 配好，且 23.1 MB 远小于 43 MiB 预留。

### 2.4 是否需要 UFS 先起来？（**不依赖**，已证）

`APRIORI.inc` 顺序（lenovo-y700g4，行号即加载顺序）：

| 行 | 驱动 | 说明 |
|---|---|---|
| 3–19 | `DxeMain` / `Pcd` / `EnvDxe` / `CpuDxe` / `ArmGicDxe` / `TimerDxe` | 基础设施 |
| 21–58 | `RamPartitionDxe` / `SmemDxe` / `DALSYSDxe` / `HWIO` / `TLMM` / `I2C` / `SPMI` / `PmicDxeLa` / `ClockDxe` | 平台初始化 |
| **76** | **`PatchedBinaries/UFSDxe.inf`** | UFS |
| 78 | `FatPkg` | 文件系统 |
| 111 | `WatchdogTimer` | |
| 119 | `FontDxe` | **字体（画字需要）** |
| 120 | `BdsDxe` | BDS |
| **165** | **`AndromedaPkg/Driver/SimpleFbDxe`** | **GOP 生产者** |
| 180 | `SimpleTextInOutSerialDxe` | |
| 182–183 | `ConSplitterDxe` / **`GraphicsConsoleDxe`** | **控制台消费者（依赖 GOP）** |

**判据（源码级）**：`SimpleFbDxe.inf` 的 `[Depex]` 只有 **`gEfiCpuArchProtocolGuid`**（= `CpuDxe`，第 14 行）。
它**不依赖** UFS、不依赖 `PmicDxeLa`、不依赖 `ClockDxe`、不依赖 `SmemDxe`。
⇒ **GOP 完全可以在 UFS 之前建立**。UFS 在 APRIORI 里排 76 只是编排序，不是 Depex 约束。

⚠️ 但要注意：**`GraphicsConsoleDxe`（行 183）需要 `ConSplitter`+`FontDxe`**，而这些在 UFS(76) 之后。
所以「**把文字画到屏上**」需要走到行 183；「**点亮/清屏**」只需行 165。

### 2.5 ★关键反证：**我们自己的 UEFI 已经亮过屏**（2026-10-05，已证）

这是本次回挖**最重要**的发现，且**推翻了本任务的前提假设**（「我们无屏无串口」）：

| 证据 | 内容 | 出处 |
|---|---|---|
| 2026-10-05 上机 `fastboot boot lenovo-y700g4_NOSB.img`（CI 产物 sha `9607a394…`） | **屏上出现了 EDK2 DxeCore 的同步异常处理器文字**：`Synchronous Exception at 0x00000000d2b20224` + `recursive exception occurred while dumping the cpu state`，**反复刷屏** | 会话 `.pi/sessions/2026-10-05T06-05-48-388Z_01a10aab-….jsonl`（用户原话轮次 `[145]`/`[180]`/`[188]`）；`.pi/sessions/2026-10-05T02-47-29-424Z_01a109f5-….jsonl`（同事件的分析） |
| 用户当时反馈「**看不清**」「字号太小 + 滚屏太快，无法记录」 | ⇒ **屏幕不仅亮，而且 GOP + GraphicsConsole + FontDxe 全链都在工作** | 同上（`字号`/`看不清` 检索命中） |
| 同会话的助理判定 | 「**ABL 已经接受 BootShim+FD 壳并跳进去了**…屏上是 EDK2 DxeCore 的同步异常处理器，**不是 ABL 的拒绝**」 ⇒ 「崩溃时屏上有字 ⇒ **framebuffer/GOP 已工作**」 | 同上 |
| PC = `0xD2B20224` | 落在 `DXE Heap`（`0xB90C0000`–`0xD65C0000`）区间内 ⇒ **某颗 DXE 驱动执行时炸**，不是 BootShim/PEI | 同上 |

**⇒ 结论口径必须修正**：

| 命题 | 2026-10-27 的旧口径 | 本次回挖的修正 |
|---|---|---|
| 「我们无屏」 | 「屏幕输出依赖 GOP，GOP 在 DXE，PrePi 期不亮」⇒ 推断为无屏 | ❌ **已被 10-05 实测推翻**：10-05 那次**屏幕确实亮了并显示了异常文字**。10-26/10-27 的「全静默」是**另一个**现象（见 §3.2） |
| 亮屏缺件 | 缺显示驱动 | ❌ 不缺。驱动 = `SimpleFbDxe`（源码在仓）、PCD 已配、`Display Reserved` 区域已映射 |

**两次上机现象为何不同（待验证，未上机）**：

| 次 | 日期 | 镜像 | 现象 | 差异候选 |
|---|---|---|---|---|
| ① | 2026-10-05 | `lenovo-y700g4_NOSB.img`（**CI 构建**，sha `9607a394…`，RELEASE + DEBUG 各一） | **亮屏 + 异常文字刷屏** | 未打 BootShim cache 补丁；CI 构建环境；`fastboot --set-active=a` 后 boot |
| ② | 2026-10-26 | `lenovo-y700g4-N2-v0.img`（**本地构建 + v0 重打包 + BootShim `dc civac` 补丁**，sha `0cef239a…`） | **全程联想 logo，无任何切换**（用户目视 19:18:56–19:20:18） | 加了 cache maintenance；**`--header_version 3` → 手工重打成 v0**；本地构建 |
| ③ | 2026-10-24 | `A`/`C` 变体 | 早死（无可见性） | 换了厂商 UFSDxe / RmVmDxe |

⇒ **头号待查变量：BootShim 的 `dc civac`/`ic iallu` 补丁是否反而抹掉了可见性**（`ZeroMem` 之前就崩 vs 之后崩）；**次号：v0 vs v3 重打包是否改了载荷布局**（重打包用的是 v3 镜像 offset=4096 起的 kernel，若 offset 算错则 FD 被截断）。这两条都能**纯主机侧**先验证（§6）。

## 3. 对 TB322FC / lenovo-y700g4 的差距表

### 3.1 逐项对比（我们 vs 已证亮屏的 dodge）

| 项 | 我们 `lenovo-y700g4` | `oneplus-dodge`（Display ✅ 已证） | `xiaomi-piano` / `oneplus-erhai`（平板，未证实） | 差距 |
|---|---|---|---|---|
| `SimpleFbDxe`（GOP 生产者） | ✅ `INF` 启用（DXE.inc L1、APRIORI L165） | ✅ 同 | ✅ 同 | **无** |
| `Display Reserved` 区域 | ✅ `0xFC800000` / 43 MiB / `WRITE_THROUGH_XN` | ✅ **逐字节相同** | ✅ 逐字节相同 | **无** |
| 分辨率 PCD | ✅ 1904×3040（23.1 MB ≤ 43 MiB） | ✅ 1440×3168 | ✅ 3200×2136 / 3392×2400 | **无** |
| `FontDxe` | ✅ `INF` 启用（APRIORI L119） | ✅ | ✅ | **无** |
| `GraphicsConsoleDxe` | ✅ `INF` 启用（APRIORI L183） | ✅ | ✅ | **无** |
| 厂商 `DisplayDxe` 二进制 | ⛔ 注释掉（不需要） | ⛔ 注释掉 | ⛔ 注释掉 | **无** |
| `DisplayReEnablerDxe` | 不用 | 不用 | 不用 | **无** |
| `PatchedBinaries` 集合 | SPMI/UFS/UsbConfig/Clock/PmicDxeLa/QcomWDog | **同 6 个** | **同 6 个**（erhai 多 `PhoenixDxe`） | **无** |
| `PcdSystemMemorySize` | 12 GiB（本单元 16 GB） | 12 GiB | 12 GiB | 平台级共同缺口，非显示 |
| 内存映射/配置映射 | 与 piano **逐字节相同或仅差两个多线程开关** | 同族 | — | **无**（10-05 已核） |
| 已证亮屏 | ✅ **是**（2026-10-05，异常文字刷屏） | ✅ 是（Status.md） | ❌ 未证实 | — |

### 3.2 我们的失败点判定：**既不是「显示缺件」也不是「UFS 挡在显示前」，而是「DXE 早期某颗驱动炸」**

判据链（全部来自本仓已有日志/报告，**非推测**）：

| # | 事实 | 出处 | 推论 |
|---|---|---|---|
| 1 | 2026-10-05：屏上出现 `Synchronous Exception at 0xD2B20224` + `recursive exception while dumping the cpu state`，**反复刷屏** | 会话 `2026-10-05T06-05-48-388Z` / `2026-10-05T02-47-29-424Z` | 屏幕/GOP/字体/控制台**全工作** ⇒ 显示不是失败点 |
| 2 | PC `0xD2B20224` ∈ `DXE Heap` `0xB90C0000`–`0xD65C0000` | 同上 | 崩在 **DXE 阶段的某颗驱动**，不在 BootShim/PEI |
| 3 | `recursive exception while dumping the cpu state` | 同上 | 异常处理器自己也踩空 ⇒ 栈/MMU/关键映射被破坏 ⇒ **严重早期 DXE 故障** |
| 4 | 10-24 静态分析：`ufs_error_log: 11/3b/55`（`UFS.c+2326`） | `reports/uefi-runtime-table-provider-20261024.md`、`reference/upstream-mu-silicium/README.md` §2 | UFS 确实也在失败——但这是**第二故障**，不是显示前置 |
| 5 | `SimpleFbDxe` Depex 仅 `gEfiCpuArchProtocolGuid` | `SimpleFbDxe.inf` 源码 | 显示**逻辑上不依赖 UFS** ⇒ 「绕过 UFS 换早期可见性」**本来就成立** |
| 6 | 10-26 上机：**全程联想 logo，零切换** | `reports/uefi-n2-v0-attempt-20261026.md` §0 | 这次连 DXE 都没进到能崩的程度 ⇒ **回归**（见 §2.5 差异候选） |

**⇒ 判定**：

- **不是「显示之前卡在 UFS」**（`SimpleFbDxe` 不依赖 UFS，且 10-05 已证屏亮）。
- **不是「显示本身缺件」**（驱动源码在仓、PCD 已配、区域已映射、10-05 已亮）。
- **是「DXE 早期某颗驱动炸」（PC `0xD2B20224`）**，且**10-26 那次连这一步都没到**。
- 因此「只补显示、绕过 UFS」这条路径 **已经是既有事实，不需要新建**；真正要做的是 **恢复 10-05 的可见性并让它稳定**。

### 3.3 「只补显示、绕过 UFS」的最小路径（结论：**无需新建，改为复现 10-05**）

原本以为要做的事 | 实际情况
---|---
找/移植显示驱动 | ❌ 不需要。`SimpleFbDxe` 已在仓且在编。
补 PCD | ❌ 不需要。1904×3040 已配。
绕过 UFS 才能亮屏 | ❌ 不需要。Depex 已证明显示不依赖 UFS。
**真正要做的** | ✅ **找回 10-05 那个能亮屏的镜像/构建路径，并解释 10-26 为何回归**（§4） |

## 4. 最小实验计划（不上机，只写配方）

### 4.1 前提修正（必须先接受这三条，否则实验是白做）

| # | 事实 | 后果 |
|---|---|---|
| 1 | **我们的 UEFI 已经亮过屏**（2026-10-05，屏上出现 EDK2 异常文字并刷屏，用户抱怨「字号太小/看不清」） | 「找亮屏方案」是**伪需求**；要做的是**复现 10-05** |
| 2 | 10-05 用的是 **CI 构建的 `header_version=3`** 镜像（会话内 `header_version=3` 解析记录 ×4），且**能真跳** | 10-24 的「v3 不交棒」结论**只对本地重打包的那批成立**，不是普遍规律 ⇒ 待澄清（§6） |
| 3 | 亮屏通道 = **`USE_SCREEN_FOR_SERIAL_OUTPUT=1`（NoSb）⇒ `FrameBufferSerialPortLib` 直接写 `Display Reserved`**，**不需要 GOP**、不需要 `SimpleFbDxe`、不需要 UFS | ⇒ **早期可见性在本仓是已实现的**，不是待开发项 |

### 4.2 实验 E-1：**恢复 10-05 可见性**（第一优先，变量数 = 1）

目标：拿回「屏上有字」。这是所有后续 UFS 实验的**前提工具**。

| 项 | 内容 |
|---|---|
| **唯一变量** | 用 **CI 口径构建**（`WM_CI_BUILD=true`，即 `build_uefi.py` 同时跑 `PlatformBuild.py`+`PlatformBuildNoSb.py`）**而非**本地 `-t RELEASE` 单跑 |
| 镜像 | `Build/PakalaPkg/ci_artifacts/lenovo-y700g4/lenovo-y700g4_NOSB.img`（历史 sha `9607a394…adad555`，9.3 MB 产物包内） |
| DSC | **`PakalaNoSb.dsc`**（`USE_SCREEN_FOR_SERIAL_OUTPUT=1`）—— **不要用 `Pakala.dsc`**（=0，无屏输出） |
| 换/保留 DXE | **全部保留**（`SimpleFbDxe` / `FontDxe` / `GraphicsConsoleDxe` / `ConSplitterDxe` 均在 APRIORI）；**不加** `DisplayDxe`/`DisplayCallerDxe`（上游 5 包均注释） |
| 判据（强） | 屏上出现**白字黑底**的 DEBUG 行（如 `Loading driver at 0x…` / `PROGRESS CODE:`） |
| 判据（中） | 屏上出现 `Synchronous Exception at 0x…` + 寄存器块 |
| 判据（弱/失败） | 全程联想 logo，无切换（= 10-26 现象） |
| 回退 | `fastboot set_active b` → `fastboot reboot`（~20 s 回 Linux） |
| 需物理 POR？ | **是**（用户在场）：失败后设备会自动回落，但若卡死需长按电源 |

### 4.3 实验 E-2：**定位早死点**（依赖 E-1 成功）

E-1 出字后，把 10-05 的 **`UFSDxe.dl1` 栈回溯**当模板，逐个变量收敛：

| 臂 | 变量 | 目的 |
|---|---|---|
| E-2a | `PatchedBinaries/UFSDxe.efi` → 厂商 `fa561bf1…`（151 552 B） | 验证 UFSDxe 是否仍是第一炸点 |
| E-2b | `PatchedBinaries/ClockDxe.efi` → `Binaries/ClockDxe/ClockDxe.efi`（原厂） | 10-05 会话已点名 ClockDxe 是 108 KB 差异的替换件 |
| E-2c | 只留 `SimpleFbDxe`+`FontDxe`+`GraphicsConsoleDxe`，**把 `UFSDxe` 整行注释掉** | **这是真正的「绕过 UFS 换可见性」**；UFS 不在则 BDS 无盘，但屏上应有字与 Shell |

E-2c 的价值：**一次性证明「显示完全不依赖 UFS」**（Depex 已静态证明，此臂是动态闭合），并给出一个**无 UFS 的最小可交互 UEFI**。

### 4.4 实验 E-3（用户要求 B 项）：**tiny DXE 拉 UFS link state**

详见 §5.3。**不建议先做这个** —— 它需要 E-1 提供的可见性来判定成败。

### 4.5 变量个数

| 实验 | 变量数 | 备注 |
|---|---|---|
| E-1 | **1** | 构建路径（CI 双跑 vs 本地单跑） |
| E-2a/b/c | **1 each** | 单二进制替换 / 单行注释 |
| E-3 | **≥3**（link 唤醒时机、polling 超时、gear 重试） | 且无可见性时不可判 |

---

## 5. 可搬资产清单

### 5.1 已落盘小件（`reference/uefi-samechip-20261028/`，112 KB）

| 文件 | 大小 | 许可 | 用途 |
|---|---|---|---|
| `SimpleFbDxe.c` / `.inf` | 254 行 / 51 行 | **BSD-2-Clause-Patent** | GOP 生产者（**不初始化硬件**，只包装 `Display Reserved`） |
| `FrameBufferSerialPortLib.c` | 8 642 B | BSD-2-Clause-Patent | **早期可见性真身**：直接把 DEBUG 写到 framebuffer |
| `MsEarlyGraphicsLib.inf` | 953 B | BSD-2-Clause-Patent | Microsoft Early Graphics 库定义 |
| `Andromeda.dsc.inc` | — | BSD-2-Clause-Patent | `USE_SCREEN_FOR_SERIAL_OUTPUT` 的 `SerialPortLib` 分支（§2.5 证据） |
| `APRIORI-lenovo-y700g4.inc` | 198 行 | BSD-2-Clause-Patent | 加载顺序（UFSDxe=76、SimpleFbDxe=165、GraphicsConsole=183） |
| `PlatformMemoryMapLib-lenovo-y700g4.c` | 64 行 | BSD-2-Clause-Patent | `Display Reserved = 0xFC800000 / 0x02B00000` |
| `PakalaNoSb.dsc` / `Pakala.dsc` | 各 ~95 行 | BSD-2-Clause-Patent | **屏输出开关的唯一差异点**（L31: 1 vs 0） |
| `PcdsFixedAtBuild-*` | 3 份 | BSD-2-Clause-Patent | 5 设备分辨率/ConOut 对照 |
| `sm8750_xiaomi_pad8p.yml` | — | BSD-2-Clause-Patent | 唯一 SM8750 CI 工作流（证明平板设备包可编译） |
| `Mu-Silicium-Status-SM8750-section.md` | 122 行 | — | 取证原文（SM8750 段全文） |
| `DisplayReEnablerDxe.c`/`.inf` | 41/25 行 | BSD-2-Clause-Patent | 未采用（Pakala 5 包均不用它） |
| `NOTES-取证片段.md` | — | — | 网络中断前取到的 PCD 片段（逐字） |

### 5.2 需要但**未**取到（网络中断）

| 资产 | 路径 | 状态 |
|---|---|---|
| `MsEarlyGraphicsLib.c` | `Platforms/AndromedaPkg/Library/MsPlatformEarlyGraphicsLib/` | 文件名与 INF 里不同（INF 写 `MsEarlyGraphicsLib.c`），**未取** |
| `GopOverrideDxe` / `MsEarlyGraphicsDxe` 源码 | 不在 `AndromedaPkg/Driver/`（API 404） | **未定位**（可能在 `MU_BASECORE` 子模块） |
| `dodge` 的 `UFSDxe.patched.efi` | `Project-Silicium/Device-Binaries/dodge/QcomPkg/Drivers/UFSDxe/UFSDxe.patched.efi` | 155 648 B，sha256 **`e76b555f7c855784cc03303ae1044c69b24f04f214a320a8e2ea101b4f3c85ef`**（已知值，本轮未重下） |

### 5.3 B 项：「tiny DXE 拉 link state」可行性评估

**上游主张**（2026-10-28T04:27:34Z，issue #12 第 4 条评论）：「UFS 问题是 Link State 处于 Sleep 状态，你让 AI 写个 tiny dxe 用来把 link state 拉起来不就行了」。
**证据等级：上游主张，我方未证实。**

#### (a) dodge 补丁语义 vs 我方失败点对齐

| 层 | dodge 的做法 | 我方现象 | 是否同一层 |
|---|---|---|---|
| **UFS 协议层 link state** | 补丁 1「The UFS Sleep call has been Replaced with the UFS Wakeup Call」；补丁 2「Force UFS Link Wake Up Function to run before Gear Check」 | `ufs_error_log: 11/3b/55`（`UFS.c+2326`，属 **link/gear 阶段**） | **可能同一层**（gear check 前 link 未醒 ⇒ gear 失败） |
| **SMMU / 地址翻译** | 未涉及 | `UFSDxe` `Synchronous Exception` 且 `ESR=0x96000005` = **Data abort: Translation fault, second level**、`FAR=0x0` | **不同层**（这是 MMU 映射缺失，不是 link state） |
| **UFSDxe 二进制代次** | dodge 用 `e76b555f…`（155 648 B） | **已否证**：本机 Mu 件与厂商件只差 6 字节（全是 build 路径串 `mp250526` vs `mp251201`）；159 744 B/`KaanapaliLAA` 26310 那版**只存在于 `plk110`/`salami`** | **不成立** |

⇒ **关键判断**：上游的「link state = Sleep」只能解释 **`ufs_error_log 11/3b/55` 这一层**；
它**解释不了** 10-05 抓到的 `ESR 0x96000005 / Translation fault, second level / FAR=0x0`（那是 SMMU 页表缺项）。
两层独立 ⇒ **即使 tiny DXE 成功把 link 拉起来，仍可能卡在 SMMU 层**。

#### (b) 「自写 tiny DXE」vs 「直接换 dodge 二进制」取舍

| 维度 | ① 自写 tiny DXE | ② 换 dodge `UFSDxe.patched.efi`（`e76b555f…`） |
|---|---|---|
| 工作量 | 高（要调 UIC 命令、poll `UFS_UIC_HCS`、超时重试、depex 排序） | **零**（拷文件 + 改一行 INF） |
| 前提 | 必须先有可见性（E-1） | 无（但**判据也需可见性**） |
| 风险 | 中（自己写 UIC 序列可能把链路搞进更差状态） | **中高**：dodge 的 UFSDxe 是 **OnePlus 13 的 PHY/供电配置**，我方 PMIC/Clock 不同（虽然 5 包 `Display Reserved` 与内存映射相同，但 **UFS PHY 与 regulator 未验**） |
| 可控性 | 高（能只做 link wake，不碰 gear/PMIC） | 低（整枚替换，含未知的 dodge 专属路径） |
| 上游支持 | **作者亲口建议的形状** | 作者未推荐；且 `Device-Binaries/dodge/README.md` 自己标 **「These Patches are Outdated & Unstable!」** |
| 与既有结论的关系 | 与 `reference/upstream-mu-silicium/README.md` §3 的「只换 UFSDxe」配方**不同**（那条已被本机否证为代次差） | 同旧配方 |

#### (c) 推荐顺序与最小验证判据

```
E-1（拿回可见性，1 变量）
  └─ 成功（屏出字）
      ├─ E-2c（注释掉 UFSDxe）：证明显示独立于 UFS，得到一个「无 UFS 但能出字/进 Shell」的最小 UEFI
      ├─ E-2a（换厂商 fa561bf1…）：确认 UFSDxe 是否第一炸点
      └─ 若 E-2a 仍报 ufs_error_log 11/3b/55（且无 Synchronous Exception）
          └─ **才**做 E-3 tiny DXE（此时上游的 link-state 假设才成为唯一候选）
```

| 实验 | 判据（必须能区分层） |
|---|---|
| E-3 成功 | `ufs_error_log 11/3b/55` **消失** 且出现 `SimpleFileSystem` 句柄 / `map -r` 能列分区 |
| E-3 部分成功 | link 起来了但 `Synchronous Exception`（`ESR 0x96…05`）出现 ⇒ **转到 SMMU 层**，tiny DXE 方向到此为止 |
| E-3 无效 | 现象与 E-2a 完全一致 ⇒ link state 不是本机根因，**推翻上游假设** |

#### (d) tiny DXE 的工程前提（上游未答，我方已列为提问）

1. **排序**：`UFSDxe.depex` = `06 08`（= `TRUE`，无自带顺序约束），在 `APRIORI.inc` 第 **76** 行。tiny DXE 要么 depex 依赖某协议，要么插到 APRIORI 第 75 行前 —— **两者都需确认不会让 UFSDxe 提前跑**。
2. **层级判据**：DEBUG 构建下 `Start EBS` 之后应出现的第一行是什么（用于判定「tiny DXE 到底有没有跑」）。
3. **UIC 命令序列**：上游未给。需从 `UFS.c` 反汇编或 UFSHCI 规范（`DME_` / `UFS_UIC_COMMAND`）自行推导。

> 这两条已写入 2026-10-28 的 issue #12 评论（`reports/uefi-issue12-reply-draft-20261028.md` §3），**不重复发送**。

## 5. 可搬资产清单

> 待填

## 6. 未证实项 / 风险 / **更正**

### 6.1 必须更正的两条既有结论

| # | 旧结论 | 出处 | 本次裁决 |
|---|---|---|---|
| 1 | 「UFSDxe **代次差**是本机 UFS 失败的原因」（159 744 B / `KaanapaliLAA` 26310 vs 本机 151 552 B） | `reference/upstream-mu-silicium/README.md` §5；`TASKS/README.md` §4 N1 | ❌ **已否证（本机）**：`lenovo-y700g4` 的 Mu 未打补丁件 `dac620ac…` 与厂商件**只差 6 字节**（全在 build 路径串 `mp250526` vs `mp251201`）；Mu 补丁件 `00ae059f…` 差 32 字节（`0xa998`/`0x114c4`/`0x1b080`）。159 744 B 那版**只存在于 `plk110`/`salami` 设备包**，y700g4 不用它 |
| 2 | 「本机无早期可见性（UART=0、无 UsbSerial、屏幕输出依赖 GOP ⇒ PrePi 期不亮）」 | `reports/uefi-control-experiment-20261027.md` §4 | ⚠️ **部分推翻**：`USE_SCREEN_FOR_SERIAL_OUTPUT=1`（`PakalaNoSb.dsc:31`）把 `SerialPortLib` 换成 **`FrameBufferSerialPortLib`**，它直接写 `Display Reserved`（`0xFC800000`）+ `PcdMipiFrameBuffer{Width,Height,PixelBpp}`，**完全不依赖 GOP**。2026-10-05 实测已证（屏上出 `Synchronous Exception` 文字）。⇒ 「依赖 GOP」的判断是**错的**；「10-26/10-27 那几次为什么没出字」才是待查项 |

### 6.2 上游主张（我方未证实）

| 主张 | 来源 | 等级 | 我方评估 |
|---|---|---|---|
| 「UFS 问题是 **Link State 处于 Sleep**，写个 tiny DXE 把 link 拉起来」 | issue #12 第 4 条评论（2026-10-28T04:27:34Z，60 字符） | **上游主张** | **方向可信但与现象不完全对位**：能解释 `ufs_error_log 11/3b/55`（link/gear 层），**解释不了** `ESR 0x96000005 / Translation fault, second level / FAR=0x0`（SMMU 层）。两层独立（§5.3） |

### 6.3 本次未能证实的关键项

| 项 | 为何重要 | 当前状态 |
|---|---|---|
| **10-05 能亮屏 vs 10-26 不亮屏的真正差异** | 这是「拿回可见性」的唯一变量 | **未证实**。已收窄到 3 个候选：① **v3 vs v0 重打包**（10-05 用 `header_version=3` 且能跳；10-24/26 结论是「v3 不跳」，**两者矛盾**）② CI 双跑（`WM_CI_BUILD=true` 同时产 SB+NoSb）vs 本地 `-t RELEASE` 单跑 ③ BootShim `dc civac` 补丁（10-26 才加） |
| **v0 重打包是否损坏载荷** | 若是，10-26 的「全静默」是**打包事故**而非 UEFI 问题 | ✅ **已排除（本次实测）**：`uefi-v0-20261027/lenovo-y700g4-{N2,A2}-v0.img` 的 `kernel_addr=0x8000` 是 **RAM 载入地址**（对应 `--kernel_offset 0x8000`），**不是文件偏移**；kernel 实际在 page 1 = `4096`，`4096+2436721=2440817 ≤ 2441216` **装得下**，`gunzip` → 4 194 464 B、`eof=True`，payload sha 与 v3 版**逐字节相同**（`25e8c6bd…` / `63cccdb7…`）。⇒ **v0 重打包干净，不是静默原因** |
| **平板（xiaomi-piano / oneplus-erhai）是否真的亮过屏** | 用户记忆的核心 | **未证实**：Mu-Silicium 官方 Status.md 的 SM8750 段**无平板行**；无 CI 产物下载记录、无作者报告。**已证亮屏的只有同 SoC 的两台手机**（dodge / pagani） |
| `MsEarlyGraphicsDxe` / `GopOverrideDxe` 源码位置 | 若要改早期图形行为 | **未定位**（`AndromedaPkg/Driver/` 下 API 404，可能在 `MU_BASECORE` 子模块） |
| `Panel_elden_nt36523_csot_3k_dsc_video_panel.xml` 是否匹配本机面板 | 已证**存在于我们构建的 FV 内**（`/tmp/nested.fv` 提取确认，另有 `Panel_elden_nt36523_csot_dsc_video_panel.xml`） | **未证实是否被 ABL 使用**（面板由 ABL 初始化，UEFI 侧只是引用名字） |

### 6.4 风险

1. **平板设备包无验证记录**：`xiaomi-piano`/`oneplus-erhai` 的 PCD 齐备、CI 工作流存在，但**没有任何人报告过能亮屏**。拿它们当「已验证参照」是**过度推断**。
2. **`fastboot boot` 跨设备包有风险**：不同设备包的 PMIC/Clock 配置不同，虽零写盘但可能需长按重启（10-05 会话已标为「边界实验，需用户同意」）。**本报告不建议做**。
3. **dodge 二进制自带警告**：`Device-Binaries/dodge/README.md` 顶部明写 **「These Patches are Outdated & Unstable!」**。
4. **本次网络中断**：后段 `raw.githubusercontent.com` TLS `unexpected eof`（直连与 `127.0.0.1:7890` 均 `000`，重试 3 轮全失败）⇒ §5.2 列出的 3 项资产未取到；§1 的 4 个设备 PCD 只有 grep 片段（`xiaomi-piano` 有全文件）。

---

## 7. 取证记录

| # | 手段 | 结果 |
|---|---|---|
| 1 | `curl` Mu-Silicium `Status.md`（5 696 行） | SM8750 段 = 第 798–919 行，**2 台设备**，Display 全 ✅ |
| 2 | GitHub contents API（带 `gh auth token`）扫 `mu_wide_platforms/Platforms/PakalaPkg/Device` | **5 个** SM8750 设备包 |
| 3 | 逐包 `grep` `PcdsFixedAtBuild.dsc.inc` / `DXE.inc` / `APRIORI.inc` / `PlatformMemoryMapLib.c` | 显示路径 5 包同源；`Display Reserved` 逐字节相同 |
| 4 | 取 `SimpleFbDxe.c`（254 行）+ `FrameBufferSerialPortLib.c` 源码 | 确认**均不初始化显示硬件**，只包装 `Display Reserved` |
| 5 | `Andromeda.dsc.inc` 的 `USE_SCREEN_FOR_SERIAL_OUTPUT` 分支 + `PakalaNoSb.dsc:31` | 确认 NoSb 的早期可见性通道 |
| 6 | 本地 `scripts/ffs-extract.py` 逐层解 `SM8750_EFI-N2.fd` → LZMA @`0xd268` → 12 865 544 B FV → **219 个 FFS** | 确认 `SimpleFbDxe`(GUID `dcfd1e6d`)、`FontDxe`、`GraphicsConsoleDxe`、`ConSplitterDxe`、`MsEarlyGraphicsDxe`、`GopOverrideDxe`、`DisplayEngine` 全在内；且含 **`Panel_elden_nt36523_csot_3k_dsc_video_panel.xml`** |
| 7 | 解出的 FV 内查 `Synchronous Exception` / `Recursive exception` | `Recursive exception` @`0x9e3a15` 存在（异常处理器在 FV 内）；`Synchronous Exception` 字符串不在（由 DxeCore 的 `ASSERT`/异常模块拼接） |
| 8 | 检索历史会话 `.pi/sessions/2026-10-05T{02-47-29,06-05-48}*.jsonl` | **命中「亮屏」原证**：用户贴出屏上 `Synchronous Exception at 0x000000001264D224` + `UFSDxe.dl1` 栈回溯；另一轮 `0xD2B20224` + `recursive exception`；并抱怨「字号太小/看不清」 |
| 9 | 同会话 `header_version` 解析记录 | 4 个镜像均 `header_version=3`，其中 `lenovo-y700g4_NOSB.img` 当时**能真跳**（与 10-24「v3 不跳」矛盾） |
| 10 | 本机二进制核对 `uefi-v0-20261027/*.img`（4 枚） | **v0 重打包干净**：`kernel_addr=0x8000` 是 RAM 载入地址（非文件偏移）；kernel 在 page1=`4096`，`4096+ks ≤ 文件长`，`gunzip` 4 194 464 B `eof=True`；payload sha 与 v3 版**逐字节相同** ⇒ 排除「重打包损坏」 |
| 11 | `gh` issue #12 评论（编排者核实，本次未重发） | 上游主张「link state = Sleep」；我方 2026-10-28T11:04:46Z 回帖 5 423 字符已发布 |
