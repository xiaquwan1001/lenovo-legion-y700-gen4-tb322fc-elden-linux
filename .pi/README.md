# .pi/ — 项目的 AI 大脑（技能 / 记忆 / swarm / 会话）

> 分层与 SSOT 见根目录 `INDEX.md` §2。本文件只说明 `.pi/` 内部各目录的分工与纳管状态。
> 全局（`~/.pi/agent/`）与项目（本目录）**叠加加载**，由工作目录决定，无需切换 profile。

## 目录分工

| 路径 | 内容 | 版本控制 | 说明 |
|---|---|---|---|
| `settings.json` | 本项目模型/会话/重试配置（`sessionDir`、provider、`retry`） | ✅ track | 项目级覆盖全局 |
| `pi-messenger.json` | pi-messenger（swarm）配置，如 `maxConcurrentSpawns` | ✅ track | 限流靠它 |
| `skills/` | **项目技能**（`SKILL.md` + `references/`）。与全局 `~/.pi/agent/skills/` 叠加 | ✅ track | `qualcomm-android-flashing` / `qualcomm-edl-flashing` / `gsi-device-adaptation`。references 正文不入上下文，**用时 grep** |
| `memory/` | **持久记忆**（跨会话）：`USER.md`(用户偏好) · `HINDSIGHT.md`(阶段决策) · `FAILURES.md`(反复踩的坑) | ✅ track | 由 `profile_memory` 追加，按 `## Memory - <date>` 分块 |
| `missions/` | **swarm 任务卡**（喂给子代理的任务说明，输入） | ✅ track | 文件名与 `agents/` 部分同名，语义不同（见下） |
| `agents/` | **swarm 子代理定义**（`role`/`model`/`objective`，输入） | ✅ track | 一个 mission 可对应多个 agent 角色 |
| `sessions/` | 会话轨迹 `*.jsonl`（运行时产物） | ❌ ignore | 索引见 `RESOURCES.md §4`；归档策略见 `RESOURCES.md §3` H1 |
| `messenger/` | pi-messenger **运行时状态**（channels/registry/tasks/agents） | ❌ ignore | 可安全删除，harness 重建 |

## `missions/` vs `agents/`（易混）

- `missions/<x>.md` = **做什么**：某专题的完整背景、已有进展、验收判据（长文）。
- `agents/<x>.md` = **谁来做**：front-matter（`role`/`model`/`objective`）+ 角色提示（短文）。
  同名（如 `audio-graphopen.md`）只是同一专题的两种文件，并非重复。

## 约定

- 技能保持**可移植**：不写主机名 / IP / 用户名 / 凭据（见全局 `AGENTS.md`）。
- `sessions/`、`messenger/` 不入 git；`sn.img`、`bootslot-b/avb.key` 等敏感物禁止入库。
- 记忆只存**跨会话有用**的偏好/教训/决策，不存可随时重推的临时细节。
