# 投递前静态核对工具 `scripts/mail-draft-check.py` + 一处真缺陷修复（2026-11-17 早）

> 触发：早间批处理复核「Q28 证据回帖 dry-run 通过」这条台账时，顺手复跑了 `send-mail-ustc.py` 的 dry-run，
> 看到 **「收件人合计: 4 个」** —— 草稿首部明明有 9 个地址。顺着这条线查出机制性缺陷并修复。

## 1. 缺陷：`send-mail-ustc.py` 的首部解析不认 RFC 822 折行

`~/.local/bin/send-mail-ustc.py`（仓外）的 `parse()` 是**逐行**的：

```python
for line in head.splitlines():
    if line.startswith("To:"):   ...
    elif line.startswith("Cc:"): ...
```

缩进续行（` Continued`, 以空格/Tab 开头）**既不匹配任何 `startswith`，也不报错** ⇒ 续行上的收件人被**静默丢弃**。
`git send-email` 不受影响（它走 RFC 解析），所以只有「用 send-mail-ustc.py 发回复」这条通道会中招。

**实测（本次修前）**：

```
$ python3 ~/.local/bin/send-mail-ustc.py patches/upstream/mdss-v5-q28-evidence-20261116/mail-body.txt
Cc     : devicetree@vger.kernel.org, linux-kernel@vger.kernel.org     # ← 只有第一行
收件人合计: 4 个                                                       # ← 应是 9 个
```

丢掉的 5 个正好是这封信**最该送到的人**：Konrad Dybcio、Dmitry Baryshkov、Abel Vesa、
Bjorn Andersson、Rob Herring（全是折行续行上的）。台账里「dry-run 已过（95 行、纯 ASCII）」
只核了行数与字符集，**没核收件人集合**，所以这条缺陷一直没被看见。

## 2. 修复（就地，草稿侧）

`patches/upstream/mdss-v5-q28-evidence-20261116/mail-body.txt` 的 `Cc:` 压成**单行**（内容一个人不删）：

```
Cc: devicetree@vger.kernel.org, linux-kernel@vger.kernel.org, Konrad Dybcio <…>, Dmitry Baryshkov <…>, Abel Vesa <…>, Bjorn Andersson <…>, Rob Herring <…>
```

修后复跑：dry-run `收件人合计: 9 个`；`mail-draft-check.py` = `OK (RFC 9 / 逐行 9)`。

## 3. 新工具：`scripts/mail-draft-check.py`（离线、零网络、可门禁化）

三视角比对：

| 视角 | 实现 | 语义 |
|---|---|---|
| A | `email.message_from_bytes` | **本该发给谁**（RFC 合规，认折行） |
| B | 复刻 `send-mail-ustc.py` 的逐行规则 | **真会发给谁** |
| C | 门禁 | 正文非 ASCII（本项目一律要求纯 ASCII）、回复件缺 `In-Reply-To` |

`A − B ≠ ∅` ⇒ **FAIL**（会被静默漏发，并逐个列出地址）。非草稿（缺 `To:/Subject:`）、
收来的原始邮件（首部有 `Received:`/`ARC-Seal:`）自动 `SKIP`，不算 FAIL。

```bash
scripts/mail-draft-check.py <draft.txt> [...]         # 退出码 0 = 全绿
scripts/mail-draft-check.py --quiet out/mail-*/*.txt  # 只打 FAIL/WARN/SKIP
```

**门禁口径建议**：`send-mail-ustc.py --send` 之前先跑一遍本脚本（该项目「无对照表不发提问」的同族纪律）。

## 4. 全仓草稿普查（50 份 `out/mail-*/*.txt` + `patches/upstream/*/mail-body.txt`）

结果 = **FAIL 3 / 其余 OK 或 SKIP**，三份都是**已发过的历史件**，且都不是本缺陷的受害者：

| 件 | 收件人 A/B | 已发方式与证据 |
|---|---|---|
| `out/mail-20261026/re-m9-its-claim.txt` | 5 / 3 | 走 `send-mail-ustc.py`（MID `179301488974.13269…@mail.ustc.edu.cn` 是 python `make_msgid` 形态）；但 lore 归档件的 `Cc` 四行俱全（`linux-arm-msm` + `linux-arm-kernel` + `lkml` + `tglx`）⇒ **实际送达面已不可从原件判定**，不据此宣称「当年漏发」。→ `reports/mail-triage-20261029.md` S11 |
| `out/mail-20261113/re-mdss-3q.txt` | 10 / 3 | `git send-email`（同目录 `send-mdss-v4.log`），折行不影响送达 |
| `out/mail-20261114/re-sashiko-mdss-v4.txt` | 11 / 3 | `git send-email`（同目录 `.mbox` 的 `From nobody …` 头 + MID `20261113234851.42e0bacd02fa…`）；lore 归档件 `Cc` 十人齐全（已核） |

⇒ 结论：**静默漏发在这三封上未造成实际损失**，但机制是真的，且 2026-11-17 这封（未发）差点中招。

## 5. 仍欠的一步（仓外，需人做）

`~/.local/bin/send-mail-ustc.py` 的 `parse()` 本身没改（不属本仓）。两种收口方式，任选：

1. 在该脚本里把首部解析换成 `email.message_from_bytes(raw)`（`getaddresses()` 取 To/Cc），一劳永逸；
2. 或在 `--send` 成功后调 `scripts/mail-append-sent.py` + 先跑 `scripts/mail-draft-check.py` 当门禁。

## 6. 复现命令

```bash
cd ~/y700-elden
python3 ~/.local/bin/send-mail-ustc.py patches/upstream/mdss-v5-q28-evidence-20261116/mail-body.txt | tail -3
#   → 正文行数: 95 | 非 ASCII: 无 | 收件人合计: 9 个
scripts/mail-draft-check.py patches/upstream/mdss-v5-q28-evidence-20261116/mail-body.txt
#   → OK (RFC 9 收件人 / 逐行 9 / 正文 96 行)，合计 1 份：FAIL 0 份
scripts/mail-draft-check.py --quiet out/mail-*/*.txt patches/upstream/*/mail-body.txt | tail -1
#   → 合计 50 份：FAIL 3 份（均为上表已发历史件）
```
