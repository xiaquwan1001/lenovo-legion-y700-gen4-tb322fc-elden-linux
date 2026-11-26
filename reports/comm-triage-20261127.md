# 通信复扫 D10（2026-11-26T05:55Z → ≈22:0xZ）— 只读

> **只读纪律**：本文件是本轮唯一写入；未发信、未回信、未推 MR、未改 `TASKS/`、未 `git commit`。
> **增量基线** = `reports/comm-triage-20261126-d11.md`（覆盖到 **2026-11-26T05:55Z**）。
> **访问时刻（推定）** = `2026-11-26T22:02:38Z`：依据 = 本轮首次取 dwc3 v16 线程 atom 时 feed 的 `<updated>` 字段；
> 本机**无 shell**（本轮工具集仅 `read`/`write`/`web_fetch`/`web_search`），不能 `date -u` 现查，故标"推定"。
> **本轮能力缺口（先说，影响判读）**：**IMAP 面完全未核**——没有 shell 就无法跑 `d11_scan.py` 类脚本、`keyring` 取值与 `imaplib`。
> 因此**「新退信数」本轮为空缺，不是 0**。下文每个面都明确写「实测」或「抓取失败 + 错误码」。

---

## ① 增量表

| 面 | 最新人类活动时间 | 条数（窗口内新人类） | 是否需要动作 |
|---|---|---|---|
| **邮件 INBOX / Junk / Sent（IMAP）** | **未核** | **未核** | 需换有 shell 的 lane 重跑（见 §3-1） |
| lore · elden 板 DTS **v10** | **窗口内 0**（最后人类早于基线：Krzysztof `11-25T12:04:02Z` @ v8 线程） | 0 | 否（等 Bjorn/Konrad 取件） |
| lore · M6 DSI-PHY **v3** | **窗口内 0**（线程只有我方 1 封） | 0 | 否 |
| lore · dwc3 **v16** | **窗口内 0**（线程最后一封 = sashiko `11-25T14:36Z`） | 0 | 否（等 Thinh/Greg） |
| lore · M8 mdss v5 / M10 fastrpc v3 | **窗口内 0**（末封仍是我方 11-25 补发） | 0 | 否（补发 ≈45 h，满 7 天再议） |
| lore · M11 pstore | **窗口内 0**（末封仍是我方 `11-25T09:07Z` ping） | 0 | 否 |
| lore · aw86927 v4 | **窗口内 0**（末封仍是我方 `11-24T04:50Z`） | 0 | 否（**sashiko 也未审 v4**） |
| **gitlab.com/mobian1**（droid-juicer **!46** + 组内 MR） | **`2026-11-23T11:10:29Z`** | 0 | 否（勿催，≈83 h 零变化） |
| **salsa.debian.org/Mobian-team** | **抓取失败** | 未核 | 否（硬前置未变，见 §3-3） |
| **gitlab.gnome.org**（phosh !2005 / phoc #125 / phoc open MR） | **抓取失败** | 未核 | 否（等 guidog，勿催） |

一句话：**本轮在能抓到的所有 deque 上，新人类评审 = 0，新机器人评审 = 0，我方欠动作 = 0**（上一轮的 3 项都已在 v10 里办完/记账）；
唯一实质缺口是 **IMAP 退信面与两个 GitLab 实例抓不到**，都属工具能力，不属上游状态变化。

---

## ② 逐面明细（含判据）

### 2.1 lore：四个在飞系列的线程封数对账（实测）

**判据口径（与上轮一致）**：以 lore **线程页** `/all/<MID>/t/` 的「N messages in thread」+ 末封作者/时间为准；
响应对照上一份报告的封数——**封数不变即「窗口内无新封」**（比逐封列时间更不容易被截断误导）。

| 系列 | 线程 MID（cover/主件） | 封数 | 上一份报告封数 | 末封 | 判读 |
|---|---|---|---|---|---|
| elden v10 | `<20261126052057.1544590-1-…>` | **4** | 4（d11） | sashiko-bot `2026-11-26T05:30Z` | 无新封（图见下） |
| M6 DSI-PHY v3 | `<20261126052049.1544229-1-…>` | **1** | 新投 | 我方 `2026-11-26T05:20:49Z` | 「only message in thread」 |
| dwc3 v16 | `<20261125142309.3265777-1-…>` | **5** | 5（d11） | sashiko `2026-11-25T14:36Z` | 无新封 |
| M8 mdss v5 | `<20261125022333.680119-1-…>` | **13** | 13（d11） | 我方 `2026-11-25T02:23:45Z` | 无新封 |
| M10 fastrpc v3 | `<20261125022328.680070-1-…>` | **8** | 8（d11） | 我方 `2026-11-25T02:23:38Z` | 无新封 |
| aw86927 v4 | `<20261124045040.559317-1-…>` | **7** | 7（d11） | 我方 `2026-11-24T04:50Z` | 无新封；**v4 无 sashiko 评审** |
| M6 DSI-PHY **v2**（旧线程） | `<20261117052047.32129-1-…>` | **3** | 3（d11） | **Jianfeng Liu `2026-11-26T03:23Z`** | 早于基线，d11 已记 |
| M11 pstore | （无稳定 MID，d11 记 dry-run id） | 3（搜索口径） | — | 我方 `2026-11-25T09:07Z` | 无新封 |

**M6 v3 的实测证据（新线程，`/t/` 原文）**：

```
* [PATCH v3] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable
@ 2026-11-26  5:20 Qianhui Xu
  0 siblings, 0 replies; only message in thread
```

且该 v3 的 `Tested-by: Jianfeng Liu` **已写进补丁体本身**（不只是 changelog）——上轮「欠落账」一项就此结清：

```
Signed-off-by: Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>
Tested-by: Jianfeng Liu <liujianfeng1994@gmail.com>
---
Changes since v2: no code change; …only adds Jianfeng Liu's Tested-by…
```

**elden v10 的实测证据**：`/t/` 页 4 封，2/2 下唯一子节点是 `sashiko-bot @ 2026-11-26 5:30`，文本逐字 =
「Sashiko AI review found 2 potential issues」+ 两条 `[Medium]`（`missing willsemi,wl2868c binding schema in target tree` /
`missing core boot and power nodes in sm8750-lenovo-elden.dts`）——**与 d11 §3 记的同一封，无第二条**。
且 v10 cover 已把 v9 的三条 `[Medium]`（含 `vin*-supply` 那条真技术意见）逐条回应，并把
`vin12/vin34/vin5/vin7-supply` 补进 2/2 实体 diff ⇒ **上轮 §7-1「需用户裁决」的一项已被 v10 办掉**。

### 2.2 gitlab.com/mobian1（实测，公开 API，匿名可用）

`GET /api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46` 原始字段（本轮现查）：

```
state=opened  detailed_merge_status=mergeable  user_notes_count=0
sha=ea9fe3d5c3bb81c246b959c2f0c6ca6ca07c4c4d  draft=False  has_conflicts=False
created_at=2026-11-21T09:31:14.341Z   updated_at=2026-11-23T11:10:29.562Z
head_pipeline: 3102631920 success 2026-11-23T11:15:16.810Z
```

与 d11 §5.1 **逐字段相同** ⇒ 无新 note、无 CI 变化、无 force-push。
组级交叉核对 `GET /groups/mobian1/merge_requests?state=opened&order_by=updated_at&sort=desc`：
**列表第一条就是 !46（`updated_at 2026-11-23T11:10:29Z`）**，其后为 !45（`10-11`）、!22（`10-04`）、!35（`10-01`）、
!36（`09-03`）、callaudiod !30、tweakster !10 ⇒ **按 updated_at 排序，组内窗口内无任何 MR 被更新**。
（计数：响应被截断，只核到「≥7 条、首条=!46」，不写死总数。）

### 2.3 salsa.debian.org / gitlab.gnome.org：**抓取失败（如实记）**

| 目标 | 尝试 | 结果 |
|---|---|---|
| `salsa.debian.org/api/v4/groups/Mobian-team/merge_requests` | `web_fetch` auto + `exa` + `anysearch` + 本地 Firefox | 返回 **`/.internal/challenge.html`**（Anubis proof-of-work，页面文字「I Challenge Thee … Verified! ✅」），**未取得任何 JSON**；`exa` 返回空、`anysearch` = HTTP 422 |
| `gitlab.gnome.org/api/v4/projects/16747/merge_requests/2005` | `web_fetch` auto | Firecrawl **HTTP 402**、Tavily 失败、AnySearch **HTTP 422**、Firefox **HTTP 500**（"page rendered but yielded no text"） |
| `gitlab.gnome.org/World/Phosh/phosh/-/merge_requests/2005`（网页） | 本地 Firefox | **CAPTCHA**：标题 "Client Challenge"，「Enter the characters seen in the image below」 |

⇒ **phosh !2005 / phoc #125 / phoc open MR 数本轮一律未核**，不沿用旧值当新值。
（上一份报告的通道口径「`-x http://127.0.0.1:7890 -A 'git/2.0'` + token」需要 shell + keyring，本轮两者都没有。）

### 2.4 IMAP：**结构性不可达**

无 shell ⇒ 无法 `imaplib` + `keyring`，无法选箱/`BODY.PEEK`/`INTERNALDATE`。
**本轮「新退信数」与「维护者直投 INBOX 的新回信」两个字段为空缺。**
（上轮已实证：`b4-reply` 类评审回信本来就不进我们 INBOX，因此**评审面用 lore 判即可**；缺口只在**退信（DSN）**这一项。）

---

## ③ 需要用户干预

| # | 事项 | 为什么需要人 | 建议动作 |
|---|---|---|---|
| 1 | **退信（DSN）面本轮完全空白** | 本 lane 的工具集只有 HTTP，没有 shell/IMAP；不是上游无事，是**看不见** | 下一轮把 IMAP 面派给**有 shell 的 lane**（复用 `d11_scan.py` 口径：`BODY.PEEK` + `readonly=True`，窗口 `SINCE 26-Nov-2026` 起、按 `INTERNALDATE > 2026-11-26T05:55Z` 切增量）。若用户希望本 lane 长期承担 D10，给本 lane **bash 权限**即可一轮闭环 |
| 2 | **gitlab.gnome.org 两件（phosh !2005 / phoc #125）未核** | CAPTCHA + 无 token | 要么提供 `gitlab.gnome.org` token（`secret-tool` 里已有的那条，需 keyring 解锁），要么授权用**有头 Firefox**（`touch ~/pi-firefox/headed`）过 CAPTCHA |
| 3 | **salsa Mobian-team 未核** | Anubis PoW 挡 API | 走 **git 协议**读仓库（`git ls-remote`/浅克隆看分支与分支头时间）比 API 更省事；或真实浏览器会话 |
| 4 | 其余**无需干预** | 各系列都只是「等维护者」 | — |

> 明确**不需要**用户做的事：elden v10 的 `vin*-supply` 裁决（已在 v10 办掉）、M6 `Tested-by` 落账（v3 补丁体已带）、
> elden 1/2 的 `Acked-by`（v10 1/2 已带 `Acked-by: Krzysztof Kozlowski`，见 §2.1 附的 1/2 正文）。

---

## ④ 工具事实（给下一轮省时间，均为本轮实测）

1. **`lore-kernel.gnuweeb.org` 是 lore 的免 Anubis 镜像**，URL 形状与 lore 一致（`/<list>/<MID>/t/`、`/t.atom`）⇒
   本会话 lore 被标记后（默认走 Firefox 撞 Anubis 时），改用它或显式 `provider=anysearch` 都能取到线程页。
2. **lore 的 `?q=…&x=A`（atom 搜索）会被 Anubis 挡**；`/all/?q=…` 的 HTML 搜索结果页可以取（拿到日期与作者，**拿不到 MID**）。
   要 MID 时用搜索引擎反查（本轮据此拿到 M6 v3 的 `<20261126052049.1544229-1-…>`）。
3. **`patchwork.kernel.org/api/1.2/…` 本轮被 Anubis 挡**（返回 PoW 页）⇒ patchwork 摄取旁证本轮未取；
   不影响判据（`commit_ref` 本来就不作证据）。
4. **gitlab.com 公开项目 API 匿名可读**（`user_notes_count`、`updated_at`、`head_pipeline` 都在主对象里，不必查 `/notes`）。
5. 本轮未做（lane 边界）：设备侧/上机、任何发信/MR 推送、`TASKS|INDEX|DEVICE|RESOURCES|PITFALLS|AGENTS` 与既有报告的修改、`git commit`。

---

## ⑤ 复盘命令（本轮实际用的，全部只读）

本轮**无 shell**，等价操作为 HTTP 取页；给下一轮有 shell 时的复现：

```bash
# A) lore 线程封数对账（任一可用通道）
for mid in 20261126052057.1544590-1 20261126052049.1544229-1 \
           20261125142309.3265777-1 20261125022333.680119-1 \
           20261125022328.680070-1 20261124045040.559317-1; do
  curl -sS -A 'Mozilla/5.0' "https://lore-kernel.gnuweeb.org/all/$mid-xiaqinghuan@mail.ustc.edu.cn/t/" \
    | grep -E 'messages in thread|only message in thread'
done
# B) GitLab（匿名可用的两面）
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
curl -sS 'https://gitlab.com/api/v4/groups/mobian1/merge_requests?state=opened&order_by=updated_at&sort=desc'
# C) IMAP（本轮缺失项，下一轮必做）
timeout -k 5 420 python3 /tmp/d11_scan.py   # 复制 d11 脚本，把增量切点改成 INTERNALDATE > 2026-11-26T05:55Z
```
