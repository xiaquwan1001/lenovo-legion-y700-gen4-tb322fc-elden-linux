# y700-elden — 项目说明

**机型唯一的研究项目**：联想拯救者 Y700 四代 = **TB322FC** = 代号 **elden** = SoC **SM8750(P)**。
研究内容 = **固件 + 驱动**（EDL/fastboot/GPT/双槽/root 只是把它刷进去的手段）。

## 双目标

- **G1**：跑**功能健全的 Linux**，**正常驱动原厂全部固件**（ADSP/CDSP/WCN7861/GPU/触屏/触觉/功放/tplg）。
- **G2**：**在没有 Android 的前提下**最大化兼容安卓（用户 2026-10-02 定：**a 槽 Android 可以不要**）。
  主路线 = 容器（Waydroid，备胎 redroid），备选 = VM（本机无 KVM，仅调研），观察 = denial/droidloom。
  **GMS / Play Integrity / Widevine 能做到哪一级 = 待调查项**：社区已有容器跑谷歌服务的先例，
  **不预设"不可能"，也不承诺能做**（取证入口见 `RESOURCES.md` §1.3、`GAPS.md` Q1）。
- **Linux 存储容量不固定**：按项目体量估算后一次给足，不写死 65/128 GiB；扩容首选回收 Android 专属分区。

## 设备等价（★核心原则）

同型号多台单元**物理地位完全等价**，**唯一差异 = 容量**（内存/UFS → 仅 GPT 数值不同）。
身份 = **(SN, hwboardid, 容量)**，记在 `DEVICE.md`；**"新机/旧机"不是角色**；
**任务按单元当前状态分派**，不按机器身份；产出必须**设备无关**（运行时读实际 GPT/DT）。

## 文档结构（三层平面，2026-10-03 起）

入口 `INDEX.md`（含 §2 分层定义与 SSOT 规则）。
**平面 1 领域层**（唯一维护面）：**`DEVICE.md`**（设备描述+状态）· **`TASKS.md`**（任务+进度+待办）·
**`RESOURCES.md`**（参考+本地资源）· **`GAPS.md`**（查漏补缺+风险）·
**`ANDROID-COMPAT.md`**（G2 方案）· **`RUNBOOK-BRINGUP.md`**（上机手册）。
**平面 2 元层**：`FILES.md`（资产台账）· `PITFALLS.md`（经验正文）· `LESSONS.md`/`db/`（生成物）· `SESSION-INDEX.md`。
**平面 3 证据层**：`archive/`（只增不改）。
**状态/进度/计划只在平面 1 维护**；日期型专题＝过程证据；旧文档原文在 `archive/2026-10-02-merged/`。
自检：`scripts/check-doctor.sh`（计数/死链/db 新鲜度/口径冲突）。

## 规则

- **不跨容量档复用 GPT 二进制**；每单元现 dump（`scripts/gpt-dump.sh`），手术一律读实际 GPT 参数。
- 动分区前先 `fastboot fetch` 备份将被覆盖的分区 + GPT 双表 dump；**写后读回校验**（不看"传输完成"）。
- 默认只动 **b 槽 + LUN0 GPT**；回收 Android 专属分区（Phase B）需 G1 全绿 + EDL 备份在手。
- **覆盖 a 槽 Android 前先做一轮真机对照取证**（`GAPS.md` Q5，不可复得）。
- 主线优先：厂商私有 compatible 先查主线等效驱动，只补 DT/config/固件命名；主线没有则分"架构性不可做 / 私有 / 可自研"，只有第三类立项。
- 用户操作设备；助手准备资产并给出精确步骤。
- **引导链问题（BL 解锁 / AVB 签名 / 降级 / GPT / EDL）先本地检索再取证**：技能 `references/*.md` 正文不入上下文，
  **不 grep 等于不存在**；命中既有结论则本轮只做「确认或推翻」，不许从零重推；引用旧成功记录先查它属于哪台单元、
  当时固件版本与锁状态（状态不同 ≠ 机型不同）。参 `PITFALLS` #87、`archive/topics/复盘-2026-10-03-BL解锁.md`。
- 不硬编码其他机器的 home 路径；用 `~` 和项目相对路径。
- 刷写失败先写复盘（操作时间线 / 根因 / 文件清单），再换方案。

## 其他

- 项目专属技能：`.pi/skills/`（`qualcomm-android-flashing`、`qualcomm-edl-flashing`、`gsi-device-adaptation`）。
- 项目记忆：`.pi/memory/`。EDL 工具：`qdl/build/qdl`（项目相对路径）。
- 通用方法论放全局技能；设备/资产细节留本项目。
