#!/bin/bash
# to-fastboot.sh — reliable Linux → fastboot, using the PSCI vendor-reset hook.
#
# （历史入口 `cycle.sh --soft` 已删除；现在软重启走 `scripts/iterate.sh`）plain `reboot -f` no longer reaches fastboot after the
# b-slot bring-up, and the old misc-BCB path (`cycle.sh --fastboot`) was NOT honoured by ABL.
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
# ★★ 2026-11-19 实测修正（PITFALLS #690）：**现役 vk192 是上游主线核，不含 vendor RESTART2 钩子**。
# 工具 = 只比 kallsyms：`psci_sys_reset` 在、`psci_system_reset2_supported` 在（主线只支持 architectural
# reset_type），但 qcom/vendor reset 处理函数 = 0 命中；`grep -icE 'restart2|vendor_reset' /proc/kallsyms`
# 只有无关符号。⇒ `reboot bootloader` / `systemctl reboot bootloader` 退化成**标准 SYSTEM_RESET**，
# ABL 当普通重启处理、仍按 `_b` 起 Linux——这就是「发了命令设备没动」的真因。
# 旧实现（`eldroid-bootctl reboot bootloader … || true`）会把这种情形变成静默空等 90 s 后报 timeout，
# 于是人以为是 USB/按键问题。现在默认**拒绝走软路径**，把手动作业说清楚；确实换回带钩子的核
# （`elden/vk41-psci-reboot` 一类）时才用 ALLOW_SOFT_RESET=1 打开。
if [ "${ALLOW_SOFT_RESET:-0}" = 1 ]; then
	# PITFALLS #628：PSCI 暖复位不发 FIN，已建的 ssh 半开 ⇒ timeout 当成功（复位已经发出）。
	timeout -k 5 12 $SSH 'sync; systemctl reboot bootloader' >/dev/null 2>&1
	rc=$?
	[ "$rc" = 0 ] || [ "$rc" = 124 ] || { echo "[to-fastboot] ❌ 软复位失败 rc=$rc（设备可能仍在 Linux）" >&2; exit 1; }
else
	echo "[to-fastboot] ❌ 现役内核无 vendor RESTART2 钩子（#690）⇒ 软路径不可用，不盲发。" >&2
	echo "[to-fastboot]    手动作业：长按电源 10 s 关机 → 按住【音量上 + 电源】至 fastboot 屏。" >&2
	echo "[to-fastboot]    或换回带钩子的核后用 ALLOW_SOFT_RESET=1 重跑本脚本。" >&2
	exit 2
fi

echo "[to-fastboot] waiting for fastboot..."
# 2026-11-05：改走 lib-wait（先判后睡 + 退避；旧实现固定 45×2 s，且第一拍必睡满 2 s）。
. "$(dirname "$0")/lib-wait.sh"
wait_until "fastboot 上线" 90 wa_fastboot_alive || { echo "[to-fastboot] fastboot timeout — check USB cable / physical keys" >&2; exit 1; }
echo "[to-fastboot] fastboot ok"

if [ -n "$BOOT" ]; then
	# PITFALLS #371：裸 fastboot 会把载荷发给总线上别的设备（或抢不通的通道）。
	[ -n "${SER:-}" ] || { echo "[to-fastboot] ❌ --boot 需显式 SER=<SN>（多设备总线禁止猜，#371）" >&2; exit 2; }
	. "$(dirname "$0")/lib-fastboot.sh"
	# PITFALLS #658：先证通道独占，再发启动命令。
	orph=$(fborphans)
	[ "$orph" = 0 ] || { echo "[to-fastboot] ❌ 本机有 $orph 个 fastboot 进程（#658：先清孤儿再上机）" >&2; exit 2; }
	fbprobe || { echo "[to-fastboot] ❌ 通道不可用（5 s 内 getvar product 无回显，#658）" >&2; exit 2; }
	# PITFALLS #650：本脚本走 PSCI 暖复位，ABL 未重新初始化时直接 boot 出现过黑屏+崩坏。
	# 原注释写了「先 reboot-bootloader」，但代码没做 —— 这里补上，并把 boot 收敛到 fbx。
	echo "[to-fastboot] ABL re-init: fastboot reboot-bootloader（#650）"
	fbx reboot-bootloader || { echo "[to-fastboot] ❌ reboot-bootloader 失败 rc=$?" >&2; exit 3; }
	wait_until "fastboot 重新上线" 60 wa_fastboot_alive || { echo "[to-fastboot] reboot-bootloader 后 fastboot 未回" >&2; exit 3; }
	fbprobe || { echo "[to-fastboot] ❌ 重初始化后通道仍不可用（#658）" >&2; exit 3; }
	echo "[to-fastboot] fastboot boot $BOOT"
	fbx boot "$BOOT"; rc=$?
	printf '%s\n' "$_FB_OUT"
	echo "[to-fastboot] booting rc=$rc; 用 scripts/slot-switch.sh status 或 ping 192.168.7.1 跟进"
	[ "$rc" = 0 ] || exit "$rc"
	# 失败标志兜底：节奏型实验（反复 fastboot boot / 反复重启）结束必须回读槽属性，
	# 否则 boot_* 的 retry 递减到 0 就留下「下一次注定失败」的 UNBOOTABLE。
	echo "[to-fastboot] 提示：拿到 shell 后立刻 scripts/slot-switch.sh status（槽属性留档）"
fi
