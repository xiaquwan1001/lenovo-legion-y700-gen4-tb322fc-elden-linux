#!/bin/sh
# A 臂采样：屏幕保护状态机 + 背光/DPMS + 按键计数。POSIX sh，整文件 scp 到 /tmp 再跑。
# 用法：AIDLE_SECS=420 OUT=/tmp/a58-idle.tsv sh /tmp/deskstack-sample.sh
OUT=${OUT:-/tmp/a58-idle.tsv}
DUR=${AIDLE_SECS:-420}
BL=/sys/class/backlight/backlight/brightness
[ -e "$BL" ] || BL=$(ls /sys/class/backlight/*/brightness 2>/dev/null | head -1)
{
    printf 'epoch\tt_rel\tbacklight\tdpms\tssctive\tactive_time\tkeys\tidle_hint\n'
} > "$OUT"
t0=$(date +%s)
end=$((t0 + DUR))
while [ "$(date +%s)" -lt "$end" ]; do
    now=$(date +%s)
    act=$(su - xuqianhui1001 -s /bin/sh -c 'XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus busctl --user call org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver GetActive 2>/dev/null' | awk '{print $2}')
    at=$(su - xuqianhui1001 -s /bin/sh -c 'XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus busctl --user call org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver GetActiveTime 2>/dev/null' | awk '{print $2}')
    keys=$(journalctl -b --no-pager 2>/dev/null | grep -c 'Power key pressed short')
    hint=$(loginctl show-session c$(loginctl list-sessions --no-legend | awk '$2==1001 && $5=="greeter"{print $1}' | head -1) -p IdleHint 2>/dev/null | cut -d= -f2)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$now" "$((now - t0))" "$(cat "$BL" 2>/dev/null)" \
        "$(cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null)" \
        "${act:-?}" "${at:-?}" "$keys" "${hint:-?}" >> "$OUT"
    sleep 15
done
echo "done $OUT" >> "$OUT"
