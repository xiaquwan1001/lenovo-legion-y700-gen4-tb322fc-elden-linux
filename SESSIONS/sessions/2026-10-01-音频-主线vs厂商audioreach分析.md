# 2026-10-01 · 音频:主线vs厂商AudioReach分析

> 会话档案（快照）。**会话身份与检索 = pi 原生 `.pi/sessions/*.jsonl`**（`session_search` / `/resume`）；
> 本文件是 2026-10-14 从 `RESOURCES.md` §4 会话索引快照机械登记的**静态档案**，不含会话全文。
> 索引总表 / 统计 / 内核版本时间线见 [`../README.md`](../README.md)。

## 身份

| 字段 | 值 |
|---|---|
| **pi 会话 id** | `01a0f5a0` |
| 磁盘匹配模式 | `.pi/sessions/*01a0f5a0*.jsonl` |
| 日期 | 2026-10-01 |
| 名称（建议） | 音频:主线vs厂商AudioReach分析 |
| 主题 | `audio` |
| 实机 | ✗ |
| 状态 | active |
| kv（提及） | — |

### 磁盘上的会话文件（1）

  - `.pi/sessions/2026-10-01T04-01-59-705Z_01a0f5a0-5199-7416-b884-664be7e3c7a3.jsonl`

## 结论（原文）

发现厂商Android内核本身自带q6apm/audioreach(AudioReach SPF路径),正在diff厂商与主线APM协议实现,未

## 风险 / 未收口

结论未闭环;主线apr按protection-domain门控/GPR_SVC_ADSP_CORE值待确认;tplg I2S子图未注册根因改动未

## 相关提交

- 当日提交史：[`../../HISTORY/days/2026-10-01.md`](../../HISTORY/days/2026-10-01.md)（当日提交 **8** 条）

---

> 生成：`scripts/gen-sessions.py`（机械生成，勿手改）。源：`git show d8ae437:RESOURCES.md` §4 会话索引。
