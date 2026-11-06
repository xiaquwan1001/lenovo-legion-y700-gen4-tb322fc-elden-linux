> **2026-11-06 22:40 执行完毕（本文件已兑现）**：H1/H2 已建（`20261106R17-faulthandler-image` / `R18-rehook-exception`），
> D1/D2 两发已打（p25 无输出、p26 命中），**问题不在「哪个驱动」而改判**：PC 在 `LinuxLoader` 自己的 `SerialPortWrite` 内。
> 结果与更正见 `reports/uefi-flt-attribution-20261106.md`；**下一批执行单 = 本文件 §7**（p27：帧缓冲控制台硬边界 + 清剩余未门控屏显写）。

# 2026-11-06 夜 UEFI 下一批（p25/p26）：把崩溃 PC 落到模块名，再决定「剔除驱动」还是「跳内核调用约定」

> 入口前提：读 `reports/uefi-day-20261106-digest.md`（当日 4 段推进 + 5 条作废）。
> 不可动摇的三条：真件**默认静默**（R12）、**一会话一发**（82 MB）、每轮崩后核 `slot info`（`PITFALLS #525`）。
> 预算：主机侧 ~2 h，上机 **2 发**（≤15 min，需用户在机旁 + 至多 1 次断电）。

## 1. 待答的唯一问题

`Synchronous Exception at 0xCFE98C8x` 是**哪个 DXE 映像**打的？—— 已知它落在 `LinuxLoader`（屏上 `[I]? base=0xCFEB2000 size=0x45000`）基址**下 ~0x1C000**，
即不在自家模块内；源码级探针改不动它，必须先把 PC 映射成模块名。

## 2. 主机侧已有的事实（本批开工前先核一遍，不需上机）

- **静态 SizeOfImage 可当运行时映像尺寸**：`LinuxLoader.efi` 的 PE `SizeOfImage` = `0x45000`，与屏上 `[I]? size=0x45000` **完全一致**
  ⇒ 静态表可直接用来反推运行时布局（验证命令：读 `Build/…/LinuxLoader/OUTPUT/LinuxLoader.efi` 的 `e_lfanew+24+56`）。
- **候选窗口（假设：前邻映像紧贴 LinuxLoader 基址）**：`PC-差 = 0xCFEB2000 - 0xCFE98C84 = 0x1937C`，
  页对齐后前邻映像的 `SizeOfImage ∈ [0x1A000, 0x22000]`。用 `Platforms/PakalaPkg/Device/lenovo-y700g4/{Binaries,PatchedBinaries}` 现有件筛选，落窗的是：

  | SizeOfImage | 候选 |
  |---|---|
  | `0x1a000` | `QcomBds`, `Ip6Dxe`, `…/HiiDatabase`(Mu 件) |
  | `0x1c000` | `PILDxe` |
  | `0x1d000` | `Ebl.efi`, `QcomChargerDxeLA` |
  | `0x1f000` | `SdccDxe` |
  | `0x22000` | `Binaries/MdeModulePkg/…/HiiDatabaseDxe` |
  | `0x21000`/`0x1b000` | FrontPage / OnScreenKeyboardDxe（Mu 构建） |

- **反证（重要，避免走偏）**：带 `usb_shared_i2c` / `redriver` 字符串的四个二进制驱动
  （`PatchedBinaries/UsbConfigDxe` `0x16000`、`Binaries/…/UsbConfigDxe` `0x16000`、`UsbfnDwc3Dxe` `0x18000`、`UsbDeviceDxe` `0xD000`）
  **都小于窗口下界** ⇒ 若紧邻假设成立，它们只能坐落在 `0xCFE9A000..0xCFEB2000` 这一段，而 PC 在**它们的下面**。
  「屏上红字刷屏的是 UsbConfig 一族」与「崩溃 PC 在更下面一个模块」可以同时为真 ⇒ **不靠猜测，取 ground truth**。
- **FD 内层 FV 是压缩的**：`SM8750_EFI.fd` 里只有偏移 `0x0` 一个 `_FVH`，DXE 模块在 LZMA 压缩的嵌套 FV 内
  ⇒ 主机侧全模块枚举要先解压（可以复刻 PrePi 的 `LzmaDecode`，或用 `patches/uefi` 里已有的解压调用做参照）。本批**可选**，不阻塞。

## 3. 批内排产

### Lane H（主机侧，零上机，先做完）

| # | 事项 | 判据 / 产出 |
|---|---|---|
| H1 | **R17 邻域装载表探针**：在 `SB_STOP(40)` 之后（真载荷已证明 40 会回话）加一段只在**真启动路径**执行的 dump：遍历 `gEfiDebugImageInfoTableGuid`（或 DxeCore 的 `mImageList`），**只打印 base ∈ [LinuxLoaderBase-0x60000, +0x1000]** 的映像，格式固定一行一条 `[M] b=%010lx s=%06lx n=%a`（名字截 12 字符，无名字打 `-`），最长 3 行 | `patches/uefi/20261106R17-imgneighborhood/`；`p25-recipe.txt`；`out/r21-sbstop-p25/uefi-preamble25-r1.img`（`--verify` 复现） |
| H2 | **R18 异常处理器 PC→模块解析**：Mu 的 `Silicon/Arm/MU_TIANO/ArmPkg/Library/DefaultExceptionHandlerLib/AArch64/DefaultExceptionHandler.c` 里 `GetImageName(ELR,…)` 与 `PC …+(off) [name]` 打印**已存在但被 `DEBUG_CODE_BEGIN()` 编掉**（RELEASE 无输出）。把它搬出 `DEBUG_CODE`、改走 `SerialPortWrite`（屏），并**跳过**递归 dump（mem/stack 全表），只留：PC + base + offset + 名字 + `ESR/FAR` 一行，然后 `CpuDeadLoop()` | `patches/uefi/20261106R18-faulthandler-image/`；`p26-recipe.txt`；`out/r21-sbstop-p26/` |
| H3 | 反汇编核对：把 H1/H2 落到 `build/uefi-woa-prep/repos/7-mu-lenovo` 树后，用 `aarch64-linux-gnu-objdump -d` 在 FD 对应段确认门控 `ldr w8,[xN,#0x63c]; cmp w8,#1` 形态与插入点（照 2026-11-06 下午那次逐点核对的流程） | 记录在 `patches/uefi/README.md` 的 p25/p26 行 |
| H4 | （可选，不阻塞）FD 解压 + 全模块表 `base/size/name/GUID` → `reports/artifacts/uefi-modmap-20261106.tsv`，与 H1 的屏上结果对账 | 表落盘即可 |

**风险**：`GetImageName` 依赖 debug image table 被 DxeCore 安装（Mu RELEASE 未必装）⇒ 若 H2 上机打出 `[K] PC … <no image>`，说明表为空，
此时 **H1 的邻域表就是唯一 ground truth**（因此 H1 必须做，不能只做 H2）。异常上下文里**不要**调用 `gBS->LocateHandleBuffer`（会分配内存）。

### Lane D（上机，2 发，按顺序）

| 发 | 件 | 目的 | 判据 |
|---|---|---|---|
| D1 | `p25`（R17 邻域表，全路径、真件原样 cmdline） | 拿崩溃点附近的映像 base/size 表 | 屏上出现 ≤3 行 `[M] b=… s=… n=…`。**LinuxLoader 那行必须出现**（自校验：`b=0CFEB2000 s=045000`），否则说明 dump 点没走到 |
| D2 | `p26`（R18 异常解析） | 把 `0xCFE98C8x` 直接翻成模块名 + 段内偏移 | 屏上 `[K] PC 0CFE98C84 0CFE9xxxx+0xNNNN <name>`；或 `<no image>`（⇒ 回退 D1 结果） |

- 执行用 `scripts/uefi-oneshot.sh <stage> out/r21-sbstop-p2{5,6}/uefi-preamble2{5,6}-r1.img`，**每发之间换会话**；
  发后 `fastboot devices` 核有没有掉线，再 `slot info` 核 retry（`PITFALLS #525`），必要时 `slot set-retry 7 b` 补回。
- **两发都无屏上输出** ⇒ 停止上机，转纯主机侧（H4 + 反汇编 H2 的插入点是否真被执行），并记一次复盘。

## 4. 拿到模块名之后的两条分支（下一批的下一批，先写清以免临场拍脑袋）

- **A｜若是 USB/redriver/Usbfn 一族**（例如屏上名字带 `Usb`）：走「单变量剔除」——在
  `Platforms/PakalaPkg/Device/lenovo-y700g4/DXE.inc`/`APRIORI.inc` 里把该驱动移出启动集（`#INF`），复测 p21 的全路径件（跳过 `FastbootUsbDeviceStop()`+ 真启动）。
  判据 = `[K] JUMP-BANNER` 出现。理由：Linux 起来不需要 UEFI 侧的 USB 设备栈；剔除它不影响 `LoadImage/StartImage` 链路。
- **B｜若不是 USB 一族**（`QcomBds`/`Pildxe`/`HiiDatabase`/`Ebl` 一类）：先看该模块在 `BootLinux()` 尾段的**调用链**（谁 `LocateProtocol` 了它），
  再决定是「EB 之前先 `DisconnectController`」还是「把该模块的 protocol 调用挪到 EB 之后」。此分支要额外 2–3 发，届时再排。

## 7. 2026-11-06 22:40 之后的新排产（p27，取代 §3/§4 的分支 A/B）

判据链已经闭合到「是谁崩」：`Synchronous Exception` 的 PC 落在 `LinuxLoader` 的 `SerialPortWrite`
（`LinuxLoader.map`: `00013bd8 000000d0`，PC=`b+0x13C84`，函数内 `+0xAC`；`SizeOfImage=0x45000` 全树唯一）。
所以 §4 的「剔除 USB 驱动 / 改调用链」两条分支**都不适用**，直接修屏显写通道：

| # | 事项 | 判据 |
|---|---|---|
| H1 | **帧缓冲控制台加硬边界**：`FbConPutCharWithFactor()` 算出像素地址后，若越过安全区（`splash_region` 前 ~448 KiB 可写）就**回卷 `p_Position->y = 0`**（或丢弃该字符）；`ResetFb()` 也在同一预算内 | 反汇编核对门控；任何调用方都写不出界 |
| H2 | **清掉真路径上剩余的未门控 `SerialPortWrite`**：`20261104R15-noavbprobe` 的 no-AVB 探针、`R2-slow-serial`、`20261106R5/R6`（banner）等，全部纳入 `SbProbeMode != 0` | 真件（无令牌）第一次屏写出现在我们**显式要取证**的那一行 |
| H3 | **归因行补 `ESR`/`FAR`**（R17 的 found 分支加上） | 下一发若再崩，能区分「写穿」vs「野指针」 |
| H4 | 上机 1 发（p27 真载荷） | 先看 `[K] JUMP-BANNER`；再看内核是否接管（USB 行为 + 是否起 Linux） |

止损不变：p27 之后累计再 3 发无 `[K] JUMP-BANNER` ⇒ 本轮收口写 handoff。

## 5. 时间盒与止损

- 本批上限：主机侧 2 h + 上机 2 发。**累计再 3 发（D1/D2 + 1 发分支件）仍无 `[K] JUMP-BANNER`** ⇒ 本轮收口写 handoff，UEFI 回「非主线、不阻塞」状态。
  理由：G1-30/vk61 已实际解决 96 MiB 限制（`TASKS` §2 G1-29 行），UEFI 是拓展项，不能无限吃主线时间。
- 收尾必做：`bash scripts/check-doctor.sh` + `git status` 干净 + 本节产出的 sha 登记（`versions/`）+ `TASKS/README.md` §5 新增一块（判据/正文/坑三件套）。

## 6. 本批要顺手改的文档（判据落地后一次写完，别分批）

- `TASKS/README.md` §5：新块（p25/p26 结果 + 分支决定）；`versions/patches-uefi-status.tsv` 加 R17/R18 行。
- `patches/uefi/README.md`：p25/p26 世代行 + 上面 H3 的反汇编核对记录。
- `PITFALLS`（若踩到新坑）：候选条目已识别——「debug image table 在 Mu RELEASE 可能为空」、「异常上下文禁止 allocate」。
