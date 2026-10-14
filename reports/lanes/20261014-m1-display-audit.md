# M1 7.3-rc7 显示回归静态审计（2026-10-14）

> 范围：主机侧静态 diff。A = `linux/`（能点亮，vk94，tip 5b169d5418）；B = `build/m1-upstream/clean-tree-73`（点不亮，7.3-rc7，tip b3815fb150）。
> 方法：逐文件 diff 显示域，按「上游演进 / vendor payload / rebase 解冲突」分类；结论均附命令+原始输出。

## 0. 树身份确认（实测）

```
$ git -C linux log --oneline -1
5b169d5418 drm/msm: 回移 7.2.5-7.2.8 DSI/DPU/Adreno 稳定性补丁 + sm8750 参考板 PHY 供电
$ git -C linux describe --tags
vk95-3-g5b169d5418
$ git -C build/m1-upstream/clean-tree-73 log --oneline -1
b3815fb150 dts: elden: 追赶 clean/base 设备侧修复（splash_region 命名 + 去 simple-framebuffer + sdhc no-1-8-v）
```

显示域源码 diff 行数统计（diff -u | grep -c '^[+-]'，排除 .o/.cmd 产物）：

| 文件 | diff 行数 |
|---|---|
| dsi/dsi_host.c | 31 |
| dsi/dsi_manager.c | 25 |
| dsi/phy/dsi_phy_7nm.c | 20 |
| dsi/phy/dsi_phy.h | 3 |
| msm_drv.c / msm_drv.h | 32 / 19 |
| dpu1/dpu_hw_catalog.c | 14 |
| dpu1/dpu_encoder.c | 5 |
| dpu1/dpu_core_perf.c | 4 |
| panel-novatek-nt36536.c | 60 |
| dsi_cfg.c / dsi.c / dsi_phy.c / msm_mdss.c / msm_kms.c | 0 |
| clk/dispcc-sm8750.c | 0 |

sm8750.dtsi 差异 = 仅新增 uart15 节点（非显示）。elden.dts 19 行差异中 grep dsi/panel/dpu/backlight/disp 为空（实测）。两树 .config 无任何 DRM/DSI/PANEL/BACKLIGHT/MDSS 差异（实测 diff 为空）。

## 1. 候选总表（按可能性排序）

> 结构事实：B 的历史 = `24a19b953e Linux 7.3-rc7` + 单个 squash 提交 `640b0e49db elden payload: downstream v7.2-elden tree state`（git log 实测）。因此每个差异可精确归入：(1) 上游 7.2→7.3 演进（B 中 `git show 24a19b953e:<file>` 已含）或 (2) vendor payload；**未发现任何"两边都有、B 解错"的 rebase 冲突痕迹**（A↔B 差异均可在 24a19b953e 里找到来源）。

| # | 候选 | 文件:行（B 树） | 分类 | 可能性 | 一句话机制 |
|---|---|---|---|---|---|
| 1 | PLL enable_cnt 预置=1 → `dsi_pll_enable_pll_bias` 早退，**SYSTEM_MUXES=0xc0 永不写入** | dsi/phy/dsi_phy_7nm.c:443-456, 1140-1145 | (1) 上游演进 | **高** | PHY power_on 先把 cnt 置 1，随后 vco set_rate/prepare 里的 bias-enable 全部早退，PLL 输出 mux 未使能 ⇒ 位钟在 clk_summary 上有"速率"但无实际视频流（dsi_isr=0、仅背光） |
| 2 | byte_clk 经 `clk_round_rate` 重推导 + byte_intf_clk 速率改为运行时按 div_2 推导 | dsi/dsi_host.c:403-440, 3011-3012 | (1) 上游演进 | 中 | byte_intf 速率来源从"power_on 时算好的 byte_clk/2"变为"round 后 byte_clk/2"，与 power_on 路径存的 byte_intf_clk_rate/link_intf_rate 可能不一致，2384 处一致性检查可失败/不同步 |
| 3 | DP 7.3 重构（pixel_clk 生命周期 stream_clks_on）+ DP0 使能 + sync_state pending | dp/dp_ctrl.c（392 行差）、dp/dp_display.c（334 行差）；elden.dts:2360-2363 | (1) 上游演进 | 中低 | DP0 status=okay 时若 DP 设备 sync_state 不完成，core.c 的 "sync_state() pending due to displayport-controller" 可让 dispcc 持续维持 boot 频率不重设 |
| 4 | bridge funcs 全量 atomic 化（pre_enable→atomic_pre_enable 等） | dsi/dsi_manager.c:301-551 | (1) 上游演进 | 低 | 纯 API 移植；DIAG 探针已证 enable 路径被调且寄存器置位，排除"没调 enable" |
| 5 | panel 丢 init-sequence 重试 + 首选模式 165Hz→120Hz | panel/panel-novatek-nt36536.c（60 行差） | (2) vendor payload 未带 | 低 | 重试缺失只影响 Q28 坏发窗口；模式表换首选不致"modeset 成功但无内容" |
| 6 | msm_drv GEM/ctx 重构、dpu catalog v13 SSPP rec、yuv420 API 改名 | msm_drv.c:222-839、dpu_hw_catalog.c:303-373、dpu_encoder.c:711 | (1) 上游演进 | 排除 | 不在 DSI 视频数据路径 |

零差异（实测 `diff -u … | grep -c '^[+-]'` = 0）：dsi_cfg.c、dsi.c、dsi_phy.c、dsi.h、msm_mdss.c、msm_kms.c、dpu_kms.c、dpu_encoder_phys_vid.c、dpu_12_0_sm8750.h、dispcc-sm8750.c。

## 2. 候选详证

### C1（高）dsi_phy_7nm.c — enable_cnt 预置 1 使 PLL bias 路径早退

**来源分类**：上游演进 —— `git show 24a19b953e:...dsi_phy_7nm.c` 实测已含 `429: if (pll->pll_enable_cnt++) {` 与 `1094: pll->pll_enable_cnt = 1;`；A（7.2+payload）无此结构（A:449-450 为无条件 `cnt++` 后继续执行）。

B 树 `dsi_pll_enable_pll_bias()`（dsi_phy_7nm.c:443）：

```c
spin_lock_irqsave(&pll->pll_enable_lock, flags);
if (pll->pll_enable_cnt++) {          /* ← 新增早退 */
        spin_unlock_irqrestore(&pll->pll_enable_lock, flags);
        WARN_ON(pll->pll_enable_cnt == INT_MAX);
        return;
}
data = readl(pll->phy->base + REG_DSI_7nm_PHY_CMN_CTRL_0);
data |= DSI_7nm_PHY_CMN_CTRL_0_PLL_SHUTDOWNB;
writel(data, pll->phy->base + REG_DSI_7nm_PHY_CMN_CTRL_0);
writel(0xc0, pll->phy->pll_base + REG_DSI_7nm_PHY_PLL_SYSTEM_MUXES);
```

B 树 `dsi_7nm_phy_enable()`（dsi_phy_7nm.c:1140）：

```c
spin_lock_irqsave(&pll->pll_enable_lock, flags);
pll->pll_enable_cnt = 1;              /* ← 预置计数 */
data = DSI_7nm_PHY_CMN_CTRL_0_DIGTOP_PWRDN_B | DSI_7nm_PHY_CMN_CTRL_0_PLL_SHUTDOWNB;
writel(data, base + REG_DSI_7nm_PHY_CMN_CTRL_0);
```

**为什么可能"modeset 成功但面板无内容"**：调用链 `dsi_7nm_phy_enable`（cnt 0→1）→ vco set_rate（B:356 调 bias）→ vco prepare/enable（B:519 调 bias，slave B:521）。cnt 已为 1 ⇒ 两次 bias 调用全部早退 ⇒ **`PLL_SYSTEM_MUXES = 0xc0` 从未写入**（该写只在早退之后的路径里）。SHUTDOWNB 已被 phy_enable 置位，PLL 可报出频率（clk_summary 有 dsi0vco=756MHz 的"速率"），但输出 mux/校准链未走全 ⇒ DSI 链路无实际数据流，与 10-14 实测 `dsi_isr=0`、CRTC active、仅背光完全吻合。A 树 7.2 语义：bias 首次调用真正执行（含 MUXES），故能点亮。

**一条命令验证**（下次上电窗口，健康发 B 树）：
```
cat /sys/kernel/debug/clk/clk_summary | grep -E 'dsi0vco|byte_clk'   # 看 enable 计数列是否 >0；再用 devmem 读 REG_DSI_7nm_PHY_PLL_STATUS(0x0AE9A_0BC? 按基址) 的 LOCKdet 位
```
代码侧最小验证：在 B 树 `dsi_pll_enable_pll_bias` 早退分支加 `pr_info("bias skipped cnt=%d\n", pll->pll_enable_cnt)`，点亮失败时若打印 "cnt=2/2" 即实锤。

### C2（中）dsi_host.c — byte_clk round + byte_intf div_2 推导

**来源分类**：上游演进（24a19b953e 已含 389/416-418 行同代码）。

B 树 dsi_host.c:403-416：
```c
rounded_byte_clk_rate = clk_round_rate(msm_host->byte_clk, msm_host->byte_clk_rate);
if (rounded_byte_clk_rate < 0) { ... return rounded_byte_clk_rate; }
msm_host->byte_clk_rate = rounded_byte_clk_rate;   /* ← 原地改写 */
```
B 树 dsi_host.c:433-440：
```c
byte_intf_clk_rate = msm_host->byte_clk_rate;
if (msm_host->byte_intf_clk_div_2)
        byte_intf_clk_rate /= 2;
ret = clk_set_rate(msm_host->byte_intf_clk, byte_intf_clk_rate);
```

**风险**：`byte_clk_rate` 被四舍五入后重写，而 power_on 路径（B:3019-3021、3060）又用改写后的值生成 `byte_intf_clk_rate/link_intf_rate`；若 round 后的 pclk/byte 派生与 DPU 侧 pclk_src 请求不一致，可在 B:2384 的一致性检查处失配。A 树不做 round（A:423 直接用旧 byte_intf_clk_rate）。
**验证**：`dmesg | grep 'Set clk rates: pclk'` 对比 A/B 两树的 byteclk/pclk 数值是否逐位相同；不等则为实锤（A 打印已删，B 打印保留）。

### C3（中低）DP 7.3 重构 + sync_state pending

**来源分类**：上游演进（`git diff 24a19b953e 640b0e49db -- drivers/gpu/drm/msm/dp` 输出为空 ⇒ dp 的 392/334 行差异全部来自 7.2→7.3）。典型变化如 dp_ctrl.c 新增 `msm_dp_ctrl_on_pixel_clk()`/`stream_clks_on` 生命周期管理。
**风险机制**：elden.dts:2360-2363 `&mdss_dp0 { status = "okay"; }`（两树同）。7.3 的 DP probe/bind 行为变化可让 DP 设备长期不调 sync_state ⇒ `drivers/base/core.c:1853/1859 "sync_state() pending due to displayport-controller"` ⇒ dispcc 保持 boot 装载的父时钟频率，DSI 显示链重设失败。
**验证**：`dmesg | grep 'sync_state() pending'`（A/B 两台对照；vk94 也应打印，若 vk94 无而 B 有即相关性成立）。

### C4（低）dsi_manager.c — bridge atomic API 移植
纯机械改名（`pre_enable→atomic_pre_enable` 等 8 处 + 补 3 个 atomic state ops）。P4d DIAG 实测 `DIAG: mgr bridge_enable id=0 powered=1 bonded=1`、`host_enable ... ctrl_after=0x173` ⇒ enable 链路确实在跑，排除。

### C5（低）panel-novatek-nt36536.c — B 丢失 vendor 重试 + 首选模式变化
B 删除了 A 的 init-sequence 重试循环（A:97-110，"bonded-DSI 首条 DCS 写间歇 -110"的 vendor 修复）与 `force_hz` 调试钩子；模式表 165Hz 从首选位（A 第一个）移到 B 第三位，首选变 120Hz。属 (2) vendor payload 未搬运；但 10-14 实测 m1-73j 为健康发（L1=L2=0），不解释"健康发仍无内容"。
**验证**：B 树内核命令行加 `panel_novatek_nt36536.force_hz=165`（需先回移 force_hz）对比行为。

## 3. 已排除项（实测）

- **DTS 显示节点**：sm8750.dtsi 两树差异仅新增 uart15；elden.dts 19 行差异 grep dsi/panel/dpu/backlight/disp 为空；wl2868c 调节器两树均在（dts:2138）。
- **dispcc-sm8750.c**：0 行差异。
- **.config**：DRM/DSI/PANEL/BACKLIGHT/MDSS 关键字 diff 为空（总 diff 332 行均为 7.3 版本面）。
- **msm_mdss.c / msm_kms.c / dpu_kms.c / dsi_phy.c / dsi.h / dpu catalog(sm8750)**：0 行差异。
- **DSC 参数、panel 模式表数值**：任务指定排除；C5 只涉及"首选位次"不涉及数值。
- **rebase 解冲突错误**：B = upstream 7.3-rc7 + 单 squash payload；A↔B 每处差异均能在 24a19b953e 或 payload 侧定位来源，未发现手工解冲突造成的混合/丢失语义（C5 的"payload 未带"属 payload 覆盖面问题，非解冲突错误）。

## 4. 建议验证顺序

1. **C1 一条 pr_info**（bias skipped cnt）+ `clk_summary` enable 计数 —— 成本最低、判别力最强。
2. C2 的 pclk/byteclk 打印对照（B 保留打印，直接可读）。
3. C3 的 `dmesg | grep 'sync_state() pending'` 对照。
4. 以上均排除后再看 C5。
