// FIX-3 驱动补丁（glm-5.3-flash，写内核树）+ M1 资产树收窄重试（qwen3.8-flash，不编译）
const results = await runs.all([
  runs.run('fix3-patch', {
    agent: 'worker',
    model: 'ustc-pool/glm-5.3-flash',
    task: `FIX-3：cambistmclkcc PM 生命周期驱动补丁（lazy-on + suspend quiesce）。仓库 /home/xuqianhui1001/y700-elden，内核树 linux/（当前 HEAD 68e8ab2c0，分支 elden/vk53-hw）。
必读：
- .pi/plans/2026-10-10-E4a-FIX1-DT.md（E4a 判定：换轨无效，FIX-3 是剩余正解）
- .pi/plans/2026-10-10-Q24-深研.md §FIX-3 定义（probe 不编程；lazy-enable 进 runtime_resume；runtime_suspend 彻底关 PLL+CBCR 静默）
- linux/drivers/clk/qcom/cambistmclkcc-sm8750.c（本树该驱动）与 drivers/clk/qcom/common.c（probe 生命周期 :340/:357-359/:431——无条件编程 PLL0 + 开 SLEEP_CLK CBCR(0x40f8) + 结尾 pm_runtime_put 把票交回 genpd = 悬空半成品态）
- linux/drivers/clk/qcom/camcc-sm8750.c 对照（camcc 有 GDSC/消费者不死）

补丁要求：
1. probe 路径不再无条件编程 PLL/开 critical CBCR——把这些移到 runtime_resume（lazy-on：首个消费者 enable 时才编程）。
2. runtime_suspend 里彻底 quiesce：关 PLL + 关 CBCR（补上 H1 缺失的静默），保证熄屏/RPMh collapse 时该块完全静默。
3. 保持 cambist MXC 单票 DT 不变（68e8ab2c0 已落）。
4. 纯驱动侧修复；checkpatch 干净。
5. 编译验证：交叉编译 Image.gz + dtbs + modules 通过（scripts/build-kernel.sh 或 make -j ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-）。
6. 写 .pi/plans/2026-10-10-FIX3-PM-lifecycle.md 记录改动点与依据链。
返回：diff 摘要 + kernelrelease + 编译结果。不烧镜像、不动设备。`
  }),
  runs.run('m1-tree', {
    agent: 'worker',
    model: 'ustc-ai-1/qwen3.8-flash-next',
    task: `M1（收窄版）：干净上游资产树——只建树 + payload 重放清单，不编译。仓库 /home/xuqianhui1001/y700-elden。
必读：
- archive/topics/UPSTREAM-REVIEW-2026-10-04.md（payload = 相对主线 v7.2 的 125 改 + 11 新文件 ≈12.4k 行，分级 A/B/C/D 与推进顺序）
- TASKS.md §7 M1 定义

步骤（时间盒 20 分钟内完成，超时立即报告部分产出）：
1. 查 RESOURCES.md / UPSTREAM-REVIEW 档案确认 upstream tip 口径（GEEKiDoS 上游 origin 或 gitlab 镜像 y700-elden-kernel main=fe54fcfff）与 payload 清单位置。
2. 建 build/m1-upstream/ 目录：从 upstream tip 浅克隆（或本地现有 geekidos-linux 树）+ 列出 payload 重放清单（125 改+11 新文件的 commit/hunk 对应表，剔除 D 类与 vk 历史）。
3. 不编译。产出 = .pi/plans/2026-10-10-M1-资产树清单.md（树位置 + 重放清单 + 与 vk81 镜像功能等价对照：哪些 payload 已含）。
若克隆/树不可得，报告具体障碍并给出本地等效资产路径。返回：清单文件路径 + 摘要。`
  })
]);
emit({
  fix3: results[0] ? { output: results[0].output, error: results[0].error } : null,
  m1: results[1] ? { output: results[1].output, error: results[1].error } : null
});
