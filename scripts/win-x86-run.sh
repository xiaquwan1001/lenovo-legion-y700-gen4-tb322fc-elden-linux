#!/bin/bash
# win-x86-run.sh — 在设备 glibc-rootfs chroot 内运行 Win-x86（Box64+Wine）命令
# 自带 fork 风暴防护（cgroup v2 pids 上限 + 超时 + cgroup 全清）。
#
# 用法（设备上以 root 运行）：
#   win-x86-run.sh [秒数] <命令...>
# 例：
#   win-x86-run.sh 120 wine64 cmd /c echo hello
#   win-x86-run.sh 180 wine64 notepad.exe
#
# 环境变量：
#   WINE_ROOTFS   默认 /root/glibc-rootfs
#   WINE_PID_CAP  默认 150（cgroup pids.max）
#   WINE_ISOLATE  设 1 时用独立前缀 ~/.wine-poc 并先清空
#   WINEDEBUG     默认 -all
set -u
R=${WINE_ROOTFS:-/root/glibc-rootfs}
SECS=${1:-120}; shift || true
[ "$#" -ge 1 ] || { echo "usage: $0 [secs] <cmd...>" >&2; exit 2; }

# 1) bind-mount 设备节点与临时 fs（幂等）
for m in /dev /proc /sys /dev/shm /dev/pts /run; do
  [ -d "$R$m" ] || mkdir -p "$R$m"
  mountpoint -q "$R$m" 2>/dev/null || mount --bind "$m" "$R$m" 2>/dev/null || true
done
[ -f /etc/resolv.conf ] && cp -f /etc/resolv.conf "$R/etc/resolv.conf" 2>/dev/null || true

# 2) cgroup v2 pids 上限（防 fork 风暴打爆设备）
CAP=${WINE_PID_CAP:-150}
GUARD=/sys/fs/cgroup/wineguard
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
  mkdir -p "$GUARD"
  grep -qw pids /sys/fs/cgroup/cgroup.controllers && \
    echo "+pids" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true
  echo "$CAP" > "$GUARD/pids.max" 2>/dev/null || true
fi

cleanup() {
  # 把残留的 wine/box64 全部清掉，并从 cgroup 移除
  for p in wineserver64 wineserver32 wine64 wine32 wine explorer.exe services.exe wineboot winedevice.exe plugplay.exe svchost.exe rpcss.exe box64; do
    pkill -9 -x "$p" 2>/dev/null || true
  done
  for p in $(cat "$GUARD/cgroup.procs" 2>/dev/null); do kill -9 "$p" 2>/dev/null || true; done
}
trap cleanup EXIT

# 3) 运行（在 chroot 内，先把 shell 放进受限 cgroup，再 exec）
WAITPID=
timeout -k 5 "$SECS" chroot "$R" /bin/bash -lc '
  if [ -w /sys/fs/cgroup/wineguard/cgroup.procs ]; then
    echo $$ > /sys/fs/cgroup/wineguard/cgroup.procs 2>/dev/null || true
  fi
  export HOME=/root BOX64_NOBANNER=1
  export BOX64_DYNAREC_BIGBLOCK=3 BOX64_DYNACACHE=1 BOX64_AVX=2 BOX64_LOG="${BOX64_LOG:-0}"
  export WINEDLLOVERRIDES="mscoree,mshtml="
  export WINEDEBUG="${WINEDEBUG:--all}"
  if [ "${WINE_ISOLATE:-0}" = "1" ]; then
    export WINEPREFIX=/root/.wine-poc
  fi
  exec "$@"
' _ "$@"
rc=$?
echo "run rc=$rc"
exit $rc
