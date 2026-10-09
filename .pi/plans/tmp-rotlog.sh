#!/bin/sh
# read-only logger: sample D-Bus orientation + tilt for ~150s
DUR=${1:-150}
OUT=/tmp/rotlog.txt
: > "$OUT"
END=$(( $(date +%s) + DUR ))
echo "LOGSTART $(date -u +%T)" >> "$OUT"
while [ "$(date +%s)" -lt "$END" ]; do
  O=$(busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy AccelerometerOrientation 2>/dev/null | tr -d '"')
  T=$(busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy AccelerometerTilt 2>/dev/null | tr -d '"')
  echo "$(date -u +%T) orient=$O tilt=$T" >> "$OUT"
  sleep 1.5
done
echo "LOGEND $(date -u +%T)" >> "$OUT"
