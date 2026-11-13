# wl2868c v11 门禁记录（2026-11-13）

树：`/tmp/wl11-tree` = `build/base-7.2` 的 worktree，detached 到 pristine
`25f7927e6ccb6f4d8652b2b474d4c935faf580f6`（linux 7.2 tarball），v10-0001/0002
`git am` 后按 Mark Brown 对 v10 2/2 的提问再加一处改动（清 LDOx_SEQ 槽位）。
基线口径与 v10 相同（7.2 pristine；`devm_regulator_get_enable_optional()` 在 7.2 已存在）。

| # | 门禁 | 命令 | 结果 |
|---|---|---|---|
| G1 | git am 干净落地 | `git worktree add /tmp/wl11-amcheck 25f7927e6 && git am v11-0001 v11-0002` | ✅ AM_OK，`git status --porcelain` 空 |
| G2 | checkpatch --strict 0001 | `perl scripts/checkpatch.pl --strict --no-tree v11-0001-*.patch` | ✅ 0 errors, 0 warnings, 0 checks, 111 lines |
| G3 | checkpatch --strict 0002 | 同上换 0002 | ✅ 0 errors, 0 warnings, 0 checks, 332 lines |
| G4 | 驱动 W=1 编译 | `make -j26 O=/tmp/wl11-kbuild ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/regulator/wl2868c-regulator.o`（defconfig + I2C/REGULATOR/REGMAP_I2C/REGULATOR_WL2868C=y） | ✅ rc=0，仅 `CC` 一行、0 warning |
| G5 | dt_binding_check | `make -j26 O=/tmp/wl11-kbuild ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- DT_SCHEMA_FILES=Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml dt_binding_check` | ✅ rc=0（binding 本轮未改） |
| G6 | 器件寄存器读数（回信证据） | 设备上 `cat /sys/kernel/debug/regmap/10-002f/registers` | ✅ 0x0a..0x0d=00、0x0e=0x80、0x0f=0x00（原文 `reports/artifacts/wl2868c-seq-20261113/read.txt`） |
| G7 | lore 投后逐字节复核 | 取回 1/2、2/2 raw → pristine `git am` → 比 blob | ✅ 5 个源文件 blob 全 SAME；`git diff` 空 |

投递件 sha256（仓库内 `patches/upstream/wl2868c-v11-20261113/`）：

```
0eb86b1527809f551372b86af976274d8435949e87f86d0b94758c5eb4e77a65  v11-0000-cover-letter.patch
d127d43c2057b0bbee6b90566da93f28d5a26d7269e0039e8f33ebda34bbf4cc  v11-0001-...patch
bed4a036e24da15f37deabe112b70afae4cd2fb546cc22ec8245d01bdd06d7a9  v11-0002-...patch
```
