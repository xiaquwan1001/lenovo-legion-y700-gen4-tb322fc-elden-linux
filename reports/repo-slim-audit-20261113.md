# 仓库瘦身审计（文档 + 脚本）— 2026-11-13

> 审计者：文档审计 Lead（y700-elden，一级 `doc-audit-lead`）。**只读**：本篇是本任务唯一产物，未改任何
> README / INDEX / TASKS / DEVICE / RESOURCES / AGENTS / PITFALLS / `.pi/*`，未做 git 写操作。
> 数字全部 2026-11-13 现查（`git ls-files` / `du -b` / `wc` / `git log`），每条给复现命令。
>
> **分工（避免重复劳动）**：本文件**不重做**
> `reports/doc-dedup-audit-20261112.md`（语义级重复）、`reports/docs-slim-20261113.md`（其执行账）、
> `reports/script-cleanup-audit-20261112.md` / `reports/script-redundancy-audit-20261112.md`（脚本逐条）、
> `reports/asset-slim-20261112.md` / `reports/external-scan-20261112b.md`。
> 本文件的增量 = **① 那四份「仍未做/需裁决」项的逐条现查（§6）②体量维度：reports/ 分布 + 增长趋势 + 生成物占比（§5）
> ③ ≤10 条可立即执行清单（§7）**。§1–§4 是支撑 §7 的账，不与上述报告重叠的只有 P1-1/P1-2/P1-3 与 §2/§4 的门禁盲区。

---

## 0. 结论先行

**一句话**：**不需要重构文档体系；需要「一次下沉 + 一次归档 + 三条口径修正」**。
骨架实测无漂移（顶层 46 项三向一致、§0 数字由脚本导出、入口文档死链 0）；
体积与漂移集中在 **`TASKS/README.md` §5 把 49 个日期沿革块写在 README（−130 KB）** 与
**`reports/` 142 篇 10 月报告再无任何活文档引用（−1.65 MB）** 两处；
外加 **3 条真实账实不符**：`versions/scripts-inventory.tsv` 陈旧 5 天、`.pi/AGENT-OPS.md` 4 处指向已不存在的 `STANDING.md`、
`AGENTS.md:42` 要求 `WARN=0` 而 HEAD 实测 `WARN=5`（该常驻判据今天不可能满足）。

### 0.1 关键数字表（现查）

| 项 | 数字 | 现查命令 |
|---|---|---|
| 纳管 md / 总字节 | **1 648 / 13 569 585 B（12.9 MiB）** | `git ls-files '*.md' \| wc -l` + `git ls-files -z '*.md' \| xargs -0 du -b \| awk '{s+=$1}END{print s}'` |
| 纳管全部文本 | 204 813 962 B ⇒ md 占 **6.6%** | `git ls-files -z \| xargs -0 du -cb \| tail -1` |
| `reports/` | **531 / 6 703.9 KB = md 的 50.6%**；均值 12.6 KB、中位 8 833 B、p90 25 613 B、>32 KB 34 篇、<2 KB 15 篇 | §5.1 |
| 无活文档引用的报告 | **176 篇 / 2 096 KB**；其中 10 月件 **142 篇 / 1 685 KB** | §5.1 |
| 报告新增速率 | 65–112 篇/周（6 个采样周均值 **89/周**，未见下降） | §5.2 |
| `TASKS/README.md` | 1 348 行 / 322 KB；**§5 = 167 KB / 987 行（52%）；49 个日期块 = 131.6 KB / 880 行** | §2.4 |
| 30 天增长 | `TASKS` 478 → **1 348 行**；`PITFALLS/README` 60 → **326 行**；`reports/` md 111 → **531** | §5.2 |
| 精简后回涨 | 11-05 精简把 `TASKS` 从 914 → 640 行，**4 天后（11-09）回到 1 175 行** | §5.2 |
| 生成物占比 | `HISTORY/` 的 **96.4%**、`SESSIONS/` 的 **98.1%** md 字节是脚本派生 | §5.3 |
| 脚本 | 264 个纳管入口 / 顶层 24 541 行；**死脚本 0**；仅沿革引用 4 个（206 行） | §3 |
| 顶层布局 | 磁盘 46 = `versions/layout.tsv` 46 = `INDEX.md` §2 表 46，双向差 **0** | §4.1 |
| 入口文档死链 | markdown `]()` **0**；反引号路径 **1 组真死**（`STANDING.md` ×4） | §2.3 |
| 未入库 `.bak-*` | 29 个 / 85 172 B（`.gitignore:391` 记为用户要求保留） | §3.4 |
| 门禁 | 基线 **FAIL=0 WARN=4** → 写本篇后 **FAIL=0 WARN=5**（新那条 = §8f「报告无人引用」，含本篇 + 今日另 2 篇） | §9 |

### 0.2 计数

**P0 = 0 · P1 = 3 · P2 = 6**（P1 全是可机器复现的账实不符；无 P0：本轮未发现安全类反向指令——
那条已在 `docs-slim-20261113` §1 修掉）。**删除建议 0 条**，全部是 `git mv` / 追加 / 改默认值。

---

## 1. 文档体量（按目录）

```bash
cd ~/y700-elden && git ls-files -z '*.md' | perl -0ne 'chomp; my @p=split m{/};
  my $d=@p>1?$p[0]:"(root)"; $c{$d}++; $b{$d}+=-s $_; END{
  for my $k (sort{$b{$b}<=>$b{$a}} keys %c){printf "%-12s %5d %10d\n",$k,$c{$k},$b{$k}}}'
```

| 目录 | md | 字节 | 占比 | | 目录 | md | 字节 | 占比 |
|---|---|---|---|---|---|---|---|---|
| `reports/` | 531 | 6 864 762 | 50.6% | | `HISTORY/` | 48 | 153 756 | 1.1% |
| `archive/` | 177 | 1 662 602 | 12.3% | | `RESOURCES/` | 10 | 136 895 | 1.0% |
| `TASKS/` | 266 | 1 531 535 | 11.3% | | 根目录 | 4 | 104 119 | 0.8% |
| `.pi/` | 112 | 1 101 515 | 8.1% | | `reference/` | 21 | 96 309 | 0.7% |
| `PITFALLS/` | 202 | 1 078 824 | 8.0% | | `DEVICE/` | 4 | 82 398 | 0.6% |
| `patches/` | 75 | 325 166 | 2.4% | | 其余 10 目录 | 25 | 105 564 | 0.8% |
| `SESSIONS/` | 173 | 310 971 | 2.3% | | | | | |

最大 10 篇（`git ls-files -z '*.md' | xargs -0 du -b | sort -rn | head`）：
`TASKS/README.md` 322 259、`.pi/memory/failures-kernel.md` 201 117、`PITFALLS/README.md` 138 024、
`reports/mail-cleanup-20261102.md` 85 279、`.pi/memory/MEMORY.md` 81 251、
`reports/code-style-and-duty-overlap-audit-20261030.md` 80 359、`SESSIONS/README.md` 75 383、
`reports/doc-dedup-audit-20261112.md` 69 243、`reports/doc-audit-20261026.md` 66 891、`reports/pitfalls-dedup-audit-20261112.md` 64 543。

**自指成本（新维度）**：文件名含 `audit|slim|tidy|inventory|review|cleanup|dedup|survey|scan` 的「关于整理的报告」
= **86 篇 / 1 598 721 B = md 总量的 11.8%**。
`git ls-files 'reports/*.md' | grep -cE '(audit|slim|tidy|inventory|review|cleanup|dedup|survey|scan)'`（86）+ 同管道 `xargs du -cb | tail -1`。
⇒ 结论：**下一轮收束请在 `reports/docs-slim-20261113.md`（`INDEX.md:185` 指定的执行账）里追加小节，不要再开同类新文件。**

---

## 2. 状态漂移

### 2.1 「§0 数字由脚本导出」仍成立 ✅

```bash
bash scripts/check-progress-counts.sh          # G1 36/37（ID 39 取消 2）、G2 9/13；rc=0
bash scripts/check-doctor.sh --only 16         # 四条 [ok]（手写数字 ↔ 脚本对账）
```
`TASKS` §0 仅 **6 768 B / 20 行**（公式 + 指针，无手算推导）。**此项无需整改。**

### 2.2 索引行 / 长行（800 B 门只覆盖 PITFALLS）

```bash
for f in INDEX.md PITFALLS/README.md TASKS/README.md SESSIONS/README.md DEVICE/README.md RESOURCES/README.md PROGRESS.md; do
  printf "%-24s max=%s >800=%s >1000=%s\n" $f "$(awk '{if(length($0)>m)m=length($0)}END{print m}' $f)" \
    "$(awk 'length($0)>800{c++}END{print c+0}' $f)" "$(awk 'length($0)>1000{c++}END{print c+0}' $f)"; done
```

| 文件 | 最长行 | >800 B | >1 000 B | 门 |
|---|---|---|---|---|
| `INDEX.md` | 707 B | 0 | 0 | — |
| `PITFALLS/README.md` | **799 B**（限 800，`s07-08-docs.py:111`） | 0 | 0 | ✅ 有 |
| `TASKS/README.md` | **6 711 B** | **86** | **57** | ❌ 无 |
| `RESOURCES/README.md` | 1 426 B | 8 | 5 | ❌ 无 |
| `DEVICE/README.md` / `PROGRESS.md` / `SESSIONS/README.md` | 1 279 / 1 128 / 1 239 B | 5 / 13 / 3 | 3 / 5 / 2 | ❌ 无 |

- **P2-4**：`PITFALLS/README.md` 最长行 = 门限 **99.9%**，且 **>700 B 有 40 行**（`awk 'length($0)>700{c++}END{print c}' PITFALLS/README.md`）。任何一次「补半句」即 §8 FAIL。
  改法（二选一）：这 40 行结论下沉正文（索引只留 ≤200 B 主题句）／给 `s07-08-docs.py:111` 加 `>700 B` 的 **warn**（不改 FAIL 语义）。
- **P2-5**：`TASKS/README.md` 86 行 >800 B（§5 28、§4 18、§1/§2 24）。同一条坑，`PITFALLS` 有门 `TASKS` 没有。
  改法：**先随 P1-3 下沉 §5**；搬完若仍 >30 行，再把 `(('PITFALLS/README.md',800),)` 扩一项。**不要先加门**（会把 52% 的存量一次打成红字，逼出草率改写）。

### 2.3 过期指针：先给「否结论」，免得下一轮再查

`reports/upstream-status-20261105.md` 被 `-20261113` 取代后，**活文档 0 处仍指旧页**
（`INDEX.md:185`、`TASKS/README.md:1317/1328/1348` 均已指新页并写明「取代 `-20261105`/`-20261029`」）；
24 篇提到旧页的文件全是 `*/sessions/*` 与 `reports/*`（沿革，按 `INDEX` §2「不改旧文件」正确保留）。

```bash
grep -rn "upstream-status-20261105" --include='*.md' INDEX.md TASKS/README.md PROGRESS.md README.md \
  DEVICE/README.md RESOURCES/README.md PITFALLS/README.md .pi/AGENT-OPS.md   # 实测 rc=1（无输出）
```

markdown 死链（入口 + 角度 README）= **0**。反引号路径严格扫描（basename 在 git 里完全不存在）命中 151，逐类过滤：

| 类 | 条数 | 判定 |
|---|---|---|
| `*.img` / `out/*` / `bootslot-b/*` | ~70 | 非死链：ignore 区产物或已登记 MIGRATION-LOST（`RESOURCES` §3.5） |
| 内核 / EDK2 源码名（`sm8750.dtsi`、`DxeMain.c`…） | ~45 | 非死链：树在 `kernel/`、`geekidos-linux/`（ignore 区） |
| `RESOURCES.md`（`SESSIONS/README.md` ×5） | 5 | 非死链：自陈来源并给 `git show d8ae437:RESOURCES.md`；`SESSIONS/` 冻结 ⇒ 不动 |
| **`STANDING.md` / `~/.pi/agent/pi-hermes-memory/STANDING.md`** | **4** | **真死 → P1-2** |

### 2.4 P1-2（P1｜`.pi/AGENT-OPS.md:21,24,62,86`）

- **现状**：4 条把「凭据上报 / 一次正反判断 / 汇报一页 / 时间盒」的权威指向 `~/.pi/agent/pi-hermes-memory/STANDING.md`，该目录已不存在（内容在全局 `~/.pi/agent/AGENTS.md`「硬性规则」+ `~/.pi/agent/rules/`）。
- **证据**：`ls ~/.pi/agent/pi-hermes-memory/` → No such file；`grep -n STANDING .pi/AGENT-OPS.md` → 4 行；`ls ~/.pi/agent/rules/` → 4 个 md。
- **为什么门没抓**：`scripts/check-doc-assets.sh:47` 的 `PAT` 只匹配仓库内前缀（`patches|reports|scripts|DEVICE|…`）⇒ 仓库外指针全盲。
- **改法**：4 处改为「全局 `~/.pi/agent/AGENTS.md`「硬性规则」第 N 条（细则 `~/.pi/agent/rules/`）」，并给 `PAT` 增一类 `~/\.pi/agent/[A-Za-z0-9._/-]+`。

### 2.5 P1-3（P1｜最大体积收益）`TASKS/README.md` §5 沿革块下沉

- **现状**：§5 = **167 562 B / 987 行（全文 52%）**，其中 **49 个 `### 2026-…` 日期块 = 131 587 B / 880 行**；Q 表本体只有 9 行。与 `INDEX.md` §2 规则 4/5（README 只维护数字、沿革进 sessions、不复述）直接冲突。§4 同理（51 257 B / 66 行）。
- **趋势（这是结构性问题，不是一次性堆积）**：日期块数 11-01 **14** → 11-06 **30** → 11-09 **45** → 11-13 **49**。
  ```bash
  for d in 2026-11-01 2026-11-06 2026-11-09 2026-11-13; do h=$(git rev-list -1 --before="$d 23:59" HEAD);
    echo -n "$d §5块数="; git show "$h:TASKS/README.md" | awk '/^## 5\./{a=1}/^## 6\./{a=0} a&&/^### 20[0-9][0-9]-/{c++}END{print c+0}'; done
  ```
- **风险（必读）**：`grep -rl '§5「' --include='*.md' . | wc -l` = **40 个文件**按「§5「<原日期标题>」块」引用，含活入口 `INDEX.md:191`、`PITFALLS` 若干条。
- **精确改法（搬移 + 保留锚，单 commit）**：
  1. 按主题（UEFI / Q28 / 输入法 / …）拆进 `TASKS/sessions/2026-11-13-TASKS-§5-沿革-<主题>.md`（先例：`2026-11-03-TASKS-§4-待办沿革.md`）；
  2. §5 **原地逐字保留每个日期块的 `###` 标题行**，正文替换为一行
     `> 已下沉：<相对链接 sessions/…> §<n>（原「<原日期标题>」块）；当前口径只读 §5 表 Q<nn> 行。`
     ⇒ `§5「…」块` 文字指针仍指得到，`INDEX.md:191` 不用改。
  **验收**：`check-doctor` FAIL=0、`check-progress-counts.sh` 仍 36/37 与 9/13（不要动 §1/§2 行内 emoji 标记 ⇒ `PITFALLS #548`）。
  **收益 −130 KB / −880 行**（README 322 → ~190 KB）。

---

## 3. 脚本

| 维度 | 数字 | 命令 |
|---|---|---|
| 纳管入口 | **264**（顶层 243；含子目录 278 文件） | `git ls-files 'scripts/*' \| wc -l` |
| 顶层行数 | **24 541 行**（205 sh + 31 py + 3 c + allowlist/conf/无扩展） | `find scripts -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) -print0 \| xargs -0 wc -l \| tail -1` |
| 死脚本（0 引用） | **0**（与 `script-cleanup` §0.7「可安全删除=0」**独立复核一致**） | `python3 scripts/static-scan.py --inventory \| awk '$6!="LIVE"'` → 空 |
| 仅沿革引用 | **4 个 / 206 行**：`dev-super-relabel.sh` 57、`dev-userdata-relabel.sh` 66、`esp-install-grub.sh` 69、`phoc-build-launch.sh` 14（均 11-11，一次性手术） | 同上 `awk '$6=="HIST-ONLY"'` |
| `.bak-*` | **29 个 / 85 172 B，全部 untracked**（`.gitignore:391` 记「用户要求有意保留在盘」）；`.pi/agents/*.bak-alias-1112` 24 个（50 912 B，其中 **16/24 与当前正文 `diff` 为空**）+ `.pi/{AGENT-OPS,ORCHESTRATION}.md.bak-alias-1112`、`.pi/fabric.json.bak-alias-1112`、`initramfs/init.bak{,-beforedbus}-20260930` | `find . -path ./.git -prune -o -path ./kernel -prune -o -path ./build -prune -o -path ./out -prune -o -path ./.pi/sessions -prune -o -type f -name '*.bak*' -print` |

**结论**：脚本侧**没有体量债**（0 可删），只有**可发现性债**（4 个入口无活指针 ⇒ 建议在 `RUNBOOK-BRINGUP/README.md` 各加 1 行；**不删**，删=丢复现路径）。`.bak-*` **保持现状**（未入库、有用户明示意图）。

---

## 4. 文档地图（`INDEX.md` §2）↔ 实际

### 4.1 顶层布局：三向一致 ✅（唯一一处「机读面 = 人读面」被证实）

```bash
export LC_ALL=C
ls -A | grep -v '^\.git$' | sed 's#/$##' | sort > /tmp/a.txt
awk '/^### 顶层布局/,/^### 证据层/' INDEX.md | grep -oE '^\|[^|]*\| `[^`]+`' | sed -E 's/^\|[^|]*\| `//;s/`$//;s#/$##' | sort -u > /tmp/b.txt
awk -F'\t' '!/^#/ && NF>=4 && $1!="zone"{print $2}' versions/layout.tsv | sed 's#/$##' | sort > /tmp/c.txt
wc -l /tmp/a.txt /tmp/b.txt /tmp/c.txt && comm -3 /tmp/a.txt /tmp/b.txt && comm -3 /tmp/a.txt /tmp/c.txt
```
实测 46 / 46 / 46，两处 `comm` **双向差皆空**；doctor §14 亦 `[ok] entries=46`。**这张表不要动。**

### 4.2 §2 其余断言：4 处文字与事实不符（P2）

| 编号 | file:line | 现状 | 证据命令 | 精确改法 |
|---|---|---|---|---|
| P2-3a | `INDEX.md:32`（§2 规则 2） | 「可用角度 **4 个**」，同段又写 `RUNBOOK-BRINGUP/` 属可写 ⇒ 实际 **5** | `ls RUNBOOK-BRINGUP/sessions/*.md \| wc -l` → **1**（确有写入） | 改「可用角度 5 个：TASKS/PITFALLS/DEVICE/RESOURCES/RUNBOOK-BRINGUP」，删后面的补丁句 |
| P2-3b | `INDEX.md:59`「证据层」段 | `archive/`（177 md / 1.66 MB）**无 README**，7 个角度都有 | `[ -f archive/README.md ] && echo y \|\| echo NO` → **NO** | 二选一：① `INDEX.md` 角度表把 `archive/` 标「无 README，入口=本篇 §2」；② 新建 `archive/README.md`（≤30 行：分区 + 追加纪律 + 不得作当前结论），并给 `INDEX.md:59` 加指针 |
| P2-3c | `INDEX.md:110` 附近 | 写死「`versions/layout.tsv`（**46 项**）」，与同节第 7 条「不写死计数」自相矛盾（今天恰好对） | `grep -n '46 项' INDEX.md` | 改「项数现查 `scripts/check-layout.sh --list \| wc -l`」——入口文档里**唯一**一个写死计数 |
| P2-3d | `INDEX.md:109-110` | 写死「fast 档 ~0.4 s / 全量 ~1.4 s」 | `time bash scripts/check-doctor.sh >/dev/null` | 改成量级 + 指向 `reports/script-audit-20261105.md` |

---

## 5. 体量维度（四份既有报告未覆盖的面：分布 / 趋势 / 生成物）

### 5.1 `reports/` 分布 —— 该按「季度 + 主题」归档，不该按文件删

```bash
git ls-files -z 'reports/*.md' | xargs -0 du -b | awk '{n++;s+=$1;if($1<2048)t++;if($1>32768)b++}END{printf "n=%d 总=%.1fK 均值=%.1fK <2K=%d >32K=%d\n",n,s/1024,s/n/1024,t,b}'
git ls-files -z 'reports/*.md' | xargs -0 du -b | sort -n | awk '{a[NR]=$1}END{print "median="a[int(NR/2)]" p90="a[int(NR*0.9)]}'
```

n=531、总 **6 703.9 KB**、均值 12.6 KB、**中位 8 833 B**、p90 25 613 B、>32 KB **34 篇**、>64 KB 4 篇、<2 KB 15 篇。
⇒ 分布**没有「碎屑」可清**（<2 KB 只 15 篇）：体积 = 少数大报告 × 数量。**唯一有效动作是按批归档。**

**「无活文档引用」口径**（本审计自定义，与 doctor §8f 不同）：文件名在**活文档**（除 `reports/`、`archive/`、`HISTORY/`、`*/sessions/` 之外的纳管 md）中出现即为「活引用」；另把活文档里的 glob（如 `reports/upstream-status-*.md`）做 `fnmatch` 计入。

```bash
for f in reports/*-202610*.md; do b=$(basename "$f");
  grep -rl --include='*.md' -F "$b" INDEX.md README.md PROGRESS.md AGENTS.md TASKS/*.md DEVICE/*.md \
    RESOURCES/*.md RUNBOOK-BRINGUP/*.md PITFALLS/*.md .pi/*.md .pi/agents/*.md >/dev/null || echo "$(du -b "$f")"; done | sort -rn | head -20
```

结果：**176 篇 / 2 096 KB** 无活引用（顶层 145 篇 / 1 793 KB；文件名日期在 10 月的 **142 篇 / 1 685 KB**）。
Top 10：`bootloader-alternatives-survey-20261030` 53.4K、`doc-slim-20261102` 49.3K、`droidloom-build-device-plan-20261030` 46.6K、
`woa-gunyah-survey-20261024` 40.2K、`research-vertical-y700-lineage-20261101` 39.0K、`research-horizontal-sm8750-20261101` 36.5K、
`audit-20261029-crossdoc` 36.4K、`uefi-samechip-tablet-display-20261028` 35.8K、`mail-triage-20261029b` 29.6K、`tablet-offload-plan-20261030` 29.3K。

**为什么 §8f 门不报**（口径差，不是 bug）：`scripts/doctor/s07-08-docs.py:265-292` 判据 = 「文件名出现在自身以外的**任何** md/sh/py/tsv」⇒ **别的 report/session 提到也算引用**。

### 5.2 增长趋势 —— 精简轮的收益在 4 天内被吃回去

```bash
for d in 2026-10-14 2026-10-20 2026-10-26 2026-11-01 2026-11-05 2026-11-09 2026-11-13; do
  h=$(git rev-list -1 --before="$d 23:59" HEAD); echo "$d TASKS=$(git show "$h:TASKS/README.md"|wc -l) PITFALLS=$(git show "$h:PITFALLS/README.md"|wc -l) reports_md=$(git ls-tree -r --name-only "$h" -- reports|grep -c '\.md$')"; done
git log --diff-filter=A --name-only --pretty=format:'%cs' -- 'reports/*.md' | awk '/^20[0-9][0-9]-/{d=$1} /^reports\//{c[substr(d,1,7)"-W"int(($3-1)/7)+1]++}END{for(k in c)print k,c[k]}' | sort
```

| 日期 | `TASKS/README` 行 | `PITFALLS/README` 行 | `reports/*.md` 篇 |
|---|---|---|---|
| 10-14 | 478 | 60 | 111 |
| 10-20 | 497 | 89 | 168 |
| 10-26 | 629 | 145 | 247 |
| 11-01 | **914** | 191 | 374 |
| 11-05 | **640**（精简轮 −274） | 216 | 415 |
| 11-09 | **1 175**（4 天 +535） | 279 | 472 |
| 11-13 | **1 348** | **326** | **531** |

- 报告新增 **65–112 篇/周（均值 89/周，无衰减）**；照此 `reports/` 每季度再 +2 300 KB ⇒ **归档必须变成例行动作而不是一次性整理**。
- `TASKS/README.md` 30 天被 **380 个提交**改过（`git rev-list --count HEAD -- TASKS/README.md`）：它是全仓最热的文件 ⇒ 只要沿革还写在这里，任何一次精简都会在几天内失效。
- **⇒ 本审计给总管的结构性建议（唯一一条，不含重构）**：把「会话结束写 §5」改成「写 `TASKS/sessions/`，§5 只允许改 Q 表行」——
  落点 = `INDEX.md` §2 规则 4 补一句（≤2 行），并在 `s07-08-docs.py` 加一条「§5 的 `### 20YY-` 块数 >10 即 warn」的软门。

### 5.3 `HISTORY/` 与 `SESSIONS/` 的生成物占比（可再生 = 理论上零风险，但别动）

```bash
printf "HISTORY days=%s md=%sB README=%sB\n" "$(ls HISTORY/days/*.md|wc -l)" "$(du -cb HISTORY/days/*.md|tail -1|cut -f1)" "$(stat -c%s HISTORY/README.md)"
printf "SESSIONS sessions=%s md=%sB README=%sB\n" "$(ls SESSIONS/sessions/*.md|wc -l)" "$(du -cb SESSIONS/sessions/*.md|tail -1|cut -f1)" "$(stat -c%s SESSIONS/README.md)"
```

| 目录 | 派生部分 | 人写部分 | 派生占比 | 生成器 |
|---|---|---|---|---|
| `HISTORY/` | `days/` 47 篇 **148 255 B** | `README.md` 5 501 B | **96.4%** | `scripts/gen-history.sh`（doctor §10 强新鲜度） |
| `SESSIONS/` | `sessions/` 171 篇 **229 604 B** | `README.md` 75 383 B | **75.4%**（若连 README 一起算，2/3 由 `gen-sessions.py` 生成） | `scripts/gen-sessions.py` |

⇒ 二者合计 **305 KB**，占 md 的 2.2%，且**全部可再生/已冻结**：删不动也没收益（doctor §9/§10 是它们的对账门；`SESSIONS/README.md` 还是 §9 的校验基准）。
**真正「不可再生」的 6.7 MB 全在 `reports/`——这就是为什么 §7 的归档只针对 `reports/` 与 `TASKS` §5。**

---

## 6. 既有四份报告的增量复核（维度①：逐条现查）

> 判定：**成立** = 现查后问题仍在；**已解决** = 现查确认已落地；**加重/低估** = 现查比原文更严重。
> ⚠ 执行前提：那几份报告的 `file:line` **已漂**（例：`DEVICE/README.md:123` 的串口条目现在在 `:147`）⇒ 逐条执行前先 `grep -n` 重定位。

### 6.1 `reports/docs-slim-20261113.md` §3.1 的 7 条

| # | 项 | 现查判定 | 证据 |
|---|---|---|---|
| 1 | `AGENTS.md` 项目记忆降级 | ✅ **已解决** | `wc -l AGENTS.md` = **52**（原 60），§项目记忆 = 9 条一行判据 + 「其余不在本文件」指针 |
| 2 | `fastboot fetch` 证据搬家 | ✅ **已解决** | `sed -n '215,220p' RUNBOOK-BRINGUP/README.md` = 一句结论 + 双指针指向 `PITFALLS #290` |
| 3 | `.pi/` 三件套互抄 | ✅ **已解决**（按 §3.1 分工） | `grep -n to-fastboot .pi/AGENT-OPS.md` → 仅 `:38`；并发/单写者落 `ORCHESTRATION §3` / `AGENT-OPS §4` |
| 4 | 进 fastboot 入口授权 | ✅ **已解决** | `.pi/AGENT-OPS.md:38`「唯一入口 = `scripts/to-fastboot.sh`（2026-11-12 定）」 |
| 5 | `RESOURCES §3` 小节重号 | ✅ **已解决** | `grep -nE '^#{2,3} +3(\.[0-9])?' RESOURCES/README.md` → `3.1–3.5` |
| 6 | ~28 条 PITFALLS 索引正文只在专题报告 | ⏸ **成立，精确 = 28 条** | `bash scripts/check-doctor.sh --only 8 \| grep -o 'PITFALLS 索引 #[0-9]*' \| wc -l` → **28**（`289 527-533 579-592 603-608`） |
| 7 | `archive/topics/*` 冻结不回写 | ⏸ **成立（纪律如此，不是债）** | — |

### 6.2 `reports/doc-dedup-audit-20261112.md` §5.2「需用户确认」6 条

| # | 项 | 现查判定 | 证据 / 新事实 |
|---|---|---|---|
| 1 | `AGENTS.md` §项目记忆降级 | ✅ **已解决**（= 6.1#1） | — |
| 2 | **`AGENTS.md:50` 的 `WARN=0` vs 权威 `FAIL=0`** | ⏸ **成立 → 本审计升为 P1-1′（见 §7 A3）** | `grep -n WARN=0 AGENTS.md` → `:42`「`check-doctor` **FAIL=0/WARN=0**」；`.pi/AGENT-OPS.md:90` 权威只要 **FAIL=0**；**HEAD 实测 FAIL=0 WARN=5** ⇒ 常驻判据今天恒假。补一条：新加子门（P1-1）也会撞它 |
| 3 | `MEMORY.md` 仍留「不得要求写 summary」 | ⏸ **成立** | `.pi/memory/MEMORY.md:141` 同时写着「**FAIL=0/WARN=0**」与「项目文档、派工单、`.pi/agents/*.md` 一律**不得**要求 AI 写 summary」；`.pi/AGENT-OPS.md:87` 已作废该禁令（2026-10-19 用户裁定）⇒ **一条记忆同时违例两处** |
| 4 | `USER.md:65` 的 U1/U2 口径 | ⏸ **成立** | `.pi/memory/USER.md:65`：「上机单元不区分 U1/U2，那个已经过时 … DEVICE/TASKS 残留属待清理」；而 `AGENTS.md`（设备等价、身份 `(SN,hwboardid,容量)`、称 U1/U2）+ `DEVICE/README.md` 8 处 U1/U2 台账为现行口径 ⇒ **需用户拍板，agent 不动** |
| 5 | #290 vs RUNBOOK 证据搬家 | ✅ **已解决** | 同 6.1#2 |
| 6 | `RESOURCES §3` 重编号 | ✅ **已解决** | 同 6.1#5 |

### 6.3 `reports/script-redundancy-audit-20261112.md` §0.5–0.6「最危险 3 条 + 最该先修」→ **三条全部已修**

| 项 | 判定 | 证据 |
|---|---|---|
| MANIFEST 装的 `eldroid-bootctl` 是无看门狗版（重铺即退 #368） | ✅ **已修** | `sha256sum scripts/eldroid-bootctl packaging/elden-userland/files/usr/local/bin/eldroid-bootctl` → **同一个 `f86d7d2d…`**（= §0.1 推荐版）；`grep -c sysrq` 两侧均 8 |
| MANIFEST 装的 `slot-attr.py` 是旧变体（`--dry-run` 前置会真写） | ✅ **已修** | `MANIFEST.tsv:34` 与 `:67` 同一 sha `1d433236…`，且 = `scripts/slot-attr.py` |
| `sources.tsv:16` 把 `reboot2` 写成「可靠入口」 | ✅ **已修** | `grep -n reboot2 packaging/elden-userland/sources.tsv` → 现文本「**不是可靠入口** … 进 fastboot 一律走 `scripts/to-fastboot.sh`」 |

⇒ **该报告的剩余价值只剩文档侧（§4 统一口径 / 退役头）**，设备侧 P0 已闭环。下一轮别再重开这三条。

### 6.4 `reports/script-cleanup-audit-20261112.md` §0 八条 —— **八条全部仍成立**，其中 2 条被原文低估

| 原文 | 现查判定 | 证据 |
|---|---|---|
| §0.1 ① `ath12k-load.sh` 装机但零调用 + bind 写路径 | **成立** | `grep -rn 'ath12k-load' scripts/ rootfs/ initramfs/ packaging/ \| grep -v '^scripts/ath12k-load.sh:'` → 只有 `build-rootfs.sh:73` 拷贝名单 + `MANIFEST.tsv:40` + 同步名单，**零调用点**；`sed -n '34,37p'` 仍 `echo "$DEV" > "$DRV/bind"`；`head -3 scripts/ath12k-load.sh` **无 RETIRED 头** |
| §0.1 ② `arm-console-run.sh:14`、`trial.sh:186` 用 `fastboot devices \| grep -q .`（#584） | **成立（2 处行号未变）** | `grep -rn 'fastboot devices.*grep -q' scripts/` → 仅这 2 处违规，另 3 个脚本已改「先落文件再 grep」 |
| §0.2 `kbuild-sanity.sh:26 KDIR=${ROOT}/build/m1-73`（树已不存在） | **成立** | `ls -d build/m1-73` → **No such file**；默认用法不带位置参数 |
| §0.3 `lib-ssh`/`lib-wait` 统一层只落 10% | **成立且加重** | inline `ssh -o ` = **61** 文件（同原文）；`source lib-ssh|lib-fastboot` = **6**；`lib-wait` = **6**；inline `fastboot devices` = **26 文件 / 40 处**（原文 35 ⇒ **+5**） |
| §0.4 `DEVICE` 把 `serial-logger.sh` 写成现役，与 `PITFALLS #622` 冲突 | **成立（行号漂 123 → 147）** | `grep -n serial-logger DEVICE/README.md` → `:147` 现役口径；`PITFALLS/README.md:318`（#622）明写「`serial-logger.sh` 会 open/close 狂抖」⇒ 按文档取证得假阴性 |
| §0.5 `n5b-vk64-death-rate.sh:131` 仍发停用的 `reboot2 bootloader` | **成立且低估：3 处** | `grep -n "reboot2 bootloader" scripts/n5b-vk64-death-rate.sh` → `:131 :167 :177`（`:158` 注释自己说它「静默无效」） |
| §0.6 A/B 三套实现，`fix-ab-mark-successful.sh` Alpine 专用且引用旧 `slot-attr.py` | **成立** | 文件头仍写 Alpine/OpenRC；`:47` 仍 `if [ -x /usr/local/sbin/slot-attr.py ]`（现役根上第一步即 `exit 1`） |
| §0.7 可安全删除 = 0 | **成立** | 我用两档口径（substring 全语料 + 活文档引用）独立复核：**0 个 0 引用** |
| §0.8 §1 13 行 / §2 12 条 / §3 12 条 | **成立（抽查 6 条全中）** | 抽查 = 上面 6 行；未逐条重算，不新开编号 |

---

## 7. ★ 本轮可立即执行清单（10 条，按性价比排序；每条给体量 + 可逆性）

| # | 动作 | 体量估计 | 可逆性 / 风险 | 验收 |
|---|---|---|---|---|
| **A1** | 重生成 `versions/scripts-inventory.tsv`（P1-1：入库 336 行 = 2026-11-08，现查 344 行） | 表 +8 行；无文档变化 | **完全可逆**（`git checkout`）；风险 0 | `diff <(sort versions/scripts-inventory.tsv) <(python3 scripts/static-scan.py --inventory\|sed '1d'\|sort)` → 空 |
| **A2** | 修 4 处 `STANDING.md` 死指针（P1-2，`.pi/AGENT-OPS.md:21,24,62,86`） | ±0 B（4 行改写） | 完全可逆；风险 0 | `grep -c STANDING .pi/AGENT-OPS.md` → 0 |
| **A3** | **统一 `check-doctor` 收尾判据**：`AGENTS.md:42` 与 `.pi/memory/MEMORY.md:141` 的 `FAIL=0/WARN=0` 改 `FAIL=0`（WARN 只列不阻塞），或反向由用户裁决「WARN 也必须清零」并当场把 28 条 §8c 打完 | 2 行；**决策 1 个** | 完全可逆；**风险 = 判据放松** ⇒ 需用户点头（`doc-dedup §5.2` #2/#3 同源） | `grep -n 'WARN=0' AGENTS.md .pi/memory/MEMORY.md` 与 `check-doctor` 实测自洽 |
| **A4** | `TASKS/README.md` §5 的 **49 个日期块（880 行 / 130 KB）下沉 `TASKS/sessions/`**，原地保留 `###` 标题锚（P1-3） | `TASKS/README.md` −130 KB / −880 行（322→~190 KB） | `git mv`+改行，**可逆**；**风险中**（40 个文件按 `§5「…」块` 引用 ⇒ 靠「保留标题字面」消解；不要动 §1/§2 emoji，`PITFALLS #548`） | `check-progress-counts.sh` 仍 36/37 与 9/13；`grep -c '^### 20' TASKS/README.md` 保持（锚在） |
| **A5** | `reports/` **142 篇 10 月件（1 685 KB）`git mv` → `archive/reports-202610/`**（判据 = §5.1「活文档零引用」，不是「日期在 10 月」） | md 总量 **−12%**；`reports/` 531→389 篇 | `git mv` 可整体反做；**风险低**（活文档零引用；§13 资产门只认存在性；`archive/` 已登记，无需改 layout） | `check-doctor` FAIL=0；`scripts/check-doc-assets.sh` PASS |
| **A6** | `reports/upstream-status-2026{1026,1027,1029,1105}.md` → `archive/topics/upstream/`（**只搬旧 4 篇**，−44.6 KB） | 4 篇 / 44.6 KB | 可逆；**风险 = 搬错 `tail -1`**：`check-doc-assets.sh:30` 用 `ls reports/upstream-status-*.md \| sort \| tail -1` 选扫描对象 ⇒ 搬后必须仍指向 `-20261113` | `ls reports/upstream-status-*.md` 只剩 1 篇 |
| **A7** | PITFALLS **28 条**索引条目：逐条标 `RETIRED` 或补 `sessions/` 正文（doctor §8c 现成清单） | +28 行（标 RETIRED 路线）／+28 个短正文（补写路线） | 完全可逆；风险低（**只补不重排编号**，`PITFALLS` 纪律） | WARN 5→**4**；`--only 8` 无该 warn |
| **A8** | 两个软门：① 脚本账新鲜度（A1 的回归防护，与 §10 HISTORY 同族）② `PITFALLS` 索引行 `>700 B` warn（P2-4） | 子门各 ~10 行 shell | 完全可逆；风险 = fast 档耗时（两者都是纯文本，实测 <0.1 s） | 故意改一脚本后 `--staged-fast` 出 warn |
| **A9** | `script-cleanup §0` 的 3 个可落地小修（**只文档/默认值，不碰设备**）：① `ath12k-load.sh` 加 `# ⛔ RETIRED` 头 + 从 `MANIFEST.tsv:40`/`build-rootfs.sh:73` 去项；② `arm-console-run.sh:14`、`trial.sh:186` 改「先落文件再 grep」（#584）；③ `kbuild-sanity.sh:26` 默认 `KDIR=$(cat patches/current-tree)` | 3 文件 +~12 行 / −2 行；MANIFEST 少装 1 件（1 467 B） | 可逆（含 MANIFEST sha 重算）；**风险 = 装机面变化** ⇒ 走一次 `packaging` 重建冒烟 | 三条各一条 grep；`python3 scripts/static-scan.py --inventory` 无新增 UNREFERENCED |
| **A10** | `INDEX.md` 4 处文字对账（P2-3a/b/c/d）+ 3 篇今日无人引用报告各补 1 行指针（`repo-slim-audit` / `todo-inventory-20261113` / `upstream-74-replay-20261113`） | +6 行 | 完全可逆；风险 0 | `check-doctor` §8f warn 消失；`grep -n '46 项' INDEX.md` → 0 |

**A4 + A5 + A6 = 文档体量 −1.82 MB（md 的 13.4%）+ 入口文件 −880 行**，是本轮全部收益；其余 7 条是账实一致性与防回归。
**明确不做**：不删任何脚本、不删 `.bak-*`、不动 `archive/`/`SESSIONS/`/`HISTORY/` 正文、不新建「第 N 份审计报告」。

---

## 8. 明确保持现状（供下一轮免检）

| 对象 | 体量 | 理由 |
|---|---|---|
| `INDEX.md` §2 顶层布局表 / `versions/layout.tsv` | 46 项 | 三向差 0 + 双向门；**动它 = 制造漂移** |
| `TASKS` §0 / `check-progress-counts.sh` | 6.8 KB | 机器导出、`--selftest` rc=0、§16 四条 ok |
| `SESSIONS/`（173 md / 311 KB）+ `HISTORY/`（48 md / 154 KB） | 465 KB | 96–98% 是脚本派生（§5.3），且是 §9/§10 对账门的基准；README 自陈「保留 = 零风险」 |
| `archive/`（177 md / 1.66 MB） | 1.66 MB | 已是归档区；`INDEX` 已声明不得作当前结论；再动 = 纯 churn |
| `.pi/memory/*.md`（201 + 81 KB） | 338 KB | 明细层就是该胖的地方；`AGENTS.md` 已收束常驻层 |
| `scripts/` 264 入口 | 24 541 行 | 死脚本 0、bashism 0；脚本 = 复现路径，不是体积债 |
| 29 个 `.bak-*`（untracked / 85 KB） | 85 KB | `.gitignore:391` 记用户要求保留在盘；未入库 ⇒ 无仓库债 |
| `.pi/sessions/` | 804 MB | 未入库的 harness 轨迹；`RESOURCES §3.4 B4` = 用户 2026-11-06 裁决不清 |

---

## 9. 门禁基线与收尾

```bash
bash scripts/check-doctor.sh | tail -1
```

| 时点 | 结果 |
|---|---|
| 写本篇**前**（基线） | **FAIL=0 WARN=4**（4 条全部既存：registry 前历史镜像无 manifest / 账本已登记例外 / 内核段不可读 / **28 条 §8c 索引条目正文只在专题报告**） |
| 写本篇**后** | **FAIL=0 WARN=5** —— 新增的是 §8f「报告无人引用」，明细含 **3 篇**：`reports/repo-slim-audit-20261113.md`（本篇）+ `reports/todo-inventory-20261113.md` + `reports/upstream-74-replay-20261113.md`（后两篇是并行会话产物，`git status` 显示同为未跟踪） |

⇒ **收尾动作（= §7 A10 的一部分）**：给这 3 篇各补 1 行指针（`INDEX.md:185` 行尾追加即可），否则每轮 doctor 都会挂着这条 WARN，
并按 A3 的裁决决定它是否阻塞收尾。**本篇只写了自己，其余一字未改**：`git status --porcelain` 除本篇与那 2 篇并行产物外为空。
