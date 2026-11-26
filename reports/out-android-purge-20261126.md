# out/ Android 镜像构建工作区删除账（2026-11-26，用户授权）

> **授权**：用户 2026-11-26「允许删除安卓镜像相关的可再生部分」。
> **范围**：`out/` 下三个**可再生**的 Android 镜像构建工作区；**不动**候选启动件、取证件、不可再生集（见 §4）。
> **前置**：同轮磁盘审计 `reports/disk-audit-20261126.md` §1 A 项；缓存台账 `versions/cache-ledger.tsv`。

## 1. 删了什么

| 目录 | 删前体积 | 重建入口 | 内容 |
|---|---|---|---|
| `out/android-slim-v3-20261119/` | **29 G** | `scripts/android-slim-v3-build.sh` + `scripts/android-rom-segassemble.py` | Android super 分片重打包工作区（`new/super_min_v3.img` 与 `rb/super_rb.img` 互为重复，7.45 G） |
| `out/android-min-20261118/` | **8.5 G** | `scripts/android-min-build.sh` + 同上 | 最小镜像 v1 造件 + `work/` |
| `out/android-slim-v2b-20261119/` | **1.1 G** | `scripts/android-slim-v2-plan.sh` + 同上 | v2b 二分造件（含 9 个 root 属主文件，走 `sudo rm`） |
| **合计** | **38.6 G** | | |

**删前清单**（19 个 >50 MB 件的 sha256 + 字节数，逐条可回查）：`reports/artifacts/out-android-purge-20261126.sha256`

## 2. 为什么判「可再生」

- 三件全部由脚本从 **super 原厂件 + `assets/android-20261119` 树**重新切分/重打包得出；输入件不在删除范围内（`assets/` 保留，`scripts/android-assets-extract-20261119.py` 可再提取）。
- 三件都**不在**候选启动件账（`versions/out-candidate-sha.tsv`，doctor §29）里，也不是 `versions/vk-kernel-identity.tsv` 的任何 vk 镜像。

## 3. 代价（如实记账，不粉饰）

原账本 `versions/out-artifacts.tsv` 这三行是 **pending「禁删，等上机」**，理由分别是：
S1/S3 对照材料、S4 二分材料、唯一 final 但首启判据未取得。**用户本轮明确授权删除**，因此：
- 要复现 S1–S4 那几组对照实验 / 取首启判据，需先花 **~1–2 h/件** 重建（命令见 §1 表），再上机；
- 账本已把这 3 行改 `superseded`，**原判读文字逐字保留在原因列**（前缀「删除前的判读（照抄）」），不会被静默改写。

## 4. 明确保留（未动）

| 保留件 | 体积 | 为什么留 |
|---|---|---|
| `out/min-restore-20261119/` | 2.5 G | **不可再生**最小可恢复集，含已验候选件（doctor §29 在读） |
| `out/android-v3-bringup-20261120/` | 203 M | v3 上机取证件（boot/vendor_boot/metadata） |
| `out/android-root-20261119/`、`out/android-min-avb-20261118/`、`out/android-super-20261118/`、`out/edl-supermin-20261118/` | ≤40 M | 小件与 EDL 试装件，成本低、留着省事 |
| `out/` 其余（UEFI/显示/G7 等候选件与取证件） | ~4.4 G | 有 sha 账/门在读 |

## 5. 空间结果

| 时间点 | 仓库目录 |
|---|---|
| 2026-11-26 上午（缓存搬家前） | 123 G |
| 缓存搬到 `~/elden-cache/`（A 之前） | 80 G |
| **删三件 Android 工作区后** | **43 G** |

`df /home`：可用 203 G → **235 G**。

## 6. 门与台账同步

- `versions/out-artifacts.tsv`：3 行 `pending → superseded`（原因列保留原判读）；`scripts/out-status.py --check` = 17 条（active 0 / verified 3 / superseded 9 / pending 5）、**禁删类失踪 0**。
- `versions/cache-ledger.tsv`：3 行体积标 `0（已删）`；`scripts/cache-audit.sh --check` 支持「已删」历史行（仍禁止磁盘上是软链）——PASS 20 条。
- `reports/disk-audit-20261126.md` §1 A 项已执行。

## 7. 若要回滚

不存在「回滚到原件」的路径（文件已删），只能重建：

```bash
bash scripts/android-min-build.sh          # v1 造件  ~40–80 min
bash scripts/android-slim-v3-build.sh      # 唯一 final ~1–2 h
bash scripts/android-slim-v2-plan.sh       # v2b 二分件
```
