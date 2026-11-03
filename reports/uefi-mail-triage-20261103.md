# UEFI/引导链/UFS 邮件分诊 2026-11-03

范围：2026-10-18 起，UEFI / UFS / pakala / mu_wide / SM8750 / firmware / issue 相关。

## 1 上游/项目回复
(待填)

## 2 内核列表相关回复
(待填)

## 3 其他值得看
(待填)

## 统计
(待填)

## 1 上游/项目回复

### QSEECOM / SCM（UEFI 线最相关）
- 2026-11-01 / Haozhen Li <dezige131@foxmail.com> / [RFC PATCH 0/2] firmware: qcom: scm: QSEECOM app loading and listener support（共 3 封 0/1/2）/
  要点：**首次在 upstream 提出 QSEECOM app 加载 + listener 回调支持**（QSEE app 的通用加载接口，含 shutdown）。
  含义：G1-29 间接引导的关键上游地基——若 Mu/SM8750 路线 A 需要从 Linux 侧调 QSEE（如 keystore/keymaster 之外的自定义 app），这可能是挂靠点；值得立刻跟评并关注方向是否被接受。
- 2026-11-02 / Konrad Dybcio / Re: [RFC 1/2] QSEECOM app loading; Re: [RFC 2/2] listener callbacks /
  要点：QCom 侧对 QSEECOM RFC 给出正面回应/审阅（细节待读原文，未证实具体立场）。
  含义：上游接受概率提升信号。
- 2026-11-02 / Dawid Wrobel（2 封）/ Re: [RFC 0/2] QSEECOM listener / 要点：外部用户参与讨论（未证实内容）。
- 2026-11-02 / Haozhen Li / Re: [RFC 1/2], Re: [RFC 2/2] / 要点：作者回帖答复 review，线程活跃。

### QSEECOM allowlist 流水（模式确认用，不逐条读）
- 10-27 Surface Laptop 8th、10-27 Mahua QCB（Abel Vesa 10-27 回）、10-29 Radxa Dragon Q8B v3/v4、10-30 Acer Swift Go Pro AI v6、11-01 HP OmniBook Ultra 14 v2：QSEECOM allowlist 持续扩张；含义：QSEECOM 在 x86 笔电上已成惯例，arm64 设备（含我们）补 allowlist 无阻力。

## 2 内核列表相关回复（UFS/引导链）

- 2026-10-28 / Martin K. Petersen (mkp, SCSI maintainer) / Re: (subset) [PATCH v4 0/5] Add UFS support for Glymur Qualcomm SoC /
  要点：**Glymur（下一代 Qualcomm SoC）UFS 支持已被 mkp 按子集应用**；同批还有 ufs qcom suspend（Milos）与 ufs core clock-scaling deadlock fix 两条。
  含义：路线 A 关注的 qcom-ufs 驱动族正快速演进；SM8750 pakala/UFS init 如需新框架（OPP/QMP phy 变化）需 rebase 跟踪 v5→merged 路径。
- 2026-10-28 / Pradeep P V K / [PATCH v5 0/3] Glymur UFS（含 QMP-UFS phy）+ Konrad Dybcio 回 / 要点：Glymur UFS v5 完整系列进收件箱并获 Konrad review。
- 2026-10-29 / Stanley Jhu (Google) / [PATCH] scsi: ufs: core: Keep clock-gating hold on failed W-LUN runtime resume / 要点：W-LUN resume 失败时保持 clock-gating hold 修复；含义：对我们 UFS runtime PM 稳定性有潜在价值（未证实是否命中我们的症状）。
- 2026-10-27 / Steven Rostedt / [PATCH 6/9] scsi: ufs: tracepoint guarded call sites / 要点：纯基建，仅统计。
- 10-28~11-02 milos-nothing-asteroids Enable UFS v1/v2（Konrad、Dmitry、Abel 回）+ 11-02 eliza CQS EVK eMMC/UFS SoM v4：设备侧 UFS enable 流水，模式参考；不逐条读。
- 2026-10-22 起（我们发出）/ Re: [RFC PATCH] clk: qcom: dispcc-sm8750: reset MDSS when bootloader left it in an unexpected state（Sent 142/143/190/198，INBOX 8173/8174 为自己 cc）/
  要点：**bootloader（XBL/ABL）显示遗留状态**线程——严格说是显示时钟不是 UEFI，但属「引导链交接」主题；10-29 有续发，暂未见维护者裁决（未证实）。

## 3 其他值得看

- 2026-10-29 / Shivendra Pratap / [PATCH v27 03/10,04/10] firmware: psci: command-based resets / PSCI auxiliary devices / 要点：PSCI reset 框架第 27 版仍在推进；含义：与 reboot/引导链有关，G1-29 若依赖 PSCI 语义需留意。
- 2026-10-29 / Bryan O'Donoghue et al. / drm/msm/adreno Soften no-firmware message 讨论 / 要点：firmware 缺失提示软化；与 GPU 固件有关，仅留意。
- 直接回复我们发 Message-ID 的信：8 封（INBOX）——全部在 camcc 显示复位回归 与 dual-DSI NT36536 两条显示线程（Konrad 10-20 回 regression；Pengyu Luo 10-26 回 dual-DSI）；与 UEFI/UFS 无直接关系，仅属项目回复。

## 统计

- 收件箱 332 封命中 grep（16 天）；其中 QSEECOM/UEFI 线约 15+ 封（QSEECOM RFC 线 ~11 封 + allowlist 6 设备）；UFS 主题 ~20 封；其余为 sm8750/camss/firmware 大流水与纯列表 PATCH。
- 纯列表 PATCH（不回复我们、与 SM8750/UEFI/UFS 无关）：大量（camss v2/v3、tegra bpmp、scmi RISC-V、dwc3 sa8255p 等），只计数量不列条。
- Junk 0 封；Sent 38 封命中（多为 camss/camcc 线）。
