#!/bin/bash
# check-abi-config.sh — 内核 .config 的 ABI 敏感项门禁（build/pack-time gate）。
#
# 为什么（2026-10-23 实受）：`CONFIG_SUSPEND` 差异会让 `struct dev_pm_info` 变大，
# 从而把 `struct device.of_node` 从偏移 624 推到 680（+56 B）。但 **vermagic 只比
# UTS 字符串**，两套模块树的 UTS 可以逐字相同 ⇒ 模块静默用错偏移读字段。
# 实测后果：
#   - `fastrpc` 读 `of_node`=NULL ⇒ `-EINVAL` ⇒ rpmsg 设备 add/remove 死循环
#     ⇒ dmesg 刷屏 2941 行/23 min + `/dev/fastrpc-*` 全缺 ⇒ SSC 传感器全废
#   - 用 `SUSPEND=y` 的 config 编出的内核上机「背光亮一下即掉电」（vk128/vk129 形态）
#
# 判据：把「会改变 struct 布局」的 config 项与参考 config 逐一比对。
# 参考 config 用 `--ref` 指定；默认取 patches/config-vk127-working-*（现役日常线 SSOT）。
#
# 用法：
#   scripts/check-abi-config.sh                      # 比 build/m1-73/.config
#   scripts/check-abi-config.sh path/to/.config
#   scripts/check-abi-config.sh --ref patches/config-daily-c1 build/m1-73/.config
#   SKIP_ABI_ASSERT=1 ...                            # 显式绕过（必须写明理由）
#
# 退出：0=一致；1=有差异（打印具体项）。
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}

# 会改变内核内 ABI / struct 布局的项。加新项时请附「改变了什么布局」。
ABI_KEYS=(
	CONFIG_SUSPEND            # struct dev_pm_info → struct device 整体尺寸
	CONFIG_PM_SLEEP           # 同上（dev_pm_info 成员集合）
	CONFIG_PM_SLEEP_SMP       # 同上
	CONFIG_PM                 # 同上
	CONFIG_PM_GENERIC_DOMAINS # genpd 指针进 struct device
	CONFIG_DEBUG_LOCK_ALLOC   # struct lockdep_map 进 struct device
	CONFIG_LOCKDEP            # 同上
	CONFIG_PROVE_LOCKING      # 同上
	CONFIG_NUMA               # struct device.numa_node
	CONFIG_HOTPLUG_CPU        # cpumask 尺寸（影响 per-cpu / device_pm）
	CONFIG_CPUMASK_OFFSTACK   # cpumask 指针 vs 数组
	CONFIG_NR_CPUS            # cpumask 尺寸
	CONFIG_PREEMPT            # struct preempt / task_struct 布局
	CONFIG_PREEMPT_COUNT
	CONFIG_PREEMPTION
	CONFIG_PREEMPT_RT
	CONFIG_ARM64_VA_BITS      # 地址空间假设
	CONFIG_ARM64_VA_BITS_39
	CONFIG_ARM64_VA_BITS_48
	CONFIG_ARM64_VA_BITS_52
	CONFIG_ARM64_4K_PAGES
	CONFIG_ARM64_16K_PAGES
	CONFIG_ARM64_64K_PAGES
	CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE
	CONFIG_CC_OPTIMIZE_FOR_SIZE
	CONFIG_SMP
	CONFIG_MODVERSIONS        # 有它才真正拦截符号/CRC 变化
)

REF=""
if [ "${1:-}" = "--ref" ]; then REF=${2:-}; shift 2; fi
CONF=${1:-$ROOT/build/m1-73/.config}

if [ "${SKIP_ABI_ASSERT:-0}" = 1 ]; then
	echo "[abi] SKIP_ABI_ASSERT=1 → 已显式绕过大 ABI 门禁" >&2
	exit 0
fi

if [ -z "$REF" ]; then
	# 默认参考：现役日常线 SSOT config（取最新一份）
	REF=$(ls -1t "$ROOT"/patches/config-vk127-working-* 2>/dev/null | head -1)
	[ -n "$REF" ] || REF=$(ls -1t "$ROOT"/patches/config-daily-* 2>/dev/null | head -1)
fi

[ -f "$CONF" ] || { echo "[abi] ❌ 目标 config 不存在：$CONF" >&2; exit 1; }
[ -f "$REF"  ] || { echo "[abi] ❌ 参考 config 不存在：$REF（用 --ref 指定）" >&2; exit 1; }

# 取某项的规范化值：`CONFIG_X=y` / `# CONFIG_X is not set` / 缺失 三种都归一为 3 类
getval() {
	local f=$1 k=$2
	if grep -qE "^$k=" "$f"; then
		grep -E "^$k=" "$f" | head -1 | sed -E "s/^$k=//"
	elif grep -qE "^# $k is not set" "$f"; then
		echo "__NOT_SET__"
	else
		echo "__ABSENT__"
	fi
}

echo "[abi] 目标: $CONF"
echo "[abi] 参考: $REF"
echo "[abi] ── ABI 敏感项比对 ──"

fail=0
for k in "${ABI_KEYS[@]}"; do
	a=$(getval "$CONF" "$k")
	b=$(getval "$REF"  "$k")
	if [ "$a" = "$b" ]; then
		printf '  [ok]   %-28s %s\n' "$k" "$a"
	else
		printf '  [FAIL] %-28s 目标=%s  参考=%s\n' "$k" "$a" "$b"
		fail=$((fail+1))
	fi
done

if [ "$fail" -eq 0 ]; then
	echo "[abi] ✅ ABI 敏感项与参考一致（${#ABI_KEYS[@]} 项）"
	exit 0
fi
cat >&2 <<'MSG'

[abi] ❌ ABI 敏感项与参考 config 不一致 —— 这样编出来的内核 **和机内模块树不兼容**。
      vermagic 只比 UTS 字符串，拦不住这种差异；症状是模块静默用错 struct 偏移：
        · fastrpc: `of_node` 读成 NULL → rpmsg add/remove 死循环 → dmesg 刷屏、
          `/dev/fastrpc-*` 全缺、SSC 传感器全废
        · 用 SUSPEND=y 编出的内核上机「背光亮一下即掉电」（vk128/vk129 形态）
      治法：把 .config 换回 SSOT（patches/config-vk127-working-*），或同步重编整套模块树。
      确要绕过：SKIP_ABI_ASSERT=1
MSG
exit 1
