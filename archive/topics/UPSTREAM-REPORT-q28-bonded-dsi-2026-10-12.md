# 上游报告 Q28 草稿 — SM8750 bonded 双 DSI + NT36536：冷起首条 DCS 的 command-DMA 超时（2026-10-12）

> 状态：**📝 已准备发送版 v2（2026-10-13）= `out/q28-bonded-dsi-2026-10-13.mail.txt`（见 §10），dry-run 通过、待用户执行发送**。发送动作需人工（GitHub issue / 邮件）。
> 目标收件方向（建议同时发）：
> ① **GEEKiDOS/linux**（本树 origin，`bonded_cmd_xfer`/`peer command DMA timeout` 这条路径出自本树）→ GitHub issue；
> ② **linux-arm-msm / dri-devel / freedreno**（转发 Dmitry Baryshkov、Abel Vesa；nt36536 上游驱动作者 Pengyu Luo）→ 邮件。
> 相关：`PITFALLS #217/#223/#224`、`reports/q28-identity-retest-20261012.md`、`reports/q28-vk113-20261012.md`、`reports/q28-DOSSIER.md`。

## 1. 为什么发（一句话）

我们把 **Q28（冷起「只有背光无桌面」）** 从「镜像构建身份伪影」重新定案为**会话相关的间歇坏发**：
同一批镜像在不同时间窗里坏发率可以是 **0/20+** 也可以是 **4/7（57%）**；
**上游的 byte-clk 取整修复（`2028280686f4`）在我们的镜像上无效**；
而坏发时 **cmD-DMA 引擎自锁**（`status=0x2200200`），运行期无法恢复（重绑会拆掉 DRM）。
这需要上游/维护者判断：这条 bonded cmd 路径的时序要求是什么、以及是否应在驱动内做可恢复处理。

## 2. 现场（硬件/软件）

| 项 | 值 |
|---|---|
| 设备 | Lenovo 拯救者 Y700 四代（TB322FC，SM8750P），A/B 槽，b 槽跑 mainline 持久根 |
| 面板 | Novatek **NT36536**，3K（1904×3040）**DSC video mode**，bonded 双 DSI（`ae94000.dsi` master / `ae96000.dsi` peer） |
| 内核树 | `GEEKiDOS/linux`（`Linux 7.2.0` 基线 + 本机 bring-up 补丁）；`dsi_manager.c` 含 `dsi_mgr_bonded_cmd_xfer()`、`bonded command DMA failed`、`peer command DMA timeout`（**对比的 vanilla 7.2 / Pengyu 快照里没有这套**，故先问上游是否支持） |
| 复现路径 | 物理 POR（断电 → Vol- + 电源进 fastboot）→ `fastboot boot <image>`；判定 = SSH 读全 dmesg + `card0`/DSI-1 状态 + compositor |
| 判据脚本 | `scripts/q28-devprobe2.sh`（L1/L2 拆分 + session 门）、`scripts/q28-cold-run.sh`（+65 s 存活门） |

## 3. 坏发签名（逐字，7/7 样本一致）

```
[    9.032148] msm_dsi ae94000.dsi: command DMA timeout: status=0x2200200
[    9.037910] msm_dsi ae96000.dsi: peer command DMA timeout: status=0x2200200
[    9.037912] msm_dsi ae94000.dsi: bonded command DMA failed: master=-110 peer=-110
[    9.037914] panel-novatek-nt36536 ae94000.dsi.0: sending dcs data ff 20 failed: -110
[    9.096078] panel-novatek-nt36536 ae94000.dsi.0: Failed to initialize panel: -5
[    9.102187] [drm:dpu_encoder_phys_vid_prepare_for_kickoff:576] [dpu error]enc35 intf1 ctl 1 reset failure: -22
[   10.176852] msm_dpu ae01000.display-controller: [drm] vblank wait timed out on crtc 0
```

- 好发在同一步做的是 `panel prepared: scheduling firmware upload`（首条 DCS 成功）。
- 坏发时 `DSI_PLL(0) lock failed`×4 / `device link`×8 **好发也有**（良性噪声）；`card0` 存在但面板从未使能 ⇒ 纯「首条命令超时」。
- 面板驱动自带的 retry 无效（attempt1 `-110` → attempt2 `-5`）⇒ **命令 DMA 引擎在坏发后保持自锁**，只有整机复位能清。

## 4. 已排除（都在同一批镜像上做过受控对照）

| 假设 | 实验 | 结果 |
|---|---|---|
| 构建身份（`#N`/UTS 布局） | 2 位 vs 3 位构建号、同一源码重编、空提交/一行打印等 20+ 发 | **不是充分条件**：当晚 3 位臂照样坏（4 坏/7），历史「3 位 0/20」落在无坏发的时间窗内 |
| 上游 byte-clk 取整（`2028280686f4`） | 把该补丁按上游语义移植到本树（`dsi_link_clk_set_rate_6g()` 内、reparent 之后取整 + `byte_intf_clk_div_2`）→ `vk114` | **仍坏**（签名逐字同） |
| ramdisk / initrd 组合 | 同一内核 + 两套 ramdisk（完整 initramfs vs 模块化 overlay）交替 | 两套都出坏发，未分离出轴 |
| DTB | 换 DTB（含/不含 ADSP `non-secure-domain`） | 结果不变（`reports/q28-storm-bias-audit-20261011.md` §6.1） |
| 断电时长 / POR 质量 | 严格 POR（断电 30 s）后再测 | 仍坏 |
| 运行期恢复 | 坏发台架上 `unbind/bind` panel + `msm_dsi` host | **更糟**：`card0` 消失、fb 切 dummy、GPU hangcheck lockup（`PITFALLS #224`） |

## 5. 时间成簇（我们最初的统计被它误导）

`reports/trials/index.tsv` 里坏发从不单独出现，总成对/成簇：

| 坏发簇（UTC） | 样本 |
|---|---|
| 10-11 15:24–15:27 | `C1`, `D1` |
| 10-12 00:02–00:09 | `E2-110a`, `E1p-v111` |
| 10-12 08:37–08:41 | `vk113-cold2`, `vk94-ctl1` |
| 10-12 09:43–09:48 | `vk114-cold1`, `vk113-cold3` |

同一批镜像在无坏发窗口（10-11 11:51–14:51）可连续 10 GOOD / 6 NOCARD / **0 L1FAIL**。
⇒ 坏发率**随会话/环境漂移**，与镜像身份无关；这解释了为什么「按镜像统计」会得出相反的结论（NOCARD 分支同教训，见 `PITFALLS #192/#195/#217`）。

## 6. 想请上游回答的四个问题

1. `dsi_mgr_bonded_cmd_xfer()`（DSI0 = master/completion source、DSI1 = peer）在 **PHY enable / PLL lock 之后第一条 DCS** 上有没有**文档化的时序约束**？我们的 cmd-DMA 在坏发时 `STATUS0=0x2200200` 且 TRIG 不自清。
2. 命令 DMA 超时是否应由驱动**可恢复**（复位 host/PHY 后重发），而不是让 panel init 永久失败？上游有无先例方向可循？
3. SM8750 + DSC video mode 冷起首条命令是否有已知 erratum？我们已试过 `6cd33b6f4155`/`2028280686f4` 那条 PLL re-lock 系列，症状不匹配。
4. 需要哪些现场（全 dmesg、`dsi`/`phy` 寄存器 dump、CLK_STATUS、rpmh 票）我们都可以提供——本仓有 `patches/q28-dsi-regdump*.patch` 与 `scripts/q28diag-forensic.sh`。

## 7. 发送清单（用户执行）

- [ ] 正文（英文，纯 ASCII）：`out/q28-bonded-dsi-2026-10-12.txt`（issue 版）→ 贴到 GEEKiDOS/linux issue；邮件版把首行 `To:`/`Cc:` 填进邮件头。
- [ ] 建议收件人：GEEKiDOS/linux issue；邮件 `linux-arm-msm@vger.kernel.org`、`dri-devel@lists.freedesktop.org`、`freedreno@lists.freedesktop.org`，Cc `dmitry.baryshkov@oss.qualcomm.com`、`abelvesa@kernel.org`、`konradybcio@kernel.org`（+ nt36536 驱动作者）。
- [ ] 注意（沿用 Q24 教训）：先订阅再发（vger 的 `<list>+subscribe@vger.kernel.org`），24–48 h 后到 lore 复核是否归档。

## 8. 本地证据索引

- 当晚 7 发 + 成簇分析 + 双否证：`reports/q28-identity-retest-20261012.md`（§6/§7）
- 日常候选镜像（3 位身份）+ 否证：`reports/q28-vk113-20261012.md`
- 身份审计（早期结论，已被 §5 降级）：`reports/q28-storm-bias-audit-20261011.md`
- 根因/双模式/判据 SSOT：`reports/q28-DOSSIER.md`
- 训练样本（机器可读）：`reports/trials/index.tsv`（`q28*|vk113*|vk94-ctl*|vk104-ctl*|vk114*`）
- 坏发台架重绑负结果：`logs/q28-rebind-20261012/dmesg-after-rebind.txt`
- 工具：`scripts/q28-devprobe2.sh`、`scripts/q28-cold-run.sh`、`scripts/q28-build-daily-id.sh`、`patches/q28-methodB-round-byteclk.patch`

---

## 9. 正文（可发送版，纯 ASCII，与 out/q28-bonded-dsi-2026-10-12.txt 一致）

（GitHub issue 直接粘贴；邮件则把首行补成 To:/Cc: 头）

```
SM8750 bonded dual-DSI + NT36536 (3K DSC video panel): intermittent first-DCS command-DMA timeout on cold boot

Hi,

We are bringing up a Lenovo Legion Y700 (2025) tablet, TB322FC / Qualcomm
SM8750P, with a Novatek NT36536 panel (1904x3040, DSC, video mode) driven by
bonded dual DSI (ae94000.dsi master, ae96000.dsi peer).

Our kernel tree is GEEKiDOS/linux (a 7.2-based tree that carries the bonded
command path: dsi_mgr_bonded_cmd_xfer() plus the "bonded command DMA failed" /
"peer command DMA timeout" messages).  We could not find that path in the
vanilla 7.2 sources we compared against, so question 1 below is whether it is
upstream-supported at all.

SYMPTOM

On a *cold* boot (power off, then bootloader -> fastboot boot <image>) the very
first DCS command of the panel init intermittently times out and the panel is
never enabled: backlight only, no desktop.  Signature (identical in all 7
failing samples we collected today):

[    9.032148] msm_dsi ae94000.dsi: command DMA timeout: status=0x2200200
[    9.037910] msm_dsi ae96000.dsi: peer command DMA timeout: status=0x2200200
[    9.037912] msm_dsi ae94000.dsi: bonded command DMA failed: master=-110 peer=-110
[    9.037914] panel-novatek-nt36536 ae94000.dsi.0: sending dcs data ff 20 failed: -110
[    9.096078] panel-novatek-nt36536 ae94000.dsi.0: Failed to initialize panel: -5
[    9.102187] [drm:dpu_encoder_phys_vid_prepare_for_kickoff:576] [dpu error]enc35 intf1 ctl 1 reset failure: -22
[   10.176852] msm_dpu ae01000.display-controller: [drm] vblank wait timed out on crtc 0

On a good boot the same step prints "panel prepared: scheduling firmware
upload".  DSI_PLL(0) lock failed x4 and device-link warnings appear on good
boots as well (we treat them as benign noise).  The panel driver's own retry
does not help (attempt 1 -110, attempt 2 -5): the command DMA engine appears to
stay latched (STATUS0 = 0x2200200, TRIG_DMA never self-clears) until the SoC is
reset.

WHAT WE ALREADY RULED OUT (controlled, same images)

* Kernel build identity: 2-digit vs 3-digit KBUILD_BUILD_VERSION, same source
  rebuilt, empty commit / one-line pr_info arms, 20+ cold boots.  We initially
  measured "0 bad / 20+" for 3-digit builds, but that window simply contained no
  failure; today the same class of images failed 4/7.  Failures cluster in time
  (adjacent boots fail; in a clean window 10 boots in a row are fine), so the
  failure rate drifts with session/environment, not with the image.
* Upstream 2028280686f4 ("drm/msm/dsi: round the byte clock rate after
  reparenting to the PHY PLL"): we ported it (round in
  dsi_link_clk_set_rate_6g() after reparent, deriving the byte intf rate from
  byte_intf_clk_div_2).  First cold boot still fails with the identical
  signature.
* ramdisk/initramfs variants, DTB variants, and a strict 30 s power-off POR:
  no effect.
* Runtime recovery by rebinding panel / msm_dsi: this tears down DRM (card0
  disappears, fb switches to dummy, GPU hangcheck reports phoc) instead of
  recovering.

QUESTIONS

1. Is there a documented ordering requirement for the bonded command path
   (DSI0 master / DSI1 peer) before the *first* DCS after PHY enable / PLL
   lock?  Our engine latches with STATUS0 = 0x2200200.
2. Should this timeout be recoverable in the driver (reset host/PHY and
   re-issue the command) instead of failing panel init permanently?  Is there
   an upstream direction/precedent we should follow?
3. Any known SM8750 / DSC video-mode erratum for the first DCS after a cold
   boot?  We already looked at the PLL re-lock series (6cd33b6f4155 and
   2028280686f4); the symptom does not match.
4. Would you like the full dmesg, dsi/phy register dumps, CLK_STATUS and RPMh
   votes from a failing boot?  We can provide both good and bad captures and
   our repro scripts.

Thanks,
<xuqianhui1001@gmail.com>
```

---

## 10. 2026-10-13 更新（发送版 v2，文件名已改日期）

**可发送文件**：`out/q28-bonded-dsi-2026-10-13.mail.txt`（带 `To:/Cc:/Subject:` 头，纯 ASCII，117 行；dry-run 通过：`python3 ~/.local/bin/send-mail-ustc.py out/q28-bonded-dsi-2026-10-13.mail.txt` ⇒ 7 收件人、Message-ID `<…@mail.ustc.edu.cn>` 保真）。旧的 issue 版正文 `out/q28-bonded-dsi-2026-10-12.txt` 保留（GitHub issue 用）。

**v2 比 v1 新增的三条硬证据**：

1. **第三形态：bootloader ACK 但无 SSH / 无 fastboot / 仅背光，30+ min 不可达**（2026-10-13 07:21，`vk94` 第 5 发，`PITFALLS #231`）⇒ 说明失败有时**打不到用户态**：设备侧看门狗（用户态脚本）也救不了。
2. **寄存器级否证：DSI 侧复位清不掉该状态**（`vk125-resetterm`）——`before-reset CTRL=0x175/STATUS0=0x20003/CLK_STATUS=0x3743/CMD_DMA_CTRL=0xd4000000` → 清闩锁 + 双链路 ctrl/PHY 复位 + 强制原厂 `ctrl_reset()` 终态（引擎关、`CLK_CTRL=0x00`）→ **`CLK_STATUS` 确实掉到 `0x1403`（DYN 位被清）** → 但 `link_power_on` 后立刻回到 `0x1743`、`STATUS0` 仍 `0x20003`，重试逐字 `-110`（连续 3 次寄存器序列完全相同）⇒ 动态像素时钟请求在 **power-on 阶段被重新拉起**、请求源在 DSI 控制器之外。
3. **同窗配对无身份效应 + 成簇实证**：2026-10-13 06:39–07:21 同窗（真实 POR）`#60` 1 坏/1 好（+1 未定 NOROUTE）vs 3 位臂 2 好 ⇒ 窗内无可辨身份效应；`#60` 07:10 坏 / 07:17 好（相隔 7 min）⇒ 跨窗聚合不能当因果证据。

**发送前置**：先订阅（`linux-arm-msm+subscribe@vger.kernel.org` 等），发出后 24–48 h 用 `python3 ~/.local/bin/lore-query.py` 或按 Message-ID 直取 raw 复核归档（lore inbox 路径不能按列表名猜；详见技能 `upstream-mail-ustc`）。

## 11. 2026-10-13 待发正文全文留档（v2 发送版；`out/` 不入 git，故在此留存）

> 待发文件 = `out/q28-bonded-dsi-2026-10-13.mail.txt`（dry-run 通过：7 收件人 / 118 行 / 纯 ASCII / Message-ID 保真）；**本次发送待用户点头**（先确认已订阅 `linux-arm-msm`）。

```
To: linux-arm-msm@vger.kernel.org
Cc: dri-devel@lists.freedesktop.org, freedreno@lists.freedesktop.org, dmitry.baryshkov@oss.qualcomm.com, neil.armstrong@linaro.org, abelvesa@kernel.org, mitltlatltl@gmail.com
Subject: [REPORT] SM8750 bonded dual-DSI + NT36536: first DCS command-DMA timeout on cold boot (DMA engine stays latched; DSI-side reset does not clear it)

Hi,

We are bringing up a Lenovo Legion Y700 (2025) tablet, TB322FC / Qualcomm
SM8750P, with a Novatek NT36536 panel (1904x3040, DSC, video mode) driven by
bonded dual DSI (ae94000.dsi master, ae96000.dsi peer).  Our tree is
GEEKiDOS/linux, a 7.2-based tree that carries the bonded command path
(dsi_mgr_bonded_cmd_xfer() plus the "bonded command DMA failed" / "peer command
DMA timeout" messages).  We could not find that path in the vanilla 7.2 sources
we compared against, so question 1 is partly whether it is upstream-supported
at all.

SYMPTOM

On a *cold* boot (power off -> bootloader -> fastboot boot <image>) the very
first DCS command of the panel init intermittently times out and the panel is
never enabled.  Warm reboots do not reproduce this signature (a warm reboot
reproducibly ends up in mode (b) below); all three modes are cold-boot only.
Signature, identical in all failing samples:

  [    9.032148] msm_dsi ae94000.dsi: command DMA timeout: status=0x2200200
  [    9.037910] msm_dsi ae96000.dsi: peer command DMA timeout: status=0x2200200
  [    9.037912] msm_dsi ae94000.dsi: bonded command DMA failed: master=-110 peer=-110
  [    9.037914] panel-novatek-nt36536 ae94000.dsi.0: sending dcs data ff 20 failed: -110
  [    9.096078] panel-novatek-nt36536 ae94000.dsi.0: Failed to initialize panel: -5
  [    9.102187] [drm:dpu_encoder_phys_vid_prepare_for_kickoff:576] [dpu error]enc35 intf1 ctl 1 reset failure: -22
  [   10.176852] msm_dpu ae01000.display-controller: [drm] vblank wait timed out on crtc 0

On a good boot the same step prints "panel prepared: scheduling firmware
upload".  "DSI PLL(0) lock failed" x4 and device-link warnings also appear on
good boots (we treat them as benign noise).

THREE FAILURE MODES, ALL COLD-BOOT ONLY

(a) panel-init timeout with the system up: card0 exists, DSI-1 connected, SSH
    reachable, only backlight - the signature above.  Most common.
(b) no card0 at all (DSI host probe fails earlier).
(c) *new* 2026-10-13: bootloader ACKs the image, but there is no SSH and no
    fastboot at all for 30+ minutes, backlight only.  In this mode the machine
    never reaches userspace, so even an on-device watchdog cannot recover it.

REGISTER-LEVEL EVIDENCE (bad boot, instrumented)

We patched the DSI path to dump state around the failure and to attempt
recovery.  Bad boot, all timestamps in one boot:

  first DCS times out (status=0x2200200)
  before-reset : CTRL=0x175  STATUS0=0x20003  CLK_STATUS=0x3743  CMD_DMA_CTRL=0xd4000000  INTR_CTRL=0x2200200
  after our reset (see below): CTRL=0x0 CLK_CTRL=0x0 CLK_STATUS=0x1403
  after link re-power-on    : CTRL=0x171  STATUS0=0x20003  CLK_STATUS=0x1743  CMD_DMA_CTRL=0x14000000
  retry of the first DCS    : failed: -110 (identical registers, three attempts in a row)

What we did in that window: cleared the driver-side failure latch, powered the
link down and up again (clock rate set, clock enable, PHY reset/re-lock, ctrl
enable), and additionally forced the terminal state of the stock
ctrl_reset() sequence (engines off, CLK_CTRL = 0x00) on both controllers before
re-enabling.  The last step *did* take effect - CLK_STATUS dropped from 0x3743
to 0x1403, i.e. the DYN_PCLK / DYN_CMD_PCLK / CMD_PCLK bits were cleared while
CLK_CTRL was 0 - but as soon as the link is powered on again CLK_STATUS returns
to 0x1743 and STATUS0 stays 0x20003 (ENGINE|DMA busy).

So: the failure is not a state we can clear from inside the DSI controller.  It
looks like the dynamic pixel-clock request is re-asserted during link power-on
and the command engine stays busy; PLL_UNLOCKED is not set (the PLL is locked),
the DSI interrupt counters do not advance while the engine is busy, and the
registers before the first command are byte-identical to those of a good boot.

WHAT WE RULED OUT (controlled, same images)

* Kernel build identity: 2-digit vs 3-digit KBUILD_BUILD_VERSION, same source
  rebuilt, empty-commit / one-line-pr_info arms, 20+ cold boots.  We first
  measured "0 bad / 20+" for 3-digit builds; that window simply contained no
  failure, and the same class of images later failed 4/7.  Pairing #60 against
  a 3-digit arm inside one window showed no measurable identity effect.
* Failures cluster in time: adjacent cold boots fail, and a clean window can
  give 10 good boots in a row.  Rate drifts with session/environment, not with
  the image.
* Upstream 2028280686f4 ("round the byte clock rate after reparenting to the
  PHY PLL"): ported to this tree with upstream semantics (rounding inside
  dsi_link_clk_set_rate_6g(), byte-intf rate from byte_intf_clk_div_2).  First
  cold boot still fails with the identical signature.
* Driver-side recovery: clearing the failure latch and resetting DSI ctrl+PHY
  (both links) + retrying, as described above.
* Forcing the stock ctrl_reset() terminal state (CLK_CTRL = 0x00) before
  re-enabling - the DYN bits come back on power-on (see above).
* Using the standard broadcast command path instead of the tree's custom bonded
  sequence: same hang, different error path.
* Enabling-time dynamic force-on (vendor-style CLK_CTRL force-on around DSI_EN,
  both transient and held for the whole panel-init window): still fails, and the
  DYN bits are latched in the forcing case too.
* ramdisk/initramfs variants, DTB variants, strict 30 s power-off POR: no effect.
* Runtime recovery by rebinding panel / msm_dsi: this tears DRM down (card0
  disappears, fb switches to dummy, GPU hangcheck) instead of recovering.

QUESTIONS

1. Is there a documented ordering requirement for the bonded command path
   (DSI0 master / DSI1 peer) for the *first* DCS after PHY enable / PLL lock?
   Our engine latches with STATUS0 = 0x2200200 and TRIG_DMA never self-clears.
2. Given that a DSI-side reset cannot clear it, is the dynamic pixel-clock
   request supposed to be dropped by the client (dispcc / INTF) side, and is
   there a known issue with that handshake on SM8750?  Should the DSI driver
   wait for the DYN domain to settle before the first command?
3. Should this timeout be recoverable in the driver (reset host/PHY and
   re-issue) instead of failing panel init permanently?  Is there an upstream
   precedent we should follow?
4. Any known SM8750 / DSC video-mode erratum for the first DCS after a cold
   boot?  We looked at the PLL re-lock series (6cd33b6f4155 and 2028280686f4);
   the symptom does not match.
5. Would you like the full dmesg, DSI/PHY register dumps, CLK_STATUS, RPMh
   votes, and our repro scripts, from both a good and a bad boot?  We have both
   and can attach them.

Thanks,
Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>

The bring-up tree is GEEKiDOS/linux plus local patches; we are happy to publish
the repro scripts (cold-boot runner, three-state probe) and the failing-boot
captures if that helps.  Happy to test any patch you suggest on the device.
```
