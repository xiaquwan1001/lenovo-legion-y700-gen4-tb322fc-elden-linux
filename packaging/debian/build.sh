#!/usr/bin/env bash
# Build the Droidloom Debian packages.
#
# Two inputs are possible, mirroring packaging/arch/PKGBUILD.in:
#
#   --payload DIR   a staged payload (runtime/, image/, base/) as produced by
#                   `droidloom-package compile`. Packs droidloom-runtime,
#                   droidloom-image and droidloom-base, exactly the file sets
#                   the Arch recipe packs.
#   (no payload)    builds droidloom-runtime from this checkout for the host
#                   architecture. The Android image packages come from a
#                   payload build: they cannot be compiled here, they are built
#                   by the AOSP build tools/droidloom-package drives.
#
# Examples:
#   packaging/debian/build.sh                       # host runtime package
#   packaging/debian/build.sh --verify              # ...and check it
#   packaging/debian/build.sh --payload /p/payload  # the complete release
#   packaging/debian/build.sh --arch arm64 ...      # cross build (needs sysroot)
#
# Output: packaging/debian/dist/*.deb (override with --out).
set -euo pipefail
umask 022

readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# The Debian packaging lives in the Droidloom checkout in production, where the
# source tree is this tree's grandparent. It is also kept in the y700-elden host
# side tree, whose sibling checkout builds the packages: pick whichever of the
# two actually holds the Droidloom source, and let --source override.
if [[ -f $SCRIPT_DIR/../arch/version.json ]]; then
    default_source=$(cd "$SCRIPT_DIR/../.." && pwd)
else
    default_source=${DROIDLOOM_SOURCE:-/home/xuqianhui/src/droidloom}
fi

# The host programs every package carries, with the output paths they own.
# Same split as tools/droidloom-package/src/components.rs.
readonly RUNTIME_COMPONENTS=(
    droidloom-supervisor
    droidloom-wayland
    droidloom-applications
    droidloom-audio
    droidloom-gpu-server
    droidloom-devices
    droidloom-doctor
    droidloom-package-support
)
readonly RUNTIME_BINARIES=(
    droidloomd
    droidloomctl
    droidloom-supervisor
    droidloom-wayland
    droidloom-applications
    droidloom-audio
    droidloom-gpu-server
    droidloom-devices
    droidloom-doctor
)
readonly SYSTEM_UNITS=(droidloomd.service)
readonly USER_UNITS=(
    droidloom.service
    droidloom-applications.service
    droidloom-recovery.service
    droidloom-audio.service
    droidloom-audio.socket
    droidloom-gpu.service
    droidloom-gpu.socket
    droidloom-devices.service
    droidloom-devices.socket
)

payload=
source_dir=
sysroot=
requested_arch=
jobs=
out=
work=
stage_dir=
verify=0
no_build=0

usage() {
    sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    cat <<'EOF'

Options:
  --source DIR    Droidloom source checkout (default: this tree, else
                  $DROIDLOOM_SOURCE, else /home/xuqianhui/src/droidloom)
  --sysroot DIR   ARM64 sysroot for --arch arm64 (debian/cross-arm64.sh)
  --payload DIR   staged payload (runtime/, image/, base/) to pack
  --arch ARCH     amd64 (x86_64) or arm64 (aarch64); default: host
  --jobs N        parallel compiler jobs (default: 2 fewer than the CPUs)
  --out DIR       destination for the packages (default: packaging/debian/dist)
  --work DIR      build tree (default: packaging/debian/.work)
  --stage DIR     stage the package trees into DIR and stop (no .deb)
  --no-build      reuse existing compiler output instead of running cargo
  --verify        check the packages (dpkg-deb -I/-c, dpkg -i --dry-run)
  -h, --help      this text
EOF
}

log() { printf '==> %s\n' "$*" >&2; }
die() { printf 'droidloom-deb: %s\n' "$*" >&2; exit 2; }

while (($#)); do
    case "$1" in
        --payload) payload=${2:?--payload needs a directory}; shift 2 ;;
        --source) source_dir=${2:?--source needs a directory}; shift 2 ;;
        --sysroot) sysroot=${2:?--sysroot needs a directory}; shift 2 ;;
        --arch) requested_arch=${2:?--arch needs a value}; shift 2 ;;
        --jobs) jobs=${2:?--jobs needs a value}; shift 2 ;;
        --out) out=${2:?--out needs a directory}; shift 2 ;;
        --work) work=${2:?--work needs a directory}; shift 2 ;;
        --stage) stage_dir=${2:?--stage needs a directory}; shift 2 ;;
        --no-build) no_build=1; shift ;;
        --verify) verify=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done

: "${out:=$SCRIPT_DIR/dist}"
: "${work:=$SCRIPT_DIR/.work}"
if [[ -z $jobs ]]; then
    cpu=$(nproc)
    jobs=$(( cpu > 2 ? cpu - 2 : 1 ))
fi

REPO=${source_dir:-$default_source}
[[ -f $REPO/Cargo.toml && -f $REPO/packaging/arch/version.json ]] ||
    die "not a Droidloom source checkout: $REPO"

# --- release identity and architecture ---------------------------------------

read -r upstream_version release < <(python3 - "$REPO/packaging/arch/version.json" <<'PY'
import json, sys
identity = json.load(open(sys.argv[1], encoding="utf-8"))
print(identity["version"], identity["release"])
PY
)
version="$upstream_version-$release"

deb_arch=${requested_arch:-$(dpkg --print-architecture)}
case "$deb_arch" in
    amd64) upstream_arch=x86_64; rust_target=x86_64-unknown-linux-gnu; recipe=x86_64-u1000 ;;
    arm64) upstream_arch=aarch64; rust_target=aarch64-unknown-linux-gnu; recipe=arm64 ;;
    *) die "unsupported Debian architecture: $deb_arch (amd64 and arm64 only)" ;;
esac
if [[ -n $payload && $deb_arch != "$(dpkg --print-architecture)" ]]; then
    die "a payload is packed for its own architecture: $payload is $upstream_arch"
fi

log "droidloom $version for $deb_arch ($upstream_arch), $jobs compiler jobs"

# --- staging -----------------------------------------------------------------

stage_root=
keep_stage=0
cleanup() { [[ -n ${stage_root:-} && -d $stage_root ]] && rm -rf "$stage_root"; }
trap cleanup EXIT

if [[ -n $stage_dir ]]; then
    stage_root=$(mkdir -p "$stage_dir" && cd "$stage_dir" && pwd)
    keep_stage=1
else
    mkdir -p "$work"
    stage_root=$(mktemp -d "$work/stage.XXXXXX")
fi

binaries=
install_binaries() {
    # $1: directory holding the compiled host programs
    local release_dir=$1 name
    for name in "${RUNTIME_BINARIES[@]}"; do
        [[ -f $release_dir/$name ]] || die "missing compiled program: $release_dir/$name"
    done
    [[ -f $release_dir/droidloom-package-helper ]] ||
        die "missing compiled program: $release_dir/droidloom-package-helper"
    install -d -m 0755 "$stage_root/runtime/usr/bin"
    for name in "${RUNTIME_BINARIES[@]}"; do
        install -m 0755 "$release_dir/$name" "$stage_root/runtime/usr/bin/$name"
    done
    install -d -m 0755 "$stage_root/runtime/usr/lib/droidloom"
    install -m 0755 "$release_dir/droidloom-package-helper" \
        "$stage_root/runtime/usr/lib/droidloom/droidloom-package-helper"
}

stage_runtime_files() {
    local name
    for name in "${SYSTEM_UNITS[@]}"; do
        install -D -m 0644 "$REPO/packaging/systemd/system/$name" \
            "$stage_root/runtime/usr/lib/systemd/system/$name"
    done
    for name in "${USER_UNITS[@]}"; do
        install -D -m 0644 "$REPO/packaging/systemd/user/$name" \
            "$stage_root/runtime/usr/lib/systemd/user/$name"
    done
    install -D -m 0644 "$REPO/packaging/arch/org.droidloom.setup.policy" \
        "$stage_root/runtime/usr/share/polkit-1/actions/org.droidloom.setup.policy"
    install -D -m 0644 "$REPO/packaging/arch/README.md" \
        "$stage_root/runtime/usr/share/doc/droidloom/README.md"
    # Arch-only integration (libalpm hooks) stays out of the Debian package:
    # debian/droidloom-runtime.{pre,post}inst call the same helper.
    install -d -m 0755 "$stage_root/runtime/usr/share/droidloom"
    python3 "$SCRIPT_DIR/gen-stage.py" cell-template \
        "$REPO/packaging/cell-spec-$recipe.json" \
        "$stage_root/runtime/usr/share/droidloom/cell-template.json"
    python3 "$SCRIPT_DIR/gen-stage.py" package-json \
        "$REPO/packaging/arch/version.json" "$upstream_arch" \
        "$stage_root/runtime/usr/share/droidloom/package.json"
    log "licenses: project, upstream notices and Cargo dependencies"
    python3 "$SCRIPT_DIR/gen-stage.py" licenses "$REPO" \
        "$stage_root/runtime/usr/share/licenses/droidloom-runtime"
}

cross_environment() {
    # The host programs link C libraries (wayland-server, gbm, xkbcommon,
    # pipewire); an ARM64 target needs their ARM64 metadata and objects.
    local sysroot=$1
    export PKG_CONFIG_ALLOW_CROSS=1
    export PKG_CONFIG_SYSROOT_DIR=$sysroot
    export PKG_CONFIG_LIBDIR=$sysroot/usr/lib/aarch64-linux-gnu/pkgconfig:$sysroot/usr/share/pkgconfig
    export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
    export CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc
    export CFLAGS_aarch64_unknown_linux_gnu="--sysroot=$sysroot -I$sysroot/usr/include/aarch64-linux-gnu -I$sysroot/usr/include"
    # droidloom-audio's build script links -lpipewire-0.3 without a search path.
    export RUSTFLAGS="-L native=$sysroot/usr/lib/aarch64-linux-gnu -C link-arg=-Wl,-rpath-link=$sysroot/usr/lib/aarch64-linux-gnu"
}

stage_runtime_from_source() {
    local release_dir
    if [[ $rust_target != x86_64-unknown-linux-gnu ]]; then
        [[ -n $sysroot && -d $sysroot/usr/lib/aarch64-linux-gnu/pkgconfig ]] ||
            die "--arch $deb_arch needs --sysroot: run debian/cross-arm64.sh first"
        command -v aarch64-linux-gnu-gcc >/dev/null ||
            die "--arch $deb_arch needs aarch64-linux-gnu-gcc (gcc-aarch64-linux-gnu)"
        rustc --print target-libdir --target "$rust_target" >/dev/null 2>&1 ||
            die "--arch $deb_arch needs: rustup target add $rust_target"
        cross_environment "$sysroot"
        log "cross build against $sysroot"
    fi
    if [[ $no_build == 1 ]]; then
        release_dir="$REPO/target/release"
        [[ $rust_target == x86_64-unknown-linux-gnu ]] ||
            release_dir="$REPO/target/$rust_target/release"
        log "reusing compiler output in $release_dir"
    else
        local -a cargo_args=(build --locked --release --jobs "$jobs")
        [[ $rust_target == x86_64-unknown-linux-gnu ]] ||
            cargo_args+=(--target "$rust_target")
        local component
        for component in "${RUNTIME_COMPONENTS[@]}"; do
            cargo_args+=(-p "$component")
        done
        log "cargo ${cargo_args[*]}"
        ( cd "$REPO" && cargo "${cargo_args[@]}" )
        release_dir="$REPO/target/release"
        [[ $rust_target == x86_64-unknown-linux-gnu ]] ||
            release_dir="$REPO/target/$rust_target/release"
    fi
    install_binaries "$release_dir"
    stage_runtime_files
}

stage_payload() {
    local payload=$1 tree
    [[ -d $payload ]] || die "payload directory missing: $payload"
    [[ -d $payload/runtime ]] || die "payload has no runtime/ tree: $payload"
    # Pack with the same tree installer the Arch recipe uses, so file modes,
    # ownership and hard links are identical.
    log "staging payload trees from $payload"
    ( cd "$REPO" && cargo run --quiet --release --locked \
        -p droidloom-package -- install-tree \
        --source "$payload/runtime" --destination "$stage_root/runtime" )
    # libalpm hooks are Arch's transaction interface; Debian calls the same
    # helper from its maintainer scripts instead.
    rm -rf "$stage_root/runtime/usr/share/libalpm"
    for tree in image base; do
        if [[ -d $payload/$tree ]]; then
            ( cd "$REPO" && cargo run --quiet --release --locked \
                -p droidloom-package -- install-tree \
                --source "$payload/$tree" --destination "$stage_root/$tree" )
        fi
    done
}

base_version=
if [[ -n $payload ]]; then
    stage_payload "$payload"
    if [[ -f $payload/base/usr/share/droidloom/package.json ]]; then
        base_version=$(python3 - "$payload/base/usr/share/droidloom/package.json" <<'PY'
import json, sys
identity = json.load(open(sys.argv[1], encoding="utf-8"))
print(f"{identity['version']}-{identity['release']}")
PY
)
    fi
    : "${base_version:=$version}"
    mode=payload
else
    log "no payload: building droidloom-runtime from this checkout"
    stage_runtime_from_source
    mode=source
fi

[[ -d $stage_root/runtime ]] || die "no runtime tree was staged"

if [[ -n $stage_dir && -z $payload ]]; then
    log "runtime tree staged in $stage_root/runtime"
    trap - EXIT
    exit 0
fi

# --- packaging ---------------------------------------------------------------

deb_dir=$stage_root/deb
install -d "$deb_dir"

write_control() {
    # $1: binary package name, $2: staged tree, $3: its DEBIAN directory
    local package=$1 tree=$2 control=$3
    local installed_size
    installed_size=$(du -sk --apparent-size "$tree" | cut -f1)
    mkdir -p "$control"
    python3 "$SCRIPT_DIR/gen-stage.py" control \
        "$SCRIPT_DIR/control.in" "$package" "$version" "$deb_arch" \
        "$mode" "$base_version" "$control/control"
    {
        echo "Version: $version"
        echo "Installed-Size: $installed_size"
    } >>"$control/control"
    # dpkg-derivable hygiene: record checksums like dh_md5sums would.
    ( cd "$tree" && find . -path ./DEBIAN -prune -o -type f -print0 |
        sort -z | xargs -0 -r md5sum | sed 's| \./| |' ) >"$control/md5sums"
    for script in postinst prerm postrm; do
        if [[ -f $SCRIPT_DIR/$package.$script ]]; then
            install -m 0755 "$SCRIPT_DIR/$package.$script" "$control/$script"
        fi
    done
}

build_deb() {
    local package=$1 tree=$2
    local control=$tree/DEBIAN
    write_control "$package" "$tree" "$control"
    local deb="$out/${package}_${version}_${deb_arch}.deb"
    mkdir -p "$out"
    log "dpkg-deb --build $package"
    dpkg-deb --root-owner-group -Zzstd --build "$tree" "$deb" >/dev/null
    printf '%s  %s\n' "$(sha256sum "$deb" | cut -d' ' -f1)" "$(basename "$deb")"
}

installed=()
for package in droidloom-runtime droidloom-image droidloom-base; do
    tree=$stage_root/${package#droidloom-}
    [[ -d $tree/usr ]] || continue
    build_deb "$package" "$tree"
    installed+=("$out/${package}_${version}_${deb_arch}.deb")
done

(( ${#installed[@]} )) || die "nothing was staged; no packages built"

# --- verification ------------------------------------------------------------

if ((verify)); then
    comment_dir=$stage_root/control-check
    for deb in "${installed[@]}"; do
        log "checking $(basename "$deb")"
        dpkg-deb --info "$deb" >/dev/null
        dpkg-deb --contents "$deb" >/dev/null
        dpkg-deb --field "$deb" Package Version Architecture Depends
        # dpkg -i --dry-run stops at unpack and never evaluates dependencies,
        # so check them against the installed package set directly.
        rm -rf "$comment_dir"
        dpkg-deb --control "$deb" "$comment_dir"
        python3 "$SCRIPT_DIR/gen-stage.py" depends "$comment_dir/control"
        rm -rf "$comment_dir"
    done
    # The requested acceptance command. dpkg stops at "unpack" and never
    # evaluates dependencies, which is why the check above is the real gate.
    # A foreign-architecture package can only be checked on that architecture;
    # dpkg refuses it here by design.
    if [[ $deb_arch == "$(dpkg --print-architecture)" ]]; then
        log "dpkg -i --dry-run"
        if dpkg -i --dry-run "${installed[@]}"; then
            log "dpkg -i --dry-run: exit 0"
        else
            log "dpkg -i --dry-run: exited non-zero (see above)"
        fi
    else
        log "skipping dpkg -i --dry-run: $deb_arch packages need a $deb_arch host"
    fi
fi

log "packages in $out"
