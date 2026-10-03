#!/bin/sh
# probe-camera-sensors.sh — TB322FC (elden/SM8750) 相机 + 传感器 只读探测
#
# 用途：只读采集设备当前相机(CAMSS/CCI/CSI/V4L2)与惯性/环境传感器(IIO)的硬件/驱动状态。
# 安全：不写入任何东西、不 modprobe、不改 /data、不刷机、不重启。
#
# 用法：
#   ./probe-camera-sensors.sh                # 从主机通过 SSH 采集（默认 root@192.168.7.1）
#   DEVICE_HOST=root@192.168.7.1 ./probe-camera-sensors.sh
#   ./probe-camera-sensors.sh --local        # 直接在设备上以 root 运行
#
# 依赖：ssh（远程模式）、sh + 标准 busybox/coreutils（设备侧）。

set -u
HOST="${DEVICE_HOST:-root@192.168.7.1}"
SSH="ssh -o ConnectTimeout=6 -o StrictHostKeyChecking=no"

PROBE_BODY='
echo "===== 1. 内核 / 设备树 ====="
uname -a
echo "--- model/compatible ---"
tr "\0" " " < /proc/device-tree/compatible 2>/dev/null; echo
cat /proc/device-tree/model 2>/dev/null | tr "\0" "\n"; echo

echo "===== 2. 相机相关 DT 节点 (live) ====="
for n in isp@ad27000 cci@ac7b000 cci@ac7c000; do
  d=/proc/device-tree/soc@0/$n
  [ -d "$d" ] && echo "present: $n" || echo "MISSING: $n"
done
echo "--- camss/cci 下挂的 sensor 子节点 ---"
find /proc/device-tree/soc@0/cci@ac7b000 /proc/device-tree/soc@0/cci@ac7c000 -name "camera@*" -o -name "lens@*" 2>/dev/null | sed "s#/proc/device-tree##"

echo "===== 3. I2C 总线与设备 ====="
ls /sys/bus/i2c/devices/ 2>/dev/null
echo "--- 各 i2c 设备名 ---"
for d in /sys/bus/i2c/devices/i2c-*/[0-9]*; do
  [ -d "$d" ] && echo "$(basename "$d"): $(cat "$d/name" 2>/dev/null)"
done

echo "===== 4. CCI (相机控制接口) 总线 ====="
ls /sys/bus/cci/devices/ 2>/dev/null || echo "(无 /sys/bus/cci)"

echo "===== 5. V4L2 / media 设备 ====="
ls /dev/video* /dev/media* /dev/v4l-subdev* 2>/dev/null || echo "(无 video/media 设备节点)"
echo "--- /sys/class/video4linux ---"
ls /sys/class/video4linux/ 2>/dev/null || echo "(无)"
echo "--- media graph 概要 ---"
for m in /dev/media*; do
  [ -e "$m" ] && echo "$m: $(cat /sys/class/media/$(basename "$m")/model 2>/dev/null)"
done

echo "===== 6. 相机/传感器 内核模块状态 ====="
lsmod 2>/dev/null | grep -iE "camss|s5kj|gc08|gt97|wl2868|cci|csiphy|iio|lsm6|st_lsm"
echo "--- 已加载模块目录 ---"
ls /sys/module/ 2>/dev/null | grep -iE "camss|s5kj|gc08|gt97|wl2868|cci|csiphy|iio|lsm6"

echo "===== 7. 内核配置 (相机/IIO/稳压) ====="
zcat /proc/config.gz 2>/dev/null | grep -iE "QCOM_CAMSS|VIDEO_S5KJ|VIDEO_GC08|VIDEO_GT97|REGULATOR_WL2868|IIO_ST_LSM6|IIO_ACCEL|IIO_GYRO|IIO_MAGN|VIDEO_CAMERA" || echo "(无 /proc/config.gz 或未匹配)"

echo "===== 8. IIO 设备 (惯性/环境传感器) ====="
ls /sys/bus/iio/devices/ 2>/dev/null || echo "(无 IIO 设备)"
echo "--- IIO 触发 ---"
ls /sys/bus/iio/devices/trigger* 2>/dev/null || echo "(无)"

echo "===== 9. dmesg 相机/传感器 相关行 ====="
dmesg 2>/dev/null | grep -iE "camss|csiphy|csid|vfe|s5kj|gc08a8|gt9764|wl2868|cci|slpi|ssc|sns_|iio|accel|gyro|lsm6" | grep -viE "dependency cycle" | tail -40

echo "===== 10. 传感器 DSP (SLPI/SSC) 状态 ====="
ls /sys/class/remoteproc/ 2>/dev/null
for r in /sys/class/remoteproc/remoteproc*/; do
  [ -d "$r" ] && echo "$(basename "$r"): name=$(cat "$r/name" 2>/dev/null) state=$(cat "$r/state" 2>/dev/null)"
done
echo "--- adspslpi 保留内存 (传感器核与其共用) ---"
grep -iE "adspslpi|slpi|sensor" /proc/iomem 2>/dev/null | head
'

if [ "${1:-}" = "--local" ]; then
  sh -c "$PROBE_BODY"
else
  $SSH "$HOST" "sh -c '$PROBE_BODY'" 2>&1
fi
