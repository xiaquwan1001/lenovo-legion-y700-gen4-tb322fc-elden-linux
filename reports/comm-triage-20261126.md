# 通信 lane 增量复扫（2026-11-25 01:45Z → 2026-11-25 22:11Z）— B4，只读
> **后继轮次**：同日 04:20Z 的 D10 lane 复扫 = `reports/comm-triage-20261126-d10.md`（本文件的 IMAP/phosh 两个「无法核验」面已被它结案；人类回信计数以 D10 为准）。

> **只读纪律**：未发信 / 未推 MR / 未改任何既有文件；唯一写入 = 本文件。
> 外部命令一律 `timeout -k`（lore 走 web_fetch/lget 重试 + 内容校验；patchwork 走 Anubis PoW）。
> 访问窗口：**2026-11-25 22:0x–22:1xZ**（CST 已是 11-26 早晨；文件名沿用 CST 日期惯例）。
> 判据口径沿用上一轮：**只有「维护者/评审人可读的回信」+「维护者树 / linux-next 内容级」算状态**；
> patchwork `state`/`commit_ref` 只作摄取/记账旁证。
> 增量基线 = `reports/comm-triage-20261125.md`（覆盖到 11-25 01:45Z）。

---

## ① 结论表（一页）

| # | 对象 | 渠道 | 本轮实取（增量） | 时间戳 (UTC) | 是否有新 note | 需我方动作 |
|---|---|---|---|---|---|---|
| A | **INBOX/Junk IMAP 增量** | IMAP `mail.ustc.edu.cn:993` | **本轮无法核验**：Login keyring 锁定（GDM 停在登录界面，无图形会话应答解锁提示）。服务器本身可达（`* OK Coremail System IMap Server Ready`），仅认证通道被挡 | 尝试 `22:07Z` | **未知** | 需用户解锁（见 §3-1） |
| B | **dwc3 v16**（linux-usb + devicetree） | lore 线程页 / feed | **4/4 归档两处**；**sashiko 14:36:14Z 回复：「reviewed this 3-patch series and found no issues」**（本系列首个零缺陷评审）；linux-usb 本代在 Cc ✓；Greg/Thinh 尚无回复 | 投出 `14:23:16Z`；sashiko `14:36:14Z` | **有（正面）** | 无需（等 Thinh/Greg；无人需回） |
| C | **elden 板 DTS v8**（arm-msm + devicetree） | lore | **已归档两处**（cover `09:13:16Z` + 2/2 `09:13:25Z`）；**2 条新 note**：sashiko `09:19:45Z` 2×[Medium]（均在 cover 已声明）+ **Krzysztof `12:03:11Z`：changelog/cover 应明写「waiting on bindings」，别用墙纸文字** | Krzysztof `12:03:11Z` | **有（需回应）** | **v9 或回信时逐条落实**（见 §2.4） |
| D | **M8 mdss 换址补发**（→ `dmitry.baryshkov@oss.qualcomm.com`） | lore arm-msm | **已归档**（`02:23:45Z`，resend 说明 + 正文原样在档）；**尚无任何维护者回复**（补发已 19.8 h） | 归档 `02:23:45Z` | **无** | 无需（在等待窗口内） |
| E | **M10 fastrpc 换址补发**（→ `srini@kernel.org` + Dmitry 现址） | lore arm-msm | **已归档**（`02:23:38Z`）；**尚无维护者回复**（补发已 19.8 h；v3 本体已 14.8 天） | 归档 `02:23:38Z` | **无** | 无需 |
| F | **M11 pstore ping**（Kees Cook） | lore `/all/` | **ping 已归档**（`09:07:26Z`）；线程 4 封（cover+1/2+2/2+ping），**Kees 仍未回**（v1 静默 9.8 天，ping 后 13 h） | ping `09:07:26Z` | **无** | 无需（按 ping 正文承诺：这是唯一一封 ping） |
| G | **aw86927 v4**（linux-input + devicetree） | lore feed（原始 XML 计数） | **零回复**：linux-input 仍 146 条、顶 = v4 6/6（`04:50:54Z`）；devicetree 144 条、顶同；静默 **≈41.4 h**（sashiko 对 v3 是 13 min 级响应，对 v4 持续静默） | 顶条 `11-24T04:50:54Z` | **无** | 无需（等评审窗口） |
| H | **wl2868c**（进 regulator for-7.5 后） | git.kernel.org broonie log + lore | **无 follow-up**：for-7.5 上 wl2868c 之后只有他人无关提交（Jesse Casco qcom-rpmh 7 天、Zhu Jun qcom_usb_vbus 36 h）；lore 侧 Mark Brown「Applied」(11-17) 后无新讨论 | log 现查 `22:1xZ` | **无** | 无需（等 7.5 合并窗口） |
| I | **re-venkat Tested-by 回信** | lore linux-pm | **昨轮「摄取未到」已解除：已归档**（`08:14:16Z`，linux-pm feed 命中，MID `179559445186.3708843.5599816201468147145@mail.ustc.edu.cn`）；Venkat/Sre 尚无回复 | 归档 `08:14:16Z` | **无** | 无需 |
| J | **phosh !2005** | gitlab.gnome.org | **本轮无法核验**：匿名 API 直连/走代理均 **HTTP 406**，网页 = 「Client Challenge」图片 CAPTCHA，keyring token 被锁取不出。沿用基线最后已知态：`opened`·notes 2·最新人类 note = guidog `11-14T13:12Z` | 尝试 `22:0xZ` | **未知** | 需用户解锁 keyring（见 §3-1） |
| K | **Mobian droid-juicer !46** | gitlab.com API v4（匿名） | `opened` · notes **0** · `sha=ea9fe3d5` · pipeline `success` · `updated_at=2026-11-23T11:10:29Z`（**已 59 h 零变化**） | 复核 `22:0xZ` | **无** | 无需（等维护者） |

**结论行**：增量内**需要我方回应的新评审只有 1 条** = C 行 Krzysztof 对 elden v8 2/2 的意见（sashiko 两条 [Medium] 均已在 cover 预先声明，回应时逐条点名即可）。**昨日遗留①已有结论**：两个死地址均已换现址补发并进档（D/E 行），但**「被读到」尚无证据**（两人均未回复，也因 IMAP 被挡无法查新退信）。**昨日遗留②（IMAP 冻结）本轮无法复核**，判据与解锁条件见 §2.8。

---

## ② 逐条证据

### 2.1 IMAP 增量——本轮认证通道被挡（错误码如实记录）

- 尝试链：`/tmp/b4_scan.py`（BODY.PEEK 只读版，INBOX + `"Junk E-mail"` + `"Sent Items"`，SINCE 24-Nov-2026）
  → **TCP/banner 正常**：`* OK Coremail System IMap Server Ready(ustccn[bde7d37c…])`（`mail.ustc.edu.cn:993` 可达）。
- **LOGIN 失败**：凭据在 GNOME keyring（唯一现有通道），而 **Login collection 处于锁定态**：
  - `python keyring.get_password('smtp', …)` → `keyring.errors.KeyringLocked: Failed to unlock the collection!`；
  - `git credential fill`（helper = `~/.local/bin/git-credential-keyring`）→ `fatal: could not read Password for 'smtp://…': 没有那个设备或地址`；
  - `secretstorage` 列举：`/org/freedesktop/secrets/collection/login locked=True`（session collection 空）；
  - 根因（`loginctl`）：会话里只有 **gdm-greeter**（seat0, tty1），**用户未登录图形会话** ⇒ 解锁提示无 SystemPrompter 可应答
    （`git-credential-keyring` 文件头已记过同一模式，2026-11-17）。
- **结论**：本轮收件侧 0 封可核；**不编状态**。该事实同时决定 §2.8（冻结复核）与 J 行（phosh token）。

### 2.2 dwc3 v16 —— 首次「零缺陷」评审（内容级新状态）

- **linux-usb**：线程页 `…/linux-usb/20261125142309.3265777-1-…/T/`：cover `2026-11-25 14:23` Qianhui Xu，
  `To: Thinh.Nguyen@synopsys.com`，`Cc: gregkh, linux-usb, robh, krzk+dt, conor+dt, devicetree, linux-arm-msm, linux-kernel`
  ⇒ **Greg 上轮要求的「补 usb 列表」本代已落实**；`0 siblings, 4 replies; 5+ messages` = 3 枚补丁 + **sashiko 1 封**，无 Greg/Thinh 回复。
- **sashiko `2026-11-25T14:36:14Z`**（投出后 **13 min**，与其历史响应节奏一致）原文：
  > Sashiko has reviewed this 3-patch series and found no issues.
  （链接 `sashiko.dev/#/patchset/20261125142309.3265777-1-…`）—— v12→v15 连吃 4+2+3 条意见后，**v16 首次全绿**。
- **linux-devicetree**：`?q=20261125142309` 命中 `[v16 3/3]`（`14:23:25Z`）⇒ 副本列表已摄取。
- **patchwork 旁证**（摄取正常，`state` 噪声照旧不作判据）：project 363（linux-usb）`[v16,1/3]`/`[v16,3/3]` = `new`（`14:23:07/09Z`）；
  project 429（devicetree）同两枚 = `needs-ack`/`handled-elsewhere`。`commit_ref` 全空 = 无合并证据（不构成「未合并」证据，沿用 §7 口径）。
- **我方动作**：无。等 Thinh/Greg 实质回复；sashiko「no issues」不需要回。

### 2.3 M8 / M10 换址补发 —— 已进档、暂无回音（昨日遗留①结论：补发 ✓，「被读到」未证实）

- **M8（mdss v5 说明信）**：`…/linux-arm-msm/?q=20261125022333` 命中 `Re: [PATCH 1/3] …mdss-common: describe additional block resets`，
  `2026-11-25T02:23:45Z`。头部 resend 说明逐字在档：
  > [Resend - delivery only. The 2026-11-24 15:15 UTC copy of this message bounced for one Cc address, dmitry.baryshkov@linaro.org ("address not found"). It is replaced below with the address that reviewer currently posts from. Nothing else changed.]
  正文 = sashiko [Low] 0xa000 归属更正 + 问「v6 现在出是否欢迎 / 要不要先 rebase 到 master」。
  线程检索（`?q="describe additional block resets"`）**最新条目 = 该补发本身** ⇒ Dmitry/Konrad/Abel 均未回复（补发后 19.8 h）。
- **M10（fastrpc v3 ping）**：`?q=20261125022328` 命中 `Re: [PATCH v3] …non-secure domain`，`02:23:38Z`，resend 说明列明两个死地址
  （`dmitry.baryshkov@linaro.org` + `srinivas.kandagatla@linaro.org`）已换现址；线程检索最新 = 补发本身 ⇒ 无回复。
- **「被读到」的判据与现状**：lore 侧唯一可证「读到」的形式 = 维护者回信 ⇒ **本轮 0**；新退信（若有）只能经 IMAP 查 ⇒ 本轮被 §2.1 挡住。
  按正常评审节奏（M8 v5 已 12.7 天、M10 v3 已 14.8 天），**不需要二次 ping**，本 lane 下轮再查。
- 附带事实：11-24T15:15Z 原版两封仍在档（`15:15:48/50Z`），即列表读者看到的是「原版 + resend」两份同文；与上轮口径一致。

### 2.4 elden 板 DTS v8 —— **增量内唯一需要我方回应的评审**

- 归档：`?q=20261125091309` 在 **linux-arm-msm**（cover `09:13:16Z` + 2/2 `09:13:25Z`）与 **linux-devicetree**（2/2 命中）均命中。
- **sashiko `2026-11-25T09:19:45Z`（2/2，2×[Medium]）**：
  1. `undocumented willsemi,wl2868c compatible in pmic@2f` —— **已被 cover 预先声明**（binding+driver 已进 regulator for-7.5 = `84e67d2ee13f`/`602f57223457`，只是 7.4-rc3 基线没有，dtbs_check 因此报 1 条，cover「Known dependencies」原文写明）；
  2. `missing core boot and power nodes`（SPMI PMIC / RPMh regulators / console / storage）—— 同样是 cover「What is in here, and what is not」+ v6 遗留声明过的点。
  ⇒ **无新信息，但回 v9 时应逐条点名回应**（口径：两者都已声明，待 7.5 bind 进树 / 后续系列补节点）。
- **Krzysztof Kozlowski `2026-11-25T12:03:11Z`（2/2）**原文：
  > Your changelog or cover letter should be explicit about waiting on bindings, instead of wall of text.
  ⇒ **这是实质写作要求**：v9 的 2/2 changelog（或 cover）必须显式写「2/2 等 willsemi,wl2868c binding 进树后再合入/顺序」，并把 v8 cover 里埋在长文里的该句提到显眼位置。**待办：elded v9 起草时落实（`patches/upstream/elden-dts-v9-prep-20261124/` 备料已在）**；本 lane 只报不写。

### 2.5 M11 pstore ping —— 已归档，Kees 未回

- `…/all/179559762994.96050.5409562801088468974@mail.ustc.edu.cn/T/` → 线程根 = v1 cover（`2026-11-16 4:00`），`4+ messages` = cover+1/2+2/2+**ping**；
  ping 正文（三问：层级 / Cc stable / 模块化限制）全文在档，`2026-11-25T09:07:26Z`。
- **无 Kees/Tony/Guilherme 回复**。ping 自带「this is the only ping unless you would like another」承诺 ⇒ **不再追加**。

### 2.6 aw86927 v4 —— 零回复（41.4 h）

- linux-input：原始 atom（重试 + `<?xml` 校验，规避上轮记过的挑战页假阳性）`<updated>2026-11-25T21:25:18Z`、**146 条**（与基线同数）、
  顶部 = `[PATCH v4 6/6]`（`11-24T04:50:54Z`），下一条 = sashiko 对 v3（`11-24T02:03:12Z`）。
- linux-devicetree：144 条、顶 = v4 6/6（`04:50:54Z`）。
- ⚠ 工具事实：Firecrawl 渲染该查询时返回了**过期缓存页**（顶部像 11-24），以 lget 原始 XML 为准——下一轮别用 web_fetch 判 aw86927 的 feed 时效。

### 2.7 wl2868c / re-venkat —— 均无新动态

- **wl2868c**：`broonie/regulator.git for-7.5` log 现查：`0216753490ff`（合并提交）+ `84e67d2ee13f`/`602f57223457`（合入件）之后
  仅两枚**无关**新提交（Jesse Casco qcom-rpmh 7 天前、Zhu Jun qcom_usb_vbus 36 h 前）⇒ **无 revert/fixup/follow-up**；
  lore 侧 Mark Brown「Applied」邮件（`11-17T18:19Z`）后无新讨论。状态不变：等 7.5 合并窗口。
- **re-venkat**：`…/linux-pm/?q="Apply the USB host current limit early"` 命中我方 Tested-by 回信 `2026-11-25T08:14:16Z`
  （完整 MID `179559445186.3708843.5599816201468147145@mail.ustc.edu.cn`，与 `reports/m12-upstream-test-20261125.md` §记录逐字一致）
  ⇒ 昨轮「lore 摄取未到」**已解除**；Venkat/Sre 尚无回复。
  ⚠ 检索事实：`/all/?q=179559445186` 仍「No results found」（索引滞后），**按列表 feed/线程查询才算数**。

### 2.8 IMAP 存储层冻结（昨日遗留②）—— 本轮无法复核；复核判据如下

- **本轮状态：未证实 / 未复核**（不是「仍冻结」也不是「已解冻」）——认证通道被挡（§2.1），收件三夹层一个都看不了。
- **间接证据（不改变结论，只列事实）**：出站路径在窗口内全程正常（M8/M10 02:23Z、re-venkat 08:14Z、M11 ping 09:07Z、elden v8 09:13Z、v16 14:23Z 五批全部 250 + lore 归档）；IMAP 服务进程存活（banner 正常）。冻结是**收件存储/投递层**的口径，出站正常与它不矛盾。
- **给下一轮的复核判据**（用户解锁后一次跑完）：
  1. 对 INBOX / `"Junk E-mail"` / `"Sent Items"` 各记：`SELECT`/`SEARCH` 返回码 + `SINCE 25-Nov-2026` 命中数 + **最后一封的 Date 时间戳**（脚本 `/tmp/b4_scan.py` 已备好，输出含每夹层 `## …: LAST=…` 行）；
  2. **解冻判据**：任一夹层出现 `Date ≥ 2026-11-25T03:44Z` 的新件（尤其 Sent Items 里应补现的 08:14Z/09:07Z/09:13Z/14:23Z 四批实发件——若 Sent 仍缺它们 = 冻结仍在）；
  3. **服务端返回码**：`select=OK/search=OK` 且命中数为 0 才能说「服务端确认无新件」；任何 `NO/BAD` 原样记入报告；
  4. 若 Sent Items 长期缺这四批件，属「发送后本机 Sent 副本丢失」，与 lore 归档并行不悖（lore 已是送达证据），此时冻结只影响**收件可见性**，不影响投递面。
- 本轮已落盘的失败现场：`/tmp/b4_scan_20261126.txt`（2 行：banner + keyring 错误）。

### 2.9 phosh !2005 —— 本轮双通道被挡（错误码如实记录）

- 匿名 API（直连与 `-x 127.0.0.1:7890` 代理各试）→ **HTTP 406**（连 `-A Firefox UA + Accept: application/json` 仍 406）；
  web_fetch API URL → 三后端全败（Tavily/AnySearch/Firefox 500）；MR 网页 → **「Client Challenge」图片 CAPTCHA**（headless 不能也不应代答）；
  token 通道 = keyring（锁定，§2.1）⇒ **三条路全断，不编状态**。
- 沿用基线最后已知态（11-25 01:2xZ 复核）：`opened` · `mergeable` · notes 2 · `sha=5300355a` · pipeline `manual/Blocked` ·
  最新人类 note = guidog `2026-11-14T13:12Z`。**下轮解锁后先补一次现查再下结论。**

### 2.10 Mobian droid-juicer !46 —— 无变化

- `GET /api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46`（匿名，gitlab.com 侧正常）：
  `state=opened` · `user_notes_count=0` · `sha=ea9fe3d5c3bb…` · `head_pipeline.status=success` · `updated_at=2026-11-23T11:10:29.562Z`
  ⇒ **59 h 零变化**（上轮 38.1 h）。无需动作。

---

## ③ 三分类（本 lane 视角）

**需动作（1 件，均不需本轮发信）**
1. **elden v9 写作项**：吸收 Krzysztof `12:03:11Z`（changelog/cover 显式写「waiting on bindings」）+ sashiko 两条 [Medium] 逐条点名
   （两条都已在 v8 cover 声明过，回应成本≈几行）。备料在 `patches/upstream/elden-dts-v9-prep-20261124/`；属 lane A/B 的活，本 lane 只登记。

**需用户（1 件）**
- **解锁图形会话 / keyring**（登录一次 GDM 即可）：解锁后三件事一起恢复——① IMAP 收件增量与冻结复核（§2.8 判据）；② phosh !2005 token 现查；③ 查 M8/M10 补发有无新退信。错误现场已存 `/tmp/b4_scan_20261126.txt`。

**可等（其余全部）**
- dwc3 v16：sashiko 全绿，等 Thinh/Greg；aw86927 v4（41 h）、M8/M10 补发（19.8 h）、M11 ping（13 h，承诺唯一一封）、wl2868c（等 7.5 窗口）、droid-juicer !46（59 h）、re-venkat（等 Venkat/Sre）。

---

## ④ 检索式 / 命令 / 访问时间（可复现）

访问窗口 2026-11-25 22:0x–22:1xZ；全部命令 `timeout -k`。

```bash
# 0) IMAP（被挡，现场已存）
timeout -k 5 420 python3 /tmp/b4_scan.py 2>&1 | tee /tmp/b4_scan_20261126.txt
#   → banner OK(Coremail)；keyring.get_password → KeyringLocked；git credential fill → could not read Password
python3 -c "import secretstorage; [print(c.collection_path, c.is_locked()) for c in secretstorage.get_all_collections(secretstorage.dbus_init())]"
#   → /org/freedesktop/secrets/collection/login locked=True；loginctl = gdm-greeter 在 seat0

# 1) lore（web_fetch=Firecrawl 直渲染；atom 用 /tmp/lget.py 重试+<?xml 校验）
web_fetch 'https://lore.kernel.org/linux-usb/20261125142309.3265777-1-xiaqinghuan@mail.ustc.edu.cn/T/'          # v16 线程 5 封
web_fetch 'https://lore.kernel.org/linux-devicetree/?q=20261125142309&x=A'                                       # v16 3/3 摄取
web_fetch 'https://lore.kernel.org/linux-usb/?q=%22two+connectors+sharing+one+HS%22&x=A'                         # sashiko no-issues 14:36:14Z
timeout -k 5 120 python3 /tmp/lget.py 'https://lore.kernel.org/linux-input/?q=aw86927&x=A' /tmp/b4_input_aw.xml  # 146 条，顶=v4 6/6
timeout -k 5 120 python3 /tmp/lget.py 'https://lore.kernel.org/linux-devicetree/?q=aw86927&x=A' /tmp/b4_dt_aw.xml # 144 条
web_fetch 'https://lore.kernel.org/linux-arm-msm/?q=20261125022333&x=A'                                          # M8 补发在档
web_fetch 'https://lore.kernel.org/linux-arm-msm/?q=20261125022328&x=A'                                          # M10 补发在档
web_fetch 'https://lore.kernel.org/all/179559762994.96050.5409562801088468974@mail.ustc.edu.cn/T/'               # M11 ping 线程 4 封
web_fetch 'https://lore.kernel.org/all/?q=wl2868c&x=A'                                                           # elden v8 + Krzysztof/sashiko
web_fetch 'https://lore.kernel.org/linux-pm/?q=%22Apply+the+USB+host+current+limit+early%22&x=A'                 # re-venkat 08:14:16Z 在档
web_fetch 'https://git.kernel.org/pub/scm/linux/kernel/git/broonie/regulator.git/log/?h=for-7.5'                 # wl2868c 无 follow-up

# 2) patchwork（Anubis PoW 经 /tmp/lget.py）
timeout -k 5 60 python3 /tmp/lget.py 'https://patchwork.kernel.org/api/1.2/patches/?project=363&q=dwc3&per_page=5&order=-date' /tmp/pw363b.json
timeout -k 5 60 python3 /tmp/lget.py 'https://patchwork.kernel.org/api/1.2/patches/?project=429&q=dwc3&per_page=5&order=-date' /tmp/pw429b.json

# 3) GitLab
timeout -k 5 60 curl -sS -m 50 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'   # OK（匿名）
timeout -k 5 60 curl -sS -m 50 -o /tmp/phosh.json -w '%{http_code}\n' \
  'https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphosh/merge_requests/2005'                          # 406（直连/代理/UA 均试）
web_fetch 'https://gitlab.gnome.org/World/Phosh/phosh/-/merge_requests/2005'                                    # → Client Challenge CAPTCHA
```

---

## ⑤ 工具事实（给下一轮省时间）

1. **Firecrawl 会返回过期缓存页**：aw86927 linux-input 查询首次渲染顶部时间戳是 11-24（实际 feed `updated=11-25T21:25Z`）。
   **feed 时效判定必须用 lget 原始 XML**（成功判据 = `<?xml` 开头），web_fetch 只用于线程页/直取。
2. **lore `/all/?q=<MID前缀>` 索引滞后**：re-venkat MID 在 `/all/` 搜不到、在 `/linux-pm/` 线程查询里在档 ⇒ 「No results」先换列表级查询再下结论。
3. **gitlab.gnome.org 对本机 IP 现在要求 CAPTCHA**（API 406 + 网页 Client Challenge）；上一轮（11-25 01:2x）同主机同代理还能匿名/带 token 访问。
   token 在 keyring，keyring 在 GDM 未登录时锁死 ⇒ **phosh 现查目前完全依赖「用户登录一次」**。
4. `/tmp/b4_scan.py` 是本轮新备的只读扫描器（比 e4_scan 多三夹层、每夹层 LAST= 与服务端码输出），解锁后直接跑即可。
5. 本轮未做：设备侧/上机（lane 边界）、任何发信/MR 推送、`TASKS/README.md` 与 `versions/` 修改、git commit。
