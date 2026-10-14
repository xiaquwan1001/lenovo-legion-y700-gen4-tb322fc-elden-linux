# 2026-10-03 · 引导：Linux→fastboot能力核实

> 会话档案（快照）。**会话身份与检索 = pi 原生 `.pi/sessions/*.jsonl`**（`session_search` / `/resume`）；
> 本文件是 2026-10-14 从 `RESOURCES.md` §4 会话索引快照机械登记的**静态档案**，不含会话全文。
> 索引总表 / 统计 / 内核版本时间线见 [`../README.md`](../README.md)。

## 身份

| 字段 | 值 |
|---|---|
| **pi 会话 id** | `01a101f3` |
| 磁盘匹配模式 | `.pi/sessions/*01a101f3*.jsonl` |
| 日期 | 2026-10-03 |
| 名称（建议） | 引导：Linux→fastboot能力核实 |
| 主题 | `flashctl` |
| 实机 | ◐ |
| 状态 | superseded |
| kv（提及） | vk40,vk34 |

### 磁盘上的会话文件（1）

  - `.pi/sessions/2026-10-03T13-28-17-745Z_01a101f3-8051-7182-810c-66b47ece3746.jsonl`

## 结论（原文）

本地检索确认BCB bootonce不被采纳、ABL无明文串；给出flash-b.sh免fastboot做A/B

## 风险 / 未收口

「能力不存在」结论后被PSCI vendor reset推翻（见01a1021c）

## 相关提交

- 当日提交史：[`../../HISTORY/days/2026-10-03.md`](../../HISTORY/days/2026-10-03.md)（当日提交 **27** 条）

---

> 生成：`scripts/gen-sessions.py`（机械生成，勿手改）。源：`git show d8ae437:RESOURCES.md` §4 会话索引。
