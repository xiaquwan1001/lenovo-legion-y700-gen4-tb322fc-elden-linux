#!/bin/bash
# deploy-camera-modules.sh — 最小可跑相机通路：只部署 .ko（不刷 boot、不重启）
#
# 前置：主机侧已 `make modules` + `make modules_install INSTALL_MOD_PATH=/tmp/modstage`
#       并 `out/camera-modules-<KV>.tar.gz` 已生成（见 CAMERA-2026-10-02.md）。
#
# 用法：
#   bash scripts/deploy-camera-modules.sh              # 部署 + depmod + 按序 modprobe + 采集证据
#   ONLY_COPY=1 bash scripts/deploy-camera-modules.sh  # 只拷贝/解包，不 modprobe
#
# 设备纪律：写 rootfs 前先 `send SageYak` 报备（音频 task-8 优先占用刷写权）。
set -euo pipefail
ROOT=${ROOT:-$HOME/y700-elden}
DEV=${DEV:-root@192.168.7.1}
SSH="ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no $DEV"
SCP="scp -o ConnectTimeout=8 -o StrictHostKeyChecking=no"
KV=$(grep -m1 '' "$ROOT/patches/camera-kver" 2>/dev/null || true)
[ -n "$KV" ] || KV=$(cd "$ROOT/linux" && make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- kernelrelease 2>/dev/null)
BUNDLE="$ROOT/out/camera-modules-$KV.tar.gz"
[ -f "$BUNDLE" ] || { echo "缺 bundle: $BUNDLE"; exit 1; }
echo "KV=$KV  bundle=$BUNDLE"

echo "== 1) 传包 =="
$SSH "cat > /tmp/camera-modules.tar.gz" < "$BUNDLE"
$SSH "mkdir -p /lib/modules/$KV && tar xzf /tmp/camera-modules.tar.gz -C /lib/modules/$KV && depmod -a $KV && echo extracted"

[ "${ONLY_COPY:-0}" = "1" ] && { echo "ONLY_COPY=1 → 不 modprobe"; exit 0; }

echo "== 2) 按依赖序加载 =="
K=/lib/modules/$KV/kernel
ORDER="
drivers/clk/qcom/camcc-sm8750.ko
drivers/clk/qcom/cambistmclkcc-sm8750.ko
drivers/i2c/busses/i2c-qcom-cci.ko
drivers/regulator/wl2868c-regulator.ko
drivers/media/mc/mc.ko
drivers/media/v4l2-core/videodev.ko
drivers/media/v4l2-core/v4l2-async.ko
drivers/media/v4l2-core/v4l2-fwnode.ko
drivers/media/v4l2-core/v4l2-cci.ko
drivers/media/common/videobuf2/videobuf2-common.ko
drivers/media/common/videobuf2/videobuf2-memops.ko
drivers/media/common/videobuf2/videobuf2-dma-sg.ko
drivers/media/common/videobuf2/videobuf2-v4l2.ko
drivers/media/platform/qcom/camss/qcom-camss.ko
drivers/media/i2c/gt9764.ko
drivers/media/i2c/s5kjns.ko
drivers/media/i2c/gc08a8.ko
"
for m in $ORDER; do
  echo "--- insmod $m"
  $SSH "insmod $K/$m 2>&1 | sed 's/^/  /'; lsmod | grep -q \"\$(basename ${m%.ko} | tr - _)\" && echo '  [ok]' || true"
done

echo "== 3) 采集证据 =="
$SSH 'echo "### i2c devices"; ls /sys/bus/i2c/devices/;
echo "### v4l/media"; ls -l /dev/video* /dev/media* /dev/v4l-subdev* 2>/dev/null;
echo "### media-ctl"; media-ctl -p 2>&1 | head -60;
echo "### v4l2-ctl"; v4l2-ctl --list-devices 2>&1 | head -30;
echo "### dmesg cam"; dmesg | grep -iE "camss|csiphy|cci|s5k|gc08|gt9764|wl2868|titan" | tail -40'
