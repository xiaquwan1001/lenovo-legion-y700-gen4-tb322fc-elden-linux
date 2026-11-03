# 2026-11-03 项目整理：外部资产收拢 / 顶层布局重构 / 精简与纠错

> 触发：用户「整理项目：① 把项目之外的资产和文档收拢；② 对项目架构重构以便长期维护；③ 精简冗余、修正过时错误部分」。
> 方案与执行账：`.pi/plans/2026-11-03-项目整理.md`。**收尾门：`scripts/check-doctor.sh` FAIL=0 / WARN=3（均为历史留白项）**。

## 1. 数字结论

| 项 | 结果 |
|---|---|
| 收归项目的仓库外资产 | **4 处 / 17.7 G**：官方线刷包 16 G、EDL 全量包 599 M、`ext-repos` 1.1 G、`l2` 唯一副本 16 K |
| 删除冗余 | **3.0 G 实际占盘**：`serial-delta.log` 2.95 G（Q32 已结项）+ 根目录 8 个 `.deb` 1.9 M + `f2e0.img` 36 M（apparent 8.6 G 是稀疏文件） |
| 根目录条目 | 47 → **46**（删 8 个 `.deb`、删 `l2` 断链软链；无新增目录） |
| 顶层布局注册表 | **新增**：`versions/layout.tsv`（46 项，4 区）+ `scripts/check-layout.sh` + `check-doctor.sh` **§14**，INDEX §2 渲染人读面 |
| `TASKS/README.md` | 203,075 → **148,881 字符**（−27 %）；最长表格行 8,597 → **1,861** 字符；14 行长单元格**逐字下沉** `TASKS/sessions/2026-11-03-TASKS行NN-*.md` |
| 纠错 | RESOURCES §3 一处**被插入行切断**的表格行（SESSIONS 行尾粘到 trials 行）；INDEX「RUNBOOK 空壳」；`build/` 体积 87 G→185 G；`ext-repos` 归属判定错误；HISTORY/days 落后 |

## 2. 收拢的仓库外资产（同盘 `mv`，原路径留同名软链 ⇒ 所有既有绝对路径继续可用）

| 原路径 | 新归属 | 体积 | 依据 |
|---|---|---|---|
| `~/文档/TB322FC_15.10.259/` | `backup/official-rom-15.10.259/` | 16 G | 官方全量线刷包（`super_4.img` 12 G 独占）；`backup/stock-259/` 只是其中 13 分区子集 |
| `~/下载/tb322fc/` | `backup/fw/tb322fc-edl/` | 599 M | EDL 全量包 65 件（rawprogram/patch/firehose） |
| `~/ext-repos/` | `external/ext-repos/` | 1.1 G | `mu`/`dl`/`mu-dodge`/`sunuefi`/`af`/`vk64rd` 全部是 TB322FC/UEFI 专用 ⇒ 上一版 RESOURCES 记为「机器级、多项目共用」**有误**，本轮更正 |
| `~/mnt/Samsung/l2/{lp_tool.py,dump-super.sh}` | `tools/l2-extract/` | 16 K | 自研 LP v1.2 dump/extract/splice **唯一副本**（外置盘 45 G super 已随盘丢失）；`./l2` 断链软链一并移除 |

**有意留在仓库外的机器级资产**（多项目共用，不属于单一项目）：`~/toolchains/`（aarch64 musl 交叉链）、`~/edl/`
（Qualcomm EDL 工具链单根目录，2026-11-03 定为源码自建）、`~/pylibs/`、`/mnt/Samsung/{waydroid-build,ccache}`（外置盘未挂）。

## 3. ⚠ 顺带检出：`out/` 一份镜像**静默损坏**（非本轮操作造成）

- `out/boot-elden-m3v5-daily.img`：**镜像 sha256 与自身 manifest 不符**，且内核段 gzip **CRC 失败**
  （`Error -3 while decompressing data: incorrect data check`）。文件大小/`mtime`（2026-10-30 11:23）均未变 ⇒
  内容在落盘之后被改过，属**静默数据损坏**（ext4，`findmnt` 已核）。
- 影响面已量化：**220 个 `out/*.img` 逐个对 manifest 复算 sha256，只有这 1 个不符** ⇒ 不是文件系统级/磁盘级普遍损坏。
- 处置：镜像移到 `backup/corrupt-20261103/` 留作取证（不入 `out/` 扫描路径），身份表按文档流程重生成
  （差异仅「该行消失」）；`versions/vk-ledger-known-issues.tsv` 中受影响的 `uts_dup12 → uts_dup11`（派生计数，理由与锚定 sha 不变，
  已在该文件 §注记说明）。重出条件：`build/m3v5-daily/` 仍在盘，重跑构建即可。
- **未解释项**：损坏发生在 2026-10-30 落盘之后、2026-11-03 之前；本轮未做任何写该文件的操作。
  若再次出现同类现象，优先排查存储/RAM（本机另有 `hw-stability` 取证项目）。

## 4. 架构重构：顶层布局注册表（长期维护的抓手）

- 问题：根目录条目随专题自发增长（46 项），没有口径回答「这个目录能不能删、要不要入库」；新会话只能靠猜。
- 做法：**不搬路径**（`build/` 是 `git worktree` 父目录，搬动会破坏 `.git/worktrees/*` 元数据与数百处脚本引用），
  改为「**注册表 + 机器门**」：
  - 真源 `versions/layout.tsv`：`zone / path / vcs / note` 四列，zone ∈ {entry 入口, doc 角度文档, evidence 证据与备份,
    src 源码补丁工具, work 工作区(ignore), ai AI 大脑}；
  - 门 `scripts/check-layout.sh`：磁盘顶层条目未登记 / 登记但磁盘不存在 / INDEX 未渲染 / zone 非法 / path 重复 = FAIL；
  - `check-doctor.sh` **§14** 接线；INDEX §2「顶层布局」表为人读面（与 `layout.tsv` 同源，行由表生成）。
- 效果：新增目录不登记就过不了收尾门；死路径（台账有、磁盘无）也会被抓。

## 5. SSOT 瘦身：`TASKS/README.md` 巨型单元格下沉

- 问题：14 行表格行 > 2000 字符（最长 8,597），把整段历史叙事塞进单元格 ⇒ 无法审阅、diff 噪声、评审时看不见结论。
- 做法（机械、可验证）：行内**每个 ≥500 字符的单元格**逐字下沉到 `TASKS/sessions/2026-11-03-TASKS行NN-<任务>.md`，
  表格留「前 200 字符摘要 + ⟪全文见本条明细⟫」；**未改任何状态词、数字、日期**。
- 校验：对 14 行 × 全部被搬单元格做**原文子串比对，mismatches=0**（脚本化，非目测）。
- 后继口径不变：状态数字仍只在 `TASKS/README.md` §0/§5；明细文件只是正文搬家。

## 6. 纠错清单（过时/错误）

1. `RESOURCES/README.md` §3 顶层台账有一行被后续插入的 `packaging/`、`reports/trials/` 行**切断**：
   `SESSIONS/README.md` 行尾 `（原 \`REA` + `DME.md §4\` 会话索引已迁此）` 粘到了 trials 行末 ⇒ 已拼回。
2. `INDEX.md` §2 称 `RUNBOOK-BRINGUP/` 是「目前空壳，需要时再启用」⇒ 实为 44 K 正文 + `sessions/`，已改。
3. `RESOURCES` §3 `build/` 记 87 G ⇒ 现 185 G / 38 项（并保留「删前先 bundle + 导 diff」前置闸口径）。
4. 根目录 `*.deb`、`f2e0.img`、`./l2` 三条台账行按实际处置改写（删除 / 收归 `tools/l2-extract/`）。
5. `reports/trials/` 记「21 M / serial-delta 不入库」⇒ 该 2.95 G 文件**此前已被 git 跟踪**（`.gitignore` 只对未跟踪文件生效），
   本轮随删除一并入库记录。
6. `HISTORY/days` 落后 HEAD ⇒ `scripts/gen-history.sh` 重生成（覆盖 1007 条提交）。

## 7. 未做（有意）

- **`build/` 185 G 未删**：13 棵是独立仓/worktree 且有未提交改动 / 本地独有提交，删除前必须先 `git bundle` + 导出 dirty diff；
  磁盘 441 G 可用，不紧迫。台账已更新真值并保留前置闸。
- 未改 `TASKS/README.md` 章节编号（§0/§5/§7 被大量文档引用），未搬 `build/`、`out/`、`logs/` 等路径。
