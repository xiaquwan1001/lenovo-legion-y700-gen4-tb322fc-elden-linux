#!/bin/sh
# combined read-only logger: D-Bus orientation/tilt + continuous ssccli accel XYZ
DUR=${1:-300}
O=/tmp/rotlog.txt
A=/tmp/rotlog-accel.txt
: > "$O"; : > "$A"
END=$(( $(date +%s) + DUR ))
echo "LOGSTART $(date -u +%T) dur=$DUR" | tee -a "$O"
( ssccli --sensor accelerometer --timeout "$DUR" 2>/dev/null | while IFS= read -r L; do echo "$(date -u +%T) $L"; done > "$A" ) &
AP=$!
while [ "$(date +%s)" -lt "$END" ]; do
  OR=$(busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy AccelerometerOrientation 2>/dev/null | tr -d '"')
  TI=$(busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy AccelerometerTilt 2>/dev/null | tr -d '"')
  echo "$(date -u +%T) orient=$OR tilt=$TI" >> "$O"
  sleep 1.5
done
echo "LOGEND $(date -u +%T)" | tee -a "$O"
