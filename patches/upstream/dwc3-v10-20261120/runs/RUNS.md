# dwc3 v10 门禁实跑记录 — 2026-11-20 20:2x（单 lane）

树：`build/elden-tree`，base = `v7.4-rc3` = `aebb7274476403040d582c61478df8f4a7bf9cd3`。
前置：`git fetch --deepen=50 origin`（HTTPS 经代理；rc=0，历史 1 → 7920 commit，`.git/shallow` 仍在）
⇒ `--3way` 可用。装配后的分支 = `v10-gate-20261120`（3 枚 am 提交），树已还原为 detached base。

| 门 | 命令 | 结果 | 日志 |
|---|---|---|---|
| G1 apply | `git am --3way v10-000[123]-*.patch`（套 `flock /tmp/pi-heavy-build.lock`） | **rc=0，3/3 干净，无 offset/fuzz** | `G1-am.log` |
| G2 checkpatch | `perl build/elden-tree/scripts/checkpatch.pl --strict --no-signoff --no-tree *.patch`（在 `mktemp -d` 空目录里跑，避开仓库内 `*.patch` 被当源码扫） | **红**：1/3 `0E/0W/0C`（115 行）· 2/3 `0E/0W/0C`（63 行）· 3/3 **`0E/1W/0C`**（618 行）⇒ rc=1 | `G2-checkpatch.log` |
| G3–G6 | 未跑 | 门链停在 G2 红门（按派单口径：红了就停，不改补丁内容凑绿） | — |

## G2 唯一的 WARNING（阻塞项）

```
WARNING: Prefer a maximum 75 chars per line (possible unwrapped commit description?)
#37:
can end up driving the data lines of the connector that is not in use, and a
```

- 位置：`v10-0003-*.patch` 第 37 行 = 3/3 **commit message** 第 4 行，长度 **78 字符**（>75）。
- 来源：`v10-0003-commit-msg.txt` 的该行原文（作者已审的 message 文本），不是代码、不是 diff。
- 修法（留给下一轮 / 作者裁决，本轮**按派单不动**）：在 `v10-0003-commit-msg.txt` 把该句折到 ≤75 字符，
  重生成 3/3 patch，然后 **从 G2 起重跑** G2→G6。

## 本轮装配动作（同目录两个新 patch 文件的来历）

`v10-0002`/`v10-0003` 在 `patches/upstream/dwc3-v10-20261120/` 原本不存在（只有 0001 与 `v10-0003-commit-msg.txt`），
故按目录内既有口径装配：

- `v10-0002-*.patch` = `../dwc3-v10-20261118/v10-0002-*.patch` 逐字节 + 插入 AI 披露段（与 1/3、3/3 同格式，插在 `Signed-off-by` 前）。
- `v10-0003-*.patch` = 1118 版 0003 的邮件头（From/From/Date/Subject）+ `v10-0003-commit-msg.txt`（去 `#` 注释行）作 commit message + 1118 版 diff 尾（`---` / diffstat / diff 原样，代码未动）。
- 自查：`grep -c 'Two connectors can share one High Speed' v10-0003-*.patch` = **1**（装配首版曾因切片取到 `Signed-off-by` 而把旧 message 一并带上，已修）。
