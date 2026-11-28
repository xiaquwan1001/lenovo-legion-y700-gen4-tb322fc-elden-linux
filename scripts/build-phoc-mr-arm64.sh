#!/bin/bash
# build-phoc-mr-arm64.sh — 在 Debian sid arm64 chroot 里编译 phoc MR 分支（边缘返回手势）
#
# 用途：给上游 MR 提供 arm64（目标架构）编译证据 —— x86_64 宿主已编过一次，这只是补架构维度。
# 用法（需 root）：sudo bash scripts/build-phoc-mr-arm64.sh
# 产物：out/phoc-edge-swipe-arm64-<日期>/{phoc-edge-swipe, build.log, meta.txt}
set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SRC=${SRC:-$REPO/build/phoc-mr-20261128}
CH=${CH:-/opt/elden/arm64-sid}
DEST=$CH/build-phoc-mr-20261128
STAMP=$(date +%Y%m%d)
OUT=${OUT:-$REPO/out/phoc-edge-swipe-arm64-$STAMP}

[ "$(id -u)" = 0 ] || { echo "需要 root（chroot 构建）：sudo bash $0" >&2; exit 1; }
[ -d "$SRC" ] || { echo "缺源码树：$SRC" >&2; exit 1; }
[ -x "$CH/bin/sh" ] || { echo "缺 chroot：$CH" >&2; exit 1; }

mkdir -p "$OUT"
echo "=== 1/4 同步源码到 chroot（排除 build-host/.git）"
rm -rf "$DEST"
mkdir -p "$DEST"
tar -C "$SRC" --exclude=./build-host --exclude=./.git -cf - . | tar -C "$DEST" -xf -

echo "=== 2/4 meson setup（embed-wlroots 静态，与设备在版形态一致）"
chroot "$CH" /bin/sh -c "cd /build-phoc-mr-20261128 && \
  meson setup build -Dembed-wlroots=enabled -Dwlroots:default_library=static \
    -Dwlroots:renderers=gles2 -Dxwayland=disabled -Dtests=false" \
  2>&1 | tee "$OUT/build.log" | tail -20

echo "=== 3/4 ninja src/phoc"
chroot "$CH" /bin/sh -c "cd /build-phoc-mr-20261128 && ninja -C build src/phoc" \
  2>&1 | tee -a "$OUT/build.log" | tail -20

echo "=== 4/4 取产物 + 记录"
cp "$DEST/build/src/phoc" "$OUT/phoc-edge-swipe"
{
  echo "src=$SRC"
  echo "chroot=$CH"
  echo "built_at=$(date -Is)"
  echo "branch=$(git -C "$SRC" rev-parse --abbrev-ref HEAD 2>/dev/null || echo n/a)"
  echo "commit=$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo n/a)"
  echo "sha256=$(sha256sum "$OUT/phoc-edge-swipe" | awk '{print $1}')"
  file "$OUT/phoc-edge-swipe"
  echo "--- max GLIBC symbol version:"
  objdump -T "$OUT/phoc-edge-swipe" | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1
  echo "--- NEEDED:"
  objdump -p "$OUT/phoc-edge-swipe" | awk '/NEEDED/{print $2}' | sort | tr '\n' ' '; echo
} > "$OUT/meta.txt" 2>&1
cat "$OUT/meta.txt"
echo "OK → $OUT"
