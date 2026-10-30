# 上游邮件分诊 — 2026-10-29 → 2026-10-30 03:17Z

> 用户 2026-10-30 要求。角色：只读分诊。**未发任何邮件**、未改订阅/凭据、未碰设备、未改 TASKS/DEVICE/INDEX/PITFALLS/versions/README、未提交 git。
> 上游化状态页（逐系列权威）= `reports/upstream-status-20261029.md`；本文件只记**这两天的增量信件与分诊**。

---

## §0 检索口径（先给范围，再给结论）

| 项 | 值 |
|---|---|
| 通道 | IMAP `mail.ustc.edu.cn:993`，凭据走 GNOME keyring（`smtp.ustc.edu.cn:465` 复用），**只读**（`BODY.PEEK`） |
| 文件夹 | `INBOX` / `"Junk E-mail"` / `"Sent Items"` |
| 时间窗 | `SINCE 27-Oct-2026`（工具最小窗；本报告只取 **10-29 00:00Z – 10-30 03:17Z** 为「今日」） |
| 头扫描量 | INBOX **2310** 封（列表流水为主）/ Junk **169** / Sent Items **32** |
| 主工具 | `~/.local/bin/read-mail-ustc.py --days 3 --limit 80`（用其 `--days/--folders/--grep`，见 §0.1） |
| 补强检索 | 服务端 `SEARCH SINCE … HEADER In-Reply-To "mail.ustc.edu.cn"`（**本轮不用 `--replies-only`**：其 `OUR_IDS` 硬编码 3 个 10-13 Message-ID，`PITFALLS #461`，换系列必漏） |
| 主题兜底 | `SUBJECT` 检索：`mdss-common` / `dispcc` / `aw86927` / `wl2868c` / `elden` / `bonded` / `mu_wide_platforms` / `UEFI` |
| patchwork | `patchwork.kernel.org/api/1.2`（匿名 200）；`patchwork.linuxtv.org/api`（Anubis PoW，用 `lore-query.py` 的 fetch 过挑战后 200）。**只读，无写操作** |
| 未做 | 任何 send/send-email/reply、改订阅、`git credential`、设备访问 |

### 0.1 `read-mail-ustc.py` 用法（本轮实测要点）

```
python3 ~/.local/bin/read-mail-ustc.py --days 3 --limit 80                 # 三文件夹近 3 天头表
python3 ~/.local/bin/read-mail-ustc.py --days 3 --folders INBOX --grep camss
python3 ~/.local/bin/read-mail-ustc.py --days 3 --replies-only             # ← 本轮弃用，见上
```
- 只输出头（DATE/FROM/SUBJECT/Message-ID/In-Reply-To/References），不取正文；正文另用只读 `BODY.PEEK[]` 抓，落 `/tmp`（不入库）。
- `Junk E-mail` 必须带引号才能 `select`；列表信常被标 `[SPAM]`。
- 近 3 天 INBOX 中**与本项目无关的私有邮件（校内作业/请假/实验室）已跳过，未记录内容**。

---

## §1 今日相关邮件（10 封外部 + 3 批我方出站）

### 1.1 外部来信（全部为上游/评审往来）

| # | 日期(UTC) | 发件人 | 列表 | Subject | Message-ID | 关联系列 | 一句结论 | 待办 |
|---|---|---|---|---|---|---|---|---|
| 1 | 10-29 07:07 | Krzysztof Kozlowski | linux-media + linux-arm-msm + devicetree（回信仅 To 我方+Bryan） | `Re: [PATCH v2 0/9] media: camss: add SM8750 support` | `<fe9765cf-ef10-4068-ad43-26346d842c12@kernel.org>` | M4 camss | 对我方 10-28 20:09 那封（`179325717815…`）只回了一句：**「What are you referring to? I'll just drop this.」** | **必须在回信里把话题重新锚定**（哪一问、哪一版），否则此线程作废 |
| 2 | 10-29 08:55 | Krzysztof Kozlowski | linux-regulator + devicetree（To 仅我方） | `Re: [PATCH v2] regulator: dt-bindings: willsemi,wl2868c: add the WL2868C camera PMIC` | `<20261029-amiable-loutish-wolf-60a76a@quoll>` | wl2868c binding v2 | **「Please respond to comments from previous version. And not with LLM. I still see no users of this binding.」**（三条硬要求：逐条回应 v1 意见 / 不要 LLM 口气 / 必须给出使用者） | 答复前先解决「users」= driver 系列或板 DTS 引用；见 §3-D2 |
| 3 | 10-29 07:53 | Shuai Liu | linux-media + linux-arm-msm | `Re: [PATCH 2/9] media: camss: csiphy: add CSIPHY 2.4.0 lane settings…` | `<tencent_D8BA93484FB26CC87737CDE3FA8A814DE00A@qq.com>` | M4 camss（v1 1/9） | 提交信息与表**自相矛盾**：正文说 SKEW_CAL 用 0x00，patch 2 实际写 0x54，0x00 的更正埋在 patch 4/9 | 拆片自洽：patch 2 直接写最终值；csiphy hunk 从 4/9 撤掉 |
| 4 | 10-29 07:54 | Shuai Liu | linux-media + linux-arm-msm | `Re: [PATCH 4/9] media: camss: csid: add the 980 generation` | `<tencent_E9EEF3D2AF2C6DF28E4DC1B855625913D908@qq.com>` | M4 camss（v1 4/9） | patch 4 实际改 **6 个文件**，混入 2/9 的 csiphy 更正 + 5/9、8/9 的 vfe 铺垫，与提交信息不符 | 同类拆片问题（与 #3 同一根因） |
| 5 | 10-29 07:54 | Shuai Liu | linux-media + linux-arm-msm | `Re: [PATCH 8/9] media: camss: vfe: add the gen4 block…` | `<tencent_3B08CBAEFC7B931B6E90D8D8C4BF3BB1B406@qq.com>` | M4 camss（v1 8/9） | 三条实质：**① interconnect 表只有 ahb/hf_mnoc 两路，而 binding+DTS 声明四路**（sf_mnoc、sf_icp_mnoc 永不投票）；② 提交信息实例计数错（实际 3 full + 2 lite CSID、3 full + 2 lite VFE） | 真正有价值的 finding：**binding/DTS 与驱动资源表必须二选一对齐**（sm8650 是先例） |
| 6 | 10-29 07:54 | Shuai Liu | linux-media + linux-arm-msm | `Re: [PATCH 9/9] arm64: dts: qcom: sm8750: add the camera subsystem` | `<tencent_448218F104903BBC74140B91BC5B93362E06@qq.com>` | M4 camss（v1 9/9） | 节点与 binding schema 对得上（19 ranges / 35 clk / 16 irq / 4 icc / 4 pd）；只有「五个 CSID 不是四个」的计数笔误 | 文字级修正 |
| 7 | 10-29 09:37 | Bryan O'Donoghue | linux-media + linux-arm-msm | `Re: [PATCH 0/9] media: camss: add SM8750 support` | `<f3a1ad00-5c74-4922-9c65-dd7a56c72582@linaro.org>` | M4 camss（v1 cover） | **明确表态：这个 enable 系列走 Hangxiang 的投稿**，「有后续修复请在它之上单独提」 | 与我方 10-29 只留 3 枚通用修复的决策**一致**；后续只发 fix 形态 |
| 8 | 10-29 13:01 | Loic Poulain | linux-media + linux-arm-msm + lkml | `Re: [PATCH 2/3] media: camss: video: check that a buffer is DMA contiguous…` | `<CAFEp6-0sLQfiNP8e+3+ZEXnjPG4GzJSPtiyEGfG2tXt-DuptGw@mail.gmail.com>` | M4 camss 3-fixes（2/3） | 质疑前提：**「你测过非连续的情况吗？设备看到的是 IOVA，仍是连续的」**，怀疑与帧下采样有关 | 与 #9 同一条：判据错在「物理连续」 |
| 9 | 10-29 14:02 | Bryan O'Donoghue | linux-media + linux-arm-msm + lkml | `Re: [PATCH 2/3] media: camss: video: check that a buffer is DMA contiguous…` | `<4d7de0cb-4a88-4af2-a407-a53d060d04a8@linaro.org>` | M4 camss 3-fixes（2/3） | **NAK，带实测反证**：代码查的是 IOVA 连续（应 `sg_phys()` 才谈物理）；他机器上 plane0 = 11 677 696 B、6 CPU entry、**5 处物理断裂、最大物理 run 8 MiB**，仍只有 1 个 DMA 段、0 IOVA 断裂 ⇒「约束 IOVA 必须物理连续可证伪」 | **patch 2/3 撤**；prepare hook 若要保留必须另立理由 |
| 10 | 10-29 15:00 | Loic Poulain | linux-media + linux-arm-msm + lkml | `Re: [PATCH 3/3] media: camss: video: stop the subdevices already started when a start fails` | `<CAFEp6-1dRNJ9rr5JWJ0W-XawtE1nby14a-ndCyCxEnd0K=gSYQ@mail.gmail.com>` | M4 camss 3-fixes（3/3） | 方向认可，建议**做成通用 helper** `camss_video_subdevs_set_stream(…, bool)`，并改用 `v4l2_subdev_enable_streams()/disable_streams()` 与 `media_entity_remote_source_pad_unique()`（别再依赖 `pads[0]`） | 是 3/3 的形态要求（不是 NAK），构成 v2 的形状 |

### 1.2 我方出站（今日，均为已批准批次；此处只登记，不重复批准）

| 时间(UTC) | 内容 | Message-ID | 归档 |
|---|---|---|---|
| 10-29 12:30 | `Re: [RFC PATCH] clk: qcom: dispcc-sm8750: reset the MDSS blocks…`（回 Abel 的第二封） | `<179327704077.28331.12487991903259233990@mail.ustc.edu.cn>` | Sent Items 可见 |
| 10-29 12:31 | `[PATCH 0/3] media: camss: three fixes for the CSID power and VFE streaming paths` + 3 枚 | `<20261029123107.28705-1..4@mail.ustc.edu.cn>` | lore `/all/`、patchwork series 32827（linuxtv） |
| 10-29 12:32 | `[PATCH v2 0/3] drm/msm + dt-bindings: describe and reset all MDSS block resets` + 3 枚 | `<20261029123238.29877-1..4@mail.ustc.edu.cn>` | patchwork 1196231/1196234/1196472 |

---

## §2 四项特别判定

### ① sashiko 对已投系列是否有新 finding —— **无新 finding（0 条）**

- sashiko-bot 对我方的**最后一次**回评 = **2026-10-28 09:53Z**（`Re: [PATCH v2 8/9] … vfe: add the gen4 block`，`<sashiko-outbox-187701@kernel.org>`）。命中集：10-27 的 aw86927 4/5、5/5；10-28 的 v1 1/4/5/8/9 与 v2 2/4/8。
- **10-29 两批新投（3-fixes 12:31Z、M8 v2 12:32Z）到 10-30 03:17Z 无任何 sashiko 回评**：以 `SEARCH SINCE 27-Oct FROM "sashiko-bot@kernel.org"` 全量取头，再按本系列关键词过滤，最后一条即上述 10-28。
- 口径限定：sashiko 只抽评（v1 9 枚只回了 4 枚、v2 9 枚只回了 3 枚）⇒ **「0 条」= 没有新评论，不等于通过**。
- 既有 10-28 的 8 条 finding 已逐条处置（4 真 bug 已修并上机复验），见 `reports/m4-sashiko-triage-20261028.md`；其中针对 2/9 CSIPHY 与 4/9 csid-980 的条目**随该两枚的放弃而失效**。

### ② M8 v2 与 camss 三枚通用修复的 maintainer 回信

| 系列 | 结果 | 证据 |
|---|---|---|
| **M8 dispcc/mdss v2**（`20261029123238.29877-1..4`，10-29 12:32Z） | **0 回信**（Abel Vesa / Dmitry Baryshkov / Rob Clark / Krzysztof / dri-devel 均无） | IRT 检索 + `SUBJECT "mdss-common"` / `"dispcc"` 双查；Abel 的 RFC 线程里我方 10-28 11:57Z + 10-29 12:30Z 两封回信**均未被回** |
| **camss 三枚通用修复**（`20261029123107.28705-1..4`，10-29 12:31Z） | **3 封回信**：Loic 2/3 质疑、Bryan 2/3 **NAK**、Loic 3/3 形状建议 | 见 §1.1 #8/#9/#10 |

- 关键裁决信息：**Bryan 已把「SM8750 camss enable」整块让给 Hangxiang 的系列**（§1.1 #7）⇒ 我方在这条线上**只能以 fix 形态存在**，这与 10-29 只发 3 枚的决策一致；3 枚里 **2/3 已被 NAK**，实际可继续的只有 **1/3（csid 错误路径 unwind）与 3/3（起流失败回退）**。

### ③ wl2868c binding v2 是否有人答复 —— **有，且是硬要求**

- Krzysztof Kozlowski，10-29 08:55Z，`<20261029-amiable-loutish-wolf-60a76a@quoll>`，原文三条：
  1. **「Please respond to comments from previous version」** → 10-27/10-28 他给 v1 的两封意见（`<c8e6c0e7…>`、`<e63d7539…>`/`<0f60fcba…>`）**尚未被逐条答复**；
  2. **「And not with LLM」** → 对我方回信口气的明确警告（我方 10-28 两封机械回帖已触发）；以后这封必须**人工撰稿**；
  3. **「I still see no users of this binding」** → binding 必须有消费者（driver 或板 DTS 引用）。当前状态：driver 系列**已备未投**（`patches/upstream/wl2868c-driver-20261028/`），且 `reports/wl2868c-recovery-20261030.md` 记有**硬阻断**（3/3 板级 DTS 缺 `xo_board`/`sleep_clk`/`bi_tcxo_div2`/`bi_tcxo_ao_div2` 四个 fixed-clock ⇒ `sm8750-lenovo-elden.dtb` 编译 rc=2），即**「把 driver 一起发」这条解锁路径目前不成立**。
- patchwork 侧同步：wl2868c v2 = `changes-requested`（series 1195400），v1 = `changes-requested`（1194266）。

### ④ 是否有信要求我们重发/改形状 —— **有 4 类（3 类改形状、1 类要求重锚定）**

| 信 | 要求类型 | 具体 |
|---|---|---|
| #9 Bryan（2/3） | **撤回** | `NAK`：DMA 连续性检查判据错（查 IOVA 却声称物理连续），有实测反证 |
| #10 Loic（3/3） | **改形状** | helper 化 + `v4l2_subdev_enable_streams()` + `media_entity_remote_source_pad_unique()` |
| #2 Krzysztof（wl2868c） | **改形状 + 重发前条件** | 逐条回应旧意见 / 不用 LLM / 必须带使用者 |
| #1 Krzysztof（camss 0/9） | **重锚定（不是重发补丁）** | 「What are you referring to? I'll just drop this.」= 他没看懂我方那封回信在答什么 |
| #3–#6 Shuai Liu | **拆片自洽（若仍要发同类内容）** | SKEW_CAL 值前后矛盾、csid-980 提交混入他片 hunk、icc 表与 binding 不一致、实例计数笔误 |

**没有任何一封信要求「整系列重发 vN」**：唯一接近的是 Bryan 说的「请在 Hangxiang 的系列之上提 fix」，即**只接受 fix 增量**。

---

## §3 需要用户拍板的投递动作（agent 不发信，逐条待批准）

> 全部动作都是**发信/改 patchwork 状态**，按 `.pi/AGENT-OPS.md` §1「上游发送按批批准」+ TASKS §7 口径执行。默认建议已给出，但**不批准即不动**。

| # | 动作 | 对象 | 触发事实 | 建议 | 状态 |
|---|---|---|---|---|---|
| **D1** | camss 3-fixes 出 **v2**：撤 2/3，保留 1/3；3/3 按 Loic 重构为通用 `camss_video_subdevs_set_stream()`（`v4l2_subdev_enable_streams` + `remote_source_pad_unique`） | linux-media / linux-arm-msm / lkml | §1.1 #9 NAK、#10 形状建议 | **建议做**：1/3 与 3/3 无人反对，重构后是干净 fix；2/3 整枚丢弃（不要试图「改成 sg_phys 版」——Bryan 的反证是说整个前提不成立） | `[需点头]` |
| **D2** | 回 Krzysztof 的 camss 信：把「上一封在答什么」重述清楚（哪一问 / 哪一版），并确认「enable 部分不再由我方推进，只跟 fix」 | 仅回信，不重发补丁 | §1.1 #1 | **建议做**，纯澄清、零技术承诺；否则此线程被封 | `[需点头]` |
| **D3** | 回 Krzysztof 的 wl2868c 信：**人工撰稿**逐条回应 v1 两封意见 + 说明使用者从哪来 | 仅回信 | §1.1 #2 | **建议先答后发**：可先答「使用者 = 板 DTS 的 8 条 `*-supply`（LDO7 扇出 3、LDO6 空置）+ driver 系列将随行」；但**不要承诺紧随其后的 driver 投递**，因为 DTS 四个 fixed-clock 缺失未修 | `[需点头]` |
| **D4** | 是否投 wl2868c **driver 系列**（`patches/upstream/wl2868c-driver-20261028/`，cover + binding 重发 + driver） | linux-regulator / devicetree | §2③ + `reports/wl2868c-recovery-20261030.md` | **建议暂不投**：先修 `sm8750-lenovo-elden.dtb` 的 4 个 fixed-clock（rc=2 是硬门），否则 driver 投出去也带不动消费者证据 | `[需点头]` |
| **D5** | patchwork 状态清理：把 **camss v2（linuxtv series 32734，9 枚 `under-review`）** 与 M4-1 bindings 的过期拷贝标 superseded/撤销 | patchwork.linuxtv.org / kernel.org | §4 | 需登录会话；API 写 403（无凭据）。**只能人工点**，或由用户提供可用的写通道 | `[需人工]` |
| **D6** | M4 camss 后续是否还跟 Shuai Liu 的 4 条意见（#5 的 icc 表不一致是唯一实质） | 我方内部 | §1.1 #3–#6 | **建议只吸收 #5**：binding/DTS 的四路 icc 与驱动 `icc_res_sm8750[]` 两路必须二选一对齐——但该系列已让给 Hangxiang，故只作为**给 Hangxiang 的 fix 素材**备着 | `[建议]` |

> 无动作项（明确「等」而非「漏」）：M1-U6（remoteproc，2 份拷贝均 `new`）、M2-A2（`handled-elsewhere`）、M3-1 v4（`new` / DT `needs-ack`）、aw86927 v2（10-27 后仅 Krzysztof binding 意见 + sashiko 2 条，均未回）、M4-1 bindings（10-28 `changes-requested` 待答）、M6 B5（用户已裁「暂不启动」）、UEFI issue#12（本轮 0 封 GitHub 通知）。

---

## §4 patchwork 只读核对（未做任何写操作）

> 判据字段 = 每枚 patch 的 `state`。匿名 `GET /api/1.2/patches/?submitter=xiaqinghuan@mail.ustc.edu.cn`；linuxtv 侧过 Anubis 后同法。
> **写权限不可用**（无 token，历史实测 403），因此下表是**读到的现状**，不是我们改成什么样。

### 4.1 逐系列（`patchwork.kernel.org` 镜像项目 / `patchwork.linuxtv.org` 权威 media 项目）

| 系列 | Message-ID 根 | kernel.org 镜像 | linuxtv（media 权威） |
|---|---|---|---|
| M3-1 **v4**（3 枚） | `20261026123211.243224-*` | arm-msm 1193719 = **new ×3**；linux-usb 1193720 = **new ×3**；devicetree 1193723 = 1/3 **needs-ack**、2–3/3 handled-elsewhere | —（非 media） |
| aw86927 v2（5 枚） | `20261027132929.242158-*` | Linux Input 1194635 = **new ×5**；devicetree 1194640 = 2/5 **not-applicable**、其余 handled-elsewhere | — |
| M1-U6 remoteproc（1 枚） | `20261027132944.242550-1` | Remoteproc 1194634 = **new**；arm-msm 1194636 = **new** | — |
| M2-A2 battmgr（1 枚） | `20261027132949.242685-1` | 1194637 / 1194638 = handled-elsewhere（已转交） | — |
| M4-1 bindings（2 枚） | `20261027051048.213177-*` | devicetree 1194267 = **changes-requested ×2**；V4L/DVB 1194271 = new ×2 | 32644 = **new ×2** |
| wl2868c binding **v1** | `20261027051055.213301-1` | devicetree 1194266 = **changes-requested**；V4L/DVB 1194272 = new | 32641 = **new** |
| wl2868c binding **v2** | `20261028120442.99375-1` | devicetree 1195400 = **changes-requested**（与 §2③ 一致） | — |
| M4 camss **v1**（9 枚） | `20261028034105.326535-*` | V4L/DVB 1195087 = **superseded ×9**；arm-msm 1195089 = superseded ×9；devicetree 1195091 = superseded ×9 | 32716 = **superseded ×9** ✔ |
| M4 camss **v2**（9 枚，未推进） | `20261028093003.722745-*` | V4L/DVB 1195271 = **superseded ×9** | 32734 = **`under-review` ×9** ⚠ |
| M4 camss **3-fixes**（3 枚） | `20261029123107.28705-*` | arm-msm 1196230 = **new ×3**；V4L/DVB 1196232 = **new ×3** | 32827 = **new ×3** |
| **M8 v2** mdss resets（3 枚） | `20261029123238.29877-*` | arm-msm 1196231 = **new ×3**；devicetree 1196234 = 1/3 **needs-ack**、2–3/3 handled-elsewhere；dri-devel 1196472 = **new ×3** | — |

### 4.2 两个需要注意的不一致

1. **camss v2 在 media 侧仍是 `under-review`，不是 `superseded`** ——
   kernel.org 的活动镜像已把它标 superseded（被 10-29 的 3 枚同主题 fix 顶掉），但 linuxtv（真正派给 Mauro 的项目）仍显示 **9/9 under-review** ⇒ 评审者队列里**同时存在「已宣布放弃的 v2」和「3 枚 fix」**。
   这与 `reports/camss-upstream-response-20261028.md` 记录的「v1 未标 Superseded（API 403 无凭据）」是**同一类问题**的另一半：v1 这次已被自动标掉，v2 还没有 ⇒ **需人工点**（§3-D5）。
2. **M3-1 v4 的 devicetree 1/3 是 `needs-ack`、linux-usb 全 `new`** —— 即 DT 维护者尚未 ack，USB 侧无人处理；与「v4 后 0 回复」一致（§5）。

---

## §5 「无回复」的检索范围与判据（不写「大概没人回」）

检索窗：**2026-10-27 00:00Z → 2026-10-30 03:17Z**（IMAP `SINCE 27-Oct-2026`），三文件夹全查（INBOX 2310 / Junk 169 / Sent 32 封头），判据 = `In-Reply-To`/`References` 命中我方该系列 Message-ID **或** 主题命中该系列并带 `Re:`。Junk 命中 **0**（故无「回信被丢垃圾箱」的可能性未排除项以外的空白）。

| 系列 | 最后一条外部来信 | 之后至今 | 判据 |
|---|---|---|---|
| **M1-U6**（remoteproc DTB fw 泄漏） | 无（投于 10-27 13:29Z） | **0 回信 / 3 天** | `HEADER In-Reply-To "mail.ustc.edu.cn"` 无 `20261027132944.242550` 命中；patchwork 两拷贝仍 `new` |
| **M2-A2**（battmgr power_now） | 无外部；仅我方 10-27 13:32Z 自回复 | **0 回信 / 3 天** | 同上（无 `20261027132949.242685` 命中）；patchwork `handled-elsewhere` |
| **M3-1 v4**（USB 双连接器） | 无（投于 10-26 12:32Z） | **0 回信 / 4 天**（含今日） | 无 `20261026123211.243224` 命中；DT 侧 `needs-ack` 未消 |
| **aw86927 v2**（5 枚） | **10-27 19:06Z Krzysztof**（binding 2/5）+ sashiko 10-27 13:37/13:55Z | **0 新回信 / 2 天** | 命中集止于 10-27；今日无新条目 |
| **M4-1 bindings**（gt9764 + s5kjns） | **10-28 14:29/14:31Z Krzysztof**（`changes-requested`） | **0 新回信 / 1 天** | 今日仅 camss 线程活动，binding 线程无新信 |
| **M4 camss**（v2 + 3-fixes） | 见 §1.1（今日 3 封） | 有回信 | — |
| **M6 B5**（bonded DSI 重构） | 无（RFC 未投；用户 10-29 裁「暂不启动」） | **0 回信** | `SUBJECT "bonded"` 近 3 天 **0** 命中 |
| **M8 dispcc/mdss** | **10-28 11:52Z Abel（RFC 3/3，其自有线程）**；我方两封回信未获回 | **v2 投后 0 回信 / ~15 h** | `SUBJECT "mdss-common"` 命中 1 封（= 我方）；`"dispcc"` 命中 4 封全为 10-28 旧线程 |
| **wl2868c** | **10-29 08:55Z Krzysztof**（见 §2③） | 有回信 | — |
| **wl2868c driver 系列** | 未投 | — | `patches/upstream/wl2868c-driver-20261028/` 仍在本地 |
| **UEFI issue#12** | 无 | **0 封 GitHub 通知 / 3 天** | `SUBJECT "mu_wide_platforms"`、`SUBJECT "UEFI"`、`FROM "github"` 三者近 3 天均 **0** 命中 ⇒ 该 issue 无新评论通知到本邮箱 |

> 判据纪律（沿用 `PITFALLS #461`）：本轮**未**使用 `read-mail-ustc.py --replies-only`；「0 回信」结论由服务端头域检索 + patchwork 状态**双证**，不是脚本单点。

---

## §6 一句话收口

今日相关外部邮件 **10 封**（Krzysztof 2 / Shuai Liu 4 / Bryan 2 / Loic 2），我方出站 3 批（3-fixes、M8 v2、回 Abel）。
**sashiko 无新 finding**；**M8 v2 无人回**；**camss 3-fixes 的 2/3 被 Bryan NAK**；**wl2868c v2 被 Krzysztof 以「逐条回应 + 不用 LLM + 必须有使用者」三条要求挡住**。
需用户拍板 **D1–D4**（D5 需人工网页操作，D6 仅建议），详见 §3，其中 **D1（3-fixes v2 撤 2/3）与 D3（人工撰稿回 Krzysztof）** 是唯一有实质进展的两条路径。
