#!/bin/bash
# deploy-sensors-hal.sh — 部署 elden UDP 传感器 HAL 到 Waydroid 容器（C4）
#
# 原理：不改 vendor.img（整块重打 1–3h），用 Waydroid 的 overlay 机制：
#   /var/lib/waydroid/overlay/vendor/* 在容器启动时覆盖到 /vendor
#   - overlay/vendor/bin/hw/android.hardware.sensors@1.0-service.waydroid  ← 新实现（UDP 收值）
#   - overlay/vendor/etc/init/elden-sensors.rc                             ← setprop waydroid.sensors.enabled=true
#
# 注意 prop：用 waydroid.sensors.enabled，**不要** waydroid.stub_sensors_hal
#   （framework 0027 补丁见到 stub prop 会默认 fix-to-user-rotation，锁死自动旋转）。
#
# 值来源（宿主侧，任选）：
#   out/sensord/eldroid-sensord --send <容器IP> --fake            # 兜底纯软件轨迹
#   真值：另一单元 a 槽 Android 跑 env-pass/scripts/sensor-send-termux.sh
#
# 前置：设备已进 mainline（ssh root@192.168.7.1）+ waydroid 已 init（/var/lib/waydroid 存在）
# 用法（主机）：
#   bash scripts/deploy-sensors-hal.sh [--restart] [--ip 192.168.7.1]
# 部署后验证（设备上）：
#   waydroid shell getprop waydroid.sensors.enabled              # true
#   waydroid shell dumpsys sensorservice                         # 列出 5 个 elden * (UDP) 传感器
#   宿主：out/sensord/eldroid-sensord --send <容器IP> --fake --rate 100
#   容器内：地图应开始旋转 / `waydroid shell dumpsys sensorservice` 事件计数增长
set -eu
cd "$(dirname "$0")/.."

TAB=${TAB:-root@192.168.7.1}
RESTART=0
if [ "${1:-}" = "--restart" ]; then RESTART=1; fi
if [ "${1:-}" = "--ip" ]; then TAB="root@${2:-192.168.7.1}"; fi

BIN=out/target-product-none/vendor/bin/hw/android.hardware.sensors@1.0-service.waydroid
# 优先用本机 waydroid-build 树的产物
WB=/mnt/Samsung/waydroid-build
if [ -f "$WB/out/target/product/waydroid_arm64_only/vendor/bin/hw/android.hardware.sensors@1.0-service.waydroid" ]; then
  BIN="$WB/out/target/product/waydroid_arm64_only/vendor/bin/hw/android.hardware.sensors@1.0-service.waydroid"
elif [ -f out/sensord/android.hardware.sensors@1.0-service.waydroid ]; then
  BIN=out/sensord/android.hardware.sensors@1.0-service.waydroid
else
  echo "找不到 HAL 二进制；先在 waydroid-build 树编译：" >&2
  echo "  cd $WB && source build/envsetup.sh && lunch lineage_waydroid_arm64_only-userdebug && mmm hardware/waydroid/sensors -j8" >&2
  exit 1
fi
echo "[deploy-sensors-hal] binary: $BIN ($(du -h "$BIN" | cut -f1))"

echo "[deploy-sensors-hal] 上传到 $TAB"
scp -q -o StrictHostKeyChecking=no "$BIN" "$TAB:/tmp/elden-sensors-service"

ssh -o StrictHostKeyChecking=no "$TAB" '
set -eu
[ -d /var/lib/waydroid ] || { echo "waydroid 未初始化（/var/lib/waydroid 不存在）"; exit 1; }
mkdir -p /var/lib/waydroid/overlay/vendor/bin/hw
mkdir -p /var/lib/waydroid/overlay/vendor/etc/init
cp /tmp/elden-sensors-service /var/lib/waydroid/overlay/vendor/bin/hw/android.hardware.sensors@1.0-service.waydroid
chmod 755 /var/lib/waydroid/overlay/vendor/bin/hw/android.hardware.sensors@1.0-service.waydroid
cat > /var/lib/waydroid/overlay/vendor/etc/init/elden-sensors.rc <<EOF
# elden UDP sensors HAL enable prop (C4)
on early-init
    setprop waydroid.sensors.enabled true
    setprop waydroid.sensors.udp_port 52012
EOF
echo "[deploy] overlay 就位："
ls -l /var/lib/waydroid/overlay/vendor/bin/hw/ /var/lib/waydroid/overlay/vendor/etc/init/
'

if [ "$RESTART" = 1 ]; then
  echo "[deploy-sensors-hal] 重启 waydroid 容器"
  ssh -o StrictHostKeyChecking=no "$TAB" 'waydroid session stop 2>/dev/null; waydroid container stop 2>/dev/null; sleep 1; waydroid container start; sleep 3; waydroid session start 2>/dev/null; waydroid status'
fi

echo "[deploy-sensors-hal] 完成。验证："
echo "  ssh $TAB 'waydroid shell getprop waydroid.sensors.enabled'   # true"
echo "  ssh $TAB 'waydroid shell dumpsys sensorservice'              # 5 个 elden * (UDP) 传感器"
echo "  out/sensord/eldroid-sensord --send <容器IP> --fake --rate 100"
