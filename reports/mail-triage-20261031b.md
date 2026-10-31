# 上游邮件分诊 — 2026-10-30 03:17Z → 2026-10-31 04:50Z（mail-io · L1-B）

> 派工单：L1-B / mail-io，收信分诊 + lore 归档核对（**只读只起草**）。
> **未发任何邮件**（`send-mail-ustc.py` 只跑 dry-run）、未改订阅/凭据、未改 SSOT（`TASKS`/`INDEX`/`PITFALLS`/`DEVICE`/`README`）、未 `git commit`、未碰设备。
> 已处理基线（不重推）：`reports/mail-triage-20261030.md` + 2026-10-31 三批投递（wl2868c v3 0/3、回 Krzysztof 两封、camss v2 0/2）。

---

## §0 口径

| 项 | 值 |
|---|---|
| 通道 | IMAP `mail.ustc.edu.cn:993`（GNOME keyring 复用），`BODY.PEEK` 只读 |
| 文件夹 | `INBOX` / `"Junk E-mail"` / `"Sent Items"` |
| 时间窗 | 分诊增量 = **2026-10-30 03:17Z → 2026-10-31 04:50Z**；为覆盖 10-29 之后全部来信，另拉 `SINCE 29-Oct-2026` 全量头表做交叉（INBOX 1397 封、Junk 24、Sent 46） |
| 工具 | `~/.local/bin/read-mail-ustc.py --days 3 --limit 60`（表头）+ 只读辅助脚本（`/tmp`，不入库）：`eld-mailhdr.py`（补 Message-ID/In-Reply-To）、`eld-mailbody.py`（BODY.PEEK 正文）、`eld-lore-thread.py`（lore `/all/<mid>/raw` + `t.mbox.gz` 整线程） |
| 归档判据 | ①按 Message-ID 取 `raw` HTTP 200；②取 `t.mbox.gz` 逐封列线程成员，用于判定「有无新评审意见」——**不以「已发送」为证据** |
| 未做 | 任何 send/`--send`、改 patchwork 状态、`git credential`、设备访问、改任何 README |

`--replies-only` 本轮**未使用**（`OUR_IDS` 硬编码 3 个 10-13 Message-ID，换系列必漏，`PITFALLS #461`）；「有无回信」由服务端头域 + lore 线程双证。

---

## §1 新来信（增量窗内与我方相关的全部 = 2 封外部 + 2 封系统退信）

| # | 时间(UTC) | 发件人 | Subject | Message-ID | 线程 | 要求项 | 截止暗示 |
|---|---|---|---|---|---|---|---|
| 1 | 10-30 15:02 | **Konrad Dybcio** | `Re: [PATCH v2 1/3] dt-bindings: display: msm: mdss-common: describe additional block resets` | `<d265dd66-d8fb-4fd2-b6cb-d50462e4b6e2@oss.qualcomm.com>` | M8 v2 | **一条实质意见**：原文全文 = 「**MDSS RSC is not part of MDSS itself**」。即 mdss-common 的 `resets` 不该列 `DISP_CC_MDSS_RSCC_BCR`（RSC 是独立块，SM8750 在 `apps_rsc: rsc@16500000`） | 无 |
| 2 | 10-31 04:00 | sashiko-bot | `Re: [PATCH v3 3/3] arm64: dts: qcom: sm8750-lenovo-elden: describe the WL2868C regulators` | `<sashiko-outbox-191739@kernel.org>` | wl2868c v3 | 自动评审 **4 条**，其中 **1 条 High 是真 bug**（详见 §4） | 无 |
| 3 | 10-29 17:39 | postmaster@mail.ustc.edu.cn | `系统退信/Systems bounce` | `<6AE384D4.1378ED.49362@mailimap2024>` | 回 Mike Turquette 的补发 | 退信对象 = 10-28 给 `mturquette@baylibre.com` 的那封（baylibre MX 临时故障，USTC 侧未重试）；正文即补发件本身，**已知并已补发**，无新动作 | — |
| 4 | 10-28 17:06 | 同上 | 同上 | `<6AE22B80.11BF23.49362@mailimap2024>` | 回 Taniya 原信 | 同一批退信，基线前，已处理 | — |

**判断**：`Junk E-mail` 24 封中与本项目相关 = **0**（唯一关键字命中是 Hans de Goede 的 libcamera camss CMA 补丁，非我方线程）。INBOX 1397 封其余为列表流水（libcamera / dwc3 / camss Hawi-Maili v3 / v23 Kaanapali 等他方系列），与本项目无投递关系。

---

## §2 lore 归档核对（11 条在评审系列，三态表）

判据：`raw` 取回成功 = 已进 archive；线程成员里出现**我方之后**的外部回信 = 有新意见。

| 系列 | 根 Message-ID | raw | 线程封数 | 最新外部来信 | **状态** |
|---|---|---|---|---|---|
| M2 A2 battmgr（power_now） | `20261027132949.242685-1` | ✅ 9299 B | 23（含 10-12 起的同主题长线程） | Konrad 10-23 15:57Z（我方 10-28 19:57Z 收尾回信之后 0 条） | **无新意见** |
| M3-1 v4（usb dwc3 双连接器 3 枚） | `20261026123211.243224-1` | ✅ 12135 B | 7 | 仅 sashiko 3 条（10-26 12:50/12:59/13:20Z，v4 投递当天） | **无新意见**（维护者仍 0） |
| M4 camss **v2 0/2**（10-31 04:11Z 投） | `20261031041154.308030-1` | ✅ 7105 B | 10（= 我方 3 + 10-29 旧 4 + 10-29 评审 3） | 10-29 16:00Z Loic（v1 3/3 形状建议）**之后 0 条** | **无新意见**（投后约 0.6 h） |
| M4 通用修复 **3 枚**（10-29 04:31Z 投，被 v2 0/2 顶替） | `20261029123107.28705-1` | ✅ 8051 B | 10 | 同上（Loic/Bryan 3 封，10-29） | **无新意见** |
| M4-1 bindings（gt9764 + s5kjns） | `20261027051048.213177-1` | ✅ 6211 B | 6 | Krzysztof 10-28 14:29/14:31Z（`changes-requested`） | **无新意见**（未答，pending） |
| M6 L1（DSI PLL_SYSTEM_MUXES） | `20261019130041.305805-1` | ✅ 6179 B | **1** | 无 | **无新意见**（单封无回信） |
| M8 RFC dispcc（10-22） | `20261022140811.469417-1` | ✅ 9339 B | 5 | Taniya 10-22 17:22Z（否决 clk 侧形状）；我方 10-28/10-29 两封未被回 | **无新意见** |
| M8 **v2 0/3**（10-29 12:32Z 投） | `20261029123238.29877-1` | ✅ 8297 B | 5 | **Konrad 10-30 15:02Z**（§1 #1） | **有新意见**（1 条，binding 语义） |
| M9 kexec（已撤回） | `20261024075856.835932-1` | ✅ 10235 B | 4 | **Marc Zyngier 10-26 13:53Z**（我方 11:41Z 撤回回信之后） | **有新信，但无新要求**（确认函，见 §3） |
| aw86927 v2（5 枚） | `20261027132929.242158-1` | ✅ 6343 B | 9 | Krzysztof 10-27 19:06Z（binding 2/5）+ sashiko 2 条 | **无新意见** |
| wl2868c **v3 0/3**（10-31 03:43Z 投） | `20261031034300.272730-1` | ✅ 7395 B | 8 | **sashiko 10-31 04:00Z**（§1 #2） | **有新意见**（4 条，其中 1 High 真 bug） |

**汇总**：11/11 系列 `raw` 取回成功（**lore 命中 11/11**）；「有新意见」**2/11**（M8 v2、wl2868c v3）；「取不到」**0/11**。
附带发现：wl2868c v3 的 4 枚与 camss v2 的 3 枚在 lore 线程里均 4/4、3/3 齐（与基线「已归档」一致），**无需重投**。

---

## §3 M9 的未记录回信（本条不是新任务，只是把记录补齐）

- Marc Zyngier，2026-10-26 13:53Z，`<86y0bky3el.wl-maz@kernel.org>`，回我方 11:41Z 的撤回信。
- 内容 = **纯确认，无新要求**：`Thanks.` + 三点复核（LPI 表页在 GIC 驱动跑到时可能已被当普通页表分给别的用途 ⇒ 内存损坏很可能；EFI reservation 是通过与平台描述方式无关的 Linux-specific EFI tables 做的，DT reserved-memory 也可但必须由初始引导点设置；若用 Linux 当一级引导器（如 petitboot）则 DT 必须带 reservation，u-boot(非 EFI) 可在 u-boot 里做）。
- 处置：**无需回信**；与 M9「撤回 + 长期归位 loader」口径一致，不改变 `TASKS` §7 M9 结论。

---

## §4 新意见逐条分诊

### 4.1 Konrad / M8 v2 binding（§1 #1）—— 技术性，可起草

| 项 | 内容 |
|---|---|
| 意见 | `MDSS RSC is not part of MDSS itself` |
| 事实核对（本地） | `build/m8-dispcc-v2/arch/arm64/boot/dts/qcom/sm8750.dtsi:5726` 确有独立 `apps_rsc: rsc@16500000`；而 `DISP_CC_MDSS_RSCC_BCR` 的**寄存器在 dispcc 空间**（`reports/m8-dispcc-v2-20261029.md` §166 已自陈「寄存器在 dispcc 寄存器空间但只作用于 MDSS 块」）⇒ **Konrad 的块归属论据成立，我方是寄存器图论据，论据层级不同** |
| 结论 | **接受**：v3 从 `mdss-common` 去掉 RSC，只留 CORE + CORE_INT2（`minItems: 1` + 2 项） |
| 遗留风险（必须写进回复） | RSCC 进列表的**唯一理由是实测**：本板 bootloader 交接时显示块活着，vendor 栈上三枚一起复位才消除面板 init 失败（`reports/q28-disp-init-ab-20261022.md` 行 10、`reports/m8-dispcc-v2-20261029.md` §177–189），**三枚从未单独测过**。去掉 RSCC 后需真机冷起重测 CORE+INT2 是否足够；若不足，复位应由 RSC 设备驱动，不回 mdss |
| 草稿 | `out/mail-20261031-b/re-konrad-mdss-rsc.txt`（41 行正文、纯 ASCII、dry-run 通过、17 收件人） |

### 4.2 sashiko / wl2868c v3 3/3 DTS（§1 #2）—— 4 条：3 真 1 部分

| 严重度 | 意见 | 本地核对 | 我的判定 |
|---|---|---|---|
| **High** | `&i2c10` 被 okay，但父 `qupv3_2` 与 `gpi_dma2` 仍 `disabled` ⇒ `geni_se_probe()` 不跑、i2c10 永不实例化、`wl2868c_probe()` 不跑、`camera_ldo1..7` 全部不存在 | **成立且可确证**：`sm8750.dtsi:695 gpi_dma2` / `:721 qupv3_2` / `:870 i2c10` 三者默认 `status = "disabled"`，v3-0003 只写了 `&i2c10 { status = "okay" }` | **真 bug，接受**；v4 需补 `&qupv3_2`/`&gpi_dma2` |
| Medium | 三个 sensor/lens compatible 无 binding、缺 CSI port/endpoint、外部 I2C sensor 上挂 `power-domains = <&camcc CAM_CC_TITAN_TOP_GDSC>` | 部分成立：gt9764/s5kjns binding **已单独投过**（`20261027051048.213177`，仍 `changes-requested`）；`galaxycore,gc08a8` **确实无 binding**；缺 endpoint、sensor 上挂 GDSC = **我方错** | **部分接受**：v4 把 sensor/lens 节点移出本系列（随各自 binding 落地）、删 sensor 的 `power-domains`；但要在 cover 里如实说明「本系列的用户是整块板 DTS，会分批落地」 |
| Low | `cci0_i2c1`/`cci1_i2c1` 被 disabled 而 bus0 开着；bus1 pinctrl（gpio115/116、gpio119/120）缺失；节点未按 unit-address 排序；commit 说两个 CCI 而 SoC 有三个 | 成立（与 sm8550/sm8650 惯例不同；`camcc-sm8750` 有 `CCI_2_CLK`、`pinctrl-sm8750` 有 cci2 引脚） | **接受** |
| Low | qcom.yaml + SoC dtsi + 板 DTS 混在一枚 | 成立；**checkpatch 同一轮也报了**（3/3 的 5 条 WARNING 之一就是"DT binding docs should be a separate patch"） | **接受**：v4 拆 3 枚 |
| 草稿 | `out/mail-20261031-b/re-sashiko-wl2868c-v3-dts.txt`（77 行正文、纯 ASCII、dry-run 通过、10 收件人） | | |

> **必须上报用户的连带影响**：High 条意味着 **Krzysztof 追问的「users of this binding」在运行时不成立**（i2c10 不探测 ⇒ 8 条 `*-supply` 指向的 regulator 注册不出来）。这不是「回复措辞」问题，而是 v3 3/3 的实质缺陷 ⇒ 在修好并上机验证之前，**不宜再向 Krzysztof 强调「用户已随系列给出」**。

---

## §5 待回/待办清单（全部未执行）

| # | 对象 | 类型 | 建议 | 状态 |
|---|---|---|---|---|
| **N1** | Konrad（M8 v2 binding） | 技术回信 + v3 重出 | 回复已起草；**v3 需从 `mdss-common` 删 RSC**（改补丁 = 需另派，本轮边界不含改 `patches/`） | `[需点头]` 草稿待批 |
| **N2** | sashiko（wl2868c v3 3/3） | 技术回信（可选）+ v4 | 回 bot **非必须**（也可只落进 v4 changelog）；4 条已逐条定案，**但 v4 需要先修 DTS 并上机验 i2c10 探测** | `[需点头]` 草稿待批 |
| **N3** | Krzysztof（wl2868c binding 线程） | 回信 | 该类**必须人工撰稿**（他明示过"not with LLM"）；本轮只列要点：①qupv3_2/gpi_dma2 缺失已承认并将在 v4 修 ②sensor/lens 节点移出本系列 ③「用户」改成「整块板 DTS 分批落地」的诚实说法 | `[需人工撰稿]` **不代写正文** |
| **N4** | 我方 | 重测 | 去掉 RSCC 后 CORE+INT2 是否仍够（Q28 冷起 A/B）——真机动作，本轮无设备 | `[需真机]` |
| ⏸ | M3-1 v4 / M4-1 bindings / aw86927 v2 / M6 L1 / M2 A2 / M8 RFC | — | 0 新信，**等**（不是漏） | 无动作 |

本轮**未**产生任何发信动作。

---

## §6 patchwork 只读情况

本轮未做写操作，也未重复拉全量（基线 `reports/mail-triage-20261030.md` §4 有效）。仅记两处与本轮新意见相关的**读侧一致**：
M8 v2 在 devicetree 侧 1/3 仍为 `needs-ack`（与「首个维护者意见＝binding 语义」相符）；wl2868c v3 三枚 `linux-regulator` 侧仍 `new`（sashiko 是自动评审，不改 patchwork state）。

---

## §7 一句话收口

增量窗内**只有 2 封新意见**：**Konrad 一句话否掉 M8 v2 的 RSC 复位**（接受，v3 删一项，但需真机重测 CORE+INT2）、**sashiko 4 条打在 wl2868c v3 的板 DTS 上且 High 是真 bug**（i2c10 的父 `qupv3_2`/`gpi_dma2` 没 enable ⇒ regulator 根本注册不出来）。
两封技术回信已起草（**未发**）；Krzysztof 那条**按 2026-10-31 用户授权可代写正文**（前提 = 披露 AI 辅助 + 证据 + 逐条回应；见 `AGENTS.md`「上游发信」），投递仍待批。

> **★2026-10-31 12:5x 总管更正（不改上文证据）**：`wl2868c v3 0/3` **已于当日 11:42:57–11:43:00 CST 实际投出**（Sent Items [208–211]、本机 INBOX [15908–15911]），patchwork 已收录 v3 三枚 + elden DTS（driver 一条 `handled-elsewhere`，其余 `new`/`needs-ack`），本报告 §6 的「三枚仍 `new`」只在 sashiko 不改 state 这一层成立。凡以「v3 待投」为前提的段落一律作废。
lore 归档 **11/11 命中、0 取不到**；另补齐一条 M9 的未记录回信（Marc 10-26 13:53Z，纯确认、无新要求）。
