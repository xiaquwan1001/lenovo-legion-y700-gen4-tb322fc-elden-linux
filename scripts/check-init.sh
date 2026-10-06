#!/usr/bin/env bash
# check-init.sh — init 单一真源 / 可运行性自检（主机侧，只读）
#
# 用法:  scripts/check-init.sh        （退出码 0=全绿，1=有 FAIL）
#
# 背景（2026-10-06 init 固化）：
#   * 旧状态：initramfs/init（boot 镜像）与 rootfs/init（磁盘根）= 设备 /init
#     三者分叉；磁盘 /init 还是 scripts/patch-init-*.sh 用 awk 原地拼出来的。
#   * 新状态：initramfs/init 为唯一真源，build-rootfs.sh / build-boot.sh 都从
#     它生成；patch-init-*.sh 已退休。本脚本防止再次分叉。
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
INIT=initramfs/init
APPLETS=initramfs/busybox-applets.txt

fail=0
ok()   { printf '  [ok]   %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; fail=$((fail+1)); }
warnf(){ printf '  [warn] %s\n' "$1"; }

echo "== check-init — $ROOT =="

# ---------------------------------------------------------- 1. 单一真源
echo
echo "== 1. 单一真源 =="
[ -f "$INIT" ] && ok "$INIT 存在" || bad "$INIT 缺失"
if [ -e rootfs/init ]; then
	bad "rootfs/init 仍存在（第二份 init）；它应由 build-rootfs.sh 从 $INIT 生成"
else
	ok "rootfs/init 已退休（无第二份）"
fi
if compgen -G 'scripts/patch-init-*.sh' >/dev/null; then
	bad "scripts/patch-init-*.sh 仍存在（awk 打补丁时代残留）"
else
	ok "patch-init-*.sh 已全部退休"
fi
if grep -q 'initramfs/init' rootfs/build-rootfs.sh; then
	ok "build-rootfs.sh 从 $INIT 安装 /init"
else
	bad "build-rootfs.sh 未指向 $INIT"
fi

# ---------------------------------------------------------- 2. 语法
echo
echo "== 2. 语法（目标解释器：busybox ash / POSIX sh）=="
if command -v dash >/dev/null 2>&1; then
	if dash -n "$INIT"; then ok "dash -n 通过"; else bad "dash -n 失败"; fi
else
	warnf "无 dash，跳过 POSIX 语法检查"
fi
if [ -x "$ROOT/initramfs/busybox" ]; then
	if "$ROOT/initramfs/busybox" sh -n "$INIT" 2>/dev/null; then
		ok "busybox ash -n 通过"
	else
		bad "busybox ash -n 失败"
	fi
else
	warnf "无 initramfs/busybox，跳过 ash 语法检查"
fi

# ---------------------------------------------------------- 3. applet 覆盖
echo
echo "== 3. 最小 initramfs 的 applet 覆盖（PITFALLS #107）=="
if [ -f "$APPLETS" ]; then
	# preflight 强制要求的核心工具：必须在 busybox applet 名单里
	core="sh mount umount mountpoint switch_root mkdir cat sleep grep"
	miss=""
	for c in $core; do
		grep -qx -- "$c" "$APPLETS" || miss="$miss $c"
	done
	if [ -z "$miss" ]; then
		ok "核心工具齐全：$core"
	else
		bad "busybox-applets.txt 缺核心工具：$miss"
	fi
	if grep -qx 'blkid' "$APPLETS" || grep -qx 'findfs' "$APPLETS"; then
		ok "根设备解析器存在（blkid 或 findfs）"
	else
		bad "无 blkid 也无 findfs：LABEL/UUID 根解析会失败"
	fi
else
	bad "$APPLETS 缺失"
fi

# ---------------------------------------------------------- 4. 挂钩脚本存在
echo
echo "== 4. init 引用的 /usr/local/sbin 挂钩 =="
missing_hook=0
for h in $(grep -oE '/usr/local/sbin/[A-Za-z0-9._-]+\.sh' "$INIT" | sort -u); do
	base=$(basename "$h")
	# camera-modules-load.sh 由 build-camera-overlay.sh 安装（不在 scripts/ 的 rootfs 名单里）
	if [ -f "scripts/$base" ]; then
		ok "$h  <- scripts/$base"
	else
		warnf "$h 无对应 scripts/$base（须由 overlay 或设备侧提供）"
		missing_hook=$((missing_hook+1))
	fi
done
[ "$missing_hook" -eq 0 ] || true

echo
if [ "$fail" -eq 0 ]; then
	echo "== check-init: 全绿 =="
	exit 0
fi
echo "== check-init: $fail 项 FAIL =="
exit 1
