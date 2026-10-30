# UEFI 线合并总账（截至 2026-10-30，含 10-29 全部结论）

> **性质**：纯只读盘点 + 结论合并。本次**未接触设备**（无 ssh/fastboot/adb）、**未构建**、**未联网**、**未改**
> `TASKS`/`DEVICE`/`INDEX`/`PITFALLS`/`versions`/`README`、**未提交 git**、未发邮件。
> **用途**：用户下一步要**直接构建并上机**，故本文件只做「事实 + 证据 + 资产」三段可执行收敛；
> 执行步骤与判据在配套的 **`reports/uefi-testplan-20261030.md`**（执行单）。
> **证据等级词**：`已证` = 有命令/日志/反汇编原文；`未证实` = 只有推断或上游口头；`未上机` = 有产物无实测。
> **路线状态不变**：`TASKS/README.md` §4 N1「维持搁置」、§5 Q25「维持搁置」——本文件**不重开可行性论证**。

---

## §0 一页结论（数字先行）

| 项 | 数字 |
|---|---|
| 本文件覆盖的报告 | **16** 份 `reports/uefi-*.md`（10-21 → 10-30）+ 3 份 `archive/topics/UEFI-*` |
| 证据目录 | **6** 个（`reports/artifacts/uefi-{built,dxe}-20261024`、`visibility-20261026`、`v0-20261027`、`e0e1-20261028`、`issue12-20261029`） |
| 可直接上机的镜像 | **9** 枚（N/A/C/A2/N2/A2-v0/N2-v0/E0/E1），**全部 sha256 已复算一致** |
| **真正「按 #418 口径可直接交棒」的镜像** | **0 枚** —— 现存 9 枚里 4 枚 v0 的 `kernel_addr=0x8000`，另 5 枚是 header v3（本机 ABL 静默忽略） |
| 已上机过的 UEFI 镜像 | **4 发**：10-05 CI 件、10-24 A repack、10-26 A2 repack（`--base 0x10000000`）、10-26 N2-v0（同一会话内 A2 交棒、N2 未交棒 ⇒ B10） |
| 已确证事实 | **27** 条（§2，每条带报告 §号 / file:line） |
| 未证/阻塞 | **10** 条（§3），其中 **3 条卡上机、4 条卡静态取证、3 条卡变量未定** |
| 可复用资产 | **44** 项（§5，镜像/固件/二进制/工具链/脚本/参考件/备份） |
| 主机侧构建树 | `build/uefi-woa-prep` **8.2 GiB 在盘**（其中 `repos/7-mu-lenovo` 5.6 GiB，HEAD `6b6ac42a`），**可直接复用** |
| 上游 issue #12 | **OPEN**，7 条评论；我方定稿 `6487769609`（6 227 字符）**已发**；上游 `6487815074` 回「系统版本问题 + 用 USB ACM Gadget 调」 |

**一句话**：UEFI 这条线的**机制链已全部打通到「能构建、能交棒、能亮屏（10-05 已证）」**，
剩下的唯一硬阻塞是 **UFS 初始化**（两层：`0x402`→`GPTListenerReadSectors` 的 `ctx+4` 解引用 + `UFS.c+2326` 的 `UFSSmmuConfig`），
而**当前没有早期可见性把这两层分开**。⇒ 上机的第一目标**不是修 UFS**，而是**先拿回亮屏/出字**（E0/E1 + `--base 0x10000000` 重打包）。

---

## §1 时间线（一页可扫）

| 日期 | 做了什么 | 结论 | 证据 |
|---|---|---|---|
| **10-05** | 首轮 bring-up：CI 件 `lenovo-y700g4_NOSB.img`（v3）`fastboot boot`；A–G 实验矩阵（UFSDxe/ClockDxe/多线程） | **壳机制成立、能进 BDS、屏上出 EDK2 同步异常文字**（= 亮屏已证）；UFS 初始化不通（`UFS.c+2326`）⇒ 暂缓路线 A，转路线 C + 发上游 | `archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md` §4/§5；`UEFI-RESOURCES-2026-10-05.md`；`UEFI-UFS-UPSTREAM-ASK-2026-10-05.md` |
| **10-09** | 上游首答 | 「firmware version related，需 UFSDxe 专用补丁」 | `UEFI-UFS-UPSTREAM-ASK-2026-10-05.md` §回复；`uefi-closeout-20261029.md` §1 |
| **10-21** | 复启评估（资产是否在盘、阻塞分层、替代方案对比） | **不建议重启**：`0x402` 首次静态定位 + `UFS.c+2326` 是**独立第二故障**⇒「至少两层」；kexec 已覆盖收益；资产 2.3 G 全丢 | `uefi-restart-20261021.md` §0/§A.2/§C/§D |
| **10-24 日间** | 资源包（6 仓 2.0 G）+ 工具链；`ffs-extract.py` 修 DataOffset bug | `uefi.elf` 解出内嵌 FV **4 247 560 B / 59 DXE 模块**，厂商 `UFSDxe` = `fa561bf1…` 151 552 B；「厂商 DXE 只在 XBL」作废 | `uefi-woa-prep-20261024.md` §2/§5；`uefi-dxe-20261024/` |
| **10-24 午后** | 「运行期表提供者」溯源 | `0x89a4`=UefiBootServicesTableLib 构造、`0x6cc8`=`gBS->AllocatePool` ⇒ **不存在运行期表**；真实依赖 = NpaDxe/ScmDxe/HWIODxe 的 `LocateProtocol` | `uefi-runtime-table-provider-20261024.md` §0/§1/§2 |
| **10-24 晚** | 构建 N（纯 Mu）/A（厂商 UFSDxe）/C（+厂商 RmVmDxe）；首次上机 | 构建 60 s、增量 14–15 s、**确定性**（C 两遍同 sha）；**v3 header 本机 ABL 静默忽略**（`Booting OKAY` 但 fastboot 仍应答）→ 同载荷 repack v0 **真交棒**后早死；`logfs` 可读但崩溃那发不落盘 | `uefi-experiment-build-20261024.md` §R2.3/§R3/§R3.1；`uefi-boot-A-attempt-20261024.md` §0/§2/§3/§4 |
| **10-25** | （旁线）Gunyah 终局裁决 = 不做 | 与 UEFI 解耦 | `reports/gunyah-decision-20261025.md`；`TASKS` §4 N2 |
| **10-26** | 可见性补丁 + A2/N2 重建 + 迁移交界面裁决 | BootShim 补 `dc civac/dsb/ic iallu/dsb/isb`（`patches/uefi/0001`）；**UEFI 不阻塞迁移**（零耦合），留 6 项复启保留清单；晚 19:18 上机 N2-v0 → **交棒后 60 s 全静默、82 s 回落 stock Android** ⇒ J1 未达成 | `uefi-visibility-20261026.md` §1/§2；`uefi-migration-interface-20261026.md` §0/§4/§5；`uefi-n2-v0-attempt-20261026.md` §0 |
| **10-26 晚（复盘）** | v0 repack 参数普查 | **v0 的 `--base` 必须 `0x10000000`（`kernel_addr=0x10008000`）**；`--base 0x0`（`0x8000`）会被 ABL `Booting OKAY` 后静默不交棒；同 header/base 下 A2 交棒、N2 不交棒 ⇒ handoff 还有未识别条件 | `PITFALLS` #418 / `PITFALLS/sessions/98-UEFI-v0-repack必须base-0x10000000.md` |
| **10-27** | 对照实验复核 + ABL 日志通道 | 「用 `Droid-VM/edk2-gunyah` 做对照」**作废**（它是 crosvm guest 固件，不能裸机 `fastboot boot`）；`UEFI_BASE=0xFF300000` 在 ABL RAM 表可用（`0x500000`）；ABL 日志每次启动重写 ⇒ 救不了失败那发 | `uefi-control-experiment-20261027.md` §0/§1/§2/§3 |
| **10-28** | E0/E1/E2 复现件重制 + 同芯片平板回挖 + issue #12 回帖（初稿已发） | E0 `987bcde9…`/E1 `1ae201c2…` 已构建（**均未上机**）；E0 口径 = BootShim **无** cache 维护；**E2 tiny DXE 不需要**（dodge 二进制已覆盖 sleep→wakeup）；同 SoC 已证亮屏的是 **dodge/pagani 两台手机**，平板**未证实**；**10-05 亮屏原证找回** ⇒ 推翻「可见性依赖 GOP」 | `uefi-visibility-rebuild-20261028.md` §0/§2.3/§4；`uefi-samechip-tablet-display-20261028.md` §0/§2.5/§6.1；`uefi-issue12-reply-draft-20261028.md` |
| **10-29** | issue #12 定稿并**发出**；收口核对 | 我方 `6487769609`（6 227 字符，`draft==posted` True）；上游 3 分钟后回 `6487815074`：「系统版本问题 / 别用劣质 token 瞎猜 / 去弄个 UEFI USB ACM Gadget」；Q2（SMMU 层）**未答** | `uefi-issue12-reply-final-draft-20261029.md` §2；`uefi-closeout-20261029.md` §0/§1 |
| **10-30** | 补证 M1/M3/M4 + 产物复核 | `0x402` 语义**再收紧** = `GPTListenerReadSectors`（`0x403`=写扇区）；`ctx+4` **生产者仍未定位到指令级**；dodge 三补丁点语义落实（第三段 = UFS IOMMU 整函数 stub）；本机配置表 **62 条**（不是 dodge 的 41 条）；E0/E1 payload 位于 **0x1000**、sha 全对 | `uefi-recovery-20261030.md` §0–§4 |

> **口径提醒**：上表 10-24「v0 repack」当时的 `--base` 记为 `0x0`，10-26 复盘证明**实际生效的是默认 `0x10000000`**（`PITFALLS` #418）。
> 现存 `reports/artifacts/uefi-*/…-v0.img` 的 `kernel_addr` 实测都是 **`0x8000`**（本次复算，见 §3 B4）⇒ **不能照抄直接上机**。

---

## §2 已确证事实清单（27 条，每条带证据指针）

> 统一约定：UFSDxe 的 `RVA == 文件偏移`（`.text` 起 `0x1000`，`uefi-issue12-reply-final-draft-20261029.md` §7 实测），故下文「RVA/偏移」可直读文件。

### A. UFSDxe 崩溃链（`0x402` 一族）

| # | 事实 | 证据 |
|---|---|---|
| **F1** | **`0x402` = GPT 读扇区请求**（不是 config tag，也不是「运行期注册表条目类型字段」）。`0x12e30` 是回调派发器：要求 `len>=0x1c`，取 `w8=[ctx]-0x401`，`w8<=3` 时走 4 项字节跳转表 `0x1e2b8`（字节 `00 07 0a 0d`）⇒ `0x401→0x12e74`、**`0x402→0x12e90→bl 0x13120`**、`0x403→0x12e9c`、`0x404→0x12ea8` | `uefi-issue12-reply-final-draft-20261029.md` §0-1、§7 R1/R2；`uefi-recovery-20261030.md` §1.2 |
| **F2** | **`0x403` = GPT 写扇区**。函数身份由字符串锚定：`0x13120`=`GPTListenerReadSectors`（串 RVA `0x1e325`）、`0x13314`=`GPTListenerWriteSectors`（串 RVA `0x1e363`）、`0x12bd8`=`GPTListenerAllocMem`、`0x12cf8`=`GPTListenerInit`、`0x12e30`=派发器（跳转表后紧跟 `"GPTListener.c"` @`0x1e2bc`） | `uefi-recovery-20261030.md` §1.2 表 |
| **F3** | **崩溃指令 = `0x13224 ldr x9,[x0,#8]`**，`x0` 由 `u32[copy+4..7]` 零扩展（`0x13200..0x13218`），值 `0xD6ABB030` ⇒ FAR `0xD6ABB038`；`copy` 是 `AllocatePool(EfiBootServicesData, u32[ctx+0x10]+u32[ctx+0x14])` + `CopyMemWrapper` 的副本，且先校验 `u32[copy+0]==0x402`（`0x131f4`） | `uefi-issue12-reply-final-draft-20261029.md` §0-2/§7 R3 |
| **F4** | **该路径上不存在任何配置表/protocol 查表**：`0x13120..0x13234` 全函数只有 2 个 `bl` —— `0x6cc8`（`[gBS+0x40]`=AllocatePool，type=4）与 `0x779c`（`CopyMemWrapper`，assert 串 `CopyMemWrapper.c` @`0x1cbb1`） | 同 F3（§0-3/§7 R3/R4） |
| **F5** | **`0x12e30` 无任何直接调用点**：全 `.text` 28 171 条指令里 `bl/b 0x12e30` = **0 条**；地址只在 `0x12de8/0x12df0` 被物化成回调指针，经 `GPTListenerInit` 用 `w1=0x2001`、`w5=0x40001000` 注册到外部协议对象（`gBS->LocateProtocol`，GUID `8d10ed77-2485-4b8b-9d2e-34987aecb9c1`，在 `vendor-dxe-fv.bin` 命中 **8 处**，邻近串落在 **`ScmDxe`**，含 `"Listener Callback function failed. id 0x%x"`） | `uefi-recovery-20261030.md` §1.1/§1.2 |
| **F6** | **`UFS.c+2326` 是独立第二故障**：`mov w1,#0x916`(2326) 全 `.text` 唯一一处 = `0x42f4`，紧邻 `"UFS.c"`(RVA `0x1b438`)；断言载荷 RVA `0x1c14e` = `!EFI_ERROR (((RETURN_STATUS)(0x8000000000000000ULL \| (7))))` ⇒ `EFI_DEVICE_ERROR`；守卫串 `UFSSmmuConfig failed` @RVA `0x1c073`，其后 `0x4310` 打印、`0x4324-0x4338` 再打 `UFS.c+2331` 第二条 ASSERT | `uefi-restart-20261021.md` §A.2；`uefi-issue12-reply-final-draft-20261029.md` §0-5/§3 |

### B. 补丁面（dodge / dodge-patched / E1）

| # | 事实 | 证据 |
|---|---|---|
| **F7** | **「三补丁点」的对象 = 厂商件 vs 仓库 `PatchedBinaries`**：`vendor-UFSDxe.efi`（`fa561bf1…878d2`，151 552 B）→ `PatchedBinaries/UFSDxe.efi`（`00ae059f…80ac1`，151 552 B），`cmp -l` = **38 B**，分 4 组：`0xa998`(8 B)、`0x114c4`(16 B)、`0x1b080`(8 B)、`0x23d21..0x23d3b`(6 B build 路径串)。本次复算逐字节一致 | `uefi-recovery-20261030.md` §2 表；本次 `cmp -l` 复算（38 行） |
| **F8** | **第三段 `0x1b080` = 把 `EnableUfsIOC`（UFS IOMMU/SMMU 域创建+配置+附着）整函数 stub 成 `mov w0,#0; ret`**。该函数字符串含 `EnableUfsIOC`、`UFS IOMMU LocateProtocol failed 0x%x`、`UFS IOMMU domain create/configure/attach failed`；唯一调用者 `0xb358`（薄包装 `0xb350`：成功返 0、失败返 `-100`），由驱动入口 `0x3fe8` 在 `0x4290/0x42a0` 调用，前置键 = `UfsSmmuConfigForOtherBootDev`（串 `0x1c056`）⇒ **dodge 的第三处补丁正好把 `UFSSmmuConfig` 变成恒成功**，与 `UFS.c+2326` 同层 | `uefi-recovery-20261030.md` §2 |
| **F9** | **第一段 `0xa998` 与第二段 `0x114c4` 属 UIC/PHY 层**：`0xa998` 所在函数 `0xa910` 内串含 UIC/链路初始化链；`0x114c4` 所在函数 `0x11370` 串含 `UFS PHY Init Error`/`EOM Init Error`/`2 Lane Init Error`/`PHY Tune Table Error`/`UFS_UIC_ERROR_REG_DUMP`，补丁把 `cbz w0,0x114dc` 换成「丢弃返回码强制继续」 | 同 F8（§2 表） |
| **F10** | **dodge 未触碰崩溃函数**：`0x13120..0x13234` 在 38 B 差异里 **0 命中** ⇒ 10-05 的 `PC=UFSDxe+0x13224` 崩溃发生在**原版代码**里，不是补丁改出来的 | `uefi-recovery-20261030.md` §2；`uefi-restart-20261021.md` §A.2 |
| **F11** | **另一对二进制（`ext-repos/mu-dodge`）的补丁语义不同**：`UFSDxe.efi`（`0b32d924…`，151 552 B）→ `UFSDxe.patched.efi`（`e76b555f…`，155 648 B）；2026-10-28 反汇编结论 = `.text` 只差 **12 B**、`.data`/`.reloc` 各 0，另新增 **4 KiB `.extra` 节**（`RVA 0x24000`，`SizeOfImage` 151 552→155 648）：① RVA `0x0a998` 把 UFS **Sleep 调用换成 Wakeup**（`mov w1,#1; bl 0xb0d0`，新函数把 UIC 命令字 `0x28c/0x28b`→**`0xd0`**）；② RVA `0x1191c` `bl 0x10284`→`b 0x24000`（**gear check 之前强制 link 唤醒**） | `uefi-visibility-rebuild-20261028.md` §4.1 |
| **F12** | **E1 里装进去的不是仓库 `PatchedBinaries`**：`reports/artifacts/uefi-e0e1-20261028/UFSDxe.patched.efi` = `e76b555f…3c85ef`（155 648 B），与 `00ae059f…`（151 552 B）**`cmp -l` 45 305 B 不同**（本次复算）；E1 FD 内实抽 PE32 section = `bc336c04…f243d`（155 652 B，前 4 B 是 `EFI_SECTION_PE32` 头，`sec[4:] == e76b555f…` 逐字节 True） | `uefi-recovery-20261030.md` §2.1/§4.1；`uefi-visibility-rebuild-20261028.md` §3.3；本次复算 |

### C. 配置表 / 平台

| # | 事实 | 证据 |
|---|---|---|
| **F13** | **本机（elden）配置表 = 62 条启用**（另有 8 条被 `//` 注释，共 70 条字面量），文件 `Platforms/PakalaPkg/Device/lenovo-y700g4/Library/PlatformConfigurationMapLib/PlatformConfigurationMapLib.c`（72 行，`0ee7e304…355dcd`）；`UfsSmmuConfigForOtherBootDev` 在第 **62** 行、`EnableUfsIOC` 在第 **30** 行，各 1 条 | `uefi-recovery-20261030.md` §3/§4 |
| **F14** | **`dodgePkg` 那份是 41 条、且不是本机平台**（OnePlus dodge，58 行）；10-29 回帖/早期报告引用的对象需按此更正。两份表**全是命名键**（`EnableShell`/`NumCpus`/`EnableUfsIOC` 之类），**无 `0x402` 这类数值键** ⇒ 「`0x402` 不是平台配置项」在本机表上同样成立 | `uefi-recovery-20261030.md` §3；`uefi-restart-20261021.md` §A.2 |
| **F15** | **`UEFI_BASE=0xFF300000`、`UEFI_SIZE=0x400000`**（BootShim 头 `.quad`），ABL `Final RAM Partitions` 明列 `Add Base 0xFF300000 / Available Length 0x500000`（5 MiB）⇒ 装载地址不是保留区/设备区；该值与 Kaanapali `build_cfg/{sm8750,sm8850}.json` 相同，非本机魔数 | `uefi-boot-A-attempt-20261024.md` §1；`uefi-control-experiment-20261027.md` §2 |
| **F16** | **本机显示参数不构成缺口**：`SimpleFbDxe`（254 行源码，BSD-2-Clause-Patent）只做 4 步 —— 按名字取内存映射 `Display Reserved`（本机 `0xFC800000`/`0x02B00000`=43 MiB）+ 读 `PcdMipiFrameBufferWidth/Height`（本机 **1904×3040**）+ `ZeroMem` + 装 GOP；**不初始化任何 DSI/panel/PHY/clock**。5 个 SM8750 设备包此段逐字节相同（`DisplayDxe`/`DisplayCallerDxe` 全被注释） | `uefi-samechip-tablet-display-20261028.md` §2.1/§2.3/§2.4 |
| **F17** | **显示在 APRIORI 上早于/独立于 UFS**：`SimpleFbDxe.inf` depex 只有 `gEfiCpuArchProtocolGuid`；APRIORI 行号 UFSDxe=**76**、FontDxe=119、BdsDxe=120、SimpleFbDxe=**165**、GraphicsConsoleDxe=**183** ⇒ 「点亮/清屏」只到 165、「画字」到 183，均**不依赖 UFS** | 同 F16（§2.4 表） |

### D. 可见性与上机现象

| # | 事实 | 证据 |
|---|---|---|
| **F18** | **BootShim cache maintenance 补丁已存在并编译验证**：`patches/uefi/0001-bootshim-add-dc-civac-ic-iallu-before-entry.patch`（`198876ac…a5f8f`）在 `_CopyLoop` 后插入 `dc civac`（循环覆盖 `UEFI_SIZE`）→ `dsb sy` → `ic iallu` → `dsb sy` → `isb`；产物 `BootShim-cachefix.bin` 160 B `0c1bb4da…09ac57`，编码实测含 `d50b7e25`(dc civac)/`d508751f`(ic iallu) | `uefi-visibility-20261026.md` §1.3/§2；`patches/uefi/0001-*` |
| **F19** | **10-05 基线口径 = BootShim 不含 cache 维护**：`BootShim.bin` 112 B `054e114d…3b8945`，全 `.text` 12 条指令，`d50b7e25`/`d508751f` 命中 **0/0**（本次在构建树复核同 sha） | `uefi-visibility-rebuild-20261028.md` §2.3；本次 `sha256sum` |
| **F20** | **本机 UEFI 在 2026-10-05 确实亮过屏**：屏上出现 EDK2 DxeCore 同步异常文字块并**反复刷屏**（会话记录同时出现 `Synchronous Exception at 0x000000001264D224` + `UFSDxe.dl1` 回溯 与 `0xD2B20224` + `recursive exception`），用户当时反馈「字号太小/看不清」；PC 落在 DXE Heap（`0xB90C0000–0xD65C0000`） | `uefi-samechip-tablet-display-20261028.md` §2.5/§3.2（引 `.pi/sessions/2026-10-05T{02-47-29,06-05-48}*.jsonl`） |
| **F21** | **早期可见性通道 = `FrameBufferSerialPortLib` 直写 framebuffer**，由 `PakalaNoSb.dsc:31` 的 `USE_SCREEN_FOR_SERIAL_OUTPUT=1` 打开（`Pakala.dsc:31` 是 0）；E0 构建命令行逐字含 `-DUSE_SCREEN_FOR_SERIAL_OUTPUT=1 -DUSE_MEMORY_FOR_SERIAL_OUTPUT=0` 且编入 `FrameBufferSerialPortLib.inf` ⇒ 「屏幕输出依赖 GOP」这一旧结论**部分推翻** | `uefi-visibility-rebuild-20261028.md` §1.4/§6.4；`uefi-samechip-tablet-display-20261028.md` §6.1 |
| **F22** | **header v3 被本机 ABL 静默忽略**：`Booting OKAY [10.1 s]` 后设备留在 bootloader（屏是联想 logo）、`fastboot getvar` 仍 0.004 s 应答（USB 同设备号 064 未重枚举）⇒ 载荷从未执行。**真交棒判据 = USB 掉线**（`Booting FAILED (usb_read failed: No such device)`） | `uefi-boot-A-attempt-20261024.md` §2/§3；`PITFALLS` #387 |
| **F23** | **v0 repack 的 `--base` 必须是 `0x10000000`**（`kernel_addr=0x10008000`）：`--base 0x0`（`0x8000`）会 `Booting OKAY` 但静默不交棒。本次复算：现存 4 枚 v0 镜像 `kernel_addr` 全部还是 **`0x8000`** | `PITFALLS` #418 / `sessions/98-*`；本次 `struct.unpack` 复算 |
| **F24** | **失败的 `fastboot boot` 会把当前槽标 `slot-unbootable:b=yes` 并切 `current-slot=a`**（`slot-retry-count:b=6` 不变）；恢复 = `fastboot set_active b`（写 misc，非分区镜像）+ `fastboot reboot`，实测 20–25 s 回 Linux | `uefi-boot-A-attempt-20261024.md` §5；`uefi-n2-v0-attempt-20261026.md` §4；`PITFALLS` #387 |
| **F25** | **补 cache 维护不足以救活**：10-26 N2-v0 交棒后 **60 s USB/fastboot/SSH 全静默**、**~82 s 回落 stock Android 槽 a**、屏幕全程联想 logo（用户目视 19:18:56–19:20:18）⇒ J1（可见性）未达成；与 10-24（无补丁）同一现象，唯一差别是回落耗时 82 s vs 25 s（不足以当证据） | `uefi-n2-v0-attempt-20261026.md` §0/§2 |

### E. 构建链（两条硬事实）

| # | 事实 | 证据 |
|---|---|---|
| **F26** | **`stuart_build` 在本机不通**：报 `CRITICAL - Build failed` 4 s 结束，真错误被 504 行 `warning: Unrecognized content` 噪声淹没；根因 = `Trim` 不在 PATH（`make: Trim: 没有那个文件或目录` ⇒ `error 7000` ⇒ `error F002`）。绕过 = 直接调 `MU_BASECORE/BaseTools/BinWrappers/PosixLike/build` 并把该目录加进 `PATH`。另外 **`-n 26` 会触发 clang SIGSEGV**（`NetworkPkg/UefiPxeBcDxe/PxeBcDhcp6.c`，exit 139），**`-n 12` 同源码一次过** | `uefi-visibility-rebuild-20261028.md` §1.3/§6.2 |
| **F27** | **CI 口径构建命令 = `./build_uefi.py -d lenovo-y700g4 -t RELEASE`**（`stuart_build … --TARGET_DEVICE` **不是**合法参数）；实测 rc=0 / 首构 60 s / 增量 14–15 s；同配置两遍 `.img` sha 相同（确定性成立）；`.img` = `gzip(BootShim.bin ‖ FV/SM8750_EFI.fd)` + `mkbootimg v3`（`PostBuild.py` 写死 v3 ⇒ 上机必须 repack v0） | `uefi-experiment-build-20261024.md` §R2.3/§R3/§R3.1 |

---

## §3 未证 / 阻塞项（10 条）

| # | 项 | 状态 | 为什么卡住 / 下一步是什么 | 证据 |
|---|---|---|---|---|
| **B1** | **M2：`0xD6ABB030` 是否落在 Mu `MemMap` 内** | **需上机** | 只有 `FAR=0xD6ABB038` 一条间接证据；主机侧无该次启动的 `MemMap`/`gEfiDebugImageInfoTableGuid` 转储，缺输入无法反算。**上机第一步（能出字后）= Shell `memmap` 或导出 debug image info** | `uefi-recovery-20261030.md` §5；`uefi-issue12-reply-final-draft-20261029.md` §0-8（L30） |
| **B2** | **L29：谁写 `ctx+4`** | **未证实（未到指令级）** | 已证 `0x12e30` 无直接调用点（F5），请求缓冲不由 UFSDxe 生成（模块内 `0x402` 立即数只有 1 处且是日志位测试）；发起者在 **SCM/TZ 监听分发**路径，但 `vendor-dxe-fv.bin` 模块边界**未解析成功**（无裸 `MZ`/`VZ`，疑压缩段）⇒ 未找到那条 `str` | `uefi-recovery-20261030.md` §1.3 |
| **B3** | **E1 二进制身份不一致** | **未证实** | E1 装的是 `e76b555f…`（**155 648 B**），仓库 `PatchedBinaries` 是 `00ae059f…`（**151 552 B**），两者长度差 4 096 B 且 `cmp -l` 有 **45 305** 个字节位置不同（F12）⇒ **E1 的成败不能解释为「dodge 三补丁」的成败**。上机前必须记下所用 UFSDxe 的 sha | `uefi-recovery-20261030.md` §2.1/§6 |
| **B4** | **E0/E1 未上机，且现存 v0 镜像 `kernel_addr=0x8000` 违反 `PITFALLS` #418** | **阻塞（可直接解）** | 本次复算：`E0/E1/A2-v0/N2-v0` 均 `kernel_addr=0x8000` ⇒ 按 #418 会被 ABL「`Booting OKAY` 后静默不交棒」。**必须先按 `--base 0x10000000` 重打包**（不改载荷，只改 header） | `PITFALLS` #418；本次 header 解析（见执行单 §2） |
| **B5** | **10-05 亮屏 vs 10-26 全静默的真正差异** | **未证实** | 收窄到 3 个候选：① v3 vs v0（**直接矛盾**：10-05 v3 真跳了，10-24/26 测得 v3 不跳）② CI 双跑（`WM_CI_BUILD=true` 同产 SB+NoSb）vs 本地 `-t RELEASE` 单跑 ③ BootShim `dc civac` 补丁（10-26 才加）。E0 已把 ③ 去掉，是判定该变量的现成件 | `uefi-visibility-rebuild-20261028.md` §6.1；`uefi-samechip-tablet-display-20261028.md` §2.5/§6.3 |
| **B6** | **本机 62 条配置表是否真被编进 E1 的 FD** | **未核** | 需构建或 FD 内符号解析；上机前不影响判断，只影响「配置是否齐」这一层的归因 | `uefi-recovery-20261030.md` §3（缺口） |
| **B7** | **UEFI 上线后 `simpledrm` 与 mdss 复位（Q28）共存行为** | **未验证** | UEFI 走 BDS→GRUB 会把 GOP framebuffer 交给内核 ⇒ 重新引入 `simple-framebuffer`；而本机 DTS 已刻意删除该项。外部仅有 Pengyu「splash 存在时 10/10 可用」口头证据（不同树，不能直套） | `uefi-migration-interface-20261026.md` §4 C4/C6、§6.5 |
| **B8** | **E2 tiny DXE（自写拉 link state）** | **无产物 / 风险未验** | 判断 = **不需要**（F11 的 dodge 补丁已覆盖 sleep→wakeup + gear check 前唤醒）；若要自写：~120–160 行 C、depex `gEfiCpuArchProtocolGuid`、需裸 MMIO `0x1D84000`（`gEdkiiUfsHostControllerProtocol` 由 UFSDxe 自己生产，拿不到），**写错 UIC 命令可致 UFS 链路不可恢复** | `uefi-visibility-rebuild-20261028.md` §4.2/§4.3；`uefi-recovery-20261030.md` §4.3 |
| **B9** | **FV 内的 `Panel_elden_nt36523_csot_3k_dsc_video_panel.xml` 是否被 ABL 使用** | **未证实** | 已证该 XML 在 FV 内（219 FFS 提取）；面板实际由 ABL 初始化，UEFI 侧只引用名字 | `uefi-samechip-tablet-display-20261028.md` §6.3 |
| **B10** | **handoff 稳定性：同 header/base 下 A2 交棒、N2 不交棒** | **未识别条件** | 10-26 同一 fastboot 会话里两者行为不同 ⇒ **不能把「交棒」当稳定判据**；每发都要用 USB 是否掉线判定，并预留回落时间 | `PITFALLS/sessions/98-UEFI-v0-repack必须base-0x10000000.md` §本轮结论 |

---

## §4 为什么这条线是「间接引导」而不是直接取代 ABL（一句话）

> **四代（TB322FC）的 UEFI 已被拆成 `uefi_a` + `imagefv_a` 两个独立分区、由 XBL 直接加载；`abl_a` 本体是 Qualcomm `LinuxLoader`，不扫 FAT、无 BDS/`SimpleFileSystem`/`Boot####` 逻辑（`uefivarstore` 里也检不到 `Boot####`/`BootOrder`）。**
> 所以路线 A 能做的只是「把一整份自建 UEFI 卷打包成 `boot.img` 的 kernel，让 ABL 当内核交棒」——多一层壳，**不是**替代 ABL；真替代（路线 B）要写 `uefi_a`/`imagefv_a`（a 槽 + EDL 兜底），这正是 `TASKS` §4 N1 判「搁置」的前提。
> 证据：`TASKS/README.md` §4 N1；`archive/topics/BOOTCHAIN-2026-10-05.md` §2.2–§2.4；`uefi-migration-interface-20261026.md` §1.1；`AGENTS.md`/`INDEX.md` 的 N1 裁决条目。

---

## §5 可复用资产清单（44 项，sha256 均为**本次或最近一次实测值**）

> 路径相对仓库根；`art/` = `reports/artifacts/`；`tree/` = `build/uefi-woa-prep/repos/7-mu-lenovo`。
> **“可用性”列**：`✅` = 文件在盘且 sha 一致；`⚠` = 在盘但需额外动作（重打包/换 header）；`⬜` = 仅记录、未归档。

### A. 可上机的 UEFI 镜像（9）

| # | 文件 | 尺寸 | sha256 | 可用性 |
|---|---|---|---|---|
| 1 | `art/uefi-built-20261024/lenovo-y700g4-A.img`（厂商 UFSDxe） | 2 445 312 | `e0d4a9041ab9787a5c4bbb833a24c6c1714534daeb4664df3c93d9d04346295a` | ⚠ header **v3**（#387，不交棒） |
| 2 | `…/lenovo-y700g4-C.img`（A + 厂商 RmVmDxe） | 2 441 216 | `dfa0c8b3e9fc1c04e8dfcb4bc4970130668e301f8b9f7bf8ae306130be5f0d29` | ⚠ v3 |
| 3 | `…/lenovo-y700g4-N.img`（纯 Mu 基线） | 2 441 216 | `ad4796a669cd038588feb98317f8bb82fdae35fedb4c66e5e42515b025179050` | ⚠ v3 |
| 4 | `art/uefi-visibility-20261026/lenovo-y700g4-A2.img`（cache 补丁 BootShim + 厂商 UFSDxe） | 2 441 216 | `251953b9db75521b7938808643e2fff3b8e29887cc2013eaab70a02517a4ebb6` | ⚠ v3 |
| 5 | `…/lenovo-y700g4-N2.img`（cache 补丁 + 纯 Mu） | 2 441 216 | `528702c67a37487177f2761832d2ae949f8042798a3e9dacbdd11e574a5b2f9f` | ⚠ v3 |
| 6 | `art/uefi-v0-20261027/lenovo-y700g4-A2-v0.img` | 2 445 312 | `2282953b490f4375d741b01351a838ef56de62331b394382472eef2144332b9b` | ⚠ `kernel_addr=0x8000`（#418） |
| 7 | `…/lenovo-y700g4-N2-v0.img`（**10-26 已上机过**） | 2 441 216 | `0cef239a03e4e0b7f507aab6afc4c7530ccf6679f431edb242fa4296bc988025` | ⚠ 同上 |
| 8 | `art/uefi-e0e1-20261028/lenovo-y700g4-E0-v0.img`（10-05 口径：shim 无 cache 维护） | 2 441 216 | `987bcde9bafc7ccfb244956acb805bd7fb3e4e7cbbad72dfbc4c5b5f327a16f2` | ⚠ 同上 |
| 9 | `…/lenovo-y700g4-E1-v0.img`（E0 + dodge `UFSDxe.patched.efi`） | 2 445 312 | `1ae201c2d518672dc2715e2553396c6bd1fbf13c7c4804fc0ee9ed1f74f96540` | ⚠ 同上 + 身份见 B3 |

### B. FD / BootShim / payload（9）

| # | 文件 | 尺寸 | sha256 | 说明 |
|---|---|---|---|---|
| 10 | `art/uefi-built-20261024/SM8750_EFI-A.fd` | 4 194 304 | `eb00db73f7e85a9d4471d2d3c1f0afc19b3cb6519eb7034ebfad874cae3c62a9` | = A2 的 fd |
| 11 | `…/SM8750_EFI-C.fd` | 4 194 304 | `560fcb93c931e39f8a33d895af05457de4e0de6e94696d274154545213a78063` | C（厂商 UFSDxe+RmVmDxe） |
| 12 | `…/SM8750_EFI-N.fd`（= `uefi-visibility-20261026/SM8750_EFI-N2.fd`） | 4 194 304 | `6d51c190086b4164a3fc90761dd44a2b166f5b612f76b643d8b6cbaac227e696` | 纯 Mu |
| 13 | `art/uefi-e0e1-20261028/SM8750_EFI-E1.fd` | 4 194 304 | `bde4831b280710829894635ad48c2ad25107a376089ef13aba81a4550cd6bea5` | 含 dodge patched UFSDxe |
| 14 | E0 的 fd（**未归档为独立文件**） | 4 194 304 | `5d60efd104eb5880dd6bc7e8769055d4c31eed9229073ec5e1e0229533c28ddf` | ⬜ 可从 E0 img gunzip 取回 |
| 15 | `tree/BootShim/BootShim.bin`（10-05/E0 基线，**无** cache 维护） | 112 | `054e114d431d52ff06f38084339a4709b0692bfc6846f0d58c2f4b40ed3b8945` | ✅ `d50b7e25` 命中 0 |
| 16 | `art/uefi-visibility-20261026/BootShim-cachefix.bin` | 160 | `0c1bb4daf0619be805ac0a1d9c601c5f61abab4342959aa92ba5c484bc09ac57` | ✅ 含 `dc civac`/`ic iallu` |
| 17 | `art/uefi-e0e1-20261028/e0-bootpayload.bin`（gzip） | 2 436 681 | `98511db91fc69a9f7112a10c9ec9dd2a7b3ae81c565a63161d99541dabcb7028` | ✅ |
| 18 | `…/e1-bootpayload.bin`（gzip） | 2 437 723 | `2a40bc9e02833a7fdf085153991ff40eb41c670002721180d28c60e5d2b32616` | ✅ |

### C. 固件/驱动二进制（10）

| # | 文件 | 尺寸 | sha256 | 说明 |
|---|---|---|---|---|
| 19 | `art/uefi-dxe-20261024/vendor-dxe-fv.bin`（从 `uefi.elf` 解出的厂商 DXE FV） | 4 247 560 | `657940ca74a667aaa518038f2d4bfe7de04205ca883574e0c46172df002962d9` | 59 个 DXE 模块 |
| 20 | `…/vendor-UFSDxe.efi`（**厂商件**） | 151 552 | `fa561bf11eb18f142b128f0335973f6c4a8d0241747ea581d5b3a56d601878d2` | GUID `0d35cd8e-97ea-4f9a-96af-0f0d89f76567` |
| 21 | `…/vendor-RmVmDxe.efi`（厂商） | 57 344 | `aed61cb16c2e884ade9f79b7b809cffd4777c308d7d4199b7a9f50a30dbb861f` | 会改 FDT（`/hypervisor/qcom,resource-manager-rpc`） |
| 22 | `…/modules.tsv`（59 模块清单） | 2 221 | — | GUID/名称对照 |
| 23 | `tree/Platforms/PakalaPkg/Device/lenovo-y700g4/Binaries/QcomPkg/Drivers/UFSDxe/UFSDxe.efi`（Mu **未打补丁**） | 151 552 | `dac620aca276e735361d8b747fe0218b6125eae004116391270f32a72e6ce750` | 与厂商件**只差 6 B**（build 路径串 `mp250526` vs `mp251201`：`0x23d21`、`0x23d30..33`、`0x23d3b`） |
| 24 | `tree/…/PatchedBinaries/UFSDxe.efi`（**Mu 补丁件**，= F7 的 patched 端） | 151 552 | `00ae059f5b4a95fbe85dc9eb4c6d991c4ea5037f330cc8d3206951680a280ac1` | 三补丁点（F7/F8/F9） |
| 25 | `/home/xuqianhui/ext-repos/mu-dodge/UFSDxe.efi`（dodge 原版） | 151 552 | `0b32d9244c945d8c4105142f1a8dafb02f7cc29d37cca6e7e1973465add41aac` | F11 的 orig 端 |
| 26 | `/home/xuqianhui/ext-repos/mu-dodge/UFSDxe.patched.efi`（dodge 补丁版） | 155 648 | `e76b555f7c855784cc03303ae1044c69b24f04f214a320a8e2ea101b4f3c85ef` | sleep→wakeup + `.extra` 4 KiB |
| 27 | `art/uefi-e0e1-20261028/UFSDxe.patched.efi` | 155 648 | 同 #26（逐字节） | E1 的输入件 |
| 28 | `…/E1-UFSDxe-in-FV-SEC2.pe32`（从 E1 FD **实抽**的 section） | 155 652 | `bc336c04a85748fc952a07b826b2f98ed9ccc9680ade3d6d3c6f28d2406f243d` | 前 4 B = section 头 |

### D. 补丁 / 工具 / 脚本 / 构建树（8）

| # | 资产 | 身份 | 用途 |
|---|---|---|---|
| 29 | `patches/uefi/0001-bootshim-add-dc-civac-ic-iallu-before-entry.patch` | `198876aceed8227ea972e15595e24afea271528ecaed93bcd2bee8d0d55a5f8f` | BootShim cache maintenance（`dc civac`→`dsb`→`ic iallu`→`dsb`→`isb`） |
| 30 | `build/uefi-woa-prep/tools/uefiextract`（NE A75） | `f1b8d112838adcf741c43dbd87f3dc61f06996239e9801ae62cf46ea1cd2485a` | FD/FV 结构浏览 |
| 31 | `build/uefi-woa-prep/tools/uefifind` | `0c1643e107a32580f3760c635ef1ba3145bf9178b977666869487fb15bd08a42` | FV 内查找 |
| 32 | `scripts/abl-log.sh` | `4981f8a124d072ee4a77aff3990cd42f8016fd32e68eedf648967d1cefde5a07` | 读 `logfs`/`UEFILOG1.TXT`（PBL→fastboot→RAM 表→`Start EBS`），**每次启动重写** |
| 33 | `scripts/mkbootimg.py` | `ea791a97ccaa1bc82b89a2752daf4779794ae7202c08cacbe8c044d2110e7684` | 重打包 v0（**必须** `--base 0x10000000`） |
| 34 | `scripts/ffs-extract.py` | `ba09676b53ffc5d1f67eff625bfbdb23ca587f0e556d45e52ffddd29ed1a227c` | FV→FFS→PE32 递归抽取（已修 DataOffset bug） |
| 35 | `scripts/grubfat-inspect.sh` | `693825623d5d4ae48c14898cef595f5d0f192cc9378c435cfdaac4738ab5ba92` | boot.img 结构自检（header/`_FVH`/PE 计数） |
| 36 | `build/uefi-woa-prep/repos/7-mu-lenovo`（**完整构建树**） | HEAD `6b6ac42a`（2026-10-05）、工作树 5.6 GiB、含 `Build/` 上次产物 | 可直接增量构建；详见执行单 |

### E. 参考件 / 原厂固件 / 备份件 / 设备通道（8）

| # | 资产 | 身份 | 用途 |
|---|---|---|---|
| 37 | `reference/uefi-samechip-20261028/`（11 文件） | `SimpleFbDxe.c/.inf`、`FrameBufferSerialPortLib.c`、`APRIORI-lenovo-y700g4.inc`、`PlatformMemoryMapLib-lenovo-y700g4.c`、`Pakala{,NoSb}.dsc`、`Andromeda.dsc.inc`、`sm8750_xiaomi_pad8p.yml`、Status SN8750 段、`NOTES-取证片段.md` | F16/F17/F21 的源码级依据 |
| 38 | `~/下载/tb322fc/` 原厂固件包 | `uefi.elf` 5 242 880 `fc68d2f9…3515c7`；`imagefv.elf` `30a0fc74…efbb84`；`abl.elf` `e7062378…e43885`；`tools.fv` `781e2403…51400c3`；另有 `NON-HLOS.bin`(367 001 600) 等 | 厂商 DXE 重抽、ABL 语义复核 |
| 39 | `backup/HA2EXB0E-16+512/gpt-20261025/{main0.bin,backup0.bin}` | 24 576 / 20 480 B；`52076e29…bad3d4` / `0be84704…ad5a18` | LUN0 GPT 双表（GPT 手术前基线） |
| 40 | `backup/HA2EXB0E-16+512/m8ab-restart-20261030/` | `gpt-sda-primary` `b1139aa2…85aac8`、`gpt-sda-backup` `4559cf53…36f4d7`、`gpt-sde-primary` `d29ebd15…5f88a0`、`gpt-sde-backup` `390fab7a…3735f7`；`boot_b-before.img` / `boot_b-base-before-restore.img` 各 100 663 296；`device-info.txt` 743 B | 10-30 最新双 LUN GPT + boot_b 双份备份（注：目录内有一个 **0 字节 `gpt-$d-$part.bin`**，是脚本变量未展开的残留，**不可当备份用**） |
| 41 | `bootslot-b/boot_b-vk181-daily-signed-20261029.img` | 100 663 296；sha `b72866ef6e6c82…d1e9` | 当前 `boot_b` 的**上一版**回退件 |
| 42 | `bootslot-b/boot_b-f2fs-root.img` | 100 663 296；sha `257266ec058f64f61b94bcd900dd7fc686f91949f46641def8b15580ca4014a4` | 更早的 `f2fs@linux18` 回退件 |
| 43 | 设备通道①：`reboot2 bootloader` → fastboot（`G1-24`） | 内核 PSCI `SYSTEM_RESET2` vendor reset；`scripts/eldroid-bootctl`、`scripts/slot-switch.sh`、`scripts/slot-attr.py` | 进/出 fastboot、查 `slot-unbootable` |
| 44 | 设备通道②：`ttyGS0` 早期 gadget（`elden_early_gadget=1`） / 通道③：`ramoops`/pstore 判复位深度 | `initramfs/init`（L305/L311–313/L394–401 白名单解析）；`scripts/q32-boot-evidence.sh`、`scripts/suspend-boot-panic-capture.sh`、`PITFALLS` #374–#377 | UEFI 线本身**用不上**（载荷进不了 Linux），但回退后判「这一发到底怎么复位」靠它 |

---

## §6 使用本文件时必须知道的三条口径

1. **「构建成功 ≠ 能亮屏 ≠ UFS 能用」**：`uefi-visibility-rebuild-20261028.md` 的自定规则；本文件所有镜像状态均为 **已构建/未上机** 或 **已上机/现象如述**，没有一条新的「已修复」。
2. **`fastboot boot` 不是无副作用**：会改 misc 槽属性（`slot-unbootable:b=yes`、`current-slot=a`）⇒ 每发后必须回验（`PITFALLS` #387）。
3. **「同一变量组」在不同设备的 UFSDxe 不可互换**：本机 `Binaries`（Mu 未补丁）与厂商件只差 6 B，而 dodge 的两枚件（`0b32d924`→`e76b555f`）是**另一个 PHY/供电体系**；`Device-Binaries/dodge/README.md` 自己标 **“These Patches are Outdated & Unstable!”**。

---

## §7 引用索引（本文所有断言的可点入口）

**报告（16）**：`uefi-restart-20261021.md` · `uefi-woa-prep-20261024.md` · `uefi-experiment-build-20261024.md` · `uefi-boot-A-attempt-20261024.md` · `uefi-runtime-table-provider-20261024.md` · `uefi-gunyah-reassess-20261024.md` · `uefi-visibility-20261026.md` · `uefi-migration-interface-20261026.md` · `uefi-n2-v0-attempt-20261026.md` · `uefi-control-experiment-20261027.md` · `uefi-visibility-rebuild-20261028.md` · `uefi-samechip-tablet-display-20261028.md` · `uefi-issue12-reply-draft-20261028.md` · `uefi-issue12-reply-final-draft-20261029.md` · `uefi-closeout-20261029.md` · `uefi-recovery-20261030.md`
**档案（3）**：`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md` · `UEFI-RESOURCES-2026-10-05.md` · `UEFI-UFS-UPSTREAM-ASK-2026-10-05.md`（+ `BOOTCHAIN-2026-10-05.md`）
**PITFALLS**：#368（`reboot2` 早发 → USB 全不枚举）· #374–#377（复位深度/pstore）· #387（v3 静默忽略 + 槽被标 unbootable + logfs 不落盘）· #401/#406（`fastboot boot` 镜像活过暖复位）· #418（v0 必须 `--base 0x10000000`）
**SSOT（只读引用，本次未改）**：`TASKS/README.md` §4 N1 / §5 Q25 / §1 G1-29 · `DEVICE/README.md` §1.1 · `INDEX.md` · `versions/`
