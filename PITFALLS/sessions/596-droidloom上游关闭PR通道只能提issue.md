# #757 droidloom 上游**没有 PR 通道**（API 404）：只能 issue + compare 链接；上游只有 `main` 一条线

- 日期：2026-11-28（T42 调查 + 父代理复核）
- 事实（可复现）：
  - `gh api repos/denialwm/droidloom/pulls?state=open` 与 `?state=all` 均 **HTTP 404 Not Found** ⇒ repo 层禁用了 PR（不只是「没人提」）。issue #58/#66 正文亦写明 beta 期关闭外部 PR。
  - 仓库**只有 `main` 一个分支**（`gh api .../branches`），没有 next/staging；发布形态 = `Package release N` 直接进 `main`（现 `release 52` = `e6f18c4`）。
  - 官方**没有 AUR 包**（`aur.archlinux.org/rpc/v5/search/droidloom` → resultcount 0），「Arch 支持」实为自托管 pacman 仓库。
  - 唯一的第三方同构线 = `EvilBorsch/droidloom` 的 `eb/*`（`eb/main` ahead **25** / behind **0**，含 `.deb` 打包 + 57 s 交叉编 + 逐文件 `.MTREE` 校验）；它的 3 条 commit 正是我方 3 条本地 patch 的上游风格等价物（`201000a` runuser `/usr/sbin`、`5380af3` 去 `--forward-signals`、`2712d37` 宿主 resolver 进 lease）。
- 纪律：以后**不要**在任务/报告里写「给 droidloom 提 PR」；正确动作 = 提 issue（正文附 `compare/main...<our-fork>:<branch>` 链接与可复现日志），响应人事实上是 `synthia-si[bot]`（Discord↔issue 桥）。
- 出处：`reports/droidloom-fork-survey-20261128.md`（§1/§2/§6 + §11 父代理复核表）。
