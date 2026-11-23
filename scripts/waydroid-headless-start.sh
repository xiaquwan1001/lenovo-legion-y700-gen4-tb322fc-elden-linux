#!/bin/bash
# ★ 场景限定头注（2026-11-23，D5 批 4 / reports/scripts-hardening-4-20261123.md §2）：**保留 + 本头注，不归档**。
#   ✔ 只在「Q28 坏发、无 phoc/phosh、无合成器」时用（2026-10-18 实测可行，证据 .pi/memory/notes-camera-waydroid.md:62）。
#   ✘ **正常态起会话不要用它**：headless weston = 空合成器错路（scripts/waydroid-cam-restart.sh:3-5，2026-10-19 判定）；
#     正常态一律用 `scripts/waydroid-cam-restart.sh`。
#   ⚠ 已知局限（未改，改=行为变更，超本轮范围）：① 内联 ssh 不走 `scripts/lib-ssh.sh`（无统一超时/重试口径）；
#     ② `XDG_RUNTIME_DIR=/run/user/0` 写死（非默认用户口径）；③ 不 source lib-device-lock。
#
# Start Waydroid headless: headless weston + waydroid session + container.
# For Q28-bad boots where no compositor/display is available.
set -u
T=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 $T"

timeout 60 $SSH 'pkill -x weston 2>/dev/null; mkdir -p /run/user/0; chmod 700 /run/user/0; true' || true

timeout 60 $SSH 'XDG_RUNTIME_DIR=/run/user/0 nohup weston --backend=headless-backend.so --socket=wayland-0 --idle-time=0 >/tmp/weston.log 2>&1 & sleep 4; ls /run/user/0/ | tr "\n" " "' || true
echo

timeout 90 $SSH 'export XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY=wayland-0; nohup dbus-run-session -- waydroid session start >/tmp/wd-session2.log 2>&1 & sleep 30; waydroid status 2>&1 | head -4; echo ---; tail -6 /tmp/wd-session2.log' || true
