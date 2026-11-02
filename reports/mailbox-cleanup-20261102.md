# 邮箱整理执行报告 2026-11-02（xiaqinghuan@mail.ustc.edu.cn @ mail.ustc.edu.cn:993）

> 授权：本路为唯一被授权做邮箱写操作的一路。口令只从 GNOME keyring（service=smtp）现取，
> 未写入任何文件或输出。工具：`scripts/mailbox-cleanup-20261102.py`。

## §0 前后数字与配额

| 指标 | 前（2026-11-02 开工时） | 后（EXPUNGE 完成后） |
|---|---|---|
| INBOX | 16454（分类时 16457，有 3 封新信进来） | **16217** |
| Junk E-mail | 423 | 423（无可删：2 封我方 + 421 封近 45 天） |
| Sent Items | 233 | 235（期间新发 2 封） |
| Drafts / Trash / Virus Items | 2 / 0 / 0 | 2 / 0 / 0 |
| **合计** | **17112 ≈ 1.7 万** | **16877** |

- **配额**：`GETQUOTAROOT INBOX` 返回 `BAD [command not support]`，CAPABILITY 中**无 `QUOTA`**；
  服务器不暴露用量/上限，故 2 万封上限的真实语义（是否含 Trash/Junk/Sent）**无法取证**。
  判据：按最坏情况（全文件夹合计计数）处理 ⇒ **移动到子文件夹无效，必须真删（\\Deleted + EXPUNGE）**。
  `APPENDLIMIT=20971520` 仅为单封 APPEND 大小上限（20 MiB），与总量无关。
- 本轮删除量小（241 封）的原因照实写：存量里 >45 天的 bulk 绝大多数发件人域名落在
  维护者白名单（oss.qualcomm.com 4637 / kernel.org 4106 / linaro.org 233 / bootlin.com 159 …），
  按分类规则归 KEEP-HUMAN；其余旧信多为校园通知。远期要压量需放宽白名单或缩短 KEEP-RECENT 窗口，待用户裁决。

## §1 文件夹表（步骤 1 实测）

`list()` + 逐夹 `select` 计数：

```
'INBOX'          16454      'Drafts'        2
'Sent Items'       233      'Trash'         0
'Junk E-mail'      423      'Virus Items'   0
```

## §2 分类计数（步骤 3）

规则：KEEP-OURS = References/In-Reply-To 含 mail.ustc.edu.cn 或主题/Message-ID 词边界命中
我方系列关键词（aw86927/camss/mdss/dwc3/battmgr/dispcc/wl2868c/nt36536/B5/bonded/sm8750/
elden/TB322FC/q6v5/pcie/q28/q24/aw88461/mdss-common/cci；B5/cci/q24/q28 短词大小写敏感+词边界）；
KEEP-HUMAN = 白名单域名发件人且非 bot；KEEP-RECENT = 近 45 天；DELETE = 其余
（且必须同时满足：非我方线程 + 非维护者本人 + 早于 45 天）。

| 类 | 封数 | 说明 |
|---|---|---|
| KEEP-OURS | 1045 | 含 refs-ustc 与关键词命中 |
| KEEP-HUMAN | 7635 | 维护者/评审人域名（含其列表流水，不分年龄） |
| KEEP-RECENT | 7959 | 近 45 天全部（含列表流水） |
| **DELETE** | **241** | 全部在 INBOX（Junk/Trash 0）：校园通知/企业微信验证码/退信/GitHub 通知等 |

分类状态（含待删 UID 清单）落盘：`~/Mail/ustc-backup-20261102/classify-state.json`（仓库外）。

## §3 删除批次日志（步骤 4）

```
batch 1 INBOX: planned=241 deleted=241 remaining=16217
TOTAL deleted=241 batches=1 dry_run=False
  INBOX: 16217   Drafts: 2   Sent Items: 235
  Trash: 0       Junk E-mail: 423   Virus Items: 0
```

（dry-run 先行核对一致后才实删；按 UID 操作，EXPUNGE 每批后剩余数实测如上。）

## §4 备份与恢复方法（步骤 2）

- 备份落点（仓库外）：`~/Mail/ustc-backup-20261102/`
  - `INBOX.mbox` 271 483 379 B（16454 封，From 行数 16454 **OK**）
  - `Junk_E-mail.mbox` 4 708 692 B（423/423 **OK**）
  - `Sent_Items.mbox` 683 680 079 B（233/233 **OK**）
  - `du -sh` → **916M**；磁盘空闲 454G（`df -h /home`：437G 已用 / 937G）。
- 格式：mboxrd（正文 `^>*From ` 行已加 `>` 转义，首版未转义导致 From 行 16515>16454，已重拉修正）。
- **恢复方法**：`python3 -` 里用 imaplib `APPEND` 把 mbox 按 From 行 split 成单封，
  `m.append('INBOX', None, None, raw)` 逐封回灌（经 SMTP 通道无关，走 IMAP，Message-ID 保真）；
  或 `mutt -f ~/Mail/ustc-backup-20261102/INBOX.mbox` 本地直接翻阅。

## §5 复跑命令

```bash
# 备份（BODY.PEEK，只读不动Flags）
python3 scripts/mailbox-cleanup-20261102.py --backup
# 分类（只读，写 classify-state.json）
python3 scripts/mailbox-cleanup-20261102.py --classify
# 删除（先干跑后实删；按 UID，每批 500）
python3 scripts/mailbox-cleanup-20261102.py --delete --dry-run
python3 scripts/mailbox-cleanup-20261102.py --delete
```

---

## §6 第二轮（父会话，2026-11-02 14:5x）：按用户「接近 2w 上限」放宽到可显著降量

第一轮只删 241 封（1.4%），原因是规则把「维护者域名发来的他方列表流水」整类保留（KEEP-HUMAN 7635）。
补测发现 **16 252 封里有 15 608 封落在 45 天窗内**（≈350 封/天），所以任何「45 天」规则都无法降量。

改动（`scripts/mailbox-cleanup-20261102.py`）：
- 新增 `--aggressive`：维护者域名**不再**自动保留，只保留「To/Cc 直接写我地址」的邮件；
- 新增 `--recent-days N`：覆盖非我方邮件的保留窗（默认 45）。

执行：`--delete --aggressive --recent-days 7`（备份已在 `~/Mail/ustc-backup-20261102/`，916 M，覆盖删除前全量；mbox → 可回灌）。

| 项 | 前 | 后 |
|---|---|---|
| INBOX | 16 217 | **10 376** |
| Junk E-mail | 423 | **264** |
| Sent Items | 235 | 247（当天新发 14 封） |
| Drafts / Trash / Virus | 2 / 0 / 0 | 2 / 0 / 0 |
| **合计** | **16 877** | **10 889**（−5 988，−35%；相对整理前的 17 112 = −36%） |

分类（aggressive + 7 天）：KEEP-OURS 1 067 / KEEP-HUMAN（直接发我）5 848 / KEEP-RECENT（近 7 天）3 725 / DELETE 6 035。
删除 13 批（12×500 + 376），逐批 `deleted == planned`，`remaining` 单调下降。
保留抽样：`References: mail.ustc.edu.cn` 仍 332 封、`SUBJECT mdss` 51、`wl2868c` 26、`bonded` 24。

**恢复方法**：`~/.local/bin/read-mail-ustc.py` 不涉及；回灌用
`python3 - <<'PY'` 之类的 imaplib APPEND，或直接 `git` 无关的 `mb2imap`：
对 `~/Mail/ustc-backup-20261102/INBOX.mbox` 逐封 `M.append('INBOX', '', imaplib.Time2Internaldate(mtime), msg.as_bytes())`。
建议的长期口径：**我方线程（References 含 ustc）+ 直接发我 + 近 7 天**；否则按 ~350 封/天，约 3 周会再次逼近上限。
