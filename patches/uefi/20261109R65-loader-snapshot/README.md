# 20261109R65-loader-snapshot — loader 侧源码快照（当前在机件 = `Loader-r65.efi`）

> **为什么是快照而不是补丁**：R55→R65 的 loader 侧改动**从未提交**（Mu 树是单提交浅克隆
> `6b6ac42a`，`.git/shallow`），也**没有**逐代补丁目录（`patches/uefi/` 里只有 R54/R55/R56/R61/R62，
> R57/R58/R58b/R59/R60/R63/R64/R65 全是工作区手工改动）⇒ 2026-11-09 之前**`Loader-*.efi` 不可再生**。
> 累计 `git diff` 与 R54/R61/R62 的补丁体**相互重叠**，做成 patch 栈会 apply 冲突 ⇒ 改为「整文件快照 + 基线提交」。

## 1. 内容

| 文件 | sha256 | 上游路径（Mu 树内） |
|---|---|---|
| `LinuxLoader.c` | `2599bc3b…` | `Platforms/QcomModulePkg/Application/LinuxLoader/LinuxLoader.c` |
| `VerifiedBoot.c` | `1b8f409d…` | `Platforms/QcomModulePkg/Library/avb/VerifiedBoot.c` |
| `BootLib.inf` | `a599d9e1…` | `Platforms/QcomModulePkg/Library/BootLib/BootLib.inf` |
| `FrameBufferSerialPortLib.c` | `f6f7cf78…` | `Platforms/AndromedaPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c` |

**基线**：`6b6ac42a`（`mu_wide_platforms`，浅克隆唯一提交）。快照 = 基线 + **R54**（BDS ESP-first）
+ R55/R56/R57/R58/R58b（ESP-first 读件、面板标记、`\espboot.log`、`\loader.log`、`\espboot.force`）
+ R59/R60/R61/R62-r6x（兜底与崩溃重挂）+ **R65 启动菜单**（`\menu.cfg`、`LMenuLoad`/`LMenuSelect`、音量/电源键）。

## 2. 复现某个 loader 件

```bash
MU=build/uefi-woa-prep/repos/7-mu-lenovo
git -C $MU reset --hard 6b6ac42a && git -C $MU submodule update --init --recursive
cp patches/uefi/20261109R65-loader-snapshot/{LinuxLoader.c,VerifiedBoot.c,BootLib.inf,FrameBufferSerialPortLib.c} \
   $MU/…（按 §1 的路径逐份放回）
cd $MU && ~/.local/bin/stuart_build -c Platforms/PakalaPkg/PlatformBuildNoSb.py \
   TARGET=RELEASE TARGET_DEVICE=lenovo-y700g4        # 增量 12–23 s（ccache 热）
# 产物：Build/PakalaPkg/RELEASE_CLANGDWARF/AARCH64/LinuxLoader.efi
```

- **不做逐字节可复现**：EDK2 产物含 `__DATE__/__TIME__`（`PITFALLS #510` 同族）⇒ 重建后只比
  「体积同量级 + 关键串在」（如 `[L] menu `、`espboot.force`、`loader.log`），别比 sha。
- 已构建并存在的件（`out/espboot-20261108/`）：`Loader-r63.efi` `92a73b78…`（菜单前 + 正式化草案基线）、
  `Loader-r65.efi` `3523b320…`（**与本次快照对应**；r65 上机日志 `menu entry n 4 / key 2 / sel 1 / key 258`）。

## 3. 与 `--gen p61` 的关系

- `p61`（`patches/uefi/p61-recipe.txt`）只覆盖**固件 FD**（BdsDxe 侧：R54/R62 等 79 个补丁），
  **不含**本快照的 loader 侧源码 ⇒ 复现「跑通路线 B 的整机件」需要 **两件**：
  FD（`--gen p61 --verify`）+ `Loader.efi`（§2）。
- 写到 ESP 的入口 = `scripts/esp-put-loader.sh --loader <efi>`（同步 + 读回校验 + `fsck.vfat -n`）。

## 4. 正式化（待做，另见 `.pi/plans/` 与 `TASKS` §5 深夜块 ④）

`BootIntoFastboot = TRUE`（`LinuxLoader.c:758` 附近）仍写死，靠 `\espboot.force` 抵消；
未写 `#timeout` 的多条目 `menu.cfg` 只取第 0 项。方案与判据见
`TASKS/README.md` §5「2026-11-08（深夜）」块与 2026-11-09 静态分析（草案 `/tmp/elden-r63/`）。
