# 安卓 a 槽：H5 三发对照（2026-11-21 下午，上机，全部失败且现象一致）

> 判据口径：用户目视 + 设备侧只读态 + 主机侧 `adb`/`fastboot`/`lsusb` 采样（每 6 s 一次，每发 4 min）。
> 结论先行：**H5（`vbmeta_a` 自签是变量）排除；`/data` 文件系统类型也是排除项；三发失败现象逐字相同**
> ⇒ 剩下的解释只能是 a 链/super 内容层（H2）或仍在 ramdisk 之后早段（H7 未排除）。
> 本轮按用户裁决「这条路走不通，总结进度，暂不继续」收口；不做第 4 发。

## 0. 三发对照表

| 发次 | `vbmeta_a` | `/data` | 结果（用户目视） | 回落 |
|---|---|---|---|---|
| ① 14:19 | 原厂 `55929c15…`（flags=0 ⇒ **verity on**） | ext4，只有 `lost+found`（11-19 21:16 建，Android 从未写过） | BL 警告 → 黑屏 → **安卓系统崩溃警告** → 联想 logo 一闪 → 黑屏 → Linux | 自动回 `_b` |
| ② 14:2x | 原厂 `55929c15…`（同上） | **f2fs 空**（`mkfs.f2fs -f -O extra_attr,inode_checksum,sb_checksum`，262910 MB discard） | 与 ① **逐字相同** | 自动回 `_b` |
| ③ 14:2x | 自签 `419e01ac…`（flags=1 ⇒ **verity off**） | f2fs 空（同 ②） | 与 ①② **逐字相同** | 自动回 `_b` |

⇒ 两个单变量（`vbmeta_a` 的 verity 位、`/data` 的 fs 类型）都**不能**改变结果；`/data` 至今仍是空 f2fs、`/metadata` 仍是 Android 6.6 建的有效 f2fs（`dump.f2fs` 可读、checkpoint state = unmount）。

## 1. 设备侧硬事实（每发后现读）

```
qbootctl          → SLOT _a: Active 0 / Successful 0 / **Bootable 0**   （失败后 ABL 自己把 a 标成不可启）
                    SLOT _b: Active 1 / Successful 1 / Bootable 1
Current slot: _b  （ABL 回落并把我方 -s a 的 active 改回 b）
pstore            → 空 ⇒ **无内核 panic**（失败发生在 kernel 之后：ramdisk / 上层）
vbmeta_a 读回      → 419e01ac…（= 第三发写入值，已复原到今天开始前的状态）
userdata          → TYPE="f2fs" UUID=fcf01c4d…（我方 mkfs 后 Android 未再格式化）
```

`vbmeta_a` 三份件的 AVB 顶层 `flags`（`d[120:124]` 大端现读）：

| 文件 | flags | 语义 | sha256 |
|---|---|---|---|
| `backup/official-rom-15.10.259/vbmeta.img` | `0x0` | verity **on** | `55929c1580d437ad…` |
| `logs/forensics-20261120-2210/vbmeta_a.img` | `0x1` | verity **off** | `419e01ac8af7345e…` |
| `out/vbmeta-a-flags3/vbmeta_a-flags3-copy-b-20261110.img` | `0x3` | verity+verification **off** | `e974ebab2e59…` |

> 因此「H5 = 写回原厂 `vbmeta_a` 看是否进桌面」这个问法本身有 confound：原厂件把 verity 打开，
> 而我们的 `super` 是自建 v1（`vbmeta_system_a` 仍是原厂），验证必然失败。所以第三发补上了
> 「verity off + 干净 f2fs」这组**本该先做**的对照 —— 仍然同样失败。

## 2. 被本轮排除 / 仍存活

| 假设 | 本轮结果 |
|---|---|
| H1 ABL 自己选 `recovery_a` | **弱化**：用户看到的是「安卓系统崩溃警告」而不是 recovery 菜单；但仍是目视判读，非日志 |
| H3 `misc`/BCB 残留 | 排除（前轮已清 + 本轮三发 `misc` 头 4 KiB 全 0） |
| H4 `metadata` | 排除（前轮 S2 实测 no-op；本轮 `dump.f2fs` 显示 metadata 干净可读） |
| **H5 `vbmeta_a` 自签** | **排除**（三发对照，flags 0/1 结果相同） |
| **H6a `/data` 是 ext4 不是 f2fs** | **排除**（②③ 用 f2fs 仍同样失败） |
| H6b `/data` 内容/OOBE 状态 | 未验证（`/data` 现在就是干净 f2fs，等价于「Android 自己格式化过」的条件） |
| **H2 `super` 内容（v1 slim）** | **存活（当前最强）**：a 槽在机 `super` = v1（`system_a` 5296 MiB，删过 `/system/preinstall`），11-18 两发 `boot_completed=1` 是**在旧 `/data` 上** |
| H7 观测 confound（ramdisk 早段失败被读成 recovery） | **存活**：`pstore` 空 = 无 kernel panic，失败点必在 ramdisk/上层；「崩溃警告」具体是 ramdisk 的 `boot_failure` UI 还是 framework 的 ANR 崩溃屏，**没有日志证据**，只有目视 |

## 3. 本轮附带确立的两条**工具事实**（对后续所有设备工作有用）

1. **`qbootctl -s <slot>` 从 Linux 可直接切槽**：`qbootctl -s a` → rc=0、打印 `SLOT 0: Set as active slot`、
   `qbootctl -a` 读回 `_a`；三发皆如此。⇒ 切槽**不需要物理键**。
   `PITFALLS #701` 里「Linux 侧无法切槽」的说法应限定为 **`-u`（标 unbootable）** 那条会失败
   （`gpt_disk_commit: Invalid args`），`-s` 可用。
2. **分区可以在 Linux 侧直接 `dd` 写，并用 `dd` 读回校验**（本轮 `vbmeta_a` 写回就是这么做的：
   写前 `55929c15…` → 写后读回 `419e01ac…` 与主机件逐字节一致）。⇒ 只要不涉及「让 ABL 重新认件」
   的场合（如换 `boot_*` 后需要 ABL 重新验签/回读），**不必为了一次写去抢 fastboot 窗口**。

## 4. 材料与方法（可复现）

- 原厂 `recovery_a` 的 `system/etc/recovery.fstab`（解包自 `backup/official-rom-15.10.259/recovery.img`，
  sha `3807dd63…` = 在机 `recovery_a`）：带 `formattable` 的**只有** `/dev/block/bootdevice/by-name/metadata`
  与 `/data`（userdata）两项；`system/vendor/product/odm/system_ext` 全是 `ro` + `logical`+`slotselect`；
  `boot`/`misc` 只是 `emmc defaults`（可挂载，非 formattable）。⇒ **恢复模式的「双清」作用域 = userdata + metadata，
  不含 `linux17`、不含 `boot_b`、不含 `super` 的物理分区**（这一条回答了用户「双清会不会误伤 Linux」）。
- 解包方法：boot header v4（`header_size=1584`）→ ramdisk 在 **offset 4096**、legacy LZ4 帧（magic `0x184c2102`，
  按 `[u32 size][block]` 逐块解），再 `cpio -idmu`。主机 `python-lz4` 原缺，本轮 `pip install --user
  --break-system-packages lz4` 装上；设备侧 `f2fs-tools` 由 `apt install` 装上（`mkfs.f2fs`/`dump.f2fs`）。
- 采样脚本行为（每发）：`adb devices` / `fastboot devices` / `lsusb | grep -ciE '05c6|18d1'` 每 6 s 记一行，
  共 4 min，落 `logs/h5-a-slot-20261121/observe.log`。三发期间 USB 始终 `usb=0`（Android 侧 gadget 未枚举），
  故 adb 取证不可用 —— 这也是「只能靠目视」的原因。

## 5. 若将来重启这条线（不在本轮执行）

按代价从低到高，三选一（都需要用户给窗口/裁决）：

1. **S3 原厂 `super` 对照**（14.5 GiB 写 ≈ 6–12 min，需 EDL）：能一次分开「H2 = 我们的 slim super」与「a 链缺件」。
2. **把目视换成日志**：造 `console=ttyGS0` 的 `boot_a` 件（件已在 `out/android-v3-bringup-20261120/boot-ttygs0-boot.img`），
   上机期用 `/dev/ttyACM*` 抓 ramdisk 输出 —— 但三发 USB 都没枚举，**该方法在本机可能同样拿不到通道**，
   要先解决「a 槽 USB 不枚举」。
3. **放弃 Android a 槽**：若确认不再需要安卓共存，则按 `reports/disk-reclaim-20261121.md` §2 的解冻判据回收
   B 档 ~42 G（`super` 22 GiB + `userdata` 256 GiB 大头），Linux 侧完全不受影响。

## 6. 一句话

三发同现象 ⇒ **a 槽失败与我们能改的那两个单变量（`vbmeta_a` verity 位、`/data` fs 类型）无关**；
在没有日志通道的前提下继续盲试的期望收益很低，故本轮在此收口。
