#!/bin/bash
# g3-steam: launch the native ARM64 Steam client inside a nested weston
# (Wayland backend, hosted by phoc) so its X11 UI lands on the real device
# display, and we can prove the window exists + screenshot it with grim.
#
# usage: run-steam.sh <seconds>
set -u
SECS=${1:-180}
export HOME=/root/steam-home
STEAM="$HOME/.local/share/Steam"
RT=/tmp/g3-steam/rt
LOG=/tmp/g3-steam
mkdir -p "$RT" "$LOG"
chmod 700 "$RT"

# --- clean any leftovers from a previous attempt (by exact comm) ---
for p in steam steamwebhelper steamerrorreporter steam-runtime-l /usr/bin/steam weston Xwayland; do
	pkill -9 -x "${p##*/}" 2>/dev/null || true
done
sleep 1

# --- nested compositor: weston as a Wayland client of phoc ---
XDG_RUNTIME_DIR=$RT WAYLAND_DISPLAY=/run/user/1001/wayland-0 \
	weston --backend=wayland --socket=wl-g3 --xwayland \
	--width=1280 --height=800 --idle-time=0 \
	>/tmp/g3-steam/weston.log 2>&1 &
WESTON=$!
for i in $(seq 1 40); do
	[ -S "$RT/wl-g3" ] && [ -S "$RT/.X11-unix/X0" ] && break
	sleep 0.25
done
echo "weston pid=$WESTON socket=$(ls $RT | tr '\n' ' ')"
export DISPLAY=:0
XAUTHORITY=$(ls "$RT"/.mutter-Xwaylandauth* "$RT"/.Xauthority 2>/dev/null | head -1)
[ -n "${XAUTHORITY:-}" ] && export XAUTHORITY

# --- Steam (native ARM64, steamrtarm64 seed) ---
export LD_LIBRARY_PATH="$STEAM/steamrtarm64:$STEAM/lib/aarch64-linux-gnu"
export STEAM_RUNTIME=0
timeout -k 5 "$SECS" "$STEAM/steamrtarm64/steam" \
	-noreactlog -console \
	>/tmp/g3-steam/steam.stdout 2>/tmp/g3-steam/steam.stderr &
SPID=$!
echo "steam wrapper pid=$SPID"

sleep 20
xwininfo -root -tree > /tmp/g3-steam/xwininfo.txt 2>&1
xdotool search --name "" getwindowname %@ 2>/dev/null | head -20 > /tmp/g3-steam/windownames.txt
pgrep -af "steam" | head -20 > /tmp/g3-steam/procs-20s.txt
wait $SPID
echo "steam rc=$?"
pgrep -af "steam" | head -20 > /tmp/g3-steam/procs-end.txt
