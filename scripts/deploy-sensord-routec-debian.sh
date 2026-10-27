#!/bin/bash
# deploy-sensord-routec-debian.sh — 在 **Debian/glibc 根**上安装路线 C 的 Waydroid sensor HAL
# （`patches-userland/waydroid-sensord-udp/`），并补齐数据源（ssccli）。
#
# 为什么需要这个脚本（2026-10-27 实测，PITFALLS #431）：
#   Alpine 根上的 `/usr/local/bin/waydroid-sensord` 是 **musl 动态**件
#   （interpreter `/lib/ld-musl-aarch64.so.1`）。搬到 glibc 根后 `which` 仍然命中
#   ⇒ Waydroid `container_manager.py` 以为有 HAL、`images.py` 也不再设
#   `waydroid.stub_sensors_hal`，但那个文件**根本 exec 不起来**（ENOENT，报错文案不提 loader）⇒
#   `android.hardware.sensors@1.0::ISensors/default` 无人注册 ⇒ `sensorservice`
#   每秒重试 ⇒ Android 永远停在 bootanimation。修法 = 用 glibc 重编同一份源码。
#
# 产物来源（优先顺序）：
#   1. `out/sensord-host/waydroid-sensord-udp` —— 主机 arm64 chroot 产物
#      （`sudo bash scripts/host-arm64-chroot.sh --build-sensord`；**可重现，目标根不留 dev 包**）
#   2. 目标根就地 `make`（需要 libgbinder-dev/libglibutil-dev/libglib2.0-dev/g++/make/pkg-config）
#
# 数据源：`ssccli` 在 Debian 的 **libssc-bin** 包里（`libssc2` 只有库，没有 CLI）⇒
#   少了它 `ssc-udp-relay` 会 `FATAL: ssccli not found` 每 5 s 退一次。
#
# 用法：
#   bash scripts/deploy-sensord-routec-debian.sh                  # 默认 TARGET=root@192.168.7.1
#   SKIP_BUILD=1 bash scripts/deploy-sensord-routec-debian.sh     # 只用设备上已有的 /root/sensord-routeC 产物
#   HOST_ART=/path/to/binary bash scripts/deploy-sensord-routec-debian.sh
#
# 回退：设备上 `mv /usr/local/bin/waydroid-sensord{.musl.bak,}` 或删掉该文件 ——
#       Waydroid 下次起容器会回退到 stub HAL（无传感器，但能开机）。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET=${TARGET:-root@192.168.7.1}
SSH_OPTS=${SSH_OPTS:--o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}
SRC=$ROOT/patches-userland/waydroid-sensord-udp
SKIP_BUILD=${SKIP_BUILD:-0}
HOST_ART=${HOST_ART:-$ROOT/out/sensord-host/waydroid-sensord-udp}

say() { printf '[sensord-debian] %s\n' "$*"; }
# shellcheck disable=SC2086
rsh() { ssh $SSH_OPTS "$TARGET" "$@"; }

say "1/4 装运行时/构建依赖（幂等；已在则秒过）"
rsh 'DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
	libgbinder-dev libglibutil-dev libglib2.0-dev g++ make pkg-config libssc-bin 2>&1 | tail -3'

say "2/4 取得 glibc 产物"
if [ "$SKIP_BUILD" = 1 ]; then
	say "  SKIP_BUILD=1 ⇒ 期望设备上已有 /root/sensord-routeC/waydroid-sensord-udp"
	rsh 'test -x /root/sensord-routeC/waydroid-sensord-udp' || { say "  缺产物，退出"; exit 1; }
elif [ -x "$HOST_ART" ]; then
	say "  用主机 chroot 产物：$HOST_ART"
	# shellcheck disable=SC2086
	scp -q $SSH_OPTS "$HOST_ART" "$TARGET:/usr/local/bin/.waydroid-sensord.new" || { say "scp 失败"; exit 1; }
else
	say "  无主机产物 ⇒ 同步源码到 /root/sensord-routeC 并就地编译"
	# shellcheck disable=SC2086
	tar -C "$SRC" -cf - Makefile SensorFW.cpp SensorFW.h Sensors.cpp Sensors.h \
		hybrisbindertypes.h service.cpp \
		| rsh 'rm -rf /root/sensord-routeC && mkdir -p /root/sensord-routeC && tar -C /root/sensord-routeC -xf - && echo synced' \
		|| { say "同步失败"; exit 1; }
	rsh 'cd /root/sensord-routeC && make 2>&1 | grep -E "error|Error" ; test -x waydroid-sensord-udp && echo BUILD-OK' \
		|| { say "编译失败"; exit 1; }
fi

say "3/4 安装（旧 musl 件改名留档）+ 校验"
rsh 'set -e
	if [ ! -x /usr/local/bin/.waydroid-sensord.new ]; then
		install -m 0755 /root/sensord-routeC/waydroid-sensord-udp /usr/local/bin/.waydroid-sensord.new
	fi
	if [ -e /usr/local/bin/waydroid-sensord ] && [ ! -e /usr/local/bin/waydroid-sensord.musl.bak ]; then
		mv /usr/local/bin/waydroid-sensord /usr/local/bin/waydroid-sensord.musl.bak
	fi
	mv -f /usr/local/bin/.waydroid-sensord.new /usr/local/bin/waydroid-sensord
	ldd /usr/local/bin/waydroid-sensord | grep -q "libc.so.6" && echo INSTALL-OK
	sha256sum /usr/local/bin/waydroid-sensord' || { say "安装失败"; exit 1; }

say "4/4 重启 relay + 容器/session（HAL 由 Waydroid 自己拉起）"
rsh 'systemctl restart ssc-udp-relay.service
	systemctl restart waydroid-container.service
	sleep 10
	su xuqianhui1001 -c "XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
		DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus HOME=/home/xuqianhui1001 \
		setsid waydroid session start >/home/xuqianhui1001/wd-session.log 2>&1 </dev/null &"
	sleep 20
	echo "--- 判据 ---"
	echo "relay:    $(systemctl is-active ssc-udp-relay)"
	echo "hapticd:  $(systemctl is-active elden-hapticd)"
	echo "sensord:  $(pgrep -af '^waydroid-sensord ' | head -1)"
	PID=$(lxc-info -P /var/lib/waydroid/lxc -n waydroid -p 2>/dev/null | tr -dc 0-9)
	echo "boot_completed: $(nsenter -t "$PID" -m -p /system/bin/getprop sys.boot_completed 2>/dev/null)"
	nsenter -t "$PID" -m -p /system/bin/dumpsys sensorservice 2>/dev/null | grep -m1 "h/w sensors"'
say done
