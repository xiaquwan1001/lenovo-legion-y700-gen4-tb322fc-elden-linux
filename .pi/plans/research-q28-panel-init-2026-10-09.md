# 专题 Q28：面板 init 间歇失败（~64% boot 只有背光无桌面）

> 设备：联想拯救者 Y700 四代 / TB322FC / SM8750P / elden，主线 Linux 7.2
> 现象：`panel-novatek-nt36536 ae94000.dsi.0: sending dcs data ff 20 failed: -110` → `Failed to initialize panel: -110`；三供电 vreg_1v8_vddio/6v1_vsp/5v8_vsn 失败时仍 enabled；DSI 连接器 connected/enabled/dpms=On；成功 boot 上相机正常。

## 结论（≤10行）
1. `ff 20` 正是 nt36536 驱动 init_sequence 的**第一条 DCS**（page 选择 `0xff,0x20`），即复位后首条命令就超时（-110=ETIMEDOUT），说明 DSI 命令通路没真正打通，而非某条中间寄存器写错。
2. 该面板（CSOT PP8807HB1-1）在本机是**双 DSI**：上游 Y700 Gen4 DT 用 `qcom,dual-dsi-mode; qcom,sync-dual-dsi;`，驱动对双 DSI 以 dsi[1] 为同步主链发命令。
3. 最强、且与本机 SoC 完全对口的根因：**SM8750 上游 sm8750.dtsi 的 `mdss_dsi1_phy` 参考时钟用了 `RPMH_CXO_CLK`，正确应为 `bi_tcxo_div2`（CXO/2）**，作者明说“错时钟父会让 DSI1 PHY PLL 频率错误、面板不可用”（2026-03-31 修复，Fixes 818ae2b389bc）。双 DSI + DSI1 PLL 频率错 → 同步命令发不出去 → 首条 DCS -110，与“供电 OK / connector connected”完全自洽。
4. 次要、通用方向：复位→首条命令时序窗口、regulator 建立时间、bootloader 遗留 DSI/MDSS 状态（热启 vs 冷启）竞争，都会造成同类“首条命令 -110”间歇失败（有 Rockchip/MSM8916/Waveshare 先例）。
5. 行动：先查项目内核 DT 里 dsi1_phy ref 是否已修 + 是否真为双 DSI，再谈面板驱动时序与重试。

## 证据（每条带可核对 URL）
- **E1 驱动时序 & 首条命令**：`novatek_prepare()` = `regulator_bulk_enable(vddio,vsp,vsn)` → `novatek_reset()`（GPIO 1@11ms/0@1-2ms/1@3-4ms/0@10-11ms）→ `init_sequence()`，首条即 `mipi_dsi_dcs_write_seq_multi(dsi_ctx, 0xff, 0x20)`。复位后到首条命令仅 ~10ms，且 regulator 使能与复位间无建立延时、无 DCS 规范 120ms。— [lkml.iu.edu/2607.1/04381.html](https://lkml.iu.edu/2607.1/04381.html)。证据强度：直接。
- **E2 本机为双 DSI**：Y700 Gen4 DT `qcom,dual-dsi-mode; qcom,sync-dual-dsi;`、`&mdss_dsi1_out → panel_in_1`；`to_primary_dsi()` 双 DSI 返回 dsi[1]（同步在 DSI1）。— [Y700 Gen4 DT 补丁](https://ratatoskr.run/linux-devicetree/2026-07-17320572/t) + E1 代码。直接。
- **E3 SM8750 DSI1 PHY 参考时钟 bug**：`mdss_dsi1_phy` 的 `ref` 从 `<&rpmhcc RPMH_CXO_CLK>` 改 `<&bi_tcxo_div2>`；“错时钟父→DSI1 PHY PLL 频率错误→面板不可用”，Fixes: 818ae2b389bc。— [spinics msg6131736](https://www.spinics.net/lists/kernel/msg6131736.html)、[lkml 2026/3/31/1782](https://lkml.org/lkml/2026/3/31/1782)。后续 eliza 补丁证实“SM8750 同源、同样问题、抄自 SM8650”。直接。
- **E4 io_start 佐证 DSI 基址**：`sm8750_dsi_cfg.io_start = {0xae94000, 0xae96000}`（DSI0/DSI1 ctrl），`mdss_dsi1_phy=phy@ae97000`。即报错前缀 `ae94000`=DSI0 控制器。— [freedreno RFC 08/11](https://lists.freedesktop.org/archives/freedreno/2025-January/035580.html)。直接。
- **E5 SM8750 DSI 需驱动侧显式重设 pixel/byte 父时钟**：PLL 不能在配置前当父，`assigned-clock-parents` 失效，靠 `dsi_clk_init_6g_v2_9()`。时钟/父链是 SM8750 显示最易错处。— [spinics msg5563058](https://www.spinics.net/lists/kernel/msg5563058.html)。直接。
- **E6 “首条 init -110”的通用先例（类比）**：Rockchip `dw-mipi-dsi ... failed write init cmds: -110`，根因=bind()→enable 间 runtime-PM 掉电丢状态，且**内建(=y)比模块更易触发**，修=bind 期间持 PM。— [lore 20210928143413](https://lore-kernel.gnuweeb.org/linux-rockchip/20210928143413.v3.3.Ie8ceefb51ab6065a1151869b6fcda41a467d4d2c@changeid/T/)。类比。
- **E7 bootloader 遗留显示状态需 MDSS 复位**：MSM8916 当 bootloader 已初始化 splash 而 DT 缺 MDSS reset → 重配报 `dsi_err_worker status=6`；v6.17 电源域改动（sync_state 前不断电）放大了此问题。— [gerhold 补丁](https://lore-kernel.gnuweeb.org/lkml/d10424b3-b70f-4166-adca-f81fcb214e04@oss.qualcomm.com/T/)。类比（对应“冷/热启差异”假设）。
- **E8 MSM DSI 主机侧时序修复族**：①`Implement reset correctly`—DSI 软复位拉高后需真实延时(20ms)，wmb 不足（msm8998 停摆）[dri-devel 252083](https://lists.freedesktop.org/archives/dri-devel/2020-January/252083.html)；②`skip the wait for video mode done`—panel pre_enable 发 DCS 时视频引擎等待必然超时刷错误[423030](https://lists.freedesktop.org/archives/dri-devel/2023-September/423030.html)。类比。
- **E9 复位→首命令窗口是“面板专有且双向”**：MediaTek 讨论明确“lcm_reset 到首条 DCS 需 >6ms 且 <40ms，超时/过长都致面板异常”。— [yhbt lore Y7nWKRHQr](https://yhbt.net/lore/dri-devel/Y7nWKRHQr9vumv0V@ravnborg.org/T/)。类比/概念。
- **E10 prepare/enable 与 PHY 锁序（相邻但 errno 不同）**：sofef00 在 `prepare()`（PHY PLL 未锁）发 DCS 得 **EINVAL(-22) 而非 -110**，修法是把 DCS 移到 `enable()`。— [sm8150 issue #1](https://github.com/sm8150-linux-mainline/linux/issues/1)。注意：errno 不符，列为解读非直证。
- **E11 冷启间歇 + 加重试/延时是常见兜底**：Waveshare DSI 冷启暗屏 PR（加稳定延时+重试；维护者对“100ms”持疑，未并入）。— [rpi PR 7182](https://github.com/raspberrypi/linux/pull/7182)。类比。

## 候选路线/修复假设（按代价×把握排序）
- **H1（DT，代价低/把握高）SM8750 DSI1 PHY ref = `bi_tcxo_div2`**：若项目为双 DSI 且内核 7.2 未含此修，则单一根因。E2+E3+E5 直接对口本机 SoC。**先在设备上核对**（见下）。风险：日志前缀是 DSI0(ae94000) 而非 DSI1，需解释（见“需验证 V1”）。
- **H2（DT，代价低/把握中高）复位/上电时序**：`regulator_bulk_enable` 后补建立延时；reset 末→首命令补足 PP8807HB1-1 的 t_init_delay（DCS 常为 120ms）；必要时遵循 E9 的 6–40ms 窗口。E1 显示当前仅 ~10ms 且无 settle。
- **H3（DT，代价低/把握中）bootloader 遗留态**：确保 DSI/MDSS 冷/热启都干净复位（E7 思路）；关掉/接管 cont-splash，避免 Android bootloader 已点屏→内核重配竞争。直接对应“~64% 间歇、失败时供电仍 enabled”。
- **H4（面板驱动，代价中/把握中）首命令重试**：对首条/整段 init 做 -110 重试（E11），**属兜底**，会掩盖真实时序/时钟根因；仅用于验证“是否纯时序”。
- **H5（主机驱动/构建，代价中/把握低中）内建 vs 模块 & PM/时钟保持**：按 E6 对照，把 panel+dsi 设为 =y 或 =m 各测一组；确认 DSI PHY 时钟在 probe→enable 全程不掉。
- **H6（主机驱动，代价高/把握低）prepare/enable PHY 锁序**：E10 家族，但产生 -22 非 -110；仅当读到确证“命令在 PLL 锁前发出”才采纳。

## 落地步骤
1. 全量 `dmesg | grep -iE 'ae96000|dsi1|dsi-phy|ae97000|pll'`，看 DSI1 是否参与、PLL 是否报异常。
2. `ls /proc/device-tree/.../panel@0/ports/` 数端口 + `grep -R . mdss_dsi1_out`，确认**是否真双 DSI**（port@1 是否连到 dsi1）。
3. `cat /proc/device-tree/.../mdss_dsi1_phy/clock-names`（应为 iface/ref）与对应 clocks phandle，比对项目 sm8750.dtsi 的 `mdss_dsi1_phy` `ref` 是否已是 `bi_tcxo_div2`（E3 diff）。
4. `clk_summary | grep -E 'bi_tcxo_div2|dsi'` 核对 DSI PLL 实际频率是否 2× 偏差。
5. 受控对照：cold（关机 60s 再上电）vs warm reboot 各 N 次计数，判断 64% 是否随热启/splash 偏斜（验证 H3）。
6. 若 H1 命中：仅改 `ref` 时钟父 → 复测 N 次 boot；若 H1 未命中：转 H2 时序 + H3 复位，再退到 H4 重试定位。

## 风险与未证实点
- 日志前缀 `ae94000.dsi.0`（DSI0）与“双 DSI 主链应是 dsi[1]/ae96000”存在张力：可能是项目实际按单 DSI(dsi0) 接线、用了旧版驱动、或该字符串由主机侧而非面板侧打印——**这决定了 H1 是否成立，必须实证**。
- 64% 间歇更像时序/竞态；而 E3 的 PLL 错配听起来是“确定性不可用”。若确为 DSI1 时钟错，间歇可能来自 PLL 在错误频率上的边际锁定——属推断，未证实。
- PP8807HB1-1 数据手册未公开，其 reset→首命令窗口/t_init_delay 无法核到规范值（E9 仅为他面板类比）。
- `ff 20` 由封装宏打印、`-110` 由 DSI 主机返回；未取到项目内核里 `sending dcs data ... failed` 的打印点源码，无法 100% 断定超时发生在 dsi0 还是 dsi1。
- NT36532(OnePlus Pad 2) 与 NT36536 是两个在评审中的近亲驱动，init 序列/亮度命令仍在变动（见评审讨论），项目所取内核 commit 的序列细节需以实际树为准。

## 需父进程在设备上验证的项
- **V1**：确认项目 DT 该 panel 是单 DSI(dsi0) 还是双 DSI（是否 `qcom,dual-dsi-mode`/port@1→dsi1），并确认失败 DCS 发生在哪条链路（dsi0 vs dsi1）。这是 H1 成立与否的开关。
- **V2**：核对项目内核 `sm8750.dtsi` 的 `mdss_dsi1_phy` `clocks` 的 `ref` 是否 `<&bi_tcxo_div2>`（E3），及 7.2 树是否已含该 Fixes。
- **V3**：`clk_summary` 读 DSI0/DSI1 PLL 实测频率，比对期望，排除 2× 偏差。
- **V4**：cold vs warm 各 ≥20 次 boot 计数，量化 64% 是否与 bootloader 遗留 splash 相关（H3）。
- **V5**：失败态抓 `regulator_summary` 三轨实测电压 + DSI 控制器 debugfs（`state_info`/`dsi-ctrl-*/`）字节时钟，判定是“命令发不出”还是“发出无 ACK”。
- **V6**：把 panel 与 dsi 主机分别 =y / =m 各测一组（E6），观察成功率变化以排除 probe 顺序/PM 掉电。
