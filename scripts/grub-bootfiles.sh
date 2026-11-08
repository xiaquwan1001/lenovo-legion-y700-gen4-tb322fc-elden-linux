#!/usr/bin/env bash
# grub-bootfiles.sh — 从 Android boot.img 取出「GRUB 直接启动」所需三件，并（可选）落到设备 /boot
#
# 背景（G1-29 后半）：UEFI 路线打通后，下一步 = 让 UEFI 侧的 bootloader（GRUB arm64-efi）
#   从 ext4(linux17) 直接读 kernel/initrd，绕开 boot_b 的 96 MiB 槽限制。
#   boot.img 里的 kernel 是 **gzip 压缩**的，GRUB 不认 ⇒ 必须先解出来；dtb 在 v2 头里是独立段。
#
# 用法：
#   scripts/grub-bootfiles.sh --boot-img out/boot-elden-vk184.img --out /tmp/bootfiles
#        只解包（纯主机侧）：产出 Image / initrd.img / elden.dtb + grub.cfg（cmdline 取 boot.img 头）
#   scripts/grub-bootfiles.sh --boot-img out/boot-elden-vk184.img --device root@192.168.7.1 --apply
#        解包后 scp 到设备 /boot/、并把 grub.cfg 写到 /boot/grub/grub.cfg（**只写 /boot，不碰分区表**）
#   scripts/grub-bootfiles.sh ... --device …            # 不加 --apply = 只打印将要做什么（默认干跑）
#
# 不做什么：不建 ESP、不改 GPT、不 flash（那是 scripts/g1-29-esp-*.sh + 用户批准的事）。
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BOOT_IMG=
OUT=${OUT:-/tmp/grub-bootfiles}
DEVICE=
APPLY=0

die() { echo "grub-bootfiles: $*" >&2; exit 1; }
say() { echo "[grub-bootfiles] $*" >&2; }

while [ $# -gt 0 ]; do
	case "$1" in
		--boot-img) BOOT_IMG=$2; shift 2;;
		--out)      OUT=$2; shift 2;;
		--device)   DEVICE=$2; shift 2;;
		--apply)    APPLY=1; shift;;
		-h|--help)  sed -n '2,22p' "$0"; exit 0;;
		*) die "unknown arg: $1";;
	esac
done
[ -n "$BOOT_IMG" ] || die "缺 --boot-img（例：--boot-img out/boot-elden-vk184.img）"
[ -r "$BOOT_IMG" ] || die "读不到 $BOOT_IMG"

mkdir -p "$OUT"
say "解包 $BOOT_IMG → $OUT"

# ---------- 1. 解包（v0/v2 头；kernel 若是 gzip 就解压成裸 Image） ----------
python3 - "$BOOT_IMG" "$OUT" <<'PY' || exit 1
import gzip, struct, sys, os
img, out = sys.argv[1], sys.argv[2]
d = open(img, 'rb').read()
magic = d[0:8]
if magic != b'ANDROID!':
    sys.exit(f'不是 Android boot.img（magic={magic!r}）')
ks, = struct.unpack_from('<I', d, 8)
rs, = struct.unpack_from('<I', d, 16)
ps, = struct.unpack_from('<I', d, 36)
hv, = struct.unpack_from('<I', d, 40)
cmdline = d[64:64+512].rstrip(b'\x00').decode()
extra = d[608:608+1024].rstrip(b'\x00').decode() if hv < 3 else ''
def page(n):  # 向上取整到页
    return ((n + ps - 1) // ps) * ps
ko = ps
roff = ko + page(ks)
k = d[ko:ko+ks]
r = d[roff:roff+rs]
doff = roff + page(rs)
if hv >= 2:
    ds, = struct.unpack_from('<I', d, 1648)
    dtb = d[doff:doff+ds]
else:
    dtb = b''
if k[:2] == b'\x1f\x8b':
    k = gzip.decompress(k)
open(os.path.join(out, 'Image'), 'wb').write(k)
open(os.path.join(out, 'initrd.img'), 'wb').write(r)
if dtb:
    open(os.path.join(out, 'elden.dtb'), 'wb').write(dtb)
print(f'  header v{hv} page={ps} kernel={len(k)} (解压后) ramdisk={len(r)} dtb={len(dtb)}', file=sys.stderr)
if k[:2] != b'MZ':
    print('  ⚠ Image 不是 EFI-stub PE（缺 CONFIG_EFI_STUB）⇒ GRUB 的 linux 命令起不来', file=sys.stderr)
open(os.path.join(out, 'cmdline.txt'), 'w').write((extra + ' ' + cmdline).strip())
PY

# ---------- 2. 生成设备侧 grub.cfg（cmdline 沿用 boot.img 头里的那串，只补 root=） ----------
CMDLINE=$OUT/cmdline.txt
[ -s "$CMDLINE" ] || die "没拿到 cmdline（$CMDLINE 为空）"
{
	cat <<'EOF'
# /boot/grub/grub.cfg —— 由 scripts/grub-bootfiles.sh 生成（改完可手改，重生成会覆盖）
set timeout=8
set default=0

menuentry "Elden Linux（GRUB 直启；内核/initrd 在 linux17）" {
  search --no-floppy --label --set=root linux17
  # 本板 Mu UEFI 是否经 EFI config table 传 DT 尚未验证 ⇒ 默认显式给 DTB（有 elden.dtb 才加这行）
  if [ -f ($root)/boot/elden.dtb ]; then devicetree ($root)/boot/elden.dtb; fi
  linux ($root)/boot/Image CMDLINE_PLACEHOLDER root=LABEL=linux17
  initrd ($root)/boot/initrd.img
}

menuentry "同内核 + initcall_debug（排障用）" {
  search --no-floppy --label --set=root linux17
  if [ -f ($root)/boot/elden.dtb ]; then devicetree ($root)/boot/elden.dtb; fi
  linux ($root)/boot/Image CMDLINE_PLACEHOLDER root=LABEL=linux17 initcall_debug
  initrd ($root)/boot/initrd.img
}

menuentry "UEFI 固件设置（重启）" { reboot }
menuentry "关机" { halt }
EOF
} > "$OUT/grub.cfg"
python3 - "$OUT/grub.cfg" "$CMDLINE" <<'PY'
import sys
cfg, cmdf = sys.argv[1], sys.argv[2]
cl = open(cmdf).read().strip()
# 去掉会与 GRUB 冲突/无意义的项：BOOT_IMAGE、重复 root=、androidboot.slot_suffix 保留（设备脚本按它判断）
parts = [t for t in cl.split() if not t.startswith('root=') and not t.startswith('BOOT_IMAGE=')]
txt = open(cfg).read()                     # 先读完再写（否则 'w' 会先把文件截成 0）
open(cfg, 'w').write(txt.replace('CMDLINE_PLACEHOLDER', ' '.join(parts)))
PY
say "生成 $OUT/grub.cfg（cmdline 取自 boot.img 头，$(wc -w <"$CMDLINE") 个参数）"
ls -l "$OUT"

# ---------- 3. 落到设备（只写 /boot） ----------
if [ -z "$DEVICE" ]; then
	say "未给 --device，结束（纯主机侧）"
	exit 0
fi
FILES="Image initrd.img grub.cfg"
[ -f "$OUT/elden.dtb" ] && FILES="$FILES elden.dtb"
if [ "$APPLY" != 1 ]; then
	say "干跑：将 scp 到 $DEVICE:/boot/ → $FILES，并 mkdir -p /boot/grub、写 /boot/grub/grub.cfg"
	say "确认无误后加 --apply"
	exit 0
fi
SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes $DEVICE"
$SSH 'mkdir -p /boot/grub && df -h /boot 2>/dev/null; ls -l /boot' || die "ssh 不通：$DEVICE"
for f in $FILES; do
	[ -f "$OUT/$f" ] || die "缺 $OUT/$f"
	scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$OUT/$f" "$DEVICE:/boot/$f" || die "scp $f 失败"
done
$SSH 'mv -f /boot/grub.cfg /boot/grub/grub.cfg && ls -l /boot /boot/grub' || die "写 /boot/grub/grub.cfg 失败"
say "已落设备：/boot/{Image,initrd.img$([ -f "$OUT/elden.dtb" ] && echo ,elden.dtb)}, /boot/grub/grub.cfg"
say "下一步（需用户批准）：建 ESP + 把 build/grub-arm64/grubaa64.efi 放到 \\EFI\\BOOT\\BOOTAA64.EFI —— 见 .pi/plans/2026-11-08-g1-29-menu-esp-p59.md"
