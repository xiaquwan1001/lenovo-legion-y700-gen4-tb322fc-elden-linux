# 安卓 a 槽「落 recovery」机制重判（2026-11-21，只读 lane）

> 目的：用已有 dump + 设备只读取证，正面回答「**为什么 ABL 选的是 `recovery_a` 而不是 `boot_a`**」，
> 并给全部候选假设的「预测 vs 已观测 + 最小判别实验」。
> lane 硬约束：**全程零设备写**（只 `dd` 读 / `cat /proc` / `qbootctl` / `slot-attr.py show`）。
> 设备：U2 `HA2EXB0E`（当时在 b 槽 Linux / vk189），设备中途离线过一次（09:38–09:53），后自动回线。
> 取证归档：小件入 `reports/artifacts/android-a-slot-forensics-20261121/`（入库，含 `SHA256SUMS.txt`），
> 大件（logfs 8 MiB / metadata 64 MiB / 分区尾 4 MiB）在 `logs/a-slot-forensics-20261121/`（`logs/` 被 .gitignore）。
> 姊妹件：材料盘点 `reports/android-a-slot-materials-20261121.md`、执行单 `reports/android-a-slot-s2s3-execplan-20261121.md`。
> **★SSOT 待并入**：`TASKS/README.md` §4「P1 安卓 a 槽」段需要加一条指针（本 lane 无权改正文）。

---

## 0. 一句话结论（数字先）

1. **「ABL 选了 `recovery_a`」这个前提不成立。** `Loading Image recovery_a … Image size: 4096 Bytes` 是 ABL 的
   **槽位枚举/头部探测**行，b 槽启动时同样打印 `Loading Image recovery_b`；紧随其后的原文是
   `Booting from slot (_a)` + **`Booting Into Mission Mode`**（= 正常启动）+ `Loaded Partition: boot`。
   ⇒ **ABL 一直是正常启 `boot_a`，从未有"recovery 模式"的日志证据**（全部 logfs 里 `Booting Into` 只出现过 Mission Mode，0 次 Recovery）。
2. **被当成证据的那 9 条 a 槽 logfs 记录是旧固件遗留，不是我们的实验。** logfs 的活文件 = FAT12 里 `UEFILOG1.TXT`
   **只有 65536 B（单条记录 ~21 KB）**，每次启动被整段覆盖；那 9 条的 `UEFI Ver = 6.0.250606`，而本机自 11-17 线刷后是 `6.0.260611`。
   11-20 那三份 dump 的**活记录**其实都是同一条：`Boot lun: 1 and BootableSlot: _b do not match → Launching fastboot`。
   （这条坑 PITFALLS **#597** 已登记过一次，本轮是第二次踩。）
3. **11-21 「落 recovery」只有 1 个样本**（`logs/android-v3-S1-20261121-091754/`），不是 2 个；
   09:12/09:15 那两发实际是「active 仍 = b → 重启回 Linux」（`FELL_BACK_LINUX`，且其中一发 `commands.log` 为空）。
4. **a 槽启动链 6 件与原厂 ROM 逐字节相同**（`boot_a` `b428a31d…`、`init_boot_a` `e8206b81…`、`vendor_boot_a` `326d5c32…`、
   `recovery_a` `3807dd63…`、`dtbo_a` `45f51790…`、`vbmeta_system_a` `910e013b…`）；
   **唯一被改过的只有 `vbmeta_a`**（在机 `419e01ac…`，自签顶层 key `1e54e86e…` + Flags 1；原厂 `55929c15…` key `8fcb864f…` Flags 0）。
5. **11-21 全部 a 槽样本的在机 super = v1**（设备侧实测 head512k `67ff7604…`，与 `out/android-min-20261118/pkg/super_min.img`
   首 512 KiB **逐字节相同**）⇒ **H2「v3 slim super 内容问题」对 11-21 的样本已被排除**（v3 当时根本不在机）。
6. **S2（原厂 metadata）已于 2026-11-20 20:26 实跑过**，而且**写前读回件 = 原厂件**（`a735fbc7…`，与写后设备端 sha 相同）
   ⇒ 写入是 no-op，a 槽照样失败（`getvar-after-S2`：`slot-unbootable:a:yes` / `slot-retry-count:a:0`，随后回落 b）
   ⇒ **H4「metadata」也已排除**。⇒ **原计划的 S2、S3 都不是当前失败的分辨实验。**
7. 新的硬证据把失败点夹到了 **Android init 的 `/metadata` 挂载之后、`/data` 挂载之前**：
   - `/metadata` **确实被某个 Android 挂载过 RW**（f2fs checkpoint/超级块被改写；对照：Linux 侧 `/proc/mounts` 只挂 `sda17 /`）；
   - `/data`（`userdata`）的 ext4 超级块 **`s_mnt_count = 0`** ⇒ 自 11-19 21:16 建好之后**从未被挂载过**；
   - `pstoredump` 命中文 0（无内核崩溃）。
8. 而 `/data` 是**主机侧 mkfs 的空 ext4**：`s_mkfs_time = 2026-11-19T13:16:23Z`（= 11-19 21:16 CST，正是 11-19 会话里
   `fastboot -w` 的同一分钟）、**无 ext4 `encrypt` 特性**、`s_r_blocks_count = 673050`（= 1%，`-m 1`）、label 空；
   `/metadata` 是**空 f2fs**（`valid_block_count=6`、`valid_node_count=3`，没有 `/vold/metadata_encryption/keys`）。
   ⇒ Android 15 的 FBE/metadata-encryption 拿不到一致的 key/文件系统 ⇒ 落到 recovery（`--prompt_and_wipe_data` 那一类 UI）
   **是本轮最强的解释（H6，高置信但未上机证实）**。
9. ⇒ **最便宜的下一步不是 S3（14.5 GiB，6–12 min），而是「启一发 + 在 recovery 里当场取证」**（零写盘，`adb exec-out` 抓
   `/proc/cmdline` + logfs 活记录 + `/tmp/recovery.log`，脚本已自动化，见 §6/§7）。取证结果二分叉：
   `force_normal_boot=0` ⇒ ABL/BCB 面；否则 ⇒ userspace 面，再按 `/data`（H6）处置。
   处置候选与代价见执行单 `reports/android-a-slot-s2s3-execplan-20261121.md`。

---

## 1. logfs 的读法（这是本轮最大方法学修正）

### 1.1 logfs 里只有一个 64 KiB 的活文件

```sh
$ python3 - <<'EOF'   # 手工解 FAT12 根目录（日志归档件 logs/a-slot-forensics-20261121/logfs-now.bin）
bps 4096 spc 1 rsv 1 nf 2 rootent 512 tot 1280
LOGFS. attr=0x08 cluster=0 size=0          # 卷标
UEFILOG1.TXT attr=0x20 cluster=2 size=65536
data_off 28672 clustersize 4096
EOF
```

即：**ABL 的日志文件只有 64 KiB，从 cluster 2（偏移 28672）开始整段重写**。
活记录长度 ≈ 21 KB（`Shutting Down UEFI Boot Services` 在文件内偏移 21034），**只能放一条**。

⇒ 8 MiB 的 logfs 分区里，**偏移 28672 之后的前 64 KiB 才是"这次/上次启动"的日志，其余是历史遗留簇**。

### 1.2 三份 11-20 dump 的活记录是同一条，而且内容是 b 槽 fastboot

```sh
$ for f in logs/forensics-20261120-2210/logfs{,2,3}.bin; do python3 … # 取 [28672, 94208)
logfs.bin : UEFI Ver 6.0.260611 / Loader Build Info: Jun 11 2026 / Fastboot=0, Recovery:0 / Launching fastboot
logfs2.bin: 同上
logfs3.bin: 同上 + `Boot lun: 1 and BootableSlot: _b do not match` / `Err: LoadImageAndAuth failed: Device Error`
```

⇒ **11-20 22:10/22:29/22:41 那三次 dump 记录的是"b 槽因 UFS 启动 LUN 与 BootableSlot 不配对而掉 fastboot"**
（PITFALLS **#484** 的机制），不是 a 槽实验。

### 1.3 那 9 条 a 槽记录是旧固件遗留

```sh
$ strings -n 4 logs/forensics-20261120-2210/logfs3.bin | grep -c "Booting Into Mission Mode"   # 9
$ strings -n 4 …/logfs3.bin | grep -ci "Booting Into Recovery"                                   # 0
$ strings -n 4 …/logfs3.bin | grep -m1 "UEFI Ver"                                                # 6.0.260611（活记录）
# 9 条 a 槽记录的 UEFI Ver = 6.0.250606（旧固件），与当前 6.0.260611 不同
```

它们的内容（每条都一样）：

```
[2568]Fastboot=0, Recovery:0
[2568]Loading Image recovery_a Done : 0 ms, Image size : 4096 Bytes     ← 槽位枚举/头部探测
[2569]Loading Image init_boot_a Done : 1 ms, Image size : 4096 Bytes
[2569]Loading Image pvmfw_a Done : 0 ms, Image size : 4096 Bytes
[2570]Booting from slot (_a)
[2570]Booting Into Mission Mode                                          ← ★ 正常启动，不是 recovery
[2571]Loading Image boot_a Done : 1 ms, Image size : 4096 Bytes
[2571]Load Image vbmeta_a total time: 0 ms
…
[2765]Loaded Partition: boot
[2765]Loaded Partition: pvmfw
[2771]VB2: boot state: orange(1)
[13024]BootLinux: factory_build = 1
Shutting Down UEFI Boot Services: 13302 ms
```

对照 b 槽那一条（`logfs-now.bin` 活记录）：

```
UEFI Ver           : 6.0.260611.BOOT.MXF.2.5.1-00240.1-PAKALA-1
Loader Build Info: Jun 11 2026 06:16:07
Fastboot=0, Recovery:0
Loading Image recovery_b Done : 0 ms, Image size : 4096 Bytes           ← b 槽同样有"recovery_b"这一行
Booting from slot (_b)
Booting Into Mission Mode
avb_slot_verify.c:913: ERROR: vbmeta_b: Public key used to sign data rejected.   ← 非致命（orange），随后照常起
Loaded Partition: boot / dtbo / pvmfw
Cmdline: console=ttyGS0,115200 console=tty0 … elden_root=LABEL=linux androidboot.slot_suffix=_b …
Shutting Down UEFI Boot Services: 13625 ms
```

⇒ `Loading Image recovery_?` 与"要不要进 recovery"**无关**，它是 ABL 对槽内一组分区做 4096 B 头部读取时的日志。

---

## 2. a 槽在机件：只有 `vbmeta_a` 与原厂不同

设备侧只读 sha（`dd iflag=direct` 直读分区，主机侧对照件用 `scripts/odirect-sha.py`）：

| 分区 | 在机 sha256 | 原厂件 | 一致？ |
|---|---|---|---|
| `boot_a` | `b428a31dadc5db3f91620c1f4114f5ee7702e34e0789ed9bf84a878a49898f20` | `backup/official-rom-15.10.259/boot.img` 同 | ✅ |
| `init_boot_a` | `e8206b81d5523d52c96f8f2eb11dfade3e80edcc4b76b796a7f74d6f45c25033` | `init_boot.img` 同 | ✅ |
| `vendor_boot_a` | `326d5c328103ac6d1284773a11f09c8524582e9c264512734d5ba9079e4b9534` | `vendor_boot.img` 同 | ✅ |
| `recovery_a` | `3807dd63ac74f1a090f554ef2958d12f0c4e093a8c5f05809d93b81ef59553eb` | `recovery.img` 同 | ✅ |
| `dtbo_a` | `45f517902d2271abe9c8bf6cab2cfa43a3126d89684fc7f956b823f03e0929a7` | `dtbo.img` 同 | ✅ |
| `vbmeta_system_a` | `910e013bbab9ac8aed5cc3d824b411488518ccec697c21b90ae715994faef7dc` | `vbmeta_system.img` 同 | ✅ |
| **`vbmeta_a`** | **`419e01ac8af7345e69a0f7f43d0e08a71079e912c9add92a5748cf1876716f31`** | `vbmeta.img` = `55929c15…` | ❌（自签） |

`vbmeta_a` 差在哪（`python3 tools/avbtool.py info_image`）：

```
在机 vbmeta_a:  Public key (sha1): 1e54e86ef19fad73791ecbab052656356be99bd8   Flags: 1
                Chain Partition: boot (loc 3) / recovery (loc 1) / vbmeta_system (loc 2) → key 8fcb864f…（OEM）
原厂 vbmeta.img: Public key (sha1): 8fcb864f11f53ed11284615fb67685522085d3a2   Flags: 0
                Chain Partition: boot / recovery / vbmeta_system → key 8fcb864f…（同上）
```

⇒ 自签只换了**顶层 key + Flags=1(HASHTREE_DISABLED)**，链描述符仍指向 OEM key，故 `boot_a`（原厂签名）链本身能验通；
bootloader 已解锁（`orange`）⇒ 顶层 key 不匹配不阻断启动（logfs 里 `VB2: Authenticate complete! boot state is: orange`）。

---

## 3. 已排除的两条：v3 super 内容、metadata

### 3.1 在机 super = v1（不是 v3）

```sh
$ ssh elden-root 'dd if=/dev/disk/by-partlabel/super bs=4096 count=128 iflag=direct' > super-head512k.bin
$ sha256sum super-head512k.bin
67ff7604e59f5b70343846572f492d1d0b405a914fda9e4d86a1982affc47479
$ dd if=out/android-min-20261118/pkg/super_min.img bs=4096 count=128 iflag=direct | sha256sum
67ff7604e59f5b70343846572f492d1d0b405a914fda9e4d86a1982affc47479      ← v1 件首 512 KiB，逐字节相同
$ python3 scripts/android-super.py list super-head512k.bin | head -3
blockdev size=23622320128 (22528.00 MiB)   system_a 5296.00 MiB   ← v1 布局（v3 是 3920 MiB）
```

（v3 件首 512 KiB = `c6278f8e…`；原厂拼装首 512 KiB = `12c35980…`。三个值可作**快速判别指纹**，脚本已接入。）

**⇒ 11-19/20/21 的全部 a 槽样本都不可能由 v3 内容解释**；S3（回写原厂 super）在这条线上判的是
「我们精简的 v1 vs 原厂」，**与 v3 无关**（v3 至今零上机样本）。

### 3.2 S2 已经跑过，且是 no-op

```sh
$ ls logs/android-v3-S2-20261120-202620/
commands.log  live-gpt0-primary.bin  metadata-pre.bin  qdl.log  readback-head16m.bin  readback-tail16m.bin  verdict.txt …
$ sha256sum logs/android-v3-S2-20261120-202620/metadata-pre.bin
a735fbc74abf0d9695a1fc598128acc78184abc710224719825bbe16fca4722e    ← 写前读回 = 原厂件 sha
$ cat logs/android-v3-S2-20261120-202620/qdl.log | tail -3
flashed 1 partition, read 2 (28.0 MiB written in 3.2 s, 8.7 MiB/s)
a735fbc74abf0d9695a1fc598128acc78184abc710224719825bbe16fca4722e    ← 设备端 sha，与写前相同
```

而 `runs/laneDeviceV3/getvar-before.txt` / `getvar-after-S2.txt` 给出了那发 boot 的结局：

```
getvar-before : current-slot:a   slot-unbootable:a:no   slot-retry-count:a:0
getvar-after-S2:current-slot:a   slot-unbootable:a:yes  slot-retry-count:a:0   ← ABL 用掉 a 槽最后一次重试并标 unbootable
```

⇒ **原厂 metadata 在机时 a 槽依然失败**，H4 排除。（顺带：`getvar-after-S2` 里 `slot-successful:b:no`、`slot-retry-count:b:1`
说明 Linux 侧从不 `markBootSuccessful`，b 槽 retry 会一路被抽干 —— 见 PITFALLS #672/#695。）

---

## 4. 失败点被夹到 init 的 `/metadata` → `/data` 之间（新证据）

### 4.1 `/metadata` 被某个 Android 挂载过 RW，`/data` 从未被挂载

```sh
# ① Linux 只挂 linux17，没碰 metadata/super/userdata
$ ssh elden-root 'grep -E "sda1[0-9]|super|metadata|userdata" /proc/mounts; cat /etc/fstab | grep -v "^#"'
/dev/sda17 / ext4 rw,noatime 0 0
LABEL=linux  /  ext4   rw,noatime  0 1

# ② /metadata 的 f2fs 被改写（checkpoint 在 cp_blkaddr=512 → 偏移 2 MiB，实测差异块正好落在 2 MiB 起）
$ python3 …  # 与 11-20 20:26 的 metadata-pre.bin 对比：29 372 416 B 内有 36 个 4 KiB 块不同
differing 4KiB blocks: 36  first [0, 4096, 2097152, 2101248, 2105344, …]

# ③ /data 的 ext4 超级块：从未挂载
$ ssh elden-root 'dd if=/dev/disk/by-partlabel/userdata bs=4096 count=1 iflag=direct' > userdata-head4k.bin
ext magic 0xef53
s_mnt_count    0
s_mkfs_time    1795094183  2026-11-19T13:16:23Z   (= 11-19 21:16:23 CST)
s_wtime/s_lastcheck 同值；s_state 0x1（clean）
features incompat 0x42 (= filetype + extents；**无 encrypt/64bit**)
features ro_compat 0x7b
s_r_blocks_count 673050  = 1% of 67 305 043 blocks（mkfs 默认 5% ⇒ 显式 -m 1）
s_inodes_count 16826368；s_free_blocks 65986867（98% 空）
volume_name  ''（空）
```

⇒ **自 11-19 21:16 之后，任何一次 a 槽启动都没有把 `/data` 挂上**（`s_mnt_count` 不会回零）。
而 `/metadata` 被挂过。即失败发生在「init 已经起来并挂了 /metadata」之后、「vold/fs_mgr 挂 /data」之前/之时。

### 4.2 `/metadata` 是空 f2fs（没有 vold 的 key 目录）

```sh
$ dump.f2fs -d 1 metadata-64M-pristine.bin | head -60
version                       6.6.118-android15-8-g350f378eb496-ab14943902-4k   ← 由 Android 15 的 f2fs 格式化的
Info: total FS sectors = 131072 (64 MB)
checkpoint_ver                0x55d64b91
user_block_count              0x1400 (5120)   valid_block_count 0x6 (6)   valid_node_count 0x3
```

`valid_node_count = 3` ⇒ 只有 root/node/meta 三个 inode，**没有任何普通文件/目录**
⇒ 不存在 `/vold/metadata_encryption/keys/**`（Android 用来解/包 `/data` 的 key 就在这里）。

> ⚠ 方法学坑（本轮踩到，已归档）：**`dump.f2fs` 会写它 dump 的镜像**——
> `[update_superblock: 765] Info: Done to update superblock`，把超级块里的 mount/fsck 字段改掉。
> 取证件必须**先复制**再 dump；`logs/a-slot-forensics-20261121/metadata-64M.dumpf2fs-mutated.bin` 就是被改过的，
> 参考值请用 `metadata-64M-pristine.bin`（`3f4934ee…`，重读复现一致）。

### 4.3 `/data` 的来历（时间线自洽）

- `TASKS/sessions/2026-11-19-安卓共存契约与v3精简上机.md` §时间线：**21:1x `fastboot -w` ⇒ `Erasing 'userdata'/'metadata'` OK**，
  并注明「/data raw 未格式化，靠首启自建」。
- 我们测到的 ext4 `s_mkfs_time` = **11-19 21:16:23 CST**（同一分钟），且该 fs 的 `-m 1`、无 `encrypt` 特性、label 空
  ⇒ **它不是 Android 的 `make_f2fs` / `mke2fs -O encrypt` 产物，而是主机侧 e2fsprogs 风格的空 ext4**。
  最可能的写者就是 **`fastboot -w` 自己**：AOSP fastboot 的 `erase` 会先 `getvar partition-type:userdata`，
  拿到 `ext4`（实测 `getvar` 原文就是 `partition-type:userdata:ext4`）时**改为调用主机的 `mke2fs` 去"格式化"**。
  （机器无关判据：主机的 `mke2fs` 默认不带 Android 的 `encrypt` 特性，Android 的 `make_f2fs/mke2fs` 必带。）
  **未验证**：到底是 fastboot 还是别的步骤造的（本仓也有一个同形状的 `scripts/dev-userdata-relabel.sh` 用 `-m 1`）。
- `/metadata` 则是 **Android 15 格式化的空 f2fs**（`version 6.6.118-android15-…`；11-20 20:26 又被原厂 `metadata_stock.img` 覆盖一次）。

⇒ 「空 /data（无 encrypt 特性）+ 空 /metadata（无 key）」这一组合，Android 15 的
`fs_mgr`/`vold` 无法把 `/data` 挂起来（要么等格式化、要么判定数据不可用），落到 recovery（`--prompt_and_wipe_data`
那一类「Can't load Android system」界面）是**预期形状**。这也解释了：
① `pstoredump` 无 panic；② `/data` 从未被挂载；③ 11-19 之前（旧 /data）v1 镜像能 `boot_completed=1`，之后就不行。

⚠ **重要推论**：若 `/data` 就是 `fastboot -w` 的产物，那么**再跑一次 `fastboot -w` 只会复现现态**，不是判别实验。
真差异在「谁执行格式化」：Android 自己的 `make_f2fs`/`mke2fs -O encrypt`（带 FBE + 在 `/metadata` 建 key）vs 主机的 `mke2fs`。
所以处置优先选 **Android 侧格式化**（stock recovery 的 *Wipe data/factory reset*，或 `fastboot format:f2fs:userdata` —— 后者取决于主机有没有 `mkfs.f2fs`，**未验证**）。

**置信度**：机制链条的每一环都有实测读数；「所以落 recovery」这一步仍属**推断**（没有 Android 侧 log）。
判别实验见 §5 的 H6 行与 §6 取证纪律（先零写取证，再按分叉处置）。

---

## 5. 全部候选假设：预测 vs 已观测 + 最小判别实验

| # | 假设 | 预测的观测 | 已观测 | 判定 | 最小判别实验 |
|---|---|---|---|---|---|
| H1 | **ABL 槽位/recovery 机制**：`--set-active` 后 ABL 自己进 recovery，或 ABL 直接选 `recovery_a` | logfs 出现 `Booting Into Recovery`（或等价的 recovery 分支）+ `Recovery:1`；`Loaded Partition: recovery` | 所有 logfs 记录里 `Booting Into` = **Mission Mode 9/9**，`Recovery:0`，`Loaded Partition: boot`；`Loading Image recovery_a` 在 b 槽同样出现（`recovery_b`） | **前提被推翻**（不是 ABL 选 recovery_a）。但"11-21 那发是否 `force_normal_boot=0`"仍未证 | 设备在 recovery 时抓 `adb exec-out cat /proc/cmdline`，看是否含 `androidboot.force_normal_boot=0`（脚本已自动化） |
| H2 | **v3 slim super 内容问题** | 在机 super = v3（`system_a 3920 MiB` / `blockdev size 7454326784`） | 在机 super = **v1**（head512k `67ff7604…` 与 v1 件逐字节相同） | **排除**（对 11-19/20/21 全部 a 槽样本） | 无需实验；若仍要判 v3，必须先写 v3 再谈（S4 面） |
| H3 | **misc/BCB 残留指令** | `misc[0:32B]` 非 0（`boot-recovery`/`bootonce-*`） | 今天 misc 1 MiB：`0..32 KiB` **全 0**；只有 `0x8000` 5 字节（`02 b0 0a 74 56`），该值在 stock 时期同样存在 | **排除**（11-21 09:19 也刚 `fastboot flash misc` 4 KiB 零过） | — |
| H4 | **metadata 被 erase/不一致** | 原厂 metadata 在机时失败消失 | S2 已实跑（2026-11-20 20:26）：写前=写后=原厂 `a735fbc7…`，a 槽仍失败并标 unbootable | **排除** | — |
| H5 | **`vbmeta_a` 自签 / rollback 索引** | AVB 校验失败导致 ABL 拒启或 Android 进 eio/recovery | `VB2: Authenticate complete! boot state is: orange`；ABL 未拒启（每次都走到 EBS）；顶层 key 变换 + Flags=1 | **未证实（低优先）**：Flags=1 只等于关 hashtree，orange 下不阻断 | 写回原厂 `vbmeta_a`（`backup/official-rom-15.10.259/vbmeta.img`，64 KiB，回退件在机 dump `logs/forensics-20261120-2210/vbmeta_a.img`）后启 a 槽 |
| H6 | **`/data`+`/metadata` 状态（本轮主推）** | `/data` 从未被挂载（`s_mnt_count=0`）；`/metadata` 被挂过；无内核 panic；落 recovery 形如 `--prompt_and_wipe_data` | 全部命中（§4） | **高置信，未上机证实** | ① 先零写取证（`/proc/cmdline`+`recovery.log`）；② 若确认是 `/data`：用 **Android 自己的格式化**（stock recovery 的 *Wipe data/factory reset*，或 `fastboot -w`）后再启。⚠ 现在 `/data` 的 ext4 本身就是 `fastboot -w` 那一下的产物（mkfs 时间 = 21:16:23、主机 e2fsprogs 风格）⇒ **重复 `-w` 可能只是复现现态**，真差异在“谁格式化”（Android 的 `make_f2fs -O encrypt` vs 主机 mke2fs） |
| H7 | **`recovery_a`/`init_boot_a`/`vendor_boot_a`/`dtbo_a` 内容坏** | 这些件与 ROM 不同 / AVB 链断 | 全部与原厂逐字节相同；链 key 指向 OEM 且 `boot_a` 原厂签名 | **排除** | — |
| H8 | **`userdata` 分区几何/GPT 错** | `userdata` 起止与登记不符 | GPT 现读：`userdata 5972392..73277434`（256.748 GiB）与台账一致；ext4 `s_blocks_count×4096` = 同一尺寸 | **排除** | — |
| H9 | **样本不足（"两发复现"不成立）** | 应有 ≥2 份独立 recovery 归档 | 只有 `091754` 一份；`090924` 空、`091526` = active 仍 b 重启回 Linux | **风险登记**（单样本 + 每次只差一轮） | 重复样本时按 §6 纪律逐发归档 |

---

## 6. 判别实验的纪律（给下一轮，直接照做）

1. **必须在 recovery 现场取证再重启**：logfs 只留最近一次启动（64 KiB），重启即丢。
   `adb exec-out`（不是 `adb shell`，后者在本机 recovery 里会 `SIGABRT`：`shell_service.cpp:380 Could not set SELinux context for subprocess`）：
   ```sh
   adb -s HA2EXB0E exec-out 'cat /proc/cmdline'                 > recovery-cmdline.txt
   adb -s HA2EXB0E exec-out 'dd if=/dev/block/by-name/logfs bs=4096 count=16' > recovery-logfs.bin
   adb -s HA2EXB0E exec-out 'cat /tmp/recovery.log'             > recovery-last.log
   adb -s HA2EXB0E exec-out 'getprop | grep "^\[ro.boot\."'     > recovery-props.txt
   ```
   判读：`cmdline` 含 `force_normal_boot=0` ⇒ **ABL 选的 recovery**（转 H1/BCB 面）；
   不含（或 =1）⇒ **userspace 侧选择**（转 H6 面，看 `recovery-last.log` 的 `--prompt_and_wipe_data` 字样）。
   ⇒ **playbook 已写进 `scripts/android-v3-bringup-walkthrough.sh` 的 `observe_android()`**（见 §7）。
2. **每发样本必须同时留**：`misc`（1 MiB 全量，含 `0x8000` 区）、`userdata` 首 4 KiB、`metadata` 首 512 KiB、
   `super` 首 512 KiB、`logfs` 活记录、`pstoredump` grep、`qbootctl` 全文 + `slot-attr.py show`。
3. **不要再用 8 MiB logfs 里"看起来像 a 槽"的记录当证据**：先解 `UEFILOG1.TXT` 的 64 KiB 活区，
   并核对 `UEFI Ver` 与当前固件是否同代（PITFALLS #597）。

---

## 7. `scripts/android-v3-bringup-walkthrough.sh` 复核 + 改动清单（§E）

复核结论：**S1–S5 的写路径（qdl/fastboot 命令、LBA、扇区数、sha 门、BCB 纪律）本身是对的**，
但**观测/取证/判据侧有 6 处会把"未验证"变成"通过"或把结论带偏**，本轮全部改成 fail-closed。

| # | 缺陷（改前） | 影响（真实踩到过） | 改法（本轮） |
|---|---|---|---|
| A1 | `run 60 ssh … 'dd if=…super…' > …/super-head512k.bin`：`run()` 会把 `[run] timeout …` 打到 **stdout**，被一并写进件 | 2026-11-21 08:57 / 08:59 两份 `super-head512k.bin` 里混进 156 B 命令文本 ⇒ `android-super.py list` 报 `bad geometry magic 0x00000000`，**判据假阴性**（09:16 那份甚至只有 156 B） | 抓字节不走 `run()`；改直连 ssh + `iflag=direct`（与 `bcb_read` 同口径），并 `logc` 记一条 |
| A2 | 同上，`pstore_triage` 也用 `run … > pstore-grep.txt` | `pstore-grep.txt` 首行是 `[run] timeout …`，`cat` 出来分不清「没查」和「查了干净」 | 改为直连 ssh 写 `pstore-raw.txt` + 解析成 `hit=N`；空值显式写 `WARN 三分类未做` |
| A3 | `super` 判据只靠 `android-super.py list` 解析输出 | 解析失败时不判失败（只要文件非空就往下走），且无法区分 v1/v3/原厂 | 新增 **head512k sha256 白名单**（v1 `67ff7604…` / v3 `c6278f8e…` / 原厂 `12c35980…`）；不在白名单 ⇒ `return 1`（不 reset） |
| A4 | `S2/S3/S4` 调 `observe_android` 后**丢弃 rc**，且**不保证 active=a** | 只跑 `--step S3` 时设备 active 仍是 b ⇒ reset 后启 Linux，`observe_android` 返回 4（`FELL_BACK_LINUX`），脚本却照样 `return 0` 报"走完" | 新增 `require_active_a()`（fastboot 侧读/写 `--set-active=a` 并读回；linux/edl 侧 **fail-closed**）；S2/S3/S4 写盘前 + reset 前各校验一次；`observe_android` 的 rc ≠ 0 ⇒ `return 1` |
| A5 | `observe_android` 的 `recovery` 分支只 `adb shell ls /tmp/recovery.log`，且把现态当先进 CONCLUSION 写死为「先读 misc 判 BCB 污染 vs 真失败」 | 11-21 那发唯一有效样本只留下 `verdict.txt` 一行字；`adb shell` 本身因 SELinux 子进程失败而 `SIGABRT`，什么都没抓到 | recovery 分支改为 **`adb exec-out` 当场抓 4 件**（`/proc/cmdline`、logfs 首 16 块、`/tmp/recovery.log`、`ro.boot.*`），并按 `force_normal_boot` 自动分叉 verdict（§6 判读） |
| A6 | `dev_state` 在 `qdl reset` 后**瞬时重逢 9008** 就判 `EARLY_FAIL state=edl` | 2026-11-20 20:27 的 S2 就留下 `verdict.txt: EARLY_FAIL state=edl`（当时设备其实正常启回了 Linux） | 观测前 **60 s 内的 `edl` 视为瞬态**（记日志、不写 verdict、`sleep 5` 重采样） |
| A7 | `run()`/`logc()` 用 `printf '%s' "$*"` 打印，**丢掉远端命令的引号** | 手抄执行单会在**主机**上跑 `findmnt` / 裸 `reboot`（`reports/android-v3-bringup-packet-20261120.md` §10.3 F1） | 新增 `_q()`（`printf '%q'`），`run()` 的打印与 `commands.log` 都改用可照抄形式 |
| A8 | S2 头注释仍写「目的：排除 H4」，无历史说明 | 会把已排除项再花一个设备窗口 | S2 步骤打印已知事实（11-20 20:26 已跑、写前=写后=原厂件）；S3 打印「在机是 v1 ⇒ 判的是 v1 vs 原厂，不是 v3」 |

验证（主机侧，零设备写）：

```sh
$ bash -n scripts/android-v3-bringup-walkthrough.sh            # syntax OK
$ bash scripts/android-v3-bringup-walkthrough.sh --dry-run     # rc=0，S1–S5 全打印，含新的 require_active_a / sha 白名单行
$ python3 scripts/gen-scripts-index.py --check                 # OK 344 个入口；随后重生成，仅 android-super.py 引用计数 46→47
```

仍**未修**（低风险，登记）：F3（dry-run 下 `commands.log` 仍不完整——dry 分支不都写 log）、
`ensure_boot_a_attrs` 在 fastboot 侧只 WARN 不阻断（当前由 `--set-active=a` 顺带复位，PITFALLS #677）。

---

## 7.5 建议登记的坑（本 lane 无权写 `PITFALLS/`，请父代理按字号补）

| 建议 | 判据一句话 | 证据 |
|---|---|---|
| **logfs 只保留最近一次启动** | `UEFILOG1.TXT` = 64 KiB（单条 ~21 KB），ABL 每次启动整段重写；8 MiB 分区其余是历史遗留簇（含旧固件 `6.0.250606`），读 logfs 必须先取 `[28672, 94272)` 并核对 `UEFI Ver` 固件代次（第二次踩 #597） | 机制重判 §1 |
| **`dump.f2fs` 会写它 dump 的镜像** | `[update_superblock: 765] Info: Done to update superblock` ⇒ 取证件必须**先复制**再 dump，否则取证物被改（本轮把 `metadata-64M.bin` 改成了 `90d3461c…`，重读原件 `3f4934ee…` 才恢复） | 材料 §C.6 |
| **`misc` 不是只有 4 KiB BCB：ABL 在 `0x8000` 起自留状态** | 4 KiB 全零时 `misc[0x8000]` 仍是 `02 b0 0a 74 56`，且 `0x8080`/`0x80C0` 两处在 11-20 20:31→11-21 09:39 之间被零化 ⇒ 「清 BCB=清 4 KiB」不覆盖 ABL 自留区，判读要整 1 MiB | 材料 §C.4 |
| **b 槽 `uefi_b`/`vendor_boot_b`/`init_boot_b` 的 GPT 属性 = `unbootable=1`（0xff）** | 三者在 LUN4 表里 `byte6=0xff`；`boot_b` `0x77` 正常 ⇒ 现在不影响启 Linux，但属"整槽可启性"隐患，来源未定 | 材料 §C.3 |
| **walkthrough `run()` 的 stdout 会污染"抓字节"输出文件** | `run … ssh 'dd …' > file` 会把 `[run] timeout …` 写进 file（`super-head512k.bin` 只剩 156 B / 混进命令文本 ⇒ `bad geometry magic`） | 机制重判 §7 A1/A2 |

---

## 8. 本轮设备只读动作清单（可复现）

```sh
ssh elden-root 'uname -r; uptime; qbootctl -a; cat /proc/cmdline'
ssh elden-root 'dd if=/dev/disk/by-partlabel/{abl_a,logfs,super(128 块),misc(1M),metadata(64M),userdata(4K)} iflag=direct'
ssh elden-root 'for p in boot_a init_boot_a vendor_boot_a recovery_a dtbo_a pvmfe_a vbmeta_a vbmeta_system_a; do
                  dd if=/dev/disk/by-partlabel/$p iflag=direct bs=1M | sha256sum; done'
ssh elden-root 'python3 /tmp/slot-attr.py --allow-wrong-lun --device /dev/sde show'
```

**零写操作**：没有 flash / qdl write / EDL 写 / `qbootctl -s|-u|-m` / `dd of=` / reboot。
（`slot-attr.py show` 只读；`scp` 仅把两个 python 脚本放到设备 `/tmp`。）

---

## 9. 数字结论表（一屏）

| 量 | 值 |
|---|---|
| logfs 活文件 | `UEFILOG1.TXT` = 65536 B / 单条记录 ~21 KB（一次启动即覆盖） |
| 11-20 三份 dump 的活记录 | 同一条：`Boot lun: 1 vs BootableSlot: _b` → `Launching fastboot`（b 槽面） |
| logfs 里 `Booting Into Recovery` 命中 | **0**（`Mission Mode` 命中 9） |
| 11-21 recovery 样本数 | **1**（`logs/android-v3-S1-20261121-091754/`） |
| a 槽与 ROM 逐字节相同的件 | **6/7**（仅 `vbmeta_a` 不同） |
| 在机 super | **v1**（head512k `67ff7604…`） |
| S2 写前/写后/设备读回 sha | 三者均 `a735fbc7…`（no-op） |
| `/data` ext4 `s_mnt_count` | **0**（11-19 21:16 mkfs 起从未挂载） |
| `/data` ext4 `encrypt` 特性 | **无**（incompat `0x42`） |
| `/metadata` f2fs `valid_block_count` / `valid_node_count` | **6** / **3**（空 fs，无 vold key） |
| `pstoredump` panic/oops 命中 | **0** |
| 设备写操作次数 | **0** |
