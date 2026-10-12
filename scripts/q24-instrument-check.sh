#!/bin/bash
# q24-instrument-check.sh — 「熄屏仪表」有效性硬门（不加载任何相机模块，零风险）。
#
# 目的（PITFALLS #198）：在跑 Q24 的 S3 之前，先证明「真实熄屏」这条路径能把屏
# 关掉并产生 RPMh 降档票。任一不动 = 仪表坏 = Q24 不可测。
#
# 判据（三值）：
#   1) GetActive → true
#   2) /sys/class/drm/card0-DSI-1/dpms → Off
#   3) 熄屏后 RPMh trace 出现 mmcx.lvl(0x30080) 或 cx.lvl(0x30000) 票
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden; cd "$ROOT" || exit 1
OUT=$ROOT/logs/q24-instr-$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"; echo "$OUT" > /tmp/q24_last_instr
TAB=root@192.168.7.1
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes -o ServerAliveInterval=5)
S(){ timeout "${2:-20}" "${SSH[@]}" "$TAB" "$1" 2>&1; }
log(){ printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$OUT/run.log"; }

log "OUT=$OUT（instrument check；cam 不加载）"
sha256sum /tmp/dev-sess.sh /tmp/dev-blank.sh > "$OUT/device-scripts.sha256"
scp -q -o StrictHostKeyChecking=no /tmp/dev-sess.sh "$TAB:/tmp/q24sess.sh"
scp -q -o StrictHostKeyChecking=no /tmp/dev-blank.sh "$TAB:/tmp/q24blank.sh"
S 'chmod +x /tmp/q24sess.sh /tmp/q24blank.sh; sh /tmp/q24sess.sh; echo sess_rc=$?; echo "DB=$DBUS_SESSION_BUS_ADDRESS XDG=$XDG_RUNTIME_DIR"' | tee -a "$OUT/run.log"

S 'grep -q debugfs /proc/mounts || mount -t debugfs none /sys/kernel/debug 2>/dev/null; echo 0 > /sys/kernel/debug/tracing/tracing_on; echo > /sys/kernel/debug/tracing/trace; echo 1 > /sys/kernel/debug/tracing/events/rpmh/enable; echo 1 > /sys/kernel/debug/tracing/tracing_on; echo trace_on'
set -m
timeout 300 "${SSH[@]}" "$TAB" 'cat /sys/kernel/debug/tracing/trace_pipe' > "$OUT/tracepipe.txt" 2>&1 &
TPID=$!
sleep 2
MARK=$(wc -l < "$OUT/tracepipe.txt")
printf '%s instr-before\n' "$MARK" >> "$OUT/marks.txt"
log "trace stream pid=$TPID mark=$MARK"

log "=== 熄屏（SetActive true）==="
S 'sh /tmp/q24blank.sh true' | tee -a "$OUT/blank.txt" | tee -a "$OUT/run.log"
sleep 4
if ! S 'echo up' 8 >/dev/null; then
  log "设备在熄屏后失联（硬复位/hang）！"
else
  S 'sh /tmp/q24sess.sh; echo "ACTIVE=$(timeout 10 gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.freedesktop.DBus.Properties.Get org.gnome.ScreenSaver Active 2>&1)"; echo "DPMS=$(cat /sys/class/drm/card0-DSI-1/dpms)"; echo "UP=$(cut -d. -f1 /proc/uptime)"' | tee -a "$OUT/after.txt" | tee -a "$OUT/run.log"
fi
sleep 2
kill "$TPID" 2>/dev/null
VOTES=$(tail -n +"$((MARK+1))" "$OUT/tracepipe.txt" | grep -cE 'addr: 0x30080|addr: 0x30000')
log "熄屏后 mmcx/cx 票数=$VOTES"
VALUE=$(tail -n +"$((MARK+1))" "$OUT/tracepipe.txt" | grep -E 'addr: 0x30080|addr: 0x30000' | tail -6)
printf '%s\n' "$VALUE" | tee -a "$OUT/run.log"
# 复原：唤醒
if S 'echo up' 8 >/dev/null; then
  S 'sh /tmp/q24blank.sh false' | tee -a "$OUT/wake.txt"
  log "已唤醒（SetActive false）"
fi
log "DONE OUT=$OUT"
