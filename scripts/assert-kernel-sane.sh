#!/bin/bash
# assert-kernel-sane.sh — 打包前的「内核身份 / 存活」硬门（pack-time gate）。
#
# 为什么（PITFALLS #162）：`make olddefconfig` 会静默删掉 CONFIG_ARCH_QCOM，
# 连带 DRM_MSM/DSI/时钟 全没——这样的 Image **能编过、能打包**，但上机永不可能点屏。
# vk81/82/83 就是死在这条上（编后才发现，且 manifest 被手写旁路、事后无从对账）。
# 本脚本把「死内核」和「陈旧内核」在**打包前**挡下，而不是等上机。
#
# 用法：
#   scripts/assert-kernel-sane.sh [kernel-image]      # 默认 $KDIR/arch/arm64/boot/Image.gz
#   KDIR=build/m1-73 scripts/assert-kernel-sane.sh     # 对重放/非默认树做闸门
#   SKIP_KERNEL_ASSERT=1 ...                          # 显式绕过（请写明理由）
#
# 退出：0=通过；1=不通过（已打印具体原因）。
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
. "$ROOT/scripts/env-build.sh"

# KDIR lets the gate run against a replay/out-of-tree kernel tree (T3/T4 replay
# lives in build/m1-73 rather than the default geekidos checkout).
KDIR=${KDIR:-$ROOT/linux}
KIMG=${1:-$KDIR/arch/arm64/boot/Image.gz}
CONF=$KDIR/.config
SMAP=$KDIR/System.map

if [ "${SKIP_KERNEL_ASSERT:-0}" = 1 ]; then
	echo "[assert] SKIP_KERNEL_ASSERT=1 → 已显式绕过内核闸门（请确保你知道自己在做什么）" >&2
	exit 0
fi

fail=0
die() { echo "[assert] ❌ $*" >&2; fail=1; }

# --- 1. .config 平台锚点（死内核判据）------------------------------------
[ -f "$CONF" ] || die ".config 不存在（$CONF）"
for c in CONFIG_ARCH_QCOM CONFIG_DRM_MSM CONFIG_DRM_MSM_DSI; do
	grep -qE "^$c=y" "$CONF" || die "$CONF 缺 $c=y → olddefconfig 腐化？从 patches/config-before-fragment-*.bak 恢复后重编"
done

# --- 1b. ABI 敏感项：编出来的内核必须和机内模块树兼容 ----------------------
# CONFIG_SUSPEND 之类的差异会把 struct device.of_node 从 624 推到 680，
# 而 vermagic 只比 UTS 字符串拦不住 ⇒ 模块静默用错偏移（fastrpc 刷屏/传感器全废、
# 或上机「背光亮一下即掉电」）。详见 scripts/check-abi-config.sh 头注释。
if [ -f "$CONF" ]; then
	if ! bash "$ROOT/scripts/check-abi-config.sh" "$CONF" >/tmp/abi-gate.$$ 2>&1; then
		sed -n '1,200p' /tmp/abi-gate.$$ >&2
		rm -f /tmp/abi-gate.$$
		die "ABI 敏感项与参考 config 不一致（见上）→ 模块树会静默失效"
	else
		[ -n "${VERBOSE:-}" ] && sed -n '1,200p' /tmp/abi-gate.$$
		grep -q 'ABI 敏感项与参考一致' /tmp/abi-gate.$$ && echo "[assert] ✅ ABI 敏感项一致（$(grep -c '\[ok\]' /tmp/abi-gate.$$) 项）"
	fi
	rm -f /tmp/abi-gate.$$
fi

# --- 2. System.map 符号锚点（平台驱动真的链进去了）------------------------
if [ -f "$SMAP" ]; then
	for s in gcc_sm8750 msm_dsi_host_bonded_cmd_trigger qcom_rpmh; do
		grep -q "$s" "$SMAP" || die "System.map 缺符号 '$s' → 无 QCOM 驱动的死内核（#162）"
	done
else
	die "System.map 不存在 → 先跑 scripts/build-kernel.sh"
fi

# --- 3. 内核镜像存在 + UTS 与树自称一致 -----------------------------------
if [ ! -f "$KIMG" ]; then
	die "缺内核镜像 $KIMG → 先跑 scripts/build-kernel.sh Image.gz"
else
	KV=$(kbuild -s kernelrelease 2>/dev/null | tr -d '\r' || echo "")
	UTS=$(python3 - "$KIMG" <<'PY' 2>/dev/null || true
import sys, zlib, re
try:
    d = open(sys.argv[1], 'rb').read()
    i = d.find(b'\x1f\x8b\x08')
    k = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(d[i:], 128 << 20)
    m = re.search(rb'Linux version (\S+)', k)
    print(m.group(1).decode() if m else "")
except Exception:
    pass
PY
)
	if [ -z "$KV" ]; then
		echo "[assert] ⚠️ 无法取 tree kernelrelease（缺少交叉编译器？）→ 跳过 UTS 对齐检查" >&2
	elif [ -z "$UTS" ]; then
		die "无法从 $KIMG 解出 UTS 串（不是 gzip Image？）"
	elif [ "$KV" != "$UTS" ]; then
		die "内核镜像 UTS=$UTS ≠ 树自称=$KV → 打包的是**陈旧/异树**内核（#131/#160 同类）"
	fi
fi

# --- 4. 陈旧检测：仅对「树自己编的默认 Image.gz」有效 -----------------------
# 该项用 mtime(KIMG) < mtime(System.map) 判「是否在改完源码后又重编」。它只在 KIMG 就是
# 本树默认产物时成立；当调用方显式 KERNEL_IMG=<外部预编内核> 时（mtime 与树无关），
# 该判据是假阳性 —— 此时的正确闸门是上面的 UTS 对齐 + config 锚点 + System.map 符号。
KIMG_DEFAULT="$KDIR/arch/arm64/boot/Image.gz"
if [ "$KIMG" = "$KIMG_DEFAULT" ] && [ -f "$KIMG" ] && [ -f "$SMAP" ] && [ "$KIMG" -ot "$SMAP" ]; then
	die "$KIMG 比 System.map 旧 → 正在打包上一次构建的内核；重跑 scripts/build-kernel.sh Image.gz"
elif [ "$KIMG" != "$KIMG_DEFAULT" ]; then
	echo "[assert] ℹ️ KIMG=$KIMG 非本树默认产物 → 跳过 mtime 陈旧检测（依赖 UTS 对齐保证身份）"
fi

if [ "$fail" -eq 0 ]; then
	echo "[assert] ✅ 内核闸门通过：config 锚点 / System.map 符号 / UTS 对齐 / 非陈旧（$KIMG）"
	exit 0
fi
echo "[assert] 打包已阻止。确要绕过：SKIP_KERNEL_ASSERT=1" >&2
exit 1
