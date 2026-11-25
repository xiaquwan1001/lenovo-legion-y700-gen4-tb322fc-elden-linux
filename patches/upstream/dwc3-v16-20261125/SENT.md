# dwc3 v16 投递记录（2026-11-25T22:23 CST / 14:23Z）

- 放行依据：用户 2026-11-26 裁决「去重待办以后全部放行可做」（TASKS §7 投递口径已改全面放行）。
- 发送：`bash SEND.sh --yes`，**4 封全 `Result: 250`**（`logs/sent-20261125-222309.txt`）。
- cover MID：`<20261125142309.3265777-1-xiaqinghuan@mail.ustc.edu.cn>`（新线程，无 In-Reply-To）。
- lore 复核：linux-usb cover **已归档命中**（web_fetch 逐字核对 2026-11-26）；linux-devicetree 摄取稍后，按 MID 复核。
- 内容：只动 1/3（sashiko 2 条 [Low] 全修：else 分支 port@0 补 graph port $ref、endpoint 拒绝正则改 `[2-9a-f]|[0-9a-f]{2,}`、changelog 移 tearline 下）；2/3、3/3 与 v15 diff 段逐字节同（patch-id `5688adec43ea`/`60721b9fb7fb`）。
- 后续：盯 Thinh Nguyen / Greg KH / sashiko 回信；被要求「先有板 DTS 再谈」时口径 = elden 板 DTS v8 已投（2026-11-25T09:13Z）。
