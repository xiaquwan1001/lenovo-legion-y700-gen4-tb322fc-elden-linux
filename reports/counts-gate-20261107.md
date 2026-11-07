# counts-gate-20261107 — 门禁新增「TASKS §0 手写数字 ↔ 计数脚本」子门（s16）

> 任务 B 交付报告。背景 = PITFALLS #548：§1 状态格多写一个 ✅，`check-progress-counts.sh`
> 算成 35/36 而 §0 手写仍是 34/36，`check-doctor.sh` 全绿无人发现。本报告把漂移比对机械化。

## 0. 结论（数字先行）

- **全量 doctor：FAIL=0 / WARN=4**（与改前基线持平；过程中一度 WARN=5，是并行 lane 的
  `reports/tasks-slim-20261107.md` 暂时成为 ORPHANR 孤儿，随后该 lane 自行引用，回落 4；
  本任务的报告通过 s16 docstring 指针自引用，不产生孤儿 WARN）。
- **fast 档 doctor（--staged-fast）：FAIL=0 / WARN=1**（同样只剩那条并行 lane 孤儿）。
- `check-progress-counts.sh` 口径未动：`G1 完成 34 / 在范围 36`、`G2 完成 8 / 在范围 12`，
  `--selftest` 通过。
- s16 单跑实测 **0.041 s**（要求 <0.3 s）。
- 负向验证：/tmp 副本把 34/36 改 35/36 后，s16 两处手写值（完成度列 + 现状行）**均 FAIL**。

## 1. 改动清单

1. **新增 `scripts/doctor/s16-tasks-counts.py`**（Python3 标准库，无网络无构建）。
   子门输出沿用 s07-08-docs.py 约定：`emit(tag, items)` + MSG 表 + 分节标题
   `== 16. TASKS §0 手写数字 ↔ 计数脚本对账（漂移门，PITFALLS #548）==`；
   支持 `--tsv` / `--root DIR` / `--tasks-file F`（另有环境变量 `ELF_TASKS_FILE`）。
   docstring 内含报告指针（兼作 ORPHANR 自引用）。
2. **`scripts/check-doctor.sh`**：子门清单 `ALL` 与 fast 档 `FAST` 各追加
   `s16-tasks-counts.py`（文件头子门注释表同步登记）。
   `--only s16` / `--only 16` 可单独调（子串匹配已天然支持）。
3. **`.githooks/pre-commit` 未改**：fast 档的编排就是把 `FAST` 列表并发跑，直接把 s16
   放进 `FAST` 即被 pre-commit 继承，无需动钩子（要求的「说明」即此：**不需要硬塞**）。

## 2. 判据与抓取正则

- **真值**：`subprocess.run(['bash', <root>/scripts/check-progress-counts.sh, '--tsv'])`，
  解析 `G1_complete / G1_in_scope / G2_complete / G2_in_scope` 四个键（字符串转 int 比较，
  首版曾因「"34" != 34」恒误报，已修）。**不消费其它键、不改 EMOJI 优先级口径。**
- **被查对象（`--tasks-file` 指定时从该文件抓，默认 `TASKS/README.md`）**，两向都查：
  - ① §0 表格「完成度」列：取首格含 `G1`/`G2` 的 `|` 行，取**最后一个** `(\d+)\s*/\s*(\d+)`
    （`G1` 行末格是 `**34/36**（口径见下表注）`，前面单元格还有别的数字，故取末个）；
  - ② §0 引用行：行首 `>` 且含「现状」，正则 `G1\s*(\d+)\s*/\s*(\d+)`（G2 同理）。
- **失败语义（宁可吵不要静默通过）**：
  - 任一处抓不到 ⇒ tag `MIS` FAIL：「§0 G1 表格…抓不到 N/M（格式变了，勿静默通过）」；
  - 数字不一致 ⇒ tag `G1M`/`G2M` FAIL，消息含双方数字与差值：
    「§0 完成度列 说 G1 35/36，脚本算 34/36（完成数差 +1）；先跑 bash
    scripts/check-progress-counts.sh 核对 §1/§2 行内标记」；
  - 计数脚本本身调用失败/退出码非 0 ⇒ tag `ERR` FAIL。
- §0 边界：`^## 0\.` 到下一个 `^## ` 之间，避免抓到 §1/§2 正文里的其它 N/M。

## 3. 验证输出

### 3.1 正向（全量 + fast + 计数脚本）
```
$ bash scripts/check-doctor.sh --json
== 16. TASKS §0 手写数字 ↔ 计数脚本对账（漂移门，PITFALLS #548）==（其余节从略，均 [ok]/既有 warn）
  [ok]   计数脚本可执行且输出可解析
  [ok]   TASKS §0 两处手写数字均可抓取（完成度列 + 现状行）
  [ok]   §0 手写 G1 数字与脚本现算一致
  [ok]   §0 手写 G2 数字与脚本现算一致
{"fail":0,"warn":4,"profile":"full","sections":["04-retired.sh","05-vk.sh","05e-manifest.sh","05f-abi.sh","06-hygiene.sh","s07-08-docs.py","09-sessions.sh","10-history.sh","11-hooks.sh","12-modular.sh","13-assets.sh","14-layout.sh","s16-tasks-counts.py"]}
$ bash scripts/check-doctor.sh --staged-fast --json
{"fail":0,"warn":1,"profile":"fast","sections":["s07-08-docs.py","09-sessions.sh","10-history.sh","11-hooks.sh","13-assets.sh","14-layout.sh","s16-tasks-counts.py"]}
$ bash scripts/check-progress-counts.sh
G1  完成 34 / 在范围 36（ID 总数 38，取消 2；未完成 2）  [✅31 🟢3 🟡2 ❌2]
G2  完成  8 / 在范围 12（ID 总数 12，取消 0；未完成 4）  [✅6 🟢1 🎯1 🆕1 ⬜1 …]
$ bash scripts/check-progress-counts.sh --selftest && echo selftest_ok
selftest_ok
```

### 3.2 负向（/tmp 副本制造漂移，仓库真文件未动）
```
$ cp TASKS/README.md /tmp/TASKS-drift.md && sed -i 's|34/36|35/36|g' /tmp/TASKS-drift.md
$ python3 scripts/doctor/s16-tasks-counts.py --tasks-file /tmp/TASKS-drift.md
== 16. TASKS §0 手写数字 ↔ 计数脚本对账（漂移门，PITFALLS #548）==
  [ok]   计数脚本可执行且输出可解析
  [ok]   TASKS §0 两处手写数字均可抓取（完成度列 + 现状行）
  [FAIL] §0 与脚本 G1 计数漂移: §0 完成度列 说 G1 35/36，脚本算 34/36（完成数差 +1）；
         先跑 bash scripts/check-progress-counts.sh 核对 §1/§2 行内标记; §0 现状行 说
         G1 35/36，脚本算 34/36（完成数差 +1）；先跑 bash scripts/check-progress-counts.sh
         核对 §1/§2 行内标记
  [ok]   §0 手写 G2 数字与脚本现算一致
```
两处手写值（完成度列 + 现状行）都被抓到并各自 FAIL；仓库内 `TASKS/README.md` 零改动
（`git status --porcelain` 无该文件，见 §4）。

### 3.3 耗时
```
$ time python3 scripts/doctor/s16-tasks-counts.py >/dev/null
real 0m0.041s   （含子进程跑一次 check-progress-counts.sh --tsv）
```

## 4. 未完成项 / 卡点

- 无未完成项。
- 备注：全量 doctor 的 WARN=5 中，`reports/tasks-slim-20261107.md` 孤儿 WARN 属并行
  lane 的产出，不归本任务处置（本任务不得写他人文件）；最终复跑时该 lane 已自引用，
  **全量 WARN 回落 4 = 改前基线**。

## 5. 最终 git status --porcelain

```
 M scripts/check-doctor.sh
?? reports/counts-gate-20261107.md
?? reports/tasks-slim-20261107.md
?? scripts/doctor/s16-tasks-counts.py
```
（`reports/tasks-slim-20261107.md` 为并行 lane 产物，非本任务写入。）

本任务改动的文件（绝对路径）：
- `/home/xuqianhui/y700-elden/scripts/doctor/s16-tasks-counts.py`（新增）
- `/home/xuqianhui/y700-elden/scripts/check-doctor.sh`（接线）
- `/home/xuqianhui/y700-elden/reports/counts-gate-20261107.md`（本报告）
