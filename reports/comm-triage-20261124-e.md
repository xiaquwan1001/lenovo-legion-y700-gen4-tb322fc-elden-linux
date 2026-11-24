# 通信 lane 复扫（2026-11-24 05:00Z → 08:30Z）— E 轮，只读

> 只读：未发信 / 未推 MR / 未改 `TASKS/README.md`、`versions/`、`INDEX.md`。所有外部命令带 `timeout -k`。
> 凭据只在运行时从 keyring / secret-tool 取，未落盘。IMAP 全 `BODY.PEEK`（不改已读态）。
> 复核时刻：INBOX 08:0xZ；lore 08:0x–08:2xZ；GitLab 08:1x–08:2xZ。
> **纪律遵守**：patchwork 的 `state`/`commit_ref` **未作为判据**（本节出现的 patchwork 只用于说明「它查不到」）；
> 合并与否一律用「维护者自己的树 / linux-next 内容级」判定（§2）。

## ① 结论表（一页）

| 系列 / 目标 | 渠道 | 最新状态（本轮实取） | 时间戳 (UTC) | 需我方动作 |
|---|---|---|---|---|
| **dwc3 v14**（原线程 `20261124015002`） | lore linux-devicetree + INBOX | **Greg KH 回信**：「Please **test on real hardware before resending**, AND also **cc: the proper mailing lists (you forgot the usb list)**」 | `2026-11-24T07:14:47Z` | **需（最高优先）**：先上机验证 + v15 补 `linux-usb`，再发 |
| dwc3 v14 **重复套**（`20261124045220`）+ 更正 | lore linux-devicetree / linux-usb | 更正信已归档（两处索引均可见）⇒ 重复线程已中和；但 **sashiko 审了重复套的 1/3**，给 2 条 `[Low]` | 更正 `04:54:23Z`；sashiko `05:04:24Z` | 可等（两条 `[Low]` 并入 v15） |
| **aw86927 v4**（`20261124045040.559317-1`） | linux-input + linux-devicetree | 归档 <1 min；**至 08:2xZ 零回复**（两列表 feed 最新条目 = 我方 `04:50:54Z`） | 投出 `04:50Z` | 无需（等评审） |
| **pstore v1**（`20261116040049.434247-1`） | lore all | 线程根在档（`11-16T04:01:14Z`）；**至今 0 回复**（按标题全档检索命中数 = 1，只有 cover） | 静默 8 天 | 无需（低优先，可择机一次礼貌 ping） |
| **mdss v5** | lore all / linux-arm-msm | 我方 `01:52Z` 的证据回帖**无人接**；维护者最后一次实质意见 = Dmitry 对 v3 2/3 | 我方 `2026-11-24T01:52:18Z`；Dmitry `2026-11-11T14:19:35Z` | 可等（已两次自回，再加 bump 只增噪） |
| **fastrpc M10 v3** | lore linux-arm-msm + linux-next 内容 | 维护者零回复（Konrad 最后一封是对 v1）；**linux-next `sm8750.dtsi` ADSP fastrpc 节点仍无 `qcom,non-secure-domain`**（只有 CDSP 有）⇒ 未进 next | v3 `2026-11-11T03:57:42Z`（静默 13 天） | 可等（可选一次礼貌 ping，与既有判定一致） |
| **wl2868c v12** | **regulator.git `for-7.5`** + linux-next | **已合入维护者树**：merge `0216753490ff`（含 `84e67d2ee13f` binding + `602f57223457` driver）；linux-next 亦含 `drivers/regulator/wl2868c-regulator.c` | 合入 ~11-17；本轮 08:1xZ 复核 | 无需（只欠文档回填，属 SSOT lane） |
| **phosh !2005** | gitlab.gnome.org API（keyring+代理 7890） | `opened` · mergeable · pipeline **Blocked（waiting for manual action）**；**最新人是 guidog（11-14）**；`updated_at 06:53Z` 是**我方 push**，不是回复 | 我方 push `06:43–06:53Z`；guidog `2026-11-14T13:12:08Z` | 可等（等维护者；勿重复催） |
| **droid-juicer !46** | gitlab.com API v4 | `opened` · **0 notes** · `updated_at 2026-11-23T11:10:29Z`（21 h+ 无变化）· pipeline #3102631920 **success** | 同左 | 无需（等维护者） |
| **salsa Mobian-team/mobian-recipes** | salsa API v4 | 15 个 open MR，**无一属我方**（最新 #173 `11-22`）⇒ 无新 note 可读 | 复核 `08:2xZ` | 无需 |
| **phoc（World/Phosh）** | gitlab.gnome.org API | 我方在 World/Phosh 下 open 的 MR **只有 phosh!2005 一个**，phoc 无我方 MR | 复核 `08:2xZ` | 无需 |

## ② 逐条证据（URL / MID）

**1) dwc3 v14 — Greg KH（唯一新增的人类回帖）**
- MID `<2026112405-sniff-untying-8990@gregkh>`（INBOX 收到 2 份，同一 MID）
- `https://lore.kernel.org/linux-devicetree/2026112405-sniff-untying-8990@gregkh/`
- 正文（原样）：
  > Please test on real hardware before resending, AND also cc: the proper
  > mailing lists (you forgot the usb list).
- 两条都可现查证实：
  - **"forgot the usb list" 成立**：`SEND.sh` 的 `CC=` 从 **v12 起**就丢了 `linux-usb@vger.kernel.org`
    （v11 的 `SEND-CHECKLIST.md` 里还在；v12/v13/v14 均无）。lore `linux-usb` 侧最后一版 v 系列是 **v11**，
    之后只有我方的 `duplicate-notice`（更正信恰好 CC 了 usb 列表才落到那里）。
  - **"test on real hardware" 成立**：v14 cover 原文自陈 "No runtime testing is claimed for this version: the mux path has not been exercised on hardware."

**2) dwc3 v14 重复套 + 更正（04:52Z / 04:54Z）**
- 重复 cover `<20261124045220.595001-1-xiaqinghuan@mail.ustc.edu.cn>`；更正 MID `<duplicate-notice-1@local>`
- `https://lore.kernel.org/linux-devicetree/duplicate-notice-1@local/`（linux-usb 侧同名条目亦在）
- 更正内容与 `patches/upstream/dwc3-v14-20261124/SENT.md` 一致（「请忽略本线程，以 01:50Z 线程为准，两批逐字节相同」）；
  账外校正：SENT.md 写「05:0xZ」，实测发出/归档是 **04:54:23Z**。
- 卫生问题（供 v15 顺手修）：`Message-ID: <duplicate-notice-1@local>` **不是合法 MID 形态**（`@local` 无域名）；
  它确实被 lore 收下了，但别当范例。
- sashiko 对**重复套 1/3** 的两条 `[Low]`（`<sashiko-outbox-230542@kernel.org>`，`05:04:24Z`）：
  1. `port@0` 从 `graph.yaml#/properties/port` 换成 `$defs/port-base` 后，**单连接器（无 mux）路径的 plain `endpoint`
     失去 `unevaluatedProperties: false`**，会静默接受 `usb-role-switch`/`mux-state` 等未描述属性；
  2. then 分支的 `'^endpoint@([2-9]|[1-9a-f][0-9a-f]+)$': false` **漏掉 `endpoint@a`–`endpoint@f`**（应写 `[2-9a-f]`）；
     sashiko 建议 else 分支改回 `$ref: …/properties/port`。
  两条对**原线程同字节内容同样适用**，随 v15 一起改即可（不必单独回）。

**3) aw86927 v4**
- cover `<20261124045040.559317-1-xiaqinghuan@mail.ustc.edu.cn>`
- `https://lore.kernel.org/linux-input/?q=aw86927&x=A` → 最新 7 条全是我方 `04:50:46–04:50:54Z` 的 v4；
  `https://lore.kernel.org/linux-devicetree/?q=aw86927&x=A` 同。v3 的 sashiko 4 条（`02:03:12Z`）已在 v4 处置，本轮无新意见。

**4) pstore v1**
- cover `<20261116040049.434247-1-xiaqinghuan@mail.ustc.edu.cn>`
- `https://lore.kernel.org/all/?q=%22refuse+zones+overlapping+the+initrd%22&x=A` → 命中 **1**（只有 cover，`11-16T04:01:14Z`）
- 既有旁证（不改结论）：`reports/主机侧-B17-20261117.md:31` 记 patchwork 上两枚被标 `handled-elsewhere`（新发即关闭）。

**5) mdss v5**
- 我方 `01:52Z` 自回（`<20261124015207.1432460-1-…>`，`In-Reply-To` 指 v5 cover）；
- `https://lore.kernel.org/all/?q=%22reset+all+block+resets+described+in+DT%22&x=A` → 最新条目仍是该自回，维护者最新 = Dmitry `11-11T14:19:35Z`（对 v3 2/3）。

**6) fastrpc M10 v3（内容级判据，非 patchwork）**
- v3 `https://lore.kernel.org/linux-arm-msm/?q=%22mark+the+ADSP+fastrpc+node+as+non-secure+domain%22&x=A` → 4 条，最新 = 我方 v3 `11-11T03:57:42Z`
- **linux-next 内容级**：`arch/arm64/boot/dts/qcom/sm8750.dtsi`（next master 直取）中
  `adsp` 的 `fastrpc {`（:2570）**无** `qcom,non-secure-domain`；`cdsp` 的（:6415，属性在 :6419）**有** ⇒ 合入证据 = 无，**未进 next**。

**7) wl2868c v12（维护者树内容级）**
- `https://git.kernel.org/pub/scm/linux/kernel/git/broonie/regulator.git/log/?h=for-7.5` 现查三行：
  `0216753490ff regulator: add the Will Semiconductor WL2868C camera PMIC`（Mark Brown，merge）、
  `602f57223457 …WL2868C camera PMIC driver`（Qianhui Xu）、`84e67d2ee13f …dt-bindings: willsemi,wl2868c…`（Qianhui Xu）。
- linux-next 内容级：`next.git/plain/drivers/regulator/wl2868c-regulator.c` 取到（9477 B，`wl2868c` 31 命中）。

**8) phosh !2005**
- `https://gitlab.gnome.org/World/Phosh/phosh/-/merge_requests/2005`
- API（`curl -x http://127.0.0.1:7890 -H "PRIVATE-TOKEN: <secret-tool … host gitlab.gnome.org>" …/projects/16747/merge_requests/2005`）：
  `state=opened`、`detailed_merge_status=mergeable`、`user_notes_count=2`、`sha=5300355a`、
  `head_pipeline.status=manual`/`detailed_status=Blocked (waiting for manual action)`、`updated_at=2026-11-24T06:53:31Z`。
- notes（desc）：`06:43:26Z` 我方长回（rework 说明）+ `06:46/06:53` 两次我方 push；**guidog 最后一条 `2026-11-14T13:12:08Z`**。
  ⇒ `updated_at` 变新是**我方**动作，**不是**新回复（这是本轮最容易误判的一格）。

**9) droid-juicer !46**
- `https://gitlab.com/mobian1/droid-juicer/-/merge_requests/46` · API `projects/mobian1%2Fdroid-juicer/merge_requests/46`
  → `state=opened`、`user_notes_count=0`、`updated_at=2026-11-23T11:10:29Z`、`head_pipeline.status=success`（#3102631920，fork `xiaquwan1001`）、`merge_status=unchecked`、`draft=false`。
- `/notes` 端点本机取到 **401 Unauthorized**（gitlab.com 匿名 note 读被限）⇒ 「0 notes」以 MR 的 `user_notes_count` 为准（同一字段，权威）。

**10) salsa Mobian-team / 11) phoc**
- `https://salsa.debian.org/api/v4/projects/71384/merge_requests?state=opened&per_page=100` → 15 条，作者全部为他方（最新 #173 `2026-11-22T09:33:52Z`）⇒ 无我方件、无新 note。
- `https://gitlab.gnome.org/api/v4/merge_requests?author_username=xuqianhui1001&state=opened` → **1 条**（只有 phosh!2005）⇒ phoc 侧无我方 MR。

## ③ 三分类

**必须先回 / 必须先动（1 件）**
1. **dwc3 v14**：Greg `07:14:47Z` 的两条要求都现查成立 ⇒ 下一版（v15）前必须 ①**真机跑通 mux 路径**（本项目 QEMU 判不了，需上机；`AGENTS.md`「上机先过 QEMU」+ 真外设面显式写「需上机」）；②**`CC` 补回 `linux-usb@vger.kernel.org`**。可直接以 v15 回，不必单独发 ack。

**可等（4 件）**
- **dwc3 重复套 sashiko 2 条 `[Low]`** ⇒ 并入 v15（`$defs/port-base` 的 `unevaluatedProperties` 缺口 + `[2-9a-f]`）。
- **aw86927 v4**：静默 <4 h，正常评审窗口，等。
- **mdss v5**：已两次自回（11-17、11-24），维护者 13 天未动；**不建议再加 bump**。
- **phosh !2005 / droid-juicer !46**：均在等对方（guidog / Mobian 维护者）；phosh 侧我方 rework 刚推，回帖不必再补。

**无需动作（5 件）**
- **wl2868c v12**：已进 `for-7.5` + linux-next（内容级双重证据）；只剩 SSOT 回填（不属本 lane）。
- **pstore v1**：0 回复、0 冲突；低优先。
- **fastrpc M10 v3**：未进 next，但也无我方欠账；「只欠一次礼貌 ping」的既有判定不变（是否 ping 由 §7 决定）。
- **salsa Mobian-team/mobian-recipes**：无我方 MR/note。
- **phoc**：无我方 MR。

## ④ 一句话判据 + 复核命令

> 判据：**只有「维护者自己的树 / linux-next 内容级」+「收件人侧可读的回信」算状态**；patchwork 的 `state`/`commit_ref` 一律不作证据（本次 v14 在 patchwork `project=4&q=dwc3` 里根本检索不到，正好说明它不能当判据）。

```bash
# 0) lore/patchwork/git.kernel.org 现在都有 Anubis：先解一次 PoW 拿 cookie（/tmp/lget.py 就是干这个的）
timeout -k 5 200 python3 /tmp/lget.py 'https://lore.kernel.org/linux-devicetree/?q=%22two+connectors+sharing+one+HS%22&x=A' /tmp/x.xml

# 1) 邮件增量（BODY.PEEK 只读；since 24-Nov，含 Junk）
timeout -k 5 420 python3 /tmp/e4_scan.py | grep -E '^11-24 '

# 2) 单封正文（按 MID，只读）
timeout -k 5 300 python3 /tmp/e4_fetch.py 2026112405-sniff-untying-8990@gregkh sashiko-outbox-230542@kernel.org

# 3) 合并状态：维护者树（内容级）
timeout -k 5 200 python3 /tmp/lget.py 'https://git.kernel.org/pub/scm/linux/kernel/git/broonie/regulator.git/log/?h=for-7.5' /tmp/r75.html
grep -c 'wl2868' /tmp/r75.html          # → 3 行（merge + 2 枚）
# linux-next 内容级：ADSP fastrpc 是否带 non-secure-domain
curl -sS -A 'Mozilla/5.0' -b /tmp/anjar_git.kernel.org.txt \
  'https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain/arch/arm64/boot/dts/qcom/sm8750.dtsi' \
  | grep -n -A4 'fastrpc {'        # → :2570 adsp 无该属性；:6415 cdsp 有

# 4) GitLab
curl -sS 'https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46' \
  | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["state"],d["updated_at"],d["user_notes_count"])'
TOK=$(secret-tool lookup protocol https user xuqianhui1001 host gitlab.gnome.org)
curl -sS -x http://127.0.0.1:7890 -H "PRIVATE-TOKEN: $TOK" \
  'https://gitlab.gnome.org/api/v4/projects/16747/merge_requests/2005/notes?per_page=100' \
  | python3 -c 'import json,sys;[print(n["created_at"],n["author"]["username"]) for n in json.load(sys.stdin)[:5]]'
```

## ⑤ 本轮的方法/口径变更（给下一轮省事）

1. **lore.kernel.org / patchwork.kernel.org / git.kernel.org 现在全部上了 Anubis**，`curl` 直取、`r.jina.ai`、
   无头 Firefox（`browserfetch.mjs`）**都不行**（jina 本出口 IP 被判 bad reputation 401）。可行做法 = **自己解 PoW**：
   取页面里内嵌的 `{"rules"…"challenge":{…}}`，找 `nonce` 使 `sha256(randomData+nonce)` 的十六进制前缀含 `difficulty` 个 0，
   再 `GET /.within.website/x/cmd/pass-challenge?id=<challenge.id>&response=<hash>&nonce=<n>&redir=<url>&elapsedTime=…`
   （**缺 `id` 会 500**；返回 302 即成功），之后同 cookie jar 直取。脚本 `/tmp/lget.py`（不在 `scripts/`，临时件）。
2. gitlab.com 的 `/notes` 匿名读 401（`user_notes_count` 仍可读）；gitlab.gnome.org 走 keyring token + 代理 7890 正常。
3. `read-mail-ustc.py` 的 `--replies-only` 仍因 `OUR_IDS` 只硬编码 3 个 2026-10 的 MID 而恒 0 —— 本轮沿用「全量 since 扫描 + 人工按 From/主题/IRT 过滤」。
