# D10 通信跟踪（只读增量 `-d`）— outlook/USTC 双箱 + 在飞系列现查 + phoc MR !829

> **只读纪律**：本文件是本轮**唯一**写入。**未发信、未回帖、未推 MR、未 `git commit`/`git push`、未改任何既有文件**。
> 两套邮箱只读：himalaya `envelope list` / `message read`（**从未加 `--seen`**）；USTC 侧一律 `BODY.PEEK`（`read-mail-ustc.py` 原实现 + 本轮临时脚本 `/tmp/d10-fetch-ustc.py` 同样用 `BODY.PEEK[]`，`M.select(box, readonly=True)`）。
> **窗口**：`2026-11-28T04:34:21Z`（上轮末次复扫，见 `reports/comms-track-20261128-c.md`）→ **`2026-11-28T06:37:52Z`**（本轮末次复扫）→ 落盘 ≈`06:45Z`。
> **基线**：`reports/comms-track-20261128-c.md`（含 §6 用户裁决落地）、`reports/upstream-userland-20261128.md`、`TASKS/dim/D10.md`。
> **判据（沿用）**：只认**人类可读回信**；`sashiko-bot` / `patchwork` / `media-ci` / GitLab / npm 之类只记「有无状态变化」；我方自己的发件不计回复。
> **通道假设变化**：用户已把 `~/.config/himalaya/config.toml` 的 `mailbox.alias.sent` 改成 `"Sent"` ⇒ 本轮**不再需要**临时 `-c` 叠加，直接 `himalaya --account outlook envelope list --mailbox sent` 即可（实测通过，§1.1）。

---

## §0 数字结论

| 指标 | 值 | 依据 |
|---|---|---|
| **窗口内新信总数（两套邮箱）** | **6 封** | outlook 2（§2.1）+ USTC 4（§2.2） |
| **其中人类手写** | **1 封** | `USTC INBOX [10493]` **Pengyu Luo** `2026-11-28T05:56:59Z`，`Re: [PATCH v8 0/2] … sm8750-lenovo-elden`（§2.2.2 全文精读） |
| 其余 5 封性质 | **全为机器人/系统** | outlook：`4816`/`4813` = GNOME GitLab pipeline；USTC：`10492`/`10494`/`10495` = USTC GitLab（我方仓库 pipeline） |
| **我方窗口内新外发** | **0 封** | USTC `Sent Items` 天花板仍是 `[400]` `2026-11-28T02:36:28Z`（iris v3，早于窗口）；outlook `Sent` 天花板仍是 `85` `04:03Z` SMTP 自测 |
| **junk 复核：`158` Akinola 是否仍在 junk** | **在**（junk 共 6 封，天花板 = `158` `2026-11-24T04:50Z`） | §2.3；且 outlook `Sent` 无任何发往 `emmanuelakinola260@gmail.com` 的信 ⇒ **未回复**（用户裁决已执行且未回滚） |
| **窗口内新 DSN/退信** | **0 封** | USTC Junk 天花板仍为 `[234]` `2026-11-27T04:06:32Z`（Nicolas Dufresne，libcamera）；outlook 三箱无 `mailer-daemon` |
| **在飞内核线程现查** | **11 条，封数见 §3** | lore `/all/<MID>/t.mbox.gz` 逐封打；**人类新回复 1 封（Pengyu，挂在 v8 线程）** |
| **iris colorspace v3（`02:36:28Z` 发）** | **Bryan/Hans 回复 0、media-ci 回执 0、新债 0** | §3.2；v2 的两个判红成因在 v3 报文里已消除（逐行） |
| **phoc `!829`（`06:03:15Z` 新建）** | `opened` / `mergeable` / **`user_notes_count=0`** / `reviewers=[]` / pipeline **1154791 success** | §4.1 |
| 其中首推 pipeline | **先红后绿**：1154790 `failed`（06:05Z，author 身份 + 格式）→ 1154791 `success`（06:09Z，17 jobs/4 stages） | §4.2（含失败根因） |
| **phoc issue `#125` 是否因 MR 增加 note** | **是，+2 条 system note（0 条人类）** | `user_notes_count` 仍 11；新增 = `mentioned in merge request !829`（06:03:17Z）+ `mentioned in commit …4931414c`（06:08:20Z）—— §4.3 |
| 其余用户态 5 对象维护者回复 | **0** | gmobile `!131` / phosh `!2005` / Mobian `droid-juicer !46` / droidloom `#65`/`#69`/`#48` —— §5.1 |
| **阻塞** | **0** | 两套 IMAP、`glab`(GNOME)、`gitlab.com` 匿名 REST、`gh`（需 `env -u *_proxy`）全部一次通过 |
| **需用户放行** | **2 项**（均非必须） | ① Pengyu 那封要不要回（建议**不回**，§2.2.2）② 若将来出 v11 是否加 `Link:` 指向他的原始 v2（建议「顺带加，不专为它发版」）—— §6 |

**一句话**：窗口 2 小时 04 分，两套邮箱**只有 1 封人类信** —— Pengyu Luo 在我们 elden **v8** 线程下答复「尽管用我的改动、不必挂 `Co-developed-by`、**引用我原始提交即可**」，我方倾向**不做动作**（v10 已在会审、1/2 已带 Krzysztof `Acked-by`，为此重投不划算）；`iris colorspace v3` 4 小时无任何回执（Bryan/Hans 均未说话，media-ci 无新债）；**phoc MR !829 已于 `06:03Z` 上线，首推 CI 因 commit 作者身份 `Elen Dev <dev@elden.local>` 被判红，`06:08Z` force-push 后 1154791 全绿，至收口 0 评审**；issue `#125` 因 MR 多了 2 条 system note，**人类仍停在 guidog 2023-02-17**。

---

## §1 通道状态

### 1.1 outlook（himalaya）—— alias 缺陷已由用户修好，直接用

```bash
himalaya --version                       # himalaya v3.0.0（+imap +smtp …）
himalaya --account outlook envelope list --mailbox sent  --page-size 12 --page 1   # ✅ 直接可用，无 -c 叠加
#  Account: outlook (imap) / Mailbox: Sent / Page: 1, envelopes 1 to 12
himalaya --account outlook envelope list --mailbox junk  --page-size 12 --page 1   # Page: 1, envelopes 1 to 6, the last
himalaya --account outlook envelope list --mailbox inbox --page-size 12 --page 1   # Page: 1, envelopes 1 to 12
```

| 项 | 本轮实测 |
|---|---|
| `mailbox.alias.sent` | 已是 `"Sent"` ⇒ `-m sent/Sent` 直接命中真实文件夹，**不再需要 `/tmp/himalaya-outlook-override.toml`**（`files/真名` 一致） |
| 箱总数 | inbox 12+（第 1 页 12，下一页仍早于 11-20）／junk **6**／Sent 12+（第 2 页起为 10 月） |
| 只读性 | 全程 `envelope list` + `message read`（无 `--seen`）；列表里 `*` 号是我方邮箱里**本来就有的**已读/旗标，非本轮所加 |
| 通道健康 | XOAUTH2（`ortie token show -a microsoft-imap-smtp`）毫秒级返回；**未落盘任何凭据** |

### 1.2 USTC（`read-mail-ustc.py`）

```bash
timeout -k 10 240 ~/.local/bin/read-mail-ustc.py --days 2 --limit 800    # rc=0，128 行，三箱全量（未截断）
timeout -k 10 240 ~/.local/bin/read-mail-ustc.py --days 8 --limit 3000   # rc=0 → INBOX 1989 / Junk 123 / Sent 83
timeout -k 10 200 ~/.local/bin/read-mail-ustc.py --days 1 --limit 200    # 收口复扫（§1.3 Ceiling 用）
```

| 箱 | 封数（SINCE 26-Nov） | **天花板（UTC）** | 窗口内新增 |
|---|---|---|---|
| INBOX | 72 | **`[10495]` `2026-11-28T06:00:09Z`** = USTC GitLab（`pi-context-meter` pipeline） | `10492`/`10493`/`10494`/`10495` |
| Junk E-mail | 20 | `[234]` `2026-11-27T04:06:32Z` Nicolas Dufresne（libcamera RFC） | **0** |
| Sent Items | 33 | **`[400]` `2026-11-28T02:36:28Z`** = 我方 iris colorspace **v3** | **0**（只读自证） |

- `--days 8` 的 1989/123/83 与上轮 1985/123/83 相比 INBOX +4 = 正是本窗口 4 封 ⇒ **窗口边界无漏扫**。
- 临时脚本 `/tmp/d10-fetch-ustc.py` 复用 `get_pw()`（keyring `smtp.ustc.edu.cn:465`）+ `BODY.PEEK[]` + `select(readonly=True)`，用于读正文。

### 1.3 本轮新增工具事实（供下轮抄）

1. **`--replies-only` 不可作为「0 回复」的证据**：它只匹配脚本里**硬编码的 3 个旧 Message-ID**（`OUR_IDS`）⇒ 对本轮所有新系列恒返回 0。判「有无回复」只能用**头部列表**（本报告用的就是它）。
2. **lore 的搜索/HTML 面仍 403**：`https://lore.kernel.org/all/?q=…&x=m` 返回 `403 Forbidden`（Anubis）⇒ 找历史提交**不能**靠 lore 搜索，只能已知 MID 走 `/all/<MID>/t.mbox.gz`（默认 curl UA）。
3. `mbox` 解析必须用 `mailbox.mbox`（按 `From ` 行分块），手写 `split(b"\nFrom ")` 会把后续邮件正文吞成空 `Date`（本轮踩过，已在 `/tmp/d10-lore.py` 修正）。
4. **`checkpatch.pl --patch <mbox>` 不可信**：它把报文尾的 `-- ` 签名行与 diff 空上下文行判成 4 个 `trailing whitespace`（`FILE: …:114: +-- $`）⇒ **别用本地 checkpatch 复跑去推断 media-ci 结论**；判 CI 只看 media-ci 回执。

---

## §2 窗口内新信逐封（6 封）

### 2.1 outlook（2 封，**均为机器人**，均与 phoc `!829` 有关）

| msg | UTC | 发件人 | 主题 | 类 | 内容要点 |
|---|---|---|---|---|---|
| `4816` | `2026-11-28T06:09:51Z` | GNOME GitLab `<gitlab-issues@gnome.org>` | `phoc \| Fixed pipeline for wip/edge-swipe-back \| 4931414c` | **R** | `Pipeline has been fixed and #1154791 has passed!`；`Commit Author: Qianhui Xu`；`successfully completed 17 jobs in 4 stages`；MR 链接 `!829` |
| `4813` | `2026-11-28T06:05:03Z` | GNOME GitLab `<gitlab-issues@gnome.org>` | `phoc \| Failed pipeline for wip/edge-swipe-back \| 7f3feda2` | **R** | `Pipeline #1154790 has failed!`；失败 job = `check-format`(#7447934) + `check-commit-log`(#7447935)，stage 均 `style-checks`；`Commit Author: **Elen Dev**` |

> 两封都是我**方仓库**（`xuqianhui1001/phoc`）的 CI 通知，不是评审、不需回信。它们在 §4.2 被当作 !829 的 CI 时序证据使用。

### 2.2 USTC INBOX（4 封）

#### 2.2.1 三封机器人（`10492` / `10494` / `10495`）

| msg | UTC | 发件人 | 主题 | 类 |
|---|---|---|---|---|
| `10492` | `2026-11-28T05:00:10Z` | USTC GitLab `<gitlab@ustc.edu.cn>` | `netease-mini-player \| Failed pipeline for main \| addd770b` | R |
| `10494` | `2026-11-28T06:00:09Z` | USTC GitLab `<gitlab@ustc.edu.cn>` | `pi-context-meter \| Auto DevOps pipeline was disabled for pi-context-meter` | R |
| `10495` | `2026-11-28T06:00:09Z` | USTC GitLab `<gitlab@ustc.edu.cn>` | `pi-context-meter \| Failed pipeline for master \| 37cd3d35` | R |

> 全是我方 USTC GitLab 实例的仓库通知（与内核无关），只记账。

#### 2.2.2 **唯一人类回信**：`10493` Pengyu Luo（elden DTS **v8** 线程）

```bash
python3 /tmp/d10-fetch-ustc.py INBOX 10493          # BODY.PEEK[]，只读
python3 /tmp/d10-lore.py 20261125091309.124354-1-xiaqinghuan@mail.ustc.edu.cn   # lore 线程现查
#  THREAD 20261125091309.124354-1-… : 7 msgs
#  … 2026-11-25T12:03:59Z | Krzysztof Kozlowski | Re: [PATCH v8 1/2] …
#    2026-11-28T05:56:59Z | Pengyu Luo <mitltlatltl@gmail.com> | Re: [PATCH v8 0/2] …
```

| 头 | 值 |
|---|---|
| `Date` | `Sat, 28 Nov 2026 13:56:59 +0800` = **`2026-11-28T05:56:59Z`** |
| `From` | `Pengyu Luo <mitltlatltl@gmail.com>` |
| `To` | `Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>`（**单收件人**） |
| `Cc` | `andersson@kernel.org, konradybcio@kernel.org, abelvesa@kernel.org, robh@kernel.org, krzk+dt@kernel.org, conor+dt@kernel.org, devicetree@vger.kernel.org, linux-arm-msm@vger.kernel.org, linux-kernel@vger.kernel.org` ⇒ **是公开列表邮件** |
| `Subject` | `Re: [PATCH v8 0/2] arm64: dts: qcom: sm8750-lenovo-elden: add the Lenovo Legion Y700 Gen4` |
| `Message-ID` | `<CAH2e8h5UCUz0hv203SsZROm_fTRptUzT96Y=ZBNozvD7ntweEg@mail.gmail.com>` |
| `In-Reply-To` | `<20261125091309.124354-1-xiaqinghuan@mail.ustc.edu.cn>`（= **v8 cover**，不是 v10） |
| **是否进 lore 归档** | ✅ 已进：`/all/20261125091309.124354-1-…/t.mbox.gz` 线程 **6 → 7 封**，末封即此信（`2026-11-28T05:56:59Z`） |

**正文（逐字，去引用段）**：

```
Feel free to incorporate my previous changes into your series. I am
happy for you to take the work forward, but I would prefer not to be
involved in its further development or maintenance. (I graduated and I
am a 995 full-time employee, I prefer to have a rest in my free time.)

There is no need to add a Co-developed-by tag on my account. A
reference to my original submission would be sufficient.

Best wishes,
Pengyu
```

他引用的是我们 **v8 cover** 里那段主动提问：

> 「…if a trailer is preferred, say which (Co-developed-by needs his Signed-off-by as well) and I will add it in v9.」

**判定**

| 问题 | 结论 | 证据 |
|---|---|---|
| 是评审意见吗 | **不是**。**没有任何技术意见**（不提 DT、不提 binding、不提 compatible） | 全文 |
| 有没有 blockage | **无**。他对「用他的工作」明确放行：`Feel free to incorporate` | 同上 |
| 要不要挂 `Co-developed-by` | **不要**（`There is no need…`），只要**引用原始提交**（`A reference to my original submission would be sufficient`） | 同上 |
| 是否需要我们动作 | **不新增动作**（见下） | —— |
| 是否要为他重投 v11 | **不需要**。v10 已在会审，`1/2` 已带 Krzysztof `Acked-by`（v10 1/2 trailer 现查）；他为「引用即可」而要求的是**极小**要求，且 v8/v9/v10 cover 均已在 lore 与维护者视野里 | §3.1 + v10 1/2 正文 |

**一处小 gap（记账，不建议为它单独发版）**：v8 cover 有专门一段「Relation to Pengyu Luo's series」，**v10 cover 没有**；v10 的 `1/2` 报文也没有指向他原始 v2 的链接。若将来因别的原因出 v11（或维护者要求 resend），**顺手在 `1/2` 的 `---` 之下补一行** `Link: <他 2026-07-26 的 "[PATCH v2 0/2] Introduce Lenovo Legion Y700 Gen4" 归档 URL>` 即满足他的要求（**本轮未加、未发**）。

> 回不回信：**建议不回**。理由：① 他的诉求（不参与、不要 trailer、引用即可）**已被默认满足**，回信不改变任何结果；② 回信会落在 **v8** 线程（v10 已是当前版本），容易让维护者在过期线程里看到新动静；③ 本 lane 无发信权限。

### 2.3 junk / sent 复核（用户裁决是否仍生效）

```bash
himalaya --account outlook envelope list --mailbox junk --page-size 12 --page 1
#  158  2026-11-24 12:50  Emmanuel Akinola        Your repo, and the people who never found it
#  157  2026-11-25 10:49  NiubiStar Support Team  Developer marketing plan for open-source projects
#  156  2026-11-17 21:41  XiaoyeAPI / 129 / 128 / 127（10 月）
himalaya --account outlook envelope list --mailbox sent --page-size 12 --page 1
#  85  2026-11-28 12:03  Qianhui Xu  himalaya SMTP test @ 2026-11-28 12:03:06
#  80  2026-11-28 11:13  徐 千惠     asking for account registry approval
#  （其余全为 10 月）
```

| 复核项 | 结果 |
|---|---|
| `158` Akinola 在 junk | **在**，且 `inbox` 第 1 页 12 封里**已无**该信（与 `-c` §6 一致） |
| 有没有人回他 / 我们回过没有 | junk 天花板 = `158`（**窗口内 0 封新 junk**）；`Sent` 天花板 = `85`（我方 SMTP 自测）⇒ **双方都没有新信**，裁决未回滚 |
| 是否出现新的冷启动/营销信 | **0**（junk 6 封全为 11-25 及以前） |

---

## §3 在飞系列（现查 `2026-11-28T06:3xZ`）

**方法**：`python3 /tmp/d10-lore.py <cover MID>` = `GET https://lore.kernel.org/all/<MID>/t.mbox.gz`（默认 curl UA）→ `mailbox.mbox` 逐封打 `Date/From/Subject`。

### 3.1 线程封数表（11 条）

| 系列 | cover / 线程 MID | 封数 | 末封（UTC） | 末封作者 | 人类回复 | 静默（对 vN 自身） |
|---|---|---|---|---|---|---|
| elden DTS **v10** | `20261126052057.1544590-1-…` | **4** | `2026-11-26T05:30:05Z` | sashiko-bot（v10 2/2） | **0** | ≈49.1 h |
| elden DTS **v8**（旧） | `20261125091309.124354-1-…` | **7**（+1） | **`2026-11-28T05:56:59Z`** | **Pengyu Luo**（§2.2.2） | **1（本轮新增）** | —— |
| dwc3 **v16** | `20261125142309.3265777-1-…` | **5** | `2026-11-25T14:36:13Z` | sashiko-bot（"found no issues"） | **0** | ≈64.0 h |
| mdss **v5** | `20261113155635.1677541-1-…` | **12** | `2026-11-25T02:23:33Z` | **我方**换址 ping | **0**（sashiko 末 `11-13T16:12:14Z`） | ≈76.2 h（ping 后） |
| fastrpc **v3** | `20261125022328.680070-1-…` | **8** | `2026-11-25T02:23:28Z` | **我方**换址 ping | **0**（Konrad 末 `11-09T14:16:40Z`） | 人类侧 ≈18.7 天 |
| pstore **v1** | `20261116040049.434247-1-…` | **4** | `2026-11-25T09:07:09Z` | **我方** ping | **0**（Kees Cook 全程 0） | 11.9 天 |
| aw86927 **v4** | `20261124045040.559317-1-…` | **7** | `2026-11-24T04:50:40Z` | 我方（6/6） | **0**（连 sashiko 0） | ≈97.8 h |
| coresight **v2** | `20261127133017.1606830-1-…` | **3** | `2026-11-27T13:30:17Z` | 我方 | **0**（James 的 R-b 在 **v1** 线程） | ≈41.1 h |
| TNOC periphid | `20261127113158.932414-1-…` | **5** | `2026-11-27T13:23:40Z` | **我方自认 superseded** | **0** | 已撤回，不跟帖 |
| DSI-PHY **v3**（M6） | `20261126052049.1544229-1-…` | **2** | `2026-11-27T20:26:47Z` | **Dmitry Baryshkov**（R-b，**窗口前**，已在 `-b`/`-20261128` 记账） | 1（旧） | 无变化 |
| iris colorspace **v3** | 与 v1 cover 同线程 `20261127152024.2149804-1-…` | **7** | `2026-11-28T02:36:28Z` | **我方 v3** | **0** | ≈4.0 h |

- **窗口内唯一变化**：`elden v8` 线程 6 → 7（Pengyu）。其余 10 条封数与上轮**逐字一致**。
- 进树检查本轮**未重跑**（窗口 2 h，无新 `linux-next` tag 发布；上轮 `-20261128` 已在内容级核过 5 个系列全部未进树）。下轮恢复内容级复核。

### 3.2 iris colorspace v3：无回复、无 media-ci 回执、无新债（证据链）

| 检查 | 现查 | 判读 |
|---|---|---|
| 线程是否 >7 封 | **仍 7 封**，末封 = 我方 v3 `02:36:28Z` | Bryan / Hans **没有任何**对 v2/v3 的回帖 |
| USTC INBOX 有无新 media-ci | 窗口内 4 封里**无** `patchwork@media-ci.org` | v3 **无回执**（v2 的回执是 `10490` `01:27:06Z`，早于窗口） |
| v2 判红成因在 v3 是否已消除 | ✅ 逐行核 `patches/upstream/v4l2-compliance-iris-20261127/0003-v3-fill-default-colorspace.patch`：① 报错句「commit 1facae9bc3c1 ("media: iris: Fix bus_info prefix in VIDIOC_QUERYCAP")」现在**同一行**（v2 是断行的，checkpatch 因此 `ERROR: Please use git commit description style 'commit <12+ chars> ("<title line>")'`）；② 正文里那句被误判成 trailer 的 `Cc: stable@vger.kernel.org), which is already in mainline…` 已改写为散文「already carries its own Fixes tag and a stable Cc」，**报文里只剩合法的 `Cc: stable@vger.kernel.org` 一行** | 两个 mandatory-ERROR 成因**均已消除**；但**不等于** media-ci 已通过 |
| ⚠ 静默 ≠ 通过 | v2 的判红滞后 ≈50 min（`00:37:37Z` 发 → `01:27:06Z` 判），v3 已 4 h 无回执 —— 两种解释：media-ci 只在失败时发信（则静默意味着过），或 v3 尚未被 patchwork 拾取（`10481` 显示 11-27 有条目被 `linux-media@vger` **拒收**：「Post to linux-media@vger.kernel.org denied: Re: [PATCH 0/11] …」，说明投递侧并非全绿） | **下轮首查**：INBOX 有无新 `patchwork@media-ci.org`；`linux-media` 线程页是否 8 封；必要时读 patchwork series state（Anubis 需 curl 默认 UA） |

### 3.3 T24（`coresight@lists.linaro.org` moderator 自证）—— 仍未触发

判据是「我方**下一封**发 `coresight@` 时不再出现 `awaits moderator approval`」；自 `2026-11-27T13:31:17Z`（v2 三封）后我方**未再向该列表发过任何东西** ⇒ 判据**没有机会**触发。INBOX 自 `13:54:54Z`（postorius 地址确认 `10480`）起 **0 封** moderator 通知（窗口内 4 封里也没有）。旁证仍然只到「订阅链路已走完」（`10473`/`10474`/`10478` + Sent `[382][383][387]…[392]`）。

---

## §4 phoc MR `!829`（新对象）

### 4.1 现查状态（`2026-11-28T06:3xZ`）

```bash
glab api --hostname gitlab.gnome.org "projects/16763/merge_requests/829"      # 16763 = World/Phosh/phoc
glab api --hostname gitlab.gnome.org "projects/16763/merge_requests/829/notes?per_page=50"
glab api --hostname gitlab.gnome.org "projects/xuqianhui1001%2Fphoc/jobs/7447935/trace"
```

| 字段 | 值 |
|---|---|
| URL | <https://gitlab.gnome.org/World/Phosh/phoc/-/merge_requests/829> |
| 标题 | `cursor: Add an edge swipe back gesture` |
| `state` / `draft` | `opened` / `False` |
| `detailed_merge_status` | **`mergeable`**（`merge_status = can_be_merged`，`has_conflicts = False`，`blocking_discussions_resolved = True`） |
| `created_at` / `updated_at` | `2026-11-28T06:03:15.483Z` / `2026-11-28T06:08:21.386Z`（= force-push 时刻，此后**无任何活动**） |
| `sha` | `4931414cc7d3fd79a9ed67c702ac0c8234f15475` |
| 分支 | `wip/edge-swipe-back` → `main` |
| **`user_notes_count`** | **0** ⇒ **没有任何人（含维护者）评论** |
| notes 实返 | **1 条，全是 system**：`2026-11-28T06:08:21.362Z xuqianhui1001 | added 1 commit ~~4931414c~~`（`7f3feda2` 被替换的对比链接） |
| `reviewers` | **`[]`**（无指派、无自愿认领） |
| `labels` / `milestone` | `[]` / `None` |
| pipeline | `1154791` **`success`**（head_pipeline 同 id 同 sha），本 MR 的 pipeline 面全绿 |
| `changes_count` | `4` —— 现查 `/changes`：`src/gesture-edge-swipe.c`（新，+331）· `src/gesture-edge-swipe.h`（新，+57）· `src/cursor.c`（+38）· `src/meson.build`（+2），**全为新增行、0 删除** |
| commits | **1 个**：`4931414c | Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn> | cursor: Add an edge swipe back gesture` |

**合规三件（用户 2026-10-31 授权前提）—— 描述里逐项在档**：

| 前提 | 现查 |
|---|---|
| ① AI 辅助披露 | ✅ 描述末节 `## AI disclosure`：「This MR was drafted with AI assistance (code, description and design notes). I reviewed, tested and built it, and I take responsibility for the contents and the decisions.」 |
| ② 可复现证据 | ✅ `## Testing` 给出编译配置（`-Dembed-wlroots=enabled -Dwlroots:default_library=static`，x86_64 + aarch64，max `GLIBC_2.38`）、真机复现步骤（左/右边缘 ≥1/4 屏宽、Firefox 不得滚动）、三条负例（中区竖滑/双指捏合/面板起手） |
| ③ 逐条回应 reviewer | **N/A 本轮**（0 条 review）；描述里已把设计取舍写清：`Known limitations`（back=close、client 仍会收到 touch-down 后收 cancel、`edge-width` 仅 GObject property）+ `Follow-ups`（跟随动画、cfg 化、与 phosh 分层 back 语义） |

> **有无 review/comment 需动作**：**没有** —— 0 条非 system note、0 reviewers。**判定：等维护者，勿催**（收口时上线 ≈34 min）。

### 4.2 首推 CI 判红的根因（已自愈，但值得记一笔）

| 时序（UTC） | 事件 | 证据 |
|---|---|---|
| `06:03:15Z` | MR `!829` 创建（`7f3feda2`） | MR `created_at` |
| `06:03:17Z` | issue `#125` 新增 system note `mentioned in merge request !829` | `issues/125/notes` |
| `06:05:03Z` | **pipeline 1154790 `failed`**（2 job） | outlook `4813` |
| `06:03:29Z` | `check-commit-log` #7447935：`ERROR: Commit message check failed` / `author: **Elen Dev <dev@elden.local>**` / `1. Missing "Signed-off-by: author information"` | job trace |
| `06:03:28Z` | `check-format` #7447934：uncrustify 要求把两处 `->handle_event (gesture, event, lx, ly)` 折行，并给出 `git rebase … --exec "./.gitlab-ci/check-style.py -r"` + `--autosquash` 流程 | job trace（404 需走**fork** 路径 `projects/xuqianhui1001%2Fphoc/jobs/<id>/trace`） |
| `06:08:21Z` | force-push 后 `4931414c`（author = `Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>`，SoB 齐全） | notes「added 1 commit」+ `sha` |
| `06:09:51Z` | **pipeline 1154791 `success`**（17 jobs / 4 stages） | outlook `4816` |

> **残余风险（给后续 lane）**：首推那版 commit 的 author 是 `Elen Dev <dev@elden.local>` —— 本机 git 身份泄漏到了 commit 里（CI 因此判「SoB 与 author 不匹配」）。当前 MR 的 commit 已正确，**但下次在 phoc 仓库提交前应先核 `git config user.name/user.email`**，否则会重复吃红。

### 4.3 issue `#125` 是否因 MR 增加 note

```bash
glab api --hostname gitlab.gnome.org "projects/16763/issues/125/notes?per_page=100&sort=desc&order_by=created_at"
#  total notes= 17
#  - 2026-11-28T06:08:20.790Z xuqianhui1001 system=True | mentioned in commit xuqianhui1001/phoc@4931414c…
#  - 2026-11-28T06:03:17.490Z xuqianhui1001 system=True | mentioned in merge request !829
#  - 2026-11-28T06:01:41.483Z xuqianhui1001 system=True | mentioned in commit xuqianhui1001/phoc@7f3feda2…
#  - 2026-11-28T01:55:21.952Z xuqianhui1001 system=False | Data point from a device … (我方证据回帖)
#  - 2023-02-17T10:33:53.385Z guidog  system=False | Yeah, I guess that's fine. …
```

| 项 | 值 |
|---|---|
| 是否增加 | **是：+3 条 system note**（`mentioned in merge request !829` 06:03:17Z、`mentioned in commit …7f3feda2` 06:01:41Z、`mentioned in commit …4931414c` 06:08:20Z） |
| 是否有**人类**新 note | **0**；`user_notes_count` 仍 **11**（system 不计）；issue `updated_at` 仍 `01:57:09Z` ⇒ **guidog 仍是最后一位人类（`2023-02-17`，3.8 年前）** |
| 结论 | 「MR 引用 issue」这条链路**已自动打通**（GitLab 侧把 MR 与 commit 都挂到了 #125），**人类侧仍零响应**；无需我方动作（不要为「提醒」再发 note） |

---

## §5 其余用户态对象（只读现查）

### 5.1 五个对象的逐字段状态

```bash
glab api --hostname gitlab.gnome.org "projects/World%2FPhosh%2Fgmobile/merge_requests/131"
glab api --hostname gitlab.gnome.org "projects/World%2FPhosh%2Fphosh/merge_requests/2005"
curl -sS https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46
env -u https_proxy -u http_proxy gh api repos/denialwm/droidloom/issues/{65,69,48}
```

| 对象 | 现查 | 变化 vs `-c` | 动作 |
|---|---|---|---|
| **phoc `!829`** | 见 §4 | **新增**（本窗口唯一新对象） | 等维护者 |
| **gmobile `!131`** | `opened` / `mergeable` / `user_notes_count=0` / `sha=ac5aae2a6e20…` / `updated_at=2026-11-28T01:55:42Z` | 无（≈4.7 h 零评审） | 否 |
| **phoc `#125`** | `opened` / `user_notes_count=11` / `updated_at=01:57:09.537Z` / 人类末条 = guidog `2023-02-17` | **+3 system note（MR/commit 引用）**，人类 0 | 否 |
| **phosh `!2005`** | `opened` / `mergeable` / `user_notes_count=3` / `sha=5300355a…` / `updated_at=2026-11-27T08:24:39.948Z` | 无（≈22.2 h） | 否（等 guidog） |
| **Mobian `droid-juicer !46`** | `opened` / `mergeable` / `user_notes_count=0` / `sha=ea9fe3d5…` / **`updated_at=2026-11-23T11:10:29.562Z`** | 无（**≈139.4 h** 不动） | 否 |
| **droidloom `#65`** | `open` / `comments=2` / `updated_at=2026-11-28T03:41:27Z` | 无（两条评论都是我方的） | 否 |
| **droidloom `#69`** | `open` / `comments=0` / `updated_at=01:55:36Z` | 无 | 否 |
| **droidloom `#48`** | `open` / `comments=1` / `updated_at=2026-11-27T14:45:11Z` | 无（唯一评论 = 我方） | 否 |

> 口径提醒：`gitlab.com` 的 `…/merge_requests/<iid>/notes` 匿名仍 **401**（上轮实测）⇒ Mobian 侧只能读 MR 对象的 `user_notes_count`。GNOME 侧 `glab api` 本轮**一次通过**（无需 `--noproxy`）。GitHub 侧 `gh api` 仍需 `env -u https_proxy -u http_proxy -u HTTPS_PROXY -u HTTP_PROXY`。

---

## §6 待办与放行清单

| # | 事项 | 类别 | 判断 / 一条命令 |
|---|---|---|---|
| **1** | **Pengyu Luo `10493` 回不回** | **需用户放行（外发）** | **建议不回**（§2.2.2：他的诉求已被默认满足，回信落在过期的 v8 线程反而添噪）。若用户坚持「礼貌回一句」，本 lane 可起草但不发 |
| **2** | **将来 v11 是否补 `Link:` 指向他原始 v2** | 需用户放行（仅在出 v11 时） | **建议「顺带加」**：`1/2` 的 `---` 之下加一行 `Link:`，不为它单独发版（他明说 `A reference … would be sufficient`） |
| **3** | **iris colorspace v3 的 media-ci 回执** | 观察点（下轮首查） | 4 h 无回执；v2 的两个 mandatory 成因在 v3 报文里已消除 ⇒ 下轮只看「INBOX 有无新 `patchwork@media-ci.org`」+「`linux-media` 线程是否 8 封」，**不宣称通过** |
| **4** | **phoc `!829` 等评审** | 观察点（勿催） | 上线 ≈34 min、0 notes、0 reviewers、pipeline 绿 ⇒ 至少隔 24–48 h 再看 |
| **5** | **phoc 仓库 git 身份** | 护栏（给后续 lane） | 首推 commit author 曾是 `Elen Dev <dev@elden.local>`（CI 因 SoB 不匹配判红）⇒ 提交前 `git config user.name/user.email` 必须为 `Qianhui Xu / xiaqinghuan@mail.ustc.edu.cn` |
| **6** | **不做清单（本轮明确不建议）** | — | 第二封 ping（pstore 11.9 天 / aw86927 97.8 h / mdss 76.2 h / fastrpc 76.2 h）、elden v11、dwc3 v17、iris v4、phoc `#125` 追评、droidloom `#65/#69/#48` 追评、Mobian `!46`、phosh `!2005`、gmobile `!131` |
| **7** | 台账回填（本 lane 不改 `TASKS/`） | 需另一 lane | ① `TASKS/dim/D10.md` 记「phoc `!829` 已上线（`06:03Z`，CI `1154791` success，0 评审）」；② 记「Pengyu `10493` `2026-11-28T05:56:59Z`：放行使用、不要 `Co-developed-by`、引用即可」；③ `TASKS/UPSTREAM.md` §7 M3-DTS 行刷新「v10 会审中 + Pengyu 放行」；④ 记 T24 仍**未触发** |

---

## 附录：本轮命令清单（全部只读）

```bash
date -u                                                       # 2026-11-28T06:32:45Z 起点 / 06:37:52Z 收口
himalaya --account outlook envelope list --mailbox {inbox,junk,sent} --page-size 12 --page 1
himalaya --account outlook message read 4816 --mailbox inbox
himalaya --account outlook message read 4813 --mailbox inbox
read-mail-ustc.py --days 2 --limit 800        # 三箱全量 128 行
read-mail-ustc.py --days 8 --limit 3000       # 1989/123/83（对账用）
read-mail-ustc.py --days 1  --limit 200       # 收口复扫（天花板核对）
read-mail-ustc.py --days 2 --limit 400 --replies-only   # ⚠ 只匹配 3 个硬编码 MID，作废
python3 /tmp/d10-fetch-ustc.py INBOX {10490,10493}      # BODY.PEEK[]，只读
python3 /tmp/d10-lore.py <11 个 MID>                    # 线程封数/末封
python3 /tmp/d10-body.py 20261126052057… {0,1}          # v10 cover + 1/2 逐字
glab api --hostname gitlab.gnome.org "projects/16763/merge_requests/829"
glab api --hostname gitlab.gnome.org "projects/16763/merge_requests/829/notes?per_page=50"
glab api --hostname gitlab.gnome.org "projects/16763/merge_requests/829/commits"
glab api --hostname gitlab.gnome.org "projects/16763/issues/125/notes?per_page=100&sort=desc&order_by=created_at"
glab api --hostname gitlab.gnome.org "projects/xuqianhui1001%2Fphoc/jobs/{7447934,7447935}/trace"
glab api --hostname gitlab.gnome.org "projects/World%2FPhosh%2F{gmobile/merge_requests/131,phosh/merge_requests/2005,phoc/issues/125}"
curl -sS https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46
env -u *_proxy gh api repos/denialwm/droidloom/issues/{65,69,48}
```

临时文件（**均在 `/tmp`，不入库**）：`/tmp/ustc-d10d.txt`、`/tmp/ustc-1d.txt`、`/tmp/d10-lore.py`、`/tmp/d10-body.py`、`/tmp/d10-fetch-ustc.py`。
