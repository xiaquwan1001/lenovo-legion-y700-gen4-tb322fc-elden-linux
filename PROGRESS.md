# 进度总结 / Progress Log

> 面向公开读者的**诚实进度与问题记录**。内部权威台账是 [`TASKS.md`](TASKS.md) 与 [`INDEX.md`](INDEX.md)；
> 本文件按时间线给出「做了啥、验证到哪、错在哪」。全部数字都有仓库内证据文件。

---

## 1. 里程碑（时间线）

| 日期 | 里程碑 | 结果 |
|---|---|---|
| 2026-10-03 | BL 解锁（降级路：线刷 vendor → `fastboot oem unlock`） | `Device unlocked=true`；GPT 手术给 Linux 分区 `linux17`=193 GiB |
| 2026-10-03 | 持久磁盘根 + **Phosh 桌面自启** | `findmnt /`=`/dev/sda17`，Phosh 在跑 |
| 2026-10-04…08 | 驱动 bring-up 批次：音频(WCD939x)/CDSP/DisplayPort/相机出流/BT/WiFi/温控/串口 | 见 `TASKS.md` §1（27 项） |
| 2026-10-08 | 基线 `vk64`；发现 **Q28 显示间歇失败** | 冷起约 6 成失败，只有背光 |
| 2026-10-09 | Q28 根因收窄；#106「进 GUI 卡死」装自动取证 | 根因=bonded 双 DSI 首条 DCS 命令 DMA hang |
| 2026-10-10 | 立内核分界线 `clean/base`；模块化内核 `vk89` | 构建/身份管线收口 |
| 2026-10-10 夜 | Q28「按内核二进制确定性」结论 | **次日经溯源审计后被降级**（见 §4） |
| 2026-10-10 夜 | 发现 **clean-GOOD → 整机卡死**（`#106`）的强相关 | 见 §4 |
| 2026-10-11 | **容器传感器打通**（路线 C：宿主 gbinder 注入 + 真值 `ssccli`→UDP）；桌面深色/亮度闭环；`C1` 策略路由内核修复 | 见 `TASKS.md` C4/G1-28/C1 |
| 2026-10-11 | **M1 干净上游资产树**建成并通过干净构建 | `build/m1-upstream/clean-tree`，见 `reports/m1-clean-tree-20261011.md` |
| 2026-10-11 晚 | **容器音频打通**（C6：闹钟出声/录音/codec 53）、**C2 GMS 登录**（用户人工验证）、`/dev/fuse` emulated storage（Q30）、`C1` 网络治本（补 `IPV6_MULTIPLE_TABLES` 等） | 见 `TASKS.md` C6/C2/C1、`reports/container-audio-20261011.md`、`PITFALLS #194` |
| 2026-10-12 | **Q28 STORM 定案**：与 NOCARD 同族 = **内核构建身份伪影**（`#60` 2 位号 ~67% 坏 vs 3 位号 0 坏/12+，Fisher p≈0.005）；源码/DTB/ramdisk 全排除 | `PITFALLS #195`、`reports/q28-storm-bias-audit-20261011.md`、`reports/q28-handoff-20261012.md` |
| 2026-10-12 | **Q28 伪线索更正**：`to_primary_dsi` DSI0/DSI1 **不是** Q28 杠杆（两树属不同 MSM 实现，本硬件上是 no-op） | `PITFALLS #196` |
| 2026-10-12 | **Q24 重开**：更正「死前签名」（#197）；受控复现得 `{camcc}`+真熄屏=静默硬复位（末票 `mmcx↓/cx↓`）；S1/S2 存活、S3 因暖复位坏台架未执行（#198）；新增干净无相机台架 `lv64-nocam` | `reports/q24-ctl-20261012.md`、`reports/q24-stageA-20261012.md` |
| 2026-10-12 | **Q24 触发器干净定位（C 系列）**：三值仪表硬门下 C0(cam=0)/C1(`{camcc}`) 各自 `blank→hold 60 s→wake` 存活，C2(配对) 熄屏 3 s 内静默硬复位（GOOD 台架；`{camcc}` 单独不致死首次确证） | `reports/q24-cseries-20261012.md` |
| 2026-10-12 | **Q24 H1 DT 臂否证**：cambist 恢复上游 `MMCX+MX`（DTB-only repack，控制组逐字节复现、内核 UTS 不变）在同一 GOOD 台架同样死在熄屏，末票与基准逐字相同 | `reports/q24-h1-dtarm-20261012.md`、`reports/q24-h1-result-20261012.md`、`PITFALLS #205` |
| 2026-10-12 | **Q24 机制轮**：GPU `power/control=on` **不能**免除致死（GPU runtime-resume 被否定）；日常 boot_b 上「配对→熄屏存活→唤醒致死」**4/4 复现**；死亡末帧 = `phoc` 使能 `disp_cc_mdss_*`，共同信号 = NoC/BCM(`0x500xx`) 票爆发 | `reports/q24-mech-20261012.md`、`PITFALLS #207/#208` |
| 2026-10-12 | **Q24 受控差分 + NoC/BCM 否证**：同 boot A(cam=0) 熄屏 76 s + 唤醒存活 / B(配对) 唤醒 ≤10 s 死；BCM(`0x500xx`) 票死/活同址同型 ⇒ BCM 靶否证；cmd-db 资源映射首次落表 | `reports/q24-noc-20261012.md`、`PITFALLS #210` |
| 2026-10-12 | **Q24 致死 = SoC 级复位 + 约 30 s 自动重启（当日 6/6，无需物理 POR）**：USB 掉线 → 重枚举 → 回到已刷 OS；「需 POR」口径改判 | `reports/q24-noc-20261012.md`、`PITFALLS #209` |
| 2026-10-12 | **Q24 死法取证（PMIC/WDT 排除）+ 最小触发矩阵**：PON 块逐字节无差异、无硬件看门狗；cambist 单独 / camcc 单独在硬门口径下各存活 ⇒ 最小触发 = 配对 | `reports/q24-r9-20261012.md`、`PITFALLS #211/#212`、`scripts/q24-pmic-*.sh` |

---

## 2. 当前完成度（诚实版）

| 目标 | 完成度 | 关键限定 |
|---|---|---|
| **G1** 功能健全的 Linux | **≈ 90%** | 按“驱动 bring-up 完整性”度量；**上游化 M1–M5 = 0/5 未开始** |
| **G2** 安卓容器（Waydroid） | **≈ 60%** | 图形/内核/GAPPS/代理可用，**容器传感器 HAL 已打通**、**容器音频已打通**（C6）、**C2 GMS 登录**；Play Integrity/SafetyNet、Widevine 等级仍在收口 |
| **G3** x86 模拟（Steam） | **PoC ✅** | Box64 + Wine 成功；Steam 游戏端到端未上机 |

---

## 3. 已验证可用的部分（有证据）

- **显示/图形**：暖起稳定出桌面（Phosh）；冷起有 `Q28` 竞态（见 §4）。
- **触屏**：Novatek NT36536（SPI）可用。
- **网络**：WiFi（WCN7861/ath12k）+ 蓝牙配对/TWS；USB-NCM 网卡（`192.168.7.1`）+ ACM 串口控制台。
- **音频**：WCD939x 播放 + 输入（DMIC）走 QDSP6/ADSP。
- **相机**：后摄按需加载模块可出流并抓帧（与熄屏互斥，见 `Q24`）。
- **安卓容器传感器**：加速/陀螺/光/磁/接近进容器；真值走 `ssccli`（Qualcomm SSC）→ UDP → 宿主 gbinder HAL（`TASKS.md` C4）。
- **桌面用户态**：深色模式、亮度滑块、自动旋转磁贴、非整数缩放/刷新率（`TASKS.md` G1-26/27/28）。
- **温控**：分级 trips。
- **存储/启动**：持久磁盘根 + A/B 槽（`qbootctl`）+ 零写盘 `fastboot boot` 迭代。

证据位置：`reports/`（专题报告 + 会话台账）、`reports/trials/`（机器可读实验记录）、`logs/`（本机，未入库）。

---

## 4. 未解决的问题（含**被我们推翻的结论**）

### Q28 — 冷起显示间歇失败（未解决，主线阻塞）

- **现象**：冷开机有概率只有背光、无画面。约 6 成冷起失败（早期 vk63 上跨复位混采口径；**★2026-10-12 收窄：坏发率由内核构建身份决定，而非固定 ~60%**，见下方「状态」行）。
- **根因（收窄）**：bonded 双 DSI 的**首条 DCS 命令 `ff 20` 的命令 DMA 引擎 hang**
  （hang 时 `STATUS0=0x20003`、`TRIG_DMA=0x1` 自不清）；DPU 的 `ctl reset failure -22`/frame-done/vblank
  风暴是下游后果。
- **两种表现**：**NOCARD**（`card0` 没出现，更早的 probe 阶段失败）与 **STORM**（有 `card0` 但风暴）。
- **判据纪律**：必须**三态** + SSH 读全 dmesg + 查 `/sys/class/drm/card0`。只数风暴签名会把 NOCARD
  误判成 GOOD；串口 logger 会漏 0–20 s 现场。
- **A/B 台架坑**：`reboot2` 暖复位会把状态“粘”成 NOCARD，不能用它做冷起结论；真冷起要物理 POR。
- **状态（2026-10-12 定案）**：**NOCARD 与 STORM 同族 = 内核构建身份（UTS 版本串 / 构建号位数）伪影**——
  `#60`（2 位构建号）臂坏发 ~67%，3 位号（`#111`–`#120`）0 坏/12+（Fisher p≈0.005）；源码/DTB/ramdisk 全部排除。
  **治法 = 日常镜像用 3 位 `#N` 新身份重编**（未执行）；冷起 A/B 必须 PINUTS（钉死 UTS）。
  待核查项（~~`to_primary_dsi` DSI0/DSI1~~ **已证否、非 Q28 杠杆，见 `PITFALLS #196`**、Method B 对齐上游 `2028280686f4`、refgen）见 `reports/q28-handoff-20261012.md`。

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
- **下一步候选（未上机，无需 POR）**：① NoC/BCM 靶（`icc_set_bw` 抓「死前谁在投 NoC」）；② dispcc 靶（只动 dispcc 不碰 DSI 面板，判定靶点在 dispcc 还是面板）；③ 把「配对 + 任意显示电源转换 ⇒ 静默硬复位；两 CC `state_synced` 均不完成」补进 9 月 RFC 的 v2 邮件。
- **运营口径不变**：相机 ⇄ 熄屏互斥（日常零相机模块）。

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

1. **Q28**：执行治法——**用 3 位 `#N` 新身份重编日常镜像**（同源码 + ADSP DTB）并冷起回归；随后核查 **Method B**、refgen（见 `reports/q28-handoff-20261012.md`）。⚠ ~~`to_primary_dsi` DSI0/DSI1~~ 已证否、非 Q28 杠杆（`PITFALLS #196`）。
2. **#106**：把判据升级为「GOOD 需 ≥60 s 存活/可交互」；尝试让死挂**自动 panic 带栈**（ramoops 或 OOB）。
3. **上游化 M1–M5**：M1 干净资产树已建、构建通过；下一步 M2 首发小系列（`checkpatch`/`dtbs_check` 绿）。
4. **G2**：Waydroid Play 登录与完整性等级取证。
5. **G3**：Steam 端到端。

---

## 7. 协作方式说明

本项目由**人类研究者 + AI 编码代理**协作推进（代理行为规范见 [`.pi/AGENT-OPS.md`](.pi/AGENT-OPS.md)）。
**纪律**：worker（子代理）只报「命令 + 原始日志」，**编排者必须独立复跑**；
结论先过“证据是否可复现”，再进 SSOT。上面 §4 中那两条被推翻的结论，正是这条纪律起作用的结果。
