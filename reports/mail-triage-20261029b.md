# Lane B 分诊报告 — 上游邮件与 patchwork（2026-10-29b）

状态：分节填充完成（§0–§5）。本 lane **只分诊与起草，未发送任何邮件**。

## 0. 方法与命令

红线：凭据只走 GNOME keyring（`read-mail-ustc.py` 内部 `keyring.get_password("smtp", …)`），
未落任何文件；IMAP 全程 `BODY.PEEK`，未置 `\Seen`。

```sh
# 1) 官方脚本（只有头，无正文）
/home/xuqianhui/.local/bin/read-mail-ustc.py --help
/home/xuqianhui/.local/bin/read-mail-ustc.py --days 5 --replies-only
# → INBOX 2 封 / Junk 0 / Sent 0

# 2) 官方脚本的 replies-only 用 3 个**硬编码**旧 Message-ID 匹配 In-Reply-To
#    （OUR_IDS，不含 10-26 起的 v4 / 10-27 批次），会漏掉在途系列回包 ⇒ 自建只读补扫：
out/mail-20261029b/mailscan.py --days 5 --mode ours     # 收件人/抄送含 xiaqinghuan@
out/mail-20261029b/mailscan.py --days 5 --mode series   # 主题命中系列关键词
tee out/mail-20261029b/scan-direct.txt   # → 116 条（含 Sent/Coremail 自存副本与 Junk 重复）

# 3) 按 Message-ID 抓整封正文（仅落 out/，不入库）
out/mail-20261029b/fetch.py out/mail-20261029b/ids.txt   # → 42 封 OK
```

原始计数的可复核输出：

```text
=== INBOX : 2926 封（SINCE 24-Oct-2026）===      # 5 天全量含 lkml/各子系统列表流量
[replies-only] INBOX 2 封 / "Junk E-mail" 0 封 / "Sent Items" 0 封
grep -c '^\[' scan-direct.txt  →  116             # 我方地址在 To/Cc 的全部（自存副本+Junk 重复）
非我方发件、非列表/非校务业务信 → **42 封去重**（见 §1）
```

⚠ 口径提醒：`--replies-only` 的最初结果（2 封，都是 Pengyu Luo 的重复件）**是漏检结果**，
不能当「上游只回了两封」用。下面 §1 用补扫结果。

## 1. 最近 5 天回信清单（--days 5 --replies-only）

窗口 = 2026-10-24 00:00 → 2026-10-29 16:20 +0800。下表已剔除：我方自存副本、
校务/教务/成绩/作业信、各列表无关流量。**同一封在 INBOX+Junk 各存一份的已去重**（故 61 条 → 42 封）。

| # | seq | Date (UTC+8) | From | Subject（截断） | Message-ID | 要点 |
|---|---|---|---|---|---|---|
| 1 | 12195 | 10-24 19:39 | Marc Zyngier | Re: [PATCH] irqchip/gic-v3-its: Claim LPI tables… | `87v76r8h0o.wl-maz@kernel.org` | M9 否决：认领 LPI 表的方案不对 |
| 2 | 12364/5 | 10-26 00:56 | Pengyu Luo | Re: [REPORT] SM8750 bonded dual-DSI + NT36536… | `CAH2e8h4wFH5Q…@mail.gmail.com` | DTS 可整块接手；无下游源码；`dsiclk_sel=0` 正确；「不答技术细节」 |
| 3 | 12842 | 10-26 20:50 | sashiko-bot | Re: [PATCH v4 1/3] dt-bindings: usb: snps,dwc3… | `sashiko-outbox-185247` | 3×Medium：hs-port 丢 `unevaluatedProperties`、缺顶层 `usb-role-switch`、mux-state 未互斥 |
| 4 | 12853 | 10-26 20:59 | sashiko-bot | Re: [PATCH v4 2/3] usb: roles… | `sashiko-outbox-185254` | 1×High：`if (!IS_ERR_OR_NULL(sw))` 应改 `if (sw)` 以透传 -EPROBE_DEFER |
| 5 | 12880 | 10-26 21:20 | sashiko-bot | Re: [PATCH v4 3/3] usb: dwc3… | `sashiko-outbox-185299` | 5×High+3×Med：持 `dwc->lock` 调 `dwc3_set_mode()` 死锁、同角色换 mux 端口漏处理、注册早于 init 竞态、fwnode 引用泄漏 |
| 6 | 12914 | 10-26 21:45 | linux-usb+owner | Bounce probe for linux-usb (no action required) | `1793022323-3128646-mlmmj-…` | 列表探活，非退信 |
| 7 | 12916 | 10-26 21:53 | Marc Zyngier | Re: [PATCH] irqchip/gic-v3-its…（我撤回后） | `86y0bky3el.wl-maz@kernel.org` | 对我撤回的收尾回应 |
| 8 | 13262 | 10-27 13:19 | sashiko-bot | Re: [PATCH 1/2] …Giantec GT9764 | `sashiko-outbox-186108` | 1×Med（应复用 `dongwoon,dw9768.yaml`）+2×Low（MAINTAINERS 排序） |
| 9 | 13611 | 10-27 21:37 | sashiko-bot | Re: [PATCH 4/5] Input: aw86927 AW8693X 布局 | `sashiko-outbox-186657` | 1×Med：PLAYCFG1 boost 位宽描述与代码不符 |
| 10 | 13623 | 10-27 21:55 | sashiko-bot | Re: [PATCH 5/5] aw86927 suspend/shutdown | `sashiko-outbox-186676` | 1×Med：`aw86927_reset()` 签名按 `devm_add_action_or_reset` 写却只被 shutdown 调 |
| 11 | 13803 | 10-28 01:58 | Mark Brown | Re: [PATCH] dt-bindings: regulator: WL2868C | `179312390429…b4-review@b4` | 主题名前缀不符子系统风格；MAINTAINERS 未排序；「只有 binding 别说 driver」；疑 linux-media 多余 |
| 12 | 13804 | 10-28 03:04 | Krzysztof Kozlowski | Re: 同上 | `c8e6c0e7-…@kernel.org` | **补丁本身破损**（正文出现整段重复）「use git or b4」；并问「谁用它？为何要这个 binding」 |
| 13 | 13805 | 10-28 03:06 | Krzysztof Kozlowski | Re: [PATCH 2/5] awinic,aw86927 AW86937 | `f76d56db-…@kernel.org` | **Acked-by**（唯一带 Ack 的在途件） |
| 14 | 14015 | 10-28 11:52 | sashiko-bot | Re: [PATCH 1/9] camss SM8750 binding（v1） | `sashiko-outbox-187448` | 1×Med：commit 里子块数量与实际不符 |
| 15 | 14017 | 10-28 12:00 | sashiko-bot | Re: [PATCH 8/9] camss vfe gen4（v1） | `sashiko-outbox-187458` | 1×Med：`vfe_reg_update()` 与 `csid_isr()` 竞态 |
| 16 | 14018 | 10-28 12:01 | sashiko-bot | Re: [PATCH 5/9] csid 报 SOF（v1） | `sashiko-outbox-187459` | 2×Med：`frame_started` 未清、无 `HAS_EVENTS` 世代没置位 |
| 17 | 14019 | 10-28 12:03 | sashiko-bot | Re: [PATCH 4/9] csid 980（v1） | `sashiko-outbox-187460` | 2×High+1×Med：`dt_id` 该用 `port&3` 非 `vc&3`、RUP 掩码漏解锁、三计数并发竞态 |
| 18 | 14020 | 10-28 12:06 | sashiko-bot | Re: [PATCH 9/9] sm8750 DTS（v1） | `sashiko-outbox-187462` | 1×High：停流/回滚失败时 CSID RDI 留使能且中断未掩 |
| 19 | 14048 | 10-28 15:28 | Patchwork Integration (media-ci) | Re: [0/9] camss v1 | `6ae1a415…@mx.google.com` | v1 建 series、CI 状态 |
| 20 | 14112 | 10-28 17:37 | sashiko-bot | Re: [PATCH v2 2/9] csiphy 2.4.0 | `sashiko-outbox-187685` | 1×Med：`0x005C` 等 4 条 SKEW_CAL 数据与正文矛盾 |
| 21 | 14128 | 10-28 17:52 | sashiko-bot | Re: [PATCH v2 4/9] csid 980 | `sashiko-outbox-187698` | 1×High：reg/aup/rup_update 位累加导致重复 AUP/RUP 命令 + 1×Med 竞态 |
| 22 | 14133 | 10-28 17:53 | sashiko-bot | Re: [PATCH v2 8/9] vfe gen4 | `sashiko-outbox-187701` | 1×Med：`vfe_reg_update_clear()` 与 `csid_isr()` 竞态 |
| 23 | 14154 | 10-28 18:10 | Vladimir Zapolskiy | Re: [PATCH v2 0/9] camss SM8750 | `8e05a28e-…@kernel.org` | **CSIPHY 必须走新 MIPI CSI2 PHY 驱动**（`phy-qcom-mipi-csi2-core.c`），参 SM8450 系列 |
| 24 | 14175 | 10-28 18:42 | Hangxiang Ma (QC) | Re: [PATCH v2 0/9] | `218d69dc-…@oss.qualcomm.com` | 本系列基于他的 SM8750 v6；**原始 authorship/SoB 被删**；要求**暂缓投递**、改进回原线程 |
| 25 | 14300 | 10-28 20:11 | Krzysztof Kozlowski | Re: WL2868C（我方 10-28 回复 1） | `e63d7539-…@kernel.org` | 「回复像低质 LLM 生成…过度消耗维护者资源」 |
| 26 | 14302 | 10-28 20:12 | Krzysztof Kozlowski | Re: WL2868C（我方 10-28 回复 2） | `0f60fcba-…@kernel.org` | 「That's LLM output. Why do you paste it?」 |
| 27 | 14306 | 10-28 20:17 | Bryan O'Donoghue | Re: [PATCH v2 0/9] | `5d886ac3-…@nxsw.ie` | 8750 camss 早在列表（2025-11 v1）；「先试那个，再在其上增补」 |
| 28 | 14318/22 | 10-28 20:30 | Bryan O'Donoghue | Re: [PATCH v2 5/9] csid 报 SOF | `84bc6332-…@kernel.org` | SOF 与 buf_done 不在同一中断，该逻辑不成立；他将另发 `V4L2_EVENT_FRAME_SYNC` 系列 |
| 29 | 14320/24 | 10-28 20:32 | Bryan O'Donoghue | Re: [PATCH v2 6/9] DMA 连续性检查 | `0f436944-…@kernel.org` | 逐行评审（见 §4 草案需引用其原话） |
| 30 | 14319 | 10-28 20:26 | Patchwork (linuxtv) | [linux-media] Patch notification: 18 patches updated | `179319036257…@linuxtv.org` | media patchwork 状态变更通知 |
| 31 | 14347 | 10-28 20:53 | Krzysztof Kozlowski | Re: [PATCH v2 1/9] camss binding | `20261028-easygoing-sepia-…@quoll` | 「What happened with …sm8750-v6…? That's a v6....」→ 质疑重复投递 |
| 32 | 14387 | 10-28 21:29 | Krzysztof Kozlowski | Re: [PATCH 1/2] GT9764 | `20261028-acrid-calm-bustard-…@quoll` | 「I don't understand why we need this. Where is any user of that?」 |
| 33 | 14393 | 10-28 21:31 | Krzysztof Kozlowski | Re: [PATCH 2/2] S5KJNS | `20261028-truthful-chupacabra-…@quoll` | **「You still send LLM-generated slop. Please start using Git.」**，否则降优先级 |
| 34 | 14408 | 10-28 21:47 | Patchwork Integration | Re: [v2,0/9] camss | `6ae1fd09…@mx.google.com` | v2 建 series |
| 35 | 14544 | 10-29 01:06 | postmaster@ustc | 系统退信/Systems bounce | `6AE22B80.11BF23.49362@mailimap2024` | **已定位**：原件 = 我方 10-28 19:57 给 Taniya 的 M8 撤回收尾信；失败收件人 `mturquette@baylibre.com`（Mike Turquette, clk 维护者），`Status: 5.0.0`、`MX query return retry`（当时暂时性；现 `dig MX baylibre.com` 正常） |
| 36 | 14751/3 | 10-29 16:07 | Krzysztof Kozlowski | Re: [PATCH v2 0/9]（回我方 10-29 汇总信） | `fe9765cf-…@kernel.org` | 「What are you referring to? I'll just drop this.」← 我方那封无引用/无对象 |
| 37 | 14778 | 10-29 15:35 | patchwork@kernel.org | Patchwork account confirmation | `010101a186958b04-…` | 本机 patchwork 账号动作（非上游） |
| 38 | 14781 | 10-29 15:48 | patchwork@kernel.org | Password reset on patchwork.kernel.org | `010101a186a23397-…` | 同上，需确认是否我方发起 |
| 39 | 14783/7 | 10-29 15:53 | Shuai Liu | Re: [PATCH 2/9] csiphy（对 v1） | `tencent_D8BA…@qq.com` | 正文/代码矛盾：2/9 写 `0x54`、正文写 `0x00`，靠 4/9 翻回；要求 2/9 自洽（文末声明用了 AI 辅助） |
| 40 | 14784/9 | 10-29 15:54 | Shuai Liu | Re: [PATCH 4/9] csid 980（对 v1） | `tencent_E9EE…@qq.com` | 同上前提下对 4/9 的意见 |
| 41 | 14786/91 | 10-29 15:54 | Shuai Liu | Re: [PATCH 8/9] vfe gen4（对 v1） | `tencent_3B08…@qq.com` | 同上 |
| 42 | 14785/8 | 10-29 15:54 | Shuai Liu | Re: [PATCH 9/9] sm8750 DTS（对 v1） | `tencent_4482…@qq.com` | 同上 |

补充（窗口外但为本轮判断必需）：Konrad 对 M2-A2 的原回帖 `84483ae1-…@oss.qualcomm.com` 日期 **10-23**、
Taniya 对 M8 dispcc RFC 的原回帖 `22a87c51-…@oss.qualcomm.com` 日期 **10-22**，均不在 5 天窗口内，
但我们在 10-28 已分别回复（`179318867727…`、`179318866835…`）。

## 2. 在途系列逐线程判断

### 2.0 两个跨线程的前提（先看这个）

1. **信誉事件（最高优先）**：Krzysztof 三封直接指责「LLM slop」——
   `20261028-truthful-chupacabra…`「You still send LLM-generated slop. Please start using Git.
   …then your work shall be deprioritized」、`e63d7539`「Reply looks like it was generated by a poor LLM」、
   `0f60fcba`「That's LLM output. Why do you paste it?」；Mark Brown 同时报了主题名前缀/MAINTAINERS 排序。
   叠加我方 10-29 那封**无称呼、无引用对象、裸编号列表**的汇总信（`179325717815`）→ Krzysztof 回
   「What are you referring to? I'll just drop this.」。**风险 = 整个提交者被降优先级**，已不是单系列问题。
   ⇒ 在修任何补丁之前，先修**提交形态**：git 生成（`git send-email`/`b4`）、每封带引用、有称呼与签名、
   ASCII 正文、不夹营销腔。
2. **重复实现事件（第二高优）**：camss SM8750 上游早已有 Qualcomm 系列（2025-11 v1 → `20260721…-v6`，
   且 Kaanapali v22/v23 在做），Hangxiang 直接要求**暂缓投递**并指出我方删掉了原作者与 SoB。
   我方 10-28 20:09 已回信承诺 hold + 补 trailer；10-29 14:59 又对 Bryan 承诺**放弃 binding/CSIPHY/
   CSID980/VFE/DTS 五类补丁**。这些是**已在公共邮件列表上做出的承诺**，后续动作必须与之自洽。

### 2.1 逐系列

| 系列 | 最新上游动作 | 我方欠的动作 | 阻塞 / 可立即做 |
|---|---|---|---|
| **M3-1 v4**（USB 双连接器，`20261026123211.243224-1..4`，10-26 12:32Z） | sashiko **3 份评审**：1/3 3×Med（hs-port 丢 `unevaluatedProperties`；缺顶层 `usb-role-switch`；`mux-state` 未互斥）、2/3 1×High（`!IS_ERR_OR_NULL(sw)` 吞掉 -EPROBE_DEFER）、3/3 **5×High+3×Med**（持 `dwc->lock` 再调 `dwc3_set_mode()` **自死锁**；同角色换 mux 端口不处理；`usb_role_switch_register()` 早于 init 的竞态；`fwnode_handle_get` 泄露）。**无人类维护者回帖**；linux-usb bounce-probe 仅列表探活 | ① 核对死锁是否真存在（读 `dwc3_set_mode()` 再抢 `dwc->lock`）②出 **v5** 修 3×High 级 ③在 v5 cover 里回 sashiko 每一条 ④补 `dwc3_pre_set_role()`/glue 通知 ⑤binding 侧回“是否改用 mux-controls 标准属性” | **不阻塞**（无人类否决）；但 **High 级含死锁，不能放着等**。可立即做：本地复现/代码核对 + v5 预备 |
| **M2-A2**（`qcom_battmgr` power_now，`20261027132949.242685-1`） | 上游**无新回信**（窗口内 0）。patchwork 两副本均 `handled-elsewhere` 但 **commit_ref 为空**（非已入树证据）。10-23 Konrad 的原质疑已在 10-28 19:57 回复（`179318867727…`） | 等 Konrad/Sebastian；若下一轮仍无音，主动发 v2 打 `[PATCH v2]`（PITFALLS #450） | **阻塞**（等人）。可立即做：把 10-28 回信的承诺（形状裁决/kanaapali 一句）落成 v2 文本备好 |
| **M4-1 gt9764**（`20261027051048.213177-2`） | Krzysztof 10-28 21:29 `acrid-calm-bustard`：「I don't understand why we need this. Where is any user of that?」；此前 sashiko 1×Med（应复用 `dongwoon,dw9768.yaml`）+2×Low（MAINTAINERS 排序） | 答“用户在哪”：①说明 VCM 驱动的投递计划（若真有）或②合入 `dw9768.yaml` 而不是新 schema；③修 MAINTAINERS 排序 | **阻塞**（缺用户/复用方案未定）。可立即做：`git diff` 确认能否直接扩 dw9768（唯一不确定点） |
| **M4-1 s5kjns**（`…-3`） | Krzysztof 10-28 21:31 `truthful-chupacabra`：「You still send LLM-generated slop. Please start using Git.」（无技术意见） | 无技术修改项；**必须先交“用 git 生成”的干净重发**，否则任何技术回复都无效 | **阻塞**（信誉）。可立即做：`b4 send`/`git send-email` 重发链验证 |
| **M4-1 wl2868c binding**（10-27 `20261027051055.213301-1` → 10-28 v2 `20261028120423.99034-1`，series 1194266/1194272/1195400） | ①Mark Brown：主题前缀不合子系统风格、MAINTAINERS 未排序、“只有 binding 别说 driver”、linux-media 多余；②Krzysztof：“broken patch, use git or b4”+“谁用它？”；③v2 后：`changes-requested` + 两封直指 LLM 味 | ①主题改 `regulator: dt-bindings: …`（v2 已改）②MAINTAINERS 排序与名字去掉 DRIVER ③答“用户在哪”（camss DTS + 驱动力）④**正文重写**成人类讨论体 | **阻塞**（信誉+用户归属）。可立即做：binding 文本改动很小，关键在措辞 |
| **M4-2 camss 9 枚**（v1 `20261028034105…` 10-28 03:40Z → v2 `20261028093003…` 09:30Z） | ①**Hangxiang Ma**：基于他的 SM8750 v6，**作者/SoB 被删**，要求**暂缓投递**；②**Bryan**：「8750 is on-list for a while…先试那个再增补」+ 逐片意见（5/9 SOF 与 buf_done 不在同一中断、6/9 需引用依据）；③**Vladimir**：CSIPHY **必须**用 `phy-qcom-mipi-csi2-core.c` 新 PHY 驱动；④**Krzysztof**：质问 “That's a v6....” 重复投递；⑤sashiko 12 条（4 High），含 `dt_id` 用 `vc&3` 错、RUP 掩码漏解、reg/aup/rup 位累加导致重复命令；⑥Shuai Liu：2/9 写 `0x54` 而正文写 `0x00`，靠 4/9 翻回，要求自洽 | ①**已承诺**：hold、补 `From:/Co-developed-by:/SoB`、放弃 binding/CSIPHY/CSID980/VFE/DTS 五类 ②尚未落实：把“剩下三枚框架补丁”基于 v23 重基并提交 ③回 Shuai Liu（指出的正是我方 R1 未决项）④补 V4L2_EVENT_FRAME_SYNC 方向确认 | **阻塞**（等 Kaanapali 重基；且我方已公开让路）。⚠ **v3 已备料未发**：`patches/upstream/m4-camss-series-20261029-v3/`（9 枚，`+42 −1`，含 4/9 加锁与 write-then-clear）——但它仍带 binding/CSIPHY/CSID980/VFE/DTS，**与 10-29 的公开承诺相矛**，需拍板后才能动（见 §5） |
| **aw86927 5 枚**（`20261027132929.242158-1..6`） | ①**Krzysztof 对 2/5 给了 Acked-by**（唯一正面信号）②sashiko 4/5：PLAYCFG1 boost 位宽描述与代码不符；5/5：`aw86927_reset()` 签名按 `devm_add_action_or_reset` 写却只被 shutdown 调 ③Dmitry（linux-input 维护者）**无回信** | ①修 4/5、5/5 两处 ②重发时**保留 2/5 的 Acked-by**（否则 Ack 丢）③等 Dmitry | **不阻塞**（有 Ack，可出 v3）。可立即做 |
| **M1-U6 pas dtbfw**（`20261027132944.242550-1`） | 上游**零回信**（patchwork 两副本均 `new`，无 tag/commit_ref） | 无；可选的温和 ping（≥7 天后再考虑），别现在催 | **阻塞**（等人）。可做的：把 linux-next “2 处 release” 的正文措辞预先改好 |
| **M8 dispcc RFC**（10-22 RFC；10-28 19:57 我方已回 Taniya） | 窗口内**无新回信**（Taniya 原回帖 10-22，已回）；patchwork linux-clk 副本 `awaiting-upstream`。⚠ **我方那封收尾信对 `mturquette@baylibre.com` 退信**（5.0.0 MX query retry，10-29 01:06 退回到本地） | ①**重投给 Mike Turquette**（只给他，不抄列表；正文同原件）②继续等 clk 维护者；若要转正式系列需 `msm_mdss_reset()` 版补丁 + DT 属性 | **部分阻塞**（Taniya 已收到，Mike 未收到 ⇒ 不能算“已回”）。可立即做：重投删单 |
| **wl2868c driver**（未投） | 无（未投） | **不应单独投**：binding 现状是 `changes-requested` 且上游反复问“用户在哪”。driver + binding + DTS 用户一起投才是回答 | **阻塞**（被 binding 卡住）。可立即做：备料核对（驱动是否已能 `-next` 上 apply） |
| （附带）**M9 ITS** | Marc Zyngier 10-24 否方案；我方 10-26 已撤回并回读，10-26 13:53 他收尾回应 | 无 | ✅ **关闭** |
| （附带）**REPORT NT36536 冷启动**（`179276337975…`） | Pengyu Luo 10-26 00:56：DTS 可整块接手（squash 后自便）、无公开下游源、`dsiclk_sel=0` 正确、“不答技术细节” | 无必答；但**我方 SMMU/splash 与 23 次 A/B 结论应在自己的报告里定性**（已闭环） | ✅ 可关闭；只剩“是否把统计回帖到列表”待拍板 |

### 2.2 一页结论

- **可立即推进**（无人阻塞）：M3-1 v5（含死锁修复）、aw86927 v3（保 Ack）、camss 三枚框架补丁。
- **等人**：M2-A2、M1-U6、M8 dispcc。
- **必须先修形态再谈技术**：s5kjns / wl2868c binding / gt9764（“用户在哪”）——否则重复投递只会加深“slop”印象。
- **已让路**：camss SM8750 主体（五类补丁）按承诺不再并行提交。


## 3. patchwork series 状态与 reviewer

只读（匿名 API + `--noproxy '*'`），**未用 token、未改任何 state**。token 存在 keyring
（`service=patchwork.kernel.org`）但本轮全程匿名，无取用必要。

```sh
# 我方全部提交（按 submitter）
curl -s --noproxy '*' "https://patchwork.kernel.org/api/1.2/patches/?submitter=xiaqinghuan%40mail.ustc.edu.cn&per_page=100&order=-date"
# 逐 series 取 state / delegate / commit_ref / tags
python3 -c '… /series/<id>/ 、 /patches/<id>/ …'
```

### 3.1 我方在途 series（各 project 副本分列，state 独立）

| series id | project | 名称 | ver | 逐片 state | delegate | commit_ref | 备注 |
|---|---|---|---|---|---|---|---|
| 1193720 | linux-usb | dwc3 双连接器 | v4 | new×3 | — | — | USB 维护者未动 |
| 1193723 | devicetree | 同上 | v4 | **needs-ack×1**、handled-elsewhere×2 | — | — | **binding 在等 DT ack** |
| 1193719 | linux-arm-msm | 同上 | v4 | handled-elsewhere×3 | — | — | 镜像副本 |
| 1194635 | linux-input | aw86927 | v1 | new×5 | — | — | 有 Ack 但 **tags 为空** |
| 1194640 | devicetree | 同上 | v1 | handled-elsewhere×4、**not-applicable×1** | — | — | 那枚 binding 在 DT 项目被判 not-applicable |
| 1194634 | linux-remoteproc | pas dtbfw | v1 | new×1 | — | — | 零动作 |
| 1194636 | linux-arm-msm | pas dtbfw | v1 | new×1 | — | — | 零动作 |
| 1194637/8 | arm-msm / linux-pm | battmgr power_now | v1 | handled-elsewhere×1 | — | **—** | 不是“已入树”证据 |
| 1194267 | devicetree | gt9764 + s5kjns binding | v1 | **changes-requested×2** | — | — | 对得上 10-28 Krzysztof 两封 |
| 1194271 | linux-media | 同上 | v1 | new×2 | — | — | media 侧未动 |
| 1194266 / 1194272 | devicetree / linux-media | wl2868c binding v1 | v1 | changes-requested / new | — | — | 10-27 原件 |
| 1195400 | devicetree | wl2868c binding v2 | **v2** | **changes-requested×1** | — | — | 主题已改对（`regulator: dt-bindings:`） |
| 1191865 / 1191356 | dri-devel / arm-msm | dispcc RFC | v1(RFC) | new×1 | — | — | — |
| 1191359 | linux-clk | dispcc RFC | v1(RFC) | **awaiting-upstream×1** | — | — | clk 侧等上游其它块 |
| 1192575 | linux-arm-kernel | ITS kexec | v1 | new×1 | — | — | 已撤回（未改状态） |
| 1189498 / 1188900 | dri-devel / arm-msm | DSI `PLL_SYSTEM_MUXES` | v1 | new / handled-elsewhere | — | — | M6 L1，无邮件回包 |
| 1195087 | linux-media | camss SM8750 **v1** | v1 | superseded×9 | — | — | 被 v2 取代 |
| 1195271 | linux-media | camss SM8750 **v2** | v2 | **superseded×9** | — | — | ⚠ 无 v3 存在（见 3.3） |
| 1195272 | linux-arm-msm | 同上 | v2 | handled-elsewhere×8、superseded×1 | — | — | 镜像副本 |
| 1195277 | devicetree | 同上 | v2 | superseded×1、handled-elsewhere×8 | — | — | 镜像副本 |

### 3.2 reviewer 只能从邮件判（patchwork 无 delegate）

全部 24 个 series 的 `delegate` 均 **null**，即 patchwork 上没有任何正式委派。实际 reviewer 全在邮件里：

| 系列 | 实际在跟的人 | 身份 |
|---|---|---|
| M3-1 v4 | sashiko-bot（3 份）；人类：无 | DT/USB 维护者未出现 |
| M4-1 binding | Krzysztof Kozlowski（DT）、Mark Brown（regulator） | 两人都已表态 |
| M4-2 camss | Vladimir Zapolskiy、Bryan O'Donoghue、Hangxiang Ma（QC）、Krzysztof、sashiko | 四人 + 机器人 |
| aw86927 | Krzysztof（Ack）、sashiko；Dmitry 未出声 | — |
| M1-U6 / M2-A2 / M8 | 无新动作（Bjorn/Mathieu/Sebastian/Taniya 本轮零回信） | — |

### 3.3 三个不宜过度解读的点（避免误判）

1. **camss v2 在 linux-media 显示 `superseded`，但根本没有 v3**：
   `patches/?submitter=xiaqinghuan@…&order=-date` 最新仍是 2026-10-28 v2；
   `related` 为空、`commit_ref` 为空、无标签。⇒ 这个 state 是人工/规则改动，**不能当“已有 v3”用**，
   也不能当“被收”。真正的事实是 Hangxiang 在邮件里要求 hold。
2. **`handled-elsewhere` 不等于已入树**：battmgr / aw86927 / M6 的副本都是 handled-elsewhere 但 `commit_ref=null`。
3. **Krzysztof 对 aw86927 2/5 的 Acked-by 没有进 patchwork `tags`**（还是 `{}`，只有 57 条 CI check）。
   ⇒ 重发 v3 时 **必须手工把 `Acked-by: Krzysztof Kozlowski <…@oss.qualcomm.com>` 写在 2/5 的 trailer 区**，
   不要指望 patchwork/b4 自动带上。

### 3.4 上游竞品系列（判重用的外部基准）

| 系列 | 最新 | 证据 |
|---|---|---|
| `media: qcom: camss: Add SM8750 support`（Hangxiang Ma, QC） | **v6，2026-07-21**（series 1131652/1131654/1131655/1131656；v1 起于 2025-11-26） | patchwork API 同上；lore `20260721-add-support-for-camss-on-sm8750-v6-0-a5f841061d18@oss.qualcomm.com` |
| `media: qcom: camss: Add Kaanapali support`（同一人） | **v23，2026-10-28 15:20**（series 1195541/1195544，15 枚） | patchwork 逐片查；比我们 v2（10-28 09:30）晚 6 h |

⇒ 结论：**camss SM8750 的路线上游早已占据且仍在迭代**，我方 v1/v2 属于重复实现。这与 §2.0-2 一致。

## 4. 回帖要点草案（纯 ASCII，放 out/mail-20261029b/）

草案**只有正文**（无 To/Subject/References 头），以便直接拼进 `git send-email` 或 `b4`。
全部纯 ASCII，已机械校验：

```sh
cd out/mail-20261029b && grep -Pn '[^\x00-\x7F]' 0*.txt   # → 无输出（rc=1）
```

| 文件 | 收件/回帖对象 | 对应上游邮件 | 要点 |
|---|---|---|---|
| `01-M3-1-mux-deadlock.txt` | sashiko（回 M3-1 3/3） | `sashiko-outbox-185299` | 承认自死锁（持 `dwc->lock` 再调 `dwc3_set_mode()`）；一并接注册竞态/fwnode 泄漏；v5 把角色变更挪出锁 + 带 1/3 三个 binding 修正 |
| `02-M3-1-binding-mux-controls.txt` | sashiko / DT 维护者（回 1/3） | `sashiko-outbox-185247` | 解释 per-endpoint `usb-role-switch` 的硬件原因；承认顶层 `usb-role-switch` 是真 bug；**反问**是否改用 `mux-controls/mux-states` 标准属性（不自辩） |
| `03-M4-1-gt9764-user.txt` | Krzysztof（回 gt9764） | `20261028-acrid-calm-bustard-…@quoll` | 直答“无用户”：给两条路（合入 `dw9768.yaml` / 与驱动+DTS 同发）并请对方选；选前不发 |
| `04-M4-1-wl2868c-user.txt` | Krzysztof + Mark Brown（回 wl2868c） | `e63d7539` / `179312390429…b4` | 认下“v1 非 git 生成、v2 封面非我逐行写”；说明用户 = DTS 节点 + 未投的驱动；接受“无驱动不发 binding” |
| `05-camss-clarify-thread.txt` | Krzysztof（回 `“I'll just drop this”`） | `fe9765cf-…@kernel.org` | **修补型**：先遣词（上一封无引用/无对象），再用可引用的话重述三项承诺（SM8750 主体让路、FRAME_SYNC 交 Bryan、只剩三枚框架补丁） |
| `06-camss-shuai-liu-skewcal.txt` | Shuai Liu（回 v1 2/9） | `tencent_D8BA…@qq.com` | 确认 2/9 vs 4/9 矛盾就是 R1 未决项（厂商 `0x00` vs 实测 `0x54`）；不上机定论不粉饰；该 patch 将随 CSIPHY 进 PHY 驱动而消失 |
| `07-aw86927-v3-note.txt` | Krzysztof + sashiko（回 2/5 Ack 与 4/5、5/5） | `f76d56db`、`sashiko-outbox-186657`、`-186676` | 声明确保 2/5 Ack 原样带进 v3；接 4/5 位宽矛盾（改代码不改描述）、5/5 `aw86927_reset()` 签名/调用点不匹配 |

未起草（故意）：

- **M1-U6 / M2-A2 / M8**：上游零动作，此时发任何东西都是催命，反而扣分。
- **s5kjns**：Krzysztof 那封无技术内容（只斥形式），**回文字无用**，只能用“下一次干净重发”作答。
- **Pengyu Luo（NT36536 报告）**：他已明说“不答技术细节”，无需回帖；除非要回帖 23 次冷启动统计（待拍板）。

## 5. 已做 / 未做 / 待拍板

### 5.1 已做

1. 拉取窗口 10-24 → 10-29 全部相关邮件：官方脚本 `--days 5 --replies-only`（2 封）+ 自建只读补扫 42 封去重。
2. 发现并证实**官方脚本的 replies-only 会漏检**（硬编码 3 个旧 Message-ID，不覆盖 10-26 起的 v4 与 10-27 批次）。
3. 42 封逐封落正文到 `out/mail-20261029b/bodies/`（不入库），完成 12 个线程的归并。
4. patchwork 匿名 API 查了 24 个 series 副本：state / delegate / commit_ref / tags；确认无 delegate、无 commit_ref。
5. 定位 10-29 系统退信：**M8 给 Taniya 的收尾信对 `mturquette@baylibre.com` 投递失败**（5.0.0，MX 暂时抽风，现 MX 正常）——此件从未重投。
6. 起草 7 封回帖（纯 ASCII）：`out/mail-20261029b/0*.txt`。
7. **未发送任何邮件**，未调用任何 send 参数；凭据只在 keyring，未落盘；IMAP 全 `BODY.PEEK`，未改变已读状态。

### 5.2 未做（本 lane 越界或需硬件）

- **未发改任何补丁**（v5、v3 均未动手）；未上机验证 SKEW_CAL `0x54` vs `0x00`（R1 仍在）。
- 未回帖任何线程（只起草）。
- 未核对 lore 侧完整性（Anubis 反爬，本次以 INBOX 回包 + patchwork 为准）。
- 未动 patchwork state/token；未改写 `reports/upstream-status-*.md`（那是主 lane 的当前页）。

### 5.3 待拍板（按紧急度）

| # | 事项 | 为何需要你定 | 默认建议 |
|---|---|---|---|
| 1 | **先修“提交形态”再修补丁**：后续所有补丁强制 `git format-patch` + `git send-email`/`b4`，正文由人逐行写 | Krzysztof 已明确“否则降优先级”；这是全局信誉而非单系列 | 采纳；并把“不用 b4/git 生成”列入投递前门禁 |
| 2 | **M8 重投给 Mike Turquette** | 他那封退了，不重投等于从没撤回过 | 重投原件（只给他） |
| 3 | **camss v3 是否废弃**（`patches/upstream/m4-camss-series-20261029-v3/` 9 枚已备料） | 它仍含 binding/CSIPHY/CSID980/VFE/DTS，与 10-29 公开承诺相矛；若发 = 自打脸 | 拆出三枚框架补丁，其余归档为“已让路” |
| 4 | **M3-1 是否现在出 v5**（含死锁修复） | 无人类否决 + High 级含自死锁；但连发大修可能被视为“不等人” | 出 v5；cover 逐条回应 sashiko |
| 5 | **gt9764 路线**（新 schema vs 合入 `dw9768.yaml`） | 要回 Krzysztof，两者互斥 | 倾向合入 `dw9768.yaml`（减少新文件） |
| 6 | **wl2868c binding/driver 组合投递** | 上游反复问“用户在哪”；单独投 binding 已被判 changes-requested | binding + driver + DTS 用户同系列 |
| 7 | 是否把 23 次冷启动 A/B 统计回帖到 NT36536 报告线程 | Pengyu 已说“不答技术细节”，回帖可能只对归档有用 | 不回，写进自己的报告即可 |
| 8 | **patchwork 账号动作来源**（`14778` 确认信 + `14781` 密码重置，10-29 07:35Z/07:48Z） | 若不是本轮/主 lane 发起，属安全事件；若是，则记一笔 | 主 lane 确认谁在 10-29 上午动过 patchwork 账号 |

### 5.4 一句话总结

过去 5 天真正的坏消息不是“没回信”，而是**两个信誉/路线事件同时到位**：
Krzysztof 已两次点名“LLM slop”，且 camss SM8750 被 Qualcomm 证明是重复投递并要求 hold；
好消息只有 aw86927 binding 的 Ack 与 M1-U6/M2-A2 仍在队列（无坏消息）。
下一步优先级：**修递交形态 > 重投 M8 退信件 > M3-1 v5 > 三枚框架补丁**，其余全保持安静。
