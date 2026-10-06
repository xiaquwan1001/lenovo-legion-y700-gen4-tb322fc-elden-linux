# 语义漂移审查（2026-10-06）— 规则的来源、升格与矛盾

> 证据层 · 只增不改。**结论权威仍在领域层**（AGENTS/INDEX/TASKS/PITFALLS）。
> 动因：用户提出「一开始记录用户偏好自己执行，后来变成项目必须用户亲自执行，中间还有些是 agent 可执行简单命令」，
> 要求排查同类「偏好→规则升格」「来源不明」「同一动作前后翻转」的现象。
> 方法：git 逐版溯源（`git log -p -- AGENTS.md`）+ 活跃文档交叉比对 + 与全局 STANDING/AGENTS、`.pi/agents/*.md`、`flashing-bundle/` 快照对照。
> 注意：`scripts/check-doctor.sh` 只覆盖计数/死链/过期文件名/百分比/vk 账，**不覆盖本节全部问题**。

---

## 0. 结论总览

| # | 类型 | 现象 | 严重度 |
|---|---|---|---|
| **D1** | 偏好→硬规则升格 + 范围扩张 + 理由替换 | 「用户**偏好**亲自执行 fastboot/EDL（避开工具断联）」→ 「项目**必须**用户亲自执行所有 fastboot/EDL」；例外条款「简单可观测脚本可直接执行」来源不明 | ★★★ |
| **D2** | 同一动作前后翻转 + 主语不清 | `fastboot --set-active` 10-05 还是「进 fastboot 后先执行」，10-06 变「未授权写操作」；RUNBOOK/bootslot-b/PITFALLS 仍在推荐 | ★★★ |
| **D3** | 规则被压缩时禁令降级为理由 | 5f1dcf0「**不要**用封装脚本跑 fastboot（to-fastboot.sh/cycle.sh）」→ 5ea99d6 变成括号里的解释；而 INDEX 仍推荐这些脚本 | ★★ |
| **D4** | 术语漂移 | 「领域层 **5** 份文档」vs INDEX §2「领域层（**4** 份）+ 经验层（1 份）」 | ★ |
| **D5** | 状态自相矛盾（同文件内） | INDEX §3「kexec 热重载**不可用**」 vs INDEX §4 快捷命令仍列 `iterate.sh kernel --kexec` | ★★ |
| **D6** | 同一数字多口径 | 会话数：INDEX「94」、RESOURCES §3 台账「93」、RESOURCES §4「94」、磁盘实况 **99** | ★ |
| **D7** | 陈旧快照未随主干更新 | TASKS §0 运维/资产写「内核 **vk50**」（当前 vk61）；INDEX §4 快捷命令仍写 `vk40` 镜像名 | ★ |

**已处理、可作为正面样例的既有反转**（不再是问题，列出以免重复调查）：
vk53/vk54 启动失败归因三次反转（DTS → initramfs+用户态 → `&i2c0`），
沿革完整保留在 `ATTRIBUTION-AUDIT-2026-10-06.md` §4/§5、`SESSION-AUDIT-2026-10-06.md` §6/§7、`PITFALLS` #108。

---

## 1. D1 — 「用户亲自执行」的完整来源链（用户举的例子）

### 1.1 逐版溯源

| 时间/提交 | 载体 | 原文 | 性质 |
|---|---|---|---|
| ~2026-10-02（迁移包快照 `flashing-bundle/profile/memory/USER.md`） | 用户记忆 | 「fastboot/EDL 类断联场景：用户**偏好**亲自执行命令、助手只做分析（**避开工具断联**）」；「复杂刷写/GUI 工具（如 LTBox）：用户亲自操作，助手准备资产并给精确步骤」 | **偏好**，带**原因**，范围=**断联场景/复杂刷写** |
| 用户自订全局规则 `~/.pi/agent/pi-hermes-memory/STANDING.md` 第 5 条 & `~/.pi/agent/AGENTS.md` | 全局 | 「动手前先确认不破坏当前可用系统；**复杂刷写/GUI 工具**有用户亲自操作，助手准备资产并给精确步骤」 | **偏好**，范围=复杂刷写/GUI |
| 2026-10-03 `76b2c0f`（AGENTS.md 首次入库） | 项目 | 「用户操作设备；助手准备资产并给出精确步骤」 | 升格为项目条目，范围=**整个设备** |
| 2026-10-05 `5f1dcf0` | 项目 | 「**设备操作**：fastboot/EDL 类命令由用户亲自执行，助手只做分析并给可直接手敲的**单条**命令；**不要**用封装脚本跑 fastboot（`to-fastboot.sh`/`cycle.sh` 等：命令有限、深层嵌套难预测、故障率高），脚本只用于主机侧构建/打包。每次进 fastboot 后、任何操作前先 `fastboot --set-active=a`。**简单、可观测的脚本可直接执行，不必先要授权**」 | 升格为**硬规则**；范围扩到**全部 fastboot/EDL**；**理由换成「封装脚本故障率高」**（断联原因丢失）；新增**无来源例外**与**授权**概念 |
| 2026-10-06 `5ea99d6` | 项目 | 「fastboot/EDL 命令由**用户亲自执行**，助手只给…单条命令（封装脚本跑 fastboot 命令有限、故障率高）；脚本只用于主机侧构建/打包。简单、可观测的脚本可直接执行」 | 压缩：**「不要用」降级为括号理由**、「不必先要授权」被删 |

### 1.2 当前并列的三套口径（互相冲突）

1. **项目 AGENTS.md**：fastboot/EDL 由用户手敲单条；脚本只用于主机侧构建/打包；「简单、可观测的脚本可直接执行」。
2. **INDEX §4 快捷命令**：直接推荐 `./cycle.sh --soft`、`scripts/iterate.sh kernel --flash …`（前者内部跑 `fastboot devices`/`fastboot flash`，后者走设备侧写入）。
3. **`.pi/agents/*.md` 任务卡**（真正驱动子代理行为）：
   - `camera.md`/`audio-graphopen.md`/`thermal.md`：「写操作走自锁脚本或 `scripts/device-lock.sh`；迭代用 `scripts/iterate.sh`」；
   - `dt-ui.md`：设备改动经 `ssh root@192.168.7.1` 执行、产物同步回 lane。
   ⇒ 子代理被授权做设备侧写操作，与 AGENTS 的「用户亲自执行」正相反。

### 1.3 来源不清的点

- **「简单、可观测的脚本可直接执行」**：首次出现在 `5f1dcf0`，无日期、无判据、无例子；「简单/可观测」未定义。
  它正是子代理卡能跑 `iterate.sh` 的漏洞来源。
- **「属性未授权写操作」**（`fastboot --set-active`）：授权对象是谁（agent / 项目 / 用户自跑）未界定；见 D2。
- 升格时**丢掉了原始理由（工具断联）**，改用「命令有限、故障率高」；两条理由对应的边界不同（断联→只避开易断的 fastboot/EDL；故障率→所有 fastboot）。

### 1.4 建议处置（待用户拍板，不在本审计内执行）

- 决定规则**主语**：是「agent 不代跑 fastboot/EDL」还是「项目所有 fastboot/EDL 都只由用户跑」。
- 给例外条款**加判据与例子**（或删除），否则 `.pi/agents/*.md` 与 INDEX 需同步改写。
- 把原始理由（断联）写回，避免下次再被「故障率」替换。

---

## 2. D2 — `--set-active` 的翻转与主语漂移

| 载体 | 现行表述 |
|---|---|
| `AGENTS.md` §规则·设备与刷写 | 「默认只动 b 槽 + LUN0 GPT；**不改 active slot**（`fastboot --set-active` 属未授权写操作）」 |
| `PITFALLS` #1（活跃） | 「进不去 Android 第一步 = **切另一个槽试试**」「仅 `fastboot --set-active=a` + `fastboot reboot` 就完好进系统」 |
| `PITFALLS` #40 | 「回 Android 两步走：① 先 `fastboot --set-active=<另一槽>`」 |
| `RUNBOOK-BRINGUP.md` 234/238/250/334/336/405 | 刷 b 槽/回退/回 Android 的步骤里都含 `fastboot --set-active=a|b` |
| `bootslot-b/README.md` 50/54/62/64/75/85 | T1/T2/回退/双系统切换都用 `--set-active` |

**翻转记录**：`5f1dcf0`（10-05）新增「每次进 fastboot 后、任何操作前先 `fastboot --set-active=a`」→ `c1c6122`（10-06）删除并改为「不要改 active slot」。

**双重漂移**：
1. **动作漂移**：从「先执行的安全步骤」翻成「禁止的未授权写操作」。
2. **意图漂移**：`PITFALLS` #280 自述「本意是不动在用的 b 槽」；但 AGENTS 现文写成对 `fastboot --set-active` 的**绝对**禁止，丢失了「保护 b 槽」这一原始意图。

**未落的同步**：PITFALLS #1/#40、RUNBOOK、bootslot-b 均未改口径，仍在教用户执行被 AGENTS 禁止的动作（若这些只对用户生效，需显式写明主语）。

---

## 3. D3 — 禁令降级为理由

- `5f1dcf0`：`不要用封装脚本跑 fastboot（to-fastboot.sh/cycle.sh 等：命令有限、深层嵌套难预测、故障率高）`。
- `5ea99d6`：`（封装脚本跑 fastboot 命令有限、故障率高）`——去掉「不要用」，变成理由从句。
- 但同库 `INDEX §4` 仍把这些脚本列为快捷入口；`scripts/iterate.sh` 默认方法就是 `--kexec`，`--boot/--flash` 会拉起 `to-fastboot.sh`。
- 后果：新会话只读 AGENTS 会以为脚本可用，只读 INDEX 会以为被推荐。属「裁切项目级规则」时的副作用（`5ea99d6` 提交信息自列保留项，但未核对 INDEX/agents 引用面）。

---

## 4. D4 — 「领域层 5 份」vs INDEX「4+1 份」

- 用「领域层 5 份」的：`AGENTS.md` §协作、`.pi/CONCURRENCY.md` §2.1、`.pi/agents/bootchain.md` §纪律、`.pi/agents/dt-ui.md` §纪律。
- `INDEX.md` §2 明确：**领域层（4 份，唯一维护面）** = DEVICE/TASKS/RESOURCES/RUNBOOK-BRINGUP；**经验层（1 份）** = PITFALLS。
- 漂移点：把「领域层 4 + 经验层 1」合并称「领域层 5」，或沿用拆分前的旧口径。单写者范围表述不一致（PITFALLS 是否父专属？）。

---

## 5. D5 — kexec 状态同文件自相矛盾

- `INDEX.md` §3：「U2 实跑 vk47clean（b 槽持久直启；**kexec 热重载不可用**，见 TASKS §4）」。
- `INDEX.md` §4 快捷命令：「`scripts/iterate.sh kernel --kexec VERSION=vkNN   # 环2：全量重编 + kexec 热重载（无 fastboot/无按钮）」。
- `TASKS.md` §4：「迭代通道：`fastboot boot`（零写盘）/ `--flash`；**kexec 快环已死**」。
- `PITFALLS` #5 备注了 file-based kexec 的可收窄结论，但设备侧分支点未定位（`KEXEC-ONDEVICE-R2`）。
- ⇒ INDEX §4 该行是过时快照，应改为「kexec 取证未闭环，暂用 `--boot/--flash`」。

---

## 6. D6 — 会话计数多口径

| 位置 | 数字 |
|---|---|
| `INDEX.md` §2/§5 | 94 |
| `RESOURCES.md` §3 台账 | 93 |
| `RESOURCES.md` §4 统计表 | 磁盘 jsonl **94** / 索引 **94** 行 |
| `scripts/check-doctor.sh` 实算（2026-10-06） | jsonl **99**，索引 grep **94** |
| `archive/topics/SESSION-AUDIT-2026-10-06.md` §0 | 94 文件 / 86 唯一 ID / 索引 93 行 |

同一数字在 3 处人工维护，且磁盘实况（99）慢于索引，check-doctor 只给 WARN。

---

## 7. D7 — 陈旧快照

- `TASKS.md` §0 运维/资产：「内核 **vk50** …」——当前构建为 `vk61`。
- `INDEX.md` §4 快捷命令：`fastboot boot out/boot-elden-vk40-ram.img` / `out/boot-elden-vk40.img`——当前 boot_b 形态 = `vk61`/`vk47clean`。
- 这类「示例仍写旧版本号」不触发 check-doctor（它只查百分比等式）。

---

## 8. 可机读化的候选（供 check-doctor 后续扩展）

1. **禁令词一致性**：AGENTS/INDEX 中出现 `cycle.sh`/`iterate.sh`/`to-fastboot.sh` 时，必须与 AGENTS 的脚本政策同段无冲突。
2. **术语白名单**：全文只允许「领域层 4 份 + 经验层 1 份」；禁止「领域层 5 份」（或反向统一）。
3. **状态词冲突**：同一术语（kexec、NFC、相机 App 实测）在 INDEX/TASKS 的状态灯不得相反。
4. **数字 SSOT**：会话数只在 RESOURCES §4 维护，INDEX 只引用不复述。

---

## 9. 处置记录（2026-10-06 同日落地）

按用户「简化入口」要求重整，漂移项对应处置如下（提交见 git log 同日 docs 提交）：

| # | 处置 |
|---|---|
| D1 | 新增 **`.pi/AGENT-OPS.md`**：单一定义自主执行分级（A 自主 / B 用户手敲 / C 请求物理干预）与授权升级；保留用户自订底线（复杂刷写/GUI 由用户操作）；原始理由「工具断联」回写。 |
| D2 | AGENT-OPS §2 明确**主语**：`--set-active` 是用户在设备恢复时的手动动作，agent 不改；PITFALLS #1 加同口径注。 |
| D3 | AGENT-OPS §2 + PITFALLS #3 明确「封装脚本代跑 fastboot＝经验禁忌（非授权规则）」；`.pi/agents/*.md` 的 `iterate.sh` 授权改为指向 AGENT-OPS。 |
| D4 | 全文统一为「领域层 4 份 + 经验层 1 份」；check-doctor 新增术语检查。 |
| D5 | INDEX §4 去掉 `--kexec` 快捷命令（改注「kexec 快环未闭环」）。 |
| D6 | RESOURCES §4 补录 6 行，数字改为 100/100/92；INDEX 去掉复述；RESOURCES §3 同步。 |
| D7 | TASKS §0 内核 vk50→vk61；INDEX §4 示例镜像 vk40→`boot_b-clean.img`。 |

**新入口结构**：项目描述=`AGENTS.md`；agent 行为/授权=`.pi/AGENT-OPS.md`；开发经验=`PITFALLS.md`；并发细则=`.pi/CONCURRENCY.md`；状态与地图=`INDEX.md`。

---

## 10. 更正（2026-10-06 同日，用户放宽授权）★

§9 的 D1/D2 处置**作废**：用户定 **agent 默认自主执行**，不再按动作类别限定「由用户手敲」。

- 新口径：**自主优先 → 有写坏风险先备份再执行 → 只有出现超出预期的错误才要求用户检查**；
  仅**物理上必须人做**的动作（按键进 fastboot/EDL、插拔线缆/耳机、断电、EDL 短接）请求用户。
- `fastboot --set-active`、分区/槽/固件写入均不再禁止；改为要求「先 `fastboot fetch` + GPT 双表 dump + 记回退路径 → 再执行 → 写后读回校验」。
- 「已知失败模式」（PITFALLS/RUNBOOK）作为「预期」基准；不符即升级用户。
- 同步地点：`.pi/AGENT-OPS.md` §1/§2、`PITFALLS` #1/#3、`.pi/agents/*.md`、用户自订 `STANDING.md` 第 5 条。
- 权威：`.pi/AGENT-OPS.md` §1。
