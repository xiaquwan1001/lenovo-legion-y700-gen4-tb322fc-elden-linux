# Lane C — 会话管理口径统一（只读取证）

> 范围：只读。工具 = read/grep/ls（本 lane **未跑 shell**，凡需 shell 的结论均标注「待父 agent 实测」并给出命令与预期输出）。
> 复核对象：`INDEX.md`、`RESOURCES/README.md`、`SESSIONS/`、7 个 `sessions/`、`.pi/*`、`scripts/gen-sessions.py`、`scripts/check-sessions.sh`、`scripts/check-doctor.sh`。

---

## 0. 结论（5 条，先看这里）

1. **`session_search` 已死**：全库 6 处主文档仍把它当会话检索入口（`INDEX.md:30/80/91`、`RESOURCES/README.md:356`、`RUNBOOK-BRINGUP/sessions/README.md:5`、`DEVICE/sessions/README.md:3`、`SESSIONS/README.md:8/29/324`、`scripts/gen-sessions.py:107/184/259`）。`pi-hermes-memory` **不在本机已装扩展清单**（`~/.pi/agent/settings.json` `packages` 全 10 项无它；`~/.pi/agent/npm/package.json` 依赖无它）⇒ 该工具**不存在**。
2. **`sess` 默认扫不到本项目会话（已实证）**：`~/.pi/agent/bin/sess:13` 默认 `~/.pi/agent/sessions`；而项目 `sessionDir=.pi/sessions`（`.pi/settings.json`）。实测：`~/.pi/agent/sessions/--home-xuqianhui-y700-elden--/` 只有 **9 个** jsonl（2026-09-29T13-29 → 2026-09-30T11-59），项目 `.pi/sessions/` 顶层有 **198 个**（至 2026-10-19T07-59）。**丢失 2026-09-30 12:13 之后的全部会话**。
3. **`sess` 还会串味**：同一关键词 `vk127` 在 `~/.pi/agent/sessions/--home-xuqianhui--/2026-10-19T03-44-17-188Z_*.jsonl` 命中（别的项目的会话里提到 elden）⇒ 不加 `PI_SESSION_DIR` 时是「漏 95% + 混入他人」。
4. **`rg .pi/sessions`（`INDEX.md:91` 写的那条命令）大概率空转**：`/.pi/sessions/` 在 `.gitignore:78` 被整目录忽略，ripgrep 对显式目录入参仍应用 ignore 规则 ⇒ 需 `rg -uuu`。**待实测**（命令见 §3.4）。
5. **`SESSIONS/` 冻结目录建议 KEEP**（零改动、零风险），只改三处措辞把「唯一权威/零风险」这类会误导的断言降级为「档案 + 校验基准」。理由见 §5。
6. 附带发现两处**数字互相矛盾**且都会误导 agent：`RESOURCES/README.md:257` 写 `.pi/sessions` = **108 M**，同文件 `:237`/`:349` 与 `reports/cloud-backup-manifest-20261016.md:67` 写 **390/391 M**；`SESSIONS/README.md:52` 写「主会话 jsonl **162**」、`:38` 写「顶层现 **168**」、磁盘实测 **198**。

---

## 1. 会话事实的载体对照表（5 类，不是 4 类）

| # | 载体 | 位置 | 权威范围 | 谁维护 | 可机读再生 | 纳管 |
|---|---|---|---|---|---|---|
| A | **pi 原生会话全文** | `.pi/sessions/*.jsonl`（顶层 198 个）+ `.pi/sessions/--home-xuqianhui1001-y700-elden--/`（9 个，09-29~09-30 迁移遗留） | **「当时到底发生了什么」的唯一一手记录** | pi 自动写，无人手改 | ❌ 不可再生 | ❌ ignore（`.gitignore:78`）；仅云备份一份（`RESOURCES/README.md:237`、`:349`） |
| A' | **子代理工件** | `.pi/sessions/subagent-artifacts/*_{input,output,transcript,meta}.*` | 子代理的输入/输出/转录 | Fabric 自动写 | ❌ | ❌ ignore（同上） |
| B | **pi 会话索引选择器** | `/resume`（`@earendil-works/pi-coding-agent/dist/main.js:330` `SessionManager.list(cwd, sessionDir)`） | 「按 cwd + 项目 sessionDir 列出本项目会话」 | pi 内置 | ✅ 运行时 | — |
| C | **`sess` CLI（替代 session_search）** | `~/.pi/agent/bin/sess`（`SESS_DIR` 环境变量可覆盖，`MAX_FILES=400`） | 关键词/正则全文快搜 | 用户本机脚本（全局，非本仓库） | ✅ | 不入库 |
| D | **角度会话进度** | `TASKS/sessions/`（15 个）、`PITFALLS/sessions/`（35 个，按编号）、`SESSIONS/sessions/`（171 个，冻结）、`DEVICE/sessions/`、`RESOURCES/sessions/`、`RUNBOOK-BRINGUP/sessions/`（**仅 README.md，空**） | 「这次会话新增了什么结论、待并入哪个 SSOT」 | 宿主/子 agent 写 | ❌ 手写，`gen-sessions.py` 只机械生成 SESSIONS/ 那 171 个 | ✅ track |
| E | **会话快照索引** | `SESSIONS/README.md`（§1 统计 / §2 内核时间线 / §3 171 行索引）+ `SESSIONS/COMPLETED-FEATURES.md` | 2026-10-14 冻结的**一次性快照**（不含此后会话） | 冻结；`COMPLETED-FEATURES.md:6` 称「手工增补」 | ✅ `scripts/gen-sessions.py` 从 `git show d8ae437:RESOURCES.md` 再生；`scripts/check-sessions.sh` 逐字节校验 | ✅ track |
| F | **提交史** | `HISTORY/days/*.md`（17 个日档）+ `HISTORY/README.md` | 「哪个提交改了什么」 | `scripts/gen-history.sh` | ✅ `--check` 对账 `git rev-list --count HEAD` | ✅ track |

**加一条已死但仍在磁盘上的第 6 类**：`~/.pi/agent/pi-hermes-memory/{sessions.db, orphan-sessions.md}`（hermes 遗留，插件已卸）→ **任何 agent 不应再引用**；目前无文档引用 ✅，但 `SESSIONS/README.md:29` 的括注「hermes 记忆检索」会让人去翻它。

---

## 2. 矛盾 / 误导清单（原文 → 改法）

> 记法：`文件:行` + 原文片段 → 建议替代文本。**全部为最小改动（只改括号内的引号部分）。**

### 2.1 `session_search` 已不存在（6 处主文档 + 生成器 3 处）

| 位置 | 原文片段 | 改为 |
|---|---|---|
| `INDEX.md:30` | `` `session_search` / `/resume` `` | `` `/resume`（本项目 `sessionDir`）；CLI 全文搜 `PI_SESSION_DIR=.pi/sessions sess <kw>` `` |
| `INDEX.md:80` | `会话身份与全文检索 = pi 原生会话（`session_search` / `/resume`）` | `会话身份与全文检索 = pi 原生会话（`/resume`、`PI_SESSION_DIR=.pi/sessions sess <kw>`）` |
| `INDEX.md:91` | `` `/resume`）/ `session_search` + `rg .pi/sessions` `` | `` `/resume`）/ `PI_SESSION_DIR=.pi/sessions sess <kw>` / `rg -uuu .pi/sessions` ``（`-uuu` 必需，见 §3.4） |
| `RESOURCES/README.md:356` | `用 `session_search` / `/resume`。` | `用 `/resume` / `PI_SESSION_DIR=.pi/sessions sess <kw>`（`sess` 默认扫全局目录，扫不到本项目，见 §3）。` |
| `RUNBOOK-BRINGUP/sessions/README.md:5` | `（`.pi/sessions/*.jsonl`，`session_search` / `/resume`）` | `（`.pi/sessions/*.jsonl`，`/resume` / `PI_SESSION_DIR=.pi/sessions sess`）` |
| `DEVICE/sessions/README.md:3` | `（.pi/sessions/*.jsonl；session_search / /resume）` | `（.pi/sessions/*.jsonl；/resume 或 PI_SESSION_DIR=.pi/sessions sess）` |
| `.pi/README.md:19` | `（检索仍用 `session_search`/`/resume`）` | `（检索用 `/resume` 或 `PI_SESSION_DIR=.pi/sessions sess`）` |
| `.pi/AGENT-OPS.md:66` | ``（`.pi/sessions/*.jsonl`，`session_search` / `/resume`）`` | ``（`.pi/sessions/*.jsonl`，`/resume` / `PI_SESSION_DIR=.pi/sessions sess`）`` |
| `SESSIONS/README.md:8` | `（`session_search` / `/resume`）` | `（`/resume` / `PI_SESSION_DIR=.pi/sessions sess`）` |
| `SESSIONS/README.md:29` | `` 检索 = **`session_search`**（hermes 记忆检索）或 pi 会话选择器 **`/resume`** `` | `检索 = pi 会话选择器 **`/resume`** 或 **`PI_SESSION_DIR=.pi/sessions sess <kw>`**（hermes 插件已卸，`session_search` 不存在）` |
| `SESSIONS/README.md:324` | `（`session_search` / `/resume`）` | 同 §2.1 首行改法 |
| `SESSIONS/COMPLETED-FEATURES.md:32` | `检索以 pi 原生 `session_search` 为准` | `检索以 pi 原生 `/resume`（或 `PI_SESSION_DIR=.pi/sessions sess`）为准` |
| `scripts/gen-sessions.py:107/184/259` | 同上三处模板 | 同步替换（**改生成器再重跑**，否则 `--check` 与 `check-sessions.sh` 只比对 §1/§2/§3 块，模板文字不进比对，安全；但 `SESSIONS/sessions/*.md` 171 个文件头含该串，需重生成才一致） |

> ⚠ 若改 `gen-sessions.py` 模板必须重跑生成器（`gen-sessions.py:103` `os.remove` 全删再写），diff 会触及 171 个文件；`check-sessions.sh` 只校验 §1/§2/§3 与抽检字段，不校验第 3 行模板 ⇒ 重跑后应仍 ALL PASS。**建议单独一次提交**，避免与其它改动混在一起。

### 2.2 「唯一权威 / 零风险 / 已冻结」口径互斥

| 位置 | 原文片段 | 问题 | 改为 |
|---|---|---|---|
| `SESSIONS/README.md:8` | `这是**唯一权威**`（指 `.pi/sessions/*.jsonl`） | 与 `:324` 的「本目录只存快照索引」并列时容易被读成「SESSIONS/ 也是权威之一」 | `这是**唯一权威**（本目录只是 2026-10-14 的快照，不是权威）` |
| `SESSIONS/README.md:13` | `**保留 = 零风险**，退役反而要同步改角度清单与交叉链接` | 「零风险」是未量化的断言；实测有 4 处硬耦合（`HISTORY/days/*.md` ×17、`HISTORY/README.md:5`、`check-doctor.sh:228/262/266`、`check-sessions.sh`） | `**保留 = 改动面最小**（仅 4 类硬耦合：`HISTORY/days/*` ×17、`HISTORY/README.md:5`、`check-doctor.sh` §7/§8 清单、`scripts/check-sessions.sh`）；退役需同步上述 4 类` |
| `INDEX.md:80` | `⚠ **已冻结的历史快照（2026-10-15 起不再增补）**` vs `SESSIONS/COMPLETED-FEATURES.md:6` `新增完成项时手工增补`（且 `:17` 已手工增补 C10） | 「冻结」与「手工增补」并存 ⇒ 读者不知道能不能往里写 | `SESSIONS/README.md` §3 索引表冻结（生成物）；`COMPLETED-FEATURES.md` 为**独立手工账**，随完成项增补，不属冻结范围` |
| `.pi/AGENT-OPS.md:63` + `INDEX.md:4` | `7 个**角度文件夹** … 各自 `README.md`（策展 SSOT）+ `sessions/`（会话进度）` | 实测 `DEVICE/sessions/`、`RESOURCES/sessions/`、`RUNBOOK-BRINGUP/sessions/` **只有 README.md、0 个会话文件**；`SESSIONS/sessions/` 是冻结快照而非「进度」 ⇒ 7×2 的结构陈述与磁盘不符 | `7 个角度文件夹`（保留）；`sessions/` 一句补充：**只有 TASKS/PITFALLS 在用（会话进度），SESSIONS 为冻结快照，DEVICE/RESOURCES/RUNBOOK 目前为空壳（只放 README 声明）** |

### 2.3 数字冲突（会直接误导 agent 判断「能不能删」）

| 位置 | 原文 | 实测/冲突源 | 改为 |
|---|---|---|---|
| `RESOURCES/README.md:257` | `` `.pi/sessions/`（jsonl 会话轨迹，含会话子目录副本） | ~108 M `` | 同文件 `:237` 写 `390 M`、`:349` 写 `311 文件 / 391 M`；`reports/cloud-backup-manifest-20261016.md:67` 写 `390 M / 595 文件` | 删体积数字，只留 `体积/文件数见 §3.3 云备份台账` |
| `SESSIONS/README.md:52` | `磁盘**主会话** jsonl **162**` / `:38` `磁盘顶层现 **168** 个 jsonl` | 本次 `ls .pi/sessions` 顶层 = **198** 个 jsonl（末个 `2026-10-19T07-59-47`） | 两处都改成 `磁盘 jsonl 数**不写死**（`ls .pi/sessions/*.jsonl | wc -l` 为准）` |
| `RESOURCES/README.md:311`（H1 行） | `归档非活跃会话（保留最近若干）` / `删除待任务 #2 完成 + 用户确认` | 与 `INDEX.md:13`「不可再生/代价高」、`cloud-backup:67`「丢了没有第二份」互斥 | 改 `**唯一全文记录，不得删除**；只允许整包云备份（见 §3.3 T3-sessions）` |

### 2.4 `rg .pi/sessions` 空转

- `INDEX.md:91`：`` `rg .pi/sessions` `` → `.gitignore:78` 是 `/.pi/sessions/`。ripgrep 对**目录**入参仍应用 `.gitignore` ⇒ **预期 0 命中**（待实测，见 §3.4）。
- 改为 `rg -uuu .pi/sessions`（或直接 `sess`）。

---

## 3. `sess` 能否扫到本项目会话？——实测（文件系统级）+ 待 shell 复核

### 3.1 判据来源（代码）

- `~/.pi/agent/bin/sess:13`：`SESS_DIR = os.path.expanduser(os.environ.get("PI_SESSION_DIR", "~/.pi/agent/sessions"))` —— **默认全局**。
- `~/.pi/agent/bin/sess:14`：`MAX_FILES = int(os.environ.get("SESS_MAX_FILES", "400"))`，`:31` 按 mtime 倒序取前 400。
- 项目侧：`.pi/settings.json` = `{"sessionDir": ".pi/sessions"}` ⇒ 本项目会话写进 `~/y700-elden/.pi/sessions/`，**不进** `~/.pi/agent/sessions/`。

### 3.2 已完成的实测（`ls` / `grep`，无需 shell）

| 事实 | 证据 |
|---|---|
| `~/.pi/agent/sessions/--home-xuqianhui-y700-elden--/` 恰好 **9 个** jsonl，最后一个是 `2026-09-30T11-59-21-222Z_01a0f22e-…jsonl` | `ls` 该目录（9 行，无更多） |
| 项目 `.pi/sessions/` 顶层 **198 个** jsonl，最早 `2026-09-30T12-13-51-559Z`、最晚 `2026-10-19T07-59-47-714Z` | `ls .pi/sessions` 全量（无 `…` 截断） |
| 项目 09-29~09-30 的 9 个会话**两份都在**（全局子目录 + `.pi/sessions/--home-xuqianhui1001-y700-elden--/`，文件名逐字相同） | 两处 `ls` 输出一致 |
| 关键词 `waydroid-camera-64bit` 在 `.pi/sessions/2026-10-18T15-21-10-903Z_01a14f9a-…jsonl` 命中；在 `~/.pi/agent/sessions/` 全树 **0 命中** | `grep`（两处） |
| 关键词 `vk127` 在 `~/.pi/agent/sessions/--home-xuqianhui--/2026-10-19T03-44-17-188Z_…jsonl` 命中（**别的项目**的会话里读到 elden 文件） | `grep` |

⇒ **结论：`sess` 默认只能看到本项目 2026-09-30 11:59 之前的 9 个会话（约 4%），且会返回其它项目的会话（串味）。**

### 3.3 待父 agent 跑的确认命令（预期输出已给出）

```bash
cd ~/y700-elden
find ~/.pi/agent/sessions -name '*.jsonl' | wc -l          # 预期 400+  ⇒ 触发 MAX_FILES=400 截断
find ~/.pi/agent/sessions/--home-xuqianhui-y700-elden-- -name '*.jsonl' | wc -l   # 预期 9
ls .pi/sessions/*.jsonl | wc -l                            # 预期 198

sess -n 3 "waydroid-camera-64bit"                          # 预期「未命中 ... (扫了 400 个会话文件)」
PI_SESSION_DIR=.pi/sessions sess -n 3 "waydroid-camera-64bit"   # 预期命中 2026-10-18T15-21 那条
SESS_MAX_FILES=2000 PI_SESSION_DIR=.pi/sessions sess -n 3 "vk127"  # 预期命中 2026-10-18T13-11 那条
```

### 3.4 待父 agent 跑的确认命令（`rg` ignore）

```bash
cd ~/y700-elden
rg -c "waydroid-camera-64bit" .pi/sessions     # 预期 0（被 .gitignore:78 拦掉）
rg -uuu -c "waydroid-camera-64bit" .pi/sessions # 预期 ≥1
```

### 3.5 最小修法（推荐 B，3 行脚本；A 为零代码兜底）

**B（推荐）：加 wrapper `scripts/sess.sh`，文档统一指它。**

```bash
#!/bin/sh
# scripts/sess.sh — 本项目会话检索。sess 默认扫 ~/.pi/agent/sessions，扫不到本项目（sessionDir=.pi/sessions）。
cd "$(dirname "$0")/.." || exit 1
exec env PI_SESSION_DIR="$PWD/.pi/sessions" SESS_MAX_FILES="${SESS_MAX_FILES:-2000}" sess "$@"
```

- 落地后文档里的命令统一写 `scripts/sess.sh <kw>`（替换 §2.1 表中所有 `PI_SESSION_DIR=.pi/sessions sess …`）。
- 必须同时抬 `SESS_MAX_FILES`：`.pi/sessions/subagent-artifacts/*_transcript.jsonl` 也在 `os.walk` 范围内，默认 400 容易被子代理转录挤满。
- 注意：subagent 转录会被扫进来，属于噪声；命中里 `subagent-artifacts/` 的可忽略（不是会话本体）。

**A（零代码兜底）**：文档只写 `PI_SESSION_DIR=.pi/sessions sess <kw>`。缺点：漏写变量就静默错（而且错得「像没这段历史」，最危险）。

**C（不推荐）**：改 `~/.pi/agent/bin/sess` 默认值去读 `settings.json` 的 `sessionDir`。会改变全局行为（`mem` 同族脚本/别的项目都受影响），跨项目耦合太强。

---

## 4. 「一次会话结束到底写什么、写到哪」——唯一规则（8 行）

1. **只写 1 个新文件**：`<角度>/sessions/YYYY-MM-DD-<主题>.md`；同一会话多主题加 `-2`。**不新建目录、不改任何已存在的 sessions 文件、不建索引表**。
2. 角度只有 4 个可用：`TASKS/`（任务/进度/未解）、`PITFALLS/`（踩坑）、`DEVICE/`（单元/镜像状态）、`RESOURCES/`（资产/资源）。
   `SESSIONS/` 冻结**不写**；`RUNBOOK-BRINGUP/` 目前空壳，需要时再启用。一次会话跨角度时，写**主角度**一个文件，其余角度补一行指针。
3. 文件头只需 6 个字段（`日期 / pi 会话 id / 主题 / 结论 / 证据指针 / ★SSOT 待并入`），格式抄 `RUNBOOK-BRINGUP/sessions/README.md` 的模板。
4. **状态数字只改一处**：`TASKS/README.md` §0（总览表）/ §5（Q 行）。**其它任何地方都不写状态数字**，只写指针。
5. 会话全文**不复述、不复制**——它就躺在 `.pi/sessions/*.jsonl`，文件里只放「结论 + 指向证据的路径/命令」。
6. 收尾判据不变（`.pi/AGENT-OPS.md` §5）：产物落盘 + SSOT 同步 + `check-doctor.sh` FAIL=0 + `git commit`。

**为什么满足「增量记录、不反复删改」**：
- 新文件 ⇒ 每次会话 diff 只有 `+`，没有 `-`（除 TASKS §0/§5 的指定行）；
- 旧文件永不回改 ⇒ 无写冲突，多 lane 并行安全（符合 `.pi/AGENT-OPS.md` §4「单写者」）；
- 状态唯一出口 = TASKS §0/§5 ⇒ 不会出现同一数字在三处漂移（现状 `162/168/198` 就是这么来的）；
- 「★SSOT 待并入」是唯一的延后合并通道，合并完成后**在新文件里划掉该标记**（仍属追加语义，不改历史结论）。

---

## 5. `SESSIONS/` 冻结目录：三方案评估（按风险排序，推荐 ①）

### ① KEEP（零改动）——**推荐**

- 改动：**0 个文件**。可选做 3 处措辞微调（`SESSIONS/README.md:8` / `:13`、`INDEX.md:80` 与 `COMPLETED-FEATURES.md:6` 的冻结口径对齐），共 4 行。
- 风险：**最低**。它已是 `check-doctor.sh` §9（`:354-369`）的**硬 FAIL 判据来源**，动它会连带动自检门。
- 代价：784 K 磁盘 + 一个「已冻结」标签（`RESOURCES/README.md:264` 已注明）。
- 唯一真问题不是目录本身，而是**文档把它说成「唯一权威之一」和「零风险」**（§2.2 已给替代文本）。**KEEP + 改措辞即可消除 90% 误导。**

### ② 降级为「档案层」（从 7 个角度里移除，目录原地保留）

要改的文件（精确到行）：

| 文件 | 行 | 改法 |
|---|---|---|
| `INDEX.md` | 4 | `**7 个角度文件夹**（… `SESSIONS/` `HISTORY/`）` → `**6 个角度文件夹**（… `HISTORY/`）+ 档案层 `SESSIONS/`（冻结快照，见 §档案例外）` |
| `INDEX.md` | 80 | 从「角度文件夹」表**移出**该行，落到 §2「证据层（`archive/`）」段落旁，标题写「冻结档案（非角度）」 |
| `.pi/AGENT-OPS.md` | 63 | 同 `INDEX.md:4` 的 6+1 表述 |
| `RESOURCES/README.md` | 264 | `\| `SESSIONS/README.md` + `SESSIONS/sessions/` \| …` 行加前缀 `【档案层】` |
| `HISTORY/README.md` | 5 | `见 **`../SESSIONS/`**` 后加 `（冻结档案层）` |
| `scripts/check-doctor.sh` | 261-266 | `ANGLES` / `INDEXED_ANGLES` **保留**（目录仍在，检查照跑，零改动） |

- 风险：**中**。`INDEX.md:4` 与 `.pi/AGENT-OPS.md:63` 是「结构 SSOT」，改错会让 check-doctor §7（`ENTRY` 清单，`check-doctor.sh:224-228`）与之不一致；另外 `INDEX.md:80` 那行同时承载「新会话不进此目录」的禁令，搬迁时容易丢。
- 收益：消除「7 个角度里有 1 个是死的」的结构噪声。

### ③ 迁入 `archive/`（`archive/2026-10-14-sessions-snapshot/`）

要改的文件（全量，漏一个就断链）：

| 文件 | 行 | 原因 |
|---|---|---|
| `scripts/gen-sessions.py` | 16-17（`OUT`/`SDIR`） | 生成目标路径 |
| `scripts/check-sessions.sh` | 29/30/43/44（`SESSIONS/README.md`、`SESSIONS/sessions/*.md`、`ls SESSIONS/sessions`） | 校验路径 |
| `scripts/check-doctor.sh` | 228（`ENTRY` 含 `SESSIONS/README.md`）、262（`ANGLES`）、266（`INDEXED_ANGLES`）、360-368（§9 调 `check-sessions.sh`） | 自检门 |
| `HISTORY/days/*.md` | 各文件 **第 4 行**（`会话视角见 `../../SESSIONS/``），**17 个文件** | 反向链接 |
| `scripts/gen-history.sh` | 34 | 上述第 4 行的生成模板（不改则下次重生成又指回旧路径） |
| `HISTORY/README.md` | 5 | 交叉引用 |
| `INDEX.md` | 80、91 | 角度表 + 机器可查段 |
| `.pi/AGENT-OPS.md` | 63（角度清单）+ 50（§9 描述） | 结构 + 门描述 |
| `.pi/README.md` | 19 | `.pi/sessions` 行的「快照见 ../SESSIONS/」 |
| `RESOURCES/README.md` | 264、357 | 资产台账 + §4 会话检索 |
| `SESSIONS/README.md` | 12-14、300 | 自述 + 生成命令 |
| `SESSIONS/COMPLETED-FEATURES.md` | 30 | `../PITFALLS` 相对路径不变，但 `SESSIONS/README.md` 指代要改 |

- 风险：**最高**。12 个文件 + 17 个生成日档，且必须「先改生成器再重跑」否则 `check-doctor` §9 立刻 FAIL、`.githooks/pre-commit`（`AGENT-OPS.md:50`）拦提交。
- 收益：几乎为零（只省 784 K，且档案层本来也该留）。

**推荐 ① KEEP + 4 行措辞**：改 4 行、零结构变更、自检门不动。若将来要瘦身，优先做 ② （只动 6 处文档、不碰生成器与自检门）。

---

## 6. 落地清单（按顺序，父 agent 可直接执行）

1. **（阻断级）** 全库替换 `session_search` 口径 → `/resume` / `sess`：`INDEX.md:30,80,91`、`RESOURCES/README.md:356`、`SESSIONS/README.md:8,29,324`、`SESSIONS/COMPLETED-FEATURES.md:32`、`DEVICE/sessions/README.md:3`、`RUNBOOK-BRINGUP/sessions/README.md:5`、`.pi/README.md:19`、`.pi/AGENT-OPS.md:66`、`scripts/gen-sessions.py:107,184,259`。
2. **（阻断级）** 新增 `scripts/sess.sh`（§3.5），并把「会话检索」命令统一到它。
3. 修 `.pi/sessions` 体积/数量矛盾：`RESOURCES/README.md:257`（删 108 M）、`:311`（H1 改「不得删除」）、`SESSIONS/README.md:38,52`（不写死 jsonl 数）。
4. 修冻结口径互斥：`INDEX.md:80` ↔ `SESSIONS/COMPLETED-FEATURES.md:6`；`SESSIONS/README.md:8,13` 措辞。
5. 补结构事实：`INDEX.md:4` / `.pi/AGENT-OPS.md:63` 注明「`DEVICE/`/`RESOURCES/`/`RUNBOOK-BRINGUP/` 的 sessions/ 目前为空壳，`SESSIONS/` 为冻结快照」。
6. 若已按 §3.3/§3.4 实测确认，把 §3 的实测输出替换本文件对应「待实测」标注（**只追加一节「实测记录」**，不改上文结论）。
