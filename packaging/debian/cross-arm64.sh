#!/usr/bin/env bash
# Prepare the ARM64 sysroot the Debian cross build links against.
#
# The host programs link libwayland-server, libgbm, libxkbcommon and
# libpipewire, which are C libraries: a Rust target alone cannot link them for
# aarch64. This script fetches their ARM64 packages from the distribution's
# ports mirror and unpacks them into a sysroot, without root, without
# dpkg --add-architecture, and without touching the host's package database.
#
#   sysroot=$(packaging/debian/cross-arm64.sh) &&
#       packaging/debian/build.sh --arch arm64 --sysroot "$sysroot"
#
# The packages are the cross-build subset of packaging/arch/PKGBUILD.in's
# makedepends (mesa, wayland, libdrm, libxkbcommon, libpipewire) plus the
# pkg-config metadata and private Requires those .pc files name.
set -euo pipefail

readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly WORK=${DROIDLOOM_CROSS_WORK:-$SCRIPT_DIR/.work/arm64}
readonly SYSROOT=$WORK/sysroot
# Ports mirror of the Ubuntu release this packaging was last built on; override
# for another distribution, e.g. DROIDLOOM_CROSS_MIRROR=https://deb.debian.org/debian-ports.
readonly MIRROR=${DROIDLOOM_CROSS_MIRROR:-http://ports.ubuntu.com/ubuntu-ports/}
readonly SUITE=${DROIDLOOM_CROSS_SUITE:-resolute}
readonly COMPONENTS=${DROIDLOOM_CROSS_COMPONENTS:-main universe}

readonly PACKAGES=(
    # Link targets and their pkg-config metadata.
    libwayland-dev libwayland-server0 libwayland-client0 libwayland-egl1
    libwayland-cursor0
    libdrm-dev libdrm2
    libxkbcommon-dev libxkbcommon0
    libgbm-dev libgbm1
    libpipewire-0.3-dev libpipewire-0.3-0t64 libspa-0.2-dev
    # Private Requires of wayland-server.pc and wayland-client.pc.
    libffi-dev libffi8
)

log() { printf '==> %s\n' "$*" >&2; }

mkdir -p "$WORK/lists/partial" "$WORK/debs" "$SYSROOT"
readonly SOURCES=$WORK/arm64.sources
cat >"$SOURCES" <<EOF
Types: deb
URIs: $MIRROR
Suites: $SUITE
Components: $COMPONENTS
Architectures: arm64
Trusted: yes
EOF

apt_options=(
    -o "Dir::Etc::sourcelist=$SOURCES"
    -o Dir::Etc::sourceparts=-
    -o "Dir::Cache=$WORK/cache"
    -o Dir::Cache::pkgcache=
    -o Dir::Cache::srcpkgcache=
    -o "Dir::State::Lists=$WORK/lists"
    -o APT::Architecture=arm64
)

if [[ ${DROIDLOOM_CROSS_REFRESH:-0} == 1 || ! -d $WORK/lists/$SUITE ]]; then
    log "reading the arm64 package index of $MIRROR"
    apt-get "${apt_options[@]}" update >/dev/null
fi

log "fetching ${#PACKAGES[@]} arm64 packages"
( cd "$WORK/debs" && apt-get "${apt_options[@]}" download "${PACKAGES[@]/%/:arm64}" )

log "unpacking into $SYSROOT"
rm -rf "$SYSROOT"
mkdir -p "$SYSROOT"
for package in "$WORK"/debs/*.deb; do
    dpkg-deb --extract "$package" "$SYSROOT"
done

for probe in wayland-server gbm xkbcommon libpipewire-0.3; do
    PKG_CONFIG_SYSROOT_DIR=$SYSROOT \
        PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig:$SYSROOT/usr/share/pkgconfig" \
        pkg-config --exists "$probe" ||
        { echo "cross-arm64: $probe is missing from the sysroot" >&2; exit 1; }
done

log "sysroot ready: $SYSROOT ($(du -sh "$SYSROOT" | cut -f1))"
printf '%s\n' "$SYSROOT"
