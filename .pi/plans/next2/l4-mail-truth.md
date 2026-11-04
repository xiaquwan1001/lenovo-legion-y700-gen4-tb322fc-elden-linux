# L4 上游邮件真实情况独立核查（2026-11-04 wl2868c v6 + dwc3 批次）

> 只读 lane，2026-11-04；不采信自报，全部结论带可复现证据。

## A. Sent 复核（2026-10-25 至今我方发出清单 vs reports/ 声称）

证据：`python3 ~/.local/bin/read-mail-ustc.py --days 14 --folders '"Sent Items"' --limit 80`；逐封取头用 /tmp/l4-fetch.py（IMAP fetch BODY.PEEK[HEADER]）。

**本批 10 封全部在 Sent Items（UID 248–257），与自报 Message-ID 前缀逐一吻合**：

| UID | Date（+0800） | Message-ID | Subject | 收件人摘要 |
|---|---|---|---|---|
| 248 | 11-04 11:26:43 | `<20261104032648.209747-1-…>` | [PATCH v6 0/5] regulator: WL2868C | To: Liam Girdwood, Mark Brown；Cc: devicetree/linux-arm-msm/linux-kernel + Bjorn/Konrad/Rob/Krzysztof/Conor |
| 249 | 11:26:44 | `…209747-2-…` | v6 1/5 dt-bindings wl2868c | 同上 |
| 250 | 11:26:45 | `…209747-3-…` | v6 2/5 driver | 同上 |
| 251 | 11:26:46 | `…209747-4-…` | v6 3/5 qcom.yaml Y700 Gen4 | 同上 |
| 252 | 11:26:47 | `…209747-5-…` | v6 4/5 sm8750-lenovo-elden | 同上 |
| 253 | 11:26:48 | `…209747-6-…` | v6 5/5 elden regulators | 同上 |
| 254 | 11:27:03 | `<20261104032706.210042-1-…>` | [PATCH 0/3] usb: dwc3 two Type-C connectors | To: Greg KH, Thinh Nguyen, Rob, Krzysztof, Conor；Cc: linux-usb/devicetree/linux-arm-msm/linux-kernel |
| 255 | 11:27:04 | `…210042-2-…` | 1/3 snps,dwc3 binding | 同上 |
| 256 | 11:27:05 | `…210042-3-…` | 2/3 usb: roles graph endpoint | 同上 |
| 257 | 11:27:06 | `…210042-4-…` | 3/3 dwc3 support | 同上 |

- 自报「wl2868c 6 封 + dwc3 4 封、MID 前缀 20261104032648.209747 / 20261104032706.210042」与 Sent 实况**完全一致**；收件人与报告 §1/§2 所述（To/Cc 集合、无 linux-regulator、无 linux-devicetree）一致。
- 补充事实（自报未写）：dwc3 PATCH 2/3 实际是 `usb: roles` 子系统补丁，收件人仍按 dwc3 系列一份（roles 维护者未单列）。
- 批次内其余 10-25 以来历史投递（v2..v5、mdss、dsi bonded、camss 等共 113 封）在 Sent 中均在档，本批未缺号、无补发痕迹。

## B. 归档复核（patchwork API + lore-query.py，三态表）

证据：`curl -s 'https://patchwork.kernel.org/api/1.2/patches/?project=linux-arm-msm&since=2026-11-03&per_page=200'`（及 `project=linux-usb` 同参）；命中过滤条件 `xiaqinghuan in msgid`。

| 补丁 | patchwork(linux-arm-msm) | patchwork(linux-usb) | state |
|---|---|---|---|
| v6 0/5 (cover) | cover 不作 patch 记录（PW 机制），未见条目 | — | 只能靠 lore |
| v6 1/5 `209747-2` | ✅ 在档 | — | new |
| v6 2/5 `209747-3` | ✅ 在档 | — | new |
| v6 3/5 `209747-4` | ✅ 在档 | — | new |
| v6 4/5 `209747-5` | ✅ 在档 | — | new |
| v6 5/5 `209747-6` | ✅ 在档 | — | new |
| dwc3 1/3 `210042-2` | ✅ 在档 | ✅ 在档 | new |
| dwc3 2/3 `210042-3` (usb: roles) | ✅ 在档 | ✅ 在档 | new |
| dwc3 3/3 `210042-4` | ✅ 在档 | ✅ 在档 | new |

- **8/8 非 cover 补丁全部在档、state=new**（PW 索引时间 2026-11-04T03:26:44–03:27:06Z，与发送时刻逐秒吻合）→ 归档面自报成立。
- lore（经 lore-query.py Anubis PoW 路径，非 /raw 200 判据）：两个 cover 直接按 MID 取 thread 页均在档：
  - `https://lore.kernel.org/linux-arm-msm/20261104032648.209747-1-…/T/` →「[PATCH v6 0/5] … 6+ messages in thread」，收件人列表与 Sent 逐字一致，含 AI-assistance disclosure；
  - `https://lore.kernel.org/linux-arm-msm/20261104032706.210042-1-…/T/` →「[PATCH 0/3] … 4+ messages in thread」，含披露段。
- 注意：lore 搜索索引（`?q=xiaqinghuan`）截至本核查只回 10-13 及更早条目，11-04 批次未进搜索索引（索引进档存在已知滞后）；按 MID 直取在档，所以判定「在档」。

## C. 回信复核（2026-11-04 02:12Z 之后 INBOX/Junk 新回信 / 退信）

证据：`read-mail-ustc.py --days 2`（INBOX 12292–12351 / Junk 251–302，截取窗口 02-Nov–04-Nov）；正文逐封用 /tmp/l4-body.py。

**INBOX 中指向本批的回信共 7 封，全部来自 sashiko-bot@kernel.org（AI 审查机器人），无维护者直接回信、无 DSN/退信**：

| 收到(UTC) | 指向 | 结论 |
|---|---|---|
| 03:34:41 | dwc3 2/3 (usb: roles) | 无问题（2 封重复投递 12330/12331） |
| 03:38:51 | v6 2/5 driver | **3 Medium**：`chip->enabled` 未初始化 / `vsys-supply` enable 缺失 / disable 时 regmap_write 失败致状态失同步 |
| 03:41:59 | v6 4/5 板 DTS | **1 Medium**：base 板 DTS 未上机验证（引 Konrad v5 意见，追问为何提前入系列） |
| 03:42:00 | v6 5/5 regulators | **1 Medium**：pmic@2f 无 SPMI PMIC/RPMh/消费者支撑（引 Konrad v5） |
| 03:44:09 | dwc3 3/3 | **2 High**：`dwc3_role_mux_init()` 竞争+teardown 顺序颠倒；`dwc3_mux_role_set()` port/role 状态撕裂 |
| 03:44:30 | dwc3 1/3 binding | **3 Medium**：oneOf 可能漏 endpoint/mux-state required、顶层 ports schema 缺 port@2、mux binding 偏 Linux 专用 |

- **退信面：0 封 DSN / 0 封 postmaster / MAILER-DAEMON**（INBOX+Junk 全窗口核对）→ 自报「0 退信」成立。
- Junk：窗口内最后一封 11-03 13:21+0100；无本批回信漏进 Junk。旧批 Krishna 11-02 对 v5 的回信在 Junk UID 256（属上批，非本批）。
- **我方待办**（均为审阅意见，非必答不可但建议 v7 或逐条回应）：dwc3 3/3 两条 High 优先；wl2868c driver 3 条 Medium；DTS 两条可复用 v6 cover 已有回应，但 sashiko 追问了；binding 3 条 Medium。

## D. 结论：本批投递真实状态 + 下次发信前必修流程问题

**结论：自报属实。** 10 封（v6 6 + dwc3 4）Sent 在档、MID 逐字一致；8/8 非 cover 补丁 patchwork 双项目（linux-arm-msm + linux-usb）在档 state=new；两个 cover lore thread 页在档；0 退信。但「发完=可等 review」不成立：**sashiko-bot 已给 2 High + 8 Medium**，dwc3 3/3 优先。

下次发信前必修流程问题：
1. `read-mail-ustc.py` 的 `OUR_IDS` 只有 3 个 10-12 老 MID ⇒ `--replies-only` 漏新系列回信（本次实证：sashiko 7 封只能靠 --days 全列）。改为从 Sent 动态取近 N 天 MID 或维护滚动清单。
2. `--folders "Sent Items"`（不带引号）触发 IMAP `SELECT BAD`（实证见下方 E 前的坑记录）——脚本默认值已带引号，但调用方必须传带引号版本，写进调用规范。
3. patchwork 匿名 `?msgid=` 恒返 `[]`，归档复核必须用 `since` + msgid 子串过滤；lore 搜索索引滞后（11-04 批次未进 `?q=` 索引），按 MID 直取 `/T/` 页为准，不要用搜索结果缺号判「未在档」。
4. cover letter 在 patchwork 永远查不到（非 patch 对象），「N/N 命中」的口径应写「非 cover N/N」避免误读。
5. 发信前若目标含 roles/USB 子系统，收件人按文件单独跑 `scripts/get_maintainer.pl`，不要整系列一份 To/Cc（本次 2/3 是 roles 补丁仍按 dwc3 名单发）。
6. sashiko-bot 是实际第一响应者（投递后 ~7 分钟回）；每次投递后应把 sashiko 结论并入盯 review 表，不等人类维护者。

## E. 自报与事实不一致点（若有）

未发现实质不一致。两处口径性补充：
1. 报告 §0 表「patchwork 索引 5/5、3/3」实际口径 = 非 cover 补丁；cover 不入 patchwork（机制所致，非投递失败）。lore 侧 cover 已实证在档。
2. 报告写「未出现任何退信」成立，但未提**sashiko-bot 已回 2 High + 8 Medium 审查意见**（03:34–03:44Z 即到达）——不算不实，但「盯 review」清单已过时，见 C 节待办。

坑记录：`read-mail-ustc.py --folders "Sent Items"`（无引号）→ `imaplib: SELECT command error: BAD [b'Request not ending with  ']`；必须传 `--folders '"Sent Items"'`。

## 未完成 / 卡点

- `?msgid=` 匿名 404/空疑似 patchwork 需鉴权（`/api/1.2/people/` 实测要求 credentials），未深究，绕过方案已写入 D-3。
- TASKS/README.md §7 头的表述未逐字比对（只核了数字口径 8 枚/0 退信，与报告一致）。
- sashiko 高/中危意见的代码正确性未逐条复核（本 lane 只核投递事实，不审代码）。
