// 2026-10-10 Q28 停项整理：文档整理 + 资料调研 + 本地清理审计（三条并行 lane，都不碰设备）
const REPO = "/home/xuqianhui1001/y700-elden"
const DATE = "20261010"

const docsTask = [
  '你在仓库 ' + REPO + ' 整理 Q28 显示问题的【本地文档进度】，产出一份【单一事实源(SSOT)合订卷】，把散落的多份 q28-* 报告收敛成一个连贯状态。',
  '硬约束：只新建文件，绝不修改/删除任何已有 git 跟踪文件，绝不碰设备，绝不 git commit。',
  '',
  '必读(先读通再动笔)：',
  '- reports/ 下所有 q28-* 文件(research / upstream-diff / upstream-research / two-layers / orchestration / handoff)',
  '- PITFALLS.md 的 #162 #163 #164 #165(Q28 相关)',
  '- reports/q28-handoff-20261010.md 顶部两段横幅(最新状态)',
  '',
  '已定案要点(务必如实体现，不要自创结论)：',
  '1. Q28 = 冷起(display bring-up)间歇失败；真实变量是【冷/暖复位】不是时间(PITFALLS #163)。',
  '2. 根因 L1：bonded 双 DSI 首条 DCS 命令(ff 20)的命令 DMA 引擎 hang(status=0x2200200, master/peer=-110, ~60% 冷起)；L2(DPU ctl reset -22/frame done)是 L1 下游(#164)。',
  '3. 两种独立失效模式(#165)：NOCARD(无 card0，0.86s DSI PLL(0) lock failed + bonded panel Failed to create device link -> 显示子系统没聚齐) 与 STORM(有 card0 但 cmd-DMA 风暴)；同指【冷起首次 DSI PLL/PHY 锁不稳】。delay 只可能盖 STORM 子窗口。',
  '4. 判据三态 NOCARD/STORM/GOOD，须 SSH 读完整 dmesg + 查 card0(scripts/q28-devprobe.sh)；串口 logger 会漏 0-20s。',
  '5. 候选修法：vk84-exp(cmd_trigger delay=1000us) / Method B(取整 byte-clk，落点 generic dsi_link_clk_set_rate_6g)。冷 A/B 仅 T1=exp=NOCARD(n=1)。',
  '6. 上游：Dmitry round byte clock after reparenting 系列(fix-eliza-dsi，经 qualcomm-linux PR #1867 转述)与本树机制吻合，待精确对齐。',
  '',
  '产出(新建)：',
  '- reports/q28-DOSSIER.md：单一事实源，含六节：a) 一句话现状 b) 已定案结论(上面6条) c) 证据索引(指向具体报告/日志/PITFALLS条目/寄存器值) d) 两种失效模式对比表 e) 候选修法与状态 f) 未决问题(冷暖 fastboot-boot 是否等价真 POR、GOOD 启动的 DSI_PLL_lockfail 基线待采、NOCARD 是否有上游修法) + 下一步。每条结论标证据来源(文件/行/dmesg)。',
  '- reports/q28-INDEX.md：Q28 文档地图：列全部 q28-* 文件与各自定位/日期，明确标注 q28-DOSSIER.md 现为 SSOT，其余为过程稿/证据附件；给每个旧报告一句【是否已并入 DOSSIER】。',
  '',
  '自检：报告里每个定案/证据都必须能指到具体来源；不臆测数字。返回：新建了哪两个文件 + DOSSIER 六节各一句摘要 + 你在旧报告里发现但未被上述要点覆盖的任何不一致(无则说无)。',
].join('\n')

const researchTask = [
  '针对性上游/下游调研(只补外部证据，不重复内部已定结论，不碰设备)。',
  '背景：SM8750(TB322FC) 主线 Linux，bonded 双 DSI + 面板 nt36536(csot,pp8807hb1-1)，VIDEO_BURST+DSC。冷起 display bring-up ~60% 失败，两种模式：',
  '(A) NOCARD：内核 0.86s 打 "DSI PLL(0) lock failed, status=0x00000000" x4，紧接 "msm_dsi ae94000.dsi: Failed to create device link (0x180) with supplier ae96000.dsi for .../panel@0" x6，之后 display-subsystem 永不聚合(无 /sys/class/drm/card0)。',
  '(B) STORM：显示绑上了，但首条面板 DCS 写(数据 ff 20)命令 DMA 超时 status=0x2200200 master=-110 peer=-110，init 重试失败，4ms 后 dpu_encoder_phys_vid ctl reset failure -22 / frame done timeout / vblank wait timed out。',
  '',
  '请查并给精确出处(链接/commit/message-id)：',
  '1. 上游 dsi_phy 里 "DSI PLL lock failed" 的代码路径与触发条件；冷起/首次 enable 时 PLL 为何可能锁不上(是否需 post-enable settle delay、phy power_on 与 first transfer 时序约束)；2025-2026 有无相关修复(重点 msm/dsi、dsi_phy_7nm/5nm、SM8750)。',
  '2. "Failed to create device link (0x180) with supplier ... for panel@0" 在上游(drm/msm / driver core)含义：DL_FLAG 0x180 是哪几个 flag、这条 dev_err 出现时是否导致 DSI host probe 失败/probe deferral、bonded 双 DSI 的 panel supplier/peer DSI device-link 创建顺序有无已知 bug 或修复。',
  '3. bonded/dual-DSI 的 panel device-link 与 master/peer DSI probe 顺序，上游 2025-2026 是否有相关提交。',
  '4. STORM 侧：命令 DMA 首条传输 hang 的已知上游处理/等待(cmd trigger 前是否该轮询 CLK_STATUS/等 DYN 位清、或 byte-clk 取整减少 re-lock)。已知 Dmitry round byte clock after reparenting / fix-eliza-dsi 系列，请确认其精确 commit 或 lore message-id 与合入 tag(上次只拿到转述)。',
  '',
  '判定每个命中：直接命中/机制吻合/仅相关。产出：写入 ' + REPO + '/reports/q28-nocard-research-' + DATE + '.md，结构：命中清单(每条:结论+精确出处+置信度) / 对 NOCARD 修复方向的启示 / 对 STORM 与 Method B 的校准(尤其 Dmitry 系列精确 ref) / 未命中与限制。诚实标注 lore/反爬取不到原文的情况。返回该文件路径 + 5-8 行要点摘要。',
].join('\n')

const auditTask = [
  '对仓库 ' + REPO + ' 做【本地条目清理审计】(只读+报告，绝不删除/修改任何文件)。目标：列出可安全清理的本地冗余及体积，交父代决定删除。逐项给：路径、体积(du -sh 或 ls -l 求和)、内容一句、判定(安全删/建议留/需确认)、理由。',
  '',
  '审计范围：',
  '1. logs/serial-*.log：列全部+体积+日期，标出一次性暖起/实验抓取(如 12:48 的 9.4MB、vk75fastboot 等) vs 仍被引用(被 Q28 报告/PITFALLS 当证据的必须标留)。给可归档/可删建议。',
  '2. out/*.img：列全部+体积+vk 号，标出死内核 vk(vk81/82/83，PITFALLS #162)、已完成实验的一次性镜像、现役/待验(vk64/vk84 保留)。',
  '3. /tmp/q28_* 与 /tmp/pi-subagents* 里本会话临时(offset/serial 等)：列+建议(会话结束可删)。',
  '4. .pi/workflows/ 下本会话新建的 *-2026-10-10*.js：列，标已完成可归档/可删。',
  '5. reports/q28-*：列全部+体积，指出彼此重叠(供父代据 DOSSIER 收敛)。',
  '6. versions/ in-flight 白名单里 vk84 实验条目：是否验收后可回收。',
  '7. 其他冗余：重复 *.orig/*.bak/临时 diff、.pi/sessions/subagent-artifacts 旧 lane 产物等(只报不删)。',
  '',
  '产出：写到 ' + REPO + '/reports/local-cleanup-audit-' + DATE + '.md，含：A 安全删清单(带总可回收体积)、B 建议留清单、C 需父代/用户确认清单。返回该路径 + "A 类可回收总计 ~XXX MB" + B/C 关键项 3-5 条。绝不执行任何 rm。',
].join('\n')

const results = await runs.all([
  { key: "docs",     agent: "worker",     task: docsTask,     output: "reports/q28-docs-lane-" + DATE + "-RESULT.md" },
  { key: "research", agent: "researcher", task: researchTask, output: "reports/q28-nocard-research-" + DATE + "-SUMMARY.md" },
  { key: "audit",    agent: "scout",      task: auditTask,    output: "reports/local-cleanup-audit-" + DATE + "-SUMMARY.md" },
])

function ref(r){ return (r && r.status) + " :: " + ((r && r.outputReference) || "") }
return { docs: ref(results[0]), research: ref(results[1]), audit: ref(results[2]) }
