# 2026-10-06 · initramfs：载具固化 + 可复现打包

> 会话档案（快照）。**会话身份与检索 = pi 原生 `.pi/sessions/*.jsonl`**（`session_search` / `/resume`）；
> 本文件是 2026-10-14 从 `RESOURCES.md` §4 会话索引快照机械登记的**静态档案**，不含会话全文。
> 索引总表 / 统计 / 内核版本时间线见 [`../README.md`](../README.md)。

## 身份

| 字段 | 值 |
|---|---|
| **pi 会话 id** | `01a10f5e` |
| 磁盘匹配模式 | `.pi/sessions/*01a10f5e*.jsonl` |
| 日期 | 2026-10-06 |
| 名称（建议） | initramfs：载具固化 + 可复现打包 |
| 主题 | `init/boot` |
| 实机 | ◐ |
| 状态 | active |
| kv（提及） | vk61 |

### 磁盘上的会话文件（1）

  - `.pi/sessions/2026-10-06T04-00-04-600Z_01a10f5e-5bf8-709b-b63f-bc33920ad026.jsonl`

## 结论（原文）

修 `cpio --reproducible`/`sort -z`/`gzip -n` 使打包可复现；定 slim/full 两载具；真机 `inittest-veh` 进桌面、init 日志干净

## 风险 / 未收口

WiFi 慢归 Q26

## 相关提交

- 当日提交史：[`../../HISTORY/days/2026-10-06.md`](../../HISTORY/days/2026-10-06.md)（当日提交 **30** 条）

---

> 生成：`scripts/gen-sessions.py`（机械生成，勿手改）。源：`git show d8ae437:RESOURCES.md` §4 会话索引。
