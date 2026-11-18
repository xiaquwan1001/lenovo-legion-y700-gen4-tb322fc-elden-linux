# KSU(init_boot) + AVB 自洽 —— 主机侧造件与对账（TB322FC / elden / ZUXOS 1.5.10.259）

> lane：`out/android-root-20261119/`　　会话日期：2026-11-18 20:0x–20:5x CST（目录按任务口径命名为 `20261119`）
> 生成器：`scripts/android-ksu-avb-build.py`　　刷写器：`scripts/android-ksu-flash.sh`（默认 dry-run）
> 结论全部**主机侧**；**一件都没上机**（本 lane 硬约束：不 adb / 不 fastboot / 不 EDL 写）

## 0. 数字结论（先看这 6 行）

1. **任务里给的 `restore-259/KSU/init_boot.img`（2 850 816 B）与 `restore-259/KSU/vbmeta.img` 在本机不存在**；
   `restore-259/` 只剩 2 个 md（`README.md`、`AVB-KSU-2026-09-29.md`），README 里列的 `重签包/`、`KSU/`、`_zips/`、
   `xbl_s_devprg_ns.melf` **全部缺**。⇒ 社区件「是否自洽」**无法用文件复核**，只能引用文档里的 digest 数字；本 lane 改为**自建**。
2. **自建件已出且自洽**：`init_boot_ksu.img`（8 388 608 B，`e30ce75d…`，footer 描述符 `2 945 024 / ce2a4442…`）
   + `vbmeta_a_root.img`（65 536 B，`5d93ba43…`，testkey `2597c218` 签、`Flags=1`、`Rollback 0`、24 条描述符中**只换 init_boot 一条**）。
   `avbtool verify_image` 两件全绿；描述符逐字节比对 = 只有 idx 18 不同；独立重算 `sha256(salt‖img[:2945024])` 与描述符相等。
3. **salt 计算方式已用原厂件三例复核**：`sha256(salt ‖ image[:ImageSize])` 对 official259 `init_boot`(2 465 792/`22a95107…`)、
   `init_boot_b`(2 228 224/`4709eeec…`)、`dtbo`(23 348 092/`b0a269a6…`) **3/3 相等** ⇒ 该公式即 AVB hash descriptor 口径。
4. **KSU LKM 必须落 `init_boot`（本机）**：`init_boot.img` = `ANDROID!` v4、**kernel_size=0**、ramdisk 2 457 793 B（LZ4 legacy + cpio：
   `init` 3 194 920 / `snapuserd` / `snapuserd_ramdisk`）；`boot.img` = v4、kernel 36 731 392 B、**ramdisk_size=0**。
   内核 KMI 直接从 `boot.img` 内核段读到 `Linux version 6.6.118-android15-8-g350f378eb496` ⇒ `android15-6.6`，与所取 `kernelsu.ko` 一致。
5. **补丁已落地并取到硬证据**：打完后 ramdisk 2 457 793 → 2 940 190（**+482 397**），cpio 多出 `kernelsu.ko`（**435 208 B**，
   = 下载件字节数）、`init` 变成 603 072 B 的 ksud stub、原 init 改名为 `init.real`（3 194 920 B = stock init 尺寸）。
6. **签名 key 的实测口径与旧文档不一致（需 SSOT 更正）**：official 259 包的 `vbmeta.img` / `boot.img` / `recovery.img` 顶层公钥
   **都是 `8fcb864f…`（OEM）**，不是 `2597c218`；2026-11-01 EDL 读回 `vbmeta_a` 与官方件**逐字节相同**（`55929c15…`）。
   `2597c218` 只出现在 **2026-09-29 的设备 dump**（`61b20210…`，`Flags=1`、chain boot→`2597c218`）。
   ⇒ `2597c218` = **AOSP testkey 的私钥唯一在手**（AOSP 公开测试密钥，`avbtool extract_public_key` 实测 sha1 = `2597c218…`），
   故自签件的顶层只能用这把；`8fcb864f` 无私钥，**永远签不出**。

## 1. 材料核对（先核再过）

| 材料 | 实测 | 判 |
|---|---|---|
| `backup/official-rom-15.10.259/init_boot.img` | 8 388 608 B `e8206b81…`；footer `NONE`、orig 2 465 792、描述符 `22a95107…` | ✅ 与 `~/文档/TB322FC_15.10.259/init_boot.img` 同 sha |
| `backup/official-rom-15.10.259/vbmeta.img` | 65 536 B `55929c15…`；`8fcb864f` / `Flags 0` / `Rollback 0` / 3 chain + 3 hash + 4 hashtree / 14 prop | ✅ = 2026-11-01 EDL 读回的 a 槽 |
| `backup/stock-259/init_boot_a.img`（2026-09-29 dump） | 8 388 608 B `6c97450e…`；ramdisk 2 948 551；footer orig 2 953 216 但描述符仍写 2 465 792/`22a95107…`；`strings` 含 `kernelsu.ko`、`description=Android KernelSU`、`/data/adb/ksud` | ⚠ **KSU 版但 footer/vbmeta 未跟**（重算 `8ddb0cfb…` ≠ `22a95107…`） |
| `backup/stock-259/init_boot_b.img` | ramdisk 2 221 225；描述符 2 228 224/`4709eeec…`；`strings` 含 `/.magisk`、`${MAGISKTMP}`；指纹 `ZUXOS_1.1.11.073`（**另一 build**） | ⚠ Magisk 版 + 跨 build |
| `restore-259/KSU/*`、`restore-259/重签包/*` | `ls` 不存在 | ❌ **缺件** |
| `tools/avbtool.py` | LineageOS 版 Python 实现，`info/verify/add_hash_footer/make_vbmeta_image` 齐全 | ✅ |
| `bootslot-b/avb.key` | `extract_public_key` → sha1 `1e54e86e…`（≠ testkey） | ✅ 是 2026-11-18 `vbmeta_a_flags1`(`419e01ac…`) 那把 |
| AOSP `testkey_rsa4096.pem`（从 `android.googlesource.com` 取） | `avbtool extract_public_key` → sha1 `2597c218aae470a130f61162feaae70afd97f011` | ✅ **设备 a 槽 dump 里出现过的 key，私钥在手** |

## 2. AVB 逐字段对账（`out/android-root-20261119/avb-recon-20261119.tsv`）

| 件 | bytes | sha256[:16] | alg | pubkey[:12] | rollback | flags | init_boot desc |
|---|---|---|---|---|---|---|---|
| official259 `vbmeta.img` | 65536 | `55929c1580d437ad` | RSA4096 | `8fcb864f11f5` | 0 | 0 | 2 465 792 `22a95107…` |
| device `vbmeta_a`（EDL 2026-11-01） | 65536 | `55929c1580d437ad` | RSA4096 | `8fcb864f11f5` | 0 | 0 | 同上（**逐字节相同**） |
| device `vbmeta_a`（dump 2026-09-29） | 65536 | `61b202102302493a` | RSA4096 | `2597c218aae4` | 0 | **1** | 同上 |
| official259 `vbmeta_system.img` | 65536 | `910e013bbab9ac8a` | RSA4096 | `8fcb864f11f5` | **1777939200** | 0 | — |
| device `vbmeta_system_a`（09-29 dump） | 65536 | `910e013bbab9ac8a` | RSA4096 | `8fcb864f11f5` | 1777939200 | 0 | —（**同官方**） |
| official259 `boot.img` | 100663296 | `b428a31dadc5db3f` | RSA4096 | `8fcb864f11f5` | **1738713600** | 0 | —（3 prop：os_version/fingerprint/security_patch） |
| official259 `init_boot.img` | 8388608 | `e8206b81d5523d52` | **NONE** | — | 0 | 0 | 2 465 792 `22a95107…` |
| device `init_boot_a`（09-29 dump） | 8388608 | `6c97450e4bea2b38` | NONE | — | 0 | 0 | 2 465 792 `22a95107…`（**stale**） |
| device `init_boot_b`（09-29 dump） | 8388608 | `186fd9cd48694340` | NONE | — | 0 | 0 | 2 228 224 `4709eeec…` |
| official259 `vendor_boot` / `dtbo` | — | `326d5c32…` / `45f51790…` | NONE | — | 0 | 0 | —（各 1 prop） |
| **NEW** `init_boot_ksu.img` | 8388608 | `e30ce75d380f6b27` | NONE | — | 0 | 0 | **2 945 024 `ce2a4442…`** |
| **NEW** `vbmeta_a_root.img` | 65536 | `5d93ba43b0e9b968` | RSA4096 | **`2597c218aae4`** | 0 | **1** | **2 945 024 `ce2a4442…`** |

chain descriptor（新件与原厂件**逐字节相同**）：`boot@loc3 = 8fcb864f`、`recovery@loc1 = 8fcb864f`、`vbmeta_system@loc2 = 8fcb864f`。

**salt 计算方式（任务要求写清）**：`Digest = sha256( Salt[32 B] ‖ image[0 : ImageSize] )`，salt 直接取描述符里的 32 字节，
`ImageSize` = **加 AVB footer 之前的镜像长度**（footer 自己的 `Original image size` 字段）。三例复核：

```
stock259 init_boot: sha256(salt eb3971… ‖ 0..2465792)  = 22a951076b73…  == 描述符 ✅
init_boot_b       : sha256(salt 85a311… ‖ 0..2228224)  = 4709eeec0546…  == 描述符 ✅
stock259 dtbo     : sha256(salt e55de2… ‖ 0..23348092) = b0a269a62abd…  == 描述符 ✅
NEW init_boot_ksu : sha256(salt eb3971… ‖ 0..2945024)  = ce2a44422eb4…  == 新描述符 ✅
```

**自洽性结论**：

- **原厂 259 一套：自洽 ✅**。3 条 chain 的公钥都等于被链分区的实际签名公钥（boot/recovery = `8fcb864f`）；
  3 条 hash descriptor（dtbo / init_boot / vendor_boot）重算全等；4 条 hashtree 属 super 侧，本 lane 不动。
- **2026-09-29 的设备 a 槽：不自洽 ❌（但在宽容态能起）**。`init_boot_a` 已被 KSU 改过（ramdisk 2 948 551），
  其 footer 与 `vbmeta_a` 里的描述符还写着 stock 的 `2 465 792 / 22a95107…` ⇒ 被哈希的后 488 KB 不含新 ramdisk 的头部改动，
  实际 `sha256 = 8ddb0cfb…`。同一 dump 的 `vbmeta_a` 还把 `boot` 链指到 `2597c218`，而设备 `boot_a` 是 `8fcb864f` 签的
  （`PITFALLS #61` 说 boot 链 key 不匹配**才致命**）⇒ 该 dump 的「当时是否真的在机 / 为何能起」**没有实测证据，不判**。
- **本 lane 两件：自洽 ✅**（下述 3 条命令的输出）。

```
$ python3 tools/avbtool.py verify_image --image $T/init_boot.img
vbmeta: Successfully verified footer and NONE vbmeta struct in …/init_boot.img
init_boot: Successfully verified sha256 hash of …/init_boot.img for image of 2945024 bytes

$ python3 tools/avbtool.py verify_image --image out/android-root-20261119/verify/vbmeta.img --follow_chain_partitions
vbmeta: Successfully verified SHA256_RSA4096 vbmeta struct in vbmeta.img          ← 顶层签名 OK（嵌入式公钥自验）
boot: Successfully verified sha256 hash of boot.img for image of 36753408 bytes
recovery: Successfully verified sha256 hash of recovery.img for image of 16039936 bytes
vbmeta_system: Successfully verified SHA256_RSA4096 vbmeta struct in vbmeta_system.img
pvmfw: Successfully verified sha256 hash of pvmfw.img for image of 774144 bytes
hashtree of product.img does not match descriptor        ← ★见下

$ python3 /tmp/chkdesc.py out/android-root-20261119/vbmeta_a_root.img …/verify
top-level flags = 1 HASHTREE_DISABLED
  dtbo: size 23348092/23348092 recomputed b0a269a62abd3bbb descriptor b0a269a62abd3bbb OK
  init_boot: size 2945024/2945024 recomputed ce2a44422eb4b4e4 descriptor ce2a44422eb4b4e4 OK
  vendor_boot: size 15155200/15155200 recomputed 7e25fffef358b78a descriptor 7e25fffef358b78a OK
```

★ `product.img does not match` 的解释（**不是我方改动引起**）：用手上从 stock `super` 解出的 `parts/product_a.img`
（1 041 178 624 B）去验原厂描述符（`Image Size 1 024 667 648`）本来就对不上——尺寸都不同，
且 2026-11-18 的 super 报告已记录「官方 `super_1..8` 少 7 段共 3.16 MiB 空洞」。**4 条 hashtree descriptor 的字节与官方完全一致**
（见下表 diff），其有效性继承自原厂件；又因本件 `Flags=1`（HASHTREE_DISABLED）在设备侧**根本不跑 hashtree 校验**
（2026-11-18 实测同一 `Flags=1` 件上机 → `ro.boot.veritymode=disabled`）。

**描述符逐条 diff（新 vs 原厂）**：

```
base descriptors=24, replacing idx 18: size 2465792 -> 2945024, digest 22a951076b734edc -> ce2a44422eb4b4e4
descriptors=24 differing indices=[18] (expect [18])
same order/lengths: True   len@18: 208 -> 208
```

## 3. KSU LKM 落 `init_boot` 还是 `boot`（本机定性，全部实测）

| 项 | `boot.img`(official 259) | `init_boot.img`(official 259) |
|---|---|---|
| magic / header_version | `ANDROID!` / **4** | `ANDROID!` / **4** |
| kernel_size | **36 731 392** | **0** |
| ramdisk_size | **0** | **2 457 793** |
| 内容 | 内核段读得到 `Linux version 6.6.118-android15-8-g350f378eb496-ab14943902-4k` | ramdisk `02214c18` = **LZ4 legacy**，解出 cpio：`init`(3 194 920)、`snapuserd`、`snapuserd_ramdisk`、`system/etc/ramdisk/build.prop` |
| footer | `SHA256_RSA4096`、rollback **1738713600**、3 prop | **`NONE`**、rollback 0、2 prop |
| AVB 角色 | **chained 分区**（`vbmeta` 里 `boot@loc3`） | **非 chained**，只由顶层 vbmeta 的 hash descriptor 覆盖 |
| 体积 | 96 MiB 分区 / 36.7 MB 内核 | 8 MiB 分区 / 2.4 MB ramdisk |

⇒ 本机 GKI（Android 16，`6.6.118-android15`）+ LKM 模式下，`kernelsu.ko` 只能塞进 **init_boot 的 ramdisk**（`boot` 的 ramdisk 段是 0 字节，
工具链/官方口径同：`KernelSU-Next` release 直接给 `aarch64_android15-6.6_kernelsu.ko`，配 `ksud boot-patch -b init_boot.img`）。
**改 `boot` 等于改内核**，那是另一条线（M 系列），与本 lane 无关，也是**没必要**的风险。

## 4. 最小改动集（实际执行的 4 步）

| # | 工具/参数 | 结果 |
|---|---|---|
| 1 | `ksud boot-patch -b input/init_boot_stock259.img -m tools/aarch64_android15-6.6_kernelsu.ko --kmi android15-6.6` | `work/init_boot_ksu_raw.img`；ramdisk 2 457 793 → **2 940 190** |
| 2 | 按 footer `original_image_size` 截断 | `work/init_boot_ksu_img_only.img` = **2 945 024 B**（ksud 会保留 stock 旧 footer，**必须剥**，否则描述符 stale） |
| 3 | `avbtool add_hash_footer --partition_name init_boot --partition_size 8388608 --hash_algorithm sha256 --salt eb3971… --algorithm NONE --rollback_index 0 --flags 0 --prop ×2` | 描述符 **2 945 024 / `ce2a4442…`**（Salt/尺寸/prop 与 stock 全同，只有 size+digest 变） |
| 4 | 取原厂 `vbmeta.img` 的 24 条描述符 → 替换 idx 18 → `SHA256_RSA4096` + AOSP testkey + `Flags=1` + `Rollback 0` → pad 65 536 | `vbmeta_a_root.img` `5d93ba43…` |

**key 决策链（为什么不是原厂 key）**：
- 设备 a 槽**真实原厂**顶层/boot 都是 `8fcb864f…`（官方包 + 11-01 EDL 读回，两处互证）→ **无私钥，签不出**。
- `1e54e86e…`（`bootslot-b/avb.key`）= 2026-11-18 上机验证过的自签 `Flags=1` 件，但它是"我方私有钥匙"，不是设备原厂信任链。
- `2597c218…` = **AOSP 公开测试密钥**（私钥可复现获取），也是 2026-09-29 设备 dump 里出现过的顶层公钥，且
  `DEVICE/README.md §1` 明确「自签必须 AOSP testkey（sha1 `2597c218`）」⇒ **本 lane 选它**。
- **但 boot 链仍保留 `8fcb864f`**：设备 `boot_a` 是原厂件，链 key 一改 boot 就致命不匹配（#61）。这是"最小改动"的硬边界。

**rollback 用台账值的正确读法**（都实测自文件，别互相挪用）：

| 位置 | 值 | 出处 |
|---|---|---|
| 顶层 `vbmeta` rollback（loc 0） | **0** | official259 `vbmeta.img` |
| `boot`（chain loc **3**） | **1738713600** | official259 `boot.img` footer（= `DEVICE/README` 台账值） |
| `recovery`（chain loc 1） | **1** | official259 `recovery.img` footer |
| `vbmeta_system`（chain loc 2） | **1777939200** | official259 `vbmeta_system.img` |

⇒ 新件顶层写 **0**（= 原厂值）。把 1738713600 填到顶层会推高 RPMB 计数、把回退变单向，**不做**。

## 5. 交付物 + 脚本 dry-run

`out/android-root-20261119/`：

| 文件 | sha256 |
|---|---|
| `init_boot_ksu.img` | `e30ce75d380f6b273f6730b127c148edc50438d91144819174113268d118c88b` |
| `vbmeta_a_root.img` | `5d93ba43b0e9b96876ebd1e26e6bb1830d240049ca077a7fceab8f25a20aa7bd` |
| `revert/init_boot_a_259stock.img` | `e8206b81d5523d52c96f8f2eb11dfade3e80edcc4b76b796a7f74d6f45c25033` |
| `revert/vbmeta_a_259stock.img` | `55929c1580d437ad9d5f43e897c37f0d6aa1f1469ffb8ede5928f4b43387f387` |
| `revert/vbmeta_a_flags1_selfsigned_20261118.img` | `419e01ac8af7345e69a0f7f43d0e08a71079e912c9add92a5748cf1876716f31` |
| `tools/ksud-x86_64-unknown-linux-musl` | `4d22f89416e7eef8f684f1ed03d2bea19da33c7d41266546e94fd7d1f6cbeca9` |
| `tools/aarch64_android15-6.6_kernelsu.ko` | `8d610b3070d4aa6fb116008c2e2caf4e3972aa73744d9106dc257a50e9bda66d` |

`sha256sum -c SHA256SUMS` → **8/8 OK**。完整清单与中间件说明见 `MANIFEST.md`。

**dry-run 全文**：`out/android-root-20261119/flash-dryrun-20261119.txt`（77 行）、
`flash-dryrun-revert-20261119.txt`（77 行）。关键段：

```
1) 写前备份（EDL 只读；单条 qdl 会话内多目标，避免第二发被 reset 打断）
   $QDL -s ufs $LOADER read 4/137946+16 $PRE/vbmeta_a.bin read 4/205962+2048 $PRE/init_boot_a.bin
   # 期望尺寸：vbmeta_a=65536  init_boot_a=8388608

2) 前置检查：fastboot devices / getvar current-slot(=a) / getvar unlocked(=yes) / getvar product(=TB322FC)
   python3 scripts/slot-attr.py show | grep -E 'boot_a|boot_b'      # byte6 含 0x80 = UNBOOTABLE 时先清标志

3) 校验：sha256sum -c SHA256SUMS ; avbtool verify_image（init_boot）+ info_image(vbmeta → 2597c218/Flags 1)

4) 刷写命令（顺序：先 vbmeta、后 init_boot，中间不重启）
   fastboot flash vbmeta_a    out/android-root-20261119/vbmeta_a_root.img
   fastboot flash init_boot_a out/android-root-20261119/init_boot_ksu.img
   fastboot reboot

5) 写后核对（两条路径）
   A. adb shell 'getprop ro.boot.veritymode; …slot_suffix'   # 期望 disabled / orange / _a
   B. EDL 只读 read 4/137946+16 与 4/205962+2048 → sha256sum 必须等于上面两件的 sha256
```

## 6. 判据 / 不可逆点 / 失败处置

- **本 lane 已取得的判据**：`avbtool verify_image` 两件全绿；描述符 diff 仅 idx 18；独立 digest 重算相等；sha256 落盘；
  `sha256sum -c` 8/8。
- **尚未取得的判据**（需上机，主机侧判不了）：`ro.boot.veritymode=disabled`、KernelSU Manager「工作中」、
  分区读回 sha256 == 刷写件 sha256。
- **不可逆点**（脚本全部规避）：`abl`（不碰）、`super`（不碰）、rollback 计数（顶层保持 0 ⇒ 可自由回退）、
  `--set-active`（不调用；切槽会让 ABL 走 b 槽另一套密钥链）。**没有任何一步"刷了就回不来"**——
  两件都有本地回退件，且 `revert/` 里的 sha256 与官方包逐字节相等。
- **失败处置**：回 fastboot → `--revert`；卡动画 > 5 min → 先确认 `current-slot` 再回退；
  `critical partitions` 报错 = BL 被锁回去（`getvar unlocked` = no）；
  `init_boot` 刷了但 KSU 显示未安装 → 先看 `ro.boot.slot_suffix` 是否还是 `_a`。
- **b 槽保护**：每条 flash 都带 `_a`；**禁止**把命令改成不带后缀的 `fastboot flash vbmeta`（会按当前槽写）。

## 7. 未决 / 需要主代理执行的命令清单

**A. 上机刷写（本 lane 禁止执行；建议按下表顺序，一次做完再停）**

```bash
# 0) 设备需在 fastboot；先只读确认
fastboot devices && fastboot getvar current-slot && fastboot getvar unlocked && fastboot getvar product
python3 scripts/slot-attr.py show | grep -E 'boot_a|boot_b'      # boot_a byte6 含 0x80 就先清 UNBOOTABLE

# 1) 写前只读备份（EDL：fastboot oem edl 进 9008）— 单条 qdl 多目标
mkdir -p out/android-root-20261119/pre/manual && \
~/edl/qdl/build/qdl -s ufs backup/official-rom-15.10.259/xbl_s_devprg_ns.melf \
  read 4/137946+16    out/android-root-20261119/pre/manual/vbmeta_a.bin \
  read 4/205962+2048  out/android-root-20261119/pre/manual/init_boot_a.bin
sha256sum out/android-root-20261119/pre/manual/*.bin | tee out/android-root-20261119/pre/manual/SHA256SUMS.txt

# 2) 刷（先 dry-run 看一遍，再 --apply）
bash scripts/android-ksu-flash.sh
bash scripts/android-ksu-flash.sh --apply
```

**B. 需要裁决的 3 件事**
1. **上机时机**：设备当前卡在「ZUXOS 动画」未结（INDEX §0-0），KSU 件刷上去会把两个变量混在一起。
   建议先把「能不能进系统」这条结掉，再刷本 lane 的件。
2. **`Flags=0` 变体要不要出**：只有在 super 已还原原厂时才安全；要就 `scripts/android-ksu-avb-build.py --flags 0 --out <dir>`。
3. **社区件是否还要找回**：`restore-259/KSU/*` 缺失。若能取回，可用同一套命令复核它的 `2 850 816 / 900054a4…` 说法；
   但即使取回也**不推荐**用（它按 9 月那版 init_boot 打，与 259 官方件不同）。

**C. ★SSOT 待并入（本轮证据与现有文档冲突/新增）**
1. `restore-259/README.md` 的目录清单**全部缺件**（已在文件头加实测注记，2026-11-18）。
2. `TASKS/README.md` Q19 ②「1.1 与 259 的 vbmeta 顶层/boot chain key 均为 AOSP testkey `2597c218`」**与文件实测冲突**：
   259 官方 `vbmeta.img` / `boot.img` / `recovery.img` 全是 `8fcb864f…`（sha256 `55929c15…` / `b428a31d…`），
   11-01 EDL 读回的 a 槽也是 `8fcb864f…`。`2597c218` 只在 **09-29 的 dump** 里。建议按"文件为准"改写，并注明
   `2597c218` 的真实含义 = 「私钥唯一在手的 AOSP 公开测试密钥，用于一切自签件」。
3. `DEVICE/README.md` §1「自签必须 AOSP testkey + rollback `1738713600` + 3 条 prop」**只适用 chained 分区（boot/recovery）**；
   `init_boot`/`vendor_boot`/`dtbo` 的 footer 是 `Algorithm NONE`、rollback 0、2 条/1 条 prop（本次实测），
   该句建议加限定词，否则下一次会有人给 init_boot 塞 3 条 prop + RSA4096（无害但不符合 stock）。
4. 新增可复用入口：`scripts/android-ksu-avb-build.py`（造件）、`scripts/android-ksu-flash.sh`（刷/回退）、
   `out/android-root-20261119/{MANIFEST.md,avb-recon-20261119.tsv,flash-dryrun-*.txt}`。
