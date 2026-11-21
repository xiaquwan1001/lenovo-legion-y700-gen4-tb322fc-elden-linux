# 上游邮件收件核查（窗口 2026-11-15T00:00Z → 2026-11-21T02:00Z）

> 只读调查：未发信、未 `git send-email`、未写 `out/mail-*`、未动设备、未改 `TASKS/README.md` 正文/`versions/`。
> 所有外部命令带 `timeout -k`；IMAP 一律 `BODY.PEEK`（不改已读状态）。凭据只在运行时从 keyring 取，未落盘、未进本文。
> 数据源：USTC IMAP（`mail.ustc.edu.cn:993`，INBOX + "Junk E-mail" + "Sent Items"）＋ patchwork REST 1.2 ＋ git.kernel.org 提交页。
> 时间统一 UTC（邮件头本地时区已换算，换算式写在引用里）。

## 0. 结论（数字先行）

| 项 | 数字 |
|---|---|
| 窗口内我方外发内核件 | **27 封**（含 v12 的一次**重复批次**，见 §6.2） |
| 窗口内**人类**回帖（对我方线程） | **5 封**：Rob Herring ×3（11-16 wl2868c v11、11-18 dwc3 v9 1/3 + 3/3）、Mark Brown ×1（11-17，**wl2868c v12 已 apply**）、Bryan O'Donoghue ×1（11-15，CSIPHY RFC） |
| 窗口内 **sashiko** 回帖（对我方线程） | **5 封**（11-17：dwc3 v9 1/3、2/3、3/3，elden v7，aw86927 v2 6/6） |
| **退信** | **0**（三处 IMAP 按 From/Subject 五条判据全 0，见 §1.3） |
| **最大新事实** | **wl2868c v12 已被 Mark Brown 合入 regulator.git `for-7.5`**（`84e67d2ee13f`、`602f57223457`，且已在 linux-next master）⇒ 项目**第一个进树的上游系列**；`TASKS` §7 与 `reports/upstream-recheck-20261120.md` 均**未记** |
| 需要我方动作 | **3 件**：① 回填 wl2868c 已合入（文档动作，非发信）；② dwc3 v10（已 SENT-ready，等放行，已内含 Rob 两封的逐条回应）；③ elden v7 / aw86927 v2 / mdss v5 的 sashiko 报告**至今零回复零处置** |
| 「必须先回」 | **0 件**（没有维护者问题在等我们答而尚未被任何在飞版本覆盖） |

## 1. 方法与口径

### 1.1 为什么不用 `--replies-only`

`~/.local/bin/read-mail-ustc.py:13-15` 的 `OUR_IDS` 只硬编码 3 个 2026-10 的 Message-ID ⇒ 窗口内**恒 0**（同一坑 2026-11-18 已记，本次未重复踩）。
替代判据：先用 Sent Items 取窗口内**全部我方 Message-ID**（86 个），再扫 INBOX/Junk 的 `In-Reply-To`/`References`/`Message-ID` 命中 + 发件人名 + 主题关键词三判据并集（临时脚本 `/tmp/inbox-probe.py`，不在 `scripts/`）。

```bash
timeout -k 5 300 python3 /tmp/mids-sent.py        # Sent Items: 日期|主题|Message-ID，86 条
timeout -k 5 400 python3 /tmp/inbox-probe.py      # INBOX 3501 封 + Junk 138 封 → 1451 候选 → 46 命中我方/退信
```
原始输出片段：
```
### INBOX total=3501
### "Junk E-mail" total=138
rows=1451
```
按我方 MID 命中后人工去重（列表信常一份投两次，1451 行里 1202 个唯一 MID）得 4 封人类 + 5 封 bot（另有 1 封 Bryan 11-15 只用主题判据命中）。

### 1.2 正文取证

按 `HEADER Message-ID` 精确取全文（`BODY.PEEK[]`），脚本 `/tmp/fetch-mids.py`；每条结论下的引文都是该命令的原样输出。

### 1.3 退信判据（全 0）

```bash
for q in 'FROM "mailer-daemon"' 'FROM "postmaster"' 'SUBJECT "Undelivered"' 'SUBJECT "Mail delivery failed"'; do ... done
```
```
INBOX (SINCE "15-Nov-2026" FROM "mailer-daemon") -> 0 []
INBOX (SINCE "15-Nov-2026" FROM "postmaster") -> 0 []
INBOX (SINCE "15-Nov-2026" SUBJECT "Undelivered") -> 0 []
INBOX (SINCE "15-Nov-2026" SUBJECT "Mail delivery failed") -> 0 []
```
（第 5 条中文「退信」因 imaplib 不允许非 ASCII 查询串报 `UnicodeEncodeError`，**未验证**；但前述 4 条 + §1.1 的 `no-reply/noreply/bounce` 发件人扫描均无邮件投递类结果。）

## 2. 逐封表

### 2.1 人类回帖

| # | 发件人 | 时间 (UTC) | 系列 | 要求什么（原文关键句） / Message-ID | 我方欠什么 | §7 记过？ |
|---|---|---|---|---|---|---|
| H1 | Rob Herring `<robh@kernel.org>` | 2026-11-16T15:10:52Z | **wl2868c（v11 1/2）** | 「**Missing my Reviewed-by tag. It's your responsibility to add tags when sending new versions.**」+ `Reviewed-by: Rob Herring (Arm)` · `<20261116151052.GA1449968-robh@kernel.org>` | **无**（v12 1/2 已带该 tag，见 `patches/upstream/wl2868c-v12-20261117/v12-0001-*.patch`） | 已记（v12 处置；本封未逐字点名） |
| H2 | Mark Brown `<broonie@kernel.org>` | 2026-11-17T16:17:30Z | **wl2868c（v12 0/2）** | 「**Applied to** `https://git.kernel.org/pub/scm/linux/kernel/git/broonie/regulator.git` **for-7.5**」+ 两枚 commit `84e67d2ee13f` / `602f57223457`；「if any updates are required … should be sent as **incremental updates** against current git, existing patches will not be replaced」「**Please add any relevant lists and maintainers to the CCs when replying**」 · `<179493225071.77896.10185420836573973098.b4-ty@b4>` | ① 回填「已合入」进 §7（文档）；② 后续板件/fastrpc 系列引用该 binding 时按**已在树**处理；③ 将来改动只能发增量补丁 + CC 列表 | **未记**（§7 与 `upstream-recheck-20261120.md` 都仍写 state=new 等评审） |
| H3 | Rob Herring `<robh@kernel.org>` | 2026-11-18T15:27:39Z | **dwc3（v9 3/3）** | 「What changed in this version **isn't really applicable for the commit message** … The commit msg should answer **"why"** we need/want this change.」+「What has changed in each version … goes **here after the '---'**」 · `<20261118152739.GA1824160-robh@kernel.org>` | 已内嵌在 **v10 的 3/3**（`patches/upstream/dwc3-v10-20261120/v10-0003-commit-msg.txt`，why-first + changelog 移到 `---`）；欠的只是**放行发信** | 已记（§7 2026-11-21 增量行；`reports/dwc3-v10-plan-20261120.md` §6） |
| H4 | Rob Herring `<robh@kernel.org>` | 2026-11-18T15:34:57Z | **dwc3（v9 1/3 binding）** | ① 对 `---` 下 `DRAFT: driver (3/3) still uses a GPIO…` 逐字回「**??**」；②「**You don't need to use $defs here.**」；③「These can be: `patternProperties: '^endpoint@[01]$':`」；④「**Don't put driver specifics in bindings.**」；⑤「This $ref **can be dropped**. You already have the schema for 'port@0' below.」 · `<20261118153457.GB1824160-robh@kernel.org>` | **v10 已逐条落实**：0001 的 `Changes since v9` 四条正是 ②③④⑤，`patternProperties` 已内联（`grep -n patternProperties v10-0001-*.patch` → 76/88 行）；「??」的原因已定位 = 自身 DRAFT 行自相矛盾（v9 3/3 实际 `mux_control_*` 命中 5 次）。欠的只是放行 | 已记（同上，cover 含对两封的逐条回应） |
| H5 | Bryan O'Donoghue `<bod@kernel.org>` | 2026-11-15T17:44:06Z | **CSIPHY 2.4.0（RFC）** | 要求先基于 on-list 的 8750/Kaanapali（Hangxiang v25，patchwork series 33877）重做；并直言「LLM output pretty difficult to understand」（详见 `reports/mail-inbox-20261118.md` §2.1 #2） | v2 已重基完成（`patches/upstream/camss-csiphy-24-v2-20261117/`，6 门全绿）但**未投**；卡点 = 差一次上机出流回归 + 投递批准 | 已记（§7 M4 行 11-17 段） |

> 说明：H5 的 11-15T17:44Z 落在本窗口内（窗口从 11-15T00:00Z 起），故计入；其详细处置属 11-18 报告范围，本文只做对齐。

### 2.2 机器人（sashiko）回帖 — 5 封，均 11-17，均**零回复零处置**

| # | 时间 (UTC) / Message-ID | 线程 | 要点（原文清单首行） | 我方欠什么 | §7 记过？ |
|---|---|---|---|---|---|
| B1 | 2026-11-17T05:27:41Z | dwc3 **v9 2/3** | `[High] usb: dwc3: unbalanced mux_control_deselect()` | v10 修（`__dwc3_set_mode()` 配对） | 已记（dwc3-v10-plan） |
| B2 | 2026-11-17T05:37:39Z `<sashiko-outbox-218216@kernel.org>` | dwc3 **v9 3/3** | `[High] unbalanced mux_control_deselect()` + `[High] missing mux_control_deselect() on teardown` | v10 修（`dwc3_drd_exit()` deselect） | 已记 |
| B3 | 2026-11-17T05:40:08Z `<sashiko-outbox-218217@kernel.org>` | dwc3 **v9 1/3** | `[Medium] unconditional hs-port on port@0`、`[Low] hs-port allows omitting mux-state`、`[Low] commit message written as v8-to-v9` | v10 修；且「commit message written as v8-to-v9」与 Rob H3 同向，v10 已按基线树改写 | 已记 |
| B4 | 2026-11-17T05:34:06Z `<sashiko-outbox-218214@kernel.org>` | **elden DTS v7** | `[Medium] undocumented lenovo,elden board compatible`、`[Medium] undocumented willsemi,wl2868c compatible and missing driver for pmic@2f`、`[Medium] lacks core boot infrastructure and regulator consumers`、`[Low] non-alphabetical phandle node ordering` | **未处置**。① 前两条是「拆件投递」的已知后果（binding 走 wl2868c 系列，**现已合入 for-7.5**，故该条自然消解，但 `lenovo,elden` 仍缺 `arm/qcom.yaml` 条目 = 需与板件同批）；② 第三条是送件口径问题（板件骨架故意最小）；③ 第四条是**可立即改的真风格项**（`&i2c10` 应在 `&qupv3_2` 前） | **未记** |
| B5 | 2026-11-17T05:46:20Z `<sashiko-outbox-218219@kernel.org>` | **aw86927 v2 6/6** | `[High] race in aw86927_close() and unbind queues`、`[Low] commit message and comment mismatch` | **未处置**（需自查 `disable_work_sync()`/unbind 竞态，属真 bug 候选） | **未记** |

> 窗口外但仍在积压：mdss v5 的 sashiko ×3（2026-11-13T16:05/16:08/16:12Z）——我方 11-17 12:17 只回了 **cover 的证据材料**（`<179488903160.260870…>`，23 次真 POR 单）、**未逐条回应 bot 的三份报告**。

## 3. 与 patchwork 现态对齐

```bash
timeout -k 5 30 curl -s 'https://patchwork.kernel.org/api/1.2/patches/<id>/'   # state / commit_ref / project
timeout -k 8 60 curl -sL 'https://git.kernel.org/pub/scm/linux/kernel/git/broonie/regulator.git/commit/?id=<sha>'
timeout -k 8 90 curl -sL 'https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/log/?qt=grep&q=wl2868c'
```

| 系列 | patchwork 现态（本次直查） | 现实 | 差在哪 |
|---|---|---|---|
| **wl2868c v12** | `14991614/14991615` **`state=new` / `commit_ref=None`**（project=`linux-arm-msm`） | **已 apply**（`84e67d2ee13f` 提交者 Mark Brown 2026-11-17T16:14:41Z、`602f57223457`；author date 2026-11-17T13:22:56+0800 = 正确批次）。linux-next `master` grep `wl2868c` 命中两条，标「3 days」 | **patchwork 记录卡在 arm-msm 副本**：regulator 维护者从 linux-regulator 列表取件，不会回写 arm-msm 副本的 state ⇒ **「arm-msm `state=new`/`commit_ref=None`」不能推出「未合并」**（§7「三条限定」的直接反例）。另外**跨投两个列表时，只查一个 project 会漏掉另一半真相** |
| dwc3 v9 | `14991612`（3/3）、`14991613`（1/3）`new`，无 commit_ref | 未合入；Rob 已回两封（H3/H4） | §7/recheck 只记了 binding 那封；**3/3 那封（commit message 写法）是独立意见**，本次补齐 |
| elden DTS v7 | `14991580` `new`，`commit_ref=None` | 无人（含 bot 之外的维护者）回复 | 无差；但 sashiko 4 条未处置（B4） |
| fastrpc non-secure v3 | `14971025` `new` | 零回复 | 无差 |
| dsi-phy `PLL_SYSTEM_MUXES` v2 | `14991582` `new`（v1 `14989476`、v2-pre `14989527` 已 superseded） | **零回复**（人类与 bot 均无） | §7 未记该系列最新代；zero-reply 也值得留意（可能被 dsi 维护者队列埋没） |
| dpu gamma LUT v2 | `14991581` `new` | 零回复 | 同上 |
| aw86927 v2（6 枚） | `linux-input 14991595/14991596`… 均 `new` | 只有 sashiko 6/6（B5） | §7 未记 |
| mdss v5 | arm-msm `14980387`(1/3 `handled-elsewhere`)/`14980388`(2/3 `handled-elsewhere`)/`14980389`(3/3 `new`) | 我方 11-17 只补了 cover 证据 | sashiko ×3 未逐条回 |
| dispcc-sm8750 clk RFC | `14907944` `new`（arm-msm）/ `14907951` awaiting-upstream（linux-clk） | 无新回帖 | 无差 |
| pstore initrd 2 枚 | **patchwork 查不到**（`q=initrd_phys_range` 在 linux-kernel/lkml 均 0 命中） | lore 侧未复核 | **未验证**（可能未摄取，也可能 project 归属不同） |
| CSIPHY 2.4.0 RFC | **patchwork 查不到**（`linux-phy q=mipi-csi2-3ph` = 0） | 11-15 Bryan 已回 | **未验证**。注意：`linux-arm-msm q=CSIPHY+2.4.0` 命中的全是他人的 2025 系列 |

**3.1「维护者已回但 TASKS 未记」**：① **wl2868c 已 apply（Mark Brown，11-17）**；② **dwc3 v9 3/3 的 Rob 回信（11-18）**（§7 只在 11-21 增量行里以「两封」笼统带过，未列 3/3 内容）；③ elden v7 / aw86927 v2 的 sashiko 条目。
**3.2「TASKS 记了但实际没有」**：未发现记录与实证相反的条目（`§7` 11-20 块的「camss v2 未进 mainline」「dispcc RFC 只一版」等均复核为真）。唯一方向相反的是**陈旧**：§7 与 11-20 一页账都把 wl2868c 记为「new 等评审」。

## 4. 三档分类

**必须先回（0 件）**
- 理由：唯一「维护者在等我们」的两封（H3/H4）所要求的全部改动，都已在**未发的 v10** 里落地，回信内容就是 v10 本身 ⇒ 先放行 v10，不需单独回帖。H2（apply 通知）按内核惯例不需回信。

**可缓（2 件 + 3 件待办）**
- **B4 elden v7**：4 条里 3 条随 wl2868c 合入自解（`willsemi,wl2868c` 已在树）；剩 `lenovo,elden` 的 `arm/qcom.yaml` 条目与字母序，跟下一次板件重投一起做最省事。缓的理由 = 单发一封只改风格的信收益低于随版投。
- **B5 aw86927 v2 6/6**：High 是 unbind 期竞态，**要动代码**，属下一版的工作量而非回帖；缓的理由 = 无人在等答复，且改动须先自查验证。
- 待办（非回信）：回填 wl2868c 已合入；H5 的上机出流回归；mdss v5 的 sashiko 三份逐条判别。

**不用回（3 类）**
- **H1**（Rob 的 tag 提醒）：v12 已带 tag，事实闭合，回「已加」只会徒增噪声。
- **H2**（Mark 的 apply 通知）：`b4-ty` 自动信，回信无意义。
- **sashiko B1–B3**：对应修复在 v10，随版说明即可（sashiko 也不读回信）。

## 5. 未回复且可执行的意见（已给出处，**未发信**）

| 来源 | 可执行点 | 回信/落地要点（供放行时用，非草稿） |
|---|---|---|
| Rob Herring H4（11-18 1/3） | binding 去 `$defs`、`endpoint@[01]` 用 `patternProperties`、删冗余 `$ref`、别写驱动细节 | **已实现**在 v10 0001；cover 里逐条点名回应（引用其原句 → 指出改在哪一行），并一句话交代 v9 里「DRAFT: driver still uses a GPIO」是过期注释（3/3 实际已用 `mux_control_*`） |
| Rob Herring H3（11-18 3/3） | commit message 写 why，changelog 放 `---` | 已在 v10 0003；cover 一句话「3/3 的 commit message 已重写为 why-first，v8→v9 变更记录移到 `---`」 |
| sashiko B4（elden v7） | ① `lenovo,elden` 需进 `Documentation/devicetree/bindings/arm/qcom.yaml`；② 板件最小骨架 = 有意为之，需在 cover 里明说「本版只描述板级时钟/GPIO/相机 PMIC，其余随各功能系列」；③ `&i2c10` 移到 `&qupv3_2` 前 | 下一版板件重投时一并改；②写成 cover 的 scope 段避免重复被提 |
| sashiko B5（aw86927 v2 6/6） | `close()` 清 `level` 后 ff-memless 仍可能再排 `play_work`；`devm` 版 `aw86927_reset()` 未 `disable_work_sync()` ⇒ unbind 竞态；Low = commit message 与实现（suspend/shutdown）口径不一致 | 需改代码：`close()`/`remove()` 走 `disable_work_sync()` + `cancel_delayed_work_sync()`，并把 commit message 与实现对齐；改动前需一次 bind/unbind 冒烟 |
| sashiko mdss v5 ×3（11-13，窗口外积压） | 三份 bot 报告至今未判真伪 | 逐条判别（真/假/已覆盖），真的进 v6，假的在 cover 引用反驳 |

## 6. 顺带发现（与本 lane 相关但不属回信）

### 6.1 账号安全告警 2 封（需用户本人确认）
```
INBOX | Wed, 18 Nov 2026 05:59:30 -0800 | GitHub <noreply@github.com> | [GitHub] A fine-grained personal access token has been added to your account
INBOX | Wed, 18 Nov 2026 06:47:16 -0800 | GitHub <noreply@github.com> | [SPAM] [GitHub] A third-party OAuth application has been added to your account
```
**未验证**是否用户本人操作。按硬规则 2，只上报不动手。

### 6.2 v12 存在一次「重复批次」（卫生问题，已无害）
Sent Items 里 11-17 有两批 v12：
```
13:21:25 +0800 | [PATCH v12 0/2] … | <cover.1794557667.git.xiaqinghuan@mail.ustc.edu.cn>
13:21:26 +0800 | [PATCH v12 1/2] … | <9ab5e5937264bb408be43986acb8553464e44a49.1794557667.git…>
13:22:55 +0800 | [PATCH v12 0/2] … | <20261117052257.34849-1-xiaqinghuan@mail.ustc.edu.cn>
```
第一批的 Message-ID 与 **11-13 的 v11 逐字相同** ⇒ 发的是 v11 原件（列表侧按重复丢弃）。**实际生效的是第二批**（patchwork `14991614/14991615` 的 MID 即 `20261117052257.34849-*`；Mark apply 的 author date 也是 13:22:56）。**无退信、无重复摄取**，结论：无害，但「同目录重发」应避免。

### 6.3 窗口内我方的 11-17「零回复」集合
`dsi-phy PLL_SYSTEM_MUXES v2`（`14991582`）、`dpu gamma LUT v2`（`14991581`）、`fastrpc v3`（`14971025`）三件**人类与 bot 均无任何回帖**。dsi/phy 属 drm-misc 常规队列，7 天无回属正常范围，但下一轮可留意是否需要 ping（按 §7 口径：不单独 ping，随版带走）。
