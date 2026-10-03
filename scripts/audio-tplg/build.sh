#!/bin/sh
# 构建 TB322FC 的 AudioReach topology (Lenovo-Y700-Gen4-tplg.bin)
# 依赖：m4, alsatplg（主机与设备 rootfs 均有）
# 用法：scripts/audio-tplg/build.sh
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
REPO="$HERE/../../stock-src/audioreach-topology"
OUT="$HERE/out"
NAME=SM8750-Lenovo-Y700-Gen4
CARD=Lenovo-Y700-Gen4
mkdir -p "$OUT"
m4 -I "$REPO" -I "$HERE" "$HERE/$NAME.m4" > "$OUT/$CARD.conf"
alsatplg -c "$OUT/$CARD.conf" -o "$OUT/$CARD-tplg.bin"
echo "built: $OUT/$CARD-tplg.bin ($(stat -c%s "$OUT/$CARD-tplg.bin") bytes)"
