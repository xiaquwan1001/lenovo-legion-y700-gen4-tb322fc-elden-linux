# 2026-11-06 夜·五：屏显取证通道的四条自伤 + logfs 持久化通道（p34–p36）

- 日期：2026-11-06（夜·五）
- pi 会话 id：见 `.pi/sessions/`
- 主题：UEFI（G1-29）取证通道从「屏」搬到「`logfs` 持久化窗口」；过程中连撞四条自伤/主机侧坑
- 结论：① **每模块一份库静态变量 ⇒ 自检打印被刷上百遍把屏吃光**；② `ReadBlocks/WriteBlocks` 的
  LBA 是**块号不是字节偏移**（写侧同 bug ⇒ logfs 一直没真写进去）；③ fastboot 响应只有 64 B；
  ④ `oem` 的 `Arg` 带命令名，不能按字面前缀剥。
- 证据指针：`reports/uefi-p34-p36-logfs-20261106.md`、`patches/uefi/20261106R{29..32}-*/`、
  `scripts/uefi-logfs-read.py`
- ★SSOT 待并入：`TASKS/README.md` §5「夜·五」（已并入）；`PITFALLS/README.md` #534–#537（已并入）

## #534 每个 DXE 映像都有自己一份库静态变量 ⇒ 「自检打印」变成刷屏洪水

- **现象**：`[F] geom=… / len=… / stride=…` 三行在整屏里出现**上百遍**，几乎每条 `[I] xxx.efi base=…`
  之前都有一次；此前把「`[F]` 看不到」误读成「被写穿冲掉」。
- **根因**：`Platforms/AndromedaPkg/Library/FrameBufferSerialPortLib` 被**每个 DXE 驱动各自链接一份**，
  静态量（`m_Initialized`、几何缓存、环形日志）**互不共享**。只要 `SerialPortInitialize()` 里带打印，
  驱动装载数量 = 打印次数。
- **判据/对策**：① 库里的「一次性自检」一律**只进共享环**（`SerialPortLogPutString`），只有真异常
  （`ck=BAD`）才占屏；② 需要跨模块共享的状态**不能放库静态量**，要放固定物理地址（见 #536）；
  ③ 看到「某个标记被冲刷」先数它出现了几次 —— 刷爆与冲掉是两种病。

## #535 `ReadBlocks/WriteBlocks` 的 `Lba` 是块号，不是字节偏移

- **现象**：`oem sbread` 恒 `Invalid Parameter`；写侧同 bug 意味着 `logfs` 记录**一直没写进去**，
  而 `SbWriteLogWindow()` 的返回值当时没人看，所以「写了」是假的。
- **根因**：`BlkIo->ReadBlocks (BlkIo, MediaId, Lba, BufferSize, Buffer)` 的 `Lba` 与
  `Media->LastBlock` 同单位（块）。把 `(LastBlock+1)*BlockSize - 窗口` 直接当 LBA 传，会 `Lba > LastBlock`
  ⇒ ScsiDisk 返回 `EFI_INVALID_PARAMETER`。
- **对策**：`BaseLba = LastBlock + 1 - (窗口字节/BlockSize)`；读任意偏移时再 `+(Offset/BlockSize)`，
  余量用 bounce buffer 拷出。**另**：`BufferSize` 必须是 `BlockSize` 整数倍，否则 `EFI_BAD_BUFFER_SIZE`。
- **通则**：写/读分区这类「一次就够、失败静默」的动作，**返回值必须打到可读通道**（本轮靠把
  `o=… l=…` 一起回给宿主才抓到这条）。

## #536 需要跨模块/跨阶段共享的调试状态，放固定物理地址而不是库静态量

- 做法（本轮）：环形日志放 `0xE3F80000`（32 KiB，头 `Magic/Size/Head/Total`），与 1 MiB 黑匣子窗
  `0xE3F00000` 同段（`R24` 已登记 Reserved + WRITE_BACK_XN）。任何模块的 `SerialPortWrite` 都写同一环。
- 前提与坑：该段在 PrePi 的 `MemoryPeim` 阶段会被 `0xFF` 填充（`PITFALLS #491`），所以 DXE 之前的
  记录会被抹；EB 之后没有 `gBS`，转储要用**缓存的 `BlkIo`**（`SbWriteLogWindowNoBs`），成败都要能容错。

## #537 fastboot 侧两个硬限制：响应 64 B；`oem` 的 `Arg` 带命令名

- `FastbootAck()` 把 `"OKAY"`/`"FAIL"` 与载荷写进 `MAX_RSP_SIZE=64` 的同一个缓冲 ⇒ 载荷 > ~59 B 被截断，
  客户端只看到 `OKAY`（本轮连续两发被这条误导成「读到了但没显示」）。
  对策：改 `FastbootInfo()` 分块（20 B/块 = 40 hex 字符），最后再 `FastbootOkay("")`。
- `CmdOemXxx` 收到的 `Arg` **不保证只有参数**（实测形如 `sbread:0:60`），而且命令名本身含十六进制字符
  （`s,b,r,e,a,d` 里 `b/a/d/e/f` 都是 hex）⇒ 「按字面剥前缀」与「从头解析 hex」都会被绕过去。
  对策：按 `:` 切段，取**尾部两个纯十六进制段**（倒数一 = len、倒数二 = off），并在失败信息里回显解析结果。
- **另一条新纪律**：连续 `oem sbread`（60 次/1200 B）会把 USB 端点打死 ——
  `DwcSubmitURB: physical endpoint 3 is in invalid state 4` → `UsbDeviceSend … Device Error` →
  `TRB ring of EpIndex 3 is full`。一次只拉 ≤512 B，块间 `sleep`，不在同一固件会话里拉整窗。

## #543 「EB 之后专用」的 NoBs 路径里仍然调用了 boot services（`AllocatePool`）+ LBA 单位漏改

- **现象**：p37 上机（真内核载荷）拿到 `preeb`、**永远拿不到 `posteb`**；屏上
  `[K] FLT pc=00000000 ids=131/131 esr=86000007`（= `blr` 到 0 的指令异常），帧里 `x30` 落在 `LinuxLoader` 内。
- **根因（静态可复算，2026-11-07）**：`#536` 加的 EB 后转储链**并不真的 NoBs** ——
  `SbDumpLogNoBs()` 里两次 `AllocatePool`/`FreePool`，`SbWriteLogWindowNoBs()` 里又一次
  `AllocatePool`/`FreePool`。EB 之后 `gBS` 已失效（本例 `+0x40` 取出 0，`+0xE8` 才是 ExitBootServices）
  ⇒ `blr x8` 跳 0。**这一次「EB 之后立刻死」极可能是我方探针自杀**，与 `#534`（探针把屏写爆）同类。
- **第二处漏改**：`SbWriteLogWindowNoBs()` 的 `Base` 仍按**字节偏移**算却当 LBA 传（`SbWriteLogWindow()`
  在 `R32` 已修，NoBs 版本漏了）⇒ 即使不崩也恒 `EFI_INVALID_PARAMETER`。
- **修法**（`patches/uefi/20261107R33-true-nobs/`）：EB 后路径全部改**静态缓冲 + 内存拷贝**，
  Base 走 `LastBlock + 1 - (窗口/BlockSize)`；并在 EB 前后各留环内标记（`[K] EBC-call` / `EBC-ret0|ret!`）
  与一次带 `cbz` 守卫的 `gBS` 内存读，让下一发能把「EB 之前成员就已为 0」与「EB 把它失效了」分开。
- **纪律**：写「某阶段不可用的服务」时，**先机械扫一遍该路径上的符号**（`grep -n "AllocatePool\|FreePool\|gBS->"`），
  不要凭函数名（`NoBs`）相信它不含 boot service；同族的「单位/口径修正」要**按函数逐个改**，
  漏一个副本等于没改（第二处漏改就是这么来的）。

## #544 工作区文件「静默改坏」但 `git status` 仍报干净（stat 缓存 + size/mtime 未变）

- **现象（2026-11-07）**：UEFI 构建在 `Platforms/OpensslPkg/Library/OpensslLib/openssl/crypto/evp/legacy_sha.c:192`
  报 `error: expected ';' after top level declarator`，源码行是 `const EVP_MD *EVP_{ha512(void)`（应为 `EVP_sha512`）。
  更诡异的三件事同时成立：`git status --short` 干净、`git fsck` 无异常、`git cat-file -p HEAD:<file>`
  里内容是**正确**的。
- **机制**：git 的 index 用 `mtime + size` 判断「是否改过」。文件被就地改坏而**长度与 mtime 都没变**时，
  status 直接跳过内容比对；`git checkout --` 也不会重写它（认为无需恢复）⇒ 只有先 `rm` 才会真正落回。
- **修法**：`rm -f <file> && git checkout -- <file>`；排查同族问题时先 `git update-index --refresh`
  再看 status（它会把 stat 缓存刷掉一部分），必要时 `git diff --no-ext-diff --stat` 或直接
  `git cat-file -p HEAD:<file> | diff - <file>` 逐文件比。
- **同族**：`PITFALLS #512/#513`（磁盘/页缓存位翻转）。本条是**工作区**层面：不一定是位翻转，
  也可能是「编辑器/脚本半途写坏 + 长度未变」。**构建报的语法错误先怀疑源码被改坏，再怀疑编译器/版本。**
