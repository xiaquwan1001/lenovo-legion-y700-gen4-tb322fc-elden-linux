# L3：项目文档精简·整理·修正审计（只读）

## A. 体量与门禁（现查 2026-11-04，HEAD=5f6bdcf）

### A.1 实跑 scripts/check-doctor.sh：FAIL=0 / WARN=4（命令 `bash scripts/check-doctor.sh 2>&1 | tail -1`）
- `[warn] registry 前的历史镜像无 manifest（历史留白）：vk183-fastrpc`（§5）
- `[warn] 账本已登记的例外`（§5d，≈90 个历史镜像 uts_dup/num_ne_tag 标记，理由在 versions/vk-ledger-known-issues.tsv）
- `[warn] 内核段不可读`：boot-elden-posctrl-markspin{,-2,-3,-3gz}-v2-20261103.img 4 个（§5d）
- `[warn] 无版本号构建拷贝 1 个：boot-elden.img`（§5d）
- 文档侧门禁（§7 围栏/截断、§8 索引对账、§9 SESSIONS、§10 HISTORY、§13 资产路径 checked=315、§14 布局 entries=46）**全 ok**。

### A.2 各主文档体量（wc -l / du -b，实查）
| 文件 | 行数 | 字节 | 备注 |
|---|---|---|---|
| TASKS/README.md | **121** | **184 574** | 平均行 1.5KB，巨型表格行是体量主因 |
| PITFALLS/README.md | 202 | 69 293 | |
| RESOURCES/README.md | 376 | 54 615 | |
| PROGRESS.md | 221 | 51 252 | |
| DEVICE/README.md | 211 | 27 559 | |
| INDEX.md | 232 | 23 178 | |
| .pi/AGENT-OPS.md | 102 | 12 290 | |
| AGENTS.md | 32 | 2 948 | 与全局/项目口径一致 |

### A.3 超规模口径判定
- 项目自身规则：INDEX.md:24 规则 4「状态数字只改 TASKS §0 一处」、INDEX.md:26 规则 7「不写死计数」、INDEX.md:37 表「PROGRESS.md 不得写权威台账」。**TASKS §1/§2 表格行内复述了几十个已被 sessions 下沉的结论**（⟪全文见 TASKS/sessions/…⟫ 指针已有 6 处，但同格仍留大段历史），违反「正文只留指针」精神——口径未明文规定行长度上限，属灰色超规模。
- TASKS §0 由脚本导出（行 21 注），无手写数字问题。
- INDEX.md §3 现状速览已做纯指针化，合规。

待填：B/C/D

## B. 过期/矛盾清单（按严重度）

### B1（高）DEVICE/README.md:133 状态口径过期，与 TASKS §0 直接矛盾
- 现状：DEVICE/README.md §2.2 U2 行写「当前未解：Q28 DSI host 楔死、Q24 熄屏×相机（权威 = ../TASKS §0/§5）」。
- 现查：TASKS/README.md:15「🟢 Q28/Q32 已结项（2026-10-24）」「⛔ Q24 熄屏×相机（2026-10-24 用户裁决关闭）」。DEVICE 行虽写「权威=TASKS」，但「当前未解」四个字自身就是过期结论，新会话只扫 DEVICE 会被误导。
- 应改成：删去「当前未解：Q28…Q24…」括号，改「未解项只读 TASKS §5」（纯指针，无状态词）。

### B2（高）TASKS/README.md §0「未开始」列与上游实况矛盾
- 现状：TASKS/README.md:13 未开始列含「上游化 M 系列（以 §7 为准）」。
- 现查：PROGRESS.md:79–86 记 2026-10-28…10-31 M4 camss v2/v3 已投递并 lore 命中（多封 250）；TASKS §7 亦有 M 行状态。上游化显然已开始。
- 应改成：该格改「上游化 M 系列进行中（只读 §7）」，或直接指针化。

### B3（中）boot_b sha 两个值都有出处，但 TASKS 行 240 的「转正」结果已被覆盖
- 现查：DEVICE/README.md:30（★2026-11-02 唯一权威首条）`boot_b` sha256=`fb55997c…`；TASKS/README.md:240（2026-10-31 vk183 真 POR）写「boot_b 仍 `aedae5f1…`」。
- 对账：11-01 UEFI 四臂判别轮在 boot_b 上写过 3 轮载荷后「每轮都刷回本备份」（DEVICE/README.md:32）⇒ 现态 fb55997c = vk172 备份件，10-31 的 vk183 转正件已被覆盖回退。TASKS 行 240 的「vk183 转正为日常件」结论在 boot_b 层已不成立（DEVICE 首条也只写 vk172 UTS）。
- 应改成：TASKS 行 240 补一行更正（或加「已被 11-01 回退覆盖，现态见 DEVICE §1.1」）；这是当前在机内核到底是不是 vk183 的重要事实纠偏。

### B4（中）TASKS G1-34 行标题过期
- TASKS/README.md:50 标题「G1-34 加速度计/重力传感器（SSC/QRTR 路线上线；**SLPI 原生 IIO 未开工**）」；同文件 §0 行 13 已写「G1-34 已收口（SSC 路线两棵根全绿；仅 SLPI 原生 IIO 路线未开工）」且状态列 ✅（2026-10-30）。
- 应改成：标题去掉括号内旧话，或改「（SLPI IIO 为后续可选线）」。

### B5（中）TASKS G1-29 行内与 §5 大段重复叙述（UEFI）
- TASKS/README.md:45 单元格内嵌 ★2026-10-28 复现件重制、sha、配方更正等大段历史，与 §5 的 2026-10-31…11-04 块、`reports/uefi-*-2026*.md` 内容重叠；同一 UEFI 状态在 G1-29 行、§0 行 18、§5 多个日期块三处出现。
- 应改成：行内只留「当前卡点（11-04：DXE dispatch/UFS）+ 指针 §5/reports」，历史段下沉 sessions（项目已有 ⟪全文见…⟫ 先例，本行仅部分执行）。

### B6（低）PROGRESS.md:12 写死「27 项」
- 「驱动 bring-up 批次…见 TASKS §1（27 项）」——写死计数违反 INDEX.md:26 规则 7（不写死计数）。现查 §1 表 G1-0…G1-36 行数可漂。应改成「见 TASKS §1」。

### B7（低）MIGRATION-LOST 标记 12 处（TASKS 4 / RESOURCES 8）
- 均为 2026-10-17 换机丢失日志的已登记留白（如 TASKS G1-26/28 行 `logs/ui-20261011/`）。非矛盾，但散在任务行内；可集中登记到 RESOURCES §3.5 表，任务行只留「⚠️MIGRATION-LOST(见 §3.5)」。

### B8（核对通过项，无需改）
- INDEX.md 写死「layout.tsv 46 项」↔ check-doctor §14 entries=46 一致。
- check-progress-counts.sh 现查 G1 33/35、G2 8/12 ↔ TASKS §0 表一致（脚本导出）。
- `reports/upstream-status-20261029.md`、`reports/gunyah-decision-20261025.md`、`reports/mobian-migration-plan-20261021.md` 等被引报告均在磁盘；check-doc-assets checked=315 全绿。
- versions/layout.tsv=53 行（46 项 + 表头等）；git log 总提交 940（HEAD=5f6bdcf, 2026-11-04）。
- 「交 DXE Core / 未上机」旧口径已被 G1-29 行 11-04 更新覆盖（载荷已执行到 DXE，§5 有 2026-11-04 块），无残留的「未上机」结论被当现状引用；唯一风险点是 B5 的行内历史段。

待填：C/D

## C. 精简方案（分级；预估行数变化以当前 wc 为基）

### P1 立刻改（低风险，仅删/改单点文案，预计 −10…−20 行）
1. DEVICE/README.md:133 删「当前未解：Q28…Q24…」→ 纯指针（B1）。−1 行实质，−~0.3 KB。
2. TASKS/README.md:13 「上游化 M 系列」未开始→进行中指针（B2）。改动 1 格。
3. TASKS/README.md:50 G1-34 标题去旧括号（B4）。
4. PROGRESS.md:12 去写死「27 项」（B6）。
5. TASKS/README.md:19/240 boot_b sha 二选一对齐 DEVICE §1.1（B3，需上机/读 DEVICE 首条确认后改）。
风险：均为文案级，无门禁影响；改后跑 `check-doctor.sh` 确认 FAIL=0。

### P2 需重构（中风险，需要先定新结构再动手）
1. **TASKS/README.md 巨型行拆解**（184 KB / 121 行，均行 1.5 KB）：
   - 方案：§1/§2 每个 ✅ 已完成任务行压成「ID｜一句话结论+日期｜证据指针」三列，历史过程全部下沉 `TASKS/sessions/2026-11-0x-TASKS行N-*.md`（⟪全文见…⟫ 先例已有 6 处，扩展到 ~30 个已完成行）。
   - 预估：184 KB → ~60 KB（−~60%）；行数不降（表格行数不变），但单行 ≤0.5 KB。风险：下沉时丢证据指针——必须逐行保留关键路径；建议按行分批（每批 5 行 + git commit）。
2. **UEFI 叙事三处收敛**（B5）：§5 日期块已按「最新两块保留、老块下沉 sessions」做过一次（11-01/11-02 块已下沉）；再对 G1-29 行与 §0 行 18 同法处理。预估 −~8 KB。
3. **MIGRATION-LOST 集中登记**（B7）：RESOURCES §3.5 建表，12 处行内标记改短指针。预估 −~1 KB。

### P3 观察（暂不动）
1. PITFALLS/README.md（202 行 / 69 KB）：索引行较长但 check-doctor §8 校验通过；正文本就在 sessions/，结构已合理。
2. RESOURCES/README.md §1.3 社区先例段落（如 :50 droidloom 长行）：属外部调研快照，信息密度高且仍在跟踪（Q3），暂留。
3. INDEX.md 232 行：§2 规则较多但都是唯一出口，不动；若 P2.1 落地后可把「会话结束时写什么」8 条瘦身（AGENT-OPS 已声明不复述，INDEX 是权威，保留）。

## D. 不要动的部分（历史档案/证据层）
- `archive/**`（含 topics/复盘-*、AUDIT*）：过程证据，INDEX.md §2 证据层明文「追加为主、不得作为当前结论引用」；修订只能带日期最小备注。
- `SESSIONS/`：2026-10-15 起冻结的逐会话快照，是 `check-sessions.sh` 校验基准（check-doctor §9），改一个字就 FAIL。
- `HISTORY/`：`gen-history.sh` 机械生成，手改会被下次生成覆盖且 §10 对账 FAIL。
- `reports/**`：证据层（check-doctor §8 查孤儿报告）；精简 ≠ 删报告，只允许「不再被入口文档引用」时保持原位。
- `versions/*.tsv`（layout/vk-kernel-identity/registry）：机器对账真源，只能由脚本再生。
- TASKS §0 表：由脚本导出，手改数字会破坏 check-progress-counts（见行 21/26 注）。

## 未完成/卡点
- sessions/（各角度）只做了粗扫（TASKS 3 个下沉文件、PITFALLS 索引结构），未逐文件审计过期叙述；P2 若立项，建议按「每角度一批」再派 lane。
- 未复核 RUNBOOK-BRINGUP/README.md（不在任务对象清单内但被多处引用）。

