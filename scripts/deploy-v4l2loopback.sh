#!/bin/bash
# deploy-v4l2loopback.sh — 为**当前在机内核**（读设备 uname -r）构建并部署 v4l2loopback
#
# 为什么需要脚本（PITFALLS #440）：容器相机要 `/dev/video100`，而
#   ① 模块必须**按目标 UTS 逐字匹配 vermagic**（否则设备拒载，且报错只说 invalid module format）；
#   ② 默认 `max_buffers=2`、且写端 gst 只申请 3 个 ⇒ Android external HAL 要 4 个会失败，
#      所以 `patches/extmod/0001-v4l2loopback-min-4-buffers.patch` 必须打上。
#
# 用法：
#   bash scripts/deploy-v4l2loopback.sh                 # 默认 TARGET=root@192.168.7.1
#   KSRC=build/vk151 bash scripts/deploy-v4l2loopback.sh # 指定内核源码树
#   SKIP_BUILD=1 bash scripts/deploy-v4l2loopback.sh    # 只重装 out/ 里已有产物
#
# 回退：设备上删 `/lib/modules/<UTS>/extra/v4l2loopback.ko` + `depmod -a`，或 `modprobe -r v4l2loopback`。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET=${TARGET:-root@192.168.7.1}
SSH_OPTS=${SSH_OPTS:--o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}
KSRC=${KSRC:-$ROOT/build/vk151}
SRC=$ROOT/build/extmod/v4l2loopback
PATCH=$ROOT/patches/extmod/0001-v4l2loopback-min-4-buffers.patch
PATCH2=$ROOT/patches/extmod/0002-v4l2loopback-mjpeg-sizeimage-2bytes.patch
SKIP_BUILD=${SKIP_BUILD:-0}
CROSS=${CROSS:-aarch64-linux-gnu-}

say() { printf '[v4l2loopback] %s\n' "$*"; }
# shellcheck disable=SC2086
rsh() { ssh $SSH_OPTS "$TARGET" "$@"; }

UTS=$(rsh 'uname -r' | tr -d '\r')
[ -n "$UTS" ] || { say "取不到设备 UTS"; exit 1; }
say "设备 UTS = $UTS"

OUT=$ROOT/out/extmod-$(printf '%s' "$UTS" | sed 's/.*-debug-//; s/[-+].*//')
mkdir -p "$OUT"

if [ "$SKIP_BUILD" = 0 ]; then
	[ -d "$SRC" ] || { say "缺源码树 $SRC（先 git clone v4l2loopback 到 build/extmod/）"; exit 1; }
	if [ -f "$PATCH" ] && ! grep -q "req_count < 4" "$SRC/v4l2loopback.c"; then
		say "打补丁：$(basename "$PATCH")"
		patch -d "$SRC" -p1 < "$PATCH" || { say "打补丁失败"; exit 1; }
	fi
	# 0002：MJPEG/JPEG 的 depth 32 -> 16。压缩格式的 sizeimage = w*h*depth/8，
	# 32 给出 w*h*4，Android external camera HAL 用 kMaxBytesPerPixel=2 做上限
	# （ExternalCameraDeviceSession.cpp），超了直接 -EINVAL ⇒ configureStreams 失败。
	if [ -f "$PATCH2" ] && ! grep -q "depth = 16," "$SRC/v4l2loopback_formats.h"; then
		say "打补丁：$(basename "$PATCH2")"
		patch -d "$SRC" -p1 < "$PATCH2" || { say "打补丁失败"; exit 1; }
	fi
	# vermagic 逐字匹配：临时把生成文件改成目标 UTS，编完立刻恢复（见 reports/v4l2loopback-build-20261026.md）
	RELF=$KSRC/include/config/kernel.release
	UTSH=$KSRC/include/generated/utsrelease.h
	cp "$RELF" /tmp/.v4l2-rel.bak && cp "$UTSH" /tmp/.v4l2-uts.bak
	printf '%s\n' "$UTS" > "$RELF"
	printf '#define UTS_RELEASE "%s"\n' "$UTS" > "$UTSH"
	say "编译（KDIR=$KSRC）"
	make -C "$KSRC" M="$SRC" ARCH=arm64 CROSS_COMPILE="$CROSS" LD=ld.lld modules -j26 \
		> /tmp/v4l2-build.log 2>&1 || { say "编译失败，见 /tmp/v4l2-build.log"; cp /tmp/.v4l2-rel.bak "$RELF"; cp /tmp/.v4l2-uts.bak "$UTSH"; exit 1; }
	cp /tmp/.v4l2-rel.bak "$RELF"; cp /tmp/.v4l2-uts.bak "$UTSH"
	cp "$SRC/v4l2loopback.ko" "$OUT/v4l2loopback.ko"
	got=$(modinfo "$OUT/v4l2loopback.ko" | awk '/^vermagic/{print $2}')
	[ "$got" = "$UTS" ] || { say "vermagic 不匹配：$got ≠ $UTS"; exit 1; }
	say "vermagic OK"
else
	say "SKIP_BUILD=1，用 $OUT/v4l2loopback.ko"
fi

say "部署 → /lib/modules/$UTS/extra/ 并加载（max_buffers=8）"
rsh "mkdir -p /lib/modules/$UTS/extra"
# shellcheck disable=SC2086
scp -q $SSH_OPTS "$OUT/v4l2loopback.ko" "$TARGET:/lib/modules/$UTS/extra/"
rsh 'depmod -a
	# ⚠ 若模块仍被占用（生产者 gst / 容器 camera HAL 开着设备），`modprobe -r` 会失败，
	# 而 `modprobe` 随后是 no-op ⇒ 你以为换了新模块，实际还在跑旧代码（2026-10-27 实测踩过）。
	if lsmod | grep -q "^v4l2loopback"; then
		modprobe -r v4l2loopback 2>/dev/null || {
			echo "FAIL: v4l2loopback 仍在使用（先 pkill gst-launch / 停容器相机），未换模块" >&2
			lsmod | grep -E "^v4l2loopback|camera" >&2
			exit 3
		}
	fi
	modprobe v4l2loopback exclusive_caps=1 video_nr=100 max_buffers=8 && \
	ls -l /dev/video100 && cat /sys/module/v4l2loopback/parameters/max_buffers'
say "done（相机生产者：bash scripts/cam-loopback.sh start front 1280x720 30）"
