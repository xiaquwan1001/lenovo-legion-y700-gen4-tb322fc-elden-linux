# UEFI 镜像 A 首次上机（2026-10-24 晚）：**header v3 不 handoff，v0 repack 才真跳；载荷死在 UEFI 早期，全程无可见性**

> 只做零写盘 `fastboot boot`。**未写任何分区**（唯一副作用见 §5：槽标记，已恢复）。
> 对象：`reports/artifacts/uefi-built-20261024/lenovo-y700g4-A.img`（sha256 `e0d4a904…`，2 445 312 B）。
> 设备：`HA2EXB0E`（U2，SM8750P 16+512）。

## 0. 结论（先数字）

| 试验 | 镜像 | 结果 |
|---|---|---|
| T1 | 原样 A（`mkbootimg --header_version 3`，无 ramdisk，cmdline 空） | **ABL 不 handoff**：`Booting OKAY [10.1s]` 后设备留在 bootloader（屏幕是联想 logo），**`fastboot getvar` 仍 0.004 s 应答**（同 USB 设备号 064，未重新枚举）⇒ 载荷**从未执行** |
| T2 | 同一载荷 repack 成 **v0**（`--base 0x0 --kernel_offset 0x8000 --pagesize 4096`） | **真 handoff**：`fastboot boot` 报 `Booting FAILED (usb_read failed: No such device)`，USB 掉线、fastboot 不再应答 ⇒ ABL 确实跳了 |
| T2 后 | — | 约 25 s 后设备以 **`17ef:7f3d` ADB** 枚举 = **stock Android 16**（`6.6.118-android15`、`ZUXOS_1.5.10.259`），`ro.boot.slot_suffix=_a` ⇒ 载荷崩溃/复位后 ABL **回落到槽 a** |
| 恢复 | — | `fastboot set_active b` 一次即恢复（`slot-unbootable:b` yes→no），`fastboot reboot` 回 vk127 Linux（25 s 上线） |

**⇒ 本轮把问题从「镜像做错了没有」推进到「UEFI 载荷在早期死掉」，但没有拿到任何内部可见性**（无串口、无显示输出、无落盘通道）。

## 1. 载荷结构（反解确认，与构建记录一致）

`.img` 的 kernel = `gzip(BootShim.bin(112 B) ‖ SM8750_EFI.fd(4 MiB))`：kernel_size 2 437 474 B，
gunzip 得 4 194 416 B = 112 + 4 194 304，其中 **fd sha256 `eb00db73…` 与 `SM8750_EFI-A.fd` 逐字相同**。

`BootShim.bin` 语义（`build/uefi-woa-prep/repos/7-mu-lenovo/BootShim/BootShim.S` + 二进制核对）：

- 头 8 字节是假 ARM64 Image 头（`adr x1,_Payload; b _Start`），偏移 8/16 是 `.quad UEFI_BASE / UEFI_SIZE`；
- 实测 **`UEFI_BASE = 0xff300000`、`UEFI_SIZE = 0x400000`**；
- 逻辑 = 「若自身不在 `0xff300000`，就把后面 4 MiB 原样拷到 `0xff300000`，然后 `br` 过去」，FD 首字节是 `b` 到 FV 入口。

## 2. T1：v3 header 被本机 ABL 静默忽略（新事实）

- `mkbootimg --header_version 3` 的镜像，本机 ABL（`BOOT.MXF.2.5.1-00240.1-PAKALA-1.104055.4` / `SocPakalaLAA`）**接受并回 OKAY，但不跳**：
  屏幕停在 bootloader（联想 logo），**fastboot 协议仍活着**。这一条本身就能当判据用 —— 真 handoff 时 USB 会掉（见 T2）。
- 同一 payload 只换 header 版本就变成「真跳」⇒ **v3/v4 支持是本机 ABL 的子集，不能用**；迭代一律用 v0（与日常 Linux 镜像同口径）。

## 3. T2：v0 跳了，然后死掉（位置未知）

`fastboot boot` 的 `Booting` 阶段 USB 立即掉线（`usb_read failed: No such device`）＝ABL 已交棒；随后设备复位并以 stock Android 出现。可能的死亡点有三层，**本轮无法区分**：

1. BootShim 的 4 MiB 拷贝（写 `0xff300000` 后 `br`，**没有 dcache clean / icache invalidate**，若 ABL 交棒时 cache 未关，这条路必炸）；
2. FD 的 SEC/PEI 早期（DDR/HOB/SCM 依赖）；
3. DXE 早期（本机 UFSDxe 代次差那一层还没轮到，因为连显示都没出来）。

## 4. 观察通道盘点（结论：目前为零）

| 通道 | 状态 |
|---|---|
| UART | ABL 日志明写 `get uart controll value:0x0` / `UartOpened is 0x0` ⇒ UART 未开，且本机无引出的调试口 |
| ABL 日志 `logfs` | ✅ **可读**：Linux 下 `/dev/disk/by-partlabel/logfs`（8 MiB，`/dev/sde68`）。本次抓到 10 个 boot 会话，含 `Memory Base Address: 0x80000000`、`Decompressing kernel image total time: 288 ms`（**ABL 自己会 gunzip kernel**，该行取自一次 mainline `fastboot boot`） |
| 但 | **崩溃那一发的日志不在 logfs 里**（UEFI 崩溃不可能写盘；且 logfs 里最新会话还停在上一发）⇒ 这条路只对「ABL 侧决策」有效，对载荷内部无效 |
| 显示 | UEFI 没到 GOP/显示初始化（屏幕仍是 ABL splash） |
| EDL(9008) | 只能读/写分区（firehose），**不能观察 RAM 里的 UEFI**；本轮未用 |

## 5. 副作用与恢复（重要）

- 失败的 `fastboot boot` 会让 ABL **把当前槽标记 `slot-unbootable:b = yes` 并切到槽 a**；`slot-retry-count:b = 6` 不变。
  恢复：`fastboot set_active b`（写 misc，非分区镜像）→ `slot-unbootable:b` 变 no → `fastboot reboot` 回 Linux（实测 25 s SSH 上线，UTS `vk127`）。
- 已记入 `PITFALLS` #387：**每轮 UEFI/异类载荷实验后必须回验 `slot-unbootable:b`**，否则下次会莫名起成 Android。

## 6. 判断与建议（待用户裁决）

1. UEFI 路线现在的成本结构变了：**不是「UFSDxe 修不修」的问题，而是「Mu 在本机连第一屏都出不来且零可见性」**。继续等于盲调，一次试验要人工断电/回槽。
2. Gunyah 侧取 capid 的三条路里，**A 路（Magisk 补丁 stock boot，`fastboot boot` 零写盘 root，读一次 `/proc/device-tree/hypervisor/*/reg`+`interrupts`）成本最低且通道可靠**（同一条 `fastboot boot` 已被本轮反复证明可用）。
3. 若仍要推 UEFI：先补**一个可见性**再谈修 bug —— 候选 ① 给 BootShim 加 `dc civac`/`ic iallu` + 串口改 USB（Mu 的 `UsbSerial`）；② 换已知能在本机跑的 FD（如 `Droid-VM/edk2-gunyah` 的 tb322fc 产物）做对照，把「打包/交棒」与「Mu 平台支持」分开。
