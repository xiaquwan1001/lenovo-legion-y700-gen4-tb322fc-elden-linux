#!/usr/bin/env bash
# 解锁前（locked 状态）零风险取证 + 解锁申请表所需参数打印。
# 设备无关：SN/容量/路径全部运行时读实际设备。用法：
#   scripts/bl-preunlock-evidence.sh            # 自动选唯一 adb 设备
#   scripts/bl-preunlock-evidence.sh <SERIAL>   # 指定设备
set -uo pipefail

SER="${1:-$(adb devices | awk 'NR>1 && $2=="device"{print $1}' | head -1)}"
[ -n "$SER" ] || { echo "no adb device"; exit 1; }
adb -s "$SER" wait-for-device

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
