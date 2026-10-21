# 上游邮件分诊 + 订阅动作准备（2026-10-21）

> 角色：worker（只读）。**未发任何邮件、未发任何订阅请求、未改 `.gitconfig`/凭据、未碰设备**（`HA2EXB0E` 仍在 fastboot）。
> 窗口：**2026-10-15 → 2026-10-21 21:1x CST**。前序档案（只做「确认/推翻 + 差量」）：`mail-triage-20261017.md`、`mail-triage-20261019.md`、`mail-lists-subscription-20261013.md`、`TASKS/README.md` §4 T1/T5、§7 M1–M7。通道口径见 `.pi/skills/upstream-mail-ustc/SKILL.md`（凭据只在 GNOME keyring，本文不含口令）。

---

## §1 查询方法与通道实测

**结论先行**：通道正常；窗口内我方**又投 4 件**（前档未覆盖，§2.1），收到 **1 条必须回**（Konrad/battmgr）+ 1 信息性（Joonhoe）+ 1 机器人「等 -rc1」+ 5 sashiko。**订阅真实状态比档案更宽**：已订 6 个，**devicetree 一项占 INBOX 54%**（§5）。

| 项 | 值 | 证据 |
|---|---|---|
| 脚本 | `ls scripts/ \| grep -i mail` = **空**（仓库无 mail 脚本）；工具在 `~/.local/bin/{read,send}-mail-ustc.py` + `lore-query.py` | 命令输出 |
| 凭据 / IMAP | **GNOME keyring**（service `smtp`，条目 `smtp.ustc.edu.cn:465`）首路径命中，**未回退 git-credential、未打印口令**；IMAP `mail.ustc.edu.cn:993`，三处全扫（Junk 名带引号） | `read-mail-ustc.py:get_pw()`；select 全 OK |
| 时间窗/命中量 | `SINCE 14-Oct-2026`（服务端逐日 15-Oct=7381 / 19-Oct=3335 / 21-Oct=894）；**INBOX 8 747 / Junk 117 / Sent 22 = 8 886 头**，落 `/tmp/scan2.jsonl`，23 s | IMAP `SEARCH SINCE`；`/tmp/mailscan2.py` |
| 我方 / 外部 | 我方 mid = Sent **22**（**8 封作业**无关）；外部回信按 `In-Reply-To`/`References` 求交 = **7 封**（Greg/Kieran/Barnabás 各 1、sashiko 4），另 2 封在别线程点了我们（Konrad Q24、Joonhoe） | §2.1 / §2.5 |

复现：`read-mail-ustc.py --days 7 --replies-only`（官方）→ `/tmp/mailscan2.py 14-Oct-2026`（全量头）→ `/tmp/bodyfetch.py /tmp/mids.txt 3000`（按 mid 取正文，均不入库）。

⚠ **坑（本次踩到）**：本服务器对 `BODY.PEEK[HEADER.FIELDS (DATE FROM SUBJECT …)]` 会让 `Date/From/Subject` 解成空串（只 `Message-ID` 正常），必须用 **`BODY.PEEK[HEADER]` 整块**，否则头表除 mid 外全空。
**流量基线**：INBOX 全量 10 376 封中 **8 745 封（84%）在 10-13 之后** ⇒ 日均 ≈ **1 090 封**。

---

## §2 分类①：对我们补丁/报告的回复

### 2.1 ★ 修正前提：窗口内我方又投了 4 件（Sent 逐条核对）

| 时间 (CST) | 件 | Message-ID | To / Cc |
|---|---|---|---|
| 10-19 21:00 | `[PATCH] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable`（M1） | `<20261019130041.305805-1-xiaqinghuan@mail.ustc.edu.cn>` | R.Clark/D.Baryshkov/A.Kumar；arm-msm+dri-devel+freedreno+lkml |
| 10-19 21:10 | `Re: [PATCH] drm/msm/dsi: fix AHB clock staying enabled across suspend` | `<179241542813.315541.11037007061803544238@mail.ustc.edu.cn>` | Joonhoe Kim；+Arpit Saini、arm-msm/dri-devel/freedreno |
| 10-19 21:18 | `[RFC PATCH v3 0/2] USB: describe two connectors sharing one DWC3 HS data bus`（+1/2、2/2） | `<20261019131848.344689-1/-2/-3-xiaqinghuan@mail.ustc.edu.cn>`（0/2 的 `In-Reply-To` = v2 cover） | Greg KH/Thinh/R.Herring；linux-usb+devicetree+arm-msm+lkml |
| 10-20 19:02 | `Re: [Regression v3] …`（T5 三件套，5 附件） | `<179249416915.570120.11194300523322683054@mail.ustc.edu.cn>` | Taniya；arm-msm+linux-clk |

⇒ **推翻 `mail-triage-20261019.md` §3.3「M1 从未发出」**（该文成文时成立，当晚已发）；`TASKS/README` §7「冻结/待解冻」**已过期**（worker 不写 README）。

### 2.2 ★ 唯一「必须回」：M2-A2 battmgr —— Konrad 要求澄清机制用词

- **`<5bf3636d-be7a-4800-9914-808d2fc5ebd9@oss.qualcomm.com>`**，**10-21 10:48 +0200**，To 我 + linux-pm + Sebastian Reichel。
- 原话：「I'm having trouble parsing this. Is that a description of what happens on the firmware side? **What's a maximum-load updater?**」（被质疑的我方句：「QBG firmware fills `BATT_POWER_NOW` via its maximum-load updater … getter indexes `context + 0x6a8 + 4 * property`」）
- **要求动作 = 只改文字、不改代码**：自造词换成 QBG 正式术语，并分层写清「固件填值行为」vs「驱动按 descriptor 索引读」。
- 回复要点（**不代发**）：① 术语替换 + 上报语义（按最大负载估算 ≠ 瞬时采样）；② 明确不是驱动 bug；③ 给形状不给结论（`current_now × voltage_now` vs `power_now` 量级对照）；④ 承接 Fenglin 10-19 `<c030eac4-…>`「默认支持、OEM 可定制掉」——定性**需 stock Android 同机取证**（设备侧，未做）。

### 2.3 M3-1 **v3**（RFC）：Greg 的回复是 bot；sashiko 从 12 条降到 4 条，但含 1 条 v3 新引入的 High

| 日期 | 发件人 | Message-ID | 要点 | 需回？ |
|---|---|---|---|---|
| 10-19 15:24 +0200 | **Greg KH**（自署 "friendly semi-automated patch-bot"） | **`<2026101912-squealing-syndrome-8f6b@gregkh>`** | USB 树合并窗口 **closed**；补丁**没丢**，`-rc1` 后看；**「你不需要做任何事」** | **否** |
| 10-19 13:29Z | sashiko（1/2 binding） | `<sashiko-outbox-177155@kernel.org>` | ① **Medium**：`hs-port` 把 `port@0` 收窄成只匹配 `^endpoint@[01]$` ⇒ **单连接器 DTS 用无编号 `endpoint` 校验回归**（点名 `sm8550.dtsi`、`imx8mp-beacon-kit.dts`）② **Medium**：两个 `if: const 0` 都失配时 `mux-state=<1>` 可重复通过 + 缺 `required` 会空匹配 ③ **Low**：描述引用内核函数名（违 `writing-bindings.rst`）+ 再推标准 mux bindings | **是（纯 binding）** |
| 10-19 13:26Z | sashiko（2/2 driver） | `<sashiko-outbox-177142@kernel.org>` | **1 High**：`usb_role_switch_at_endpoint()` **吞掉 `-EPROBE_DEFER`**（`usb_role_switch_match()` 区分「属性缺失→NULL」/「属性在但未注册→defer」，我方把 defer 当「没找到」继续遍历 ⇒ consumer 先 probe 时永久拿不到 switch） | **是（真缺陷）** |

⇒ 人类 review 仍 **0**；建议**等 `-rc1`**，期间只做 High + 2 Medium 三处小改，**不急发 v4**（`AGENT-OPS` §3 一次正反判断）。

### 2.4 M1 与 Q24/Taniya：都是 **0 回复**（均已投递并归档）

- **M1 `PLL_SYSTEM_MUXES`**：邮箱侧窗口内无任何邮件 `In-Reply-To`/`References` 指向 `<20261019130041.305805-1-…>`（求交 0，唯一命中是我们自己那封）；lore `/linux-arm-msm/` **已归档**（头部一致）。**〔已证实〕已投 + 0 回复（24 h）**。
- **Q24/Taniya**：`From: *taniya*` 全扫，她窗口内最后一封 = **10-16** 且全在**别人线程**（GP M/N、gcc-qcs615、gcc-glymur、av1ecc-glymur），对我们 Q24 与 T5 交件**无回执无催问**。线程内唯一新人类发言 = **Konrad 10-20 09:37 +0200** `<101257b5-7e43-4cc1-ba17-1507dad27b52@oss.qualcomm.com>`（同 mid 进箱 **3 份**=多路投递）= 单变量实验（注释 `rpmhpd_driver.sync_state` 把 rail 钉最大档）；`TASKS/README` §4 T5 已收录，**vk64 台架未跑**。

### 2.5 Joonhoe Kim 10-20：回答了我们的提问（信息性，无请求）

**`<20261020132424.983-1-26rote@gmail.com>`**（10-20 22:24 +0900，To 我）。
- 我们问：runtime-callback 变体下 DPMS off 后 dispcc 会 suspend 吗？DPMS on 面板能回来吗？→ **两个 Yes**（SM8850 / v7.3-rc4，`display off + system awake`）：现行代码 + Arpit 补丁 = `disp_cc_mdss_ahb_clk` prepare **2**、dispcc **active**、**MMCX on**；只在 PHY runtime 回调 prepare = prepare **0**、dispcc **suspended**、**MMCX off**；30 次 DPMS off/on 全回面板。
- 今日加测：**无 DP sink** → DPU/双 DSI/PHY/DP controller/MDSS/dispcc **全 suspended**、`ahb_clk enable=prepare=0`；**插 sink** → DP controller/MDSS/dispcc **保持 active**、`enable=2 prepare=2` ⇒ 残留引用来自 **DP 侧**；且**他的树带自己的 DP 补丁**（每 sink 一份 runtime PM 引用），**可能与 mainline 不同**。
- 建议 **不回**（等自然触点）；若回只给观测、不索数据、不提 G2/G3。价值 =「dispcc prepare 计数 ↔ MMCX on/off」这条**可复现度量**（Q24/Q28 通用）。

---

## §3 分类②：sm8750 / 骁龙 8 Elite 新线索

### 3.1 ★★ 与 Q24 同族且**上游已接受**：camcc GDSC「卡在 off」= 缺 flop retention + wait

`[PATCH v2 2/3] clk: qcom: camcc-sm8450: Retain flops across camera GDSC collapse` + `3/3 … Park the camera RCGs when they are disabled`（Sushmit Singh Rathore，10-20 14:21；**Abel Vesa `Reviewed-by` 10-21 11:40 +0300** `<lhszemddes3ettau7brxfaiqe7srrqy4mfb4coxtlclxsavbg3@jk5c2s235wkj>`）。
作者机理：「camera GDSC 在两次会话间被 collapse；**无 flop retention + 默认 clock-disable wait 时，IFE GDSC 下次上电卡在 off**」→ 修法 = **same wait values + `RETAIN_FF_ENABLE`**。
⇒ Q24 候选机理在上游的**正解是「保 flop + 调 wait」而非「别 collapse」**（可作回 Taniya 的锚点）；与 Jagadeesh `PWRSTS_RET_ON`（GDSC 永不合）是**同族语义的另一半**，须成对读。

### 3.2 Adreno 8xx（= 我们 A830 同代）两件与我们直接相关

| 线程 | 意义 |
|---|---|
| `[PATCH 00/12] drm/msm/a8xx: GPU state capture support`（**Rob Clark** 10-20；含 `06/12 Fix PROTECT span length`、`09/12 devcoredump`、`10-11/12 generated nonctx/protect regs`），Konrad 10-21 逐枚 review | GPU 崩溃取证/寄存器表重构；**形状未定，别急着跟**，但 M1–M5 的 GPU 取证要基于这批之后的树 |
| `Re: Adreno 829 (SM8845) zap shader: PAS init rejected by TZ under Gunyah`（Venkat **自撤题**，10-21 10:38 `<TYCPR01MB11847…@outlook.com>`） | **可直接用的结论**：失败 = **zap shader 拿错签名副本**。stock `/vendor/firmware/gen80900_zap.mbn` 是**测试根签名**（SECTOOLS SECP384R1 CURVE TEST ROOT），生产 TZ 以 `0x300045` 拒；Android 实载 **modem 分区 OEM 签名副本** `/vendor/firmware_mnt/image/gen80900_zap.mbn`。换 OEM 签名后 **mainline PAS init 成功、不需 QTEE listener**。⇒ GPU/ADSP 固件从 `firmware_mnt` 取 |

### 3.3 Kaanapali（= SM8750 平台代号）DT 在动 —— 板 DTS 跟随项

- 10-21 `[PATCH v2] kaanapali: Add memory-region for audio PD`（Ekansh Gupta）：ADSP 音频 PD `memory-region` 进树 ⇒ 板 DTS 音频/ADSP 节点需跟随（同 `PITFALLS #186`）。
- 10-20 `[PATCH v1] kaanapali: Split cluster power domains`（Konrad 问 → Abel 回）：集群 PD 拆分 = CPU idle/suspend 的上游形状（关联 T9）。
- 10-21 `[PATCH v2 1/6] glymur: Add CAMSS and CSIPHY nodes` + `5/6 ov08x40 on CSIPHY4`（Konrad 逐条 review）：**M4-camss 的现成范式**，写板 DTS 前先对齐。

### 3.4 其它（记录，不必跟）

- `[PATCH v2 2/4] sm8750: Set snps,resume-hs-terminations for USB`（Peter Chen 10-18；Konrad/Abel 10-19 提意见）——**与 M3-1 同文件面**，v4 前必读。
- sm8750 videocc 时钟输入修正（Shawn Guo `v3 3/4`，10-17）——10-19 报告已记，**仍有效**。
- `[PATCH] drm/msm/adreno: Leave the GPU RSC awake for system poweroff`（Michael Burch；Konrad 10-21 14:12 质疑未做严格 A/B）：`d9108bfdb746`（stale rpmh votes）在 X1E80100 上**把 poweroff 变 reboot**，条件 = 关机时 GPU RSC/PDC 已睡 ⇒ 我们 reboot/poweroff 疑难（`uefi-restart-20261021.md`、`kexec-plan-20261021.md`）的**假设**（补丁未定论）。
- **Joonhoe Kim 同平台高产**：窗口内发 qrtr `-EAGAIN`、`qca` 蓝牙地址检查、`battmgr` ×2、`ufs` 死锁、`dsi` AHB —— **全命中我们模块面**。
- `msm/dpu`、`qca_suspend`：邮箱窗口内 **0 命中**（改走 lore，见 §7）。

---

## §4 分类③：噪声与已闭环项

窗口（16-Oct 起）INBOX **5 570 封**：单作者最多 **Konrad 434**、机器人 **sashiko 416**、单主题 ≤25 ⇒ **噪声是「宽度」不是「尖峰」**，「引用 mid 求交 → 关键词补扫」足够，**不需读全量**。

**已闭环（与前档一致，不重复论证，只记证据）**：Krzysztof 的 v1 binding 两条否决与 lkp `mux_role` —— v2 撤 `usb-psy-name`+重写 `usb-role-switch`、v3 删 `port@2`、v2 起删 `mux_role`，窗口内 `From: krzk` / `lkp@intel.com` 引用我方 mid = **0**；`postmaster@qualcomm.com` 退信 —— 旧址 `quic_tdas@quicinc.com` 满，现用 `taniya.das@oss.qualcomm.com` 且她本人已回，窗口内无新退信；我方已撤稿的 DPU GC-block + P3 gamma LUT —— sashiko 未再提，P3 **仍 0 人类回复（14 天）**；libcamera 两枚 —— 无新回复，硬门不变（sensor 驱动须先上游化 `<179225268473…>`、AGC 须 rebase master `<75e177a5-…>`）。

---

## §5 订阅状态核对（以实际收信为证据）

**★ 最重要更正**：`mail-lists-subscription-20261013.md` 把 linux-clk 写成「建议尽快订」、devicetree 写成「不要订阅」；**两者 10-13 就订上了**。核对面 = IMAP 全库 `SUBJECT "Welcome to"`（生效）+ `SUBJECT "confirm"`（触发）双向配对：

| 列表 | `Welcome to`（= 生效） | `Confirm subscription`（触发） | 我方确认（Sent） | 判定 |
|---|---|---|---|---|
| **linux-arm-msm@vger** | **10-12 08:16Z** | 10-12 08:15Z | 10-12 16:16 CST `Re: Confirm…` | 已订〔已证实〕 |
| **linux-pm@vger** | **10-13 00:09Z** | 10-13 00:09Z | 10-13 08:09 CST | 已订〔已证实〕 |
| **linux-input@vger** | **10-13 00:08Z** | 10-13 00:08Z | 10-13 08:08 CST | 已订〔已证实〕 |
| **linux-clk@vger** | **10-13 02:21Z** | 10-13 02:15Z | 10-13 10:21 CST `confirm` | 已订〔已证实〕（档案「建议尽快订」过期） |
| **devicetree@vger** | **10-13 03:00Z** | 10-13 02:49Z | 10-13 11:00 CST | 已订〔已证实〕（档案「不要订」被推翻） |
| **libcamera-devel** | **10-17 17:35 +0200** | 10-17 17:33 +0200（两 token） | 10-17 23:35 CST `confirm 5c7937…` | 已订〔已证实〕 |

### 5.1 实收量（`SINCE 16-Oct`，按 `List-Id` 统计 INBOX）

| List-Id | 封数 | 占 INBOX | 备注 |
|---|---|---|---|
| `devicetree.vger.kernel.org` | **3 191** | **54%** | 最大成本项，已订 |
| `linux-arm-msm.vger.kernel.org` | **1 380** | 24% | 主战场，保留 |
| `linux-input` / `linux-pm` / `linux-clk` | **462 / 429 / 307** | 21% | 触觉（前期用处有限）/ battmgr+CX / Q24 线 |
| `libcamera-devel` | 61 + **116 在 Junk** | ~1% | **★ 66% 判垃圾**（含 confirm）⇒ 不查 Junk 会「以为没订」 |
| `lkml` / `dri-devel` / `linux-usb` / `linux-media` | **0** | 0% | **确实未订**（收到的只是被 Cc 的个人副本） |

---

## §6 建议现在订阅的列表 + 可直接发送的正文

> 前提：已订 6 个、实测 ≈ **1 090 封/日**。故**不再加大列表**，只加「小而准、且正卡住我方线程」的。**本 worker 一封未发**；以下正文需**用户批准**。

| # | 动作 | 列表 | 机制 | 理由 | 成本 |
|---|---|---|---|---|---|
| **A1** | **减负：退订 devicetree**（或 digest） | `devicetree@vger.kernel.org` | vger `+unsubscribe` | 实测 **3 191 封/54%**；自己 binding 的 review **被 Cc 就能收**（M3-1 副本已进箱=实证） | **−约 400/日**〔已证实量级〕 |
| **A2** | 新订 linux-usb | `linux-usb@vger.kernel.org` | vger `+subscribe` | M3-1 **v3 在 Greg 队列**（§2.3），非订户看不到后续 review | 〔推测〕20–60/日 |
| **A3** | 新订 linux-remoteproc | `linux-remoteproc@vger.kernel.org` | vger `+subscribe` | ADSP/CDSP + `qcom_q6v5_pas` = G1 主线（10-21 Konrad 仍 review q6v5 64-bit 截断） | 〔推测〕5–15/日 |
| — | **暂不订** dri-devel | `dri-devel@lists.freedesktop.org` | **freedesktop Mailman 表单**（`+subscribe@vger` 无效） | M1 那枚 0 回复，等有人回再订 | 〔推测〕100–250/日 |
| — | 不订 LKML/media/wireless | — | — | 维持 10-13 结论（`List-Id`=0） | 0 |

`A2` 正文：
```
To: linux-usb+subscribe@vger.kernel.org
Subject: subscribe

subscribe
```
`A3` 正文：
```
To: linux-remoteproc+subscribe@vger.kernel.org
Subject: subscribe

subscribe
```
`A1` 若要减负：同格式把收件人换成 **`devicetree+unsubscribe@vger.kernel.org`**（正文 `unsubscribe`）。

发后（SKILL §3）：回 `Confirm subscription to …` 的 Reply-To（`<list>+confsub-<token>-xiaqinghuan=mail.ustc.edu.cn@vger.kernel.org`）任意内容 → **收到 `Welcome to <list>@vger.kernel.org` 才算成功**，**Junk 也要查**（libcamera 教训）。发信 `send-mail-ustc.py <file>`（先 dry-run 核头，再 `--send`，**需用户批准**）；dry-run 的 Message-ID ≠ 实发 id（坑 #10）。

---

## §7 本周「只追踪不订阅」的 lore 查询命令（各 1 条）

```bash
# ① sm8750 全域（10-21 实测有效；最新命中 = Konrad 10-21 08:48Z battmgr 回复）
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-arm-msm/?q=s%3Asm8750"
# ② camcc（Q24）
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-clk/?q=s%3Acamcc"
# ③ msm/dpu（M2-P3 gamma LUT / DPU 校验路径）
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/dri-devel/?q=s%3A%22msm%2Fdpu%22"
# ④ qca_suspend / hci_qca（邮箱窗口内 0 命中，故转 lore）
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-bluetooth/?q=s%3Aqca_suspend"
```
路径别猜：devicetree = `/linux-devicetree/`、lkml = `/lkml/`（SKILL 坑 #1）。

**本次已做 3 次复核**：① M1 → `/linux-arm-msm/` 已归档、0 回复；② M3-1 v3 0/2 → `/linux-usb/` 已归档，`In-Reply-To` 正确指 v2 cover（线程未断）；③ `s:sm8750` 最新三条 = Konrad battmgr（10-21）、我方 T5（10-20 11:02Z）、Konrad Q24（10-20 07:37Z）⇒ **与邮箱对得上，无漏收**。

---

## §8 风险：订阅后的流量影响

| 项 | 数字 / 判断 | 级别 |
|---|---|---|
| 现状基线 | `SINCE 16-Oct` INBOX **5 860 封**（≈**1 090/日**），6 个已订列表占 **99.5%** | 〔已证实〕 |
| 加 A2+A3 | **+25～75/日**（+3～7%） | 〔推测〕 |
| 若加 dri-devel | **+100～250/日**（与 arm-msm **双投**＝同线程两遍） | 〔推测〕 |
| 退订 devicetree | **−约 400 封/日（−37%）**；风险＝失去「别人改 binding 提前知道」，但**被 Cc 仍收自己线程** | 收益〔已证实〕/风险〔推测〕 |
| 垃圾过滤 | `libcamera-devel` **66% 落 Junk**（含 confirm）⇒「订了却以为没订」或漏真回复 | 〔已证实〕 |
| 可读性 / 不要做 | 人工翻邮件已不可行，必须维持「引用 mid 求交 + 关键词补扫」（23 s 扫 8 886 头）；不把 lkml/media 加进同一邮箱，不为分流再建第二邮箱 | 〔已证实方法有效〕 |

---

## §9 结论与待用户决定项

〔已证实〕**T5 已交件、Taniya 0 回复**（Q24 唯一新人类发言 = Konrad 10-20 单变量建议，**vk64 台架未跑**）；**M1 已投 + 已归档 + 0 回复**（`TASKS/README §7`「冻结/未发送」需回填）；**M3-1 v3 = 1 High（吞 `-EPROBE_DEFER`）+ 2 Medium + 1 Low**，Greg 是 bot「等 -rc1」⇒ **不急发 v4**；订阅 = arm-msm/pm/input/clk/**devicetree**/libcamera-devel，`dri-devel`/`linux-usb`/`lkml`/`media` 未订。

**待用户决定**
- **D1（唯一「对方在等」）**：回 Konrad battmgr 澄清（`<5bf3636d-…>`）？建议**回**，只改 commit message 用词（主机侧 10 分钟）。
- **D2** 是否 **A1 退订 devicetree**（−37% 流量）｜**D3** 是否新订 **linux-usb + linux-remoteproc**（§6 正文可用）。
- **D4**：M3-1 v3 的 1 High + 2 Medium 现在改，还是等 `-rc1` 出 v4｜**D5**：Joonhoe 是否回（建议不回）。

**边界**：未发任何邮件/订阅；未改 `.gitconfig`/凭据；未碰设备；未 commit；本报告仍是孤儿（`TASKS/README` 指针待编排者补）。
