# .pi/ — 项目的 AI 大脑（技能 / 记忆 / 子代理 / 会话）

> 分层与 SSOT 见根目录 `INDEX.md` §2。本文件只说明 `.pi/` 内部各目录的分工与纳管状态。
> 全局（`~/.pi/agent/`）与项目（本目录）**叠加加载**，由工作目录决定，无需切换 profile。

## 目录分工

| 路径 | 内容 | 版本控制 | 说明 |
|---|---|---|---|
| `settings.json` | 本项目模型/会话/重试配置（`sessionDir`、provider、`retry`） | ✅ track | 项目级覆盖全局 |
| `AGENT-OPS.md` | **agent 行为/授权规范（唯一入口）**：自主优先 / 风险先备份 / 异常才上报 / 物理干预边界 / 写入权限 / 汇报时间盒 | ✅ track | 所有会话与子代理必读 |
| `CONCURRENCY.md` | **并发细则**（基线+fork / 提交 trailer / vk 分配 / lane 归属 / 父合并；入口 `scripts/lane.sh`） | ✅ track | `AGENT-OPS` 的下级；派子代理前必读 |
| `lanes/` | lane 运行时元数据（worktree/分支/baseline/状态） | ❌ ignore | 由 `scripts/lane.sh new` 写；机器本地 |
| `skills/` | **项目技能**（`SKILL.md` + `references/`）。与全局 `~/.pi/agent/skills/` 叠加 | ✅ track | `qualcomm-android-flashing` / `qualcomm-edl-flashing` / `gsi-device-adaptation`。references 正文不入上下文，**用时 grep** |
| `plans/` | `plan` 技能产出的方案草稿（非权威，落地后结论进领域层） | ✅ track | 临时规划产物 |
| `missions/` | **子代理任务卡**（作为 `fabric_exec` 里 `agents.run({task})` 的派工背景，输入） | ✅ track | 文件名与 `agents/` 部分同名，语义不同（见下） |
| `agents/` | **子代理角色卡（提示词源）**（`name`/`description` + 角色提示） | ✅ track | ⚠️ pi-subagents 已于 2026-10-12 卸载，本目录**不再被任何插件自动加载**；派工时把角色卡正文 + 任务卡拼成 `task` 传给 Fabric（`agents.run`/`agents.spawn`），模型用别名或 provider/id |
| ~~`workflows/`~~ | ✅ **已清空移除（2026-10-12）**：pi-subagents workflow 脚本（5 个）+ `plans/*-workflow.js`（5 个）已移入 `archive/2026-10-12-retired-pi-subagents-workflows/` | — | 旧方言已废弃、仅供追溯；复用须按 fabric 重写（`agents.run`/`Promise.allSettled`），**不要原地改语法** |
| `sessions/` | 会话轨迹 `*.jsonl`（运行时产物） | ❌ ignore | 索引见 `RESOURCES.md §4`；归档策略见 `RESOURCES.md §3` H1 |

## `missions/` vs `agents/`（易混）

- `missions/<x>.md` = **做什么**：某专题的完整背景、已有进展、验收判据（长文）。
- `agents/<x>.md` = **谁来做**：front-matter（`name`/`description`）+ 角色提示（短文）。迁移后**没有任何插件解析这些字段**（`advertise`/`role`/`objective` 均仅供人读），派工时必须显式把角色卡正文带进 `task`。
  同名（如 `audio-graphopen.md`）只是同一专题的两种文件，并非重复。

## 约定

- 技能保持**可移植**：不写主机名 / IP / 用户名 / 凭据（见全局 `AGENTS.md`）。
- **行为标准只写在 `.pi/AGENT-OPS.md`**；子代理角色卡（`agents/`）只写角色专属补充，不另行定义自主/授权边界。
- **编排接口（2026-10-12 起）**：子代理走 `fabric_exec`（pi-fabric），不再用 pi-subagents；模型别名 `worker`/`scout`/`delegate`/`fast`/`flash`→`ustc-pool/ustc-worker`、`complex`/`researcher`/`oracle`/`evidence-auditor`→`ustc-pool/ustc-complex`、`default`→`ustc-pool/ustc`（**经网关只能选 litellm 别名**，原始名 `deepseek-flash*`/`glm-5.3-flash` 已不可用）；并发 ≤3；独立任务用 `Promise.allSettled`。细则见全局技能 `fabric-dispatch-checklist`；改 `fabric.json` 后需 `/reload` 才生效。
  - **角色工具集（原 `settings.json` 的 `subagents.agentOverrides`，已随本次迁移删除）**：`researcher` = `read,grep,ls,write,web_search,web_fetch,web_providers`；`evidence-auditor` = `read,grep,ls,web_search,web_fetch,web_providers`（只读）。Fabric 的 `tools:[...]` 是**完整白名单**（2026-10-12 实测：不显式列出 `web_*` 的子代理只会回 NO_WEB_TOOL；全局 `agents.defaultTools` 不含 `web_*`），所以每次派工必须显式传 `tools`。
- `sessions/` 不入 git；`sn.img`、`bootslot-b/avb.key` 等敏感物禁止入库。已退场的插件入口（`pi-messenger.json`、`messenger/`、`swarm*.sh`）不再放回本目录 → `archive/2026-10-04-retired-entrypoints/`。
- 记忆只存**跨会话有用**的偏好/教训/决策，不存可随时重推的临时细节。项目记忆已迁 hermes（`~/.pi/agent/pi-hermes-memory/` + `~/.pi/agent/projects-memory/<repo>/`，`memory_search` 可检索）——`.pi/memory/` 已于 2026-10-05 删除。
