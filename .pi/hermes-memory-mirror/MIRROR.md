# hermes 项目记忆 — 只读镜像（勿手改）

本目录是 **生成物**：由 `scripts/sync-hermes-memory.sh` 从**仓库之外**的 hermes
活文件单向快照而来，随本仓库一起异地备份（USTC GitLab / GitHub）。

| 项 | 值 |
|---|---|
| 源（唯一可写面） | `~/.pi/agent/projects-memory/y700-elden/` |
| 快照内容 | `MEMORY.md` + `skills/*/SKILL.md` |
| 不含 | hermes 自动滚动的 `.MEMORY.md.recovery-*` / `.retired-*`（派生历史，约 26 M） |
| 刷新 | `scripts/sync-hermes-memory.sh` |
| 一致性自检 | `scripts/sync-hermes-memory.sh --check` |

**方向纪律**：要改记忆就改 hermes 活文件（`memory_add` 等工具），改完跑一次同步；
**不要**直接编辑本目录 —— 下次同步会原样覆盖。
