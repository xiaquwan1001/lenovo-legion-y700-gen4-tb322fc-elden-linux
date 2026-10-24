# 厂商 DT 节点的属性值可能是「每次开机新发」的：先取两个样本再决定静态还是动态（#388）

> 日期：2026-10-24 · 场景：从 stock Android 的 live DT 取 Gunyah RM 节点 `reg`（tx/rx capid），准备写进主线 DTB。

## 现象

同一台机器连续两次 `adb reboot`，节点名与属性都变：

| 样本 | 节点名 | `reg` |
|---|---|---|
| 1 | `qcom,resource-manager-rpc@90d561f5f0ee2c27` | `0x90d561f5f0ee2c27 / 0x90d561f5f0ee1c7c` |
| 2 | `qcom,resource-manager-rpc@ea54cae59f233167` | `0xea54cae59f233167 / 0xea54cae59f23de12` |

高 48 bit 相同、低 16 bit 不同（= 每次开机新生成的基 + 一对队列索引）；同批节点里的 `interrupts`（SPI 960/961）则完全不变。

⇒ 若只取一个样本就「写死进 DTB」，下一次开机会静默拿错 capid（驱动照样 probe，RPC 全超时，很难看出是值的问题）。

## 纪律

- **凡是「运行时注入」的 DT 节点（由 bootloader/TZ/驱动在启动时生成，而不是静态 dtb/dtbo 里的），取值前必须连续两次开机对比**：
   判据 = 同名属性两次是否逐字节一致；不一致就说明必须运行时发现，静态写死无效。
- 判断「静态还是运行时」的廉价方法：`rg` 该属性值/节点名后缀在 `dtbo_*`、`vendor_boot_*`、`dtb/*` 等本地固件 blob 里是否 0 命中（0 命中 = 运行时生成）。
- 运行时生成的值要在主线里拿到，只能复刻生成者的**发现通道**（本机 = ABL `RmVmDxe` 调 SCM SIP `0x02000609` 取「hyp boot info」，magic `0xC06B0071`），不是去读 DT。
