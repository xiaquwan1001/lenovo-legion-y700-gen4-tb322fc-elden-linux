# A4 文档审计汇总（2026-11-19）

> 结论先行：全仓文档审计共登记 **29 条**（含 4 条 KEEP/无问题基线），其中需动手的问题 **20 条**：
> 矛盾 4、死指针最多（跨 6 个文件 34 处引用位，收敛为 8 条）、未标作废的旧结论 2、重复段 3、体量 2、过期专题 2、孤儿报告 1。
> 无未来日期文档；check-doctor FAIL=0（WARN=7 均已登记豁免）。执行按三批走：批一零风险、批二需同步改引用、批三需人工确认，**本文只给模板不执行**。

---

## 1) 概述

**审计范围**（A4-docs-audit.tsv 覆盖的路径）：
顶层 `README.md`、`PROGRESS.md`、`INDEX.md`、`AGENTS.md`；`DEVICE/README.md`、`TASKS/README.md`、`RESOURCES/README.md`、`RUNBOOK-BRINGUP/{README.md, LINUX-STATE-REPRO.md, GPT-MINIMAL-DESIGN.md, f2fs-migration.md}`、`PITFALLS/README.md`、`SESSIONS/README.md`、`HISTORY/README.md`；专题抽查 `reports/`（索引过期与同主题滚动）、`archive/`（结构现状）、sessions 目录（体量）、未来日期全仓核查、check-doctor 自检基线。

**问题计数（与 tsv 逐行一致，类型可交叉时按主类型计）**：

| 类型 | 条数 | 涉及文件 |
|---|---|---|
| ①矛盾（与 §0/现态/自相矛盾） | 4 | README.md ×3、INDEX.md ×1 |
| ②死指针 | 8 | DEVICE、TASKS ×3、RESOURCES、RUNBOOK-BRINGUP ×3、PITFALLS、SESSIONS |
| ③未标作废的旧结论 / 作废标记核查 | 2（另有 f2fs-migration 已处理 = C类 KEEP） | INDEX.md、SESSIONS/README.md |
| ④重复段落 | 3 | README.md、AGENTS.md、RESOURCES/README.md |
| ⑤体量过大 | 2 | DEVICE/README.md、sessions 目录 |
| ⑥过期专题 | 2 | PROGRESS.md、reports/ |
| 孤儿报告 / 基线核查（—） | 8 | stale-cleanup-b-docs、全局基线、未来日期、HISTORY、archive、reports、REPORTS 索引、f2fs |
| **合计** | **29** | |

关键数字：未来日期 `.md`（-newermt 2026-11-20）= **0**；`reports-index.py --check` = **rc=1**（过期）；check-doctor = **FAIL=0 / WARN=7**；RESOURCES/README.md 死指针 **11 处** test -e 失败。

---

## 2) 归档目标目录设计

**archive/ 现状**（实测 `ls archive/`，**无 archive/README.md**）：12 个按日期的 `retired-*` 目录 + `topics/`（早期专题全文，`ls archive/topics | wc -l` 数十篇）+ `evidence/` + `plans-*`，追加式命名，与 INDEX §2「证据层」定位一致；TASKS/README 引用旧专题时省略 `archive/topics/` 前缀（见 §4）。

**归档目标沿用既有惯例**：`archive/<YYYY-MM-DD>-<主题>-retired/`，本轮建议 **`archive/2026-11-19-docs-audit-retired/`**（内部可再分 `contradicted/`、`superseded/` 子目录），并在目录内放一个 README.md 记「每件的作废原因 + 替代指针」——这正是现状里每个 retired-* 目录都有 README.md 的惯例。

**为什么这样分层**：
- archive/ 顶层只收「目录级归档」，单文件级小修（加作废抬头、改指针）**不进 archive**，就地 APPEND——与「文档只留一个入口、新内容就地写」的全局规则一致，避免为 3 行作废标注搞文件搬家。
- `topics/` 是专题全文层，只放「整篇被取代但仍有史料价值」的文件；`retired-*` 是退役层，放「已确认无人再读」的文件。两者用途不同，不混放。

**与现状衔接**：不新建平行体系；本轮所有 MERGE-INTO 的「源」都是**合并后变薄**的原文件（README.md 的已知问题表、RESOURCES 的 8 篇 asset 报告），只把被取代的**整篇**沉入新 retired 目录，原文件留一行指针。

**移动后需要改的指针**（移动即批二内容）：
- 指向 asset 报告的：`RESOURCES/README.md §3`（加「历史 asset 报告已归档至 archive/2026-11-19-docs-audit-retired/，现查 §3」）。
- 指向被合并段的：`INDEX.md §0` 第 10 条 doc-slim 行补 stale-cleanup-b-docs-20261119.md 指针（孤儿报告修复，顺手做）。
- 全仓 `rg` 复核一遍被移动文件名，确保 0 残留旧路径。

---

## 3) 三批执行顺序（模板，不执行）

**批一 · 零风险**（只加作废抬头/改指针/重跑机器索引，无删除无移动）：
```sh
# 1. 重跑报告索引（修 reports/README.md 过期）
timeout -k 3 60 python3 scripts/reports-index.py
# 2. 作废抬头模板（就地 sed 追加一行，示例 INDEX.md:208）
sed -i '208s/$/（2026-11-15 快照，已过时，现查 reports\/README.md）/' INDEX.md
# 3. 死指针标注模板（硬死件）
sed -i 's|`bake-vendor.sh`|`bake-vendor.sh`（件已删，见 versions/out-images-sha256-20261105.tsv 账）|' DEVICE/README.md
# 4. INDEX §0 补孤儿报告指针（手编一行）
# 5. 验证
timeout -k 3 60 bash scripts/check-doctor.sh
```
适用：tsv 中全部「APPEND-作废抬头 / KEEP+标注」项（README.md ×3、INDEX.md ×2、PROGRESS.md、INDEX:127、DEVICE 死指针、TASKS 裸名补全路径、RESOURCES 死指针标注）。

**批二 · 需同步改引用**（合并/移动后必须改指针，含 rg 复核）：
```sh
# 合并：README.md §4 已知问题表 -> TASKS/README.md §5，源留一行指针
# 合并：8 篇 asset 报告 -> RESOURCES/README.md §3，旧文件加「已被 §3 取代」一行
mv reports/asset-inventory-2026102x.md archive/2026-11-19-docs-audit-retired/superseded/
# 改指针后全仓复核
rg -n 'asset-inventory-2026102x' --glob '!archive/**'   # 期望：仅剩指针行
timeout -k 3 60 bash scripts/check-doctor.sh            # FAIL=0
```
适用：README→TASKS 合并、RESOURCES asset 报告归档、TASKS 已删脚本逐条标注、PITFALLS 补全路径。

**批三 · 需人工确认**（涉及判定性结论或大文件移动）：
```sh
# 人工判断后才动，每项先出 diff 给用户过目
# 1. AGENTS.md 与全局层的 3 段重复（跨仓改动）
# 2. DEVICE/README.md §1.1 拆「现态一段 + 沿革进 sessions」
# 3. LINUX-STATE-REPRO.md to-fastboot.sh vs PITFALLS #690 口径裁决
# 4. GPT-MINIMAL-DESIGN.md：gpt-minimal-build.py/linux-gpt-apply.sh 是被删还是从未提交
# 5. RUNBOOK-BRINGUP/README.md:13,403 死命令段整段作废
```

---

## 4) MERGE-INTO / ARCHIVE-TO 逐条清单

| 源 -> 目标 | 理由 | 批号 |
|---|---|---|
| README.md §4 已知问题表 -> TASKS/README.md §5（源留一行指针） | 两处维护同一结论文（Q28/Q32/Q24/#106），INDEX §0 已收口 | 批二 |
| AGENTS.md 3 段（发布CI/上游发信/记忆细则） -> 全局 ~/.pi/agent/AGENTS.md（项目侧只留差异） | 与全局层近逐字重复；跨仓改动 | 批三 |
| 8 篇 reports/asset-*-2026110x.md -> RESOURCES/README.md §3（旧文件 ARCHIVE-TO archive/2026-11-19-docs-audit-retired/superseded/） | 同主题滚动 5 版，结论互相覆盖无作废链 | 批二 |
| reports/stale-cleanup-b-docs-20261119.md -> INDEX.md §0 第 10 条补指针（APPEND，非移动） | check-doctor §13 孤儿报告 | 批一 |
| TASKS/README.md 9 个已删脚本名 -> 标注「已删，见 reports/script-cleanup-audit-20261112.md」或改指 archive/2026-11-06-retired-scripts/（原地改，非移动） | 读者按名找脚本落空 | 批二 |
| DEVICE/README.md §1.1 -> 拆「现态一段 + 沿革进 sessions」（本轮只登记） | 70 行四代口径叠写，易看漏压过链 | 批三 |
| RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md / GPT-MINIMAL-DESIGN.md 死命令段 -> 人工裁决后作废标注（原地） | 涉及上机操作与设备重建唯一入口 | 批三 |

## 5) 不建议归档的清单与理由

- **PROGRESS.md**：公开时间线允许滞后，顶部已有「以 INDEX §0 为准」，只建议补 11 月里程碑段，不归档。
- **SESSIONS/README.md**：冻结档案，SSOT 原则不改旧文件；死引用多带 `git show` 合法语境，仅在下次触碰时顺手标注。
- **HISTORY/README.md**：机器生成、抽检全对账通过（check-doctor §10 [ok]），无问题。
- **archive/ 整体**：结构规整、追加式、与证据层定位一致，KEEP，无需新目录。
- **reports/ 同主题旧版**：组内日期倒序天然沉底，不必逐篇加作废头；只重跑索引。
- **TASKS/README.md 省略 archive/topics/ 前缀的引用**：非死链（test -e 全过），低优先统一路径即可。
- **TASKS/sessions/ 等体量增长**：只增不改是既有规则，§0 摘结论已覆盖，KEEP。
- **f2fs-migration.md**：已有 2026-11-19 作废头（C 类确认），无需再动。
- **全局自检基线 / 未来日期核查**：FAIL=0、0 命中，无需动作。
