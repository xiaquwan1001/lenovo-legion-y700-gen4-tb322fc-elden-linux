# .pi/ — 项目的 AI 大脑（技能 / 记忆 / 子代理 / 会话）

> 分层与 SSOT 见根目录 `INDEX.md` §2。本文件只说明 `.pi/` 内部各目录的分工与纳管状态。
> 全局（`~/.pi/agent/`）与项目（本目录）**叠加加载**，由工作目录决定，无需切换 profile。

## 目录分工

| 路径 | 内容 | 版本控制 | 说明 |
|---|---|---|---|
| `settings.json` | 本项目模型/会话/重试配置（`sessionDir`、provider、`retry`） | ✅ track | 项目级覆盖全局 |
| `CONCURRENCY.md` | **并发任务约束**（基线+fork / 提交 trailer / vk 分配 / lane 归属 / 父合并；入口 `scripts/lane.sh`） | ✅ track | 派子代理前必读 |
| `lanes/` | lane 运行时元数据（worktree/分支/baseline/状态） | ❌ ignore | 由 `scripts/lane.sh new` 写；机器本地 |
| `skills/` | **项目技能**（`SKILL.md` + `references/`）。与全局 `~/.pi/agent/skills/` 叠加 | ✅ track | `qualcomm-android-flashing` / `qualcomm-edl-flashing` / `gsi-device-adaptation`。references 正文不入上下文，**用时 grep** |
| `memory/` | **持久记忆**（跨会话）：`USER.md`(用户偏好) · `HINDSIGHT.md`(阶段决策) · `FAILURES.md`(反复踩的坑) | ✅ track | 由 `profile_memory` 追加；⚠️ **只有尾部 4–8 KB 注入系统提示**，故要主动修剪 |
| `missions/` | **子代理任务卡**（喂给 `Agent` 的任务背景，输入） | ✅ track | 文件名与 `agents/` 部分同名，语义不同（见下） |
| `agents/` | **子代理角色定义**（`role`/`model`/`objective`） | ✅ track | 由 `@tintinweb/pi-subagents` 加载为 `Agent` 可选类型；**无 harness 守护进程** |
| `sessions/` | 会话轨迹 `*.jsonl`（运行时产物） | ❌ ignore | 索引见 `RESOURCES.md §4`；归档策略见 `RESOURCES.md §3` H1 |

## `missions/` vs `agents/`（易混）

- `missions/<x>.md` = **做什么**：某专题的完整背景、已有进展、验收判据（长文）。
- `agents/<x>.md` = **谁来做**：front-matter（`role`/`model`/`objective`）+ 角色提示（短文）。
  同名（如 `audio-graphopen.md`）只是同一专题的两种文件，并非重复。

## 约定

- 技能保持**可移植**：不写主机名 / IP / 用户名 / 凭据（见全局 `AGENTS.md`）。
- `sessions/` 不入 git；`sn.img`、`bootslot-b/avb.key` 等敏感物禁止入库。已退场的插件入口（`pi-messenger.json`、`messenger/`、`swarm*.sh`）不再放回本目录 → `archive/2026-10-04-retired-entrypoints/`。
- 记忆只存**跨会话有用**的偏好/教训/决策，不存可随时重推的临时细节。
