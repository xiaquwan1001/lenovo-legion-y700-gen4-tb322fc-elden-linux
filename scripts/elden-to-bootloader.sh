#!/bin/sh
# elden-to-bootloader.sh — 设备侧「Linux → bootloader(fastboot)」单一入口（POSIX sh，可独立跑）
#
# ★2026-11-23 重要更正（实测推翻 PITFALLS #690/#701 的「只能物理键」结论）：
#   在**无任何 vendor-reset 钩子**的日常核 vk192（7.3.1）上，同一次启动内对照实验：
#     `systemctl reboot`            → 回 Linux
#     `systemctl reboot bootloader` → **~21 s 进 fastboot**（`fastboot devices` 见 HA2EXB0E）
#   7.4-rc3 两枚核（一个带本仓 vendor-reset 补丁、一个**不带**）表现相同 ⇒ **钩子不是必要条件**，
#   真正起作用的是 `reboot(2)` 的 **cmd 字符串**（systemd 位置参数 → machine_restart(cmd)），
#   ABL 依该字符串决定进 fastboot。历史结论之所以错，是因为旧工具**默认拒绝**发软命令（fail-closed），
#   从未真正发出过 `reboot bootloader`。证据 = reports/linux-to-bl-vendor-reset-20261123.md §0。
#   因此：**默认臂改为直接 `reboot bootloader`**；PSCI 钩子只在与其它方案对比时才有意义。
#
# 历史（保留作沿革）：本脚本最初假设只有 vk41 起的 PSCI SYSTEM_RESET2 vendor reset 钩子管用：
#   （`reboot(2)` reason = bootloader/edl → reset_type 0x80010001/0x80000000；见
#    patches/kernel-history/*/0003-elden-vk41-minimal-PSCI-SYSTEM_RESET2-vendor-reset-h.patch）。
#   但**现役 vk192 是上游主线核，不含该钩子**（PITFALLS #690：`psci_system_reset2_supported` 在、
#   vendor reset 处理函数 0 命中）⇒ `systemctl reboot bootloader` 退化成普通重启，设备回到 Linux。
#   同时 Q23（2026-10-03）记录过 `misc` BCB `bootonce-bootloader` **不被 ABL 采纳**，但那是一条
#   独立结论、此后 ABL 行为在 11-19 的 EDL 现场又出现过 `bootonce-bootloader` 残留 ⇒ 值得**可复现地再测一次**。
#   所以本脚本 = 两条臂 + 能力自检 + 现场可回滚，主机侧 `scripts/to-bootloader.sh` 负责等 fastboot 与收尾。
#
# 用法（设备上，root）：
#   elden-to-bootloader --dry-run            # 只打印将要做的事 + 能力自检结论（不改任何东西）
#   elden-to-bootloader                      # 自动选臂（2026-11-23 起恒走 psci 臂 = `reboot bootloader`）
#   elden-to-bootloader --psci               # 强制 PSCI（`systemctl reboot bootloader`）
#   elden-to-bootloader --bcb                # 强制写 BCB：misc.command="bootonce-bootloader" + reboot
#   elden-to-bootloader --clear-bcb          # 只把 misc 的 BCB 头 4 KiB 清零（不重启）
#
# 纪律：
#   * 写 misc 前先把原 4 KiB 备份到 /var/lib/elden/misc-bcb.bak（打印 sha256），失败即不写。
#   * 只写 **头 4 KiB**（AOSP `struct bootloader_message` 在分区偏移 0）；不碰 misc 其余部分
#     （qbootctl 的 slot 计数区在别处，见 reports/android-min-avb-facts-20261118.md §3）。
#   * 本脚本自己会重启，**调用者不要在同一 ssh 会话里等它返回**（连接会断）。
set -u

MISC=/dev/disk/by-partlabel/misc
BCB_BAK=/var/lib/elden/misc-bcb.bak
MODE=auto
DRY=0

say() { printf '%s\n' "$*"; }
die() { printf '[elden-to-bootloader] FAIL %s\n' "$*" >&2; exit "${2:-1}"; }

for a in "$@"; do
	case "$a" in
		--dry-run) DRY=1 ;;
		--auto) MODE=auto ;;   # 2026-11-25 修：主机侧 to-bootloader.sh 一直传 --auto，设备侧却拒收 ⇒ 软路径静默不执行（实测「没反应」）
		--psci) MODE=psci ;;
		--bcb) MODE=bcb ;;
		--clear-bcb) MODE=clear ;;
		-h|--help) sed -n '1,30p' "$0"; exit 0 ;;
		*) die "未知参数 $a（--help 看用法）" 2 ;;
	esac
done

[ "$(id -u)" = 0 ] || die "要 root（写 misc 需要）" 3
[ -e "$MISC" ] || die "找不到 $MISC（分区表里没有 misc？）" 4

# ---- 能力自检：现役内核有没有 PSCI vendor-reset 钩子 ----
# 判据：钩子里有 `psci_elden_try_vendor_reset`（未被内联时会出现在 kallsyms）；
# 若已被内联则退回「dmesg 里是否出现过该钩子的 pr_info」（只在用过之后才有）。
HOOK=0
if grep -q 'psci_elden_try_vendor_reset' /proc/kallsyms 2>/dev/null; then
	HOOK=1
elif dmesg 2>/dev/null | grep -q 'SYSTEM_RESET2 vendor reset'; then
	HOOK=1
fi
say "[elden-to-bootloader] 内核 PSCI vendor-reset 钩子: $([ "$HOOK" = 1 ] && echo 有 || echo 无)（UTS $(uname -r)）"

if [ "$MODE" = auto ]; then
	# 2026-11-23 更正：无钩子也走 psci 臂（= `reboot bootloader` 本身即可进 fastboot，实测见头注）
	MODE=psci
	say "[elden-to-bootloader] 自动选臂: --$MODE（钩子$([ "$HOOK" = 1 ] && echo 有 || echo 无)，两者都可用）"
fi

# ---- 臂 1：PSCI（需要内核钩子）----
if [ "$MODE" = psci ]; then
	[ "$HOOK" = 1 ] || say "[elden-to-bootloader] 内核无 vendor-reset 钩子，但 \`reboot bootloader\` 仍可进 fastboot（2026-11-23 实测）"
	if [ "$DRY" = 1 ]; then
		say "[dry] systemctl reboot --reboot-argument=bootloader（systemd <257 回退位置参数）"
		exit 0
	fi
	sync
	# systemd 257+ 用 --reboot-argument（位置参数会报 "Too many arguments." 且 rc=1、设备不动）；
	# 老 root 没有这个选项 ⇒ 回退位置参数。不用 exec：exec 之后回退分支根本不成立。
	if ! systemctl reboot --reboot-argument=bootloader 2>/dev/null; then
		say "[elden-to-bootloader] --reboot-argument 不被接受，回退位置参数形态"
		systemctl reboot bootloader
	fi
	exit 0
fi

# ---- 臂 2：BCB（bootonce-bootloader）----
read_bcb4k() { dd if="$MISC" bs=4096 count=1 2>/dev/null; }

if [ "$MODE" = clear ]; then
	if [ "$DRY" = 1 ]; then say "[dry] dd 4 KiB 零 → $MISC"; exit 0; fi
	dd if=/dev/zero of="$MISC" bs=4096 count=1 conv=fsync 2>/dev/null || die "清 BCB 失败" 5
	sync
	say "[elden-to-bootloader] BCB 已清零（读回 nonzero=$(read_bcb4k | tr -d '\0' | wc -c)）"
	exit 0
fi

# 备份（幂等：只备份「非全零」的原件；全零说明本来就没有 BCB）
mkdir -p "$(dirname "$BCB_BAK")" 2>/dev/null || true
read_bcb4k > "$BCB_BAK.tmp" 2>/dev/null || die "读 misc 失败" 5
if [ -s "$BCB_BAK.tmp" ] && [ "$(tr -d '\0' < "$BCB_BAK.tmp" | wc -c)" -gt 0 ]; then
	mv -f "$BCB_BAK.tmp" "$BCB_BAK"
	say "[elden-to-bootloader] 已备份原 BCB: $BCB_BAK（sha256 $(sha256sum "$BCB_BAK" | cut -d' ' -f1)）"
else
	rm -f "$BCB_BAK.tmp"
	say "[elden-to-bootloader] 原 BCB 全零（无需备份）"
fi

if [ "$DRY" = 1 ]; then
	say "[dry] 写 misc[0:32]=\"bootonce-bootloader\" + 其余 4 KiB 清零，然后 systemctl reboot"
	exit 0
fi

# 4 KiB 结构：command[32] | status[32] | recovery[768] | 其余零
TMP=$(mktemp /tmp/bcb.XXXXXX) || die "mktemp 失败" 6
dd if=/dev/zero of="$TMP" bs=4096 count=1 2>/dev/null
printf 'bootonce-bootloader' | dd of="$TMP" bs=1 seek=0 conv=notrunc 2>/dev/null
dd if="$TMP" of="$MISC" bs=4096 count=1 conv=fsync 2>/dev/null || { rm -f "$TMP"; die "写 misc 失败" 7; }
sync
CMD=$(dd if="$MISC" bs=1 count=32 2>/dev/null | tr -d '\0')
rm -f "$TMP"
[ "$CMD" = "bootonce-bootloader" ] || die "读回校验失败（command=\"$CMD\"）" 8
say "[elden-to-bootloader] BCB 已写入并读回: command=\"$CMD\"；现在重启（ABL 读 misc 决定去向）"
sync
exec systemctl reboot
