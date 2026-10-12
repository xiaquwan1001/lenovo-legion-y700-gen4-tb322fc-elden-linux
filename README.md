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

同型号多台单元物理等价，本项目用 **U1 / U2** 指代单元；任务按单元**当前状态**分派。

---

## 2. 目标（按优先级）

- **G1 — 完整 Linux + 上游化**：跑功能健全的主线 Linux，正确驱动原厂固件（ADSP/CDSP/WCN7861/
  GPU/触屏/触觉/功放/tplg/相机…）；达到上游规范后按模块提交（`checkpatch`/DTC/`dtbs_check` 绿）。
- **G2 — 安卓容器**：不依赖 Android 宿主运行安卓应用（主路线 **Waydroid**，备胎 redroid）。
  核心验收 = 可用性 + 风控/完整性等级（GMS 登录、Play Integrity / SafetyNet、Widevine 到哪一级，**取证判定**）。
- **G3 — x86 模拟**：以 **Steam 游戏**为载体跑通 x86 用户态/游戏（Box64 + Wine/Proton）。
- **拓展（非主线）**：UEFI 间接引导、Gunyah 高通虚拟化做 VM。

---

## 3. 状态（诚实版）

| 目标 | 完成度 | 说明 |
|---|---|---|
| **G1** 驱动 bring-up | **≈ 90%** | 27/30 项功能可用；**上游化 M1–M5 = 0/5（未开始）** |
| **G2** 安卓容器 | **≈ 60%** | Waydroid 图形/内核/GAPPS/代理通路可用；**容器传感器 HAL 已打通**（宿主 gbinder 注入 + 真值 SSC→UDP）、**容器音频打通**（C6：闹钟出声 + 录音 + MediaCodec 53）、**C2 GMS 登录**（用户人工验证）；Play Integrity / SafetyNet、Widevine 等级仍在收口 |
| **G3** x86 模拟 | **PoC ✅** | Box64 + Wine PoC 成功；Steam 端到端未上机 |

已工作（有实测证据）：显示/图形（暖起）、触屏、WiFi/BT、USB（NCM 网卡 + ACM 串口）、
音频播放与输入、温控、CDSP、DisplayPort、相机出流（按需加模块）、持久磁盘根 + Phosh 桌面自启、
A/B 槽管理、**安卓容器传感器**（加速/陀螺/光/磁/接近，真值来自 `ssccli` → UDP 注入容器）、
**容器音频**（C6：闹钟出声、录音、`/dev/fuse` emulated storage）、桌面用户态深色模式/亮度滑块/自动旋转磁贴。
明细与证据见 [`TASKS.md`](TASKS.md) §1。

**未解决 / 正在查（见 §4）**：显示冷起竞态 `Q28`、进桌面后整机卡死 `#106`、
相机与熄屏互斥 `Q24`、以及**若干被我们自己推翻的结论**（诚实记录，见 `PROGRESS.md`）。
（此前记录在案的桌面用户态三项 —— 深色模式/电源菜单图标/亮度滑块 —— 于 2026-10-11 上机复核通过。）

---

## 4. 已知问题（当前）

| ID | 问题 | 状态 |
|---|---|---|
| **Q28** | **冷起显示间歇失败**：首条 DCS 命令 `ff 20` 的命令 DMA 引擎 hang → 面板未使能 → 只有背光无画面。冷起失效有两种表现：**NOCARD**（`card0` 没出现）与 **STORM**（有 `card0` 但 cmd-DMA/DPU 风暴）。 | **未解**。**2026-10-12 深夜最新口径**：坏发 ~50%、逐启动随机、**按时间成簇（会话级）**，与镜像/构建身份**无关**——旧「构建身份伪影」定案**作废**（`PITFALLS #217/#223`）；3 位身份只是降险偏置（`#60` 5/7 坏 vs 3 位 1/23，p≈8e-4，残余坏发点估 4.3%、上界 21.9%）。七臂 vk116–vk122 全部否证，故障态不在 DSI 控制器内部（`reports/q28-dsi-recover-20261012.md`）；**恢复只能整机复位**；日常可用性靠**看门狗兜底**（坏发 75 s 自动正常重启，~50%→~75%，`reports/q28-watchdog-20261012.md`）。上游报告已就绪待发。`boot_b` 仍 = `vk94`。判据必须三态（NOCARD/STORM/GOOD，`scripts/q28-devprobe2.sh`）+ SSH 读全 dmesg+查 `card0`；冷起 A/B 必须 PINUTS（钉死 UTS），`reboot2` 暖复位会粘 NOCARD 不可当台架。待核查项（~~`to_primary_dsi` DSI0/DSI1~~ **已证否、非 Q28 杠杆，`PITFALLS #196`**；Method B、refgen）见 `reports/q28-handoff-20261012.md`。 |
| **#106** | **亮屏进桌面后整机卡死**（无 panic、SSH/USB 全失、只能物理断电）。历史上被记为“偶发”，本仓库记录了它与 **“干净的 GOOD 显示”强相关**的实测：显示真正起来后数秒内冻结。 | 未定性。已装 `softlockup_panic`+`ramoops` 自动取证，但硬看门狗被禁用+只能冷断电，**至今没抓到栈**。 |
| **Q24** | 熄屏 × 相机（单模块 `cambistmclkcc` × DT 电源域）→ 共存会常态掉电。 | 用户裁决：**日常零相机模块**，需要时临时加载。 |
| — | **结论纪律**：`vk81/82/83` 曾因构建事故成为“无 QCOM 驱动的死内核”，其上的结果**已作废**；`Q28` 一度被判定为“按内核二进制确定性”，经独立溯源审计后**已降级**（见 `PROGRESS.md`）。 | 已是流程的一部分：worker 结论必须由编排者独立复跑。 |

详细的“我们错在哪、怎么发现的”见 **[`PROGRESS.md`](PROGRESS.md)**。

---

## 5. 仓库地图

| 路径 | 内容 |
|---|---|
| `INDEX.md` | **入口 / 文档分层与 SSOT**（中文，最权威的现状快照） |
| `TASKS.md` | 唯一任务台账（ID / 状态 / 下一步） |
| `PITFALLS.md` | **踩坑经验库**（动手前该扫的坑，170+ 条） |
| `DEVICE.md` | 设备/分区/槽位/存储口径 |
| `RESOURCES.md` | 资源与资产清单 |
| `RUNBOOK-BRINGUP.md` | 从解锁到起桌面的操作手册 |
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
TASKS.md                 # 看进度/未解
PITFALLS.md              # 动手前扫坑

# 内核构建（需 aarch64 交叉工具链 + ccache；见 scripts/env-build.sh）
scripts/build-kernel.sh
# 打包 boot.img
VERSION=<tag> scripts/build-boot.sh
# 设备侧三态判据（显示问题）
scripts/q28-devprobe.sh  # 在设备上跑：NOCARD / STORM / GOOD
```

> 本项目原私有仓库托管于 USTC GitLab；此 GitHub 为公开镜像/发布点。
