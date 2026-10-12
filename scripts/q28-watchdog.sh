#!/bin/sh
# q28-watchdog.sh — 主机侧管理：把 Q28 运营兜底看门狗装到设备/开关/查状态。
#
# 设备侧实现 = rootfs/persistent-overlay/q28-boot-watchdog.sh（本仓库为唯一源）。
#
# 用法：
#   scripts/q28-watchdog.sh install     # 推设备脚本 + 挂到 /etc/local.d 的启动钩子 + 建 off/on 包装
#   scripts/q28-watchdog.sh on|off      # 启用 / 停用（设备侧 marker /etc/q28-watchdog.disable）
#   scripts/q28-watchdog.sh status      # 设备侧现状（开关/计数/最近日志/会话）
#   scripts/q28-watchdog.sh judge [秒]  # 设备侧立刻按判据跑一遍（会真的重启，若判为坏发；默认等待 3 s）
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PAY="$ROOT/rootfs/persistent-overlay/q28-boot-watchdog.sh"
TAB=root@192.168.7.1
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -b 0"
S() { timeout "${S_TMO:-40}" $SSH "$TAB" "$@"; }

usage() { sed -n '2,12p' "$0"; exit 2; }

cmd=${1:-}
case "$cmd" in
install)
	[ -f "$PAY" ] || { echo "missing $PAY" >&2; exit 1; }
	S 'mkdir -p /usr/local/sbin /etc/local.d'
	timeout 40 scp -o StrictHostKeyChecking=no -q "$PAY" "$TAB:/usr/local/sbin/q28-boot-watchdog.sh"
	S 'chmod 755 /usr/local/sbin/q28-boot-watchdog.sh'
	# 设备侧开关包装（on/off/status），与 host 侧同名语义
	S 'cat > /usr/local/sbin/q28-watchdog.sh' <<'EOS'
#!/bin/sh
set -eu
D=/etc/q28-watchdog.disable
S=/var/lib/q28-watchdog
case "${1:-status}" in
  off)  touch "$D"; echo "q28-watchdog: OFF (marker $D)" ;;
  on)   rm -f "$D";  echo "q28-watchdog: ON" ;;
  status)
    if [ -e "$D" ]; then st=OFF; else st=ON; fi
    echo "q28-watchdog: $st  count=$(cat "$S/count" 2>/dev/null || echo 0)  phoc=$(pgrep -x phoc | wc -l)  phosh=$(pgrep -x phosh | wc -l)  card0=$([ -e /sys/class/drm/card0 ] && echo yes || echo no)"
    logger -t q28-wd -p daemon.notice 2>/dev/null "status queried"; ;;
  *) echo "usage: q28-watchdog.sh on|off|status" >&2; exit 2 ;;
esac
EOS
	S 'chmod 755 /usr/local/sbin/q28-watchdog.sh'
	# 启动钩子：local.d 的 elden-bringup.start 已枚举后台 helper（setsid … &），加入即可
	S 'if ! grep -q q28-boot-watchdog /etc/local.d/elden-bringup.start 2>/dev/null; then
		sed -i "s/^for h in /for h in q28-boot-watchdog /" /etc/local.d/elden-bringup.start
		grep -n "for h in" /etc/local.d/elden-bringup.start
	else echo "hook already present"; fi'
	S 'ls -la /usr/local/sbin/q28-boot-watchdog.sh /usr/local/sbin/q28-watchdog.sh; grep -n "for h in" /etc/local.d/elden-bringup.start'
	;;
on)  S '/usr/local/sbin/q28-watchdog.sh on' ;;
off) S '/usr/local/sbin/q28-watchdog.sh off' ;;
status) S '/usr/local/sbin/q28-watchdog.sh status; echo "--- log ---"; logread 2>/dev/null | grep q28-wd | tail -5' ;;
judge)
	w=${2:-3}
	S "Q28_WD_WAIT=$w /usr/local/sbin/q28-boot-watchdog.sh; echo rc=\$?"
	;;
*) usage ;;
esac
