# #461 「有无上游回复」不能靠 `read-mail-ustc.py --replies-only`

## 结论（2026-10-28 实测）

- `~/.local/bin/read-mail-ustc.py --replies-only` 的判据是脚本里**硬编码的 3 个 `OUR_IDS`**
  （10-13 那批 camss/regulator 的 Message-ID），**不是**「所有我方 Message-ID」。
- 换系列后它必然漏报：实测对 10-17 之后发出的 M3 v2/v4、M4、M9、aw86927、camss 系列
  **全部未命中**（`--days 45` 仍只回 16 封），而同期实际有 16 条需动作的回复。
- ⇒ **不得**把它的空结果写成「上游没回」。

## 正确做法

- 服务端搜 `HEADER In-Reply-To "mail.ustc.edu.cn"` + `HEADER References "mail.ustc.edu.cn"`
  （覆盖我方发出的 `<...@mail.ustc.edu.cn>`），再用 SUBJECT/TO 关键词兜底；
- 取正文用 `BODY.PEEK[]`（**不改 `\Seen`**，不污染用户邮箱）；
- 命中落 JSON 台账，正文另存 `out/mail-<date>/`，报告只引用台账。
- 现成实现：`out/mail-20261028/triage-20261028.py` + `dump-msgs.py`。

## 附带（同一轮踩到）

- lore 已上 Anubis PoW：`curl` 一律 403，复核走 `lore-query.py` / `web_fetch provider=browser`（见 #444）。
- 投递后复核必须**双通道**：Sent Items 回读 + lore raw 正文 sha256，任一缺失都不算「已发」。
