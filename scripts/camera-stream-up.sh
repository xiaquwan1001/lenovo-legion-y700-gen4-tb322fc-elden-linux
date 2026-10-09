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
# 用法（设备上，scp 上去后；⚠️ 未部署到 /usr/local/sbin，属主机 repo 的采集/验证助手）：
#   sh camera-stream-up.sh front            # gc08a8 -> csiphy4 -> csid0 -> vfe0_rdi0 -> /dev/video0
#   sh camera-stream-up.sh rear             # s5kjns -> csiphy3 -> csid1 -> vfe1_rdi0 -> /dev/video3
#   sh camera-stream-up.sh front stream 5   # 配置并抓 5 帧（注意顺序：是 `<哪个> stream [N]`）
#
# 2026-10-09 23:14 实机验证：双摄各出真实帧（前 distinct=255/stddev=36.8，后 243/34.7，见 G1-5）。
set -eu
WHICH=${1:-front}
DO_STREAM=${2:-}
N=${3:-3}

M="media-ctl -d /dev/media0"
SENSOR_DEV=""

set_v4l2() { $M --set-v4l2 "$1"; }
link()     { $M -l "$1"; }

# entity 名里的 I2C **总线号会随 probe 顺序漂**：2026-10-09 深夜实测，脚本里硬编码的
# front=12-0031 / rear=11-0056，而本次开机实际是 front=13-0031 / rear=12-0056，
# 整套 set-v4l2 被拒，只给一句没有信息量的 `Unable to setup formats: Invalid argument (22)`。
# ⇒ 按“驱动名 + 芯片地址”（这俩由 DT 决定，稳定）**运行时解析** entity 名，不写总线号。
GRAPH=$(mktemp); trap 'rm -f "$GRAPH"' EXIT INT TERM
$M -p > "$GRAPH" 2>/dev/null
resolve_sensor(){
	sed -n "s/.*entity [0-9]*: \($1 [0-9]*-$2\).*/\1/p" "$GRAPH" | head -1
}

case "$WHICH" in
front)
	SENSOR_DRV=gc08a8; SENSOR_ADDR=0031; FMT="SRGGB10_1X10"; W=3264; H=2448
	PHY=msm_csiphy4; CSID=msm_csid0; VFE=msm_vfe0_rdi0; VIDEO=/dev/video0; PIX=pRAA
	;;
rear)
	SENSOR_DRV=s5kjns; SENSOR_ADDR=0056; FMT="SGRBG10_1X10"; W=4080; H=3072
	# 用独立 csid1/vfe1 通道，避免与前摄占用 csid0 冲突（Resource busy）
	PHY=msm_csiphy3; CSID=msm_csid1; VFE=msm_vfe1_rdi0; VIDEO=/dev/video3; PIX=pgAA
	;;
*) echo "usage: $0 {front|rear} [stream N]" >&2; exit 2 ;;
esac

F="${FMT}/${W}x${H}"

SENSOR_NAME=$(resolve_sensor "$SENSOR_DRV" "$SENSOR_ADDR")
if [ -z "$SENSOR_NAME" ]; then
	echo "[camera-up] FAIL: 媒体图里找不到 $SENSOR_DRV @ $SENSOR_ADDR（相机模块没加载？先跑 camera-modules-load.sh）" >&2
	exit 3
fi
for e in "$PHY" "$CSID" "$VFE"; do
	grep -q "entity [0-9]*: $e " "$GRAPH" || { echo "[camera-up] FAIL: 图里没有 entity $e" >&2; exit 3; }
done
echo "[camera-up] $WHICH: sensor entity = \"$SENSOR_NAME\""

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
