#!/bin/bash
# q28-build-daily-id.sh — Q28 收尾：以「3 位构建号」新**构建身份**重编**日常镜像**。
#
# 背景（PITFALLS #192/#195、reports/q28-storm-bias-audit-20261011.md）：
#   冷起 GOOD/NOCARD/STORM 由**内核构建身份**（UTS_VERSION 里的 `#N`/日期长度 → .rodata 布局）决定：
#   `#60`（2 位，= 现役日常 vk94 的身份）臂 4 坏/2 好；3 位构建号臂 0 坏/12+（Fisher p≈0.005）。
#   治法：日常镜像用 3 位 `#N` 新身份重编 ⇒ 本脚本。
#   ⚠️ 更正（PITFALLS #217/#223，2026-10-12 深夜）：3 位身份是**偏置不是解**——
#   vk113-dailyid(#121) 真机冷起仍 L1FAIL，坏发按时间成簇、缓解不在镜像层。
#   本脚本仍按 3 位身份构建（降险），但**不得**据此认为 Q28 已解决。
#
# 单变量保证：与 `out/boot-elden-vk94.img`（现役日常）相比，
#   * ramdisk / DTB / cmdline  —— 取自 vk94 **原始镜像**，逐字节相同（脚本内断言 sha）
#   * 内核源提交 = d02658e63（= 日常内核源码）+ config a383cdb9（= 由 vk64 内核 ikconfig 复验一致）
#   * LOCALVERSION 钉死 = -vk64-gd02658e63cf6（CONFIG_LOCALVERSION_AUTO=n）⇒ 模块 vermagic 不变
#   ⇒ **唯一差异 = 内核构建身份（#N + 构建日期串）**。
#
# 用法: bash scripts/q28-build-daily-id.sh [BASE_IMG] [VERSION]
# 产出: out/boot-elden-<VERSION>.img + .manifest
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
BASE_IMG=${1:-${BASE_IMG:-out/boot-elden-vk94.img}}
VERSION=${2:-${VERSION:-vk113-dailyid}}
BASE_COMMIT=${BASE_COMMIT:-d02658e63cf607e71231b077ddd73f42408463c0}
CFG=${CFG:-patches/config-before-fragment-20261011-155716.bak}      # sha a383cdb9
PINUTS=${PINUTS:--vk64-gd02658e63cf6}
KBVER=${KBVER:-121}
KBTIME=${KBTIME:-Mon Oct 12 18:00:00 CST 2026}
WT=${WT:-/tmp/dailyid}
UNPACK=${UNPACK:-/tmp/vk94base}
CMDLINE=${CMDLINE:-console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17 androidboot.slot_suffix=_b elden_nocamera=1}
DTB_EXPECT=5d658a2ce48cdda9a0451aaef28b6c668fb76607f76e2f0648ee9194c0008c0d
RD_EXPECT=35823240fcd15b4b08e1219e9a849a9abaa997bca7c11fd7f3e6e477c9c0478c
LOG=$ROOT/logs/q28-build-$VERSION-$(date +%Y%m%d-%H%M%S).log
mkdir -p "$ROOT/logs"
exec > >(tee -a "$LOG") 2>&1
echo "### $VERSION (Q28 daily-id) start $(date '+%F %T')  log=$LOG"

[ -f "$BASE_IMG" ] || { echo "缺基准镜像 $BASE_IMG"; exit 1; }

# --- 1) 解包基准（ramdisk/DTB/cmdline 的唯一来源）--------------------------
rm -rf "$UNPACK"; mkdir -p "$UNPACK"
python3 tools/mkbootimg/unpack_bootimg.py --boot_img "$BASE_IMG" --out "$UNPACK" >/dev/null
BASE_DTB_SHA=$(sha256sum "$UNPACK/dtb" | cut -d' ' -f1)
BASE_RD_SHA=$(sha256sum "$UNPACK/ramdisk" | cut -d' ' -f1)
BASE_K_SHA=$(sha256sum "$UNPACK/kernel" | cut -d' ' -f1)
echo "[1] 基准 $BASE_IMG  dtb=$BASE_DTB_SHA  ramdisk=$BASE_RD_SHA  kernel(packed)=$BASE_K_SHA"
[ "$BASE_DTB_SHA" = "$DTB_EXPECT" ] || { echo "❌ 基准 DTB 与 vk94 记录不符"; exit 2; }
[ "$BASE_RD_SHA"  = "$RD_EXPECT"  ] || { echo "❌ 基准 ramdisk 与 vk94 记录不符"; exit 2; }

# --- 2) 干净 worktree + 钉 config/UTS/构建身份 -----------------------------
# WT_FRESH=1 → 强制重建 worktree（全新编译）；默认复用同 commit 的既有 worktree（省一次全量编译）。
WT_HEAD=$(git -C "$WT" rev-parse HEAD 2>/dev/null || echo none)
if [ "${WT_FRESH:-0}" = 1 ] || [ "$WT_HEAD" != "$BASE_COMMIT" ] || [ ! -f "$WT/arch/arm64/boot/Image.gz" ]; then
	echo "[2] 重建 worktree（WT_FRESH=${WT_FRESH:-0} 现有 HEAD=$WT_HEAD）"
	git -C linux worktree remove --force "$WT" >/dev/null 2>&1 || true
	git -C linux worktree prune
	rm -rf "$WT"
	git -C linux worktree add --detach "$WT" "$BASE_COMMIT" >/dev/null
else
	echo "[2] 复用既有 worktree $WT（HEAD=$WT_HEAD）"
fi
# --- 2b) 可选：应用内核补丁（PATCH=patches/xxx.patch）——用于「日常组合 + 机制修复」臂 ---
git -C "$WT" checkout -- . 2>/dev/null || true     # 清掉上一次实验残留
if [ -n "${PATCH:-}" ]; then
	PP="$ROOT/$PATCH"
	[ -f "$PP" ] || { echo "❌ 补丁不存在 $PP"; exit 2; }
	git -C "$WT" apply "$PP" || { echo "❌ 补丁应用失败：$PATCH"; exit 2; }
	echo "[2b] 已应用 $PATCH sha=$(sha256sum "$PP" | cut -c1-12)"
	git -C "$WT" --no-pager diff --stat | tail -3
fi

cp -f "$CFG" "$WT/.config"
sed -i 's/^CONFIG_LOCALVERSION_AUTO=.*/CONFIG_LOCALVERSION_AUTO=n/' "$WT/.config"
cp -f linux/.version "$WT/.version" 2>/dev/null || true   # 继承计数器（下界，见 KBVER 覆盖）
CFG_SHA=$(sha256sum "$WT/.config" | cut -d' ' -f1)
GOOD_CFG_SHA=$(sha256sum "$CFG" | cut -d' ' -f1)
KHEAD=$(git -C "$WT" rev-parse --short HEAD)
echo "[2] worktree=$WT  HEAD=$KHEAD  好档 config sha=$GOOD_CFG_SHA  钉死后 config sha=$CFG_SHA"
EXPECT_CFG=${EXPECT_CFG:-a383cdb99dfe}   # 允许派生 config（如 +C1 fragment）；默认仍钉好档
[ "${GOOD_CFG_SHA:0:12}" = "$EXPECT_CFG" ] || { echo "❌ 源 config 前 12 位 $GOOD_CFG_SHA ≠ $EXPECT_CFG"; exit 2; }
KHEAD_FULL=$(git -C "$WT" rev-parse HEAD); BASE_FULL=$(git -C linux rev-parse "$BASE_COMMIT")
[ "$KHEAD_FULL" = "$BASE_FULL" ] || { echo "❌ worktree HEAD=$KHEAD_FULL ≠ $BASE_FULL"; exit 2; }

echo "[2] 构建身份：KBUILD_BUILD_VERSION=$KBVER  KBUILD_BUILD_TIMESTAMP=$KBTIME  LOCALVERSION=$PINUTS"
. "$ROOT/scripts/env-build.sh"
export KBUILD_BUILD_VERSION="$KBVER" KBUILD_BUILD_TIMESTAMP="$KBTIME" LOCALVERSION="$PINUTS"
make -C "$WT" -j"$(nproc)" ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" LOCALVERSION="$PINUTS" Image.gz

KIMG="$WT/arch/arm64/boot/Image.gz"
SMAP="$WT/System.map"

# --- 3) 编后硬门（对齐 assert-kernel-sane.sh，但对象是 worktree）-----------
for c in CONFIG_ARCH_QCOM CONFIG_DRM_MSM CONFIG_DRM_MSM_DSI; do
	grep -qE "^$c=y" "$WT/.config" || { echo "❌ $c 缺失（死内核）"; exit 3; }
done
for s in gcc_sm8750 msm_dsi_host_bonded_cmd_trigger qcom_rpmh; do
	grep -q "$s" "$SMAP" || { echo "❌ System.map 缺 $s（死内核 #162）"; exit 3; }
done
echo "[3] ✅ config 锚点 / System.map 符号通过"

UTS=$(python3 - "$KIMG" <<'PY'
import sys, zlib, re
d = open(sys.argv[1],'rb').read()
i = d.find(b'\x1f\x8b\x08')
k = zlib.decompressobj(16+zlib.MAX_WBITS).decompress(d[i:], 128<<20)
m = re.search(rb'Linux version [^\x00]{0,400}', k)
print((m.group(0).decode(errors='replace') if m else '').strip())
PY
)
echo "[3] UTS: $UTS"
echo "$UTS" | grep -q 'Linux version 7.2.0-debug-vk64-gd02658e63cf6 (' || { echo "❌ UTS release 串不符"; exit 3; }
# 构建号权威来源 = 生成的 utsversion.h（UTS_VERSION 串里就是 "#N SMP ..."）
echo "[3] utsversion.h: $(sed -n 's/^#define UTS_VERSION "\(.*\)"/\1/p' "$WT/include/generated/utsversion.h")"
echo "[3] utsrelease.h: $(sed -n 's/^#define UTS_RELEASE "\(.*\)"/\1/p' "$WT/include/generated/utsrelease.h")"
BN=$(sed -n 's/^#define UTS_VERSION "#\([0-9]*\) .*/\1/p' "$WT/include/generated/utsversion.h")
[ -n "$BN" ] || BN=$(echo "$UTS" | sed -n 's/.*) #\([0-9]*\) SMP.*/\1/p')
[ -n "$BN" ] || { echo "❌ 取不到 #N"; exit 3; }
[ "${#BN}" -eq 3 ] || { echo "❌ 构建号 $BN 不是 3 位（#195 治法要求 3 位）"; exit 3; }
echo "[3] ✅ 3 位构建号 #$BN；UTS 长度=${#UTS}"

# --- 4) 重打包（ramdisk/DTB/cmdline 用 vk94 原件）------------------------
SKIP_KERNEL_ASSERT=1 KERNEL_IMG="$KIMG" DTB_FILE="$UNPACK/dtb" RAMDISK="$UNPACK/ramdisk" \
	CMDLINE_OVERRIDE="$CMDLINE" VERSION="$VERSION" KDIR="$WT" bash scripts/build-boot.sh
rm -f out/boot-elden.img   # build-boot.sh 顺手写的无版本号拷贝（check-doctor WARN）

# --- 5) 独立复验 ---------------------------------------------------------
rm -rf /tmp/dailyidcheck; mkdir -p /tmp/dailyidcheck
python3 tools/mkbootimg/unpack_bootimg.py --boot_img "out/boot-elden-$VERSION.img" --out /tmp/dailyidcheck >/dev/null
NEW_DTB=$(sha256sum /tmp/dailyidcheck/dtb | cut -d' ' -f1)
NEW_RD=$(sha256sum /tmp/dailyidcheck/ramdisk | cut -d' ' -f1)
NEW_K=$(sha256sum /tmp/dailyidcheck/kernel | cut -d' ' -f1)
[ "$NEW_DTB" = "$BASE_DTB_SHA" ] || { echo "❌ 新镜像 DTB ≠ 基准"; exit 4; }
[ "$NEW_RD"  = "$BASE_RD_SHA"  ] || { echo "❌ 新镜像 ramdisk ≠ 基准"; exit 4; }
SZ=$(stat -c%s "out/boot-elden-$VERSION.img")
[ "$SZ" -le 100663296 ] || { echo "❌ 镜像 $SZ B > 96 MiB"; exit 4; }
echo "[5] ✅ DTB/ramdisk 与 vk94 逐字节同；新 kernel(packed)=$NEW_K；image=$SZ B ($((SZ/1024/1024)) MiB)"

echo "[5] 内核载荷 vs vk94："
python3 - out/boot-elden-vk94.img "out/boot-elden-$VERSION.img" <<'PY'
import sys, zlib, hashlib, re
def load(p):
    d = open(p,'rb').read(); i = d.find(b'\x1f\x8b\x08')
    k = zlib.decompressobj(16+zlib.MAX_WBITS).decompress(d[i:], 128<<20)
    m = re.search(rb'Linux version [^\x00]{0,400}', k)
    return k, (m.group(0).decode(errors='replace') if m else '')
a, ua = load(sys.argv[1]); b, ub = load(sys.argv[2])
print(f"  vk94  payload sha256={hashlib.sha256(a).hexdigest()}  UTS={ua}")
print(f"  new   payload sha256={hashlib.sha256(b).hexdigest()}  UTS={ub}")
print(f"  size  vk94={len(a)} new={len(b)} diff={abs(len(a)-len(b))}")
n = sum(1 for x, y in zip(a, b) if x != y) + abs(len(a)-len(b))
print(f"  差异字节 = {n} ({100.0*n/max(len(a),len(b)):.3f}%)")
PY
echo "### $VERSION done $(date '+%F %T')"
grep -E "^(kernel_release|kernel_uts|kernel_payload_sha256|dtb_packed_sha256|ramdisk_sha256|config_sha256|image_sha256|image_size|verification)=" "out/boot-elden-$VERSION.manifest" || true
