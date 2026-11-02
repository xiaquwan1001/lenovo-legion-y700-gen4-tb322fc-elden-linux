# 投递报告 — M6/B5 回复 Dmitry 四条 + M3-1 dwc3 v5 1/2 补投正确 DT 列表

- 日期：2026-11-02（发送时段 13:40–13:41 CST / 05:40–05:41Z）
- 授权：用户 2026-11-02 明确批准本批两封投递（含 AI 代写正文，按 `AGENTS.md`「上游发信」三条纪律）
- 通道：`~/.local/bin/send-mail-ustc.py`（dry-run → `--send`；凭据走 keyring，未落盘）

## §0 数字结论

| 项 | 值 |
|---|---|
| 发出 | **2 封**，均 `已发送 OK`（无 SMTP 报错；发后 20 min 内 INBOX/Junk 无新 postmaster 退信，最大 postmaster 序号仍为 INBOX 15773 / Junk 405） |
| Sent Items 回读 | **[234]**、**[235]**；主题/收件人/In-Reply-To 逐字对上 |
| 正文一致性 | 两封回读正文与落盘文件的 **sha256 完全相同**（`408d416c…`、`16fa459b…`） |
| 纯 ASCII | 2/2（`grep '[^ -~]'` 0 命中，7bit us-ascii 发送） |
| lore 归档 | **6 个列表位全部命中 200**（详见 §2），无 404 遗留 |
| 未做 | 不投新补丁、不改 `patches/local`、未 rebase、未改任何 SSOT 文档 |

## §1 两封的身份

| # | Message-ID | 主题 | To | In-Reply-To |
|---|---|---|---|---|
| **B5 回复** | `<179359805420.413286.9245285367012895571@mail.ustc.edu.cn>` | `Re: [PATCH 0/5] drm/msm/dsi: collect bonded command-path data into per-SoC config` | Dmitry Baryshkov `<dmitry.baryshkov@oss.qualcomm.com>` | `<j5ixobskknatvusosmhgvvmnze4q67iyfwk6gsa3y5goovx4z4@mhumd2vsnfkm>`（Dmitry 对 0/5 的回信） |
| **M3-1 补投** | `<179359806935.413510.7108025505776923330@mail.ustc.edu.cn>` | `[PATCH v5 1/2] dt-bindings: usb: snps,dwc3: tighten the two-connector shared HS bus` | `devicetree@vger.kernel.org` | 无（独立单封） |

B5 回复 Cc：Rob Clark、**Abhinav Kumar `<abhinav.kumar@linux.dev>`**、**Jessica Zhang `<jesszhan0024@gmail.com>`**、
Sean Paul、Marijn Suijten、`linux-arm-msm`、`dri-devel`、`lkml`（无任何 `quic_*@quicinc.com`）。

M3-1 补投 Cc：Rob Herring、Conor Dooley、Krzysztof Kozlowski（`krzk+dt@kernel.org`）、Greg Kroah-Hartman、
`linux-usb`、`linux-arm-msm`、`linux-kernel`（与 v5 原三封同名单，仅把 DT 列表地址换成正确的）。

## §2 lore 归档（逐封、列表专属路径 `/<list>/<mid>/raw`）

| 信 | 列表 | 结果 | 字节 |
|---|---|---|---|
| B5 回复 | `linux-arm-msm` | **200** | 10517 |
| B5 回复 | `dri-devel` | **200** | 9799 |
| B5 回复 | `lkml` | **200** | 10510 |
| M3-1 补投 | `linux-devicetree`（= devicetree.vger.kernel.org 镜像） | **200** | 12417 |
| M3-1 补投 | `linux-usb` | **200** | 12410 |
| M3-1 补投 | `lkml` | **200** | 12431 |

B5 线程（`--thread linux-arm-msm:<cover>`）：**11+ 封**，最新成员 = 我方 `2026-11-02 5:40Z`，
挂在 Dmitry 的 0/5 回信之下 ⇒ 线程归并正确，未另起。

**一个必须记住的命名坑**：`https://lore.kernel.org/devicetree/` **整站 404**；DT 归档的列表名是
`linux-devicetree`，其页头自述 *"devicetree.vger.kernel.org archive mirror"*。也就是说
**地址 = `devicetree@vger.kernel.org`**，而 **lore 列表名 = `linux-devicetree`** —— 这两件事不同。
本轮先按 `devicetree:` 探测得到 404，一度误判「未归档」；换列表名后 200。收件地址仍按用户指令用 `devicetree@`。

## §3 M3-1 补投：内容零改动的证明

```
# 1) 从补丁文件取「commit message 起」的正文
$ python3 - <<'EOF'   # 见 /tmp/m3rs/ 复原
s=open('patches/upstream/m3v5-20261030/v5-0001-…patch').read()
open('/tmp/m3rs/from-file.txt','w').write(s[s.index('Two connectors behind one controller'):])
EOF

# 2) 回读 Sent Items seq 225（2026-10-31 实发 1/2）正文
$ timeout 120 python3 /tmp/m3rs/fetch.py           # -> /tmp/m3rs/sent-225.txt

# 3) 比对（Sent Items 侧是 CRLF）
$ tr -d '\r' < /tmp/m3rs/sent-225.txt > /tmp/m3rs/sent-225.lf.txt
$ diff -u /tmp/m3rs/from-file.txt /tmp/m3rs/sent-225.lf.txt && echo IDENTICAL_AFTER_CRLF_STRIP
IDENTICAL_AFTER_CRLF_STRIP
```

⇒ 补投正文 = 2026-10-31 实发件原文（仅去掉 mbox 头 `From <sha>` 行，git-send-email 亦如此），
`patches/upstream/m3-1-v5-dt-resend-20261102/0001-…patch` 为同一文本的存档副本
（sha256 `43f8662f268c8c94bedd0476f9bd95ebf605970711aad5f4d8af935900967edb`）。

## §4 B5 回复：四条逐条落实（正文 `out/mail-20261102-b5/re-dmitry-b5-4items.txt`）

| Dmitry 条目 | 我方处置 | 证据编号 |
|---|---|---|
| 0/5「bonded DSI 现在就能用，凭什么改」 | 上游只有时钟/PHY 半；`dsi.xml:190` 有 `BROADCAST_EN`、`dsi_host.c` 从不置位（0 命中）；本板首个 DCS `ff 20` `-22`、命令 DMA 引擎 hang（`STATUS0=0x20003`、`TRIG_DMA=0x1` 自不清）；本系列是该路径上游化的数据前提 | E1–E3 |
| 1/5 ①lock 也该一起去 ②block comment 格式 ③base kernel | ①②接受（现 `dsi_manager.c:40/41` 两者都是 file-scoped；comment 改 leading `/*` 独占一行）；③如实交代 base = `0f1fb1c9c1` = v7.3-rc7 `24a19b953e` + **一个本地压缩载荷提交**（148 文件 +15513/−700，DSI 部分 `dsi_host.c +578`、`dsi_manager.c +249`、`dsi.h +19`），非公开；并给出**已实测的上游重放结论** 0/6（仅 0002 干净）作为「你 apply 不上」的对照 | E4、E5、E5b |
| 2/5 跨平台差异 / 其他平台 / 不得挂在 sm8650 表项 | 只有 SM8750 数据、**不主张**跨平台差异；其他 SoC `cfg->bonded == NULL` 走旧路径；接受「SM8750 数据不得挂 sm8650 表项」（两者 DSI 6G v2.9），v2 改按 compatible 选择 | E6 |
| 4/5「IDs 不是 probe order，master 也由 DT 定」 | **直接认错**并贴改正后的 commit message 段（`dsi_mgr_parse_of()` 从 `qcom,master-dsi` 取，link id = host 序号；DT 是唯一权威，表项只用于「调用者必须是 master」的检查）；声明 v2 不再「从表取 master」 | E7 |

三件套：①首段即 AI 披露；②每条带 `[E#]` → 正文末 Evidence 段给命令/`file:line`（逐行对应
`out/mail-20261102-b5/claims.tsv`）；③4 条全覆盖，无遗漏（对账见 `out/mail-20261102-b5/self-review.md` §1）。

## §5 未做 / 明确不主张

1. **未 rebase、未投任何补丁**（正文承诺 v2 在 torvalds master 上重切后作为新系列重发）。
2. **未改** `patches/local/b5-resoc-20261027/*`（B5 v2 的改动点已写进回信，但补丁未动）。
3. **未改**任何 SSOT 文档；**未** `git add/commit/checkout/clean`；**未**碰设备；**未** sudo。
4. `dri-devel` 是否被 moderation 延误未单独核（本次 200 直接命中，无需跟进）。
5. 未在 patchwork 上做任何写操作。

## §6 复跑命令

```bash
cd /home/xuqianhui/y700-elden   # 首命令 git rev-parse --show-toplevel 核对

# 归档（列表专属路径，~6 s/req；注意 DT 列表名是 linux-devicetree）
python3 /tmp/eld-lore-1102.py \
  linux-arm-msm:179359805420.413286.9245285367012895571@mail.ustc.edu.cn \
  dri-devel:179359805420.413286.9245285367012895571@mail.ustc.edu.cn \
  lkml:179359805420.413286.9245285367012895571@mail.ustc.edu.cn \
  linux-devicetree:179359806935.413510.7108025505776923330@mail.ustc.edu.cn \
  linux-usb:179359806935.413510.7108025505776923330@mail.ustc.edu.cn
python3 /tmp/eld-lore-1102.py --thread linux-arm-msm:20261031150305.1107572-1-xiaqinghuan@mail.ustc.edu.cn

# Sent Items 回读 + 正文 sha256 对账
python3 /tmp/m3rs/verify.py
```
