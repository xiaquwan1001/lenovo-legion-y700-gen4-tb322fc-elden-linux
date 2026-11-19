# #688 本仓远端默认分支是 `main`：`git push <remote> HEAD:master` 会**静默新建**一条 master，而不是报错

## 现场（2026-11-19，提交 `f972a181` / `35d6e232`）

收尾按「双发布」惯例推两个 remote，写的是 `git push $r HEAD:master`。两条都返回 **rc=0**，
输出里只有一行容易被当成「推成功」的 `* [new branch]  HEAD -> master`——
实际是**在远端新建了 `refs/heads/master`**（内容 = 本地 HEAD），而真正的默认分支 `main`
**没有动**，仍停在旧提交 `64b24dd4`。之后 `git rev-parse origin/master` 为空（本地没有该跟踪分支），
才露出破绽。

## 判据与处置

- 推送前先确认分支名：`git branch --show-current`（本仓 = `main`）+ `git ls-remote --heads <remote>`。
- 推送后**必须**核 sha，而不是看 rc/看 `[new branch]`：
  `git ls-remote --heads <remote> main | cut -f1` 应等于 `git rev-parse HEAD`。
- 误推的处置（幂等、安全）：先补推正确分支 `git push <remote> HEAD:main`，
  再 `git push <remote> --delete master`（该分支是本轮误建、内容与 main 相同，无引用）；
  最后两个 remote 各再 `ls-remote --heads` 复核只剩 `main`/`history/pre-vk34`。
- 同理适用于任何「`[new branch]` 却不报错」的场景：**新分支不是成功信号**，
  只有「期望的分支 sha 变了」才是。
