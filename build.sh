#!/bin/bash
# Incremental kernel build (elden). Never run olddefconfig — it deletes CONFIG_ARCH_QCOM.
set -eu
cd "$(dirname "$0")"
cd linux
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
grep -q '^CONFIG_ARCH_QCOM=y' .config || { echo "ERROR: CONFIG_ARCH_QCOM missing (.config corrupted by olddefconfig?)"; exit 1; }
make -j"$(nproc)" Image.gz dtbs
echo "[build] OK: $(ls -la arch/arm64/boot/Image.gz | awk '{print $5}') bytes"
