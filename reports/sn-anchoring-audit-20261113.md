# SN 锚定审计（B12，2026-11-13，纯主机侧取证，未碰设备）

> 用户口径（2026-11-12）：以后全部显式锚定**原厂 SN**；认设备权威判据 = `fastboot getvar serialno`（只读）。
> 本轮只做静态取证：UEFI(Mu) 源码、initramfs 镜像内容、仓库资产。**未跑 fastboot/adb/ssh**。
> 回答 `TASKS/README.md`:145 的 ①②③ 与 ④。

## 结论一览

| 问 | 答案 | 一句话 |
|---|---|---|
| ① UEFI(Mu) 侧 SMBIOS/SerialNumber 是否锚原厂 SN | **否** | SMBIOS 串 = Qualcomm ChipInfo SoC 串号；UEFI 传给内核的 `androidboot.serialno` = **CRC32(UFS product_serial)** 的十六进制小写（U2 = `51318dc0`），**都不是** `fastboot getvar serialno` 的 `HA2EXB0E` |
| ② adb/Waydroid 侧是否暴露常量 SN | **未见暴露（低置信，待一发只读 getprop 钉死）** | 本项目 adb 全走 TCP（serial = `IP:5555`）；Waydroid 资产（buildtree/OTA zip/我们的 vendor 改动）里搜不到任何 serialno 覆盖 |
| ③ initramfs gadget 改动何时生效 | **下次重建 ramdisk 后** | 现役 `out/ramdisk-vk181-working.cpio.gz`（11-12 打包）内的 `usr/local/sbin/usb-gadget` **仍是写死 `HA2CB1KY` 的旧版**；`initramfs/usb-gadget`（动态取值）只有重跑 `scripts/build-initramfs.sh` + 重打 boot.img/换 `/boot/initrd.img` 才进设备 |

## ① UEFI(Mu) 侧 — 否（未锚原厂 SN），证据两处

树 = `build/uefi-woa-prep/repos/7-mu-lenovo`（7-mu-lenovo / AndromedaPkg，uefi-build-variant.sh 的构建树）。

1. **SMBIOS 串**（`Platforms/AndromedaPkg/Driver/SmBiosTableDxe/`）：
   - `SmBiosTableDxe.c:852` → `RetrieveSerialNumber(SerialNumberString)`；
   - `PlatformUtils.c:224-249`：`RetrieveSerialNumber()` 走 **`gEfiChipInfoProtocolGuid → GetSerialNumber()`**（Qualcomm ChipInfo 协议，**SoC/chip 串号**），`AsciiSPrint(..., "%lld", serial)` 十进制打印，喂给 SMBIOS Type1/Type2/Type3（`SmBiosTableDxe.c:709/726/739`）。
   - ⇒ SMBIOS SerialNumber ≠ 原厂零售 SN（`HA2EXB0E` 形态），也 ≠ fastboot SN。
2. **cmdline 的 `androidboot.serialno`**（`Platforms/QcomModulePkg/Library/BootLib/`）：
   - `Board.c:590-637 BoardSerialNum()`：取 **UFS MemCardInfo 的 `product_serial_num`，算 CRC32**，`"%x"` 十六进制小写；
   - `UpdateCmdLine.c:54,445-448`：该串拼进 ` androidboot.serialno=`。
   - **交叉实证**：`reports/uefi-p58-sdccdxe-handoff-success-20261107.md:50` 实测 UEFI 引导的内核 cmdline = `androidboot.serialno=51318dc0`，而该机 fastboot SN = `HA2EXB0E`（`DEVICE/README.md`）⇒ **UEFI 引导路径上，gadget 脚本从 cmdline 兜底拿到的会是 `51318dc0`（UFS CRC32），不是原厂 SN**。U 稳定但不等于权威判据。
   - 同理：UEFI 自己的 fastboot gadget serial 也是这个 CRC32 值（`scripts/uefi-oneshot.sh:13 UEFI_SERIAL:-51318dc0` 与实测吻合）。

**遗留动作（下轮建议）**：要么改 `BoardSerialNum()` 的取值源（需找到 ABL 读零售 SN 的协议——stock ABL 是怎么拿到 `HA2EXB0E` 的还没核），要么在 `/etc/elden-serial` 兜底文件里显式写原厂 SN 并把它排在 cmdline 之前。**在核实前，不要把 `51318dc0` 当目标机身份用。**

## ② adb / Waydroid 侧 — 未见常量 SN（低置信）

- 本项目**不存在 USB adb 通道**：gadget = CDC-NCM + 2×CDC-ACM（`initramfs/usb-gadget` / `rootfs/usb-gadget`，函数集里没有 ffs/adb）；host 侧 adb 均为 `adb connect 192.168.7.1:5555` ⇒ adb serial = **IP:5555**，与 SN 无关（ Waydroid 侧同理）。
- Waydroid 资产全量检索：`reference/waydroid-buildtree/`（产品配置/manifests）、`waydroid-ota/vendor/waydroid_arm64_only/`（MAINLINE vendor zip 名单）、`patches/waydroid-*`、`.pi/skills/waydroid-*` 中 **0 处** `ro.serialno`/serialno 覆盖 ⇒ 我们从未给容器设置过 SN；Lineage 20 base 的 `ro.serialno` 默认为空（TCP adb 不读它）。
- **未钉死的残余**：设备上容器内 `getprop ro.serialno` 的实际值（Lineage/Waydroid 可能自动填 hal 生成串）。**今晚只读采集可加一条**：`waydroid shell getprop ro.serialno; adb devices -l`，若出现常量/模板串再立条目。

## ③ initramfs gadget — 下次重建 ramdisk 才生效

- 真源链：`initramfs/usb-gadget`（已改动态取值）→ `scripts/build-initramfs.sh:72`（`sed > $R/bin/usb-gadget`…注意装到 ramdisk 内路径 `bin/`，而旧镜像里是 `usr/local/sbin/`，见下）→ ramdisk → boot.img。
- **实锤**：解包现役 `out/ramdisk-vk181-working.cpio.gz`（11-12 11:55 打包，即 `reports/uefi-vk188-fbcon-20261112.md` §3.3 换上的修好件）中的 `usr/local/sbin/usb-gadget`，第 37 行仍是 `echo "HA2CB1KY" > strings/0x409/serialnumber`；与 `initramfs/usb-gadget` `diff` = **DIFFERS**（取证副本 `/tmp/b12rd/usr/local/sbin/usb-gadget`）。
- ⇒ 「设备侧已部署」只对**磁盘根**（`/usr/local/sbin/usb-gadget`）成立；initramfs 内那份要等：`scripts/build-initramfs.sh full` → 重打 boot.img（或换 `/boot/initrd.img`）→ 重启。**注意 ①**：UEFI 引导时 cmdline 的 serialno 是 CRC32 值，动态版在 UEFI 路径拿到的串将是 `51318dc0`（仍是单机常量，但与 `fastboot getvar serialno` 不同）——见 ① 的遗留动作。

## ④ 权威判据重申

认设备只用：`fastboot getvar serialno`（只读，本轮未跑）或内核 `androidboot.serialno`（**stock ABL 路径**下=原厂 SN；**UEFI 路径**下=CRC32 串，见 ①）。不依赖 gadget iSerialNumber（两代值：旧 `HA2CB1KY` / 新动态值）。

## 证据命令（可复现）

```bash
# ① UEFI 侧
rg -n "RetrieveSerialNumber|GetSerialNumber" build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/AndromedaPkg/Driver/SmBiosTableDxe/
rg -n -A12 "BoardSerialNum" build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/QcomModulePkg/Library/BootLib/Board.c | sed -n '30,45p'
rg -n "UsbSerialCmdLine|StrSerialNum" build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/QcomModulePkg/Library/BootLib/UpdateCmdLine.c
# ③ ramdisk 内容
zcat out/ramdisk-vk181-working.cpio.gz | cpio -id --no-absolute-filenames usr/local/sbin/usb-gadget
diff usr/local/sbin/usb-gadget initramfs/usb-gadget
```
