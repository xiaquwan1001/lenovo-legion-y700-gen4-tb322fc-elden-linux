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
	core="sh mount umount switch_root mkdir cat sleep grep"
	miss=""
	for c in $core; do
		grep -qx -- "$c" "$APPLETS" || miss="$miss $c"
	done
	if [ -z "$miss" ]; then
		ok "核心工具齐全：$core"
	else
		bad "busybox-applets.txt 缺核心工具：$miss"
	fi
	# 根解析器：真机 busybox 有 findfs、没有 blkid/mountpoint（2026-10-06 实测）
	if grep -qx 'findfs' "$APPLETS" || grep -qx 'blkid' "$APPLETS"; then
		ok "根设备解析器存在（findfs 或 blkid）"
	else
		bad "无 findfs 也无 blkid：LABEL/UUID 根解析会失败"
	fi
	# 名单必须与真实 busybox 一致（2026-10-06 发现旧名单含假的 blkid/mountpoint）
	if command -v qemu-aarch64 >/dev/null 2>&1 && [ -x "$ROOT/initramfs/busybox" ]; then
		qemu-aarch64 "$ROOT/initramfs/busybox" --list 2>/dev/null | LC_ALL=C sort -u > /tmp/ck-init-applets.$$
		if diff -q /tmp/ck-init-applets.$$ "$APPLETS" >/dev/null 2>&1; then
			ok "busybox-applets.txt 与实际二进制 --list 一致（$(wc -l < "$APPLETS") 项）"
		else
			bad "busybox-applets.txt 与二进制 --list 不一致（跑 qemu-aarch64 initramfs/busybox --list | sort -u 重建）"
		fi
		rm -f /tmp/ck-init-applets.$$
	else
		warnf "无 qemu-aarch64，跳过 applet 名单与二进制一致性检查"
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
# ---------------------------------------------------------- 5. initramfs 资产
echo "== 5. initramfs 资产（内嵌 /init == 真源）=="
_asset_check() {
	_a=$ROOT/$1
	[ -f "$_a" ] || { warnf "$(basename "$1") 不存在（先跑 scripts/build-initramfs.sh slim|full）"; return; }
	_t=/tmp/ck-init-asset.$$
	rm -rf "$_t"; mkdir -p "$_t"
	( cd "$_t" && gzip -dc "$_a" | cpio -idm --quiet 2>/dev/null )
	if [ -f "$_t/init" ] && diff -q <(sed 's/\r$//' "$INIT") <(sed 's/\r$//' "$_t/init") >/dev/null 2>&1; then
		ok "$(basename "$_a") 内嵌 /init == 真源（$(stat -c%s "$_a") B）"
	else
		bad "$(basename "$_a") 内嵌 /init != 真源（或无法解开）"
	fi
	rm -rf "$_t"
}
_asset_check out/initramfs-slim.cpio.gz
_asset_check out/initramfs-full-elden.cpio.gz
if [ "${CHECK_INIT_DEEP:-0}" = 1 ]; then
	if bash scripts/build-initramfs.sh verify >/tmp/ck-init-repro.$$ 2>&1; then
		ok "资产可复现（deep）：$(grep -c '可复现 OK' /tmp/ck-init-repro.$$) 项"
	else
		bad "资产不可复现（deep）：$(tail -1 /tmp/ck-init-repro.$$)"
	fi
	rm -f /tmp/ck-init-repro.$$
else
	warnf "跳过可复现性重建（CHECK_INIT_DEEP=1 开启，约 15s）"
fi

echo
if [ "$fail" -eq 0 ]; then
	echo "== check-init: 全绿 =="
	exit 0
fi
echo "== check-init: $fail 项 FAIL =="
exit 1
