#!/bin/sh
# elden-sensorproxy-sync.sh — 让 iio-sensor-proxy 在「传感器真出数」之后再起（D16 开机竞态）
#
# 为什么需要（2026-11-27 vk197 实测）：`iio-sensor-proxy`（3.9 ssc 版）在开机时先于
# hexagonrpcd 的 SSC attach 起来，于是 `HasAccelerometer` 一直是 false；手工
# `systemctl restart iio-sensor-proxy` 才三属性全 true。本脚本把那次 restart 做成
# 「等到真出数」再执行一次，避免固定 sleep 的假绿/假红。
#
# 判据（可复跑）：
#   - 本脚本输出 `ready after Ns (HasAccelerometer=true)`
#   - `busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer` = true
#
# 注意：**不设** After=elden-sensorspd.service —— 该单元是 oneshot 跑常驻 hexagonrpcd，
# 永不「start 完成」，按 After= 排队会把本单元一直堵到超时。这里只靠轮询。
set -u
BUDGET=${BUDGET:-150}      # 总等待上限（秒）
INTERVAL=${INTERVAL:-5}
PROP='net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer'
SSCCLI=${SSCCLI:-ssccli}

getprop() {
	busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy \
		net.hadess.SensorProxy HasAccelerometer 2>/dev/null | awk '{print $2}'
}

i=0
while [ "$i" -lt $((BUDGET / INTERVAL)) ]; do
	i=$((i + 1))
	if timeout 8 "$SSCCLI" --sensor accelerometer --timeout 3 2>/dev/null \
		| grep -q 'Accelerometer sensor measurement'; then
		if [ "$(getprop)" != "true" ]; then
			systemctl restart iio-sensor-proxy 2>/dev/null || true
			sleep 3
		fi
		echo "elden-sensorproxy-sync: ready after $((i * INTERVAL))s (HasAccelerometer=$(getprop))"
		exit 0
	fi
	sleep "$INTERVAL"
done
echo "elden-sensorproxy-sync: SSC accelerometer not streaming after ${BUDGET}s - leaving iio-sensor-proxy untouched" >&2
exit 0
