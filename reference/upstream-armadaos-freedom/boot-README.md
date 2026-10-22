# Y700 四代引导构建与打包

适用于 TB322FC / SM8750。四代和五代共用 [kShimC 源码](../../lenovo-tb323fu/boot/kshim-success-source/README.md)，使用各自的机型配置、原厂 Android 输入和设备树。

| 用途 | 构建入口 |
|---|---|
| 原厂 Android + kShimC 菜单 | 本目录的 [build_android_boot.py](build_android_boot.py) |
| Linux 诊断环境或已安装的机身 Linux | [kshim-build-boot.py](../../../system_files/usr/libexec/armada/kshim-build-boot.py) |
| 系统内打包依赖 | [kshim-tools](../../../packages/kshim-tools/README.md) |

第一条路径只打包原厂 Android 基座，不包含 Linux、DTB 或 initramfs；第二条路径才负责四代 Linux 启动载荷。两条路径都使用 4 MiB 的 kShimC runtime。当前功能状态见[四代设备文档](../README.md)。

## 构建 4 MiB runtime

构建前先按[共享依赖准备指引](../../lenovo-tb323fu/boot/kshim-success-source/DEPENDENCIES.md)恢复 CrDK、picolibc、LVGL 与 libfdt，并核对固定版本；快照本身不包含这些目录，也不含可用的 Git 元数据。

runtime 由共享源码树构建（`K = devices/lenovo-tb323fu/boot/kshim-success-source`），
使用独立的 `tb322fc_android_defconfig`。配置名中的 `android` 不限制它只能显示 Android；Linux 条目由打包时的 manifest 提供。

```sh
# 在 K 源码树根目录
python3 tools/build_runtime.py --config configs/tb322fc_android_defconfig --out <runtime-out>
# 产物 <runtime-out>/kShimC.bin，必须恰好 4 MiB
```

该 profile 保留：QCOM_KEYS、QCOM_SPMI、debounce2、FRAMEBUFFER/LVGL、
UI 旋转 270、LVGL_BUFFER_BYTES=243712、
入场动画 0、STAR_CHART 主题、语言切换/中文/条目详情/Android 基座，
以及 KSHIM_MENU_POWER_ACTIONS、KSHIM_MENU_ADVANCED_ACTIONS、
KSHIM_MENU_SESSION_SETTINGS、KSHIM_QCOM_REBOOT。显式关闭：
KSHIM_QEMU_PLATFORM、KSHIM_TOUCH、KSHIM_SMP、KSHIM_UEFI_TEST_MENU、banner、
KSHIM_DEBUG_CONSOLE 与 KSHIM_BOOT_TIMING。设备信息为共享实现，无需新增选项。

## 原厂 Android 基座打包

runtime 构建、测试与打包在 Linux Docker 构建环境中执行；脚本本身不访问设备、不联网。
打包使用本目录的独立驱动（默认复用同级 TB323FU 的
`star-chart-build/repack_boot_v4.py`，也可用 `--repacker` 覆盖）：

```sh
python3 <repo>/devices/lenovo-tb322fc/boot/build_android_boot.py \
  --stock-boot <96MiB 原厂 boot.img> \
  --runtime   <4MiB kShimC.bin> \
  --packer    <MultiBootKernelPatcher> \
  --unpacker  <UnpackTool> \
  --avbtool   <avbtool 路径> \
  [--repacker <repack_boot_v4.py 路径>] \
  --out       <输出目录> \
  [--source-label <记录用标签>]
```

`--source-label` 仅作记录用途。

### 输入约束

- `--stock-boot` 必须是 96 MiB（100663296 字节）、魔数 `ANDROID!`、header
  版本 4、header_size 1584、ramdisk_size 0、signature_size 0，且带 AVB footer。
  内核直接从 boot header 的 kernel_size 处截取，无需单独的 `--stock-image`。
  应使用与本机 Android 版本匹配的自有原厂 boot 备份。
- 截取出的内核必须是 raw ARM64 Image：`ARM\x64` 魔数在 0x38、image_size>=64、
  非 `UNCOMPRESSED_IMG`、且不是 gzip。
- `--runtime` 必须恰好 4 MiB。

### 菜单与校验

菜单为 Android 基座（默认项）+ 设备信息 + 语言切换/中文 + 按键操作；电源、
高级与会话设置项已启用，调试串口、触屏与 SMP 已关闭。

离线检查覆盖 Manifest ABI 校验、字节级往返与 avbtool 校验。校验用的 AVB
元数据是**未签名**的，需要解锁 bootloader，无法保留原厂 Lenovo 签名。

## Linux 启动载荷打包

[`kshim-build-boot.py`](../../../system_files/usr/libexec/armada/kshim-build-boot.py) 目前只接受四代 `lenovo,elden` / `qcom,sm8750` 设备树，不适用于五代 Baldur。它提供两种布局：

| 布局 | 输入 | 默认启动项 |
|---|---|---|
| `--layout maintenance` | 显式提供 `--linux-image`、`--dtb`、`--initrd` 和 `--bootargs` | Android；可用 `--default-entry maintenance` 选择诊断环境 |
| `--layout installed` | 提供 `--installer-result` 与 `--boot-dir`，从安装结果选择内核、DTB 和 initramfs | 机身 Linux；可用 `--default-entry android` 改为 Android |

两种布局都需提供 `--stock-boot`、`--runtime`、`--packer`、`--unpacker`、`--repacker`、`--avbtool` 和独立的 `--out` 输出目录。`installed` 布局不能再手工传入另一组内核、DTB、initramfs 或命令行。

维护布局包含原厂 Android 和 Linux 诊断入口；安装布局增加机身 Linux，并让诊断入口共享同一份 Linux 内核、使用单独的 DTB。两者都不是五代的 TF 卡／机身八或九条目布局。打包过程校验布局、解包往返和 boot 封装，不执行刷写或重启。

## 更新衔接

系统内的 [`armada-kshim-prepare`](../../../system_files/usr/libexec/armada/armada-kshim-prepare) 负责从已部署系统准备输入，[`armada-kshim-sync`](../../../system_files/usr/libexec/armada/armada-kshim-sync) 负责调度打包、写入与回读。当前实现按四代设备树匹配，完整 OTA 流程仍待验证；本页的离线打包命令不替代该流程。
