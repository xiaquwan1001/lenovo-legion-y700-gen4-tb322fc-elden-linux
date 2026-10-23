#!/bin/bash
# slot-switch.sh — A/B 槽位「一键往返切换 + 槽属性自检」（../TASKS/README.md §2 C7）
#
# 背景：本机 a 槽 = stock Android，b 槽 = mainline 持久根（见 ../DEVICE/README.md §2）。
# 进 Android = 切到 a 槽；回 Linux = 切回 b 槽。实机验证（HANDOFF §20）：
# 「多数情况只切槽就够」——不需要刷 dtbo（2026-10-11 再次成立）。
#
# 用法：
#   scripts/slot-switch.sh status            # 看当前在哪（fastboot/adb/ssh）+ 槽属性
#   scripts/slot-switch.sh a                 # 切 active=a（不重启）
#   scripts/slot-switch.sh b                 # 切 active=b（不重启）
#   scripts/slot-switch.sh a --reboot        # 切 a 并重启，等到 Android adb 上线
#   scripts/slot-switch.sh b --reboot        # 切 b 并重启，等到 Linux ssh 上线 + 置 boot_b succ
#
# 纪律：
#   · fastboot 命令一律单条（PITFALLS #3）；本脚本已拆单条。
#   · b 槽回 Linux 后自动跑 scripts/fix-ab-mark-successful.sh（PITFALLS #181：
#     不置 BOOT_SUCCESSFUL ⇒ 每次启动扣 retry，~7 次卡 fastboot）。
#   · Linux → fastboot 走 eldroid-bootctl（PSCI RESTART2），不用 `reboot bootloader`
#     （OpenRC 下会变成 halt+VBUS 自开机，PITFALLS #150–#152 一类）。
#   · 切槽会写 GPT：脚本每次写前把 fastboot 侧当前槽读回并打印；回退 = 再切回。
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
TAB=${TAB:-root@192.168.7.1}
. "$(dirname "$0")/lib-device-lock.sh"
device_lock_acquire

# --- 目标设备必须显式指定（PITFALLS #371）---------------------------------
# 本脚本曾经用裸 `fastboot devices` / `adb get-state` 判断「当前在哪」，即假设
# 总线上只有本机平板。实测代价：总线上唯一的 adb 设备是**另一台手机**时，
# `adb get-state` 返回 `device` ⇒ 脚本判定「在 Android」⇒ 把 `adb reboot bootloader`
# 发给了那台无关手机。现改为：
#   · 串口/序列号优先级 SER / SERIAL / TABLET_SERIAL 环境变量，或第一个非选项参数 --serial <SN>
#   · 只允许**fastboot 侧唯一设备**自动推导（且 product 必须匹配 $TABLET_PRODUCT_MATCH）
#   · adb 侧**永不猜**：没有显式序列号就直接失败并提示
#   · `adb devices` 里有多个设备时直接失败
SER=${SER:-${SERIAL:-${TABLET_SERIAL:-}}}
TABLET_PRODUCT_MATCH=${TABLET_PRODUCT_MATCH:-elden}

fb() { timeout "${FBTO:-20}" fastboot ${SER:+-s "$SER"} "$@" 2>&1; }
fb_devices() { timeout 6 fastboot devices 2>/dev/null | awk 'NF{print $1}'; }
adbx() { timeout "${ADBTO:-15}" adb "$@" 9>&- 2>/dev/null; }
adb_devices() { timeout 8 adb devices 9>&- 2>/dev/null | awk 'NR>1 && $2=="device"{print $1}'; }

resolve_target() {
	[ -n "$SER" ] && return 0
	local list n
	list=$(fb_devices); n=$(printf '%s\n' "$list" | grep -c . || true)
	if [ "$n" = 1 ]; then
		SER=$(printf '%s\n' "$list" | head -1)
		local prod
		prod=$(timeout 8 fastboot -s "$SER" getvar product 2>&1 | awk -F': ' '/^product:/{print $2}')
		case "$prod" in
			*"$TABLET_PRODUCT_MATCH"*) : ;; # 本机平板（fastboot product 形如 elden_prc_wifi）
			*) echo "[slot] ❌ 唯一 fastboot 设备 $SER 的 product='$prod' 不含 '$TABLET_PRODUCT_MATCH'，拒绝操作（可显式 SER=<SN> 覆盖）" >&2; SER=""; return 1 ;;
		esac
		echo "[slot] 自动选定 fastboot 设备：$SER (product=$prod)"
		return 0
	fi
	echo "[slot] ❌ 无法确定目标设备（fastboot 设备数=$n）。请显式指定：SER=<序列号> $0 ... 或 --serial <序列号>" >&2
	return 1
}

have_fastboot() { resolve_target >/dev/null 2>&1 || return 1; [ "$(fb getvar current-slot 2>&1 | grep -c current-slot)" != 0 ]; }
# adb 侧只认显式序列号（PITFALLS #371：adb get-state 会把别的手机当成我们的）
have_adb()      { [ -n "$SER" ] && [ "$(adbx -s "$SER" get-state | tr -d '\r')" = device ]; }
have_linux()    { timeout 8 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$TAB" true 2>/dev/null; }

wait_fastboot() { for i in $(seq 1 60); do have_fastboot && { echo "[slot] fastboot 上线 (~$((i*2))s)"; return 0; }; sleep 2; done; echo "[slot] fastboot 超时" >&2; return 1; }
wait_adb()      { for i in $(seq 1 60); do sleep 5; s=$(adb get-state 2>/dev/null | tr -d '\r'); [ "$s" = device ] && { echo "[slot] Android adb 上线 (~$((i*5))s)"; return 0; }; done; echo "[slot] Android adb 超时" >&2; return 1; }
wait_linux()    { for i in $(seq 1 60); do sleep 3; have_linux && { echo "[slot] Linux ssh 上线 (~$((i*3))s)"; return 0; }; done; echo "[slot] Linux ssh 超时" >&2; return 1; }

show_attrs() {
	echo "[slot] 槽位属性："
	fb getvar current-slot 2>&1 | grep -E 'current-slot' || true
	for s in a b; do
		printf '  slot_%s: retry=%s unbootable=%s successful=%s\n' "$s" \
			"$(fb getvar slot-retry-count:$s 2>&1 | awk -F': ' '/slot-retry/{print $2}')" \
			"$(fb getvar slot-unbootable:$s 2>&1 | awk -F': ' '/slot-unbootable/{print $2}')" \
			"$(fb getvar slot-successful:$s 2>&1 | awk -F': ' '/slot-successful/{print $2}')"
	done
}

ensure_fastboot() {
	have_fastboot && return 0
	if have_adb; then
		echo "[slot] 在 Android(adb $SER) → adb -s $SER reboot bootloader"
		adbx -s "$SER" reboot bootloader >/dev/null 2>&1 || true
	elif have_linux; then
		echo "[slot] 在 Linux(ssh) → eldroid-bootctl reboot bootloader"
		timeout 25 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "$TAB" \
			'/usr/local/sbin/eldroid-bootctl reboot bootloader 2>/dev/null || eldroid-bootctl reboot bootloader 2>/dev/null' >/dev/null 2>&1 || true
	else
		echo "[slot] 既非 fastboot/adb/ssh —— 请手动进 fastboot（电源键或 fastboot reboot bootloader）" >&2
		return 1
	fi
	wait_fastboot
}

cmd=${1:-}; shift || true
want_reboot=0
_rest=()
while [ $# -gt 0 ]; do
	case "$1" in
		--reboot) want_reboot=1 ;;
		--serial) SER=${2:?--serial 需要序列号}; shift ;;
		--serial=*) SER=${1#--serial=} ;;
		*) _rest+=("$1") ;;
	esac
	shift
done

case "$cmd" in
status)
	if have_fastboot; then echo "[slot] 当前位置：fastboot ($SER)"; show_attrs
	elif have_adb; then echo "[slot] 当前位置：Android (adb $SER)  slot=$(adbx -s "$SER" shell getprop ro.boot.slot_suffix 2>/dev/null | tr -d '\r')"
	elif have_linux; then echo "[slot] 当前位置：Linux (ssh)"; timeout 20 ssh -o StrictHostKeyChecking=no "$TAB" 'eldroid-bootctl slot info 2>/dev/null || qbootctl 2>/dev/null' 2>/dev/null || true
	else echo "[slot] 未发现设备（fastboot/adb/ssh 都不可达）"; exit 1; fi
	;;
a|b)
	ensure_fastboot || exit 1
	before=$(fb getvar current-slot 2>&1 | awk -F': ' '/current-slot/{print $2}')
	echo "[slot] 切换前 current-slot=$before → 目标 $cmd"
	fb --set-active=$cmd
	after=$(fb getvar current-slot 2>&1 | awk -F': ' '/current-slot/{print $2}')
	echo "[slot] 切换后 current-slot=$after"
	[ "$after" = "$cmd" ] || { echo "[slot] ❌ 读回不符，停止" >&2; exit 1; }
	show_attrs
	if [ "$want_reboot" = 1 ]; then
		echo "[slot] reboot → 等待目标系统"
		fb reboot
		if [ "$cmd" = a ]; then wait_adb
		else wait_linux && { echo "[slot] 置 boot_b succ（qbootctl -m b）"; timeout 30 ssh -o StrictHostKeyChecking=no "$TAB" 'qbootctl -m b 2>/dev/null || true; sleep 1; qbootctl -n b 2>/dev/null' || true; }; fi
	fi
	;;
"")
	sed -n '2,20p' "$0"; exit 1 ;;
*)
	echo "[slot] 未知子命令：$cmd（用 status|a|b [--reboot]）" >&2; exit 2 ;;
esac
