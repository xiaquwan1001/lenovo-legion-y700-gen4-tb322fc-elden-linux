# Q28 NOCARD 窄口径补证（2 问）

日期：2026-10-10 ｜ 网络访问 8/8（2 次搜索 + 6 次取原文，其中 1 次被反爬拦截）｜ 只补外部事实，不碰设备。

命中判级速览：
- **Q1（要精确 ref）＝ 直接命中**（拿到主线 hash + 首个包含 tag + patchwork/lore id）。
- **Q2（SM8750 / 7nm DSI PHY 冷起 "DSI PLL lock failed" 修复）＝ 直接命中**（上游 2026-09-24 补丁，错误字符串与我们日志逐字相同；**但该补丁未合入且作者自陈会打挂 SM8350**）。
- Q2 后半（power_on→首条 transfer 的 settle delay 讨论）＝ **未命中**（本轮单次检索内未见）。

---

## Q1 结论：可 cherry-pick 的精确 ref —— 直接命中，置信度 **高**

**主线 commit：`2028280686f4fa78e2f1f6dede4b6c1fd782b9e3`**
`drm/msm/dsi: round the byte clock rate after reparenting to the PHY PLL`，Dmitry Baryshkov，
作者日期 2026-09-03；cgit master log 显示进入 torvalds/master 的 age = 2026-09-15。

| 项目 | 值 | 出处 |
|---|---|---|
| 主线 hash（cherry-pick 用） | `2028280686f4fa78e2f1f6dede4b6c1fd782b9e3` | [torvalds cgit commit 页](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=2028280686f4fa78e2f1f6dede4b6c1fd782b9e3)（经 cgit `qt=grep` 检索，一手） |
| 首个包含 tag | **v7.3-rc4**（在 rc3→rc4 变更记录内）→ 首个正式版 tag **v7.3** | [Linus: Linux 7.3-rc4](https://lkml.org/lkml/2026/9/20/1213) |
| Message-ID | `<20260903-fix-eliza-dsi-v1-1-3474a6c9f2e0@oss.qualcomm.com>` | commit trailer 内 lore 链接：https://lore.kernel.org/r/20260903-fix-eliza-dsi-v1-1-3474a6c9f2e0@oss.qualcomm.com |
| Patchwork | https://patchwork.freedesktop.org/patch/750496/ | 同一 commit trailer（一手） |
| 列表原文（patch 全文） | https://lists.freedesktop.org/archives/dri-devel/2026-September/593696.html | 一手，已逐字取到 |
| stable 回合约 | linux-6.18.y `78cb2ee981594ef7da05333fc6be7a56e7598b0b`（committer Greg KH 2026-09-25，Sasha Levin sign-off）→ 随 **6.18.54** 发布 | [stable cgit commit](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/commit/?h=linux-6.18.y&id=78cb2ee981594ef7da05333fc6be7a56e7598b0b)；[LWN 6.18.54](https://lwn.net/Articles/1096821/) |
| 其他 stable | 7.2.8 变更记录亦列 | [lkml.iu.edu 7.2.8](https://lkml.iu.edu/2609.3/04326.html)（二手佐证） |
| trailer | `Fixes: 6cd33b6f4155 ("drm/msm/dsi: round 6G byte clock rate to the PLL-achievable value")`、`Reported-by: Abel Vesa`、`Reported-by: Krzysztof Kozlowski`、`Reviewed-by: Konrad Dybcio`、`Tested-by: Konrad Dybcio # SM6115P J606F`、`Tested-by: Abel Vesa`、`Reviewed-by: Abel Vesa`、`Assisted-by: LLM` | stable commit 页（一手） |
| diffstat | `drivers/gpu/drm/msm/dsi/dsi_host.c`，19 insert / 17 delete | 同上 |

代码改动（一手 diff）：`unsigned long byte_intf_clk_rate` → `bool byte_intf_clk_div_2`；
`clk_round_rate(msm_host->byte_clk, msm_host->byte_clk_rate)` **从 `dsi_calc_clk_rate_6g()` 搬进
`dsi_link_clk_set_rate_6g()`** 并写回 `msm_host->byte_clk_rate`；`byte_intf_clk` 的 rate 由已 round 的
byte_clk_rate 现算（div_2 时 /2）；`msm_dsi_host_power_on()` 只保存 `div_2` 标志。

commit message 直引（与 SM8750 路径吻合）：
> "DSI 6G v2.9 hosts (SM8650, **SM8750**, Kaanapali, etc.) reparent the byte and pixel RCGs to the DSI PHY PLL at runtime from `dsi_link_clk_set_rate_6g_v2_9()`, after the PHY has been enabled. However `dsi_calc_clk_rate_6g()` runs earlier, in order to compute the bit clock request for the PHY. At that point the byte RCG still has its reset parent (XO), so `clk_round_rate()` returns a bogus rate, which then ends up in the PHY bit clock request and **the PLL gets programmed to a wrong frequency, breaking the panel**."

### Q1 移植前置条件（researcher 推断，非来源原文）
`Fixes:` 指向 `6cd33b6f4155`，而本 commit 的 diff 是**把 `clk_round_rate()` 从 `dsi_calc_clk_rate_6g()` 删掉**——
说明 2026-09-03 时该调用仍在树中（与上一轮"6cd33b6f4155 已被 `bc484ede914d` revert"的转述并列看，需核对顺序）。
⇒ 移植前先查本树 `dsi_calc_clk_rate_6g()` 是否含 `clk_round_rate()`：若无（本树 base 早于 6cd33b6f4155），本 commit 对本树**既不必要也不可干净 apply**。

---

## Q2 结论：上游确有针对 7nm DSI PHY "PLL(0) lock failed" 的修复补丁（未合入）—— 直接命中，置信度 **高**

**补丁：`[PATCH] drm/msm/dsi/phy: power up the digital top before starting the 7nm PLL`**
作者 Dmitry Baryshkov，首发 **2026-09-24 03:51:03 +0300**；2026-09 至 10 月在 lkml 讨论中。
取到的是 Dmitry 本人 2026-10-01 的回复，其中**逐字引用了自己补丁的完整 commit message**（一手页面）：
https://lkml.rescloud.iu.edu/2610.0/02665.html
（标题页：`Re: [PATCH] drm/msm/dsi/phy: power up the digital top before starting the 7nm PLL`，Date: Thu Oct 01 2026 - 19:30:44 EST）

### 机制（原文逐字，与 NOCARD 签名逐条对照）
> "`dsi_pll_7nm_vco_prepare()` de-asserts PLL_SHUTDOWNB and starts the PLL, **but leaves the PHY digital top powered down; only `dsi_7nm_phy_enable()` sets DIGTOP_PWRDN_B. The PLL cannot lock in that state.** This went unnoticed for as long as the PLL was only ever prepared from the DSI host's enable path, after the PHY had been enabled."
>
> "Since commit **acf7a91d0b0e** ("clk: qcom: dispcc-sm8250: Enable parents for pixel clocks") the clock framework enables the PHY PLL on its own while applying the DT's `assigned-clock-parents` from `of_clk_set_defaults()`, **at probe time, before the PHY has been touched**. The lock fails, the failed enable leaves the pixel clock with an **unbalanced enable count**, and the **retries on every probe attempt stall the boot for tens of seconds**:"
> ```
> DSI PLL(0) lock failed, status=0x00000000
> PLL(0) lock failed
> dsi0_phy_pll_out_dsiclk already disabled
> WARNING: drivers/clk/clk.c:1188 at clk_core_disable+0x244/0x24c
>  clk_core_disable
>  __clk_set_parent_after
>  clk_core_set_parent_nolock
>  clk_set_parent
>  of_clk_set_defaults
>  platform_probe
> ```
> "**CMN_CTRL_0 reads 0x20** at the failing attempt: PLL_SHUTDOWNB set, DIGTOP_PWRDN_B clear. **Setting DIGTOP_PWRDN_B alone makes the same PLL lock**, with no rate change and no other register touched."
>
> "Power up the digital top together with the PLL bias, and power it down again with it. The normal enable path is unaffected: `dsi_7nm_phy_enable()` holds the bias reference and writes CMN_CTRL_0 in full anyway."
>
> `Fixes: 1ef7c99d145c ("drm/msm/dsi: add support for 7nm DSI PHY/PLL")`
> `Fixes: acf7a91d0b0e ("clk: qcom: dispcc-sm8250: Enable parents for pixel clocks")`
> `Assisted-by: LLM` ｜ `Signed-off-by: Dmitry Baryshkov`

### 状态（重要，直接读自作者本人）
> **Dmitry 2026-10-01：** "For the reference, **picking up this patch breaks the boot on SM8350 HDK with the disconnected HDMI display output.** I'll try debugging it later."

⇒ 判定（interpretation，非原文直述）：截至 2026-10-01 该补丁**尚未合入上游**，且作者已知它带副作用。
本会话第 8 次访问想直接查 torvalds cgit 是否含 "power up the digital top" 以确认合入状态，**被反爬拦截（Making sure you're not a bot）**，故"未合入"依据是作者自述 + 时间线，未拿到"mainline 里查无此提交"的正面证据。

### 与本树 NOCARD 的对应关系（判级与注意事项）
- **错误串直接命中**：我们现场日志里的 `DSI PLL(0) lock failed` / `PLL(0) lock failed` 与该上游报告**逐字相同**，且都出自 7nm DSI PHY 驱动、都发生在 **probe 期 `of_clk_set_defaults()`**（对应我们 ~0.86s 的早期时间戳），并伴随 CCF enable 计数错乱 + 反复重试拖慢启动——与"间歇性无 card0（component bind 未成功 → DRM 不出 card）"这一层级后果可衔接。
- 上游触发前提（需在本树自查，researcher 推断）：
  1. 本树是否含 `acf7a91d0b0e`（`clk: qcom: dispcc-sm8250: Enable parents for pixel clocks`）或其等价改动（使 CCF 自行 prepare/enable PHY PLL）。
  2. 我们的 MDSS/DSI DT 是否在 `dsi0_phy_pll_out_dsiclk` 一类 pixel clock 上写了 `assigned-clock-parents`（或 `clocks=` 让 clk 核在 probe 期 set parent）。
  3. 失败现场 `CMN_CTRL_0` 是否 = 0x20（PLL_SHUTDOWNB=1、DIGTOP_PWRDN_B=0）。若读到 0x20 即可判**同一根因**；若不是，则该补丁只是同症状异因。
  4. 现场是否也出现 `dsi0_phy_pll_out_dsiclk already disabled` + `clk_core_disable` WARNING —— 这是"CCF 侧计数错乱"的强特征，与"仅 panel 时序差"可区分。
- 注意 **SM8750 用的是 DSI PHY v7.0（不是老 7nm 通用路径）**：上游系列里明确 SM8750 "Only reparent byte and pixel clocks while PLLs is prepared"（见下"仅相关"条目），所以本补丁是否覆盖 SM8750 的 `dsi_phy_7nm` 代码路径需按本树实际文件确认（`drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c` vs 新 v7.0 路径）。**researcher 推断，未取原文核实。**
- **不要盲目 cherry-pick**：作者自陈会打挂 SM8350（HDMI 输出、显示器未接场景）。若要试，建议在本地做成"只在 probe-time prepare 路径上临时置 DIGTOP_PWRDN_B"的最小改动，并保留可回退。

### Q2 相邻证据（仅相关，snippet 级，未取原文）
- SM8750 DSI PHY v7.0 系列 "[PATCH v7 06/13] drm/msm/dsi/phy: Add support for SM8750"（dri-devel 2025-06）：https://lists.freedesktop.org/archives/dri-devel/2025-June/511185.html ；同系列 thread 列表出现 "Fix pll freq check for clock ..." 字样。
- LWN「drm/msm: Add support for SM8750」变更注记：**"SM8750: Only reparent byte and pixel clocks while PLLs is prepared"**（时序/顺序约束，正是"PHY 未就绪前不得 reparent/prepare"这一类约束）：https://lwn.net/Articles/1024743/ —— **snippet 级，未取原文**。
- 同期同族问题（非 DSI）：`phy: qcom-qmp-ufs: Fix kaanapali PHY PLL lock failure after SM8650 G4 fix`（linux-phy 2026-04）http://lists.infradead.org/pipermail/linux-phy/2026-April/030474.html —— 佐证"SM8650 世代修 PLL 会连带改坏别的 SoC"这一上游反复出现的模式（类比 SM8350 回归）。**仅相关。**
- **未命中**：未检索到任何上游关于 `dsi_phy` `power_on()` → 首条 DCS transfer 之间需要 **settle delay / t-clone / t-pre** 的讨论或补丁，也未见 SM8750 冷起首次 enable 概率性 lock 失败的独立 bug report。本轮只用 1 次检索覆盖该子问，**不构成穷尽性结论**。

---

## 矛盾 / 需并存记录
1. 上一轮转述称 `6cd33b6f4155` 已被 `bc484ede914d` revert；但 `2028280686f4` 的 diff 显示 `clk_round_rate()` 在 `dsi_calc_clk_rate_6g()` 中**仍存在**并被其删除，且 `Fixes:` 直接指向 `6cd33b6f4155`。两者并存 ⇒ revert 与 fix 的先后/覆盖关系本轮**未核**。移植前必须按本树实际代码判定。
2. LWN **5.15.222** 变更记录出现同主题行（5.15 无 DSI 6G v2.9 / SM8750 代码路径）⇒ 疑为 stable changelog 噪声，对本树无意义，已按低价值处理。
3. Q2 补丁"修复 lock 失败"与"打挂 SM8350 HDMI"同时为真：上游尚未收敛出一个对所有 7nm 平台安全的版本。

## 取不到的限制说明（诚实标注）
- 第 8 次网络访问 `git.kernel.org/.../torvalds/linux.git/log/?qt=grep&q=power+up+the+digital+top` **被反爬页拦（"Making sure you're not a bot!"）**，因此：
  - 未能正面确认 DIGTOP 补丁是否已进 mainline（以及其主线 hash / 是否被 drm-msm fixes tag 收录）；
  - 该补丁的 **Message-ID / patchwork 编号未取到**（本轮只取到 lkml 归档镜像页，未访问 lore 原页）。
- Q2 相邻条目里 LWN 1024743 与 dri-devel 2025-June/511185 为 **snippet 级引用**，未取原文。
- Q2 后半（settle delay）只做了 1 次检索即触及访问上限。

## Sources
**Kept（一手，已取原文）**
- [dri-devel 593696 — Dmitry 原始 patch 全文](https://lists.freedesktop.org/archives/dri-devel/2026-September/593696.html) — Q1 全部 ref / trailer / diff。
- [stable 6.18.y commit 78cb2ee9…](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/commit/?h=linux-6.18.y&id=78cb2ee981594ef7da05333fc6be7a56e7598b0b) — 给出 **Upstream commit 2028280686f4**、patchwork 750496、完整评审/测试 trailer。
- [torvalds master log（cgit grep）](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=2028280686f4fa78e2f1f6dede4b6c1fd782b9e3) — 主线 hash + age 2026-09-15。
- [Linus: Linux 7.3-rc4](https://lkml.org/lkml/2026/9/20/1213) — 首个包含 tag（v7.3-rc4 → v7.3）。
- [lkml 镜像：Re: power up the digital top before starting the 7nm PLL](https://lkml.rescloud.iu.edu/2610.0/02665.html) — Q2 核心：完整 commit message + 逐字错误串 + SM8350 回归自述。
- [LWN 6.18.54](https://lwn.net/Articles/1096821/) — stable 发布归属。

**Deprioritized / Rejected**
- regzbot 总表、Debian/launchpad changelog、lkft-triage 6.18.54-rc1 —— 纯二手转发，已被一手替代。
- LWN 5.15.222 中的同主题行 —— 5.15 无相关代码路径，疑噪声。
- linux-phy kaanapali QMP-UFS lock failure —— 非 DSI，仅作模式类比。
- TI/NXP 论坛、googlesource vendor dtsi —— 与本问题无关。

## Next steps（最有用的后续，全部不需网络）
1. 本树核 `drivers/gpu/drm/msm/dsi/dsi_host.c`：`dsi_calc_clk_rate_6g()` 是否含 `clk_round_rate()`；决定 `2028280686f4` 可 apply 性。
2. 本树核 `git merge-base --is-ancestor acf7a91d0b0e HEAD` + grep MDSS/DSI DT 的 `assigned-clock-parents`（是否让 clk 核 probe 期 set parent 到 dsi PHY PLL）。
3. 坏发时读一次 `CMN_CTRL_0`（期望 0x20 = PLL_SHUTDOWNB|!DIGTOP_PWRDN_B）与是否伴随 `dsi0_phy_pll_out_dsiclk already disabled` + clk_core_disable WARNING ⇒ 一击定根因归属。
4. 待网络宽裕再补：lore 上 DIGTOP 补丁的 Message-ID/patchwork 与当前合入状态（本轮被反爬拦）。
