# patches/local/fastrpc-sensorspd-20261126 — SENSORS_PD 消息缓冲走 remote heap（上游未合入的回移件）

## 补丁是什么

**1 行修复**：`drivers/misc/fastrpc.c` `fastrpc_get_args()` 里，SENSORS_PD 的消息缓冲
即使 `sctx->sid` 非零也要走 `fastrpc_remote_heap_alloc()`（remote heap），而不是
context bank（SMMU IOVA）分配——sensors PD 直接访问该缓冲（不经 context bank），
context bank 分配会让 DSP 访问其地址空间未映射的内存 ⇒ SMMU context fault
（如 `fsr=0x402 iova=0x1fffff000`）或 bus stall。

- 修改前：`if (ctx->fl->sctx->sid)`
- 修改后：`if (ctx->fl->sctx->sid && ctx->fl->pd != SENSORS_PD)`

## 出处（原文，逐字）

- Message-ID：`<20261003150559.6926-2-pc1598@mainlining.org>`
- 主题：`[PATCH v2 1/1] misc: fastrpc: Allocate message buffer from remote heap for sensors PD`
- 作者：Robin Snyders（代码）／Piyush Raj Chouhan（投递），R-b：Dmitry Baryshkov（2026-10-05 回复）
- 日期：2026-10-03
- 原文：https://lore.kernel.org/linux-arm-msm/20261003150559.6926-2-pc1598@mainlining.org/
  （封面信 https://lore.kernel.org/linux-arm-msm/20261003150559.6926-1-pc1598@mainlining.org/ ）
- 实证背景：SM8150 SLPI 上 hexagonrpcd attach sensors PD 即 SMMU context fault →
  `PDM: service 'sensor_process' crash` → `crash detected in slpi`；修后 attach 干净、QRTR svc 出数。

## 为什么落在 patches/local/（而非 patches/ 上游回移常规位）

父代理 2026-11-26 复核：torvalds `master` 与 `gregkh/char-misc.git` 的
`char-misc-next`/`char-misc-linus` 三处 `fastrpc.c` 都**没有**该修复；
patchwork state=`handled-elsewhere` 但树上无痕。**上游未合入 ⇒ 只能作为 local 回移件管理**，
待上游合入后本目录作废（删除并以 patches/ 常规上游件取代）。

## 在本项目里的用途（工单 S2，2026-11-26）

检验 `reports/sensors-hexagonrpcd-20261126.md` 假说 A（~85% 静态置信）：
本机 SM8750 ADSP compute-cb `reg=3..8`（sid 非零）+ 在机内核未含此修复 ⇒
`hexagonrpcd … -s`（INIT_ATTACH_SNS）第一条 RPC 即 SMMU fault ⇒ sensors PD fatal ⇒ 整机复位
（`PITFALLS #692`）。判据：打上本补丁的试验内核上 attach 存活 ⇒ A 证实；仍崩 ⇒ 排除 A，指向 B/C。

## 门禁（2026-11-26 实测）

- `git -C build/daily apply --check <本补丁>` = rc 0（干净）
- `build/daily/scripts/checkpatch.pl --no-tree <本补丁>` = **0 errors / 0 warnings**
