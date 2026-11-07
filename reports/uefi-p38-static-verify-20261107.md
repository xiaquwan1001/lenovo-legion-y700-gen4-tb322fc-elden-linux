# p38 世代「EB 后真·无 boot service」静态独立复核（verify-worker，只读）

日期：2026-11-07 ｜ 复核对象：`uefi-20261107R33-p38`（G1-29 UEFI 间接引导线）
方式：`llvm-objdump 21.1.8`（`coff-arm64`）+ `LinuxLoader.map` + Python 反汇编扫描（自研 adrp/ldr 绝对地址求解 +
`bl`/`b`（含尾调用）过近似控制流可达集）。**不构建、不上机、不联网、不改仓库文件**（唯一新增 = 本报告）。

---

## 0. 结论

**通过（PASS）。** 三项判据全部成立，且在**过近似**（跟随所有条件分支，不裁决条件）意义上成立：

| # | 判据 | 结果 |
|---|---|---|
| 1 | EB 调用之后 → 跳内核之前，区间内不再有 boot service **调用** | ✅ 0 处。`bl 0x1630c`(EB) 返回点 0x5aa0 起，到内核入口 `blr` 之前，唯一 gBS 访问 = **0x5b2c 读指针 + 0x5b34 读成员**，`0x5b30 cbz` 守卫，其后**从不** `blr` |
| 2 | `SbDumpLogNoBs` 区间内 0 次 `AllocatePool`/`FreePool`、0 次 gBS 访问 | ✅ 0 处（全区间 0x47f4–0x49c8 无 gBS 载入、无池调用；只有静态缓冲） |
| 3 | `SbWriteLogWindowNoBs` 已被内联、缓冲为静态 | ✅ map 中该函数**只有** `SbWriteLogWindowNoBs.m_SbNoBsBuf`（0x39680）这一 static，无独立函数符号；该缓冲全镜像只在 `SbDumpLogNoBs` 内被引用（0x4954/0x4978） |
| 4 | 镜像内载荷 == `payload-v2aligned.bin.gz` | ✅ 逐字节相同（见 §4） |

**残留说明（不判失败，但需知悉，均已在 §3.4 给地址）**：EB 后仍有 ①3 处 `gRT`（runtime 表，非 boot 表）派发；
②1 处固件 **BlockIo 协议方法**间接调用（0x49b0，实现不在本镜像，是否内部偷用 gBS 只能上机证伪）；
③1 处 `pQcomScmModeSwitchProtocol` 方法（AArch32 路径）。这三类都**不是** gBS 表调用，本次修复目标（消灭 EB 后 `gBS->*`）已达成。

---

## 1. 输入件与完整性

| 文件 | 大小 | sha256 |
|---|---|---|
| `reports/artifacts/uefi-20261107R33-p38/obj/LinuxLoader.efi` | 187 904 | `3f14c13885308b29cea7879add8a97eb84811c6a8eeed43b7a73800406699e78` |
| `.../obj/LinuxLoader.map` | 247 579 | `b1cf7a598e8ea1deef193c9c19a5d010932014586ba9c6bcee298db06d069239` |
| `.../SM8750_EFI.fd` | 4 194 304 | `15678b2406fcb4e37aa4a42957fa201cfd8e9e8fd65f561fd48c2960c1fe6d06` |
| `.../payload-v2aligned.bin.gz` | 2 459 508 | `a5c8994e3d5ff0ff91b69083e2c9bdd41d0e84607340a4e0adf6b8ac673e7cde` |
| `out/r21-sbstop-p38/uefi-preamble38-r1.img` | 67 219 456 | `0e2bddbd64fc81f843e064ece98d3b647fcf5ea006a56214fc38c469272badad` ✅与交接值一致 |

反汇编件 = 构建树产物（同 sha）：`build/.../RELEASE_CLANGPDB/AARCH64/LinuxLoader.efi`；
产物 FD = 构建树 FD（同 sha）：`build/.../FV/SM8750_EFI.fd`；
`build.log:5499` 记录该 `.efi` 经 `GenSec -s EFI_SECTION_PE32` 打进 FFS `f536d559-…LinuxLoader`。
（FD 内 FFS 为压缩存储，明文/原始指令在 FD 与 img 中搜不到，故 `.efi↔FD` 的字节级包含关系不成立为直接证据，
以「三方同 sha + build.log GenSec 行」为链条。）

---

## 2. 定位与常量（任务 1、2）

### 2.1 gBS 地址的独立确认（不只信 map）
入口 `_ModuleEntryPoint`（0x1050）里 x20 = `0x4e9b8`：

```
0x1084  ldr x8,[x1,#0x60]        ; x1 = SystemTable → [gST+0x60] = BootServices
0x10ac  str x8,[x20,#0xd8]       ; → 0x4ea90 = gBS
0x10b0  ldr x8,[x19,#0x58]       ; [gST+0x58] = RuntimeServices
0x10b4  str x8,[x20,#0xd0]       ; → 0x4ea88 = gRT
0x10a0  stp x21,x19,[x20,#0xe0]  ; → 0x4ea98 = gImageHandle, 0x4eaa0 = gST
```

⇒ **gBS 页面/偏移 = `adrp 0x4e000` + `#0xa90`**，与 map 行 `0004ea90 gBS` 一致（双证）。

**本 fork 的 EFI_BOOT_SERVICES 成员偏移**（由 EB 前标记的编译器取值反推，非猜）：

```
0x5a30  ldr x3,[x26,#0xa90]     ; x3 = gBS        （x26 由 0x5874 adrp x26,0x4e000 得来）
0x5a34  cbz x3, 0x5a44
0x5a38  ldp x4,x6,[x3,#0x40]    ; x4 = gBS->AllocatePool(+0x40)，x6 = gBS->FreePool(+0x48)
0x5a3c  ldr x5,[x3,#0xe8]       ; x5 = gBS->ExitBootServices(+0xE8)
```

与补丁里 `[K] gbs=%lx ap=%lx eb=%lx fp=%lx` 的取值次序逐一对应 ⇒ **AllocatePool=+0x40 / FreePool=+0x48 / EB=+0xE8**
（注意：与 EDK2 上游标准偏移不同，扫描必须按本表判定，否则漏判）。

### 2.2 函数边界（.map 相邻符号求交）

| 符号 | 区间 | 长度 |
|---|---|---|
| `SbLogPut` | 0x3e00–0x3e9c | 0x9c |
| `SerialPortWrite` | 0x401c–0x44d8 | 0x4bc |
| `FbConFlush` | 0x44d8–0x44fc | 0x24 |
| `SbDumpLog`（EB 前版） | 0x44fc–0x47f4 | 0x2f8 |
| **`SbDumpLogNoBs`** | **0x47f4–0x49c8** | 0x1d4 |
| **`BootLinux`** | **0x49c8–0x5d6c** | 0x13a4 |
| `SbBootProbe` | 0x5d6c–0x5e78 | 0x10c |
| `SwitchTo32bitModeBooting` | 0xa1d4–… | — |
| `ShutdownUefiBootServices` | 0x1630c–0x165d8 | 0x2cc |
| `InternalAllocatePool` | 0x14ec–0x152c | 0x40 |
| `AllocateZeroPool` | 0x152c–0x1558 | 0x2c |

### 2.3 EB 调用点与「区间 c」

* **BootLinux 内调用 EB 的 bl：`0x5a9c  bl 0x1630c`**（返回点 0x5aa0；全镜像唯一 `bl 0x1630c`）。
* EB 真实发生在 `ShutdownUefiBootServices` 内：
  `0x164e0 adrp x9,0x4e000 / 0x164e4 add x9,x9,#0xa90 / 0x164e8 ldr x1,[sp,#0x18]（MapKey）/
  0x164ec ldp x8,x0,[x9]（x8=gBS, x0=gImageHandle）/ 0x164f0 ldr x8,[x8,#0xe8] / 0x164f4 blr x8`
  = `gBS->ExitBootServices(gImageHandle, MapKey)`；外层 GetMemoryMap(`+0x38`) 重试循环按
  `EFI_BUFFER_TOO_SMALL=0x8000000000000005`（0x16388 构造 x24）判退，失败回滚 `FreePages`（0x165a4）。
* **区间 c（EB 返回 → 间接跳内核）**，三条互斥出口，取最长包络：
  * 主路径 → `0x5c9c blr x8`（`x0=0,x1=0,x2=dtb`，arm64 旧协议入口）：区间 **[0x5aa0, 0x5c9c)**
  * EFI-stub 入口 `0x5d44 blr x19`（`x0=dtb,x1=x2=x3=0`）：区间 [0x5aa0, 0x5d44)
  * AArch32 路径 `0x5ce0 bl 0xa1d4`：区间 [0x5aa0, 0x5ce4)
  * 0x5aa0–0x5d6c 共 179 条指令，过近似可达 178 条；唯一不可达 = `0x5ca0`（`blr` 之后，内核不返回）。

---

## 3. 判定与证据（任务 3）

### 3.1 区间 c：EB 之后没有任何 boot service 调用

对 `0x5aa0` 做过近似可达闭包（跟随全部 `b/b.cond/cbz/tbz/尾调用 b`；`bl` 进被调 + 继续；`blr/ret` 终止）：
**1931 条指令、36 个函数**。可达函数清单：
`BootLinux, CpuPause, AsciiVSPrint, AsciiSPrint, SetMem, CopyMem, SbLogPut, SerialPortWrite, FbConFlush,
SbDumpLogNoBs, SbBootProbe, SwitchTo32bitModeBooting, BootStatsSetTimeStamp, BasePrintLibFillBuffer,
BasePrintLibSPrintMarker, InternalMemSetMem, StrnLenS, AsciiStrnLenS, WriteBackInvalidateDataCacheRange,
CacheRangeOperation, WriteBackDataCacheRange, PreparePlatformHardware, ArmDataCacheLineLength, memcpy,
ArmCacheInfo, ArmCallSmc, ArmDataSynchronizationBarrier, ArmDisable{AsynchronousAbort,BranchPrediction,
DataCache,InstructionCache,Interrupts,Mmu,Tlb}, ArmEnableInterrupts, ArmGetInterruptState`。

* **该闭包内 `bl` 目标 31 个，无一个指向 `InternalAllocatePool(0x14ec)` / `AllocateZeroPool(0x152c)`。**
* **该闭包内可解析到「已知全局」的访存 56 处，其中触及 UEFI 服务表的只有 4 处：**

| 地址 | 指令 | 目标 | 性质 |
|---|---|---|---|
| **0x5b2c** | `ldr x3,[x26,#0xa90]` | **gBS** | 只读指针 |
| 0x5b34 | `ldr x4,[x3,#0x40]` | gBS->AllocatePool | **仅取值打印**；`0x5b30 cbz x3,0x5b3c` 守卫，`0x5b38 b 0x5b40`，无 `blr` |
| 0x5e3c→0x5e60 | `ldr x8,[x8,#0xa88]` / `ldr x8,[x8,#0x58]` / `blr x8` | **gRT** | runtime 表（SbBootProbe，0x5e2c `cbnz w10` 门控） |
| 0xac64→0xac7c，0xac98→0xacb0 | `ldr x8,[x4,#0x90]`/`[x4,#0x88]`→`blr x8` | **gRT** | runtime 变量服务（BootStatsSetTimeStamp，基址 = 0x4e9f8+0x90 / 0x4ea00+0x88 = 0x4ea88） |

* **区间 c 内的全部间接调用（9 处）与来源：**

| 地址 | 指令 | 目标来源 | 判定 |
|---|---|---|---|
| 0x49b0 | `blr x9` | `[m_SbLogBlkIo(0x39670)+0x20]` = `BlkIo->WriteBlocks` | 协议方法（见 §3.4 R1） |
| 0x5c9c | `blr x8` | `0x5c8c ldr x8,[sp,#0x38]` = 内核入口 | 内核入口 |
| 0x5d44 | `blr x19` | `0x5ca8 ldr x19,[sp,#0x38]` = 内核入口 | 内核入口 |
| 0x5e60 | `blr x8` | `[[0x4ea88]/*gRT*/+0x58]` | runtime 服务，非 BS |
| 0xa368 | `blr x19` | `[pQcomScmModeSwitchProtocol(0x35440)]` | 协议方法，非 BS |
| 0xac7c / 0xacb0 | `blr x8` | gRT 槽 0x48 / 0x88 | runtime 服务，非 BS |
| 0x125e8 / 0x127b8 | `br x11` / `br x8` | `adr` 基址 + 表偏移 | 打印库 switch 跳表，非调用 |
| 0x14b4c | `blr x20` | 实参传入的静态函数指针：`0x14b84 adrp/add → ArmCleanDataCacheEntryByMVA(0x23728)`、`0x14afc → ArmCleanInvalidateDataCacheEntryByMVA` | 本镜像内静态 cache-op 指针，非 BS |

* 其余 EB 后被调函数逐一核验无 BS：`SbLogPut`（0x3e00）只碰 0xE3F80000 RAM 日志环；
  `AsciiSPrint/AsciiVSPrint/BasePrintLibSPrintMarker` 用栈缓冲（无池调用）；
  `SerialPortWrite`/`FbConFlush` 只碰 FrameBufferSerialPortLib 的静态状态（`m_Initialized/m_FbSafe/m_FbStride/m_TextRows/m_TextCols/p_Position/m_Color.0/m_Color.1/font5x12`）；
  `PreparePlatformHardware`(0x165d8) 只调 `ArmDisable*` + 尾调 `ArmInvalidateTlb`；
  `WriteBackDataCacheRange` 只调 `ArmDataCacheLineLength`+`CacheRangeOperation`。
* 出口性质（过近似可见的全部离开方式）：返回（`0x4f28` 序言/`0x4f70` 块 → `EFI_UNSUPPORTED(0x8000…0015)`）、
  死循环（`0x5d48` canary → `0x5d64 bl CpuPause`）、或跳内核。**没有一条将控制流带回 EB 之前的 gBS 使用块。**

### 3.2 `SbDumpLogNoBs`（0x47f4–0x49c8）

* **gBS 载入 0 处、`bl 0x14ec/0x152c` 0 处**；全部 `bl` 只有：`0x48d4 bl 0x13c0 (AsciiSPrint)`、
  `0x4900 bl 0x17dc (CopyMem)`、`0x4918 bl 0x17dc (CopyMem)`。
* 静态缓冲（map + 反汇编互证）：

| 缓冲 | 地址 | 使用点 |
|---|---|---|
| `SbDumpLogNoBs.m_SbNoBsRing`（8 KiB） | 0x2f470 | 0x487c / 0x4910 |
| `SbDumpLogNoBs.m_SbNoBsRec` | 0x31470 | 0x48e8 / 0x4980 |
| `SbWriteLogWindowNoBs.m_SbNoBsBuf`（16 KiB） | 0x39680 | 0x4954 / 0x4978 |
| `m_SbLogBlkIo` | 0x39670 | 写：0x4798（**SbDumpLog 内，EB 前**）；读：0x4924 |
| `m_SbLogMediaId` | 0x39678 | 写：0x47a4（EB 前）；读：0x49a0 |

  ⇒ BlkIo 句柄是 **EB 前** `SbDumpLog` 捕获、EB 后直接复用（不再 Locate/HandleProtocol）——与补丁语义一致。
* 唯一的写盘调用（守卫链完整）：
  `0x491c cbz x22,0x49b4` → `0x4924 ldr x20,[m_SbLogBlkIo]` → `0x4928 cbz x20,0x49b4` →
  `0x4930 ldr w8,[…];0x4934 cbz w8,0x49b4` → `0x4944 cmp x10,#0x4000 / 0x4948 b.ls 0x49b4` →
  `0x498c sub x21,x9,x8`（**Base = LastBlock+1 − SB_LOG_WINDOW/BlockSize，LBA 而非字节偏移**：
  `0x4938 ldr x9,[+0x18]; 0x493c add x9,x9,#1`；`0x4970 udiv w8,w10(=0x4000),w8`）→
  `0x4998 ldr x9,[x20,#0x20] / 0x49b0 blr x9` = `WriteBlocks(BlkIo, MediaId, LBA, 0x4000, 静态 Buf)`。
* 缓冲全为静态：无 `ZeroMem` 前的分配、无 `FreePool`；`0x4950-0x496c` 是对静态 Buf 的 16 KiB 清零循环。

### 3.3 内联与全镜像池扫描（任务 2 的机器扫描）

* `SbWriteLogWindowNoBs` **无独立函数符号**（map 里只有它的 static），其缓冲只被 `SbDumpLogNoBs` 引用 ⇒ 已内联进
  `SbDumpLogNoBs`（0x4920–0x49b0 段）。
* 全 `.text`（0x1000–0x241bc，35 943 条指令）机械扫描（`adrp`+绝对地址求解，带寄存器 kill）：

| 指标 | 数量 |
|---|---|
| gBS（0x4ea90）指针载入 | **296** 处，分布在 **82** 个函数 |
| `gBS->AllocatePool`（+0x40）派发 | 40 处 |
| `gBS->FreePool`（+0x48）派发 | 99 处 |
| `gBS->ExitBootServices`（+0xE8）派发 | 1 处（0x164f4） |
| `bl InternalAllocatePool(0x14ec)` | 2 处：0x153c（在 `AllocateZeroPool` 内）、0x1e0ec（在 `AsciiPrint` 内） |
| `bl AllocateZeroPool(0x152c)` | 26 处（0x5540 BootLinux〔EB **前**〕、0x8368/0x8378/0x838c/0x850c、0x99c4、0xd1a4、0x0ed6c/0xfa94/0xfaec/0xfca8、0x10904/0x109b0、0x10f0c、0x11334/0x116b8/0x11820/0x11830/0x11884、0x155e4、0x1a024、0x1a758、0x1ab48、0x1ad20、0x1b41c、0x1eb30） |

* **`SbDumpLog`（EB 前版，作为对照）里仍有 3×AllocatePool（0x4534/0x4634/0x46e0）+ 3×FreePool（0x47b4/0x47c4/0x47d4）**
  ——正是 p37 崩溃形态的形状；它在 EB 前被调（0x5a78、0x10f4 等），合法。
* BootLinux 自身的 BS 使用点全部在 EB 之前：AllocatePool 0x4b60；FreePool 0x4e64/0x5888/0x59d0；
  gBS 载入 0x4b40/0x4c4c/0x4e5c/0x5880/0x5898/0x59c8/0x5a30/**0x5b2c**（最后一个即 EB 后唯一那次）。
* **没有任何指令向 gBS（0x4ea90）写值**（不存在「把 gBS 置 NULL」的写法；「真·无 BS」靠不再引用实现）。

### 3.4 残留风险（点名，供上机判读时参考）

* **R1｜0x49b0 `blr x9` = `m_SbLogBlkIo->WriteBlocks`。** 这是固件 BlockIo 实现的方法指针，实现不在 LinuxLoader 内，
  静态无法证明其内部不触碰 gBS（若触碰则仍是 `blr` 到失效指针）。这是本方案的**唯一外部假设**；
  上机若出现 `[K] post-dump-ok`（0x5b70–0x5bfc 那 18 组 `mov w0,#imm / bl 0x3e00`，逐字符 `SbLogPut` 拼出的 `"[K] post-dump-ok\n\r"`），即经验性证伪该假设。
* **R2｜gRT 在 EB 后被调用**：0xac7c/0xacb0（`BootStatsSetTimeStamp`，被 0x5c60 在「EB 成功」分支上调用）
  与 0x5e60（`SbBootProbe` 的 mark 路径，0x5cbc 在 EB 后可达）。runtime 服务在 EB 后物理寻址下合法，
  但把变量/日志服务暴露在 EB 之后；若平台 RT 已在 EB 时收尾，最多返回错误，不解释为 p37 型崩溃。
* **R3｜AArch32 出口 0x5ce0 → 0xa1d4 → 0xa368 `blr x19`（`pQcomScmModeSwitchProtocol`）**：同为协议方法（R1 同类），
  仅 arm32 内核路径可达；本工程 arm64 Image 不走。
* **R4｜EB 失败即挂**：`0x5c3c tbnz x19,#0x3f,0x5d48`（x19 = EB 返回码）→ canary 检查 → `0x5d64 bl CpuPause`
  死循环。设计上「EB 失败就不跳内核」，与本次判据无冲突，但排障时别把它当成内核崩。
* **R5｜顺序安全确认**：`SerialPortWrite(0x5c20)` 在 `PreparePlatformHardware(0x5c40)`（关 D-cache/MMU/中断）**之前**，
  `WriteBackDataCacheRange(0x5acc/0x5d30)` 在关 MMU 前后各一次，未发现「关 MMU 后再取全局」的窗口。

---

## 4. 载荷链核对（任务 4）

boot image v0/v2 头解析（`scripts/uefi-bootimg-dump-v0.py`）：`magic=ANDROID!`, `header_version=2`,
`kernel_size=2459508`, `page_size=4096`, `kernel_addr=0x8000`, `file_size=67219456`,
`cmdline=… elden_root=LABEL=linux17 androidboot.slot_suffix=_b …`。载荷位于 **偏移 0x1000**（首 4 KiB 头之后）。

| 环节 | 大小 | sha256 | 判定 |
|---|---|---|---|
| img 内 `kernel` 字段（0x1000，长 2459508） | 2 459 508 | `a5c8994e3d5ff0ff91b69083e2c9bdd41d0e84607340a4e0adf6b8ac673e7cde` | **= `payload-v2aligned.bin.gz`**（且 `bytes equal=True`）✅ |
| 解 gz → `payload-v2aligned.bin` | 4 194 496 | `c6b1e9b6b5af3fba4a4b19f7284e6531f402ed82dc25f6c42c5dfee1181d0b44` | = 归档同名文件 ✅ |
| 其中 `[192:192+4194304]` | 4 194 304 | `15678b24…6d06` | = `SM8750_EFI.fd`（逐字节）✅ |
| 其中 `[0:192]` | 192 | `aae98b52c8cb78f89c178a24a815ff39c7e20958e034a581505a19ed81163ce0` | ≈ `BootShim.bin`(`51a57a9e…`)，**仅偏移 0x10 一字节不同**：内嵌 u32=0x004000c0 vs 归档 0x00400000（差 0xc0=192=shim 长度，与 `bootshim-copy-length-from-build-constants` 补丁一致） |

即：`uefi-preamble38-r1.img` → gz（逐字节）→ `BootShim(1B 改写) + SM8750_EFI.fd`，而该 FD 与构建树 FD 同 sha，
构建树 FD 由 `build.log` 打包 `LinuxLoader.efi`（与本次反汇编件同 sha）。链闭合。

---

## 5. 执行过的命令（可复现）

```bash
cd /home/xuqianhui/y700-elden && git rev-parse --show-toplevel && git status --porcelain=v1
sha256sum reports/artifacts/uefi-20261107R33-p38/{SM8750_EFI.fd,BootShim.bin,payload-v2aligned.bin*,obj/LinuxLoader.efi} \
          out/r21-sbstop-p38/uefi-preamble38-r1.img \
          build/uefi-woa-prep/repos/7-mu-lenovo/Build/PakalaPkg/RELEASE_CLANGPDB/{AARCH64/LinuxLoader.efi,FV/SM8750_EFI.fd}
/usr/bin/llvm-objdump -h reports/artifacts/uefi-20261107R33-p38/obj/LinuxLoader.efi
/usr/bin/llvm-objdump -d --no-symbolic-operands --no-show-raw-insn obj/LinuxLoader.efi > /tmp/p38_dis_num.txt
/usr/bin/llvm-objdump -d --start-address=0x5b20 --stop-address=0x5b40 obj/LinuxLoader.efi
aarch64-linux-gnu-objdump -d --no-show-raw-insn obj/LinuxLoader.efi          # 交叉核对（pei-aarch64-little）
python3 scripts/uefi-bootimg-dump-v0.py out/r21-sbstop-p38/uefi-preamble38-r1.img
grep -n "LinuxLoader" reports/artifacts/uefi-20261107R33-p38/build.log        # GenFw/GenSec 行
# 分析脚本（临时件全在 /tmp，未进仓库）：
#   /tmp/p38_an.py /tmp/p38_an2.py  —— .map 符号表 + 相邻符号求函数边界 + 全局访存求解
#   /tmp/p38_flow.py /tmp/p38_post_eb2.py —— 过近似可达集（bl/b 尾调用入队、blr/ret 终止、tbz 取末位立即数）
#   /tmp/p38_scan.py /tmp/p38_scan2.py —— 全 .text 的 gBS 载入 / gBS 槽派发（含寄存器 kill）/ 池调用点
#   载荷核对：内联 python3（gzip + hashlib，img[0x1000:0x1000+kernel_size] 与 gz 比对）
```

**覆盖度与工具局限（如实记录）**
* `.text` 反汇编 35 943 条、2 处 4–8 字节空洞（0x1008–0x101c、0x23c68，编译器对齐填充），无漏译码区域。
* 可达性用「跟随所有分支」的过近似 ⇒ 结论方向安全（若过近似都干净，则真路径必干净）。
* 槽位语义只标注「实参形状无歧义」的（CreateEvent/TPL=0x10、AllocatePool(4,size,&buf)、EB(ImageHandle,MapKey)），
  其余按数值槽位给出，不猜名字。
* FD 内 FFS 压缩 ⇒ `.efi` 到 img 的包含关系以 sha 三方一致 + build.log GenSec 行作证，非直接字节匹配。

## 6. 工作区一致性

开始时 `git status --porcelain=v1`：
```
?? patches/uefi/20261107R33-true-nobs/
?? patches/uefi/p38-recipe.txt
?? reports/artifacts/uefi-20261107R33-p38/
```
结束时（本报告写完）：同前三条 **+ `?? reports/uefi-p38-static-verify-20261107.md`**，无其他改动。
