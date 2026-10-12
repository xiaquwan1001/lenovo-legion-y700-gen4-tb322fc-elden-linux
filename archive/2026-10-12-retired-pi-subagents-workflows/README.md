# 已退役：pi-subagents workflow 脚本（2026-10-12 归档）

来源（原路径）：`.pi/workflows/*.js`（5 个）、`.pi/plans/*-workflow.js`（5 个）。

- **为什么退役**：这些是 pi-subagents 的受限 workflow 方言（```js workflow 块 / `runs.run` / `runs.all` / `emit`）。
  pi-subagents 已于 **2026-10-12 从 `~/.pi/agent/settings.json` 的 packages 卸载**，改用 **pi-fabric（`fabric_exec`）**；旧方言不再被任何插件解析。
- **用途**：仅追溯当时的编排意图与 lane 划分，**不要原地改语法**。
- **复用方式**：按 Fabric 重写为普通 TS 程序 —— `runs.run` → `await agents.run`、`runs.all` → `Promise.allSettled`、`emit` → `return` 结构化对象；细则见全局技能 `fabric-dispatch-checklist`。

相关：`../../.pi/README.md`、项目 `INDEX.md` §2。
