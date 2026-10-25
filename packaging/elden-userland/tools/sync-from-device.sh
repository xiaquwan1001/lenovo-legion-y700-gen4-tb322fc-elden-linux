#!/bin/bash
# sync-from-device.sh — 把设备上的用户态「自研」文件逐字采回仓库（**只读设备**）
#
# 做什么
#   1. 从设备拉文本文件（脚本 / initd / local.d / conf.d / config）到 files/<dst>
#   2. 对 ELF 只记 sha256/size（二进制不进 git，靠 sources.tsv 重建）
#   3. 生成 MANIFEST.tsv（dst / kind / sha256 / size / mode / repo_src）
#
# 不做：不写设备、不 ssh 到容器、不改任何 rootfs。
#
# 用法：bash tools/sync-from-device.sh [user@host]
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SSH_TARGET=${1:-${SSH_TARGET:-root@192.168.7.1}}
OUT_FILES="$HERE/files"
MANIFEST="$HERE/MANIFEST.tsv"

SSH="ssh -o BatchMode=yes -o ConnectTimeout=8 $SSH_TARGET"

# --- 采集清单（显式枚举，不用通配；通配会把 .bak-* 一起拖进来） ---------------
TEXT_PATHS=(
  # 自研 /usr/local/sbin 脚本
  usr/local/sbin/ath12k-load.sh        usr/local/sbin/ath12k-retry.sh
  usr/local/sbin/audio-alsa-init.sh    usr/local/sbin/bt-up.sh
  usr/local/sbin/charge-ctl.sh         usr/local/sbin/charge-watch.sh
  usr/local/sbin/dpms-watch.sh         usr/local/sbin/net-selfheal.sh
  usr/local/sbin/net-up.sh             usr/local/sbin/net-up-manual.sh
  usr/local/sbin/start-desktop.sh      usr/local/sbin/time-sync.sh
  usr/local/sbin/usb-gadget            usr/local/sbin/slot-attr.py
  usr/local/sbin/openrc-enable.sh      usr/local/sbin/fix-logind-poweroff.sh
  usr/local/sbin/blankspy.sh           usr/local/sbin/kmsgspy.sh
  usr/local/sbin/camera-modules-load.sh usr/local/sbin/cam-mode.sh
  usr/local/sbin/q28-boot-watchdog.sh  usr/local/sbin/q28-watchdog.sh
  usr/local/sbin/wifi-scan-refresh.sh  usr/local/sbin/elden-backlight-floor.sh
  usr/local/sbin/sleep-bisect.sh       usr/local/sbin/sleep-cumulative.sh
  usr/local/sbin/elden-session-root    usr/local/sbin/elden-session-user
  usr/local/sbin/greetd-initial-session.sh usr/local/sbin/setup-session-greetd.sh
  usr/local/sbin/waydroid-ipv6          usr/local/sbin/waydroid-session.sh
  usr/local/sbin/waydroid-ui.sh         usr/local/sbin/wd-ctl.sh usr/local/sbin/wd-restart.sh
  usr/local/sbin/elden-powerlog.initd   usr/local/sbin/99-unmanaged.conf
  # 自研 /usr/local/bin 脚本
  usr/local/bin/elden-ime-mode         usr/local/bin/elden-ime-toggle
  usr/local/bin/eldroid-bootctl        usr/local/bin/ssc-udp-relay.py
  usr/local/bin/slot-attr.py           usr/local/bin/bwrap
  usr/local/bin/feedback               usr/local/bin/vibrate
  usr/local/bin/q28-race-hunt.sh       usr/local/bin/scale.sh
  # 自研 / 打过补丁的 initd（OpenRC 语义的唯一现存位置）
  etc/init.d/elden-hapticd             etc/init.d/elden-powerlog
  etc/init.d/greetd                    etc/init.d/iio-sensor-proxy
  etc/init.d/qbootctl                  etc/init.d/wifi-scan-refresh
  etc/init.d/pstore-catch              etc/init.d/ssc-udp-relay
  etc/init.d/waydroid-ipv6             etc/init.d/backlight-floor
  # 参数与一次性启动逻辑
  etc/conf.d/elden-hapticd             etc/conf.d/wifi-scan-refresh
  etc/conf.d/backlight-floor           etc/conf.d/greetd
  etc/local.d/elden-bringup.start      etc/local.d/elden-bootlog.start
  etc/local.d/50-gunyah.start
  etc/greetd/config.toml
  etc/udev/rules.d/99-elden.rules
  # 根 init（真源在 initramfs/init，这里只记录设备副本 sha 以便发现漂移）
  init
)

# ELF：不采内容，只记 sha（重建见 sources.tsv）
ELF_PATHS=(
  usr/local/bin/elden-hapticd
  usr/local/bin/elden-ime-focusd
  usr/local/bin/eldroid-sensord
  usr/local/bin/ffrumble
  usr/local/bin/waydroid-sensord
  usr/local/bin/waydroid-sensord-udp
  usr/local/sbin/reboot2
)

die() { printf 'sync: FATAL: %s\n' "$*" >&2; exit 1; }

$SSH true 2>/dev/null || die "设备不可达：$SSH_TARGET（本脚本只读设备，不需要 fastboot）"

tmp=$(mktemp -d) || die "mktemp"
trap 'rm -rf "$tmp"' EXIT

# --- 1. 文本文件：设备侧 tar 流（保 mtime/mode），主机侧解到 files/ -----------
present=()
for p in "${TEXT_PATHS[@]}"; do
  $SSH "[ -f /$p ]" && present+=("$p") || printf 'sync: skip (absent) /%s\n' "$p"
done
[ "${#present[@]}" -gt 0 ] || die "设备上没有任何可采文本文件"

rm -rf "$OUT_FILES"
mkdir -p "$OUT_FILES"
$SSH "tar -cf - -C / ${present[*]}" | tar -xf - -C "$OUT_FILES" \
  || die "tar 流失败（busybox tar / 权限？）"

# --- 2. 元数据：kind / sha256 / size / mode ----------------------------------
meta="$tmp/meta.tsv"
: >"$meta"
for p in "${present[@]}"; do
  case "$p" in
    *.py)  kind=python ;;
    init)  kind=init ;;
    etc/init.d/*) kind=openrc-initd ;;
    etc/local.d/*) kind=locald ;;
    *.toml|*.rules|etc/conf.d/*) kind=config ;;
    *)     kind=script ;;
  esac
  read -r h sz mode < <($SSH "sha256sum /$p | cut -d' ' -f1; stat -c '%s %a' /$p" | tr '\n' ' ')
  printf '%s\t%s\t%s\t%s\t%s\tfiles/%s\n' "/$p" "$kind" "$h" "$sz" "$mode" "$p" >>"$meta"
done

# 设备上有、但不是 we own 的 initd 覆盖（防止「设备改了、我们不知道」）
for p in "${ELF_PATHS[@]}"; do
  if $SSH "[ -f /$p ]"; then
    read -r h sz mode < <($SSH "sha256sum /$p | cut -d' ' -f1; stat -c '%s %a' /$p" | tr '\n' ' ')
    printf '%s\t%s\t%s\t%s\t%s\t-\n' "/$p" elf "$h" "$sz" "$mode" >>"$meta"
  else
    printf 'sync: skip (absent) /%s\n' "$p"
  fi
done

# --- 3. MANIFEST.tsv（排序、带表头） ---------------------------------------
{
  printf 'dst\tkind\tsha256\tsize\tmode\trepo_src\n'
  sort -k1,1 "$meta"
} >"$MANIFEST"

printf '\nsync: %s 条已采（text=%s elf=%s）→ %s\n' \
  "$(($(wc -l <"$MANIFEST") - 1))" "${#present[@]}" "${#ELF_PATHS[@]}" "${MANIFEST#$HERE/}"

# --- 4. 提示：哪些 ELF 还没有重建源 ---------------------------------------
if [ -f "$HERE/sources.tsv" ]; then
  awk -F'\t' 'NR>1 && $2=="elf" && $6=="-" {print $1}' "$MANIFEST" | while read -r d; do
    grep -qP "^\Q$d\E\t" "$HERE/sources.tsv" || printf 'sync: ⚠ 无重建源（sources.tsv 缺项）：%s\n' "$d"
  done
fi
