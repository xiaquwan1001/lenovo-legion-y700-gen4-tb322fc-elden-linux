#!/bin/bash
# common.sh — packaging/elden-userland/build/ 各配方共用的小工具（被 source，不单独执行）
#
# 设计口径（T14 收尾，2026-11-04）：
#   1. **每个配方都必须支持 `--dry-run`**：只打印将要执行的命令，**不建目录、不编译、不写系统**。
#      `tools/verify.sh --rebuildable` 依赖这一点做机器检查（rc=0 且 stdout 非空）。
#   2. 配方本身**只往仓库内写**（`out/`，见 .gitignore）；需要 root 的路径（arm64 chroot 编译）
#      只在真正的构建阶段出现，dry-run 里一律只打印。
#   3. 不重复发明构建命令：配方的"真相"仍然是 `scripts/build-*.sh` 与
#      `scripts/host-arm64-chroot.sh`；本目录负责**统一入口 + 可演练 + 可被门禁检查**。

DRY_RUN=0
ARGS=()

# parse_args "$@" — 抽出 --dry-run，其余留在 ARGS
parse_args() {
	ARGS=()
	while [ $# -gt 0 ]; do
		case "$1" in
			--dry-run|-n) DRY_RUN=1 ;;
			*) ARGS+=("$1") ;;
		esac
		shift
	done
	export DRY_RUN
}

repo_root() { cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[1]}")")/../../.." && pwd; }

# run <cmd...> — dry-run 时只打印（带 `+` 前缀，便于复制），否则执行
run() {
	if [ "$DRY_RUN" = 1 ]; then
		local a
		printf '+'
		for a in "$@"; do
			case "$a" in
				*[[:space:]]*) printf " '%s'" "$a" ;;
				*)             printf ' %s' "$a" ;;
			esac
		done
		printf '\n'
	else
		printf '[run] %s\n' "$*"
		"$@"
	fi
}

# note <text...> — 人类可读说明；dry-run 时也输出（stderr），不影响 stdout 的命令流
note() { printf '# %s\n' "$*" >&2; }

# need <prog> — 缺工具时给出可复制的安装提示（dry-run 下只警告不退出）
need() {
	local p=$1 pkg=${2:-$1}
	if ! command -v "$p" >/dev/null 2>&1; then
		if [ "$DRY_RUN" = 1 ]; then
			note "缺少 $p（真跑前需：apt-get install -y $pkg）"
			return 0
		fi
		printf 'ERROR: 缺少 %s（apt-get install -y %s）\n' "$p" "$pkg" >&2
		return 1
	fi
}

# need_root — 需要 root 的配方调用（dry-run 不检查）
need_root() {
	[ "$DRY_RUN" = 1 ] && return 0
	[ "$(id -u)" = 0 ] && return 0
	printf 'ERROR: 需要 root：sudo bash %s %s\n' "$0" "$*" >&2
	return 1
}

# need_file <path> — 源文件缺失即失败（dry-run 下也只报错，因为缺源=配方无效）
need_file() {
	[ -e "$1" ] && return 0
	printf 'ERROR: 缺文件 %s\n' "$1" >&2
	return 1
}

# finish <名字> — 统一收尾（打印产物清单 / dry-run 提示）
finish() {
	if [ "$DRY_RUN" = 1 ]; then
		printf '# dry-run 结束：%s 未执行任何写操作\n' "$1" >&2
	fi
}
