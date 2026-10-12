# 上游报告草稿 — SM8750 cambistmclkcc 电源域导致 display blank 时硬复位

> 状态：**✅ 已发送（2026-10-08 09:16，用户验收）** — 通过 Outlook 网页 SMTP 通道发至 linux-arm-msm@vger.kernel.org，Cc Taniya Das / Bjorn Andersson / Konrad Dybcio / Abel Vesa / linux-clk / devicetree / 自己留底。
> ⚠️ **2026-10-10 取证：该邮件未进 lore 归档**（搜 cambistmclkcc 共 166 条，最新 10-02 upstream RFC，无本 Regression 帖）——SMTP 发出 ≠ 已进列表（vger 首帖有审核门）。
> 状态 2：**✅ v2 已重发（2026-10-10，用户手动验收）** — Outlook 网页重发 `[Regression v2] … MX-only binding insufficient`（收件人 linux-arm-msm@vger + Cc Taniya/Bjorn/Konrad/Abel Vesa 5 块、正文 2939 字符含 10-08 后全部新数据：MX-only 3 轮 2 掉电、bare clock controller 半成品态机理链、MX_AO/MXC_AO + PM lifecycle 两问）。**agent 代填全部就绪后点发送被风控拦下（邮件落草稿夹），用户手动重发成功**——浏览器高频自动化操作触发 Outlook 风控，发送类动作需用户手动执行（教训）。正文存 `out/q24-regression-v2-email.txt`；后续盯 lore 归档 + 回复（预期被问 MX_AO 语义与 PM lifecycle 修复可上游性，E4a 结论 MXC 单票可直接回填）。
> 发送所用干净 patch（纯 ASCII）：内核提交 `be79b256d`（实验版 `86ea33c25`）。
> 后续：盯 lore.kernel.org/linux-arm-msm 回复（可能要求 rebase 到 v7.1-rc1+ 或改 `vdd_mx-supply` 写法）。
> **2026-10-12 追加：v1/v2 经复核均未进 lore 归档；本轮数据推翻 v1/v2 两条结论（单模块触发、MX-only 规避）⇒ 已起草 v3，见 `archive/topics/UPSTREAM-REPORT-cambist-q24-v3-2026-10-12.md`，正文 `out/q24-regression-v3-email.txt`（待用户发送）。**
> 相关上游系列：`[PATCH v4] arm64: dts: qcom: sm8750: Add camera clock controller`
> （lore: 20260511-sm8750_camcc_dt-v4-1-eab4b6c3eaea@oss.qualcomm.com，Bjorn 已指出需 rebase 到 v7.1-rc1+）
> 驱动：`[PATCH 3/3] clk: qcom: camcc: Add camera clock controller driver for SM8750 SoC`
> （lore: 20251202-sm8750_camcc-v1-0-b3f7ef6723f1@oss.qualcomm.com）

---

## 邮件正文（英文草稿）

Subject: [Regression] SM8750 cambistmclkcc: hard reset on display blank unless the node is bound to MX only

Hi,

While bringing up mainline Linux on a Lenovo Y700 4th gen tablet (TB322FC,
SM8750/P, board dts sm8750-lenovo-elden), we hit a reproducible hard
reset/power-loss triggered by the combination of the cambistmclkcc clock
controller and display blanking (DPMS off via the desktop screensaver, no
system suspend involved). pstore/kmsg show no trace — it looks like an
RPMh power-domain collapse taking the whole SoC down.

### Reproduction

- Load the `cambistmclkcc-sm8750` module (driver as posted upstream;
  no consumer, all clocks unprepared, usecount 0).
- Trigger display blank from userspace
  (`org.gnome.ScreenSaver.SetActive(true)`; DPMS off only, mem is s2idle
  and never entered).
- The device hard-resets / loses power with a probability of ~100% per
  blank on the stock DT, reproducible across 60+ bisect rounds.

Control groups (each >=3 rounds, with a no-camera-module control group):

| modules loaded                | result            |
|-------------------------------|-------------------|
| qcom-camss alone              | survives          |
| camcc-sm8750 + camss          | survives          |
| i2c-qcom-cci + camss          | survives          |
| wl2868c-regulator + camss     | survives          |
| **cambistmclkcc-sm8750 alone**| **resets ~3/3**   |
| none (control)                | survives          |
| system_heap (dma-heap)        | survives          |

So the trigger is the cambistmclkcc block specifically, not the camss
pipeline. The stock Lenovo vendor kernel does not instantiate this block
at all (no cambistmclkcc node in the vendor dtsi), which is presumably why
this was never seen internally.

### DT-level experiments

Upstream v4 node:

    power-domains = <&rpmhpd RPMHPD_MMCX>, <&rpmhpd RPMHPD_MX>;
    required-opps = <&rpmhpd_opp_low_svs>, <&rpmhpd_opp_low_svs>;

- **H1**: drop `power-domains`/`required-opps` entirely
  → survival improves from 0/3 to 7/9 (still ~20% intermittent resets).
- **H2**: keep a single power domain, MX only
  (`power-domains = <&rpmhpd RPMHPD_MX>` + low_svs)
  → user-verified healthy: repeated display blank/wake cycles via the
  power key, no reset, camera modules loaded.

Driver-side toggles (`use_rpm=false`, dropping the critical SLEEP_CLK
cbcr) did not change the outcome (6/9, 7/9 respectively), so the coupling
appears to be at the power-domain/DT level, not in the clock driver logic.

### Hypothesis

v3→v4 of your DT series describes MX/MXC as the always-on rail that "can
sustain this usecase" for camcc. Our data points the same way: with the
cambist node voting on MMCX, the display-blank path (which gates MMCX
consumers) interacts badly with the cambist GDSC/clock state and the
domain collapses far enough to take the SoC down. Binding cambist to MX
only — a rail that stays on across blank — removes the failure.

### Questions

1. Is MMCX the right vote for cambistmclkcc on SM8750, or should it be
   MX (always-on) only, mirroring what the vendor kernel does by not
   touching the block from Linux at all?
2. Is the vendor DT's `vdd_mx-supply` model (regulator instead of
   rpmhpd) the intended representation for this block?

Device/kernel details on request (vendor kernel baseline, dmesg, dtb
diffs, our repro sweep script). We're happy to test any follow-up
patches on hardware.

Best regards,
<姓名 / 邮箱>

---

## 证据指针（本仓库）

- 复现脚本：`scripts/sleep-sweep.sh`（实时落盘、可回 fastboot 兜底）
- H2 DTB diff：`linux/arch/arm64/boot/dts/qcom/sm8750.dtsi:2092`（提交 `86ea33c25`，分支 vk53-hw）
- 镜像：`out/boot-elden-vk63.img`（kernel vk47clean + H2 DTB + elden_nocamera=1）
- 二分结论：`PITFALLS.md` #132、`TASKS.md` §5 Q24 / §7 G1-33
- 本轮记录：`archive/topics/`（H2 判定 = 用户实机确认健康，2026-10-07）

## 发送前待办（✅ 已全部完成 2026-10-08）

- [x] 用户补姓名/邮箱签名（Qianhui Xu <xuqianhui1001@outlook.com>）
- [x] patch 转纯 ASCII（H1/H2 注释改英文，重做 commit 链 `171de3ae0`→`c53e471be`→`be79b256d`；`dtbs_check` 通过）
- [x] 发送通道：Outlook 网页（用户登录 + 代填），凭据不落盘；`scripts/send-upstream-report.py` 保留为备用（走 `OUTLOOK_APP_PASSWORD`）
- [x] 已在「已发送」邮件夹确认（2026-10-08 09:16）
