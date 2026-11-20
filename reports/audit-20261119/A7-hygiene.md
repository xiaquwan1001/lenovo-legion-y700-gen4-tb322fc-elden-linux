# A7 — 项目卫生与门禁现状体检

审计代理: A7-hygiene / 生成时间: 2026-11-19 / 只读
（基线 commit `4542020e` 2026-11-19；全部外部命令套 `timeout -k 3`；未做任何写操作，仅创建本文件）

## 结论（先数字）

- **check-doctor 全量：FAIL=0 / WARN=7**（`--json` 实测）。7 条 WARN 全部为「不可核/已登记豁免」类，仅 1 条（§8 报告缺指针）属「5 分钟可修」。
- **progress-counts：G1 39 项（在册 37：✅33🟢3🟡1❌2）；G2 13 项（10 完成 3 部分）**；doctor §16 对账门 PASS，与 TASKS §0 无矛盾。
- **PITFALLS**：正文条目 243 个（95 个 sessions 文件），范围 #290–#685，**无真重号**；但区间内有 159 个空号 + #1–#289 全缺（旧条目以 `N. **` 行式存于旧文件，289 行）——编号不连续，归「需人工判」。
- **.pi/memory/**：7 文件共 352 KB；超 300 字条目 332 条（占多数），failures-kernel.md 单文件 199 KB —— 与全局纪律（条目 ≤300 字）偏差大，归「需人工判」。
- **docs-health（全局）**：1 FAIL + 2 WARN，**全部不属 elden 项目**（hw-stability 记忆超 50 KB、melodia/netease 死路径）。
- **recent-sessions vs INDEX §0：一致**（共存契约冻结 / v3 三发未进桌面且 2 发 BCB 污染 / 设备现居 Linux / 桌面已起），见下文第 5 节逐条对。

---

## 1. 门禁结果表

### 1.1 check-doctor.sh（全量，`timeout -k 3 300 bash scripts/check-doctor.sh`，退出码 0）

汇总（`--json`）：`{"fail":0,"warn":7,"profile":"full"}`，20 个子门全部执行。

| 子门 | 结果 | WARN 归类 |
|---|---|---|
| 04-retired / 05e-manifest / 05f-abi(门本身) / 06-hygiene / s07-08-docs / 09-sessions / 10-history / 11-hooks / 13-assets / 14-layout / 15-timeline / s16-tasks-counts / 17-shell-hygiene / 18-flashpkg-geometry / 19-slotattr-selftest / 20-rootfs-image / 21-write-precheck / 22-desktop-chain | PASS（22 号门含反作弊自检 5/5） | — |
| 05-vk §5d | warn ×4：①源树 geekidos-linux/ 不在盘 ⇒ 75 行内核身份暂不可核（已逐行登记 `versions/kernel-src-archive.tsv`）②账本例外 uts_dup（`vk-ledger-known-issues.tsv`）③4 个 posctrl boot 镜像载荷解不出（免于核对）④身份表降级一致（C=2） | 已登记豁免（①④）/ C 类存量（②③） |
| 05f §ABI | warn ×1：无内核树 .config ⇒ ABI 核对跳过（不可核；影响记录 `reports/disk-cleanup-20261119-validation-impact.md`） | C 类存量（随 2026-11-19 磁盘清理衍生，已登记） |
| s07-08-docs §8 | warn ×1：`reports/stale-cleanup-b-docs-20261119.md` 无人引用（grep 全仓仅命中其自身，已独立复核） | **本轮可修（5 分钟）** |
| 12-modular | warn ×1：无构建树（build/daily 不在盘）⇒ 模块化门禁跳过；同上影响记录 | C 类存量 |

WARN 分类合计：本轮可修 1 / 已登记豁免 2 / C 类存量 4。C 类根因同源：geekidos-linux 源树与 build 树不在盘（2026-11-19 清理），恢复入口 = `versions/layout.tsv` 注释。

### 1.2 check-progress-counts.sh --tsv

先读脚本头部确认纯只读输出（stdout 打表，无写文件），直接运行。实测输出：

```
G1: total 39 / cancelled 2 / in_scope 37 / complete 36 / partial 1  (✅33 🟢3 🟡1 ❌2)
G2: total 13 / cancelled 0 / in_scope 13 / complete 10 / partial 3  (✅7 🟢2 🎯1 🟡2 ⬜1)
```

doctor §16（TASKS §0 手写数字 ↔ 本脚本对账）PASS ⇒ 数字与 TASKS/README.md §0 一致。

## 2. PITFALLS/README.md 体检

结构：README = 纯索引（`grep -c '^---$'` = 1，仅一条分隔线），正文在 `sessions/*.md`（95 个文件，共 1,044,159 B）。

- **条目数**：`grep -h -o '^## #[0-9]*' sessions/*.md | wc -l` = 243 个 `## #NNN` 头（含 a/b/c 后缀变体，如 `#397a/b/c`、`#417a/b`、`#546b`）。
- **重号**：无真重号。初扫报 dup {397,399,417,546}，逐个核实均为同号字母后缀（`sessions/86-…md:6` `## #397a`、`sessions/88-…md:6` `## #399a`、`sessions/97-…md:6` `## #417a`、`sessions/177-…md:28` `## #546b`），符合「同文件编号沿用」惯例。
- **跳号**：范围 #290–#685 内缺 159 个号（如 337–343、359–371 段、381–396 段等）；#1–#289 在 sessions 无 `## #` 定义。README 头部已自述部分成因：`28 个 #NNN 的正文只在专题报告`（PITFALLS/README.md:11）；旧号以 `N. **★…**` 行式存在于旧 sessions 文件（`grep -rn '^[0-9]\+\. ' sessions/` = 289 行，例：`sessions/28-上游邮件通道.md:3` `257. **★通道选型…**`）——即旧条目确实用了「行首 N. 」格式，与新规（会被当条目定义）冲突，但 doctor §8 编号对账门 PASS，说明脚本已兼容此历史格式。**跳号总量 159 + 旧格式 289 行 ⇒ 需人工判**（见行动清单）。
- **索引↔正文漂移**：README 索引表含逐条目行（如 `| 371 | 电源键短按不熄屏… | 10-桌面Phosh.md |`，README.md:53）；抽查 `#371/#546` 引用均有正文对应（`#546` 见 `sessions/177-…md:14`）。未见死指针（doctor §13 资产路径门亦 PASS）。

## 3. .pi/memory/ 体检

| 文件 | 字节 | `^---$` 条目 | 超 300 字条目 | 最大条目 |
|---|---|---|---|---|
| failures-kernel.md | 199,110 | 346 | 195 | 947 |
| MEMORY.md | 48,183 | 68 | 53 | 2,198 |
| failures-device.md | 46,501 | 85 | 43 | 1,025 |
| notes-camera-waydroid.md | 32,868 | 41 | 35 | 1,224 |
| USER.md | 17,718 | 54 | 2 | 371 |
| notes-display.md | 4,087 | 0 | 1(整文件) | 2,851 |
| notes-migration.md | 3,921 | 6 | 3 | 650 |

- 7 文件共 352,388 B；**超 300 字条目 332 条**（按 `\n---\n` 切分统计）——与全局纪律「一条 ≤300 字，只写判据+处置+指针」偏差显著，尤其 MEMORY.md（均条目 ~700 B）与 notes-display.md（单块 2,851 B 无分隔）。
- **与 PITFALLS 重复**：未做逐条 diff（预算内未取证）；间接证据 = doctor §6 静态卫生与 2026-11-12 去重审计（`reports/pitfalls-dedup-audit-20261112.md`）均 PASS/已收口，但 2026-11-19 磁盘清理后新增的 build 树缺失类 WARN 未同步进 .pi/memory 判据（§1.1 C 类）。重复度定量：**未取证**。

## 4. 文档体检（docs-health）

入口：`scripts/` 下无等效脚本；全局入口 `~/.pi/agent/bin/docs-health`（python3 脚本，直接 bash 执行会报错——shebang 是 python3，需 `python3` 调用，本轮实测确认）。

实测（`python3 ~/.pi/agent/bin/docs-health -v`，覆盖 150 文档/16 项目）：

- **FAIL 1**：`hw-stability/.pi/memory/MEMORY.md` 62 KB > 50 KB —— 非 elden 项目（全局 AGENTS.md 已给该目录独立豁免入口）。
- **WARN 2**：`melodia/AGENTS.md:18`、`netease-mini-player/AGENTS.md:40` 死路径 —— 均非 elden。
- **elden 项目本体：0 FAIL / 0 WARN**（无未来日期、无死指针、无逐字重复段被标）。

## 5. recent-sessions.sh 3 vs INDEX.md §0 一致性

`bash scripts/recent-sessions.sh 3`（只读）结论：①2026-11-19T04-08 轮 = zero-to-desktop 8 步自检 + §22 门 + BACKLOG 本地项见底；②2026-11-19T11-20 轮 = 共存契约冻结 + v3 三发上机未进桌面（2 发 BCB 污染）+ 设备现居 Linux + 下轮 S1–S5 纪律；③当前轮 = 8 个只读审计子代理。

对照 `INDEX.md` §0（核对日期 2026-11-19，INDEX.md:8）：

| 会话结论 | INDEX §0 对应 | 一致 |
|---|---|---|
| 共存契约 super/userdata/linux17 区间、16 条目不重叠、rc=0 | §0 第 1 条（INDEX.md:12–14，数字逐字一致） | ✅ |
| v3 三发未进桌面、2 发 BCB 污染、`misc` BCB=`boot-recovery` | §0 第 1 条「上机 3 发均未进桌面，其中 2 发被 BCB 污染」+ logfs/pstoredump 证据链 | ✅ |
| 下轮纪律 清 BCB → qbootctl -a → … | §0 第 1 条「下轮纪律」逐条一致（S1–S5 顺序相同） | ✅ |
| 桌面起来（Phosh+GPU 渲染、glmark2 2594）、udev 真因、槽位 successful | §0 第 2/3 条（13:20 与下午条） | ✅ |
| 无冲突项 | — | ✅ |

## 6. 行动清单（三档）

**5 分钟可修（1 项）**
1. 给 `reports/stale-cleanup-b-docs-20261119.md` 补一处指针（在对应 README/TASKS 行加引用），消 doctor §8 的唯一「报告无人引用」WARN。

**需重排编号（0 项硬需求）**
- PITFALLS 无真重号、doctor 编号对账门 PASS ⇒ **不需要重排**；跳号 159 个属历史遗留（README 头部已声明「条目编号范围不写死」），若要补齐应走「新条目取最大号+1」而非回填。

**需人工判（3 项）**
1. PITFALLS 旧 sessions 文件 289 行 `N. **` 行式条目（#1–#289 无 `## #NNN` 定义）：是否迁移成 `## #NNN` 头或登记为「历史格式豁免」。
2. .pi/memory/ 332 条超 300 字条目（尤其 MEMORY.md、failures-kernel.md、notes-display.md 单块 2,851 B）：是否按 `bin/mem-split` 类工具拆域压缩；与 PITFALLS 的定量重复度需专项 diff 取证。
3. C 类存量 4 条 WARN 的恢复时机：geekidos-linux 源树 + build 树重建（入口 `versions/layout.tsv` 注释、`versions/kernel-src-archive.tsv`、`reports/disk-cleanup-20261119-validation-impact.md`）——重建后重跑 vk-identity.py 清降级表（注意项目规则：vk-identity.py 禁重跑需按其入口条件）。
