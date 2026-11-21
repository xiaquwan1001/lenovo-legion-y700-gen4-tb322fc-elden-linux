# 设备停在 BL 的真根因：`ValidateSlotGuids: BootableSlot _b does not have valid guids`（2026-11-21 晚）

> 一句话：**不是内核、不是 boot_b 内容、也不是 vbmeta_b**。ABL 在 `FindBootableSlot()` 里判定
> 「b 槽没有合法 GUID」⇒ `LoadImageAndAuth()` 直接 `Device Error` ⇒ `Launching fastboot`。
> 触发条件与 `scripts/gpt-slot-flip-active.py` 头部记录的历史坑**同一类**：`fastboot --set-active`
> 会在两个槽之间搬 **partition type GUID**，连续/重复调用会留下「GUID 在一侧、ACTIVE 位在另一侧」的半完成态。

## 1. 证据（XBL/ABL 自己的 log，不是推断）

来源：EDL 读 `logfs`（LUN4 sector 409595，8 MiB），FAT12 卷内文件 `UEFILOG1.TXT`
（`mdir -i logs/restore-20261121/logfs-now.bin ::/`）。

```
437:B - ... - Fastboot=0, Recovery:0
439:B - ... - Loading Image recovery_b Done : 1 ms, Image size : 4096 Bytes
442:B - ... - Active Slot _b is bootable, retry count 6
443:B - ... - ValidateSlotGuids: BootableSlot _b does not have valid guids
446:Err: line:1866 FindBootableSlot() status: Device Error
447:Err: line:2167 LoadImageAndAuth() status: Device Error
448:LoadImageAndAuth failed: Device Error
449:Launching fastboot
```

- 这解释了全部表象：`fastboot reboot` 后 USB 断 ~4 s 又回 fastboot（ABL 根本没进内核，
  屏上也不会出 Linux）；`fastboot boot <img>` 也报同一句 `Failed to load/authenticate boot image: Device Error`
  （走的是同一个 `LoadImageAndAuth`）。
- **`retry count 6` 说明槽位属性本身没被吃光**，`Active Slot _b is bootable` 也说明 ACTIVE 位是对的
  ⇒ 剩下的只有 GUID 合法性这一条。

## 2. 与 GPT 现状对照（几何/GUID 未变，只有属性字节在动）

`backup/HA2EXB0E-16+512/edl-20261120-2208/gpt4-primary.bin`（11-20 基线，当时 b 槽正常起 Linux）
vs `logs/uefi-flashed-20261121/lun4-gpt-primary.bin`（11-21 15:21 EDL 现读）：

- 68 个分区名/几何/type GUID **全部相同**；
- 只有 12 处 attribute 字节差异（`boot_a/boot_b/aop_b/tz_b/hyp_b/modem_b/abl_b/keymaster_b/devcfg_b/qupfw_b/vbmeta_b/dtbo_b`），
  即 ABL 自己每次启动/`set_active` 时写回的那些位。

⇒ 15:21 那份表看上去还是自洽的；**之后的 `fastboot --set-active=b`（本轮又调了两次）把 GUID 侧搬过去了**，
这才落到 `ValidateSlotGuids` 失败。这正是 `scripts/gpt-slot-flip-active.py` 注释里那句
「用 fastboot set_active 连做两次会出现 GUID 落在 b 侧、ACTIVE 位却在 a 侧的半完成态」。

## 2.5 判据原文（源码级，别再猜）

`build/uefi-woa-prep/merge-espfirst-20261121/tree/Platforms/QcomModulePkg/Library/BootLib/PartitionTableUpdate.c`

- **判定**（`:1542-1602` `ValidateSlotGuids`）：取 **`boot_<slot>`** 与 **`abl_<slot>`** 两个条目的
  `PartitionTypeGUID`，**若两者相同 ⇒ `EFI_DEVICE_ERROR`**，DEBUG 就是 `BootableSlot %s does not have valid guids`。
  同一函数后面还有一条 LUN 判据：UFS 下 `UfsBootLun` 必须 `0x2 ⇔ _b`、`0x1 ⇔ _a`，否则
  `Boot lun: %x and BootableSlot: %s do not match`（本次日志里**没有**这条，说明先倒在前一条）。
- **`set_active` 干了什么**（`:560-621` `SetActiveSlot`）：对 `GetMultiSlotPartsList()` 里的**每一对**
  `X_a`/`X_b` 调 `SwapPtnGuid()` **交换 PartitionTypeGUID**，然后对 UFS 额外把 **boot LUN** 在 1↔2 之间切
  （`:606-617`），最后 `UpdatePartitionAttributes(PARTITION_GUID)` 写双表。
  ⇒ **它是「整表 GUID 侧换边 + 切 boot LUN」的复合动作，不是幂等的**：连做两次 = 换回来，
  但只要中间有一次没走到最后（超时/`getvar` 无回包/我们打断），就会停在半完成态。
- 现表与 11-20 基线逐分区比（本机两份 dump）：68 个分区名/几何/type GUID 全同，只有 12 处 attribute 字节差异
  ⇒ 15:21 那份表**看起来仍是自洽的**；砖是在其后又调了 `--set-active` 才形成的。**因此只有 EDL 现读**才能判定，
  不能拿仓里 15:21 的 dump 当现状。

## 3. 修复方案（待设备 bootloader 恢复响应后执行）

已固化成一键脚本：`scripts/recover-lun4-slotguid.sh`（默认 dry-run；`--apply` 才写盘；
`--from-dir DIR` 可离线干跑判定）。它做的事：

1. 探活（`getvar current-slot` 无回包 = ABL 半挂 ⇒ 直接报错要求物理断电，连发命令没用）；
2. `fastboot oem edl` → 读 LUN4 主表 `0+6`，从主表解析 `alt_lba` 再读备表；
3. 与 `backup/HA2EXB0E-16+512/edl-20261120-2208/gpt4-{primary,backup}.bin` 逐分区比
   **type GUID / 几何 / ACTIVE 位**，并单独打印 `boot_<slot> vs abl_<slot>` 是否相等（ABL 的原判据）；
4. 判定：GUID 侧不同 ⇒ 写回基线对表；只有 ACTIVE 位不对 ⇒ `gpt-slot-flip-active.py` 只补属性位；
   两者都对 ⇒ 说明问题不在 GPT（回 `logfs` 的 `UEFILOG1.TXT` 看下一条判据）；
5. 写盘一律经 `scripts/linux-gpt-apply.sh --apply --reset`（写前 dump + 写后逐字节读回 + O_DIRECT sha + 设备端 sha256 双尺子）。

手动等价命令（脚本不可用时）：

1. `fastboot oem edl` → `qdl read 4/0+7` 取当前主/备表；
2. 与 `backup/HA2EXB0E-16+512/edl-20261120-2208/gpt4-{primary,backup}.bin` 逐分区比 **type GUID**；
   - 若 GUID 侧与 11-20 基线不同 ⇒ 直接把 11-20 那一对表写回（当时 = b 槽 active 且能起 Linux）；
   - 若 GUID 侧与基线相同、只有 ACTIVE 位不对 ⇒ 用 `scripts/gpt-slot-flip-active.py --activate b` 只补属性位。
3. 写盘一律走 `scripts/linux-gpt-apply.sh --lun 4 --gpt … --backup … --apply`（内建写前 dump + 写后逐字节读回 + O_DIRECT sha）。
4. 复位后普通重启，判据 = SSH 回来 `uname -r` = vk192（`out/boot-elden-vk192.img` 口径），`qbootctl` b 槽 Active/Successful/Bootable=1。

## 4. 本轮同时排除/确认的项（避免下一轮重跑）

| 项 | 结论 | 依据 |
|---|---|---|
| `boot_b` 内容 | **不是原因**（换成 `bootslot-b/boot_b.img` = vk192 签名件 06c081ca 仍同样失败） | 本轮 flash boot_b 后重启仍回 BL |
| `vbmeta_b` | **不是原因**（`out/vbmeta-b/vbmeta_b-flags3.img` 已刷，ABL 在 FindBootableSlot 之前就退出了） | logfs 顺序：GUID 校验在 LoadImageAndAuth 内、AVB 之前 |
| `vendor_boot_b`（下午被改成 FAT32 ESP） | **不是原因**（写回原厂 `backup/official-rom-15.10.259/vendor_boot.img` 仍同样失败） | 本轮实测；但**该分区已恢复原厂件**，UEFI ESP 形态丢失（若要重做需重新写） |
| `misc` BCB | 干净（头 4 KiB 全 0） | `logs/restore-20261121/misc-now.bin` |
| 电池/供电 | 正常（`battery-voltage: 4294`、`battery-soc-ok: yes`） | `fastboot getvar all` |
| `fastboot --set-active` 的副作用 | **有**：会搬 type GUID，是本次砖的直接机制 | 本节 §2 + 脚本注释 |

## 5. 操作纪律（本轮新增/重申）

- **不要用 `fastboot --set-active` 切槽**；Linux 侧用 `qbootctl -s <slot>`（已实测可用），主机侧只在
  确实需要时用一次，并在之后**立刻**用 EDL 复核 GUID 侧与 ACTIVE 位是否一致。
- BL 侧一但出现「`fastboot devices` 能看见、`getvar` 无回包」，说明 ABL 卡在半挂状态 ⇒ 只能**物理断电/长按电源**，不要连发命令。
