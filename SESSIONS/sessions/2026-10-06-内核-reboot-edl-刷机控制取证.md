# 2026-10-06 · 内核：reboot edl / 刷机控制取证

> 会话档案（快照）。**会话身份与检索 = pi 原生 `.pi/sessions/*.jsonl`**（`session_search` / `/resume`）；
> 本文件是 2026-10-14 从 `RESOURCES.md` §4 会话索引快照机械登记的**静态档案**，不含会话全文。
> 索引总表 / 统计 / 内核版本时间线见 [`../README.md`](../README.md)。

## 身份

| 字段 | 值 |
|---|---|
| **pi 会话 id** | `01a11100` |
| 磁盘匹配模式 | `.pi/sessions/*01a11100*.jsonl` |
| 日期 | 2026-10-06 |
| 名称（建议） | 内核：reboot edl / 刷机控制取证 |
| 主题 | `flashctl` |
| 实机 | ✅ |
| 状态 | active |
| kv（提及） | — |

### 磁盘上的会话文件（1）

  - `.pi/sessions/2026-10-06T11-37-08-097Z_01a11100-cf01-73c1-bfd8-596ba8bb03c0.jsonl`

## 结论（原文）

`reboot edl`/recovery 路径取证：vk41 钩子映射 bootloader/edl → PSCI RESTART2；recovery 落 nvmem-reboot-mode 未覆盖

## 风险 / 未收口

reboot edl 实测待做

## 相关提交

- 当日提交史：[`../../HISTORY/days/2026-10-06.md`](../../HISTORY/days/2026-10-06.md)（当日提交 **30** 条）

---

> 生成：`scripts/gen-sessions.py`（机械生成，勿手改）。源：`git show d8ae437:RESOURCES.md` §4 会话索引。
