#!/bin/bash
# waydroid-cam-restart.sh — restart the Waydroid stack after a vendor.img swap.
#
# ★ 2026-10-19 重要更正：默认**用真实桌面会话**（session user 的 phoc），不要用 headless weston。
#   旧版固定跑 `XDG_RUNTIME_DIR=/run/user/0` + headless weston ⇒ session 挂在**没有界面的空合成器**上，
#   容器里 app 进程能起但窗口无处显示 ⇒ 用户看到的现象就是「容器无法调起图形化界面、进程拉不起」。
#   只有 Q28 坏发（没有 phoc/面板）时才该退回 headless，用 MODE=headless 显式指定。
#
# 用法：
#   scripts/waydroid-cam-restart.sh              # 真实桌面（默认，推荐）
#   MODE=headless scripts/waydroid-cam-restart.sh # 无桌面时（Q28 坏发）的应急路径
#
# 注意（踩过的坑）：
#   - `waydroid container start` **不会**启 lxc，它只是 DBus 常驻服务；容器由 `waydroid session start`
#     通过 dbus 请求 container manager 拉起。所以顺序必须是 container(服务) → session。
#   - 被 kill 后 dbus system bus 上会残留 `id.waydro.Container` 名，后续启动静默报
#     "Container service is already running" 且 lxc 仍是 STOPPED ⇒ 必须 pkill -9 容器服务进程。
#   - 容器无 UI 客户端连接时 Waydroid 会主动 `lxc-freeze`（省电）⇒ `waydroid status` 显示 FROZEN
#     是**正常行为**，不是故障；起 session/app 就会解冻。
set -u
T=${TAB:-root@192.168.7.1}
MODE=${MODE:-desktop}
# SSH 必须**先于** detect_sess() 定义：2026-10-29 lane L1d 修（旧版把它放在 detect_sess 之后，
# detect_sess 里 `$SSH` 未绑定 ⇒ `set -u` 直接报 "SSH: 未绑定的变量"）。
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 $T"
# 桌面会话用户：**从设备自动检测**（2026-10-28 lane L1d 修）
#   旧版写死 xuqianhui1001/1000，且 desktop 分支用 `setsid sudo -u`，而 Debian 根**没有 sudo**
#   ⇒ `setsid: failed to execute sudo: No such file or directory`（PITFALLS #459 同类坑）。
#   现在：环境变量 SESS_USER/SESS_UID 若已给则复用；否则按「谁拥有 /run/user/*/wayland-0」检测；
#   再否则退回「/home 下唯一用户」。privilege 切换用 runuser（Debian root 自带），无 sudo 也行。
detect_sess() {
  local rt u id
  for rt in $(timeout 20 $SSH 'ls -d /run/user/*/wayland-0 2>/dev/null' 2>/dev/null); do
    id=${rt#/run/user/}; id=${id%%/*}
    u=$(timeout 20 $SSH "getent passwd $id 2>/dev/null | cut -d: -f1" 2>/dev/null)
    [ -n "$u" ] && { echo "$u $id"; return 0; }
  done
  u=$(timeout 20 $SSH 'for d in /home/*; do [ -d "$d" ] && basename "$d"; done | head -1' 2>/dev/null)
  [ -n "$u" ] || return 1
  id=$(timeout 20 $SSH "id -u $u 2>/dev/null" 2>/dev/null)
  [ -n "$id" ] && echo "$u $id"
}
if [ -z "${SESS_USER:-}" ] || [ -z "${SESS_UID:-}" ]; then
  if got=$(detect_sess) && [ -n "$got" ]; then
    set -- $got
    SESS_USER=${SESS_USER:-$1}
    SESS_UID=${SESS_UID:-$2}
  fi
fi
SESS_USER=${SESS_USER:-xuqianhui1001}
SESS_UID=${SESS_UID:-$(id -u "$SESS_USER" 2>/dev/null || echo 1000)}
# 会话内提权：优先 sudo（若有），否则 runuser（Debian root 自带）
if timeout 20 $SSH 'command -v sudo >/dev/null 2>&1' 2>/dev/null; then RUNAS="sudo -u"; else RUNAS="runuser -u"; fi
echo "  会话用户 = $SESS_USER (uid $SESS_UID), 提权方式 = $RUNAS"

echo "== [1/3] 停旧栈（container 服务的 dbus 名必须一起清掉）"
timeout 120 $SSH 'lxc-stop -P /var/lib/waydroid/lxc -n waydroid -k >/dev/null 2>&1
  for p in $(pgrep -f "waydroid sess[i]on start") $(pgrep -f "waydroid containe[r] start") $(pgrep -f "dbus-run-sessio[n] -- waydroid"); do kill -9 $p 2>/dev/null; done
  sleep 2; lxc-ls -P /var/lib/waydroid/lxc 2>/dev/null' || true

echo "== [2/3] 起 container 服务（MODE=$MODE）"
# PITFALLS #465：宿主带着 `androidboot.mode=charger` 重启时（插 USB），容器 init 会变成
# `ro.bootmode=charger` ⇒ 只跑 `on charger`，没有 vold/zygote ⇒ 只有 15 个进程、没有
# `media.camera` 服务。这里先重建 `/run/fake-cmdline`（tmpfs，重启即丢）+ 确保 lxc bind
# 在位；幂等，无需 charger 时自动跳过。
if [ -f "$(dirname "$0")/waydroid-cmdline-fix.sh" ]; then
  bash "$(dirname "$0")/waydroid-cmdline-fix.sh" 2>&1 | tail -4
fi
timeout 90 $SSH "MODE='$MODE' SESS_USER='$SESS_USER' SESS_UID='$SESS_UID' bash -s" <<'EOS'
set -u
if [ "$MODE" = headless ]; then
  # 应急：无桌面时用 headless weston（注意：这样容器 app 没有可见窗口）
  mkdir -p /run/user/0; chmod 700 /run/user/0
  pgrep -x weston >/dev/null || (XDG_RUNTIME_DIR=/run/user/0 nohup weston \
    --backend=headless-backend.so --socket=wayland-0 --idle-time=0 >/tmp/weston.log 2>&1 & sleep 4)
fi
nohup waydroid container start >/tmp/wdcm.log 2>&1 &
sleep 6
EOS

echo "== [3/3] 起 session"
if [ "$MODE" = headless ]; then
  timeout 240 $SSH 'export XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY=wayland-0
    nohup dbus-run-session -- waydroid session start >/tmp/wd-session.log 2>&1 &
    for i in $(seq 1 40); do sleep 5; out=$(waydroid status 2>&1 | head -3); echo "$out" | grep -q "Container:.*RUNNING" && break; done
    echo "$out"' || true
else
  # 真实桌面：借用 phoc 的 wayland-0 与它的 session bus（否则 gsettings/dbus 全是空的）
  timeout 300 $SSH "SESS_USER='$SESS_USER' SESS_UID='$SESS_UID' RUNAS='$RUNAS' bash -s" <<'EOS'
set -u
# 远端兜底：宿主判定的 RUNAS 透传为空时，在设备上自己判一次（Debian 根无 sudo）
[ -n "${RUNAS:-}" ] || { command -v sudo >/dev/null 2>&1 && RUNAS="sudo -u" || RUNAS="runuser -u"; }
RT=/run/user/$SESS_UID
[ -S "$RT/wayland-0" ] || { echo "FAIL: $RT/wayland-0 不存在（phoc 没起？用 MODE=headless）"; exit 1; }
# 从会话用户任一进程的 environ 里取 DBUS_SESSION_BUS_ADDRESS（竞态：先判可读再读，见 cam-mode.sh 注释）
SB=$(for p in $(pgrep -u "$SESS_UID" | head -40); do ( tr '\0' '\n' < "/proc/$p/environ" ) 2>/dev/null \
     | grep -m1 '^DBUS_SESSION_BUS_ADDRESS='; done | head -1 | cut -d= -f2-)
echo "  DBUS_SESSION_BUS_ADDRESS=${SB:-<empty>}"
setsid $RUNAS "$SESS_USER" env HOME="/home/$SESS_USER" XDG_RUNTIME_DIR="$RT" WAYLAND_DISPLAY=wayland-0 \
  DBUS_SESSION_BUS_ADDRESS="$SB" waydroid session start >/tmp/wd-session.log 2>&1 < /dev/null &
for i in $(seq 1 40); do sleep 5; out=$(waydroid status 2>&1 | head -6)
  echo "$out" | grep -q "Container:.*RUNNING" && break; done
echo "$out"
EOS
fi
