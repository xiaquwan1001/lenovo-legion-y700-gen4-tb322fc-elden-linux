# 安卓「系统起不来」证据链审计（2026-11-22，主机侧只读）

> 口径：纯只读审计，零设备操作（无 adb/fastboot/ssh/qdl）。每条结论挂证据（文件:行号）；
> 判断不了处显式写「证据不足」。引用的行号以本仓当前文件内容为准。

## §1 时间线（安卓曾起得来 vs 起不来的实测事件）

### ✅ 曾起得来（4 次有效成功样本，全在 11-18 / 11-19 前半段）

| 时间 | 变量组合 | 判据 | 证据 |
|---|---|---|---|
| 11-16 之前（出厂/官方包） | 原厂 super v0 + 原厂 vbmeta_a(flags=0) + 原厂 /data | 出厂 logfs seg1+ 留有 9 条 a 槽任务启动记录（`UEFI 6.0.250606`，2025-06 固件），全到 `Start EBS` | PITFALLS/README.md:378（#703）；reports/android-a-slot-laneC-20261121.md:12-14 |
| 11-18 上半 | v1 `super_min`（`/system` 5.0 GiB）+ **旧（未 wipe）`/data`** + 自签 `vbmeta_a` Flags=1（`ro.boot.veritymode=disabled`） | **两发 `boot_completed=1`** | INDEX.md:169-171；reports/android-slim-v2-20261119.md:104（「同一 v1 镜像在旧 /data 上两发 boot_completed=1」）；reports/android-slim-v2-20261119.md:165 |
| 11-19 20:0x（先决） | 换回**原厂 GPT**（单变量定因：之前是第三方非原厂 GPT） | 「完整起 Android 16」 | INDEX.md:164 |

### ❌ 起不来（按发次，标 confound）

| 时间 | 变量 | 现象 | **confound** | 证据 |
|---|---|---|---|---|
| 11-18 下半 | 同 v1 super 但 **`/data` 被 wipe** | 卡 ZUXOS 动画 | ⚠ 未取证；且 `boot_b` 属性/BLE 无关变量并存 | INDEX.md:167；reports/android-slim-v2-20261119.md:25 |
| 11-19 深夜 v3 上机 3 发 | v3 super（system_a 3920 MiB）①首启 ②wipe 后 ③回刷 v1 | ①卡动画 ②卡 logo 掉电 ③同 ① | ⚠ **②③被 BCB=`boot-recovery`/`bootonce-bootloader` 污染，很可能启的是 recovery，不算 Android 失败样本**；① logfs「EBS 13.3 s ⇒ ABL 清白」的引用本身用的是出厂段（后被 #703 推翻） | INDEX.md:117-125；reports/android-slim-v3-20261119.md:179 |
| 11-20 11:0x | v1 在机、BCB 清 0、`boot_a` 属性修复后 reset | 仍失败、自动回落 b | ⚠ 本发仍引用出厂 logfs 段做「EBS 之后」归因（后推翻）；但「回落 b + a 被标 unbootable」是当时实读 | reports/android-a-slot-attempt-20261120.md:40,53,55；PITFALLS/README.md:370（#695） |
| 11-21 上午 S1（09:17 等） | `--set-active=a` + 清 BCB | 落「recovery」态（`adb devices` 显示 recovery + adbd SIGABRT） | ⚠ **未取到本次 logfs seg0**（证据丢失）；「落 recovery」仅一次目视/adb 观测 | reports/android-a-slot-laneC-20261121.md:34（§A④）；:51-53（§0.2） |
| 11-21 14:1x–14:2x H5 三发 | ①原厂 vbmeta_a + ext4 空 /data ②原厂 vbmeta_a + f2fs 空 /data ③自签 vbmeta_a(flags=1) + f2fs | 三发**逐字相同**：BL 警告→黑屏→「安卓系统崩溃警告」→logo 一闪→回落 b | ⚠ 三发全部只有**用户目视**（USB 不枚举、无 adb、pstore 空）；「崩溃警告」归属无日志 | reports/a-slot-h5-three-way-20261121.md:10-14,24,74-76 |

**时间线小结**：唯一干净的成功↔失败差异变量 = **`/data` 旧 vs wipe**（11-18 两发成功 vs 11-18 下半起全部失败）。11-21 三发进一步排除了 `vbmeta_a` verity 位与 `/data` fs 类型，但**没有验证 `/data` 内容路径本身**（H6b 未验证，reports/a-slot-h5-three-way-20261121.md:50）。

## §2 假设台账 H1–H7（含「已排除」复核）

| 假设 | 状态 | 最强证据 | 审计意见 |
|---|---|---|---|
| **H1** ABL 自己选 recovery_a / 槽位机制问题 | **无样本（未证伪，不是已排除）** | lane C 明确改判：全部 9 条「Mission Mode」记录是出厂 seg1+ 遗留，**我们没有一发自己的 a 槽 ABL logfs**（reports/android-a-slot-laneC-20261121.md:23-25,41） | 同意 lane C。注意与 #702（PITFALLS/README.md:377）冲突：#702 说「`--set-active=a` 后 ABL 直接走 recovery_a」，其证据同样是出厂段/目视，**应视为未证实** |
| **H2** super 内容（v1/v3 slim 不可启） | **存活（曾认为最强，已弱化）** | v1 曾在旧 /data 上两发 boot_completed=1 ⇒ super 内容本身可起系统（reports/android-slim-v2-20261119.md:104,165；reports/a-slot-h5-three-way-20261121.md:51） | 11-21 三发后 H2 从「最强」降级：失败与 super 变量无新证据挂钩，反而 /data 状态是贯穿性差异。S3（原厂 super 对照）仍未跑 |
| **H3** misc/BCB 残留 | **已排除（证据充分）** | 头 4 KiB 全 0 + 11-21 09:19 主动 flash 4 KiB 零；清 0 后仍失败（reports/a-slot-h5-three-way-20261121.md:46；reports/android-a-slot-laneC-20261121.md §A H3 行） | 成立。但 #702 的「recovery 会写回 BCB」仍在：每次实验后必须复查 BCB，不构成对排除的挑战 |
| **H4** metadata 被擦/不一致 | **已排除（证据充分）** | S2 实跑：写前=写后=原厂 `a735fbc7…`（no-op），a 槽仍失败；`dump.f2fs` 干净（reports/android-a-slot-laneC-20261121.md §A H4 行；reports/a-slot-h5-three-way-20261121.md:47） | 成立。原报告声称「原厂 metadata 在机仍失败消失」措辞混乱，但 no-op 本身足以排除 |
| **H5** vbmeta_a 自签（flags=1）/rollback | **已排除（11-21 三发，单变量对照）** | flags 0（verity on）vs 1（verity off）结果逐字相同（reports/a-slot-h5-three-way-20261121.md:10-14,48） | 成立，这是全链里最干净的一次对照。**但注意**：#598（PITFALLS/README.md:295）记录过原厂 a 链在哈希不匹配时「屏上 5 s 警告后不交棒」——三发目视里的「BL 警告→黑屏」与该分支相容，只是 verity 位不是决定变量 |
| **H6** `/data`+`/metadata` 状态（wipe 后从未被 Android 挂载） | **存活（主推，未上机证实）** | 成功↔失败唯一贯穿差异 = /data 旧 vs wipe；`s_mnt_count=0`（reports/android-a-slot-laneC-20261121.md §A H6 行；reports/android-slim-v2-20261119.md:104） | 11-21 三发只测了「干净 f2fs」这一种 /data 状态，**没测「让 Android 自己格式化/旧 /data 回来」**——H6 未被三发触碰。⚠ 但机制链有缺口：a 链 ramdisk 无 `/system/bin/recovery`，`--prompt_and_wipe_data` 路径需二次启动并留 `Recovery:1`，无样本（laneC §0.3:44-46） |
| **H7** 观测 confound（ramdisk 早段失败被读成 recovery） | **存活（不可排除）** | a 链两个 ramdisk 都没有 `/system/bin/recovery` ⇒ `IsRecoveryMode()` 不成立；11-18/19 同一 `adbd SIGABRT` 签名当时也被判 recovery（reports/android-a-slot-laneC-20261121.md §A H7 行）；pstore 空 = 无内核 panic（reports/a-slot-h5-three-way-20261121.md:24,52） | 「崩溃警告」到底是 ramdisk `boot_failure` UI 还是 framework ANR，**证据不足**——只有目视。这是当前最需要日志通道的点 |

**「已排除」复核结论**：H3/H4/H5 排除成立；**H1 从未真正被排除也未被证实（无样本）**；#702/#706（PITFALLS/README.md:377,381）里任何依赖 seg≥1 logfs 的措辞按 #703 纪律一律降权。

## §3 三个最小单变量实验（各 ≤15 min 设备窗口）

### E1 落点当场取证（不改任何变量，纯观测）——复用下一次任何 a 槽启动

- **前置条件**：无（任何一发启动顺带做）；`qbootctl -s a` 从 Linux 可切槽、不需物理键（PITFALLS/README.md:382，#707）。
- **写什么**：什么都不写。启动失败/落 recovery 后**第一件事**在设备侧：
  `dd if=/dev/block/by-name/logfs bs=4096 count=64`（只取 seg0 64 KiB，**下一次启动立刻覆盖**，PITFALLS/README.md:378）
  + `/proc/cmdline` + `getprop ro.boot.mode` + `/tmp/recovery.log`（lane C S0 单，reports/android-a-slot-laneC-20261121.md §D S0）。
- **判据**：seg0 出现 `Recovery:1` + `Booting into Recovery Mode via Boot` ⇒ H1 成立；`Recovery:0` + Mission Mode ⇒ ABL 之后落 recovery（H6/H7）；seg0 与出厂包 seg0 sha 相同 ⇒ 该次 ABL 根本没写 logfs（异常，另立项）。
- **失败回退**：只读操作，无回退需求；若 USB 不枚举（三发皆如此，reports/a-slot-h5-three-way-20261121.md:74-76）则该通道拿不到——先走 E3 造通道。

### E2 让 Android 自己格式化 /data（H6 的直接检验）

- **前置条件**：进入 recovery（v1 在机 + BCB 清 0 + `boot_a` 属性复位，walkthrough S1）；先做 E1 取证。
- **写什么**：在 recovery 菜单选 *Wipe data/factory reset*（作用域 = userdata + metadata，**不含 super/boot_b/linux17**，原厂 recovery.fstab 实证，reports/a-slot-h5-three-way-20261121.md:66-70）。这不是主机 `fastboot -w` 的重复——差异在「由 Android 自己挂载并初始化 /data」。
- **判据**：重启 a 槽后 `sys.boot_completed=1` 且动画退出 ⇒ H6 成立（/data 初始化方式是变量）；仍失败 ⇒ H6 的「主机 wipe vs Android 自格式化」差异被排除，H6 整体降级。
- **失败回退**：/data 本来就是空 f2fs，无数据损失；metadata 被 Android 重写属预期（S2 已证原厂件 no-op 可回写）；槽位失败自动回 b（Linux 不受影响）。

### E3 造日志通道：`console=ttyGS0` boot 件 + 串口抓 ramdisk 输出（H7 的解法）

- **前置条件**：件已造好 `out/android-v3-bringup-20261120/boot-ttygs0-boot.img`（reports/a-slot-h5-three-way-20261121.md:83）；主机侧 `/dev/ttyACM*` 监听进程先起。风险已知：三发 USB 未枚举 ⇒ 该法可能同样拿不到通道，需先解决「a 槽 USB 不枚举」（同上 :85）。
- **写什么**：只 `dd` 写 `boot_a`（写前记 sha `b428a31d…`，回退 = 同字节写回原厂件；Linux 侧写分区不需物理键，#707）。
- **判据**：串口在黑屏前出现 init/ramdisk 日志 ⇒ 失败点直接可见；若串口完全静默且 ABL seg0 显示已交棒 ⇒ 失败在更早的显示/驱动路径（H7 反向证实）。
- **失败回退**：`dd` 写回原厂 `boot_a`（sha 校验）+ `boot_a` 属性复位（`slot-attr.py set a --retry 7 --no-unbootable`，回退件与修法见 reports/android-a-slot-laneC-20261121.md §B 表）。

（未选 S3 原厂 super 对照：14.5 GiB 写 6–12 min + 需 EDL，且 lane C 已正确降级为「H1/H6/H7 清后再做」的对照，reports/android-a-slot-laneC-20261121.md §A 判别顺序。）

## §4 结论（根因排序 + 值不值得继续）

**根因排序（挂证据）：**
1. **H6（/data 状态/初始化路径）**——唯一贯穿全部成败样本的差异变量（11-18 旧 /data 两发成功 vs wipe 后全败，reports/android-slim-v2-20261119.md:104,165）；11-21 三发未触碰它（只换了 fs 类型，reports/a-slot-h5-three-way-20261121.md:49-50）。
2. **H7（观测 confound / 无日志黑盒）**——所有「失败」样本中≥3 发的失败点归属只有目视（三发）或被出厂 logfs 污染（11-19/20），ramdisk 无 recovery 二进制使「落 recovery」判读本身可疑（reports/android-a-slot-laneC-20261121.md §A H7）。
3. **H1（ABL 槽位/recovery 机制）**——无样本命题，未证伪未证实（laneC §0.1）；优先级低于 H6/H7 只因它可被 E1 一次覆盖。
4. **H2（super 内容）**——已从「最强」降级：v1 有成功反例，且无任何失败样本与 super 变量共变。
5. **H5/H3/H4**——证据充分地排除（reports/a-slot-h5-three-way-20261121.md:46-48）。

**值不值得继续**：**值得，但只在两个条件下继续**——① 先做 E1（纯观测，边际成本≈0）拿到第一份真正的本次启动 ABL seg0；② E2 用 ≤15 min 直接检验 H6。两者都落空（仍无日志 + Android 自格式化也不行）再谈 S3 或放弃。若用户已裁决「暂不继续」（reports/a-slot-h5-three-way-20261121.md:6），则本审计支持该裁决的**当时理由**（盲试低收益），但指出其论据里「H5 已排除」成立、「failure 在 super」方向已被降权，重启线的正确入口是 E1→E2→（视结果）S3，而不是继续换 vbmeta/fs 变量。B 档回收判据（INDEX.md §0 条 1 提到受影响）应在 E1/E2 之后再定。

*审计者注：本审计全程未触碰设备；所有设备侧数值转引自上述报告/日志文件名，未独立复跑（主机侧只读约束）。*
