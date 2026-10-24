# UEFI/异类载荷 `fastboot boot` 三坑：v3 header 被静默忽略、失败会标记当前槽 unbootable、ABL 日志在 logfs 分区（#387）

> 日期：2026-10-24 · 场景：把 Mu 构建的 UEFI（`gzip(BootShim ‖ FD)`）用 `fastboot boot` 零写盘上机。

## 坑 1：`mkbootimg --header_version 3` 的镜像本机 ABL「接受但不跳」

判据不是屏幕，而是 **USB**：

- **v3**：`fastboot boot` 回 `Booting OKAY [10.1s]`，但**设备留在 bootloader、fastboot 协议仍应答**（`getvar` 0.004 s、USB 设备号不变）⇒ 载荷从未执行。
- **同一 payload repack 成 v0**（`--base 0x0 --kernel_offset 0x8000 --pagesize 4096`）：`Booting` 阶段就 `usb_read failed: No such device`（USB 掉线）⇒ 真交棒。

⇒ 本机 ABL（`BOOT.MXF.2.5.1-00240.1-PAKALA-1.104055.4`）对 header v3 的支持是子集；**实验镜像一律用 v0**。
另：ABL 自己会 gunzip 内核（日志 `Decompressing kernel image total time: 288 ms`），所以 gzip 载荷不是问题。

## 坑 2：`fastboot boot` 失败会把当前槽标记 `slot-unbootable=yes` 并回落到另一槽

实测：载荷崩溃复位后设备起成 **stock Android（槽 a）**，`fastboot getvar` 得：

```
current-slot: a          slot-unbootable:b: yes       slot-retry-count:b: 6
```

⇒ 日用 Linux 在 `boot_b`，一次失败的实验就把它标成不可引导。恢复只需 `fastboot set_active b`（写 misc，不碰分区镜像），
随后 `slot-unbootable:b` 变 no、`fastboot reboot` 正常回 Linux。

**纪律**：每轮异类载荷实验结束都要回验 `slot-unbootable:<slot>`；不要用「能起来」判断槽状态。

## 坑 3：ABL 日志确实有，但在 `logfs` 分区，且不含崩溃那一发

- Linux 下读：`dd if=/dev/disk/by-partlabel/logfs bs=4096 | strings -n 5`（8 MiB，一次保留约 10 个 boot 会话）。
- 里面有 ABL 的决策信息（槽选择、`Memory Base Address`、cmdline、gunzip 耗时、DTB overlay 失败等），**非常有用**。
- 但**崩溃的那一发不会写进去**（UEFI 崩溃前不可能落盘；最新会话常还停在上一次启动）⇒ `logfs` 只能回答「ABL 做了什么」，
  回答不了「载荷死在哪」。要查后者必须另开通道（串口/USB 串口/落盘标记）。
