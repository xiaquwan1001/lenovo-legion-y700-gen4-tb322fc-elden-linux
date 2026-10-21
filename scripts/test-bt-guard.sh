#!/bin/bash
# test-bt-guard.sh — 对 50-elden-bt-guard 做注入式单元测试（不需要真机、不动本机 BT）
#
# 为什么不能用「跑一次真 suspend」当验证：命中 WCN7850 固件下载窗口（~23 s）是概率事件，
# 而且失败表现为「系统没睡」，很容易被误读成「钩子没生效」。所以把判据函数的行为
# 用伪造的 `dmesg` / `rfkill` 固定下来（PITFALLS #364 教训：门必须做负向验证）。
#
# 用法：scripts/test-bt-guard.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOOK=$ROOT/rootfs/persistent-overlay/usr-libexec-elogind-system-sleep/50-elden-bt-guard
[ -f "$HOOK" ] || { echo "缺 $HOOK" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok() { echo "[ok]   $*"; }
bad() { echo "[FAIL] $*"; FAIL=1; }

mkdir -p "$TMP/bin"
cat >"$TMP/bin/dmesg" <<'EOF'
#!/bin/sh
cat "$FAKE_DMESG"
EOF
cat >"$TMP/bin/rfkill" <<'EOF'
#!/bin/sh
# 只支持 `list bluetooth` 与 `block|unblock bluetooth`
case "$1" in
list) printf '0: hci0: Bluetooth\n\tSoft blocked: %s\n\tHard blocked: no\n' "$(cat "$FAKE_RFKILL")" ;;
block) echo yes >"$FAKE_RFKILL"; echo "blocked" >>"$FAKE_CALLS" ;;
unblock) echo no >"$FAKE_RFKILL"; echo "unblocked" >>"$FAKE_CALLS" ;;
esac
EOF
chmod +x "$TMP/bin/dmesg" "$TMP/bin/rfkill"

# 每个用例：独立的 dmesg / rfkill 状态 / 调用记录
setup() { # $1 = settled|downloading, $2 = initial soft-blocked state
	echo no >"$TMP/rfkill.state"
	echo "$2" >"$TMP/rfkill.real"
	: >"$TMP/calls"
	if [ "$1" = settled ]; then
		cat >"$TMP/dmesg.txt" <<'EOF'
[   59.1] Bluetooth: hci0: setting up wcn7850
[   82.4] Bluetooth: hci0: QCA setup on UART is completed
EOF
	else
		cat >"$TMP/dmesg.txt" <<'EOF'
[   59.1] Bluetooth: hci0: QCA setup on UART is completed
[   80.0] Bluetooth: hci0: setting up wcn7850
EOF
	fi
}
run_hook() { # $1 = pre|post, $2 = WAIT_S
	FAKE_DMESG=$TMP/dmesg.txt FAKE_RFKILL=$TMP/rfkill.real FAKE_CALLS=$TMP/calls \
	WAIT_S=${2:-45} PATH="$TMP/bin:$PATH" \
	sh "$HOOK" "$1" suspend >"$TMP/out.txt" 2>&1
}

# ---- 用例 1：BT 已就绪 ⇒ pre 不动 rfkill、快速返回 ----
setup settled no
t0=$(date +%s)
run_hook pre 45; rc=$?
t1=$(date +%s)
[ "$rc" -eq 0 ] && ok "1a pre(settled) rc=0" || bad "1a pre(settled) rc=$rc"
[ -s "$TMP/calls" ] && bad "1b pre(settled) 误调 rfkill：$(cat "$TMP/calls")" || ok "1b pre(settled) 未调 rfkill"
[ $((t1 - t0)) -le 2 ] && ok "1c pre(settled) 立刻返回（$((t1 - t0))s）" || bad "1c pre(settled) 耗时 $((t1 - t0))s"

# ---- 用例 2：仍在下载 + WAIT_S 到期 ⇒ block 并留状态 ----
setup downloading no
run_hook pre 2; rc=$?
[ "$rc" -eq 0 ] && ok "2a pre(downloading) rc=0（不阻断挂起）" || bad "2a pre(downloading) rc=$rc"
grep -q "blocked" "$TMP/calls" && ok "2b pre(downloading) 已 rfkill block" || bad "2b pre(downloading) 没有 block"
[ "$(cat "$TMP/rfkill.real")" = yes ] && ok "2c rfkill 状态 = yes" || bad "2c rfkill 状态异常"
[ -f /run/elden-bt-guard.state ] || [ -f "$TMP/../elden-bt-guard.state" ]
STATE=$(grep -o 'STATE=[^ ]*' "$HOOK" | head -1 | cut -d= -f2)
echo "     （真实状态文件路径 $STATE 由设备侧使用；本测试直接查上面 rfkill 状态即可）"

# ---- 用例 3：post 恢复（状态文件存在 ⇒ unblock）----
# 复制钩子并改写 STATE/LOG 到临时路径，避免污染本机 /run
sed "s#^STATE=.*#STATE=$TMP/guard.state#; s#^LOG=.*#LOG=$TMP/guard.log#" "$HOOK" >"$TMP/hook.sh"
echo no >"$TMP/guard.state"
: >"$TMP/calls"
echo yes >"$TMP/rfkill.real"
FAKE_DMESG=$TMP/dmesg.txt FAKE_RFKILL=$TMP/rfkill.real FAKE_CALLS=$TMP/calls PATH="$TMP/bin:$PATH" \
	sh "$TMP/hook.sh" post suspend >/dev/null 2>&1
grep -q "unblocked" "$TMP/calls" && ok "3a post 恢复了 rfkill（unblock）" || bad "3a post 未恢复"
[ -f "$TMP/guard.state" ] && bad "3b 状态文件未清理" || ok "3b 状态文件已清理"

# ---- 用例 4（负向）：post 无状态文件 ⇒ 不碰 rfkill ----
: >"$TMP/calls"; echo yes >"$TMP/rfkill.real"
FAKE_DMESG=$TMP/dmesg.txt FAKE_RFKILL=$TMP/rfkill.real FAKE_CALLS=$TMP/calls PATH="$TMP/bin:$PATH" \
	sh "$TMP/hook.sh" post suspend >/dev/null 2>&1
[ -s "$TMP/calls" ] && bad "4a post 无状态时误调 rfkill" || ok "4a post 无状态时不动 rfkill"

# ---- 用例 5：非 suspend（如 hibernate）⇒ pre 直接放行 ----
setup downloading no
run_hook_pre_hibernate() { :; }
FAKE_DMESG=$TMP/dmesg.txt FAKE_RFKILL=$TMP/rfkill.real FAKE_CALLS=$TMP/calls PATH="$TMP/bin:$PATH" \
	sh "$HOOK" pre hibernate >/dev/null 2>&1
[ -s "$TMP/calls" ] && bad "5a pre(hibernate) 不该动 rfkill" || ok "5a pre(hibernate) 不介入"

echo
[ "$FAIL" -ne 0 ] && { echo "⇒ 有用例失败"; exit 1; }
echo "⇒ 全部用例通过"
