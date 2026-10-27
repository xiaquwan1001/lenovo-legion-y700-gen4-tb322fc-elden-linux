#!/bin/bash
# skewcal-frame-stats.sh — 在锁内抓 N 帧存设备 /tmp，再用 python3 统计（distinct/stddev/非零占比）。
# 目的：fps/错误计数相同不代表像素正确；SKEW_CAL 影响的是链路采样相位。
# usage: scripts/skewcal-frame-stats.sh <label> [frames]
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"
LABEL=${1:-X}; N=${2:-3}

"$ROOT/scripts/device-lock.sh" -w 900 bash -c "
  $SSH 'sh /tmp/camera-stream-up.sh front >/dev/null 2>&1; rm -f /tmp/fr*.raw
    v4l2-ctl -d /dev/video0 --stream-mmap --stream-count=$N --stream-to=/tmp/fr.raw >/dev/null 2>&1
    python3 - <<EOF
import sys
d=open(\"/tmp/fr.raw\",\"rb\").read()
if not d:
    print(\"LABEL=$LABEL EMPTY\"); sys.exit()
n=len(d); nz=sum(1 for b in d if b)
vals=set(d)
mean=sum(d)/n
var=sum((b-mean)**2 for b in d)/n
print(\"LABEL=$LABEL BYTES=%d NONZERO_PCT=%.2f DISTINCT=%d MEAN=%.2f STDDEV=%.2f\"%(n,100.0*nz/n,len(vals),mean,var**0.5))
EOF
    rm -f /tmp/fr.raw'
"
