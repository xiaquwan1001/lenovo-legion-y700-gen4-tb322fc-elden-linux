# 并发任务基线+fork 工作流（约束）

> 2026-10-05 定。取代旧「子 agent 一律不 commit」的口径（旧规划会话 `01a104a2`）。
> 目标：子代理提交可区分、并发各走独立分支、版本号不再撞车、冲突由父 agent 收口。
> 相关：`scripts/lane.sh`、`.githooks/commit-msg`、`versions/vk-registry.tsv`；分层见 `INDEX.md` §2。

## 1. 模型（single integrator + forked lanes）

```
main ──base/<date>-<sha>──┬── lane/c3-id    (worktree) ── commits ──┐
                          ├── lane/c7-slot  (worktree) ── commits ──┤  父 agent
                          └── lane/upstream (worktree) ── commits ──┘  merge --no-ff
                                   ▲ 每个 lane 自带内核 worktree（按需）
```

- **父 agent = 唯一 integrator**：只有父写 `main`、改领域层 SSOT 文档、跑 `check-doctor`、打 `merge/*` 标签。
- **子 agent = lane 所有者**：在自己的 `git worktree` + 分支上推进并**提交**；不碰 `main`、不改 `TASKS/DEVICE/INDEX/RESOURCES/PITFALLS`。
- **baseline**：父在开工前给 `main` 打不可变标签 `base/<date>-<sha>`；lane 一律从该标签 fork。
- **fork**：`scripts/lane.sh new <lane> <baseline> [--kernel]` 建 worktree+分支+元数据。
- **merge**：子 agent `lane.sh done` → 父 `lane.sh merge <lane>`（`--no-ff`，父解冲突）→ `check-doctor` → `tag merge/<lane>`。

## 2. 不可变式（违反即回退）

1. **单写者**：任何时刻一个文件只有一个写者。领域层 5 份文档 + `.githooks` + `versions/` = 父专属。
2. **文件归属不重叠**：lane 只写自己的路径（见 §5）；跨路径需求 → 回父 agent 协调，不得私自扩权。
3. **不 rebase / 不 merge main 进 lane**：lane 只从 baseline 前进；需要上游新基线时由父决定是否重开 lane。
4. **内核改动必走 worktree**：`geekidos-linux`（13 G）绝不在主 checkout 上多 agent 同时改。
5. **设备是单一串行资源**：所有上机/刷写/复现任务用 `scripts/device-lock.sh` 串行，任何时刻只有一个 lane 持设备。
6. **并发上限 ≤3 个后台子 agent**，为限流/预算留余量（`~/.pi/agent/AGENTS.md`）。

## 3. 提交信息（子代理可区分）

lane 分支上的每条提交**必须**带 trailer 块，`.githooks/commit-msg` 强制校验：

```
camera: 前摄出流打通（vk52）

<正文>

Lane: camera
Agent: camera            # .pi/agents/<role>.md，或 parent
Baseline: base/20261005-99d49aa
Task: G1-5               # TASKS 编号
VK: vk52                 # lane.sh alloc 产出，可多个
```

- 校验命令：`git log --format='%(trailers:key=Lane,valueonly)'`。
- 绕过（仅工具类）：`LANE_HOOK_SKIP=1` 或消息含 `[skip-lane]`。
- 非 lane 分支（`main`）不校验，历史提交无需回填。

## 4. 版本号分配（修「版本号划分不清」）

**唯一真相 = `versions/vk-registry.tsv`**（入库、父提交）。分配走 `scripts/lane.sh alloc`：对 registry 文件 `flock` 后取 `max(vk)+1` 追加一行，返回 `vkN`。

- 不再扫 `out/boot-elden-vk*.img` 猜号（并发必撞）。`scripts/iterate.sh` 的无参 `VERSION` 改调 `lane.sh alloc`。
- registry 由父在 merge 时一并提交；lane 自己**不提交** registry（避免分叉）。
- 命名沿用 `vk<N>`；一次性实验变体加后缀（`vk52-ram`、`vk52a`），后缀不进 registry。

## 5. 当前可并发的 lane 规划（2026-10-05）

| lane | 任务 | 路径归属（只写这些） | 设备 | 执行者 |
|---|---|---|---|---|
| `c3-id` | C3 身份/DRM 取证 + 社区对照 | `archive/topics/c3-*.md`、`.pi/drafts/` | 无 | gplay |
| `c7-slot` | C7 slot 切换脚本 + A16 `new-tablet` 参数化 | `scripts/`（新文件为主） | 无 | general |
| `upstream` | M1–M5 上游化补丁整理 | `patches/` | 无 | general |
| （设备 lane） | G1-22 二分 / BT H1·H2 / G1-8 基准 / C1 Waydroid | 内核 worktree + `scripts/` | **U2 串行** | 父协调 |

**设备 lane 天然不并发**：同一时刻只放行一件（`device-lock.sh` + 父排程）；需要改内核时同样 `lane.sh new <lane> <base> --kernel` 开 worktree，但持设备者唯一。
**U1（stock Android）未接**：C0/C3-Android/C7 验证在 U1 接入后可成为与 U2 并行的第二条设备线。

## 6. 冲突收口（父 agent）

1. 父在 `main` 上 `git merge --no-ff lane/<x>`；冲突优先保留 lane 语义、由父统一改写文档引用。
2. 领域层文档的并发改动一律不发生在 lane 内 → 冲突面收敛到 `scripts/`、`patches/`、`archive/` 三个不相交目录。
3. merge 后必跑 `scripts/check-doctor.sh`（FAIL=0）、更新 `TASKS.md`、`git tag merge/<lane>`。
4. 内核 lane：父在 `geekidos-linux` 内单独 merge，并把净 diff 回导 `patches/` 后提交主库（内核树不入主库 git）。
