#!/bin/bash
# cam-loopback.sh — 把 mainline 相机（libcamera 软 ISP）转发到一个 v4l2loopback 节点。
#
# 用途（C5 主机侧）：容器/任意消费者需要一个普通 V4L2 capture 设备；主机管线上
#   libcamerasrc → videoconvert/videoscale → YUY2 → v4l2sink → /dev/video100
# 前置：设备侧 /lib/modules/$(uname -r)/extra/v4l2loopback.ko（本脚本会尝试 insmod）。
#
# 已知限制（2026-10-17 实测）：
#   - 软 ISP 吞吐很低：原生 4096×3072 ≈ 1.1 fps、1280×720 ≈ 2.0 fps（不是 30 fps；
#     30 fps 是只看前两帧的假象）。
#   - 后摄 s5kjns 的 libcamera AE 不工作（缺 sensor helper）⇒ 必须手动设
#     exposure/analogue_gain，否则画面全黑；本脚本在 rear 模式下会先设好。
#
# 用法：
#   scripts/cam-loopback.sh start [front|rear] [WxH] [fps]   # 默认 front 1280x720 30
#   scripts/cam-loopback.sh stop
#   scripts/cam-loopback.sh status
#   scripts/cam-loopback.sh test [N]      # 从 /dev/video100 读 N 帧并报 Y 统计
set -u
DEV=${DEV:-root@192.168.7.1}
LOOP=/dev/video100
CAM_FRONT="/base/soc@0/cci@ac7c000/i2c-bus@0/camera@31"
CAM_REAR="/base/soc@0/cci@ac7b000/i2c-bus@0/camera@56"
S() { timeout 30 ssh -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=no "$DEV" "$@" 2>/dev/null; }
SRUN() { timeout 60 ssh -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=no "$DEV" 'bash -s' 2>&1; }

case "${1:-status}" in
start)
	WHICH=${2:-front}; SIZE=${3:-1280x720}; FPS=${4:-30}
	W=${SIZE%x*}; H=${SIZE#*x}
	if [ "$WHICH" = rear ]; then CAM=$CAM_REAR; else CAM=$CAM_FRONT; fi
	SRUN <<EOF
set -u
lsmod | grep -q v4l2loopback || modprobe v4l2loopback exclusive_caps=1 video_nr=100 2>/dev/null || insmod /lib/modules/\$(uname -r)/extra/v4l2loopback.ko exclusive_caps=1 video_nr=100
[ -e $LOOP ] || { echo "FAIL: $LOOP 不存在（v4l2loopback 未加载）"; exit 1; }
$( [ "$WHICH" = rear ] && echo 'v4l2-ctl -d /dev/v4l-subdev28 --set-ctrl exposure=3100,analogue_gain=1500 >/dev/null 2>&1' )
pkill -f 'gst-launch-1.0 -q libcamerasrc' 2>/dev/null; sleep 1
GST_DEBUG=0 nohup gst-launch-1.0 -q libcamerasrc camera-name="$CAM" ! videoconvert ! videoscale ! video/x-raw,format=YUY2,width=$W,height=$H,framerate=$FPS/1 ! v4l2sink device=$LOOP >/tmp/cam-loopback.log 2>&1 &
sleep 6
echo "-- producer log:"; tail -3 /tmp/cam-loopback.log
echo "-- loop fmt:"; v4l2-ctl -d $LOOP --get-fmt-video 2>/dev/null | grep -E 'Width|Pixel'
EOF
	;;
stop)
	S "pkill -f 'gst-launch-1.0 -q libcamerasrc' 2>/dev/null; echo stopped"
	;;
status)
	S 'echo "modules: $(lsmod | grep -c v4l2loopback)"; echo "node: $(ls '$LOOP' 2>/dev/null || echo missing)"; pgrep -af "gst-launch-1.0 -q libcamerasrc" | head -2'
	;;
test)
	N=${2:-20}
	SRUN <<EOF
set -u
timeout 40 v4l2-ctl -d $LOOP --stream-mmap --stream-count=$N --stream-to=/tmp/lbtest.yuv >/dev/null 2>&1
python3 - <<'PY'
d=open('/tmp/lbtest.yuv','rb').read()
w,h=1280,720; fsz=w*h*2; n=len(d)//fsz
print('frames',n)
for fi in ([0,n-1] if n else []):
    fr=d[fi*fsz:(fi+1)*fsz]; y=fr[0::2]
    print(' frame',fi,'Y mean',round(sum(y)/len(y),1),'min',min(y),'max',max(y))
PY
EOF
	;;
*) echo "usage: $0 {start [front|rear] [WxH] [fps]|stop|status|test [N]}"; exit 2 ;;
esac
