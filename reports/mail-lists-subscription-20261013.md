# 值得订阅/追踪的邮件列表与信息源 — elden 项目（2026-10-13）

> 只读调研产物。已核实项均给出 URL / lore 实测 / 本地文件出处；未核实项已标注。
> 现有订阅基线：linux-arm-msm（2026-10-12）、linux-pm（2026-10-13，用户自述）。仓库 `RESOURCES.md` §1、
> `TASKS.md` §5/§7 为关联性依据；订阅机制出处 `~/.pi/agent/projects-memory/y700-elden/../.pi/skills/upstream-mail-ustc/SKILL.md`（本仓）。

## 1. 订阅排序（价值 × 成本，含机制）

| 排名 | 列表 | 地址 | 订阅机制 | 投递门槛 | 日均流量(估) | 项目关联 |
|---|---|---|---|---|---|---|
| 1 | linux-arm-msm | linux-arm-msm@vger.kernel.org | 已订（vger：发 `<list>+subscribe@vger.kernel.org`，确认信回一发即生效；majordomo 已退役） | 非订户投递进审核（本仓 SKILL 已实测） | 中(30–80) | 主战场：QCOM 全家桶、DT、drm/msm、 remoteproc、battmgr 全过此列表 |
| 2 | linux-pm | linux-pm@vger.kernel.org | 已订（vger 同上） | 非订户审核 | 中(20–60) | qcom_battmgr M2 补丁、CX power domain、熄屏(Q24)电气级问题都在 PM 侧 |
| 3 | linux-clk | linux-clk@vger.kernel.org | **建议尽快订**（vger 同上）：Q24 v3 已投此列表且 Taniya 沟通在续 | 非订户审核 | 中(20–40) | camcc/cambistmclkcc/dispcc、clk 负责人 Taniya Das 的评审线程都在这 |
| 4 | dri-devel | dri-devel@lists.freedesktop.org | **freedesktop Mailman**，网页表单 https://lists.freedesktop.org/mailman/listinfo/dri-devel （2026-10-13 实测 200，订阅=POST ../subscribe/dri-devel，需回确认信） | 订户直投；非订户经审核/可被拒 | 大(100–250) | M2 的 drm/msm/dpu 两枚补丁在此评审；lore 已见 2026-10-13 SM8750 DSPP catalog 新补丁（见 §7 新事实①） |
| 5 | linux-input | linux-input@vger.kernel.org | vger 同上 | 非订户审核 | 小(10–25) | aw86927 触觉驱动上游化（M1–M5 面） |
| 6 | linux-remoteproc | linux-remoteproc@vger.kernel.org | vger 同上 | 非订户审核 | 小(5–15) | ADSP/CDSP hexagonrpcd/remoteproc、sensor PD（y700-adsp-ssc 技能线） |
| 7 | linux-media | linux-media@vger.kernel.org | vger 同上 | 非订户审核 | **极大(200+)** | camss 相机栈（G1-22/Q24 后续、前后摄出帧后的功能化） |
| 8 | linux-bluetooth | linux-bluetooth@vger.kernel.org | vger 同上 | 非订户审核 | 小(10–30) | hci_qca / WCN7861 IBS 断连调参 |
| 9 | linux-sound (ALSA/ASoC) | linux-sound@vger.kernel.org | vger 同上；lore 实测活跃（2026-10-13） | 非订户审核 | 中(20–50) | 音频 tplg/I2S 子图（vk34 GPR 修复后仍需上游化） |
| 10 | ath12k | ath12k@lists.infradead.org | **infradead Mailman**（lore 头实測 `ath12k.lists.infradead.org`），网页 https://lists.infradead.org/mailman/listinfo/ath12k | 订户直投 | 小(5–20) | Q26 已关，但 WiFi 新 bug/固件接口变化仍出自此；**先只追踪** |

机制出处：vger 列表/归档权威目录 = https://subspace.kernel.org/vger.kernel.org.html （2026-10-13 实测含 linux-arm-msm/pm/clk/input/media/remoteproc/bluetooth/sound/wireless）。

## 2. 只需追踪（读归档，不订阅）+ 追踪方式

**替代追踪四件套**（全部只读，不产生邮件）：
- lore 查询（自动过 Anubis）：`python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/<list>/?q=<词>"`
- Atom 订阅：URL 加 `?x=A`（lore-query.py 已默认）；可喂任何 RSS 阅读器
- patchwork：https://patchwork.kernel.org/project/<list>/list/ （如 `/project/linux-arm-msm/`）
- subspace 收件箱列表页：https://subspace.kernel.org/vger.kernel.org.html （订阅/描述一览）

| Top | 列表 | lore 路径（**别猜**） | 追踪建议 |
|---|---|---|---|
| 1 | LKML | `lore.kernel.org/lkml/` | **绝不订阅**（流量数百/日）。只按线程查：`?q=<Message-ID 或关键词>` |
| 2 | devicetree | `lore.kernel.org/linux-devicetree/`（SKILL 坑#1 实测） | 只查 DT binding 审核；我们 CC 进线程即可 |
| 3 | linux-clk | `lore.kernel.org/linux-clk/` | 若暂不订，先 `?q=sm8750` / `?q=camcc` 盯 Q24 线 |
| 4 | dri-devel | `lore.kernel.org/dri-devel/` | `?q=sm8750` / `?q=msm/dpu` 盯 SM8750 DPU 活动再决定订否 |
| 5 | linux-media | `lore.kernel.org/linux-media/` | camss 上游化启动前 `?q=camss` 周期扫 |

## 3. 非内核信息源

| 源 | 为什么值得 | 最小成本追踪 |
|---|---|---|
| mesa/freedreno（gitlab.freedesktop.org/mesa/mesa） | Adreno 830 (A830/gen80000) 支持与 turnip 演进直接关系 G2/G3（`RESOURCES.md` §1 已在用 26.1.8） | gitlab RSS（项目 → Activity feed）或每两周 `git -C mesa log --oneline src/freedreno` |
| phosh / phoc（gitlab.freedesktop.org/mobian1/phosh… 现归 phosh 命名空间） | 本仓 `patches-userland/` 已有 3 个自维护补丁 + MR 草案（RESOURCES §3 L237）；上游合入/改动直接决定可弃自维护 | gitlab MR 订阅（网页），或月度 `?q=phoc` 查 lore（phoc 少量邮件） |
| Waydroid（github.com/waydroid/waydroid + waydroid_script） | G2 主路线；`casualsnek/waydroid_script` 的 certified/Widevine 流程是 C3 复现对象（RESOURCES §1 L45） | GitHub Watch → Releases only |
| postmarketOS / mobian（gitlab.postmarketos.org + wiki） | SM8x50 手机侧 mainline 经验、battmgr/sensor 坑表（RESOURCES §1 L33） | wiki 订阅页少；用月度网页浏览即可，勿订其 IRC 流 |
| Qualcomm CodeLinaro / codelinaro.org（qclinux、aurora tplg、CAMSS 固件） | 原厂 tplg/固件/厂家驱动补丁先于主线出现（ADSP tplg 线的权威上游） | codelinaro 项目 → RSS / 关注 release tag |
| 存量社区设备线：`xiaobai-Lethe/Y700-elden-linux`（GitHub） | 同机型先行者：165Hz mode table、Mesa deb、.config（RESOURCES §1 L16，已在本地镜像） | GitHub Watch releases only（已本地镜像，低频 diff 即可） |
| lore.kernel.org 全库 | 一切补丁的最终归档，唯一可靠复核面（SKILL §5） | `lore-query.py` + Message-ID raw 比对 |

## 4. 不要订阅（防淹，USTC 邮箱已在收完整 vger 流量）

- **lkml / linux-kernel**：数百封/日；我们的邮件都 CC lkml，归档路径 `/lkml/`，按线程查即可。
- **devicetree**（linux-devicetree）：binding 审核流水线流量大且与我们非主线；CC 即达。
- **linux-media**（除非 camss 上游化开工日）：200+/日，先 `?q=camss` 扫描。
- **linux-wireless**：ath12k 补丁都双投 ath12k+linux-wireless，订 ath12k（更小）或干脆只读。
- **regressions**：regressions@lists.linux.dev 是**报告出口**不是讨论池；流量极小但低增量，查 lore `/regressions/` 即可。
- **dri-devel 暂缓**（若短期只出零星 dpu 补丁）：M2 线程用 `?q=sm8750` 跟；要连续回帖再订（订了也是 100+/日）。
- **freedesktop lists 的 announce/digest 类**、任何 GitHub 全量 Watch：只开 Releases。
- 已被 USTC 收全量 vger 流量的邮箱：**不要再把这些列表加进同一邮箱做订阅**（重复一封 + 回执爆炸）。

## 5. 与已有订阅的重复/冲突点

- **linux-arm-msm 覆盖面极宽**：QCOM 的 clk/drm-msm/battmgr/remoteproc/DT 大多数讨论先出现或双投于 arm-msm；订 linux-clk 只为拿到非 QCOM 侧 clk 树的整体评审与 maintainer 信号。
- **归档路径陷阱**（SKILL 坑#1）：`devicetree → /linux-devicetree/`、`linux-kernel → /lkml/`；查错路径 404 ≠ 未投递。
- **dri-devel 与 arm-msm 双投**：drm/msm 补丁两列表都收；追踪侧只盯一边不会漏。
- **ath12k ≠ vger**：在 infradead，`<list>+subscribe@vger` 对它无效。
- linux-pm 已订 ⇒ battmgr/CX 线程的回信会直达 USTC 邮箱（注意 Coremail `[SPAM]` 标记与 Junk 文件夹，SKILL 坑#4）。

## 6. 动作建议（按需执行，本次未做任何订阅）

1. 本周：订 linux-clk（Q24 线续中）。
2. M2 dpu 线需要回帖时：订 dri-devel（Mailman 表单 + 确认信）。
3. aw86927 / remoteproc / bt / sound 上游化开工日各自提前 1 周订对应列表。
4. 日常追踪：`lore-query.py '?q=sm8750'` 扫 arm-msm + dri-devel + linux-clk 三处，周一一次。

## 7. 调研中的新事实

1. **2026-10-13 lore/dri-devel 已出现 `[PATCH] drm/msm/dpu: add the missing GC block to the SM8750 DSPP catalog`**——与 Q28 DPU 相关的独立上游活动，值得跟进（lore 实测，非本仓提交）。
2. **ath12k 列表宿主 = lists.infradead.org（Mailman）**，不是 vger；订阅方式与 vger 的 +subscribe 不同（lore 归档头实测）。
3. lore 直连根路径返回 403 是 **Anubis PoW 正常行为**，用 `~/.local/bin/lore-query.py` 可全通过（本次对 dri-devel/ath12k/linux-sound 三处实测成功）；「403/无条目」不可当作「列表不存在」。

## 附录：编排者独立复核（2026-10-13，standing rule「子代理自报不可信」）

- **④.1 更正（重要）**：报告中「lore/dri-devel 已出现独立上游补丁 `add the missing GC block to the SM8750 DSPP catalog`」**判断错误**——那条正是**我们自己**当天 08:21 投出的 P1（Message-ID `20261013002124.332074-1-…`）+ sashiko 机器人自动评审回复（`sashiko-outbox-168803@kernel.org`）。真正值得记录的既有事实是：**同一修复早已由 Rob Clark 合入 msm 树**（`3389406e6a03`，`drm/msm/dpu: Fix GAMMA LUT for sm8750 related DPUs`，applied 2026-09-30，v7.4；本地按 `gitlab.freedesktop.org/lumag/msm` 的 `msm-next` 分支核实）。我们据此**已撤稿**。
- **④.2 部分核实**：`lore.kernel.org/ath12k/` inbox 存在且活跃（2026-10-13 有 `ath-next-20261012` pull）✓；「宿主 = lists.infradead.org」这一具体结论**未独立核实**（子代理自述来源为 lore 头部，可接受但未复验）。
- **④.3 认可**：lore 根路径 403 / Anubis 挑战属正常反爬行为，与 `PITFALLS #220` 一致。
- **补充更正**：表格中「dri-devel 暂缓/只追踪」需注意——我们**已在 dri-devel 投递**（P1 撤稿回复 + P3 新补丁），且 **dri-devel 在 lore 有可读镜像**（`lore.kernel.org/dri-devel/` 查询命中），因此「订阅」（lists.freedesktop.org 表单）与「追踪」（lore）可分开处理。
