# 通信复扫 D10-b（窗口 `2026-11-27T01:10Z` → `2026-11-27T03:29Z`）— 只读

> **只读纪律**：本文件是本轮**唯一**写入；未发信、未回信、未推 MR、未改 `TASKS/`、未 `git commit`、未调用 `grow_loop`。
> **增量基线** = `reports/comm-triage-20261127.md` 末尾「补：2026-11-27 01:1xZ」节（该节把三箱增量核到 `2026-11-27T01:1xZ`）。
> **本轮现场核对时刻**：`2026-11-27T03:28:39Z`（`date -u` 实测，本 lane 有 shell）；落盘 ≈ `03:32Z`。
> **窗口长度 ≈ 2 h 19 min**（01:10Z → 03:29Z）。
> 下文每条断言都附「命令 + 原始片段」；无据的一律标「未核」或「不可达」。

---

## §0 数字结论

| 指标 | 值 | 依据 |
|---|---|---|
| **人类新消息 N** | **0 封 / 0 条** | IMAP 三箱窗口内 0（§1）；lore 四线程末封全部早于窗口起点（§2）；GitHub `#31` reviews/comments 均 `[]`、`#21` 末条 = 我方（§3）；GitLab `!46` `user_notes_count=0`、salsa 15 个 open MR 0 条我方且最新 `updated_at` = 11-22（§4） |
| **机器人条数 M** | **0 条** | sashiko 在四系列上最后一次发言 = `2026-11-26T05:30Z`（elden v10 2/2），早于窗口；窗口内无新 bot 封（§2 封数/末封时刻） |
| **我方欠动作 K（窗口内新增）** | **0 项** | 无新问题、无新评审意见、无退信（§1 退信 0） |
| 账外既有欠账（**非本轮新增**，仅记账） | **2 项** | ① phosh `!2005` 回 guidog = 外发，需用户放行（§4.3，本轮不可达无法复核）；② PR `#31` 的 CI 5 次 run 全 `action_required`（等维护者点批准，非我方动作，§3.2） |
| 本轮窗口内**我方**出站（非他人消息） | **2 件** | ① PR `#31` 创建 `02:14:39Z`、② issue `#21` 评论 `02:28:33Z`（§3，均由 `xiaquwan1001` 提交，非本 lane 所为） |
| 工具不可达（如实记） | **3 面** | ① `patchwork.kernel.org` API = Anubis 挑战页（HTTP 200 但非数据，§2 头）；② `gitlab.gnome.org` 三路全 **406 / 0 字节**（§4.3）；③ 附带：`gitlab.com` 的 `…/merge_requests/46/notes` 匿名 **401**（§4.1，用对象上的 `user_notes_count` 代替） |

一句话：**窗口内他人零消息、机器人零消息、我方零新增欠账；唯一实质变化是我方自己在窗口里把 hexagonrpc 的 `PR #31` 推上去了，且它的 CI 因「首次贡献者需批准」而全部没跑。**

---

## §1 IMAP 三箱增量（INBOX / Junk E-mail / Sent Items）

### 1.1 通道与脚本（可复现）

keyring **未锁**，`imaplib` 登录成功（无需 `sudo`、无需用户登录图形会话）。脚本 = 上一轮 `/tmp/d12_scan.py` 的逐字节副本，只改 3 行：

```bash
cp /tmp/d12_scan.py /tmp/d13b_scan.py
# 差异（diff 原文，本轮实测）
# 2c2  """D12 incremental ... """      ->  """D10b incremental ..."""
# 27c27  CUT = datetime.datetime(2026, 11, 26, 5, 55, ...)  # D11 window end
#        -> CUT = datetime.datetime(2026, 11, 27, 1, 10, ...)  # D10-b window start
# 66c66  /tmp/d12_rows_1126.json        ->  /tmp/d13b_rows_1127.json
timeout -k 5 300 python3 /tmp/d13b_scan.py
```

读取形态：`M.select(box, readonly=True)` + `BODY.PEEK[HEADER.FIELDS (DATE FROM TO CC SUBJECT MESSAGE-ID IN-REPLY-TO)]`（**不置 `\Seen`**）。

### 1.2 原始日志（逐字，`/tmp/d13b_scan.log`，exit=0）

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
total rows after cut 2026-11-27T01:10:00+00:00: 0
```

### 1.3 判读

| 箱 | 窗口内新件 | 其中我方线程回信 | 退信/DSN | 箱内最后一件（INTERNALDATE, UTC） |
|---|---|---|---|---|
| INBOX | **0** | 0 | **0** | `2026-11-26T20:33:46Z`（uid 10459, Faizel K B, rkcif bytesperline v2 2/2） |
| Junk E-mail | **0** | 0 | 0 | `2026-11-26T13:27:05Z`（libcamera RFC） |
| Sent Items | **0** | — | — | `2026-11-26T05:21:04Z`（`[PATCH v10 2/2] … sm8750-lenovo-elden` = 上一批最后一封） |

**边界复核**（证明「0」不是切点算错）：另跑一个只问「服务器本地日 27-Nov 之后」的探针
`python3 /tmp/d13b_probe27.py`（`SEARCH SINCE "27-Nov-2026"`，服务器时区 `+0800`）：

```
=== INBOX : SINCE 27-Nov-2026 -> 4 msgs
  uid=10456 idate=27-Nov-2026 02:09:52 +0800 | Barnabás Pőcze … Re: [PATCH 4/6] libcamera: egl: …
  uid=10457 idate=27-Nov-2026 02:09:52 +0800 | Barnabás Pőcze … Re: [PATCH 1/6] libcamera: egl: …
  uid=10458 idate=27-Nov-2026 02:09:55 +0800 | Barnabás Pőcze … Re: [PATCH 5/6] software_isp: benchmark: …
  uid=10459 idate=27-Nov-2026 04:33:46 +0800 | Faizel K B … Re: [PATCH v2 2/2] media: rockchip: rkcif: …
=== "Junk E-mail" : SINCE 27-Nov-2026 -> 0 msgs
=== "Sent Items" : SINCE 27-Nov-2026 -> 0 msgs
```

四件的 `INTERNALDATE` 换算成 UTC = `2026-11-26T18:09:5xZ` / `2026-11-26T20:33:46Z`，**全部早于窗口起点 `01:10Z`**
⇒ 与 1.2 的 `total rows after cut … 0` 自洽。**没有任何一封与在飞系列相关**（关键词 `elden|dwc3|wl2868c|aw86927|sm8750|TB322FC|dsi-phy` 零命中），**退信零封**。

> 与上一轮口径的差异（如实记）：上一轮「补」节报 INBOX 24 新件、Sent 0；本轮因切点前移到 `01:10Z`，同一批 36 件里被计入的只有 `>01:10Z` 的部分 = 0，两轮不矛盾。

---

## §2 lore / patchwork：四个在飞系列的「新回复」与「是否进树」

### 2.0 工具事实（本轮实测）

- `lore-kernel.gnuweeb.org`（免 Anubis 镜像）**可用**，`/all/<MID>-xiaqinghuan@mail.ustc.edu.cn/t/` 直接 `curl -sSL` 拿到完整线程页（本次 4 个页面 7.9 KB ~ 74.9 KB）。
- `patchwork.kernel.org/api/1.2/…` **仍是 Anubis 挑战页**，本轮原样记录（HTTP 200 但正文不是 JSON）：
  ```
  $ curl -sS -A 'Mozilla/5.0' 'https://patchwork.kernel.org/api/1.2/patches/?q=elden&per_page=2'
  HTTP 200 size=7044
  <!doctype html><html lang="en"><head><title>Making sure you&#39;re not a bot!</title>…
  ```
  ⇒ 按 `TASKS/UPSTREAM.md` §7 头口径（`/raw` 或挑战页的 200 **不得**当归档/合入证据，且 `commit_ref` 空值本来就不作证据），**patchwork 本轮不作为判据**，进树判定全部走 **linux-next / torvalds 内容级**（§2.2）。

### 2.1 线程封数对账（实测，末封时刻 = 判据）

| 系列 | 线程页 | 线程元数据（逐字） | 末封 | 窗口内新封 |
|---|---|---|---|---|
| elden 板 DTS **v10** | <https://lore-kernel.gnuweeb.org/all/20261126052057.1544590-1-xiaqinghuan@mail.ustc.edu.cn/t/> | `0 siblings, 2 replies; 4+ messages in thread` … `end of thread, other threads:[ ~2026-11-26 5:30 UTC \| newest ]` | **sashiko-bot `2026-11-26 5:30`** | **0** |
| dwc3 **v16** | <https://lore-kernel.gnuweeb.org/all/20261125142309.3265777-1-xiaqinghuan@mail.ustc.edu.cn/t/> | `0 siblings, 4 replies; 5+ messages in thread` … `end of thread, other threads:[ ~2026-11-25 14:36 UTC \| newest ]` | **sashiko-bot `2026-11-25 14:36`** | **0** |
| M6 DSI-PHY **v3** | <https://lore-kernel.gnuweeb.org/all/20261126052049.1544229-1-xiaqinghuan@mail.ustc.edu.cn/t/> | `0 siblings, 0 replies; only message in thread` … `only message in thread, other threads:[ ~2026-11-26 5:21 UTC \| newest ]` | 我方（唯一封） | **0** |
| aw86927 **v4** | <https://lore-kernel.gnuweeb.org/all/20261124045040.559317-1-xiaqinghuan@mail.ustc.edu.cn/t/> | `0 siblings, 6 replies; 7+ messages in thread` … `end of thread, other threads:[ ~2026-11-24 4:50 UTC \| newest ]` | 我方 6/6 `2026-11-24 4:50` | **0** |

四封数（4 / 5 / 1 / 7）与 `reports/comm-triage-20261127.md` §2.1 记的**完全一致** ⇒ 窗口内零新封。
**结论**：`elden v10`（等 Bjorn/Konrad）、`dwc3 v16`（等 Thinh/Greg）、`M6 v3`（等 Dmitry/Rob）、`aw86927 v4`（**连 sashiko 都没审**）四个线程**均无新回复**。

### 2.2 「是否进树」= 内容级现查（维护者树经 linux-next 覆盖）

被测树（本轮实测的版本与指针）：

```
$ git ls-remote --tags https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git 'next-20261126*'
a7e48407c0191a687deda50cf6ae3beb8c06de69  refs/tags/next-20261126
a9c48428cbd8d96b26f92631d0db6f8519c5fcc5  refs/tags/next-20261126^{}
$ git ls-remote https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git HEAD
a9c48428cbd8d96b26f92631d0db6f8519c5fcc5  HEAD
$ make -s -C /dev/null  # 版本：curl plain Makefile?h=master
VERSION = 7 / PATCHLEVEL = 4 / SUBLEVEL = 0 / EXTRAVERSION = -rc4   (linux-next 与 torvalds 同为 7.4.0-rc4)
```

> 即 **`next-20261126` 的 commit = `a9c48428cbd8d96b26f92631d0db6f8519c5fcc5` = next `master` HEAD**（tag 与 HEAD 同 sha）。

取文件方式（`git.kernel.org/…/plain/<path>?h=master`，**需 `-L`**，否则 301）：

| 系列 | 内容级标记（我方补丁实际加入的东西） | linux-next（`next-20261126`） | torvalds `master`（7.4-rc4） | 判读 |
|---|---|---|---|---|
| elden **v10** | 新文件 `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` + `bindings/arm/qcom.yaml` 含 `lenovo,elden` | 文件 **HTTP 404**；`qcom.yaml` 里 `elden` 命中 **0** | 同：**404**；`elden`=**0** | **未进树** |
| dwc3 **v16** | `bindings/usb/snps,dwc3-common.yaml` 新增 `mux-controls` 约束；`drivers/usb/roles/class.c` 里查找 graph endpoint 的 role switch | `mux-controls` 命中 **0**；`class.c` 里 `graph` 命中 **0** | `mux-controls`=**0** | **未进树** |
| M6 DSI-PHY **v3** | `dsi_phy_7nm.c` 的 `dsi_7nm_phy_enable()` 内新增 `writel(0xc0, … REG_DSI_7nm_PHY_PLL_SYSTEM_MUXES)` | 文件内 `PLL_SYSTEM_MUXES` 共 **2** 处（line 417 / 439），均在 `dsi_pll_enable_pll_bias`/`disable_pll_bias`；`dsi_7nm_phy_enable`（line 960–1193）体内命中 **0** | 同：417/439 两处，`dsi_7nm_phy_enable` 体内 **0** | **未进树**（这 2 处是上上游原有的，不是我们的补丁） |
| aw86927 **v4** | `drivers/input/misc/aw86927.c` 增 `AW86937_CHIPID 0x9370` / `AW86937` 枚举 | `AW86937` 命中 **0** | `AW86937`=**0** | **未进树** |

**M6 那两条「看起来命中了」必须点明区别**（否则极易误判成已合入），原始片段（torvalds `master`）：

```
396: }
398: static void dsi_pll_disable_pll_bias(struct dsi_pll_7nm *pll)
417:	writel(0,   pll->phy->pll_base + REG_DSI_7nm_PHY_PLL_SYSTEM_MUXES);
421: }
423: static void dsi_pll_enable_pll_bias(struct dsi_pll_7nm *pll)
439:	writel(0xc0, pll->phy->pll_base + REG_DSI_7nm_PHY_PLL_SYSTEM_MUXES);
442: }
```

而我方 v3 补丁的 hunk 落点是：

```
+++ b/drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c
@@ -1096,6 +1096,7 @@ static int dsi_7nm_phy_enable(struct msm_dsi_phy *phy,
+	writel(0xc0, pll->phy->pll_base + REG_DSI_7nm_PHY_PLL_SYSTEM_MUXES);
```

⇒ 两处的上下文/函数不同；`dsi_7nm_phy_enable` 体内 `PLL_SYSTEM_MUXES` 计数 = **0** ⇒ 未合入。

**口径声明**：本节的「进树」判据 = 上面 4 行 grep 的计数 + 文件存在性（内容级），**完全不看** patchwork `state`/`commit_ref`（§7 头已明确 `commit_ref` 空值不作证据）；同时**未**直接拉 4 位维护者各自的 git 树（`msm`/`usb`/`input`/`qcom` 树），理由是 linux-next `next-20261126` 已包含这些树且其当天快照晚于我方的最后投递（v16 `11-25T14:23Z`、v10/v3 `11-26T05:20Z`）——若维护者恰在 11-26 之后才取件，本判据会滞后（见 §5 复查项）。

---

## §3 GitHub `linux-msm/hexagonrpc`：PR #31 与 issue #21

### 3.0 通道（关键：REST 匿名 403 被限，但 `gh` **有登录态**）

```
$ curl -sS -o /dev/null -w 'api %{http_code}\n' https://api.github.com/repos/linux-msm/hexagonrpc/pulls/31
api 403
$ gh auth status
github.com
  ✓ Logged in to github.com account xiaquwan1001 (keyring)
$ gh api rate_limit --jq '.rate'
{"limit":5000,"remaining":4973,"reset":175753263,"used":27}
```

⇒ 本轮**不走匿名 REST、不走 HTML 爬**，用 `gh`（带 token，剩余 4973/5000）。**只读调用，未 mutation。**
（HTML 也已抓到兜底：`curl -sSL -A 'Mozilla/5.0 …' https://github.com/linux-msm/hexagonrpc/pull/31` → HTTP 200，299 935 B；`…/issues/21` → HTTP 200，476 865 B。）

### 3.1 PR #31 主对象（`gh pr view 31 --json …`，逐字段）

```
number = 31
title = hexagonrpcd: serve the write side of the file service from a copy-up overlay
state = OPEN          isDraft = False
createdAt = 2026-11-27T02:14:39Z     updatedAt = 2026-11-27T03:09:39Z
mergeable = MERGEABLE   mergeStateStatus = UNSTABLE
additions = 1279  deletions = 81  changedFiles = 17
baseRefName = main   headRefName = writable-overlay   author = xiaquwan1001
commits = 6
   620f39314f2e 2026-11-27T03:00:50Z interface/apps_std: declare the file methods the sensors PD uses
   63d872ad8ca6 2026-11-27T03:00:50Z hexagonrpcd: listener: survive signature mismatches and larger inbufs
   7e5f067cccc4 2026-11-27T03:06:33Z hexagonrpcd: serve DSP writes from a copy-up overlay
   be972b8b7b1e 2026-11-27T03:06:33Z hexagonrpcd: add -O DIR for the writable overlay
   894ef56f9d3f 2026-11-27T03:06:33Z hexagonrpcd: rpcd_builder: map sns_reg_version and parsed_file_list.csv
   5aed5eb5ddea 2026-11-27T03:06:33Z tests: cover the writable overlay
```

= 任务书说的「我们 6 提交可写 overlay」**已在档**（6/6，`+1279 / −81 / 17 files`）。
**窗口内事件时序（`gh api repos/…/issues/31/timeline`，逐字）**：

```
2026-11-27T02:28:07Z head_ref_force_pushed xiaquwan1001
2026-11-27T02:28:34Z cross-referenced xiaquwan1001
2026-11-27T02:45:52Z head_ref_force_pushed xiaquwan1001
2026-11-27T02:46:28Z ready_for_review xiaquwan1001
2026-11-27T03:02:47Z head_ref_force_pushed xiaquwan1001
2026-11-27T03:09:09Z head_ref_force_pushed xiaquwan1001
```
（`createdAt 02:14:39Z` + `ready_for_review 02:46:28Z` ⇒ 先以 draft 开出，32 min 后转正式评审。**全部 event 的 actor 都是我方**，无他人介入。）

### 3.2 评论 / review / CI（**关键发现：CI 一次都没真跑**）

```
$ gh pr view 31 --json reviews     -> {"reviews":[]}
$ gh pr view 31 --json comments    -> {"comments":[]}
$ gh api repos/linux-msm/hexagonrpc/pulls/31/comments --jq length -> 0
$ gh pr view 31 --json statusCheckRollup
{"statusCheckRollup":[{"__typename":"CheckRun","completedAt":"2026-11-27T03:09:11Z",
  "conclusion":"SUCCESS","detailsUrl":"https://probot.github.io/apps/dco/","name":"DCO",
  "startedAt":"2026-11-27T03:09:11Z","status":"COMPLETED","workflowName":""}]}
$ gh api repos/linux-msm/hexagonrpc/commits/5aed5eb5ddea/status --jq '{state,total:(.statuses|length)}'
{"state":"pending","total":0}
$ gh api 'repos/linux-msm/hexagonrpc/actions/runs?branch=writable-overlay&per_page=10'
5
2026-11-27T03:09:14Z | Build+test | completed | action_required | event=pull_request
2026-11-27T03:02:53Z | Build+test | completed | action_required | event=pull_request
2026-11-27T02:45:58Z | Build+test | completed | action_required | event=pull_request
2026-11-27T02:28:11Z | Build+test | completed | action_required | event=pull_request
2026-11-27T02:14:43Z | Build+test | completed | action_required | event=pull_request
```

判读（有据）：
1. **零评审、零评论**（review 0、issue-comment 0、inline review-comment 0）⇒ 维护者（`z3ntu` / `lumag` / `flamingradian`）尚未看。
2. 唯一的 check 是 **DCO = SUCCESS**（`probot` DCO app）。
3. **`Build+test` 的 5 次 run 全部 `conclusion = action_required`** = GitHub 在等**有写权限的人点「Approve and run」**（首次贡献者的 workflow 默认需批准；`head_ref_force_pushed` 5 次 ⇒ 5 次都重新触发又都卡在批准）。
   ⇒ **真实构建/测试结果目前不存在**；`mergeStateStatus = UNSTABLE` 与 `combined status pending / 0 statuses` 都由这个「等待批准」造成，不是我方代码红。
   （`gh api repos/…/contents/.github/workflows/build.yaml` 原文确认 `on: pull_request` ⇒ 本该自动跑，卡点在权限批准，不在触发条件。）
4. 我方**无法自行解除**（无该仓库写权限）⇒ 不是「我方欠动作」，是「等维护者批准 CI」。

### 3.3 issue #21（`Stub support for fwrite, fremove, fclose_fd, fopen_with_env_fd`）

```
number = 21  state = OPEN  author = z3ntu  labels = []
createdAt = 2026-03-20T16:11:17Z  updatedAt = 2026-11-27T02:28:33Z  comments = 11
```

末条（窗口内，**我方**）逐字：

```
2026-11-27T02:28:33Z | xiaquwan1001
Following the design you sketched here (`/var/...` copy-up, read falls back to the read-only tree), I put a working
implementation up as #31: writes go to a copy-up overlay (`-O DIR`, e.g. `/var/lib/hexagonrpcd`), reads are
overlay-first, and a file that only exists below `-R` cannot be removed or renamed (`-EPERM`). It is layered in
`hexagonfs` (`hexagonfs_openat_write()` + overlay-backed fds), so `apps_std` has no overlay logic.

It is verified on a TB322FC (SM8750P): the sensors PD writes its registry for real and `iio-sensor-proxy` reports
working accelerometer/ambient light/proximity. The `fwrite` definition there is `WORD + BLOB_SEQ + OUT_BLOB +
OUT_BLOB` (matches the `(1, 1, 2, 0)` counts reported here), and `fopen_with_env_fd` (36) is called at the end of
attach.

If you would rather have the overlay commits on this branch instead of a separate PR, I am happy to rebase them
here — just say which. Same for the `fopen_fd`/`fclose_fd` stubs: #31 has real implementations, so tell me if you
would prefer them as stubs first.
```

⇒ **issue #21 上他人最新发言仍是 2026-08-18T07:13:04Z（`z3ntu`：sidenote「…I don't think I'll be able to work on this in the coming month…」）**，
我方 11-27 那条之后**零回复**。

### 3.4 旁证：#29 窗口内我方评论之后亦零回复

```
$ gh api repos/linux-msm/hexagonrpc/issues/29 --jq '{state,updated_at,comments}'
{"comments":2,"state":"open","updated_at":"2026-11-27T01:18:43Z"}
末两条：… 2026-11-16T01:54:21Z | bruceythegoosey | … / 2026-11-27T01:18:43Z | xiaquwan1001 | …
```
（#29 的 `01:18:43Z` 那条已在上一节记账；本轮窗口内**没有**对它的回信。）

仓库近期全局（`issues?state=all&sort=updated&direction=desc`）：`31`（03:09:39Z，我方）、`21`（02:28:33Z，我方评论）、`29`（01:18:43Z，我方评论）、`30`（2026-11-24T21:07:15Z，`sajattack`，窗口外）⇒ **窗口内他人活动 0**。

---

## §4 Mobian 与 phosh

### 4.1 `gitlab.com/mobian1/droid-juicer` `!46`（我方，公开 API 匿名可读）

```
$ curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
iid = 46    title = configs: add Lenovo Legion Y700 Gen4 (TB322FC)
state = opened        detailed_merge_status = mergeable      user_notes_count = 0
created_at = 2026-11-21T09:31:14.341Z   updated_at = 2026-11-23T11:10:29.562Z
sha = ea9fe3d5c3bb81c246b959c2f0c6ca6ca07c4c4d   draft = False   has_conflicts = False
author = xiaquwan1001   web_url = https://gitlab.com/mobian1/droid-juicer/-/merge_requests/46
```

**`!46` 无新 note**：`user_notes_count = 0`，`updated_at` 仍 = `2026-11-23T11:10:29.562Z`（≈ **88 h 零变化**，跨本窗口零变化）。
`/notes` 端点匿名不可读，原样记录（不能据此推翻 `user_notes_count`）：

```
$ curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46/notes?per_page=100'
{"message":"401 Unauthorized"}
```

组内全景（`/api/v4/groups/mobian1/merge_requests?state=opened`）：**open 13 个、我方 1 个（仅 `!46`）**，其余作者
`gemausername/tiol11/dhxx/Danct12/meldegwi/dylanvanassche/…`，最新他人 `updated_at` = `2026-10-11T11:43:44Z`（`!45`）。

### 4.2 `Mobian-team/mobian-recipes` 的 15 个 open MR —— **不是我方，且不在 gitlab.com**

- `gitlab.com` 上**不存在**该路径：`GET https://gitlab.com/api/v4/projects/Mobian-team%2Fmobian-recipes/merge_requests?state=opened` → **HTTP 404** `{"message":"404 Project Not Found"}`。
- 真身 = **salsa.debian.org**（`salsa.debian.org/api/v4/projects/Mobian-team%2Fmobian-recipes/merge_requests?state=opened` → **HTTP 200**，211 379 B）：

```
open MRs = 15
mine (author == xiaquwan1001) = 0
!173 | 2026-11-22T09:29:55 | yifei       | notes=1 | upd=2026-11-22T09:33:52 | Enable CI for Lomiri images
!172 | 2026-10-21T20:07:36 | g0tmi1k     | notes=1 | upd=2026-10-22T16:13:33 | qcom/extract-parts: cd $ARTIFACTDIR
!170 | 2026-09-15T11:34:16 | g0tmi1k     | notes=1 | upd=2026-10-21T10:30:02 | sunxi: Treat a pkg as installed if it really is
!169 | 2026-09-15T11:34:09 | g0tmi1k     | notes=0 | upd=2026-09-15T11:57:03 | setup-luks: Take disk name from lsblk instead of regex
!168 | 2026-09-15T10:54:31 | g0tmi1k     | notes=0 | upd=2026-09-15T11:15:07 | Quote vars to setup-*.sh
!166 | 2026-09-15T10:49:09 | g0tmi1k     | notes=0 | upd=2026-10-21T10:34:11 | CI: Add pipeline check for devices/
!165 | 2026-09-15T10:29:44 | g0tmi1k     | notes=0 | upd=2026-09-15T13:25:32 | extract-bootimg: Fail when boot image is missing
!164 | 2026-07-28T14:04:39 | tiol        | notes=4 | upd=2026-10-04T13:52:27 | Draft: Improve devices/qcom/bootloader.sh …
!163 | 2026-07-24T13:14:40 | g0tmi1k     | notes=0 | upd=2026-07-24T13:16:21 | build.sh: Sync with GitLab CI
!158 | 2026-04-12T13:57:30 | pem120      | notes=2 | upd=2026-08-18T13:07:13 | Draft: Add intial support for msm8953 based devices.
!154 | 2025-12-24T17:40:15 | Iam_Tj      | notes=5 | upd=2026-01-12T20:37:54 | LUKS: fix bootonroot
!146 | 2025-07-21T08:10:31 | devrtz      | notes=2 | upd=2025-09-17T10:29:00 | build: Couple crypt_root option …
!117 | 2024-05-22T17:56:47 | julianfairfax| notes=1 | upd=2025-10-12T10:21:13 | rockchip: add dkms and gcc …
!59  | 2022-04-12T07:05:46 | a-wai       | notes=34| upd=2023-10-09T10:52:32 | console: introducing the console environment
!8   | 2020-09-24T18:53:10 | a-wai       | notes=2 | upd=2022-11-05T13:39:22 | WIP: Add shellcheck and bashate fixes …
```

⇒ **15 个 open MR 全部不是我方（0/15）**；最大 `updated_at` = `2026-11-22T09:33:52Z`，**窗口内零更新**。
（附带纠正一处长期口径：该仓库在 salsa.debian.org，不在 gitlab.com；上一轮报告里 `Mobian-team` 面「抓取失败/不可达」是因为打的是 gitlab.com 路径，本轮用 salsa API 已读通。）

### 4.3 `gitlab.gnome.org`：phosh `!2005` 与 phoc `#125` —— **不可达（406 / 0 字节），如实记**

三路都试（各 1 次，未硬绕）：

```
$ curl -sS 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphosh/merge_requests/2005?iids[]=2005'
direct-api  HTTP 406 size=0
$ curl -sSL -A 'Mozilla/5.0 (X11; Linux x86_64) … Chrome/120' 'https://gitlab.gnome.org/World/Phosh/phoc/-/issues/125'
direct-html HTTP 406 size=0
$ curl -sS -x http://127.0.0.1:7890 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphoc/issues/125'
proxy-7890  HTTP 406 size=0          # 7890 有监听（ss -ltnp 见 127.0.0.1:7890 + 192.168.7.9:7890）
```

⇒ **`phosh !2005` 与 `phoc #125` 本轮一律「未核」**，不含任何推测。上一份可读快照（`reports/comm-triage-2026112*.md`、`reports/phosh-mr-2005-rework-20261124.md`）记的是：
`!2005` = 我方 MR，`opened`、`user_notes_count=1`（guidog `2026-11-14T13:12:08Z`「continue without AI」+ 建议 failed 时置 enabled、下次按键重试），`detailed_merge_status = need_rebase`，此后无人类回复；
phoc `#125` 最后 note `2023-02-17`。**本轮无法证实/否证这些是否变了**——这是本 lane 的已知盲区（§5 第 3 条）。

---

## §5 下一轮动作清单

**A. 必须做（有明确触发条件，均为只读）**

1. **IMAP 续扫**（切点前移到 `2026-11-27T03:29Z`）：
   `cp /tmp/d13b_scan.py /tmp/d13c_scan.py && sed -i 's/2026, 11, 27, 1, 10/2026, 11, 27, 3, 29/' /tmp/d13c_scan.py && python3 /tmp/d13c_scan.py`
   关注点：① 是否出现 sashiko / Bjorn / Konrad / Greg / Thinh / Dmitry 对我方四个在飞系列的回信；② 退信（`mailer-daemon|postmaster|undeliver|delivery status`）。
2. **PR `#31` 的 CI 是否被批准**：`gh api 'repos/linux-msm/hexagonrpc/actions/runs?branch=writable-overlay&per_page=5'` ——
   只要 `conclusion` 从 `action_required` 变成 `success/failure`，就把真实 build/test 结果补进通信账；若长期停在 `action_required`，
   在 PR 上**不需要**催（内部触发机制），可由用户决定是否在 `#21` 里提一句「CI 等批准」。
3. **`gitlab.gnome.org` 换通道**：406 是本 lane 端口问题，不是上游状态。上一轮曾用 **Firecrawl/有头浏览器** 读到过页面；
   下一轮优先用 `web_fetch(provider="firecrawl")` 取 `https://gitlab.gnome.org/World/Phosh/phosh/-/merge_requests/2005`
   与 `…/phoc/-/issues/125`，取不到就**继续记「不可达」**，不要用记忆值冒充现查。

**B. 触发式（不到点不做）**

4. **`droid-juicer !46`**：`user_notes_count` 仍 0 且 `updated_at` 仍 `2026-11-23` ⇒ **不催**（≈88 h，队列慢是常态）。
5. **`aw86927 v4`**：线程 7 封、连 sashiko 都没审（我方 `11-24T04:50Z` 起静默 ≈ 47 h+22 h = **≈ 70 h**）⇒ 到 **满 7 天（12-01）**仍零封再议「礼貌 ping 或 v5」。
6. **`M6 DSI-PHY v3` / `elden v10`**：均 `11-26T05:2xZ` 投出，静默 ≈ 22 h ⇒ 不催（`elden 1/2` 无依赖可先合，cover 已写明顺序）。

**C. 口径修订建议（给总管，不自行改文件）**

7. 本 lane 已把 **`Mobian-team/mobian-recipes` 的 URL 从 `gitlab.com` 纠正为 `salsa.debian.org`**（§4.2 有 200/404 对照）。
   建议下一轮起 `reports/*` 与派工单统一写 salsa 路径，避免再报「不可达」。
8. **`patchwork` 依旧不可用作判据**（§2.0 原文）。若某轮确实需要 patchwork 摄取旁证，只能走带 JS 的浏览器路径，
   且结论仍须以内容级 grep 为准（`TASKS/UPSTREAM.md` §7 头口径）。
9. **进树判据的已知滞后**：本轮用 `next-20261126`（`a9c48428cbd8`，7.4.0-rc4）。若维护者是在 11-26 白天之后才从自己的树取件，
   `next-20261127` 才是判决点 ⇒ 下一轮请把 `git ls-remote --tags … 'next-20261127*'` 与上面 4 行 grep 一起重跑。

---

## 附：本轮全部命令（只读，可逐条复现）

```bash
# 0) 现场时间
date -u        # 2026-11-27T03:28:39Z

# 1) IMAP（keyring 未锁，readonly + BODY.PEEK）
cp /tmp/d12_scan.py /tmp/d13b_scan.py   # 仅改 CUT -> 2026-11-27T01:10Z + 输出名
timeout -k 5 300 python3 /tmp/d13b_scan.py | tee /tmp/d13b_scan.log
timeout -k 5 200 python3 /tmp/d13b_probe27.py        # SEARCH SINCE "27-Nov-2026" 边界复核

# 2) lore 线程页（4 个 MID）
for mid in 20261126052057.1544590-1 20261125142309.3265777-1 \
           20261126052049.1544229-1 20261124045040.559317-1; do
  curl -sSL -A 'Mozilla/5.0' "https://lore-kernel.gnuweeb.org/all/$mid-xiaqinghuan@mail.ustc.edu.cn/t/" \
    | grep -oE '[0-9]+ messages? in thread|only message in thread|end of thread, other threads:\[[^]]*\]'
done
# 2b) 进树内容级（linux-next = next-20261126 a9c48428cbd8；torvalds master = 7.4.0-rc4）
N=https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain
T=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain
curl -sSL "$N/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts?h=master" -o /dev/null -w '%{http_code}\n'  # 404
curl -sSL "$N/Documentation/devicetree/bindings/arm/qcom.yaml?h=master" | grep -c elden                  # 0
curl -sSL "$N/Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml?h=master" | grep -c mux-controls # 0
curl -sSL "$N/drivers/input/misc/aw86927.c?h=master" | grep -c AW86937                                    # 0
curl -sSL "$N/drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c?h=master" | grep -n PLL_SYSTEM_MUXES              # 417/439 仅两处
git ls-remote --tags https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git 'next-20261126*'

# 3) GitHub（gh 有登录态；匿名 REST 403）
gh pr view 31 --repo linux-msm/hexagonrpc --json state,createdAt,updatedAt,mergeable,mergeStateStatus,commits,reviews,comments,statusCheckRollup
gh api 'repos/linux-msm/hexagonrpc/issues/31/timeline?per_page=100'
gh api 'repos/linux-msm/hexagonrpc/actions/runs?branch=writable-overlay&per_page=10'
gh issue view 21 --repo linux-msm/hexagonrpc --json state,updatedAt,comments
gh api 'repos/linux-msm/hexagonrpc/issues/21/comments' --jq '.[-1]'

# 4) GitLab
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
curl -sS 'https://gitlab.com/api/v4/groups/mobian1/merge_requests?state=opened&per_page=100'
curl -sS 'https://salsa.debian.org/api/v4/projects/Mobian-team%2Fmobian-recipes/merge_requests?state=opened&per_page=100'
curl -sS -w '%{http_code}\n' 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphosh/merge_requests/2005?iids[]=2005'   # 406
```

■ 结束
