#!/bin/bash
# cam-loopback.sh — 把 mainline 相机（libcamera 软 ISP）转发到一个 v4l2loopback 节点。
#
# 用途（C5 主机侧）：容器/任意消费者需要一个普通 V4L2 capture 设备；主机管线上
#   libcamerasrc → videoconvert/videoscale → NV12 → v4l2sink → /dev/video100
#
# ★格式必须是 **NV12**（2026-10-27 实测）：
#   Android 的 external camera HAL 只把 NV12 映射成 YCbCr_420_888（预览可用）；
#   YUYV 走的是"YUV 兜底"分支，cameraserver 的 legacy 参数层会
#   `Camera2-Parameters: generated preview size list is empty` ⇒ 相机打不开。
#
# ★`max_buffers=8` 也是必须的（同 PITFALLS #440）：HAL 要 4 个 buffer，而写端
#   gst v4l2sink 只申请 3 个，v4l2loopback 会把后来的请求压到 3 ⇒
#   `VIDIOC_REQBUFS expected 4 buffers, got 3 instead` ⇒ configureStreams 失败。
#   还需要内核侧补丁 `patches/extmod/0001-v4l2loopback-allow-grow-reqbufs.patch`。
# 前置：设备侧 /lib/modules/$(uname -r)/extra/v4l2loopback.ko（本脚本会尝试 insmod）。
#
# 已知限制（2026-10-17 实测）：
#   - 软 ISP 吞吐很低：原生 4096×3072 ≈ 1.1 fps、1280×720 ≈ 2.0 fps（不是 30 fps；
#     30 fps 是只看前两帧的假象）。
#   - 后摄 s5kjns 的 libcamera AE 不工作（缺 sensor helper）⇒ 必须手动设
#     exposure/analogue_gain，否则画面全黑；本脚本在 rear 模式下会先设好。
#
# ★★★ 与 Linux 相机**互斥**（2026-10-19 实测）：本脚本用 libcamerasrc 独占 CSI/CSID 链路，
#   在位时任何另一个相机客户端（`cam`、GNOME Snapshot、浏览器…）都会失败并报
#   `couldn't play camera stream` / `Failed to setup link 'msm_csiphy4'[1] -> 'msm_csid0'[0]: Resource busy`
#   ⇒ **用容器相机/loopback 前先确认没人在用 Linux 相机；用完立刻 `stop`**。
#   `start` 现在会先检测是否已有相机客户端在用，有则拒绝启动（FORCE=1 可强制）。
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
	# 互斥检查：已有别的相机客户端占用链路时拒绝启动（否则对方会报 "couldn't play camera stream"）
	if [ "${FORCE:-0}" != 1 ]; then
		# ⚠ 2026-10-23：旧判据 `snapshot` 会命中内核线程 `[disp_snapshot]`（display 快照，
		# 与相机无关）⇒ 永远误报「已有相机客户端在跑」。改为只匹配**用户态**客户端：
		# argv[0] 必须以 / 开头（内核线程显示为 [name]），且排除 pgrep/本脚本自身。
		busy=$(S "ps -eo pid,args | grep -E '(^|[ /])(cam|captureScript|gnome-snapshot|snapshot)( |\$)' | grep -vE 'pgrep|grep|cam-loopback|\\[.*\\]' | wc -l") || busy=0
		if [ "${busy:-0}" -gt 0 ]; then
			echo "REFUSE: 已有相机客户端在跑（$busy 个）——loopback 会独占 CSI 链路并让它们报 \"couldn't play camera stream\"。"
			echo "        确认要抢就 FORCE=1 重跑；或用完先关掉对方。"
			exit 3
		fi
	fi
	if [ "$WHICH" = rear ]; then CAM=$CAM_REAR; else CAM=$CAM_FRONT; fi
	SRUN <<EOF
set -u
lsmod | grep -q v4l2loopback || modprobe v4l2loopback exclusive_caps=1 video_nr=100 max_buffers=8 2>/dev/null || insmod /lib/modules/\$(uname -r)/extra/v4l2loopback.ko exclusive_caps=1 video_nr=100 max_buffers=8
[ -e $LOOP ] || { echo "FAIL: $LOOP 不存在（v4l2loopback 未加载）"; exit 1; }
$( [ "$WHICH" = rear ] && echo 'v4l2-ctl -d /dev/v4l-subdev28 --set-ctrl exposure=3000,analogue_gain=32 >/dev/null 2>&1' )
pkill -f 'gst-launch-1.0 -q libcamerasrc' 2>/dev/null; sleep 1
GST_DEBUG=0 nohup gst-launch-1.0 -q libcamerasrc camera-name="$CAM" ! videoconvert ! videoscale ! video/x-raw,format=${LOOPFMT:-NV12},width=$W,height=$H,framerate=$FPS/1 ! v4l2sink device=$LOOP >/tmp/cam-loopback.log 2>&1 &
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
w,h=1280,720
# NV12 = Y 平面(w*h) + 交织 UV(w*h/2)；YUYV = 每像素 2 字节交织
yuyv = (len(d) % (w*h*3//2) != 0) and (len(d) % (w*h*2) == 0)
fsz = w*h*2 if yuyv else w*h*3//2
n=len(d)//fsz
print('frames',n,'fmt','YUYV' if yuyv else 'NV12')
for fi in ([0,n-1] if n else []):
    fr=d[fi*fsz:(fi+1)*fsz]
    y=fr[0::2] if yuyv else fr[0:w*h]
    print(' frame',fi,'Y mean',round(sum(y)/len(y),1),'min',min(y),'max',max(y))
PY
EOF
	;;
*) echo "usage: $0 {start [front|rear] [WxH] [fps]|stop|status|test [N]}"; exit 2 ;;
esac
