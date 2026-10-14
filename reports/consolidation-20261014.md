# 文档/代码整理与归档总结 — 2026-10-14

> 本轮任务：整理文档与代码 / 修订删减过时条目 / 减少重复登记（改引用）/ 重构自检代码 / 找出残缺会话 / 合并归档已完成子功能与 git 历史。
> 证据层：子代理原始审计/重构报告已存 `reports/lanes-20261014/`（`audit-dedup`/`audit-stale`/`audit-features` + 各 lane；nexavlinks 网关），编排者抽样复核。
> 状态：**已提交**（见文末「提交」节）。

---

## 0. 数字结论（先结论）

| 项 | 结果 |
|---|---|
| 自检 `check-doctor.sh` 墙钟 | **~110 s → 12.7 s**（快 8.7×）；输出除「死脚本已退役」一行外逐行一致（FAIL=0，WARN 7→6） |
| 去重改引用 | **20+ 处**跨文件重复登记收敛为指针（INDEX / RUNBOOK / DEVICE / RESOURCES / README / PROGRESS / PITFALLS / 三份 sessions/README） |
| 过时条目修订 | **5 处**硬过时修正（TASKS 慢启动/WCN、RESOURCES 会话计数、README PITFALLS 计数、PROGRESS 当前口径、HISTORY 提交账 445→447） |
| 残缺会话 | 171 个会话档案**结构齐全**（仅 2 个 junk 冒烟结论为占位）；**1 个缺档已定位**（Waydroid C10），**0 条无 jsonl 的墓碑行** |
| 悬空引用 | `PITFALLS #262` 被引用但未登记 → **已补登记**；编号范围 #1–#261 → **#1–#262** |
| 归档/退役 | 死脚本 `q28-cold-sample-loop.sh` → `archive/2026-10-14-retired-scripts/`；新增 `SESSIONS/COMPLETED-FEATURES.md` 合并账 |
| 自检全绿 | `check-doctor` FAIL=0/WARN=6、`check-sessions` ALL PASS、`gen-history --check` 一致（448=448） |
| 断链 | **0**（707 个 .md / 554 条相对链接全量检查） |

---

## 1. 自检代码重构（速率与流程）

- `scripts/check-doctor.sh` + `scripts/vk-identity.py`（子代理 lane `refactor-doctor`，编排者独立复跑验证）：
  - 根因：check-doctor 调用 `vk-identity.py --gate`（39 s）**与** `--check`（39 s）各做一次全量扫描；§5 的 vk 版本账又对 `out/` 108 个镜像逐个解压抽 UTS（~30 s）。
  - 改法：两次调用合并为一次（同时产出 gate 结论 + 新鲜度），共享镜像 UTS 解析。
  - 验证：改前/改后完整输出逐行 diff 仅差「`q28-cold-sample-loop.sh` 死脚本告警 → ok」一行（因该脚本本轮退役）；退出码语义不变。

## 2. 减少重复登记（改为引用）

按 SSOT 地图收敛，重复位置改为一句指针，数字/口径只在 SSOT 维护：

- **INDEX.md §3**：删去 Q28/Q24 当前口径、`boot_b=vk94`、C10 细节、模块化载荷/相机/上机纪律/内核分界线数字，全部改指针（TASKS §5 / DEVICE §1.1 / PITFALLS）。
- **RUNBOOK-BRINGUP/**（7 处）：容量值域、rootfs 归档规格、new-tablet 命名、零写盘 #92/#93、先查结论 #87、kexec 根因 → 各指 SSOT。
- **DEVICE/**（2 处）：AOSP 550 G、rootfs 3.44 GB/30852 项 → RESOURCES §2.2/§2.3。
- **RESOURCES/README.md**（5 处）：`.pi/sessions` 100 个 jsonl、`README.md §4` 118 条索引（已迁 SESSIONS）→ 指 SESSIONS §1。
- **根 README.md**：PITFALLS「170+ 条」删数字 → 指抬头编号范围。
- **PROGRESS.md**（5 处）：Q28/Q24 当前数字与状态 → 指 TASKS §5（保留时间线与「被推翻结论」的诚实记录）。
- **PITFALLS/sessions/README.md + TASKS/sessions/README.md + RESOURCES/sessions/README.md**：三份近逐字样板收敛为一行指针（标准见 INDEX §2 / AGENT-OPS §4）。
- **.pi/AGENT-OPS.md**：与家目录全局规范逐字重复的条目改为引用 `~/.pi/agent/AGENTS.md` / `STANDING.md`（一次正反判断、失败先复盘、汇报/时间盒）；`agents.maxConcurrent` **3 → 8**（与全局 `fabric.json` 实际值对齐，原描述过时）。

## 3. 过时 / 残缺条目修订

- `TASKS/README.md` §7：慢启动「~95 s…未定位」→ 已定位（WCN MHI 首探 91 s）+ 修复（`ATH12K=m` → `Run /init` 4.486 s）；「未决①」中「考虑移植 MHI 补丁」→ 标注**已并入基线**。
- `RESOURCES/README.md`：删陈旧计数 100/118（实际顶层 168 jsonl；索引已迁 SESSIONS）。
- `HISTORY/README.md`：总提交 445 → **448**、HEAD `e7dbcdd` → `265e77c`、日期表 10-14 17→20、docs 152→153、「其余 58 type」→ 97；`days/*.md` 已重生成（`gen-history --check` 一致）。
- `PITFALLS`：补登记 **#262**（方法学：跨时段比较显示结果必须同报坏发簇状态）。
- `SESSIONS/README.md` §0：加「快照统计未随 v2 重核」校正（「9 条墓碑行」实为 9 条重复 id 行；reference 34→35；主会话 jsonl 162→168）。
- 索引 `#262` 悬空引用消解。

## 4. 残缺会话 + 合并归档已完成子功能与 git 历史

- **新增 `SESSIONS/COMPLETED-FEATURES.md`**：15 行「已完成子功能合并账」，把 `结论 ↔ 会话档案 ↔ 关键提交（本仓库 hash 已核验，内核树 hash 另标）↔ 权威描述处` 并成一张表；收敛同一功能的分散描述，并标出**缺口**（Waydroid C10 无 §3 档案）。由 `SESSIONS/README.md` §6 指向。
- **残缺会话判据**：171 个档案字段齐全（仅 2 个 junk 冒烟为占位）；`.pi/sessions` 168 个 jsonl 无「无 assistant 回复」会话；`SESSIONS` §3 表 **0 条无 jsonl 的墓碑行**。
- **junk/superseded 处置**：12 junk + 5 superseded 行**表内保留作审计痕迹、不删**（§5 记为待批）；理由逐条见 `.pi/lanes/audit-features-20261014.md` §4。

## 5. 删除 / 归档总结

| 动作 | 对象 | 处置 |
|---|---|---|
| **归档** | `scripts/q28-cold-sample-loop.sh`（无活跃引用的死脚本） | `git mv` → `archive/2026-10-14-retired-scripts/`；`PITFALLS/sessions/15` §15.2 补登记 |
| **删除** | 无（本轮不删任何正文；过时内容一律改引用或标注） | — |
| **新增** | `SESSIONS/COMPLETED-FEATURES.md` | 已完成子功能合并账 |
| **保留** | 171 个会话档案、junk/superseded 行、PITFALLS 证据、`archive/` 全部 | 追加为主，不改写既有结论 |
| **提交** | 分 2 提交 | (1) `m1-73(baseline)`：上一轮未提交的 M1-7.3 机上验收 + 机器账；(2) 本整理轮（去重/过时/自检重构/归档）。子代理原始报告存 `reports/lanes-20261014/` |

## 6. 验证证据

- `bash scripts/check-doctor.sh` → `FAIL=0 WARN=6`（12.7 s）。
- `bash scripts/check-sessions.sh 5` → `ALL PASS`（§1/§2/§3 仍逐字节等于快照源）。
- `bash scripts/gen-history.sh --check` → 448 = 448 一致（生成时）。
- 全量相对链接检查：0 断链。
- 审计给的关键 file:line / commit hash 已由编排者独立复核（`git cat-file -e` 核验本仓库 hash 全在；内核树 hash 另标）。
