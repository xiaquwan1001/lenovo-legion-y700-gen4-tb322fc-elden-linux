#!/data/data/com.termux/files/usr/bin/sh
# sensor-send-termux.sh — Android 侧传感器转发器（C4 真值来源）
#
# 原理：Termux:API 的 termux-sensor 流式输出 JSON 行
#   {"sensor":"Accelerometer Sensor","values":[x,y,z],"timestamp":...}
# 本脚本把它映射成 eldroid-sensord 文本协议行，经 UDP 发给跑 Waydroid 的那台单元：
#   acc x y z / gyr x y z / mag x y z / light v / prox v
#
# 前置：Termux + Termux:API app（`pkg install termux-api`，手机上装 Termux:API APK）
# 用法（Termux 里）：
#   sh sensor-send-termux.sh <宿主IP> [端口]
#   例：sh sensor-send-termux.sh 192.168.1.23          # 目标 = 跑 Waydroid 单元的 wlan IP
#
# 两台 Y700 同网段时：源机(a 槽 Android) → 目标机(b 槽 mainline+Waydroid)。
# 目标机 IP 看它的 `ip addr show wlan0`；也可走 USB-NCM 192.168.7.1（需同 USB 段）。
#
# 停止：Ctrl-C（termux-sensor 子进程一并退出）。
set -u

HOST=${1:-}
PORT=${2:-52012}
[ -n "$HOST" ] || { echo "usage: $0 <host> [port]"; exit 2; }
command -v termux-sensor >/dev/null || { echo "需要 termux-api（pkg install termux-api + Termux:API app）"; exit 1; }

# UDP 发送器：busybox nc -u 或 socat
send_udp() {
  if command -v busybox >/dev/null; then
    busybox nc -u -w0 "$HOST" "$PORT"
  else
    nc -u -w0 "$HOST" "$PORT"
  fi
}

echo "[sensor-send] -> udp://$HOST:$PORT  (Ctrl-C 停止)"
echo "[sensor-send] termux-sensor 20 Hz，按 Ctrl-C 前先锁屏免采集中断"

# termux-sensor: -s 指定传感器（可重复），-d 采样间隔 ms
termux-sensor -s "Accelerometer" -s "Gyroscope" -s "Magnetic" -s "Light" -s "Proximity" -d 50 2>/dev/null |
while IFS= read -r line; do
  case "$line" in
    *Accelerometer*) t=acc ;;
    *Gyroscope*)     t=gyr ;;
    *Magnetic*)      t=mag ;;
    *Light*)         t=light ;;
    *Proximity*)     t=prox ;;
    *) continue ;;
  esac
  # 提取 values 数组里的浮点（toybox sed 兼容写法）
  vals=$(printf '%s' "$line" | sed -n 's/.*"values":\[\([^]]*\)\].*/\1/p')
  case "$t" in
    acc|gyr|mag)
      x=$(printf '%s' "$vals" | cut -d, -f1)
      y=$(printf '%s' "$vals" | cut -d, -f2)
      z=$(printf '%s' "$vals" | cut -d, -f3)
      msg="$t $x $y $z"
      ;;
    *)
      msg="$t $vals"
      ;;
  esac
  # 每行一条 UDP 包
  printf '%s\n' "$msg" | send_udp
done
