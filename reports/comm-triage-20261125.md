# 通信 lane 增量复扫（2026-11-24 08:00Z → 2026-11-25 01:45Z）— D10，只读

> **只读纪律**：未发信 / 未推 MR / 未改任何既有文件；唯一写入 = 本文件。
> 外部命令一律 `timeout -k`（IMAP 全 `BODY.PEEK`，不改已读态；凭据只在运行时从 keyring 取，未落盘）。
> 访问日期：**2026-11-25（UTC）**，复核窗口 01:0x–01:45Z；各条实际复核时刻见表内「复核时刻」。
> 判据口径沿用上一轮：**只有「维护者/评审人可读的回信」+「维护者树 / linux-next 内容级」算状态**；
> patchwork 的 `state`/`commit_ref` 不作判据（本轮只把它当「摄取/记账是否错乱」的旁证，见 §2.2）。
> 增量基线 = `reports/comm-triage-20261124-e.md`（E 轮，覆盖到 11-24 08:30Z）。

---

## ① 结论表（一页）

| # | 对象 | 渠道 | 本轮实取（增量） | 时间戳 (UTC) | 是否有新 note | 需我方动作 |
|---|---|---|---|---|---|---|
| A | **INBOX/Junk 增量**（634 封） | IMAP `mail.ustc.edu.cn:993` | Greg KH / Dmitry Torokhov / sashiko / guidog **对我们任何线程 0 封**；仅 4 封退信（DSN）来自我方 15:15Z 的 ping 批 | 复核 `01:0xZ` | — | 见下（退信） |
| B | **aw86927 v4**（linux-input + devicetree） | lore 两列表 feed | **零回复**。两列表最新条目都还是我方 `04:50:54Z` 的 v4 6/6；静默 **20.4 h**（sashiko 对 v3 曾 13 min 内答复，对 v4 至今静默） | 投出 `11-24T04:50:46Z` | **无** | 无需（等评审窗口） |
| C | **dwc3 v14**（linux-usb！注意 duplicate） | lore `linux-usb` + `linux-devicetree` | **linux-usb 侧 v12/v13/v14 三代全部缺席**（该列表最后一代我方 v 系列 = **v11**，`11-21T13:20:37Z`；之后只有我方 duplicate-notice `04:54:23Z`）；devicetree 侧线程最新 = **Greg KH `07:14:47Z`**（= E 轮已读那封），此后无新 note | Greg `11-24T07:14:47Z` | **无**（增量内 0） | 仍是 v15 前置两条件（真机上机 + 补 `linux-usb`）；本轮不改判定 |
| D | **phosh !2005**（GNOME GitLab MR） | gitlab.gnome.org API v4（keyring token + 代理 7890） | `opened` · `mergeable` · notes **2** · `sha=5300355a` · pipeline **manual / Blocked**；`updated_at` 仍是 `11-24T06:53:31Z`（**我方 push**，不是回复）；**最新人类 note = guidog `2026-11-14T13:12:08Z`** | 复核 `01:2xZ` | **无** | 无需（等维护者；勿催） |
| E | **Mobian droid-juicer !46** | gitlab.com API v4 | `opened` · notes **0** · `sha=ea9fe3d5` · pipeline `success` · `updated_at=2026-11-23T11:10:29Z`（已 **38.1 h** 零变化） | 复核 `01:2xZ` | **无** | 无需（等维护者） |

**结论行（有没有需要本轮动手的）**：
**没有「必须先回」的新评审意见**（增量内维护者/机器人对我们 4 个对象 0 封）。
但有 **1 件新增的、需要裁决的投递事故**：我方 `11-24T15:15:40Z` ping 批里 **两个 `@linaro.org` 收件人是死地址，被 Google 退回**
（`dmitry.baryshkov@linaro.org` = M8/mdss 的评审人本人；`srinivas.kandagatla@linaro.org` = fastrpc 维护者），
即 **ping 没送到这两个人手上**。修法与重发都需用户按批放行（本 lane 不发信，见 §3）。

---

## ② 逐条证据

### 2.1 INBOX 增量（`2026-11-24 08:00Z` 之后）

脚本 = `/tmp/e4_scan.py`（沿用 E 轮；`SINCE 24-Nov-2026`，INBOX + `"Junk E-mail"`，全 `BODY.PEEK`）。
返回 **1182 封**（含 11-23 16:00Z 起，服务器 SINCE 按时区放宽），其中 **≥ 11-24 08:00Z = 634 封**。

按发件人/在办线程过滤（`grep -iE 'greg|dmitry|sashiko|guido|aw86927|dwc3|snps|phosh|droid-juicer|elden|fastrpc|mdss|wl2868c|pstore'`）：

| 期望发件人 | 增量内命中我们的线程 | 说明 |
|---|---|---|
| Greg KH | **0** | 增量内 Greg 只有 1 封（`11-24T14:24Z`），IRT 是别人的 phy 系列（`9fa428e0-…@app.fastmail.com`），与本项目无关 |
| Dmitry Torokhov | **0** | 增量内 Dmitry 10+ 封全是别人的 Input 补丁（amimouse / goodix / atkbd / pm8941-pwrkey / raydium …），无 aw86927 |
| sashiko-bot | **0** | 增量内 sashiko 15 封，全部 IRT 指他人 MID；对我们 MID 的最后一次仍是 `sashiko-outbox-230542`（`05:04Z`，E 轮已读） |
| guidog | **0** | INBOX 里根本没有 guidog（其意见只在 GitLab，见 §2.4） |

**4 封 Delivery Status Notification（本轮唯一「新东西」）**

- 位置：`"Junk E-mail"`；发件 `Mail Delivery Subsystem <mailer-daemon@googlemail.com>`；时间 `2026-11-24T07:15:40-0800` = **`15:15Z`**（另 2 封为同信副本）。
- MID / IRT：

| DSN Message-ID | In-Reply-To（我方被退的信） |
|---|---|
| `<6b05aa1c.46fc6ae6.c618b.3f9a.GMR@mx.google.com>`（及 `…3f9b…` 副本） | `<179553333372.1285526.8130842532811879857@mail.ustc.edu.cn>`（fastrpc M10 ping） |
| `<6b05aa25.218e0dbd.12dd0f.a42b.GMR@mx.google.com>`（及 `…a42a…` 副本） | `<179553334050.1285678.9600414747998960135@mail.ustc.edu.cn>`（mdss v5 / sashiko [Low] 说明） |

- 正文原样（两封各一段，逐字）：
  > ** Address not found **
  >
  > Your message wasn't delivered to **srinivas.kandagatla@linaro.org** because the address couldn't be found, or is unable to receive mail.
  >
  > The response was:
  >
  > The email account that you tried to reach does not exist. …

  > ** Address not found **
  >
  > Your message wasn't delivered to **dmitry.baryshkov@linaro.org** because the address couldn't be found, or is unable to receive mail.

- **我方需要做什么（一句话）**：把这两个收件人换成现用地址后重发/补发 ——
  `dmitry.baryshkov@**oss.qualcomm.com**`（证据：lore `linux-arm-msm` 按 `f:dmitry.baryshkov` 现查，最近 5 封全部是 `@oss.qualcomm.com`）、
  `**srini@kernel.org**`（证据：`11-24T21:06Z` 起 Srini 本人连续 4 封 From 均为 `srini@kernel.org`）。
  **重发属投递动作，须用户按批放行**；本轮只报不改。
- 上下文（不是新信件）：这两封 = `out/mail-20261124/SENT.md` 记的 23:2x CST ping 批（#1 fastrpc ping、#2 mdss/sashiko [Low] 说明），
  SENT.md 记「已发送 OK」只反映 SMTP 接受；**送达层面有 2 个死地址**。附带事实：这两封都已进 lore 归档
  （`https://lore.kernel.org/all/179553333372.1285526.8130842532811879857@mail.ustc.edu.cn/` 与
  `…/179553334050.1285678.9600414747998960135@mail.ustc.edu.cn/`，标题逐字核对），所以**列表读者能看到，只有这两个人没收到**。

### 2.2 dwc3 v14 —— duplicate 事故的现态（`linux-usb` + `linux-devicetree`）

- **linux-usb 侧缺席是事实、且不止 v14**：`https://lore.kernel.org/linux-usb/?q=dwc3+two+connectors&x=A`（feed `updated 2026-11-25T01:12:58Z`）
  逐代列出 v1(10-13)、v2(10-17)、RFC v3(10-19)、v4(10-26)、v5(10-31)、v5'(11-02)、v6(11-04)、v7(11-06 11:28)、v8(11-06 11:42)、
  v9(11-17)、v10(11-21 02:21)、**v11(11-21 13:20:37)**，然后是 `Re: [PATCH v14 0/3] …` = **我方 duplicate-notice（04:54:23Z）** —— 再无他物。
  ⇒ 该列表上 **v12 / v13 / v14 三代全部没有**；Greg「you forgot the usb list」从归档层面完全成立（不是只漏了 v14 一次）。
- **devicetree 侧线程最新 = Greg `2026-11-24T07:14:47Z`** `<2026112405-sniff-untying-8990@gregkh>`（= E 轮已读原文），
  feed `updated 2026-11-25T01:14:15Z`；其后只有我们的 duplicate-notice（`04:54:23Z`）与两套 v14（`04:52:29Z` / `01:50:12Z`）。
  ⇒ **增量内该线程无新 note**。
- **duplicate 记账现态（旁证，不作合并判据）**：patchwork `devicetree`（project 429）`q=dwc3&order=-date` 现查：
  - 重复套（`11-24T04:52`）：`[v14,1/3]` = `needs-ack`、`[v14,3/3]` = `handled-elsewhere`；
  - **原线程（`11-24T01:50`，Greg 回的就是这套）= `superseded`**。
  ⇒ patchwork 把「原套」判成被「重复套」取代（因为重复套后到、subject/编号相同）。两套逐字节相同 ⇒ **内容无风险，仅线程记账反向**；
    若维护者/b4 按 patchwork series 取件，会取到重复套（它的 discussion 里挂着 sashiko `230542`，而 Greg 的回信挂在原套）。**v15 必须开新线程并说明，别指望 patchwork 自动修复。**

### 2.3 aw86927 v4（linux-input + devicetree）

- linux-input：`https://lore.kernel.org/linux-input/?q=aw86927&x=A`（feed `updated 2026-11-25T01:03:51Z`，146 条）
  → 顶部 7 条 = v4 全 7 封（cover `04:50:46Z` … 6/6 `04:50:54Z`），下一条是 `sashiko-outbox-230375`（**11-24T02:03:12Z**，对 v3）。
- linux-devicetree：同名检索（`updated 2026-11-25T01:14:15Z`）→ 顶部同样是 v4 全 7 封，`04:50:54Z` 之后无任何条目。
- **无新 note；最新作者 = 我方 Qianhui Xu（`11-24T04:50:54Z`）**；静默 20.4 h。
- 观测（不改判定）：sashiko 对 v3 是 **13 min** 内答复（`02:03Z`），对 v4 已 **20 h** 静默 ⇒ 属机器人队列/取舍，**不构成我方欠账**，也不必催。
- patchwork 摄取正常（旁证）：`project=17`（linux-input）v4 六枚全 `new`（`04:50:35–04:50:40Z`）；`project=429`（devicetree）v4 五枚 `handled-elsewhere` + binding 枚 `not-applicable`。

### 2.4 phosh !2005（GNOME GitLab）

- `GET /api/v4/projects/16747/merge_requests/2005`（token 取自 keyring `host=gitlab.gnome.org`，经 `127.0.0.1:7890`）：
  `state=opened` · `detailed_merge_status=mergeable` · `user_notes_count=2` · `sha=5300355a` ·
  `updated_at=2026-11-24T06:53:31.635Z` · `head_pipeline.detailed_status = Blocked (waiting for manual action)`。
- `/notes?per_page=100&sort=desc` **6 条**（含 system note），最新 3 条全是我方：`06:53:31Z`(system, added 1 commit) / `06:46:10Z`(system) / `06:43:26Z`(我方 rework 正文)；
  **最新人类 = guidog `2026-11-14T13:12:08.406Z`**：「Thanks for looking into this. Can we continue without AI from here as this is far too verb…」。
- **无新 note**；`updated_at` 变新纯属我方 push。链接 `https://gitlab.gnome.org/World/Phosh/phosh/-/merge_requests/2005`。

### 2.5 Mobian droid-juicer !46（gitlab.com）

- `GET /api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46`：`state=opened` · `user_notes_count=0` · `sha=ea9fe3d5` ·
  `head_pipeline.status=success` · `draft=false` · `updated_at=2026-11-23T11:10:29.562Z`（**38.1 h 零变化**）。
- **无新 note**；链接 `https://gitlab.com/mobian1/droid-juicer/-/merge_requests/46`。（`/notes` 端点匿名读 401，故以 `user_notes_count` 为准，与上轮同。）

### 2.6 顺带更正上一轮（E 轮）的一处记录错误 —— **sashiko 两条 [Low] 的第 2 条不是正则**

E 轮 §2 把 `sashiko-outbox-230542` 的两条 `[Low]` 记成「① `unevaluatedProperties` 缺口 ② `^endpoint@…` 漏 a–f」。
**实际原文**（INBOX 逐字）：两条的标题是
1. `[Low] dt-bindings: usb: snps,dwc3: incomplete endpoint schema under port@0`
2. `[Low] dt-bindings: usb: snps,dwc3: **inter-version changelog above tearline**`
   —— 第 2 条正文：「Should the "Changes since v13:" revision log be **moved below the `---` tearline** separator so that git am does not record it in the permanent commit message?」
   而「`'^endpoint@([2-9]|[1-9a-f][0-9a-f]+)$'` 漏 single-digit `a`–`f`」是 **第 1 条正文的 "Also, …" 后半段**（同一 `[Severity: Low]` 块）。
- **为什么重要**：Greg 这轮要求的正是「changelog 必须列全历代」（11-23 已记）+ 本轮「真机测试 / 补 usb 列表」；这一条还要求 **changelog 放在 `---` 之下**。
  ⇒ **v15 的 cover 必须同时满足「历代 changelog 完整」与「changelog 在 tearline 之下」**，否则同类 `[Low]` 会再来一次。
- 同内容另有一份 `sashiko-outbox-230368`（`11-24T02:02:29Z`，挂在**原线程** v14 1/3），两条标题逐字相同 ⇒ 两套重复件得到的是同一对意见，无需分别回应。

---

## ③ 三分类（本 lane 视角）

**需裁决 / 需动作（2 件，均属投递面，须用户按批放行）**
1. **ping 批的死地址（新增）**：mdss 说明信丢给 `dmitry.baryshkov@linaro.org`、fastrpc ping 丢给 `srinivas.kandagatla@linaro.org`，
   两封都 `Address not found`。要不要以现用地址补发（`dmitry.baryshkov@oss.qualcomm.com` / `srini@kernel.org`）= 用户裁决；
   **本轮只报，不写回信、不发信**。
2. **dwc3 v15 的两个前置不变**：① 真机跑通 mux 路径（本 lane 不碰设备，须上机 lane）；② `CC` 补回 `linux-usb@vger.kernel.org`
   （**已累计缺 v12/v13/v14 三代**，v15 若再漏，Greg 侧会看到「同一要求被无视三次」）。另加一条本轮新增的卫生项：
   cover 的 changelog 放 `---` 之下、历代全列（见 §2.6）。

**可等（3 件）**
- **aw86927 v4**：静默 20.4 h，正常窗口（sashiko 稀疏属机器人侧）。
- **phosh !2005**：等 guidog；pipeline 是 `manual`（需人工触发），我方无可做。
- **droid-juicer !46**：等 Mobian 维护者，39 h 零变化。

**无需动作（1 件）**
- **dwc3 v14 的 duplicate 记账**：内容逐字节相同，线程已在两处归档；只记「patchwork 把原套标 superseded」，留作 v15 开新线程的理由。

---

## ④ 检索式 / 命令 / 访问时间（可复现）

访问日期 **2026-11-25（UTC）**；所有外部命令带 `timeout -k`。

```bash
# 0) 邮件增量（BODY.PEEK，只读；INBOX + "Junk E-mail"）
timeout -k 5 420 python3 /tmp/e4_scan.py        # → 1182 封（≥11-24 08:00Z 计 634 封）
awk -F'\t' '$1>="11-24 08:00Z"' /tmp/d10_scan_20261125.txt | grep -iE 'greg|dmitry|sashiko|guido|aw86927|dwc3|snps|phosh|droid-juicer|fastrpc|mdss'
# 单封正文（DSN / sashiko 原件）
timeout -k 5 300 python3 /tmp/e4_fetch.py '6b05aa1c.46fc6ae6.c618b.3f9b.GMR@mx.google.com' \
    '6b05aa25.218e0dbd.12dd0f.a42a.GMR@mx.google.com' sashiko-outbox-230368@kernel.org sashiko-outbox-230542@kernel.org

# 1) lore atom feed（自解 Anubis PoW；失败重试 2–3 次或改 web_fetch）
timeout -k 5 300 python3 /tmp/lget.py 'https://lore.kernel.org/linux-input/?q=aw86927&x=A'        /tmp/d10_input_aw.xml    # 146 条，顶=v4 6/6 04:50:54Z
timeout -k 5 300 python3 /tmp/lget.py 'https://lore.kernel.org/linux-devicetree/?q=aw86927&x=A'    /tmp/d10_dt_aw2.xml      # 同名，顶=v4 6/6
timeout -k 5 300 python3 /tmp/lget.py 'https://lore.kernel.org/linux-usb/?q=dwc3+two+connectors&x=A' /tmp/d10_usb_dwc3.xml   # 顶=duplicate-notice 04:54:23Z
timeout -k 5 300 python3 /tmp/lget.py 'https://lore.kernel.org/linux-devicetree/?q=%22two+connectors+sharing+one+HS%22&x=A' /tmp/d10_dt_dwc3.xml  # 顶=Greg 07:14:47Z
timeout -k 5 300 python3 /tmp/lget.py 'https://lore.kernel.org/linux-arm-msm/?q=f%3Admitry.baryshkov&x=A' /tmp/d10_bary.xml # → 现用地址 @oss.qualcomm.com

# 2) 我方 15:15Z 两封是否进档（Firecrawl 直渲染，可过 Anubis）
web_fetch 'https://lore.kernel.org/all/179553334050.1285678.9600414747998960135@mail.ustc.edu.cn/'   # 标题 = Re: [PATCH 1/3] …mdss-common…
curl -sS -A 'Mozilla/5.0' -b /tmp/anjar_lore.kernel.org.txt \
    'https://lore.kernel.org/all/179553333372.1285526.8130842532811879857@mail.ustc.edu.cn/'         # 200, <title>=Re: [PATCH v3] …non-secure domain

# 3) patchwork 摄取/记账（仅旁证，不作判据）
timeout -k 5 200 python3 /tmp/lget.py 'https://patchwork.kernel.org/api/1.2/patches/?project=17&q=aw86927&per_page=10&order=-date'  ...
timeout -k 5 200 python3 /tmp/lget.py 'https://patchwork.kernel.org/api/1.2/patches/?project=429&q=dwc3&per_page=8&order=-date' ...

# 4) GitLab
TOK=$(secret-tool lookup protocol https user xuqianhui1001 host gitlab.gnome.org)   # 只在运行时用，未落盘
curl -sS -x http://127.0.0.1:7890 -H "PRIVATE-TOKEN: $TOK" \
  'https://gitlab.gnome.org/api/v4/projects/16747/merge_requests/2005' | jq '{state,detailed_merge_status,user_notes_count,sha,updated_at}'
curl -sS -x http://127.0.0.1:7890 -H "PRIVATE-TOKEN: $TOK" \
  'https://gitlab.gnome.org/api/v4/projects/16747/merge_requests/2005/notes?per_page=100&sort=desc'
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
```

---

## ⑤ 工具事实（给下一轮省时间）

1. **`/tmp/lget.py` 的 Anubis 检测有假阳性**：它只查 `'not a bot' in html`，而挑战页里是 HTML 转义的 `you&#39;re not a bot` ⇒
   **会把「挑战页」当成功**（本轮两次把好结果覆盖成 7748 B 的挑战页）。对策：判成功改用「`<?xml` 或 `<!doctype`/`<title>` 命中预期」，并**重试 2–3 次**
   （实测同一 URL 第 1 次成功、第 2 次被挑战）。本轮已用「重试 + 内容校验」的写法。
2. **`web_fetch`（Firecrawl）能直渲染 lore 的 `/all/<MID>/`**（含 `Thread overview`），是 Anubis 限流时最省事的兜底。
3. **patchwork API 的列表端点返回裸 JSON 数组**（无 `{count,results}` 信封），不能按 DRF 分页结构解析。
4. **`read-mail-ustc.py --replies-only` 仍不可用**（`OUR_IDS` 只硬编码 3 个 2026-10 的 MID）⇒ 继续用「全量 since 扫描 + From/主题/IRT 过滤」。
5. 本轮未做：设备侧/上机（lane 边界）、任何发信/MR 推送、`TASKS/README.md` 与 `versions/` 修改。
