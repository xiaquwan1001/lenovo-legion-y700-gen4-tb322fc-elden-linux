# Pengyu Luo 上游代码参考（Y700 Gen4 / elden）

> 2026-10-12 拉取。Pengyu Luo `<mitltlatltl@gmail.com>` 是 **本机（Lenovo Legion Y700 Gen4 = sm8750-lenovo-elden）** 的主线上游作者：
> panel 驱动、Y700 Gen4 DT 都由他提交。本目录保存其**上游原始代码**，供与本树（elden 分支）对比与上游化。

## 文件与出处

| 文件 | 出处 | 说明 |
|---|---|---|
| `panel-novatek-nt36536.c` | `torvalds/linux` master，`drivers/gpu/drm/panel/panel-novatek-nt36536.c`（486 行） | NT36536 面板驱动（CSOT PP8807HB1-1）。上游加入 commit `75a5dbd1f4f7`（本树 **NOT-IN-TREE**；本树为其衍生版 + elden 改动） |
| `sm8750-lenovo-elden.dts` | 0-day bot 镜像 `github.com/intel-lab-lkp/linux` commit `2c4ddee5c903f029247b90aa92c98ee7245891e5`（1096 行） | Pengyu 的 Y700 Gen4 DT（v2 系列，2026-08；本树同名 DTS 为其扩展） |

原始 URL：
- driver: `https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/panel/panel-novatek-nt36536.c`
- dts: `https://raw.githubusercontent.com/intel-lab-lkp/linux/2c4ddee5c903f029247b90aa92c98ee7245891e5/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`
- 系列：nt36536 `[PATCH v3 0/2]`（lore `dri-devel`，2026-07）；Y700 Gen4 `[PATCH v2 0/2]`（2026-07-26）

## 与本树的差异（潜在上游化 / 排查点）

### 驱动 `panel-novatek-nt36536.c`（本树 558 行 vs 上游 486 行）
1. **`to_primary_dsi()`**：上游 dual-DSI 时返回 **`ctx->dsi[1]`**（"Sync on DSI1"）；**本树改成 `ctx->dsi[0]`**（注释：elden 下游命令 master 是 DSI0，MSM manager 会把每次写镜像到 DSI1 再触发 DSI0 广播 master）。—— 与 bonded 首条 DCS 直接相关，**Q28 排查要点**。
2. **init 重试**：本树在 `novatek_prepare()` 加 `for tries` 循环（失败 → `novatek_reset` → 重试 2 次），对应提交 `d02658e63`；上游无重试。另加 `novatek_enable()`（`panel->prepared ? 0 : -EIO`）。
3. **`force_hz` 模块参数** + 额外刷新率模式（40/24 Hz）并把 165 Hz 提前为 preferred；上游无。
4. **probe 顺序**：本树把 backlight 创建移到 `devm_mipi_dsi_attach()` **之前**（上游在 attach 之后）。

### DTS `sm8750-lenovo-elden.dts`（本树大很多，含 elden 扩展）
- 本树显示段（`&mdss` 起 820 行 vs Pengyu 293 行）新增：
  - `&mdss { memory-region=<&splash_mem>; /delete-property/ iommus; }` + `&mdss_mdp { iommus=<&apps_smmu 0x800 0x2>; }`
  - `panel0` 节点（reset-gpios / vddio,vsp,vsn / pinctrl / backlight / ports）
  - `&mdss_dsi0_out`、`&mdss_dsi1_out` 的 `data-lanes = <0 1 2>`
  - **`&mdss_dsi{0,1}_phy { qcom,cphy-timing-ctrl = [...] }`**（下游精确 C-PHY timing；两者都 `phy-type = <PHY_TYPE_CPHY>`）
  - `&mdss_dp0` okay、WCN7861 PCIe 节点、thermal zones 等大量非显示扩展
- Pengyu v2 里 `&mdss_dsi0` 只留 `/* panel: csot,pp8807hb1-1 */` 注释（该 lkp 快照未含 panel 节点）。

### 上游相关 patch 在本树的状态
| 上游 | 内容 | 本树 |
|---|---|---|
| `e4eb11b34d6c`（Pengyu，2026-03）`drm/msm/dsi: fix pclk rate calculation for bonded dsi` | bonded DSC 每半屏分别 round-up hdisplay | **已在树**（`dsi_adjust_pclk_for_compression(..., is_bonded_dsi)`） |
| `2028280686f4`（Dmitry，2026-09）`round byte clk after reparenting to PHY PLL` | byte-clk 取整 | **NOT-IN-TREE**（＝Method B 要补） |
| `75a5dbd1f4f7` `drm/panel: Add Novatek NT36536` | 上游 panel 驱动 | **NOT-IN-TREE**（本树为衍生） |

## ★Q28 相关线索（Pengyu 本人报告）

`[PATCH] arm64: dts: qcom: sc8280xp: use refgen regulator for DSI`（2026-02-28，lore linux-devicetree）讨论中，Pengyu 在 2026-02-28 说：
> "Thanks for explaining this. **I saw a similar thing on sm8750, I had to reboot again and again to turn on the display once.**"

上下文 = DSI PHY 的 **refgen** 供电投票（Dmitry：有 refgen driver 时内核会在启动过程中把它关掉，若无 `refgen-supply` 投票则 DSI 失去基准）。Konrad：新 SoC 多有 PHY↔REFGEN 硬件连线自动处理。

本树核验：
- `sm8750.dtsi`（本树与上游 mainline 均）**无 refgen 节点、DSI 节点无 `refgen-supply`**；
- 但 `drivers/regulator/qcom-refgen-regulator.ko` **已编为模块** ⇒ 若存在 refgen 节点会被 probe（当前 sm8750 无）。
- ⇒ 对 sm8750 这条线索**可能不适用**（走硬件线），但**Pengyu 的"反复重启才有显示"与本机 STORM 症状一致**，值得作为候选根因之一保留/向他确认。

## 使用建议

1. 需要**上游原始 panel 驱动/DT** 做对比、上游化或提 patch 时，直接读本目录。
2. Q28 要核查/回归时，重点看 `to_primary_dsi`（DSI0 vs DSI1 命令 master）、`qcom,cphy-timing-ctrl`、以及 refgen 线索。
3. 拉更新：见上方原始 URL（本目录为快照，不自动更新）。
