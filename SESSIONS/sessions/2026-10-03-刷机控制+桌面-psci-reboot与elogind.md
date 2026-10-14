# 2026-10-03 · 刷机控制+桌面：PSCI reboot与elogind

> 会话档案（快照）。**会话身份与检索 = pi 原生 `.pi/sessions/*.jsonl`**（`session_search` / `/resume`）；
> 本文件是 2026-10-14 从 `RESOURCES.md` §4 会话索引快照机械登记的**静态档案**，不含会话全文。
> 索引总表 / 统计 / 内核版本时间线见 [`../README.md`](../README.md)。

## 身份

| 字段 | 值 |
|---|---|
| **pi 会话 id** | `01a1021c` |
| 磁盘匹配模式 | `.pi/sessions/*01a1021c*.jsonl` |
| 日期 | 2026-10-03 |
| 名称（建议） | 刷机控制+桌面：PSCI reboot与elogind |
| 主题 | `flashctl-power` |
| 实机 | ✅ |
| 状态 | active |
| kv（提及） | vk41,vk40 |

### 磁盘上的会话文件（1）

  - `.pi/sessions/2026-10-03T14-13-36-832Z_01a1021c-fdc0-7182-810c-66b73222d0e6.jsonl`

## 结论（原文）

实机确认 PSCI SYSTEM_RESET2 vendor reset 生效：`eldroid-bootctl reboot bootloader` 真进fastboot；另修elogind关机（HandlePowerKey占位致shutdown inhibitor卡in-progress）

## 风险 / 未收口

EDL/recovery的vendor reset未测；长按关机待实测；配置重启持久性待复核

## 相关提交

- 当日提交史：[`../../HISTORY/days/2026-10-03.md`](../../HISTORY/days/2026-10-03.md)（当日提交 **27** 条）

---

> 生成：`scripts/gen-sessions.py`（机械生成，勿手改）。源：`git show d8ae437:RESOURCES.md` §4 会话索引。
