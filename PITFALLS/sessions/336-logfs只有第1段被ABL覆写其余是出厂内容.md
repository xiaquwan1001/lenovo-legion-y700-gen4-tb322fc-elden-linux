# #703 `logfs` 只有第 1 段会被 ABL 覆写，seg1+ 全是出厂内容 —— 拿它当「本次启动」证据会把归因全做反

- 日期：2026-11-21（lane C 只读取证 + 主会话独立复核）
- 状态：**已复核**（我在主机上重跑了逐段 sha 比对，结果与 lane 一致）

## 现象与判据

设备在机 `logfs` 分区 = `probe-logfs` 10 段环形缓冲的**错觉**：实际只有 **segment 0** 会被 ABL 重写，
`seg1..127` 与**出厂包**逐段字节相同。

```
# 判据（主机侧，8 MiB 分区 + 出厂包 backup/official-rom-15.10.259/logfs_ufs_8mb.bin，段 = 512 KiB）
logfs.bin  / logfs2.bin / logfs3.bin（11-20 三次 dump）
  seg 0      : 与出厂包不同（本次启动写在这）
  seg 1..12+ : 与出厂包 **sha 逐段相同**
```

原始结果：`same segs: [1..12] diff segs: [0]`（三份 dump 一致）。
出厂包 `strings logfs_ufs_8mb.bin | grep 'Start EBS'` 能直接看到 `13263/13302×2/13304×2/13307/13309/13311`，
以及 **9 条 a 槽启动记录**、`Booting Into Mission Mode`、`factory_build = 1`、`UEFI 6.0.250606`（2025-06-06 出厂固件，
现固件 `6.0.260611`）。

## 被这条推翻的结论（逐条，含原判据的错误所在）

| 旧结论 | 错在哪 |
|---|---|
| 「每次 a 槽启动都到 `Shutting Down UEFI Boot Services`（≈13.3 s）⇒ **ABL 清白**」（11-19） | 那条 EBS 时间来自 **seg≥1 = 出厂** |
| 「EBS **13311** 与 11-19 三发同族 ⇒ 失败在 EBS 之后」（11-20/11-21） | 同上；`13311` 是出厂包里的一次历史记录 |
| 「logfs 显示 `Loading Image recovery_a` / `Booting from slot (_a)` ⇒ 落 recovery」（#702 第 1 条证据链） | `Loading Image <part>` 是**每次任务启动的头部探测**（b 槽也有 `recovery_b` 同款），真 recovery 会打 `Recovery:1` + `Booting into Recovery Mode via Boot`；而 `A 槽` 那几行本身在出厂包里 |
| 「`logfs` 对最近启动根本不写」（#594/#597/#602 一带的旧争论） | 方向对、原因错：**只写 seg0**，不是不写 |

## 判据式纪律（以后必须照做）

- **(1)** **`logfs` 只信 seg0**（偏移 0..512 KiB）；要看 seg≥1 先与该机型出厂包逐段 sha 比对，
   相同即**出厂遗留**，不得引用。
- **(2)** 归因「某次启动失败在哪一步」必须有三条同时成立才写进文档：
   ① 证据来自 seg0 或本次启动×cmdline/`pstore` 等**本次产生**的件；
   ② 与出厂包**不同**（sha 判据）；
   ③ 有时间锚（本次 boot 的 uptime/rtc/`androidboot.*` 命中）。
- **(3)** 出厂包不是噪声源而是**必须先建基线**的参照物：本机 = `backup/official-rom-15.10.259/logfs_ufs_8mb.bin`
   （固件 `6.0.250606`）；升级固件后要重取。

## 顺带复核到的三条现态（同日实读，不是推断）

| 事实 | 判据 |
|---|---|
| 在机 `super` = **v1**（不是 v3） | 设备 super 头 4 MiB sha `d516ae04f7f3efac…` = `out/android-min-20261118/pkg/super_min.img` 头 4 MiB（v3 件为 `f7c8a9801c0fc013…`）⇒ 不等 |
| a 链除 `vbmeta_a` 外**全是原厂** | boot_a `b428a31d` / vendor_boot_a `326d5c32` / init_boot_a `e8206b81` / recovery_a `3807dd63` / vbmeta_system_a `910e013b` = 出厂；只有 `vbmeta_a` = `419e01ac…` ≠ 原厂 `55929c15…` |
| 在机内核 = **vk189** | `uname -r` = `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（多个文档写的「现役 vk192」是编号混用，见 `versions/vk-registry.tsv`） |

## 处置

- 判别顺序改为：**H5（刷原厂 `vbmeta_a`，10 min，需物理键）→ 落点当场取 seg0 `logfs` + cmdline** →
  S3（原厂 `super` 对照，14.5 GiB）降级为对照实验。全账 = `reports/android-a-slot-laneC-20261121.md`。
- 证据件：`logs/a-slot-analysis-20261121/{super-head4M.bin,super-tail4M.bin,misc-64k.bin,device-forensics.txt,SHA256SUMS.txt}`。
