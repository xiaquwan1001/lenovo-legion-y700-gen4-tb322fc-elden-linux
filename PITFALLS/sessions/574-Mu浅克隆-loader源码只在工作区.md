# 「六、脚本/工具」抽出：#574（原 `06-脚本工具.md` 内条目）

## #574：Mu 树是**单提交浅克隆**，「活线 loader 源码只在工作区」⇒ `Loader-*.efi` 曾整体不可再生

- 现场（2026-11-09 静态盘点）：`build/uefi-woa-prep/repos/7-mu-lenovo` 的 `git log` 只有 **1 个提交**
  （`.git/shallow`，`6b6ac42a`）⇒ **不能 `git stash`/`git log -p`/`git blame` 找回历史**；
  `git status` 常驻 5 项脏改动（`LinuxLoader.c` +557、`VerifiedBoot.c` +283、`FrameBufferSerialPortLib.c` +28、
  `BootLib.inf` +1、`Common/MU_TIANO` 子模块 m）。
- 后果：R55→R65 每一代 `Loader-*.efi` 都**只是「当时工作区的产物」**，`patches/uefi/` 里没有对应补丁目录
  （只有 R54/R55/R56/R61/R62 这几个 FD 侧目录）⇒ 换机器/重置工作区即永久丢失，且**无法分辨某个 `.efi` 由哪些改动构成**。
- 已修：`patches/uefi/20261109R65-loader-snapshot/`（4 个文件的整文件快照 + `SHA256SUMS` + 放回路径 + 构建命令），
  并写明**基线提交 `6b6ac42a`**、产物对应 `Loader-r65.efi` `3523b320…`。
- 为什么用快照而非 patch：累计 `git diff` 与 R54/R61/R62 的补丁体**相互重叠**，做成 patch 栈会 `git apply` 冲突；
  且 EDK2 产物含 `__DATE__/__TIME__`（`#510` 同族）本就不可能逐字节复现。
- 纪律：**动 Mu 树前先确认活线源码是否已冻结**；新增 loader 改动 → 更新快照目录（同一目录覆盖 + 改 `README` 的「对应产物」行），
  并同步 `patches/uefi/README.md` §0 的「两件」清单（FD 用 `--gen`，loader 用快照）。
