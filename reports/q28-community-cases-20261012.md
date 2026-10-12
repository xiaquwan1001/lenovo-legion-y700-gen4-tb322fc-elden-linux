# Q28 STORM — 社区相似案例检索（2026-10-12）

> 目的：按用户要求，查社区/上游是否有与 Q28（SM8750 bonded DSI 冷起首条 DCS `-110` 命令 DMA 超时、`#60` 构建身份高坏发）相似的案例与已有修法。
> 检索源：Exa / Brave（web_search）、ratatoskr/lore 归档、LWN、regzbot、freedreno。

## 0. 结论速览

1. **本机这块面板已有上游驱动**：Pengyu Luo 的 `drm/panel: Add Novatek NT36536`（目标就是 **LENOVO Legion Y700 Gen4** 的 CSOT PP8807HB1-1 双联面板），v1/v2/v3（2026-06→07）。**本树 `panel-novatek-nt36536.c` = 该上游驱动 + elden 加的 retry 循环**，结构对齐（init 在 `prepare`、`prepare_prev_first=true`、dual-DSI 同步在 DSI1）。
2. **上游确有 SM8750/Eliza DSI 的破屏回归与修法**（与我们的 STORM 相邻但非同一现象）：`6cd33b6f4155`「round 6G byte clock rate to PLL-achievable」**打破 Eliza（疑含 SM8750）显示**，被 revert，再由 **`2028280686f4`（Dmitry Baryshkov：「round the byte clock rate after reparenting to the PHY PLL」）** 修好，已进 **mainline + stable 6.1/6.6/6.12/6.18/7.2.y**。
   - **本树两个 commit 都不在**（`NOT-IN-TREE`）⇒ 我们处于「v2.9 host 有 reparent、无取整」状态，正是项目所谓 **Method B** 要补的那段。
3. **同类的 DCS `-110` 超时修法**（不同 SoC/面板）：`drm/panel: visionox-rm69299 split DSI commands into enable/disable`（Guido Günther, 2026-04）修 `msm_dsi … wait for video done timed out` / `sending DCS … failed: -110`，核心是**把 DCS 命令放到 `enable`/`disable` 而不是 `prepare`**（并提到 `disp_cc_mdss_*clk status stuck at 'on'`）。我们的 nt36536（同上游）把 init 放 `prepare`——与上游一致，但值得对照。
4. **未找到**「内核构建身份/`.rodata` 布局决定某次冷启成败」的公开案例。这更像本机冷启竞态的表现，社区无直接先例（SM8750+mainline 装机量极低）。
5. **可行动**：(a) 按上游 `2028280686f4` 校准 Method B；(b) 到上游 nt36536 线程/`dri-devel` 报告我们的冷启 `command DMA timeout` 观察。

## 1. 上游 nt36536 驱动（本机面板，直接相关）

- 系列：`[PATCH v1/v2/v3 0/2] drm/panel: Add Novatek NT36536 panel driver`，Pengyu Luo `<mitltlatltl@gmail.com>`。
  - v2: https://ratatoskr.run/linux-devicetree/2026/07/17215421/t （2026-07-05）
  - 绑定：`csot,pp8807hb1-1` + `novatek,nt36536`，dual-link 10-bit，`vddio/vsp/vsn` 三供电 + `reset-gpios`。
- 关键实现（与本树一致）：`novatek_prepare()` 里 `regulator_bulk_enable` → `novatek_reset()` → `init_sequence()`（首条即 `0xff 0x20`，与我们日志 `sending dcs data ff 20 failed` 对应）→ DSC PPS → 背光；`prepare_prev_first=true`；dual-DSI 主用 `dsi[1]`。
- 本树差异：`novatek_prepare()` 加了 **elden retry 循环**（`init_sequence` 失败 → `novatek_reset` → 重试 2 次），对应 `d02658e63`「retry bonded-DSI init sequence on -110」。上游无此重试。

## 2. byte-clock 取整回归与上游修法（＝Method B 的社区出处）

- **regzbot**：「drm/msm/dsi: DSI display on Eliza and probably SM8750 broken」 https://linux-regtracking.leemhuis.info/regzbot/regression/generic/6cd33b6f4155/
  - culprit：`6cd33b6f4155`「drm/msm/dsi: round 6G byte clock rate to the PLL-achievable value」（在 byte RCG 还没 reparent 到 PHY PLL 时取整 → 得到 19.2 MHz 假值 → PHY 编程错频 → 破屏）。
  - 先 revert（`bc484ede914d`），再 **正规修：`2028280686f4`「drm/msm/dsi: round the byte clock rate after reparenting to the PHY PLL」**（freedreno msg46766，2026-09-03），已进 mainline + stable（6.1/6.6/6.12/6.18/7.2.y）。
- **本树核验**：`6cd33b6f4155 / bc484ede914d / 2028280686f4 / 35cbe34c3704` **全部 NOT-IN-TREE**。
- 关联机制（SM8750 DSI v2.9）：PLL 是 byte/pixel RCG 的父，**必须先 prepare PLL 再 reparent**；v5 修订强调「只在 PLL prepared 时 reparent」。这正是本树 `dsi_clk_init_6g_v2_9` / `dsi_link_clk_set_rate_6g_v2_9` 的语境。
- ⇒ 项目 `patches/q28-methodB-round-byteclk.patch` 的落点应与 `2028280686f4`（generic `dsi_link_clk_set_rate_6g()` 顶部、reparent 之后）一致；此前 `q28-round-vk86.patch` 亦声明按 msg46766。

## 3. 相似的「首条 DCS -110 超时」修法（不同 SoC/面板）

- `drm/panel: visionox-rm69299: Split DSI commands out into enable/disable`（Guido Günther，2026-04-27，dri-devel）：
  - 症状：`msm_dsi ae94000.dsi: [drm:dsi_cmds2buf_tx] wait for video done timed out` / `sending DCS SET_DISPLAY_OFF failed: -110`（在 blank/unblank 时）。
  - 修法：DCS 命令放 `enable/disable`（不是 `prepare`）；并提到 `disp_cc_mdss_{pclk0,byte0,byte0_intf}_clk status stuck at 'on'` 偶发。
  - 与我们的差异：我们是 **cmd-DMA timeout（首条 DCS 冷起）**，不是 wait-for-video；但它证明「DCS 发送阶段/时序」是 msm DSI 的一类真实坑。
- 其他通用案例（非 Qualcomm 或早期）：i.MX8M DCS timeout、nwl-dsi `DSI transfer timed out`、msm 8916 DCS 抖动 —— 均为「DCS 时序/阶段」类，非 SM8750 冷启。

## 4. SM8750/Eliza 上游背景

- `[PATCH v5/v6 00/24] drm/msm: Add support for SM8750`（Krzysztof Kozlowski）：DSI v2.9 host、`dsi_clk_init_6g_v2_9`、PLL reparent 流程；「DSI works!」。
- `[PATCH v2/v3 0/8] drm/msm: Add Qualcomm Eliza SoC support`：Eliza MDSS = SM8750 演化，DSI 面板可用。

## 5. 未命中项（诚实）

- **没有**公开案例把「某次冷启成败」归因到**内核构建身份/`.rodata` 布局**（`#N` 位数）。这是本机观察；社区无先例可引用。
- **没有**找到 `command DMA timeout: status=0x2200200` + `bonded command DMA failed: master=-110 peer=-110` 的 SM8750 + nt36536 报告。

## 6. 建议

1. **Method B 校准到上游 `2028280686f4`**（先确认本树是否本该有；本树缺 → 按上游语义移植到 generic 落点），用 PINUTS + 已知 GOOD 身份台架做冷起 A/B。
2. **可选**：在 `dri-devel` / 上游 nt36536 系列回帖报告本机冷启首条 DCS `-110` 现象（附 dmesg/寄存器），征询 Dmitry/Pengyu 意见。
3. 治法优先仍是**日常镜像用 3 位 `#N` 新身份重编**（见 `PITFALLS #195`），先恢复日常可用；Method B 是根治方向的候选。

## 7. 参考链接

- nt36536 v2：https://ratatoskr.run/linux-devicetree/2026/07/17215421/t
- byte-clk 修：https://www.mail-archive.com/freedreno@lists.freedesktop.org/msg46766.html
- regzbot：https://linux-regtracking.leemhuis.info/regzbot/regression/generic/6cd33b6f4155/
- rm69299：https://yhbt.net/lore/dri-devel/161b2074-ba4a-4456-a236-955a2575c5cd@ixit.cz/t/
- SM8750 drm: https://lwn.net/Articles/1019429/
- Eliza: https://lwn.net/Articles/1064661/
