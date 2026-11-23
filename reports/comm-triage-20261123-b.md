# D10 通信跟踪（b 轮，下午）2026-11-23

> 性质：**只读**。未发信、未回复、未推 MR、未动设备；IMAP 全部 `BODY.PEEK`；lore 走 `lore-query.py`（过 Anubis）；
> 时间窗 = 上午轮 `reports/comm-triage-20261123.md`（收于 06:05Z）→ 本轮 10:10Z。
> 本轮核心事件：**Greg Kroah-Hartman 回了 dwc3 v11 3/3**（08:20Z）；**dwc3 v12 已发**（09:53Z）并已过 lore 归档。

---

## §0 结论一行

**dwc3 线现态 = Greg 对 v11 3/3 首次真人回复（08:20Z），唯一要求是「changelog 必须列全此前所有版本」；v12（09:53Z）已修正 krzk 的两条投法（披露移到 `---` 下、新线程、`In-Reply-To` 为空）并加了「无运行时实测」声明，但其 changelog 仍只有 "Changes since v10"，即 v12 大概率没看到 Greg 的回信 ⇒ v13 需补全 v10 之前历代 changelog，这是当前唯一硬欠账。** 其余（elden v7 / fastrpc v3 / mdss v5 / wl2868c / Mobian !46 / phosh !2005 / phoc #302）与上午轮相比零变化。

## §1 邮件（read-mail-ustc.py --days 3 + 全历史 MID 扩集回信匹配）

- `--replies-only` 恒 0（`OUR_IDS` 硬编码 3 个 10 月 MID 的老坑，11-18/11-21/本轮三次复现）→ 用临时脚本（/tmp）以 Sent Items 自 01-Sep 起 242 个历史 MID 做 `In-Reply-To`/`References` 匹配。
- INBOX + Junk 自 21-Nov 命中 26 封：自收副本（v10×4、v11×4、v12×3）+ sashiko v10×3、v11×2 + krzk v10 1/3 ×2 份 + Joonhoe Kim aw86927 ×3（各双份）+ **新：Greg ×2 份（同 MID，列表+直投）**。
- Junk 命中 0；真退信 0。
- Sent 窗口内新增：**v12 ×4（11-23 17:53 CST）**。

### Greg Kroah-Hartman 的回复（本轮最硬一条）

`<2026112313-skied-crock-7374@gregkh>`，2026-11-23T08:20:36Z，Re: **[PATCH v11 3/3]**，lore 已归档。
引 v11 3/3 的 changelog（"Changes since v10:"）后逐字：

> What about all the previous versions?  Please always include them all, right? thanks, greg k-h

判读：不是拒绝内容，是**投递规范**要求——changelog 要覆盖 v9 及更早（本系列在 lore 上自 v4 起可见，还有 v5/v7/v8/v9/v10 多代）。语气是惯例提醒（"right?"），配合他主动 Cc 全套 dt/usb 地址，说明**系列进入了他的视野**（此前 v10/v11 只有 sashiko + krzk）。

### v12 实发核验（IMAP 自收副本 17710–17713 + lore /all/）

| 项 | v11 | v12 |
|---|---|---|
| 线程 | 续投 v10（krzk K2） | **新线程，`In-Reply-To: None`** ✅ |
| AI 披露位置 | commit msg 内（`---` 之上） | **cover 正文披露 + 各 patch 披露移到 `---` 之下** ✅ |
| 新增声明 | 无 | cover 明写「No runtime testing is claimed for this version: the mux path has not been exercised on hardware」 |
| changelog | only v10 | **仍 only "Changes since v10"** ❌（Greg 的要求未满足） |

时间线：Greg 回信 08:20Z → v12 实发 09:53Z，间隔 1.5h；v12 的 To/Cc 未变（仍 Thinh/robh/krzk/conor/gregkh + 四列表），说明发信大概率在读完 Greg 回信之前定稿（changelog 恰好只到 v10 与此一致）。

## §2 lore 归档复核

- **v12：4/4 已在 `/all/`**（MID `20261123095310.154352-1..4`，09:53:24–09:53:28Z）；**linux-devicetree 列表 4/4 亦可见**；linux-usb 列表索引暂未刷出 v12（仍是 v11 最新）——按 `/all/` 已收判归档成功，仅该列表检索视图滞后。
- v11 4/4 在 `/all/` 与两列表（上午轮结论不变）。
- Greg 回信在 `/all/` 可见（08:20:39Z）。
- sashiko 对 v12：**尚无**（发信后约 1h，正常窗口内）。
- patchwork：v11 2/3 = **superseded**（15007994 现查）；v12 patchwork 索引接口本轮查询不便（`q=`/`msg_id` 参数被忽略），以 lore 为准，不影响结论。

## §3 其它线程（与上午轮比对：零变化）

| 线程 | 现态 | 变化 |
|---|---|---|
| elden DTS v7 | `20261117052029.31900-1`（patchwork `14991580`，state=new）；维护者树/next 无文件；comments=0 | 无 |
| M10 fastrpc v3 | `20261111035731.940893-1`（`14971025`，new）；`sm8750.dtsi` adsp 仍无 `non-secure-domain`；静默 12 天 | 无 |
| M8 mdss v5 | 3/3 在档；`msm-next` `msm_mdss.c` 未合入；sashiko 报告未逐条判别（PATCHES 侧欠账） | 无 |
| wl2868c | v12（regulator）11-17 发出；`TASKS/README.md:478` 文档回填已完成 | 无 |
| aw86927 v2 | Joonhoe Kim 三枚 Tested-by 待收进 v3 备料（上午轮 A2，未变） | 无 |

## §4 GitLab（只读 REST，未登录）

| 项 | 现态（本轮现查 10:0xZ） | 变化 |
|---|---|---|
| **Mobian `droid-juicer` `!46`** | state=opened，`user_notes_count=0`，`detailed_merge_status=mergeable`，updated_at 仍 2026-11-21T09:31:15Z；pipeline 唯一一条 iid=1 **success**（11-21T09:34Z，sha 2dead7cc）；项目 last_activity 仍 = 开 MR 时刻 | 无（3 天 0 note 0 reviewer） |
| phosh `!2005` | opened，notes=1（内容仍取不到：单查 `/merge_requests/2005` 返 HTTP 406，`iids[]` 列表接口可读对象但 notes 401），`need_rebase`，无 reviewer，updated_at 仍 11-14T13:14Z | 无 |
| phoc `#302` | opened，notes=0，updated_at 2022-10-10 | 无 |

gitlab.gnome.org 单 MR 端点 406 / HTML 页 CAPTCHA（Client Challenge），改走 `?iids[]=2005` 列表端点才读到对象——记为工具坑。

## §5 需要决策/动作（供编排方裁，不阻塞）

1. **v13 changelog 补全（P1，唯一硬欠账）**：按 Greg 08:20Z 要求，changelog 覆盖 v9 及全部更早版本（本系列 lore 可见 v4/v5/v7/v8/v9/v10 多代）。同时保留 v12 已修好的两条投法。建议等 sashiko 对 v12 的报告出来（一般数小时内）一并处理，凑齐再投 v13；投递仍按 §7 批准制。
2. fastrpc ping、mdss sashiko 判别、Mobian/`!2005` 等待 —— 均沿上午轮 A3–A7，无新增。

---

**结论：本轮零外发、零写入（本文件除外）；dwc3 已获 Greg 首次回复，v12 投法已修好但 changelog 仍缺 v10 之前历代，v13 需补全后再投。**
