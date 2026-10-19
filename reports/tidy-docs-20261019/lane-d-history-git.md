# Lane D — HISTORY/ 与 git 增量账（只读取证）

> 范围：只读。工具 = `read` / `grep` / `ls`（**本 lane 无 shell**，故所有 git 数字用「文件证据 + 等价命令」双轨给出；
> 凡需 `git` 才能定论的一律标「待父 agent 实测」并附命令与预期）。
> 复核对象：`HISTORY/README.md`、`HISTORY/days/*.md`（17 个）、`scripts/gen-history.sh`、`scripts/check-doctor.sh`、
> `.githooks/{pre-commit,commit-msg}`、`.git/{config,hooks,logs,refs}`、`INDEX.md`、`TASKS/README.md`、`reports/`。

---

## 0. 结论先行（6 条）

1. **漂移已复核，且比「数字过期」更严重**：`HISTORY/days/` 只到 **2026-10-14**（17 个文件，头部条数合计 **448**，逐日核对见 §1.2），
   而 `HEAD`（`.git/refs/heads/main:1`）= **`8c07f019bf5a0b27186b490e0fbdbafdb14b0822`**。10-15～10-19 的提交**整日缺失**，
   不是「表格里少 45 个数」，而是 `HISTORY/` 对最近一周的提交**完全无记录**。
2. **`gen-history.sh` 确实只管 `days/`**：全文（`scripts/gen-history.sh:1-41`）只 `rm -f "$DAYS"/*.md` + 重写日文件，
   **没有任何一处写 `HISTORY/README.md`** ⇒ README 的 5 处数字（`§1` 448/265e77c、`§2` 合计 448、`§3` type 表 + 「其余 97 个 type」、
   `§5` 「对账结果…448=448→一致」、`§6`「共 17 个日文件」）**必然与 git 脱钩**。
3. **`--check` 的判据天生「只能是刚生成那一刻为真」**：它比的是 `days 条目合计` vs `git rev-list --count HEAD`
   （`scripts/gen-history.sh:11-15`）。任何一次新提交都会让 `HEAD` +1 而 `days` 不变 ⇒ **它永远在生成后的下一次提交即转 FAIL**。
   ⇒ 这类判据**绝不能进 pre-commit**（每次提交必然自伤），只能做「收尾重生成」的提示。这是本次最需要写进文档的一条。
4. **`check-doctor.sh` 对 HISTORY 完全无覆盖**（逐条核对：`ENTRY` 只做围栏/截断/证据指针，`ANGLES` 里 `HISTORY` 因无 `HISTORY/sessions/`
   目录被 `continue` 跳过，`COUNT_RULES` 只有 `INDEX.md` 的 PITFALLS 一条）⇒ 见 §3 的补法。
5. **两个 git 钩子从未生效，已复核为真**：`.git/config:1-4` 只有 `[core]` 的 4 个键，**无 `hooksPath`**；
   `.git/hooks/` 只有 13 个 `*.sample`，**无 `pre-commit`、无 `commit-msg`**；而 `.githooks/{pre-commit,commit-msg}` 两个文件都存在且内容完整。
   ⚠ 附带风险：一旦 `git config core.hooksPath .githooks` 生效，`commit-msg` 会**只对 `lane/*`、`elden/lane-*` 分支强制 trailer**
   （`.githooks/commit-msg:19-22`），main 不受影响；`pre-commit` 只在暂存区命中 `HISTORY/`/`PITFALLS/`/`INDEX.md` 等路径时才跑
   （`.githooks/pre-commit:31-37`）。**若把 §3 的 HISTORY 判据做成 FAIL 并留在 `--staged-fast` 路径里，就会每次提交都 FAIL。**
6. **「未引用报告」不止 4 个**：`m1-73-dts-fix-catchup-20261013.md` 其实**有**引用（`TASKS/README.md:432` 的花括号glob
   `reports/m1-73-{onboard-image,boot-failure,dts-fix-catchup,daily-config-rebuild}-20261013.md`）；
   真正零引用的是 **6 个**：`motor-haptics-vk127-20261017.md`、`vk127-stress-20261017.md`、`session-2026-10-13-evening.md`、
   `init-systemd-vs-openrc-20261011.md`、`libc-musl-vs-glibc-20261011.md`（+ 源码片段 `reports/egltest.cpp` 无仓内指针）。挂载点见 §5。

---

## 1. 复核过程（实际读了什么 + 等价只读命令）

### 1.1 本 lane 实际执行的只读操作（工具级，逐条可重放）

| # | 操作（工具调用） | 取证结论 |
|---|---|---|
| 1 | `read HISTORY/README.md`（153 行全文） | 448 / `265e77c` / 17 日 / 合计 448 / 「其余 97 个 type」/「对账结果 448=448→一致」/「共 17 个日文件」6 处硬编码，行号见 §2.1 |
| 2 | `read scripts/gen-history.sh`（41 行全文） | 只写 `days/*.md`；`--check` 判据在 `:11-15`；`rm -f "$DAYS"/*.md` 在 `:20`；模板 3/4 行在 `:33-34` |
| 3 | `read scripts/check-doctor.sh`（全文 ~390 行） | HISTORY 只在 `:228`（`ENTRY` 围栏清单）与 `:261-262`（`ANGLES`）出现；后者因 `HISTORY/sessions/` 不存在被 `:269` 的 `if not os.path.isdir(sdir)… continue` 跳过；`:313-317` 的 `COUNT_RULES` 只有 `INDEX.md` |
| 4 | `ls .githooks` → `commit-msg`,`pre-commit`；`ls .git/hooks` → 13 个 `*.sample` | 无生效钩子 |
| 5 | `read .git/config`（全文 13 行） | `[core]` 只有 `repositoryformatversion`/`filemode`/`bare`/`logallrefupdates`，**无 `hooksPath`** |
| 6 | `read .githooks/pre-commit` / `commit-msg`（全文） | pre-commit 仅在暂存区命中 `HISTORY/` 等路径时跑 `check-doctor --staged-fast`；commit-msg 只校验 `lane/*`、`elden/lane-*` 分支 |
| 7 | `read .git/refs/heads/main` | `8c07f019bf5a0b27186b490e0fbdbafdb14b0822`（≠ README 的 `265e77c`） |
| 8 | `ls HISTORY/days` | 17 个文件，**最新 = `2026-10-14.md`**，无 10-15…10-19 |
| 9 | `grep '提交记录（\d+ 条）' HISTORY/days` | 逐日：13/6/13/8/8/27/64/14/30/21/24/21/30/35/74/40/20 = **448**（与 README §2 表逐行一致 ⇒ 漂移不在表内，在「未重生成」） |
| 10 | `read HISTORY/days/2026-10-14.md` | 20 条，末条 = `265e77c`（⇒ README「生成时 HEAD」= 该日最后一条，可直接从日档反读，无需 git） |
| 11 | `read .git/logs/HEAD`（53 行全文） | 首行 `clone: from github.com…`（`1a4bd89`），其后 52 条 ref 更新（含 1 条 `commit (amend)`）⇒ **本机新增可达提交 ≈ 49–50**；末条 = `8c07f01` | 
| 12 | `grep -rn` 检索 6 个候选报告名（多轮，含字面量模式） | 见 §5：4 个真孤儿 + 2 个额外孤儿 |

### 1.2 需要 git 才能定论的两项（**待父 agent 实测**）

```bash
cd ~/y700-elden
git rev-list --count HEAD                     # 父 agent 已测 = 493
git rev-parse --short HEAD                    # 预期 8c07f01（与 .git/refs/heads/main 一致）
git rev-list --count 265e77c                  # 预期 448；若 ≠448 ⇒ README 那 448 本身就是错的（不只过期）
git rev-list --count 1a4bd89                  # 预期 443（= 493 - 50，按 reflog 推）；用于解释 493-448=45 与 reflog 50 的 5 条差额
git log --format=%ad --date=short | sort | uniq -c | sort -k1,1nr | head -8   # 每日真实条数（§2 表重算用）
git log --format=%ad --date=short | sort -u | tail -1                          # 预期 2026-10-19（覆盖区间末端）
git log --format=%ad --date=short | sort -u | head -1                          # 若 ≠2026-09-28 ⇒ days 漏掉更早的提交（另一类缺口）
git rev-list --count HEAD --since=2026-10-15                                  # 预期 45（10-15…10-19 缺口）
cat HISTORY/days/*.md | grep -oE '^- [0-9a-f]{7}' | sort | uniq -d | head      # 预期空；非空 ⇒ days 里有重复 hash（会虚增合计）
```

> ⚠ 第 4 行的差额值得父 agent 花 10 秒确认：`448 + 50 = 498 ≠ 493`。可能解释有三（都需实测区分）：
> ① 换机后从 GitHub 重新 clone 的历史与旧机在 10-14 之后被改写（`MIGRATION-LOST` 的「提交史」损失）；
> ② `days/` 里有重复/已不可达的 hash；
> ③ 存在 2026-09-28 之前的提交未被任何日档覆盖（`343a7fe` 未必是根）。
> 命令：`git merge-base --is-ancestor 265e77c HEAD; echo $?`、`git rev-list --count HEAD --not 265e77c`、
> `git cat-file -t 265e77c`、`cat HISTORY/days/*.md | grep -oE '^- [0-9a-f]{7}' | sort -u | wc -l`（唯一 hash 数，若 < 448 即 ②）。

---

## 2. 让数字不再漂移：两种最小方案（**推荐 (b)**）

### 2.1 现行硬编码清单（`HISTORY/README.md`）

| 行 | 原文片段 | 是否会漂 |
|---|---|---|
| `:6` | `> 数字口径：以 git log 为准，随仓库增长需重跑 scripts/gen-history.sh 再生。` | 措辞误导（脚本并不更新这些数字） |
| `:14` | `\| 总提交数 \| **448** \|` | ✔ 必漂 |
| `:15` | `\| 覆盖区间 \| 2026-09-28 → 2026-10-14（17 个自然日） \|` | ✔ 必漂（末端日期 + 日数） |
| `:16` | `\| 生成时 HEAD \| 265e77c \|` | ✔ 必漂 |
| `:17` | `\| 平均每日 \| ≈ 26.3 条 \|` | ✔ 派生量 |
| `:18` | `\| 峰值日 \| 2026-10-12（74 条） \|` | ✔ 派生量 |
| `:30-46` | 17 行逐日条数 | ✔ 新增日/当日新增即漂（**与各日档头部 `（N 条）` 重复**） |
| `:47` | `\| **合计** \| **448** \|` | ✔ |
| `:58-67` | 10 行 type 统计 | ✔ 必漂 |
| `:69` | `> 其余 97 个 type 各 1–5 条` | ✔ 必漂（type 种数） |
| `:117-118` | `scripts/gen-history.sh` / `--check` | 无数字，但需补 `--stats` |
| `:140` | `**对账结果**（生成时）：days/ 条目合计 = **448**，git rev-list --count HEAD = **448** → 一致。` | ✔ **最危险**：断言「一致」，实测早已 FAIL |
| `:151` | `...                # 共 17 个日文件` | ✔ |

> 关键观察：**§2 的逐日条数在 `days/*.md` 每个文件的第 1 行已有同源副本**（`# YYYY-MM-DD — 提交记录（N 条）`），
> 所以删掉 §2 表**不丢任何机器信息**，只是少一眼速览 —— 这一点让「删数字」方案的代价几乎为零。

### 2.2 方案 (b)（**推荐**）：删掉硬编码数字，改成「现查」

**b-1. `scripts/gen-history.sh` 加 `--stats`（约 14 行，插在 `:8` 的 `DAYS=` 之后、`:10` 的 `--check` 分支之前）**

```bash
if [ "${1:-}" = "--stats" ]; then
  head_n=$(git rev-list --count HEAD)
  short=$(git rev-parse --short HEAD)
  first=$(git log --date=short --format=%ad | tail -1)
  last=$(git log -1 --date=short --format=%ad)
  days=$(git log --date=short --format=%ad | sort -u | wc -l)
  echo "总提交数 = $head_n    当前 HEAD = $short"
  echo "覆盖区间 = $first → $last（$days 个自然日）    平均每日 = $(awk -v a="$head_n" -v b="$days" 'BEGIN{printf "%.1f", a/b}')"
  echo "峰值日 = $(git log --date=short --format=%ad | sort | uniq -c | sort -rn | head -1 | awk '{print $2"（"$1" 条）"}')"
  echo "--- 逐日 ---"
  git log --date=short --format=%ad | sort | uniq -c | awk '{printf "%s  %s\n", $2, $1}'
  echo "--- type top10（口径 = subject 首个 ^[a-z_]+）---"
  git log --format=%s | grep -oE '^[a-z_]+' | sort | uniq -c | sort -rn | head -10 | awk '{printf "%-12s %s\n", $2, $1}'
  echo "--- type 种数 = $(git log --format=%s | grep -oE '^[a-z_]+' | sort -u | wc -l)"
  exit 0
fi
```

> 注：`--check` 用的 `grep -cE '^- [0-9a-f]{7} '`（`:11`）对 8+ 位缩写不匹配（`%h` 一旦因对象增多变长就漏计）。
> 顺手改成 `grep -cE '^- [0-9a-f]{7,}'`（**同一处、零风险**）。

**b-2. `HISTORY/README.md` 六处最小替换（每处「原文 → 新文本」）**

| 位置 | 原文 | 改为 |
|---|---|---|
| `:6` | `> 数字口径：以 `git log` 为准，随仓库增长需重跑 `scripts/gen-history.sh` 再生。` | `> 数字口径：**本文件不写死任何计数**（写了必漂，见 §5）。一切数字现查 `scripts/gen-history.sh --stats`；`days/` 各文件头部的「（N 条）」即逐日真值。` |
| `:10-18`（§1 整张表） | `## 1. 总览` + 6 行表 | `## 1. 总览\n\n> **不写死数字**（历史教训：2026-10-19 实测 README 448 vs `git rev-list --count HEAD` 493，且 `days/` 缺 10-15～10-19 整整 5 天）。\n> 现查：\n>\n> ```bash\n> scripts/gen-history.sh --stats   # 总提交数 / 覆盖区间 / 当前 HEAD / 平均每日 / 峰值日 / 逐日表 / type top10 / type 种数\n> ```\n>\n> 单独两项：`git rev-list --count HEAD`（总提交数）、`git rev-parse --short HEAD`（当前 HEAD）。` |
| `:24-47`（§2 表） | `## 2. 按日期统计` + 17 行 + 合计 | `## 2. 按日期统计\n\n> 逐日条数**唯一真值 = 各日档第 1 行的 `# YYYY-MM-DD — 提交记录（N 条）`**（`days/` 目录即清单，`ls HISTORY/days`）。\n> 汇总表用 `scripts/gen-history.sh --stats` 现出，本文件不再抄。` |
| `:51-70`（§3 表 + 「其余 97 个 type」） | 10 行 type 表 + 说明句 | 保留 `:53-54` 的口径段（算法说明，不漂），把表格与 `:69` 换成：`> 分布用 `scripts/gen-history.sh --stats` 现出（top10 + 种数）；类型前缀不等于提交语义分类，只反映作者当时的书写习惯。` |
| `:140` | `**对账结果**（生成时）：… = **448**，… = **448** → 一致。` | `**对账**（现查，不写死）：`scripts/gen-history.sh --check` → 输出 `days 条目合计 = N` / `git rev-list --count HEAD = N`，两者相等即 OK。\n> ⚠ **该判据天生「只在刚生成时为真」**：任何新提交都会让 `HEAD` +1 而 `days` 不变，所以它是**收尾时的重生成提示**，不能当 pre-commit 门（见 §3）。` |
| `:151` | `...                # 共 17 个日文件` | `...                # 每个自然日一个文件（个数以 ls 为准）` |

**b-3. 同步两处外部指针（否则 b 会让它们指向已删的表）**

- `INDEX.md:81`：`（总数见 `HISTORY/README.md` §1）` → `（总数现查 `scripts/gen-history.sh --stats`）`
- `HISTORY/README.md:117-118`（§5 命令块）补一行：
  ```bash
  scripts/gen-history.sh --stats  # 现查全部统计（总提交数 / 逐日 / type），本 README 不写死数字
  ```

**落地成本**：改 1 个脚本（+14 行）+ 1 个 README（6 处）+ 1 行 INDEX。**改完永不漂**（因为不再有数字可漂），且 `check-doctor` 可以只做「禁止重新写死」的廉价断言（§3）。

### 2.3 方案 (a)：`gen-history.sh` 顺带重写 §1/§2 + `check-doctor` 校验（**不推荐，但给全**）

思路：用 HTML 注释包住生成区，脚本只替换这一块，README 其余散文不动。

**a-1. `HISTORY/README.md` 插入标记（§1+§2 合成一块，放在 `:10` 之前）**

```markdown
<!-- BEGIN:gen-history-stats（由 scripts/gen-history.sh 改写；勿手改，改了会被下次生成覆盖） -->
（此处由脚本填充：§1 总览表 + §2 逐日表 + §3 type 表）
<!-- END:gen-history-stats -->
```

**a-2. `scripts/gen-history.sh` 追加（在 `:40` 的 `echo "生成 …"` 之后）**

```bash
# ---- 重写 HISTORY/README.md 的生成块（BEGIN/END 标记之间） ----
readme="HISTORY/README.md"
blk=$(mktemp)
{
  echo "## 1. 总览"
  echo
  echo "| 指标 | 值 |"
  echo "|---|---|"
  echo "| 总提交数 | **$(git rev-list --count HEAD)** |"
  echo "| 覆盖区间 | $(tail -1 "$tmp" | cut -f1) → $(head -1 "$tmp" | cut -f1)（$(cut -f1 "$tmp" | sort -u | wc -l) 个自然日） |"
  echo "| 生成时 HEAD | \`$(git rev-parse --short HEAD)\` |"
  echo "| 峰值日 | $(cut -f1 "$tmp" | uniq -c | sort -rn | head -1 | awk '{print $2"（"$1" 条）"}') |"
  echo
  echo "## 2. 按日期统计"
  echo
  echo "| 日期 | 条数 |"
  echo "|---|---|"
  cut -f1 "$tmp" | uniq -c | awk '{printf "| %s | %s |\n", $2, $1}'
  echo "| **合计** | **$(git rev-list --count HEAD)** |"
} > "$blk"
python3 - "$readme" "$blk" <<'PY'
import sys, re
readme, blk = sys.argv[1], open(sys.argv[2], encoding='utf-8').read().rstrip('\n')
t = open(readme, encoding='utf-8').read()
new, n = re.subn(r'(?s)<!-- BEGIN:gen-history-stats.*?-->\n.*?<!-- END:gen-history-stats -->',
                 '<!-- BEGIN:gen-history-stats（由 scripts/gen-history.sh 改写；勿手改） -->\n'
                 + blk + '\n<!-- END:gen-history-stats -->', t)
if n != 1:
    sys.exit('gen-history: README 生成块标记缺失/重复（期望 1 处），已中止')
open(readme, 'w', encoding='utf-8').write(new)
PY
rm -f "$blk"
echo "已同步 $readme 的生成块"
```

同时 `--check` 增加第三项：`README 生成块里的「总提交数」== $head`（`sed -n 's/^| 总提交数 | \*\*\([0-9]*\)\*\*.*/\1/p'`）。

**a-3. 代价与风险（为什么排在 b 之后）**
- README 变成「部分生成」文件 —— 与项目既定口径（`INDEX.md` §2「`README.md` = 策展 SSOT 正文」、`check-doctor.sh:311` 的 STALECOUNT 提示「改为不写死数字，或同步修正」）**方向相反**；
- 每次重跑都改 README ⇒ 每个提交都可能牵动一个「策展文件」的 diff，且脚本失效（标记丢失/重复）时是**破坏性**的（需要 `n==1` 断言兜底，如上）；
- 仍需一个「README ↔ git」的 doctor 判据，等价于 b 的判据再加一层文件改写正确性。

> **推荐 (b)**：一是项目自己已经立了「不写死数字」的先例（`check-doctor.sh` §8b 的 STALECOUNT 分支就是为了治这类手写计数）；
> 二是 §2 表本来就被 `days/` 头部逐条记录着，删掉零损失；三是 (b) 让「数字漂移」这一类缺陷在结构上消失，而不是靠脚本每次都记得跑。

---

## 3. `check-doctor` 的 HISTORY 判据（<0.5 s）

**一句话判据**：`HISTORY/days/` 的条目合计必须等于 `git rev-list --count HEAD`，**且** `HISTORY/README.md` 不得再出现写死的提交数
（数字唯一出口 = `scripts/gen-history.sh --stats`）。

**具体命令（判据本体，可直接内联进 `scripts/check-doctor.sh`）**

```bash
_d=$(cat HISTORY/days/*.md | grep -cE '^- [0-9a-f]{7,} ')
_h=$(git rev-list --count HEAD)
if grep -qE '^\| *总提交数 *\| *\*\*[0-9]+\*\*' HISTORY/README.md; then
  bad "HISTORY/README.md 又写死了提交数（应改为 scripts/gen-history.sh --stats 现查）"
elif [ "$_d" = "$_h" ]; then
  ok "HISTORY/days 与 HEAD 一致（$_d 条）"
else
  warnf "HISTORY/days 落后 HEAD $_d→$_h 条（收尾请跑 scripts/gen-history.sh）"
fi
```

**成本**：`cat 17 个文件（约 35 KB）+ grep -c` ≈ 3–6 ms；`git rev-list --count HEAD`（493 提交，packed）≈ 10–20 ms；
**合计约 20–30 ms**（远低于 0.5 s）。**待父 agent 实测**：`time (cat HISTORY/days/*.md | grep -cE '^- [0-9a-f]{7,} ' >/dev/null; git rev-list --count HEAD >/dev/null)`。

**插入位置（两个坑必须避开）**
1. **必须放在「慢路径」或 `--staged-fast` 之外**（`scripts/check-doctor.sh:207` 的 `fi   # ← --staged-fast 快速路径到此结束` 之后，
   与 §7/§8/§9 并列，如新增 `== 10. HISTORY 对账 ==`）。若放进 fast 路径 → `.githooks/pre-commit` 每次提交都因 `HEAD` 刚 +1 而 FAIL。
2. **落后只能 WARN、写死数字才 FAIL**：落后是「该重生成」的正常状态；写死数字是唯一真正的错。

---

## 4. `rm -f days/*.md` 全量重写是否违反「不反复删改」

**结论：从 git diff 稳定性看是安全的**——内容只由 `git log` 决定，未变化的日子会**逐字节重写出同一份内容**，
git 按内容比对 ⇒ 不产生 diff（只有 mtime 变）。也就是说「全量重写」在仓库里表现为**只改动真正有变化的日档**：
通常是最后一天（新增条目）+ 新增的日文件；其余 16 个文件 diff 为空。**现状 `days/` 只有 17 个文件、约 35 KB，全量重写成本可忽略。**

**四个会让「全量重写」意外产生大 diff 的例外（必须在文档里写明，否则下次会误判为「脚本乱改」）**

| # | 例外 | 触发条件 | 影响 |
|---|---|---|---|
| E1 | **`%h` 缩写长度变化** | git 对象数增长后自动缩写从 7 位变 8 位 | **17 个日档的每一行 hash 同时变**（一次性、全树 churn）。治法：生成时钉 `--abbrev=10`（或 `%H` 截 10 位），永不再变 |
| E2 | **提交被改写** | `rebase` / `amend` / `filter-repo`（MIGRATION 场景真实存在） | 相关日档的 hash/条数全变，甚至日档被删/新增 ⇒ 属「真变化」，不是脚本问题 |
| E3 | **日期分桶随时区** | `%ad --date=short` 用**本地时区**渲染 | 在别的 TZ 下重跑，跨午夜的提交会换日 ⇒ 建议脚本首行 `export TZ=Asia/Shanghai`（`scripts/gen-history.sh` 目前没有） |
| E4 | **作者日期非单调**（amend/rebase） | `for date in $(cut -f1 "$tmp" \| uniq)`（`:27`）依赖「同一日期相邻」，但按 commit 序 tac 后作者日期可能不连续 | 该日期在循环里出现两次；虽然 `awk -F'\t' -v d=$date '$1==d'` 会过滤**全表**所以内容仍完整，但会重复写同一文件（无数据损失、纯浪费）。顺手改 `for date in $(cut -f1 "$tmp" \| sort -u)` 更稳 |

**文档该怎么写才不误导（`HISTORY/README.md` §5 补 3 行，替换掉「对账结果」段后的空白）**

```markdown
> **重跑是幂等的**：日档内容只由 `git log` 决定 ⇒ 未变化的日档**逐字节相同**，`git diff` 只出现在真正有变化的日期
> （通常是最后一天 + 新增日文件）。因此「全量重写 `days/*.md`」**不是反复删改**，可以放心重跑。
> 三个例外（属真变化或一次性 churn）：提交被 amend/rebase 改写；git 自动缩写长度变化（用 `--abbrev=10` 可永久消除）；
> 在不同时区重跑导致跨午夜提交换日（脚本应钉 `TZ`）。
> 纪律：`days/*.md` **永不手工编辑**（头部已写「请勿手工编辑」）；README 侧不写死数字（§1/§2/§3）。
```

---

## 5. 未被引用的 reports（复核 4 个 → 实为 6 个；逐个给挂载点）

### 5.1 复核结果

| 报告 | 引用状态（grep 全仓，含 `*.md`/脚本/`versions/`） | 判定 |
|---|---|---|
| `reports/m1-73-dts-fix-catchup-20261013.md` | **有引用**：`TASKS/README.md:432` 的**花括号glob** `reports/m1-73-{onboard-image,boot-failure,dts-fix-catchup,daily-config-rebuild}-20261013.md`（故此文件按字面名 grep 命中为 0，父 agent 的计数把它误判成孤儿） | **不是孤儿**，但引用是 glob ⇒ 见 5.2-① 的写法建议 |
| `reports/motor-haptics-vk127-20261017.md` | **零引用**（仅自引：`:4/:63/:66/:84`；`PITFALLS` §29/§30 只覆盖 2026-10-13 的 C10 一期/二期，**没有**「桥 amplitude 默认 0 ⇒ 静音」这条） | 孤儿 |
| `reports/vk127-stress-20261017.md` | **零引用**（仅自引 `:20`；`TASKS/README.md:139` T4 行只指向 `reports/vk127-sampling-20261017.md` + trials `s{3,4,5,6}`，**未覆盖 s7/s8**） | 孤儿 |
| `reports/session-2026-10-13-evening.md` | **零引用**（`reports/Q24-Q28-INDEX.md:66` 指的同名日报是 `reports/session-2026-10-13.md`，白天那份） | 孤儿 |
| `reports/init-systemd-vs-openrc-20261011.md` | **零引用**（`SESSIONS/README.md:254` 指的是 `~/文档/arm平板-systemd-vs-openrc-glibc-vs-musl-调研-2026-10-11.md`，不是仓内这份） | **额外孤儿** |
| `reports/libc-musl-vs-glibc-20261011.md` | **零引用**（同上；仅自引 `:15/:20`） | **额外孤儿** |
| （`reports/egltest.cpp`） | 仓内无指针；`PITFALLS/sessions/45-…md:58` 说的是设备侧 `/tmp/egltest.cpp` | 源片段，非报告；建议在 `reports/camera-linux-vk127-20261018.md` §1 的复现器段补一句「仓内副本：`reports/egltest.cpp`」 |

### 5.2 挂载点（每条一处，最小改动）

| # | 报告 | 挂载点（文件:行 → 加什么） |
|---|---|---|
| ① | `m1-73-dts-fix-catchup-20261013.md` | `TASKS/README.md:432` 保留 glob，但在同段尾加一句把三个易漏项点出来：`（其中 `dts-fix-catchup` = 73e→73f 的 3 处板 DTS 差异台账；`boot-failure` = 两 DTB 逐节点差异）`。**若想让它可被逐文件 grep**：把 432 的 glob 拆成 4 条显式路径（1 行改 4 行）。**也可并入** `reports/session-2026-10-13-evening.md` §2 的 `m1-73-dts-fixes` 行（那行现在只写「报告」，没写文件名）。 |
| ② | `motor-haptics-vk127-20261017.md` | **`PITFALLS/sessions/30-Waydroid马达透传二期：AIDLHAL替换.md`** 末尾（`#239–#243` 段之后）加一条 `#2xx. **桥 amplitude 默认 0 ⇒ 马达静音**（2026-10-17 vk127 实测，修法 = 默认 0→255 + 运行中改幅要重新上传；kprobe 判据 `aw86927_haptics_play_work` 命中数）` + 证据指针 `reports/motor-haptics-vk127-20261017.md`。同时在 **`TASKS/README.md:88`（C10 行）** 尾补：`**2026-10-17 补**：vk127 线复测发现桥 amplitude 默认 0（静音）已修并上机验收，见 reports/motor-haptics-vk127-20261017.md`。 |
| ③ | `vk127-stress-20261017.md` | **`TASKS/README.md:192`（§5 Q28 行）尾**加：`**🆕 2026-10-17**：T4 的 3/3 GOOD 之后**第 4 发即坏发（s7，教科书级 L1 签名、SSH 存活、L2 风暴持续）**，断电真 POR 后 s8 = GOOD（`dsi_isr` 0→41）⇒ 「按会话成簇、整机复位解除」又多一组同镜像配对；报告 reports/vk127-stress-20261017.md`。同段也可在 **`reports/q28-DOSSIER.md:420`（§r 的 T6 补记处）** 加一行指针（该处现在只指 `q28-badboot-m1-baseline-20261015.md`）。 |
| ④ | `session-2026-10-13-evening.md` | **`reports/Q24-Q28-INDEX.md:66`** 尾（现为「详见 `reports/session-2026-10-13.md`。」）改为「详见 `reports/session-2026-10-13.md`（白天）+ `reports/session-2026-10-13-evening.md`（晚间：M1 重基定案 + 12 lane 产物与编排者复核表）。」**或**挂到 `TASKS/README.md:432` 证据层同段（`reports/session-2026-10-13-evening.md` 的 §2 表正是 432 那 4 份 m1-73 报告的产出台账）。 |
| ⑤ | `init-systemd-vs-openrc-20261011.md` + ⑥ `libc-musl-vs-glibc-20261011.md` | **两篇同为「不切」裁决**（同会话 `01a12a67`），→ 在 **`TASKS/README.md` §4/§5「已定不做 / 搁置」**区（`INDEX.md:110` 也列了同一组）加一行：`- **宿主 rootfs 不切 glibc、不切 systemd**（2026-10-11 裁决，零收益/高重建成本）：`reports/libc-musl-vs-glibc-20261011.md`、`reports/init-systemd-vs-openrc-20261011.md``。这样「已定不做」清单与证据一次对齐，且两篇互为准据不再孤立。 |

---

## 6. 落地清单（父 agent 可直接执行，按顺序）

1. **（阻断）** 先实测 §1.2 的 4 条命令，确认 `448` 是「过期」还是「本身错误」（差额 5 条待解释）。
2. **（建议方案 b）** 改 `scripts/gen-history.sh`：加 `--stats`（§2.2 b-1）+ `--check` 的 `{7,}` 与 `sort -u`（§4 E4）+ `TZ` 钉死（§4 E3）+ `--abbrev=10`（§4 E1）。
3. 改 `HISTORY/README.md` 六处（§2.2 b-2），并同步 `INDEX.md:81`（b-3）。
4. 跑 `scripts/gen-history.sh`（生成 10-15…10-19 的 5 个新日档，并把 `days/` 追平 HEAD），再 `--check` 应 OK。
5. 在 `scripts/check-doctor.sh` 慢路径新增 `== 10. HISTORY 对账 ==`（§3 代码块）；**不要**放进 `--staged-fast`。
6. 按 §5.2 给 6 个孤儿报告各加一处挂载点（每处 1 行）。
7. 收尾跑 `scripts/check-doctor.sh` 到 FAIL=0（新增 HISTORY 项若报「落后」属 WARN，正好提示重生成）。

---

## 7. 本次未验证/不确定项（逐条给命令）

| # | 项 | 命令 |
|---|---|---|
| 1 | 本机 git 真正计数（493 为父 agent 实测值，本 lane 无 shell） | `git rev-list --count HEAD` |
| 2 | `265e77c` 是否为 HEAD 祖先（决定 45 vs 50 的差额解释） | `git merge-base --is-ancestor 265e77c HEAD; echo $?` |
| 3 | `days/` 是否有重复 hash（会虚增合计） | `cat HISTORY/days/*.md \| grep -oE '^- [0-9a-f]{7}' \| sort \| uniq -d \| head` |
| 4 | 是否存在 2026-09-28 之前的提交（另一类缺口） | `git log --date=short --format=%ad \| sort -u \| head -3` |
| 5 | §3 判据真实耗时 | `time (cat HISTORY/days/*.md \| grep -cE '^- [0-9a-f]{7,} ' >/dev/null; git rev-list --count HEAD >/dev/null)` |
| 6 | 钩子文件是否可执行（`core.hooksPath` 生效的前提） | `ls -l .githooks/`（应 `-rwxr-xr-x`；若不带 x 需 `chmod +x .githooks/*`） |
| 7 | 若启用钩子，lane 分支提交是否会被 trailer 门拦 | `git config core.hooksPath .githooks && git branch --show-current`（先确认当前不在 `lane/*` 上再启用） |
