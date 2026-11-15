#!/usr/bin/env bash
# run.sh <tag> <memMB> <initrd-basename> [extra qemu args...]
set -u
TAG=$1; MEM=$2; INITRD=$3; shift 3
W=/tmp/qsay2; GRUBW=$W/grub-$TAG; ESP=$W/esp-$TAG
mkdir -p $GRUBW $ESP/EFI/BOOT $ESP/boot
cat > $W/menu-$TAG.cfg <<EOF
set timeout=2
set default=0
insmod all_video
insmod font
insmod gfxterm
insmod ext2
insmod fat
insmod part_msdos
insmod search
insmod linux
menuentry "qsay2 $TAG" {
  set root=(hd0,1)
  linux (\$root)/boot/Image console=ttyAMA0,115200 loglevel=8 ignore_loglevel efi=debug panic=0 rdinit=/nonexistent
  initrd (\$root)/boot/$INITRD
}
EOF
WORK=$GRUBW MODULES="normal linux ext2 fat part_msdos search search_label echo test sleep reboot halt minicmd cat ls configfile font gfxterm gfxmenu all_video video" \
  CFG=$W/menu-$TAG.cfg bash /home/xuqianhui/y700-elden/scripts/grub-arm64-standalone.sh >/dev/null 2>&1 || { echo "$TAG: grub build FAILED"; exit 1; }
cp $GRUBW/grubaa64.efi $ESP/EFI/BOOT/BOOTAA64.EFI
sync
timeout -k 5 120 qemu-system-aarch64 -M virt,acpi=off -cpu cortex-a72 -m $MEM -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -drive file=fat:rw:$ESP,format=raw,if=virtio \
  -display none -device ramfb -serial file:$W/log-$TAG.log "$@" >/dev/null 2>&1
echo "=== $TAG (mem=${MEM}M initrd=$INITRD) ==="
grep -aE "Unpacking|broken padding|no cpio|Freeing initrd|Loaded initrd|Failed to load initrd|Kernel panic|Initramfs" $W/log-$TAG.log | sed 's/\r//'
