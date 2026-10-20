#!/bin/bash
# switch-kernel-abi.sh — 在内核「ABI 变体」之间原子切换（内核镜像 + 模块树一起换）
#
# 为什么需要这个脚本（PITFALLS #355，2026-10-20 实受）：
#   vk127（CONFIG_SUSPEND=n）与 vk129（CONFIG_PM_SLEEP=y）的 **UTS 字符串完全相同**
#   （都是 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty），所以两者共用同一个
#   /lib/modules/<UTS> 路径 —— 但它们的 ABI 不同：
#       struct dev_pm_info 随 CONFIG_PM_SLEEP 变大小
#       ⇒ dev->fwnode 偏移 632(vk127) vs 688(vk129)，差 56 字节
#       ⇒ 模块与内核错配会读到错误偏移，启动 0.55 s panic（coresight/cscfg）
#   而 CONFIG_MODVERSIONS 未开 ⇒ 没有 CRC 门，错配**静默**加载。
#
#   ⇒ 切换内核时**必须**同时切换模块树。本脚本把这两半做成原子操作，
#      并且切换后**验证**（跑模块加载探针），失败自动回滚。
#
# 用法：
#   scripts/switch-kernel-abi.sh --list                     # 看设备上现有哪些 ABI 变体
#   scripts/switch-kernel-abi.sh --to suspend               # 切到含 suspend 的（vk129）
#   scripts/switch-kernel-abi.sh --to nosuspend             # 切回不带 suspend 的（vk127）
#   scripts/switch-kernel-abi.sh --to suspend --check       # 只预检，不动设备
#
# 变体命名与设备上的资产（2026-10-20 建立）：
#   suspend    = boot_b-vk129.img + /lib/modules/<UTS>-abi-suspend
#   nosuspend  = boot_b-vk127.img + /lib/modules/<UTS>-abi-nosuspend
#
# 纪律：
#   · 切换内核镜像需要 fastboot（设备须在 BL 里）；切换模块树可以运行态做。
#   · 两半必须同进同退；任何一步失败都恢复原状。
#   · 切换后跑探针：modprobe coresight（vk129 下这是原崩溃点，能过=A BI 匹配）。
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
DEV=${DEV:-root@192.168.7.1}
UTS_FALLBACK=7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty
TARGET=
CHECK_ONLY=0
DO_LIST=0

while [ $# -gt 0 ]; do
	case "$1" in
		--to) TARGET=$2; shift 2;;
		--check) CHECK_ONLY=1; shift;;
		--list) DO_LIST=1; shift;;
		*) echo "unknown arg: $1" >&2; exit 64;;
	esac
done

SSH() { timeout 30 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes \
	-o ServerAliveInterval=15 "$DEV" "$@" 2>/dev/null; }
FB_PRESENT() { timeout 15 fastboot devices >/tmp/skabi-fb.txt 2>&1; grep -q HA2EXB0E /tmp/skabi-fb.txt; }

img_for() {
	case "$1" in
		suspend)   echo "$ROOT/bootslot-b/boot_b-vk129.img";;
		nosuspend) echo "$ROOT/bootslot-b/boot_b-vk127.img";;
		*) return 1;;
	esac
}

moddir_for() { echo "/lib/modules/${UTS:-$UTS_FALLBACK}-abi-$1"; }

# 当前真在跑的是哪个 ABI —— 唯一可信判据是运行内核的 ikconfig
current_abi() {
	local v
	v=$(SSH 'zcat /proc/config.gz 2>/dev/null | sed -n "s/^CONFIG_PM_SLEEP=y$/yes/p"' | tr -d '\r')
	[ "$v" = yes ] && echo suspend || echo nosuspend
}

# ---------------------------------------------------------------- --list
if [ "$DO_LIST" = 1 ]; then
	echo "### 设备资产清点 $(date '+%F %T')"
	SSH true || { echo "❌ 设备不可达（$DEV）"; exit 1; }
	UTS=$(SSH 'uname -r' | tr -d '\r')
	echo "-- 运行内核 UTS = $UTS"
	echo "-- 运行内核 ABI = $(current_abi)   (依据 /proc/config.gz 的 CONFIG_PM_SLEEP)"
	echo "-- 运行内核构建 = $(SSH 'uname -v' | tr -d '\r')"
	echo
	echo "-- /lib/modules 下的相关树："
	SSH "for d in /lib/modules/$UTS /lib/modules/$UTS-abi-* /lib/modules/*vk127*; do
		[ -d \"\$d\" ] || continue
		n=\$(find -L \"\$d\" -name '*.ko' 2>/dev/null | wc -l)
		c=\$(stat -c%s \"\$d/kernel/drivers/hwtracing/coresight/coresight.ko\" 2>/dev/null || echo -)
		printf '   %-72s ko=%-5s coresight=%s\n' \"\$d\" \"\$n\" \"\$c\"
	done" | tr -d '\r'
	echo
	echo "-- 主机侧镜像："
	for v in nosuspend suspend; do
		f=$(img_for "$v"); [ -f "$f" ] && printf '   %-9s %s (%s B)\n' "$v" "$(basename "$f")" "$(stat -c%s "$f")"
	done
	echo
	echo "-- 一致性判据：运行 ABI 应 == 挂载的 /lib/modules/<UTS> 对应变体"
	exit 0
fi

[ -n "$TARGET" ] || { echo "用法：$0 --list | --to suspend|nosuspend [--check]"; exit 64; }

IMG=$(img_for "$TARGET") || { echo "❌ 未知变体 '$TARGET'（只支持 suspend|nosuspend）"; exit 64; }
[ -f "$IMG" ] || { echo "❌ 缺镜像 $IMG"; exit 1; }

echo "### switch-kernel-abi → $TARGET  $(date '+%F %T')"
SSH true || { echo "❌ 设备不可达（$DEV）"; exit 1; }
UTS=$(SSH 'uname -r' | tr -d '\r')
CUR=$(current_abi)
MDIR=$(moddir_for "$TARGET")
echo "-- 当前 ABI = $CUR   目标 ABI = $TARGET"
echo "-- 目标镜像 = $IMG ($(stat -c%s "$IMG") B, sha $(sha256sum "$IMG" | cut -c1-16)…)"
echo "-- 目标模块树 = $MDIR"

# --- 预检 ---
if [ "$CUR" = "$TARGET" ]; then
	echo "✅ 已经是 $TARGET，无需切换"
	exit 0
fi

KO=$(SSH "find $MDIR -name '*.ko' 2>/dev/null | wc -l" | tr -d '\r')
echo "-- 目标模块树现有 .ko = ${KO:-0}"
if [ "${KO:-0}" -lt 1000 ]; then
	echo "❌ 目标模块树不完整（期望 ~1497）⇒ 拒绝切换。"
	echo "   先把对应模块树部署到 $MDIR（见 reports/vk129-abi-fix-verified-20261020.md §4.3 的四条部署纪律）"
	exit 1
fi

if [ "$CHECK_ONLY" = 1 ]; then
	echo "== 预检通过（--check 未改任何东西）=="
	echo "   真跑：$0 --to $TARGET"
	exit 0
fi

# --- 执行：模块树切换（运行态可做，原子 mv）+ 内核镜像（需 fastboot） ---
echo "-- [1/3] 切换模块树"
SSH "set -e
	D=/lib/modules/$UTS
	NEW=$MDIR
	BAK=\${D}.swapbak-\$(date +%s)
	if [ -d \"\$D\" ]; then mv \"\$D\" \"\$BAK\"; fi
	if ! ln -s \"\$NEW\" \"\$D\" 2>/dev/null; then cp -a \"\$NEW\" \"\$D\"; fi
	echo \"   \$D -> \$NEW (备份 \$BAK)\"
" || { echo "❌ 模块树切换失败"; exit 1; }

echo "-- [2/3] 探针：modprobe coresight（原崩溃点）"
if SSH 'modprobe -r coresight 2>/dev/null; modprobe coresight 2>&1; echo rc=$?' | grep -q 'rc=0'; then
	echo "   ✅ coresight 加载通过 ⇒ 模块 ABI 与运行内核匹配"
else
	echo "   ❌ 探针失败 ⇒ 自动回滚模块树"
	SSH "set -e; D=/lib/modules/$UTS; BAK=\$(ls -d \${D}.swapbak-* 2>/dev/null | tail -1);
		rm -rf \"\$D\"; [ -n \"\$BAK\" ] && mv \"\$BAK\" \"\$D\"; echo '   已回滚'"
	exit 1
fi

echo "-- [3/3] 内核镜像"
if FB_PRESENT; then
	timeout 90 fastboot flash boot_b "$IMG" >/tmp/skabi-flash.txt 2>&1 \
		&& echo "   ✅ boot_b 已刷为 $TARGET" \
		|| { echo "   ❌ flash 失败"; tail -3 /tmp/skabi-flash.txt; exit 1; }
	timeout 30 fastboot reboot >/dev/null 2>&1 && echo "   已重启，等待设备回来…"
	t=0; while [ $t -lt 180 ]; do SSH true && break; sleep 5; t=$((t+5)); done
	SSH true || { echo "❌ 重启后不可达 —— 用串口查：tail /var/log/elden-serial/ttyACM0.log"; exit 1; }
	echo "   ✅ 已回来：ABI 现为 $(current_abi)（期望 $TARGET）"
else
	echo "   ⚠️ 设备不在 fastboot ⇒ 只切了模块树，内核镜像未刷。"
	echo "      这意味着当前运行内核与模块树 ABI 不一致（$CUR 内核 + $TARGET 模块）。
	       必须在下次进 BL 时执行：fastboot flash boot_b $IMG"
	echo "      或直接让设备进屋 fastboot 后重跑本脚本。"
	exit 2
fi

echo
echo "### 完成：内核 + 模块树 = $TARGET（原子）"
echo "   复核：$0 --list"
