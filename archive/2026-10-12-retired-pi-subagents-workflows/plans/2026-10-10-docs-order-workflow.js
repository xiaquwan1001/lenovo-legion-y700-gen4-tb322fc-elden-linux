// 文档对账整理（worker，可写）+ 下一步实验顺序分析（reviewer，只读）——两路并行
const results = await runs.all([
  runs.run('docs-audit', {
    agent: 'worker',
    task: `文档对账整理 y700-elden 仓库（/home/xuqianhui1001/y700-elden）。
任务：
1. 先跑 bash scripts/check-doctor.sh，记录 FAIL/警告项。
2. 对账 6 份维护文档（INDEX.md / TASKS.md / DEVICE.md / RESOURCES.md / RUNBOOK-BRINGUP.md / PITFALLS.md）之间的数字漂移与口径冲突：重点核对 §0 进度总览完成度数字、G1/G2 未解项 ID（Q28/Q24/Q26/G1-6）、INDEX §3 指针与 TASKS §1 任务行是否一致、2026-10-09/10-10 最新裁决（Q26 WiFi 关闭、G1-6 TF 卡搁置、Q24 互斥口径、Q28 寄存器差分）是否已同步到所有引用处。
3. 只修漂移/死链/口径冲突，不新增结论、不改任务状态语义；每个修改保持最小 diff。若发现需要用户裁决的矛盾（如两文档数字无法判定谁是 SSOT），不擅自改，列出来。
4. 重跑 check-doctor.sh 验证全绿（或只剩固有警告）。
返回：修改文件清单 + 每处修改一句话理由 + 残留待裁决项。`
  }),
  runs.run('exp-order', {
    agent: 'reviewer',
    task: `下一步实验顺序分析（只读）。仓库：/home/xuqianhui1001/y700-elden。
背景：G1 ~90%，剩余两大未解 Q28（显示间歇，断点已收窄，剩 delay/busy 重触发/查 DYN pclk 三个单变量实验）、Q24（熄屏×相机，用户已裁互斥二选一，根治等上游回复）；未开工 G1-8 CPU/GPU 基准、上游化 M1–M5；G2 卡在 Play 登录与传感器 HAL 部署。
必读：TASKS.md §0/§4/§5/§7、INDEX.md §3、.pi/plans/ 下最新计划（Q28 寄存器差分 2026-10-09、深研产物 .pi/plans/2026-10-10-Q24-深研.md 与 .pi/plans/2026-10-10-Q28-深研.md 若已存在则纳入）。
产出（写到 .pi/plans/2026-10-10-下一步实验顺序.md）：
1. 候选实验清单：Q28 三单变量实验、Q24 根治方案验证、G1-8 基准、M1 干净上游资产树、G2 传感器 HAL 部署验证、C0 Android 对照取证（U1 覆盖前必做、不可复得）等，每项附上机代价（镜像烧写/重启次数/风险）。
2. 排序依据：日常可用性收益 × 证据不可复得性 × 上机代价 × 依赖关系；明确哪些必须串行（如 C0 需 U1 接入、Q28 实验依赖当前 boot_b 口径）。
3. 给出推荐顺序（含并行项）与每项的验收判据，标注哪些零写盘可做。
纪律：只读，不改文档。返回文件路径与推荐顺序摘要。`
  })
]);
emit({
  docs: results[0] ? { output: results[0].output, error: results[0].error } : 'missing',
  order: results[1] ? { output: results[1].output, error: results[1].error } : 'missing'
});
