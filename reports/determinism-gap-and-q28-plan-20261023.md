# 概率性测试意味着什么 —— 结构性诊断 + Q28 收敛方案（2026-10-23）

> 触发问题：**「一旦陷入概率性不确定测试，是否意味着我们缺少了某些东西，或某些功能的实现不健壮？」**
> 本文先给判据（怎么区分「真随机」与「我们没控制住的状态」），再给 Q28 的收敛方案（含代码位置与顺序证据），最后给可执行的确定性门。
> 结论口径：〔已证实〕= 有仓库内代码行/实验数据；〔推测〕= 有机制推理未闭环。

---

## 1. 「概率」在我们项目里的真实构成

Q28（冷起 ~50% 只有背光）与 Q24（vk64 上熄屏/唤醒致死，实测 6/8）看上去都是「随机」。但把 2026-10-12…10-23 的证据摊开后，它们**不是同一类随机**：

| 类别 | 表现 | 我们项目里的实例 |
|---|---|---|
| **A. 真竞态** | 同一确定性初始态下仍随机（首命令撞 DYN pclk 切换） | Q28 坏发：首条 DCS `ff 20` 走 bonded 命令 DMA 超时〔已证实，寄存器差分〕 |
| **B. 未受控的交接态** | 上一次是谁把硬件留在什么状态 | `fastboot boot` 冷路径 ≡ 真 POR 但 bootloader 遗留 MDSS/DSI/PLL 状态不同；kexec 继承「另一个内核已完整编程」的显示（0154 在 kexec 上必然无效）〔已证实〕 |
| **C. 缺可观测性** | 确定性事件被记成随机 | Q24 硬复位**无末帧**（pstore 空、串口 ~8.8 s 才有）；ramoops 缺 `record-size` ⇒ 没有 panic 持久区〔已证实〕 |
| **D. 我们自己的测试泄漏** | 假阴性/假阳性污染样本 | 2026-10-23 一天内修掉 3 类：`SetActive` 冷启动 no-op、`dpms` 空读数其实是已复位、**显示栈已坏的 boot 被记成 INVALID**（`dpu_err` 507/15、DBus 超时、`dpms` 写 `EACCES`）〔已证实〕 |

**判据（可直接复用）**：
- 若「同一镜像 + 同一 cmdline + 同一模块树 + 每次真 POR」仍双向出现 ⇒ A 类竞态。
- 若把**交接态固定**（例：从 bootloader 直接起、或从 kexec 起）后结果单向化 ⇒ B 类，属**缺状态归一化**。
- 若失败后没有任何末帧/寄存器快照 ⇒ C 类，属**缺可观测性**，此时任何「概率」都不可信。
- 若同一 boot 内连采结果一致、换 boot 才变 ⇒ D 类 + B 类，属**测试未分层**。

## 2. 结论：概率性 ≠ 硬件玄学，而是三处工程缺口

1. **复位/电源时序没有明确 owner**（最核心）。
   当前形态：`dispcc`（时钟驱动）在 probe 里复位整块 MDSS（我们的 0154），而 **display 驱动**自己也有一段 `msm_mdss_reset()`（只管 `MDSS_CORE` 一个 BCR）。两处都想当 owner ⇒ 谁先谁后取决于 probe 顺序 ⇒ 结果依赖交接态。
   上游评审（Taniya Das 2026-10-22）已明确指出这点：**这些复位属 display SW，不该由 clk 驱动驱动；整块复位再配 PLL 会闪屏**。
2. **没有「已知零态」的归一化步骤 + 读回校验**。
   我们所有显示初始化的鲁棒性都建立在「ABL 交接过来时大概是干净的」这个假设上。没有一次「assert → 保持 → deassert → **读回确认 `CTRL.ENABLE=0`、`CLK_STATUS` 无 DYN 位** → 再编程」的闭环，
   于是失败后只能靠「重试」，而重试又撞上单向闩锁（`dsi_bonded_cmd_failed`）与 `link_configured` 误清（两处已修，`PITFALLS #366`）。
3. **固件侧无可见性**（Q24 的关键）。
   vk64 那发死亡末帧是 **`sys_m_smsm.c:322` TZ `err fatal notification` + `adsp watchdog`**〔已证实，`logs/n5b-vk64-20261023-133658.log.round2.serial`〕
   —— 也就是说 **ADSP 侧先被判死**，而我们**没有任何 ADSP minidump / SSR reason / rail 遥测**。这不叫「随机」，这叫「看不见」。

## 3. Q28 收敛方案（v2，按依赖性排序）

### 3.1 已证实的靶点与两步修复

| 项 | 数据 | 结论 |
|---|---|---|
| 0154（dispcc probe 复位 `MDSS_CORE\|CORE_INT2\|RSCC`） | base 5/9 STORM；only0154 **5/5 GOOD**；含 0154 两臂合并 **15/15 vs 4/9**，Fisher 双侧 **p=0.003** | STORM 由「活着的显示被复位」决定〔已证实〕 |
| 0155（PHY `DIGTOP_PWRDN_B` 随 PLL bias） | only0155 3/4 STORM，但 PLL 已锁 | 只修 `PLL lock failed`/使能计数失衡，**不治 STORM**〔已证实〕 |
| 软件闩锁 + `link_configured` 误清 | 修后重试**首次真的到硬件**并报 `stale link configuration`/-116 | 属「把确定性失败伪装成不可恢复」〔已证实，`PITFALLS #366`〕 |

### 3.2 v2 = 把复位搬回 display 侧，并保证**早于 PLL 配置**

**代码事实（决定可行性）**〔已证实，`build/m1-73/drivers/gpu/drm/msm/msm_mdss.c`〕：

- `msm_mdss_init()` 的**第一件事**就是 `msm_mdss_reset(&pdev->dev)`（`:372`）；
- 之后才 `devm_clk_bulk_get_all()`（`:397` 附近）拿时钟；
- ⇒ **在 mdss 复位时刻，mdss 的时钟/PLL 尚未被 enable/rate-set**。这说明「display 侧复位 + 早于 PLL」在**现有代码顺序里本来就成立**，Taniya 的架构意见与我们要的时序**不冲突**。
- 现状唯一障碍：`msm_mdss_reset()` 只取一个 reset（`reset_control_get_optional_exclusive(dev, NULL)`），且 `mdss-common.yaml` 的 `resets` 只声明了 `MDSS_CORE` 一项。

**v2 补丁形态（3 处，最小改动）**：

1. `Documentation/devicetree/bindings/display/msm/mdss-common.yaml`：`resets` 改成 3 项（`MDSS_CORE`、`MDSS_CORE_INT2`、`MDSS_RSCC`），后两者标 optional。
2. `sm8750.dtsi` 的 mdss 节点：`resets = <&dispcc DISP_CC_MDSS_CORE_BCR>,
   <&dispcc DISP_CC_MDSS_CORE_INT2_BCR>, <&dispcc DISP_CC_MDSS_RSCC_BCR>;`
3. `msm_mdss.c`：`msm_mdss_reset()` 改 `reset_control_bulk_get_optional_exclusive()` + `reset_control_bulk_assert()` → `msleep(20)` → `reset_control_bulk_deassert()`；`dispcc-sm8750.c` 里的 0154 整段删除。

**判据（v4 实验，设备侧）**：`only0154 5/5 GOOD` 必须在「搬到 mdss 之后」复现（≥5 发冷起 GOOD、`dpu_err=0`、`dsi_isr≈41`）；若搬完退化成 base 水平 ⇒ 说明真正起作用的是「**dispcc probe 时刻**」（比 dispcc PLL 配置更早），那就得改为在 dispcc 里以「handoff normalization」名义保留，并把理由写进 changelog 正面回应 Taniya。

### 3.3 必须同时处理的两个副作用

- **simpledrm/efifb**：整块复位会把 bootloader 交接的 framebuffer 抽掉（我们 A/B 树**故意不描述** `simple-framebuffer`，所以没覆盖这条；sashiko 的 High 就指这里）。
  v2 要求：复位只在「我们即将接管显示」时做（`drm_aperture_remove_conflicting_framebuffers()` 之后 / 或 `!simpledrm` 时），并把这条对照实验写进报告（有 simpledrm 在场 vs 不在场）。
- **闪屏**：冷起 bring-up 阶段屏尚未点亮 ⇒ 无可见闪；一旦有 simpledrm 在扫，就要接受一次黑屏（这属于接管语义，不是回归）。

### 3.4 把「概率」压成「确定性」的三道门（都已在仓库或本轮落地）

| 门 | 内容 | 现状 |
|---|---|---|
| **G1 交接态归一化** | 复位 3 个 BCR + 读回确认 `CTRL.ENABLE=0`/无 DYN 位，再编程；不一致就**再复位一次**（确定性重试，不靠软件重试） | 待 v2 实现 |
| **G2 失败可见** | ① `ramoops` 加 `record-size`（关闭 `deflate`/签名校验问题需同 DTB 才回收 ⇒ 写进 boot_b 后即可用）；② 断言失败走 `panic`/`WARN` 而不是静默 return | ① 之前因「回收内核 DTB 不带 record-size」**主动不做**，现在 boot_b 已是我们的镜像 ⇒ 条件成熟 |
| **G3 样本分层** | 每发记录 boot 质量协变量（`dpu_err` 计数、`GetActive` 响应、Q28 签名、`boot_id`），坏 boot 直接作废并重开 | 本轮已实现（`n5b` 显示健康门 + `FRESH=1`） |

## 4. Q24 的「缺失项」清单（与 Q28 同构）

1. **ADSP/CDSP 侧可见性**：抓 TZ fatal reason（`qcom_smem_state`/`smem` scatter）、开启 remoteproc minidump/SSR 收集（`/sys/class/remoteproc/*/coredump`、`QCOM_MDT_LOADER`+`minidump` 路径）。
2. **电源遥测**：Konrad 单变量臂（`sync_state` 关闭）已 3/3 存活、基线 6/8 死 ⇒ 说明**rail 降档时序**是嫌疑；要拿到 `rpmh` 实际 corner 序列（tracepoint `rpmh`/`cmd-db`）而不是靠猜。
3. **判定归因**：Q24 的「死」有两种相位（熄屏瞬间 ADSP fatal；唤醒 <6 s 无痕），必须按相位分别统计，否则永远算不出可比较的率。

## 5. 一句话回答

> **概率性是症状，不是本质。** 我们缺的是三样东西：**（1）复位/电源时序的明确 owner**、**（2）已知零态 + 读回的归一化闭环**、**（3）失败时的末帧可见性（ramoops + 固件侧 dump）**。
> Q28 的解法不是「再试一个臂」，而是把 0154 搬到 display 侧（`msm_mdss_reset()`，扩成 3 个 BCR，天然早于 PLL）+ 保留两处闩锁修复 + 加读回校验；Q24 的解法是拿固件侧 reason，再判 Konrad 那条 rail 时序。
