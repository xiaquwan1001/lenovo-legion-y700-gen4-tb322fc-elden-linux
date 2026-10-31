# ORCHESTRATION — 三层编排协议（总管 / 一级角色 / 二级执行）

> 状态：2026-10-31 立，用户裁定「总管只对接需求，一级按角色分工，二级可选并行」。
> 上位：**`.pi/AGENT-OPS.md`**（行为/授权唯一入口，本文件不重复其自主优先与备份口径）；
> 并发/基线/lane：**`.pi/CONCURRENCY.md`**；角色卡：**`.pi/agents/`**；入口：`INDEX.md` §2。

---

## 1. 三层职责（谁做什么、谁不能做什么）

| 层 | 身份 | 做 | 不做 | 交付 |
|---|---|---|---|---|
| **L0 总管** | 与用户对话的那个 Pi 会话（Main） | 需求 ⇄ 工程约束；拆成可验收派工单；派一级；**独立复核**；写领域层 SSOT；合并 lane；与用户确认外部阻塞 | 长链调试、逐文件实现、反复试错；绕过一级直接刷机/改内核 | 派工单、验收结论、SSOT 更新、给用户的一页汇报 |
| **L1 角色** | 常设角色卡（4 个，见 §2） | 把派工单拆成子任务；判断复杂度；**必要时**派二级；汇总、自检、回执 | 改领域层 SSOT；跨角色扩权；把串行工作伪并行 | 产物（报告/补丁/session）+ 回执（路径 + 关键数字 + 复现命令） |
| **L2 执行** | 叶级 agent（可选） | 执行一个边界清晰的子任务；在自己的路径/worktree 内落产物 | 再派发（深度 2 是叶）；改别人的路径；跳 role 边界 | 单一子任务产物 + 自检命令输出 |

**总管允许直接做的事**：读/搜/看证据；≤3 步的单点复核（验收硬规则 7「worker 自报不可信」）；
改 SSOT；派工与收口。**「减少直接调试」不等于「放弃复核」**——复核必须由总管亲自重跑关键门禁。

---

## 2. 一级角色（常设，角色卡即提示词）

| 角色卡 | 职责 | 不碰 |
|---|---|---|
| `physical-exec` | 物理执行：设备侧探测/写入、刷写/上机、构建打包、脚本落地 | 领域层文档定稿、上游邮件 |
| `doc-audit-lead` | 文档审计：状态漂移/死链/编号/SSOT 违例/孤儿报告/资源台账 | 修改任何 README/INDEX/TASKS/DEVICE/RESOURCES |
| `mail-io` | 邮件收发：收信分诊、lore 归档核对、补丁/回信草稿、归档落盘 | **未经用户按批放行的发信**、凭据落盘 |
| `code-boundary` | 代码边界检查：上游化三问门、checkpatch/DTC/ABI、下游隔离、单写者/模块边界 | 越界重构、无指派的功能实现 |

二级执行（叶，可选）：`impl-worker`（有界实现）、`verify-worker`（只读独立复核），以及既有专题卡
（`camera`/`bootchain`/`dt-ui`/`upstream-m`/`bench`/…，作为某个子任务的专才）。

---

## 3. 生效参数（配置真值，不在此发明）

- `agents.maxDepth: 2` —— root=0，L1=1，L2=2；**L3 被 Fabric 拒绝**（`depth > maxDepth` 抛错）。`0` 关闭派发。
- `agents.maxConcurrent: 16` —— 每个 Fabric 进程一个全局子代理信号量。
- `agents.maxPerExecution: 16` —— 单次 `fabric_exec` 最多启动 16 个子代理。
- **树内配额（策略，非配置）**：总管同时 ≤ **4 个 L1**；每个 L1 同时 ≤ **3 个 L2**；
  合计 ≤ 4 + 4×3 = **16**。L2 不得再派（深度与工具双重保证，见 §4）。
- 值真源 = `~/.pi/agent/fabric.json`（全局）+ `.pi/fabric.json`（本项目覆盖）。**改后必须 `/reload` 才生效。**

---

## 4. 递归的硬条件（技术事实，派错就“静默不能派”）

1. **总管派 L1 必须显式 `recursive: true`**：只有它会把 `fabric_exec` 放进子代理工具集；
   不传 ⇒ L1 只是普通叶，**无法派 L2**（不是报错，是根本没工具）。
2. **L1 派 L2 不要传 `recursive`**：L2 是叶；非 recursive 子代理不会拿到 `fabric_exec`，
   再叠加深度上限，形成双重硬闸。
3. **`tools` 是完整白名单**（不是增量）：不列 `bash`/`read`/`edit`/`write`/`grep`/`find`/`ls` 就没有；
   要 `web_*` 必须显式列。`recursive: true` 时 `fabric_exec` 由 Fabric 自动追加。
4. **本项目模型一律用 ustc 池**（`custom.ustc-pool/*`，经本机 litellm 网关 `ustc-pool` 轮转 key）：
   默认 `ustc`、执行/实现 `ustc-worker`、研究 `ustc-research`、审计/边界检查 `ustc-audit`。
   派工时写显式 `provider/model`（别名在会话内可能不解析）；池内 key 轮转/限流由 litellm 负责，不手动绑 key。
5. 递归子代理还会继承 `agent` 风险授权；**不继承**网络/写盘授权——需要时在派工单里写清。
6. **L1 派 L2 必须同步 await**：在一次普通 `fabric_exec`（可传 `timeoutMs`）里用 `Promise.allSettled` 起 L2，**不要用 `background: true`**。
   实测（2026-10-30 重派轮）：子代理里把 L2 扇出挂成后台程序 ⇒ 15 分钟零产物、`agents.list()` 返回 0、无子进程，而同步 waited 版本两轮均正常。
   出现该症状时先改回同步派发，不要归因于模型/限流。

派 L1 的最小调用形：

```ts
const r = await agents.run({
  agent: "physical-exec",                 // .pi/agents/*.md 的 name
  task: dispatchText,                     // 目标/边界/验收/回执字段
  recursive: true,                        // ★ 必须
  cwd: "/home/xuqianhui/y700-elden",
  model: "custom.ustc-pool/ustc-worker",   // 例：物理执行走 worker 别名
  timeoutMs: 6 * 3600_000,
});
```

---

## 5. 派工单最小字段（总管 → L1；L1 向下复制同一骨架）

1. **目标**（一句话）与**验收判据**（可执行命令 / 可测数字，不用“完成/搞定”）。
2. **边界**：可写路径白名单、禁改文件（领域层 SSOT）、是否需要 lane/worktree、**是否持设备锁**。
3. **已知事实**：指向 `PITFALLS`/`reports`/`sessions` 的现有结论，禁止从零重推。
4. **交付**：产物路径（`reports/`、`patches/`、`sessions/` 的具体文件名）+ 回执字段。
5. **时间盒**（`timeout -k`）+ 预算（`agentBudget`/`tokenBudget`）+ **升级条件**（哪些异常必须停并上报）。

### L1 的深派决策（满足才派，不满足自己做）

- 子任务 ≥ 2 个且**相互独立**（无共享写路径，或全部只读）；
- 每个子任务本身 ≥ 15 分钟或 ≥ 3 个文件的量级；
- 写路径可**互不重叠**地切开（否则先由 L1 串行切分或改派单写者）；
- 设备动作**永远串行**（全局单资源，`scripts/device-lock.sh`），不得并行派上机。

不满足以上任一条 ⇒ L1 自己顺序做。**禁止**为“看起来像并行”而派 L2；**禁止**把同一文件的写任务拆给两个 L2。

---

## 6. 写权限、lane 与外部副作用

- **单写者**：总管唯一写 `main` 与领域层 SSOT；L1 只读 SSOT；L2 只写被指派的路径。
- 并发写 → 按 `.pi/CONCURRENCY.md` 走 lane/worktree；提交带 `Lane/Agent/Baseline/Task/VK` trailer。
- **设备是单一串行资源**：任何上机/刷写/复现前 `scripts/device-lock.sh`，同一时刻仅一个持有者。
- **物理动作**（按键进 fastboot/EDL、插拔、断电）= 用户执行；agent 给精确步骤与预期现象。
- **发信**：`mail-io` 默认只读/只起草；投递须用户按批放行（`TASKS/README.md` §7 口径）。**2026-10-31 用户授权：回信/cover 正文可由 agent 撰写**（含「not with LLM」类线程），前提 = 开头如实披露 AI 辅助 + 每条论断可复现证据 + 逐条回应，见 `AGENTS.md`「上游发信」；**投递动作仍逐批放行**。凭据不入派工单、不落盘、不进回复。

---

## 7. 回执与复核（自报不可信）

回执固定四段，缺一段视为未交付：

```
结论：<一句话 + PASS/FAIL/未证实>
产物：<路径列表（必须真实存在，L1 用 ls/read 验证）>
关键数字：<命令输出里的数、计数、哈希、版本>
复现：<最小可复现命令>
```

- L2 → L1：L1 必须 `ls`/`read` 验证产物存在，并**重跑廉价门禁**（`check-doctor --staged-fast`、构建一次、单条 `fastboot getvar` 等）。
- **证据先落盘（长任务必做）**：每条命令 `2>&1 | tee reports/artifacts/<topic>-<date>/<gate>.log`，每过一门立即把 rc/warn/err 追加进报告；
  不要把大段日志读进上下文（只 `grep -c`/`tail -3`）。理由：2026-10-30 一次 L1 进程 SIGSEGV 死掉，未 tee 的门禁全部丢失、必须重跑。
- L1 → 总管：总管按验收判据**独立复跑**（硬规则：worker 自报成功不可信）；不复跑不得写“已修复/已解决”。
- 失败/半成品同样落盘，状态词只用「未解 / 未证实 / 未上机」。

---

## 8. 升级与失败处置

- L2 遇**超出预期**的错误（与 `PITFALLS`/`RUNBOOK` 已知模式不符、设备不回退、无可用通道）⇒ 停止重试，保留现场，回 L1。
- L1 判断无法在派工边界内完成（缺权限/缺设备/需改 SSOT）⇒ 回总管，不自行扩权。
- 总管遇外部依赖（凭据/账号/权限/隐私/物理动作）⇒ 直接上报用户。
- 同一方案只做一次正反判断；长任务无进展先落盘复盘（操作史/根因/文件清单），再换方案。

---

## 9. 自检清单（改配置/角色卡后跑一遍）

1. `python3 -m json.tool ~/.pi/agent/fabric.json` 与 `.pi/fabric.json` 通过；两处 `maxDepth=2`、`maxConcurrent=16`。
2. `fabric_exec` 里 `agents.definitions()`：新角色卡出现在列表且 `error` 为空；`tools`/`model` 如期。
3. 冒烟：总管派 1 个 L1（`recursive: true`），L1 再派 1 个 L2 跑一条 `echo` 并回传——证明深度 2 与递归工具授权可用。
4. 冒烟后核对行数为 `depth: 2`（L2）、`PI_FABRIC_DEPTH` 递增，且 L2 不具备 `fabric_exec`。
5. `/reload` 后改动才进入运行中的会话；`scripts/check-doctor.sh` FAIL=0；`git commit`。

---

## 10. 扩角色（保持单一真源）

新增一级角色 = 新文件 `.pi/agents/<name>.md`（`name`/`description`/`model`/`thinking`/`tools` + 角色正文，
正文里引用本文件而不复制行为标准）→ 在 §2 表加一行 → `.pi/README.md` 角色表同步。
新增二级 = 只加一个叶卡，并在 §2 末句列出；无需改协议。
