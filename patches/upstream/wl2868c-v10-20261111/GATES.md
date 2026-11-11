# wl2868c v10 门禁记录（2026-11-11）

门禁树：`/tmp/wl10-tree`（= `build/base-7.2` 的 worktree，checkout 到 pristine 基点
`25f7927e6ccb6f4d8652b2b474d4c935faf580f6`「linux 7.2 pristine (tarball)」，
v10 两件 commit 由 v9 补丁 am 后按 `reports/wl2868c-v10-plan-20261111.md` §7 改出）。
注：v9 正式基线是 7.4-rc2 `d48723711b`；本轮复用方案 §8 已验证的 7.2 pristine
（`devm_regulator_get_enable_optional()` 在 7.2 已存在，见方案 §4.3 的逐行证据）。

| # | 门禁 | 命令 | 结果 |
|---|---|---|---|
| G1 | git am 干净落地 | `git worktree add /tmp/wl10-amcheck 25f7927e6 && git am v10-0001 v10-0002` | ✅ AM_OK，`git status --porcelain` 空；跑完 worktree 已 `git worktree remove --force` 删除 |
| G2 | checkpatch --strict 0001 | `perl scripts/checkpatch.pl --strict --no-tree v10-0001-*.patch` | ✅ `total: 0 errors, 0 warnings, 0 checks, 111 lines checked` |
| G3 | checkpatch --strict 0002 | 同上换 0002 | ✅ `total: 0 errors, 0 warnings, 0 checks, 311 lines checked` |
| G4 | 驱动 W=1 编译 | `make -j26 O=/tmp/wl10-kbuild ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/regulator/wl2868c-regulator.o`（defconfig + I2C/REGULATOR/REGMAP_I2C/REGULATOR_WL2868C=y） | ✅ rc=0，0 warning（输出仅 `CC drivers/regulator/wl2868c-regulator.o`） |
| G5 | dt_binding_check | `make -j26 O=/tmp/wl10-kbuild ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- DT_SCHEMA_FILES=Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml dt_binding_check` | ✅ rc=0（CHKDT/LINT/STYLE/DTEX/DTC 全过） |
| G6 | get_maintainer --self-test=patterns | 在 25f7927e6、HEAD~1、HEAD 各跑 `scripts/get_maintainer.pl --self-test=patterns` | ✅ rc=0；三处均无 wl2868 相关告警（仅上游既有的 ep93xx/dma-buf 无关告警）。MAINTAINERS 的 `F: drivers/regulator/wl2868c-regulator.c` 已按方案 §7.3 移到 2/2 |

补丁 sha256（投递件）：

```
57cc867b080bdcf1bdeab1356b1b9a8887f27cc783c47948c0a49e8344fa2af6  v10-0000-cover-letter.patch
151bbfc0e1a57447c43b4d9959dbec42873b49fa03586e2eef3e278078e20add  v10-0001-...patch
4242205ebc4c3d01e8553f7cda1bc335977c959b2ba20e50eeab600036e2edb5  v10-0002-...patch
```

复现：方案 §7 的基线抽取 + 本表命令；门禁临时产物在 /tmp（wl10-tree / wl10-kbuild / wl10-amcheck），不进仓库。
