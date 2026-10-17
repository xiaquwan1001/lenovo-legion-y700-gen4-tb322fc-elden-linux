#!/bin/bash
# m1-73-modules-overlay.sh — 为 M1-7.3（7.3-rc7 重基树）RAM 镜像注入启动关键 `=m` 模块。
#
# 背景（PITFALLS #248）：`fastboot boot` 的纯 ramdisk 镜像不含 .ko，磁盘 /lib/modules 又对不上
#   新内核 UTS ⇒ 所有 `=m` 驱动都不加载。本机实测必需两项：
#     fsa4480  —— typec mode-switch ⇒ 解开 pmic_glink.altmode → DP → dispcc → msm_drm_bind 阻塞
#     fastrpc  —— /dev/fastrpc-adsp ⇒ hexagonrpcd → ADSP 传感器
#
# 用法：scripts/m1-73-modules-overlay.sh [out_overlay_cpio.gz]
#   在 M1 树（build/m1-upstream/clean-tree-73）已编好的前提下，产出叠加用 cpio.gz；
#   再 `cat <base.ramdisk> overlay.cpio.gz > 73x.ramdisk` + scripts/mkbootimg.py 打包
#   （打包后务必回读核验 cmdline，见 PITFALLS #249）。
set -euo pipefail
cd "$(dirname "$0")/.."
M1=${M1_TREE:-build/m1-upstream/clean-tree-73}
KV=$(make -s -C "$M1" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- kernelrelease)
OUT=${1:-/tmp/m1-73-overlay.cpio.gz}
OVL=$(mktemp -d)
trap 'rm -rf "$OVL"' EXIT
mkdir -p "$OVL/lib/modules/$KV/kernel/drivers/usb/typec/mux" \
         "$OVL/lib/modules/$KV/kernel/drivers/misc" \
         "$OVL/usr/local/sbin"
cp "$M1/drivers/usb/typec/mux/fsa4480.ko" "$OVL/lib/modules/$KV/kernel/drivers/usb/typec/mux/"
cp "$M1/drivers/misc/fastrpc.ko"          "$OVL/lib/modules/$KV/kernel/drivers/misc/"
aarch64-linux-gnu-strip --strip-debug "$OVL/lib/modules/$KV/kernel/drivers/usb/typec/mux/fsa4480.ko"
aarch64-linux-gnu-strip --strip-debug "$OVL/lib/modules/$KV/kernel/drivers/misc/fastrpc.ko"
cat > "$OVL/usr/local/sbin/m1-73-modules-load.sh" <<'EOF'
#!/bin/sh
set -u
KV=$(uname -r)
D=/lib/modules/$KV/kernel
for m in fsa4480 fastrpc; do
  p=$(find "$D" -name "$m.ko" 2>/dev/null | head -1)
  if [ -z "$p" ]; then echo "[m1-73] no $m.ko"; continue; fi
  if lsmod 2>/dev/null | grep -q "^$(echo $m | tr - _) "; then continue; fi
  if insmod "$p" 2>/dev/null; then echo "[m1-73] loaded $m"; else echo "[m1-73] WARN insmod $m failed" >&2; fi
done
EOF
chmod 755 "$OVL/usr/local/sbin/m1-73-modules-load.sh"
# 叠加一个 /init 覆盖层：在 cgroup2 挂载前调用加载钩子。
# 基础 /init 取自当前镜像（脚本调用者可换），此处从 rootfs SSOT 复制。
cp rootfs/persistent-overlay/init "$OVL/init" 2>/dev/null || true
chmod 755 "$OVL/init" 2>/dev/null || true
python3 - "$OVL/init" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
anchor='# cgroup2 single hierarchy'
call='\n# --- M1-73: load =m modules baked into this ramdisk (DP mode-switch + fastrpc sensors) ---\nif [ -x /usr/local/sbin/m1-73-modules-load.sh ]; then\n\t/usr/local/sbin/m1-73-modules-load.sh >"$KLOG" 2>&1 || warn "m1-73 module load failed"\nfi\n\n'
assert anchor in s, 'anchor missing in '+p
open(p,'w').write(s.replace(anchor, call+anchor, 1))
PY
( cd "$OVL" && find . | cpio -o -H newc --owner 0:0 2>/dev/null | gzip -9 > "$OUT" )
echo "[m1-73] overlay -> $OUT"
