# Q24 / Q28 在上游化标准下的重新定义（2026-10-15）

> 输入：`reports/upstream-policy-20261013.md`（三问门 §1、Q3 违例 §3、隔离清单 §6、M 衔接 §7）、`reports/b5-dsi-resoc-20261013.md`（DSI 一族 56 hunk 逐条分类 + P1–P4 切分）、`archive/topics/UPSTREAM-REPORT-{cambist-q24-v3,q28-bonded-dsi}-*.md`（已发报告与回信）、`reports/{q24-mech,q24-r9,q24-noc,q28-dispcc-static,p1-upstream-dsi,m1-display-rootcause-analysis}-*.md`。
> 口径：**状态与样本数仍以 `TASKS/README.md` §5 为准**；本文只回答一个问题——「把 Q24/Q28 放进上游化标准，它们分别是什么、能交付什么、卡在哪、怎么判完成」。

## 0. 数字结论（一页）

| 项 | 上游可交付 | 需重构 | 需上游协作 | 必须隔离（永不进包） | 上游化完成度 |
|---|---|---|---|---|---|
| **Q28** | **1 枚已备料**（DSI PHY `PLL_SYSTEM_MUXES` 1 行，`patches/upstream/m1-2026-10-14/0001`）+ **报告已归档** | **B5 P1–P4**（DSI 一族 6 文件 / **+887 −64 / 56 hunk**） | 四问已发（lore 命中，直发 0 回复）；**Pengyu 指路 = DPU dsi clk source select（10-bit C-PHY plane）** | bonded 命令路径（18 hunk）／诊断钩子／看门狗／PINUTS 构建身份 | **≈35%** |
| **Q24** | **0 枚补丁可提**（v1/v2 的 DT 补丁已**自撤**；`use_rpm=false`、去 `critical_cbcrs` 均无效）——合规产物 = **报告 + RFC v3（已发、已归档、Taniya Das 已回信）** | 无（本地无合规代码可提） | 四问在 v3 里已问；**上游有 consumer = Kaanapali camera DT overlay v21 14/14** | `cam-mode.sh`/相机⇄熄屏互斥/零相机 cmdline（发行版策略） | **≈30%** |

**一句话**：Q28 是「**一枚上游缺口 + 一次结构重构 + 一条待定位的控制器外故障**」；Q24 是「**上游模型问题（裸时钟控制器 × camcc 配对）+ 一个需要外部仪器的电气/时序根因**」。两者都**没有**可直接发的修复补丁——这正是上游标准要求它们以「证据 + 重构 + 协作」而非「workaround」形态存在的原因。

## 1. 标准回顾（只列与这两项相关的硬条款）

- **三问门**（policy §1）：Q1 有无子系统框架？Q2 有无同类芯片可扩展？Q3 这段逻辑是**硬件事实**还是**软件策略**？
- **A/B/C/D 分级**（审查档案）：A = 方向正确可直接发；B = 结构需重做；C = 私有/需隔离；D = 永不进上游。
- **Q3 违例 ⇔ 发上游前必清**（policy §3）；**未定根因不得写成硬件事实**。
- **薄下游层预算 1–2k 行**（policy §6）；超预算 = 有东西没被 DT 化或没复用现成驱动。
- **无设备证据不得写"已修复"**（`.pi/AGENT-OPS.md` §3）：运营可用 ≠ 根因解决 ≠ 上游化完成——**这三个判据在本文里分开记账**。

## 2. Q28：新标准下的四层分解

### 2.1 现状（不变）
冷起首次 modeset 首条 DCS `ff 20` 的 **bonded 命令 DMA 超时**（`status=0x2200200`，master=-110/peer=-110）；坏发 ~50%、按时间成簇；**故障态不在 DSI 控制器内部**（`vk125` 复位终态后 DYN 位仍被重新拉起）；七臂否证；恢复只能整机复位；日常靠看门狗。上游栈对照已**悬置**（P2b 复测 4/4 未复现、且从未做面板实测）。

### 2.2 分层表（= 上游化的实际工作面）

| 层 | 内容 | 类别 | 归属产物 | 门 | 现状 |
|---|---|---|---|---|---|
| **L1 上游缺口** | bonded 模式 `PLL_SYSTEM_MUXES=0xc0` 不在上游（`44784327815b` 撤了 `93c97bc8d85d`）⇒ E1b = 在 `dsi_7nm_phy_enable()` 预置块补 1 行 | **A** | `patches/upstream/m1-2026-10-14/0001` | checkpatch `--strict` 0E/1W/0C；pristine `git am` rc=0；目标文件编译 rc=0 | ✅ **已备料**（投递冻结中）；机上已验（L1=0/L2=0 + `dsi_isr`=41 + 用户目视确认） |
| **L2 结构重构** | DSI 一族散落 10 处 `of_device_is_compatible`；上游按「硬件版本寄存器」选 cfg，SM8750 与 sm8650 撞 `V2_9_0` ⇒ vendor 只能逐处兜 | **B** | `reports/b5-dsi-resoc-20261013.md` §2.4 的 **P1–P4**（P0 可独立先发） | P1 机械零行为 + checkpatch；P2/P3 数据/DT（binding 硬门）；**P4 行为改动必须重跑 Q28 冷起风暴** | 🟡 **P1 机械样例已编译+checkpatch 全绿**（`b5/dsi-compat-cleanup` `a57c1ae791`）；P1 前提「SM8750 报 V2_9_0」**未上机读 `REG_DSI_VERSION` 证实** |
| **L3 现场代码** | bonded 命令路径 18 hunk（H01/H02/H12/H19/H20/H23/H26/H27/H34/H37–H42/H45/H46）：配对 prepare→stage→trigger→arm→wait→poll、坏发即放弃、`msm_dsi_host_enable` 时机从 pre_enable 挪到 enable | **B/Q3 待证** | 先 `cfg->bonded_cmd` 门控的 **P4**；若上游答复「非上游模型」⇒ 整组移入 **M5 下游 patchset**，M1 命令路径回退上游 `need_sync` 双写 | P4 默认仅 SM8750 打开 + 注释标 `RFC/根因见 Q28 报告`；**H14/H23 魔数需 stock 佐证才可当硬件事实** | 🟡 待上游四问答复定落点 |
| **L4 实验/诊断（永不进包）** | `dsi_cmd_delay_us` cmdline、D1 timing `dev_info`、`patches/q28-*` 诊断补丁、看门狗、PINUTS/构建身份做法 | **D** | `patches/`（实验层）、`scripts/` | 只允许存在于实验树/发行版 | ✅ M1 树已剔除（`grep` 0 命中）；**B5 各补丁不得顺手加回** |
| **L5 上游协作** | 报告已发（2026-10-12T23:53:58Z，lore `/linux-arm-msm/` 命中，本地-归档逐字节同）；四问 = bonded 时序约束／cmd-DMA 是否应可恢复／DSC video 冷起 erratum／需要哪些现场 | — | `archive/topics/UPSTREAM-REPORT-q28-bonded-dsi-2026-10-12.md` | 24–48 h lore 复核；回信看 INBOX + Junk | 🟡 直发 0 回复；**Pengyu 公开指路**：面板驱动够用，缺口在 **DPU/时钟源选择（10-bit C-PHY plane）** ⇒ 与 B5/P4 同向 |

### 2.3 新标准暴露的三个缺口（旧口径看不到）

1. **P1 前提未实证**：`msm_dsi_cfg_get()` 改为 compatible 消歧前，必须先上机读 SM8750 的 `REG_DSI_VERSION`（当前是从上游表 + 报告推断）。**这是 L2 的第一块砖**。
2. **「行为中性」缺形式化**：B5 的 P1–P3 声明对 Q28 行为中性，但**没有任何采样协议验证**（Q28 时间成簇 ⇒ 单样本不可比）。新标准要求：P2/P3 落地时**必须**与 P4 分离 + 同会话交替采样（`PITFALLS #223`）。
3. **根因「控制器外」与标准分层冲突**：L3 是「vendor 命令路径」，而故障态指向 **DSI 控制器之外（dispcc/INTF 侧动态时钟请求）**。⇒ 若上游答复倾向「dispcc/INTF 侧」，Q28 会**跨出 B5 的范围**（进入 clk/dispcc 子系统），需按 Q1 重新选框架、另立条目（当前无 SM8750 dispcc 驱动：Lenovo stock 未含 clk 驱动）。

### 2.4 「完成」的定义（三判据分开记账）

| 判据 | 含义 | 当前 |
|---|---|---|
| **运营可用** | 坏发可自恢复/兜底（看门狗 ~50%→75%；现 boot_b = M1 基线） | 🟡 缓解 |
| **根因解决** | 能指名哪一条硬件/时序条件被违反，并有可复现的反证 | ❌ 未达成 |
| **上游化完成** | ① L1 补丁被收（或其等价物进树）；② L2 重构合入；③ L3 有明确定位（上游特性 or M5 隔离）；④ L4 全在包外 | ❌ ≈35% |

## 3. Q24：新标准下的三层分解

### 3.1 现状（不变）
最小触发 = **`camcc-sm8750` + `cambistmclkcc-sm8750` 配对 + 真实熄屏**；致死 = SoC 级复位且 28–42 s **自恢复**（5/5）；PMIC PON 块逐字节同、无硬件看门狗、NoC/BCM 票否证、GPU runtime-PM 无关；致死点随显示电源转换移动。

### 3.2 分层表

| 层 | 内容 | 类别 | 归属 | 门 | 现状 |
|---|---|---|---|---|---|
| **上游模型（Q1/Q2）** | `cambistmclkcc` 以「无 GDSC、无 consumer 的裸时钟控制器」形态使用是否正确？**必须与 `camcc` 同时 probe** 才触发 | **上游侧问题**（非我们补丁缺陷） | RFC v3 四问之 §1 | 上游答复 + 上游复现 | 🟡 **已回信**：上游有 consumer = **Kaanapali camera DT overlay v21 14/14** ⇒ 该形态在上游**是被使用的**，故问题落在「配对/顺序约束」而非「能不能这么用」 |
| **DT 事实** | `cambist` 节点 `power-domains=<MMCX>,<MX>` + `required-opps` | **DT（Q3 正解）** | 上游口径即 `MMCX+MX` | `dt-doc-validate` | ✅ **已回到上游形态**；H1 臂（DTB-only 还原上游）**否证其杠杆性** ⇒ **不留本地 DT 变体**（撤），符合"DT 只放硬件事实" |
| **驱动侧补丁** | `use_rpm=false`（6/9）、去 `critical_cbcrs`（7/9）、H1/H2 电源域变体 | **无可提** | — | — | ✅ 全部否证/撤回 ⇒ **新标准下正确做法 = 不提"没根因的补丁"**（policy：未定根因不得写成硬件事实） |
| **协作件** | RFC v3（2026-10-12T08:22Z 发出 + 2026-10-13 follow-up）四问：裸时钟控制器支持性／相机 BIST 与显示在同一 MMCX/MX 域的**顺序约束**／SM8750 事后可读的**复位原因源**／根因未明前发行版安全默认 | — | `archive/topics/UPSTREAM-REPORT-cambist-q24-v3-2026-10-12.md` | lore 归档 + 回信 | 🟡 已归档 + Taniya Das 回信 |
| **需外部仪器的实验** | 外部电流/电压测量（电气/时序级靶点） | — | `.pi/plans/2026-10-12-Q24-静态复核与实验计划.md` 系 | 需人手 + 仪器 | ⬜ **唯一未开工的关键一步** |
| **隔离件（发行版策略）** | `elden_nocamera=1`、`cam-mode.sh on/off`、相机⇄熄屏互斥、"相机不固化进日常态" | **D（策略）** | `scripts/`、cmdline、`/etc/modules-load.d` | 永不进上游包 | ✅ 已隔离（**不得**以 DT/C 代码形式混入上游包） |

### 3.3 新标准暴露的缺口

1. **"最小触发 = 配对"缺上游可读的因果**：配对是**统计事实**，不是机制解释；上游答「有 consumer」只说明形态合法。⇒ 下一步不是再扫 DT/驱动变体（已 3 轮否证），而是**外部测量**或**拿到复位原因源**（RFC 四问之 §3）。
2. **上游消费方对照可做静态取证**：Kaanapali camera DT overlay v21（14/14）既是上游 consumer，就是**"上游是怎么配的"的参照**——可静态比对 `power-domains`/`required-opps`/probe 顺序，找我们的差异（低代价、无需设备）。
3. **复位原因源未查**：AOP/CPUCp crash-health 寄存器或 smem scatter —— 属"取得根因所需的现场"，比继续二分更有价值。

### 3.4 「完成」的定义

| 判据 | 含义 | 当前 |
|---|---|---|
| 运营安全 | 日常零相机模块 ⇒ 熄屏安全；需相机时先禁熄屏 | ✅ 已达成（用户裁决口径） |
| 根因解决 | 指出被违反的硬件/顺序约束并反证 | ❌ 未达成（靶点已转电气/时序级） |
| 上游化完成 | ① RFC 有上游复现/确认；② 若为驱动/DT 缺陷 ⇒ 按正确层提交；③ 若为硬件/PMIC 特性 ⇒ 上游文档化 + 我们的隔离件留在包外 | ❌ ≈30% |

## 4. 对照与优先级（新标准视角）

| 维度 | Q28 | Q24 |
|---|---|---|
| 可立即推进的上游动作 | **P1 落地（含 `REG_DSI_VERSION` 实证）** + P0（DSC 1.2，通用件） | Kaanapali overlay v21 静态对照（找差异） |
| 需要设备 | P1 需 1 次上机（读版本寄存器 + 冷起对照） | 无需（静态）；根因需外部仪器 |
| 阻塞 | 上游四问答复（决定 L3 落点：P4 vs M5） | 外部仪器（人手） |
| 与既有 M 系列关系 | 并入 **B5（policy §7 已建议）**；P4 可能需要 **M5 下游 patchset** | 独立条目（clk/pm-domain 协作）；与 M4 camss（B8）相邻但不同层 |
| 新标准下的主要收益 | 把「940 行 vendor DSI 散落」变成「1 机制 + 2 数据/DT + 1 门控行为」的可评审形态 | 把「玄学硬复位」变成「上游 issue + 待测量清单」，不再消耗本地二分 |

## 5. 建议动作（按性价比，全部可执行）

1. **Q28-P1 前置实证**（设备 1 次）：读 SM8750 `REG_DSI_VERSION` ⇒ 确认是否 `V2_9_0`；顺带取一次冷起三态样本。**授权已获（免在场刷机）**。
2. **Q28-P0/P1 落地**（主机）：P0（DSC 1.2 通用，独立补丁）+ P1（compatible 消歧，机械零行为）⇒ 各过 checkpatch `--strict` + 编译门，入 `patches/upstream/`（**投递冻结中，只备料**）。
3. **Q24 静态对照**（主机）：拉取/阅读 Kaanapali camera DT overlay v21（上游 consumer）与我们的 `cambist`/`camcc` 节点做 14/14 逐项对照，产出差异表 ⇒ 可能直接得到"顺序约束"的线索。
4. **把两项写成 M 系列正式行**（本次已做，见 `TASKS/README.md` §7 M6/M7）。
5. **不做的**：Q28 再扫 DT/驱动变体（已否证 7 臂 + H1/D1/D2）；Q24 再扫 DT 变体（H1/H2/mxnom 已否证）；把任何 workaround 包装成"修复补丁"。

## 6. 未决（需拍板）

1. **M6/M7 是否按本文形态立项**（M6 = B5+Q28 上游化；M7 = Q24 上游协作 + 外部测量）。
2. **投递冻结是否对 M6/M7 同样生效**（默认生效：只备料不发）——若要"发"，最小可发件 = Q28 的 P0 + L1 1 行补丁。
3. **Q28-L3 的落点**：等上游四问答复；若答复"bonded 非上游模型"，则按 **M5 隔离**而不是硬塞进 B5。
4. **Q24 外部测量的执行条件**（仪器/人手窗口）。

## 7. 证据指针

- 标准与清单：`reports/upstream-policy-20261013.md`、`archive/topics/UPSTREAM-REVIEW-2026-10-04.md`
- Q28 结构：`reports/b5-dsi-resoc-20261013.md`（56 hunk 分类 + P1–P4）、`reports/q28-dispcc-static-20261012.md`（原厂前提削弱 = 主靶可能出 B5 范围）
- Q28 上游：`archive/topics/UPSTREAM-REPORT-q28-bonded-dsi-2026-10-12.md`（§6 四问、§12 归档结果）、`reports/m1-display-rootcause-analysis-20261014.md`（Pengyu 指路）
- Q24：`archive/topics/UPSTREAM-REPORT-cambist-q24-v3-2026-10-12.md`、`reports/{q24-mech,q24-r9,q24-noc,q24-cseries,q24-h1-result}-20261012.md`
- 机上事实：`reports/m1-73-e1b-pllfix-20261014.md`（L1 补丁）、`TASKS/README.md` §0/§5/§7
