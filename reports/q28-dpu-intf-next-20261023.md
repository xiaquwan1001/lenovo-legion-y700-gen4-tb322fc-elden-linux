# Q28 下一个变量：DPU/INTF 侧（含新拿到的 OEM 显示驱动源码对照）— 2026-10-23

> 承接 `reports/upstream-mail-sm8750-refs-20261023.md` §3（Pengyu 提示「DPU 侧才是缺口」）与
> `reports/upstream-mail-sm8750-refs-20261023.md` §4（面板供电核对）。
> 本轮只做**主机侧静态对照 + 设备侧只读取证**，未改内核、未刷机。

---

## 0. 结论

1. **新资产**：OEM 显示驱动**源码**就在本地 —— `stock-src/android_kernel_lenovo_sm8750-modules/qcom/opensource/display-drivers/`
   （`msm/dsi/{dsi_clk_manager,dsi_ctrl_hw_2_2,dsi_phy_hw_v3_0/v4_0/v5_0,dsi_panel,...}`、`msm/sde/`）。
   `stock-src/android_kernel_lenovo_sm8750/` 是 GKI 树（只有 upstream `drm/msm` + `drivers/gpu`/`mmc`/`sound`），
   **没有 `drivers/power/supply`**、也没有 QBG/battery 代码 ⇒ 电池问题仍无法从下游源码回答（已向 Konrad 发更正说明）。
2. **Pengyu 提到的「10-bit C-PHY clk source select」在 DSICLK_SEL 这一层我们已经做了、且与 OEM 一致**：
   - OEM：`DSI_W32(phy, DSIPHY_CMN_CLK_CFG1, data << 2)`（bit2 = 内部/外部 PLL），**整寄存器写** ⇒ 其余位
     （`DSICLK_SEL`、`BITCLK_SEL`）被清 0；
   - 我们（`dsi_phy_7nm.c:851-865`）：对 `qcom,sm8750-dsi-phy-3nm` 显式 `DSICLK_SEL(0)` + `PIX_CLK_DIV=2`，
     非 SM8750 才走 `DSICLK_SEL(3)`；`disp_cc_mdss_pclk0/1_clk_src` 实测 172 972 734 Hz
     （理论 756 839 941/2 × 16/35 = 172 991 986 Hz，−0.011%，属分频取整）。
   ⇒ 已去信请 Pengyu 给出他指的具体寄存器（若是 INTF/dispcc mux 而非 PHY CMN，我们再测）。
3. **bonded 双 DSI 的时钟父链是对的，不是缺陷**：OEM `dsi_clk_update_parent()` 明确把**第二路**的
   `byte_clk`/`pixel_clk` 的 parent 设成**第一路**的；我们的好启动实测一致（`pclk1`/`byte1` ← `dsi0_phy_pll_out_*`）。
   ⇒ 「peer pclk 没起来」作为一个默认解释被否定（仍要用坏启动样本核对）。
4. 因此下一轮**先不加变量**，取**坏启动的同口径只读取证**再决定动哪：
   `scripts/q28-clkdiag.sh`（只读，0 风险）已在好启动上跑出基线样本
   （`reports/artifacts/q28-clkdiag-good-20261023.txt`）。

---

## 1. 好启动基线（本机 vk152，真 POR，2026-10-23）

```
boot_id=a87b537f  uptime≈...  card0-DSI-1=connected/enabled
dmesg 计数: command DMA timeout 0 | peer 0 | DSI_PLL_lockfail 0
            recovery is not complete 0 | reset failure 0 | STORM 0
            failed to acquire mdss resets 0
disp_cc_mdss_pclk0_clk_src  rate=172972734  parent=dsi0_phy_pll_out_dsiclk
disp_cc_mdss_pclk1_clk_src  rate=172972734  parent=dsi0_phy_pll_out_dsiclk
disp_cc_mdss_byte0_clk_src  rate=108107958  parent=dsi0_phy_pll_out_byteclk
disp_cc_mdss_byte1_clk_src  rate=108107958  parent=dsi0_phy_pll_out_byteclk
disp_cc_mdss_mdp_clk_src    rate=575000000  parent=disp_cc_pll0
```

## 2. 坏启动要看的 4 个数（判据先定死，避免事后找解释）

| # | 量 | 好启动值 | 坏启动若是 X ⇒ 指向 |
|---|---|---|---|
| 1 | `pclk1_clk_src` parent/rate | `dsi0_phy_pll_out_dsiclk` / 172 972 734 | 与 pclk0 不同 ⇒ **dispcc/DT 层**（peer 时钟没绑对） |
| 2 | `byte1_clk_src` parent/rate | 同上 | 同上 |
| 3 | `dmesg` 的 `ctl N reset failure` 序号 | 0 条 | 出现 `ctl 1` ⇒ **peer CTL/INTF**（与 REPORT v2 的历史样本一致） |
| 4 | `dri/0/summary` 里两路 encoder/crtc 的活动状态 | 两路 active | 单路 active ⇒ 绑定/encoder 侧 |

若 1–4 在坏启动上**都正常**，则排除时钟与绑定，下一变量收敛到
**DPU INTF 编程/CTL flush 顺序**（`dpu_hw_ctl.c` 的 `CTL_FETCH_PIPE_ACTIVE`、`INTF_MUX`、TE），
即 Krzysztof 那批 v12.0 DPU 改动所在的位置。

## 3. 待办

1. **收坏启动样本**：`≥8 发真 POR`（禁暖复位），每发起来后立刻跑
   `ssh root@192.168.7.1 'bash -s' < scripts/q28-clkdiag.sh`，好/坏分别归档。
2. 若坏启动 1/2 异常 ⇒ 查 `sm8750.dtsi` 两路 DSI 的 `clocks`/`clock-names` 与 dispcc `pclk_src` 的 parent 映射。
3. 等 Pengyu 回信（clk-src 具体位置 + 下游源码指针）与 Taniya 对 v2 三问的回答。
