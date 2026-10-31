# PrePi 时刻能不能写屏 —— 静态前置调查（2026-10-31，lane uefi-vis，L1，零上机）

> 派工单：uefi-vis「PrePi 时刻能不能写屏」。背景：A2 交棒后全静默；R1 证明 shim（重定位前）写
> `0xFC800000` 会让 shim 自毁 ⇒ 不交棒。本报告只做静态取证 + 编译验证，零设备操作。
> 证据树 = `build/uefi-woa-prep/repos/7-mu-lenovo`（HEAD `6b6ac42a`，结束已还原干净）。

## §0 四问一句话答案（先行表）

| # | 问题 | 一句话答案 |
|---|---|---|
| 1 | 全静默 = 「没东西可打印」吗？ | **不是。** RELEASE 下 `PcdDebugPrintErrorLevel=0x00000000`（`Andromeda.dsc.inc:59`），DEBUG() 全灭，但 PrePi 路径有 **3 处不经 DEBUG() 门控的 `SerialPortWrite`**：① `PrePi.c:134-143` 的固件 banner（无条件）；②③ 异常处理器 `DefaultExceptionHandler.c:200/207`（无条件）。**只要 UEFI 活到 PrePiMain 的 banner，屏上必然有字** ⇒ 「无输出」仍然构成「早死」证据，但死点被夹紧在「UEFI 入口 ~ `PrePi.c:143`」之间。 |
| 2 | PrePi 入口时刻 `0xFC800000` 能不能写？ | **安全。** UEFI 自己的 `ModuleEntryPoint.S:32` 先 `ArmDisableCachesAndMmu`，此后到 `PrePi.c:143` banner 期间 **MMU 是关的**，写 `0xFC800000` 是**裸物理 DDR store**；该区在 `PlatformMemoryMapLib.c:35` 是普通 DDR（`AddMem MEM_RES SYS_MEM_CAP Reserv WRITE_THROUGH_XN`），AP CPU 的 store **不经过 SMMU**（SMMU 只翻译设备 master；且 AndromedaPkg SEC/PrePi 路径**无任何 SMMU 初始化**，`QcomMmuDetachHelperLib` 未被 dsc 引用）。R1 shim 之死与「UEFI 内写屏」不可类比——shim 执行在 ABL 的 MMU 页表下，UEFI PrePi 写屏在 MMU 关闭后。 |
| 3 | 最小插桩方案？ | **存在且已备料编译（rc=0）**：`patches/uefi/20261031-prepi-vis/0001-prepi-entry-framebuffer-marker.patch` —— 在 `PrePi.c` `CEntryPoint` 第一条语句加 `PrePiFbMarker(0x0000FF00)`：向 `0xFC800000` 连写 1904×16 像素红色实心条（16 行）。判读：**红条出现 = UEFI C 入口已到；随后 banner 文字出现 = 活到 PrePiMain；红条出现但无字 = 死在 entry~banner 之间。** |
| 4 | 若正常路径本来就打字，真正的问题是什么？ | 正常路径**本来就会打**（banner + 异常 dump 都无条件），所以对 UEFI 线真正有意义的问题**不是「让正常路径打一行」**，而是「为什么连这份无条件输出也没出现」——即 A2 交棒后是否真的执行了 UEFI 入口；这已由红条/banner 二段判读直接回答，不需要换 UART/USB（那些仍是为「屏写不可见/屏幕已被 ABL 关掉」准备的退路）。 |

## §1 Q1 证据：RELEASE 下 SEC/PrePi 的无条件输出点

**DEBUG 门控值**：`Platforms/AndromedaPkg/Andromeda.dsc.inc:59`（`!else` 即非 DEBUG 分支，PakalaNoSb 走 RELEASE）
`gEfiMdePkgTokenSpaceGuid.PcdDebugPrintErrorLevel|0x00000000`；同分支 `PcdDebugPropertyMask|0x00` ⇒ **DEBUG() 全静、ASSERT 全空转**（`BaseDebugLibSerialPort` 依 `PcdDebugPrintErrorLevel` 过滤，`Andromeda.dsc.inc:123`）。

**不经过 DEBUG() 宏门控的 `SerialPortWrite`（PrePi 阶段，逐一数）**：

| # | 位置 | 内容 | 门控 |
|---|---|---|---|
| 1 | `Platforms/AndromedaPkg/PrePi/PrePi.c:130-143` | `AsciiSPrint("UEFI firmware (version %s built at %a on %a)\n\r",…)` + `SerialPortWrite` | **无条件**（裸调用） |
| 2 | `Silicon/Arm/MU_TIANO/ArmPkg/Library/DefaultExceptionHandlerLib/AArch64/DefaultExceptionHandler.c:200` | "Recursive exception occurred…" | 无条件 |
| 3 | 同文件 `:206-207` | `"%a Exception at 0x%016lx\n"`（异常 dump 首行） | 无条件 |

- 异常处理器已挂钩：`PrePi/AArch64/ModuleEntryPoint.S:45-46` `ldr x0,=PcdCpuVectorBaseAddress; bl ArmWriteVBar`；
  处理器实例 = `Andromeda.dsc.inc:172` `DefaultExceptionHandlerLib|ArmPkg/…/DefaultExceptionHandlerLib.inf`（带格式 dump 的 AArch64 版，非 BaseNull）。
  ⇒ **VBar 生效后任何异常都会走 #2/#3 屏上出字**。
- FB 写的实现链：`SerialPortLib`（USE_SCREEN=1 ⇒ `FrameBufferSerialPortLib`，`Andromeda.dsc.inc:197-201`）`SerialPortWrite`→`FbConPutCharWithFactor` 直写 `Display Reserved`（`FrameBufferSerialPortLib.c:52` 取区 + 写字符位图），不依赖 GOP/DSI。
- 更早的物理写：`CEntryPoint→ArmPlatformInitialize(0)→EarlyInitialization→UartInit→InitializeSharedUartBuffers`（`ArmPlatformLib.c:131/145`，`InitializationUtils.c:23-33`）在 `SerialPortInitialize` 之后把光标计数器写到 fb 尾部 —— 也是无条件物理写，但只写 8 字节，屏上看不见；**第一个屏上可见点 = banner（#1）**。
- 更正一条旧口径：本轮构建**没有**独立的 `ArmPlatformPkg/Sec` 阶段（`Andromeda.dsc.inc:631` SEC 模块 = `AndromedaPkg/PrePi/PeiUniCore.inf`）；前报引用的 `ArchSec.c:45` 属于 PeilessSec/Sec 变体，本机构建不在链接集内，异常入口是上面 ModuleEntryPoint.S:45→DefaultExceptionHandlerLib 这条。

**结论**：正常路径（活着走到 PrePiMain）**一定**有一条 banner。所以 10-30/10-31 的「A2 交棒后全静默」**不是**「没东西可打印」，死点被夹进窗口：
`_ModuleEntryPoint → ArmDisableCachesAndMmu → CEntryPoint → ArmPlatformInitialize → PrePiMain:143`（含 DecompressFirstFv 之前的全部代码，banner 在 Decompress 之前）。

## §2 Q2 证据：`0xFC800000` 在 PrePi 入口时刻的可达性

1. **区的定义**：`Platforms/PakalaPkg/Device/lenovo-y700g4/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c:35`
   `{ "Display Reserved", 0xFC800000, 0x02B00000, AddMem, MEM_RES, SYS_MEM_CAP, Reserv, WRITE_THROUGH_XN }` —— 普通 DDR（非 MMAP_IO/Device），`AddMem`。
2. **何时进页表**：`ArmPlatformGetVirtualMemoryMap`（`Platforms/AndromedaPkg/Library/ArmPlatformLib/ArmPlatformLibMem.c:26-`）把全部 `HobOption != HobOnlyNoCacheSetting` 的条目（含 Display Reserved）转成 `ARM_MEMORY_REGION_DESCRIPTOR`；由 `MemoryPeim`（`PrePi.c:166` 调用）→ `InitMmu`（`MemoryInitPei/MemoryInitPeiLib.c:33-46`）→ `ArmConfigureMmu`（`ArmPkg/Library/ArmMmuLib/AArch64/ArmMmuLibCore.c`，粒度 = L2 2 MB block / L3 4 KB block，`BITS_PER_LEVEL=9` @ `:111`）建表并开 MMU。
3. **但是 banner 时刻 MMU 尚未开**：PrePi 的 `ModuleEntryPoint.S:32`（`bl ASM_PFX(ArmDisableCachesAndMmu)`）在进 C 之前**先关 MMU**；`MemoryPeim` 在 `PrePi.c:166`，晚于 banner（`:143`）。⇒ banner 写屏 = **物理直写 DDR**，与页表无关。
4. **SMMU/XPU**：AndromedaPkg 的 PrePi/ArmPlatformLib/SEC 路径 grep `SMMU|Smmu` 仅命中 `QcomMmuDetachHelperLib`（SMMU v2 寄存器操作封装），该 lib **未被 `Andromeda.dsc.inc` 引用**（grep 命中 0）⇒ SEC 阶段不存在 SMMU 配置动作；且 SMMU 不翻译 AP CPU 的 store。
5. **R1 shim 之死的边界**：shim 执行在 ABL 载入之后、UEFI 之前，跑在 **ABL 的 MMU 页表**下；`0xFC800000` 是否在 ABL 页表里是 ABL 决定的（未取证、不可静态判定）。UEFI 的写屏点在 **MMU 已被 UEFI 自己关掉之后**，二者的地址翻译条件不同，R1 的否证**不外推**到本方案。

**可判定句**：在 `PrePiMain` 的 `SerialPortWrite`（`PrePi.c:143`）以及其前的 `CEntryPoint` 任意处写 `0xFC800000` 是**安全**的，因为此时 UEFI 已执行 `ArmDisableCachesAndMmu`（`ModuleEntryPoint.S:32`）——写是裸物理 DDR store，该区是普通 DDR（PlatformMemoryMapLib.c:35），且 AP CPU store 不经过任何 SMMU（SEC 阶段无 SMMU 初始化，QcomMmuDetachHelperLib 未链接）。唯一残余风险 = 屏幕是否仍被 ABL 点亮（不可静态判定，见 §6）。

## §3 最小插桩方案（已编译验证 rc=0）

- **补丁**：`patches/uefi/20261031-prepi-vis/0001-prepi-entry-framebuffer-marker.patch`（+16 行，`git diff` 直接产出）。
  `CEntryPoint` 第一条语句加 `PrePiFbMarker(0x0000FF00)`：向 `0xFC800000` 连写 **1904×16 像素红色实心条**（32bpp xRGB，顶行 16 行）。
  ① 无新早死风险：物理 DDR 写、不依赖 MMU/GOP/DSI/SerialPortLib 初始化；② 不改任何分支语义（纯新增语句 + 纯新增 static 函数）；③ 编译验证：
  `python3 Platforms/PakalaPkg/PlatformBuildNoSb.py TARGET=RELEASE TARGET_DEVICE=lenovo-y700g4` ⇒ **rc=0**（日志 `reports/artifacts/uefi-prepi-vis-20261031/build-prepi-vis.log`）。
- **反汇编确认 marker 编入**：`ArmPlatformPrePiUniCore.efi` 偏移 `0x1c20: mov w8, #0xfc800000`（objdump 实测）。
- **判读树**（一发 `fastboot boot` 即可）：
  | 现象 | 结论 |
  |---|---|
  | 无红条、USB 不掉线 | UEFI 入口未执行（等价于不交棒，非本载荷） |
  | 无红条、USB 掉线 | 交棒了，但死在 `_ModuleEntryPoint` 前 5 条指令内（几乎不可能） |
  | **红条、无字** | 活到 CEntryPoint，死在 entry→banner（ArmPlatformInitialize/PrePiMain 前段）；或 banner 写屏失败 |
  | **红条 + banner 文字** | UEFI 正常活过 PrePi 入口 ⇒ 「早死」假设被推翻，死亡点后移到 DXE，需换判读 |

## §4 Q4：替代观测面一句话

正常路径**本来就有**无条件屏上输出（banner + 异常 dump），所以**不需要**为「让正常路径打一行」做事；真正待回答的是「连无条件 banner 也没出现 = UEFI 是否真的执行」，红条/banner 二段判读即可闭合。USB ACM/UART 只是「屏幕已被 ABL 关掉（写了看不见）」这一残余风险出现时的退路（未证实，见 `uefi-visibility-channels-20261031.md` §0）。

## §5 产物

`reports/artifacts/uefi-prepi-vis-20261031/`：
- `SM8750_EFI-prepi-vis.fd`（4 194 304 B，sha256 `c6e0e887…abc1b7`）
- `ArmPlatformPrePiUniCore.efi`（含 marker，sha256 `23fc8dac…eac09f3`，`0x1c20 mov w8,#0xfc800000`）
- `build-prepi-vis.log`（stuart_build Success，rc=0）
- `SHA256SUMS`

`patches/uefi/20261031-prepi-vis/0001-prepi-entry-framebuffer-marker.patch`（31 行）。

构建树已还原：`git status --porcelain` = ` M Common/MU_TIANO` + 两个既有 `*.orig-mu` untracked，与开工时一致。

## §6 未证实清单

1. **A2 交棒后屏幕是否仍被 ABL 点亮**（DSI 是否被 ABL 关断）——静态不可判定；若屏已黑，红条/banner 写了也看不见，判读退化为「全无」，需 USB 判据联合解读。
2. R1 shim 死因的精确机制（ABL 页表是否映射 0xFC800000）——未取证，只能说明「shim 时刻 ≠ UEFI 时刻」，不能定罪。
3. 红（0x0000FF00）在当前面板像素格式（RGB888 vs BGR888）下可能显示为蓝色——不影响「有/无色条」判读，只影响色名。
4. 本 FD 含 marker 但**未与 A2 的 cachefix shim/厂商 UFSDxe 组合 repack**——上机载荷组装按 `uefi-swap-x1x2-20261031.md` §4 段一流程由父 agent 执行。
