#!/bin/bash
# Serve local Waydroid OTA (system+vendor) to the tablet over USB-Net.
# Fixes: sourceforge is unreachable/403 for some clients; host has a proxy,
# Motrix/aria2 does not. We download on the host (via proxy) and serve locally.
#
# usage: scripts/waydroid-ota-serve.sh [PORT]   (default 8800)
set -eu
PORT=${1:-8800}
HOST_IP=${HOST_IP:-192.168.7.2}
ROOT="$(cd "$(dirname "$0")/.." && pwd)/waydroid-ota"
DL="$HOME/下载"

SYS_ZIP="$DL/lineage-20.0-20260927-VANILLA-waydroid_arm64_only-system.zip"
VND_ZIP="$DL/lineage-20.0-20260927-MAINLINE-waydroid_arm64_only-vendor.zip"
SYS_DT=1790490369
VND_DT=1790493416

link() { # src dest
  [ -f "$1" ] || { echo "MISSING: $1" >&2; exit 1; }
  ln -sfn "$1" "$2"
}

SYS_DIR="$ROOT/system/lineage/waydroid_arm64_only"
VND_DIR="$ROOT/vendor/waydroid_arm64_only"

echo "[ota] sha256 system (699MB, please wait)..."
SYS_SHA=$(sha256sum "$SYS_ZIP" | cut -d' ' -f1)
SYS_SIZE=$(stat -c%s "$SYS_ZIP")
echo "[ota] sha256 vendor..."
VND_SHA=$(sha256sum "$VND_ZIP" | cut -d' ' -f1)
VND_SIZE=$(stat -c%s "$VND_ZIP")

link "$SYS_ZIP" "$SYS_DIR/$(basename "$SYS_ZIP")"
link "$VND_ZIP" "$VND_DIR/$(basename "$VND_ZIP")"

SYS_URL="http://$HOST_IP:$PORT/system/lineage/waydroid_arm64_only/$(basename "$SYS_ZIP")"
VND_URL="http://$HOST_IP:$PORT/vendor/waydroid_arm64_only/$(basename "$VND_ZIP")"

cat > "$SYS_DIR/VANILLA.json" <<JSON
{"response":[{"datetime":$SYS_DT,"filename":"$(basename "$SYS_ZIP")","id":"$SYS_SHA","romtype":"VANILLA","size":$SYS_SIZE,"url":"$SYS_URL","version":"20.0"}]}
JSON
cat > "$VND_DIR/MAINLINE.json" <<JSON
{"response":[{"datetime":$VND_DT,"filename":"$(basename "$VND_ZIP")","id":"$VND_SHA","romtype":"MAINLINE","size":$VND_SIZE,"url":"$VND_URL","version":"20.0"}]}
JSON

echo "[ota] serving $ROOT on http://$HOST_IP:$PORT/"
echo "[ota]   system: $SYS_URL  ($SYS_SHA)"
echo "[ota]   vendor: $VND_URL  ($VND_SHA)"
exec python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$ROOT"
