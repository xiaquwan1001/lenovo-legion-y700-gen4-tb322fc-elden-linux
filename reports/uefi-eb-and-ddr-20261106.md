# 2026-11-06 夜·三：屏显 NULL 崩修好 → EB 正常返回 → 面板被熄 → 转 DDR 黑匣子（p27/p28/p29/p30 四发）

## 1. 四发结果一览

| 代 | 内容 | 上机结果 |
|---|---|---|
| p27 | R19 帧缓冲硬边界 + R20 归因行加 `ESR/FAR` + **R21 惰性初始化** | 屏上出现 `[F] len=2B00000 lim=70000 stride=1DC0 line=16500`；`[K] NO-EB OK`；**无 `[K] FLT`** |
| p28 | R22 恢复 EB + banner 带 EB 状态（`eb=%r`） | **只剩背光**；USB 从 0 s 起彻底消失，65 s 内无任何枚举、无网络 |
| p29 | R23 DDR checkpoint（page 4 = EB 返回后、page 5 = `LinuxKernel()` 前） | `[K] FLT pc=CFD0F448 img=- b=CFD04000 z=46000 o=B448 esr=96000046 far=E3F04000` |
| p30 | R24 把 `0xE3F00000` 登记进平台内存图（Reserv + WRITE_BACK_XN） | 只剩背光（待 DDR 读回判读） |

## 2. 三条硬结论

1. **屏显真因 = `p_Position` 恒 NULL，不是写穿**：`LinuxLoader.map` 里**没有 `SerialPortInitialize` 符号**
   （该映像从不调初始化，LTO 连符号都丢了）⇒ 第一次打印就 `p_Position->y`（offset 8）data abort。
   `R21` 惰性初始化修好，`[F]` 那行同时把三个数钉死：**描述符声明 `len=0x2B00000`=43 MiB**，
   我们夹的预算 `lim=0x70000`=448 KiB，一行文字 `line=0x16500`=91 392 B（scale 1）⇒ 屏上稳定只装 ~6 行。
2. **`ExitBootServices()` 正常返回**（p29 的 fault 落在 `SbBbMark(4)`，而它前一条就是 `SbEbStatus = Status;`
   ⇒ EB 调用已完成）⇒ 「EB 卡住」假设作废，p28 的背光**不是** EB 挂死。
3. **EB 之后面板被驱动退出流程熄掉** ⇒ EB 之后的屏上判据全部无效（p28/p30 都是「只剩背光」）；
   同时 USB 设备栈被拆 ⇒ 宿主通道也没了 ⇒ **EB 之后唯一通道 = DDR 黑匣子**（`PITFALLS #531`）。

## 3. p29 那条 fault 的完整解读（顺带证明 DDR 页没被映射）

`esr=0x96000046` ⇒ EC=`0x25`（Data Abort, current EL）、WnR=1（**写**）、DFSC=`0b000110`（translation fault, level 2）
`far=0xE3F04000` = 黑匣子窗口 `0xE3F00000` 的 **page 4**（正是 `SbBbMark(4)` 要写的那页）
⇒ UEFI 页表没映射该 carveout（平台内存图里 `0xD6610000`–`0xFC800000` 之间是空洞）。
`R24` 用「Reserved + WRITE_BACK_XN」把它登记进 `PlatformMemoryMapLib`（与 `XBL DT` 同型），
内核侧本来就有 `memmap=1M$0xE3F00000` 保留，地址对齐。

## 4. 判据（下一步，p30 已打，等读回）

复位后正常进 Linux → `scripts/blackbox.py read --pa 0xE3F00000`：
- **page 4 有、page 5 无** ⇒ EB 过了但没走到跳内核（`PreparePlatformHardware()` 一带卡住）；
- **page 4、5 都有**而设备无 USB ⇒ 已经调用 `LinuxKernel()`，问题在跳内核参数/内核极早期；
- **都没有** ⇒ 连 EB 返回后第一行都没走到（说明 `SbBbMark` 仍写不进去，要换窗口）。
