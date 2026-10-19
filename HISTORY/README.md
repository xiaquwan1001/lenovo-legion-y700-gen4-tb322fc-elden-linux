# HISTORY — git 提交史（逐提交权威）

> **角度**：本仓库的 git 提交历史。**一个提交 = 一行**，按自然日切分。
> **SSOT 声明**：`days/*.md`（`scripts/gen-history.sh` 机械生成）是**逐提交的权威视图**；
> 会话视角（谁在哪个 pi 会话里为什么这么做）见 **`../SESSIONS/`**，两者互补、不互相覆盖。
>
> **本文件不写死任何计数**（写了必漂：2026-10-19 实测曾是 README「448」vs 实际 493，且 `days/` 缺 10-15～10-19 五天）。
> 一切数字现查：`scripts/gen-history.sh --stats`。逐日真值 = 各日档第 1 行的 `（N 条）`。

---

## 1. 总览（现查）

```bash
scripts/gen-history.sh --stats
```

一条命令输出：总提交数 / 当前 HEAD / 覆盖区间 / 平均每日 / 峰值日 / 逐日表 / type top10 / type 种数。

单独两项：

```bash
git rev-list --count HEAD    # HEAD 祖先的提交数
git rev-parse --short HEAD   # 当前 HEAD
```

> ⚠ **统计范围 = HEAD + 已回填的历史分支**：`2026-09-28`～`10-02` 那 5 个日档记录的是
> `history/pre-vk34` 的提交，它们**不是 HEAD 的祖先**（历史回填资产，见
> `archive/2026-10-04-git-backfill/VERSION-MAP.txt`）。脚本同时遍历 `history/*`，
> 所以 `days/` 合计会大于 `git rev-list --count HEAD` —— 这是**正确**的，不是漂移。

---

## 2. 按日期统计

**唯一真值 = `days/` 目录本身**（每个自然日一个文件，文件第 1 行写当日条数）。

```bash
ls HISTORY/days                       # 有哪些天
head -1 HISTORY/days/*.md             # 每天多少条
```

汇总表用 `scripts/gen-history.sh --stats` 现出，本文件不再抄。

---

## 3. 按 commit type 统计

口径：取 subject 行**首个 `^[a-z_]+` 前缀**（到第一个非 `[a-z_]` 字符为止），
即 `type` / `type: ...` / `type(scope): ...` 三种写法统一归入 `type`。

分布现查（top10 + 种数）：`scripts/gen-history.sh --stats`。

> 类型前缀不等于提交语义分类，只反映作者当时的书写习惯；大量前缀是主题式
> （`rootfs`/`power`/`haptics`/`flashctl`/`bringup`/`ledger`/`camera`/`vk`/`kexec`/`gpu`/`panel`/`thermal`/`bt`…）。

---

## 4. 提交信息规范

### 4.1 主题行

采用 `<type>[(<scope>)]: <subject>` 风格，前缀为小写（`^[a-z_]+`）；scope 常用车道/模块名，
如 `q(q28)`、`kexec(kexec)`、`audit(audit)`。

### 4.2 lane trailer（子代理提交溯源）

强制由 **`.githooks/commit-msg`** 执行（**需 `core.hooksPath=.githooks` 才生效**，见 §5）：仅对匹配
`lane/*` 或 `elden/lane-*` 的**分支**校验，其余分支（含 `main`、dense history）不检查。必需 trailer：

| trailer | 含义 | 示例 |
|---|---|---|
| `Lane:` | 与分支名对应的 lane id（须**逐字相等**，否则拒绝） | `Lane: q28` |
| `Agent:` | 角色名（`.pi/agents/<role>.md` 或 `parent`） | `Agent: camera` |
| `Baseline:` | lane fork 出的基线 tag | `Baseline: base/20261005-99d49aa` |
| `Task:` | 任务 id（`Task:` 或 `VK:` 二者其一即可） | `Task: G1-5` |

示例消息体：

```text
<type>(<lane>): <subject>

Body...

Lane: q28
Agent: camera
Baseline: base/20261005-99d49aa
Task: G1-5
VK: vk51
```

绕过（罕见，如纯工具提交）：`LANE_HOOK_SKIP=1` 或消息内含 `[skip-lane]`。
细节见 `.pi/CONCURRENCY.md`。

---

## 5. 生成与校验

**生成（机械，勿手抄）**：

```bash
scripts/gen-history.sh          # 重新生成 HISTORY/days/*.md（幂等）
scripts/gen-history.sh --check  # 对账 days 合计 == git rev-list HEAD + history/*
scripts/gen-history.sh --stats  # 现查全部统计（本 README 不写死数字）
```

**重跑是幂等的**：日档内容只由 `git log` 决定 ⇒ 未变化的日档**逐字节相同**，`git diff` 只出现在
真正有变化的日期（通常是最后一天 + 新增日文件）。所以「全量重写 `days/*.md`」**不是反复删改**，可以放心重跑。

三个会让重跑产生额外 diff 的例外（都属真变化或一次性 churn）：

| 例外 | 触发 | 处置 |
|---|---|---|
| E1 hash 缩写变长 | git 对象增多后 `%h` 从 7 位变 8 位 ⇒ 所有日档每行同时变 | 脚本已钉 `core.abbrev=10`，**永不再变**（2026-10-19 已做一次性迁移） |
| E2 提交被改写 | `rebase`/`amend`/`filter-repo` | 属真变化；相关日档 hash/条数全变 |
| E3 时区不同 | 换机器/换 TZ 重跑，跨午夜提交换日 | 脚本**不改 TZ**（用 git 默认）；换环境前先看 `--stats` 的覆盖区间是否变 |

> `--check` 的判据**天生「只在刚生成时为真」**：任何新提交都会让 HEAD +1 而 `days/` 不变。
> 它是**收尾时的重生成提示**，不能当 pre-commit 门（`check-doctor` §10 只 WARN 不 FAIL）。

**查询示例**：

```bash
# 全部提交（时间升序）
git log --format=%ad'|'%h'|'%s --date=short | tac

# 按天
git log --since=2026-10-12 --until=2026-10-12 --format='- %h %s'

# 只看 type
git log --format=%s | grep -E '^docs'

# 看某条提交的 lane trailer
git log -1 --format=%B <hash>
```

---

## 6. 目录结构

```text
HISTORY/
├── README.md          # 本文件（规范 + 查询入口；统计一律现查）
└── days/
    ├── YYYY-MM-DD.md  # 该日全部提交，按时间升序，每行 `- <10 位 hash> <subject>`
    ...                # 每天一个文件，个数以 ls 为准
    └── ...
```
