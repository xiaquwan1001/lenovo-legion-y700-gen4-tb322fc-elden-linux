#!/bin/bash
# g3-steam: launch native ARM64 Steam against a LOCAL package feed.
#
# Why local feed: on this network the Steam CDN (fastly) is reachable over IPv6
# but NOT over IPv4 (curl -4 → 000, curl -6 → 200), and Steam's updater picks
# the IPv4 path → "Download failed: http error 0 / Steam needs to be online to
# update". All 63 packages were already fetched + sha256-verified by fetch.py,
# so we serve them from 127.0.0.1 exactly like the armadaos reference does
# (-overridepackageurl). Steam still shows the normal login UI afterwards.
#
# usage: steam-up.sh <seconds>
set -u
SECS=${1:-240}
export HOME=/root/steam-home
STEAM="$HOME/.local/share/Steam"
export XDG_RUNTIME_DIR=/tmp/g3-steam/rt
export WAYLAND_DISPLAY=/run/user/1001/wayland-0
export DISPLAY=:0
export LD_LIBRARY_PATH="$STEAM/steamrtarm64:$STEAM/lib/aarch64-linux-gnu"
export STEAM_RUNTIME=0
L=/tmp/g3-steam
FEED=/root/g3-steam/work/feed

# local package feed
pgrep -f "http.server 8080" >/dev/null || {
	nohup python3 -m http.server 8080 --bind 127.0.0.1 --directory "$FEED" \
		>"$L/feed.log" 2>&1 &
	for i in $(seq 1 40); do
		curl -fsS -o /dev/null http://127.0.0.1:8080/ 2>/dev/null && break
		sleep 0.25
	done
}
curl -fsS -o /dev/null http://127.0.0.1:8080/ && echo "feed up on 127.0.0.1:8080"

: > "$L/steam.stdout"; : > "$L/steam.stderr"
timeout -k 10 "$SECS" "$STEAM/steamrtarm64/steam" \
	-overridepackageurl http://127.0.0.1:8080 \
	-noreactlog -console \
	>"$L/steam.stdout" 2>"$L/steam.stderr" &
SPID=$!
echo "steam pid=$SPID start=$(date -u +%FT%TZ)"
echo $SPID > "$L/steam.pid"
wait $SPID
echo "steam exit rc=$? at $(date -u +%FT%TZ)"
