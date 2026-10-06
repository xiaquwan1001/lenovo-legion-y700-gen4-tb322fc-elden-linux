# y700-elden — 项目说明

**机型唯一**：联想拯救者 Y700 四代 = **TB322FC** = 代号 **elden** = SoC **SM8750(P)**。
研究面 = **让这块板子在主线 Linux 上功能完整**（固件/驱动为主；刷写只是手段）。

## 目标（按优先级）

- **G1 完整 Linux + 上游化**：主线 Linux **功能特性完整**，**正确驱动全部原厂固件**（ADSP/CDSP/WCN7861/GPU/触屏/触觉/功放/tplg/相机…）。
  代码达到上游规范后**按模块向上游提交**（checkpatch/DTC/`dtbs_check` 绿；分级与顺序见 `TASKS.md` §7 M1–M5）。
- **G2 安卓容器**：**不依赖 Android 宿主**运行安卓应用（主路线 Waydroid，备胎 redroid）。
  核心验收 = **可用性 + 风控/完整性等级**：GMS 登录、**Play Integrity / SafetyNet**、Widevine 能做到哪一级
  （**取证判定，不预设"不可能"也不承诺**；见 `RESOURCES.md` §1.3、`TASKS.md` §5 Q1/§6）。
- **G3 x86 模拟运行**：以 **Steam 游戏**为验收载体，跑通 x86 用户态/游戏（Box64 + Wine/Proton 线）。
- **拓展（非主线，不阻塞 G1–G3）**：**UEFI 间接引导**、**Gunyah 高通虚拟化做 VM**。现状/裁决见 `TASKS.md` §4/§5、`archive/topics/`。

存储：Linux 容量按项目体量一次给足（`DEVICE.md` §3），扩容首选回收 Android 专属分区；不写死配置。

## 核心原则

- **设备等价**：同型号多台单元**物理地位完全等价**，唯一差异 = 容量；身份 = **(SN, hwboardid, 容量)**（`DEVICE.md`）。
  任务按单元**当前状态**分派，产出必须**设备无关**（运行时读实际 GPT/DT）。
- **文档 SSOT**：唯一入口 `INDEX.md`；状态/进度/计划只在 `INDEX` 指向的领域层维护。分层与清单见 `INDEX.md` §2（本文件不复述）。

## 规则 · 设备与刷写

- **不跨容量档复用 GPT 二进制**；每单元现 dump（`scripts/gpt-dump.sh`），手术一律读实际 GPT 参数。
- 动分区前先 `fastboot fetch` 备份将覆盖分区 + GPT 双表 dump；**写后读回校验**（不看"传输完成"）。
- 默认只动 **b 槽 + LUN0 GPT**；**不改 active slot**（`fastboot --set-active` 属未授权写操作）。回收 Android 专属分区需 G1 全绿 + EDL 备份在手。
- **覆盖 a 槽 Android 前，先做一轮真机对照取证**（`TASKS.md §5` Q5，不可复得）。
- **设备操作**：fastboot/EDL 命令由**用户亲自执行**，助手只给可直接手敲的**单条**命令（封装脚本跑 fastboot 命令有限、故障率高）；脚本只用于主机侧构建/打包。简单、可观测的脚本可直接执行。
- **测试环境**：零写盘优先 `fastboot boot`；区分 **`-ram` 纯 RAM 变体（停在 initramfs，无桌面/会话服务）** 与 **持久变体（RAM 内核 + 磁盘根，有桌面/服务）**。
  功能/服务级测试（蓝牙音频、桌面音频、Waydroid、相机出流、Integrity）**必须用持久变体或持久系统**（`PITFALLS` #93）。

## 规则 · 研发流程

- **先查本地既有结论**：引导链（BL/AVB/降级/GPT/EDL）及反复出现的问题，先 `grep` 技能 `references/` + `archive/topics/` + `PITFALLS`；
  命中则本轮只做「确认或推翻」，不从零重推（`PITFALLS` #87）。引用旧成功记录先查它属于哪台单元、当时固件版本与锁状态。
- **主线优先**（服务 G1 上游化）：厂商私有 compatible 先找主线等效驱动，只补 DT/config/固件命名；主线没有则分「架构性不可做 / 私有 / 可自研」，只立第三类。
- **判据在设备侧**：主机侧构建/编译/能进 BDS 一律只算「未上机验证」；间歇性故障**单次样本无效**（须同口径量化 + 单变量 + 长时窗）。见 `PITFALLS` §0 纪律 4。
- 不硬编码其他机器的 home 路径；用 `~` 与项目相对路径。

## 协作

- 并发子代理 = `Agent` 工具（`pi-subagents`）+ `.pi/agents/<role>.md` + `.pi/missions/<topic>.md`，**无守护进程**。
  派发前读 **`.pi/CONCURRENCY.md`**（基线+fork、单写者、提交 trailer、vk 分配，入口 `scripts/lane.sh`）。**领域层 5 份文档只有父 agent 写**。
- 项目技能 `.pi/skills/`（`qualcomm-android-flashing`、`qualcomm-edl-flashing`、`gsi-device-adaptation`）；通用方法论放全局技能。
- 启动入口：`cd ~/y700-elden && pi`。收工自检 `scripts/check-doctor.sh`（计数/死链/口径冲突）。

---

> 修订 2026-10-06：目标重心上移（G1 加"上游化"、G2 明确"风控/完整性"、新增 G3 x86、拓展 UEFI/Gunyah）；
> 裁掉已丢上下文的条目（文档结构复述、并发流程全文、旧入口/swarm 历史）——分别归 `INDEX.md` §2、`.pi/CONCURRENCY.md`、`PITFALLS.md` §15。
