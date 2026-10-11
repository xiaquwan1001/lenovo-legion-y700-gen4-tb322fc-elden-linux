#!/bin/sh
# fix-ab-mark-successful.sh — 让设备每次启动都把自己标记为 A/B 槽「启动成功」。
#
# 为什么（2026-10-11 实测，PITFALLS #181）：
#   Alpine rootfs 自带 /etc/init.d/qbootctl（command="qbootctl" command_args="-m"），
#   但 **它不在任何 runlevel 里** ⇒ BOOT_SUCCESSFUL 位永远不置位 ⇒ ABL 每次启动都把
#   当前槽的 tries_remaining 减 1 ⇒ ~7 次重启后计数归零、槽被标 UNBOOTABLE，
#   设备直接停在 fastboot（表现为「启动次数用尽卡 fastboot」）。
#   受 Q28 所迫频繁重启的机器必然踩到。
#   另一个小坑：原脚本用 `command=`/`default_start`，对一个「跑完即退」的命令，
#   OpenRC status 会报 **crashed**（无 pidfile）——功能上仍会标记，但状态误导；
#   本脚本改成显式 start(){ ebegin/eend }，status 正常显示 started。
#
# 幂等：已在 runlevel 中则跳过；脚本内容总是被覆盖为权威版本（先备份原文件）。
# 用法：设备上当 root 跑： sh scripts/fix-ab-mark-successful.sh
set -u

INIT=/etc/init.d/qbootctl
[ -e "$INIT" ] || { echo "FAIL: $INIT 不存在（不是 Alpine/OpenRC 根？）" >&2; exit 1; }
command -v qbootctl >/dev/null 2>&1 || { echo "FAIL: 找不到 qbootctl" >&2; exit 1; }

[ -e "$INIT.orig" ] || cp -a "$INIT" "$INIT.orig"

cat > "$INIT" <<'EOF'
#!/sbin/openrc-run
# Mark the current A/B slot successful on every boot.
# 2026-10-11 fix (see scripts/fix-ab-mark-successful.sh): this service existed
# but was NOT in any runlevel -> BOOT_SUCCESSFUL never set -> ABL decremented
# tries_remaining once per boot -> after 7 reboots the device stopped at
# fastboot.  Enabled in runlevel `default`; explicit start() so OpenRC status
# reports `started` instead of `crashed` for this run-once command.
description="Mark current boot as successful in Android A/B interface"

start() {
	ebegin "Marking current A/B slot successful"
	/usr/bin/qbootctl -m
	eend $?
}
EOF
chmod 755 "$INIT"

rc-update add qbootctl default >/dev/null 2>&1 || true
rc-service qbootctl --quiet restart >/dev/null 2>&1 || rc-service qbootctl start >/dev/null 2>&1 || true

echo "--- 复核（必须 started + BOOT_SUCCESSFUL）---"
rc-service qbootctl status 2>&1 | head -1
if [ -x /usr/local/sbin/slot-attr.py ]; then
	python3 /usr/local/sbin/slot-attr.py show 2>/dev/null | grep -E "  boot_[ab] "
else
	qbootctl -m
fi
echo "runlevel: $(ls -l /etc/runlevels/default/qbootctl 2>/dev/null || echo '未启用！')"
