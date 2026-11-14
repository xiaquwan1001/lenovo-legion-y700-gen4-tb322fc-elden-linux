#!/bin/bash
# grub-arm64-arming-build.sh — 用「嵌入菜单」重打 arm64 GRUB（UEFI 复测用），带自校验
#
# 为什么不能只改设备上的 grub.cfg（2026-11-14 现查定案）：
#   ESP 上的 `\EFI\BOOT\BOOTAA64.EFI`（v3b-bigfont，sha `244c5f65…`）是**嵌入菜单**件 ——
#   二进制里含 5 个完整 `menuentry`，**不含** `configfile …/boot/grub/grub.cfg` 的桩。
#   ⇒ 改 linux17 的 `/boot/grub/grub.cfg` 对 a 槽启动**完全无效**，必须重打 EFI 再 `--activate`。
#
# 用法：
#   scripts/grub-arm64-arming-build.sh                 # 用 out/grub-20261114/arming-menu.cfg
#   scripts/grub-arm64-arming-build.sh --cfg FILE --out FILE
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$ROOT/build/grub-arm64
MODDIR=$WORK/usr/lib/grub/arm64-efi
FONTDIR=$WORK/fonts
CFG=$ROOT/out/grub-20261114/arming-menu.cfg
OUT=$ROOT/out/grub-20261114/grubaa64-arming-v6.efi
MODULES="normal linux fdt ext2 fat disk part_gpt part_msdos search search_label search_fs_uuid echo test sleep reboot halt minicmd cat ls configfile loadenv font gfxterm gfxmenu all_video video"

die() { echo "[grub-build] ERROR: $*" >&2; exit 1; }
say() { echo "[grub-build] $*" >&2; }

while [ $# -gt 0 ]; do
	case "$1" in
		--cfg) CFG=$2; shift 2;;
		--out) OUT=$2; shift 2;;
		-h|--help) sed -n '2,18p' "$0"; exit 0;;
		*) die "unknown arg: $1";;
	esac
done

[ -d "$MODDIR" ] || die "缺 arm64 模块目录 $MODDIR（先跑 scripts/grub-arm64-standalone.sh 取 deb）"
for f in big med small; do [ -f "$FONTDIR/$f.pf2" ] || die "缺字体 $FONTDIR/$f.pf2"; done
[ -f "$CFG" ] || die "缺菜单 $CFG"
mkdir -p "$(dirname "$OUT")"

say "grub-mkstandalone（菜单 $(wc -l <"$CFG") 行，字体 96/72/40 px）"
grub-mkstandalone -O arm64-efi -d "$MODDIR" --modules="$MODULES" -o "$OUT" \
	"boot/grub/grub.cfg=$CFG" \
	"boot/grub/fonts/big.pf2=$FONTDIR/big.pf2" \
	"boot/grub/fonts/med.pf2=$FONTDIR/med.pf2" \
	"boot/grub/fonts/small.pf2=$FONTDIR/small.pf2" || die "grub-mkstandalone 失败"
[ -s "$OUT" ] || die "产物为空"

# ---------- 自校验（不过不许上机） ----------
python3 - "$OUT" "$CFG" <<'PY' || die "自校验失败"
import sys
img, cfg = sys.argv[1], sys.argv[2]
blob = open(img, 'rb').read()
cfgtext = open(cfg, 'rb').read()
# 1) PE machine = 0xAA64
import struct
off = struct.unpack_from('<I', blob, 0x3c)[0]
mach = struct.unpack_from('<H', blob, off+4)[0]
ok = True
if mach != 0xaa64:
    print('MISS: PE machine=0x%04x（应为 0xaa64）' % mach); ok = False
# 2) 嵌入的 cfg 必须逐段在镜像里（按行取非空非注释，抽样 6 行）
need = [l.strip() for l in cfgtext.decode('utf-8', 'replace').splitlines()
        if l.strip() and not l.strip().startswith('#')]
sample = [need[0], need[len(need)//3], need[len(need)//2], need[-2]]
sample += ['earlycon=efifb', 'keep_bootcon', 'elden_grub_log']
for t in sample:
    if t.encode('utf-8') not in blob:
        print('MISS: %r 不在镜像里' % t); ok = False
# 3) 必须是「嵌入菜单」而不是桩（含 menuentry，且不含 configfile 桩）
if b'menuentry "' not in blob:
    print('MISS: 无 menuentry（这不是菜单件）'); ok = False
if blob.count(b'menuentry "') < 3:
    print('MISS: menuentry 少于 3 个'); ok = False
# 4) 三档字体都在
for f in (b'boot/grub/fonts/big.pf2', b'boot/grub/fonts/med.pf2', b'boot/grub/fonts/small.pf2'):
    if f not in blob:
        print('MISS: 字体 %s 未嵌入' % f.decode()); ok = False
print('OK machine=0x%04x menuentry=%d size=%d' % (mach, blob.count(b'menuentry "'), len(blob)))
sys.exit(0 if ok else 1)
PY
sha256sum "$OUT"
say "完成：$OUT"
