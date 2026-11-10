#!/usr/bin/env bash
# grub-arm64-standalone.sh — 主机侧造 arm64-efi 的 standalone GRUB（G1-29「启动菜单」载荷）
#
# 用途：给 UEFI（Mu/p58 世代）一个可用 bootloader —— BDS 扫到 ESP 上的
#       \EFI\BOOT\BOOTAA64.EFI 后由它读 ext4(linux17) 的 kernel/initrd 起内核。
#       本脚本**纯主机侧**：只写 build/grub-arm64/，不碰设备、不 flash。
#
# 为什么需要它：Ubuntu(x86) 不提供 `grub-efi-arm64-bin`（只有 amd64/ia32 模块），
#   所以 arm64 模块得从 ubuntu-ports 的 arm64 deb 里取（解包即可用，不需要 arm64 主机）。
#
# 用法：
#   scripts/grub-arm64-standalone.sh                 # 造「前缀桩」件：只做 search+configfile，菜单留在设备 /boot/grub/grub.cfg
#   scripts/grub-arm64-standalone.sh --cfg FILE      # 把 FILE 整段嵌进去（离线菜单，设备上不可改）
#   scripts/grub-arm64-standalone.sh --modules "a b" # 覆盖模块集
#   scripts/grub-arm64-standalone.sh --clean         # 清缓存重建
#
# 产物：build/grub-arm64/grubaa64.efi（自校验：PE machine=0xAA64 + 嵌入的 cfg 能在字符串里找到）
#
# 设计取舍（2026-11-08）：默认做**前缀桩**而不是硬编码菜单——菜单随内核一起演进，
#   每次都重新打包 EFI 不现实；桩件在 ESP 上永不改，改菜单 = 改 linux17 上的一个文本文件。
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WORK:-$ROOT/build/grub-arm64}
DEB=grub-efi-arm64-bin_2.14-2ubuntu1_arm64.deb
DEB_SHA=532decc2dfd16f475cb5fbef0435c1c446cad822f519dcbc9f36b80f785e410d
URL=${URL:-https://mirrors.ustc.edu.cn/ubuntu-ports/pool/main/g/grub2-unsigned/$DEB}
MODULES=${MODULES:-"normal linux fdt ext2 fat disk part_gpt part_msdos search search_label search_fs_uuid echo test sleep reboot halt minicmd cat ls configfile"}
CFG=${CFG:-}
OUT=$WORK/grubaa64.efi

die() { echo "grub-arm64: $*" >&2; exit 1; }
say() { echo "[grub-arm64] $*" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --cfg)     CFG=$2; shift 2;;
    --modules) MODULES=$2; shift 2;;
    --clean)   CLEAN=1; shift;;
    -h|--help) sed -n '2,25p' "$0"; exit 0;;
    *) die "unknown arg: $1";;
  esac
done

command -v grub-mkstandalone >/dev/null || die "缺 grub-mkstandalone（apt install grub-common）"
[ -n "${CLEAN:-}" ] && { say "清缓存 $WORK"; rm -rf "$WORK"; }

mkdir -p "$WORK"
# ---------- 1. 取 arm64 模块（缓存 + sha 校验） ----------
MODDIR=$WORK/usr/lib/grub/arm64-efi
if [ ! -d "$MODDIR" ]; then
  if [ ! -f "$WORK/$DEB" ]; then
    say "下载 $URL"
    curl -s --noproxy '*' -fL --max-time 120 -o "$WORK/$DEB.part" "$URL" || die "下载失败（换 URL=… 重试）"
    mv "$WORK/$DEB.part" "$WORK/$DEB"
  fi
  got=$(sha256sum "$WORK/$DEB" | cut -d' ' -f1)
  [ "$got" = "$DEB_SHA" ] || die "deb sha 不符：期望 $DEB_SHA 实测 $got（镜像换版了？确认后改 DEB_SHA）"
  say "解包 $DEB"
  dpkg-deb -x "$WORK/$DEB" "$WORK" || die "dpkg-deb 解包失败"
fi
[ -d "$MODDIR" ] || die "解包后没有 $MODDIR"

# 2026-11-10：字体。Debian 的 `grub-efi-arm64-bin` **不带** unicode.pf2（它在 grub-common 里），
# 而 gfxterm 没有字体就退化成 EFI 文本模式 ⇒ 上机看到「Linux 通用 GRUB 小字菜单」（用户 2026-11-10 反馈）。
# 字体与架构无关，直接借宿主 /usr/share/grub/unicode.pf2 即可（grub-mkstandalone 按 -d 推出 …/share/grub）。
FONTDIR=$WORK/usr/share/grub
if [ ! -f "$FONTDIR/unicode.pf2" ]; then
  mkdir -p "$FONTDIR"
  if [ -f /usr/share/grub/unicode.pf2 ]; then
    cp /usr/share/grub/unicode.pf2 "$FONTDIR/unicode.pf2"
    say "补字体 $FONTDIR/unicode.pf2（取自宿主，$(stat -c%s "$FONTDIR/unicode.pf2") B）"
  else
    say "⚠ 宿主也没有 unicode.pf2（apt install grub-common）——gfxterm 会退化成文本模式"
  fi
fi

# ---------- 2. 嵌入的 cfg：默认「前缀桩」 ----------
EMBED=$WORK/embedded.cfg
if [ -n "$CFG" ]; then
  [ -r "$CFG" ] || die "读不到 --cfg $CFG"
  cp "$CFG" "$EMBED"
  say "嵌入外部菜单 $CFG（$(wc -c <"$EMBED") B）——设备上改不了，重建才生效"
else
  cat >"$EMBED" <<'EOF'
# ESP 上的 GRUB 桩：只负责找到 linux17（ext4）并把菜单交给 /boot/grub/grub.cfg
# ⇒ 换内核/改启动项 = 改 linux17 上的文本文件，不必重打本 EFI。
set timeout=30
search --no-floppy --label --set=root linux17
if [ -n "$root" ] && [ -f ($root)/boot/grub/grub.cfg ]; then
  set prefix=($root)/boot/grub
  configfile $prefix/grub.cfg
else
  echo "GRUB: 找不到 linux17:/boot/grub/grub.cfg —— 落到应急 shell"
  set prefix=($root)/boot/grub
fi
EOF
  say "嵌入前缀桩 cfg（$(wc -c <"$EMBED") B）"
fi

# ---------- 3. 打包 ----------
say "grub-mkstandalone -O arm64-efi（模块 $MODULES）"
grub-mkstandalone -O arm64-efi -d "$MODDIR" --modules="$MODULES" \
  -o "$OUT" "boot/grub/grub.cfg=$EMBED" || die "grub-mkstandalone 失败"
[ -s "$OUT" ] || die "产物为空"

# ---------- 4. 自校验（失败即红线，别上机） ----------
machine=$(aarch64-linux-gnu-objdump -f "$OUT" 2>/dev/null | sed -n 's/.*格式 \([a-z0-9-]*\).*/\1/p')
[ -n "$machine" ] || machine=$(python3 - "$OUT" <<'PY'
import sys,struct
d=open(sys.argv[1],'rb').read(0x100)
off=struct.unpack_from('<I',d,0x3c)[0]
m=struct.unpack_from('<H',d,off+4)[0]
print('pei-aarch64-little' if m==0xaa64 else 'machine=0x%04x'%m)
PY
)
case "$machine" in
  pei-aarch64-little) say "自校验 PE machine = ARM64 ✔";;
  *) die "产物不是 ARM64 EFI（objdump 说：$machine）——别上机";;
esac
# 嵌入的 cfg 必须真在镜像里（否则 grub 起来是空白菜单）
# 注：不能用 `strings | grep` 判定——cfg 里含中文，strings 只抓 ASCII 连续段会截断；
# 用字节搜索两组 ASCII 令牌（都命中才算嵌进去了）。
if [ -z "$CFG" ]; then
	python3 - "$OUT" <<'PY' || die "嵌入 cfg 不在产物里（memdisk 令牌未命中）"
import sys
blob = open(sys.argv[1], 'rb').read()
need = [b'set timeout=30', b'linux17', b'/boot/grub/grub.cfg']
miss = [t.decode() for t in need if t not in blob]
if miss:
    print('GRUB-ARM64-MISS: ' + ','.join(miss), file=sys.stderr)
    sys.exit(1)
PY
	say "自校验 嵌入 cfg 在产物里 ✔"
fi
say "产物 $OUT  $(stat -c%s "$OUT") B"
sha256sum "$OUT"
