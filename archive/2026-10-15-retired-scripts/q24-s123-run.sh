#!/bin/bash
# q24-s123-run.sh — Q24 受控复现：冷起 → 仪表硬门 → S1 → S2 → S3。
#
# 用法:
#   scripts/q24-s123-run.sh out/boot-elden-lv64-nocam.img <label>          # 冷起 + 全序列
#   SKIP_BOOT=1 scripts/q24-s123-run.sh - <label>                          # 复用当前已启动的台架
# 前提: 设备在 fastboot（冷起模式）且起点是物理 POR；或 SKIP_BOOT=1 时设备已在台架里。
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden; cd "$ROOT" || exit 1
IMG=${1:-out/boot-elden-lv64-nocam.img}
LABEL=${2:-s123}
SKIP_BOOT=${SKIP_BOOT:-0}
S1_WAIT=${S1_WAIT:-60}
S2_WAIT=${S2_WAIT:-300}
S3_MODE=${S3_MODE:-blank+wake}
S3_HOLD=${S3_HOLD:-60}
OUT=$ROOT/logs/q24-$LABEL-$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"; echo "$OUT" > /tmp/q24_last_out
TAB=root@192.168.7.1
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes -o ServerAliveInterval=5 -o ServerAliveCountMax=2)
S(){ timeout "${2:-20}" "${SSH[@]}" "$TAB" "$1" 2>&1; }
alive(){ [ "$(S 'echo up' 8)" = "up" ]; }
log(){ printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$OUT/run.log"; }
mark(){ printf '%s %s\n' "$(wc -l < "$OUT/tracepipe.txt" 2>/dev/null || echo 0)" "$1" >> "$OUT/marks.txt"; }
died(){ if alive; then return 1; fi; log "DEATH: SSH 不通"; return 0; }
log "OUT=$OUT IMG=$IMG LABEL=$LABEL SKIP_BOOT=$SKIP_BOOT S1=${S1_WAIT}s S2=${S2_WAIT}s"

# --- 0) 前置 ---------------------------------------------------------------
if [ "$SKIP_BOOT" = 1 ]; then
  alive || { log "FAIL: SKIP_BOOT=1 但设备不可达"; exit 2; }
  log "复用当前台架（不重启）"
else
  timeout 20 fastboot devices > "$OUT/fastboot.txt" 2>&1 || true
  grep -q fastboot "$OUT/fastboot.txt" || { log "FAIL: 设备不在 fastboot（需物理 POR 进 fastboot）"; exit 2; }
  timeout 15 fastboot getvar product > "$OUT/fb-probe.txt" 2>&1 || true
  grep -q product "$OUT/fb-probe.txt" || { log "FAIL: bootloader 不应答 getvar（fastboot gadget 卡死）→ 需物理 POR"; exit 2; }
  log "bootloader 应答: $(tr '\n' ' ' < "$OUT/fb-probe.txt")"
  sha256sum "$IMG" > "$OUT/image.sha256"
  log "fastboot boot $IMG"
  timeout 180 fastboot boot "$IMG" > "$OUT/fastboot-boot.log" 2>&1
  tail -3 "$OUT/fastboot-boot.log" | tee -a "$OUT/run.log"
  up=0
  for i in $(seq 1 40); do alive && { up=1; log "ssh up after $((i*5))s"; break; }; sleep 5; done
  [ "$up" = 1 ] || { log "FAIL: 200s 内无 SSH"; exit 10; }
fi
# 串口 logger 始终启动（含 SKIP_BOOT；死亡现场唯一记录，2026-10-12 教训）
bash scripts/serial-logger.sh "$OUT/serial.log" >/dev/null 2>&1 &
LOGPID=$!
log "serial-logger pid=$LOGPID -> $OUT/serial.log"

# --- 1) 台架身份 -----------------------------------------------------------
S 'uname -a; echo ---; cut -d. -f1 /proc/uptime; echo ---; cat /proc/cmdline' > "$OUT/s0-env.txt"
S 'cat /proc/sys/kernel/random/boot_id' > "$OUT/s0-bootid.txt"
log "$(head -1 "$OUT/s0-env.txt")"

# --- 2) 设备侧脚本 ---------------------------------------------------------
for f in q24-dev-sess.sh q24-dev-blank.sh q24-dev-keepawake.sh q24-dev-snap.sh q24-dev-dstate.sh; do
  scp -q -o StrictHostKeyChecking=no "scripts/$f" "$TAB:/tmp/$f" || log "WARN: scp $f 失败"
done
S 'chmod +x /tmp/q24-dev-*.sh; ls -l /tmp/q24-dev-*.sh | wc -l'

# --- 3) 等会话就绪（phoc/gsd-screensaver/D-Bus 可用）-------------------------
ses=0
for i in $(seq 1 30); do
  r=$(S 'sh /tmp/q24-dev-blank.sh false 2>&1 | head -1' 8)
  case "$r" in *active=*) ses=1; break;; esac
  sleep 5
done
[ "$ses" = 1 ] || { log "GATE_FAIL: 会话/D-Bus 不可用（phoc-phosh 未起或总线不可达）"; S 'sh /tmp/q24-dev-dstate.sh' > "$OUT/s0-dstate.txt"; exit 4; }
log "会话就绪: $r"
S 'sh /tmp/q24-dev-keepawake.sh' | tee -a "$OUT/s0-keepawake.txt" | tee -a "$OUT/run.log"
S 'sh /tmp/q24-dev-snap.sh s0' > "$OUT/s0-snap.txt"
S 'sh /tmp/q24-dev-dstate.sh' > "$OUT/s0-dstate.txt"
S 'sh -s' < scripts/q28-devprobe2.sh > "$OUT/s0-q28probe.txt" 2>&1 || true
cat "$OUT/s0-snap.txt" "$OUT/s0-q28probe.txt" | tee -a "$OUT/run.log"

# --- 4) 仪表硬门（不加载相机模块，零风险）----------------------------------
S 'grep -q debugfs /proc/mounts || mount -t debugfs none /sys/kernel/debug 2>/dev/null; echo 0 > /sys/kernel/debug/tracing/tracing_on; echo > /sys/kernel/debug/tracing/trace; echo 1 > /sys/kernel/debug/tracing/events/rpmh/enable; echo 1 > /sys/kernel/debug/tracing/tracing_on; echo trace_on' >> "$OUT/s0-trace.txt"
timeout 2400 "${SSH[@]}" "$TAB" 'cat /sys/kernel/debug/tracing/trace_pipe' > "$OUT/tracepipe.txt" 2>&1 &
TPID=$!
sleep 2; mark "boot"
log "trace stream pid=$TPID lines=$(wc -l < "$OUT/tracepipe.txt")"
S 'sh /tmp/q24-dev-blank.sh false' > "$OUT/instr-wake.txt" 2>&1; sleep 2
mark "instr-before"
S 'sh /tmp/q24-dev-blank.sh true' > "$OUT/instr-blank.txt" 2>&1
sleep 4
if died; then log "仪表硬门期间设备已死（cam=0 竟然死？）"; else S 'sh /tmp/q24-dev-snap.sh instr' >> "$OUT/instr-snap.txt"; fi
sleep 2; mark "instr-after"
MB=$(awk '$2=="instr-before"{print $1}' "$OUT/marks.txt")
IVOTES=$(tail -n +"$((MB+1))" "$OUT/tracepipe.txt" 2>/dev/null | grep -cE 'addr: 0x30080|addr: 0x30000')
IA=$(grep -o 'SETACTIVE.*' "$OUT/instr-blank.txt" | head -1)
IFINAL=$(grep -o 'GATE_AFTER5 .*' "$OUT/instr-blank.txt" | head -1)
log "仪表硬门: $IFINAL | mmcx/cx 票=$IVOTES | $IA"
HG=0
case "$IFINAL" in *'active=(true'*) HG=$((HG+1));; esac
case "$IFINAL" in *'dpms=Off'*) HG=$((HG+1));; esac
[ "${IVOTES:-0}" -gt 0 ] && HG=$((HG+1))
if [ "$HG" -lt 3 ]; then
  log "GATE_FAIL: 仪表无效（需 3/3：GetActive=true + dpms=Off + 降档票），本台架不能用于 Q24 ⇒ 需物理 POR 重取台架"
  kill "$TPID" 2>/dev/null; exit 5
fi
log "仪表硬门 3/3 通过 ⇒ 台架可用于 Q24"
S 'sh /tmp/q24-dev-blank.sh false' > "$OUT/instr-wake2.txt" 2>&1

# --- 5) S1: 只 camcc ------------------------------------------------------
mark "s1-before"
log "S1: modprobe camcc-sm8750（不熄屏 ${S1_WAIT}s）"
S 'modprobe camcc-sm8750 && echo S1_LOAD_OK || echo S1_LOAD_FAIL' | tee -a "$OUT/run.log"
i=0; while [ $i -le "$S1_WAIT" ]; do
  died && { log "S1 期间死亡 (t=${i}s)"; break; }
  S 'sh /tmp/q24-dev-snap.sh s1' >> "$OUT/s1.txt"; i=$((i+10)); [ "$i" -le "$S1_WAIT" ] && sleep 10
done
mark "s1-after"; S 'sh /tmp/q24-dev-snap.sh s1-end' >> "$OUT/s1.txt"
grep -E '###|lsmod-cam|genpd' "$OUT/s1.txt" | tail -6 | tee -a "$OUT/run.log"

# --- 6) S2: + cambist -----------------------------------------------------
if alive; then
  mark "s2-before"
  log "S2: modprobe cambistmclkcc-sm8750（不熄屏 ${S2_WAIT}s）"
  S 'modprobe cambistmclkcc-sm8750 && echo S2_LOAD_OK || echo S2_LOAD_FAIL' | tee -a "$OUT/run.log"
  i=0; while [ $i -le "$S2_WAIT" ]; do
    died && { log "S2 期间死亡 (t=${i}s)"; break; }
    S 'sh /tmp/q24-dev-snap.sh s2' >> "$OUT/s2.txt"; i=$((i+20)); [ "$i" -le "$S2_WAIT" ] && sleep 20
  done
  mark "s2-after"; S 'sh /tmp/q24-dev-snap.sh s2-end' >> "$OUT/s2.txt"
  grep -E '###|lsmod-cam|genpd' "$OUT/s2.txt" | tail -6 | tee -a "$OUT/run.log"
else log "跳过 S2（设备已死）"; fi

# --- 7) S3: 真实熄屏 ------------------------------------------------------
if alive; then
  log "S3: 真实熄屏（mode=$S3_MODE hold=${S3_HOLD}s）"
  S 'sh /tmp/q24-dev-snap.sh s3-pre' > "$OUT/s3-pre.txt"
  S 'dmesg | tail -15' > "$OUT/s3-pre-dmesg.txt"
  mark "s3-blank-before"; BLANK_T0=$(date +%s)
  S 'sh /tmp/q24-dev-blank.sh true' > "$OUT/s3-blank.txt" 2>&1
  cat "$OUT/s3-blank.txt" | tee -a "$OUT/run.log"
  sleep 8
  if died; then log "DEATH_AT=blank（熄屏后 ≤14s）"; else
    S 'sh /tmp/q24-dev-snap.sh s3-post' > "$OUT/s3-post.txt"
    S 'dmesg | tail -20' > "$OUT/s3-post-dmesg.txt"
    log "S3: 熄屏后仍存活（+$(( $(date +%s) - BLANK_T0 ))s）⇒ ${S3_HOLD}s 保持窗（不唤醒）"
    i=0; while [ "$i" -lt "$S3_HOLD" ]; do
      died && { log "DEATH_AT=blank-hold（熄屏后 +$(( $(date +%s) - BLANK_T0 ))s，期间无任何唤醒动作）"; break; }
      sleep 15; i=$((i+15))
    done
    S 'sh /tmp/q24-dev-snap.sh s3-post-hold' > "$OUT/s3-post-hold.txt" 2>/dev/null
  fi
  mark "s3-blank-after"
  if [ "$S3_MODE" = "blank+wake" ] && alive; then
    log "S3: 唤醒（SetActive false）"
    mark "s3-wake-before"
    S 'sh /tmp/q24-dev-blank.sh false' > "$OUT/s3-wake.txt" 2>&1
    date '+%H:%M:%S WAKE_ISSUED' >> "$OUT/s3-wake.txt"
    sleep 10
    if died; then log "DEATH_AT=wake（唤醒后 ≤10s，blank 后 +$(( $(date +%s) - BLANK_T0 ))s）"; else log "S3: 唤醒后仍存活（+$(( $(date +%s) - BLANK_T0 ))s）"; fi
    mark "s3-wake-after"
  elif [ "$S3_MODE" = "blank+wake" ]; then log "跳过唤醒（设备已死）"; else log "S3_MODE=$S3_MODE：不唤醒"; fi
else log "跳过 S3（设备已死）"; fi

# --- 8) 收口 --------------------------------------------------------------
sleep 3; kill "$TPID" 2>/dev/null; sleep 1; pkill -P $$ 2>/dev/null; [ -n "${LOGPID:-}" ] && kill "$LOGPID" 2>/dev/null; true
log "=== marks ==="; cat "$OUT/marks.txt" | tee -a "$OUT/run.log"
log "=== trace 尾 6 行 ==="; tail -6 "$OUT/tracepipe.txt" | tee -a "$OUT/run.log"
log "=== S3 硬门 ==="
SB=$(awk '$2=="s3-blank-before"{print $1}' "$OUT/marks.txt" 2>/dev/null); SB=${SB:-0}
SW=$(awk '$2=="s3-wake-before"{print $1}' "$OUT/marks.txt" 2>/dev/null); SW=${SW:-0}
SV=$(tail -n +"$((SB+1))" "$OUT/tracepipe.txt" 2>/dev/null | grep -cE 'addr: 0x30080|addr: 0x30000')
WV=$(tail -n +"$((SW+1))" "$OUT/tracepipe.txt" 2>/dev/null | grep -cE 'addr: 0x30050|addr: 0x300d0|addr: 0x30080|addr: 0x30000')
log "blank 段(>=$SB) mmcx/cx 票=$SV；wake 段(>=$SW) gfx/gmxc/mmcx/cx 票=$WV"
log "ALIVE=$(alive && echo yes || echo no)"
log "DONE OUT=$OUT"
