// Q28 上游补丁核实 + Method B 修复起草（2026-10-10）
// 两 lane 并行，均不碰设备：
//   U = researcher：拉上游三处 commit 的精确 diff + 落在哪个 tag + dsi_host.c 相关 hunk
//   F = worker：据本地树 + 已有调研起草「最小安全 Method B（取整 byte-clk）」补丁（只写草稿，不编不提）
// 父代独立复核 worker 草稿 + 用 U 的精确 diff 校准后才谈编译/上机。

const COMMON = `
背景（勿重复论证，直接用）：
- 机型 y700-elden = SM8750P，bonded DSI + CMD mode + DSC。Q28 = 首条命令 DMA 触发时概率性 -110 超时（CMD_MODE_ENGINE_BUSY 永不清），寄存器差分只在坏发多 CLK_STATUS 的 DYN_PCLK_ACTIVE|DYN_CMD_PCLK_ACTIVE 两位置位；好/坏 clk_summary 完全一致。
- 关键新事实（2026-10-10 用户实机纠正，见 PITFALLS #163）：Q28 与时间无关、全天候；真实变量是**复位类型**——**冷起基本失败、暖复位基本成功**。机制解读：暖复位不清 DSI PLL/PHY 锁态 → 冷起首次 modeset 才走脆弱的 PLL re-lock 路径 → 撞 cmd DMA 触发。这与上游「byte-clk 未取整 → 每次 set_rate 都 retrigger PLL re-lock」高度吻合。
- 已知上游线索（来自 reports/q28-upstream-research-20261010.md，可能不完整/需你核实）：
  * 6cd33b6f4155 Kavan Smith "drm/msm/dsi: round 6G byte clock rate to the PLL-achievable value"
  * bc484ede914d Kozlowski revert 上面（"broke DSI display on Eliza and probably SM8750"）
  * Dmitry Baryshkov fix-eliza-dsi 系列 (2026-09-03) "drm/msm/dsi: round the byte clock rate after reparenting to the PHY PLL"（正解）
- 本树代码：linux -> 符号链接到 geekidos-linux。关键函数 dsi_link_clk_set_rate_6g_v2_9()（约 448 行）在 of_device_is_compatible(...,"qcom,sm8750-dsi-ctrl") 分支里 clk_set_rate(msm_host->dsi_pll_byte_clk, msm_host->byte_clk_rate) 用的是**未取整**值。现场数字：请求 byteclk 133.076 MHz，PLL 实际达成 108.108 MHz（差 23%）。`

const U = `任务：把上游这三处的**精确补丁内容**取回来（上次 lore.kernel.org 被反爬挡住）。
必须用 web_providers(action:"test") 确认哪个后端可用，然后优先用能过 Cloudflare 的后端（Firecrawl/Bright Data 经 web_fetch，provider 参数），或改用镜像：
  - 首选 kernel.org 的 commit 视图 / patch 直链：https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/patch/?id=<sha>
  - 或 dri-devel / linux-arm-msm 在 patchwork / lore 的镜像站；或 github 上游镜像 commit 页（如 6by9/linux、torvalds/linux mirror）。
产出（写进 reports/q28-upstream-diff-20261010.md）：
1. 三个 commit 各自的完整 diff（尤其 dsi_host.c 的 hunk），原文照抄，标注来源 URL + 取到/取不到。
2. 每个 commit **落在哪个 tag / 哪个 release**（用 git describe 语义或 lore 的 base）：这决定我们能否直接 cherry-pick。明确：Dmitry 的正解进了主线哪个版本？还是仍在 review/未合入 stable？
3. dsi_link_clk_set_rate_6g / dsi_link_clk_set_rate_6g_v2_9 / byte_intf_clk_rate / esc_clk_rate / bitclk_rate 之间的取整/派生关系，用上游最终版代码说明「取整应放哪、哪些派生量要一起改」。
4. 若确实取不到某些 URL，列出试过哪些后端/镜像 + 各自失败原因，别只说失败。
只补外部证据，不改本地代码，不碰设备。`

const F = `任务：起草「最小安全 Method B」补丁 = 把 byte-clk 取整修复移植到本树 SM8750 路径。
纪律：**只写草稿文件 patches/q28-methodB-round-byteclk.patch（unified diff，基于当前 linux 树），不要编译、不要 git add/commit、不要改设备。** 父代会用 researcher 的精确上游 diff 校准后才决定编译。
步骤：
1. 读 linux/drivers/gpu/drm/msm/dsi/dsi_host.c：dsi_link_clk_set_rate_6g_v2_9()、dsi_link_clk_set_rate_6g()、msm_host->byte_clk_rate / byte_intf_clk_rate / esc_clk_rate / bitclk_rate 在哪里被赋值和消费（grep 全文件）。
2. 判清**正确性风险**：若把取整后的 rate 回写 byte_clk_rate，哪些派生量（byte_intf_clk_rate=byte/2?、esc=byte/esc_div、bitclk=byte*7/8、DSC pclk）会失配、会不会引入回归。
3. 据此写**最小改动**：仅在 SM8750 分支用 clk_round_rate() 取整、回写 msm_host->byte_clk_rate 与 msm_host->byte_intf_clk_rate（及必要的派生量），使后续 clk_set_rate 在 CCF 里成 no-op、不再每次 retrigger PLL。取整失败/返回 0 时退回原行为。
4. 补丁里加注释引用上游 commit 与本树行号；单独写一份 patches/q28-methodB-NOTES.md 说明改了什么、风险点、为何不碰其它派生量、以及「上机验证前必须做的静态检查清单」。
产出：patches/q28-methodB-round-byteclk.patch + patches/q28-methodB-NOTES.md。`

const [u, f] = await Promise.all([
  runs.run('upstream-diff', { agent: 'researcher', task: COMMON + '\n\n' + U, output: 'reports/q28-upstream-diff-20261010.md' }),
  runs.run('methodB-draft', { agent: 'worker', task: COMMON + '\n\n' + F, output: 'patches/q28-methodB-NOTES.md' }),
])

return {
  upstream: { ok: u.ok, output: u.outputPath || null, error: u.error || null },
  methodB: { ok: f.ok, output: f.outputPath || null, error: f.error || null },
}
