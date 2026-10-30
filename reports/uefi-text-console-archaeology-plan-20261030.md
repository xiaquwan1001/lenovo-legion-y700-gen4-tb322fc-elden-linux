# UEFI 文本 console 考古 + 复现计划（L2 lane，2026-10-31）

> **问题**：历史上到底哪一版 UEFI 能上屏幕、输出文字缓冲区（文本 console）？
> **产出性质**：只读考古 + 可执行执行单。**本 lane 不碰设备写操作、不构建、不 git 提交**。
> **证据等级**：`已证` = 有文件:行 / 命令输出 / URL 原文；`未证实` = 推断；`未上机` = 有产物无实测。
> **地基**：`reports/uefi-consolidated-20261030.md` §0/§1/§2（27 条已确证事实，下称「总账」）。
>
> **问答对应**：Q1→§1；Q2→§2；Q3→§3；Q4→§0 速查表 + §4；Q5→§5.1。已确认事实汇总在文末 §A（A1–A21）。

---

## §0 一页结论（数字先行）

| 项 | 数字 / 结论 |
|---|---|
| 「历史上能屏上出字」的**层次** | **2 层**：① **FrameBuffer debug console**（3 发，10-05）② **BDS/ConOut 文本 console**（1 发，10-05 实验 B） |
| 10-05 能出字的**确切产物** | ① `lenovo-y700g4_NOSB.img`（CI RELEASE，**header v3**，2 441 216 B，sha **`9607a394…`**）② 本地 DEBUG（v3，`1e4bfc59…`）③ 本地 DEBUG+`SCALE_FACTOR=3`（v3，`c4567bd6…`，**首个可读**）④ **`expB-ufs-unpatched.img`（v3，2 682 880 B，`f6c12112…`，跑到 BDS）** |
| 这些产物现在在哪 | **全部不在盘**（`已证`：内容非空的 `.img` 最早 = 2026-10-26；10-05 当日全盘 `<1 MiB` 只有 3 个 0 字节占位文件；`find` 镜像名/扩展名均零命中） |
| 重取/重建 | 重取 1 条路（GitHub artifact `37257529970`，**未核过期**）；重建 1 条路（同 commit `6b6ac42a` 树在盘 8.2 GiB） |
| 最近一次上机（10-30，总账之后） | **4 发**：E0 ✗ / N2 ✗ / **E1 ✗（本 lane 首次归档，此前无报告）** / **A2 ✓交棒但全静默** ⇒ **J1（屏上出字）仍为 0** |
| 根本矛盾 | **同一 v3 header，10-05 真交棒，10-24 不交棒**；**`--base 0x10000000` 已满足仍不交棒**（9/10/11）⇒ 交棒主变量在**载荷**，且目前唯一相关项 = “含 vendor UFSDxe”（§3.3） |
| 最小复现 | **~90 s 构建 + 2 发上机**：`PakalaNoSb.dsc` RELEASE + `SCALE_FACTOR 3` + **未补丁 UFSDxe**；首次发 v3、备发 v0/`0x10000000` |
| 判据 | **3 条二值**：USB 是否掉线 / 屏上是否出可辨认 ASCII / 60 s 内是否回落 stock（§4.3） |
| 未证实 | **9 条**（§5 U1–U9），其中 **3 条可由本执行单直接回答**（U1/U3/U6） |

**一句话**：能出字的版本从来不是“某一版 Mu”而是**一个配置**（NoSb + 放大字号 + 未补丁 UFSDxe），
它 10-05 既出过异常字块也跑到过 BDS，但**四枚产物全部丢失**；而复现的真正不确定项不是构建而是**ABL 交棒条件**（现无单一变量能解释）。

### Q4 结论速查（详细执行单在 §4）

| 问 | 答 |
|---|---|
| 复用 E0 还是 E1？ | **都不用当首选**。E0（无 cache shim）只是“10-05 口径”但 10-30 实测**不交棒**；E1 装的 dodge 件与仓库 `PatchedBinaries` 不是同一对（155 648 vs 151 552 B）且**从未执行**。首选 = **10-05 实验 B 配方**（未补丁 UFSDxe + 补丁 ClockDxe + `EnableMultiThreading=0`，后两项已是默认） |
| 要 `-D DEBUG` / `PcdDebugPrintErrorLevel` 吗？ | **不必须**：头行与 `Recursive exception` 是 `SerialPortWrite()` 直调，RELEASE 也出字。要模块名/寄存器转储才把 `-b RELEASE` 改 `-b DEBUG`（会自动得 `0x0f`/`0x800fee0f`，代价：地址变、包变大） |
| 要禁用串口吗？ | **不用**：`PakalaNoSb.dsc:32-34` 已把 GENI/DM/Memory 三个串口全设 0，屏幕是唯一出口 |
| 要 `--base 0x10000000` 重打包吗？ | **两发都打**：T1 保 v3（10-05 真的跳过的那面）+ T2 按 #418 打 v0/`0x10000000`。因为 #418 只对 v0 成立，而 10-05 的成功案例是 v3 |
| 要改 `PcdSetupConOut*` 吗？ | **不用**：本机 180/166 已与 1904×3040 匹配；且通道① 根本不读它 |


---

## §1 「哪一版」定案表（Q1）

### 1.1 10-05「屏上出字」的确切产物链（三发，三枚不同 sha）

> 关键更正：10-05 的屏上出字**不是一个镜像的一次事件**，而是**同一崩溃（`UFSDxe+0x13224`）在三枚产物上先后复现**；
> 屏上文字**从不可读变可读**是**改字形放大系数**的结果，与「哪一版 UEFI」无关。

| 发 | 产物 | 大小 | sha256 | 构建来源 | 屏上看到的 | 证据 |
|---|---|---|---|---|---|---|
| **①** | `out/uefi-lenovo-y700g4/PakalaPkg/ci_artifacts/lenovo-y700g4/lenovo-y700g4_NOSB.img` | 2 441 216 B | **`9607a394f0e8bad6b911a72094aea0957f7830e942b93f90da5893845541cc9a`** | **GitHub CI run `37257529970`（RELEASE，fork `xiaquwan1001/mu_wide_platforms`）**，artifact 名 `uefi-images-lenovo-y700g4` | `Synchronous Exception at 0x00000000d2b20224` + `Recursive exception occurred while dumping the CPU state`（**字形 5×12 未放大 ⇒ 读不清**） | L2-新：`~/.pi/agent/sessions/2026-10-05T02-47-29*.jsonl` 03:50:07Z / 03:59:51Z / 05:09:22Z 用户原文；同 session 03:29:45Z「CI run 37257529970 completed success」；`grubfat-inspect.sh` 输出 `FILE: out/uefi-lenovo-y700g4/…(2441216 B) sha256 9607a394…` |
| **②** | `mu_wide_platforms/Build/PakalaPkg/ci_artifacts/lenovo-y700g4/lenovo-y700g4_NOSB.img` | 2 678 784 B（DEBUG 更大） | `1e4bfc594df6b2cf9dbc83b0e00f4fa453d46af81e212fa45fecba8333a412b1` | 本地首次打通编译链：`build_uefi.py -d lenovo-y700g4 -t DEBUG`（clang-21 / Python 3.14 环境） | `Synchronous Exception at 0x00000000651224`，**FAR=0 空指针**、ESR EC=0x25 ⇒ 与 CI 版地址不同 | L2-新：同 session 07:20:08Z「本地编译链已打通」；07:29:37Z 用户抄屏；07:30:25Z 分析 |
| **③** | `Build/PakalaPkg/lenovo-y700g4.img` = `out/local-scale3/lenovo-y700g4_NOSB-scale3.img` | 2 674 545 B kernel(gz) | **`c4567bd6a73891fbb8f25b6fe94476c6b33a1d1d8b2651058cdc30e8af92e2e7`** | ② + `font5x12.h: SCALE_FACTOR 1→3`（+ 异常处理器精简/末屏重印） | **完全可读**：`Synchronous Exception at 0x000000001264D224` + `PC 0x…(0x12653A000+0x13224) [0] UFSDxe.dl1` + ScmDxeCompat/QRKSDxe/DxeCore 全栈 | L2-新：同 session 07:38:13Z（改字号）/07:40:49Z（构建 26.7 s）/07:52:00Z 用户抄屏；`c4567bd6…` grubfat-inspect 输出 |

**三发同一故障的地址换算自证**：`0xD2B20224 − 0x13224 = 0xD2B0D000`、`0x1264D224 − 0x13224 = 0x12653A000`——
即**同一 `UFSDxe+0x13224` 崩溃，只是 DEBUG 版加载基址不同**；①为 RELEASE（无模块名），③为 DEBUG（有 `.dl1` 名字）。
⇒ 「10-05 能出字」= **RELEASE CI 件本身就能出字**（①），不需要 DEBUG、不需要改字号（只是看不清）。

> **补充（比“出字”更强的一发）**：10-05 实验 **B**（未补丁 UFSDxe + 补丁 ClockDxe + `EnableMultiThreading=0`）**跑到 BDS**，
> 即**真 ConOut 文本 console**（见 §A A18、§3.1 行 4）。产物 `out/local-exp/expB-ufs-unpatched.img`
> （2 682 880 B，sha `f6c1211218c0043e578f5fbdb116692b53917b28fd848959311c04da127e1f3c`）—— **同样不在盘**。
> 若目标定义为“文本 console（ConOut）而不是 debug 画字”，那**该发才是历史上的最高水位**。

### 1.2 现状：全部**不在盘**

| 检查 | 结果 |
|---|---|
| 仓库内 `*.img` 按 mtime 全扫（排除 `build/uefi-woa-prep/repos`） | 最早 = **2026-10-26**；**无任何 10-05 的 `.img`** |
| `find /home/xuqianhui -newermt '2026-10-05' ! -newermt '2026-10-06' -size +100k` | 命中的**全是 session JSONL / clash yaml**，**无镜像** |
| `find … -iname '*NOSB*.img'` | 只有 `PlatformBuildNoSb.py`/`*NoSb.dsc` 源文件和 10-26 之后的产物 |
| `build/uefi-woa-prep` 8.2 GiB | `Build/PakalaPkg/lenovo-y700g4.img`（2 441 216 B，**10-26 16:44** 的 N2，sha `c6d41807…`）——**不是** 10-05 那枚 |

⇒ 与 10-21 报告「资产 2.3 G 全丢」一致：**三枚 10-05 产物均无本地副本**（`已证`）。

### 1.3 能否重取/二次重建

| 途径 | 可行性 | 细节 |
|---|---|---|
| **A. GitHub Actions artifact 直下** | **可能仍在（未核）** | run `37257529970`（RELEASE）在 fork `xiaquwan1001/mu_wide_platforms`；DEBUG run `37261121029` 的 artifact id = **`11325316429`**（10-05 会话原文）。artifact 默认保留 90 天 ⇒ **2026-10-05 + 90 ≈ 2027-01-03 前有效**。RELEASE artifact id **未记录**，需 `gh api repos/xiaquwan1001/mu_wide_platforms/actions/runs/37257529970/artifacts` 现查。命令见 §4.0 |
| **B. 本地按同 commit 重建** | **可**（确定性已证） | `build/uefi-woa-prep/repos/7-mu-lenovo` HEAD `6b6ac42a`（2026-10-05）在盘、8.2 GiB；同配置两遍 `.img` sha 相同（总账 F27）⇒ 可重建**字节级同源**产物；但**注意**：① 与 CI 的唯一已知差异 = 本机 clang-21 vs CI clang-18（②③的经验：地址会变）② 需 `-t RELEASE` + `USE_SCREEN_FOR_SERIAL_OUTPUT=1`（E0 口径，总账 F21） |
| **C. 从本机 `out/` 找回** | **不可能** | 见 §1.2 |

**结论（Q1）**：能用屏出字的版本 = **CI RELEASE `lenovo-y700g4_NOSB.img`，sha256 `9607a394…`，2 441 216 B，mkbootimg header v3**（`PostBuild.py` 写死 v3，总账 F27）。
**它已不在盘**；最短恢复路径 = 先试 artifact 直下（A，一条 `gh api` 命令即可判定），失败则由 B 重建同 commit。

### 1.4 10-05 那发到底「上机成功到什么程度」（补口径）

- ABL **接受**了 BootShim+FD 非标准 arm64 壳并**真跳了**（否则屏上不会有 EDK2 异常处理器的输出）——`已证`。
- 这**直接矛盾**于 10-24/10-26 测得的「header v3 被本机 ABL 静默忽略」（总账 F22）：**同一 v3 header，10-05 跳了、10-24 没跳**。
  这是总账 B5 的三个候选之一，本 lane 认为它是**最需要优先证伪的一条**（见 §3 矩阵行 V1）。
- 屏上文字 = **EDK2 DxeCore 异常处理器 `DEBUG()` 输出经 `FrameBufferSerialPortLib` 直写 framebuffer**，**不是** ConOut/GOP 文本 console（见 §2）。

## §2 文字输出链（机制 + 配置）（Q2）

### 2.1 判定：是 (a) —— 真的是 EDK2 文本画到 framebuffer；但要分清两个独立通道

**结论：10-05 屏上的字是 (a) 真文本 glyph 渲染，不是背光/花屏/撕裂。** 但必须区分**两条独立输出通道**，
它们共用 `0xFC800000` framebuffer，触发条件完全不同：

| | 通道① `SerialPort → FrameBuffer`（10-05 实际看到的） | 通道② `ConOut → GraphicsConsole → GOP`（BDS 界面 / 实验 B） |
|---|---|---|
| 渲染者 | `AndromedaPkg/Library/FrameBufferSerialPortLib`（`font5x12` 逐字模画） | `MdeModulePkg/Universal/Console/GraphicsConsoleDxe` + `ConSplitterDxe` |
| 上层调用 | `BaseDebugLibSerialPort` 的 `DEBUG()`；异常处理器**直接** `SerialPortWrite()` | `gST->ConOut->OutputString()`、BDS/FrontPage |
| 何时可用 | **PrePI/DxeCore 一启动**（无 depex、不需 GOP、不需 BDS） | 仅当 APRIORI 走到 `SimpleFbDxe`(165) 装出 GOP、再到 `ConSplitter`(182)/`GraphicsConsole`(183) |
| 怎么开启 | `PakalaNoSb.dsc:31 USE_SCREEN_FOR_SERIAL_OUTPUT=1` | 默认就在（只要有 GOP） |
| 实证 | 10-05 `Synchronous Exception at 0x…` + 寄存器转储 | 10-05 实验 B 的 BDS「无可启动设备」（§A A18） |

两条通道都**不依赖 UFS**：通道①不经 APRIORI；通道②的 `SimpleFbDxe`(165)/`GraphicsConsole`(183) 都在 `UFSDxe`(76) 之后但 depex 无关。

### 2.2 通道①的完整链（逐地址/逐配置）

```
ABL 交接时 framebuffer 仍活着（`reserved-memory/splash_region` 43 MiB @0xFC800000 `no-map`；`FW_LIVE_FB=yes`、`SIMPLEDRM=0`）
        │
PakalaNoSb.dsc:31   USE_SCREEN_FOR_SERIAL_OUTPUT = 1     ← 与 Pakala.dsc:31 = 0 的唯一开关差异
        │
Andromeda.dsc.inc:199-201  SerialPortLib = FrameBufferSerialPortLib.inf
Andromeda.dsc.inc:123      DebugLib     = BaseDebugLibSerialPort.inf
        │
FrameBufferSerialPortLib.c:46-66  SerialPortInitialize()
        ├─ LocateMemoryMapAreaByName("Display Reserved") → 0xFC800000 / 0x02B00000（43 MiB）
        │     └→ MemoryMapHelperLib.c:22-26 → GetUefiCfgLib() → ShLib->LoadLib("UEFI Config Lib")
        │        ⇒ 与 vendor UFSDxe 崩溃函数 0x13120 调的 [.data:0x228d8]+0x40 是**同一个配置 ABI**（§3.4）
        ├─ p_Position = 0xFC800000 + 1904*3040*4 = **0xFDE18000**
        └─ FbConReset() → 清屏 23.1 MB 黑（会把 ABL logo 抹掉，是“屏变黑”的二值信号）
        │
FbConPutCharWithFactor(c, msg, SCALE_FACTOR)          ← font5x12.h:33-35
FONT_WIDTH=5 / FONT_HEIGHT=12 / SCALE_FACTOR=1
  ⇒ 317 列 × 253 行、字形 5×12 px ⇒ 屏上 5 px 高 ⇒ 10-05 用户“字号太小/看不清”
  ⇒ SCALE_FACTOR=3 后：105 列 × 84 行、字形 15×36 px ⇒ 07:52 那张全栈转储“完全可读”
```

**为何 RELEASE 也能出字（但只有两行）**：`DefaultExceptionHandler` 只有两句是 `SerialPortWrite()` 直调（`:200` 递归行、`:206-207` 头行），不进 DEBUG 级别过滤；
PC/回溯/寄存器全包在 `DEBUG_CODE_BEGIN()`（`:213`）里，受 `PcdDebugPropertyMask`/`PcdDebugPrintErrorLevel` 控制（`Andromeda.dsc.inc:51-59`）。
这正是 10-05 两类屏面的差别（**已证**：03:59 用户只抄到两行；07:36/07:52 抄到整屏）。

**失败模式（代码路径已证，运行期归因未证实）**：若 `LocateMemoryMapAreaByName("Display Reserved")` 出错（ShLib HOB 缺失/配置 ABI 不通），
`SerialPortInitialize` 在 `:52-54` 直接返回错，`p_Position` 保持 NULL；首个字符即在 `:113`/`:122`/`:132` 空指针 ⇒ 触发异常处理器 ⇒
出口又是同一 `SerialPortWrite` ⇒ **递归异常 + `CpuDeadLoop` ⇒ 屏幕一个字也不出**。
这是「交了棒但全静默」（10-26 N2-v0、10-30 A2-v0b）的**首选解释**，但主机侧无法证伪（需屏/串口）。

### 2.3 通道②的 ConOut 配置（同芯片参考值）

| 项 | 本机 elden | xiaomi-piano | erhai | dodge / nx789j |
|---|---|---|---|---|
| `PcdMipiFrameBufferWidth\|Height` | **1904×3040** | 3200×2136 | 3392×2400 | 1440×3168 / 1216×2688 |
| `PcdSetupConOutColumn` / `Row` | **180 / 166**（=1904/8, 3040/19） | 400 / 112 | 424 / 126 | 180 / 166 |
| `PcdConOutColumn` / `Row` | **180 / 166** | 400 / 112 | 424 / 126 | 未取到 |
| `PcdVideo{H,V}Resolution` | 1904 / 3040 | 3200 / 2136 | 3392 / 2400 | 未取到 |

证据：`reference/uefi-samechip-20261028/NOTES-取证片段.md` §1–§4。GOP 提供者 = `SimpleFbDxe.inf`（depex 仅 `gEfiCpuArchProtocolGuid`；只做「取 `Display Reserved` + 读 `PcdMipiFrameBufferW/H` + ZeroMem + 装 GOP」，不初始化 DSI/panel/PHY）。
`ConSplitterDxe`(APRIORI:182) 分发 ConOut/ConIn/ErrOut；但 **ConIn 在本机从未起来**（`UsbBusStart: Init command not active`，10-05 §5.5）⇒ **能看不能输入**。

## §3 变量 × 现象矩阵（Q3）

### 3.0 本 lane 新取到的 10-30 上机事实（总账之后发生的，必须并入）

| 发 | 时间(本地) | 载荷 | sha256 | `Booting` | **交棒** | 证据 |
|---|---|---|---|---|---|---|
| 1 | 10-30 12:xx | E0-v0b | `ad450e28…` | `OKAY [10.108s]` | ❌ | `reports/uefi-onboard-20261030.md` §0 |
| 2 | 10-30 12:xx | A2-v0b | `a38bd563…` | **`FAILED (usb_read failed)`** | ✅ | 同上 |
| 3 | 10-30 14:15 | N2-v0b | `90659a4d…` | `OKAY [10.107s]` | ❌（60/60 s 仍 `18d1:d00d`） | `reports/uefi-n2-v0b-onboard-20261030.md` §0 |
| **4** | **10-30 15:04** | **E1-v0b** | **`2ff27bf0…`** | **`OKAY [10.110s]`** | **❌（30 s 采样全 `18d1:d00d`；随后人工 `fastboot reboot` 回 Linux）** | **L2-新：`reports/artifacts/uefi-e1v0b-20261030/{boot-attempt,usb-watch,post}.txt` —— 该发无报告，本 lane 首次归档结论** |

**四枚 header 逐字段相同**（v0/pagesize 4096/`kernel_addr=0x10008000`/`ramdisk_addr=0x11000000`/`second_addr=0x10f00000`，L2 实测）：
⇒ **#418 的 base 规则已满足仍不交棒**，交棒判别量在**载荷**，且目前与「载荷里是不是**厂商** UFSDxe」相关（E0/N2 无、E1 是 dodge 件、A2 是厂商件）。

### 3.1 版本/变量 × 现象矩阵（全部 `fastboot boot`，零写盘）

| # | header | base → `kernel_addr` | 载荷（UFSDxe） | BootShim cache 维护 | 现象 | 状态 | 证据 |
|---|---|---|---|---|---|---|---|
| 1 | **v3** | — | 10-05 CI RELEASE NOSB（Mu 补丁 `00ae059f`） | **无** | 交棒 + 屏上 2 行异常（不可读） | **C：进入通道①** | §1.1 ① |
| 2 | v3 | — | 本地 DEBUG NOSB（同载荷） | 无 | 交棒 + 全转储（PC `0x651224`，FAR=0） | C | §1.1 ② |
| 3 | v3 | — | 本地 DEBUG NOSB + `SCALE_FACTOR=3` | 无 | 交棒 + **可读**全栈（`UFSDxe+0x13224`） | C | §1.1 ③ |
| 4 | **v3** | — | 本地 NOSB + **未补丁 UFSDxe（`dac620ac`）** + 补丁 ClockDxe + MT=0 | 无 | 交棒 + **跑到 BDS，ConOut 出「无可启动设备」** | **D：进入通道②** | 10-05 档案 §4 表 B/D |
| 5 | v3 | — | 本地 RELEASE 三发 A/C/N（vendor `fa561bf1` / +RmVmDxe / 纯 Mu） | 无 | `Booting OKAY` 后 fastboot 仍应答 | **A：没交棒** | `uefi-boot-A-attempt-20261024.md` §2/§3 |
| 6 | v0 | `0x0`→`0x8000` | A2（vendor + cache shim） | 有 | 交棒 | B / 早死 | `uefi-n2-v0-attempt-20261026.md`、总账 B10 |
| 7 | v0 | `0x0`→`0x8000` | N2（纯 Mu + cache shim） | 有 | **记录内部矛盾**：F25「交棒后 60 s 静默、82 s 回落」vs B10「同会话 N2 未交棒」 | 未定 | 总账 F25 vs B10 |
| 8 | **v0** | **`0x10008000`** | A2（vendor） | 有 | `FAILED (usb_read failed)` = 真交棒；全静默；~30 s 回落 stock `_a`（`17ef:7f3d`） | **B：交棒后早死、零输出** | `reports/uefi-onboard-20261030.md` §0 发 2 |
| 9 | **v0** | `0x10008000` | E0（10-05 口径，无 cache shim） | **无** | `OKAY [10.108s]`，28 s 采样全 `18d1:d00d` | A | 同上 发 1 |
| 10 | **v0** | `0x10008000` | N2（纯 Mu + cache shim） | 有 | `OKAY [10.107s]`，60/60 s 全 `18d1:d00d` | A | `uefi-n2-v0b-onboard-20261030.md` §0 |
| 11 | **v0** | `0x10008000` | E1（dodge `e76b555f` 155 648 B + cache shim） | 有 | `OKAY [10.110s]`，30 s 全 `18d1:d00d` | A | **A21（本 lane 首次归档）** |

### 3.2 三种状态（+两种“已进入输出”）的硬判据

| 状态 | 定义 | 唯一可靠判据 | 命中行 |
|---|---|---|---|
| **A 没交棒** | ABL 从未跳载荷 | `Booting OKAY` 后 **USB 持续 `18d1:d00d`**、`fastboot getvar` 仍秒应答、`current-slot` 不变（#387） | 5, 9, 10, 11 |
| **B 交棒后早死** | 跳了，但在任何输出前挂 | `FAILED (usb_read failed: No such device)` / USB 掉线 ≥15 s，**且屏无字** | 8（+6/7 同型） |
| **C 进入通道①** | 屏上出现可辨认 ASCII | 肉眼/录像确认 `Synchronous Exception at 0x…` 或任意 glyph | 1, 2, 3 |
| **D 进入通道②** | BDS/前端界面出字 | 屏上出现 `No bootable option or device was found` / FrontPage | 4 |

### 3.3 矩阵读出的五件事（与总账口径的差异必须显式记下）

1. **「header v3 被 ABL 静默忽略」不是定律**：同一 v3，行 1–4 四次**真交棒**，行 5 三发不交棒。⇒ #387 只能写成「**某些** v3 不交棒」。
2. **「`--base 0x10000000` 就会交棒」也不成立**：行 9/10/11 满足 #418 却**全不交棒**；而 `0x8000` 的 A2（行 6/8）反而交棒 ⇒ **主变量在载荷，不在 header/base**。
3. **唯一与「交棒」稳定相关的属性 = 载荷含 vendor UFSDxe（A2）**：10-26 与 10-30 两轮同向；但行 5 的 A（vendor，v3）不交棒 ⇒ 该相关**不跨 header**，机制未明（§5 U3）。
4. **「出字」与「交棒」是不同变量**：能出字的行 1–3 全是 **NoSb + 无 cache shim**；能交棒的行 8 是**有 cache shim** 的包 ⇒ **cache 补丁与可见性无关**（同总账 F25 判断），**NoSb 与可见性直接相关**（§2.1）。
5. **`UEFI_BASE=0xFF300000` / `UEFI_SIZE=0x400000` 在所有行相同**（BootShim 头 `.quad`；ABL RAM 表有 `0x500000`）⇒ **不是变量**，行 5 的失败不能用装载地址解释。

### 3.4 与 UFS 两层故障的对接（“能出字”≠“能用”）

| 层 | 内容 | 与可见性的关系 | 证据 |
|---|---|---|---|
| 第一层 | `0x402 → GPTListenerReadSectors` 的 `ctx+4` 空指针（崩溃指令 `0x13224 ldr x9,[x0,#8]`，FAR=`0xD6ABB038`） | **正是它把 10-05 第一次屏上文字炸出来的**（行 1–3 的转储就是它） | 总账 F1/F3 |
| 第二层 | `UFS.c+2326 UFSSmmuConfig failed`（`0x42f4`，`EFI_DEVICE_ERROR`） | 不死，只 ASSERT；行 4 能绕过第一层跑到 BDS，就是因为**换成了未补丁 UFSDxe**（不再走 `0x13120` 的 `0x402` 路径） | 总账 F6/F8 |
| dodge 三补丁 | `0xa998`(UIC)、`0x114c4`(PHY 返回码)、`0x1b080`(`EnableUfsIOC` 整函数 stub) | E1 装的却是**另一对**（`e76b555f`，155 648 B，带 4 KiB `.extra`，语义 sleep→wakeup），且 E1 **没交棒** ⇒ **该补丁从未被真机执行过** | 总账 F7/F8/F11/F12；行 11 |

## §4 最短复现执行单（Q4）

### 4.0 第 0 步：先试取回 10-05 原件（只读网络，≤3 MiB）

```bash
# 工作目录：/home/xuqianhui/y700-elden ；预期 <20 s
mkdir -p out/uefi-1005-recover && cd out/uefi-1005-recover
timeout 120 gh api repos/xiaquwan1001/mu_wide_platforms/actions/runs/37257529970/artifacts \
  --jq '.artifacts[] | {id,name,size_in_bytes,expired,created_at}'   # 记下 RELEASE artifact id
# 若有未过期 artifact（name=uefi-images-lenovo-y700g4）：
timeout 300 gh api repos/xiaquwan1001/mu_wide_platforms/actions/artifacts/<ID>/zip > rel.zip
ls -l rel.zip && unzip -o rel.zip && sha256sum */lenovo-y700g4_NOSB.img
# 判据：sha256 == 9607a394f0e8bad6b911a72094aea0957f7830e942b93f90da5893845541cc9a
```
若 404/`expired:true` ⇒ 走 §4.1 重建。

### 4.1 构建（工作目录固定；总耗时预期 ≈ 90 s）

> 目标：造一枚**已知会出字**的镜像。两发：**主发 = 10-05 实验 B 配方**（能到 ConOut），**备发 = 10-05 CI 配方**（只求通道① 两行字）。
> **不修 UFS**；两处可逆改动（`font5x12.h`、`PatchedBinaries/UFSDxe.efi`）构建后必须还原。

```bash
cd /home/xuqianhui/y700-elden/build/uefi-woa-prep/repos/7-mu-lenovo
DEV=Platforms/PakalaPkg/Device/lenovo-y700g4

# ---------- G0 前置校验（不过就停） ----------
timeout -k 5 60 sha256sum $DEV/PatchedBinaries/UFSDxe.efi \
  $DEV/Binaries/QcomPkg/Drivers/UFSDxe/UFSDxe.efi $DEV/PatchedBinaries/ClockDxe.efi
# 期望：00ae059f…80ac1 / dac620ac…ce750 / 3e439a7a…72d53
timeout -k 5 30 git status --porcelain   # 期望只有 M Common/MU_TIANO + 2 个 .orig-mu

# ---------- G1 字形放大 3 倍（唯一“可读性”变量） ----------
cp Platforms/AndromedaPkg/Include/Resources/font5x12.h /tmp/font5x12.h.bak
timeout -k 5 10 sed -i 's/^#define SCALE_FACTOR 1$/#define SCALE_FACTOR 3/' \
  Platforms/AndromedaPkg/Include/Resources/font5x12.h
timeout -k 5 10 grep -n '#define SCALE_FACTOR' Platforms/AndromedaPkg/Include/Resources/font5x12.h  # 期望 3

# ---------- G2 主发：换未补丁 UFSDxe（= 10-05 实验 B） ----------
cp $DEV/PatchedBinaries/UFSDxe.efi /tmp/UFSDxe.orig-mu.efi
cp $DEV/Binaries/QcomPkg/Drivers/UFSDxe/UFSDxe.efi $DEV/PatchedBinaries/UFSDxe.efi

# ---------- G3 环境 ----------
export CLANG_BIN=/usr/lib/llvm-21/bin/            # 结尾斜杠必须有
export CLANGPDB_BIN=/usr/lib/llvm-21/bin
export CLANGPDB_AARCH64_PREFIX=aarch64-linux-gnu-
export WORKSPACE=$PWD
export PACKAGES_PATH="$PWD:$PWD/Platforms:$PWD/MU_BASECORE:$PWD/Common/MU:$PWD/Common/MU_TIANO:$PWD/Common/MU_OEM_SAMPLE:$PWD/Silicon/Arm/MU_TIANO:$PWD/Features/DFCI:$PWD/Features/CONFIG:$PWD/Binaries:$PWD/Silicon/QC/Sm8750"
export EDK_TOOLS_PATH=$PWD/MU_BASECORE/BaseTools
export EDK_TOOLS_BIN=$PWD/MU_BASECORE/BaseTools/Bin/Mu-Basetools_extdep/Linux-x86
export CONF_PATH=$PWD/Conf
export PATH="$EDK_TOOLS_BIN:$PWD/MU_BASECORE/BaseTools/BinWrappers/PosixLike:$HOME/.local/bin:$PATH"

# ---------- G4 BootShim（10-05 口径：无 cache 维护） ----------
timeout -k 5 120 bash build_boot_shim.sh -b 0xFF300000 -s 0x00400000; echo SHIM_RC=$?
timeout -k 5 20 sha256sum BootShim/BootShim.bin   # 期望 112 B / 054e114d…3b8945
timeout -k 5 20 ls -l BootShim/BootShim.bin       # 160 B = 误用了 cache 补丁版

# ---------- G5 FD（必须 NoSb dsc；-n 12，勿用 -n 26） ----------
timeout -k 10 1800 bash MU_BASECORE/BaseTools/BinWrappers/PosixLike/build \
  -p PakalaPkg/PakalaNoSb.dsc -b RELEASE -t CLANGPDB -n 12 -a AARCH64 \
  -y $PWD/Build/PakalaPkg/RELEASE_CLANGPDB/BUILD_REPORT.TXT \
  -Y PCD -Y DEPEX -Y FLASH -Y BUILD_FLAGS -Y LIBRARY -Y FIXED_ADDRESS -Y HASH \
  -D SHARED_CRYPTO_PATH=$PWD/MU_BASECORE/CryptoPkg/Binaries/edk2-basecrypto-driver-bin_extdep \
  -D BUILDID_STRING=Unknown -D MEMORY_PROTECTION=TRUE -D SHIP_MODE=FALSE \
  -D TARGET_DEVICE=lenovo-y700g4 -D FDT=y700g4.dtb; echo BUILD_RC=$?   # 预期 0，≈44 s
```

### 4.2 打包（v3 原味 + v0 保守）与产物校验

```bash
cd /home/xuqianhui/y700-elden/build/uefi-woa-prep/repos/7-mu-lenovo
FD=Build/PakalaPkg/RELEASE_CLANGPDB/FV/SM8750_EFI.fd
mkdir -p /tmp/uefi-text-20261031
cat BootShim/BootShim.bin $FD | gzip -9 -n > /tmp/uefi-text-20261031/payload.gz   # 与 10-05 同构

# 发 1：header v3（10-05 原味：那一面确实真跳过）
timeout -k 5 60 python3 /home/xuqianhui/y700-elden/scripts/mkbootimg.py \
  --kernel /tmp/uefi-text-20261031/payload.gz \
  --ramdisk /home/xuqianhui/y700-elden/reports/artifacts/uefi-e0e1-20261028/empty.ramdisk \
  --header_version 3 --pagesize 4096 --cmdline "" -o /tmp/uefi-text-20261031/T1-v3.img

# 发 2：header v0 + --base 0x10000000（PITFALLS #418）
timeout -k 5 60 python3 /home/xuqianhui/y700-elden/scripts/mkbootimg.py \
  --kernel /tmp/uefi-text-20261031/payload.gz \
  --ramdisk /home/xuqianhui/y700-elden/reports/artifacts/uefi-e0e1-20261028/empty.ramdisk \
  --header_version 0 --pagesize 4096 --base 0x10000000 --kernel_offset 0x8000 \
  --cmdline "" -o /tmp/uefi-text-20261031/T2-v0.img
```

**产物核对（五项全过才上机）**：

```bash
timeout -k 5 120 python3 - <<'EOF'
import struct,gzip,hashlib,glob,os
FONT=bytes.fromhex('00000000000000008010420884000200')   # font5x12 字模起点 = NoSb 编译进 FB console 的硬指纹
for f in sorted(glob.glob('/tmp/uefi-text-20261031/T*.img')):
    d=open(f,'rb').read(); ps=struct.unpack_from('<I',d,36)[0]
    ks,ka=struct.unpack_from('<I',d,8); hv=struct.unpack_from('<I',d,40)[0]
    pl=gzip.decompress(d[ps:ps+ks])
    print(f"{os.path.basename(f)} hv={hv} kaddr=0x{ka:x} size={len(d)} payload={len(pl)} "
          f"_FVH@{pl.find(b'_FVH')} font@{pl.find(FONT)} sha={hashlib.sha256(d).hexdigest()}")
EOF
```

| 判据 | 期望值 | 不符怎么办 |
|---|---|---|
| `hv` | T1=**3**、T2=**0** | 参数错，重打包 |
| `kaddr` | T1=0（v3 不填）、T2=**0x10008000** | 补 `--base 0x10000000`（#418） |
| `payload` | **4 194 416**（BootShim 112 + FD 4 194 304） | 大小不对 ⇒ FD/shim 错，**别上机** |
| `_FVH@` | **152** | 非 152 ⇒ 壳/FD 拼接顺序错 |
| `font@` | **>0** | `-1` ⇒ 没用 `PakalaNoSb.dsc`（可见性通道没编进去）⇒ 回 G5 |

**构建后立刻还原（不留副作用）**：

```bash
cd /home/xuqianhui/y700-elden/build/uefi-woa-prep/repos/7-mu-lenovo
cp /tmp/font5x12.h.bak Platforms/AndromedaPkg/Include/Resources/font5x12.h
cp /tmp/UFSDxe.orig-mu.efi Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries/UFSDxe.efi
timeout -k 5 30 git status --porcelain   # 必须回到只有 M Common/MU_TIANO + 2 个 .orig-mu
```

### 4.3 上机（**需用户在场录像**；由父会话排期，本 lane 不执行）

```bash
# S0 就绪门（每发重过；PITFALLS #376）
timeout -k 5 20 ssh -o ConnectTimeout=8 root@192.168.7.1 'uname -v; uptime'
# >>> 用户开始录像（60 fps，对准整块屏）<<<
timeout -k 5 20 ssh root@192.168.7.1 'reboot2 bootloader'
sleep 12                                          # #368：硬复位 ~11 s 内别发 fastboot
timeout -k 5 20 fastboot devices                  # 必须出序列号，否则停
timeout -k 5 20 fastboot getvar current-slot      # 记录；期望 b
timeout -k 5 20 fastboot getvar slot-unbootable:b

# S1 发 1（主发，v3）
timeout -k 5 30 sha256sum /tmp/uefi-text-20261031/T1-v3.img
timeout -k 10 120 fastboot boot /tmp/uefi-text-20261031/T1-v3.img
# 同时开 USB 采样（格式与 reports/artifacts/uefi-*-20261030/usb-watch.txt 一致）：
#   for i in $(seq 60); do echo "$(date +%T) $(lsusb | grep -c 18d1:d00d)"; sleep 1; done
```

**三条二值判据**：

| # | 判据 | 通过 | 不通过 |
|---|---|---|---|
| **J1** | **60 s 内 USB 是否掉线** | 出现 `FAILED (usb_read failed)` 或 `18d1:d00d` 计数归零 ⇒ **交棒了** | 60/60 全为 1 ⇒ **没交棒**（状态 A），跳 S2 发 2 |
| **J2** | **屏上是否出现可辨认 ASCII**（`SCALE_FACTOR=3` 下字高 36 px） | 出现 `Synchronous Exception at 0x…`（通道①）**或** `No bootable option or device was found` / FrontPage（通道②）⇒ **J1 目标达成** | 全程联想 logo / 全黑 / 花屏 ⇒ 记「交棒后早死且零输出」（状态 B），保留录像 |
| **J3** | **60 s 内是否回落 stock Android**（`lsusb` 见 `17ef:7f3d` 或 `adb devices` 通、`getprop ro.boot.slot_suffix`=`_a`） | 回落 ⇒ 与 10-26/10-30 同形态，崩溃已发生 | 不回落且静默 ⇒ 挂死在 UEFI 内，长按电源 |

### 4.4 失败回退（全部已实测过）

```bash
# R1 槽属性复原（唯一写操作，只改 misc）
timeout -k 5 20 fastboot set_active b
timeout -k 5 20 fastboot getvar current-slot       # 期望 b
timeout -k 5 20 fastboot getvar slot-unbootable:b  # 期望 no
timeout -k 5 20 fastboot reboot                    # 期望 15–25 s 回 Linux

# R2 fastboot 完全不应答（USB 不枚举）⇒ 物理长按电源 10 s（需用户操作）；
#    仍不进系统 ⇒ 进 bootloader 后 set_active b；再不行按 DEVICE/README.md 的 EDL 兜底

# R3 回 Linux 后核身份
timeout -k 5 20 ssh root@192.168.7.1 'uname -v'
timeout -k 5 20 sha256sum /home/xuqianhui/y700-elden/bootslot-b/boot_b.img   # 确认本次未碰 boot_b
```

**回退判据（三项全绿）**：`current-slot=b` + `slot-unbootable:b=no` + ssh 通且 `uname -v` 与开工前一致。

### 4.5 记录字段（每发必写，禁手抄）

`镜像路径 + sha256 + hv + kernel_addr + payload 字节数 + font@ 偏移 + 槽前后状态 + 录像文件名 + J1/J2/J3 结果 + 回落耗时`，
写入 `reports/artifacts/uefi-text-<日期>/`（脚本 `scripts/trial.sh`）。

### 4.6 本执行单**不做**的三件事

1. **不修 UFS**（`0x402` 的 `ctx+4` 生产者、`UFSSmmuConfig` 留给其他 lane）。
2. **不改 `PcdSetupConOutColumn/Row`**（本机 180/166 已与面板匹配，且通道① 不用它）。
3. **不搞串口/USB-ACM 早显**（上游建议的 UfsSerial；与本次“最短路径”正交，§5 U8）。

## §5 未证实与阻塞

| # | 项 | 状态 | 为何卡 / 怎么解 | 证据 |
|---|---|---|---|---|
| **U1** | **同一 v3 header，10-05 交棒、10-24 不交棒** | **未证实** | 4 个候选：① ABL 进 fastboot 的路径不同（10-05 是用户手工进；10-24 是 `reboot2 bootloader`）② slot 状态不同（10-05 每发先 `--set-active=a`）③ CI clang-18 vs 本地 clang-21 产出的壳字节差异 ④ 同 #418 的“偶发”。**解法**：用 §4.2 的 T1（v3）在两种进 fastboot 路径下各打一发，只改这一个变量 | §1.4、§3.3-1；总账 B5 |
| **U2** | **10-26 N2-v0 到底交没交棒**（F25 与 B10 直接矛盾） | **记录冲突** | F25：「交棒后 60 s 静默、82 s 回落」；B10：「同会话 A2 交棒、N2 未交棒」。两者不可能同时为真。**解法**：回看 `uefi-n2-v0-attempt-20261026.md` 的 `usb-watch` 原始采样（本次未查文件级） | 总账 F25 / B10 |
| **U3** | **为何只有 A2（vendor UFSDxe）载荷交棒**（而 E0/N2/E1 不交） | **未证实** | 已排除：header/base（§3.3-2）、`code0`（E0=`0x10000381` vs A2=`0x10000501`，但 N2 也是 `0x501` 却不交）、载荷总长（A2/N2 同为 4 194 464）。剩下唯一相关项 = “含 vendor UFSDxe”。**备选解释**：A2 的 USB 掉线可能实际是**看门狗复位**而不是交棒，而判别词无法区分两者。**解法**：用 §4.2 的 T1（未补丁 UFSDxe = vendor 类）直接验 | §3.1 行 5/8/9/10/11；`uefi-onboard-20261030.md` §2 H1 |
| **U4** | **交棒后全静默是否就是 `p_Position=NULL`（`Display Reserved` 查表失败）** | **未证实** | 代码路径已证（§2.2）；区分器：① `SCALE_FACTOR` 改大前后屏上是否仍无字（若本来就不画，与字号无关）② 把 `SerialPortInitialize` 失败改成“直接画到固定 `0xFC800000`”的探针版（~10 行，不改逻辑）⇒ 若变有字，则就是查表失败 | §2.2、§A A17 |
| **U5** | **10-05 CI artifact `37257529970` 是否还能下** | **未核实（未联网）** | 需 `gh api …/runs/37257529970/artifacts`（§4.0）；若 `expired` 则只能重建。**注意**：即使拿到，它也不能直接上机（v3 且 demo 已证实本机当前状态不一定交棒） | §1.3 |
| **U6** | **10-05 实验 B 的 BDS 是否依赖我当时额外打的 faultline/末屏重印补丁** | **未证实** | 会话里 16:04 的 expB 注释为“B/D baseline with scale3+faultline”（07:38 之后改的）。⇒ 那些改动是**可见性辅助**（缩小转储、末屏重印），理论上不影响能否到 BDS，但**未做过干净对照**。**解法**：§4.1 就是不复用 faultline、只改 `SCALE_FACTOR` 的干净版，上了就自然回答 | 10-05 会话 07:38:13Z / 07:42:52Z / 08:05:00Z |
| **U7** | **`0xD6ABB030` 是否落在 Mu `MemMap` 内**（= 总账 B1） | **需上机** | 只有 `FAR=0xD6ABB038` 间接证据。**只有屏/串口活着时才能跑 `memmap`** ⇒ 本 lane 的 §4 就是它的前置 | 总账 B1 |
| **U8** | **无硬件串口 / 无 `UsbSerial*Dxe`** | **阻塞（硬件级）** | 上游 #12 建议“搞个 UEFI USB ACM Gadget”；本机 UART 全 0（`USE_UART_*_FOR_SERIAL_OUTPUT=0`）、`ttyGS0` 只是 Linux gadget。⇒ **屏是唯一输出面**，所以 §4 的录像不是可选项 | `PakalaNoSb.dsc:32-34`；`reports/bootloader-alternatives-survey-20261031.md` §L2 硬阻塞① |
| **U9** | **B7：UEFI 上线后 `simpledrm` 与 mdss 复位共存** | **未验证，且本 lane 不碰** | UEFI→GRUB 会把 GOP framebuffer 交给内核，重新引入已从 DTS 删除的 `simple-framebuffer`；与 Q28 直接冲突 | 总账 B7；`uefi-migration-interface-20261026.md` §4 C4 |

### 5.1 旁证五行：能不能不靠 Mu 拿到「屏上出字」（Q5，展开交 L4）

| 路线 | 能不能 | 证据指针 |
|---|---|---|
| **裸写 ABL 交接的 framebuffer**（自写一个 100 行内的 arm64 壳，把字丢到 `0xFC800000`） | **能，且成本最低** | `FW_LIVE_FB=yes` **5/5**（`reports/q32-matrix-20261024.md`）+ `[drm] reserved boot framebuffer IOVA 0xfc800000+0x2b00000`；ABL 只要 `/reserved-memory/splash_region` 存在就不关显示（`archive/topics/复盘.md:80-86`）。**但**：需先解决“壳能不能被 ABL 接受”（§3.3 行 5 vs 8 就是这个问题） |
| **Mu 之外的最小 UEFI**（不用 Mu，自己写 DXE 只装 GOP+ConOut） | **不推荐** | 面板/DSI 从不由 UEFI 侧初始化（`SimpleFbDxe` 只取现成 framebuffer）⇒ 自写也只能拿到“同一块 framebuffer”，换不来新能力；而依赖 `LocateMemoryMapAreaByName` 的部分可换成直接硬编码 `0xFC800000` |
| **`simpledrm`/`simple-framebuffer`（内核侧接 framebuffer）** | **不走 bootloader 但需 bootloader 交棒** | 本机 DTS **已刻意删除** `simple-framebuffer`（`reports/m1-73-dts-fix-catchup-20261013.md` §2.1：与 `splash_mem` 同址争用）；重新加回即可得 `fbcon` 早期字（内核启动阶段，而非 bootloader 阶段） |
| **lk2nd** | **不可行** | `msm8916-mainline/lk2nd` 支持面止于 `msm8996`；`sdm6xx/sdm8xx/sm6xxx/sm7xxx/sm8xxx` 命中 **0**（`reports/bootloader-alternatives-survey-20261031.md` L1-b 行） |
| **kShimC（同机型第三方实证的自绘菜单）** | **可行但只给菜单** | `sunflower2333/kShimC` + `Project-Aloha/DualBootKernelPatcher`，自带 framebuffer+LVGL；**在 TB322FC 上被第三方验证过**（`未证实` 级，同报告 L1-c/L1-e）；不提供 UFS/网络/救援 shell |

> 一句话：**要“屏上出字”不必依赖 Mu**（裸壳直写 framebuffer 就够），但**要“屏幕能读且能继续引导”仍然绕不开 UFS 与交棒条件**。展开交 L4 lane。

---

## §6 引用索引（本 lane 新增/重核的部分）

**新增文件证据**：`reports/artifacts/uefi-e1v0b-20261030/{boot-attempt,usb-watch,post,pre-state}.txt`（首次归档）；`reports/artifacts/uefi-{onboard,n2v0b}-20261030/`（本 lane 重读并实测 header）。
**会话级原证**：`~/.pi/agent/sessions/2026-10-05T02-47-29*.jsonl`、`…T06-05-48*.jsonl`（屏面抄录、构建命令、sha 清单）。
**代码级**：`Platforms/AndromedaPkg/Andromeda.dsc.inc:51-59,123,199-201`；`Platforms/PakalaPkg/PakalaNoSb.dsc:31-34`；`Platforms/AndromedaPkg/Include/Resources/font5x12.h:33-35`；`DefaultExceptionHandler.c:199-200,206-207,213,223-304,336`；`FrameBufferSerialPortLib.c:46-66,69-86,113,122-132,298-313`；`MemoryMapHelperLib.c:22-26`；`UefiCfgLib.c:16-25`；`PlatformPeiLib.c(Sm8750):137-170`；`PlatformConfigurationMapLib.c:23,30,62`；`DXE.inc:54-60`；`APRIORI.inc:45,76,165,182,183`。
**报告**：本文件 §1–§5 内联引用；总额口径以 `reports/uefi-consolidated-20261030.md` 为准。

---

## §A 已确认事实（先落盘，逐条带证据指针）

> 本节只收录**已在本 lane 复核过**的内容；引自总账的会标「总账 F#」，本 lane 新复核的标「L2-新」。

| # | 事实 | 等级 | 证据 |
|---|---|---|---|
| A1 | 10-05 首轮 bring-up 用的镜像是 CI 件 `lenovo-y700g4_NOSB.img`（mkbootimg **header v3**），`fastboot boot` 后**能进 BDS、屏上出 EDK2 同步异常文字** | 已证（引自档案） | 总账 §1 时间线 10-05 行；`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md` §4/§5 |
| A2 | 10-05 屏上文字 = EDK2 DxeCore 同步异常文本块并**反复刷屏**；同会话记录出现 `Synchronous Exception at 0x000000001264D224` + `UFSDxe.dl1` 回溯，另有 `0xD2B20224` + `recursive exception`；用户反馈「字号太小/看不清」 | 已证 | 总账 F20；`reports/uefi-samechip-tablet-display-20261028.md` §2.5/§3.2（引 `.pi/sessions/2026-10-05T{02-47-29,06-05-48}*.jsonl`） |
| A3 | 早期可见性通道 = **`FrameBufferSerialPortLib` 直写 framebuffer**，由 `PakalaNoSb.dsc:31` 的 `USE_SCREEN_FOR_SERIAL_OUTPUT=1` 打开（`Pakala.dsc:31` 为 0） | 已证 | 总账 F21；`reports/uefi-visibility-rebuild-20261028.md` §1.4/§6.4 |
| A4 | 10-05 基线口径 = BootShim **不含** cache 维护：`BootShim.bin` 112 B、sha `054e114d…3b8945`，12 条指令里 `d50b7e25`(dc civac)/`d508751f`(ic iallu) 命中 **0/0** | 已证 | 总账 F19；`uefi-visibility-rebuild-20261028.md` §2.3 |
| A5 | header v3 被本机 ABL **静默忽略**：`Booting OKAY [10.1 s]` 后仍留在 bootloader（屏为联想 logo）、`fastboot getvar` 仍秒应答 ⇒ 载荷从未执行。**真交棒判据 = USB 掉线** | 已证 | 总账 F22；`uefi-boot-A-attempt-20261024.md` §2/§3；`PITFALLS` #387 |
| A6 | 现存 9 枚镜像**0 枚**符合 #418 口径（4 枚 v0 的 `kernel_addr=0x8000`，5 枚 header v3） | 已证 | 总账 §0 表、F23、B4 |
| A7 | `UEFI_BASE=0xFF300000`、`UEFI_SIZE=0x400000`；ABL `Final RAM Partitions` 明列 `Add Base 0xFF300000 / Available Length 0x500000` | 已证 | 总账 F15；`uefi-boot-A-attempt-20261024.md` §1；`uefi-control-experiment-20261027.md` §2 |
| A8 | 本机显示参数不构成缺口：`SimpleFbDxe` 只做「按名字取 `Display Reserved` 内存（本机 `0xFC800000`/`0x02B00000`=43 MiB）+ 读 `PcdMipiFrameBufferWidth/Height`（1904×3040）+ ZeroMem + 装 GOP」，**不初始化任何 DSI/panel/PHY/clock** | 已证 | 总账 F16；`uefi-samechip-tablet-display-20261028.md` §2.1–§2.4 |
| A9 | 显示在 APRIORI 上早于/独立于 UFS：`SimpleFbDxe.inf` depex 仅 `gEfiCpuArchProtocolGuid`；APRIORI 行号 UFSDxe=76、FontDxe=119、BdsDxe=120、SimpleFbDxe=165、GraphicsConsoleDxe=183 | 已证 | 总账 F17；同 A8 |
| A10 | `UFS.c+2326`（`0x42f4`，`mov w1,#0x916`）与 `0x402`→`GPTListenerReadSectors`（崩溃指令 `0x13224 ldr x9,[x0,#8]`，FAR `0xD6ABB038`）是**两个独立故障层** | 已证 | 总账 F3/F6；`uefi-issue12-reply-final-draft-20261029.md` §0-2/§0-5/§7 |
| A11 | 10-26 N2-v0（cache 补丁）交棒后 60 s 全静默、~82 s 回落 stock Android 槽 a，**屏幕全程联想 logo** ⇒ 可见性未达成 | 已证 | 总账 F25；`uefi-n2-v0-attempt-20261026.md` §0/§2 |
| A12 | `fastboot boot` 失败会把当前槽标 `slot-unbootable:b=yes` 并切 `current-slot=a`；恢复 = `fastboot set_active b` + `fastboot reboot`（实测 20–25 s 回 Linux） | 已证 | 总账 F24 |
| **A13** | 10-05 屏上文字的**渲染者 = `FrameBufferSerialPortLib`（SerialPortLib 覆写）**，不是 ConOut：`PakalaNoSb.dsc:31 USE_SCREEN_FOR_SERIAL_OUTPUT=1` → `Andromeda.dsc.inc:199-201` 把 `SerialPortLib` 换成 `FrameBufferSerialPortLib.inf`；`Andromeda.dsc.inc:123` `DebugLib=BaseDebugLibSerialPort` 因此全部 `DEBUG()` 都画到 framebuffer | L2-新（代码复核） | `build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/AndromedaPkg/Andromeda.dsc.inc:123,199-201`；`Platforms/PakalaPkg/PakalaNoSb.dsc:31` |
| **A14** | 异常输出分两段：**无条件** `SerialPortWrite` 的只有 2 句（`"\n\n%s Exception at 0x%016lx\n"` 与 `"\nRecursive exception occurred while dumping the CPU state\n"`）；PC/回溯/寄存器转储全在 `DEBUG_CODE_BEGIN()` 内的 `DEBUG((DEBUG_ERROR,…))` | L2-新 | `Silicon/Arm/MU_TIANO/ArmPkg/Library/DefaultExceptionHandlerLib/AArch64/DefaultExceptionHandler.c:200`（recursive）、`:206-207`（header）、`:213` `DEBUG_CODE_BEGIN()`、`:223-304`（转储）、`:336` `gST->ConOut->OutputString` |
| **A15** | 因此 **RELEASE 也会出字**（2 行），但 `PcdDebugPropertyMask=0x00`/`PcdDebugPrintErrorLevel=0`（`Andromeda.dsc.inc:58-59`）⇒ 无转储；`TARGET=DEBUG` 时 `0x0f`/`0x800fee0f`（`:51-52`）⇒ 全转储。**这正好解释 10-05 的两种屏面**（CI RELEASE 只有两行，本地 DEBUG 有整屏） | L2-新 | 同上 + `Andromeda.dsc.inc:51-59` |
| **A16** | 字形尺寸决定可读性：`font5x12.h` `FONT_WIDTH 5`/`FONT_HEIGHT 12`/`SCALE_FACTOR 1`；1904×3040 面板下 5×12 px 文字不可读，改 `SCALE_FACTOR 3` 后 105 列×84 行可读 | 已证（10-05 实测） | `Platforms/AndromedaPkg/Include/Resources/font5x12.h:33-35`；`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md` §3；10-05 会话 07:38:13Z/07:52:00Z |
| **A17** | 屏写入口先决条件 = `LocateMemoryMapAreaByName("Display Reserved")` 成功（`0xFC800000`+`0x02B00000`）；失败则 `p_Position` 保持 NULL，任何 `SerialPortWrite` 都会**空指针→递归异常→彻底无声**（不落任何字） | 未证实（代码路径已证，运行期归因待验） | `reference/uefi-samechip-20261028/FrameBufferSerialPortLib.c:52-54`（失败即 return）、`:113,122-132`（`p_Position->x`）；`Platforms/AndromedaPkg/Library/MemoryMapHelperLib/MemoryMapHelperLib.c:22-24`；`Platforms/AndromedaPkg/Library/UefiCfgLib/UefiCfgLib.c:16-25`（要 `GetEfiShLibHob()`） |
| **A18** | **10-05 实验 B 跑到了 BDS（= 真 ConOut 文本 console）**：`未打补丁 UFSDxe + 补丁版 ClockDxe + EnableMultiThreading=0` ⇒ 「无可启动设备」界面。这比「异常转储出字」更强，是**唯一的 ConOut 实证** | 已证（10-05 实验记录） | `archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md` §4 表 B/D 行 + §5.4；产物 `out/local-exp/expB-ufs-unpatched.img`（2 682 880 B，sha `f6c1211218c0043e578f5fbdb116692b53917b28fd848959311c04da127e1f3c`，10-05 16:04 本地构建，**已丢**） |
| **A19** | `EnableMultiThreading=0`、`EnableUfsIOC=1`、`UfsSmmuConfigForOtherBootDev=1` 在本机配置表行 23/30/62；FV 取 `PatchedBinaries/{UFSDxe,ClockDxe}.inf`（`DXE.inc:58,60`、`APRIORI.inc:45,76`），`Binaries/…/ClockDxe.inf` 被注释 | L2-新 | `Platforms/PakalaPkg/Device/lenovo-y700g4/Library/PlatformConfigurationMapLib/PlatformConfigurationMapLib.c:23,30,62`；`DXE.inc:54-60`；`DXE.dsc.inc:79-85`；`APRIORI.inc:44-45,76` |
| **A20** | 构建树当前状态：HEAD `6b6ac42a`（2026-10-05 11:51:56 +0800）、`git status` 仅 3 项（`M Common/MU_TIANO` + 2 个未跟踪 `.orig-mu`）；`PatchedBinaries/UFSDxe.efi` = `00ae059f…`（Mu 补丁版，**规范态**）、`Binaries/…/UFSDxe.efi` = `dac620ac…`（Mu 未补丁）⇒ 树未被上次实验留脏 | L2-新（实测） | `git log -1`、`git status --porcelain`、`sha256sum` 输出（本 lane） |
| **A21** | **10-30 15:04 的 `E1-v0b` 上机从未写报告**：`Booting OKAY [10.110s]` 后 30 s 采样全为 `18d1:d00d` ⇒ **未交棒**；随后人工 `fastboot reboot` 回 Linux（`/dev/sda17 ext4`） | L2-新（首次归档） | `reports/artifacts/uefi-e1v0b-20261030/{boot-attempt,usb-watch,post,pre-state}.txt` |

*（后续每 3–5 条发现追加）*
