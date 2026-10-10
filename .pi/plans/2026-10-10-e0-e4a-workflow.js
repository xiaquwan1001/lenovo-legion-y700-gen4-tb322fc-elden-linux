// 并行：E0 Q28 诊断增强补丁（worker，写内核树）+ E4a Q24 FIX-1 DT 补丁（worker，写内核树）
const results = await runs.all([
  runs.run('e0-q28-diag', {
    agent: 'worker',
    task: `E0：Q28 显示间歇诊断增强补丁。仓库 /home/xuqianhui1001/y700-elden，内核树 linux/（当前分支基线见 versions/vk-kernel-identity.tsv，现役诊断内核为 vk75 系）。
必读：
- .pi/plans/2026-10-10-Q28-深研.md（353 行，机制链与补丁要求全部在此）
- .pi/plans/2026-10-09-深夜-Q28寄存器差分-模块化在机验证-槽位险情.md §1（现有 dump 代码位置）
- 内核 drivers/gpu/drm/msm/ 下 dsi_host.c / dsi_ctrl.c / 现有诊断 dump 实现

补丁要求（全部来自 Q28-深研 §3 的 E0 定义）：
1. 把坏发 dump 改为「trigger 后 40×50µs 时间序列」采样（STATUS0/CLK_STATUS/cmd_dma_busy/cmd_engine_busy 等），不再只取单点。
2. 补采寄存器：DMA_SCHEDULE_CTRL、DMA_SCHEDULE_CTRL2、VBIF_CTRL、DMA_FIFO_CTRL、LANE_CTRL，以及 master/slave DSI 各自的预算/状态（诊断内核预算 bug：预算双减、ok 消耗 timeout 预算——一并修）。
3. 打印 panel init_trigger 入口时刻的 STATUS0。
4. 纯诊断增强，不改任何功能路径/时序；checkpatch 干净。
5. 编译验证：交叉编译 aarch64 defconfig 内核通过（用仓库内现有构建脚本 scripts/ 下 build 相关），产出镜像路径报告。
先写 .pi/plans/2026-10-10-E0-诊断补丁.md 记录改动点，再落代码。返回：补丁 diff 摘要 + 镜像路径 + 编译结果。`
  }),
  runs.run('e4a-q24-fix1', {
    agent: 'worker',
    task: `E4a：Q24 FIX-1 DT 补丁（cambistmclkcc 改挂恒开电源域）。仓库 /home/xuqianhui1001/y700-elden，内核树 linux/。
必读：
- .pi/plans/2026-10-10-Q24-深研.md（200 行，FIX-1 定义：cambist 节点 power-domains 从 <&rpmhpd RPMHPD_MX> 改为恒开对等体 RPMHPD_MX_AO 或 RPMHPD_MXC_AO，依据 drivers/pmdomain/pmdomain? 实为 drivers/genpd/ 或 rpmhpd.c:646-665 active_only peer）
- lore.kernel.org 上游参考：Abel Vesa 2026-10-02 对 [PATCH RFC 11/15] arm64: dts: qcom: maili: Add support for cambistmclkcc and camcc 的回复（message-id astvkiexa6ihrg3w7g5lhowvu5g2i37rxofmtlqejuozl3i4cu@34ej3ckphqwc，https://lore.kernel.org/linux-arm-msm/）——看 upstream Maili DTS 怎么写 cambistmclkcc 的 power-domains，对齐上游写法。
- 本树 cambist 节点位置：linux/arch/arm64/boot/dts/qcom/ 下 sm8750 相关 dtsi + 当前设备 overlay/变体（H2）
- DEVICE.md §DT 变体说明

步骤：
1. 先查 rpmhpd.c 确认 RPMHPD_MX_AO/MXC_AO 存在且语义为 always-on peer。
2. 看 upstream Abel Vesa 线程里的 DTS 写法（若可访问：浏览器已登录 lore；或直接读上游 maili dtsi patch 内容）。若拿不到，按 rpmhpd 源码证据自行定 AO 对等体名。
3. 修改 cambistmclkcc 节点 power-domains 一行；保持其余不变；dtbs_check / dt-validate 通过（或报告基线红点）。
4. 交叉编译内核+DTB 验证通过，产出镜像路径。
5. 写 .pi/plans/2026-10-10-E4a-FIX1-DT.md 记录改动与依据。
不动设备、不烧镜像。返回：diff + 依据摘要 + 镜像路径。`
  })
]);
emit({
  e0: results[0] ? { output: results[0].output, error: results[0].error } : null,
  e4a: results[1] ? { output: results[1].output, error: results[1].error } : null
});
