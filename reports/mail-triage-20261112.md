# 上游邮件增量分诊 — 2026-11-12（窗口 2026-11-11T08:08Z → now）

> 基线：`reports/mail-triage-20261111b.md`（窗口止 **2026-11-11T08:08Z**）。
> 本轮窗口 = **2026-11-11T08:08Z → 2026-11-12T13:31Z**（UTC，取报告落笔时现查时刻）。
> 纪律：只读侦察。零发信、零设备写、未改 SSOT/版本账、无 git commit；唯一产物 = 本文件。
> 数据源：**patchwork API 1.2**（`https://patchwork.kernel.org/api/1.2/`）为唯一档证据；
> lore `/raw` 被 Anubis 挡，**不作档证据**（仅在本轮显式标注「未采信」处出现）。

## §1 现查命令与时间戳

（本节记录本轮实际跑过的命令与原始返回码/条数，便于复现）

> 排版说明：§1 正文在**本文件末尾**（原作者留下的位置），本节标题下原样保留，本轮未改动其内容。

## §2 逐系列表（最新 revision / state / commit_ref / reviewer tag）

现查时刻 **2026-11-12T13:31Z**（`date -u`；§1 落笔时刻之后约 4h51m 又跑了一轮）。
口径：**§2–§6 覆盖窗口 2026-11-11T08:08Z → 2026-11-12T13:31Z**（= §1 头部声明的窗口），
并在每行标 `[08:40前]` / **`[08:40后]`**（=`§1` 基线之后的严格增量）以便与下一轮对齐。
全部请求 `curl -sS --noproxy '*'` + `-w '%{http_code}'`，**HTTP 200**（23 个 patch 端点 + 2 个 series 端点 + 1 个 checks 端点）。

我方 patchwork 总量（`/patches/?submitter=…&per_page=100`，**238 条** = page1 100 + page2 100 + page3 38，page3 为 `rel="last"`）：
`superseded` 123 / `handled-elsewhere` 60 / `new` 44 / `changes-requested` 5 / `not-applicable` 4 / `needs-ack` 1 /
`awaiting-upstream` 1 —— **`accepted` 0 条** ⇒ 截至本轮**无任何已合并**（§3 结论层）。

### §2.1 窗口内的 revision 变化（step 1）

| 系列 | revision | 首封时间(UTC) | 窗口内动作 | 证据 |
|---|---|---|---|---|
| **wl2868c** | **v10（新投出）** | 2026-11-11T11:11:31 `[08:40前]` | 11-11T11:11Z 投出 v10（cover `<20261111111132.1296892-1-…>`），**把 v9 全部顶成 superseded** | series `1208264`（linux-arm-msm）/ `1208267`（devicetree）<br>`https://patchwork.kernel.org/api/1.2/series/1208264/` |
| wl2868c | v9 | 2026-11-07T01:50:13 | `14959745`/`14959744` 由 `handled-elsewhere` → **`superseded`** | `https://patchwork.kernel.org/api/1.2/patches/14959745/` |
| **M10（fastrpc non-secure-domain）** | v3（无新 rev） | 2026-11-11T03:57:31 | 窗口内**无新 rev**，仍 `new` | `https://patchwork.kernel.org/api/1.2/patches/14971025/` |
| **dwc3 双 Type-C** | v8（无新 rev） | 2026-11-06T11:42:06 | 窗口内**无 v9 投出**（series 列表里 11-06 之后无 dwc3 条目） | `https://patchwork.kernel.org/api/1.2/series/1204116/` |
| **mdss v3** | v3（无新 rev） | 2026-11-02T05:50:24 | 窗口内**无新 rev**，但 dri-devel 三份副本被 `archived=True` | `https://patchwork.kernel.org/api/1.2/patches/14931321/` |

⇒ step 1 结论：**08:40Z 之后（strict 增量）我方零新投递、零新 revision**；窗口内唯一新 revision = **wl2868c v10**（11-11T11:11Z，落在 08:08→08:40 那段）。

### §2.2 逐 patch 状态表（step 2）

| 系列 / patch | project:id | state | commit_ref | archived | tags | comments（条数 / 最新） |
|---|---|---|---|---|---|---|
| **wl2868c v10 1/2** binding | linux-arm-msm `14972055` | `new` | `None` | False | `{}` | 1 / **Rob `Reviewed-by`** 11-11T15:50:24Z |
| **wl2868c v10 2/2** driver | linux-arm-msm `14972056` | `new` | `None` | False | `{}` | 1 / **Mark Brown 提问** 11-11T17:42:43Z |
| wl2868c v10 1/2 (dt 副本) | devicetree `14972059` | `not-applicable` | `None` | False | `{}` | 1（同 Rob 的 RV，镜像） |
| wl2868c v10 2/2 (dt 副本) | devicetree `14972060` | `handled-elsewhere` | `None` | False | `{}` | 1（同 Mark Brown，镜像） |
| wl2868c v9 1/2 | linux-arm-msm `14959745` | **`superseded`** | `None` | False | `{}` | 1 / Rob RV 2026-11-09T14:54:04Z（历史 tag，随 v9 作废） |
| wl2868c v9 2/2 | linux-arm-msm `14959744` | **`superseded`** | `None` | False | `{}` | 0 |
| wl2868c v9 1/2、2/2 (dt) | devicetree `14959749`/`14959748` | `not-applicable` / `handled-elsewhere` | `None` | False | `{}` | 0 |
| **M10 v3** | linux-arm-msm `14971025` | `new` | `None` | False | `{}` | **0** |
| M10 v2 | linux-arm-msm `14966246` | `superseded` | `None` | False | `{}` | 0 |
| **dwc3 v8 1/3** binding | linux-usb `14957383` | `new` | `None` | False | `{}` | 0 |
| dwc3 v8 2/3 roles | linux-usb `14957384` | `new` | `None` | False | `{}` | 1 / sashiko 11-06T11:47:57Z（旧） |
| dwc3 v8 3/3 dwc3 | linux-usb `14957385` | `new` | `None` | False | `{}` | 1 / sashiko 11-06T11:52:05Z（旧） |
| dwc3 v8 1/3 (dt 副本) | devicetree `14957399` | **`needs-ack`** | `None` | False | `{}` | 0；**checks: `dt-meta-schema` = fail**（2026-11-07T02:26:25Z，`build.log`） |
| dwc3 v8 2/3、3/3 (dt) | devicetree `14957398`/`14957397` | `handled-elsewhere` | `None` | False | `{}` | 0 |
| **mdss v3 1/3** binding | dri-devel `14931320` / arm-msm `14931323` / devicetree `14931334` | `new` / `handled-elsewhere` / `not-applicable` | `None` | **True / False / False** | `{}` | 1 / Rob Ack 11-10T19:27:44Z（旧） |
| **mdss v3 2/3** drm/msm | dri-devel `14931321` / arm-msm `14931324` | `new` / `handled-elsewhere` | `None` | **True** / False | `{}` | 1 / **Dmitry Baryshkov 提问** 11-11T14:19:30Z |
| **mdss v3 3/3** DTS | dri-devel `14931322` / arm-msm `14931325` | `new` | `None` | **True** / False | `{}` | 2 / Abel RV 11-02T13:17:55Z + **Dmitry `Reviewed-by`** 11-11T14:18:31Z |

三条判读要点：
1. **`tags` 字段依旧全空**（`{}`）——与 11-11b §4 同一现象：patchwork 不把 Acked-by/Reviewed-by 解析进 `tags`，
   判接收**只能读 comment 正文**。本轮 Rob→v10 1/2、Dmitry→mdss 3/3 两个新 tag 均在 comment 里。
2. **`commit_ref` 全为 `None`、`state=accepted` 0 条** ⇒ 截至 2026-11-12T13:31Z **没有任何我方 patch 进 maintainer 树**。
3. **dwc3 v8 1/3 的 dt 副本 `dt-meta-schema` = fail** 是新查到的硬证据（此前只记 `needs-ack`）：
   `https://patchwork.kernel.org/api/1.2/patches/14957399/checks/`。这与 Rob 的结构性 changes-requested 一致 ⇒ 该 binding 不改过不了 CI。

DONE §2

## §3 新 reviewer tag 与未答问题

全量扫描口径（保证不漏）：`/patches/?submitter=…` 三页共 **238** 条，取其中 `new`/`needs-ack`/`changes-requested`/
`awaiting-upstream`/`handled-elsewhere` **111 条**逐条拉 `/patches/<id>/comments/`（111 请求，全 200），
过滤 `date >= 2026-11-11T08:08:00`；另拉 4 个窗口内 cover 的 comments（`14169578`/`14169579`/`14165241`/`14165242` 等，全 0 条）。
→ **窗口内新外部 comment 共 5 条正文 / 10 份 patch 副本**（每份系列在两个 project 各一份副本），发件人只有 3 人：
Rob Herring、Dmitry Baryshkov、Mark Brown。**M10 v3、dwc3 v8 全系、camss 系列、dsi bonded 5 连发：窗口内 0 新 comment。**

### §3.1 新 reviewer tag（3 个）

| # | 目标 patch | 评审人 | 时间(UTC) | tag（comment 原文行） | 证据 |
|---|---|---|---|---|---|
| T1 | **wl2868c v10 1/2** `14972055` | Rob Herring (Arm) | 2026-11-11T15:50:24 | **`Reviewed-by: Rob Herring (Arm) <robh@kernel.org>`** | `https://patchwork.kernel.org/comment/27361802/`<br>msgid `<179441222370.2975760.8038836403367934702.robh@kernel.org>` |
| T2 | **mdss v3 3/3** `14931322`/`14931325` | Dmitry Baryshkov | 2026-11-11T14:18:31 | **`Reviewed-by: Dmitry Baryshkov <dmitry.baryshkov@oss.qualcomm.com>`** | `https://patchwork.kernel.org/comment/27361322/`（arm-msm 镜像 `/comment/27361314/`）<br>msgid `<fglkl4ksxin2citf44fvrjrqupz2a7asbuwxmkja6dbgu5stcx@uyjfipsp2njl>` |
| T3 | **drm/msm/dpu gamma LUT** `14884121` | Dmitry Baryshkov | 2026-11-11T16:58:23 | **`Reviewed-by: Dmitry Baryshkov …`**（同一封里还给了一条 `Fixes: 39a750ff5fc9 ("drm/msm/dpu: Add DSPP GC driver …")`，即**要求我方把这个 Fixes 补进 patch**） | `https://patchwork.kernel.org/comment/27361985/`（arm-msm 镜像 `/comment/27361977/`）<br>msgid `<h346otfneexdgpndvmydknzuxuljywvflaoss3xppblp4k2svo@wcanozcwnysb>` |

T1 的连带结论：`reports/mail-triage-20261111b.md` §5 那句「若 v10 动 1/2 则 Rob 的 Reviewed-by 作废」**已消解**——
v10 投出后 Rob 于 4h39m 后**重新给了 RV**（v9 的 RV 在 `14959745` 上，已随 `superseded` 失效，但 v10 拿到新的一份）。

### §3.2 新问题 / 新增要求（3 条，均**未答**）

| # | 出处 patch | 提问人 | 时间(UTC) | 原文要点（逐字） | 证据 |
|---|---|---|---|---|---|
| Q1 | **wl2868c v10 2/2** `14972056` | Mark Brown | 2026-11-11T17:42:43 | 「Should the driver not also override the **LDOx_SEQ** registers to make sure we have software control of them, or **hide the enable/disable ops if they're non-zero**?」——即：`LDOx_SEQ` 若被固件置位，per-LDO 使能就不受软件控制，要么主动覆盖 SEQ、要么在这种情况下隐藏 `enable`/`disable`。 | `https://patchwork.kernel.org/comment/27362144/`<br>msgid `<179441896388.393238.285161772971892952.b4-review@b4>` |
| Q2 | **mdss v3 2/3** `14931321` | Dmitry Baryshkov | 2026-11-11T14:19:30 | 两点：①「**Is it an interrupt controller?**」（质疑 commit message 里「INT2 interrupt controller」的措辞）；②「**What is the side effect of it? How was it tested?**」（要求写清不 reset 的副作用 + 测试方法）。 | `https://patchwork.kernel.org/comment/27361323/`（镜像 `/comment/27361315/`）<br>msgid `<awb7bslhrhemsgvu7ubaejvurk6fecotgvqlwtvsoe2benqdgq@tvh2sfjbuzyu>` |
| Q3 | **dsi/phy PLL_SYSTEM_MUXES** `14901898` | Dmitry Baryshkov | 2026-11-11T17:09:07 | 「**This belongs to the commit message rather than the code.**」——把 hunk 里那段 9 行注释移到 commit message。**不是 NAK，无 tag**。 | `https://patchwork.kernel.org/comment/27362009/`（镜像 `/comment/27362015/`）<br>msgid `<e4ul4zxjta4oyo5fpjjzwkykb4gicztcn7yrgjw7aer6bqowkw@6nx2arhvmyca>` |

### §3.3 「已合并」判定：**0 条**

- 238 条 patch 中 `state=accepted` **0**、`commit_ref` 非空 **0**（逐条打印核对，见 §2.2）。
- 窗口内 commit_ref **没有一次从 `None` 变为非空**。
- 反向证据（防「patchwork 落后于 maintainer 树」）：`archived=True` 只出现在 mdss v3 的 dri-devel 三份副本
  （`14931320`/`14931321`/`14931322`，本轮**新出现**），但同系列 `commit_ref` 仍为 `None`、`state` 仍 `new`
  ⇒ **`archived` 只表示「人工归档/线程已处理」，不等于已应用**。这条判据以后直接引用本节。

### §3.4 顺带核实：wl2868c **v10 已消化 v9 的 sashiko B1–B3**（不是新要求，是欠账结清）

v9↔v10 diff（API `diff` 字段逐行比，`14959744` → `14972056`，9056 B → 10759 B）确认三处都改了：

| 11-11b 的欠账 | v10 实际改动 | 位置 |
|---|---|---|
| B1 reset 早于 vsys 使能 | `devm_gpiod_get_optional(…, "reset", GPIOD_OUT_**HIGH**)` + 注释说明 devres 逆序unwind；新增 `wl2868c_reset_assert()` | probe |
| B2 只有 `vin7-supply` 的板子 | 新增 `wl2868c_enable_control_supply()`：`devm_regulator_get_enable_optional("vsys")` 失败再退 `"vin7"` | probe 前段 |
| B3 `chip->enabled` 未校验 SYS_EN | 只有 `value & WL2868C_SYS_ENABLE` 为真才 `chip->enabled = value & WL2868C_LDO_ENABLE_MASK` | probe 读 `LDO_ENABLE` 处 |

另有清理：`MAINTAINERS` 的 `F: drivers/regulator/…` 从 1/2 移到 2/2；binding 示例补 `vin12-supply`（1/2，+1 行）。

DONE §3

## §4 新外部回信 / 退信

只读 IMAP 复核（`EXAMINE` + `BODY.PEEK[...]`，每夹**重新登录**以避开 Coremail `BAD [Request not ending with]`；
`secret-tool lookup service smtp` 取密码，未打印未落盘；夹名必须带引号 `"Junk E-mail"`/`"Sent Items"`，否则 SELECT 失败）。
脚本 `/tmp/laneB_imap2.py`（本轮现写，只读）。

| 项 | 值 | 说明 |
|---|---|---|
| INBOX `SINCE 11-Nov-2026` | 1273 行 / 窗口内 **898** | 列表流量为主；**未做 Message-ID 去重**（本轮不需要精确计数） |
| Junk E-mail | 23 行 / 窗口内 23 | 无我方线程命中 |
| Sent Items | 4 行 / 窗口内 **3** | 只有 wl2868c v10 的 0/2、1/2、2/2（11-11T11:11Z 三条）⇒ **窗口内我方仅此一次投递** |
| 给我方线程的外部回信 | **5 条 / 5 个唯一 MID** | = §3 的 T1/T2/T3/Q1/Q2/Q3 里 5 个不同 MID（Q2 的镜像不算）；全部与 patchwork comment 的 msgid **逐字一致**（交叉校验通过） |
| 其中人类署名 | 5/5（Rob 1、Mark Brown 1、Dmitry 3） | 无 sashiko-bot 新回信 |
| 退信 / 投递失败（我方 patch） | **0** | `grep -iE 'Bounce|undeliver|Delivery Status|postmaster|mailer-daemon'` 窗口内仅 1 命中，见下 |
| Junk 命中我方线程 | 0 | — |

唯一的 bounce 类来信（**非我方投递失败，无需动作**）：

- `linux-pm+owner@vger.kernel.org`，2026-11-12T08:31:40Z，msgid `<1794472300-1742782-mlmmj-3ffe9489@vger.kernel.org>`，
  Subject `Bounce probe for linux-pm@vger.kernel.org (no action required)`。
  正文：vger 投给我们的某封 linux-pm 邮件**被我校邮件服务器当垃圾拒收**（被拒的是
  `https://lore.kernel.org/linux-pm/20261112080532.30774-1-shaunakkdatar@gmail.com/`，别人的补丁），
  mlmmj 发探针确认连通性正常。⇒ 只说明「列表整封垃圾邮件被拒」，**不涉及我方 patch 或我方外发**。

补充判读：本窗口**没有任何维护者直投（To 只有我、不经列表）的回信**——11-11b 记录的
「Rob Herring 直投 ack」（11-10 16:36Z `<20261110163640.GA85824-robh@kernel.org>`）模式本轮未复现；
本轮 5 条全部是**列表 + 直接 Cc** 双份（因此 INBOX 里成对出现，也是行数虚高的原因）。

DONE §4

## §5 我方欠项（逐条，含是否需用户批准）

放行口径沿用 `TASKS/README.md` §7：**发信（含纯回信/新版本/ping）一律需用户逐系列批准**；本 lane 只侦察，**未发任何信**。

| # | 系列 / patch | 现状（本轮证据） | 欠什么 | 需用户批准? |
|---|---|---|---|---|
| W1 | **wl2868c v10 2/2** `14972056` | Mark Brown 11-11T17:42Z 提 `LDOx_SEQ` 问题（§3.2 Q1），**未答**；1/2 已拿 Rob RV | 二选一回应：①核查 `LDOx_SEQ` 复位值/固件是否置位，在 probe 里主动清零 SEQ（保住软件控制）；②若无法保证，则在 SEQ 非 0 时 `hide` enable/disable（Mark 给的备选）。**先要量设备侧 `0x??` SEQ 寄存器实测值**，再决定是否出 v11 | **是**（回信或 v11） |
| W2 | **mdss v3 2/3** `14931321` | Dmitry 11-11T14:19Z 两问（§3.2 Q2），**未答**。1/3 = Rob Ack、3/3 = Abel RV + **Dmitry RV（新）** ⇒ 只剩 2/3 挡合入 | 把「INT2 是否真是中断控制器」的措辞改准（查 SM8750 dispcc 复位表与 `mdss_intr` 实现），并补「不 reset 的副作用 = command DMA timeout / 只有背光无 DRM 设备」+「测试方法 = 设备实测（U2/vk127 复现路径）」进 commit message | **是**（回信；改 commit message 需重发 v4） |
| W3 | **drm/msm/dpu gamma LUT** `14884121` | **Dmitry 给了 RV**，同时要求补 `Fixes: 39a750ff5fc9`（§3.1 T3）；补丁 2026-10-13 投出，**一个月才回** | 出 v2：加 `Fixes:` 行、正文与 RV 原样保留（tag 可随 v2 继承） | **是**（v2 = 新版本） |
| W4 | **dsi/phy PLL_SYSTEM_MUXES** `14901898` | Dmitry 11-11T17:09Z 要求「9 行注释移进 commit message」（§3.2 Q3），无 tag | 出 v2：注释搬到 commit message，代码不变 | **是**（v2） |
| W5 | **dwc3 v8 0/3–3/3** `14957383/84/85`（dt `14957399` 另带 `dt-meta-schema` **fail**） | Rob 11-10T16:36Z 结构性 changes-requested（`port@0` 双 endpoint、删 `port@2`、`port-select-gpios`→gpio mux）；v9 **未投出**；binding 草案在 `patches/upstream/dwc3-v9-draft-20261111/`，**driver/DTS 未改** | ①`drivers/usb/dwc3/drd.c` 换 `devm_mux_control_get` + `mux_control_select(…, endpoint->mux_state)`；②sm8750 DTS 改双 endpoint；③再跑 `dt_binding_check` + `dtbs_check` | **是**（v9），且**当前不具备投递条件** |
| W6 | **M10 v3**（fastrpc non-secure-domain）`14971025` | 投出 **33.5 h**（11-11T03:57Z → 11-12T13:31Z），patchwork `new`、**0 comment**、0 回信 | 无。11-11b 已核实逐条满足 Konrad+sashiko 两条 Low | 否（继续等） |
| W7 | **wl2868c v10 1/2** `14972055` | Rob RV（T1），`state=new`、`commit_ref=None` | 无 | 否 |
| W8 | **mdss v3 1/3** `14931320`、**3/3** `14931322` | Ack + RV + RV（T2），但同系列 2/3 未过 ⇒ 整串不会单独合入 | 无（等 2/3） | 否 |
| W9 | **dsi bonded 5 连发** `14930241…`（10-31）、**camss 9 连发 v2** `14920907…`（10-28）、**camss 3 fixes** `14928877…`（10-31） | 窗口内 **0 新 comment / 0 回信**；全部 `state=new`、`commit_ref=None` | 无（无新增要求）。⚠ 这三串**上一份报告完全没登记**，属分诊盲区 | 否 |

**本轮不建议**：对 M10 v3、wl2868c v10、dwc3 v8 任何系列发 ping/resend（最新意见距今 ≤ 26 h，dwc3 已明确在返工）。

DONE §5

## §6 卡点与本轮未覆盖

### §6.1 卡点（挡住下一步的硬约束）

1. **`LDOx_SEQ` 无设备实测值**（挡 W1）：`reports/` 与 `.pi/memory/` 里没有 WL2868C `SEQ` 寄存器（`0x??`）的读回值，
   而 Mark 的两个选项取决于「固件是否把 SEQ 置位」。要答得准，**必须在 U2 上 i2c 读一次**——属设备动作，
   本 lane 无授权、未做。
2. **mdss 2/3 的措辞问题需要 DT/驱动事实**（挡 W2）：「INT2 是否 interrupt controller」要查
   `sm8750 dispcc` 复位表与 `drivers/gpu/drm/msm/msm_mdss.c` 里 `mdss_intr` 的实际用法；本轮未展开取证，
   只确认了 Dmitry 的质疑点（他引的那句在 2/3 的 commit message 第 4 行）。
3. **dwc3 v9 的 driver 未动**（挡 W5）：`mux_control_select` 持锁到 `mux_control_deselect`，与 role-switch
   回调（可能中断上下文）的兼容性**仍未评估**（11-11b §6b-1 的欠账原样保留，本轮未推进）。
4. **patchwork `tags` 字段恒空**（`{}`，238 条全查）：任何「按 tag 过滤/排序」的路子都不可用，
   tag 只能逐 comment 正则。这是本 lane 每轮都要重复付的成本（111 次 comments 请求）。

### §6.2 未覆盖 / 已知盲区

| # | 盲区 | 影响 | 下一步 |
|---|---|---|---|
| U1 | **未核 maintainer 树是否已悄悄应用**（无 `commit_ref` 也可能是 patchwork 没跟上，或已被 `next` 分支吸收） | 「0 已合并」这个结论只对 **patchwork 侧**成立 | 需一个有上游 git 访问的 lane 跑 `b4`/查 `next`/`drm-misc-next` |
| U2 | **lore `/raw` 被 Anubis 挡**（本轮未用，标注**未采信**） | 无法核对「只在 lore、未进 patchwork comment」的回复（11-11b 已发现 sashiko 三条 Medium 就属此类） | 沿用仓库 `scripts/lore-fetch-raw.py`；本 lane 未跑 |
| U3 | **IMAP 未按 Message-ID 去重** | §4 的 898/23/3 是**行数**不是唯一封数（列表副本 + 直投 Cc 会成对） | 需要精确计数时按 11-11b §1 的 json 去重流程 |
| U4 | **Sent Items 只有 4 封**（邮箱 11-02 被 `mailbox-cleanup-20261102.py` 清理过） | 更早的我方外发无法从邮箱侧复核；窗口内只看到 v10 三条 | 历史外发以 `out/mail-*` 为准 |
| U5 | **v10 由谁产出未掌握**（本 lane 未参与；11-11b §6b-2 当时记「wl2868c v10 driver 改动未做」） | v10 内容我已逐行核实（§3.4 消化 B1–B3），但**它的构建/门禁日志不在本报告** | 由产出方补门禁记录 |
| U6 | **cover 只抽查 6 个**（窗口内 v10 ×2、dwc3 v8 ×2、mdss v3 ×2，均 0 新 comment；dwc3 v8 cover `14167685` 上是 11-10 的旧 Rob 评论） | 理论上可能有「回复到 cover」的新意见漏检 | 下轮把 `/covers/` 全量 54 个按 `date>=窗口` 过一遍 comments |
| U7 | **旧账未登记（跨轮盲区，最该修的）**：11-11b 只跟踪了 4 个系列，实际在审还有 **dpu gamma LUT、dsi/phy PLL_SYSTEM_MUXES、dsi bonded 5 连发、camss 9 连发、camss 3 fixes** —— 本轮正是靠「238 条全量扫 comments」才把 Dmitry 11-11 的三条捞出来 | 若沿用「只查已知 4 系列」的做法，**11-11 的 3 个新 tag/要求会全部漏掉** | 建议 SSOT 侧把「在审系列清单」固化（总管并入 `TASKS/`），分诊每轮全量扫 |

### §6.3 计数复核（一句话给总管）

窗口内 **238 条 patch / 54 个 cover 中，111 条在审 patch 全量扫 comments ⇒ 5 条新外部回复（Rob 1、Dmitry 3、Mark 1）、
3 个新 tag（2×Reviewed-by + 1×Reviewed-by 附带 Fixes 要求）、3 个未答问题、0 条已合并、
0 封退信；唯一新 revision = wl2868c v10（11-11T11:11Z）**。

DONE §6

## §1 现查命令与时间戳

落笔现查时刻：**2026-11-12T08:40Z**（`date -u` → `Thu Nov 12 08:40:32 UTC 2026`）；仓库 HEAD `5beef79fc6`（`git log -1`，2026-11-12 14:53 +0800）。

patchwork API 1.2（本轮实际命令，全部 HTTP 200）：

```sh
# ① 我方的全部系列（86 个，按 date 倒序取最新 14 个）—— 用于确认「有没有新 revision 投出」
curl -sS -G 'https://patchwork.kernel.org/api/1.2/series/' \
  --data-urlencode 'submitter=xiaqinghuan@mail.ustc.edu.cn' --data-urlencode 'per_page=100'
# ② 按 project 拉我方 patch（★坑：project 链接名不是邮箱列表名）
#    arm-msm ✗ 空 / linux-usb ✓ / dri-devel ✓ / linux-pm ✓ / devicetree ✓ → 正确名是 linux-arm-msm
curl -sS -G 'https://patchwork.kernel.org/api/1.2/patches/' \
  --data-urlencode 'project=linux-arm-msm' \
  --data-urlencode 'submitter=xiaqinghuan@mail.ustc.edu.cn' \
  --data-urlencode 'per_page=100' --data-urlencode 'order=-date'
# ③ 逐 patch 取 state/commit_ref/archived/tags + comments 正文
curl -sS 'https://patchwork.kernel.org/api/1.2/patches/14972055/'
curl -sS 'https://patchwork.kernel.org/api/patches/14972055/comments/'
```

两个 API 坑（本轮新踩，值得记）：
- `order=-date` **必须**与 `project=` 或 `series=` 同用，否则 **HTTP 400**
  `{"detail":"This ordering must be limited with one of these parameters: project, series"}`（不带 order 只回最早几条）。
- `--noproxy '*'` 写错成 `-noproxy '*'` 会让 curl 静默失败（`HTTP 000`）——对比 `--max-time` + `-w '%{http_code}'` 才能发现。
- `patches/<id>/` 里的 `comments` 字段是**字符串 URL**（`https://patchwork.kernel.org/api/patches/<id>/comments/`，**注意无 `1.2`**），不是列表；当列表遍历会 404。
