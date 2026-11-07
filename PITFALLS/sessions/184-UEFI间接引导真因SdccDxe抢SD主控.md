# #554 · UEFI 间接引导「交棒后 ~4 s 整机硬复位」的真因 = `SdccDxe` 抢初始化 SD 主控

- 日期：2026-11-07（深夜·三，G1-29，U2 `HA2EXB0E`，p58 一发闭环）
- 发现场景：`reports/uefi-p58-sdccdxe-handoff-success-20261107.md`

## 现象链

- UEFI 交棒成立（内核 cmdline 带 `elden_bootpath=uefi`），但内核在 **3.9–10 s** 处整机硬复位；
  ABL 下次启动记 `PM: Reset by PSHOLD / Hard Reset` + `PM: PON by SYSOK`。
- 3/6 发死亡现场的最后一行是 `mmc0: ADMA error: 0x02000000`，且 `ADMA Ptr: 0x0000000ffffff224`
  （一个荒谬的物理地址）；同一内核由 **ABL** 引导时 `mmc0` 完全正常。

## 真因

`fastboot boot` 路径上，UEFI 的 `SdccDxe` 会初始化 SD 主控（`8804000.mmc`），交棒前**没有收尾**
⇒ 内核接手后 DMA 描述符地址错 → ADMA error → 整机硬复位。
从 FV 里摘掉 `SdccDxe` 后，内核 `new high speed SDXC card @4.0 s`、`mmcblk0 58.6 GiB`、`probe returned 0`，
一路起到用户态。

## 关键纪律

- **摘一个 DXE 件，三处清单都要动**：`APRIORI.inc`（APRIORI FV）+ `DXE.inc`（主 FV）+ `DXE.dsc.inc`（`[Components]`）。
  只注 `DXE.inc` ⇒ 它仍被 APRIORI 拉进 FV 并 dispatch，单变量试验会得出「不是它」的**假阴性**。
- **「时间到就复位」不能只看时间**：本轮先做了三条关看门狗的路全证伪（`PITFALLS #552`），
  再靠「fault handler 自旋 15 min 不复位」排掉定时器假设，才把注意力转回内核现场。
- 复位源字段（`Reset by PSHOLD` / `PON by SYSOK`）只说明「AP 侧拉低 PS_HOLD」这一条路径，
  **不能**据此指名某一枚看门狗。
