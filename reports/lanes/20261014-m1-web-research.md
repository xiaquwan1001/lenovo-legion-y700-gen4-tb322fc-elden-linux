# M1 7.3-rc7 显示回归 —— 主机侧联网检索（2026-10-14）

> 任务：仅主机侧联网检索，回答 4 组问题。**不改设备、不改源码、不 commit。**
> 背景：reports/m1-73-display-regression-20261014.md（M1 7.3-rc7 重基树管道全绿但面板只有背光；同窗口 vk94 出桌面）。
> 证据规则：每条结论附 **URL + 原文引用**；区分「实测」与「文档/邮件记载」。
> 状态：进行中。

## Q1. 上游 kernel v7.3-rc 系列 qcom sm8750 display/DSI/DPU 是否有已知回归或修复？

**结论（实测 git.kernel.org，主线 torvalds/linux）**：v7.3-rc1..v7.3-rc7 窗口内 **drivers/gpu/drm/msm 共 15 个修复**，其中与显示/DSI 直接相关的有 3 个；**DSI 目录只有 1 个**（byte clock），**DPU 目录 0 个**。没有看到公开的"7.3-rc 把 SM8750 面板弄坏"的独立回归报告——唯一在本窗口提出的 SM8750 显示问题是本项目自己发的 [REPORT]（见 Q3a）。

命令（cgit range 查询，需 `h=<tag>`）：
```
GET https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/drivers/gpu/drm/msm?h=v7.3-rc7&qt=range&q=v7.3-rc1..v7.3-rc7
GET .../log/drivers/gpu/drm/msm/dsi?h=v7.3-rc7&qt=range&q=v7.3-rc1..v7.3-rc7
GET .../log/drivers/gpu/drm/msm/dpu?h=v7.3-rc7&qt=range&q=v7.3-rc1..v7.3-rc7
```
原始输出（drivers/gpu/drm/msm，v7.3-rc1..v7.3-rc7，15 条）：
```
f4fae975db08 drm/msm/hdmi_phy: fix runtime PM cleanup on probe failure
2028280686f4 drm/msm/dsi: round the byte clock rate after reparenting to the PHY PLL
a5b5cc909931 drm/msm/dpu: clear pending peripheral flush state
58995b11dfb7 drm/msm/dp: fix link bandwidth check when wide bus is enabled
6fbbf1e152f3 drm/msm/adreno: fix autosuspend cleanup during teardown
e249a6e2a130 drm/msm/dp: skip PUSH_IDLE when the link was never enabled
ea9dadeac79c drm/msm: mark the fbdev framebuffer as system memory
ba970587a0e1 drm/msm/a6xx+: Increase GMU FW init timeout
a2b65837980a drm/msm/a6xx: Use CX AO Counter register for timestamp on a750 GPUs
ed9ad3d41830 drm/msm/a6xx: Add CX AO Counter registers used for a750 GPUs
3163cd725343 drm/msm: remove stale perf counter XML TODO
01c8d1f385f7 drm/msm: RCU-free the scheduler-containing ring and VM objects
8061ee61b942 drm/msm/adreno: Fix the skip_gpu parameter description
adf596733131 drm/msm: Fix the separate_gpu_kms parameter description
b7c0f8436f07 drm/msm/adreno: Only check for PAS when a zap shader is present
```
drivers/gpu/drm/msm/dsi：**只有** `2028280686f4`（byte clock，见 Q2c）。
drivers/gpu/drm/msm/dpu：**0 条**。

**"回归"性质的两条线索**：

1. **7.3-rc 前修掉的 DSI 回归（bonded PLL）**：commit **44784327815b** "Revert \"drm/msm: dsi: fix PLL init in bonded mode\""（作者日期 2026-07-12）在 **v7.2 内不存在、v7.3-rc1 已存在**（实测：v7.2 的 `dsi_phy_7nm.c` 含 `pll_enable_cnt++;`，v7.3-rc1 已换成 `if (pll->pll_enable_cnt++)` 早退）。即 **v7.3-rc 系列已含该 revert**。详见 Q2b。
   ```
   $ GET .../plain/drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c?h=v7.2
   v7.2  has early-return-revert-state: False has pll_enable_cnt++;: True
   $ GET ...?h=v7.3-rc1
   v7.3-rc1 has early-return-revert-state: True has pll_enable_cnt++;: False
   ```
2. **v7.3-rc 窗口内的 DSI 修复**：byte clock 修复 `2028280686f4`（v7.3-rc3 → **v7.3-rc4** 落地，实测 `byte_intf_clk_div_2` 计数 rc3=1、rc4=4），修的是 `6cd33b6f4155`（"round 6G byte clock rate to the PLL-achievable value"）引入的"把错误 byte 速率塞进 PHY bit clock 请求 → PLL 编到错频 → 面板坏"。**这是与"SM8750/SM8650 面板点不亮"最贴的一条上游修复。**

**上游对"dual-DSI/DSC 面板"的官方口径（邮件）**：Pengyu Luo（NT36536 panel 上游作者、Y700 Gen4 DT 作者）在 [REPORT] 回复中明确：
> In a word, the panel driver is supported, the DPU may not be.
> most drivers for dual dsi dual dsc panels in the upstream are alright, but they may still not work due to the DPU ... we need to hack the dsi clk source select for the 10-bit CPHY plane, etc.
URL：https://lore.kernel.org/all/CAH2e8h6_pACX_j8YBDhhSZzbfs45waF-Y6KJo82_2c6BT0suEg@mail.gmail.com/

他的 Y700 Gen4 DT 补丁 changelog 也把 DPU 写成已知损坏：
> Framebuffer (Require mdss and dispcc to be disabled)
> Downstream supported features: - Display (8/10 bits) (Nowadays DPU driver is broken for dual dsi panel)
URL：https://lore.kernel.org/all/20260726143048.130116-3-mitltlatltl@gmail.com/

## Q2. 具体补丁/系列的确切内容与状态

### Q2a SM8750 DSI PHY 供电 ("sm8750 add phy supply", mtp/qrd dts)

**先说负面实测结论**：截至本轮检索，**上游 SoC 级 `sm8750.dtsi` 的 DSI PHY 节点没有任何供电属性**；没有找到标题/正文为"sm8750: add phy supply"的独立上游补丁。

实测（cgit plain，master 与 v7.3-rc7）：
```
$ GET .../plain/arch/arm64/boot/dts/qcom/sm8750.dtsi?h=master
mdss_dsi0_phy: phy@ae95000 {
        compatible = "qcom,sm8750-dsi-phy-3nm";
        reg = ..., reg-names = "dsi_phy","dsi_phy_lane","dsi_pll";
        clocks = <&dispcc DISP_CC_MDSS_AHB_CLK>, <&bi_tcxo_div2>;
        clock-names = "iface","ref";
        #clock-cells = <1>; #phy-cells = <0>;
        status = "disabled";
};          <-- 无 vdda/vdds/vddio-supply
sm8750.dtsi supply count: 0 | vdda count: 0
```
（v7.3-rc7 的节点内容与 master **完全相同**。）

**真正存在、且与"供电"相关的上游/公开补丁（按相关度）**：

1. **[PATCH v3] arm64: dts: qcom: sm8750-mtp: Set sufficient voltage for panel nt37801**（Ayushi Makhija / 转发 Arpit Saini，2026-10-07）
   URL：https://lore.kernel.org/all/20261007-resend-upstream-attention-v3-1-c2af21b3def4@oss.qualcomm.com/
   原文引用：
   > The NT37801 Sepc V1.0 chapter "5.7.1 Power On Sequence" states VDDI=1.65V~1.95V, so set sufficient voltage for panel nt37801.
   > Fixes: 4fca6849864d ("drm/panel: Add Novatek NT37801 panel driver")
   diff（`sm8750-mtp.dts`）：`vreg_l12b_1p8` 的 `regulator-min-microvolt` 由 `1200000` → `1650000`。
   状态：**已 Reviewed-by: Dmitry Baryshkov / Konrad Dybcio**（mtp 板，panel VDDI）。
2. **Manivannan Sadhasivam, [PATCH 00/28] arm64: dts: qcom: Fix swapped QMP PHY vdda-phy/vdda-pll supplies**（2026-08-03，含 [PATCH 21/28] sm8750）
   URL：https://lore.kernel.org/all/20260803-phy-supply-fix-v1-0-5880630cde3e@oss.qualcomm.com/ , https://lore.kernel.org/all/20260803-phy-supply-fix-v1-21-5880630cde3e@oss.qualcomm.com/
   注：这是 **USB QMP PHY** 的 vdda-phy/vdda-pll 交换修正，**不是 DSI PHY**；已 backport 到 7.2.6（lore 20260912065714.445192977@linuxfoundation.org）。
3. **Pengyu Luo, [PATCH v2 2/2] arm64: dts: qcom: sm8750: Add Lenovo Legion Y700 Gen4**（2026-07-26）
   URL：https://lore.kernel.org/all/20260726143048.130116-3-mitltlatltl@gmail.com/
   板级 dts **确实给 DSI 供电属性**，且是**写在板 dts 而不是 SoC dtsi**：
   ```
   +&mdss_dsi0 { vdda-supply = <&vreg_l3g_1p2>; qcom,dual-dsi-mode; qcom,sync-dual-dsi; qcom,master-dsi; status="okay"; };
   +&mdss_dsi1 { vdda-supply = <&vreg_l3g_1p2>; ... };      /* DSI controller 的 vdda */
   +&mdss_dsi1_phy { vdds-supply = <&vreg_l3i_0p88>; phy-type = <PHY_TYPE_CPHY>; status="okay"; };   /* DSI PHY 供电 */
   ```
   ⇒ 说明**SM8750 DSI PHY 的供电走板级 `vdds-supply`，SoC dtsi 故意留空**。若 M1/上游树用了这个板 dts 却"缺 phy supply"，应核对 `&mdss_dsi1_phy` 的 `vdds-supply` 是否被保留。
   （该补丁 changelog 同时写明 "DPU driver is broken for dual dsi panel"，见 Q1。）

### Q2b dsi_phy_7nm.c PLL enable 计数重构

**结论**：这一"计数重构"来自 bonded-mode PLL 修复 **93c97bc8d85d ("drm/msm: dsi: fix PLL init in bonded mode")**，随后被 **Dmitry Baryshkov 于 2026-07-12 提交 revert**（因为把非 bonded 用例的时钟分频器program错、选错 display mode，报告人 Mohit Dsor）。

- URL（revert 补丁）：https://lore.kernel.org/all/20260712-msm-revert-dsi-pll-fix-v1-1-40122689ea25@oss.qualcomm.com/
- 原文引用（commit message）：
  > Commit 93c97bc8d85d ("drm/msm: dsi: fix PLL init in bonded mode") fixed one of the issues with the DSI bonded mode, but broke non-bonded usecase for DSI as reported by Mohit Dsor. Clock divider is being programmed incorrectly, resultin in the wrong display mode being selected. Revert the offending commit, letting Neil to work on a better fix.
  > Fixes: 93c97bc8d85d ("drm/msm: dsi: fix PLL init in bonded mode")
- revert 后的代码形态（即被恢复的旧式逻辑，**与 M1 树现状描述一致**），原文 diff：
  ```
  -	pll->pll_enable_cnt++;
  -	WARN_ON(pll->pll_enable_cnt == INT_MAX);
  +	if (pll->pll_enable_cnt++) {
  +		spin_unlock_irqrestore(&pll->pll_enable_lock, flags);
  +		WARN_ON(pll->pll_enable_cnt == INT_MAX);
  +		return;
  +	}
  ```
  并在 `dsi_7nm_phy_enable()` 中 `pll->pll_enable_cnt = 1;`、`dsi_7nm_phy_disable()` 中 `pll->pll_enable_cnt = 0;`，同时新增 `phy->pll_data = pll_7nm;`。
  （文件：`drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c`、`dsi_phy.h`）
- **与 M1 的关系（已用 git 核对）**：M1 树"已使能即提前返回 + enable_cnt=1"= revert 之后的形态；实测主线 **v7.3-rc7 的 `dsi_phy_7nm.c` 正是该形态**（`if (pll->pll_enable_cnt++)` 早退、`pll_enable_cnt = 1/0`），而 v7.2 是纯自增。⇒ **M1 树的 PLL 计数逻辑与 v7.3-rc7 主线一致，不是重基私货**。
  ```
  $ GET .../plain/drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c?h=v7.3-rc7
  spin_lock_irqsave(&pll->pll_enable_lock, flags);
  if (pll->pll_enable_cnt++) { ... return; }
  ...
  pll->pll_enable_cnt = 1;   /* dsi_7nm_phy_enable */
  pll->pll_enable_cnt = 0;   /* dsi_7nm_phy_disable */
  ```

### Q2c byte_intf_clk_div_2 / byte_intf_clk rate 相关补丁

**结论**：确切补丁 = **"drm/msm/dsi: round the byte clock rate after reparenting to the PHY PLL"**（Dmitry Baryshkov, 2026-09-03），mainline commit **2028280686f4**，Fixes **6cd33b6f4155 ("drm/msm/dsi: round 6G byte clock rate to the PLL-achievable value")**。

- URL（原补丁）：https://lore.kernel.org/all/20260903-fix-eliza-dsi-v1-1-3474a6c9f2e0@oss.qualcomm.com/
- 原文引用（commit message）：
  > DSI 6G v2.9 hosts (SM8650, SM8750, Kaanapali, etc.) reparent the byte and pixel RCGs to the DSI PHY PLL at runtime from dsi_link_clk_set_rate_6g_v2_9(), after the PHY has been enabled. However dsi_calc_clk_rate_6g() runs earlier, in order to compute the bit clock request for the PHY. At that point the byte RCG still has its reset parent (XO), so clk_round_rate() returns a bogus rate, which then ends up in the PHY bit clock request and the PLL gets programmed to a wrong frequency, breaking the panel.
  > ... Derive the byte interface clock rate from the rounded byte clock rate, otherwise it would keep requesting the idealized rate and retrigger the PLL on every transfer.
- 代码改动（原文 diff）：`struct msm_dsi_host` 里 `unsigned long byte_intf_clk_rate` → `bool byte_intf_clk_div_2`；把 `clk_round_rate(byte_clk)` 从 `dsi_calc_clk_rate_6g()` 移到 `dsi_link_clk_set_rate_6g()` 开头；byte_intf 速率由 round 后的 byte rate 派生：
  ```
  +	if (msm_host->byte_intf_clk_div_2)
  +		byte_intf_clk_rate /= 2;
  ```
- **stable 回归范围**：该补丁已进 stable。lore 抽查：
  - 7.2 分支：[PATCH 7.2 153/438]，https://lore.kernel.org/all/20260923140648.736242442@linuxfoundation.org/ （2026-09-23），对应 **Linux 7.2.8**（2026-09-25，https://lore.kernel.org/all/2026092502-yippee-sedation-7579@gregkh/）
  - 6.18：[PATCH 6.18 127/398] .../20260923140646.729486104@linuxfoundation.org/ → Linux 6.18.54
  - 6.12：[PATCH 6.12 118/877] .../20260930152417.282565847@linuxfoundation.org/
  - 6.6 / 6.1 / 5.15 亦有（.../20260930152451.885806406、20260930152431.069784328、20260930152408.912807068）
- **对本项目最相关**：Qianhui Xu 已在 [REPORT] 里说明"ported to this tree with upstream semantics ... byte-intf rate from byte_intf_clk_div_2. First cold boot still fails with the identical signature" ⇒ 该补丁**不能解释** 7.3-rc7 M1 树"只有背光"这一稳定态（它解释的是首条 DCS 超时的冷启动间歇问题）。

### Q2d 7.2.5–7.2.8 stable 里的 DSI/DPU/Adreno 稳定性补丁

**注意**：cgit 的 `?qt=range` 查询**必须带 `h=<tag>`**，否则会被静默忽略而返回 master 上的近期提交（本轮踩过）。下面用 stable/linux.git 逐个 stable tag 核对，并以具体补丁 mail 佐证。

命令：
```
GET https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/log/drivers/gpu/drm/msm?h=v7.2.8&qt=range&q=v7.2.5..v7.2.8
```
原始输出（stable/linux.git, `drivers/gpu/drm/msm` @v7.2.8 区间，节选）：
```
713abac5c04c drm/msm: RCU-free the scheduler-containing ring and VM objects
ad4fd6cfac9d drm/msm/hdmi_phy: fix runtime PM cleanup on probe failure
fd25668f96ff drm/msm/dpu: clear pending peripheral flush state
ebc273b45d58 drm/msm/adreno: fix autosuspend cleanup during teardown
c59e4a90780f drm/msm/dsi: round the byte clock rate after reparenting to the PHY PLL
4483604a4fd6 drm/msm/dp: fix link bandwidth check when wide bus is enabled
5e97d117b79c drm/msm/dp: skip PUSH_IDLE when the link was never enabled
00008e6f544c drm/msm/dsi: Drop dev_pm_opp_set_rate(0)
e532b800728d drm/msm/dp: Drop dev_pm_opp_set_rate(0)
54b17a858b8b drm/msm/dpu: Drop sneaky dev_pm_opp_set_rate(0)
e2a99fa93b40 drm/msm: don't tear down KMS twice when KMS init fails
0f00f6848f6b drm/msm/dpu: Fix DMA SSPP REC block offsets on DPU v13
8a61c211d0d5 drm/msm: remove objects from evit list after pinning them
9d7355c6040c drm/msm/a6xx: Fix RBBM_CLOCK_CNTL3_TP0 value in a730_hwcg
09b360eb6ce3 drm/msm: Only fini scheduler after successful init
d684f756d029 drm/msm: Fix task_struct reference leak in recover_worker
8fc6a356f498 drm/msm/a6xx: Fix IRQ storm during msm_recovery test
197912ffbb65 drm/msm/a6xx: Fix A621 GPUCC register list for state capture
9d52bfc956c7 drm/msm/a6xx: Fix A663 GPUCC register list for state capture
dc64cf9d7142 drm/msm: Recover HW before retire hung submit
51fcee9d4140 drm/msm/a6xx: Fix stale rpmh votes after suspend
105aaff286a1 drm/msm/adreno: fix use after free on error path in a6xx_gpu_init()
5de981b7db1f Revert "drm/msm: dsi: fix PLL init in bonded mode"
96379c2dec72 drm/msm/dp: add missing drm_edid_connector_update() before add_modes on cache...
```
按类别：
- **DSI**：`round the byte clock rate after reparenting to the PHY PLL`（7.2.8，见 Q2c）、`dsi: Drop dev_pm_opp_set_rate(0)`、`Revert "drm/msm: dsi: fix PLL init in bonded mode"`（进 7.2 stable 系列）。
- **DPU**：`clear pending peripheral flush state`、`Drop sneaky dev_pm_opp_set_rate(0)`、`Fix DMA SSPP REC block offsets on DPU v13`。
- **Adreno/GPU**：`fix autosuspend cleanup during teardown`、`a6xx: Fix IRQ storm during msm_recovery test`、`a6xx: Fix stale rpmh votes after suspend`、`adreno: fix use after free on error path in a6xx_gpu_init()`、`a6xx: Fix A621/A663 GPUCC register list for state capture`、`RCU-free the scheduler-containing ring and VM objects`。
- **DP**：`fix link bandwidth check when wide bus is enabled`、`skip PUSH_IDLE when the link was never enabled`、`Drop dev_pm_opp_set_rate(0)`、`do not reject wide-bus modes while a YUV420 mode is active`、`reject YUV420-only modes without VSC SDP support`。

**stable 补丁 mail 佐证（lore）**：
- 7.2.8（Linux 7.2.8, 2026-09-25）：https://lore.kernel.org/all/2026092502-yippee-sedation-7579@gregkh/ ，其 byte clock backport mail：[PATCH 7.2 153/438] https://lore.kernel.org/all/20260923140648.736242442@linuxfoundation.org/
- 7.2.6-rc：https://lore.kernel.org/all/20260912065648.999753832@linuxfoundation.org/
- 7.2.5-rc：https://lore.kernel.org/all/20260909134230.441546314@linuxfoundation.org/
（7.2.7 的公告未在检索窗口内单独命中；上面以 diff range 为准。）

## Q3. lore.kernel.org 检索

### Q3a "sm8750" + (dsi|dpu|phy) 近期帖子

检索方式：`https://lore.kernel.org/all/?q=<terms>&x=A`（Atom；站点有 Anubis PoW 反爬，本轮已解并保留 cookie）。命令与原始输出见文末附录。

**最相关的一条长线程（2026-10-12 起）**：

- 原帖：[REPORT] SM8750 bonded dual-DSI + NT36536: first DCS command-DMA timeout on cold boot (DMA engine busy)
  URL：https://lore.kernel.org/all/179184923104.248043.14168731037113716140@mail.ustc.edu.cn/ （Xu Qianhui, 2026-10-12, linux-arm-msm）
  原文引用：
  > On a *cold* boot ... the very first DCS command of the panel init intermittently times out and the panel is never enabled.
  > Uppercase register: `command DMA timeout: status=0x2200200` ... "registers before the first command are byte-identical to those of a good boot."
  > Upstream 2028280686f4 ("round the byte clock rate after reparenting to the PHY PLL"): ported to this tree ... First cold boot still fails with the identical signature.
- 回复 1：Pengyu Luo, 2026-10-13, https://lore.kernel.org/all/CAH2e8h6_pACX_j8YBDhhSZzbfs45waF-Y6KJo82_2c6BT0suEg@mail.gmail.com/
  原文引用（**关键**）：
  > In a word, the panel driver is supported, the DPU may not be.
  > I think most drivers for dual dsi dual dsc panels in the upstream are alright, but they may still not work due to the DPU. Once I upstreamed partial patches, but it is not enough, we need more, like we need to hack the dsi clk source select for the 10-bit CPHY plane, etc.
  > You can find some threads in LKML about 10bpc 10bpp support on DPU discussions that I was involved in...
- 回复 2：Pengyu Luo, 2026-10-13, https://lore.kernel.org/all/CAH2e8h7H5-DzTj1zwejYQyNNtupurgzYq4t6gKPZoZw=7EQvrA@mail.gmail.com/

**其它 sm8750 dpu/dsi 近期帖子（同期窗口）**：

| 日期 | 作者 | 标题 | URL |
|---|---|---|---|
| 2026-10-13 | Qianhui Xu | [PATCH] drm/msm/dpu: add the missing GC block to the SM8750 DSPP catalog | https://lore.kernel.org/all/20261013002124.332074-1-xiaqinghuan@mail.ustc.edu.cn/ |
| 2026-10-13 | Qianhui Xu | [PATCH] drm/msm/dpu: reject undersized gamma LUT blobs | https://lore.kernel.org/all/20261013020425.408928-1-xiaqinghuan@mail.ustc.edu.cn/ |
| 2026-10-12 | Qianhui Xu | [Regression v3] SM8750: cambistmclkcc + camcc together hard-reset the SoC on display blank | https://lore.kernel.org/all/179179331695.677917.11557670447411700010@mail.ustc.edu.cn/ |
| 2026-10-08 | Zhang Jiaxi | [RFC PATCH 0/3] drm/msm: correct DSC RGB and command-mode vblank handling | https://lore.kernel.org/all/SY5PR01MB1060041363FC41A7F40DF59DBA1932@SY5PR01MB10600.ausprd01.prod.outlook.com/ |
| 2026-09-30 | Robin Clark | [PATCH] drm/msm/dpu: Fix GAMMA LUT for sm8750 related DPUs | https://lore.kernel.org/all/20260930152645.22194-1-robin.clark@oss.qualcomm.com/ |
| 2026-07-12 | Dmitry Baryshkov | [PATCH] Revert "drm/msm: dsi: fix PLL init in bonded mode" | https://lore.kernel.org/all/20260712-msm-revert-dsi-pll-fix-v1-1-40122689ea25@oss.qualcomm.com/ |

### Q3b NT36536 (novatek nt36536) panel DSC 1.2 讨论

**结论**：NT36536 面板驱动**已上游**，且 DSC 1.2 参数就写在驱动里（默认配置 = Y700 Gen4 的 CSOT PP8807HB1-1，10-bit，dual-link）。

1. **[PATCH v3 2/2] drm/panel: Add Novatek NT36536 panel driver**（Pengyu Luo, 2026-07-09）
   URL：https://lore.kernel.org/all/20260709142846.12463-3-mitltlatltl@gmail.com/
   原文引用：
   > Add a driver for panels using the Novatek NT36536 Display Driver IC, including support for the CSOT PP8807HB1-1, a dual-link 10-bit panel found in LENOVO Legion Y700 Gen4.
   > Reviewed-by: Neil Armstrong <neil.armstrong@linaro.org>
   驱动里的 DSC 参数（原文 diff 摘录，`panel-novatek-nt36536.c`）：
   ```
   +static struct drm_dsc_config csot_pp8807hb1_1_dsc_cfg = {
   +       .dsc_version_major = 1,
   +       .dsc_version_minor = 2,
   +       .slice_height = 20,
   +       .slice_width = 476,
   +       .slice_count = 2,
   +       .bits_per_component = 10,
   +       .bits_per_pixel = 8 << 4,
   ...
   +      MIPI_DSI_MODE_LPM | MIPI_DSI_MODE_DSC_ALL_SLICES_IN_PKT,
   ```
   ⇒ **DSC 1.2 是上游面板驱动的既定配置**（version_minor=2, 8bpp@10bpc, 2 slices/link）；本项目 P4a 用 vendor DSC1.2 参数"无差别"这一实测与该上游参数并不矛盾——**缺口不在这几个 PPS 参数**。
2. **[PATCH] drm/panel: fix novatek-nt36536 dependencies**（Arnd Bergmann, 2026-09-25）
   URL：https://lore.kernel.org/all/20260925130125.3897046-1-arnd@kernel.org/
   原文引用：
   > The recently added driver requires access to DSC helper code and fails to link without that: undefined symbol: drm_dsc_pps_payload_pack
   > Fixes: 75a5dbd1f4f7 ("drm/panel: Add Novatek NT36536 panel driver")
   diff：`config DRM_PANEL_NOVATEK_NT36536` 增加 `select DRM_DISPLAY_DSC_HELPER` + `select DRM_DISPLAY_HELPER`（已被 b4 收，见 179093258520.2282096...b4-ty@b4/）。
3. **DSC video-mode INTF 宽度讨论（与 NT36536 直接相关）**：见 Q4 的 `round up the compressed INTF width` 系列——Pengyu Luo 在回复里点名 **Y700 gen4 面板需要 round-up**，且 gaokun(MateBook E Go, 800*2) 同样。
4. 同窗口还有 `[PATCH] drm/panel: novatek-nt36536: Fix panel double-remove on attach failure`（David Carlier, 2026-07-24）https://lore.kernel.org/all/20260724041746.12887-1-devnexen@gmail.com/ （Pengyu 有回复）。

## Q4. "modeset 成功但只有背光/无内容" 在 qcom DSI(C-PHY, bonded dual-DSI, DSC) 上的成因与排查法

**结论**：**有**，而且是本窗口正在被修的活跃话题。公开归因为两类，都是 **DPU↔DSI 的宽度/时序握手**问题，而不是背光或面板本身：
(A) **INTF 压缩宽度取整方向不一致 → DSI FIFO 溢出**（画面无/断续、无 vblank、DSI FIFO err 中断暴涨）；
(B) **bonded/split display 下主从 encoder 关闭顺序错 → 共享 CTL 被提前复位 → source pipe 卡死**。

### A. INTF 压缩宽度 round-up（直接对应"点不亮/无内容"）

- **[PATCH] drm/msm/dpu: round up the compressed INTF width**（Joonhoe Kim, 2026-10-04）
  URL：https://lore.kernel.org/all/20261004102758.84436-1-26rote@gmail.com/
  原文引用（commit message）：
  > For DSI with DSC, drm_mode_to_intf_timing_params() scales the INTF active width by bpp / (3 * bits_per_component) and rounds down. The DSI host computes the same width with DIV_ROUND_UP ... When the division is not exact the INTF line is one pclk shorter than the DSI line, and **the DSI FIFO overflows**.
  > Example: a bonded DSI video-mode panel, 952 pixels per link, DSC 8 bpp at 10 bpc: 952 * 8 / 30 = 253.87, so the INTF uses 253 and the DSI 254.
  > **Tested on a Lenovo Legion Tab Y700 gen 5 (SM8850) with that panel** ... rounding down, DPMS off/on gives no vblank and 14000-17000 DSI FIFO error interrupts per second (dsi_err_worker: status=4); rounding up, the picture comes back and there are no errors.
  > Fixes: f9ce482d7dc0 ("drm/msm/dpu: fix video mode DSC for DSI")
  diff：`dpu_encoder_phys_vid.c` 的 `timing->width = timing->width * drm_dsc_get_bpp_int(dsc) / (dsc->bits_per_component * 3)` → `DIV_ROUND_UP(...)`。
- **Pengyu Luo 的 Review（2026-10-04）**：https://lore.kernel.org/all/CAH2e8h6RPMF+Tod==XKjAbjmnzUKs1skCpvN7_YuGyao9m2baA@mail.gmail.com/
  原文引用：
  > For most tablets, the horizontal pixel count is not divisible by 3, so rounding up is necessary for them. Besides lenovo Y700 gen4, rounding up also helps dsc display on gaokun (800 * 2), whose patch was initially provided by White Lewis
  > Reviewed-by: Pengyu Luo <mitltlatltl@gmail.com>
  ⇒ **Y700 gen4（本机同型面板）被点名需要这个 round-up**。**实测排查法**：看 `dsi_err_worker: status=4` 之类 DSI FIFO 中断计数、`vblank wait timed out`；若 INTF/DSI 宽度差 1 会表现为"合成正常、面板无内容"。

### B. bonded/split display 的主从 encoder 关闭/复位顺序

- **[PATCH v3] drm/msm/dpu: disable the slave encoder before the master**（Joonhoe Kim），**已 Applied to msm-next**（Dmitry, 2026-10-06）
  URL：https://lore.kernel.org/all/179126968609.1110179.6720784693254574991.b4-ty@b4/ （commit https://gitlab.freedesktop.org/lumag/msm/-/commit/32d04280ddeb）
  原文引用（被引用的原 patch 描述）：
  > dpu_encoder_virt_atomic_disable() disables the physical encoders in phys_encs[] order, i.e. the master first. With a split display (two interfaces on one CTL, e.g. bonded DSI) the master's dpu_encoder_helper_phys_cleanup() then resets the shared CTL while the slave's timing engine is still running, and the source pipe is left stalled half-way through the slave's next frame.

### C. 更上层的"数据通路宽度/时钟源"已知缺口（Pengyu Luo 指路）

- Pengyu 在 [REPORT] 回复中（Q1 已引）说：dual-DSI dual-DSC 面板"面板驱动 OK，DPU 可能不行"，缺的东西包括 **"hack the dsi clk source select for the 10-bit CPHY plane"**，并指向 DPU 10bpc/10bpp 讨论线。
- 相关仍在讨论的补丁：
  - **[PATCH RFC/v2] drm/msm/dpu: calculate data_width like downstream**（Alexander Koskovich, 2026-03-22）https://lore.kernel.org/all/20260322-fix-data-width-calc-v2-1-d5f28136bc4e@pm.me/ —— 按 `dce_bytes_per_line` 推 INTF `data_width`，处理 widebus+compression 的"数据有效窗口"。
  - **drm/msm/dpu: fix video mode DSC INTF timing width calculation**（Pengyu Luo / Alexander Koskovich 长线程，2026-03-20/21）——核心论断："INTF (which feeds DSI) is after DSC compression. INTF timings are always in RGB888 (24-bit) units ... the INTF timing should match what is programmed on the DSI side"。
  - **[PATCH v5 0/6] Add support to 2 panels in bonded-DSI mode**（Jun Nie, 2026-07-27）https://lore.kernel.org/all/20260727-sm8650-7-1-bonded-dsi-v5-0-c042266b9eeb@linaro.org/ 及其 `mipi_dsi_device.dual_panel` 标志 https://lore.kernel.org/all/20260727-sm8650-7-1-bonded-dsi-v5-3-c042266b9eeb@linaro.org/ —— 面向"两块独立面板在 bonded-DSI 下当一块逻辑面板"。

### D. 本项目自己的公开记录（同一症状）
[REPORT]（Q3a）就是"card0 在、DSI-1 connected、只有背光"这一症状的公开描述；两个回复都指向 DPU 侧而非面板/DSI 控制器侧。
注意区分：本项目 M1 7.3-rc7 的现象是 **`dsi_isr`=0**（连视频时序都没跑），而 A 类公开案例是"DSI 在跑但 FIFO 溢出/无 vblank"（dsi_isr 会动、有 FIFO err）。⇒ 公开资料能解释"背光但无内容"的一大类成因，但**不能直接解释 dsi_isr=0**；后者更可能是 video 未真正启动（时钟/widebus/DSC 使能握手）而非宽度取整。

## 附：检索方法与原始输出

### 工具可用性（实测）
- `fabric_exec` 里 **`extensions.web_search` / `extensions.web_fetch` / `extensions.agent_browser` 均报 "Unknown Fabric action"**（本会话未注册），`tools.list` 里也没有 web provider。⇒ 退化为 **host 侧 curl/python**（符合"只做主机侧"）。
- 外网：主机有本地代理 `http://127.0.0.1:7897`。`lore.kernel.org` / `git.kernel.org` 走直连（`--noproxy '*'`）反而更快。
- **lore 与 git.kernel.org 都开了 Anubis 反爬（PoW）**：裸 curl 只拿到 `Making sure you're not a bot!` 挑战页（HTTP 200/500 + `set-cookie: techaro.lol-anubis-auth=`）。本轮用 python 解 Anubis PoW（sha256(randomData+nonce) 找 difficulty 个前导 0，再 GET `/.within.website/x/cmd/anubis/api/pass-challenge?id=..&response=..&nonce=..&redir=..&elapsedTime=..`），按 host 持久化 cookie 后，lore 与 cgit 均正常。脚本：`/tmp/lore/net.py`、`/tmp/lore/lore.py`（临时文件，不在仓库内）。
- 通用搜索引擎（Google/Bing/DDG/Brave/Qwant）经代理**均不可用**（超时/Anubis/返回无关缓存页），故本轮检索以 **lore + git.kernel.org（cgit）** 两个一手源为准，未依赖二手搜索摘要。

### 复现命令
```bash
# lore 全文搜索（Atom），返回 日期|作者|标题|URL
python3 /tmp/lore/lore.py s 'sm8750 dsi' 'byte_intf_clk_div_2' 'nt36536 dsc' ...
# 取原始邮件正文
curl --noproxy '*' -sS -A 'Mozilla/5.0' -b /tmp/lore/cj.txt \
     https://lore.kernel.org/all/<msgid>/raw
# cgit 单文件历史 / tag 内容（range 查询必须带 h=<tag>）
GET https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/<path>?h=v7.3-rc7&qt=range&q=v7.3-rc1..v7.3-rc7
GET https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/<path>?h=v7.3-rc7
GET https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/log/drivers/gpu/drm/msm?h=v7.2.8&qt=range&q=v7.2.5..v7.2.8
```

### 关键 commit 摘要表（一手核对）
| commit | 主题 | 落地 |
|---|---|---|
| 44784327815b | Revert "drm/msm: dsi: fix PLL init in bonded mode" | v7.2 无 / v7.3-rc1 有 |
| 93c97bc8d85d | drm/msm: dsi: fix PLL init in bonded mode | 7.2 周期，已被 revert |
| 6cd33b6f4155 | drm/msm/dsi: round 6G byte clock rate to the PLL-achievable value | 引入问题的补丁 |
| 2028280686f4 | drm/msm/dsi: round the byte clock rate after reparenting to the PHY PLL | **v7.3-rc4**；backport 7.2.8 等 |
| 5de981b7db1f | Revert "drm/msm: dsi: fix PLL init in bonded mode" | stable 7.2.x 对应 commit |
| a5b5cc909931 | drm/msm/dpu: clear pending peripheral flush state | v7.3-rc1..rc7 |
| 6fbbf1e152f3 | drm/msm/adreno: fix autosuspend cleanup during teardown | v7.3-rc1..rc7 |
| ba970587a0e1 | drm/msm/a6xx+: Increase GMU FW init timeout | v7.3-rc1..rc7 |
| 32d04280ddeb | drm/msm/dpu: disable the slave encoder before the master | msm-next（2026-10-06） |
| 75a5dbd1f4f7 | drm/panel: Add Novatek NT36536 panel driver | 已上游（DSC1.2 配置） |

### 与 M1 回归的关系（本轮检索能/不能回答的）
- **能**：M1 7.3-rc7 里两项"候选差异"——`dsi_phy_7nm.c` 的 PLL enable 计数早退、`dsi_host.c` 的 `byte_intf_clk_div_2`——**实测都与主线 v7.3-rc7 一致**，不是重基引入的私货（详见 Q2b/Q2c）。
- **不能**：公开资料没有"7.3-rc7 导致 SM8750 面板只有背光"的现成结论；能解释"背光无内容"的公开成因（INTF round-up、slave encoder 顺序、data_width/widebus）都要么已在上游/msm-next、要么仍 RFC。M1 树 `dsi_isr=0` 这一具体现象仍属未公开个案。
- **待办（设备侧，非本轮）**：在 M1 树核对是否缺 `DIV_ROUND_UP` 版 INTF 宽度（若 M1 从 7.2 重基，7.2 无该修复）、以及 DPU slave-encoder 关闭顺序。
