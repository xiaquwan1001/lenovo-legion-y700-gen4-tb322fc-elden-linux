# 2026-11-05 三个 lane 的任务卡（原 `.pi/tmp-tasks/`，2026-11-26 整理轮 B5 归档）

> 为什么在这里：三篇是 2026-11-05 一次整理轮派给三个 lane 的任务书，**各自轮次早已收口**，
> 在仓库里 0 引用（`grep -rn tmp-tasks --include='*.md'` 只剩审计与本文件自身）。
> 正文**逐字保留**（未改一字），只加分段标题；对应产物见各篇开头的「语境/产出」段与
> `reports/integrity-audit-20261105.tsv`、`versions/out-artifacts.tsv`、`TASKS/README.md` 的拆分沿革。

---

## 原 `.pi/tmp-tasks/integrity.md`

# lane V：全仓数据完整性校验（带重试定性）

## 语境
项目根 /home/xuqianhui/y700-elden，HEAD 干净（开工前确认）。本机 2026-11-05 已发生 3 起静默数据损坏
（out/boot-elden-m3v5-daily.img、build/b5-v2 文件名位翻转+基对象不可读、.git pack 校验和不符）；
用户已把 BIOS 改回保守设置并另派稳定性测试 agent。**本轮要求：凡校验一律「失败重试一次」再定性**，
把「瞬时读错」与「真损坏」分开记录。

## 硬约束
- **只读**：不得修改/删除/移动任何既有文件；不 git commit；不上机；不发邮件。
- 只允许**新建**自己的交付文件。
- 每条结论带可复现命令；未证写「未证」。中文输出。时间盒 ≤40 分钟，超时就落盘并如实报未完成范围。

## 校验矩阵（每项都跑，结果进表）
1. **git 仓库**：项目根 `.`、`geekidos-linux`、`build/m3v2-7.3rc7`、`build/base-7.2`、`build/daily`（若是 worktree 会共享 .git，注明即可）。
   每仓跑：`git fsck --full --no-dangling`、`git count-objects -v`、`git verify-pack -v .git/objects/pack/*.idx | tail -2`、`git rev-parse HEAD`。
   **失败重试**：同一命令重跑一次；仍失败才判红。注意 build/* 多为浅克隆（.git/shallow），缺父提交属预期，别当损坏。
2. **产物镜像**：`out/*.img`（129 件 / 9.43 G）逐个 sha256sum，与对应 `out/*.manifest` 记录的镜像 sha 比对（先看一个 manifest 的字段名）；
   无 manifest 的单列「无基线」。**不一致时**：再算一次 sha256 并比对两次结果——两次不同 = 读取不稳定；仍不一致 = 疑似真损坏（再用 `dd iflag=direct` 抽读同区域做第三次对照）。
3. **备份/封存件**：`backup/build-bundles/*.tar.zst`（`zstd -t`）、`backup/git-repair-20261105/*.zst`、全部 `backup/**/SHA256SUMS`
   （`sha256sum -c`，只跑存在对应文件的条目；缺失单列）、`reports/artifacts/**/SHA256SUMS`。
4. **文本层稳定性**：`git ls-files -z patches versions scripts | xargs -0 sha256sum > /tmp/t1` 跑两遍比对；
   另检查是否有 0 字节文件、`.patch` 里不含 `diff --git` 的异常件。
5. **不可及**：在机 boot_b / GPT 等设备侧本轮不校验（如实标注）。

## 交付
- `/home/xuqianhui/y700-elden/reports/integrity-audit-20261105.md`：§0 一句话结论（几红几黄）+ §1 汇总表（项/件数/失败数/重试后恢复数/真损坏数）+ §2 逐条异常（路径、期望 vs 实测、重试结果、定性）+ §3 未覆盖范围 + §4 复核命令。
- 机器账 `/home/xuqianhui/y700-elden/reports/integrity-audit-20261105.tsv`（列：scope\tpath\texpected\tactual\tretry_result\tverdict）。

回执 ≤25 行：交付路径 + 关键数字（红/黄/恢复数）+ 复核命令。

---

## 原 `.pi/tmp-tasks/outarchive.md`

# lane O：`out/` 历史镜像归档 + vk 账目同批改造（**只备料，不执行**）

## 语境
项目根 /home/xuqianhui/y700-elden。用户已批准本轮把 `out/` 历史镜像（129 个 `*.img` / 9.43 G）做归档瘦身，
但**必须与 `versions/vk-kernel-identity.tsv`（下称 ledger）同批处理**，否则 `check-doctor §5d` 会把「文件消失」判成
身份不可核对。历史上还有一条硬纪律：**禁止重跑 `scripts/vk-identity.py`**（镜像缺失会清空/污染整表，见 `.pi/memory/MEMORY.md` 2026-10-17 条）。

## 你的角色 = 备料 + dry-run，**不执行任何 mv/rm/写 ledger**
父进程会照你的清单执行。所以你要交付的是「可粘贴的命令 + 预期 diff + 回滚 + 判据」。

## 必做（按顺序）
1. **读懂账目与门禁的耦合**：
   - `head -3 versions/vk-kernel-identity.tsv`（列名）、随机抽 3 行看 path 写法（是 `out/xxx.img` 还是裸名）。
   - `rg -n "vk-kernel-identity|5d|5e" scripts/check-doctor.sh | head -30`，读那段：它如何定位镜像文件、缺文件是 FAIL 还是 WARN、是否比对 `sha256`、`kernel-unreadable` 标记怎么处理。
   - `versions/vk-ledger-known-issues.tsv` 里对 `uts_dup*/num_ne_tag` 的豁免机制（别踩）。
   - `out/*.manifest` 与镜像的关系：manifest 里 `image=` 是绝对路径、`image_sha256=` 是身份；`scripts/build-manifest.sh` 如何生成。
2. **定「保留集」并给判据**（每条给命令+输出）：
   - 在机对应的镜像：`DEVICE/README.md` §1.1 首条的 `boot_b` sha（vk172 线）与 `out/` 里哪个文件逐字节一致（用 manifest 的 `image_sha256` 或直接 sha256）。
   - 当前两条在用线：`m3v5-onboard` 系（含 `-b`）、`vk172`/`vk183-fastrpc` 等最新线、`reports/upstream-*` 最近条目引用的件。
   - 取证类必须留：`out/corrupt-20261102/`、`boot-elden-m3v5-daily.img`（11-03 静默损坏件，已修复但保留）、UEFI 本轮 `uefi-2026110*.img`（若 TASKS §5 11-04 块引用）。
   - 被 **reports/TASKS/DEVICE 里的「当前时态」句**引用的件（历史叙事引用不算）。
3. **给归档方案**：目标目录 `backup/out-history-20261106/`（同盘 mv，不压缩；另附「是否值得 tar.zst」评估与体积预估）。
   注意：`backup/` 是 never-delete 区、且被 `.gitignore` 忽略 ⇒ 移过去不影响 git。
4. **给 ledger 改造 patch（逐行）**：移动的每一件在 ledger 里怎么改（改 path 列 → `backup/out-history-20261106/<name>`，还是保持 `out/<name>` 并把「已归档」记在 known-issues？）。
   **选一种口径并说明为什么**，给出需要改动的行号清单 + 一个可直接 `python3 - <<'PY'` 的改写脚本（幂等、带 dry-run 开关、改前备份 ledger 到 `backup/`）。
5. **dry-run 证据**：把上面脚本以 `--dry-run` 跑一遍（不写盘），贴输出摘要（将改 N 行 / 将移动 M 件 / 释放 X 字节）。
6. **判据与回滚**：执行后必须满足
   - `bash scripts/check-doctor.sh 2>&1 | tail -1` → **FAIL=0**，且 §5d/§5e 的 WARN 数量不增加；
   - `awk -F'\t' 'NR>3{print $1"  out/"$3}' versions/out-images-sha256-20261105.tsv | sha256sum -c --quiet`（基线表要能继续校验——若路径变了，说明基线表也要同批改，给出改法）；
   - `git status` 只应有「ledger + 基线表 + 必要的 docs 指针」三类改动；
   - 回滚 = 记录 mv 的反向命令 + ledger 备份文件路径。

## 硬约束
- **不执行** mv/rm、不写 ledger、不改仓库任何既有文件、不 git commit、不上机。
- 只允许新建：`reports/out-archive-plan-20261106.md`（或 20261105-2）+ 一个 `scripts/` 之外的临时脚本放 `/tmp`。
- 每条结论带可复现命令；未证写「未证」。中文。时间盒 ≤35 分钟。

## 交付
`/home/xuqianhui/y700-elden/reports/out-archive-plan-20261105.md`：
§0 一句话结论（保留 N 件 / 归档 M 件 / 释放 X G / ledger 改 K 行 / 门禁风险）
§1 账目-门禁耦合事实（带 file:line）
§2 保留集（逐件 + 理由 + 引用来源）
§3 归档清单（逐件 + 体积 + ledger 行号）
§4 可粘贴执行序列（mv 命令 + ledger 改写脚本 + dry-run 输出）
§5 判据与回滚
§6 未证/待裁决
回执 ≤25 行。

---

## 原 `.pi/tmp-tasks/ssot3.md`

# lane S3：SSOT 并入第二轮（TASKS 剩余 79 条 + 其它角度残留）

## 语境
项目根 /home/xuqianhui/y700-elden。第一轮已关闭 TASKS 61 条 + DEVICE/RESOURCES/PITFALLS 18 文件。
本轮处理剩余：`rg -l '★SSOT 待并入' TASKS/sessions DEVICE/sessions RESOURCES/sessions PITFALLS/sessions`
里**尚未变成「无（…，2026-11-05）」**的那些（上一轮实测 TASKS 剩 79 条：散文式目标 42 / 空标记「正文在下方」21 / 显式 PENDING 12 / 已并入带残留注记 4）。

## 硬约束
- 只改 `TASKS/README.md`、`DEVICE/README.md`、`RESOURCES/README.md`、`PITFALLS/README.md` 与上述 `sessions/*.md`；其它文件不动（不碰 INDEX/AGENTS/reports/archive/scripts/versions）。
- **edit 定点替换，禁整文件 write**；每批 ≤20 条落盘一次。
- 不动 2026-11-05 父进程新写的行：`TASKS §7` 头部四条（投递批次沿革 / 当前一页 / 未答项 / 归档复核口径）、`RESOURCES §3` 可清理标记表的 A8/B1–B4/H1。
- 分类处置规则：
  * **散文式目标/标题块** ⇒ 标「无（非结论型条目）」，不往 README 塞。
  * **空标记 /「正文在下方」** ⇒ 读该文件正文取一句结论并入对应节；若正文本身是过程叙事 ⇒ 标「无（过程叙事留 sessions/）」。
  * **显式 PENDING（未并入/待父会话/待批）** ⇒ **原样保留不动**，回执列名。
  * **已并入但带残留注记** ⇒ 保留注记内容，只把标记改成标准式。
- 不改状态词/编号/日期/数字口径；不新增任务 ID；表格不得拆行；每条并入 ≤2 行、每格 ≤600 字符；不写死计数。
- 不 git commit（父进程统一提交）。

## 交付
- `/home/xuqianhui/y700-elden/reports/ssot-merge-20261105-round2.md`（并入条数 by 角度 / 关闭标记数 / 保留 PENDING 清单 / 未处理残留 / 新增超长行=0 / check-doctor 结果）。
- 回执 ≤25 行。

---
