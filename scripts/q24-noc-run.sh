#!/bin/bash
# q24-noc-run.sh -- Q24 第 8 轮：NoC/BCM 差分 + 死法判定（PS_HOLD 掉电 vs SoC 挂死）
#   A（对照 cam=0）：blank(true) -> hold 60 -> wake(false)   预期存活
#   B（配对 camcc+cambist）：blank(true) -> hold 60 -> wake(false)   预期死亡
#   trace = interconnect + rpmh + clk + devfreq（设备侧 helper 先清空所有 events/*/enable）
#   死亡后主机侧观察 240 s：USB/ssh 是否回、boot_id 是否变 -> 判定死法
# 用法: scripts/q24-noc-run.sh [boot.img|-] [label]    "-" = 复用当前已起台架
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden; cd "$ROOT" || exit 1
IMG=$1; LABEL=$2
[ -z "$IMG" ] && IMG=out/boot-elden-lv64-nocam.img
[ -z "$LABEL" ] && LABEL=noc
HOLD=$(printenv HOLD 2>/dev/null || true); [ -n "$HOLD" ] || HOLD=60
SETTLE=$(printenv SETTLE 2>/dev/null || true); [ -n "$SETTLE" ] || SETTLE=20
RECOVER=$(printenv RECOVER 2>/dev/null || true); [ -n "$RECOVER" ] || RECOVER=240
TP=$(printenv TP 2>/dev/null || true); [ -n "$TP" ] || TP="events/interconnect events/rpmh events/clk events/devfreq"
SKIP_BOOT=0
case "$IMG" in -|skip|SKIP) SKIP_BOOT=1;; esac
OUT=$ROOT/logs/q24-$LABEL-$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"; echo "$OUT" > /tmp/q24_last_out
TAB=root@192.168.7.1
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes -o ServerAliveInterval=5 -o ServerAliveCountMax=2)
SSHF=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=4 -o BatchMode=yes)
S(){ timeout "${2:-25}" "${SSH[@]}" "$TAB" "$1" 2>&1; }
Sf(){ timeout 8 "${SSHF[@]}" "$TAB" "$1" 2>&1; }
alive(){ [ "$(S "echo up" 10)" = "up" ]; }
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$OUT/run.log"; }
mark(){ echo "$(wc -l < "$OUT/tracepipe.txt" 2>/dev/null || echo 0) $1" >> "$OUT/marks.txt"; }
markof(){ sed -n "/ $1$/p" "$OUT/marks.txt" 2>/dev/null | head -1 | cut -d" " -f1; }
died(){ if alive; then return 1; fi; log "DEATH: SSH 不通"; return 0; }
DEATHS=()
phase(){
  local tag=$1 hold=$2 t0 v fin HG_A HG_D votes i
  mark "$tag-blank-before"; t0=$(date +%s)
  S "sh /tmp/q24-dev-blank.sh true" > "$OUT/$tag-blank.txt" 2>&1
  cat "$OUT/$tag-blank.txt" | tee -a "$OUT/run.log"
  v=$(markof "$tag-blank-before"); [ -z "$v" ] && v=0
  votes=$(tail -n +"$((v+1))" "$OUT/tracepipe.txt" 2>/dev/null | grep -c rpmh_send_msg)
  fin=$(grep -o "GATE_AFTER5 .*" "$OUT/$tag-blank.txt" | head -1)
  log "$tag 硬门: [$fin] rpmh_msgs=$votes"
  if died; then log "DEATH_AT=$tag/blank（熄屏后 ≤14s）"; DEATHS+=("$tag/blank"); return 1; fi
  case "$fin" in *"active=(true"*) HG_A=1;; *) HG_A=0;; esac
  case "$fin" in *"dpms=Off"*) HG_D=1;; *) HG_D=0;; esac
  log "$tag gate: active=$HG_A dpms_off=$HG_D"
  sleep 6; i=0
  while [ "$i" -lt "$hold" ]; do
    if died; then log "DEATH_AT=$tag/blank-hold（+$(( $(date +%s) - t0 ))s）"; DEATHS+=("$tag/blank-hold"); return 1; fi
    sleep 15; i=$((i+15))
  done
  S "sh /tmp/q24-dev-snap.sh $tag-posthold" > "$OUT/$tag-posthold.txt" 2>/dev/null
  domain "$tag-posthold"
  mark "$tag-blank-after"
  if ! alive; then log "DEATH_AT=$tag/pre-wake"; DEATHS+=("$tag/pre-wake"); return 1; fi
  log "$tag 唤醒（SetActive false；熄屏已 +$(( $(date +%s) - t0 ))s）"
  mark "$tag-wake-before"
  S "sh /tmp/q24-dev-blank.sh false" > "$OUT/$tag-wake.txt" 2>&1
  date "+%H:%M:%S WAKE_ISSUED" >> "$OUT/$tag-wake.txt"
  cat "$OUT/$tag-wake.txt" | tee -a "$OUT/run.log"
  sleep 10
  if died; then log "DEATH_AT=$tag/wake（唤醒后 ≤10s）"; DEATHS+=("$tag/wake"); return 1; fi
  sleep 20
  if died; then log "DEATH_AT=$tag/wake-late（唤醒后 10-30s）"; DEATHS+=("$tag/wake-late"); return 1; fi
  mark "$tag-wake-after"
  S "sh /tmp/q24-dev-snap.sh $tag-postwake" > "$OUT/$tag-postwake.txt" 2>/dev/null
  log "$tag 唤醒后存活（+$(( $(date +%s) - t0 ))s）"
  mark "$tag-end"
  return 0
}
domain(){
  local f="$OUT/$1-domain.txt" g v; : > "$f"
  for g in cx mx mmcx mxc; do v=$(S "cat /sys/kernel/debug/pm_genpd/$g/current_state" 12); echo "$g=$v" >> "$f"; done
}

# ---- 0) 前置 ----
T0H=$(date "+%Y-%m-%d %H:%M:%S"); echo "$T0H" > "$OUT/t0.txt"
if [ "$SKIP_BOOT" = 1 ]; then
  alive || { log "FAIL: SKIP_BOOT 但设备不可达"; exit 2; }
  log "OUT=$OUT IMG=$IMG（复用当前台架）LABEL=$LABEL TP=[$TP] HOLD=$HOLD RECOVER=$RECOVER"
else
  timeout 20 fastboot devices > "$OUT/fastboot.txt" 2>&1 || true
  grep -q fastboot "$OUT/fastboot.txt" || { log "FAIL: 设备不在 fastboot"; exit 2; }
  timeout 15 fastboot getvar product > "$OUT/fb-probe.txt" 2>&1 || true
  grep -q product "$OUT/fb-probe.txt" || { log "FAIL: bootloader 不应答 getvar -> 需物理 POR"; exit 2; }
  log "OUT=$OUT IMG=$IMG LABEL=$LABEL TP=[$TP]"
  sha256sum "$IMG" | tee "$OUT/image.sha256"
fi
lsusb > "$OUT/host-lsusb-before.txt" 2>&1 || true
bash scripts/serial-logger.sh "$OUT/serial.log" >/dev/null 2>&1 &
LOGPID=$!; log "serial-logger pid=$LOGPID"
if [ "$SKIP_BOOT" != 1 ]; then
  log "fastboot boot $IMG"
  timeout 180 fastboot boot "$IMG" > "$OUT/fastboot-boot.log" 2>&1
  tail -3 "$OUT/fastboot-boot.log" | tee -a "$OUT/run.log"
  up=0; for i in $(seq 1 40); do alive && { up=1; log "ssh up after $((i*5))s"; break; }; sleep 5; done
  [ "$up" = 1 ] || { log "FAIL: 200s 内无 SSH"; exit 10; }
fi
S "uname -a; echo ---; cut -d. -f1 /proc/uptime; echo ---; cat /proc/cmdline" > "$OUT/s0-env.txt"
S "cat /proc/sys/kernel/random/boot_id" > "$OUT/s0-bootid.txt"
log "bench: $(head -1 "$OUT/s0-env.txt") bootid=$(head -1 "$OUT/s0-bootid.txt")"
for f in q24-dev-sess.sh q24-dev-blank.sh q24-dev-keepawake.sh q24-dev-snap.sh q24-dev-dstate.sh q24-dev-trace-on.sh; do
  scp -q -o StrictHostKeyChecking=no "scripts/$f" "$TAB:/tmp/$f" || log "WARN: scp $f 失败"
done
S "chmod +x /tmp/q24-dev-*.sh" >/dev/null

# ---- 1) 会话 + 台架健康门 ----
ses=0; r=""
for i in $(seq 1 40); do
  r=$(S "sh /tmp/q24-dev-blank.sh false 2>&1 | head -1" 12)
  case "$r" in *"active=(true"*|*"active=(false"*) ses=1; break;; esac
  sleep 5
done
[ "$ses" = 1 ] || { log "GATE_FAIL: 会话总线/ScreenSaver 无有效响应（$r）"; S "sh /tmp/q24-dev-dstate.sh" > "$OUT/abort-dstate.txt"; exit 4; }
S "sh /tmp/q24-dev-dstate.sh" > "$OUT/s0-dstate.txt"
if grep -qE "^D pid=[0-9]+ +/" "$OUT/s0-dstate.txt" || grep -qE "a6xx_gmu_oob|a6xx_gmu_set_oob|msm_gpu_fault_crashstate_capture|msm_job_run" "$OUT/s0-dstate.txt"; then
  log "GATE_FAIL: 台架不健康（D 态含合成器/GPU：#198）"; exit 4
fi
log "会话/健康门通过: $r"
S "sh /tmp/q24-dev-keepawake.sh" > "$OUT/s0-keepawake.txt" 2>&1
S "sh /tmp/q24-dev-snap.sh s0" > "$OUT/s0-snap.txt"
S "sh -s" < scripts/q28-devprobe2.sh > "$OUT/s0-q28probe.txt" 2>&1 || true
grep -E "VERDICT|l1=" "$OUT/s0-q28probe.txt" | tee -a "$OUT/run.log"
cat "$OUT/s0-snap.txt" | tee -a "$OUT/run.log"

# ---- 2) 资源地图 + 域/轨基线 ----
S "cat /sys/kernel/debug/cmd-db" > "$OUT/cmd-db.txt" 2>&1
grep -E "^0x[0-9a-f]+: " "$OUT/cmd-db.txt" | sed -e "s/: / /" | cut -d" " -f1,2 | sort -u > "$OUT/resmap.txt"
log "resmap 条数=$(wc -l < "$OUT/resmap.txt")"
S "cat /sys/kernel/debug/pm_genpd/pm_genpd_summary" > "$OUT/s0-genpd.txt" 2>&1
S "cat /sys/kernel/debug/regulator/regulator_summary" > "$OUT/s0-regulator.txt" 2>&1
S "grep -e cam -e bist -e disp -e mxc -e mmcx -e bi_tcxo -e mdss /sys/kernel/debug/clk/clk_summary" > "$OUT/s0-clk.txt" 2>&1
domain s0; cat "$OUT/s0-domain.txt" | tee -a "$OUT/run.log"
S "dmesg | tail -30" > "$OUT/s0-dmesg.txt" 2>&1

# ---- 3) trace ----
S "pkill -f trace_pi[p]e" >/dev/null 2>&1 || true
S "sh /tmp/q24-dev-trace-on.sh $TP" > "$OUT/s0-trace.txt" 2>&1
grep -E "=enabled" "$OUT/s0-trace.txt" | tee -a "$OUT/run.log"
timeout 3000 "${SSH[@]}" "$TAB" "cat /sys/kernel/debug/tracing/trace_pipe" > "$OUT/tracepipe.txt" 2>&1 &
TPID=$!; sleep 2; mark boot; log "trace pid=$TPID lines=$(wc -l < "$OUT/tracepipe.txt")"

# ---- 4) 相位 A：cam=0 对照 ----
log "=== A: cam=0 对照（预期存活）==="
S "modprobe -r cambistmclkcc-sm8750 camcc-sm8750 2>/dev/null; echo cleaned" > "$OUT/a-clean.txt" 2>&1
sleep 5
S "sh /tmp/q24-dev-snap.sh a0" > "$OUT/a0-snap.txt"; grep lsmod-cam "$OUT/a0-snap.txt" | tee -a "$OUT/run.log"
phase a "$HOLD"; RCA=$?
if [ "$RCA" = 1 ]; then log "ABORT: cam=0 对照竟死 -> 台架不可用"; kill "$TPID" 2>/dev/null; exit 6; fi

# ---- 5) 相位 B：配对 ----
log "=== B: camcc + cambist 配对（预期死亡）==="
S "modprobe camcc-sm8750 && echo CC_OK || echo CC_FAIL" | tee -a "$OUT/run.log"
sleep "$SETTLE"
S "modprobe cambistmclkcc-sm8750 && echo BIST_OK || echo BIST_FAIL" | tee -a "$OUT/run.log"
sleep "$SETTLE"
S "sh /tmp/q24-dev-snap.sh b0" > "$OUT/b0-snap.txt"
domain b0; cat "$OUT/b0-snap.txt" "$OUT/b0-domain.txt" | tee -a "$OUT/run.log"
S "cat /sys/kernel/debug/pm_genpd/pm_genpd_summary" > "$OUT/b0-genpd.txt" 2>&1
S "grep -e cam -e bist -e disp -e mxc -e mmcx -e bi_tcxo -e mdss /sys/kernel/debug/clk/clk_summary" > "$OUT/b0-clk.txt" 2>&1
S "dmesg | tail -25" > "$OUT/b0-dmesg.txt" 2>&1
phase b "$HOLD"; RCB=$?
log "相位结果: A=$RCA B=$RCB DEATHS=[${DEATHS[*]:-none}]"

# ---- 6) 死法判定 ----
TDEAD=$(date "+%Y-%m-%d %H:%M:%S")
: > "$OUT/recovery.log"; rt0=$(date +%s)
while [ "$RCB" = 1 ] || [ "$RCA" = 1 ]; do
  e=$(( $(date +%s) - rt0 )); [ "$e" -gt "$RECOVER" ] && break
  fb=$(timeout 8 fastboot devices 2>&1 | paste -sd"|" -)
  ls=$(lsusb 2>/dev/null | grep -ciE qualcomm || true)
  up=$(Sf "echo up; cut -d. -f1 /proc/uptime; cat /proc/sys/kernel/random/boot_id" | paste -sd"/" -)
  echo "+$e s ssh=[$up] fastboot=[$fb] usb_qc_count=$ls" >> "$OUT/recovery.log"
  case "$up" in up/*) log "设备自动回来了: $up"; break;; esac
  sleep 10
done
tail -20 "$OUT/recovery.log" | tee -a "$OUT/run.log"
journalctl -k --since "$TDEAD" --no-pager 2>/dev/null | grep -iE "usb|xhci|disconnect|rndis" | tail -40 > "$OUT/host-usb.txt" 2>&1
lsusb > "$OUT/host-lsusb-after.txt" 2>&1 || true

# ---- 7) 收口 + 分析 ----
sleep 2; kill "$TPID" 2>/dev/null; sleep 1; [ -n "$LOGPID" ] && kill "$LOGPID" 2>/dev/null; true
log "=== marks ==="; cat "$OUT/marks.txt" | tee -a "$OUT/run.log"
for tag in a b; do
  for w in blank wake; do
    v=$(markof "$tag-$w-before"); e=$(markof "$tag-$w-after")
    [ -z "$v" ] && continue
    [ -z "$e" ] && e=$(wc -l < "$OUT/tracepipe.txt")
    n=$((e-v)); win=$(tail -n +"$((v+1))" "$OUT/tracepipe.txt" | head -n "$n")
    log "=== $tag/$w 窗口 行 $v..$e（$n 行）事件直方图 ==="
    echo "$win" | grep -oE ": [a-z_0-9]+:" | sort | uniq -c | sort -rn | head -10 | tee -a "$OUT/run.log"
    log "=== $tag/$w BCM/RPMh 票 ==="
    echo "$win" | grep -oE "addr: 0x[0-9a-f]+" | sort | uniq -c | sort -rn | head -15 | tee -a "$OUT/run.log"
    log "=== $tag/$w icc 路径 ==="
    echo "$win" | grep -oE "path=[^ ]+ dev=[^ ]+ node=[^ ]+" | sort | uniq -c | sort -rn | head -12 | tee -a "$OUT/run.log"
    log "=== $tag/$w clk 事件 ==="
    echo "$win" | grep -oE "clk_(enable|disable|prepare|unprepare|set_rate): [a-z_0-9]+" | sort | uniq -c | sort -rn | head -15 | tee -a "$OUT/run.log"
  done
done
log "=== trace 最后 30 行 ==="
tail -30 "$OUT/tracepipe.txt" | sed "s/  */ /g" | tee -a "$OUT/run.log"
log "ALIVE=$(alive && echo yes || echo no) DEATHS=[${DEATHS[*]:-none}] DONE OUT=$OUT"