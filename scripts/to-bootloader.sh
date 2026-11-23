#!/bin/bash
# to-bootloader.sh — 主机侧「Linux → bootloader」驱动 + 判据（配套设备侧 elden-to-bootloader）
#
# 为什么（2026-11-21 建，2026-11-24 更正）：设备窗口里的测试（AVB 债验收 `fastboot flash vbmeta_b`/
# `fastboot boot`、Android a 槽 S1–S5）都需要进 fastboot。★ **PITFALLS #712（2026-11-23 实测）**：
# 现役 vk192（上游主线核、无 vendor-reset 钩子）上 `sync; systemctl reboot bootloader` 同样进 fastboot
# ⇒ 2026-11-21 的「#690/#701：软路径全灭、只能人肉长按【音量上 + 电源】」**已作废**。
# 本脚本仍保留两臂，只因为“哪一臂生效”必须用 `fastboot devices` 里出现目标 SN 来证明：
# 默认 `--arm auto` 交设备侧 `elden-to-bootloader --auto`（#712 后恒走 psci 臂 = `reboot bootloader`）。
#
# 用法：
#   scripts/to-bootloader.sh                 # 自动选臂（设备侧能力自检决定 psci/bcb）
#   scripts/to-bootloader.sh --arm bcb       # 强制 BCB（misc command=bootonce-bootloader）
#   scripts/to-bootloader.sh --arm psci      # 强制 PSCI（`systemctl reboot bootloader`）
#   scripts/to-bootloader.sh --dry-run       # 只打印将发生什么
#   scripts/to-bootloader.sh --clear-bcb     # 只清 misc 头 4 KiB（不重启）
#   SER=HA2EXB0E TAB=root@192.168.7.1 WAIT=150 scripts/to-bootloader.sh
#
# 判据三态：
#   fastboot（目标 SN 出现）        ⇒ rc=0，打印下一步（并提示 `fastboot reboot-bootloader` 前先核通道独占）
#   Linux 回来（SSH 可登且 uptime 变小/BCB 已被消费）⇒ rc=10（= 该臂对本核无效，写回结论）
#   both 都没有（超时）            ⇒ rc=11（先查线/供电，别猜内核）
#
# 纪律：设备写入走 scripts/device-lock.sh 串行；fastboot 一律显式 -s $SER（PITFALLS #371）。
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
SER=${SER:-HA2EXB0E}
TAB=${TAB:-root@192.168.7.1}
WAIT=${WAIT:-150}
SSH_BASE=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes "$TAB")
DEV_TOOL=/usr/local/sbin/elden-to-bootloader

ARM=auto; DRY=0; CLEAR=0
while [ $# -gt 0 ]; do
	case "$1" in
		--arm) ARM=${2:?--arm 需要 auto|psci|bcb}; shift ;;
		--dry-run|--dry) DRY=1 ;;
		--clear-bcb) CLEAR=1 ;;
		-h|--help) sed -n '2,26p' "$0"; exit 0 ;;
		*) echo "未知参数 $1（--help）" >&2; exit 2 ;;
	esac
	shift
done
case "$ARM" in auto|psci|bcb) ;; *) echo "--arm 只能是 auto|psci|bcb" >&2; exit 2 ;; esac

. "$ROOT/scripts/lib-hosttools.sh"
ensure_hosttools --quiet
[ -n "${FB_BIN:-}" ] || { echo "[to-bl] 找不到 fastboot（见 scripts/lib-hosttools.sh）" >&2; exit 2; }
. "$ROOT/scripts/lib-device-lock.sh"
device_lock_acquire

fb_devices_sn() { # 目标 SN 在不在 fastboot 列表里（不进管道，PITFALLS #584）
	local f; f=$(mktemp "${TMPDIR:-/tmp}/fbd.XXXXXX")
	timeout -k 2 8 "$FB_BIN" devices >"$f" 2>/dev/null
	local out; out=$(cat "$f"); rm -f "$f"
	case "$out" in *"$SER"*) return 0 ;; *) return 1 ;; esac
}
linux_up() { timeout -k 2 6 "${SSH_BASE[@]}" 'cut -d. -f1 /proc/uptime' 2>/dev/null; }

# ---- 0) 设备必须先在 Linux ----
UP0=$(linux_up)
if [ -z "$UP0" ]; then
	if fb_devices_sn; then echo "[to-bl] 设备已在 fastboot（$SER）⇒ 无需重启"; exit 0; fi
	echo "[to-bl] ❌ 既不在 Linux（ssh 不通）也不在 fastboot ⇒ 先插线/上电（DEVICE/README.md §1.6）" >&2
	exit 11
fi
echo "[to-bl] 设备在 Linux：uptime=${UP0}s、UTS=$(timeout -k 2 6 "${SSH_BASE[@]}" 'uname -r')"

# ---- 1) 设备侧工具在不在（缺则先部署，幂等）----
if ! timeout -k 2 6 "${SSH_BASE[@]}" "test -x $DEV_TOOL" 2>/dev/null; then
	if [ "$DRY" = 1 ]; then echo "[dry] 需先部署设备侧工具：scp scripts/elden-to-bootloader.sh $TAB:$DEV_TOOL"; exit 0; fi
	echo "[to-bl] 设备侧工具缺失 ⇒ 部署"
	timeout -k 3 60 scp -o BatchMode=yes -o ConnectTimeout=8 \
		"$ROOT/scripts/elden-to-bootloader.sh" "$TAB:$DEV_TOOL" >/dev/null 2>&1 || { echo "[to-bl] 部署失败" >&2; exit 2; }
	timeout -k 2 10 "${SSH_BASE[@]}" "chmod 755 $DEV_TOOL" || { echo "[to-bl] chmod 失败" >&2; exit 2; }
fi

if [ "$CLEAR" = 1 ]; then
	echo "[to-bl] 清 BCB（misc 头 4 KiB）"
	[ "$DRY" = 1 ] && { echo "[dry] $DEV_TOOL --clear-bcb"; exit 0; }
	timeout -k 3 60 "${SSH_BASE[@]}" "$DEV_TOOL --clear-bcb" || exit 3
	exit 0
fi

# ---- 2) 设备侧能力自检（打印臂与钩子判定）----
timeout -k 3 60 "${SSH_BASE[@]}" "$DEV_TOOL --dry-run" || { echo "[to-bl] 设备侧 --dry-run 失败" >&2; exit 2; }

if [ "$DRY" = 1 ]; then
	echo "[dry] 实跑命令：ssh $TAB '$DEV_TOOL --$ARM'（会重启设备）"
	exit 0
fi

# ---- 3) 发（nohup 后 ssh 会断，属预期）----
echo "[to-bl] 发重启（arm=$ARM）：设备会断连，随后等 fastboot…"
timeout -k 5 20 "${SSH_BASE[@]}" "nohup $DEV_TOOL --$ARM >/tmp/elden-to-bl.log 2>&1 &" >/dev/null 2>&1 || true
sleep 3

# ---- 4) 等判据 ----
deadline=$(( $(date +%s) + WAIT ))
while [ "$(date +%s)" -lt "$deadline" ]; do
	if fb_devices_sn; then
		echo "[to-bl] ✅ fastboot 上线（$SER，arm=$ARM，用时 $(( WAIT - (deadline - $(date +%s)) ))s）"
		echo "[to-bl] 下一步：进 fastboot 后先 \`$FB_BIN -s $SER reboot-bootloader\` 让 ABL 重新初始化再灌件（PITFALLS #650）"
		echo "[to-bl] 收尾提醒：拿到 shell 后立刻 scripts/slot-switch.sh status（槽属性留档，防 retry 抽干 #672）"
		exit 0
	fi
	now_up=$(linux_up)
	if [ -n "$now_up" ] && [ "$now_up" -lt "$UP0" ] 2>/dev/null; then
		echo "[to-bl] ⚠ 设备回到了 Linux（uptime ${now_up}s < 之前 ${UP0}s）⇒ arm=$ARM 对本核**无效**" >&2
		echo "[to-bl]   结论登记：$( [ "$ARM" = bcb ] && echo 'BCB bootonce-bootloader 未被 ABL 采纳（与 Q23 一致）' || echo 'psci 臂本次未生效（#712 路径已实测可用，本次失败按现场记账：查线/供电/ABL）' )" >&2
		timeout -k 2 10 "${SSH_BASE[@]}" "$DEV_TOOL --clear-bcb" >/dev/null 2>&1 || true
		exit 10
	fi
	sleep 4
done
echo "[to-bl] ❌ ${WAIT}s 内既没 fastboot 也没回 Linux ⇒ 先查线/供电/按键，别猜内核" >&2
exit 11
