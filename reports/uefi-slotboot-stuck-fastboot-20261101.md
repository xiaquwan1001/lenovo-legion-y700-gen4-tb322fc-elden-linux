# UEFI「槽位正常启动」实验导致设备只能进 fastboot —— 事故记录与取证台账（2026-11-01）

> 性质：**事故复盘 + 实测取证**。设备 U2（SN `HA2EXB0E`）当前**只能进 fastboot**，未恢复。
> 触发：`TASKS/README.md` §5「2026-11-01 16:39」块（P2 最小形态：把 ddrmarks 载荷签进 `boot_b` 再 `reboot`）。
> 本轮设备操作全部有据可查；写入的分区只有 `boot_b`、`boot_a`（恢复用）、`misc`（BCB 诊断）、LUN4 GPT（槽位属性修补）。
> 关联：`PITFALLS #481/#482`、`reports/uefi-ddr-blackbox-20261101.md` §10、`reports/lanes-consolidated-20261101.md` §5。

---

## §0 结论摘要（当前只有「已排除」是硬结论）

1. **设备现状**：`fastboot` 可用（`18d1:d00d`、`getvar` 全应答、`current-slot:b`），**无 Android、无 adb、无 ssh**。
2. **镜像内容与槽位元数据都已排除**（§2/§3）：两个槽的 boot 分区读回与「已知能启动的件」**逐字节相同**，
   槽位属性已修成 `a=successful b=active+successful+retry7` 且**被 ABL 接受**（retry 不再递减）——**仍然进 fastboot**。
3. **最强未解线索**：`fastboot continue` 对 a/b 两槽都回
   **`Failed to load image from partition: Device Error`** ⇒ ABL 卡在「从分区加载镜像」，不是内容不对。
4. **最关键的反常**：本轮**只改过 `boot_b` 的内容**，而**原厂槽 `boot_a`（与原厂备份逐字节相同）也跟着不启动**
   ⇒ 不是「某个槽的镜像坏了」，而是某个**跨槽持久状态**变了（候选见 §5）。
5. **没有归因结论**。缺的是一手证据：**GPT 修复之后那几次启动的 `logfs`**（§4 抓到的是修复前那份）。

---

## §1 时间线（本机实测时刻，CST）

| 时刻 | 动作 | 结果 |
|---|---|---|
| 16:28 | 抓 `logfs`（修复前基线，10 段有效启动日志） | 存 `artifacts/uefi-slotboot-20261101/logfs-before.bin`（`492e1124…`） |
| 16:39 | 把 `artifacts/uefi-ddr-20261101/slotb-uefi-marks.img`（`769c3800…`，96 MiB，ddrmarks shim + Mu FD 的 v0 boot.img）写进 `boot_b` | 读回 sha 逐字节一致 |
| 16:46 | Linux 侧 `reboot`（**不走 `fastboot boot`**） | **+14 s 直接进 fastboot**，全程无 Android gadget |
| 17:0x | `flash boot_b bootslot-b/boot_b.img`（`fb55997c…`，16:2x 还在跑的件）→ `--set-active=b` → reboot | 仍进 fastboot |
| 17:1x | `--set-active=a` → reboot | 仍进 fastboot |
| 17:2x | `fastboot continue`（a / b） | 两槽均 `Failed to load image from partition: Device Error` |
| 17:3x | `misc` BCB 清零（写 2048 B 零 + 保留 0x8000 起的 15 B） → reboot | 无改善 |
| 17:4x | `--set-active a` + `flash boot_a backup/stock-259/boot_a.img` → reboot | 无改善 |
| 17:5x | 用户**物理断电重启** | 仍进 fastboot |
| 18:0x | `fastboot erase misc` → reboot | 无改善 |
| 18:2x | 用户进 **EDL 9008** | `lsusb` = `05c6:9008` |
| 19:0x | EDL 只读：`printgpt` / `r logfs` / `r boot_a` / `r boot_b` | 见 §2 |
| 19:1x | 判定槽位属性异常 → 改 LUN4 GPT 双表并写回 | 读回逐字节一致（§3） |
| 19:2x | EDL `reset` | 设备回到 fastboot（不是 Android，也不是 Linux） |
| 19:3x | 再 reboot + `getvar` | `a/b` 均 `successful:yes`、`retry:7`、`current-slot:b`，**仍进 fastboot**，ssh 不可达 |

> 备注：`--set-active` 每次都会把该槽 retry 重置为 7，随后每次 reboot 掉到 6 ⇒ **ABL 确实在尝试启动并失败**，
> 不是 BCB 强制进 fastboot。

---

## §2 EDL 只读取证（19:0x）

工具与 loader（本机已装好，路径固定）：

```bash
cd ~/edl-tool/bkerler-edl-1cda1a6
L=~/下载/tb322fc/xbl_s_devprg_ns.melf
python3 edl.py --loader=$L printgpt
python3 edl.py --loader=$L r logfs  <out>
python3 edl.py --loader=$L r boot_a <out>     # 24576 扇区 × 4096 = 96 MiB
python3 edl.py --loader=$L r boot_b <out>
python3 edl.py --loader=$L rs 0 34 --lun=4 <out>            # LUN4 主 GPT
python3 edl.py --loader=$L rs $((1048576-34)) 34 --lun=4 <out>  # LUN4 备份 GPT
```

**LUN4（boot 链所在的物理 LUN）关键分区**（`printgpt` 实测）：

| 分区 | Offset | Length |
|---|---|---|
| `boot_a` | `0x1baa6000` | `0x06000000` |
| `boot_b` | `0x4e920000` | `0x06000000` |

**镜像读回与「已知能启动的件」比对（全部逐字节相同）**

| 分区 | 读回 sha256 | 与谁相同 | 判定 |
|---|---|---|---|
| `boot_a` | `d4772c1189b5d438…` | `backup/stock-259/boot_a.img` | 原厂件，未损坏 |
| `boot_b` | `fb55997c524ea262…` | `bootslot-b/boot_b.img`（16:2x 仍在跑 vk183 时的分区值） | 能启动的件，未损坏 |

⇒ **「镜像坏了」这个假设被彻底排除**（这是本轮唯一硬结论之一）。

---

## §3 槽位元数据（GPT 属性字节）与修补

判据来源 = AOSP/Qualcomm `gpt-utils.h`：`boot_<slot>` 条目属性**字节 6**，
`bit2=ACTIVE(0x04)`、`bit6=SUCCESSFUL(0x40)`、`bit7=UNBOOTABLE(0x80)`、`bits5..3=retry(0x38)`。

**修补前（EDL 读回实测）**

```
boot_a  byte6=0x37  retry=6 active=1 succ=0 unbootable=0
boot_b  byte6=0x32  retry=6 active=0 succ=0 unbootable=0
```

**修补（`scripts/slot-attr.py --image` 离线改，双表 + 双 CRC 重算）**

```
boot_b: 0x32 -> 0x7f   (active + successful + retry7)
boot_a: 0x37 -> 0x78   (inactive + successful + retry7)
```

写回后再读回：

```
PRIMARY READBACK IDENTICAL
BACKUP  READBACK IDENTICAL
```

**ABL 侧的接受证据**：修补后 `fastboot getvar all` 实测
`slot-successful:a:yes / retry:a:7`、`slot-successful:b:yes / retry:b:7`，
且**连续多次 reboot 后 retry 不再递减**（符合「bit6 置位则不减」的机制）⇒ ABL 确实读到了我们写的新属性。

⇒ **「槽位属性把设备锁死」这个假设也被排除**——但它**没有**修好启动。

存档（可一条命令回滚）：`lun4-gpt-{primary,backup}-raw.bin`（`ed56f1da…` / `0bbfa568…`）、
改后件 `lun4-gpt-{primary,backup}-new.bin`（`fb18e8ea…` / `bab69f0f…`）。

---

## §4 `logfs` 判读（修复前那份，`efc88d9f…`）

`logfs` = 8 MiB = 10 × 64 KiB 环形；用本轮新写的 `scripts/logfs-decode.py` 解码。

| 段 | slot | 关键行 | 含义 |
|---|---|---|---|
| seg0 | **无** | `PM: PON by SYSOK` → `Start EBS [ 7940]`，**没有 `Booting from slot`、没有 `Loading Image`** | 这一次 ABL **根本没走槽位启动路径**，直接进 fastboot |
| seg1–9 | `_a` | `Loading Image recovery_a/init_boot_a/pvmfw_a/boot_a` + `Booting from slot (_a)` + `Start EBS [13302…]` | 早先的正常尝试（当时 Linux/Android 还能起） |

**注意两点**
- `Image size : 4096 Bytes` 这一行在本机是**正常现象**（早先能正常启动的段里也全是 4096），
  **不能**当作「ABL 解析失败」的判据（`PITFALLS` 里那条是别的机型的判据）。
- seg0 的 `Start EBS [ 7940]` 与「正常槽位启动」的 `[13302]`、`fastboot 模式`的 `[4085]` **都不同**
  ⇒ 这是一个**第三种进入路径**，成因未知。

**缺口**：这份 logfs 是 16:28 抓的基线 + 19:05 抓的一份，
**都没有覆盖「GPT 修复之后」的启动**；而那才是现在这个稳定态的现场。

---

## §5 未解问题与候选（按权重，全部**未证**）

1. **ABL「从分区加载」失败**（最强线索）：`fastboot continue` 的
   `Failed to load image from partition: Device Error` 是 ABL 自己报的加载错误。
   方向：AVB 链（`vbmeta_a/b`、`vbmeta_system_a/b`、`pvmfw_a`）与 ABL 的期望是否还一致；UFS 读是否正常。
2. **某个跨槽持久状态被改**：只动 `boot_b` 却让原厂槽也不启动，这指向
   ① `misc`（当前内容未核对，上轮读取被打断）；② `devinfo`/`lenovoraw`（Lenovo 自定义判定）；
   ③ rpmb 里的 rollback index / 版本计数；④ ABL 的 "prevent flash verify" 类修改检测。
3. **LUN4 GPT 的一致性**：我只改了 `boot_a`/`boot_b` 两个条目的 byte6，
   而 Lenovo ABL 的 `--set-active` 是否会连带改**其它后缀分区**（`recovery_*`/`init_boot_*`/`pvmfw_*`）的同类位，未知；
   目前 `recovery_b/init_boot_b/pvmfw_b` 等仍是 `0xfb`（succ=1 unbootable=1），与 `boot_b=0x7f` **不同形态**。
   这可能是「槽 b 声明可用但子分区声明不可用」的不一致——**未证**，但值得优先核对。
4. **载荷是否真的执行过**：仍无答案（DDR 标记需要 Linux 才能读）。这事故本身不能反证 #481。

---

## §6 下一步（**已暂停，等用户许可**；全部只读优先）

1. EDL 重抓 **当前** `logfs`（GPT 修复之后），用 `scripts/logfs-decode.py` 判：ABL 这次**有没有**尝试槽位启动、失败在哪一步。
2. 只读核对 `vbmeta_a/b`、`vbmeta_system_a/b`、`pvmfw_a` 是否仍为原厂件（AVB 失败会表现为 `Device Error`）。
3. 重读 `misc`（上轮被打断）与 `devinfo`、`lenovoraw`，看是否被写过。
4. 若仍无解：用官方包 GPT + 全量分区表比对（`references/tb322fc-bootloop-gpt-mismatch.md` 的判据），
   或直接 LTBox 全量刷回（最后手段，需用户决定）。

## §7 教训（应写入 PITFALLS，待用户确认）

- **改槽位/写 boot 分区之前，先确认「回滚路径」在设备侧真的成立**：本轮以为「`boot_b` 有备份、`flash` 回去就行」，
  实际出现「刷回原件也不启动」的跨槽故障，备份件本身无法恢复**分区之外的持久状态**。
- **实验前必须抓到「当前状态基线」的 `logfs` 与 GPT 双表**（本轮 GPT 抓了，`logfs` 只抓在写盘前，正好差了关键一段）。
- **`fastboot continue` 的 `Device Error` 是 ABL 加载层的独立信号**，比 `Booting OKAY` / `usb_read failed` 更有指向性，
  应作为判据之一写进 #481 的补充。

---

# ★§8 闭环（2026-11-01 21:xx）：真根因 = 引导固件代次与 A/B 槽脱钩（`PITFALLS #484`）

> **本节推翻 §0 结论 1/3/4、§5 全部候选、§6 全部待办、§7 第一条教训的口径。** 设备已恢复，在机 Linux。

## §8.1 定案

本机是**双代引导固件并存**，且 ABL **按活动槽选择 boot LUN**：

| 活动槽 | boot LUN | XBL | ABL | UEFI | 结果 |
|---|---|---|---|---|---|
| `a` | **1** | `xbl_a` `8b09b3ae…` | `abl_a` `e7062378…`（payload `e48d3b8f…`） | `uefi_a` `fc68d2f9…` = **`6.0.260611`（Jun 11 2026）** | 进 Android（实测成功） |
| `b` | **2** | `xbl_b` `fc4fd270…` | `abl_b` `811489f0…`（payload `529b9e95…`） | `uefi_b` `ae3c1c92…` = **`6.0.260514`（May 14 2026）** | 进 Linux（实测成功） |

`*_a` 全线（`uefi_a`/`abl_a`/`xbl_a`/`xbl_config_a`）与官方包
`/home/xuqianhui/文档/TB322FC_15.10.259/` **逐字节相同**；`*_b` 是上一版（`uefi_b` 差 550 846 B，
其中第二个 LZMA 段整体不同 = 545 780 B）。

**卡死那次**是 `slot=b` 却跑在 `UFS Boot LUN: 1` ⇒ Jun 11 那代 UEFI 去读 b 槽，`logfs` seg0 表现为
`POST Time [2828] OS Loader` → 1 行 `VB: RWDeviceState: Succeed using rpmb!` → `Start EBS [7845]`，
**没有 `Booting from slot`、没有 `KeyPress:/BootReason:/Fastboot=/SilentBoot` 段**，总时长 7.8 s（正常 13.3 s）。

## §8.2 修复与验证

```bash
fastboot --set-active=a && fastboot reboot   # → 进 Android（ro.boot.slot_suffix=_a, verifiedbootstate=orange, veritymode=eio）
fastboot --set-active=b && fastboot reboot   # → 回 Linux（slot_suffix=_b）
```

双向各做一次，均一次成功。恢复后 Linux 实测：`boot_id fbfec355-d05b-485b-86c5-f01cf60c07c6`、
UTS `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172`、`findmnt /` = `/dev/sda17` ext4（`elden_root=LABEL=linux17`）、
`card0-DSI-1=connected`、`systemctl --failed` 空、`qbootctl` 显示 `Current slot: _b`，`boot_b` 分区未改动（`fb55997c…`）。

## §8.3 §5 四条候选的逐条否定

1. **AVB 链** → ❌ 无关。`vbmeta_a` = 官方包逐字节相同；b 槽 `vbmeta_b` 被拒的
   `avb_slot_verify.c:913: ERROR: vbmeta_b: Public key used to sign data rejected.` 在**能正常启动**的那次
   （`logfs-before.bin` seg0）里也同样出现 ⇒ 这是 unlocked/orange 常态。
2. **跨槽持久状态（`misc`/`devinfo`/rpmb）** → ❌ 无关。`misc` **1 MiB 全 0**；
   `devinfo` = `ANDROID-BOOT!` + `0d/0e/0f = 1/1/1`（= `is_unlocked`/`is_unlock_critical`/`is_charger_screen_enabled`，
   与 `getvar` 的 `unlocked:yes`/`charger-screen-enabled:1` 一致，**正常值**，差点被当成故障点清掉）。
3. **GPT 一致性** → ❌ 无关。主/备双表 header CRC + entry CRC 全 OK；`boot_a=0x78`/`boot_b=0x7f`（retry7/succ1）
   已被 ABL 接受；另有 22 个条目的 byte6 是 `0x4f`/`0x0b`（retry=1 老值）属**历史遗留**，不影响启动。
4. **载荷是否被执行** → 归结为零：卡死那发是引导固件层没走到槽位路径，与 `fastboot boot` 载荷无关（#481 不受影响）。

## §8.4 取证方法（可复现，全只读）

```bash
cd ~/edl-tool/bkerler-edl-1cda1a6
L=~/下载/tb322fc/xbl_s_devprg_ns.melf
python3 edl.py --loader=$L r logfs   <out>          # 8 MiB 环形 × 10 段
python3 edl.py --loader=$L r uefi_a|uefi_b <out>    # 各 5 MiB
python3 edl.py --loader=$L r abl_a|abl_b   <out>
python3 edl.py --loader=$L r xbl_a|xbL_b   <out>
python3 edl.py --loader=$L r devinfo|misc  <out>
python3 edl.py --loader=$L r vbmeta_a|vbmeta_b <out>
python3 edl.py --loader=$L rs 0 34 --lun=4 <out>    # 各 LUN 的 GPT 主表
cd ~/y700-elden && python3 scripts/logfs-decode.py <logfs> --segment 0
```

`05c6:9008` 默认 root-only，需 `/etc/udev/rules.d/99-edl.rules`
（`SUBSYSTEM=="usb",ATTRS{idVendor}=="05c6",ATTRS{idProduct}=="9008",MODE="0666",GROUP="plugdev"`）
**加** `udevadm control --reload-rules && udevadm trigger --subsystem-match=usb --action=change`
（只 reload 不 trigger 不生效，本轮实测踩到）。

## §8.5 `logfs` 判读纠错（`PITFALLS #485`）

本机（U2 `HA2EXB0E`，ECID `0x045A7FD29739`，16+512）的 10 段 `logfs` **只有 seg0 是它自己写的**；
seg1–9 的 ECID 是 `0x045AC096892B`（**另一台 12+256**，`UFS INQUIRY ID: SAMSUNG KLUEG4RHKF-F0H1`），
且与官方包 `logfs_ufs_8mb.bin` **9/10 段逐字节相同**（= 工厂模板）。

⇒ **§4 的「seg0 = 第三种进入路径」与用 seg1–9 当「早先正常尝试」的整段推论全部作废**。
判本机历史只能看 seg0，并核对 `Chip ECID` / `UFS INQUIRY ID` / `RAM Installed`。
（`Image size : 4096 Bytes` 在能正常启动的段里也全是 4096，**不是**解析失败判据。）

## §8.6 教训（已并入 `PITFALLS #484/#485`）

- **「不可恢复」的结论要留余地**：§0/§5 断言「断电/刷回/切槽全无效」，8 小时后被一条 `--set-active` 推翻。
  写死结论前先问「有没有漏掉一个状态维度（LUN / 固件代次 / 槽位属性）」。
- **备份不足 ≠ 原因在备份之外**：当时把「刷回原件无效」解释成「存在不可见的持久状态」，实际只是两个**可读**量。
- **别按第一直觉动手**：曾在计划里准备「清 `devinfo` 的 `u.1.1.1` 三字节」，核对布局后发现那正是三个正常标志位。
