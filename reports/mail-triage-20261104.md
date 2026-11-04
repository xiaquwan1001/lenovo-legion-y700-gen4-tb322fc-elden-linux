# 上游邮件重分诊 — 2026-11-04（A3 · 只读增量复核）

> 派工单：A3 上游邮件重分诊（**只读**）。**本轮未发任何邮件、未删信、未改订阅、未碰 patchwork、未访问设备、未改仓库既有文件、未 `git commit`。**
> 上一份全量分诊：`reports/mail-triage-20261102.md`（窗口止 **2026-11-02 03:57Z**）；此后仅有 UEFI 专项 `reports/uefi-mail-triage-20261103.md`。
> 本轮结论：**「各系列 0 条新意见」已失效** —— 增量窗内 **12 条外部回信 + 6 封退信**，其中 **2 条是维护者对我方系列的否决/丢弃动作**（dwc3）、**1 条是「请重发、apply 不上」**（wl2868c v5）。

---

## §0 口径与窗口

| 项 | 值 |
|---|---|
| 通道 | IMAP `mail.ustc.edu.cn:993`（口令仅从 GNOME keyring `secret-tool lookup service smtp` 取，未写入任何文件/日志） |
| 文件夹 | `INBOX` / `Junk E-mail` / `Sent Items` |
| 只读实现 | `SELECT ... (readonly=True)`（IMAP EXAMINE）+ `BODY.PEEK[HEADER.FIELDS ...]` / `BODY.PEEK[]`。**无 STORE / COPY / EXPUNGE / MOVE / 无 `\Seen` 写入**。`FETCH (FLAGS)` 只读回读 |
| 增量窗 | **起点 2026-11-02 03:57Z（上一份分诊的止点）→ 终点 2026-11-04 02:12Z（抓取时刻，UTC）** |
| 抓取窗 | IMAP `SINCE 01-Nov-2026`（服务端按本地日期 CST 切，实际带出 10-31 16:11Z 起）⇒ **共 2411 封**：`INBOX 2333` / `Junk E-mail 63` / `Sent Items 15`；实际日期跨度 `2026-10-31 16:11:30Z .. 2026-11-04 02:09:53Z` |
| 兜底窗 | `SINCE 25-Oct-2026` 的 `HEADER References "mail.ustc.edu.cn"` + `HEADER In-Reply-To "mail.ustc.edu.cn"` 服务端搜索（INBOX + Junk）⇒ **188 封**（去重后，全部落在 INBOX，1 封另在 Junk 有副本） |
| Sent 基线 | `Sent Items` `SINCE 25-Oct-2026` ⇒ **98 封**（我方投递全表；**最后一封 = 2026-11-02 06:06:03Z**，此后我方无任何外发） |
| 脚本 | `/tmp/eld-mailhdr-1104.py`（信头表）、`/tmp/eld-body-1104.py`（正文）、`/tmp/eld-reply-1104.py`（去引用正文）、`/tmp/eld-search-1104.py`（References/IRT 兜底）。**全部在 `/tmp`，仓库零污染** |
| 判定口径 | 「与我方有关」= `References`/`In-Reply-To` 命中我方 110 个 Message-ID 之一（Sent 全表 98 + `patches/**` 与 `out/**/*.eml` 头部 12），或主题命中系列关键词 |
| 未证口径 | 凡未取得信件正文/可复现证据的，写「未证」，不猜 |

**重要口径修正（影响上一份报告的可信度排序）**：

1. **`\Seen` 不能用来判断「我方是否看到」**：本邮箱 `UNSEEN 12149 / MESSAGES 12289`，几乎所有近期邮件都无 `\Seen`；本轮 12 条新外部回信**全部无 `\Seen`**（FLAGS 为空）。故本报告一律以「是否已被报告记录」为「未见」判据。
2. **lore 归档本轮无法核对**：`lore.kernel.org` 现被 Anubis JS 挑战拦截，`/<list>/<mid>/raw` 一律返回 **HTTP 200 + 7712 B 的挑战页 HTML**（不是信件本体，`grep 'Making sure you.re not a bot'` 命中）。上一份报告用的 `/raw 200` 判据**在本轮环境下会假阳性**，故 §3 归档列全部标「未证」。
3. `linux-regulator@vger.kernel.org` **不是有效列表地址**（见 §1d），本地 `linux/MAINTAINERS:28913-28925`「VOLTAGE AND CURRENT REGULATOR FRAMEWORK」只有 `L: linux-kernel@vger.kernel.org`，全树无 `linux-regulator` 字样。

---

## §1 四问逐条回答

### a) 已投系列在 11-02 03:57Z 之后有没有新 review/reply/Reviewed-by/Acked-by/Tested-by

**有。12 条独立外部回信（24 封副本，多数一封在 INBOX 有两个序号 = 列表 + 直达各一份），覆盖 6 个系列。**

| # | 何时(UTC) | 谁 | 系列 | 性质 | Message-ID | 副本 |
|---|---|---|---|---|---|---|
| 1 | **11-02 04:49:40** | **Krishna Kurapati** | **M3-1 dwc3 v5 0/2** | **程序性反对**：*"If v5 is being sent, it must not to be applied on top of v4. It must include (v4 + any additional changes/improvements)."* | `<ba544091-1da4-4616-b1d5-fe23f32679d9@oss.qualcomm.com>` | INBOX 10335/10336 + Junk 256 |
| 2 | 11-02 06:13:21 | sashiko-bot | wl2868c v5 **2/4**（driver） | 1 条 **Medium**：SYS_EN 未置位时其他 LDO 的 preset 位仍为 1，`wl2868c_enable()` 只 `regmap_update_bits` ⇒ **顺带点亮别的 LDO** | `<sashiko-outbox-192941@kernel.org>` | INBOX 10367 |
| 3 | 11-02 06:19:55 | sashiko-bot | wl2868c v5 **4/4**（elden 板 DTS） | **2 Medium + 1 Low**：①`giantec,gt9764`/`samsung,s5kjns` 未进树内 schema + endpoint 无 remote-endpoint；②新板 DT 缺 boot 基础设施（SPMI/RPMh/console/存储，父 supply 全是 dummy）；③`arm/qcom.yaml` 改动应与 dt-bindings 拆分 | `<sashiko-outbox-192949@kernel.org>` | INBOX 10368 |
| 4 | 11-02 06:19:56 | sashiko-bot | wl2868c v5 **3/4**（sm8750 CCI） | **2 Medium**：①`cci2` 被省掉——CCI 由 `i2c-qcom-cci` 独立 bind，且 sm8550/sm8650 都描述全 3 个；②`sleep` 状态把 function 改成 `gpio`，而既有 SoC 是保留 `cci_i2c_sda/scl` 只改 bias | `<sashiko-outbox-192950@kernel.org>` | INBOX 10369 |
| 5 | **11-02 08:07:28** | **Krzysztof Kozlowski** | **M3-1 dwc3 v5 1/2（重投那封）** | **否决 + 流程**：*"I don't see how any of above is useful in git log. Anyway, this is misthreaded - missing rest of patchset. Please read submitting patches document and switch to b4…"* | `<20261102-armored-arcane-serval-43faf4@quoll>` | INBOX 10424/10425/10426 |
| 6 | **11-02 08:13:26** | **Krzysztof Kozlowski** | **M3-1 dwc3 v4 1/3** | **丢弃**：*"Unanswered Sashiko comments plus some confusion with duplicated posting of v5 without the rest, **dropping**."* | `<20261102-screeching-utopian-avocet-492500@quoll>` | INBOX 10428/10429/10430 |
| 7 | 11-02 08:59:35 | **Konrad Dybcio** | wl2868c v5 **4/4** | 质疑板 DTS 里为何重复 bindings 例子里的内容：*"What's the reason for including it here then? You already gave us the meaningful part of this as an example in dt-bindings"*（指 board clocks 段） | `<dddc808a-6407-4db1-aa72-0ebe5652f97c@oss.qualcomm.com>` | INBOX 10460/10461 |
| 8 | 11-02 09:00:17 | **Konrad Dybcio** | wl2868c v5 **3/4** | **撞车警告**：*"There's an identical patchset in flight, please don't send competing series without a clear reason"* → 指向 Hangxiang Ma 的 CCI 系列 `<20260618-pakala-camera-v2-2-9fbb729fd242@oss.qualcomm.com>` | `<c1e1f708-86a4-45a5-921b-fb8a74a827d4@oss.qualcomm.com>` | INBOX 10462/10463 |
| 9 | **11-02 09:22:10** | **Loic Poulain** | **M4 camss v2 2/2**（+ 挂在 three-fixes 线程） | **正面**：*"So the patch looks better now… the change looks good to me, but I'll leave it to Bryan to decide whether we should merge it as-is or address that future use case now."*（提出 `media_entity_remote_source_pad_unique()` 在多源 link 时的限制，属未来 pixel-path 议题） | `<CAFEp6-2PjOg6wJ5SotsdGkkOvqeDHLbZo8w9s746LgfJTnpfvw@mail.gmail.com>` | INBOX 10478/10483 |
| 10 | **11-02 12:50:05** | **Mark Brown** | **wl2868c v5 0/4** | **拒收（apply 失败）**：*"This doesn't apply against current code, please check and resend."* | `<0b7aa07e-7771-4ae1-ab0b-0d6e692706d6@sirena.org.uk>` | INBOX 10673/10686 |
| 11 | **11-02 13:17:55** | **Abel Vesa** | **M8 mdss v3 3/3** | **Reviewed-by: Abel Vesa**（正向，收） | `<buaeo5m3ozihgl5t6767jvu72umwbzqx2debegmzvkuigwwqki@zbtoarlnnihe>` | INBOX 10703/10751 |
| 12 | **11-02 19:52:37** | **Conor Dooley** | wl2868c **v4 1/4**（binding） | **changes-requested**：①「板级 supply 段落」与 wl2868c binding 无关；②`arm/qcom.yaml` 改动必须拆出去；③输入 supply 没设 required 的假设被质疑；④**漏了 `vsys`**，至少 `vin7` 与 `vsys` 之一强制（"the higher of the two powers the internal control logic"）；带 `pw-bot: changes-requested` | `<20261102-hedge-parchment-da1dbb0b60be@spud>` | INBOX 11267/11270 |

**逐系列「有/无」判定**

| 系列（本轮派工单点名） | 有新意见? | 证据 |
|---|---|---|
| **M3-1 dwc3 v5（0/2 + 1/2 重投）** | **有，2 条，都是坏消息** | Krishna 11-02 04:49:40Z（`<ba544091…>`）+ Krzysztof 11-02 08:07:28Z（`<20261102-armored-arcane-serval-43faf4@quoll>`）；**v4 1/3 另被 Krzysztof 明确 dropping**（11-02 08:13:26Z，`<20261102-screeching-utopian-avocet-492500@quoll>`） |
| **M4 camss v2 0/2** | **有 1 条（技术面正面）** | Loic 11-02 09:22:10Z `<CAFEp6-2…@mail.gmail.com>`，评的是 **v2 2/2**，落在 three-fixes 线程；**v2 0/2 cover 与 1/2 仍无人评** |
| **M4 camss three-fixes（0/3）** | 无新 | 该线程最后外部来信仍是 10-29 13:01/14:02/15:00Z（Loic/Bryan）；11-02 的那封 Loic 属 v2 线程（References 同时含 `20261029123107.28705-1` 与 `20261031041154.308030-1/-3`） |
| **M8 mdss v3 0/3** | **有 1 条（Reviewed-by，正向）** | Abel Vesa 11-02 13:17:55Z `<buaeo5m3…>` 只给 **3/3（sm8750 DTS）**；**1/3 binding 与 2/3 driver 无任何回信** |
| **wl2868c v5 0/4** | **有 7 条**（6 sashiko/Konrad/Mark + Conor 落在 v4 1/4 线程） | sashiko ×3（06:13:21 / 06:19:55 / 06:19:56）、Konrad ×2（08:59:35 / 09:00:17）、Mark Brown（12:50:05）、Conor（19:52:37，v4 1/4 线程） |
| **wl2868c v4（旧线）** | **有 1 条** | Conor 11-02 19:52:37Z `<20261102-hedge-parchment-da1dbb0b60be@spud>`（changes-requested） |
| **M2 A2 battmgr** | **无** | 我方 Sent[191] 10-28 11:57:57Z 之后，References/IRT 里无任何外部回信；11-02 11:41Z Abel 新发的 `power: supply: qcom_battmgr: Fix pmic_glink client use-after-free on unbind`（`<20261102-battmgr-client-teardown-uaf-v1-1-972fc5a5e0c9@oss.qualcomm.com>`，INBOX 10621）是**同文件的另一处修复**，不是对我方 A2 的评论 |
| **M6 B5 0/5** | **无新** | 我方 Sent[234] 11-02 05:40:54Z 回完 Dmitry 四条后，**Dmitry 没有新回信**；窗口内最后一条 Dmitry 仍是 10-31 20:31Z |
| **M1-U6 q6v5_pas** | **无** | 10-27 投递后线程里 0 条外部回信（含 25-Oct 兜底窗） |
| **aw86927 5 枚** | **无**（详见 c） | 见 §1c |
| **M4-1 gt9764 / s5kjns bindings** | **无** | 最后外部来信 = Krzysztof 10-28 13:29:34Z（GT9764，INBOX 8270）+ 13:31:24Z（S5KJNS，INBOX 8276）+ sashiko 10-27 05:19:59Z（INBOX 7145）；11-02 03:57Z 之后 **0 条**（`SINCE 25-Oct` 兜底窗亦无） |

---

### b) 有没有维护者回了但我方可能没看到的

**兜底搜索：`SINCE 25-Oct-2026` + `HEADER References/In-Reply-To "mail.ustc.edu.cn"` ⇒ 188 封（INBOX 187 + Junk 1 副本），逐封比对后：**

- **188 封里没有一封是「没进 INBOX 的」**：除 Krishna 那封另有 Junk 副本（Junk 256）外，全部已投递到 INBOX。
- **窗口内（11-02 03:57Z 之后）与我方有关的外部来信 = 12 条（§1a 全表）**，其中 **4 条落在上一份报告完全没覆盖的系列上**（dwc3 的两条否决、wl2868c v5 的 Mark/Abel/Conor 组合），说明「基线之后 0 条」的时效性确已失效。
- **上界之外的相邻项**：10-30 15:02:26Z Konrad 有一封 `Re: [PATCH v2 1/3] dt-bindings: display: msm: mdss-common…`（INBOX 9534/9535），早于上一份分诊止点但**未见于上一份报告**（上一份只记了 Dmitry 10-31 的两条 mdss 意见）—— 记为**基线漏记**，非本轮新增。
- **没有发现「只进 Junk、未进 INBOX」的维护者回信**；Junk 63 封里只有 Krishna 那 1 封与本项目相关，其余是 GitHub 通知与 libcamera 流水。

**结论**：不存在「维护者回了但我方信里根本收不到」的情况；失配点在**处理端**（12 条新回信全部无 `\Seen` 且未被任何报告记录）。

---

### c) aw86927 线程 10-27 之后有没有新意见

**没有。** 逐条证据：

| 时间(UTC) | 事件 | 证据 |
|---|---|---|
| 10-27 13:37:25 | sashiko 对 4/5 的 Medium（两条同名副本） | INBOX 7494 / 7504 |
| 10-27 13:55:45 | sashiko 对 5/5 的 Medium | INBOX 7506 / 7512 |
| 10-27 18:06:02 | **Krzysztof** 对 2/5（binding）的答复（含 Acked-by 2/5 与要求） | INBOX 7688 / 7694 |
| **10-27 18:06:02 之后** | **0 条** | `SINCE 01-Nov-2026` 全窗（2411 封）里 `aw86927`/`awinic` 命中仅 1 条 = **别人**的 `[PATCH v3 0/2] Input: Add Awinic AW8697 haptics driver`（11-02 22:04:15Z，INBOX 11332，不同芯片）；`SINCE 25-Oct-2026` 兜底窗里 aw86927 相关最后一封仍是 10-27 |

**⇒ 直接结论：aw86927 若出 v3，不需要并入任何 10-27 之后的新反馈。** 仍需并入的只有 10-27 那轮的既有意见（Krzysztof 对 2/5 的要求 + sashiko 对 4/5、5/5 的两条 Medium + 我方 1/5 的 `Fixes:` 标签本地核对问题）。

---

### d) 新退信（DSN）/ 订阅确认 / 列表拒信

**有，6 封 `postmaster@mail.ustc.edu.cn` 退信，全部同因、全部指向 wl2868c v5 那一批（11-02 06:05:12–06:06:09Z）。**

| seq | 时间(UTC) | 被弹收件人 | 状态/诊断 | 原信 Message-ID |
|---|---|---|---|---|
| INBOX 10354 | 11-02 06:05:12 | `linux-regulator@vger.kernel.org` | `550 5.1.1 … User unknown in virtual alias table` | `<20261102060458.461372-2-…>`（v5 1/4） |
| INBOX 10355 | 11-02 06:05:14 | 同上 | 同上 | `<20261102060458.461372-1-…>`（v5 0/4 cover） |
| INBOX 10356 | 11-02 06:05:21 | 同上 | 同上 | `<20261102060458.461372-3-…>`（v5 2/4） |
| INBOX 10357 | 11-02 06:05:23 | 同上 | 同上 | `<20261102060458.461372-4-…>`（v5 3/4） |
| INBOX 10358 | 11-02 06:05:25 | 同上 | 同上 | `<20261102060458.461372-5-…>`（v5 4/4） |
| INBOX 10360 | 11-02 06:06:09 | 同上 | 同上 | `<179359956355.462429…>`（回 Mark Brown 那封） |

- **地址确实错**：`linux/MAINTAINERS:28913-28925`「VOLTAGE AND CURRENT REGULATOR FRAMEWORK」的列表只有 `L: linux-kernel@vger.kernel.org`；全树 `grep -rn linux-regulator linux/MAINTAINERS linux/Documentation` **零命中**。⇒ 该 vger 列表不存在，regulator 补丁应发 **LKML**（+ 维护者 Cc）。
- **这是我方第二次踩同类错**：上一轮是 `linux-devicetree@vger.kernel.org`（v5 dwc3，本次复查的 `postmaster` 全表里 10-31 23:02 三封仍在，INBOX 9895/9896/9897）。**两处都不影响维护者本人收到**（Liam/Mark/Konrad/Rob/Conor 都在 Cc），只影响列表归档。
- **另一类（历史，早于本轮窗口）**：`mturquette@baylibre.com` 两封 550（10-29 01:06Z INBOX 8427、10-30 01:39Z INBOX 9042），是我方 dispcc RFC 抄送的旧地址；与本轮无关，归入地址纪律。
- **订阅确认 / vger 其它 550 / 列表拒信**：**0 条**（窗口内 `postmaster`/`mailer-daemon`/`subscribe`/`confirm` 全扫，除上述 6 封外无命中）。
- **一处需要用户本人确认的非邮件列表事项**：`Junk E-mail 294`，11-02 15:14:01Z，`GitHub <noreply@github.com>`「[GitHub] **A third-party OAuth application has been added to your account**」。属账号安全告警，不在本任务授权范围（不点链接、不改设置），**只上报**。

---

## §2 Sent Items 交叉核对（`out/mail-*` 的 Message-ID 是否真在 Sent 里）

`Sent Items SINCE 25-Oct-2026` 全表 **98 封**，逐一比对（抽查 + 全表反查）：

| 批次 | 抽查 Message-ID | 在 Sent? | 发出时间(UTC) |
|---|---|---|---|
| **M3-1 dwc3 v5 0/2 cover** | `<20261031150154.1106455-1-xiaqinghuan@mail.ustc.edu.cn>` | ✅ | 10-31 15:01:52Z（Sent[224]） |
| **M3-1 dwc3 v5 1/2 重投** | `<179359806935.413510.7108025505776923330@mail.ustc.edu.cn>` | ✅ | 11-02 05:41:09Z（Sent[235]） |
| **M8 mdss v3 0/3 cover** | `<20261102055026.438521-1-xiaqinghuan@mail.ustc.edu.cn>` | ✅ | 11-02 05:50:23Z（Sent[236]） |
| **M8 mdss v3 3/3** | `<20261102055026.438521-4-xiaqinghuan@mail.ustc.edu.cn>` | ✅ | 11-02 05:50:26Z（Sent[239]） |
| **wl2868c v5 0/4 cover** | `<20261102060458.461372-1-xiaqinghuan@mail.ustc.edu.cn>` | ✅ | 11-02 06:04:54Z（Sent[242]） |
| **wl2868c v5 1/4** | `<20261102060458.461372-2-xiaqinghuan@mail.ustc.edu.cn>` | ✅ | 11-02 06:04:55Z（Sent[243]） |
| **M4 camss v2 0/2 cover** | `<20261031041154.308030-1-xiaqinghuan@mail.ustc.edu.cn>` | ✅ | 10-31 04:11:52Z（Sent[212]） |
| **M4 camss v2 2/2** | `<20261031041154.308030-3-xiaqinghuan@mail.ustc.edu.cn>` | ✅ | 10-31 04:11:54Z（Sent[214]） |
| M4 camss three-fixes 0/3 | `<20261029123107.28705-1-xiaqinghuan@mail.ustc.edu.cn>`（Sent[199]） | ✅ | 10-29 12:31:04Z |
| M6 B5 0/5 + 回 Dmitry | `<20261031150305.1107572-1-…>`（Sent[227]）/ `<179359805420.413286.…>`（Sent[234]） | ✅ | 10-31 15:03:00Z / 11-02 05:40:54Z |
| aw86927 5 枚 | `<20261027132929.242158-1..6-…>`（Sent[161]–[166]） | ✅ | 10-27 13:29:24–29Z |
| M4-1 gt9764/s5kjns 0/2 | `<20261027051048.213177-1..3-…>`（Sent[156]–[158]） | ✅ | 10-27 05:10:46–48Z |

**观察**
1. 抽查 8 条 `out/mail-*` 批次 Message-ID **全部命中 Sent**，无「报告里有、实际没发」的情况。
2. **Sent 末条 = 11-02 06:06:03Z**（Sent[247]，回 Mark Brown 的 wl2868c v3 线程），此后至今 **零外发** ⇒ 所有 11-02 之后的维护者意见**都还没回**。
3. **`out/mail-*` 目录本身只覆盖到 `out/mail-20261102-{b5,m3dt,mdss,wl2868c}`**；11-02 的 dwc3 1/2 重投（Sent[235]）**在 `out/` 下没有对应目录**（本任务只读，未补）。

---

## §3 行动表

| # | 项 | 上游最新动作 | 我方欠什么 | 现在能做什么（不发信） | 需用户批? |
|---|---|---|---|---|---|
| **B1** | **M3-1 dwc3 v5/v4（最紧急）** | Krishna 11-02 04:49:40Z：v5 不能「叠在 v4 上」；Krzysztof 11-02 08:07:28Z：*misthreaded*、去读 submitting-patches、**改用 b4**；11-02 08:13:26Z：**v4 1/3 已 dropping** | **v6 = v4 1/3..3/3 全量 + v5 两个 fix 合并成一个完整、自洽、单线程的系列**；并换 b4 发送；回信正文不要写「resend 理由」进 commit log | 起草 v6 的 cover + 逐条 changelog（引 Krishna/Krzysztof 原话）；本地跑 `b4 send --dry-run` 验证线程形态 | **发信需批**（内容+线程形态） |
| **B2** | **wl2868c v5 → v6** | Mark Brown 11-02 12:50:05Z：**apply 不上，重发**；Conor 11-02 19:52:37Z（v4 1/4）：拆 `arm/qcom.yaml`、删无关段落、补 `vsys` 且 `vin7`/`vsys` 至少一个 required、说明 supply 为何非 mandatory；Konrad 11-02 08:59:35Z：板 DTS 里重复 clocks 段；sashiko 11-02 06:13/06:19：SYS_EN preset 位、cci2 缺失、sleep pinctrl 用 `gpio` 而非 `cci_i2c_sda/scl`、gt9764/s5kjns 未进树、板 DT 缺 boot 基础设施 | 6 条 patches 改动 + 1 条发送纪律（**列表地址改 LKML**）+ 重定 base 使其真能 apply | 逐条把意见落成 `patches/` 的 TODO（本轮只读，未改） | **改补丁需另派**；发信需批 |
| **B3** | **wl2868c 3/4 与第三方撞车** | Konrad 11-02 09:00:17Z：*identical patchset in flight*，指向 `<20260618-pakala-camera-v2-2-9fbb729fd242@oss.qualcomm.com>`（Hangxiang Ma 的 SM8750/Pakala CCI 系列，本窗口内其 v23/v24 仍在投） | **决策**：SM8750 CCI dtsi 是等对方先落还是改为不投、只留 board DTS 依赖 | 读对方最新版（邮件正文在 INBOX 10558 等）判断重叠范围 | **需用户定策**（是「让路」还是「给理由并行」） |
| **B4** | **M8 mdss v3** | Abel Vesa 11-02 13:17:55Z：**Reviewed-by 3/3** | 无需动作；等 1/3、2/3 有人看。若要 v4，只做累积 tag | 把 Reviewed-by 记进 `TASKS/README.md` §7 M8（仓库改动不在本任务授权内 ⇒ 只报告） | 否（**什么都不用做**） |
| **B5** | **M4 camss v2 2/2** | Loic 11-02 09:22:10Z：正面，把决定权交 Bryan | 等 Bryan；**不要 ping**（10-29 之后 Bryan 已看过 three-fixes） | 无 | 否（**什么都不用做**，只跟踪） |
| **B6** | **aw86927** | **10-27 18:06Z 之后 0 条新意见**（§1c） | 若出 v3：并 10-27 那轮意见即可，**不必等/不必并新反馈** | 无 | 否（**什么都不用做**） |
| **B7** | **M4-1 gt9764/s5kjns** | **10-28 13:31Z 之后 0 条** | Krzysztof 10-28 两封的意见仍待落（v2 未发） | 无 | 否（暂**什么都不用做**） |
| **B8** | **M6 B5** | 我方 11-02 05:40:54Z 已回完 Dmitry 四条；**7 天无回** | 无 | 无 | 否（**什么都不用做**，等） |
| **B9** | **M2 A2 battmgr / M1-U6 q6v5_pas** | 均 0 条新回信 | 无 | 无 | 否（**什么都不用做**） |
| **B10** | **地址纪律（第二次踩）** | 6 封 550 全指 `linux-regulator@vger.kernel.org`；本地 MAINTAINERS 该子系统列表 = `linux-kernel@vger.kernel.org` | 以后 regulator 补丁 **不写 linux-regulator@**；上一个坑 `linux-devicetree@` → `devicetree@` 同理；`mturquette@baylibre.com` 换现用地址 | 把两条正确地址写进 `TASKS/README.md` §7 发送清单（需授权） | **改文档需批**（发信已含在 B1/B2） |
| **B11** | **GitHub OAuth 告警** | Junk 294，11-02 15:14:01Z：第三方 OAuth 应用被加入账号 | 需**用户本人**核实是否为本人操作 | 无（不点链接） | **是，立即上报用户** |

**汇总**：必须动作 **2 项**（B1 dwc3 v6、B2 wl2868c v6）；需用户决策 **1 项**（B3 撞车让路）；需用户核实 **1 项**（B11）；**「什么都不用做」明写 6 项**（B4/B5/B6/B7/B8/B9）。

---

## §4 本轮未做 / 未证

1. **未发任何信**、未改订阅、未改 patchwork 状态、未 `git add/commit/checkout/clean`、未访问设备、未 `sudo`。
2. **未删信/未标已读**：全程 EXAMINE + BODY.PEEK；`\Seen` 状态零变更（12 条新信仍全部无 `\Seen`）。
3. **lore 归档与线程未核**：`lore.kernel.org` 现为 Anubis JS 挑战，`/<list>/<mid>/raw` 返回 200 但内容是挑战页（7712 B），**不能用状态码判定归档**。故「某系列是否已进 archive / 是否被 patchwork 收」本轮**全部未证**。
4. **patchwork 三态未重拉**（同上，且上一份报告记的 state 结论仍待复核）。
5. **Mark Brown「doesn't apply against current code」的具体冲突点未证**：未拿 v5 系列在 `linux` 树 / `linux-next` 上实跑 `git am`。合理怀疑与 Konrad 指出的「in-flight 的 SM8750 CCI 系列」（Hangxiang Ma v23/v24，本窗仍在投）在 `sm8750.dtsi` 上冲突，但**未验证**。
6. **Krzysztof「unanswered Sashiko comments」具体指哪几条未证**：只知 v4 1/3 线程里 sashiko 10-26 12:50:14Z 有意见（INBOX 6725），本轮未逐条比对是否已在 v5 1/2 里答复。
7. **未判定 `vsys` 是否真为 WL2868C 必需**：Conor 的原话是「我怀疑」；本地无该芯片数据手册，**未证**。
8. **`out/` 缺 dwc3 v5 1/2 重投（Sent[235]）的批次目录**：仅记录，未补（写仓库不在授权内）。
9. **未做的相邻核查**：issue #12 新评论（属 UEFI 专项）、`gh` 侧任何写操作。
10. **时区**：全部 UTC；原信为 `+0200`/`+0800`/`+0000`/`+0530` 的已换算。

---

## §5 复跑命令

```bash
# 0) 必须先在仓库根
cd /home/xuqianhui/y700-elden && git rev-parse --show-toplevel

# 1) 信头表（只读；输出 /tmp/eld-mailhdr-1104.json，2411 封）
python3 /tmp/eld-mailhdr-1104.py                  # SINCE 01-Nov-2026
# 2) Sent 全表（默认输出改成 ELD_OUT；ELD_FOLDERS 覆盖文件夹）
ELD_OUT=/tmp/eld-sent-25oct.json ELD_FOLDERS='Sent Items' python3 /tmp/eld-mailhdr-1104.py 25-Oct-2026
# 3) References/In-Reply-To 兜底（25-Oct 起，188 封）
python3 /tmp/eld-search-1104.py 25-Oct-2026
# 4) 正文 / 去引用正文
python3 /tmp/eld-body-1104.py  INBOX 10335 10424 10428 10673 11267 --max=2500
python3 /tmp/eld-reply-1104.py INBOX 10460 10462 10478 10621
# 5) 退信 DSN（被弹收件人 + 原信 Message-ID）
python3 - <<'EOF'   # 见 §1d 的循环；或直接 fetch INBOX 10354..10360 的 message/delivery-status
EOF
# 6) FLAGS 只读回读（证明未标已读）
python3 -c "import imaplib,subprocess;pw=subprocess.run(['secret-tool','lookup','service','smtp'],capture_output=True,text=True).stdout.strip();m=imaplib.IMAP4_SSL('mail.ustc.edu.cn',993);m.login('xiaqinghuan@mail.ustc.edu.cn',pw);m.select('INBOX',readonly=True);print(m.fetch('10424','(FLAGS)'))"
# 7) 地址正确性（本地证据，不依赖外网）
grep -n -A14 'VOLTAGE AND CURRENT REGULATOR FRAMEWORK' linux/MAINTAINERS
grep -rn 'linux-regulator\|linux-devicetree' linux/MAINTAINERS linux/Documentation | head
# 8) lore 现状（注意：200 + 7712B 挑战页 = 不可用）
curl -s --noproxy '*' -A 'Mozilla/5.0' -o /tmp/o.raw -w '%{http_code} %{size_download}\n' \
  "https://lore.kernel.org/linux-usb/20261031150154.1106455-1-xiaqinghuan@mail.ustc.edu.cn/raw"
grep -c 'not a bot' /tmp/o.raw
```

> 脚本全部在 `/tmp`（临时，可能被清）。仓库内本轮**只新增本文件**。

DONE-MAILTRIAGE
