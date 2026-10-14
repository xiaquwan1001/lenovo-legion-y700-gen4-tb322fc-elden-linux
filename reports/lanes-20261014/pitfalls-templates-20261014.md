# Lane 报告：PITFALLS 悬空编号 + 死脚本退役 + sessions README 去样板

日期：2026-10-14 ｜ 边界：PITFALLS/**、三份 sessions/README.md、scripts→archive 移入 ｜ 工作目录 /home/xuqianhui1001/y700-elden

## 结论
三项全部落地，改动均在独占边界内；未触碰 INDEX.md / TASKS/README.md / .pi/AGENT-OPS.md / SESSIONS/ / .githooks / versions/。

## A. 补登记悬空条目 #262 ✅
- 核对：`PITFALLS/README.md:6` 原声明 `#1–#261`；`TASKS/sessions/2026-10-14-m1-73-mainlining.md:14/165` 引用 `PITFALLS #262`（悬空）。
- 改动：在 #259–#261 所在 `PITFALLS/sessions/33-盯“精确UTS单变量打包”的三连坑.md` 末尾（现 36→41 行）补 `262.` 一条，格式照抄同文件 `N. **标题**` + 缩进 `- ` 要点；内容 = 跨时段比较显示结果必须同时报告坏发簇状态、同镜像隔数小时复跑为识别簇的最低成本手段，证据指 `TASKS/sessions/2026-10-14-m1-73-mainlining.md`。
- `PITFALLS/README.md:6` 抬头改为 `**条目编号 #1–#262**`。
- 验证：`grep -n '条目编号' PITFALLS/README.md` → `#1–#262`；`tail -8` 见 #262 完整条目。

## B. 退役死脚本 ✅
- 核实：`grep -rln 'q28-cold-sample-loop' .`（排除 .git）→ 命中仅 `scripts/q28-cold-sample-loop.sh` 本体、`.pi/lanes/audit-stale-20261014.md`（审计报告）与 `.pi/sessions/*.jsonl`；无任何活跃文档/脚本引用，与 C2 审计（`.pi/lanes/audit-stale-20261014.md:125` DEAD）一致。
- 改动：`git mv scripts/q28-cold-sample-loop.sh archive/2026-10-14-retired-scripts/`（新建该归档目录，沿用 `archive/2026-10-13-*` 命名）。git status 显示 `R`（重命名保留历史）。
- 登记：`PITFALLS/sessions/15-过时废弃功能缺陷登记.md` §15.2 表新增一行（第 38 行），格式照抄同节 `| 来源 | 处置 | 日期 |`，含退役理由与承接口径。
- 验证：`ls scripts/q28-cold-sample-loop.sh` → No such file；归档目录内文件在。

## C. 三份 sessions/README.md 去样板 ✅
- 复述点：三份第 3–8 行近逐字重复「命名规则 / 文件头字段 / 会话身份与检索」，与 `INDEX.md` §2 + `.pi/AGENT-OPS.md` §4 重复。
- 改动：删去命名行、文件头字段行、会话身份行，收敛为一行指针；保留各角度目录特有的范围说明（`本目录只放跨会话新增…`）。
  - 改后（三份一致，仅标题不同）：
    - `- 本目录只放**跨会话新增**（跨会话进度面）；稳定结论由宿主并入上级 README.md。`
    - `- 命名 / 文件头字段 / 会话身份与检索标准见 INDEX.md §2 与 .pi/AGENT-OPS.md §4（本处不复述）。`
- 验证：`cat` 三份确认。

## 备注
- 工作树中另有他人改动（INDEX.md、TASKS/README.md、.pi/AGENT-OPS.md、SESSIONS/、scripts/gen-sessions.py、scripts/vk-identity.py 等）非本 lane 所为，未触碰。
