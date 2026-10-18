#!/bin/sh
# 设备侧：自编 libcamera 0.7.1（simple pipeline + soft ISP）并安装。
# 关键：必须让 meson 找不到 libcrypto，否则 IPA 走进程内签名路径 → 软 ISP 输出全黑（PITFALLS #322）。
set -eu
SRC=${SRC:-/root/libcamera-0.7.1}
[ -d "$SRC" ] || { echo "missing $SRC (解包 v0.7.1 源码)"; exit 1; }
[ "$(id -u)" = 0 ] || { echo "need root"; exit 1; }

echo "[1/4] 备份 Alpine 原版（只备份一次）"
mkdir -p /root/lc-bak-$(date +%Y%m%d)
for f in /usr/lib/libcamera.so.0.7.1 /usr/lib/libcamera-base.so.0.7.1; do
  b=/root/lc-bak-$(date +%Y%m%d)/$(basename $f)
  [ -f "$b" ] || cp -a "$f" "$b"
done

echo "[2/4] 去掉 openssl-dev（让 meson 拿不到 libcrypto ⇒ IPA 隔离）"
apk del openssl-dev 2>/dev/null || true

echo "[3/4] 构建"
cd "$SRC" && rm -rf build
meson setup build -Dpipelines=simple -Dipas=simple -Dcam=enabled \
  -Dgstreamer=disabled -Dpycamera=disabled -Dtest=false -Ddocumentation=disabled -Dprefix=/usr
ninja -C build -j4

echo "[4/4] 安装 + 验收"
ninja -C build install && ldconfig
echo "--- 验收（逐帧 mean 不应全 0）---"
rm -rf /tmp/lcv && mkdir -p /tmp/lcv
timeout 60 cam -c1 -C12 --file='/tmp/lcv/f_#.bin' >/dev/null 2>&1 || true
python3 - <<'PY'
import glob, os
fs = sorted(glob.glob('/tmp/lcv/f_*.bin'))
if not fs:
    print("  no frames"); raise SystemExit
means = []
for p in fs:
    d = open(p, 'rb').read(8192)
    v = d[::4]
    means.append(round(sum(v) / len(v), 1))
print("  size", os.path.getsize(fs[0]), "frames", len(fs))
print("  means", means)
print("  -> " + ("OK（有画面）" if any(m > 1 for m in means[1:]) else "FAIL（全黑，检查是否又启用了 libcrypto）"))
PY
