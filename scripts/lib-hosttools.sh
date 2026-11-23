#!/bin/bash
# lib-hosttools.sh — 主机侧外部工具（fastboot / adb）落点解析（2026-11-21）
#
# 为什么需要：本机 PATH 里**没有** `fastboot`。它在 `~/.local/opt/platform-tools/fastboot`
# （v37.0.1，从 dl.google.com 下载解压，无需 sudo；见 `.pi/memory/failures-kernel.md`
# 的「本机 fastboot 路径」条）。症状是「工具在、但 `command -v fastboot` 判 MISS」——
# 2026-11-21 实测 `scripts/android-v3-bringup-walkthrough.sh --step S5 --dry-run` 的
# 前置校验就这样把自己挡在门外（S1–S5 全被跳过，看着像「没装工具」）。
#
# 用法：
#   . "$(dirname "$0")/lib-hosttools.sh"
#   ensure_hosttools                     # 幂等：找到就把所在目录前置进 PATH，并导出 FB_BIN/ADB_BIN
#   [ -n "$FB_BIN" ] || die "没装 fastboot"
#   "$FB_BIN" devices                     # 或者用裸 `fastboot`（PATH 已被补齐）
#
# 顺序：$FB_BIN/$ADB_BIN 显式指定 > PATH > ~/.local/opt/platform-tools > /usr/lib/android-sdk/platform-tools
# 注意：把 `~/.local/opt/platform-tools` 前置进 PATH 后，**同目录的 adb（v37.0.1）也会优先**
#   （系统 adb 34 与 37 混用时 adb server 会自报版本不符并重启一次，属预期）。
# 只做**查找与 PATH 前置**，不下载、不安装、不改系统。

# dev_present <fastboot|adb> <SN> —— 该 SN 是否在线（**先收全量输出再判**）
#   为什么要这个函数：`fastboot devices | grep -q` 会把 SIGPIPE 送回 fastboot 客户端、打断设备侧
#   bulk 通道（PITFALLS #584：之后 `fastboot devices` 恒空、只能物理 POR）。这里把输出先落进变量，
#   管道只接在 shell 变量上，不碰 fastboot 的 stdout。
dev_present() {
	local tool=$1 sn=$2 out bin
	if [ "$tool" = adb ]; then bin=${ADB_BIN:-adb}; out=$(timeout -k 5 6 "$bin" devices 2>/dev/null)
	else bin=${FB_BIN:-fastboot}; out=$(timeout -k 5 8 "$bin" devices 2>/dev/null); fi
	printf '%s\n' "$out" | awk 'NF{print $1}' | grep -qx -- "$sn"
}

hosttool_resolve() { # $1=name → 打印绝对路径；找不到 rc=1
	local name=$1 cand
	for cand in \
		"$(command -v "$name" 2>/dev/null)" \
		"${HOME:-/root}/.local/opt/platform-tools/$name" \
		"/usr/lib/android-sdk/platform-tools/$name"; do
		[ -n "$cand" ] || continue
		[ -x "$cand" ] && { printf '%s\n' "$cand"; return 0; }
	done
	return 1
}

_hosttool_prepend_dir() { # $1=bin 绝对路径；把它所在目录前置进 PATH（去重、幂等）
	local dir
	dir=$(dirname "$1")
	case ":$PATH:" in
		*":$dir:"*) : ;;
		*) PATH="$dir:$PATH" ;;
	esac
	export PATH
}

# ensure_hosttools [--quiet]
#   解析 fastboot/adb（尊重已设置的 FB_BIN/ADB_BIN），补齐 PATH，导出 FB_BIN/ADB_BIN。
#   两者都没找到也**不**报错（调用方自己判），但会导出空串，便于统一判断。
ensure_hosttools() {
	local quiet=0
	[ "${1:-}" = "--quiet" ] && quiet=1
	if [ -z "${FB_BIN:-}" ]; then FB_BIN=$(hosttool_resolve fastboot || true); fi
	if [ -n "${FB_BIN:-}" ]; then _hosttool_prepend_dir "$FB_BIN"; fi
	if [ -z "${ADB_BIN:-}" ]; then ADB_BIN=$(hosttool_resolve adb || true); fi
	if [ -n "${ADB_BIN:-}" ]; then _hosttool_prepend_dir "$ADB_BIN"; fi
	export FB_BIN ADB_BIN
	[ "$quiet" = 1 ] && return 0
	printf '[hosttools] fastboot=%s adb=%s\n' "${FB_BIN:-（未找到）}" "${ADB_BIN:-（未找到）}"
}
