# #710 上游 pristine 板 DTS 上做 `fastboot boot` = **全盲实验**：DTB 里 `ufs` 是 `disabled`，内核起来也挂不到根

- 日期：2026-11-21 20:37（U2 HA2EXB0E，dwc3 v11 G7 首次上机）
- 触发：7.4-rc3 worktree（板 DTS 上游骨架 + dwc3 v11）打出的 `out/g7-20261121/boot-with-rolehook.img`
  经 `fastboot boot` 上机：`Sending OKAY / Booting OKAY`（12.0 s），之后 **60 s 内 `usb0`/`ttyGS0` 全无**，
  `lsusb` 只剩 `18d1:d00d`（fastboot）⇒ 已回落。

## 判据（可离线复现，不需要设备）

- **1) 先数 DTB 的「可观测面」**：`dtc -I dtb -O dts out/g7-20261121/sm8750-lenovo-elden.dtb | grep -c 'status = "okay"'`
  ⇒ **4**（整棵树只有 4 个节点是 okay）。上游 `sm8750.dtsi` 的骨架默认全 `disabled`，
  我们的板 DTS 只补了 USB 两连接器 ⇒ **USB 之外一个设备都没使能**。
- **2) 关键缺件是存储**：`ufs@1d84000 { … status = "disabled"; }` ⇒ 没有块设备 ⇒
  `root=LABEL=linux` 必然找不到 ⇒ `panic=15` ⇒ 回 fastboot。这与「内核坏」症状一致但归因完全不同。
- **3) 旁证**：回到 vk192 后 `journalctl --list-boots` 里失败那次**没有任何条目**、`/sys/fs/pstore/` 空
  ⇒ 从未到过 userspace（不是 systemd 之后崩）。
- **4) 通道自指**：`usb0`(NCM)/`ttyGS0` 就是被验的 dwc3 gadget（`initramfs/usb-gadget`）⇒
  gadget 一出问题就**连 panic 都看不到**；本板无物理 UART。

## 处置

- **判「能否上机」先算可观测面**：`dtc` 数 `status = "okay"`，逐个确认 **root 介质（ufs/nvme/mmc）**、
  **console 通道**、**判据要读的节点** 三者都在，缺一即「结构性不可观测」，别把它当回归去查。
- 要在上游树上验 USB/dwc3，必须同树使能 UFS（+ display/WCN 才能看副作用）；只加 USB 节点的树只能验「内核起没起」。
- 本次落盘：`reports/dwc3-g7-prep-20261121.md` §5；设备无写盘（`fastboot boot`），`fastboot reboot` 即回 vk192。
