#!/bin/bash
# RETIRED 2026-11-27：2026-10-31 执行单配套的一次性窗口取证采集包，产物已在 reports/artifacts/device-window-20261031/；可复核：reports/script-audit-ssh-20261118.md
# device-window-collect.sh — 设备窗口只读采集包（2026-10-31 执行单配套）
#
# 一次采齐所有「读回型」判据，输出到 reports/artifacts/device-window-20261031/。
# 只读：设备侧只有 cat/grep/journalctl/dumpsys/findmnt 等只读命令；无写入、无刷写、无重启。
#
# 用法（主机侧）：
#   scripts/device-window-collect.sh                 # T1 开机基线（默认）
#   scripts/device-window-collect.sh --post-shutdown # T3 关机后取证（上一 boot 的 greetd 计时）
#   scripts/device-window-collect.sh --dry-run       # 只打印将执行的命令，不连设备，rc=0
#
# 纪律：所有 ssh 经 scripts/device-lock.sh；TAB 环境变量可覆盖 ssh 目标（默认 root@192.168.7.1）。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/reports/artifacts/device-window-20261031"
TAB=${TAB:-root@192.168.7.1}
MODE=baseline
[ "${1:-}" = "--post-shutdown" ] && MODE=post-shutdown
DRY=0
[ "${1:-}" = "--dry-run" ] || [ "${2:-}" = "--dry-run" ] && DRY=1

mkdir -p "$OUT"
SSH_CMD="ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 $TAB"

# gate <name> <remote-command...> — 经 device-lock 跑一条只读命令并 tee 落盘
GATE_FAIL=0
gate() {
	local name=$1; shift
	local log="$OUT/$name.log"
	if [ "$DRY" = 1 ]; then
		echo "DRY: '$ROOT/scripts/device-lock.sh' $SSH_CMD \"$*\" > $log"
		return 0
	fi
	echo "[gate] $name"
	# 2026-11-18 审计 R4：① 旧版用相对路径 scripts/device-lock.sh，只在仓根 CWD 下成立；
	# ② 旧版无条件 return 0 —— 采集失败的包与成功包长得一样（只看退出码 = 假绿）。
	timeout "${GATE_TO:-90}" "$ROOT/scripts/device-lock.sh" $SSH_CMD "$*" >"$log" 2>&1
	local rc=$?
	echo "  rc=$rc log=$log ($(wc -l <"$log") lines)"
	[ "$rc" = 0 ] || { echo "  [warn] gate $name rc=$rc（判据未采到，报告里必须注明）"; GATE_FAIL=$((GATE_FAIL + 1)); }
	return 0
}

if [ "$DRY" = 1 ]; then
	echo "== dry-run（不连设备，模式=$MODE） =="
else
	echo "== device-window collect: mode=$MODE target=$TAB out=$OUT =="
fi

if [ "$MODE" = baseline ]; then
	# ---- T1 开机基线（W1 复核 / W5 vk183 侧 / 通用） ----
	gate 01-identity "uname -r; uname -v; cat /proc/sys/kernel/random/boot_id; cat /proc/cmdline; findmnt -no SOURCE,FSTYPE,OPTIONS /"
	# boot_b 在 LUN4（/dev/sde45），不在 LUN0。先记录解析结果与分区容量：udev 还没建
	# by-partlabel、或 GPT 变了的时候，空流 sha 是 e3b0c442…（会被当成本尊读数）。
	gate 02-bootb-sha "readlink -f /dev/disk/by-partlabel/boot_b; blockdev --getsize64 /dev/disk/by-partlabel/boot_b 2>/dev/null; dd if=/dev/disk/by-partlabel/boot_b bs=4M 2>/dev/null | sha256sum | cut -c1-16"
	gate 03-q28-signature "dmesg | grep -cE 'command DMA timeout|peer command DMA timeout|reset failure|STORM|recovery is not complete|dsi_bonded_cmd_failed|vblank timeout|drm_crtc_wait_one_vblank|PPM init failed' ; dmesg | grep -E 'DSI PLL lock|Failed to initialize panel' | wc -l"
	gate 04-panel-dpms "cat /sys/class/drm/card0-DSI-1/status 2>/dev/null; cat /sys/class/drm/card0-DSI-1/enabled 2>/dev/null; cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null"
	gate 05-failed-units "systemctl --failed --no-legend | wc -l; systemctl is-system-running"
	gate 06-modules "find /lib/modules/\$(uname -r) -name '*.ko' 2>/dev/null | wc -l; lsmod | wc -l"  # \$(uname -r) 在设备侧展开
	gate 07-i2c10-wl2868c "ls -l /dev/i2c-10 2>/dev/null; ls -d /sys/bus/i2c/devices/10-002f 2>/dev/null; dmesg | grep -E 'geni_i2c 888000\.i2c|wl2868c' | tail -5; grep -c camera_ldo /sys/class/regulator/*/name 2>/dev/null | grep -c ':1' || true"
	gate 08-camera-host "ls -l /dev/video100 2>/dev/null; lsmod | grep -c v4l2loopback || true; ls /dev/video* 2>/dev/null | wc -l"
	gate 09-greetd-p0 "systemctl show greetd -p TimeoutStopUSec -p ExecStop -p MainPID"
	gate 10-waydroid "waydroid status 2>&1 | head -5; waydroid shell dumpsys media.camera 2>/dev/null | grep -E 'Number of camera devices|Device 0 maps' | head -3"
	gate 11-tablet-night "grep -c USTC_API_KEY /root/.config/pi-tablet-night.env 2>/dev/null; ls -l /root/.config/pi-tablet-night.env 2>/dev/null"
elif [ "$MODE" = post-shutdown ]; then
	# ---- T3 关机后取证（W2 判据，reports/shutdown-greetd-hang-plan-20261030.md §4.4） ----
	gate 20-poweroff-timing "journalctl -b -1 -o short-unix --no-pager | grep -E 'Stopping greetd|Stopped greetd|timed out\. Killing|Failed with result|System is powering off|final.target'"
	gate 21-timeout-count "journalctl -b -1 --no-pager | grep -c 'timed out. Killing' || true"
	gate 22-greetd-log "stat -c '%y %s' /var/log/greetd.log; tail -5 /var/log/greetd.log"
	gate 23-this-boot "uname -v; cat /proc/sys/kernel/random/boot_id; systemctl is-system-running; loginctl list-sessions --no-legend | wc -l"
else
	echo "unknown mode: $MODE" >&2; exit 2
fi

if [ "$DRY" = 1 ]; then
	echo "== dry-run 完成（未连设备） rc=0 =="
else
	echo "== 完成（失败 gate 数=$GATE_FAIL）；逐条核对判据见 reports/device-window-checklist-20261031.md =="
	[ "$GATE_FAIL" = 0 ] || { echo "== 注意：有 $GATE_FAIL 条判据未采到，勿当作「设备正常」 ==" >&2; exit 1; }
fi
exit 0
