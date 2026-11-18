#!/usr/bin/env bash
# 解锁前（locked 状态）零风险取证 + 解锁申请表所需参数打印。
# 设备无关：SN/容量/路径全部运行时读实际设备。用法：
#   scripts/bl-preunlock-evidence.sh            # 自动选唯一 adb 设备
#   scripts/bl-preunlock-evidence.sh <SERIAL>   # 指定设备
set -uo pipefail

# 永不猜设备（PITFALLS #371）：显式 SN，或总线上恰好一台。
SER=${1:-}
if [ -z "$SER" ]; then
  ND=$(timeout 8 adb devices 9>&- 2>/dev/null | awk 'NR>1 && $2=="device"' | wc -l)
  [ "$ND" = 1 ] || { echo "总线有 $ND 台 adb 设备：请显式给序列号" >&2; exit 1; }
  SER=$(timeout 8 adb devices 9>&- 2>/dev/null | awk 'NR>1 && $2=="device"{print $1; exit}')
fi
[ -n "$SER" ] || { echo "no adb device"; exit 1; }
# wait-for-device 无 -s 会等**任何**设备；这里既带 -s 又有超时上限
timeout 60 adb -s "$SER" wait-for-device 9>&- || { echo "adb $SER 60 s 内未就绪" >&2; exit 1; }
# shell -n + </dev/null：下面 for 循环里的 adb shell 不许吃脚本 stdin（PITFALLS #397 同族）
adb_s() { timeout "${ADBTO:-20}" adb -s "$SER" shell -n "$@" </dev/null; }

CAP="$(adb -s "$SER" shell getprop ro.boot.hwboardid | tr -d '\r' | sed 's/^SM8750P_//;s/_[0-9]*$//')"
BOOTLOAD_SN="$(adb -s "$SER" shell getprop ro.boot.bootload_sn | tr -d '\r')"
LOCKED="$(adb -s "$SER" shell getprop ro.boot.flash.locked | tr -d '\r')"
DISP="$(adb -s "$SER" shell getprop ro.build.display.id | tr -d '\r')"
WV="$(adb -s "$SER" shell getprop sys.lenovo.widevine_security_level | tr -d '\r')"

DIR="backup/${SER}-${CAP}/pre-unlock"; mkdir -p "$DIR"

# --- 纯读采集（不写设备一个字）---
adb -s "$SER" shell getprop                                   > "$DIR/getprop-locked.txt"
adb -s "$SER" shell 'ls -l /dev/block/by-name'                > "$DIR/by-name.txt"
adb -s "$SER" shell 'cat /proc/partitions'                    > "$DIR/proc-partitions.txt"
adb -s "$SER" shell 'dumpsys sensorservice'                   > "$DIR/sensorservice-locked.txt"
adb -s "$SER" shell 'pm list packages -f'                     > "$DIR/packages.txt"
adb -s "$SER" shell 'settings list global'                    > "$DIR/settings-global.txt"
adb -s "$SER" shell 'settings list secure'                    > "$DIR/settings-secure.txt"
adb -s "$SER" shell 'dumpsys -l'                              > "$DIR/dumpsys-services.txt"
for p in ro.serialno ro.boot.serialno ro.boot.hwboardid ro.boot.bootload_sn \
         ro.build.display.id ro.build.version.security_patch ro.product.model \
         ro.boot.flash.locked ro.boot.vbmeta.device_state ro.boot.verifiedbootstate \
         ro.boot.slot_suffix sys.lenovo.widevine_security_level \
         ro.odm.lenovo.supported_csr_type ro.boot.bootloader; do
  printf '%s=%s\n' "$p" "$(adb -s "$SER" shell getprop $p | tr -d '\r')"
done > "$DIR/key-props.txt"
sha256sum "$DIR"/* > "$DIR/SHA256SUMS"

cat <<EOF

==== ${SER} (${CAP}) locked 基线已存 ${DIR} ====
  系统         : ${DISP}
  锁状态       : ro.boot.flash.locked=${LOCKED}  （1=locked）
  Widevine     : ${WV}   ★解锁极可能永久降为 L3，此项即"标准答案"
  ---- 官网 https://www.zui.com/iunlock 申请表要填的两项 ----
  序列号 SN           : ${SER}
  Bootloader_SN       : ${BOOTLOAD_SN}
  ==========================================================
提示：解锁会擦除全部用户数据并永久失去 L1/保修/FOTA；确认后再进 fastboot 执行解锁。
EOF
