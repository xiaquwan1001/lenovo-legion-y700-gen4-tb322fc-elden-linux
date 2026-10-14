# 2026-09-30 · 音频：AudioReach共享内存根因

> 会话档案（快照）。**会话身份与检索 = pi 原生 `.pi/sessions/*.jsonl`**（`session_search` / `/resume`）；
> 本文件是 2026-10-14 从 `RESOURCES.md` §4 会话索引快照机械登记的**静态档案**，不含会话全文。
> 索引总表 / 统计 / 内核版本时间线见 [`../README.md`](../README.md)。

## 身份

| 字段 | 值 |
|---|---|
| **pi 会话 id** | `01a0f23c` |
| 磁盘匹配模式 | `.pi/sessions/*01a0f23c*.jsonl` |
| 日期 | 2026-09-30 |
| 名称（建议） | 音频：AudioReach共享内存根因 |
| 主题 | `audio` |
| 实机 | ✅ |
| 状态 | active |
| kv（提及） | vk19,vk20,vk21,vk22,vk |

### 磁盘上的会话文件（1）

  - `.pi/sessions/2026-09-30T12-13-51-559Z_01a0f23c-4646-73a9-870e-599b997d1e9b.jsonl`

## 结论（原文）

用 kprobe 定位 SHARED_MEM_MAP 失败根因：PCM 缓冲地址 bit32 与 AudioReach 的 SMMU sid 约

## 风险 / 未收口

音频修复未收口（DMA掩码/地址约定改动未生效）；多次改内核刷机；TF卡SDR104静默写坏仅记录未解决

## 相关提交

- 当日提交史：[`../../HISTORY/days/2026-09-30.md`](../../HISTORY/days/2026-09-30.md)（当日提交 **13** 条）

---

> 生成：`scripts/gen-sessions.py`（机械生成，勿手改）。源：`git show d8ae437:RESOURCES.md` §4 会话索引。
