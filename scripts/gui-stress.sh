#!/usr/bin/env bash
# gui-stress.sh — 给 PITFALLS #106「进桌面后整机卡死」造**真实** GUI/GPU 负载。
#
# 依据：73 分钟 idle（`gfx` 电源域全程 off）不复现；用户是「进了桌面之后」挂的
# ⇒ 缺的变量是合成器真在合成（有窗口、有重绘、屏幕亮着）。
#
# ★PATHCHECK（先于任何计数，教训见 PITFALLS #140 + 记忆「复现脚本先验控制通路」）：
#   第 0 轮必须实测到 ① dpms 真的 On ② `gfx` 电源域变 on（=GPU 真在合成），否则整轮样本无意义，
#   本脚本直接 rc=2 退出，不产出「没复现」的结论。
# 极性坑：org.gnome.ScreenSaver **SetActive(true)=熄屏**，SetActive(false)=唤屏（写反会让 App
# 在熄屏态跑，phosh 不合成 ⇒ 零 GPU 负载，白测）。
#
# usage: scripts/gui-stress.sh [seconds]     默认 600；主机侧请再套一层 timeout
set -uo pipefail
cd "$(dirname "$0")/.."
SECS=${1:-600}
TAB=${TAB:-root@192.168.7.1}
OUT=logs/gui-stress-$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"
S() { timeout "${2:-60}" scripts/device-lock.sh ssh -o StrictHostKeyChecking=no "$TAB" "$1"; }

cat > "$OUT/dev-stress.sh" <<'EOS'
#!/bin/sh
# 会话身份从 phoc 进程取（greetd 会话在 UID 1000，root 连不上它的总线：PITFALLS #140）
P=$(pidof phoc | awk '{print $1}')
U=$(sed -n 's/^Uid:[[:space:]]*\([0-9]*\).*/\1/p' /proc/$P/status | head -1)
G=$(sed -n 's/^Gid:[[:space:]]*\([0-9]*\).*/\1/p' /proc/$P/status | head -1)
A=$(tr '\0' '\n' < /proc/$P/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
H=$(getent passwd "$U" | cut -d: -f6)
as_user() { setpriv --reuid=$U --regid=$G --clear-groups env DBUS_SESSION_BUS_ADDRESS="$A" XDG_RUNTIME_DIR=/run/user/$U WAYLAND_DISPLAY=wayland-0 HOME=$H sh -c "cd $H && $*"; }
wake()  { as_user timeout 8 gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive false >/dev/null 2>&1; }
blank() { as_user timeout 8 gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true  >/dev/null 2>&1; }
vs()    { awk '/^ *185:/ {print $2}' /proc/interrupts; }   # mdss vsync/IRQ = 合成器有没有真在刷
dpms()  { cat /sys/class/drm/card0/card0-DSI-1/dpms 2>/dev/null; }
spin()  { as_user "timeout 12 foot -e sh -c 'i=0; while [ \$i -lt 300 ]; do i=\$((i+1)); echo tick \$i; sleep 0.2; done' >/dev/null 2>&1 &"; as_user "timeout 10 btop >/dev/null 2>&1 &"; }

# ---- PATHCHECK：控制通路必须被证明有效，否则不产出结论 ----
wake; sleep 5; spin; sleep 6   # 唤屏要 ~3 s 才落到 dpms，等太短会误判 PATHCHECK 失败
pc_dpms=$(dpms); a=$(vs); sleep 6; b=$(vs)
echo "PATHCHECK dpms=$pc_dpms vsync_delta=$((b - a))"
echo "$pc_dpms" | grep -qi '^On' || { echo "PATHCHECK-FAIL: 唤屏没生效"; exit 2; }
[ $((b - a)) -gt 20 ] || { echo "PATHCHECK-FAIL: mdss 中断没在涨 ⇒ 合成器没在刷，样本无意义"; exit 2; }
echo "PATHCHECK-OK"

i=0; end=$(( $(date +%s) + SECS ))
while [ "$(date +%s)" -lt $end ]; do
	i=$((i + 1))
	wake; spin
	[ $((i % 2)) -eq 0 ] && as_user "timeout 18 chromium --ozone-platform=wayland --no-first-run --disable-gpu-sandbox --disable-dev-shm-usage >/dev/null 2>&1 &"
	sleep 8
	echo "$(date +%T) r$i dpms=$(dpms) vs=$(vs) load=$(cut -d' ' -f1 /proc/loadavg)"
	as_user "pkill -f -U $U 'foot|btop|chromium'" >/dev/null 2>&1
	blank; sleep 2; wake; sleep 1
done
echo "DONE rounds=$i"
EOS

S "mkdir -p /root/gui-stress" || exit 1
timeout 60 scripts/device-lock.sh scp -q -o StrictHostKeyChecking=no "$OUT/dev-stress.sh" "$TAB:/root/gui-stress/dev-stress.sh" || exit 1
echo "[stress] 设备侧前台跑（PATHCHECK 先行），输出 -> $OUT/stress.log"
timeout -k 15 $((SECS + 180)) scripts/device-lock.sh ssh -o StrictHostKeyChecking=no "$TAB" \
	"SECS=$SECS timeout -k 15 $((SECS + 150)) sh /root/gui-stress/dev-stress.sh" 2>&1 | tee "$OUT/stress.log"
rc=${PIPESTATUS[0]}
echo "[stress] rc=$rc（2=PATHCHECK 没过，不产出『没复现』结论）"
exit $rc
