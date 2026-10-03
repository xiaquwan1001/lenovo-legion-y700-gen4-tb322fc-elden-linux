#!/bin/sh
# thermal-stress.sh — 温控压测驱动（在设备上运行）
#
# 同时加载 CPU (stress-ng) + GPU (es2gears_wayland)，期间由 thermal-watch.sh
# 采样温度/频点；结束时输出峰值与降频点摘要。
#
# 用法（设备上 root）：
#   DURATION=420 /tmp/thermal-stress.sh
#   CPUS=8 GPU_N=1 DURATION=600 /tmp/thermal-stress.sh
#
# 环境变量：DURATION(默认420s) CPUS(默认全部) GPU_N(默认1) INTERVAL(默认2s)
set -u
DURATION=${DURATION:-420}
CPUS=${CPUS:-$(nproc 2>/dev/null || echo 8)}
GPU_N=${GPU_N:-1}
INTERVAL=${INTERVAL:-2}
LOG=${LOG:-/var/log/thermal-watch.log}
WATCH=${WATCH:-/tmp/thermal-watch.sh}

[ -x "$WATCH" ] || { echo "missing $WATCH"; exit 1; }
command -v stress-ng >/dev/null || { echo "stress-ng not installed"; exit 1; }

say() { echo "[stress] $*"; }
say "start: cpu=$CPUS gpu=$GPU_N duration=${DURATION}s interval=${INTERVAL}s"

# 记录起始温度/频点
say "before: $(for z in /sys/class/thermal/thermal_zone*; do printf "%s=%s " "$(cat $z/type)" "$(cat $z/temp)"; done | head -c 300)"

# 1) 监控
INTERVAL=$INTERVAL LOG=$LOG "$WATCH" --duration "$DURATION" >/dev/null 2>&1 &
tw=$!
sleep 1

# 2) CPU 负载
stress-ng --cpu "$CPUS" --cpu-method matrixprod --timeout "$((DURATION-5))"s \
	--metrics --quiet >/dev/null 2>&1 &
sp=$!

# 3) GPU 负载（Wayland 会话）。找不到显示则跳过，仅做 CPU 压测。
gpu_pids=""
if [ "$GPU_N" -gt 0 ] && [ -S /run/phosh/wayland-0 ]; then
	i=0
	while [ $i -lt "$GPU_N" ]; do
		XDG_RUNTIME_DIR=/run/phosh WAYLAND_DISPLAY=wayland-0 \
			timeout "$((DURATION-3))"s es2gears_wayland >/dev/null 2>&1 &
		gpu_pids="$gpu_pids $!"
		i=$((i+1))
	done
	say "gpu load started (es2gears_wayland x$GPU_N)"
else
	say "WARNING: no wayland socket / GPU_N=0 -> CPU-only stress"
fi

say "load running; monitoring $((DURATION-5))s..."
wait $sp 2>/dev/null
for p in $gpu_pids; do kill "$p" 2>/dev/null; done
wait $tw 2>/dev/null
say "stress finished"
