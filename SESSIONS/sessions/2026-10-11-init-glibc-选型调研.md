# 2026-10-11 · init / glibc 选型调研

> 会话档案（快照）。**会话身份与检索 = pi 原生 `.pi/sessions/*.jsonl`**（`session_search` / `/resume`）；
> 本文件是 2026-10-14 从 `RESOURCES.md` §4 会话索引快照机械登记的**静态档案**，不含会话全文。
> 索引总表 / 统计 / 内核版本时间线见 [`../README.md`](../README.md)。

## 身份

| 字段 | 值 |
|---|---|
| **pi 会话 id** | `01a12a67` |
| 磁盘匹配模式 | `.pi/sessions/*01a12a67*.jsonl` |
| 日期 | 2026-10-11 |
| 名称（建议） | init / glibc 选型调研 |
| 主题 | `research` |
| 实机 | ✗ |
| 状态 | reference |
| kv（提及） | — |

### 磁盘上的会话文件（1）

  - `.pi/sessions/2026-10-11T09-59-25-307Z_01a12a67-257a-763e-bc26-57650a52ee62.jsonl`

## 结论（原文）

报告写 `~/文档/arm平板-systemd-vs-openrc-glibc-vs-musl-调研-2026-10-11.md`；systemd 更适合（DE 绑定 `systemd --user`）

## 风险 / 未收口

独立于项目

## 相关提交

- 当日提交史：[`../../HISTORY/days/2026-10-11.md`](../../HISTORY/days/2026-10-11.md)（当日提交 **35** 条）

---

> 生成：`scripts/gen-sessions.py`（机械生成，勿手改）。源：`git show d8ae437:RESOURCES.md` §4 会话索引。
