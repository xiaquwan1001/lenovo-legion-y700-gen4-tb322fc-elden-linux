# git 树整理执行账 — 2026-11-13（第二轮）

> 执行 `reports/git-tree-audit-20261113.md`（只读审计）里的「可立即执行」部分，**不改写历史**、**不删工作区文件**。
> 前提铁律全部遵守：`build/*` 与嵌套仓动手前先 `git bundle`（3 份已 `bundle verify` 通过）。

## §0 结论数字

| 对象 | 整理前 | 整理后 | 回收 |
|---|---|---|---|
| 主仓 `.git` | 526 MB | **322 MB** | 204 MB |
| `geekidos-linux/.git`（= `linux/` 实体） | 1.9 GiB | **306 MB** | ≈1.6 GiB |
| `build/m3v2-7.3rc7/.git` | 1.6 GiB（13 packs，大量重复） | **562 MB**（2 packs） | ≈1.0 GiB |
| 主仓被跟踪体积 | 932 MiB | **≈108 MiB** | 824 MiB（不再入新提交） |
| **合计磁盘回收** | | | **≈2.9 GiB**（另有 824 MiB 停止扩张） |

所有 bundle 在 `backup/git-slim-20261113/`（`/backup/*` 已被 `.gitignore:63` 忽略，不入库）：
`main-all-20261113.bundle`（515 MB / 74 refs，含 `refs/original/refs/heads/main`）、
`geekidos-all-20261113.bundle`（301 MB / 139 refs / 70 tags）、`m3v2-all-20261113.bundle`（394 MB）。
三份均 `git bundle verify` = 「这个捆绑包记录一个完整历史」。

## §1 主仓：删 filter-branch 残留 + gc

```bash
git bundle create backup/git-slim-20261113/main-all-20261113.bundle --all refs/original/refs/heads/main
git bundle verify backup/git-slim-20261113/main-all-20261113.bundle   # 完整历史
git for-each-ref --format='%(refname)' refs/original | xargs -r -n1 git update-ref -d
git tag -d attic/lane-upstream-20261012 attic/tablet-night-20261031   # USTC 远端仍有同名 tag（ls-remote 现查）
git reflog expire --expire-unreachable=now --all && git gc --prune=now
```

- 回收来源 = 审计查明的 22 个不在 HEAD 的 blob（194 MB），原本被 `refs/original/*` + `attic/*` tag 双重钉住。
- **可逆性**：内容在 bundle + `backup/git-history-rewrite-20261112/pre-rewrite-main-2.bundle`；
  `attic/*` tag 在 USTC 远端仍存在（`git fetch --tags` 可复原）。
- 门禁：`git fsck` 干净、`git log` 正常、工作区改动未受影响。

## §2 reports/artifacts：大件不入库（主仓最大的单向膨胀源）

- 实测：`reports/artifacts/` 被跟踪 798 MiB / 2083 件，其中 **277 件 >1 MiB 合计 823.9 MiB**，
  种类全是 `*.fd`(45) `*.img`(83) `*.bin`(90) `*.gz`(31) `*.log`(28) —— 即 UEFI 试验目录里逐份重复的
  4 MiB `SM8750_EFI.fd` + `bootpayload.bin` + 5 MiB `build.log`。
- 处置：`.gitignore` 末尾加 5 条块规则 + `git rm --cached`（**文件仍在磁盘原位，路径引用照常可用**）。
  结果：`reports/artifacts` 被跟踪 798 MiB → **48.7 MiB**（剩 SHA256SUMS / md / 小件截图）。
- 可核验性：每目录 `SHA256SUMS` 仍入库；历史版本 `git show <old-commit>:<path>` 可取回；
  规则与恢复条件写在 `reports/artifacts/README.md`（唯一正文）。

## §3 geekidos-linux（浅克隆）：repack 后回收 1.6 GiB

原因 = 审计实测「可达对象只占 13.4%」：8 个 pack 里 5 个是 265–287 MB 的**重复上游 pack**。

```bash
cd geekidos-linux && git bundle create ../backup/git-slim-20261113/geekidos-all-20261113.bundle --all
git repack -a -d -q      # 9.3 s，1.9 GiB -> 307 MB
git prune --expire=now
```

- 结果：refs 139（16 heads + 53 remote-tracking + 70 tags）全部保留、`fsck` 干净、HEAD 树可读。
- 被 prune 的是**不可达的重复上游历史**（38858 unreachable commits / 189445 trees），可由上游重取；
  本地独有内容全在 139 条 ref 内 ⇒ 已进 bundle。

## §4 build/m3v2-7.3rc7：**踩到一个坑，已收口**（必须记住）

- 第一次 `git repack -a -d` **跑了 50 min 被 timeout 砍掉**，`.git` 反而从 1.6 GiB 涨到 5.0 GiB：
  该仓是 **`partialclonefilter = blob:none`**，repack 需要全部 blob ⇒ 触发了按需取件
  （日志刷 `warning: filtering not recognized by server, ignoring`），把上游全量又拉了一遍。
- 正解 = **`GIT_NO_LAZY_FETCH=1 git repack -a -d`**（git 2.53 支持）：只重排本地已有对象，**10 s** 完成，
  2.8 GiB（含被拉进来的重复 pack）→ 572 MB；再 `GIT_NO_LAZY_FETCH=1 git prune --expire=now` → **562 MB**。
- 收口验证：3 个 worktree（本体 / `build/daily` / `wt/reb-731`）`git log` 与文件读取均正常；
  `build/daily` 的 19 个未提交改动原样保留。
- **新坑（写进 PITFALLS）**：对 `blob:none` 部分克隆跑 `repack -a -d` 会反向膨胀并在断网时挂死。

## §5 未做（有意留着，需用户或需设备）

1. `build/daily`(13 GiB) 与 `wt/reb-731`(12 GiB) 的**构建中间产物**（`.o`/`.cmd`/`*.mod`）≈20–23 GiB：
   今晚要上机，删了就得重编 ⇒ 留到上机轮之后再做。
2. `build/uefi-woa-prep` 8.2 GiB（EDK2 树，可重取）、`out/` 5.8 GiB 镜像：走 `scripts/out-archive.py`，不手删。
3. `reports/` 里 176 篇「只在 sessions 被引用」的 10 月报告（1.6 MB）：搬走会断 142 处历史指针，
   收益 <0.02% ⇒ **不动**（审计建议的 `git mv` 我按成本判断后否掉，理由记录在此）。
4. `backup/` 31 GiB 与 `dl-cam/`/`reference/` 的 untracked 大件：不入 git，属备份面，另轮处理。
