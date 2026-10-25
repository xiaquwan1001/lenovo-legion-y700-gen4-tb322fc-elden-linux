#!/bin/sh
# capture kernel log to disk with line buffering + frequent sync, so the last
# messages before a power-off survive.
: > /root/kmsg-live.log
stdbuf -oL dmesg -w >> /root/kmsg-live.log 2>&1 &
while :; do sync; sleep 0.5; done
