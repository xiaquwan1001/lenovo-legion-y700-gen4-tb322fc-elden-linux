# AGENT-OPS — agent 行为与开发规范（唯一入口）

> **本文件是「agent 该怎么做事」的唯一入口。** 项目描述见根目录 `AGENTS.md`；技术踩坑/经验见 `PITFALLS/README.md`；
> 并发细则见 `.pi/CONCURRENCY.md`；设备上机步骤见 `RUNBOOK-BRINGUP/README.md`；状态/进度见 `INDEX.md` → `TASKS/README.md`。
> 领域层事实与档案证据不被本文件复述，只被引用。
> 状态：2026-10-06 立；同日用户定**自主优先**口径（风险先备份，异常才上报）。

---

## 1. 执行原则（自主优先；风险就备份；异常才上报）

**默认：agent 先自主执行。** 不再逐条请示，也不再把「谁执行」按动作类别禁止。
判据顺序：**是否会破坏当前可用系统 → 是否已备份 → 是否可回退 → 是否可观测**。

| 情形 | 行为 |
|---|---|
| 主机侧一切（构建/打包/编译/静态分析/检索/脚本/基准）+ 设备侧只读探测 + **常规设备写操作**（含 fastboot/EDL、分区/槽/固件写入、经 `scripts/device-lock.sh` 的串行访问） | **直接执行**，不必逐条请示 |
| **有写坏风险的写入**（分区/GPT/boot 槽/dtbo/vbmeta/固件，以及任一次 `fastboot` 写前） | **先备份**（`fastboot fetch` 将覆盖分区 + GPT 双表 dump + 记录回退路径），**再执行**；写后读回校验 |
| **物理上必须人做**（按键组合进 fastboot/EDL、插拔线缆/耳机、断电、EDL 短接） | 停下，给精确步骤与预期现象，**请用户操作**（agent 无法代做） |
| 执行中出现**超出预期的错误**（失败模式与 `PITFALLS`/`RUNBOOK` 已知项不符、设备不回退、无可用通道、反复重启） | **停止重试**，保留现场（日志/slot/镜像 hash），给用户可执行的检查/恢复步骤 |
| 凭据/账号/权限/隐私 | 属外部干预，直接上报用户（`STANDING.md`，全局 `~/.pi/agent/pi-hermes-memory/STANDING.md`，不在本仓库） |

- **「预期」的基准** = `PITFALLS` + `RUNBOOK` 的已知失败模式；与此不符即升级到用户。
- **一次正反判断**：同一失败不反复试错；先诊断基础设施（限流/代理/网络）。
- **fastboot 拆单条**：该机对批量/连续命令容错差，命令逐条跑（技术事实，见 `PITFALLS` #3）。
- 用户自订底线已按 2026-10-06 指示放宽：**自主执行优先**；原「复杂刷写/GUI 由用户操作」不再是硬边界。

---

## 2. 设备安全纪律

- **不跨容量档复用 GPT 二进制**；每单元现 dump（`scripts/gpt-dump.sh`），手术读实际 GPT 参数。
- 动分区/刷写前：`fastboot fetch` 备份将覆盖分区 + GPT 双表 dump；**写后读回校验**（不看「传输完成」）。
- 默认只动 **b 槽 + LUN0 GPT**；`fastboot --set-active` 属写操作，按「先备份 GPT + 记当前 slot → 再执行」处理（不再绝对禁止）；恢复步骤见 `RUNBOOK-BRINGUP/README.md`。
- 覆盖 a 槽前确认真机对照取证已归档（2026-10-11 主体已采，指针 `TASKS/README.md §5` Q5）；回收 Android 专属分区需 G1 全绿 + EDL 备份在手。
- **零写盘优先** `fastboot boot`；严格区分 **`-ram` 纯 RAM 变体（无桌面/服务）** 与**持久变体（RAM 内核 + 磁盘根）**——功能/服务级测试必须用持久变体（`PITFALLS` #92/#93）。
- **封装脚本**：主机侧构建/打包脚本可跑；**不要用封装脚本代跑 fastboot/EDL**——该机对批量/连续命令容错差，命令一律拆单条（经验见 `PITFALLS` #3）。

---

## 3. 研发纪律

- **先查本地既有结论**：引导链（BL/AVB/降级/GPT/EDL）及反复出现的问题，先 `grep` 技能 `references/` + `archive/topics/` + `PITFALLS`；命中则本轮只做「确认或推翻」，差量重推（`PITFALLS` #87）。
- **判据在设备侧**：主机侧构建/编译/能进 BDS 一律只算「未上机验证」；**无设备证据不得写「已修复/已解决」**（`PITFALLS` §0 纪律 4）。间歇性故障**单次样本无效**（须同口径量化 + 单变量 + 长时窗）。
- **上机结论必须落 record**：一次设备实验 = `scripts/trial.sh` 一条机器可读记录（`reports/trials/`）；**无 record 不得写 verdict**；`--reset` 类型必填（`por`/`cold`/`warm`），复位敏感问题（如 Q28）禁暖复位样本。构建产物身份由打包前硬门 `scripts/assert-kernel-sane.sh` + `check-doctor §5e` 保证。
- **归因分层**：报「驱动/内核坏」前先分清 initramfs/rootfs 打包（C）与用户态配置（D）（`PITFALLS` #115）。
- **主线优先**（服务上游化）：厂商私有 compatible 先找主线等效驱动，只补 DT/config/固件命名；主线没有则分「架构性不可做 / 私有 / 可自研」，只立第三类。
- **上游化三问门**（写代码前）：① 有对应主线子系统 → 必须用其框架；② 有同类芯片驱动 → 复用/扩展而非新写；③ 硬件事实进 DT/数据表、软件策略才进 C。红线框架表、违例清单与下游隔离清单见 `reports/upstream-policy-20261013.md`。
- **一次正反判断**：同一方案/推理/建议只做一次正反判断，不重复论证。
- **失败先复盘**：长任务反复失败无进展时，先落盘复盘（操作史/根因/文件清单）再换方案。
- 不硬编码其他机器的 home 路径；用 `~` 与项目相对路径。

---

## 4. 文档与写入权限（文档 v2：文件夹＝角度）

- **结构**：唯一入口 `INDEX.md`（文件）；7 个**角度文件夹** `DEVICE/` `TASKS/` `RESOURCES/` `RUNBOOK-BRINGUP/` `PITFALLS/` `SESSIONS/` `HISTORY/`，
  每个内 `README.md`（策展 SSOT，唯一维护面）+ `sessions/`（**以会话为单位**的进度，命名 `YYYY-MM-DD-<主题>.md`）。
- **记录时的区分度**（取代旧的自检计数/死链检查）：写入时就靠 文件夹(角度) + 文件名(日期+主题) + pi 会话 id 区分；
  会话身份/检索用 **pi 原生项目会话**（`.pi/sessions/*.jsonl`，`session_search` / `/resume`），不手抄索引表。
- **单写者**：任何时刻一个文件只有一个写者。**各角度 `README.md` + `.githooks` + `versions/` = 父 agent 专属**；
  子 agent 只写被指派的 `sessions/` 新文件，一般不碰 README（被显式指派重建某角度文件夹时，该角度对本次派工单写者）。
- **并入流程**：`sessions/` 里的「★SSOT 待并入」由宿主择机并进同角度 `README.md`，随后移除该标记。
- `archive/` **追加为主**：允许为更正/回填做带日期的最小修订（不改写既有结论口径）；结论以角度 `README.md` 为准，archive 不得被引用为「当前结论」。
- 结论可反转：保留推翻记录（见 `ATTRIBUTION-AUDIT-2026-10-06.md` 的分层更正）。

---

## 5. 汇报与时间盒

- 汇报**先数字结论、后细节，一页内**；阶段性收官后先总结再推进。
- 长跑任务必须设**自动截止时间盒**（脚本内 `timeout -k <秒>`），并用 `ps`/`pgrep` 核实进程真的结束。
- 状态词只允许「未解 / 未证实 / 未上机」；失败与半成品必落盘。

---

## 6. 协作与并发

- 需要并发时走 `.pi/CONCURRENCY.md`（基线+fork、单写者、提交 trailer、vk registry、入口 `scripts/lane.sh`）。
- 子代理 = `fabric_exec`（pi-fabric）里的 `agents.run`/`agents.spawn` + `.pi/agents/<role>.md`（角色卡正文）+ `.pi/missions/<topic>.md`（任务背景），**无守护进程**；2026-10-12 起不再用 pi-subagents。
- **worker 自报成功不可信**：编排者必须独立重跑测试与全量回归。
- 并发上限 ≤3 个后台子 agent（已固化到全局 `fabric.json` 的 `agents.maxConcurrent: 3`；为限流/预算留余量，见全局 `AGENTS.md`）。
- 子代理的**行为标准一律以本文件为准**；`.pi/agents/*.md` 只写角色专属补充，不另行定义自主/授权边界。迁移后无插件自动加载角色卡，派工须把其正文显式拼进 `task`。
- **本项目子代理一律经 `custom-nexavlinks-com` 网关**（`https://www.nexavlinks.com`，模型 `deepseek-v4.1-flash`）：项目级 `.pi/fabric.json` 已把全部别名（worker/researcher/audit/…）指向该模型；改后需 `/reload` 生效。凭据只在全局 `auth.json`，不入库；网关地址/模型名属配置非密件。
