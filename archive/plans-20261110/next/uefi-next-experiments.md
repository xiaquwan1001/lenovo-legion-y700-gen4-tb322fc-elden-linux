# UEFI 线下一步实验设计（DxeCore 从未启动 → 内层 FV 解压失败）

> 性质：**只读分析**（未改仓库文件、未接触设备、未 commit）。
> 口径来源：`PITFALLS/sessions/2026-11-04-UEFI-DxeCore从未启动.md`、`reports/uefi-payload-execution-20261104.md`、
> `TASKS/README.md` §5、`patches/uefi/20261104-dxe/`。
> 本文件只做**增量**：不推翻「DxeCore 从未被启动」，只排实验顺序。

- 编写日期：2026-11-04（主机侧只读）
- 树：`build/uefi-woa-prep/repos/7-mu-lenovo`（HEAD `6b6ac42a`，见各 `manifest.txt:repo_head`）
- 外部对照：`external/ext-repos/sunuefi`（SunUEFI / piano / SM8750）

---

## §1 已否证假设表（防重复实验）

### §1.1 表（一行一条，附证据指针）

| # | 曾经的假设 | 现状 | 证据（file:line / 命令） |
|---|---|---|---|
| F1 | 屏上出现 `[P11]` = 已把控制交给 DXE Core | **否证**。`[P11]` 打在 `LoadDxeCoreFromFv()` **返回之后**；本轮实测返回 `0x8000000000000E0E`… 精确值 `0x800000000000000E` = `EFI_NOT_FOUND`，且 `[D00]` 从未出现 | `PITFALLS/sessions/2026-11-04-UEFI-DxeCore从未启动.md:7,25-35`；插桩点 `patches/uefi/20261104-dxe/0004-prepi-print-loaddxecore-status.patch`（`PrePi.c:255` `SbMark("[P11]")` 在 `LoadDxeCoreFromFv` 之后） |
| F2 | 「FV 发现链/HOB 里没有 FV」导致找不到 DxeCore | **否证**。HOB 里确实有 1 个 FV（`0xFF300000`/`0x400000`），`FfsAnyFvFindFirstFile` 找到 FV_IMAGE 文件，失败在更内层 GUIDED 段解码 | `PITFALLS/…DxeCore从未启动.md:8`（`[G04n]`/`[G11]` 打印） |
| F3 | 压缩数据本身坏 / 压缩参数错 / 字典 16 MiB 分配失败 / scratch 64 KiB 不足 | **否证**。主机用**同一份** `Sdk/C/LzmaDec.c` 解出 `res=0`、`0xC45008` 字节；Python `lzma` 同成功。代码层面：`LzmaDecode` 只用 `SzAlloc` 拿 probs（≤16 KB），`SCRATCH_BUFFER_REQUEST_SIZE = SIZE_64KB` 且 `SzAlloc` 只在 `BufferSize >= Size` 时返回 | `PITFALLS/…DxeCore从未启动.md:9`；`MU_BASECORE/MdeModulePkg/Library/LzmaCustomDecompressLib/LzmaDecompress.c:14`（64 KiB）、`:28-50`（SzAlloc 语义）、`:203`（`LzmaDecode` 调用点，`Destination` 直通、`p.dic=dest` 无字典分配） |
| F4 | shim 的 4 MiB FD 拷贝没跑完 / 没 `br` 进 UEFI | **否证**。进度色带 4/4 + M2 绿带 ⇒ 拷贝完成并跳转；UEFI 版本行打印 = PrePi 真的在执行 | `reports/uefi-payload-execution-20261104.md:17`（§0#5）、`:92-93`（§7 表格首行）；色带补丁 `patches/uefi/20261104-prog/`、`20261104-fbband/` |
| F5 | `usb_read failed` = 交棒；存在 1–2 s 看门狗复位 | **否证**。自旋探针同样触发 `usb_read failed` 但标记全 0；自旋载荷躺数分钟无人复位 | `reports/uefi-payload-execution-20261104.md:27`（§1 表）；`TASKS/README.md:137`（11-03 下午块） |
| F6 | DDR stage 标记页可「事后读回」判读 | **否证**。自家载荷（PrePi 侧）写了 ~1.9 GB `0xFF` 把 shim 早写的 stage 页抹掉；三窗读回恒 100% `0xFF`。两次对照（纯重启 / 同路径启动真内核）证明不是 ABL/启动路径 | `reports/uefi-payload-execution-20261104.md:20`（§0#8）、`:51-56`（§4）；取证目录 `reports/artifacts/uefi-readback-20261103-184958/` |
| F7 | `0xFF300000` 不是真 DRAM / 写不进去 | **否证**。Linux 侧写 `0x42` 读回 `0x42`，`0xFF300000`/`0xFF600000`/`0xFF7FF000` 三处全过 | `reports/uefi-payload-execution-20261104.md:19`（§0#7） |
| F8 | `splash_region` 的 43 MiB 整块可写 | **否证**。整屏填红到约 137 行后整机无响应；安全可写仅前 ~448 KiB（`0`–`0x70000`） | `reports/uefi-payload-execution-20261104.md:16`（§0#4）、`:35-36`（§2.2） |
| F9 | 低相关四条：只改 `text_offset` 即可 / EDL `peek` 可回读 / 必须升 Mu v4.1 / 必须写 tiny DXE | **均否证或「不作为」**：载荷头须三件齐（`code0` branch + `image_size` + `flags=0xa` + v2 base 0）；loader 无 `peek`；v4.1 的内存图缺口本机已覆盖；同 SoC 已证现有链可用 | `TASKS/README.md:137,158`；`reports/uefi-next-step-decision-20261103.md:15`；`PlatformMemoryMapLib.c:22,31` |

### §1.2 仍然**开放**的两条（本轮要设计实验而不是当结论用）

| K | 假设 | 状态 | 本文件处置 |
|---|---|---|---|
| K1 | `PlatformMemoryMapLib.c` 把 `0xFF300000` 声明为 `BsData`（= 可分配/可写回 cache）破坏内存图与 FD | **未证**，且存在**反向论据**（见 §2.2 的机制核对：PrePi 的 `AllocatePages` 从 `EfiFreeMemoryTop` 向下走，而 `EfiFreeMemoryTop` = DXE Heap 顶端 `0xD65C0000`，不在 FD 区间内）⇒ 该假设只能解释「DXE 起来之后」的破坏，**不能解释 PrePi 期间的损坏** | 降级为「顺手修 + 消变量」，不作首选（实验 E6） |
| K2 | 损坏发生在 shim 拷贝**之前/之后**的源侧（gz 载荷/拷贝）还是目标侧（PrePi 内存图/分配） | **未证**：第 11 发两张块表屏纯黑，判据未取到 | 升级为**首选**（实验 E1/E2），因为它是唯一能二分「源 vs 目标」的实验 |


## §2 Mu 树精确改点与单变量实验（PrePi / FwVol / LZMA）

### §2.1 (a) 「GetInfo 成功但 Decode 失败」只能推出「源数据被改坏」

- `LzmaUefiDecompressGetInfo` **不解压**：只 `GetDecodedSizeOfBuf((UINT8*)Source)` 读 `EncodedData[5..12]` 这 8 字节 + `ASSERT(SourceSize>=13)`，返回 `ScratchSize=SIZE_64KB`（`MU_BASECORE/MdeModulePkg/Library/LzmaCustomDecompressLib/LzmaDecompress.c:146-155`，`GetDecodedSizeOfBuf` 在 `:88-105`）。
- `LzmaUefiDecompress` 唯一失败分支：`LzmaDecode(...) != SZ_OK ⇒ RETURN_INVALID_PARAMETER`（`:203-219`）。调用形态 `Dest / &DecodedBufSize(=0xC45008) / Source+13 / &EncodedDataSize(=SourceSize-13)`（`:200-213`）。
- 因此：`GetInfo` 通过 ⇒ **只有前 13 字节**可信；`Decode` 失败 ⇒ range decoder 在中途读到与编码不一致的字节（`SZ_ERROR_DATA`）。被读入的输入长度 = `SourceSize-13`，输出 `0xC45008`（≈12.3 MiB）⇒ **压缩流本身就有数 MiB**，必然跨过 FD `0x100000` 边界进坏区 16+。
- 两个事实同时成立而只坏一处，唯一自洽解 = **源字节被改**，而不是：解压器 bug（主机同一份 `Sdk/C/LzmaDec.c` 解 `res=0`）、参数错（GetInfo/Decode 用的是同一 `Source`/`SourceSize`）、scratch 不足（`SzAlloc` 只需 ≤16 KB probs，64 KiB 够，且不够会返回 `SZE_NOMEM` 而仍映射为同一错误码——但 FD 尺寸与原厂产物一致，可先排除）。
- **关键后果**：卡点从「FV 层」搬回「内存层」。FV 解析、GUIDED 分发、GetInfo、scratch 分配、`Destination` 分配全部正常，唯一异常量就是 **`0xFF300000` 起 4 MiB 的字节内容**；而且它是一个**确定性、可复现的字节级差异**（同一镜像每次坏在同一位置）⇒ 可以用 FNV 块表二分，不需要时序类探针。

### §2.2 (b) PrePi 用的是 `DXE Heap`(0xB90C0000)，不是 `0xFF300000`

- `PrePi.c:104` `LocateMemoryMapAreaByName("DXE Heap",&DxeHeap)`；`:116-120` `UefiMemoryBase=DxeHeap.Address`、`StacksBase=UefiMemoryBase+Size-StacksSize`；`:151-156` `HobConstructor(base,size,...,StacksBase)`；`:163` `BuildStackHob`。地址来源 `Platforms/PakalaPkg/Device/lenovo-y700g4/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c:34` `DXE Heap 0xB90C0000 / 0x1D500000` ⇒ 区间 `[0xB90C0000, 0xD65C0000)`，栈顶 `0xD6580000`。
- `ModuleEntryPoint.S:74-94` 主核栈同样用 `PcdPrePiStackBase/Size`；`:32` 先 `ArmDisableCachesAndMmu`；`:96-99` `ArmDisableDataCache/ArmEnableDataCache`（MMU 仍关）。`ArmMmuLibCore.c:720-731` 建表期只在 MMU 未开时 invalidate，`:757-764` 到 `MemoryPeim` 末尾才 `ArmEnableDataCache()`+`ArmEnableMmu()`。
- ⇒ PrePi 的 HOB/栈/`AllocatePages` 全从 `EfiFreeMemoryTop=0xD6580000` 向下，**从不落到 0xFF300000**；`PlatformMemoryMapLib.c:36` 的 `UEFI FD BsData` 在 PrePi 阶段**不构成破坏路径**，只影响 DXE 起来后的 allocator（→ K1 降级为顺手修）。
- 但 PrePi 里有**唯一**一处直接碰 FD 的 cache 动作：`PrePi.c:282-288` `InvalidateDataCacheRange(0xFF300000, 0x400000)` —— **invalidate 不 clean**。MMU off 时它理论上 no-op，所以这是零成本可排除项（实验 E2），却是「A/B 好而 C 坏」的唯一候选机理。

### §2.3 (c) 「shim 运行时 MMU/DCache 开不开」= 4 MiB 拷贝是否真落 DRAM 的未知量

- 树内 `BootShim.S` 共 61 行、纯汇编：`_CopyLoop` 是 `ldp/stp` 16B 后索引（`:43-47`），随后 `ldr x5,_StackBase; br x5`（`:48-51`）——**全程无任何 cache/MMU 指令**。`BootShim/Makefile` 只有 `--target=aarch64-linux-gnu`，无 C 源。
- 补丁链自己印证这个未知量没被独立测量：`patches/uefi/0001-bootshim-add-dc-civac-ic-iallu-before-entry.patch` 加了 4 MiB `dc civac` 扫描，`patches/uefi/20261104-nocivac/0001-bootshim-skip-fd-civac-sweep.patch` 又删掉，注释理由写作「死点只可能在这段 4 MiB cache 维护里」⇒ 判据是「加/删后现象变化」，不是「cache 开着但我 clean 了」。
- 机理两分：ABL 若以 MMU.On+DCache.On 交棒，`stp` 只写脏行、DRAM 未必更新；随后 `PrePi.c:268` `ArmDisableDataCache()`（**不 clean**）+ `:285` invalidate 会把这批脏行丢掉。ABL 若以 MMU.Off 交棒，架构上 C 位被忽略 ⇒ 写入直达 DRAM，拷贝可信。
- **一次上机判定（E1）**：同屏三张 FNV-32 块表，每表 16 值 = 8 位 hex × 8 个/行 × 2 行，三表共 6 行 + 3 个标签 ≈ 9 行，`--scale 3`（≈75×50）绰绰有余。
  - 块选法（关键）：**步长 0x20000**，块号 i 覆盖 FD `i*0x20000`（= 64 KiB 块 `2i`）⇒ i=0..7 落在已验证正确的 0–1 MiB、i=8..15 落在坏区，**跨过 1 MiB 边界才有鉴别力**（若用严格连续 64 KiB 块 0..15，三表都会全对，白烧一发）。
  - 表 A = shim 在 `_CopyLoop` 之后、`br` 之前对 **`_Payload`** 算同一 16 块（源区）；表 B = shim 紧接着对 **`0xFF300000`** 算（目标区，写后立刻读）；表 C = PrePi 在 `DecompressFirstFv()` 之前对 `0xFF300000` 算（复用 `patches/uefi/20261104-dxe/0013-prepi-block-fnv-table.patch` 的 `SbBlocks()`，改成 16 块步长 0x20000 即可）。
- 三种结果的结论：
  1. **A 坏** ⇒ 源侧（ABL 解 gz / 载荷落地长度不足；「前 8 好、后 8 坏」= 只落地了 ~1 MiB，直接指向 `image_size`/载荷布局），与 shim、PrePi、UEFI 全无关。
  2. **A 好、B 坏** ⇒ shim 拷贝/缓存：上式 MMU.On 假设成立 ⇒ 修法是把 `dc civac` 从「跳过后再补」改成**只 clean 不 invalidate**（`dc cvac`，`BootShim.S:48` 前插入）。
  3. **A/B 都好、C 坏** ⇒ 死点 100% 在 PrePi 内部：优先 `PrePi.c:268` 的 `ArmDisableDataCache` + `:285` 的 invalidate 组合（改成先 `CleanInvalidateDataCacheRange`，或用 `dc cvac` 代替 invalidate）；若改成 clean 后仍坏，再查 `MemoryPeim` 之后至 `DecompressFirstFv` 之间谁写了 FD 区。

## §2.4 ★独立复核（编排者 2026-11-04 09:xx 静态反汇编）：**真正的根因已定位，不是 cache、不是内存图**

> 本节由编排者独立复核加入，**优先级高于 §1.2 的 K1/K2**。证据 = 已入库产物的 `BootShim.bin` 反汇编 + `payload-v2aligned.bin` 头字段，全部主机侧、零上机。

**一句话**：shim 的拷贝长度取自 Linux `Image` 头 offset 16（`image_size`），而 repack 脚本把这个字段写成了**载荷真实长度 `0x400308`**；shim 的分块拷贝循环用**等值比较**决定「还剩几块」，`0x308` 的余数让第一次比较就落到「拷贝完成」分支 ⇒ **只拷了 1 MiB 就 `br` 进 `0xFF300000`**。

| 事实 | 证据 |
|---|---|
| 载荷头 `image_size = 0x400308`（≡ **8** mod 16，≡ **776** mod 1 MiB），`text_offset=0`，`flags=0xa` | `reports/artifacts/uefi-dxe10-20261104/payload-v2aligned.bin` offset 8/16/24；`uefi-prepi-20261104`、`uefi-prog-20261104` 同值（`python3 -c` 读头，本轮已跑） |
| shim 拷贝长度=该字段：`ldr x6, 0x10`（从载荷头 offset 16 读） | `reports/artifacts/uefi-dxe10-20261104/BootShim.bin` 反汇编 `0x98`；`uefi-prepi-20261104/BootShim.bin` 反汇编 `0x98` |
| 循环结构 = 「拷 1 MiB → `subs x6,x6,#0x100000` → `cmp x6,#0x300000` / `#0x200000` / `#0x100000` **等值比较** → 相等则画色带并 `b` 回循环头 `0xa4`；不等则走 `0x1b8` 的**收尾路径**（画 M0/M4/M5 三条色带后 `br x5`）」 | `BootShim.bin` 反汇编 `0xa4–0x2a8`；关键指令 `0xb8: subs x6,x6,x24`、`0xbc/0x110/0x164: cmp x6,#0x300/#0x200/#0x100, lsl 12`、`0x1b8: 收尾`、`0x2a4: ldr x5,0x300; br x5` |
| 首次迭代后 `x6 = 0x400308 − 0x100000 = 0x300308 ≠ 0x300000` ⇒ 三个等值比较全不相等 ⇒ **直接进收尾并 `br x5`** | 同上，逐指令推演 |
| ⇒ 目标区只有前 **1 MiB** 是本次写入，其余 3 MiB 保留上一轮的陈旧内容 | 与「块 0–15 正确、块 16–63 全错」**逐位吻合**；也解释了「坏内容 ≠ ramdisk / ≠ 0xFF / ≠ 0x00」 |
| 色带「进度 4/4」是**误读**：M0/M4/M5 三条色带都在收尾路径里连画，与「拷完 4 MiB」无关 | 反汇编 `0x1b8–0x2a0`（三条色带 + `ic iallu` 全在收尾路径） |
| 同一余数还解释历史上的「civac 段死点」：`_CivacLoop` 用同一 `_StackSize` 做 `subs #64; b.ne`，`0x400308` 不是 64 的倍数 ⇒ **永不归零、扫出 4 MiB 窗口外** ⇒ 挂死；旧 `_CopyLoop`（`subs #16`）同理会扫出界 | `patches/uefi/20261103-posctrl/0002-bootshim-text-offset-zero-plus-marks.patch`（`ldr x6,_StackSize` + `subs x6,x6,#64; b.ne`）；`patches/uefi/0001-…dc-civac…patch`（`subs #16`） |

**结论**：`LzmaDecode` 返回 `EFI_INVALID_PARAMETER` 不是解压器/内存图问题，而是**压缩流从 `0x100000` 起根本没被搬进目标区**。§1.2 的 K1/K2 全部降为次要（K2 的「源 vs 目标」二分也已被本节的代码级证据绕过：源没问题、目标只写了 1 MiB）。

**最小修法（两种，建议 A+B 同时）**：
- **A（shim 侧，根治）**：拷贝长度不要读头部字段，改用构建期字面量 `_UefiSize: .quad UEFI_SIZE`（放在代码段内、不占 Linux 头字段），并把分块循环的等值比较改成带余量形式（`cmp x6, x24, lsl 12` 之类的有序比较，或先 `add x6,x6,#0xFFFFF; and x6,x6,#~0xFFFFF` 向上取整到 1 MiB）。**任何情况下循环必须有「已写字节 ≥ UEFI_SIZE 即停」的硬上界**，防再出现扫出界挂死。
- **B（repack 侧，双保险）**：`scripts/uefi-repack-v2aligned.py` 里 `image_size` 写真实长度是对的（ABL 要这个），但应在写完头之后**断言 `len(payload) % 16 == 0` 并对 `BootShim.bin` 做 16 字节对齐填充**（当前 `_Payload` 落在 `0x2e8`，`ldp` 是 16 字节非对齐访问，见 §4）。

---

## §3 SunUEFI 对照：屏上可见性 + 自研 UFS 只读栈

口径：`external/ext-repos/sunuefi` @ `afe922b`（与 `~/下载/Project-SunUEFI-main.zip` 同日）。**注意**：该克隆的 worktree 在 2026-11-04 上午被发现 index 丢失（`git status` 报 1428 项 `D`），本轮用 `git show HEAD:<path>` 逐文件读取，未依赖 worktree；修复中（`fetch --refetch` 拉全 blob 后 `reset --hard`）。

### §3.1 (a) 屏上判读法：能借什么、不能借什么

**结论**：他们的「GOP 涂色检查点」与我们「屏上串口 `[Pxx]`」是同类手段，**我们现有的已经更好用**（有文本、能打十六进制值，色带只能编码 4–5 个阶段）。真正值得借的是**三条工程纪律**，不是绘制方法：

| 可借项 | 他们的做法（file:line） | 对我们的用处 |
|---|---|---|
| ★ 检查点**周期性重发** | `docs/devel/boot/uefi-display.md:53`：检查点状态存进产品内存，由现有 GUI pump 周期重发，**避免被 UFS 日志覆盖** | 正好治我们的 `PITFALLS #496`（一屏 75×50，滚掉即证据全丢）。可在 `Platforms/AndromedaPkg` 找一个已有的周期钩子（或 timer 事件）把关键 `[Pxx]`/块表来回重打 |
| ★ 诊断构建与发布构建**硬分离** | `:24-26`（`SUNUEFI_DISPLAY_DIAGNOSTIC=1 ./build.sh uefi`，构建清单记录 `display_diagnostic` 与编译标志；默认构建零色块零等待）；`:61-71`（诊断会延长初始化，只用于定位） | 我们 `scripts/uefi-build-variant.sh` 已有 `manifest.txt`，可加一列 `instrument=dxe|prepi|none`，并要求「上机收口发的官方件 = instrument=none」 |
| ★ 给**别人的二进制**插桩的通用手法 | `:61-71`：`=2` 时在 `LoadImage` 拿到的驱动副本的**零填充可执行区**放 trampoline，按原 BL 目标 + 重定位接管，包装函数原样转发 8 个整数参数 | 我们后续若要把插桩打进**原厂 `ClockDxe.efi` / 厂商 `UFSDxe.efi`**（DXE 阶段），这是唯一不改原件、不改运行中代码的路径 |
| 反面清单（别重走） | `:47-56`：把显示实例 `0x3e4b0` 的 `+0xd0` 申请数 4→0（只差 7 字节，sha `98d76405…`）**不足以修白屏**，仍只看到 `BEFORE CLOCK`；`:83-97` 最终修法 = 派生 ClockDxe 改两个 RVA（`0xc784` `BL`→`MOV w0,#0` 延后 CESTA/media 初始化、`0x3ead0` DCD 开关 1→0，共 5 字节，sha `abb63e6c…`） | 若我们以后要绕开原厂时钟初始化，先照他们这条**已验证的 5 字节配方**走，别自己猜寄存器；同时记住他们明确写了「软件菜单截图正确 ≠ 物理显示链路工作」 |

### §3.2 (b) 自研 UFS 只读栈：最小可搬集合与许可

**结论**：只搬 6 个文件即可拿到「SM8750 上已知能跑通的 UEFI 读盘能力」，**全部 `BSD-2-Clause-Patent`**（逐文件首行已核），不含 GPL 件：

| 文件 | 行数 | SPDX | 作用 |
|---|---|---|---|
| `uefi/core/PianoUfsProbe.c` | 110 | BSD-2-Clause-Patent | 控制器/时钟探测 + **时钟/GDSC 租约账本**（`PianoUfsStopClocks` / `PianoUfsRetainClocks`，DEBUG 串 `SUNUEFI_UFS_RESET_*`） |
| `uefi/core/PianoUfsReadOnlyDma.c` | 1138 | BSD-2-Clause-Patent | 主体：UIC/UTRD、DMA bounce、**owned SMMU bypass bank**、`ExitBootServices` 通知、GPT |
| `uefi/core/PianoUfsDmaLayout.c` + `.h` | 133 / 26 | BSD-2-Clause-Patent | UTRD（LE）与 UPIU（BE）线格式构造器 |
| `uefi/core/PianoReadOnlyBlock.c` + `.h` | 45 / 15 | BSD-2-Clause-Patent | 标准 `BlockIO` + **无条件写屏障**（无 WRITE CDB） |
| `uefi/core/PianoUfsBlockIo.c` + `.h` | 114 / 22 | BSD-2-Clause-Patent | 正常读写 + 调用方限定写窗口 |
| `uefi/core/PianoUfsProductVolume.c` + `.h` | 177 / 62 | BSD-2-Clause-Patent | 产品化封装（卷/分区枚举） |

**不必搬**：`PianoUfsWriteTest.c`(238)、`PianoUfsBoundedBlock.c`(133)、`PianoUfsBoundedFileSystemTest.c`(106) —— 都是受控写入实验，且 `PianoUfsReadOnlyDma.c` 通过 `PIANO_UFS_WRITE_TEST_BASELINE_HEADER` 宏把这些实验**编译期剔除**（`git show HEAD:uefi/core/PianoUfsReadOnlyDma.c` 的 `#include PIANO_UFS_WRITE_TEST_BASELINE_HEADER` 一行）。

**依赖面（决定工作量）**：`PianoUfsReadOnlyDma.c` 还 `#include` 了 `PianoOwnedSmmu.h`、`PianoGpt.h`、`PianoStorageIo.h`、`PianoExt4.h`、`PianoUfsBoundedLayout.h` ⇒ 真正搬要连带这些（SMMU bypass、GPT、Ext4/SFS 读取）；且运行期依赖厂商 DXE 基础层（`EFIClock` 协议、`FdtLib`、`HWIODxeDriver`/`HALIOMMU`/`DALSys` 这类原厂驱动，见 `uefi/platforms/pianoPkg/native-modules.json` 的 10 个基础 DXE）。**⇒ 定位：它是「万一厂商 `UFSDxe.efi` 黑盒始终不通」时的保底路线，不是下一步。**

---

## §4 非对齐访问炸弹自查（BootShim + selector）

**结论：我们已有一处同类隐患，且现在就能在主机侧证实。**

| 事实 | 证据 |
|---|---|
| SunUEFI 记录：MMU-off 下 8 字节非对齐读必炸（`ESR=0x96000021` / `FAR=0xB5B76634` / `ELR=0xA8001428`），修法 = 编译加 `-mstrict-align` | `RESOURCES/sessions/2026-11-03-Project-SunUEFI复用盘点.md` §1/A2（引自其 `docs/devel/boot/combined-boot.md`） |
| 我们的 shim 是纯汇编，**没有 C 的 `Be64` 问题**（`BootShim/BootShim.S` 61 行，`Makefile` 无 C 源、无 `-mstrict-align` 需求） | `build/uefi-woa-prep/repos/7-mu-lenovo/BootShim/Makefile`（只有 `CC=clang --target=aarch64-linux-gnu`） |
| **但 `_Payload`（= 载荷拷贝源）落在 `0x2e8`（prepi，744 B shim）/ `0x308`（dxe10，776 B shim），都不是 16 字节对齐**，而拷贝循环用的是 `ldp x2,x3,[x4],#16`（16 字节访问）⇒ 每一次源读都是**非对齐 16 字节访问** | `reports/artifacts/uefi-prepi-20261104/BootShim.bin`：`0x0: adr x1,0x2e8`；`reports/artifacts/uefi-dxe10-20261104/BootShim.bin`：`0x0: adr x1,0x308`；两者均有 `0xa8: ldp x2,x3,[x4],#16`（`0x2e8 % 16 = 8`、`0x308 % 16 = 8`） |
| 目前没炸的原因：`SCTLR_EL1.A`（对齐检查）为 0，且 MMU 关闭时 unaligned 访问在 ARMv8 上本可工作（只是慢）。**一旦某次引导器留下 `A=1`，或我们改用 `ldp` 之外的 SIMD 多寄存器加载，就会立刻变成 SunUEFI 那个 ESR** | 机理；`Silicon/Arm/MU_TIANO/ArmPkg/Library/ArmMmuLib/AArch64/ArmMmuLibCore.c:755-757` 只在建表末尾 `ArmDisableAlignmentCheck()`，而 shim 跑在那之前 |

**一次性自查命令（主机侧，零上机）**：

```sh
# 1) 载荷内所有“源/目标指针”是否 16 字节对齐（_Payload 偏移 = adr 立即数）
aarch64-linux-gnu-objdump -D -b binary -m aarch64 reports/artifacts/<变体>/BootShim.bin \
  | grep -E 'adr\s+x1|ldp|stp' | head
# 2) 16 字节访问的地址是否 16 对齐：把上面 adr 的立即数 %16，非 0 即隐患
python3 - <<'EOF'
print('_Payload 0x2e8 %16 =', 0x2e8 % 16)   # → 8，非 0 ⇒ 非对齐（dxe10 为 0x308 ⇒ 8）
EOF
# 3) 结构体/多寄存器读的自查（若将来加 C/selector）：反汇编里出现 ldp/ldr q 且基址常量非对齐即命中
```

**修法（与 §2.4 的 B 项合并做）**：在 `BootShim.S` 的 `_Payload` 前加 `.balign 16`，或在 `uefi-repack-v2aligned.py` 里把 `shim` 补零到 16 的整数倍（**顺带满足 `image_size % 16 == 0`**，见 §2.4-B）。

---

## §5 按性价比排序的下一步实验表（全部零写盘 `fastboot boot`）

| # | 实验 | 改哪里 | 屏上判据 | 成本 | 风险 |
|---|---|---|---|---|---|
| **E0 ★首选** | **修拷贝长度**：长度改用构建期 `_UefiSize: .quad UEFI_SIZE` + 分块循环改有序比较/向上取整，并给循环加硬上界 | `BootShim/BootShim.S`（新变体补丁，参考 `patches/uefi/20261103-posctrl/0002` 的 `_UefiBase` 写法）；`scripts/uefi-repack-v2aligned.py` 加 `len%16==0` 断言 + 16B 对齐填充 | **`[P11]` 不再出现**（DxeCore 不返回）+ 屏被 DXE 清屏 + **`[D00]` 出现**；块表 64/64 全对 | 1 发 | 低（可回退到现镜像） |
| **E1** | 三张 FNV 块表（源/目标/PrePi），步长 `0x20000`（跨 1 MiB 边界才有鉴别力） | `patches/uefi/20261104-dxe/0013-prepi-block-fnv-table.patch` + shim 内 2 张表 | A/B 都好、C 好 = 修好；若 A 好 B 坏 = 拷贝/cache 侧；若仍只见 1 MiB 好 = E0 未生效 | 1 发 | 低；**必须与 E1 同一发**（否则白烧） |
| **E2** | 若 E0 后仍只 1 MiB 好：把 `PlatformMemoryMapLib.c:36` `UEFI FD` 的 `BsData` → `Reserv` | `build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c:36` | 块表 C 由「16/64 对」变「64/64 对」 | 1 发 | 低（只影响 DXE 起来后的 allocator，见 §2.2） |
| **E3** | 给 PrePi 加「周期重发关键检查点」（借 SunUEFI §3.1 的纪律） | `Platforms/AndromedaPkg/PrePi/PrePi.c`（已有 `SbMark`，加 timer/pump） | 一屏滚掉后仍能回读最后阶段 | 0 发（随下次上机） | 低 |
| **E4** | 进 DXE 之后的第一道闸：**DXE dispatch 相位点**（`DxeMain.c` 9 点 + `Dispatcher.c` 每 dispatch 一个 `>`） | `patches/uefi/20261104-dxe/0001/0002`（已在手，等 E0 通过后再上） | `[D01]…[D08]`（`gBds->Entry` = 进 BDS 菜单） | 1–2 发 | 低 |
| **E5** | 若 E4 停在 UFS：先换树内 `PatchedBinaries/UFSDxe.efi`（`00ae059f…`） | 构建选项 `--ufsdxe` | 出现 BlockIO/分区枚举计数 | 1–2 发 | 中（黑盒二进制） |
| **E6** | 若 E5 仍空：评估搬 SunUEFI 自研只读栈（§3.2 的 6 文件 + SMMU/GPT/Ext4 依赖） | 新 DXE 组件 | 133 分区 / 139 句柄（照他们实机数字） | 主机 2–3 天 | 中高 |
| **E7** | 收口纪律：诊断构建与发布构建分离 + 每次上机只带 1 个变量 | `scripts/uefi-build-variant.sh`（manifest 加 `instrument=` 列） | —（流程项） | 0 发 | 无 |

**先做哪一条**：**E0（+E1 同发）**。理由：§2.4 已用**反汇编把「只拷了 1 MiB」证到指令级**，`LzmaDecode` 失败的因与果因此闭环；E0 是唯一一条「改 3 行汇编就应当直接跨过整个 FV 解压卡点」的实验，而 E2/E5/E6 都建立在「4 MiB 真的在内存里」这个前提上——不先修它，后面全部实验都会得到同样的假阴性。带宽注意：E0 成功后，卡点会**一次性跳到 DXE dispatch/UFS**，应同时备好 E4 的插桩件。


DONE-UEFI
