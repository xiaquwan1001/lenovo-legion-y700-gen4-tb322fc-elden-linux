#!/bin/bash
# suspend-drain-rate.sh — 量化「相机栈在位 + 真 suspend」的掉电率（%/h）
#
# 背景：Q24 一直只说「掉电/不断电」，从没有过**可比较的速率**。
#   Q24（DPMS 熄屏）与本实验（整机 suspend）是两个子系统，不得互相顶替
#   （`reports/q24-suspend-hypothesis-excluded-20261019.md` §1.3）。
#   本脚本给 suspend 分支一个硬指标：%SOC 变化 / 小时 + boot_id 是否变 + 唤醒后栈是否还在。
#
# 前置：
#   · 内核必须支持 suspend（/sys/power/state 含 mem）。在机 vk127 是 `CONFIG_SUSPEND=n`，
#     先解决 vk128/vk129 启动即死（scripts/suspend-boot-panic-capture.sh）。
#   · 电池须**不在充电**（否则是充电曲线不是放电率）。脚本会先检查并拒绝跑。
#
# 用法：
#   scripts/suspend-drain-rate.sh                 # 默认 30 分钟窗口
#   scripts/suspend-drain-rate.sh 60              # 60 分钟
#   scripts/suspend-drain-rate.sh 30 --no-camera  # 对照：不加载相机栈
#
# 判据：
#   · boot_id 全程不变 = 没复位（Q24 签名不成立）
#   · 唤醒后 modules/video 数 = 睡前（栈没被拆）
#   · 掉电率 = (cap_start - cap_end) * 60 / minutes
#
# 纪律：idle-delay 置 0 以免会话层抢先熄屏干扰；窗口内不跑任何重编译（#302 过热）。
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
MIN=${1:-30}
shift || true
CAM=1
for a in "$@"; do case "$a" in --no-camera) CAM=0;; esac; done
DEV=${DEV:-root@192.168.7.1}
TS=$(date +%Y%m%d-%H%M%S)
LOG=$ROOT/logs/suspend-drain-$TS.log
mkdir -p "$ROOT/logs"
exec > >(tee -a "$LOG") 2>&1

SSH() { timeout 25 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -o BatchMode=yes "$DEV" "$@" 2>/dev/null; }
WAIT_WAKE=${WAIT_WAKE:-1800}
BAT=/sys/class/power_supply/qcom-battmgr-bat
USB=/sys/class/power_supply/qcom-battmgr-usb

echo "### suspend drain $(date '+%F %T')  window=${MIN}min  camera=$CAM  log=$LOG"

SSH true || { echo "❌ 设备不可达"; exit 1; }

# --- 0. 能力与前置门 ---
STATE=$(SSH 'cat /sys/power/state 2>/dev/null' | tr -d '\r')
echo "-- /sys/power/state = '${STATE:-<空>}'"
case "$STATE" in
	*mem*) : ;;
	*) echo "❌ 内核不支持 suspend（state 为空）。先解决 vk128/vk129 启动即死："
	   echo "   scripts/suspend-boot-panic-capture.sh --arm vk129"
	   exit 2;;
esac

ONLINE=$(SSH "cat $USB/online 2>/dev/null" | tr -d '\r')
STATUS=$(SSH "cat $BAT/status 2>/dev/null" | tr -d '\r')
if [ "${ONLINE:-0}" = "1" ] || echo "${STATUS:-}" | grep -qi charg; then
	echo "❌ 正在充电（usb.online=$ONLINE status=$STATUS）⇒ 测到的是充电曲线。先拔线。"
	exit 3
fi

BID0=$(SSH 'cat /proc/sys/kernel/random/boot_id' | tr -d '\r')
UNAME=$(SSH 'uname -r' | tr -d '\r')
echo "-- boot_id=$BID0  uname=$UNAME"

# --- 1. 相机栈 ---
if [ "$CAM" = 1 ]; then
	SSH 'CAM_FORCE=1 /usr/local/sbin/camera-modules-load.sh >/dev/null 2>&1'
	MODS=$(SSH 'lsmod | grep -cE "camss|cci|camcc|cambist|s5kjns|gc08a8"' | tr -d '\r')
	VIDS=$(SSH 'ls -d /dev/video* 2>/dev/null | wc -l' | tr -d '\r')
	echo "-- 相机栈：模块=$MODS  /dev/video*=$VIDS"
	[ "${MODS:-0}" -ge 5 ] || echo "   ⚠️ 模块数偏少，注意结论口径"
else
	MODS=0; VIDS=$(SSH 'ls -d /dev/video* 2>/dev/null | wc -l' | tr -d '\r')
	echo "-- 对照臂：不加载相机栈（/dev/video*=$VIDS）"
fi

# --- 2. 防会话层抢熄屏 ---
SBU=$(SSH 'for p in $(pidof phoc); do tr "\0" "\n" < /proc/$p/environ 2>/dev/null | sed -n "s/^DBUS_SESSION_BUS_ADDRESS=//p"; done | head -1' | tr -d '\r')
[ -n "$SBU" ] && SSH "su - xuqianhui1001 -c 'DBUS_SESSION_BUS_ADDRESS=$SBU XDG_RUNTIME_DIR=/run/user/1000 gsettings set org.gnome.desktop.session idle-delay \"uint32 0\"'" >/dev/null

CAP0=$(SSH "cat $BAT/capacity" | tr -d '\r')
UPT0=$(SSH 'cut -d" " -f1 /proc/uptime' | tr -d '\r')
PWR0=$(SSH "cat $BAT/power_now 2>/dev/null" | tr -d '\r')
echo "-- 睡前：capacity=${CAP0}%  uptime=${UPT0}s  power_now=${PWR0:-?}uW"

# --- 3. 进入 suspend 并计时 ---
T0=$(date +%s)
echo "-- 写入 mem → suspend（窗口 ${MIN} 分钟；期间 SSH 应失联）"
SSH "sh -c 'sync; echo mem > /sys/power/state'" >/dev/null 2>&1
sleep 10
if SSH true 2>/dev/null; then
	echo "   ⚠️ 写入后 10 s 仍可 SSH ⇒ 可能没真正挂起（检查 dmesg | grep -i suspend）"
	SSH 'dmesg | grep -iE "PM: suspend|Freezing" | tail -5'
fi

echo "-- 等待 ${MIN} 分钟（$(date '+%H:%M:%S') → $(date -d "+${MIN} min" '+%H:%M:%S')）"
sleep $((MIN * 60))

# --- 4. 唤醒 ---
# ★ 2026-10-20 实测（reports/t9-rtc-wake-limit-20261020.md）：
#   RTC wakealarm / rtcwake **唤不醒 s2idle**（挂了 6+ 分钟没醒）。
#   ⇒ 唤醒只能人工按电源键。脚本在这里明确等待并提示，不做静默超时。
echo
echo "======================== 请按电源键唤醒设备 ========================"
echo "  RTC 自动唤醒在 s2idle 下无效（已实测），必须人工按键。"
echo "  脚本会每 5 s 探测一次，最长等 $((WAIT_WAKE)) s。"
echo "==================================================================="
WAKE_T0=$(date +%s)
t=0
while [ $t -lt "$WAIT_WAKE" ]; do
	if SSH true 2>/dev/null; then
		echo "   ✅ 已唤醒（等待 $t s）"
		break
	fi
	sleep 5; t=$((t+5))
done
SSH true || { echo "❌ 唤醒后不可达（等了 ${WAIT_WAKE}s）；用串口看是否死在 resume: tail -30 /var/log/elden-serial/ttyACM0.log"; exit 4; }

BID1=$(SSH 'cat /proc/sys/kernel/random/boot_id' | tr -d '\r')
CAP1=$(SSH "cat $BAT/capacity" | tr -d '\r')
UPT1=$(SSH 'cut -d" " -f1 /proc/uptime' | tr -d '\r')
VIDS1=$(SSH 'ls -d /dev/video* 2>/dev/null | wc -l' | tr -d '\r')
MODS1=$(SSH 'lsmod | grep -cE "camss|cci|camcc|cambist|s5kjns|gc08a8"' | tr -d '\r')
T1=$(date +%s)
# 实际时长 = 进入 suspend 到 SSH 重新可达的墙钟。人工唤醒有 ±几秒抖动，
# 对 %/h 影响可忽略；但必须记下，不能假装精确。
ELAPSED=$(( (T1 - T0) / 60 ))

echo
echo "### 结果"
echo "  窗口实际 $ELAPSED min（含进入/唤醒开销）"
echo "  capacity  ${CAP0}% → ${CAP1}%    Δ=$((CAP0 - CAP1))%"
if [ "$ELAPSED" -gt 0 ]; then
	RATE=$(awk -v a="$CAP0" -v b="$CAP1" -v m="$ELAPSED" 'BEGIN{printf "%.2f", (a-b)*60/m}')
	echo "  ★ 掉电率  ${RATE} %/h"
fi
echo "  boot_id   $([ "$BID0" = "$BID1" ] && echo "未变（无复位）" || echo "变了！$BID0 → $BID1 ⇒ 复位，Q24 签名成立")"
echo "  uptime    ${UPT0}s → ${UPT1}s（挂起期间不进 uptime 属正常）"
echo "  相机栈    模块 ${MODS}→${MODS1}  /dev/video* ${VIDS}→${VIDS1}"
echo "  log       $LOG"
echo
echo "口径提醒：本结果只描述「整机 suspend」，不得写进 Q24（DPMS 熄屏）的判据。"
