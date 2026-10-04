#!/bin/sh
# build-boot-slim.sh — G1-30（= G1-29 路线 C）：最小 initramfs 版 boot.img
#
# 背景：瓶颈是 ramdisk（完整 Alpine rootfs ~80 MB），不是内核（Image.gz ~20 MB）。
#       本脚本用 busybox 最小 initramfs（~1 MB），由 /init 解析 `elden_root=LABEL=linux17`
#       挂 ext4 持久根并 switch_root；rootfs/模块留在磁盘，boot.img 由 ~101 MB 降到 ~21 MB。
#
# 用法：
#   VERSION=vk52-slim sh scripts/build-boot-slim.sh
#
# ★ 必读：内核与磁盘 /lib/modules 必须同版本，否则相机/音频等模块全部加载失败。
#   本脚本只负责「打小镜像」，不负责重建内核/模块；内核版本取当前内核树 Image.gz。
set -eu
ROOT=${ROOT:-$HOME/y700-elden}
VERSION=${VERSION:?usage: VERSION=vkNN-slim sh scripts/build-boot-slim.sh}

KERNEL=$ROOT/linux/arch/arm64/boot/Image.gz
[ -f "$KERNEL" ] || { echo "missing $KERNEL" >&2; exit 1; }

# 内核 UTS（尽力探测）与 boot_b 分区大小
UTS=$(gzip -dc "$KERNEL" 2>/dev/null | strings 2>/dev/null | grep -m1 -o 'Linux version [^ ]*' || echo 'Linux version ?')
BOOT_B_SZ=$(printf '%d' 0x6000000)   # 96 MiB = 100663296

echo "[slim] kernel : $UTS"
echo "[slim] boot_b : $BOOT_B_SZ B (96 MiB)"
echo "[slim] 提示：确认磁盘 root 的 /lib/modules/<同版本> 存在，否则改用对应内核重打。"

RAMDISK_KIND=busybox VERSION="$VERSION" bash "$ROOT/scripts/build-boot.sh"

IMG=$ROOT/out/boot-elden-$VERSION.img
SZ=$(stat -c %s "$IMG")
echo "[slim] image  : $SZ B / $BOOT_B_SZ B"
[ "$SZ" -le "$BOOT_B_SZ" ] || { echo "[slim] FAIL: 超过 boot_b 分区" >&2; exit 1; }
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bash "$SCRIPT_DIR/grubfat-inspect.sh" "$IMG" | head -12
echo "[slim] OK  sha256=$(sha256sum "$IMG" | cut -d' ' -f1)"
echo "[slim] 回退: fastboot flash boot_b out/boot_b-vk49.img   （或 fastboot boot 零写盘试）"
