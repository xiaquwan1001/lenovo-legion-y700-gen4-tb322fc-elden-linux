# 仓库卫生核对（只读，2026-11-04）

范围：`/home/xuqianhui/y700-elden`，HEAD=`cc6c16f`。全程只读：未改仓库文件、未上机、未提交。

## 0. 方法与环境

- 只用 `git status/ls-files/grep/show`、`du`、`sha256sum`、`find`、`read`；四个门禁脚本先读源码确认无写副作用再跑。
- 结论带证据；不确定标「未证」。

## 1. 未跟踪/未提交项盘点

### 1.1 全量现状（`git status --porcelain`）

- 未提交的**已跟踪**改动：0（`git status --porcelain` 无 ` M`/`M ` 行）。工作区干净面 = 只有未跟踪项。
- 未跟踪条目共 **89 行**：88 个二进制文件（`reports/artifacts/uefi-dxe*-20261104/`）+ 1 个目录 `.pi/plans/next/`（本条交付物所在目录）。
- 未跟踪总字节数：`git status -z | xargs du -cb` = **226 551 139 B ≈ 216 MiB**。
- 形成方式：11 个目录 × 8 个同名文件：
  `uefi-dxe-20261104`、`uefi-dxe2-…` … `uefi-dxe11-…`（`ls -d reports/artifacts/uefi-dxe*-20261104` 共 11 项，每项 `du -sh` = 21M）。
  每目录 8 个：`SM8750_EFI.fd`(4.0M) `bootpayload.bin`(2.4M) `kernel.bin`(2.4M) `lenovo-y700g4-v3.img`(2.4M) `payload-v2aligned.bin`(4.0M) `payload-v2aligned.bin.gz`(2.4M) `uefi-v0.img`(2.4M) `BootShim.bin`(776B)。

### 1.2 是否被 .gitignore 覆盖

**未被覆盖**（跑 `git check-ignore -v reports/artifacts/uefi-dxe-20261104/uefi-v0.img` → 空 = NOT IGNORED）。
对照：.gitignore 只对**特定** artifact 目录的 `*.img` 做了豁免式忽略，没有通用规则：

- `.gitignore` 末段：`reports/artifacts/uefi-ddr-20261101/*.img`、`reports/artifacts/uefi-ddrcut-20261101/*.img`、`/reports/artifacts/uefi-edl-read-20261101/*.bin` —— 都是**逐目录点名**，`uefi-dxe*-20261104/` 不在名单内。
⇒ 现状是「既没忽略、也没入库」的裸未跟踪态（每次 `git status` 都会被 88 行噪声淹没）。

### 1.3 同目录里哪些已入库（可对账面）

每个 dxe 目录的**文本三件已入库**：`build.log` `manifest.txt` `SHA256SUMS`（`git ls-files 'reports/artifacts/uefi-dxe*20261104*'` → 各 11 份）。
已入库的 `SHA256SUMS` 覆盖 4 个文件（`cd <dir> && sha256sum -c SHA256SUMS` → 11/11 目录全 OK）：
`SM8750_EFI.fd`、`BootShim.bin`、`kernel.bin`、`uefi-v0.img`。
**未登记 sha 的 4 个**：`bootpayload.bin`、`payload-v2aligned.bin`、`payload-v2aligned.bin.gz`、`lenovo-y700g4-v3.img`（不在 SHA256SUMS 里，只有 `payload-v2aligned.bin` 被 `reports/uefi-payload-execution-20261104.md:82`/`scripts/uefi-repack-v2aligned.py` 提到名字；`lenovo-y700g4-v3.img` 仅出现在 `scripts/uefi-build-variant.sh`）。
⇒ 缺口 A：这 4 类中间件既无 sha 也无入库，属「可重生成但指纹未留」。

### 1.4 与最近提交「vk 身份表收录本轮 8 个 out/uefi-*.img」的一致性

提交 `c716521`（`git show --stat`）：改了 `versions/vk-kernel-identity.tsv`，新增 8 行。

- **文件真存在**：8/8 全在（逐个 `stat` 均 67 194 880 B，与 `ls -la out/uefi-*.img` 一致）：
  `uefi-20261103-v2aligned` / `20261104-{dual,fbband,fbfill,m3block,nocivac,prepi,prog}`。
- **只是「按名字收录」，不是「sha 收录」**：新增行的形状是
  `(no-payload)\tuefi-….img\t-\t(无内核载荷)…\tskip`（`versions/vk-kernel-identity.tsv:76-83`，表头 11 列见 `:1`）——`kbin_sha`/`src_sha` 列**全空**，flag=`skip`。这张表是「内核身份表」，UEFI 镜像无内核载荷故 skip，**没有 sha 字段可用**。
- **out/ 侧 sha 未登记在任何受管文本里**：`out/*.img` 被 `.gitignore` 的 `/out/*`+`!/out/*.manifest` 挡住（`git ls-files out/uefi-20261104-dxe.img` 空）；`sha256sum out/uefi-20261104-dxe.img` = `d1727231…`，`git grep d1727231` → 0 命中。
  唯一例外是坏消息里的好消息：`reports/uefi-payload-execution-20261104.md:44-49,101` 记了这 8 个镜像的**8 位 sha 前缀**，逐个与实测一致（fca136d9/23f1cbdb/351640e2/e18f0be4/ce3292d4/daf8d891/e5aa7164、v2aligned 3724ce34）⇒ **8 个已被「报告内 8 位前缀」事实登记**。
- **后续提交 9bcf0b6/1e613ee 的 11 个 dxe 镜像连前缀都没有**：`out/uefi-20261104-dxe{,2..11}.img` 实测 sha 前缀（d1727231/dd3ca219/f2a9e4b9/c6b93b25/9d74be12/9e4dffcd/8fb6755a/3364d61e/a8f0fc0e/bfd04e84/400206d7）**`git grep` 全 0 命中**；身份表也只有名字行（`versions/vk-kernel-identity.tsv:78-88`，即 dxe 到 dxe11 共 11 行）。
  `reports/artifacts/uefi-boot-20261103-dxe*/` 里只有 `boot.txt`（ABL 日志），**没有 SHA256SUMS**。

**结论（入库缺口，按证据分级）**：

| 项 | 现状 | 缺口 |
|---|---|---|
| 8 个 11-03/11-04 早批 out/uefi-*.img | 名字进身份表（skip）+ 报告内 8 位 sha 前缀 | 无 64 位 sha 台账；但前缀可核对，**低风险** |
| 11 个 out/uefi-20261104-dxe*.img | 只有名字行，sha **0 处** | **中风险**：不可复现核对；建议至少把 sha256 写进 `reports/artifacts/uefi-boot-20261103-dxe*/SHA256SUMS` 或 `TASKS §5` 块 |
| 88 个未跟踪 dxe 中间件（226 MiB） | 未忽略、未入库 | `git status` 噪声 + 12 个文件无指纹（缺口 A） |

## 2. 四个门禁脚本结果

### 2.0 先确认无写副作用（要求 2 的前置）

| 脚本 | 写操作审计 | 结论 |
|---|---|---|
| `scripts/check-layout.sh` | 只有 `mktemp`+`trap rm -f` 临时文件；其余 grep/ls（`:1-64`） | 纯只读，可跑 |
| `scripts/check-progress-counts.sh` | 只开 `TASKS/README.md` 读 + `print`（`:18-84`） | 纯只读 |
| `scripts/check-project-memory.sh` | **`--fix` 会 `mkdir -p`/`rm -f`/`ln -s`**（`:25-33`）；无参数则只校验 | 本次不带 `--fix` |
| `scripts/check-doctor.sh` | `grep -nE '>>|tee|mkdir|rm -|git add'` → 仅 `:193 rm -f /tmp/abi5f.$$`（临时文件）；头注释 `:2` 自述「只读，不改任何文件」 | 纯只读 |

### 2.1 逐个结果

| 命令 | 退出码 | 结论 |
|---|---|---|
| `./scripts/check-layout.sh` | 0 | `PASS: 布局注册表一致（entries=46）` |
| `./scripts/check-progress-counts.sh` | 0 | `G1 完成 33 / 在范围 35（ID 总数 37，取消 2；未完成 2）[✅30 🟢3 🟡2 ❌2]`、`G2 完成 8 / 在范围 12（未完成 4）[✅6 🟢1 🎯1 🟡2 🆕1 ⬜1]` |
| `./scripts/check-project-memory.sh` | 0 | `OK（.pi/memory ⇄ ~/.pi/agent/projects-memory/y700-elden；记忆文件 2 个，项目技能 11 个）` |
| `./scripts/check-doctor.sh`（全量，`timeout 900`） | 0 | **FAIL=0 WARN=5**（明细见 2.2） |

### 2.2 check-doctor 的 5 个 WARN（无 FAIL）

1. §5 vk 版本账：`[warn] registry 前的历史镜像无 manifest（历史留白，见审计档案）：vk183-fastrpc`
2. §5d 内核身份表：`[warn] 账本已登记的例外（理由见 versions/vk-ledger-known-issues.tsv）`——列出 ~70 个 `uts_dup*/num_ne_tag` 已知例外（`versions/vk-ledger-known-issues.tsv` 是理由账，属**有意豁免**）。
3. §5d：`[warn] 内核段不可读（boot 镜像但载荷解不出 ⇒ 免于身份核对）：boot-elden-posctrl-markspin-v2-20261103.img boot-elden-posctrl-markspin2-v2-20261103.img boot-elden-posctrl-markspin3-v2-20261103.img boot-elden-posctrl-markspin3gz-v2-20261103.img boot-elden-vk167-trace.img`（5 个 UEFI probe 件，无内核段是设计使然）。
4. §5d：`[warn] 无版本号构建拷贝 1 个（build-boot.sh 默认产物）：boot-elden.img`。
5. §10 HISTORY 对账：**`[warn] HISTORY/days 落后（未覆盖 HEAD cc6c16f5a6 或 HEAD~1 1e613eeb8b）→ 跑一次 scripts/gen-history.sh`** ← 直接对应本任务第 4 项，是**唯一需要动手的真实缺口**。

其余节全 `[ok]`：§5e manifest 完整性、§5f ABI（`build/m1-73` `struct device.of_node @ 624`）、§6 静态卫生、§7 入口文档围栏、§8 索引↔磁盘对账（含 `reports/ 无孤儿报告`）、§9 SESSIONS 快照（`OK=7 FAIL=0`）、§11 hooks、§12 模块化、§13 文档资产路径（`checked=308`）、§14 布局注册表（`entries=46`）。

## 3. 2026-11-03 报告登记覆盖（INDEX / PROGRESS / TASKS）

### 3.1 候选文件清单（磁盘实存）

`ls reports/uefi-*2026110[34]*.md` → 7 篇：`uefi-external-scan-20261103.md`、`uefi-github-scan-20261103.md`、`uefi-mail-triage-20261103.md`、`uefi-next-step-decision-20261103.md`、`uefi-posctrl-20261103-summary.md`、`uefi-posctrl-linux-entry-20261103.md`、`uefi-payload-execution-20261104.md`。
另有 `RESOURCES/sessions/2026-11-03-Project-SunUEFI复用盘点.md`、`TASKS/sessions/2026-11-04-UEFI载荷首次被执行.md`、`PITFALLS/sessions/2026-11-04-UEFI-DxeCore从未启动.md`（后者不在 `TASKS/sessions/`）。

### 3.2 三份 SSOT 文档的引用计数（`grep -cF`）

| 文件 | INDEX.md | PROGRESS.md | TASKS/README.md |
|---|---|---|---|
| reports/uefi-next-step-decision-20261103.md | 0 | 0 | **1** |
| reports/uefi-posctrl-20261103-summary.md | 0 | 0 | **1** |
| reports/uefi-payload-execution-20261104.md | 0 | 0 | **3** |
| reports/uefi-posctrl-linux-entry-20261103.md | 0 | 0 | 0 |
| reports/uefi-mail-triage-20261103.md | 0 | 0 | 0 |
| reports/uefi-github-scan-20261103.md | 0 | 0 | 0 |
| reports/uefi-external-scan-20261103.md | 0 | 0 | 0 |
| RESOURCES/sessions/2026-11-03-Project-SunUEFI复用盘点.md | 0 | 0 | 0 |
| TASKS/sessions/2026-11-04-UEFI载荷首次被执行.md | 0 | 0 | **1** |
| PITFALLS/sessions/2026-11-04-UEFI-DxeCore从未启动.md | 0 | 0 | **1** |

### 3.3 判定（按文档各自的角色，不是单纯计数）

- **TASKS/README.md ＝ 已覆盖**：§5 顶层块齐了 —— `:143`「2026-11-04（晚）DxeCore 从未启动」、`:155`「2026-11-04 载荷被执行→PrePi→DXE」、`:129`「2026-11-03 晚→11-04」、以及 11-03 决策块（`uefi-next-step-decision` 三份子报告同目录声明）。G1-29 行已内含 2026-11-04 状态更新。
- **PITFALLS #490–#496 ＝ 已覆盖**：`PITFALLS/README.md:195-201` 行号 154–160 七条全在；`#490/#491/#492` 指向 `PITFALLS/sessions/157-UEFI载荷执行三层判据与两条通道边界.md`（存在，36 行），`#493–#496` 指向 `PITFALLS/sessions/2026-11-04-UEFI-DxeCore从未启动.md`（存在，69 行）。
- **RESOURCES/README.md ＝ 已覆盖**：`:80` 有「★2026-11-03 增第二路线（Project-SunUEFI）」正文，`:231` 把该 session 文件列入表。
- **INDEX.md ＝ 遗漏且指针过期**：全文 0 处提到上述任何报告；`:189` 现状快照仍写「当前口径与四臂判别结果只读 `TASKS/README.md` §5（**11-01/11-02 块**）」——TASKS §5 现在已有 11-03/11-04 三块，指针口径已落后。
- **PROGRESS.md ＝ 遗漏**：里程碑表最大日期 = `| 2026-11-02`（`grep -oE '^\| 2026-1[0-9]-[0-9]{2}' PROGRESS.md | sort -u | tail -1`），`grep -n '2026-11-0[34]' PROGRESS.md` → **0 行**；文件 mtime `Nov 2 13:28`。即 11-03（判据纠正/下一步决策）与 11-04（载荷执行/DXE）两条里程碑在公开面完全缺失。
- **子报告（mail/github/external-scan、posctrl-linux-entry）无顶级指针 ＝ 可接受**：它们都被 `reports/uefi-next-step-decision-20261103.md` / `reports/uefi-posctrl-20261103-summary.md` / `reports/uefi-payload-execution-20261104.md` 引用，而后者已被 TASKS §5 收录；INDEX §2 的「跨角度写主角度一个文件」规则允许这种聚合引用（doctor §8 `reports/ 无孤儿报告` 也 PASS）。

**缺失登记项汇总**：INDEX.md `:189` 口径过期（必须补）；PROGRESS.md 缺 11-03/11-04 两条里程碑（建议补）；`reports/uefi-posctrl-linux-entry-20261103.md` 在 SSOT 级无独立指针（建议补一行，非硬缺口）。

## 4. HISTORY/days/2026-11-03.md 对最新 4 个提交的覆盖

**结论：不覆盖，且缺 7 条（不止 4 条）。**

- 文件首行自述「提交记录（**13 条**）」（`HISTORY/days/2026-11-03.md:1`），最后一条 = `45bf341e9c docs: 资产与进度文档再精简…`（`:18`）。
- 实际 2026-11-03 的提交数（HEAD 祖先中 author date = 11-03）：`git log --date=short --format=%ad | grep -c '^2026-11-03$'` = **23**；日档只列 13 ⇒ **缺 10 条**（不是 4 条）。
  13 + 10 = 23 完全对得上，无 history/* 回填差异（`--all` 也给 23）。
  缺的 10 条（`git log --date=short --format='%h %ad %s' | awk '$2=="2026-11-03"'` 前 10 行）：
  `cc6c16f`(22:49) `1e613ee`(22:45) `c716521`(20:36) `9bcf0b6`(20:26) `8c66211`(20:25) `b9007de`(20:25) `68274f2`(20:09) `31c4715`(17:30) `385492c`（三线核查裁决）`1bd6297`（history 重生成）。
  ⇒ 被点名的 4 个（`cc6c16f/1e613ee/c716521/9bcf0b6`）全在缺口内。
- 因此被点名的 4 个提交 **一个都没进日档**：`grep -nE 'cc6c16f|1e613ee|c716521|9bcf0b6' HISTORY/days/2026-11-03.md` → 0 行。
- 独立复核：`./scripts/check-doctor.sh` §10 也给同一结论 —— `[warn] HISTORY/days 落后（未覆盖 HEAD cc6c16f5a6 或 HEAD~1 1e613eeb8b）→ 跑一次 scripts/gen-history.sh`。
- **修法（不要手改）**：`HISTORY/days/*.md` 是派生物（`scripts/gen-history.sh:9`「永不手工编辑」；`HISTORY/README.md:4` SSOT 声明），执行 `scripts/gen-history.sh` 后 `git diff` 应只动 `HISTORY/days/2026-11-03.md`（幂等脚本，`:5`）。验收：日档首行变「23 条」且上述 10 个 hash 各出现一次；再跑 `scripts/gen-history.sh --check`。
  - 本次**未执行**该脚本（它会写文件，任务要求只读）。

## 5. 清单：必须补 / 建议补 / 无需动作

> 编排者 2026-11-04 已独立复核本节引用的关键数字：`reports/artifacts/uefi-dxe*-20261104` = **11 目录 / 226 MB**、`git log --date=short | grep -c 2026-11-03` = **23**、`HISTORY/days/2026-11-03.md` 首行「13 条」、`INDEX.md:189` 仍写「11-01/11-02 块」、`grep -n '2026-11-0[34]' PROGRESS.md` = **0 行**。均与 lane 报告一致。

### 5.1 必须补（有硬性不一致或噪声）

| # | 项 | 动作（可直接粘贴） | 验收 |
|---|---|---|---|
| M-1 | `INDEX.md` 口径过期：`:189` 仍写「当前口径与四臂判别结果只读 `TASKS/README.md` §5（**11-01/11-02 块**）」 | 改成「…只读 `TASKS/README.md` §5（**11-03/11-04 块**；11-01/11-02 已下沉）」；并在 §2 报告索引里加一行 `reports/uefi-payload-execution-20261104.md`、`reports/uefi-posctrl-20261103-summary.md` | `grep -n '11-0[34]' INDEX.md` 非空；`./scripts/check-doctor.sh` §7/§8 仍 `[ok]` |
| M-2 | `reports/artifacts/uefi-dxe*-20261104/` **11 目录 226 MB 裸未跟踪**（既未入库也无 ignore 规则 ⇒ 每次 `git status` 88 行噪声） | 二选一（建议 a）：**(a) 只入库「可复现身份」三件**：每目录只 `git add` `BootShim.bin`+`manifest.txt`+`SHA256SUMS`（合计 <100 KB），其余 `.img/.bin/.fd` 加 ignore：在 `.gitignore` 末段追加 `reports/artifacts/uefi-dxe*-20261104/*.img`、`*.bin`、`*.gz`、`*.fd`（**逐目录点名**，与既有 `uefi-ddr-20261101/*.img` 风格一致）；**(b) 全量入库**（226 MB，不可逆地撞仓库体量，不推荐） | `git status --porcelain \| grep -c uefi-dxe` = 0；`du -sh .git` 增量 <1 MB |
| M-3 | `HISTORY/days/2026-11-03.md` 落后：首行写「13 条」，实际 11-03 提交 **23** 条，被点名的 `cc6c16f/1e613ee/c716521/9bcf0b6` 全缺 | 跑生成器（**勿手改**，`scripts/gen-history.sh:9` 自述派生物）：`scripts/gen-history.sh && git diff --stat HISTORY/` | 首行变「23 条」；4 个 hash 各命中 1 次；`scripts/gen-history.sh --check` rc=0；`check-doctor` §10 warn 消失 |

### 5.2 建议补

| # | 项 | 动作 |
|---|---|---|
| S-1 | `PROGRESS.md` 公开面缺 11-03（判据纠正 + 下一步裁决）与 11-04（载荷执行 / DXE 卡点）两条里程碑（`grep -n '2026-11-0[34]'` = 0 行，mtime 停在 Nov 2） | 在里程碑表末尾（现有最大日期行 `\| 2026-11-02`）之后追加两行：11-03 =「UEFI 三线核查后裁决 + 载荷可执行性重定位（9 发零写盘）」、11-04 =「载荷首次被执行→Mu PrePi 走完→**DxeCore 未启动（LZMA 段）**」，各带 `reports/` 指针 |
| S-2 | `reports/uefi-posctrl-linux-entry-20261103.md` 在 SSOT 级无独立指针 | 不必单独登记（已被 `uefi-posctrl-20261103-summary.md` 聚合引用，doctor §8 「无孤儿报告」PASS）；若要登记就并进 M-1 的同一行 |
| S-3 | 本轮 `.pi/plans/next/` 三份 lane 交付物未入库 | 按用户习惯决定：入 `.pi/plans/` 或仅作临时件；若要留档建议 `git add .pi/plans/next/` |

### 5.3 无需动作（已核）

| 项 | 理由 |
|---|---|
| 四个门禁脚本 | `check-layout` PASS(46)、`check-progress-counts` 0、`check-project-memory` OK、`check-doctor` **FAIL=0 WARN=5**；5 条 warn 里 4 条是**有意豁免**（历史无 manifest / 理由账 `versions/vk-ledger-known-issues.tsv` / 5 个 UEFI probe 件无内核段 / `boot-elden.img` 无版本号），只有 §10 是真缺口（= M-3） |
| `TASKS/README.md` 的 11-03/11-04 登记 | §5 已含 11-03 决策块、11-03 晚→11-04 块、11-04 两块；G1-29 行已含 11-04 状态；PITFALLS #490–#496 行齐全（`PITFALLS/README.md:195-201`）；RESOURCES §1.6/§2.9 已登记 SunUEFI |
| 已跟踪文件的未提交改动 | `git status --porcelain` 无 ` M` 行，工作区对已跟踪文件是干净的 |
| `.gitignore` 既有规则 | 逐目录点名风格与 `reports/artifacts/uefi-ddr-20261101/*.img` 一致，按 M-2 续写即可，无需重构成通配规则 |

### 5.4 建议执行顺序

1. **M-3**（一条命令、幂等、产生真实修复）→ `scripts/gen-history.sh`
2. **M-2(a)**（`git add` 三件/目录 + `.gitignore` 追加）→ 让 `git status` 回到可读
3. **M-1**（INDEX 口径 + 报告索引两行）
4. **S-1**（PROGRESS 两条里程碑）
5. 1–4 完成后一起提交，并**同时**决定 S-3（`.pi/plans/next/` 是否入库）
6. 全程**不要**手改 `HISTORY/days/*.md`；**不要**为了消 warn 去动 `versions/vk-ledger-known-issues.tsv`

DONE-HYGIENE
