# 安卓 a 槽 lane C：机制重判 · 材料核实 · 设备只读取证 · 执行单 · 脚本复核（2026-11-21）

> 只读 lane。**零设备写入**（无 flash/qdl/EDL/reboot/qbootctl 写）。设备 = U2 **HA2EXB0E**，现态
> `active=_b`、Linux 在机（`7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）、`graphical.target` active。
> 姊妹件（同轮并行写出，不互相覆盖）：`reports/android-a-slot-mech-rejudge-20261121.md`（A 详证）、
> `reports/android-a-slot-materials-20261121.md`（B 详证）、`reports/android-a-slot-s2s3-execplan-20261121.md`（D 详证）。
> 本文件 = **lane C 自己的判据 + 两处硬校正 + 一页执行单**；与上述三件的差异在 §0.3、§A.1 明确标注。

---

## 0. 数字结论（先看这 6 行）

| # | 结论 | 硬证据（命令 + 原始值） |
|---|---|---|
| 1 | **`logfs` 不是 10 段环形日志，只写第 1 段**：`logfs` 8 MiB 里 **offset 0..63 KiB 之外的 9 段，与出厂包 `backup/official-rom-15.10.259/logfs_ufs_8mb.bin` 逐段 sha 完全相同**；第 10..127 段全 0 | `sha256(seg[i])`：`now=[e6a99e61,5ce4b3c5,ecb774f9,c81b37fa,482e794e,06120e2c,13b8d050,9fb338f2,80fbceb9,1b869bcb]` vs `shipped=[fe6ff617,5ce4b3c5,…,1b869bcb]`（仅 seg0 不同） |
| 2 | ⇒ **那 9 条「a 槽 + `Booting Into Mission Mode` + `factory_build = 1`」记录是出厂遗留**（`UEFI Ver 6.0.250606` / `Loader Build Jun 6 2025`），**不是**我们任何一发 a 槽实验；现固件是 `6.0.260611` / `Jun 11 2026` | `logfs-decode.py --segment 1 \\| grep UEFI Ver` → `6.0.250606…`；`--segment 0` → `6.0.260611…` |
| 3 | ⇒ 被广泛引用的「EBS **13311** ms 与 11-19 三发 13302/13307/13263 同族 ⇒ 失败在 EBS 之后」**不成立**：这些数字全都出现在**出厂包**里 | `strings logfs_ufs_8mb.bin \\| grep -oE 'Start EBS +\\[ *[0-9]+\\]' \\| sort \\| uniq -c` → `13263/13302×2/13304×2/13307/13309/13311/3155/4085` |
| 4 | **a 槽在机件除 `vbmeta_a` 外全是原厂逐字节**：`boot_a b428a31d…`、`vendor_boot_a 326d5c32…`、`init_boot_a e8206b81…`、`recovery_a 3807dd63…`、`vbmeta_system_a 910e013b…`；**`vbmeta_a 419e01ac…` ≠ 原厂 `vbmeta.img 55929c15…`** | `dd if=/dev/disk/by-partlabel/<p> bs=1M iflag=direct \\| sha256sum`（全表 `logs/a-slot-analysis-20261121/device-forensics.txt`） |
| 5 | 在机 super = **v1**（`system_a 5296 MiB`、7 个 `_a` 逻辑分区、首 512 KiB sha `67ff7604…`）；BCB 干净；`boot_a` 属性 = `0x32`（retry 6 / succ 0 / unbootable 0） | `android-super.py list super-head512k.bin`；`misc` 64 KiB 只有 5 个非零字节（`0x8000`=`02 b0 0a 74 56`）；`slot-attr.py show` |
| 6 | **本轮修掉 2 个 fail-open 脚本缺陷**（dry-run 会真读设备 128 MiB 并打印「hit=0 = 干净」；dry-run 会打印「原厂 super 能进桌面」的结论行），已复跑验证 | `--dry-run --step S3` 现输出 `[dry] 跳过 pstoredump 抓取` + `[dry] 结论行省略` |

### 0.1 「ABL 为什么选 recovery_a」——问题本身要改写

`Loading Image recovery_a … Image size : 4096 Bytes` 是 ABL **每次任务模式启动都做的头部探测**：
b 槽启动时同样打印 `Loading Image recovery_b`（`logs/a-slot-analysis-20261121/device-forensics.txt` 同批 logfs seg0）。
真正的 recovery 启动会打印 `Recovery:1` + **`Booting into Recovery Mode via Boot`**（判据件：
`logs/device-s1-113527/logfs.bin` seg0 = b 槽 recovery 实况）。
⇒ **在现有全部真记录里，没有一条是我们 a 槽启动的 ABL 日志**，所以「ABL 选 recovery_a」既未被证实、也未被证伪，
**它目前是无证据命题**（§A 的 H1 归入「无样本」，不归入「已排除」）。

### 0.2 现在最缺的一件事（不是 S3）

**落 recovery 后第一件事 = `dd logfs 64 KiB`，否则下一次启动立刻覆盖**（这是 §A 唯一能一次分开 H1/H6/H7 的观测）。
脚本已机械化（`observe_android` 的 recovery 分支），但**上一发（`logs/android-v3-S1-20261121-091754/`）没取到**这份 logfs。

### 0.3 与并行姊妹件的两处口径差

1. 姊妹 A 件把「9/9 Mission Mode」当作 H1 的**反证**；本 lane 更正为：这 9 条 = 出厂遗留（§0.1），**只能当"原厂 a 槽任务启动长这样"的样板**，不能当反证。H1 仍是**无样本**。
2. 姊妹 A 件把 `/metadata` 被写过 + `/data` 从未挂载当主推（H6）；本 lane 同意这是**当前最省成本的前置**，但机制上还差一环（§A H6 行：`IsRecoveryMode()` 只能是 ramdisk 里有 `/system/bin/recovery`，而 a 链两个 ramdisk 都没有，故 `/data` 路径若要落 recovery 必先经 AOSP `do_mount_all → reboot_into_recovery(--prompt_and_wipe_data)`，那会**再启动一次**并留下 `Recovery:1` 记录 —— 这正是 logfs 必须当场取的原因）。

---

## A. 机制重判：候选假设 / 预测 vs 已观测 / 最小判别实验

**观测基线（本 lane 唯一可信的四条硬事实）**
① a 链件除 `vbmeta_a` 全原厂（§0-4）；② 在机 super = v1；③ misc 头 4 KiB 全 0（BCB 干净）、`boot_a` 属性可启；
④ **没有一发我们自己的 a 槽 ABL 日志**（§0-1/2），所以「落 recovery」只有一次一手的感官/`adb devices` 观测（`091754/observe.log`：`state=recovery` + `adbd SIGABRT`）。

| 假设 | 一句话 | 预测的观测 | 已观测 | 能区分它的最小实验 | 判定 |
|---|---|---|---|---|---|
| **H1** | ABL 槽位/recovery 机制：`--set-active=a` 后 ABL 自己走 recovery（or 直接启 `recovery_a`） | 真 logfs 出现 `Recovery:1` + `Booting into Recovery Mode via Boot`；`Loaded Partition: recovery` | **无我们自己的 a 槽 logfs 记录**（全部 9 条是出厂 6.0.250606 遗留） | 落点当场 `adb exec-out dd if=/dev/block/by-name/logfs bs=4096 count=64`（**下一发必须做**）；脚本已自动 | **无样本（未证伪）** |
| **H2** | super 内容问题（v1/v3 slim 不可启） | 原厂 super 能起、我们的不能 | 在机就是 v1，而 v1 曾在旧 `/data` 上两发 `boot_completed=1`（`reports/android-slim-v2-20261119.md`） | S3（原厂 super 对照，14.5 GiB）；但要先排除 H6/H7，否则 S3 失败也无法归因 | **弱化（有反例）** |
| **H3** | misc/BCB 残留指令 | `misc[0:32]` 非 0 | 64 KiB 里仅 5 字节在 `0x8000`（非 BCB 区）；头 4 KiB 全 0；11-21 09:19 又 `fastboot flash misc` 4 KiB 零过 | 已足够 | **排除** |
| **H4** | metadata 被 erase/不一致 | 原厂 metadata 在机仍失败消失 | S2 已在 2026-11-20 20:26 实跑：**写前件 = 写后件 = 原厂 `a735fbc7…`（no-op）**，a 槽仍失败 | 已足够 | **排除（S2 是 no-op）** |
| **H5** | `vbmeta_a` 自签（flags=1）/rollback 索引 | AVB 失败 ⇒ ABL 拒启 或 Android 降级 | ABL 侧见到 `VB2: Authenticate complete! boot state is: orange`（出厂 logfs 样板里），未拒启；`vbmeta_a` 是 a 链唯一非原厂件 | **写回原厂 `vbmeta_a`（64 KiB，回退件 = `logs/forensics-20261120-2210/vbmeta_a.img`）→ 启 a 槽**；成本 ≈ 一次 fastboot 窗口，比 S3 便宜 100× | **未验证（性价比最高）** |
| **H6** | `/data`+`/metadata` 状态（`fastboot -w` 之后从未被 Android 挂载） | `/data` `s_mnt_count=0`；`/metadata` 被写过；无内核 panic；落 recovery 形如 `--prompt_and_wipe_data` | `s_mnt_count=0 / state=0x1 / s_wtime=0`（`logs/a-slot-forensics-20261121/userdata-head4k.bin`）；`pstoredump` 命中 0 | **机制确认实验**：落 recovery 后读 `/proc/cmdline`（应见 `force_normal_boot=0`）+ `/tmp/recovery.log`（应见 prompt_and_wipe_data）——脚本已自动化；处置 = 让 **Android 自己**格式化（recovery 的 *Wipe data/factory reset*），不是再来一次主机 `fastboot -w` | **主推（未上机证实）** |
| **H7** | `adb devices = recovery` 是判读 confound | 若为 confound，则落点其实不是 recovery userspace | ① a 链两处 ramdisk（`init_boot_a` 22 项 cpio、`vendor_boot_a` 335 项）**都没有** `/system/bin/recovery` ⇒ AOSP `IsRecoveryMode()` 不成立；② 11-18/19 也见过同一 `adbd SIGABRT` 签名（`TASKS/sessions/2026-11-18-…`），当时也判成 recovery | 落点当场取 `getprop ro.boot.mode` / `/proc/cmdline` / `ls -l /system/bin/recovery`（`exec-out`，绕开 adbd shell 崩） | **不可排除（方法与 H6 同一发实验）** |
| **H8** | `userdata` GPT 几何错 | 起止与台账不符 | 与台账一致（姊妹件 §4.3） | — | **排除** |
| **H9** | `factory_build = 1` 是 recovery 证据 | 1 ⇒ recovery | 1 只出现在**出厂 a 槽**记录与本机 a 槽件；b 槽我们的 Linux 件打印 0。它是 ABL 对**镜像来源**打的标（同一 ABL 二进制 `abl_a==abl_b==abl.elf e7062378…`），与启动模式无关 | — | **排除（误解）** |

**判别顺序（结论）**：`H5 写回原厂 vbmeta_a（1 次 fastboot，5 min）` → `H6/H7 同一发：落点当场取 cmdline/logfs/recovery.log` → 只有前两者都清了才轮到 `S3（14.5 GiB，14–18 min）`。
**S3 现在的定位不再是"唯一有效实验"**，而是「H5/H6/H7 全清之后的对照」。

---

## B. 材料核实（S2/S3 就绪度，全部 O_DIRECT 口径）

| 件 | 路径 | 字节 | O_DIRECT sha256 | 副本 | 台账一致 |
|---|---|---|---|---|---|
| 原厂 metadata（S2 件） | `out/android-v3-bringup-20261120/metadata_stock.img` | 29 372 416 | `a735fbc74abf0d9695a1fc598128acc78184abc710224719825bbe16fca4722e` | 8 分片 `backup/official-rom-15.10.259/metadata_{1..8}.img`（8192/32768/10539008/16384/24576/28672/8192/12288 B，齐备） | ✅ `versions/out-artifacts.tsv` 记 pending（禁删） |
| 原厂 super（S3 件） | **缺件**，按需现造 `out/android-v3-bringup-20261120/super_stock_contig.img` | 15 607 586 816（=3810446 扇区；稀疏 ~12.2 GiB） | 现造后核 | 8 分片齐备（405504 / 1650688 / 1041178624 / 12266729472 / 12533760 / 598372352 / 1536172032 / 147382272 B） | ✅ 分片在 `backup/official-rom-15.10.259`（`versions/backup-manifest.tsv` 记 KEEP-REF 单副本 16.79 GB） |
| 第二副本 | `backup/official-rom-15.10.259/` 是**唯一**在线副本（manifest 记 `alt_source=联想官网重下`）；`super_4=12.2 GB` 独占 | — | — | **无第二副本**（云备份 20261016 未覆盖） | ⚠ 不要 `out-archive` 删分片 |
| 回退件：在机 super | `out/android-min-20261118/pkg/super_min.img` | 8 893 497 344 | `e3d0d26f…`（首 512 KiB 实测 `67ff7604…` = 在机值） | 在机 super 头/尾 4 MiB 已 dump（`logs/a-slot-analysis-20261121/`） | ✅ |
| 回退件：`boot_a` 属性 | 现值 `byte6=0x32`（retry6/succ0/unbootable0） | — | — | 修法 `slot-attr.py set a --retry 7 --no-unbootable --successful` | ✅ 已记 |
| 回退件：`misc` | 64 KiB O_DIRECT `c515a5d7…`（仅 `0x8000` 5 字节） | — | — | 写入只需 `dd 4 KiB 零`，可逆 | ✅ |
| 回退件：`vbmeta_a`（H5 用） | `logs/forensics-20261120-2210/vbmeta_a.img`（自签现役件 419e01ac…） | 65 536 | 与设备读值一致 | 原厂件 `backup/official-rom-15.10.259/vbmeta.img` 55929c15… | ✅ |

**S2 结论：已是 no-op，不必再花窗口**（写前 = 写后 = 原厂件，a 槽仍失败）。
**S3 结论：件可现造（`/` 余 194 G > 12.2 GiB），但按 §A 判别顺序排到 H5/H6/H7 之后。**

---

## C. 设备只读取证（全部落 `logs/a-slot-analysis-20261121/`，`SHA256SUMS.txt` 自校验）

| 项 | 值 | 命令要点 |
|---|---|---|
| `qbootctl` | `Current slot: _b`；`_a Active0 Succ0 Bootable1`；`_b 1/1/1`；`qbootctl -a` → `Active slot: _b` | `qbootctl; qbootctl -a` |
| `boot_a`/`boot_b` GPT 属性 | `boot_a byte6=0x32`（retry6/succ0/**unbootable0**）；`boot_b 0x77`；`vbmeta_b 0x4f`；`uefi_b/vendor_boot_b/recovery_b/init_boot_b 0xff`（OEM 常量，按 `slot-attr.py` 文档**不是** unbootable 标记） | `python3 /tmp/slot-attr.py --allow-wrong-lun --device /dev/sde show` |
| super 头部 geometry | `mag=0x616c4467 … flags=0x1`；`blockdev size=23622320128`；`system_a 5296 MiB` + 6 个 `_a`（vendor 1466 / product 993 / system_ext 571 / vendor_dlkm 141 / system_dlkm 12 / odm 2）⇒ **v1**（v3 会是 `system_a 3920 MiB`） | `dd … super bs=4096 count=128 iflag=direct` → `android-super.py list` |
| super 首/末 4 MiB | head `d516ae04f7f3efac9e3879dc96fe21e3ef00c6db524abdcceac473123c0d523d`；tail `bb9f8df61474d25e71fa00722318cd387396ca1736605e1248821cc0de3d3af8`（未整盘读） | `dd bs=1M count=4 iflag=direct` / `skip=22524` |
| `misc` 64 KiB | O_DIRECT `c515a5d771b9443f80c0df29a79f1cca7ee06adea15e4ccf6f14fe3bcd5f800c`；非零 = 5 字节 @ `0x8000` `02 b0 0a 74 56`；**头 4 KiB 全 0（BCB 干净）** | `dd bs=4096 count=16 iflag=direct` |
| a/b 分区 sha | 见 §0-4 + `device-forensics.txt`（含 `recovery_b=dfaf3dde…`≠原厂 recovery、`vbmeta_b=906e6922…`=11-21 AVB 债修复件） | 同上 |
| `abl_a` / `abl_b` | **都等于原厂 `abl.elf` `e7062378…`** ⇒ a 槽不是"跑另一套旧 ABL"，§A H9 成立 | `dd bs=1M iflag=direct \\| sha256sum` |
| logfs 结构 | 见 §0-1（仅 seg0 由设备写；seg1..9 与出厂包逐段同 sha；seg10..127 全 0） | `sha256` 逐 64 KiB 段对比 |

---

## D. 一页执行单（self-contained；S0 取证 → H5 → S2（可选）→ S3）

> 通用：`S=HA2EXB0E`、`TAB=root@192.168.7.1`、`QDL=$HOME/edl/qdl/build/qdl`、`L=$HOME/下载/tb322fc/xbl_s_devprg_ns.melf`。
> 每条外部命令过 `timeout -k`；qdl 每条带 `-R`，`reset` 单独一发；写前先读 live GPT 过 `scripts/android-linux-coexist-check.py`；
> 主机件 sha 一律 O_DIRECT（`scripts/odirect-sha.py`）；**reset 前必须「清 BCB 4 KiB → 读回全 0」**。
> 机械入口 = `bash scripts/android-v3-bringup-walkthrough.sh --apply --step S1|S2|S3`（本 lane 已复核，§E）。

### S0（新增，强制）落点当场取证 —— 30 s，只在"落 recovery/异常"时
```sh
timeout -k 5 30 adb -s $S exec-out 'cat /proc/cmdline'      > recovery-cmdline.txt   # 判据：含 force_normal_boot=0 ⇒ ABL 选的 recovery
timeout -k 5 30 adb -s $S exec-out 'dd if=/dev/block/by-name/logfs bs=4096 count=64 2>/dev/null' > recovery-logfs.bin
timeout -k 5 30 adb -s $S exec-out 'cat /tmp/recovery.log'  > recovery-last.log      # 判据：见 prompt_and_wipe_data ⇒ /data 路径
timeout -k 5 30 adb -s $S exec-out 'getprop | grep "^\[ro.boot\."' > recovery-props.txt
```
- **为什么强制**：`logfs` 只写第 1 段，**下一次启动立刻覆盖**（§0-1）。上一发就是因此丢了唯一的 ABL 证据。
- 判据：`recovery-logfs.bin` 里出现 `Recovery:1` + `Booting into Recovery Mode via Boot` ⇒ H1 成立；出现 `Recovery:0` + `Booting Into Mission Mode` ⇒ 落 recovery 发生在 ABL 之后（走 H6/H7）。

### H5（最便宜的单变量）写回原厂 `vbmeta_a` —— 5 min，**需物理键**（进 fastboot）
```sh
# 人：长按电源 10 s 关机 → 按住【音量上 + 电源】→ fastboot 屏
timeout -k 5 20 fastboot -s $S getvar current-slot                  # 记现值
timeout -k 5 60 fastboot -s $S flash vbmeta_a backup/official-rom-15.10.259/vbmeta.img   # 64 KiB；**必须 flash，不能 boot**（boot 只收引导件）；回退件 = logs/forensics-20261120-2210/vbmeta_a.img
timeout -k 5 20 fastboot -s $S --set-active=a ; timeout -k 5 20 fastboot -s $S getvar current-slot
timeout -k 5 30 fastboot -s $S reboot                              # → S0 取证窗口
```
- 判据：进桌面 ⇒ H5 成立（`vbmeta_a` 自签是变量）；仍落 recovery ⇒ H5 排除，走 S0/S2/S3。
- 失败处置：`--set-active=a` 后 `current-slot != a` ⇒ 停（不 reboot）；回退 = `flash vbmeta_a logs/forensics-20261120-2210/vbmeta_a.img` + `--set-active=b`。
- 注：`vbmeta` 必须 `flash` 不能 `boot`（`boot` 只接受 boot 镜像）。

### S2 原厂 metadata —— 5–8 min（**已知 no-op，仅在需要新样本时跑**）
```sh
python3 scripts/odirect-sha.py out/android-v3-bringup-20261120/metadata_stock.img    # 必须 = a735fbc7…
fastboot -s $S oem edl ; lsusb -d 05c6:9008                                          # 120 s 未枚举 ⇒ 人项
$QDL -s ufs -R $L read 0/0+6 live-gpt0.bin
python3 scripts/android-linux-coexist-check.py --gpt live-gpt0.bin                   # MISMATCH ⇒ 不写
$QDL -s ufs -R $L read 0/5857704+7171 metadata-pre.bin                               # 回退基线（应 = a735fbc7…）
$QDL -s ufs -R $L write 0/5857704 out/android-v3-bringup-20261120/metadata_stock.img sha256 0/5857704+7171 \
      read 0/5857704+4096 head16m.bin read 0/5860779+4096 tail16m.bin
$QDL -s ufs -R $L write 0/89992 zero4k.bin read 0/89992+1 bcb-after.bin               # 清 BCB
$QDL -s ufs $L reset
```
- 判据：设备端 sha = `a735fbc7…`、head/tail `cmp` 一致、BCB 读回 nonzero=0；reset 后 → S0。
- 预判：**写的是同一份原厂内容 ⇒ 观测不会变**（11-20 已实测）。要真判因请走 H5/H6。

### S3 原厂 super 对照 —— 14–18 min，**需 EDL（`fastboot oem edl`，前置 = 物理键或已在 fastboot）**
```sh
python3 scripts/android-super.py assemble --xml backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml \
        --label super -o out/android-v3-bringup-20261120/super_stock_contig.img       # 必须 15607586816 B
python3 scripts/odirect-sha.py out/android-v3-bringup-20261120/super_stock_contig.img  # 记 sha（约 12.2 GiB 实占）
fastboot -s $S oem edl ; lsusb -d 05c6:9008
$QDL -s ufs -R $L read 0/0+6 live-gpt0.bin && python3 scripts/android-linux-coexist-check.py --gpt live-gpt0.bin --super-img <件>
$QDL -s ufs -R $L read 0/90504+128 super-head512k-pre.bin
$QDL -s ufs -R $L write 0/90504 <件> sha256 0/90504+3810446 read 0/90504+4096 head16m.bin read 0/3896854+4096 tail16m.bin
$QDL -s ufs -R $L write 0/89992 zero4k.bin read 0/89992+1 bcb-after.bin
$QDL -s ufs $L reset
```
- 判据：设备端 sha = 主机 sha、head/tail 逐字节一致；reset 后**先 S0 取证**再看是否进桌面。
- 失败处置：`SAHARA: failed to read request` ⇒ 上一条 qdl 漏了 `-R`；sha 不符 ⇒ 先 `hw-cache-wash` 再复测（页缓存口径），不要急着重刷。
- 回退：`$QDL -s ufs -R $L write 0/90504 out/android-min-20261118/pkg/super_min.img`（v1，2171264 扇区，`e3d0d26f…`）。
- **时间预算**：造件 2–4 min（12.2 GiB 写盘）+ 写 14.5 GiB ≈ 6 min + 读回校验 3 min + 观察 ≤10 min。

### 人项清单（agent 不能做）
| # | 动作 | 出现在 |
|---|---|---|
| 1 | 长按电源 10 s 断电 → **音量上 + 电源** 进 fastboot | H5、S1（Linux 侧无法切槽，`PITFALLS #701`）、S2/S3 的 `fastboot oem edl` 前置 |
| 2 | 恢复窗口（1–2 h 桌面不可用） | H5 ≈ 10 min；S2 ≈ 10 min；S3 ≈ 30 min |
| 3 | 若落到 recovery 且属 `/data` 路径：在 recovery UI 上做 **Wipe data/factory reset**（让 Android 自己格式化） | H6 处置 |

### 已在只读侧"干跑"过的部分
`--verify`（7/7 件 + 16 分片，rc0）、`--dry-run --step S3`（rc0、无设备写入、无假结论）、
`odirect-sha.py` 全件复算、logfs 逐段对比、ramdisk 解包（`init_boot`/`vendor_boot`）、`slot-attr show`、`qbootctl`、`super` 头/尾、`misc` 64 KiB。

---

## E. `scripts/android-v3-bringup-walkthrough.sh` S1–S3 复核 + 改动清单

**复核动作（全部实跑）**：`bash -n` = OK；`--verify` = rc0（7/7 件 + 分片齐备 + fastboot 37.0.1）；`--dry-run --step S3` = rc0；
`python3 scripts/gen-scripts-index.py --check` = `OK scripts/README.md 结构最新（344 个入口）`（本轮改动未新增/删除脚本，索引不需重生成）。

**本轮我改的 2 处（fail-closed，均为"未验证→通过"的漏洞）**

| # | 位置 | 旧行为（实测） | 新行为 |
|---|---|---|---|
| C1 | `pstore_triage()` | 为"抓字节不进 `run()`"绕开了 `APPLY` 门 ⇒ **`--dry-run` 也真读 128 MiB**，并把 `hit=0` 打印成「判据：命中 0 ⇒ 无内核崩溃」= **把"没执行"显示成"查过且干净"** | `if [ "$APPLY" != 1 ]; then info "[dry] 跳过 pstoredump 抓取…"; return 0; fi` |
| C2 | `S3()` 结尾 verdict | dry-run 下 `observe_android` 直接 `return 0`，旧实现据此打印 **「S3 结论：原厂 super 能进桌面 ⇒ 我们的 v1 super 内容」**（未执行被读成通过） | `[ "$APPLY" = 1 ] || { info "[dry] 结论行省略（未真执行，不产生 verdict）"; return 0; }` |
| C3 | `S1()` super 头抓取 | dry-run 也会 ssh `dd 512 KiB`（只读，但与"dry 只打印"不符） | 加 `[ "$APPLY" != 1 ]` 分支只打印将执行的命令 |

**复核认可（姊妹件同轮已加、逐条验证过语义正确，无改动）**：`_q()` 引用保全（修 packet §10.3 F1）；`require_active_a`（S2/S3/S4 写盘前 + reset 前各一次，Linux 侧 fail-closed）；
`S1` super 首 512 KiB sha 三档判据（`67ff7604…`=v1 / `c6278f8e…`=v3 / `12c35980…`=原厂，**我独立 O_DIRECT 复算三个常量全对**）；
recovery 分支当场抓 `cmdline/logfs/recovery.log/props`（正是 §D S0）；`pstore_triage` 的 `hit=unknown` 与 0 区分；`observe_android` 的 reset 后 60 s EDL 瞬态去抖。

**仍未自动化（留给下轮，不阻塞）**：① recovery 分支 `dd /dev/block/by-name/logfs` 在 recovery 里是否真有 `by-name` 链接**未验证**（备选 `/dev/block/platform/soc/1d84000.ufshc/by-name/logfs`）；② S5 的 `fastboot boot` 件是否被 ABL 接受 = 需上机项；③ S3 判据里"原厂也不进 ⇒ 不是 super 内容"仍可能被 H6/H7 污染，脚本已用 `rc` 明示但不能自动区分。

---

## F. 收尾结论表（数字优先）

| # | 还剩什么 | 谁做 | 成本 | 判据 |
|---|---|---|---|---|
| 1 | **落 recovery 时当场取 logfs/cmdline**（唯一能分 H1/H6/H7 的观测；已丢过一次） | agent（脚本已自动化；需一次 a 槽启动） | 1 发 ≈ 5 min | logfs 出现 `Recovery:1` ⇒ H1；`Recovery:0`+Mission ⇒ 走 H6 |
| 2 | **H5：写回原厂 `vbmeta_a`**（a 链唯一非原厂件，最便宜单变量） | **用户物理键** + agent | 10 min | 进桌面 ⇒ H5 成立；仍 recovery ⇒ 排除 |
| 3 | H6 处置：让 **Android 自己**格式化 `/data`（不是主机 `fastboot -w`） | 用户（recovery UI） | 5 min | 落 recovery 时看 `/tmp/recovery.log` 是否有 `prompt_and_wipe_data` |
| 4 | S3 原厂 super 对照（**降级为 H5/H6 之后的对照**，不再是"唯一有效实验"） | agent（需物理键进 fastboot → EDL） | 造件 4 min + 写 6 min + 观察 10 min，共 ≈ 30 min | 设备端 sha 一致；原厂能起 ⇒ H2 成立 |
| 5 | S2 原厂 metadata | — | **不必再跑**（11-20 实测 no-op） | 已排除 |
| 6 | 文档校正：`PITFALLS #702` 与 `reports/android-a-slot-attempt-20261120.md` §3.1 里"logfs=EBS 13311 同族"的证据链**无效**（出厂遗留） | 编排者（本 lane 无 TASKS/PITFALLS 写权） | 5 min | 引用本文件 §0-1/2/3 |
| 7 | 设备现态（本轮结束时实测）：`active=_b`、Linux vk189 在机、`boot_a 0x32`、BCB 头 4 KiB 全 0、super=v1 | — | 未改动任何分区 | — |

**一句话**：a 槽问题的**证据基础**本轮被修正（logfs 只有 1 段真记录 ⇒ 此前所有"a 槽 ABL 日志"推断作废），
因此下一步不是花 30 分钟刷 14.5 GiB，而是 **10 分钟的 `vbmeta_a` 单变量 + 一次带当场取证的 a 槽启动**。

---

## 附：本轮产物与复现

- 证据目录：`logs/a-slot-analysis-20261121/`（`super-head4M.bin`、`super-tail4M.bin`、`misc-64k.bin`、`device-forensics.txt`、`SHA256SUMS.txt`）
- 复现：`cat logs/a-slot-analysis-20261121/device-forensics.txt`；logfs 逐段对比脚本见本文件 §0-1 命令（`sha256` 每 64 KiB）
- 脚本改动：`scripts/android-v3-bringup-walkthrough.sh`（3 处，见 §E；`scripts/README.md` 索引无需重生成，已 `--check` 通过）
- 未读/未做：`scripts/README.md` 未改；`TASKS/README.md`/`PITFALLS` 未改（无写权）；未做任何设备写操作
