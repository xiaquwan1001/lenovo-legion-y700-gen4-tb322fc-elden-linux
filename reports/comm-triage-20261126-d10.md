# D10 通信 lane 复扫（2026-11-25T11:25Z → 2026-11-26T04:20Z）— 只读

> **只读纪律**：本文件是本轮**唯一**写入；未发信、未回信、未推 MR、未改 `TASKS/`、未 `git commit`、未改动任何既有报告。
> 外部命令一律只读（IMAP 全 `BODY.PEEK` + `readonly=True` 选箱，不改已读态；凭据运行时从 keyring 取，未落盘）。
> **文件关系（重要）**：`reports/comm-triage-20261126.md` 已被 **B4 lane 于 2026-11-25 22:1xZ** 占用（覆盖到 22:11Z，其中 IMAP 与 phosh 两面明确记为「被挡、未核」）；本文件是**同日 D10 的第二轮**，不复用其路径以免覆盖他人报告。
> 增量基线 = `reports/mobian-phosh-upstream-20261125.md`（覆盖到 **2026-11-25T11:25Z**）；与 B4 重叠段以本轮现查值为准，**B4 未核的两面（IMAP / phosh）本轮已核**，并补上 B4 漏看的一封人类信（§3.1）。
> 访问时刻：**2026-11-26T04:02Z–04:20Z**（`date -u` 现查）。
> 判据口径不变：① 只认「维护者/评审人可读的回信」+「维护者树 / linux-next **内容级**」；② patchwork `state`/`commit_ref` 只作摄取旁证，**`commit_ref` 空不构成任何证据**。

---

## ① 头条数字

| 指标 | 值 | 明细 |
|---|---|---|
| **本轮新人类消息** | **3 封 / 2 人** | Krzysztof Kozlowski ×2（对 elden v8：**1 条评审意见** `12:03:11Z` + **1 个 `Acked-by`** `12:04:02Z`）、Jianfeng Liu ×1（M6 DSI-PHY v2 的 **`Tested-by`**，`11-26T03:23:15Z`） |
| **机器人消息** | **2 条**（均 sashiko） | dwc3 **v16** 系列：**"found no issues"**；elden **v9 2/2**：**3×`[Medium]`（其中 1 条是新增技术意见）** |
| **我方欠动作** | **3 项** | 1 项需裁决（elden `vin*-supply`）、2 项记账（`Tested-by` 落账 / `Acked-by` 台账）；**无「不办就卡住」的新代码动作** |
| **IMAP 冻结** | **已解除**（B4 的「未核」就此结案） | INBOX 天花板 `2026-11-26T03:23:29Z`；昨天记的冻结点 = `2026-11-25T03:44:39Z` |

一句话：**本轮首次出现人类评审输出**——binding 拿到了 `Acked-by`（9 小时后发的 v9 未带该 trailer，见 §3.1），外部第三方给了 `Tested-by`；dwc3 v16 机器人清零。**没有需要立刻回信的意见**：Krzysztof 的两条已被 v9 覆盖，`Tested-by` 只欠落账与致谢。

---

## ② A 面：邮件 INBOX / Junk / Sent 增量

### 2.1 判据命令与原始输出（冻结是否解除）

```bash
timeout -k 5 420 python3 /tmp/d10_scan_1126.py     # 本轮脚本：STATUS + 各箱最后一封 INTERNALDATE + 增量头
```

原始输出（逐字）：

```
STATUS INBOX OK "INBOX" (MESSAGES 10433 UIDVALIDITY 1)
SINCE 25-Nov: 160 msgs INBOX
LAST INTERNALDATE in INBOX = 2026-11-26T03:23:29Z | Re: [PATCH v2] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first 
STATUS "Junk E-mail" OK "Junk E-mail" (MESSAGES 216 UIDVALIDITY 5)
SINCE 25-Nov: 23 msgs "Junk E-mail"
LAST INTERNALDATE in "Junk E-mail" = 2026-11-25T18:28:56Z | Re: [PATCH v3 2/7] camss: Add camss utility functions
STATUS "Sent Items" OK "Sent Items" (MESSAGES 370 UIDVALIDITY 3)
SINCE 25-Nov: 9 msgs "Sent Items"
LAST INTERNALDATE in "Sent Items" = 2026-11-26T00:22:06Z | [PATCH v9 1/2] dt-bindings: arm: qcom: document the Lenovo Legion Y700
total rows after cut 2026-11-25T11:25:00+00:00: 39
```

**判读：存储层已解冻。** 三箱天花板全部晚于昨天记的 `2026-11-25T03:44:39Z`：INBOX 新到 `2026-11-26T03:23:29Z`（≈+23.6 h）、Junk `2026-11-25T18:28:56Z`、Sent `2026-11-26T00:22:06Z`（= 我方 v9 三封的入档副本，**证明「发送后本机 Sent 副本丢失」也已恢复**，B4 §2.8 判据 4 的疑虑一并排除）。
⇒ 昨天那条「IMAP 存储层冻结（需用户核配额/反垃圾）」**结案，无需用户处置**；B4 的「keyring 锁死 + 未核」也不再成立（本轮 keyring 正常可取，见 §9-2）。

**一处口径差异（据实记，不影响判据）**：昨天记 `STATUS INBOX (MESSAGES 19435)`，本轮同一命令返回 **10433**。差值 ≈9000 未取到解释（非本轮动作）。本轮判据以 **INTERNALDATE 天花板**为准，不依赖 MESSAGES 计数。

### 2.2 增量逐条（39 封，按类别）

| 类别 | 封数 | 说明 |
|---|---|---|
| 我方（Sent 副本） | 7 | dwc3 v16 四封 `2026-11-25T14:23:10Z–14:23:21Z`；elden v9 三封 `2026-11-26T00:22:04Z–00:22:06Z` |
| 对我们线程的机器人来信 | 2 | `sashiko-outbox-233571`（`11-25T14:36:20Z`，dwc3 v16 cover）、`sashiko-outbox-234477`（`11-26T00:31:19Z`，elden v9 2/2） |
| 对我们线程的**人类**来信 | **1** | `Jianfeng Liu <liujianfeng1994@gmail.com>`，`11-26T03:23:29Z`，`In-Reply-To <20261117052047.32129-1-…>`（M6 DSI-PHY v2） |
| 退信（DSN） | 1 | `postmaster@mail.ustc.edu.cn` `11-25T14:19:58Z`，`X-CM-Original-Message-ID: <piliplus-inquiry-20261125@mail.ustc.edu.cn>`，`Final-Recipient: githubaccount56556@proton.me`，`Status: 5.0.0 / Diagnostic-Code: SMTP; rcpt handle timeout … proton.me MX query return retry` ⇒ **与本 lane 无关（个人 PiliPlus 询问信）**，不是内核投递事故 |
| 他人线程 | 28 | 全为 libcamera/rkisp1 与 camss 他人系列；`bod@kernel.org 11-25T15:46:54Z` 是回给 Jizhou Tong（我们仅在 Cc） |

**投递面结论**：本轮 **0 退信涉及我方内核信**（M8 的 `abel.vesa@linaro.org`、M10 的 `srinivas.kandagatla@linaro.org` 两处死地址问题未复现，因本轮我方只发了 dwc3 v16 与 elden v9；两封的 Cc 均无 `@linaro.org` 死地址）。

### 2.3 新增人类信原文（Jianfeng Liu）

```
Subject: Re: [PATCH v2] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable
From: Jianfeng Liu <liujianfeng1994@gmail.com>   Date: Thu, 26 Nov 2026 11:23:15 +0800
In-Reply-To: <20261117052047.32129-1-xiaqinghuan@mail.ustc.edu.cn>

Tested-by: Jianfeng Liu <liujianfeng1994@gmail.com>

I can confirm this patch fixes DSI panel on my Xiaomi Pad 5 Pro. Thanks
for your work and I'm looking forward to it getting merged.

BTW I wonder if this mail is ignored by the mailing list because from this
link[1], I can see:
-- strict thread matches above, loose matches on Subject: below --
2026-11-17  5:20 [PATCH v2] " Qianhui Xu
And the mail from 11-17 doesn't have a subject.
[1] https://lore.kernel.org/linux-arm-msm/20261116150334.78710-1-xiaqinghuan@mail.ustc.edu.cn/
```

判读：**`Tested-by`，第三方独立板（小米 Pad 5 Pro）**，是本条 1 行修复的首个外部背书，v3/合并时需落账（§7-2）。
他附带「11-17 那封没有 Subject」**经查不成立**——归档副本 Subject 完好：

```bash
timeout -k 5 200 python3 /tmp/lget.py 'https://lore.kernel.org/all/20261117052047.32129-1-xiaqinghuan@mail.ustc.edu.cn/raw' /tmp/dsiphy_raw.txt
grep -n '^Subject:\|^Message-ID:' /tmp/dsiphy_raw.txt
# 56:Subject: [PATCH v2] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable
# 58:Message-ID: <20261117052047.32129-1-xiaqinghuan@mail.ustc.edu.cn>
```
我们 v2 发过两次（`20261116150334.78710-1` 与 `20261117052047.32129-1`，正文相同、subject 前缀不同），他看到的应是 lore 线程页「loose match」区的显示 ⇒ **属显示/重复投递问题，不是归档损坏**。

### 2.4 通道事实（本轮新发现，影响「头条数字可信」）

**INBOX 不是评审回信的可靠通道**：Krzysztof 的两封（b4-reply，`To` 只有列表 + 维护者）**没有进我们的 INBOX**：

```bash
# INBOX / "Junk E-mail" / "Sent Items" 三箱逐条查
(SINCE "25-Nov-2026" HEADER In-Reply-To "20261125091309") -> INBOX 0 / Junk 0 / Sent 0
(FROM "krzk@kernel.org") -> INBOX 453        # 该地址历史信件在，只是这两封没到
```
⇒ **「INBOX 里没有回复」不能推出「没人回」**；人类回信只能以 lore 线程为判据（B 面即按此做）。这也是 B4 只用 lore 覆盖 C 面却漏掉 v8 1/2 那封 Acked-by 的直接原因（§3.1）。

---

## ③ B 面：lore 五个在飞系列 + 附带 M6 / aw86927

`timeout -k 5 600 python3 /tmp/d10_lore_1126.py`（逐个 `https://lore.kernel.org/all/<MID>/t.atom`，UA = 浏览器串；8 条线程 feed `updated 2026-11-26T04:06:48Z`）

| 系列 | 线程封数 | 末封 / 作者 | 本轮新增人类 | 机器人 |
|---|---|---|---|---|
| **dwc3 v16** `<20261125142309.3265777-1>` | **5**（4 我方 + 1） | `2026-11-25T14:36:14Z` sashiko | **0** | `sashiko-outbox-233571`：「**Sashiko has reviewed this 3-patch series and found no issues.**」 |
| **elden 板 DTS v9** `<20261126002157.1954799-1>` | **4**（3 我方 + 1） | `2026-11-26T00:31:11Z` sashiko | **0** | `sashiko-outbox-234477`：**3×`[Medium]`**（§3.2） |
| elden v8（已被 v9 取代） | 6 | `2026-11-25T12:04:02Z` Krzysztof | **2**（12:03:11Z / 12:04:02Z） | sashiko `232999`（09:19:45Z） |
| **M8 mdss reset v5 + 11-25 补发** `<20261125022333.680119-1>` | 13 | `2026-11-25T02:23:45Z` 我方补发 | **0** | 无 |
| **M10 fastrpc v3 + 11-25 补发** `<20261125022328.680070-1>` | 8 | `2026-11-25T02:23:38Z` 我方补发 | **0**（末人类仍是 Konrad `2026-11-09T14:16:46Z`） | 无 |
| **M11 pstore initrd-overlap ping** `<179559762994.96050.…>` | 4 | `2026-11-25T09:07:26Z` 我方 ping | **0** | 无 |
| aw86927 v4 `<20261124045040.559317-1>` | 7 | `2026-11-24T04:50:54Z` 我方 | **0**（静默 ≈47.5 h） | 无 |
| M6 DSI-PHY v2 `<20261117052047.32129-1>` | 3 | `2026-11-26T03:23:24Z` **Jianfeng Liu** | **1**（`Tested-by`） | 无 |

### 3.1 elden v8 的人类评审原文（本轮唯一「新评审意见」+ 一个 Acked-by）

```bash
# 取法：t.atom 取回整线程，再按 link/@href 命中该 MID 的 entry 取 content（curl 直取 200，无需 Anubis）
curl -sS -A 'Mozilla/5.0 …' 'https://lore.kernel.org/all/179560823932.84329.556031734688243707.b4-reply@b4/t.atom'
```

- **`<179560818867.84329.911396338614062552.b4-reply@b4>`**，`2026-11-25T12:03:11Z`，Re: **v8 2/2**：
  > Your changelog or cover letter should be explicit about waiting on bindings, instead of wall of text.
- **`<179560823932.84329.556031734688243707.b4-reply@b4>`**，`2026-11-25T12:04:02Z`，Re: **v8 1/2**：
  > Acked-by: Krzysztof Kozlowski <krzysztof.kozlowski@oss.qualcomm.com>

**两条都已被 v9 覆盖**：v9 cover 第 12 行专节 `Waiting on bindings`（`patches/upstream/elden-dts-v9-20261126/SENT.md`、`reports/dts-v9-prep-20261126.md` 已记；B4 §2.4 只看到 2/2 那条，**1/2 的 Acked-by 是本轮新增事实**）。
**但 `Acked-by` 没有进 v9 1/2 的补丁体**（Ack `12:04Z` 早于 v9 投出 `00:22Z` 约 12 h）：

```bash
grep -c "Acked-by" patches/upstream/elden-dts-v9-20261126/v9-0001-*.patch   # -> 0
grep -c "Acked-by" patches/upstream/elden-dts-v8-20261125/v8-0001-*.patch   # -> 0
```
判读：技术上「应带未带」，**风险低**——`b4`/维护者按 lore 自取 `Acked-by` 是常规流程（我们统计 M8 的 R-b 也是同一机制）。**不建议为此重投 v10**；若真发 v10，补 trailer 并在 changelog 记一句即可。

### 3.2 elden v9 的 sashiko 3×`[Medium]`（2 旧 + **1 新**）

`sashiko-outbox-234477`，`2026-11-26T00:31:11Z`，三条标题逐字：

| # | 标题 | 新旧 | 内容要点 |
|---|---|---|---|
| 1 | `missing willsemi,wl2868c binding schema in target tree` | 旧（v8 已报） | cover 已声明依赖 `84e67d2ee13f`/`602f57223457`；**内容级已核实该 binding 在 `broonie/regulator.git for-7.5`/`for-next`（§4.2）** |
| 2 | `missing core boot and power nodes in sm8750-lenovo-elden.dts` | 旧（v8 已报） | cover「Not included, and not claimed to work」已写 |
| 3 | `missing vin*-supply properties on pmic@2f for active LDOs` | **新增** | 原文：`The willsemi,wl2868c binding and driver map LDO1/LDO2 to vin12-supply, LDO3/LDO4 to vin34-supply, LDO5 to vin5-supply, and LDO7 to vin7-supply, and only allow omitting an input supply when the board does not use the outputs it feeds.` |

判读：第 3 条是**真技术意见**（我们 LDO1–5、7 都在用，而 `pmic@2f` 只写了 `vsys-supply`）。⇒ 下一次发板件时应给 `pmic@2f` 补 `vin12/vin34/vin5/vin7-supply`。本轮不出 v10（无维护者要求、且 binding 已 Ack）——**要不要现在动由用户裁决**（§7-1）。

---

## ④ C 面：patchwork 摄取 + 内容级是否合入

### 4.1 patchwork（**只作摄取旁证**）

```bash
timeout -k 5 200 python3 /tmp/lget.py 'https://patchwork.kernel.org/api/1.2/patches/?project=<id>&q=<kw>&order=-date&per_page=N' /tmp/pw.json
# project id：linux-input=17、dri-devel=21、linux-arm-msm=92、linux-usb=363、devicetree=429
```

| 系列 | linux-usb 363 | devicetree 429 | linux-arm-msm 92 | 其它 |
|---|---|---|---|---|
| dwc3 **v16** | `[v16,1/3]` **15022241 `new`**（v15 15020958 → `superseded`） | `[v16,1/3]` **15022238 `needs-ack`**（v15 15020990 → `superseded`） | — | — |
| elden **v9** | — | `[v9,1/2]` **15024078 `needs-ack`**、`[v9,2/2]` 15024079 `handled-elsewhere`（v8 两枚 → `superseded`） | `[v9,1/2]` **15024081 `new`**、`[v9,2/2]` **15024080 `new`** | — |
| M8 mdss v5（11-13 件；11-25 只是回复式补发） | — | — | — | dri-devel 21：`14980400/14980398/14980399` **仍全 `new`**（补发是 reply，不产生 patch 条目） |
| M10 fastrpc v3 | — | — | `14971025` **仍 `new`**，`commit_ref=None` | — |
| aw86927 v4 | — | — | — | linux-input 17：`15015279–15015284` **6 枚全 `new`** |
| M6 DSI-PHY v2 | — | — | — | dri-devel 21：`14991579` **仍 `new`** |

摄取正常；**`commit_ref` 全 `None`，本轮不作为任何判据**。

### 4.2 内容级（维护者树 / linux-next）—— 唯一有效判据

linux-next 现查：**`20261125`，HEAD `2026-11-25T15:50:49Z`**（`Add linux-next specific files for 20261125`），`Makefile` = **7.4.0**。

```bash
B=https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain
curl -sSL "$B/<path>?h=master"
```

| 对象 | 检查点 | 结果 | 判读 |
|---|---|---|---|
| elden 板 DTS | `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` | **404** | 未进 next |
| elden binding | `Documentation/devicetree/bindings/arm/qcom.yaml` | 200，`grep -n elden` **无命中** | 未进 next |
| elden（qcom 树） | `.../qcom/linux.git/plain/…sm8750-lenovo-elden.dts?h=for-next` | **404** | 未进 `for-next` |
| M10 fastrpc | `arch/arm64/boot/dts/qcom/sm8750.dtsi` | `non-secure-domain` **仅 1 处 = line 6419（CDSP）**；ADSP `fastrpc`（line 2570，`qcom,remote-pid = <2>`）**无该属性** | 未合入（与 11-21 同） |
| M8 mdss reset | `drivers/gpu/drm/msm/msm_mdss.c` | 只有单 `reset_control_get_optional_exclusive(dev, NULL)`（line 328） | 未合入 |
| M6 DSI-PHY | `drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c` | `dsi_7nm_phy_enable()` 在 `writel(data, …CMN_CTRL_0)` 之后**没有** `writel(0xc0, …PLL_SYSTEM_MUXES)`（只有 bias helper 里有 2 处） | 未合入 |
| aw86927 | `drivers/input/misc/aw86927.c` | `grep -ci aw86937` = **0** | 未合入 |
| **elden 2/2 的硬依赖** | `broonie/regulator.git`：`for-7.5` **与** `for-next` 的 `willsemi,wl2868c.yaml` + `drivers/regulator/wl2868c-regulator.c` | 两 ref 均 **200** | **依赖已就位**（cover 的 `84e67d2ee13f`/`602f57223457` 有内容级支撑） |

---

## ⑤ D 面：Mobian / phosh GitLab（我方 MR 的 note / CI 变化）

### 5.1 `gitlab.com/mobian1/droid-juicer !46`（我方唯一 MR）

```bash
curl -sS -H "PRIVATE-TOKEN: $(secret-tool search --all protocol https host gitlab.com | awk -F'= ' '/^secret =/{print $2}')" \
  'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
```
原始字段：
```
state=opened  detailed_merge_status=mergeable  user_notes_count=0
sha=ea9fe3d5c3bb81c246b959c2f0c6ca6ca07c4c4d  draft=False  has_conflicts=False
updated_at=2026-11-23T11:10:29.562Z
head_pipeline: 3102631920 success 2026-11-23T11:15:16.823Z
```
- **零变化**：`updated_at` 与 B4/上轮相同 ⇒ 至复核时刻 **≈65.2 h** 无 note / CI 变化；`/notes` 匿名读仍 `401 Unauthorized`（故以 `user_notes_count` 为准）。
- 组内交叉核对 `GET /groups/mobian1/merge_requests?state=opened&per_page=100`：**13 条 open MR，我方只有 !46**（!45 `2026-10-11`、!36、!35、!22 均久挂）⇒ 维护者节奏月级，**不必催**。

### 5.2 `salsa.debian.org/Mobian-team/*`（我方无 MR）

```bash
curl -sS 'https://salsa.debian.org/api/v4/groups/Mobian-team/merge_requests?state=opened&per_page=100'
```
**33 条 open MR，作者无一条是我们**（与上轮一致）。与我们相关度高的**他人**件：

| MR | 作者 / 时间 | 为什么记 |
|---|---|---|
| `Mobian-team/packaging-tools!33` `kernel-minor-rebase: optimize preparatory steps` | a-wai，`2026-11-25T10:00:17Z` | 7.x staging 线的重基工具在动 ⇒ 我们将来做 `mobian-sm8750-7.4` 更省事 |
| `Mobian-team/devices/kernels/qcom-linux!61` `Draft: 7.3-sdm845` | tiol，`2026-11-24T21:21:21Z` | 7.3 线活；仍**无** sm8750 分支（`branches?search=8750` → `[]`） |

`mobian-recipes` `master` 末次提交仍 `2026-10-21T10:33:28Z a4fff866`；`devices/qcom/packages/` 无实体文件 ⇒ MR-2 的内核 deb 硬前置未变。

### 5.3 `World/Phosh/phosh !2005`（GNOME GitLab）—— B4 记「406 全断」的通道本轮打通

**工具事实（与昨天/ B4 都相反，别照抄旧口径）**：直连 `--noproxy '*'` → **502**；走代理 + **非浏览器 UA** → **200**；浏览器 UA 经代理 → **406**。

```bash
sec=$(secret-tool search --all protocol https host gitlab.gnome.org | awk -F'= ' '/^secret =/{print $2}')
curl -sS -x http://127.0.0.1:7890 -A 'git/2.0' -H "PRIVATE-TOKEN: $sec" \
  'https://gitlab.gnome.org/api/v4/projects/16747/merge_requests/2005'
```
返回：
```
state=opened  detailed_merge_status=mergeable  user_notes_count=2  has_conflicts=False
sha=5300355a30f47df5443823a1c6c207adc30d9e39  updated_at=2026-11-24T06:53:31.635Z
head_pipeline: 1152598 manual / "Blocked (waiting for manual action)" 2026-11-24T07:01:50.911Z
```
`/notes?per_page=100&sort=desc` **6 条**（2 human + 4 system）：
```
2026-11-24T06:53:31.610Z xuqianhui1001 SYSTEM added 1 commit 5300355a
2026-11-24T06:46:10.656Z xuqianhui1001 SYSTEM added 1 commit 82f9f3d9
2026-11-24T06:43:26.467Z xuqianhui1001 HUMAN  Reworked as suggested: …
2026-11-24T06:43:13.146Z xuqianhui1001 SYSTEM changed the description
2026-11-24T05:15:12.467Z xuqianhui1001 SYSTEM added 21 commits
2026-11-14T13:12:08.406Z guidog       HUMAN  Thanks for looking into this. Can we continue without AI fro…
```
⇒ **无新 note、无 CI 变化**；最新人类仍是 guidog `2026-11-14T13:12:08Z`（≈45.6 h 前，其间全是我方动作）。

---

## ⑥ 外部门 / 阻塞

| # | 门 | 现态 | 需要用户做什么 |
|---|---|---|---|
| 门-1 | **IMAP 存储层冻结** | **已解除**（INBOX 天花 `2026-11-26T03:23:29Z`，三箱均有新件，Sent 副本恢复） | **无** |
| 门-2 | 邮件通道能力 | **INBOX 会漏收 b4-reply 类评审回信**（Krzysztof 两封三箱皆无，`11-25T12:03/12:04Z`） | 无（判据已改为 lore 线程，本轮落地）；根治属邮件服务侧，不在本 lane |
| 门-3 | GNOME GitLab 访问 | 可用，但口径为「**代理 + 非浏览器 UA**」；`--noproxy '*'`/浏览器 UA 均失败 | 无（已写进 §9 供下轮） |
| 门-4 | elden 2/2 的 binding 依赖 | **已满足**（`broonie/regulator.git for-7.5`/`for-next` 均有 binding + 驱动） | 无（等 7.5 窗口，cover 已写合并顺序） |
| 门-5 | M11 台账 MID 仍是 dry-run id（上轮记） | **本轮未核 `TASKS/` 是否已改**（lane 不写 `TASKS/`）；lore 实发值仍是 `<179559762994.96050.5409562801088468974@…>` | 由有 `TASKS/` 写权的一轮确认/更正 |
| 门-6 | 任何投递动作（回信/重发/ping） | 本 lane **不发** | 若要回 Jianfeng 或发 elden v10 / DSI-PHY v3，需**按批放行** |

---

## ⑦ 下一动作（可派发粒度）

| # | 动作 | 载体 / 谁做 | 需放行？ |
|---|---|---|---|
| 1 | **elden `pmic@2f` 补 `vin12/vin34/vin5/vin7-supply`**（sashiko v9 第 3 条，真技术意见；可顺带把 Krzysztof `Acked-by` 放进 1/2 trailer） | 新 lane：改 `patches/upstream/elden-dts-v9-20261126/` 出 **v10**（2 枚）+ 门禁 | 备料**不需**放行；**投 v10 需放行** |
| 2 | **M6 DSI-PHY 收 `Tested-by: Jianfeng Liu`**：出 v3（只加 trailer，正文/补丁体不变）或等维护者索取 | 新 lane：`patches/upstream/m6-dsi-pll-v2-20261113-sent-20261117/` → v3 备料 | 备料**不需**；投 v3 **需放行** |
| 3 | **回 Jianfeng**：一句致谢 + 说明「`/raw` 里 Subject 完好，11-16/11-17 是同一 v2 的重复投递，问题在我们」 | mail-io（`send-mail-ustc.py`，纯 ASCII，回 `In-Reply-To` 他那封） | **需放行**（发信）；本轮不写正文 |
| 4 | elden 1/2 的 `Acked-by` 落账（台账写「Ack 在 v9 前 12 h 给出、b4 可自取，不重投」） | 有 `patches/` 写权的一轮 | **不需**（只改台账） |
| 5 | dwc3 v16：**等 Thinh/Greg**（机器人清零、`linux-usb` 在 Cc、双列表均摄取） | 无需动作（下轮复扫） | — |
| 6 | M8 / M10 / M11：静默等待（M8 末人类 = Konrad `11-09T14:16Z`、M10 同、M11 零回复；ping 后 7 天） | 下轮复扫；到 2 周再议 ping | 再 ping **需放行** |
| 7 | aw86927 v4：静默 ≈47.5 h，等 Dmitry Torokhov | 无需动作 | — |
| 8 | phosh !2005 / droid-juicer !46：等维护者（45.6 h / 65.2 h 零变化） | 无需动作，**勿催** | — |
| 9 | Mobian MR-2：仍卡内核 deb（`qcom-linux` 无 sm8750 分支、`mobian-recipes` master 自 10-21 未动）；可借 `packaging-tools!33`（11-25）与 `qcom-linux!61` 的 7.3 形状先做 `mobian-sm8750-7.4` 备料 | 独立 lane（备料不需放行） | 投 MR 需放行 |

---

## ⑧ 复现命令（全部只读）

```bash
# A) IMAP（BODY.PEEK + readonly 选箱；凭据运行时取 keyring）
timeout -k 5 420 python3 /tmp/d10_scan_1126.py
timeout -k 5 300 python3 /tmp/d10_fetch_1126.py '20261126032315.2226704-1-liujianfeng1994@gmail.com' \
   'sashiko-outbox-233571@kernel.org' 'sashiko-outbox-234477@kernel.org' '6B06EE8E.3CC965.49362@mailimap2024'
# 通道复核：Krzysztof 两封是否到过 INBOX（应为 0）
python3 -c "import imaplib,keyring;M=imaplib.IMAP4_SSL('mail.ustc.edu.cn',993);M.login('xiaqinghuan@mail.ustc.edu.cn',keyring.get_password('smtp','xiaqinghuan@mail.ustc.edu.cn'));M.select('INBOX',readonly=True);print(len(M.search(None,'(SINCE \"25-Nov-2026\" HEADER In-Reply-To \"20261125091309\")')[1][0].split()))"

# B) lore 线程 atom（curl 直取 200，无需 Anubis）
timeout -k 5 600 python3 /tmp/d10_lore_1126.py
curl -sS -A 'Mozilla/5.0 …' 'https://lore.kernel.org/all/179560823932.84329.556031734688243707.b4-reply@b4/t.atom'
timeout -k 5 200 python3 /tmp/lget.py 'https://lore.kernel.org/all/20261117052047.32129-1-xiaqinghuan@mail.ustc.edu.cn/raw' /tmp/dsiphy_raw.txt

# C) patchwork（仅摄取旁证）
timeout -k 5 200 python3 /tmp/lget.py 'https://patchwork.kernel.org/api/1.2/patches/?project=363&q=dwc3+two+connectors&order=-date&per_page=12' /tmp/pw_usb.json
timeout -k 5 200 python3 /tmp/lget.py 'https://patchwork.kernel.org/api/1.2/patches/?project=429&q=Legion+Y700&order=-date&per_page=12'   /tmp/pw_dt_legion.json
timeout -k 5 200 python3 /tmp/lget.py 'https://patchwork.kernel.org/api/1.2/patches/?project=92&q=Legion+Y700&order=-date&per_page=12'    /tmp/pw_msm_legion.json
timeout -k 5 200 python3 /tmp/lget.py 'https://patchwork.kernel.org/api/1.2/patches/?project=92&q=non-secure+domain&order=-date&per_page=8' /tmp/pw_m10.json
timeout -k 5 200 python3 /tmp/lget.py 'https://patchwork.kernel.org/api/1.2/patches/?project=17&q=aw86927&order=-date&per_page=8'          /tmp/pw_aw.json
timeout -k 5 200 python3 /tmp/lget.py 'https://patchwork.kernel.org/api/1.2/patches/?project=21&q=PLL_SYSTEM_MUXES&order=-date&per_page=6' /tmp/pw_dsiphy.json
# C) 内容级（linux-next 20261125 / qcom for-next / regulator for-7.5）
B=https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain
curl -sS -o /dev/null -w '%{http_code}\n' "$B/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts?h=master"   # 404
curl -sSL "$B/arch/arm64/boot/dts/qcom/sm8750.dtsi?h=master" -o /tmp/ln_sm8750.dtsi && grep -n "non-secure-domain" /tmp/ln_sm8750.dtsi
curl -sSL "$B/drivers/gpu/drm/msm/msm_mdss.c?h=master" -o /tmp/ln_mdss.c && grep -n "reset_control_get" /tmp/ln_mdss.c
curl -sSL "$B/drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c?h=master" -o /tmp/ln_7nm.c && grep -n "PLL_SYSTEM_MUXES" /tmp/ln_7nm.c
curl -sSL "$B/drivers/input/misc/aw86927.c?h=master" -o /tmp/ln_aw.c && grep -ci aw86937 /tmp/ln_aw.c
for ref in for-7.5 for-next; do curl -sS -o /dev/null -w "$ref %{http_code}\n" \
  "https://git.kernel.org/pub/scm/linux/kernel/git/broonie/regulator.git/plain/Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml?h=$ref"; done

# D) GitLab
curl -sS -H "PRIVATE-TOKEN: $(secret-tool search --all protocol https host gitlab.com | awk -F'= ' '/^secret =/{print $2}')" \
  'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46'
curl -sS 'https://gitlab.com/api/v4/groups/mobian1/merge_requests?state=opened&per_page=100'
curl -sS 'https://salsa.debian.org/api/v4/groups/Mobian-team/merge_requests?state=opened&per_page=100'
curl -sS 'https://salsa.debian.org/api/v4/projects/Mobian-team%2Fdevices%2Fkernels%2Fqcom-linux/repository/branches?per_page=100&search=8750'
sec=$(secret-tool search --all protocol https host gitlab.gnome.org | awk -F'= ' '/^secret =/{print $2}')
curl -sS -x http://127.0.0.1:7890 -A 'git/2.0' -H "PRIVATE-TOKEN: $sec" \
  'https://gitlab.gnome.org/api/v4/projects/16747/merge_requests/2005'
curl -sS -x http://127.0.0.1:7890 -A 'git/2.0' -H "PRIVATE-TOKEN: $sec" \
  'https://gitlab.gnome.org/api/v4/projects/16747/merge_requests/2005/notes?per_page=100&sort=desc'
```

---

## ⑨ 工具事实（给下一轮省时间）

1. **GNOME GitLab 通道口径又变了**：`--noproxy '*'` → **502**；`-x http://127.0.0.1:7890 -A 'git/2.0'` → **200**；`-A 'Mozilla/5.0'` 经代理 → **406**。上个报告与 B4 的两种写法**今天都失败**，别照抄。
2. **`secret-tool lookup label '…'` 取不到 GNOME token（返回空串，`len=0`）**：必须用 `secret-tool search --all protocol https host gitlab.gnome.org | awk -F'= ' '/^secret =/{print $2}'`。用空 token 查会得到 **406**（不是 401），极易误判「接口挂了」——B4 的「406 全断」可能就是这个坑 + keyring 锁定的叠加。
3. **lore `<MID>/t.atom` 返回整个线程**，不是单条：要单条正文得在 feed 里按 `link/@href` 命中该 MID 的 `entry` 再取 `content`（本轮据此取到 Krzysztof 两封原文）。
4. **b4-reply 类评审回信不一定进我们 INBOX**（本轮 Krzysztof 两封实证）⇒ 「有没有人回」**只能**用 lore 线程判定；IMAP 只作退信/我方副本面。
5. **git.kernel.org `plain/` 是无鉴权内容级查证的便宜路径**（`?h=<branch>`；`/atom/?h=master` 拿 HEAD）；不受 Anubis 影响，优于 lore/patchwork。
6. 本轮未做（lane 边界）：设备侧/上机、任何发信/MR 推送、`TASKS|DEVICE|INDEX|RESOURCES|PITFALLS|AGENTS` 与既有 report 的修改、`git commit`。
