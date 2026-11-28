#!/bin/sh
# deploy-iio-sensor-proxy-patches.sh — install / verify / roll back the patched
# iio-sensor-proxy 3.9 (elden patches 0001 Claim deferral + 0002 light rate limit
# + 0003 median/EMA smoothing).
#
# Runs ON THE DEVICE (elden, Debian trixie arm64). Copy it and the .deb over first:
#   scp patches-userland/iio-sensor-proxy-20261128/artifacts/iio-sensor-proxy_3.9-3elden_arm64.deb \
#       scripts/deploy-iio-sensor-proxy-patches.sh root@elden:/root/
# then, on the device:
#   sh /root/deploy-iio-sensor-proxy-patches.sh --check            # read-only, no root needed
#   sh /root/deploy-iio-sensor-proxy-patches.sh --apply             # needs root + CONFIRM=yes
#   sh /root/deploy-iio-sensor-proxy-patches.sh --rollback          # back to 3.9-1
# Options: --deb <path> (default /root/iio-sensor-proxy_3.9-3elden_arm64.deb),
#          --expect-sha256 <hex> (refuse to install a different file).
#
# Package versions: this script installs 3.9-3elden and rolls back to the distro
# 3.9-1. The intermediate local build 3.9-2elden (0002 only, i.e. rate limit
# without the 0003 smoothing) can be skipped: 3.9-3elden is a plain superset of
# 0001+0002 and dpkg installs it straight over 3.9-1 or over 3.9-2elden.
#
# Modes
#   --check     read-only self-test: architecture, package state, running binary,
#               backend bits, and the "before" criteria from
#               reports/sensors-orientation-als-20261128.md §3.3. Writes nothing.
#   --apply     dpkg -i the patched deb, then restart the proxy (the restart is what
#               re-runs discovery; patch 0001 makes the client claim that races with it
#               stick). Takes the device lock if scripts/device-lock.sh is present.
#   --rollback  apt-get install --reinstall iio-sensor-proxy=3.9-1 + restart.
#
# Safety: aborts unless /etc/debian_version or dpkg says trixie-ish, aborts on non-aarch64,
# snapshots /var/lib/dpkg/status and `dpkg -l iio-sensor-proxy` before touching anything,
# and never edits udev rules, the unit or the polkit policy (they are byte-identical to
# the ones the distro package already installed).
set -eu

DEB=/root/iio-sensor-proxy_3.9-3elden_arm64.deb
EXPECT_SHA256=${EXPECT_SHA256:-}
MODE=
TARGET_VERSION=3.9-3elden
BASE_VERSION=3.9-1
BIN=/usr/libexec/iio-sensor-proxy

usage () {
	sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
}

while [ $# -gt 0 ]; do
	case "$1" in
	--check) MODE=check ;;
	--apply) MODE=apply ;;
	--rollback) MODE=rollback ;;
	--deb) shift; DEB=${1:?--deb needs a path} ;;
	--expect-sha256) shift; EXPECT_SHA256=${1:?--expect-sha256 needs a digest} ;;
	-h|--help) usage ;;
	*) echo "unknown option: $1" >&2; usage ;;
	esac
	shift
done
[ -n "$MODE" ] || usage

say () { printf '%s\n' "$*"; }
hdr () { printf '\n== %s\n' "$*"; }
have () { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- read-only bits
pkg_version () { dpkg-query -W -f='${Version}' "$1" 2>/dev/null || echo "absent"; }

show_state () {
	hdr "package / binary state"
	say "iio-sensor-proxy installed : $(pkg_version iio-sensor-proxy)"
	say "libssc2                    : $(pkg_version libssc2)"
	say "libglib2.0-0t64            : $(pkg_version libglib2.0-0t64)"
	say "libgudev-1.0-0             : $(pkg_version libgudev-1.0-0)"
	say "libpolkit-gobject-1-0      : $(pkg_version libpolkit-gobject-1-0)"
	if [ -r "$BIN" ]; then
		say "binary sha256              : $(sha256sum "$BIN" | cut -d' ' -f1)"
	else
		say "binary sha256              : $BIN missing"
	fi
	if [ -r "$BIN" ] && have objdump; then
		say "binaries NEEDED            : $(objdump -p "$BIN" | awk '/NEEDED/{printf "%s ", $2}')"
		say "binary max GLIBC symbol    : $(objdump -T "$BIN" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)"
	fi
	say "glibc (ldd)                : $(ldd --version 2>/dev/null | head -1)"
	say "proxy unit active          : $(systemctl is-active iio-sensor-proxy 2>/dev/null || echo unknown)"
	say "backend strings in binary  : $(for s in ssc-light ssc-accel ssc-proximity ssc-compass; do
		strings -a "$BIN" 2>/dev/null | grep -qx "$s" && printf '%s ' "$s"; done)"
	# 0003 tags every report with its cause ("first reading"/"step"/"hysteresis"/"stale"),
	# so the journal says why a level went out.
	say "smoothing (0003) in binary  : $(strings -a "$BIN" 2>/dev/null | grep -q '(%s)' &&
		strings -a "$BIN" 2>/dev/null | grep -q 'hysteresis' && echo present || echo absent)"
}

show_criteria () {
	hdr "criteria from reports/sensors-orientation-als-20261128.md §3.3 (read-only)"
	if have journalctl; then
		say "ClaimLight/ClaimAccelerometer since boot : $(journalctl -u iio-sensor-proxy -b --no-pager 2>/dev/null | grep -cE 'ClaimLight|ClaimAccelerometer' || true)"
		say "'already claimed ... no-op' since boot    : $(journalctl -u iio-sensor-proxy -b --no-pager 2>/dev/null | grep -c 'already claimed device, no-op' || true)"
		say "'Enabling sensor' since boot              : $(journalctl -u iio-sensor-proxy -b --no-pager 2>/dev/null | grep -c 'Enabling sensor' || true)"
		say "'Emitted light changed' last 60 s         : $(journalctl -u iio-sensor-proxy --since '-1min' --no-pager 2>/dev/null | grep -c 'Emitted light changed' || true)"
		say "'Turning deferred claim' since boot        : $(journalctl -u iio-sensor-proxy -b --no-pager 2>/dev/null | grep -c 'Turning deferred claim' || true)"
	else
		say "journalctl not available"
	fi
	if have busctl; then
		say "HasAmbientLight            : $(busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAmbientLight 2>/dev/null || echo 'n/a')"
		say "LightLevel                 : $(busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy LightLevel 2>/dev/null || echo 'n/a')"
		say "LightLevelUnit             : $(busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy LightLevelUnit 2>/dev/null || echo 'n/a')"
	else
		say "busctl not available"
	fi
	say ""
	say "backlight writes over 60 s (100 ms sampling, needs the ALS to be running):"
	if [ -w /sys/class/backlight/aw99706-backlight/brightness ] || [ -r /sys/class/backlight/aw99706-backlight/brightness ]; then
		say "  b0=\$(cat /sys/class/backlight/aw99706-backlight/brightness); n=0"
		say "  for i in \$(seq 600); do b=\$(cat /sys/class/backlight/aw99706-backlight/brightness)"
		say "    [ \"\$b\" != \"\$b0\" ] && { n=\$((n+1)); b0=\$b; }; sleep 0.1; done; echo writes=\$n"
		say "  target: <= 2 writes, <= 6 'Emitted light changed' reports per minute"
	else
		say "  /sys/class/backlight/aw99706-backlight/brightness not readable"
	fi
}

check_deb () {
	hdr "candidate package"
	if [ ! -f "$DEB" ]; then
		say "!! missing: $DEB (scp it first, or pass --deb <path>)"
		return 1
	fi
	say "file      : $DEB"
	say "size      : $(wc -c <"$DEB") bytes"
	say "sha256    : $(sha256sum "$DEB" | cut -d' ' -f1)"
	if [ -n "$EXPECT_SHA256" ]; then
		got=$(sha256sum "$DEB" | cut -d' ' -f1)
		if [ "$got" = "$EXPECT_SHA256" ]; then
			say "sha256    : matches --expect-sha256"
		else
			say "!! sha256 mismatch: expected $EXPECT_SHA256"
			return 1
		fi
	fi
	have dpkg-deb || { say "!! dpkg-deb not available"; return 1; }
	say "Package   : $(dpkg-deb -f "$DEB" Package)"
	say "Version   : $(dpkg-deb -f "$DEB" Version)"
	say "Arch      : $(dpkg-deb -f "$DEB" Architecture)"
	say "Depends   : $(dpkg-deb -f "$DEB" Depends)"
	return 0
}

guard_arch () {
	arch=$(uname -m)
	if [ "$arch" != "aarch64" ] && [ "$arch" != "arm64" ]; then
		say "!! this script must run on the device (aarch64); this host is $arch" >&2
		say "   the host-side, read-only variant is: bash patches-userland/iio-sensor-proxy-20261128/build-arm64-deb.sh" >&2
		exit 3
	fi
	if ! have dpkg-query; then
		say "!! dpkg-query missing: not a Debian system?" >&2
		exit 3
	fi
}

# ---------------------------------------------------------------- write paths
snapshot () {
	dir=/root/iio-sensor-proxy-backup-$(date +%Y%m%d-%H%M%S)
	mkdir -p "$dir"
	dpkg -l >"$dir/dpkg-l.txt" 2>&1 || true
	cp -a /var/lib/dpkg/status "$dir/dpkg-status.txt" 2>/dev/null || true
	dpkg-query -W -f='${Package} ${Version}\n' >"$dir/versions.txt" 2>/dev/null || true
	[ -r "$BIN" ] && cp -a "$BIN" "$dir/iio-sensor-proxy.old" || true
	say "snapshot: $dir"
}

restart_proxy () {
	if systemctl is-active iio-sensor-proxy >/dev/null 2>&1 ||
	   systemctl is-enabled iio-sensor-proxy >/dev/null 2>&1; then
		say "restarting iio-sensor-proxy ..."
		systemctl restart iio-sensor-proxy
		sleep 2
		say "active: $(systemctl is-active iio-sensor-proxy)"
	else
		say "!! iio-sensor-proxy unit not enabled/active, not starting it"
	fi
}

do_apply () {
	[ "$(id -u)" = 0 ] || { say "!! --apply needs root" >&2; exit 4; }
	[ "${CONFIRM:-}" = yes ] || {
		say "!! refusing to install without CONFIRM=yes (this restarts the sensor proxy)" >&2
		exit 4
	}
	guard_arch
	check_deb || { say "!! candidate package unusable, aborting" >&2; exit 5; }
	snapshot
	hdr "dpkg -i"
	dpkg -i "$DEB"
	restart_proxy
	hdr "post-install state"
	show_state
	show_criteria
	say ""
	say "rollback if needed: sh $0 --rollback"
}

do_rollback () {
	[ "$(id -u)" = 0 ] || { say "!! --rollback needs root" >&2; exit 4; }
	guard_arch
	snapshot
	hdr "apt-get install --reinstall iio-sensor-proxy=$BASE_VERSION"
	DEBIAN_FRONTEND=noninteractive apt-get install -y --reinstall "iio-sensor-proxy=$BASE_VERSION"
	apt-mark hold iio-sensor-proxy >/dev/null 2>&1 || true
	restart_proxy
	hdr "post-rollback state"
	show_state
	say ""
	say "note: apt-mark hold iio-sensor-proxy re-applied so that an apt upgrade"
	say "      cannot pull the package back to a different version."
}

case "$MODE" in
check)
	guard_arch
	say "== read-only self-test (nothing is modified)"
	show_state
	check_deb || say "(no usable candidate .deb; --apply would abort)"
	show_criteria
	say ""
	say "== verdict: read-only checks done; --apply still requires root + CONFIRM=yes"
	;;
apply) do_apply ;;
rollback) do_rollback ;;
esac
