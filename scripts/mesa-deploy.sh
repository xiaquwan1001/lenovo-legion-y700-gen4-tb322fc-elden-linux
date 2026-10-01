#!/bin/bash
# mesa-deploy.sh — 把 extract-mesa-libs.sh 打好的 Mesa 包推到 Y700 设备并安装
#
# 用法：
#   DEVICE=root@192.168.7.1 bash mesa-deploy.sh
#   bash mesa-deploy.sh --rollback          # 只在设备上执行回退
set -euo pipefail

DEVICE="${DEVICE:-root@192.168.7.1}"
SRC="${SRC:-$HOME/mesa-out}"          # extract-mesa-libs.sh 的产出目录
HERE="$(cd "$(dirname "$0")" && pwd)"
REMOTE_TMP=/root/wd
REMOTE_NEW=/root/wd/mesa-new

log() { echo -e "\033[1;36m[deploy]\033[0m $*"; }

if [ "${1:-}" = "--rollback" ]; then
  log "在设备上回退…"
  scp "$HERE/waydroid-mesa-swap.sh" "$DEVICE:$REMOTE_TMP/"
  ssh "$DEVICE" "bash $REMOTE_TMP/waydroid-mesa-swap.sh rollback"
  exit 0
fi

TARBALL="$(ls -t "$SRC"/mesa-vendor-*.tar.gz 2>/dev/null | head -1 || true)"
[ -n "$TARBALL" ] || { echo "❌ 没找到 $SRC/mesa-vendor-*.tar.gz，先跑 extract-mesa-libs.sh"; exit 1; }
log "包: $TARBALL"

log "推送到 $DEVICE:$REMOTE_TMP/"
scp "$HERE/waydroid-mesa-swap.sh" "$TARBALL" "$DEVICE:$REMOTE_TMP/"

log "在设备上解包并安装"
ssh "$DEVICE" "
  set -e
  cd $REMOTE_TMP
  rm -rf $REMOTE_NEW && mkdir -p $REMOTE_NEW
  tar xzf '$(basename "$TARBALL")' -C $REMOTE_NEW
  bash $REMOTE_TMP/waydroid-mesa-swap.sh install $REMOTE_NEW
"
