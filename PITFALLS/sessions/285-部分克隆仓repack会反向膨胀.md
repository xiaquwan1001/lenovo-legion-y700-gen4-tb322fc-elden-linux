# 100 — 对 `blob:none` 部分克隆跑 `git repack -a -d` 会反向膨胀并挂死

## #649 对 `blob:none` 部分克隆仓跑 `git repack -a -d`：会按需拉全量 blob（反向膨胀 3 倍），断网/限速时挂死；正解 `GIT_NO_LAZY_FETCH=1`

- **现象**（2026-11-13 实测，`build/m3v2-7.3rc7`，`remote.origin.partialclonefilter = blob:none`）：
  `git repack -a -d` 跑了 **50 min** 被 timeout 砍掉，`.git` 反而从 **1.6 GiB 涨到 5.0 GiB**；
  日志刷 `warning: filtering not recognized by server, ignoring`，`objects/pack/` 里出现
  `tmp_pack_z9VREi`（2.2 GB）与一个新的 278 MB 重复 pack。
- **根因**：repack 需要**全部 blob** 才能重排；部分克隆里缺 blob 会触发 promisor 按需取件，
  而 `git.kernel.org` 不支持 filter ⇒ 客户端把上游全量又拉一遍（该仓原本就有 9 个近似重复的 278 MB pack）。
- **正解**：`GIT_NO_LAZY_FETCH=1 git repack -a -d`（git ≥ 2.46；本机 2.53）只重排本地已有对象，
  **10 s** 完成 2.8 GiB → 572 MB；再 `GIT_NO_LAZY_FETCH=1 git prune --expire=now` → 562 MB。
- **配套纪律**：① 动手前先 `git bundle create <备份> --all` 并 `bundle verify`；
  ② 中断后**先删 `objects/pack/tmp_pack_*`** 再谈别的（不删会白占数 GB）；
  ③ 收口判据 = 该仓各 worktree 的 `git log` 与文件读取仍正常 + `fsck --connectivity-only` 只剩 dangling 无所谓。
- **出处**：`reports/git-slim-exec-20261113.md` §4。
