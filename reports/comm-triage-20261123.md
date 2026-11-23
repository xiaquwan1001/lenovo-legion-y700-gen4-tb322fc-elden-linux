# D10 通信跟踪（邮件 + Mobian/phosh GitLab）2026-11-23

> 性质：**只读**。未发信、未回复、未推 MR、未 fork/push、未动设备、未改任何其它文件；唯一写域 = 本报告。
> 窗口 = **2026-11-21T02:00Z → 2026-11-23T06:05Z**（起点 = 上一篇 `reports/mail-triage-20261121-night.md` 的收尾时刻）。
> 外部命令一律 `timeout -k`；IMAP 全部 `BODY.PEEK`（不改已读状态）；`curl --noproxy '*'`；凭据只在运行时由 keyring 取，未落盘、未打印、未进本文。
> 数据源：USTC IMAP（INBOX / "Junk E-mail" / "Sent Items"）＋ lore raw（`scripts/lore-fetch-raw.py`，过 Anubis）＋ patchwork REST 1.2 ＋
> git.kernel.org（`next/linux-next`、`gregkh/usb`、`qcom/linux` 三棵树 plain 取文件）＋ gitlab.freedesktop.org ＋ GitLab/GNOME/Salsa REST。

---

## §0 结论（数字先行）

| 项 | 数字 / 事实 |
|---|---|
| 窗口内我方外发 | **8 封**：dwc3 **v10** ×4（11-21T02:21Z）、dwc3 **v11** ×4（11-21T13:20Z） |
| 窗口内**对我方线程**的回信 | **9 封（唯一）**：sashiko 5 + **人类 4** |
| 人类回帖 | **4 封**：Krzysztof Kozlowski ×1（v10 1/3，09:11Z）＋ **Joonhoe Kim ×3（aw86927 v2 4/6、5/6、6/6，17:23Z，均为 `Tested-by`）** |
| sashiko | **5 封**：v10 ×3（02:33/02:40/02:40Z，已被 v11 闭合）＋ **v11 ×2（13:31Z 1/3 = 1×Low；13:32Z 0/3 汇总 = 2/3、3/3 no issues）** |
| **退信** | **0**（`mailer-daemon`/`postmaster`/`noreply`/`bounce`/主题五判据窗口内唯一命中 = `noreply@hydro.ac` 的注册信，非投递失败） |
| 我方自收副本 | 8（v10 ×4、v11 ×4，属正常回环） |
| 第三方列表信（in-window） | **55 封**（camss / dpu / kaanapali / glymur 等，非我方线程；其中 3 封一度只按关键词命中，实为我方 aw86927 回信，见 §1.2） |
| 11-22 全天 + 11-23 至 06:05Z | 对我方线程**零新信**（只有第三方列表流量） |
| lore 归档 | dwc3 **v11 4/4 在 `/all/`**，cover 另在三列表各 1 命中；elden v7 / fastrpc v3 / mdss 3 枚 **全部命中**（§4） |
| 内容级合并判定（维护者树 + linux-next） | **本轮现查：四个系列全部「未合入」**（§4 逐条带文件与 grep 计数） |
| GitLab 阻塞我方 | **0 项**（Mobian `!46` 等维护者；phosh `!2005` 需 rebase 但不是我方阻塞；phoc `#302` 仍 open 无进展） |

### 需我方动作清单（按优先级）

| # | 动作 | 优先级 | 依据（证据） | 谁做 / 前置 |
|---|---|---|---|---|
| **A1** | **下一次投递（v12 或等价）必须先修「投法」两条**：① 三枚 patch 的 AI 披露段移到各自 `---` **之下**（cover 可保留正文披露）；② **新线程**（不带 `--in-reply-to`）。**代码不用再改**。 | **P1（唯一"正在烧信誉"的项）** | v11 实发件 raw：`/tmp/lore-v11/2.raw` 第 111 行 `*** AI-assistance disclosure ***`、第 116 行才是 `---`（披露在 commit message 内）；`/tmp/lore-v11/1.raw` 第 59-60 行 `In-Reply-To/References: <20261121022104.1507987-1-…>`（仍串到 v10）。二者正是 krzk 11-21T09:11Z 点名的两点（K1/K2），且 sashiko v11 又独立判了 `[Low] transient AI disclosure left in commit message` | mail-io 下一轮 + **用户按批放行** |
| **A2** | **把 Joonhoe Kim 的三枚 `Tested-by` 收进 haptics 下一个版本**（0004/0005/0006 各一枚 + cover 致谢），当前 v3 备料里 `grep -c Tested-by` = **0** | **P2（外部第三方实测证据，白拿）** | 他 11-21T17:23Z 三封原文：「Tested on a Lenovo Y700 Gen 5 (TB323FU, Kaanapali) with two AW86937 … before and after s2idle」＋`Tested-by: Joonhoe Kim <26rote@gmail.com> # Lenovo Y700 Gen 5 (TB323FU)` | 备料即可（不动设备）；投递仍需放行 |
| **A3** | elden DTS：v7 仍未合入、**patchwork comments = 0**；v8 备料的「`arm/qcom.yaml` 条目 + phandle 字母序」两项仍欠（sashiko 11-17 的 4 条里唯一没自然消解的两条） | P3 | §4 表；`qcom/linux for-next` 与 `linux-next master` 的 `sm8750-lenovo-elden.dts` 均 **404** | 备料组；不需用户 |
| **A4** | fastrpc v3 已静默 **12 天**（0 回复 0 comment，内容级未进树）⇒ 是否发一次礼貌 ping，需用户裁（§7 现口径是「随版带走、不单独 ping」） | P4（决策项，非技术） | `14971025` comments=0；`sm8750.dtsi` 仅 cdsp 有 `qcom,non-secure-domain`（`grep -c` = 1） | 用户一句话 → mail-io |
| **A5** | mdss v5 的 sashiko 三份报告**仍未逐条判别**（11-13 起）；此项属 `PATCHES` 侧欠账，不是邮件回信 | P5 | `14980395`（dri-devel 1/3）comments=1 且作者为 sashiko-bot；arm-msm 侧 14980389 comments=0 | 代码边界/上游化 lane |
| **A6** | wl2868c「已合入」文档回填**已完成**（上一轮列为待办），本轮复核 `TASKS/README.md:478` 已含 `84e67d2ee13f/602f57223457` ⇒ 无需再动 | — | `grep -c 84e67d2ee13f TASKS/README.md` = 2 | — |
| **A7** | Mobian `!46`：**仍 0 note**（创建 11-21T09:31Z，已 2 天）；**不要动 fork**（CI 跑在 `xiaquwan1001` 的 fork 上，重推会改 head sha） | —（等） | §5.1 | — |

### 未确认项（含原因）

1. **phosh `!2005` 唯一那条 note 的作者/内容**：`GET …/merge_requests/2005/notes` 与 `/discussions` 均返 **401 Unauthorized**（未认证 API 只给 MR 对象上的 `user_notes_count=1`，无法区分是人工回复还是「added N commits」系统 note）。→ **未确认**。本轮未调用 `secret-tool` 取 GitLab token（凭据处理与只读口径冲突，且不阻塞任何结论）。
2. **Mobian `!46` 的 CI 现态**：本轮只取 MR/issue 元数据，未重查 pipeline；11-21 报告记的是 3 job 全 success。→ 现状**未确认**（无理由变更）。
3. **mdss 系列 dri-devel 侧其余副本的 comments**：只查了 `14980395`（1 条）。arm-msm 三枚 `14980387/8/9` 中 3/3 与 1/2 已查（0/0/1）。其余副本**未逐条查**。
4. **Junk 内 52 封未逐封人工阅读**：判据用的是「我方全部 242 个历史 Message-ID 的 `In-Reply-To`/`References` 命中 + 发件人 + 主题」三判据并集，理论上不漏对我方的回复；但「不提我方 MID 的纯人工评论」无法用机械判据发现（低概率）。
5. **dwc3 v11 是否被 Greg 直接取件**：本轮查了 `gregkh/usb:usb-next` 的 `drivers/usb/dwc3/core.c`（`mux_control` 计数 = **0**）与 `linux-next:master`（同为 0），未见取件迹象；但维护者「不回信直接合入」的盲区只有下一次快照才能排除。→ 结论按「未合入」，可被后续快照推翻。

---

## §1 方法与口径

### 1.1 为什么不用 `read-mail-ustc.py --replies-only`

`~/.local/bin/read-mail-ustc.py:13-15` 的 `OUR_IDS` 硬编码 3 个 **2026-10** 的 Message-ID ⇒ 窗口内恒 0（同坑 11-18、11-21 两轮已记，未重复踩）。
本轮改用**临时脚本（/tmp，不入 `scripts/`）**，三判据并集，且**把「我方 MID 集合」从窗口扩到全历史**——这是本轮最重要的方法修正（见 §1.2）。

```bash
# 凭据：importlib 载入 read-mail-ustc.py 的 get_pw()（keyring → git-credential），只在运行时用
timeout -k 10 900 python3 /tmp/e2_mail.py     # 阶段1 Sent Items → 我方 MID；阶段2 INBOX/Junk 三判据
timeout -k 10 900 python3 /tmp/e2_pass3.py    # 阶段3：Sent Items(01-Sep 起 245 封/242 MID) × INBOX+Junk 全量
```

原始输出：

```
### Sent Items SINCE 20-Nov-2026: total=9, in-window(>= 11-21T02:00Z)=8, our MIDs=8
### INBOX SINCE 20-Nov-2026: 1822
### Junk  SINCE 20-Nov-2026: 52
### candidate rows=118 ; in-window candidate=74
### Sent Items since 01-Sep-2026: 245 mails, 242 unique our MIDs
### in-window mail whose thread references ANY of our MIDs: 9 (deduped)
```

in-window 74 行的分类（脚本口径）：自收副本 **8** / 对我方 MID 的回复行 **7**（krzk 一份投两处，去重后 6 唯一）/ 退信类命中 **1**（假阳性，见 §2.3）/ 仅关键词命中 **58**。

### 1.2 ⚠ 方法修正：只取"窗口内我方 MID"会漏掉对旧系列的回复

任务给的判据（Sent Items 取**窗口内**我方 MID）在本窗口**恰好漏掉 3 封真人回信**：
我方 aw86927 v2 是 11-17T05:21Z 发的（窗口外），所以 Joonhoe Kim 的 3 封回信既不在"窗口 MID"集合里，也没被我方窗口关键词（`aw86927` 只在 §1 词表里命中过，但因 `why` 走的是 else 分支被归为「第三方」）。
**修正 = 用 Sent Items 自 01-Sep 起的 242 个历史 MID 做 `In-Reply-To`/`References` 匹配**，一次性把 9 封唯一回信全部抓出（§1.1 阶段 3 的 9 行）。建议后续 D10 轮次固定用这个扩集口径。

### 1.3 退信判据

```
FROM "mailer-daemon" / FROM "postmaster" / SUBJECT "Undelivered" / SUBJECT "Mail delivery failed"
+ 发件人子串 no-reply|noreply|bounce|mail-daemon|mailerdaemon + 主题子串 退信|无法投递
```
窗口内**只有 1 条命中**：`Hydro <noreply@hydro.ac>` / `Sign Up` / `<…@bounce.hydro.ac>`，2026-11-23T01:58:24Z —— 是第三方服务注册信，**不是投递失败**。⇒ 真退信 **0**。

---

## §2 逐封归类（窗口内 9 封对我方线程的信）

### 2.1 人类回帖（4）

| # | 发件人 | 时间 (UTC) | 线程 | 内容要点 | 要不要我方动作 |
|---|---|---|---|---|---|
| H1 | Krzysztof Kozlowski `<krzk@kernel.org>` | 2026-11-21T09:11:00Z · `<20261121-icy-bright-partridge-afe8de@quoll>`（INBOX 收到 2 份：To+Cc 双投，同 MID） | dwc3 **v10 1/3** | 「This does not go to commit msg, but changelog.」＋「You keep sending multiple revisions, this one even threaded to other posting and still not really responding to feedbacks.」＋「Feedback was waiting for three days… wasting our time.」 | **要**：不是回信，而是**下一次投递必须换投法**（A1）。**不建议单发回信**（他明说别再耗时间）。见 §3 |
| H2 | Joonhoe Kim `<26rote@gmail.com>` | 2026-11-21T17:23:20Z · `<20261121172320.829-1-26rote@gmail.com>` | aw86927 **v2 4/6** | `Tested-by: Joonhoe Kim <26rote@gmail.com> # Lenovo Y700 Gen 5 (TB323FU)`；两个 AW86937（chip ID 0x9370），compatible `awinic,aw86937`,`awinic,aw86927`，probe + rumble 双电机，s2idle 前后均正常 | **要**：收 tag（A2） |
| H3 | 同上 | 2026-11-21T17:23:26Z · `<20261121172326.846-1-26rote@gmail.com>` | aw86927 **v2 5/6** | 同上（实测范围含 5/6 的寄存器布局改动） | **要**：收 tag |
| H4 | 同上 | 2026-11-21T17:23:31Z · `<20261121172331.863-1-26rote@gmail.com>` | aw86927 **v2 6/6** | 「Rumble works before and after s2idle」——直接支撑 6/6 的 suspend/shutdown 行为主张 | **要**：收 tag |

> 附带事实：Joonhoe Kim 同时在评别人的 kaanapali DSI 系列（`<20261121172313.812-1-…>`，Tested-by），是活跃的 GB5 设备 reviewer；他的三封同秒连发、同 MID 在 INBOX 出现两次（列表 + 直投重复投递）。

### 2.2 sashiko（5）

| # | 时间 (UTC) / MID | 线程 | 结论 | 处置状态 |
|---|---|---|---|---|
| B1 | 11-21T02:33:15Z · `<sashiko-outbox-226546@kernel.org>` | v10 3/3 | Medium：`dwc3_drd_exit()` 里 deselect 早于角色 teardown | 已在 v11 闭合（v11 cover 变更点 1，实测 `gates/pos-*` 等门已复跑） |
| B2 | 11-21T02:40:38Z · `<sashiko-outbox-226549@kernel.org>` | v10 1/3 | 1 Medium（无条件 `$ref` 到 port@0）+ 2 Low（`$defs`/驱动细节、`dr_mode` required） | 已在 v11 闭合（变更点 2/3/4） |
| B3 | 11-21T02:40:44Z · `<sashiko-outbox-226550@kernel.org>` | v10 0/3 | 系列汇总：2/3 no issues、1/3 三题、3/3 一题 | 同上 |
| **B4** | **11-21T13:31:07Z · `<sashiko-outbox-227074@kernel.org>`** | **v11 1/3** | **1×Low：「transient AI disclosure left in commit message」**，并引 krzk 11-21 原帖，问「should this AI-assistance disclosure paragraph be moved below the `---` separator」 | **未处置，且 = A1 的直接确认**（sashiko 独立复述了 krzk 的意见） |
| B5 | 11-21T13:32:23Z · `<sashiko-outbox-227076@kernel.org>` | v11 0/3 | **Patches 2 and 3: no issues found**；Patch 1: 1 potential issue (1 Low) | 同上 —— **代码面已被机器评审判清**，只剩「投法」一条 |

### 2.3 退信（0）

见 §1.3：窗口内唯一命中是 `hydro.ac` 注册信，非投递失败。**无真退信**。

### 2.4 列表通告 / 第三方线程（不属于我方，55 封）

全部为他人系列（`media: qcom: camss` 多条、`drm/spacemit` K3 DPU、`glymur-camss`、`kaanapali` DSI/UFS、`dwc3: qcom` UTMI/PIPE clock、`atkbd` 等）。**无需我方动作**。
值得记一笔的**相邻动向 2 条**（不是回复，但影响我们的后续判断）：

- `[PATCH 0/3] media: qcom: camss: Two routing fixes and one tidy-up`（Bryan O'Donoghue，11-22T02:10Z）—— 与我们 camss 系列同一子系统，Bryan 自己在动 routing；我们的 CSIPHY 2.4.0 v2 若要投，需先读这串的落点。
- `[PATCH] arm64: dts: qcom: kaanapali: Describe the UFS MCQ registers`（Joonhoe Kim，11-22T01:44Z，base `909ef7a9a30f` = 当前 linux-next）—— 同族设备（Y700 Gen5）上游化在同步推进，说明 GB5 分支有人在做。

---

## §3 🔴 本轮最硬的一条：v11 是"发出了但没按 krzk 的要求改投法"

上一轮（11-21 夜）的 A1 建议 = 「AI 披露移到 `---` 下 + 新线程」。**v11 在 13:20Z 实发了 4 封，但两条都没改**。逐字复核（lore raw 与 IMAP 自收副本互证）：

```bash
grep -n "AI-assistance disclosure\|^---$" /tmp/lore-v11/2.raw      # v11 1/3
111:*** AI-assistance disclosure ***
116:---

grep -nE "^(In-Reply-To|References):" /tmp/lore-v11/1.raw          # v11 0/3
59:In-Reply-To: <20261121022104.1507987-1-xiaqinghuan@mail.ustc.edu.cn>
60:References: <20261121022104.1507987-1-xiaqinghuan@mail.ustc.edu.cn>
```

⇒ **K1（披露位置）仍在**、**K2（续投到上一代）仍在**。sashiko 对 v11 1/3 的 `[Low]` 与本判据完全一致（§2.2 B4）。
**代码侧无欠账**：sashiko v11 汇总明写 2/3、3/3 `no issues found`（§2.2 B5），v11 对 v10 四条意见的处置也确实在 diff 里。

**代价判读**：krzk 的原话是「同一套投法在浪费我们时间」。v12 若仍带这两条，第三次同样的批评是可以预期的；把披露移到 `---` 下 + 去掉 `--in-reply-to` 是**零代码改动的纯机械动作**，没有技术风险。

---

## §4 归档复核（lore）+ 内容级合并判定（维护者树 / linux-next）

口径（`TASKS/README.md` §7）：**lore 只作"是否投递/是否成线程"的证据；是否合并一律按维护者自己的树或 linux-next 内容级判，`commit_ref` 空值不构成任何证据。**

| 系列 | 在档最新代 / MID | lore 归档 | 内容级（本轮现查） | 判定 |
|---|---|---|---|---|
| **dwc3 v11** | `20261121132029.2379449-1..4`（11-21T13:20Z） | **4/4 在 `/all/`**（13014/12611/9035/29380 B）；cover 另在 `linux-usb`/`linux-devicetree`/`linux-arm-msm` 各 1 命中 | `gregkh/usb:usb-next` `drivers/usb/dwc3/core.c` → `grep -c mux_control` = **0**；`linux-next:master` 同文件 = **0**；`snps,dwc3-common.yaml` 无 `mux-controls`/`mux-state`/`endpoint@1`；`drivers/usb/roles/class.c` 无 endpoint/fwnode_graph 查找 | **未合入**（v10 已被 v11 supersede：patchwork `15007992/93/94`） |
| dwc3 v10 | `20261121022104.1507987-1..4` | 4/4（上一轮已核，本轮未重取） | 同上（同一份内容） | 已被 v11 取代 |
| **elden DTS v7** | `20261117052029.31900-1`（`14991580`，state=new） | **命中**（10415 B，Subject 逐字） | `qcom/linux:for-next` 的 `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` = **HTTP 404**；`linux-next:master` 同路径 = **404** | **未合入**；patchwork **comments = 0**（无人评） |
| **mdss v5** | `20261113155635.1677541-2/-3/-4` | **3/3 命中** | `drm/msm:msm-next` 的 `drivers/gpu/drm/msm/msm_mdss.c` 仍是单枚 `reset_control_get_optional_exclusive(dev, NULL)`（v5 引入的是 `devm_reset_control_array_get`）⇒ 无该逻辑 | **未合入**；arm-msm 3/3 comments=0，dri-devel 1/3 有 1 条 sashiko（11-13） |
| **fastrpc v3** | `20261111035731.940893-1`（`14971025`，state=new） | **命中**（7539 B） | `linux-next:master` `sm8750.dtsi`：`grep -c non-secure-domain` = **1**，唯一那处（第 6419 行）在 **cdsp** 的 `fastrpc` 子节点内；adsp 仍无 | **未合入**；comments = **0**（11-11 起 12 天） |

复跑命令（本轮原样）：

```bash
timeout -k 10 300 python3 scripts/lore-fetch-raw.py all <MID> -o /tmp/lore-…
for f in drivers/usb/dwc3/core.c Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml \
         drivers/gpu/drm/msm/msm_mdss.c arch/arm64/boot/dts/qcom/sm8750.dtsi \
         arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts; do
  timeout -k 5 90 curl -sSL --noproxy '*' -o /tmp/ng_$(basename $f) -w "%{http_code} $f\n" \
    "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain/$f?h=master"; done
timeout -k 5 90 curl -sSL --noproxy '*' -o /tmp/un_core.c \
  "https://git.kernel.org/pub/scm/linux/kernel/git/gregkh/usb.git/plain/drivers/usb/dwc3/core.c?h=usb-next"
timeout -k 5 90 curl -sSL --noproxy '*' -o /tmp/qc_elden.dts \
  "https://git.kernel.org/pub/scm/linux/kernel/git/qcom/linux.git/plain/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts?h=for-next"
timeout -k 5 90 curl -sSL --noproxy '*' -o /tmp/msm_mdss.c \
  "https://gitlab.freedesktop.org/drm/msm/-/raw/msm-next/drivers/gpu/drm/msm/msm_mdss.c"
```

> 坑（本轮再确认）：`git.kernel.org/.../plain/…?h=…` 需 **`-L`**（裸请求返 **301** 且 0 字节，会被误读成"文件不存在"）；lore 的 `curl` 仍 403（Anubis），必须走 `scripts/lore-fetch-raw.py`。

---

## §5 GitLab（Mobian / phosh / phoc）

### 5.1 `mobian1/droid-juicer`（gitlab.com，project id 41929225）

| 项 | 值 |
|---|---|
| 项目 | `last_activity_at` = **2026-11-21T09:31:15Z**（= 我们 `!46` 的开 MR 时刻，之后项目无活动），default_branch `master`，19 forks |
| **`!46`（我方）** | <https://gitlab.com/mobian1/droid-juicer/-/merge_requests/46> — state **opened**，`draft=false`，`user_notes_count` = **0**，`updated_at` = 2026-11-21T09:31:15Z ⇒ **2 天零评论、零 reviewer** |
| 其他 opened MR | `!45`（beryllium 传感器，10-11，0 note）· `!36`（fw 路径主线化，09-03，8 note，仍 open）· `!35`/`!22`/`!2`（Draft，最老 2023） |
| opened issues（7） | `#16` per-device post-processing、`#14` firmware postprocessing（11-31/11-01 有活动）、`#13` fairphone-fp4、`#11` sdm845 路径、`#10` initramfs、`#6` MAC、`#1` ideas；**无 elden 相关 issue** |
| 是否阻塞我方 | **否**。注意 `#16`（per-device post-processing）与我们的"故意不覆盖 4 项"取舍同题，将来维护者可能引用它回答我们的问题，投递前值得读一遍 |

### 5.2 `Mobian-team/mobian-recipes`（salsa.debian.org，project id 71384）

| 项 | 值 |
|---|---|
| opened MR（15） | 最新活动 `!173`（Lomiri CI，2026-11-22T09:33Z）；其余为 build/CI/extract 类，**无我方 elden/MR** |
| opened issue（16） | 最新 `#61`（CI 漏 image job，2026-07-26）；**无 elden 相关** |
| 是否阻塞我方 | **否**。MR-2（`wip.toml`）按 11-22/11-23 结论继续与内核分支同批，不单独投 |

### 5.3 phosh / phoc（gitlab.gnome.org）

| 项 | 值 |
|---|---|
| **phosh `!2005`**（我方） | <https://gitlab.gnome.org/World/Phosh/phosh/-/merge_requests/2005> — state **opened**，`draft=false`，created 2026-11-14T12:51:03Z，`updated_at` = 2026-11-14T13:14:53Z（此后无动静），`user_notes_count` = **1**，`detailed_merge_status` = **`need_rebase`** |
| 判读 | ① 上游 `main` 已前进 ⇒ 若后续要推动，**必须先 rebase 再说话**（否则重复 `!820` 那次的返工）；② 唯一那条 note 性质**未确认**（401，见 §0 未确认 1）；③ 一周零人工回复，符合 phosh 侧「小修不急」的节奏，不是被拒 |
| **phoc `#302`** | <https://gitlab.gnome.org/World/Phosh/phoc/-/work_items/302> — state **opened**，created **2022-10-10T15:40:55Z**，`updated_at` **= created_at**（四年零活动），`user_notes_count` = **0** ⇒ 完全无人碰 |
| 判读 | 该条讲的是「装了 IME 后 OSK 不提层」= **层叠遮挡**，与我们 11-10/11-11 报告已判定的「不是"不弹"根因」一致；本轮不改变结论，**不阻塞**我们自己的 IME 方案（A2/A3 路线） |
| phoc `!820`（历史） | 已合并（10-31，`1ef2711f`，进 0.59 线）；本轮未重查 |

---

## §6 一句话总账

**代码面这 48 小时没有任何新的技术欠账**（sashiko 对 v11 2/3、3/3 明说 no issues；v10 三题 + 3/3 一题已闭合）；
唯一的真问题在**投递工艺**：v11 顶着 krzk 三天前的两条流程批评照原样发出，sashiko 又独立判了一模一样的 `[Low]`；
同时三名外部 reviewer 里最有价值的一件（Joonhoe Kim 对 aw86927 三枚补丁的 `Tested-by`）还躺在 INBOX 里没进任何版本。
四个重点系列在维护者树/linux-next 上**全部未合入**（内容级现查），Mobian `!46` 仍在等维护者，phosh `!2005` 需先 rebase。

---

## §7 本轮命令台账（复跑用；全部带 `timeout -k`，全部只读）

```
timeout -k 10 900 python3 /tmp/e2_mail.py            # IMAP 三判据 + Sent Items 窗口 MID（8）
timeout -k 10 900 python3 /tmp/e2_pass3.py           # 历史 242 MID × INBOX+Junk → 9 封唯一回信
timeout -k 10 300 python3 /tmp/e2_body.py <MIDs…>    # BODY.PEEK 取全文（sashiko v11 / krzk / aw86927 三封）
timeout -k 10 300 python3 scripts/lore-fetch-raw.py all <5 MIDs> -o /tmp/lore-check2
timeout -k 10 300 python3 scripts/lore-fetch-raw.py {all,linux-usb,linux-devicetree,linux-arm-msm} <v11 cover/1-3>
timeout -k 5 40 curl -sS --noproxy '*'  patchwork.kernel.org/api/1.2/patches/{14991580,14971025,14980387..9,15007992}/…
timeout -k 5 40 curl -sS --noproxy '*'  patchwork.kernel.org/api/1.2/patches/<id>/comments/
timeout -k 5 90 curl -sSL --noproxy '*' {next/linux-next,gregkh/usb,qcom/linux} plain 文件 + drm/msm msm-next raw
timeout -k 5 40 curl -sS --noproxy '*'  gitlab.com/api/v4/projects/41929225/{merge_requests,issues}
timeout -k 5 40 curl -sS --noproxy '*'  salsa.debian.org/api/v4/projects/71384/{merge_requests,issues}
timeout -k 5 40 curl -sS --noproxy '*'  gitlab.gnome.org/api/v4/projects/{16747,World%2FPhosh%2Fphoc}/…
```

**未做**（按只读与授权边界）：任何 `send-mail`/`git send-email`、任何回复、任何 MR/fork/push、任何设备动作、任何 `git commit`、除本报告外的任何文件写入。
