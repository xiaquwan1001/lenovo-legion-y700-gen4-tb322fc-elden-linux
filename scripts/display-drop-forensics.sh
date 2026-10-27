#!/bin/sh
# display-drop-forensics.sh — 设备侧「桌面显示栈自发掉线」一次抓全
#
# 背景（2026-10-27）：Debian 根上两小时内两次出现同一形态 —— `card0-DSI-1` `status=connected`
#   但 `dpms=Off` / `enabled=disabled`、logind 里 seat0 会话消失、`phoc` 进程还在、`grim` 挂住、
#   容器 SurfaceControl 报 `DEAD_OBJECT`；**没有 dmesg 复位签名、发生在空闲期**（与 Q28 不同触发）。
#   当时只有零散手查，事后再看已丢现场 ⇒ 本脚本把「掉线瞬间要的东西」一次抓完。
#
# 用法（在设备上跑，或主机 `ssh root@192.168.7.1 'sh -s' < scripts/display-drop-forensics.sh`）：
#   sh display-drop-forensics.sh            # 抓一包，打印路径
#   sh display-drop-forensics.sh --tar      # 额外打成 /var/tmp/<同名>.tar.gz 便于拉回
# 只读：不写 sysfs、不重启、不动分区。
set -u

STAMP=$(date +%Y%m%dT%H%M%S)
OUT="${OUT:-/var/tmp/display-drop-$STAMP}"
mkdir -p "$OUT" || exit 1
say() { printf '[ddf] %s\n' "$*"; }

# 1. 身份与时基
{
  echo "stamp=$STAMP"
  echo "uptime=$(cat /proc/uptime)"
  echo "boot_id=$(cat /proc/sys/kernel/random/boot_id)"
  echo "kernel=$(uname -r)"
  [ -r /etc/os-release ] && grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release
  echo "root=$(findmnt -no FSTYPE,SOURCE / 2>/dev/null)"
} >"$OUT/00-identity.txt" 2>&1

# 2. DRM/KMS 连接器状态（判据核心：dpms / enabled / status 三者组合）
{
  for c in /sys/class/drm/card*-*; do
    [ -d "$c" ] || continue
    printf '%s\n' "== $(basename "$c")"
    for f in status enabled dpms modes; do
      [ -r "$c/$f" ] && printf '  %s=%s\n' "$f" "$(tr '\n' ',' <"$c/$f")"
    done
  done
} >"$OUT/10-drm.txt" 2>&1

# 3. 会话与合成器（掉线时会话消失、phoc 残留）
{
  echo "== loginctl sessions"
  loginctl list-sessions --no-legend 2>&1
  echo "== seats"
  loginctl list-seats --no-legend 2>&1
  echo "== session details (each)"
  for s in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
    loginctl show-session "$s" -p Id -p Active -p State -p Class -p Type -p Seat -p Display 2>&1
  done
  echo "== compositor processes"
  ps -eo pid,ppid,etimes,stat,args 2>/dev/null | grep -E 'phoc|phosh|gnome-session|greetd|phrog' | grep -v grep
  echo "== wayland sockets"
  ls -l /run/user/*/wayland-* 2>&1
} >"$OUT/20-session.txt" 2>&1

# 4. dmesg（全量 + 显示相关 + vblank/PHY/reset 签名）
dmesg >"$OUT/30-dmesg-full.txt" 2>&1 || journalctl -k --no-pager >"$OUT/30-dmesg-full.txt" 2>&1
dmesg 2>/dev/null | grep -iE 'dsi|mdss|dpu|disp|phy|panel|bonded|vblank|pll|link_configured|reset' \
  >"$OUT/31-dmesg-display.txt" 2>&1
dmesg 2>/dev/null | grep -iE 'vblank timeout|crtc_wait_one_vblank|reset failure|dsi_bonded_cmd_failed|link training|estale|PLL|timeout' \
  >"$OUT/32-dmesg-signatures.txt" 2>&1

# 5. 内核侧残留证据（pstore / 复位原因 / 中断计数）
{
  echo "== pstore"
  ls -l /sys/fs/pstore 2>&1
  echo "== reset reason (if any)"
  for f in /sys/kernel/debug/qcom_reset /sys/kernel/restart_reason /proc/device-tree/chosen/qcom,reset-reason; do
    [ -e "$f" ] && { echo "-- $f"; cat "$f" 2>&1 | head -5; }
  done
  echo "== interrupts (dsi/mdss/dpu)"
  grep -iE 'dsi|mdss|dpu' /proc/interrupts 2>&1 | head -20
} >"$OUT/40-kernel-leftovers.txt" 2>&1

# 6. 用户态日志（合成器 / 登录器 / 输入）
{
  jctl() { journalctl --no-pager -n "${2:-200}" -u "$1" 2>&1 | tail -n "${2:-200}"; }
  for u in greetd phoc phosh waydroid-container systemd-logind; do
    echo "==================== $u"
    jctl "$u" 200
  done
  echo "==================== user session (phoc/phosh gnome-session)"
  journalctl --no-pager -n 200 _COMM=phoc 2>&1 | tail -n 200
} >"$OUT/50-journal.txt" 2>&1

# 7. 槽位/看门狗（排除「其实是复位了」）
{
  qbootctl -m 2>&1 || true
  echo "== failed units"
  systemctl --failed --no-legend 2>&1
} >"$OUT/60-slot-units.txt" 2>&1

say "已抓取: $OUT"
ls -l "$OUT" | sed 's/^/[ddf]   /'
if [ "${1:-}" = "--tar" ]; then
  tar -C /var/tmp -czf "$OUT.tar.gz" "$(basename "$OUT")" 2>/dev/null && say "打包: $OUT.tar.gz"
fi
