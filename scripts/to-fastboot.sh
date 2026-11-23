#!/bin/bash
# to-fastboot.sh — reliable Linux → fastboot（软路径，唯一实现见 scripts/lib-soft-bootloader.sh）
#
# （历史入口 `cycle.sh --soft` 已删除；现在软重启走 `scripts/iterate.sh`）
# ★ 2026-11-24（PITFALLS #712）：`sync; systemctl reboot bootloader` 在现役 vk192（无 vendor reset 钩子）
#   上也进 fastboot（实测 ~21 s），所以本脚本**默认真发**软路径，不再「无钩子就拒绝」。#690/#701 作废。
#   旧路径 `eldroid-bootctl`（python3 件）已随 Alpine 根退场；misc-BCB 路径 ABL 不采纳。
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

echo "[to-fastboot] device -> fastboot ..."
# ★★ 2026-11-24 更正（PITFALLS #712，实测见 reports/linux-to-bl-vendor-reset-20261123.md §0）：
# `sync; systemctl reboot bootloader` 在**无 PSCI vendor-reset 钩子**的现役 vk192 上同样进 fastboot
# （同启动内对照：无参 `systemctl reboot` 回 Linux，`reboot bootloader` ~21 s 进 fastboot）。
# ⇒ 2026-11-19 那版「#690：无钩子 ⇒ 拒绝走软路径、直接要物理键」已作废（旧错因 = 只比 kallsyms
# 的静态判据 + fail-closed 从未真发命令）。现在默认**真发**软路径，失败才打物理键文案。
# 唯一实现 = scripts/lib-soft-bootloader.sh（别再各写一份）。
SB_WAIT=${SB_WAIT:-90}
. "$(dirname "$0")/lib-soft-bootloader.sh"
if ! soft_to_bootloader "$SB_WAIT"; then
	echo "[to-fastboot] ❌ 软路径未进 fastboot" >&2
	bl_phys_hint
	exit 2
fi
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
