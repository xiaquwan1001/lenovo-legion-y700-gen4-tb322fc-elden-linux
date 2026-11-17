## #671 重发新版本前必须 strip 补丁件里的 `Message-ID`/`In-Reply-To`/`References`，否则 git send-email 照抄旧 MID

- 现象（2026-11-17 实测，wl2868c v12）：从 v11 目录复制出的补丁件保留了 `format-patch --thread` 写进文件的
  `Message-ID: <9ab5e593…>`、`In-Reply-To: <cover.1794557667…>`、`References: …`；`git send-email` 把它们当**显式头**照抄
  ⇒ v12 三封发出去用的还是 v11 的 Message-ID。
- 后果（不是「可能」而是实测）：归档侧按 MID 去重 —— `scripts/lore-fetch-raw.py linux-arm-msm 9ab5e593…` 取回的是
  **v11 原文**（Subject `[PATCH v11 1/2]`、Date 11-13）；也就是说 v12 在 lore/patchwork 上等于**没发**，且同一 MID 的第二封内容
  会被归档器/收件端去重丢弃。
- 判据：发前 `grep -n '^Message-ID:\|^In-Reply-To:\|^References:' <件>` 必须**无输出**；发后取 raw 的 Subject 必须等于本次版本号。
- 处置：`sed -i '/^Message-ID: </d; /^In-Reply-To: </d; /^References: </d' *.patch` 后重发，并在 cover 顶部加一行
  「上一封误用 v11 的 MID，请用这封（内容相同）」。重发件 `20261117052257.34849-{1,2,3}` 三列表均归档。
- 顺带：`git send-email` 给 cover 生成 `<时间.进程-1>`、后续 `<…-2/-3>` 的 MID，**每次实发都不同**（别拿 dry-run 的 MID 去查归档）。
- 全账：`patches/upstream/wl2868c-v12-20261117/SENT.md`「注意：第一次误发」、`logs/sent2-*.txt`。
