#!/bin/sh
# q28-devprobe.sh — 设备端三态判定 Q28 冷起显示结果。POSIX sh。
# 三态（务必三态：只数风暴签名会把“显示缺失”误判成 GOOD）：
#   NOCARD = 无 /sys/class/drm/card0（DSI/PLL/probe 早期失败，管道没起来）
#   STORM  = 有 card0 但 DSI/DPU bring-up 报错风暴（cmd-DMA timeout / ctl reset / frame done / vblank）
#   GOOD   = 有 card0 + 有 connector connected + 无风暴签名
echo "uname=$(uname -r) uptime=$(cut -d' ' -f1 /proc/uptime)s"
DSIPLL=$(dmesg | grep -c 'DSI PLL(0) lock failed')
DLFAIL=$(dmesg | grep -c 'Failed to create device link')
STORM=$(dmesg | grep -Ec 'command DMA timeout|bonded command DMA failed|Failed to initialize panel|ctl [0-9]+ reset failure|frame done timeout|vblank wait timed out')
HAS=0; for f in /sys/class/drm/card0; do [ -d "$f" ] && HAS=1; done
CONN=""
for d in /sys/class/drm/card0-*; do
  [ -e "$d/status" ] && CONN="$CONN $(basename $d)=$(cat $d/status)"
done
CONNECTED=$(echo "$CONN" | grep -c connected)
echo "DSI_PLL_lockfail=$DSIPLL  device_link_fail=$DLFAIL  storm_sig=$STORM  card0=$HAS  connectors:$CONN"
if [ "$HAS" -eq 0 ]; then
  echo "VERDICT=NOCARD  (显示驱动未绑/无 card0；DSI PLL lockfail=$DSIPLL devlinkfail=$DLFAIL)"
elif [ "$STORM" -gt 0 ]; then
  echo "VERDICT=STORM   (card0 在但 bring-up 风暴 sig=$STORM)"
elif [ "$CONNECTED" -ge 1 ]; then
  echo "VERDICT=GOOD    (card0 + connected + 无风暴)"
else
  echo "VERDICT=NOROUTE (card0 在无 connected 输出)"
fi
