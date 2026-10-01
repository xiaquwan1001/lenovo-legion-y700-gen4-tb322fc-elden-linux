# 面板刷新率：静态分析与改动方案 — 2026-10-01

> 目标：1904×3040 LCD（CSOT PP8807HB1-1 / Novatek NT36536，dual-DSI bonded + C-PHY + DSC + 10bpc video mode）的
> 刷新率驱动梳理与 **165Hz 支持**。
> 入口 `INDEX.md`；参考 `HANDOFF.md §9` 与上游 `experiments/165hz-mode-table.patch`。

## 0. 一句话结论（已更新 2026-10-01 晚）

**165Hz 实测在冷启动下可用**：用测试内核强制 165Hz 冷启，DSI 链路零报错、时钟与离线计算完全一致、
CRTC 正常扫描出图，合成器（phoc + Xwayland + GNOME）正常起来。
**上游 `experiments/165hz-mode-table.patch` 的「165Hz 失败、backlight only + FIFO 风暴」是旧树状态**，
当前树（已含厂商硬编码 SM8750 C-PHY 像素时钟路径 + 上游 hdisplay 修复）已不再复现。
剩余限制在 **合成器**：phoc 把 preferred（120Hz）钉死，运行时 `wlr-randr` 切 165Hz 被它忽略。

mode table 已完整（8 档），所有档位「压缩后 per-host pclk」几乎相同（172.97–172.99 MHz）——
**165Hz 不是时钟速率问题**。详细分析见 §1–§6，上机结果见 §7。

**2026-10-01 收尾（vk32）**：已将 mode table 的 **165Hz 档移到首位 → 成为默认 preferred**，冷启即 165Hz，
合成器 `Modesetting … @ 165.000 Hz`，运行 2 min 零 DSI 报错，8 档仍全部暴露。见 §9。

## 1. 当前状态（实测）

| 项 | 值 |
|---|---|
| 驱动 | `drivers/gpu/drm/panel/panel-novatek-nt36536.c`（`=y` 内建），compatible `csot,pp8807hb1-1` |
| DSC | 1.2，`slice_height=20 slice_width=476 slice_count=2`，`bpc=10`，`bpp=8<<4` |
| DSI | `MIPI_DSI_MODE_VIDEO | ..._BURST | ..._LPM | DSC_ALL_SLICES_IN_PKT`，dual-DSI bonded，C-PHY，3 lane/DSI |
| PHY | `qcom,sm8750-dsi-phy-3nm`（`dsi_phy_7nm.c`），`qcom,cphy-timing-ctrl=[00 00 00 00 23 23 08 19 08 02 04 00 00 00]` |
| 当前帧率 | **120.00 Hz**（`modetest -M msm -c`：8 个 mode，#0 为 preferred） |
| 165Hz | mode #1 存在；**冷启可用**（vk30 实测零 DSI 报错，见 §7）；仅在 phoc 下运行时切换被忽略（合成器钉 preferred=120Hz）。旧「不可用/backlight only/FIFO 风暴」为本行下方模式表旧树状态 |

`modetest -M msm -c`（2026-10-01 实测）：

```
#0 1904x3040 120.00  htot 2244 vtot 3400  clk 915552   preferred
#1 1904x3040 165.00  htot 2068 vtot 3120  clk 1064606
#2 1904x3040 144.00  htot 2068 vtot 3575  clk 1064606
#3 1904x3040  90.00  htot 2628 vtot 3120  clk 737942
#4..#7 60/40/30/24  htot 2244 vtot 6800/10200/13600/17000  clk 915552
```

`/sys/kernel/debug/clk/clk_summary`（120Hz 工作态）：

```
dsi0vco_clk               = 756,839,941
dsi0_pll_bit_clk          = 756,839,941
dsi0_phy_pll_out_dsiclk   = 378,419,971   (bit/2)
disp_cc_mdss_pclk0_clk_src= 172,991,986   (= dsiclk × 16/35)
dsi0_phy_pll_out_byteclk  = 108,119,991   (= bit/7)
```

## 2. 刷新率配置在哪里

| 层 | 文件 / 函数 | 作用 |
|---|---|---|
| mode table | `panel-novatek-nt36536.c` `csot_pp8807hb1_1_modes[]` | 各档 clock/htotal/vtotal/porches（已含 165/144） |
| DSI 时钟 | `dsi_host.c` `dsi_adjust_pclk_for_compression()` / `dsi_get_pclk_rate()` / `dsi_byte_clk_get_rate()` | 由 mode 推 pclk/byteclk，再 `get_phy_clk_req()` 得 `bitclk=byteclk×7` 给 PLL |
| DSI 时序寄存器 | `dsi_host.c` `dsi_timing_setup()` `dsi_update_dsc_timing()` | 写 `REG_DSI_ACTIVE_H/TOTAL/...`、DSC 压缩模式寄存器 |
| PHY/PLL | `dsi_phy_7nm.c` `pll_7nm_register()`（SM8750 C-PHY 走 DSICLK_SEL=0 + PIX_CLK_DIV=2）、`dsi_7nm_phy_enable()` | PLL 分频与 C-PHY 像素时钟路径 |
| DPU 侧 | `dpu_encoder_phys_vid.c` `drm_mode_to_intf_timing_params()` / `programmable_fetch_get_num_lines()` | 由 mode 推 INTF 压缩时序（width/htotal/vtotal）与 prefetch |
| 面板侧 | `csot_pp8807hb1_1_init_seq()` | 一次性 init（含 "frame ctl" `0xb2/0xb3`、DSC `0x90/0x91/0x92`），**不随刷新率变化** |

## 3. 关键静态结论（数字）

按 mainline 公式离线复算全部 8 档（bonded，DSC 8bpp/10bpc，压缩行 = `DIV_ROUND_UP(952*8,30)*2 = 508`）：

| Hz | clock | htot | vtot | adj_pclk(全) | per-host pclk | byteclk | bitclk |
|---|---|---|---|---|---|---|---|
| 120 | 915552 | 2244 | 3400 | 345,984 | **172,992** | 108,120 | 756,840 |
| 165 | 1064606 | 2068 | 3120 | 345,945 | **172,973** | 108,108 | 756,756 |
| 144 | 1064606 | 2068 | 3575 | 345,945 | 172,973 | 108,108 | 756,756 |
| 90 | 737942 | 2628 | 3120 | 345,945 | 172,973 | 108,108 | 756,756 |
| 60/40/30/24 | 915552 | 2244 | … | 345,984 | 172,992 | 108,120 | 756,840 |

- 厂商 mode table 是**刻意设计**成「压缩后 pclk 恒定」的（刷新越高，blanking 越小以抵消 clock 上升）。
- 因此 165Hz 与 120Hz 的 **D-SI/PHY 时钟完全一致** → **排除「时钟速率不足 / PLL 拉不上去」**。
- 链路余量：link ≈ 5.19 Gbps/host；165Hz 压缩数据需求 ≈ 3.92 Gbps/host（余量 1.32×）→ **也不是带宽不足**。

→ 165Hz 的差异只剩 **时序寄存器（htotal/vtotal/blanking）与 DSC/DPU 配置**，或 **面板侧 per-refresh 寄存器**。

## 4. 候选根因（排序）

| # | 假设 | 依据 | 验证方法 |
|---|---|---|---|
| **H1** | **面板 per-refresh 寄存器**：init 里的 "frame ctl"（`0xb2/0xb3`）与 DSC 参数只按一个刷新率写死；165Hz 需厂商的另一套值 | 厂商 Android 的 DSI timing 是按 refresh 分档（dtbo 里每档一组 register）；主线 init 只跑一次 | 取 Y700 厂商 DT 的 165Hz register 序列，对比 |
| **H2** | **DSI 压缩后 blanking 过小**：165Hz 压缩行 254、h_total 336 → 仅 82 pclk blanking（120Hz 为 170）；低于 DSI video 引擎/FIFO 的取数窗口需求 → under/overflow | `dsi_timing_setup()`；报错为 `DSI_ERR_STATE_FIFO(0x4)` | 打印 `REG_DSI_TOTAL/ACTIVE_H`、试加大 hbp/htotal（牺牲刷新或改 porch） |
| **H3** | **DPU INTF 与 DSI 的 DSC 宽度舍入/时序不同步**：DPU `timing->width` 与 DSI `hdisplay` 必须严格相等；165Hz 行更短，任何 1-cycle 差异都会累积 | 上游 ac47870/2d51cfb 正是修这个；本树已含该修（`DIV_ROUND_UP` 两边一致），但 porches 的压缩处理仍可能不一致 | 打印 DPU `width/htotal/vtotal` 与 DSI `hdisplay/h_total/v_total` 对比 |
| **H4** | **PHY PLL 重锁 / 时钟域毛刺**：video 面板从 DSI clock lane 再生时序，PLL 重锁会造成静默失锁 | 上游 "drm/msm/dsi: don't re-lock the PHY PLL" | 冷启 165Hz 观察；对比 modeset 前后 PLL 寄存器 |
| **H5** | 上游 **byte clock 舍入**（`2028280686f4`）在本树缺失：`dsi_calc_clk_rate_6g()` 用理想 byteclk 求 bitclk，PLL 四舍五入后 DISPCC RCG 与 DSI 假设不一致 | 本树 `dsi_calc_clk_rate_6g` 无 round；上游 7.3 有此回归+修复 | 打印 `clk_round_rate()` 与实际 rate；对照 `DISP_CC_MDSS_PCLK0_CLK_SRC` M/N |

> H1 的旁证：**本次 dump 的 `backup/dtbo_a.img`（76 个 FDT blob）里没有 Y700 的 nt36536/pp8807 面板节点**
> （只有 nt37801 等其他机型）——即厂商 Y700 的 per-refresh DSI timing **不在这块 dtbo 里**，
> 需要从 boot/vendor_boot 或 EDL 的 imagefv/其他分区再取。

## 5. 改动方案（分三步，先静态/小样本，后上机）

### 步骤 A（无风险，先做）：把时序对齐做成可观测
在 `dsi_timing_setup()` 与 `drm_mode_to_intf_timing_params()` 增加 `dev_dbg`/`dev_info`：
打印 mode 的 `clock/htotal/vtotal`、压缩后 `hdisplay/h_total/v_total`、DPU `width/xres/htotal/vtotal`、
以及 `pclk/byteclk/bitclk`。用于确认 H2/H3（DPU 与 DSI 是否一致、blanking 是否过小）。

### 步骤 B（候选修复，按代价低→高依次试）
1. **H5 补丁**：把上游 `2028280686f4`（reparent 后 round byteclk）落到 `dsi_link_clk_set_rate_6g_v2_9()`，
   并让 `msm_dsi_host_get_phy_clk_req()` 用 `clk_round_rate()` 后的 byteclk 求 bitclk。
   低风险、且是已知 SM8750 问题。
2. **H3 补丁**：把 DPU `drm_mode_to_intf_timing_params()` 里 DSC 的 porches 也按压缩后单位对齐，
   保证 `dpu.width + dpu.porches == dsi.h_total`（当前两边都 `DIV_ROUND_UP`，但 porch 未压缩）。
3. **H2 实验**：临时把 mode table 里 165Hz 的 `htotal` 调大（如 hfp 50→138，即沿用 120Hz 的 porch），
   观察 FIFO 是否消失——用来判定是不是 blanking 太小。
4. **H1 修复**（最终目标）：从 Y700 厂商 DT 取 165Hz 的 DSI timing/panel register，
   在 panel driver 里按 `drm_display_mode` 分档下发（`prepare()` 里按 `mode->clock` 选 register 组）。

### 步骤 C：小样本验证（本机）
- 只重编 `panel-novatek-nt36536.o` / `dsi_host.o` / `dsi_phy_7nm.o` / `dpu_encoder_phys_vid.o`，确认编译通过。
- 因为面板驱动是 `=y`，整核重编后走既有 `flash-b.sh`（写 boot_b + 回读校验 + 重启）上机。

## 6. 上机验证协议（165Hz）

> 面板切到 165Hz 失败时 `120Hz 回不去，需冷重启`（上游 README 实测）。因此：
> **测试前确认可 SSH（USB 网，不依赖显示）**；失败就 `reboot -f` 恢复；最低风险是 `modetest`。

```bash
# 0) 记录基线
ssh root@192.168.7.1 'modetest -M msm -c | sed -n "1,20p"; \
  cat /sys/kernel/debug/clk/clk_summary | grep -E "dsi0|pclk0"'

# 1) 停合成器（释放 DRM master）
ssh root@192.168.7.1 'pkill -x phoc; sleep 1'   # 或停 phosh-session

# 2) 切到 165Hz（mode #1, connector 36, crtc 103）
ssh root@192.168.7.1 'modetest -M msm -s 36:1904x3040-165@103 2>&1 | head'

# 3) 取证
ssh root@192.168.7.1 'dmesg | grep -iE "dsi|fifo|err" | tail -30; \
  cat /sys/kernel/debug/clk/clk_summary | grep -E "dsi0|pclk0"'

# 4) 恢复（无论成败）
ssh root@192.168.7.1 'reboot -f'
```

验收：dmesg **无** `DSI_ERR_STATE_FIFO`/`dsi_err_worker`，`modetest -c` 显示 165Hz 生效，面板有画面。

## 7. 上机验证结果（2026-10-01 晚，实测）

测试内核：`#27`（本树 + §5 诊断打印 + 面板驱动 `force_hz` 测试钩子 `patches/0007-*`）。

### 7.1 测试 A：冷启动强制 165Hz（`vk30`，cmdline `panel_novatek_nt36536.force_hz=165`）

| 项 | 实测 |
|---|---|
| DSI 诊断 | `timing 1904x3040@165Hz clk=1064606 htot=2068 vtot=3120 -> h_total=336 ha=[32..286] v_total=3120 (bonded=1 dsc=1 wide=1)` |
| 时钟 | `pclk_src=172,972,734` / `byte=108,107,958` / `bit=756,755,712` —— **与 §3 离线预测逐位吻合** |
| CRTC | `status: crtc:103 1904x3040, mixer0/1 各 952x3040, plane fb XR24`（正在扫描出图） |
| 合成器 | `phoc` + Xwayland + GNOME 服务全部正常启动 |
| `wlr-randr` | `1904x3040 px, 165.000000 Hz (preferred, current)`，Enabled: yes |
| **DSI 报错** | **0**（挂载/负载 30s 后仍为 0） |
| 背光 | 511/4095，power=0 |

→ **165Hz 冷启动工作正常**，与旧 README 结论相反。

### 7.2 测试 B：运行时切换（`vk31`，全部 mode，preferred=120Hz）

- `wlr-randr --output DSI-1 --mode 1904x3040@165` 返回 rc=0，但 **phoc 日志显示它始终
  `Modesetting with … @ 120.000 Hz`** —— 合成器把 preferred 钉死，忽略运行时模式变更。
- 因此「live switch」在 phoc 下无法测；这不是驱动/链路失败（无任何 DSI 报错）。

### 7.3 结论与下一步取舍

1. **165Hz 驱动侧已可用**（冷启已验证）；若要日常用 165Hz，最小改动是
   **把 mode table 的 165Hz 放到 preferred**（或加设备级默认），因为 phoc 跟随 preferred。
2. 若要像 120Hz 一样随时切，需要解决 **phoc 的运行时 mode 切换**（output-management 未生效），
   或绕过合成器用 `modetest`（需先停 phoc，见 §6）。
3. §4 的 H1–H5 在当前树上**未触发/已修复**；后续若出现偶发 FIFO，再按 §5 依次排查。

### 7.4 复现/回退

```bash
# 强制 165Hz 冷启（测试钩子）
VERSION=vk-test CMDLINE_EXTRA="panel_novatek_nt36536.force_hz=165" bash scripts/build-boot.sh
scripts/flash-b.sh out/boot-elden-vk-test.img --reboot
# 回退到基线（120Hz，全部 mode）
scripts/flash-b.sh out/boot-elden-vk29.img --reboot
```

设备测试后保留在 `vk31`（120Hz、全 8 档、仅多一条诊断打印），即可用状态。

## 8. 上游参考补丁

| commit | 主题 | 本树是否已含 |
|---|---|---|
| `ac47870fd795` | `drm/msm/dsi: fix hdisplay calculation when programming dsi registers` | ✅ 已含（`bits_per_pclk` 分支） |
| `2d51cfb77daa` + `82159db4371f` | `fix bits_per_pclk` / `CMD mode hdisplay` | ✅ 已含 |
| 上游（lore `20260903-fix-eliza-dsi`，`2028280686f4`） | `round the byte clock rate after reparenting to the PHY PLL` | ❌ 未含 → H5 |
| 上游（lore） | `drm/msm/dsi: don't re-lock the PHY PLL ...` | 未确认 → H4 |
| 作者 `experiments/165hz-mode-table.patch` | 仅把 165/144/90 档加入 mode table | ✅ 本树 mode table 已含全部 8 档 |

## 9. 收尾：165Hz 设为默认（2026-10-01 晚，vk32）

承接 §7.3 的取舍 1，落地最小改动：**把 `csot_pp8807hb1_1_modes[]` 的 165Hz 档移到数组首位**。
`novatek_get_modes()` 用 `count == 0`（即数组首个条目）标 `DRM_MODE_TYPE_PREFERRED`，
故移动顺序即可改默认，无需改代码逻辑。

| 项 | 结果 |
|---|---|
| 改动 | 仅移动 mode table 条目顺序（`patches/0008-panel-165hz-default.patch`，+12/-11） |
| 内核 | `#28`（22:57），Image.gz 20,572,250 B |
| boot.img | `out/boot-elden-vk32.img` 83,562,496 B，sha256 `b892a00e…` |
| 上机 | `flash-b.sh --reboot`：签名读回哈希一致，~18s 回到 Linux |
| `modetest -c` | `#0 1904x3040 165.00 … type: preferred, driver`（8 档全在） |
| phoc | `connector DSI-1: Modesetting with 1904x3040 @ 165.000 Hz` |
| `wlr-randr` | `165.000000 Hz (preferred, current)` |
| 时钟 | `pclk=172,972,734` / `byte=108,107,958` / `bit=756,755,712`（与 §3/§7 逐位一致） |
| DSI 报错 | **0**（冷启 + 运行 2 min 复核后仍 0） |
| 背光 | 511/4095，on |

**结论：165Hz 现已是设备默认刷新率**，冷启直接生效（phoc 跟随 preferred）。
`force_hz` 测试钩子保留（默认 0），可供单模式调试。回退镜像 `out/boot-elden-vk31.img`（120Hz 默认）。
