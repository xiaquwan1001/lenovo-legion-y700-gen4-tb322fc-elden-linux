#!/bin/bash
# qemu-full-chain-smoke.sh — QEMU 复刻「AAVMF → GRUB → EFI-stub → vk188 内核 → 串口 dmesg」全链
# （B16，2026-11-13；替掉 UEFI 线拍屏取证。配方依据 reports/qemu-usage-survey-20261112.md §3
#   + 本轮实测修正，见 reports/qemu-full-chain-20261113.md）
#
# 判据（四条全绿 = PASS）：
#   1) 串口有 `Linux version`（vk188 UTS）
#   2) 串口有 `efi: EFI v2` （EFI-stub 交接成功，非 -kernel 直装）
#   3) 串口有 `Run /init as init process`
#   4) 串口有 `Console: switching to colour frame buffer device`（-device ramfb 下 fbcon 有后端）
#
# 用法：bash scripts/qemu-full-chain-smoke.sh [--keep] [IMAGE] [INITRD]
#   IMAGE   默认 out/vk188-bootfiles/Image（vk188 sysfbfb）
#   INITRD  默认 out/initramfs-slim.cpio.gz（thin initrd，QEMU 无 UDC/无 linux17，够判据）
#   --keep  保留 /tmp/qfc 工作区与 qemu 进程（调试用）
#
# 实测关键点（都是本轮踩过的）：
#   - **不要用 `-drive file=fat:rw:DIR`（vvfat）**：vvfat 对 ≥32 MiB 文件/长名不可靠，GRUB 报
#     `error: file '/boot/Image' not found`（本轮实测）；用 mkfs.vfat + pyfatfs 灌真镜像。
#   - `-M virt` 必须 `acpi=off`（本内核无 CONFIG_ACPI ⇒ build_all_zonelists 空指针 panic）。
#   - 内核阶段显示设备必须 `-device ramfb`（virtio-gpu 本内核无驱动）；串口判据用
#     `console=ttyAMA0,115200 earlycon=pl011,0x09000000`（设备的 ttyGS0/efifb 在 virt 上不存在）。
#   - GRUB cfg 必须显式 `search --no-floppy --file --set=root /boot/Image`（standalone 件不猜 root）。
#   - 单轮 ≈ 30–40 s（TCG，无 KVM）。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W=/tmp/qfc
KEEP=0; [ "${1:-}" = "--keep" ] && { KEEP=1; shift; }
IMAGE=${1:-$ROOT/out/vk188-bootfiles/Image}
INITRD=${2:-$ROOT/out/initramfs-slim.cpio.gz}
[ -f "$IMAGE" ] || { echo "缺 $IMAGE" >&2; exit 2; }
[ -f "$INITRD" ] || { echo "缺 $INITRD" >&2; exit 2; }
QEMU=${QEMU:-qemu-system-aarch64}
BIOS=${BIOS:-/usr/share/qemu-efi-aarch64/QEMU_EFI.fd}
[ -f "$BIOS" ] || { echo "缺 $BIOS（apt install qemu-efi-aarch64）" >&2; exit 2; }
command -v mkfs.vfat >/dev/null || { echo "缺 mkfs.vfat（dosfstools）" >&2; exit 2; }
python3 -c 'import pyfatfs' 2>/dev/null || pip install --user --break-system-packages --quiet pyfatfs

rm -rf "$W"; mkdir -p "$W"
# 1) GRUB standalone（含 search_fs_file；菜单内嵌）
cat > "$W/menu.cfg" <<'EOF'
set timeout=2
menuentry "qemu-smoke" {
  search --no-floppy --file --set=root /boot/Image
  linux ($root)/boot/Image console=ttyAMA0,115200 earlycon=pl011,0x09000000 keep_bootcon loglevel=8 ignore_loglevel panic=-1
  initrd ($root)/boot/initrd.img
}
EOF
WORK=$W/grub-build MODULES="normal linux fdt ext2 fat disk part_gpt part_msdos search search_label search_fs_file echo test sleep reboot halt minicmd cat ls configfile font gfxterm all_video efi_gop" \
  CFG=$W/menu.cfg GRUB_FONT_SIZE=40 bash "$ROOT/scripts/grub-arm64-standalone.sh" >&2 || exit 3

# 2) 真 FAT32 ESP（≈100 MB 够 64 MiB Image + initrd；不使用 vvfat，见头注）
dd if=/dev/zero of=$W/esp.img bs=1M count=320 2>/dev/null
mkfs.vfat -n ELDENQEMU $W/esp.img >/dev/null
python3 - "$W/esp.img" "$W/grub-build/grubaa64.efi" "$IMAGE" "$INITRD" <<'PY' || exit 3
import sys
from pyfatfs.PyFatFS import PyFatFS
img, efi, image, initrd = sys.argv[1:5]
fs = PyFatFS(img)
for d in ('/EFI','/EFI/BOOT','/boot'):
    try: fs.makedir(d)
    except Exception: pass
for src, dst in ((efi,'/EFI/BOOT/BOOTAA64.EFI'), (image,'/boot/Image'), (initrd,'/boot/initrd.img')):
    with open(src,'rb') as f, fs.openbin(dst,'w') as o:
        while True:
            b = f.read(1<<20)
            if not b: break
            o.write(b)
fs.close()
PY

# 3) 跑 QEMU（ramfb + 串口文件；最多 180 s）
timeout 180 $QEMU -M virt,acpi=off -cpu cortex-a72 -m 2048 -smp 4 \
  -bios "$BIOS" -drive file=$W/esp.img,format=raw,if=virtio \
  -display none -device ramfb -serial file:$W/serial.log \
  -monitor unix:$W/mon.sock,server,nowait >/dev/null 2>&1 &
QPID=$!
# 等 Linux version（GRUB 菜单 2 s + EFI ~5 s + 内核 ~15 s）
for _ in $(seq 1 36); do grep -q "Linux version" $W/serial.log 2>/dev/null && break; sleep 5; done
kill $QPID 2>/dev/null; wait $QPID 2>/dev/null

# 4) 判据
pass=0
chk() { if grep -aq "$1" $W/serial.log; then echo "PASS: $2"; pass=$((pass+1)); else echo "FAIL: $2"; fi; }
chk "Linux version"                    "J1 Linux version（内核真跑起来）"
chk "efi: EFI v"                       "J2 EFI-stub 交接（非 -kernel 直装）"
chk "Run /init as init process"        "J3 initramfs 执行到 /init"
chk "Console: switching to colour"     "J4 ramfb fbcon 有后端（simpledrm）"
echo "---- serial.log: $W/serial.log"
[ "$KEEP" = 1 ] || rm -rf "$W"
[ "$pass" = 4 ] && { echo "== FULL-CHAIN PASS (4/4)"; exit 0; } || { echo "== FULL-CHAIN FAIL ($pass/4)"; exit 1; }
