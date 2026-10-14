# HISTORY — git 提交史（逐提交权威）

> **角度**：本仓库的 git 提交历史。**一个提交 = 一行**，按自然日切分。
> **SSOT 声明**：本目录（`HISTORY/` 的 `README.md` + `days/*.md`）是**逐提交的权威视图**；
> 会话视角（谁在哪个 pi 会话里为什么这么做）见 **`../SESSIONS/`**，两者互补、不互相覆盖。
> 数字口径：以 `git log` 为准，随仓库增长需重跑 `scripts/gen-history.sh` 再生。

---

## 1. 总览

| 指标 | 值 |
|---|---|
| 总提交数 | **445** |
| 覆盖区间 | 2026-09-28 → 2026-10-14（17 个自然日） |
| 生成时 HEAD | `e7dbcdd` |
| 平均每日 | ≈ 26.2 条 |
| 峰值日 | 2026-10-12（74 条） |

> 提交数 = `git rev-list --count HEAD`；本目录 `days/` 条目合计必须与之相等（见 §5 校验）。

---

## 2. 按日期统计

见 `days/YYYY-MM-DD.md`（每天一个文件，正文含该日全部提交）。

| 日期 | 条数 |
|---|---|
| 2026-09-28 | 13 |
| 2026-09-29 | 6 |
| 2026-09-30 | 13 |
| 2026-10-01 | 8 |
| 2026-10-02 | 8 |
| 2026-10-03 | 27 |
| 2026-10-04 | 64 |
| 2026-10-05 | 14 |
| 2026-10-06 | 30 |
| 2026-10-07 | 21 |
| 2026-10-08 | 24 |
| 2026-10-09 | 21 |
| 2026-10-10 | 30 |
| 2026-10-11 | 35 |
| 2026-10-12 | 74 |
| 2026-10-13 | 40 |
| 2026-10-14 | 17 |
| **合计** | **445** |

---

## 3. 按 commit type 统计

口径：取 subject 行**首个 `^[a-z_]+` 前缀**（到第一个非 `[a-z_]` 字符为止），
即 `type` / `type: ...` / `type(scope): ...` 三种写法统一归入 `type`。

| type | 条数 |
|---|---|
| `docs` | 152 |
| `q` | 45 |
| `audio` | 21 |
| `feat` | 15 |
| `chore` | 15 |
| `fix` | 11 |
| `upstream` | 8 |
| `test` | 8 |
| `wifi` | 6 |
| `audit` | 6 |

> 其余 58 个 type 各 1–5 条（多为主题式前缀：`rootfs`/`power`/`haptics`/`flashctl`/`bringup`/`ledger`/`camera`/`vk`/`kexec`/`gpu`/`panel`/`thermal`/`bt`…），
> 完整清单用下方 §4 命令自行展开；类型前缀不等于提交语义分类，只反映作者当时的书写习惯。

---

## 4. 提交信息规范

### 4.1 主题行

采用 `<type>[(<scope>)]: <subject>` 风格，前缀为小写（`^[a-z_]+`）；scope 常用车道/模块名，
如 `q(q28)`、`kexec(kexec)`、`audit(audit)`。

### 4.2 lane trailer（子代理提交溯源）

强制由 **`.githooks/commit-msg`** 执行：仅对匹配 `lane/*` 或 `elden/lane-*` 的**分支**校验，
其余分支（含 `main`、dense history）不检查。必需 trailer：

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
scripts/gen-history.sh          # 重新生成 HISTORY/days/*.md
scripts/gen-history.sh --check  # 对账 days 条目数 == git rev-list --count HEAD
```

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

# 统计每日条数
git log --format=%ad --date=short | sort | uniq -c
```

**对账结果**（生成时）：`days/` 条目合计 = **445**，`git rev-list --count HEAD` = **445** → 一致。

---

## 6. 目录结构

```text
HISTORY/
├── README.md          # 本文件（策展 SSOT：统计表 + 规范 + 查询）
└── days/
    ├── 2026-09-28.md  # 该日全部提交，按时间升序，每行 `- <hash> <subject>`
    ...                # 共 17 个日文件
    └── 2026-10-14.md
```
