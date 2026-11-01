# #482 · `fastboot boot` 的**接受/拒绝是非确定性的**，不能拿 header 逐字段差分去追

- 日期：2026-11-01（上机，零写盘；详见 `reports/uefi-ddr-blackbox-20261101.md` §6.1 与本文件）

## 观测

同一份**未改动**的镜像 `reports/artifacts/uefi-ddr-20261101/clean2/uefi-v0.img`（sha `423188a0…`），
同一 header，连续上机三次三种结果：

| 次 | 时间 | 主机侧 | 判读 |
|---|---|---|---|
| r1 | 13:42 | `Booting FAILED (usb_read failed)` + USB 消失 | HANDOFF（ABL 接手） |
| r2 | 13:54 | `Booting OKAY [10.145s]`，fastboot 仍应答 | NOJUMP（ABL 拒绝） |
| r3/r4 | 13:57 / 14:06 | `Failed to load/authenticate boot image: Invalid Parameter` | 拒绝（第三种回话） |

补充事实：`qbootctl -u a` 把另一槽标成 unbootable 之后连拒多次，`-m a` 恢复后又接受 ⇒
**接受与否与「另一槽是否 bootable」相关**（ABL 在这条路径上确实在校验/分支，不是盲跳）。

## 结论

- **`Booting OKAY` ≠ 载荷跑了**；**`usb_read failed` 也 ≠ 载荷跑了**（只 = ABL 接手）。
   两者都不是「载荷执行」判据，只是 ABL 侧的分支指纹。
- **不要再用 boot image header 逐字段差分去追「接受规则」**——同 header 同字节可以三次三结果，
   历史上「`A2-v0b` ✅ / `N2-v0b` ❌，header 只差 `kernel_size`+`id`」的矛盾属于这类假归因。
- 判据必须写成**统计式**：同一镜像重复 N 发，只统计真正 HANDOFF 的发次；每发先确认本次真的被接手。
- 82 MB 级镜像走 `fastboot boot` 会让 ABL 自己**挂死在 logo**（`PITFALLS #481` 第三态）⇒
   该路径不适合承载「内核 + 大 ramdisk」，也不适合当临时读取通道。

## 附带

- 走了「槽位正常启动」路径（把 ddrmarks 载荷签进 `boot_b` 再 `reboot`）之后，本机进入
  **「只能进 fastboot」**的状态，刷回原厂 `boot_a` / `erase misc` / 物理断电都没恢复 ⇒ 见 `TASKS/README.md`
  §5「2026-11-01 16:39」块与 `DEVICE/README.md` §1.1 首条（归因待 EDL 读回 `logfs`）。
