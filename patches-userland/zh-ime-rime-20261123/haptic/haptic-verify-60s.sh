#!/bin/sh
# haptic-verify-60s.sh — OSK 每键震动 上机 60 s 验证（设备侧执行；只读+一次 ffrumble 触发）
# 用法: sh haptic-verify-60s.sh [/dev/input/event2]
# 判据三条，见 haptic/README.md §3。外部命令一律 timeout -k。
set -u
DEV=${1:-/dev/input/event2}
pass=0; fail=0
ok()   { echo "OK   $*"; pass=$((pass+1)); }
bad()  { echo "FAIL $*"; fail=$((fail+1)); }

echo "== 1/3 FF 链路基线（人手应感到 0.3 s 震动）"
timeout -k 2 5 ffrumble "$DEV" 300 0xffff && ok "ffrumble 触发无错（问人手：震了吗）" \
                                          || bad "ffrumble 触发失败"

echo "== 2/3 OSK 打字时 FF 是否被触发（另开一路打 OSK 几个键）"
echo "   现在在 OSK 上按任意 3 个键…"
timeout -k 3 8 getevent -c 3 "$DEV" >/tmp/haptic-ev.$$ 2>&1
if grep -q 'SYN_REPORT' /tmp/haptic-ev.$$; then
  ok "FF 事件到达内核（$(grep -c SYN_REPORT /tmp/haptic-ev.$$) 次 SYN）"
else
  bad "8 s 内无 FF 事件：补丁没进被执行的二进制，或 env 未落到 osk-stub"
fi
rm -f /tmp/haptic-ev.$$

echo "== 3/3 env 是否落到 osk-stub 进程"
PID=$(timeout -k 2 5 pgrep -x phosh-osk-stub | head -1)
if [ -n "${PID:-}" ] && tr '\0' '\n' < "/proc/$PID/environ" | grep -q '^ELDEN_OSK_HAPTIC_DEV='; then
  ok "ELDEN_OSK_HAPTIC_DEV 在 osk-stub environ 里"
else
  bad "env 未落到 osk-stub（drop-in 没写或没 daemon-reload/restart）"
fi

echo "== 结果: PASS=$pass FAIL=$fail"
[ "$fail" = 0 ]
