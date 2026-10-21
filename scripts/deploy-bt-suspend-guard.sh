#!/bin/bash
# deploy-bt-suspend-guard.sh — 把 BT suspend 保护钩子部署到设备并验证。
#
# 背景（2026-10-21，T9 实测）：WCN7850 固件下载 ~23 s >> hci_qca 的
# FW_DOWNLOAD_TIMEOUT 3 s ⇒ 命中下载窗口的 suspend 会在 3.5 s 被 -110 弹出。
# 钩子 = elogind system-sleep pre/post（源 rootfs/persistent-overlay/usr-libexec-elogind-system-sleep/50-elden-bt-guard）。
#
# 用法：
#   scripts/deploy-bt-suspend-guard.sh            # 部署 + 自检
#   scripts/deploy-bt-suspend-guard.sh --check    # 只自检（不写入）
#   scripts/deploy-bt-suspend-guard.sh --remove   # 卸载
#
# 自检项：
#   1. 文件存在且可执行
#   2. 语法：sh -n
#   3. pre 分支在 BT 已就绪时应立即退出 0（实测耗时 < 2 s）
#   4. post 分支在无状态文件时退出 0
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEV=${DEV:-root@192.168.7.1}
SRC=$ROOT/rootfs/persistent-overlay/usr-libexec-elogind-system-sleep/50-elden-bt-guard
DST=/usr/libexec/elogind/system-sleep/50-elden-bt-guard
MODE=deploy
for a in "$@"; do
	case "$a" in
		--check) MODE=check ;;
		--remove) MODE=remove ;;
		-h|--help) sed -n '2,18p' "$0"; exit 0 ;;
	esac
done

SSH() { timeout 30 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes "$DEV" "$@" 2>/dev/null; }
ok() { echo "[ok]   $*"; }
bad() { echo "[FAIL] $*"; FAIL=1; }
FAIL=0

[ -f "$SRC" ] || { echo "缺源文件: $SRC" >&2; exit 1; }
sh -n "$SRC" || { echo "源文件语法错" >&2; exit 1; }
ok "源文件语法通过"

if [ "$MODE" = check ] && ! SSH true; then
	echo "设备不可达（DEV=$DEV）"; exit 1
fi

case "$MODE" in
remove)
	[ -n "$(SSH ls "$DST" 2>/dev/null)" ] && SSH rm -f "$DST" && ok "已删除 $DST"
	;;
deploy)
	SSH mkdir -p /usr/libexec/elogind/system-sleep
	cat "$SRC" | timeout 30 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes "$DEV" "cat > $DST" || bad "写入失败"
	SSH chmod 0755 "$DST"
	SSH 'sh -n /usr/libexec/elogind/system-sleep/50-elden-bt-guard' || bad "设备侧语法检查失败"
	ok "已部署 $DST"
	;;
esac

if [ "$MODE" = remove ]; then exit 0; fi

# ---- 自检 ----
[ "$(SSH stat -c %a "$DST" 2>/dev/null)" = "755" ] && ok "权限 755" || bad "权限不是 755"
SSH 'test -x /usr/libexec/elogind/system-sleep/50-elden-bt-guard' && ok "可执行" || bad "不可执行"

# pre 分支在 BT 就绪时必须立即返回且不改 rfkill
before=$(SSH 'rfkill list bluetooth | tr "\n" " "')
t0=$(date +%s)
SSH 'sh /usr/libexec/elogind/system-sleep/50-elden-bt-guard pre suspend; echo rc=$?'
t1=$(date +%s)
after=$(SSH 'rfkill list bluetooth | tr "\n" " "')
[ $((t1 - t0)) -lt 10 ] && ok "pre 分支快速返回（$((t1 - t0))s）" || bad "pre 分支耗时过长（$((t1 - t0))s）"
[ "$before" = "$after" ] && ok "pre 分支未改 rfkill 状态" || bad "pre 分支意外改了 rfkill"

# post 分支无状态文件时必须安静返回
SSH 'rm -f /run/elden-bt-guard.state; sh /usr/libexec/elogind/system-sleep/50-elden-bt-guard post suspend; echo rc=$?' >/tmp/bt-guard-post.txt
grep -q "rc=0" /tmp/bt-guard-post.txt && ok "post 分支 rc=0" || bad "post 分支非 0"

echo
if [ "$FAIL" -ne 0 ]; then echo "⇒ 部署有问题"; exit 1; fi
echo "⇒ 部署完成，自检全绿"
echo "   日志：设备 /var/log/elden-bt-guard.log"
echo "   注意：本钩子只在 **elogind 发起**的 suspend 里生效（loginctl suspend / 合盖 / 电源菜单）。"
echo "         直接 'echo mem > /sys/power/state' 不经过 elogind，钩子不会被调用。"
