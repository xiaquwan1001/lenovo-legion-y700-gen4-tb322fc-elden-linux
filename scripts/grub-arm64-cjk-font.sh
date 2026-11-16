#!/bin/bash
# grub-arm64-cjk-font.sh — 给 GRUB 嵌入菜单造「中文可用」的主字体（pf2）
#
# 为什么需要（2026-11-16 实测）：
#   ESP 的嵌入菜单 GRUB 原来用 DejaVu 系 `big.pf2`，**没有 CJK 字形** ⇒ 菜单标题里的中文/全角括号
#   在屏上渲染成「点」（`Linux vk192（UEFI 直载…）` → `Linux vk192. UEFI ....`）。
#   GRUB 菜单项**不折行**，所以中文标题还必须短；字体则可以直接换。
#
# 做法：从系统 CJK TTF 里**只抽菜单用到的字符**（pyftsubset，几十 KB），再用 grub-mkfont 造 pf2，
#   然后 `scripts/grub-arm64-arming-build.sh --cfg … --bigfont <pf2> --out …` 重打 EFI。
#   抽子集而不是整份 Noto CJK：整份 96 px 会到十几 MB，ESP 只有 ~64 MB 余量（PITFALLS #664）。
#
# 用法：
#   scripts/grub-arm64-cjk-font.sh --size 72 \
#       --titles out/grub-arm64-arming-20261116/arming-daily-v10-cjk.cfg \
#       --out build/grub-arm64/fonts/big-cjk72.pf2
#   # 不给 --titles 时，自动从 cfg 里的 menuentry 行取字符
# 依赖：pyftsubset（fonttools）、grub-mkfont（grub-common）、一份 CJK TTF/OTF/TTC
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SIZE=72
FONT="/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
FONTNUM=0
TITLES=
OUT=$ROOT/build/grub-arm64/fonts/big-cjk.pf2
TMP=$(mktemp -d)

die() { echo "[cjk-font] ERROR: $*" >&2; exit 1; }
say() { echo "[cjk-font] $*" >&2; }

while [ $# -gt 0 ]; do
	case "$1" in
		--size) SIZE=$2; shift 2;;
		--font) FONT=$2; shift 2;;
		--fontnum) FONTNUM=$2; shift 2;;
		--titles) TITLES=$2; shift 2;;
		--out) OUT=$2; shift 2;;
		-h|--help) sed -n '2,22p' "$0"; exit 0;;
		*) die "unknown arg: $1";;
	esac
done

command -v grub-mkfont >/dev/null || die "缺 grub-mkfont（apt install grub-common）"
command -v pyftsubset >/dev/null || die "缺 pyftsubset（pip install fonttools）"
[ -f "$FONT" ] || die "缺字体 $FONT"
[ -n "$TITLES" ] || die "缺 --titles（嵌入菜单 cfg）"
[ -f "$TITLES" ] || die "读不到 $TITLES"

# 1) 收集字符：menuentry 里的标题 + 可打印 ASCII + 常用全角标点/箭头
say "抽取字符集（标题 $TITLES）"
python3 - "$TITLES" "$TMP/chars.txt" <<'PY' || die "字符集生成失败"
import io, re, sys
cfg, out = sys.argv[1], sys.argv[2]
s = io.open(cfg, encoding='utf-8').read()
titles = re.findall(r'^\s*menuentry\s+"([^"]*)"', s, re.M)
if not titles:
    sys.exit("cfg 里没有 menuentry 标题")
chars = set("".join(titles))
chars |= set(chr(c) for c in range(0x20, 0x7f))
chars |= set("（）【】《》…、，。：；！？“”‘’—·↑↓←→")
io.open(out, "w", encoding="utf-8").write("".join(sorted(chars)))
print("  menuentry=%d glyphs_requested=%d" % (len(titles), len(chars)))
PY

# 2) 子集化 TTF
say "pyftsubset → $TMP/subset.ttf（只留上面那些字形）"
pyftsubset "$FONT" --font-number="$FONTNUM" --text-file="$TMP/chars.txt" \
	--output-file="$TMP/subset.ttf" --layout-features='*' || die "pyftsubset 失败"

# 3) 造 pf2
mkdir -p "$(dirname "$OUT")"
say "grub-mkfont -s $SIZE → $OUT"
grub-mkfont -s "$SIZE" -o "$OUT" "$TMP/subset.ttf" || die "grub-mkfont 失败"
[ -s "$OUT" ] || die "产物为空"

# 4) 自校验：每个标题里的汉字码位必须真的进了 pf2（按 BE u32 在文件里出现）
python3 - "$OUT" "$TITLES" <<'PY' || die "自校验失败"
import io, re, sys
pf2, cfg = sys.argv[1], sys.argv[2]
d = open(pf2, 'rb').read()
titles = re.findall(r'^\s*menuentry\s+"([^"]*)"', io.open(cfg, encoding='utf-8').read(), re.M)
missing = {}
for t in titles:
    for ch in t:
        if ord(ch) < 0x80:
            continue
        if d.count(ord(ch).to_bytes(4, 'big')) == 0 and d.count(ord(ch).to_bytes(4, 'little')) == 0:
            missing.setdefault(t, []).append(ch)
print("  pf2=%d B  titles=%d  missing=%s" % (len(d), len(titles), missing or "none"))
sys.exit(1 if missing else 0)
PY

say "完成：$OUT（$(stat -c%s "$OUT") B，$SIZE px）。重打 EFI："
say "  scripts/grub-arm64-arming-build.sh --cfg $TITLES --bigfont $OUT --out <EFI>"
rm -rf "$TMP"
