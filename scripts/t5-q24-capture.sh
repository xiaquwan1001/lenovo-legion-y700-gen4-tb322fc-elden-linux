#!/bin/bash
# t5-q24-capture.sh — T5：给 Taniya Das（Q24 语境）的三件套采集
#
# 交付物（对应她 2026-10-13 09:03 UTC 的原话请求）：
#   ① 完整 dmesg / console log（从 t=0 起）
#   ② /sys/kernel/debug/pm_genpd/pm_genpd_summary
#   ③ /sys/kernel/debug/clk/clk_summary
# 语境要求（不得违反）：
#   * **Q24 语境** = cambistmclkcc + camcc **配对加载** + 一次**真实熄屏**
#     （不是 Q28 坏发快照；`dpms` sysfs 只读 ⇒ 用 ScreenSaver.SetActive，PITFALLS #294）
#   * **采集副作用必须写明**：读 clk_summary 会 runtime-resume 时钟控制器
#     （Joonhoe Kim 2026-10-16，<20261016125036.1069-1-26rote@gmail.com>）⇒
#     「读取时状态 ≠ 故障瞬间状态」；顺序 = dmesg → genpd → clk（clk 最后）
#   * 若熄屏致死：把**熄屏前**快照作为「死前状态」交付，并注明死于第几步
#
# 用法：bash scripts/t5-q24-capture.sh [--blank-seconds 60] [--keep-cam]
#   默认结束时执行 cam-mode off（回到熄屏安全态）；--keep-cam 则保留相机栈
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEV=${DEV:-root@192.168.7.1}
BLANK_S=60
KEEP_CAM=0
while [ $# -gt 0 ]; do
	case "$1" in
	--blank-seconds) BLANK_S=$2; shift 2 ;;
	--keep-cam) KEEP_CAM=1; shift ;;
	*) echo "usage: $0 [--blank-seconds N] [--keep-cam]" >&2; exit 2 ;;
	esac
done
TS=$(date +%Y%m%d-%H%M%S)
OUT=$ROOT/reports/artifacts/t5-$TS
mkdir -p "$OUT"
LOG=$OUT/run.log
exec > >(tee -a "$LOG") 2>&1

SSH="ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=8 $DEV"
say() { echo "[$(date '+%H:%M:%S')] $*"; }
ssh_ok() { $SSH true 2>/dev/null; }
r() { $SSH "$@"; }

say "== T5 采集开始  out=$OUT"
if ! ssh_ok; then echo "❌ 设备不可达（$DEV）"; exit 1; fi

say "== 0) 前置：持设备锁 + 预检"
. "$ROOT/scripts/lib-device-lock.sh"
device_lock_acquire || exit 1
say "  设备锁已持有（fd 9，随进程退出释放）"

r 'uname -r; cat /proc/sys/kernel/random/boot_id; cut -d. -f1 /proc/uptime' | tee "$OUT/00-preflight.txt"
DPMS=$(r 'cat /sys/class/drm/card0/card0-DSI-1/dpms 2>/dev/null || echo "?"')
say "  dpms=$DPMS  （必须 On：面板 GOOD 才不是 Q28 坏发语境）"
if [ "$DPMS" != "On" ]; then
	echo "❌ 面板不是 GOOD 态（dpms=$DPMS）⇒ 数据会落进 Q28 坏发语境，T5 拒绝采集"
	exit 3
fi

say "== 1) 相机栈**配对加载**（cambistmclkcc + camcc）"
r 'sh /usr/local/sbin/cam-mode.sh on' | tee "$OUT/10-cam-mode-on.txt"
PAIR=$(r 'lsmod | grep -cE "^(camcc_sm8750|cambistmclkcc_sm8750) "')
say "  配对模块数(期望 2)=$PAIR"
r 'lsmod | grep -E "^(camcc_sm8750|cambistmclkcc_sm8750) " ' | tee "$OUT/11-pair-modules.txt"
r 'ls /dev/media* /dev/video* 2>/dev/null | wc -l' | tee "$OUT/12-cam-devices.txt"
if [ "$PAIR" -lt 2 ]; then echo "⚠️ 配对模块不足 2（Q24 语境不完整，继续但报告需注明）"; fi

say "== 2) ① 完整 dmesg（t=0 起？）"
r 'dmesg' > "$OUT/20-dmesg-before-blank.txt"
HEADT=$(head -1 "$OUT/20-dmesg-before-blank.txt" | sed -n 's/^\[\s*\([0-9.]*\)\].*/\1/p')
say "  dmesg $(wc -l < "$OUT/20-dmesg-before-blank.txt") 行，首行 t=${HEADT:-?}（0.000000 = 从启动起完整）"

say "== 3) ② pm_genpd_summary（先读，开销小）"
r 'cat /sys/kernel/debug/pm_genpd/pm_genpd_summary' > "$OUT/30-pm_genpd_summary.txt"
say "  $(wc -l < "$OUT/30-pm_genpd_summary.txt") 行"

say "== 4) ③ clk_summary（**最后读**；读完立即记录 boot_id/uptime）"
r 'cat /sys/kernel/debug/clk/clk_summary' > "$OUT/40-clk_summary.txt"
say "  $(wc -l < "$OUT/40-clk_summary.txt") 行"
r 'echo "boot_id=$(cat /proc/sys/kernel/random/boot_id) uptime=$(cut -d. -f1 /proc/uptime)s at=$(date -u +%FT%TZ)"' | tee "$OUT/41-after-clk-read.txt"
BOOT0=$(r 'cat /proc/sys/kernel/random/boot_id')

say "== 5) 真实熄屏（ScreenSaver.SetActive true）→ 等 ${BLANK_S}s"
BUS=$($SSH "for p in \$(pgrep -u 1000 | head -20); do ( tr '\\0' '\\n' < /proc/\$p/environ ) 2>/dev/null | grep -m1 '^DBUS_SESSION_BUS_ADDRESS='; done | head -1 | cut -d= -f2-")
say "  session bus = ${BUS:-<未找到>}"
r "sudo -u xuqianhui1001 HOME=/home/xuqianhui1001 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS='$BUS' gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true" | tee "$OUT/50-blank-call.txt"
sleep 3
r 'cat /sys/class/drm/card0/card0-DSI-1/dpms 2>/dev/null; echo "boot_id=$(cat /proc/sys/kernel/random/boot_id)"' | tee "$OUT/51-dpms-after-blank.txt"
[ -n "$BUS" ] && $SSH "sudo -u xuqianhui1001 HOME=/home/xuqianhui1001 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS='$BUS' grim /tmp/t5-blank.png" 2>/dev/null && \
	scp -q -o StrictHostKeyChecking=no "$DEV:/tmp/t5-blank.png" "$OUT/52-blank-screenshot.png" 2>/dev/null

DIED=0
for i in $(seq 1 $((BLANK_S/5))); do
	sleep 5
	if ! ssh_ok; then
		say "  ⚠️ 第 $((i*5))s：SSH 失去响应（可能正在复位）"
	fi
	B=$(r 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null)
	if [ -n "$B" ] && [ "$B" != "$BOOT0" ]; then
		say "  ❌ 设备已复位（boot_id 变化 $BOOT0 → $B）⇒ 熄屏致死"
		DIED=1; break
	fi
done
if [ "$DIED" = 0 ]; then say "  ✅ 熄屏 ${BLANK_S}s 后仍存活（boot_id 未变）"; fi

if [ "$DIED" = 0 ]; then
	say "== 6) 唤醒（SetActive false）+ 取熄屏后快照"
	r "sudo -u xuqianhui1001 HOME=/home/xuqianhui1001 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS='$BUS' gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive false" | tee "$OUT/60-unblank-call.txt"
	sleep 3
	r 'cat /sys/class/drm/card0/card0-DSI-1/dpms 2>/dev/null' | tee "$OUT/61-dpms-after-wake.txt"
	r 'dmesg' > "$OUT/62-dmesg-after-blank.txt"
	r 'cat /sys/kernel/debug/pm_genpd/pm_genpd_summary' > "$OUT/63-pm_genpd_summary-after.txt"
	r 'cat /sys/kernel/debug/clk/clk_summary' > "$OUT/64-clk_summary-after.txt"
	r 'echo "boot_id=$(cat /proc/sys/kernel/random/boot_id) uptime=$(cut -d. -f1 /proc/uptime)s"' | tee "$OUT/65-after-all.txt"
	# 熄屏前后 dmesg 差分（新增行）
	tail -n +$(($(wc -l < "$OUT/20-dmesg-before-blank.txt") + 1)) "$OUT/62-dmesg-after-blank.txt" > "$OUT/66-dmesg-delta.txt" 2>/dev/null || true
	say "  熄屏期间新增 dmesg 行 = $(wc -l < "$OUT/66-dmesg-delta.txt" 2>/dev/null || echo 0)"
else
	say "  死亡样本：以熄屏前快照（20/30/40）作为「死前状态」交付"
	r 'dmesg' > "$OUT/67-dmesg-after-reset.txt" 2>/dev/null || true
fi

say "== 7) 收尾：恢复熄屏安全态"
if [ "$KEEP_CAM" = 0 ]; then
	r 'sh /usr/local/sbin/cam-mode.sh off' | tee "$OUT/70-cam-mode-off.txt"
else
	say "  --keep-cam：保留相机栈（注意：此时不要熄屏）"
fi
r 'echo "boot_id=$(cat /proc/sys/kernel/random/boot_id)"; sh /usr/local/sbin/cam-mode.sh status' | tee "$OUT/71-final-status.txt"

say "== 汇总"
cat <<EOF | tee "$OUT/summary.txt"
date            : $(date -u +%FT%TZ)
kernel          : $(head -1 "$OUT/00-preflight.txt")
boot_id(pre)    : $BOOT0
pair modules    : $PAIR / 2 (camcc_sm8750 + cambistmclkcc_sm8750)
dmesg lines     : $(wc -l < "$OUT/20-dmesg-before-blank.txt")  首行 t=${HEADT:-?}
genpd lines     : $(wc -l < "$OUT/30-pm_genpd_summary.txt")
clk lines       : $(wc -l < "$OUT/40-clk_summary.txt")
blank           : ${BLANK_S}s, died=$DIED
dmesg delta     : $(wc -l < "$OUT/66-dmesg-delta.txt" 2>/dev/null || echo n/a)
artifacts       : $OUT
EOF
say "== done"
