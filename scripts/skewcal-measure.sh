#!/bin/bash
# skewcal-measure.sh — 一次 M4 SKEW_CAL A/B 出流测量（设备是唯一串行资源 → 单次测量整体包在 device-lock 内）。
#
# usage: scripts/skewcal-measure.sh <label> [frames]
# 输出: LABEL=.. FRAMES=.. GOT=.. RC=.. SECS=.. FPS=.. ERR=.. NEWLINES=..
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"
UP=/home/xuqianhui/y700-elden/scripts/camera-stream-up.sh
DEVS=/tmp/skewcal-dev-measure.sh

LABEL=${1:-A1}
FRAMES=${2:-90}

# 设备端测量脚本（独立文件，避免 ssh 引号地狱）
cat > /tmp/skewcal-dev-measure.sh <<'DEVEOF'
#!/bin/sh
set -u
N=${1:-90}
# dmesg 环形缓冲已满（行数恒定）⇒ 用全量匹配计数做前后差分，不能用 tail -n +N
PAT='command DMA timeout|EPIPE|EINVAL|csiphy.*error|camss.*error'
err_before=$(dmesg | grep -ciE "$PAT")
sh /tmp/camera-stream-up.sh front >/tmp/skewcal-up.log 2>&1
rc_up=$?
t0=$(date +%s%N)
timeout $((N + 30)) v4l2-ctl -d /dev/video0 --stream-mmap --stream-count="$N" >/tmp/skewcal-stream.log 2>&1
rc=$?
t1=$(date +%s%N)
err_after=$(dmesg | grep -ciE "$PAT")
# 成功帧数 = v4l2-ctl 打印的帧标记 '<' 个数；fps 用它自己报的末行
 got=$(tr -dc '<' < /tmp/skewcal-stream.log | wc -c)
rep_fps=$(grep -oE '[0-9.]+ fps' /tmp/skewcal-stream.log | tail -1 | grep -oE '[0-9.]+')
echo "RESULT rc_up=$rc_up rc=$rc got=${got:-0} ns=$((t1 - t0)) err=$((err_after - err_before)) ebefore=$err_before eafter=$err_after repfps=${rep_fps:-?}"
echo "--- stream log tail ---"
tail -3 /tmp/skewcal-stream.log
echo "--- camera dmesg (last lines mentioning csiphy/camss/vfe/csid) ---"
dmesg | grep -iE "csiphy|camss|vfe|csid" | tail -6
DEVEOF

out=$("$ROOT/scripts/device-lock.sh" -w 900 bash -c "
  $SSH 'test -s /tmp/camera-stream-up.sh' || scp -q -o StrictHostKeyChecking=no '$UP' $TAB:/tmp/camera-stream-up.sh
  scp -q -o StrictHostKeyChecking=no '$DEVS' $TAB:$DEVS
  $SSH 'sh $DEVS $FRAMES'
" 2>&1)

printf '%s\n' "$out"
res=$(printf '%s\n' "$out" | grep -m1 '^RESULT ')
[ -n "$res" ] || { echo "MEASURE-FAILED label=$LABEL"; exit 1; }
got=$(printf '%s' "$res" | sed -n 's/.*got=\([0-9]*\).*/\1/p')
ns=$(printf '%s' "$res" | sed -n 's/.*ns=\([0-9]*\).*/\1/p')
err=$(printf '%s' "$res" | sed -n 's/.*err=\([0-9]*\).*/\1/p')
nl=$(printf '%s' "$res" | sed -n 's/.* ebefore=\([0-9]*\).*/\1/p')
rc=$(printf '%s' "$res" | sed -n 's/.* rc=\([0-9]*\).*/\1/p')
repfps=$(printf '%s' "$res" | sed -n 's/.*repfps=\([0-9.]*\).*/\1/p')
secs=$(awk -v n="${ns:-0}" 'BEGIN{printf "%.3f", n/1e9}')
fps=$(awk -v g="${got:-0}" -v n="${ns:-1}" 'BEGIN{printf "%.2f", (n>0? g/(n/1e9):0)}')
printf 'LABEL=%s FRAMES=%s GOT=%s RC=%s SECS=%s FPS=%s V4L2FPS=%s ERR=%s ERR_TOTAL_BEFORE=%s\n' \
  "$LABEL" "$FRAMES" "${got:-0}" "${rc:-?}" "$secs" "$fps" "${repfps:-?}" "${err:-?}" "${nl:-0}"
