# 2026-10-01 · 审计：Waydroid 卡点与自编 Mesa

> 会话档案（快照）。**会话身份与检索 = pi 原生 `.pi/sessions/*.jsonl`**（`session_search` / `/resume`）；
> 本文件是 2026-10-14 从 `RESOURCES.md` §4 会话索引快照机械登记的**静态档案**，不含会话全文。
> 索引总表 / 统计 / 内核版本时间线见 [`../README.md`](../README.md)。

## 身份

| 字段 | 值 |
|---|---|
| **pi 会话 id** | `01a0f7cd` |
| 磁盘匹配模式 | `.pi/sessions/*01a0f7cd*.jsonl` |
| 日期 | 2026-10-01 |
| 名称（建议） | 审计：Waydroid 卡点与自编 Mesa |
| 主题 | `probe-audit` |
| 实机 | ✗ |
| 状态 | reference |
| kv（提及） | vk27 |

### 磁盘上的会话文件（1）

  - `.pi/sessions/2026-10-01T14-10-51-607Z_01a0f7cd-c056-73b0-abfd-9657deeeb5fb.jsonl`

## 结论（原文）

卡点=SurfaceFlinger 需 bionic Mesa≥26.1；成品不存在→树内定向编可行但全量 sync 属过度下载，可用 free

## 风险 / 未收口

「升 Mesa 26.1 即不 hang」为推断非实测，存在 Glymur 反例；sync 未收敛。

## 相关提交

- 当日提交史：[`../../HISTORY/days/2026-10-01.md`](../../HISTORY/days/2026-10-01.md)（当日提交 **8** 条）

---

> 生成：`scripts/gen-sessions.py`（机械生成，勿手改）。源：`git show d8ae437:RESOURCES.md` §4 会话索引。
