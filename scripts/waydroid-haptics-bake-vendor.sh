#!/bin/bash
# waydroid-haptics-bake-vendor.sh — 马达透传**固化**进容器 vendor 镜像（TASKS C10 三期）
#
# 背景（PITFALLS #244）：容器 vendor.img 是「按内容自动裁」的紧凑 ext4，**100% 满**；
# 原位往里塞文件会 ENOSPC，且 `install` 会把目标先截断成 0 字节（本轮把镜像里那份 HIDL
# HAL 弄成 0 字节过）⇒ 正确做法 = 改产品配置后**重建镜像**。
#
# 固化内容（全部落在 vendor 分区，运行期零 bind 挂载）：
#   ① 自编 AIDL V2 vibrator HAL  android.hardware.vibrator-service.elden -> /vendor/bin/hw/
#      + 自带 rc /vendor/etc/init/vibrator-elden.rc
#      + 自带 vintf fragment /vendor/etc/vintf/manifest/android.hardware.vibrator.elden.xml
#   ② 静态 RRO EldenVibrationOverlay.apk -> /vendor/overlay/（PITFALLS #245：Settings 强度档位）
#   ③ 产品配置里删掉镜像原 HIDL vibrator HAL（device.mk + manifest.xml，PITFALLS #246）
#
# 用法（主机）：
#   bash scripts/waydroid-haptics-bake-vendor.sh            # 打配置补丁(幂等) + 建镜像 + 推设备 + 验证
#   bash scripts/waydroid-haptics-bake-vendor.sh --build-only
#   bash scripts/waydroid-haptics-bake-vendor.sh --verify
set -eu
cd "$(dirname "$0")/.."

TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $TAB"
WB=${WB:-/mnt/Samsung/waydroid-build}
PROD=$WB/out/target/product/waydroid_arm64_only
IMG=$PROD/vendor.img
BUILD_ONLY=0
VERIFY_ONLY=0
for a in "$@"; do
  case "$a" in
    --build-only) BUILD_ONLY=1 ;;
    --verify)     VERIFY_ONLY=1 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

if [ "$VERIFY_ONLY" = 0 ]; then
  echo "[bake] 1/4 同步源码 + 打产品配置补丁（幂等）"
  python3 "$OLDPWD/scripts/waydroid-haptics-bake-patch.py" 2>/dev/null || python3 scripts/waydroid-haptics-bake-patch.py

  echo "[bake] 2/4 m vendorimage"
  ( cd "$WB"
    export CCACHE_DIR=/mnt/Samsung/ccache USE_CCACHE=1
    source build/envsetup.sh >/dev/null 2>&1
    lunch lineage_waydroid_arm64_only-userdebug >/dev/null 2>&1
    m vendorimage 2>&1 | tail -5 )
  ls -l --time-style=+%H:%M "$IMG"
  [ "$BUILD_ONLY" = 1 ] && { echo "[bake] --build-only 结束"; exit 0; }

  echo "[bake] 3/4 停容器 → 原子替换 vendor.img → 摘掉 aidl bind 块"
  $SSH 'for p in $(pgrep -f "usr/bin/waydroi[d]"); do kill -9 "$p"; done; sleep 2;
        lxc-stop -P /var/lib/waydroid/lxc -n waydroid -k 2>/dev/null || true; sleep 1; echo "  stopped"'
  $SSH 'IMG=/var/lib/waydroid/images/vendor.img; [ -f "$IMG.bak-elden-haptics-20261013-115055" ] || cp "$IMG" "$IMG.bak-elden-haptics-$(date +%Y%m%d-%H%M%S)"' || true
  scp -q "$IMG" "$TAB:/var/lib/waydroid/images/vendor.img.new"
  $SSH 'mv /var/lib/waydroid/images/vendor.img.new /var/lib/waydroid/images/vendor.img; ls -l /var/lib/waydroid/images/'
  $SSH 'python3 - <<PY
p="/var/lib/waydroid/lxc/waydroid/config"
lines=open(p,encoding="utf-8").read().split(chr(10))
out=[];skip=False
for l in lines:
    if l.startswith("# >>> elden-haptics aidl"): skip=True; continue
    if l.startswith("# <<< elden-haptics aidl"): skip=False; continue
    if skip: continue
    out.append(l)
open(p,"w",encoding="utf-8").write(chr(10).join(out))
PY
        grep -n "mount.entry.*elden" /var/lib/waydroid/lxc/waydroid/config'

  echo "[bake] 4/4 起容器"
  $SSH 'for p in $(pgrep -f "usr/bin/waydroi[d]"); do kill -9 "$p"; done; sleep 1;
        setsid nohup waydroid container start >/tmp/wd-c.log 2>&1 </dev/null & sleep 12; /usr/local/sbin/wd-ctl.sh session >/dev/null; sleep 28; /usr/local/sbin/wd-ctl.sh state | head -2'
fi

echo "[bake] 验证"
$SSH 'sh -s' <<'EOS'
L=/var/log/elden-hapticd.log
echo "-- 容器健康:"; timeout 15 waydroid shell -- getprop sys.boot_completed 2>/dev/null; ps -eo comm | grep -cE "phoc|phosh"
echo "-- HAL 来源（exe 路径应指向 /vendor/bin/hw/...，且没有 vibrator bind 挂载）:"
timeout 20 waydroid shell -- sh -c 'ls -l /proc/$(pidof android.hardware.vibrator-service.elden | cut -d" " -f1)/exe | tail -1; cat /proc/mounts | grep -c vibrator' 2>&1 | tail -2
echo "-- caps/effects:"; timeout 25 waydroid shell -- dumpsys vibrator_manager 2>/dev/null | grep -oE "mCapabilities=\[[^]]*\]|mSupportedEffects=\[[^]]*\]" | head -2
echo "-- 静态 RRO + 强度档位（应为 3）:"; timeout 20 waydroid shell -- cmd overlay list 2>/dev/null | grep -i elden
timeout 20 waydroid shell -- cmd overlay lookup com.android.settings com.android.settings:integer/config_vibration_supported_intensity_levels 2>&1 | tail -1
echo "-- 幅度 oneshot -a 300 160:"; base=$(wc -l < $L)
timeout 20 waydroid shell -- cmd vibrator_manager synced oneshot -a 300 160 >/dev/null 2>&1; sleep 1; awk -v b=$base 'NR>b' $L
echo "-- cancel（-B 8s，1.2s 取消）:"; base=$(wc -l < $L)
( timeout 25 waydroid shell -- cmd vibrator_manager synced -B oneshot 8000 >/dev/null 2>&1 & ); sleep 1.2
stamp=$(date +%T); timeout 20 waydroid shell -- cmd vibrator_manager cancel >/dev/null 2>&1
sleep 1.5; awk -v b=$base 'NR>b' $L; echo "   cancel 发于 $stamp"
echo "-- 残留运行时挂载（应只剩 sysfs 桥）:"; grep -n "mount.entry.*elden" /var/lib/waydroid/lxc/waydroid/config
EOS
