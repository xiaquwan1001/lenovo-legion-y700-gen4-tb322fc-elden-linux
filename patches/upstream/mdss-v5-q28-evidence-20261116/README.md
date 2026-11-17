
## 投递实账（2026-11-17 12:20 CST）

- 门禁：`scripts/mail-draft-check.py` = **OK**（RFC 9 收件人 / 逐行 9 / 正文 96 行）；dry-run 9 人、纯 ASCII。
- 实发：`python3 ~/.local/bin/send-mail-ustc.py mail-body.txt --send` → **已发送 OK**，
  `Message-ID: <179488903160.260870.8168848839719897744@mail.ustc.edu.cn>`，
  `In-Reply-To: <20261113155635.1677541-1-xiaqinghuan@mail.ustc.edu.cn>`（= mdss v5 cover）。
- lore 复核（发后 ~60 s，`scripts/lore-fetch-raw.py` 按 MID 取 raw）：**`/linux-arm-msm/` 1 封 10067 B、`/dri-devel/` 1 封 9326 B、`/lkml/` 1 封 10060 B** 全部命中；
  正文与本地件**逐字节相同**（`sha256 4fe84148…` = 4780 B，两边相等；Subject = `Re: [PATCH v5 0/3] drm/msm/mdss: …`）。
- 本目录 = 已投状态；`Sent Items` 无副本（`send-mail-ustc.py` 走 smtplib 不 APPEND，补账用 `scripts/mail-append-sent.py --apply`，需解锁 keyring 的会话）。
