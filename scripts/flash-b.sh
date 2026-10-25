#!/bin/bash
# Flash a mainline boot image into slot b *from inside Linux* — no fastboot needed.
#
# Why: after the b-slot bring-up (HANDOFF §24) the tablet boots Linux on its own,
# and `reboot -f` returns to Linux, so the old `cycle.sh --soft` -> fastboot loop
# no longer exists. boot_b is a plain block device we own: sign the image with
# our AVB key (scripts/sign-boot-b.sh) and dd it.
#
# usage: scripts/flash-b.sh [in.img] [--reboot]
#        default in.img = out/boot-elden-vk40.img
set -eu
cd "$(dirname "$0")/.."
TAB=${TABLET:-root@192.168.7.1}

# --- device lock (serialize across concurrent agents; see scripts/device-lock.sh) ---
. "$(dirname "$0")/lib-device-lock.sh"
device_lock_acquire
REBOOT=0
IN=out/boot-elden-vk40.img
for a in "$@"; do
	case "$a" in
		--reboot) REBOOT=1 ;;
		*) IN=$a ;;
	esac
done

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
	echo "[flash-b] rebooting..."
	# ★ 2026-10-15 修（PITFALLS #288）：原用 `(sleep 1; reboot -f) &`，
	# 实测在本机当前状态下【会挂起、根本不重启】——`/sbin/reboot` 是 elden-powerwrap，
	# openrc 分支 `exec /bin/busybox reboot`；该路径与 `busybox reboot -f` 均实测挂起。
	# `sysrq-b` 是当前唯一可靠通道（实测 uptime 归零 + boot_id 换新）。
	timeout 30 ssh $SSH_OPTS "$TAB" 'sync; echo b > /proc/sysrq-trigger' || true
	echo "[flash-b] waiting for Linux..."
	for i in $(seq 1 90); do
		sleep 2
		ping -c1 -W1 192.168.7.1 >/dev/null 2>&1 && timeout 8 ssh $SSH_OPTS \
			"$TAB" 'uptime' 2>/dev/null && { echo "[flash-b] up (~$((i*2))s)"; break; }
	done
	timeout 15 ssh $SSH_OPTS "$TAB" 'cat /proc/version' || true
fi
