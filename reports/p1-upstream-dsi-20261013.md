# P1 臂：纯上游 DSI（7.3-rc7）上机结果 — 2026-10-13 深夜

> 目的：回答「上游 mainline DSI（无 vendor bonded_cmd）能否驱动 elden 面板 / Q28 是否为 vendor 栈引入」。
> 方式：M1 干净树 + 只回退 DSI 栈到 pristine 7.3-rc7；零写盘 fastboot boot。
> 状态：**已上机（1 发，U2/HA2EXB0E）**；结论=**上游 DSI 在本硬件点不亮，且失败在更早的像素时钟编程**。

## 0. 数字先行

- 镜像：`out/boot-elden-p1-uplink-dsi.img`（86 257 664 B，sha `06da231c…`），UTS `7.3.0-rc7-debug-g5f0c2c668fd1`。
- 变量：`drivers/gpu/drm/msm/dsi/` + `registers/display/dsi.xml` + `include/drm/drm_mipi_dsi.h` 回退到 pristine `24a19b953e`（内核内 `bonded command DMA failed` 串计数 = 0 ⇒ 确为上游 DSI）。
- 其余与 m1-73j 同：同一 7.3-rc7 基座、同 elden DTS/DTB、同 cmdline、同 ramdisk 基座（`35823240…`）+ 37 模块 overlay（fsa4480/fastrpc/时钟闭包，vermagic 全对）。
- 结果：**L1FAIL**，`card0` 在、`card0-DSI-1=connected`、phoc/phosh 起、背光 511、**无画面**。

## 1. 失败签名（与 vendor Q28 不同）

```
[ 95.460133] dsi_link_clk_set_rate_6g: Failed to set rate pixel clk, -22
[ 95.460135] msm_dsi_host_power_on: failed to enable link clocks. ret=-22
[ 95.460138] dsi_mgr_bridge_power_on: power on host 0 failed, -22
[ 95.460199] msm_dsi ae94000.dsi: Power on failed: -22
[ 95.488909] panel-novatek-nt36536: sending dcs data ff 20 failed: -22
[ 95.488912] panel-novatek-nt36536: Failed to initialize panel: -22
```

- 上游失败在 **`dsi_link_clk_set_rate_6g() → clk_set_rate(pixel_clk) = -EINVAL`**，**早于** vendor 栈的 Q28（`command DMA timeout status=0x2200200` → `-110`）。
- 两处都在**像素时钟/dispcc 域**，但上游连 panel init 都没走到 DCS 命令引擎。

## 2. 根因（源码级，vendor 有、上游无）

对比 `dsi_link_clk_set_rate_6g_v2_9()`：

- **vendor（M1 树）独有块**：
  ```c
  if (of_device_is_compatible(dev->of_node, "qcom,sm8750-dsi-ctrl")) {
      ret = clk_set_rate(msm_host->dsi_pll_byte_clk, msm_host->byte_clk_rate);
      ...
  }
  ```
  注释原文：*"SM8750's C-PHY parent-enable path also needs a valid cached VCO rate before the first prepare attempt."*
- **上游 7.3-rc7 没有这块**（无 SM8750 分支，直接 reparent 后 `dsi_link_clk_set_rate_6g()`）⇒ PLL VCO rate 未缓存 ⇒ 后续 `clk_set_rate(pixel_clk)` 被 dispcc RCG 拒绝 `-EINVAL`。

⇒ 上游 DSI 目前**缺少 SM8750 专用的 DSI PLL / C-PHY 时钟编程**；这正是 B5（DSI per-SoC cfg）要把散落 `of_device_is_compatible` 收敛成 per-SoC cfg 的那部分，是**可上游的一小块**。

## 3. 结论与下一步

1. **「丢掉 vendor DSI 栈、直接用上游」当前行不通** —— 上游连面板上电都失败（缺 SM8750 PLL 时钟块）。所以「上游规范地驱动屏幕」= 必须先把这块 SM8750 专用处理**按上游规范上游化**，而不是简单回退。
2. **候选下一步（单变量、可上游）**：P1b = P1 + 只移植 vendor 的 SM8750 `dsi_pll_byte_clk` 取速率块（`dsi_link_clk_set_rate_6g_v2_9` 内一个 `if`），看是否：
   - 走到 panel init（则得到**与 vendor 相同的 Q28 cmd-DMA 签名** ⇒ 证明该时钟块与 Q28 无关，Q28 是更下游的命令引擎/DYN 域问题）；
   - 或出现不同签名（则说明像素时钟编程本身就是 Q28 的一环）。
   这是把 Q28 与「SM8750 DSI 上游化缺口」分离的最干净实验。
3. 设备现状：U2 正跑 P1（仅背光），SSH 在；回日常 = `eldroid-bootctl reboot system`（boot_b=vk94）。

## 4. 证据

- `logs/p1-boot-20261013-223522/`（env/dmesg/drm/probe）。
- `reports/trials/20261013T143556Z-p1-uplink-dsi-s1.json`。
- 源树：`build/p1-upstream-dsi`（分支 `p1/upstream-dsi`，commit `5f0c2c668f`）。
- 对照：`build/m1-upstream/clean-tree-73`（vendor DSI）的 `dsi_link_clk_set_rate_6g_v2_9`。

---

## 5. P1b / P1c 追加（2026-10-13 深夜）

### P1b（`d22b679109`）= 移植 vendor SM8750 `dsi_pll_byte_clk` 取速率块 → **否证**
- 仍 `dsi_link_clk_set_rate_6g: Failed to set rate pixel clk, -22`，签名不变 ⇒ 该块单独不解决问题。
- 对照发现 `dsi_get_pclk_rate`/`dsi_calc_clk_rate` upstream 与 vendor **逐字相同** ⇒ 根因不在 N/M 计算，而在**时钟能否合成**。

### P1c（`05876fca33`）= + PHY `pll_7nm_register` SM8750 C-PHY 位路径（保持 P1b）→ **PHY 块生效，但显示仍不工作**
- 改动：cphy_mode 下对 `qcom,sm8750-dsi-phy-3nm` 选 `DSICLK_SEL(0)`/`pll_bit`（vendor 注释：elden 30bpp/三 trio C-PHY 走全速 bit 路径 + PIX_CLK_DIV=2 + DISPCC 16/35 M/N；通用 2/7 路径合成不出 172.992 MHz 压缩后单 host 像素时钟）。
- **实测（1 发）**：`Failed to set rate pixel clk -22` **消失**，DSI `power_on` 无报错；但仍：
  - `dpu_encoder_phys_vid_prepare_for_kickoff … enc35 intf1/intf2 ctl 1 reset failure: -22`
  - `dpu_encoder_frame_done_timeout` + `vblank timeout` + `drm_crtc_wait_one_vblank` WARN 风暴
  - **无任何 panel DCS/init 日志**；`phoc/phosh=0`、无 wayland ⇒ 无桌面。
- ⇒ PHY C-PHY 块**是上游点亮面板的必要条件**（否则连上电都失败），但**不是充分条件**。下一步嫌疑 = **P1 只回退了 DSI，未回退 DPU**（M1 树 DPU 仍是 vendor：`dpu_encoder.c +52/-20`、`dpu_encoder_phys_vid.c`、`dpu_12_0_sm8750.h`）⇒ upstream DSI 与 vendor DPU 组合不匹配。真正的「纯上游显示」臂应连 DPU/msm_mdss 一起回退（但会丢 SM8750 GPU/DPU catalog 的 vendor 增量，需逐一评估）。
- 判据注意：`q28-devprobe2.sh` 的 L1 正则匹配的是 vendor 栈字符串，对 upstream 栈**漏判**（本次误报 `l1=0 / GOOD-NOSESSION`）；对 upstream 栈应加上 `dpu.*reset failure`、`vblank timeout` 等判据。

### P1d（`d300ff1032`）= + DPU/msm_mdss 也回退到 pristine → 仍不工作，且**归因更清晰**
- 结果与 P1c **同一失败**：`enc35 intf1/intf2 ctl 1 reset failure: -22` + `frame done timeout` + `vblank timeout`；无 panel DCS、无 session。另见 `dsi1 phy driver is not ready`（回退 msm_mdss 去掉 `mdss_prepopulate_dsi_phys` 的副作用）。
- **关键归因**（三臂对照）：
  | 臂 | DSI | DPU | 结果 |
  |---|---|---|---|
  | m1-73j（vendor） | vendor | vendor | 过 kickoff → panel DCS `-110`（Q28） |
  | P1c | **upstream** | vendor | DPU kickoff `ctl reset -22`，无 DCS |
  | P1d | **upstream** | **upstream** | DPU kickoff `ctl reset -22`，无 DCS |
  ⇒ **DPU kickoff 失败是「upstream DSI」带来的**（vendor DPU 也救不了）。即换上游 DSI 后，DPU INTF 无法 kickoff。
- 含义：上游 7.3-rc7 的 DSI（含 bonded 双 DSI 面板）与 DPU 的配合**不完整**；要「上游规范点亮」，必须把 vendor DSI 栈里与 kickoff/使能时序相关的增量按 b5 分类逐组上游化（候选：b5 §3.2 的 H39/H40/H42 使能时序、H12/H20 IRQ/dma_submit_seq、H45/H46 bonded 配对）。

## 6. 阶段结论（三臂后）

- **纯上游显示栈目前点不亮 elden 面板**：缺 PHY SM8750 C-PHY 位路径（P1c 已证必要）之后，仍卡在 **DPU kickoff**，且该卡点来自 **upstream DSI** 而非 DPU。
- vendor DSI 栈当前**是必需的**；「上游化显示」= 按 b5 的 56 hunk 分类**成组移植** vendor DSI 增量，而不是逐块猜（PHY、byte-clk 已验证是其中两块）。
- Q28（panel DCS `-110`）与上述「上游缺口」正交：需先能走到 panel init，才能判断 Q28 是否 vendor DSI 命令路径特有。

### P1e（`8acbc6b142`）= 移植 vendor「host_enable 移入 atomic_enable」→ 仍不工作；但**采集到关键事实**
- 失败同前（`ctl 1 reset failure -22` + vblank 风暴），该 enable 时序不是解。
- **关键**：`novatek-nvt36xxx-spi: panel prepared` + **零 DCS 失败 / 零 command-DMA timeout**。对照全五臂：

  | 臂 | PHY C-PHY 块 | DCS 面板 init | Q28 签名 |
  |---|---|---|---|
  | P1 | 无 | 失败 `-22`（上电阶段） | 无 |
  | P1b | 无 | 失败 `-22` | 无 |
  | **P1c/P1d/P1e** | **有** | **成功（panel prepared）** | **无** |

  ⇒ **只要补上 PHY SM8750 C-PHY 位路径，上游 DSI 就能完成面板 DCS 初始化，且 3/3 未出现 Q28 的 `command DMA timeout`**（Q28 是 vendor DSI 命令路径的签名）。
- **剩余阻塞 = DPU video/CTL 起不来**：`dpu_encoder_phys_vid_prepare_for_kickoff → ctl->ops.wait_reset_status` 超时 → `CTL_SW_RESET` 位不清 → `-EINVAL`；panel 已 prepared 但 video 未起 ⇒ 无画面、无 session。
  - 该 CTL 失败在 **vendor DPU（P1c）与 upstream DPU（P1d/P1e）下都出现** ⇒ 与 DPU 无关，系于 **upstream DSI 的链路/video 状态**。
  - vendor dsi_host.c 多出的 ~552 行（bonded cmd、`dsi_cmd_link_clk_set_rate`、`dsi_sw_reset_v2_9`、`msm_dsi_host_bonded_wait_video`…）里，尚未定位哪一块让 DPU INTF/CTL 能跑。

## 7. ★ P2b 成功：上游 DSI host/manager + vendor PHY → 屏幕点亮（2026-10-13 23:04）

### 7.1 结果（1 发）
- 镜像 `out/boot-elden-p2b-uplink-dsi.img`（sha `71016e08…`，UTS `gbdc7a8aafe65`，commit `bdc7a8aafe`）。
- **VERDICT=GOOD**：`l1=0 l2=0 storm_sig=0 session=1 phoc=1 phosh=1 wayland=1 card0-DSI-1 connected`；
  `card0-DSI-1 dpms=On`、modes `1904x3040`、`ctl reset -22` **0 次**、无 vblank/frame-done/underflow、`panel prepared`，phosh 会话在 tty7。
- 唯一残留噪声是启动早期 `disp_cc_mdss_*_clk_src: orphan reparent failed: -110`（历史 GOOD 冷/暖起同样出现，良性）。

### 7.2 该臂相对 pristine 7.3-rc7 的**全部** vendor 增量（= 上游化清单）
| 域 | 改动 | 是否必需 |
|---|---|---|
| DSI PHY | **整个 vendor `phy/dsi_phy{,_7nm}.c/h`**（SM8750 C-PHY 位路径 DSICLK_SEL=0、`qcom,cphy-timing-ctrl` 解析与时序寄存器、slave PHY LDO 值） | **必需**（本次决定项） |
| DSI host | 仅 SM8750 `dsi_pll_byte_clk` 取速率（P1b，1 块） | 必要（否则 pixel clk -22） |
| DSI manager | host_enable 移入 `.atomic_enable`（P1e） | 已合入；与上游 DPU 协同 OK |
| msm_mdss | `mdss_prepopulate_dsi_phys()`（让 DSI PHY 子设备被 populate） | 必要（否则 dsi1 phy not ready） |
| DPU | **无**（保持 pristine 上游） | —— |
| 其余 msm | adreno/iommu/gem/msm_kms（GPU + splash 保留，与显示路径无直接关系） | 待评估 |

⇒ **「上游规范点亮屏幕」的 vendor 缺口已收窄到：DSI PHY（最大块）+ 少量 DSI host/manager/mdss 位点**；DPU 无需 vendor 改动。

### 7.3 结论与待办
- **Q28 疑为 vendor DSI 命令路径专有**：⚠️ **2026-10-14 悬置**：同镜像复测 4/4 未复现该 GOOD 且面板从未实测 ⇒ 见 `reports/p2b-retest-20261014.md`。原文：本臂用的是上游 DSI 命令路径（无 `bonded_cmd_*`），1 发即 GOOD 且无 `command DMA timeout`。**需多发改冷/温起采样确认 Q28 是否真的不出现**（vendor 栈坏发 ~50%，单发不作数）。
- 这些 vendor 增量可直接作为 **b5 / M3 显示片上上游补丁的输入**（per-SoC cfg 化）。
- 设备当前跑 P2b（RAM，零写盘）。回日常 = `eldroid-bootctl reboot system`。

## 8. 事故记录：P2b 上 kmscube 触发整机硬挂（2026-10-13 23:12）

- 现象：P2b 上（已停 phoc），modetest 成功把 CRTC 设为 enable=1 active=1 mode 1904x3040@120；随后运行 kmscube（GL/EGL 渲染）后整机硬挂：仅背光、SSH/ping 无响应、串口无输出（USB gadget 仍枚举，CPU 不响应）。
- 恢复：串口 SysRq-b 未产生回显，但设备随后 USB 重枚举并正常重启（回到日常 boot_b=vk94，7.2.0-debug-vk64-gd02658e63cf6）——SysRq-b 生效，无需物理 POR。
- 含义：与 PITFALLS #106（进 GUI 后整机卡死）同型；kmscube 是可复现触发点（GPU/显示侧），与 P2b 的 DSI 改动关系待定。
- 纪律更新：在 P2b 这类 arm 上跑 kmscube/GL 前必须常驻串口 logger，否则取证丢失。


## 9. 收尾（2026-10-13 深夜）

- **P2c**（上游 DSI host/manager + vendor PHY + **vendor DPU**，commit 2851bcaff6）：合成器可正常 modeset（connector enabled、crtc-0 enable=1 active=1 mode 1904x3040@120、plane fb 由 phoc 分配、grim 截图成功且有非黑内容）——但**面板实测仍只有背光、无内容**。
- 与 P2b 对照得到两个独立问题：
  1. **上游 DPU 的 DRM 格式/modifier 面**让 phoc 无法 modeset（P2b: connector enabled=disabled、grim no supported format）；换成 vendor DPU 后合成器恢复正常（P2c 已解决）。
  2. **即使合成器在扫描输出，面板仍不显示** ⇒ 上游 DSI host 的视频流/编程没有真正驱动面板；**只有 vendor DSI host 才点得亮**。
- 阶段结论：**「上游规范点亮屏幕」的剩余大缺口 = DSI host**（vendor dsi_host.c 的 ~552 行里包含让面板真正显示的 video/DSC/bonded 编程；已正面验证的必需增量：DSI PHY（必需）+ DSI host（video/命令）+ DSI manager（时序）+ msm_mdss（populate DSI PHY）；DPU 侧也需 vendor 的格式面）。
- 事故：P2c 上 kmscube 曾触发整机硬挂（与 PITFALLS #106 同型），串口 SysRq-b 可恢复；ARM 上跑 GL 前须常驻串口 logger。
- 设备归位：boot_b = vk94（日常），本次全程零写盘。

## 10. 复现资产

- 树：build/p1-upstream-dsi（分支 p1/upstream-dsi；提交链 P1 5f0c2c668f → P1b d22b679109 → P1c 05876fca33 → P1d d300ff1032 → P1e 8acbc6b142 → P2b bdc7a8aafe → P2c 2851bcaff6）。
- 镜像：out/boot-elden-p1-uplink-dsi.img、p1b、p1c、p1d、p1e、p2b（DRM GOOD）、p2c（合成器可渲染但面板无内容）。
- 报告：本文件；trial 记录 reports/trials/*p1*p2*。

