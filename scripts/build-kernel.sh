#!/bin/bash
# Rebuild the bring-up kernel image + DTB for the Lenovo TB322FC (elden).
set -e
ROOT=${ROOT:-$HOME/y700-elden}
cd "$ROOT/linux"
export PATH="$HOME/bin:$PATH"
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
make -j"$(nproc)" Image.gz dtbs
ls -la arch/arm64/boot/Image.gz arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
