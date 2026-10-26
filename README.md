# Lenovo Legion Y700 (4th Gen) · TB322FC · SM8750P **"elden"** — Mainline Linux Bring-up

> 联想拯救者 Y700 四代（Lenovo Legion Y700 Gen 4 / 4th Gen）· 机型 **TB322FC** · 代号 **elden** ·
> SoC **Qualcomm SM8750(P) Snapdragon 8 Gen 4/Elite 系** —— 让它跑**功能完整的上游 Linux** 的公开研究工作区。

[![status](https://img.shields.io/badge/status-research%20%2F%20work%20in%20progress-orange)](#-状态诚实版)
[![target](https://img.shields.io/badge/SBC-TB322FC%20%2F%20elden-blue)]()

这是一个**仍在进行、且已知有未解决问题**的 bring-up 项目。我们把**代码、DTS/内核补丁、工具链、
证据日志、以及被推翻的结论**一起公开，方便同机型的人少走弯路，也方便上游评审挑错。

---

## 0. 一句话现状

主线 Linux（7.x）在这块板子上**大多数子系统已经能工作**（显示/图形/触屏/网络/音频/温控/串口/相机出流…），
**但显示子系统有一个未解决的冷启动竞态**（下面 `Q28`），它导致日常“冷开机有概率只有背光无画面”。
根因已收窄到 **bonded 双 DSI 首条 DCS 命令的命令 DMA 引擎 hang**，修复尚未落地。

**这个仓库不是“刷机教程”，是研究记录。** 刷机有变砖风险，详见 §6。

---

## 1. 设备（关键词速查）

| 项 | 值 |
|---|---|
| 商品名 | Lenovo Legion Y700 第四代 / **Legion Y700 Gen 4** / 4th gen |
| 型号 | **TB322FC** |
| 项目代号 | **elden** |
| SoC | **Qualcomm SM8750(P)**（Snapdragon 8 Gen 4 平台，8 核，Adreno） |
| 面板 | 8.8" 3K（1904×3040）**bonded 双 DSI + DSC**，Novatek NT36536（CSOT PP8807HB1） |
| 存储/内存 | 16 GB / 512 GB（UFS），A/B 双槽 |
| 目标 | **上游 Linux**（非 Android、非厂商内核），并**按模块向上游提交** |

> **SSOT**：机型规格的权威正文在 [`DEVICE/README.md`](DEVICE/README.md)；本表只是公开门面的速查副本。
> 单元台账（U1/U2）与分区/槽位口径同样以 `DEVICE/README.md` 为准。

---

## 2. 目标（按优先级）

> **SSOT**：目标定义与逐项状态**只**在 [`AGENTS.md`](AGENTS.md)（项目描述）与
> [`TASKS/README.md`](TASKS/README.md) §0（进度数字）维护；此处不复述，避免三处漂移。

- **G1 — 完整 Linux + 上游化**（驱动 bring-up + 按模块上游提交）
- **G2 — 安卓容器**（Waydroid 为主路线；验收 = 可用性 + 风控/完整性等级）
- **G3 — x86 模拟**（Steam 游戏为载体，Box64 + Wine/Proton）
- **拓展（非主线，不阻塞 G1–G3）**：UEFI 间接引导、Gunyah 虚拟化

完整措辞与验收口径见 [`AGENTS.md`](AGENTS.md) §目标；当前完成度见 [`TASKS/README.md`](TASKS/README.md) §0。

---

## 3. 状态（诚实版）

| 目标 | 状态（权威数字见 [`TASKS/README.md`](TASKS/README.md) §0） | 说明 |
|---|---|---|
| **G1** 驱动 bring-up | 多数驱动已工作 | **冷起显示竞态 `Q28` 未解**（已有修复候选，真 POR 3 发 GOOD、还差 5 发）；上游化 M1–M5 未开始 |
| **G2** 安卓容器 | 主链路已通 | Waydroid 图形/内核/GAPPS/代理通路可用；**容器传感器 HAL 已打通**（宿主 gbinder 注入 + 真值 SSC→UDP）、**容器音频打通**（C6：闹钟出声 + 录音 + MediaCodec 53）、**C2 GMS 登录**（用户人工验证）、**C10 马达透传**（AIDL V2 幅度控制+固化进 vendor.img）；Play Integrity / SafetyNet、Widevine 等级仍在收口 |
| **G3** x86 模拟 | **PoC ✅** | Box64 + Wine PoC 成功；Steam 端到端未上机 |

已工作（有实测证据）：显示/图形（暖起）、触屏、WiFi/BT、USB（NCM 网卡 + ACM 串口）、
音频播放与输入、温控、CDSP、DisplayPort、相机出流（按需加模块）、持久磁盘根 + Phosh 桌面自启、
A/B 槽管理、**安卓容器传感器**（加速/陀螺/光/磁/接近，真值来自 `ssccli` → UDP 注入容器）、
**容器音频**（C6：闹钟出声、录音、`/dev/fuse` emulated storage）、桌面用户态深色模式/亮度滑块/自动旋转磁贴。
明细与证据见 [`TASKS/README.md`](TASKS/README.md) §1。

**未解决 / 正在查（见 §4）**：显示冷起竞态 `Q28`、进桌面后整机卡死 `#106`、
**暖起 vs 冷起差异 `Q32`**（新，2026-10-23 立项）、以及**若干被我们自己推翻的结论**（诚实记录，见 `PROGRESS.md`）。
（`Q24` 熄屏×相机已于 2026-10-23 **根因指名**：7.2 血统缺上游 `skip retention by default`，7.3 线自带该修复。）
（此前记录在案的桌面用户态三项 —— 深色模式/电源菜单图标/亮度滑块 —— 于 2026-10-11 上机复核通过。）

---

## 4. 已知问题（当前）

| ID | 问题 | 状态 |
|---|---|---|
| **Q28** | **冷起显示间歇失败**：首条 DCS 命令 `ff 20` 的命令 DMA 引擎 hang → 面板未使能 → 只有背光无画面。两种表现：**NOCARD**（`card0` 没出现）与 **STORM**（有 `card0` 但 cmd-DMA/DPU 风暴）。 | **🟢 已规避·结项（2026-10-24，用户裁决不补样本）**。**2026-10-23 口径**：根因收窄到「首次 modeset 时命令引擎撞上 DYN 像素时钟域切换」，并定位两处代码缺陷（`dsi_bonded_cmd_failed` 单向闩锁、`link_configured` 误清）；**修复候选已上机**：把 MDSS 三块 BCR 复位搬到 display 侧 `msm_mdss_reset()` + 两处软件修，**真 POR 冷起累计 3 发全 GOOD**（判据：`DSI_PLL_lockfail=0`、`storm_sig=0`、mdss reset 失败 0、两路 pclk/byte parent 一致），距 ≥8 发判据还差 5 发；日常线 `boot_b = vk152`。上游 RFC 已投并评审中（`reports/q28-v2-mdss-reset-20261023.md`、`reports/q28-por-samples-r1r2-20261023.md`）。⚠ 已否证：~~构建身份伪造~~、~~`to_primary_dsi`~~、~~DSI ctrl+PHY 复位/软件闩锁/自定义 bonded 序列/使能期 force-on~~；冷起 A/B 必须真实 POR（暖复位会粘坏态）。 |
| **Q32** | **暖起（warm reset）与冷起（真 POR）的差异** —— 同一内核/DTB 为何会因复位深度不同而结果不同 | **已结项（并入 Q28，2026-10-24）：三臂 5 发全 GOOD，三个复位入口无差异**。静态预研已发现：现有证据**自相矛盾**（暖复位既有→NOCARD 也有 2/2 GOOD），所以判据只能是「**同一复位深度内是否一致**」；最可能的差异源 = **ABL 交接的 framebuffer**（7.2 DT 有 `chosen/framebuffer@fc800000`，7.3 树显式删除并注明 MDSS BCR 会把 ABL 交接的显示从 simpledrm 底下抽走）⇒ 真正的变量是「**本次启动 ABL 有没有留活显示**」，不是「暖/冷」这个代理指标。三臂实验（暖 vendor reset / 真 POR / `reboot -f`）待用户在机旁做（`reports/q32-warm-vs-cold-preresearch-20261023.md`）。 |
| **#106** | **亮屏进桌面后整机卡死**（无 panic、SSH/USB 全失、只能物理断电）。历史上被记为“偶发”，本仓库记录了它与 **“干净的 GOOD 显示”强相关**的实测：显示真正起来后数秒内冻结。 | 未定性。已装 `softlockup_panic`+`ramoops` 自动取证，但硬看门狗被禁用+只能冷断电，**至今没抓到栈**。 |
| **Q24** | 熄屏 × 相机 → 共存会常态掉电。 | **⛔ 已关闭（2026-10-24 用户裁决：不再取证）**；2026-10-23 根因已指名、停止采样**：7.2 血统缺上游 `pmdomain: qcom: rpmhpd: Skip retention by default`（7.3 线自带该修复）⇒ 7.3 上 41 发真实熄屏 0 死亡、7.2 上 6/8 死，**是版本差不是随机**；日常线无需本地补丁。运营上仍保留 `cam-mode.sh on/off` 互斥（安全策略，非既成事实）。 |
| — | **结论纪律**：`vk81/82/83` 曾因构建事故成为“无 QCOM 驱动的死内核”，其上的结果**已作废**；`Q28` 一度被判定为“按内核二进制确定性”，经独立溯源审计后**已降级**（见 `PROGRESS.md`）。 | 已是流程的一部分：worker 结论必须由编排者独立复跑。 |

详细的“我们错在哪、怎么发现的”见 **[`PROGRESS.md`](PROGRESS.md)**。

---

## 5. 仓库地图

| 路径 | 内容 |
|---|---|
| `INDEX.md` | **入口 / 文档结构（文件夹＝角度）与 SSOT**（中文，最权威的现状快照） |
| `TASKS/README.md` | 唯一任务台账（ID / 状态 / 下一步） |
| `PITFALLS/README.md` | **踩坑经验库**（动手前该扫的坑，条目编号范围见该文件抬头） |
| `DEVICE/README.md` | 设备/分区/槽位/存储口径 |
| `RESOURCES/README.md` | 资源与资产清单 |
| `RUNBOOK-BRINGUP/README.md` | 从解锁到起桌面的操作手册 |
| `patches/` | 内核补丁、config、DTS 变更、上游对照 |
| `scripts/` | 构建/打包/部署/取证工具链 |
| `reports/` | 专题报告与**证据**（含 `q28-DOSSIER.md`、会话台账） |
| `.pi/` | 本项目 AI 协作层（技能/子代理/计划），公开以示方法 |

---

## 6. 免责与安全

- 本仓库记录的是**研究过程**，镜像/脚本可能**变砖或丢数据**；刷写前务必备份（`backup/`）。
- `backup/` 下的部分内容对应**已解锁 BL** 的设备与出厂镜像证据，**不要**拿去做与本机型无关的操作。
- 内核/DT 补丁多来自 Linux 主线或社区，遵循其原始许可（多为 **GPL-2.0**）；脚本文档若无特别说明按 **MIT**。
  详见 `LICENSE`。
- 本仓库**不含**任何凭据、密钥、账号密码；历史中曾出现的一个被截断的网关 key **片段已清理**。

---

## 7. 快速开始

```sh
# 目录
INDEX.md                 # 先读这个
TASKS/README.md                 # 看进度/未解
PITFALLS/README.md              # 动手前扫坑

# 内核构建（需 aarch64 交叉工具链 + ccache；见 scripts/env-build.sh）
scripts/build-kernel.sh
# 打包 boot.img
VERSION=<tag> scripts/build-boot.sh
# 设备侧三态判据（显示问题）
scripts/q28-devprobe.sh  # 在设备上跑：NOCARD / STORM / GOOD
```

> 本项目原私有仓库托管于 USTC GitLab；此 GitHub 为公开镜像/发布点。
