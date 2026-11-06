# pre-stop18（`FindBootableSlot` 之后）— 1 发，零写盘

| 项 | 值 |
|---|---|
| 件 | `out/r21-sbstop/pre-stop18.img` sha256 `d66d2365…7e5ded`（= preamble `7757114d…` + cmdline 令牌 `sbstop=18 `，`cmp -l` 仅 9 字节差，offset 65–74） |
| ABL 载入 | `Sending 1.488s` / `Booting OKAY 10.108s` |
| UEFI 侧 fastboot | ~6 s 出现，ser `51318dc0`，VID `045e:0c2f` |
| 打这一发 | `fastboot -s 51318dc0 boot pre-stop18.img` → `Sending OKAY 1.494s` 后 `Booting` 无终局，45 s 超时 rc=124 |
| 判据 | 设备**仍枚举**（同一 Device 040，未重枚举）；`getvar product` 12 s **零字节**、无 endpoint shutdown 字样 ⇒ `NO_SERVICE` = 递归异常 dump 死循环 |

## 判读

`diag st=Aborted last=[vs-18]` **未出现** ⇒ 崩在 `FindBootableSlot()` 之后这个标记点**之前**。
结合上一轮 `pre-stop19`（`GetAVBVersion` 之后）同样崩 ⇒ 崩溃窗口 ⊂ `LoadImageAndAuth()` 前导，
且首个嫌疑仍是 `FindBootableSlot()`（`PartitionTableUpdate.c:1603`）。

**注意**：这一发**不能**单独把窗口收进 `FindBootableSlot` 函数体 —— 需 `pre-stop17`（`WaitForFlashFinished` 之后）：
回话 ⇒ 崩点在 (17,18] = `FindBootableSlot`；崩 ⇒ 再打 `pre-stop16`（函数入口）继续左移。

## 下一步

1. **物理断电**（长按电源）→ 回 ABL fastboot（`HA2EXB0E`，`product: elden_prc_wifi`）。
2. 打 `pre-stop17`，然后 `pre-stop16`（各 1 发，崩一次断电一次）。
