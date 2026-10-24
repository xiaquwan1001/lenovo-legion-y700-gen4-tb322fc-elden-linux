# 进度总结 / Progress Log

> 面向公开读者的**诚实进度与问题记录**。内部权威台账是 [`TASKS/README.md`](TASKS/README.md) 与 [`INDEX.md`](INDEX.md)；
> 本文件按时间线给出「做了啥、验证到哪、错在哪」。全部数字都有仓库内证据文件。

---

## 1. 里程碑（时间线）

| 日期 | 里程碑 | 结果 |
|---|---|---|
| 2026-10-03 | BL 解锁（降级路：线刷 vendor → `fastboot oem unlock`） | `Device unlocked=true`；GPT 手术给 Linux 分区 `linux17`=193 GiB |
| 2026-10-03 | 持久磁盘根 + **Phosh 桌面自启** | `findmnt /`=`/dev/sda17`，Phosh 在跑 |
| 2026-10-04…08 | 驱动 bring-up 批次：音频(WCD939x)/CDSP/DisplayPort/相机出流/BT/WiFi/温控/串口 | 见 `TASKS/README.md` §1（27 项） |
| 2026-10-08 | 基线 `vk64`；发现 **Q28 显示间歇失败** | 冷起约 6 成失败，只有背光 |
| 2026-10-09 | Q28 根因收窄；#106「进 GUI 卡死」装自动取证 | 根因=bonded 双 DSI 首条 DCS 命令 DMA hang |
| 2026-10-10 | 立内核分界线 `clean/base`；模块化内核 `vk89` | 构建/身份管线收口 |
| 2026-10-10 夜 | Q28「按内核二进制确定性」结论 | **次日经溯源审计后被降级**（见 §4） |
| 2026-10-10 夜 | 发现 **clean-GOOD → 整机卡死**（`#106`）的强相关 | 见 §4 |
| 2026-10-11 | **容器传感器打通**（路线 C：宿主 gbinder 注入 + 真值 `ssccli`→UDP）；桌面深色/亮度闭环；`C1` 策略路由内核修复 | 见 `TASKS/README.md` C4/G1-28/C1 |
| 2026-10-11 | **M1 干净上游资产树**建成并通过干净构建 | `build/m1-upstream/clean-tree`，见 `reports/m1-clean-tree-20261011.md` |
| 2026-10-11 晚 | **容器音频打通**（C6：闹钟出声/录音/codec 53）、**C2 GMS 登录**（用户人工验证）、`/dev/fuse` emulated storage（Q30）、`C1` 网络治本（补 `IPV6_MULTIPLE_TABLES` 等） | 见 `TASKS/README.md` C6/C2/C1、`reports/container-audio-20261011.md`、`PITFALLS #194` |
| 2026-10-12 | ~~**Q28 STORM 定案**：与 NOCARD 同族 = **内核构建身份伪影**~~（**当日深夜已被推翻**，见下方 10-12 深夜各行与 `PITFALLS #217/#223`） | `PITFALLS #195`、`reports/q28-storm-bias-audit-20261011.md`、`reports/q28-identity-retest-20261012.md` |
| 2026-10-12 | **Q28 伪线索更正**：`to_primary_dsi` DSI0/DSI1 **不是** Q28 杠杆（两树属不同 MSM 实现，本硬件上是 no-op） | `PITFALLS #196` |
| 2026-10-12 | **Q24 重开**：更正「死前签名」（#197）；受控复现得 `{camcc}`+真熄屏=静默硬复位（末票 `mmcx↓/cx↓`）；S1/S2 存活、S3 因暖复位坏台架未执行（#198）；新增干净无相机台架 `lv64-nocam` | `reports/q24-ctl-20261012.md`、`reports/q24-stageA-20261012.md` |
| 2026-10-12 | **Q24 触发器干净定位（C 系列）**：三值仪表硬门下 C0(cam=0)/C1(`{camcc}`) 各自 `blank→hold 60 s→wake` 存活，C2(配对) 熄屏 3 s 内静默硬复位（GOOD 台架；`{camcc}` 单独不致死首次确证） | `reports/q24-cseries-20261012.md` |
| 2026-10-12 | **Q24 H1 DT 臂否证**：cambist 恢复上游 `MMCX+MX`（DTB-only repack，控制组逐字节复现、内核 UTS 不变）在同一 GOOD 台架同样死在熄屏，末票与基准逐字相同 | `reports/q24-h1-dtarm-20261012.md`、`reports/q24-h1-result-20261012.md`、`PITFALLS #205` |
| 2026-10-12 | **Q24 机制轮**：GPU `power/control=on` **不能**免除致死（GPU runtime-resume 被否定）；日常 boot_b 上「配对→熄屏存活→唤醒致死」**4/4 复现**；死亡末帧 = `phoc` 使能 `disp_cc_mdss_*`，共同信号 = NoC/BCM(`0x500xx`) 票爆发 | `reports/q24-mech-20261012.md`、`PITFALLS #207/#208` |
| 2026-10-12 | **Q24 受控差分 + NoC/BCM 否证**：同 boot A(cam=0) 熄屏 76 s + 唤醒存活 / B(配对) 唤醒 ≤10 s 死；BCM(`0x500xx`) 票死/活同址同型 ⇒ BCM 靶否证；cmd-db 资源映射首次落表 | `reports/q24-noc-20261012.md`、`PITFALLS #210` |
| 2026-10-12 | **Q24 致死 = SoC 级复位 + 约 30 s 自动重启（当日 5/5，无需物理 POR）**：USB 掉线 → 重枚举 → 回到已刷 OS；「需 POR」口径改判 | `reports/q24-noc-20261012.md`、`PITFALLS #209` |
| 2026-10-12 | **Q24 死法取证（PMIC/WDT 排除）+ 最小触发矩阵**：PON 块逐字节无差异、无硬件看门狗；cambist 单独 / camcc 单独在硬门口径下各存活 ⇒ 最小触发 = 配对 | `reports/q24-r9-20261012.md`、`PITFALLS #211/#212`、`scripts/q24-pmic-*.sh` |
| 2026-10-12 晚 | **Q28 收尾轮：日常镜像按 3 位构建身份重编（`vk113-dailyid`，可复现：全量重编逐字节相同）+ 上游 round 修复臂（`vk114-dailyid-round`）** | **两者均未修好 Q28**：当晚 7 发冷起 4 坏/7（4 臂同率），签名逐字同；⇒ 『构建身份治法』作废 |
| 2026-10-12 晚 | **Q28 判据修正：坏发按时间成簇（会话级），非镜像属性** | `PITFALLS #223`、`reports/q28-identity-retest-20261012.md` §6 |
| 2026-10-12 晚 | **Q28 负结果**：运行期重绑 panel/`msm_dsi` 不恢复（`card0` 消失 + GPU hangcheck） | `PITFALLS #224`、`logs/q28-rebind-20261012/` |
| 2026-10-12 晚 | **Q28 上游报告草稿就绪（待发送）** | `archive/topics/UPSTREAM-REPORT-q28-bonded-dsi-2026-10-12.md`、`out/q28-bonded-dsi-2026-10-12.txt` |
| 2026-10-12 深夜 | **Q28 七臂收束：vk116–vk122（+vk123）全部否证**；`-5`=软件闩锁短路、DSI ctrl+PHY 复位救不回、自定义 bonded 序列/使能期 force-on 同签名坏发；判别量=**DYN pclk 域闩住**⇒故障态不在控制器内部 | `reports/q28-dsi-recover-20261012.md`、`PITFALLS #226` |
| 2026-10-12 深夜 | **Q28 主靶 dispcc/INTF 静态对照后削弱**：原厂源码本仓已有，`DSI_DISP_CC_*` 只用于 PHY reset clamp/MDP 调试，命令路径寄存器级等价 | `reports/q28-dispcc-static-20261012.md`、`PITFALLS #227` |
| 2026-10-12 深夜 | **Q28 运营兜底看门狗上机**：坏发 75 s 后自动**正常重启**（可用性 ~50%→~75%）；顺带修 `reboot2` 旧构建「无参=进 fastboot」地雷 | `reports/q28-watchdog-20261012.md`、`PITFALLS #228/#229` |
| 2026-10-13 | **Q28 复位终态对齐臂 vk125 上机否证**（= vk117 恢复路径 + `CLK_CTRL=0` 终态）：坏发 boot 上恢复路径确实触发（`resetting DSI link` + 两控制器 `Q28 resetterm: CTRL=0x0 CLK_CTRL=0x0 CLK_STATUS=0x1403`），但 `link_power_on` 后 `CLK_STATUS` 立刻回到 `0x1743`、重试命令逐字 `-110`（3 次尝试寄存器序列完全相同）⇒ **终态对齐不是解** | `reports/q28-dsi-recover-20261012.md` §20、`PITFALLS #230` |
| 2026-10-13 07:15–07:22 | **Q28 同窗配对采样（T2 第 1 窗，#60 ↔ 3 位身份）**：vk104-s1 **GOOD** / vk94-s4 **GOOD** / vk104 **GOOD** / vk94-s5 **UNKNOWN**（操作者提前中断，未捕判据）；同窗前段 07:04 vk125 **L1FAIL**、07:10 vk94 **L1FAIL** ⇒ **窗内两臂都出 GOOD、#60 自身也有坏发 ⇒ 无可辨身份效应**（坏发成簇主导；三条 record 由日志回填，存活门被人工中断已在 note 标注）。**同窗口尾 07:21 `vk94` 第 5 发 = 坏发第三形态「仅背光 + 无 SSH」**（`NOROUTE`；150 s 无 SSH、无 fastboot、30 min 仍不可达）⇒ 判据不得并入 NOCARD/STORM，且**设备侧看门狗救不了本形态**（`PITFALLS #231`） | `reports/trials/20261012T23{2103,2537,2538}Z-*.json`、`reports/q28-identity-retest-20261012.md` §8 |
| 2026-10-12 深夜 | **上游回移 lane 收尾**：清洗后 14 文件 fast-forward 合入 `clean/base`（`5b169d541`），出日常候选 `out/boot-elden-vk124-merged.img`（同 UTS 身份 `#121`）；**验收口径改为「取得 1 次 GOOD 冷起」**；上机 3 发全 L1FAIL | `reports/upstream-lane-merge-20261012.md` |
| 2026-10-13 | **C10 Waydroid 马达透传完成**：容器 HAL ↔ `aw86927` FF 全链路 → 自编 **AIDL V2** 拿到幅度控制与 `cancel` → **固化进 `vendor.img`**（运行期零 bind）→ **Settings 振动强度档位**（静态 RRO，档位 1→3） | `reports/waydroid-haptics-20261013.md`、`PITFALLS #232–#246` |
| 2026-10-14 | **Q31 显示回归定位并修复（E1b，1 行语义）**：上游 revert 了 bonded PLL init ⇒ `PLL_SYSTEM_MUXES=0xc0` 永不写入；修复后干净 POR 面板有内容 + 触屏可操作 | `reports/m1-73-e1b-pllfix-20261014.md` |
| 2026-10-18…22 | **Q28 机理改写**：定位 `dsi_bonded_cmd_failed` 单向闩锁 + `link_configured` 误清两处代码缺陷；A/B 修复后 **0154+0155 两臂合并 15/15 GOOD vs base 4/9（p=0.003）** | `reports/q28-disp-init-ab-20261022.md`、`PITFALLS #366` |
| 2026-10-23 | **Q28 v2：复位搬到 display 侧（`msm_mdss_reset()`）真 POR 5/5 GOOD**，证明起作用的是「复位动作 + 早于 PLL」而非 dispcc probe 位置；日常候选 `vk151/vk152` 已写 `boot_b`（含 kexec 诊断旋钮） | `reports/q28-v2-mdss-reset-20261023.md`、`reports/vk151-daily-candidate-20261023.md` |
| 2026-10-23 | **Q24 根因指名并停止采样**：7.2 血统缺上游 `pmdomain: qcom: rpmhpd: Skip retention by default`（7.3 线自带）⇒ 41 发 0 死亡 vs 7.2 的 6/8 死是**版本差不是随机**；日常线无需本地补丁 | `reports/q24-retention-rootcause-20261023.md` |
| 2026-10-23 | **收尾轮（免 POR）**：Q29 关闭（容器 Mesa bind 冗余，已删，图形正常）、**背光下限服务**（修「面板 GOOD 但看起来黑屏」）、容器相机恢复 1 设备（根因 = `/dev/video100` bind 从未持久化） | `reports/closeout-q29-backlight-camera-20261023.md`、`PITFALLS #372/#373` |
| 2026-10-23 夜 | **Q28 前 2 发真 POR（vk152）= 2/2 GOOD**，判据段逐字一致；累计 3 发，距 ≥8 发判据剩 5 发（**采样配额：agent 只取 2 发，其余交用户**）。**新增待办 Q32 = 暖起 vs 冷起差异**（静态预研指向「ABL 交接 framebuffer + 复位动作」，而非「暖/冷」本身） | `reports/q28-por-samples-r1r2-20261023.md`、`reports/q32-warm-vs-cold-preresearch-20261023.md` |
| 2026-10-23 深夜 | **Q32 开工（无复位、无 verdict）**：取证工具落地（`scripts/q32-boot-evidence.sh` / `scripts/q32-arm.sh`，clkdiag 加 6 个 Q32 判据、两个 POR 收集器自动附采）；**判据更正 = 复位深度只能从 pstore/ramoops 取**（本次 dmesg 永无该打印，`PITFALLS #374`）；**试点（vk152 `b6211ab4`）**：DT `splash_region` 43 MiB + msm `reserved boot framebuffer IOVA` + `silent_boot.mode=nonsilent` ⇒ **ABL 留了活显示**，而 `simpledrm=0`（`PITFALLS #375`）；UEFI 交叉评估：**维持搁置**，UEFI 会把「固件活显示」推向恒 yes 并抹掉 W1 臂 | `reports/q32-kickoff-20261023.md` |
| 2026-10-24 凌晨 | **Q32 判据表完成（5 发）**：W1(vendor 0x80010001)×2 GOOD、C1(真 POR)×2 GOOD、W2(arch SYSTEM_RESET)×1 GOOD ⇒ **三入口无差异，暖/冷不是主变量**；5/5 `FW_LIVE_FB=yes` / `SIMPLEDRM=0` ⇒ 「撕显示」机会与复位深度无关；局限 = 坏发未复现，结论限定本线。**复位深度改为从 pstore 指纹判读**（#374/#377）。Q32 → 并入 Q28 | `reports/q32-matrix-20261024.md` |
| 2026-10-24 | **Q28 收口 = 已规避（运营线 vk152）**：规避栈 = 0154/0155/闩锁清零/`link_configured` + 看门狗（ON、count=0）+ 三态探针；POR 5/5、暖复位 3/3 全 GOOD（8/8 无坏发）。用户决定**不补样本、不挖根因**（Q24 教训）；口径限定「运营判断、非已解决」，复启条件三条 → `reports/q28-workaround-closeout-20261024.md` |
| 2026-10-24 | **kexec「静默挂死」破案并修好**：目标其实 1.3 s 就到 `/init`（旧记录「没到 marker 段」错），真因是交接后 `GICR_CTLR.EnableLPIs` 在 SM8750 上是 **RES1**（清不掉）+ LPI 表跨 kexec 无保留 ⇒ `redist_disable_lpis()` -EBUSY ⇒ LPI 从不重配 ⇒ ITS 命令队列停摆（**99 次 ×1.25 s，`/init` 126.35 s**）。修法 = incoming 侧 `memblock_reserve()` **认领**继承的表、走 preallocated 路径 ⇒ **0 超时、`/init` 1.31 s（vk160/vk161 实测）** | `reports/kexec-target-boots-20261024.md`、`TASKS/sessions/2026-10-24-kexec-its-lpi-claim.md` |
| 2026-10-24 | **修法已上游投递并入归档**：`[PATCH] irqchip/gic-v3-its: Claim LPI tables inherited across kexec on DT`，Message-ID `<20261024075856.835932-1-xiaqinghuan@mail.ustc.edu.cn>`，`/lkml/` 与 `/linux-arm-kernel/` 均命中；checkpatch `--strict` 0/0/0、干净 `git am` rc=0、编译 0 warning | `patches/upstream/m-gic-its-claim-20261024/README.md`、`TASKS/README.md` §7 M9 |
| 2026-10-24 | **kexec 剩余边界写清**：修好的是「内核 + MSI」，**显示与 USB 仍是继承活态**（`mask=1` 跳过 `device_shutdown`）⇒ 目标里无 `card0`、`[usb-gadget] no UDC after 20s`，~157 s 被自家 Q28 看门狗重启回落；定位维持「不需显示/网络的调试快环」 | `reports/kexec-target-boots-20261024.md` §9、`PITFALLS #380` |

---

## 2. 当前完成度（诚实版）

| 目标 | 状态（权威数字见 [`TASKS/README.md`](TASKS/README.md) §0） | 关键限定 |
|---|---|---|
| **G1** 功能健全的 Linux | 多数驱动已工作（暖起） | 按“驱动 bring-up 完整性”度量；**上游化 M1–M5 未开始** |
| **G2** 安卓容器（Waydroid） | 主链路已通 | 图形/内核/GAPPS/代理可用，**容器传感器 HAL 已打通**、**容器音频已打通**（C6）、**C2 GMS 登录**、**C10 马达透传**（AIDL V2 + 固化 vendor.img）；Play Integrity/SafetyNet、Widevine 等级仍在收口 |
| **G3** x86 模拟（Steam） | **PoC ✅** | Box64 + Wine 成功；Steam 游戏端到端未上机 |

---

## 3. 已验证可用的部分（有证据）

- **显示/图形**：暖起稳定出桌面（Phosh）；冷起有 `Q28` 竞态（见 §4）。
- **触屏**：Novatek NT36536（SPI）可用。
- **网络**：WiFi（WCN7861/ath12k）+ 蓝牙配对/TWS；USB-NCM 网卡（`192.168.7.1`）+ ACM 串口控制台。
- **音频**：WCD939x 播放 + 输入（DMIC）走 QDSP6/ADSP。
- **相机**：后摄按需加载模块可出流并抓帧（与熄屏互斥，见 `Q24`）。
- **安卓容器传感器**：加速/陀螺/光/磁/接近进容器；真值走 `ssccli`（Qualcomm SSC）→ UDP → 宿主 gbinder HAL（`TASKS/README.md` C4）。
- **安卓容器马达透传**：Waydroid HAL → 宿主桥 → `aw86927` 主线驱动；AIDL V2 幅度+cancel，固化进 `vendor.img`（`TASKS/README.md` C10、`reports/waydroid-haptics-20261013.md`）。
- **桌面用户态**：深色模式、亮度滑块、自动旋转磁贴、非整数缩放/刷新率（`TASKS/README.md` G1-26/27/28）。
- **温控**：分级 trips。
- **存储/启动**：持久磁盘根 + A/B 槽（`qbootctl`）+ 零写盘 `fastboot boot` 迭代。

证据位置：`reports/`（专题报告 + 会话台账）、`reports/trials/`（机器可读实验记录）、`logs/`（本机，未入库）。

---

## 4. 未解决的问题（含**被我们推翻的结论**）

> **本节的「当前口径」已上收：[`TASKS/README.md`](TASKS/README.md) §5（Q28/Q24）为准；此处只保留时间线与被推翻结论的诚实记录。**

### Q28 — 冷起显示间歇失败（未解决，主线阻塞）

- **现象**：冷开机有概率只有背光、无画面（早期口径「约 6 成」「坏发率由构建身份决定」均已废）。**当前口径只读 [`TASKS/README.md`](TASKS/README.md) §5 Q28**，本处不复述数字。
- **根因（收窄）**：bonded 双 DSI 的**首条 DCS 命令 `ff 20` 的命令 DMA 引擎 hang**
  （hang 时 `STATUS0=0x20003`、`TRIG_DMA=0x1` 自不清）；DPU 的 `ctl reset failure -22`/frame-done/vblank
  风暴是下游后果。
- **两种表现**：**NOCARD**（`card0` 没出现，更早的 probe 阶段失败）与 **STORM**（有 `card0` 但风暴）。
- **判据纪律**：必须**三态** + SSH 读全 dmesg + 查 `/sys/class/drm/card0`。只数风暴签名会把 NOCARD
  误判成 GOOD；串口 logger 会漏 0–20 s 现场。
- **A/B 台架坑**：`reboot2` 暖复位会把状态“粘”成 NOCARD，不能用它做冷起结论；真冷起要物理 POR。
- **状态（历史）**：多轮实测已推翻「构建身份伪影」定案及多种治法（3 位身份重编 `vk113/vk114`、上游 byte-clk `2028280686f4` 移植、运行期重绑 DSI host、驱动内自恢复 `vk116/vk117`、七臂 vk116–vk123 + 复位终态 `vk125` 等）。**当前口径（坏发率 / 收敛状态 / 下一步）只读 [`TASKS/README.md`](TASKS/README.md) §5 Q28**，过程证据见下方「被推翻的结论」与 §1 时间线对应各行。

> **⚠️ 被推翻的结论（诚实记录）**：2026-10-10 夜我们曾得出「Q28 是**按内核二进制确定性**的、
> 不是冷/暖」这一逆转性结论，并一度写进 SSOT。次日**溯源审计否定了它**：
> 1. 那个「21 发」台账里**只有 7 发有原始日志**，其余是口头观测、`.img` 已删；
> 2. 所谓「内核二进制差 5,040,884 B(8%)」**主要是假象**——是 `LOCALVERSION` 版本串长度变化
>    导致的**整段 `.rodata` 平移 4 字节**（`.text` 仅 26 个 word 不同、全是地址立即数，无指令语义改变）；
> 3. 同一镜像在**同一路径**上就能跑出 GOOD→STORM→STORM→GOOD（**非确定性**），直接否掉“恒定复现”。
> 结论：原说法降级为「在 `reboot2` 暖路径上 vk64 亮、新编不亮，**真因未定**」。
> 过程稿见 `reports/q28-binary-determinism-provenance-20261010.md`。

### #106 — 亮屏进桌面后整机卡死（未解决）

- **现象**：显示正常起来后数秒，**整机冻结**：无 panic、SSH/ping/USB/fastboot 全失，只能物理断电。
- **边界**：APSS **硬看门狗被永久禁用** ⇒ 永不自复位；只有“冷断电”能恢复 ⇒ ramoops 也随之丢失，
  **至今一栈未获**。纯 RAM initramfs 不启桌面，故不受影响。
- **2026-10-10 新增观测**：本仓库的对照实验显示它与**“干净的 GOOD 显示”强相关**——
  相同的 `fastboot boot`，`storm=0` 的干净 GOOD **2/2 在数秒内打死**；`storm>0` 的 STORM **4/4 存活**；
  NOCARD 存活。也就是**“有 card0”不等于“能用”**，判定 GOOD 必须带**存活门**。
- **对历史结论的影响**：我们无法确认历史上所有被记为 `GOOD` 的样本都是真 GOOD——
  早期判据是二值的（有 `card0`=GOOD），会把「STORM 存活」和「亮一下就死」混在一起。
  但**也不能说它们全是 hang**：既有反例（`card0`+风暴的样本存活 >226 s），且当时循环能连续进行也说明多数不是 hang。

### Q24 — 熄屏 × 相机（已裁决规避；2026-10-12 重开调查）

单模块 `cambistmclkcc-sm8750` 与 DT 电源域冲突，相机常驻会在熄屏时掉电。**用户裁决**：
日常**零相机模块**，需要相机时显式加载。根治变体未完成。

**2026-10-12 重开（方法学复核 + 受控复现，详见 `reports/q24-ctl-20261012.md`）**：

- **更正（`PITFALLS #197`）**：旧口径的「死前共同签名」（第二 CC 加载时 RPMh 批量投 0）**不是死因**——`modprobe camcc→cambist` **不熄屏、设备存活时同样出现**（那批轨稳态本为 0）。
- **受控复现第 1 轮**：GOOD 台架（`-vk64` PINUTS）上 `{camcc}` 单模块 + 真实熄屏 → **静默硬复位**（串口无 panic、USB 重枚举）；末票 = phoc `mmcx↓/cx↓`（**异于配对死的 `mxc→0`**）。⚠️ 状态为「完整栈装载后卸载」，非干净 `{camcc}` ⇒ 不否定历史结论。
- **第 2 轮 S1/S2/S3**：S1（`{camcc}` 60 s）、S2（配对 300 s）**不熄屏均存活**；**S3 未执行**——该轮经 `reboot2 bootloader`（暖复位）取台架 ⇒ 踩 `PITFALLS #166`，`phoc` 卡 D 态（GPU/DPU 故障）⇒ 熄屏完全 no-op。
- **新纪律（`PITFALLS #198`）**：熄屏实验必备「屏真关」硬门（`GetActive`+`DPMS`+RPMh `mmcx/cx` 降档票）；**A/B 起点必须是物理 POR**。
- **静态新发现**：本树 cambist DT = H2（MX-only，`be79b256d`），是对上游 mainline（MMCX+MX）的**实验性偏离**，且其立论已被 #197 否定 ⇒ **从未在配对基线上测过**。
**2026-10-12 当日后续五轮（3–7 轮，均已完成）**：

- **第 3 轮（干净无相机台架 + 三值硬门）**：`lv64-nocam` 冷起（Q28 判定 L1FAIL 但会话/仪表可用）⇒ 仪表硬门 **3/3 通过**；S1（`{camcc}` 60 s）/S2（配对 300 s）**不熄屏存活**；S3 真熄屏**成功且 +11 s 未立即致死**，死亡发生在**唤醒**（末票 `gfx=1/gmxc=1` GPU 域上电）。
- **第 4 轮（C 系列，决定性）**：**GOOD 台架**一次冷起内 C0/C1/C2，三相位每步 `blank→hold 60 s→wake` 且每步过三值硬门 ⇒ **C0/C1 存活 +89 s，C2（配对）熄屏 3 s 内静默硬复位**（串口无 panic）；三相位熄屏末票**逐字相同**（`mmcx=2/cx=5`）⇒ **票不区分死/活**。
- **第 5/6 轮（H1 DT 臂）**：DTB-only repack（控制组逐字节复现基准 DTB、内核 UTS 不变、`dtc` diff 恰 6 行）⇒ **否证**：上游 `MMCX+MX` 同样死在熄屏，签名与 MX-only 基准逐项相同 ⇒ **DT 电源域绑定既不是死因也不是解**。
- **第 7 轮（机制取证）**：GPU runtime-PM 钉 `on` 仍死 ⇒ **GPU resume 非致死步骤**；L1FAIL 台架/日常 boot_b 上「配对→熄屏（存活）→唤醒（致死）」4/4 复现；死亡末帧 = `phoc` 使能 `disp_cc_mdss_mdp_lut_clk/vsync_clk_src/vsync_clk`；所有现场共同信号 = **NoC/BCM（`0x500xx`）RPMh 投票爆发**。
- **下一步 / 致死口径**：① NoC/BCM 靶已否证（`#210`）；② dispcc 靶当前无手段。**当前口径（致死 = SoC 级复位 + 约 30 s 自恢复、最小触发 = 配对、靶点转电气/时序级、上游 RFC v2/v3 邮件状态）只读 [`TASKS/README.md`](TASKS/README.md) §5 Q24。**
- **运营口径不变**：相机 ⇄ 熄屏互斥（日常零相机模块）。

- **（原 Q28 收尾轮状态，2026-10-12 深夜；此 bullet 误置 Q24 段末，实为 Q28 内容）**：七臂 vk116–vk123 / 复位终态 vk125 全部否证；看门狗兜底上机；上游回移候选 `vk124-merged` 取 1 次 GOOD（T1 达标）。**当前口径只读 [`TASKS/README.md`](TASKS/README.md) §5 Q28**，过程见 §1 时间线与 `reports/q28-*.md`。

### 构建/身份事故（已修复并入流程）

- `vk81/82/83` 因 `make olddefconfig` 抹掉 `ARCH_QCOM` → 编出**无 QCOM 驱动的死内核**且当时未察觉，
  其上的上机结果**全部作废**。已加编后符号守卫（`gcc_sm8750`/`msm_dsi_host_bonded_cmd_trigger`/`rpmh`）。
- `vk87/88` 名字与载荷对不上（`Image.gz` 陈旧未重编）→ 已删除、加打包前内核身份硬门。
- **版本号纪律**：`vkN` 是「构建/载具号」不是内核版本；内核身份唯一判据 = 镜像内核载荷的 sha256。

---

## 5. 方法 / 资产

- **版本号台账**：`versions/`（registry / 内核身份表 / manifest 指纹）。
- **实验记录**：`reports/trials/`（JSON + `index.tsv`），每发落盘、可事后复核。
- **取证脚本**：`scripts/q28-devprobe.sh`（三态）、`scripts/trial.sh`（闸门+记录）、
  `scripts/gui-freeze-watch.sh`（#106）、`scripts/check-doctor.sh`（仓库自检）。
- **分界线**：内核树以 `clean/base`（= `d02658e63`）为唯一功能基线，其上为实验层。

---

## 6. 下一步（按优先级）

> **2026-10-23 起的工作纪律（用户定）**：**需要物理 POR 的样本一律排最后**；**TF 卡（G1-6）暂时不做**；
> **Q28 采样配额：agent 只取 2 发，其余交用户在机旁完成**。权威口径 = [`TASKS/README.md`](TASKS/README.md) §4「收尾轮次纪律」。

1. **Q28**（未解，主线阻塞）：日常线 `vk152`，**真 POR 已 3 发 GOOD（判据段逐字一致）**，还差 5 发（交用户，
   `scripts/q28-por-rounds.sh 1 2400 <轮号>`，`boot_b` 已是 vk152 故不需要 fastboot）。
   机理线：M8 的 dispcc RFC 已投并在评审（我方 10-23 已按 Taniya 架构意见改成 display 侧复位）。
   ⚠ 已否证：~~3 位身份重编~~、~~`to_primary_dsi`~~、~~上游 `2028280686f4` 移植~~、
   ~~DSI ctrl+PHY 复位/软件闩锁/自定义 bonded 序列/使能期 force-on~~（`PITFALLS #196/#217/#223/#226`）。
2. **Q32（新）暖起 vs 冷起差异**：静态预研已完成（`reports/q32-warm-vs-cold-preresearch-20261023.md`），
   三臂实验（W1 暖 vendor / C1 真 POR / W2 `reboot -f`）在用户在场时做；
   核心假说已从「暖/冷」改写为「**本次启动 ABL 有没有留活显示**」。
3. **Q24**：**根因已指名、停止采样**（7.2 缺上游 `skip retention by default`，7.3 自带）。日常仍执行
   `cam-mode.sh on/off` 互斥（安全策略，非既成事实）。
4. **#106**：判据「GOOD 需 ≥60 s 存活/可交互」；ramoops 装弹已在位等它自己撞（见 `TASKS` §5 §2 表）。
5. **上游化 M1–M5**：M1 树与 `m1-73/baseline` 已收敛；M3-1 v3 形状 RFC 已投等 ack；
   M3-2 台账 / M3-3 音频 / M3-4 显示 / M4 camss 均备料封存（投递冻结，收盘统一投）。
6. **G2**：容器相机只剩 **App 实开预览（需装 APK）**；C3 身份/DRM 取证（PI 检测 App 亦需 APK）。
7. **G3**：Steam 端到端。

---

## 7. 协作方式说明

本项目由**人类研究者 + AI 编码代理**协作推进（代理行为规范见 [`.pi/AGENT-OPS.md`](.pi/AGENT-OPS.md)）。
**纪律**：worker（子代理）只报「命令 + 原始日志」，**编排者必须独立复跑**；
结论先过“证据是否可复现”，再进 SSOT。上面 §4 中那两条被推翻的结论，正是这条纪律起作用的结果。
