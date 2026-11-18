#!/bin/bash
# Flash a mainline boot image into slot b *from inside Linux* — no fastboot needed.
#
# Why: after the b-slot bring-up (HANDOFF §24) the tablet boots Linux on its own,
# and `reboot -f` returns to Linux, so the old soft-reset loop (`cycle.sh --soft`, 已删除)
# no longer exists. boot_b is a plain block device we own: sign the image with
# our AVB key (scripts/sign-boot-b.sh) and dd it.
#
# usage: scripts/flash-b.sh [in.img] [--reboot]
#        in.img 必填（旧默认 vk40 已随 out 清理删除）
set -eu
cd "$(dirname "$0")/.."
TAB=${TABLET:-root@192.168.7.1}

# --- device lock (serialize across concurrent agents; see scripts/device-lock.sh) ---
. "$(dirname "$0")/lib-device-lock.sh"
device_lock_acquire
REBOOT=0
for a in "$@"; do
	case "$a" in
		--reboot) REBOOT=1 ;;
		*) IN=$a ;;
	esac
done
[ -n "$IN" ] || { echo "usage: $0 <in.img> [--reboot]" >&2; exit 1; }

echo "[flash-b] signing $IN"
./scripts/sign-boot-b.sh "$IN" >/dev/null
SHA=$(sha256sum bootslot-b/boot_b.img | cut -d' ' -f1)
echo "[flash-b] image sha256=$SHA  (96 MiB, signed with bootslot-b/avb.key)"

# Why stream over ssh instead of scp/rsync:
#   * device sshd has no sftp-server subsystem (scp defaults to SFTP since OpenSSH 9);
#   * scp/rsync split the remote spec on the first ':' -> IPv6 link-local hosts break
#     unless bracketed. Piping through ssh sidesteps both, and never needs /tmp space.
# 2026-10-25 fix (PITFALLS #391): do NOT force `ssh -6`. The default TABLET is the
# IPv4 literal 192.168.7.1, where `-6` fails with "Address family for hostname not
# supported"; an IPv6 link-local target (root@fe80::1e:5eff:feed:e101%<iface>) still
# works without the flag, since ssh picks the family from the address itself.
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=8 -o ServerAliveInterval=15"

# P0（B 类）：写之前核对分区存在 + 装得下（dd 不检查，短写照样 rc=0）。
PSZ=$(timeout 20 ssh $SSH_OPTS "$TAB" "blockdev --getsize64 /dev/disk/by-partlabel/boot_b" 2>/dev/null | tr -dc '0-9')
ISZ=$(stat -c%s bootslot-b/boot_b.img)
echo "[flash-b] partition boot_b=${PSZ:-读不到} B ; 镜像 $ISZ B"
[ -n "${PSZ:-}" ] || { echo "[flash-b] 读不到 /dev/disk/by-partlabel/boot_b（分区名/设备不对）" >&2; exit 1; }
[ "$ISZ" -le "$PSZ" ] || { echo "[flash-b] 镜像 $ISZ B > 分区 $PSZ B，拒绝写" >&2; exit 1; }

# P0（A 类）：写 boot_b 之后如果不置 succ，重启就是扣 retry 的一发；--reboot 前先看门。
echo "[flash-b] boot_b 槽属性（写前基线）："
timeout 20 ssh $SSH_OPTS "$TAB" 'python3 /usr/local/sbin/slot-attr.py show 2>/dev/null | grep -E "^  boot_b "' || \
	echo "[flash-b] （读不到 slot-attr.py，槽属性未留档）"

echo "[flash-b] writing boot_b (streamed over ssh)..."
cat bootslot-b/boot_b.img | timeout 900 ssh $SSH_OPTS "$TAB" '
set -e
D=/dev/disk/by-partlabel/boot_b
dd of=$D bs=1M conv=fsync 2>/dev/null
sync
dd if=$D bs=1M count=96 2>/dev/null | sha256sum | cut -d" " -f1
' > /tmp/flash-b-readback.txt
RB=$(tail -1 /tmp/flash-b-readback.txt)
echo "[flash-b] readback sha256=$RB"
[ "$SHA" = "$RB" ] || { echo "[flash-b] MISMATCH — boot_b NOT updated cleanly" >&2; exit 1; }
echo "[flash-b] OK"

if [ "$REBOOT" = 1 ]; then
	# A 类兜底：重启前把 succ 置上，避免「写+重启」把 retry 一路减到 0（#181）。
	timeout 40 ssh $SSH_OPTS "$TAB" 'python3 /usr/local/sbin/slot-attr.py mark-successful b' >/dev/null 2>&1 || \
		echo "[flash-b] ⚠ 置 boot_b succ 失败（若该槽 succ=0，每次重启都在扣 retry）"
	echo "[flash-b] rebooting..."
	# ★ 2026-10-15 修（PITFALLS #288）：原用 `(sleep 1; reboot -f) &`，
	# 实测在本机当前状态下【会挂起、根本不重启】——`/sbin/reboot` 是 elden-powerwrap，
	# openrc 分支 `exec /bin/busybox reboot`；该路径与 `busybox reboot -f` 均实测挂起。
	# `sysrq-b` 是当前唯一可靠通道（实测 uptime 归零 + boot_id 换新）。
	timeout 30 ssh $SSH_OPTS "$TAB" 'sync; echo b > /proc/sysrq-trigger' || true
	echo "[flash-b] waiting for Linux..."
	# 2026-11-05：lib-wait 换代判据（旧实现只测 ping+ssh，重启前旧系统仍在答 ⇒ 会立刻"成功"）
	. "$(dirname "$0")/lib-wait.sh"
	wait_reboot wa_ssh_alive 180 && echo "[flash-b] up" || echo "[flash-b] 等待超时（继续做版本读取，失败即暴露）"
	timeout 15 ssh $SSH_OPTS "$TAB" 'cat /proc/version' || true
fi
