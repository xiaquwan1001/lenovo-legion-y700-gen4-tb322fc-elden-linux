# RUNBOOK-BRINGUP 会话进度（sessions/）

本目录按会话记录 RUNBOOK-BRINGUP 角度的迭代进度。每个会话一个文件，文件名：`YYYY-MM-DD-<主题>.md`（如 `2026-10-14-persistent-boot-73.md`）。

> **检索约定**：会话身份与全文检索走 pi 原生项目会话（`.pi/sessions/*.jsonl`，`session_search` / `/resume`），本目录只放提炼后的进度快照，不维护会话索引表。

## 头部字段约定

每份进度文件以如下字段开头：

```markdown
---
日期: YYYY-MM-DD
pi 会话 id: <.pi/sessions/*.jsonl 对应的 session id>
主题: <一句话主题>
结论: <本会话达成的结论/状态>
证据指针: <命令输出/日志/文件路径等证据的落点>
★SSOT 待并入: <需并入本目录 README.md 的条目；无则写「无」>
---
```

## 流程

1. 会话中产生对启动直启（persistent boot）方案的新结论或新步骤时，新建 `YYYY-MM-DD-<主题>.md` 记录。
2. 标记 `★SSOT 待并入` 的条目由策展者核对后并入 `../README.md` 正文，并入后在进度文件中移除该标记。
3. 本目录文件为过程记录；`../README.md` 才是 RUNBOOK-BRINGUP 角度的策展 SSOT。
