# D10 通信跟踪（2026-11-27，只读快照）— 邮件 / GitLab / GitHub / 其他

> **只读纪律**：本文件是本轮**唯一**写入。未发信、未回信、未推 MR、未 `git commit`、未 `git push`、未改任何既有报告/台账。
> IMAP 全部 `BODY.PEEK`（不改已读态），凭据运行时由 keyring 取、未落盘；外部命令一律 `timeout -k`。
> **现场核对窗口**：`2026-11-27T05:55Z` → `2026-11-27T06:06Z`（`date -u` 起点实测 `05:55:58Z`；末尾 `git.kernel.org` 响应头自述 `2026-11-27 06:01:25 +0000`）。
> **增量基线**：`reports/comm-triage-20261127-c.md`（上一轮收口 `2026-11-27T04:07:17Z`）、`reports/upstream-status-20261125.md`（系列台账）、`reports/dts-v10-sashiko-20261126.md`（T7 = 等真实修订触发）。
> **判据口径（沿用）**：只认「维护者/评审人可读的回信」+「维护者树 / linux-next **内容级**」；`patchwork` 的 `state`/`commit_ref` 不作证据。每条给「对象 + 时间 + 要/否 + 一句话」，零回复明写「零回复」。

---

## §0 数字结论

| 指标 | 值 | 依据 |
|---|---|---|
| **待我方动作（需/可外发）** | **1 项** | phosh `!2005` 回 guidog 的「no AI」要求 = **外发**，按 MEMORY 硬规则须用户放行（§2.4）；本轮不代发 |
| 需我方动作（代码/台账） | **0 项** | 两条人类 trailer 已在当前版本里闭合：`Tested-by: Jianfeng Liu` → v3 已带；`Acked-by: Krzysztof` → v9/v10 1/2 已带（§1.9/§1.10） |
| 窗口内新人类信 | **0 封** | IMAP 三箱窗口内对我方线程 0 封（§1.1）；lore 九条线程末封时刻全部早于 `04:07:17Z`（§1.4–§1.12） |
| 在飞系列「人类零回复」 | **7 条** | elden v10 / dwc3 v16 / dsi-phy v3 / mdss v5 / fastrpc v3 / pstore / aw86927 v4（§1.4–§1.11） |
| Mobian（gitlab.com + salsa） | **我方 1 件待审、salsa 0 件** | droid-juicer `!46` notes 0、`updated_at` 停在 `2026-11-23T11:10:29Z`（≈96 h 零变化）；salsa `Mobian-team` 32 个 open MR 中我方 0 个（§2.1/§2.3） |
| GNOME（phosh/phoc） | **1 MR 开、1 MR 已合、1 issue 休眠** | phosh `!2005`（最后人类 note = guidog `11-14T13:12:08Z`）、phoc `!820` **merged `10-31`**、phoc `#125` 最后活动 `2023-02-17`（§2.4–§2.6） |
| GitHub `denialwm/droidloom` 四条 | **全部非我方作者、全部 0 条我方回复** | `search/issues?q=repo:denialwm/droidloom+involves:xiaquwan1001` → `0`（§3.0） |
| 工具不可达（如实记） | **2 处** | ① `gitlab.gnome.org` 匿名 curl `406`/直连 `502`、headless Firefox 撞 CAPTCHA（认证后 `glab api` 正常，§2.4）；② `git.kernel.org` / patchwork 有 Anubis，须走 `web_fetch`（§4） |

---

## §1 邮件（USTC IMAP + lore 线程）

### 1.1 通道状态与三箱天花板

```bash
timeout -k 5 300 /home/xuqianhui/.local/bin/read-mail-ustc.py --days 2 --limit 400   # rc=0
```
原始行（逐字）：
```
=== INBOX : 186 封（SINCE 25-Nov-2026）===
=== "Junk E-mail" : 41 封（SINCE 25-Nov-2026）===
=== "Sent Items" : 13 封（SINCE 25-Nov-2026）===
```
| 箱 | 封数 | 最后一封（INTERNALDATE → UTC） | 判读 |
|---|---|---|---|
| INBOX | 186 | `Thu, 26 Nov 2026 13:33:31 -0700` = **2026-11-26T20:33:31Z**（Faizel K B，别人线程 rkcif） | 通道活；**20:33Z 后无新信**（≈9.4 h） |
| Junk E-mail | 41 | `Thu, 26 Nov 2026 23:06:32 -0500` = **2026-11-27T04:06:32Z**（Nicolas Dufresne，libcamera RFC） | 存储层活；**无我方线程、无 DSN** |
| Sent Items | 13 | `Thu, 26 Nov 2026 13:20:57 +0800` = **2026-11-26T05:20:57Z**（`[PATCH v10 2/2]`） | 我方 v9/v10/v16/dsi-phy-v3 副本齐 |

**退信面**：`grep -i -E 'mailer-daemon|postmaster|Delivery Status' /tmp/d10c_mail.txt` 三箱命中 **0** ⇒ 本轮 **0 封 DSN**（M8 `abel.vesa@linaro.org` / M10 `srinivas.kandagatla@linaro.org` 两处死地址问题未复现）。

### 1.2 我方窗口内实发（Sent 副本，非他人消息，仅记账）

| 时刻 (UTC) | 件 | 备注 |
|---|---|---|
| 2026-11-26T00:21:55–57Z | elden DTS **v9** 三封 | 已被 05:20Z 的 v10 取代 |
| 2026-11-26T05:20:49–57Z | **dsi-phy v3** 一封 + **elden v10** 三封 | 见 §1.5 / §1.4 |
| 2026-11-25T14:23:06–09Z | **dwc3 v16** 四封 | 见 §1.6 |
| 2026-11-25T02:23:28Z / 02:23:33Z | fastrpc 换址 ping / mdss 换址 ping | 见 §1.8 / §1.7 |

### 1.3 我方线程收到的回复（本快照可证的最近 4 封，均早于本轮窗口）

| # | 对象 | 时间 (UTC) | 要/否 | 一句话 |
|---|---|---|---|---|
| 1 | `Jianfeng Liu <liujianfeng1994@gmail.com>`，`Re: [PATCH v2] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES…`（线程 `20261117052047.32129`，lore 3 entries 末封） | **2026-11-26T03:23:24Z** | **否** | 外部第三方 `Tested-by`（Xiaomi Pad 5），**已落入 v3**（`patches/upstream/m6-dsi-phy-v3-20261126/*.patch` 含 `Tested-by: Jianfeng Liu`），无需回信 |
| 2 | `sashiko-bot`，`Re: [PATCH v10 2/2] elden`（线程 4 entries） | 2026-11-26T05:30:06Z | 否 | 2×`[Medium]`，**已裁决不主动回**（`reports/dts-v10-sashiko-20261126.md` §0 选 (A)，备用草稿未发） |
| 3 | `sashiko-bot`，`Re: [PATCH v9 2/2] elden` | 2026-11-26T00:31:11Z | 否 | 3×`[Medium]`，已被 v10 覆盖（v10 只剩 2 条） |
| 4 | `sashiko-bot`，`Re: [PATCH v16 0/3] usb: dwc3` | 2026-11-25T14:36:14Z | 否 | 「found no issues」，dwc3 系列机器人侧清零 |

复现（线程封数/末封逐条核）：`python3 /tmp/d10c_thread.py "https://lore.kernel.org/all/<cover-MID>/t.atom"`（脚本 = `lore-query.py` 的 `fetch` 过 Anubis，逐 entry 打 `author/updated`）。

### 1.4 elden 板 DTS **v10** — 零人类回复

- 线程：`https://lore.kernel.org/all/20261126052057.1544590-1-xiaqinghuan@mail.ustc.edu.cn/t.atom` → **4 entries**：我方 `05:21:01Z` / `05:21:02Z` / `05:21:05Z` + sashiko `2026-11-26T05:30:06Z`。
- **零回复**（Bjorn / Konrad / Conor / Krzysztof 均无）；**要/否**：**否**（T7 口径 = 等真实修订触发，见 `reports/dts-v10-sashiko-20261126.md`）。

### 1.5 M6 DSI-PHY **v3** — 零回复

- 线程：`https://lore.kernel.org/all/20261126052049.1544229-1-xiaqinghuan@mail.ustc.edu.cn/t.atom` → **1 entry**（只有我方 `2026-11-26T05:21:10Z`）。
- **零回复**（Dmitry 自 `2026-11-11T17:09:11Z` 对 v1 评审后未再发声）；**要/否**：**否**（等 dri-devel 评审窗口）。
- 附带人工核过：`Tested-by` 未丢，见 §1.3-1。

### 1.6 dwc3 **v16** — 机器人清零、人类零回复

- 线程：`https://lore.kernel.org/all/20261125142309.3265777-1-xiaqinghuan@mail.ustc.edu.cn/t.atom` → **5 entries**，末封 sashiko `2026-11-25T14:36:14Z`（"no issues"）。
- **人类零回复**（Thinh / Greg KH 均无，距投出 ≈39 h）；**要/否**：**否**。

### 1.7 M8 mdss **v5** — 维护者零回复（换址 ping 后仍静默）

- 线程：`https://lore.kernel.org/all/20261113155635.1677541-1-xiaqinghuan@mail.ustc.edu.cn/t.atom` → **12 entries**；最后一封人类 = sashiko `2026-11-13T16:12:15Z`，其后的 4 封全是我方（`11-17T04:17:20Z`、`11-24T01:52:18Z`、`11-24T15:15:50Z`、**换址补发 `11-25T02:23:45Z`**）。
- **零回复**（Dmitry / Konrad / Bjorn / clk 维护者）；**要/否**：**否**（补发距今 ≈27.5 h，未到再 ping 的门槛）。

### 1.8 M10 fastrpc **v3** — 维护者零回复

- 线程：`https://lore.kernel.org/all/20261125022328.680070-1-xiaqinghuan@mail.ustc.edu.cn/t.atom` → **8 entries**；最后一封人类 = **Konrad `2026-11-09T14:16:46Z`**，其后 3 封全是我方（v2/v3 + `11-24T15:15:48Z` + 换址补发 `11-25T02:23:38Z`）。
- **零回复**；**要/否**：**否**（技术欠账已清零，见 `TASKS/UPSTREAM.md` M10 行）。

### 1.9 M11 pstore/ram — 零回复（静默 ≈11 天）

- 线程：`https://lore.kernel.org/all/20261116040049.434247-1-xiaqinghuan@mail.ustc.edu.cn/t.atom` → **4 entries**：v1 三封 `11-16T04:01:14Z` + 我方 ping `2026-11-25T09:07:26Z`。
- **零回复**（Kees Cook 及 Cc 全静默）；**要/否**：**否**（ping 已发 ≈21 h）。

### 1.10 aw86927 **v4** — 连 sashiko 都零回复

- 线程：`https://lore.kernel.org/all/20261124045040.559317-1-xiaqinghuan@mail.ustc.edu.cn/t.atom` → **7 entries，全部我方**，末封 `2026-11-24T04:50:54Z`。
- **零回复**（Dmitry Torokhov 与 sashiko 均无，静默 ≈73 h；对照 v3 时 sashiko 13 min 内答）；**要/否**：**否**（等评审窗口）。

### 1.11 wl2868c **v12** — 线程已闭合，进树另证

- 线程：`https://lore.kernel.org/all/cover.1794557667.git.xiaqinghuan@mail.ustc.edu.cn/t.atom` → **7 entries**；最后人类 = **Rob Herring `2026-11-16T15:10:55Z`**（要 R-b tag），我方 v12 三封 `2026-11-17T05:21:29–32Z` 已带 tag ⇒ 闭合。
- 此后 **零回复**（线程无新封）；**要/否**：**否**。进树状态见 §4.1/§4.2（内容级）。

### 1.12 未投系列（备料）

- `camss-csiphy-24-v2-20261117`：**未投**（`patches/upstream/camss-csiphy-24-v2-20261117/README.md` 状态「备料，未投」）⇒ 无线程、无回复；**要/否**：**否**（投递需用户放行）。

---

## §2 GitLab（Mobian / GNOME）

### 2.0 通道

```bash
timeout -k 5 60 curl -sS --max-time 45 'https://gitlab.com/api/v4/...'          # 200（走 7890 代理）
timeout -k 5 60 curl -sS --max-time 45 'https://salsa.debian.org/api/v4/...'    # 200
timeout -k 5 45 glab api --hostname gitlab.gnome.org '...'                      # 200（glab keyring token）
curl -sS -A 'Mozilla/5.0 …' 'https://gitlab.gnome.org/api/v4/...'               # 406（0 字节，匿名被挡）
curl -sS --noproxy '*' 'https://gitlab.gnome.org/api/v4/...'                    # 502（0 字节）
```
⇒ 结论：**`gitlab.gnome.org` 必须走 `glab api`（认证）**；匿名 curl 与 headless Firefox 均不可用（后者撞 "Client Challenge" CAPTCHA，`web_fetch provider=browser` 实取到的就是验证码页）。

### 2.1 `gitlab.com/mobian1/droid-juicer` `!46`（我方 droid-juicer MR）

- URL：`https://gitlab.com/mobian1/droid-juicer/-/merge_requests/46`
- 现查（`/projects/mobian1%2Fdroid-juicer/merge_requests/46`）：`state=opened` · `draft=false` · `user_notes_count=0` · `detailed_merge_status=mergeable` · `sha=ea9fe3d5` · `updated_at=2026-11-23T11:10:29Z` · author `xiaquwan1001`。
- **零回复**（0 note、0 reviewer）；距上次变化 **≈96 h**；**要/否**：**否**（勿催，等 Mobian 维护者）。

### 2.2 `gitlab.com` 组 `mobian1` open MR 全量

- `https://gitlab.com/api/v4/groups/mobian1/merge_requests?state=opened&per_page=50` → **13 个**，其中**我方（`xiaquwan1001`）仅 `!46`**；其余最新 `updated_at` = `2026-11-23T11:10:29Z`（即 `!46` 自己）。
- **要/否**：**否**。

### 2.3 `salsa.debian.org/Mobian-team`

- `https://salsa.debian.org/api/v4/groups/Mobian-team/merge_requests?state=opened&per_page=50` → HTTP 200、**32 个 open MR**，按 author 过滤 `xiaquwan1001` = **0 个**（本轮实算 `mine: 0`）。
- 最新活动（非我方）：`Mobian-team/devices/kernels/qcom-linux!61`，`updated_at=2026-11-26T22:27:13Z`，作者 `tiol`，标题 `7.3-sdm845`。
- **要/否**：**否**（droid-juicer MR 在 gitlab.com，不在 salsa；salsa 侧我方零在投）。

### 2.4 `gitlab.gnome.org/World/Phosh/phosh` `!2005`（我方 MR）

- URL：`https://gitlab.gnome.org/World/Phosh/phosh/-/merge_requests/2005`
- 现查（`glab api … /merge_requests/2005`）：`state=opened` · `draft=false` · `merge_status=can_be_merged` · `detailed_merge_status=mergeable` · `sha=5300355a` · `user_notes_count=2` · `updated_at=2026-11-24T06:53:31Z`（= **我方 push**，非回复）· pipeline `1152598` `status=manual` / `detailed_status=Blocked`。
- notes 6 条中 5 条是我方系统 note；**最后一条人类 note = `guidog` `2026-11-14T13:12:08Z`**（原话要求「Can we continue without AI from here…」）。
- **要/否**：**要（外发类）** —— 回 guidog 属对外发送，按 MEMORY 硬规则需用户放行；本 lane 不代发、不回帖。附注：该 MR 自 `11-24T06:53:31Z` 起零变化 ≈50 h，**不是**维护者在等我们。

### 2.5 `gitlab.gnome.org/World/Phosh/phoc` `!820`（我方 MR）

- URL：`https://gitlab.gnome.org/World/Phosh/phoc/-/merge_requests/820`
- 现查（`glab api --hostname gitlab.gnome.org 'merge_requests?scope=created_by_me&state=all'`，共 2 条我方 MR）：`state=merged` · `updated_at=2026-10-31T21:22:14Z` · `user_notes_count=8`。
- **要/否**：**否**（已合入上游，无待办）。

### 2.6 `gitlab.gnome.org/World/Phosh/phoc` issue `#125`

- URL：`https://gitlab.gnome.org/World/Phosh/phoc/-/work_items/125`（`/issues/125` 同对象）
- 现查：`state=opened` · `user_notes_count=10`（notes 实返 13 条）· `updated_at=2023-02-17T10:33:53Z` · **最后一条 note = guidog `2023-02-17T10:33:53Z`**（"Yeah, I guess that's fine…"）。
- **要/否**：**否**（三年休眠、非我方创建；我方向 = 0 条 issue，`issues?scope=created_by_me` → 0）。

---

## §3 GitHub（`denialwm/droidloom`）

### 3.0 参与度先证

```bash
gh api 'search/issues?q=repo:denialwm/droidloom+involves:xiaquwan1001&per_page=20'  # total_count=0
gh api 'search/issues?q=repo:denialwm/droidloom+author:xiaquwan1001'                 # total_count=0
gh api 'repos/denialwm/droidloom'      # pushed_at=2026-11-26T18:22:59Z, open_issues=32
```
⇒ 四条 issue **均非我方提交、我方 0 条评论**；下表是「我方向关注的外部条目」现状，**需我方动作：否（四条皆是）**。

| # | 对象/URL | 时间 | 要/否 | 一句话 |
|---|---|---|---|---|
| 3.1 | `#48` `https://github.com/denialwm/droidloom/issues/48` | created = updated = **2026-11-22T12:33:38Z**；`state=open`；`comments=0` | **否** | 作者 `wt-5783`；虚拟 Wi-Fi 在 captive-portal 校验失败后永久禁用 ⇒ **维护者零回复**（4.7 天） |
| 3.2 | `#58` `https://github.com/denialwm/droidloom/issues/58` | created = updated = **2026-11-26T13:17:27Z**；`state=open`；`comments=0` | **否** | 作者 `EvilBorsch`（Ubuntu 26.04 arm64 / OnePlus Pad 3 实测清单）⇒ **零回复**（16.8 h），与我们的 Y700 用户态线相关但非我方条目 |
| 3.3 | `#21` `https://github.com/denialwm/droidloom/issues/21` | `updated_at=2026-11-16T20:17:20Z`；`comments=2`；最后一条 = **`pharra` 2026-11-16T20:16:46Z** | **否** | NixOS flake 投稿者请维护者开 PR（"Would you mind open the pull reqeust in…"）⇒ 球在维护者 `denialwm` 手上，非我方线程 |
| 3.4 | `#31` `https://github.com/denialwm/droidloom/issues/31` | `closed_at=2026-11-18T10:25:10Z`；`comments=1`；最后一条 = `synthia-si[bot]` **2026-11-18T10:25:09Z** | **否** | keymint/AVF 重试洪水 + DMA-BUF heap + netd tether 记账三条，机器人回复「各自 release 20 起已修」⇒ 已结案 |

---

## §4 其他（内容级进树判定 / 陆侧工具）

### 4.1 wl2868c：**已在 linux-next master**（内容级）

- `web_fetch provider=browser https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain/Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml`
  → 实取到 YAML 正文，`maintainers: - Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>`、`compatible: const: willsemi,wl2868c`；页面响应头 `generated by cgit … at 2026-11-27 06:01:25 +0000`。
- **要/否**：**否**（已进 next；与 §1.11「线程闭合」一致）。

### 4.2 wl2868c：**未在 torvalds/master**（同一判据、同刻）

- `web_fetch provider=browser https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml`
  → 页面正文 `Not found`（cgit 自述 `2026-11-27 06:01:25 +0000`）。
- **要/否**：**否**（等下一个 merge window；elden DTS 2/2 的 binding 依赖即此条）。

### 4.3 工具事实（复现用）

- `git.kernel.org` 直连 `curl` = Anubis 挑战页（HTTP 200 但正文是 "Making sure you're not a bot!"，`7321 B`）⇒ 必须走 `web_fetch`（本轮两次均成功）。
- `gitlab.gnome.org` 匿名：`curl` 406/502、headless Firefox CAPTCHA ⇒ 认证通道 = `glab api --hostname gitlab.gnome.org`（`gh auth status` 侧 GitHub = `xiaquwan1001` keyring，正常）。
- IMAP：`read-mail-ustc.py` 自带 `--replies-only` 判据仍是**旧 MID 白名单**（恒 0），本轮不用它；一律用「箱天花板 + lore 线程封数」两路交叉（同 `reports/mail-inbox-20261118.md` §1 结论文口径）。

### 4.4 补充（非 droidloom，但在我方 D10 台账上）

- `linux-msm/hexagonrpc` PR `#31`：`state=open` · `comments=0` · `review_comments=0` · `mergeable=true` · `updated_at=2026-11-27T03:09:39Z`；CI 最新 3 次 `Build+test` 全 `action_required`（`03:09:14Z` / `03:02:53Z` / `02:45:58Z`）⇒ **仍需维护者点批准才能跑**；**要/否**：**否（非我方动作）**。复现：`gh api 'repos/linux-msm/hexagonrpc/actions/runs?per_page=3'`。

---

## §5 零回复清单（一屏）

| 对象 | 最后人类活动 | 我方向后续 | 静默时长（至 06:0xZ） |
|---|---|---|---|
| elden DTS v10 | 无（只有 sashiko `11-26T05:30:06Z`） | 我方 3 封 `11-26T05:21Z` | ≈24.6 h |
| dsi-phy v3 | 无 | 我方 1 封 `11-26T05:21:10Z` | ≈24.6 h |
| dwc3 v16 | 无（sashiko "no issues" `11-25T14:36:14Z`） | 我方 4 封 `11-25T14:23Z` | ≈39.5 h |
| mdss v5 | sashiko `11-13T16:12:15Z` | 我方 4 次（末 = 换址 ping `11-25T02:23:45Z`） | 13.6 天（补发 27.5 h） |
| fastrpc v3 | **Konrad `11-09T14:16:46Z`** | 我方 3 次（末 = 换址 ping `11-25T02:23:38Z`） | 17.6 天（补发 27.5 h） |
| pstore/ram | 无 | v1 `11-16T04:00Z` + ping `11-25T09:07:26Z` | 11 天（ping 21 h） |
| aw86927 v4 | 无（sashiko 亦无） | 我方 7 封 `11-24T04:50Z` | ≈73 h |
| wl2868c v12 | Rob Herring `11-16T15:10:55Z`（已闭合） | v12 `11-17T05:21Z` | 10 天（无待办） |
| mobian1/droid-juicer `!46` | 无（notes 0） | 我方 `11-23T11:10:29Z` push | ≈96 h |
| phosh `!2005` | **guidog `11-14T13:12:08Z`** | 我方 `11-24T06:53:31Z` push（等放行才能回） | 12.7 天 |
| droidloom `#48` / `#58` / `#21` | 无 / 无 / `pharra 11-16T20:16:46Z` | 我方 0 | 4.7 天 / 16.8 h / 10.4 天 |
