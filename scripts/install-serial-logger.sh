#!/bin/bash
# install-serial-logger.sh — 一次性装一个常驻的串口日志服务（需 sudo）。
#
# 为什么不让 agent 自己去 cat /dev/ttyACM0：
#   /dev/ttyACM0 = root:dialout 660，本机用户不在 dialout 组（PITFALLS #359）。
#   而 Q24/suspend 的死亡瞬间 dmesg 只能来自串口（pstore 常为空，#197）。
#   `setfacl` 虽然立即生效，但**设备每次重启 USB gadget 都会重建该节点**，
#   ACL 随之丢失 —— 恰好在最需要它的那一刻（重启/panic）失效。
#   ⇒ 用 systemd 服务持有端口（重连自动重开），日志落成 0644 普通文件，
#     agent 只读文件，不碰 tty 权限。
#
# 用法： sudo bash scripts/install-serial-logger.sh [PORT] [LOGDIR]
#   默认 PORT=/dev/ttyACM0（gadget if02，console=ttyGS0 的输出口）
# 验收： systemctl status elden-serial-logger; tail -n 20 /var/log/elden-serial/ttyACM0.log
# 卸载： sudo systemctl disable --now elden-serial-logger && sudo rm /etc/systemd/system/elden-serial-logger.service
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "需要 root：sudo bash $0 $*" >&2; exit 1; }

ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
PORT=${1:-/dev/ttyACM0}
LOGDIR=${2:-/var/log/elden-serial}
UNIT=/etc/systemd/system/elden-serial-logger.service
LOG="$LOGDIR/$(basename "$PORT").log"
READER="$ROOT/scripts/serial-fanout.sh"
# systemd 设备单元名：/dev/ttyACM0 -> dev-ttyACM0.device（--suffix=device 已含前缀，别再拼 dev-）
UNIT_DEV="$(systemd-escape --path "$PORT" --suffix=device)"

[ -f "$READER" ] || { echo "缺 $READER" >&2; exit 1; }
install -d -m 0755 "$LOGDIR"
chmod +x "$READER"

cat > "$UNIT" <<EOF
[Unit]
Description=elden debug serial logger ($PORT)
# ★ 不要用 BindsTo：设备一重启节点消失 ⇒ systemd **正常停止**本服务，
#   而 Restart=always 不覆盖 BindsTo 触发的停止 ⇒ 节点回来也不自启，
#   日志停在旧内容被误读成「没有 panic」（2026-10-20 实测，见 PITFALLS #361）。
#   重连交给 serial-fanout.sh 自己（内部轮询等节点），systemd 只兜底。
After=$UNIT_DEV

[Service]
Type=simple
ExecStart=$READER $PORT $LOG
Restart=always
RestartSec=1
# 只读端口，不做任何设备侧动作
Nice=-5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable elden-serial-logger.service >/dev/null
systemctl restart elden-serial-logger.service
sleep 2

echo "-- unit: $UNIT"
echo "-- log : $LOG"
systemctl --no-pager --lines=0 status elden-serial-logger.service | head -6 || true
chmod 0644 "$LOG" 2>/dev/null || true
if [ -s "$LOG" ]; then
	echo "✅ 已采到数据（$(wc -c < "$LOG") B）—— 末尾 5 行："
	tail -n 5 "$LOG" | sed 's/^/   | /'
else
	echo "⚠️ 日志暂时为空：内核此刻没有向 ttyGS0 输出是正常的（没有 printk）。"
	echo "   判活办法（不依赖设备）：echo 1 > /proc/sys/kernel/sysrq 之后往 ttyGS0 写一行，或重启设备看是否出现 new boot 行。"
fi
echo
echo "agent 侧用法：SERIAL_LOG=$LOG（两个采集脚本都已支持从日志 relay）"
