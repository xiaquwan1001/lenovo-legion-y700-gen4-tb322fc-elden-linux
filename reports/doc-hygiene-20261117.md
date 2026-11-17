# 文档/工具/工件卫生清理报告 (2026-11-17)

> lane: 整理类。只读核查为主；无邮件、无 push、无设备改动、无 commit、无删除。
> 状态: **完成**（§1–§6 全部落盘；门禁收尾 FAIL=0 WARN=2）

## 结论速览

| 节 | 项 | 结果 |
|---|---|---|
| §1 | `check-doctor.sh` 基线 | **FAIL=0 WARN=3**（+1 为本次新建报告自身「无人引用」，属自查副作用） |
| §1 | `check-progress-counts.sh --tsv` | G1 **36/37**（🟡1）；G2 **10/13**（🟡2 ⬜1） |
| §2 | HISTORY/days 落后 WARN | **已修**：重生成 51 个日文件；`--check` 「落后 2 条」→「OK: 对账一致」（1346=1346） |
| §2 | vk 账本例外（~70 条）/ 4 个 boot 内核段不可读 | **存量豁免，未动** |
| §3 | `versions/scripts-inventory.tsv` | **已修**：落后 4 处（缺 `scripts/mail-draft-check.py`）→ 重生成，现 **368 条**（LIVE 304 / HIST-ONLY 64 / UNREFERENCED 0） |
| §4 | 三处上游口径对账 | 4 项已发系列三处**全一致**；发现 6 处不一致，**修 2 处**（Q21 行、INDEX §0 的 m8-mdss v4），**报告 4 处** |
| §5 | `/tmp` 与工作区占用 | `/tmp/pi-fabric-runs-*` **0 个**；`~/.cache/pi-tmp` **4.4 G**（其中 fabric runs 33 个 / 2.7 G）；项目 **89 G**；未跟踪 >50MB = **0** |
| §6 | 收尾门禁 | **FAIL=0 WARN=2**（WARN 3→2，唯一消除项 = HISTORY 落后；新增的「报告无人引用」已挂指针消掉） |

---

## §1 门禁基线

命令（可复现）：

```bash
cd /home/xuqianhui/y700-elden
timeout -k 5 180 bash scripts/check-doctor.sh              # 汇总: FAIL=0  WARN=3
timeout -k 5 120 bash scripts/check-progress-counts.sh --tsv
```

### 1.1 门禁汇总

`check-doctor.sh` 基线：**FAIL=0  WARN=3**（16 个 section，逐节 [ok]）。

> 注：本次运行实际打出 `WARN=4`，多出的一条是本节报告文件自身（§8『报告无人引用』）——
> 文件是本轮新建，属「自己在查自己」，不计入基线；收尾时若仍未挂指针则如实列出（见 §6）。

### 1.2 三个 WARN 定性

| # | WARN 原文（截断） | 定性 | 处置 |
|---|---|---|---|
| W1 | `账本已登记的例外（理由见 vk-ledger-known-issues.tsv）`：约 70 个 vk 条目（`uts_dup14`/`uts_dup12`/`uts_dup7`/`num_ne_tag(...)`） | **已登记豁免**（存量，理由已在 `versions/vk-ledger-known-issues.tsv`） | 不动 |
| W2 | `内核段不可读（boot 镜像但载荷解不出）`：`boot-elden-posctrl-markspin{,2,3}{,-gz3}-v2-20261103.img`（4 个） | **存量不阻塞**（门禁自身提示「勿再据其做构建身份判断」） | 不动（设备断电，不重出镜像） |
| W3 | `HISTORY/days 落后（未覆盖 HEAD 3e384f4be6 或 HEAD~1 076668972d）` | **本轮可修** | §2 已修 |

### 1.3 进度计数（现查）

`check-progress-counts.sh --tsv`：

| 组 | total | cancelled | in_scope | complete | partial | detail |
|---|---|---|---|---|---|---|
| G1 | 39 | 2 | 37 | 36 | 1 | ✅33 🟢3 🟡1 ❌2 |
| G2 | 13 | 0 | 13 | 10 | 3 | ✅7 🟢2 🎯1 🟡2 ⬜1 |

与 `TASKS/README.md` §0 手写数字一致性由 doctor §16 覆盖：`[ok] §0 手写 G1/G2 数字与脚本现算一致`。

DONE: §1 门禁基线

---

## §2 可修 WARN 清理

### 2.1 HISTORY/days（WARN W3，可修 → 已修）

修前对账：

```
$ timeout -k 5 120 bash scripts/gen-history.sh --check
days 条目合计 = 1344
git rev-list --count HEAD = 1297（含回填历史分支 = 1346）
落后 2 条 — 收尾时跑一次 scripts/gen-history.sh
```

执行（脚本幂等，未变化日文件不产生 diff）：

```
$ timeout -k 5 120 bash scripts/gen-history.sh
生成 51 个日文件（abbrev=10）
```

修后：

```
$ bash scripts/gen-history.sh --check
days 条目合计 = 1346
git rev-list --count HEAD = 1297（含回填历史分支 = 1346）
OK: 对账一致
```

`--stats` 现查数字（供引用，勿写入 README）：

| 指标 | 值 |
|---|---|
| 总提交数 | 1297（HEAD `3e384f4b`） |
| 覆盖区间 | 2026-10-03 → 2026-11-17（46 个自然日） |
| 平均每日 | 28.2 条 |
| 峰值日 | 2026-10-12（74 条） |

实际 diff 仅 `HISTORY/days/2026-11-17.md`（+3/-1 行），符合「只有当天文件该变」。

### 2.2 其余两个 WARN（存量，不动）

- vk 账本登记例外：理由在 `versions/vk-ledger-known-issues.tsv`，属**已登记豁免**；改它需逐条重判 vk 身份，超出本 lane 授权。
- 4 个 `posctrl-markspin*-v2-20261103.img` 内核段不可读：存量；设备断电、无新镜像可替代，按门禁提示「免于身份核对」保留。

DONE: §2 可修 WARN 清理

---

## §3 工件清单重生成

先查生成口径（不猜）：`versions/scripts-inventory.tsv` 头部自述 ——
`# 唯一生成命令：python3 scripts/static-scan.py --inventory | sed '1d'`。

实测该口径**是错的**：`static-scan.py --inventory` 第一行就是表头 `path	ext	lines	bytes	live	hist	verdict`（`head -6` 实测），
`sed '1d'` 会把表头删掉，与文件现状（第 6 行 = 表头）不符。正确做法 = 保留文件前 5 行注释块 + 脚本完整输出。

### 3.1 落后核实

```
$ python3 scripts/static-scan.py --inventory > /tmp/inv-full.txt
$ diff <(tail -n +6 versions/scripts-inventory.tsv) /tmp/inv-full.txt
245c245  scripts/gen-history.sh   live 56 → 57
276c276  scripts/lore-fetch-raw.py live 12 → 14
278      scripts/mail-append-sent.py live 2 → 4
279      + scripts/mail-draft-check.py（整条缺失）
```

结论：**确实落后**（4 处差异，含 1 个新脚本未入册）。

### 3.2 重生成

```bash
cp versions/scripts-inventory.tsv /tmp/inv-before.tsv
python3 scripts/static-scan.py --inventory > /tmp/inv-full.txt
{ head -5 /tmp/inv-before.tsv; cat /tmp/inv-full.txt; } > versions/scripts-inventory.tsv
```

顺带最小修正第 2 行生成命令自述（原 `| sed '1d'` 会使表头丢失）：

```
# 唯一生成命令：保留本文件前 5 行注释块，其后接 `python3 scripts/static-scan.py --inventory` 的完整输出（脚本自带表头，勿 sed 删行）
```

### 3.3 现查数字（报告中所有计数以此为准）

| 项 | 值 | 命令 |
|---|---|---|
| 清单总条目 | **368** | `awk -F'\t' 'NR>6' versions/scripts-inventory.tsv \| wc -l` |
| LIVE | 304 | `awk -F'\t' 'NR>6{print $7}' … \| sort \| uniq -c` |
| HIST-ONLY | 64 | 同上 |
| UNREFERENCED | 0 | 同上 |
| `scripts/` 顶层条目 | 272 | `ls scripts/ \| wc -l` |
| `scripts/*.sh`+`*.py` | 258 | `ls scripts/ \| grep -cE '\.(sh\|py)$'` |

> 口径说明：368 ≠ `scripts/` 下文件数——清单覆盖 `scripts|rootfs|tools|packaging|initramfs` 全部可执行入口。
> 若别处文档写「350 条/367 条」，以本表 368 为准（旧值来自上一次生成）。

DONE: §3 工件清单重生成

---

## §4 文档自相矛盾扫描

范围 = 三处「上游口径」权威（`reports/upstream-status-20261113.md`、`TASKS/README.md` §7、`INDEX.md` §0）
+ `TASKS/README.md` §0/§4/§5 的 ⬜/🟡 行。历史快照（`reports/*-2026101x.md`、`TASKS/sessions/*`、
`archive/*`）按 `INDEX.md` §2「时间序裁决」**不算矛盾**（典型：`TASKS/sessions/2026-11-16-pstore守卫落地…` 写「未发信」= 当时快照、`reports/upstream-dedup-audit-20261027.md` 写 M6 B5-P4「未发」= 10-27 快照，均按快照读，不回写）。

### 4.1 「已发 / 等批准 / 待放行」三处对账

| 系列 | `upstream-status` §1/§2 | `INDEX` §0-6 | `TASKS` §7 M 行 | 判定 |
|---|---|---|---|---|
| dsi/phy **v2** | 已投（11-16 22:50/23:03，两发 250，三处归档） | 已发 | —（M 行无此项） | ✅ 一致 |
| mdss **v5** | 已发（11-14，4×250） | 已发 | M8 行头「v5 已投」 | ✅ 一致 |
| wl2868c **v11** | 已投 3×250 | 已发 | M3/M4 行「v11 已发」 | ✅ 一致 |
| pstore guard v1 | 已投（11-16 12:00:49，2+cover 全 250） | §0-5「已发 … 等回复」 | §4 N1 条「已发」 | ✅ 一致 |
| Q28 证据回帖 | 未发（只差放行） | 未发（**唯一在档未发**） | —（§7 无该条） | ✅ 一致 |
| dwc3 v9 / gamma v2 / haptics v2 / board DTS | §2 未逐条列（haptics 行写「v1 + 欠 v2 两点」） | 备料在档、等批准 | §4 附「patches/upstream/{dwc3-v9,board-dts-single,dpu-gamma-lut-v2}-*」 | ⚠️ 粒度不一致（见 4.2-④） |

**结论**：四个「已发出的项」没有任何一处仍写「未发 / 只差放行」 —— 按 `rg '只差放行|待放行|等放行|未发'`
扫 `INDEX.md`/`TASKS/README.md`/`reports/upstream-status-20261113.md` 三文件，命中 1 处，正是 Q28 证据回帖（确实是未发）。

### 4.2 发现的真矛盾（逐条）

| # | 位置 | 矛盾内容 | 处置 |
|---|---|---|---|
| ① | `TASKS/README.md:385`（Q21 行「关联任务」列） | 写 `G1-22 🟡 / Q24`，同文件 `:45` G1-22 = **🟢**、`:388` Q24 = **⛔ 关闭**；且括注「根因=单模块 `cambistmclkcc-sm8750`，**仍未根治**」已被同文件 `:430`「~~DT 电源域耦合~~ 更正：RPMh rail retention 档（2026-10-23）」推翻 | **已修**（划旧结论 + 指向 Q24 行；状态标 `🟢 / ⛔`） |
| ② | `INDEX.md:56` vs `:57` | 同一段落内 `:56` 把 **`m8-mdss v4` 3 枚** 列入「上游待批准批次…逐系列等用户放行」，`:57` 又写「已投的不再在列：… **mdss v5**」 | **已修**（`:56` 该枚划线 + 注明 v5 已投、剩等回复；v5↔v4 diff 只差 3/3 message，apply 结论可沿用） |
| ③ | `TASKS/README.md:137` 前言 vs `:137-199` 内容 | 前言「**本节只列开放项**」，实际 33 条项目符号里 **11 条**标题自带 `✅`/`🟢`（如 §4-8 `vk189/vk190 ✅ 上机收口`、§4-19 `N2 Gunyah 编译完成`、T14/T17 `🟢`、T20 `✅ 闭环`、N1 多条 `✅/★定案`） | **只报告**（结构性问题：需整节重排，超本 lane 的最小改动边界） |
| ④ | `reports/upstream-status-20261113.md` §2 行 | `haptics aw86937` 行仍按 **v1** 描述（「我方欠 v2 顺手采纳两点」），而 `INDEX` §0 已按 **haptics v2 6 枚已 rebase 备料等放行** 计 | **只报告**（两处描述的是不同维度：一页写欠什么、INDEX 写件备到哪一版；建议该行补「v2 已备料见 `patches/upstream/haptics-v2-*`」一句） |
| ⑤ | `reports/upstream-status-20261113.md:7 vs :34/:39` | 文件名与 §3「当前一页」定位为 11-13，但 §1 标题写「本窗口已投（**2026-11-11 → 11-14**）」却含 **11-16** 两项（dsi/phy v2、pstore guard）；§2b 标题写「**2026-11-16** 复查与新增欠账」而首条正文是「**2026-11-17** 早复核」 | **只报告**（日期口径小漂移；改标题需与「取代 11-05 快照」的沿革说明一起动，留给编者） |
| ⑥ | `TASKS/README.md:93`（C8 行） | 行首结论「🟡 **维持低优先不立项**」与同单元格后半「⇒ 由『维持不立项』改为『**阶段 0 阳性，进入立项评估**』」自相矛盾（后者是 2026-10-24 的更新） | **只报告**（同一格里已有时间序更新，读者能判；改行首需重写整格结论） |

### 4.3 ⬜/🟡 行核对结果

| 行 | 标记 | 正文结论 | 判定 |
|---|---|---|---|
| `C9`（:94） | ⬜ 新增 | INDEX §0-2 也列「剩 C9 打分表」 | ✅ 一致 |
| `C5`（:90） | 🟡 | 正文「②b 已达成，②c 未做」；INDEX「C5 App 实开预览」未做 | ✅ 一致 |
| `G1-38`（:60） | 🟡 | §4 条目同口径「待上机」 | ✅ 一致 |
| `C8`（:93） | 🟡 | 行首/后文互斥 | 见 4.2-⑥ |
| `A11`/`A12`（:104/:105） | ⬜ | 无正文，VM 路线低优先 | ✅ 一致（不影响 G1–G3） |
| `redroid`（:486） | ⬜ 未装 | 备胎，R1 受阻才切 | ✅ 一致 |

### 4.4 指针有效性

`check-doctor.sh` §13 已通过（`checked=428`，全 `[ok]`）⇒ **不重复做**，「指向不存在文件」本轮 0 例。

DONE: §4 文档自相矛盾扫描

---

## §5 零碎整理（只报告，未删任何文件）

### 5.1 临时目录占用

| 位置 | 现状 | 命令 |
|---|---|---|
| `/tmp/pi-fabric-runs-*` | **0 个**（本机 `/tmp` 上已无该前缀目录） | `ls -d /tmp/pi-fabric-runs-* \| wc -l` |
| `~/.cache/pi-tmp/pi-fabric-runs-*` | **33 个 / 2.7 G**，最老 `2026-11-15`（`-M54u9`/`TgFaqd`/`ceVmvJ`），最大 5 个：`CIiMtk 341M`、`ceVmvJ 262M`、`fovXDh 254M`、`KBcfFy 247M`、`2M54u9 216M` | `du -shc ~/.cache/pi-tmp/pi-fabric-runs-* \| tail -1` |
| `~/.cache/pi-tmp` 合计 | **4.4 G**（含 `tmp.Akzvx2TFWp.tar.gz` 单文件 **550 M**） | `du -sh ~/.cache/pi-tmp` |

> `/tmp` 与 `/` 同分区：`/dev/nvme0n1p2 937G 已用 668G(76%) 可用 222G`（`df -h /tmp`）。
> 判断：2.7 G 的 fabric run 目录属「可回收」，但均属**别的会话/在跑的 lane 的产物**，
> 本 lane 不删（任务红线亦禁止删文件）；建议由编排者在全会话收尾后按 mtime > 2 天统一清。

### 5.2 项目体积

| 路径 | 大小 |
|---|---|
| `/home/xuqianhui/y700-elden` 合计 | **89 G** |
| `build/` | 36 G |
| `backup/` | 29 G（红线：不动） |
| `wt/` | 13 G |
| `out/` | 3.8 G |
| `geekidos-linux/` | 2.1 G |
| `reports/` | 1.9 G |

（INDEX §0-8 记 2026-11-16 两轮清理后项目 76 G；现查 **89 G** ⇒ 期间又长了 ~13 G，主要落在 `build/`(36 G) 与 `wt/`(13 G)，建议下一轮清理时按这两处复算，本 lane 不动。）

### 5.3 `git status`（意外大文件）

```
 M .pi/AGENT-OPS.md          ← 非本 lane 改动（并行 lane/编排者）
 M HISTORY/days/2026-11-17.md        ← 本 lane（§2 gen-history.sh）
 M INDEX.md                          ← 本 lane（§4 一处）
 M TASKS/README.md                   ← 本 lane（§4 一处）
 M versions/scripts-inventory.tsv    ← 本 lane（§3）
?? reports/doc-hygiene-20261117.md   ← 本 lane 报告
?? reports/misc-20261117.md          ← 并行 lane
?? reports/todo-reconcile-20261117.md← 并行 lane
?? reports/upstream-replies-20261117.md ← 并行 lane
```

未跟踪文件 >50 MB：**0 个**（逐文件 `stat -c%s` 过滤 `??` 列表，命令见下）。

```bash
git status --porcelain -uall | awk '$1=="??"{print $2}' \
  | while read -r f; do [ -f "$f" ] && s=$(stat -c%s "$f") && [ "$s" -gt 52428800 ] && echo "$((s/1048576))MB $f"; done
```

DONE: §5 零碎整理

---

## §6 收尾与编者清单

### 6.1 门禁变化

| 时刻 | FAIL | WARN | 明细 |
|---|---|---|---|
| 基线（开工） | 0 | **3** | ① vk 账本登记例外（~70 条）② 4 个 boot 镜像内核段不可读 ③ `HISTORY/days` 落后（未覆盖 HEAD `3e384f4b`/`HEAD~1` `076668972d`） |
| 中途 | 0 | 4 | 上一行 + 「`reports/doc-hygiene-20261117.md` 无人引用」（本 lane 新建文件自身） |
| 收尾（最终） | 0 | **2** | ① vk 账本登记例外（存量豁免）② 4 个 boot 镜像内核段不可读（存量豁免） |

⇒ **WARN 3 → 2**；`check-progress-counts.sh --tsv` 收尾复跑数字未变（G1 36/37、G2 10/13），
证明本轮改动没有触碰任何结论数字。

复现：

```bash
cd /home/xuqianhui/y700-elden
timeout -k 5 180 bash scripts/check-doctor.sh            # == 汇总: FAIL=0  WARN=2
timeout -k 5 120 bash scripts/check-progress-counts.sh --tsv
timeout -k 5 120 bash scripts/gen-history.sh --check     # OK: 对账一致
python3 scripts/static-scan.py --inventory | wc -l       # 369 = 368 条 + 表头
```

### 6.2 编者清单

| # | 项 | 发现 | 处置 |
|---|---|---|---|
| 1 | `HISTORY/days/*` | 落后 HEAD 2 条 | **已改** `HISTORY/days/2026-11-17.md`（`scripts/gen-history.sh` 机械生成，5 条 → 7 条） |
| 2 | `versions/scripts-inventory.tsv` | 4 处陈旧（`gen-history.sh` live 56→57、`lore-fetch-raw.py` 12→14、`mail-append-sent.py` 2→4、缺 `mail-draft-check.py`） | **已改** 整表重生成（368 条） |
| 3 | `versions/scripts-inventory.tsv:2` | 自述生成命令 `… --inventory \| sed '1d'` **是错的**（脚本自带表头，`sed 1d` 会删表头） | **已改** 第 2 行为「保留前 5 行注释块 + 脚本完整输出，勿 sed 删行」 |
| 4 | `TASKS/README.md:385`（§5 Q21 行） | 状态列 `G1-22 🟡 / Q24` 与 `:45`(`🟢`)/`:388`(`⛔ 关闭`) 矛盾；括注「根因=单模块 cambistmclkcc，仍未根治」被 `:430` 推翻 | **已改** 旧结论划线 + 指向 Q24 行；状态改 `🟢 / ⛔（已关闭）` |
| 5 | `INDEX.md:56`（§0 下一步-2） | 同段内 `:56` 把 `m8-mdss v4` 列为「等用户放行」，`:57` 又写「已投的不再在列：… mdss v5」 | **已改** `m8-mdss v4` 划线 + 注明 v5 已于 11-14 投出、剩等回复（§0 结论数字**未动**） |
| 6 | `TASKS/README.md:200`（H2 巡检行） | 门禁 WARN「本报告无人引用」 | **已改** 该行末补指针 `reports/doc-hygiene-20261117.md`（消掉该 WARN） |
| 7 | `TASKS/README.md:137` §4 前言 | 写「本节只列开放项」，实际 33 条里 11 条标题自带 ✅/🟢（§4-1/4-8/4-19、T14、T17、T20、N1 多条…） | **建议**（未改）：整节做一次「完成项下沉到 sessions」的重排，或把前言改为「开放项 + 尚未下沉的完成项」 |
| 8 | `reports/upstream-status-20261113.md` §2 haptics 行 | 仍按 **v1** 叙述「我方欠 v2 两点」，与 `INDEX` §0 的「haptics v2 6 枚已 rebase 等放行」不同步 | **建议** 该行补一句「v2 已备料 `patches/upstream/haptics-v2-*`，等放行」 |
| 9 | `reports/upstream-status-20261113.md:7 / :34 / :39` | §1 标题窗口写「11-11 → 11-14」却含 11-16 两项；§2b 标题「2026-11-16 复查」而正文是「2026-11-17 早复核」 | **建议** 标题日期口径统一到「截至 2026-11-17」 |
| 10 | `TASKS/README.md:93`（C8 行） | 行首「🟡 维持低优先不立项」与同格后半「⇒ 改为阶段 0 阳性、进入立项评估」互斥 | **建议** 重写行首结论（同一格内已有时间序更新，读者可判，未强改） |
| 11 | `~/.cache/pi-tmp/pi-fabric-runs-*` | 33 个目录 / 2.7 G（最老 2026-11-15），属其它会话产物 | **建议** 全编排收尾后按 mtime >2 天统一清（本 lane 不删） |
| 12 | 项目体积 | 现查 **89 G**，`INDEX` §0-8 记 11-16 清理后 **76 G** ⇒ 期间 +13 G（`build/` 36 G、`wt/` 13 G 为主） | **建议** 下一轮清理按 `build/`+`wt/` 复算 |
| 13 | `.pi/AGENT-OPS.md` | `git status` 显示已修改，**非本 lane 改动**（并行 lane/编排者） | 提示编排者提交时一并处理 |
| 14 | 4 个 `posctrl-markspin*-v2-20261103.img` | 内核段不可读（WARN 存量） | **建议**（未做，需设备/重出件）：从 `out/` 移到 `out/_quarantine/` 或补一份 manifest 注明「不可解」 |
| 15 | vk 账本 ~70 条登记例外 | 存量豁免，理由在 `versions/vk-ledger-known-issues.tsv` | 不动（重判 vk 身份超出本 lane 授权） |

### 6.3 本轮未做（按任务红线）

- 未发任何邮件、未 `git push`、未 `git commit`、未碰设备、未删任何文件、未动 `backup/`。
- `INDEX.md` §0 **结论数字**（G1 36/37、G2 10/13、在机 vk192）与 `DEVICE/README.md` §1.1 权威行 **未改**。
- 并行 lane 产生的新报告（`misc-20261117.md` / `todo-reconcile-20261117.md` / `upstream-replies-20261117.md`）
  由各自 owner 负责挂指针（它们的「无人引用」WARN 不在本 lane 处置范围）。

DONE: §6 收尾与编者清单
