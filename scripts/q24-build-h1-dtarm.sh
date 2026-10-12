#!/bin/bash
# q24-build-h1-dtarm.sh — 构建 Q24 **H1 DT 臂**（cambist 恢复上游 mainline MMCX+MX）的 DTB-only 镜像。
#
# 单变量保证：内核载荷 / ramdisk / cmdline 与基准台架 out/boot-elden-lv64-nocam.img **逐字节相同**，
#   唯一差异 = DTB（sm8750.dtsi 的 cambistmclkcc 节点 power-domains/required-opps，见
#   patches/q24-h1-cambist-dt.patch）⇒ 内核 UTS 逐字不变（`7.2.0-debug-vk64-gd02658e63cf6`）
#   ⇒ 保住 Q28 GOOD 构建身份（PITFALLS #192/#195 的观察者效应）。
#
# 步骤（可复现，含**控制组**）：
#   1) 解包基准镜像 → kernel / ramdisk / dtb
#   2) 在 d02658e63 的**干净 worktree** 上重建 DTB ⇒ 必须与基准镜像里的 DTB **逐字节相同**（控制组）
#   3) 应用 H1 patch → 重建 DTB（sha 改变，且 dtc 反编译 diff 只应命中 cambist 节点）
#   4) 用同一个 kernel/ramdisk/cmdline + H1 DTB 重打包
#
# 用法: bash scripts/q24-build-h1-dtarm.sh [BASE_IMG] [VERSION]
# 产出: out/boot-elden-<VERSION>.img + .manifest
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
BASE=${1:-out/boot-elden-lv64-nocam.img}
VERSION=${2:-vk112-h1-dtbmmcxmx}
BASE_COMMIT=d02658e63cf607e71231b077ddd73f42408463c0
CFG=patches/config-before-fragment-20261011-155716.bak   # sha a383cdb9（好档）
WT=${WT:-/tmp/h1dt}
UNPACK=${UNPACK:-/tmp/h1unpack}
CMDLINE_H1=${CMDLINE_H1:-console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17 androidboot.slot_suffix=_b elden_nocamera=1}

[ -f "$BASE" ] || { echo "缺基准镜像 $BASE"; exit 1; }

# --- 1) 解包基准 -----------------------------------------------------------
rm -rf "$UNPACK"; mkdir -p "$UNPACK"
python3 tools/mkbootimg/unpack_bootimg.py --boot_img "$BASE" --out "$UNPACK" >/dev/null
BASE_DTB_SHA=$(sha256sum "$UNPACK/dtb" | cut -d' ' -f1)
echo "[1] 基准 DTB sha=$BASE_DTB_SHA"

# --- 2) 干净 worktree + 控制组 DTB -----------------------------------------
rm -rf "$WT"
git -C linux worktree add --detach "$WT" "$BASE_COMMIT" >/dev/null 2>&1 || true
cp -f "$CFG" "$WT/.config"
make -C "$WT" -j"$(nproc)" ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" LOCALVERSION="-vk64" \
  qcom/sm8750-lenovo-elden.dtb >/dev/null
CTRL_SHA=$(sha256sum "$WT/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb" | cut -d' ' -f1)
echo "[2] 控制组 DTB sha=$CTRL_SHA"
[ "$CTRL_SHA" = "$BASE_DTB_SHA" ] || { echo "❌ 控制组未逐字节复现基准 DTB ⇒ 工具链/提交不符，停止"; exit 2; }

# --- 3) H1 patch + 重建 ----------------------------------------------------
if git -C "$WT" apply patches/q24-h1-cambist-dt.patch 2>/dev/null; then echo "[3] patch 已应用"; else echo "[3] patch 已应用过，跳过"; fi
make -C "$WT" -j"$(nproc)" ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" LOCALVERSION="-vk64" \
  qcom/sm8750-lenovo-elden.dtb >/dev/null
H1_DTB=$WT/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
H1_SHA=$(sha256sum "$H1_DTB" | cut -d' ' -f1)
echo "[3] H1 DTB sha=$H1_SHA"
[ "$H1_SHA" != "$BASE_DTB_SHA" ] || { echo "❌ H1 DTB 与基准相同（patch 未生效）"; exit 2; }
DTC=$WT/scripts/dtc/dtc
"$DTC" -I dtb -O dts "$UNPACK/dtb" -o /tmp/dt-base.dts 2>/dev/null
"$DTC" -I dtb -O dts "$H1_DTB" -o /tmp/dt-h1.dts 2>/dev/null
echo "[3] dtc diff 行数（期望 6）: $(diff /tmp/dt-base.dts /tmp/dt-h1.dts | wc -l)"
diff -u /tmp/dt-base.dts /tmp/dt-h1.dts | head -20

# --- 4) 重打包（同 kernel/ramdisk/cmdline）--------------------------------
SKIP_KERNEL_ASSERT=1 KERNEL_IMG="$UNPACK/kernel" DTB_FILE="$H1_DTB" RAMDISK="$UNPACK/ramdisk" \
  CMDLINE_OVERRIDE="$CMDLINE_H1" VERSION="$VERSION" bash scripts/build-boot.sh
rm -f out/boot-elden.img   # build-boot.sh 会顺手写一个无版本号拷贝（check-doctor unversioned WARN）

# --- 5) 独立复验 -----------------------------------------------------------
rm -rf /tmp/h1check; mkdir -p /tmp/h1check
python3 tools/mkbootimg/unpack_bootimg.py --boot_img "out/boot-elden-$VERSION.img" --out /tmp/h1check >/dev/null
echo "[5] 载荷对比（kernel/ramdisk 应与基准逐字节相同；dtb 应为 H1）"
sha256sum /tmp/h1check/kernel "$UNPACK/kernel" /tmp/h1check/ramdisk "$UNPACK/ramdisk" /tmp/h1check/dtb | sed "s#$ROOT/##"
