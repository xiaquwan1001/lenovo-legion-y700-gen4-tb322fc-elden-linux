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
