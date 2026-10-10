# Q28 上游精确 diff + 移植裁决（2026-10-10）

> 补 lane U 未落地的部分。父会话用 web_search/web_fetch 直接取回权威原文并逐条对树核实。

## 1. 权威事实（一手来源）
- **正解 = 上游 commit `2028280686f4fa78e2f1f6dede4b6c1fd782b9e3`**（Dmitry Baryshkov, 2026-09-03）。
  - lore `20260903-fix-eliza-dsi-v1-1-3474a6c9f2e0@oss.qualcomm.com`；Patchwork 750496；
    Reviewed/Tested-by Konrad Dybcio + Abel Vesa；**已进 mainline，v7.3-rc4**（非 rc3）。
  - Qualcomm 官方 backport：qualcomm-linux/kernel-topics PR #1867 → `tech/mm/drm`，merge `9511cf8cf5f2`，diff 与 lore 逐字一致，validate-patch ✅。
  - 关联 issue：#1153「Display/Graphics failure on Kanapa & Pakala with 7.3-rc2」、#1145「Graphics failing on Pakala 7.3-rc2」。
- 因果链：Kavan `6cd33b6f4155`（round 6G byte clk）→ Kozlowski `bc484ede914d` revert（"broke SM8750/Eliza"）→ Dmitry `2028280686f4` 正解。
- **机制（精确）**：DSI 6G v2.9 主机（SM8650/**SM8750**/Kaanapali）在 `dsi_link_clk_set_rate_6g_v2_9()`（PHY 使能后）把 byte/pixel RCG reparent 到 DSI PHY PLL。但 `dsi_calc_clk_rate_6g()` **跑得更早**（为 PHY 算 bitclk），那时 byte RCG 仍挂复位父 XO，`clk_round_rate()` 返回**废值(19.2 MHz)**灌进 PHY bitclk → PLL 编错频 → 破屏。Kavan 的错就在这（在 reparent 前取整）。

## 2. 上游 diff 原文（`2028280686f4`，dsi_host.c，19+ 17−）
```
 struct msm_dsi_host {
 	unsigned long byte_clk_rate;
-	unsigned long byte_intf_clk_rate;
+	bool byte_intf_clk_div_2;
 	unsigned long pixel_clk_rate;

 int dsi_link_clk_set_rate_6g(struct msm_dsi_host *msm_host)
 {
+	unsigned long byte_intf_clk_rate;
+	long rounded_byte_clk_rate;
 	int ret;
+
+	rounded_byte_clk_rate = clk_round_rate(msm_host->byte_clk,
+					       msm_host->byte_clk_rate);
+	if (rounded_byte_clk_rate < 0) {
+		pr_err("%s: failed to round byte clock rate, %ld\n",
+		       __func__, rounded_byte_clk_rate);
+		return rounded_byte_clk_rate;
+	}
+	msm_host->byte_clk_rate = rounded_byte_clk_rate;
 	DBG("Set clk rates: pclk=%lu, byteclk=%lu", ...);
 ...
 	if (msm_host->byte_intf_clk) {
-		ret = clk_set_rate(msm_host->byte_intf_clk, msm_host->byte_intf_clk_rate);
+		byte_intf_clk_rate = msm_host->byte_clk_rate;
+		if (msm_host->byte_intf_clk_div_2)
+			byte_intf_clk_rate /= 2;
+		ret = clk_set_rate(msm_host->byte_intf_clk, byte_intf_clk_rate);

 int dsi_calc_clk_rate_6g(...)          // ← 删除 Kavan 在 dsi_calc_pclk 之后加的取整块
 {
-	long rounded_byte_clk_rate;
 	...
 	dsi_calc_pclk(msm_host, is_bonded_dsi);
-	rounded_byte_clk_rate = clk_round_rate(msm_host->byte_clk, msm_host->byte_clk_rate);
-	if (rounded_byte_clk_rate < 0) { ... }
-	msm_host->byte_clk_rate = rounded_byte_clk_rate;
 	msm_host->esc_clk_rate = clk_get_rate(msm_host->esc_clk);

 int msm_dsi_host_power_on(...)         // ← 不再预计算 byte_intf_clk_rate
 {
-	msm_host->byte_intf_clk_rate = msm_host->byte_clk_rate;
-	if (phy_shared_timings->byte_intf_clk_div_2)
-		msm_host->byte_intf_clk_rate /= 2;
+	msm_host->byte_intf_clk_div_2 = phy_shared_timings->byte_intf_clk_div_2;
```
要点：**取整放在 `dsi_link_clk_set_rate_6g()`（generic，在 `_v2_9` reparent 之后被调用），对象是 `msm_host->byte_clk`（RCG，此时已挂 PLL）**；byte_intf 由取整后的 byte_clk_rate 现算。

## 3. ★移植裁决：逐字 cherry-pick 对本树**无效**（父代逐条对树核实）
本树 dsi_host.c 现状（已核）：
- `dsi_calc_clk_rate_6g()` = **干净原始版**（只有 `dsi_calc_pclk` + `esc=clk_get_rate`），**无 Kavan 的 `clk_round_rate` 块**。
- struct 仍是 `unsigned long byte_intf_clk_rate`（未改 bool div_2）。
- `6cd33b6f4155` / `bc484ede914d` / `2028280686f4` **全部 NOT-IN-TREE**。
⇒ **本树 = 前置 Kavan 的 7.2 基线 = 上游"7.2 panels 正常"那一侧**。上游 #1153 是 **Kavan 引入的 7.3-rc2 回归**，我们没这个回归。
⇒ **`2028280686f4` 的删除型 hunks 应用不上**（删我们不存在的代码），且**它修的不是我们的 Q28**。

## 4. 那"取整"到底还该不该做？
- 事实不变：本树驱动请求 byteclk 133.076 MHz，PLL 实际 108.108 MHz（差 23%），`byte_clk_rate` 恒 ≠ 可达值 → CCF 每次 transfer 可能 re-evaluate（这正是上游 commit message 后半句"Derive byte intf from the rounded rate, otherwise it keeps requesting the idealized rate and **retrigger the PLL on every transfer**"描述的隐患）。
- 所以**"reparent 后把 byte_clk_rate 取整回写"对本树仍是合理加固**——但**等价于上游的"加"的部分，不含"删"的部分**（我们本就没有要删的）。worker 草稿方向对，但落点/对象需按上游校准：
  - 落点应是 **`dsi_link_clk_set_rate_6g()`**（generic，`_v2_9` reparent 后调用它），**不是** `_v2_9` 内 SM8750 分支。
  - 对象 `clk_round_rate(msm_host->byte_clk, …)`（RCG），不是 `dsi_pll_byte_clk`。
  - **绝不在 `dsi_calc_clk_rate_6g` 里取整**（那会重演 Kavan 的 XO-父废值 bug）。
- ⚠ 但**它是否真能消 Q28 仍是经验问题**：Q28 强依赖**冷/暖复位**，而 Kavan 回归是"恒定破屏"、与复位类型无关——说明我们的冷启竞态**未必是同一根因**。取整可能只是降低 re-lock churn 概率，未必根治。

## 5. 下一步（修订，取代 handoff §3 的"cherry-pick"）
1. 以「上游"加"部分的等价移植」重写 Method B（落点 generic `dsi_link_clk_set_rate_6g`、对象 byte_clk、派生 byte_intf；**不动** dsi_calc_clk_rate_6g / 不做删除 hunks）。作为 vk85 候选。
2. **冷起 A/B 为唯一仲裁**（暖起不敏感）：base vs round vs（delay/CLK_STATUS 轮询）物理冷起各 N 次，看坏发率。
3. 若取整冷启仍高坏发 ⇒ Q28 另有根因，转：CMD engine 编程序 / PHY `save/restore_pll_state` 在冷/暖路径差异 / `dsi_cmd_link_clk_set_rate` 的 `-ESTALE` 路径 / 首帧 TE 依赖。串口常驻 + pstore-catch 抓真实现场栈。
4. 记 PITFALLS/记忆：**别对我们树逐字 cherry-pick 2028280686f4**（缺前置 Kavan，我们在 7.2 已知良好侧）。

## 6. 来源
- https://github.com/torvalds/linux/commit/2028280686f4.patch （raw diff 全文）
- https://github.com/qualcomm-linux/kernel-topics/pull/1867 （官方 backport + 机制说明）
- http://www.mail-archive.com/freedreno@lists.freedesktop.org/msg46766.html 、msg46768（评审）
- https://ratatoskr.run/dri-devel/2026-09-17504604/t 、2026-09-17504052（revert）、2026-07-17220914（Kavan）
