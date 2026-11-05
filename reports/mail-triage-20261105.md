# 上游邮件增量分诊 — 2026-11-05

> 上一份分诊：`reports/mail-triage-20261104.md`（窗口止 **2026-11-04 02:12Z**）。
> **本轮窗口**：2026-11-04 02:12Z → **2026-11-05 02:40Z**（抓取时刻，UTC）。
> 本轮 **只读**：`M.select(box, readonly=True)`（EXAMINE）+ `BODY.PEEK[]`/`BODY.PEEK[HEADER.FIELDS …]`。**无 STORE / COPY / EXPUNGE / MOVE，无 `\Seen` 写入**。未发信、未改 patchwork、未碰设备、未改既有文件、未 commit。
> 直接结论：**窗口内新增外部回信 8 条（6 sashiko + 2 Krzysztof）、0 封退信；我方 0 封外发被弹**。

---

## §0 口径

| 项 | 值 |
|---|---|
| 通道 | IMAP `mail.ustc.edu.cn:993`；口令只从 GNOME keyring `secret-tool lookup service smtp` 取（未落盘） |
| 文件夹 | `INBOX` / `"Junk E-mail"` / `"Sent Items"`（Junk 名必须带引号） |
| 抓取 | `SINCE 03-Nov-2026` ⇒ **2635 条头**（INBOX 2617 / Junk 8 / Sent 10），实际跨度 11-03 → 11-05 02:39Z |
| 归属于我方的判据 | `References`/`In-Reply-To` 命中 `mail.ustc.edu.cn`，或 `From` 是我方地址 |
| 窗口内命中 | 窗口后条目 1314 条 → 去重 943 MID → **严格归属我方 18 条**（10 封我方投递副本 + 8 条外部回信） |
| 脚本 | `/tmp/laneA/scan.py`（头表）、`/tmp/laneA/body.py`（正文）、`/tmp/laneA/sent.py`（Sent 全表） |

**引用面**：全部 6 封 sashiko 都以我方 11-04 Message-ID 为 `In-Reply-To`（逐封核对，见 §1）；不存在「只进 Junk 的维护者回信」（Junk 窗口内唯一一封 = Jacopo Mondi 的 mali-c55 线程，与本项目无关）。

---

## §1 窗口内外部回信（8 条，全表）

| # | 时间(UTC) | 发件人 | 系列 / 分片 | 性质与摘要 | Message-ID | INBOX seq |
|---|---|---|---|---|---|---|
| 1 | **11-04 03:34:41** | sashiko-bot | dwc3 `2/3`（roles） | **无问题**：*"Sashiko has reviewed this patch and found no issues."* | `<sashiko-outbox-196610@kernel.org>` | 12330 / 12331 |
| 2 | 11-04 03:38:51 | sashiko-bot | wl2868c `v6 2/5`（driver） | **3 × Medium**：`chip->enabled` 未初始化（boot 已开的 LDO 位被后续整字节写清）；`vsys-supply` 从未 request/enable（probe 读 DEVICE_ID 时可能无供电 / late_cleanup 关掉未认领 supply）；`disable()` 先清位后写盘（写失败 ⇒ core `use_count=1` 但 `chip->enabled` 已丢位） | `<sashiko-outbox-196615@kernel.org>` | 12332 |
| 3 | 11-04 03:41:59 | sashiko-bot | wl2868c `v6 4/5`（板 DTS 骨架） | **1 × Medium**：板 DT 只有 clocks + gpio-reserved-ranges，缺 SPMI/RPMh/console/存储 ⇒ 引 Konrad v5 原话，问是否应随 PMIC/使用者一起发 | `<sashiko-outbox-196620@kernel.org>` | 12335 |
| 4 | 11-04 03:42:00 | sashiko-bot | wl2868c `v6 5/5`（WL2868C regulators） | **1 × Medium**：vin12/34/5/7 父 supply 未描述、`wl2868c_vsys` 是无约束 `regulator-fixed` ⇒ 六路 LDO 全落 dummy 父 | `<sashiko-outbox-196621@kernel.org>` | 12336 |
| 5 | 11-04 03:44:09 | sashiko-bot | dwc3 `3/3`（dwc3 mux） | **2 × High**：① `dwc3_mux_role_set()` 在放锁期间让 `__dwc3_set_mode()` 读到「新 `mux->desired_port` + 旧 `dwc->desired_dr_role`」撕裂；② `dwc3_role_mux_init()` 端口 1 注册失败时 `cancel_work_sync()` 早于 `usb_role_switch_unregister()`，work 可在 `dwc->role_mux=NULL` 后跑 / 在 `role_mux_exit()` 里解引用 NULL | `<sashiko-outbox-196628@kernel.org>` | 12337 / 12339 |
| 6 | 11-04 03:44:30 | sashiko-bot | dwc3 `1/3`（binding） | **3 × Medium**：`oneOf` 里 endpoint/mux-state 未 required；顶层 `ports` 缺 `port@2`；Linux 专有 mux 绑定与 `port@2` 拆分的形状问题 | `<sashiko-outbox-196629@kernel.org>` | 12338 / 12340 |
| 7 | **11-04 10:30:22** | **Krzysztof Kozlowski** | wl2868c `v6 5/5` | **changes-requested**：*"I do not understand why this is a separate patch. You add new hardware, so the commit is 'add new hardware'. One logical action, one commit."* ⇒ 5/5 并入 4/5 | `<20261104-elfish-booby-of-awe-27d2b6@quoll>` | 12606 / 12607 |
| 8 | **11-04 10:31:30** | **Krzysztof Kozlowski** | wl2868c `v6 3/5`（`arm/qcom.yaml`） | **changes-requested（措辞）**：*"Board cannot be shipped with such compatible - it's first time usage here. 'Add Lenovo Legion Y700 Gen4, an Qualcomm SM8750-based tablet'."* ⇒ commit message 改写 | `<20261104-offbeat-cerulean-degu-cfec1b@quoll>` | 12609 / 12610 |

**严重度合计**：**2 High + 8 Medium**（分散在 6 封 sashiko 里）—— 与派工单给的「2 High + 8 Medium」一致。

### §1a 对派工单「7 封 sashiko」的独立复核 ⇒ **实为 6 封（唯一 MID）**

- 窗口内 `From: sashiko-bot` 共 **75 封唯一 MID**，其中 `References/In-Reply-To` 命中我方的**只有 6 个 MID**（上表 #1–#6）。
- 复现：`/tmp/laneA/scan.py 03-Nov-2026` 生成 `hdr.json` 后按 `sashiko` + `mail.ustc.edu.cn` 过滤；逐 MID 计数 = 6。
- 6 个 MID 在 INBOX 共占 **8 个序号**（12330/12331、12332、12335、12336、12337/12339、12338/12340）—— 列表副本 + 直达副本各一。**若把副本当邮件数会得到 8，把「2 High 那封」拆成两条会得到 7**，二者都不是唯一信数。
- 归属核对：6 封的 `In-Reply-To` 与 11-04 投递的 6 个 patch MID 一一对应（`20261104032648.209747-3/-5/-6`、`20261104032706.210042-2/-3/-4`），**无错挂**。
- 结论：**「7 封」不可复现；以 6 封 / 2 High + 8 Medium 为准。**

---

## §2 逐系列「有没有新意见」

| 系列 | 窗口内新意见 | 依据 |
|---|---|---|
| dwc3 `0/3`（11-04） | **有 3 条**（sashiko 2/3 无问题、1/3 三 Medium、3/3 两 High） | 上表 #1/#5/#6；人类维护者 0 条 |
| wl2868c `v6 0/5`（11-04） | **有 5 条**（sashiko 3 封共 5 Medium + Krzysztof 2 封 changes-requested） | 上表 #2/#3/#4/#7/#8 |
| M8 mdss `v3 0/3` | 无 | 窗口内无命中；Abel Vesa Reviewed-by 仍在 11-02 |
| M4 camss `v2 0/2` | 无 | 11-04 的 camss 讨论（Loic/Bryan/Vladimir/Nihal/Allan/Jacopo）全部是**别人的线程**，`References` 不含我方 MID |
| M6/B5 `0/5` | 无 | 最后外部来信仍是 Dmitry 10-31 20:31Z |
| M4-1 gt9764/s5kjns | 无 | 最后外部来信 Krzysztof 10-28 13:29/13:31Z |
| aw86927 | 无 | 10-27 18:06Z 之后 0 条（本窗再次确认） |
| M2-A2 / M1-U6 | 无 | 投递后 0 条 |
| M9 | 无 | 已撤回 |

---

## §3 退信 / DSN / 订阅确认

窗口内 `From`~`postmaster|mailer-daemon|Mail Delivery|Undelivered` 与主题含「退信」的**命中 0 封**。
⇒ 11-04 两批（wl2868c v6 收件人含 `devicetree@`/`linux-arm-msm@`/LKML，dwc3 收件人含 `linux-usb`/`devicetree`/`linux-arm-msm`/LKML，均不含 `linux-regulator@`、`linux-devicetree@`）**全部投递成功**。对照 11-02 批的 6 封 550（`linux-regulator@` 不存在）已不重复。

---

## §4 Sent Items 交叉核对（我方外发）

`Sent Items SINCE 25-Oct-2026` = **108 封**，按日：10-26 6 / 10-27 14 / 10-28 27 / 10-29 10 / 10-31 26 / 11-02 15 / 11-04 10。

- 窗口内（11-04 02:12Z 起）我方外发 = **10 封**，全部为 11-04 那两批：Sent[248]–[253]（wl2868c v6 `-1..-6`）、Sent[254]–[257]（dwc3 `-1..-4`）。
- **窗口内我方 0 封非投递外发**（无回信、无 ping）⇒ 8 条外部意见**一条都还没被回复**。
- 11-02 的 Sent[233] 是一封非上游事务邮件（标题为编码后的中文），不计入上游台账。

---

## §5 行动表（本轮判断，供编排者/用户裁决；本轮不执行）

| # | 项 | 上游最新 | 我方欠什么 | 需用户批 |
|---|---|---|---|---|
| C1 | **dwc3 3/3 两条 High** | sashiko 11-04 03:44:09Z | 改锁序（`dwc3_set_mode()` 前不放开 `dwc->lock` 的可见窗口，或让 `__dwc3_set_mode()` 在同一临界区快照两字段）+ err 路径先 unregister 再 `cancel_work_sync()` | 改补丁需另派；发 v6 需批 |
| C2 | **dwc3 1/3 三条 Medium** | sashiko 11-04 03:44:30Z | binding：`oneOf` 补 required、顶层补 `port@2`、把 Linux 专有 mux 属性挪出 DT schema 讨论 | 同上 |
| C3 | **wl2868c driver 三条 Medium** | sashiko 11-04 03:38:51Z | `chip->enabled` 从硬件回填、request/enable `vsys-supply`、`disable()` 写成功后再清位 | 同上 |
| C4 | **wl2868c 板 DTS/regulators 两条 Medium** | sashiko 11-04 03:41/03:42Z + Krzysztof 11-04 10:30Z | 5/5 并入 4/5；板 DT 与 PMIC/使用者一起发（或给出理由）；3/5 commit message 改写 | 同上 |
| C5 | 归档口径 | — | 已按 patchwork 复核（见 `upstream-status-20261105.md` §1），无需动作 | 否 |
| C6 | GitHub OAuth 告警（11-02 15:14Z, Junk 294） | 历史项 | 需**用户本人**核实 | **是** |

---

## §6 复跑命令

```bash
# 1) 头表（只读 EXAMINE；输出 /tmp/laneA/hdr.json）
python3 /tmp/laneA/scan.py 03-Nov-2026
# 2) 8 条回信正文（sashiko 6 + Krzysztof 2）
python3 /tmp/laneA/body.py x 'INBOX:12330' 'INBOX:12332' 'INBOX:12335' 'INBOX:12336' 'INBOX:12337' 'INBOX:12338' 'INBOX:12606' 'INBOX:12609'
# 3) Sent 全表 + 按日计数
python3 /tmp/laneA/sent.py
# 4) sashiko 唯一性（6 个 MID / 75 封唯一 sashiko）
python3 - <<'EOF'
import json;d=json.load(open('/tmp/laneA/hdr.json'))
u={r['mid'] for r in d if r['date']>='2026-11-04T00:00' and 'sashiko' in r['frm'].lower()}
print(len(u), sum('mail.ustc.edu.cn' in (r['refs']+r['irt']) for r in d if r['mid'] in u))
EOF
```

DONE-MAILTRIAGE-20261105
