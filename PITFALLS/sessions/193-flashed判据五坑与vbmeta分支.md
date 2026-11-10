# PITFALLS 193 — flashed 形态判据的五个坑（2026-11-10 实测）

> 索引见 `PITFALLS/README.md` 表尾 #593–#597；正文来源 = `reports/uefi-p69-flashed-and-vbmeta-20261110.md`。

## #593 计时判据只能作**正控**，不能作反证（硬复位会把它剪断）

2026-11-10 给 PrePi 加了 25 s 停留（`R70`，`[P00]`/`[P08]`/`[P10]` 各一档），想用「回落到 `_b` 的总耗时」判断
「我们的件跑到哪一层」。结果：`fastboot boot` 形态 **54.5 s → 128.7 s（+74.3 s ≈ 3×25 s）**，仪器成立；
flashed 形态 **28.9 s → 28.8 s（+0 s）**。

当时的推断「+0 s ⇒ 我们的件根本没执行到 PrePi」**是错的**：flashed 形态会**硬复位**（用户实测：logo 一闪 → 掉电），
复位把停留整段剪掉，总耗时自然回到基线 —— 与「代码从没跑过」**不可分**。

- 判据：停留类计时**只在「必然跑完」的形态**（这里 = `fastboot boot`）里能证明「代码执行了」；
  在被复位/看门狗打断的形态里，**+0 s 没有任何信息量**。
- 正解：要判「跑到哪」，必须用**复位后仍存在**的通道（屏 / 复位前写下的持久标记），或先把复位源去掉。
- 附带测量法：先测同形态的**无停留基线**（`set_active b` + `fastboot reboot` → SSH ≈18 s），差值才是失败发寿命（≈10 s）。

## #594 logfs **看不到**失败那一发；而且**恢复动作会覆盖它**

- 每发试验抓两次整分区（8 MiB）：`logfs-pre.bin` / `logfs-post.bin` ⇒ **只有 slot0（前 64 KiB）变化**，
  且 slot0 内容是**成功那发 `_b`** 的记录（`Booting from slot (_b)` … `Start EBS [13423]`）。**失败的 `_a` 尝试零记录。**
  ⇒ 「firmware 没写记录」与「记录被下一发覆盖」在同一槽上是**同一个现象**，logfs 对失败发自证能力为零。
- **纪律**：失败发之后**先把 logfs 拷下来，再恢复设备**。本轮两次在 `set_active b` + `reboot` 之后才去读，
  slot0 已被恢复那发覆盖（`EBS@7979`），两次证据都丢了。

## #595 `oem sbread` **只存在于我们自己的 UEFI**，stock fastboot 里没有

`fastboot oem sbread:0:20` 与 `oem sbread 0 20` 在 stock ABL fastboot 上都是 `FAILED (remote: 'unknown command')`
（它是 `20261104R21-hostdiag` 给**我们的** UEFI fastboot 加的命令）。而失败那一发的结局恰好是**停在 bl**，
Linux 又起不来 ⇒ **bl 里读不到 logfs**，只有回 Linux 才能 `dd`。

- ⇒ 「写标记到 logfs 头 → 尝试 → 在 bl 里读回」这类探针**在本机不成立**；别按这个思路设计实验。
- 想拿「失败发是否写过记录」，只能：① 让它**停在 Linux**（不可能）② 用复位后仍存的通道（屏/DDR）③ 先解决复位源。

## #596 别拿**振动**当判据 —— 固件里根本没有 haptic 驱动

用户提出「一短一长两下振动」可当启动次数标记（很有价值，确实能分辨「两次启动」）。但用它当
「我们的件跑到 DXE」的判据会翻车：`grep -ci haptic reports/artifacts/uefi-20261110R70-p69/build.log` = **0**，
`strings -a SM8750_EFI.fd | grep -i haptic` = **空** ⇒ 我们 FV 里没有 `I2CHapticDxe`，振动全部来自 **stock 固件**
（logfs 里那条 `I2CHapticDxe: aw ram play` 属于原厂 UEFI 的日志）。

- 可用之处：**只**能当「发生了几次启动尝试」的时钟（短 = 失败发、长 = `_b` 起 Linux）。
- 想用外设当判据，先 grep 自己的 FV 里有没有那个组件。

## #597 解读 logfs 前先数**记录条数与固件版本**：别把历史记录当本轮的

本轮早先据 `logfs-p67-flashed.bin` 得出「2 条记录、`[3806]` 与 `[12984]` 属同一次启动、中间 9 s 空窗」，
并写进了 `reports/uefi-p67-flash-trial-20261110.md` §3。复数是 **10 条**（每 64 KiB 一条），
且 blk1–blk9 的 `UEFI Ver = 6.0.250606…` 而当前固件是 `6.0.260611…` ⇒ **那 9 条是旧固件时期的历史记录**。
⇒ 「9 s 空窗 + 回退 `_b`」不是一次启动内的回退，而是**一发失败尝试的寿命**（与 §593 测出的 ≈10 s 吻合）。

- 判据：① 先 `grep -c 'Booting from slot'` 数条数；② 每条抽 `UEFI Ver` 与 `KeyPress/BootReason`；
  ③ 只有版本与当前固件一致、且 slot/时间戳连续的，才算本轮的。
- 相关：`#587`（dd 先验字节数）、`#586`（固定 LBA 信标不能自证）。

## #598 同一镜像 `_a` 起不来 / `_b` 起得来时，**先比 `vbmeta` Flags，再谈固件**

`tools/avbtool.py info_image` 的实测（2026-11-10）：

| | key sha1 | Auxiliary Block | **Flags** |
|---|---|---|---|
| `vbmeta_a` | `8fcb864f…`（原厂） | 8000 | **0**（校验开启，含原厂 `boot`/`recovery`/`vbmeta_system` 链 + 原厂 props） |
| `vbmeta_b` | `fc1e3b33…`（我方 `bootslot-b/avb.key`） | 2368 | **3** = `VERIFICATION_DISABLED` + `HASHTREE_DISABLED` |

`_b` 每发都会打 `avb_slot_verify.c:913: ERROR: vbmeta_b: Public key used to sign data rejected.`，然后**照常**
`Load Image boot_b` → `BootLinux` → `Start EBS`（校验被关闭/公钥被拒 ⇒ 放行）；
`_a` 的 `vbmeta_a` 仍是原厂签名且记录**原始 `boot_a` 的哈希**，我们把 `boot_a` 换成任何别的镜像都过不了 ⇒
走「哈希不匹配 = 校验失败」分支（屏上那 5 s 警告）⇒ **不交棒**。

- 纪律：在**过这道墙之前**问「我们的固件跑到哪一层」是无效问题；先让 `_a` 用与 `_b` 同样的「校验关闭」口径。
- 见 `TASKS §5`「2026-11-10（晚，p69/R70 + 金标准对照）」块、`reports/uefi-p69-flashed-and-vbmeta-20261110.md` §4。

## #599 判别「谁的责任」最省的一发 = **把正在跑的槽逐字节刷进另一槽**

从设备读回 `boot_b`（`4e38bc2c…`，100 663 296 B）原样刷进 `boot_a`，两槽**逐字节相同**后仍起不来 ——
但死法从「logo 一闪 → **掉电**（`unbootable=1`）」变成「正常解锁警告 → **无缝回 bl 不掉电**（≈16 s，`unbootable=0`）」。
⇒ ① 两种失败形态 = **两条不同的 ABL 分支**，不能混谈；② **flashed 失败与我们的 payload 无关**（`#588` 同族）。

- 附带：`/sys/fs/pstore` **空** ⇒ 该发没有内核崩溃转储（ramoops 未写），偏向「内核没起来」而非「起来后崩」。
- 成本：一发 `flash`（1.6 s）+ 一次重启，**可原样回滚**（`backup/boot_a-pre-uefi-20261108.img`）。

## 附：同一批工具坑（不单独编号，已在实现里修）

- `fastboot devices` 每行是 `SN\tfastboot` **两列**：`while read -r ser` 会拿到整行 ⇒ `-s "SN<TAB>fastboot"` ⇒
  `getvar product` 空、`product` 匹配 0 个、脚本静默等 fastboot 等到超时。
- 重启后 `/tmp`（tmpfs）里的 `slot-attr.py` 消失 ⇒ 每次快照前要重推。
- ssh 不包 `timeout` + `ServerAlive*` 会卡到 `tcp_retries2`（`#585` 复发；本轮又踩一次，白等 ~9 min）。
