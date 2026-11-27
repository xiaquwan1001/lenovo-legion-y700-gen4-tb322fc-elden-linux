# 通信跟踪 D10-c（窗口 `2026-11-27T03:29Z` → `2026-11-27T04:07Z`）— 只读

> **只读纪律**：本文件是本轮**唯一**写入；未发信、未回信、未推 MR、未改 `TASKS/`、未 `git commit`、未调用 `grow_loop`。
> **增量基线** = `reports/comm-triage-20261127-b.md`（该轮窗口收口 `2026-11-27T03:29Z`，现场核对时刻 `03:28:39Z`）。
> **本轮现场核对时刻**：`2026-11-27T04:07:17Z`（`date -u` 实测）。窗口长度 ≈ **38 min**。
> 每条断言附「命令 + 原始片段 + 时间戳」；无据的一律标「未核 / 不可达」，不做推断。

---

## §0 数字结论

| 指标 | 值 | 依据 |
|---|---|---|
| **人类新消息 N** | **0 封 / 0 条** | IMAP 三箱窗口内 0（§2）；lore 四线程封数与末封时刻全部与上轮一致（§3）；GitHub `#31` reviews/comments 仍 `0/0/0`、`#21` 末条仍是我方 `02:28:33Z`（§1）；GitLab `!46` `user_notes_count=0` 且 `updated_at` 仍 `2026-11-23`、salsa 15 个 open MR 最新 `updated_at` = `2026-11-22`（§4） |
| **机器人条数 M** | **0 条** | sashiko 四个系列最后发言仍是 elden v10 的 `2026-11-26 05:30Z`（§3 封数 4 / 5 / 1 / 7，与上轮逐一对齐） |
| **我方欠动作 K（窗口内新增）** | **0 项** | 无新问题、无新评审意见、无退信 |
| **重点项结论：PR `#31` CI 是否已获批准开始跑** | **没有。仍是 `action_required`，且窗口内没有产生任何新 run** | 5 次 `Build+test` 全 `action_required`；最新一次 `created_at = run_started_at = 2026-11-27T03:09:14Z`（= 从未真正启动，且早于窗口起点）；仓库级最新 run 仍就是这一条（§1.2） |
| 账外既有欠账（**非本轮新增**） | **2 项** | ① phosh `!2005` 回 guidog = 外发，需用户放行（本轮该站 5 通道全不可达，无法复核，§4.3）；② PR `#31` CI 等维护者点批准（非我方动作，§1.2） |
| 工具不可达（如实记） | **2 面** | ① `gitlab.gnome.org`：curl 三路 **406 / 0 字节**，`web_fetch` 的 firecrawl **402 额度耗尽**、tavily 失败、anysearch **422**、headless Firefox **500 无文本**、exa 空正文（§4.3）；② `gitlab.com` `!46/notes` 匿名 **401**（沿用对象上 `user_notes_count`，§4.1） |

一句话：**本轮窗口内他人零消息、机器人零消息、我方零新增欠账；`PR #31` 的 CI 仍在等维护者批准（`action_required` 第 5 次，且 03:29Z 后连新 run 都没有）。**

---

## §1 【重点】GitHub `linux-msm/hexagonrpc`：PR `#31` 的 CI 与评审

### 1.1 通道

`gh` 有登录态（`xiaquwan1001`，keyring），全部调用**只读**，无任何 mutation：

```
$ gh auth status
github.com
  ✓ Logged in to github.com account xiaquwan1001 (keyring)
  - Token: gho_************************************
```

### 1.2 判据行：CI 是否出现非 `action_required` 的 `Build+test` ⇒ **没有**

```
$ gh run list -R linux-msm/hexagonrpc --limit 6 --json conclusion,status,workflowName,headBranch,createdAt
[{"conclusion":"action_required","createdAt":"2026-11-27T03:09:14Z","headBranch":"writable-overlay","status":"completed","workflowName":"Build+test"},
 {"conclusion":"action_required","createdAt":"2026-11-27T03:02:53Z","headBranch":"writable-overlay","status":"completed","workflowName":"Build+test"},
 {"conclusion":"action_required","createdAt":"2026-11-27T02:45:58Z","headBranch":"writable-overlay","status":"completed","workflowName":"Build+test"},
 {"conclusion":"action_required","createdAt":"2026-11-27T02:28:11Z","headBranch":"writable-overlay","status":"completed","workflowName":"Build+test"},
 {"conclusion":"action_required","createdAt":"2026-11-27T02:14:43Z","headBranch":"writable-overlay","status":"completed","workflowName":"Build+test"},
 {"conclusion":"action_required","createdAt":"2026-11-22T21:52:20Z","headBranch":"sdm845-lg-judyln-paths","status":"completed","workflowName":"Build+test"}]
```

**6 条里 6 条 `action_required`，无一条 `success`/`failure`/`cancelled`。**

补充证据（仓库级，不加 branch 过滤，证明窗口内**没有**新 run）：

```
$ gh api 'repos/linux-msm/hexagonrpc/actions/runs?per_page=6' --jq '.workflow_runs[] | "\(.created_at) | \(.name) | \(.status) | \(.conclusion) | branch=\(.head_branch) | started=\(.run_started_at)"'
2026-11-27T03:09:14Z | Build+test | completed | action_required | branch=writable-overlay | started=2026-11-27T03:09:14Z
2026-11-27T03:02:53Z | Build+test | completed | action_required | branch=writable-overlay | started=2026-11-27T03:02:53Z
2026-11-27T02:45:58Z | Build+test | completed | action_required | branch=writable-overlay | started=2026-11-27T02:45:58Z
2026-11-27T02:28:11Z | Build+test | completed | action_required | branch=writable-overlay | started=2026-11-27T02:28:11Z
2026-11-27T02:14:43Z | Build+test | completed | action_required | branch=writable-overlay | started=2026-11-27T02:14:43Z
2026-11-22T21:52:20Z | Build+test | completed | action_required | branch=sdm845-lg-judyln-paths | started=2026-11-22T21:52:20Z
```

三点判读（均为原始字段，不是推测）：
1. 最新一条 run 的 `created_at == run_started_at == 2026-11-27T03:09:14Z` ⇒ 该 run **从未真正开始**，`action_required` = 停在 GitHub 的「首次贡献者 workflow 需人工批准」闸上。
2. 该 run 的时刻 **早于本窗口起点 `03:29Z`** ⇒ 窗口内 **零新 run**（无新 push，也无「批准后补跑」）。
3. **不是我们代码的问题**：`action_required` 的 run 不产出任何 build log；`combined status` 因此恒为 `pending / 0 statuses`（§1.3）。

同一仓库里另一位非维护者 `sajattack` 的 PR `#30`（`sdm845-lg-judyln-paths`）自 `2026-11-22T21:52:20Z` 起**同样停在 `action_required`（已 4 天+）** ⇒ 这是仓库级「非写权限贡献者需批准」策略，非本 PR 独有。

我方**无法自行批准**：

```
$ gh api repos/linux-msm/hexagonrpc --jq '...permissions'
"permissions":{"admin":false,"maintain":false,"pull":true,"push":false,"triage":false}
$ gh api repos/linux-msm/hexagonrpc/actions/runs/45932485832/approvals
[]
```

（`approvals` 返回 `[]` 原样记录，不做「是否表示无待批」的推断；`push:false` 已足以证明我方点不了「Approve and run」。）

### 1.3 PR `#31` 对象：views / comments / reviews（全部零变化）

```
$ gh api repos/linux-msm/hexagonrpc/pulls/31 --jq '{number,title,state,draft,created_at,updated_at,mergeable,mergeable_state,comments,review_comments,commits,changed_files,additions,deletions,head:.head.ref,sha:.head.sha}'
{"additions":1279,"changed_files":17,"comments":0,"commits":6,
 "created_at":"2026-11-27T02:14:39Z","deletions":81,"draft":false,"head":"writable-overlay",
 "mergeable":true,"mergeable_state":"unstable","number":31,"review_comments":0,
 "sha":"5aed5eb5ddea07b6f87a0a58bffc4c52b39774d3","state":"open",
 "title":"hexagonrpcd: serve the write side of the file service from a copy-up overlay",
 "updated_at":"2026-11-27T03:09:39Z"}
$ gh api repos/linux-msm/hexagonrpc/pulls/31/reviews --jq length          -> 0
$ gh api repos/linux-msm/hexagonrpc/pulls/31/comments --jq length         -> 0   (inline review comments)
$ gh api repos/linux-msm/hexagonrpc/issues/31/comments --jq length        -> 0
$ gh api repos/linux-msm/hexagonrpc/commits/5aed5eb5ddea.../status --jq '{state,total:(.statuses|length)}'
{"state":"pending","total":0}
$ gh api repos/linux-msm/hexagonrpc/commits/5aed5eb5ddea.../check-runs --jq '.check_runs[] | "\(.name) | \(.status) | \(.conclusion) | \(.completed_at)"'
DCO | completed | success | 2026-11-27T03:09:11Z
```

- **`updated_at = 2026-11-27T03:09:39Z` 早于窗口起点 `03:29Z`** ⇒ 窗口内该 PR **零事件**（无评论、无 review、无 push、无状态变化）。
- views 数：GitHub REST 不提供 PR 浏览量（`traffic/views` 只覆盖仓库/热门 path，且需 `push` 权限，我方 `push:false`）⇒ **"views" 本轮标「接口不存在/无权限，未核」**，不以记忆值充数。
- 唯一 check 仍是 **DCO = success**（`03:09:11Z`，probot DCO app），与上轮相同。
- `mergeable_state = unstable` 仍是「check 缺结果」造成，非代码红。

### 1.4 issue `#21`（`Stub support for fwrite, fremove, fclose_fd, fopen_with_env_fd`）

```
$ gh api repos/linux-msm/hexagonrpc/issues/21 --jq '{state,updated_at,comments,title}'
{"comments":11,"state":"open","title":"Stub support for fwrite, fremove, fclose_fd, fopen_with_env_fd","updated_at":"2026-11-27T02:28:33Z"}
$ gh api repos/linux-msm/hexagonrpc/issues/21/comments --jq '"count=\(length) first=\(.[0].created_at) last=\(.[-1].created_at) lastby=\(.[-1].user.login)"'
count=11 first=2026-03-23T19:34:08Z last=2026-11-27T02:28:33Z lastby=xiaquwan1001
```

**无新评论**：条数 11、`updated_at = 02:28:33Z`（窗口前 1 h），末条仍是**我方** `xiaquwan1001`。其上一条人类发言仍是 `z3ntu` 的 `2026-08-18T07:13:04Z`（`"Just a sidenote, I don't think I'll be able to work on this in the …"`）。

### 1.5 仓库侧人类活动（旁证：窗口内维护者零动作）

```
$ gh api 'repos/linux-msm/hexagonrpc/commits?per_page=3' --jq '...'
2026-09-15T07:54:57Z | Guido Günther | rpcd: Map `-h` to help
2025-08-14T21:48:34Z | Richard Acayan | tests: add unit test for hexagonrpc function
2025-07-03T22:48:00Z | Richard Acayan | libhexagonrpc: remove legacy APIs
$ gh api repos/linux-msm/hexagonrpc --jq '{pushed_at,updated_at,open_issues_count}'
{"open_issues_count":8,"pushed_at":"2026-10-01T00:37:41Z","updated_at":"2026-10-21T10:18:15Z"}
```

`main` 最后一次人类提交 = `2026-09-15`（Guido Günther）⇒ 仓库维护节奏本身很慢，不能据此推断「维护者拒看」，仅作事实记账。

---

## §2 IMAP 三箱增量（INBOX / Junk E-mail / Sent Items）

### 2.1 通道（keyring 未锁，未重试）

脚本 = 上轮 `/tmp/d13b_scan.py` 的逐字节副本，**只改 3 行**（`diff` 原文）：

```
$ cp /tmp/d13b_scan.py /tmp/d13c_scan.py && sed -i 's/2026, 11, 27, 1, 10, tzinfo/2026, 11, 27, 3, 29, tzinfo/' ...
2c2
< """D10b incremental read-only IMAP scan (2026-11-26). ..."""
> """D10c incremental read-only IMAP scan (2026-11-26). ..."""
27c27
< CUT = datetime.datetime(2026, 11, 27, 1, 10, tzinfo=datetime.timezone.utc)  # D10-b window start
> CUT = datetime.datetime(2026, 11, 27, 3, 29, tzinfo=datetime.timezone.utc)  # D10-b window start
66c66
< json.dump(rows, open("/tmp/d13b_rows_1127.json", "w"), ...)
> json.dump(rows, open("/tmp/d13c_rows_1127.json", "w"), ...)
```

读取形态不变：`select(readonly=True)` + `BODY.PEEK[HEADER.FIELDS (DATE FROM TO CC SUBJECT MESSAGE-ID IN-REPLY-TO)]`（**不置 `\Seen`**）。

### 2.2 原始日志（逐字，`/tmp/d13c_scan.log`，exit=0）

```
STATUS INBOX OK "INBOX" (MESSAGES 10459 UIDVALIDITY 1)
SINCE 26-Nov: 36 msgs INBOX
LAST INTERNALDATE in INBOX = 2026-11-26T20:33:46Z | Re: [PATCH v2 2/2] media: rockchip: rkcif: Honour the requested
 byte
STATUS "Junk E-mail" OK "Junk E-mail" (MESSAGES 233 UIDVALIDITY 5)
SINCE 26-Nov: 19 msgs "Junk E-mail"
LAST INTERNALDATE in "Junk E-mail" = 2026-11-26T13:27:05Z | [RFC PATCH v1] libcamera: pipeline: simple: Handle failed capture
 be
STATUS "Sent Items" OK "Sent Items" (MESSAGES 374 UIDVALIDITY 3)
SINCE 26-Nov: 7 msgs "Sent Items"
LAST INTERNALDATE in "Sent Items" = 2026-11-26T05:21:04Z | [PATCH v10 2/2] arm64: dts: qcom: sm8750-lenovo-elden: add Lenovo Legi
total rows after cut 2026-11-27T03:29:00+00:00: 0
```

**判读 = 0 新件**，且有两条独立互证：

1. **箱总数与上轮完全相同**（INBOX `10459`、Junk `233`、Sent `374`，上轮同值）⇒ 窗口内**没有任何邮件到达或离开**。
2. 三箱的「箱内最后一件」时刻（`2026-11-26T20:33:46Z` / `2026-11-26T13:27:05Z` / `2026-11-26T05:21:04Z`）**全部落在 11-26，早于窗口起点 `2026-11-27T03:29Z`**。

### 2.3 边界复核（证明「0」不是切点算错）

`SEARCH SINCE "27-Nov-2026"` 探针（服务器时区 `+0800`），逐字：

```
=== INBOX : SINCE 27-Nov-2026 -> 4 msgs
  uid=10456 idate=27-Nov-2026 02:09:52 +0800 | Barnabás Pőcze … Re: [PATCH 4/6] libcamera: egl: …
  uid=10457 idate=27-Nov-2026 02:09:52 +0800 | Barnabás Pőcze … Re: [PATCH 1/6] libcamera: egl: …
  uid=10458 idate=27-Nov-2026 02:09:55 +0800 | Barnabás Pőcze … Re: [PATCH 5/6] software_isp: benchmark: …
  uid=10459 idate=27-Nov-2026 04:33:46 +0800 | Faizel K B … Re: [PATCH v2 2/2] media: rockchip: rkcif: …
=== "Junk E-mail" : SINCE 27-Nov-2026 -> 0 msgs
=== "Sent Items" : SINCE 27-Nov-2026 -> 0 msgs
```

四件换算 UTC = `2026-11-26T18:09:5xZ` / `2026-11-26T20:33:46Z`，**全部早于 `03:29Z`** ⇒ 与 2.2 的 `total rows after cut … 0` 自洽。

| 箱 | 窗口内新件 | 退信/DSN | 箱内最后一件（INTERNALDATE, UTC） |
|---|---|---|---|
| INBOX | **0** | **0** | `2026-11-26T20:33:46Z`（uid 10459, Faizel K B, rkcif bytesperline v2 2/2） |
| Junk E-mail | **0** | 0 | `2026-11-26T13:27:05Z`（libcamera RFC） |
| Sent Items | **0** | — | `2026-11-26T05:21:04Z`（`[PATCH v10 2/2] … sm8750-lenovo-elden` = 上一批最后一封，窗口内**我方零外发**） |

四件与在飞系列无关（`elden|dwc3|wl2868c|aw86927|sm8750|TB322FC|dsi-phy` 零命中）。

---

## §3 lore 四系列：线程封数与末封时间（全部零新增）

页面统一取免 Anubis 镜像 `https://lore-kernel.gnuweeb.org/all/<MID>-xiaqinghuan@mail.ustc.edu.cn/t/`（`curl -sSL`，4 页 HTTP 200）。

| 系列 | 线程页 | 封数（页内原始） | 末封（页内时间戳） | 窗口内新封 |
|---|---|---|---|---|
| elden 板 DTS **v10** | <https://lore-kernel.gnuweeb.org/all/20261126052057.1544590-1-xiaqinghuan@mail.ustc.edu.cn/t/> | `0 siblings, 2 replies` / `Thread overview: 4+ messages` | **`2026-11-26  5:30`**（`sashiko-bot`；页脚 `other threads:[~2026-11-26 5:30 UTC]`，`?t=20261126053006`） | **0** |
| dwc3 **v16** | <https://lore-kernel.gnuweeb.org/all/20261125142309.3265777-1-xiaqinghuan@mail.ustc.edu.cn/t/> | `0 siblings, 4 replies` / `5+ messages in thread` | **`2026-11-25 14:36`**（页脚 `~2026-11-25 14:36 UTC`，`?t=20261125143614`） | **0** |
| M6 DSI-PHY **v3** | <https://lore-kernel.gnuweeb.org/all/20261126052049.1544229-1-xiaqinghuan@mail.ustc.edu.cn/t/> | `0 siblings, 0 replies` / `only message in thread` | 我方唯一封 `2026-11-26  5:20`（页脚 `~2026-11-26 5:21 UTC`，`?t=20261126052110`） | **0** |
| aw86927 **v4** | <https://lore-kernel.gnuweeb.org/all/20261124045040.559317-1-xiaqinghuan@mail.ustc.edu.cn/t/> | `0 siblings, 6 replies` / `7+ messages in thread` | **`2026-11-24  4:50`**（我方 6/6；页脚 `~2026-11-24 4:50 UTC`，`?t=20261124045054`） | **0** |

原始片段（每页首行线程元数据 + 末行时间戳，逐字）：

```
=== 20261126052057.1544590-1  (elden v10)     HTTP 200 size=29708
0 siblings, 2 replies
2026-11-26  5:20 ` …[PATCH v10 2/2] arm64: dts: qcom: sm8750-lenovo-elden: add Lenovo Legion Y700 Gen4, a Qualcomm SM8750-based tablet…  Qianhui Xu
2026-11-26  5:30   ` …sashiko-bot
end of thread, other threads:[~2026-11-26  5:30 UTC | newest]

=== 20261125142309.3265777-1  (dwc3 v16)       HTTP 200 size=74944
0 siblings, 4 replies
2026-11-25 14:23 ` …[PATCH v16 0/4] usb: dwc3: …  Qianhui Xu
2026-11-25 14:36 ` …[last reply]
end of thread, other threads:[~2026-11-25 14:36 UTC | newest]

=== 20261126052049.1544229-1  (M6 DSI-PHY v3)  HTTP 200 size=7893
0 siblings, 0 replies
only message in thread, other threads:[~2026-11-26  5:21 UTC | newest]
2026-11-26  5:20 …[PATCH v3] drm/msm/dsi/phy: …  Qianhui Xu

=== 20261124045040.559317-1  (aw86927 v4)      HTTP 200 size=44063
0 siblings, 6 replies
2026-11-24  4:50 ` …[last of our 6]
end of thread, other threads:[~2026-11-24  4:50 UTC | newest]
```

**封数（4 / 5 / 1 / 7）与 `reports/comm-triage-20261127-b.md` §2.1 逐一对齐** ⇒ 窗口内**零新封、零新评审意见**，故本轮**无新增原文可摘**（无新邮件即无「新增原文」，不以旧文冒充新文）。

四线程当前等待对象（沿用上轮口径，本轮未变）：`elden v10` 等 Bjorn/Konrad；`dwc3 v16` 等 Thinh/Greg；`M6 v3` 等 Dmitry/Rob；`aw86927 v4` **连 sashiko 都未审**（静默已 ≈ 72 h）。

> 进树复核（linux-next `next-20261127`）本轮**未做**：任务书本轮只要求「线程页封数与末封时间」。上轮口径是 `next-20261126`（`a9c48428cbd8`，7.4.0-rc4）四个系列全部「未进树」，该结论在窗口 38 min 内不可能被推翻（维护者树无法在窗口内合并+进 next 快照）；下轮按 §5 第 3 条一并重跑。

---

## §4 Mobian 与 phosh/phoc

### 4.1 `gitlab.com/mobian1/droid-juicer` `!46`（我方，匿名 API 可读）

```
$ curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
{'iid': 46, 'title': 'configs: add Lenovo Legion Y700 Gen4 (TB322FC)', 'state': 'opened',
 'detailed_merge_status': 'mergeable', 'user_notes_count': 0,
 'created_at': '2026-11-21T09:31:14.341Z', 'updated_at': '2026-11-23T11:10:29.562Z',
 'sha': 'ea9fe3d5c3bb81c246b959c2f0c6ca6ca07c4c4d', 'draft': False, 'has_conflicts': False}
$ curl -sS '.../merge_requests/46/notes?per_page=100' -w '\nHTTP %{http_code}\n'
{"message":"401 Unauthorized"}
HTTP 401
```

**`!46` 无新 note**：`user_notes_count = 0`、`updated_at` 仍 = `2026-11-23T11:10:29.562Z`（跨本窗口零变化；距 `updated_at` 已 **≈ 89 h** 无变化，自创建 `2026-11-21T09:31Z` 起 **≈ 115 h 零人回复**）。`/notes` 匿名 401 原样记录，**不据此推翻** `user_notes_count`。

### 4.2 `Mobian-team/mobian-recipes`（15 个 open MR，**均非我方**；仓库在 salsa 不在 gitlab.com）

```
$ curl -sS 'https://gitlab.com/api/v4/projects/Mobian-team%2Fmobian-recipes/merge_requests?state=opened'
HTTP 404          # ⇒ 该路径在 gitlab.com 不存在（沿用上轮已纠正的口径）
$ curl -sS 'https://salsa.debian.org/api/v4/projects/Mobian-team%2Fmobian-recipes/merge_requests?state=opened&per_page=100'
HTTP 200
open = 15
mine = 0
173 2026-11-22T09:33:52.088Z yifei    notes=1 Enable CI for Lomiri images
172 2026-10-22T16:13:33.373Z g0tmi1k  notes=1 qcom/extract-parts: cd $ARTIFACTDIR
166 2026-10-21T10:34:11.061Z g0tmi1k  notes=0 CI: Add pipeline check for devices/
170 2026-10-21T10:30:02.509Z g0tmi1k  notes=1 sunxi: Treat a pkg as installed if it really is
164 2026-10-04T13:52:27.689Z tiol     notes=4 Draft: Improve devices/qcom/bootloader.sh by makin
```

**窗口内零更新**：最大 `updated_at` 仍 = `2026-11-22T09:33:52.088Z`（`!173`，`yifei`）；**我方 0/15** ⇒ 无可跟踪项。

### 4.3 `gitlab.gnome.org`：phosh `!2005` 与 phoc `#125` —— **不可达，5 通道全失败（如实记）**

```
$ curl -sS -m 25 -o /dev/null -w 'HTTP %{http_code} size=%{size_download}\n' \
    'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphosh/merge_requests/2005'
HTTP 406 size=0
$ curl -sSL -m 25 -A 'Mozilla/5.0 (X11; Linux x86_64) … Chrome/120.0' -o /dev/null -w … \
    'https://gitlab.gnome.org/World/Phosh/phosh/-/merge_requests/2005'
HTTP 406 size=0
$ curl -sS -m 25 -x http://127.0.0.1:7890 -o /dev/null -w … \
    'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphoc/issues/125'
HTTP 406 size=0
```

`web_fetch` 五路（本轮新增尝试）：

```
firecrawl  -> HTTP 402  "Insufficient credits … your team has 0 left, plan credits resetting at 2026-12-20T11:37:46.927Z"
tavily     -> Failed to fetch url
anysearch  -> HTTP 422  "Unable to extract content from the URL."
browser(headless Firefox) -> HTTP 500 "page rendered but yielded no text"
exa        -> 空正文（Provider: Exa | <url>，无内容）
```

⇒ **`phosh !2005` 与 `phoc #125` 本轮一律「不可达 / 未核」**，不含任何推测值。
**firecrawl 额度已在 2026-11-27T04:0xZ 耗尽（`0 credits`，官方邮件口径重置 `2026-12-20`）** ⇒ 上轮 §5 第 3 条提的「下一轮用 firecrawl 取 gnome 页」这条路径**本轮起失效**，需换通道（见 §5 第 1 条）。

上一份**可读**快照（历史，非本轮现查）：`!2005` = 我方 MR、`opened`、`user_notes_count=1`（`guidog` `2026-11-14T13:12:08Z`「continue without AI」+ 建议 failed 时置 enabled、下次按键重试）、`detailed_merge_status = need_rebase`；phoc `#125` 末 note `2023-02-17`。**这些是否已变，本轮无法证实/否证**——记为盲区。

---

## §5 下一轮动作

**A. 必须做（只读，有明确触发条件）**

1. **`gitlab.gnome.org` 换通道**（本轮 5 通道全败，firecrawl 额度已归零）：候选顺序 = ① 本机有头 Firefox 渲染
   （`touch ~/pi-firefox/headed` → `node ~/.pi/agent/extensions/web-search/bin/browserfetch.mjs fetch <url> --headed` → 用完 `rm -f`）；
   ② `PI_FIREFOX_PROFILE` 带登录态；③ 都失败就**继续记「不可达」**，不得用记忆值充现查。
2. **PR `#31` CI 复查（重点项延续）**：`gh run list -R linux-msm/hexagonrpc --limit 6 --json conclusion,status,workflowName,headBranch,createdAt` +
   `gh pr view 31 --json reviews,comments,updatedAt`。判据：出现**非 `action_required`** 的 `Build+test` 即把真实 build/test 结果补进通信账；
   若仍 `action_required` 且 **`updated_at` 仍为 `2026-11-27T03:09:39Z`** ⇒ 说明维护者未上线，**不催**（我方 `push:false`，无批准权）。
3. **IMAP 续扫**：切点前移到本轮收口 `2026-11-27T04:07Z`
   （`cp /tmp/d13c_scan.py /tmp/d13d_scan.py` 后只改 `CUT` 与输出名）；关注 sashiko/Bjorn/Konrad/Greg/Thinh/Dmitry 回信与退信。
4. **lore 四线程封数**（同 §3 的 4 个 URL）：封数一旦 > `4 / 5 / 1 / 7` 就摘原文。
5. **进树复核**（上轮欠项，本轮未做）：`git ls-remote --tags …/linux-next.git 'next-20261127*'` + 上轮 4 行内容级 grep
   （`sm8750-lenovo-elden.dts` 存在性、`qcom.yaml` 的 `elden`、`snps,dwc3-common.yaml` 的 `mux-controls`、`aw86927.c` 的 `AW86937`、
   `dsi_phy_7nm.c` 的 `PLL_SYSTEM_MUXES` 落点函数）。

**B. 触发式（不到点不做）**

6. **`droid-juicer !46`**：`user_notes_count` 仍 0、`updated_at` 仍 `2026-11-23`（≈90 h）⇒ **不催**。
7. **`aw86927 v4`**：连 sashiko 未审、静默 ≈ 72 h ⇒ 到 **满 7 天（`2026-12-01`）** 仍零封再议「礼貌 ping / v5」。
8. **`elden v10` / `M6 v3`**：投出 `11-26T05:2xZ`，静默 ≈ 23 h ⇒ 不催；`elden 1/2` 无依赖，理论上可先合（cover 已写明顺序）。

**C. 口径/工具事实（给总管，不自行改文件）**

9. **firecrawl 额度归零**（`2026-12-20` 才重置）⇒ 后续任何 lane 依赖 firecrawl 取页都会 402，派工单里不要默认它可用。
10. `patchwork.kernel.org` 仍不可作判据（上轮原文：Anubis 挑战页，HTTP 200 非 JSON）；进树一律内容级 grep。
11. **views 数**：GitHub REST 无 PR 级浏览量接口且我方 `push:false` ⇒ 以后派工单里「PR views」应改写为「PR `updated_at` + timeline 事件」，
    两者等价可核。

---

## 附：本轮全部命令（只读，可逐条复现）

```bash
date -u                       # 2026-11-27T04:07:17Z

# §2 IMAP（keyring 未锁；readonly + BODY.PEEK）
cp /tmp/d13b_scan.py /tmp/d13c_scan.py   # 仅改 CUT -> 2026-11-27T03:29Z + 输出名
diff /tmp/d13b_scan.py /tmp/d13c_scan.py
timeout -k 5 300 python3 /tmp/d13c_scan.py | tee /tmp/d13c_scan.log
timeout -k 5 200 python3 /tmp/d13b_probe27.py | tee /tmp/d13c_probe27.log   # SEARCH SINCE 27-Nov-2026 边界复核

# §1 GitHub
gh auth status
gh run list -R linux-msm/hexagonrpc --limit 6 --json conclusion,status,workflowName,headBranch,createdAt
gh api 'repos/linux-msm/hexagonrpc/actions/runs?per_page=6' --jq '.workflow_runs[] | …'
gh api repos/linux-msm/hexagonrpc/pulls/31 --jq '{…}'
gh api repos/linux-msm/hexagonrpc/pulls/31/reviews  --jq length
gh api repos/linux-msm/hexagonrpc/pulls/31/comments --jq length
gh api repos/linux-msm/hexagonrpc/issues/31/comments --jq length
gh api repos/linux-msm/hexagonrpc/commits/5aed5eb5ddea/status     --jq '{state,total:(.statuses|length)}'
gh api repos/linux-msm/hexagonrpc/commits/5aed5eb5ddea/check-runs --jq '.check_runs[] | …'
gh api repos/linux-msm/hexagonrpc/actions/runs/45932485832/approvals
gh api repos/linux-msm/hexagonrpc --jq '{…permissions}'
gh api repos/linux-msm/hexagonrpc/issues/21 --jq '{…}'
gh api repos/linux-msm/hexagonrpc/issues/21/comments --jq '"count=\(length) …"'
gh api 'repos/linux-msm/hexagonrpc/issues/31/timeline?per_page=100'
gh pr list -R linux-msm/hexagonrpc --state all --limit 8 --json number,state,author,headRefName,createdAt,title

# §3 lore（4 个 MID）
for mid in 20261126052057.1544590-1 20261125142309.3265777-1 20261126052049.1544229-1 20261124045040.559317-1; do
  curl -sSL -A 'Mozilla/5.0' "https://lore-kernel.gnuweeb.org/all/$mid-xiaqinghuan@mail.ustc.edu.cn/t/" -o /tmp/lore_$mid.html
  grep -oE '[0-9]+ messages? in thread|only message in thread|0 siblings, [0-9]+ replies' /tmp/lore_$mid.html
  grep -oE 't=2026[0-9]+' /tmp/lore_$mid.html | head -1
done

# §4 GitLab / gnome
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46/notes?per_page=100'   # 401
curl -sS 'https://gitlab.com/api/v4/projects/Mobian-team%2Fmobian-recipes/merge_requests?state=opened'      # 404
curl -sS 'https://salsa.debian.org/api/v4/projects/Mobian-team%2Fmobian-recipes/merge_requests?state=opened&per_page=100'
curl -sS -m 25 -o /dev/null -w '%{http_code} %{size_download}\n' 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphosh/merge_requests/2005'  # 406 0
curl -sS -m 25 -x http://127.0.0.1:7890 … 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphoc/issues/125'                                  # 406 0
# web_fetch: firecrawl 402 / tavily fail / anysearch 422 / browser 500 / exa 空
```

■ 结束
