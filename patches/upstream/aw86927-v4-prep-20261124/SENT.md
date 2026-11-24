# aw86927 v4 投递记录（2026-11-24 12:50 CST = 04:50Z，用户放行「全部放行」）

- **发出**：`bash SEND.sh --yes`，**7 封全 250**（cover + 6 patch；收件人同 v2/v3：Dmitry + robh/krzk/conor + DT/input/LKML 列表）。
- **cover MID**：`<20261124045040.559317-1-xiaqinghuan@mail.ustc.edu.cn>`（新线程；SMTP 会话日志 `logs/sent-20261124-125040.txt`）。
- **门禁**：投前全绿，账 = `GATES-v4.md`（G1 6/6 落树 · G2 checkpatch 0 ERROR · G3 `W=1` 0W0E · G4 `dt_binding_check` rc=0 · G6 mailinfo 7/7；SEND.sh dry-run 亦过）。
- **lore 复核**：⏳ 待摄取 —— **已知教训（11-24 03:0xZ）：`linux-input` 侧摄取延迟可 >1 h**，不要在 1 小时内按「未归档」下结论；
  复核命令（≥1 h 后跑）：
  `curl -s 'https://lore.kernel.org/linux-input/?q=%22aw86927%22&x=A'` + `.../linux-devicetree/?q=aw86927&x=A`（找 `04:50Z` 批次）。
- **与 v3 的关系**：v3（`../aw86927-v3-prep-20261124/`，01:50Z 投出）已被本轮 v4 取代；sashiko 对 v3 的 4 条全部在 v4 6/6 处置。
