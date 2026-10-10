# Q28 显示问题 — 单一事实源（SSOT 合订卷）

> 本文件是 **Q28 显示 bring-up 问题的唯一事实源（SSOT）**。散落的过程稿（`reports/q28-*-20261010.md`）
> 收敛于此；旧报告只作证据附件保留（见 `reports/q28-INDEX.md`）。
> 定稿日期：2026-10-10。每条结论标证据来源（PITFALLS 条目 / 报告 § / 日志文件:行 / 寄存器值 / 源码行）。
> 本文档**不改设备、不改内核、不改任何已有 git 跟踪文件**，仅整理进度。

---

## a) 一句话现状

Q28 = 设备**冷起（display bring-up）间歇性无画面**，根因候选已定案在 **DSI 冷起首次 PLL/PHY 锁不稳**：
轻则在**首条 DCS 命令的命令 DMA 上 hang（STORM）**，重则 **DSI host probe 就没出 card0（NOCARD）**；
两条候选修法（`cmd_trigger` settle delay / 取整 byte-clk）都**未编、未上机、未判定**，冷 A/B 只跑了 **1 次且撞 NOCARD**。

> **🆕 2026-10-10 夜复核（§k，`PITFALLS #171`）**：上述「冷起 ~60%」口径被**收窄**。固定路径
> `Linux → reboot2 bootloader → fastboot boot` 连测 21 发：`out/boot-elden-vk64.img`（Oct-8 内核）**GOOD×7**，
> 而**所有新编镜像**（vk89/vk89-plain/vk64c/vk64c+旧ramdisk/`make clean` 全量）**NOCARD×14**。
> ⇒ 在当前设备状态，**Q28 与「内核二进制」绑定（同一二进制恒定复现）**，不是冷/暖、也不是 ~60% 随机。

---

## b) 已定案结论（6 条，逐条标证据）

**B1 — Q28 的真实变量是「冷/暖复位」，不是时间/温度。**
冷起基本失败（用户实机约 ~60%，"有时能进桌"）；暖起（`reboot→fastboot boot` / ABL 已初始化）基本成功。
> **⚠️ 收窄（2026-10-10 夜，§k / `PITFALLS #171`）**：固定路径下 Q28 与**内核二进制**绑定——
> 同一内核恒定复现（非掷骰子），换一个同源构建即可从 NOCARD 翻到 GOOD。故「冷/暖」至少不是当前判别变量；
> 本条的「~60%」是早期在 vk63 上跨复位类型混采的旧口径，观已不适用。
- 推翻 2026-10-09「强时间相关（下午好/夜里坏）」的初判（用户实机纠正）。
- 硬约束：**A/B 样本必须固定复位类型**；纯暖起循环（今天暖起 9/9 干净、`q28-ab-delay.sh` 8/8 GOOD）**不能**当"未复现"结论，只能说明暖路径本没撞上触发条件。要复现高坏发态须走**冷起（用户 POR 进 fastboot → `fastboot boot`，零写 boot_b）**。
- 证据：`PITFALLS.md #163`（"修正本条初稿方向写反"）；`reports/q28-handoff-20261010.md` §0 口径纠正；`logs/q28-ab-20261010-130712.log`（暖起 A/B）。

**B2 — 根因 L1 = bonded 双 DSI「首条 DCS 命令（`ff 20`）」的命令 DMA 引擎 hang；L2 是 L1 的下游。**
坏发瞬间：面板首条 DCS `dcs data ff 20` 即超时，主/peer 报 `command DMA timeout status=0x2200200 master=-110 peer=-110`，
init 重试 3 次仍败（-110→-5），**4 ms 后**才出现 `dpu_encoder_phys_vid … ctl 1 reset failure -22` / frame done / vblank 风暴 → 自发重启。
- **完美共现 ⇒ L2（DPU CTL 卡死 -22）= L1 的下游后果，非独立 bug。根因 = L1。**
- hang 瞬间寄存器：`STATUS0=0x20003`（正常=0x0）、`TRIG_DMA=0x1` 自不清；CTL/CMD_DMA_CTRL/FIFO 好与坏相同。
- 同日志 15 boot 分段差分：GOOD 4 次（`commandDMA=0/initfail=0/ctlreset=0/framedone=0`）、BAD 11 次（全部先 cmd DMA timeout）。
- 面板 `csot,pp8807hb1-1`(=`novatek,nt36536`) `mode_flags = …VIDEO_BURST…DSC`（`drivers/gpu/drm/panel/panel-novatek-nt36536.c:530`），init 仍走 DCS；背光是 init 成功之后才开 → 以 dmesg `Failed to init panel` 为准，不能凭"有背光"判 init 成功。
- 证据：`PITFALLS.md #164`；`reports/q28-two-layers-20261010.md`「★根因确认」段；`logs/q28-BAD-vk75dump-20261009-222932/q28-dumps.txt:1-2`（STATUS0/TRIG_DMA/INTR_CTRL 值）；同目录 `dmesg.txt:988-999`（timeout + `ff 20` -110→-5）；`logs/q28-BAD-live-20261009-221729/serial.log:269-272`。

**B3 — 冷起显示失效至少两种独立模式：NOCARD（无 card0）与 STORM（cmd-DMA 风暴）。**
- **NOCARD**：无 `/sys/class/drm/card0`；dmesg 早期 `DSI PLL(0) lock failed, status=0x00000000`（~0.86 s）+ `Failed to create device link … for …panel@0` → display-subsystem 组件没聚齐 → **根本没 card0**，管道没跑到 cmd-DMA 阶段，所以风暴签名=0（只数签名会误判 GOOD）。
- **STORM**：有 card0，但 cmd-DMA 超时/ctl reset/frame done/vblank 风暴（即 B2）。
- 两模式**同指一个根：冷起首次 DSI PLL/PHY 不能稳定锁定**；`cmd_trigger` 处的 delay 只盖 STORM 子窗口（远晚于 0.86 s 的 DSI host probe），**盖不住 NOCARD**。
- 证据：`PITFALLS.md #165`；`scripts/q28-devprobe.sh`（三态探针实现）；`logs/q28-forensics-20261010-125030/02-dmesg.txt:719`（`DSI PLL(0) lock failed …`）。

**B4 — 判据必须三态（NOCARD/STORM/GOOD），且须 SSH 读完整 dmesg + 查 card0。**
- 三态：无 `card0` ⇒ **NOCARD**；有 card0 但有风暴签名 ⇒ **STORM**；有 card0 + connector connected + 无风暴 ⇒ **GOOD**。
- 旧"只 grep `command DMA timeout`"的分类器**漏判** vblank/frame-done 风暴（`scripts/q28-verdict.sh` 已扩到 L1+L2 六类签名），更漏判 NOCARD。
- **不能靠串口 logger 判显示**：logger 重连会漏 0–20 s，正好盖住 NOCARD 的 0.86 s 现场。
- 证据：`scripts/q28-devprobe.sh`（三态）；`scripts/q28-verdict.sh`（六类签名，L1/L2 都数）；`PITFALLS.md #164`（方法论教训）/ `#165`（基建修正）。

**B5 — 候选修法：vk84-exp（`cmd_trigger` delay=1000 us）与 Method B（取整 byte-clk）。冷 A/B 仅 1 次，撞 NOCARD。**
- **vk84-exp**：`msm_dsi_host_bonded_cmd_trigger()` 写 `REG_DSI_TRIG_DMA` 前 `usleep_range(1000)`（`early_param dsi_cmd_delay_us`，默认 0=现状）。镜像 `out/boot-elden-vk84-q28delay-{base,exp}.img`，载荷逐字节同、唯一差 cmdline。补丁 `patches/q28-cmd-dma-delay.patch`。**只可能影响 STORM，不影响 NOCARD**。
- **Method B**：取整 byte-clk 使后续 `clk_set_rate` 成 CCF no-op、不再 retrigger PLL。草稿 `patches/q28-methodB-round-byteclk.patch` + `patches/q28-methodB-NOTES.md`；**落点须按上游校准到 generic `dsi_link_clk_set_rate_6g()`、对象 `msm_host->byte_clk`（不是 `_v2_9` 内 SM8750 分支、不是 `dsi_calc_clk_rate_6g`）**。**未编、未 apply、未上机**。
- 冷 A/B 记录：**T1 = vk84-exp(delay=1000) = NOCARD（n=1）**；**T2 = vk84-base 冷起（用户 POR→按键进 fastboot→`fastboot boot`，2026-10-10 18:04）= NOCARD（n=1，15 s 判读：无 card0、`DSI PLL(0) lock failed`×4、devlink fail×6、风暴签名 0）**。两臂冷 fastboot 上下文**同坏**，delay 无法区分（本就不治 NOCARD，符合预期）；「fastboot-boot 冷路径 ≟ 真 POR」仍未决（§f 未决 1），但 NOCARD 在该路径 2/2 重现 ⇒ **它可作三臂 A/B 的公共判据**（round 若连 NOCARD 都消 = 强信号）。证据 `logs/q28-coldAB-20261010/T2-base-180434/`。
- **Method B 已按上游真 diff 落地 = vk85-round**：真 diff 已从邮件列表取回（freedreno msg46766，`20260903-fix-eliza-dsi` change-id）；实现 = generic `dsi_link_clk_set_rate_6g()` 顶部对 `msm_host->byte_clk` `clk_round_rate` 回写 + `byte_intf` 由取整值派生（div-2 用运行时探测等价本树字段）；内核提交 `392b4897e`；树内旧草稿 `patches/q28-methodB-round-byteclk.patch`（落点错在 `_v2_9` 分支+PLL 对象）**作废**。
- 证据：`PITFALLS.md #164`（修复靶点）/ `#165`（T1 记录 + delay 盖不住 NOCARD）；`reports/q28-upstream-diff-20261010.md` §4–5（Method B 正确落点）；`reports/q28-orchestration-20261010.md` §3（vk84 单变量对）。

**B6 — 上游 `round byte clock after reparenting`（Dmitry）与本树机制吻合，但「逐字 cherry-pick 对本树无效」。**
- 上游正解 = commit `2028280686f4`（Dmitry Baryshkov，2026-09-03，`fix-eliza-dsi` 系列，**已进 mainline v7.3-rc4**）；经 qualcomm-linux **PR #1867** backport（merge `9511cf8cf5f2`，diff 与 lore 逐字一致）。机制：6G v2.9 主机在 reparent 到 PHY PLL 后取整 byte_clk，避免每次 transfer 重触 PLL。
- 因果链：Kavan `6cd33b6f4155`（reparent **前**取整 = 灌 19.2 MHz 废值破屏）→ Kozlowski `bc484ede914d` revert → Dmitry `2028280686f4` 正解。
- **对本树的裁决**：本树 = **前置 Kavan 的 7.2 基线**，三 commit 全 NOT-IN-TREE；`2028280686f4` 的"删除型 hunks"应用不上，且它修的是 Kavan 引入的 7.3-rc2 恒定回归（与复位类型无关），**不等于我们的冷起竞态**。"取整"对本树仍是合理**加固**（等价"加"部分、不含"删"部分），但**能否消 Q28 仍是经验问题**。
- 证据：`reports/q28-upstream-diff-20261010.md` §1–4（一手原文 + 逐条对树核实）；`reports/q28-upstream-research-20261010.md` §1.1（早期"机制完全吻合"判断，已被 upstream-diff 收窄，见 §"不一致"）。

---

## c) 证据索引（结论 → 具体来源）

| # | 证据 | 类型 | 精确来源 |
|---|------|------|----------|
| C1 | 冷/暖复位为真变量，非时间 | 定案条目 | `PITFALLS.md #163` |
| C2 | 暖起 A/B 8/8 GOOD（测错变量，不判别） | 日志 | `logs/q28-ab-20261010-130712.log`；`reports/q28-orchestration-20261010.md` §4 表 |
| C3 | L1 命令 DMA timeout 寄存器值 | 寄存器 | `logs/q28-BAD-vk75dump-20261009-222932/q28-dumps.txt:1-2`（`STATUS0=0x20003`、`TRIG_DMA=0x1`、`INTR_CTRL=0x2200200`） |
| C4 | 首条 DCS `ff 20` 超时 -110→-5 | dmesg | 同目录 `dmesg.txt:988-999`；`logs/q28-BAD-live-20261009-221729/serial.log:269-272` |
| C5 | GOOD(4)/BAD(11) 差分、L2=L1 下游 | 日志差分 | `PITFALLS.md #164`；`reports/q28-two-layers-20261010.md`「★根因确认」 |
| C6 | 面板 VIDEO_BURST+DSC，init 走 DCS | 源码 | `drivers/gpu/drm/panel/panel-novatek-nt36536.c:530`（见 two-layers §关键源码事实） |
| C7 | 显示时序（bonded/DSC/wide，bitclk 1064606 kHz） | dmesg | `logs/q28-BAD-vk75dump-20261009-222932/dmesg.txt:986`；`logs/q28-forensics-20261010-125030/02-dmesg.txt:987` |
| C8 | DSI byte-clk 实际达成 108.108 MHz | clk_summary | `logs/q28-forensics-20261010-125030/03-clk-dsi-mdss-raw.txt:43`（`108107958`）；`logs/q28-control-coldboot-181758/control.txt`（byte0/1=108107958） |
| C9 | "请求 133.076 MHz / 差 23%"（派生值，见 §g） | 推断 | `reports/q28-orchestration-20261010.md` §2（133.076 = bitclk 1064606÷8 推得；clk_summary 只记达成 108.108） |
| C10 | NOCARD 现场：DSI PLL(0) lock failed（0.86 s） | dmesg | `logs/q28-forensics-20261010-125030/02-dmesg.txt:719`；三态判据 `scripts/q28-devprobe.sh` |
| C11 | 三态判据实现 | 脚本 | `scripts/q28-devprobe.sh`（NOCARD/STORM/GOOD/NOROUTE）；`scripts/q28-verdict.sh`（六类风暴签名） |
| C12 | 冷 A/B T1=exp=NOCARD（n=1） | 定案条目 | `PITFALLS.md #165`（冷 A/B trial 记录）；`reports/q28-handoff-20261010.md` 顶部「冷 A/B 已开始」横幅 |
| C13 | vk84 单变量对（唯一差 cmdline delay） | 镜像+补丁 | `out/boot-elden-vk84-q28delay-{base,exp}.img`(+`.manifest`)；`patches/q28-cmd-dma-delay.patch` |
| C14 | Method B 草稿 + 复核（未编未上机） | 补丁 | `patches/q28-methodB-round-byteclk.patch`；`patches/q28-methodB-NOTES.md` |
| C15 | 上游正解 + PR #1867 + NOT-IN-TREE 裁决 | 一手对树 | `reports/q28-upstream-diff-20261010.md` §1–3 |
| C16 | 死内核事故（vk81/82/83 无 QCOM 驱动）与守卫修复 | 定案条目 | `PITFALLS.md #162`；`scripts/build-kernel.sh`（编后符号守卫）、`scripts/apply-kernel-fragment.sh`（回钉/回滚） |

---

## d) 两种失效模式对比表

| 维度 | NOCARD（更早 / 更根本） | STORM（较晚 = B2 主证据） |
|---|---|---|
| card0 | **无**（`/sys/class/drm` 只有 `version`） | 有 |
| 首个现场时刻 | **~0.86 s**（DSI host probe） | ~9 s（modeset / init 首条 DCS） |
| 关键签名 | `DSI PLL(0) lock failed, status=0x00000000`；`Failed to create device link … panel@0` | `command DMA timeout status=0x2200200 master=-110 peer=-110`；`ff 20` 失败；`ctl 1 reset failure -22`；frame done/vblank 风暴 |
| 风暴签名计数 | **0**（管道没跑到 cmd-DMA） | >0 |
| GUI/桌面 | 无 | 无（背光可能亮、面板不刷） |
| 与 delay 的关系 | **盖不住**（probe 阶段，早于 cmd_trigger） | 可能盖（cmd_trigger settle delay 正作用于此窗口） |
| 共同根 | 冷起首次 **DSI PLL/PHY 未稳定锁定** | 冷起首次 **DSI PLL/PHY 未稳定锁定** |
| 判据 | `q28-devprobe.sh`：无 card0 ⇒ NOCARD | `q28-devprobe.sh`：有 card0 + 风暴 ⇒ STORM |
| 现场日志 | T1（`#165`/handoff 横幅记录；仓库内**未见独立 NOCARD 日志目录**，见 §g-3） | `logs/q28-BAD-vk75dump-20261009-222932/`、`logs/q28-BAD-live-20261009-221729/` |

---

## e) 候选修法与状态

| 修法 | 作用点 | 目标模式 | 状态 | 证据 |
|---|---|---|---|---|
| **vk84-exp**（`dsi_cmd_delay_us=1000`） | `msm_dsi_host_bonded_cmd_trigger()` 写 TRIG_DMA 前 `usleep_range` | **仅 STORM**（盖不住 NOCARD） | 镜像已出（base/exp 单变量对）；**冷 A/B 仅 T1=NOCARD(n=1)，暖 A/B 8/8 GOOD 不判别** | C12/C13；`#165` |
| **Method B（取整 byte-clk）** | generic `dsi_link_clk_set_rate_6g()`、对象 `msm_host->byte_clk`（**非** `_v2_9` 分支、**非** `dsi_calc_clk_rate_6g`） | 主要 STORM（降 re-lock churn 概率）；能否消 Q28 **未定** | 草稿 + 父代复核完成；**未编、未 apply、未上机**；需按上游校准落点后编 vk85 | C14/C15；upstream-diff §4–5 |
| Method A 变体（触发前轮询 `REG_DSI_CLK_STATUS` 等 DYN 位清零） | cmd_trigger 前 | STORM | **未实现**（比固定 delay 更贴上游语义，候选） | upstream-research §2.1 方案A |
| 上游 `2028280686f4` 逐字 cherry-pick | — | — | **裁决：对本树无效**（缺前置 Kavan，本树在 7.2 良好侧，删除型 hunks 用不上） | C15；upstream-diff §3 |

---

## f) 未决问题与下一步

**未决问题：**
**★ C 配对对照定案（2026-10-10 晚，台架有效性）：同内核 vk64 × 两条冷路径。**
- **C1 = vk64 真实 POR 盘启（断电→按电源正常开机，boot_b，完整 rootfs）= 失败（仅背光无输出，用户目测）**。
- **C2 = vk64 冷 fastboot 路径（断电→按键 fastboot→`fastboot boot out/boot-elden-vk64.img`，同内核）= STORM**（card0=1、DSI-1=connected、dpms=On、风暴 sig=16：`command DMA timeout status=0x2200200`+`bonded command DMA failed master=-110 peer=-110`+`panel init attempt1 -110 → attempt2 -5 → Failed to initialize panel -5`+`vblank wait timed out`×13），phosh=0。证据 `logs/q28-coldAB-20261010/C2-vk64-185754/`。
- ⇒ **未决 1 定案：fastboot-boot 冷路径≡真实 POR 冷起（两者都坏），台架有效，T1/T2/T3 NOCARD 样本有效**。
- ~~基线分层：vk64=STORM、vk84/vk85=NOCARD，差=诊断补丁推早~~ **【已被后续证伪】**：vk86 就建在干净 vk64 基线上，暖机 fastboot boot **仍 4/4 NOCARD**（modeset 从未到达）⇒ NOCARD 不是诊断补丁引入的，干净 vk64 自己也会 NOCARD。
- **新坑（本轮实测，影合射 vk74 旧记录）**：**连续 `reboot2 bootloader`→`fastboot boot`（reboot2=暖复位，不清 DSI PHY/PLL 态）会把状态粘死在 NOCARD**，与内核/补丁无关 ⇒ **暖机 A/B 不可判别**；只有 POR（完全断电）能清粘态。vk74「4/4 全坏、断电即恢复」= 同一现象。
- **round 补丁现状**：已出 vk86-base（干净 vk64）/ vk86-round / vk86-round2（round 改**无条件 `pr_info` 带 ideal/rounded/no-op**），内核提交 `71bc68462`，`git apply --check` 干净落 vk64，config=a383cdb9（与 vk84 对一致）、同完整 ramdisk（`build-initramfs.sh full BASE=boot-elden-vk61`，sha d6ad1321）。**但 NOCARD 粘态下 modeset 从不到达→round 分支从不执行→暖机测不到 round**；要测 round 只能 POR 隔离冷起且需能落到 STORM 模式（STORM 才进 modeset），而冷起落 NOCARD/STORM 本身随机 ⇒ **round 的干净 A/B = 概率采样，属应避免类**。

1. **fastboot-boot 冷路径是否真等价于用户物理 POR 冷起。**【已定案见上方 C 横幅：等价】 若 base 也 NOCARD 不重现，就得改用真 POR（用户断电）做 A/B。（`PITFALLS #163`、handoff 顶部横幅「下次先定」）
1.5. **（新）reboot2 暖复位粘 NOCARD 态的确切机理与清除方式。** 已实测连续暖复位粘 NOCARD（vk86 4/4）、断电可恢复（vk74）；但未定位“什么硬件态被粘住”。下次若要用 fastboot 台架做 A/B，**每臂之间必须 POR**，不能连续 reboot2。
2. **GOOD 启动的 `DSI_PLL_lockfail` / `device_link_fail` 基线。** `#165` 提出"待对实：这两行是 GOOD 也有的良性噪声、还是 NOCARD 独有因果"。现有 GOOD 样本已给出强提示（见 §g-2）：
   - `logs/q28-control-coldboot-181758/control.txt`：**一次 GOOD 冷起**（`card0-DSI-1 connected`、phosh=1）却 `pllfail=8`、`cmdadma=0`。
   - `logs/q28-forensics-20261010-125030/02-dmesg.txt`：有 card0 的 GOOD 现场里 `DSI PLL(0) lock failed`=**4**、`Failed to create device link`=**8**。
   - ⇒ 初步：**这两行在 GOOD 启动也出现（良性/会重试成功），card0 有无才是判据，不是这两行本身**。仍需一个受控 GOOD 冷/暖回读正式坐实。
3. **NOCARD 是否有对应上游修法。** 上游 `fix-eliza-dsi` 针对 cmd 侧取整，未见直接治"probe 期 PLL lock 不稳 → 无 card0"的上游补丁；SM8750+Linux 装机量近乎为零，公开社区无先例（upstream-research §3.2）。
4. **取整到底能不能消 Q28。** Kavan 回归是"恒定破屏、与复位类型无关"，Q28 强依赖冷/暖复位 → 未必同一根因（upstream-diff §4）。

**下一步（按 handoff/upstream-diff §5 优先级，冷起需用户配合断电）：**
1. 先定 fastboot-boot 冷路径是否等价真 POR；不等价则用真 POR 做 A/B。
2. ~~Method B 按上游"加"部分重出~~ ✅ 已做（真 diff msg46766 校准、generic 落点 + `byte_clk` 对象，内核提交 `392b4897e`，已编 vk85-round）。
3. 三臂冷起 A/B：base vs round vs（delay / CLK_STATUS 轮询），**用 `scripts/q28-devprobe.sh` 三态判 + SSH 读全 dmesg + 查 card0**，各 N 次物理冷起看坏发率。
4. 若取整冷启仍高坏发 ⇒ 转 CMD engine 编程序 / PHY `save/restore_pll_state` 冷-暖差异 / `dsi_cmd_link_clk_set_rate` 的 `-ESTALE` 路径；串口常驻 + pstore-catch 抓真实现场栈。
5. 采一个确认 GOOD 的冷/暖启动，正式回记 DSI_PLL/device-link 基线（回答未决 2）。

---

## g) 旧报告里发现、未被"已定案 6 条"覆盖的不一致（整理时发现，非新增结论）

1. **冷/暖方向在 `reports/q28-orchestration-20261010.md` 正文里是反的。** 该文件 §0/§4 写"**暖复位基本失败、冷起基本成功**"，与权威 `PITFALLS #163`（"修正本条初稿方向写反"：**冷起基本失败、暖起基本成功**）**恰好相反**。handoff §"口径纠正"声称已纠正 orchestration §4/§5，但**磁盘上该文件正文仍是旧的反向表述**。本 DOSSIER 以 `#163`/B1 为准（冷失败、暖成功）。
2. **`DSI_PLL_lockfail`/`device_link_fail` 的因果定位存疑（良性噪声 vs NOCARD 独有）。** 有 card0 的 GOOD 现场（forensics、control-coldboot）同样出现这两行（见 §f-2），提示它们**不是 NOCARD 判据本身**。旧报告（#165/handoff）把 NOCARD 直接归因于这两行；card0 有无才是判据。列为未决 2，DOSSIER 不据此改根因。
3. **NOCARD（T1）无独立落盘日志目录。** 冷 A/B T1=NOCARD 的证据目前只在 `PITFALLS #165` 与 handoff 顶部横幅（文字转述），仓库 `logs/` 下 `grep VERDICT=NOCARD` 无命中。n=1 且无原始 dmesg 落盘，判定强度弱；正式 A/B 应每轮 `q28-devprobe.sh` 输出落盘。
4. **upstream-research 的"机制完全吻合 / 移植方向明确"已被 upstream-diff 收窄。** `q28-upstream-research` §1.1「置信度：高」「机制与 Q28 现象完全吻合」与其"方案 B：直接 cherry-pick fix-eliza-dsi"结论，被 `q28-upstream-diff` §3–4 推翻（逐字移植无效、且未必同一根因）。以 upstream-diff 为准。
5. **"133.076 MHz / 差 23%" 是派生值，非直接测得的坏-好差。** clk_summary 只记**达成** 108.108 MHz（C8）；133.076 = bitclk 1064606÷8（C7）推得（C9）。orchestration §2 称"取整缺口直接坐实根因"，但同时 good/bad clk_summary 完全一致（#164/两-layers 据此判"不是时钟树状态差异"）——两者需并列读：取整是合理加固假设，尚非坏-好实测差值。
6. **`reports/q28-two-layers-20261010.md` 正文含已被自身顶部横幅推翻的初判。** 其"结论先行/建议下一步"段主张"L2 DPU CTL -22 是当前主因、byte-clk/delay 非优先级"，而顶部「★根因确认」段 + `#164` 已定为"L1 是根、L2 是下游"。读该文件须以顶部段为准。

---

## g) 上游核验（2026-10-10 research lane + 本树静态核，**含对一条热门假说的否定**）

来源：`reports/q28-nocard-research-20261010.md`（8 次网络访问，一手 diff/commit 已取）。

**G1 — Q1：Dmitry byte-clk 取整修复的精确 ref（拿到，但对本树不适用）**
- 主线 `2028280686f4fa78e2f1f6dede4b6c1fd782b9e3`「drm/msm/dsi: round the byte clock rate after reparenting to the PHY PLL」，首个包含 tag **v7.3-rc4→v7.3**；stable 随 **6.18.54**（`78cb2ee9…`）。patchwork 750496 / lore `<20260903-fix-eliza-dsi-v1-1-…>`。
- **适用性判定：不可干净 apply** —— 该 commit 的 diff 是把 `clk_round_rate()` 从 `dsi_calc_clk_rate_6g()` 搬走，而**本树 `dsi_host.c` 全文无 `clk_round_rate`**（grep 命中 0），即本树 base 早于其 `Fixes: 6cd33b6f4155`。⇒ Method B 若做，是**按机制自己落**（把取整放 generic `dsi_link_clk_set_rate_6g`），不是 cherry-pick。

**G2 — Q2：上游「power up digital top before 7nm PLL」补丁：错误串逐字相同，但**已核实不是本树 NOCARD 根因****
- 补丁 Dmitry 2026-09-24（**未合入**，作者自陈会打挂 SM8350 HDMI 未接场景）。其报错 `DSI PLL(0) lock failed, status=0x00000000` 与我 NOCARD 日志**逐字相同**，一度高度可疑。
- **本树静态核验三条前提全不满足 ⇒ 否定**：① 本树**不含**触发 commit `acf7a91d0b0e`；② elden/sm8750 DT **无** dsi phy/pixel 的 `assigned-clock-parents`；③ 我 NOCARD dmesg（`logs/q28-T1-nocard-vk84exp-dmesg.txt`）**没有**该补丁失败签名要求的 `dsi0_phy_pll_out_dsiclk already disabled` + `clk_core_disable` WARNING + `of_clk_set_defaults` 栈。
- 反证闭环：这与既有记忆「`DSI PLL(0) lock failed` ×4 是好/坏启动**都有**的开机 probe 良性噪声」一致。**NOCARD 判据仍是 card0 缺失，与这几行无关。**

**G3 — NOCARD 真因**已收窄**（GOOD vs NOCARD 干净差分）**
- GOOD(vk75 基线, `logs/q28-BASELINE-good-vk75-dmesg.txt`)：8.70s `msm_dpu ae01000: bound ae94000.dsi / ae96000.dsi / af54000 / 3d00000.gpu` → 组件聚齐 → card0。
- NOCARD(vk84-exp)：**无任何 `bound ae94000.dsi`**、无 -517 defer、无 bind failed —— DPU master 组件聚合**从未完成**（静静没聚齐）。
- **下一步定根所需**（非本轮能定，需冷起）：同内核 GOOD-vs-BAD 冷起 dmesg 对（消 vk75/vk84 混淆）+ 坏发起 `drivers/gpu/drm` / component probe 动态调试或 `CMN_CTRL_0` 读值；先证「DSI host 自身 probe 是否失败」还是「master 聚合时序问题」。

## h) ★ 2026-10-10 深夜定案：真实日常失败 = STORM（覆盖本轮中途所有 NOCARD 慌乱）
- **C1real**（用户真实 POR → 正常开机 → 磁盘 vk64 日常）= **STORM**：card0=1、DSI-1=connected、dpms=On、`msm_dsi bonded command DMA failed master=-110 peer=0`+`command DMA timeout status=0x2200200`+`panel init attempt1 -110→attempt2 -5→Failed to initialize panel -5`+`vblank wait timed out`×12、phosh=0。证据 `logs/q28-coldAB-20261010/C1real-vk64-*`。
- 与 C2（POR→fastboot→fastboot boot vk64=STORM）**两条真实冷路径 2/2 STORM 一致** ⇒ **用户真实坏发就是 STORM（DOSSIER L1 cmd-DMA hang），A 的靶（delay/round 打 STORM）本就没打错**。
- **纠正本轮中途错误**：
  1. 中途「A 打错靶（修 STORM 但只产 NOCARD）」**作废**——那是我误用 `reboot2` 连续暖复位（粘态产 NOCARD）+ 用了带诊断的 vk84/vk85。
  2. 中途「干净 vk64 自己也会 NOCARD（vk86 暖机 4/4 NOCARD 推翻诊断补丁推早说）」**也作废**——那 4/4 是 `reboot2` 暖复位粘态，非 POR 冷起，样本无效。
  3. **有效对照仍在**：POR 冷 fastboot 路径 vk64=STORM（C2）vs vk84/vk85=NOCARD（T2/T3），差 = vk64→HEAD 的诊断 commit（`ca81318f2` 传播 power-up 失败 等）⇒ **那批诊断 commit 会把 STORM 变成 NOCARD，不能进 STORM 修法测试台**。
- **正确的 A 测试台**：`vk86-base`（干净 vk64，无诊断）做 STORM 对照；`vk86-round2`（+可观测 round，`pr_info` 无条件打 ideal/rounded/no-op）做实验。**每个样本之间必须真实 POR 断电**（reboot2 暖复位无效，会粘 NOCARD）。判据三态：vk86-base 冷起应稳定 STORM；vk86-round 若取整消 STORM→GOOD = 正解。round 补丁已验干净落 vk64、config=a383cdb9、同完整 ramdisk。

## i) 2026-10-10 深夜收尾（会话交接：资产/设备/分支/唯一下一步）
- **本轮净结论**：① 台架有效（fastboot 冷路径≡真 POR，C1real+C2 两条真实路径 2/2 STORM）；② **用户真实日常失败=STORM（L1 cmd-DMA hang），delay/round 靶没错**；③ NOCARD 全部是暖复位粘态（`#166`）或带 vk73-85 诊断链（`ca81318f2`）的伪影；④ **未定性敏感点**：内核+DTB 逐字节同、仅 `/init` 差 `payload-modules-load.sh`（挪时序），冷起一次 STORM(C2) 一次 NOCARD(A2)（`#168`）。
- **作废**：T1/T2/T3（带诊断链镜像+部分暖复位）、vk85 及其结论、本轮中途「A 打错靶/干净 vk64 也 NOCARD」两条推断、`patches/q28-methodB-round-byteclk.patch`（落点错）。
- **可复用资产**：分支 `q28/vk86`：`d02658e63`(vk86-base=vk64 内核)→`71bc68462`(+round)→`a8c09a723`(+无条件遥测)；镜像 `out/boot-elden-vk86-{base,round,round2}.img`（manifest 齐全，config a383cdb9=与 vk64/vk84 对逐字节同）；完整 ramdisk 重建命令 `scripts/build-initramfs.sh full out/boot-elden-vk61.img`（sha d6ad1321）；round 补丁 `patches/q28-round-vk86.patch`；遥测判读 `dmesg | grep "Q28 byte clk"`（`no-op=YES` ⇒ 取整在 SM8750 是空操作，直接放弃 round）。
- **设备态**：boot_b 全程未写（仍 vk64 日常）；会话结束时设备 RAM 里跑 vk86-base，**POR 一次即回日常**。
- **唯一下一步（先于任何修法）**：同一镜像 `vk86-round2` 冷起 **2** 次（每次间隔真实 POR，禁 `reboot2`）→ 模式不同 ⇒ 非确定性 ⇒ **停 Q28 转 Q24（FIX-2 臂现成：vk84-base/exp）**；模式相同 ⇒ `/init` 时序杠杆 ⇒ 静态调 `/init` 时序后再 A/B。若任一 round 样本到 STORM：读 `Q28 byte clk` 遥测判 no-op。
  ⚠️ **本节「唯一下一步」已被 §j / §k 覆盖**：§k（2026-10-10 夜）证明 Q28 与**内核二进制**绑定、同一二进制恒定复现，故「冷起 2 次看是否非确定」已不必做；新下一步见 §k。

## j) 2026-10-10 第二会话追加：真实 POR 确定性 + 复位深度阶（PITFALLS #170）
- **真实物理 POR（用户手动，vk64 日常 boot_b）2/2 = STORM**：run1 `storm_sig=267`（uptime 226s）、run2 `storm_sig=18`（uptime 22s）；两次均在 ~0.88s `DSI PLL(0) lock failed`×4、~9.07–9.14s `command DMA timeout status=0x2200200` + `bonded command DMA failed master=-110 peer=-110` + `Failed to initialize panel -5` + `ctl 1 reset failure -22` + `frame done timeout`。模式与签名时序一致。证据 `reports/trials/*-realpor-run{1,2}/`。
- ⇒ **real-POR 路径确定性复现 STORM**；§i 遗留的「同镜像冷起一次 STORM 一次 NOCARD」应归因于**复位类型混淆**（暖复位粘 NOCARD，`#166`），而非同路径二进制非确定性。**确定性门在 POR 路径上=通过（2/2 同模式）**。
- **复位深度 → 显示 阶（实测，n 小）**：物理 POR（最深）→ STORM；`fastboot reboot`→boot_b → STORM；`busybox poweroff -f`+VBUS 自开机（浅）→ GOOD；`reboot2` 暖复位→fastboot boot → NOCARD 粘态。⇒ 决定显示的不是「重启/断电」动作，而是该复位有没有清掉 DSI PLL/PHY 态。
- **坏发态软复位不可用**：严重 STORM（sig=267）下发 `busybox poweroff -f`，命令执行但**不生效**（uptime 连续、SSH 不断）＝内核关机路径被 DRM storm 卡死（`#150`）。已排除 SIGHUP。⇒ 坏发态只能物理强制断电。
- **对下一步的影响**：real-POR 可靠产坏发，但物理 POR 只能启动**固定的 boot_b**。要冷起一个实验镜像（如 vk86-round2），只有两条路：(a) 把镜像写进 boot_b 再 POR（写盘，需备份，且 slot 次数风险）；(b) 用户 POR **进 fastboot**（按键）后 `fastboot boot <实验镜像>` —— DOSSIER §h C2 已证 cold-fastboot→`fastboot boot` = STORM，且零写盘。**推荐 (b)** 作为 A/B 采样台，但需用户配合“POR 进 fastboot”这一动作。

### j-附) round 补丁静态审查（2026-10-10 第二会话；不碰设备）
- **落点/因果窗口：正确**。`q28-round-vk86.patch`（内核提交 `392b4897e`）改的是 generic `dsi_link_clk_set_rate_6g`；SM8750 经 `dsi_link_clk_set_rate_6g_v2_9`（`dsi_cfg.c:288`→`dsi_host.c:507`）到达它，且它在 `msm_dsi_host_power_on` 内**紧接 `link_clk_enable`（PLL 上锁点）之前**执行 ⇒ **在 PLL 上锁的因果窗口内**。方向上与上游 `2028280686f4`（reparent 后取整）一致。
- **★纠正一条先前错误结论（div2）**：`patches/q28-methodB-NOTES.md` 断言“SM8750 3nm PHY **不**置 `byte_intf_clk_div_2`”，并据此怀疑补丁的 `intf != byte → /2` 有 bug。实测代码链：SM8750 → `dsi_phy_3nm_8750_cfgs` → `msm_dsi_dphy_timing_calc_v4`（`dsi_phy_7nm.c:1018`）→ `dsi_phy.c:461` **置 `byte_intf_clk_div_2 = true`**。⇒ **SM8750 div2 = true**，补丁派生 `byte_intf = rounded/2` **对本板是对的**；NOTES 前提写反。附带：该写法在“no-div2 + 取整改速率”的板上会错误减半（通用脆弱，对本板无影响）。
- **台账状态：round = 未测（非被否证）**。vk87（round2 内核 + vk64 ramdisk）落 NOCARD，但 **不可归因**：既可能是 round 改变了 PLL 上锁，也可能是复位状态遗留（证据：vk64 与 vk86-base 内核字符串几乎一致却一个 STORM 一个 NOCARD，n=1）。⇒ **不归档、不排修法 A/B，挂起为“未测/阻塞于测试台”**。
- **测试台三条件（重启本线前必须满足）**：① 复位类型可证且固定（真 POR 判据：`boot_id` 变 + 设备真断电，不接受软关机/暖复位）；② 每臂 N≥3；③ 镜像过 `scripts/assert-kernel-sane.sh` 且 manifest 完整（`vk86-base.manifest ramdisk=(unknown)` 即不合格）**。

## k) 2026-10-10 夜复核：Q28 与「内核二进制」绑定，收窄「冷/暖」与「~60%」口径

> **⚠️ 本节已被溯源审计降级（2026-10-10，`reports/q28-binary-determinism-provenance-20261010.md`、`PITFALLS #171`）。**
> ① 21 发台账**仅 7 发有原始日志**（GOOD×2=`logs/q28-path-iso-vk64-220502`；NOCARD×5=`logs/q28-vk89-loop-*`/`q28-vk89plain-*`），其余 14 发无证据、`.img` 已删。
> ② 「内核二进制差 5,040,884 B」**主要是假象**：35.2–41.1 MiB 段 94.72% 满足 `b[i]==a[i-4]`（`.rodata` 平移 4 字节），源头=`LOCALVERSION` `-vk64`→`-vk64c` 多 1 字符；`.text` 仅 26 个 word 不同、全为 ADD/LDR 地址立即数，**无指令语义改变**。
> ③ **反证**：同一 vk64.img 在冷 POR/冷 fastboot 路径 3/3=STORM（`trials/*-realpor-run{1,2}`、`*-coldfb-vk64`）⇒「不是冷/暖」不成立；固定路径 reboot2 正是 `#166` 的 NOCARD 粘态机制。
> ⇒ **现口径**：在 reboot2 暖路径上 vk64 亮、vk89/vk64c 不亮；真因未定（4B 布局 / 复位粘态 / vk89 config 差）。本节下表与结论仅作旧记录保留。

> 过程稿全文：`reports/q28-binary-determinism-20261010.md`；经验条目：`PITFALLS #171`。
> 触发：用户指出「冷/暖无法定性，怀疑该说法本身可靠」。遂抛开标签，固定路径观察。

**方法**：固定 `Linux → /usr/local/sbin/reboot2 bootloader → fastboot boot <img>`；判据 = SSH 读
`card0`（`/sys/class/drm` 含 `card0`=GOOD；只有 `version`=NOCARD）。`fastboot boot` 确为 RAM 起
（cmdline token `elden_probe=FBK64` 实证，无 boot_b 回退）。

**台账（21 发）**：

| 镜像 | 内核 | 结果 |
|---|---|---|
| `out/boot-elden-vk64.img`（Oct-8 内核 `8efb2731`） | Oct-8 | **GOOD ×7** |
| `vk89`（clean/base 模块化，新编） | vk89 | NOCARD ×5 |
| `vk89-plain`（vk89 内核 + base ramdisk） | vk89 | NOCARD ×2 |
| `vk64c`（vk64 config 新编 + 当前 ramdisk） | vk64c | NOCARD ×2 |
| `vk64c-oldrd`（vk64c 内核 + **vk64 原 ramdisk**） | vk64c | NOCARD ×2 |
| `vk64c-clean`（`make clean` 全量重编） | vk64c | NOCARD ×3 |

**变量逐个钉死**：路径（token 证明 RAM 起）、ramdisk（vk64c-oldrd 用与 vk64 逐字节同的 ramdisk 仍 NOCARD）、
config（vk64 内核 `extract-ikconfig` 与 `a383cdb9` **0 差异**）、工具链（双方 gcc 15.2.0-16ubuntu1 / ld 2.46）、
源码提交（双方 `-g d02658e63`、无 `-dirty`）、陈旧对象（`make clean` 全量仍 NOCARD）——**全部排除**。

**唯一差异 = 内核二进制本体**：两 `Image` **同大小**（62,540,288 B）、payload sha `8efb2731` vs `ccc0a284`，
字节差 **5,040,884 B（~8%）且高度集中在 32–44 MiB 区**；该区字符串集合一致，差异字节多为相邻小偏移（±4/±16）
⇒ 形态像**数据/指针重定位（布局漂移）**，非大面积代码改写。

**修正后的定案**：
1. **Q28 在当前设备状态 = 「按内核二进制确定性」**：同一二进制该路径恒定复现（非掷骰子），
   换一个同源构建即可整体翻面。→ **冷/暖不是当前判别变量**；B1「~60%」为 vk63 时代跨复位混采旧口径，收窄。
2. Q28 = **对内存/时序极敏感的首发竞态**；内核镜像布局的微小漂移即足以把它推到 GOOD / NOCARD 一侧。
3. Oct-8 `vk64.img` 落在 GOOD 侧 → 保留作 **Q28 GOOD 参照**（新编镜像默认 NOCARD 侧）。

**下一步（二选一，待裁决）**：
- **A 定位机制**：分别 dump 两内核 `/proc/kallsyms`，找 32–44 MiB 区地址位移的函数/表，判定「纯布局」vs「真代码差」。
- **B 借 A/B 搜变量**：以「同源两构建一 GOOD 一 NOCARD」为现象，单因素改构建（`-j`、无害 config 项、
  `KBUILD_BUILD_TIMESTAMP`）看能否把新编推到 GOOD 侧。

**工具修复**：`scripts/assert-kernel-sane.sh` 第 4 项 mtime 陈旧检测对显式 `KERNEL_IMG=`（外部预编内核）误伤，
已改为仅对本树默认 `Image.gz` 生效（外部内核身份由 UTS 对齐保证）。
