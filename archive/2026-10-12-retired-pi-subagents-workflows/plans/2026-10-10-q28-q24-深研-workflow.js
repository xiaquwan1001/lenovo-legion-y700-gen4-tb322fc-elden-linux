// 深研 Q28（显示间歇失败）与 Q24（熄屏×相机）——只读调查，两路并行
const results = await runs.all([
  runs.run('q28-deep', {
    agent: 'delegate',
    task: `深入调查 Q28 显示间歇失败（只有背光无桌面）。仓库：/home/xuqianhui1001/y700-elden。
必读材料：
- TASKS.md §5 Q28 条目与 INDEX.md §3（现状：断点=面板首条 DCS 写走 bonded 命令 DMA 超时，非 DPU modeset；四项寄存器差异 STATUS0/CLK_STATUS/cmd_dma_busy/cmd_engine_busy；假说=「首次 modeset 命令引擎撞 DYN 像素时钟域切换」）
- .pi/plans/2026-10-09-深夜-Q28寄存器差分-模块化在机验证-槽位险情.md §1
- 内核源码在 /home/xuqianhui1001/y700-elden/linux（msm DRM 驱动：dpu1、dsi 驱动 drivers/gpu/drm/msm/；重点找 DYN/DYN_PCLK_ACTIVE、cmd_dma_busy、bonded DCS 命令路径、panel init 时序）

产出（写到 .pi/plans/2026-10-10-Q28-深研.md，只读设备、不烧任何镜像）：
1. 从内核源码层面解释「bonded DCS 命令 DMA 超时 + DYN pclk 域切换」的机制链：谁开启 DYN 像素时钟（DYN_PCLK_ACTIVE 置位者）、首次 modeset 与后续的路径差异、cmd_dma_busy 卡 1 的硬件含义。
2. 对剩余三个单变量实验逐一做可行性/根因论证（delay 前移 DCS 写 / busy 重触发 / 查谁开 DYN pclk）：每个实验预期改什么代码或时序、预期观察什么寄存器/dmesg 变化、能否证伪假说、风险与上机代价。
3. 给出你认为最优先的一个实验及理由。
纪律：worker 只读源码与文档，不改内核、不动设备。返回时报告文件路径与核心结论摘要。`
  }),
  runs.run('q24-deep', {
    agent: 'delegate',
    task: `深入调查 Q24 熄屏×相机（熄屏→整机硬复位）。仓库：/home/xuqianhui1001/y700-elden。
必读材料：
- TASKS.md §1 G1-22/G1-33 条目（根因=单模块 cambistmclkcc-sm8750 单独加载即触发熄屏硬复位；H1 去 power-domains 7/9 存活、D1 use_rpm=false 6/9、D2 去 critical_cbcrs 7/9、H2 单挂 MX 域 vk63 实测 3 轮 2 掉电——均未根治；用户裁决：互斥二选一，根治改挂 RPMh/驱动侧真修，上游报告已发 2026-10-08）
- archive/topics/UPSTREAM-REPORT-cambist-q24-2026-10-08.md
- 内核源码 /home/xuqianhui1001/y700-elden/linux：drivers/clk/qcom/camcc-sm8750.c（cambistmclkcc 节点）、drivers/pmdomain/ 或 rpmhpd、DSI/显示电源域交互
- DEVICE.md 中 DT 变体说明

产出（写到 .pi/plans/2026-10-10-Q24-深研.md，只读设备、不烧任何镜像、不改内核）：
1. 从内核/电源域层面分析 cambistmclkcc 为何单加载即触发熄屏掉电：它的 power-domains/critical_cbcrs 与 RPMh MX/MXC/MMCX collapse 的关系、为什么 H1/H2/D1/D2 都只能降低频率而非根治、硬复位最可能来自哪一层（RPMh/PIL/TZ/PMIC 看门狗）。
2. 「驱动侧真修」具体指什么：给出 2–3 个可落地的修复方案（如 cambist 驱动不碰 MX 轨、延迟使能、或从 camcc 拆出独立 clock controller），每个附源码依据与预期风险。
3. 查一下上游（linux-arm-msm 邮件列表/lore.kernel.org）对 2026-10-08 报告（cambist/q24）是否有回复——用 web_search/web_fetch 搜 lore.kernel.org。
4. 给出根治路线的优先序与理由。
纪律：只读，不动设备。返回时报告文件路径与核心结论摘要。`
  })
]);
emit({
  q28: results[0] ? { output: results[0].output, error: results[0].error } : 'missing',
  q24: results[1] ? { output: results[1].output, error: results[1].error } : 'missing'
});
