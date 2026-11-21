# 文档与踩坑精简（D6 lane）— 死指针 / 重复段 / 索引漂移 — 2026-11-21 夜

**范围**（TASKS §4.0 **D6 文档与踩坑精简**）：只修三类 —— ①死指针 ②重复段 ③索引漂移；
只改 `INDEX.md` / `TASKS/README.md` / `PITFALLS/README.md`（`PITFALLS/sessions/` 未动）。
**硬约束遵守**：未 `git commit`；未碰 `scripts/` `patches/` `out/` `.pi/memory/`；未跑全量 `check-doctor`
（另一 lane 正在重建内核源树，§5d/§14 会抖）；未碰设备（零 ssh/fastboot/adb/qdl）。

---

## 0. 结论数字

| 类 | 发现 | 已修 | 遗留（含理由） |
|---|---|---|---|
| ① 死指针（导航义：指出去找不到） | **7** | **7** | 6 类共 20+ 处按既有豁免/非导航义保留（见 §0.1） |
| ② 重复段（同段内容在两处逐字近似） | **1** | **1** | 0（`INDEX §0` 其余条目是摘要，抽查无 0.85 以上近似） |
| ③ 索引漂移（写死计数 / 索引↔磁盘） | **2** | **1** | **1**（`reports/README.md` 机器索引过期，须跑生成器，不在本轮白名单） |
| 合计 | **10** | **9** | 1 需生成器 + 6 类结构性遗留（另出 4 条非本 lane 的跨 lane 报告项） |

**门禁前后对照（只跑必需子门，未跑全量）**

| 门 | before（本轮开工前） | after（改完） | 判读 |
|---|---|---|---|
| `~/.pi/agent/bin/docs-health --brief` | `1 FAIL / 2 WARN` | `1 FAIL / 2 WARN` | **零新增**；唯一 FAIL = 全局 `hw-stability/.pi/memory/MEMORY.md` 53 KB > 50 KB（非本项目） |
| `bash scripts/check-doctor.sh --only 15` | `FAIL=0 WARN=0`（核对日期 2026-11-21） | `FAIL=0 WARN=0` | 时间序健康，**零新增** |
| `bash scripts/check-doctor.sh --only 8` | `FAIL=0 WARN=1` | `FAIL=0 WARN=1` | 唯一 WARN = `reports/device-window-20261121-night.md` 无人引用（**他 lane 未跟踪新文件**，非本轮产物） |
| `bash scripts/check-doctor.sh --only 7` | `FAIL=0 WARN=1` | `FAIL=0 WARN=1` | 同上 |
| `bash scripts/check-doc-assets.sh`（§13 委托） | `checked=442 missing=0` | `checked=442 missing=0` | 白名单前缀全覆盖，**零新增** |
| `git status --short` | `?? reports/device-window-20261121-night.md` | 本轮文件 `M INDEX.md`、`M TASKS/README.md`、`?? reports/doc-audit-night-20261121.md`、`?? TASKS/sessions/2026-11-21-文档资料审计night.md`；**另有 4 项他 lane 产物**（`?? linux` 21:07 出现的软链、`?? reports/device-window-20261121-night.md`、`M patches/upstream/dwc3-v11-20261121/v11-0000-cover-letter.patch`、`M reports/dwc3-v11-20261121.md`）——均非本轮改动 | 见 §2-④/⑤ |

### 0.1 「死指针」口径与豁免（为什么不把 20+ 处全算缺陷）

`scripts/check-doc-assets.sh` 的判据只覆盖 `patches|patches-userland|reports|scripts|rootfs|packaging|bootslot-b|DEVICE|TASKS|RESOURCES|PITFALLS|RUNBOOK-BRINGUP`
这些**入库前缀**，且 `patches/0011` 这类**前缀截断按 glob 解析**。因此真正的盲区 = `out/ logs/ backup/ build/ env-pass/ archive/ versions/`
（工作区/不可再生区）。本轮即按这个盲区逐条 `test -e` 复核，并沿用四条既有豁免：

1. **MIGRATION-LOST 已标注**：`logs/ui-20261011/`、`logs/cam-bright-20261018/`、`logs/bench-20261011/` 行内已带 `⚠️MIGRATION-LOST`，
   且已入 `versions/migration-gaps-2026-10-17.tsv`（`logs/ LOST`）⇒ 不改（改=删沿革）。
2. **清理记录行本身**：`INDEX.md` §0「2026-11-16 磁盘 A 类清理」行列出 `out/mu-memmap-20261115`、`dl-cam/ndk`、`backup/official-rom`、
   `backup/out-history` —— 这些词就是「被删了什么」的取证内容，非指向 ⇒ 不改（2026-11-21 上轮审计 T10 同判）。
3. **allowlist**：`bootslot-b/boot_b_vk40.img` 已在 `scripts/doc-assets-allowlist.txt`（换机未随迁）⇒ 不改。
4. **非仓库路径**：`debian/patches/Apply-upstream-patches.patch`（设备侧 Debian 打包路径）、AOSP `external/mesa`、
   `~/edl/qdl/build/qdl`、`~/.local/opt/platform-tools/fastboot` ⇒ 非本仓指针，不改。

---

## 1. 逐条 before → after（每条 = 位置 / 现状 / 证据命令 / 改法）

> 复现命令都在仓根跑。`test -e` 返回 1 = 不存在。

### ① 死指针（7 处，全部已修）

| # | 位置 | 现状（before） | 证据命令 | after（改法） |
|---|---|---|---|---|
| A1 | `INDEX.md:51` | `回退表 = backup/HA2EXB0E-16+512/edl-apply-readback-20261121-164957/rollback/` | `ls backup/HA2EXB0E-16+512/edl-apply-readback-20261121-164957/` → 只有 `gpt4-{primary,backup}.bin`、`pre-write-{primary,backup}.bin`、`pre-write-snapshot.json`、`qdl{,-pre}.log`，**无 `rollback/` 子目录** | 路径改到目录本身 + 括号内列实存文件名（保留「回退表」语义） |
| A2 | `INDEX.md:262` | 「…已出」：`backup/out-history-20261121/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img` | `ls backup/out-history-20261121/p2-minbase-20261118/` → 只有 `rootfs-minbase-20261118.ext4.img.sha256` + `boot-minbase-labellinux.img`；`versions/out-artifacts.tsv:15` 原文即「boot 件 + rootfs **sha 清单**」 | 保留原路径（指 sha 清单）并标注「**镜像本体未随归档**」+ 指 `versions/out-artifacts.tsv` 行 15 |
| A3 | `INDEX.md:286` | 「树 = `build/daily` `v7.3.1-5-g4bdf1711b5`」 | `ls -d build/daily` → No such file（2026-11-19 磁盘清理） | 加「**该树已于 2026-11-19 磁盘清理删除**，版本标识以本行文字为准」+ 指 `reports/disk-cleanup-20261119-validation-impact.md` |
| A4 | `TASKS/README.md:45`（G1-3） | `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` | `ls env-pass/` → 只剩 `scripts/ tools/`；`git log --all -- env-pass/backup-20261002` 空（从未入库） | 保留路径 + 标「**该归档不在仓**（2026-10-17 换机前件、未入库）」 |
| A5 | `TASKS/README.md:58`（G1-34） | `build/vk151` 的未提交工作区 | `ls -d build/vk151` → No such file（11-19 清理；`build/` 只剩 `elden-tree`/`g7-tree`/`phoc-src-*`/`phosh-src-*`/…） | 括号补「该树已于 2026-11-19 清理 + 报告指针」 |
| A6 | `TASKS/README.md:91`（C4） | `out/sensord/android.hardware.sensors@1.0-service.waydroid` | `ls out/sensord/` → `eldroid-sensord`、`eldroid-sensord-host` | 改为 `out/sensord/eldroid-sensord` + 注明旧名已不实存 |
| A7 | `TASKS/README.md:92`（C5） | `build/daily/.config` 被 vk189-suspend 改动 | 同 A3 | 保留路径 + 括注「树已于 2026-11-19 清理」（事故事实不变） |

### ② 重复段（1 处，已修）

| # | 位置 | 现状 | 证据命令 | 改法 |
|---|---|---|---|---|
| B1 | `INDEX.md:25–28`（§0「2026-11-21 傍晚 — dwc3 v11 SENT-ready」3 条 bullet） | 与 `TASKS/README.md:470`（§7「2026-11-21 傍晚增量」）**逐字近似**：三处改动描述、版本账事实（v10 实投 1/3 = 11-18 版 / 11-20 重写版从未投出）、件路径三句都在两处 | 句级 difflib（跨三文件、同文件邻行除外）：`INDEX.md:27 ↔ TASKS:470` ratio **0.85**、`INDEX.md:28 ↔ TASKS:470` **0.89**；全仓仅此一组 >0.85 | `INDEX §0` 压成 1 条摘要（保留件路径/门禁/0004 hold），细节改为指向 `TASKS §7` 的**一行指针**（原文仍在 TASKS §7，零信息丢失） |

### ③ 索引漂移（2 处，修 1）

| # | 位置 | 现状 | 证据命令 | 处置 |
|---|---|---|---|---|
| C1 | `INDEX.md:364` | 「`reports/README.md`（**509 篇**的机器生成目录…）」 | `ls reports/*.md \| wc -l` → **602**；`reports/README.md:7`「报告总数：**580**」⇒ 三处三个数（509/580/602） | **已修**：删死数字，改为「篇数不写死：现查 `ls reports/*.md \| wc -l`」（符合 `INDEX §2` 规则 7；`check-doctor §8` 的 `STALECOUNT` 只因「PITFALLS N 节」正则触发，不涉此项，改后仍 `[ok]`） |
| C2 | `reports/README.md:7` | 机器索引自报 580 篇，磁盘 602 | `python3 scripts/reports-index.py --check` → `reports/README.md 过期：重新跑 scripts/reports-index.py` | **遗留**：修复=跑生成器重写该文件，属 `scripts/` 侧且生成物（不在本轮白名单）⇒ 交父代理，见 §2-③ |

**已核实「无漂移」的三项**（避免下轮重复劳动）：

- `PITFALLS` 正文编号：`grep -oE '^\| [0-9]+ \| \*\*#[0-9]+' PITFALLS/README.md | grep -oE '#[0-9]+' | sort | uniq -d` → **空**（无重复行）；
  索引行数 289（`grep -cE '^\| [0-9]+ \| \*\*#'`），正文 `## #` 243 个、`archived=` 28 条、`REPORTS_ONLY` 0 条 ⇒ `check-doctor §8` 全 `[ok]`。
- `PITFALLS/README.md` 表头已自守「条目编号范围不写死 / 最后更新勿写死日期」⇒ 无 C1 类漂移。
- `Q`/`M`/`G1` 编号：§5 表头已写明「Q27 从无此号（幻影引用已清）」，本轮未发现新的同号异义。

### ④ 结构性遗留（发现未修，附理由 —— 建议单独一轮，勿混进本轮）

| # | 位置 | 现状 | 证据 | 为什么本轮不修 |
|---|---|---|---|---|
| D1 | `TASKS/README.md:46`（G1-23 行） | 行内 **8 个管道**（应为 6 列 / 7 管道）：`⟪全文见 …⟫` 之后残留 `|blank` 命中 0），**未覆盖熄屏/唤醒转换**；…`——下沉剪切残留，`vblank` 丢了起始反引号 | `awk 'NR==46{print gsub(/\|/,"|")}'` → 8 | 修=重排单元格并复原被剪的短语，属**语义编辑**，超「纯搬运/改指针」边界；建议单轮对照 `TASKS/sessions/2026-11-06-TASKS行038-G1-23.md` 修 |
| D2 | `TASKS/README.md:92`（C5 行） | **10 个管道**（应为 5 列 / 6 管道）：三段「★2026-10-23 / 10-28 收尾」被塞进同一行不同单元格 | `awk 'NR==92{print gsub(/\|/,"|")}'` → 10 | 同上（三处正文需按 `sessions/2026-11-03-TASKS行81-C5.md` 回填顺序） |
| D3 | `INDEX.md` 10 处缩写会话指针 | `PITFALLS/sessions/329-…`、`TASKS/sessions/2026-11-19-…` 等（行 142/157/169/183/193/206/219/235/252/284） | 逐行 `sed -n 'Np'`；`…` 使 `test -e` 恒假 | 10 处全改会吃掉本轮「≤20 处」预算的过半，且 `ls` 可秒查；建议父代理按 T4 口径（2026-11-21 上轮修 `M6` 截断名之法）批量一轮 |
| D4 | `PITFALLS/README.md` 索引行内历史路径 | `build/vk151/.config`（L156）、`out/stage-debian/`（L164/185）、`out/boot-elden-vk158.img`（L220）、`build/m3v2-7.3rc7`（L341）、`build/daily`（L303） | 逐个 `test -e` = 1 | 这是**事故当时的路径事实**（「当时的 `.config` 被毁」「当时的产物就读到翻转字节」），不是导航指针；改成「已删」会削弱证据且顶破「索引行 ≤800 B」⇒ 保留 |

---

## 2. 建议父代理后续动作（按文件分组，可照做）

1. **`reports/README.md`（C2，P1）**：`python3 scripts/reports-index.py` 重生成后 `git add`；随后 `python3 scripts/reports-index.py --check` 应 rc≠1。
   这是本轮唯一「索引↔磁盘」实锤漂移，且 `reports/README.md` 是 `reports/` 的查全入口，过期会让「哪篇没人引用」判断全错（现磁盘 602 篇、索引 580 篇 ⇒ 22 篇不在索引里）。
2. **`TASKS/README.md` D1/D2（P1）**：G1-23 行补回被剪短语（`（`vblank` 命中 0）`）并把 7 个单元格收敛回 6 列；C5 行按 `sessions/2026-11-03-TASKS行81-C5.md` 把三段收进「状态」列。两行都属「人肉能读、表格解析读丢」的静默故障（`check-doctor §8 TBL` 只查「续行不以 `|` 开头」，查不到多管道）。
3. **`INDEX.md` D3（P2）**：10 处 `…`/截断会话指针改全名，一条命令可批量生成映射：
   `for n in 142 157 169 183 193 206 219 235 252 284; do sed -n "${n}p" INDEX.md | grep -o '`[^`]*…[^`]*`'; done`。
4. **`.gitignore`（P1，非文档 lane）**：`git status` 现多出 `?? linux`（软链 → `geekidos-linux`）；`.gitignore` 有 `/geekidos-linux/` 但**没有 `/linux`** ⇒ 软化链接会被误 `git add`。建议加 `/linux` 一行（`RESOURCES §3` 同步一句）。
5. **`versions/layout.tsv`（P1，内核重建 lane 收口项）**：`check-doctor --only 14` 现报
   `FAIL 布局注册表不一致：geekidos-linux / linux 顶层条目未登记`——因 2026-11-19 清理时删了这两行（表头注释留了重登记步骤）。
   重建 lane 收口时按注释把两行加回，否则每一轮 §14 都红。**注意：此 FAIL 与本轮文档改动无关**（我未碰 tsv/脚本）。
6. **`reports/device-window-20261121-night.md`（P2）**：`check-doctor §8 ORPHANR` 唯一 WARN，无人引用。由产出它的 lane 在 `TASKS §4.0` 或对应 README 补一行指针即可（我不代改，避免抢写别人的报告行）。
7. **`docs-health` 全局 FAIL（P2）**：`hw-stability/.pi/memory/MEMORY.md` 53 KB > 50 KB ⇒ `~/.pi/agent/bin/mem-split`；不属本项目文档。

---

## 3. 变更清单（本轮写盘）

```
 M INDEX.md        6 +/7 -   （A1/A2/A3 死指针、B1 去重、C1 去写死计数）
 M TASKS/README.md 4 +/4 -   （A4/A5/A6/A7 死指针）
?? reports/doc-audit-night-20261121.md          （本报告）
?? TASKS/sessions/2026-11-21-文档资料审计night.md （会话记录）
```

**他 lane 同期产物（非本轮，仅供父代理区分）**：`?? linux`、`?? reports/device-window-20261121-night.md`、
`M patches/upstream/dwc3-v11-20261121/v11-0000-cover-letter.patch`、`M reports/dwc3-v11-20261121.md`。

未改：`PITFALLS/README.md`（三类均查无实据，理由见 §1-③/D4）、`PITFALLS/sessions/**`、`archive/**`（本轮无需搬移）。

## 4. 复现全套（一条命令看结论）

```bash
cd /home/xuqianhui/y700-elden
~/.pi/agent/bin/docs-health --brief            # 1 FAIL（全局 hw-stability）/2 WARN —— 与改前一致
bash scripts/check-doctor.sh --only 15          # FAIL=0 WARN=0
bash scripts/check-doc-assets.sh                # checked=442 missing=0
git diff --stat                                 # INDEX.md 6+/7-、TASKS/README.md 4+/4-
```
