# 任务 I — 新 M1 树（Linux 7.3-rc7）首轮上机对照镜像

> 日期：2026-10-13 · 纯主机侧，**未上机、未碰设备**（本会话未执行任何 fastboot/adb/EDL、未插拔、未按键）。
> 产物：`out/boot-elden-m1-73.img` + `out/boot-elden-m1-73.manifest` + 本报告。
> 新 M1 树 = `build/m1-upstream/clean-tree-73`（分支 `m1/clean-tree-7.3rc7`，tip `ed6f232d10`）。
> 参照 = 现役镜像 `out/boot-elden-vk126-c1.img`（85 340 160 B）。
> 纪律：只写 `out/` 与本报告；未改 TASKS/DEVICE/INDEX/RESOURCES/PITFALLS/versions/.githooks；未对 geekidos-linux 未知 ref 做 cat-file。

## §1 方法与参照

### 1.1 参照镜像（现役日常 vk126-c1）解包

```
$ python3 tools/mkbootimg/unpack_bootimg.py --boot_img out/boot-elden-vk126-c1.img --out /tmp/m1-73-ref
boot magic: ANDROID!
kernel_size: 20592012
ramdisk size: 64586468
dtb size: 149063
boot image header version: 2
page size: 4096
command line args: console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17 androidboot.slot_suffix=_b elden_nocamera=1

$ sha256sum out/boot-elden-vk126-c1.img /tmp/m1-73-ref/ramdisk /tmp/m1-73-ref/dtb
7e9f459ebc5f8e46e0aad1d2bba8abc9591fd5955ba4168e946030ff8dd4c391  out/boot-elden-vk126-c1.img
35823240fcd15b4b08e1219e9a849a9abaa997bca7c11fd7f3e6e477c9c0478c  /tmp/m1-73-ref/ramdisk
5d658a2ce48cdda9a0451aaef28b6c668fb76607f76e2f0648ee9194c0008c0d  /tmp/m1-73-ref/dtb
```

**参照做法（reports/c1-noworkaround-20261013.md + scripts/q28-build-daily-id.sh）**：日常镜像 = 在基准镜像上**只换内核**，ramdisk / DTB / cmdline 逐字节复用（`q28-build-daily-id.sh` 内 sha 断言）。故「同形换核」= 换内核 + 换 DTB，其余沿用。

### 1.2 参照 ramdisk 的模块形态（关键事实）

参照 ramdisk（`/tmp/vk94base/ramdisk`，sha `35823240…`，vk94/vk124/vk126 同源）解包：

```
$ gzip -dc /tmp/vk94base/ramdisk | cpio -idm --quiet   # 到 /tmp/refrd
$ find /tmp/refrd -name '*.ko*' | wc -l
0
$ ls /tmp/refrd/lib/modules
ls: cannot access '/tmp/refrd/lib/modules': No such file or directory
```

即：**参照镜像 ramdisk 内没有任何 .ko**；其日常运行的 =m 驱动（DISPCC/GPUCC 时钟、fastrpc、CCI、NFC…）来自**磁盘根** `/lib/modules/7.2.0-debug-vk64-…/`（设备 UFS）。这是一个必须处理的差异点（见 §1.4、§6）。

### 1.3 新 M1 树产物与 UTS

```
$ git -C build/m1-upstream/clean-tree-73 log --oneline -1
ed6f232d10 M1: drop the remaining vendor dm-default-key call sites (f2fs, blk_types)
$ ls -la build/m1-upstream/clean-tree-73/arch/arm64/boot/Image.gz \
        build/m1-upstream/clean-tree-73/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
20798473  …/Image.gz
  153262  …/sm8750-lenovo-elden.dtb
$ sha256sum …/Image.gz …/sm8750-lenovo-elden.dtb …/.config
78dbf7b16595edd24b41273d778e6a499893c9e2158b5c6c8aa24d1886e2c7a1  …/Image.gz
6c07499f4025c51a27256a45317cdd9d4ab41f22ad8082d6b8b112f140a8ab87  …/sm8750-lenovo-elden.dtb
78dd54532c07550d0ba4b825d794a4377cef7d7436ff598327a7011c782da72f  …/.config

$ make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- kernelrelease
7.3.0-rc7-debug-ged6f232d10e3
$ gzip -dc Image.gz | strings | grep -m1 '^Linux version' | sed 's/ (.*//'
Linux version 7.3.0-rc7-debug-ged6f232d10e3
```

`CONFIG_LOCALVERSION="-debug"` + `CONFIG_LOCALVERSION_AUTO=y` ⇒ UTS release 带 git 后缀 `-ged6f232d10e3`。**本镜像内核 UTS release = `7.3.0-rc7-debug-ged6f232d10e3`。**

### 1.4 新树 .config 与现役日常镜像 config 的差异（任务补充②）

现役日常 config = `/tmp/dailyid/.config`（= `patches/config-daily-c1`（sha `f008aae441af…`）把 `CONFIG_LOCALVERSION_AUTO` 钉为 `n`，sha `4025d21c3521…`，vk126 内核即用它构建）。

```
dailyid vars 4919   tree vars 4955
only in dailyid: 14   only in tree: 50   value differs: 1

value differs (dailyid -> tree):
  CONFIG_GPIO_REGMAP: m -> y

only in dailyid (14):
  CONFIG_ARCH_ENABLE_THP_MIGRATION=y
  CONFIG_ARM64_WORKAROUND_REPEAT_TLBI=y
  CONFIG_CRYPTO_DEV_FSL_CAAM_PRNG_API=y
  CONFIG_CRYPTO_DEV_QCE=m (+ AEAD/ENABLE_ALL/SHA/SKCIPHER/SW_MAX_LEN)
  CONFIG_CRYPTO_DEV_QCOM_RNG=m
  CONFIG_DRM_VRAM_HELPER=m
  CONFIG_HAVE_GENERIC_VDSO=y
  CONFIG_IPV6_MULTIPLE_TABLES=y
  CONFIG_PROC_SYSCTL=y
```

only-in-tree 50 项绝大多数是 **7.3 新增/改名的上游符号**（`ARCH_HAS_PMD_SOFTLEAVES`、`ARM64_ERRATUM_3821522`、`CLK_GLYMUR_/NORD_/HAWI_/SHIKRA_/MAILI_*` 等），属 7.2→7.3 正常增量，非人工改配。

**可比性判断**（差异是否大 → 是否需以现役 config 为准）：
- **差异小**（65 个符号 / ~4960，且 50 个是上游新符号），因此**按任务默认口径使用新树自带 .config（即已编译通过的构建身份）**，未对其重跑 `olddefconfig`、未重建内核。
- **但有一处实质可比性缺口**：树 config **缺 `CONFIG_IPV6_MULTIPLE_TABLES=y`**（`IP_ADVANCED_ROUTER`/`IP_MULTIPLE_TABLES` 两边都是 y），另缺 `CONFIG_PROC_SYSCTL=y`、`CONFIG_ARCH_ENABLE_THP_MIGRATION=y`。C1（Waydroid 原生出网，reports/c1-noworkaround-20261013.md）依赖 IPv6 策略路由 ⇒ **若本轮要顺带复核 C1，建议改用现役 config + `olddefconfig` 重建**；否则本轮仅作内核/引导/DTS 对照。详见 §6 未决 U2。
- `CONFIG_LOCALVERSION_AUTO` 日常=n、树=y：导致 UTS 串不同（7.2.0-debug-vk64-… vs 7.3.0-rc7-debug-ged6f232d10e3），即磁盘旧模块必然 vermagic 失配 —— 这正是本镜像必须在 ramdisk 内自带新模块的原因（§1.5）。

### 1.5 本镜像采用的「同形换核 + 自带模块」口径

- 内核、DTB：换新树产物。
- ramdisk：**参照 vk126 的 Alpine 根**（64 586 468 B，逐字节复用）**+ 一层新增 overlay**（新内核 UTS 的 =m 启动关键模块 + 模块加载器 + SSOT `/init`）。理由：参照镜像的 =m 时钟/驱动来自磁盘旧模块，对 7.3 UTS 必然失配而静默不加载；不补模块则**很可能点不亮屏**（`CLK_*_DISPCC=m`、`CLK_*_GPUCC=m`）。
- cmdline：与参照逐字相同（含 `elden_nocamera=1`）。
- dtbo：**不打包进 boot.img**；`fastboot boot` 不清 dtbo，处理见 §5。

## §2 构建命令与输出

### 2.1 模块构建（新树 config，与 Image.gz 同一次构建身份）

```
$ cd build/m1-upstream/clean-tree-73
$ make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules
  LD [M]  net/bridge/bridge.ko
  LD [M]  net/nfc/nfc.ko
  LD [M]  net/nfc/nci/nci.ko
  … modules rc=0
$ make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules_install \
      INSTALL_MOD_PATH=$PWD/out/modstage-m1-73
  … install rc=0
$ find out/modstage-m1-73 -name '*.ko' | wc -l
1497
$ ls out/modstage-m1-73/lib/modules/
7.3.0-rc7-debug-ged6f232d10e3
```

### 2.2 启动关键模块闭包（36 个）+ overlay 构建

对以下 root 取 `modprobe --show-depends` 依赖闭包，逐个 `aarch64-linux-gnu-strip --strip-debug`（`CONFIG_DEBUG_INFO=y` 使未 strip 的 .ko 很大：闭包 49 个 72 MB → strip 后 3.7 MB；本闭包 36 个）：

```
ROOTS="dispcc0-nord dispcc1-nord dispcc-glymur gcc-nord gcc-hawi gpucc-nord gpu2cc-nord
 negcc-nord nwgcc-nord segcc-nord videocc-hawi videocc-maili audiocorecc-shikra evacc-glymur
 tcsrcc-glymur camcc-glymur cambistmclkcc-sm8750 i2c-qcom-cci leds-qcom-flash wl2868c-regulator
 fastrpc rpmsg_ctrl nfc nci nxp-nci_i2c bridge veth fuse"
closure modules: 36
overlay ko count: 36  overlay uncompressed: 4.4M
overlay cpio.gz: 954643 B
```

overlay 内容：`lib/modules/$KV/kernel/…`（36 个 strip 后 .ko + depmod 生成的 modules.dep 等）、`/init`（= `rootfs/persistent-overlay/init` SSOT，含 payload 钩子）、`/usr/local/sbin/payload-modules-load.sh`（本镜像新增，加载 clk/gpu/fastrpc/cci/nfc/bridge/veth/fuse，见 `out/m1-73-payload-modules-load.sh`）。

### 2.3 ramdisk 与 boot.img 重打包

```
$ cat /tmp/m1-73-ref/ramdisk out/m1-73-overlay.cpio.gz > out/rootfs-m1-73.cpio.gz
ramdisk m1-73: 65541111 B

$ python3 tools/mkbootimg/mkbootimg.py --header_version 2 \
    --os_version 15.0.0 --os_patch_level 2025-08 \
    --kernel build/m1-upstream/clean-tree-73/arch/arm64/boot/Image.gz \
    --ramdisk out/rootfs-m1-73.cpio.gz \
    --dtb   build/m1-upstream/clean-tree-73/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb \
    --cmdline 'console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15
               clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17
               androidboot.slot_suffix=_b elden_nocamera=1' \
    --base 0x00000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
    --second_offset 0x00f00000 --tags_offset 0x00000100 --dtb_offset 0x01f00000 \
    --pagesize 4096 -o out/boot-elden-m1-73.img
image = 86503424 B (82 MiB)  limit 100663296   SIZE OK
4f0e10dab27d814b82f835adfea705a9ad280c68d87377d588eb4c1dc80d35bb  out/boot-elden-m1-73.img
```

（未走 `build-boot.sh`：该脚本会额外写 `out/boot-elden.img`；本任务要求不覆盖任何现有镜像。本次也未删改其它任何 out/*.img —— 见 §4 mtime。）

## §3 vermagic 与读回校验（全部从成品镜像读出）

### 3.1 解包成品 + 组件 sha

```
$ python3 tools/mkbootimg/unpack_bootimg.py --boot_img out/boot-elden-m1-73.img --out /tmp/m1-73-vfy
kernel_size:  20798473
ramdisk size: 65541111
dtb size:     153262
boot image header version: 2
command line args: console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on
  panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17
  androidboot.slot_suffix=_b elden_nocamera=1

$ sha256sum /tmp/m1-73-vfy/kernel /tmp/m1-73-vfy/ramdisk /tmp/m1-73-vfy/dtb
78dbf7b16595edd24b41273d778e6a499893c9e2158b5c6c8aa24d1886e2c7a1  kernel   (= 新树 Image.gz)
1a5c0bc806630406ebc38900c8c69b6c1bd9009bbbc220d66b9335b4cfb221e4  ramdisk
6c07499f4025c51a27256a45317cdd9d4ab41f22ad8082d6b8b112f140a8ab87  dtb      (= 新树 DTB)
```

### 3.2 内核 UTS（从成品镜像读回）

```
$ gzip -dc /tmp/m1-73-vfy/kernel | strings | grep -m1 '^Linux version' | sed 's/ (.*//'
Linux version 7.3.0-rc7-debug-ged6f232d10e3
```

### 3.3 ramdisk 组成为 `参照根 + overlay` 的字节级证明

```
$ SZREF=$(stat -c%s /tmp/m1-73-ref/ramdisk)   # 64586468
$ tail -c +$((SZREF+1)) /tmp/m1-73-vfy/ramdisk > /tmp/m1-73-ovl-from-artifact.cpio.gz
$ cmp /tmp/m1-73-ovl-from-artifact.cpio.gz out/m1-73-overlay.cpio.gz
   → 无输出（字节相同）
$ cat /tmp/m1-73-ref/ramdisk out/m1-73-overlay.cpio.gz | sha256sum
1a5c0bc806630406ebc38900c8c69b6c1bd9009bbbc220d66b9335b4cfb221e4  -
$ sha256sum /tmp/m1-73-vfy/ramdisk
1a5c0bc806630406ebc38900c8c69b6c1bd9009bbbc220d66b9335b4cfb221e4  /tmp/m1-73-vfy/ramdisk
```

⇒ 成品 ramdisk = 现役参照根（未改动）与新增 overlay 的拼接。

### 3.4 模块数量与逐模块 vermagic（从成品镜像的 overlay 读出）

```
$ gzip -dc /tmp/m1-73-ovl-from-artifact.cpio.gz | cpio -it | grep -c '\.ko'
36
$ gzip -dc /tmp/m1-73-ovl-from-artifact.cpio.gz | cpio -idm   # 到 out/.m1-73-artifact-rd
$ find out/.m1-73-artifact-rd -name '*.ko' | wc -l
36

$ for ko in $(find out/.m1-73-artifact-rd -name '*.ko' | sort); do
    echo "$(basename $ko)  $(modinfo -F vermagic $ko | awk '{print $1}')"; done
audiocorecc-shikra.ko     7.3.0-rc7-debug-ged6f232d10e3
cambistmclkcc-sm8750.ko   7.3.0-rc7-debug-ged6f232d10e3
camcc-glymur.ko           7.3.0-rc7-debug-ged6f232d10e3
dispcc0-nord.ko           7.3.0-rc7-debug-ged6f232d10e3
dispcc1-nord.ko           7.3.0-rc7-debug-ged6f232d10e3
dispcc-glymur.ko          7.3.0-rc7-debug-ged6f232d10e3
evacc-glymur.ko           7.3.0-rc7-debug-ged6f232d10e3
gcc-hawi.ko               7.3.0-rc7-debug-ged6f232d10e3
gcc-nord.ko               7.3.0-rc7-debug-ged6f232d10e3
gpu2cc-nord.ko            7.3.0-rc7-debug-ged6f232d10e3
gpucc-nord.ko             7.3.0-rc7-debug-ged6f232d10e3
negcc-nord.ko             7.3.0-rc7-debug-ged6f232d10e3
nwgcc-nord.ko             7.3.0-rc7-debug-ged6f232d10e3
segcc-nord.ko             7.3.0-rc7-debug-ged6f232d10e3
tcsrcc-glymur.ko          7.3.0-rc7-debug-ged6f232d10e3
videocc-hawi.ko           7.3.0-rc7-debug-ged6f232d10e3
videocc-maili.ko          7.3.0-rc7-debug-ged6f232d10e3
i2c-qcom-cci.ko           7.3.0-rc7-debug-ged6f232d10e3
leds-qcom-flash.ko        7.3.0-rc7-debug-ged6f232d10e3
led-class-flash.ko        7.3.0-rc7-debug-ged6f232d10e3
mc.ko                     7.3.0-rc7-debug-ged6f232d10e3
v4l2-async.ko             7.3.0-rc7-debug-ged6f232d10e3
v4l2-flash-led-class.ko   7.3.0-rc7-debug-ged6f232d10e3
videodev.ko               7.3.0-rc7-debug-ged6f232d10e3
fastrpc.ko                7.3.0-rc7-debug-ged6f232d10e3
veth.ko                   7.3.0-rc7-debug-ged6f232d10e3
nxp-nci_i2c.ko            7.3.0-rc7-debug-ged6f232d10e3
nxp-nci.ko                7.3.0-rc7-debug-ged6f232d10e3
wl2868c-regulator.ko      7.3.0-rc7-debug-ged6f232d10e3
rpmsg_ctrl.ko             7.3.0-rc7-debug-ged6f232d10e3
fuse.ko                   7.3.0-rc7-debug-ged6f232d10e3
stp.ko                    7.3.0-rc7-debug-ged6f232d10e3
bridge.ko                 7.3.0-rc7-debug-ged6f232d10e3
llc.ko                    7.3.0-rc7-debug-ged6f232d10e3
nci.ko                    7.3.0-rc7-debug-ged6f232d10e3
nfc.ko                    7.3.0-rc7-debug-ged6f232d10e3

checked=36 mismatch=0
```

**结论（硬性要求 1）**：成品镜像 ramdisk 内 **36 个 .ko，逐个 `modinfo -F vermagic` 首字段 = `7.3.0-rc7-debug-ged6f232d10e3`，与成品内核 UTS release 逐字一致，0 失配。** 参照根内原本 0 个 .ko，故不存在旧 vermagic 残留。

### 3.5 模块加载器与 /init 钩子（从成品读出）

```
$ grep -c 'payload-modules-load' out/.m1-73-artifact-rd/init
2                                   # SSOT /init 调用 payload-modules-load.sh
$ ls -la out/.m1-73-artifact-rd/usr/local/sbin/payload-modules-load.sh
-rwxr-xr-x … 1281 … payload-modules-load.sh
$ grep -c 'dispcc0-nord' out/.m1-73-artifact-rd/usr/local/sbin/payload-modules-load.sh
1                                   # 加载器含显示/GPU 时钟 root
$ wc -l < out/.m1-73-artifact-rd/lib/modules/7.3.0-rc7-debug-ged6f232d10e3/modules.dep
36
```

### 3.6 镜像大小硬门

```
image = 86503424 B (82 MiB)   limit 96 MiB = 100663296 B   → SIZE_OK
```

## §4 镜像清单 sha256

| 对象 | 大小 (B) | sha256 |
|---|---|---|
| **out/boot-elden-m1-73.img**（交付） | 86 503 424 | `4f0e10dab27d814b82f835adfea705a9ad280c68d87377d588eb4c1dc80d35bb` |
| ├ kernel（镜像内，= 树 Image.gz） | 20 798 473 | `78dbf7b16595edd24b41273d778e6a499893c9e2158b5c6c8aa24d1886e2c7a1` |
| ├ ramdisk（镜像内） | 65 541 111 | `1a5c0bc806630406ebc38900c8c69b6c1bd9009bbbc220d66b9335b4cfb221e4` |
| └ dtb（镜像内，= 树 elden DTB） | 153 262 | `6c07499f4025c51a27256a45317cdd9d4ab41f22ad8082d6b8b112f140a8ab87` |
| 内核解压载荷 sha256（身份判据） | — | `ea2b77752336fc02325e60863bf43912f7c90fcefbd82792ad3eda6556deffdb` |
| out/rootfs-m1-73.cpio.gz | 65 541 111 | `1a5c0bc806630406ebc38900c8c69b6c1bd9009bbbc220d66b9335b4cfb221e4` |
| out/m1-73-overlay.cpio.gz | 954 643 | （见 manifest / overlay） |
| modstage-m1-73 模块总数 | 1497 | （KV = 7.3.0-rc7-debug-ged6f232d10e3） |
| 参照 out/boot-elden-vk126-c1.img | 85 340 160 | `7e9f459ebc5f8e46e0aad1d2bba8abc9591fd5955ba4168e946030ff8dd4c391` |

**未覆盖任何现有镜像**（mtime 证明；且未产生 `out/boot-elden.img`）：

```
-rw-rw-r-- 86503424 2026-10-13_19:56:14 out/boot-elden-m1-73.img      ← 本次新建
-rw-rw-r-- 85319680 2026-10-12_22:44:15 out/boot-elden-vk124-merged.img
-rw-rw-r-- 85319680 2026-10-13_06:59:25 out/boot-elden-vk125-resetterm.img
-rw-rw-r-- 85340160 2026-10-13_13:44:58 out/boot-elden-vk126-c1.img
$ ls out/boot-elden.img
ls: cannot access 'out/boot-elden.img': No such file or directory
```

新树 .config sha `78dd54532c07550d0ba4b825d794a4377cef7d7436ff598327a7011c782da72f`；manifest = `out/boot-elden-m1-73.manifest`。

## §5 上机步骤与回退（给用户；agent 未执行任何设备操作）

> 前置：**本镜像只 `fastboot boot`，不刷任何分区**。零写盘；出问题断电重启即回原状态。
> 该机对**连续/批量 fastboot 命令**容错差（PITFALLS #3）：下面每条**单独执行**，等它返回再敲下一条。

### 5.1 进入 fastboot（物理操作，只能由用户做）

- 关机后按住 **音量下 + 电源**（或按项目既有惯例组合）进 fastboot；主机侧 `fastboot devices` 应能列出。
- 若设备之前在 Linux 里，可直接在设备串口/SSH 里 `reboot bootloader`（若该钩子在本镜像可用）。

### 5.2 dtbo 说明（卡 logo 的唯一已知诱因）

- `fastboot boot` **不会清 dtbo**。ABL 会把槽内 dtbo（overlay）叠到我们的内嵌 DTB 上；若槽里是**原厂有效 dtbo**，可能叠加失败而**卡 logo**（PITFALLS #10/#1）。
- 现役日常镜像一直用 `fastboot boot` 且能点亮，说明两槽**当前已是假 dtbo（4 KB 全零）**；若如此则本步可**跳过**。
- 若卡 logo / 黑屏且确认是 dtbo 问题，用**假 dtbo**（`out/dtbo-dummy.img`，4096 B）覆盖两槽，**每条单独执行**：

```
fastboot flash dtbo_a out/dtbo-dummy.img
fastboot flash dtbo_b out/dtbo-dummy.img
```

（这是写操作；是否执行由用户决定。写后可读回校验：`fastboot getvar current-slot` / 观察 ABL 日志 `Dtbo hdr magic mismatch`。）

### 5.3 启动（单条命令）

```
fastboot boot out/boot-elden-m1-73.img
```

**预期现象**：fastboot 下载约 86.5 MB → 引导；串口 `/dev/ttyACM0`（CDC-ACM，`ttyGS0` 控制台，115200）出内核 log；USB gadget 重枚举有十几秒延迟（PITFALLS #7），之后主机出现 `enx…` / `ttyACM0`，设备 `usb0` = `192.168.7.1`，`ssh root@192.168.7.1`（无密码）。

**判据（逐条核对）**：
1. `uname -r` ⇒ `7.3.0-rc7-debug-ged6f232d10e3`（= 本报告 UTS）。
2. `lsmod | wc -l` ≥ 20（加载器应已载入显示/GPU 时钟等；见 `dmesg` 里 `[m1-73] loaded …`）。
3. 显示：`cat /sys/class/drm/card0-*/status` 之一为 `connected`（若仍有问题，先分模块/加载层，再判内核，见 PITFALLS #115）。
4. `dmesg | grep -iE 'error|fail|panic|Call trace'` 无新增致命项。

### 5.4 从未上机 ⇒ 可能起不来的恢复（用户只需物理操作）

| 现象 | 判据/含义 | 用户动作 |
|---|---|---|
| 黑屏 + 串口无输出，USB 无枚举 | 内核/DTB 早期挂 | **长按电源 ~10 s 断电重启**；设备完好回到原状态（本次零写盘）。 |
| 卡开机 logo | 多为 dtbo 叠加（§5.2） | 断电重启；需要时按 §5.2 覆盖假 dtbo 后再试。 |
| fastboot 报 `Failed to load/authenticate boot image: Load Error` | bootloader 脏态（PITFALLS #4） | 单条 `fastboot reboot bootloader`，等待，再单条 `fastboot boot …`。 |
| 能进系统但无显示 | 多半 =m 时钟模块未加载或 probe 失败 | 串口/SSH 登录，`dmesg | grep -i 'clk\|dispcc\|dpu\|dsi'`；把结论回填。 |
| 进入 Linux 后想退出 | RAM 启动 | 断电重启即回原系统；或在 `reboot`（本树无 reboot-mode，回到 fastboot，PITFALLS #2）。 |

**兜底**：本次未写任何分区/槽/dtbo（未执行 `fastboot flash`），故**不存在需要刷回的分区**；断电即恢复。

## §6 未决与未上机声明

**声明：本次为纯主机侧构建，镜像 `verification=NOT_TESTED_ON_DEVICE`。无设备证据，不写「已修复/可启动」。**

1. **未上机**：未见 BDS/串口/显示，一切「预期」均为静态推断。
2. **config 可比性（任务补充②）**：本镜像用新树自带 .config（差异小，65 符号；50 个为 7.3 新符号）。**未决**：树 config 缺 `CONFIG_IPV6_MULTIPLE_TABLES=y`（另缺 `PROC_SYSCTL`、`ARCH_ENABLE_THP_MIGRATION`）——若本轮要复核 C1（Waydroid 原生出网），应改用现役 config（`patches/config-daily-c1` 去 AUTO）+ 新树 `olddefconfig` 重建，并记录 `olddefconfig` 变更；届时需注意 PITFALLS #9（`olddefconfig` 会删 `CONFIG_ARCH_QCOM`，须回钉并做 System.map 符号守卫）。
3. **模块覆盖不全**：新树 config 有 **1497** 个 =m 模块，本 ramdisk 只带 **36** 个启动关键项。**磁盘根**（`elden_root=LABEL=linux17`）上的 `/lib/modules/7.2.0-debug-vk64-…` 对新 UTS **vermagic 失配 → 静默不加载**（PITFALLS #176）；因此任何**不在本 36 项内、又不在内核内建**的功能，本轮将不可用。已知**内建**（=y，不受影响）：ath12k、DRM panel、WCD939X、SC8280XP 声卡、aw86927、aw99706、DWC3、QMP PHY、pinctrl/icc/rpmh/scm。已知**未带且 =m**（本轮预期缺失）：相机媒体栈（qcom-camss、s5kjns/gc08a8/gt9764 等，且 cmdline `elden_nocamera=1` 本就抑制相机）、`CRYPTO_DEV_QCE`/`QCOM_RNG`、`V4L2_ISP`、部分 PHY（`PHY_QCOM_QUSB2` 等）、`st21nfca`（NFC 本镜像带的是 `nxp-nci`）。如需更多，可在首启后把 `out/modstage-m1-73` 对应模块 scp 到设备 `/lib/modules/7.3.0-rc7-debug-ged6f232d10e3/` 再 `depmod -a` + `modprobe`（**不是**零写盘操作，由用户决定）。
4. **DTB 变化**：新树 elden DTB 153 262 B（参照 149 063 B），是 7.3 重基后的 DTS 结果，未上机验证。
5. **/init 来源**：本镜像 overlay 用 `rootfs/persistent-overlay/init`（SSOT），相对参照 ramdisk 的 /init 仅多出 payload 钩子；相机 loader 不在 ramdisk 中且 cmdline `elden_nocamera=1`，故相机仍不加载（保持 Q24 口径）。
6. **模块 `--strip-debug`**：为压体积仅去调试节，`.modinfo`/vermagic 保留（§3.4 已逐个验证）。
7. **镜像大小**：86 503 424 B < 96 MiB 硬门（PITFALLS #6）；未走 `build-boot.sh` 以免覆盖 `out/boot-elden.img`。
8. **中间产物**：`out/modstage-m1-73/`、`out/.m1-73-ovl/`、`out/m1-73-overlay.cpio.gz`、`out/rootfs-m1-73.cpio.gz`、`out/m1-73-payload-modules-load.sh`、`out/.m1-73-artifact-rd/` 保留在 `out/` 供复核。

---

## 附：复现所需关键命令（主机侧）

```sh
# 0) 参照解包
python3 tools/mkbootimg/unpack_bootimg.py --boot_img out/boot-elden-vk126-c1.img --out /tmp/m1-73-ref
# 1) 新树模块
cd build/m1-upstream/clean-tree-73
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules_install \
     INSTALL_MOD_PATH=$PWD/../../out/modstage-m1-73
# 2) 闭包 + strip + overlay + cat + mkbootimg （见 §2.2/§2.3）
```
