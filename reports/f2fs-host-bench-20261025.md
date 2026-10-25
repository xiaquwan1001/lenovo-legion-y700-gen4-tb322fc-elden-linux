# f2fs 主机 loop 台架 + discard 能力实测（G1，2026-10-25）

> 前置：`reports/g0-fstype-zero-write-20261025.md`（`/init` 已能自动探测 fstype，真机验证过）。
> 本轮：**零设备写盘**。台架在主机 `/var/tmp` 的 6 GiB **4096 B 扇区 loop** 上跑（与设备 `logical_block_size=4096` 对齐），
> 设备侧只做**只读**能力查询。脚本 `scripts/f2fs-host-bench.sh`（可重跑，root 仅用于 losetup/mount）。

## 0. 结论

1. **10-21 报告里唯一的【未证实】项现已【已证实】= 本机 UFS 支持 UNMAP/discard**：
   `discard_max_bytes=34 359 734 272`（32 GiB）、`discard_granularity=4096`、`lsblk -D` 的 `DISC-GRAN 4K / DISC-MAX 32G`，
   且 `logical_block_size=physical_block_size=4096`（原生 4K，无 512e RMW 惩罚）⇒ `mount -o discard` 可用。
2. **4K 随机写 + fsync 是 f2fs 的真实收益**：`1288 IOPS` vs ext4 `647 IOPS` = **2.0×**（与 FAST'15 的「最多 2×（SQLite）」同量级）。
   这正是我们要跑的形状：`apk upgrade`、Waydroid 的 SQLite、phosh 设置写入。
3. **顺序写付出 ~20% 代价**（5044 → 3953 MB/s）。在 UFS 上（实测瓶颈远低于此）这 20% 大概率被存储本身吃掉，**不作为否决理由**，
   但要在真机上复核一次顺序写。
4. **93% 利用率没有出现 GC 悬崖**（1303 IOPS ≈ 空盘 1288）——**不等于**「高利用率安全」：f2fs 默认 `reserve_root≈12.5% of user blocks`
   把可用空间先扣住了，所以「df 显示 93%」对 f2fs 而言尚未触到它的 97.5% 死区。**运维口径仍要求 <85%**。
5. **fsck.f2fs 比 e2fsck 慢 ~5×**（163 ms vs 33 ms @6 GiB）。6 GiB 上无所谓，但 150 GiB 根分区要评估开机 fsck 时间窗。

## 1. 台架结果（原始数据 `out/f2fs-bench/result.tsv`）

| 配置 | 顺序写 1 MiB | 4K randwrite + fsync/8 | 2000×4K 元数据 | 93% 后 4K+fsync | fsck |
|---|---|---|---|---|---|
| ext4（noatime） | **5044 MB/s** | 647 IOPS | 95238 IOPS | 649 IOPS | 33 ms（e2fsck） |
| f2fs（noatime） | 3953 MB/s | **1288 IOPS** | 95238 IOPS | **1303 IOPS** | 163 ms |
| f2fs（noatime,discard,gc_merge） | 4145 MB/s | 1282 IOPS | 117647 IOPS | 1304 IOPS | — |

- 全部 `direct=1`（绕 page cache），每格 = 一次 fio job；`r4k_fsync` = `--rw=randwrite --bs=4k --fsync=8 --size=256M`。
- 「93% 后」= 每个配置各自 `dd` 填到 93%（三份 `df` 记录在 `out/f2fs-bench/df-*.txt`）再重跑同一 job。
- 元数据一格的 95238/95238 相同 ⇒ **该指标触到测量地板（2000 个文件瞬间完成），不可用于比较**，保留只为说明「没有反向证据」。

## 2. 三处必须记住的边界（不许把 loop 数搬到 UFS）

1. **loop on NVMe ≠ UFS**：NVMe 队列深、无 FTL GC；UFS 有内部 GC + 写放大。本表只回答「同一内核/同一工具链下 f2fs 相对 ext4 的方向与量级」。
2. **`fsync=8` 不是 SQLite**：真实 SQLite WAL 是「多写 + 单 fsync 提交」，f2fs 的优势可能更大（WAL 顺序 + 检查点），需真机 App 侧再验。
3. **fstrim 返回 0 B 不是失败**：`discard` 档写 128 MiB → 删除 → `sync` → `fstrim -v` 仍报 `0 B 已修剪`。
   f2fs 的 FITRIM 只修剪**空闲 segment**，刚删的数据要等 GC/checkpoint 才进空闲段 ⇒ 「0 B」是 f2fs 语义，不是 discard 不通。
   discard 通路的硬证据在别处：loop 队列 `discard_max_bytes=4294966784`、设备侧 32 GiB、`mount -o discard` 无告警。

## 3. 参数定案（进 f2fs 迁移配方）

```fstab / mount 选项：  noatime,discard,gc_merge
mkfs：                  mkfs.f2fs -l linux17 <dev>        # LABEL 必须保留：cmdline 用 elden_root=LABEL=linux17
内核：                  CONFIG_F2FS_FS=y + XATTR + POSIX_ACL（在机 7.3 树已满足，无需改）
```

明确**不做**：
- ❌ `checkpoint=disable`（意外关机回滚 + 必须 GC，根分区禁忌，`f2fs.rst:282-289`）；
- ❌ `nobarrier` / `reserve_root=32768` / `inlinecrypt` 等 Android `/data` 参数照抄（那是 metadata 加密卷的配方）；
- ❌ `resize.f2fs -s` 缩容（ZUXOS 不认，`PITFALLS` 已记，会 bootloop）。

对账确认（本轮实测，非引述）：
- `mkfs.f2fs 1.16.0`、设备侧 `f2fs-tools 1.16.0-r4`、内核 7.3-rc7 ⇒ **同代，无「mkfs 新/内核旧」风险**；
- `blkid -L linux17 -o device` 能定位 f2fs 卷、`-o value -s TYPE` 返回 `f2fs` ⇒ 迁移路线依赖的 LABEL 定位成立；
- `fsck.f2fs -f` 干净退出（rc=0）。

## 4. 下一步（按顺序）

1. **入口收敛**（`/init` 与 `local.d` 对 5 个后台脚本的双启）：换 init 前必做，已在本轮之后立刻进行。
2. 真分区手术：二选一 —— **A 并存**（离线缩 ext4 + 尾部新建 f2fs；需给 `gpt-surgery` 加「缩 linux17」能力 + ramdisk 补 `resize2fs`）
   或 **B 原地换**（归档 → RAM 根 `mkfs.f2fs -l linux17` → 解包）。两者都需要设备在场与用户批准。
