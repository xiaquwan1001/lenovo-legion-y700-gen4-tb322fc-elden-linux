# 上游命中与回移审计（7.2.y 稳定 / 7.3 周期 / lore 在途）

日期：2026-10-12 · lane `upstream`（worktree `/home/xuqianhui1001/y700-wt/wt-upstream*`，baseline `base/20261012-3727144`，内核分支 `elden/lane-upstream` @ `5d01d3324`）
来源：`cdn.kernel.org` ChangeLog-7.2.1…7.2.10；torvalds `v7.3-rc7` 浅克隆（`v7.2..v7.3-rc7` = 8427 提交）；lore.kernel.org Atom 检索（18 个主题）。

---

## A. 已回移并提交（3 commit，共 14 补丁，+197 行），编译验证中

| 补丁 | 出处 | 文件 |
|---|---|---|
| ASoC: qcom: q6apm: keep the graph start count in sync with the DSP | 7.2.6 `78ac8fc2`（=7.3 `daa7ffd76`） | `sound/soc/qcom/qdsp6/q6apm.c` |
| ASoC: qcom: qdsp6: Zero-initialize AudioReach module config | 7.3 `9c9fb79f` | `q6apm-dai.c` |
| ASoC: qcom: lpass-cpu: use DAI table index for playback constraints | 7.2.10 `f11336e6` | `lpass-cpu.c` |
| bus: mhi: host: Flush the posted write after MHI_SOC_RESET_REQ_OFFSET | 7.2.6 `84e713a8` | `drivers/bus/mhi/host/main.c` |
| firmware: qcom: scm: add trace events for the SMC call interface | 7.2.6 `0e93bb22` | `qcom_scm_trace.h`（新增 143 行） |
| drm/msm/dsi: round 6G byte clock rate to the PLL-achievable value | 7.2.5 `d152b582`（Kavan Smith，已回溯到 5.10/5.15/6.1/6.6/6.12） | `dsi_host.c` |
| drm/msm/dp: Drop dev_pm_opp_set_rate(0) | 7.2.6 `e532b800` | `dp_ctrl.c` |
| drm/msm/dpu: Drop sneaky dev_pm_opp_set_rate(0) | 7.2.6 `54b17a85` | `dpu_core_perf.c` |
| drm/msm: Only fini scheduler after successful init | 7.2.6 `09b360eb` | `msm_ringbuffer.c/.h` |
| drm/msm: Recover HW before retire hung submit | 7.2.6 `dc64cf9d` | `msm_gpu.c` |
| drm/msm/dpu: clear pending peripheral flush state | 7.2.8 `fd25668f` | `dpu_hw_ctl.c` |
| drm/msm/adreno: fix autosuspend cleanup during teardown | 7.2.8 `ebc273b4` | `adreno_gpu.c` |
| drm/msm/a6xx: Fix stale rpmh votes after suspend | 7.2.6 `51fcee9d` | `a6xx_gmu.c` |
| arm64: dts: qcom: sm8750: Fix swapped USB QMP PHY supplies（仅参考板 mtp/qrd） | 7.2.6 `407b05cf` | `sm8750-{mtp,qrd}.dts` |

提交：`98fda55ca`（audio）/ `a00945de6`（mhi+scm）/ `169d74806`（drm/dts）。镜像身份计划 `LOCALVERSION=-vk115-upstream`（registry vk115 已占位）。

## B. 冲突，需人工 rebase（本树已偏离上游）

| 补丁 | 出处 | 冲突点 |
|---|---|---|
| drm/msm/dsi: round the byte clock rate after reparenting to the PHY PLL | 7.2.8 `c59e4a90`（主线 `202828068`） | `dsi_host.c:129`；本树有 **SM8750 专有 set_rate-before-parent workaround**（另一会话已做成 `patches/q28-methodB-round-byteclk.patch`，vk114 未过冷起） |
| drm/msm/dsi: Drop dev_pm_opp_set_rate(0) | 7.2.6 `00008e6f` | `dsi_host.c:549`（同源偏离） |
| drm/msm: RCU-free the scheduler-containing ring and VM objects | 7.2.8 `713abac5` | `msm_ringbuffer.h:55`（本树 scheduler 结构已被本地改动） |
| drm/msm/a6xx: Fix IRQ storm during msm_recovery | 7.2.6 `8fc6a356` | `msm_gpu.c:552`（与 Recover-HW 补丁顺序/上下文冲突；a6xx 对本机 a8xx 价值低） |

未取到正文（cgit 503，需重试）：`ASoC: codecs: lpass-wsa-macro: rewrite the interpolator volume`（7.2.10 `c374d710`）。

## C. 本地问题 → 上游命中

### Q24（camcc+cambist 配对 × 熄屏 → SoC 级复位）
- **本方报告已在档**：`[Regression v3] SM8750: cambistmclkcc + camcc together hard-reset the SoC on display blank`（2026-10-12，`https://lore.kernel.org/all/179179331695.677917.11557670447411700010@mail.ustc.edu.cn/`）。
- 上游同时在推进的两条相邻线：`[PATCH v2 00/48] clk: qcom: Use common probe data for always-on clocks`（2026-09-24，涉及 cambist/GDSC 语义）；`[PATCH v21 14/14] arm64: dts: qcom: kaanapali-mtp-camera-s5kjn5: Add DT overlay`（2026-10-12，Qualcomm 回复中引用 cambistmclkcc 语境）。→ 建议把 RFC v2 挂到这两条线程上要 reviewer。
- 无“已合并”的修复：7.2.y/7.3 里 **0 条** 涉及 cambistmclkcc/camcc 的修复提交。

### Q28（bonded 双 DSI 首条 DCS 命令 DMA hang）
- 7.3 周期内 drm/msm 仅 17 条，DSI 相关 **仅 1 条**（`202828068` round-after-reparent，本树冲突见 §B）。
- 在途/相邻：`[PATCH v3] drm/msm/dpu: disable the slave encoder before the master`（v3 2026-10-02，已进 `drm-msm-next-2026-10-11` **for v7.4**）；`[PATCH] drm/msm/dpu: round up the compressed INTF width`（2026-10-05）→ **v7.4 方向与 bonded 双 DSI 顺序强相关**，值得跟踪/试验。
- 面板侧：`[PATCH] drm/panel: fix novatek-nt36536 dependencies`（Arnd, 2026-09-25，Neil 已 Reviewed，**Applied → drm-misc-next `f11277810402`**）→ Kconfig 依赖修正，本树（7.2 基线）未含，属低风险回移候选。

### Q26 / G1-6 WiFi beacon-loss（本会话重要否证）
- 上游 `ath12k: spurious beacon-loss disconnects on WCN7850 (regression in 7.2.6)`（2026-10-09）**已被作者撤回**：`#regzbot invalid: not a kernel regression`（2026-10-10）。原因=作者机器 2026-09-22…10-05 关机，且**另一台 iwlwifi 客户端在同一时刻同样丢 beacon**（AP 侧问题）。
- ⇒ **不要**为该“回归”做本地修补或升级 7.2.y 归因；本树 `patches/0012`（仅在转发 beacon 时启用 ARM conn-loss timer）仍可作为行为加固，但**没有上游依据**。
- 在途：`[PATCH v2 6/7] ath12k: add PCIe link recovery retry`（2026-10-11，Red Hat）——与本地 `0001-ath12k-shorten-mhi-timeout` 同域（MHI/PCIe 恢复）。

### G1-4 音频 / tplg
- **本地 0011 有同题在途 RFC**：`[RFC PATCH] ASoC: qcom: q6apm-lpass-dais: start the graph at prepare`（回复 2026-10-09 Fairphone: “last blocker to upstream Fairphone (Gen. 6) speaker support”）→ 未合并、等 maintainer；可考虑与作者合流或直接提交本地方案。
- `[RFC PATCH 0/4] ASoC: qcom: q6apm: correct PCM formats and error handling`（2026-10-08）：format 长度、STOP 失败处理、readiness/provider 生命周期、V2 data completion 假进度 → 与本地 `0005/0009` 同域，值得逐个评估。
- 7.3 已合并的新能力：`topology-driven Audio IF support`、`q6apm-lpass-dais TDM DAI ops`、`q6prm Audio IF clock IDs`、`q6dsp-lpass-ports QAIF 改名`（皆 non-stable，功能级）。

### G1-3 触觉（aw86927/aw86937）
- 上游正在收 **Awinic 系列**：`[PATCH v2 0/3] AW8695 haptic driver`（Fairphone, 2026-10-01）+ `dt-bindings: input: awinic,aw86927: Add Awinic AW8697`（2026-10-02，**Krzysztof Acked-by**）→ 绑定文件 `awinic,aw86927.yaml` 已被 AW8695 系列复用。
- ⇒ 本地方案（`patches/0003`）应改为**扩展现有 aw8695 驱动 + 已有绑定**（而非独立 dt-bindings），这是最现实的上游化路径。

### G1-24 重启通道 / reboot-mode
- `[PATCH v26 00/10] Implement PSCI reboot mode driver for PSCI resets`（2026-09-28）：新增 `power: reset: reboot-mode` + per-SoC `psci reboot-modes`（talos/monaco/lemans/kodiak）。本机依赖的 PSCI SYSTEM_RESET2 vendor reset 正在**标准化**（本地为自研钩子 `elden/vk41-psci-reboot`）→ 上游化应改为 DT `reboot-modes` 描述而非代码钩子。

### G1-6 TF 卡
- `[PATCH v1 2/3] mmc: msm_sdhci: add HS200/HS400 support`（2026-08-27/28，讨论中）→ 若后续重启 TF 线，先看此系列是否覆盖本机 SDHC 实例。

### G1-34 传感器 / ADSP
- `[PATCH v2] arm64: dts: qcom: eliza: Add FastRPC support`、`[PATCH 2/2] misc: fastrpc: Allocate entire reserved memory for Audio PD in probe`、`[PATCH] misc: fastrpc: Don't fail probe when the SDSP memory assign fails`（2026-09-22~10-02）→ 与本地 `5d01d3324`（sm8750 ADSP fastrpc non-secure-domain）同域；无 SSC/hexagonrpcd 的 AP 侧上游方案（lore 检索 `hexagonrpc sensor_pd` 0 命中）。

### G1-29 UEFI
- 无新上游命中（Mu 平台 issue 仍待回复）。

## D. 待办
1. 编译验证 vk115（进行中）：`/tmp/vk115-build.log`，目标 `Image.gz` + `dtbs`，含符号守卫（`gcc_sm8750`/`msm_dsi_host_bonded_cmd_trigger`/`rpmh`）。
2. §B 四条冲突补丁人工 rebase（DSI 两条要等 Q28 会话的 round workaround 定型后再动）。
3. 重取 `lpass-wsa`（`c374d710`，cgit 503）。
4. 评估 v7.4 在途 DPU bonded 顺序补丁（`disable the slave encoder before the master`）——Q28 潜在正解方向。
5. nt36536 Kconfig 依赖补丁（drm-misc-next `f11277810402`）单独小回移。

---

## E. ★ 设备本体（Y700 Gen4 / elden）上游线索（本会话新发现）

作者：**Pengyu Luo `<mitltlatltl@gmail.com>`**（与本项目 `reference/upstream-pengyuluo/` 同一来源）。

| 系列 | 状态（本会话核实） |
|---|---|
| `drm/panel: Add Novatek NT36536 panel driver`（v1–v3，2026-06/07） | **已进主线**：`panel-novatek-nt36536.c` 与 `novatek,nt36536.yaml` 均在 **`v7.3-rc7`** 中（上游加入 commit `75a5dbd1f4f7`）。本树同名文件是**衍生版**（558 行 vs 上游 486 行，含 elden 改动 + `d02658e63` 重试） |
| `[PATCH v2 0/2] Introduce Lenovo Legion Y700 Gen4`（2026-07-26，DTS + bindings） | **未进主线**（`v7.3-rc7` 无该 DTS、Makefile 无 elden）；但已出现在 0-day 机器人镜像 `intel-lab-lkp/linux` commit `2c4ddee5c903`（2026-08-11 应用轨迹）→ 大概率在 **arm64 for-next / 7.4 待合** |
| 评审意见（Konrad Dybcio / Abel Vesa / b4 / LKP bot） | 已抓取原文：DTS 里 `enable-gpios` 拼写（aw99706 backlight）需修、`mdss`/`dispcc` 使能不一致、CDT 段落无关、fb/altmode 取舍等 |
| LKP 0-day 报告 | `<202608170237.IhJo7vY0-lkp@intel.com>`：`sm8750-lenovo-elden.dtb` `backlight@76 (awinic,aw99706): 'enable-gpios'` 校验失败 → **我们的本地 DTS 若同源需同步修** |

**结论**：本项目的面板驱动 + 设备 DTS 存在**同时存在的上游提交线**（同一社区作者）。上游化的正确路径不是从零提交，而是：① 把本树 elden 增量（Q28 重试、force_hz 模式、backlight probe 顺序、DP/USB 改动）**拆成对 `75a5dbd1f4f7` 的增量补丁**；② DTS 以 `2c4ddee5c903` 为基线补差量，避免与在审 v2/v3 冲突。

## F. 已闭环问题的上游对照（无论解决与否）

| 本地问题 | 本地结论 | 上游命中 |
|---|---|---|
| G1-4 音频 tplg/MI2S | 已通 | 7.3 合并 topology-driven Audio IF / TDM DAI ops / q6prm Audio IF clk IDs；在途 RFC 4/4（q6apm PCM format+错误处理） |
| G1-5 相机出流 | 已通 | 上游 **kaanapali-mtp-camera-s5kjn5 DT overlay v21**（2026-10-12，Qualcomm 回复中，讨论可选 `vddm`）；无 sm8750 camss 专用新补丁 |
| G1-7 BT 配对 | 已通 | 7.3 大批通用加固（RFCOMM/ISO/L2CAP）；**无 wcn7861 专用补丁**；`[PATCH v2 4-6/7] ath11k/ath12k: PCIe link recovery retry`（在途） |
| G1-8 GPU/基准 | 已出分 | `[PATCH 1/6] drm/msm/a8xx: Add support for Adreno 830 GPU` 讨论中；`drm-msm-next-2026-10-11` 已收 a8xx 相关（for v7.4） |
| G1-9 DP | 已通 | sm8750 DP 无新命中；7.2.y 收 7 条 `drm/msm/dp` 修复（wide-bus/YUV420/PUSH_IDLE），本批已回移 drop-opp |
| G1-11 CDSP | 已通 | 无专门上游命中（fastrpc 侧 3 条见 §C） |
| G1-25…G1-28 桌面/主题/亮度 | 已闭环（用户态） | 不属内核上游；无内核侧命中 |
| G1-31/32 工具与 OpenRC | 已通 | 与主线无关 |
| G1-6 TF 卡 | 搁置 | `mmc: msm_sdhci: add HS200/HS400 support`（v1，2026-08，讨论中） |
| G1-34 传感器（部分） | 重力/旋转已通 | **0 条** hexagonrpcd/SSC 上游命中（AP 侧仍无人做） |

## G. 风险与纪律提醒
- **不要**基于 `WCN7850 beacon-loss @7.2.6` 做回归假设（已撤回）。
- 本会话回移批次**未上机**（`verification=NOT_TESTED_ON_DEVICE`）；仅编译层面验证。
- DSI 相关两条冲突补丁与 Q28 会话的 `q28-methodB-round-byteclk.patch` **同源**，合并前必须与 Q28 会话对齐，避免台架污染。
