#!/bin/bash
# q28-build-oldrep-pin.sh — E1 判定臂 vk108：**旧源码重编 + PINUTS**。
#
# 目的（reports/q28-storm-bias-audit-20261011.md §7.5 E1）：
#   oldK(vk94) 与 newK(vk104) 只在「构建身份（UTS_VERSION #N/日期 → .rodata 布局）+1 个 ADSP DT 提交」上不同。
#   本臂 = **旧源码 d02658e63** + a383cdb9 config + **PINUTS 钉死 localversion 串**
#         + vk94 的旧 ramdisk（ramdisk 已证与 STORM 无关，保持与 vk94 其余一致）。
#   ⇒ 与 vk94 的唯一差 = **构建身份（#N/日期 + LOCALVERSION_AUTO 标志）**。
#   vk108 GOOD  ≈ vk104 ⇒ 旧源码无罪，STORM 是构建身份/布局伪影（H1）。
#   vk108 STORM ⇒ 旧源码/DT 是轴（H2）。
#
# 不变量：源码 commit、.config（除 LOCALVERSION_AUTO）、ramdisk、cmdline 与 vk94 一致。
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden
cd "$ROOT"
BASE_COMMIT=${BASE_COMMIT:-d02658e63cf607e71231b077ddd73f42408463c0}
CONFIGFILE=${CONFIGFILE:-$ROOT/patches/config-before-fragment-20261011-155716.bak}   # a383cdb9
VERSION=${VERSION:-vk108-oldrep-pin}
BR=${BR:-q28/oldrep-pin}
PINUTS=${PINUTS:--vk64-gd02658e63cf6}
OLD_IMG=${OLD_IMG:-$ROOT/out/boot-elden-vk94.img}
LOG=$ROOT/logs/q28-build-$VERSION-$(date +%Y%m%d-%H%M%S).log
mkdir -p "$ROOT/logs"
exec > >(tee -a "$LOG") 2>&1
echo "### q28 build $VERSION start $(date '+%F %T') log=$LOG"

# --- pin config (a383cdb9) + PINUTS --------------------------------------
cp -f "$ROOT/linux/.config" "$ROOT/linux/.config.pre-oldrep"
cp -f "$CONFIGFILE" "$ROOT/linux/.config"
sed -i 's/^CONFIG_LOCALVERSION_AUTO=.*/CONFIG_LOCALVERSION_AUTO=n/' "$ROOT/linux/.config"
export LOCALVERSION="$PINUTS"
# 可选：强制 KBUILD_BUILD_VERSION（`#N`）以复现旧构建 banner 长度（E1'）。
if [ -n "${KBUILD_BUILD_VERSION:-}" ]; then
	export KBUILD_BUILD_VERSION
fi
if [ -n "${KBUILD_BUILD_TIMESTAMP:-}" ]; then
	export KBUILD_BUILD_TIMESTAMP
fi
echo "pinned config sha: $(sha256sum "$ROOT/linux/.config" | cut -d' ' -f1)  LOCALVERSION=$LOCALVERSION  KBUILD_BUILD_VERSION=${KBUILD_BUILD_VERSION:-auto}"

# --- branch at the OLD source commit -------------------------------------
cd "$ROOT/linux"
git checkout -B "$BR" "$BASE_COMMIT" || { echo "checkout failed"; exit 1; }
git checkout -- .
echo "HEAD: $(git log -1 --oneline)  dirty=$(git status --porcelain | wc -l)"

# --- build kernel + dtbs --------------------------------------------------
cd "$ROOT"
bash scripts/build-kernel.sh Image.gz dtbs || { echo "kernel build failed"; exit 1; }
echo "--- built UTS ---"
strings "$ROOT/linux/arch/arm64/boot/Image" | grep -m1 'Linux version'
strings "$ROOT/linux/arch/arm64/boot/Image" | grep -m1 -E '^#[0-9]+ SMP' || true

# --- repack with vk94's old ramdisk + vk94 cmdline ------------------------
RD=$ROOT/out/.rd-$VERSION
rm -rf "$RD"; mkdir -p "$RD"
python3 "$ROOT/tools/mkbootimg/unpack_bootimg.py" --boot_img "$OLD_IMG" --out "$RD" >/dev/null || { echo "unpack old img failed"; exit 1; }
python3 "$ROOT/tools/mkbootimg/mkbootimg.py" --header_version 2 \
	--os_version 15.0.0 --os_patch_level 2025-08 \
	--kernel "$ROOT/linux/arch/arm64/boot/Image.gz" \
	--ramdisk "$RD/ramdisk" \
	--dtb "$ROOT/linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb" \
	--cmdline "console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17 androidboot.slot_suffix=_b elden_nocamera=1" \
	--base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --second_offset 0xf00000 --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 \
	-o "$ROOT/out/boot-elden-$VERSION.img" || { echo "mkbootimg failed"; exit 1; }

# --- manifest -------------------------------------------------------------
KDIR="$ROOT/linux" RAMDISK_FILE="$RD/ramdisk" MKBOOTIMG_ARGS="--kernel $ROOT/linux/arch/arm64/boot/Image.gz --dtb $ROOT/linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb" \
	bash "$ROOT/scripts/build-manifest.sh" "$VERSION" "$ROOT/out/boot-elden-$VERSION.img" || echo "manifest failed"

# --- restore canonical tree state -----------------------------------------
cd "$ROOT/linux" && git checkout -q clean/base
cp -f "$ROOT/linux/.config.pre-oldrep" "$ROOT/linux/.config"
rm -f "$ROOT/linux/.config.pre-oldrep"
rm -rf "$RD"
echo "restored HEAD: $(git log -1 --oneline)  config sha: $(sha256sum .config | cut -d' ' -f1)"
echo "### done $(date '+%F %T')"; ls -l "$ROOT/out/boot-elden-$VERSION.img"
