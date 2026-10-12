#!/bin/sh
# q24-dev-dstate.sh — D 态进程清单（台架健康前置检查，PITFALLS #198）。
n=0
for p in /proc/[0-9]*; do
  st=$(awk '/^State:/{print $2}' "$p/status" 2>/dev/null)
  if [ "$st" = D ]; then n=$((n+1)); echo "D pid=${p#/proc/} $(tr -d '\0' < "$p/cmdline" 2>/dev/null) wchan=$(cat "$p/wchan" 2>/dev/null)"; fi
done
echo "D_STATE_COUNT=$n"
