#!/bin/sh
# qbootctl-mark.sh — 把当前 A/B 槽标记为启动成功，**带等待/重试**（PITFALLS #181）
#
# 为什么需要包装（2026-10-26 Debian 根实测）：
#   单纯 `ExecStart=/usr/bin/qbootctl -m` 在早期启动会失败：
#     qbootctl[433]: get_number_slots: Failed to open bootdev dir (No such file or directory)
#     qbootctl[433]: No slots found, is this an A/B device?
#     → status=1/FAILURE
#   原因不是槽坏了，而是 **设备节点还没被 udev 建出来**（Debian 用 /dev/disk/by-partlabel，
#   Android 式 /dev/block/by-name 也可能存在）。早跑一次失败就完事 ⇒ 槽的 retry 计数
#   照常递减，~7 次开机后卡 fastboot。Alpine 上恰好没踩到（UFS/udev 起得更早），
#   但这是时序竞态，不是发行版差异 ⇒ 两边都用这个包装。
#
# 判据：等到「bootdev 目录出现」再调 qbootctl -m；仍失败则打印诊断并 exit 1
#      （明确失败 > 静默成功：静默成功会让人以为槽已安全）。
set -u
QBOOTCTL=${QBOOTCTL:-/usr/bin/qbootctl}
MAX=${QBOOTCTL_MAX:-15}      # 15 × 2 s = 最多等 30 s
SLEEP=${QBOOTCTL_SLEEP:-2}

log() { echo "qbootctl-mark: $*" >&2; logger -t qbootctl-mark "$*" 2>/dev/null || true; }

# Debian 的 qbootctl 用 /dev/disk/by-partlabel（strings 实证）；Android 系可能用
# /dev/block/by-name。两者都认：优先等 boot_* 链接真的出现，其次目录在就先试一把
# （qbootctl 失败会走重试，不会误判成功）。
have_slots() {
	[ -d /dev/disk/by-partlabel ] && ls /dev/disk/by-partlabel 2>/dev/null | grep -q '^boot_' && return 0
	[ -d /dev/block/by-name ] && return 0
	[ -d /dev/disk/by-partlabel ] && return 0
	return 1
}

i=0
while [ "$i" -lt "$MAX" ]; do
	if have_slots; then
		if "$QBOOTCTL" -m 2>&1 | sed 's/^/qbootctl-mark: /' >&2; then
			# 复核：确认当前槽真的被标成 successful（别只信返回码）
			cur=$("$QBOOTCTL" -c 2>/dev/null)
			if [ -n "$cur" ] && "$QBOOTCTL" -n "$cur" >/dev/null 2>&1; then
				log "slot ${cur} marked successful (after ${i} x ${SLEEP}s wait)"
				exit 0
			fi
			log "warn: qbootctl -m rc=0 but slot ${cur:-?} not verified successful"
		fi
	else
		[ $((i % 5)) -eq 0 ] && log "waiting for bootdev dir (attempt $i/$MAX)"
	fi
	i=$((i + 1))
	sleep "$SLEEP"
done

log "FAILED to mark slot successful after ${MAX} attempts"
"$QBOOTCTL" 2>&1 | sed 's/^/qbootctl-mark: dump: /' >&2 || true
exit 1
