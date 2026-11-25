# 磁盘清理执行（2026-11-25，用户授权「只删本项目的冗余垃圾，不动其他 tmp 文件」）

> 前置：`reports/repo-slim-candidates-20261125.md`（清单）+ `reports/tmp-forensics-20261125.md`（`/tmp` 归属取证）
> + `reports/build-residue-verify-20261125.md`（`build/` 残渣可重建性）。**本文件记录实际执行与复核结果**。

## 0. 数字

| 指标 | 清理前 | 清理后 | 变化 |
|---|---|---|---|
| `/` 已用 | 722 G | **643 G** | **−79 G** |
| `/` 可用 | 168 G | **247 G** | **+79 G** |
| 使用率 | 82 % | **73 %** | −9 pt |

## 1. 已删（全部经父代理独立复核，非仅采信 worker）

| 件 | du | 复核证据（我自己跑的命令） | 结果 |
|---|---|---|---|
| `/tmp/pkgtest` | 17 G | `scripts/odirect-sha.py`：`/tmp/pkgtest/super.img` = `out/android-min-20261118/pkg/super_min.img` = `e3d0d26f…`（O_DIRECT 逐字节相同） | ✅ 删（纯冗余副本） |
| `/tmp/super_rebuild.img` | 7.0 G | O_DIRECT：= `out/android-slim-v3-20261119/new/super_min_v3.img` = `51eae107…` | ✅ 删 |
| `/tmp/v3test` | 15 G | 内含 `super_auto.img`/`super_test.img`，源料 `backup/official-rom-15.10.259/super_{1..8}.img`（16 G）实存 ⇒ 可 `lpmake` 重打 | ✅ 删 |
| `/tmp/lpz` | 16 G | 同上源料实存；`scripts/android-super.py` + `lpunpack.py` 在 | ✅ 删 |
| `/tmp/ltbox-target` | 5.8 G | cargo `CARGO_TARGET_DIR`；`~/LTBox` 仓实存（HEAD `8f6d141c`） | ✅ 删（`cargo build` 可再生） |
| `/tmp/csiphy2` | 3.7 G | 补丁已归档 `patches/upstream/camss-csiphy-24-v2-20261117/` | ✅ 删 |
| `/tmp/b9` | 4.3 G | `tree/` 是独立 clone（HEAD `f66469d9`，10 个 dirty = aw86927 v1 工作区）、`out/` 是 v1 七封 | ✅ **先归档后删**：`backup/b9-20261113/{tree-dirty.diff,series.tar.zst,README.md}` |
| `/tmp/super_corrupt_evidence.img` | 7.0 G | 唯一位翻转证据（`8f962bee…`） | ✅ **先压缩归档后删**：`~/hw-stability/evidence/inbox/20261119-y700-elden-super-bitflip/super_corrupt_evidence.img.tar.zst`（3.97 G），**流式解包 sha 复核 = `8f962bee…` 通过** |
| `/tmp/rbex` | 3.9 G | 其 `system_a.img` = `db74cd06…`（= MANIFEST 值） | ✅ 先用它还原 `out/…/new/system_a.img`（见 §3），还原并复核后才删 |
| `build/g7a-tree` + `build/g7-tree` 的链接产物 | 6.4 G | `vmlinux.o`(1.7G×2) / `vmlinux` / `vmlinux.unstripped` / `.tmp_vmlinux*`；判据 = 源码 `v7.4-rc3@aebb727447` + 7 枚补丁 + 归档 DTS/`Image.gz`/config 全在 `out/g7-*`，重链 30 s | ✅ 删 **只删链接产物，保留两棵 worktree**（后续 v15 还要用） |

**合计实收 ≈ 79 G**（apparent ≈ 86 G，`du` 差值含归档前占位）。

## 2. 明确不删（有理由，写死免得下轮又提）

| 件 | du | 不删理由 |
|---|---|---|
| `/tmp/trixie-sysroot` | 2.6 G | `reports/rime-completer-userdir-20261124.md:329`、`reports/d3-ime-userdir-fallback-20261124.md:101` 把它当**现存路径**写进可复跑命令；删了这两条复跑前要先重建 |
| `/tmp/{aw86927-v4,dwc3-am-20261121,dwc3-base-1121,dwc3-v1{0,1,2,3}-*,v11-verify,…}` | ≈17 G | 全是 `build/elden-tree` 的 worktree，**dwc3 v15 / aw86927 v5 还要重打**；dirty=6/10 的是"已 apply 待重发"的现场。要删这些必须先 `git worktree prune` 并确认补丁已归档 |
| `/tmp/gu-test`、`/tmp/ncm-cold-before`、`/tmp/ncm-cold-after` | 7.8 G | **不是本项目的**：Gradle daemon 日志 `currentDir=~/netease-mini-player/ui/android`、cargo fingerprint 指向 `netease-mini-player/core/crates/ncm-*` |
| `build/g7a-tree`、`build/g7-tree`（整树） | 13.6 G（删链接后） | 仍是 worktree，v15/回归要重编；整树可删（A-2 ≈19 G）但需先归档 `.config`（已做：`out/g7-reset-20261123/config-g7a-reset.config`）——本轮不动，等 v15 落地后再说 |
| `out/android-slim-v3-20261119`（28 G）等四大目录 | 40 G | `versions/out-artifacts.tsv` 全 `pending/verified` ⇒ 禁删 |

## 3. 顺带修掉的 SSOT 漂移（不是删除，是复原）

`out/android-slim-v3-20261119/new/system_a.img` 实物 = `0b400b93…`，而 `MANIFEST.md`/`SHA256SUMS`/
`~/hw-stability/.../hashes.txt` 三方记 `db74cd06…`。定因 = **11-19 21:18 被 rw 挂载过一次**
（`cmp -l` 仅 13880 字节不同且全在 metadata 区；`dumpe2fs -h` 两边 UUID/created 逐字相同、实物
`Last mount time = 11-19 21:18:35`）。处置 = 用 MANIFEST 同值的干净件还原 + O_DIRECT 复核通过。
纪律已入 `PITFALLS #718`（pending 镜像只读处理）。

## 4. `scripts/out-archive.py` KEEP 表修正（用户授权「可以修表」）

补登 `boot-elden-vk189.img`（在机 daily）与 `boot-elden-vk192.img`（回退件）。旧表 dry-run 会把这两件判成
「归档候选」= 误归档在机件。补后 dry-run：**保留 16 件 / 归档 8 件（572 MiB）**（原 10 件 / 735 MiB）。
`reports/out-archive-20261105.md` §2 已同步。

## 5. 复现判据

```sh
df -h /                                     # 期望 ~73%（≈247 G 可用）
ls /tmp/{pkgtest,v3test,lpz,ltbox-target,csiphy2,b9,rbex} 2>&1 | head   # 全部 No such file
scripts/odirect-sha.py --tsv out/android-slim-v3-20261119/new/system_a.img   # db74cd06…（= MANIFEST）
python3 scripts/out-archive.py               # dry-run：保留 16 / 归档 8
tar --zstd -xOf ~/hw-stability/evidence/inbox/20261119-y700-elden-super-bitflip/super_corrupt_evidence.img.tar.zst \
    super_corrupt_evidence.img | sha256sum   # 8f962bee…（证据可复原）
```
