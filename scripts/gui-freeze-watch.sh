#!/usr/bin/env bash
# gui-freeze-watch.sh — 抓 PITFALLS #106「进 GUI 后整机卡死」的现行。
#
# 已知：无 panic、SSH/网络同时不通、APSS 硬看门狗被永久禁用 ⇒ 不会自复位，只能物理复位。
# 因此取证只有两条通道，本脚本两条都开：
#   ① 主机侧串口（内核 console=ttyGS0 → /dev/ttyACM0）：内核若打 RCU stall / soft lockup /
#      hung task，会在挂死瞬间继续往串口吐；整机 wedged 则串口也静默——"有没有字"本身就是判据。
#   ② 心跳采样（每 5 s 一组）：uptime / dpms / phosh / load / GPU 电源域 / 中断计数。
#      挂死时刻 = 心跳中断前最后一组，能看出「是不是刚熄屏/刚唤屏时挂的」这类相关事件。
# 另外顺手把 pstore 挂上并报告有没有 ramoops 后端：下次若能走 magic SysRq 复位（而不是断电），
# ramoops 能把最后一次 printk 留下；没有后端就得给 DT 加 reserved-memory（下一版）。
#
# usage: scripts/gui-freeze-watch.sh [watch_seconds]     # 默认 600
set -uo pipefail
cd "$(dirname "$0")/.."
SECS=${1:-600}
TAB=${TAB:-root@192.168.7.1}
OUT=logs/gui-freeze-$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"
SLOG=$OUT/serial.log; HB=$OUT/heartbeat.log

# ① 串口：设备等 USB 重枚举出 ACM 节点后再开（fastboot 态没有该节点）
if [ ! -e /dev/ttyACM0 ]; then
	echo "[watch] 等 /dev/ttyACM0（最多 90 s）"
	i=0; while [ $i -lt 18 ] && [ ! -e /dev/ttyACM0 ]; do sleep 5; i=$((i + 5)); done
fi
if [ -e /dev/ttyACM0 ]; then
	nohup timeout -k 10 $((SECS + 120)) bash -c "end=\$(( \$(date +%s) + $SECS + 120 )); while :; do cat /dev/ttyACM0 >> $SLOG 2>/dev/null; sleep 0.5; [ \$(date +%s) -ge \$end ] && break; done" >/dev/null 2>&1 &
	echo "[watch] 串口 -> $SLOG (pid $!)"
else
	echo "[watch] 无 /dev/ttyACM0：串口通道缺失（只能靠心跳）"
fi

S() { timeout "${2:-8}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$TAB" "$1" 2>/dev/null; }
echo "[watch] 等 SSH"; i=0; while [ $i -lt 36 ]; do S 'echo up' | grep -q up && break; sleep 5; i=$((i + 5)); done
S 'echo up' | grep -q up || { echo "[watch] FAIL: 起不来（可能已经挂在上一次）"; exit 1; }

# 一次性环境快照（含 pstore/ramoops、空闲超时、GPU 域）
S 'mkdir -p /sys/fs/pstore; mountpoint -q /sys/fs/pstore || mount -t pstore pstore /sys/fs/pstore 2>&1; echo "pstore=$(ls /sys/fs/pstore 2>/dev/null | tr "\n" " ")"; echo "ramoops_dt=$(ls /proc/device-tree/reserved-memory/ 2>/dev/null | tr "\n" " ")"; U=$(sed -n "s/^Uid:[[:space:]]*\([0-9]*\).*/\1/p" /proc/$(pidof phoc)/status|head -1); A=$(tr "\0" "\n" </proc/$(pidof phoc)/environ | sed -n "s/^DBUS_SESSION_BUS_ADDRESS=//p"); for k in idle-delay lock-delay; do echo "gs:$k=$(setpriv --reuid=$U --regid=$U --clear-groups env DBUS_SESSION_BUS_ADDRESS=$A XDG_RUNTIME_DIR=/run/user/$U timeout 6 gsettings get org.gnome.desktop.session $k 2>&1|head -1)"; done; echo "saver:activate=$(setpriv --reuid=$U --regid=$U --clear-groups env DBUS_SESSION_BUS_ADDRESS=$A XDG_RUNTIME_DIR=/run/user/$U timeout 6 gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.freedesktop.DBus.Properties.Get org.gnome.ScreenSaver ActivationDelay 2>&1|head -1)"' >"$OUT/env.txt" 2>&1
sed -n '1,12p' "$OUT/env.txt"

# ② 心跳
end=$(( $(date +%s) + SECS ))
: > "$HB"
while [ "$(date +%s)" -lt $end ]; do
	line=$(S 'printf "up=%s load=%s dpms=%s phosh=%s gfx=%s mdssirq=%s dsi0irq=%s tmp=%s batt=%s\n" "$(cut -d" " -f1 /proc/uptime)" "$(cut -d" " -f1 /proc/loadavg)" "$(cat /sys/class/drm/card0/card0-DSI-1/dpms 2>/dev/null)" "$(ps -eo comm|grep -cx phosh)" "$(grep -E "^gfx " /sys/kernel/debug/pm_genpd/pm_genpd_summary|awk "{print \$2}")" "$(awk "/^ *185:/ {print \$2}" /proc/interrupts)" "$(awk "/^ *186:/ {print \$2}" /proc/interrupts)" "$(cut -d" " -f1 /sys/class/thermal/thermal_zone11/temp 2>/dev/null)" "$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)"')
	echo "$(date +%T) $line" >> "$HB"
	if [ -z "$line" ]; then
		# SSH 不响应：连测 3 次确认，避免网络抖动误判
		n=0; while [ $n -lt 3 ] && ! S 'echo up' | grep -q up; do n=$((n + 1)); sleep 5; done
		if [ $n -ge 3 ]; then echo "$(date +%T) *** FROZEN (SSH 连续 3 次无响应) ***" | tee -a "$HB"; break; fi
	fi
	sleep 5
done

echo "[watch] 心跳尾 6 行："; tail -6 "$HB"
# 挂死后再让串口多吐 30 s（stall/lockup 常在挂后数十秒才打全）
sleep 30
echo "[watch] 串口字节数=$(wc -c < "$SLOG" 2>/dev/null || echo 0)；可疑行："
grep -aiE "rcu|stall|lockup|hung task|panic|Unable to handle|watchdog|error|fail" "$SLOG" 2>/dev/null | tail -25
echo "[watch] OUT=$OUT"
