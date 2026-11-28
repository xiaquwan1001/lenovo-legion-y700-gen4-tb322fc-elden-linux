# D10 通信跟踪（只读增量快照 `-c`）— outlook/himalaya 首扫 + USTC 复核 + 用户态现查

> **只读纪律**：本文件是本轮**唯一**写入。**未发信、未回帖、未推 MR、未 `git commit`/`git push`、未改任何既有文件**。
> 两套邮箱全部 **只读**：himalaya `message read`（官方语义「The read leaves the flags of the message alone, unless `--seen` is given」，本 lane **从未加 `--seen`**）；USTC 侧 `read-mail-ustc.py` 用 `BODY.PEEK[HEADER.FIELDS …]`。
> **现场时刻**：`date -u` 起点 **`2026-11-28T04:22:29Z`** → 末次两套邮箱复扫 **`2026-11-28T04:34:21Z`**（此后无新信）→ 落盘 ≈`04:4xZ`。本地时区 `Asia/Shanghai`（**CST = UTC+8**，`timedatectl` 直读）。
> **增量基线**：`reports/comms-track-20261128-b.md`（收口 `02:18Z`，本轮从该切点续）→ `reports/comms-track-20261128.md`（`11-27T22:17Z`）→ `reports/comms-track-20261127-b.md`；`TASKS/dim/D10.md`；`patches/upstream/v4l2-compliance-iris-20261127/SENT.md`；`TASKS/UPSTREAM.md` §7（M3-DTS/M6/M8/M10/M11/M12 行）。
> **判据（沿用）**：只认**人类可读的回信**；`sashiko-bot` / `patchwork` / `media-ci` / `npm` / Firecrawl 之类只记「有无状态变化」；我方自己的发件不计回复。
> **两个入口都活着**（与 `-b` 一致，`-20261128` 主段记的 keyring 锁问题已不再复现）：USTC IMAP 与 outlook IMAP（himalaya + XOAUTH2 `ortie token`）本轮均**一次通过**。

---

## §0 数字结论

| 指标 | 值 | 依据 |
|---|---|---|
| **outlook 三箱（inbox/junk/sent）自 2026-11-20 起的信** | **39 封**（inbox 36 / junk 1 / sent 2） | §1.2–§1.3，逐封 `envelope list` 原文 |
| **其中人类手写信** | **2 封** | ① `4737` Akinola `2026-11-24T04:50:12Z`（inbox，**冷启动营销**）② `157` NiubiStar `2026-11-25T02:49:18Z`（**已在 junk**，营销代理） |
| 其中「**问能否参与/合作/用你的项目/贡献**」 | **1 封（唯一一封）** | `4737`；`157` 是**卖服务**（要项目链接 + 发布窗口），不是参与请求 —— §1.5 |
| 其中我方自发（非第三方） | **2 封** | `4808` 用户当天验通道的 SMTP 自测 `04:03Z`；`80` 用户给 `salsa-admin@debian.org` 的账号注册申诉 `2026-11-28T03:13:43Z` |
| **USTC 三箱在 `02:18Z` 之后的新人类回信** | **0 封** | INBOX 天花板 `10491` = Microsoft 账户通知 `2026-11-28T04:00:30Z`（机器人）；Junk 天花板 `11-27T04:06:32Z`（Nicolas Dufresne，libcamera）；Sent 天花板 `[400]` = **我方** iris v3 `02:36:28Z` |
| 11-23..11-25 USTC 侧「问能否参与/合作」人类信 | **0 封** | 关键词全库扫描 0 命中；窗口内非列表发件人仅 8 封且全为内核列表争论/退信/测试信 —— §1.5 |
| **在飞内核系列逐条复核** | **9 条，全部 0 人类回复** | elden v10 / dwc3 v16 / mdss v5 / fastrpc v3 / pstore / aw86927 v4 / coresight v2 / TNOC / iris colorspace v3 —— §3.1 |
| 其中本轮**状态变化**（非人类） | **2 条** | ① iris colorspace **v3 已实发**（`02:36:28Z`，lore 线程 7 封，末封 = 该 v3）② `10490` media-ci 对我方 v2 的 mandatory checkpatch 判红（`01:27:06Z`，早于 `-b` 已记，本轮只复核） |
| **T24 coresight moderator 自证** | **未触发**（判据仍未满足） | 自 `13:54:54Z` 订阅确认后我方**未再向 `coresight@` 发过任何一封**，故「下一封不再出现 awaits moderator approval」这个判据**没有机会触发**；INBOX 自 `13:54Z` 起 0 封 moderator 通知 —— §3.1 |
| **用户态上游 5 个对象** | **维护者回复 0** | gmobile `!131` notes 0；phoc `#125` 我方 note 后 0 回；phosh `!2005` guidog 0 回；Mobian `droid-juicer !46` notes 0（≈113.5 h）；droidloom `#65/#69/#48` 维护者全 0 —— §3.2 |
| 其中**唯一变化** | **`droidloom #65` comments 0 → 2** | 两条**都是我方**（`02:51:40Z` / `03:41:27Z`，`-b` 之后新增）—— §3.2 |
| 退信/DSN | **5 封，全部在 USTC Junk，且是 11-24 的 Google 死地址退信（前序已记账）** | `[190][191][192][193][200]` `mailer-daemon@googlemail.com`；outlook 三箱 0 封 DSN |
| **阻塞** | **0** | 两套 IMAP、`glab`(GNOME)、`gh` 本轮全部一次通过（`gh` 仍需 `env -u *_proxy`） |
| **需用户放行** | **3 项** | ① 给 Akinola 回不回（建议不回，草稿已备）② outlook `4737` 是否标 junk（改邮箱状态）③ iris v3 之后是否要追加任何动作（本轮无）—— §4 |

**一句话**：outlook 通道**首扫干净** —— 自 11-20 起 39 封信里只有 **1 封人类冷启动推销**（Akinola，11-24），**不是**招募、**不是**「能不能参与项目」、**没有任何报价/交付物/时间表**，是典型模板群发，**建议忽略**（§2）；另一个营销件（NiubiStar）已被自动判进 Junk。USTC 侧自 `02:18Z` **零新人类回信**，9 条在飞系列**全部仍在静默**，唯一实质变化是 **iris colorspace v3 已于 `02:36:28Z` 实发并归档**（线程 7 封）。用户态 5 个对象**维护者零回复**，`droidloom #65` 的两条新评论**都是我们自己**。

---

## §1 通道状态（含 himalaya outlook 首扫与 alias 缺陷）

### 1.1 outlook 通道（用户 2026-11-28 新部署，本 lane 首次使用）

```bash
himalaya --version
#  himalaya v3.0.0 +gmail +imap +jmap +maildir +mbox +msgraph +pimdir +rustls-ring +sieve +smtp
#  build: linux musl x86_64  git: nix-flake-20261126162934, rev 24f28e0f0a98d646cc72f68680891e8e1aa5ff29
himalaya mailbox list --account outlook
#  Drafts  drafts  Drafts / 存档 - 存档 / Outbox - Outbox / Junk junk Junk
#  Inbox   inbox   Inbox  / Sent  sent  Sent  / Deleted trash Deleted / Notes - Notes
```

**⚠ 配置缺陷（记一行，属用户环境，本 lane 未改）**

| 项 | 事实 |
|---|---|
| 缺陷 | `~/.config/himalaya/config.toml` 写 `mailbox.alias.sent = "Sent Items"`，而**本账号实际文件夹名是 `Sent`** |
| 复现 | `himalaya envelope list --account outlook --mailbox sent` → `Error: IMAP mailbox 'Sent Items' not found` / `IMAP SELECT failed: NO "Sent Items" doesn't exist.` |
| 为什么三种写法都失败 | himalaya 对 `-m` 取值先做**大小写不敏感 alias 匹配**：`sent` / `Sent` / `SENT` / 字面 `Sent Items` **全部**被解析成那个不存在的 `Sent Items` |
| **正确用法（本 lane 采用，零改动用户配置）** | 写一个只覆盖该别名的临时 TOML，再 `-c` **叠加**到用户配置上：<br>`printf '[accounts.outlook]\nmailbox.alias.sent = "Sent"\n' > /tmp/himalaya-outlook-override.toml`<br>`himalaya envelope list --account outlook --mailbox sent \`<br>`  -c ~/.config/himalaya/config.toml -c /tmp/himalaya-outlook-override.toml` |
| 已验证 | 叠加后 `Mailbox: Sent`，`Page: 1, envelopes 1 to 17, the last`（17 封，末封 = 我方 SMTP 自测 `04:03Z`） |
| 仓库里已有等价实现 | `scripts/read-mail-outlook.sh`（**untracked，非本 lane 所建**）用 `sed` 把用户配置改到临时文件再 `-c` 传入，注释里记的正是这条坑；持久修法 = 用户自己把 config 的 `"Sent Items"` 改成 `"Sent"`（或直接用该脚本） |

**通道健康**：IMAP `imaps://outlook.office365.com:993` + XOAUTH2（token 命令 `ortie token show -a microsoft-imap-smtp`）本轮每次都在毫秒级返回；**不需要**账号口令，全程未落盘任何凭据。

### 1.2 outlook `inbox` 逐封分类（自 2026-11-20 起，**36 封**）

分类：**H** = 人类手写；**R** = 机器/自动通知（含 `Eric at Firecrawl` 这种「人署名但机器发」的用量告警）；**S** = 我方自发。时间 = 本地 `envelope list` 值 −8 h 得 UTC。

```bash
himalaya envelope list --account outlook --mailbox inbox --page-size 50 --page 1 -c … -c /tmp/himalaya-outlook-override.toml
#  Page: 1, envelopes 1 to 50 ;  Next page: --page 2   （第 2 页起已全早于 11-20）
```

| msg | UTC | 发件人 | 主题 | 类 |
|---|---|---|---|---|
| 4808 | 2026-11-28T04:03Z | Qianhui Xu | himalaya SMTP test @ 2026-11-28 12:03:06 | **S** |
| 4805 | 2026-11-28T04:00Z | Microsoft 帐户团队 | 连接到 Microsoft 帐户的新应用 | R |
| 4802 | 2026-11-28T02:52Z | Cloudflare | In Vegas December 1-3? Join Cloudflare's Region: Earth | R（营销） |
| 4799 | 2026-11-28T02:37Z | ChatGPT | 有 4 种新图像风格等你尝试 | R |
| 4797 | 2026-11-28T02:20Z | npm | published pi-loop-core@0.1.5 | R |
| 4795 | 2026-11-28T02:18Z | npm | published pi-loop-core@0.1.4 | R |
| 4793 | 2026-11-27T12:32Z | npm | published pi-model-speed@0.7.0 | R |
| 4789 | 2026-11-27T10:00Z | npm | published pi-agent-handoff@0.1.1 | R |
| 4787 | 2026-11-27T09:30Z | npm | published pi-agent-handoff@0.1.0 | R |
| 4785 | 2026-11-27T06:03Z | npm | published pi-loop-core@0.1.3 | R |
| 4783 | 2026-11-27T05:51Z | npm | published pi-loop-core@0.1.2 | R |
| 4781 | 2026-11-27T05:43Z | npm | published pi-loop-core@0.1.1 | R |
| 4779 | 2026-11-27T05:25Z | npm | published pi-loop-core@0.1.0 | R |
| 4774 | 2026-11-26T11:44Z | Brave Search API | usage threshold alert | R |
| 4769 | 2026-11-26T06:26Z | Firecrawl | included credits used | R |
| 4766 | 2026-11-26T06:03Z | Eric at Firecrawl | 95% of credits | R |
| 4763 | 2026-11-26T06:10Z | Eric at Firecrawl | 90% of credits | R |
| 4759 | 2026-11-25T07:51Z | Eric at Firecrawl | 80% of credits | R |
| 4755 | 2026-11-25T02:46Z | npm | published pi-fabric-resume@0.1.2 | R |
| 4753 | 2026-11-25T02:41Z | npm | published pi-fabric-hardening@0.2.1 | R |
| 4751 | 2026-11-25T02:40Z | npm | published pi-fabric-agent-echo@0.1.2 | R |
| 4749 | 2026-11-25T02:36Z | npm | published pi-model-speed@0.6.0 | R |
| 4746 | 2026-11-25T02:29Z | Eric at Firecrawl | 70% of credits | R |
| 4743 | 2026-11-24T14:20Z | Eric at Firecrawl | 50% of credits | R |
| 4739 | 2026-11-24T09:37Z | Discord | Discord 政策更新 | R |
| **4737** | **2026-11-24T04:50:12Z** | **Emmanuel Akinola `<emmanuelakinola260@gmail.com>`** | **Your repo, and the people who never found it** | **H**（§2 精读） |
| 4649 | 2026-11-23T01:49Z | GNOME Discourse | [GNOME Discourse] Summary | R |
| 4643 | 2026-11-21T09:16Z | GitLab | A new personal access token has been created | R |
| 4640 | 2026-11-21T07:42Z | GitLab | gitlab.com sign-in from new location | R |
| 4638 | 2026-11-21T03:27Z | npm | published pi-fabric-resume@0.1.1 | R |
| 4636 | 2026-11-21T03:22Z | npm | published pi-fabric-agent-echo@0.1.1 | R |
| 4634 | 2026-11-21T03:21Z | npm | published pi-model-speed@0.3.0 | R |
| 4632 | 2026-11-21T03:21Z | npm | published pi-fabric-hardening@0.2.0 | R |
| 4630 | 2026-11-21T03:20Z | npm | published pi-fabric-resume@0.1.0 | R |
| 4625 | 2026-11-20T15:13Z | Firecrawl | credits have reset | R |
| 4621 | **2026-11-19T22:21Z** | Cloudflare | Welcome to Cloudflare | R |

> `4621` 的 UTC 落在 11-19 晚间，只因本地日期是 11-20 06:21 CST 才被切进来；一并列出以免下轮误判「漏扫」。
> **inbox 自 11-20 起人类信合计 = 1 封（4737）**。

### 1.3 outlook `junk` / `sent` / 其它箱

```bash
himalaya envelope list --account outlook --mailbox junk  …  # Page: 1, envelopes 1 to 5, the last
himalaya envelope list --account outlook --mailbox sent  -c … -c /tmp/himalaya-outlook-override.toml
#  Page: 1, envelopes 1 to 17, the last
```

| 箱 | 自 11-20 起 | 内容 |
|---|---|---|
| **Junk** | **1 封** | `157` `2026-11-25T02:49:18Z` **NiubiStar Support Team `<market@mcpcnserver.com>`**（`Reply-To: 3673409676@qq.com`，`List-Unsubscribe: …/unsubscribe?…`）"Developer marketing plan for open-source projects" —— **营销代理**，要「project link + launch window」，明写「we can suggest a practical plan before any payment」。**已在 Junk，无需动作**（原文直读，非「问能否参与」）。其余 4 封（156 `11-17`、129/128/127 `10 月`）在窗口外 |
| **Sent** | **2 封** | `4808/85` SMTP 自测 `2026-11-28T04:03Z`（用户验通道）；`80` **`2026-11-28T03:13:43Z` → `salsa-admin@debian.org`**，主题 "asking for account registry approval"，正文一行：`my mail address is xuqianhui1001@outlook.com,and username xuqianhui` —— **用户/他 lane 发的账号申诉，不是本 lane 所为**，仅记账；**至收口无回信**（inbox/sent 均无后续）。其余 15 封全为 10 月（GitLab 注册、列表订阅、回归报告） |
| **存档 / Deleted / Outbox / Notes** | **0 / 1 / 0 / 0** | 存档与 Outbox 空；Deleted 只有 1 封 `10-12` 的旧草稿；Notes 空 ⇒ **outlook「全箱」无遗漏的人类冷启动信** |

**别名/全箱核查**：`from:emmanuelakinola260@gmail.com` 在 **inbox / junk / sent / 存档 / Deleted / Outbox / Notes 七个箱全部搜过**，仅 inbox 命中 1 封 ⇒ **Akinola 只发过这一封，我方从未回复过**（sent 0 命中）。

### 1.4 USTC 三箱（`read-mail-ustc.py`，两遍）

```bash
timeout -k 5 180 /home/xuqianhui/.local/bin/read-mail-ustc.py --days 8 --limit 3000   # rc=0, 4.7 s
=== INBOX : 1985 封（SINCE 20-Nov-2026）===
=== "Junk E-mail" : 123 封（SINCE 20-Nov-2026）===
=== "Sent Items" : 83 封（SINCE 20-Nov-2026）===
```
（第一次用 `--limit 800` 只打末尾 800 行，会**丢** 11-20..11-23 上午的段；本报告用 `--limit 3000` 的**全量** 2194 行，`/tmp/ustc-8d-full.txt`。）

| 箱 | 封数 | **天花板（UTC）** | 判读 |
|---|---|---|---|
| INBOX | 1985 | `10491` `2026-11-28T04:00:30Z` = `Microsoft 帐户团队`（**机器人**） | 通道活；`02:18Z` 之后**只有这 1 封，且是机器人** ⇒ 新人类回信 **0** |
| Junk E-mail | 123 | `[234]` `2026-11-27T04:06:32Z` = Nicolas Dufresne（libcamera RFC） | 全是列表信（libcamera 被 Coremail 判 spam）；`02:18Z` 后 0 封 |
| Sent Items | 83 | `[400]` `2026-11-28T02:36:28Z` = **我方** `[PATCH v3] media: iris: fill in a default colorspace…` | 我方副本齐；`02:18Z` 后**只有这一封（v3 实发）** |

- **DSN/退信面**：outlook 三箱 **0 封**；USTC **5 封**，全部在 Junk 且是 `2026-11-24T15:15/18:23Z` 的 `mailer-daemon@googlemail.com`（= 前序已记账的 `dmitry.baryshkov@linaro.org` / `srinivas.kandagatla@linaro.org` 死地址事故），**本轮无新退信**。
- **列表审核面**：`grep -iE 'awaits moderator|postorius|confirmation is needed|email commands'` 命中 12 行，最后一条 = `10480` `2026-11-27T13:54:54Z`（postorius 邮件地址确认）⇒ `13:54Z` 之后 **0 封 moderator 通知**（T24 判据见 §3.1）。

### 1.5 「问能否参与/合作/用你的项目/贡献」专项扫描（11-23 → 11-25）

```bash
# (a) outlook：三箱 + 存档/Deleted/Outbox/Notes 全部逐封看过（§1.2/§1.3 的表就是全量）
# (b) USTC：全量 2194 行关键词扫描
grep -inE 'contribut|collaborat|your project|partnership|sponsor|recruit|hiring|internship|cooperat|outreach|marketing|promot|seo |freelance' /tmp/ustc-8d-full.txt
#  → 0 命中
awk 'NR>=2 && NR<=1986' /tmp/ustc-8d-full.txt | grep -E '(2[345]) Nov 2026' \
  | grep -viE 'xiaqinghuan|gitlab@ustc|jw@ustc|\[PATCH|Re: \[|RFC|sashiko|patchwork|media-ci|linuxtv|bounces|postorius|mailer-daemon|kernel test robot|lkp@intel|linux-next'
#  → 8 行，逐条核过，全部不是冷启动：
#    [9478] 23 Nov 15:11+0800 Xuyang Dong      Re: clk: eswin: eic7700 …（他人列表争论）
#    [10135] 24 Nov 12:41Z  Pinkesh Vaghela    Re: clk: eswin …（同上）
#    [10142] 24 Nov 13:08Z  Felix Plamper      [REGRESSION] HID logitech-hidpp（列表 bug 报告）
#    [10154] 24 Nov 13:28Z  Stefan Ghetu       [RESEND PATCH v3] clk: imx（列表补丁）
#    [10280] 24 Nov 16:17Z  Mathieu Poirier    [UPDATE] Patch review update（列表月报）
#    [10345] 24 Nov 17:29Z  Geert Uytterhoeven [GIT PULL] clk: renesas（列表 pull）
#    [10418] 25 Nov 14:19Z  postmaster@ustc     系统退信
#    [10431] 25 Nov 20:49Z  Robert Mader       Test mail, please ignore
```

**结论（带 msg id）**：11-23..11-25 窗口内，「问能否参与/合作/用你的项目/贡献」性质的人类信 **只有 `outlook#4737` 一封**（Emmanuel Akinola）。它不是参与请求（详见 §2）。
同一窗口内还有一封**卖服务的营销信** `outlook junk#157`（NiubiStar，`2026-11-25T02:49:18Z`），性质是「我们帮你做发布/分发，先给项目链接和发布窗口」——**不是**「我想加入/贡献」，且**已被判进 Junk**，本轮不建议任何动作。
USTC 侧（发件人 `xiaqinghuan@mail.ustc.edu.cn`）窗口内 **0 封**此类信。

---

## §2 `outlook #4737` 精读：Emmanuel Akinola（**不发送任何回信**）

```bash
himalaya message read 4737 --account outlook --mailbox inbox --raw \
  -c ~/.config/himalaya/config.toml -c /tmp/himalaya-outlook-override.toml > /tmp/akinola-4737.eml   # rc=0, 15 613 B
```
（`--raw` 取原始 RFC 5322；**未加 `--seen`** ⇒ 该信的 `\Seen` 状态未被我改。）

### 2.1 报文事实（逐字）

| 头 | 值 |
|---|---|
| `Date` | **`Tue, 24 Nov 2026 05:50:12 +0100` = `2026-11-24T04:50:12Z`**（= 本地 `12:50 CST`）。**注意**：派工单写的「05:50Z」是**发件人 +0100 本地时间**，UTC 是 **04:50:12Z**；与 outlook `Received` 链首跳 `Mon, 23 Nov 2026 20:50:25 -0800` 交叉一致 |
| `From` | `Emmanuel Akinola <emmanuelakinola260@gmail.com>` |
| `Return-Path` | `emmanuelakinola260@gmail.com`（**与 From 同址**；**无 `Reply-To`**） |
| `To` | `xuqianhui1001@outlook.com`（**单收件人，无 Cc/Bcc 痕迹**） |
| `Subject` | `Your repo, and the people who never found it` |
| `Message-ID` | `<CAD74fks4Yq+foVxgzwk4Q=wM3bYNwUkF_Xq9uj1izGFA6CPJGQ@mail.gmail.com>` |
| 结构 | `multipart/alternative`：`text/plain` **1 081 B** + `text/html` **1 207 B**（HTML 部分已读，全文见 2.2） |
| 反垃圾 | `X-MS-Exchange-Organization-SCL: 1`（低分，**未被 outlook 判垃圾**）、`dmarc=pass`、`spf=pass` |
| 缺失 | **无** `List-Unsubscribe`、**无** `List-Id`、**无** 任何 `https://` 链接、**无** `<img>`/追踪像素（`grep -icE '<img\|tracking\|utm_'` = **0**） |

### 2.2 正文（`text/plain` 逐字；HTML 部分为同一段落的单 `<div dir="auto">` 转换，内容一字不差）

```
Hi xiaquwan1001,

I will be honest with you, xiaquwan1001, I almost did not send this. But
"xiaquwan1001/lenovo-legion-y700-gen4-tb322fc-elden-linux" is too good to
stay quiet about. I also noticed you have been committing recently, which
matters more than people think, active projects are far easier to get
traction for than dormant ones.

What I have seen work, over and over, is steady targeted exposure rather
than one viral moment. A handful of the right communities, introduced to
your project the right way, spread across a few weeks instead of one burst.
Slower, but the people who arrive actually stay and use it.

What I do is straightforward. I audit how the project presents itself,
sharpen the positioning so the value is immediately clear, identify the
specific communities and newsletters where your users already are, and run
consistent outreach there over several weeks rather than in one burst.

A short reply is all I need to start putting something together for
"xiaquwan1001/lenovo-legion-y700-gen4-tb322fc-elden-linux".

Best,
Akinola
```

### 2.3 判定（逐项回答派工单的问题）

| 问题 | 结论 | 证据 |
|---|---|---|
| **性质** | **推广/营销外包（冷启动私信）** —— 不是招聘、不是技术合作邀约、不是「问能否参与项目」 | 全文自我定义：`I audit how the project presents itself, sharpen the positioning … identify the specific communities and newsletters where your users already are, and run consistent outreach there over several weeks` |
| **明确要我们做什么** | **只要求「回一句」**：`A short reply is all I need to start putting something together` ⇒ 目的 = 拿到回信、进入他的销售流程 | 同上句 |
| **是否属于「问能否参与项目」** | **否**。全信**没有一句**是「我想加入/我想贡献/我能不能帮你们写驱动」；主语始终是「我帮你做曝光」，客体是仓库的**呈现方式与传播**，不是代码 | 全文；且**通篇零技术内容**（未提 SM8750 / Y700 / DRM / 上游内核 / 任何驱动名） |
| **有无具体报价** | **无**。零价格、零费率、零套餐 | 全文无数字金额 |
| **有无交付物** | **只有动词级描述**（audit / sharpen positioning / identify communities / run outreach），**无任何可验收物**（没有文章数、渠道清单、placement 名单、报表样例） | 同上 |
| **有无时间表** | **只有「several weeks」**，无起止、无里程碑 | `over several weeks rather than in one burst` |
| **是不是模板群发** | **强证据指向模板 + 槽位填充**（见下 5 条） | ① 仓库全名 `"xiaquwan1001/lenovo-legion-y700-gen4-tb322fc-elden-linux"` **带引号原样插入两次**（典型变量替换）；② 称呼直接拿 **GitHub 账号名** `xiaquwan1001` 当人名，且同一段里重复两次（`Hi xiaquwan1001,` + `I will be honest with you, xiaquwan1001,`）；③ 「内容」全是与具体项目无关的通用话术（`steady targeted exposure rather than one viral moment`），**换任何仓库都成立**；④ 签名只有 `Best, Akinola` —— **无公司、无网站、无电话、无 LinkedIn、无退订方式**，与 NiubiStar（有 `List-Unsubscribe` + 官网 + 退订 token）形成对照；⑤ HTML 是 Gmail 单 `<div dir="auto">` 纯文本行转换，无追踪像素无 CTA ⇒ 「抓 GitHub 最近有 push 的仓库 → 套模板 → 逐个私信」的流水线 |
| 发件人可信度旁证 | 免费 gmail、地址带 `260` 后缀（一次性/新注册观感）、本地时区 `+0100`（西非/中欧一带）；**无退订机制**意味着一旦回信就只能靠他自己停 | 头部；对照 §1.3 的 NiubiStar |
| 他确实看过仓库吗 | **只看了元数据**：仓库 slug 真实存在（`gh api` 现查：`created_at 2026-10-10T15:45:46Z`、`pushed_at 2026-11-28T04:10:42Z`、`stargazers_count 4`），他说的「you have been committing recently」对得上；但**没有任何内容级细节** ⇒ 是 GitHub API/网页列表层面的抓取 | `env -u https_proxy … gh api repos/xiaquwan1001/lenovo-legion-y700-gen4-tb322fc-elden-linux --jq '{full_name,pushed_at,stargazers_count}'` |

### 2.4 处置建议

**建议：忽略（不回）。次选：忽略 + 标 junk。**

理由（按权重）：
1. **回复即进入销售漏斗**：他唯一诉求就是「一句话回信」，而信里**没有报价、没有交付物、没有时间表**；先回再看价，等于把时间花在对方定价上。
2. **无退订机制**：没有 `List-Unsubscribe`，回一句「不需要」通常换来 2–3 轮跟进，成本比忽略高。
3. **对本项目的收益路径本来就不在这里**：项目当前的真实牵引是上游内核维护者（本轮 `Dmitry Baryshkov` / `James Clark` / `Bryan O'Donoghue` 三条线程）与真机用户复现；**4 个 star** 的仓库做付费曝光，投入产出无法论证（也没有他给的任何数据支撑）。
4. 唯一「值得回」的情形 = 用户**真想买增长服务**：那也不该在这封信上谈，应先要到书面报价 + 交付物样例 + 过往案例链接，再比价 —— **本轮不建议主动走这一步**。
5. **不要做的**：不要点开/回复索要「案例」，不要给仓库写权限（他主动说不需要 token，但模板信里这类话不可作为承诺）。

### 2.5 英文草稿（**仅供备查，未发送、也不在本轮放行范围**，7 行）

```
Hi Akinola,

Thanks for the note, but I'm not in the market for marketing help. This project
grows through the upstream kernel maintainers who review the patches and the
people who actually run the port on the device, and I'd rather keep that organic.
Please don't follow up.

Best regards,
Qianhui
```

> 若最终决定「彻底闭环」而不只是忽略，另一条更省事的路是**不回信、直接把 `4737` 标为 Junk**（改邮箱状态，非外发）—— 见 §4 第 2 项。

---

## §3 上游状态

### 3.1 在飞内核系列（逐条，现查 `04:3xZ`）

**方法**：lore 线程 `t.mbox.gz`（**默认 curl UA**；浏览器 UA 会吃 Anubis 假页）逐封打 `Date/From/Subject`：
```bash
python3 /tmp/d10-lore.py <cover-MID>      # GET https://lore.kernel.org/all/<MID>/t.mbox.gz
```

| 系列 | cover MID | 线程封数 | 末封（UTC） | 末封作者 | 人类回复 | 静默 |
|---|---|---|---|---|---|---|
| elden DTS **v10** | `20261126052057.1544590-1-…` | **4** | `2026-11-26T05:30:05Z` | sashiko-bot（v10 2/2） | **0** | ≈47.2 h |
| dwc3 **v16** | `20261125142309.3265777-1-…` | **5** | `2026-11-25T14:36:13Z` | sashiko-bot（"found no issues"） | **0** | ≈62.1 h |
| mdss **v5** | `20261113155635.1677541-1-…` | **12** | `2026-11-25T02:23:33Z` | **我方**换址 ping | **0**（sashiko 最后 `11-13T16:12:14Z`） | ≈74.3 h（补发后） |
| fastrpc **v3** | 线程 = `<20261125022328.680070-1-…>`（ping 所在线程） | **8** | `2026-11-25T02:23:28Z` | **我方**换址 ping | **0**（Konrad 最后 `2026-11-09T14:16:40Z`） | 人类侧 18.6 天 |
| pstore **v1** | `20261116040049.434247-1-…` | **4** | `2026-11-25T09:07:09Z` | **我方** ping | **0**（Kees Cook 全程 0） | 11.7 天 |
| aw86927 **v4** | `20261124045040.559317-1-…` | **7** | `2026-11-24T04:50:40Z` | 我方 | **0**（连 sashiko 都 0） | ≈95.9 h |
| coresight **v2** | `20261127133017.1606830-1-…` | **3** | `2026-11-27T13:31:17Z` | 我方 | **0**（James 的 R-b 挂在 **v1** 线程） | ≈39.1 h |
| TNOC periphid | `20261127113158.932414-1-…` | **5** | `2026-11-27T13:23:40Z` | **我方自认 superseded** | **0**（sashiko `[Low]` `11:41:59Z`） | 已撤回，不跟帖 |
| **iris colorspace v3** | 与 v1 cover 同线程 `<20261127152024.2149804-1-…>` | **7** | **`2026-11-28T02:36:28Z`** | **我方 v3** | **0** | ≈2 h |

**两处状态变化（非人类，仅记账）**

1. **iris colorspace v3 已在 `02:36:28Z` 实发并归档**（`-b` 快照时还挂在「待放行」）：lore 线程从 6 封 → **7 封**，末封 = `[PATCH v3] media: iris: fill in a default colorspace for decoded formats`（`Sat, 28 Nov 2026 10:36:28 +0800`）。USTC **Sent Items `[400]`** 与 `SENT.md`（MID `<20261128023628.24408-1-…>`、`Result: 250`）三处一致；**至收口 0 人类回复**（`02:18Z` 之后 INBOX 只有 1 封机器人信，§1.4）。
2. `10490` `patchwork@media-ci.org` `2026-11-28T01:27:06Z` 对我方 **v2** 判 `ERROR: Fails one or more mandatory checkpatch tests` —— **早于 `-b` 切点**，本轮只做复核（v3 即为修它而发；v3 是否已过 CI **还没有回执**，这是下轮第一个观察点）。

**T24（`coresight@lists.linaro.org` moderator 自证）—— 未触发**

| 判据 | 现查 | 说明 |
|---|---|---|
| 自证判据 | 「**下一封**发 `coresight@` 时不再出现 `awaits moderator approval`」 | 我方自 `2026-11-27T13:31:17Z`（v2 三封）之后**再没向 `coresight@` 发过任何东西** ⇒ 判据**没有机会**被触发 |
| 订阅是否完成 | 是（`10478` `13:35:31Z` "results of your email commands" + `10480` `13:54:54Z` postorius 地址确认 + Sent `[382][383][387][388][389][390][391][392]`） | 时间点**晚于** v2 那三封（`13:31Z`） |
| 旁证 | INBOX 自 `13:54Z` 起 **0 封** moderator 通知；最后一条 moderator 是 `10477` `13:31:17Z` | —— |
| ⚠ 工具事实（**不要**用这条当反证） | `curl https://lore.kernel.org/coresight/<MID>/t.mbox.gz` 对我方 v1/v2 **和** James Clark 的回复**同为 404** ⇒ 该端点**不能**用来判「列表侧是否可见」；HTML 面（`/`、`/coresight/`、`/<list>/<mid>/`）现全 **403**（Anubis），只有 `/all/<MID>/t.mbox.gz` 可用 | 伪造 MID 同端点 404 作标定 |

**结论**：9 条在飞系列 **0 条**拿到人类回复；唯一动作候选是「iris v3 的 CI 回执」与「是否要给 aw86927/pstore 发第二封 ping」（§4 第 3 项，本轮均为**不建议**）。

### 3.2 用户态上游现查（只读；全部 `timeout -k`）

```bash
timeout -k 5 60 glab api --hostname gitlab.gnome.org "projects/World%2FPhosh%2Fgmobile/merge_requests/131"
timeout -k 5 60 glab api --hostname gitlab.gnome.org "projects/World%2FPhosh%2Fphoc/issues/125"
timeout -k 5 60 glab api --hostname gitlab.gnome.org "projects/World%2FPhosh%2Fphosh/merge_requests/2005"
timeout -k 5 60 curl -sS -m 45 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
timeout -k 5 45 env -u https_proxy -u http_proxy -u HTTPS_PROXY -u HTTP_PROXY gh api repos/denialwm/droidloom/issues/{48,65,69}
```

| 对象 | 现查（逐字字段） | 变化 vs `-b` | 要/否 |
|---|---|---|---|
| **gmobile `!131`** `World/Phosh/gmobile` | `state=opened` · `draft=False` · `detailed_merge_status=mergeable` · **`user_notes_count=0`** · `sha=ac5aae2a6e20c792ca743cc99105b03175b5acb1` · `created_at=2026-11-28T01:55:02.597Z` · `updated_at=01:55:42.377Z` · 标题 `display-panels: Add Lenovo Legion Y700 Gen4` | 无（≈2.75 h，零评审）；`notes` 里唯一一条是 **system** 的 "changed the description"（id `2948915`，故 `user_notes_count=0` 不矛盾） | **否**（等维护者；勿催） |
| **phoc `#125`** | `state=opened` · **`user_notes_count=11`**（notes 实返 14 条，含 3 条 system）· `updated_at=2026-11-28T01:57:09.537Z`（我方编辑）· 末条 = **我方** `2026-11-28T01:55:21.952Z`；**最后一位其他人类 = `guidog` `2023-02-17T10:33:53.385Z`** | 无（我方 note 已落，维护者 3.8 年零回） | **否**（等形状表态；勿先行提 MR） |
| **phosh `!2005`** | `state=opened` · `draft=False` · `mergeable` · `user_notes_count=3` · `sha=5300355a30f47df5443823a1c6c207adc30d9e39` · `updated_at=2026-11-27T08:24:39.948Z`；notes 7 条（含 commit system note），末条 = **我方** `08:24:39.881Z`（AI 披露 + 复现器）；`guidog` 最后一封 `2026-11-14T13:12:08Z` | 无（≈20.3 h） | **否**（等 guidog） |
| **Mobian `droid-juicer !46`** `gitlab.com/mobian1/droid-juicer` | `state=opened` · `draft=False` · `mergeable` · **`user_notes_count=0`** · `sha=ea9fe3d5c3bb81c246b959c2f0c6ca6ca07c4c4d` · `created_at=2026-11-21T09:31:14.341Z` · **`updated_at=2026-11-23T11:10:29.562Z`（≈113.5 h 不动）**；项目 open MR **6**，我方 = 1（`!46`） | 无 | **否** |
| **droidloom `#65`** | `state=open` · **`comments=2`** · `updated_at=2026-11-28T03:41:27Z`；两条评论作者**都是 `xiaquwan1001`**（`02:51:40Z` 无 placeholder IME 的复现序列；`03:41:27Z` 带 `WAYLAND_DEBUG=1` 的 `zwp_text_input_v3` 协议轨迹） | **有**：0 → 2，但**全是我方**（`-b` 之后新增） | **否**（维护者仍零回） |
| **droidloom `#69`** | `state=open` · `comments=0` · `created_at=2026-11-28T01:52:15Z` · `updated_at=01:55:36Z` | 无 | **否** |
| **droidloom `#48`** | `state=open` · `comments=1` · `updated_at=2026-11-27T14:45:11Z` | 无（唯一评论 = 我方 `11-27T14:45:11Z`） | **否**（不二次催） |

**工具事实（沿用 + 本轮新增）**
1. GNOME 侧 `glab api --hostname gitlab.gnome.org` 本轮**一次通过**（无需 `--noproxy`）。
2. `gitlab.com` 匿名 REST 可用；**但 `…/merge_requests/<iid>/notes` 匿名会 401**（本轮 `droid-juicer !46` 实测 `{"message":"401 Unauthorized"}`）⇒ notes 计数只能读 MR 对象的 `user_notes_count`。
3. `salsa.debian.org` 上 **`Mobian-team/droid-juicer` 是 404**（`{"message":"404 Project Not Found"}`）；真正的上游仓库列表是 `agx/droid-juicer`(118668)、`amartinz/…`、`dh/…`、`samcday/…`、`BengalOS-team/pkgs/…`、`Mobian-team/packages/rust-droid-juicer`(80951)。**我方 MR `!46` 在 `gitlab.com/mobian1/droid-juicer`**（与 `-b` 一致）。
4. GitHub 侧 `gh api` 仍需 `env -u https_proxy -u http_proxy -u HTTPS_PROXY -u HTTP_PROXY`，否则 TLS handshake 超时。

---

## §4 待办 / 需用户放行清单

| # | 事项 | 类别 | 为什么 | 一条命令/位置 |
|---|---|---|---|---|
| **1** | **`outlook#4737` Akinola 回不回** | **需用户放行（外发）** | 判断已做完（§2.4）：性质 = 营销外包冷启动、模板群发、零报价零交付物；建议**忽略**。若用户决定回，草稿在 §2.5（7 行，**未发送**） | 回信需用 outlook SMTP（himalaya `message send`）或 USTC 侧；本 lane 不代发 |
| **2** | `4737` 是否标 Junk | **需用户放行（改邮箱状态，非外发）** | 不回但想彻底闭环的唯一低风险做法 | `himalaya flag add 4737 --account outlook --mailbox inbox --flag junk`（**本 lane 未执行**） |
| **3** | **iris colorspace v3 的 CI 回执** | 观察点（无需动作） | v3 于 `02:36:28Z` 实发；按 v2 的节奏（`00:37:37Z` 发 → `01:27:06Z` 判红，滞后 **≈50 min**）本该在 `03:26Z` 前后到，**至 `04:34:21Z` 仍 0 回执**。⚠ **静默 ≠ 通过**：本窗口内 media-ci 只出现过 3 封（`10484/10485` 无法 apply、`10490` checkpatch 硬门），**样本不足**以断言「不报错就是过」 | 下轮首查：INBOX 有无新的 `Patchwork Integration <patchwork@media-ci.org>`；lore 线程 `<20261127152024.2149804-1-…>` 是否 >7 封；必要时读 patchwork series `1224591` 的 state（Anubis 需 curl 默认 UA） |
| **4** | **T24 自证** | 观察点 | 判据要我方**下一次**向 `coresight@` 发信才能触发；当前**未触发**（§3.1） | 若将来有 coresight 新版本：发完核 INBOX 有无 `awaits moderator approval` |
| **5** | **不做清单（本轮明确不建议）** | — | 催 = 烧信誉，且全部未到门槛 | 第二封 ping（pstore 11.7 天 / aw86927 95.9 h / mdss 74.3 h / fastrpc 74.3 h）、elden v11 重投、dwc3 v17、phoc `#125` 追评、droidloom `#65/#69/#48` 追评、Mobian `!46`、phosh `!2005`、gmobile `!131` |
| **6** | **outlook 配置缺陷的持久修法** | 需用户（环境） | 临时 `-c` 叠加可用但每次要带两个 `-c`；`scripts/read-mail-outlook.sh` 已封装同样修正 | 用户把 `~/.config/himalaya/config.toml` 的 `mailbox.alias.sent = "Sent Items"` 改成 `"Sent"`（**本 lane 未改**） |
| **7** | 台账回填（本 lane 不改 `TASKS/`） | 需另一 lane | ① `TASKS/dim/D10.md` 记「outlook 通道已可用 + alias 坑」；② iris colorspace 台账标「v3 已发 `02:36:28Z`，等 CI」；③ 用户态三件按 §3.2 刷新 T37/T32/T35 指针；④ 记 `80`（salsa 账号申诉，`03:13:43Z`）为「等回信」 | `TASKS/dim/D10.md`、`TASKS/UPSTREAM.md` §7 各行、`TASKS/NEXT.md` T37 |

---

## §5 本轮新增工具事实（供下轮直接抄）

1. **himalaya v3.0.0 的 `message read` 默认不改已读态**（帮助原文：「The read leaves the flags of the message alone, unless `--seen` is given」）⇒ 只读审计**不需要**另写 `BODY.PEEK` 脚本；`--raw` 给原始 RFC 5322 字节，`--json` 给解码后的 headers/text/html。
2. **`envelope list` 无 JSON 输出**（`-o`/`--json` 不是它的选项；`--json` 是**全局**标志位，用在 `message read` 等命令上）；时间一律按**本地时区**打印 ⇒ 引用 UTC 时必须 −8 h（本机 `Asia/Shanghai`）。
3. **alias 缺陷的三种「看起来对」的写法全废**：`-m sent` / `-m Sent` / `-m "Sent Items"` 全部被解析成不存在的 `Sent Items`；正确做法 = **临时 TOML 叠加 `-c base -c override`**。
4. `himalaya mailbox list` 能列出**真实**文件夹名（`Sent`），这是发现该缺陷最快的入口。
5. `read-mail-ustc.py --limit N` 只截**打印**的最后 N 行（`rows[-limit:]`），**前面的段会静默丢失**；核「某几天的全量」必须 `--limit` ≥ 该箱总数（本轮 1985 → `--limit 3000`），否则会得出「窗口内 0 封」的假结论。
6. **`lore.kernel.org` 的 HTML 面现在整体 403**（`/`、`/coresight/`、`/<list>/<mid>/` 均 403，Anubis），**只有 `/all/<MID>/t.mbox.gz` 可用**（默认 curl UA，200 + gzip）；`/<list>/<MID>/t.mbox.gz` 对**确实在列表里**的邮件也 404（James Clark 反例）⇒ **不能**用它判「列表侧可见性」。

---

### 附录：本轮命令与产物

```bash
date -u                                  # 2026-11-28T04:22:29Z（起点）
himalaya mailbox list --account outlook  # 发现真名 Sent vs alias "Sent Items"
himalaya envelope list  -a outlook -m inbox     -s 50 -p 1 -c cfg -c /tmp/himalaya-outlook-override.toml
himalaya envelope list  -a outlook -m junk      -s 50 -p 1 -c cfg -c /tmp/himalaya-outlook-override.toml
himalaya envelope list  -a outlook -m sent      -s 50 -p 1 -c cfg -c /tmp/himalaya-outlook-override.toml
himalaya envelope search -a outlook -m {inbox,junk,sent,存档,Deleted,Outbox,Notes} 'from:emmanuelakinola260@gmail.com' -c cfg -c …
himalaya message read 4737 -a outlook -m inbox --raw  -c cfg -c …   # 未加 --seen
himalaya message read 157  -a outlook -m junk  --raw  -c cfg -c …
himalaya message read 80   -a outlook -m sent  --raw  -c cfg -c …
read-mail-ustc.py --days 8 --limit 3000          # 全量 2194 行 → /tmp/ustc-8d-full.txt
read-mail-ustc.py --days 2 --limit 400           # 收口前复扫
python3 /tmp/d10-lore.py <9 个 cover MID>         # lore 线程封数/末封
glab api --hostname gitlab.gnome.org …           # gmobile !131 / phoc #125 / phosh !2005
curl -sS https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46
gh api repos/denialwm/droidloom/issues/{48,65,69}[/comments]
curl -sS https://lore.kernel.org/{all,coresight}/<MID>/t.mbox.gz   # 404 反例对照
```
临时文件（**均在 `/tmp`，不入库**）：`/tmp/himalaya-outlook-override.toml`、`/tmp/akinola-4737.eml`、`/tmp/junk-157.eml`、`/tmp/sent-80.eml`、`/tmp/ustc-8d-full.txt`。
