#!/bin/sh
# device-side: (re)start a YUY2 test pattern producer on /dev/video100
pkill -f 'videotest[s]rc' 2>/dev/null
sleep 1
setsid gst-launch-1.0 -q videotestsrc is-live=true \
  ! video/x-raw,format=YUY2,width=1280,height=720,framerate=10/1 \
  ! v4l2sink device=/dev/video100 >/tmp/camtest.log 2>&1 &
sleep 6
echo "-- producer pids:"
pgrep -f 'videotest[s]rc' | head -3
echo "-- fmt:"
v4l2-ctl -d /dev/video100 --get-fmt-video 2>&1 | grep -E 'Width/Height|Pixel'
echo "-- log:"
tail -3 /tmp/camtest.log 2>/dev/null
