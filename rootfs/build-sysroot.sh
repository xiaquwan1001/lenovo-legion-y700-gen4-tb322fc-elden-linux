#!/bin/bash
# Assemble an arm64 sysroot for cross-building userland pieces.
# 默认 `SUITE=resolute` = **主机** Ubuntu 26.04 的端口源（历史上为编 Mesa 设的）；
# 注意：**设备在版 = Debian 13 trixie**（phosh 0.46 / phoc 0.46 / glib 2.84.4）。
# 要与设备同 ABI 编件（如 libgmobile）请显式覆盖：
#   SUITE=trixie MIRROR=http://deb.debian.org/debian PKGS_ENV="<包表>" SYSROOT=… bash rootfs/build-sysroot.sh
# 范例（T34）= reports/gmobile-t34-build-deploy-20261128.md §1 + rootfs/cross-aarch64-gmobile.ini 头注。
set -euo pipefail

# 默认路径按仓根推导（2026-11-28 修正：旧值 /home/xuqianhui1001/… 在本机不存在）
REPO=${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
SYSROOT=${SYSROOT:-$REPO/out/sysroot-arm64}
APT=$SYSROOT/.apt
# SUITE/MIRROR 可按需换（例：在 Debian trixie 设备上取同版 dev 包）
SUITE=${SUITE:-resolute}
MIRROR=${MIRROR:-http://ports.ubuntu.com/ubuntu-ports}

PKGS=(
	libdrm-dev libdrm2 libdrm-common
	libwayland-dev libwayland-client0 libwayland-server0 libwayland-cursor0 libwayland-egl1
	wayland-protocols libwayland-bin libwayland-egl-backend-dev
	libudev-dev libudev1 libdisplay-info-dev libdisplay-info3
	libx11-dev libx11-6 libx11-xcb-dev libx11-xcb1 x11proto-dev xtrans-dev
	libxcb1-dev libxcb1 libxcb-dri3-dev libxcb-dri3-0 libxcb-present-dev libxcb-present0
	libxcb-sync-dev libxcb-sync1 libxcb-shm0-dev libxcb-shm0 libxcb-randr0-dev libxcb-randr0
	libxcb-xfixes0-dev libxcb-xfixes0 libxcb-glx0-dev libxcb-glx0 libxcb-dri2-0-dev libxcb-dri2-0
	libxcb-render0-dev libxcb-render0 libxcb-shape0-dev libxcb-shape0 libxcb-keysyms1-dev libxcb-keysyms1
	libxext-dev libxext6 libxfixes-dev libxfixes3 libxdamage-dev libxdamage1
	libxshmfence-dev libxshmfence1 libxrandr-dev libxrandr2 libxxf86vm-dev libxxf86vm1
	libxau-dev libxau6 libxdmcp-dev libxdmcp6 libxrender-dev libxrender1
	libexpat1-dev libexpat1 zlib1g-dev zlib1g libzstd-dev libzstd1
	libelf-dev libelf1t64 libffi-dev libffi8
	libvulkan-dev libvulkan1
	libc6-dev libc6 linux-libc-dev
)

# PKGS_ENV：逗号或空白分隔的完整替代包表（例：只给 gmobile 用的 glib/json-glib dev）
if [ -n "${PKGS_ENV:-}" ]; then
	read -r -a PKGS <<< "${PKGS_ENV//,/ }"
fi

mkdir -p "$APT"/etc/apt/{sources.list.d,preferences.d,apt.conf.d,trusted.gpg.d} \
	 "$APT"/var/lib/apt/lists/partial "$APT"/var/cache/apt/archives/partial \
	 "$APT"/var/lib/dpkg "$SYSROOT/debs"
: > "$APT/var/lib/dpkg/status"

cat > "$APT/etc/apt/sources.list" <<EOF
deb [arch=arm64 trusted=yes] $MIRROR $SUITE main universe
deb [arch=arm64 trusted=yes] $MIRROR $SUITE-updates main universe
EOF

aptopts=(
	-o Dir="$APT"
	-o Dir::State="$APT/var/lib/apt"
	-o Dir::State::status="$APT/var/lib/dpkg/status"
	-o Dir::Cache="$APT/var/cache/apt"
	-o Dir::Etc::sourcelist="$APT/etc/apt/sources.list"
	-o Dir::Etc::sourceparts="$APT/etc/apt/sources.list.d"
	-o Dir::Etc::preferences="$APT/etc/apt/preferences"
	-o Dir::Etc::preferencesparts="$APT/etc/apt/preferences.d"
	-o Dir::Etc::trusted="$APT/etc/apt/trusted.gpg"
	-o Dir::Etc::trustedparts="$APT/etc/apt/trusted.gpg.d"
	-o APT::Architecture=arm64
	-o APT::Architectures::=arm64
	-o Acquire::Languages=none
	-o Acquire::Retries=3
)

echo "== apt update"
apt-get "${aptopts[@]}" update >/dev/null

echo "== downloading ${#PKGS[@]} packages"
cd "$SYSROOT/debs"
missing=()
for p in "${PKGS[@]}"; do
	if ! apt-get "${aptopts[@]}" download "$p" >/dev/null 2>&1; then
		missing+=("$p")
	fi
done
echo "downloaded: $(ls -1 *.deb 2>/dev/null | wc -l)"
[ ${#missing[@]} -gt 0 ] && echo "unavailable: ${missing[*]}"

echo "== unpacking into sysroot"
for d in *.deb; do
	dpkg-deb -x "$d" "$SYSROOT"
done

echo "== fixing absolute symlinks"
# .so symlinks in /usr/lib point at /lib/... absolute paths; rewrite them
# relative so the cross-linker resolves them inside the sysroot.
find "$SYSROOT" -type l | while read -r link; do
	target=$(readlink "$link")
	case "$target" in
		/*)
			rel=$(realpath -m --relative-to="$(dirname "$link")" "$SYSROOT$target")
			ln -sfn "$rel" "$link"
			;;
	esac
done

echo "== usrmerge compat symlinks"
# The debs are usrmerge-only, but the linker still looks for the loader under
# the historical /lib path recorded in the aarch64 ELF interpreter field.
mkdir -p "$SYSROOT/lib"
[ -e "$SYSROOT/lib/ld-linux-aarch64.so.1" ] || \
	ln -sfn ../usr/lib/ld-linux-aarch64.so.1 "$SYSROOT/lib/ld-linux-aarch64.so.1"
[ -e "$SYSROOT/lib/aarch64-linux-gnu" ] || \
	ln -sfn ../usr/lib/aarch64-linux-gnu "$SYSROOT/lib/aarch64-linux-gnu"

echo "== header check"
for h in libdrm/msm_drm.h wayland-client.h X11/Xlib.h xcb/xcb.h expat.h zlib.h vulkan/vulkan.h; do
	printf '%-24s ' "$h"
	ls "$SYSROOT/usr/include/$h" >/dev/null 2>&1 && echo OK || echo MISSING
done
du -sh "$SYSROOT"
