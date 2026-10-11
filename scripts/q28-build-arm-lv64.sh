#!/bin/bash
# q28-build-arm-lv64.sh — build one Q28 arm (base|round) as a TRUE single-variable
# pair on commit d02658e63 with LOCALVERSION=-vk64 and the SAME modular-overlay
# ramdisk recipe (so /init timing is identical across arms — PITFALLS #172/§h).
#
#   ARM=base  -> clean/base                       -> out/boot-elden-vk97-base-lv64.img
#   ARM=round -> clean/base + round byte-clk patch -> out/boot-elden-vk96-round-lv64.img
#
# Controls: same commit, same .config a383cdb9, same LOCALVERSION=-vk64, same
# ramdisk structure; only difference = the round change (and its rebuilt, vermagic-
# matched modules).  Round patch is committed so UTS stays clean and exactly 12 hex.
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden
cd "$ROOT"
ARM=${ARM:-round}
BASE_COMMIT=d02658e63cf607e71231b077ddd73f42408463c0
PATCH=$ROOT/patches/q28-round-vk86.patch
GOLDEN=$ROOT/out/rootfs-base-golden.cpio.gz
CLEANCFG=$ROOT/patches/config-before-fragment-20261011-155716.bak   # sha a383cdb9
case "$ARM" in
	base)  VERSION=vk97-base-lv64 ;  BR=q28/base-lv64 ;  APPLY=0 ; PATCH=$ROOT/patches/q28-round-vk86.patch ; MSG="" ;;
	base2) VERSION=vk100-base2-lv64 ; BR=q28/base2-lv64 ; APPLY=0 ; PATCH=$ROOT/patches/q28-round-vk86.patch ; MSG="" ;;
	round) VERSION=vk96-round-lv64 ; BR=q28/round-lv64 ; APPLY=1 ; PATCH=$ROOT/patches/q28-round-vk86.patch ; MSG="exp(q28): round byte clk after reparenting to PHY PLL (msg46766)" ;;
	sham)  VERSION=vk98-sham-lv64 ;  BR=q28/sham-lv64 ;  APPLY=1 ; PATCH=$ROOT/patches/q28-sham-noop.patch ; MSG="exp(q28): sham no-op (clk_round_rate query + pr_info, no assignment)" ;;
	sham2) VERSION=vk99-sham2-lv64 ; BR=q28/sham2-lv64 ; APPLY=1 ; PATCH=$ROOT/patches/q28-sham2-noop.patch ; MSG="exp(q28): sham2 no-op (constant pr_info only, no clock API)" ;;
	empty) VERSION=vk101-empty-lv64 ; BR=q28/empty-lv64 ; APPLY=0 ; PATCH=$ROOT/patches/q28-round-vk86.patch ; MSG="" ;;
	*) echo "ARM must be base|round|sham"; exit 2 ;;
esac
LOG=$ROOT/logs/q28-build-$VERSION-$(date +%Y%m%d-%H%M%S).log
mkdir -p "$ROOT/logs"
exec > >(tee -a "$LOG") 2>&1
echo "### q28 build $VERSION (ARM=$ARM) start $(date '+%F %T')  log=$LOG"

export LOCALVERSION=-vk64

# --- pin the clean config --------------------------------------------------
cp -f "$ROOT/linux/.config" "$ROOT/linux/.config.pre-q28arm"
cp -f "$CLEANCFG" "$ROOT/linux/.config"
echo "pinned config sha: $(sha256sum "$ROOT/linux/.config" | cut -d' ' -f1)"

# --- branch + optional patch ----------------------------------------------
cd "$ROOT/linux"
git checkout -B "$BR" "$BASE_COMMIT" || { echo "checkout failed"; exit 1; }
git checkout -- .
if [ "$APPLY" = 1 ]; then
	git apply "$PATCH" || { echo "patch apply failed"; exit 1; }
	git commit -aqm "$MSG" || { echo "commit failed"; exit 1; }
fi
# empty arm: zero code delta, only the git HEAD sha changes (UTS scm part)
if [ "$ARM" = empty ]; then
	git commit -q --allow-empty -m "chore(q28): empty commit (sha-only change, no code delta)" \
		|| { echo "empty commit failed"; exit 1; }
fi
echo "HEAD: $(git log -1 --oneline)  state=$(git status --porcelain | wc -l) modified"

# --- build kernel + modules ------------------------------------------------
cd "$ROOT"
bash scripts/build-kernel.sh Image.gz dtbs modules || { echo "kernel build failed"; exit 1; }

STAGE=$ROOT/out/modstage-$VERSION
rm -rf "$STAGE"
( cd "$ROOT/linux" && make -j"$(nproc)" ARCH=arm64 \
	CROSS_COMPILE="ccache aarch64-linux-gnu-" LOCALVERSION="$LOCALVERSION" \
	modules_install INSTALL_MOD_PATH="$STAGE" ) || { echo "modules_install failed"; exit 1; }
KV=$(cd "$ROOT/linux" && make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
	LOCALVERSION="$LOCALVERSION" kernelrelease | tr -d '\r')
echo "--- KV=$KV"

# --- modular overlay ramdisk + boot.img ------------------------------------
KV="$KV" STAGE="$STAGE" BASE="$GOLDEN" bash scripts/build-modular-overlay.sh \
	|| { echo "modular overlay failed"; exit 1; }
cp -a "$ROOT/out/rootfs-overlaid-modular.cpio.gz" \
	"$ROOT/out/rootfs-overlaid-modular-$VERSION.cpio.gz"

VERSION="$VERSION" RAMDISK="$ROOT/out/rootfs-overlaid-modular-$VERSION.cpio.gz" \
	bash scripts/build-boot.sh || { echo "packaging failed"; exit 1; }

# --- restore canonical tree state ------------------------------------------
cd "$ROOT/linux" && git checkout -q clean/base
cp -f "$ROOT/linux/.config.pre-q28arm" "$ROOT/linux/.config"
rm -f "$ROOT/linux/.config.pre-q28arm"
echo "restored .config sha: $(sha256sum "$ROOT/linux/.config" | cut -d' ' -f1)"
echo "### q28 build $VERSION done $(date '+%F %T')"
ls -l "$ROOT/out/boot-elden-$VERSION.img" 2>/dev/null
grep -E "kernel_uts=|config_sha256=|ramdisk_sha256=|dtb_packed_sha256=|image_sha256=|image_size=" \
	"$ROOT/out/boot-elden-$VERSION.manifest" 2>/dev/null
