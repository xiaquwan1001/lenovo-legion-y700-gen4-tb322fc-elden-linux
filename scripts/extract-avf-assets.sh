#!/usr/bin/env bash
# extract-avf-assets.sh — 从原厂 system 镜像离线提取 AVF（Android Virtualization
# Framework）资产：crosvm / vm / microdroid_kernel / u-boot.bin 等。
#
# 为什么不需要设备：GAPS Q13 担心的「资产已丢」可用宿主侧的
# /mnt/Samsung/l2/system_a.pristine.img（本机原厂 259 system 镜像）离线复原，
# 内含 /system/apex/com.android.virt.apex（87.8 MB，与 U1 a 槽同 build）。
#
# 依赖：debugfs（e2fsprogs）、unzip。全程只读源镜像，不写 /mnt。
#
# 用法:
#   scripts/extract-avf-assets.sh                  # 默认源镜像 + 默认输出 backup/avf
#   IMG=/path/system.img OUT=/path/avf scripts/extract-avf-assets.sh
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

IMG=${IMG:-/mnt/Samsung/l2/system_a.pristine.img}
OUT=${OUT:-$ROOT/backup/avf}
APEX_SRC=/system/apex/com.android.virt.apex

[ -r "$IMG" ] || { echo "!! 源镜像不可读: $IMG" >&2; exit 1; }
command -v debugfs >/dev/null || { echo "!! 缺 debugfs (e2fsprogs)" >&2; exit 1; }
command -v unzip   >/dev/null || { echo "!! 缺 unzip" >&2; exit 1; }

mkdir -p "$OUT"
APEX="$OUT/com.android.virt.apex"
PAYLOAD="$OUT/apex_payload.img"
BIN="$OUT/bin"      # 宿主 x86 可执行模型？否：apex 内是 **guest 侧 ARM64** 二进制
FS="$OUT/etc-fs"

echo "== 1/4 dump apex from $IMG =="
debugfs -R "dump $APEX_SRC $APEX" "$IMG" 2>&1 | tail -1
[ -s "$APEX" ] || { echo "!! apex dump 失败" >&2; exit 1; }

echo "== 2/4 解 apex（zip）取 apex_payload.img =="
unzip -o -q -j "$APEX" apex_payload.img -d "$OUT"
[ -s "$PAYLOAD" ] || { echo "!! apex_payload.img 提取失败" >&2; exit 1; }

echo "== 3/4 dump 关键二进制（bin/*）=="
mkdir -p "$BIN" "$FS"
for f in crosvm vm virtmgr early_virtmgr virtualizationservice vmnic vfio_handler fd_server; do
  debugfs -R "dump /bin/$f $BIN/$f" "$PAYLOAD" 2>&1 | tail -1
done

echo "== 4/4 dump guest 内核 / initrd / bootloader / 磁盘模板 =="
debugfs -R "dump /etc/fs/microdroid_kernel $FS/microdroid_kernel" "$PAYLOAD" 2>&1 | tail -1
debugfs -R "dump /etc/fs/microdroid_super.img $FS/microdroid_super.img" "$PAYLOAD" 2>&1 | tail -1
debugfs -R "dump /etc/fs/microdroid_vbmeta.img $FS/microdroid_vbmeta.img" "$PAYLOAD" 2>&1 | tail -1
for f in u-boot.bin rialto.bin microdroid_initrd_normal.img microdroid_initrd_debuggable.img microdroid.json; do
  debugfs -R "dump /etc/$f $FS/$f" "$PAYLOAD" 2>&1 | tail -1
done

echo "== 校验 =="
( cd "$OUT" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + | sort -k2 > SHA256SUMS )
ls -la "$OUT" "$BIN" "$FS"
echo
echo "完成 → $OUT  (SHA256SUMS 已生成)"
