# #484 · 「只能进 fastboot」的真根因 = 引导固件代次与 A/B 槽脱钩（非 AVB / 非镜像 / 非槽位属性）

日期: 2026-11-01
pi 会话 id: 01a196f3-27e8-7466-a690-e95236db1b43
主题: 「只能进 fastboot」真根因 = 引导固件代次与槽位脱钩（LUN1=Jun11 / LUN2=May14）
结论: 见 §0；`--set-active=a` 立刻进 Android、`--set-active=b` 立刻回 Linux，双向可复现
证据指针: `../reports/uefi-slotboot-stuck-fastboot-20261101.md`（事故）、`../reports/artifacts/uefi-edl-read-20261101/`（全部取证件）
★SSOT 待并入: `TASKS/README.md` §5 事故块；#482/#483 的「不可恢复」措辞需降级

---

## #484 结论（四条，均实测复现）

- **根因 = 引导固件代次与活动槽脱钩**，不是 AVB：
  `slot=a` → `UFS Boot LUN: 1` → `xbl_a` + UEFI `6.0.260611`（Jun 11 2026）→ 正常进 Android；
  `slot=b` → `UFS Boot LUN: 2` → `xbl_b` + UEFI `6.0.260514`（May 14 2026）→ 正常进 Linux。
- **卡死那次是 `slot=b` 却跑在 `UFS Boot LUN: 1`**（Jun 11 那代 UEFI 去读 b 槽）⇒ `POST Time` 之后
  只剩 1 行 `VB: RWDeviceState: Succeed using rpmb!` 就走 `Start EBS [7845]` 进 fastboot，
  **全程没有 `Booting from slot`**，总耗时 7.8 s（正常 13.3 s）。
- **修复 = 一条命令**：`fastboot --set-active=a` → 进 Android；`--set-active=b` → 回 Linux。双向可复现。
- **AVB 全程无关**：`vbmeta_a` 与官方包 259 逐字节相同；b 槽 `vbmeta_b` 被 ABL 拒
  （`avb_slot_verify.c:913: ERROR: vbmeta_b: Public key used to sign data rejected.`）
  在**能正常启动**的那次日志里也存在 ⇒ 该 ERROR 是 unlocked/orange 常态，不是死因。

## 判据（以后遇到「只进 fastboot」按此查）

| 观察点 | 正常 | 卡 fastboot |
|---|---|---|
| logfs 里 `UFS Boot LUN` | 与 `current-slot` 配对（a→1 / b→2） | 与槽位不配对 |
| logfs 里有无 `Booting from slot (_x)` | 有 | **无** |
| logfs 总时长 | ~13.3 s（`Shutting Down UEFI Boot Services` 后 `Start EBS[133xx]`） | ~7.8 s（`Start EBS[78xx]`） |
| `KeyPress:` / `BootReason:` / `Fastboot=` / `SilentBoot` 段 | 有 | **无** |

三条同时命中 = 引导固件代次与槽位脱钩 ⇒ 先试 `--set-active` 另一槽，**不要**去刷分区。

## 取证方法（全部只读，零风险）

```bash
cd ~/edl-tool/bkerler-edl-1cda1a6
L=~/下载/tb322fc/xbl_s_devprg_ns.melf
python3 edl.py --loader=$L r logfs  <out>       # 8 MiB 环形，10 段
python3 edl.py --loader=$L r uefi_a  <out>      # 5 MiB
python3 edl.py --loader=$L r uefi_b  <out>
python3 edl.py --loader=$L r abl_a   <out>
python3 edl.py --loader=$L r devinfo <out>
python3 edl.py --loader=$L r misc    <out>
python3 edl.py --loader=$L rs 0 34 --lun=4 <out>   # LUN4 主 GPT
cd ~/y700-elden && python3 scripts/logfs-decode.py <logfs> --segment 0
```

**EDL 权限**：`05c6:9008` 默认 root-only（`crw-rw-r--`），`edl.py` 会报
`Permission denied accessing 05c6:9008`。装一条 udev 规则即可
（`SUBSYSTEM=="usb",ATTRS{idVendor}=="05c6",ATTRS{idProduct}=="9008",MODE="0666",GROUP="plugdev"`
写到 `/etc/udev/rules.d/99-edl.rules`），装后**必须**
`udevadm control --reload-rules && udevadm trigger --subsystem-match=usb --action=change`，
只 reload 不 trigger 不生效（本轮实测踩到）。

## 本机引导固件代次台账（2026-11-01 EDL 实测）

| 分区 / LUN | 内容 sha256(前16) | 构建日期 | 与官方包 259 |
|---|---|---|---|
| `uefi_a`（LUN4） | `fc68d2f91a713722` | **Jun 11 2026** | **逐字节相同** |
| `uefi_b`（LUN4） | `ae3c1c9266c13584` | **May 14 2026** | 差 550 846 B（第二段 LZMA 整体不同） |
| `abl_a`（LUN4） | `e7062378a1fe977d` | Jun 11 2026（payload `e48d3b8f…`） | 逐字节相同 |
| `abl_b`（LUN4） | `811489f0cefb662b` | May 14 2026（payload `529b9e95…`） | 不同 |
| `xbl_a`（LUN1） | `8b09b3ae7d7ff87a` | — | 逐字节相同 |
| `xbl_b`（LUN2） | `fc4fd2701cb1cdd1` | — | 不同 |
| `xbl_config_a`（LUN1） | `88e56e47c12b68bc` | — | 逐字节相同 |
| `devinfo` | `ANDROID-BOOT!` + `u.1.1.1` | — | 正常值（解锁+充电屏），**不是**故障点 |

⇒ **本机是「双代引导固件并存」**：LUN1/`*_a` = 259 原厂（Jun 11），LUN2/`*_b` = 上一版（May 14）。
ABL 按活动槽选择 boot LUN，所以**槽位与 LUN 必须配对**。

## ABL 侧对应字符串（从 `abl.elf` 解 LZMA 段取到）

`Boot lun: %x and BootableSlot: %s do not match`、`Boot lun mismatch switch from 2 to 1`、
`Switching the boot lun from 1 to 2`、`read devinfo failed!!!!!!!`、`Get BootLun =%u`、
`SetBootLun =%u`、`Non Multi-slot: Unbootable entering fastboot mode`。

## GPT 现状（2026-11-01 20:5x，主备双表 header+entry CRC 均 OK）

`boot_a=0x78`（retry7/succ1/active0）、`boot_b=0x7f`（retry7/succ1/active1）是 19:1x 人工修补结果；
与官方包相比另有 22 个条目的 byte6 差异（0x4f/0x0b vs 0x7f/0xfb，即 retry=1 的老值），
**均为历史遗留**，不影响启动（Android 与 Linux 都验证过）。

## 恢复后的设备终态（2026-11-01 21:4x）

`slot_suffix=_b`、`boot_id fbfec355`、UTS `…vk172`、`findmnt /` = `/dev/sda17` ext4、
`card0-DSI-1=connected`、`systemctl --failed` 空、`boot_b` sha `fb55997c…`（未改动）。

---

## #485 `logfs` 八成为**工厂模板**，不是本机历史

本机（U2 `HA2EXB0E`，ECID `0x045A7FD29739`，16+512）的 10 段 `logfs` 里只有 **seg0** 是自己写的；
seg1–9 的 ECID 是 `0x045AC096892B`（另一台 **12+256**，`UFS INQUIRY ID: SAMSUNG KLUEG4RHKF-F0H1`），
且与官方包 `/home/xuqianhui/文档/TB322FC_15.10.259/logfs_ufs_8mb.bin` **9/10 段逐字节相同**。

⇒ 判「历史正常启动」**只能看 seg0，并核 ECID / UFS 容量 / RAM Installed**；拿 seg1–9 当本机基线
会得出反向结论（这正是 11-01 事故报告 §4「ABL 走了第三种路径」的来源，已作废）。

附带两条同源判据坑：`Image size : 4096 Bytes` 在能正常启动的段里也全是 4096（**不是**解析失败判据）；
同一份 `logfs` 内 `UFS Boot LUN` 逐段不同是**正常**的（每段是各自那次启动的值）。

---

## 教训

- **「不可恢复」结论要留余地**：#483 断言「断电/刷回/切槽全无效」，8 小时后被一条 `--set-active` 推翻。
  写死结论前先问「有没有漏了一个状态维度（LUN / 固件代次 / 槽位属性）」。
- **备份不足 ≠ 原因在备份之外**：#483 把「刷回原件无效」解释成「存在不可见的持久状态」，
  实际只是**槽位属性 + LUN** 两个可读量。取证要先穷举可读量，再谈不可见量。
- **EDL 是最便宜的判据来源**：`logfs` 一次读出即可区分「没走槽位路径」与「走了被拒」，
  比反复 `fastboot boot` 试错便宜两个数量级。
- **别急着按第一直觉动手**：本轮原计划「清 `devinfo` 的 `u.1.1.1` 三字节」，核对布局后发现那正是
  `is_unlocked / is_unlock_critical / is_charger_screen_enabled` 三个正常标志位 —— 差点写坏。
