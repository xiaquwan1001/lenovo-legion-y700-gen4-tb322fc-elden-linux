# M1 显示回归：根因分析与下一步实验（2026-10-14，编排者自做最终分析）

> 输入：本日实测（`reports/m1-73-display-regression-20261014.md`）+ 三条 lane 报告（`reports/lanes/20261014-{m1-display-audit,m1-web-research,upstream-replies}.md`，均为子代理产出，**关键论断已由编排者独立复核**）+ 上游回信。
> 结论分级：**已实测确认** / **强候选（有静态+旁证，未上机验证）** / **待查**。

## 0. 已实测确认的事实

1. **同一窗口**：日常 `vk94`（7.2 血统 `linux/` 树）面板出桌面；M1 7.3-rc7 树（`m1-73j`）"L1=L2=0、phoc/phosh 在、CRTC active、grim 出图 39965 B"但**面板只有背光** ⇒ **M1 树显示回归**（非 Q28、非粘态、非面板故障）。
2. 上游臂（P2b/P2c/P4a/P4d，上游 DSI host）额外：phoc `no supported format`（modeset 失败）；强制 `modetest` modeset 后**面板仍黑**且 `dsi_isr=0`。**DIAG 探针**证明 `dsi_mgr_bridge_enable`/`msm_dsi_host_enable` 都被调用、`DSI_CTRL 0x171→0x173`（`VID_MODE_EN` 置位）⇒ 缺口在"video 真正跑起来"的条件，不在 enable 是否被调用。
3. **DSC 1.2 已否证**：P4a = P2c + vendor DSC1.2（RC 参数 + `first_line_bpg_offset`），行为与 P2c 无差别。
4. 静态审计：两树显示域差异**全部可归属**（上游 7.2→7.3 演进 / vendor payload），**未发现 rebase 解冲突错误**；`dsi_cfg.c`、`dsi.c`、`dsi_phy.c`、`msm_mdss.c`、`msm_kms.c`、`dpu_kms.c`、`dpu_encoder_phys_vid.c`、`dispcc-sm8750.c`、两树 .config 显示项、DTS 显示节点 = **零差异**。

## 1. 强候选（按优先级）

### H1 ★ DSI PHY 的 bonded PLL 初始化修复在 7.3 被上游 revert —— elden 正是 bonded 双 DSI

本地 diff（编排者实测：`diff -u <7.2 的 phy> <7.3-rc7 的 phy>`）：

```diff
 static void dsi_pll_enable_pll_bias(struct dsi_pll_7nm *pll)
 {
   spin_lock_irqsave(&pll->pll_enable_lock, flags);
-  pll->pll_enable_cnt++;
-  WARN_ON(pll->pll_enable_cnt == INT_MAX);
+  if (pll->pll_enable_cnt++) {
+      spin_unlock_irqrestore(&pll->pll_enable_lock, flags);
+      WARN_ON(pll->pll_enable_cnt == INT_MAX);
+      return;                       /* ← 首次调用即早退：PLL_SHUTDOWNB / SYSTEM_MUXES=0xc0 都不写 */
+  }
   数据写入 REG_DSI_7nm_PHY_CMN_CTRL_0 (PLL_SHUTDOWNB) 与 REG_DSI_7nm_PHY_PLL_SYSTEM_MUXES = 0xc0
 ...
 dsi_7nm_phy_enable():  + pll->pll_enable_cnt = 1;   /* ← 预置 1，使上面的早退必然命中 */
 dsi_7nm_phy_disable(): + pll->pll_enable_cnt = 0;
```

- **来源**：web lane 用 lore 定位到 `93c97bc8d85d ("drm/msm: dsi: fix PLL init in bonded mode")`，其后被 Dmitry Baryshkov **revert**（`44784327815b`，2026-07-12，理由：该修复**破坏了非 bonded** 用例——"clock divider is being programmed incorrectly, resulting in the wrong display mode"，URL https://lore.kernel.org/all/20260712-msm-revert-dsi-pll-fix-v1-1-40122689ea25@oss.qualcomm.com/ ）。**v7.3-rc1 起即为 revert 后形态**；我们的 7.2 血统 `linux/` 树仍带**修复版**（纯自增）。两个 commit 对象在本地 partial clone 中不存在（实测 `cat-file` fatal），故 lore 为外部证据，但与本地 diff **逐字一致**。
- **为什么指向 elden**：elden 是 **bonded 双 DSI + DSC**（Q28 全部工作都建立在"bonded"上）；被 revert 的恰是"bonded 模式 PLL 初始化"修复。
- **与症状吻合**：`clk_summary` 里 `dsi0vco=756.8 MHz`（clk 框架记录"速率"）但**无实际视频流**（`dsi_isr=0`、面板无内容）——与"PLL 输出 mux/初始化未按 bonded 走"一致。
- **置信度**：静态+旁证强；**机制仍待一条证据**（见 §3 E1）。注意：最终是否命中取决于 `clk_set_rate(bias)` 与 `phy_enable(预置 cnt=1)` 的调用先后——若 bias 在 phy_enable 之前跑过，则 0xc0 已写入，H1 不成立。**这正是 E1 要测的。**

### H2 byte_clk round / byte_intf_clk 速率推导（上游 `2028280686f4`，v7.3-rc4）
B 树把 byte_clk 改为 `clk_round_rate` 后再算 `byte_intf_clk`（新增 `byte_intf_clk_div_2`），而 power_on 路径存的 `byte_intf_clk_rate/link_intf_rate` 可能与之一致性检查不同步。**中**。

### H3 DP 7.3 重构 + `sync_state() pending due to displayport-controller` + `&mdss_dp0 okay`
历史上本项目就有"使能 `mdss_dp0` → 阻塞 `msm_drm_bind` → **背光亮但无显示**"的记录（`linux/` commit `08791078c8`），后与 USB role-switch 同批放开。B 树 DP 侧 392/334 行差异 + DP0 okay。**中低**（且 PITFALLS #248 已证明"DP 阻塞"在 M1 上的表现是**无 card0**，与本次"有 card0、有 modeset"不同）。

### H4 其它（低）：panel 驱动缺 Q28 init 重试（只影响坏发窗口）；DPU catalog/encoder 的 7.3 演进（不在 DSI 数据路径）。

## 2. 上游情报（已归档回信，可直接复用）

- **Q28 报告回信（Pengyu Luo，2026-10-13）**：*"the panel driver is supported, the DPU may not be … we need to hack the **dsi clk source select for the 10-bit CPHY plane**"* ⇒ 上游视角：面板驱动够用，**缺口在 DPU/时钟源选择**。这与 H1/H3 的"时钟/时钟源选择"家族同向，是本轮最有价值的外部指路。
- **Q24 RFC v3 回信（Taniya Das，Qualcomm）**：确认上游 **有** `cambistmclkcc` 的 consumer（Kaanapali camera DT overlay v21 14/14 作 MCLK provider）⇒ 相机/熄屏那条线的"上游无 consumer"前提被修正。
- M3-1（4 枚）、M2 A2/P3：已归档，**0 外部回信**（投递约 1 天，待 review）。

## 3. 下一步实验（成本从低到高，每条单变量）

**E1 ★（1 次构建 + 1 次启动）**：在 M1 树（`m1-73j` 的 config/ramdisk/DTB 口径）上**恢复 bonded PLL 初始化修复**：把 `dsi_pll_enable_pll_bias()` 改回无条件自增（即还原 `93c97bc8d85d` 的语义），并在同一内核里加 2 行 `pr_info` 打印（进入/早退/写 0xc0）——**一次启动同时拿到"机制是否命中"与"面板是否点亮"**。
- 判据：启动后先看串口/SSH dmesg 里 `pr_info`（是否发生过早退）+ `/proc/interrupts` 的 `dsi_isr` 是否开始增长；再看面板（用户目视）。
- 若点亮 ⇒ **M1 显示回归根因确认**，且该 patch 就是 M1/上游化两个方向的必修项（并可回上游，理由：elden 这类 bonded 面板需要它，而 upstream revert 的替代修复尚未落地）。

**E2（若 E1 不亮）**：byte_clk/byte_intf 单变量臂（H2）。
**E3（若 E1/E2 都不亮）**：按 Pengyu 的指路做 **DPU dsi clk source select（10-bit C-PHY plane）** 对照；同时把 DP0 单变量关掉复测（H3）。

## 4. 方法纪律（本轮踩到并已入档）

- 串口控制台（`/dev/ttyACM0`）会被设备侧 shell 刷屏**丢内核消息** ⇒ 必须 SSH `dmesg` 交叉核对（`PITFALLS #254`）。
- 显示坏态下 `reboot2` 挂 DRM cleanup → 用 **SysRq-b**（`#253`）；`arm-window-hunt.sh` 已内置两级回退。
- SSH 高频重试触发 sshd 源惩罚自锁（`#254`）⇒ 单次连接 + 退避。
- 判"屏幕点亮"**只认面板实测**（`#251/#255`）：card0/connector/CRTC/session/grim 全绿仍可能黑屏。
- 子代理产物一律由编排者复核：本轮 Top1 候选、`PLL_SYSTEM_MUXES` 写入点、7.2↔7.3 diff、`pll_enable_cnt` 语义均已独立重跑确认。
