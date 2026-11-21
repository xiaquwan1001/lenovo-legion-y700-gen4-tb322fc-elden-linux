# a 槽 S2/S3 材料盘点 + 设备只读取证（2026-11-21）

> 配套：机制重判 `reports/android-a-slot-mech-rejudge-20261121.md`、执行单 `reports/android-a-slot-s2s3-execplan-20261121.md`。
> 本文只回答两件事：**B. 要写的件在不在、完不完整、有没有第二份、与台账对不对**；
> **C. 设备现态（只读）到底是什么**。全部命令 + 原始输出片段都在正文里。
> 设备：U2 `HA2EXB0E`（b 槽 Linux / `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）。
> 取证归档：小件 `reports/artifacts/android-a-slot-forensics-20261121/`（入库）；大件 `logs/a-slot-forensics-20261121/`（gitignored）。
> **★SSOT 待并入**：`TASKS/README.md` §4 需要一条指针（本 lane 无权改正文）。

---

## 0. 一屏结论

| # | 结论 | 数字/证据 |
|---|---|---|
| 1 | **S2 件在位且与台账一致** | `out/android-v3-bringup-20261120/metadata_stock.img` 29 372 416 B / O_DIRECT `a735fbc7…` |
| 2 | **S3 件不在位（按设计现造）** | `super_stock_contig.img` 缺；8 个原厂分片全在，sha 与 `pieces-inventory.txt` **8/8 一致**；拼装后应为 15 607 586 816 B（分片实占 15 604 424 704 B + 3 162 112 B 空洞补零）；工作区余 **188 GiB** |
| 3 | **回退件齐** | 在机 super = v1 ⇒ 回退件 `out/android-min-20261118/pkg/super_min.img`（`e3d0d26f…`，今日 O_DIRECT 复核一致）；`vbmeta_a` 在机件有 dump `logs/forensics-20261120-2210/vbmeta_a.img`（`419e01ac…`） |
| 4 | **第二份副本只有"上一代"** | `backup/stock-259/`（2026-09-29 采集）是**上一代固件**（`boot_a` `d4772c11…` ≠ 在机 `b428a31d…`）⇒ **不能当回退件**；有效第二份只有 `backup/official-rom-15.10.259/`（与在机件同代） |
| 5 | **在机 super = v1** | 设备侧 head512k `67ff7604…` = v1 件首 512 KiB **逐字节相同** |
| 6 | **kbc/misc 现态干净但有一处新异常** | `misc[0:32KiB]` 全 0；`0x8000` 5 B（stock 期同值）；**`0x8080`/`0x80C0` 已被零化**（11-20 20:31 时还是 `01 0c 11 b5 6a` / `01 72 6f 6d 73`） |
| 7 | **b 槽 GPT 属性有 3 个分区是 unbootable=1** | `uefi_b` / `vendor_boot_b` / `init_boot_b` = `0xff`（retry7/succ1/**unbootable1**）；`boot_b` `0x77`、`abl_b` `0x4f` |
| 8 | **`/data` 从未被挂载** | `userdata` ext4 `s_mnt_count = 0`，`s_mkfs_time = 2026-11-19 21:16:23 CST`，**无 `encrypt` 特性** |

---

## B. 材料在位与完整（sha 一律 O_DIRECT）

命令原文（主机侧一律走本仓硬门 `scripts/odirect-sha.py`，避免页缓存污染，AGENTS 硬规则 12 / PITFALLS「页缓存 sha 稳定但错」）：

```sh
python3 scripts/odirect-sha.py --tsv <file>            # 输出 "<path>\t<bytes>\t<sha256>"
```

### B.1 S2 件（原厂 metadata，28.01 MiB）

| 项 | 值 |
|---|---|
| 路径 | `out/android-v3-bringup-20261120/metadata_stock.img` |
| 字节 | 29 372 416（= 7171 扇区 × 4096） |
| O_DIRECT sha256 | `a735fbc74abf0d9695a1fc598128acc78184abc710224719825bbe16fca4722e` |
| 台账 | `reports/artifacts/android-v3-bringup-20261120/pieces-inventory.txt` 同值 ✅ |
| 首 512 KiB sha（设备侧对照指纹） | `1fdbee76c49d643926fcf4aea1650516342e37a89276030a4dcc2823a7873c9f` |
| 拼装来源 | `backup/official-rom-15.10.259/metadata_1..8.img`（8 片，共 10 670 080 B 实数据，落在 5857704..5864874 跨度内） |
| 第二份副本 | **无**（只有 `out/android-min-avb-20261118/metadata.img` 这个**别的用途**件，sha 不同，不作副本） |

> 注：**S2 在 11-20 20:26 已实跑**（`logs/android-v3-S2-20261120-202620/`），且**写前读回件就等于这个 sha**
> ⇒ 再跑一次是 no-op（见机制重判 §3.2）。

### B.2 S3 件（原厂 super，14.54 GiB）—— 现造

| 项 | 值 |
|---|---|
| 拼装件路径（约定） | `out/android-v3-bringup-20261120/super_stock_contig.img` |
| **是否存在** | ❌ 缺（设计如此：稀疏落盘约 12.2 GiB，占窗口前不造） |
| 目标任务尺寸 | **15 607 586 816 B** = 3 810 446 扇区 × 4096 |
| 分片实占 | 15 604 424 704 B（8 片之和）；**3 162 112 B（772 扇区）是空洞，拼装时补零** |
| 拼装命令 | `python3 scripts/android-super.py assemble --xml backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml --label super -o out/android-v3-bringup-20261120/super_stock_contig.img` |
| 工作区余量 | `/` 937 G，已用 702 G，**可用 188 G**（≥ 12.2 GiB，够） |

原厂 8 分片（今日 O_DIRECT 重测，与 `pieces-inventory.txt` 逐行相同）：

```
super_1.img    405504      d30085c8ba5ee1faae7d7a70a3c069372f29c2573c63ff1e39eece412416e9b4
super_2.img    1650688     7cd080a1667785ed5a5d6dedf3deda192fc6266f49096dbd421298d055844abd
super_3.img    1041178624  9fa82c7fc4505fdc78c05e0407bec75fe7f1c5633ce486ec2df0aa36143fe976
super_4.img    12266729472 756f288dace1cbaed3a1412b81d902a26deeb2ef4d6ee778022e3c08cdbd44e2
super_5.img    12533760    bdd924e82c810a4dd4489e1ef51f21a2dc415e117d4ef0e449243c5ab32b4b63
super_6.img    598372352   780e33b4ca4f92bc7ae06f98d03d9e44da1aaf1f1d11f6a188ffbe70599fda60
super_7.img    1536172032  9f3f4057b8b5298f33216d091ff667b8b17f204df82158773316129fcdf91203
super_8.img    147382272   179419e2e61bd675cdb3942a414421d75d85910888365317bd75383d4800587c
```

原厂 super 首 512 KiB 的 sha（用 `super_1.img` + 补零算得，供设备侧快速判别）：

```
stock super head512k sha256 = 12c35980e1e809dbb621c6be9dabb51cad777e18fc944bcc4ffec228a611c23d
stock super head1M   sha256 = 84cf64251e3f0d1527a945cc482de0ab5cd759ae64f203d2a5aa25debc16f0b3
```

### B.3 回退件（S1–S3 全覆盖）

| 回退对象 | 件 / 值 | 依据 |
|---|---|---|
| 在机 super（= v1） | `out/android-min-20261118/pkg/super_min.img` 8 893 497 344 B / `e3d0d26fb3a6f97ec10e4533ea2d675a9693acb42bb10ddb9dd4cb897517e13c`（今日 O_DIRECT 复核 ✅） | 在机 head512k 与该件首 512 KiB 逐字节相同 |
| 在机 super（全量快照） | 设备侧 22 GiB 读回成本高；**不需要**——该分区内容 = v1 件（`8.28 GiB`）+ 尾部历史（LP 元数据不引用 14.54 GiB 以上区域） | `android-super.py list` 的 extents 全部落在 blockdev size 内 |
| `vbmeta_a`（自签，在机） | `logs/forensics-20261120-2210/vbmeta_a.img` 65 536 B / `419e01ac8af7345e69a0f7f43d0e08a71079e912c9add92a5748cf1876716f31` | 11-20 设备侧 dump |
| `vbmeta_a`（**改回原厂**用） | `backup/official-rom-15.10.259/vbmeta.img` 65 536 B / `55929c1580d437ad9d5f43e897c37f0d6aa1f1469ffb8ede5928f4b43387f387` | H5 实验用；回退 = 上面的在机件 |
| `boot_a` | 在机 = 原厂 `b428a31d…`；件 = `backup/official-rom-15.10.259/boot.img` | 两侧 sha 相同 |
| `misc` 现值 | 已归档：`logs/a-slot-forensics-20261121/misc-full-1M.bin`（1 MiB / `ca6dc3b6…`）；64 KiB 口径 `c515a5d7…` | §C.4 |
| `boot_a` GPT 属性 | 现值 `0x32`（retry6 / succ0 / unbootable0）；复位命令见执行单 | §C.3 |

### B.4 第二份副本与台账对账

```sh
$ ls -d backup/*259*
backup/official-rom-15.10.259   backup/stock-259
$ sha256sum backup/stock-259/{boot_a.img,vbmeta_a.img,recovery_a.img,init_boot_a.img}
d4772c1189b5d4385718ef0db84ce4f32a6ef2629a32497554b65fba91705886  boot_a.img
61b202102302493a33b142ddff6974391ade2b570ebf10943a370f427c5630d5  vbmeta_a.img
dfaf3dde754cd1d2bf716c2168d3dda6d760c69b10de7a0eb4891d74cd0b2a1d  recovery_a.img
6c97450e4bea2b38bbe9f599547316f1dba0676df1696cfff2a2a2dc1e5a55bf  init_boot_a.img
```

⇒ `backup/stock-259/`（mtime 2026-09-29）属**上一代固件**，与在机件（2026-06-11 代 `ZUXOS_1.5.10.259_260611`）**不同代**；
**不可用作回退件**，只能作"上一代对照"。有效原件只认 `backup/official-rom-15.10.259/`。

台账一致性：`reports/artifacts/android-v3-bringup-20261120/pieces-inventory.txt` 的 7 件 + 16 分片本轮全部重测一致；
唯一口径差异见该台账注明项（`super_dbg.img` buffered sha 会漂 → 以 O_DIRECT `8b42f20d…` 为准）。

---

## C. 设备只读取证（现态）

### C.1 现态与槽位

```sh
$ ssh elden-root 'uname -r; uptime; qbootctl -a'
7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0
 09:33:35 up 12 min,  2 users,  load average: 0.08, 0.10, 0.14
Active slot: _b

$ ssh elden-root 'qbootctl'
Current slot: _b
SLOT _a:  Active 0  Successful 0  Bootable 1
SLOT _b:  Active 1  Successful 1  Bootable 1
```

`qbootctl` **只报 Bootable 0/1**，retry/unbootable 必须读 GPT 属性字节。

### C.2 分区几何（LUN0 后表实测值，与台账一致）

```sh
$ ssh elden-root 'for p in super metadata misc userdata linux17 boot_a boot_b; do \
      printf "%-10s %-8s %s\n" $p "$(readlink -f /dev/disk/by-partlabel/$p)" "$(blockdev --getsize64 /dev/disk/by-partlabel/$p)"; done'
boot_a     /dev/sde12  100663296
boot_b     /dev/sde45  100663296
metadata   /dev/sda13  67108864
misc       /dev/sda7   1048576
super      /dev/sda10  23622320128
userdata   /dev/sda16  275681456128
linux17    /dev/sda17  207232172032
```

GPT（`out/android-slim-v3-20261119/edl/gpt0-primary.bin` 现读件）：

```
super            90504..5857671     5767168 扇区 = 22.000 GiB
vbmeta_system_a  5857672..5857687        16 扇区 =  0.062 MiB
metadata         5857704..5874087     16384 扇区 =  0.062 GiB（64 MiB）
misc             89992..90247          256 扇区
userdata         5972392..73277434  67305043 扇区 = 256.748 GiB
linux17          73277435..123871226 50593792 扇区 = 193.000 GiB
```

⚠ 注意 **super 分区 22 GiB ≠ 原厂镜像 14.54 GiB**：原厂只写 `90504..3864949`；写 3 810 446 扇区后
14.54–22 GiB 段保留旧内容，而 LP 元数据（v1/v3/原厂三种）的 extent 都在各自 blockdev size 内 ⇒ **不影响挂载**。

### C.3 a/b 槽 GPT 属性字节（`slot-attr.py show`，只读）

```sh
$ ssh elden-root 'python3 /tmp/slot-attr.py --allow-wrong-lun --device /dev/sde show | grep -E "boot_|uefi|abl|init_boot|vendor_boot|recovery_|pvmfw"'
  boot_a             byte6=0x32 retry=6 active=0 succ=0 unbootable=0     ← 可启（bit7=0, retry>0），但"未成功"、retry 已被抽到 6
  vendor_boot_a      byte6=0x7b retry=7 active=0 succ=1 unbootable=0
  recovery_a         byte6=0x7b retry=7 active=0 succ=1 unbootable=0
  init_boot_a        byte6=0x7b retry=7 active=0 succ=1 unbootable=0
  pvmfw_a            byte6=0x7b retry=7 active=0 succ=1 unbootable=0
  uefi_a             byte6=0x7b retry=7 active=0 succ=1 unbootable=0
  abl_a              byte6=0x0b retry=1 active=0 succ=0 unbootable=0
  boot_b             byte6=0x77 retry=6 active=1 succ=1 unbootable=0
  uefi_b             byte6=0xff retry=7 active=1 succ=1 unbootable=1     ← ★异常
  abl_b              byte6=0x4f retry=1 active=1 succ=1 unbootable=0
  vendor_boot_b      byte6=0xff retry=7 active=1 succ=1 unbootable=1     ← ★异常
  init_boot_b        byte6=0xff retry=7 active=1 succ=1 unbootable=1     ← ★异常
```

判读：
- `boot_a = 0x32`（retry 6 / succ 0 / unbootable 0）⇒ **可启**，但每次失败抽一次重试；上机前必须复位到 `0x7a`（PITFALLS #695）。
- `uefi_b/vendor_boot_b/init_boot_b = 0xff` **是新登记的异常**（b 槽在跑 Linux，`boot_b` 正常，故当前不影响启动；
  但它意味着"整槽 unbootable"这件事在位——若哪天 `boot_b` 也被抽干，ABL 可能直接判 b 槽不可启）。
  来源未定（`--set-active` 与 `slot-attr.py set` 都会写这一族字节），**未验证**。

### C.4 misc（BCB 与 ABL 自留区）

```sh
$ ssh elden-root 'dd if=/dev/disk/by-partlabel/misc bs=64k count=1 iflag=direct | sha256sum'
c515a5d771b9443f80c0df29a79f1cca7ee06adea15e4ccf6f14fe3bcd5f800c   # 64 KiB 口径（任务书要求）
$ ssh elden-root 'dd if=/dev/disk/by-partlabel/misc bs=1M iflag=direct | sha256sum'
ca6dc3b64ed590f8af9b78fa3177243f6ad22a1f8ada93de77a0e4c9a61e2fd0   # 1 MiB 全量
$ python3 - <<'EOF'   # 1 MiB 件逐块统计
block @32768: nonzero=5     ← 只有这一处非零；0..32 KiB 全 0（无 boot-recovery / bootonce-*）
0x8000: 02 b0 0a 74 56
0x8080: 00 00 00 00 00 00 00 00 …      ← ★ 11-20 20:31 时是 01 0c 11 b5 6a
0x80c0: 00 00 00 00 00 00 00 00 …      ← ★ 11-20 20:31 时是 01 72 6f 6d 73
EOF
```

对比（同口径，1 MiB）：

| 件 | `0x8000` | `0x8080` | `0x80C0` | `[0:32]` |
|---|---|---|---|---|
| `runs/laneDeviceV3/pstore/misc-after-boot.bin`（11-20 20:31） | `02 b0 0a 74 56` | `01 0c 11 b5 6a` | `01 72 6f 6d 73` | 全 0 |
| `backup/misc/misc-full_from-android-a.bin`（stock 期） | 同上 | 同上 | 同上 | `bootonce-bootloader` |
| `logs/forensics-20261120-2210/misc.bin`（11-20 22:10） | 全 0（1 MiB 全零） | — | — | 全 0 |
| **今天**（`misc-full-1M.bin`） | `02 b0 0a 74 56` | **全 0** | **全 0** | 全 0 |

⇒ 两条新事实：
① **ABL 在 misc 里有自己的状态区（`0x8000` 起）**，"清 BCB = 只清 4 KiB"**不覆盖它**；
② 11-20 22:10 那份 1 MiB **全零**（说明有人在这之前整段清过 1 MiB），今天 `0x8000` 的 5 字节又回来了、另两处被零化
⇒ **写者非单一**（ABL 与我们的 dd 都在写），`misc` 的判读必须整 1 MiB 而不是只看 4 KiB。**未验证**具体写者。

### C.5 在机 super = v1（首 512 KiB 指纹）

```sh
$ ssh elden-root 'dd if=/dev/disk/by-partlabel/super bs=4096 count=128 iflag=direct' > super-head512k.bin
$ sha256sum super-head512k.bin
67ff7604e59f5b70343846572f492d1d0b405a914fda9e4d86a1982affc47479
$ python3 scripts/android-super.py list super-head512k.bin | head -12
geometry   : mag=0x616c4467 struct_size=52 checksum=OK max_size=65536 slots=3 logical_block_size=4096
metadata   : primary slot=0 off=12288 v10.2 header=256 tables=692 flags=0x1 hdr_chk=OK tbl_chk=OK
blockdev   : name=super first_logical_sector=1024 alignment=524288 alignment_offset=491520 size=23622320128
partition  : system_a 5296.00 / vendor_a 1466.00 / product_a 993.00 / system_ext_a 571.00
             vendor_dlkm_a 141.00 / system_dlkm_a 12.00 / odm_a 2.00      ← 7 个 _a，v1 布局
```

**判别指纹表（三件，脚本已接入 `S1`）**：

| 在机件 | super 首 512 KiB sha256 |
|---|---|
| v1（`out/android-min-20261118/pkg/super_min.img`） | `67ff7604e59f5b70343846572f492d1d0b405a914fda9e4d86a1982affc47479` |
| v3（`out/android-slim-v3-20261119/new/super_min_v3.img`） | `c6278f8e2646d7d07aaea5f309a50e558dcb42e7833615305ac703bd136ce58d` |
| 原厂（拼装件首 512 KiB） | `12c35980e1e809dbb621c6be9dabb51cad777e18fc944bcc4ffec228a611c23d` |

⇒ **在机 = v1**（不是 v3）。

### C.6 metadata（今天已不等于原厂件：f2fs 被 Android 挂过）

```sh
$ ssh elden-root 'dd if=/dev/disk/by-partlabel/metadata bs=4096 count=128 iflag=direct | sha256sum'
9a0ffcf91328805f0b5b634ce3231c23ad47eb86ce756318174a7b3f701e10fe     # 在机 head512k
# 原厂件 head512k = 1fdbee76…（B.1）；11-20 20:26 写前读回件也是 a735fbc7…（= 原厂全量）
$ ssh elden-root 'dd if=/dev/disk/by-partlabel/metadata bs=1M count=64 iflag=direct' > metadata-64M-pristine.bin
$ sha256sum metadata-64M-pristine.bin
3f4934ee448996085edd05a1e4bcac1884415637bd23f61f06194a3e097e9732
```

与 11-20 20:26 的原厂写入件逐块对比（29 372 416 B 跨度内）：

```
differing 4KiB blocks: 36   first [0, 4096, 2097152, 2101248, 2105344, 2109440, …]
```

差异块位置与 f2fs 结构吻合（超级块 0/4 KiB；checkpoint 区 `cp_blkaddr=512` ⇒ 偏移 2 MiB）
⇒ **有 Android 把 `/metadata` 挂成 RW 并做了 checkpoint**（Linux 侧 `/proc/mounts` 只有 `sda17 /`，不可能写它）。

`dump.f2fs` 解出的 fs 是**空 fs**：`valid_block_count=6`、`valid_node_count=3`、`total FS sectors=131072 (64 MB)`、
`version 6.6.118-android15-…`（Android 15 的 f2fs 格式化）⇒ **没有 `/vold/metadata_encryption/keys`**。

> ⚠ 取证纪律：`dump.f2fs` 会**写**被 dump 的镜像（`update_superblock: Done to update superblock`）。
> `metadata-64M.dumpf2fs-mutated.bin`（`90d3461c…`）是被它改过的；参考值用 `metadata-64M-pristine.bin`（`3f4934ee…`，重读复现）。

### C.7 userdata（`/data`）首 4 KiB：从没被挂载过

```sh
$ ssh elden-root 'dd if=/dev/disk/by-partlabel/userdata bs=4096 count=1 iflag=direct' > userdata-head4k.bin
ext magic 0xef53
s_blocks_count 67305043 (= 256.748 GiB，正好是分区大小)
s_free_blocks  65986867 (98%)
s_inodes_count 16826368
s_mnt_count    0                    ← ★ 建好之后**从未挂载**
s_mkfs_time    2026-11-19T13:16:23Z  (= 11-19 21:16:23 CST)
s_wtime / s_lastcheck 同值；s_state 0x1(clean)
features incompat 0x42 (FILETYPE+EXTENTS；**无 ENCRYPT / 无 64BIT**)
features ro_compat 0x7b
s_r_blocks_count 673050 (= 1% ⇒ 显式 -m 1；mke2fs 默认 5%)
volume_name ''（空）
```

⇒ **`userdata` 是主机侧 e2fsprogs 风格的空 ext4，不是 Android 的 `mke2fs -O encrypt` / `make_f2fs` 产物**；
且 **自建好起没有任何系统挂载过它**（`s_mnt_count` 单调增，不会归零）。

### C.8 logfs（ABL 日志）：活记录 = 本次 b 槽 Linux 启动

```sh
$ ssh elden-root 'dd if=/dev/disk/by-partlabel/logfs bs=1M iflag=direct' > logfs-now.bin
# FAT12: UEFILOG1.TXT cluster=2 size=65536（只 64 KiB，单条记录）
$ python3 -c "…write [28672:28672+65536] to uefilog1-current.txt…"
UEFI Ver           : 6.0.260611.BOOT.MXF.2.5.1-00240.1-PAKALA-1
Loader Build Info: Jun 11 2026 06:16:07
Fastboot=0, Recovery:0
Loading Image recovery_b Done : 0 ms, Image size : 4096 Bytes
Booting from slot (_b) / Booting Into Mission Mode
avb_slot_verify.c:913: ERROR: vbmeta_b: Public key used to sign data rejected.
Loaded Partition: boot / dtbo / pvmfw
Cmdline: console=ttyGS0,115200 console=tty0 … elden_root=LABEL=linux androidboot.slot_suffix=_b …
Shutting Down UEFI Boot Services: 13625 ms
```

别的日志一律是**历史遗留簇**（含 9 条 `6.0.250606` 旧固件 a 槽记录）——判读口径见机制重判 §1。

### C.10 头尾少量读回（任务书要求：不整盘读 14.5 GiB）

```sh
# 头已在 C.5/C.6（super 128 块 = 512 KiB；metadata 128 块 = 512 KiB）
# 尾 4 MiB（O_DIRECT）
$ ssh elden-root 'dd if=/dev/disk/by-partlabel/super    bs=1M skip=22524 count=4 iflag=direct' > super-tail4M.bin
$ ssh elden-root 'dd if=/dev/disk/by-partlabel/metadata bs=1M skip=60    count=4 iflag=direct' > metadata-tail4M.bin
$ sha256sum super-tail4M.bin metadata-tail4M.bin
bb9f8df61474d25e71fa00722318cd387396ca1736605e1248821cc0de3d3af8   super-tail4M.bin
bb9f8df61474d25e71fa00722318cd387396ca1736605e1248821cc0de3d3af8   metadata-tail4M.bin   ← 两份同值
$ python3 -c "…nonzero 统计…"
super-tail4M.bin nonzero 0
metadata-tail4M.bin nonzero 0      ← 两者末 4 MiB **全零**（未写入区，符合 v1/原厂件都短于分区）
```

LUN0 分区表项（现读，`dd if=/dev/sda bs=4096 skip=0 count=34 iflag=direct`，139 264 B）：

```sh
$ python3 …   # 解析
magic EFI PART   nent 32   esz 128   disk guid ebfc6ec9-bb90-52e1-f60b-2321c7f4d385
first/last usable LBA = 6 .. 123871226
misc                 89992 ..      90247      1.000 MiB
keystore             90248 ..      90375      0.500 MiB
frp                  90376 ..      90503      0.500 MiB
super                90504 ..    5857671  22528.000 MiB      ← 22 GiB 分区（原厂件只写 3 810 446 扇区）
vbmeta_system_a    5857672 ..    5857687      0.062 MiB      attrs=0x100b000000000000
vbmeta_system_b    5857688 ..    5857703      0.062 MiB      attrs=0x104f000000000000
metadata           5857704 ..    5874087     64.000 MiB
rawdump            5874088 ..    5939623    256.000 MiB
pstoredump         5939624 ..    5972391    128.000 MiB
userdata           5972392 ..   73277434 262910.324 MiB
linux17           73277435 ..  123871226 197632.000 MiB
```

（`vbmeta_system_a/b` 的 attrs 非 0 = A/B 槽属性位，其 byte6 语义见 C.3；其余分区 attrs 全 0。）

### C.9 pstoredump（内核崩溃通道）

```sh
$ bash scripts/android-v3-bringup-walkthrough.sh --step S4 --dry-run    # 其 pstore_triage 实跑只读段
hit=0        # grep -acE 'panic|oops|Unable to handle' 命中 0
```

（`logs/android-v3-S4-20261121-095338/pstore-raw.txt` = `0`；改前的旧实现会把 `[run] …` 混进这个文件，本轮已修。）

---

## D. 归档件与复现

`logs/a-slot-forensics-20261121/`（`SHA256SUMS.txt` 已随件更新）：

| 件 | 字节 | sha256 | 说明 |
|---|---|---|---|
| `super-head512k.bin` | 524 288 | `67ff7604…` | 在机 super 首 512 KiB（v1 指纹） |
| `metadata-64M-pristine.bin` | 67 108 864 | `3f4934ee…` | 在机 metadata 全量（参考件） |
| `metadata-64M.dumpf2fs-mutated.bin` | 67 108 864 | `90d3461c…` | 被 `dump.f2fs` 改过的同一份（**不要**当参考） |
| `misc-full-1M.bin` | 1 048 576 | `ca6dc3b6…` | misc 全量（64 KiB 口径 `c515a5d7…`） |
| `userdata-head4k.bin` | 4 096 | `4160ab74…` | `/data` ext4 超级块所在块 |
| `logfs-now.bin` | 8 388 608 | `b2d3c946…` | logfs 全量（活记录见 `uefilog1-current.txt`） |
| `uefilog1-current.txt` | 65 536 | `5b147ef0…` | logfs 的活 64 KiB 记录 |
| `abl_a.bin` | 1 048 576 | `e7062378…` | ABL（与原厂 `abl.elf`、在机 `abl_b` 同 sha；内容是压缩 ELF，`strings` 取不到文案） |
| `super-tail4M.bin` | 4 194 304 | `bb9f8df6…` | 在机 super 末 4 MiB（**全零**） |
| `metadata-tail4M.bin` | 4 194 304 | `bb9f8df6…` | 在机 metadata 末 4 MiB（**全零**，与上同值） |
| `gpt0-primary-lba0-33.bin` | 139 264 | `755609da…` | LUN0 主表（保护 MBR + 头 + 32 项） |

复现命令：每条结论上方均给了原命令；指纹类（head512k / misc / metadata）再跑一次应得同值
（O_DIRECT 口径，本轮 metadata 重读两次一致 `3f4934ee…`）。
