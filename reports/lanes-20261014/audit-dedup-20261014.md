# 重复登记审计（去重前置） — y700-elden 文档仓库

> 生成：2026-10-14，只读审计（未改仓库任何文件）。工作目录 `/home/xuqianhui1001/y700-elden`。
> 方法（可复核）：`/tmp/dedup.py` + `/tmp/dedup3.py` 对下列 12 个主文件 + 7 个角度 `sessions|days/` 目录（共 **241 个 .md**）逐行/逐句归一化（去空白、去 markdown 标记、数字→`#`），按内容 hash 聚类，取「出现在 ≥2 文件」的组；再用 `grep -nE` 对语义重复逐条核对 file:line。行级聚类 89 组（多为生成物样板），句级 291 组，触及主文件 177 组。
> 范围：`INDEX.md TASKS/README.md DEVICE/README.md RESOURCES/README.md RUNBOOK-BRINGUP/README.md PITFALLS/README.md SESSIONS/README.md HISTORY/README.md README.md PROGRESS.md AGENTS.md .pi/AGENT-OPS.md` + 各角度 `sessions/`（SESSIONS/sessions、PITFALLS/sessions、TASKS/sessions、DEVICE/sessions、RESOURCES/sessions、RUNBOOK-BRINGUP/sessions、HISTORY/days）。

---

## 0. 结论速览

- **口径链完整**：`INDEX §3` 已声明「数字只读 `TASKS §0/§5`」且**未复述完成度百分比**（合规）；但**复述了 Q28/Q24 的当前口径与 `boot_b=vk94`**，违反自身 SSOT 规则。
- **`SESSIONS/README.md` 是最大同源重复面**：§1 统计（171 行/162 主会话/136 子会话）与 §3 索引表，逐字搬自 `RESOURCES.md §4` 快照，且 **171 行索引的「结论」列 = 171 个 `sessions/*.md` 的「结论（原文）」逐字重复**；而 `RESOURCES/README.md:235/242` 仍留**过时计数**（100 个 jsonl / 118 条索引）。
- **纪律类**（先查本地既有结论 / 动分区前备份 / 零写盘 / 无证据不得写已修复）在 `PITFALLS/README §0`、`.pi/AGENT-OPS §1–§3`、`RUNBOOK` 三处近逐字并存；`AGENT-OPS` 内部「一次正反判断」自身重复一次。
- **PITFALLS 编号范围**只在 `PITFALLS/README.md:7` 维护，但 `README.md:90` 另写「170+ 条」= 数字冲突。
- **容量档建议值**（160–200 / 64–96）与「一次给足」在 `DEVICE §3` 与 `RUNBOOK` 各写一遍。

---

## 1. 重复清单

| 重复主题 | 主 SSOT（应保留） | 重复位置（应改引用） | 类型 | 建议 |
|---|---|---|---|---|
| **Q28 当前口径**（坏发 ~50%、逐启动随机/成簇、与镜像身份无关、命令 DMA、`boot_b=vk94`、上游栈暂不可作对照臂） | `TASKS/README.md:169`（§5 Q28，自我声明权威） | `INDEX.md:91`；`TASKS/README.md:15`（§0 速览）；`README.md:75`；`PROGRESS.md:38`（看门狗行）、`PROGRESS.md:133`（收尾轮） | 语义+数字 | `INDEX.md:91` 只留「未解，`boot_b` 见 DEVICE §1.1，口径只读 TASKS §5 Q28」，删 ~50%/vk94/逐启动随机；§0 速览只留 ID；README/PROGRESS 数字改指针 |
| **Q24 当前口径**（致死=SoC 级复位+~30 s 自动重启、最小触发=camcc+cambist 配对+真熄屏、用户裁决互斥） | `TASKS/README.md:167`（§5 Q24） | `INDEX.md:92`；`TASKS/README.md:15`；`README.md:76`；`PROGRESS.md`（§4 Q24 段） | 语义+数字 | `INDEX.md:92`/`README.md:76` 改纯指针；`PROGRESS` 保留时间线但去掉与 §5 重复的「当前口径」数字 |
| **`boot_b = vk94`（在机镜像形态）** | `DEVICE/README.md:29`（并 `:78` U2 台账） | `INDEX.md:91`；`TASKS/README.md:15,19,169`；`README.md:75`；`PROGRESS.md:133` | 数字（设备状态） | 除 `DEVICE` 外全部改「见 `DEVICE §1.1`」；`TASKS §5 Q28` 可保留「日常 boot_b」因属判据上下文 |
| **PITFALLS 条目编号范围（#1–#261）** | `PITFALLS/README.md:7`（明确「编号范围只在本行维护」） | `README.md:90`（写「170+ 条」） | 数字冲突 | `README.md:90` 删数字，改「编号范围见 `PITFALLS §0` 抬头」 |
| **SESSIONS §1 统计（171 行 / 162 主会话 / 136 子代理 / 77✅）** | `SESSIONS/README.md:33`（声明「会话数字 SSOT = 本表」） | `INDEX.md:65`（171）；`SESSIONS/README.md:16`（171）；`RESOURCES/README.md:235`（**100 个 jsonl**）、`:242`（**118 条会话索引（数字 SSOT，§4）** — 陈旧） | 数字冲突/陈旧 | `RESOURCES:235/242` 改「数量见 `SESSIONS/README.md §1`」，删除 100/118 陈旧值；`INDEX:65` 改指针或标注为快照 |
| **HISTORY 提交总数 445** | `HISTORY/README.md:14`（+`:47,:140` 校验） | `INDEX.md:66`（445） | 数字（快照） | `INDEX:66` 改「总数见 `HISTORY/README.md §1`」 |
| **Linux 容量档建议值（512 档 160–200；256 档 64–96 GiB）** | `DEVICE/README.md:142`（§3.2） | `RUNBOOK-BRINGUP/README.md:25`（§0.0 表）、`:279`（Phase 3 注释） | 逐字 | RUNBOOK 两处改「值域见 `DEVICE §3.2`」，仅保留 `LINUX_GIB` 变量语义 |
| **「一次给足、不预设固定值」容量策略** | `DEVICE/README.md:141`（§3.2 规则 1） | `INDEX.md:20`（使命 8 行）；`AGENTS.md:23`；`RUNBOOK:25,29,279,431` | 语义 | `INDEX/AGENTS` 已引用 `DEVICE §3`，可接受；RUNBOOK 保留操作解释，去重口径即可 |
| **零号纪律「先查本地既有结论再取证」** | `PITFALLS/README.md:13`（事实层） | `.pi/AGENT-OPS.md:43`；`RUNBOOK-BRINGUP/README.md:86` | 逐字/语义 | 保留 `PITFALLS #87` 为唯一正文；`AGENT-OPS:43` 与 `RUNBOOK:86` 改「见 `PITFALLS #87`」式引用 |
| **「动分区/刷写前先备份 + 写后读回校验」** | `PITFALLS/README.md:14`（事实） | `.pi/AGENT-OPS.md:18`（§1 表）、`:33`（§2）；`RUNBOOK` 各 Phase 内联命令 | 逐字 | `AGENT-OPS:18/33` 保留行为判据但改引用 `PITFALLS §0`/`DEVICE §3.2` 的技术正文 |
| **「零写盘优先 / `-ram` 与持久变体不得混」** | `PITFALLS/README.md:15,17`（#92/#93） | `.pi/AGENT-OPS.md:36`；`RUNBOOK-BRINGUP/README.md:229`（Phase 2 警示） | 逐字 | `AGENT-OPS:36`、`RUNBOOK:229` 改引 `PITFALLS #92/#93`，保留一句操作结论 |
| **「无设备证据不得写已修复；间歇性故障单次样本无效」** | `PITFALLS/README.md:16,18`（§0 纪律 4） | `.pi/AGENT-OPS.md:44`（§3）；`TASKS/README.md` 判据列（多处「命令+原始输出可复现」） | 逐字 | `AGENT-OPS:44` 已是规范面，保留；`TASKS` 任务行不再重述纪律 |
| **「一次正反判断」** | `.pi/AGENT-OPS.md:49`（§3 研发纪律） | `.pi/AGENT-OPS.md:24`（§1 执行原则）——**同文件内部重复** | 逐字 | 合并为一条，`AGENT-OPS:24` 改引 §3 |
| **「worker 结论必须被编排者独立复跑」** | `.pi/AGENT-OPS.md:81`（§6，行为权威） | `TASKS/README.md:6`（表头）；`PROGRESS.md:168`（§7）；`README.md:78`（§4 结论纪律） | 语义/逐字 | `TASKS:6`/`PROGRESS:168`/`README:78` 改「见 `.pi/AGENT-OPS.md §6`」，保留各自语境一句话 |
| **会话身份与检索 = pi 原生（`session_search`/`/resume`）** | `SESSIONS/README.md:14-16`（+`RESOURCES/README.md` §4） | `INDEX.md:48`（§2）、`INDEX.md:74`（§2）；`.pi/AGENT-OPS.md:70`（§4）；`TASKS/sessions/README.md:7`、`RESOURCES/sessions/README.md:7`、`PITFALLS/sessions/README.md:7` | 逐字 | 各处改引 `SESSIONS/README.md §0`；角度 `sessions/README.md` 收敛为指向 `INDEX §2` |
| **文档 v2 结构说明（角度文件夹 + README SSOT + sessions/ 命名）** | `INDEX.md §2`（`:44-58`） | `.pi/AGENT-OPS.md §4`（`:65-72`）；`TASKS/sessions/README.md:3-8`、`RESOURCES/sessions/README.md:3-8`、`PITFALLS/sessions/README.md:3-8`（三份近逐字） | 逐字 | 三个角度 `sessions/README.md` 用同一模板但改为「标准见 `INDEX §2`/`AGENT-OPS §4`」，删复述 |
| **3 份角度 `sessions/README.md` 样板** | 取一份为模板 | `TASKS/sessions/README.md:3-8` ↔ `RESOURCES/sessions/README.md:3-8` ↔ `PITFALLS/sessions/README.md:3-8`（含「命名 YYYY-MM-DD-<主题>.md / 文件头字段 / 只放跨会话新增 / 会话身份 / 标准见 INDEX §2」） | 逐字 | 保留模板，正文改一行指针；或标注为生成物 |
| **SESSIONS/README.md §3 索引「结论」列 ↔ 171 个 session 文件「结论（原文）」** | 二者均由 `gen-sessions.py` 从同一快照生成（`SESSIONS/README.md:3-4,11`） | `SESSIONS/README.md` 每行结论 ↔ `SESSIONS/sessions/*.md` 的「结论（原文）」节（节标题 line 24 起，如 `2026-10-11-q24-q28-关系辨析.md:24-27`） | 逐字（171×） | 二选一保留：session 文件只留身份+链接不回抄结论，或 README 索引删结论列 |
| **HISTORY/days/*.md 头部样板** | 生成物（`HISTORY/README.md:135-140`） | `HISTORY/days/*.md:1,3,4`（17 个文件） | 逐字 | 生成物，可接受；如需减重可把 header 抽到生成器常量 |
| **持久 rootfs 归档规格（3.44 GB / 30852 项）** | `RESOURCES/README.md:138`（§2.2 资产台账） | `TASKS/README.md:32`（G1-3）；`RUNBOOK-BRINGUP/README.md:45`；`DEVICE/README.md:131`（§3.1） | 数字 | TASKS/RUNBOOK/DEVICE 改「见 `RESOURCES §2.2`」，仅保留用途说明 |
| **GPT 手术结果数字（449.7→256.7 / 193.0 GiB）** | `DEVICE/README.md:117-118`（§2.5 GPT 参数，唯一权威） | `TASKS/README.md:31`（G1-2）、`:177`（Q7）；`PROGRESS.md:12`；`SESSIONS/README.md:130`（索引行） | 数字 | 除 DEVICE 外改「参数见 `DEVICE §2.5`」；TASKS G1-2 可保留「已完成」结论 |
| **`clean/base` 内核分界线（`d02658e63` / `baseline/feature-only` `6c1376907`）** | `TASKS/README.md:119`（§4 口径） | `INDEX.md:101`（§3） | 逐字 | `INDEX:101` 改指针「口径在 `TASKS §4`」 |
| **AOSP 树体量 550 G** | `RESOURCES/README.md:157`（§2.3 大容量资产） | `DEVICE/README.md:135`（§3.1 估算表）；`SESSIONS/README.md:116`（索引行） | 数字 | DEVICE 改「见 `RESOURCES §2.3`」 |
| **备份目录命名 `<SN>-<容量档>` / 禁用 `new-tablet`** | `INDEX.md:21`（术语）+ `DEVICE/README.md:121` | `TASKS/README.md:96`（A16）、`:223`；`RUNBOOK-BRINGUP/README.md:26,32` | 语义 | RUNBOOK/TASKS 改引 `DEVICE §2.5`；保留 `$BAK` 变量定义 |
| **Widevine L1（解锁前基线）/ L1→L3 不可逆** | `TASKS/README.md:180`（Q15）+ `:231`（风险登记） | `RUNBOOK-BRINGUP/README.md:72,110,166`；`TASKS/README.md:74`（C0）；`RESOURCES/README.md`（解锁链取证 §1.4） | 语义 | RUNBOOK 保留操作提示，结论数字指向 `TASKS §5 Q15`/`Q1` |
| **Q31 已解口径（E1b 1 行 PLL_SYSTEM_MUXES / 上游 `44784327815b` revert）** | `TASKS/README.md:170`（§5 Q31） | `INDEX.md:94`（§3） | 语义 | `INDEX:94` 改指针 |
| **「Q26 WiFi 已关闭（2026-10-10 用户确认）」** | `TASKS/README.md:168`（§5 Q26） | `INDEX.md:96`（§3 已关闭列表）；`DEVICE/README.md`（§1.2 WiFi 行）；`TASKS/README.md:14` | 语义 | 各处改引 `TASKS §5 Q26` |
| **「`vk81/82/83` = 无 QCOM 驱动死内核，结果作废」** | `PITFALLS/README.md` #162（正文） | `TASKS/README.md:36`（G1-22）、`:141`；`README.md:78`；`PROGRESS.md` §4；`INDEX.md` §3 | 语义 | 保留 `PITFALLS #162` 为唯一正文，其余指针化 |
| **「kexec 定论不可用 / device_shutdown 掉电根因」** | `TASKS/README.md:120`（§4 口径） | `RUNBOOK-BRINGUP/README.md:376-383`；`INDEX.md:95`；`PROGRESS.md` | 语义 | RUNBOOK 保留操作命令，根因口径指向 `TASKS §4` |
| **`cd ~/y700-elden` + 常用命令块** | `RESOURCES/README.md:295`（git 工作流） | `INDEX.md:110`（§4 快速命令）；`RUNBOOK:234,278,334`（Phase 命令头） | 逐字/片段 | 属正常操作示例，低优先；可改为统一「命令入口见 `INDEX §4`」 |
| **每会话「当日提交史」行（动态日期/条数）** | 生成物 | `SESSIONS/sessions/*.md:34`（172×）+ `HISTORY/days/*.md` | 逐字样板 | 生成物，接受 |

---

## 2. Top-20 最该先改的重复项

1. **`INDEX.md:91`** — 删 Q28 数字（~50%、逐启动随机、`boot_b=vk94`、命令 DMA 细节），改「未解；口径只读 `TASKS §5 Q28`」。
2. **`INDEX.md:92`** — Q24 当前口径改纯指针（`TASKS §5 Q24`）。
3. **`TASKS/README.md:15`（§0 速览）** — Q28/Q24 两条长口径压缩为 ID + 指针，避免与 §5 双份维护。
4. **`README.md:90`** — 「170+ 条」删除，改「编号范围见 `PITFALLS §0` 抬头」。
5. **`RESOURCES/README.md:242`** — 删「118 条会话索引（数字 SSOT，§4）」（陈旧且指向已改写的 `README §4`）。
6. **`RESOURCES/README.md:235`** — 「100 个 jsonl」改为「会话数见 `SESSIONS/README.md §1`」。
7. **`INDEX.md:65`** — 「171 个逐会话档案」改指针或明确标注为快照日期。
8. **`INDEX.md:66`** — 「445 条」改「见 `HISTORY/README.md §1`」。
9. **`RUNBOOK-BRINGUP/README.md:25` + `:279`** — 容量建议值（160–200/64–96）改「见 `DEVICE §3.2`」。
10. **`DEVICE/README.md:135`** — 「Android 树 550 G」改「见 `RESOURCES §2.3`」。
11. **`TASKS/README.md:32` / `RUNBOOK:45`** — rootfs「3.44 GB / 30852 项」改「见 `RESOURCES §2.2`」。
12. **`INDEX.md:101`** — 内核分界线改指针（`TASKS §4`）。
13. **`INDEX.md:94`** — Q31 已解口径改指针（`TASKS §5 Q31`）。
14. **`.pi/AGENT-OPS.md:24` vs `:49`** — 合并重复的「一次正反判断」。
15. **`PITFALLS/README.md:13/14/15` vs `.pi/AGENT-OPS.md:18/33/36/43`** — 纪律条文择一为正文（建议 `PITFALLS` 保事实、`AGENT-OPS` 保行为判据），互相引用。
16. **`TASKS/README.md:6` / `PROGRESS.md:168` / `README.md:78`** — 「worker 独立复跑」统一指向 `.pi/AGENT-OPS.md §6`。
17. **三个角度 `sessions/README.md`（`TASKS`/`RESOURCES`/`PITFALLS`）第 3–8 行** — 收敛为同一指针模板，删复述正文。
18. **`SESSIONS/README.md` 索引「结论」列 ↔ `SESSIONS/sessions/*.md`「结论（原文）」** — 二选一（建议 session 文件不再回抄结论，或索引删结论列）。
19. **`TASKS/README.md:31` / `PROGRESS.md:12`** — GPT 手术数字改「见 `DEVICE §2.5`」。
20. **`RUNBOOK-BRINGUP/README.md:26,32` / `TASKS:223`** — `new-tablet` 禁用口径改引 `DEVICE §2.5`/`INDEX:21`。

---

## 3. 附：方法可复核性

```bash
# 1) 归一化 hash 聚类（行级/句级），输出触主文件的跨文件重复组
python3 /tmp/dedup.py        # 行级 89 组 -> /tmp/dup_cross.json
python3 /tmp/dedup3.py       # 句级 291 组 -> /tmp/dup_sent_norm.json
# 2) 语义/数字逐条核对（本报告 file:line 均来自此）
grep -nE 'Q28|Q24|boot_b.*vk94|~50%|445|171|162|编号范围|170\+|3\.44 GB|30852|550 G|new-tablet|独立复跑' <files>
```

> 未改仓库文件；本文即唯一产出。
