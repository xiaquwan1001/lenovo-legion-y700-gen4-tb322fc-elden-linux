# y700-elden — 项目说明

**机型唯一的研究项目**：联想拯救者 Y700 四代 = **TB322FC** = 代号 **elden** = SoC **SM8750(P)**。
研究内容 = **固件 + 驱动**（EDL/fastboot/GPT/双槽/root 只是把它刷进去的手段）。

## 双目标

- **G1**：跑**功能健全的 Linux**，**正常驱动原厂全部固件**（ADSP/CDSP/WCN7861/GPU/触屏/触觉/功放/tplg）。
- **G2**：**在没有 Android 的前提下**最大化兼容安卓（用户 2026-10-02 定：**a 槽 Android 可以不要**）。
  主路线 = 容器（Waydroid，备胎 redroid），备选 = VM（本机无 KVM，仅调研），观察 = denial/droidloom。
  **GMS / Play Integrity / Widevine 能做到哪一级 = 待调查项**：社区已有容器跑谷歌服务的先例，
  **不预设"不可能"，也不承诺能做**（取证入口见 `RESOURCES.md` §1.3、`TASKS.md §5` Q1）。
- **Linux 存储容量不固定**：按项目体量估算后一次给足，不写死 65/128 GiB；扩容首选回收 Android 专属分区。

## 设备等价（★核心原则）

同型号多台单元**物理地位完全等价**，**唯一差异 = 容量**（内存/UFS → 仅 GPT 数值不同）。
身份 = **(SN, hwboardid, 容量)**，记在 `DEVICE.md`；**"新机/旧机"不是角色**；
**任务按单元当前状态分派**，不按机器身份；产出必须**设备无关**（运行时读实际 GPT/DT）。

## 文档结构（入口最少，2026-10-03 起）

与 hermes 项目记忆同源，此处为准（子代理读不到可检索记忆）。

**唯一入口 `INDEX.md`**（含 §2 分层定义与 SSOT 规则）。根目录只有 6 份维护文档：
- **`DEVICE.md`** 设备描述+状态 · **`TASKS.md`** 任务/进度/未解(§5)/G2方案(§6)/上游化(§7) ·
- **`RESOURCES.md`** 参考+本地资源+资产台账(§3)+会话索引(§4) · **`RUNBOOK-BRINGUP.md`** 上机手册 ·
- **`PITFALLS.md`** 踩坑（§0 零号纪律 + #1–#98）。

**状态/进度/计划只在领域层维护**；日期型专题＝过程证据（`archive/`，只增不改）；旧文档原文在 `archive/2026-10-02-merged/`。
无 SQLite/生成物；查询用 `rg`，会话回忆用 pi 原生选择器；自检 `scripts/check-doctor.sh`（计数/死链/口径冲突）。

## 规则

- **不跨容量档复用 GPT 二进制**；每单元现 dump（`scripts/gpt-dump.sh`），手术一律读实际 GPT 参数。
- 动分区前先 `fastboot fetch` 备份将被覆盖的分区 + GPT 双表 dump；**写后读回校验**（不看"传输完成"）。
- 默认只动 **b 槽 + LUN0 GPT**；回收 Android 专属分区（Phase B）需 G1 全绿 + EDL 备份在手。
- **覆盖 a 槽 Android 前先做一轮真机对照取证**（`TASKS.md §5` Q5，不可复得）。
- 主线优先：厂商私有 compatible 先查主线等效驱动，只补 DT/config/固件命名；主线没有则分"架构性不可做 / 私有 / 可自研"，只有第三类立项。
- **设备操作**：fastboot/EDL 类命令由用户亲自执行，助手只做分析并给可直接手敲的**单条**命令；不要用封装脚本跑 fastboot（`to-fastboot.sh`/`cycle.sh` 等：命令有限、深层嵌套难预测、故障率高），脚本只用于主机侧构建/打包。**不要改 active slot**（b 槽是当前可用系统，`fastboot --set-active` 属未授权写操作）。简单、可观测的脚本可直接执行，不必先要授权。
- **测试环境选择**：零写盘优先 `fastboot boot`；但必须区分 **`-ram` 纯 RAM 变体（停在 initramfs，无桌面/会话服务）** 与 **持久变体（RAM 内核 + 磁盘根，有桌面/Phosh/PipeWire/bluetoothd/Waydroid）**。功能/服务级测试（蓝牙音频、桌面音频栈、Waydroid、相机出流）**必须用持久变体或持久系统**，否则缺系统服务会误判为功能故障（`PITFALLS` #93）。
- **引导链问题（BL 解锁 / AVB 签名 / 降级 / GPT / EDL）先本地检索再取证**：技能 `references/*.md` 正文不入上下文，
  **不 grep 等于不存在**；命中既有结论则本轮只做「确认或推翻」，不许从零重推；引用旧成功记录先查它属于哪台单元、
  当时固件版本与锁状态（状态不同 ≠ 机型不同）。参 `PITFALLS` #87、`archive/topics/复盘-2026-10-03-BL解锁.md`。
- 不硬编码其他机器的 home 路径；用 `~` 和项目相对路径。
- **并发任务一律走基线+fork**（`.pi/CONCURRENCY.md`）：父 agent 打 `base/*` 标签 → `scripts/lane.sh new <lane> <base> [--kernel]` 建 worktree+分支 → 子 agent 只在自己的 lane 分支提交（trailer `Lane/Agent/Baseline/Task/VK`，`.githooks/commit-msg` 强制）→ 父 `lane.sh merge <lane>` 解冲突并 `check-doctor`。**领域层 5 份文档 + `.githooks` + `versions/` 只有父能写**；版本号统一由 `scripts/lane.sh alloc`（registry `versions/vk-registry.tsv`，flock）分配，禁止扫 `out/` 猜号。并发上限 3。

## 其他

- 项目专属技能：`.pi/skills/`（`qualcomm-android-flashing`、`qualcomm-edl-flashing`、`gsi-device-adaptation`）。
- **启动入口**：`cd ~/y700-elden && pi`。`flashing` / `eacndev` / `lob-remake` 三个 `cd` 包装（旧 pi-profile-switch 时代遗留）**已于 2026-10-04 移除**，归档 `archive/2026-10-04-retired-entrypoints/`。
- **并发子代理** = `Agent` 工具（插件 `pi-subagents`，nicobailon）+ `.pi/agents/<role>.md` 角色定义 + `.pi/missions/<topic>.md` 任务背景；**无 harness 守护进程**。旧 swarm harness（`pi-messenger-swarm`，已卸载）的脚本与补丁在归档目录，命令已失效。
- 通用方法论放全局技能；设备/资产细节留本项目。
