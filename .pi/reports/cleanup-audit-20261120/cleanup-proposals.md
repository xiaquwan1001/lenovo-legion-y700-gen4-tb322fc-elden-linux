# 文档/脚本清理提案 — 2026-11-20（只读）

生成日期 2026-11-20。依据：INDEX.md 文档地图、TASKS/README.md、PITFALLS/README.md、`reports/audit-20261119/A4-docs-audit.tsv`（基座，本轮逐条抽验）、`find`/`grep` 实测。

> 本轮已就地修掉 4 条（A4 批一）：见同目录 `todos-20261120.md` 表 #1–#7。下表为**剩余未修**项。

## (a) 重复叙述同一事实
| 路径:行 | 证据 | 建议动作 |
|---|---|---|
| `TASKS/README.md` §4 已知问题表 vs `INDEX.md` §0 | A4 已判：Q28/Q32/Q24/#106 两处维护同一结论文（`reports/audit-20261119/A4-docs-audit.tsv` 批二行） | 批二：README §4 表留一行指针到 INDEX §0（需改引用，等放行） |
| `reports/asset-*.md` 8 篇（20261023→20261112） | 同主题滚动 5 版互相覆盖、无作废链（A4 tsv） | 批二：按 A4 归档到 `archive/2026-11-19-docs-audit-retired/superseded/` |
| `TASKS/README.md:574` 头部自身列举 4 代 upstream-status 快照 | `reports/upstream-status-20261113.md`（现查）与 `-1105/-1029/-1027` 历史快照并存，头部已标过期 | 已有作废标注，**维持现状**（历史快照惯例合法）；不改 |
| `DEVICE/README.md:28/82/88` ★/★★/★★★ 三代口径叠写 | A4：时间序规则靠叠写实现，新读者易看漏压过链 | P2：§1.1 首条显式加「以下 ★ 均为历史」一句 |

## (b) 过时结论（与最新实测冲突）
| 路径:行 | 证据 | 建议动作 |
|---|---|---|
| `INDEX.md:215`「135 个报告只出现 1 次（2026-11-15 实测）」 | 现存 564 篇；**本轮已修**（补快照失效标注） | ✅ 已完成 |
| `README.md:19/60/88` 三处 2026-11-12/13 口径 | 与 INDEX §0 / DEVICE §1.1 冲突；**本轮已修** | ✅ 已完成（见 todos 表） |
| `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:330` 疑 `to-fastboot.sh` 死指针 | A4 条件判定「find 空则需作废」；实测 `ls scripts/to-fastboot.sh` **在盘** ⇒ 非死指针 | 不动；在 A4 台账旁记一条更正 |
| `.pi/AGENT-OPS.md:57-62`「唯一入口 = to-fastboot.sh」与 #690 口径 | `reports/stale-cleanup-b-docs-20261119.md` C1 称已改；抽验 `.pi/AGENT-OPS.md` 现文是否还写「sysrq-b 兜底」 | 疑似已修，见 (c) 复核注 |

## (c) 死指针（实测 MISSING）
| 路径:行 | 证据（命令） | 建议动作 |
|---|---|---|
| `DEVICE/README.md:168` `bake-vendor.sh` | `find . -name bake-vendor.sh -not -path './.git/*'` → 空 | 就地补「（件已删，账见 `versions/out-images-sha256-20261105.tsv`）」——批一模板已有，未列入本轮 |
| `DEVICE/README.md:373` `custom_vm.md` | 同上 find → 空 | 就地补「（AOSP 上游文档，不在仓）」 |
| `PITFALLS/sessions/24-Waydroid容器.md:4` `tools/wd-audio-test/` | `ls tools/wd-audio-test` → 无；实存 `scripts/wd-audio-test/`（A3 tsv 亦记 scripts/ 路径） | 就地改指 `scripts/wd-audio-test/` |
| `RUNBOOK-BRINGUP/README.md:13,403` `BRINGUP-NEW-TABLET*` | find → 空（A4 判死） | 批二：作废标注 |
| `TASKS/README.md` 9 个已删脚本裸名（build-locked-chain.sh、flash-recovery.sh 等） | A4：find 全空 | 批二：标「已删，见 reports/script-cleanup-audit-20261112.md」 |
| `RESOURCES/README.md` `docs/` 目录引用 | `ls docs` → 无此目录（A4） | 批二：删或改指 INDEX §2 |

## (d) 失效/待处置脚本
| 路径 | 证据 | 建议动作 |
|---|---|---|
| `scripts/wd-audio-test/Test{Audio,Codec,Record}.java` | A3 判 DELETE-CANDIDATE；**本轮复核发现 `TASKS/README.md:516` 与 `TASKS/sessions/2026-11-06-TASKS行077-C6.md:15` 按名引用** ⇒ 非零引用，A3 判定偏严 | 不删；与同目录 `ListCodecs.java` 一起列 KEEP-ARCHIVE（归档时同步改 2 处文档指针） |
| `reports/stale-cleanup-b-docs-20261119.md` 孤儿报告 | check-doctor §13 曾报无人引用 | ✅ 本轮已修（INDEX §0-10 补指针） |
| `scripts/__pycache__`、`tools/__pycache__`、`rootfs/debian/ime/__pycache__` | 2 个 .pyc 在盘（`find . -name '*.pyc' -not -path './.git/*'`），A6/A7 已判可再生产物 | 主会话放行后删（非本轮权限） |

## 抽验说明
A4 台账 29 条中抽验 6 条：4 条成立（已修或列上表）、1 条条件判定经复核为**非问题**（to-fastboot.sh 在盘）、1 条（TestAudio 零引用）**偏严需放宽**。其余 23 条未逐条复跑，采纳 A4 原判并标注来源。
