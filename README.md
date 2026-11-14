# Lenovo Legion Y700 (4th Gen) · TB322FC · SM8750P **"elden"** — Mainline Linux Bring-up

> 联想拯救者 Y700 四代（Lenovo Legion Y700 Gen 4 / 4th Gen）· 机型 **TB322FC** · 代号 **elden** ·
> SoC **Qualcomm SM8750(P) Snapdragon 8 Gen 4/Elite 系** —— 让它跑**功能完整的上游 Linux** 的公开研究工作区。

[![status](https://img.shields.io/badge/status-research%20%2F%20work%20in%20progress-orange)](#-状态诚实版)
[![target](https://img.shields.io/badge/SBC-TB322FC%20%2F%20elden-blue)]()

这是一个**仍在进行、且已知有未解决问题**的 bring-up 项目。我们把**代码、DTS/内核补丁、工具链、
证据日志、以及被推翻的结论**一起公开，方便同机型的人少走弯路，也方便上游评审挑错。

---

## 0. 一句话现状

主线 Linux（当前日常线基于 **stable 7.3.1**；当前构建号与完成度**现查** [`TASKS/README.md`](TASKS/README.md) §0 与 [`DEVICE/README.md`](DEVICE/README.md) §1.1，本文件不维护具体号）
在这块板子上**大多数子系统已经能工作**（显示/图形/触屏/网络/音频/温控/串口/相机出流+拍照、传感器、Waydroid 容器主链路…），日常已可日用。

近期几件大事的**逐日时间线正文 = [`PROGRESS.md`](PROGRESS.md) §1**（本节不重复维护，避免两处漂移）。最近一轮（2026-11-12）要点：UEFI N1 判读再更正（菜单两版都能显，无屏显 = `CONFIG_SYSFB_SIMPLEFB` 未开）并出对应内核待上机验；Waydroid/输入法/马达/音频/传感器全链上机可用。

**这个仓库不是“刷机教程”，是研究记录。** 刷机有变砖风险，详见 §6。

---

## 1. 设备（关键词速查）

| 项 | 值（速查副本，权威 = [`DEVICE/README.md`](DEVICE/README.md)） |
|---|---|
| 商品名 | Lenovo Legion Y700 第四代 / **Legion Y700 Gen 4** / 4th gen |
| 型号 | **TB322FC** |
| 项目代号 | **elden** |
| SoC | **Qualcomm SM8750(P)**（骁龙 8 至尊版 / 8 Elite，8 核 + Adreno 830） |
| 面板 | 8.8" 3K（1904×3040）**bonded 双 DSI + CPHY + DSC**，Novatek NT36536（CSOT PP8807HB1-1） |
| 存储/内存 | UFS 4.0，A/B 双槽（容量**按单元**不同，见 `DEVICE/README.md` §2.2 单元台账） |
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
| **G1** 驱动 bring-up | 多数驱动已工作；日常线基于 stable 7.3.1 | **在机内核/槽位只读** [`DEVICE/README.md`](DEVICE/README.md) §1.1 首条（2026-11-13 起 = `vk190` 持久 `boot_b`，RAM 试验件 `vk191`）；冷起显示竞态 `Q28` 已按「已规避」结项（2026-10-24；样本数与复启条件只读 `TASKS` §5）；上游化 M 系列进行中（camss SM8750、dwc3、wl2868c、aw86927 等，逐条只读 `TASKS` §7） |
| **G2** 安卓容器 | 主链路已通 | Waydroid 图形/内核/GAPPS/代理通路可用；**容器传感器 HAL**（真值 SSC→UDP）、**容器音频**（C6）、**C2 GMS 登录**（用户人工验证）、**C10 马达透传**（AIDL V2 + 固化进 vendor.img + Settings 强度档位）、**C11 触屏中文输入法**（squeekboard + fcitx5/Rime，2026-10-20 上机验收）、**容器相机到 App 预览 `STREAMING`**（2026-10-29）；Play Integrity / SafetyNet、Widevine 等级仍在收口 |
| **G3** x86 模拟 | **PoC ✅ / Steam 登录界面 ✅** | Box64 + Wine PoC 成功；官方 ARM64 Steam 客户端 2026-10-28 起到登录界面（实测证据 `reports/g3-steam-20261028.md`），截图判据 10-29 闭环；Steam 游戏端到端（图形/音频/性能）未上机 |
| **拓展** UEFI 间接引导 | 🟢 **两种形态都通（2026-11-10）** | 零写盘形态（`fastboot boot` 的 UEFI 件读起 ESP 上的 `boot.img`，2026-11-08）与 flashed 形态（写 `boot_a`，2026-11-10 打通，129.2 s 起 Linux）都已实测；flashed 曾失败三轮，真根因 = 原厂 `dtbo_a` 的 Android DTBO 被 ABL 合进我们的 DTB（清 `dtbo_a` 即通）。剩余仅「菜单交互目视」与「`boot_a` 冷起回归」两项非阻塞，详见 `TASKS` §5「2026-11-10（深夜）」块与 `reports/uefi-dtbo-a-rootcause-20261110.md`。Gunyah = 终局裁决非主线（2026-10-25） |

已工作（有实测证据）：显示/图形（暖起）、触屏、WiFi/BT、USB（NCM 网卡 + ACM 串口）、
音频播放与输入、温控、CDSP、DisplayPort、相机出流（按需加模块）、持久磁盘根 + Phosh 桌面自启、
A/B 槽管理、**安卓容器传感器**（加速/陀螺/光/磁/接近，真值来自 `ssccli` → UDP 注入容器）、
**容器音频**（C6：闹钟出声、录音、`/dev/fuse` emulated storage）、桌面用户态深色模式/亮度滑块/自动旋转磁贴。
明细与证据见 [`TASKS/README.md`](TASKS/README.md) §1。

**未解决 / 正在查**：当前开放项与「卡什么」**只读 [`INDEX.md`](INDEX.md) §0（现在一页）**；
本文件不再维护第二套状态清单。
（`Q28` 冷起显示竞态与 `Q32` 暖/冷起差异已于 2026-10-24 **按「已规避」结项**；样本数与复启条件只读 `TASKS` §5。）
（`Q24` 熄屏×相机已于 2026-10-23 **根因指名**：7.2 血统缺上游 `skip retention by default`，7.3 线自带该修复。）
（UEFI 间接引导已于 2026-11-10 **两种形态都通**，见上表「拓展」行。）
（此前记录在案的桌面用户态三项 —— 深色模式/电源菜单图标/亮度滑块 —— 于 2026-10-11 上机复核通过。）
（日用用户态基线 `G1-37`：sudo/locale/中文字体/输入法/zram 已于 2026-11-07 落地、11-09 全链收口，见 `TASKS` §1。）

---

## 4. 已知问题（当前）

| ID | 问题 | 状态 |
|---|---|---|
| **Q28** | **冷起显示间歇失败**：首条 DCS 命令 `ff 20` 的命令 DMA 引擎 hang → 面板未使能 → 只有背光无画面。两种表现：**NOCARD** 与 **STORM**。 | **🟢 已规避·结项（2026-10-24，用户裁决不补样本、不挖根因）**。修复口径、结项样本数、判据、已否证清单与在机镜像**只读** [`TASKS/README.md`](TASKS/README.md) §5 Q28 行 + [`DEVICE/README.md`](DEVICE/README.md) §1.1；历史报告 `reports/q28-v2-mdss-reset-20261023.md`、`reports/q28-por-samples-r1r2-20261023.md`。冷起 A/B 必须真实 POR（暖复位会粘坏态）。 |
| **Q32** | **暖起（warm reset）与冷起（真 POR）的差异** —— 同一内核/DTB 为何会因复位深度不同而结果不同 | **已结项（并入 Q28，2026-10-24）：三臂实验跑完、入口无差异**。判据表、样本数与「变量是 ABL 有没有留活显示」的结论只读 `TASKS` §5 Q28/Q32 行与 `reports/q32-matrix-20261024.md`、`reports/q32-warm-vs-cold-preresearch-20261023.md`。 |
| **#106** | **亮屏进桌面后整机卡死**（无 panic、SSH/USB 全失、只能物理断电）。2026-10-10 的对照实验记录到它与「干净的 GOOD 显示」强相关。 | **历史记录，当前不作开放项**：2026-10 之后无复现样本（Q28 运营线 8/8 无坏发、日线累计多轮无命中），也**没有栈**（硬看门狗禁用 + 只能冷断电）。谁再撞到就按「装弹已就位（`softlockup_panic`+ramoops）」取证，取证前不重新论证。 |
| **N1** | **UEFI 间接引导（G1-29）** | 🟢 **已收口（2026-11-10 深夜）**：零写盘与 flashed（写 `boot_a`）两种形态都实测起 Linux；flashed 三年失败的真根因 = 原厂 `dtbo_a`（ABL 把 Android DTBO 合进我们的 DTB）⇒ 配方 = `dtbo_a` 全 0 + 刷 `boot_a`。剩余 = 菜单交互目视、`boot_a` 冷起回归（非阻塞）。**只读** `TASKS` §5「2026-11-10（深夜）」块与 `reports/uefi-dtbo-a-rootcause-20261110.md`。 |
| **Q24** | 熄屏 × 相机 → 共存会常态掉电。 | **⛔ 已关闭（2026-10-24 用户裁决：不再取证）**；根因、样本数与运营互斥策略**只读** `TASKS` §5 Q24 行。 |
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
