#!/bin/bash
# deploy-camera-modules.sh — deploy the mainline camera stack to a RUNNING
# device WITHOUT flashing boot and WITHOUT rebooting (fallback path).
#
# Preferred path is the zero-write boot image (camera modules baked into the
# ramdisk, auto-loaded by /init at cold boot):
#     fastboot boot out/boot-elden-vk49.img        # persistent root + camera
#     fastboot boot out/boot-elden-vk49-ram.img    # pure RAM + camera
# Use this script when the device is already running an older boot image and
# you want the camera stack without re-booting it.
#
# It installs out/camera-modules-<KV>.tar.gz (same build as the running kernel)
# into /lib/modules/<KV>/ and calls scripts/camera-modules-load.sh, which runs
# depmod and modprobes the stack in dependency order.
#
# usage:
#   bash scripts/deploy-camera-modules.sh              # copy + depmod + load + evidence
#   ONLY_COPY=1 bash scripts/deploy-camera-modules.sh  # copy/unpack only
#
# Device discipline: this writes to the rootfs; coordinate before running.
set -euo pipefail
export PATH="$HOME/bin:$PATH"
ROOT=${ROOT:-$HOME/y700-elden}
DEV=${DEV:-root@192.168.7.1}
SSH="ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no $DEV"
SCP="scp -o ConnectTimeout=8 -o StrictHostKeyChecking=no"

# KV: prefer the on-disk marker, else ask the tree.  Must equal `uname -r`.
KV=$(grep -m1 '' "$ROOT/patches/camera-kver" 2>/dev/null || true)
[ -n "$KV" ] || KV=$(cd "$ROOT/linux" && make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- kernelrelease 2>/dev/null)
BUNDLE="$ROOT/out/camera-modules-$KV.tar.gz"
[ -f "$BUNDLE" ] || { echo "missing bundle: $BUNDLE (run scripts/package-camera-modules.sh)"; exit 1; }

echo "KV=$KV"
echo "bundle=$BUNDLE ($(du -h "$BUNDLE" | cut -f1))"

# Guard: the module vermagic must match the *running* kernel, not just the tree.
RUNKV=$($SSH 'uname -r' 2>/dev/null || true)
if [ -n "$RUNKV" ] && [ "$RUNKV" != "$KV" ]; then
	echo "REFUSING: device runs $RUNKV but bundle is for $KV (rebuild the bundle for the running kernel)" >&2
	exit 1
fi

# Guard (ABI): vermagic 只比 UTS 字符串，拦不住 struct 布局漂移（PITFALLS #367：
# CONFIG_SUSPEND 差异 → struct device.of_node 偏移 624 vs 680 → fastrpc 读成 NULL →
# rpmsg 死循环 + `/dev/fastrpc-*` 全缺 + SSC 传感器全废）。这里比对模块构建树的
# .config 与现役 SSOT 参考 config 的 27 项 ABI 敏感项，不一致就拒绝部署。
CAMD_TREE=${CAMD_TREE:-$ROOT/$(sed -n 's/^\(build\/[^ #]*\).*/\1/p' "$ROOT/patches/current-tree" 2>/dev/null | head -1)}
if [ -f "$CAMD_TREE/.config" ]; then
	echo "== 0) ABI gate (tree=$CAMD_TREE) =="
	bash "$ROOT/scripts/check-abi-config.sh" "$CAMD_TREE/.config" || {
		echo "REFUSING: 模块构建树与 SSOT 参考 config 的 ABI 敏感项不一致（见上）；修好或显式 SKIP_ABI_ASSERT=1 绕过" >&2
		exit 1
	}
else
	echo "WARN: 找不到 $CAMD_TREE/.config，跳过 ABI 门禁（用 CAMD_TREE=<树目录> 指定）" >&2
fi

echo "== 1) transfer =="
$SSH "cat > /tmp/camera-modules.tar.gz" < "$BUNDLE"
$SSH "mkdir -p /lib/modules/$KV && tar xzf /tmp/camera-modules.tar.gz -C /lib/modules/$KV && depmod -a $KV && echo extracted"

echo "== 2) install loader =="
$SCP "$ROOT/scripts/camera-modules-load.sh" "$DEV:/usr/local/sbin/camera-modules-load.sh"
$SSH "chmod 755 /usr/local/sbin/camera-modules-load.sh"

[ "${ONLY_COPY:-0}" = "1" ] && { echo "ONLY_COPY=1 → not loading"; exit 0; }

echo "== 3) load (depmod + modprobe dependency order) =="
$SSH "/usr/local/sbin/camera-modules-load.sh"

echo "== 4) evidence =="
$SSH 'echo "### i2c devices"; ls /sys/bus/i2c/devices/ | sort;
echo "### v4l/media"; ls -l /dev/video* /dev/media* /dev/v4l-subdev* 2>/dev/null;
echo "### media-ctl"; media-ctl -p 2>&1 | head -80;
echo "### v4l2-ctl"; v4l2-ctl --list-devices 2>&1 | head -30;
echo "### dmesg cam"; dmesg | grep -iE "camss|csiphy|cci|s5k|gc08|gt9764|wl2868|titan|dependency cycle" | tail -50'
