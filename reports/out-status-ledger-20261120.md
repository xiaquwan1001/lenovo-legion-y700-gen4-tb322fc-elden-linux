# out/ 造件生命周期账本（out-status.py + versions/out-artifacts.tsv）— 2026-11-20

对应 `.pi/reports/cleanup-audit-20261120/arch-audit.md` §5 #6（P1）：out/ 87G 只有 §23
「大件必须有报告」一道门，没有生命周期状态 ⇒ 每次瘦身都要全量考古。本轮把状态收进
**入库**账本，瘦身从考古变查表。

## 0. 一页结论

- 产物：`scripts/out-status.py`（--init/--check/--selftest）+ 账本 `versions/out-artifacts.tsv`（git 入库）+ `scripts/doctor/25-out-status.sh`（check-doctor §25，只进全量档）。
- 验收：selftest rc=0（三类坏件各 1 条 FAIL 抓到）；`--check` rc=0；`check-doctor` 全量 **FAIL=0 WARN=6**（6 条 WARN 全部为既有：§5 vk 身份降级 ×3、§5f ABI 不可核、§12 无构建树，§25 零新增）；`--only 25` rc=0；人为坏件（pending + 删目录）被 FAIL 抓到后已复原。

## 1. 词表与判据（固定四词，不许自造）

| 状态 | 判据 | 删除政策 |
|---|---|---|
| `active` | 现役/唯一造件，还在被设备或流程使用 | 不可删 |
| `verified` | 已上机或已核验（EDL 写入读回 sha 一致等），可复用 | 可复用；删前查报告 |
| `superseded` | 被取代/中间件/校验副本 | 删候选 |
| `pending` | 等首启/等上机验证 | **禁删** |

## 2. 账本格式

`versions/out-artifacts.tsv`，TAB 分 5 列：`out/<dir> <TAB> 状态 <TAB> 依据 <TAB> 报告指针 <TAB> 最后核对日期`。
「依据」不许空（照 §17/§23 反作弊口径：空依据/非法状态/缺登记均 FAIL）。out/ 本身仍被
.gitignore 忽略，只有账本入库。

## 3. --init 推断规则（依据列必须写明，不许留空）

对 out/ 下 >200MB 一级目录，按序：
1. 任一 `reports/*.md` 行内同时出现 `out/<name>` 与「可删/被取代」 ⇒ `superseded`（依据引报告）；
2. `reports/<name>.md` 头部标记「作废/superseded」 ⇒ `superseded`；
3. 目录含 `verify/` 或 `rb/` 顶层子目录 ⇒ `superseded`（P2#7：校验过即可删档）；
4. 含 `new/` 且报告称「首启判据未取得/未上机」 ⇒ `pending`，否则 `active`；
5. 有报告但无状态关键词 / 无报告 ⇒ 保守默认 `pending`（禁删，待人工归类）。
推断结果必须人工复核后入库（`--init` 不覆盖已有账本，`--force` 才重写）。

## 4. --check 三件事

① 每个 >200MB 的 out/ 一级目录必须在账本（缺 ⇒ FAIL）；② 状态词合法、依据非空、无重复条目；
③ `pending`/`active` 目录必须真实存在（不在盘 ⇒ FAIL，防「账本说禁删但已丢」）。
`out/` 不存在 ⇒ 整体 SKIP（WARN 行，照 §23/§24「不可核」口径，不算 PASS）。

## 5. --selftest 覆盖（合成树，稀疏文件不占盘）

三类坏件各重放一次、必须各被**恰好 1 条** FAIL 抓到：大件缺登记 / 非法状态词（`pendingx`）/ pending 目录失踪。

## 6. 三态验证（原始输出要点）

- `python3 scripts/out-status.py --check` 正常态：
  `账本 6 条（active 0 / verified 1 / superseded 4 / pending 1）；>200MB 目录 6 个、缺登记 0；禁删类失踪 0`，rc=0。
- 人为坏件：把 `out/min-restore-20261119` 改 `pending` 并移走目录 ⇒
  `[FAIL] out/min-restore-20261119 标 pending（禁删）但目录已不在盘 —— 账本与磁盘矛盾，先查是谁删的`，rc=1；复原后 rc=0。

## 7. 本轮账本内容（人工复核后定稿）

| 条目 | 状态 | 依据（摘要） |
|---|---|---|
| out/.work-rootfs-20261118 | superseded | rootfs 构建中间工作目录；成品 = min-restore（bigfile-verdict-20261120 B 档） |
| out/android-assets-20261119 | superseded | 报告行「…staging/ 812MB…可删；脚本会重建」（android-assets-20261119.md） |
| out/android-min-20261118 | superseded | 被 slim-v2b/v3 取代；无同名报告 |
| out/android-slim-v2b-20261119 | superseded | 含 verify//rb/ 校验副本（P2#7） |
| out/android-slim-v3-20261119 | **pending** | 唯一 final：EDL 写入读回一致但**首启判据未取得**（禁删，等上机） |
| out/min-restore-20261119 | **verified** | 在机恢复件（唯一含 /init 成品，LBA 73277435 sha abf96ec4… 一致） |

注：`active` 暂为 0 条属正常（当前无在役造件目录；<200MB 目录不强制入账，造大件时补）。

## 8. 后续维护口径（谁在造件时更新哪一行）

- **造件者**：产生新的 >200MB `out/<name>/` 时，同轮在 `versions/out-artifacts.tsv` 追加一行
  （状态 + 依据 + 报告指针 + 当日日期）；报告照 §23 同轮写。
- **上机验证后**：把该行 `pending` → `verified`（或 `active`），改依据、更新日期。
- **被新版本取代时**：旧行 → `superseded`，依据写「被 out/<新> 取代（reports/…）」。
- **删除前**：查本表；`pending`/`active` 行禁删，先改状态（附依据）再删；删后行保留
  （账本是历史账，§25 只对在账 pending/active 查存在性）。
- 门禁位置：`check-doctor` §25（`scripts/doctor/25-out-status.sh`，全量档 ~2 s）。
