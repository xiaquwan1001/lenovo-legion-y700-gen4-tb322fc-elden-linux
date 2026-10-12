# Q28 原厂 display 源码静态对比（dispcc/INTF 靶）— 2026-10-12

> 目的：执行 2026-10-12 收束给出的「剩余靶点 #1 = dispcc/INTF 侧动态时钟请求」的**代码级静态核对**。
> 素材：`stock-src/android_kernel_lenovo_sm8750-modules/.../msm/dsi/`（本机权威）+ `reference/vendor-display-sm8750/`（同 SoC 兄弟）。
> 纪律：**纯静态**，未改内核树、未编译、未上机。

## 0. 结论（数字先行）

1. **原厂 display 源码本仓已有**（`stock-src/...`，40 文件）⇒ 前一轮「`/tmp/vdsrc` 易失」的问题**已消除**；本目录的 OnePlus 版仅为兄弟参考，与 Lenovo 版核心同源（差异仅 OPLUS/IRIS OEM 补丁）。
2. **「剩余靶点 #1」的前提不成立**：全树 grep 显示 `DSI_DISP_CC_*` 只用于 **① `disp_cc+0x00` 的 PHY reset clamp**（`dsi_ctrl_hw_22_phy_reset_config`）、**② `DSI_MDP_INTF_*` 仅用于 TE / line-count 调试**（`dsi_ctrl_hw_2_2.c`）。
   **原厂在 DSI 驱动里并不操作 DYN pclk 域** ⇒ 该靶点从「原厂对照」这条路上**挖不到东西**。
3. **命令路径逐项对照 = 等价**（§2）：原厂 `kickoff_command()` 与主线 `msm_dsi_host_bonded_cmd_stage()` 在寄存器级一致（BROADCAST/MASTER/WC_SEL/PACKET_TYPE/embedded bit28；FIFO bit16+bit20 禁水位；v≥2.8 VBIF priority=7；DMA base/len；SW_TRIGGER/TRIG_DMA=1）⇒ 与 vk121 的实验结论互相印证。
4. `CLK_STATUS` 的 DYN 位**原厂也不清**（`clear_error_status()` 只清 BIT(16) PLL_UNLOCK）⇒ 与 vk117 的「控制器复位后 DYN 位仍在」一致：DYN 是 **dispcc 侧只读映射**。
5. 唯一新发现的可实验差异 = **复位终态**（§3，原厂复位后**时钟全关 + 引擎保持关**；主线恢复保存值）。vk117 未单独测过终态。

## 1. 参考源事实

| 项 | 值 |
|---|---|
| 本机权威 | `stock-src/android_kernel_lenovo_sm8750-modules/qcom/opensource/display-drivers/msm/dsi/`（40 文件） |
| 兄弟参考 | `reference/vendor-display-sm8750/`（OnePlus @ lineage-24.0，已含 `dsi_ctrl_hw.h`） |
| 逐字节相同 | `dsi_ctrl_reg.h`、`dsi_clk_manager.c` |
| 差异性质 | `OPLUS_*` 异常上报、`CONFIG_PXLW_IRIS`（Pixelworks）；**无功能核心差异** |
| Lenovo 缺 | `clk/qcom/dispcc-sm8750.c` 等时钟驱动（stock GPL 未含）⇒ dispcc RCG 方向需另找 vendor 主内核树 |

## 2. 命令路径对照（寄存器级）

| 寄存器 | 原厂 `kickoff_command()` | 主线 `bonded_cmd_stage()` | 一致 |
|---|---|---|---|
| CMD_MODE_DMA_CTRL | bit31 BROADCAST_EN / bit30 MASTER / bit26 LPM / **bit28 embedded** / 清 bit24 packet-type、bit29 WC_SEL | `BROADCAST_EN`/`BROADCAST_MASTER`/`LOW_POWER`/`FROM_FRAME_BUFFER`，清 WC_SEL/PACKET_TYPE | ✅ |
| CMD_MODE_DMA_CTRL_1 | MULTI_DMA_BURST 按 flag | `CTRL1_MULTI_DMA_BURST_EN` 清 | ✅ |
| DMA_FIFO_CTRL | **BIT(20)+BIT(16)** 禁写/读水位 | `DISABLE_READ_WATERMARK\|DISABLE_WRITE_WATERMARK` | ✅ |
| VBIF_CTRL (v≥2.8) | PRIORITY=7 | PRIORITY=7 | ✅ |
| DMA offset/length | DMA_CMD_OFFSET / DMA_CMD_LENGTH | DMA_BASE / DMA_LEN(0xFFFFFF) | ✅ |
| 触发 | `DSI_CMD_MODE_DMA_SW_TRIGGER=1` | `REG_DSI_TRIG_DMA=1` | ✅ |

⇒ 命令发射编程**无差异**；与 vk121（换标准广播路径仍坏）一致，卡点不在这批寄存器。

## 3. 复位终态差异（唯一新发现，未实验）

原厂 `dsi_ctrl_hw_cmn_ctrl_reset()`：
```
DSI_CTRL &= ~VID_MODE_EN ; DSI_CTRL &= ~(ENABLE|VID_MODE_EN)
DSI_CLK_CTRL = 0x100a00          /* force-on dynamic clocks */
DSI_SOFT_RESET = 1 ; = 0
DSI_CLK_CTRL = 0x00              /* 时钟全关 */
DSI_CTRL = (data & ~VID_MODE_EN) /* 只恢复 ENABLE，引擎保持关 */
```
主线 `dsi_sw_reset_v2_9()`：
```
DSI_CTRL &= ~(ENABLE|VID_MODE_EN|CMD_MODE_EN)
DSI_CLK_CTRL = saved | force_on(ENABLE_CLKS|BIT8|9|11|21)
DSI_RESET = 1 ; = 0
DSI_CLK_CTRL = saved             /* 恢复原时钟 */
DSI_CTRL = ctrl (原值，含 CMD_MODE_EN)
```
差异：原厂复位后**时钟关、引擎关**；主线复位后**恢复原状的时钟与引擎位**。
> 边界：vk117 已证明「控制器寄存器确实被复位但救不回」，故此项**不是已证根因**；但当时只比较了寄存器值，**未测终态**，仍属未实验轴。

## 4. PHY reset clamp（新候选，未验证）

原厂 `dsi_ctrl_hw_22_phy_reset_config()`：读写 `disp_cc + 0x00`（`DISP_CC_MISC_CMD_REG_OFF`），按 **DSI index 位** mask/unmask "disable PHY reset"。
原厂在 **v2.7/2.8/2.9** 都保留 `disp_cc_base` 映射（`dsi_ctrl.c:737-746`）。
**待核**：主线是否等价处理该 clamp（`dispcc-sm8750` / `dsi_phy`）；若缺，可能与「PHY 复位态」相关。

## 5. 结论与下一步

- **原厂同 SoC 代码在 Q28 这条轴上已无更多可挖**（命令路径等价；原厂不做 DYN pclk 操作）⇒ **支持「转上游/Qualcomm + 运营兜底看门狗」的裁决**，而不是继续翻别家机型驱动。
- 仍值得做的低成本实验（按序）：
  1. **DYN 握手旁路**：panel init **全窗口**保持 `FORCE_ON_DYN_*`（不还原 `CLK_CTRL`）——直接检验「DYN pclk 请求闩住」假说（vk122 只在 enable 瞬间包了 force-on，窗口太短）。
  2. **复位终态对齐**：恢复序列终态改成原厂样式（`CLK_CTRL=0` → 恢复 `DSI_EN`、引擎关 → 再 `cmd_engine_en`）后发第 2 条 DCS。
  3. **PHY reset clamp**：核对 §4，若主线缺则补。
- dispcc RCG 方向需 **vendor 主内核树的 `dispcc-sm8750.c`**（Lenovo stock 未含 clk 驱动）。

## 6. 证据

- 固化参考：`reference/vendor-display-sm8750/`（含 README 与 sha256）。
- 命令路径主线实现：`geekidos-linux/drivers/gpu/drm/msm/dsi/dsi_host.c:2534-2563`（bonded_cmd_stage）、`:1632`（dsi_cmds2buf_tx）。
- 复位主线实现：`dsi_host.c:1201-1225`（`dsi_sw_reset_v2_9`）。
- 原厂：`reference/vendor-display-sm8750/dsi_ctrl_hw_cmn.c:819-846`（ctrl_en）、`:877-947`（kickoff）、`:1396-1487`（clear_error_status）、`:1781-1810`（ctrl_reset）；`dsi_ctrl_hw_2_2.c:90-110`（phy_reset_config）。
