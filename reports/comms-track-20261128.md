# D10 通信跟踪（窗口 `2026-11-26T22:02Z` → `2026-11-27T22:17Z`）— 邮件 / lore / Mobian / phosh / GitHub（只读）

> **只读纪律**：本文件是本轮**唯一**写入。未发信、未回帖、未推 MR、未 `git commit`/`git push`、未改 `TASKS/`、未动 `reports/` 其它文件。
> IMAP 若可用一律 `BODY.PEEK`；本轮 **IMAP 与 `glab`(GNOME) 认证面均因 keyring 被锁而不可用**（§2，已有旁证），改用 **lore 全域扫**（79 线程）与 **GNOME 匿名 REST**（绕开 406，§8）取证。
> **现场时刻**：`date -u` 起点 **`2026-11-27T22:02:35Z`**（本地 `2026-11-28 06:02:35 CST`）→ 末次核 **`2026-11-27T22:17:14Z`**。窗口 = 24 h（`11-26T22:02Z` → `11-27T22:17Z`）。
> **增量基线**：`reports/comms-track-20261127-c.md`（收口 `11-27T12:32Z`）、`reports/comms-track-20261127.md`（`06:06Z`）、`patches/upstream/v4l2-compliance-iris-20261127/SENT.md`（`11-28 06:15` 更新）、`reports/upstream-sent-backfill-20261127.md`。
> **判据（沿用）**：只认「维护者/评审人可读的回信」。**机器人**（`sashiko-bot`）与**我方自己的发件**都不算回复；lore 线程按 `t.atom` 的 `entries/末封 author` 判。

---

## §0 数字结论

| 指标 | 值 | 依据 |
|---|---|---|
| **窗口内新人类回信（我方线程）** | **3 封 / 2 个系列** | James Clark `13:02:07Z`（coresight v1，**R-b**）、Bryan O'Donoghue `16:04:12Z`（iris v4l2-compliance 3 贴，**要 Fixes/stable**）、Dmitry Baryshkov `20:26:52Z`（dsi-phy v3，**R-b**）§4 |
| 其中**顺风**（无需动作） | 2 封 | James 的 R-b + 「补 fixes: tag」**已在 28 min 后的 v2 里闭合**（v2 两贴均带 `Fixes:` + `Reviewed-by: James Clark`，§4.1） |
| 其中**要动作**（代码/外发） | **1 封** | bod 对 1/3 要 `Fixes:` + `Cc: stable`；同晚另一 lane 已查明 1/3 **与主线 `1facae9bc3c1` 重复**、3/3 已被主线取代 ⇒ v2 已缩成**单贴 2/3**，**待放行投递**（§4.2 / §7-2） |
| 我方窗口内外发（非本 lane 所为，仅记账） | **4 件组 / 9 封** | coresight **v2** 3 封 `13:31Z`；TNOC **自认 superseded 撤回信** `13:23:40Z`；iris **v4l2-compliance 3 贴** `15:20:36Z`；iris 00/11 回帖（给 Neil 的硬件实测）`15:26:24Z` |
| 窗口内机器人 | **1 封** | `sashiko-bot` `11:42:00Z` 对 TNOC 2/2 `[Low]`（缺 `Fixes: ebd1eb365cae`） |
| **在飞系列「人类零回复」** | **6 条** | elden v10 / dwc3 v16 / mdss v5 / fastrpc v3 / pstore / aw86927 v4（§1） |
| Mobian | **droid-juicer `!46` notes 0、`updated_at` 不动 107 h**；mobian1 组 13 open MR 我方仍只 1 件；salsa 32 open / 我方 0（§5） |
| GNOME（phosh/phoc） | **phosh `!2005` 自 `11-27T08:24:39Z`（我方回帖）零变化 ≈13.9 h**；phoc `!820` merged；phoc `#125` 休眠 3.7 年（§5） |
| GitHub `denialwm/droidloom` | `#65` **我方 11-27T14:01:51Z 新开、0 评论**；`#48` 唯一新评论是**我方自己** `14:45:11Z` ⇒ 维护者两处均零回复（§6） |
| 工具不可达（如实记） | **3 面** | ① IMAP/keyring（锁）；② `gitlab.gnome.org` 经代理 406/`glab` 401；③ patchwork（Anubis，不作判据）（§2/§8） |

**一句话**：本轮**确有 3 封人类回信**（上两轮全是 0）——**2 个 R-b 到手**（dsi-phy v3 的 Dmitry、coresight 的 James，后者已进 v2）；**唯一动作项**是 bod 要在 iris 1/3 补 `Fixes:`+`Cc: stable`，而同晚已查明 1/3 与主线重复、v2 缩成单贴 2/3 **卡在 keyring 锁不能发**。

---

## §1 一行账（每线程：状态 / 是否新回复 / 下一步）

| # | 线程（cover MID） | 线程内人类最后活动 | **窗口内新人类回复** | 状态 | 下一步 |
|---|---|---|---|---|---|
| 1 | **coresight MODULE_DEVICE_TABLE v2** `<20261127133017.1606830-1-…>` | **James Clark `11-27T13:02:07Z`**（挂在 **v1** 下） | **有**（v1 线程，非 v2） | 🟢 **已闭合**：James 给 `Reviewed-by:` + 「Could probably do with fixes: tags for both commits」；**v2（13:31Z）两贴均已带 `Fixes:` + 该 R-b** | 无动作（等 pick up）；不要重复回帖 |
| 2 | **sm8750 TNOC periphid** `<20261127113158.932414-1-…>` | sashiko `11-27T11:42:00Z`（`[Low]`） | **无** | ⛔ **我方已自认 superseded**（`13:23:40Z` 请 Jie Gan drop：其 11-18 `[PATCH 0/4]` series 1214623 已含同两处改动） | 台账关为「撤回」；等 Jie Gan v2 进树，不跟帖 |
| 3 | **iris v4l2 系列 patchwork 1222157**（Neil Armstrong，11 贴，`<…-iris-decoder-drc-fixes-v1-0-58b9f6b3fe86@linaro.org>`） | **我方** `11-27T15:26:24Z`（回帖给 Neil，附 Y700 实测） | **无**（Neil/维护者零回） | 🟡 系列仍 `new`（上轮 patchwork 判据）；我方 H.264/HEVC 硬件证据已落帖 | 不催；等 Neil 或 Hans/Mauro 表态 |
| 4 | **M10 adsp nonsecure v3 + 换址 ping** `<20261125022328.680070-1-…>` | **Konrad `11-09T14:16:46Z`** | **无** | 🟡 8 entries，末封 = 我方 ping `11-25T02:23:38Z` | 不动作（技术欠账已清零） |
| 5 | **M11 pstore/ram 重叠 initrd + ping** `<20261116040049.434247-1-…>` | 无（Kees Cook 全程静默） | **无** | 🟡 4 entries，末封 = 我方 ping `11-25T09:07:26Z` | 静默 11.9 天；**12-02 仍静默**再议第二封 ping |
| 6 | **M8 mdss v5 + 换址 ping** `<20261113155635.1677541-1-…>` | sashiko `11-13T16:12:15Z` | **无** | 🟡 12 entries，末封 = 我方换址补发 `11-25T02:23:45Z` | 不动作（补发 2.8 天，未到门槛） |
| 7 | **M3-DTS（elden）v9 → v10** v9 `<…11-26T00:21:57Z>` / v10 `<20261126052057.1544590-1-…>` | sashiko `11-26T05:30:06Z`（v10 2/2） | **无**（Krzysztof/Bjorn/Konrad 均无） | 🟡 v10 = 在飞最新版；**v11 目录只有备料未投**（`patches/upstream/elden-dts-v11-20261126/README.md` 首行「未投递」） | 不动作（T7 口径：等真实修订触发） |
| 8 | **dwc3 v16** `<20261125142309.3265777-1-…>` | sashiko `11-25T14:36:14Z`（"found no issues"） | **无**（Thinh/Greg KH 零回） | 🟡 5 entries | 不动作（静默 2.3 天） |
| 9 | **M6 dsi-phy v3** `<20261126052049.1544229-1-…>` | **Dmitry Baryshkov `11-27T20:26:52Z`** | **有（R-b）** | ✅ **`Reviewed-by: Dmitry Baryshkov` + `Cc: <stable@vger.kernel.org>`（他加在引用块后）** | **台账补 R-b**（另一 lane 做）；不动作、不道谢 |
| 10 | **iris v4l2-compliance 3 贴** `<20261127152024.2149804-1-…>` | **Bryan O'Donoghue `11-27T16:04:12Z`**（挂 1/3） | **有（要动作）** | 🟠 「Please add an appropriate `Fixes:` and `Cc: stable@vger.kernel.org`」；同晚查明 **1/3 ≡ 主线 `1facae9bc3c1`**、3/3 已被主线取代 ⇒ **v2 = 单贴 2/3** 已备好**未投** | **需用户放行 + 先解锁会话**（§7-1/2） |
| 11 | aw86927 v4 `<20261124045040.559317-1-…>`（上轮台账在飞，本轮补扫） | 无（连 sashiko 都无） | **无** | 🟡 7 entries 全我方，末封 `11-24T04:50:54Z` | 12-01 满 7 天再议 ping |

---

## §2 邮件三箱：**本轮不可用**（keyring 锁），lore 全覆盖替代

```bash
timeout -k 5 300 /home/xuqianhui/.local/bin/read-mail-ustc.py --days 2 --limit 400
# rc=1，唯一输出：keyring 无凭据（git-credential-keyring / smtp.ustc.edu.cn:465）
```
逐层定位（逐字）：
```
python3 -c "import keyring; keyring.get_password('smtp','xiaqinghuan@mail.ustc.edu.cn')"
  → keyring.errors.KeyringLocked: Failed to unlock the collection!
secret-tool search service smtp                  → secret-tool: Cannot get secret of a locked object
git credential fill (host=smtp.ustc.edu.cn:465)   → fatal: could not read Password … 没有那个设备或地址
busctl --user … org.freedesktop.Secret.Service Collections
  → /org/freedesktop/secrets/collection/{login,session}   （服务在，collection 锁着）
```
**旁证（不是我一个人在卡）**：`patches/upstream/v4l2-compliance-iris-20261127/SENT.md`（`11-28T06:15` 更新）同一结论「本机只有 GDM greeter 会话，keyring 锁 ⇒ `git credential fill` rc=128」。⇒ **登录桌面会话后即恢复**，本 lane 不碰凭据、不尝试解锁。

**因此本轮的边界（必须知道）**：
1. **退信/DSN、列表审核通知、`[SPAM]` 标记**本轮**未核**（上轮 0 封 DSN，本轮无法证）。`coresight@lists.linaro.org` 的 moderator 审核信属此类 —— 订阅事项另有 `reports/coresight-list-subscribe-20261127.md`（需网页 Postorius，人工）。
2. 只进我们邮箱、**不进 lore** 的信（GNOME/GitLab 通知、GitHub 通知、校内信）本轮**未核**。
3. 我方 8 条内核线程**全部在 lore**，其「有无人类回复」已由 §3 全域扫覆盖 ⇒ **结论不受 IMAP 缺失影响**。

---

## §3 lore 全域扫（79 条我方线程，替代 IMAP 的主判据）

方法：先按发件人取我方近 10 天全部消息（79 条），**逐条取其 `t.atom` 线程**，只用**每线程末封的 `updated/author`** 判「窗口内有没有新人说话」。

```bash
python3 /home/xuqianhui/.local/bin/lore-query.py "https://lore.kernel.org/all/?q=f:xiaqinghuan%40mail.ustc.edu.cn+d:20261118..&x=A"   # 79 条
python3 /tmp/d10d_sweep2.py     # 逐线程取 t.atom 的末封，过滤 last >= 2026-11-26T20:00Z（源码见附录 A2）
```
原始输出（逐字，只列末封 ≥ `11-26T20:00Z` 的行；共 **17 行 / 79 线程**）：
```
2026-11-27T20:26:52Z | entries=2 | last_from=dmitry.baryshkov@oss.qualcomm.com | [PATCH v3] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES…
2026-11-27T16:04:12Z | entries=5 | last_from=bod@kernel.org | [PATCH 0/3] media: iris: fix v4l2-compliance format and cap issues
2026-11-27T16:04:12Z | entries=5 | last_from=bod@kernel.org | [PATCH 1/3] media: iris: report a platform bus_info prefix
2026-11-27T16:04:12Z | entries=5 | last_from=bod@kernel.org | [PATCH 2/3] media: iris: fill in a default colorspace…
2026-11-27T16:04:12Z | entries=5 | last_from=bod@kernel.org | [PATCH 3/3] media: iris: seed the crop rectangle…
2026-11-27T15:26:24Z | entries=13 | last_from=xiaqinghuan@mail.ustc.edu.cn | Re: [PATCH 00/11] media: iris: fix the decoder source change…
2026-11-27T13:31:18Z | entries=3  | last_from=xiaqinghuan@mail.ustc.edu.cn | [PATCH v2 0/2] coresight: add missing MODULE_DEVICE_TABLE()…
2026-11-27T13:23:44Z | entries=5  | last_from=xiaqinghuan@mail.ustc.edu.cn | Re: [PATCH 0/2] … describe the TNOC AMBA periphid
2026-11-27T13:02:07Z | entries=4  | last_from=james.clark@linaro.org | [PATCH 0/2] coresight: add missing MODULE_DEVICE_TABLE()…（v1）
```
⇒ **窗口内 `last_from` 为人类的线程只有 3 个**（Dmitry / bod / James），其余末封全是我方或 sashiko。**无第四封遗漏**。

---

## §4 三封新人类回信的原文要点与处置

### 4.1 James Clark（`<6f997513-27da-47e5-83bb-18c267e930c6@linaro.org>`，`11-27T13:02:03Z`，挂 coresight **v1**）

> 「Could probably do with fixes: tags for both commits, but:
>  **Reviewed-by: James Clark <james.clark@linaro.org>**」

- **已闭合**：v2（lore 归档 `13:31:09–13:31:18Z`，实发 ≈`13:30Z`）两贴正文实查含
  `Fixes: f78d206f3d73 ("Coresight: Add Coresight TMC Control Unit driver")`（1/2）、
  `Fixes: 5b7916625c01 ("Coresight: Add TPDA link driver")`（2/2）、两贴均 `Reviewed-by: James Clark <james.clark@linaro.org>`。
- 复现：`python3 /tmp/d10d_patch.py https://lore.kernel.org/all/20261127133017.1606830-2-xiaqinghuan@mail.ustc.edu.cn/ …-3-…`（只打 trailer/diff 行）。
- **下一步：无**（不要为「已满足的要求」再回帖）。

### 4.2 Bryan O'Donoghue（`<6505dda0-f534-4705-bcea-ecf5f6b9ec30@kernel.org>`，`11-27T16:04:09Z`，挂 iris **1/3**）

> 「Please add an appropriate `Fixes:` and `Cc: stable@vger.kernel.org`」——**只对 1/3**，2/3、3/3 未提意见。

同晚机械对账（**另一 lane 已做，本轮独立复核**）：
| 事实 | 证据 |
|---|---|
| 1/3（`plat:` → `platform:`）**与主线同一 hunk 完全重复** | `gh api repos/torvalds/linux/commits/1facae9bc3c1`：作者 Vishnu Reddy，author `2026-08-18`、**committer `2026-09-29T09:43:07Z`**，自带 `Fixes: 94ef75095d5e` + `Cc: stable@vger.kernel.org`，`Signed-off-by: Bryan O'Donoghue`（= 请他补 tag 的人本人） |
| 该提交**已在 v7.4-rc1/rc3/rc4**，**不在 v7.3** | `raw.githubusercontent.com/torvalds/linux/{v7.3,v7.4-rc1,v7.4-rc3,v7.4-rc4}/…/iris_vidc.c` → v7.3 含 `"plat:%s:%s"`、rc1/rc3/rc4 含 `"platform:%s:%s"` |
| 3/3 已被主线 `iris_vdec_s_fmt()` 无条件 seed `inst->crop` 取代 | `patches/upstream/v4l2-compliance-iris-20261127/SENT.md`（另一 lane 记 v7.4-rc3 `iris_vdec.c:271-274/309-312`） |
| ⇒ **v2 = 单贴 2/3**（rebase v7.4-rc3，`Fixes: b530b95de22c` + `Cc: stable`，AI 披露，正文说明 drop 1/3、3/3） | `patches/upstream/v4l2-compliance-iris-20261127/0002-v2-fill-default-colorspace.patch`（`git apply --check` OK / checkpatch `--strict` 0E0W0C / `--dry-run` OK） |
| **未投原因 = 同一个 keyring 锁** | 同上 `SENT.md` 末节 + `reports/v4l2-compliance-v2-20261128.md` §4 |

**下一步：需用户放行 + 先登录会话**（§7-1、§7-2）。本 lane **不代发**。

### 4.3 Dmitry Baryshkov（`<oj34ljpmxdycfa6igp7bw7ruk6fuukyxmpnneir66eagrm7itl@czqpnm3r66d4>`，`11-27T22:26:47 +0200` = `20:26:52Z`，dsi-phy v3）

> 整封只有两行（引用块之后）：
> `Cc: <stable@vger.kernel.org>`
> `Reviewed-by: Dmitry Baryshkov <dmitry.baryshkov@oss.qualcomm.com>`

- 含义：把该贴收进 msm-next 的意图 + 要求 stable 回传；**没有任何改动意见**。
- **下一步**：只改台账（M6 行补 R-b / `Cc: stable`）；**不回帖**。可留一个观察点：下一轮查 `msm-next for-next` 是否已出现该提交（内容级，不看 patchwork）。

---

## §5 Mobian / salsa / GNOME（只读现查）

### 5.1 `gitlab.com/mobian1/droid-juicer` `!46`（我方 MR）— **零回复，107 h 无变化**
```bash
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
```
```
state=opened draft=False user_notes_count=0 detailed_merge_status=mergeable
sha=ea9fe3d5c3bb81c246b959c2f0c6ca6ca07c4c4d
updated_at=2026-11-23T11:10:29.562Z  created_at=2026-11-21T09:31:14.341Z  author=xiaquwan1001
```
⇒ **无新人类回复**（notes 恒 0）；**要/否：否**（勿催）。

### 5.2 `gitlab.com` 组 `mobian1` — 13 open MR，我方仍只 1 件
`/groups/mobian1/merge_requests?state=opened&per_page=100` → `open MRs: 13`，`mine: ['mobian1/droid-juicer!46']`；组内最新变化仍是 `!46` 自己（`11-23T11:10:29Z`）。
另查 `projects/mobian1%2Fdroid-juicer/issues?state=all&updated_after=2026-11-26T22:00:00Z` → **0 条**（无人开新 issue 谈 Y700）。

### 5.3 `salsa.debian.org/Mobian-team` — 32 open MR，我方 0
`/groups/Mobian-team/merge_requests?state=opened&per_page=100` → `open MRs: 32 http_ok`、`mine: 0`。
组内窗口内唯一人类活动：`Mobian-team/devices/kernels/qcom-linux!61`（`tiol`，`7.3-sdm845`，`updated_at=2026-11-27T21:32:24Z`）——**非我方、非 Y700**，仅记账。

### 5.4 `gitlab.gnome.org/World/Phosh/phosh` `!2005`（我方 MR）— **无新回复**
```bash
curl -sS --noproxy '*' 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphosh/merge_requests?iids%5B%5D=2005&state=all'
```
```
iid=2005 state=opened draft=False detailed_merge_status=mergeable
sha=5300355a30f47df5443823a1c6c207adc30d9e39  user_notes_count=3
updated_at=2026-11-27T08:24:39.948Z  created_at=2026-11-14T12:51:03.731Z  author=xuqianhui1001
```
- `updated_at` = **我方 `11-27T08:24:39Z` 的回帖**（上轮 `-c` 报告 §4.4 已记）；`sha` 未变、notes 由 2 → 3（就是我方那条）。
⇒ **guidog 自 `11-14T13:12:08Z` 起仍零回**（静默 **13.4 天**）；**要/否：否**（不要为「催回复」再发；该 MR 的回复权属外发，且上轮已回过）。

### 5.5 `gitlab.gnome.org/World/Phosh/phoc` `!820` / issue `#125`
```
!820 : state=merged  updated_at=2026-10-31T21:22:14.192Z  user_notes_count=8   （已合入，无待办）
#125 : state=opened  user_notes_count=10  updated_at=2023-02-17T10:33:53.407Z  author=guidog （三年休眠、非我方）
```
我方在 GNOME 的 MR 全量 = **2 条**（`author_username=xuqianhui1001&state=all`：phosh `!2005` + phoc `!820`），**无第三条**。

---

## §6 GitHub `denialwm/droidloom`（`#65`、`#48`）

```bash
gh api repos/denialwm/droidloom --jq '{pushed_at,open_issues_count}'   # 2026-11-27T11:45:05Z / 35
gh api repos/denialwm/droidloom/issues/65 --jq '{state,user:.user.login,created_at,updated_at,comments}'
gh api repos/denialwm/droidloom/issues/48 --jq '{state,user:.user.login,created_at,updated_at,comments}'
gh api repos/denialwm/droidloom/issues/48/comments --jq '.[]|"\(.created_at) | \(.user.login)"'
gh api 'repos/denialwm/droidloom/issues/65/timeline?per_page=100'      # 空
```

| # | 状态 | 时间 | **有无人类回复** | 说明 |
|---|---|---|---|---|
| `#65` | `open`，`comments=0`，timeline **空** | created = updated = **`2026-11-27T14:01:51Z`** | **无** | **我方（`xiaquwan1001`）新开**：「Placeholder IME: showSoftInput always fails (…PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE) and no keyboard is drawn (0.1.0-49 / 0.1.0-51)」⇒ 维护者零回（≈8.3 h） |
| `#48` | `open`，`comments=1` | updated **`2026-11-27T14:45:11Z`** | **无** | 唯一评论 = **我方自己**（`xiaquwan1001`，第三份独立复现：三探针今日均 `204`、蜂窝仍永久离线）；之后再 1 条 `referenced` 事件（`15:10:15Z`，也是我方）。维护者 `wt-5783` 条目本身 **零回** |

**要/否：否**（两条都是我方向发声，按纪律不 ping、不二次催）。
附记账（我方 D10 台账上的外部 PR）：`linux-msm/hexagonrpc` PR `#31` → `state=OPEN` · `reviews=0` · `comments=0` · `mergeStateStatus=UNSTABLE` · `updatedAt=2026-11-27T03:09:39Z`（窗口内**无变化**）。

---

## §7 **需用户放行 / 需人工**（本轮全部动作项）

| # | 事项 | 类别 | 为什么需要人 | 一条命令/位置 |
|---|---|---|---|---|
| 1 | **登录桌面会话 → keyring 解锁** | **需人工（最高优先）** | 当前只有 GDM greeter，`login` collection 锁着 ⇒ **IMAP 读信 + `glab`(GNOME 认证) + 所有 `git send-email` 全部不可用** | 图形登录（或 `loginctl` 解锁会话）后重跑 `read-mail-ustc.py`；本 lane 不碰口令 |
| 2 | **投 iris v2 单贴（drop 1/3、3/3，仅 2/3）** | **需用户放行（外发）** | bod 的回信是「要 tag」而不是「已收」；1/3 与主线重复、3/3 已被取代 ⇒ 必须发 v2 并说明 drop，否则系列挂在错前提上 | `cd patches/upstream/v4l2-compliance-iris-20261127 && git send-email --dry-run …`（实发命令见该目录 `SEND.sh`/`SENT.md`；门禁已过） |
| 3 | **`coresight@lists.linaro.org` 订阅**（网页 Postorius） | **需人工**（用户已放行订阅，邮件路 3 条全败） | 非成员 ⇒ v1/v2 各 3 封被压审，列表成员看不到 | `reports/coresight-list-subscribe-20261127.md`（登录态确认） |
| 4 | **台账回填（我不改 `TASKS/`）** | 需另一 lane/人工 | 本轮 3 封人类信改变 3 行状态 | ① M6 dsi-phy v3：加 `Reviewed-by: Dmitry Baryshkov` + `Cc: stable`（`11-27T20:26:52Z`）；② coresight MODULE_DEVICE_TABLE：**v2 已带 James R-b + Fixes ⇒ 系列可标「等 pick up」**；③ TNOC：标 **撤回/superseded**（`13:23:40Z` 撤回信已发）；④ iris v4l2-compliance：标「v2 单贴待放行」 |
| 5 | 下一轮观察点（无需动作） | 记录 | — | msm-next `for-next` 是否出现 dsi-phy v3 提交；`next-2026112x` 是否含 coresight `MODULE_DEVICE_TABLE`；Jie Gan TNOC `v2` 是否进树 |
| 6 | `droid-juicer!46`(107 h/0 note)、phosh `!2005`(13.4 天)、droidloom `#48`/`#65`、mdss/fastrpc/pstore/elden v10/dwc3 v16 | **不做** | 队列慢属常态；催只会烧信誉 | §1/§5/§6 |

---

## §8 工具事实（本轮新增/修正，供下轮直接抄）

1. **`gitlab.gnome.org` 的 406 是「代理出口」造成的，不是权限**：经 `https_proxy=127.0.0.1:7890`（本机默认 env）访问 → Fastly `HTTP/2 406`、`content-length: 0`、`x-served-by: cache-sin-…`；**`curl --noproxy '*'` 直连即 200**。
2. **`glab api` 现在的 406**：`glab` 的 GNOME token 存在 keyring（`~/.config/glab-cli/config.yml` 里 `gitlab.gnome.org` 段**无 token 行**）⇒ keyring 锁时 glab 退化为匿名 ⇒ 406。`GITLAB_TOKEN` env 里的 token **只对 `gitlab.com` 无效、对 GNOME 也 401**（`/api/v4/version` + token → 401/406），别拿它当 GNOME 凭据。
3. **GNOME 匿名可读面（本轮实测）**：`/api/v4/projects/<id>/merge_requests`（列表，含 `?iids[]=2005&state=all` 取单条）、`/issues/<iid>`、`/merge_requests?author_username=…&state=all` **都 200**；但**单条 MR `/merge_requests/<iid>`、`/notes`、`/discussions` 一律 406/401**，MR 网页 HTML 是 Fastly 挑战页（`/_fs-ch-…`）⇒ **判「有无新回复」只能用「列表里的 `updated_at` + `user_notes_count` + `sha`」三件套**（本轮即此法）。
4. **`patchwork.kernel.org` 仍不可用**（Anubis 挑战页，HTTP 200 非 JSON）⇒ 本报告**零** patchwork 判据（含 §1-3 的「仍 new」直接引自上一轮 `-c` 报告，未重复现查）。
5. `lore` 侧 `t.atom` + `lore-query.py` 的 Anubis 自动解题本轮全程正常（79 次线程取数无失败）。

---

## §9 残差（如实）

1. **IMAP 未核**：DSN/退信、列表审核通知、`[SPAM]` 标记、GNOME/GitLab/GitHub 邮件通知 —— 本轮**无数据**（§2）。内核线程结论不受影响（lore 全覆盖）。
2. **GNOME notes 正文读不到**（匿名 406/401）：`!2005` 的「无新回复」由 `updated_at=11-27T08:24:39Z`（我方回帖）+ `user_notes_count=3` 推出，未逐条读 note 正文。
3. `#48` 我方评论（`14:45:11Z`）**具体措辞只读了前 400 字符**；如需全文另行取。
4. 未查 `msm-next`/`linux-next` 内容级进树（本轮任务范围外），只留观察点（§7-5）。

---

## 附录 A：本轮全部命令（只读，可逐条复现）

```bash
# 0) 现场与纪律
cd /home/xuqianhui/y700-elden && git rev-parse --show-toplevel      # /home/xuqianhui/y700-elden
date -u                                                             # 2026-11-27T22:02:35Z（末核 22:17:14Z）
git status --porcelain                                              # 只读核对：本 lane 未动任何既有文件

# 1) 邮件（失败面，逐层定位）
timeout -k 5 300 /home/xuqianhui/.local/bin/read-mail-ustc.py --days 2 --limit 400      # rc=1 keyring 无凭据
python3 -c "import keyring;keyring.get_password('smtp','xiaqinghuan@mail.ustc.edu.cn')"  # KeyringLocked
secret-tool search service smtp                                                          # Cannot get secret of a locked object
printf 'protocol=smtp\nhost=smtp.ustc.edu.cn:465\nusername=xiaqinghuan@mail.ustc.edu.cn\n\n' | git credential fill
busctl --user call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.DBus.Properties Get ss org.freedesktop.Secret.Service Collections
grep -n 'gitlab.gnome.org' -A5 ~/.config/glab-cli/config.yml                             # 该段无 token 行

# 2) lore 单线程（点查，脚本 = 上一轮 /tmp/d10c_thread.py，逐 entry 打 author/updated）
python3 /tmp/d10c_thread.py "https://lore.kernel.org/all/<cover-MID>/t.atom"
#   实跑的 8+3 条线程：
#   20261127133017.1606830-1 / 20261127113158.932414-1 / 20261125022328.680070-1 / 20261116040049.434247-1
#   20261113155635.1677541-1 / 20261126052057.1544590-1 / 20261125142309.3265777-1 / 20261124045040.559317-1
#   20261126052049.1544229-1 / 20261127113137.931578-1（v1）/ linux-media/20261125-topic-iris-decoder-drc-fixes-v1-0-58b9f6b3fe86@linaro.org

# 3) lore 全域扫（79 线程，主判据）
python3 /home/xuqianhui/.local/bin/lore-query.py "https://lore.kernel.org/all/?q=f:xiaqinghuan%40mail.ustc.edu.cn+d:20261118..&x=A"
python3 /tmp/d10d_sweep2.py                                        # 源码见 A2

# 4) 取正文 / 取 trailer（只读）
python3 /tmp/d10d_links.py "<thread>/t.atom"                       # 每条 entry 的 URL（找人类那封的 MID）
python3 /tmp/d10d_raw.py "https://lore.kernel.org/all/6f997513-27da-47e5-83bb-18c267e930c6@linaro.org/"          # James Clark
python3 /tmp/d10d_raw.py "https://lore.kernel.org/all/6505dda0-f534-4705-bcea-ecf5f6b9ec30@kernel.org/"          # bod
python3 /tmp/d10d_raw.py "https://lore.kernel.org/all/oj34ljpmxdycfa6igp7bw7ruk6fuukyxmpnneir66eagrm7itl@czqpnm3r66d4/"  # Dmitry
python3 /tmp/d10d_raw.py "https://lore.kernel.org/all/179578582079.1094405.15142623585619157958@mail.ustc.edu.cn/"        # 我方 TNOC 撤回信
python3 /tmp/d10d_patch.py "…/20261127133017.1606830-2-…/" "…/20261127133017.1606830-3-…/"   # 只打 Fixes/Reviewed-by/diff 行

# 5) 主线对账（Fixes 候选 + 是否重复）
gh api 'repos/torvalds/linux/commits?path=drivers/media/platform/qcom/iris/iris_vidc.c&per_page=40' \
  --jq '.[]|"\(.sha[0:12]) \(.commit.author.date) \(.commit.message|split("\n")[0])"'
gh api repos/torvalds/linux/commits/1facae9bc3c1 --jq '"a=\(.commit.author.date) c=\(.commit.committer.date)"'
for t in v7.3 v7.4-rc1 v7.4-rc3 v7.4-rc4; do
  curl -sS -o /tmp/x.c "https://raw.githubusercontent.com/torvalds/linux/$t/drivers/media/platform/qcom/iris/iris_vidc.c"
  echo "$t plat=$(grep -c '"plat:%s:%s"' /tmp/x.c) platform=$(grep -c '"platform:%s:%s"' /tmp/x.c)"
done

# 6) GitLab（gitlab.com / salsa 匿名 REST 正常；GNOME 必须 --noproxy）
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
curl -sS 'https://gitlab.com/api/v4/groups/mobian1/merge_requests?state=opened&per_page=100'
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/issues?state=all&updated_after=2026-11-26T22:00:00Z'
curl -sS 'https://salsa.debian.org/api/v4/groups/Mobian-team/merge_requests?state=opened&per_page=100'
curl -sS --noproxy '*' 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphosh/merge_requests?iids%5B%5D=2005&state=all'
curl -sS --noproxy '*' 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphosh/merge_requests?author_username=xuqianhui1001&state=all&per_page=50'
curl -sS --noproxy '*' 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphoc/merge_requests?author_username=xuqianhui1001&state=all&per_page=50'
curl -sS --noproxy '*' 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphoc/issues/125'
#   反例（406）：curl -sS 'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphosh/merge_requests/2005'
#   反例（406）：timeout 90 glab api --hostname gitlab.gnome.org 'projects/World%2FPhosh%2Fphosh/merge_requests/2005'

# 7) GitHub
gh api repos/denialwm/droidloom --jq '{pushed_at,open_issues_count}'
gh api repos/denialwm/droidloom/issues/65 --jq '{number,state,user:.user.login,created_at,updated_at,comments}'
gh api repos/denialwm/droidloom/issues/48 --jq '{number,state,user:.user.login,created_at,updated_at,comments}'
gh api repos/denialwm/droidloom/issues/48/comments --jq '.[]|"\(.created_at) \(.user.login)"'
gh api 'repos/denialwm/droidloom/issues/48/timeline?per_page=100' --jq '.[]|"\(.created_at) \(.event) \(.actor.login//"")"'
gh api 'repos/denialwm/droidloom/issues/65/timeline?per_page=100'
gh pr view 31 --repo linux-msm/hexagonrpc --json state,updatedAt,mergeStateStatus,reviews,comments
```

### A2：`/tmp/d10d_sweep2.py`（本轮主判据脚本，只读、无写入）
```python
import importlib.util, pathlib, re
LQ = pathlib.Path.home()/".local/bin/lore-query.py"
spec = importlib.util.spec_from_file_location("lq", LQ)
lq = importlib.util.module_from_spec(spec); spec.loader.exec_module(lq)
final, body = lq.fetch("https://lore.kernel.org/all/?q=f:xiaqinghuan%40mail.ustc.edu.cn+d:20261118..&x=A")
msgs = []
for m in re.finditer(r'<entry>(.*?)</entry>', body, re.S):
    e = m.group(1)
    link = re.search(r'<link[^>]*href="([^"]+)"', e); tit = re.search(r'<title>(.*?)</title>', e, re.S)
    if link: msgs.append((re.sub(r"\s+"," ",tit.group(1))[:70] if tit else '?', link.group(1)))
res = {}
for tit, url in msgs:                       # 逐条取线程 atom，只用「末封」判新人
    turl = url.rstrip('/') + "/t.atom"
    if turl in res: continue
    f2, b2 = lq.fetch(turl)
    ent = re.findall(r'<entry>(.*?)</entry>', b2, re.S)
    if not ent: continue
    e = ent[-1]
    em = re.search(r'<email>(.*?)</email>', e, re.S); eu = re.search(r'<updated>(.*?)</updated>', e, re.S)
    res[turl] = (len(ent), eu.group(1), em.group(1), tit)
for k,(n,last,who,tit) in sorted(res.items(), key=lambda kv: kv[1][1], reverse=True):
    if last >= "2026-11-26T20:00:00Z": print(last, n, who, tit, k)
```

■ 结束

---

## 2026-11-28 09:3x CST 增量（T32/D13/T33 轮，只读）

窗口：2026-11-27T16:00Z → 2026-11-28T01:30Z（接上一节的 11-28 早轮）。

| 面 | 结果 |
|---|---|
| **USTC INBOX（人类）** | **1 封**：`[10489] 2026-11-27T22:26:47+0200 Dmitry Baryshkov` `Re: [PATCH v3] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable` ⇒ 正文末 **`Reviewed-by: Dmitry Baryshkov <dmitry.baryshkov@oss.qualcomm.com>`**（无技术异议）。**M6 首个维护者 Reviewed-by**。 |
| **USTC INBOX（机器人）** | `[10490] Patchwork Integration` iris v2 colorspace 通知（= 我们 08:37 CST 自己发出的那贴） |
| **其它未读** | 无（近 8 天 INBOX 最新即 10489/10490；Junk 无可疑；无退信） |
| **hexagonrpc PR #31** | 仍 `OPEN` / `UNSTABLE` / `reviews=[]`，`updatedAt` 仍是 2026-11-27T03:09:39Z（零变化） |
| **droidloom issues** | `#65` = OPEN、`updatedAt` 2026-11-27T14:01:51Z、**comments 0**；`#48` 最后一条仍是我们的 11-27 评论（`updatedAt` 14:45:11Z）⇒ 维护者未回复 |
| **网络坑** | `gh` 默认走 `https_proxy` ⇒ `api.github.com` TLS handshake timeout；`env -u https_proxy …` 即正常（`curl --noproxy '*'` = 200 同证） |

**本轮我方欠动作（0 项必须）**：M6 的 `Reviewed-by` 只需在下次修订（v4 或合入后）带进 commit trailer；不需要单独回帖（D10 只读口径）。

### 2026-11-28 09:5x 我方外发（用户裁决后执行，已报备）

| 面 | 动作 | 结果 |
|---|---|---|
| droidloom | 新 issue **#69**：图形 IME 不投影到宿主（Trime/Fossify 对照 + `grim` 证据 + 源码指针 + 三条 asks） | <https://github.com/denialwm/droidloom/issues/69>（正文 `reports/artifacts/droidloom-graphical-ime-20261128/body.md`，含 AI 披露行） |
| gmobile（Phosh 上游） | **MR !131** `display-panels: Add Lenovo Legion Y700 Gen4` | <https://gitlab.gnome.org/World/Phosh/gmobile/-/merge_requests/131>，commit `ac5aae2`，`mergeable`、pipeline running |
| phoc | #125 证据回帖（lisgd 旁听/不吞事件的实测 + phoc 内实现提议） | note `2948914`，2026-11-28T01:55:21Z |

全账 = `reports/upstream-userland-20261128.md`。凭据：GNOME token（keyring）走 bettbox `127.0.0.1:7890`；GitHub 走 `gh`（需 `env -u *_proxy`）。
