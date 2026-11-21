# B 档回收执行与「37 G 待解冻」精算（2026-11-21）

> 工作面来自 `TASKS/README.md` §4「P2 B 档 ~42 G 回收」与 `reports/audit-20261119/A6-*`。
> 结论先说：**42 G 里 37.0 G 是四件 `pending`（实验材料，禁删）**，它们的解冻判据 = 安卓 a 槽
> S3 结论（同一轮派了只读 lane 在做）。本轮能安全回收的只有 **399 MiB**，已回收并记账。

## 0. 数字（`du -sm` 实测，2026-11-21 10:0x）

| 项 | 大小 | 状态（`versions/out-artifacts.tsv`） | 本轮处置 |
|---|---|---|---|
| `out/android-slim-v3-20261119` | **28 G** | **pending**（唯一 final 造件，首启判据未取得） | **不动** |
| `out/android-min-20261118` | **8.5 G** | **pending**（S1/S3 的 v1 对照件） | **不动** |
| `out/android-slim-v2b-20261119` | 1.1 G | **pending**（S4 二分件） | **不动** |
| `out/android-v3-bringup-20261120` | 203 M | **pending**（S2/S5 上机件） | **不动** |
| 合计「待解冻」 | **≈ 37.0 G** | — | 等 a 槽判据 |
| `out/stage-debian` | 135 M | superseded（`stage.sh` 可重生） | **已删** |
| `out/modstage-vk163` | 89 M | superseded（模块 staging，可重生） | **已删** |
| `out/modstage-vk172` | 94 M | superseded | **已删** |
| `out/p2-minbase-20261118` | 82 M | superseded（`min-restore` 的真超集） | **已 mv** → `backup/out-history-20261121/` |
| **本轮净回收** | **399 MiB** | `out/` 44 036 → 43 637 M | — |

磁盘：`/` 697 G 用 / **194 G 空闲**（79%）⇒ 空间**不紧张**，B 档的价值是账目正确而不是救急。

## 1. 为什么 37 G 不能现在删（判据，不是保守）

四件 `pending` 全部是**同一台设备窗口实验的输入**：

1. `android-slim-v3` = 待验的 final super（S3 要拿它和原厂 super 对照才能分出 H1「ABL/槽位机制」 vs
   H2「v3 slim super 内容」）。
2. `android-min` = v1 造件（S1 复现「v1 在机」、S3 的现态基线）。
3. `android-slim-v2b` = S4 二分件（S3 若指向 super 内容，这一步是唯一能把问题缩到具体池/包的路径）。
4. `android-v3-bringup` = S2 原厂 `metadata` 28 MiB + S5 两件取证件（`console=ttyGS0` boot/vendor_boot v4）。

删任一件 ⇒ 设备窗口要重造（v3 = 7409 MiB super 重建 + EDL 写入读回校验，约 1–2 h），
而设备窗口是**唯一稀缺资源**（进 fastboot 只能物理键，`PITFALLS #701`）。

## 2. 解冻判据（一条命令级判据，判到就走）

**解冻条件 A（首选）**：a 槽首启成功（真 Android 起、`adb` 到 launcher）⇒ 四件全部 `verified`，
`android-min` / `android-slim-v2b` 转 `superseded` 可删，`slim-v3` 转 `verified` 保留 → 立即回收 **9.6 G**。

**解冻条件 B（次选）**：S3 结论 = H2（v3 内容问题）⇒ `slim-v3` 与 `v2b` 保留做修版，删 `android-min`（8.5 G）。

**解冻条件 C（最差）**：S3 结论 = H1（ABL/槽位机制，super 无关）⇒ `android-min` + `v2b` 可删（9.6 G），
`slim-v3` 转 `verified` 保留作日常安卓件。

判据落地方式：a 槽 lane 的 `reports/android-a-slot-s2s3-execplan-20261121.md` 出结论后，
按本办法改 `versions/out-artifacts.tsv` 三行状态 + 跑 `scripts/out-status.py --check`，然后删。

## 3. 仍需用户拍板（A6「必须先问」四项，本轮未动）

| 项 | 大小 | 问题 |
|---|---|---|
| `reports/artifacts/slotattr-20261119/full-image.bin` | **4.0 G** | 2026-11-19 slotattr 实验的设备分区整读回；设备态已变，留档（移 backup/）还是删？ |
| `backup/git-history-rewrite-20261112` + `git-slim-20261113` | 2.0 G | 不在 `versions/backup-manifest.tsv` 台账；`.git` 本体健在 |
| `dl-cam/vendor-cam-l1d.img` | 256 M | C1 相机线供体件，仓内无脚本引用 |
| `backup/boot_a-pre-uefi-20261108.img` | 96 M | `backup-manifest.tsv` 已标 DELETE（与 `stock-259/boot_a.img` 同 sha） |

四项合计 **6.4 G**，都是「留档 vs 删」的取舍，不是技术判断题。

## 4. 附：本轮为何没走 `scripts/out-archive.py`

`out-archive.py` 是 **mv 到 `backup/out-history-*/`**（同文件系统）⇒ **净释放 0**，账目正确但不回收空间；
它适合「历史镜像必须留本体」的场合。本轮 `p2-minbase` 走的就是这条路（留本体），
三个 staging 目录则是**纯可再生中间物**（`rootfs/debian/stage.sh`、`build-kernel.sh` 重跑即得），
故直接删 + 在账本里写明重生命令。
