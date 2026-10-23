# 上游邮件分诊（2026-10-23）

> 角色：worker（只读，主机侧）。**未发任何邮件、未碰设备、未改 `.gitconfig`/凭据、未 commit**（见 §5）。
> 窗口：**2026-10-21 00:00Z → 2026-10-23 05:2x Z（= 10-23 13:2x CST）**。
> 前序权威口径：`reports/mail-triage-20261021.md`（本轮只做「差量 + 确认/推翻」，不重复论证）。
> 通道与工具：`.pi/skills/upstream-mail-ustc/SKILL.md`（凭据只在 GNOME keyring，本文不含口令）。

---

## §0 结论速览

- 窗口内我方**新投 1 件**（Q28 dispcc RFC，10-22 14:08Z）+ **3 类订阅动作**（10-21 14:09Z / 14:31Z 生效：订 linux-usb、订 linux-remoteproc、退 devicetree）。〔已证实：Sent Items uid 136–142 + INBOX 10453/10454/10459/10486/10487/10490〕
- **新外部来信（去重后）= 4 封**：Konrad 10-22（battmgr 反问）、Taniya Das 10-22（Q28 明确反对）、sashiko 10-22（Q28 4 条）、+1 封我方 RFC 的 DSN 退信（`mturquette@baylibre.com` 5.0.0）。〔已证实，§1/§2〕
- **需我方行动的条数 = 3**：① 回 Taniya Das（Q28 架构归属争议，**首次人类 maintainer 反对**）② 回 Konrad battmgr（他要下游源码/下游行为佐证）③ 处理 Q28 的 mturquette 退信（建议：不重发）。〔依据见 §2〕
- **窗口内流量**（`>= 2026-10-21 00:00Z`，按 mid 去重）：INBOX **1 775 原始 / 1 368 唯一**、Junk **82（全 libcamera-devel）**、Sent **8**。〔已证实〕
- **噪声基线**：`SINCE 20-Oct` 全量 INBOX 3 338 封 / Junk 143（100% libcamera-devel）/ Sent 9 ⇒ 日均 ≈ 1 160 封（上轮 1 090）。〔已证实：§3.4〕

---

## §1 我方在途邮件状态表

| 对象 | 发出时间 (CST) | Message-ID | lore 归档 | 回复 | 线程状态 |
|---|---|---|---|---|---|
| **A. Q28 dispcc RFC** | 10-22 22:08 | `<20261022140811.469417-1-xiaqinghuan@mail.ustc.edu.cn>` | `/linux-arm-msm/` ✅、`/linux-clk/` ✅、`/dri-devel/` ✅（均 2026-10-22T14:08:25Z） | **sashiko 4 条**（14:26Z）+ **Taniya Das 1 条**（17:23Z） | **活跃、有人类评审、我方未回** |
| **B. T5 Q24 数据集（Taniya）** | 10-20 11:02 | `<179249416915.570120.11194300523322683054@mail.ustc.edu.cn>` | 前轮已核 ✅ | **0 新回复**（窗口内该 mid 仅命中我方自己的投递副本） | 静默 3 天 |
| **C. battmgr / Q24 线** | 我方 10-21 21:49 | `<179259054168.209323.8102186130128474174@mail.ustc.edu.cn>`（IRT=`<5bf3636d-…>`） | 未单独核（见 §3.3） | **Konrad 10-22 10:16 +0200 反问** `<52fc4222-508d-4acf-b38a-7b4e5aeff3cb@oss.qualcomm.com>` | **我方已回过一次，现在轮到我们回第二轮** |
| **D. M3-1 v3（linux-usb / devicetree）** | 10-19 21:18 | `<20261019131848.344689-1/-2-xiaqinghuan@mail.ustc.edu.cn>` | 两个列表均归档 ✅（`/linux-usb/` 与 `/linux-devicetree/` 命中同一组 3 条：v3 0/2、1/2、sashiko） | **0 新回复**（Greg/lkp/sashiko 均无新件） | 等 `-rc1`，与上一轮一致 |

### 1.1 A（Q28）：**本轮最大增量 —— 首次拿到人类 maintainer 的技术反对意见**

**① Taniya Das，10-22 22:52 +0530 = 17:22Z**，`<22a87c51-4f8c-49c0-a13a-c11767f10e85@oss.qualcomm.com>`，To 我 + linux-arm-msm，Cc linux-clk/dri-devel/Bjorn/Konrad/Dmitry/Michael Turquette/Stephen Boyd。〔已证实：INBOX uid 11339 / 11343 / 11344（同 mid 三份 = 多路投递）〕

原话（全文只有这一段）：

> These resets if required should be taken care or triggered from the Display SW driver. It is not on to the clock driver to drive these resets. If these are done the complete dispcc would be reset and when the PLLs gets reconfigured there should be a flicker observed on the display.

⇒ **两点实质意见**：(a) **架构归属**：dispcc BCR 不该由 clk 驱动驱动，应由 display（drm/msm mdss）侧触发；(b) **可观测副作用**：整块 dispcc 复位后再配 PLL 会**闪屏**。

**② sashiko 10-22 14:26Z**，`<sashiko-outbox-181631@kernel.org>`，4 条（1 High / 3 Medium）：〔已证实：INBOX uid 11254/11256，正文全文已读〕

| 级别 | 内容 |
|---|---|
| **High** | 在 `disp_cc_sm8750_probe()` 里无条件复位三块 BCR：`msm_mdss_reset()` 本来就在 `msm_mdss_init()` 里做同样的 assert/deassert；且在 `qcom_cc_really_probe()` 初始化 `mdss_gdsc`/`mdss_int2_gdsc` **之前**、`critical_cbcrs`（SLEEP_CLK/XO_CLK/RSCC_AHB/RSCC_VSYNC）使能之前就拆掉显示块 ⇒ 若 bootloader framebuffer（simpledrm/efifb）在用、或 drm/msm 是模块/延迟 probe，会**撕掉正在扫描的显示并打断 DMA** |
| Medium | `lenovo,elden` 这个 compatible **不在 `arm/qcom.yaml` 已文档化的 board compatible 里** |
| Medium | 裸 `regmap_write(reg, 0x1/0x0)` 覆盖整寄存器，**不 mask、不 readback**（`qcom_reset_set_assert()` 是 `regmap_update_bits` + readback 刷 posted write） |
| Medium | 注释说「让块从 known-zero 开始」，但三个 BCR **并不复位 PLL**；`clk_lucid_evo_pll_configure()`/`clk_pongo_elu_pll_configure()` 见 `trion_pll_is_enabled()` 为真会**直接 return**（不重配）⇒ 注释与代码语义不符 |

⇒ **sashiko 的 High 与 Taniya 的意见同向**：都指向「不该在 clk probe 里复位、应该在 mdss/display 侧；且要先判断硬件是否活着」。这两条互相加强，不能再当机器人噪声。

### 1.2 C（battmgr / Q24）：我方已回过一轮，Konrad 追加三个问题；Q24 单变量线程 0 进展

我方 10-21 21:49 的回信（`<179259054168.…>`，IRT 正确指向 `<5bf3636d-…>`）已把「maximum-load updater」这个词撤回并分层写清「驱动不采样、只读固件留的槽位」。Konrad 10-22 10:16 +0200 回：〔已证实：INBOX uid 10977〕

> So it indeed seems like the OEM modifications are the culprit here. Do you have downstream kernel sources for this device? Are the properties remapped? Is power_now disabled there too? If not, can you read it on a downstream kernel and see if it also returns garbage?

⇒ 三个具体问题：**(i) 有没有这台设备的下游内核源码**（ii）**属性是否被重映射**（iii）**下游是否也禁用 power_now / 下游读出来是不是垃圾值**。这是**设备侧取证**（要跑 stock Android 内核），本 lane 不能碰设备 ⇒ 只能给「有/没有 + 上游证据」，或明确写「需设备侧一轮验证」。

**对任务 C 前半句（Q24 `rpmhpd_driver.sync_state` 单变量）**：〔已证实〕全窗口扫 `<101257b5-7e43-4cc1-ba17-1507dad27b52@oss.qualcomm.com>` 只命中 10-20 09:37 +0200 的 3 份同 mid 副本（多路投递），**无任何人跟进**；`TASKS/README` §4 T5 的「下一步 = vk64 台架跑单变量」**仍未执行**（本轮不碰设备）。

### 1.3 B / D：确认「无新回复」

- B：全窗口 3 490 封头中，`179249416915.570120` 只命中我方 3 份副本（INBOX×2 多路投递 + Sent），**无第三方引用**。〔已证实〕
- D：`/linux-usb/` 与 `/linux-devicetree/` 用 `s:"describe two connectors"` 复核，命中仍只有我方 v3 0/2 + 1/2 + sashiko 1 封（2026-10-19T13:30:01Z），**Greg KH / lkp / 新 sashiko 均无新件**。〔已证实，§3.2〕

### 1.4 E（其它需我方行动）：**无遗漏项**

全窗口把 `To + Cc` 含 `xiaqinghuan@mail.ustc.edu.cn` 的**非我方发出**邮件按 mid 去重后 = **18 封**，逐个归类：〔已证实〕

| 归类 | 封 | 需行动？ |
|---|---|---|
| Konrad battmgr（10-20 / 10-21 / 10-22） | 3 | ✅ 最新一封见 §2 A2（前两封已回过） |
| sashiko Q28 | 1 | ✅ 见 §2 A3 |
| Taniya Q28 | 1 | ✅ 见 §2 A1 |
| Joonhoe Kim（10-20，信息性） | 1 | ❌ 上轮已判「不回」 |
| DSN 退信 | 1 | △ 见 §2 A4 |
| 订阅系统回执（Confirm ×3 / Welcome ×2 / Goodbye ×1） | 6 | ❌ 均已生效 |
| 教务处通知（私有信、非上游） | 5 | ❌ 与项目无关 |

⇒ **没有「直接 Cc 给我们、但不属于以上任何一线程」的新东西**；也没有新出现的 `Reviewed-by`/`Acked-by`/`NACK`/`please fix` 字样邮件（除 Taniya 那封的反对语）。〔已证实〕

---

## §2 需我方行动清单

> 排序 = 「对方在等 + 有时间窗」优先。**本 lane 一封未发**，以下只是建议。

### A1 ★★★ 回 Taniya Das（Q28）—— 必须回，不回就是死局

- **对方诉求**：dispcc BCR 复位**不属于 clk 驱动**，应在 display SW 侧；且整块复位会**闪屏**。
- **事实核对（主机侧已做）**：〔已证实〕
  - `sm8750.dtsi:3296` 已有 `resets = <&dispcc DISP_CC_MDSS_CORE_BCR>` 挂在 **mdss 节点**上；
  - `msm_mdss.c:309-333` `msm_mdss_reset()` 已经在 `msm_mdss_init()` 里 `assert → msleep(20) → deassert`（**注释原话："Tests indicate that reset has to be held for some period of time, make it one frame in a typical system"**）。
  - ⇒ **Taniya 说的位置（display 侧）和代码（msm_mdss_reset）本来就已经存在**，我们的 0154 确实是在**重复**做一次、且提前到了 dispcc probe。
- **为什么当初仍需要 0154**〔推测，有 A/B 支撑〕：`msm_mdss_reset()` 只复位 `CORE_BCR` 一个，且在 `mdss` probe 时、**在 dispcc PLL 已经被 clock framework 配过之后**（依据：`sm8750.dtsi:3292-3296` 的 mdss 节点 `clocks`/`resets` 均指向 `&dispcc` ⇒ **dispcc 作为 provider 必须先 probe 完成**，mdss 才能 probe）。我们的 A/B 显示 **CORE_INT2 + RSCC 也要一起复位且需早于 PLL 配置**。
- **建议回复结构（只改代码位置，不改观测）**：
  1. 先接受她的架构判断：**承认 dispcc probe 不是正确位置**；
  2. 指出 `msm_mdss_reset()` 现有实现**只一个 BCR + 只 msleep(20)**，并追问：把它扩成三个 BCR 是否可接受（**这是最小改动的正解形态**）；
  3. 问「顺序」：mdss probe 在 dispcc 之后，能否保证复位早于 PLL 配置？若不能，需要在 mdss 里 `clk_set_rate` 之前插入；
  4. 闪屏问题：我们的场景是**冷起首次 bring-up**（面板尚未 init、`card0` 不存在），没有已有扫描输出 ⇒ 理论上不会闪；但**必须承认**若 simpledrm/efifb 在跑就会（与 sashiko High 同点）；
  5. 给数据：`without 5/9 STORM vs with 15/15 GOOD，Fisher 双侧 p=0.003`（拆分：only0154 5/5、exp 10/10、only0155 3/4 STORM ⇒ 复位才是对症项）。
- **最小改动**：把 hunk 从 `dispcc-sm8750.c` 搬到 `msm_mdss.c` 的 `msm_mdss_reset()`，BCR 表从 `dispcc` 的 reset map 取（或用 `reset_control_bulk`）。**预期只剩一件事说不通**：mdss 复位时机是否真的早于 PLL——需要 v4 实验验证（设备侧）。
- **⚠ 必须自己先说清的 caveat**〔已证实〕：0154 的 A/B **是在 `build/base-7.2` 的树上跑的，而该树故意不描述 `chosen/framebuffer`（simple-framebuffer）**（`build/base-7.2/.../sm8750-lenovo-elden.dts:1208-1216` 有注释：「MDSS 的 CORE_BCR reset 会把 ABL 交接的 framebuffer 从 simple-framebuffer 脚下抽掉」）；而本仓主干 `linux/.../sm8750-lenovo-elden.dts:524` **是有 `simple-framebuffer` 的**。⇒ **sashiko 的 High（simpledrm 被拆）在我们的 A/B 里根本没被覆盖**。回复时必须分开说：「实测树无 simple-framebuffer；若有，确实会闪一下 — 那正是我们要避免的，所以建议住 mdss/先判活态」。

### A2 ★★★ 回 Konrad Dybcio（battmgr）—— 他在等三个具体回答

他问：(i) 有没有下游内核源码 (ii) 属性是否被重映射 (iii) 下游是否也禁用 power_now / 读出来是不是垃圾。

- **主机侧可答的**〔已证实〕：`reference/upstream-armadaos-freedom/patches/0149-*.patch`（`battmgr SM8750 POWER_NOW`）证明**别的 elden 分支也碰到同一个 `POWER_NOW` 问题并自行修改**（README §4：「`0149`/`0150` battmgr SM8750 —— ✅ 已有，来源不同」）。这可以作为「不只我们一台/不只我们一家看到」的独立证据。
- **必须诚实说的**：没有原厂下游内核源码（只有 prebuilt），**属性重映射无法静态证明**。
- **建议动作**：回一封短邮件，① 给 0149 的外部对照；② 明确「下游源码不可得，prebuilt 无法静态核」；③ 提出**可用代替判据**：由内核侧打印 `BATT_POWER_NOW` 原始 32-bit 值与 `current_now × voltage_now` 对照（**只需现成 debugfs/自定义一行 printk**，旧 0 回复版报告里已有此量级对照）；④ 问是否接受「不在 SM8750 上注册 `POWER_NOW`」为保守方案。
- **不做的**：不承诺「去 stock Android 跑一遍」（需设备且需时，不属于本 lane）。

### A3 ★★ Q28 的 sashiko（3 个 Medium + 1 个 High）—— 与 A1 同封一起回

- **High 与 Taniya 同向**（不应在 clk probe 拆显示 + 先判硬件是否活着）⇒ 随 A1 的搬迁自然消掉，**不必单独辩护**。
- **Medium①** `lenovo,elden` 未文档化：**可反驳但需分场合说**。〔已证实〕本仓 `build/base-7.2/Documentation/devicetree/bindings/arm/qcom.yaml:1125` **已经列了 `lenovo,elden`**，但它来自本仓 `378459aff` 本地提交（`git log -S"lenovo,elden"` 只命中这 1 个提交）⇒ **相对主线确实未文档化，相对本仓已文档化**。回复口径：「board binding 在随板 DTS 串里一并提，当前主线未含」；**若迁到 `msm_mdss.c` 且改成通用行为，此条自动作废**。
- **Medium②** 裸 `regmap_write` 覆盖整寄存器：**真缺陷**，改用 `reset_control_*` 或 `regmap_update_bits` + readback（照 `reset.c:qcom_reset_set_assert` 的形状）。
- **Medium③** BCR 不复位 PLL（我们 commit message 也没这么说，但注释写「known-zero state」易误读）：**只改注释用词**。

### A4 ★ 退信处理：`mturquette@baylibre.com` 5.0.0

`postmaster@mail.ustc.edu.cn` 10-23 03:16 CST 退信，`Final-Recipient: mturquette@baylibre.com`，`Status: 5.0.0`，`Diagnostic-Code: SMTP; rcpt handle timeout,last handle info: domain baylibre.com MX query return retry`。〔已证实：INBOX 11387 + message/delivery-status 段〕

- **含义**：USTC 侧 DNS 解析 `baylibre.com` MX **超时**（不是对方拒收）⇒ Michael Turquette **可能根本没收到** Q28。
- **并非全丢**：`linux-clk` / `linux-arm-msm` / `dri-devel` 均已归档 ⇒ 名单上能看到。
- **建议**：**不重发整封**（会在列表造成重复）；若真要补，只发一封**非列表**的私人 copies 给 Stephen Boyd（`sboyd@kernel.org`，同维护者）代为转达。**最小改动 = 什么都不做**。

### 不做的事

- **不催 Taniya 回 Q24/T5**（她 10-22 在 Q28 上主动回信 = 人活着、但选择不回数据集邮件；`AGENT-OPS` 一次正反判断 ⇒ 等）。
- **不因 Q28 有回复就给 M3-1 v4**（两个不同线程，M3-1 仍等 `-rc1`）。
- **不回 Joonhoe**（上一轮结论仍成立，窗口内他无新件）。

---

## §3 lore 复核记录

### 3.1 邮箱全量扫描（先做，避免漏收）

自建脚本 `/tmp/scan3.py`（复用 `read-mail-ustc.py` 的凭据/IMAP 函数，**不改仓库文件**）：

```bash
python3 /tmp/scan3.py 20-Oct-2026 /tmp/scan3.jsonl
# INBOX 3338 / Junk 143 / Sent Items 9 = 3490 头
```

- **坑（本轮新踩）**：`email.header.decode_header()` 对某些列表信返回 `unknown-8bit`，`read-mail-ustc.py:36` 的 `p.decode(e or "utf-8")` 会 **`LookupError` 直接崩**（首跑 370 封就死）。绕过 = 在扫描脚本里包 try/except 后回退 utf-8。**建议后续把这一行修一下**（本次未改仓库/工具）。
- 必须用 `BODY.PEEK[HEADER]` 整块（上一轮已记：`HEADER.FIELDS` 在本服务器会让 Date/From/Subject 解成空串）。
- **同 mid 多份**：vger 多路投递（To 我 + Cc 列表）会把同一封拆成 2–3 份进 INBOX ⇒ 统计前必须按 mid 去重。

### 3.2 逐个对象复核

| # | 命令 | 命中 | 结论 |
|---|---|---|---|
| 1 | `lore-query.py "https://lore.kernel.org/linux-arm-msm/?q=s%3A%22reset+the+MDSS+blocks%22"` | 2026-10-22T14:08:25Z 我方 RFC + **17:23:01Z Taniya** | **Q28 已归档**；arm-msm 只 2 条（sashiko 未进 arm-msm，只进 clk/dri）〔已证实〕 |
| 2 | 同上 `/linux-clk/` | 14:08:25Z 我方 + 14:26:24Z sashiko + 17:23:01Z Taniya | **3/3 完整**〔已证实〕 |
| 3 | 同上 `/dri-devel/` | 14:26:36Z sashiko + 17:23:23Z Taniya（**无我方原帖**） | Q28 未直接投 dri-devel，是 Cc 分发〔已证实〕 |
| 4 | `lore-query.py "https://lore.kernel.org/linux-usb/?q=s%3A%22describe+two+connectors%22"` | 2026-10-19T13:18:54Z 我方 v3 0/2 + 1/2，13:30:01Z sashiko | **M3-1 v3 无任何新回复**〔已证实〕 |
| 5 | 同上 `/linux-devicetree/` | 同上 3 条 | 同上〔已证实〕 |
| 6 | `lore-query.py "https://lore.kernel.org/linux-arm-msm/?q=s%3A%22PLL_SYSTEM_MUXES%22"` | 仅 1 条 2026-10-19T13:01:05Z（我方 M1） | **M1 仍 0 回复（第 4 天）**〔已证实〕 |
| 7 | `lore-query.py "https://lore.kernel.org/linux-pm/?q=s%3A%22do+not+report+power_now%22"` | 7 条完整：10-13 我方 → 10-15 ×2 → 10-19 c030eac4 → 10-21 5bf3636d → 10-21 我方 → **10-22T08:16:49Z Konrad** | **battmgr 线程完整归档，Konrad 10-22 那封 = 最新**〔已证实〕 |
| 8 | 同上 `/linux-arm-msm/` | 完全同 7 条（同 mid 同时间） | 双列表同步、无漏〔已证实〕 |

### 3.3 邮箱侧证据（逐条）

- **Taniya**：`INBOX uid 11339 / 11343 / 11344`，同 mid `<22a87c51-…@oss.qualcomm.com>`，`Thu, 22 Oct 2026 22:52:53 +0530`。〔已证实〕
- **sashiko**：`INBOX uid 11254 / 11256`，`<sashiko-outbox-181631@kernel.org>`，`2026-10-22T14:26:23Z`。〔已证实〕
- **Konrad battmgr**：`INBOX uid 10977 / 10979 / 10980`，`<52fc4222-…>`，`Thu, 22 Oct 2026 10:16:44 +0200`。〔已证实〕
- **DSN**：`INBOX uid 11387`，`Fri, 23 Oct 2026 03:16:52 +0800`，内含 `message/delivery-status` 段（quote 完毕，§2 A4）。〔已证实〕
- **Sent Items 逐条**（9 封，含作业无关）：134=T5(10-20)、**135=回 Konrad battmgr(10-21 21:49)**、136/137=`subscribe`、138=`unsubscribe`、139/140/141=`confirm`（各 3 封 = linux-usb / linux-remoteproc / devicetree）、**142=Q28 RFC(10-22 22:08)**。〔已证实〕

### 3.4 噪声基线（`SINCE 20-Oct`，按 `List-Id`）

| List-Id | INBOX 封数 |
|---|---|
| `devicetree.vger.kernel.org` | **1285**（退订 10-21 14:31Z 生效，其余为之前残留） |
| `linux-arm-msm` | 919 |
| **`linux-pm`** | **329** |
| `linux-clk` | 295 |
| **`linux-usb`** | **221（10-21 新订后首次出现）** |
| `linux-input` | 191 |
| `libcamera-devel` | 63 + **143 全在 Junk** |
| **`linux-remoteproc`** | **17（新订后首次出现）** |
| 无 List-Id（私人信/系统信） | 18（教务 5、订阅回执 6、Konrad 3、sashiko 1、Joonhoe 1、Taniya 1、DSN 1） |

⇒ **日均 ≈ 1 160 封**（3 338 / 约 2.9 天），与上一轮 1 090/日 同量级〔已证实〕。**Junk = 100% libcamera-devel（143/143），比上轮的 66% 更极端**〔已证实〕。全文搜 `xiaqinghuan` 在 Junk 中 **0 命中** ⇒ **本轮 Junk 无我方任何线程的回复**〔已证实〕。

### 3.5 ⚠ 工具缺陷：官方 `--replies-only` **看不到本轮最重要两封**

```bash
python3 ~/.local/bin/read-mail-ustc.py --days 3 --replies-only
# => INBOX 5 封，全部是 10-20 的 Q24 线程；Q28 / battmgr 的回复 0 命中
```

原因：`read-mail-ustc.py:21-23` 把 `OUR_IDS` **硬编码成 3 个 mid**（都是 10-13 前后的旧件），**新增的 T5 / battmgr / Q28 mid 不在里面**。[已证实：源码行号 + 实跑输出]

**判据**：以后一律用「**按 Sent Items 动态取 mid 再求交**」（本轮脚本 /tmp/scan3.py 的做法），**不要信 `--replies-only` 的 0 命中**。

---

## §4 与上一轮口径的差异

### 4.1 「新人类发言」增量（上轮 = 1 条 Konrad；本轮 = 2 条人 + 1 机器人 + 1 系统）

| 发言 | 上一轮（至 10-21 21:1x） | 本轮新增 |
|---|---|---|
| Konrad Dybcio | 10-20 Q24 单变量建议 + 10-21 battmgr 澄清请求 | **+10-22 battmgr 二次反问（三个具体问题）** |
| Taniya Das | 窗口内 0 条面向我们 | **+10-22 Q28 明确技术反对（首次）** |
| sashiko | 4 条（M3-1） | **+4 条（Q28）** |
| 其它人类 | Joonhoe（信息性） | **0** |
| 系统 | — | **+1 DSN 退信** |

### 4.2 需推翻 / 修正的上轮口径

1. **上轮 §9「唯一必须回 = Konrad battmgr」已过期**：现在是 **2 条必须回**（+ Taniya/Q28）。〔已证实〕
2. **上轮 §6 的 A1/A2/A3 订阅建议已全部执行完毕**（上轮标为「待用户批准」）：devicetree **已退订**（`Goodbye` 10-21 14:31:44Z）、linux-usb **已订**（`Welcome` 14:31:45Z）、linux-remoteproc **已订**（`Welcome` 14:31:44Z）。**流向已变，§3.4 实测能对上**。〔已证实〕
3. **上轮「Junk 中 libcamera 占 66%」→ 本轮 100%**，且 Junk 中无我方线程。〔已证实〕
4. **M3-1 D 项：上轮「sashiko 从 12 条降到 4 条」→ 本轮 0 条新**（v3 无新 review）。**不是变好也不是变坏，是没有人看**。〔已证实〕
5. **上轮 §2.3 建议的「不急发 v4」仍成立**，但**新增一条例外考虑**：linux-usb 现已订阅（221 封进箱），若 `-rc1` 后 Greg 回复，我们**这次真的会收到**〔推测：上轮是「被 Cc 才收」，现在列表直送〕。
6. **上轮未记录的新事实**：`lenovo,elden` 在本仓树 `arm/qcom.yaml:1125` **已文档化，但它是本地提交**（`build/base-7.2` 的 `git log -S` 只命 1 个提交 = `378459aff` 本仓 payload 快照）⇒ sashiko 的 Medium ①「未文档化」**相对主线成立、相对本仓不成立**。回复时应直接指这一点（否则容易被误认为我们漏了 binding）。〔已证实〕
7. **`msm_mdss_reset()` 早就存在且就只复位一个 BCR**（`msm_mdss.c:309`，`msleep(20)` 注释「one frame」）。这**不是本轮新发现**，但上一轮报告未把它写进「M3/Q28 口径」，而它恰好是同时回答 Taniya + sashiko High **两方的钥匙**。〔已证实〕

---

## §5 边界声明

本轮为**主机侧只读**作业：

- **未发送任何邮件**（包括回复、转发、订阅/退订、DSN 重发）；`~/.local/bin/send-mail-ustc.py` **未调用**。
- **未修改 `.gitconfig`、未触碰任何凭据**（口令由 `read-mail-ustc.py:get_pw()` 从 GNOME keyring 取，全程未打印）。
- **未碰任何设备**（`fastboot`/`adb`/`ssh` 全部未执行）。
- **未 commit、未改仓库任何文件**（除本报告）；临时脚本均在 `/tmp/`（`scan3.py` / `body3.py` / `scan3.jsonl`）。
- 未新增 lore 以外的外部请求（lore 查询 = 8 次 GET，均为只读）。

> 上一轮 §6 的订阅动作（A1 退订 devicetree / A2 订 linux-usb / A3 订 linux-remoteproc）**已在 10-21 由其它 lane 完成**，本轮仅**核验结果**，未重做。
