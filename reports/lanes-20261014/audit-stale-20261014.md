# 过时 / 残缺 / 断链审计 — 2026-10-14

> 只读审计，未改任何仓库文件（本输出除外）。工作目录 /home/xuqianhui1001/y700-elden。
> 方法：脚本解析 + 逐行核对；证据给 file:line。仓库文档 v2：INDEX.md 唯一入口，7 角度文件夹。

**结论先行**：文档树整体健康——707 个 .md、554 条相对链接 **0 断链**；171 个逐会话档案 **0 结构性缺失**（仅 2 个 junk 冒烟档案结论为占位）。真正的欠账集中在三处：
1) `TASKS/README.md` §7 内部自相矛盾（慢启动 430 行仍写「未定位」，471–475 行已定案修复）；
2) `PITFALLS` 条目号 `#262` 被引用但从未登记；
3) `SESSIONS/README.md` §1 的「9 条墓碑行 / reference=34」与磁盘实况对不上。

---

## A. 残缺 / 不完整的会话记录

### A1. `SESSIONS/sessions/*.md`（171 个）文件头字段逐文件核查

- 字段齐全度：**171/171** 均有「## 身份」表（日期 / pi 会话 id / 主题 / 实机 / 状态 / kv）与「## 结论（原文）」「## 风险 / 未收口」段；**0 个**缺 pi 会话 id、0 个缺日期、0 个缺主题。
- **schema 与 INDEX §2 的 v2 文件头规范不一致（系统性）**：这 171 个档案**没有任何一个**含「证据指针」或「★SSOT 待并入」字段（`grep -rl '证据指针' SESSIONS/sessions/` = 0；`SSOT 待并入` = 0）。它们是 `scripts/gen-sessions.py` 从冻结快照 `git show d8ae437:RESOURCES.md` §4 **机械生成**（文件尾自带「机械生成，勿手改」）。建议：**保留**（是逐会话档案、非角度会话进度，两套规范不同），但在 SESSIONS/README.md §4 明确说明「本目录档案**不套用** angle sessions 的文件头字段」以免下次审计重复误报。
- 结论为占位/空的文件（不合格）——**2 个**：

| file:line | 结论值 | 建议 |
|---|---|---|
| `SESSIONS/sessions/2026-10-05-会话-冒烟-2-01a109ec.md:25`（结论行 :27） | `空测试` | 保留（junk 冒烟，§3 状态列已标 junk，可整行忽略） |
| `SESSIONS/sessions/2026-10-05-会话-冒烟-3-01a109ed.md:24`（结论行 :26） | `空测试` | 同上 |

另 `2026-10-05-会话-冒烟-1-01a109e8.md:27` = `空测试，0 工具调用`（有内容，非占位）。§3 表共 **12 行 junk**，均可忽略。

### A2. 各角度 `sessions/` 中「★SSOT 待并入」未并入 README 的条目

- 实际带待并入正文的**只有 1 个文件**：`TASKS/sessions/2026-10-14-m1-73-mainlining.md:8`（标题在 :8，条目 :10–:22）。DEVICE/RESOURCES/RUNBOOK-BRINGUP/PITFALLS 四个 `sessions/` 只有 `README.md`（模板说明），无实际会话文件；其余 TASKS/sessions 两文件无 ★SSOT 段。
- 逐条并入状态：

| # | 条目（摘要） | 是否已并入 README | 证据 |
|---|---|---|---|
| 1 | WCN 90 s 停滞根因 = 缺 `patches/0001-ath12k-shorten-mhi-timeout`，非 7.3 回归 | **已并入** | `TASKS/README.md:471,473` |
| 2 | M1-7.3 快启动 `Run /init` 7.67 s + `wlan0` 通（daily config + 补丁 0001） | **已并入** | `TASKS/README.md:472,474` |
| 3 | 显示侧三连否证 ⇒ Q28 会话级坏发簇 | **已并入（实质）** | `TASKS/README.md:15,169`（Q28「按时间成簇」口径） |
| 4 | 机器账重生成（identity.tsv + known-issues 例外；FAIL=0/WARN=8） | **已并入** | `TASKS/README.md:473` |
| 5 | 建议并入 PITFALLS 的 4 条方法学（#259–#262） | **部分未并** | #259/#260/#261 已登记 `PITFALLS/sessions/33-...md:21,27,32`；**#262 全仓不存在**（见 C3） |

建议：该会话 §「★SSOT 待并入」可删标题、保留正文（或按 RUNBOOK-BRINGUP/sessions/README.md:25 规则并入后移除标记）；补登记 #262。

### A3. `.pi/sessions/*.jsonl`（顶层 168 个）疑似被中断/极短会话

- 逐文件解析 role 计数：**无「无 assistant 回复」的会话**（每个 jsonl 都 ≥1 条 assistant）。极短（<15 行、1 条 assistant）共 **5 个**，全部是已知冒烟/空会话，§3 表均已标 junk：

| 短 id | 行数 | 对应 SESSIONS 档案 | 状态 |
|---|---|---|---|
| `01a1071b` | 13 | `2026-10-04-会话.md`（「可以继续了」，仅一句用户消息） | junk |
| `01a109e8` | 11 | `2026-10-05-会话-冒烟-1-01a109e8.md` | junk |
| `01a109ec` | 11 | `2026-10-05-会话-冒烟-2-01a109ec.md` | junk |
| `01a109ec` | 11 | （第二条 jsonl，同上 id） | junk |
| `01a109ed` | 11 | `2026-10-05-会话-冒烟-3-01a109ed.md` 等 | junk |

- 另有 **6 个顶层 jsonl 不在 171 行快照表内**（10-14 快照冻结后新增，符合 README §0「此后新增会话不在表内」）：`01a13867 / 01a13903 / 01a13917 / 01a13969 / 01a13a25 / 01a13a4d`。建议：保留（快照口径已声明）。

### A4. `SESSIONS/README.md` §3 的 171 行「墓碑行」

- 严格判据（行 → 链接 `sessions/*.md` 是否存在、档案内列出的 jsonl 是否在盘）：**171 行全部通过，0 条无对应 jsonl 的墓碑行**。
- 但 README §1 声明「本索引 **171** 行（含 **9 条**已删除/迁移会话的墓碑行）」`SESSIONS/README.md:33`，**与实况不符**：
  - 171 行 = **162** 个不同 pi 短 id + **9** 条重复 id 行；这 9 条重复行是**子代理/同会话多主题行，并非删除/迁移**：`01a10527`×3、`01a105fb`×3、`01a10596`×2、`01a10736`×2、`01a109e8`×2、`01a109ec`×2、`01a12d5a`×2。
  - PITFALLS #15.3 登记的已删 junk（`01a0f533/01a0f608/01a0fa4b/01a0fabe/01a101b5`）**都不在 §3 表内**、盘上也无 jsonl。
- 附带统计漂移：§1「active 119 / reference 34 / junk 12 / superseded 5」= 170 ≠ 171；实测 §3 表 **reference = 35**（`SESSIONS/README.md:33`）。
- 建议：**改引用**——把「9 条墓碑行」改为「9 条重复 id 行（子代理/多主题）」；修 reference 34→35。或将该行标注为「逐字搬自源 §4.1、未随 v2 重核」。

---

## B. 过时 / 被取代但仍按现状陈述

### B1. `PITFALLS/sessions/15-过时废弃功能缺陷登记.md`（全文已读，115 行）边界总结

- **#15 的定位**（`:3-5`）：登记「已过时/废弃/被取代的**文件、会话、技能结论** + 已知功能缺陷」，是「**别再依赖**」的索引，**不写状态**——状态权威在 `TASKS/README.md`/§1/§5、`RESOURCES/README.md`。
- 现存登记项（7 小节）：15.1 已废弃/合并/删文件（含根 `build.sh/iterate.sh/pack.sh`、死内核 vk81/82/83）；15.2 退役外部资产；15.3 被取代/无效会话（junk）；15.4 技能参考过时结论；15.5 已知功能缺陷**纯索引**（表内只有缺陷名→权威入口，**不复制状态**）；15.6 已否掉生态方案；15.7 编号体检（1–261 一号一条）。
- **与 `archive/topics/pitfalls-archive-20261014.md` 的边界**（15.7 末行 `:114`）：8 条已作废/被取代条目（**#163/#167/#168/#171/#175/#192/#195/#250**）的**逐字原文移入 archive**；PITFALLS **原位只保留条目号 + 结论首行 + 指针**，archive 是证据层、非 SSOT。
- 判读：**边界清晰、无重叠**。#15 是「废弃索引」，archive 是「被取代条目的全文存档」，`TASKS`/`RESOURCES` 是状态权威。未发现 #15 内条目与 archive 矛盾。

### B2. 标记词扫描（作废/已失效/已过时/DEPRECATED/已被取代/停用/不再）——活跃文档中仍当「当前口径」的过时内容

| file:line | 现陈述 | 问题 | 建议 |
|---|---|---|---|
| `TASKS/README.md:430` | 「慢启动：M1 内核到用户态 `Run /init` **~95 s**（daily ~5 s），疑 ath12k 探测阻塞内核 init（`PITFALLS #250`，**未定位**）」 | **过时**：同一 §7 内 `:471-475` 已定案（根因=缺补丁 0001；已修；`Run /init` 7.67 s）。同文自相矛盾 | **改引用/删**（改为「→ 见下 :471」） |
| `TASKS/README.md:475` | 「未决（下一轮）① WCN 首探根因……并**考虑移植** 7.2 侧 MHI 90s→3s 补丁」 | **过时**：该「未决」在 `:471-474` 已解决并机上验收 | **删/改**为已并入项 |
| `TASKS/README.md:429` | 「……后者仍卡亮屏」 | 同句尾已附 2026-10-14 更正（E1b 已修复），前半句口径过时 | **改引用**（保留更正即可） |
| `PITFALLS/README.md:6` | 「条目编号 **#1–#261**」 | `#262` 被 `TASKS/README.md:475` 与会话引用但未登记（见 C3） | **补登记 #262** |
| `SESSIONS/README.md:33` | 「reference 34 / 9 条墓碑行」 | 与实况不符（见 A4） | 见 A4 |

- 其余标记词命中均属**正当的历史链/更正记录**（如 `README.md:75` Q28「构建身份伪影**作废**」= 当前口径；`PROGRESS.md:32,138` 作废声明；`TASKS/README.md:102-105` §3 已作废旧任务线指向 archive；`DEVICE/README.md:83` 已作废条目标注「口径纠正」）。**不属过时陈述**。

### B3. `TASKS/README.md` §5（Q 项）中已标「已解/关闭/已答」但仍占正文的条目

§5 共 24 个 Q 行；其中 **16 个已闭合却仍以整段正文保留**（多为删除线 + 完整历史正文）：

| file:line | Q | 状态词 |
|---|---|---|
| `TASKS/README.md:164` | Q21 | 「已归因 → 并入 Q24」 |
| `TASKS/README.md:165` | Q23 | 已解决 |
| `TASKS/README.md:168` | Q26 | ✅ 已关闭 |
| `TASKS/README.md:170` | Q31 | ✅ 已解 |
| `TASKS/README.md:172` | Q2 | ✅ 已答 |
| `TASKS/README.md:176` | Q6 | 已定稿 |
| `TASKS/README.md:177` | Q7 | 已解决 |
| `TASKS/README.md:178` | Q8 | 已解决 |
| `TASKS/README.md:179` | Q9 | 已解决 |
| `TASKS/README.md:180` | Q15 | 已执行 |
| `TASKS/README.md:183` | Q17 | 不再阻塞 |
| `TASKS/README.md:185` | Q11 | 已结 |
| `TASKS/README.md:187` | Q13 | 已解决 |
| `TASKS/README.md:188` | Q14 | ✅ 已解 |
| `TASKS/README.md:189` | Q19 | 已结 |
| `TASKS/README.md:191` | Q30 | 已修 |

- 说明：§5「勾销规则」(`:243`) 规定闭合项保留追溯，故**不算违规**；但 `:199` 已声明「已闭合/取消……不再在此复述」，实际仍复述 16 条。建议：**保留**（有追溯价值）或统一压缩成「已闭合清单 + 指针」；至少与 `:199` 口径对齐。

---

## C. 断链 / 孤儿

### C1. 全量相对链接检查 — **0 断链**

- 扫描 **707 个 .md**（排除 .git/build/out/logs 等非文档目录），共 **651 条 `](...)` 链接，554 条相对链接**，逐条解析并 `os.path.exists`：**0 条断链**（含 INDEX/TASKS/PITFALLS/SESSIONS/HISTORY 全量表）。
- 注：`scripts/check-doctor.sh` 文档 v2 起**已不再做死链检查**（脚本头注释 `:6-7`），故本项由本次审计独立执行。

### C2. 活跃引用不到的 `scripts/*.sh`（check-doctor DEAD 口径）

- 直接运行 `scripts/check-doctor.sh`（退码 0，FAIL=0 / WARN=7），§6 报：**DEAD = `scripts/q28-cold-sample-loop.sh`**（在 `scripts/` 之外仅出现于 `.pi/sessions/*.jsonl` 与 `.git`，语料排除后者 ⇒ 无任何活跃文档/脚本引用）。
- 建议：**核实后删或标 legacy**（与 PITFALLS #15.2 的 `sleep-bisect.sh` 同类处置——「不删、降为 legacy」需在 #15.2 补登记）。

### C3. 悬空交叉引用（应属断链变体）

- **`#262`**：被 `TASKS/README.md:475` 与 `TASKS/sessions/2026-10-14-m1-73-mainlining.md:14`（「#259–#262」）引用，但 **PITFALLS 全仓（README + sessions/01–33）无 #262 条目**（`git grep '#262' -- PITFALLS` 空）；`PITFALLS/README.md:6` 只声明到 #261。
- 建议：**补登记 #262**（方法学第 4 条「显示 A/B 必须报簇状态」）或把引用改为 #259–#261。

---

## 汇总建议优先级

1. **改引用**：`TASKS/README.md:430,475`（慢启动/WCN 已定案，勿再当未决）；`TASKS/README.md:429`。
2. **补登记**：PITFALLS `#262`（C3/B2）。
3. **改引用**：`SESSIONS/README.md:33`「9 条墓碑行」→「9 条重复 id 行」、reference 34→35。
4. **删/标 legacy**：`scripts/q28-cold-sample-loop.sh`（C2），并在 PITFALLS #15.2 补一行。
5. **保留**：171 个逐会话档案（仅 2 个 junk 冒烟结论为占位）；`TASKS` §5 闭合 Q 项正文（有追溯价值）。

> 生成：2026-10-14 只读审计。方法=脚本解析（链接/字段/jsonl）+ 逐行核对；证据均可 file:line 复核。
