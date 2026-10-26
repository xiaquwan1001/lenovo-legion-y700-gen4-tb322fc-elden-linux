#!/bin/sh
# test-init-preflight.sh — `initramfs/init` 的 preflight 回归测试（免 root、离线）
#
# 为什么需要：2026-10-26 M6 事故里，Debian 根的 `/init` 在 **preflight 第一屏**
# 就把自己判成「根不完整」→ rescue shell（PID 1 无 tty ⇒ 全静默，看起来像挂死）。
# 根因 = 旧 preflight 在**磁盘阶段也要求 `switch_root`**，而 Debian 的 busybox 包
# 只装 `/bin/busybox`、不装 applet 链接。见
# `reports/m6-switch-root-breakpoint-resolved-20261026.md`。
#
# 做法：从 `initramfs/init` 里**逐字抽出** preflight 段（awk 定位，不复制逻辑），
# 在受限 PATH 的沙箱里跑 4 个用例。任何一条不符即 rc=1。
#
# 用例：
#   1. 磁盘阶段、无 switch_root、无 busybox        → 通过（本事故的正解）
#   2. 磁盘阶段、缺 mkdir 但有 busybox applet      → 通过（applet 回退定义同名函数）
#   3. initramfs 阶段、无 switch_root、无 busybox  → 失败并点名 switch_root
#   4. initramfs 阶段、busybox 有 applet 无链接    → 通过，且 SWITCH_ROOT_CMD 用可拆词形式
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
INIT_SCRIPT=$ROOT/initramfs/init
[ -f "$INIT_SCRIPT" ] || { echo "缺 $INIT_SCRIPT" >&2; exit 1; }

pass=0; fail=0
ok()   { printf '  ok    %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL  %s\n' "$*"; fail=$((fail+1)); }

WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT INT TERM

# --- 抽出 preflight 段（含注释头到 end 标记）--------------------------------
# 起点必须是 applet 回退块（preflight 用到 BB/have_applet），终点 = end 标记。
sed -n '/^# --- busybox applet fallback/,/^# --- end preflight/p' "$INIT_SCRIPT" > "$WORK/preflight.sh"
[ -s "$WORK/preflight.sh" ] || { echo "抽不到 preflight 段（标记变了？）" >&2; exit 1; }
grep -q 'SWITCH_ROOT_CMD' "$WORK/preflight.sh" || { echo "preflight 段里没有 SWITCH_ROOT_CMD" >&2; exit 1; }

# --- 沙箱工具目录 -----------------------------------------------------------
# 只放 preflight 真正需要的命令，保证「缺不缺」由我们决定，不受宿主机影响。
TOOLS=$WORK/tools
mkdir -p "$TOOLS"
for c in sh grep sleep cat mkdir mount umount; do
	# 用宿主机同名命令做桩（只要求可执行、行为一致）
	cp "$(command -v "$c")" "$TOOLS/$c" 2>/dev/null || ln -s "$(command -v "$c")" "$TOOLS/$c"
done
# switch_root 的桩：能跑就说明 exec 目标解析正确（真实调用只发生在 initramfs 阶段）
printf '#!/bin/sh\necho "STUB switch_root $*"\n' > "$TOOLS/_switch_root_stub"
chmod +x "$TOOLS/_switch_root_stub"

# busybox 桩：`--list` 打印给定 applet 名单；被当 applet 调用时打印 STUB。
mkbusybox() { # mkbusybox <dir> <applets...>
	_d=$1; shift
	mkdir -p "$_d"
	{
		echo '#!/bin/sh'
		printf 'if [ "$1" = "--list" ]; then\n'
		for a in "$@"; do printf '  echo %s\n' "$a"; done
		printf '  exit 0\nfi\n'
		printf 'echo "STUB busybox $*"\n'
	} > "$_d/busybox"
	chmod +x "$_d/busybox"
}

# run_case <描述> <phase: disk|initramfs> <PATH> <期望: pass|fail> <期望的 SWITCH_ROOT_CMD 子串|-> [期望 stderr 子串]
run_case() {
	_desc=$1; _phase=$2; _path=$3; _want=$4; _wantcmd=$5; _wantmsg=${6:--}
	_bbsearch=${7:--none-}
	[ "$_wantmsg" = - ] && _wantmsg=''

	_out=$(
		PATH=$_path
		export PATH
		# 把 busybox 搜索面钉进沙箱：否则宿主机 /bin/busybox 会让"无 busybox"用例失真
		BB_SEARCH=${_bbsearch:--none-}
		export BB_SEARCH
		# 桩：preflight 依赖这两个（失败路径才会用到 rescue）
		fatal() { printf 'FATAL %s\n' "$*" >&2; }
		rescue() { printf 'RESCUE %s\n' "$*" >&2; return 1; }
		if [ "$_phase" = disk ]; then
			root_phase_disk() { ROOT_FSTYPE=ext4; return 0; }
		else
			root_phase_disk() { ROOT_FSTYPE=rootfs; return 1; }
		fi
		. "$WORK/preflight.sh"; _st=$?
		printf 'CMD=%s\n' "$SWITCH_ROOT_CMD"
		# 必须把 preflight 的返回值带出去：后面的 printf 会把 `$?` 覆盖成 0
		exit $_st
	) 2>&1
	_rc=$?
	if [ "$_want" = pass ]; then
		if [ $_rc -eq 0 ]; then ok "$_desc"; else bad "$_desc（期望通过，实际 rc=$_rc）: $(echo "$_out" | tr '\n' ' ')"; fi
	else
		if [ $_rc -ne 0 ]; then ok "$_desc"; else bad "$_desc（期望失败，实际通过）"; fi
	fi
	if [ -n "$_wantmsg" ]; then
		echo "$_out" | grep -q "$_wantmsg" && ok "$_desc :: 错误信息点名 $_wantmsg" \
			|| bad "$_desc :: 错误信息里没有 $_wantmsg（$(echo "$_out" | tr '\n' ' ')）"
	fi
	if [ "$_wantcmd" != - ]; then
		echo "$_out" | grep -q "^CMD=$_wantcmd" && ok "$_desc :: SWITCH_ROOT_CMD=$_wantcmd" \
			|| bad "$_desc :: SWITCH_ROOT_CMD 不是 '$_wantcmd'（$(echo "$_out" | grep '^CMD=')）"
	fi
}

sec() { printf '\n[%s]\n' "$*"; }

sec "1. 磁盘阶段（Debian 根：无 switch_root、无 busybox）"
# 事故现场的最小复现：只有普通二进制，没有 busybox。
run_case "磁盘阶段不要求 switch_root" disk "$TOOLS" pass "switch_root"

sec "2. 磁盘阶段 + applet 回退（缺 mkdir，但 busybox 有）"
D2=$WORK/t2
mkdir -p "$D2"
for c in sh grep sleep cat; do cp "$TOOLS/$c" "$D2/$c"; done
mkbusybox "$D2" mkdir mount umount switch_root
run_case "缺 mkdir 时用 busybox applet 补" disk "$D2" pass "switch_root" - "$D2/busybox"

sec "3. initramfs 阶段缺 switch_root ⇒ 必须失败并点名"
run_case "initramfs 阶段要求 switch_root" initramfs "$TOOLS" fail "switch_root" "switch_root"

sec "4. initramfs 阶段：有 applet 无链接 ⇒ 用可拆词形式（exec 友好）"
D4=$WORK/t4
mkdir -p "$D4"
for c in sh grep sleep cat mkdir mount umount; do cp "$TOOLS/$c" "$D4/$c"; done
mkbusybox "$D4" switch_root findfs
run_case "applet 回退不用同名函数（exec 只认路径）" initramfs "$D4" pass ".*/busybox switch_root" - "$D4/busybox"

printf '\n==== init-preflight: PASS=%d FAIL=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
