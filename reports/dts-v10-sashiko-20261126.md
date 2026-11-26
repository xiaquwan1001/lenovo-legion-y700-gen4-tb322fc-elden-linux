# elden 板 DTS v10 —— sashiko 复审两条 `[Medium]` 的处置裁决（2026-11-26，**不发信**）

> **纪律**：本文件是本轮**唯一**新增报告；**未发任何邮件**（含 `--dry-run`）、**未改** `TASKS/`、
> `PATCHES/` 既有文件、`patches/upstream/elden-dts-v10-20261126/`（v10 目录只读）。
> 新增备料目录 = `patches/upstream/elden-dts-v11-20261126/`（只含「下一版 cover/changelog 该写什么」的文本，
> **不含任何 DTS 改动**）。备用回信草稿 = `out/mail-20261126/re-sashiko-v10-core-nodes.txt`（默认不发）。
> 外部查询只读：lore `t.atom` 线程、`git.kernel.org` 的 `plain/`（经 `web_fetch` 过 Anubis）；
> 本地判据全部落在 `build/elden-tree`（7.4-rc3，`aebb72744764`）与 `linux`（= `/home/xuqianhui/elden-cache/src/geekidos-linux`，
> 全历史克隆，用 `git show <rev>:<path>` 读，不 checkout）。

---

## 0. 裁决（一句话）

**选 (A)：v10 的 DTS 不改，不出「为答机器人」的 v11；把拆分计划写成下一版 cover 的显式一节 + 2/2 changelog 两行。**
两条 `[Medium]` **都不是新缺陷**：① binding 那条是 cover `Waiting on bindings` 已点名的依赖（且本轮补到内容级证据：
binding 已在 `linux-next next-20261125`、仍不在 torvalds/master）；② core boot 那条**事实成立但属已声明范围**，
且 sashiko 把「storage/USB」也列进首版要求，**与 SM8750 参考板自己的首版范围相反**（见 §3 的提交/日期表）。
(B) 不是「机械搬运」：console UART 身份在本机**没有证据**、双口 USB 依赖我方在飞的 dwc3 v16、
`ramoops` 与会审中的 M11 撞车、原厂两条属性在上游是死属性/无 binding —— 属「有依赖就不该现在扩」。
**回复**：不主动回（机器人、无新事实、无人类要求）；备用草稿已备，仅当人类维护者重提时发出。

---

## 1. 新信事实核对（Message-ID / 归档 / 工具口径）

| 项 | 值 | 判据（可复跑） |
|---|---|---|
| Message-ID | **`<sashiko-outbox-234789@kernel.org>`** | 线程 atom：`curl -sS -A 'Mozilla/5.0 …' 'https://lore.kernel.org/all/20261126052057.1544590-3-xiaqinghuan@mail.ustc.edu.cn/t.atom'`（200，22159 B） |
| From / 时间 | `sashiko-bot <sashiko-bot@kernel.org>`，`2026-11-26T05:30:06Z`（信内 `05:30:05Z`） | 同上，`<author><name>sashiko-bot</name><email>sashiko-bot@kernel.org</email>` |
| 挂载点 | `In-Reply-To` = **v10 2/2** `<20261126052057.1544590-3-…>`（atom `thr:in-reply-to` 指向 `…-3-…` permalink） | 同上 |
| 是否进 archive | **进 `linux-devicetree`**；`linux-arm-msm` **无独立副本**（按 MID 查该列表返回「found in another inbox → ../../linux-devicetree/…」） | `web_fetch https://lore.kernel.org/linux-arm-msm/sashiko-outbox-234789@kernel.org/` |
| 评审条数 | **2 条 `[Medium]`**（v9 是 3 条；`vin*-supply` 那条**本轮不再出现** = v10 的四处 supply 修法在机器侧已不报） | atom content 逐字 |
| 本代 vs v9 的评审差异 | v9：M1 binding、M2 core boot、M3 `vin*-supply` ⇒ v10：只有 M1、M2 | 对照 `reports/comm-triage-20261126-d10.md` §3.2 |
| 线程当前成员 | 线程 atom 共 **4 条**：我方 cover/1/2/2/2（`05:21:01Z`/`05:21:02Z`/`05:21:05Z`）+ sashiko（`05:30:06Z`）⇒ **尚无任何人类回信**（Bjorn/Konrad/Conor/Krzysztof 均无） | atom `entry` 逐个 author 计数 |

**原文逐字（两条标题 + 正文要点，供后续逐条答复时引用）**

```
- [Medium] arm64: dts: qcom: missing willsemi,wl2868c binding schema in
  target tree
- [Medium] arm64: dts: qcom: missing core boot and power nodes in
  sm8750-lenovo-elden.dts
```

M1 正文：

> Is the binding schema for "willsemi,wl2868c" present in the target tree?
> Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml has not
> landed on this branch yet, so checkpatch reports an undocumented DT string
> and make dtbs_check fails schema validation on pmic@2f.

M2 正文：

> Should this board devicetree include the core boot peripherals and system
> power rails (such as chosen/stdout-path, SPMI PMICs, RPMh regulators under
> apps_rsc, boot storage, or USB) rather than only describing an isolated
> camera PMIC whose input supplies are stubbed to wl2868c_vsys and whose LDO
> outputs have no consumers?  Because sm8750.dtsi leaves UARTs, storage, USB,
> and display blocks disabled by default, this devicetree lacks the core
> hardware description needed to boot or operate the board.

**一处机器口径要纠正（M1 里的）**：sashiko 说「checkpatch reports an undocumented DT string」——**不成立**。
v10 实跑的 checkpatch 是 `0 errors, 1 warnings, 0 checks`（1/2 = 0/0/0），唯一的 W 是
`added, moved, or deleted file(s), does MAINTAINERS need updating?`，**没有任何 binding 相关输出**
（`patches/upstream/elden-dts-v10-20261126/logs/checkpatch-v10.txt:2,6,10`）。
真正会报的是 `make dtbs_check`，且**正好一条**：

```
arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb: /soc@0/geniqup@8c0000/i2c@888000/pmic@2f:
  failed to match any schema with compatible: ['willsemi,wl2868c']
```
（`logs/dtbs-check-3dtb-no-binding-20261126.log` 末段；apply binding 后同门 0 诊断，
`logs/dtbs-check-3dtb-with-wl2868c-binding-20261126.log`）

---

## 2. 两条逐条归类：哪些是「已在 cover 说明的预期现象」，哪些是「真新意见」

| # | 条目 | 归类 | 判据 |
|---|---|---|---|
| **M1** | binding schema 不在目标树 ⇒ `pmic@2f` 报 undocumented | **已在 cover 说明的预期现象（第 3 次重复）** | v10 cover 专节 `Waiting on bindings`（`v10-0000-cover-letter.patch:13` = `cover.txt:7`）：点名文件 `Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml`、`84e67d2ee13f`（binding）/`602f57223457`（driver）、`regulator.git for-7.5`、基线 `v7.4-rc3` 没有它、合并顺序、以及「提前取 2/2 的代价 = 正好 1 条诊断」；2/2 的 `Changes in v10` 未重复但 cover 已给。**本轮新增内容级证据**见下 |
| **M2** | 缺 core boot / 电源节点（`chosen/stdout-path`、SPMI PMIC、`apps_rsc` RPMh regulators、boot storage、USB） | **已声明范围的重复（第 ≥4 次），但其中「storage/USB 也要算首版」是 sashiko 新加的口径** | `chosen`/PMIC/console/storage 四项自 **v6 4/5** 提交信息就写明「cannot be validated on hardware yet and is left to a separate board series」（`patches/upstream/wl2868c-20261104-v6/v6-0004-…patch:8-12`）；v9 cover 第 59 行专节 `Not described, not claimed`（点名 SPMI PMICs/RPMh regulators/console 与「boots nothing by itself」）；v10 cover 再用 `Review response: v9 2/2` 第 2 条逐字答过，并在 `Not described, not claimed` 段沿用。**「LDO 无消费者」「输入是 stub」也是 v10 cover 自己写的**（`What v10 changes in 2/2` 段）⇒ 无新事实 |
| — | （v9 的 M3 `vin*-supply`） | **本轮消失** | v10 首信两条里没有它 ⇒ v10 的四处 `vin*-supply` 被如实读作修好了 |

**M1 的本轮新增硬证据（比 cover 的写法更强，下次可直接引用）**

| 树 | 结果 | 取法 |
|---|---|---|
| `broonie/regulator.git for-7.5` | **在**（99 行，与本地 v12 binding 同源） | `web_fetch …/regulator.git/plain/Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml?h=for-7.5` |
| `next/linux-next.git master` | **在** | `…?h=master` |
| `next/linux-next.git next-20261125` | **在** ⇒ 7.5 合并窗口后自然进 mainline | `…?h=next-20261125` |
| `torvalds/linux.git master`（= 7.4-rc 线） | **`Not found`** ⇒ 我方基线没有它不是我们的问题 | `…/torvalds/linux.git/plain/…/willsemi,wl2868c.yaml` |

**结论**：M1 = 「等」的事实，**不需要任何动作**；把上表塞进下一版 cover 的一行，比现在 cover 里
「not in v7.4-rc3, the base of this series」更硬（多了 next 侧的证据），也不增加篇幅。

**M2 的「新」到底新在哪**：只新在**枚举**（它第一次把 `chosen/stdout-path` 与 `storage`/`USB` 并进一句话）
和**语气**（「lacks the core hardware description needed to boot or operate the board」）。**没有新的技术事实**，
也没有新的行号/属性级指摘（对比 v9 的 M3 是给了 `supply_name` 映射的，那才是真意见）。
因此对 M2 的处置是「**要不要按它扩范围**」的裁量，不是「修 bug」。

---

## 3. core boot 这条：上游同类板首版到底带哪些节点（惯例判据，逐文件/逐提交）

判据口径：只看**主线已合入**的首版提交（`git -C linux show <commit>:<path>`；`linux` 是全历史克隆）。
`git log --diff-filter=A` 在 `build/elden-tree`（浅克隆，最早 2025-12-12）里会退化成 merge commit，不可用。

### 3.1 SM8750 参考板（同 SoC，最有说服力）

`arm64: dts: qcom: sm8750: Add MTP and QRD boards` = **`6a02becf4b42`**，2024-12-04，Melody Olvera（Qualcomm），
`Link: 2024-12-04-sm8750_master_dt-v3-6-4d5a8269950b@quicinc.com`。首版 `sm8750-mtp.dts` = **794 行**，带：

| 首版就带 | 行号（该 blob 内） |
|---|---|
| `aliases { serial0 = &uart7 }` + `chosen { stdout-path = "serial0:115200n8" }` | 28–34 |
| PMIC includes（`pm8010`/`pm8550`/`pm8550ve`/`pmd8028`/`pmih0108`/`pmk8550`/`pmr735d_a`/`sm8750-pmics.dtsi`） | 11–20 |
| `vph_pwr` `regulator-fixed` | 84–93 |
| `&apps_rsc` 的 **8 个 RPMh regulator bank**（pmic-id `b`,`d`,`f`,`g`,`i`,`j`,`m`,`n`） | 96 起（`regulators-0` @97） |
| `&uart7 { status = "okay" }`、`&tlmm { gpio-reserved-ranges }`、gpio-keys、flash LED、PWM | 789–795 |

**首版没带、后来才加的（同文件，主线提交与日期）**：

| 子系统 | 提交 | 日期 | 距首版 |
|---|---|---|---|
| Wi-Fi/BT | `141714e163bbb` *arm64: dts: qcom: sm8750-mtp: Add WiFi and Bluetooth* | 2025-09-02 | ~9 个月 |
| **UFS（boot storage）** | `a95d8e3f40756` *…sm8750: Add UFS nodes for SM8750 MTP* | **2025-03-27** | **~4 个月** |
| SDC2（SD 卡） | `add674d84596b` | 2025-12-02 | ~12 个月 |
| **USB** | `2340f29e2b06e` *…sm8750: Add USB support for SM8750 MTP platform* | **2025-11-01** | **~11 个月** |
| display | `20a7612116304` | 2026-03-17 | ~16 个月 |
| DP over USB | `f54b2d81a7255` | 2026-03-17 | ~16 个月 |
| GPU | `d5eee07a7818e` | 2026-08-09 | ~20 个月 |

⇒ **同 SoC 参考板的「首版 = console + PMIC + RPMh regulators」，「storage/USB = follow-up」是既有事实**，
不是我们的发明。sashiko 把 storage/USB 列进首版要求，**与它自己参考的 `sm8750.dtsi` 同目录的历史相反**。

### 3.2 其它主线首版（同一口径，抽样）

| 板 | 首版提交 | 首版行数 | `chosen/stdout-path` | PMIC+rpmh | UFS | USB | display |
|---|---|---|---|---|---|---|---|
| `sm8750-mtp`/`qrd`（Qualcomm） | `6a02becf4b42` 2024-12-04 | 794 / 792 | ✅ | ✅ | ❌ | ❌ | ❌ |
| `sm8650-ayaneo-pocket-s2`（社区，"add **basic** devicetree"） | `df260487f33c8` 2026-03-19 | 1552 | ✅ | ✅ | ✅ | ✅ | ✅（其 display 节点 2026-08-31 才补：`3465c7448d209`） |
| `sm7325-motorola-dubai` | `dd1316efdbc5a` 2026-04-03 | 1457 | ✅ | ✅ | ✅ | ✅ | ✅ |
| `milos-fairphone-fp6` | `e25834d7691f0` 2025-12-10 | 791 | ❌（无 chosen） | ✅ | ❌ | ✅ | ❌ |
| `hamoa-lenovo-ideacentre-mini-01q8x10`（Bjorn 本人，Lenovo 消费机） | `af241225893ac` 2026-04-01 | 1201 | **❌ 无 `stdout-path`** | ✅ | ❌ | ✅ | ✅ |

⇒ **惯例是双峰的**：Qualcomm 参考板「console+电源起步、逐块长大」；社区整机移植常一次到位（有原厂 DT 可抄 + 能上机）。
**决定因素不是节点数，而是「这份 DT 能不能被验证」**——这正是我们从 v6 起写下的理由。

### 3.3 `chosen/stdout-path` 在本树里不是硬要求（避免被一条不成立的标准绑住）

`build/elden-tree/arch/arm64/boot/dts/qcom/` 共 **368** 个 `.dts`，其中 **246 个没有 `stdout-path`**、
**217 个连 `chosen` 都没有**（`grep -L` 计数）。UEFI 引导的 x1/hamoa/glymur 类机器（含
`hamoa-lenovo-ideacentre-mini-01q8x10.dts`、`x1e80100-lenovo-thinkpad-t14s.dts`）普遍不写 `stdout-path`。
**本机走的就是 UEFI+GRUB 链**（`reports/uefi-onboard-walkthrough-20261106.md`），Console 是 `ttyGS0`（USB gadget）
而不是某个 UART（`reports/m32-…`、`reports/q32-w1-sample-20261024.md:18`）。

---

## 4. 我方 v10 是否真的「不足以 boot」？——**是，事实成立**（逐项核，136 行）

`sm8750-lenovo-elden.dts`（v10 2/2，`@@ -0,0 +1,136 @@`）实际节点清单 = `clocks{}`（4 个 fixed/fixed-factor）、
`wl2868c_vsys`（`regulator-fixed`）、`&gpi_dma2`、`&qupv3_2`、`&i2c10` + `pmic@2f`（6 LDO）、`&tlmm`（2 段 reserved + 1 个 pinctrl）。

| sashiko 说的 | 本树事实 | 行号（`build/elden-tree`，7.4-rc3） |
|---|---|---|
| `chosen/stdout-path` 缺 | DTS 里无 `chosen`（`#include` 只有 `gpio.h` 与 `sm8750.dtsi`） | — |
| SPMI PMIC 缺 | `spmi_bus` 节点在 dtsi 里存在，但**没有任何 PMIC 子节点**（PMIC 由 `pm8550.dtsi` 等 include 提供，我们没 include） | `sm8750.dtsi:3882` |
| `apps_rsc` RPMh regulators 缺 | `apps_rsc` 在 dtsi 里存在，**board 未填 `regulators-N`** | `sm8750.dtsi:6011` |
| `sm8750.dtsi` 默认 disabled | **成立**：`uart7` `disabled`；`qupv3_1`/`qupv3_2` `disabled`；`gpi_dma2` `disabled`；`ufs_mem_hc`/`ufs_mem_phy` `disabled`；`usb` `disabled`；`mdss` `disabled` | `2037` / `1558`,`724` / `698` / `5924`,`5901` / `3141`（status 在 `3208`）/ `3351` |
| LDO 输出无消费者 | **成立**：文件里没有 `cci*`/camera 节点，`camera_ldoN` 只被声明未被引用 | — |

⇒ **能起内核，但看不到、也到不了任何地方**：无 console、无 rootfs（UFS disabled）、无 USB(gadget)、
无 RPMh 供电给任何消费者。cover 里那句「boots nothing by itself」是本项目自 v6 起的自述，**不是辩护**。
**所以 M2 的处置只能是「范围与次序」，不能是「误报」。**

---

## 5. 裁决：**(A)** —— 不改 DTS，下一版 cover/changelog 写显式拆分计划

### 5.1 为什么 (A)

1. **同族惯例支持「首版 = console+电源」，但也证明 storage/USB 属 follow-up**（§3.1 提交/日期表）。
   按 sashiko 的字面要求把 5 类节点一次塞进 136 行的文件，反而**偏离** SM8750 自己的历史；
   最小合规改动（若将来非改不可）是「console + PMIC + RPMh」，**不包含 storage/USB**。
2. **我们没有可验证路径，这是从 v6 起就写下的理由，现在仍然成立**：上游树从未在本机上电
   （日常线跑的是 vendor 7.3 内核 + vendor DT；本项目自己的口径见
   `reports/m3v5-f2-onboard-20261030.md:166`「202 行上游骨架板 DTS … 只服务上游投递，不用于上机验证」）。
   把 ~500 行 regulator/PHY 描述加进来，`dtbs_check` 绿 ≠ 电压/轨归属正确；被 Konrad 问
   「Are you sure it's actually how it's wired up?」（`reports/mail-triage-20261019.md:158`）那一类问题是**上机才能答**的。
3. **(B) 的依赖是实的、且在飞**（详见 §5.2）：双口 USB 依赖我方 dwc3 v16（`[PATCH v16 0/3]` 已于 2026-11-26T14:23Z 投出、未合入，见 `TASKS/UPSTREAM.md` M3 行）；
   `reserved-memory`/`ramoops` 与会审中的 M11（pstore initrd-overlap）撞车；原厂 DT 里两条属性在上游
   一条无 binding（`usb-psy-name`）、一条完全死掉（`qcom,preserve-boot-mappings`）⇒ **不是机械搬运**。
4. **人类评审信号**：4 轮（v3/v5/v6/v9/v10）里**没有任何人类维护者**要求补 core 节点；
   Krzysztof 对本板只提过两件事——措辞（`6d…`："Add Lenovo Legion Y700 Gen4, an Qualcomm SM8750-based tablet"）
   与「One logical action, one commit」，外加 v8 那句「**Your changelog or cover letter should be explicit about
   waiting on bindings, instead of wall of text**」。他要的是**显式、短、在 changelog/cover 里**的声明——
   这正好是 (A) 的形态（`reports/dts-v9-prep-20261126.md` §2.1/2.2 记了原文与落点）。
5. **同一份文件的「全量版」并没因为节点多而被接收**：Pengyu Luo 的 `[PATCH v2 0/2]` 的板件
   （`reference/upstream-pengyuluo/sm8750-lenovo-elden.dts`，**1096 行**）已含 `chosen`（第 33 行，simple-framebuffer）、
   `&apps_rsc`（248）、UFS（1023/1030）、9 处 `&usb`（121/159/1056/1064…）、display（804 起），
   **仍未合入**（`reports/dup-check-20261125.md:20` 内容级核过 next/for-next 均无）。
   ⇒ 「节点数」不是本板的卡点。**这条也是 (A) 的反面证据：扩范围并不能换来合入。**

### 5.2 为什么不选 (B)（依赖账）

| (B) 需要的块 | 数据在哪（可机械搬） | 会引入的依赖/风险 | 现在能扩吗 |
|---|---|---|---|
| `chosen/stdout-path` | **无来源**：原厂 overlay 只 enable `qupv3_se14_4uart`，那是**蓝牙** UART（下游/ Pengyu 版都是 `serial1 = &uart14` + `bluetooth{}` 子节点）；原厂/下游/Pengyu 三份 DT 全都**没有** `stdout-path` | 写哪个 UART 是**猜**；本机 console 走 USB gadget（`ttyGS0`） | ❌（除非只写 `chosen` + simple-framebuffer，那是另一件事） |
| SPMI PMIC 节点 | `linux:sm8750-lenovo-elden.dts` 的 include 段（第 9–20 行）已给出 pm8550/pm8550ve/pmih0108/pmk8550/pms + `sm8750-pmics.dtsi`；`backup/stock-elden/elden.dts` 的 `&spmi_bus` 8 个 fragment 给了 PMIC 地址表 | 主线的 `pmd8028`/`pmih0108` 与原厂的 `pmd802x`/`pmih010x` **命名不同**，需先确认具体型号（下游已按主线型号写过，可作为旁证） | 🟡（可搬，但需一条条核） |
| `apps_rsc` RPMh regulators（6 个 bank：`b`,`d`,`f`,`g`,`i`,`j`） | `linux:…elden.dts` 第 **855–1299** 行（≈445 行，含每路 min/max/mode）；电压值也可对 `backup/stock-elden/elden.dts`（`regulator-min-microvolt = <0x2625a0>` 等原始值）复核 | 445 行无消费者描述；`dtbs_check` 只能证 schema 对，证不了轨对 | 🟡 |
| UFS（boot storage） | `linux:…elden.dts` 第 2277–2294 行（`&ufs_mem_phy`/`&ufs_mem_hc` + 4 条 supply + `reset-gpios`）；主线 UFS 支持已进（`a95d8e3f40756`，2025-03-27） | 依赖上一条的 RPMh 轨（`vreg_l17b_2p5`/`vreg_l1d_1p2`/`vreg_l3g_1p2`/`vreg_l1j_0p91`） | 🟡 |
| USB | 主线 SM8750 已全齐：`&usb`/`&usb_hsphy`/`&usb_dp_qmpphy` + **`qcom,sm8750-pmic-glink`**（`sm8750-mtp.dts:203-206,1410-1433`） | **但本板是两个 Type-C 连接器**（下游 `port@0`/`port@2`），正是我方 **dwc3 v16**（在飞、未合入）的形态；原厂 `usb-psy-name`（`drivers/usb/dwc3/core.c:2237` 读，**无 YAML**）与 `qcom,preserve-boot-mappings`（`drivers/`+`dtsi` 全树 0 命中 = 死属性）都必须剥掉 | ❌（双口）/ 🟡（单口） |
| `reserved-memory`+`ramoops` | 原厂/下游均有 | **与 M11 pstore initrd-overlap v1（在审，11-25 ping 过）语义直接相关** | ❌ |

⇒ 结论：**(B) 现在做＝一次不可上机验证的 500 行扩张 + 3 个在飞依赖**；这正是「有依赖就不该现在扩」。

### 5.3 (A) 的形态要求（否则就退化成「墙纸文字」）

- 位置：**cover 第一屏**（`Waiting on bindings` 之上或紧邻），标题一句话；2/2 的 changelog 里 2 行索引；
- 内容：**表格为主**（哪块在哪一版），加**一句理由**（未上机验证 + 依赖在飞），**不写论证散文**；
- 不重复 v6–v10 的历史争论；不复述 sashiko 原文；不承诺日期。

文本已备：`patches/upstream/elden-dts-v11-20261126/cover-scope-section.txt`（可直接粘进 cover 与 changelog）。

---

## 6. 是否回复 sashiko 线程：**不回复**（默认），草稿备用

**不回复的理由**（三条，按权重）：

1. **`sashiko-bot@kernel.org` 不是评审人**：它没有 Ack/合入权限；本项目至今对 sashiko 的处置方式一直是
   「在**下一版 cover/提交信息**里逐条答」（v4/v6/v9/v10 都是这个路径），**从不直接回机器人**；
2. **两条都没有新事实**（§2），且 v10 刚发 9 分钟就被回评，此刻回信只会把线程再刷一遍，**给 Bjorn 的收件箱增噪**；
3. **它要的东西恰好是「下一版该写的」**：按 Krzysztof 的口味，答案应在 cover/changelog，而不是在回信里。

**发信条件（三者任一，届时用现成草稿）**：
① 人类维护者（Bjorn/Abel/Konrad/Conor/Krzysztof）在同一线程或新线程重提 core 节点；
② 维护者要求「v11 必须补节点」；③ 用户/总管决定用回信固定口径。

草稿：**`out/mail-20261126/re-sashiko-v10-core-nodes.txt`**（纯 ASCII，`In-Reply-To` = `sashiko-outbox-234789@kernel.org`，
逐条回应 + 每条带证据 + `---` 下 AI 披露 + 不改 v11 计划）。

---

## 7. 下一版需要动哪几个文件（不动 DTS）

| # | 文件 | 改什么 |
|---|---|---|
| 1 | `patches/upstream/elden-dts-v11-20261126/cover-scope-section.txt`（本轮已建） | 现成文本：`Scope of this series, and what follows` 一节 + 2/2 changelog 两行 |
| 2 | `patches/upstream/elden-dts-v11-20261126/v11-0000-cover-letter.patch` | 贴入上一节（在 `Waiting on bindings` 之上）；`Waiting on bindings` 段补一行 next 侧证据（§2 表） |
| 3 | `patches/upstream/elden-dts-v11-20261126/v11-0002-*.patch` | 仅 `Changes in v11:` 两行索引（指向 cover 那一节）；**diff 段与 v10 逐字节相同** |
| 4 | `patches/upstream/elden-dts-v11-20261126/{GATES.md,SENT.md,SEND.sh,SHA256SUMS}` | 沿用 v10 的门禁与投递脚本（diff 未变 ⇒ 门禁可只复跑 checkpatch+dtbs_check 一次） |
| 5 | `TASKS/UPSTREAM.md` M3-DTS 行、`TASKS/dim/D10.md` | 记「v10 sashiko 2 条：均无动作；(A) 裁决；下一版 cover 加 scope 节」（**本轮按纪律未改**）。**顺带发现的漂移**：`TASKS/UPSTREAM.md:25` 的 M3-DTS 行当前仍写「**v9 已投**」，未记 v10 已于 `2026-11-26T05:20:57Z` 投出（`patches/upstream/elden-dts-v10-20261126/SENT.md`）⇒ 下一轮应一并改 |

**不动的**：`patches/upstream/elden-dts-v10-20261126/*`（只读）、任何 DTS 内容、`TASKS/`、`PATCHES/` 既有文件。

---

## 8. 附：若日后转 (B) 的数据源清单（本轮**不执行**，供下一次决策直接用）

| 源 | 路径 | 能取到 | 可信度/限制 |
|---|---|---|---|
| **下游整机 DT（首选）** | `git -C linux show HEAD:arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`（**2359 行**，Pengyu Luo，下游树 `b0c05eb72e101` 2026-09-12 加入） | pmic include 段（9–20）、`aliases`(509–515)、`chosen`+framebuffer(516–535)、`&apps_rsc` 6 bank(855–1299)、`&tlmm`(2005)、`&ufs_mem_phy/hc`(2277–2294)、`&usb*`(2295 起)、`&pmic_glink` 端口拓扑 | 含 vendor 属性（`usb-psy-name`、`mux-state`、`qcom,preserve-boot-mappings`）**必须剥**；未经上游评审 |
| **原厂 overlay（地线）** | `backup/stock-elden/elden.dts`（**16661 行**，`/plugin/`，model = "Sun QRD SKU2 V8 Power Grid"） | `&spmi_bus` 8 个 fragment（PMIC 地址表：`pm8010@c/@d`、`pm8550@1`、`pm8550ve@3/5/6/8`、`pm8550vs@2…@9`、`pmd802x@4`、`pmih010x@7`）；`&ufshc_mem`/`&ufsphy_mem`/`&usb0`/`&sdhc_2`/`&pcie0_rp` 使能；纯数值 `regulator-min/mlcrovolt`；`&qupv3_se14_4uart`(12861) = **蓝牙** | 只是 overlay，**底座是 QRD 基板**（regulators 在基板 dtb 里，overlay 里不全）；变量名是 vendor 的 |
| **原厂 SoC 级 dtb** | `backup/stock-elden/dtb/01..13_*.dtb`（Sun/SunP/Kera/Tuna 等 13 个） | SoC 级节点与部分板级数据；可用于交叉核对 regulator/时钟 | **没有整机合成 DT**（base+overlay 在设备上拼装），不能直接反编译出板级全貌 |
| **上游前作（同文件）** | `reference/upstream-pengyuluo/sm8750-lenovo-elden.dts`（**1096 行**，上游格式，v2 未合入） | `chosen`+simple-framebuffer(33)、`&apps_rsc`(248)、UFS(1023/1030)、USB(9 处)、display(804 起) | 已按上游风格整理，最省转换成本；但**未合入**，且他当时被 changes-requested |
| **上游参考（同 SoC）** | `build/elden-tree/arch/arm64/boot/dts/qcom/sm8750-mtp.dts`（1436 行） | 6 个 RPMh bank、`qcom,sm8750-pmic-glink`(203)、UFS(1412 起)、USB(1410–1433) | 直接可用的「合法形状」模板（binding 全在树内） |

**会引入的新 binding/依赖**（grep 过 `build/elden-tree/Documentation/devicetree/bindings`）：
- 已有、无风险：`simple-framebuffer.yaml`、`qcom,pmic-glink.yaml`、`qcom,sm8750-ufshc`/`sc8280xp-qmp-ufs-phy`、`regulator/*`。
- **没有/不能直接用**：`usb-psy-name`（0 命中，仅 `dwc3/core.c:2237` 读）、`qcom,preserve-boot-mappings`（`drivers/` 0 命中 = 死属性）、
  `qcom,wcn7861-bt`（0 命中 ⇒ M3-6 才谈）。⇒ 这三样若照抄，`dtbs_check` 会立刻变红或写进死属性。
- **在飞依赖**：dwc3 v16（双口 USB 形态，未合入）；M11 pstore initrd-overlap（ramoops 语义）。

---

## 9. 复现命令（本节全部只读）

```bash
# 1) 新信原文 + MID + 挂载点（绕过 Anubis：t.atom 直取 200）
curl -sS -A 'Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0' \
  'https://lore.kernel.org/all/20261126052057.1544590-3-xiaqinghuan@mail.ustc.edu.cn/t.atom' -o /tmp/v10thread.atom
python3 -c "import xml.etree.ElementTree as ET;ns={'a':'http://www.w3.org/2005/Atom'};r=ET.parse('/tmp/v10thread.atom').getroot();[print(e.findtext('a:author/a:email',default='',namespaces=ns), e.findtext('a:updated',default='',namespaces=ns)) for e in r.findall('a:entry',ns)]"

# 2) sashiko 是否进 archive（arm-msm 只是重定向到 devicetree）
#    -> 浏览器/web_fetch: https://lore.kernel.org/linux-arm-msm/sashiko-outbox-234789@kernel.org/

# 3) binding 在哪些树（web_fetch 过 Anubis）
#    for-7.5 / next master / next-20261125 -> 有；torvalds master -> Not found

# 4) 我方 136 行与 gates
grep -c '^+' patches/upstream/elden-dts-v10-20261126/v10-0002-*.patch   # 含 hunk 头，见 GATES.md §12
tail -3 patches/upstream/elden-dts-v10-20261126/logs/checkpatch-v10.txt
tail -3 patches/upstream/elden-dts-v10-20261126/logs/dtbs-check-3dtb-no-binding-20261126.log

# 5) 同族首版 node 清单（浅克隆不可用 --diff-filter=A，改用全历史克隆）
git -C linux show 6a02becf4b42:arch/arm64/boot/dts/qcom/sm8750-mtp.dts | grep -n 'chosen\|stdout-path\|&apps_rsc\|&uart7'
git -C linux log --format='%h|%ad|%s' --date=short v7.4-rc1 -- arch/arm64/boot/dts/qcom/sm8750-mtp.dts

# 6) sm8750.dtsi 默认 disabled
python3 - <<'PY'
import re
L=open('build/elden-tree/arch/arm64/boot/dts/qcom/sm8750.dtsi').read().split('\n')
for n in ['uart7','qupv3_2','gpi_dma2','ufs_mem_hc','usb','mdss','apps_rsc','spmi_bus']:
    for i,l in enumerate(L):
        if re.match(r'^\t+'+n+r':\s',l):
            st=next((m.group(1) for m in (re.search(r'status = "(\w+)"',x) for x in L[i:i+90]) if m),'none')
            print(f'{n:12s} line {i+1:5d} status={st}'); break
PY

# 7) 本树里 chosen/stdout-path 的普及度
cd build/elden-tree/arch/arm64/boot/dts/qcom
echo "total=$(ls *.dts|wc -l) no-stdout=$(grep -L stdout-path *.dts|wc -l) no-chosen=$(grep -L chosen *.dts|wc -l)"
```

---

## 10. 残余风险 / 未证

1. **`(A)` 的实际风险**：sashiko 每版都会重复这条（已 4 轮），人类也可能最终站到它那边；
   (A) 只保证「口径清楚、不被读成隐瞒」，**不保证**它不再出现。触发人类意见时按 §6 条件切草稿/或评估 (B)。
2. **`(B)` 的可行性没有被本轮否证**：PMIC/RPMh/UFS 的数据确实够搬（§8），否掉的是「**现在**做」；
   若将来上机能用上游 DTB 起板，`(B)` 的改法就变成「按 §8 的三源拼 + 剥 vendor 属性 + 单列一条系列」。
3. **console 归属仍未证**：本机没有可用 UART console 的正面证据（只有 `ttyGS0`）；若日后发现调试 UART，
   `chosen/stdout-path` 才可写实值（现在写就是猜）。
4. **未上机**：本报告所有「通过/0 诊断」都是纯静态门；「boots nothing by itself」是**结构性推论**，
   不是本轮实测（v10 也没有上机）。
5. **sashiko 合成的提交号与我们 patch 的 `index` 行不同**（它写 `d9b5cd8f14c6…` / blob `5fb094dd7efc5`，
   我们的 2/2 是 `d8e9ab1272`）。它会自建提交对象，**本轮不据此推断内容差异**：
   它引用的 diff 头是 `@@ -0,0 +1,136 @@` 且含四条 `vin*-supply`，与我方所发一致。
