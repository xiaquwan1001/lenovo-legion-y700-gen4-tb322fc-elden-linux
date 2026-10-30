# 开源 bootloader 替代调研（TB322FC / SM8750P / elden）—— 2026-10-31

> **性质**：只读调研 + 联网检索。本 lane 对设备的接触**仅限一次只读 ssh**（`uname` / `ls /dev/disk/by-partlabel` /
> `blockdev --getsize64` / `cat /proc/cmdline` / `cat /sys/module/qcom_scm/parameters/download_mode`），
> **无 fastboot、无 adb、无写盘、无安装包、无 reboot**；**未构建**、**未下载任何资产**（只用 `gh api` 元数据与原始文件）；
> **未改** `TASKS`/`INDEX`/`PITFALLS`/`DEVICE`/`AGENTS.md`/`versions/`、未 git add/commit。
> **证据等级词**：`已证` = 有文件:行 / 命令原文+输出 / URL+日期；`未证实` = 只有推断或第三方口头；
> `未上机` = 有产物无实测。
> **只引用不重开**：UEFI 线 = `reports/uefi-consolidated-20261030.md`（维持搁置）；kexec 线 =
> `reports/kexec-target-boots-20261024.md`（仅调试）。

---

## #0 一页结论

| 项 | 结论 |
|---|---|
| **推荐** | **不换 bootloader**；把现有 L0（`fastboot boot` + kexec）里唯一已定位的缺口补掉 |
| **只做一件事** | **kexec 的 GIC ITS quiesce**（~20 行，零写盘，判据三条：目标 cmdline 含 `elden_kexec_target=1` / 到 `/init` < 30 s（对照 126.3 s）/ `ITS queue timeout` = 0） |
| **第 0 号待办（门，不是路线）** | **真机验证 9008**（Vol+ 插线 → `edl.py printgpt`，~30 min，需用户在场）；通过后立刻补 `abl_a/xbl_a/uefi_a/logfs` 的 dd dump（~40 MiB） |
| **理由（3 条）** | ① L0-b 是**唯一已证「跑到用户态」**的路线（`reports/kexec-target-boots-20261024.md` §0）；② 零砖风险；③ 它把「找 bootloader」变成「不需要 bootloader」 |
| **L2（替代 ABL）** | **无现实性**：coreboot `sm8750` **0 命中**、U-Boot 无 board/config、lk2nd 止于 msm8996、Mu 只在手机上（平板未证）+ 本机 UFS 两层故障未解 ⇒ **维持 UEFI 搁置**（与 `TASKS` §4 N1 / §5 Q25 一致） |
| **硬阻塞（若将来做 L2）** | ① **早期可见性**（UART 全 0、无 `UsbSerial*Dxe`）② **UFS + SMMU 域初始化**（`EnableUfsIOC`/`UFSSmmuConfig`）③ **XBL 签名墙**（`abl_a` 是否可写/是否验签 = **未证实**） |
| **不可逆性判决** | **EDL 9008 真机未验 ⇒ 在验证前，任何 `abl`/`xbl` 写入一律「不可接受」**（判据见 §3.4） |
| **最贵的错觉** | 「ABL 在管 DDR/AOP/PMIC」——**它不管**（XBL 管）；真正「不做就砖」的只有 **UFS(含 SMMU) 与 fastboot 通道**两条（§2.1） |
| **收益排序** | kexec 快环 ≫ kShimC 菜单 > UEFI ≫ U-Boot/lk2nd > 刷 `abl`（风险断崖） |

---

## §1 分层矩阵（L0 → L2，风险从低到高）

> 读法：**「风险」= 把设备弄成不可恢复状态的概率**，不是工作量。L0 零写盘 ⇒ 风险≈0；L2 要写 `abl/xbl` ⇒ 风险不可逆。
> 每一行的「实证状态」只写本仓库/本机已有的证据；上游 README 的说法一律降级到 §4 并标 `未证实`。

### L0 —— 不改引导器，只做「自有载荷」（风险：无 / 已有生产使用）

| 路线 | 代表实现 | 支持面 | 对 SM8750/TB322FC 的实证状态 | 收益 | 阻塞 |
|---|---|---|---|---|---|
| **L0-a** `fastboot boot <raw Image>` | 本仓库既有工作流 | 全部（内核侧自己驱动） | **`已证`**：日常路径。`DEVICE/README.md:1.1`、`reports/m1-clean-tree-20261011.md`；本轮设备侧只读复核 `uname -r` = `7.3.0-rc7-debug-vk127-…-vk172`，根 `/dev/sda17` | 零写盘、可任意试内核、失败即回原槽 | 需要主机 + USB + 人；**不能自启**、不能脱离 PC |
| **L0-b** kexec（Linux → Linux） | 本仓库 `scripts/kexec-*`、有 `kexec_diag` 旋钮 | 内核侧 | **`已证` 到用户态**：`reports/kexec-target-boots-20261024.md` §0 —— 目标到 `/init`、`switch_root` 到 `/dev/sda17`、`udevd` 起；断点 = **GIC ITS 未 quiesce**（129 条 `ITS queue timeout`，到 `/init` 由 ~9 s 拖到 **126.3 s**），显示/USB 继承态未复位 | **不需主机**即可换内核/换根；是「Linux 当 bootloader」的地基 | ITS quiesce 补丁未写（同文 §3，~20 行，判据明确）；显示继承无解（`msm-mdss/unbind` 会整机重启） |
| **L0-c** 「Linux 当 bootloader」 | **kShimC**（`sunflower2333/kShimC`，GPLv3，4 MiB bare-metal runtime，非 Linux）、`u-root`/LinuxBoot、`tinyboot`（kexec + BLS） | 取决于 runtime 自带驱动 | **同机型第三方实证（`未证实` 级）**：`mydanyi/armadaos-freedom` 的 TB322FC 文档称「kShimC 中文菜单 / 进原厂 Android / 进机身 Linux / 触屏坐标修正」**已确认**；但同仓 issue #4（2026-10-20）在求「依赖固定版本或一份可用的 `kShimC.bin`」⇒ **构建不可复现**，不是可直接引用的底座 | 菜单 + 双系统 + 不依赖 PC | ① 需先有一个能起 Linux/Android 的 boot 槽（它自己不解决首次引导）；② kShimC 是 GPLv3，与本仓口径不一致（`reference/upstream-armadaos-freedom/README.md` §2 已裁决「只引用不 vendor」） |
| **L0-d** LinuxBoot / u-root | `u-root/u-root`（push 2026-10-27，3082★） | x86 为主，arm64 可用 | `未证实`：u-root 在本机没有任何实测；它要求先由某种固件（EFI）加载或用 `linuxboot` 打包进固件 ⇒ **在 L0 形态下它只是「另一个 initramfs」**，价值等同 L0-b | 提供 `boot`/`kexec` 用户态工具与菜单 | 不解决引导入口；收益被 L0-b 覆盖 |

**L0 小结**：这层**已经是本项目现状**，唯一尚未吃掉的红利 = **把 kexec 快环修到可用**（ITS quiesce + 显示/USB 继承），不是「再找一个 bootloader」。

### L1 —— second-stage bootloader（ABL 仍在，替换它之后加载的东西）（风险：低，只写 boot 分区）

| 路线 | 代表项目 | 支持面（对 SM8750 逐项） | 实证状态 | 收益 | 阻塞 / 工作量 |
|---|---|---|---|---|---|
| **L1-a** U-Boot mainline（`qcom`） | `u-boot/u-boot`（master push 2026-10-30，5305★） | `board/qualcomm/` = `dragonboard410c/820c/845c`、`qcs404-evb` + `debug-{msm8953,qcm6490,qcs9100,sdm845,sm6115,sm6350,sm8250}.config`、`qcom-phone.config`、`google-pixel.config`（API 2026-10-31）→ **SM8750 无 board/config**。`drivers/clk/qcom/` 有 **`clock-sm8650.c`**、`clock-x1e80100.c`；`drivers/ufs/ufs-qcom.c` + `drivers/phy/qcom/phy-qcom-qmp-ufs.c`（含 `pcs-ufs-v6.h`）在树 | `sm8750` 的 69 条命中**全部在 `dts/upstream/**`**（自动同步的 Linux DT 子树），`configs/`/`board/`/`drivers/` **0 命中** ⇒ **无板级支持**（`已证`，API 检索 2026-10-31） | 成熟驱动框架 + 现成 SM8650 时钟表可抄；可作「诊断/救砖用第二引导」 | 工作量大且**收益低**：U-Boot 不能给你桌面；它仍需被 `boot.img` 或 `fastboot boot` 装进去 ⇒ **不比 L0-b 更省**，却要重写 SM8750 时钟/PMIC/UFS PHY v6 表。**估算：≥4–8 人周**（未核实，按 SM8650 端口规模推） |
| **L1-b** lk2nd | `msm8916-mainline/lk2nd`（push 2026-10-20，635★） | `Documentation/devices.md`（275 行）SoC 小节 = `msm8916/8909/8952/8953/8974/8226/8994/8996/8960/8610/8660`；**`sdm6xx/sdm8xx/sm6xxx/sm7xxx/sm8xxx` 命中 0** | `已证`：SM8750 **无先例**，支持面止于 **msm8996 一代** | lk2nd 的强项是「统一 fastboot + 设备/面板/电池自动探测」，正好是我们 patchwork 的部分 | 需新增 UFS 4.0 host + CPHY/DSC panel 表；LK 的 `platform/msm_shared` 是 `devprg/mmc/dsi` 老栈 ⇒ **等同新写平台支持**。且它**本身是 boot.img 载荷**（README「Configuration」段原文）⇒ 仍属 L1 |
| **L1-c** systemd-boot / GRUB(arm64-efi) | 上游 | 需要 EFI runtime + GOP | `未证实`（架构性推断）：ABL 只在 `fastboot boot`/boot 分区给我们一个 **kernel 槽**，没有 EFI application 槽；L0 形态下内核直接起，没有 EFI stub 的调用者 | — | **在 UEFI（L2）成立前无意义**；UEFI 一旦成立它们才有位置 |
| **L1-d** tinyboot | `jmbaur/tinyboot`（push 2026-10-12，29★，"A kexec-based bootloader"） | 需先跑起一个 Linux，再按 BLS 菜单 kexec | `未证实`：本机 0 实测；其 README 只给 QEMU 跑法 | 极小的 BLS 菜单 + kexec（`tinyconfig` 内核） | 与 L0-b 同源同阻塞（kexec 继承态）；**可用作 L0-b 的 UI 层，不构成新路线** |
| **L1-e** kShimC（bare-metal 第二级） | `sunflower2333/kShimC` + `Project-Aloha/DualBootKernelPatcher`（`MultiBootKernelPatcher`） | 自带 `QCOM_KEYS`/`QCOM_SPMI`/framebuffer+LVGL/libfdt；**不含 UFS/网络** | **同机型第三方在用（`未证实` 级，见 L0-c）**；构建需求 = CrDK + picolibc + LVGL + libfdt 固定版本，`tb322fc_android_defconfig` | **这是唯一在 TB322FC 上被第三方验证过的「自绘菜单 + 多系统」方案**；4 MiB 固定尺寸，塞进 boot header 的 kernel 槽 | GPLv3（不 vendor）；依赖 `MultiBootKernelPatcher` 改 boot.img；菜单能显示但**不提供 UFS/网络/救援 shell** |

**L1 小结**：L1 的天花板是「多一层菜单/多一个引导器」，**不解决本项目真正卡住的两件事**（UFS 初始化归 ABL；显示继承归 kexec）。除 L1-e（同机型有第三方实证）外，其余三条对 SM8750 都要从零写平台层。

### L2 —— 完整替代 ABL（风险：不可逆，写 `abl`/`xbl`）（风险：高）

> **前提事实**：本机 ABL 本身就是 EDK2/DXE 派生物（F-02），所以 L2 的技术含义 = **重新实现那 59 个 DXE 模块的责任**，
> 并且要跨过 **XBL 的签名校验**（见 §3 判据）。

| 路线 | 代表项目 | 支持面 | 对 SM8750/TB322FC 的实证状态 | 收益 | 阻塞 |
|---|---|---|---|---|---|
| **L2-a** EDK2 / Mu（Mu-Silicium / `mu_wide_platforms`） | `reference/upstream-mu-silicium/`、`reports/uefi-consolidated-20261030.md` | 同 SoC 有 2 台手机（`dodge`/OnePlus 13 等）已 `Linux Boot ✅`；**平板未证实** | **`已证`（已上机 4 发）**：10-05 亮屏出字（`F20`）；10-24/10-26 交棒后 60 s 全静默、~82 s 回落 stock；**现存 9 枚镜像 0 枚「按 #418 口径可直接交棒」**；`UFS.c+2326`（`UFSSmmuConfig`）+ `0x402`（`GPTListenerReadSectors` 的 `ctx+4`）两层故障 | 若成：统一 UEFI ⇒ 可挂 GRUB/systemd-boot/LinuxBoot，且 ABL 的 fastboot 限制（无 `fetch`）被替换 | **卡在「早期可见性」**：UART 全 0、无 `UsbSerial*Dxe`、`logfs` 每次启动重写 ⇒ 失败那发取不到证；上游 issue #12 只答「系统版本问题」 |
| **L2-b** coreboot | `coreboot/coreboot`（push 2026-10-30，2819★） | **不是「无 qcom 支持」**：`src/soc/qualcomm/` = `calypso / common / dougie / ipq40xx / ipq806x / qcs405 / sc7180 / sc7280 / x1p42100`。`x1p42100`（骁龙 X 系）目录含 **`ufs.c`、`pmic.c`、`rpmh_rsc_init.c`、`cpucp_load_reset.c`、`adsp_load_reset.c`、`qclib.c`、`display/`、`usb/`** ⇒ **它干的正是 ABL 那一层的活** | `已证`：**SM8750 零命中**（`search/code?q=sm8750 repo:coreboot/coreboot` = 0）；所有端口都是 **ChromeOS / WoA 板**，DT/时钟/PMIC 表按板写死 | 架构上最贴近「ABL 替代」的现成工程骨架 | ① 从零移植 SM8750 SoC 目录（UFS/PMIC/RPMH/CPUC P 各有现成实现可抄，但表要重写）；② `util/qualcomm/createxbl.py`/`ipqheader.py`/`mbncat.py` 说明产物按 **MBN/XBL 格式打包** ⇒ **必须过签名链**，零售机不可行（见 §3） |
| **L2-c** depthcharge | ChromeOS | 需 coreboot | `未证实`（架构性）：depthcharge 是 **coreboot 的 payload**，无 coreboot 无从加载；它对 Qualcomm 的支撑完全依赖 coreboot 端口 | — | 本项目无意义（除非 L2-b 先成） |
| **L2-d** U-Boot proper 刷进 `xbl`/`abl` 分区 | u-boot `qcom` | 同上（无 SM8750） | `未证实`：**未做过任何分区写入尝试**；`xbl_a` = 3 670 016 B、`abl_a` = 1 048 576 B（本轮设备侧 `blockdev --getsize64` 实测），与固件包 `xbl_s.melf` / `abl.elf` 尺寸**逐字节相等** ⇒ 分区就是原厂镜像的直拷贝 | 一次写入即「换掉 ABL」 | ① 无 SM8750 支持（同 L1-a）；② **XBL 验 ABL 签名**（本机 `hyp` 分区已证受 XBL 校验，`DEVICE/README.md` §1）⇒ 非签名 ABL 预期不启动；③ 写坏只能靠 EDL |
| **L2-e** UEFI 固件 + LinuxBoot payload | Mu + `u-root` `boot` | 同 L2-a | `未证实`：依赖 L2-a 先亮屏 | 把「引导逻辑」从 C 固件搬到 Linux 用户态（可维护性最好） | 全部 L2-a 的阻塞 + u-root arm64 的 UFS 卷访问 |

**L2 小结**：**没有任何一条 L2 路线在 SM8750 上有过成功先例**（`已证`：coreboot 0 命中；lk2nd/UBoot 无 SM8750；
Mu 只在手机上、平板未证）。L2 的真实瓶颈不是代码量，而是 **① 早期可见性（无 UART/无串口 DXE）** 与
**② XBL 签名墙**（§3）。

---


---

## §2 ABL 现在替我们做了什么（逐项 + 证据 + 换掉之后谁做）

> 判据：**「不做就砖」= 少做这一项，设备连 fastboot/内核都到不了**。
> 本节的设备侧事实全部来自**只读**命令（本轮 2026-10-31 一次 ssh 会话 + 既有报告），无任何写操作。

| # | ABL 的职责 | 证据（文件:行 / 命令+输出 / URL+日期） | 等级 | 换掉 ABL 后谁做 | 不做会怎样 |
|---|---|---|---|---|---|
| 1 | **DDR 训练 / 内存映射表** | ABL 日志里有 `Memory Base Address: 0x80000000`、`Final RAM Partitions` 表（`reports/uefi-boot-A-attempt-20261024.md` §「ABL 日志」；`reports/uefi-control-experiment-20261027.md` §2 引用 `Add Base 0xFF300000 / Available Length 0x500000`）；另有独立 `ddr` 分区（本轮实测 `/dev/disk/by-partlabel/ddr -> /dev/sdd3`，1 048 576 B） | **部分已证**：「ABL 收到已初始化的 RAM 表」已证（它只做*分区*，不做*训练*）；**训练在 ABL 之前由 XBL 完成 = `未证实`**（推断自我方日志顺序 PBL→XBL→ABL，`scripts/abl-log.sh` 头注释） | **XBL**（不在 L2 改动范围） | — （⇒ **L2 不必重做 DDR 训练**，这是最关键的一条「省下来的活」） |
| 2 | **AOP / RPMh 资源与电压轨** | coreboot 的 `x1p42100` 端口有 `rpmh_rsc_init.c`（`已证`，源码在树）⇒ 这一层是可重写的、非黑盒；本机 `aop_a`/`aop_config_a` 分区在（本轮 `ls /dev/disk/by-partlabel`）；内核侧 `rpmhpd`/`rpmhcc` 依赖 AOP | `未证实`（谁在 ABL 阶段初始化 RPMh 未直接取证；只有「AOP 独立固件 + coreboot 有对应实现」两条） | AOP 固件（XBL 加载），ABL 只**协商** | RPMh 不通 ⇒ 时钟/电源域全死（内核起不到 DRM） |
| 3 | **PMIC / SPMI 初始化** | `cdt` 分区（平台 ID/PMIC 配置）；主线需要 `spmi` + `pmk8550` 才有点电/音量键/RTC（`PITFALLS` #392 的 RTC 修复即在 PMIC SDAM）；kShimC 配置项 `QCOM_SPMI`（`reference/upstream-armadaos-freedom/boot-README.md` §「构建 4 MiB runtime」）说明**第二级载荷也能碰 SPMI** | `已证`（存在性与依赖）/ `未证实`（ABL 具体做了什么） | XBL + PMIC 自身 OTP；ABL 做板级配置 | 电源键/充电/RTC 全废 |
| 4 | **UFS 初始化（含 SMMU/IOMMU 域）** | **最硬的一条**：厂商 `UFSDxe` 里 `EnableUfsIOC`（UFS IOMMU `domain create/configure/attach`）被 dodge 补丁整函数 stub 掉才跑得过；`UFS.c+2326` 的 ASSERT 载荷 = `UFSSmmuConfig failed`（`reports/uefi-recovery-20261030.md` §2 F8、`uefi-consolidated-20261030.md` §2 F6）；本机 `androidboot.bootdevice=1d84000.ufshc`（本轮 cmdline） | **`已证`**（反汇编 + 断言字符串 + 两处独立证据） | L2 实现者（**这就是 Mu 卡了 3 周的那一层**） | **砖**：拿不到 rootfs/分区表 |
| 5 | **`splash_region` 活显示** | 本机 DT `reserved-memory/splash_region` 43 MiB @ `0xfc800000`（`no-map`）；内核打印 `boot framebuffer mapped before SID switch` + `[drm] reserved boot framebuffer IOVA 0xfc800000+0x2b00000`；`FW_LIVE_FB=yes` **5/5**（`reports/q32-matrix-20261024.md`）；`PITFALLS` #366 段亦记 | **`已证`** | ★**没有人**：Mu 的 `SimpleFbDxe` **只做 4 步**（按名字取 `Display Reserved` 内存映射 + 读 `PcdMipiFrameBufferWidth/Height` + `ZeroMem` + 装 GOP），**不初始化任何 DSI/panel/PHY/clock**（`uefi-consolidated-20261030.md` §2 F16） | 黑屏（不是砖，但等于瞎） |
| 6 | **slot / AVB / `qbootctl`** | 本轮 cmdline：`androidboot.slot_suffix=_b`、`androidboot.verifiedbootstate=orange`；槽状态在 **GPT attribute byte 6**（`AB_FLAG_OFFSET`+6，`0x04` active / `0x40` successful / `0x80` unbootable / `0x38` retry），我们与 QTI `gpt-utils.h` **逐位等价**（`reports/twrp-parity-edl-dload-20261020.md` §2、`scripts/slot-attr.py`）；ABL 每次启动递减 retry，`PITFALLS` #181 | **`已证`** | ABL 独有；没有替代者（GPT 属性可以被任何程序改，但**「ABL 读它并决定启哪个槽」这件事没得替**） | 双槽全废（只能固定单槽启动） |
| 7 | **充电检测 + `androidboot.mode=charger`** | 插 USB 重启时 `/proc/cmdline` 带 `androidboot.mode=charger` ⇒ 容器 `ro.bootmode=charger` 只跑 `on charger`（`PITFALLS` #465、`scripts/waydroid-cmdline-fix.sh` 头注释） | **`已证`** | ABL 独有（充电图标/关机充电是 ABL 画的） | 插着线重启会进「充电模式」而非正常启动 —— **L2 若不实现，行为会变**（可能反而更好，但是**变更**） |
| 8 | **fastboot 协议（含 `fetch` 缺失）** | `fastboot boot` / `flash` / `getvar` 全部由 ABL 提供；**无 `fastboot fetch`**（实测 `Unable to get max-fetch-size`，`PITFALLS` #290、`PITFALLS/README.md:14`） | **`已证`** | L2 必须自己实现（Mu 有 `UsbSerial*Dxe`/fastboot 支持但本机未验证；`uefi-migration-interface-20261026.md` §4 记「无 `UsbSerial*Dxe`」） | **失去唯一的电池外恢复/刷新通道** |
| 9 | **`logfs` / `UEFILOG1.TXT` 启动日志** | `scripts/abl-log.sh`：`logfs` = `/dev/sde68`（**8 388 608 B**，FAT12，卷标 `LOGFS`，内含 `UEFILOG1.TXT` 64 KiB），覆盖 PBL 时间戳 → XBL → ABL（`Launching fastboot` / `Cmdline` / `Final RAM Partitions`）→ `Start EBS`；**每次启动重写** | **`已证`**（脚本 + 多份报告引用） | L2 实现者（可选） | 失去唯一的「bootloader 侧决策」取证通道（本项目 UEFI 线正是被这条限制卡住的） |
| 10 | **解压内核 / 组装 bootconfig cmdline** | ABL 日志 `Decompressing kernel image total time: 288 ms`（`reports/uefi-boot-A-attempt-20261024.md`）⇒ ABL 自己 gunzip；cmdline 里 `androidboot.*` 与联想私有 `hqsysfs.pcba_stage/config`（本轮 `cat /proc/cmdline`）都是 ABL 拼的 | **`已证`** | L2 实现者 | `fastboot boot` 的「裸 gzip Image 也能起」这一便利会消失 |

### 2.1 「换掉 ABL 后这些谁做」—— 按 L2 路线的归属

| 职责 | 保留 XBL（L1 / L2-a Mu） | 连 XBL 一起换（不可能，见 §3） | 判断 |
|---|---|---|---|
| DDR 训练 | XBL | PBL/fuse | **不用管** |
| AOP / RPMh / PMIC | XBL + AOP | 需自写 | 不用管（Mu 亦未重做） |
| **UFS + SMMU 域** | **L2 实现者** | 同 | ★**硬前置**（Mu 就死在这） |
| **点屏 / framebuffer** | **L2 实现者**（或像 Mu 一样「假设前级已点屏」直接复用 `Display Reserved`） | 同 | ★**硬前置**，但是**可绕过项**（Mu 的做法） |
| slot/AVB | L2 实现者 | — | 硬前置（否则只能单槽） |
| fastboot + logfs | L2 实现者 | — | **不做就失去恢复通道** ⇒ 硬前置 |
| charger 模式 | L2 实现者（可选） | — | 行为变更，不砖 |

**结论（本节最重要一句）**：**「不做就砖」的硬前置只有两条 —— UFS(含 SMMU 域) 与 fastboot 通道**；
`DDR 训练`/`AOP`/`PMIC` **不是** ABL 的责任（XBL 做），`点屏` 可以被「复用 `Display Reserved`」绕过（Mu 已证这条取巧可行），
`slot/AVB` 与 `logfs` 是「不做就残废但不砖」。


---

## §3 回退与不可逆性（**本节是裁决关键**）

### 3.1 EDL 9008 在本机到底可用吗？

| 环节 | 状态 | 证据 |
|---|---|---|
| 内核侧触发代码 | **`已证`（主机侧）**：`qcom_scm` 的 `set_download_mode()` 写 TCSR `0x1fc0000 + 0x19000` 的 `QCOM_DLOAD_MASK`（bits 5..4）；DT 补丁已落 `patches/edl-dload-20261020/`，`dtbs` rc=0、`dtbs_check` **0 诊断**、板 DTB 153101→**153233 B** | `reports/twrp-parity-edl-dload-20261020.md` §1 |
| 设备侧参数文件 | **`已证`（本轮只读）**：`/sys/module/qcom_scm/parameters/download_mode` = **`off`** | 本轮 `cat` 输出 |
| **真机进 9008** | **`未上机`** —— 原文「未做：真机 EDL 触发验证（要刷新 DTB 的内核 + 接受一次进 9008 的风险）」 | 同报告 §1 末 |
| **按键进 9008（不依赖内核）** | **`已证`（社区口径，非本机实测）**：关机 → 按住 **Vol+** → 插 **长边口** USB | `.pi/skills/qualcomm-edl-flashing/SKILL.md` §Workflow 3；`skywalker512/armada-tb322fc` README「仅长边口支持 fastboot/9008」 |
| EDL programmer（免签名） | **`已证`（文件在盘）**：`~/下载/tb322fc/xbl_s_devprg_ns.melf`（1 697 740 B，`ns` = 不做签名校验） | `ls -l` 本轮；技能 §Key facts 1 |
| 工具链 | **`已证`（技能内多轮真机使用，含 TB322FC 2026-08-16/17 记录）**：`bkerler/edl` + udev `05c6:9008` + USB **2.0** 口 + `--loader=`；`edl.py` 的 LBA 单位是 **4096 B** | 同技能 §Pitfalls（多条 TB322FC 实例） |

**结论**：**软件与资产侧齐备，唯一缺口是「本机 9008 从未真正进去过」** ⇒ 按本项目纪律只能记 `未上机`。
但按键通道（Vol+ 插线）是**与内核无关的硬件通道**，且 `XblRamdump.elf`、`xbl_s_devprg_ns.melf` 都在包里 ⇒ 风险不是「没有 EDL」，而是「没验证过」。

### 3.2 备份现状（`xbl`/`abl` 分区备份在盘吗？）

| 项 | 状态 |
|---|---|
| `backup/HA2EXB0E-16+512/` 内容（本轮 `ls`） | `boot_b-*.img` ×3（各 100 663 296 B）、`m8ab-restart-20261030/boot_b-base-before-restore.img`（100 663 296 B）、`sde-gpt-{head,tail}.bin`（各 139 264 B，在 `backup/`）、`gpt-20261025/{main0,backup0}.bin`、`gpt_*_0.bin`、`c0-baseline/`、`device-rescue-20261017/`、`current-259/`、`stock/`、`unique/`、`pre-unlock/`、`fw/`、`stock-elden/` |
| **`xbl` / `abl` 分区 dump** | ❌ **没有**（`ls backup/HA2EXB0E-16+512/` 无任何 `xbl*`/`abl*`）；`grep -rl xbl` 只命中脚本/文档，无二进制 |
| **等价备份（原厂固件包）** | ✅ `~/下载/tb322fc/abl.elf` = **1 048 576 B** ≡ `abl_a` 分区尺寸（本轮 `blockdev --getsize64` = 1 048 576）；`xbl_s.melf` = **3 670 016 B** ≡ `xbl_a`（3 670 016）；`uefi.elf` = 5 242 880 ≡ `uefi_a`；另有 `四代旧版abl.elf`（241 464 B，旧版） |
| ⇒ 判定 | **「可恢复」在文件层面 YES**（原厂包逐尺寸匹配），但**没有任何一份是「从本机读回并校验」的**（`PITFALLS` #290：ABL 无 `fetch`，只能设备侧 `dd`） |
| 现在能否补齐 | ✅ **能，且很便宜**：`xbl_a`+`abl_a`+`uefi_a`+`logfs`+`tz_a`+`hyp_a`+`imagefv_a`+`uefisecapp_a` = **约 40.0 MiB**（3.67+1+5+8+5+8+2+2 MiB，逐项本轮实测），全部是 `/dev` 下的普通块设备 ⇒ 一条 `dd` + `sha256sum` 读回即可。**属设备写操作（写 /tmp），本 lane 未做，需父批准** |

### 3.3 签名墙：L2 到底能不能「刷进 `abl` 分区」

| 事实 | 等级 | 出处 |
|---|---|---|
| 量产 SoC 的 secure boot fuse 是**单向**的，没有「固件解锁硬件 secure boot」这回事 | `已证`（技能多轮） | `.pi/skills/qualcomm-edl-flashing/SKILL.md` §Key facts 1 |
| 本机 `hyp` 分区受 **XBL 签名校验**（所以 Gunyah 换不掉） | `已证` | `DEVICE/README.md` §1「Hypervisor: 签名 Gunyah 占 EL2 … `hyp` 分区受 XBL 签名校验」 |
| ⇒ **`abl` 同属 XBL 校验链** | `未证实`（推断：同一 `LUN4` 引导链、同一份 `xbl_s.melf`；本轮实测 `abl_a`/`xbl_a`/`tz_a`/`hyp_a` 全在 `sde`/`sdb` 引导 LUN） | — |
| **第三方称**「解锁后 XBL 的校验链会放宽，允许打过补丁的 ABL 加载」 | **`未证实`**（单仓库、1 star、无复现、目标机型非 TB322FC） | `CrackerCat/abl-patch-toolkit` README（2026-08-15） |
| 我们能动的写通道 | `fastboot flashing unlock_critical` 曾用于解锁（技能 §PRINCIPLE），`abl_a` 是否因此可写 **`未证实`** | `.pi/skills/qualcomm-edl-flashing/SKILL.md` §PRINCIPLE |

**⇒ L2-d（U-Boot/coreboot 刷进 `abl`）在本机是「未证实可行」的门，且失败面 = 砖。**
在这条未知被消除之前，任何 L2 路线的**第一位**都不是写代码，而是 §3.4 的验证阶梯。

### 3.4 ★ 可接受 / 不可接受 判据（本 lane 的明确裁决口径）

**不可接受（任一命中即不许动 `abl`/`xbl`）**
1. **EDL 9008 未经真机验证**（至少一次真机进 9008 + 至少一条读命令成功）；
2. **没有本机 `abl_a` + `xbl_a` 的读回 dump + sha256**（原厂包不算，因为它无法证明「本机这份是原厂」）；
3. **没有第二人/第二台机器**在场能跑 `edl.py`（砖了以后 9008 恢复需要：另一台机 + USB2 线 + 长边口 + 按键动作，都是物理动作）；
4. **同时改 `xbl`**（PBL 验 XBL，失败连 EDL 的 programmer 加载都可能受影响）——**只许一次动一个分区**；
5. 当前 `boot_b` 不是已知 GOOD 的日常线（本轮 = `vk172`/`m3v5-f2`，`DEVICE` §1.1 已记 GOOD ⇒ 满足）。

**可接受（同时满足才允许做「写 `abl_a`」的实验）**
1. 上面 5 条全绿；
2. 第一次写入的对象是 **原厂 `abl.elf` 逐字节原样**（零功能变更加一次写+读回校验）——**用「无变化」验证写通道与验签**；
3. 第二次写入的才是 1 字节改动版（验证「解锁后是否放宽验签」）；
4. 全程 `fastboot` 单条执行（该机对连续命令容错差，`PITFALLS` #3），每次写后**读回校验**；
5. 每次动之前把 `logfs` 先 dump 一份（失败那一发的 ABL 日志会被回落启动覆盖）。

> **一句话**：`abl`/`xbl` 的写入**在 EDL 真机验证之前一律不可接受**；
> 而这项验证本身就是 L2 的**第 0 号任务**（成本 ~30 min，需用户在场按键）。

### 3.5 砖了以后用户需要什么（清单，供用户判断「值不值得」）

| 需要 | 具体 | 现状 |
|---|---|---|
| 另一台可上网的机器 | 装 `edl.py` venv（`pip install -r requirements.txt`） | 本机即可（砖的是平板，不是主机）✅ |
| USB **2.0** 口 + USB 2.0 数据线 | USB3 会 Sahara `USB Overflow` | 需现场确认（`PITFALLS` 多条） |
| **长边口** | 只有长边 USB-C 支持 fastboot/9008 | ✅ 已知 |
| 物理按键动作 | 关机 → 按住 **Vol+** → 插线 | **必须用户做**（agent 不能代做） |
| udev 规则 | `05c6:9008` MODE=0666 + `udevadm control -R` + **重新插拔** | ✅ 技能已记 |
| 恢复镜像 | `abl.elf` / `xbl_s.melf` + 6 套 GPT + 全套原厂包 | ✅ `~/下载/tb322fc/`（599 MB） |
| **时间** | 一次 EDL 恢复 = 若干次「写坏 → 断电 → 按键进 9008 → 重跑幂等脚本」循环（技能实测：**每失败一个分区要一次物理断电**） | ⚠️ 无人在场时**不可完成** |


---

## §4 生态实证（2026-10-31 只读联网检索）

**检索方法**（可复现）：`gh api search/repositories?q=…`、`gh api search/code?q=…+repo:<owner>/<repo>`、
`gh api repos/<r>/contents/<path>?ref=master`、`gh api search/issues?q=tb322fc+bootloader`。
**未做**：Telegram / Matrix / XDA 站内搜索（无可用凭据/无稳定入口）⇒ 那三处属 **检索盲区**，见 §6。

### 4.1 直接针对 SM8750 / 8 Elite 的项目

| # | 项目 | URL | 日期 | 它做了什么 | 证据等级 |
|---|---|---|---|---|---|
| 1 | **Mu-Silicium / `mu_wide_platforms`**（UEFI，L1/L2-a） | github.com/sunflower2333/mu_wide_platforms（issue #12）；状态页快照在 `reference/uefi-samechip-20261028/Mu-Silicium-Status-SM8750-section.md` | 状态页 2026-10-28 快照 | SM8750 段：OnePlus 13（`dodge`）UEFI **Display / Internal Storage / USB Device Mode / Mass Storage / Linux Boot = ✅**，需 `index986/sm8750-mainline` 内核 | **`已证`（仅"上游自述 + 本仓 10-05 亮屏 + 反汇编）**；**平板形态 `未证实`** |
| 2 | `index986/sm8750-mainline` | 被上条引用 | 2026-10 | SM8750 mainline 内核树 | **`未证实`**（未取树；对本项目价值 = DT/驱动参考，非 bootloader） |
| 3 | `CrackerCat/abl-patch-toolkit` | github.com/CrackerCat/abl-patch-toolkit | 创建 2026-08-15 / push 2026-08-14 | 打 **ABL 内 `LinuxLoader.efi`** 两处字节补丁（`0x450B0` ADRL、`0xec4a8` 字符串表），让 `androidboot.vbmeta.device_state` 恒 `locked`、`verifiedbootstate` 恒 `green`；自称与原件差 **5 字节** | **`未证实`**：32 KB、1 star、无复现、机型非 TB322FC；且**它不是 bootloader 替代，是「骗检测」**。**与我们相关的一句**：其 README 称「解锁后 XBL 验签链放宽，打过补丁的 ABL 才能加载」——这正是 §3.3 那条未证实的关键前提 |
| 4 | `Exo1i/opd2415-…-ksu` | github.com/Exo1i/opd2415-6.6.118-cve-2026-64560-ksu | 2026-10-27 | OnePlus Pad 3（OPD2415，**SM8750 平板**）**锁定 BL** 下用内核 CVE 后载 KernelSU | **`未证实`**（与本 lane 无关，仅证明「同 SoC 平板社区活跃在内核层，不在引导层」） |

### 4.2 通用开源 bootloader 对 SM8750 的支持面（源码级核查）

| 项目 | URL | 最近 push | SM8750 支持 | 证据等级 |
|---|---|---|---|---|
| U-Boot | github.com/u-boot/u-boot | 2026-10-30 | ❌ 无 board/config/驱动；`sm8750` 69 条命中**全部**在 `dts/upstream/**`（Linux DT 同步子树）。同代有 `clock-sm8650.c`/`clock-x1e80100.c`/UFS PHY v6 | **`已证`**（`gh api search/code` 2026-10-31） |
| coreboot | github.com/coreboot/coreboot | 2026-10-30 | ❌ 0 命中；但 `src/soc/qualcomm/{sc7180,sc7280,qcs405,x1p42100,calypso,dougie,ipq40xx,ipq806x}` 存在，`x1p42100` 含 `ufs.c`/`pmic.c`/`rpmh_rsc_init.c`/`cpucp_load_reset.c`/`adsp_load_reset.c` | **`已证`** |
| lk2nd | github.com/msm8916-mainline/lk2nd | 2026-10-20 | ❌ 支持面止于 `msm8996`；`sdm6xx/sdm8xx/sm6xxx/sm7xxx/sm8xxx` = 0 | **`已证`**（`Documentation/devices.md`） |
| depthcharge | chromiumos（未取） | — | ❌ 需 coreboot | **`未证实`**（架构性） |
| tinyboot | github.com/jmbaur/tinyboot | 2026-10-12 | 与 SoC 无关（kexec + BLS，需先有 Linux） | **`已证`**（README） |
| u-root / LinuxBoot | github.com/u-root/u-root | 2026-10-27 | 与 SoC 无关（同上） | **`已证`**（仓库自述） |

### 4.3 针对 TB322FC 本机型的开源项目（有没有人做过引导层？）

| 项目 | URL | 日期 | 与本 lane 的关系 | 证据等级 |
|---|---|---|---|---|
| **kShimC** | github.com/sunflower2333/kShimC（4★） | push 2026-10-13 | 「In-Kernel BootLoader」= 4 MiB bare-metal runtime，被 `MultiBootKernelPatcher` 塞进 boot.img 的 kernel 槽；`QCOM_KEYS`/`QCOM_SPMI`/LVGL 菜单；GPLv3 | **`已证`（代码/README）** |
| **armadaos-freedom** | github.com/mydanyi/armadaos-freedom | push 2026-10-29（本地快照 `244b7451`，2026-10-22） | **TB322FC 的 kShimC 适配**：`build_android_boot.py` + `tb322fc_android_defconfig`，runtime **必须恰好 4 MiB**；`kshim-build-boot.py` 只接受 `lenovo,elden`/`qcom,sm8750`；四代文档称「kShimC 中文菜单 / 进原厂 Android / 进机身 Linux」**已确认** | **`已证`（文档原文）**；「真机已确认」= **`未证实`**（第三方自述） |
| armadaos-freedom **issue #4** | github.com/mydanyi/armadaos-freedom/issues/4 | 2026-10-20 | 有人在求「kShimC runtime 的依赖固定版本，或一份可用的 `kShimC.bin`」⇒ **同机型的 kShimC 构建尚不可复现** | **`已证`**（issue 存在+标题） |
| TWRP device tree | github.com/polygraphene/android_device_lenovo_TB322FC | push 2026-04-04 | 提供 `TW_HAS_EDL_MODE`、`libboot_control_qti` 等出厂实现对照（`reports/twrp-parity-edl-dload-20261020.md` 已用） | **`已证`** |
| tb322fc mainline 各分支 | `h0cheung/tb322fc-linux`（2026-10-25）、`GEEKiDoS/tb322fc-linux`、`5aaee9/nixos-tb322fc-linux`（2026-10-23） | — | **都是内核/发行版层，不是引导器层** | **`已证`**（描述） |
| EDL 工具 | `l11223/geekflash`（macOS EDL，2026-02-12）、`18027972083/y700-flash-guide`（2026-10-12） | — | 佐证「9008 是本机社区常用通道」 | **`未证实`**（未逐条核内容） |

### 4.4 检索结论（一句话）

**截至 2026-10-31，全世界没有任何公开项目在 SM8750 / 8 Elite 上替换过 ABL 或做出第三方开源 first/second-stage bootloader。**
同 SoC 上唯一真实的开源固件成果是 **Mu-Silicium 的 UEFI（L1/L2-a 形态，且只在手机上）**；
本机型上唯一真实的「引导层第三方作品」是 **kShimC（bare-metal 第二级，塞 boot.img）**，且其构建尚不可复现（issue #4）。

---

## §5 裁决表 + 推荐顺序 + 最小验证

### 5.1 路线 × 工作量 × 阻塞 × 收益 × 风险

| 序 | 路线 | 层 | 工作量（估） | 主要阻塞 | 收益 | 风险 | 裁决 |
|---|---|---|---|---|---|---|---|
| **1** | **kexec + ITS quiesce**（+ K3 判据脚本） | L0-b | **S**（~20 行改动 + 6–8 轮零写盘，已有完整判据） | 无（`its_force_quiescent()` 现成，`reports/kexec-target-boots-20261024.md` §3） | ★**不需 PC 的快环**；为将来任何「Linux 当 bootloader」打地基 | **≈0**（零写盘） | ✅ **做** |
| 0 | **EDL 9008 真机验证**（Vol+ 插线 + `printgpt`） | 门（非路线） | **~30 min**，需用户在场按键 | 需一次「进 9008」的接受度 | 解锁全部后续风险承受力（§3 的 5 条判据里最关键一条） | 低（只读 `printgpt`） | ✅ **第 0 号待办**（不属路线，是准入） |
| 2 | kShimC 菜单 / 双系统（仅当出现「脱离 PC 双启」需求） | L0-c / L1-e | **M**（构建依赖不可得 ⇒ 先解决 issue #4） | runtime 构建不可复现；GPLv3 不 vendor | 同机型有第三方实证的**唯一**菜单方案 | 低（写 boot 分区，可回退） | 🟡 **备选，不主动做**（与「UEFI 搁置、kexec 仅调试」不冲突） |
| 3 | Mu / EDK2（UEFI 间接引导） | L2-a | **L**（1–2 周 + 2.3 G 资产） | ① 早期可见性（无 UART/无 `UsbSerial*Dxe`）② UFS 两层（`0x402` `ctx+4` / `UFS.c+2326` `UFSSmmuConfig`） | 一次性解决引导器 + 可挂 GRUB/LinuxBoot | 中（写 boot 槽，可回退） | ⛔ **维持搁置**（与 `TASKS` §4 N1 / §5 Q25 一致） |
| 4 | U-Boot mainline 当第二级 | L1-a | **XL**（≥4–8 人周，未核实） | 无 SM8750 board/config/时钟表/PHY 表 | 低（不能给你桌面） | 低 | ❌ **不推荐**（收益 < 成本，且不如 L0-b） |
| 5 | lk2nd | L1-b | **XL** | 支持面止于 msm8996；UFS4/CPHY/DSC 无先例 | 中（统一 fastboot/自动探测） | 低 | ❌ **不推荐** |
| 6 | U-Boot/coreboot 刷进 `abl`/`xbl` | L2-d | **XL** + **签名墙** | §3.3 三条未证实（XBL 验签是否放宽 / `abl_a` 是否可写） | —— | **不可逆** | ⛔ **在 §3.4 阶梯通过前一律禁止** |
| 7 | coreboot 移植 SM8750 | L2-b | **XXL**（新 SoC 目录） | 0 命中；产物按 MBN 打包需签名 | 架构最正 | **不可逆** | ❌ **无现实性**（除非有人愿做 SoC bring-up 且先解决签名） |
| 8 | LinuxBoot/u-root/tinyboot 固件化 | L2-e | 依赖 L2-a | 同 L2-a | 可维护性最好 | 中 | ⏸ **等 L2-a** |
| 9 | depthcharge / GRUB / systemd-boot | L1-c/L2-c | — | 需 EFI 或 coreboot | — | — | ❌ **当前无意义** |

**依赖顺序**：`EDL 验证（0）` → `kexec ITS（1）` → （需求出现时）`kShimC（2）` → （复启条件满足）`Mu（3）` → 其余。

### 5.2 ★「如果只做一件事，做哪件」

> **做第 1 项：kexec 的 ITS quiesce + K3 判据。**
>
> 理由（三条，均为本项目已有证据）：
> 1. **它是唯一「已经跑到用户态」的路线**（`reports/kexec-target-boots-20261024.md` §0 第 1 条：目标到 `/init`、`switch_root` 成功），
>    只差一处已定位的缺口（ITS 未 quiesce ⇒ 129 条 `queue timeout` ⇒ 126 s）；
> 2. **零写盘、零砖风险**（`fastboot boot` + `kexec -e`），失败就是回落 `boot_b`；
> 3. **它把「找 bootloader」问题变成「不需要 bootloader」**：Linux 一旦能可靠 kexec，L1/L2 的全部动机（菜单/多系统/快环）都可用
>    用户态解决 —— 这正是 kShimC/u-root/tinyboot 共同的思路，而我们不需要引入新代码基。
>
> **不做**：L2（UEFI/刷 `abl`）全部路线；理由 = 裁决表 + §3.4 判据未过 + `TASKS` 既有裁定。

### 5.3 每条路线的最小验证（命令级 + 判据 + 预期 + 失败回退）

> 所有设备侧动作**本 lane 未执行**，需父批准；带 ⚠️ 的必须用户在场。

**① EDL 9008（第 0 号，门）** ⚠️
```bash
# A. 按键通道（不依赖内核，最稳）：关机 → 按住 Vol+ → 插长边口 USB
lsusb | grep -i 05c6:9008            # 预期: 一行 "Qualcomm ... 9008"
# B. 只读探测（不写任何分区）
python3 edl.py --loader=~/下载/tb322fc/xbl_s_devprg_ns.melf printgpt
```
- **判据**：打印出 6 个 LUN 的 GPT；`boot_b` 的 first-last 与本仓 `backup/HA2EXB0E-16+512/gpt-20261025/main0.bin` 解析值一致。
- **预期**：`Mode detected: firehose` + 分区表。
- **失败回退**：`edl.py reset`（等价重启）；若 `Connection detected, quiting.` = 会话 wedge ⇒ **物理断电后重新 Vol+ 插线**（replug 无效，技能 §Pitfalls 有 2026-08-08 硬证据）。
- 通过后**立刻**补 `abl_a/xbl_a/uefi_a/logfs` 的 dd dump + sha256（~40 MiB）。

**② kexec ITS quiesce（第 1 项）**
```bash
# 静态门（主机侧）
git -C build/vk151 grep -n "its_force_quiescent" -- drivers/irqchip/irq-gic-v3-its.c
#   预期: 至少 1 处定义（报告记 5008/5044/5132 附近的调用点）
# 动态（零写盘；需父批准）
ssh root@192.168.7.1 'echo 1 > /sys/kernel/kexec_diag/kexec_diag; cat /sys/kernel/kexec_diag/kexec_diag'
bash scripts/kexec-boot.sh  ...   # 载入目标后 kexec -e
# 从 +90 s 起每 3 s 轮询（判据用 cmdline 身份，不用串口）
```
- **判据**（三条全绿才算通过）：① 目标 `/proc/cmdline` 含 `elden_kexec_target=1`；
  ② 目标到 `/init` 的耗时 **< 30 s**（对照 126.3 s）；③ 目标 `dmesg | grep -c 'ITS queue timeout'` = **0**。
- **预期**：`ath12k` 正常 probe（不再 `-110`），SSH 在 130 s 窗口内提前到 ~15 s。
- **失败回退**：`mask=1` 路径不掉电（`已证`），目标失败 ⇒ 设备自复位回 `boot_b`，无需物理干预。

**③ kShimC（备选）**
```bash
gh api repos/mydanyi/armadaos-freedom/issues/4 --jq '.state,.comments'   # 判据: closed 且有人贴出 kShimC.bin 的 sha256
```
- **判据**：拿到 `kShimC.bin`（**恰好 4 MiB**，`stat -c%s` = 4194304）+ 一份第三方实测日志。
- **预期**：issue 关闭 + 有可复现构建说明。
- **失败回退**：不投入（现状即"不可复现"）。

**④ Mu / UEFI（搁置，若复启）**
```bash
# 用 --base 0x10000000 重打包 v0（PITFALLS #418），单条执行
fastboot boot <E0-or-E1-v0-base10000000>.img
```
- **判据**：屏上出现 EDK2 文字（`Synchronous Exception` 块或 BDS 菜单）⇒ 早期可见性恢复。
- **预期**：10-05 曾达成（`uefi-consolidated-20261030.md` F20）。
- **失败回退**：`fastboot set_active b` + `fastboot reboot`（写 misc，非分区镜像；`PITFALLS` #387 记实测 20–25 s 回 Linux）。

**⑤ 刷 `abl_a`（L2-d，**仅在第 0 号通过后**）** ⚠️
```bash
# 第 1 步：原厂 abl.elf 逐字节原样（验证写通道 + 验签，零功能变化）
fastboot flash abl_a ~/下载/tb322fc/abl.elf
ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/abl_a bs=1M count=2 | sha256sum'
sha256sum ~/下载/tb322fc/abl.elf        # 预期: 两个 sha 一致（1048576 B）
```
- **判据**：写后读回 == 原厂文件；`fastboot reboot` 后仍能进系统、`logfs` 无新验签错误。
- **失败回退**：EDL `edl.py w abl_a ~/下载/tb322fc/abl.elf`（幂等）。
- **第 2 步（才轮到 1 字节改动版）**：只有第 1 步通过、且 §3.4 五条全绿才允许。

**⑥ coreboot / U-Boot（不推荐；若有人要做，先做这个判据）**
```bash
gh api "search/code?q=sm8750+repo:coreboot/coreboot" --jq '.total_count'   # 现状 0
gh api "search/code?q=sm8750+repo:u-boot/u-boot"    --jq '[.items[].path]|map(select(startswith("dts/upstream")|not))'
```
- **判据**：出现非 `dts/upstream` 的命中（= 真的有人写了板级支持）。
- **预期**：现状分别为 0 与 `[]`。
- **lk2nd 的最小判据**（同一形态，一条命令）：
  `gh api repos/msm8916-mainline/lk2nd/contents/Documentation/devices.md --jq .content | base64 -d | grep -c '### lk2nd-sm8'`
  → **预期 0**（现状 0）；只有出现 `### lk2nd-sm8xxx` 小节才说明有同代先例。
- **失败回退**：不投入。


---

## §6 未证实项 / 未核实数字

### 6.1 未证实 / 未核实清单

| # | 项 | 为什么未证实 | 消除它的最小动作 |
|---|---|---|---|
| U1 | **XBL 是否验 ABL 签名 / 解锁后是否放宽** | 只有第三方 README 一句（`CrackerCat/abl-patch-toolkit`，1 star，无复现）；本机只证了 `hyp` 受 XBL 校验 | §5.3 ⑤ 第 1 步（原样刷回）→ 第 2 步（1 字节改） |
| U2 | **`abl_a` 是否可写**（`unlock_critical` 是否覆盖它） | 从未尝试写入 | 同上第 1 步 |
| U3 | **本机 9008 真机可用** | `download_mode`=off；DT 补丁已落但从未真机触发 | §5.3 ① |
| U4 | **DDR 训练确由 XBL 完成（ABL 不碰）** | 推断自「ABL 日志里的 RAM 表是*分区*表」+ PBL→XBL→ABL 顺序 | 读 `~/下载/tb322fc/xbl_s.melf` 字符串（纯主机，无需设备） |
| U5 | **`ddr` 分区（`/dev/sdd3`，1 MiB）的用途** | 只有名字 | 同上，`strings` 搜索/与 `xbl_config.elf` 比对 |
| U6 | **kShimC 在 TB322FC 真机"已确认"** | 第三方文档自述；同仓 issue #4 表明构建都还没复现 | 等 issue #4 关闭 |
| U7 | **coreboot 在 Qualcomm 上的具体引导位置**（是否由 XBL 加载） | 官方文档只有 `sc7180/sc7280/index.md`，未读到链路描述；只能由 `util/qualcomm/{createxbl,ipqheader,mbncat}.py` 推断"按 MBN 打包" | 读 `Documentation/soc/qualcomm/sc7180/index.md` 全文 + `util/qualcomm/description.md` 全文 |
| U8 | **U-Boot/lk2nd 移植工作量（4–8 人周 / XL）** | 我按 SM8650 端口规模外推，**没有任何实测** | 需真实评估（不在本 lane 范围） |
| U9 | `index986/sm8750-mainline` 的树内容与许可 | 未取树（>500 MiB 需父审批） | `gh api repos/.../git/trees?recursive=1` 只读元数据 |
| U10 | **Telegram / Matrix / XDA 是否有 TB322FC 引导层讨论** | **检索盲区**：无凭据/无稳定入口，本 lane 未覆盖 | 需用户提供入口，或改用 `web` 搜索（本 lane 未启） |
| U11 | §5.1 的「S/M/L/XL 工作量」分级 | 除 ①（20 行）与 ④（1–2 周，引自既有报告）外，**均为量级估算** | — |
| U12 | `edl.py` 在本机的现存版本/可用性 | 只看技能文档，未跑 `python3 edl.py --help` | 一条命令即可（主机侧，无风险） |

**已核实的具体数字（可复核）**：分区尺寸 6 项（本轮 `blockdev --getsize64`）；固件包 9 项尺寸（`ls -l`）；
`backup/` 内 `boot_b` 备份 3 份各 **100 663 296 B**；EDL 资产总量 ~40.0 MiB（8 个分区相加）；
lk2nd SoC 小节 11 个；U-Boot `sm8750` 命中 69 条 / coreboot 0 条；`sm8750` 在 U-Boot 的
`configs|board|drivers` 命中 **0**。

---

### 6.2 对任务前提的三处更正（都有证据，不是措辞问题）

| 任务里的前提 | 实测/源码事实 | 影响 |
|---|---|---|
| 「coreboot（写清**无 qcom 支持**）」 | **不成立**：coreboot 有 `src/soc/qualcomm/` 8 个目录（`sc7180/sc7280/qcs405/x1p42100/calypso/dougie/ipq40xx/ipq806x`），`x1p42100` 甚至有 `ufs.c`/`pmic.c`/`rpmh_rsc_init.c`/`cpucp_load_reset.c`/`adsp_load_reset.c`（`gh api contents` 2026-10-31）。**准确表述 = 「有 Qualcomm SoC 支持，但没有 SM8750，且端口全是 ChromeOS/WoA 板」** | 「coreboot 不可能」这个结论仍然成立，但**理由变了**：不是"没支持"，而是「无此 SoC + 需过 MBN 签名链」 |
| 「ABL 做 DDR 训练/AOP/PMIC」 | **DDR 训练不由 ABL 做**（ABL 日志拿到的是已初始化的 `Final RAM Partitions` 表）；`ddr` 分区独立存在（`/dev/sdd3`，1 MiB） | 这条**大幅降低 L2 成本**：L2 不必重做 DDR 训练（`未证实`，见 §6.1 U4） |
| 「L2 = 换一个开源 bootloader」 | 本机 ABL **本身就是 EDK2/DXE**（`uefi.elf` 解出 59 个 DXE 模块，含 `UFSDxe`/`BdsDxe`/`SimpleFbDxe`） | L2 的真实工作量 = **重写那 59 个模块的责任集**，不是「移植一个 bootloader」 |

### 6.3 本轮取证事实清单（`已证`，边查边追加）

### F-01 设备当前引导形态 = L0（`fastboot boot` 零写盘）已是既有工作流
- `DEVICE/README.md:1.1`（2026-10-30 13:19 条目）：在机镜像经 `scripts/flash-b.sh` 签名写入 `boot_b` 后**读回校验**
  sha256 `e6b1124c…`；运行根 `/dev/sda17` ext4 `LABEL=linux17`；`ssh root@192.168.7.1` 经 USB-NCM。
- 历史条目（`DEVICE/README.md:1.1` 2026-10-27 段）：`fastboot boot out/boot-elden-vk17x.img` **零写盘进**，
  `boot_b` 未改、回退 = 重启即回原槽。⇒ **L0 不是设想，是本项目日常**。`已证`

### F-02 本机 ABL 本身就是 EDK2 派生物 ⇒「替代 ABL」在架构上不是换 OS，而是换 UEFI 实现
- `reference/uefi-samechip-20261028/NOTES-取证片段.md` + `reports/uefi-consolidated-20261030.md` §0/§2：
  从原厂 `~/下载/tb322fc/uefi.elf`（5 242 880 B）解出内嵌 FV **4 247 560 B / 59 个 DXE 模块**，
  含厂商 `UFSDxe`（`fa561bf1…`，151 552 B）、`SimpleFbDxe`、`BdsDxe`、`GraphicsConsoleDxe` 等。
  ⇒ **本机 ABL 的 DXE 阶段就是 EDK2 模块集合**，`UEFI_BASE=0xFF300000`、`UEFI_SIZE=0x400000` 的 BootShim 交棒模型成立。
  `已证`（本仓库已解包并有 sha）。
- 含义：L2「完整替代 ABL」= **重新实现 EDK2 DXE 里那 59 个模块承担的全部责任**，不是为了换语言/换 bootloader 品牌。

### F-03 L0 已在生产使用：三条零写盘/免引导器路径都是现实
- `fastboot boot <Image>`：`DEVICE/README.md:1.1`（2026-10-27 段）实测零写盘进；`reports/m1-clean-tree-20261011.md` 同。
- kexec：`reports/kexec-target-boots-20261024.md` §0 —— 目标内核**确实跑到 `/init`、挂上 `/dev/sda17`、switch_root 成功**；
  唯一断点是 **GIC ITS 未 quiesce**（`its_map_one()` 拿不回命令队列，129 条 `ITS queue timeout`，到 `/init` 从 ~9 s 拖到 126.3 s），
  不是「没起来」。同文 §3 给出 ITS quiesce 补丁（~20 行）作治根候选。
- 结论：L0 的**收益已被吃掉**，剩余价值在「让 kexec 快环可用」（ITS quiesce），不在「找一个新 bootloader」。

### F-04 U-Boot mainline：**支持 Qualcomm 手机/平板这一类，但 SM8750 无板级支持**
- `board/qualcomm/` 下只有 `dragonboard410c/820c/845c`、`qcs404-evb` + 配置碎片
  `debug-{msm8953,qcm6490,qcs9100,sdm845,sm6115,sm6350,sm8250}.config`、`qcom-phone.config`、`google-pixel.config`
  （GitHub API `contents/board/qualcomm?ref=master`，2026-10-31 查）。
- `drivers/clk/qcom/` 有 `clock-sm8550.c`、**`clock-sm8650.c`**、`clock-x1e80100.c`；
  `drivers/phy/qcom/` 有 UFS PHY（`phy-qcom-qmp-ufs.c` + `pcs-ufs-v6.h`）；
  `drivers/ufs/ufs-qcom.c` 存在。⇒ **UFS/时钟/PHY 这一层在同代（SM8650/X1E）有可用前例**。
- **但 `search/code?q=sm8750+repo:u-boot/u-boot` 的 69 条命中全部落在 `dts/upstream/**`**（U-Boot 自动同步的 Linux DT 子树），
  **没有一条在 `configs/`、`board/`、`drivers/`** ⇒ `sm8750.dtsi` 在树里 ≠ 有 SM8750 板级支持。`已证`（API 检索 2026-10-31）
- 缺什么：无 `configs/qcom_sm8750_defconfig`、无 SM8750 GCC/RPMH 时钟表、无板级 DDR/PMIC 初始化、无 `LinuxLoader` 等价物。

### F-05 lk2nd：支持面**止于 msm8996/msm8953 一代，SM8xxx 一代完全没有**
- `msm8916-mainline/lk2nd` 的 `Documentation/devices.md`（275 行，2026-10-31 取）里 SoC 小节依次为
  `msm8916 / msm8909 / msm8952 / msm8953 / msm8974 / msm8226 / msm8994 / msm8996 / msm8960 / msm8610 / msm8660`。
- **`sdm6xx/sdm8xx/sm6xxx/sm7xxx/sm8xxx` 命中 0**（grep `^### ` 列表 + 关键词检索）。`已证`
- 形态：lk2nd 是**打包成 Android boot.img 由 stock bootloader 加载**（README「Configuration」段原文：
  "it is packed into an Android boot image, which is then loaded by the stock bootloader"）⇒ 即便移植，也是 **L1**，不是替代 ABL。
- 移植代价：lk2nd 依赖 LK 的 `platform/msm_shared`（老式 `devprg`/`mmc`/`dsi`）与 **per-SoC 时钟表 + panel 表**；
  SM8750 需要新增 UFS 4.0 host controller 驱动（LK 只有 `ufs` 老实现）+ CPHY/DSC panel 表 —— 无先例可抄。

### F-06 coreboot：**有 Qualcomm SoC 支持（不是「无 qcom 支持」），但没有 SM8750，且模型不同**
- `src/soc/qualcomm/` = `calypso`、`common`、`dougie`、`ipq40xx`、`ipq806x`、`qcs405`、`sc7180`、`sc7280`、**`x1p42100`**
  （GitHub API 2026-10-31）。
- `x1p42100`（骁龙 X 系列）目录里有 **`ufs.c`、`pmic.c`、`rpmh_rsc_init.c`、`cpucp_load_reset.c`、`adsp_load_reset.c`、
  `qclib.c`、`tsens_map.c`、`display/`、`usb/`** ⇒ **coreboot 在 Qualcomm 上做的事正好就是「ABL 那一层」**（UFS/PMIC/RPMH/协处理器加载）。
  这是「L2 可行」最强的现实先例。
- **但**：这些端口全部是 **ChromeOS / WoA 平台**，DT/时钟/PMIC 表按那些板子写死；`search/code?q=sm8750 repo:coreboot/coreboot` **0 命中**；
  `util/qualcomm/createxbl.py` 说明其产物是**按 XBL/MBN 格式打包**（即沿用高通签名链的装载约定），不是「随便刷进 abl 分区」。
  ⇒ 对 SM8750 属「同一架构、不同 SoC」的**从零移植**，不是配置工作。

### F-07 depthcharge / systemd-boot / GRUB：都要求先有 EFI 或 coreboot，属**payload 层**
- `depthcharge` 是 ChromeOS 的 **payload**，由 coreboot 以 `coreboot + depthcharge` 组合运行；没有 coreboot（或等效 EFI）就无从加载。
- `systemd-boot`/`GRUB(arm64-efi)` 需要 **EFI runtime** ⇒ 只有 L2 的 UEFI（Mu/EDK2）成立后才有意义；
  在 `fastboot boot` 裸 Image 的 L0 形态下完全用不上（内核直接起，没有 EFI stub 调用者）。
- ⇒ 这三者在本项目**当前不是候选**，而是「L2 成功后的下游选项」。`未证实`（推断自各自架构，未在本机验证）

### F-08 Mu-Silicium（同 SoC 手机已跑 Linux）的装载位置 = **boot 分区，不是 abl/xbl** ⇒ 它是 L1
- `reference/uefi-samechip-20261028/Mu-Silicium-Status-SM8750-section.md`：SM8750 段落里的 OnePlus 13（`dodge`）
  UEFI 状态 Display/Internal Storage/USB Device Mode/Mass Storage/**Linux Boot = ✅**，Linux 需 mainline 内核
  （`index986/sm8750-mainline`），有 postmarketOS wiki 页。
- 这与本项目 `uefi-consolidated-20261030.md` §1 的 10-05 结论一致：**镜像以 `fastboot boot` / boot 分区载荷形式进**，
  即 XBL+ABL 仍在位、只替换「ABL 之后加载什么」。⇒ **Mu 的天花板就是 L1**；它解决的问题（UFS 初始化、GOP、Linux 引导）
  正是本项目 UFS 两层故障卡住的地方。`已证`（上游状态页 + 本项目 10-05 亮屏）

### F-09 生态检索（2026-10-31）：SM8750「开源 bootloader」只有 ABL **打补丁**类，无替代类
| 项目 | URL | 日期 | 内容 | 证据等级 |
|---|---|---|---|---|
| `CrackerCat/abl-patch-toolkit` | github.com/CrackerCat/abl-patch-toolkit | 创建 2026-08-15，push 2026-08-14 | 对 ABL 内 `LinuxLoader.efi` 打 2 处字节补丁（`0x450B0` ADRL、`0xec4a8` 字符串表），让 `androidboot.vbmeta.device_state` 恒为 `locked`；自称 5 字节差异 | **未证实**：仓库 32 KB、1 star、无 issue/无第三方复现、目标机型非 TB322FC；且**这是「骗检测」不是「换引导器」** |
| `Exo1i/opd2415-…-ksu` | github.com/Exo1i/opd2415-6.6.118-cve-2026-64560-ksu | 2026-10-27 | OnePlus Pad 3（OPD2415，**SM8750**）**锁定 BL** 下用内核 CVE 后载 KernelSU | **未证实**（与本 lane 无关，仅说明「同 SoC 平板有人做内核层，不做 bootloader」） |
| `index986/sm8750-mainline` | 见 Mu-Silicium 状态页引用 | 2026-10 | SM8750 mainline 内核树（被 dodge 的 Linux Boot 依赖） | **未证实**（未取树；对本项目价值=参考 DT/驱动，不是 bootloader） |

⇒ **结论：截至 2026-10-31，没有任何公开项目在 SM8750/8 Elite 上替换过 ABL 或做出第三方开源 first/second-stage bootloader；
唯一的同 SoC「开源固件」成果是 Mu-Silicium 的 UEFI（L1 形态）且只在手机上、平板未证。**

### F-10 EDL 回退资产：**软件侧齐备，真机触发未验**
- 本机固件包 `~/下载/tb322fc/`（599 MB，65 项）含：`abl.elf`（1 048 576 B）、`xbl_s.melf`（3 670 016 B）、
  `xbl_config.elf`（352 256 B）、**`xbl_s_devprg_ns.melf`（1 697 740 B，`ns` = 免签名 EDL programmer）**、
  `tz.mbn`、`hypvm.mbn`、`uefi.elf`、`uefi_sec.mbn`、`devcfg.mbn`、`aop.mbn`、`shrm.elf`、`qupfw` 类、6 套 GPT（`gpt_main0..5/gpt_backup0..5`）。
  ⇒ **「刷坏后能不能回到原样」在文件层面是 YES**（但这依赖 EDL 通道本身可用）。
- EDL 通道：`reports/twrp-parity-edl-dload-20261020.md` §1 —— DT 缺 `qcom,dload-mode` 的根因已修（`patches/edl-dload-20261020/`），
  `dtbs` rc=0、`dtbs_check` 0 诊断、dry-run 读到参数文件（当前 `off`）；**真机 9008 触发未验**（原文「未做：真机 EDL 触发验证」）。
- ⇒ 现状 = **`未上机`**：有产物、有链路分析、无真机证据。
