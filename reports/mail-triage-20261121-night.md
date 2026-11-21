# 邮件/上游 夜间分诊（2026-11-21T02:00Z → 13:10Z，只收信与核对、**零发信**）

> 性质：只读 + 只起草。**未发任何邮件**、未 `git send-email`、未改订阅、未改 `TASKS/README.md`、
> 未 `git commit`、未碰设备。外部命令一律 `timeout -k`；IMAP 全 `BODY.PEEK`（不改已读）。
> 窗口起点 = 上一篇 `reports/mail-inbox-20261121.md` 的截止时刻（02:00Z），本篇只 **additive**。
> 数据源：USTC IMAP（INBOX / "Junk E-mail" / "Sent Items"）＋ lore raw（`scripts/lore-fetch-raw.py`，
> 过 Anubis）＋ patchwork REST 1.2 ＋ git.kernel.org ＋ GitLab REST。

---

## §0 结论（数字先行）

| 项 | 数字 / 事实 |
|---|---|
| 窗口内对我方的**唯一**新信 | **8 封**：我方 v10 自收副本 4 + sashiko 3（对 v10）+ krzk 1（对 v10 1/3） |
| **人类**回帖 | **1 封**，且是 🔴 **流程性否定**（Krzysztof Kozlowski，09:11Z） |
| **sashiko** 回帖 | **3 封**（02:33/02:40/02:40Z，v10 投后 12–19 分钟） |
| 退信 | **0**（`mailer-daemon`/`postmaster`/`noreply`/`bounce` 四判据窗口内全 0） |
| Junk 里漏网的我方线程信 | **0**（窗口内 Junk 8 封，无 qcom/我方命中） |
| lore 归档核对 | dwc3 v10 **4/4 × 3 个列表**在档；wl2868c v12 **3/3 在 arm-msm + devicetree**，**`/linux-regulator/` = HTTP 404** |
| 同区域竞争者（dwc3） | **0**（5 组关键词 × 3 项目，11-01 起只有我方代次） |
| wl2868c 上游最终形态 | **= 我们投的 v12，逐字节**（只有 rebase 造成的 `index`/行号差异；新文件 blob 一致） |
| `mobian1/droid-juicer !46` | **opened / 非 draft / mergeable / CI 3 job 全 success（09:31–09:34Z）/ 0 评论 0 reviewer** |
| **阻塞发信的项** | **1 个（两项机械改动）**：AI 披露须从 commit msg 移到 `---` 下；v11 须改**新线程** |
| 需回信吗 | **0 封必须单独回**——krzk 的两条都能用「下个版本本身」闭合（且单独回信大概率被当噪声） |

**一句话**：v11 的**代码**没问题（sashiko 对 v10 的四条全在 v11 里闭合），但 **v11 的"投法"被
krzk 09:11Z 提前否掉了**——披露位置和续投线程正是他点名的两点。改这两处（不动 diff）即可发。

---

## §1 逐线程

### 1.1 🔴 dwc3 v10 1/3 —— krzk 的流程否定（本窗口最重要）

`<20261121-icy-bright-partridge-afe8de@quoll>`，2026-11-21T09:11Z，`In-Reply-To` = v10 1/3。
三句原文：

```
This does not go to commit msg, but changelog.
You keep sending multiple revisions, this one even threaded to other
posting and still not really responding to feedbacks.
Feedback was waiting for three days and then you send the same. That's
just wasting our time.
```

- **K1 披露位置**：`grep -n "AI-assist\|^---$"` 三枚 patch → 披露段均在 `Signed-off-by` 之前
  （commit msg 内）。**v11 同样如此** ⇒ 必须移。
- **K2 续投线程**：v10 cover 的 `In-Reply-To` 是 v9 cover（lore raw 逐字可验），
  `GATES-v11.md` §5 还要求 v11 再挂到 v10 cover 上 ⇒ **正中批评**，改新线程。
- **K3「没在回应反馈」**：这条我方**有反证**——v11 的 `Changes since v10` 逐条点名 sashiko 四条
  （含一条「一半不成立」的实测反驳）。**不需要单独发信辩解**，下个版本带着走即可。
- 判读：他不是在要一个新版本，是在要「**别再用这套投法**」。因此本轮**不建议**为此单发一封回信。

### 1.2 sashiko 对 v10 ×3（02:33–02:40Z，均已被 v11 闭合）

```
<sashiko-outbox-226549@kernel.org>  1/3  3 条：Medium 无条件 hs-port $ref / Low $defs+驱动细节 / Low dr_mode required
<sashiko-outbox-226546@kernel.org>  3/3  1 条：Medium dwc3_drd_exit() 里 deselect 早于角色 teardown
<sashiko-outbox-226550@kernel.org>  0/3  系列汇总：2/3 no issues，1/3 三题、3/3 一题
```

对应 v11 的三处改动（本轮回读补丁正文核对，非引用 GATES 自述）：

| sashiko | v11 落点 | 复核命令输出 |
|---|---|---|
| Medium（1/3 无条件 `$ref`） | 顶层 `port@0` 回到通用 graph port，两 endpoint 只在 `mux-controls` 分支必填 | G6 正样例 4/4 → 0 诊断；v10-as-sent 对照下 2 个正样例被拒 |
| Low（`$defs`） | `grep -c '^$defs' v11-0001-*.patch` = **0**；`patternProperties` 在 | 见 §3 原始片段 |
| Low（`dr_mode` required） | `const: otg` 保留、移出 `required` | `gates/pos-no-dr-mode` 0 诊断 |
| Medium（3/3 deselect 顺序） | `dwc3_role_mux_deselect()` 挪到 `switch (dwc->current_dr_role)` 之后 | 0003 的 `dwc3_drd_exit()` hunk |

⇒ **v11 不需要再改代码**。这也是 K3 的实物证据。

### 1.3 wl2868c v12 —— 已进 `regulator.git for-7.5`，本窗口无新回帖

| 事实 | 判据 |
|---|---|
| `for-7.5` 分支含 merge「regulator: add the Will Semiconductor WL2868C camera PMIC」（Mark Brown）+ 我们两枚 + 无后续修正 | `log/?h=for-7.5` 文本命中三行（见 §3） |
| 上游两枚 commit 与 v12 **diff 正文逐字节相同**（只有 `index`/`@@` 行号因 rebase 变化；新文件 blob `9ffb08dcb…`（driver）、`972813fbd…`（yaml）一致） | `diff -u` 我方 2/2 vs `patch/?id=602f…` → 只剩 `index`/`@@`/`-- ` 三类差异 |
| linux-next `master` 已有该驱动 | `plain/drivers/regulator/wl2868c-regulator.c?h=master` → HTTP 200 / 9477 B |
| patchwork `linux-arm-msm` 副本仍 `state=new`/`commit_ref=None` | `14991614/14991615`（这是已知盲区，**不得**据此判未合入） |
| **v12 没有投 `linux-regulator` 列表**：`To: Liam Girdwood, Mark Brown` 直投；`/linux-regulator/<v12 cover>/raw` = **404** | 下方原始输出 |

⇒ 合入来自**直投维护者**，不是列表；后续对该文件只能按 Mark 的规矩发**增量补丁**（他 11-17 通知里明写）。
我方零技术欠账，只剩**文档回填**（`TASKS` §7 / D2 行仍写「等评审」——按硬约束本轮未改，交主会话）。

### 1.4 elden DTS v7 / aw86927 v2 / mdss v5 / fastrpc v3 / dsi-phy v2 / dpu gamma v2

窗口内**零新回帖**（人类与 bot 均无）。基线报告的未处置项原样保留：
- elden v7 的 sashiko 4 条：3 条随 wl2868c 合入自然消解，剩 `arm/qcom.yaml` 条目 + 字母序，**跟下一次板件重投一起做**。
- aw86927 v2 的 High（unbind 竞态）要动代码 ⇒ 属下一版工作，不是回信。
- mdss v5 的 sashiko 三份仍未逐条判别（`PATCHES` 侧欠账，非本 lane）。

### 1.5 `mobian1/droid-juicer !46`（非邮件通道，任务点名要查）

```sh
curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/41929225/merge_requests/46"
curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/xiaquwan1001%2Fdroid-juicer/pipelines/3097183213/jobs"
```

| 项 | 值 |
|---|---|
| 标题 / 分支 | `configs: add Lenovo Legion Y700 Gen4 (TB322FC)` / `configs/lenovo-elden` → `master` |
| 状态 | **opened，非 draft**，`detailed_merge_status=mergeable`，无冲突，创建 **2026-11-21T09:31Z** |
| 改动 | 单文件 `configs/lenovo,elden.toml`（new_file，+116 行） |
| CI | pipeline `3097183213` **success**；jobs：`check`(09:31:30) / `build`(09:33:18) / `test`(09:34:39) 全 success |
| 评审 | `user_notes_count=0`，`reviewers=[]`，`assignees=[]`，无 label ⇒ **维护者尚未看** |
| 描述自检 | 已写明「ADSP/CDSP 故意不列（TZ 拒单文件 `cdsp_dtb.mbn`）+ 未上机 + 板支持仍在上游化」 |
| 同类在飞 MR | `!45`(beryllium, 10-11)、`!36`(路径迁移, Draft 无)、`!35`/`!22`/`!2`（长期 Draft）⇒ 我方是唯一 novo-SoC 件 |

⇒ D2 行的「CI 绿等维护者」**与现查一致**；注意它在 `xiaquwan1001` 的 fork 上跑 CI，
所以后续若维护者要 rebase，**不能**在 fork 直接重推（会改 MR 的 head sha，CI 需重跑）。

---

## §2 建议动作与放行点

| # | 动作 | 谁做 | 是否需用户 |
|---|---|---|---|
| A1 | **改 v11 投法**：三枚 patch 的 AI 披露段移到各自 `---` 之下（cover 保留）；发信**不带** `--in-reply-to`（新线程）；cover 首段点一句「回应 sashiko 11-21 02:40Z 报告」 | mail-io（下一轮） | **需用户一句放行**（见下） |
| A2 | 若用户想要「先礼后兵」，可选：给 krzk 回一封 15 行以内的**纯流程**回信（认 K1/K2、不复述技术、不辩解 K3），再发 v11 | mail-io | 需用户点头；**默认不写**（他明说「别再浪费我们时间」，回信风险 > 收益） |
| B | **文档回填** wl2868c 已合入（`TASKS` §7 + D2 行 + `reports/upstream-recheck-20261120.md` 的「new 等评审」口径） | 主会话（本 lane 禁改 README） | 否 |
| C | `mobian-mr-plan` 补一条：`!46` 已开、CI 绿、0 评论 ⇒ 下一步只是**等**，别再动 fork | 主会话/文档 lane | 否 |
| D | 不投 0004（板 DTS）、不单独 ping 任何人（§7 口径：随版带走） | — | — |

### 放行点（用户只需说这一句）

> **「dwc3 v11 可以发：先把 AI 披露移到 `---` 下（三枚各一处）+ 改用新线程，然后投 4 封。」**

明细、收件人、References 方案、附件顺序、发后复核，全部已落
`patches/upstream/dwc3-v11-20261121/SEND-CHECKLIST.md`。

---

## §3 Verify：lore / 外部状态**原始输出片段**

**① dwc3 v10 四封在档（`all` 聚合；三列逐个另验）**

```
  1    13562 B  Subject: [PATCH v10 0/3] usb: dwc3: support two connectors sharing one HS data  -> /tmp/lore-v10/1.raw
  2    12239 B  Subject: [PATCH v10 1/3] dt-bindings: usb: snps,dwc3: describe two connectors   -> /tmp/lore-v10/2.raw
  3     8838 B  Subject: [PATCH v10 2/3] usb: roles: look up role switches attached to a graph  -> /tmp/lore-v10/3.raw
  4    28783 B  Subject: [PATCH v10 3/3] usb: dwc3: select the shared HS data bus with a mux c  -> /tmp/lore-v10/4.raw
```

```
== linux-usb
  1    13562 B  Subject: [PATCH v10 0/3] ... /tmp/chk-linux-usb/1.raw
== linux-devicetree
  1    13569 B  Subject: [PATCH v10 0/3] ... /tmp/chk-linux-devicetree/1.raw
== linux-arm-msm
  1    13590 B  Subject: [PATCH v10 0/3] ... /tmp/chk-linux-arm-msm/1.raw
```

`/tmp/lore-v10/1.raw` 头（证明是 v10 且串到 v9）：

```
From: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
Date: Sat, 21 Nov 2026 10:21:01 +0800
Message-ID: <20261121022104.1507987-1-xiaqinghuan@mail.ustc.edu.cn>
X-Mailer: git-send-email 2.53.0
In-Reply-To: <20261117052137.32833-1-xiaqinghuan@mail.ustc.edu.cn>
List-Id: <linux-usb.vger.kernel.org>
```

**② wl2868c v12 三封在档 + `linux-regulator` 404**

```
  1     9428 B  Subject: [PATCH v12 0/2] regulator: add the Will Semiconductor WL2868C camera   -> /tmp/lore-wl12/1.raw
  2     9947 B  Subject: [PATCH v12 1/2] regulator: dt-bindings: willsemi,wl2868c: add the WL2  -> /tmp/lore-wl12/2.raw
  3    20066 B  Subject: [PATCH v12 2/2] regulator: willsemi,wl2868c: add the WL2868C camera P  -> /tmp/lore-wl12/3.raw
```

```
== linux-regulator
urllib.error.HTTPError: HTTP Error 404: Not Found        ← v12 未投该列表（To: Liam + Mark 直投）
== linux-devicetree   → 1 9407 B 命中
== linux-arm-msm      → 1 9428 B 命中
```

`/tmp/lore-wl12/1.raw` 的 To/Cc：

```
To: Liam Girdwood <lgirdwood@gmail.com>,
	Mark Brown <broonie@kernel.org>
Cc: Rob Herring <robh@kernel.org>,
	Krzysztof Kozlowski <krzk+dt@kernel.org>,
	Conor Dooley <conor+dt@kernel.org>,
	linux-kernel@vger.kernel.org, devicetree@vger.kernel.org,
	linux-arm-msm@vger.kernel.org
```

**③ wl2868c 上游最终形态 = 我们的 v12（diff 正文逐字节）**

```
== v12-0002-regulator-willsemi-wl2868c-add-the-WL2868C-camer.patch
-index 435beaf95..5a3913c45 100644
+index 174d445feba23..55a9fffa09749 100644
-@@ -29063,6 +29063,7 @@ M:	Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
+@@ -30195,6 +30195,7 @@ M:	Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
-index 000000000..9ffb08dcb
+index 0000000000000..9ffb08dcbf655      ← 新文件 blob 相同
-2.53.0
+cgit 1.3.1-korg
== v12-0001-...-dt-bindings-...
-index 000000000..972813fbd
+index 0000000000000..972813fbd78c8      ← 新文件 blob 相同
```

**④ `regulator.git for-7.5` 含我方两枚 + 合并提交，无后续修正**

```
regulator: add the Will Semiconductor WL2868C camera PMIC  Mark Brown    4 days
regulator: willsemi,wl2868c: add the WL2868C camera PMIC driver  Qianhui Xu 4  4 days
regulator: dt-bindings: willsemi,wl2868c: add the WL2868C camera PMIC  Qianhui Xu 2  5 days
```

**⑤ v11 的两项发前改（多源可验）**

```
$ grep -c '^\$defs' patches/upstream/dwc3-v11-20261121/v11-0001-*.patch
0
$ sed -n '26,31p' patches/upstream/dwc3-v11-20261121/v11-0001-*.patch
*** AI-assistance disclosure ***
This patch was prepared with the help of an LLM coding assistant.  The
author reviewed every line and ran the gates quoted in the series notes.

Signed-off-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
---
                                    ↑ 披露在 Signed-off-by 之前 = commit msg 内（krzk K1 违例）
```

**⑥ 竞争者检索（5 组关键词 × 3 项目，只出我方代次）**

```
== q=two+connectors
   1201271 v1 2026-11-04T03:27:03 | xiaqinghuan@mail.ustc.edu.cn | usb: dwc3: two Type-C connectors sharing one HS data bus
   1213435 v9 2026-11-17T05:21:36 | xiaqinghuan@mail.ustc.edu.cn | ...
   1217901 v10 2026-11-21T02:21:02 | xiaqinghuan@mail.ustc.edu.cn | [v10,1/3] dt-bindings: usb: snps,dwc3: ...
== q=snps,dwc3+mux / usb-role-switch+endpoint / dwc3+mux-controls / shared+HS+data+bus
（无输出）
```

**⑦ patchwork：v10 三枚 `new` / `commit_ref=None`；wl2868c v12 两枚同态**

```
15007992 new 2026-11-21T02:21:02 cref= None | [v10,1/3] dt-bindings: usb: snps,dwc3: describe two con
15007994 new 2026-11-21T02:21:03 cref= None | [v10,2/3] usb: roles: look up role switches attached to
15007993 new 2026-11-21T02:21:04 cref= None | [v10,3/3] usb: dwc3: select the shared HS data bus with
14991614/14991615 new 2026-11-17 cref= None（**已知盲区**：实际已合入 for-7.5）
```

**⑧ 收件人复现（树内 `get_maintainer.pl`，现跑）**

```
0001 → Greg Kroah-Hartman (USB SUBSYSTEM), Rob Herring, Krzysztof Kozlowski, Conor Dooley (DT), linux-usb, devicetree, linux-kernel
0002 → Greg Kroah-Hartman, linux-usb, linux-kernel
0003 → Thinh Nguyen (DWC3 DRD), Greg Kroah-Hartman, linux-usb, linux-kernel
```

---

## §4 残留风险

1. **krzk 的态度风险最高**：他三次用 "you"（人身化的流程批评）。若 v11 仍以旧投法出现，
   该系列在该维护者处可能被长期冷处理。A1 两项改动是唯一的低成本止损。
2. `mobian !46` **零评论已 4 h**，Mobian 侧历史上确有「设备 config MR 挂两年」的先例（`!2`/`!22`）
   ⇒ 若一周无回应，应准备「转 recipes-only 路线」的 B 方案（`mobian-mr-plan` §2.5 已有）。
3. 本报告未做**任何**投递动作，v11 的 G7（上机）仍未做；cover 已声明 "No runtime testing is claimed"，
   与 `TASKS` D2 行的 G7 未做状态一致。
