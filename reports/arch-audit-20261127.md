# 项目架构审计 — 2026-11-27（只读）

> **性质**：只读架构审计。**唯一写入 = 本文件**。未改任何 README/INDEX/TASKS/DEVICE/RESOURCES/脚本/配置，
> 未删/移任何文件，未 `git add`/`commit`（`git status --short` 见 §5.0）。
> **仓库**：`git rev-parse --show-toplevel` = `/home/xuqianhui/y700-elden`，`HEAD` = `e04f614b`，`du -sh .` = **50 G**，`git ls-files` = **7757**。
> **纪律**：每条结论 = 可复跑命令 + 原始数字；拿不准标「待确认」。命令一律套 `timeout -k 10`。
> 复跑清单见 §4；与既有 6 份审计的对账见 §3。

---

## 0. 基线校正（父会话给的背景里有 2 处与现查不符，先钉死）

| 项 | 父会话基线 | **现查真值** | 命令 |
|---|---|---|---|
| `git ls-files` | 7757 | **7757 ✓** | `timeout -k 60 300 git ls-files \| wc -l` |
| `.md` 件数 | 1356 | **2229（+873）**；磁盘 2516 | `timeout -k 60 120 git ls-files -z '*.md' \| tr '\0' '\n' \| wc -l`；`find . -name '*.md' \| wc -l` |
| `du -sh .` | 50 G | **50 G ✓** | `timeout -k 300 du -sh .` |
| check-doctor | FAIL=0 WARN=3 | **FAIL=0 WARN=3 ✓**（§5d 源树不可核 / 账本例外 / 身份表降级） | `timeout -k 600 bash scripts/check-doctor.sh` |
| docs-health | 0/0/154 文档/13 项目 | **0/0/154/13 ✓** | `~/.pi/agent/bin/docs-health --brief` |
| check-progress-counts | G1 36/37、G2 10/13 | **G1 36/37、G2 10/13 ✓** | `timeout -k 300 bash scripts/check-progress-counts.sh` |

> `.md` 的 1356 → 2229 是本轮**唯一被推翻的基线数字**。§2.6「154 vs 1356」这条问题的分母因此要改写为 **154 vs 2229**（结论方向不变，见 §1 的 A14）。

> ⚠️ **`check-doctor` 的 FAIL 数在本轮期间发生了变化**：开工时（19:0x）全量 `FAIL=0 WARN=3`；
> 收尾前复跑同一命令时 §14 已 **FAIL=1** —— 原因是并行会话在仓库根落了一个 8 字节文件 `=50KB`
> （`ls -la --time-style=full-iso '=50KB'` → `2026-11-26 19:38:21`）。`bash scripts/check-layout.sh` 现判
> `FAIL: 顶层条目未登记（versions/layout.tsv）：=50KB`，`bash scripts/check-doctor.sh --only 14` → `FAIL=1`。
> **结论：本轮基线（FAIL=0）只在 19:38 之前成立；当前树 FAIL=1。** 详见 §1 的 **A0** 与 §5.0。

---

## 1. 一页结论表

| ID | 问题 | 证据（命令 + 原始数字） | 判定 | 建议动作 | 归属 | 预估收益 |
|---|---|---|---|---|---|---|
| **A0** | ★ **当前树 `check-doctor` = FAIL=1（不是基线说的 0）** | `bash scripts/check-layout.sh` → `FAIL: 顶层条目未登记（versions/layout.tsv）：=50KB`（rc=1）；`bash scripts/check-doctor.sh --only 14` → `FAIL=1`；`ls -la --time-style=full-iso '=50KB'` → `8 B, 2026-11-26 19:38:21`。开工时全量 doctor 仍是 `FAIL=0 WARN=3` ⇒ **是本轮期间由并行会话落盘造成的新 FAIL** | **修（P0，1 秒）** | `rm -f '=50KB'`；随后复跑 `bash scripts/check-doctor.sh` 确认回到 `FAIL=0 WARN=3` | 父代理可执行 | 收尾门现在过不了；一条 `rm` 即恢复 |
| **A1** | 顶层布局**未登记**条目（A0 事故之外） | 19:0x 时 `bash scripts/check-layout.sh` → `PASS: 布局注册表一致（entries=46）`；`ls -1A \| wc -l` = 47 −`.git` = **46** ⇒ 注册表完整；集合差也全空。**19:38 后**因 A0 的 `=50KB` 变 FAIL（已单列 A0） | **豁免（门有效，无实质性未登记者）** | 不动作；清理 A0 的 `=50KB` 后即回 PASS | — | 无（现状健康） |
| **A2** | `layout.tsv` 的 `vcs` 列**无机器校验** | `git ls-files dl-cam \| wc -l` = **231**，而 `versions/layout.tsv` 写 `cache dl-cam/ ignore`；`check-layout.sh` 只校验 zone/path/重复/INDEX 渲染（源码 `:44-70`） ⇒ `vcs` 列是**装饰** | **修（P1）** | 给 `check-layout.sh` 加一条：`vcs=ignore` 的行必须 `git ls-files <path> \| wc -l` = 0；例外（`dl-cam/` 的 231 纳管源件）单列白名单 | 父代理可执行 | 关掉「台账说 ignore、实际 231 件入库」的口径裂缝（相机工作区是全仓唯一双态目录） |
| **A3** | `INDEX.md` §2 与 `layout.tsv` **人读面重复渲染** | `versions/layout.tsv` 中 `dl-cam/` **1 行**（zone=cache）；`INDEX.md:619`「工作区」行与 `:620`「缓存」行**都列了 `dl-cam/`** ⇒ 人读面 2 处 | **修（P2）** | 从 §2「工作区」行删 `dl-cam/`（归缓存区），保留「231 纳管源件」注 | 父代理可执行 | 消除「这个目录到底能不能删」的双答案 |
| **A4** | `.pi/` 内层**无登记处** | `.pi/README.md` 目录分工表登记 12 项；`ls .pi/` 实有 **18** 项 ⇒ 未登记 **6**：`tmp-tasks/ rambuild/ reports/ fabric/ fabric.json mcp.json`（`grep -c` 逐个 0 命中）；`check-layout.sh` 只扫顶层 | **修（P2）** | `.pi/README.md` 补 6 行（含 `fabric*` 标「已卸载遗留，待删」）；可选把登记表机器化（`.pi/layout.tsv`），否则会一直漂 | 父代理可执行 | 堵住「.pi 下随手建目录无人知」 |
| **A5** | 7 角度文件夹齐备性 | 7/7 有 `README.md`；6 有 `sessions/`（`TASKS/` 347、`PITFALLS/` 281、`SESSIONS/` 171、`RESOURCES/` 9、`DEVICE/` 4、`RUNBOOK-BRINGUP/` 1）；`HISTORY/` 用 `days/`（59 篇，`HISTORY/README.md:3` 已声明） | **豁免（齐备）** | 不动作 | — | 无 |
| **A6** | `sessions/` **无增量**（>30 天 = 早于 2026-10-28） | `SESSIONS/sessions` **171/171 全停**（最新 2026-10-23）；`RUNBOOK-BRINGUP/sessions` **1/1 停**（2026-10-19）；`PITFALLS` 80/281、`TASKS` 24/347、`DEVICE` 1/4、`RESOURCES` 1/9 | **豁免（SESSIONS 冻结是设计）／RUNBOOK 待裁定** | SESSIONS 的 171 篇是「2026-10-15 起冻结」的档案，不动；`RUNBOOK-BRINGUP/sessions` 只有 1 篇且 39 天无增量 ⇒ 建议并入 `README.md` 后删 `sessions/`（该角度也声明「`README.md` = 权威正文」） | 需用户裁定（RUNBOOK 曲线） | 少一个只有一篇的伪 `sessions/` 层 |
| **A7** | `scripts/` 清单 vs 文档引用 | 入口 **359**（`scripts/README.md` 359 行 = `python3 scripts/gen-scripts-index.py --check` → `OK … （359 个入口）`）；14 份活面文档命中 **161（44.8%）**，孤儿 **198**（`scripts/doctor/` 28 + `lib-*` 4 + **plain 166**）；死引用 **7 路径 / 12 处** | **修（P1）** | ①166 plain 孤儿按「退役头 / 补一行到角度 README→scripts/README / 保持私有」三分类，只对「已无调用点且不可重建」的加 RETIRED 头；②7 条死引用就地修（`PITFALLS/README.md:99` 的 `scripts/checkpatch.pl` 指内核树、`RESOURCES/README.md` 6 条 q28/envpass/sensor 脚本已不存在） | 父代理可执行 | 44.8% 的引用率意味着**一半脚本只能靠 `scripts/README.md` 找到**，而该索引是生成物、不是语义入口 |
| **A8** | **死脚本门已被生成索引自吞** | `python3 scripts/static-scan.py --tsv` → `DEAD	-`（空）；机制 = `static-scan.py:38` 的 `SELF_OUTPUT` 只排 `versions/scripts-inventory.tsv`，**没排 `scripts/README.md`**，而后者是 359 行的全量清单 ⇒ 每个脚本都「被引用」 | **修（P1，门级）** | `SELF_OUTPUT` 加 `scripts/README.md`（或把 `live` 判据改为「只认 14 份活面文档」，与 A7 同口径）。这是**门空转**，比没有门更糟 | 父代理可执行 | 恢复 `§6 dead` 的判别力；顺带让 `scripts-inventory.tsv` 的 `LIVE/HIST-ONLY` 不再恒真（现查 447 条里 441 LIVE / 6 HIST-ONLY） |
| **A9** | **packaging 镜像契约：重复数被低估 9×** | `sha256` 全量对比（§4 命令）→ packaging↔`scripts/`/`rootfs/persistent-overlay/` **同内容 28 对**（父会话记 3 对）；另 **13 组同名不同内容**（漂移），最大 `init` **380 行差异**（两份不同代的 `/init`）、`charge-watch.sh` 189、`q28-watchdog.sh` 52、`time-sync.sh` 43、`net-up.sh` 38、`ath12k-load.sh` 34 | **判定：应当长久重复 + 必须加一致性 gate** | 新增 `scripts/check-userland-mirror.sh`（三态退出码，形态见 §2.4 末） | 父代理可执行（建脚本）；**把 13 组漂移按「谁是权威」逐组裁定 = 需用户裁定** | 28 对重复本身合理（`files/` = 设备逐字快照，`scripts/` = 权威源），但**没有任何门**把两者绑在一起；13 组漂移里 `charge-watch/time-sync/net-up` 是已上线服务件 |
| **A10** | packaging 门**根本没接线** | `packaging/elden-userland/tools/verify.sh` 457 行有 A–F/H/H2/H3 八段，`grep -n "scripts/" verify.sh` = **0 命中**；`grep -n "elden-userland\|verify.sh" scripts/check-doctor.sh` = **0 命中** ⇒ 用户态固化门**不在任何 doctor 档位** | **修（P1）** | 把 `verify.sh --offline`（零写盘那档）挂成 doctor 新节 §31，只在 full 档；再让 §31 顺带跑 A9 的镜像门 | 父代理可执行 | `packaging/README.md` 明写「`scripts/` 是 `/usr/local/sbin` 权威副本」，而这句话**当前没有机器证据** |
| **A11** | 残留垃圾逐项 | `.pi/agents/*.bak-alias-1112` **24 个 / 100 K**（其中 **10/24 与现正文逐字相同**；全仓 `*.bak*` = **27**）；`.pi/tmp-tasks/` 3 件（tracked，**0 引用**）；`.pi/fabric.json` 688 B（**tracked**）+ `.pi/fabric/` 332 K（untracked 4 件）；`restore-259/` 20 K 2 件（README 自述缺件）；`probes/` 2.5 M 27 件（含 `.ko/.o/dsidump` 二进制）；`.pi/rambuild/` 1 件 | **混合（见 §2.5 逐项）** | 见 §2.5 表 | 24 个 bak **需用户裁定**（`.gitignore:394-396` 记「用户要求有意保留在盘」）；其余父代理可执行 | 见 §2.5 |
| **A12** | **`fabric.json` 三处活文档仍称「配置真值」** | `ls ~/.pi/agent/fabric.json` → **No such file**（fabric 已卸载）；但 `.pi/fabric.json` 仍 **tracked**，且 `.pi/AGENT-OPS.md:129`、`.pi/ORCHESTRATION.md:43`、`:137`、`.pi/CONCURRENCY.md:31` 仍写「配置真值 = `~/.pi/agent/fabric.json` + `.pi/fabric.json`」；`AGENTS.md:38` 已改口「fabric.json 已于 2026-11-21 随 fabric 卸载删除」⇒ **同一仓两套说法** | **修（P0，会误导 agent 去读一个不存在的文件）** | ①三处活文档改成「`~/.pi/agent/settings.json` 的 `subagents` 段 + `custom-providers.json`（与 `AGENTS.md:38` 同口径）」；②`git rm .pi/fabric.json` + `rm -rf .pi/fabric/`（均已无消费者） | 父代理可执行 | 删掉一个**已被自己文档宣布死亡却仍在盘上**的配置真源 |
| **A13** | `check-doctor` 覆盖（30 节 / 28 子门） | `check-doctor.sh --list` = **28** 子门；`grep section` 得 §4,5,5d,5e,5f,6,7,8,9,10,11,12,13,14,15,16,17,…,30 = **30 节**；fast 档 **17** 子门。`scripts/doctor/` 30 文件 = 28 在 `ALL` + `_lib.sh` + `ab-bench.sh`（后者是 2026-11-05 重构的 A/B 验收装置，故意不接线） | **豁免（结构健康）** | 无；`ab-bench.sh` 保留（`reports/script-audit-20261105.md:128` 有重跑说明） | — | 无 |
| **A14** | `docs-health` 覆盖面 = **1.1%** | 覆盖只到 `.pi/` 层：`~/.pi/agent/bin/docs-health:93-105` 的 `collect_docs` 只收 `AGENTS.md` + `.pi/*.md` + `.pi/memory/*.md` + `.pi/skills/*/SKILL.md` ⇒ 本项目 = 1+4+8+11 = **24 篇**，对 **2229** 份 tracked md = **1.1%**；领域层（INDEX/TASKS/PITFALLS/DEVICE/RESOURCES/RUNBOOK/reports/archive/SESSIONS/HISTORY，共 **2205 篇**）**0 覆盖** | **豁免（分工正确，非遗漏）** | 不建议扩大 docs-health（它是全局工具，管「agent 大脑层」）；领域层由仓内门兜（§7/§8/§13/§16/§30）。**但要在某处写明这条分工**，否则下轮还会被当成缺口重查 | 父代理可执行（补一行口径） | 省掉每轮重复的「154 vs 1300+」困惑 |
| **A15** | `check-doc-assets.sh` 白名单**有绕道风险（已实证）** | 扫描面只有 **36 份**文件（`default_files()` 硬编码：7 章 + `TASKS/dim/*.md` 25 + INDEX + DEVICE/README + PITFALLS/README + 最新 upstream-status）；`checked=703 missing=0 skipped=7`。**绕道 1（前缀 glob）**：`compgen -G "${tok}*"` 让任何「前缀存在」的 token 通过 —— 实测新建 `/tmp/doca_probe2.md` 写 `` `scripts/ch` ``/`` `reports/uefi` ``/`` `patches/0` `` → `checked=3 missing=0 PASS`。**绕道 2（白名单陈化）**：`scripts/doc-assets-allowlist.txt` 12 条实体里 **6 条已 0 引用**（`patches/config-before-fragment-…bak`、`patches/kernel-history/elden_vk53-hw/0019+0020`、`reports/vk152`、`scripts/q24-rebuild-arms.sh`、`reports/artifacts/uefi-20261107R39R40-p45/`、`…R21-hostdiag/`）。**绕道 3（覆盖面）**：`RESOURCES/README.md`（73 个资产 token）、`RUNBOOK-BRINGUP/README.md`（23）、`AGENTS.md`（12）**不在扫描面** | **修（P1，门级）** | ①前缀 glob 只对**目录型** token 生效（要求 `${tok}` 以 `/` 结尾才允许 `*` 匹配）；②白名单加「0 引用即 FAIL」的自检；③`default_files()` 补 `RESOURCES/README.md` + `RUNBOOK-BRINGUP/README.md` | 父代理可执行 | 门现在能过，但「过」不代表被引用的路径存在 |
| **A16** | `reports/` 被当垃圾场 | `reports/*.md` = **693** 篇 / **9.2 MB**（**注**：本审计期间并行 lane 又落了 2 篇，现查已 695；下同，凡 693 均为此快照）；整个 `reports/` = 4966 文件 / **2288.7 MB**，其中**未跟踪 1511 件 / 2155.9 MB**（`.gitignore` 里 `reports/artifacts/**` 相关规则 **173 条**，逐目录白名单式排除 ⇒ 新增 artifacts 目录默认入库）。**孤儿**：仅 **225/693（32.5%）** 被角度 `README` 引用；**468（67.5%）** 无角度 README 指针；连 `sessions/` 也算上仍剩 **59** | **修（P1）+ 部分豁免** | ①孤儿按「结论已被角度层吸收则标 `archived=` / 仍有独立价值则补一行指针」批处理；②`.gitignore` 的 173 条逐目录规则改为「`reports/artifacts/**` 整体 ignore + 显式 `!` 白名单 md」；③清理 `reports/artifacts/` 顶部 8 目录 ≈ 300 MB（`disk-audit-20261126.md` 的 D 项，未做） | 父代理可执行（①②③）；**②的入库边界改动前需用户确认** | 67.5% 无指针 = 违反 `.pi/AGENT-OPS.md:75` 的「报告必须被引用」 |
| **A17** | **`reports/README.md` 已过期且无门** | `python3 scripts/reports-index.py --check` → `reports/README.md 过期：重新跑 scripts/reports-index.py`，**rc=1**；文件自述「报告总数：633」，现查 **693**（快照；差 59–61 篇且仍在增）；`grep -rn reports-index scripts/*.sh scripts/doctor/* .githooks/*` = **0 命中** ⇒ 生成器**没有挂在任何门/钩子上**，与 `scripts/README.md`（有 §24 门）形成不对称 | **修（P1）** | 抄 §24 形态加一节 `31-reports-index.sh`（委托 `reports-index.py --check`，三态：0=ok / ≠0=FAIL / 缺 python3=SKIP），进 full 档 | 父代理可执行 | 「`reports/` 内部查全索引」目前是**唯一入口却指向 60 篇不存在的位置** |
| **A18** | 过程叙事**仍停在入口页** | `INDEX.md` §0「现在一页」= 行 9–504 = **496/718 行**、**98 966 B / 122 744 B = 80.6%**；对比 `TASKS/README.md` 6 402 B/54 行（拆分后已达标）、`AGENTS.md` 8 154 B/61 行（达标）；`PITFALLS/README.md` 191 810 B/409 行（索引本体，职责所在）；`TASKS/sessions` **291/347（83.9%）** 不被入口文档引用、**151** 全仓 0 引用（`scripts/doctor/s07-08-docs.py:73-75` 已声明 TASKS opt-out） | **修（P2）+ 豁免（TASKS opt-out 已声明）** | ①把 INDEX §0 的「晚间块/历史增量」按日期切到 `INDEX/sessions/` 或 `reports/`，§0 收敛到 ≤120 行；②TASKS opt-out 已是**明示口径**，不再当缺陷查 | 父代理可执行（①）；②免动 | §0 是每个会话必读面，80.6% 的内容是过程账 ⇒ 每轮开工的固定阅读税 |

> **判定汇总**：修 **P0 = 2**（**A0 的 `=50KB`**、A12）、**P1 = 8**（A2/A7/A8/A10/A15/A16/A17 + A9 的 gate 部分）、**P2 = 4**（A3/A4/A18 + A11 部分）、
> 豁免 **5**（A1/A5/A6/A13/A14 + A18 的 TASKS opt-out）。**需用户裁定 = 3 项**：A11 的 24 个 `.bak`（.gitignore 明示「有意保留」）、A9 的 13 组漂移「谁是权威」、A6 的 `RUNBOOK-BRINGUP/sessions` 存废。

---

## 2. 分节展开

### 2.1 顶层布局登记（A1–A4）

**现状数字**

```
$ timeout -k 10 120 bash scripts/check-layout.sh
PASS: 布局注册表一致（entries=46）        # ← 19:0x 的快照
# 19:38 之后同一命令变：FAIL: 顶层条目未登记（versions/layout.tsv）：=50KB   ← 见 A0

$ ls -1A | wc -l            # 47（19:0x 快照；=50KB 落盘后为 48）
$ timeout -k 120 bash scripts/check-layout.sh --list | wc -l   # 46
```

47 − `.git` = **46** = 注册表 46 ⇒ **未登记条目 = 0**（A0 的 `=50KB` 出现前）。反向集合差也为空：

```bash
ls -1A | sed 's#/$##' | LC_ALL=C sort > /tmp/disk_top.txt
bash scripts/check-layout.sh --list | awk '{print $2}' | sed 's#/$##' | LC_ALL=C sort -u > /tmp/reg.txt
LC_ALL=C comm -23 /tmp/disk_top.txt /tmp/reg.txt     # 未登记（输出应只有 .git）
LC_ALL=C comm -13 /tmp/disk_top.txt /tmp/reg.txt     # 登记但磁盘不存在（应为空）
```

**判据**：`versions/layout.tsv` 表头（`:3-5`）「根目录的**每个**顶层条目都必须在此登记（`.git` 除外）」；
门 = `scripts/check-layout.sh`（`:54-58` 反向遍历 `ls -A1`）＋ `check-doctor.sh` §14。

**判定**：**豁免（门有效，无未登记者）**。

**但台账有三处口径裂缝**（不是「未登记」，是「登记了但不自洽」）：

| # | 裂缝 | 证据 | 最小改法 |
|---|---|---|---|
| A2 | `vcs` 列无校验 | `git ls-files dl-cam \| wc -l` = **231** ≠ `vcs=ignore`；`check-layout.sh` 全文件无 `git ls-files` 调用 | `check-layout.sh` 加：`vcs=ignore` 行 ⇒ `git ls-files <dir>` 必须为 0，例外列白名单 |
| A3 | INDEX 人读面重复渲染 | `INDEX.md:619`（工作区行）与 `:620`（缓存行）都出现 `` `dl-cam/` ``；注册表只 1 行 | 从工作区行删掉 |
| A4 | `.pi/` 内层无登记 | `.pi/README.md` 表 12 项 vs `ls .pi/` 18 项 ⇒ 缺 `tmp-tasks/ rambuild/ reports/ fabric/ fabric.json mcp.json` | 补 6 行；`fabric*` 标「遗留待删」 |

> `.pi/` 内层这一层没有任何机器门（`check-layout.sh` 只看顶层），是「先加行再落盘」纪律唯一没有门的地方。

---

### 2.2 七个角度文件夹齐备性（A5–A6）

```
$ for d in DEVICE TASKS RESOURCES RUNBOOK-BRINGUP PITFALLS SESSIONS HISTORY; do
    printf "%-16s README=%s md=%s size=%s\n" $d ... ; done
DEVICE             README=Y sessions=4    md=  6 size=140K  newest=2026-11-26
TASKS              README=Y sessions=347  md=379 size=2.6M  newest=2026-11-26
RESOURCES          README=Y sessions=9    md= 10 size=164K  newest=2026-11-26
RUNBOOK-BRINGUP    README=Y sessions=1    md=  6 size=128K  newest=2026-11-24
PITFALLS           README=Y sessions=281  md=282 size=1.9M  newest=2026-11-26
SESSIONS           README=Y sessions=171  md=173 size=792K  newest=2026-11-13
HISTORY            README=Y sessions=NO   md= 60 size=328K  newest=2026-11-26
```

**齐备性：7/7 有 `README.md`（策展 SSOT）；6/7 有 `sessions/`；`HISTORY` 用 `days/`（59 篇）**，
后者是设计而非缺口 —— `HISTORY/README.md:3` 明写「`days/*.md`（`scripts/gen-history.sh` 机械生成）是逐提交的权威视图」。

**体积排行**（`du -sh`）：`TASKS` 2.6 M > `PITFALLS` 1.9 M > `SESSIONS` 792 K > `HISTORY` 328 K > `RESOURCES` 164 K > `DEVICE` 140 K > `RUNBOOK-BRINGUP` 128 K。
`TASKS`（379 md）已超过 `PITFALLS`（282 md）成为最大角度 —— 与 `TASKS/README.md` 自设的「本文件目标 < 20 KB」并不矛盾（正文已下沉到 6 个章节文件 + `dim/D##.md`），但**会话文件数** 347 是全仓之最。

**>30 天无新文件**（截止 2026-10-28，`find <dir>/sessions -name '*.md' ! -newermt 2026-10-28`）：

| 角度 | 停摆/总数 | 最新一件 |
|---|---|---|
| `SESSIONS/sessions` | **171 / 171 = 100%** | 2026-10-23 |
| `RUNBOOK-BRINGUP/sessions` | **1 / 1 = 100%** | 2026-10-19 |
| `PITFALLS/sessions` | 80 / 281 = 28.5% | 2026-11-26 |
| `TASKS/sessions` | 24 / 347 = 6.9% | 2026-11-26 |
| `DEVICE/sessions` | 1 / 4 = 25% | 2026-11-19 |
| `RESOURCES/sessions` | 1 / 9 = 11% | 2026-11-05 |
| `HISTORY/days` | 1 / 59 | 2026-11-26 |

**判定**：`SESSIONS` **豁免**（`versions/layout.tsv` 记「2026-10-15 起冻结，只读」）；`RUNBOOK-BRINGUP` **待裁定** —— 该角度只有 1 篇会话且 39 天无增量，而 `INDEX.md` §2 已把 `README.md` 定为权威正文，`sessions/` 层在这里是空壳。

---

### 2.3 `scripts/` 清单 vs 文档引用（A7–A8）

**工具侧（原样引用）**

```
$ ~/.pi/agent/bin/proj-audit /home/xuqianhui/y700-elden --only tool,junk,danger --quiet
WARN danger-pattern  ×42（远端命令未套 timeout（规则 3/14）/ pkill -f 自匹配 / --no-verify）
WARN junk            repo   200 个备份/临时件，例: wt/fastrpc-sensorspd-test/…/*.dtb.d.dtc.tmp
---- /home/xuqianhui/y700-elden
FAIL=0 WARN=43 INFO=486
```

> **口语化修正**：本轮先后跑出 `WARN=45` 与 `WARN=43` 两个快照，差额 2 条是 `tool-undocumented tools/uinput-{back,touch}-build.sh`
> （单独跑 `--only tool` 又变 `PASS：没有发现工具链/文档问题`）⇒ 该子判据**在 combo 模式下不稳定**，标「待确认」，不计入任何结论。
> `danger-pattern` 的 42 条集中在「远端命令未套 timeout」与「`pkill -f` 自匹配」，与 `scripts/check-shell-hygiene.py` 的 §17 门重叠（§17 现状全绿）⇒ 两门口径不同，非新问题。

**自复算（口径 = 父会话指定的 14 份活面文档）**

活面文档集 = `INDEX.md` `AGENTS.md` `PITFALLS/README.md` `reports/README.md` + `TASKS/*.md`(7) + `DEVICE/*.md`(2) + `RESOURCES/*.md`(1) = **14 份**。

| 指标 | 数字 | 命令 |
|---|---|---|
| `scripts/` 可执行入口 | **359** | `python3 scripts/gen-scripts-index.py --check` → `OK … （359 个入口）` |
| `scripts/` 目录文件总数 | **439**（281 `.sh` + 72 `.py` + 66 `.pyc` + 4 `.java` + 4 `.conf` + 3 `.c` + 杂项） | `find scripts -type f \| wc -l` |
| `.pyc` 是否入库 | **否**（0 tracked；`.gitignore:107 __pycache__/`） | `git ls-files 'scripts/__pycache__' \| wc -l` = 0 |
| 被活面文档引用 | **161（44.8%）** | §4 命令 |
| 孤儿 | **198** = `scripts/doctor/` **28** + `lib-*` **4** + **plain 166** | §4 命令 |
| 死引用（文档提到、文件不存在） | **7 个唯一路径 / 12 处** | §4 命令 |

**死引用清单（全 7 条）**

| 路径 | 出现处 | 判定 |
|---|---|---|
| `scripts/checkpatch.pl` | `PITFALLS/README.md:99` | **误报级**：正文指的是**内核树**的 `scripts/checkpatch.pl`（`build/…/scripts/`），不是本仓 `scripts/`；建议改成 `build/vk151/scripts/checkpatch.pl` 全路径 |
| `scripts/envpass-provision.sh` | `RESOURCES/README.md`、`TASKS/G2.md` | **真死**（2026-10-17 换机未随迁） |
| `scripts/q28-ab-delay.sh` | `RESOURCES/README.md` ×2 | **真死** |
| `scripts/q28-boot-cycle.sh` | `RESOURCES/README.md` ×2 | **真死**（现役 = `scripts/q28-reboot-until-good.sh`） |
| `scripts/q28-race-hunt.sh` | `RESOURCES/README.md` ×2 | **真死** |
| `scripts/q28-verdict.sh` | `RESOURCES/README.md` ×2 | **真死** |
| `scripts/sensor-send-termux.sh` | `RESOURCES/README.md`、`TASKS/ANDROID-COMPAT.md`、`TASKS/G2.md` | **真死** |

> `check-doc-assets.sh` 本应抓这 7 条，但 `RESOURCES/README.md` **不在它的扫描面**（见 A15），且这 7 条都以脚本名而非反引号资产 token 出现。

**孤儿前 30（按行数降序；plain 类共 166）**

| 行数 | 脚本 | 行数 | 脚本 | 行数 | 脚本 |
|---|---|---|---|---|---|
| 600 | `gpt-preflight.py` | 260 | `asset-install-linux.sh` | 200 | `charge-watch.sh` |
| 538 | `android-super.py` | 255 | `bisect/eldtest.sh` | 199 | `suspend-boot-panic-capture.sh` |
| 394 | `android-assets-extract-20261119.py` | 238 | `host-mem-build-stress.sh` | 198 | `mailbox-quota-reclaim-20261125.py` |
| 332 | `mailbox-cleanup-20261102.py` | 233 | `android-super-scan.py` | 196 | `rebuild-vk64-image.sh` |
| 331 | `uefi-r21-sbstop-ladder.sh` | 230 | `dump-verdict.py` | 190 | `q32-arm.sh` |
| 312 | `android-lpdump.py` | 218 | `autotest-cycle.sh` | 190 | `b5-u2-atomic-timeline.sh` |
| 293 | `out-candidate-sha.py` | 215 | `ffs-extract.py` | 181 | `q32-boot-evidence.sh` |
| 283 | `esp-apply.sh` | 213 | `check-modular-config.sh` | 176 | `driver-snapshot.sh` |
| 275 | `android-ksu-avb-build.py` | 203 | `n7-vk127-camera-blank.sh` | 174 | `verify-tree-integrity.py` |
| | | | | 169 | `switch-kernel-abi.sh` |
| | | | | 168 | `uefi-grubcfg-arming.sh` |
| | | | | 168 | `deploy-modules.sh` |

（其余 136 个 plain 孤儿可用 §4 命令一键重列；完整清单落 `/tmp/orph_final.txt`，非本仓产物。）

**`scripts/doctor/` 的 28 个「孤儿」是假阳性**：它们由 `check-doctor.sh` 的 `ALL=` 变量按**路径**调用（`check-doctor.sh:130`），不是文档引用关系。同理 `lib-*` 4 个是被 `source` 的。**真正的 plain 孤儿 = 166**。

**判定**：**修（P1）**。但**先修门再清脚本** —— 见 A8：`static-scan.py --tsv` 现在是 `DEAD	-`（空集），因为：

```
$ grep -n "SELF_OUTPUT" scripts/static-scan.py
38:SELF_OUTPUT = ('versions/scripts-inventory.tsv',)
59:    return sorted(set(files) - set(SELF_OUTPUT))
$ grep -c "abl-log" scripts/README.md
1      # `scripts/abl-log.sh` 在生成索引里 → 被判「已被引用」
```

`scripts/README.md` 是 359 行的**全量清单**且 `.md` 在语料里 ⇒ 每个脚本都至少被它「引用」一次 ⇒ `dead_scripts()` 恒返回空。**这是一个已经空转的门**（`scripts/check-doctor.sh:24` 声称 §6 管「死脚本」）。

---

### 2.4 packaging 镜像契约（A9–A10）

**同内容重复 = 28 对（父会话记 3 对，实为 28）**

口径：`packaging/elden-userland/files/**` + `packaging/keyboard-settings/files/**` 与 `scripts/**` + `rootfs/persistent-overlay/**` 做 `sha256` 全配对。命令见 §4。

| 分区 | 对数 | 例 |
|---|---|---|
| `files/` ↔ `scripts/` | **20** | `usr/local/sbin/start-desktop.sh`↔`scripts/start-desktop.sh`（父会话已知）；`usr/local/bin/eldroid-bootctl`↔`scripts/eldroid-bootctl`；`net-selfheal.sh`；`wifi-scan-refresh.sh`；`audio-alsa-init.sh`；`charge-ctl.sh`；`99-unmanaged.conf`；`kmsgspy.sh` … |
| `files/` ↔ `rootfs/persistent-overlay/` | **8** | `etc/init.d/greetd`↔`etc-initd-greetd`；`etc/init.d/elden-hapticd`↔`elden-hapticd.initd`；`etc/conf.d/backlight-floor`↔`etc-conf.d-backlight-floor`；`init`↔`init`（**内容不同**，见下）… |

**同名不同内容 = 13 组（这是真正的风险面）**

| 文件 | `packaging/files/…` sha | `scripts/` 或 `rootfs/` sha | `diff -u \| grep -c '^[+-]'` |
|---|---|---|---|
| `charge-watch.sh` | `4a8870f2de` | `257b0125fa` | **189 行** |
| `q28-boot-watchdog.sh` | `a85ec07ac0` | `709e9eb86c`(rootfs) | 20 |
| `q28-watchdog.sh` | `1149f75c50` | `7ad0c823a0` | 52 |
| `time-sync.sh` | `f82f3bf406` | `c5736ac00a` | 43 |
| `net-up.sh` | `c5d4dc3500` | `4dad8ea5ef` | 38 |
| `ath12k-load.sh` | `37ca2ec077` | `8086e6a892` | 34 |
| `scale.sh` | `56fce08546` | `244da69b3c` | 10 |
| `sleep-bisect.sh` | `0f60886060` | `92e995af52` | 9 |
| `sleep-cumulative.sh` | `e1cebe181b` | `53323d290b` | 8 |
| `openrc-enable.sh` | `c89433b3aa` | `deb55ceb3a` | 8 |
| `camera-modules-load.sh` | `d1b0a9ebf8` | `e2264abfe5` | 3 |
| `init` | `47af5f7d54` | `073253e54d`(rootfs) | **380 行**（两份不同代的 `/init`，风险最高的漂移） |
| `slot-attr.py` | `2b004355f9`（`/usr/local/{bin,sbin}` **两份同 sha**，packaging 内部自重复） | `a9bd30ed1b`(scripts) | 25 |

**这是「应当长久的重复」还是「应加 gate」？**

**判定：两者皆是，但当前只做对了一半。**

- **重复本身必须长久**：`packaging/elden-userland/README.md` §设计第 2 条明确 —— `files/` = **逐字采自设备**（`tools/sync-from-device.sh` 写入，`禁止手改`，sha256 比对），`scripts/` = **权威副本**。两者**语义不同**（一个是「设备上现在是什么」的快照，一个是「我们打算装什么」的源）。把它们合并成一份会毁掉「设备漂移可被检出」这条能力。
- **但没有任何一致性 gate**：`tools/verify.sh` 457 行、A–H 八段，`grep -n "scripts/" verify.sh` = **0 命中**；`grep -n "elden-userland" scripts/check-doctor.sh` = **0 命中**。⇒ `README.md` 里「`scripts/` 是 `/usr/local/sbin` 权威副本」这句话**目前是纯口述**。
- **13 组漂移说明它已经在漂**：`init` **380 行**（两份不同代的 `/init` —— 装错即起不来）、`charge-watch.sh` 189 行、`q28-watchdog.sh` 52 行、`time-sync.sh` 43 行、`net-up.sh` 38 行，都是已上线件；**漂移方向未知**（不知道设备上现在跑的是哪一份）。

**gate 的可行形态（不实现，只给形态）**

```
脚本：scripts/check-userland-mirror.sh
判据：
  A. 对 packaging/elden-userland/MANIFEST.tsv 每一行，取 repo_src 的 sha256，
     与「同名文件在 scripts/ 或 rootfs/persistent-overlay/ 里的副本」逐一比对：
       - 存在同 sha 副本  → OK（可配对，须登记进配对表）
       - 存在同名不同 sha → DRIFT（打印 diff 行数 + 谁的 mtime 更新）
       - 无任何同名副本   → UNPAIRED（仍是合法状态：设备专有件）
  B. 配对表 packaging/elden-userland/mirror.tsv（人工维护，每行 dst<TAB>authority<TAB>理由）
     用来把「允许漂移」的 13 组显式化；表里没有的漂移一律 FAIL。
  C. 反作弊：临时把某个已配对文件的副本改一个字节 ⇒ 必须 FAIL（防门空转）。
退出码（三态，与 check-doctor 契约一致）：
  0 = 全部配对/已豁免；1 = 存在未登记漂移或配对缺失；
  2 = SKIP（packaging/ 或 MANIFEST.tsv 缺失、缺 sha256sum）—— SKIP 不得计成 PASS。
接线：scripts/doctor/31-userland-mirror.sh，只进 full 档（~0.3 s，纯 sha 比对）。
```

**为什么不是「删除重复」**：删掉 `scripts/` 侧的 `start-desktop.sh` 等 20 个副本，会让「重新打包到新 rootfs」失去源（`files/` 是设备快照，禁止手改）；删掉 `files/` 侧则失去漂移检出力。**正确形态 = 保留两份 + 一张权威配对表 + 一个三态门。**

---

### 2.5 残留垃圾逐项判定（A11）

| 对象 | 现查数字 | 命令 | 判定 | 依据/建议 |
|---|---|---|---|---|
| `.pi/agents/*.bak-alias-1112` | **24 个 / 100 K**；其中 **10/24 与现正文 `diff` 为空**，14 个有差异；**全部 untracked** | `ls .pi/agents/*.bak-alias-1112 \| wc -l`；`for f in …; do diff -q "$cur" "$f"; done` | **待裁定（用户明示保留）** | `.gitignore:394-396`：「2026-11-13：`.pi/**` 的模型别名改写留了逐文件备份（`*.bak-alias-1112`，用户要求**有意保留在盘**）」⇒ 不是遗漏，是决定。可执行的最小动作 = **删掉 10 个与现正文逐字相同的**（零信息损失），保留 14 个有差异的 |
| 全仓 `*.bak*` | **27 个** = 24 个 agent bak + `initramfs/init.bak{,-beforedbus}-20260930` + `bootslot-b/boot_b.bak-20261123-740d431b.img` | `find . \( -path ./.git … \) -prune -o -type f -name '*.bak*' -print \| wc -l` | **豁免** | 与 `repo-slim-audit-20261113.md:167` 记的 29 个相比已减 2（`.pi/{AGENT-OPS,ORCHESTRATION}.md.bak-alias-1112` 已消）⇒ 已在收敛 |
| `.pi/tmp-tasks/` | **3 件 / 20 K，全部 tracked，全仓 0 引用**（`grep -rn tmp-tasks` 排除 reports/wt = 0 命中） | `ls .pi/tmp-tasks`；`git ls-files .pi/tmp-tasks \| wc -l` | **修（P2）** | 内容 = 2026-11-05 三个 lane 的任务卡（`integrity.md`/`outarchive.md`/`ssot3.md`）；lane 早已收口 ⇒ `git mv` 到 `archive/2026-11-05-lane-taskcards/`（保留可追溯），或直接 `git rm` |
| `.pi/fabric.json` | **688 B，tracked**；`~/.pi/agent/fabric.json` **不存在**；4 处活文档仍称其为「配置真值」 | `git ls-files .pi/fabric.json`；`ls ~/.pi/agent/fabric.json` | **修（P0，= A12）** | fabric 插件已卸载（`AGENTS.md:38` 自己宣布 2026-11-21 删除），文件却还在且被 4 处引用 ⇒ 下个会话会去读一个死配置 |
| `.pi/fabric/` | **332 K / 4 件，untracked**（`mcp-cache.json` + `mesh/`） | `find .pi/fabric -type f \| wc -l` | **修（P2）** | 卸载遗留的运行时缓存，`rm -rf` 即可（不在 `.gitignore` 白名单外，也不被任何文档引用） |
| `.pi/mcp.json` | 37 B，tracked，0 引用 | `cat .pi/mcp.json`；`grep -rn mcp.json --include=*.md .` = 0 | **待裁定** | 内容 = `{"coolapk":{"enabled":true}}`，是**唯一的 MCP 开关**（不是垃圾），但 `.pi/README.md` 未登记 ⇒ 归 A4 补登记，不删 |
| `restore-259/` | **20 K / 2 件**（`README.md` + `AVB-KSU-2026-09-29.md`）；README 自述「重签包/ KSU/ _zips/ 全部不在盘上」 | `find restore-259 -type f` | **豁免（自述完整）** | 注册为 `src`「恢复说明（二进制不入库）」；缺件已在 README 顶部红字声明并给了等价替代路径（官方 259 包 + `scripts/android-ksu-avb-build.py`）⇒ 保留有史料价值，**不需要动** |
| `probes/` | **2.5 M / 27 件**，含二进制 `blackbox.ko`、`q28latch.ko`/`dsidump`、`.module-common.o`（构建中间产物） | `find probes -type f \| wc -l`；`du -sh probes` | **修（P2，只清中间产物）** | 注册为 `src`「设备侧诊断探针源码」⇒ 探针本体保留；`.module-common.o` 这类构建中间物应进 `.gitignore` |
| `.pi/rambuild/` | 1 件 8 K，tracked，表头是 `# name<TAB>base<TAB>path<TAB>created` | `ls .pi/rambuild` | **待裁定** | 未登记于 `.pi/README.md`；内容像一次性记录 ⇒ 补登记或挪 `archive/` |
| `.pi/reports/` | **11 tracked = 11 件在盘**，112 K（`cleanup-20261119.md` + `disk-audit-2026-11-15.md` + `cleanup-audit-20261120/` 下 9 篇） | `git ls-files .pi/reports \| wc -l`；`find .pi/reports -type f \| wc -l` | **待裁定** | 内容 = 2026-11-19/20 两轮清理的中间产物（含 `cleanup-proposals.md`、`deadcode.md`、`todos-20261120.md`）；是否仍有价值需人判 ⇒ 要么移进 `reports/`（进正式证据层），要么挪 `archive/`；现在它两头都不在 |
| `.pi/sessions/` | **1018 件 / 1.1 G**，0 tracked（`ignore`） | `find .pi/sessions -type f \| wc -l` | **豁免（工作数据）** | `disk-audit-20261126.md` 的 C 项（gzip 可回收 ~0.45 G），需先验工具兼容性，**本轮不动** |

**汇总**：垃圾面真正「可删且无争议」的 = `.pi/tmp-tasks`(3) + `.pi/fabric/`(4) + `.pi/fabric.json`(1) + `probes/*.o`(1) ≈ **9 件 / ~350 K**。
「需用户裁定」= 24 个 `.bak-alias-1112`（其中 10 个可零风险删）。

---

### 2.6 工具接线（A13–A15、A17）

**`check-doctor.sh` 覆盖**

```
$ timeout -k 60 bash scripts/check-doctor.sh --list | wc -l        # 28 子门
$ … | grep -c 'full+fast'                                          # 17 进 fast 档
§ 节号 = 4,5,5d,5e,5f,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30   # 30 节
```

30 节 ↔ 28 子门的差 = `05-vk.sh` 一次出 §5+§5d、`s07-08-docs.py` 一次出 §7+§8。**结构健康**。

`scripts/doctor/` 目录 = **30 文件**：28 在 `ALL` + `_lib.sh`（公共库）+ `ab-bench.sh`（2026-11-05 重构的 A/B 验收装置，故意不接线，`reports/script-audit-20261105.md:128` 给了重跑命令）。

**文档体检面**

| 门 | 覆盖面 | 现查 |
|---|---|---|
| `~/.pi/agent/bin/docs-health` | 只 `.pi/` 层（`AGENTS.md` + `.pi/*.md` + `.pi/memory/*.md` + `.pi/skills/*/SKILL.md`） | 本项目 **24/2229 = 1.1%**；`0 FAIL / 0 WARN / 154 文档 / 13 项目` |
| `scripts/doctor/s07-08-docs.py` | 入口文档围栏/截断 + §8 索引↔磁盘 | `FAIL=0 WARN=0` |
| `scripts/check-doc-assets.sh` | **36 份**指定文档的资产 token | `checked=703 missing=0 skipped=7` |
| `scripts/doctor/30-tasks-routing.py` | TASKS §N → 章节文件路由 | `ok` |
| `scripts/reports-index.py --check` | **无门** | **rc=1，已过期（633 vs 693）** |

**哪些 md 不在任何体检面内**：`reports/*.md` **692 篇**（693 − 被 doc-assets 扫的 1 篇最新 upstream-status）、`archive/` 190 篇、`SESSIONS/` 173 篇、`patches/**` 167 篇、`HISTORY/days` 60 篇、`.pi/plans` 53 篇、`reference/` 21 篇、`TASKS/sessions` 347 篇（§8 已声明 opt-out）。

**是否应该纳入？** **不需要全纳，但有两类应该在**：
1. **`reports/*.md` 的资产路径**（692 篇未扫）—— 这正是 `check-doc-assets.sh` 的立此原因（`reports/upstream-status-20261027.md` 曾批量指向不存在路径），现在却只扫「最新一篇」。
2. **`reports/README.md` 的新鲜度**（A17）—— 它是 `reports/` 的查全索引，过期 60 篇而无人知。

**`check-doc-assets.sh` 白名单机制的绕道风险（A15，已实证）**

| 风险 | 现状 | 实证 |
|---|---|---|
| 前缀 glob 让「前缀存在」通过 | `compgen -G "${tok}*"`（`:78`）对**任意** token 生效，不要求以 `/` 结尾 | `/tmp/doca_probe2.md` 写 `` `scripts/ch` ``/`` `reports/uefi` ``/`` `patches/0` `` → `checked=3 missing=0 PASS` |
| 占位符跳过面过宽 | `case` 里 `%` 也被当占位符跳过（`:71`） | 任何含 `%` 的路径不经检查 |
| 白名单只增不减 | 12 条实体，**6 条已 0 引用** | `grep -v '^#' scripts/doc-assets-allowlist.txt` + 逐条 `grep -rl` |
| 覆盖面缺口 | `RESOURCES/README.md`（73 token）、`RUNBOOK-BRINGUP/README.md`（23）、`AGENTS.md`（12）不在 `default_files()` | `grep -oE '`(patches\|reports\|scripts\|…)[^`]*`' <file> \| sort -u \| wc -l` |
| 白名单本身不校验理由格式 | `is_allowed()` 只比第一列（`:60-63`），行尾理由是注释 | 读源码 |

**最小改法（3 处、1 个文件）**：①前缀 glob 改为「`${tok}` 以 `/` 结尾才允许 `*`」；②加一段「白名单条目 0 引用 ⇒ WARN」自检；③`default_files()` 补 RESOURCES/RUNBOOK 两份 README。

---

### 2.7 分层违例（A16–A18）

**`reports/` 是不是垃圾场？**

| 指标 | 数字 | 命令 |
|---|---|---|
| `reports/*.md` | **693 篇 / 9.2 MB**（快照时刻；并行 lane 后又 +2 ⇒ 现查 695） | `find reports -maxdepth 1 -name '*.md' \| wc -l`；`-printf '%s\n' \| awk` |
| `reports/` 全目录 | **4966 件 / 2288.7 MB** | §4 命令 |
| 其中 untracked | **1511 件 / 2155.9 MB**（94% 体积） | 同上 |
| `.gitignore` 里 `reports/artifacts` 规则 | **173 条**（逐目录白名单式） | `grep -c '^/\?reports/artifacts' .gitignore` |
| 被角度 README 引用的报告 | **225 / 693 = 32.5%** | §4 命令 |
| **孤儿（无角度 README 指针）** | **468 / 693 = 67.5%** | 同上 |
| 连 `*/sessions/` 也算后的孤儿 | **59 / 693** | 同上 |

**判定**：`reports/` 承担了 3 种互不冲突的职责（活跃证据工作区 / 大件 artifacts / 历史结论），其中 **md 面（9.2 MB）健康，artifacts 面（2.16 G 未跟踪）是体积主因**。`reports/` 的问题不是「垃圾」，是**引用纪律执行率 32.5%** —— 违反 `.pi/AGENT-OPS.md:75`「新落盘的 `reports/*.md` 不得成为孤儿」。

**`reports/README.md` 87 KB 还是策展索引吗？**

- 尺寸 **87 733 B / 1317 行**，首行自述「机器生成，勿手改」，生成器 `scripts/reports-index.py`（`--check` 只比对）。
- **它仍是索引，但已经过期**：`python3 scripts/reports-index.py --check` → rc=**1**，`reports/README.md 过期`；文件自报「报告总数：633」vs 现查 **693**（差 **59–61 篇**，随并行 lane 落盘在动：本审计快照时刻 693，逐篇分布 = 20261124×3 / 20261125×28 / 20261126×26 / 20261127×2 / 无日期×2）。
- **而它没有任何门**：`grep -rn reports-index scripts/*.sh scripts/doctor/* .githooks/*` = **0 命中**。对比 `scripts/README.md` 有 §24 门（含双向反作弊）⇒ **两份同构的生成索引，一份有门一份没有**。
- 副作用：`scripts/doctor/s07-08-docs.py` 的 §8f「reports/ 无孤儿报告」把 `reports/README.md` 当语料，而后者覆盖 **634/693（91.5%）** 个报告文件名 ⇒ **该门结构性无法判出孤儿**。实证：把 `reports/README.md` 从语料剔除后，§8f 会判出 **2** 篇（`doc-audit-20261125.md`、`reboot-bootloader-by-kernel-20261125.md`）—— 也就是说该门当前的真实判别力接近 0。

**过程叙事是否还停在入口页？**（抽样 5 份头部）

| 文件 | 尺寸 | 行数 | 最长行 | 判定 |
|---|---|---|---|---|
| `INDEX.md` | **122 744 B** | 718 | 1 247 | **§0「现在一页」= 行 9–504 = 496 行 / 98 966 B = 全文件 80.6%** ⇒ **仍停在入口页**（唯一重的） |
| `PITFALLS/README.md` | 191 810 B | 409 | 602 | 索引本体，**职责所在**（每条一行 + 指针），豁免 |
| `DEVICE/README.md` | 56 317 B | 415 | 1 053 | 规格/矩阵/台账，属领域正文，可接受 |
| `RESOURCES/README.md` | 65 064 B | 396 | 964 | 同上（外部参考 + 台账） |
| `RUNBOOK-BRINGUP/README.md` | 36 151 B | 476 | 701 | 手册本体，豁免 |
| `reports/README.md` | 87 733 B | 1317 | 155 | 机器生成索引，豁免（但过期，见 A17） |
| `TASKS/README.md` | **6 402 B** | **54** | 318 | **2026-11-26 拆分后已达标**（< 20 KB 自设目标） |
| `AGENTS.md` | 8 154 B | 61 | 273 | 达标 |

**结论**：`TASKS` 的拆分（§1–§7 → 6 个章节文件 + `dim/D##.md`，`README` 只剩 54 行）是本仓**唯一一次成功的「下沉」范式** —— 应照它做 `INDEX §0`。
`TASKS/sessions` **291/347（83.9%）** 不被任何入口文档引用、**151 篇全仓 0 引用** —— 但 `s07-08-docs.py:73-75` 已把 TASKS 写成**明示 opt-out**（「188 篇按日期滚动的会话日志，按主题在 §1/§5/§7 引用，逐文件登记会变成维护负担」）⇒ 这不是漏检，是决定，**豁免**。

---

## 3. 与既有 6 份审计的对账

> 判定词：**已修**（本轮实测已不存在）/ **仍成立**（复现同上或更差）/ **已取代**（被新口径/新事实覆盖）。

### 3.1 `reports/code-style-and-duty-overlap-audit-20261030.md`

| 原条目 | 原判据 | 本轮实测 | 结论 |
|---|---|---|---|
| **A1-11** `patches/upstream/**` 的 checkpatch 必须在 `/tmp` 跑（仓库根跑会静默降级） | 手工门 | `grep -rn checkpatch scripts/*.sh scripts/*.py` = **0 命中** ⇒ 该门**从未机器化**，目前只在审计报告里手工可跑 | **仍成立**（且更弱：无任何自动化） |
| **A2-01** `dsi_phy_7nm.c` 用 `of_machine_is_compatible("lenovo,elden")` 判板名（走后门） | 红线正命中 | `grep -rln of_machine_is_compatible patches/` = 4 文件，含 `patches/upstream/dispcc-reset-v2-20261113/*.patch`、`patches/upstream/q28-dispcc-2026-10-22/0001-*`、`patches/vk151-20261023/0001-*` | **仍成立（同族）**；`dispcc-reset-v2` 的 README 已自述「建议撤回 RFC、不再立 v2」⇒ 是否算「已退役」**待确认** |
| **B7-01** `check-abi-config.sh` 默认目标写死已退役 `build/m1-73` | 裸跑必过 | `scripts/check-abi-config.sh:62` 注释「默认目标 = `patches/current-tree` 指向的现役日常线树（**不再写死已退役的 build/m1-73**）」 | **已修** |
| **B4** Q28 看门狗同脚本 2 份同 sha + 1 heredoc + 1 MANIFEST | 设备侧唯一源不成立 | 本轮 §2.4：`q28-boot-watchdog.sh` 已**同名不同内容**（`a85ec07ac0` vs `709e9eb86c`）⇒ 从「多份同 sha」退化为「多份不同 sha」 | **仍成立且恶化**（现在不知道跑的是哪份）→ 归入 A9 |

### 3.2 `reports/doc-audit-20261026.md`

| 原条目 | 原数字 | 本轮实测 | 结论 |
|---|---|---|---|
| P0 §6-1 资源台账与磁盘差 1.05×–187×（`reports/` 记 15 M 实为 2.8 G） | 台账失真 | `reports/` 现 **2288.7 MB**；台账现值未复核（属 `RESOURCES/README.md` 域，本轮不改） | **仍成立（量级未变）**，`disk-audit-20261126` 已接手 |
| P1 §5-3 `TASKS/sessions` 40/64 篇全仓 0 引用、门禁 opt-in 漏了 TASKS | 62.5% | 现 **347 篇**；入口文档 0 引用 **291（83.9%）**；全仓 0 引用 **151（43.5%）** | **仍成立**；但 `s07-08-docs.py:73-75` 现已**明写** opt-out 理由 ⇒ 从「漏了」升级为「已声明的豁免」 |
| 死链 703 个不同路径 / 1593 处 | 全仓 | `check-doc-assets.sh` 现 `checked=703 missing=0`（但只扫 36 份、且前缀 glob 有绕道，见 A15） | **已修（其扫描面内）/ 仍成立（面外）** |
| 孤儿报告 11 篇 | reports 208 篇时 | 现 693 篇，按「任一文件引用」口径只剩 **2** 篇；按「角度 README」口径 **468** 篇 | **已修（窄口径）/ 已取代（口径变宽后暴露出 468）** |

### 3.3 `reports/doc-dedup-audit-20261112.md`

| 原条目 | 原判据 | 本轮实测 | 结论 |
|---|---|---|---|
| P0 ③ 收尾判据：`AGENTS.md:50` 要 `WARN=0`，`AGENT-OPS` 只要 `FAIL=0` | 两套说法 | 本轮 `check-doctor` 常态 **WARN=3**（存量三条），若按 `WARN=0` 收尾则**永远收不了尾** | **仍成立（且是当前稳态下的真冲突）** |
| P1 `.pi/AGENT-OPS.md:98-99` 把并发三值 + 配额整段复写 | 应改为指针 | 现 `.pi/AGENT-OPS.md:129` 已改成指针，**但指向 `~/.pi/agent/fabric.json` + `.pi/fabric.json`**，前者**已不存在** | **已修形式 / 新引入死因** → A12 |
| §2 `.pi/` 三件套互相抄（并发/单写者/设备锁/ustc 池 4 份） | 30 组重复 | `grep -c maxConcurrent`：`ORCHESTRATION` **2** / `AGENT-OPS` **0** / `CONCURRENCY` **0** ⇒ 并发三值已收敛到 `ORCHESTRATION` §3 一处；**单写者/设备锁/ustc 池三组本轮未重算 ⇒ 待确认** | **部分已修（并发组）/ 待确认（其余三组）** |

### 3.4 `reports/script-cleanup-audit-20261112.md`

| 原条目 | 原判据 | 本轮实测 | 结论 |
|---|---|---|---|
| **P0 ①** `packaging/.../ath12k-load.sh` 仍被 MANIFEST 装机但零调用点 | P0 | `scripts/ath12k-load.sh:11` 已加 `RETIRED` 头；`scripts/README.md:120` 标 `★★★ RETIRED（2026-11-22）★★★` | **已修** |
| **P0 ②** `arm-console-run.sh:14` / `trial.sh:186` 仍用 `fastboot devices \| grep -q .` | P0 | `grep -rn 'fastboot devices \| grep -q' scripts/` → **只剩 7 条注释**（`esp-apply.sh:59`、`lib-soft-bootloader.sh:23`、`lib-hosttools.sh:22`、`linux-gpt-apply.sh:53`、`uefi-ddr-trial.sh:30`、`linux-gpt-dump.sh:20`、`arm-window-hunt.sh:12`），**无代码命中** | **已修** |
| P2 `build/<旧树名>` 漂移 28 处 | 28 处 / 17 文件 | `grep -rhoE 'build/[A-Za-z0-9._-]+'` 活面文档 → 11 个名字；`build/` 现为软链 `→ ~/elden-cache/build` | **已取代**（`build/` 搬家后旧树名自然失效，但引用的「树名」仍在文档里） |
| **P2** `scripts/kbuild-sanity.sh:26` 硬赋值 `KDIR=${ROOT}/build/m1-73` | 默认用法打不存在的树 | `grep -n KDIR= scripts/kbuild-sanity.sh` → `:31 KDIR=`（空，` :42 *) KDIR=$1`） | **已修** |
| `lib-ssh`/`lib-wait` 统一层只落 10% | 61 内联 vs 6 source | 现 **71** 个脚本内联 `ssh -o`，**6** source `lib-ssh.sh`，**5** source `lib-wait.sh`，内联 `fastboot devices` 轮询点 **32** | **仍成立（恶化：61→71）** |

### 3.5 `reports/pitfalls-dedup-audit-20261112.md`

| 原条目 | 原判据 | 本轮实测 | 结论 |
|---|---|---|---|
| P0 6 个编号被跨文件重复定义（#53/#192/#282–#285） | 撞号 | `bash scripts/check-doctor.sh --only s07-08` → `[ok] 文件名/条目编号无撞车`；`PITFALLS/README.md:10` 记「`#53/#192/#282–#285` 撞号已让位」 | **已修** |
| P1 索引 36 行指向 `../reports/*.md` 的 #NNN 无 sessions 正文 | 27 个 #NNN 悬空 | `check-doctor §8` → `[ok] PITFALLS 索引 #NNN 均有正文定义` + `[ok] 已归档豁免（26 个 #NNN 带 archived=）`；`PITFALLS/README.md:10` 记「2026-11-20 实测清零：全库 226 条索引、sessions 正文 226/226」 | **已修** |
| P1 索引行长度门对「指向 reports 的行」形同虚设 | 原判据要求行内含 `sessions/` | `scripts/doctor/s07-08-docs.py:114-120` 现为 `for rel, lim in (('PITFALLS/README.md', 800),)` + 注释「长度门不再要求行内含 `sessions/`」，同文件 `:177` 悬空门同改；`check-doctor §8` → `[ok] 索引行长度合规` | **已修（门已覆盖）** |
| §A1 `pkill -f` 自匹配 18 个副本（`.pi/memory/failures-device.md` 内 7 遍） | 重复 | 本轮未重算（不在七件范围内，且 `proj-audit` 仍报 6 处 `pkill -f` 自匹配 WARN） | **待确认**（建议下轮专项复算，本轮不下结论） |

### 3.6 `reports/disk-audit-20261126.md`

| 原条目 | 原建议 | 本轮实测 | 结论 |
|---|---|---|---|
| A `out/` 三件 Android 构建工作区（38.6 G） | ✅ 已执行（用户授权） | `du -sh out/` = **7.1 G**（`du -sh --apparent-size` = 12 G） | **已修** |
| B 19 组同内容大件（9.9 G，`cp -l` 硬链） | 谨慎 | 未动 | **仍成立（未执行）** — 同轮已有 `reports/fs-dedup-20261127.md` 在办（不属本轮） |
| C `.pi/sessions` gzip（~0.45 G） | 先验工具兼容 | `.pi/sessions` 现 **1018 件 / 1.1 G** | **仍成立（未执行）** |
| D `reports/artifacts/`（2.0 G，可回收 ~0.3 G） | 低优先 | `reports/artifacts` 仍 **2.0 G**；`reports/` 未跟踪 **2155.9 MB** | **仍成立（未执行）** → 归入 A16 |
| E `.git` 418 M / `backup/` 29 G / `bootslot-b/` 1.8 G | 不动 | `.git` **417 M**、`backup/` **33 G**、`bootslot-b/` **2.2 G** | **已取代**（`backup/` 29→33 G、`bootslot-b/` 1.8→2.2 G；原「不动」结论仍适用） |

### 3.7 对账小结

| 状态 | 条数 | 条目 |
|---|---|---|
| **已修** | 9 | B7-01 / script-cleanup P0① / script-cleanup P0② / kbuild-sanity 默认树 / pitfalls 撞号（#53/#192/#282–#285）/ PITFALLS 索引悬空 / 行长门 / disk-A（out/ 38.6 G）/ doc-dedup 并发组已收敛到单处 |
| **仍成立** | 10 | A1-11（checkpatch 从未机器化）/ A2-01（同族 4 文件）/ B4（退化为同名不同 sha）/ doc-audit P0§6-1 / doc-audit P1§5-3 / doc-dedup P0③（WARN=0 vs FAIL=0）/ lib-ssh 统一层 6 vs 71 / disk-B / disk-C / disk-D |
| **已取代** | 3 | `build/<旧树名>` 28 处（build 搬家后失效）/ 孤儿报告口径（窄→宽，暴露 468）/ disk-E 三处体积（backup 29→33 G、bootslot-b 1.8→2.2 G） |
| **待确认** | 3 | `dispcc` 系列是否已算退役 / `pkill -f` 18 副本现状（本轮未重算）/ `.pi/` 单写者·设备锁·ustc 池三组重复度 |

> 数字不追求「加起来等于条目总数」——同一条目跨两份审计时会各记一次（如 B4 与 A9 同源）。

---

## 4. 复跑命令清单（全部只读，可直接复制）

```bash
cd /home/xuqianhui/y700-elden

# ---- 0 基线 ----
timeout -k 60 300 git ls-files | wc -l
timeout -k 60 120 git ls-files -z '*.md' | tr '\0' '\n' | wc -l
timeout -k 300 du -sh .
timeout -k 600 bash scripts/check-doctor.sh                 # FAIL=0 WARN=3
timeout -k 300 bash scripts/check-progress-counts.sh        # G1 36/37 G2 10/13
~/.pi/agent/bin/docs-health --brief                         # 0/0/0 · 154 文档 · 13 项目
~/.pi/agent/bin/proj-audit "$PWD" --only tool,junk,danger --quiet   # FAIL=0 WARN=43（42 danger + 1 junk；见 §2.3 抖动说明）

# ---- 2.1 顶层布局 ----
timeout -k 120 bash scripts/check-layout.sh                 # PASS entries=46
ls -1A | wc -l                                             # 47（含 .git）
ls -1A | sed 's#/$##' | LC_ALL=C sort > /tmp/disk_top.txt
timeout -k 120 bash scripts/check-layout.sh --list | awk '{print $2}' | sed 's#/$##' | LC_ALL=C sort -u > /tmp/reg.txt
LC_ALL=C comm -23 /tmp/disk_top.txt /tmp/reg.txt     # 未登记（输出应只有 .git）
LC_ALL=C comm -13 /tmp/disk_top.txt /tmp/reg.txt     # 登记但磁盘不存在（应为空）
git ls-files dl-cam | wc -l                                 # 231（vcs=ignore 的反例）
ls .pi/ | wc -l                                            # 18 vs .pi/README.md 表 12 项

# ---- 2.2 角度文件夹 ----
for d in DEVICE TASKS RESOURCES RUNBOOK-BRINGUP PITFALLS SESSIONS HISTORY; do
  printf "%-16s md=%4s size=%6s last=%s\n" "$d" "$(find $d -name '*.md'|wc -l)" \
    "$(du -sh $d|cut -f1)" "$(find $d -name '*.md' -printf '%TY-%Tm-%Td\n'|sort|tail -1)"; done
for d in DEVICE TASKS RESOURCES RUNBOOK-BRINGUP PITFALLS SESSIONS; do
  printf "%-16s old(>30d)=%4d / %4d\n" "$d" \
    "$(find $d/sessions -name '*.md' ! -newermt 2026-10-28|wc -l)" "$(ls $d/sessions/*.md|wc -l)"; done

# ---- 2.3 scripts 引用 / 孤儿 / 死引用 ----
python3 scripts/gen-scripts-index.py --check                # OK … 359 个入口
python3 scripts/static-scan.py --tsv                        # BASHISM - / DEAD -  ← 门空转证据
python3 scripts/static-scan.py --inventory | awk -F'\t' 'NF>=7{print $7}' | sort | uniq -c
find scripts -type f | wc -l                                # 439
git ls-files 'scripts/__pycache__' | wc -l                  # 0
python3 - <<'EOF'   # 活面文档 14 份 → 引用 / 孤儿 / 死引用
import os,glob,re
os.chdir('/home/xuqianhui/y700-elden')
docs=['INDEX.md','AGENTS.md','PITFALLS/README.md','reports/README.md']\
     +sorted(glob.glob('TASKS/*.md'))+sorted(glob.glob('DEVICE/*.md'))+sorted(glob.glob('RESOURCES/*.md'))
blob={d:open(d,encoding='utf-8',errors='replace').read() for d in docs}
c=[]
for dp,dn,fn in os.walk('scripts'):
    dn[:]=[d for d in dn if d!='__pycache__']
    for f in fn:
        if f.endswith(('.pyc','.md','.txt','.tsv','.service','.conf','.initd','.m4','.java','.c')): continue
        c.append(os.path.join(dp,f))
c.sort()
ref=[p for p in c if any(os.path.basename(p) in t for t in blob.values())]
print("scripts=%d ref=%d orphan=%d" % (len(c),len(ref),len(c)-len(ref)))     # 359 161 198
pat=re.compile(r'scripts/([A-Za-z0-9_./-]+\.(?:sh|py|pl))')
dead={(m.group(1),d) for d,t in blob.items() for m in pat.finditer(t)
      if not os.path.exists('scripts/'+m.group(1))}
print("dead_refs=%d" % len(dead)); [print(" ",k) for k in sorted(dead)]      # 12 处 / 7 路径
EOF

# ---- 2.4 packaging 镜像契约 ----
python3 - <<'EOF'
import os,hashlib,collections
os.chdir('/home/xuqianhui/y700-elden')
def gather(p):
    d={}
    for dp,dn,fn in os.walk(p):
        for f in fn:
            q=os.path.join(dp,f)
            try: d[q]=hashlib.sha256(open(q,'rb').read()).hexdigest()
            except OSError: pass
    return d
A=gather('packaging/elden-userland/files'); AK=gather('packaging/keyboard-settings/files'); A.update(AK)
S=gather('scripts'); R=gather('rootfs/persistent-overlay')
idx=collections.defaultdict(list)
for z,dd in (('A',A),('SR',S),('SR',R)):
    for p,h in dd.items(): idx[h].append((z,p))
same=set()
for h,v in idx.items():
    zs={z for z,_ in v}
    if 'A' in zs and 'SR' in zs:
        for a in [p for z,p in v if z=='A']:
            for s in [p for z,p in v if z=='SR']: same.add((a,s))
print("SAME_CONTENT_PAIRS=%d" % len(same))                    # 28
bn=collections.defaultdict(list)
for p,h in list(A.items()): bn[os.path.basename(p)].append(('A',p,h))
for p,h in list(S.items())+list(R.items()): bn[os.path.basename(p)].append(('SR',p,h))
drift=[(n,v) for n,v in bn.items() if {x[2] for x in v} and
       any(x[0]=='A' for x in v) and any(x[0]=='SR' for x in v) and len({x[2] for x in v})>1]
print("SAME_NAME_DRIFT=%d" % len(drift))                      # 13
for n,v in sorted(drift): print(" ",n,[p for _,p,_ in v])
EOF
grep -n "scripts/" packaging/elden-userland/tools/verify.sh | wc -l     # 0
grep -n "elden-userland\|verify.sh" scripts/check-doctor.sh | wc -l     # 0

# ---- 2.5 残留垃圾 ----
ls .pi/agents/*.bak-alias-1112 | wc -l                      # 24
for f in .pi/agents/*.bak-alias-1112; do diff -q "${f%.bak-alias-1112}" "$f" >/dev/null 2>&1 && echo SAME; done | wc -l   # 10
timeout -k 300 find . \( -path ./.git -o -path ./wt -o -path ./build -o -path ./out -o -path ./backup -o -path ./linux -o -path ./geekidos-linux -o -path ./external -o -path ./dl-cam -o -path ./.pi/sessions \) -prune -o -type f -name '*.bak*' -print | wc -l   # 27
git ls-files .pi/fabric.json; ls -la ~/.pi/agent/fabric.json     # tracked / 不存在
find .pi/fabric -type f | wc -l                             # 4
git ls-files .pi/tmp-tasks | wc -l                          # 3
grep -rn "tmp-tasks" --include=*.md . | grep -v '^./wt/' | grep -v '^./reports/' | wc -l   # 0
find restore-259 probes dl-cam -type f | wc -l              # 2 / 27 / 230

# ---- 2.6 工具接线 ----
timeout -k 60 bash scripts/check-doctor.sh --list | wc -l    # 28
timeout -k 60 bash scripts/check-doctor.sh --list | grep -c full+fast   # 17
ls scripts/doctor/ | wc -l                                   # 30
timeout -k 300 bash scripts/check-doc-assets.sh              # checked=703 missing=0 skipped=7 files=36
timeout -k 120 bash scripts/check-doc-assets.sh --list | wc -l          # 36
grep -v '^#' scripts/doc-assets-allowlist.txt | grep -c .    # 12
printf '前缀通配绕过：`scripts/ch` 与 `reports/uefi` 与 `patches/0`\n' > /tmp/doca_probe2.md
timeout -k 120 bash scripts/check-doc-assets.sh /tmp/doca_probe2.md     # PASS ← 绕道证据
timeout -k 120 python3 scripts/reports-index.py --check; echo rc=$?     # 过期 rc=1
grep -rn reports-index scripts/*.sh scripts/doctor/* .githooks/* | wc -l  # 0

# ---- 2.7 分层 ----
find reports -maxdepth 1 -name '*.md' | wc -l                # 693
find reports -type f -printf '%s\n' | awk '{s+=$1;n++} END {printf "%d %.1f MB\n",n,s/1048576}'   # 4966 2288.7 MB
find reports -maxdepth 1 -name '*.md' -printf '%s\n' | awk '{s+=$1;n++} END {printf "%d %.1f MB\n",n,s/1048576}'  # 693 9.2 MB
grep -c '^/\?reports/artifacts' .gitignore                   # 173
sed -n '9,504p' INDEX.md | wc -c                             # 98966
wc -c INDEX.md                                               # 122744
```

**清理 `/tmp` 临时件**（本轮只往 `/tmp` 写）：`rm -f /tmp/doca_probe*.md /tmp/orph_final.txt /tmp/disk_top.txt /tmp/reg*.txt /tmp/doctor.txt /tmp/ri.out /tmp/inv_fresh.tsv`

---

## 5. 附录

### 5.0 本轮工作区状态（未动 git 索引）

```
$ git status --short
?? ".pi/plans/2026-11-27-整理三线派工.md"     ← 开工时**已存在**（非本轮产物）
?? =50KB                                      ← 本轮开工时不存在；8 B 的 shell 重定向残骸（非本轮产物）
?? reports/arch-audit-20261127.md             ← ★ 本轮唯一新增（本文件）
?? reports/fs-dedup-20261127.md               ← 本轮开工时不存在；并行 lane 的产物（非本轮产物）
```

> 本轮**只新增** `reports/arch-audit-20261127.md`；其余 3 项均为**他人/他 lane 产物**，本轮未读、未改、未删。
> `=50KB` 是 8 字节文件（内容 `=== ===`），疑似某条 `find`/`du` 命令的重定向写错落点 —— **建议父代理立刻 `rm -f '=50KB'`**。
> **它已经把门顶红了**：`=50KB` 落在仓库根 ⇒ `scripts/check-layout.sh` 判「顶层条目未登记」⇒
> `check-doctor.sh --only 14` 现在 **FAIL=1**（`bash scripts/check-doctor.sh --only 14` 实测，2026-11-26 19:53）。
> 本轮开工时（19:0x）全量 doctor 还是 `FAIL=0 WARN=3`，即**这条 FAIL 是本轮期间新产生的**、由并行会话的落盘事故造成。

### 5.1 本轮**未覆盖**的面（避免被误读为「审过没问题」）

1. `reports/*.md` 正文结论的正确性（693 篇）—— 只审了「引用关系」与体积。
2. `patches/**` 的 checkpatch / DTC / binding 三态（A1-11 已指出该门从未机器化）。
3. `.pi/memory/*.md`（6 件 / 340 KB）与 `PITFALLS/sessions/*.md`（281 篇）的重复度（归 pitfalls-dedup-audit）。
4. `RESOURCES/README.md` §3 资源台账的逐项体积对账（归 doc-audit-20261026 的 P0 §6-1，仍未闭合）。
5. 任何设备侧事实（**本轮零设备接触**：无 adb/fastboot/ssh/qdl）。

### 5.2 四个「先做这个」的顺序建议（按代价排序）

0. **A0**（`rm -f '=50KB'`）—— 1 秒，让 `check-doctor` 回到 FAIL=0；**不做这条，任何「收尾」都不成立**。
1. **A12**（删 `fabric.json` + 修 4 处活文档）—— 5 分钟，消除「配置真源指向空文件」。
2. **A8**（`static-scan.py` 的 `SELF_OUTPUT` 加 `scripts/README.md`）—— 1 行，恢复死脚本门的判别力，之后 A7 的 166 个孤儿才可信。
3. **A17**（加 `31-reports-index.sh`）—— 抄 §24 形态，让 `reports/README.md` 的 60 篇缺口可见并可自动修。

---

## 6. 父代理独立复核与落地（2026-11-26 20:2x–20:4x CST，本节由父会话追加）

> 口径 = 全局规则 7「worker 自报不可信」：下列每条都**由父会话重跑命令**确认过，不是采信 §1 的自述。
> 已落地件全部带**阴性对照**（证明检查器真的会红），命令与结果附在本节。

### 6.1 已落地（5 项）

| ID | 落地内容 | 父代理复核结果 |
|---|---|---|
| **A0** | 顶层杂件 `=50KB` 已移出：`mv '=50KB' /tmp/elden-junk-20261126/`（未 `rm`，留复查） | `scripts/check-layout.sh` → `PASS: 布局注册表一致（entries=46）`；全量 `check-doctor` 回 **FAIL=0 / WARN=3** |
| **A12** | ①`.pi/AGENT-OPS.md:129`、`.pi/ORCHESTRATION.md:44/§9`、`.pi/CONCURRENCY.md:31` 改口 `settings.json` 的 `subagents` 段；②`git rm .pi/fabric.json` + `rm -rf .pi/fabric/` | `grep -rn fabric.json .pi/*.md AGENTS.md` 现只余三处**已改口**的说明句；`grep -rln fabric scripts/ .githooks/` = 0（无消费者） |
| **A8** | `scripts/static-scan.py` 的 `SELF_OUTPUT` 加 `scripts/README.md` | **实证成立**：`git add -N scripts/zz-orphan-*.sh` 造 tracked 孤儿 → 修前 DEAD=`-`（被索引自吞）；修后 DEAD 命中，且**重建索引后仍命中** |
| **A17** | ①`python3 scripts/reports-index.py` 重生成（633 → **694 篇**）；②新建 `scripts/doctor/31-reports-index.sh` 并接进 `check-doctor.sh` 的 `ALL` 档 | §31 双阴性对照：新增 `reports/zz-doctor-probe.md` ⇒ `--check rc=1`；手改 `报告总数` ⇒ `[FAIL] 过期`；复原 ⇒ `[ok] 最新（694 篇）` |
| **A15** | `scripts/check-doc-assets.sh` 前缀 glob 收紧为「前缀命中数 ≤3」 | 真树仍 `checked=703 missing=0 skipped=7 PASS`（两条真截断 `PITFALLS/sessions/01`、`patches/uefi/20261106R31` 实测 n=1 仍过）；阴性对照 `scripts/ch`/`reports/uefi`/`patches/0` **3/3 判 MISSING** |
| **A2** | `scripts/check-layout.sh` 新增第 4 步（`vcs=ignore` 区不得有 ≥5 MiB 或 `.img/.bin/.mbn/.elf/.ko` 的 tracked 件）+ `versions/layout.tsv` 表头写明「ignore = 默认不入库，不是一件都不许」 | 真树 `PASS`；阴性对照：`git add -fN` 造 `out/zz-probe/big.img`（6 MiB）⇒ **两条红线都判 FAIL**，撤回后回 PASS |

### 6.2 对 §1 的三处修正（父代理指出，避免下轮误用）

1. **A8 的机制成立、但第一版自测方法无效**：`static-scan.py` 的脚本清单取自 `git ls-files scripts/*.sh`（**只认 tracked**），
   所以「新建一个未跟踪探针」测不出自吞。必须 `git add -N` 让它进入索引后再测（本文件 §6.1 已用此法证实）。
   另：若探针名被写进**任何语料文件**（含 `static-scan.py` 自己的注释），`grep -F` 会把它算作「有引用」——父代理第一次
   落地后被自己的注释污染，改用 `zz-orphan-*.sh` 通配写法才测通。
2. **A2 的判据形式与审计建议不同**：审计建议「`vcs=ignore` ⇒ `git ls-files` 必须为 0」。父代理改判为「不得有 ≥5 MiB / 器件件」——
   因为 `out/`（235 件 manifest）、`dl-cam/`（231 件源件）、`backup/`（18 件小文本证据）、`env-pass/`、`assets/` 都是**有意入库的小件**，
   按审计原判据会一次性判 478 件 FAIL 且逼人改台账语义。现判据既保留机器语义又不误伤。
3. **A8 的「DEAD 恒空」在当前树只对「新孤儿」成立**：修后真树 `DEAD` 仍为 `-`（父代理独立复核：`git grep -lF <每个脚本 basename>`
   在排除两个索引文件后仍 0 个零引用脚本）⇒ 历史 359 个脚本确实都被某种语料提到过；A8 的危害是**未来**新脚本一旦重新生成索引就永久隐身。

### 6.3 仍待处理（进 `TASKS/NEXT.md` §4.0a）

- **T9** = A9/A10（用户态镜像门 + `verify.sh` 接线；13 组漂移「谁是权威」需用户裁定）
- **T10** = A16（`reports/` 468 篇孤儿 + `.gitignore` 173 条规则收敛；改入库边界需用户确认）
- **T11** = A18（`INDEX.md` §0 下沉，口径见 `.pi/plans/2026-11-27-文档精简拆分归档.md` B1）
- **T12** = `.pi/sessions/` gzip（先改 `sessfind` 等 5 处 `*.jsonl` 硬匹配，见 `reports/fs-dedup-20261127.md` §B3）
- **未动**：A11 的 24 个 `.pi/agents/*.bak-alias-1112`（`.gitignore` 明示用户有意保留）、A6 的 `RUNBOOK-BRINGUP/sessions` 存废、
  A7 的 166 个 plain 孤儿分类（本轮只确认门已修好，分类需逐脚本判）。
