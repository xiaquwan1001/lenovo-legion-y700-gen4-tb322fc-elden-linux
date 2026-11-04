#!/bin/bash
# waydroid-sensord.sh — 重建 /usr/local/bin/waydroid-sensord 与 waydroid-sensord-udp
#                      （路线 C 的 Waydroid Sensors HAL，同一份源码两个文件名）
#
# 源   : patches-userland/waydroid-sensord-udp/{Makefile,service.cpp,Sensors.cpp,SensorFW.cpp,...}
#        （service.cpp/Sensors.cpp = 上游 GPL-3.0 未改；SensorFW.{h,cpp} = 自写 UDP 数据源）
# 产物 : out/sensord-host/waydroid-sensord{,-udp}（默认 glibc）；--target=musl 时为 musl 变体
#
# ── 为什么必须有「两套」以及怎么取舍（2026-10-27 实测，PITFALLS #431） ──────────────
#   * 这个 ELF 是 **动态链接** 的（interpreter 决定它能跑在哪种根上）：
#       - glibc 版：interpreter /lib/ld-linux-aarch64.so.1  ⇒ 只有 Debian/Mobian 根可用
#       - musl  版：interpreter /lib/ld-musl-aarch64.so.1   ⇒ 只有 Alpine 根可用
#   * 危机点：Waydroid 的 `container_manager.py` / `images.py` 只按**文件存在**决定
#     "宿主有 HAL"（并因此不再设 `waydroid.stub_sensors_hal`）。把 musl 件搬到 glibc 根上，
#     `which` 仍命中但 exec 直接 ENOENT（报错文案不提 loader）⇒ sensorservice 每秒重试
#     ⇒ Android 永远停在 bootanimation。**换根必须重编，没有别的办法。**
#   * 取舍（本轮定案）：
#       - **glibc 版 = 默认**：产物 sha256 22028ffd… 与 MANIFEST 清单值**逐字一致**，
#         即设备上现役件就是这条 recipe 的产物 ⇒ 用 host arm64 chroot（/opt/elden/arm64-sid）。
#         代价：需要 root + debootstrap + binfmt（本机已具备），首次 ~10 min，之后增量秒级。
#       - **musl 版 = 备选**（Alpine 根/或回退到 Alpine 时代）：同样做法，把 chroot 换成
#         Alpine aarch64 根 + `apk add build-base pkgconf gbinder-dev glib-util-dev glib-dev`。
#         本机**当前没有** Alpine chroot ⇒ 该分支只提供命令，**未证**（标 dry-run only）。
#       - 不用 musl-cross-make / 静态链接：上游 Makefile 依赖 pkg-config 找
#         gbinder/glibutil 的 .pc，静态交叉链没有这两套 .pc，改 Makefile 不在本任务范围。
#
# 用法:
#   bash packaging/elden-userland/build/waydroid-sensord.sh --dry-run            # 只打印（默认 glibc）
#   sudo bash packaging/elden-userland/build/waydroid-sensord.sh                 # 真跑 glibc
#   bash packaging/elden-userland/build/waydroid-sensord.sh --target=musl --dry-run
#
# 真跑等价物（不经过本包装）: sudo bash scripts/host-arm64-chroot.sh --build-sensord
set -euo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

TARGET=glibc
for a in "${ARGS[@]:-}"; do
	case "$a" in
		--target=*) TARGET=${a#--target=} ;;
		'') : ;;
		*) printf '未知参数: %s（支持 --dry-run / --target=glibc|musl）\n' "$a" >&2; exit 2 ;;
	esac
done
REPO=$(repo_root)
SRC=$REPO/patches-userland/waydroid-sensord-udp
CHROOT_DIR=${CHROOT_DIR:-/opt/elden/arm64-sid}
ALPINE_DIR=${ALPINE_DIR:-/opt/elden/arm64-alpine}
MIRROR=${MIRROR:-https://mirrors.ustc.edu.cn/debian}
OUT=$REPO/out/sensord-host

need_file "$SRC/Makefile"
need_file "$SRC/service.cpp"
need_file "$SRC/SensorFW.cpp"

case "$TARGET" in
glibc)
	note "目标根: glibc（Debian sid arm64 chroot $CHROOT_DIR）"
	[ "$DRY_RUN" = 1 ] || need_root "$@"
	# 1. chroot 存在性（dry-run 只提示）
	run sh -c "test -x '$CHROOT_DIR/bin/sh' || debootstrap --arch=arm64 --variant=minbase --include=ca-certificates sid '$CHROOT_DIR' '$MIRROR'"
	# 2. 构建依赖（幂等）
	run chroot "$CHROOT_DIR" /bin/sh -c \
		"apt-get update -qq && apt-get install -y -qq --no-install-recommends \
		 build-essential pkgconf make g++ libgbinder-dev libglibutil-dev libglib2.0-dev"
	# 3. 源码 → chroot → make（把源码拷进去，绝不反向写仓库）
	run rm -rf "$CHROOT_DIR/root/sensord-build"
	run mkdir -p "$CHROOT_DIR/root/sensord-build"
	run cp -a "$SRC/." "$CHROOT_DIR/root/sensord-build/"
	run chroot "$CHROOT_DIR" /bin/sh -c \
		'cd /root/sensord-build && make clean >/dev/null 2>&1; make'
	# 4. 取回产物（两个文件名 = MANIFEST 的两行）
	run mkdir -p "$OUT"
	run cp "$CHROOT_DIR/root/sensord-build/waydroid-sensord-udp" "$OUT/waydroid-sensord-udp"
	run cp "$CHROOT_DIR/root/sensord-build/waydroid-sensord-udp" "$OUT/waydroid-sensord"
	;;
musl)
	note "目标根: musl（Alpine aarch64 chroot $ALPINE_DIR）—— 本机暂无该 chroot，分支未证"
	[ "$DRY_RUN" = 1 ] || need_root "$@"
	run sh -c "test -x '$ALPINE_DIR/bin/sh' || apk --root '$ALPINE_DIR' --arch aarch64 --initdb --no-cache add alpine-base"
	run chroot "$ALPINE_DIR" /bin/sh -c \
		'apk add --no-cache build-base pkgconf g++ gbinder-dev glib-util-dev glib-dev'
	run rm -rf "$ALPINE_DIR/root/sensord-build"
	run mkdir -p "$ALPINE_DIR/root/sensord-build"
	run cp -a "$SRC/." "$ALPINE_DIR/root/sensord-build/"
	run chroot "$ALPINE_DIR" /bin/sh -c 'cd /root/sensord-build && make clean; make'
	run mkdir -p "$OUT"
	run cp "$ALPINE_DIR/root/sensord-build/waydroid-sensord-udp" "$OUT/waydroid-sensord-udp.musl"
	run cp "$ALPINE_DIR/root/sensord-build/waydroid-sensord-udp" "$OUT/waydroid-sensord.musl"
	;;
*)
	printf '未知 target: %s（glibc|musl）\n' "$TARGET" >&2; exit 2 ;;
esac

# 5. 自检判据（真跑时）：interpreter 必须与目标根一致
if [ "$DRY_RUN" = 0 ]; then
	art=$OUT/waydroid-sensord-udp
	note "自检: file/readelf 与 sha256"
	run sh -c "file '$art'; readelf -l '$art' | grep -A1 INTERP | tail -1; sha256sum '$art' '$OUT/waydroid-sensord'"
	case "$TARGET" in
		glibc) run sh -c "readelf -l '$art' | grep -q 'ld-linux-aarch64' || { echo 'ERROR: 不是 glibc 版'; exit 1; }" ;;
		musl)  run sh -c "readelf -l '$art' | grep -q 'ld-musl-aarch64' || { echo 'ERROR: 不是 musl 版'; exit 1; }" ;;
	esac
fi
finish "waydroid-sensord($TARGET)"
