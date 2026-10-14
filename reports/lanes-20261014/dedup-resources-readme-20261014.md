# 过时计数修正 + 重复改引用（RESOURCES / 根 README / PROGRESS）

- Lane: `dedup-resources-readme-20261014`
- 边界：`RESOURCES/**`、`README.md`（根）、`PROGRESS.md`（未越界；INDEX/TASKS/AGENT-OPS/SESSIONS/.githooks/versions 未动）
- 改动文件：`RESOURCES/README.md`(4 处)、`README.md`(1 处)、`PROGRESS.md`(5 处)
- 行号核对：改动前用 `grep -n`/`sed -n` 逐一核对，行号与审计一致。

## 结论

| # | 文件:行 | 问题 | 处置 |
|---|---|---|---|
| 1 | RESOURCES/README.md:235 | 「.pi/sessions/（100 个 jsonl…）」数字过时（实际顶层 `.pi/sessions/*.jsonl` = **168**） | 删「100 个 jsonl」，改「jsonl 会话轨迹」+ 指针 **会话数 SSOT = SESSIONS/README.md §1** |
| 2 | RESOURCES/README.md:242 | 「README.md §4 \| 118 条会话索引（数字 SSOT，§4）」：会话索引已迁 SESSIONS/ 角度，根 README §4 不再是会话 SSOT | 整行改写为 `SESSIONS/README.md + SESSIONS/sessions/`（784 K，会话数 SSOT=§1，原索引已迁此） |
| 3 | README.md:90 | 「PITFALLS/README.md（170+ 条）」与 PITFALLS 实际编号冲突（现 `#1–#261`） | 删数字，改「条目编号范围见该文件抬头」 |
| 4 | PROGRESS.md:73-133 | §4 复述 TASKS 当前口径（Q28 坏发率 / boot_b=vk94 / Q24 致死口径 / 邮件状态等），且已漂移（v3 早已发出） | §4 抬头加指针；Q28 两条「状态」bullet 收敛为 1 条历史指针；误置在 Q24 段末的 Q28 收尾轮 bullet 收敛为指针；Q24「下一步状态」收敛为指针。均指 **TASKS/README.md §5 Q28/Q24** |
| 5 | RESOURCES/README.md:287 / :313-315 | §3 H1 行仍指「README.md §4」；§4「会话检索」无会话数 SSOT 指向 | H1 改指 `SESSIONS/README.md`；§4 标题+正文补「会话数/统计 SSOT = SESSIONS/README.md §1」 |

## 证据（命令）

- 磁盘事实：`ls .pi/sessions/*.jsonl | wc -l` → **168**（顶层）；`du -sh SESSIONS` → **784K**；`git ls-files SESSIONS | wc -l` → 172（tracked）。
- PITFALLS 抬头（只读核对）：`PITFALLS/README.md:6` → 「条目编号 **#1–#261**」「编号范围只在本行维护，其它文档不复述具体数字」。
- SESSIONS SSOT：`SESSIONS/README.md:33` 会话数字 SSOT = 本表（§1）。
- 改动后核验：`grep -n '100 个 jsonl|118 条会话'` 无残留；`grep -n 'SESSIONS/README.md' RESOURCES/README.md` 命中 235/242/287/313/315；`grep -c 'TASKS/README.md' PROGRESS.md` → 13；`git diff` 仅上述 3 文件。

## 保留（未改，附理由）

- **PROGRESS.md §1 时间线**（含 :15「约 6 成」、:38「~50%→~75%」、:40 的 `vk94` 臂标签）：均为带日期的事件记录，符合「PROGRESS 只留时间线」；非当前口径陈述，故保留。任务列举的「:38」经核对是时间线行，未作删改。
- PROGRESS §4「被推翻的结论（诚实记录）」段：PROGRESS 独有、非 TASKS 复述，保留。
- PROGRESS Q24 引言（现象/机制/用户裁决一句话）与第 1–7 轮实验史：历史证据，保留。

## 需要父 agent / 其它边界的待办（越界，未改）

1. **SESSIONS/README.md §1 自相矛盾**：:33 写「磁盘主会话 jsonl **162**」，而实际顶层 = **168**（本 lane 只作指针，未改 SESSIONS/）。建议父侧复核 162/168/171 三数口径。
2. **根 README.md §4「已知问题（当前）」表**（:75 Q28、:77 Q24）：仍逐字复述 TASKS §5 当前口径（坏发 ~50%、boot_b=vk94、看门狗兜底、上游报告待发等），属同一类重复；本任务仅要求改 §5 仓库地图的 PITFALLS 行，故未动，建议后续改为指针或注明「当前口径见 TASKS §5」。
