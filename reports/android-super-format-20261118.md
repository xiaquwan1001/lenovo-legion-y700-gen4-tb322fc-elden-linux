# super 封装格式、工具链与精简额度（S1）

日期：2026-11-18 ｜ 全部在主机侧完成（未接触设备、未改 SSOT、未 commit）
产物：`scripts/android-super.py`、`scripts/android-super-scan.py`、`out/android-super-20261118/`

---

## 0. 结论数字（先看这里）

| 项 | 数值 | 判据/命令 |
|---|---|---|
| 8 段 `super_1..8.img` 合计 | **15,604,424,704 B = 14.53 GiB** | `ls -l backup/official-rom-15.10.259/super_*.img` |
| 组装后 super 所在磁盘槽 | **22,528 MiB (23,622,320,128 B)** | metadata `block_devices[0].size` |
| liblp 元数据区 | **405,504 B = 4096 + (4096 + 65536×3)×2**，与 `super_1.img` 长度**完全相等** | `GetTotalMetadataSize()` 公式 |
| geometry 校验 | **通过**（struct_size=52，SHA-256 覆盖前 52 B，checksum 字段清零） | 本文 §1.1（**修正已知事实 2**：先前"验不过"是 hash 区间/清零位置取错） |
| 6 份 metadata 副本 | 全部 header/table checksum **通过**（v10.2，header 256 B，slot0/1 tables 2376 B，slot2 1104 B） | §1.1 |
| 元数据结构 | `LP_HEADER_FLAG_VIRTUAL_AB_DEVICE`(0x1)，`metadata_slot_count=3`，`metadata_max_size=65536`，`logical_block_size=4096` | §1.1 |
| 逻辑分区 | **14 个**（7 个 `_a` + 7 个 `_a-cow`），extent 60 条，`qti_dynamic_partitions_a` 上限 22,524 MiB，**已用 14,887.30 MiB (66.1%)**，`cow` 组 375.34 MiB | §3 |
| 载荷文件系统 | 7/7 全 **ext4**（label 与分区名一致），无 erofs/f2fs | §1.3 |
| 包内空洞（未写的 LBA） | **7 处共 3,162,112 B = 3.016 MiB** | §1.4 |
| 包相对"活"layout 的缺失 | **6.484 MiB**（其中 2.383 MiB 落在分区逻辑空间内，另 ~4.1 MiB 是 `system_a` 末尾 extent 越过 data_end 的部分） | §1.5 |
| 解包/重打包 | `lpunpack` 14/14 分区与自研工具 **逐字节一致**；`lpmake` 原样重打后 14/14 内容 **MATCH** | §3.3 |
| 只删预装可释放 | **6,690.52 MiB = 6.53 GiB**（`/system/preinstall` 3271.94 + `/system/etc/AI` 3209.50 + `/system/etc/bgmusic` 209.09） | §4.1 |
| 全部 ext4 空闲块合计 | **11,308 块 × 4 KiB = 44 MiB**（分区已按内容裁到极限） | §4.2 |
| ⇒ 现实可做到的最小待刷包 | **≈ 8.1 GiB**（去预装 + 重建分区 + `lpmake` 重打；较当前 14.53 GiB 减 6.4 GiB） | §4.4 |

**一句话**：`super_1..8` 不是自定义格式，是一份**标准 liblp super 的"非零/已用区域切片"**（元数据区完整 + 数据按 4 KiB 对齐的稀疏 dump，跳过 3.0 MiB 空洞），可以原样用 `lpunpack` 解开；当前包里 **b 槽没有独立数据**（与 a 槽 ext4 共享同一批物理 extent），所以"去掉 b 槽"省不出任何字节；唯一能真正让待刷文件变小的是**删内容 + 重建分区 + 重打 super**。

---

## 1. A：`super_1..8` 到底是什么

### 1.1 元数据区 = 标准 liblp，不是坏 geometry

`super_1.img` 只有 405,504 B，恰好等于 AOSP liblp 的元数据区长度：

```
GetTotalMetadataSize = LP_PARTITION_RESERVED_BYTES(4096)
                     + (LP_METADATA_GEOMETRY_SIZE(4096) + metadata_max_size×slot_count)×2
                     = 4096 + (4096 + 65536×3)×2 = 405,504
```

实测偏移（`scripts/android-super-scan.py`，输出 `out/android-super-20261118/logs/scan.txt`）：

```
super_1.img  valid=[4096:geom, 8192:geom, 12288:header, 77824:header,
                    143360:header, 208896:header, 274432:header, 339968:header]
```

即：`0..4095` 保留零 → `4096` 主 geometry → `8192` 备份 geometry → `12288/77824/143360` 主 metadata slot0/1/2 →
`208896/274432/339968` 备份 metadata slot0/1/2。字段完全符合 `system/core/fs_mgr/liblp/utility.cpp`
（2026-11-18 现取上游源码核对）：

```c
GetPrimaryGeometryOffset() = 4096;  GetBackupGeometryOffset() = 4096+4096;
GetPrimaryMetadataOffset(geo,slot) = 4096 + 4096*2 + max_size*slot;
GetBackupMetadataOffset(geo,slot)  = 4096 + 4096*2 + max_size*slot_count + max_size*slot;
```

**geometry checksum 是真的好的**（这是对已知事实 2 的修正）。校验方法：取 `struct_size=52` 字节、
把 `checksum`（偏移 8..39）清零后 SHA-256：

```
sha256(52B, checksum=0) = 12ff55f0aba7b506f25cb5da5dca09344234e8df1d9c93ae82a499d98019467e
stored                  = 12ff55f0aba7b506f25cb5da5dca09344234e8df1d9c93ae82a499d98019467e   # MATCH
geometry(4096) 与 geometry(8192) 完全相同；metadata_max_size=65536, slot_count=3, logical_block_size=4096
```

6 份 metadata 副本（slot0/1/2 × 主/备）全部 `header_checksum OK` + `tables_checksum OK`；版本 v10.2，
header 256 B，`flags=0x1` = `LP_HEADER_FLAG_VIRTUAL_AB_DEVICE`（与设备 `ro.build.ab_update=true` 一致）。

> 关于"LP metadata header magic 0x414C4467 / gDLA"：`0x616c4467`（"gDla"）是 **geometry** magic，
> **header** magic 是 `0x414C5030`（"0PLA"）。两者都全段扫了，见 §1.2。

### 1.2 全段 magic 扫描 + checksum 验证（判据：raw 命中不算，必须过校验）

```
super_1.img    raw=8   valid=2 geom + 6 header            coincidences=0
super_2.img    raw=0   valid=-                            coincidences=0
super_3.img    raw=3   valid=-                            coincidences=3
super_4.img    raw=14  valid=76075064 geom, 76079160 geom, 76083256 header   coincidences=11
super_5.img    raw=0   valid=-                            coincidences=0
super_6.img    raw=0   valid=-                            coincidences=0
super_7.img    raw=4   valid=-                            coincidences=4
super_8.img    raw=0   valid=-                            coincidences=0
```

14.5 GiB 数据里出现 0~5 个 4 字节巧合是统计必然（14.5e9/2^32 ≈ 3.4）。**唯一"合法"的额外命中**是
`super_4.img` 偏移 76,070,968 起的**嵌套 LP 镜像**（geometry 在 +4096/+8192、header 在 +12288，
v10.0、`system_a` 单分区 97,472×512 B、device size 52,002,816 B）——即某个分区里自带了一份
`super_empty.img` 类的测试镜像；说明**裸 magic 扫描必须有校验器兜底**，这也正是本工具与 `lpunpack` 的行为差异点。

复现：

```bash
python3 scripts/android-super-scan.py \
  --xml backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml \
  --segment-dir backup/official-rom-15.10.259 | tee out/android-super-20261118/logs/scan.txt
```

### 1.3 每段内部的 FS magic 与 ext4 label（判据：ext4 sb 在 1024，magic 0x53ef 在 1080，label 在 0x78）

组装后用 `scripts/android-super.py list --probe-fs`（`logs/our-list-assembled-probe-fs.txt`）：

| 分区 | 首 extent 物理偏移 | FS | label | block size | 块数 | 已用块 |
|---|---|---|---|---|---|---|
| `odm_a` | 1,048,576 | ext4 | `odm` | 4096 | 376 | 374 |
| `product_a` | 3,145,728 | ext4 | `product` | 4096 | 250,163 | 249,409 |
| `system_a` | 872,415,232 | ext4 | `/` | 4096 | 2,949,079 | 2,940,203 |
| `system_dlkm_a` | 12,746,489,856 | ext4 | `system_dlkm` | 4096 | 2,991 | 2,982 |
| `system_ext_a` | 12,759,072,768 | ext4 | `system_ext` | 4096 | 143,761 | 143,327 |
| `vendor_a` | 13,294,895,104 | ext4 | `vendor` | 4096 | 369,104 | 367,977 |
| `vendor_dlkm_a` | 14,830,010,368 | ext4 | `vendor_dlkm` | 4096 | 35,392 | 35,286 |
| 7 × `*-cow` | 15.6 GB 之后 | **全零**（无 FS） | - | - | - | - |

段 → 段内出现的 extent/分区起点（512 B 扇区，super 内相对偏移）：

| 段 | 区间 | 段内起始的 extent |
|---|---|---|
| `super_1` | [0, 792) | —（纯元数据区，§1.1） |
| `super_2` | [2048, 5272) | `odm_a@2048`、`vendor_dlkm_a@5232`、`product_a@5264` |
| `super_3` | [6144, 2039696) | `product_a@6144`、`product_a@1701920`、`system_a@1703936` |
| `super_4` | [2039808, 25998264) | `product_a@{24895480,24919904,25965840}`、`system_dlkm_a@24895488`、`system_ext_a@24920064`、`vendor_a@25966592` |
| `super_5` | [25999360, 26023840) | —（`vendor_a` 主体中段） |
| `super_6` | [26023936, 27192632) | —（`vendor_a` 主体后段） |
| `super_7` | [27193344, 30193680) | `odm_a@30018360`、`product_a@28963552/29252680/30018448/30163400`、`system_a@29555392` |
| `super_8` | [30195712, 30483568) | `product_a@30310504/30340536`、`system_a@30310472/30340056/30340560/30368992` |

**关键判据**：每个分区的 ext4 superblock 精确落在其"逻辑 0 + 首 extent 物理起点"上
（7/7 命中，且 6 个 label 与分区名逐字一致），说明 metadata 的 extent→物理偏移映射与按 XML LBA
组装的布局**完全吻合**，不是 repacker 自定义布局。erofs (`0xE0F5E1E2`) / f2fs (`0xF2F52010`) 在
分区起点均未命中（全部 ext4，`shared_blocks` 特性、只读镜像）。

### 1.4 组装后的布局与"包内空洞"

按 XML `start_sector`（4096 B 扇区）以 `base_lba=90504`（`frp` 之后第一个分区，即 super 起点）组装：

```bash
python3 scripts/android-super.py assemble \
  --xml backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml \
  --label super --pad-to-device -o out/android-super-20261118/super-90504.img
# 8 段实际载荷合计 15,604,424,704 B；最后一段写到 15,607,586,816 B（14.53 GiB）为止；
# --pad-to-device 再按 metadata 的 device size 23,622,320,128 B 补齐（稀疏，零成本）
```

7 处空洞（包内没有写、设备上保持原值的 LBA 区间，超级块坐标，512 B 扇区）：

| # | 512B 扇区区间 | 字节数 | 绝对字节偏移（super 内） |
|---|---|---|---|
| 1 | [792, 2048) | 643,072 | 405,504 – 1,048,576 |
| 2 | [5,272, 6,144) | 446,464 | 2,699,264 – 3,145,728 |
| 3 | [2,039,696, 2,039,808) | 57,344 | 1,044,324,352 – 1,044,381,696 |
| 4 | [25,998,264, 25,999,360) | 561,152 | 13,311,111,168 – 13,311,672,320 |
| 5 | [26,023,840, 26,023,936) | 49,152 | 13,324,206,080 – 13,324,255,232 |
| 6 | [27,192,632, 27,193,344) | 364,544 | 13,922,627,584 – 13,922,992,128 |
| 7 | [30,193,680, 30,195,712) | 1,040,384 | 15,459,164,160 – 15,460,204,544 |

合计 3,162,112 B。**是否 repacker 自定义布局？不是**——这些空洞全部 4 KiB 对齐、长度都是 4 KiB 的整数倍，
且 §1.5 证明包内数据 = 活 metadata 的"非 COW extent 并集"去掉这些空洞与末尾零区：典型的
**"只 dump 非零 4 KiB 块"的稀疏化打包**（等价于把 sparse 镜像的 zero-chunk 省掉后用 rawprogram 写回）。

### 1.5 包的来源 = 哪个 metadata slot？（判据：覆盖/引用比例）

| metadata slot | extent 并集 | 非 COW 并集 | COW 并集 | 覆盖包内字节 | 包内未被引用 | 非 COW 缺失 |
|---|---|---|---|---|---|---|
| slot 0（`_a` + cow，attr=RO,UPDATED） | 14.905 GiB | 14.538 GiB | 0.367 GiB | **14.532 GiB (100.00%)** | 0.001 GiB | 6.484 MiB |
| slot 1（`_b` + cow） | 14.877 GiB | 14.532 GiB | 0.345 GiB | 14.532 GiB (99.99%) | 0.001 GiB | 2.383 MiB |
| slot 2（无 cow，单 extent，attr=RO，v10.2 小表） | 13.945 GiB | 13.945 GiB | 0 | 13.944 GiB (95.95%) | 0.588 GiB | 0.984 MiB |

结论：**包是从 slot 0（活槽，boot slot a）的"非 COW extent 并集"切出来的**——14.532/14.533 GiB
对照非 COW 并集 14.538 GiB，误差只有包内那 3.0 MiB 空洞 + 末尾 4.1 MiB 零区。

旁证：slot 0 的 7 个 `*-cow` 分区（375.34 MiB）**完全没有出现在包里**（它们 100% 全零，见 §1.3），
且 `system_a` 末尾 8,392 扇区（4.1 MiB）的 extent 越过 data_end——那里已超出 ext4 的 FS 边界
（`system_a` FS 只到 2,949,079 块 = 11.25 GiB，而 extent 合计 11.43 GiB），本来就是零，故被跳过。

> 因此 **slot 2 是过期的旧 layout 副本**（`alignment=1048576/offset=0`、a/b 单 extent、无 COW，
> 很像 `lpmake` 出厂产物），slot 0/1 才是设备实际在用的（`alignment=524288, alignment_offset=491520`，
> 各 60/60 条 extent 带快照 `UPDATED` 标记）。

### 1.6 判据强度总结

| 断言 | 判据 | 强度 |
|---|---|---|
| 元数据区是标准 liblp | 长度 = 公式值 405,504 B；geometry/header/table 三处 checksum 全过；字段与上游 `utility.cpp` 现取源码逐条对上 | 硬 |
| 布局按 XML LBA 成立 | 7/7 分区 ext4 sb 精确落在"首 extent 物理偏移"，label 与分区名一致 | 硬 |
| 包 = 非 COW 已用区域切片 | 包内字节 100.00% 被 slot0 非 COW extent 覆盖，未覆盖 1 MiB；空洞 7 处全 4 KiB 对齐；COW 全零且未入包 | 硬（唯一软点是空洞内容，见 §6） |

---

## 2. B：工具链（主机侧，未 sudo）

现成可用（父代理已备好，本会话只做验证）：

```
/usr/bin/{simg2img,img2simg,append2simg,mkfs.erofs,fsck.erofs,dump.erofs,erofsfuse}
/usr/sbin/zerofree, /usr/sbin/debugfs, /usr/sbin/dumpe2fs, /usr/sbin/e2fsck, /usr/sbin/resize2fs
tools/android-super-bin/lpunpack, tools/android-super-bin/lpmake   (= ~/bin/lpunpack, ~/bin/lpmake)
```

- `lpunpack` **认位置参数**：`lpunpack [options] SUPER_IMAGE [OUTPUT_DIR]`，没有 `--help`（传了就打印 usage 退出）。
- `lpunpack` **会在 extent 越界时报 `read failed: No such file or directory` 并 rc=70**：第一次跑在
  14.53 GiB 的组装件上直接失败（最先处理的 `vendor_dlkm_a-cow` extent 在 15.6 GB 之后）。**必须先把
  镜像按 metadata 的 device size 补到 22 GiB（稀疏，零成本）**，之后 14 分区一次全出（rc=0，18.8 s）。
- 自研兜底：`scripts/android-super.py`（list/size/extract/assemble，纯 python，零依赖）。
- 独立交叉验证：`unix3dgforce/lpunpack`（948 行纯 python 第三方实现）——3 个分区 sha256 与自研一致。

---

## 3. C：解包结果 + round-trip

### 3.1 分区表（`scripts/android-super.py list`，slot 0）

```
geometry   : magic=0x616c4467 struct_size=52 checksum=OK max_size=65536 slots=3 lbs=4096
metadata   : primary slot=0 off=12288 v10.2 header=256 tables=2376 flags=0x1 hdr_chk=OK tbl_chk=OK
blockdev   : name=super first_logical_sector=2048 (1.00 MiB) alignment=524288 alignment_offset=491520
             size=23622320128 (22528.00 MiB)
group      : default                  max_size=0
group      : qti_dynamic_partitions_a max_size=23618125824 (22524.00 MiB)
group      : cow                      max_size=0

partition            attr        group                     size MiB  ext  fs
odm_a                RO,UPDATED  qti_dynamic_partitions_a      1.57    2  ext4(odm)
product_a            RO,UPDATED  qti_dynamic_partitions_a    992.95   12  ext4(product)
system_a             RO,UPDATED  qti_dynamic_partitions_a  11704.61   15  ext4(/)
system_dlkm_a        RO,UPDATED  qti_dynamic_partitions_a     11.95    2  ext4(system_dlkm)
system_ext_a         RO,UPDATED  qti_dynamic_partitions_a    570.65    6  ext4(system_ext)
vendor_a             RO,UPDATED  qti_dynamic_partitions_a   1465.01   13  ext4(vendor)
vendor_dlkm_a        RO,UPDATED  qti_dynamic_partitions_a    140.55    3  ext4(vendor_dlkm)
odm_a-cow            -           cow                           4.54    1  (全零)
product_a-cow        -           cow                          19.70    1  (全零)
system_a-cow         -           cow                         279.90    1  (全零)
system_dlkm_a-cow    -           cow                           4.21    1  (全零)
system_ext_a-cow     -           cow                          24.20    1  (全零)
vendor_a-cow         -           cow                          36.53    1  (全零)
vendor_dlkm_a-cow    -           cow                           6.27    1  (全零)
TOTAL                                                       15262.65
```

extent 明细（60 条）见 `logs/our-list-super_1.txt`（在官方段 `super_1.img` 上直接跑）与
`logs/our-list-assembled-probe-fs.txt`。特征：`_a` 分区被"OTA 快照"打散成 2~15 段（`UPDATED` 标记），
主体集中在低位，尾部夹着 8~2,032 扇区的碎片。

### 3.2 FS 实际用量（`dumpe2fs -h`，见 `logs/ext4-usage-table.txt`）

总计空闲 11,308 块 = 44 MiB ⇒ **分区已按内容裁到几乎无余量**（`system_a` 只空 8,876/2,949,079 块）。

### 3.3 round-trip

(1) **解包一致性**：`lpunpack`（C++ 官方实现）与 `scripts/android-super.py extract`（纯 python）
逐分区 sha256 —— **14/14 MATCH**；第三方 python `lpunpack.py` 抽样的 3 个分区也 MATCH。

(2) **元数据再序列化**：把解析出的 partitions/extents/groups/block_devices 重新按 `<36sIIII` /
`<QIQI` / `<36sIQ` / `<QIIQ36sI` 打包并重算 `tables_checksum`+`header_checksum`，
与原元数据区 **逐字节相同**（`tables 2376 B identical: True`，`header identical: True`）⇒ 字段口径正确。

(3) **lpmake 原样重打**（同分区名/大小/组/属性，`-d 23622320128 -m 65536 -s 3 --virtual-ab -g ...`）：

```bash
lpmake -d 23622320128 -a 524288 -O 491520 -m 65536 -s 3 --virtual-ab \
  -g qti_dynamic_partitions_a:23618125824 -g cow:0 \
  -p odm_a:readonly:1650688:qti_dynamic_partitions_a -i odm_a=extract/lpunpack-slot0/odm_a.img ... \
  -o out/android-super-20261118/roundtrip/super-lpmake.img
```

结果（`logs/lpmake.log` + `scripts/android-super.py list roundtrip/super-lpmake.img`）：

- 分区表一致：14 个分区、名字/大小/组/max_size 全同；`needed_bytes_if_compact = 15,263.04 MiB`。
- 差异（可解释，非错误）：
  * 每分区被**压成 1 条 extent**（lpmake 紧凑分配）——原镜像 60 条 → 14 条；
  * `attributes` 5 (`RO|UPDATED`) → 1 (`RO`)：`lpmake` 无 UPDATED 开关（快照态由 OTA 运行时写）；
  * `alignment/alignment_offset` 变成 1 MiB/0（本 build 的 `-a/-O` 未写进 block device 表；
    设备实际值 524288/491520 只影响原地增长对齐，不影响内容）。
- **内容对比：重新 lpmake 后按 extent 流式 sha256 与原始解包件逐分区比对，14/14 MATCH**
  （COW 分区两侧都是全零）。原始输出：`logs/roundtrip-compare.txt`（重打件已删，命令见 §5）。

---

## 4. D：精简额度三档量化

基线（这个包格式下"待刷文件" = 8 段 raw 文件）：

- 当前：**15,604,424,704 B = 14.53 GiB**（`ls -l` 合计）＝ super 已用数据 14.538 GiB − 3.0 MiB 空洞 − 4.1 MiB 尾部零区
- 若改成单文件 raw / sparse：raw 需 15.6 GiB；`fastboot sparse` 最多能省
  **48.43 MiB（12,398 个全零 4 KiB 块，占 0.33%）** —— 这是把 14.53 GiB 逐 4 KiB 扫一遍的结果
  （COW 那 375 MiB 全零本来就没进包，所以不再计入）⇒ **重新 sparse 化收益 0.3%，可忽略**。

### 4.1 (i) 只删预装 APK / 预置内容

APK 清点：298 个 `.apk` 合计 7,657.11 MiB（`logs/ext4-inventory.tsv`，由 `debugfs ls -l` 递归遍历 10,579 条目）。

主要可去：

| 目标 | 大小 | 说明 |
|---|---|---|
| `/system/preinstall` | **3,271.94 MiB**（94 文件） | 第三方预装：Wangyiyun 349、Capcut 218、BaiduNetdisk 217、AiFlashPoint 210、MotoReadyFor 181、Weibo_HDwm 169、iqiyi 165、Moffice 156、MiguPlay 153、DouYin 140、ZuiGallery 140、ZuiNotes 122… |
| `/system/etc/AI` | **3,209.50 MiB**（36 文件） | 联想本地 AI 模型 |
| `/system/etc/bgmusic` | **209.09 MiB**（40 文件） | 预置背景音乐 |
| 合计 | **6,690.52 MiB = 6.53 GiB** | = 当前包体积的 **45%** |

其他可选（需逐个判断）：`product/priv-app/LenovoXiaoTian` 256.9、`product/app/{TrichromeLibrary64 172.8,
WebViewGoogle64 77.8, xiangbb 77.5, talkback 47.3}`、`system_ext/priv-app/ZuiSystemUI 212.6` 等。

**但注意：单纯删文件不会让包变小。** 实测（`system_a` 副本，删掉上表 170 个文件）：

```
删除前: blocks=2,949,079 used=2,940,203 (11.20 GiB)
删除后: used=1,250,387 (4.77 GiB)          # 内容确实少了 6.45 GiB
resize2fs -M: 2,949,079 → 2,654,854 块 (只缩 1.15 GiB，仍留 5.35 GiB 尾部空洞)
```

⇒ 必须**重建分区**（`mke2fs` + 回填，或直接 `mkfs.erofs`），否则瘦不下来。重建后 `system_a` ≈ 4.9 GiB。

### 4.2 (ii) 再去掉 b 槽逻辑分区

- 本包 b 槽**没有独立数据**：metadata slot 1 的 `_b` 分区与 `_a` **共享同一批物理 extent**
  （逐 extent 比对：`system_b` 起点 1,703,936 = `system_a` 起点，长度只差 12,592 扇区；
  `vendor_b` 比 `vendor_a` 只差 8 扇区）。
- 所以删掉 b 槽只省 **metadata 一个副本 64 KiB（上限）**，数据 0 字节；代价是丢掉 A/B 回滚能力
  （`--virtual-ab` 设备 bootloader 会按 `slot_suffix` 选择，slot b 无 metadata 就起不来）。
- 若为了保留 b 槽而**真的写入两份数据**（干净 A/B 包），体积会**翻倍到 ~29 GiB**，这正好说明当前包是
  "共享 extent 的去重包"，而不是可裁剪的双份包。

### 4.3 (iii) 缩分区本身

两种含义分开说：

1. **缩到文件系统最小**：全部 7 个 ext4 未用块合计 **11,308 块 = 44 MiB**（0.28% 体积）——
   因为镜像当初就是 `mke2fs` + 只读回填 + `shared_blocks` 去重的，几乎无余量。
   `resize2fs -M` 只能拿回其中一部分（它只砍「最后一个已分配块之后」的空间，`product_a` 满打满算 754 块 = 3 MiB）。
2. **缩 super 物理分区本身**（22,528 MiB → 例如 16 GiB）：省的是**设备空间**（GPT 需要一起改），
   对**下载体积 0 收益**。

### 4.4 结论：哪种能真正让"待刷文件"变小

| 方案 | Δ待刷文件 | 前提 / 代价 |
|---|---|---|
| (i) 删预装 **但不动分区** | **0** | 无意义：extent 不变 |
| (i)+(iii) 删预装 **+ 重建分区 + lpmake 重打** | **−6.4 GiB ⇒ ≈ 8.1 GiB** | 需要重建 7 个 ext4（或换 erofs）、重算 `lpmake`、重新按 rawprogram/`fastboot` 分发；b 槽若要保留需再复制一份（+8 GiB） |
| (ii) 只去 b 槽 metadata | **0（≤64 KiB）** | 丢 A/B 回滚；本包 b 槽与 a 槽共享 extent |
| (iii) 缩 FS 到最小 | **−0~44 MiB** | 必须重建分区；`resize2fs -M` 单独用无效 |
| 重新 sparse 化 | **−48.43 MiB（0.33%）** | 无内容风险，但收益可忽略 |
| **额外杠杆（本轮只做小样本）**：只读分区从 ext4 换 **EROFS + lz4hc** | `system_dlkm` 样本 **11.94 MB → 7.39 MB（61.9%）** | `mkfs.erofs` 已在主机；需主线内核 `CONFIG_EROFS_FS`（odem 侧 Waydroid 容器无关）。全量换算要下一轮实测，若 62% 成立则 14.5 GiB → **≈9.0 GiB**，叠加去预装后 **≈5 GiB** |

> 换句话说：**在这个包格式下，"只删 APK"不会改变任何一个字节的待刷文件**；能变的只有
> "删内容 → 用 `mke2fs`/`mkfs.erofs` 重建分区 → `lpmake` 重打 super → 重新切片/打包"这条完整链路。
> 当前 8 段 raw 文件已经是"只含非零已用块"的形态，压缩率已经没有空间。

---

## 5. E：产物与重生成方法

```
scripts/android-super.py           # list / size / extract / assemble（本文所有表都出自它）
scripts/android-super-scan.py      # magic 扫描（含 checksum 校验）+ 覆盖/空洞分析

out/android-super-20261118/
  super-90504.img                  23,622,320,128 B 表观 / 14.5 GiB 实占（8 段按 XML LBA 组装 + 补到 device size）
  extract/lpunpack-slot0/          14 个分区镜像，14.9 GiB（lpunpack 官方实现产物）
  roundtrip/（空的，镜像已删以省盘）  重打命令见下，8 s 重生成；比对输出 logs/roundtrip-compare.txt
  walk_ext4.py                     debugfs 递归遍历小工具（生成 ext4-inventory.tsv）
  logs/  scan.txt scan.json our-list-*.txt our-size-slot{0,1,2}.txt lpunpack.log lpmake.log
         e2fsck-*.log ext4-usage-table.txt ext4-inventory.tsv debloat-*.log artifacts.txt
  lpdump.txt                       元数据 dump（早期草稿，内容与 logs/our-list-* 一致）
```

磁盘占用合计 **30 GiB**（`du -sh out/android-super-20261118`；lpmake 重打件 14.5 GiB 为省盘已删，8 s 可重生成）。**全部可删后重生成**：

```bash
# 1) 组装（~27 s，得到 14.5 GiB 实占）
python3 scripts/android-super.py assemble \
  --xml backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml \
  --label super --pad-to-device -o out/android-super-20261118/super-90504.img
# 2) 解包（~19 s）
lpunpack out/android-super-20261118/super-90504.img out/android-super-20261118/extract/lpunpack-slot0
# 3) 重打（~8 s）
lpmake -d 23622320128 -a 524288 -O 491520 -m 65536 -s 3 --virtual-ab \
  -g qti_dynamic_partitions_a:23618125824 -g cow:0 \
  -p odm_a:readonly:1650688:qti_dynamic_partitions_a -i odm_a=extract/lpunpack-slot0/odm_a.img \
  ...（其余 13 个分区同形，完整命令行见 logs/lpmake.log 对应 history） \
  -o out/android-super-20261118/roundtrip/super-lpmake.img
```

工具自检（三个子命令都在官方段/组装件上跑通）：

```bash
python3 scripts/android-super.py list  backup/official-rom-15.10.259/super_1.img          # 元数据表
python3 scripts/android-super.py size  out/android-super-20261118/super-90504.img          # 额度
python3 scripts/android-super.py extract out/.../super-90504.img /tmp/x --partition odm_a  # 抽取
```

---

## 6. 未解决疑点（需下一轮或需设备/原厂件）

1. **3.0 MiB 空洞是"零"还是"被 repacker 漏掉的真数据"**（唯一影响正确性的点）。
   判据分叉：
   - 若空洞在设备上是零 ⇒ 完全无损，包可直接当干净刷写件；
   - 若空洞非零 ⇒ 这 8 段只适合**覆盖刷**（不擦 super 直接写，未列 LBA 保留旧值），
     **先 `erase super` 再刷会把 `vendor_a` 写坏**。
   实测倾向"非零"：`e2fsck -fn` 显示 `vendor_a` 的 inode 41/47/53 的 extent 节点块
   4053/4068/4090 落在空洞 4（fsblock 3959..4095）⇒ 全零；`system_a`/`product_a` 的 e2fsck 干净（rc=0）。
   一个 ext4 的 extent 树节点不可能本来就全零，所以**更可能是漏了真数据**（除非原厂 vendor 镜像本身有缺陷）。
   取证办法（需设备或原厂 super.img，本轮禁止碰设备）：只读 6 个空洞区间的字节
   （即上表"绝对字节偏移"，每段 4 KiB 读一次），若非全零即可定案。
2. **`metadata_slot_count=3` 的语义**：A/B 设备通常是 2；这里 3 个 slot（0=a 活、1=b、2=旧出厂态）。
   需要确认 bootloader 选槽规则（`slot 2` 是否只在两者都坏时回退），影响"能否安全删 slot 2 metadata"（至多省 64 KiB，不建议动）。
3. **b 槽共享 extent 是否合法/可长期使用**：`system_a`/`system_b` 指向同一批物理 extent，OTA 到 b 槽时
   必须靠 snapshot（COW）写新数据；这解释了为什么包里有 7 个全零 COW 卷。若我们要做"可 OTA 的精简包"，
   必须一并保留 COW 卷与 `UPDATED` 属性（`lpmake` 不支持 `UPDATED`，要自己写 metadata 或走 OTA 流程）。
4. **EROFS 换算率**只有单样本（`system_dlkm` 61.9%）；`system_a`/`vendor_a` 含量大、含 dex/oat/vdex，
   压缩率可能更高也可能更低，需要全量实测（`debugfs rdump` 全树 + `mkfs.erofs -zlz4hc`）。
5. **`lpmake` 本 build 不支持 `-D/-n`**（写成 `-a/-O` 也没落进 block device 表），所以原地增长用的
   `alignment_offset=491520` 无法原样复现；若后续要在设备上 `fastboot flash super` 再 `resize`，
   需要带 `-D super:23622320128:524288:491520` 的新版 lpmake。
