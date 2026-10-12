#!/bin/bash
# q24-kill.sh [label] -- Q24 致死一次（配对 -> 熄屏 -> 唤醒），并在死前/死后各做一次 PMIC 寄存器 dump，
#   用于判定「复位原因」（PON/fault 位）；同时记录恢复期 USB 枚举形态（mainline gadget vs fastboot）。
# 用法: bash scripts/q24-kill.sh r9     环境变量: HOLD=20 SETTLE=20 RECOVER=300
set -uo pipefail
cd /home/xuqianhui1001/y700-elden || exit 1
LABEL=$1; [ -z "$LABEL" ] && LABEL=kill
ARM=$(printenv ARM 2>/dev/null || true); [ -n "$ARM" ] || ARM=pair
DOPMIC=$(printenv PMIC 2>/dev/null || true); [ -n "$DOPMIC" ] || DOPMIC=1
HOLD=$(printenv HOLD 2>/dev/null || true); [ -n "$HOLD" ] || HOLD=20
SETTLE=$(printenv SETTLE 2>/dev/null || true); [ -n "$SETTLE" ] || SETTLE=20
RECOVER=$(printenv RECOVER 2>/dev/null || true); [ -n "$RECOVER" ] || RECOVER=300
OUT=logs/q24-$LABEL-$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"; echo "$OUT" > /tmp/q24_last_out
TAB=root@192.168.7.1
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes -o ServerAliveInterval=5 -o ServerAliveCountMax=2)
S(){ timeout "${2:-25}" "${SSH[@]}" "$TAB" "$1" 2>&1; }
Sf(){ timeout 8 "${SSH[@]}" "$TAB" "$1" 2>&1; }
alive(){ local v; v=$(S "echo up" 10); [ "$v" = up ]; }
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$OUT/run.log"; }
died(){ if alive; then return 1; fi; log DEATH_SSH_GONE; return 0; }
PROD(){ lsusb 2>/dev/null | grep -E "18d1|1d6b:0104" | grep -oE "ID [0-9a-f]+:[0-9a-f]+ .*" | head -1; }
DEATH=no
alive || { log "FAIL: 设备不可达（fastboot=[$(timeout 8 fastboot devices 2>&1 | paste -sd/ -)]）"; exit 2; }
log "OUT=$OUT LABEL=$LABEL ARM=$ARM HOLD=$HOLD SETTLE=$SETTLE RECOVER=$RECOVER PMIC=$DOPMIC"
S "uname -r; cut -d. -f1 /proc/uptime; cat /proc/sys/kernel/random/boot_id; cat /proc/cmdline" > "$OUT/env.txt"
log "bench: $(head -1 "$OUT/env.txt") uptime=$(sed -n 2p "$OUT/env.txt") bootid=$(sed -n 3p "$OUT/env.txt")"
log "pre USB: $(PROD)"
bash scripts/serial-logger.sh "$OUT/serial.log" >/dev/null 2>&1 &
LOGPID=$!
for f in q24-dev-sess.sh q24-dev-blank.sh q24-dev-keepawake.sh q24-dev-snap.sh q24-dev-dstate.sh; do
  scp -q -o StrictHostKeyChecking=no "scripts/$f" "$TAB:/tmp/$f" || log "WARN scp $f"
done
S "chmod +x /tmp/q24-dev-*.sh" >/dev/null

# --- 会话门 ---
ses=0; r=""
for i in $(seq 1 40); do
  r=$(S "sh /tmp/q24-dev-blank.sh false 2>&1 | head -1" 12)
  case "$r" in *"active=(true"*|*"active=(false"*) ses=1; break;; esac
  sleep 5
done
[ "$ses" = 1 ] || { log "GATE_FAIL 会话无响应: $r"; exit 4; }
log "会话门通过: $r"
S "sh /tmp/q24-dev-keepawake.sh" > "$OUT/keepawake.txt" 2>&1

# --- 1) PMIC 基线（可关） ---
if [ "$DOPMIC" = 1 ]; then
log "== PMIC dump (pre) =="
bash scripts/q24-pmic-dump.sh $LABEL-pre > "$OUT/pmic-pre.log" 2>&1
grep -c "" "$OUT/pmic-pre.log" | { read n; log "pmic-pre: $n 行日志"; }
PRE_DIR=$(grep -o "OUT=.*" "$OUT/pmic-pre.log" | tail -1 | sed -e "s/OUT=//")
log "PMIC_PRE=$PRE_DIR"
fi

# --- 2) 配对 ---
S "modprobe -r cambistmclkcc-sm8750 camcc-sm8750 2>/dev/null; echo cleaned" > "$OUT/clean.txt" 2>&1
sleep 5
S "sh /tmp/q24-dev-snap.sh pre" > "$OUT/pre-snap.txt" 2>&1
grep lsmod-cam "$OUT/pre-snap.txt" | tee -a "$OUT/run.log"
case "$ARM" in
  cambist) S "modprobe cambistmclkcc-sm8750 && echo BIST_OK" | tee -a "$OUT/run.log"; sleep "$SETTLE";;
  camcc)   S "modprobe camcc-sm8750 && echo CC_OK" | tee -a "$OUT/run.log"; sleep "$SETTLE";;
  *)       S "modprobe camcc-sm8750 && echo CC_OK" | tee -a "$OUT/run.log"; sleep "$SETTLE"; S "modprobe cambistmclkcc-sm8750 && echo BIST_OK" | tee -a "$OUT/run.log"; sleep "$SETTLE";;
esac
S "sh /tmp/q24-dev-snap.sh pair" > "$OUT/pair-snap.txt" 2>&1
cat "$OUT/pair-snap.txt" | tee -a "$OUT/run.log"

# --- 3) 熄屏 -> hold -> 唤醒 ---
S "sh /tmp/q24-dev-blank.sh true" > "$OUT/blank.txt" 2>&1
cat "$OUT/blank.txt" | tee -a "$OUT/run.log"
date "+%H:%M:%S BLANK_ISSUED" >> "$OUT/blank.txt"
if died; then DEATH=blank; log "DEATH_AT=blank"; else
  log "熄屏存活，保持 $HOLD s"
  sleep "$HOLD"
  if died; then DEATH=blank-hold; log "DEATH_AT=blank-hold"; else
    S "sh /tmp/q24-dev-blank.sh false" > "$OUT/wake.txt" 2>&1
    date "+%H:%M:%S WAKE_ISSUED" >> "$OUT/wake.txt"
    cat "$OUT/wake.txt" | tee -a "$OUT/run.log"
    sleep 10
    if died; then DEATH=wake; log "DEATH_AT=wake"; else
      sleep 20
      if died; then DEATH=wake-late; log "DEATH_AT=wake-late"; fi
    fi
  fi
fi
log "DEATH=$DEATH"

# --- 4) 恢复观察（含枚举形态） ---
: > "$OUT/recovery.log"
rt0=$(date +%s)
while [ "$DEATH" != no ]; do
  e=$(( $(date +%s) - rt0 )); [ "$e" -gt "$RECOVER" ] && break
  up=$(Sf "echo up; cut -d. -f1 /proc/uptime; cat /proc/sys/kernel/random/boot_id" | paste -sd/ -)
  echo "+$e s usb=[$(PROD)] ssh=[$up]" >> "$OUT/recovery.log"
  case "$up" in up/*) log "设备回来了: usb=[$(PROD)] $up"; break;; esac
  sleep 8
done
log "USB_POST=$(PROD)"
tail -8 "$OUT/recovery.log" | tee -a "$OUT/run.log"

# --- 5) PMIC 复采 ---
if [ "$DEATH" != no ] && [ "$DOPMIC" = 1 ]; then
  log "== PMIC dump (post) =="
  bash scripts/q24-pmic-dump.sh $LABEL-post > "$OUT/pmic-post.log" 2>&1
  POST_DIR=$(grep -o "OUT=.*" "$OUT/pmic-post.log" | tail -1 | sed -e "s/OUT=//")
  log "PMIC_POST=$POST_DIR"
fi
kill "$LOGPID" 2>/dev/null; sleep 1; true
log "DONE DEATH=$DEATH OUT=$OUT"