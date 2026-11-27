# 通信跟踪 D10-c 增量（窗口 `2026-11-27T03:20Z` → `2026-11-27T12:32Z`）— 只读

> **只读纪律**：本文件是本轮**唯一**写入。未发信、未回信、未推 MR、未改 `TASKS/`、未 `git commit`、未调用 `grow_loop`。
> 增量基线：`reports/comm-triage-20261127-b.md`（收口 `03:29Z`）、`reports/comm-triage-20261127-c.md`（收口 `04:07:17Z`）、`reports/comms-track-20261127.md`（收口 `06:06Z`）。
> **本轮现场时刻**：`2026-11-27T12:26:48Z`（起，`date -u`）→ `2026-11-27T12:32:04Z`（末次核）。窗口 ≈ **9 h 12 min**。
> 每条结论附「命令 + 原始片段」；查不到即写「0 件」并给边界。

---

## §0 数字结论

| 指标 | 值 | 依据 |
|---|---|---|
| **窗口内新人类消息（我方相关）** | **0 封** | IMAP 三箱窗口内 18 行全查（§1.2）：人类 1 封但**无关**（Nicolas Dufresne，libcamera RFC，在 Junk）；lore 4 条在飞线程末封时刻全部早于窗口起点（§2.1） |
| 窗口内新人类消息（无关/校内） | 1 + 1 | `Nicolas Dufresne` 04:06:57Z（Junk，libcamera）；`教务系统 <jw@ustc.edu.cn>` 07:00:58Z（校内通知，非技术） |
| **机器人 M** | **10 条**（+1 校内系统通知单列） | sashiko **1**（11:42:07Z，TNOC 2/2，`[Low]`）；`coresight-bounces` 列表审核通知 **3**；`USTC GitLab` 流水线通知 **6**（§1.3/§1.4） |
| **我方窗口内外发** | **6 封邮件 + 1 条 GitLab note** | 邮件 = 新投两系列共 6 封（`11:31:42–11:32:05Z`）；GitLab = phosh `!2005` 回 guidog **`08:24:39Z`**（均非本 lane 所为，仅记账，§1.6/§4.3） |
| **新投两系列是否成功投递** | coresight-moduletable **已进 lore 但被 coresight@ 列表压审**（3 封审核通知）；tnoc **正常进 lore 并 10 min 内拿到 sashiko 评审** | §1.3 / §2.2 / §2.3 |
| **我方欠动作（窗口内新增）** | **1 项本地可做 + 1 项需放行** | ① TNOC 2/2 补 `Fixes: ebd1eb365cae`（本地可做）；② 重投 v2 / 订阅 coresight@ 属外发，需用户放行（§5） |
| **进树判定（内容级）** | 6 个对象 **全部未进树** | linux-next `next-20261126`（`a9c48428`，HEAD，**无 next-20261127 tag**）+ torvalds `master` 7.4.0-rc4（§3） |
| **GitHub `linux-msm/hexagonrpc`** | PR `#31` 无评审无评论；CI 仍 5/5 `action_required`；**窗口内新增 1 次人类 `subscribed`（`Drakulix` 10:07:45Z）** | §4.1 |
| **GitLab** | `droid-juicer!46` 仍 0 note；salsa `Mobian-team` 32 open / 我方 0；phosh `!2005` 我方回帖已落（`08:24:39Z`），guidog 零回；phoc `!820` merged、`#125` 休眠 | §4.2–4.5 |
| **不可达面（如实记）** | 2 面 | ① `patchwork.kernel.org` Anubis 挑战页（HTTP 200 / 7044 B 非 JSON）；② `gitlab.gnome.org` 匿名 `curl` 406 / 0 B（**认证 `glab api` 可读**）；③ 附带 `gitlab.com …/notes` 匿名 401（§6） |

一句话：**本轮他人对我方在飞系列仍零人类回复；实质新增是「我们自己投了两系列」——tnoc 10 分钟拿到 sashiko 1 条 `[Low]`（缺 Fixes trailer，事实成立），coresight-moduletable 被 `coresight@lists.linaro.org` 的「非成员」审核压住（仍经 Cc 进 lore）；另有 1 位 GitHub 用户 `Drakulix` 订阅了 `PR #31`。**

---

## §1 邮件三箱（INBOX / Junk E-mail / Sent Items）+ 退信

### 1.1 通道与脚本（`BODY.PEEK`，不置 `\Seen`）

```bash
sed 's/2026, 11, 27, 3, 29/2026, 11, 27, 3, 20/; s/d13c/d13d/g' /tmp/d13c_scan.py > /tmp/d13d_scan.py
timeout -k 5 300 python3 /tmp/d13d_scan.py | tee /tmp/d13d_scan.log
```

原始日志（逐字，exit=0）：

```
STATUS INBOX OK "INBOX" (MESSAGES 10470 UIDVALIDITY 1)
SINCE 26-Nov: 47 msgs INBOX
LAST INTERNALDATE in INBOX = 2026-11-27T11:42:07Z | Re: [PATCH 2/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA per
STATUS "Junk E-mail" OK "Junk E-mail" (MESSAGES 234 UIDVALIDITY 5)
SINCE 26-Nov: 20 msgs "Junk E-mail"
LAST INTERNALDATE in "Junk E-mail" = 2026-11-27T04:06:57Z | Re: [RFC] Reproducible IPA module authentication using installed che
STATUS "Sent Items" OK "Sent Items" (MESSAGES 380 UIDVALIDITY 3)
SINCE 26-Nov: 13 msgs "Sent Items"
LAST INTERNALDATE in "Sent Items" = 2026-11-27T11:32:05Z | [PATCH 2/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid
total rows after cut 2026-11-27T03:20:00+00:00: 18
```

**退信面**：`grep -icE 'mailer-daemon|postmaster|undeliver|delivery status' /tmp/d13d_scan.log` → **0** ⇒ 本轮 **0 封 DSN**。

边界复核（`SEARCH SINCE "27-Nov-2026"`，服务器时区 +0800）：

```
INBOX "INBOX" (MESSAGES 10470 UIDVALIDITY 1)      SINCE 27-Nov: 15
Junk "Junk E-mail" (MESSAGES 234 UIDVALIDITY 5)   SINCE 27-Nov: 1
Sent "Sent Items" (MESSAGES 380 UIDVALIDITY 3)    SINCE 27-Nov: 6
```

15 − 12（窗口前 4 件已于上轮核为 `11-26T18:09Z/20:33Z` 类，见上一轮 §1.3；本窗口内 3 件为 `coresight-bounces`×N 与 sashiko）自洽，无「切点算错」迹象。

### 1.2 窗口内 18 行全表（原文摘录；我方件标 `[ours]`）

| 时刻 (UTC) | 箱 | From | Subject | Message-ID |
|---|---|---|---|---|
| 04:06:57 | Junk | Nicolas Dufresne `<nicolas@ndufresne.ca>` | Re: [RFC] Reproducible IPA module authentication using installed checksums | `<a89cd373e489288734c0ad87693a0b2852d30430.camel@ndufresne.ca>` |
| 07:00:58 | INBOX | 教务系统 `<jw@ustc.edu.cn>` | 大学生研究计划审核结果（中期检查） | `<6B092AAA.3F8C69.49362@ustc.edu.cn>` |
| 08:00:11 | INBOX | USTC GitLab `<gitlab@ustc.edu.cn>` | pi-loop-core \| Failed pipeline for main \| 098045fe | `<6b09388b44270_39b3400d03101a3@git.ustc.edu.cn.mail>` |
| 08:00:12 | INBOX | USTC GitLab | pi-loop-core \| Auto DevOps pipeline was disabled | `<6b09388b6720a_39baccb03105e6@git.ustc.edu.cn.mail>` |
| 11:00:08 | INBOX | USTC GitLab | pi-agent-handoff \| Auto DevOps pipeline was disabled | `<6b0962b75cb6c_39b32d3543141f@git.ustc.edu.cn.mail>` |
| 11:00:09 | INBOX | USTC GitLab | pi-agent-handoff \| Failed pipeline for main \| cc5e2d27 | `<6b0962b8450c2_39bacd14314542@git.ustc.edu.cn.mail>` |
| 11:00:11 | INBOX | USTC GitLab | pi-agent-handoff \| Failed pipeline for v0.1.1 \| cc5e2d27 | `<6b0962b860903_39b32c274314768@git.ustc.edu.cn.mail>` |
| 11:00:12 | INBOX | USTC GitLab | pi-agent-handoff \| Failed pipeline for v0.1.0 \| 84e7e79a | `<6b0962b782e2d_39b238ad183143e9@git.ustc.edu.cn.mail>` |
| 11:31:42 | Sent | Qianhui Xu | [ours] `[PATCH 0/2] coresight: add missing MODULE_DEVICE_TABLE() for CTCU and TPDA` | `<20261127113137.931578-1@…>` |
| 11:31:45 | Sent | Qianhui Xu | [ours] `[PATCH 1/2] coresight: ctcu: add missing MODULE_DEVICE_TABLE()` | `<20261127113137.931578-2@…>` |
| 11:31:48 | Sent | Qianhui Xu | [ours] `[PATCH 2/2] coresight: tpda: add missing MODULE_DEVICE_TABLE()` | `<20261127113137.931578-3@…>` |
| 11:32:00 | Sent | Qianhui Xu | [ours] `[PATCH 0/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid` | `<20261127113158.932414-1@…>` |
| 11:32:01 | Sent | Qianhui Xu | [ours] `[PATCH 1/2] dt-bindings: arm: qcom,coresight-tnoc: allow the AMBA periphid` | `<20261127113158.932414-2@…>` |
| 11:32:03 | INBOX | `coresight-bounces@lists.linaro.org` | Your message to coresight@lists.linaro.org awaits moderator approval | `<179577911833.1471.16950301362915367660@lists.linaro.org>` |
| 11:32:04 | INBOX | `coresight-bounces@lists.linaro.org` | （同上） | `<179577911846.1471.8762400476942584092@lists.linaro.org>` |
| 11:32:05 | INBOX | `coresight-bounces@lists.linaro.org` | （同上） | `<179577911718.1471.8650866467135030447@lists.linaro.org>` |
| 11:32:05 | Sent | Qianhui Xu | [ours] `[PATCH 2/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid` | `<20261127113158.932414-3@…>` |
| 11:42:07 | INBOX | `sashiko-bot@kernel.org` | `Re: [PATCH 2/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid` | `<sashiko-outbox-237264@kernel.org>` |

**分类计数**：人类（非我方）**1**（Nicolas Dufresne，无关）；校内系统通知 **1**（教务系统）；机器人/列表自动 **10**（sashiko 1 + coresight-bounces 3 + USTC GitLab 6）；我方出站 **6**。**我方在飞系列的人类回复 = 0 封。**

### 1.3 【新事件 A】coresight-moduletable 系列被 `coresight@lists.linaro.org` 压审（3 封通知原文）

```
$ timeout -k 5 120 python3 /tmp/d13d_body.py INBOX 10467
From: coresight-bounces@lists.linaro.org
Date: Fri, 27 Nov 2026 11:31:58 +0000
Subject: Your message to coresight@lists.linaro.org awaits moderator approval
---正文---
Your mail to 'coresight@lists.linaro.org' with the subject

    [PATCH 2/2] coresight: tpda: add missing MODULE_DEVICE_TABLE()

Is being held until the list moderator can review it for approval.

The message is being held because:

    The message is not from a list member
```

另两封（uid 10468/10469）原文分别对应 `[PATCH 1/2] … ctcu …` 与 `[PATCH 0/2] …`，理由同为
`The message is not from a list member`。⇒ **`coresight@` 的副本被压**（我们不是该列表成员）。
缓解事实：该系列**仍进了 lore**（§2.2，Cc 里 `linux-arm-kernel` / `linux-kernel` 送达），所以归档/评审可达，
但**只按 coresight list-id 过滤的读者（含部分 CIP/patchwork 摄取）看不到**——记账为投递风险，非失败。

### 1.4 【新事件 B】sashiko 对新 tnoc 系列的唯一评审（原文全录）

```
$ timeout -k 5 120 python3 /tmp/d13d_body.py INBOX 10470
From: sashiko-bot@kernel.org
Date: Fri, 27 Nov 2026 11:41:59 +0000
Subject: Re: [PATCH 2/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid
MID: <sashiko-outbox-237264@kernel.org>
To: "Qianhui Xu" <xiaqinghuan@mail.ustc.edu.cn>
Cc: devicetree@vger.kernel.org, robh@kernel.org, conor+dt@kernel.org
------------------------------------------------------------
Thank you for your contribution! Sashiko AI review found 1 potential
issue to consider:
- [Low] arm64: dts: qcom: sm8750: missing Fixes trailer for tn@109ab000
  probe fix
--
...
[Severity: Low]
This fixes probing of the tn@109ab000 node on SM8750.  Should this
include:

  Fixes: ebd1eb365cae ("arm64: qcom: dts: sm8750: add coresight nodes")
```

**事实核验（该建议是否成立）**：

```
$ gh api repos/torvalds/linux/commits/ebd1eb365cae --jq '{date:.commit.author.date,msg:(.commit.message|split("\n")[0])}'
{"date":"2025-11-20T13:48:54Z","msg":"arm64: qcom: dts: sm8750: add coresight nodes"}
$ git -C /tmp/ln grep -n 'tn@109ab000' FETCH_HEAD -- arch/arm64/boot/dts/qcom/sm8750.dtsi
FETCH_HEAD:arch/arm64/boot/dts/qcom/sm8750.dtsi:5175:		tn@109ab000 {
```

⇒ `ebd1eb365cae` 真实存在且正是引入该节点的提交，`tn@109ab000` 在 next 里确在 line 5175 ⇒ **`[Low]` 成立**，
补 `Fixes:` 是纯文本改动（本地可做；重投 = 外发，需放行）。

---

## §2 lore：4 条在飞线程 + 2 个新投系列信封

### 2.1 在飞四线程：**末封时刻与上轮逐字一致，窗口内 0 新封**

```bash
for mid in 20261126052057.1544590-1 20261125142309.3265777-1 20261124045040.559317-1 20261126052049.1544229-1; do
  curl -sSL -A 'Mozilla/5.0' "https://lore-kernel.gnuweeb.org/all/$mid-xiaqinghuan@mail.ustc.edu.cn/t/"
done | grep -oE '[0-9]+ siblings, [0-9]+ replies|only message in thread|other threads:\[[^]]*\]'
```

| 系列（轮次） | 线程页封数（元数据原文） | 末封时刻（`other threads:[ ~… | newest ]`） | 窗口内新封 |
|---|---|---|---|
| elden 板 DTS：任务书写 **v9**，**实况最新 = v10**（v9 已被 v10 取代） | `0 siblings, 2 replies; 4+ messages in thread` | `~2026-11-26  5:30 UTC`（sashiko，v10 2/2） | **0** |
| dwc3 mux **v16** | `0 siblings, 4 replies; 5+ messages in thread` | `~2026-11-25 14:36 UTC`（sashiko "no issues"） | **0** |
| aw86927 **v4** | `0 siblings, 6 replies; 7+ messages in thread` | `~2026-11-24  4:50 UTC`（我方 6/6） | **0** |
| M6 DSI-PHY：任务书写 v2，**实况最新 = v3** | `only message in thread`（1 封，`11-26 05:21`） | 我方唯一封 | **0** |

> 口径说明：任务单写的 elden **v9** / DSI-PHY **v2** 是旧轮次；本项目现行最新为 **v10** / **v3**（`11-26T05:20Z` 投出），
> 两者线程我也逐条比对了封数（4 / 1），与上轮一致，**窗口内无任何新封**。四系列 **人类回复 0、机器人 0**。

### 2.2 新投系列信封 1：`coresight-moduletable`（cover `<20261127113137.931578-1@…>`）

```
$ curl -sSL "https://lore-kernel.gnuweeb.org/all/20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn/t/"
http=200 size=12693
0 siblings, 2 replies; 3+ messages in thread
* [PATCH 0/2] coresight: add missing MODULE_DEVICE_TABLE() for CTCU and TPDA   @ 2026-11-27 11:31 Qianhui Xu
  ` [PATCH 1/2] coresight: ctcu: add missing MODULE_DEVICE_TABLE()          2026-11-27 11:31
  ` [PATCH 2/2] coresight: tpda: add missing MODULE_DEVICE_TABLE()          2026-11-27 11:31
To: suzuki.poulose   Cc: mike.leach, james.clark, leo.yan, alexander.shishkin, coresight,
                    linux-arm-kernel, linux-kernel
```

⇒ **已在 lore，3 封全是我方**，**没有任何回复**（sashiko 到 `12:26Z` 为止未审此系列）。列表压审问题见 §1.3。

### 2.3 新投系列信封 2：`tnoc-periphid`（cover `<20261127113158.932414-1@…>`）

```
$ curl -sSL "https://lore-kernel.gnuweeb.org/all/20261127113158.932414-1-xiaqinghuan@mail.ustc.edu.cn/t/"
http=200 size=16104
0 siblings, 2 replies; 4+ messages in thread
* [PATCH 0/2] … TNOC AMBA periphid   @ 2026-11-27 11:31 Qianhui Xu
  ` [PATCH 1/2] dt-bindings: arm: qcom,coresight-tnoc: allow the AMBA periphid   11:31
  ` [PATCH 2/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid      11:31
   （+ sashiko-bot 2026-11-27 11:41）
To: andersson  Cc: konradybcio, robh, krzk+dt, conor+dt, linux-arm-msm, devicetree, linux-kernel
```

⇒ 4 封 = 我方 3 + **sashiko 1（`11:41`，`[Low]`，§1.4）**；无人类评审。

---

## §3 进树判定（**内容级**，不看 `commit_ref`）

被测树（本轮实测）：

```bash
$ git ls-remote --tags https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git 'next-2026112*' | tail -4
a7e48407c0191a687deda50cf6ae3beb8c06de69  refs/tags/next-20261126
a9c48428cbd8d96b26f92631d0db6f8519c5fcc5  refs/tags/next-20261126^{}
$ git ls-remote https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git HEAD
a9c48428cbd8d96b26f92631d0db6f8519c5fcc5  HEAD          ← 仍 = next-20261126，**next-20261127 tag 尚未产出**
```

> **通道事实（本轮新增，可复用）**：`git.kernel.org` 的 cgit `/plain/` 仍是 Anubis 挑战页
> （`curl … /plain/Makefile?h=master` → `http=200 size=7362` 但正文是 `Making sure you're not a bot!`），
> **但 git 协议可用** ⇒ 本轮改用**部分历史浅克隆**取真实源码做 grep：
> ```
> git init /tmp/ln && git -C /tmp/ln remote add origin https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
> git -C /tmp/ln fetch -q --depth=1 origin refs/tags/next-20261126     # 292 MB，服务端提示 filtering not recognized
> git -C /tmp/ln show FETCH_HEAD:Makefile | head -5                     # VERSION=7 PATCHLEVEL=4 SUBLEVEL=0 -rc4
> ```
> torvalds 侧用 `https://raw.githubusercontent.com/torvalds/linux/master/<path>`（匿名 200）。

| # | 对象 | 内容级标记 | linux-next `next-20261126` | torvalds `master` 7.4-rc4 | 判读 |
|---|---|---|---|---|---|
| 1 | elden DTS v10 | 文件 + `qcom.yaml` 里 `elden` | `git ls-tree -r --name-only FETCH_HEAD \| grep -c sm8750-lenovo-elden.dts` → **0**；`git grep -ci elden … qcom.yaml` → 空（0） | 同 404/0 | **未进树** |
| 2 | dwc3 v16 | `snps,dwc3-common.yaml` 的 `mux-controls` | `git grep -n mux FETCH_HEAD -- …/snps,dwc3-common.yaml` → **0 行** | `mux-controls` → **0** | **未进树** |
| 3 | M6 DSI-PHY v3 | `dsi_7nm_phy_enable()` 体内 `PLL_SYSTEM_MUXES` | `git grep -n PLL_SYSTEM_MUXES … dsi_phy_7nm.c` → **仅 417/439 两处**，函数体为 `dsi_pll_enable_pll_bias/disable` | 同（417/439） | **未进树**（这两处是上游原有） |
| 4 | aw86927 v4 | `AW86937` 枚举/`0x9370` | `git grep -ci aw86937 … aw86927.c` → 空（**0**） | **0** | **未进树** |
| 5 | **coresight-moduletable**（新投） | `coresight-ctcu-core.c` / `coresight-tpda.c` 的 `MODULE_DEVICE_TABLE`（本补丁各 +1 行） | `git grep -c MODULE_DEVICE_TABLE … coresight-ctcu-core.c` → 空（0）；`… coresight-tpda.c` → 空（0） | `curl … \| grep -c` → **0 / 0** | **未进树**（今日 11:31Z 才投，符合预期） |
| 6 | **tnoc-periphid**（新投） | `qcom,coresight-tnoc.yaml` 的 PrimeCell/`unevaluatedProperties`；`sm8750.dtsi` 的 `arm,primecell-periphid` | `git grep -e primecell -e unevaluatedProperties … yaml` → 仅 **25/42/86 行的原有 compatible 字符串**，无 `unevaluatedProperties`；`grep -c primecell-periphid sm8750.dtsi` → **0** | yaml 仍 `additionalProperties: false`（line 65/81），`unevaluatedProperties` **0**；`sm8750.dtsi` periphid **0** | **未进树** |

**口径声明**：判据 = 上面 6 行的 grep 计数 + 文件存在性（内容级），**不使用** patchwork 的 `state`/`commit_ref`。
滞后提示：`next-20261127` 尚未发布（README 记时点 12:30Z），若维护者今天白天取件，判决点要等 `next-20261127`。

---

## §4 GitHub / GitLab / Mobian / phosh

### 4.0 GitHub 通道与真实 repo 确认

```bash
$ gh auth status
github.com
  ✓ Logged in to github.com account xiaquwan1001 (keyring)
$ gh api repos/linux-msm/hexagonrpc --jq '{full_name,open_issues_count}'
{"full_name":"linux-msm/hexagonrpc","open_issues_count":8}     ← repo 名确认真实存在
```

### 4.1 PR `#31`（`linux-msm/hexagonrpc`）— 无评审；**窗口内 1 次人类订阅**

```bash
$ gh pr view 31 --repo linux-msm/hexagonrpc --json state,mergeable,mergeStateStatus,updatedAt,reviews,comments,additions,deletions,changedFiles
{"additions":1279,"changedFiles":17,"comments":[],"deletions":81,"mergeStateStatus":"UNSTABLE",
 "mergeable":"MERGEABLE","number":31,"reviews":[],"state":"OPEN","updatedAt":"2026-11-27T03:09:39Z"}
$ gh api 'repos/linux-msm/hexagonrpc/actions/runs?per_page=8' --jq '.workflow_runs[]|"\(.created_at) | \(.name) | \(.status) | \(.conclusion) | branch=\(.head_branch)"'
2026-11-27T03:09:14Z | Build+test | completed | action_required | branch=writable-overlay
2026-11-27T03:02:53Z | Build+test | completed | action_required | branch=writable-overlay
2026-11-27T02:45:58Z | Build+test | completed | action_required | branch=writable-overlay
2026-11-27T02:28:11Z | Build+test | completed | action_required | branch=writable-overlay
2026-11-27T02:14:43Z | Build+test | completed | action_required | branch=writable-overlay
2026-11-22T21:52:20Z | Build+test | completed | action_required | branch=sdm845-lg-judyln-paths
```

**窗口内新增（唯一他人动作）**：

```bash
$ gh api 'repos/linux-msm/hexagonrpc/issues/31/timeline?per_page=100' --jq '.[]|select(.created_at>"2026-11-27T03:00:00Z")|"\(.created_at) \(.event) \(.actor.login // "-")"'
2026-11-27T03:02:47Z head_ref_force_pushed xiaquwan1001
2026-11-27T03:09:09Z head_ref_force_pushed xiaquwan1001
2026-11-27T10:07:45Z subscribed Drakulix          ← 人类，窗口内新出现
```

判读：`reviews=[]`、`issues/31/comments` 0 条、`pulls/31/comments` 0 条 ⇒ **零评审、零发言**；
`Build+test` 仍 **5/5 `action_required`**（无第 6 次 run，说明无人点批准）；
**`Drakulix` 于 `10:07:45Z` 订阅**该 PR（GitHub `subscribed` 事件，通常是关注者/潜在评审者，**未留任何文字**）⇒ 记为「关注信号」，
按纪律**不主动 ping**。

### 4.2 `gitlab.com/mobian1/droid-juicer` `!46` — 0 note

```
GET /api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46 -> http=200
{'iid': 46, 'state': 'opened', 'detailed_merge_status': 'mergeable', 'user_notes_count': 0,
 'updated_at': '2026-11-23T11:10:29.562Z', 'sha': 'ea9fe3d5c3bb81c246b959c2f0c6ca6ca07c4c4d',
 'draft': False, 'has_conflicts': False} author=xiaquwan1001
```
组内 `mobian1` open = **13**，其中我方仅 `!46`；最新他人 `updated_at` = `2026-10-11T11:43:44Z`（`!45`）。
⇒ **零变化（≈121 h）**，本 lane 不催。

### 4.3 `salsa.debian.org/Mobian-team` — 32 open / 我方 0

```
GET /api/v4/groups/Mobian-team/merge_requests?state=opened&per_page=100 -> http=200  open=32  mine=0
2026-11-26T22:27:13.505Z  Mobian-team/devices/kernels/qcom-linux!61 | tiol | notes=1  ← 最新，早于窗口起点
2026-11-22T09:33:52.088Z  Mobian-team/mobian-recipes!173 | yifei | notes=1
```
⇒ **窗口内 0 更新**（最新仍在 `11-26T22:27Z`，早于 `03:20Z`）。我方在投 **0 件**；`droid-juicer!46` 在 gitlab.com，不在 salsa（口径沿用上轮纠正）。

### 4.4 `gitlab.gnome.org` — **认证通道可用**（匿名 `curl` 仍 406）

```bash
$ curl -sS 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphosh/merge_requests/2005' -o /dev/null -w 'anon http=%{http_code} size=%{size_download}\n'
anon http=406 size=0
$ glab api --hostname gitlab.gnome.org 'projects/World%2FPhosh%2Fphosh/merge_requests/2005'   # 200，JSON
```
⇒ 上一轮「不可达」的成因是**匿名通道**；本轮用 `glab`（keyring token）读通，`phosh !2005` 与 `phoc #125` 均为**现查值**。

**phosh `!2005`（我方 MR）现查**：

```
{'state':'opened','draft':False,'detailed_merge_status':'mergeable','user_notes_count':3,
 'updated_at':'2026-11-27T08:24:39.948Z','sha':'5300355a30f47df5443823a1c6c207adc30d9e39',
 'merge_status':'can_be_merged','has_conflicts':False}
pipeline: manual / Blocked (pipelines/1152598)
```

notes（`sort=desc`，非 system 3 条）：

| 时间 (UTC) | 作者 | 摘录 |
|---|---|---|
| **2026-11-27T08:24:39.881Z** | **`xuqianhui1001`（我方，窗口内）** | "Disclosure first: I use an AI assistant … Your suggestion is in 5300355a (2026-11-24) … CI on 5300355a: 17/19 jobs success, the two left (abi-compliance-checker, unit-test:native-alpinelinux-edge) are manual. … Could you take another look?" |
| 2026-11-24T06:43:26Z | `xuqianhui1001` | "Reworked as suggested: the failed handler now sets the mode to on …" |
| 2026-11-14T13:12:08Z | **`guidog`** | "Thanks for looking into this. Can we continue without AI from here … setting the mode to `enabled` in failed … looks more robust to me" |

⇒ **上轮挂账的「回 guidog」已在 `08:24:39Z` 由别处 lane 落帖**（本 lane 未发任何东西）；**guidog 此后 0 回复**
（最后人类 note 仍是 11-14）⇒ 现状态 = **等我方 → 变 → 等 guidog 再评审**，无需再发。

**phoc**：`!820` = `merged`（`updated_at 2026-10-31T21:22:14Z`，notes 8）；`#125` = `opened`，`user_notes_count=10`，`updated_at=2023-02-17T10:33:53Z`（三年休眠，非我方）⇒ **均无待办**。

---

## §5 我方欠动作清单（区分「需用户放行」/「本地可做」/「非我方动作」）

| # | 事项 | 类别 | 依据 | 备注 |
|---|---|---|---|---|
| 1 | **TNOC 2/2 补 `Fixes: ebd1eb365cae ("arm64: qcom: dts: sm8750: add coresight nodes")`** | **本地可做**（改本地 patch 树 + 台账） | sashiko `[Low]` §1.4，`ebd1eb365cae` 已核实存在 | 只改本地文件不需放行；**重投 v2 属外发 ⇒ 第 2 项** |
| 2 | 重投 TNOC 系列 **v2**（带 Fixes）或回帖说明不做 | **需用户放行**（外发） | `[Low]` 未闭环时易被重复提；本系列 `11:31Z` 投出才 ≈1 h | 建议先本地改好、随下批一起发 |
| 3 | **订阅/申请加入 `coresight@lists.linaro.org`**（避免后续 coresight 系列再被压审；也可请 moderator 放行本次 3 封） | **需用户放行**（外发邮件/账号操作） | §1.3 三封 `not from a list member` | 当前系列已进 lore，非阻塞 |
| 4 | phosh `!2005` 回 guidog | **已完成（非本轮）** | §4.4 `08:24:39Z` note | 此后零回，**不再发** |
| 5 | PR `#31` 的 `Build+test` 审批（5/5 `action_required`） | **非我方动作** | §4.1 | 仅维护者有权限批准；`Drakulix` 订阅 = 关注信号 |
| 6 | `droid-juicer!46` 催审 | **不做** | §4.2 121 h / notes 0 | 队列慢属常态 |
| 7 | aw86927 v4 `ping`/v5 | **触发式：不做**（满 7 天 = 12-01 再议） | §2.1 末封 `11-24T04:50Z`，≈80 h | 连 sashiko 都未审 |
| 8 | elden v10 / dwc3 v16 / dsi-phy v3 | **不做** | §2.1 | 静默 ≈31 h / ≈46 h / ≈31 h，未到门槛 |

---

## §6 不可达面（失败原文，逐字）

| 面 | 命令 | 原始输出 |
|---|---|---|
| `patchwork.kernel.org` API | `curl -sS -A 'Mozilla/5.0' 'https://patchwork.kernel.org/api/1.2/patches/?q=elden&per_page=2'` | `http=200 size=7044`，正文 `<!doctype html>…<title>Making sure you&#39;re not a bot!</title>` ⇒ **非 JSON，不作判据** |
| `git.kernel.org` cgit `/plain` | `curl -sSL -A 'Mozilla/5.0 …' '…/next/linux-next.git/plain/Makefile?h=master'` | `http=200 size=7362`，正文同上 Anubis 挑战页 ⇒ 改走 **git 协议浅克隆**（§3） |
| `gitlab.gnome.org` 匿名 | `curl -sS '…/api/v4/projects/World%2FPhosh%2Fphosh/merge_requests/2005'` | `anon http=406 size=0` ⇒ 认证 `glab api` 可读（§4.4） |
| `gitlab.com …/notes` 匿名 | `curl '…/mobian1%2Fdroid-juicer/merge_requests/46/notes?per_page=100'` | `{"message":"401 Unauthorized"}` `http=401` ⇒ 用对象上 `user_notes_count`（§4.2） |

---

## §7 窗口边界与下轮关注（只读）

1. **边界**：末次 IMAP 核 `12:32:04Z`；`sashiko` 对 **coresight-moduletable** 系列到 `12:26Z` 尚未审（lore 3 封全是我方）——下次扫描应能见到。
2. **`next-20261127` tag 尚未产出**（`HEAD` 仍 `a9c48428`）⇒ 进树判决点顺延；下轮把 §3 的 6 行 grep 重跑即可。
3. **TNOC 的 `[Low]`** 若用户决定「不回、下版带 Fixes」，则与 elden `vin*-supply`、`Acked-by` 台账同批处理。
4. **`Drakulix` 订阅 `#31`**：按纪律不 ping；若 7 天内出现 review 再据实记。

---

## 附：本轮全部命令（只读，可逐条复现）

```bash
date -u                                                                    # 2026-11-27T12:26:48Z
sed 's/2026, 11, 27, 3, 29/2026, 11, 27, 3, 20/; s/d13c/d13d/g' /tmp/d13c_scan.py > /tmp/d13d_scan.py
timeout -k 5 300 python3 /tmp/d13d_scan.py | tee /tmp/d13d_scan.log        # 18 rows
timeout -k 5 200 python3 /tmp/d13d_probe.py                                # SEARCH SINCE 27-Nov 边界
grep -icE 'mailer-daemon|postmaster|undeliver|delivery status' /tmp/d13d_scan.log   # 0
timeout -k 5 120 python3 /tmp/d13d_body.py INBOX 10467                     # 列表压审原文
timeout -k 5 120 python3 /tmp/d13d_body.py INBOX 10470                     # sashiko [Low] 原文

# lore 线程（4 在飞 + 2 新投）
for mid in 20261126052057.1544590-1 20261125142309.3265777-1 20261124045040.559317-1 \
           20261126052049.1544229-1 20261127113137.931578-1 20261127113158.932414-1; do
  curl -sSL -A 'Mozilla/5.0' "https://lore-kernel.gnuweeb.org/all/$mid-xiaqinghuan@mail.ustc.edu.cn/t/" \
   | grep -oE '[0-9]+ siblings, [0-9]+ replies|only message in thread|other threads:\[[^]]*\]'
done

# 进树（内容级）：linux-next 浅克隆 + raw.githubusercontent(torvalds)
git init /tmp/ln && git -C /tmp/ln remote add origin https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
git -C /tmp/ln fetch -q --depth=1 origin refs/tags/next-20261126
git -C /tmp/ln ls-tree -r --name-only FETCH_HEAD | grep -c sm8750-lenovo-elden.dts          # 0
git -C /tmp/ln grep -ci elden FETCH_HEAD -- Documentation/devicetree/bindings/arm/qcom.yaml # 0
git -C /tmp/ln grep -n mux-controls FETCH_HEAD -- Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml  # 0
git -C /tmp/ln grep -n PLL_SYSTEM_MUXES FETCH_HEAD -- drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c               # 417/439 only
git -C /tmp/ln grep -ci aw86937 FETCH_HEAD -- drivers/input/misc/aw86927.c                   # 0
git -C /tmp/ln grep -c MODULE_DEVICE_TABLE FETCH_HEAD -- drivers/hwtracing/coresight/coresight-ctcu-core.c    # 0
git -C /tmp/ln grep -c MODULE_DEVICE_TABLE FETCH_HEAD -- drivers/hwtracing/coresight/coresight-tpda.c        # 0
git -C /tmp/ln grep -n -e primecell -e unevaluatedProperties FETCH_HEAD -- Documentation/devicetree/bindings/arm/qcom,coresight-tnoc.yaml
git -C /tmp/ln grep -c primecell-periphid FETCH_HEAD -- arch/arm64/boot/dts/qcom/sm8750.dtsi # 0
curl -sS https://raw.githubusercontent.com/torvalds/linux/master/Documentation/devicetree/bindings/arm/qcom,coresight-tnoc.yaml | grep -c unevaluatedProperties

# GitHub
gh pr view 31 --repo linux-msm/hexagonrpc --json state,mergeable,mergeStateStatus,reviews,comments,updatedAt
gh api 'repos/linux-msm/hexagonrpc/issues/31/timeline?per_page=100' --jq '.[]|select(.created_at>"2026-11-27T03:00:00Z")|"\(.created_at) \(.event) \(.actor.login)"'
gh api 'repos/linux-msm/hexagonrpc/actions/runs?per_page=8'
gh api repos/torvalds/linux/commits/ebd1eb365cae

# GitLab
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
curl -sS 'https://gitlab.com/api/v4/groups/mobian1/merge_requests?state=opened&per_page=100'
curl -sS 'https://salsa.debian.org/api/v4/groups/Mobian-team/merge_requests?state=opened&per_page=100'
glab api --hostname gitlab.gnome.org 'projects/World%2FPhosh%2Fphosh/merge_requests/2005'
glab api --hostname gitlab.gnome.org 'projects/World%2FPhosh%2Fphosh/merge_requests/2005/notes?per_page=100'
glab api --hostname gitlab.gnome.org 'projects/World%2FPhosh%2Fphoc/issues/125'
glab api --hostname gitlab.gnome.org 'merge_requests?scope=created_by_me&state=all&per_page=50'
```

■ 结束
