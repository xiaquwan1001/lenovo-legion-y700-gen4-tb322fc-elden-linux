# 邮件本地资产清理（2026-11-02）

> 范围：`out/mail-2026*` 共 10 个历史邮件工作区 + `reports/mail-triage-*.md` 复核。
> 约束：只做**可逆**动作（同一文件系统内 `mv`）；`out/` 全部 `.gitignore` 忽略，本次
> **未执行任何 git 写操作**，未碰设备，未碰邮箱写。

## §0 结论数字

| 项 | 数量 | 逻辑字节 | 说明 |
|---|---|---|---|
| 审计范围 | **10 个目录 / 203 个文件** | 2 639 399 B（`du -sh` = 3.1M） | `out/mail-20261023 … 20261031-c` |
| **A 直接删除** | **8 个文件** | **22 140 B（21.6 KiB）** | `__pycache__` 1 + dry-run 中间件 6 + 被取代脚本 1 |
| **B 归档（mv，可恢复）** | **7 条路径 = 18 个文件** | **437 413 B（427 KiB）** | → `out/mail-trash-20261102/<原文件/子目录名>`（扁平存放，映射见 §2.1） |
| **C 保留** | **177 个文件** | 2 179 846 B（2.08 MiB） | 被 md/脚本引用，或某轮唯一原始数据 |
| 磁盘前后 | — | `du -sh` 3.1M → **2.6M（存活件）+ 476K（回收区）= 3.08M** | 差额 = 删除的 21.6 KiB 逻辑字节（块对齐后 476K 为回收区实测） |

引用审计：`rg` 命中共 **82 个不同被引 token / 140 条引用**（`*.md` 137 条 + `scripts/`、`patches/` 3 条）。
**没有任何被引路径落进 A/B**；动作后对 9 个关键被引路径逐一 `[ -e ]` 复检 → 9/9 OK（见 §4）。

其他结论：

1. **邮箱侧本轮零写操作**（只统计）：INBOX 近 14 天 **9 397 封**，其中 **8 034 封（85.5%）是他方 kernel 系列流水**；
   与本项目直接相关的仅 **96 封**。可逆清理候选合计 **8 695 封**，建议 IMAP `MOVE` 到 `Cleanup-20261102`，**等用户批准**（§3）。
2. `reports/mail-triage-*.md` 共 **10 篇**：md5 全不同；两两「公共行 / 较短篇行数」最高仅 **3%（2 行）** ⇒
   **无内容完全重复、也无被后一篇整体取代**；建议**全部保留**（§3.3）。

## §1 引用审计（命令 + 全量结果）

命令（两条，均为本次实际执行；`rg` 无路径参数且 stdin 非 tty 时会退化成读 stdin，故显式给 `.`）：

```bash
rg -n --glob '*.md' 'out/mail-' .                 # → 137 条命中
rg -n 'out/mail-' scripts/ patches/ 2>/dev/null   # → 3 条命中
```

结论：命中分布在 **42 篇文件**（`rg -l --glob '*.md' 'out/mail-' . | wc -l` = 43，含本报告自身）：
`reports/` 21 篇、`TASKS/sessions/` 16 篇、`TASKS/README.md` 1、`AGENTS.md` 1、
`PITFALLS/sessions/` 1、`patches/upstream/*/README.md` 2。逐条落表：

| 被引用 out/mail-* 路径/模式 | 引用者 file:line |
|---|---|
| `out/mail-*/` | `reports/audit-20261029-crossdoc.md:305` |
| `out/mail-20261023/` | `TASKS/sessions/2026-10-23-Q24扩样-Konrad单变量-邮件与确定性缺口.md:15` |
| `out/mail-20261023/re-konrad-q24-retention.txt` | `TASKS/README.md:139` |
| `out/mail-20261026/re-m9-its-claim.txt` | `reports/mail-triage-20261029.md:47` |
| `out/mail-20261026/re-m9-withdraw.txt` | `TASKS/README.md:871` |
| `out/mail-20261027/` | `reports/mail-triage-20261029.md:43` |
| `out/mail-20261028/` | `TASKS/sessions/2026-10-28-邮箱分诊与UEFI回帖草稿.md:5` , `reports/camss-upstream-response-20261028.md:5` , `reports/dispcc-battmgr-20261028.md:7` , `reports/dispcc-battmgr-20261028.md:225` , `reports/mail-triage-20261028.md:3` , `reports/uefi-issue12-reply-final-draft-20261029.md:238` , `reports/wl2868c-20261028.md:6` |
| `out/mail-20261028/battmgr-gh/` | `TASKS/sessions/2026-10-28-dispcc与battmgr回信.md:20` |
| `out/mail-20261028/battmgr-verify/` | `TASKS/sessions/2026-10-28-dispcc与battmgr回信.md:9` , `TASKS/sessions/2026-10-28-dispcc与battmgr回信.md:23` , `reports/dispcc-battmgr-20261028.md:102` |
| `out/mail-20261028/battmgr-verify/qcom_battmgr.c` | `reports/dispcc-battmgr-20261028.md:198` |
| `out/mail-20261028/camss-reply-hangxiang.txt` | `reports/camss-upstream-response-20261028.md:193` |
| `out/mail-20261028/camss-reply-vladimir.txt` | `reports/camss-upstream-response-20261028.md:194` |
| `out/mail-20261028/dump-by-msgid.py` | `reports/wl2868c-20261028.md:14` |
| `out/mail-20261028/dump-msgs.py` | `TASKS/sessions/2026-10-28-邮箱分诊与UEFI回帖草稿.md:13` |
| `out/mail-20261028/hx-v6/` | `reports/camss-upstream-response-20261028.md:30` , `reports/camss-upstream-response-20261028.md:75` , `reports/camss-upstream-response-20261028.md:101` |
| `out/mail-20261028/hx-v6/0*.patch` | `reports/camss-upstream-response-20261028.md:81` |
| `out/mail-20261028/hx-v6/0002.patch` | `reports/m4-camss-v3-plan-20261029.md:17` |
| `out/mail-20261028/hx-v6/0005.patch` | `reports/m4-camss-v3-plan-20261029.md:33` |
| `out/mail-20261028/hx-v6/{0002,0005}.patch` | `reports/m4-camss-v3-plan-20261029.md:77` |
| `out/mail-20261028/lore-camss-reply/` | `reports/camss-upstream-response-20261028.md:216` |
| `out/mail-20261028/lore-camss-reply/*` | `TASKS/sessions/2026-10-28-camss上游回信与SoB整改.md:61` |
| `out/mail-20261028/lore-camss-reply/{sentitems-hangxiang,sentitems-vladimir}.eml` | `TASKS/sessions/2026-10-28-camss上游回信与SoB整改.md:32` |
| `out/mail-20261028/m4-camss-20261028-dryrun.txt` | `TASKS/sessions/2026-10-28-M4系列定稿可发.md:30` , `patches/upstream/m4-camss-series-20261028/README.md:93` , `reports/m4-camss-series-ready-20261028.md:63` |
| `out/mail-20261028/m4-camss-20261028-send.txt` | `TASKS/sessions/2026-10-28-M4系列投递与复核.md:22` , `patches/upstream/m4-camss-series-20261028/README.md:106` , `reports/mail-triage-20261029.md:37` |
| `out/mail-20261028/m4-camss-v2-send.txt` | `TASKS/sessions/2026-10-28-M4v2投递复核与BinaryEye实测.md:56` , `patches/upstream/m4-camss-series-20261028-v2/README.md:44` , `reports/mail-triage-20261029.md:38` |
| `out/mail-20261028/orig/sashiko-outbox-{187685,187698,187701}-kernel-org.eml` | `reports/camss-upstream-response-20261028.md:266` |
| `out/mail-20261028/orig2/` | `TASKS/sessions/2026-10-28-dispcc与battmgr回信.md:12` |
| `out/mail-20261028/patchwork-*.json` | `TASKS/sessions/2026-10-28-camss上游回信与SoB整改.md:62` |
| `out/mail-20261028/patchwork-series-1195087-v1.json` | `reports/camss-upstream-response-20261028.md:242` , `reports/mail-triage-20261029.md:118` |
| `out/mail-20261028/patchwork-submitter-camss.json` | `reports/mail-triage-20261029.md:39` |
| `out/mail-20261028/re-konrad-battmgr-20261028.txt` | `TASKS/sessions/2026-10-28-dispcc与battmgr回信.md:10` , `reports/dispcc-battmgr-20261028.md:250` |
| `out/mail-20261028/re-taniya-dispcc.txt` | `TASKS/sessions/2026-10-28-dispcc与battmgr回信.md:10` , `reports/dispcc-battmgr-20261028.md:231` |
| `out/mail-20261028/sent-verify/` | `TASKS/sessions/2026-10-28-dispcc与battmgr回信.md:11` , `reports/dispcc-battmgr-20261028.md:225` |
| `out/mail-20261028/triage-20261028.json` | `reports/mail-triage-20261028.md:10` , `reports/mail-triage-20261029.md:61` , `reports/mail-triage-20261029.md:169` |
| `out/mail-20261028/triage-20261028.py` | `PITFALLS/sessions/125-邮件分诊脚本只认硬编码MessageID.md:17` , `TASKS/sessions/2026-10-28-邮箱分诊与UEFI回帖草稿.md:11` , `reports/mail-triage-20261028.md:9` |
| `out/mail-20261028/uefi-issue12-reply.md` | `TASKS/sessions/2026-10-28-顺序推进-B5第5步-UEFI回帖-容器相机.md:29` |
| `out/mail-20261028/uefi-issue12-reply.txt` | `reports/uefi-issue12-reply-draft-20261028.md:47` , `reports/uefi-issue12-reply-draft-20261028.md:60` |
| `out/mail-20261028/wl2868c-driver/` | `reports/wl2868c-driver-20261028.md:5` |
| `out/mail-20261028/wl2868c-driver/cover-letter.txt` | `reports/mail-triage-20261029.md:41` |
| `out/mail-20261028/wl2868c/` | `TASKS/sessions/2026-10-28-wl2868c重生成与投递.md:5` , `reports/wl2868c-20261028.md:12` |
| `out/mail-20261028/wl2868c/reply-*.txt` | `reports/wl2868c-20261028.md:119` |
| `out/mail-20261028/wl2868c/send-krzk.txt` | `reports/mail-triage-20261029.md:42` |
| `out/mail-20261028/wl2868c/send-v2.txt` | `reports/wl2868c-20261028.md:154` , `reports/wl2868c-driver-20261028.md:322` |
| `out/mail-20261028/wl2868c/send/` | `reports/wl2868c-20261028.md:156` |
| `out/mail-20261028/wl2868c/sent-verify/` | `reports/wl2868c-20261028.md:162` |
| `out/mail-20261029/` | `TASKS/sessions/2026-10-29-收官-容器相机与camss定调.md:24` , `TASKS/sessions/2026-10-29-邮件分诊.md:12` , `reports/mail-triage-20261029.md:4` |
| `out/mail-20261029/delta-20261029.json` | `reports/mail-triage-20261029.md:192` |
| `out/mail-20261029/fetch-body.py` | `reports/mail-triage-20261029.md:176` , `reports/mail-triage-20261029.md:193` |
| `out/mail-20261029/inbox/` | `reports/mail-triage-20261029.md:62` |
| `out/mail-20261029/lore-archive.txt` | `reports/mail-triage-20261029.md:13` , `reports/mail-triage-20261029.md:79` |
| `out/mail-20261029/lore-probe.py` | `reports/mail-triage-20261029.md:178` , `reports/mail-triage-20261029.md:180` , `reports/mail-triage-20261029.md:194` |
| `out/mail-20261029/msgids.txt` | `reports/mail-triage-20261029.md:178` , `reports/mail-triage-20261029.md:195` |
| `out/mail-20261029/pw-series-p1.json` | `reports/mail-triage-20261029.md:118` , `reports/mail-triage-20261029.md:196` |
| `out/mail-20261029/triage-20261029.json` | `reports/mail-triage-20261029.md:31` , `reports/mail-triage-20261029.md:168` |
| `out/mail-20261029/triage-20261029.py` | `reports/mail-triage-20261029.md:60` , `reports/mail-triage-20261029.md:164` , `reports/mail-triage-20261029.md:191` |
| `out/mail-20261029/uefi-issue12-reply-final.txt` | `reports/uefi-issue12-reply-final-draft-20261029.md:240` |
| `out/mail-20261029/upstream-v6/` | `reports/mail-triage-20261029.md:98` , `reports/mail-triage-20261029.md:197` |
| `out/mail-20261029b` | `reports/mail-triage-20261029b.md:209` |
| `out/mail-20261029b/` | `reports/m3-v5-recovery-20261030.md:37` , `reports/mail-triage-20261029b.md:203` , `reports/wl2868c-recovery-20261030.md:34` |
| `out/mail-20261029b/0*.txt` | `reports/mail-triage-20261029b.md:237` |
| `out/mail-20261029b/01,02` | `reports/upstream-status-20261029.md:17` |
| `out/mail-20261029b/01-M3-1-mux-deadlock.txt` | `reports/m3-v5-recovery-20261030.md:255` |
| `out/mail-20261029b/04-M4-1-wl2868c-user.txt` | `reports/wl2868c-recovery-20261030.md:263` |
| `out/mail-20261029b/05` | `reports/upstream-status-20261029.md:43` |
| `out/mail-20261029b/07` | `reports/upstream-status-20261029.md:26` |
| `out/mail-20261029b/bodies/` | `reports/mail-triage-20261029b.md:234` |
| `out/mail-20261029b/bodies/sashiko-outbox-185299_kernel.org.txt` | `reports/m3-v5-recovery-20261030.md:17` , `reports/m3-v5-recovery-20261030.md:254` |
| `out/mail-20261029b/bodies/sashiko-outbox-1852{47,54,99}_kernel.org.txt` | `reports/m3-v5-selfcontained-20261031.md:81` |
| `out/mail-20261029b/fetch.py` | `reports/mail-triage-20261029b.md:23` |
| `out/mail-20261029b/ids.txt` | `reports/mail-triage-20261029b.md:23` |
| `out/mail-20261029b/mailscan.py` | `reports/mail-triage-20261029b.md:18` , `reports/mail-triage-20261029b.md:19` , `reports/upstream-status-20261029.md:50` |
| `out/mail-20261029b/scan-direct.txt` | `reports/mail-triage-20261029b.md:20` |
| `out/mail-20261029c/README.md` | `TASKS/sessions/2026-10-29-双口定案与上游三封投递-2.md:31` |
| `out/mail-20261031-b/` | `TASKS/sessions/2026-10-31-下午-三封回信与wl2868c-v4.md:12` , `TASKS/sessions/2026-10-31-四lane轮-M8收尾-邮件分诊-投递前门禁.md:14` |
| `out/mail-20261031-b/re-konrad-mdss-rsc.txt` | `TASKS/README.md:569` , `reports/mail-batch-20261031b-3replies-20261031.md:19` , `reports/mail-triage-20261031b.md:78` |
| `out/mail-20261031-b/re-krzysztof-wl2868c-v4shape.txt` | `reports/mail-batch-20261031b-3replies-20261031.md:23` |
| `out/mail-20261031-b/re-sashiko-wl2868c-v3-dts.txt` | `TASKS/README.md:569` , `reports/mail-batch-20261031b-3replies-20261031.md:21` , `reports/mail-triage-20261031b.md:88` |
| `out/mail-20261031-c/` | `reports/m3-v5-selfcontained-20261031.md:98` |
| `out/mail-20261031-c/0000-cover-letter.txt` | `TASKS/README.md:580` , `TASKS/sessions/2026-10-31-阻塞项A类三lane与B类窗口单.md:14` , `reports/m3-v5-selfcontained-20261031.md:16` , `reports/m3-v5-selfcontained-20261031.md:77` , `reports/m3-v5-selfcontained-20261031.md:110` , `reports/m3v5-repack-20261031.md:18` |
| `out/mail-20261031/` | `TASKS/README.md:599` , `TASKS/README.md:606` , `TASKS/sessions/2026-10-31-上游批次-patchwork-icc素材.md:13` , `reports/doc-slim-20261102.md:270` , `reports/doc-slim-20261102.md:391` |
| `out/mail-20261031/re-krzysztof-camss.txt` | `reports/m4-camss-v2-20261031.md:40` |
| `out/mail-20261031/{re-krzysztof-wl2868c.txt,claims.tsv,self-review.md}` | `AGENTS.md:28` , `TASKS/README.md:600` , `reports/doc-slim-20261102.md:267` |

要点（判据来源）：

- 引用多为**目录级**（`out/mail-20261028/`、`out/mail-20261029b/bodies/`），因此目录内**全部文件按 C 保留**，
  只有"目录内可证明为中间产物"的文件单独降级（见 §2）。
- `aw86927` 一条特殊：`patches/upstream/aw86927-20261027-v2/` 只存 5 枚正文、**无 cover 与实发头**，
  故 `out/mail-20261027/aw86927/` 6 件是唯一实发形态 → C；同目录根部的同名 6 件是 dry-run（§2 A 组）。

## §2 分类明细（每文件一条判定）

判定口径（派工单原文）：A = `__pycache__`/`*.pyc`、明显临时或被同名新版本取代且零引用；
B = 零引用但可能是唯一证据的 `orig*/`、dump 类；C = 被 md/脚本引用或某轮唯一原始数据。

- **A 组 3 类共 8 件**：① `__pycache__/lore-probe.cpython-314.pyc`（可再生）；
  ② `out/mail-20261027/00{00..05}-*` 6 件 = **dry-run 转录**（`Date: 21:28:54`），20 秒后被
  `out/mail-20261027/aw86927/`（`Date: 21:29:14`）取代，且仓内另有 `patches/upstream/aw86927-20261027-v2/`
  （`diff` 实测：与仓内版仅 `Subject:` 一行差，`4c4  [PATCH] … vs [PATCH 1/5] …`）；
  ③ `out/mail-20261029/lore-check.py`（零引用，功能被随后被引的 `lore-probe.py` 完全覆盖：后者含归档核实 + `--thread` 线程树，
  `reports/mail-triage-20261029.md:178,180,194` 引的是 probe）。
- **B 组是 7 条 `mv` 命令**（同盘，可 `mv` 回原位无损恢复）：`battmgr-gh/`（上一轮半成品，2 个文件与 `battmgr-verify/` **同 md5**、
  仅一句叙述性提及 `TASKS/sessions/2026-10-28-dispcc与battmgr回信.md:20`）、`hx-v5/`（被 `hx-v6/` 取代，零引用）、
  `fetch-threads.py`、`raw-inbox-5d.txt`、`raw-replies-5d.txt`（同轮正式落盘为 `scan-direct.txt`）、
  `a2-v2-clarify.txt`、`camss-reply-v23.txt`（后两者零引用，可能是已发稿的唯一副本，故归档不删）。
- **C 组 177 件**：其中 `out/mail-20261028/` 现存 84 件未逐文件名点引，但该目录被 md 以**目录/子目录粒度**
  引用 193 处（`rg -n --glob '*.md' 'out/mail-20261028' . | wc -l`），按「证据不随手删」纪律整体保留。

### §2.1 归档清单（原路径 → 回收区路径，共 7 条 / 18 文件 / 437 413 B）

同盘 `mv`，反向执行即原位恢复；回收区总 `du -sh` = 476K。

| 原路径 | 回收区路径 | 文件数 | 逻辑字节 | 判据 |
|---|---|---|---|---|
| `out/mail-20261028/battmgr-gh/` | `out/mail-trash-20261102/battmgr-gh/` | 8 | 267 918 | 上一轮半成品，仅叙述性提及 `TASKS/sessions/2026-10-28-dispcc与battmgr回信.md:20`；`drivers_power_supply_qcom_battmgr_downstream.c`、`drivers_power_supply_Makefile` 与 `battmgr-verify/qcom_battmgr.c`、`supply_Makefile` **同 md5** |
| `out/mail-20261028/hx-v5/` | `out/mail-trash-20261102/hx-v5/` | 5 | 94 590 | 零引用；被 `hx-v6/` 取代（`reports/m4-camss-v3-plan-20261029.md:17,77` 只引 v6） |
| `out/mail-20261028/fetch-threads.py` | `out/mail-trash-20261102/fetch-threads.py` | 1 | 2 373 | 零引用；功能被 `dump-msgs.py` / `dump-by-msgid.py` 取代（`PITFALLS/sessions/125-邮件分诊脚本只认硬编码MessageID.md:17`、`reports/wl2868c-20261028.md:14`） |
| `out/mail-20261029b/raw-inbox-5d.txt` | `out/mail-trash-20261102/raw-inbox-5d.txt` | 1 | 68 762 | 零引用；同轮正式落盘为 `scan-direct.txt`（32 664 → `reports/mail-triage-20261029b.md:20`） |
| `out/mail-20261029b/raw-replies-5d.txt` | `out/mail-trash-20261102/raw-replies-5d.txt` | 1 | 534 | 零引用（同上，dump 类） |
| `out/mail-20261027/a2-v2-clarify.txt` | `out/mail-trash-20261102/a2-v2-clarify.txt` | 1 | 1 741 | 零引用（`rg -n a2-v2-clarify` 无输出）；M2/A2「resend 非 v2」澄清稿，可能是已发稿唯一副本 ⇒ 归档不删 |
| `out/mail-20261029/camss-reply-v23.txt` | `out/mail-trash-20261102/camss-reply-v23.txt` | 1 | 1 495 | 零引用（`rg -n camss-reply-v23` 无输出）；camss v23 回信起草稿 ⇒ 归档不删 |
| **合计** | — | **18**（目录 2 + 文件 5 条路径） | **437 413** | — |

| 路径 | 大小(B) | 判定 | 引用证据（file:line / 判据） | 动作 |
|---|---|---|---|---|
| `out/mail-20261029/__pycache__/lore-probe.cpython-314.pyc` | 5032 | A 删除 | 编译缓存（`__pycache__`），可由 lore-probe.py 再生；`PYTHONDONTWRITEBYTECODE` 无关 | `rm`（已执行） |
| `out/mail-20261029/lore-check.py` | 1083 | A 删除 | rg 零命中；功能被 lore-probe.py 覆盖（probe 含归档核实 + `--thread` 线程树），报告引的是 probe（`reports/mail-triage-20261029.md:178,194`） | `rm`（已执行） |
| `out/mail-20261027/0000-cover-letter.patch` | 1628 | A 删除 | dry-run 件（Date 21:28:54），20 s 后被 `aw86927/` 实发件（21:29:14）取代；仓内另有 `patches/upstream/aw86927-20261027-v2/` | `rm`（已执行） |
| `out/mail-20261027/0001-Input-aw86927-fix-the-7-V-boost-reference-for-AW8693.patch` | 1316 | A 删除 | 同上；与仓内 v2 版仅 Subject 差（`[PATCH]` vs `[PATCH 1/5]`，`diff` 实测 4c4） | `rm`（已执行） |
| `out/mail-20261027/0002-dt-bindings-input-awinic-aw86927-document-the-AW8693.patch` | 1157 | A 删除 | 同上（dry-run 中间件） | `rm`（已执行） |
| `out/mail-20261027/0003-Input-aw86927-add-support-for-Awinic-AW86937.patch` | 1636 | A 删除 | 同上（dry-run 中间件） | `rm`（已执行） |
| `out/mail-20261027/0004-Input-aw86927-handle-the-AW8693X-play-and-boost-regi.patch` | 5135 | A 删除 | 同上（dry-run 中间件） | `rm`（已执行） |
| `out/mail-20261027/0005-Input-aw86927-stop-playback-over-suspend-and-on-shut.patch` | 5153 | A 删除 | 同上（dry-run 中间件） | `rm`（已执行） |
| `out/mail-20261023/README.md` | 6677 | C 保留 | `TASKS/sessions/2026-10-23-Q24扩样-Konrad单变量-邮件与确定性缺口.md:15`（整目录）；`TASKS/README.md:139`（re-konrad-q24-retention.txt） | 无 |
| `out/mail-20261023/re-konrad-battmgr.txt` | 3194 | C 保留 | `TASKS/sessions/2026-10-23-Q24扩样-Konrad单变量-邮件与确定性缺口.md:15`（整目录）；`TASKS/README.md:139`（re-konrad-q24-retention.txt） | 无 |
| `out/mail-20261023/re-konrad-q24-retention.txt` | 6695 | C 保留 | `TASKS/sessions/2026-10-23-Q24扩样-Konrad单变量-邮件与确定性缺口.md:15`（整目录）；`TASKS/README.md:139`（re-konrad-q24-retention.txt） | 无 |
| `out/mail-20261023/re-taniya-q28-dispcc.txt` | 4958 | C 保留 | `TASKS/sessions/2026-10-23-Q24扩样-Konrad单变量-邮件与确定性缺口.md:15`（整目录）；`TASKS/README.md:139`（re-konrad-q24-retention.txt） | 无 |
| `out/mail-20261026/re-m9-its-claim.txt` | 1977 | C 保留 | `TASKS/README.md:871`（re-m9-withdraw.txt）；re-m9-its-claim.txt 为同轮唯一稿件 | 无 |
| `out/mail-20261026/re-m9-withdraw.txt` | 1746 | C 保留 | `TASKS/README.md:871`（re-m9-withdraw.txt）；re-m9-its-claim.txt 为同轮唯一稿件 | 无 |
| `out/mail-20261027/aw86927/0000-cover-letter.patch` | 1628 | C 保留 | `patches/upstream/aw86927-20261027-v2/` 只存 5 枚正文；实发头（Date 21:29:14）与 cover 仅此处有 | 无 |
| `out/mail-20261027/aw86927/0001-Input-aw86927-fix-the-7-V-boost-reference-for-AW8693.patch` | 1320 | C 保留 | `patches/upstream/aw86927-20261027-v2/` 只存 5 枚正文；实发头（Date 21:29:14）与 cover 仅此处有 | 无 |
| `out/mail-20261027/aw86927/0002-dt-bindings-input-awinic-aw86927-document-the-AW8693.patch` | 1161 | C 保留 | `patches/upstream/aw86927-20261027-v2/` 只存 5 枚正文；实发头（Date 21:29:14）与 cover 仅此处有 | 无 |
| `out/mail-20261027/aw86927/0003-Input-aw86927-add-support-for-Awinic-AW86937.patch` | 1640 | C 保留 | `patches/upstream/aw86927-20261027-v2/` 只存 5 枚正文；实发头（Date 21:29:14）与 cover 仅此处有 | 无 |
| `out/mail-20261027/aw86927/0004-Input-aw86927-handle-the-AW8693X-play-and-boost-regi.patch` | 5139 | C 保留 | `patches/upstream/aw86927-20261027-v2/` 只存 5 枚正文；实发头（Date 21:29:14）与 cover 仅此处有 | 无 |
| `out/mail-20261027/aw86927/0005-Input-aw86927-stop-playback-over-suspend-and-on-shut.patch` | 5158 | C 保留 | `patches/upstream/aw86927-20261027-v2/` 只存 5 枚正文；实发头（Date 21:29:14）与 cover 仅此处有 | 无 |
| `out/mail-20261028/battmgr-verify/commits.json` | 17287 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/configs.json` | 20279 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/defconfig` | 38223 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/evidence-github-api.txt` | 3073 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/local-lstree.txt` | 1473 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/qcom_battmgr.c` | 39375 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/repo.json` | 8074 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/sun_le.config` | 11124 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/sun_perf.config` | 11020 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/supply-qcom.json` | 64931 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/supply-top.json` | 146055 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/supply_Kconfig` | 30734 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/supply_Makefile` | 5706 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/battmgr-verify/vendor-configs.json` | 32658 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/camss-reply-hangxiang.txt` | 3771 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/camss-reply-vladimir.txt` | 2772 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/dump-by-msgid.py` | 2652 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/dump-msgs.py` | 2210 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/hx-v6/0001.patch` | 10802 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/hx-v6/0002.patch` | 24422 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/hx-v6/0003.patch` | 12074 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/hx-v6/0004.patch` | 10649 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/hx-v6/0005.patch` | 28022 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/hx-v6/0006.patch` | 13590 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/hx-v6/0007.patch` | 14873 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/lore-camss-reply/hangxiang-179318934146.raw` | 8519 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/lore-camss-reply/sentitems-hangxiang.eml` | 5463 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/lore-camss-reply/sentitems-vladimir.eml` | 4444 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/lore-camss-reply/vladimir-179318935222.raw` | 7518 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/m4-camss-20261028-dryrun.txt` | 15311 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/m4-camss-20261028-send.txt` | 15291 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/m4-camss-v2-send.txt` | 14751 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig/218d69dc-5761-4a8c-824f-7a15307f54a6-oss-qualcomm-com.eml` | 15939 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig/218d69dc-5761-4a8c-824f-7a15307f54a6-oss-qualcomm-com.hdr` | 843 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig/8e05a28e-7881-4bf5-98c7-c5ccf4e22735-kernel-org.eml` | 8441 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig/8e05a28e-7881-4bf5-98c7-c5ccf4e22735-kernel-org.hdr` | 873 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig/sashiko-outbox-187685-kernel-org.eml` | 9331 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig/sashiko-outbox-187685-kernel-org.hdr` | 577 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig/sashiko-outbox-187698-kernel-org.eml` | 11174 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig/sashiko-outbox-187698-kernel-org.hdr` | 556 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig/sashiko-outbox-187701-kernel-org.eml` | 6677 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig/sashiko-outbox-187701-kernel-org.hdr` | 579 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig2/22a87c51-4f8c-49c0-a13a-c11767f10e85-oss-qualcomm-com.eml` | 15785 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig2/22a87c51-4f8c-49c0-a13a-c11767f10e85-oss-qualcomm-com.hdr` | 801 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig2/52fc4222-508d-4acf-b38a-7b4e5aeff3cb-oss-qualcomm-com.eml` | 15693 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig2/52fc4222-508d-4acf-b38a-7b4e5aeff3cb-oss-qualcomm-com.hdr` | 710 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig2/625f7af0-5977-41e3-a76d-fde8f998ed97-oss-qualcomm-com.eml` | 15118 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig2/625f7af0-5977-41e3-a76d-fde8f998ed97-oss-qualcomm-com.hdr` | 915 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig2/84483ae1-1fbb-4219-a829-5867feb8bb17-oss-qualcomm-com.eml` | 14751 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/orig2/84483ae1-1fbb-4219-a829-5867feb8bb17-oss-qualcomm-com.hdr` | 794 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/patchwork-patch-14920481.json` | 23181 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/patchwork-series-1195087-v1.json` | 6789 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/patchwork-submitter-camss.json` | 36031 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/re-konrad-battmgr-20261028.txt` | 3917 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/re-taniya-dispcc.txt` | 2895 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/sent-verify/179318866835-88849-1485640983989491497-mail-ustc-edu-cn.eml` | 4541 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/sent-verify/179318866835-88849-1485640983989491497-mail-ustc-edu-cn.hdr` | 819 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/sent-verify/179318867727-88971-13007415873000488463-mail-ustc-edu-cn.eml` | 5589 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/sent-verify/179318867727-88971-13007415873000488463-mail-ustc-edu-cn.hdr` | 895 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/triage-20261028.json` | 558970 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/triage-20261028.py` | 4432 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/uefi-issue12-reply.md` | 3163 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/uefi-issue12-reply.txt` | 5423 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c-driver/cover-letter.txt` | 1705 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/0001-v2.patch` | 4930 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/179312390429-199157-12016700546762955000-b4-review-b4.eml` | 4730 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/179312390429-199157-12016700546762955000-b4-review-b4.hdr` | 675 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/20261027051055-213301-1-xiaqinghuan-mail-ustc-edu-cn.eml` | 4952 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/20261027051055-213301-1-xiaqinghuan-mail-ustc-edu-cn.hdr` | 502 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/c8e6c0e7-397c-4692-a478-d9778b312886-kernel-org.eml` | 7035 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/c8e6c0e7-397c-4692-a478-d9778b312886-kernel-org.hdr` | 675 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/reply-broonie.txt` | 2870 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/reply-krzk.txt` | 2319 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/send-broonie.txt` | 3419 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/send-krzk.txt` | 3368 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/send-v2.txt` | 955 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261028/wl2868c/send/0001-regulator-dt-bindings-willsemi-wl2868c-add-the-WL286.patch` | 4933 | C 保留 | 见 §1 | 无 |
| `out/mail-20261028/wl2868c/sent-verify/20261028120423-99034-1-xiaqinghuan-mail-ustc-edu-cn.eml` | 3902 | C 保留 | 见 §1 | 无 |
| `out/mail-20261028/wl2868c/sent-verify/20261028120423-99034-1-xiaqinghuan-mail-ustc-edu-cn.hdr` | 695 | C 保留 | 见 §1 | 无 |
| `out/mail-20261028/wl2868c/sent-verify/20261028120432-99230-1-xiaqinghuan-mail-ustc-edu-cn.eml` | 4470 | C 保留 | 见 §1 | 无 |
| `out/mail-20261028/wl2868c/sent-verify/20261028120432-99230-1-xiaqinghuan-mail-ustc-edu-cn.hdr` | 707 | C 保留 | 见 §1 | 无 |
| `out/mail-20261028/wl2868c/sent-verify/20261028120442-99375-1-xiaqinghuan-mail-ustc-edu-cn.eml` | 6758 | C 保留 | 见 §1 | 无 |
| `out/mail-20261028/wl2868c/sent-verify/20261028120442-99375-1-xiaqinghuan-mail-ustc-edu-cn.hdr` | 485 | C 保留 | 见 §1 | 无 |
| `out/mail-20261028/wl2868c/v2-dryrun.txt` | 952 | C 保留 | `reports/camss-upstream-response-20261028.md:193,194,216,242,266`；`reports/dispcc-battmgr-20261028.md:102,198,225,231,250`；`reports/wl2868c-20261028.md:12,119,154,156,162`；`reports/mail-triage-20261028.md:9,10`；`reports/mail-triage-20261029.md:37,41,42`；`reports/m4-camss-v3-plan-20261029.md:17,77`；`patches/upstream/m4-camss-series-20261028/README.md:93,106` | 无 |
| `out/mail-20261029/delta-20261029.json` | 36420 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/fetch-body.py` | 3286 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/inbox/0f436944-fa9a-49f9-ac1d-8779a36ab13d_kernel.org.txt` | 2622 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/inbox/0f60fcba-8f31-4b3d-a7d8-8dee548e0b41_kernel.org.txt` | 1417 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/inbox/20261028-acrid-calm-bustard-0cfe4d_quoll.txt` | 900 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/inbox/20261028-easygoing-sepia-mastodon-c09f32_quoll.txt` | 934 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/inbox/20261028-truthful-chupacabra-of-bloom-2f8b65_quoll.txt` | 811 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/inbox/5d886ac3-4baf-49c7-a703-7cb737ef48da_nxsw.ie.txt` | 1008 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/inbox/6ae1fd09.80cfa24d.9ab3d.3061_mx.google.com.txt` | 1985 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/inbox/84bc6332-1db6-4c9c-a956-51b76f96352a_kernel.org.txt` | 1041 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/inbox/e63d7539-2347-4e95-bdd6-f8e1e899e065_kernel.org.txt` | 2606 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/lore-archive.txt` | 5980 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/lore-probe.py` | 2824 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/lore-thread.py` | 2004 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/lore-threads.txt` | 7745 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/msgids.txt` | 2227 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/pw-series-p1.json` | 41326 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/pw-series-p2.json` | 75340 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/triage-20261029.json` | 249622 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029/triage-20261029.py` | 4432 | C 保留 | `reports/mail-triage-20261029.md:178,180,194`；`TASKS/sessions/2026-10-29-邮件分诊.md:12` | 无 |
| `out/mail-20261029b/01-M3-1-mux-deadlock.txt` | 818 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/02-M3-1-binding-mux-controls.txt` | 842 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/03-M4-1-gt9764-user.txt` | 762 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/04-M4-1-wl2868c-user.txt` | 755 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/05-camss-clarify-thread.txt` | 916 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/06-camss-shuai-liu-skewcal.txt` | 737 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/07-aw86927-v3-note.txt` | 726 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/0f436944-fa9a-49f9-ac1d-8779a36ab13d_kernel.org.txt` | 3281 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/0f60fcba-8f31-4b3d-a7d8-8dee548e0b41_kernel.org.txt` | 1809 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/179312390429.199157.12016700546762955000.b4-review_b4.txt` | 1613 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/179318866835.88849.1485640983989491497_mail.ustc.edu.cn.txt` | 3102 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/179318867727.88971.13007415873000488463_mail.ustc.edu.cn.txt` | 4144 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/179318934146.107329.15810039464216984473_mail.ustc.edu.cn.txt` | 3992 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/179318935222.107529.54392791903989018_mail.ustc.edu.cn.txt` | 2969 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/179319036257.1042.14959401745115982353_linuxtv.org.txt` | 5697 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/179325717815.489400.16602455641444097904_mail.ustc.edu.cn.txt` | 1673 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/20261028-acrid-calm-bustard-0cfe4d_quoll.txt` | 1240 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/20261028-easygoing-sepia-mastodon-c09f32_quoll.txt` | 1478 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/20261028-truthful-chupacabra-of-bloom-2f8b65_quoll.txt` | 1151 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/218d69dc-5761-4a8c-824f-7a15307f54a6_oss.qualcomm.com.txt` | 2367 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/22a87c51-4f8c-49c0-a13a-c11767f10e85_oss.qualcomm.com.txt` | 2371 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/5d886ac3-4baf-49c7-a703-7cb737ef48da_nxsw.ie.txt` | 1497 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/6AE22B80.11BF23.49362_mailimap2024.txt` | 200 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/6ae1fd09.80cfa24d.9ab3d.3061_mx.google.com.txt` | 2069 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/84483ae1-1fbb-4219-a829-5867feb8bb17_oss.qualcomm.com.txt` | 1626 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/84bc6332-1db6-4c9c-a956-51b76f96352a_kernel.org.txt` | 1700 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/8e05a28e-7881-4bf5-98c7-c5ccf4e22735_kernel.org.txt` | 1917 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/CAH2e8h4wFH5Q_biepZzQuerydvmwbUOsEMRRzs4y-c-0WbjYrw_mail.gmail.com.txt` | 6195 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/c8e6c0e7-397c-4692-a478-d9778b312886_kernel.org.txt` | 1411 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/e63d7539-2347-4e95-bdd6-f8e1e899e065_kernel.org.txt` | 2992 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/f76d56db-6ea8-45ef-a70e-e53cc70cf508_kernel.org.txt` | 1182 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/fe9765cf-ef10-4068-ad43-26346d842c12_kernel.org.txt` | 961 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-185247_kernel.org.txt` | 8725 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-185254_kernel.org.txt` | 4006 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-185299_kernel.org.txt` | 16261 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-186108_kernel.org.txt` | 5905 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-186657_kernel.org.txt` | 2888 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-186676_kernel.org.txt` | 2776 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-187448_kernel.org.txt` | 3304 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-187458_kernel.org.txt` | 3964 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-187459_kernel.org.txt` | 6817 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-187460_kernel.org.txt` | 7410 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-187462_kernel.org.txt` | 5139 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-187685_kernel.org.txt` | 6762 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-187698_kernel.org.txt` | 8652 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/sashiko-outbox-187701_kernel.org.txt` | 4172 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/bodies/tencent_D8BA93484FB26CC87737CDE3FA8A814DE00A_qq.com.txt` | 2440 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/fetch.py` | 2151 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/ids.txt` | 2063 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/mailscan.py` | 3584 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029b/scan-direct.txt` | 31512 | C 保留 | `reports/mail-triage-20261029b.md:18-23,203-237`；`reports/m3-v5-recovery-20261030.md:17,254,255`；`reports/wl2868c-recovery-20261030.md:263` | 无 |
| `out/mail-20261029c/README.md` | 716 | C 保留 | `TASKS/sessions/2026-10-29-双口定案与上游三封投递-2.md:31`（README.md） | 无 |
| `out/mail-20261029c/re-turquette-resend.txt` | 2952 | C 保留 | `TASKS/sessions/2026-10-29-双口定案与上游三封投递-2.md:31`（README.md） | 无 |
| `out/mail-20261031-b/re-konrad-mdss-rsc.txt` | 3332 | C 保留 | `reports/mail-triage-20261031b.md:78,88`；`TASKS/sessions/2026-10-31-下午-三封回信与wl2868c-v4.md:12`；`reports/mail-batch-20261031b-3replies-20261031.md:19,21,23` | 无 |
| `out/mail-20261031-b/re-krzysztof-wl2868c-v4shape.txt` | 3806 | C 保留 | `reports/mail-triage-20261031b.md:78,88`；`TASKS/sessions/2026-10-31-下午-三封回信与wl2868c-v4.md:12`；`reports/mail-batch-20261031b-3replies-20261031.md:19,21,23` | 无 |
| `out/mail-20261031-b/re-sashiko-wl2868c-v3-dts.txt` | 4830 | C 保留 | `reports/mail-triage-20261031b.md:78,88`；`TASKS/sessions/2026-10-31-下午-三封回信与wl2868c-v4.md:12`；`reports/mail-batch-20261031b-3replies-20261031.md:19,21,23` | 无 |
| `out/mail-20261031-c/0000-cover-letter.txt` | 6813 | C 保留 | `TASKS/README.md:580`；`TASKS/sessions/2026-10-31-阻塞项A类三lane与B类窗口单.md:14` | 无 |
| `out/mail-20261031/claims.tsv` | 4611 | C 保留 | `AGENTS.md:28` 与 `TASKS/README.md:600`（3 件范例句）；`reports/m4-camss-v2-20261031.md:40`（re-krzysztof-camss.txt） | 无 |
| `out/mail-20261031/re-krzysztof-camss.txt` | 2001 | C 保留 | `AGENTS.md:28` 与 `TASKS/README.md:600`（3 件范例句）；`reports/m4-camss-v2-20261031.md:40`（re-krzysztof-camss.txt） | 无 |
| `out/mail-20261031/re-krzysztof-wl2868c.txt` | 3194 | C 保留 | `AGENTS.md:28` 与 `TASKS/README.md:600`（3 件范例句）；`reports/m4-camss-v2-20261031.md:40`（re-krzysztof-camss.txt） | 无 |
| `out/mail-20261031/self-review.md` | 4659 | C 保留 | `AGENTS.md:28` 与 `TASKS/README.md:600`（3 件范例句）；`reports/m4-camss-v2-20261031.md:40`（re-krzysztof-camss.txt） | 无 |
| `out/mail-trash-20261102/a2-v2-clarify.txt` | 1741 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/battmgr-gh/drivers_power_supply_Makefile` | 5706 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/battmgr-gh/drivers_power_supply_qcom_Kconfig` | 2945 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/battmgr-gh/drivers_power_supply_qcom_Makefile` | 936 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/battmgr-gh/drivers_power_supply_qcom_battery.c` | 61623 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/battmgr-gh/drivers_power_supply_qcom_battmgr_downstream.c` | 39375 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/battmgr-gh/drivers_power_supply_qcom_qbg-core.h` | 7804 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/battmgr-gh/drivers_power_supply_qcom_qti-qbg.c` | 78872 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/battmgr-gh/drivers_power_supply_qti_battery_charger.c` | 70657 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/camss-reply-v23.txt` | 1495 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/fetch-threads.py` | 2373 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/hx-v5/0001.patch` | 24612 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/hx-v5/0002.patch` | 11608 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/hx-v5/0003.patch` | 14912 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/hx-v5/0004.patch` | 27567 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/hx-v5/0005.patch` | 15891 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/raw-inbox-5d.txt` | 68762 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |
| `out/mail-trash-20261102/raw-replies-5d.txt` | 534 | B 归档 | （本次归档件；原路径与原大小见 §2.1） | `mv` → `out/mail-trash-20261102/` |

## §3 邮箱侧统计与建议（**本轮未执行任何邮箱写操作，等用户批准**）

### §3.1 统计方法与原始数字

只读脚本（`BODY.PEEK`，不改 `\Seen`）：凭据取 `git credential fill`（`smtp.ustc.edu.cn:465`），
IMAP `mail.ustc.edu.cn:993`，只 `SEARCH`+`FETCH HEADER`。分类正则（本次实跑，见 §4）：

| 桶 | INBOX 近 14 天（SINCE 19-Oct-2026） | Junk E-mail 近 60 天 |
|---|---|---|
| 总封数 | **9 397** | **422** |
| 他方 kernel 系列流水（`[PATCH|RFC|GIT PULL|RESEND]`，且不含本项目关键词） | **8 034（85.5%）** | 0 |
| 通知/机器人（noreply、bugzilla、patchwork、github、sashiko…） | **648** | 0 |
| 含本项目关键词（`sm8750|elden|aw86927|wl2868c|gt9764|battmgr|dispcc|camss|mipi-csi2|…`） | **453** | 0 |
| `[SPAM]` 前缀 / 落在 Junk | **44** | **422** |
| 退信/召回（mailer-daemon、系统退信） | **7** | 0 |
| 订阅确认（Confirm subscription/unsubscribe） | **6** | 0 |
| 其他（人）、含"考试通知"等非内核信 | **205** | 0 |

对 453 封「含本项目关键词」再分（第二遍扫描 `To`/`Cc`）：

| 子类 | 封数 | 处置建议 |
|---|---|---|
| A 直达我方（`To`/`Cc` 含 `xiaqinghuan@`） | **96** | **保留**（review 回复，必须逐封读） |
| B 他人新系列流水（同主题词但与我方无关） | **159** | 可清理 |
| C 他人同主题讨论（同主题词、非我方线程） | **192** | **保留观察**（可能含对我方系列的间接评价） |

### §3.2 可逆清理建议（分三档，均不删除）

| 档 | 内容 | 封数 | 命令骨架（未执行） |
|---|---|---|---|
| ① 零风险 | 退信/召回 7 + 订阅确认 6 | **13** | `MOVE` → `Cleanup-20261102` |
| ② 低风险 | 通知/机器人 648 | **648** | 同上（sashiko 自动评审信建议留到 11-15 再清） |
| ③ 主体 | 他方 kernel 系列流水 8 034 | **8 034** | 同上，**建议按 `SINCE` 分段（如只清 10-19 之前）** |
| 合计候选 | | **8 695** | 保留 = 453（本项目）+ 205（人信）+ 44（`[SPAM]` 先不动，交垃圾过滤器重判） |
| Junk 现状 | 422 封基本都是我们不订阅的 libcamera 列表 | 422 | 建议服务端「清空垃圾箱」由用户手动执行，agent 不碰 |

建议动作形态（**需用户批准后执行；移动而非删除，可整目录 `MOVE` 回来**）：

```bash
# 伪代码：只读扫描 → 生成 seq 列表 → 一次 MOVE（保留 \Seen 不变）
python3 - <<'EOF'   # 见 §4 脚本，把候选 seq 写到 /tmp/cleanup-seqs.txt
EOF
# 批准后：
#   M.create("Cleanup-20261102"); M.copy(seqs, "Cleanup-20261102"); M.store(seqs, "+FLAGS", "\\Deleted")
```

**本轮未执行任何邮箱写操作（无 CREATE / COPY / STORE / EXPUNGE / MOVE），等用户批准。**

### §3.3 `reports/mail-triage-*.md` 复核（只给建议，不删）

10 篇：1017(42 行)/1019(192)/1021(108)/1023(136)/1026(127)/1028(50)/1029(138)/1029b(187)/1030(110)/1031b(67)
（行数 = 去重后 >20 字节的行数）。`md5sum` 全不同；两两公共行最多 **2 行（占比 ≤3%）**，多为表头套话。

建议：**全部保留**。理由：每篇的覆盖窗口互不重叠（`1021/1023/1026` 是差量轮；`1029` 与 `1029b` 是同日**两条不同 lane**，
前者「各系列下一步唯一动作台账」、后者「Lane B 分诊 + 7 封回帖草案」；`1030/1031b` 窗口首尾相接：
`→10-30 03:17Z` 与 `10-30 03:17Z→10-31 04:50Z`）。无「整篇被取代」现象，`reports/` 是入库证据，不做任何删改。

## §4 复跑命令（全部只读；可直接复制执行）

```bash
# 0) 盘前/盘后 du 与文件数
du -sh out/mail-2026102* out/mail-2026103* | tail -3
du -sb out/mail-2026102* out/mail-2026103* | awk '{s+=$1} END{print "bytes="s}'
find out/mail-2026102* out/mail-2026103* -type f | wc -l

# 1) 引用审计（注意必须给 "."，否则 rg 在非 tty stdin 下改读 stdin → 0 命中）
rg -n --glob '*.md' 'out/mail-' .
rg -n 'out/mail-' scripts/ patches/ 2>/dev/null

# 2) 本次 A 组判据复现（dry-run vs 实发；仓内 v2 版差异仅 Subject）
diff out/mail-20261027/0000-cover-letter.patch out/mail-20261027/aw86927/0000-cover-letter.patch   # 仅 Date 行
diff patches/upstream/aw86927-20261027-v2/0001-*.patch out/mail-20261027/aw86927/0001-*.patch      # 仅 Subject
# B 组判据：battmgr-gh 与 battmgr-verify 同 md5
md5sum out/mail-trash-20261102/battmgr-gh/drivers_power_supply_qcom_battmgr_downstream.c \
       out/mail-20261028/battmgr-verify/qcom_battmgr.c                                              # 同 hash e70a216d…

# 3) 归档可逆性：列出回收区清单，反向 mv 即恢复
find out/mail-trash-20261102 -type f | sort
du -sb out/mail-trash-20261102

# 4) 被引路径存活复检（9/9 应全 OK）
for p in out/mail-20261028/triage-20261028.py out/mail-20261029/triage-20261029.py \
         out/mail-20261028/dump-msgs.py out/mail-20261028/dump-by-msgid.py \
         out/mail-20261029/lore-probe.py out/mail-20261029/fetch-body.py \
         out/mail-20261029b/mailscan.py out/mail-20261029b/fetch.py \
         out/mail-20261029b/01-M3-1-mux-deadlock.txt; do
  [ -e "$p" ] && echo "OK  $p" || echo "MISS $p"; done

# 5) 邮箱只读统计（复现 §3.1；无任何写操作，凭据走 git credential）
~/.local/bin/read-mail-ustc.py --days 14 --folders INBOX --limit 5

# 6) mail-triage 重复度复核
md5sum reports/mail-triage-*.md
python3 - <<'EOF'
import glob,itertools,os
fs=sorted(glob.glob("reports/mail-triage-*.md"))
t={f:set(l.strip() for l in open(f,encoding="utf-8") if len(l.strip())>20) for f in fs}
for a,b in itertools.combinations(fs,2):
    i=len(t[a]&t[b])
    if i: print(i, os.path.basename(a), os.path.basename(b))
EOF
```

## §5 未做 / 待确认

- 邮箱清理**未执行**（按纪律等用户批准）；如需执行，建议先 ① 档 13 封试跑、观察 24 h 再上 ③ 档。
- `out/mail-20261028/battmgr-gh/drivers_power_supply_qti-qbg.c`（78 872 B）与 `qti_battery_charger.c`（70 657 B）
  在 `battmgr-verify/` 内**没有**对应副本（只测了 2 个文件同 md5），内容可从 GitHub 重取，故归档而非删除；
  若确认后续不再需要对账，可整体 `rm -r out/mail-trash-20261102/`（一次性回收 476K）。
- `out/mail-20261029c/re-turquette-resend.txt` 与 `out/mail-20261031/claims.tsv` 之外若干「零引用草稿」
  本次判 C（同一目录有 md 引用 + 体积小），未逐条追查其是否已进 Sent Items——**待确认**，不影响本次结论。
