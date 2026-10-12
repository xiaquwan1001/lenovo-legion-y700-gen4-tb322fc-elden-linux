#!/bin/bash
# q24-cseries-run.sh — Q24 C 系列：一次冷起内按序 C0(cam=0) → C1({camcc}) → C2({camcc,cambist})，
# 每步都做「真熄屏 → hold N s → 唤醒」，用于分离「blank / blank-hold / wake」三个致死点。
#
# 用法: scripts/q24-cseries-run.sh [boot.img] [label]
#   S3_MODE=blank+wake（默认）| blank-only    HOLD=60（每步保持窗秒数）  SETTLE=20（加载后静置）
# 前提: 设备已在 fastboot，且起点是物理 POR。
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden; cd "$ROOT" || exit 1
IMG=${1:-out/boot-elden-lv64-nocam.img}
LABEL=${2:-cseries}
MODE=${S3_MODE:-blank+wake}
HOLD=${HOLD:-60}
SETTLE=${SETTLE:-20}
OUT=$ROOT/logs/q24-$LABEL-$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"; echo "$OUT" > /tmp/q24_last_out
TAB=root@192.168.7.1
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes -o ServerAliveInterval=5 -o ServerAliveCountMax=2)
S(){ timeout "${2:-20}" "${SSH[@]}" "$TAB" "$1" 2>&1; }
alive(){ [ "$(S 'echo up' 8)" = "up" ]; }
log(){ printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$OUT/run.log"; }
mark(){ printf '%s %s\n' "$(wc -l < "$OUT/tracepipe.txt" 2>/dev/null || echo 0)" "$1" >> "$OUT/marks.txt"; }
DEATHS=()

# ---- 0) 前置 ----
timeout 20 fastboot devices > "$OUT/fastboot.txt" 2>&1 || true
grep -q fastboot "$OUT/fastboot.txt" || { log "FAIL: 设备不在 fastboot"; exit 2; }
timeout 15 fastboot getvar product > "$OUT/fb-probe.txt" 2>&1 || true
grep -q product "$OUT/fb-probe.txt" || { log "FAIL: bootloader 不应答 getvar（gadget 卡死）→ 需物理 POR"; exit 2; }
log "OUT=$OUT IMG=$IMG MODE=$MODE HOLD=${HOLD}s SETTLE=${SETTLE}s；$(tr '\n' ' ' < "$OUT/fb-probe.txt")"
sha256sum "$IMG" | tee "$OUT/image.sha256"
bash scripts/serial-logger.sh "$OUT/serial.log" >/dev/null 2>&1 &
LOGPID=$!; log "serial-logger pid=$LOGPID"

# ---- 1) 冷起 ----
log "fastboot boot $IMG"
timeout 180 fastboot boot "$IMG" > "$OUT/fastboot-boot.log" 2>&1
tail -3 "$OUT/fastboot-boot.log" | tee -a "$OUT/run.log"
up=0; for i in $(seq 1 40); do alive && { up=1; log "ssh up after $((i*5))s"; break; }; sleep 5; done
[ "$up" = 1 ] || { log "FAIL: 200s 内无 SSH"; exit 10; }

# ---- 2) 台架身份 ----
S 'uname -a; echo ---; cut -d. -f1 /proc/uptime; echo ---; cat /proc/cmdline' > "$OUT/s0-env.txt"
S 'cat /proc/sys/kernel/random/boot_id' > "$OUT/s0-bootid.txt"
log "$(head -1 "$OUT/s0-env.txt")"
for f in q24-dev-sess.sh q24-dev-blank.sh q24-dev-keepawake.sh q24-dev-snap.sh q24-dev-dstate.sh; do
  scp -q -o StrictHostKeyChecking=no "scripts/$f" "$TAB:/tmp/$f" || log "WARN: scp $f 失败"
done
S 'chmod +x /tmp/q24-dev-*.sh' >/dev/null

# ---- 3) 等会话 + 关自动熄屏 ----
# 会话就绪 = 必须拿到**真实布尔回复**（active=(true/false)），不接受 error 串
# （2026-10-12 教训：error 串里也有 'active='，会让 gate 误判通过）
ses=0; r=""
for i in $(seq 1 40); do
  r=$(S 'sh /tmp/q24-dev-blank.sh false 2>&1 | head -1' 10)
  case "$r" in *'active=(true'*|*'active=(false'*) ses=1; break;; esac
  sleep 5
done
[ "$ses" = 1 ] || { log "GATE_FAIL: 会话总线/ScreenSaver 无有效响应（最后一次: $r）"; S 'sh /tmp/q24-dev-dstate.sh' > "$OUT/abort-dstate.txt"; exit 4; }
# #198 台架健康前置检查：D 态里出现 合成器/Xwayland/GPU 捕获 ⇒ GPU/显示故障态，仪器必坏
S 'sh /tmp/q24-dev-dstate.sh' > "$OUT/s0-dstate.txt"
if grep -qiE 'phoc|phosh|Xwayland|gnome-session|gsd-|rpm_resume|a6xx|msm_gpu|msm_job_run|dma_fence' "$OUT/s0-dstate.txt"; then
  log "GATE_FAIL: 台架不健康（D 态含合成器/GPU：#198 故障态）见 s0-dstate.txt"; exit 4
fi
log "会话/台架健康门通过: $r"
S 'sh /tmp/q24-dev-keepawake.sh' | tee -a "$OUT/s0-keepawake.txt" | tee -a "$OUT/run.log"
S 'sh /tmp/q24-dev-snap.sh s0' > "$OUT/s0-snap.txt"
S 'sh /tmp/q24-dev-dstate.sh' > "$OUT/s0-dstate.txt"
S 'sh -s' < scripts/q28-devprobe2.sh > "$OUT/s0-q28probe.txt" 2>&1 || true
cat "$OUT/s0-snap.txt" "$OUT/s0-q28probe.txt" | tee -a "$OUT/run.log"

# ---- 4) trace ----
S 'grep -q debugfs /proc/mounts || mount -t debugfs none /sys/kernel/debug 2>/dev/null; echo 0 > /sys/kernel/debug/tracing/tracing_on; echo > /sys/kernel/debug/tracing/trace; echo 1 > /sys/kernel/debug/tracing/events/rpmh/enable; echo 1 > /sys/kernel/debug/tracing/tracing_on; echo trace_on' > "$OUT/s0-trace.txt"
timeout 2400 "${SSH[@]}" "$TAB" 'cat /sys/kernel/debug/tracing/trace_pipe' > "$OUT/tracepipe.txt" 2>&1 &
TPID=$!; sleep 2; mark "boot"; log "trace pid=$TPID lines=$(wc -l < "$OUT/tracepipe.txt")"
died(){ if alive; then return 1; fi; log "DEATH: SSH 不通"; return 0; }

# ---- 5) 相位函数 ----
# phase_blank TAG HOLD：真熄屏 → hold → (可选)唤醒；返回 0=全程存活，1=死亡（DEATH_AT 已记）
phase_blank(){
  local tag=$1 hold=$2 t0 now v
  mark "$tag-blank-before"; t0=$(date +%s)
  S 'sh /tmp/q24-dev-blank.sh true' > "$OUT/$tag-blank.txt" 2>&1
  cat "$OUT/$tag-blank.txt" | tee -a "$OUT/run.log"
  v=$(awk "\$2==\"$tag-blank-before\"{print \$1}" "$OUT/marks.txt"); v=${v:-0}
  local votes; votes=$(tail -n +"$((v+1))" "$OUT/tracepipe.txt" 2>/dev/null | grep -cE 'addr: 0x30080|addr: 0x30000')
  local fin; fin=$(grep -o 'GATE_AFTER5 .*' "$OUT/$tag-blank.txt" | head -1)
  case "$fin" in *'active=(true'*) ;; *) log "$tag 硬门 FAIL(active): $fin";; esac
  case "$fin" in *'dpms=Off'*) ;; *) log "$tag 硬门 FAIL(dpms): $fin";; esac
  log "$tag 硬门: active/dpms=[$fin] mmcx/cx 票=$votes"
  # ★先判死：仪表有效时的死亡现场正好是 "dpms=Off + 票>0 + 随后失联"，active 读数会因会话崩溃而变 false
  if died; then log "DEATH_AT=$tag/blank（熄屏后 ≤14s；票=$votes）"; DEATHS+=("$tag/blank"); return 1; fi
  case "$fin" in *'active=(true'*) HG_A=1;; *) HG_A=0;; esac
  case "$fin" in *'dpms=Off'*) HG_D=1;; *) HG_D=0;; esac
  if [ "$HG_A" = 0 ] || [ "$HG_D" = 0 ] || [ "$votes" -eq 0 ]; then
    log "GATE_FAIL: $tag 仪表无效（需 3/3：active=true + dpms=Off + 降档票>0）⇒ 本台架不能用于 Q24，请物理 POR 重取"
    return 2
  fi
  sleep 8
  local i=0
  while [ "$i" -lt "$hold" ]; do
    if died; then log "DEATH_AT=$tag/blank-hold（熄屏后 +$(( $(date +%s) - t0 ))s，无唤醒动作）"; DEATHS+=("$tag/blank-hold"); return 1; fi
    sleep 15; i=$((i+15))
  done
  S 'sh /tmp/q24-dev-snap.sh '"$tag"'-post-hold' > "$OUT/$tag-post-hold.txt" 2>/dev/null
  mark "$tag-blank-after"
  if [ "$MODE" = "blank+wake" ]; then
    if ! alive; then log "DEATH_AT=$tag/wake?（唤醒前已失联）"; DEATHS+=("$tag/pre-wake"); return 1; fi
    log "$tag 唤醒（SetActive false）"
    mark "$tag-wake-before"
    S 'sh /tmp/q24-dev-blank.sh false' > "$OUT/$tag-wake.txt" 2>&1
    date '+%H:%M:%S WAKE_ISSUED' >> "$OUT/$tag-wake.txt"
    sleep 10
    if died; then log "DEATH_AT=$tag/wake（唤醒后 ≤10 s，blank 后 +$(( $(date +%s) - t0 ))s）"; DEATHS+=("$tag/wake"); return 1; fi
    mark "$tag-wake-after"
    S 'sh /tmp/q24-dev-snap.sh '"$tag"'-post-wake' > "$OUT/$tag-post-wake.txt" 2>/dev/null
    log "$tag 唤醒后存活（+$(( $(date +%s) - t0 ))s）"
  fi
  mark "$tag-end"
  return 0
}

# ---- 6) C0: cam=0 对照 ----
log "=== C0: cam=0 对照（硬门 + blank/hold/wake）==="
S 'sh /tmp/q24-dev-snap.sh c0' > "$OUT/c0-snap.txt"
phase_blank c0 "$HOLD"; RC=$?
if [ "$RC" = 2 ]; then log "ABORT: C0 仪表硬门失败（cam=0 都不能熄屏）⇒ 台架无效"; kill "$TPID" 2>/dev/null; exit 5; fi
[ "$RC" = 1 ] && { log "跳过 C1/C2"; C0DONE=1; }

# ---- 7) C1: camcc ----
if [ -z "${C0DONE:-}" ]; then
  log "=== C1: modprobe camcc-sm8750 → 静置 ${SETTLE}s → blank/hold/wake ==="
  S 'modprobe camcc-sm8750 && echo C1_LOAD_OK || echo C1_LOAD_FAIL' | tee -a "$OUT/run.log"
  sleep "$SETTLE"
  S 'sh /tmp/q24-dev-snap.sh c1' > "$OUT/c1-snap.txt"
  grep -E 'lsmod-cam|state_synced|genpd' "$OUT/c1-snap.txt" | tee -a "$OUT/run.log"
  phase_blank c1 "$HOLD"; RC=$?
  [ "$RC" = 2 ] && { log "ABORT: C1 仪表硬门失败"; kill "$TPID" 2>/dev/null; exit 5; }
  [ "$RC" = 1 ] && { log "跳过 C2"; C1DONE=1; }
fi

# ---- 8) C2: + cambist ----
if [ -z "${C0DONE:-}" ] && [ -z "${C1DONE:-}" ]; then
  log "=== C2: modprobe cambistmclkcc-sm8750 → 静置 ${SETTLE}s → blank/hold/wake ==="
  S 'modprobe cambistmclkcc-sm8750 && echo C2_LOAD_OK || echo C2_LOAD_FAIL' | tee -a "$OUT/run.log"
  sleep "$SETTLE"
  S 'sh /tmp/q24-dev-snap.sh c2' > "$OUT/c2-snap.txt"
  grep -E 'lsmod-cam|state_synced|genpd' "$OUT/c2-snap.txt" | tee -a "$OUT/run.log"
  phase_blank c2 "$HOLD" || true
fi

# ---- 9) 收口 ----
sleep 3; kill "$TPID" 2>/dev/null; sleep 1; pkill -P $$ 2>/dev/null; [ -n "${LOGPID:-}" ] && kill "$LOGPID" 2>/dev/null; true
log "=== marks ==="; cat "$OUT/marks.txt" | tee -a "$OUT/run.log"
for tag in c0 c1 c2; do
  v=$(awk "\$2==\"$tag-blank-before\"{print \$1}" "$OUT/marks.txt" 2>/dev/null); v=${v:-0}
  w=$(awk "\$2==\"$tag-wake-before\"{print \$1}" "$OUT/marks.txt" 2>/dev/null); w=${w:-0}
  vn=$(tail -n +"$((v+1))" "$OUT/tracepipe.txt" 2>/dev/null | grep -cE 'addr: 0x30080|addr: 0x30000')
  wn=$(tail -n +"$((w+1))" "$OUT/tracepipe.txt" 2>/dev/null | grep -cE 'addr: 0x30050|addr: 0x300d0|addr: 0x30080|addr: 0x30000')
  log "$tag: blank 段票=$vn（mmcx/cx）；wake 段票=$wn（gfx/gmxc/mmcx/cx）"
done
log "DEATHS=[${DEATHS[*]:-none}] ALIVE=$(alive && echo yes || echo no)"
log "DONE OUT=$OUT"
