#!/usr/bin/env bash
# c0-android-evidence.sh — C0「真 Android 对照取证」采集器
#
# 目的：在**覆盖 a 槽之前**，从仍为 stock+root 的单元（当前=U1 `HA2ABH62`）
# 采集兼容层的「标准答案」：身份属性 / DRM 级别 / 传感器清单 / 分区与包清单。
# 这些数据一旦 a 槽被覆盖即不可复得（GAPS Q5）。
#
# 依赖：adb（设备已连接并授权）。root 操作用设备侧 KSU（`su -c`，只发单条简单命令）。
# 输出：backup/<SN>-<容量档>/c0-baseline/（设备专属，git 不纳管）
#
# 用法:
#   scripts/c0-android-evidence.sh              # 自动探测设备
#   scripts/c0-android-evidence.sh HA2ABH62     # 指定 serial
#
# 不自动化的部分（需人工，见脚本末尾提示）：目标 App 关键流程录屏、传感器 30 s CSV。
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

SER=${1:-}
if [ -z "$SER" ]; then
  SER=$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')
fi
[ -n "$SER" ] || { echo "!! 未找到在线 adb 设备（U1 是否连接并授权？）" >&2; exit 1; }

ADB="adb -s $SER"
HB=$($ADB shell getprop ro.boot.hwboardid 2>/dev/null | tr -d '\r')
echo "设备 serial=$SER  hwboardid=${HB:-未知}"

# 容量档 → 目录名（与 backup/<SN>-<容量档> 规范一致）
# hwboardid 形如 SM8750P_16+512_13 / TB322FC_SM8750P_12+256，容量档 = 其中的 NNN+NNN 字段。
CAP=$(printf '%s' "$HB" | grep -oE '[0-9]+\+[0-9]+' | head -1)
[ -n "$CAP" ] || CAP=unknown
OUT="$ROOT/backup/${SER}-${CAP}/c0-baseline"
mkdir -p "$OUT"
echo "输出 → $OUT"

cap() { # cap <文件名> <shell 命令>
  local f=$1; shift
  echo "  · $f"
  $ADB shell "$@" > "$OUT/$f" 2>&1 || echo "    (命令非零退出，已记录)"
}

echo "== 1/6 身份属性 =="
cap getprop-all.txt getprop
cap getprop-dalvik.txt getprop -Z
{
  echo "# C0 identity key props — $SER  $(date -Is)"
  for p in ro.build.fingerprint ro.build.version.release ro.build.version.security_patch \
           ro.product.model ro.product.device ro.boot.hwboardid ro.boot.serialno \
           ro.boot.verifiedbootstate ro.boot.flash.locked ro.boot.vbmeta.device_state \
           sys.lenovo.widevine_security_level ro.vendor.build.fingerprint \
           ro.boot.product.hardware.sku ro.vendor.qti.va_aosp.support ro.hardware.keystore; do
    echo "$p = $($ADB shell getprop "$p" 2>/dev/null | tr -d '\r')"
  done
} > "$OUT/key-props.txt"

echo "== 2/6 DRM / Widevine =="
# Android 16 起服务名变化：media.drm/drm 可能不存在，回退 drm.drmManager + IDrmFactory dump。
cap dumpsys-media.drm.txt dumpsys media.drm
cap drm-info.txt dumpsys drm
$ADB shell dumpsys drm.drmManager > "$OUT/dumpsys-drmManager.txt" 2>&1 || true
$ADB shell dumpsys android.hardware.drm.IDrmFactory/widevine > "$OUT/dumpsys-drmFactory-widevine.txt" 2>&1 || true
$ADB shell getprop 2>/dev/null | tr -d '\r' | grep -iE 'widevine|drm|media\.drm' > "$OUT/widevine-props.txt" 2>&1
$ADB shell getprop 2>/dev/null | tr -d '\r' | grep -iE 'virt|gunyah|crosvm|avf|pvm' > "$OUT/virt-props.txt" 2>&1
$ADB shell getprop 2>/dev/null | tr -d '\r' | grep -iE 'keybox|attest|keymint|keystore|strongbox|csr' > "$OUT/keystore-props.txt" 2>&1

echo "== 3/6 传感器 =="
cap dumpsys-sensorservice.txt dumpsys sensorservice
$ADB shell dumpsys sensorservice 2>/dev/null | tr -d '\r' | grep -A200 -iE 'sensor list|active sensors' > "$OUT/sensor-list.txt" 2>&1

echo "== 4/6 分区 / 包 / 槽位 =="
$ADB shell 'ls -l /dev/block/by-name' > "$OUT/by-name.txt" 2>&1
$ADB shell 'cat /proc/partitions' > "$OUT/proc-partitions.txt" 2>&1
$ADB shell 'pm list packages' > "$OUT/packages.txt" 2>&1
$ADB shell 'getprop | grep -E "slot|boot" | head -40' > "$OUT/slot-props.txt" 2>&1

echo "== 5/6 AVF / virt（设备侧复核，与离线提取互相印证）=="
$ADB shell 'pm path com.android.virt' > "$OUT/virt-path.txt" 2>&1
$ADB shell 'ls -l /apex/com.android.virt* /system/apex/com.android.virt.apex 2>/dev/null' > "$OUT/virt-apex-ls.txt" 2>&1
# 设备侧 crosvm 是否带 gunyah（离线已证有；此处置于记录）
$ADB shell 'ls -l /apex/com.android.virt/bin 2>/dev/null' > "$OUT/virt-bin-ls.txt" 2>&1

echo "== 6/6 校验和 =="
( cd "$OUT" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + | sort -k2 > SHA256SUMS )
ls -la "$OUT"
echo
echo "完成。仍待人工补齐（不可自动化）："
echo "  ① 7 颗传感器 30 s 采样 CSV：在设备 Termux 里逐颗采集（见 TASKS/README.md §5 Q5 / C0）"
echo "  ② 5 个目标 App 关键流程录屏：adb -s $SER shell screenrecord /sdcard/c0-app-N.mp4"
echo "     录完 adb -s $SER pull /sdcard/c0-app-N.mp4 \"$OUT/\""
