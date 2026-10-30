# .pi/ — 项目的 AI 大脑（技能 / 记忆 / 子代理 / 会话）

> 分层与 SSOT 见根目录 `INDEX.md` §2。本文件只说明 `.pi/` 内部各目录的分工与纳管状态。
> 全局（`~/.pi/agent/`）与项目（本目录）**叠加加载**，由工作目录决定，无需切换 profile。

## 目录分工

| 路径 | 内容 | 版本控制 | 说明 |
|---|---|---|---|
| `settings.json` | 本项目模型/会话/重试配置（`sessionDir`、provider、`retry`） | ✅ track | 项目级覆盖全局 |
| `AGENT-OPS.md` | **agent 行为/授权规范（唯一入口）**：自主优先 / 风险先备份 / 异常才上报 / 物理干预边界 / 写入权限 / 汇报时间盒 | ✅ track | 所有会话与子代理必读 |
| `CONCURRENCY.md` | **并发细则**（基线+fork / 提交 trailer / vk 分配 / lane 归属 / 父合并；入口 `scripts/lane.sh`） | ✅ track | `AGENT-OPS` 的下级；派子代理前必读 |
| `ORCHESTRATION.md` | **三层编排协议**（总管 / 一级角色 / 二级叶级）：职责、递归硬条件、深派判据、回执与复核、树内并发配额 | ✅ track | 2026-10-31 立；与 `CONCURRENCY.md` 同级，均受 `AGENT-OPS` 约束 |
| `lanes/` | lane 运行时元数据（worktree/分支/baseline/状态） | ❌ ignore | 由 `scripts/lane.sh new` 写；机器本地 |
| `skills/` | **项目技能**（`SKILL.md` + `references/`）。与全局 `~/.pi/agent/skills/` 叠加 | ✅ track | `qualcomm-android-flashing` / `qualcomm-edl-flashing` / `gsi-device-adaptation`。references 正文不入上下文，**用时 grep** |
| `plans/` | `plan` 技能产出的方案草稿（非权威，落地后结论进领域层） | ✅ track | 临时规划产物 |
| `missions/` | **子代理任务卡**（作为 `fabric_exec` 里 `agents.run({task})` 的派工背景，输入） | ✅ track | 文件名与 `agents/` 部分同名，语义不同（见下） |
| `agents/` | **子代理角色卡（提示词源）**：一级 Lead（`physical-exec`/`doc-audit-lead`/`mail-io`/`code-boundary`）+ 二级叶级（`impl-worker`/`verify-worker`）+ 既有专题卡 | ✅ track | pi-fabric **会按 `name` 直接读取**本目录 `*.md`（正文作 systemPrompt，`tools`/`model` 可被调用覆盖）；派工时也可只传 `agent` 名 |
| ~~`workflows/`~~ | ✅ **已清空移除（2026-10-12）**：pi-subagents workflow 脚本（5 个）+ `plans/*-workflow.js`（5 个）已移入 `archive/2026-10-12-retired-pi-subagents-workflows/` | — | 旧方言已废弃、仅供追溯；复用须按 fabric 重写（`agents.run`/`Promise.allSettled`），**不要原地改语法** |
| `sessions/` | 会话轨迹 `*.jsonl`（运行时产物） | ❌ ignore | **逐会话快照档案见 `../SESSIONS/`**（检索仍用 `session_search`/`/resume`）；归档策略见 `../RESOURCES/README.md` §3 |

## `missions/` vs `agents/`（易混）

- `missions/<x>.md` = **做什么**：某专题的完整背景、已有进展、验收判据（长文）。
- `agents/<x>.md` = **谁来做**：front-matter（`name`/`description`/`model`/`tools`）+ 角色提示（短文）。
  pi-fabric 会读本目录（不递归），派工时可用 `agents.run({ agent: "<name>" })` 直接引用；
  若角色卡不在 Fabric 搜索路径或需要临时角色，仍可把正文拼进 `task`。

## 约定

- 技能保持**可移植**：不写主机名 / IP / 用户名 / 凭据（见全局 `AGENTS.md`）。
- **行为标准只写在 `.pi/AGENT-OPS.md`**；子代理角色卡（`agents/`）只写角色专属补充，不另行定义自主/授权边界。
- ~~不写 summary/总结/摘要~~ **该禁令已作废（2026-10-19，用户裁定）**：它只造成 pi agent 文本流解析异常，是错误归因。现在允许收尾短报，但仍要求**交付落盘文件**，回复以「产物路径 + 关键数字」为主（见 `.pi/AGENT-OPS.md` §5/§6）。
- **编排接口（2026-10-31 起）**：总管 / 一级角色 / 二级叶级三层，协议见 **`ORCHESTRATION.md`**；子代理走 `fabric_exec`（pi-fabric），
  不再用 pi-subagents。并发 **16**、递归深度 **2**（`agents.maxConcurrent` / `agents.maxDepth`，全局+项目 `fabric.json` 均显式）；
  树内配额 4 个一级 × 3 个二级。独立任务用 `Promise.allSettled`/`workflow.parallel`。
  细则见全局技能 `fabric-dispatch-checklist`；改 `fabric.json` 后需 `/reload` 才生效。
  **模型：一律 ustc 池**（`custom.ustc-pool/ustc` / `ustc-worker` / `ustc-research` / `ustc-audit`，本机 litellm 网关轮转 key）；
  项目级 `.pi/fabric.json` 已把全部别名指向该池。**`agents.run` 的 `tools` 是完整白名单**（不列就用不了；递归调用才会自动附加 `fabric_exec`）。
  - **角色工具集**：角色卡 frontmatter `tools` 即默认白名单（一级 `mail-io` 含 `web_*`，`code-boundary` 含 `edit/write` 用于写报告）；调用时传 `tools` 会整体覆盖。Fabric 的 `tools:[...]` 是**完整白名单**（不显式列出 `web_*` 的子代理只会回 NO_WEB_TOOL），所以需要联网时务必显式传/写。
- `sessions/` 不入 git；`sn.img`、`bootslot-b/avb.key` 等敏感物禁止入库。已退场的插件入口（`pi-messenger.json`、`messenger/`、`swarm*.sh`）不再放回本目录 → `archive/2026-10-04-retired-entrypoints/`。
- 记忆只存**跨会话有用**的偏好/教训/决策，不存可随时重推的临时细节。项目记忆已迁 hermes（`~/.pi/agent/pi-hermes-memory/` + `~/.pi/agent/projects-memory/<repo>/`，`memory_search` 可检索）——`.pi/memory/` 已于 2026-10-05 删除。
