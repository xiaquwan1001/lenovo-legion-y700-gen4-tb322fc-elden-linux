#!/bin/bash
# One-command iteration: build -> pack -> soft-reboot to fastboot -> boot new image -> wait SSH.
# usage: iterate.sh [rootfs.cpio.gz]
set -eu
cd "$(dirname "$0")"
ROOTFS=${1:-out/rootfs-vk7.cpio.gz}
OUT=out/boot-elden-latest.img
./build.sh
./pack.sh "$ROOTFS" "$OUT"
./cycle.sh --soft          # device currently in Linux -> fastboot (no physical button)
./cycle.sh "$OUT"          # fastboot -> new Linux
echo "[iterate] done; ssh root@192.168.7.1"
