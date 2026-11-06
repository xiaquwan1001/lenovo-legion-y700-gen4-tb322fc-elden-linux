# #523 · `ExitBootServices` 之后**宿主侧判据天然失效**（≠ 崩溃）+ 同会话 stage≥40 会污染

> 索引行见 `PITFALLS/README.md`；2026-11-06 傍晚 UEFI 线（G1-29）上机取证。
> 证据：`reports/uefi-onboard-walkthrough-20261106.md` §1–§2、`reports/artifacts/uefi-p9-onboard-20261106/results.tsv`。

## 结论（两条，一条判据 + 一条纪律）

### A. EB 之后「无应答」不是崩溃判据

`ShutdownUefiBootServices()` 真的调 `ExitBootServices` 之后，USB 设备栈被拆 ⇒ 后续标记**回不了宿主**。
实测现象：`fastboot boot` 无 diag 响应，但**屏上刷** `UsbfnDwcCorePoll: Usbfn is not enabled` /
`UsbDeviceSend: … USB cable not attached`，同时 `fastboot devices` 仍列着序列号（端点还在，功能已死）。

- 误判代价：历史上 2026-11-05 前后把「`sbstop=7`/`41`/`42` 无应答」读成
  「`ShutdownUefiBootServices` 崩溃」，据此绕了很多路。
- 对策：**EB 之后只能用屏**（`PITFALLS #492/#515` 给的可写预算很小 ⇒ 用 `--scale 1` 把每行从 274 KiB
  降到 91 KiB，448 KiB 预算就能放 ~4 行）；并且**必须把标记切在 EB 前后各一个**，否则无法区分。

### B. 同一固件会话连打「stage ≥ 40」的件会把后续打成 `Load Error`

实测：一个会话里先打 `stop40`（回话）→ 再打 `stop41` → 之后 **连 `stop40` 也退化**成
`diag st=Load Error last=[[K] ldt=Load Error]`（= `LoadAddrAndDTUpdate` → `UpdateDeviceTree` 失败），
同一件连打 4 发全同、换会话（重载 preamble）立刻恢复。

- 结论：**EB 之后的档位，一个固件会话只能打一发**；要连打必须重载 preamble（或断电）。
- 别把它当「镜像坏了/构建坏了」：同一 sha 的件在换会话后行为完全正常。

## 判据/纪律

- 「无应答」要先分三态：`DEAD`（USB 不枚举）/ `ENUM_DEAD`（枚举但 getvar 无应答）/ `REPLY`。
  只把 `REPLY` 当「到达」，其余必须结合**屏上**现象归类（EB 后 / 递归 dump / 端点 shutdown）。
- 停机点表里凡是跨过 `ExitBootServices` 的档位，判据旁边必须写一句「此档宿主不可达」。
