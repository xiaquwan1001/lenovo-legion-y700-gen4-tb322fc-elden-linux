# 上游邮件分诊 — Q24 / Q28（2026-10-19）

> 角色：worker / researcher（只读邮箱，**未发任何邮件**、未改 `.gitconfig`/凭据、未碰设备）。
> 目标：读最近 30 天全部邮件，按 **Q24**（熄屏掉电 / cambistmclkcc+camcc 时钟 / Taniya Das 线程）、
> **Q28**（DSI 面板 init 间歇失败 / dsi_7nm_phy / PLL_SYSTEM_MUXES / dispcc DYN pclk / 上游 DSI 线）分诊，
> 确认 **T5 待办**与 **M1/M3 补丁串**的回复状态，给可执行下一步。
> 前序档案（已读，避免重复）：`reports/mail-triage-20261017.md`、`reports/lanes/20261014-upstream-replies.md`、
> `reports/q28-DOSSIER.md`、`reports/q24-q28-narrative-archive-20261019.md`、`TASKS/README.md` §4 T5 / §7 M1–M7。

---

## §1 拉取清单与命令

### 1.1 通道与范围（实测）

| 项 | 值 |
|---|---|
| IMAP | `mail.ustc.edu.cn:993`（`imap.ustc.edu.cn` 无 DNS）；凭据 = GNOME keyring（service `smtp`，条目 `smtp.ustc.edu.cn:465` 复用） |
| 账号 | `xiaqinghuan@mail.ustc.edu.cn`（= `Qianhui Xu`） |
| 文件夹 | `INBOX` / `"Junk E-mail"` / `"Sent Items"` |
| 时间窗 | `SINCE 19-Sep-2026`（30 天） |
| 命中量 | 头扫描 **7680 封**（INBOX 7612 / Sent Items 46 / Junk 22）；主题/回信相关集正文落盘 **2149 封**（`/tmp/maildump30/`），其中再按 Message-ID 精取 **93 封**（`/tmp/mailfocus*/`） |
| 我方 Message-ID 基数 | **46**（Sent Items 全部） |
| 引用我方 Message-ID 的独立邮件 | **34**：我方自回 13 + **外部 21**（其中上游相关 **18**；另 2 封校内实验室咨询、1 封 `postmaster` 退信），逐条见 §2–§4 |
| lore 复核 | `cambistmclkcc` 线程 3 件齐；`bonded dual-DSI` 线程 4 件齐（v2 报告 **0 回复**） |

### 1.2 命令（可复现）

```bash
# 官方脚本（头列表，常用）
python3 ~/.local/bin/read-mail-ustc.py --days 30 --limit 400
python3 ~/.local/bin/read-mail-ustc.py --days 30 --replies-only
python3 ~/.local/bin/read-mail-ustc.py --days 14 --grep cambist,camcc,dsi,panel,clk

# 本次为了「按 Message-ID 精确取正文 + 去重 + 落盘」写的两个只读辅助脚本（/tmp，不入库）
python3 /tmp/kwmail.py  --days 30 --dump /tmp/maildump30        # 全量头 + 相关集正文
python3 /tmp/fetchbody.py /tmp/mids.txt /tmp/mailfocusN        # 按 Message-ID 清单取正文

# lore 复核（Anubis 自动过挑战）
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-arm-msm/?q=s%3Acambistmclkcc"
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-arm-msm/?q=s%3Abonded+dual-DSI"
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-arm-msm/179206690897.1177097.7309368787214649515@mail.ustc.edu.cn/"
```

正文快照目录：`/tmp/maildump30/`（2149 个命中文件）、`/tmp/mailfocus{,2,3,4,5,6,7,9}/`。
（`/tmp` 非持久；**关键邮件全文已在本文档逐条摘要**，无需重跑即可用。）

### 1.3 一句话结论

- **Q24**：Taniya Das 自 **10-13** 起**没有任何新回信、也没有催促**；她一次性的数据请求（dmesg + `pm_genpd_summary` + `clk_summary`）**仍欠着 6 天**（T5 = 未完成）。同期上游出现**两件与 Q24 机制直接同源的新工作**（Konrad 的 clk-dvfs RFC 16 件、Abel 的 genpd boot performance floor 4 件）——后者正是我们 N1b 观察到的「provider 在 `sync_state` 前夹到最高档」的**上游正式表述**。
- **Q28**：`[REPORT v2]`（10-15）**依然 0 回复**（lore 线程 + 邮箱双向确认）；M1 的 `PLL_SYSTEM_MUXES` 修复补丁**从未发出**（`patches/upstream/m1-2026-10-14/README.md` 明写「未发送」）⇒ 无 review 可等。M3-1 **v2**（10-17）只有 **sashiko 机器人**两条，**人类维护者 0 回复**。
- **新增可交往的人**：**Joonhoe Kim**（Lenovo Legion Tab **Y700 Gen5 / SM8850 / bonded DSI**，v7.3-rc4）——Q28 与 Q24 都直接相关的同类硬件持有者，见 §3.4。

---
## §2 Q24 相关（熄屏掉电 / cambistmclkcc + camcc / Taniya Das 线程）

### 2.1 我们自己的线程（现状：**无新回信**）

| 日期 | 发件人 | 主题 | Message-ID | In-Reply-To | 要点 | 需我们回？ |
|---|---|---|---|---|---|---|
| 10-12 16:21 / 16:39 | 我 | `[Regression v3] SM8750: cambistmclkcc + camcc together hard-reset the SoC on display blank` | `<179179331695.677917.11557670447411700010@mail.ustc.edu.cn>`（列表版）/ `<179179434083.729561.17404250333011539770@…>`（直投 Taniya 版，因 `quic_tdas@quicinc.com` 退信重投） | — | RFC v3 全文（4 个问题：bare controller 是否安全 / CX 域 tie / RPMh 末票 / 顺序约束） | — |
| 10-13 08:13 | 我 | `Re: [Regression v3] …`（补充两点上游证据） | `<179185039667.309517.8503800087166757122@mail.ustc.edu.cn>` | `<179179331695…>` | ① Kaanapali camera DT overlay v21 14/14 用 `cambistmclkcc` 作 MCLK provider ⇒ 上游确有 consumer；② v7.4 clock pull 的 `sm8750-gcc: Add CX power domain` / `dispcc-sm8750: use common probe handling` 与我们失败点同区域；承诺「rebase 后重跑配对 case 并回报」 | — |
| **10-13 16:03 IST** | **Taniya Das**（Qualcomm，clk/dt 维护者） | `Re: [Regression v3] …` | **`<869f6981-38d3-48cc-824e-98b5f662bd01@oss.qualcomm.com>`** | `<179185039667…>` | **★ 明确请求数据**：`Could you please share the complete dmesg/console logs` + ① `cat /sys/kernel/debug/pm_genpd/pm_genpd_summary` ② `cat /sys/kernel/debug/clk/clk_summary`。**没有回答我们 4 个问题中的任何一个** | **★ 是（T5 欠着）** |
| 10-12 | `postmaster@qualcomm.com`（Junk） | `Undeliverable: [Regression v3] …` | `<25cf402b-0d34-4157-be57-d23953cf32be@nasanex01a.na.qualcomm.com>` | `<179179331695…>` | 旧地址 `quic_tdas@quicinc.com` 邮箱满；已改 `taniya.das@oss.qualcomm.com` 且她本人已回 ⇒ **无需处置**（与 10-17 分诊一致） | 否 |

**核实方式（双通道一致）**：
- 邮箱：30 天内 `From: taniya`/`Cc: taniya` 的**全部**邮件已逐条列检（`/tmp` 脚本按 `frm+cc` 过滤）——她 10-13 之后只在**别的**线程发言（`GP M/N clock controller`、`gcc-qcs615`、`av1ecc-glymur`、`RFC clk-dvfs`），**对我们的 Q24 线程零后续**（无回执、无催问、无 "any update?"）。
- lore：`s:/cambistmclkcc/` 搜索结果 = **只有 3 件**（我方 v3、我方 10-13 补充、Taniya 10-13 回复），**归档至今未增**。

⇒ **T5 状态：仍未完成（欠 6 天）**。判据按 `TASKS/README.md` §4 T5 行的验收口径：回信 + 三件套，「**不得**拿 2026-10-17 的 Q28 坏发快照顶替」。

### 2.2 上游同期新工作（与 Q24 机制**同源**，必须读；都不需要我们回）

| 日期 | 发件人 | 主题 / Message-ID | 与 Q24 的关系 |
|---|---|---|---|
| 10-13 15:48 | **Abel Vesa** | `[PATCH 0/4] pmdomain: Preserve boot performance constraints until sync_state`<br>`<20261013-genpd-boot-performance-floor-v1-0-a765dc83e6d7@oss.qualcomm.com>`<br>（1/4 `<…-v1-1-…>`、3/4 rpmhpd `<…-v1-3-…>`） | **★★ 直接对应我们 N1b 的机制**：p3 明写 *"RPMh power domains are registered as powered off without knowing their initial hardware state. Until the provider's `sync_state()` runs, `rpmhpd_aggregate_corner()` replaces requests with the highest supported corner"* → 这正是 Q24 `reports/q24-n1b-boottime-pairing-20261015.md` 里「provider 在两 CC 绑定前未求值 ⇒ 夹到最高档 vs 按真实票投票」的**上游正式表述**；且 p3 顺手改了 `to_active_sleep()`：`active_only && state_synced` 才把 sleep 票压 0（**我们的 `mxc.lvl` 末票观察区**）。状态：**0 回复**（我方邮箱 30 天内无后续）；lore 线程亦无 review |
| 10-14 14:19 | **Konrad Dybcio** | `[RFC PATCH 00/16] Centralize the ownership of power rail votes for Qualcomm clocks`<br>`<20261014-topic-qc_clk_dvfs-v1-0-3041b788e9f7@oss.qualcomm.com>` | 把「频率→电压角」映射收进 clk 驱动；含 **11/16 `clk: qcom: gdsc: Make GDSC parenting optional`**（`<…-v1-11-…>`）与 **16/16 `rpmhpd: Stop forwarding MMCX pstate to CX`**（`<…-v1-16-…>`，DNM）。**16/16 原文**：「MMCX needs CX to be on, but it does not need CX's performance state to follow its own… raising MMCX can also raise CX when no CX consumer needs the higher level」——**与我们 RFC v3 问题 2（CX 域 tie / 末票 cx/mmcx）同区域**。讨论要点：Dmitry 质疑「PLL 是否同域」、「consumer 应关心全部 supplies」、建议用 DT 里 PLL 子节点 + OPP；Konrad 反驳「DT 会变成一半 clock data」；**Taniya 只回了一句**（`<187f4cc2-05b3-4c8f-aad8-0d803f2f5b21@oss.qualcomm.com>`，10-15 16:27）：「This seems to be similar proposal which was there earlier + 2018 codeaurora 链接」 |
| 10-12 17:00 / 10-13 14:45 | Bjorn Andersson | `[GIT PULL] Qualcomm clock updates for v7.4` / `(second attempt)`<br>`<20261013194514.325658-1-andersson@kernel.org>` | 我们 RFC v3 引用的「v7.4 clock pull」**已正式进 v7.4**：含 `Model GCC CX power-domain dependencies and runtime PM`、`Move always-on clock and GCC initialization into common Qualcomm probe handling across 47 … drivers`。⇒ **Q24 的 rebase 目标已可用** |
| 10-14 | Konrad / Abel / Jagadeesh / Loic | `clk: qcom: gcc-eliza: Use retention for PCIe power domains`（`<273f7f8c-e24d-4322-a418-4fd5ed84b0bd@oss.qualcomm.com>` 等） | **方法学参考**：Jagadeesh 指出 `PWRSTS_RET_ON` 会让 GDSC「首次使能后永不合」；这类「GDSC 卡在 off」现象与 Q28 方案 C 的 `HW_CTRL_SKIP_DIS` 同一族语义（参见 §3.5） |
| 10-15 | Bryan O'Donoghue | `Re: [PATCH v21 14/14] arm64: dts: qcom: kaanapali-mtp-camera-s5kjn5: Add DT overlay`<br>`<9f75b5d1-c8f9-4e74-a857-ca2a1fb096d9@kernel.org>` | 我们 RFC v3 的**唯一上游 consumer 证据源**（v21 14/14 相机 overlay）正在被 review 且已得 `Reviewed-by` ⇒ 该论据仍然成立、且更硬 |
| 10-15 | Ekansh Gupta / Konrad | `[PATCH v1 4/4] arm64: dts: qcom: sm8750: Make the ADSP remote heap no-map`（`<…sm8750…>`，10-15） | 非 Q24，但 **sm8750 的 DT 在动**：一旦进树，我们的板 DTS 需跟随（ADSP fastrpc/SSC 邻域，`PITFALLS #186`） |

**对 Q24 口径的影响（不改结论、只补强）**：`TASKS/README` §5 Q24 行「sync_state 时机构型无判别力（A/B 同活）」是**本台架上的经验否定**；
Abel 的 4 件与 Konrad 的 16/16 说明**上游自己认为这个「boot 期夹到最高档」是真问题且正在改**。
⇒ 正确的表述是：**机制真实存在于上游代码，但在我们台架上单独不构成致死条件**（与 `q24-n2prime-both-arms-survive-20261015.md` 的 12/12 存活一致），
**不得**把它写成「已被上游否证」。

---
## §3 Q28 相关（DSI 面板 init 间歇失败 / dsi_7nm_phy / dispcc DYN pclk / 上游 DSI 线）

### 3.1 我们自己的 Q28 报告：**v2 至今 0 回复**

| 日期 | 主题 | Message-ID | 回复情况 |
|---|---|---|---|
| 10-13 07:53 | `[REPORT] SM8750 bonded dual-DSI + NT36536: first DCS command-DMA timeout on cold boot (DMA engine stays latched; DSI-side reset does not clear it)` | `<179184923104.248043.14168731037113716140@mail.ustc.edu.cn>` | **2 封**（均 Pengyu Luo，见 §3.2） |
| 10-15 20:21 | `[REPORT v2] SM8750 bonded dual-DSI + NT36536: the command-DMA-timeout signature is not the invariant; dark panel is not recoverable in software` | `<179206690897.1177097.7309368787214649515@mail.ustc.edu.cn>` | **★ 0 回复**（30 天邮箱全扫 + lore 线程视图双向确认，至今 4 天） |

lore 复核：`s:/bonded dual-DSI/` 命中 4 件 = 我方 v1、Pengyu ×2、我方 v2；**v2 之后无新增**。

### 3.2 唯一的 Q28 人类回信（已归档，**不需要再回**）

| 日期 | 发件人 | Message-ID | 要点（≤3 行） | 需回？ |
|---|---|---|---|---|
| 10-13 12:34 | **Pengyu Luo** `<mitltlatltl@gmail.com>` | `<CAH2e8h6_pACX_j8YBDhhSZzbfs45waF-Y6KJo82_2c6BT0suEg@mail.gmail.com>` | 「panel 驱动上游支持，**DPU 可能不支持**」；上游双 DSI/双 DSC 大体齐，但还缺件，例：**10-bit CPHY plane 需要 hack `dsi clk source select`**；集成费时、且「Ver+0.1 就可能因 DPU 回归失效」 | 否（他会话式收尾，无请求） |
| 10-13 12:38 | 同上 | `<CAH2e8h7H5-DzTj1zwejYQyNNtupurgzYq4t6gKPZoZw=7EQvrA@mail.gmail.com>` | 自我更正：给出正确线程链接 + 两张 bring-up 快照（`postimg.cc/xJr11DK5`、`postimg.cc/0zz30h8P`）；明说「**I cannot help with this for now**，已很久没跟这条线，可看 LKML 上 10bpc/10bpp DPU 讨论」 | 否（明确的「帮不上」收尾） |

⚠ 口径提醒：`TASKS/README` §5 Q28 已裁定「`dsi clk source select` = PHY `DSICLK_SEL` + dispcc pclk src，**本树已 = 原厂**（`SEL=0`、`pclk_div=2`），Pengyu 指路**已反转**」⇒ 这条**不要再当行动项**。

### 3.3 M1 显示修复（`PLL_SYSTEM_MUXES`）：**从未发出，因此不存在 review**

| 项 | 值 |
|---|---|
| 补丁 | `patches/upstream/m1-2026-10-14/0001-drm-msm-dsi-phy-program-PLL_SYSTEM_MUXES-on-the-firs.patch` |
| README 原文 | 「## 0001 —— 唯一可上游补丁（**未发送**）」 |
| 邮箱核对 | 30 天内 Sent Items **46 封**逐条检视：**无** 该补丁、**无** 任何 `PLL_SYSTEM_MUXES` / `dsi_7nm_phy` 主题邮件 ⇒ 与 README 一致 |
| 门状态 | checkpatch `--strict` 0E/1W/0C（唯一 W = partial clone 缺 `44784327815b`，已知良性）、pristine `git am` rc=0、`dsi_phy_7nm.o` rc=0、全量 `Image.gz dtbs` rc=0/0/0 |
| 投递冻结 | `TASKS/README` §7：「⏸ 投递冻结（用户 2026-10-13 决定）… 待项目收盘统一投递；唯一已发出的例外 = M3-1」 |

⇒ **「M1 补丁串有没有人回复 review」= 不成立的问题**：没有发出，自然没有回复。**需要用户决定是否解除冻结**（见 §5 第 4 条）。

### 3.4 ★ 新发现：Joonhoe Kim 的 DSI AHB 时钟线（Q28 与 Q24 都相关）

**线程**：`drm/msm/dsi: fix AHB clock staying enabled across suspend`（Arpit Saini v1，`<20261006-dsi-ahb-clk-suspend-fix-v1-1-67da848e1b0a@oss.qualcomm.com>`）

| 日期 | 发件人 | Message-ID | 要点 |
|---|---|---|---|
| 10-06 | **Arpit Saini**（Qualcomm） | `…-v1-1-67da848e1b0a@oss.qualcomm.com` | `pm_clk_suspend()/resume()` 只 `clk_disable()/clk_enable()`，从不 `clk_unprepare()` ⇒ `prepare_count` 永不归零，AHB 时钟在 s2idle 期间仍显示 enabled；修法 = 把 `clk_prepare()/unprepare()` 移到 `suspend_late/resume_early`（避开 PHY 作 clock provider 时的 `prepare_lock` 死锁），`DPM_FLAG_NO_DIRECT_COMPLETE` |
| 10-14 11:38 | Arpit Saini | `<0a901acc-fa5c-40f5-a468-5280cb25a71f@oss.qualcomm.com>` | 与 Alexey Minnekhanov 往返；重申 `clk_prepare` 不能在 PHY runtime 回调里 |
| **10-16 21:50** | **Joonhoe Kim** `<26rote@gmail.com>` | **`<20261016125036.1069-1-26rote@gmail.com>`** | **★ 在 `Lenovo Legion Tab Y700 Gen 5`（SM8850，bonded DSI，v7.3-rc4）上实测**：s2idle + 显示开 **无差异**（两 PHY 已 runtime suspended、`disp_cc_mdss_ahb_clk` enable_count=0、CX collapse 相同）；**差异在「显示关、系统醒」**：probe 期 prepare ⇒ **dispcc 保持 runtime active、MMCX 保持 on**；改成 runtime 回调里 prepare ⇒ 两者都能关。另外：「**读 clk_summary 会 runtime-resume 时钟控制器**，所以它显示的状态可能不同」；他的变体做了 **30 次 DPMS off/on + 循环读 clk_summary** 未死 |
| 10-17 23:46 | Arpit Saini | `<54ae7a34-2ec9-4051-ba16-136a0228609c@oss.qualcomm.com>` | 承认 `enable=0 prepare=1` 才是故障；**「CCF prepare_lock 死锁是理论担忧，我没有复现」** |

**为什么这条对我们价值最高（三条独立接口）**：
1. **判据陷阱**：他明确说「**读 `clk_summary` 会 runtime-resume clock controller**，读到的状态可能不同」——这与我们 `T5` 要交的 `clk_summary` 快照、以及 Q24 只读实测（`pm_genpd`/`clk_summary`）**直接冲突**：**读的动作本身改变被测状态**。⇒ 交 Taniya 的数据必须**注明采集方式与副作用**（见 §5 第 1 条）。
2. **Q28 相邻**：`disp_cc_mdss_ahb_clk` 的 prepare 计数与 **dispcc 保持 runtime active / MMCX 保持 on** 直接相关——这正是我们 Q28「坏发 = 持续 down-state」与「dispcc/INTF 侧动态时钟」的邻居；也是 Q24 里 `dispcc` 参与电源转换的那条边。
3. **同类硬件**：他是 **Y700 Gen5 / SM8850 / bonded DSI**，比 Pengyu 更近；且**他已在本线程公开提出可用证据**（30 次 DPMS 循环）。

### 3.5 其它上游 DSI/display 动向（观察项，非行动项）

| 日期 | 主题 / 人 | 与我们关系 |
|---|---|---|
| 10-13 ~ 10-16 | `[PATCH v4/v5] drm/msm/dpu: rework layer mixer allocation and mode limits`（Dmitry / Mahadevan） | DPU 校验路径在动；我们 M2-P3（gamma LUT）与这类校验改动同文件，投递前需比对 |
| 10-14 ~ 10-15 | `[PATCH v2/v3] drm/msm/dpu: Add INT2 GDSC power domain support for Kaanapali`（Yongxing Mou，`<a09f71a4-31e7-439d-b053-66b279ea27c7@oss.qualcomm.com>` 等） | **GDSC 作为 DPU 的第二 power domain**：Dmitry 问「应继续 RPMHPD_MMCX 还是改 `DISP_CC_MDSS_CORE_INT2_GDSC`」。与我们 Q28 方案 C（`mdss_int2_gdsc` 只读判别）**同一个对象**，价值 = 上游确认「INT2 只供电部分 source pipe，CORE 仍挂 MDSS 父设备」 |
| 10-18 15:54 / 21:56 | `[PATCH] drm/msm/dpu: keep vblank enabled when entering self refresh`（Ramón Jesús Miranda）→ **作者已 withdraw** | 与我们「vblank 风暴」无关（是 self-refresh 路径），**不必跟** |
| 10-15 13:08 | `[PATCH 00/13] drm/msm/dcp: Add Qualcomm DCP display support`（Jayant Shekhar） | 新 display 后端（HFI），长期可能影响 msm 显示栈；观察 |
| 10-19 12:18 | `[PATCH v5 1-5/5] dt-bindings/drm:panel: Truly NT36850 + sdm845-hdk display card`（Dmitry） | **纯上游 DSI 面板 + display card overlay 范式**：可作为「我们能上游什么形态的板级显示」的参照（不是我们的面板） |
| 10-17 ~ 10-19 | `[PATCH v3 0/4] qcom: videocc: Fix sleep clock on Glymur/SM8750/Nord`（Shawn Guo，`<…videocc…>`） | **sm8750 videocc 时钟输入描述被修**（含我们板 DTS 用的节点）；进树后我们的板 DTS 需跟随 |

---
## §4 其它上游回复（我方其它补丁串）

### 4.1 M3-1 v2（dwc3 双连接器共享 HS 总线）— **人类维护者 0 回复，只有两个机器人**

| 日期 | 发件人 | 主题 / Message-ID | 要点 | 需回？ |
|---|---|---|---|---|
| 10-17 16:13 | 我（v2 投递） | `[PATCH v2 0/2]` `<20261017081320.220525-1-xiaqinghuan@mail.ustc.edu.cn>`、`1/2` `…-2-…`、`2/2` `…-3-…` | 撤 `usb-psy-name` 整枚、binding 不踩属性顺序、删 `mux_role`、sashiko 4 条全修、Konrad 拓扑质疑用板 DTS 片段正面回答 | — |
| **10-17 08:28Z** | sashiko-bot | `Re: [PATCH v2 1/2]` **`<sashiko-outbox-175391@kernel.org>`** | **5 条 Medium**：① 板级 HS GPIO mux 被建模进 controller ② `port@2` 把第二连接器建模成 controller bus ③ `usb-role-switch` 放在 graph endpoint ④ `port-select-gpios` 条件遗漏 required ports ⑤ schema 允许两 port 同 `mux-state` | **建议处理**（都是 binding 语义，主机侧可改） |
| **10-17 08:36Z** | sashiko-bot | `Re: [PATCH v2 2/2]` **`<sashiko-outbox-175396@kernel.org>`** | **7 条**（1 Critical / 3 High / 3 Medium）：**Critical** = `dwc3_role_mux_init()` 错误路径未 `cancel` `drd_work`；High = ① `dwc3_mux_role_set()` 里未加锁调 `dwc3_set_mode()` 的竞争 ② **in-place role swap 覆盖 `port->stamp` ⇒ 会把数据路径从在用端口抢走**（并指出 `time_before` MAX_LONG 回绕）③ role switch 注册在 endpoint fwnode 上破坏 lookup；Medium = fwnode 泄漏 / `error`+`desired_role` 从不被读 / 缺 `dwc3_pre_set_role()` | **建议处理**（至少 Critical + 两条 High） |
| 10-14 13:04 | Konrad Dybcio | `Re: [PATCH 0/3]` `<9fcbc293-2b5e-4b52-9854-a9afc39dc946@oss.qualcomm.com>` | v1 的拓扑质疑：「This is an incredibly strange setup. Are you sure it's actually how it's wired up? **Are there any hubs or other devices connected inline?**」 | **v2 已正面回答（板 DTS 片段）⇒ 待确认**；Konrad 尚无后续 |
| 10-14 13:12 / 13:13 | Krzysztof Kozlowski | `<20261014-brilliant-sympathetic-marmoset-ed5fce@quoll>` / `<20261014-mutant-bustard-of-dew-637afe@quoll>` | v1 的 binding 否决（`usb-psy-name` 全树无使用者 / 用 phandle 而非名字 / endpoint 里放 `usb-role-switch`） | **v2 已撤该枚并重写 ⇒ 已闭环**（等他自己确认） |
| 10-15 04:19 | kernel test robot（Junk） | `<202610150418.XE8EkA7P-lkp@intel.com>` | v1 的 `core.c:171 variable 'mux_role' set but not used [-Wunused-but-set-variable]` | **v2 已删该变量 ⇒ 已闭环** |

**统计**：v2 投递后 **50 h** 内**零人类回复**（Greg/Thinh/Konrad/Krzysztof 都没有）；仅 2 条 sashiko 机器人（共 12 条 finding）。

### 4.2 M2-A2（`qcom_battmgr: do not report power_now on SM8750`）— **有实质进展，且「回答已到、问题在我们这边」**

| 日期 | 发件人 | Message-ID | 要点 | 需回？ |
|---|---|---|---|---|
| 10-13 08:21 | 我 | `<20261013002124.332111-1-xiaqinghuan@mail.ustc.edu.cn>` | SM8750 QBG 用 max-load 更新器填 `BATT_POWER_NOW`（getter 索引 `context+0x6a8+4*property`）⇒ 上报 89 W / >100 W 荒谬值；DT 已有 `qcom,sm8750-pmic-glink` 但驱动无条目、回落 SM8350 ⇒ 加 SM8750 变体 + 无 POWER_NOW 描述符 | — |
| 10-15 15:27 | **Konrad Dybcio** | `<d3a67d47-9072-4094-85a0-7e1b75e08314@oss.qualcomm.com>` | **提问（不是对我们的补丁）**：「+Fenglin would we know if this is an issue on **all SM8750 devices**, or perhaps something **OEM-specific**?」 | ★ **是**（我们有两台同型单元 + 实测数据，是最该回答的人） |
| 10-15 15:27 | Konrad | `<b957c95e-89b9-4e62-9e88-0c5754771511@oss.qualcomm.com>` | 自嘲「(helps to actually Cc someone when you say you do..)」+ 补 Cc Fenglin | 否 |
| **10-19 10:03** | **Fenglin Wu**（Qualcomm，QBG 侧） | **`<c030eac4-1574-40d3-938d-ce11a505271a@oss.qualcomm.com>`** | **★ 回答**：「**SM8750 device supports 'power_on' property in the battery management firmware by default. Different OEMs might customized that without supporting it.**」⇒ 即「**默认有，OEM 可能定制掉**」 | ★ **是**：这句话**没有判定我们这块板属于哪种**，需要我们用实测数据补上（否则补丁按 OEM 特例处理） |

**判断**：Fenglin 的答复把结论推回给我们 —— 若我们只报「本机不报 `power_now`」，维护者会倾向认为**OEM 定制**、不该进 SoC 级 quirk；
若我们能给出 **stock Android 侧同一台机器上 `power_now`/`BATT_POWER_NOW` 原始值同样荒谬**的取证（或 QBG 固件版本），才算「SM8750 固件行为」。
我们**已有**的素材：`reports/mail-triage-20261017.md` 提到的 C0 Android 取证主体（`TASKS/README` §2 C0 行）；QBG 固件版本需设备侧读。

### 4.3 libcamera `ipa: libipa` 两枚 — **两封都要改**

| 日期 | 发件人 | 主题 / Message-ID | 要点 | 需回？ |
|---|---|---|---|---|
| 10-17 23:33 / 23:38 | 我（**5 分钟内发了两批**：`<20261017153344.436818-1..3-…>` 与 `<20261017153829.442320-1..3-…>`；**全部回复都指向 23:38 那批**，23:33 批次零回复） | `[PATCH 1/2] ipa: libipa: add camera sensor helpers for GC08A8 and S5KJNS` / `[PATCH 2/2] ipa: simple: agc: make the exposure target tunable` | GC08A8（前摄，1/1024 步进、pedestal 64@10bit）、S5KJNS（后摄，1/32 步进）；AGC `exposureTarget` 可调 | — |
| **10-17 16:58** | **Kieran Bingham**（libcamera 维护者） | **`<179225268473.513434.6954062940176085837@ping.linuxembedded.co.uk>`** | ① `git grep` 内核里**找不到这两个 sensor**，lore 搜 `gc08a8` / `s5kjns` **均无命中** ⇒ 「Drivers for the sensors **must be on their way upstream Linux** for support to be added to libcamera」② **一 sensor 一 patch** ③ 在 `---` 之后**给公开 datasheet 或 brief 链接**便于核验 | ★ **是（硬门：sensor 驱动必须先上游化）** |
| **10-19 13:24** | **Barnabás Pőcze** | **`<75e177a5-dd27-4122-9edd-7ac03528dab0@ideasonboard.com>`** | 「**Please base changes on the master branch.** This part has been considerably changed since the latest release, and thus the diff below is no longer applicable.」 | ★ **是（rebase 到 master 重出）** |

⇒ **libcamera 这条线的真实前置条件**：GC08A8/S5KJNS 的**内核驱动上游化**（我们目前没有）；否则 IPA helper 无法被接收。这与 M4-camss 无关（那是 Qualcomm CAMSS 侧），是**独立的小件**、可作为 G1 相机线的副产品。

### 4.4 其它与 Q24/Q28 无直接关系、但被扫到的我方线程（一句话结论）

| 线程 | 状态 |
|---|---|
| `[PATCH] drm/msm/dpu: add the missing GC block to the SM8750 DSPP catalog` | 我 10-13 已发**撤稿回复**（与 msm 树 `3389406e6a03` 重复）⇒ **闭环**；sashiko 的 OOB 提示转成 P3 |
| `[PATCH] drm/msm/dpu: reject undersized gamma LUT blobs`（P3） | **0 回复**（14 天）；无 review |
| `[PATCH 0/2] USTC SMTP threading test` / `keyring channel test` / 各 `subscribe`/`confirm` | 自测与订阅，已归档，**无需动作** |

---
## §5 下一步建议（排序 + 依赖 + 证据 Message-ID）

依赖标注：**〔主机〕** = 只需主机侧（不受设备可用性阻塞）；**〔设备〕** = 需要在机采集/上机；**〔用户决定〕** = 需用户裁定口径/授权。

### 第 1 位 · 回 Taniya Das（T5 闭环）— **〔设备〕+〔用户决定：是否接受「采集副作用」免责声明〕**

**做了什么**：按她 10-13 的原话交三件套，**按 Q24 语境**（不得用 10-17 Q28 坏发快照顶替）。

**必须包含的采集纪律（本次分诊新发现，直接来自 Joonhoe Kim 10-16 的实测）**：
> 「**Reading `clk_summary` runtime-resumes the clock controllers, so it can show a different state.**」
> 证据：`<20261016125036.1069-1-26rote@gmail.com>`

⇒ 附件必须写明：`clk_summary` / `pm_genpd_summary` 的**读取动作本身会 resume 时钟控制器**，因此「读取时的状态 ≠ 故障瞬间状态」。
**推荐采集顺序（把副作用写进报告而不是隐藏它）**：
1. 冷起 / 配对加载 → `dmesg`（完整，含 `t=0` 起）；
2. `pm_genpd_summary`（先读，开销小）；
3. `clk_summary`（**最后读**，读完立即记录 `boot_id` + uptime）；
4. 再做**一次真实熄屏**（`ScreenSaver.SetActive(true)`，`PITFALLS #294` 明确 `dpms` sysfs 只读）→ 若存活则再取一份 `dmesg` 尾部（熄屏前后差分）；
5. 若致死（`#209` 自动恢复），把**上一份**（熄屏前）快照作为「死前状态」交付，并注明死于第 4 步。

**证据 Message-ID（引用她原话）**：`<869f6981-38d3-48cc-824e-98b5f662bd01@oss.qualcomm.com>`（10-13 16:03 IST，To: 我 + linux-arm-msm + **Jagadeesh Kona**）。

**同时应回答她没答的问题（仍是 4 问）**：她的回信**只问不答**，所以我方回信应把 4 问**原样重贴一次并编号**，附「我们已做的排除」（suspend 能力级排除 `reports/q24-suspend-hypothesis-excluded-20261019.md`、7.3 线 41 发存活），
否则这条线程会变成单向数据索取。

**依赖**：设备在场 + 一次 POR（熄屏致死会自恢复，不需人手断电）。选一台当前 = 相机栈可加载且**显示 GOOD** 的台架（否则数据仍是 Q28 坏发语境）。

### 第 2 位 · 处理 M3-1 v2 的 sashiko 12 条 — **〔主机〕**

- **Critical（必做）**：`dwc3_role_mux_init()` 错误路径取消 `drd_work`。证据 `<sashiko-outbox-175396@kernel.org>`。
- **High（必做）**：① `port->stamp` 只在 `NONE→非NONE` 时更新（in-place role swap 不得丢总线，且 `time_before` 有 MAX_LONG 回绕）② 释放锁后再 `dwc3_set_mode()` 的 `desired_port`/`desired_dr_role` 竞争（或把二者合并到同一临界区）③ role switch 不要注册在 endpoint fwnode 上。
- **Medium**：fwnode 泄漏、`error`+`desired_role` 未被读（删或真的上报）、补 `dwc3_pre_set_role()`。
- **binding 5 条**（`<sashiko-outbox-175391@kernel.org>`）：是否改用标准 `mux` 子系统 / `gpio-mux`；`port@2` 的语义；`usb-role-switch` 位置；`port-select-gpios` 条件里 required ports；两 port 同 `mux-state` 的约束。
- ⚠ 这是**判断类**：sashiko 的 ① ② 与 Konrad 的「strange setup」是同一疑问的不同表述 ⇒ 若采纳「改用标准 mux 节点」，整个 binding 形状要重来，**必须先做一次正反判断再动手**（`AGENT-OPS` §3）。
- 产物落 `patches/upstream/m3-v3-2026-10-2x/`；**投递前须用户裁定是否解除投递冻结**（M3-1 是唯一既有例外，v3 属同系列延续）。

### 第 3 位 · M2-A2 battmgr：回答 Fenglin 的「all SM8750 or OEM-specific」 — **〔设备〕（取证）+〔用户决定〕**

- Fenglin 原话：`<c030eac4-1574-40d3-938d-ce11a505271a@oss.qualcomm.com>`（10-19 10:03）「SM8750 device supports 'power_on' property in the BMS firmware **by default**. Different OEMs might customized that **without supporting it**.」
- Konrad 的问题：`<d3a67d47-9072-4094-85a0-7e1b75e08314@oss.qualcomm.com>`（10-15）。
- **要交的证据（判定「固件默认行为」vs「Lenovo OEM 定制」）**：
  1. 本机 kernel 侧：`/sys/class/power_supply/*/` 全属性 dump + `qcom-battmgr` 收到的 QBG 属性表（`power_now` 值 + 同时刻 `current_now`×`voltage_now` 对照，证明荒谬）；
  2. **stock Android 侧同机对照**（`qcom,sm8750-pmic-glink` 在 stock DTB 里是否同一 compatible、QBG 固件版本字符串）——`TASKS/README` §2 C0 行已有主体取证，需补 QBG 版本一项；
  3. 若两台单元（U1/U2）都可测：**两台都复现** ⇒ 至少排除「单机个例」。
- 若证据只支持 OEM 特例 ⇒ 按 Konrad/Fenglin 的口径**撤补丁**，改记为下游板级 workaround（符合 `reports/upstream-policy-20261013.md` 的下游隔离清单）。

### 第 4 位 · 决定 M1 `PLL_SYSTEM_MUXES` 补丁是否解冻投递 — **〔用户决定〕（唯一阻塞项）**

- 现状：补丁全门绿（checkpatch 0E/1W/0C、pristine `git am` rc=0、编译 rc=0、全量构建 0/0），**但从未发出**；邮箱 46 封 Sent 逐条核对无此件。
- 它修的是一条**已被 revert 的上游回归**（`93c97bc8d85d` 被 `44784327815b` revert 后 `dsi_7nm_phy_enable()` 预置 `pll_enable_cnt=1` 使 `PLL_SYSTEM_MUXES=0xc0` 首次 bring-up 永不写入），**判据不依赖我们的板**（pristine 7.3-rc7 上任何 bonded DSI 板都会中）⇒ 这是**最符合上游化标准的一件**，且与 Q28 无关（Q28 是间歇失败，这是确定性缺失）。
- 建议：**解除冻结、投 linux-arm-msm + dri-devel + freedreno**，To: Dmitry Baryshkov / Abhinav Kumar / Jessica Zhang；Cc 记录 revert 的作者。理由：它不携带任何板级私有信息、纯上游回归修复。
- 若用户不解除冻结 ⇒ 至少在 §7 M6 的 L1 行把「已备料未发送」改成「**待用户解冻**」，避免下次分诊再误以为已投递。

### 第 5 位 · 主动联系 Joonhoe Kim（Q28 + Q24 双相关，**同类硬件**）— **〔主机〕（起草）**

- 他是 **Lenovo Legion Tab Y700 Gen5 / SM8850 / bonded DSI / v7.3-rc4**（`<20261016125036.1069-1-26rote@gmail.com>`），已公开：① 读 `clk_summary` 会 resume 时钟控制器；② 30 次 DPMS off/on + 循环读 `clk_summary` **未死**；③ 「显示关、系统醒」时 probe 期 prepare 会让 **dispcc runtime active + MMCX 常 on**。
- **对我们两条线都有直接价值**：
  - Q24：③ 提供了一个**可测的电源态差异**（dispcc/MMCX 常 on vs 关），正是「致死是否需要某个轨一直在 on」的候选条件；
  - Q28：`disp_cc_mdss_ahb_clk` 的 prepare 计数 = dispcc runtime PM 的判据，可作为「坏发态 = 持续 down-state」的第三条独立度量。
- **建议动作**：在 `drm/msm/dsi: fix AHB clock staying enabled across suspend` 线程内回一封**纯信息性**邮件（不问他要数据、只给我们的观测）：说明我们在 SM8750P（Y700 Gen4，TB322FC，bonded dual-DSI NT36536）上看到「显示关后 dispcc 仍活」与「坏发 boot 上 DPU `core_irq` 3 s 内冻结在 10」并存，问他的 v7.3-rc4 台架是否也观察到 dispcc 残留 runtime active。**⚠ 需用户批准**（涉及对外发言），且**不得**透露 G2/G3 或任何非公开信息。

### 第 6 位 · Q28 只做「零成本静态跟进」，不再投工时 — **〔主机〕**

- `[REPORT v2]`（`<179206690897.1177097.7309368787214649515@mail.ustc.edu.cn>`）**4 天 0 回复**，Dmitry/Neil/Abel/Pengyu 全在 Cc 里但无人接。按 `AGENT-OPS` §3「一次正反判断」+ §5 Q28「本地软件二分已达边界」：**不追发 v3**（除非有新机理）。
- 值得**顺手**做的两件（都是读上游、不出门）：
  1. 把 `INT2 GDSC` 线程（`<a09f71a4-31e7-439d-b053-66b279ea27c7@oss.qualcomm.com>`）里 Yongxing 的解释（INT2 只供电部分 source pipe、CORE 仍挂 MDSS 父设备、runtime PM 父子继承）与 Q28 方案 C 的 `mdss_int2_gdsc=off-0` 读数**对齐一次**，看是否给「坏发 = 域闩住」补一条上游语义支撑（预期：**否**，因为 §5 Q28 已实测 `pm_genpd` 零判别力；只做一次核对即收口）。
  2. `gpio` GDSC 那条方法学（Jagadeesh：`PWRSTS_RET_ON` ⇒ GDSC 永不合，`<273f7f8c-e24d-4322-a418-4fd5ed84b0bd@oss.qualcomm.com>`）与我们 `dispcc-sm8750.c` 的 `HW_CTRL_SKIP_DIS` delta 是**反向语义**（我们少了 hw-trigger 关闭）。记录进 `PITFALLS` 语义对照即可，**不建新臂**。

### 第 7 位 · libcamera 两枚（低优先，且被硬门挡住）— **〔用户决定〕是否投入**

- Kieran 的硬门：GC08A8 / S5KJNS **内核驱动必须在上游路上**（lore 现无任何命中）。我们**没有**这两个 sensor 的上游驱动 ⇒ **现在重发也没用**。
- Barnabás 的门：AGC 那枚必须 **rebase 到 libcamera master**（release 后大改）。
- 建议：**AGC 那枚（`[PATCH 2/2]`）独立重出**（rebase master，纯通用改进，无 sensor 依赖）；**sensor helper 那枚挂起**，等 GC08A8/S5KJNS 驱动上游化（那是 M4 之外的小件，需用户决定是否立项）。
- 证据：`<179225268473.513434.6954062940176085837@ping.linuxembedded.co.uk>`、`<75e177a5-dd27-4122-9edd-7ac03528dab0@ideasonboard.com>`。

### 5.1 待回复项清单（一页速查）

| # | 对方 | 事项 | 截止紧迫度 | 依赖 |
|---|---|---|---|---|
| **R1** | Taniya Das | 三件套数据（dmesg + genpd + clk_summary），Q24 语境 | **高（欠 6 天）** | 设备 + 用户确认采集声明 |
| R2 | Fenglin Wu / Konrad | 「all SM8750 or OEM-specific」 | 中 | 设备取证（含 stock Android QBG 版本） |
| R3 | sashiko（M3-1 v2） | 12 条 finding（1C/3H/3M + 5M binding） | 中 | 主机；需先做一次正反判断 |
| R4 | Konrad（M3-1 v2 cover） | 「strange setup」是否被板 DTS 片段说服 | 低（等他自己回） | 无 |
| R5 | Joonhoe Kim（DSI AHB 线） | 主动信息性接触（**需用户批准**） | 低 | 用户批准 |
| R6 | libcamera Kieran / Barnabás | sensor 驱动上游化前置 / AGC rebase master | 低 | 用户决定是否投入 |
| R7 | （我自己）M1 补丁 | 解冻投递 | 中 | **用户决定** |

**不需要回的**：Pengyu Luo（已收尾）、postmaster 退信、Krzysztof v1 否决（v2 已闭环）、lkp `mux_role`（v2 已删）、sashiko 对我方已撤稿 DPU GC 块（已闭环）。

---

## §6 本次分诊与前序档案的差异（避免重复劳动）

| 项 | `mail-triage-20261017.md` 的口径 | 本次（10-19）更新 |
|---|---|---|
| Q24 Taniya | 「★ 明确请求数据，建议回信」 | **仍欠；她 6 天零后续、无催促**；同期上游出现两件同源正式工作（Abel floor 4 件 / Konrad clk-dvfs 16 件）⇒ RFC v3 的 4 问有了**新的引用锚点** |
| Q28 v2 报告 | 「至今 0 回复」 | **仍 0 回复（第 4 天）**，lore 已确认归档且无人接 |
| M1 `PLL_SYSTEM_MUXES` | 档案未提及其投递状态 | **确认「从未发出」**（README + Sent 46 封逐条核对）⇒ 不存在「等 review」 |
| M3-1 | 「v2 已投、等 review」 | **50 h+ 零人类回复；但有 12 条 sashiko**，其中 1 Critical + 3 High 是**真缺陷级**（不是噪声） |
| M2-A2 battmgr | 「Konrad 已问『所有 SM8750 还是 OEM 特有』」 | **Fenglin 10-19 已答（默认有，OEM 可能定制掉）⇒ 球回到我们这边**，需要取证 |
| 新线索 | 无 | **Joonhoe Kim（Y700 Gen5 / SM8850 / bonded DSI）** 与 **「读 clk_summary 会 resume 时钟控制器」** 这条判据陷阱 |

---

## §7 未做 / 边界（诚实声明）

- **未发任何邮件**（含未发「收到，数据采集中」的回执）。R1 的 6 天延迟**没有**任何临时回复，是否要补一封「已收到、正在采集」由用户决定（不建议：一次完整交件优于两次半成品）。
- **未跑 `scripts/check-doctor.sh` / 未 git commit**：本任务为只读分诊，产物仅本文档；入库与钩子校验留给编排者收尾（`AGENT-OPS` §5 收尾五项由编排者执行）。
- **本文档目前是孤儿报告**（`AGENT-OPS` §3「报告必须被引用」）：按 `AGENT-OPS` §4 单写者规则，`TASKS/README.md` 由父 agent 专属，本 worker **不碰**。**编排者必须**把指针补进：① `TASKS/README.md` §4 T5 行（证据列加本文档）② `TASKS/README.md` §5 Q24 / Q28 行的「历史口径链」指针；否则本文随文件沉底。
- lore 侧只复核了 **Q24 / Q28 两条主线线程**；`sashiko` 对 M3-1 v2 的完整正文已抓取并摘要（`/tmp/mailfocus3/`），但**未**逐条评估「该怎么改」——那属于第 2 位的实施任务，不是分诊。
- `/tmp` 下的正文快照与辅助脚本（`kwmail.py`、`fetchbody.py`）**不入库**；本文档已内嵌全部关键 Message-ID 与要点，可独立使用。
