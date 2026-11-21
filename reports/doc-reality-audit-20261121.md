# 文档「与进度脱节」核实 + 收敛 — 2026-11-21

**任务**：核实文档层与最近 2–3 轮会话实测进度的脱节，逐项机器化核查后只改状态词/指针/下沉，不改语义。
**权重**：最近会话实测结论（`scripts/recent-sessions.sh 3`）> INDEX §0 > 其它 README（INDEX §2 时间序裁决）。

## 1. 机器化核查结果（命令 + 数字）

| 核查项 | 命令 | 结果 |
|---|---|---|
| 进度数字 vs §0 | `scripts/check-progress-counts.sh --tsv` | G1 39/2c → in-scope 37，✅33 🟢3 🟡1 ❌2；G2 13，✅7 🟢2 🎯1 🟡2 ⬜1 —— 与 TASKS §0/INDEX §0 一致 |
| 全量门 | `scripts/check-doctor.sh` | 修前 **FAIL=0 / WARN=6**（基线吻合）；修中一度 FAIL=1（§13 吃掉省略写法，见 §2-T8），修后复跑 **FAIL=0 / WARN=6**，6 条 WARN 全为既有 C 类（源树已档/账本例外/内核段不可读/身份表降级/无 .config/无构建树），本轮零新增 |
| 时间序 | `check-doctor --only 15` | ok：核对日期 2026-11-21，INDEX §0 与 DEVICE §1.1 均指 vk192 |
| 跨文档版本 | 同上（含 vk 矛盾检查） | FAIL=0 |
| 死指针扫描 | 批处理 python（scripts/reports/patches/out/versions/logs 路径逐个 `test -e`） | 修前 14 处未标缺失；修后**未标注缺失 = 0**（2 处为「清理记录行本身」属正常，见 §2-T9） |
| docs-health | `python3 ~/.pi/agent/bin/docs-health`（bash 直跑报语法错——该脚本必须用 python3 调） | **1 FAIL / 2 WARN**，全部在全局 `~/.pi/agent` 层，非本项目文档（见 §3） |
| 会话 vs 文档 | `scripts/recent-sessions.sh 3` + `git log -5` | §0 已含 11-20/21 全部实测结论（AVB 债了结、UEFI 路 A「有字没菜单」、ESP 落地、音频/马达已过、IME P3 未决、a 槽 H5 未做、dwc3 v10 已投、wl2868c 已进树）——**状态层面无脱节** |

## 2. 脱节/死指针清单（位置 / 证据 / 处置 / 是否已修）

| # | 位置 | 现态证据 | 处置 | 已修 |
|---|---|---|---|---|
| T1 | TASKS §4 131–201 行 2026-11-21 长增量块（~70 行） | 原文与 INDEX §0 大段重复 | 原文逐字下沉 `TASKS/sessions/2026-11-21-§4增量块下沉.md`（11 228 B，零删改），§4 留 9 条一行账 + 指针 | ✅ |
| T2 | TASKS L286（N1）`out/mu-memmap-20261115/uefi-preamblec1m-r1.img` | `test -e` 失败；删除记录 = `reports/disk-cleanup-20261116.md`（INDEX L228 同证） | 就地加「**目录已删**（2026-11-16 A 类清理 + 指针）」 | ✅ |
| T3 | TASKS L301（N2）`out/gunyah-73/` | 目录不存在；sha 账在 `reports/gunyah-73-port-20261112.md` §3 | 加「目录已删，sha 账留报告 §3」 | ✅ |
| T4 | TASKS L627（M6）`patches/upstream/m1-2026-10-14/0001` | 目录在、`0001` 截断名不存在；实际 = `0001-drm-msm-dsi-phy-program-PLL_SYSTEM_MUXES-on-the-firs.patch` | 改成完整文件名 | ✅ |
| T5 | TASKS L69 + DEVICE L186 `patches/0011` | 前缀简写；实际 = `patches/0011-q6apm-mi2s-start-graph-at-prepare.patch` | 改成完整文件名（两处） | ✅ |
| T6 | DEVICE L73/L108 `out/r21-sbstop-pc1/…` | 已删；sha 复核记录 = `reports/disk-cleanup-20261116.md` L78 | 两处加「已删 + sha 复核指针」 | ✅ |
| T7 | DEVICE L388 `logs/agent-logs-2026-10-02/` | 已删（体量估算示例行） | 加「（已删）曾 80 M/天」 | ✅ |
| T8 | INDEX L201 `out/p2-minbase-20261118/{rootfs…,boot…}.img` | 已 mv 到 `backup/out-history-20261121/p2-minbase-20261118/`（`versions/out-artifacts.tsv` 行 15，superseded） | 改为完整归档路径；中途省略写法「`…/`」被 doctor §13 拒 ⇒ 改回全路径，复跑 FAIL=0 | ✅ |
| T9 | INDEX L225 `logs/40-sent.txt` | 实际 = `patches/upstream/pstore-ram-initrd-overlap-20261116/logs/`（目录，含 40-sent.txt） | 指针改为真实目录 | ✅ |
| T10 | INDEX L228 `out/mu-memmap-20261115`（扫描仍报） | 该行**就是清理删除记录本身**（列被删目录），非失效引用 | 不改（改了反而破坏取证记录） | 留（正常） |
| T11 | TASKS L70 `logs/cam-bright-20261018/` | 已删，但同文件内 G1-26/G1-8 行的 MIGRATION-LOST 标法不一 | 不改语义；属 MIGRATION-LOST 旧日志（2026-10-17 迁移丢失，`versions/migration-gaps-2026-10-17.tsv` 账内） | 留（已账内） |

## 3. 修了 / 留了 / 证据不足

- **修了 9 条**（T1–T9）：全部是状态词/指针/下沉，零语义改动。复跑判据：`bash scripts/check-doctor.sh` → `FAIL=0 WARN=6`；死指针扫描未标注缺失 = 0。
- **留了 2 条**（T10、T11）：T10 = 清理记录本身；T11 = MIGRATION-LOST 旧账，标法不统一但事实已入 `versions/migration-gaps` 账，统一标法属纯格式收益，TODO(低优先)。
- **本项目文档未发现「状态落后于会话」的脱节**：INDEX §0 已覆盖 11-20/21 全部实测结论，核对日期 2026-11-21。
- **证据不足不猜**：用户说「有些地方和进度脱节」——机器化核查后，脱节集中在**死指针**（已修）而非状态数字；若用户另指具体条目，待指认后按同法核。
- **全局层（非本项目，不动）**：docs-health FAIL = `~/.pi/agent/memory/topics-pi-runtime.md` 51 KB > 50 KB（应 `bin/mem-split` 拆分）；WARN = `failures-fabric.md` 67 KB（已豁免登记）+ netease 项目死路径。TODO(需用户拍板是否本轮拆)。
- git：3 个文档 M + 1 个新 session 文件，未 commit（主会话提交纪律）。
