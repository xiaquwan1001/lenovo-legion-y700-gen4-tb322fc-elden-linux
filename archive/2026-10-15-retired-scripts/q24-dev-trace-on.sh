#!/bin/sh
# q24-dev-trace-on.sh -- 清空所有 tracepoint 后启用 $@ 指定的 events/<name> 目录，并回报仍开启的集合
echo 0 > /sys/kernel/debug/tracing/tracing_on
for d in /sys/kernel/debug/tracing/events/*/; do echo 0 > $d/enable 2>/dev/null; done
echo > /sys/kernel/debug/tracing/trace
for d in $@; do
  p=/sys/kernel/debug/tracing/$d
  [ -d $p ] && echo 1 > $p/enable
done
echo 1 > /sys/kernel/debug/tracing/tracing_on
echo trace_on
for d in /sys/kernel/debug/tracing/events/*/; do n=$(basename $d); v=$(cat $d/enable 2>/dev/null); [ "$v" != 0 ] && echo $n=enabled; done