#!/bin/bash
# to-fastboot.sh — reliable Linux → fastboot, using the PSCI vendor-reset hook.
#
# `cycle.sh --soft` (plain `reboot -f`) no longer reaches fastboot after the
# b-slot bring-up, and `cycle.sh --fastboot` (misc BCB) was NOT honoured by ABL.
# The working path is the PSCI SYSTEM_RESET2 vendor reset added in vk41:
#     eldroid-bootctl reboot bootloader
#
# ★ 2026-11-13 实测警告（PITFALLS #650）：`--boot` 这条组合**不推荐**。
#   本脚本用 `eldroid-bootctl reboot bootloader`（PSCI 暖复位，跳过 systemd 关机序列），
#   随后立刻 `fastboot boot` —— 实测出现过「进 fastboot 后灌镜像 → 黑屏 + 屏幕崩坏/core dump，
#   设备自行回正常槽位」；同一镜像改用 `ssh elden-root 'reboot bootloader'`（systemd 正常关机）
#   再 `fastboot boot` 一次通过。**上机默认改为**：
#       ssh elden-root 'sync; reboot bootloader'   # 等 fastboot
#       fastboot boot out/<img>
#   若必须用本脚本：进 fastboot 后先 `fastboot reboot-bootloader` 让 ABL 重新初始化，再 `fastboot boot`。
#
# usage:
#   scripts/to-fastboot.sh                       # reboot to fastboot, wait
#   scripts/to-fastboot.sh --flash out/boot-elden-vk49.img
#                                                # sign+dd into boot_b FIRST
#                                                # (stays in Linux), then fastboot
#   scripts/to-fastboot.sh --boot out/x.img      # reboot to fastboot + fastboot boot
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"

# --- device lock (serialize across concurrent agents; see scripts/device-lock.sh) ---
. "$(dirname "$0")/lib-device-lock.sh"
device_lock_acquire

FLASH=""; BOOT=""
while [ $# -gt 0 ]; do
	case "$1" in
		--flash) FLASH=$2; shift ;;
		--boot)  BOOT=$2; shift ;;
		-h|--help) sed -n '2,18p' "$0"; exit 0 ;;
		*) echo "unknown arg: $1" >&2; exit 2 ;;
	esac
	shift
done

if [ -n "$FLASH" ]; then
	echo "[to-fastboot] flashing boot_b from inside Linux first..."
	bash "$ROOT/scripts/flash-b.sh" "$FLASH"
fi

echo "[to-fastboot] device -> fastboot (PSCI vendor reset)..."
# 必须给 ssh 套 timeout（2026-11-13 实受，PITFALLS #628）：设备做的是 PSCI SYSTEM_RESET2
# 暖复位，TCP 不会收到 FIN ⇒ 已建立的 ssh 连接会半开，默认要等内核重传超时（~15 min）才返回，
# 期间脚本停在「device -> fastboot」不动、后面的 wait_until 根本轮不到。
# 口径与 kexec-bs-cycle.sh / sd-run-variant.sh 一致：超时就当成功（复位已经发出）。
timeout -k 5 12 $SSH 'sync; eldroid-bootctl reboot bootloader' >/dev/null 2>&1 || true

echo "[to-fastboot] waiting for fastboot..."
# 2026-11-05：改走 lib-wait（先判后睡 + 退避；旧实现固定 45×2 s，且第一拍必睡满 2 s）。
. "$(dirname "$0")/lib-wait.sh"
wait_until "fastboot 上线" 90 wa_fastboot_alive || { echo "[to-fastboot] fastboot timeout — check USB cable / physical keys" >&2; exit 1; }
echo "[to-fastboot] fastboot ok"

if [ -n "$BOOT" ]; then
	echo "[to-fastboot] fastboot boot $BOOT"
	fastboot boot "$BOOT"
	echo "[to-fastboot] booting; use --wait helper (cycle.sh --wait) or ping 192.168.7.1"
fi
