# 2026-11-06 夜·三：屏显 NULL 崩修好 → EB 正常返回 → 面板被熄 → 转 DDR 黑匣子（p27/p28/p29/p30 四发）


<!-- pitfalls-entries -->
> **本报告承载的 PITFALLS 条目正文锚点**（索引行在 `PITFALLS/README.md`；此处给 #NNN 定义，避免索引悬空）：
> `#532`、`#533`

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

---

## 5. 追加（p30 读回 → p31/p32/p33）：**已经调用到 `LinuxKernel()`**，卡点搬到「交接参数」+ 新发现「屏满不刷新」

### 5.1 p30 的 DDR 读回（决定性的正面结果）

```
$ scripts/blackbox.py read --pa 0xE3F00000
   4  uefi:eb-returned（ExitBootServices 已返回）      99.7% REACHED
   5  uefi:before-LinuxKernel（已到调用点）            99.8% REACHED
```
⇒ ① `ShutdownUefiBootServices()` **正常返回**；② **已经执行到 `LinuxKernel()` 调用点**（下一条指令就是跳）。
而设备此后 65 s 无 USB、无网络 ⇒ **内核没有起来**。卡点从「EB / 跳不跳」彻底搬到了
**「交接参数（DTB/内核地址/MMU-cache 状态/入口约定）」与内核极早期**。

### 5.2 p31–p33 三件（都为看清交接参数与异常而做）

| 代 | 改动 | 上机结果 |
|---|---|---|
| p31 | R25 帧缓冲预算放回整块面板（448 KiB 那条结论疑似 NULL 崩误判）+ **scale 4**（用户要求字体放大四倍）；R26 在 **EB 之前**打一行 `[K] dtb=<addr> m=<魔数> sz=<fdt总长> k=<内核地址>` | 屏写满后**不刷新**，看不到新内容 |
| p32 | R27 满屏时**有界清屏 + 回顶**（`SetMem` 到 `m_FbSafe`）+ `[F]` 行加 `s=%d` 报有效 scale | `[F] len=2B00000 lim=164800 stride=1DC0 line=16500 s=4` ⇒ **scale 4 确实生效**；随后 **`Recursive exception occurred while dumping the CPU state`** ⇒ 我们的 handler 自己二次崩（R21 的惰性初始化在 EB 之后调到了 HOB/UEFI 服务） |
| p33 | R28 去掉 `SerialPortWrite` 的惰性初始化（未初始化就静默丢弃），改在 `LinuxLoaderEntry()` 显式初始化一次 | 已构建、**未上机**（本轮收尾） |

### 5.3 ⚠ 遗留 bug（下轮第一优先）：满屏不刷新 ⇒ 看不到真正的 CPU dump

现象（p31/p32/p33 三代共有）：**屏幕写满之后不再刷新**，异常 dump 打不出来就被卡死。
已定位到两条互相叠加的原因：

1. **可用行数被 PCD 尺寸夹死**：`lim=0x164800`=1 460 224 B ≈「16 个未缩放行」，
   而 `scale=4` 时一行文字占 4 行 ⇒ **整屏只剩 ~4 行**；随便一点输出就满，
   之后全靠「回卷」维持，任何多行内容（异常 dump 几十行）都会被自己碾掉。
   `len=0x2B00000`（43 MiB，描述符声明）与 `gWidth*gHeight*(gBpp/8)`（≈1.4 MB）差 30 倍 ⇒
   **PCD 里的宽高和真面板（1904×3040）不一致**，这是必须查清的第一件事。
2. **回卷/清屏/刷新三者没对齐**：R27 只做了「`SetMem(m_FbSafe)` + `y=0` + `FbConFlush()`」，
   而没有处理 `p_Position->x` 与 `m_MaxPosition` 的原设计语义（原设计用 `ResetFb()` 三重像素循环 +
   行计数），于是「写满」与「刷新」在边界上不一致。

**下轮修法（已写进计划）**：① 先量出真面板几何（PCD 值 vs `len` vs 实测一行字节），把 `m_FbSafe` 定为
`min(描述符长度, w*h*bpp/8)` 的**真实值**；② 用行计数（`y += FONT_HEIGHT*scale` 的像素语义）实现
「满屏 → 有界清屏 → 回顶」，并在**清屏后同步 `x=0`**；③ 异常归因恢复**多行 dump**（既然能刷），
或按 `sbprobe` 选择「单行归因 / 完整 dump」两档。
