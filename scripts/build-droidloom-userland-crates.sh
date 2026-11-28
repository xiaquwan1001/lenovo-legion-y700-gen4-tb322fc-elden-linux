#!/bin/bash
# build-droidloom-userland-crates.sh — 主机交叉编 droidloom 4 个「C 依赖」件（不走 Arch ARM sysroot）
#
# 背景：T44（reports/t44-ubuntu-build-scoping-20261128.md）实证真 C 依赖只有
#   wayland-client / gbm / libpipewire-0.3（+ 构建期 glslangValidator）。
#   本脚本用 trixie arm64 sysroot（`scripts/sysroot-add-droidloom-deps.sh` 补齐后）在
#   **Ubuntu/Pop 主机**上交叉编 `droidloom-{wayland,audio,devices,gpu-server}`。
#
# 用法：bash scripts/build-droidloom-userland-crates.sh [crate ...]
#       默认编 4 个件；产物在 build/droidloom-51-src/target/aarch64-unknown-linux-gnu/release/
# 判据：每件 max GLIBC 符号 ≤ 2.41（设备 Debian 13）；脚本自动打印。
set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SYSROOT=${SYSROOT:-$REPO/out/sysroot-trixie-arm64}
SRC=${SRC:-$REPO/build/droidloom-51-src}
WRAP=${WRAP:-$REPO/build/tools/aarch64-cc-sysroot.sh}
CRATES=${*:-"droidloom-wayland droidloom-audio droidloom-devices droidloom-gpu-server"}

[ -d "$SYSROOT/usr/lib/aarch64-linux-gnu" ] || { echo "缺 sysroot：$SYSROOT（先跑 scripts/sysroot-add-droidloom-deps.sh）" >&2; exit 1; }
[ -d "$SRC" ] || { echo "缺 droidloom 源码树：$SRC" >&2; exit 1; }

# gcc 包装：必须把 --sysroot 传给 ld，否则 trixie 的 libc.so/libm.so（ld script 内用绝对路径
# /lib/aarch64-linux-gnu/...）会落到宿主根目录 ⇒ "cannot find /lib/aarch64-linux-gnu/libm.so.6"
mkdir -p "$(dirname "$WRAP")"
cat > "$WRAP" <<'EOS'
#!/bin/sh
exec aarch64-linux-gnu-gcc --sysroot="${ELDEN_AARCH64_SYSROOT:?}" "$@"
EOS
chmod +x "$WRAP"

export ELDEN_AARCH64_SYSROOT="$SYSROOT"
export PKG_CONFIG_ALLOW_CROSS=1
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig:$SYSROOT/usr/share/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER="$WRAP"
export CC_aarch64_unknown_linux_gnu="$WRAP"
export RUSTFLAGS="-L $SYSROOT/usr/lib/aarch64-linux-gnu"
export PATH="$HOME/.cargo/bin:$PATH"

args=()
for c in $CRATES; do args+=(-p "$c"); done

echo "=== 编译：$CRATES"
cd "$SRC"
cargo build --release --locked --target aarch64-unknown-linux-gnu "${args[@]}"

OUT=$SRC/target/aarch64-unknown-linux-gnu/release
echo "=== 产物与兼容性判据（设备 glibc 2.41）"
fail=0
for c in $CRATES; do
  b=$OUT/$c
  [ -f "$b" ] || { echo "  [FAIL] 缺产物 $c"; fail=1; continue; }
  g=$(objdump -T "$b" | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1)
  printf "  %-22s %9d B  max %s\n" "$c" "$(stat -c%s "$b")" "$g"
  case "$g" in
    GLIBC_2.4[1-9]*) echo "  [FAIL] $c 需要高于设备的 glibc"; fail=1 ;;
  esac
done
[ $fail -eq 0 ] && echo "OK — 4 件均可上设备（≤ GLIBC 2.41）" || exit 1
