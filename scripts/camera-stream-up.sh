#!/bin/sh
# camera-stream-up.sh — 在设备上把 camss 采集链路配置到可出流（幂等）。
#
# 背景（2026-10-04/05）：相机模块加载后 csiphy/vfe 的默认格式是
# UYVY8_1X16/1920x1080，而 sensor 输出 raw Bayer（gc08a8=SRGGB10，
# s5kjns=SGRBG10），且 csiphy→csid→vfe→video 链路默认未使能。
# 结果是 v4l2-ctl --stream-mmap 失败（-32）。本脚本按 sensor 的真实格式
# 把整链 pad 格式统一，并使能链路，然后即可 `v4l2-ctl -d /dev/videoN
# --stream-mmap`。非破坏性（不改内核/不改持久盘），重复运行安全。
#
# 用法（设备上）：
#   sh /tmp/camera-stream-up.sh front     # gc08a8 -> csiphy4 -> csid0 -> vfe0_rdi0 -> /dev/video0
#   sh /tmp/camera-stream-up.sh rear      # s5kjns -> csiphy3 -> csid0 -> vfe0_rdi1 -> /dev/video1
#   sh /tmp/camera-stream-up.sh stream front [N]   # 配置并抓 N 帧（默认 3）
set -eu
WHICH=${1:-front}
DO_STREAM=${2:-}
N=${3:-3}

M="media-ctl -d /dev/media0"
SENSOR_DEV=""

set_v4l2() { $M --set-v4l2 "$1"; }
link()     { $M -l "$1"; }

case "$WHICH" in
front)
	SENSOR_NAME="gc08a8 12-0031"; FMT="SRGGB10_1X10"; W=3264; H=2448
	PHY=msm_csiphy4; CSID=msm_csid0; VFE=msm_vfe0_rdi0; VIDEO=/dev/video0; PIX=pRAA
	;;
rear)
	SENSOR_NAME="s5kjns 11-0056"; FMT="SGRBG10_1X10"; W=4080; H=3072
	# 用独立 csid1/vfe1 通道，避免与前摄占用 csid0 冲突（Resource busy）
	PHY=msm_csiphy3; CSID=msm_csid1; VFE=msm_vfe1_rdi0; VIDEO=/dev/video3; PIX=pgAA
	;;
*) echo "usage: $0 {front|rear} [stream N]" >&2; exit 2 ;;
esac

F="${FMT}/${W}x${H}"

set_v4l2 "\"$SENSOR_NAME\":0[fmt:$F]"
set_v4l2 "\"$PHY\":0[fmt:$F]"
set_v4l2 "\"$PHY\":1[fmt:$F]"
set_v4l2 "\"$CSID\":0[fmt:$F]"
set_v4l2 "\"$CSID\":1[fmt:$F]"
set_v4l2 "\"$VFE\":0[fmt:$F]"
set_v4l2 "\"$VFE\":1[fmt:$F]"
link "\"$PHY\":1->\"$CSID\":0[1]"
link "\"$CSID\":1->\"$VFE\":0[1]"

v4l2-ctl -d "$VIDEO" --set-fmt-video=width=$W,height=$H,pixelformat=$PIX >/dev/null
echo "[camera-up] $WHICH configured: $SENSOR_NAME $FMT -> $PHY -> $CSID -> $VFE -> $VIDEO ($PIX ${W}x${H})"

if [ "$DO_STREAM" = stream ]; then
	echo "[camera-up] streaming $N frames from $VIDEO ..."
	timeout $((N + 10)) v4l2-ctl -d "$VIDEO" --stream-mmap --stream-count="$N"
	echo "[camera-up] stream rc=$?"
fi
