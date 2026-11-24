# aw86927 v4 备料（2026-11-24）——**未投递，等放行**

- 触发：sashiko 对 v3 6/6 的 **1×[High] + 2×[Medium] + 1×[Low]**（2026-11-24T02:03:12Z，四条全成立）
  ＋ 收取 Joonhoe Kim 给 v2 4/6、5/6 的 `Tested-by`（`reports/comm-triage-20261123.md` A2 开放项）。
- 内容：1–5 与 v3 逐字节相同（4/6、5/6 各加一枚 `Tested-by`）；6/6 重写，四条意见逐条处置见 `GATES-v4.md` §1。
- 门禁（全绿）：G1 6/6 干净落树 · G2 checkpatch 0 ERROR（2 条已知 `Unknown commit id` 假阳性）·
  G3 `W=1` 编 `drivers/input/misc/aw86927.o` rc=0/0 warning · G4 `dt_binding_check` rc=0 · G6 mailinfo 7/7。
  基线 7.4-rc3（`aebb727447`），与 v3 同；**未**在 linux-next 复验（本地无该树）。
- 与 v2/v3 的关系：v2 = `../haptics-v2-20261117/`（已投 6 封，有 `SENT.md`）；v3 = `../aw86927-v3-prep-20261124/`
  （备料，**已被 v4 取代**，别再投 v3）。
- 投递：**未发**。放行后 `bash SEND.sh`（默认 dry-run，`--yes` 才真发；收件人同 v2：7 封、新线程）。
  投前建议先在 **linux-next 基线**复跑 G1（预期最多 1 行 `#include` 漂移，必要时按该基线重出 6/6）。
