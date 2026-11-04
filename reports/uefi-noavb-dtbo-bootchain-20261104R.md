# UEFI 线 · R14–R18：AVB 被编译掉 / dtbo 32 MiB 卡死 / 探针通道被 ConOut no-op 吞掉

日期：2026-11-04 晚（接 `TASKS/sessions/2026-11-04-UEFI-DXE走完到BDS之后的handoff.md`）
设备：U2 `HA2EXB0E`（ABL fastboot）/ UEFI 侧 fastboot 序列号 `51318dc0`，`boot_b` 全程未写。

## 1. R14 探针「没编进二进制」的真因（已定论）

- 同一份 `VerifiedBoot.c` 用 build.log 的原始 clang 命令重编，`-O0/-O1/-Oz` 三种结果完全一致；
- `clang -E` 里 3 条 `AsciiPrint` 都在（`/tmp/vb_test.i` 33386/33442/33841），但对象里只剩 `[V] avb=`；
- `llvm-dis` 后 `GetAVBVersion()` = `ret i32 0`（`VERIFIED_BOOT/_2/_LE` 全 0）
  ⇒ `LoadImageAndAuthVB2` / `avb_slot_verify` / `GetPartitionIndex` 等**整段编译期消失**
  ⇒ R14 的 `[V] res=` / `[V] ld=` 是死代码，永远打不出来。**这棵树的 LoadImageAndAuth 走 NO_AVB 分支。**

## 2. 探针「上屏看不见」的真因（关键坑）

- R7 的 `patches/uefi/20261104R7-loadmap/0001-*.patch` 把 `gST->ConOut->OutputString`
  换成了 no-op（目的是让异常处理器能走到 `CpuDeadLoop`）；
- 因此 **`AsciiPrint` / `Print` / `DEBUG` 一律不可见**；屏上能看到的 `[I]/[E]/[L]` 全部走
  `SerialPortWrite`（FrameBufferSerialPortLib 直接写帧缓冲）。
- ⇒ 之后所有探针统一 `AsciiSPrint + SerialPortWrite`（R15 起），并在 LinuxLoader/BootLib/AvbLib
  三个 `.inf` 补 `SerialPortLib` + `PrintLib`。

## 3. `continue` / `boot` 的 "Load Error" 根因

`dtbo_a/dtbo_b` = **0x2000000 (32 MiB)**（`fastboot getvar partition-size:dtbo_b` 实测），
而 `NoAVBLoadReqImage()` 把「整个分区」当 dtbo 镜像，`DTBO_MAX_SIZE_ALLOWED` = 24 MiB
（`LocateDeviceTree.h:69`）⇒ `EFI_OUT_OF_RESOURCES` ⇒ `LoadImageNoAuth()` 把 dtbo 的任何失败
改写成 `EFI_LOAD_ERROR`（`VerifiedBoot.c:554`）⇒ 两条路都报 Load Error。
`dtbo_b` 实际内容**整块为 0**（Linux 侧 `dd ... | od -tx4` 全 0）⇒ 本机根本没有 overlay。

R16/R17 修法：先读一页表头；magic 不合法 ⇒ `EFI_NO_MEDIA`（= 没有 overlay，走既有 skip 分支）；
magic 合法 ⇒ 按 `total_size` 装载，且缓冲区按 4 KiB 取整（`LoadImageFromPartition` 会按块大小
向上取整读，否则越界）。

## 4. 修复之后的进展与当前卡点

- R17 起 `continue` 不再返回 Load Error，流程进到 `BootLinux`；
- 但随后 **`Synchronous Exception at 0xCFE99344` + `Recursive exception`**：地址落在 DXE heap
  （`PlatformMemoryMapLib.c` 里 `DXE Heap = 0xB90C0000+0x1D500000`），**不在 kernel 区**
  （`Kernel = 0xA8000000+0x10000000`，`KernelLoadAddr = 0xA8080000`）；
- R18 在 `LinuxKernel(...)` 前插了 `CpuDeadLoop()`，实测**没走到**该停点 ⇒ 崩溃发生在
  `BootLinux` 的准备阶段（`GetImage`/`UpdateBootParams`/`DTBImgCheckAndAppendDT`/
  `LoadAddrAndDTUpdate` 之一），不是跳内核之后。
- 已加 `[K] enter/img/addr/dtb/ldt/jump` 与 `[V] …` 标记（`SerialPortWrite`）；
  当前唯一缺的证据是屏上这几行的值（异常打印会滚屏，取证只能靠人工拍照）。

## 5. 下一发（R19）备选取证方案

若 `[K]` 行仍拍不到：把每条标记同时写进 **UEFI NV 变量**（`gRT->SetVariable`，本树有
`VariableRuntimeDxe`+`FvbDxe`），下次启动在 BDS 入口读出来用 `SerialPortWrite` 打最后 3 行再
`CpuDeadLoop()` —— 画面只剩这几行，拍一张就能定位。

## 6. R19/R20 与「随机性」（本轮最后状态）

- R19（NV 变量取证）：`[S] prev:` 在 22:41 那发镜像上**没有出现在屏上**（连 `[S] setvar=` 也没有），
  但同一发的 LinuxLoader/FV 确实是新编的（`found=1 size=0x2B800`，比 R14 的 `0x2B000` 多 2 KiB）。
  ⇒ 变量取证不可用/未落地，已放弃，改宿主可编程停机点。
- **用户实测：从最近两发开始崩溃是随机的**（同一镜像一次启动有递归异常、一次没有）。
  ⇒ 不是固定代码路径的确定性 bug，更像内存/时序相关问题（堆被写坏、或交接前状态不稳定）。
  这也意味着二分必须重复多次才能定论。
- 现有取证工具（已构建，`out/uefi-20261104R20-stage-bisect-r1.img`）：
  `boot.img` cmdline 里加 `sbstop=N`（N=1..7）即让 BootLinux 在第 N 阶段返回 `EFI_ABORTED`；
  宿主判据：fastboot 回 `Aborted` ⇒ 到达 N；USB 掉线 ⇒ 崩在 N 之前。二分不需要拍照。

## 7. 未解 / 下一步

1. 用 R20 的 `sbstop=N` 在 `fastboot boot`（内存镜像路径，cmdline 可注入）下二分崩溃阶段，每档重复 3 次
   以对付随机性；
2. 若崩溃确实落在 `LoadAddrAndDTUpdate` 之类拷贝阶段，重点查：内核/ramdisk/DTB 落地地址
   （`Kernel=0xA8000000+0x10000000`，`KernelLoadAddr=0xA8080000`）与 DXE heap
   （`0xB90C0000+0x1D500000`）是否相交、以及 `LoadImageFromPartition` 的按块取整读；
3. 备选（不改 Qcom 老路）：按 handoff 的方案 A，直接在 FD 里放 arm64 GRUB / 一个自写 loader，
   由 BDS `LoadImage` 启动，绕开 `BootLinux` 这套 Android 语义。
