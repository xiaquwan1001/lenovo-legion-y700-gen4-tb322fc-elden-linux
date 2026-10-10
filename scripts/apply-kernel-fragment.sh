#!/bin/bash
# apply-kernel-fragment.sh — 把配置片段合并进内核树 .config，并导出新快照
#
# 用法：
#   FRAG=patches/<fragment>.config bash apply-kernel-fragment.sh
#   FRAG=... SNAP=patches/<snapshot> bash apply-kernel-fragment.sh
#   （未指定 FRAG 会列出可选项并退出；不再有隐式默认片段/SNAP）
#
# 行为：
#   1. 备份当前 .config 到 patches/config-before-fragment-<时间>.bak
#   2. merge_config.sh 合并片段
#   3. 若有交叉 gcc，跑 make olddefconfig 解析依赖，并回钉 ARCH_QCOM 等锚点
#   4. 导出新快照（SNAP；默认 patches/config-<时间戳>）
set -euo pipefail

K="${K:-$HOME/y700-elden/linux}"
if [ -z "${FRAG:-}" ]; then
	cat >&2 <<'EOF'
usage: FRAG=patches/<fragment>.config [SNAP=patches/<snapshot>] bash apply-kernel-fragment.sh

未指定 FRAG（要合并的配置片段）。可用片段：
EOF
	ls -1 "${PATCHES:-$HOME/y700-elden/patches}"/fragment-*.config 2>/dev/null | sed 's/^/  /' >&2 || true
	echo "（旧默认指向 vk28 netd 片段，已移除——裸跑会静默覆盖旧快照，见 PITFALLS #162 同类教训）" >&2
	exit 2
fi
FRAG="$FRAG"
PATCHES="${PATCHES:-$HOME/y700-elden/patches}"
# SNAP 默认改为时间戳路径，避免无声覆盖历史快照（旧默认硬编码 config-vk28-netd-ipv6-xfrm）。
SNAP="${SNAP:-$PATCHES/config-$(date +%Y%m%d-%H%M%S)}"
CROSS="${CROSS:-aarch64-linux-gnu-}"
export PATH="$HOME/bin:$PATH"   # 本机 gcc 只有版本化名，~/bin 里放了 aarch64-linux-gnu-gcc 软链

log()  { echo -e "\033[1;36m[kconf]\033[0m $*"; }
warn() { echo -e "\033[1;33m[kconf] ⚠️  $*\033[0m"; }
die()  { echo -e "\033[1;31m[kconf] ❌ $*\033[0m" >&2; exit 1; }

[ -d "$K" ]     || die "内核树不存在: $K"
[ -f "$FRAG" ]  || die "片段不存在: $FRAG"
[ -f "$K/.config" ] || die "$K/.config 不存在（先 make defconfig）"
[ -x "$K/scripts/kconfig/merge_config.sh" ] || die "缺 merge_config.sh"

cd "$K"
BK="$PATCHES/config-before-fragment-$(date +%Y%m%d-%H%M%S).bak"
cp -a .config "$BK"
log "已备份当前 .config → $BK"

log "合并片段: $(basename "$FRAG")"
ARCH=arm64 CROSS_COMPILE="$CROSS" ./scripts/kconfig/merge_config.sh -m -O . .config "$FRAG"

if command -v "${CROSS}gcc" >/dev/null 2>&1; then
  log "解析依赖：make olddefconfig"
  make ARCH=arm64 CROSS_COMPILE="$CROSS" olddefconfig >/dev/null
else
  warn "没装 ${CROSS}gcc → 跳过 olddefconfig（依赖未解析）"
  warn "装好后跑： sudo apt install -y gcc-15-aarch64-linux-gnu"
  warn "然后： cd $K && make ARCH=arm64 CROSS_COMPILE=$CROSS olddefconfig"
fi

# PITFALLS/FAILURE 2026-10-10: `make olddefconfig` silently DROPS CONFIG_ARCH_QCOM
# (which cascades away the whole MSM / DRM_MSM / dispcc / gcc_sm8750 stack),
# producing a kernel that builds fine but has ZERO qcom symbols on-device ->
# a dead image (vk81/vk82/vk83 were bricked this way). Re-pin the platform
# anchors olddefconfig is known to strip, WITHOUT re-running olddefconfig
# (the build path never runs olddefconfig, so the over-specified line sticks).
repin() { # $1 = CONFIG_...
  grep -qE "^${1}=y" .config || { warn "olddefconfig 丢了 ${1}=y → 回钉"; printf '%s=y\n' "$1" >> .config; }
}
for anchor in CONFIG_ARCH_QCOM CONFIG_DRM_MSM CONFIG_DRM_MSM_DSI CONFIG_SMD_RPM CONFIG_QCOM_RPMHPD; do
  grep -qE "^${anchor}=" "$BK" && repin "$anchor"   # only re-pin what the pre-fragment config had set
done
# Hard guard: if the pre-fragment backup had ARCH_QCOM=y but we still lack it, abort.
if grep -qE '^CONFIG_ARCH_QCOM=y' "$BK" && ! grep -qE '^CONFIG_ARCH_QCOM=y' .config; then
  cp -a "$BK" .config
  die "olddefconfig 仍删掉了 CONFIG_ARCH_QCOM，已回滚到备份 $BK。请检查 $FRAG 是否 unselected 了 ARCH_QCOM 的依赖。"
fi

cp -a .config "$SNAP"
log "新快照: $SNAP"

echo
log "校验关键符号："
for s in XFRM XFRM_USER IP6_NF_IPTABLES IP6_NF_FILTER IP6_NF_NAT NETFILTER_XT_MATCH_OWNER; do
  printf "  %-30s %s\n" "$s" "$(grep -E "^CONFIG_${s}=" .config | head -1 || echo '# 未生效')"
done
echo
log "下一步重建内核：  bash $(dirname "$0")/build-kernel.sh && bash $(dirname "$0")/build-boot.sh"
