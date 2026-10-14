# 2026-10-09 · 相机：模块驱动收尾 + "camera not found" 根因

> 会话档案（快照）。**会话身份与检索 = pi 原生 `.pi/sessions/*.jsonl`**（`session_search` / `/resume`）；
> 本文件是 2026-10-14 从 `RESOURCES.md` §4 会话索引快照机械登记的**静态档案**，不含会话全文。
> 索引总表 / 统计 / 内核版本时间线见 [`../README.md`](../README.md)。

## 身份

| 字段 | 值 |
|---|---|
| **pi 会话 id** | `01a12140` |
| 磁盘匹配模式 | `.pi/sessions/*01a12140*.jsonl` |
| 日期 | 2026-10-09 |
| 名称（建议） | 相机：模块驱动收尾 + "camera not found" 根因 |
| 主题 | `camera` |
| 实机 | ✅ |
| 状态 | active |
| kv（提及） | vk64 |

### 磁盘上的会话文件（1）

  - `.pi/sessions/2026-10-09T15-21-08-181Z_01a12140-f755-7438-a0e0-8b7d24291a50.jsonl`

## 结论（原文）

收尾相机模块驱动 + 查「模块已装仍报 camera not found」→ 根因=现役 cmdline `elden_nocamera=1` 使模块根本没加载（配置态非驱动坏，`c377ac2`/`d8ba26d`；PITFALLS #157 类误判）

## 风险 / 未收口

相机⇄熄屏互斥（Q24）为已知约束；主题据首条指令+提交标题

## 相关提交

- 当日提交史：[`../../HISTORY/days/2026-10-09.md`](../../HISTORY/days/2026-10-09.md)（当日提交 **21** 条）

---

> 生成：`scripts/gen-sessions.py`（机械生成，勿手改）。源：`git show d8ae437:RESOURCES.md` §4 会话索引。
