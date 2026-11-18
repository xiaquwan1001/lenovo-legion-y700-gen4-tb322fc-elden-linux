#!/bin/sh
# hide-android-partitions-selftest.sh — 离线自测（全部在 /tmp 沙盒里跑，不碰 /etc、不碰设备）
#
# 覆盖：dry-run 输出 / apply 写入 / 幂等 / --check rc / --revert 逐字节还原 / --keep 追加白名单 /
#      sh -n / udevadm verify 规则语法
#
# 用法：sh scripts/hide-android-partitions-selftest.sh    # rc=0 = 全绿
set -u
cd "$(dirname "$0")/.." || exit 1
S=scripts/hide-android-partitions.sh
SB="${TMPDIR:-/tmp}/hideandroid-selftest.$$"
FAIL=0
ok() { printf 'PASS  %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; FAIL=$((FAIL + 1)); }
chk() { if [ "$1" = "0" ]; then ok "$2"; else bad "$2"; fi; }

cleanup() { rm -rf "$SB"; }
trap cleanup EXIT INT TERM

rm -rf "$SB"; mkdir -p "$SB/rules"
cat >"$SB/partlabels.txt" <<'EOF'
sda1 system
sda5 vendor
sda9 persist
sda18 linux17
sda19 eldenesp
sdb1 sdcard
EOF
cat >"$SB/fstab" <<'EOF'
# /etc/fstab: static file system information.
LABEL=linux	/	ext4	defaults,noatime	0	1
# Android 只读分区（示例）
PARTLABEL=persist	/mnt/persist	ext4	ro,nofail	0	2
/dev/disk/by-partlabel/vendor	/mnt/vendor	ext4	defaults,ro	0	2
/dev/disk/by-partlabel/eldenesp	/boot/efi	vfat	umask=0077	0	1
UUID=1847ae03-1111-2222-3333-444455556666	/mnt/Samsung	ext4	defaults,nofail,x-systemd.device-timeout=10	0	2
/dev/disk/by-partlabel/system	/mnt/system	ext4	ro	0	2
no-dump-pass	/mnt/bare	ext4	ro
EOF
cp "$SB/fstab" "$SB/fstab.orig"
export HIDE_PARTLABELS="$SB/partlabels.txt" HIDE_RULES_DIR="$SB/rules" \
	HIDE_FSTAB="$SB/fstab" HIDE_STATE_DIR="$SB" HIDE_FAKE_ROOT=1

echo "== 1) sh -n"
sh -n "$S"; chk $? "sh -n 语法"
echo "== 2) --dry-run（不得写任何文件）"
out="$(sh "$S" --dry-run 2>&1)"; rc=$?
chk $rc "dry-run rc=0"
printf '%s' "$out" | grep -q 'ENV{UDISKS_IGNORE}="1"'; chk $? "dry-run 打印出 UDISKS_IGNORE 规则"
printf '%s' "$out" | grep -q 'sda18 *linux17 *keep'; chk $? "dry-run 预演把 linux17 标为 keep"
printf '%s' "$out" | grep -q 'sda1 *system *HIDDEN'; chk $? "dry-run 预演把 system 标为 HIDDEN"
[ -f "$SB/rules/79-hide-android-partitions.rules" ] && bad "dry-run 竟然写了规则文件" || ok "dry-run 未写规则文件"
echo "== 3) --check 在干净状态应 rc=1"
sh "$S" --check >/dev/null 2>&1; [ $? -ne 0 ]; chk $? "--check 干净状态 rc!=0"
echo "== 4) --apply"
sh "$S" --apply >"$SB/apply.log" 2>&1; chk $? "--apply rc=0"
[ -f "$SB/rules/79-hide-android-partitions.rules" ]; chk $? "规则文件已生成"
grep -q 'ENV{ID_PART_ENTRY_NAME}=="linux17|eldenesp|linux"' "$SB/rules/79-hide-android-partitions.rules"
chk $? "规则里白名单用 udev 的 | 交替"
grep -c 'x-gvfs-hide' "$SB/fstab" | grep -qx 3; chk $? "fstab 恰好 3 行被加 x-gvfs-hide"
grep -q '/boot/efi' "$SB/fstab" && ! grep '/boot/efi' "$SB/fstab" | grep -q x-gvfs-hide
chk $? "/boot/efi 未被改（系统内部挂载点）"
grep -q 'UUID=1847ae03' "$SB/fstab" && ! grep 'UUID=1847ae03' "$SB/fstab" | grep -q x-gvfs-hide
chk $? "无法解析的分区（TF 卡 UUID）未被改"
if command -v udevadm >/dev/null 2>&1; then
	echo "== 5) udevadm verify 规则语法"
	udevadm verify "$SB/rules/79-hide-android-partitions.rules" >"$SB/verify.log" 2>&1
	chk $? "udevadm verify 通过"
	grep -q 'Fail:    0' "$SB/verify.log"; chk $? "udevadm verify Fail:0"
fi
echo "== 6) 幂等：再 apply 一次不得改 fstab"
cp "$SB/fstab" "$SB/fstab.after1"
sh "$S" --apply >"$SB/apply2.log" 2>&1
diff -q "$SB/fstab.after1" "$SB/fstab" >/dev/null; chk $? "第二次 apply fstab 未变"
grep -q '已是最新' "$SB/apply2.log"; chk $? "第二次 apply 报『已是最新』"
echo "== 7) apply 后 --check 应 rc=0"
sh "$S" --check >"$SB/check.log" 2>&1; chk $? "apply 后 --check rc=0"
echo "== 8) --keep sdcard 追加白名单"
sh "$S" --dry-run --keep sdcard 2>&1 | grep -q 'linux17|eldenesp|linux|sdcard'; chk $? "--keep 追加进 udev 白名单"
echo "== 9) --revert"
sh "$S" --revert >"$SB/revert.log" 2>&1; chk $? "--revert rc=0"
diff -q "$SB/fstab.orig" "$SB/fstab" >/dev/null; chk $? "revert 后 fstab 逐字节回到原始"
[ ! -f "$SB/rules/79-hide-android-partitions.rules" ]; chk $? "revert 后规则文件已删除"

echo
if [ "$FAIL" = "0" ]; then echo "ALL PASS"; exit 0; fi
echo "FAILED: $FAIL 项"; exit 1
