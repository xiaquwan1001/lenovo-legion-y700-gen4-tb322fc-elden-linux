#!/bin/bash
# build-payload-hook.sh — 往已有 ramdisk 追加「payload 加载钩子」最小层
#
# 背景（2026-10-09 教训）：vk77-modular 的 /init 里已有 payload 钩子，但**打包时漏了
# /usr/local/sbin/payload-modules-load.sh** ⇒ 钩子里 `[ -x ... ]` 判假、静默不加载，
# 表现为「模块化内核起来了但 lsmod 是空的」。模块本身在 ramdisk 里（39 个 .ko 齐）。
# 光看构建脚本"应该装了"不算数，必须从**产物镜像**里读回来验（PITFALLS §0 纪律 4）。
#
# 用法：
#   BASE=out/rootfs-overlaid-modular.cpio.gz bash scripts/build-payload-hook.sh
#   → out/rootfs-overlaid-modular-hook.cpio.gz   （base + 一层：/init + loader 脚本）
#
# 层叠机制与 build-camera-overlay.sh / build-modular-overlay.sh 相同：内核按顺序解包
# 多个连续 cpio，后者覆盖同名普通文件，所以这一层只放两个文件，不动 base 的字节。
set -euo pipefail
R=$(cd "$(dirname "$0")/.." && pwd)
BASE=${BASE:?需要 BASE=<base ramdisk cpio.gz>}
OUT=$R/out
INIT=${INIT:-$R/rootfs/persistent-overlay/init}
LOADER=${LOADER:-$R/scripts/payload-modules-load.sh}
NAME=$(basename "$BASE" .cpio.gz)
DST=${DST:-$OUT/$NAME-hook.cpio.gz}

for f in "$BASE" "$INIT" "$LOADER"; do [ -e "$f" ] || { echo "missing: $f" >&2; exit 1; }; done

# --- build the layer ----------------------------------------------------------
OVL=$OUT/.payload-hook
rm -rf "$OVL"; mkdir -p "$OVL/usr/local/sbin"
install -m 0755 "$INIT"   "$OVL/init"
install -m 0755 "$LOADER" "$OVL/usr/local/sbin/payload-modules-load.sh"
grep -q payload-modules-load "$OVL/init" || { echo "/init 里没有 payload 钩子：$INIT" >&2; exit 1; }

LAYER=$OUT/.payload-hook.cpio.gz
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(stat -c %Y "$INIT")}
( cd "$OVL" && find . -print0 | cpio --null -o -H newc --owner=0:0 --reproducible 2>/dev/null | gzip -9 ) > "$LAYER"

cat "$BASE" "$LAYER" > "$DST"
rm -rf "$OVL"

# --- verify from the ARTIFACT, not from the recipe ----------------------------
BASE=$BASE DST="$DST" python3 - <<'PY'
import gzip, os, re, subprocess, sys
def walk(path):
    buf = gzip.GzipFile(path, 'rb').read()
    inits, loader, ko = [], None, 0
    off = 0
    while off + 110 <= len(buf):
        if buf[off:off+6] != b'070701':
            nxt = buf.find(b'070701', off)
            if nxt < 0: break
            off = nxt; continue
        try:
            size = int(buf[off+54:off+62], 16); nsize = int(buf[off+94:off+102], 16)
        except Exception:
            break
        name = buf[off+110:off+110+max(nsize-1,0)]
        pad_n = (nsize+3) & ~3; pad_d = (size+3) & ~3
        if name == b'TRAILER!!!':
            off += 110 + pad_n; off = (off+511) & ~511; continue
        if name.lstrip(b'./') == b'init':
            inits.append(buf[off+110+pad_n:off+110+pad_n+size])
        if name.endswith(b'payload-modules-load.sh'):
            loader = size
        if name.endswith(b'.ko'): ko += 1
        off += 110 + pad_n + pad_d
    return inits, loader, ko

bi, bl, bko = walk(os.environ['BASE'])
di, dl, dko = walk(os.environ['DST'])
fails = []
if not di: fails.append('产物里找不到 /init')
if b'payload-modules-load' not in di[-1]: fails.append('最后一份 /init 里没有 payload 钩子')
if dl is None: fails.append('产物里没有 /usr/local/sbin/payload-modules-load.sh')
if dko < 1: fails.append('产物里没有 .ko（payload 模块包丢了）')
if dko < bko: fails.append(f'模块数比 base 少：{bko} -> {dko}')
print(f"base : init={len(bi)} loader={'yes' if bl else 'NO'} ko={bko}")
print(f"out  : init={len(di)} loader={dl} bytes ko={dko}  size={os.path.getsize(os.environ['DST'])}")
if fails:
    print('VERIFY FAIL: ' + '; '.join(fails)); sys.exit(1)
print('VERIFY OK: /init 钩子 + loader 脚本 + 模块包都在产物里')
PY

echo "base : $BASE"
echo "out  : $DST ($(du -h "$DST" | cut -f1))"
echo "next : VERSION=vkXX RAMDISK=$DST bash scripts/build-boot.sh"
