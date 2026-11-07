# 上游回包增量复核 — 2026-11-07

> 只读 lane：未发信、未改 patchwork、未碰设备；本文件为唯一新增。
> 基线 = `reports/upstream-status-20261105.md`（截至 11-05 02:40Z，含 11-06 §5 追记）；
> 事件背景 = `out/mail-20261106/REPORT.md`（11-06 投 dwc3 v8 + wl2868c v8）。
> 增量窗 = 11-05 02:40Z → 11-07 本轮复核。

## §0 一句话结论

**增量窗（11-05 02:40Z → 11-07 09:40Z）新增回信 4 封**（sashiko 对 dwc3 v8 2/3、3/3 各一封「no issues」= 11-04 两条 High 的修复被机器评审确认；Rob Herring 对 wl2868c binding 2 条 changes-requested；Conor 对 wl2868c v8 1/2 pw-bot「changes-requested」）；**我方欠 1 项返工（2 个技术点）** = wl2868c binding YAML（v9：description 段落加 `>` 块修饰符 + example 删固定 regulator 供给方）。dwc3 两条 High 与 Krzysztof 11-04 两条 changes-requested 均已被 v8 修掉/拆出，**无未答**。

## §1 逐系列表

patchwork 增量口径：`patches/?submitter=xiaqinghuan@mail.ustc.edu.cn&since=2026-11-05` = **26 条**（全部为 11-06 批，即首轮 11:28/11:30 13 枚 + v8 11:42 13 枚？实为首轮 8 枚 + v8 8 枚 + 系列 id 分散，见 artifacts `pw-since1105.json`）；全量自 10-25 = 194 条。原始 JSON：`reports/artifacts/upstream-20261107/pw-since1105.json`、`pw-since1025.json`。

| 系列 | 11-07 归档状态（patchwork id 证据） | 新增回信 | 我方欠什么 | 复启条件 |
|---|---|---|---|---|
| **M3-1 dwc3 v8**（`[PATCH v8 0/3]`，cover `<20261106114208.987284-1>`） | linux-usb 3/3 `new`（14957383–85，series 1204116）；arm-msm 3/3 `handled-elsewhere`（14957386–88）；devicetree 1/3 `needs-ack` + 2/3,3/3 `handled-elsewhere`（14957397–99）。**首轮无 `-vN` 批**：arm-msm 已 `superseded`（14957349–51）、wl2868c 首轮 arm-msm 2/2 `superseded`（14957352–53），**但 linux-usb 首轮 3/3 仍 `new`**（14957345–47，未标 superseded） | **2 封 sashiko**：2/3 `found no issues` `<sashiko-outbox-201358@kernel.org>`；3/3 `found no issues` `<sashiko-outbox-201364@kernel.org>` | **0 项**。11-04 两条 High（锁序撕裂 / err-path teardown）v8 已修且机器评审通过；1/3 binding 等 Rob/Krzysztof 人工（现 `needs-ack`）。**注意**：linux-usb 首轮 3 枚未被 patchwork 判为旧版，后续若标 superseded 属正常，勿当新事件 | 等 1/3 binding 人工回信；0 条即不动 |
| **wl2868c v8**（`[PATCH v8 0/2]`，cover `<20261106114252.988023-1>`） | arm-msm 2/2 `handled-elsewhere`（14957389–90）；devicetree 1/2 `needs-ack`（14957395）+ 2/2 `handled-elsewhere`（14957396）；**Conor pw-bot 已回 `changes-requested`（见 §2），patchwork needs-ack 可能随后自动翻红** | **2 封**：Rob（对 v6 1/5）`<20261106141036.GA2921668-robh@kernel.org>`；Conor（对 v8 1/2）`<20261106-lucrative-sadden-741ffe6c43e9@spud>` | **1 项返工（2 技术点），见 §2-1/§2-2** → binding v9。Krzysztof 11-04 两条（5/5 并 4/5、3/5 commit message）已由「板 DTS 整段拆出（held-back）」覆盖 ✔；sashiko 11-04 的 driver 三条 Medium 已在 v8 2/2 修 ✔，但 2/2 尚无 sashiko/Mark 回信 | 出 v9 binding（含 §2 两点）；2/2 driver 等 Mark Brown/sashiko；板 DTS 待三处意见收敛后再议 |
| **M8 mdss v3** | 无增量（本窗 0 新 patch 记录；此前 3+3 在档） | 0 | 0（维持 11-05 口径：有 Abel R-b，只等 1/3、2/3 人工） | 等 Dmitry/Konrad；不改内容 |
| **M4-2 camss v2** | 无增量 | 0（Bryan 11-07 发的是他自己的 camss SOF v3 系列，非针对我方） | 0（等 Bryan） | 等 Bryan |
| **M4-1 bindings（gt9764/s5kjns）** | 无增量 | 0 | Krzysztof 10-28 两条仍待并入 v2（11-05 已记，无新增） | 出 v2 时并入 |
| **aw86927 / M2-A2 battmgr / M1-U6 q6v5_pas / M9** | 无增量 | 0 | 维持 11-05 口径 | 不变 |

## §2 未答意见逐条

### 已答/已修（确认，不需动作）

1. **dwc3 11-04 两条 High** — v8 已修：sashiko 2/3（`<sashiko-outbox-201358@kernel.org>`，In-Reply-To `<20261106114208.987284-3-…>`）与 3/3（`<sashiko-outbox-201364@kernel.org>`，IRT `<20261106114208.987284-4-…>`）均 "found no issues"。✔ 已覆盖。
2. **Krzysztof 11-04 wl2868c 两条 changes-requested**（5/5 拆补丁 `<20261104-elfish-booby-of-awe-27d2b6@quoll>`；3/5 compatible 措辞 `<20261104-offbeat-cerulean-degu-cfec1b@quoll>`）— v8 已把板 DTS 整段拆出（held-back），binding+driver 两枚不含板件。✔ 已覆盖（以「拆出」方式，需在 v9 cover 里向 Krzysztof 点明一句）。
3. **sashiko 11-04 wl2868c driver 三条 Medium** — v8 2/2 已修（chip->enabled 种子化 / vsys 使能 / disable() 写成功才提交），尚无新评审回信，不算欠。

### 仍未答（我方欠）

- **§2-1 [binding, v9 必改] wl2868c YAML 多段 description 缺 `>` 块修饰符**
  Rob 11-06 14:10Z（对 v6 1/5，正文引用现 v8 1/2 同一处）："With paragraphs, you need '>' modifier."
  位置 = `willsemi,wl2868c.yaml` 顶层 `description:` 与 `vin7-supply/vsys-supply` 的多段 description。msgid `<20261106141036.GA2921668-robh@kernel.org>`。
- **§2-2 [binding, v9 必改] example 里不得出现固定 regulator 供给方**
  Rob 同信："Drop. We don't put providers into examples." — 即 example 中 `vsys_reg: regulator-vsys`（`compatible = "regulator-fixed"`）整段删除，`vsys-supply = <&vsys_reg>` 引用一并处理（或改 phandle 到不存在的 label 之外的正确形态：example 只放 consumer 侧，provider 移出）。
- **§2-3 [流程] Conor 对 v8 1/2 已打 pw-bot changes-requested**
  Conor 11-06 17:12Z："Rob's feedback on v6 was ignored … pw-bot: changes-requested"，msgid `<20261106-lucrative-sadden-741ffe6c43e9@spud>`，IRT v8 1/2 `<20261106114252.988023-2-…>`。
  判读：**非新意见**，是 §2-1/§2-2 的升级器——v8 在 Rob 回信（14:10Z）之前 28 分钟投出（11:42Z），非「无视」而是时序竞态；v9 回信里**礼貌说明这一点**即可，勿自辩过火。
- **§2-4 [待观察，非欠] dwc3 1/3 binding 与 wl2868c 2/2 driver** 无人工回信；patchwork `needs-ack`/`new`。不主动 ping。

## §3 建议动作

1. 【主机侧可做】出 wl2868c binding v9：YAML description 改 `>` 折叠块（3 处）+ example 删 `vsys_reg` provider；cover 中说明「v8 投出早于 Rob 回信 28 分钟，属时序而非忽略」，并点明板 DTS 已按 Krzysztof 意见拆出。
2. 【需投递批准】v9 发信（binding 1 封 + cover，In-Reply-To 串到 v8 cover `<20261106114252.988023-1-…>`）。
3. 【主机侧可做】dwc3 v8 与 wl2868c 2/2 继续静默等待；下一轮复核时重查 sashiko 对 v8 1/3、wl2868c 2/2 的机器评审与 patchwork `needs-ack`→人工状态迁移。
4. 【主机侧可做】清理首轮无 `-vN` 批残留：linux-usb 3 枚仍 `new`（14957345–47）+ devicetree 首轮 needs-ack，观察 patchwork 是否随 v8 自动 superseded；如 v9 前仍未收敛，可在下次获批发信时用 cover 附带说明。
5. 【主机侧可做】保留 artifacts：`pw-since1105.json`、`pw-since1025.json`、`inbox-headers.json` 为本轮唯一证据链。
6. 【需用户核实】（沿用 11-05 §2-6）GitHub OAuth 第三方应用告警仍未处理，与本 lane 无关，提醒一次。

---

复核方法（只读）：IMAP `EXAMINE` + `BODY.PEEK`（`SINCE 05-Nov-2026`，INBOX 2804 封非我方、命中我方系列 msgid 前缀 4 封；Junk 未扫——11-05 结论无历史先例，本轮 INBOX 已全命中）；patchwork API 1.2，无凭据。口令全程未打印、未落盘（编排者复核时 `/tmp/pw.txt` 已不存在；凡临时落地即删）。

DONE-UPSTREAM-DELTA-20261107
