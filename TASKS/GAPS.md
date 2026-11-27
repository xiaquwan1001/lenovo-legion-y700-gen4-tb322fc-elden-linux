## 5. 查漏补缺（GAPS）

> **★镜像件口径（2026-11-11 回填，`reports/project-audit-20261111.md` §1）**：本节各历史块里提到的
> `out/r21-sbstop-p*/uefi-preamble*-r1.img` 等件**已于 2026-11-10「发送清理」会话删除**（释放 7.39 GiB），
> 同批 `out/boot-elden-*.img` 多数只剩同名 `.manifest`（2026-11-05 `out/` 归档 + 11-10 清理）
> ⇒ 这些路径一律以「`out/<件名>.manifest` + `versions/vk-kernel-identity.tsv` + 对应会话记录」为证据，
> 配方/补丁在 `patches/`（UEFI 系在 `patches/uefi/`）。别再按块内原路径找件。

### 沿革索引（2026-10-30 → 2026-11-10；49 个历史块，原文已全部下沉）

> **块号约定**：`NN` ⇔ `sessions/2026-11-13-TASKS5沿革-NN.md`（37 块，一块一文件）；其余块在表内直写路径。
> **2026-11-19 搬家**（`reports/doc-slim-plan-20261118.md` §3 C3）：最后 12 个仍带**内联正文**的块逐字搬到 `sessions/2026-11-19-TASKS5内联块下沉.md`；下方表只留「日期 → 要点 → 全文」。
> 每块里的作废/更正标记**随正文一起搬**，不在本表复述；状态数字口径仍只看 §0。

| 日期 | 块 | 要点（原文标题关键词） | 全文 |
|---|---|---|---|
| 2026-11-10 | 02–04 | p69/R70 计时判据被硬复位剪断（矛头指向 `vbmeta_a`）；**`dtbo_a` 真根因 = Android DTBO overlay（flashed 形态打通）**；p67/R68 信标 v3（连 BdsDxe 都没跑到） | `sessions/2026-11-13-TASKS5沿革-{02,03,04}.md` |
| 2026-11-09 | 01、05 | R63 分区普查 + 按 GPT 名定位 ESP（零写盘一发）；flashed 形态 4 发全败 + `p60` 对照同败（落盘信标 v1 废 / v2 判不了哪一发） | `sessions/2026-11-13-TASKS5沿革-{01,05}.md` |
| 2026-11-08 | 07–11 | 路线 B 打通（ESP `boot.img` 被 Mu `LinuxLoader` 直接读起）；启动菜单闭环 + 落地第一发；首试 indeterminate；ESP+GRUB 菜单出来但 EFI-stub 撞墙；arm64 GRUB 备料 + QEMU 端到端 | `sessions/2026-11-13-TASKS5沿革-{07..11}.md` |
| 2026-11-07 | 06、12–18 | 间接引导打通（真因 = `SdccDxe` 抢初始化 SD 主控）；「关硬件看门狗」三路全证伪；交棒成立 / 令牌进 cmdline；漏 `fastboot continue`；探针调 boot service | `sessions/2026-11-13-TASKS5沿革-{06,12..18}.md` |
| 2026-11-06 | 19–26 | `logfs` 持久化窗口；已调用到 `LinuxKernel()`；真崩溃真因 = 自家探针写屏；屏显 NULL 崩；`LinuxLoader` 的 `SerialPortWrite`；首次全场走通到跳内核 | `sessions/2026-11-13-TASKS5沿革-{19..26}.md` |
| 2026-11-05 | 27、28 | R21 取证通道改走 fastboot 响应；判据彻底改为「宿主可读」（崩溃点收敛到 `LoadImageAndAuth` 前导 3 步） | `sessions/2026-11-13-TASKS5沿革-{27,28}.md` |
| 2026-11-04 | 29、30 + 4 块 | 路线 D（FV 内 `LinuxLoader` 没人启动）；DXE 全走完/UFS 枚举成功但无 ESP；ramoops 主机可读判据；DxeCore 真进场 / 从未被启动；载荷被执行 → PrePi → DXE | `sessions/2026-11-13-TASKS5沿革-{29,30}.md` + `sessions/2026-11-04-UEFI-DXE走完到BDS之后的handoff.md` + `sessions/2026-11-04-UEFI载荷首次被执行.md` + `sessions/2026-11-19-TASKS5内联块下沉.md` |
| 2026-11-02 | 31 | UEFI「载荷到底有没有被执行」四臂判别，全部为 0 + 更正一条错判 | `sessions/2026-11-13-TASKS5沿革-31.md` |
| 2026-11-01 | 归档 §1–§3 | 判据纠正（「交棒条件」是 header 产物、7 发载荷从未执行）；槽位正常启动 → 只进 fastboot；EDL `peek` 本机不可用（改切断回落+回读） | `sessions/2026-11-02-UEFI历史块归档.md` §1–§3 |
| 2026-10-31 | 归档 §4–§8、32–36 | 暂停深入（用户裁决）；控制组+R2 / R1 / 四通道 / 2×2 补全（多数已按 `PITFALLS #480–#482` 作废）；启动提速 net-selfheal；三封回信 + wl2868c v4；四 lane 轮（vk183）；阻塞项 lane | `sessions/2026-11-02-UEFI历史块归档.md` §4–§8 + `sessions/2026-11-13-TASKS5沿革-{32..36}.md` + `sessions/2026-11-19-TASKS5内联块下沉.md` |
| 2026-10-30 | 37 | 新增待办与并行安排 | `sessions/2026-11-13-TASKS5沿革-37.md` |

### 1. 待调查（Open questions，按优先级）

> **编号以表内为准**（Q27 从无此号；不在此写死连续区间）；**Q27 从无此号**（历史「G1-34 / §5 Q27」为幻影引用，已随 2026-10-10 清理移除）。
> **2026-11-14**：已归档/已结项的四行（Q25/Q31/Q32/Q3）从「整段沿革」压成「当前口径 + 指针」，原文逐字沉到 `sessions/2026-11-14-TASKS-5-Q行沿革下沉.md`。

| ID | 未知 | 为什么要知道 | 怎么测（最小实验） | 关联任务 |
|---|---|---|---|---|
| ~~**Q22**~~ | ~~**vk34（2026-10-01）之后未逐版验证的内核增量**~~（5 文件：DTS 分级热 trip + `q6apm.c`/`q6prm.c`/`audioreach.c`/`q6apm-lpass-dais.c` + `config-vk40-bringup`） | 决定 G1 基线是否可信（曾是「AI 难以稳固推进」的核心） | ✅ **已无剩余动作（2026-10-26）**：「增量=熄屏复位源」已由 Q24 根因取代；最后一个子项 vblank/PPM 残留复核已闭合（三窗 47.5 min 全 0，见 §1 G1-23 行）。**三轮取证全过程只在 G1-23，此处不复述** | **G1-23**；`archive/topics/AUDIT-since-vk34-2026-10-03.md`、`AUDIT2-post-vk34-bisect-2026-10-03.md`、`AUDIT3-polling-sideeffects-2026-10-03.md` |
| **Q21** | ~~桌面空闲熄屏（DPMS blank）→ 整机重启~~ **已归因（2026-10-07）→ 并入 Q24**（~~根因=单模块 `cambistmclkcc-sm8750`，仍未根治~~ **2026-10-23 更正：根因 = RPMh rail retention 档，已指名并结项，见本表 Q24 行**） | 与 DP/altmode（G1-9）不同源 | 已由 60+ 轮模块二分 + H1 实锤 | **G1-22 🟢 / Q24 ⛔（已关闭）** |
| ~~**Q23**~~ | ~~Linux 侧 reboot→fastboot 的触发点~~ **已解决（2026-10-03 深夜）** | 已定 G1-24 路线 | **实测结论**：PMIC SDAM `reboot-reason@48`、`misc` BCB `bootonce-bootloader`/`boot-recovery` **均不被 ABL 采纳**；**PSCI SYSTEM_RESET2 vendor reset 被采纳**（`mode-bootloader=<0x80010001 0x2>`、`mode-edl=<0x80000000 0x1>`，无 recovery）。落地 = `elden/vk41-psci-reboot` 最小钩子（`psci.c`）；`reboot bootloader` → fastboot **实测成功**。EDL = TCSR DLOAD cookie（`qcom,dload-mode=<&tcsr 0x19000>`）。**2026-10-20：EDL 根因已定位并修好**——先前「本机不支持 EDL」的归因是错的：EDL 不走 reboot-mode magic，而走 `qcom_scm` 的 `download_mode`（TCSR `0x1fc0000+0x19000`）；我们 `sm8750.dtsi` 既无 `qcom,dload-mode` 也无该 TCSR 块 ⇒ 地址恒 0。已按原厂 DTB + 上游 kaanapali 三源对齐新增 `tcsr: syscon@1fc0000` 并挂 `qcom,dload-mode`（`patches/edl-dload-20261020/`，`dtbs` rc=0、`dtbs_check` 0 诊断），`eldroid-bootctl reboot edl` 改为真实实现；**真机 9008 触发未验**（需用户同意承担一次进 EDL）。另：槽位/计数已与 QTI `gpt-utils.h` 逐位核对等价，无需替换；TWRP 的 BCB 通道本机实测不被 ABL 采纳，不采用 | **G1-24**；`archive/topics/FLASHCTL-2026-10-03.md` §7–§9、`reports/twrp-parity-edl-dload-20261020.md` |
| **Q25** | 🔒 **已归档（2026-11-10 深夜随 G1-29 收口）**：UEFI 两种形态都通，flashed 真根因 = `dtbo_a`（与 UFS/UFSDxe 无关）⇒ 不需要 tiny DXE；上游 `#12` 两条回帖已闭环（含 2026-11-13 的 UFS 枚举 `BlockIo=119` 结论）⇒ **本 Q 无剩余动作** | 决定将来是否重启 UEFI 方向；**当前不阻断主线** | 无（已归档；重启判据见 §4 N1） | **G1-29**（状态见 §1 该行）；历史取证链（`0x402` 反汇编定论、`UFS.c+2326`）→ `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q25、`reports/uefi-restart-20261021.md`、`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md` |
| **Q24** | **桌面熄屏（DPMS off）→ 整机硬复位/断电** | ⛔ **关闭·不值得取证（2026-10-24 用户裁决）**：不再做任何取证（含原保留的 `vk149` 臂，**取消**）—— 根因已指名且日常线免疫，继续取证无判别力 | 装相机模块后长时空闲不断电 —— **2026-11-27 已实测通过**（相机常驻 + DPMS off 10 min 零复位；`reports/q24-cam-on-retire-20261127.md`） | G1-22 / G1-33；逐轮证据 → `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q24、`TASKS/sessions/2026-11-03-TASKS行443-Q24.md`、`reports/q24-suspend-hypothesis-excluded-20261019.md`、`reports/q24-n7-vk127-20261017.md`、`PITFALLS` #197–#212 / #282–#289 / #294–#295 |
| **Q26** | ~~WiFi 关联后 IPv4 约 140 s、每 16–18 s 周期掉线~~ | ✅ **已关闭（2026-10-10 用户实机确认 WiFi 正常，关联即可用）** | 已无需再测（关闭项不从「怎么测」再取样本） | 历史排查全文 → `archive/topics/history-chain-tasks5-20261014.md` §Q26 |
| **Q28** | **面板 init 间歇失败 → 只有背光无桌面**（在机镜像口径**只在 `DEVICE/README.md` §1.1 维护**，此处不写死镜像号） | 🟢 **已规避·结项（2026-10-24 用户裁决，补采样门槛作废）**：**坏发 ~50%、逐启动随机、按时间成簇（会话级）**、**与镜像/构建身份无关**（旧「构建身份伪影」作废）；七臂 vk116–vk123 全否证；**故障态不在 DSI 控制器内部**；日常靠看门狗兜底（~50%→~75%）。结项样本 = 真 POR 5/5 + 暖复位 3/3 = **8/8 无坏发** | 冷起后 `card0` 在 + 面板实测有画面（非仅背光）；`fastboot getvar all \| grep -c "psci: SYSTEM_RESET2"` = 0 可作「本发是真 POR」的硬判据 | `reports/q28-DOSSIER.md`（SSOT）、`reports/q28-INDEX.md`（文档地图）、`reports/q28-dsi-recover-20261012.md`；寄存器级与逐轮细节 → `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q28、`TASKS/sessions/2026-11-03-TASKS行445-Q28.md` | ⟪全文见 `TASKS/sessions/2026-11-25-§5Q28三卷底账下沉.md`⟫
| **Q31** | ~~M1 7.3-rc7 重基树「管道全绿但面板只有背光」~~ | ✅ **已解（2026-10-14，E1b）**：`writel(0xc0, PLL_SYSTEM_MUXES)` 放进 `dsi_7nm_phy_enable()` 预置块（refcount 不动）⇒ 干净 POR 面板有内容 + 触屏可用；根因 = 上游 `44784327815b` revert 了 bonded PLL init（`PLL_SYSTEM_MUXES=0xc0` 永不写入），我方净差异 = **1 行语义** | 同窗口 `vk94` 对照；机上验收 `reports/trials/20261014T115840Z-m1-baseline.json`（`Run /init` 7.67 s、`card0-DSI-1` connected、用户目视面板+触屏） | `reports/m1-73-e1b-pllfix-20261014.md`、`patches/m1-73-e1-pllfix.patch`；历史口径 → `archive/topics/history-chain-tasks5-20261014.md` §Q31；**M1 / §7** |
| **Q1** | **容器内的 GMS 身份 / Play Integrity / Widevine 能做到哪一级**（不作猜测，先取证） | 决定 G2 兼容上限与是否需要 VM/换路线 | 复现三条社区做法各一次（只变一个变量）：① Waydroid + GApps；② 未认证设备注册；③ Widevine L3 注入。**本机取证**：GMS 登录 ✅、Google 连通 ✅、**Widevine 不存在**（只有 ClearKey）、`build=test-keys/userdebug` ⇒ 不加对策 PI device 必失败；STRONG **结构性否证**（无 TEE、keymaster 4.0 软实现）。**★2026-11-10 书面收口 = `reports/c3-pi-tiers-closeout-20261110.md`**（三档结论 / 结构性否证三条 / 换路线净增益 0 / 唯一剩余动作 = 一次 SPIC 回包） | **C3**；社区侧与逐轮证据 → `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q1、`TASKS/sessions/2026-11-06-TASKS行411-Q1.md` |
| Q2 | ~~Waydroid 在 **vk40** 上是否不再需要旧 workaround~~ **✅ 已答（2026-10-11，vk64）：仍必需。** 去 workaround 后容器只有链路路由、无 default；`ip rule` → `Operation not supported`（`CONFIG_IP_ADVANCED_ROUTER` 仍 not set）。要根除需开该 config（连带 `IP_MULTIPLE_TABLES`）重编内核。**🆕 2026-10-11 vk95 已开该 config：`ip rule` 上机生效（`local/main/default` 三表），内核侧根修完成；容器端到端（去 workaround 出网）待 Q28 GOOD 启动复测**（见 `reports/c1-iprule-vk95-20261011.md`）。附带发现：vk64 部署模块目录缺 `net/` 核心模块（bridge），已补（`PITFALLS #184`）；模块化 ramdisk 管线也已补齐 net/veth/fuse | 少一处 bind-mount 脆弱点 | 已实测（§C1 行） | **C1** |
| Q3 | **droidloom**（Linux 原生跑 Android 应用，Wayland 直出窗口）在 arm64 宿主是否可用 | 形态优于容器（无需 Android 镜像） | **结论：维持「只跟踪」**（2026-11-11 口径，三次复核逐版收窄）：① 上游自修订 27 起**有 aarch64 包**（最新 `0.1.0-30`）⇒ 自构建不再是唯一路径；② 合成器门槛只剩 `wp_linux_drm_syncobj_manager_v1`（phoc 补丁 + aarch64 二进制已在 `out/phoc-syncobj-arm64-20261111/phoc`）；③ 内核前置已通（`vk187b` 上机 nftables，`ready=True blockers=0`）；④ **L1–L4 全绿**（`vk187b` 上 applications 列出 2 个 Android 应用、Settings 上屏 = 用户目视）；⑤ 身份/完整性上游明确免责 ⇒ 对 G2 硬验收**无净增益**（五维：可用性 1/5、图形 2/5、输入 2/5、音频 3/5、身份 0/5）。复启判据 = R1 受阻或需要「无 Android 镜像」形态 | 逐轮证据 → `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q3、`reports/droidloom-feasibility-20261108.md`、`reports/droidloom-l2-phoc-syncobj-20261111.md`、`TASKS/sessions/2026-11-11-droidloom-L3-上机打通.md`；**C12** |
| Q4 | **无 KVM 前提下 VM 路线值不值得投**（**书面评估已完成 2026-10-02**，结论见 TASKS C8） | 决定要不要开第二条腿 | 结论：**维持低优先**。① 设备侧 KVM 不可达（XBL 在 secure-boot 链内加载 hyp，主线 `-el2.dtb` overlay 只适用 Qualcomm dev kit，ABL 重签救不了——hyp 加载点在 ABL 上一级）；② 独立 gunyah 驱动（v17）未进主线（本地 7.2 树 `drivers/virt/` 无 gunyah 目录）；③ 唯一新路线 = KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，2025-04，配 `qemu-for-gunyah`），WIP（pinned pages/无 guest_memfd/禁 swap）。**决定性上机实验**：vk40 起机后 `dmesg \| grep -i gunyah`（本地 qcom_scm 已带 gunyah UUID 探测）——通则路线第一步成立，败则归档 | **C8**（🟡 书面结论已出；**2026-10-25 终结 = 不可行，见 §4 N2 终局裁决与 `reports/gunyah-decision-20261025.md`**） |
| **Q5** | **真 Android 对照基线**（一旦覆盖 a 槽就不可复得）：GMS 属性 8 段、Widevine 级别、7 颗传感器读数曲线、目标 App 行为 | 兼容层的"标准答案"，也是判定容器是否等价的尺子 | ✅ **主体已采（2026-10-11，U2 a 槽 stock，报告 `reports/c0-android-baseline-20261011.md`）**：`getprop` 全量、Widevine **L1**（`dumpsys IDrmFactory/widevine`）、42 传感器清单、分区/包、AVF apex、账号（0）。**剩**：30 s 传感器 CSV、5 App 录屏（均为 App 行为项，与 root 无关）。**PI 判定不属本基线**（对象 = Waydroid 容器 → §2 C3）。U1 a 槽（stock+root）可另采；root 专属项已判定无产出、不补采（2026-10-13） | **G2/C0**；`backup/HA2EXB0E-16+512/c0-baseline/` |
| Q6 | 兼容层验收的**量化判据**——**已定稿（2026-10-02，A15）**：10 条用例+阈值见 `README.md §6` §5 | 避免"看起来能用"的自欺 | 上机后按用例表逐条实测打分（打分模板同处） | **C9**（模板就绪） |
| Q7 | ~~Linux 分区到底要多大~~ **已解决（2026-10-03 G1-2）** | GPT 手术一次给足，避免二次缩容 | 实测划定：`linux17`=193 GiB（CRC 校验过），估算表在 `../DEVICE/README.md` §3.1 | G1-2 ✅ |
| Q8 | ~~音频是否真的可听 + 有无录音通路~~ **已解决（2026-10-04 G1-4）** | G1 硬验收 #4 | 实测：`amixer cset numid=8 on` 后扬声器出声 ✅；`arecord -D hw:0,2`（AMIC1）采集 ✅，UCM2 Mic | G1-4 ✅ |
| Q9 | ~~相机能否真正出流（graph ENABLED ≠ 有帧）~~ **已解决（2026-10-05 G1-5）** | G1 硬验收 #5 | 实测：前后摄 `v4l2-ctl --stream-mmap` 连续出帧 rc=0，帧尺寸精确吻合 | G1-5 ✅ |
| **Q15** | **解锁 U2 的两个不可逆代价**：① Widevine **L1→L3**（现 `sys.lenovo.widevine_security_level=L1`，属 TEE 内密钥，社区主流案例为永久降级）——它正是 Q1/Q5 容器侧 DRM 上限的「标准答案」；② 保修 + FOTA。**两台单元现均已解锁**（U1 2026-08-16 / U2 2026-10-03；U2 实机现 `flash.locked=0`） | 先拍基线再解锁，否则事后无法对照；且影响 G2 的 U5 用例上限 | ✅ **已执行（2026-10-03）**：`scripts/bl-preunlock-evidence.sh HA2EXB0E` → `backup/HA2EXB0E-16+512/pre-unlock/`（getprop 全量/by-name/传感器清单/settings/Widevine=L1 + SHA256SUMS）；解锁后重测同一项做对照 | **G1-0**、Q1/Q5 |
| **Q32** | ~~暖起 vs 冷起的差异~~ **已结项（2026-10-24）：五发判据表已成（W1×2 / C1×2 / W2×1 全 GOOD、无入口差异）⇒ 并入 Q28，不再单列** | 已并入 Q28 | 无（已结项） | 立项记录/逐发数据 → `TASKS/sessions/2026-11-14-TASKS-5-Q行沿革下沉.md` §Q32、`reports/q32-warm-vs-cold-preresearch-20261023.md`、`PITFALLS #166`；在机镜像只读 `DEVICE/README.md` §1.1 |
| ~~**Q16**~~ | ~~三代「模板改 SN 自造解锁 blob」在四代 259 上是否有效~~ **已结（2026-10-03）：无效。** 四代 1.5.x ABL 换内嵌 key，**任何** sn.img（官网/三代免签模板/第三方签名）都过不了；且 **1.1.11.120 / 1.5.x 本身就不开放解锁命令**（版本门）。正解 = 降级 1.1.11.073 后 `fastboot oem unlock`（U2 已实测一次成功，无需 sn.img） | 不影响 G1（EDL 路不受 lock 位限制） | 已验证；`PITFALLS` #86、`RUNBOOK` §0.5 ★权威顺序、复盘 `archive/topics/复盘-2026-10-03-BL解锁.md` | 已结 |
| ~~**Q18**~~ | ~~第三方签名四代 blob（356 B）能否过 259 的 ABL 验签~~ **已结（2026-10-03）：不通过**——`flash unlock` OKAY（伪分区，不算数）但 `oem unlock-go` 失败；离线 18 组合验签全败 ⇒ 四代 ABL 换 key。**结论：买/求签名文件对 1.5.x 无用**；blob 与取证保留作证据（`backup/HA2EXB0E-16+512/sn-neko-zuxos.img`、`sn-neko` 取证 §5） | 已关：G1-0 靠降级解决 | `PITFALLS` #84/#86 | 已结 |
| ~~**Q17**~~ | ~~locked 态下「EDL 直写 + testkey 自签链」能否把 b 槽引导起来~~ **不再阻塞（2026-10-03）**：U2 已解锁 → 本实验从「必需」降为「可选」；`scripts/build-locked-chain.sh` 离线验证全绿，**真机未验**（无 locked 单元） | 若将来拿到 locked 新单元且想保住 Widevine L1/保修，本实验仍可取代解锁 | 照旧：`qdl` 写 `boot_b`/`dtbo_b`/`vbmeta_b` 后从 b 槽引导；失败留屏幕状态/日志 | G1-1（可选） |
| Q10 | TF 卡间歇写丢失是卡、还是 `sdhci-msm` flush/cache | ✅ **倾向「卡本身」（2026-10-26：新卡 3 轮 0 不一致 + `err_stats` 全 0 + fsck clean；ios 37.5 MHz/4-bit/SD_HS）；旧卡废置 ⇒ 不做驱动侧补丁选择** | 无需继续（仅新坏卡出现时重开） | G1-6 |
| ~~Q11~~ | ~~DP 输出被 `disabled` 的 ADSP altmode/UCSI 能否修好~~ **已结（2026-10-07）：与 UCSI 无关**——真因 = `dwc3_drd_init` 仅在 `dr_mode=otg` 时跑（本机 DTS 写死 `peripheral`）⇒ role switch 未注册 ⇒ `ucsi_init` EPROBE_DEFER 放弃；ADSP UCSI PPM 本身可通 | 外接显示能力（已解） | —（定案见 G1-9 根因链三步） | G1-9 ✅ |
| Q12 | 温控缺 OEM 层（`lenovo,sys-temp`/BCL）会不会在长期负载下露短板 | 安全边界 | 长时压测（≥2 h）+ `thermal-watch` 采样，看壳温与限频层级 | G1-8 附带 |
| **Q13** | ~~AVF 资产（crosvm/vm/microdroid_kernel/u-boot.bin）主机上找不到~~ **已解决（2026-10-04，离线提取）** | C8/R2 VM 路线的地基资产 | 不需设备：从原厂 259 system 镜像 `/mnt/Samsung/l2/system_a.pristine.img` 的 `/system/apex/com.android.virt.apex`（87.8 MB）debugfs 提取 → `backup/avf/`（crosvm 含 **Gunyah** 后端、microdroid_kernel **6.6.77-android15-8**、u-boot.bin/rialto.bin/initrd 全；SHA256SUMS）；`scripts/extract-avf-assets.sh` 可重跑 | ✅ 资产部分已闭；**a 槽覆盖前真正不可复得的只剩 C0（真机 getprop/DRM/传感器/App 行为）** |
| **Q14** | ~~**C4 UDP HAL 上机三未知**~~ **✅ 已解（2026-10-11，路线 C）**：① 宿主↔容器 UDP 可达（宿主发 52012 即达，无防火墙阻挡）；② 路线 C 不涉 `/vendor`/overlay，无 SELinux context 问题；③ 传感器名/映射由 daemon `getSensorsList` 决定。实测 6 h/w sensors running + UDP 喂值出事件 + 自动旋转监听连接 | C4 验收前置 | 已实测（§C4 行、`reports/c4-route-c-20261011.md`） | **C4 ✅** |
| ~~**Q19**~~ | ~~locked b 槽实验三未知~~ **已结（2026-10-03）**：U2 走降级路解锁成功（`fastboot oem unlock`），locked 实验不再需要；三未知答案归档：① U2(259) vbmeta_b 顶层=8fcb864f；② 1.1 与 259 的 vbmeta 顶层/boot chain key 均为 **AOSP testkey 2597c218**（私钥在手），rollback 均 1738713600/0；③ dtbo 无 hash 校验需求由自造 vbmeta 控制。路 C 管线保留作资产 | — | — | 已结 |
| **Q29** | ~~容器 vendor 镜像 Mesa 与宿主 bind Mesa 重叠~~ **✅ 已核对并简化（2026-10-23）**：`debugfs` 从 `vendor.img` 抽出 `config_nodes` 涉及的 **11 个**文件与 `/root/wd/mesa/...` 逐一比对 ⇒ **9 个逐字节 SAME**；剩 2 个（`lib64/libgallium_dri.so`、`lib64/hw/vulkan.freedreno.so`）**同尺寸、不同 build-id**，但**段级 `.text`/`.rodata` 相同**，只有 `.eh_frame*`/`.plt`/`.got.plt` 与 build-id 不同（同源两次构建）。⇒ **删除 `config_nodes` 里 `waydroid-mesa-swap` 段全部 11 条 bind**（备份 `config_nodes.bak-q29-20261023-221233`），起真实桌面会话实测 **`GLES: freedreno, Adreno (TM) 830, OpenGL ES 3.2 Mesa 26.1.8`**，容器 `/vendor/lib64/libgallium_dri.so` = 镜像内那份（mtime 2026-10-13 12:03）⇒ 图形栈正常。**（附）容器内录音「app 级」已可用**：修 emulated storage（见 Q30）后，自带 `org.lineageos.recorder` 无头驱动出 m4a。| 容器图形一致性（已闭） | ✅ 已核对 + 已简化 | `reports/closeout-q29-backlight-camera-20261023.md` §1、`PITFALLS #190` |
| **Q30** | ~~容器内 emulated storage 不可挂~~ **已修（2026-10-11）**：`sm list-volumes`=`emulated;0 unmountable`，全部写外存的 app（含自带 Recorder）`getExternalFilesDir()` 返 null。根因=容器缺 `/dev/fuse`（宿主有，但 `config_nodes` 生成时它还不存在 ⇒ `lxc.py make_entry("/dev/fuse")` 跳过）。修=`config_nodes` 加 `/dev/fuse` bind + `/etc/modules` 加 `fuse`；修后 `emulated;0 mounted`、Recorder 可存 m4a。 | 容器存储完整性（G2/C4） | ✅ 已修 | `reports/container-audio-20261011.md` §5.6 |
| **Q20** | **流程病：引导链问题先外部取证/自研、后本地检索** ⇒ 把 7、8 月已定的结论（版本门、.120 trap、失败特征串、**U1 已于 2026-08-16 用降级路解成功一次**）在 10-03 重新发现一遍，多花一轮必败实验。根因：`references/*.md` 正文不入上下文，**不 grep 等于不存在**（`PITFALLS` #87） | 上不设防就会再犯（下次是新 ROM 版本 / 新单元 / AVB 参数） | 已落：① `AGENTS.md` 新增「本地优先」规则；② `RUNBOOK` §0.5 ★权威顺序置顶（含版本门与停手串）；③ 本文末一条 grep 命令作开场强制动作；④ 引用旧成功记录先查单元+固件态 | 流程（无单元依赖） |

| **Q33** | **WCD939X 冷起 5425 行 `ASoC error (-16)` 读重试（耗 20 s）** | 音频最终可用，但启动多等 20 s、并刷屏 | 抓调用栈/调用者（T139 音频卡初始化上下文），确认 `soc_component_read_no_lock()` 的 EBUSY 来源（regmap 在 runtime-suspend 时读）；复现命令见 `reports/vk163-por-boot-latency-20261026.md` §3 | T21 / G1-4 / `PITFALLS #421` |
| **Q34** | **`bluetoothd` 冷起偶发 crash**（`systemctl restart bluetooth` 后正常；原记为 Alpine `rc-service bluetooth stop/start`） | 冷起后蓝牙不可用，需手动重启服务 | ✅ **已定案（2026-10-28 现场复现）= 不是 crash，是 WCN7861 外设固件缺文件**（`PITFALLS #454`）：`bluetoothd` 一直 active，`hci0` DOWN / BD 全 0、`Direct firmware load for qca/tmel_peach_20.elf failed with error -2` ⇒ `Peripheral setup failed: -2`；设备 `/lib/firmware/qca/` 只有 4 个文件（少 tmel）。补文件 + `modprobe -r hci_uart; modprobe hci_uart` ⇒ `hci0 UP RUNNING` / BD `22:22:62:9C:97:58` / `QCA setup on UART is completed`；**重载服务或重载模块都不解决，必须补文件**（旧「restart 就好」与本次不同源）。根治 = `elden-firmware` 加 `local-extras.tsv` + 新门禁 A2「驱动 `MODULE_FIRMWARE` 声明的厂商固件必须进包」（负向测试已验证）。原判据存档：若为 D-Bus 名抢占则在 `bluetooth` 服务加 restart/调序 | T21 / G1-7 / `PITFALLS #420` 邻近 |
| **Q35** | **双口能否「长边跑数据 + 短边快充」** | ✅ **已判定（2026-10-29 实测）= 物理可行、被 ADSP 选口策略挡住**：只留短边 PD 时电池 **12.2 A**（capacity 19%→27%，≈46 W）；两口同插则只吃长边 SDP 0.891 A。内核逐口建模（两 `typec/port*` + 两 `ucsi-source-psy-*` + 两颗 SMB1501）⇒ 不是「内核只认一口」；`qcom-battmgr-usb` 只读跟随被选中的那口，AP 无控制面 ⇒ **归因固件（ADSP 策略）** | 不阻塞 G1/G2；反向接法「PD 长边、数据短边」已观察到数据与充电并存；快充和热切换待验证（见 `DEVICE/README.md` §1.4；M3-1 仲裁的必要性未证实） | **不再投入**（除非将来 ADSP 侧提供选口接口）；事实正文只在 `DEVICE/README.md` §1.4，采样与判据 = `reports/usb-dual-port-test-protocol-20261029.md` §8 | 不需要单独任务行 |
| **Q36** | **硬件视频解码（qcom iris / SM8750）不可用** | `/dev/video*` 零个 ⇒ Moonlight V+ 等一切要硬件解码的客户端只能软解（1080p 软解可用，4K 不行） | 触发场景 = 2026-11-27 部署 Moonlight 后 V+ 报「检测不到硬件解码」。**已定因**：DT `soc@0/video-codec@aa00000` 存在且 `compatible="qcom,sm8750-iris"`，但 `status="disabled"`（上游 sm8750.dtsi 注释：iris 固件厂商签名，只在有签名固件的板子开）；`CONFIG_VIDEO_QCOM_IRIS=m` + `qcom-iris.ko` 都在位。治本三项 = ① 从 Android `vendor_a` 取 vpu/iris 签名固件装 `/lib/firmware/qcom/...` ② 板级 dtsi 覆盖 `status="okay"`（`video_mem` 保留区、`iommu 0x1940/0x1947`、videocc GDSC 已在上游）③ 主线 iris 的 `qcom,sm8750-iris` 兼容项与固件名/HFI 版本对上（对不上 = 上游能力缺口，按项目原则登记 + 试上游）。**★2026-11-27 晚（vk197 上机，`reports/dt-vk197-adsp-iris-20261127.md`）**：①②**已落地** —— 固件 `/lib/firmware/qcom/vpu/vpu35_p4.mbn`（2 392 776 B）+ 板级 `&iris { status = "okay" }` ⇒ `qcom-iris` 绑上 `aa00000.video-codec`，暴露 **`/dev/video17`（dec）/`/dev/video18`（enc）**，格式表 H264/HEVC/VP9/AV1 全在；③**部分成立**：固件侧已活（`sub_state 0→0x22→0x66` = `DRC|INPUT_PAUSE` → 加 `DRC_LAST|OUTPUT_PAUSE`，即固件在发首次 settings-change，HFI 通），但真解码仍 `capture: driver decode error`（H.264 baseline/main/high 三档同现象，`frame=1`/`corrupt decoded frame`）⇒ **Q36 未结**；**2026-11-27 晚静态判读改判根因层 = 驱动 DRC / 首帧前 IPSC 路径**（`V4L2_BUF_FLAG_ERROR` 来自零尺寸 `PSC_LAST` 输出缓冲被误标；`iris_hfi_gen2_response.c:393` 判 `LAST` 不判 `PSC_LAST`），上游 Neil Armstrong 2026-11-25 的 11 贴系列 **patchwork 1222157 正是修这套（未合入）**，我方树（2026-10-14）连其 base 符号都没有 ⇒ 下一步 = 取该系列做 backport 试（或等合入）。权威判读 = `reports/iris-decode-static-20261127.md`。另：`qcom_iris` **开机不自动加载**（模块里有 `of:N*T*Cqcom,sm8750-iris` alias，需手工 `modprobe qcom_iris`）⇒ 待查 udev 冷插。 **★2026-11-27 晚（第二次，上机，已解）**：backport patchwork **1222157** 全套 11 贴到日常树（`patch -p1 --fuzz=3`，我方树老 6 周；唯一缺符号 `iris_vb2_signal_eos()` 本地补 4 行），只重编 `qcom-iris.ko`（**不换内核、不改 DT**）⇒ **H.264 `frame=90` + HEVC `frame=90`、无 `decode error`，framemd5 与软解逐帧 90/90 零不一致**；`qcom_iris` 开机自动加载同时收口（真因 = 我方 `/etc/modprobe.d/elden-blacklist-iris.conf` 的 `blacklist qcom-iris` 实验保险丝，已改名 `.disabled`；冷启实测通过，节点权限变 `crw-rw----+`）。**根因表述更正**：`iris_hfi_gen2_response.c:393` 少判 `PSC_LAST` **不是修复点**（backport 后该行未变），真修复 = 系列 09/10 的 `early_capture`/`drc_unsignalled` 分支使零尺寸 `PSC_LAST` 走「重入队」而非置 `V4L2_BUF_FLAG_ERROR`。回滚 = `git checkout -- drivers/media/platform/qcom/iris/` 后重编覆盖；产物 `out/iris-backport-1222157/`（ko sha `9b815bc359012c1b…`）、组合补丁 `patches/backport-iris-drc-1222157/`；权威报告 `reports/iris-backport-1222157-20261127.md`。**残留**：① Moonlight 硬件解码判据未验（需 Sunshine 宿主 + 交互式串流）② 给 Neil 回 `Tested-by:` 未做 ③ 上游合入后应撤 backport。 | ✅ **已解（2026-11-27 晚，上机实测）**，非阻塞 | `reports/iris-backport-1222157-20261127.md`、`reports/hwdec-iris-sm8750-feasibility-20261127.md`、`reports/moonlight-client-deploy-20261127.md`（追加节） |

---

### 2. 已知缺口的补救路径（G1 侧，简表）

> **只列未闭合项**，且本表不维护状态数字（✅/❌ 一律看 §1 对应任务行）。
> 已闭合/取消（相机出流 G1-5、音频 G1-4、DP G1-9、CDSP G1-11、BT G1-7、NFC 取消 G1-10）不再在此复述。

| 缺口 | 类别 | 补救路径 | 关联 |
|---|---|---|---|
| ~~TF 卡间歇写丢失~~ | ✅ 已定性（新卡 3 轮零错误；旧卡废置） | 无（`patches/candidate-tf-*.patch` 保留备查，不实施） | G1-6 / Q10（已收口） |
| 熄屏 × 相机共存 | ~~DT 电源域耦合~~ **更正：RPMh rail retention 档**（2026-10-23，已指名） | **已由上游 `skip retention by default` 解决（7.3 含）；日常线无需本地补丁、无需规避** | G1-33 / Q24 |
| 进 GUI 后整机卡死（PITFALLS #106，10-05 两次 + 今日 1 次） | 未定性；**非 Q28 专属**（卡死那次桌面显示正常，用户 2026-10-09 确认）；APSS 硬看门狗被永久禁用 ⇒ 死挂不自复位，故一直抓不到栈 | **已常驻装弹**：`/etc/sysctl.d/99-freeze-trace.conf`（softlockup_panic+all_cpu_backtrace+panic=20+sysrq）+ `pstore-catch`（开机把 ramoops 归档到 `/var/log/pstore/`）⇒ 真实使用/压测中命中即自动 panic→暖复位→带回全 CPU 栈；压力器 `scripts/gui-stress.sh`（PATHCHECK=mdss vsync 增量，实测 6 s +319 才算有效样本）；首轮 60 轮合成负载压测**未复现**（峰值 66.1 ℃、load 1.8）⇒ 改靠常驻装弹在日常使用中等它自己撞 | — |
| 面板 init 间歇失败（只有背光） | 收窄：**只有开机首次 modeset 触发**（80 轮 DPMS 上电循环 0 命中）；机制候选=首次上电被吞错 + ABL 遗留态（`research-q28-dpu-powerup-race` / `2026-10-09-Q28-密集复现与vk74`） | ~~温启跑 vk74~~ **已作废（2026-11-13 对账：Q28 已结项、运营线 vk152 起 8/8 无坏发 ⇒ 本行不作待办）**；历史二分见 `archive/topics/` | Q28 |
| WiFi 到可用 | ✅ 已关闭（2026-10-10 用户确认正常） | —（历史假设：版本/DTB 增量，见 Q26） | Q26 ✅ |
| SLPI 7 传感器（Linux 侧原生） | AP 侧无总线，需 QRTR + `qcom_smgr` 栈 | 可选自研（路线见 G1-34，未开工）；**G2 侧不等它**——走容器虚拟传感器（§6 §2①） | G1-34 |
| 温控 OEM 层（`lenovo,sys-temp`/BCL/QMI cooling） | 厂商私有 | 通用 thermal 框架已给 4 级 trip；长负载（≥2 h）复核壳温/限频层级 | G1-8 / Q12 |
| TEE/SPU/hw-fence/Gunyah/PMIH010x/BCL/FM/ST54 | 私有或无源码 | 明确不投入 | ✗ 结案 |

---

### 3. 环境与流程类待办（不属功能，但会咬人）

| 项 | 现象 | 处理 |
|---|---|---|
| 代理 `127.0.0.1:7897` | ✅ **已恢复正常（2026-10-06 复核：`curl -x 7897 https://www.google.com` → 302）** | 现状 = **Clash Verge Rev / verge-mihomo**（root，mixed-port 7897，mode=rule，tun 关闭）；2026-10-05 已加 99 条校园/教育网 DIRECT 规则 + bashrc `no_proxy` 覆盖。排障/回滚见 `~/netfix/复盘-2026-10-05-教育网分流-clash规则.md`；凭据通道见 `~/netfix/凭据与下载通道-2026-10-05.md` |
| `/mnt/Samsung` 无 `nofail` | 掉盘卡开机 | ✅ 已修（A18，2026-10-02） |
| `qemu-utils` 缺失 | 不能造/转 guest 磁盘 | ✅ 已装（`/usr/bin/qemu-img`、`qemu-nbd` 在位，A13 勾销） |
| API 双重限流（20 req/窗口 + $30/3h） | worker"干净退出"像崩溃 | 用 provider `deepseek`；并发 ≤3；见 `archive/topics/复盘-2026-10-02-swarm.md` |
| vermagic 耦合 | 改 `CONFIG_LOCALVERSION` → 相机 `.ko` 全废 | 改内核版本必须整套重编 `.ko` |
| 备份目录命名 | 历史 `backup/new-tablet/` 语义已废 | 新操作一律 `backup/<SN>-<容量档>/`；脚本默认值参数化（A16） |

---

### 4. 风险登记（高影响，需你决策或知悉）

| 风险 | 概率/影响 | 缓解 |
|---|---|---|
| ~~解锁 U2 = 永久失去 Widevine L1 / 保修 / FOTA（全项目唯一 locked 单元）~~ **已解锁（2026-10-03），本条关闭**；残余 = 新单元若在 1.5.x 上试解锁会白跑一轮 | 低 / 中 | 解锁前 locked 基线已入库（`backup/HA2EXB0E-16+512/pre-unlock/`，Widevine=L1 已记）；G2 的 U5 用例按 L3 上限做预期 |
| 1.5.10.259 屏蔽解锁指令导致白跑一轮 | ~~低/低~~ **已发生（2026-10-03）** | 已由全量降级 1.1.11.073 解决（G1-0 已关闭）；**以后新单元直接判版本门→降级，不再在 1.5.x 上试解锁**（`RUNBOOK` §0.5）。注：U2 现态已回 **259 + unlocked**（2026-10-03 实机核验） |
| 覆盖 a 槽后强检测/银行类 App 完全不可用 | 中 / 中 | Q5 先取证；保留 stock + EDL 恢复；容器不行就换路线而不是硬扛 |
| GPT 手术/回收分区写坏 LUN0 | 低 / **高** | 手术前**分区镜像备份（三选一：设备侧 `dd` / 线刷包解出 / **EDL 读回**；本 ABL 无 `fastboot fetch`，#290；**EDL 工具链与 loader 见 `RESOURCES/README.md` §2.1（其能力限制：本机 loader 不放行 `peek`，`PITFALLS #486`）**）** + GPT 双表 dump + EDL 包在手；只写主/备表两处；写后读回校验 |
| 设备热失控（曾 103 °C） | 低 / 高 | 分级 trips 已在线；压测必带 `thermal-watch`，超 90 °C 自动降级 |
| ~~空闲熄屏→重启（U2 实测）~~ **已关闭（2026-10-24 用户裁决：不值得取证）**：日常线（7.3 血统）免疫，Q24 只读 §5 | 低 / 低 | 禁止空闲熄屏（`idle-delay=0` 或 phosh caffeine 常开）作为临时规避，并把它写进 `start-desktop.sh`（已删）/rootfs 归档；根治前 **不要**在不可回滚的持久系统上做熄屏实验（详见 `archive/topics/复盘-2026-10-03-持久化与睡眠.md`） |
| **未验证内核增量（vk34 之后）** | 已发生 / 中（风险已降级） | 2026-10-03 二分只能说明「vk34→vk40 叠加体内有回归」；**熄屏复位的真因后续定为单模块 `cambistmclkcc-sm8750` × DT 电源域（不在那 5 文件内）**，见 Q24。残留风险 = vblank/PPM 计数回归未复核（G1-23）|
| 边充边跑掉电（PMIC 默认 100 mA） | 中 / 中 | 上机前 `charge-ctl.sh`（已删） 拉满输入电流；长任务挂充电器并监控 |
| 单一路线依赖（只押 Waydroid） | 中 / 中 | 保留 redroid 作 R1' 备胎（本文 §6 §0） |
| **宿主内存位翻转**（曾致构建静默损坏；2026-10-20 已定性，原 T11） | 中 / 中 | **归硬件项目，不属于本项目待办**：判据 = 三读法 `scripts/detect-memory-corruption.py` + 构建前后门 `scripts/kbuild-sanity.sh`；硬件侧检测（BIOS memtest / 换条）由用户在其硬件项目处理 |

---

### 5. 勾销规则

- 勾销一条 Q ⇒ 必须给出：命令、原始输出片段、结论一句话、生效文档链接（`../DEVICE/README.md` / `README.md §6`）。
- 不允许"口头已确认"：控制面 OK ≠ 数据面 OK（`GRAPH_START status=0` ≠ 可听；graph ENABLED ≠ 出帧）。

---

