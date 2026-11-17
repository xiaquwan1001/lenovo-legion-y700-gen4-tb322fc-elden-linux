# 上游邮件收件核查（截止 2026-11-17 13:40 UTC / 11-17 21:40 CST）

> 只读调查：未发信、未 `git send-email`、未动设备、未改任何 SSOT 文件。
> 全部外部命令带 `timeout -k 5`；每条事实附文件+行号或 URL+时间。
> 本文件与 `reports/upstream-replies-20261117.md`（昨日同主题）互补：本文聚焦 **2026-11-14 以来的新回帖 + 9 个在飞系列逐一对账**。

## 0. 结论（数字先行）

| 项 | 数字 |
|---|---|
| 2026-11-14 00:00 UTC 以来收到的人类回帖 | **2 封**（Rob Herring 11-16 对 wl2868c **v11**；Bryan O'Donoghue 11-15 对我方 CSIPHY **RFC**） |
| 同期收到的 bot（sashiko）回帖 | **8 封**（mdss v5 ×3 于 11-13；board v7 ×1、dwc3 v9 ×3、haptics v2 ×1 于 11-17） |
| 9 个在飞系列里「有人类回帖」的 | **1 个**（wl2868c，且是 v11 而非 v12） |
| 真正**零回复**（既无人也无 bot） | **3 个**：pstore、dsi-phy v2、dpu-gamma v2 + 1 个未投（camss-csiphy-24-v2） |
| 需我方动作的回帖 | **4 件**：dwc3 v9（bot High×2）、haptics v2（bot High×1）、board v7（bot Medium×3，属预期内）、wl2868c（tag 已闭合） |
| `--replies-only` 口径 | **失效**（脚本硬编码 3 个旧 Message-ID），非通道问题，见 §1 |

## 1. 工具状态：`--replies-only` 恒为 0，必须换判据

任务给的第一条命令实测 **0 封**，而同窗口 Sent Items 有 41 封（说明通道 OK、过滤口径错）：

```
$ timeout -k 5 180 /home/xuqianhui/.local/bin/read-mail-ustc.py --days 4 --replies-only
=== INBOX : 0 封（SINCE 13-Nov-2026）=== [replies-only]
=== "Junk E-mail" : 0 封（SINCE 13-Nov-2026）=== [replies-only]
=== "Sent Items" : 0 封（SINCE 13-Nov-2026）=== [replies-only]
$ timeout -k 5 180 /home/xuqianhui/.local/bin/read-mail-ustc.py --days 7   # 无 --replies-only
=== INBOX : 3530 封 … |  === "Sent Items" : 41 封（SINCE 10-Nov-2026）===
```

- 根因：`~/.local/bin/read-mail-ustc.py:13-15` 的 `OUR_IDS` 只硬编码了 **3 个 2026-10 的旧 Message-ID**
  （`179184923104…/179179331695…/179184859459…`），11 月所有系列的 MID 都不在里面 ⇒ 恒 0。
- 本次替代判据（只读、`BODY.PEEK` 不改已读状态）：临时脚本按「精确 MID 前缀出现在 `In-Reply-To`/`References`」+「系列唯一主题片段」双判据扫 INBOX/Junk/Sent（脚本 `/tmp/mail-probe3.py`），
  再用 lore 独立复核：`~/.local/bin/lore-query.py 'https://lore.kernel.org/<list>/?q=<MID 前缀>'`
  （`curl` 直连 lore = **403**，需过 Anubis；证据：`curl -s "https://lore.kernel.org/all/?q=s%3A…" -w '%{http_code}'` → `403`）。

## 2. 2026-11-14 以来收到的回复（逐条）

### 2.1 人类回帖（2 封）

| # | 发件人 | 日期 (UTC) | 线程 | 一句话要点 | 要我们做什么 | 是否升级 |
|---|---|---|---|---|---|---|
| 1 | Rob Herring `<robh@kernel.org>` | **2026-11-16 15:10:52** | `Re: [PATCH v11 1/2] regulator: dt-bindings: willsemi,wl2868c: …`（mid `<20261116151052.GA1449968-robh@kernel.org>`） | 「Missing my Reviewed-by tag. It's your responsibility to add tags when sending new versions.」并再次给出 `Reviewed-by: Rob Herring (Arm)` | **新版本必须带上已有 R-b tag**（不针对代码） | **已闭合**：v12 的 1/2 已带该 tag（`patches/upstream/wl2868c-v12-20261117/v12-0001-*.patch:25`），cover 也写明「v11 重发丢了 tag」（同目录 `v12-0000-cover-letter.patch:18,26,29`）。**不需要回信** |
| 2 | Bryan O'Donoghue `<bod@kernel.org>` | **2026-11-15 17:44:06** | `Re: [RFC] phy: qcom: mipi-csi2-3ph: SM8750 ships CSIPHY 2.4.0 lane table - preferred shape?`（mid `<57ea8341-…@kernel.org>`，lore `linux-phy` 命中） | 要求「先基于 on-list 的 8750/Kaanapali（Hangxiang v25，patchwork series 33877）」；并直言「LLM output pretty difficult to understand」 | **不是补 tag，而是换基线 + 换写法**：重基到 v25 `[01..03]`，信里去掉 AI 风格铺陈 | **需人决策**：v2 重基已完成、6 道门全绿但**未投**（`patches/upstream/camss-csiphy-24-v2-20261117/README.md:11`「状态：备料，未投」）。投递仍需逐系列批准；投递时**必须**明写「无上机实测」 |

### 2.2 bot（sashiko）回帖（8 封，均 `sashiko-bot@kernel.org`，无需回信但要逐条判真伪）

| # | 线程/补丁 | 日期 (UTC) | 要点 | 要我们做什么 | 是否升级 |
|---|---|---|---|---|---|
| 3 | m8-mdss **v5** `1/3`、`2/3`、`3/3` | **2026-11-13 16:05 / 16:08 / 16:12** | 3 封 bot 报告（lore `dri-devel` 命中 `sashiko-outbox-213154/213159/213171`） | 逐条判真伪；**至今 3.9 天未处理也未回帖** | **建议升级为待办**：这是 9 个系列里唯一「bot 报告积压近 4 天、无人跟进」的 |
| 4 | board DTS **v7**（单提交） | **2026-11-17 05:34:06** | Medium×3 + Low×1：`lenovo,elden` 未文档化、`willsemi,wl2868c` binding/驱动不在树、DT 缺 platform 骨架、phandle 非字母序 | 见下 | **不是代码 bug，是我方送件口径的已知后果**，见 §3.1 |
| 5 | dwc3 **v9** `2/3` | 2026-11-17 05:27:41 | High：`__dwc3_set_mode()` 里 `mux_control_deselect()` 可能不配对（初始 mode 切换时 `active_port=-1` 却 deselect；`mux_control_select()` 失败后 `active_port` 未回 -1） | **自查代码、有则修**（发 v10 前） | **需升级（High）**：属真 bug 候选，不是风格问题 |
| 6 | dwc3 **v9** `3/3` | 2026-11-17 05:37:39 | High：`dwc3_drd_exit()` 未 `mux_control_deselect()`，卸载后 mux 锁不释放 | 同上（`devm` 释放只 `put` 不 deselect） | **需升级（High）** |
| 7 | dwc3 **v9** `1/3` | 2026-11-17 05:40:08 | 第 3 封（binding 侧，低价值/一般性意见） | 判断即可 | 否 |
| 8 | haptics **v2** `6/6` | 2026-11-17 05:46:20 | High：`close()` 清 `level` 后 ff-memless 定时器仍可能再排 `play_work`；`devm aw86927_reset()` 未 `disable_work_sync()` ⇒ unbind 期竞态；Low：commit message 与实现口径不一致（suspend/shutdown） | **自查并补 `disable_work_sync()`/竞态处理**；改 commit message | **需升级（High）** |

> bot 报告均在 list 归档可查（`https://lore.kernel.org/linux-usb/sashiko-outbox-218216@kernel.org/` 等），
> 逐封归档判据：`lore-query.py 'https://lore.kernel.org/linux-usb/?q=20261117052137.32833'` → 7 条中 3 条为 `Re:`。

## 3. 与 9 个在飞系列对账

| 系列 | MID（本次判据） | 发送 (UTC) | 人类回帖 | bot | 结论 |
|---|---|---|---|---|---|
| pstore-ram-initrd-overlap-20261116 | `20261116040049.434247-{1,2,3}` | 11-16 04:01 | **0** | **0** | 零回复；lore `lkml` 查询只回我方 3 枚 |
| wl2868c v11 | `cover.1794557667` / `9ab5e593…git.xiaqinghuan` | 11-13 08:19 | 1（Rob 11-16，= #1） | 0 | 已由 v12 闭合 |
| wl2868c v12 | `20261117052257.34849-{1,2,3}` | 11-17 05:23 | 0 | 0 | 刚发 8.3 h；tag 已带 |
| m8-mdss v5 | `20261113155635.1677541-{1..4}` | 11-13 15:56 | **0** | 3（= #3） | 零人类回复 3.9 d；我方 11-17 12:17 CST 已自回一封补 Q28 证据（Sent #296，`In-Reply-To: …-1-`） |
| dsi-phy v2 | `20261116150334.78710-1`（首）/`20261117052047.32129-1`（重发） | 11-16 15:03 / 11-17 05:21 | **0** | **0** | 零回复；上一版 v1（10-19）等 Dmitry 用了 **3 周**（11-11 才回，mid `<e4ul4zxj…@6nx2arhvmyca>`） |
| board DTS v7 | `20261117052029.31900-1` | 11-17 05:20 | 0 | 1（= #4） | 零人类回复 |
| dwc3 v9 | `20261117052137.32833-{1..4}` | 11-17 05:21 | 0 | 3（= #5–7） | 零人类回复；v8 时 Rob 曾 11-10 回（`<20261110163640.GA85824-robh@…>`） |
| dpu-gamma v2 | `20261117052046.32092-1` | 11-17 05:21 | **0** | **0** | 零回复；v1（10-13）等 Dmitry **29 天**后才回（11-11 `<h346otfn…@wcanozcwnysb>`） |
| haptics v2 | `20261117052112.32527-{1..7}` | 11-17 05:21 | 0 | 1（= #8） | 零人类回复 |
| camss-csiphy-24-v2 | — | **未投** | — | — | 备料态（`camss-csiphy-24-v2-20261117/README.md:10`），不在飞 |

### 3.1 board DTS v7 的 bot 指摘是「送件口径」的必然结果，不是新信息

- 我方自己事先就写下了这条：`patches/upstream/board-dts-single-20261113-sent-20261117/README.md:40` 记 checkpatch W#2
  「`lenovo,elden` appears un-documented」⇒ 因为 `qcom.yaml` 那枚（v6 `3/5`）**没进后续系列**；
  同文件 `:43` 结论「本枚**不能裸发**」，给了两条路 (a) 与 binding 同批、(b) 等 binding 合入。
- 而 `SENT.md` 显示 **11-17 13:20 CST 已按单提交裸发**（`board-dts-single-20261113-sent-20261117/SENT.md:3-6`）。
  ⇒ sashiko 的 3 条 Medium 正是 README 预告的后果（外加「DT 缺 platform 骨架」这条是「单提交拆分」的副产物）。
- **要我们做什么**：不必逐条改代码；要么在 v8 里与 `qcom.yaml` + `willsemi,wl2868c.yaml` 同批，
  要么该封在维护者眼里会被当成「未就绪」。**需要人决策**（是否撤回/并批），不建议催 reviewer。

## 4. 零回复清单 + follow-up 时间判断

| 系列 | 已等（截至 11-17 13:40 UTC） | 建议动作 | 判断依据 |
|---|---|---|---|
| **pstore-ram-initrd-overlap** | **1.4 天** | **等到 11-23（满 7 天）再评**；若 patchwork 仍 New，11-24/25 可发一封**不带 `[PATCH v2]`、只补背景/复现**的礼貌 ping | pstore 是小编成面（Kees Cook/Tony Luck），1–2 周属正常；论坛惯例：<7 天催单会被视为催单 |
| **m8-mdss v5** | **3.9 天** | **不要催**（我方 11-17 已自回一封补 Q28 证据，等于已在跟） | dri-devel 惯例 1–2 周；Dmitry 对同系列 v1→v3 的回帖间隔 2–10 天，但 v4→v5 已沉默；再催会是第三次触达 |
| **dsi-phy v2** | 1.4 天（首）/ 8.3 h（重发） | 等到 **12-01 前后**再评；最早 11-24 | 同一位 reviewer 对同一文件 v1 用了 **3 周**（10-19→11-11），本次预期不会更快 |
| **dpu-gamma v2** | 8.3 h | 等到 **12-01** 之后再评 | 同上，v1 用了 **29 天** |
| **wl2868c v12** | 8.3 h | **11-24 查 patchwork 状态**（New / Under review / Applied），无回应再考虑 11-25 后一句 ping | Mark Brown 一般数日内 apply；v10→次日 b4-review、v11→Rob 3 天后回 tag，属快通道 |
| **board DTS v7** | 8.3 h | **不催**；先决定 binding 并批，再谈 v8 | 缺 `qcom.yaml` 是硬伤，催 reviewer 只会换来重复质疑（v6 线程里 Krzysztof/sashiko/Konrad 已同向质疑） |
| **dwc3 v9** | 8.3 h | 先吃 sashiko 两条 High，**修完再谈 v10**；11-24 后若仍无人类回帖可考虑 | Thinh Nguyen 节奏偏慢（v8 发送 11-06 → Rob 回帖 11-10） |
| **haptics v2** | 8.3 h | 先处理 `disable_work_sync()` 竞态；11-24 后再评 | linux-input 通常 1–2 周；Dmitry 11-15 仍在活跃回其它线程 |
| **camss-csiphy-24-v2** | 未投 | 不是催单问题；**投递待批准**，且必须明写无上机实测 | `README.md:11`、`GATES.md`（6 道门全静态/夹具） |

**通用节奏（内核社区惯例，本轮只作参考不是硬结论）**：
① `[PATCH]` 发出 **7 天内不催**，**2 周无任何回应**才考虑 ping 或 `RESEND`；
② 按子系统节奏而非日历：dri-devel/msm（Dmitry/Abel/Konrad）常在 1–3 周；regulator（Mark）数日；input（Dmitry T.）1–2 周；
③ **merge window 期间不催**（维护者不收新特性、只处理 fix）：上游当前基线 = **7.4-rc3**（`patches/upstream/camss-csiphy-24-v2-20261117/GATES.md` §0：`gh/master = aebb727447`，7.4-rc3 final），
   按 7.4 周期推算 **12 月上旬进入 merge window**（推断，非实测）⇒ 12 月上旬到中旬的沉默不要解读为「被忽略」。
④ 已有 tag 的补丁不需要「感谢/跟进」回信；Rob 那类 tag 诉求的正确回应是**下一版里带上 tag**，而不是回邮件（本次 v12 已做对）。

## 5. 建议的下一步（本轮未执行，只列清单）

1. **dwc3 v9 / haptics v2 的两条 High**：读 sashiko 原文 → 核对代码 → 若成立则进 v10 / v3（优先级高于任何 ping）。
2. **m8-mdss v5 的 3 封 bot 报告**（积压 3.9 天）：至少过一遍，写进 `patches/upstream/m8-mdss-v5-20261114/README.md` 的待办。
3. **board DTS v7 口径决策**：撤回/并批/继续裸发三选一，需用户放行。
4. **camss-csiphy-24-v2 投递**：待批准（并需要一次上机出流回归才允许写 Tested-by）。
5. **`--replies-only` 修复**：`~/.local/bin/read-mail-ustc.py:13-15` 的 `OUR_IDS` 改为从 `patches/upstream/*/` 动态收集 MID（或加 `--mids-file`）。属工具改造，本轮只读未改。

## 6. 复现命令（全部带 timeout，均已实跑）

```bash
timeout -k 5 180 /home/xuqianhui/.local/bin/read-mail-ustc.py --days 4 --replies-only   # → 0 封（口径失效）
timeout -k 5 180 /home/xuqianhui/.local/bin/read-mail-ustc.py --days 7                  # → Sent 41 封
timeout -k 5 500 python3 /tmp/mail-probe3.py        # 按 MID 前缀 + 主题片段扫 INBOX/Junk（本次数据来源）
timeout -k 5 200 python3 /tmp/mail-body.py '<mid>'  # 取单封正文（BODY.PEEK，不改已读）
timeout -k 5 90 /home/xuqianhui/.local/bin/lore-query.py 'https://lore.kernel.org/linux-usb/?q=20261117052137.32833'
timeout -k 5 90 python3 scripts/lore-fetch-raw.py linux-kernel 20261116040049.434247-1-xiaqinghuan@mail.ustc.edu.cn
```

**未做/做不到的**：`curl` 直连 lore 仍 403（Anubis），故所有归档判据走 `lore-query.py`/`lore-fetch-raw.py`；
GitHub API 本次被限流（`API rate limit exceeded`），未用它判合入状态（该项昨日报告已核，本文不重复）。

收尾: 9 个在飞系列对账完成——14 日以来仅 2 封人类回帖（Rob 的 R-b 已由 v12 闭合、Bryan 要求已由 v2 重基满足），8 封 sashiko 中 dwc3/haptics 各含 High 需改码，pstore/dsi-phy/dpu-gamma 为真零回复（等 7 天~2 周再评）。
