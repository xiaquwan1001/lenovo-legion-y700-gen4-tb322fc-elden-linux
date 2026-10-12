# 上游报告 v3 草稿 — SM8750：`cambistmclkcc`+`camcc` **配对**在熄屏时硬复位 SoC（2026-10-12）

> 状态：**📝 草稿就绪，待用户发送**（2026-10-12）；正文 = `out/q24-regression-v3-email.txt`（**纯 ASCII，5131 字节**，已校验非 ASCII 字节 = 0）。
> 前序：v1（2026-10-08）/ v2（2026-10-10）见 `archive/topics/UPSTREAM-REPORT-cambist-q24-2026-10-08.md`；**2026-10-12 复核 lore：`linux-arm-msm/?q=cambistmclkcc` 仍无任何 `[Regression]` 帖 ⇒ v1/v2 均未见归档**（正文见 `out/q24-regression-v2-email.txt`）。

## 1. 为什么必须有 v3（不只是补数据）

本轮（2026-10-12 第 8–9 轮）用**三值仪表硬门**（会话 `GetActive` + `DPMS` + RPMh 降档票）重测，**推翻 v1/v2 的两条结论**：

| # | v1/v2 的说法 | 本轮结论 |
|---|---|---|
| 1 | 「触发器 = `cambistmclkcc` 单模块」 | **错**：`camcc` 单独存活、`cambist` 单独存活、**两者同载才致死**（配对 = 最小触发） |
| 2 | 「绑 MX-only 是有效规避（降频）」，附补丁 `be79b256d` | **撤回**：DTB-only 还原上游 `MMCX+MX` 绑定（控制组逐字节复现基线 DTB）后**照样死**，RPMh 票尾与 MX-only 逐字相同 ⇒ 电源域绑定不是杠杆；「半成品裸时钟控制器撞坍缩轨」的机理故事**未获证实** |

## 2. v3 新增的三条硬证据（邮件正文核心）

1. **致死 = SoC 级复位，且自恢复**：无 pstore/无内核信息、USB PHY 掉线；当日 5 次受控致死**全部自动恢复**（USB 重枚举在掉线后 **28–42 s**；其中 2 次直接以 SSH 登录 + **新 boot_id** 确认）⇒ 不是软件崩溃、也不需要人工干预。
2. **PMIC 侧无记录**：事件前后全量 dump SPMI 各 slave（`/sys/kernel/debug/regmap/0-00..0-09/registers`），**主 PMIC 的 PON 块 `0x1300-0x13ff` 逐字节相同**（无 latched reason、无 fault 位）；SoC 硬件看门狗 `Hard watchdog permanently disabled` ⇒ 非看门狗复位。
3. **排除的其它靶**：`interconnect`/BCM（`0x500xx` MC0/SH0/SH1/ACV）票在**致死与存活的熄屏里同址同型**；GPU `power/control=on`（消除 runtime-resume）**不解决**；末帧 = 合成器使能 `disp_cc_mdss_*`；面板未 init 的台架上致死点移到**唤醒**方向 ⇒ 致死点随显示电源转换移动。

## 3. 邮件正文里的四个问题（需要上游/Qualcomm 回答）

1. `cambistmclkcc` 以「无 GDSC、无 consumer 的裸时钟控制器」形态使用是否被支持？为何**必须与 `camcc` 同时 probe** 才触发（邮件里引用了上游 maili/hawi camss RFC「两者一起添加」的现象）。
2. 相机 BIST 块与显示（dispcc）在共享 MMCX/MX 域上的电源/时钟坍缩是否存在**文档化顺序约束**？
3. SM8750 上事件后可从 Linux 读到的**复位原因源**是什么（PON 无记录、无 pstore；是否有 AOP/CPUCp crash/health 寄存器或 smem scatter）？
4. 在根因清楚前，发行版的安全默认应取哪种（always-on vote / `vdd_mx` supply 绑定 / 延后 `cambistmclkcc` probe 到显示关闭）？我们可上机验证。

## 4. 发送清单（用户执行）

- [ ] 正文：`out/q24-regression-v3-email.txt`（把前 3 行的 `To:`/`Cc:`/`Subject:` 填进邮件头，正文从 `Hi,` 起）；**待发送副本已放 `~/文档/elden-upstream-v3-email.txt`，订阅信 + 步骤见 `~/文档/elden-vger-subscribe.txt`、`~/文档/elden-上游通知-发送步骤.md`（2026-10-12 定稿，采用方案 A：先订阅再发）**。
- [ ] To：`linux-arm-msm@vger.kernel.org`；Cc（**2026-10-12 按 MAINTAINERS/绑定 yaml 校正**）：`andersson@kernel.org`、`konradybcio@kernel.org`、`abelvesa@kernel.org`（**`abel.vesa@linaro.org` 已失效：Gmail 554 no such user**）、`quic_tdas@quicinc.com`（树内 sm8750-gcc.yaml 权威）、`quic_jkona@quicinc.com`（camcc 绑定作者）、`linux-clk@vger.kernel.org`、`devicetree@vger.kernel.org`；自留底 `xuqianhui1001@outlook.com`。
- [ ] 通道：Outlook 网页（**发送动作必须用户点**；上次 agent 代填触发风控、邮件落草稿箱，见 `.pi` 教训）。
- [ ] ⚠️ **先解决「发了但没进列表」的问题**：v1/v2 均未归档，可能是①发件地址未订阅 vger ⇒ 首帖进审核且未放行；②被静默丢弃。建议二选一：**先订阅** `linux-arm-msm`（vger 用 `majordomo@vger.kernel.org`，`subscribe linux-arm-msm`）再发；或**同时**直发一位维护者（如 Bjorn Andersson）并在正文首段说明「前两次投稿未出现在归档」。
- [ ] 发送后 24–48 h 复核 `https://lore.kernel.org/linux-arm-msm/?q=cambistmclkcc` 是否出现 `[Regression v3]`；检查「已发送」与收件箱是否有 bounce/审核通知。

## 4b. 投递事故（2026-10-12）

- 首轮 v3 因 `abel.vesa@linaro.org` 被拒（`554 5.1.3 no such user`）产生退信；已改 `abelvesa@kernel.org`。其余收件人未见退信 ⇒ 用修正后的地址**重发一次**即可。

## 5. 预期回复与可回填数据

- 若问 **MX_AO/MXC_AO 语义**：可用 `rpmhpd.c` 的 `to_active_sleep()` 对 active_only 域清零 sleep 票的代码事实回答（v2 已问过）。
- 若问 **PM lifecycle 可上游性**：`use_rpm=false`（6/9）与去 `critical_cbcrs`（7/9）均无改善 ⇒ 无修可提。
- 若要求 **更多现场**：可直接复用 `scripts/q24-kill.sh`（`ARM=pair|cambist|camcc`、`PMIC=1`）+ `scripts/q24-pmic-diff.sh` 出数据；串口/PMIC dump 全在 `logs/q24-*`。

## 6. 本地证据索引

- 受控差分 + 死法：`reports/q24-noc-20261012.md`（§2 NoC 否证、§3 自恢复复位）
- 死法取证 + 触发矩阵：`reports/q24-r9-20261012.md`（§4 PMIC/WDT、§5 矩阵）
- 机制轮：`reports/q24-mech-20261012.md`（GPU PM 否定、末帧 dispcc）
- H1 DT 臂否证：`reports/q24-h1-result-20261012.md`（+ `patches/q24-h1-cambist-dt.patch`）
- 纪律：`PITFALLS #209`（自恢复复位、无需 POR）、`#210`（NoC 否证）、`#211`（PMIC/WDT）、`#212`（最小触发=配对）
## 7. 邮件正文（最终版，纯 ASCII，与 `~/文档/elden-upstream-v3-email.txt` 和 `out/q24-regression-v3-email.txt` 一致）

（正文首段含 DELIVERY NOTE；发送时从第 4 行的 Subject 起照抄邮件头，正文从 Hi, 起）

\`\`\`
To: linux-arm-msm@vger.kernel.org
Cc: Bjorn Andersson <andersson@kernel.org>, Konrad Dybcio <konradybcio@kernel.org>, Abel Vesa <abelvesa@kernel.org>, Taniya Das <quic_tdas@quicinc.com>, Jagadeesh Kona <quic_jkona@quicinc.com>, linux-clk@vger.kernel.org, devicetree@vger.kernel.org, xuqianhui1001@outlook.com
Subject: [Regression v3] SM8750: cambistmclkcc + camcc together hard-reset the SoC on display blank

Hi,

Third revision of a regression report about SM8750 (Lenovo Y700 4th gen tablet,
TB322FC, board dts sm8750-lenovo-elden) being hard-reset by the camera clock
controllers when the display is blanked.

DELIVERY NOTE (please read): the two earlier revisions (2026-10-08 and
2026-10-10) do not appear in the linux-arm-msm archive, and neither does any
[Regression] mail from this address. If an older copy of this report reaches you
later from a moderation queue, please ignore it and review this revision: the
data below supersedes it, and it also withdraws two of its claims.

### Corrections to the earlier revisions

1. "The trigger is the cambistmclkcc block specifically" is wrong. With a strict
   user-space gate on the same kernel (modules probed, all clocks unprepared, no
   consumers, no camss/cci/regulator drivers loaded):

     cam = 0                     blank, hold 60 s, resume  -> alive
     camcc-sm8750 only           blank, hold, resume       -> alive
     cambistmclkcc-sm8750 only   blank, hold, resume       -> alive
     both loaded                 first real blank           -> SoC reset

   The earlier single-module results were gate artifacts: our older blank test
   did not verify that the panel actually left the active state.

2. The "bind cambistmclkcc to MX only" workaround (be79b256d, attached to the
   previous revision) is withdrawn. We rebuilt the device tree only, restoring
   the upstream binding (power-domains = <&rpmhpd RPMHPD_MMCX>, <&rpmhpd
   RPMHPD_MX> + low_svs) and verified that the control build reproduces our
   baseline DTB byte for byte. The SoC still resets, with an RPMh vote tail
   identical to the MX-only build. The power-domain binding is not the lever,
   and our "half-built bare clock controller collides with a collapsing rail"
   story is therefore not confirmed - please treat it as an open question, not
   as a root cause. No fix patch is attached to this revision.

### Death signature (what we can measure)

- SoC level reset, not a software crash: no pstore and no kernel message, the
  USB PHY drops, and the device reboots by itself into the flashed OS. In the
  five death events we instrumented today the recovery was always automatic,
  28-42 s after the USB disconnect; two of them were confirmed by an SSH login
  showing a new boot_id.
- PMIC: dumping all SPMI slaves through debugfs before and after the event shows
  the PON register block (0x1300..0x13ff of the main PMIC) byte-identical, i.e.
  no latched PON reason and no fault bit. The SoC hardware watchdog is disabled
  ("Hard watchdog permanently disabled"), so this is not a watchdog reset.
- Tracing: the last frames are the compositor enabling disp_cc_mdss_* clocks
  (blank direction). On a bench where the panel did not initialize, the death
  moves to the resume direction (GPU domain bring-up) - the death point follows
  the display power transition.
- Interconnect: BCM/RPMh votes during a dying blank are identical in address and
  shape to a surviving blank (MC0, SH0, SH1, ACV) and icc_set_bw paths look
  normal, so this does not look like a NoC bandwidth vote problem.
- Pinning the GPU power/control to "on" (no GPU runtime resume on resume) does
  not prevent the reset.

### Reproduction

- mainline 7.2 based tree, no vendor patches affecting clocks or genpd.
- modprobe cambistmclkcc-sm8750 and camcc-sm8750.
- real display blank from userspace (org.gnome.ScreenSaver.SetActive(true),
  DSI DPMS off; no s2idle or system suspend involved) -> reset within seconds.
- on benches where the panel fails to initialize, the same reset is provoked by
  the resume direction instead (SetActive(false)).

### Questions

1. Is cambistmclkcc supposed to be usable as a bare clock controller with no
   GDSC and no consumer? The failure needs BOTH camcc and cambistmclkcc to be
   probed. Is there a hardware coupling that requires the camcc side to be
   powered while the camera BIST block keeps its AHB clock and PLL programmed?
   (The maili/hawi camss RFC adds both nodes together, which makes us suspect
   they are not independent on this generation.)
2. Is there a documented ordering constraint between the camera BIST block and
   display power/clock collapse (dispcc) on the shared MMCX/MX domains? Any
   display power transition, blank or resume, with both controllers loaded
   takes the SoC down instantly, and we cannot see that interaction in the clock
   or genpd code paths.
3. Which reset-reason source exists on SM8750 that we could read from Linux after
   such an event? PON latches nothing and there is no pstore. Is there an AOP or
   CPUCp crash/health register, or a smem scatter area, that records
   "PS_HOLD dropped" versus "cold reset"?
4. Until the root cause is known, what default would you recommend for
   distributions: an always-on vote for cambistmclkcc, a required vdd_mx supply
   binding, or deferring cambistmclkcc probe until the display is off? We can
   test any of these on hardware and report back.

We can run further experiments (registers, traces, chip revisions) on request.

Thanks,
Xuqianhui (elden bring-up, Lenovo Y700 Gen4 / SM8750)\`\`\`
