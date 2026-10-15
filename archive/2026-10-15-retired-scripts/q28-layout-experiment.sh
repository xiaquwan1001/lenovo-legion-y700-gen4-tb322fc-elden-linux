#!/bin/bash
# 一次性溯源实验：同 config/同源/同工具链/同 KBUILD_BUILD_TIMESTAMP+VERSION，
# 只差 LOCALVERSION 字符串长度（q28a vs q28aa），验证「二进制差异是否仅=版本串长度」。
set -uo pipefail
cd /home/xuqianhui1001/y700-elden
. scripts/env-build.sh
OUT=out/q28-layout
mkdir -p "$OUT"
TS="Sat Oct 10 12:00:00 CST 2026"
for LV in q28a q28aa; do
  echo "==== build LOCALVERSION=-$LV  start $(date -Is)"
  timeout -k 60 3000 make -C linux -j16 \
      LOCALVERSION="-$LV" KBUILD_BUILD_VERSION=7 KBUILD_BUILD_TIMESTAMP="$TS" \
      Image >"$OUT/build-$LV.log" 2>&1
  rc=$?
  echo "==== build $LV rc=$rc end $(date -Is)"
  if [ $rc -ne 0 ]; then echo "BUILD FAILED $LV"; tail -20 "$OUT/build-$LV.log"; break; fi
  cp linux/arch/arm64/boot/Image "$OUT/Image-$LV"
  cp linux/System.map "$OUT/System.map-$LV"
  strings -a "$OUT/Image-$LV" | grep -m1 '^Linux version'
  sha256sum "$OUT/Image-$LV"
done
echo "ALL DONE $(date -Is)"
