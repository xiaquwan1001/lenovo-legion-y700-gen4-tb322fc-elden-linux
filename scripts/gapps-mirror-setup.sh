#!/bin/bash
# gapps-mirror-setup.sh — 把 GAPPS system 镜像接入本地 OTA 源（生成 GAPPS.json + 软链）
# 用法（主机执行）：scripts/gapps-mirror-setup.sh [PORT]
#   下载好的 zip 默认在 ~/下载/lineage-20.0-20260927-GAPPS-waydroid_arm64_only-system.zip
set -eu
PORT=${1:-8800}
HOST_IP=${HOST_IP:-192.168.7.2}
ROOT="$(cd "$(dirname "$0")/.." && pwd)/waydroid-ota"
DL="$HOME/下载"

GAPPS_ZIP="$DL/lineage-20.0-20260927-GAPPS-waydroid_arm64_only-system.zip"
SYS_DIR="$ROOT/system/lineage/waydroid_arm64_only"

[ -f "$GAPPS_ZIP" ] || { echo "MISSING: $GAPPS_ZIP" >&2; exit 1; }

echo "[gapps] sha256 (1.09GB, please wait)..."
GAPPS_SHA=$(sha256sum "$GAPPS_ZIP" | cut -d' ' -f1)
GAPPS_SIZE=$(stat -c%s "$GAPPS_ZIP")
echo "[gapps] sha256=$GAPPS_SHA size=$GAPPS_SIZE"

ln -sfn "$GAPPS_ZIP" "$SYS_DIR/$(basename "$GAPPS_ZIP")"

GAPPS_URL="http://$HOST_IP:$PORT/system/lineage/waydroid_arm64_only/$(basename "$GAPPS_ZIP")"
# datetime 与官方 20260927 build 一致（system 镜像同一 build 时间戳）
GAPPS_DT=1790490369

cat > "$SYS_DIR/GAPPS.json" <<JSON
{"response":[{"datetime":$GAPPS_DT,"filename":"$(basename "$GAPPS_ZIP")","id":"$GAPPS_SHA","romtype":"GAPPS","size":$GAPPS_SIZE,"url":"$GAPPS_URL","version":"20.0"}]}
JSON

echo "[gapps] wrote $SYS_DIR/GAPPS.json"
echo "[gapps] GAPPS_URL=$GAPPS_URL"
