#!/bin/bash
# Build the Waydroid container-audio test dexes (TestAudio / TestCodec / ListCodecs).
# Needs: javac (host), and the AOSP build tree for android.jar + d8.jar.
#
#   tools/wd-audio-test/build.sh [build-tree]
#
# Default build tree: /mnt/Samsung/waydroid-build
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TREE=${1:-/mnt/Samsung/waydroid-build}
AJ="$TREE/prebuilts/sdk/current/system/android.jar"
D8="$TREE/prebuilts/sdk/tools/lib/d8.jar"
[ -f "$AJ" ] || { echo "no android.jar: $AJ" >&2; exit 1; }
[ -f "$D8" ] || { echo "no d8.jar: $D8" >&2; exit 1; }

OUT=${OUT:-/tmp/wd-audio-test}
mkdir -p "$OUT"
cd "$HERE"
for M in TestAudio TestCodec TestRecord ListCodecs; do
    javac -source 8 -target 8 -bootclasspath "$AJ" -classpath "$AJ" -d "$OUT" "$M.java"
    mkdir -p "$OUT/$M"
    rm -f "$OUT/$M/classes.dex"
    java -cp "$D8" com.android.tools.r8.D8 --min-sdk-version 30 --output "$OUT/$M" "$OUT/$M.class" >/dev/null
    (cd "$OUT/$M" && jar cf "$OUT/$M.jar" classes.dex)
    echo "built $OUT/$M.jar"
done

cat <<EOF

Push & run inside the Android container (device host, root):
  scp $OUT/*.jar root@192.168.7.1:/tmp/
  ssh root@192.168.7.1 'cp /tmp/*.jar /home/xuqianhui1001/.local/share/waydroid/data/local/tmp/'
  ssh root@192.168.7.1 'waydroid shell -- sh -c "CLASSPATH=/data/local/tmp/ListCodecs.jar app_process /data/local/tmp ListCodecs"'
EOF
