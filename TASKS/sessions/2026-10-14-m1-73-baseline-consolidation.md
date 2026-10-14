# 会话记录 2026-10-14：M1-7.3 功能基线收敛整合（基线分支 + 上游补丁备料）

> 承接 `2026-10-14-m1-73-mainlining.md` §3「并入基线」。本次只做**收敛整合**（主机侧），**未上机、未写设备**。
> 设备：U2 `HA2EXB0E`（本轮未触碰）。

## 0. 数字先行

| 项 | 值 |
|---|---|
| 基线分支 | `build/m1-upstream/clean-tree-73` @ **`m1-73/baseline`**（tip **`c7da05b1d8`**）= `m1/clean-tree-7.3rc7` + **2 提交** |
| 提交 ① | `54dc4dd8fe` `drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable`（**净 9 行 / 无探针 / 上游件**） |
| 提交 ② | `c7da05b1d8` `ath12k: shorten MHI wait timeout 90s->3s`（**本地件**） |
| 剔除 | E1（refcount 变更）、E1g（Kconfig hack）——均非基线所需 |
| 全量构建 | `make -j16 … Image.gz dtbs` → **rc=0 / 0 error / 0 warning**；`Image.gz` **20 798 895 B**；板 DTB 153 101 B（**补丁前后逐字节同**） |
| 上游补丁 | `patches/upstream/m1-2026-10-14/0001-…PLL_SYSTEM_MUXES…patch`（1 枚，**未发送**） |
| 门 | checkpatch `--strict` **0E/1W/0C**；pristine `24a19b953e` `git am` **rc=0**；目标文件编译 **rc=0** |

## 1. 做了什么

1. **建基线分支**：从 `m1/clean-tree-7.3rc7`（= 7.3-rc7 + 板 DTS 追赶 `1e4077e13f`/`b3815fb150`）起 `m1-73/baseline`。
2. **只放两枚提交**：
   - `54dc4dd8fe`：在 `dsi_7nm_phy_enable()` 预置 `pll_enable_cnt = 1` 后补写 `PLL_SYSTEM_MUXES = 0xc0`（`dsi_pll_enable_pll_bias()` **保持上游原样**）；**无 pr_info 探针**。
   - `c7da05b1d8`：cherry-pick E2 的 ath12k MHI 超时改动（本就无探针）。
3. **构建验证**（日常 config：`ATH12K=y` / `ATH11K=m` / `FSA4480=m`，与 `linux/.config` 逐项一致）：rc=0，0 error/0 warning。
4. **产出上游补丁**：`patches/upstream/m1-2026-10-14/`（0001 + README），checkpatch / pristine git am / 编译三门通过。

## 2. 关键判据（为什么只发 DSI 那 1 行）

- **DSI 修复 = 上游件**：它修的是**上游回归**（`44784327815b` revert 了 `93c97bc8d85d`），带 `Fixes:` 标签、净 1 行语义、`dsi_pll_enable_pll_bias()` 语义不变 ⇒ 不会再次以"破坏非 bonded"为由被 revert。上机证据 = E1b 干净 POR 发（面板有内容 + 触屏，`dsi_isr=41`）。
- **ath12k 超时 = 本地件、不进上游**：`reports/upstream-policy-20261013.md` §3 明确列 **Q3 违例 D4**（"全局超时 | 掩盖 WCN 上电时序 | **删；正确解 = probe defer**"）。故仅留在功能基线，上游形态另立项（probe defer）。
- 与 E2 会话 §3 口径一致：**E1b 无探针版 = 上游件；0001 / Kconfig / 板 DTS = 本地件**。

## 3. 证据 / 产物

- 分支：`build/m1-upstream/clean-tree-73` @ `m1-73/baseline`（`git log --oneline -2`）
- 补丁目录：`patches/upstream/m1-2026-10-14/`（0001 patch + README）
- 构建日志：`/tmp/m1-baseline-build.log`（临时，非入账）；构建产物 `arch/arm64/boot/{Image.gz,dts/qcom/sm8750-lenovo-elden.dtb}`
- 上机依据（既有）：`reports/m1-73-e1b-pllfix-20261014.md`、`reports/m1-display-rootcause-analysis-20261014.md`

## 4. 遗留 / 下一步

1. **未打包 boot 镜像**：本次只做源码基线收敛，未生成 `out/boot-elden-m1-baseline.img`；如需上机复核再打包（ramdisk/DTB 复用 `73j` 口径）。
2. **投递冻结中**（用户 2026-10-13）：上游补丁只备料，不发邮件。
3. 与 Q31 关系：E1b 修复已确认，本次把它固化成**无探针可提交形态**并纳入基线；§5 Q31 / §7 状态不变。
