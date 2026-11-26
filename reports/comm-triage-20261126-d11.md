# 通信复扫 D11（2026-11-26T04:20Z → 05:55Z + GitLab 面）— 只读

> **只读纪律**：本文件是本轮唯一写入（未发信、未推 MR、未改 `TASKS/`、未 commit 之外的既有报告）。
> IMAP 全程 `BODY.PEEK` + `readonly=True`；凭据运行时从 keyring 取（图形会话已解锁，`keyring` 直取成功）。
> 外部命令均套 `timeout -k`；GitHub/GitLab 走公开 API（`--noproxy '*'`）。
> 增量基线 = `reports/comm-triage-20261126-d10.md`（覆盖到 **2026-11-26T04:20Z**）。

---

## ① 头条

| 指标 | 值 | 明细 |
|---|---|---|
| 本轮新人类消息 | **0** | — |
| 本轮新机器人消息 | **1** | sashiko 对 **elden v10 2/2**（`05:30:05Z`）：**2×`[Medium]`** |
| 我方新投出 | **2 件** | M6 DSI-PHY **v3**（`05:20:54Z`）+ elden 板 DTS **v10** 3 封（`05:20:58Z–05:21:04Z`），全 250 |
| 我方欠动作 | **1 项（判定后为 0）** | sashiko 两条都已由 v10 cover/SENT 记录覆盖（见 §3） |

一句话：**投出的两件在档无新人类评审**；v10 的 sashiko 复审两条 Medium 均为「预期现象 / cover 已声明不包含」，**不需要改 DT，也不需要回信**。

---

## ② A 面：IMAP（三箱，`SINCE 26-Nov-2026`）

判据命令：`timeout -k 5 180 python3 /tmp/d11_scan.py`（D10 脚本改窗口；`BODY.PEEK`）。

```
STATUS INBOX OK "INBOX" (MESSAGES 10435 UIDVALIDITY 1)
STATUS "Junk E-mail" OK "Junk E-mail" (MESSAGES 216 UIDVALIDITY 5)
STATUS "Sent Items" OK "Sent Items" (MESSAGES 374 UIDVALIDITY 3)
LAST INTERNALDATE INBOX     = 2026-11-26T05:35:25Z | Re: [PATCH v10 2/2] …elden…
LAST INTERNALDATE Junk      = 2026-11-25T18:28:56Z | Re: [PATCH v3 2/7] camss: …
LAST INTERNALDATE Sent      = 2026-11-26T05:21:04Z | [PATCH v10 2/2] …
rows after cut 04:20Z: 6
```

增量 6 行（逐条）：我们的两件在 INBOX 的自回副本（`05:20:54Z` M6 v3）+ Sent 副本 4 行（M6 v3、v10 cover/1/2、2/2）+ **sashiko 对 v10 2/2**（`05:35:25Z`，`In-Reply-To <20261126052057.1544590-3-…>`）。
Junk 无新件；无退信（DSN）。

---

## ③ sashiko 对 v10 2/2 的两条 `[Medium]`（判定：都不需要动作）

| # | 意见 | 判定 | 依据 |
|---|---|---|---|
| 1 | `willsemi,wl2868c` binding **不在目标树** ⇒ `make dtbs_check` 对 `pmic@2f` 报 undocumented | **预期现象，无需动作** | v10 cover 第 12 行 `Waiting on bindings` 专节点名 binding + 两个提交号（`84e67d2ee13f` binding / `602f57223457` driver，均已进 `regulator.git for-7.5`）+ 合并顺序；sashiko 只审「当前分支」不读 cover |
| 2 | 缺 core boot / 电源节点（`chosen/stdout-path`、SPMI PMIC、`apps_rsc` RPMh regulators、storage、USB、display） | **已在 cover 声明不含，无需动作** | v10 cover 明写首版范围 = board clocks + reserved GPIO + camera PMIC，「Not included, and not claimed to work」；`patches/upstream/elden-dts-v10-20261126/SENT.md` §「回应关系」② 已记 |

**口径提醒**：sashiko 是 AI 评审机器人，其意见是**提示**而非维护者裁决；维护者（Bjorn/Krzysztof/Conor）至今对 v10 未回。
⇒ **不主动回 sashiko 线程**（会把机器人线程顶上列表）；若维护者自己提出同一问题，按 §3 依据回答。
后续动作已派 lane R（`reports/dts-v10-sashiko-20261126.md`）核对「首版该不该带 core 节点」的 qcom 惯例，结论落 v11 cover 方向。

---

## ④ B 面：GitLab（mobian / phosh 上游）

| 件 | 现查 | 判读 |
|---|---|---|
| `mobian1/droid-juicer !46` | `state=opened` · `detailed_merge_status=mergeable` · **`user_notes_count=0`**（人类 note 0）· `updated_at=2026-11-23T11:10:29Z` · `sha=ea9fe3d5` | **≈74 h 零变化、零人类回复**；仓库队列慢（6 open MR，!45 自 10-11）⇒ 不催 |
| `salsa.debian.org/Mobian-team/mobian-recipes` qcom 三处 | 上次核 = 11-25（`devices/qcom/configs/wip.toml` 空模板、`packages/`+`droid-juicer/` 只有 `.gitkeep`） | 硬前置仍是「内核 deb 先有」⇒ 不重复核 |
| `World/Phosh/phoc` **issue #125**（back gesture） | web_fetch 现查：**最后一条 note = 2023-02-17**（alicem「leaning towards client side」/ guidog「two/three finger swipe close」）⇒ 无新增讨论 | 我方 lisgd 路线仍最优（`TASKS/dim/D13.md`） |
| `World/Phosh/phoc` open MR | **13 条**（上次 14）· 最新更新 !827 `2026-11-25` · 前 5：828/827/819/805/788 | 无 edge-swipe/back 相关新件；!827（11-25）值得下一轮看一眼是不是手势相关 |
| gitlab.com `scope=created_by_me` | MR 1（仅 !46）/ issue 0 | 无遗漏面 |

> GitLab API 备注：`gitlab.com` 公开项目 API 免 token 可用；`gitlab.gnome.org` 的 `/notes` 端点 **401**（需 token），故 phoc #125 用 `web_fetch` 渲染页核（与 11-25 口径一致）。

---

## ⑤ 下一步（按判读，不是命令）

0. **在两飞件（M6 v3 / v10 2/2）等窗口**：距今 < 1 h，无需动作；patchwork 摄取滞后数十小时 ⇒ **lore 为准**。
1. **dwc3 v16**：sashiko 已 "no issues"（11-25），静默中 ⇒ 等 Bjorn/Greg 取件或回信。
2. **M8 / M10 / M11 三件换址补发（11-25T02:23Z）** 距今 ≈27 h，0 回音 ⇒ 到 **11-27** 再判是否二次 ping（避免连续 ping）。
3. phoc `!827`（2026-11-25 更新）下一轮顺带核一次主题，判断是否与手势/deck 相关（若是，可作为我方 lisgd 方案的上游对接口）。
