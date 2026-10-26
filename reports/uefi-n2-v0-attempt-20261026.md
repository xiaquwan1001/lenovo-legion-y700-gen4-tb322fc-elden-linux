# UEFI N2（BootShim cache 修复 + v0 repack）上机：**仍零可见性**，ABL 回落到 stock Android 槽 a

日期：2026-10-26 19:18–19:22　设备：`HA2EXB0E`（U2）　全程零写盘 `fastboot boot`

## 0. 结论（先数字）

| 判据 | 结果 |
|---|---|
| 镜像 | `lenovo-y700g4-N2-v0.img`（纯 Mu + cache 修复 BootShim，sha256 `0cef239a03e4e0b7…`） |
| ABL 是否交棒 | **是** —— `fastboot boot` 报 `Booting FAILED (usb_read failed: No such device)`（= 真跳，见 `PITFALLS #387`） |
| 交棒后 60 s | **USB 全静默**（`lsusb` 无 `18d1/05c6/17ef`、无 fastboot、无 SSH） |
| 交棒后 ~82 s | 设备重新枚举为 **`17ef:7f3d` = stock Android**（`TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259`、`ro.boot.slot_suffix=_a`） |
| 槽副作用 | `current-slot=a`、`slot-unbootable:b=yes` ⇒ 已 `fastboot set_active b`（yes→no），`fastboot reboot` 后 **19:22:18 Linux vk163 重新上线** |
| **J1（可见性）** | **未达成**：D-cache clean + I-cache invalidate 这一层不是「UEFI 早期死亡」的唯一/主要根因（或不是唯一缺口） |
| **屏幕实测（用户目视，19:18:56–19:20:18）** | **全程联想 logo** —— 没有黑屏切换、没有 UEFI 菜单/文字 ⇒ UEFI **从未走到 GOP/显示初始化**，与「载荷死在 DXE 之前」一致；也证明 ABL 交棒后没有任何可见的活体证据 |

## 1. 为什么先重打包

10-26 lane 交付的 A2/N2 是 **`mkbootimg --header_version 3`**（`Platforms/PakalaPkg/PythonLibs/PostBuild.py` 固定 v3），而 `PITFALLS #387` 已证本机 ABL **静默忽略 v3**（回 `OKAY` 但不跳）。
⇒ 直接 `fastboot boot` 原 A2/N2 会得到「假阴性」。本次先按 10-24 的 v0 口径重打包（载荷逐字节同源）：

```
python3 scripts/mkbootimg.py --kernel <v3 镜像 offset=4096 起的 kernel> --ramdisk <empty> \
  --header_version 0 --base 0x0 --kernel_offset 0x8000 --pagesize 4096 --cmdline ""
```

| 产物 | 大小 | sha256 |
|---|---|---|
| `reports/artifacts/uefi-v0-20261027/lenovo-y700g4-N2-v0.img` | 2 441 216 | `0cef239a03e4e0b7f507aab6afc4c7530ccf6679f431edb242fa4296bc988025` |
| `reports/artifacts/uefi-v0-20261027/lenovo-y700g4-A2-v0.img` | 2 445 312 | `2282953b490f4375d741b01351a838ef56de62331b394382472eef2144332b9b` |

载荷核对（gunzip 后）：shim **160 B**（含 `dc civac`=`d50b7e25`、`ic iallu`=`d508751f`；`UEFI_BASE=0xff300000`、`UEFI_SIZE=0x400000`）+ FD 4 MiB
（N2 fd sha256 `6d51c190…` = 10-24 N 的 fd ⇒ **唯一变量就是 BootShim**）。

## 2. 时间线

| 时刻 | 事件 |
|---|---|
| 19:18:56 | `fastboot boot N2-v0` → `Sending 2384 KB OKAY [0.055 s]` → `Booting FAILED (usb_read failed)` = ABL 交棒 |
| 19:19:01–19:19:56 | 每 5 s 轮询：USB 0、fastboot 0、SSH 0（UEFI 要么没起 USB 栈，要么已死） |
| 19:20:18 | 以 `17ef:7f3d` + ADB 出现（stock Android，`_a` 槽）⇒ 载荷崩溃/复位后 ABL 回落槽 a |
| 19:21:4x | `fastboot set_active b`、`slot-unbootable:b` yes→no |
| 19:22:18 | Linux vk163 重新上线（SSH 20 s 内） |

对比 10-24（无 cache 修复）：同样「交棒后无输出 → 回落槽 a」。本次**没有改善判据**，唯一差别是回落耗时更长（~82 s vs ~25 s），不足以当证据。

## 3. 排除与剩余候选

已排除（本轮之前）：header v3 不交棒（已修）、打包/交棒（本轮再次确认 OK）。
本轮**排除**：BootShim 缺 D-cache clean / I-cache invalidate（补了仍静默）。

剩余候选（按成本）：
1. **BootShim 的 `stp` 拷贝在 MMU/cache 状态下本身不可用**（`UEFI_BASE=0xff300000` 是否被 ABL 映射为普通内存）——需对照一个已知能在本机跑的 tb322fc EDK2 产物（`Droid-VM/edk2-gunyah`），把「打包/交棒」与「Mu 平台支持」彻底分开。
2. **Mu 的 SM8750 平台初始化本身不成立**（DDR/HOB/SCM/PmicDxe 在 Pakala 上缺件）——同一对照实验可判。
3. 串口改 USB（Mu `UsbSerial`）——只有前两条有结论后才值得做。

## 4. 副作用与回退（已做）

- 失败 `fastboot boot` ⇒ `slot-unbootable:b=yes`、`current-slot=a`；恢复 = `fastboot set_active b` → `fastboot reboot`（本轮实测 20 s 回 vk163 Linux）。
- 全程零写盘（仅 misc 槽属性）。

## 5. 顺带发现（与本轮无关但需记账）

**vk163 载荷缺 RTC offset 补丁**：`build/vk151` 的板 DTB 里 `rtc@6100` **没有 `nvmem`/cell offset**（`patches/dt/0002-arm64-dts-qcom-sm8750-elden-pmk8550-rtc-offset.patch` 未进这条线），
⇒ 设备 `hwclock -r` = **1970-01-09**、`/sys/class/rtc/rtc0/since_epoch=695530`。影响：T9 的 `wakealarm` 必须以 RTC epoch（而非 sys epoch）写入；日常线时间不可靠。
