#!/bin/bash
# uefi-build-variant.sh — 在 7-mu-lenovo 树上构建一个 **可追溯的 UEFI 变体**（G1-29 线）
#
# 用途：UEFI 实验的唯一构建入口。产出 = FD + boot payload + v0 镜像 + sha256 + 构建日志，
#       并保证「改了什么」写进 manifest；结束时把树还原（只还原本脚本动过的文件）。
#
# 用法：
#   scripts/uefi-build-variant.sh <outdir> [--ufsdxe mu|vendor] [--rmvmdxe mu|vendor]
#                                 [--shim stock|cachefix|markers|ddrmarks|custom:<file>]
#                                 [--patch <patchfile>]... [--clean] [--no-restore]
#
# 默认：--ufsdxe mu --rmvmdxe mu --shim stock（= 纯 Mu 基线 N）
#
# 说明：
#  - UEFI_BASE=0xFF300000 / UEFI_SIZE=0x400000 与上游 build_uefi.py 一致（ABL 报告该窗 5 MiB 可用）。
#  - 变体镜像一律 repack 成 **header v0 + base 0x10000000**（PITFALLS #387/#418：v3 被 ABL 静默忽略）。
#  - 构建可复现性：同源两次构建 FD 应逐字节相同（2026-10-24 已验证 C 变体两次同 sha）。
set -euo pipefail

REPO=${REPO:-$HOME/y700-elden/build/uefi-woa-prep/repos/7-mu-lenovo}
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ART=$ROOT/reports/artifacts
UEFI_BASE=${UEFI_BASE:-0xff300000}
UEFI_SIZE=${UEFI_SIZE:-0x400000}

OUT=""
UFSDXE=mu
RMVMDXE=mu
SHIM=stock
PATCHES=()
CLEAN=0
RESTORE=1

while [ $# -gt 0 ]; do
	case "$1" in
		--ufsdxe) UFSDXE=$2; shift 2;;
		--rmvmdxe) RMVMDXE=$2; shift 2;;
		--shim) SHIM=$2; shift 2;;
		--patch) PATCHES+=("$2"); shift 2;;
		--clean) CLEAN=1; shift;;
		--no-restore) RESTORE=0; shift;;
		-*) echo "unknown option: $1" >&2; exit 2;;
		*) OUT=$1; shift;;
	esac
done

[ -n "$OUT" ] || { echo "usage: $0 <outdir> [--ufsdxe mu|vendor] [--rmvmdxe mu|vendor] [--shim stock|cachefix|markers|ddrmarks|custom:<file>] [--patch <p>]... [--clean]" >&2; exit 2; }
[ -d "$REPO" ] || { echo "missing repo: $REPO" >&2; exit 1; }
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

DEV=Platforms/PakalaPkg/Device/lenovo-y700g4
UFSDXE_DST=$DEV/PatchedBinaries/UFSDxe.efi
RMVMDXE_DST=$DEV/Binaries/QcomPkg/Drivers/RmVmDxe/RmVmDxe.efi
SHIM_SRC=$REPO/BootShim/BootShim.S
SHIM_BIN=$REPO/BootShim/BootShim.bin

cd "$REPO"

# ---------- 还原用快照 ----------
BK=$(mktemp -d)
trap 'rm -rf "$BK"' EXIT
cp "$SHIM_SRC" "$BK/BootShim.S"
cp "$SHIM_BIN" "$BK/BootShim.bin" 2>/dev/null || true
cp "$UFSDXE_DST" "$BK/UFSDxe.efi"
cp "$RMVMDXE_DST" "$BK/RmVmDxe.efi"
APPLIED=()
reset_tree() {
	for p in "${APPLIED[@]:-}"; do
		[ -n "$p" ] && git apply -R "$p" 2>/dev/null || true
	done
	cp "$BK/BootShim.S" "$SHIM_SRC"
	[ -f "$BK/BootShim.bin" ] && cp "$BK/BootShim.bin" "$SHIM_BIN"
	cp "$BK/UFSDxe.efi" "$UFSDXE_DST"
	cp "$BK/RmVmDxe.efi" "$RMVMDXE_DST"
	rm -f BootShim/BootShim.elf
}
[ "$RESTORE" = 1 ] && trap 'reset_tree; rm -rf "$BK"' EXIT

# ---------- 组装变体 ----------
case "$UFSDXE" in
	mu) ;;  # PatchedBinaries 默认就是 Mu 件
	vendor) cp "$ART/uefi-dxe-20261024/vendor-UFSDxe.efi" "$UFSDXE_DST";;
	*) echo "bad --ufsdxe $UFSDXE" >&2; exit 2;;
esac
case "$RMVMDXE" in
	mu) [ -f "$RMVMDXE_DST.orig-mu" ] && cp "$RMVMDXE_DST.orig-mu" "$RMVMDXE_DST";;
	vendor) cp "$ART/uefi-dxe-20261024/vendor-RmVmDxe.efi" "$RMVMDXE_DST";;
	*) echo "bad --rmvmdxe $RMVMDXE" >&2; exit 2;;
esac

for p in "${PATCHES[@]:-}"; do
	[ -n "$p" ] || continue
	git apply --verbose "$p" >>"$OUT/build.log" 2>&1
	APPLIED+=("$p")
done

case "$SHIM" in
	stock) ;;
	cachefix) git apply "$ROOT/patches/uefi/0001-bootshim-add-dc-civac-ic-iallu-before-entry.patch" 2>>"$OUT/build.log";;
	markers) git apply "$ROOT/patches/uefi/0001-bootshim-add-dc-civac-ic-iallu-before-entry.patch" \
	                "$ROOT/patches/uefi/20261031-vis/0002-bootshim-framebuffer-milestone-markers.patch" 2>>"$OUT/build.log";;
	ddrmarks) git apply "$ROOT/patches/uefi/20261101-ddr/0001-bootshim-ddr-stage-markers.patch" 2>>"$OUT/build.log";;
	custom:*) cp "${SHIM#custom:}" "$SHIM_BIN";;
	*) echo "bad --shim $SHIM" >&2; exit 2;;
esac

if [ "$SHIM" != custom:* ]; then
	rm -f BootShim/BootShim.elf BootShim/BootShim.bin
	./build_boot_shim.sh -b $UEFI_BASE -s $UEFI_SIZE >>"$OUT/build.log" 2>&1
fi

# ---------- 构建 ----------
if [ "$CLEAN" = 1 ]; then rm -rf Build/PakalaPkg/RELEASE_CLANGPDB; fi
PATH=$HOME/.local/bin:$PATH GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
	timeout -k 10 ${BUILD_TIMEOUT:-2400} ./build_uefi.py -d lenovo-y700g4 -t RELEASE >>"$OUT/build.log" 2>&1 \
	|| echo "note: build_uefi.py rc!=0 (see build.log)" >>"$OUT/build.log"

FD=Build/PakalaPkg/RELEASE_CLANGPDB/FV/SM8750_EFI.fd
[ -f "$FD" ] || { echo "no FD produced" >&2; exit 1; }

cp "$FD" "$OUT/SM8750_EFI.fd"
cp BootShim/BootShim.bin "$OUT/BootShim.bin"
cp Build/PakalaPkg/bootpayload.bin "$OUT/bootpayload.bin" 2>/dev/null || true
cp Build/PakalaPkg/lenovo-y700g4.img "$OUT/lenovo-y700g4-v3.img" 2>/dev/null || true

# ---------- repack v0（PITFALLS #387/#418） ----------
# header v3/v4 的布局与 v0 不同（offset 36 不是 page_size ⇒ 不能按 v0 解析）；
# v3/v4 的 kernel 恒在 offset 4096（bootimg 规范：kernel_offset = 4096）。
python3 - "$OUT" <<'PY'
import sys, os, struct
out = sys.argv[1]
d = open(os.path.join(out, 'lenovo-y700g4-v3.img'), 'rb').read()
ks = struct.unpack_from('<I', d, 8)[0]
kv = struct.unpack_from('<I', d, 40)[0]
page = 4096 if kv >= 3 else struct.unpack_from('<I', d, 36)[0]
open(os.path.join(out, 'kernel.bin'), 'wb').write(d[page:page+ks])
PY
python3 "$REPO/ImageResources/mkbootimg.py" --kernel "$OUT/kernel.bin" --header_version 0 \
	--base 0x10000000 --kernel_offset 0x8000 --pagesize 4096 -o "$OUT/uefi-v0.img" \
	>>"$OUT/build.log" 2>&1

# ---------- manifest ----------
{
	echo "# uefi-build-variant manifest"
	echo "date=$(date -Is)"
	echo "repo=$REPO"
	echo "repo_head=$(git rev-parse HEAD)"
	echo "submodules=$(git submodule status | tr '\n' ';')"
	echo "clang=$(clang --version | head -1)"
	echo "python=$(python3 --version)"
	echo "uefi_base=$UEFI_BASE uefi_size=$UEFI_SIZE"
	echo "variant.ufsdxe=$UFSDXE variant.rmvmdxe=$RMVMDXE variant.shim=$SHIM"
	echo "patches=${PATCHES[*]:-none}"
	echo "worktree_after=$(git status --porcelain | tr '\n' ';')"
} > "$OUT/manifest.txt"
(cd "$OUT" && sha256sum SM8750_EFI.fd BootShim.bin kernel.bin uefi-v0.img > SHA256SUMS)
cat "$OUT/SHA256SUMS"
