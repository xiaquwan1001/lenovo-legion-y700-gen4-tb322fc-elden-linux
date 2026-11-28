# D10 通信跟踪（D10 lane 增量快照，只读）— 邮件三箱 + lore + 用户态上游现查

> **只读纪律**：本轮**未发信、未回帖、未推 MR、未 `git commit`/`git push`、未改任何既有报告/台账/代码**。
> IMAP 全 `BODY.PEEK`（不改已读态）；凭据运行时由 keyring 取、未落盘；外部命令一律 `timeout -k`。
> **写入偏离说明（必读）**：派工单指定「唯一写入 = 新建 `reports/comms-track-20261128.md`」，但该路径**已存在**
> （上一 lane 于 `11-27T22:17Z` 收口的快照 + 09:3x CST 与 09:5x 两段追加）。按「不改既有报告」硬约束，
> 本轮落到**同日前缀的新序号文件** `reports/comms-track-20261128-b.md`（沿用仓库既有 `-b`/`-c` 序号惯例，
> 见 `reports/comms-track-20261127-b.md`、`-c.md`）。原路径**未动一字**。
> **现场时刻**：`date -u` 起点 **`2026-11-28T02:18:11Z`** → 末次核 **`2026-11-28T02:2xZ`**。
> **增量基线**：`reports/comms-track-20261128.md`（`11-27T22:17Z` 主段 + 两段追加）、`reports/comms-track-20261127.md`（`06:06Z`）、
> `reports/upstream-userland-20261128.md`（用户态三件）、`patches/upstream/v4l2-compliance-iris-20261127/SENT.md`、`TASKS/UPSTREAM.md` §7（M3-DTS/M6/M8/M10/M11/M12）、`TASKS/NEXT.md` §4.0a（T37/T7）。
> **判据（沿用上两轮）**：人类回信才算回复；`sashiko-bot`/`patchwork`/`media-ci` 只记「有无状态变化」；
> 进树只看 **内容级**（`git.kernel.org` plain / commit 页），不看 patchwork `state`/`commit_ref`。

---

## §0 数字结论

| 指标 | 值 | 依据 |
|---|---|---|
| **待我方动作（需外发）** | **1 项（打包一次）** | iris：`2/3` 出 **v3**（只因 commit message 折行被 CI 判 mandatory checkpatch 失败，代码不动）+ 顺带一句回 bod「1/3 与主线 `1facae9bc3c1` 重复、建议 drop」；**本轮不代发、按 §7-1 待放行** |
| 待我方动作（台账/记账，非外发） | **2 项** | ① M6 dsi-phy v3 补 `Reviewed-by: Dmitry Baryshkov` + `Cc: stable`；② iris 3 贴 patchwork 已 `Changes Requested`（§3） |
| **窗口内新人类信** | **0 封** | 三箱天花板：INBOX 末封 `11-28T01:27:06Z`（机器人）、Sent 末封 `11-28T00:37:37Z`（我方 v2）、Junk 末封 `11-27T04:06:32Z`；均早于起点 `02:18:11Z` |
| 本轮**逐封精读**的人类回信 | **3 封**（均已在 lore 归档，MID 逐条核） | James Clark `11-27T13:02:03Z`（coresight v1，R-b）、Bryan O'Donoghue `16:04:09Z`（iris 1/3）、Dmitry Baryshkov `20:26:47Z`（dsi-phy v3，R-b）——**三封都已在前序快照记账**，本轮做的是独立复核 + 判读（§2） |
| 其中**顺风闭合** | **1 封** | James 的 R-b + 「补 Fixes」已由 `13:30Z` 的 v2 闭合（两贴本地 grep 实证带 `Fixes:` + `Reviewed-by: James Clark`） |
| 其中**仍需我方动作** | **1 封** | bod 对 1/3 要 `Fixes:`/`Cc: stable` ⇒ 该贴已是主线重复件，动作改为「说明并 drop」，并入 v3 |
| **机器人/列表信状态变化** | **5 封，其中 1 条是新欠账** | ① `10490` media-ci 对**我方 v2 colorspace**判 `ERROR: Fails one or more mandatory checkpatch tests`（**前序快照未记**，本机已复现）② `10488` patchwork：3 贴 `New → Changes Requested` ③ `10484/10485` media-ci：v1 3/3 **无法 apply**（机械佐证 1/3 已在上游）④ `10481` linux-media 拒信（v1，已由 v2 修正）（§3） |
| 退信/DSN | **0 封** | `grep -iE 'mailer-daemon\|postmaster\|Delivery Status\|Undelivered\|returned to sender'` 三箱 0 命中 |
| **在飞系列「人类零回复」** | **6 条** | elden v10 / dwc3 v16 / mdss v5 / fastrpc v3 / pstore / aw86927 v4（§4） |
| gmobile **!131**（T37） | 新开 · **0 note** · `mergeable` | `user_notes_count=0`，`created_at=updated_at≈2026-11-28T01:55Z`（≈27 min） |
| droidloom **#69**（T37） | **0 评论** · OPEN | `#65` 亦 0；`#48` 1 条评论 = **我方自己**（`11-27T14:45:11Z`），维护者两处均零回复 |
| phoc **#125**（T37） | notes **10 → 11**（+我方 1 条）· **维护者零回复** | note `2948914`（我方 `01:55:21Z`）；最后人类 = guidog `2023-02-17T10:33:53Z` |
| Mobian `droid-juicer` **!46** | **0 note** · `updated_at` 停在 `11-23T11:10:29Z`（≈111.6 h） | mobian1 组 13 open / 我方 1；salsa 32 open / 我方 **0** |
| phosh **!2005** | notes **3**（末条 = 我方 `11-27T08:24:39Z` 回帖）· guidog 自 `11-14T13:12:08Z` 零回（≈13.6 天） | 上轮记的「待放行回 guidog」**已执行**，本轮只记账 |
| **阻塞** | **0** | 上一轮的「keyring 锁 ⇒ IMAP/glab/send-email 全不可用」**已解除**：本轮 IMAP 与 `glab api`(GNOME) 均一次通过 |

**一句话**：本轮没有新人类信，但**翻出两条需要动手的东西** —— ① 我方 iris `2/3` 的 v2 被 media CI 判**mandatory checkpatch 失败**（commit message 里一行以 `Cc:` 开头 + `commit <sha>` 引用标题折行），必须出 v3；② bod 要的 `Fixes:`/`Cc: stable` 对象是**主线已有的 `1facae9bc3c1`**（内容级已核），照做没有意义，正确动作是「说明并 drop 1/3」。两件可以合成一次外发（§7-1）。用户态三件（gmobile !131 / droidloom #69 / phoc #125）**全部 0 维护者回复**，按 T37 只跟踪、不催。

---

## §1 通道状态（三箱 + 天花板）

```bash
timeout -k 5 300 /home/xuqianhui/.local/bin/read-mail-ustc.py --days 2 --limit 400   # rc=0
```
原始行（逐字）：
```
=== INBOX : 67 封（SINCE 26-Nov-2026）===
=== "Junk E-mail" : 20 封（SINCE 26-Nov-2026）===
=== "Sent Items" : 32 封（SINCE 26-Nov-2026）===
```
| 箱 | 封数 | 末封（原文 Date → UTC） | 判读 |
|---|---|---|---|
| INBOX | 67 | `Fri, 27 Nov 2026 17:27:06 -0800` = **2026-11-28T01:27:06Z**（`patchwork@media-ci.org`，我方 v2 的 CI 反馈） | 通道活；**01:27Z 后 0 新信**（≈55 min） |
| Junk E-mail | 20 | `Thu, 26 Nov 2026 23:06:32 -0500` = **2026-11-27T04:06:32Z**（Nicolas Dufresne，libcamera RFC） | 存储层活；**无我方线程命中**（`grep -iE 'qcom\|iris\|coresight\|elden\|aw8692\|dwc3\|droid-juicer\|phosh'` = 0） |
| Sent Items | 32 | `Sat, 28 Nov 2026 08:37:37 +0800` = **2026-11-28T00:37:37Z**（`[PATCH v2] media: iris: fill in a default colorspace…`，即 T31 的实发件） | 我方副本齐（含 coresight v2 三封、TNOC 撤回信、iris 3 贴、给 Neil 的 v1/v2） |

- **退信面**：0 封 DSN（判据见 §0）。上一轮的 `dmitry.baryshkov@linaro.org` / `srinivas.kandagatla@linaro.org` 死地址问题**本轮未复现**。
- **`coresight@` 压审（T24 自证）**：INBOX 里最后一次 moderator 信是 `10475–10477`（`11-27T13:31Z`，= **v2 那三封**）；用户当晚网页订阅完成后**还没有新的 coresight 发布**⇒ 自证判据（下一封不再出现 `awaits moderator approval`）**仍待触发**。
- 与本轮无关的噪声：`10467–10469/10473–10480`（订阅握手，收口于 `reports/coresight-list-subscribe-20261127.md`）、`10436–10466`（自家 USTC GitLab pipeline 通知）、`10442/10460`（教务系统）。

---

## §2 逐封判读（3 封人类回信，按派工单 a/b/c 顺序）

> 三封的 MID 均在 lore 线程里逐字命中（§4），正文用 `BODY.PEEK` 精读。**均不代发任何邮件**。

### 2.a `msg 10472` James Clark — `Re: [PATCH 0/2] coresight: add missing MODULE_DEVICE_TABLE() for CTCU and TPDA`

| 项 | 内容 |
|---|---|
| **对象** | `James Clark <james.clark@linaro.org>`；MID `<6f997513-27da-47e5-83bb-18c267e930c6@linaro.org>` |
| **时间 (UTC)** | **2026-11-27T13:02:03Z**（`Fri, 27 Nov 2026 13:02:03 +0000`） |
| **挂在** | v1 cover `<20261127113137.931578-1-…>`（不是 v2） |
| **要什么** | 正文除引用块只有两行：`Could probably do with fixes: tags for both commits, but:` / `Reviewed-by: James Clark <james.clark@linaro.org>` ⇒ **给 R-b，附带建议补 `Fixes:`** |
| **是否需我方动作** | **否（只记账）**—— 两项都已被 `13:30Z` 的 v2 满足 |
| **判定依据（原文关键句）** | ① `Could probably do with fixes: tags for both commits, but:`；② `Reviewed-by: James Clark <james.clark@linaro.org>`。**本地实证**：`v2-0001-…patch` 含 `Fixes: f78d206f3d73 ("Coresight: Add Coresight TMC Control Unit driver")` + `Reviewed-by: James Clark <james.clark@linaro.org>`，`v2-0002-…patch` 含 `Fixes: 5b7916625c01 ("Coresight: Add TPDA link driver")` + 同一 R-b |
| **一句话建议** | **不要回帖**（R-b 之后道谢/再回帖是噪声，且 krzk 11-21 已因「反复投递」批评过）；台账把 A 系列标「等 pick up」即可。观察点：`next-2026xxxx` 的 `coresight-ctcu-core.c` 是否出现 `MODULE_DEVICE_TABLE`（本轮现查仍 0，§5） |

### 2.b `msg 10489` Dmitry Baryshkov — `Re: [PATCH v3] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable`

| 项 | 内容 |
|---|---|
| **对象** | `Dmitry Baryshkov <dmitry.baryshkov@oss.qualcomm.com>`；MID `<oj34ljpmxdycfa6igp7bw7ruk6fuukyxmpnneir66eagrm7itl@czqpnm3r66d4>` |
| **时间 (UTC)** | **2026-11-27T20:26:47Z**（`Fri, 27 Nov 2026 22:26:47 +0200`） |
| **要什么** | 引用块之后**只有两行**：`Cc: <stable@vger.kernel.org>` / `Reviewed-by: Dmitry Baryshkov <dmitry.baryshkov@oss.qualcomm.com>` ⇒ **收进 msm-next 的意图 + 要求 stable 回传；零技术异议** |
| **是否需我方动作** | **否（只记账）**—— 不重投、不改代码、不回帖 |
| **判定依据（原文关键句）** | 全文（去掉引用）就是那两行（`BODY.PEEK` 直读，见 §附录命令）：`Cc: <stable@vger.kernel.org>` / `Reviewed-by: Dmitry Baryshkov <dmitry.baryshkov@oss.qualcomm.com>` |
| **一句话建议** | **本轮唯一实质收获**：M6 拿到**首个 msm 维护者 R-b**（12 天前他对 v1 提过意见，v3 已闭合）。台账 M6 行补 R-b + `Cc: stable`；下一轮观察点 = `msm-next for-next` 是否出现该提交。**内容级现查（本轮已做）**：torvalds 与 linux-next 的 `dsi_phy_7nm.c` 仍只有 **2 处** `PLL_SYSTEM_MUXES`（`:417` 写 `0`、`:439` 写 `0xc0`），没有 phy_enable 里的第 3 处 ⇒ **尚未进树**（§5） |

### 2.c `msg 10486` Bryan O'Donoghue — `Re: [PATCH 1/3] media: iris: report a platform bus_info prefix`

| 项 | 内容 |
|---|---|
| **对象** | `Bryan O'Donoghue <bod@kernel.org>`；MID `<6505dda0-f534-4705-bcea-ecf5f6b9ec30@kernel.org>` |
| **时间 (UTC)** | **2026-11-27T16:04:09Z** |
| **要什么** | 正文除引用块一行：`Please add an appropriate Fixes: and Cc: stable@vger.kernel.org` ——**只针对 1/3**（2/3、3/3 未提意见） |
| **是否需我方动作** | **要**，但**不是照做**：1/3 已是主线重复件，补 tag 无意义 ⇒ 动作 = **一句说明 + drop**，可与 2/3 的 v3 一起发（§7-1） |
| **判定依据（原文关键句）** | ① bod 原文：`Please add an appropriate Fixes: and Cc: stable@vger.kernel.org`；② **内容级复核**：`git.kernel.org` torvalds/master 的 `drivers/media/platform/qcom/iris/iris_vidc.c:486-487` 已是 `snprintf(cap->bus_info, … "platform:%s:%s", …)`，且 `<torvalds/linux.git/commit/?id=1facae9bc3c1>` 页面标题 = **`media: iris: Fix bus_info prefix in VIDIOC_QUERYCAP`** ⇒ 我方 1/3（`plat:` → `platform:`）**与主线同 hunk 完全重复**；③ 机械旁证：media-ci 两次 attempt（`10484/10485`）在 media-committers `next` 上 `patch failed: iris_vidc.c:466`，正是「该行已被上游改掉」 |
| **一句话建议** | 回帖一句话（`Thanks — 1/3 is a duplicate of 1facae9bc3c1 which is already in mainline (my tree predates it); dropping it rather than adding tags.`），同时把 2/3 的 v3 发出去；3/3 也注明已被主线 `iris_vdec_s_fmt()` 取代。**属外发，待用户放行**；本 lane 不代发、不落盘草稿 |

---

## §3 机器人 / patchwork / 列表信（只记「有无状态变化」）

| msg | 来源 | 时间 (UTC) | **状态变化** | 一句话 |
|---|---|---|---|---|
| `10484` | `Patchwork Integration <patchwork@media-ci.org>` | `2026-11-27T15:46:29Z` | **有**：v1 3/3 系列 **CI 未测** | `b4 shazam` 在 media-committers `next bb425d7d` 上 `Patchwork failed at 0001`（`error: patch failed: iris_vidc.c:466`）⇒ 机械佐证 1/3 已在上游被改掉 |
| `10485` | 同上 | `15:52:00Z` | 同上（重试同一结论） | 与 `10484` 逐字相同（两次 attempt） |
| `10488` | `patchwork@linuxtv.org` | `16:16:02Z` | **有**：3 贴 `New → Changes Requested` | 与我方判断一致（bod 的评审已落到 patchwork）；`3/3` 也在其中，即使我们认为它已被主线取代 |
| `10490` | `Patchwork Integration` | **`2026-11-28T01:27:06Z`** | **有，且是新欠账** | 对我方 **v2 colorspace**（`<20261128003737.1300698-1-…>`）：`ERROR: Fails one or more mandatory checkpatch tests`；明细 = ① `WARNING: Do not use whitespace before Cc:` @ commit msg 行 29（该行以 `Cc: stable@vger.kernel.org), which is already in mainline. My tree predates` 开头）② `ERROR: Please use git commit description style 'commit <12+ chars of sha1> ("<title line>")'`（引用 `1facae9bc3c1` 的标题被折成两行）。**本机复现**：`perl scripts/checkpatch.pl 0002-v2-fill-default-colorspace.patch` → `2 errors, 5 warnings, 43 lines checked`（见 §附录） |
| `10481` | `linux-media+owner@vger.kernel.org` | `2026-11-27T15:21:03Z` | 无（已修复） | v1 回 Neil 的信被拒：`the list address was not found in either the To: or CC: header`；`23:26 CST` 的 v2（列表提到 To）已被 lore 归档（T25 已核 13 封） |

> `10490` 的处置要点（**v3 只改 commit message，代码不动**）：把「withdrawn 说明」段落重排，**不允许任何行以 `Cc:` 开头**（把它并进句子或写成 `(Cc: stable@vger.kernel.org)`），并让 `commit <12+> ("<title>")` 的标题**不折行**（或把该引用缩短）。这属于硬门（CI 判 mandatory），不修则 v2 不会被审。

---

## §4 lore 归档核对 + 在飞系列零回复清单

### 4.1 三封回信的归档实证（MID 逐字 + 线程封数）

```bash
python3 /tmp/d10-lore.py <cover-MID>    # 取 t.mbox.gz（默认 curl UA 可通），逐 entry 打 Date/From/Subject
```
| 线程 | 封数 | 末封 | 本轮回信是否在档 |
|---|---|---|---|
| coresight v1 `<20261127113137.931578-1-…>` | **4** | `James Clark 11-27T13:02:03Z` | ✅ entry 4 = msg 10472（MID 逐字相同） |
| dsi-phy v3 `<20261126052049.1544229-1-…>` | **2** | `Dmitry 11-27T20:26:47Z` | ✅ entry 2 = msg 10489 |
| iris `0/3` `<20261127152024.2149804-1-…>` | **6** | `我方 v2 11-28T00:37:37Z` | ✅ entry 5 = msg 10486（Bryan，挂 1/3） |
| coresight v2 `<20261127133017.1606830-1-…>` | 3 | 我方 `13:31:18Z` | —（R-b 已在 v2 正文里，无需新回信） |

### 4.2 在飞系列：**6 条人类零回复**（与上一轮同数，dsi-phy 已出列）

| 系列 | 线程封数 | 最后人类活动 | 我方最后动作 | 静默（至 `02:2xZ`） |
|---|---|---|---|---|
| elden DTS **v10** | 4（+sashiko） | 无 | 3 封 `11-26T05:21Z` | ≈45 h |
| dwc3 **v16** | 5（末 = sashiko "no issues"） | 无 | 4 封 `11-25T14:23Z` | ≈60 h |
| mdss **v5** | 12 | sashiko `11-13T16:12:15Z` | 换址 ping `11-25T02:23Z` | 14 天（补发 72 h） |
| fastrpc **v3** | 8 | **Konrad `11-09T14:16:40Z`** | 换址 ping `11-25T02:23Z` | 18.4 天（补发 72 h） |
| pstore **v1** | 4 | 无 | ping `11-25T09:07Z` | 11.9 天（ping 66 h） |
| aw86927 **v4** | 7（全我方） | 无（连 sashiko 都无） | `11-24T04:50Z` | ≈94 h |
| ~~dsi-phy v3~~ | 2 | **Dmitry R-b `11-27T20:26Z`** | — | **已出列（R-b 到手）** |
| TNOC periphid | 5 | sashiko `[Low]` | 自认 superseded `13:23Z` | 已撤回，不跟帖 |
| iris `0/3` v1 | 6 | **bod `16:04Z`** | 我方 v2 `00:37Z` | 有回复 ⇒ 出列（转 §7-1 动作） |

---

## §5 内容级进树核对（只看维护者树/next，不看 patchwork）

```bash
# 默认 curl UA 在 git.kernel.org 可直通（浏览器 UA 才会吃 Anubis 假 200）
timeout -k 5 60 curl -sSL 'https://git.kernel.org/pub/scm/linux/kernel/git/{torvalds/linux.git,next/linux-next.git}/plain/<path>'
```
| 对象 | 现查结果 | 判定 |
|---|---|---|
| dsi-phy v3 | `dsi_phy_7nm.c`（torvalds **和** next，均 200 / 47 664 B）：`PLL_SYSTEM_MUXES` 命中 **2**（`:417` 写 `0`、`:439` 写 `0xc0`） | **未进树**（我们的第 3 处写不在）⇒ 与 R-b 刚到手一致 |
| elden DTS v10 | `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` → next **404** | 未进树（v11 备料仍未投，T7 口径不变） |
| coresight MODULE_DEVICE_TABLE v2 | next `coresight-ctcu-core.c` **200 / 8 518 B**，`MODULE_DEVICE_TABLE` 命中 **0** | 未进树（等 pick up） |
| TNOC periphid | next `sm8750.dtsi:5175 tn@109ab000` 只有 `compatible/reg/clocks`，**无 periphid** | 未进树；我方已撤回，等 Jie Gan 系列 |
| iris 1/3（bus_info） | torvalds `iris_vidc.c:486-487` = `"platform:%s:%s"`；commit 页 `1facae9bc3c1` 标题 = `media: iris: Fix bus_info prefix in VIDIOC_QUERYCAP` | **已在上游** ⇒ 1/3 作废，bod 的 tag 要求无对象 |

---

## §6 用户态上游现查（只读；T37 三处 + Mobian）

| 对象 | 现查（本轮） | 变化 | 要/否 |
|---|---|---|---|
| **gmobile `!131`** `World/Phosh/gmobile`（T33/T37） | `state=opened` · `draft=false` · `detailed_merge_status=mergeable` · **`user_notes_count=0`** · `sha=ac5aae2a` · `created_at=2026-11-28T01:55:02Z` · `updated_at=01:55:42Z` | 新开 ≈27 min，**零评审** | **否**（等 T37；勿催） |
| **droidloom `#69`**（T32/T37） | `OPEN` · **`comments=0`** · `created_at=2026-11-28T01:52:15Z` · `updated_at=01:55:36Z`（我方编辑标题） | 我方新开 ≈28 min | **否** |
| **droidloom `#65`** | `OPEN` · `comments=0` · `updated_at=2026-11-27T14:01:51Z` | 无 | **否**（≈12.4 h） |
| **droidloom `#48`** | `OPEN` · `comments=1` · `updated_at=2026-11-27T14:45:11Z` | **变化**：唯一评论 = **我方**（第三方复现数据，T1 动作已落地）；**维护者仍零回复** | **否**（不二次催） |
| **phoc `#125`**（T35/T37） | `state=opened` · `user_notes_count=**11**`（notes 实返 14 条，其中 system 3）· 我方 note `2948914` @ `2026-11-28T01:55:21Z` · `updated_at=01:57:09Z`（我方编辑） | **+1 条 = 我方**；最后人类 = `guidog 2023-02-17T10:33:53Z` ⇒ **维护者零回复** | **否**（T35 等形状表态；勿先行提 MR） |
| **Mobian `droid-juicer !46`** | `opened` · `draft=false` · **`user_notes_count=0`** · `detailed_merge_status=mergeable` · `sha=ea9fe3d5` · `updated_at=2026-11-23T11:10:29Z` | 无变化（≈**111.6 h**） | **否** |
| mobian1 组 / salsa | `open MRs=13`，`mine=1`（= `!46`）；salsa `Mobian-team` `open=32`，`mine=0`，最新活动仍是 `qcom-linux!61`（`tiol`，`11-27T21:32:24Z`） | 无我方变化 | **否** |
| phosh `!2005`（记账） | `opened` · notes **3** · `sha=5300355a` · `updated_at=2026-11-27T08:24:39Z` = **我方回帖**（note `2948291`，含 AI 披露 + 复现器 + 「Could you take another look?」） | **上轮「待放行回 guidog」已执行**（本 lane 只记账）；guidog 自 `11-14T13:12:08Z` 零回（≈13.6 天） | **否**（等 guidog） |
| `linux-msm/hexagonrpc` PR `#31`（我方台账附属） | `open` · `mergeable_state=unstable` · `updated_at=2026-11-27T03:09:39Z` · `reviews=[]` · inline comments **0** · 近两次 `Build+test` 仍 `action_required` | 无变化 | **否**（等维护者点批准） |

> GNOME 侧工具口径**沿用上一轮**：`glab api --hostname gitlab.gnome.org`（认证）本轮**一次通过**；`gitlab.com`/`salsa` 走匿名 REST；GitHub 侧 `gh` 需 `env -u *_proxy`（否则 TLS handshake timeout / 输出尾部夹 hint 行）。

---

## §7 需用户放行 / 需人工（本轮全部动作项）

| # | 事项 | 类别 | 为什么 | 一条命令/位置 |
|---|---|---|---|---|
| **1** | **iris：发 `2/3` 的 v3 + 一句回 bod 说明 1/3 作废** | **需用户放行（外发，打包一次）** | ① v2 被 CI 判 mandatory checkpatch 失败（`Cc:` 开头行 + `commit <sha>` 标题折行）⇒ 不修不会被审；② bod 明确要 tag，而 1/3 已是主线 `1facae9bc3c1`，须给一句说明否则会被当成「忽略评审」 | 目录 `patches/upstream/v4l2-compliance-iris-20261127/`；修改点 = `0002-v2-fill-default-colorspace.patch` 的 commit message（**代码零改动**）；门禁复跑 `perl <tree>/scripts/checkpatch.pl 0002-…patch` 必须 0E，再 `git send-email --dry-run` |
| 2 | 台账回填（本 lane 不改 `TASKS/`） | 需另一 lane | 3 处状态变化 | ① M6 dsi-phy v3 补 `Reviewed-by: Dmitry Baryshkov` + `Cc: stable`（`11-27T20:26Z`）；② coresight A 系列标「v2 已带 R-b+Fixes，等 pick up」；③ iris 3 贴标 `Changes Requested` + 「2/3 待发 v3」；④ 用户态三件按 §6 更新 T37 指针 |
| 3 | 观察点（无需动作） | 记录 | — | ① `msm-next for-next` 是否出现 dsi-phy v3；② `next-2026xxxx` 是否含 coresight `MODULE_DEVICE_TABLE`；③ gmobile `!131` / phoc `#125` / droidloom `#69` 的首条维护者回复 |
| 4 | **不做清单** | — | 催只会烧信誉 | elden v10（T7 等真实修订）、dwc3 v16、mdss v5、fastrpc v3、pstore、aw86927 v4、`!46`、`#48`/`#65`、phosh `!2005` |

---

## §8 工具事实（本轮新增/修正，供下轮直接抄）

1. **keyring 已解锁 ⇒ IMAP/`glab`(GNOME)/`git send-email` 三面恢复**：上一轮把「keyring 锁」列为最高优先人工项，本轮 `read-mail-ustc.py` 与 `glab api --hostname gitlab.gnome.org` 均**一次成功**（无需 `--noproxy`）。
2. **`git.kernel.org` plain 用默认 curl UA 可直通**（`200` + 真实源码，47 KB 级文件正常）；**`-L` 必须加**（`commit/?id=` 返回 `301`，不带 `-L` 会得到 0 字节）。
3. **`lore` 侧 `t.mbox.gz` + 默认 curl UA 全程可用**（11 条线程 11 次 200）；解析要点：mbox 分隔符是 `From mboxrd@z Thu Jan  1 00:00:00 1970`，**不是** `From <40-hex>`（按后者切会得到 `total entries: 0` 的假空线程）。
4. **media CI（`patchwork@media-ci.org`）是真实硬门**：它跑 `media-patchstyle` + `checkpatch`，`ERROR: Fails one or more mandatory checkpatch tests` 会直接挡审。**commit message 也受 checkpatch 约束**（行长、`commit <sha> ("title")` 不折行、行首不许出现 `Cc:` 之类 trailer 样式）——这与 `sashiko` 的代码级评审是两回事，**两者都要过**。
5. `gh api` 的 stdout 尾部会被追加 `gh event listen` 提示行 ⇒ 直接 `json.load` 会 `Extra data`；用 `--jq` 取字段，或把 JSON 写文件再解析。
6. `read-mail-ustc.py` 只取头（`BODY.PEEK[HEADER.FIELDS …]`）；读正文用临时脚本 `BODY.PEEK[]`（默认 `\Seen` 不变），本报告脚本 `/tmp/d10-fetch-body.py`（§附录）。

---

## §9 残差（如实）

1. **未做全域 lore 扫**（上一轮用 `lore-query.py` 扫过 79 线程）：本轮按派工单点查 11 条线程 + 三箱天花板两路交叉；**若某条我方线程在 `11-27T22:17Z` 之后有新人说话但既没进 INBOX 也没被我点到的 11 条覆盖，本轮会漏**（概率低：所有在飞线程都已点查）。
2. **`10490` 的 CI 报告页未取**（`https://linux-media.pages.freedesktop.org/.../jobs/117534681/artifacts/report.htm`）；本报告的结论依据 = CI 正文 + **本机 checkpatch 复现**（2 errors / 5 warnings）。
3. **patchwork 仍未作判据**（Anubis）；`10488` 的 `Changes Requested` 只当状态变化记账。
4. **hexagonrpc #31 的 CI 失败原因未深挖**（`action_required` = 首次贡献者待批准，与上一轮同结论）。
5. `git status` 里 `M rootfs/build-sysroot.sh`、`?? reports/artifacts/gmobile-elden-20261128/`、`?? rootfs/cross-aarch64-gmobile.ini` 是**别的 lane** 的在途改动，本 lane 未触碰。

---

## 附录：本轮全部命令（只读，可逐条复现）

```bash
# 0) 现场与纪律
cd /home/xuqianhui/y700-elden && git rev-parse --show-toplevel   # /home/xuqianhui/y700-elden
date -u                                                          # 2026-11-28T02:18:11Z（末核 02:2xZ）
git status --porcelain                                           # 仅别的 lane 的在途件，本 lane 零改动

# 1) 邮件三箱（BODY.PEEK）+ 逐封正文
timeout -k 5 300 /home/xuqianhui/.local/bin/read-mail-ustc.py --days 2 --limit 400   # rc=0，67/20/32 封
python3 /tmp/d10-fetch-body.py 10472 10486 10489 10484 10485 10488 10490 10481       # BODY.PEEK[]，正文精读
grep -i -E 'mailer-daemon|postmaster|Delivery Status|Undelivered|returned to sender' /tmp/d10-mail-20261128.txt  # 0 命中

# 2) lore 线程归档核对（11 条 cover MID）
python3 /tmp/d10-lore.py 20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn \   # coresight v1，4 entries
                        20261126052049.1544229-1-xiaqinghuan@mail.ustc.edu.cn \   # dsi-phy v3，2
                        20261127152024.2149804-1-xiaqinghuan@mail.ustc.edu.cn \   # iris 0/3，6
                        20261127133017.1606830-1-xiaqinghuan@mail.ustc.edu.cn \   # coresight v2，3
                        20261127113158.932414-1-xiaqinghuan@mail.ustc.edu.cn \    # TNOC，5
                        20261126052057.1544590-1-xiaqinghuan@mail.ustc.edu.cn \   # elden v10，4
                        20261125142309.3265777-1-xiaqinghuan@mail.ustc.edu.cn \   # dwc3 v16，5
                        20261113155635.1677541-1-xiaqinghuan@mail.ustc.edu.cn \   # mdss v5，12
                        20261125022328.680070-1-xiaqinghuan@mail.ustc.edu.cn \    # fastrpc v3，8
                        20261116040049.434247-1-xiaqinghuan@mail.ustc.edu.cn \    # pstore，4
                        20261124045040.559317-1-xiaqinghuan@mail.ustc.edu.cn \    # aw86927 v4，7
                        20261128003737.1300698-1-xiaqinghuan@mail.ustc.edu.cn      # iris v2（与 v1 同线程）

# 3) 内容级进树（torvalds + next，默认 curl UA + -L）
curl -sSL 'https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=1facae9bc3c1'
curl -sSL 'https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/drivers/media/platform/qcom/iris/iris_vidc.c'      # :486 "platform:%s:%s"
for b in torvalds/linux.git next/linux-next.git; do
  curl -sSL "https://git.kernel.org/pub/scm/linux/kernel/git/$b/plain/drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c" | grep -c PLL_SYSTEM_MUXES   # 2
done
curl -sSL 'https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts'      # 404
curl -sSL 'https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain/drivers/hwtracing/coresight/coresight-ctcu-core.c'     # MODULE_DEVICE_TABLE=0

# 4) 本地复现 media CI 的 checkpatch 失败（只读）
cd /tmp/base-wt && perl scripts/checkpatch.pl \
  /home/xuqianhui/y700-elden/patches/upstream/v4l2-compliance-iris-20261127/0002-v2-fill-default-colorspace.patch
#   → 2 errors, 5 warnings, 43 lines checked

# 5) 用户态上游（只读）
glab api --hostname gitlab.gnome.org 'projects/World%2FPhosh%2Fgmobile/merge_requests/131'
glab api --hostname gitlab.gnome.org 'projects/World%2FPhosh%2Fphoc/issues/125'
glab api --hostname gitlab.gnome.org 'projects/World%2FPhosh%2Fphoc/issues/125/notes?per_page=100&sort=asc'
glab api --hostname gitlab.gnome.org 'projects/World%2FPhosh%2Fphosh/merge_requests/2005/notes?per_page=100'
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
curl -sS 'https://gitlab.com/api/v4/groups/mobian1/merge_requests?state=opened&per_page=50'
curl -sS 'https://salsa.debian.org/api/v4/groups/Mobian-team/merge_requests?state=opened&per_page=100'
env -u https_proxy -u http_proxy -u all_proxy gh issue view 69 --repo denialwm/droidloom --json state,createdAt,updatedAt,comments
env -u https_proxy -u http_proxy -u all_proxy gh issue view 48 --repo denialwm/droidloom --json comments
env -u https_proxy -u http_proxy -u all_proxy gh api repos/linux-msm/hexagonrpc/pulls/31 --jq '"\(.state) \(.updated_at) \(.mergeable_state)"'
```

■ 结束
