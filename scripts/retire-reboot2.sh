#!/bin/bash
# retire-reboot2.sh — 把设备上的 `/usr/local/sbin/reboot2` 换成「拒绝壳」（幂等；2026-11-27）
#
# 为什么（PITFALLS #749，证据 reports/upstream-coresight-fixes-20261127.md §5）：
#   `reboot2` 是 Alpine 期的「带 reason 的 reboot」工具，早被 `systemctl reboot
#   --reboot-argument=bootloader`（systemd ≥257）取代。它走 PSCI 暖复位、与 ABL 状态耦合，
#   2026-11-27 实测把设备带进「phosh 起来后整机卡死、USB 全消失」（要长按电源 15 s）。
#   口径早就写了「停用」，但二进制仍在 PATH 里 ⇒ 任何人凭记忆就能再踩一次。
#
# 动作（幂等）：
#   1) 真件留档：`/var/lib/elden/retired/reboot2-<日期>`（不存在才复制）+ 同目录 sha256；
#   2) `/usr/local/sbin/reboot2` 换成 810 B 的 sh 壳：打印正确入口并 rc=1
#      （任何残留调用立刻可见并失败，不会再「看起来成功」）；
#   3) 删除 `/etc/modules-load.d` 之外的引用不动；`q28-boot-watchdog.sh` 的能力自检会因
#      拿不到旧 banner 而回退 `sysrq-b`（该 unit 在现机 disabled）。
#
# 回滚：`mv /var/lib/elden/retired/reboot2-<日期> /usr/local/sbin/reboot2`
#
# 用法：bash scripts/retire-reboot2.sh [--dry-run]
#       rootfs/镜像重建会把真二进制装回（rootfs/build-overlay.sh / build-rootfs.sh /
#       configure-ubuntu.sh 都编 reboot2.c）⇒ **重建后重跑本脚本**。
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
TAB=${TAB:-root@192.168.7.1}
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -o BatchMode=yes "$TAB")

. "$ROOT/scripts/lib-device-lock.sh"
device_lock_acquire

echo "[retire-reboot2] target=$TAB dry_run=$DRY"
if [ "$DRY" = 1 ]; then
	"${SSH[@]}" 'ls -l /usr/local/sbin/reboot2* 2>&1; head -3 /usr/local/sbin/reboot2 2>/dev/null'
	exit 0
fi

"${SSH[@]}" 'sh -s' <<'EOS'
set -e
BIN=/usr/local/sbin/reboot2
KEEP=/var/lib/elden/retired/reboot2-20261127
mkdir -p /var/lib/elden/retired

if [ -f "$BIN" ] && head -2 "$BIN" 2>/dev/null | grep -q 'RETIRED 2026-11-27'; then
	echo "[retire-reboot2] 已是拒绝壳（幂等，无改动）"
	"$BIN" >/dev/null 2>&1 && { echo "FAIL: 壳竟然返回 0"; exit 1; } || true
	exit 0
fi

if [ -f "$BIN" ]; then
	# 真件（ELF）⇒ 留档；已是改名件就不再重复复制
	if [ ! -f "$KEEP" ]; then
		cp -a "$BIN" "$KEEP"
		sha256sum "$KEEP" > "$KEEP.sha256"
	fi
	mv -f "$BIN" "$BIN.retired-20261127" 2>/dev/null || rm -f "$BIN"
fi

cat > "$BIN" <<'STUB'
#!/bin/sh
# RETIRED 2026-11-27（PITFALLS #368/#542/#749）：`reboot2` 不再是 Linux→bootloader 的入口。
#   * 无参曾被当「正常重启」，旧构建无参=进 fastboot（#229）；它走过 PSCI 暖复位，
#     与 ABL 状态耦合，2026-11-27 实测把设备带进「phosh 起来后整机卡死、USB 全消失」。
#   * 唯一入口：systemctl reboot --reboot-argument=bootloader（systemd<257 用位置参数）
#     或主机侧 scripts/to-fastboot.sh / scripts/elden-to-bootloader.sh。
# 保留本壳仅为让任何残留调用立刻可见并失败（勿删此文件；真件在
# /var/lib/elden/retired/reboot2-20261127 与 /usr/local/sbin/reboot2.retired-20261127）。
printf "reboot2: RETIRED (2026-11-27) — 用 systemctl reboot --reboot-argument=bootloader\n" >&2
exit 1
STUB
chmod 755 "$BIN"
echo "[retire-reboot2] 已换成拒绝壳；真件留档 $KEEP"
EOS

"${SSH[@]}" 'ls -l /usr/local/sbin/reboot2*; /usr/local/sbin/reboot2; echo "stub rc=$?"; sha256sum /var/lib/elden/retired/reboot2-20261127 2>/dev/null' || true
echo "[retire-reboot2] DONE"
