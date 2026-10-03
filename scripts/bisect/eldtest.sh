#!/bin/bash
# eldtest.sh — vk34→vk40 回归的「渐进触发」自动化测试（2026-10-03）
#
# 设计目标（针对 AUDIT3 的教训）：
#   1. 尽量减少轮询：等待启动用「串口 console 里出现 uname 横幅」这一事件驱动（tail -F | grep -m1），
#      而不是 tight `fastboot devices` 轮询。
#   2. 渐进触发：从「什么都不做」逐级加压到「真实合成器 on/off ×N」，每级之间读一次 dmesg 计数。
#   3. 一条命令只做一件事；副作用（fastboot boot）单独成步并落 journal，绝不在等待循环里。
#   4. 版本归属靠 per-uname 校验（boot 后先 `uname -r`），不靠文件名。
#
# 用法：
#   scripts/bisect/eldtest.sh matrix                     # 打印版本表 + sha256（不碰设备）
#   scripts/bisect/eldtest.sh baseline                   # 打印/执行 b 槽基线（vk34recon）烧写步骤
#   scripts/bisect/eldtest.sh one <label>                # 设备已在 fastboot：fastboot boot + 观测
#   scripts/bisect/eldtest.sh flash <label>              # 从 Linux：flash-b 写 b 槽 + 重启 + 观测（不需要 fastboot）
#   scripts/bisect/eldtest.sh observe <label>            # 只观测（设备已由你手动 boot 好）
#
# 环境：设备 USB NCM 已在 host 起 192.168.7.2/24（enx…），SSH root@192.168.7.1；
#       kernel console = /dev/ttyACM0（可选，缺省也能跑，只是少一路证据）。
set -u
ROOT=${ROOT:-$HOME/y700-elden}
cd "$ROOT" || exit 1
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes root@192.168.7.1"
SER=${SER:-/dev/ttyACM0}
RUN=$(date +%Y%m%d-%H%M%S)
OUTDIR=${OUTDIR:-$ROOT/logs/bisect/$RUN}

declare -A IMG UNAME
IMG[vk34recon]=out/boot-elden-vk34recon.img;  UNAME[vk34recon]=ge72a036ed4be
IMG[v1-thermal]=out/boot-elden-v1-thermal.img; UNAME[v1-thermal]=gf681b616a3af
IMG[v2-audio]=out/boot-elden-v2-audio.img;     UNAME[v2-audio]=g951c5f1c2ca5
IMG[vk40re]=out/boot-elden-vk40re.img;         UNAME[vk40re]=g6ef87e6a8868
ORDER=(vk34recon vk40re v1-thermal v2-audio)

log()  { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$OUTDIR/journal.log" >&2; }
sshq() { $SSH "$@" 2>/dev/null; }

# ---------- 版本表 ----------
cmd_matrix() {
  printf '%-12s %-34s %-22s %s\n' LABEL IMAGE EXPECTED_UNAME SHA256_16
  for l in "${ORDER[@]}"; do
    printf '%-12s %-34s %-22s %s\n' "$l" "${IMG[$l]}" "${UNAME[$l]}" \
      "$(sha256sum "${IMG[$l]}" 2>/dev/null | cut -c1-16)"
  done
  echo
  echo "b 槽基线镜像: bootslot-b/boot_b-vk34recon.img  (kernel=vk34recon)  sha256_16=$(sha256sum bootslot-b/boot_b-vk34recon.img 2>/dev/null | cut -c1-16)"
  echo "当前 b 槽母本: bootslot-b/boot_b.img            (kernel=vk40 dirty d16ab35ce4a57afa)"
}

# ---------- b 槽基线 ----------
cmd_baseline() {
  cat <<'TXT'
== 把持久 boot_b 换成已知基线（vk34recon）==
前提：设备在 fastboot；vbmeta_b_flags3 已含本机 AVB key。
备份：现 boot_b 的内容已存为 bootslot-b/boot_b.img（内核=vk40 dirty，payload d16ab35ce4a57afa），
      无需再 fetch（本机 fastboot 不支持 fetch）。

步骤（你亲自执行；逐条、勿合并）：

  # 1) 烧基线
  fastboot flash boot_b bootslot-b/boot_b-vk34recon.img

  # 2) 读回校验：临时 RAM 引导基线内核，再从设备里 dd 出 boot_b 比对
  fastboot boot out/boot-elden-vk34recon.img
  #   等 SSH 起来（约 25–60 s），然后：
  ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/boot_b bs=1M count=96 2>/dev/null | sha256sum'

  # 3) 与 host 侧比对（两个 sha 必须相同）：
  sha256sum bootslot-b/boot_b-vk34recon.img

完成后任何「复位/回退」都落在 vk34recon 基线，而不再落在被测的 vk40 上。
TXT
}

# ---------- 串口捕获（只读；无副作用） ----------
start_cap() {
  [ -r "$SER" ] || { log "serial $SER 不可读，跳过 console 捕获"; return 1; }
  [ -f "$OUTDIR/cap.pid" ] && kill "$(cat "$OUTDIR/cap.pid")" 2>/dev/null
  mkdir -p "$OUTDIR"
  ( timeout 5400 cat "$SER" >> "$OUTDIR/console.log" 2>/dev/null ) &
  echo $! > "$OUTDIR/cap.pid"
  log "console 捕获 -> $OUTDIR/console.log (pid $(cat "$OUTDIR/cap.pid"))"
}
stop_cap() { [ -f "$OUTDIR/cap.pid" ] && kill "$(cat "$OUTDIR/cap.pid")" 2>/dev/null; log "console 捕获已停"; }

# 事件驱动等待：console 出现指定 uname 横幅；$1=uname 子串 $2=超时秒
wait_banner() {
  local u=$1 t=${2:-180} f="$OUTDIR/console.log"
  [ -f "$f" ] || { log "无 console.log，跳过 banner 等待"; sleep 20; return 0; }
  # 先查已有内容（本 run 的 console.log 从 fastboot 期开始，此时尚无 kernel banner）
  if grep -q -m1 -a "Linux version .*$u" "$f" 2>/dev/null; then
    log "banner 命中(既有): $u"; return 0
  fi
  if timeout "$t" tail -n0 -F "$f" 2>/dev/null | grep -q -m1 -a "Linux version .*$u"; then
    log "banner 命中: $u"
  else
    log "banner 等待超时/未命中: $u（改按固定延时）"
  fi
}

# 粗粒度等待 SSH（有界；每 8s 一试，失败不算副作用）
wait_ssh() {
  local t=${1:-180} i=0
  while [ "$i" -lt "$((t/8))" ]; do
    if sshq true; then log "SSH up (~$((i*8))s)"; return 0; fi
    i=$((i+1)); sleep 8
  done
  log "SSH 超时"; return 1
}

# 远程读一次状态；$1=阶段名
probe() {
  local stage=$1
  sshq 'bash -s' <<'EOF'
U=$(cut -d' ' -f1 /proc/uptime)
printf 'uptime=%s uname=%s vblank=%s ppm=%s adsp=%s\n' \
  "$U" "$(uname -r)" \
  "$(dmesg | grep -cE 'vblank timeout')" \
  "$(dmesg | grep -cE 'PPM init')" \
  "$(dmesg | grep -cE 'crash detected|fatal notification')"
EOF
}

# 渐进触发（在设备上执行）；$1=级别
trigger() {
  sshq 'bash -s' <<EOF
PID=\$(pidof phosh)
export XDG_RUNTIME_DIR=/run/phosh
[ -n "\$PID" ] && export DBUS_SESSION_BUS_ADDRESS=\$(tr '\0' '\n' < /proc/\$PID/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
case "$1" in
  s0) : ;;                                             # 纯空闲
  s1) wlr-randr --output DSI-1 --on  >/dev/null 2>&1 ;; # 单次 on
  s2) wlr-randr --output DSI-1 --off >/dev/null 2>&1 ;; # 单次 off
  s3) for i in 1 2 3 4 5; do wlr-randr --output DSI-1 --on >/dev/null 2>&1; sleep 3; wlr-randr --output DSI-1 --off >/dev/null 2>&1; sleep 3; done ;;
  sleep) sleep 120 ;;
esac
echo "trigger $1 done"
EOF
}

# 跑一轮渐进触发，写入 results.tsv
run_stages() {
  local label=$1
  local last_u=""
  # 级别 名称  触发后等待
  local spec="s0:idle0:45 s1:on:15 s2:off:15 s3:onoff5:20 sleep:idle2:120"
  for item in $spec; do
    local key=${item%%:*} name rest waitsec
    name=$(echo "$item" | cut -d: -f2)
    waitsec=$(echo "$item" | cut -d: -f3)
    [ "$key" != "sleep" ] && trigger "$key"
    sleep "$waitsec"
    local p; p=$(probe "$name")
    # 复位检测：SSH 失败或 uname 变化或 uptime 变小
    if [ -z "$p" ]; then
      printf '%s\t%s\t%s\t%s\n' "$label" "$name" "RESET?" "SSH lost" | tee -a "$OUTDIR/results.tsv"
      log "[$label] $name -> SSH lost（疑似复位）"; last_u=""; wait_ssh 240; start_cap; continue
    fi
    local u; u=$(echo "$p" | sed -n 's/.*uname=\([^ ]*\).*/\1/p')
    if [ -n "$last_u" ] && [ "$u" != "$last_u" ]; then
      log "[$label] uname 由 $last_u 变 $u（复位并回退！）"
    fi
    last_u=$u
    printf '%s\t%s\t%s\n' "$label" "$name" "$p" | tee -a "$OUTDIR/results.tsv"
  done
}

# ---------- one / observe ----------
cmd_observe() {
  local label=$1
  [ -n "${IMG[$label]:-}" ] || { echo "unknown label: $label"; exit 1; }
  mkdir -p "$OUTDIR"
  log "== 观测 $label =="
  wait_ssh 240 || { log "SSH 未起，退出"; return 1; }
  local get; get=$(sshq 'uname -r')
  log "当前 uname=$get（期望含 ${UNAME[$label]}）"
  if ! echo "$get" | grep -q "${UNAME[$label]}"; then
    log "!! uname 与期望不符：实际 $get / 期望 ${UNAME[$label]}；请确认在跑的目标内核"
    printf '%s\tboot\tMISMATCH\tuname=%s expect=%s\n' "$label" "$get" "${UNAME[$label]}" | tee -a "$OUTDIR/results.tsv"
    return 1
  fi
  printf '%s\tboot\tOK\tuname=%s\n' "$label" "$get" | tee -a "$OUTDIR/results.tsv"
  run_stages "$label"
  log "== $label 完成；结果在 $OUTDIR/results.tsv，串口在 $OUTDIR/console.log =="
}

cmd_one() {
  local label=$1
  [ -n "${IMG[$label]:-}" ] || { echo "unknown label: $label"; exit 1; }
  mkdir -p "$OUTDIR"
  start_cap
  log "== fastboot boot $label =="
  # 副作用单独一步，落 journal；不用轮询，直接给 fastboot 自己的超时
  if ! timeout 180 fastboot boot "${IMG[$label]}" 2>&1 | tee -a "$OUTDIR/journal.log" | tail -3; then
    log "fastboot boot 失败/超时"; stop_cap; return 1
  fi
  wait_banner "${UNAME[$label]}" 200
  cmd_observe "$label"
  stop_cap
}

# flash = 用 flash-b.sh 把测试内核写进 b 槽并重启（不需要 fastboot；AUDIT3/PITFALLS#88）
# 注意：flash-b.sh 会把签名后的镜像写到 bootslot-b/boot_b.img（覆盖），并带 sha256 回读校验。
cmd_flash() {
  local label=$1
  [ -n "${IMG[$label]:-}" ] || { echo "unknown label: $label"; exit 1; }
  mkdir -p "$OUTDIR"
  start_cap
  log "== flash-b $label -> boot_b + reboot =="
  if ! scripts/flash-b.sh "${IMG[$label]}" --reboot 2>&1 | tee -a "$OUTDIR/journal.log" | tail -6; then
    log "flash-b 失败"; stop_cap; return 1
  fi
  wait_banner "${UNAME[$label]}" 200
  cmd_observe "$label"
  stop_cap
}

# ---------- prepare：只读地准备/核验测试版本 ----------
cmd_prepare() {
  mkdir -p "$ROOT/logs/bisect"
  local man="$ROOT/logs/bisect/manifest-$(date +%Y%m%d-%H%M%S).txt"
  {
    echo "# 测试版本清单  $(date)"
    echo "# host git: $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)"
    echo
    for l in "${ORDER[@]}"; do
      f="${IMG[$l]}"
      if [ -f "$f" ]; then
        printf '%-12s %-34s uname=%-20s sha256=%.24s\n' "$l" "$f" "${UNAME[$l]}" "$(sha256sum "$f" | cut -d' ' -f1)"
      else
        printf '%-12s %-34s MISSING\n' "$l" "$f"
      fi
    done
    echo
    echo "# b 槽基线（已签名，待你烧写）:"
    ls -l bootslot-b/boot_b-vk34recon.img
    echo "# 当前 b 槽母本（=vk40 dirty，切勿当基线）:"
    ls -l bootslot-b/boot_b.img
    echo
    echo "# kernel payload 指纹对照（audit3）:"
    echo "#   bootslot-b/boot_b.img        -> d16ab35ce4a57afa (vk40 现场)"
    echo "#   bootslot-b/boot_b_vk34recon  -> ecfa53db763c57fe (vk34recon)"
  } | tee "$man"
  echo; echo "manifest -> $man"
}

case "${1:-}" in
  matrix)   cmd_matrix ;;
  prepare)  cmd_prepare ;;
  baseline) cmd_baseline ;;
  one)      cmd_one "${2:-}" ;;
  flash)    cmd_flash "${2:-}" ;;
  observe)  cmd_observe "${2:-}" ;;
  *) sed -n '2,30p' "$0" ;;
esac
