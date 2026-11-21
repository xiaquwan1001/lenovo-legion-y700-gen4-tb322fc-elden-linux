# dwc3 v11 投递前清单（2026-11-21 夜，**未投递，等用户放行**）

> 本文件只做「发前核对」，**不执行任何 `git send-email`**，也不改三枚补丁的字节
> （`GATES-v11.md` 记录的六个 blob 仍是当前件的 blob，改字节必须整套重跑并重记门链）。
> 写者 = mail-io lane；收口发信须用户按批放行后由指定单一执行者做。
> 上游事实的时间基准：**2026-11-21T13:0xZ**（下面每条都带可复现命令）。

---

## 0. 🔴 发前阻断项：1 条（今天 09:11Z 新到，v11 未覆盖）

**Krzysztof Kozlowski 对 v10 1/3 的回信**，`<20261121-icy-bright-partridge-afe8de@quoll>`，
2026-11-21T09:11Z（= 10:11 +0100），三句原文：

```
This does not go to commit msg, but changelog.

You keep sending multiple revisions, this one even threaded to other
posting and still not really responding to feedbacks.

Feedback was waiting for three days and then you send the same. That's
just wasting our time.
```

⇒ 三条都是**流程性**指控，与代码无关，但发 v11 前必须逐条闭合，否则等于第二次撞同一堵墙：

| # | 他的要求 | v11 现状 | 发前必须做 |
|---|---|---|---|
| K1 | AI 披露「不进 commit message，进 changelog（`---` 之后）」 | **违反**：三枚 patch 的披露段都在 `Signed-off-by` 之前（即 commit msg 内）。实测 `grep -n "AI-assist\|^---$"` → 0000:17/…；0001 披露 26–29 行、`---` 31 行；0002 25–28 / `---` 30；0003 30–33 / `---` 35 | 把 0000（cover 的 `---` 之后本就是 changelog，**只留 cover 一份即可**）+ 0001/0002/0003 的披露段整段移到各自 `---` 之下；**`Signed-off-by` 前一位保持为正文最后一行** |
| K2 | 「一封封续投、还挂到别的 posting 线程上」 | **将违反**：`GATES-v11.md` §5 第 3 条要求 `--in-reply-to=<v10 cover>`，正是他点名的做法 | **改为新线程**（不带 `--in-reply-to`）；代际关系写进 cover 的 `Changes since v10` 首段一句话即可 |
| K3 | 「反馈等了三天、然后你又发一样的东西」 | **可闭合**：v11 相对 v10 的三处改动正是 sashiko v10 的四条建议（见 §3），cover 已逐条点名回应 | cover 开头加一句「本条回复 sashiko 2026-11-21T02:40Z 对 v10 的报告，逐条见下」；并把 K1 的披露位置改动写进 changelog |

> K1/K2 是**机械可验证**的，不需要重跑 G1–G6（改动只在 commit message 与发信参数，不进 diff）；
> 但改完必须复核 `git apply` 仍 3/3（mailinfo 会因 commit msg 变化而不影响 diff，仍建议跑一次 `G1`）。

---

## 1. 收件人（每条可用命令复现）

**实测 To/Cc（来源 = v10 的 lore 原始件，逐字）**

```sh
timeout -k 5 200 python3 scripts/lore-fetch-raw.py all 20261121022104.1507987-1-xiaqinghuan@mail.ustc.edu.cn -o /tmp/lore-v10
awk '/^To:/,/^Subject:/' /tmp/lore-v10/1.raw
```

```
To: Thinh.Nguyen@synopsys.com,
	linux-usb@vger.kernel.org
Cc: Rob Herring <robh@kernel.org>,
	Krzysztof Kozlowski <krzk+dt@kernel.org>,
	Conor Dooley <conor+dt@kernel.org>,
	Greg Kroah-Hartman <gregkh@linuxfoundation.org>,
	devicetree@vger.kernel.org,
	linux-arm-msm@vger.kernel.org,
	linux-kernel@vger.kernel.org
```

**树内 `get_maintainer.pl` 交叉验证（本次现跑）**

```sh
cd build/elden-tree
for p in /home/xuqianhui/y700-elden/patches/upstream/dwc3-v11-20261121/v11-000{1,2,3}-*.patch; do
  echo "== $(basename $p)"; perl scripts/get_maintainer.pl --no-git --no-roles "$p"; done
```

```
0001 → Greg Kroah-Hartman (USB SUBSYSTEM), Rob Herring, Krzysztof Kozlowski, Conor Dooley (DT),
       Felipe Balbi (in file), linux-usb, devicetree, linux-kernel
0002 → Greg Kroah-Hartman, linux-usb, linux-kernel
0003 → Thinh Nguyen (DWC3 DRD), Greg Kroah-Hartman, linux-usb, linux-kernel
```

⇒ **沿用 v10 的 To/Cc 集合即可**，唯一强制增补：`linux-arm-msm@vger.kernel.org` 已在 Cc（板件相关，
且 wl2868c 合入通知里 Mark Brown 明确要求「回信时把相关列表和维护者带上」）。

| 角色 | 地址 | 位置 |
|---|---|---|
| DWC3 维护者 | `Thinh.Nguyen@synopsys.com` | To |
| USB 列表 | `linux-usb@vger.kernel.org` | To |
| DT 维护者 | `robh@kernel.org` / `krzk+dt@kernel.org` / `conor+dt@kernel.org` | Cc |
| USB 子系统 | `gregkh@linuxfoundation.org` | Cc |
| DT 列表 | `devicetree@vger.kernel.org` | Cc |
| qcom 列表 | `linux-arm-msm@vger.kernel.org` | Cc |
| LKML | `linux-kernel@vger.kernel.org` | Cc |

---

## 2. 线程与 References

| 方案 | 参数 | 判据 |
|---|---|---|
| **A（推荐，新线程）** | 不带 `--in-reply-to` / `--no-thread` | 直接闭合 K2；cover 里 `Changes since v10` 首段点名 v9/v10 的两枚 MID，读者可点开 |
| B（旧方案，**不要用**） | `--in-reply-to='<20261121022104.1507987-1-xiaqinghuan@mail.ustc.edu.cn>'`（v10 cover） | `GATES-v11.md` §5 原写法；**正是 krzk 09:11Z 批评的「threaded to other posting」** |
| C（更不要用） | `--in-reply-to=<v9 cover 20261117052137.32833-1-…>` | 会形成 v8→v9→v10→v11 五级续投链 |

v10 四封的 Message-ID（逐字，取自 lore raw，非 Sent 回读）：

```sh
for i in 1 2 3 4; do grep -m1 '^Message-ID:' /tmp/lore-v10/$i.raw; done
```

```
Message-ID: <20261121022104.1507987-1-xiaqinghuan@mail.ustc.edu.cn>   # 0/3 cover
Message-ID: <20261121022104.1507987-2-xiaqinghuan@mail.ustc.edu.cn>   # 1/3 binding
Message-ID: <20261121022104.1507987-3-xiaqinghuan@mail.ustc.edu.cn>   # 2/3 usb: roles
Message-ID: <20261121022104.1507987-4-xiaqinghuan@mail.ustc.edu.cn>   # 3/3 dwc3 mux
```

---

## 3. 附件顺序（4 枚，严格按此顺序）

| 序 | 文件 | 行数 | checkpatch（本轮记录值） | 备注 |
|---|---|---|---|---|
| 0000 | `v11-0000-cover-letter.patch` | — | n/a | 含 AI 披露（留在 cover 即可）+ `Changes since v10` 四条 + `Known gaps` + 门结果 |
| 0001 | `v11-0001-dt-bindings-usb-snps-dwc3-describe-two-connectors-on.patch` | 115 | 0E/0W/0C | 顶 `From 0000…` 是占位，**放行时须 `git am` 后 `format-patch` 现生成** |
| 0002 | `v11-0002-usb-roles-look-up-role-switches-attached-to-a-graph-endpoint.patch` | 63 | 0E/0W/0C | 与 v10 逐字节同（无评审意见） |
| 0003 | `v11-0003-usb-dwc3-select-the-shared-HS-data-bus-with-a-mux-controller.patch` | 624 | 0E/0W/0C | deselect 顺序已按 sashiko 调后 |

- **0004（板 DTS，GPIO 29 + 双 endpoint）继续 hold**，不在本批。
- 三枚补丁的 `From 0000…` 占位必须在放行时重生成（`GATES-v11.md` §5 第 4 条），否则 commit hash 与内容不符。

复现 checkpatch（**必须走 stdin**，见 `GATES-v11.md` §3 坑 4；脚本在 `build/elden-tree`，仓库根没有）：

```sh
cd build/elden-tree
for p in /home/xuqianhui/y700-elden/patches/upstream/dwc3-v11-20261121/v11-000{1,2,3}-*.patch; do
  perl scripts/checkpatch.pl --strict --no-signoff --no-tree - < "$p" | tail -2; done
```

```
"[PATCH v11 1/3] dt-bindings: usb: snps,dwc3: describe two connectors" has no obvious style problems and is ready for submission.
"[PATCH v11 2/3] usb: roles: look up role switches attached to a graph" has no obvious style problems and is ready for submission.
"[PATCH v11 3/3] usb: dwc3: select the shared HS data bus with a mux" has no obvious style problems and is ready for submission.
```

---

## 4. v11 相对 v10 已闭合的评审（sashiko v10 三条 + krzk 一条）

sashiko 于 **2026-11-21T02:33/02:40Z** 对 v10 回 3 封（v10 是 02:21Z 投的，晚 12–19 分钟），
**不在** `reports/mail-inbox-20261121.md` 的窗口内（该报告截到 02:00Z）⇒ 本轮新增发现：

| 来源 MID | 级别 | 意见 | v11 处置 | 判据 |
|---|---|---|---|---|
| `<sashiko-outbox-226549@kernel.org>`（1/3） | Medium | `$ref: '#/$defs/hs-port'` 无条件套到 `port@0` ⇒ 无量 mux 的单连接器节点 `dtbs_check` 回归 | 已改：`port@0` 顶层保持通用 graph port，两 endpoint 只在 `mux-controls` 分支要求 | G6 正样例 4/4 0 诊断、负样例 4/4 被拒；v10-as-sent 对照 2 个正样例被拒 |
| 同上 | Low | 应照 Rob 意见去掉本地 `$defs`、改 `patternProperties`、删驱动实现细节 | 已改 | `grep -c '^$defs' patches/upstream/dwc3-v11-20261121/v11-0001-*.patch` → **0** |
| 同上 | Low | `dr_mode` 列进 `required` 会拒掉依赖 `usb-drd.yaml` 默认值 `otg` 的节点 | 已改：仍 `const: otg`，但移出 `required` | `gates/pos-no-dr-mode` 0 诊断；v10 schema 下 2 条诊断 |
| `<sashiko-outbox-226546@kernel.org>`（3/3） | Medium | `dwc3_drd_exit()` 里 deselect 早于角色 teardown | 已改：`dwc3_role_mux_deselect()` 挪到 `switch (dwc->current_dr_role)` 之后 | 0003 diff `@@ …dwc3_drd_exit`；`grep -n -A3 'mode worker is drained'` |
| `<sashiko-outbox-226550@kernel.org>`（0/3） | — | 系列级汇总：2/3 no issues | 无需动作 | — |
| `<20261121-icy-bright-partridge-afe8de@quoll>`（krzk，1/3） | 🔴 流程 | 见 §0 | **未覆盖** | — |

复核命令：

```sh
# 1/3 三条（正文含 [Severity: …] 行）
timeout -k 5 200 python3 scripts/lore-fetch-raw.py linux-usb sashiko-outbox-226549@kernel.org | grep -n 'Severity'
# 3/3 一条
timeout -k 5 200 python3 scripts/lore-fetch-raw.py linux-usb sashiko-outbox-226546@kernel.org | grep -n 'Severity'
# krzk 流程意见
timeout -k 5 200 python3 scripts/lore-fetch-raw.py linux-devicetree 20261121-icy-bright-partridge-afe8de@quoll | tail -8
# 收件箱侧：确认这三封确实投到了我们自己的 INBOX（BODY.PEEK，不改已读）
timeout -k 5 180 python3 ~/.local/bin/read-mail-ustc.py --days 2 --grep sashiko,quoll --folders INBOX
```

---

## 5. 归档现状（发前确认"旧件仍在、没有并发竞争者"）

```sh
for L in linux-usb linux-devicetree linux-arm-msm; do
  timeout -k 5 200 python3 scripts/lore-fetch-raw.py $L 20261121022104.1507987-1-xiaqinghuan@mail.ustc.edu.cn; done
```

实测：三处全部取到 raw（`13562 / 13569 / 13590 B`，字节差仅来自各列表加的 footer）⇒ **v10 cover 三列在档**。

patchwork（`linux-usb`）：series `1217901` v10，三枚 `15007992/15007994/15007993`，`state=new`、
`commit_ref=None` ⇒ 未进 mainline/next（`commit_ref` 空**只能**这么读，§7 三条限定）。

**同区域竞争者：0**（2026-11-01 起，三项目全量 series 搜索 `two connectors` / `snps,dwc3 mux` /
`usb-role-switch endpoint` / `dwc3 mux-controls` / `shared HS data bus`，除我方代次外无他人）：

```sh
for q in "two+connectors" "snps,dwc3+mux" "usb-role-switch+endpoint" "dwc3+mux-controls" "shared+HS+data+bus"; do
  for proj in linux-usb linux-devicetree linux-arm-msm; do
    timeout -k 5 60 curl -s --noproxy '*' \
      "https://patchwork.kernel.org/api/1.2/series/?project=$proj&q=$q&per_page=20" \
      | python3 -c "import json,sys;[print(s['id'],'v%s'%s['version'],s['date'][:19],s['submitter']['email'],s['name'][:50]) for s in json.load(sys.stdin) if s['date']>='2026-11-01']"
  done; done
```

⇒ 只有 `xiaqinghuan@mail.ustc.edu.cn` 的 v1/v1/v8/v9/v10。**没人抢同一区域**（这也意味着没有
「别人已合入等价实现」的风险，可以按自己的节奏改）。

---

## 6. 放行点：需要用户说的**一句话**

> **「dwc3 v11 可以发：先把 AI 披露移到 `---` 下（三枚 patch 各一处）+ 改用新线程，然后投 4 封。」**

用户只要回这一句（或等价表述），执行者即可按 §1/§2/§3 发信；**不含这句就继续 hold**。
否则自动执行的默认状态 = **不发**。

---

## 7. 发后必做（写在这里，避免下一轮漏）

1. lore 复核 `linux-usb` + `linux-devicetree` 两列（`devicetree` 摄取滞后是常态，以 lore 为准）。
2. 判据：4/4 命中且 `Message-ID` 逐字、`In-Reply-To` **为空**（新线程）。
3. 把 §0 的 K1/K2/K3 处置写进 `SENT.md`，供下一版 cover 引用。
