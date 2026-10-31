# UEFI 早期可见性通道调查（2026-10-31，lane：uefi-vis，L1）

> 派工单目标：**拿到 A2 形态交棒之后，UEFI 早期输出的最小可行观测面是哪条、代价多大、判据是什么**。
> 本轮不上机/不刷写/不重启；全部结论来自静态取证 + 树内源码 + 上游只读检查。
> 证据词：`已证` = 有命令/原文；`未证实` = 推断或缺直接证据。

---

## §0 结论（先行）

| 通道 | 可做性 | 最小代价 | 判据 | 本轮状态 |
|---|---|---|---|---|
| **① 屏上出字（FB 直写 / FrameBufferSerialPortLib）** | **已证可行（树内现成，无需焊接）** | **0 行新代码**（改 1 个 build 变量重打包）；BootShim 里程碑已备料（384 B shim，rc=0） | A2 交棒后屏幕出现色条/文字 | **推荐主通道** |
| ② 内存落盘（InMemorySerialPortLib→PStore 区） | **本机不可行**（MemoryMap 无 `PStore` 区；需改 PlatformMemoryMapLib 自划一块） | 中（改 map + Linux 侧读取脚本） | /dev/mem 读到环状日志 | 备选，可与①叠加 |
| ③ USB 串口/ACM gadget | **未证实**（树内无 UsbSerialDxe；`UsbfnDwc3Dxe` 在 APRIORI 但无 serial 客户端；上游组织内 code search UsbFnSerial=0） | 高（自写 USB ACM function 驱动） | 主机 `lsusb` 出新 ttyACM | 不推荐本轮 |
| ④ 硬件 UART（GENI） | **未证实**（TB322FC 无公开 UART 测试点证据；树内有 `QcomGeniSerialPortLib` 现成实现，`PcdUartSerialBase` 默认 0x98C000 但本机 PCD 未覆盖） | 极高（拆机+焊接/找飞线） | 串口出字节 | 记录，不深究 |

**一句话**：**A2 形态改 0 行代码就有观测面**——A2 构建已编入 `FrameBufferSerialPortLib`（`PakalaNoSb.dsc:31` `USE_SCREEN_FOR_SERIAL_OUTPUT=1`），它直接写 ABL 已点亮的 framebuffer（`Display Reserved` 0xFC800000），**不依赖 GOP**；当前全静默的最合理解释是**死在它之前**（PrePi 之前/之中），所以补上 BootShim 里程碑色条（已编译验证）把观测窗口前移到 shim 第一条指令。

---

## §1 A2 静默的结构性定位（为什么三条路现在都该是"死在更早"）

### F-V1 已证：A2 载荷里可见性代码是编进去的
- `PakalaNoSb.dsc:31`：`USE_SCREEN_FOR_SERIAL_OUTPUT = 1`（10-24/10-28/10-30 三次构建同口径）。
- `Andromeda.dsc.inc:197-203`：该开关 ⇒ `SerialPortLib = FrameBufferSerialPortLib`。
- `FrameBufferSerialPortLib.c:28-31,52-57`：输出直接写 `PcdMipiFrameBufferWidth/Height`（本机 PCD 1904×3040）+ `LocateMemoryMapAreaByName("Display Reserved")`（本机 map `0xFC800000/0x02B00000`，PlatformMemoryMapLib:35）。**不调 GOP、不碰 DSI/panel PHY**（与 `uefi-consolidated-20261030.md` F16/F17 一致）。
- DebugPrint 门控（`Andromeda.dsc.inc:575` 区域 `PcdDebugPrintErrorLevel|0x00000000`）**只影响 DEBUG() 文本**；异常路径 `ArchSec.c:45`（ArmPlatformPkg/Sec）是**裸 `SerialPortWrite`，无宏门控** ⇒ 10-05 的屏上异常块就是这条链打出来的。RELEASE 下它仍然活着。

### F-V2 推论（结构性，非新实验）
A2 交棒后全静默 ⇒ 三种位置，均可由本轮备料区分：
| 死点 | 现象（上机判读） |
|---|---|
| shim 未执行（= 根本没交棒） | 无 M1 色条 + fastboot USB 不掉线 |
| 死在 shim 拷贝/cache 维护 | 有 M1（红），无 M2（绿）/M3（蓝） |
| 死在 UEFI 入口~SEC 异常处理器生效前 | M1/M2/M3 全有，无文字 |
| 活过 SEC | 屏上应出现 DEBUG/异常文字（10-05 已证该链路通） |

---

## §2 通道 1：屏上出字（推荐主通道）

### 已出备料（编译验证 rc=0）
`patches/uefi/20261031-vis/0002-bootshim-framebuffer-milestone-markers.patch`
（基于 0001 cachefix 之上的叠加 diff，`patch --dry-run` 验证 apply 干净。）

- 产物：`reports/artifacts/uefi-vis-20261031/BootShim-vis-cachefix.bin`（**384 B**，sha256 `863baa95…9d15703`）；
  无 FB 宏时为纯 cachefix 160 B 等价物（`BootShim-vis.bin` 336 B 为无 0001 的纯 marker 版）。
- 编译验证：`clang --target=aarch64-linux-gnu -c BootShim.S … -DFB_BASE=0xFC800000 -DFB_WIDTH=1904` **rc=0**；
  反汇编含 `d50b7e25`(dc civac) + `d508751f`(ic iallu)（0001 语义保留）+ 4 处 `str w23,[x20],#4` 色条循环。
- 里程碑色（32bpp xrgb，顶行 16×16 px 条）：**M1 红=shim 已执行；M2 绿=拷贝完成；M3 蓝=cache 维护完、即将 br 进 UEFI；MD 黄=落入 _Dead（不应出现）**。
- 假设声明（未证实）：fb 在 shim 时刻仍是 32bpp、stride=1904×4、且 ABL 留下的内容可见。此三假设均未上机验证过（XBL/ABL→Linux 的 fb 布局有 Linux 侧证据，但 shim 时刻的 fb 状态未取证）。

### 上机判据（给父 agent）
见 §5 实验单 R1。**无论 shim 死在哪，M1–M3 至少区分出 4 种死法**，这是当前唯一能把「UEFI 早期死亡」切开的零焊接手段。

### 反证/风险
- 若 shim 时刻 fb 被 ABL 关显示（DSI 未续供电），色条写了也看不见 → 判读退化为「全无色条」，需与 USB 掉线判据（PITFALLS #387）联合解读。
- 色条写在 fb 起始 4 px 行，安全（不碰 `Display Reserved` 尾部 BootShim 自身区域；`0xFC800000+4 MiB` 远小于 region 0x2B00000）。

---

## §3 通道 2：内存落盘（PStore/InMemory）

- **已证不可直接用**：`InMemorySerialPortLib.c:39` `LocateMemoryMapAreaByName("PStore", &PStore)`；本机 `PlatformMemoryMapLib-lenovo-y700g4.c` **全 70 行内无 `PStore` 条目**（grep 实测 0 命中）⇒ 该库在本机 map 下 `LocateMemoryMapAreaByName` 必失败（返回错误，PStore.Address=0）⇒ 写入会打空指针。
- **最小启用条件（若走此路）**：PlatformMemoryMapLib 加一行 `{ "PStore", <addr>, 0x40000, Reserv, … }`，选一块 Linux 侧 `reserved-memory`/ramoops 之外的空 RAM；Linux 侧用 `/dev/mem` 偏移读取。代价：改 map + 重建 + Linux 侧读取脚本，且**仍受 §1 同一"死点"限制**（死在 SerialPortLib 初始化之前则无日志）。
- **与 ramoops 的关系**：本机 DTS 缺 `record-size`（既有报告已录）⇒ Linux ramoops 现状不可用；本通道是"手工 ramoops"，绕开 pstore 驱动。**优先级低于通道 1**（通道 1 是实时观测，本通道是事后取证），但可与通道 1 并存（两个 SerialPortLib 不能同时是 SerialPortLib——只能选 FrameBufferInMemorySerialPortLib 组合，`Andromeda.dsc.inc:198` 即该组合）。

---

## §4 通道 3/4：USB ACM 与硬件 UART（均不推荐本轮）

### 通道 3 USB 串口/ACM
- 树内 grep `UsbSerial|UsbFnSerial|ACM` 于本机设备包：**0 命中**（`UsbfnDwc3Dxe` 在 APRIORI:135 编入，但只是 USB function 控制器栈，无 serial 类客户端）。
- 上游 WOA-Project org code search：`UsbFnSerial` **total_count=0**（gh api，2026-10-31）；`mu_wide_platforms` 仓内无 UsbSerialDxe。
- issue #12 上游原话（`issuecomment-6487815074`，2026-10-29）："你要是没有办法把屏幕拍给AI调试，就去弄个UEFI的USB ACM Gadget" —— 上游只是方向性建议，**未提供同 SoC 先例**。
- 代价评估：自写 USB ACM function 驱动（DWC3 peripheral + USB function protocol + ACM 描述符），百行级新 C 代码 + 无同 SoC 参考 ⇒ **不推荐本轮**。若屏上通道（§2）被证伪再回来做。

### 通道 4 硬件 UART
- 树内有现成 `QcomGeniSerialPortLib`（`Andromeda.dsc.inc:207` 分支，`USE_UART_GENI_FOR_SERIAL_OUTPUT=1` 即启用），基址 PCD `PcdUartSerialBase` 默认 `0x98C000`（AndromedaPkg.dec:111）；本机 `PcdsFixedAtBuild.dsc.inc` **未覆盖** ⇒ 用默认值是否对应本机 debug UART 未知（**未证实**）。
- 硬件侧：TB322FC 公开资料中**无 UART 测试点/焊盘证据**（web 搜索无命中；XBL 侧 `boot_logger_uart.c` 字符串证明 XBL 具备 UART 日志能力，但**无本机启用的直接证据**）。
- 结论：软件开关是现成的（改 2 行 dsc），**卡点是物理访问**（拆机+找飞线/焊接），本 lane 无证据、无设备权限，**不深究**。

---

## §5 上机实验单（给父 agent；全部零写盘，每发判据 = PITFALLS #387 USB 掉线）

> R1（唯一必做）：
> 1. `cd build/uefi-woa-prep/repos/7-mu-lenovo && patch -p1 < patches…/0001-… && cd BootShim && patch -p0 < patches…/0002-…`（或直接用已编译产物）
> 2. `clang --target=aarch64-linux-gnu -c BootShim.S -o BootShim.elf -DUEFI_BASE=0xFF300000 -DUEFI_SIZE=0x00400000 -DFB_BASE=0xFC800000 -DFB_WIDTH=1904 && llvm-objcopy -O binary BootShim.elf BootShim.bin`（rc 必须 0；产物 384 B）
> 3. 按 `uefi-swap-x1x2-20261031.md` §4 段一流程重建 A2 同基座载荷（cachefix shim + 厂商 UFSDxe `00ae059f`），`--base 0x10000000` repack
> 4. `fastboot boot`，手机摄像头同步录像；判读表 = §1 F-V2 四行。
> 5. 回退：`fastboot set_active b && fastboot reboot`（若槽被标 unbootable）。

## §6 未证实清单
1. shim 时刻 fb 是否仍可见（32bpp/stride/显示未关）——**未证实**，只能上机判。
2. `QcomGeniSerialPortLib` 默认 PCD 0x98C000 是否对应本机 debug UART —— **未证实**。
3. TB322FC 是否有可借用的 UART 触点（USB/耳机孔/电池触点）—— **无公开证据**。
4. 上游 issue #12 自 10-29 后**无新评论**（gh api 实测，last=2026-10-29T04:19:30Z）⇒ 无需回帖。
5. 本轮备料 shim 与 `PatchedBinaries` 槽位组合的 FV 内 sha 一致性 —— 由父 agent 按既有流程逐枚核对（本 lane 不动构建树工作树，构建树已还原干净）。

## §7 附：全量包核对（用户新下载 /home/xuqianhui/文档/TB322FC_15.10.259）
- `uefi.elf` sha256 `fc68d2f9…3515c7` = **与 10-24 已分析件逐字节相同** ⇒ UEFI 侧取证无需重跑。
- 增量价值：`xbl_s.melf`（3.5 MiB）含 `boot_logger_uart.c`/`boot_logger_ram.c`/`logs_to_media.c` 字符串 ⇒ XBL 具备 UART/RAM/媒体三路日志；`xbl_config.elf` 含多组 `top_qup*_se*_uart_{active,sleep}` pinctrl 节点名 ⇒ QUP UART SE 在板级配置中存在（哪一个是 debug 口仍**未证实**）。
