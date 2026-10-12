#!/bin/bash
# q24-mech-run.sh — Q24 **机制取证轮**：一次冷起内加载 `{camcc,cambist}`，然后在**宽 tracepoint 集**下做
# 一次真实熄屏，把「死前最后一帧」抓全（clk / rpmh / regulator / power / drm 事件流）。
#
# 动机：H1（cambist DT 恢复上游 MMCX+MX）已否证（2026-10-12，同样死在熄屏）；DT 空间基本用尽 ⇒
#   下一步要的是**机制**而不是盲试臂。设备无 pstore，唯一 post-mortem = 主机侧 trace_pipe 流。
#
# 判据：死亡后看 tracepipe 尾部（最后一帧事件 + 最后一条 clk/rpmh 票）⇒ 指认「死在哪一步」。
# 用法: scripts/q24-mech-run.sh [boot.img] [label]   （前提：设备已在 fastboot，起点=物理 POR）
#       SKIP_BOOT=1 scripts/q24-mech-run.sh - <label>   复用当前已起的台架（不重启）
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden; cd "$ROOT" || exit 1
IMG=${1:-out/boot-elden-lv64-nocam.img}
LABEL=${2:-mech}
HOLD=${HOLD:-60}
SETTLE=${SETTLE:-20}
SKIP_BOOT=${SKIP_BOOT:-0}
TP=${TP:-'events/rpmh events/clk events/regulator events/power events/drm events/thermal'}
OUT=$ROOT/logs/q24-$LABEL-$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"; echo "$OUT" > /tmp/q24_last_out
TAB=root@192.168.7.1
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes -o ServerAliveInterval=5 -o ServerAliveCountMax=2)
S(){ timeout "${2:-20}" "${SSH[@]}" "$TAB" "$1" 2>&1; }
alive(){ [ "$(S 'echo up' 8)" = "up" ]; }
log(){ printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$OUT/run.log"; }
mark(){ printf '%s %s\n' "$(wc -l < "$OUT/tracepipe.txt" 2>/dev/null || echo 0)" "$1" >> "$OUT/marks.txt"; }
died(){ if alive; then return 1; fi; log "DEATH: SSH 不通"; return 0; }

# --- 0) 前置 ---
if [ "$SKIP_BOOT" = 1 ]; then
  alive || { log "FAIL: SKIP_BOOT=1 但设备不可达"; exit 2; }
  log "OUT=$OUT IMG=$IMG LABEL=$LABEL TP=[$TP]（复用当前台架）"
else
  timeout 20 fastboot devices > "$OUT/fastboot.txt" 2>&1 || true
  grep -q fastboot "$OUT/fastboot.txt" || { log "FAIL: 设备不在 fastboot"; exit 2; }
  timeout 15 fastboot getvar product > "$OUT/fb-probe.txt" 2>&1 || true
  grep -q product "$OUT/fb-probe.txt" || { log "FAIL: bootloader 不应答 getvar（gadget 卡死）→ 物理 POR"; exit 2; }
  log "OUT=$OUT IMG=$IMG LABEL=$LABEL TP=[$TP]"
  sha256sum "$IMG" | tee "$OUT/image.sha256"
fi
bash scripts/serial-logger.sh "$OUT/serial.log" >/dev/null 2>&1 &
LOGPID=$!; log "serial-logger pid=$LOGPID"

# --- 1) 冷起 ---
if [ "$SKIP_BOOT" != 1 ]; then
  log "fastboot boot $IMG"
  timeout 180 fastboot boot "$IMG" > "$OUT/fastboot-boot.log" 2>&1
  tail -3 "$OUT/fastboot-boot.log" | tee -a "$OUT/run.log"
  up=0; for i in $(seq 1 40); do alive && { up=1; log "ssh up after $((i*5))s"; break; }; sleep 5; done
  [ "$up" = 1 ] || { log "FAIL: 200s 内无 SSH"; exit 10; }
fi
S 'uname -a; echo ---; cut -d. -f1 /proc/uptime' > "$OUT/s0-env.txt"; log "$(head -1 "$OUT/s0-env.txt")"
for f in q24-dev-sess.sh q24-dev-blank.sh q24-dev-keepawake.sh q24-dev-snap.sh q24-dev-dstate.sh; do
  scp -q -o StrictHostKeyChecking=no "scripts/$f" "$TAB:/tmp/$f" || log "WARN: scp $f 失败"
done
S 'chmod +x /tmp/q24-dev-*.sh' >/dev/null

# --- 2) 会话 + 台架健康门（同 C 系列）---
ses=0; r=""
for i in $(seq 1 40); do
  r=$(S 'sh /tmp/q24-dev-blank.sh false 2>&1 | head -1' 10)
  case "$r" in *'active=(true'*|*'active=(false'*) ses=1; break;; esac
  sleep 5
done
[ "$ses" = 1 ] || { log "GATE_FAIL: ScreenSaver 无有效响应（$r）"; exit 4; }
S 'sh /tmp/q24-dev-dstate.sh' > "$OUT/s0-dstate.txt"
if grep -E '^D pid=[0-9]+ +/' "$OUT/s0-dstate.txt" >/dev/null || grep -qE 'a6xx_gmu_oob|a6xx_gmu_set_oob|msm_gpu_fault_crashstate_capture|msm_job_run' "$OUT/s0-dstate.txt"; then
  log "GATE_FAIL: 台架不健康（D 态含合成器/GPU：#198）"; exit 4
fi
S 'sh /tmp/q24-dev-keepawake.sh' | tee -a "$OUT/s0-keepawake.txt" >/dev/null
S 'sh /tmp/q24-dev-snap.sh s0' > "$OUT/s0-snap.txt"; cat "$OUT/s0-snap.txt" | tee -a "$OUT/run.log"
S 'sh -s' < scripts/q28-devprobe2.sh > "$OUT/s0-q28probe.txt" 2>&1 || true
grep -E 'VERDICT|l1=' "$OUT/s0-q28probe.txt" | tee -a "$OUT/run.log"

# --- 3) 宽 tracepoint + 流 ---
# 注意：events/enable 写 'Invalid argument' 是已知无害现象（逐目录 enable）
S "grep -q debugfs /proc/mounts || mount -t debugfs none /sys/kernel/debug 2>/dev/null;
   echo 0 > /sys/kernel/debug/tracing/tracing_on; echo > /sys/kernel/debug/tracing/trace;
   for d in $TP; do [ -d /sys/kernel/debug/tracing/\$d ] && echo 1 > /sys/kernel/debug/tracing/\$d/enable; done;
   echo 1 > /sys/kernel/debug/tracing/tracing_on; echo trace_on" > "$OUT/s0-trace.txt" 2>&1
S 'for d in /sys/kernel/debug/tracing/events/*/; do n=$(basename $d); [ "$(cat $d/enable 2>/dev/null)" != "0" ] && echo "$n=enabled"; done' | tee -a "$OUT/s0-trace-en.txt"
timeout 2400 "${SSH[@]}" "$TAB" 'cat /sys/kernel/debug/tracing/trace_pipe' > "$OUT/tracepipe.txt" 2>&1 &
TPID=$!; sleep 2; mark "boot"; log "trace pid=$TPID lines=$(wc -l < "$OUT/tracepipe.txt")"

# --- 4) 仪表硬门（cam=0）---
mark "instr-before"
S 'sh /tmp/q24-dev-blank.sh true' > "$OUT/instr-blank.txt" 2>&1
sleep 8
if died; then log "DEATH_AT=instr（cam=0 竟死）"; else
  fin=$(grep -o 'GATE_AFTER5 .*' "$OUT/instr-blank.txt" | head -1); log "instr 硬门: [$fin]"
  case "$fin" in *'active=(true'*) ;; *) log "GATE_FAIL: 仪器无效（active）"; kill "$TPID" 2>/dev/null; exit 5;; esac
  case "$fin" in *'dpms=Off'*) ;; *) log "GATE_FAIL: 仪器无效（dpms）"; kill "$TPID" 2>/dev/null; exit 5;; esac
  S 'sh /tmp/q24-dev-blank.sh false' > "$OUT/instr-wake.txt" 2>&1; log "仪器 3/3 通过，已唤醒"
fi

# --- 5) 加载配对 ---
mark "pair-load-before"
S 'modprobe camcc-sm8750 && echo CC_OK || echo CC_FAIL' | tee -a "$OUT/run.log"
sleep "$SETTLE"
S 'modprobe cambistmclkcc-sm8750 && echo BIST_OK || echo BIST_FAIL' | tee -a "$OUT/run.log"
sleep "$SETTLE"
S 'sh /tmp/q24-dev-snap.sh pair' > "$OUT/pair-snap.txt"; cat "$OUT/pair-snap.txt" | tee -a "$OUT/run.log"
S 'dmesg | tail -10' > "$OUT/pair-dmesg.txt"

# --- 6) 熄屏（不唤醒）---
mark "blank-before"; T0=$(date +%s)
S 'sh /tmp/q24-dev-blank.sh true' > "$OUT/blank.txt" 2>&1
cat "$OUT/blank.txt" | tee -a "$OUT/run.log"
sleep 8
if died; then log "DEATH_AT=blank（熄屏后 ≤14 s）"; else
  log "熄屏后仍存活 ⇒ 保持 ${HOLD}s（不唤醒）"
  i=0; while [ "$i" -lt "$HOLD" ]; do died && { log "DEATH_AT=blank-hold（+$(( $(date +%s) - T0 ))s）"; break; }; sleep 15; i=$((i+15)); done
fi
mark "blank-after"
sleep 3; kill "$TPID" 2>/dev/null; sleep 1; pkill -P $$ 2>/dev/null; [ -n "${LOGPID:-}" ] && kill "$LOGPID" 2>/dev/null; true

# --- 7) 死前最后一帧（机制取证）---
log "=== marks ==="; cat "$OUT/marks.txt" | tee -a "$OUT/run.log"
MB=$(awk '$2=="blank-before"{print $1}' "$OUT/marks.txt" 2>/dev/null); MB=${MB:-0}
log "=== blank 段事件直方图（按事件名）==="
tail -n +"$((MB+1))" "$OUT/tracepipe.txt" | grep -oE ': [a-z_0-9]+:' | sort | uniq -c | sort -rn | head -12 | tee -a "$OUT/run.log"
log "=== trace 最后 25 行 ==="
tail -25 "$OUT/tracepipe.txt" | sed 's/  */ /g' | tee -a "$OUT/run.log"
log "ALIVE=$(alive && echo yes || echo no) DONE OUT=$OUT"
