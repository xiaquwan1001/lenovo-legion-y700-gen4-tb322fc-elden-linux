#!/bin/sh
# bench-run.sh — 设备侧 CPU/GPU/内存/磁盘 基准（task-7，工具自适应，缺少的自动跳过）
#
# 设计：只用设备上已有的工具（mesa-demos / vulkan-tools 已在 rootfs）；
#       可选增强工具用 apk 装：sysbench stress-ng vkmark fio 7zip iperf3。
#       全程记录温度/频点，结束时打印摘要；原始日志留在 OUTDIR。
#
# 用法（设备上 root，Alpine busybox sh）：
#   sh bench-run.sh                 # 标准一轮（约 2-3 分钟）
#   DUR=30 sh bench-run.sh          # 每项时长
#   ONLY=cpu sh bench-run.sh        # 只跑某类（cpu|mem|disk|gles|vk|all）
#
# 环境：DUR(每项秒,默认15) OUTDIR(默认/var/log/bench-<ts>) ONLY(默认all)
set -u
DUR=${DUR:-15}
ONLY=${ONLY:-all}
TS=$(date +%Y%m%d-%H%M%S)
OUTDIR=${OUTDIR:-/var/log/bench-$TS}
mkdir -p "$OUTDIR"
N=$(nproc 2>/dev/null || echo 8)
SUM="$OUTDIR/summary.txt"

say() { echo "[bench] $*" | tee -a "$SUM"; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- 温度/频点采样（后台） ---
sample() {
	while :; do
		tmax=0
		for z in /sys/class/thermal/thermal_zone*; do
			[ -r "$z/temp" ] || continue
			t=$(cat "$z/temp" 2>/dev/null); [ -n "$t" ] || continue
			[ "$t" -gt "$tmax" ] 2>/dev/null && tmax=$t
		done
		printf 'T=%s tmax=%s c0=%s gpu=%s\n' "$(date +%s)" "$tmax" \
			"$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq 2>/dev/null)" \
			"$(cat /sys/class/devfreq/*gpu*/cur_freq 2>/dev/null | head -1)" >> "$OUTDIR/thermal.log"
		sleep 2
	done
}
sample & SPID=$!

# Wayland 会话（GLES/Vulkan 需要）
HAVE_WL=0
for wl in /run/user/0/wayland-0 /run/phosh/wayland-0 /run/user/1000/wayland-0; do
	[ -S "$wl" ] || continue
	export XDG_RUNTIME_DIR=$(dirname "$wl") WAYLAND_DISPLAY=wayland-0
	HAVE_WL=1; break
done

say "=== bench-run $TS  nproc=$N dur=${DUR}s wayland=$HAVE_WL ==="
say "kernel: $(uname -r)"
say "tools: sysbench=$(have sysbench && echo y || echo n) stress-ng=$(have stress-ng && echo y || echo n) fio=$(have fio && echo y || echo n) 7z=$(have 7z && echo y || echo n) vkmark=$(have vkmark && echo y || echo n) vulkaninfo=$(have vulkaninfo && echo y || echo n) es2gears=$(have es2gears_wayland && echo y || echo n) glmark2=$(have glmark2-es2-wayland && echo y || echo n)"

run() { # run <logname> <cmd...>
	name=$1; shift
	say "--- $name"
	if "$@" > "$OUTDIR/$name.log" 2>&1; then say "  ok"; else say "  FAILED (see $OUTDIR/$name.log)"; fi
}

# ---------------- CPU ----------------
if [ "$ONLY" = all ] || [ "$ONLY" = cpu ]; then
	if have sysbench; then
		run sysbench-cpu sysbench cpu --cpu-max-prime=20000 --threads="$N" --time="$DUR" --events=0 run
		grep -E 'events per second|total number of events|latency' "$OUTDIR/sysbench-cpu.log" >> "$SUM" 2>/dev/null
	else say "  (no sysbench; 可 apk add sysbench)"; fi
	if have 7z; then
		run 7zip-bench sh -c "7z b -mmt=$N"
		grep -E '^Tot:|^Avr:|^CPU  usage' "$OUTDIR/7zip-bench.log" >> "$SUM" 2>/dev/null
	fi
	if have stress-ng; then
		run stress-ng-cpu stress-ng --cpu "$N" --cpu-method matrixprod --metrics-brief --timeout "${DUR}s"
		grep -E 'bogo ops/s' "$OUTDIR/stress-ng-cpu.log" | tail -3 >> "$SUM" 2>/dev/null
	fi
	if ! have sysbench && ! have stress-ng && ! have 7z; then
		run sha256-speed sh -c "dd if=/dev/zero bs=1M count=256 2>/dev/null | sha256sum; \
			dd if=/dev/zero bs=1M count=256 2>/dev/null | time -p sha256sum"
	fi
fi

# ---------------- 内存 ----------------
if [ "$ONLY" = all ] || [ "$ONLY" = mem ]; then
	if have sysbench; then
		run sysbench-mem sysbench memory --memory-total-size=8G --threads="$N" --time="$DUR" run
		grep -E 'transferred|MiB/sec' "$OUTDIR/sysbench-mem.log" >> "$SUM" 2>/dev/null
	elif have stress-ng; then
		run stress-ng-vm stress-ng --vm 2 --vm-bytes 1G --metrics-brief --timeout "${DUR}s"
	fi
fi

# ---------------- 磁盘 ----------------
if [ "$ONLY" = all ] || [ "$ONLY" = disk ]; then
	if have fio; then
		run fio-seqread fio --name=seqread --rw=read --bs=1M --size=256M \
			--filename="$OUTDIR/fio.bin" --ioengine=psync --runtime="$DUR" --time_based --group_reporting
		grep -E 'READ:|bw=' "$OUTDIR/fio-seqread.log" >> "$SUM" 2>/dev/null
		rm -f "$OUTDIR/fio.bin"
	else
		run dd-read sh -c "dd if=/dev/zero of=$OUTDIR/dd.bin bs=1M count=256 conv=fsync 2>&1; \
			dd if=$OUTDIR/dd.bin of=/dev/null bs=1M 2>&1; rm -f $OUTDIR/dd.bin"
		grep -E 'bytes|MB/s' "$OUTDIR/dd-read.log" >> "$SUM" 2>/dev/null
	fi
fi

# ---------------- GPU / GLES ----------------
if [ "$ONLY" = all ] || [ "$ONLY" = gles ]; then
	if [ "$HAVE_WL" = 1 ]; then
		if have glmark2-es2-wayland; then
			run glmark2-es2 glmark2-es2-wayland -b build:duration="$DUR"
			grep -E 'glmark2 Score' "$OUTDIR/glmark2-es2.log" >> "$SUM" 2>/dev/null
		elif have es2gears_wayland; then
			run es2gears timeout "$((DUR + 3))" es2gears_wayland
			grep -oE '[0-9.]+ FPS' "$OUTDIR/es2gears.log" | awk '{s+=$1; n++} END{if(n)printf "es2gears: avg %.1f FPS over %d samples\n", s/n, n}' >> "$SUM"
		fi
	else say "  (no wayland socket — skip GLES)"; fi
fi

# ---------------- GPU / Vulkan ----------------
if [ "$ONLY" = all ] || [ "$ONLY" = vk ]; then
	if have vulkaninfo; then
		run vulkaninfo vulkaninfo --summary
		grep -iE 'driverName|driverInfo|deviceName|apiVersion' "$OUTDIR/vulkaninfo.log" | sort -u >> "$SUM" 2>/dev/null
	fi
	if have vkmark && [ "$HAVE_WL" = 1 ]; then
		run vkmark vkmark -b vertex -b clear --winsys wayland -s 800x600 -d "$((DUR * 1000))"
		grep -iE 'Score|FPS' "$OUTDIR/vkmark.log" | tail -4 >> "$SUM" 2>/dev/null
	else
		say "  (no vkmark or no wayland; 可选 apk add vkmark)"
	fi
fi

kill "$SPID" 2>/dev/null
{
	echo "--- thermal 峰值 ---"
	awk '{for(i=1;i<=NF;i++){if($i ~ /^tmax=/){split($i,a,"=");if(a[2]+0>m)m=a[2]+0}}} END{printf "max thermal temp = %.1f C\n", m/1000}' "$OUTDIR/thermal.log"
} >> "$SUM"

say ""
say "===== SUMMARY ====="
cat "$SUM"
