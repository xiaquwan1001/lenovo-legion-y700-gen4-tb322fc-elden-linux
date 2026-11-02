# 上游邮件分诊 — 截至 2026-11-02 03:57Z（mail-io-update · 只读）

> 派工单：邮件状态更新到 2026-11-02（只读分诊，不发信）。
> **本轮未发任何邮件**、未改订阅、未改 patchwork 状态、未碰设备、未 `git commit`、未改任何 SSOT 文档。
> 已处理基线（不重复处理）：`reports/mail-triage-20261031b.md`、`reports/doc-mail-audit-20261101.md` §4。

---

## §0 口径与窗口

| 项 | 值 |
|---|---|
| 通道 | IMAP `mail.ustc.edu.cn:993`（口令走 GNOME keyring `smtp`，未落任何文件） |
| 文件夹 | `INBOX` / `"Junk E-mail"` / `"Sent Items"`（全部 `readonly=True` + `BODY.PEEK`，不置 `\Seen`） |
| 增量窗 | **2026-11-01 00:00Z → 2026-11-02 03:57Z**（IMAP `SINCE 01-Nov-2026`；服务端按本地日期切，实际多带出 10-31 后半段，正好覆盖基线漏记项） |
| 兜底窗 | `SINCE 25-Oct-2026` 的 `HEADER References "mail.ustc.edu.cn"` / `HEADER In-Reply-To "mail.ustc.edu.cn"` 服务端搜索（用于找「维护者已回但我方没看到」） |
| 拉取量 | 该窗 **397 封**（INBOX **380**、Junk **16**、Sent **1**）；Sent 那 1 封是无关的课程作业 |
| 工具 | `/tmp/eld-mailhdr-1102.py`（信头表）、`/tmp/eld-body-1102.py`（正文）、`/tmp/eld-dsn2-1102.py`（退信 DSN 解析）、`/tmp/eld-search-1102.py`（References 兜底）、`/tmp/eld-lore-1102.py`（lore 核对）。**全部在 `/tmp`，未污染仓库** |
| 相关判定 | ①`References`/`In-Reply-To` 含 `mail.ustc.edu.cn`；②主题/收件人命中本项目关键词；③退信看 DSN 里被弹的收件人与原信 Message-ID |
| lore 判据 | 归档 = `/<list>/<msgid>/raw` 取回 HTTP 200（逐封核，非「已发送」）；线程 = `/<list>/<msgid>/t/` 成员表 |

**与基线的口径偏差（必须先说）**：`out/mail-20261029/lore-probe.py` 走 `/all/<mid>/`，本轮 **8/8 全部返回 HTTP 300 Multiple Choices**
（同一 Message-ID 被多列表收录时 `/all` 无法选一个，脚本自身 docstring 已警告该坑）。因此本轮改用列表专属
`/<list>/<mid>/raw`，且**必须传完整 Message-ID**（只传 `2026…-1` 短号在 `/raw` 上取不到）。
`lore-probe.py` 本轮判据不可用 ≠ lore 没收录；改用新路径后 8/8 命中（见 §3）。

---

## §1 新信表（窗口内与本项目相关，去重后 **12 条事件 / 16 封邮件**）

> 重复投递说明：下列 #6–#11 每封在 INBOX 里都有**两个序号、同一 Message-ID**（列表 + 直达各一份），故 16 封 = 12 事件。

| # | 何时(UTC) | 谁 | 哪个系列 | 要点 | 基线是否已记 |
|---|---|---|---|---|---|
| 1 | **11-01 22:40** | **Mark Brown** `<aue_zSZqx_hsM7c2@sirena.org.uk>`（INBOX 16366 + 16373） | wl2868c（`Re: [PATCH v3 0/3]`，IRT = v3 cover `<20261031034300.272730-1>`） | **流程投诉**，非技术：*"Please don't send new patches in reply to old patches or serieses…"* —— 指我方 **v4 0/4 是用 `--in-reply-to` 挂在 v3 cover 下发的**（Sent 219 IRT = v3 cover），把新版本埋进旧线程 | ❌ 新（11-01 审计窗口止于 11-01 17:08 CST，此信在 11-02 06:40 CST） |
| 2 | 10-31 07:01 | sashiko-bot（INBOX 15930） | **wl2868c v4 1/4**（binding） | 1 条 **Low**：`qcom.yaml` 改动混进 wl2868c 提交 | ❌ 基线漏记（11-01 审计 §4 #5 写「sashiko 未再评新版本」，与事实不符） |
| 3 | 10-31 07:06 | sashiko-bot（INBOX 15931） | **wl2868c v4 4/4**（elden 板 DTS） | 3 条 **Medium**：①未文档化 camera/lens compatible + endpoint 未连；②新板 DT 缺 boot 基础设施（chassis-type 等）；③`cci0_i2c1`/`cci1_i2c1` 标 disabled 却仍 claim bus1 pinctrl | ❌ 基线漏记 |
| 4 | 10-31 07:10 | sashiko-bot（INBOX 15932） | **wl2868c v4 3/4**（sm8750 CCI） | **1 条 High（真 bug）+ 1 Medium + 1 Low**。High = `cci1_1_default/sleep` 用了 **gpio119/120**，而 gpio119/120 是 **cci2 bus1**，cci1 bus1 应为 **gpio111(SDA)/gpio164(SCL)**；Medium = `cci*_i2c1` disabled 但父节点已 claim 引脚；Low = tlmm 子节点未按字母序 | ❌ 基线漏记 |
| 5 | 10-31 15:02 | **postmaster@mail.ustc.edu.cn** ×3（INBOX 16012/16013/16014） | **M3-1 dwc3 v5 0/2 + 1/2 + 2/2** | 三封同因：`550 5.1.1 <linux-devicetree@vger.kernel.org>: Recipient address rejected: User unknown in virtual alias table`。**地址写错**——vger 的 DT 列表是 `devicetree@vger.kernel.org`，没有 `linux-devicetree@`。其余收件人全部接收 | ❌ 新 |
| 6 | 10-31 20:21 | **Dmitry Baryshkov**（INBOX 16123+16124） | **M6 B5 0/5**（`[PATCH 0/5] drm/msm/dsi: collect bonded command-path data…`） | 反对「无理由重构」：*"I'd prefer to see the reason for the changes. **The bonded DSI is seemingly working today.**"* | ❌ 基线漏记（11-01 审计 §4 #5 写「M6 B5 无维护者新回信」） |
| 7 | 10-31 20:24 | Dmitry（16125+16126） | **B5 1/5**（flag 进 manager state） | ①若 flag 已挪进 `msm_dsim_glb`，`dsi_bonded_cmd_lock` 也该一起去；②block comment 格式不合规范；③**"what is your base kernel? I don't see these definitions"** —— apply 不上 | ❌ 基线漏记 |
| 8 | 10-31 20:27 | Dmitry（16127+16128） | **B5 2/5**（per-SoC bonded cfg） | 两问：*"Do they differ from platform to platform?"* / *"What happens on the other platforms?"* | ❌ 基线漏记 |
| 9 | 10-31 20:31 | Dmitry（16129+16130） | **B5 4/5**（master 取自 per-SoC cfg） | **事实纠错**：*"IDs are not assigned by the probe order. Master is also assigned via the DT."* | ❌ 基线漏记 |
| 10 | 10-31 21:47 | Dmitry（16141+16142） | **M8 mdss v2 2/3**（`msm_mdss_reset()`） | 删掉 `msm_mdss_reset()` 上方新加的长注释（「AI 喜欢写长注释」那一条）；未反对 `devm_reset_control_array_get` 本身 | ✅ 已记（11-01 审计 §4 #1） |
| 11 | 10-31 21:48 | Dmitry（16143+16144） | **M8 mdss v2 3/3**（sm8750 DTS） | *"Please drop the RSCC reset"* | ✅ 已记（11-01 审计 §4 #2） |
| 12 | 10-31 05:27 | **postmaster@qualcomm.com**（Junk 405） | 我方 **Sent[216]**（`Re: [PATCH v2 1/3] dt-bindings: … mdss-common …`，10-31 05:27Z 发出） | **弹的是两个 quic 地址**：`quic_jesszhan@quicinc.com`（Jessica Zhang）、`quic_abhinavk@quicinc.com`（Abhinav Kumar），均 `550 5.1.10 RESOLVER.ADR.RecipientNotFound`；其余收件人成功 | ✅ 已记「需人工核实」，本轮**核到确切地址**（见 §2 A6） |

### 明确排除（不进表）

- **INBOX 380 封里的其余 ~360 封** = 他方列表流水（iio/HID/Rockchip/camss Glymur/Qualcomm qda v4 25 枚/spi 等），与本项目无投递关系。
- **Junk 16 封**：除 #12 外全为 libcamera 大流量（v0.8.0 发布、software_ISP AF、IPU6 mono），非我方面。
- **Sent Items 1 封** = 「图形学作业4」，无关。
- **我方自发自收回环**：INBOX 16015–16030（dwc3 v5 / B5 六封的 INBOX 副本）等，按基线口径排除。

---

## §2 行动表（谁做什么）

| # | 谁 | 做什么 | 是否必须回 | 回信要点（≤3 行） | 截止暗示 |
|---|---|---|---|---|---|
| **A1** | 人工撰稿（mail-io 不得代写正文）→ 总管批 → 投递 | **wl2868c：答 Mark Brown 的流程投诉 + v5 改正发信方式** | **必须回（短文即可）** | ①承认 v4 用 `--in-reply-to` 挂在 v3 下是错的，v5 起每个版本新起线程；②同时把 v4 的三条 sashiko 意见（含 High 的 cci1_1 引脚）在 v5 里改掉；③不做多余解释、不辩解 | 无死线，但 v5 越早越好；7.4 merge window 已开（10-31 `[GIT PULL] power utilities update for Linux-7.4`），新版本自然排 7.5 |
| **A2** | mail-io 起草 → 人工核 → 批 | **M6 B5：回 Dmitry 四条** | **必须回（4 条都要逐条）** | ①正面给「为什么改」：不是美化，是为 B5 的 bonded 命令路径上游化铺路 + 现网 Q28 坏发取证（三方引用 `reports/b5-resoc-20261027.md`、`reports/m6-b5-series-repack-20261031.md`）；②承认 4/5 commit message 的「probe order」说法错误（master 由 DT 定），改写；③**必须交代 base `0f1fb1c9c1` 不在公开树**并给等价复现方式（否则他永远 apply 不上） | 无死线。**★但这是本系列能否继续的前提**：0/5 被问「bonded DSI 现在就能用，凭什么改」= 立项理由被质疑 |
| **A3** | mail-io（只读核对）→ 投递需批 | **M3-1 dwc3 v5：补投 `devicetree@vger.kernel.org`** | 不必「回信」，但**需重投 1/2**（binding 未进 DT 列表归档） | ①`linux-devicetree@vger.kernel.org` 是错地址（vger `550 5.1.1`），正确为 `devicetree@vger.kernel.org`；②只补 1/2 的 binding 一封（或 v6 全量，由总管定）；③Rob/Krzysztof/Conor 是直接 Cc，本体已收到，故非紧急 | 低。归档侧 `linux-devicetree` **404**（实测，§3），`linux-usb`/`linux-arm-msm` 均在 |
| **A4** | 需改 `patches/`（另派，本轮边界不含） | **wl2868c v5 3/4：修 `cci1_1` 引脚 High** | 不必回 bot，落进 v5 changelog | ①`cci1_1_default/sleep` 改 gpio111/gpio164（依据见 §4.1 本地核对）；②顺带按 Medium 去掉 `cci*_i2c1` 的 `status="disabled"` 或把 bus1 pinctrl 改成按需 claim；③pinctrl 节点挪到字母序位置（Low） | 低（elden 当前只用 `cci0_i2c0`，见 §4.1 影响面） |
| **A5** | 需改 `patches/` | **wl2868c v5 1/4 + 4/4：拆/改** | 不必回 bot | ①1/4 把 `qcom.yaml` 改动从 wl2868c 提交剥离（Low，checkpatch 也报过同类）；②4/4 补 chassis-type 等板级 boot 基础设施、camera/lens 与 binding 同步落地 | 低 |
| **A6** | 后续任何 mdss 回信的执行者 | **Cc 名单换掉 quic 旧地址** | 不需要重发补丁 | ①mdss v2 系列本体（Sent 203–206）用的是现用地址 `abhinav.kumar@linux.dev` / `jesszhan0024@gmail.com`，**没弹**；②只有 Sent[216] 那封回复抄了 `quic_*@quicinc.com` 才弹；③v3 及以后一律用现用地址 | — |
| **A7** | 人工 + 真机 | **M8 mdss v3：先修再发** | 回信随 v3 一起 | ①v3 = 删 RSCC + 留 CORE/CORE_INT2 + 删长注释（两条 Dmitry 意见 + Konrad 意见合并说明）；②**发前必须真机冷起 A/B 证明 CORE+INT2 足够**（当前无设备）；③commit/回信都短，避免「LLM 味」 | 中；被真机复测阻塞 |

**汇总**：必须回 **2 条**（A1、A2）；需重投 **1 条**（A3）；需改补丁 **2 条**（A4、A5）；地址纪律 **1 条**（A6）；待真机 **1 条**（A7）。

### 特别核对（派工单 §5 逐项）

| 项 | 结论 |
|---|---|
| **5a. Dmitry 对 mdss v2 两条意见之后有无新回信 / v3 是否已发** | **无新回信**（lore 线程 8 封 = 我方 4 + Konrad 1 + Dmitry 2 + 我方回复 1，最新外部 = 10-31 21:48Z）；**v3 未发**：Sent Items 自 10-29 20:32 CST 之后**没有任何 mdss 邮件**（`/tmp/eld-sent-1102.py` 全表，末四条 mdss = Sent 203–206 + 回信 216）。`TASKS/README.md` §7 M8 的 10-31 静态裁定（删 RSC、0002 保留）仍是待落地状态 |
| **5b. postmaster@qualcomm.com 退信 / 弹的哪个地址 / 是否需重发** | 弹 **`quic_jesszhan@quicinc.com` + `quic_abhinavk@quicinc.com`**（`550 5.1.10 RecipientNotFound`），原信 = 我方 **Sent[216]**（mdss-common v2 1/3 的回复）。**不需要重发**：系列本体用的已是现用地址，只有这封回复抄了旧 quic 地址 ⇒ 记为地址纪律（A6） |
| **5c. mu_wide_platforms issue #12 新评论** | `gh api repos/sunflower2333/mu_wide_platforms/issues/12` → `state=open, comments=7, updated_at=2026-10-29T04:19:30Z`。**无新评论**；最新仍是 sunflower2333 10-29「别用劣质 token 瞎猜…UEFI USB ACM Gadget」 |
| **5d. 是否存在「维护者已回但我方从未看到」的信** | 用 References/In-Reply-To 服务端搜索（窗口放宽到 10-25）**有，共 3 类**：①B5 四封 Dmitry（#6–#9）、②wl2868c v4 三封 sashiko（#2–#4）、③三封 USTC 退信（#5）。三者都不在任何既有报告里 ⇒ **基线确有漏记**，不是「没来信」。除此之外无第四条 |

---

## §3 lore 三态表（本轮逐封重核）

判据：`/<list>/<msgid>/raw` HTTP 200 = 已进 archive；线程成员里出现我方之后的外部回信 = 有新意见。
**注意**：`lore-probe.py` 的 `/all/` 路径本轮全 300，见 §0。

| 系列 | 根 Message-ID（完整） | 归档 | 归档列表 | 线程 | 最新外部来信 | **状态** |
|---|---|---|---|---|---|---|
| **M3-1 dwc3 v5** | `20261031150154.1106455-1-…@mail.ustc.edu.cn` | ✅ 12375 B | `linux-usb` + `linux-arm-msm` | 3（我方 cover+2） | 无 | **归档 ✅ / 0 回信**；**`linux-devicetree` 404 = binding 未进 DT 归档**（错地址，A3） |
| **M4 camss v2 0/2** | `20261031041154.308030-1-…` | ✅ 7105 B | `linux-media` | 10+（我方 v1 3 + v2 3 + Loic/Bryan 4） | 10-29 15:00Z Loic（v1 阶段）；**v2 之后 0 条** | **归档 ✅ / 0 新意见**（v2 未被评） |
| **M4 camss v3** | — | — | — | — | — | **未发**（Sent Items 无 v3；派工单里的 "v3" 目前不存在） |
| **M6 B5 0/5** | `20261031150305.1107572-1-…` | ✅ 7357 B | `linux-arm-msm` + **`dri-devel` 6754 B** | 10（我方 6 + Dmitry 4） | **Dmitry 10-31 20:21–20:31Z（4 封）** | **归档 ✅（dri-devel 已补上，基线「0/6」作废）/ 有 4 条新意见** |
| **M8 mdss v2 0/3** | `20261029123238.29877-1-…` | ✅ 8297 B | `linux-arm-msm` + `dri-devel` + `linux-devicetree`（1/3 7669 B） | 8 | Dmitry 10-31 21:47/21:48Z（2 封） | **归档 ✅ / 有 2 条意见（已定案，v3 未发）** |
| **M2 A2 battmgr** | `20261027132949.242685-1-…` | ✅ 9264 B | `linux-pm` | 23（长线程） | Konrad 10-23；我方 10-28 收尾后 0 条 | **归档 ✅ / 0 新意见** |
| **wl2868c v3** | `20261031034300.272730-1-…` | ✅ 7395 B | `linux-arm-msm`（**`linux-regulator` inbox 在 lore 上是 404，该列表无独立归档**） | 与 v4 同线程 | sashiko 10-31 04:00Z（已处理，回信 Sent[217]） | **归档 ✅ / 0 新意见** |
| **wl2868c v4** | `cover.1793427040.git.xiaqinghuan@…` | ✅ 8544 B（`linux-arm-msm`）/ 8523 B（`linux-devicetree`）/ 8537 B（`lkml`） | 多列表 | 11+（v3 4 + 我方回复 1 + v4 5 + sashiko 3） | **Mark Brown 11-01 22:40Z** | **归档 ✅ / 有 1 条流程投诉**（A1） |
| **M1-U6 q6v5_pas** | `20261027132944.242550-1-…` | ✅ 6924 B | `linux-remoteproc` | 单封 | 无 | **归档 ✅ / 0 新意见** |

**汇总**：本轮需核 **8 个已发系列**（camss v3 不存在），**归档 8/8 命中、0 取不到**；「有新意见」**3/8**（B5、mdss v2、wl2868c v4 线程）。

---

## §4 未证实 / 未做

1. **sashiko v4 3/4 的 High 我已静态复核，结论偏「成立」但有一处推理链依赖跨 SoC 引脚表相同**（记此以便回信不越界）：
   - 我方文本确实把 `cci1_1` 写成 `gpio119/120`：`patches/upstream/wl2868c-v4-20261031/v4-0003-*.patch:175-190`（`pins = "gpio119"` / `"gpio119", "gpio120"`）。
   - `linux/arch/arm64/boot/dts/qcom/sm8650.dtsi:6385-6410`：`cci2_1_default/sleep` = gpio119/120；`:6321-6352` 的 `cci1_1` 在 sm8650 上是 gpio12/13（引脚编号跨 SoC 不同，**不能直接类比**）。
   - `linux/drivers/pinctrl/qcom/pinctrl-sm8750.c:1550,1603`：gpio111 = `cci_i2c_sda` + **`cci_timer`**、gpio164 = `cci_i2c_scl` + **`cci_timer`**，与 sashiko 所述「cci1_1 与 cci_timer 复用」一致；`:1558-1559` gpio119/120 亦可作 cci_i2c_sda/scl（不排他）。
   - ⇒ **引脚归属（哪对属于 cci1_1 还是 cci2_1）在本地树里查不到权威映射**，sashiko 的依据是 sm8650 DTS + sibling pinctrl 的编号延续性。**「High 成立」目前是强旁证，不是直接证据**；回信/修补丁前建议用 vendor DTS 或高通常见 camera DTS 再核一次（本轮未做）。
   - **影响面**：elden 板当前只开 `&cci0` / `&cci0_i2c0`（`v4-0004-*.patch:104-108`），`cci1` 仍 disabled ⇒ 该 High 对 elden **当前无运行时影响**，但是 SoC dtsi 层面的真错。
2. **sashiko v4 4/4 三条 Medium 未逐条做本地核对**（只在正文读到标题级）；其中「板 DT 缺 boot 基础设施」是否指 chassis-type 等，需读全文后再定。
3. **Dmitry 的「what is your base kernel」**：我方 base `0f1fb1c9c1` 不在公开树（基线已记该局限）。本轮**未找到**等价公开 base（未试 `git log --all --oneline | grep 0f1fb1c9c1` 之外的取法，也无 upstream 孪生提交）⇒ 标**未证实是否可在公开树上复现 apply**。
4. **未做**：任何发信 / 改订阅 / patchwork 写操作 / `git add|commit|checkout|clean` / 设备访问 / `sudo` / 改任何 README·INDEX·TASKS·DEVICE·RESOURCES·PITFALLS·PROGRESS·AGENTS·.pi/*.md。
5. **未核**：patchwork 三态本轮没重拉（基线 `reports/mail-triage-20261030.md` §4 有效；sashiko 不改 state 这一层不变）。
6. **时区**：表格一律 UTC。Dmitry/Mark 原信为 `+0200`/`+0000`，已换算；sashiko 原生 `+0000`。

---

## §5 复跑命令

```bash
cd /home/xuqianhui/y700-elden   # 首命令必须是 git rev-parse --show-toplevel 并核对

# 1) 信头表（SINCE 01-Nov-2026；INBOX / Junk / Sent，只读 BODY.PEEK）
python3 /tmp/eld-mailhdr-1102.py            # -> /tmp/eld-mailhdr-1102.json（397 封）

# 2) 指定邮件正文
python3 /tmp/eld-body-1102.py INBOX 16123 16125 16127 16129 16366
python3 /tmp/eld-body-1102.py INBOX 15930 15931 15932

# 3) 退信 DSN（被弹收件人 + 原信 Message-ID）
python3 /tmp/eld-dsn2-1102.py INBOX 16012 16013 16014
python3 /tmp/eld-dsn2-1102.py '"Junk E-mail"' 405

# 4) References 兜底（找「维护者已回但我方没看到」）
python3 /tmp/eld-search-1102.py             # 25-Oct 起的 References/In-Reply-To 含 mail.ustc.edu.cn

# 5) Sent Items 全表（判断某版本到底发没发）
python3 /tmp/eld-sent-1102.py               # 25-Oct 起

# 6) lore 归档 / 线程（注意：完整 Message-ID + 列表名 + ~6 s 限速）
python3 /tmp/eld-lore-1102.py linux-usb:20261031150154.1106455-1-xiaqinghuan@mail.ustc.edu.cn
python3 /tmp/eld-lore-1102.py --thread linux-arm-msm:20261031150305.1107572-1-xiaqinghuan@mail.ustc.edu.cn

# 7) issue #12
gh api repos/sunflower2333/mu_wide_platforms/issues/12 --jq '{state,comments,updated_at}'

# 8) 本地静态核对（sashiko High）
grep -n 'cci[0-9]_[01]_default:' linux/arch/arm64/boot/dts/qcom/sm8650.dtsi
grep -nE '\b(111|119|120|164)\] = PINGROUP' linux/drivers/pinctrl/qcom/pinctrl-sm8750.c
```

> 脚本都在 `/tmp`（临时），仓库内**只**新增本文件与 `TASKS/sessions/2026-11-02-邮件分诊.md`。
> `/tmp` 若被清理，脚本可从本节描述按 `out/mail-20261029/{triage-20261029.py,fetch-body.py}` 的取信模式重建。
