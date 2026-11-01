# #479 · UEFI「交棒/不交棒」判据曾被 boot image v0 header 污染 —— 同载荷换 header 结果翻面

- 日期：2026-11-01（上机实测，零写盘 10 发）
- 适用范围：`fastboot boot` 任何「异类载荷」（Mu UEFI / BootShim / 自写 shim），不只 UEFI 线。

## 现象（一句话）

`fastboot boot <img>` 的两种结局 **不是载荷属性**，而是 v0 **header 字段**决定的：

| 结局 | 现场 | 判读 |
|---|---|---|
| **接受（HANDOFF）** | 数据传输 ACK 后 **0.05 s** 内 `Booting FAILED (usb_read failed)`，USB 消失 | ABL 已开始启动（拆 USB）；载荷随后执行 |
| **拒绝（NOJUMP）** | **恰好 ~10.1 s** 后 `Booting OKAY`，USB 不断、bus/device 不变、`getvar` 继续 0.004 s 应答 | ABL 从未启动它，回到菜单 |

## 硬证据

`N2-v0b.img`（10-30，**拒绝**，2/2 复现）vs `N2-repack-v0.img`（本轮，**接受**）：等长、**同一份 gz 载荷字节**
（把新 payload 写回旧件得到的 sha256 = 旧件原件），逐字节 diff 只有 7 段：`ramdisk_addr`(0x14)、`second_addr`(0x1c)、
`os_version`(0x2c)、`id`(0x240)、`dtb_size`(0x66c)、`dtb_addr` 高 16 位(0x676)。
`id` 与 `kernel_size` 已各自用单变量排除。

## 规则（工程口径）

- 本机做异类载荷实验**只用一个打包口径**：`mkbootimg --header_version 0 --base 0x10000000 --kernel_offset 0x8000 --pagesize 4096`，
  **不传** `--os_version/--ramdisk/--second/--dtb`，让这些字段全零。工具 = `scripts/uefi-build-variant.sh`。
- **不要**沿用「从某份成品 header 复制再只改 kernel_size」的打包法：会带入 `os_version=0x1e000133`、`ramdisk_addr=0x01000000`、
  `second_addr=0x10f00000`、`dtb_size=0x067c`、`dtb_addr=0x11f0xxxxxxxx` 这些遗留值，行为不可预期。
- 判据纪律：**`Booting OKAY` ≠ 载荷跑了**；`Booting FAILED (usb_read failed)` 才是「ABL 接受并开始启动」。
  `lsusb` 仍见 `18d1:d00d` 时必须再用 `fastboot getvar product` 证明 ABL 活着（只有 lsusb 不算证据）。

## 代价

10-30/31 一整批结论（「交棒需厂商 UFSDxe × cachefix shim」「E1/X1/X2 交叉换件」「重建即失效」「早期写 FB 致命」）
全部建立在被污染的判据上 ⇒ 那 7 发载荷**从未被执行**，结论作废。纠正与重测见
`reports/uefi-cleanheader-reframe-20261101.md`。
