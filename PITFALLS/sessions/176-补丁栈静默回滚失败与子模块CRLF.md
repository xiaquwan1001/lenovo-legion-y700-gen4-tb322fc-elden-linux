# 2026-11-07 夜：UEFI 构建脚本的「静默回滚失败」与子模块 CRLF 补丁（p45 备料）

- 日期：2026-11-07（夜）
- pi 会话 id：见 `.pi/sessions/`
- 主题：`scripts/uefi-build-variant.sh` 的补丁应用/回滚路径把「失败」当「成功」，导致工作区残留改动被误判为干净
- 结论：① `revert_patch()` 用 `git apply -R … || true` **吞掉回滚失败** ⇒ 残留改动只看主仓 `git status` 查不到
  （在 `MU_BASECORE` / `Common/MU_TIANO` / `Silicon/Arm/MU_TIANO` 里）；② 子模块补丁若被 `git diff` 归一化掉 CRLF，
  裸 `git apply` 会静默对不上 ⇒ 补丁未进配方而构建「成功」。
- 证据指针：`reports/uefi-p45-ebscreen-prebuilt-20261107.md` §6、
  `scripts/uefi-build-variant.sh`（`apply_patch`/`revert_patch`/`reset_tree`）、
  补丁 `patches/uefi/20261107R39-ebscreen/`、`patches/uefi/20261107R40-noclear/`
- ★SSOT 待并入：`PITFALLS/README.md` #545（已并入）

## #545 补丁栈脚本「回滚失败也返回成功」⇒ 工作区残留改动藏在子模块里

- **现象**：手工用「逆序 `git apply -R`」回滚一套 66 枚的配方后，主仓 `git status --porcelain`
  只剩 `M Common/MU_TIANO` / `M Silicon/Arm/MU_TIANO`（子模块指针），看起来是干净的；
  实际 `git -C MU_BASECORE status` 里还有 `Dispatcher.c`/`DxeMain.c`/`Image.c`/`BdsEntry.c`，
  `git -C Common/MU_TIANO status` 里还有 `PrePiLib.c`/`FwVol.c` —— 全是没回滚掉的补丁改动。
- **根因**：`uefi-build-variant.sh` 的 `revert_patch()` 写成 `git apply -R "$p" 2>/dev/null || true`，
  回滚失败（上下文被后续补丁改过、或 CRLF/空白不一致）时**照样返回 0**；
  `reset_tree()` 因此认为「已回滚」，下一个变体就在**脏工作区**上继续打补丁。
  本轮手工回滚时同样被这条骗过一轮。
- **判据/对策**：
  1. `revert_patch()` 不再吞错，失败 `return 1`；`reset_tree()` 打 `WARN: 回滚失败，工作区可能残留改动`。
  2. `apply_patch()` 每层加 `--ignore-whitespace` 兜底（严格 apply 失败后才用，并打 `note:`）；
     子模块里含 CRLF 的补丁（`.gitattributes` 是 `* -text`，`git diff` 会归一化）就靠它。
  3. **怀疑工作区脏时逐子模块查**：`for sm in MU_BASECORE Common/MU Common/MU_TIANO Silicon/Arm/MU_TIANO; do git -C $sm status --porcelain; done`
     —— 主仓 `git status` 只报子模块指针，不报子模块里的改动。
