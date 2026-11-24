#!/usr/bin/env bash
# as-client-deploy.sh — 把 Audio Share 的「Linux 客户端」装到平板（TB322FC 主线 Debian）
#
# 为什么需要（2026-11-20）：上游 mkckr0/audio-share 只发 Android 客户端，`as-cmd` 是服务端。
# 平板跑主线 Debian ⇒ 得自己实现协议那一端。协议逐字节依据 = 上游 Android 源码
# `android-app/.../service/{NetClient,NetworkIO}.kt`：
#   TCP: int32le CMD_GET_FORMAT(1) → int32le 1 + int32le size + protobuf AudioFormat
#        int32le CMD_START_PLAY(2) → int32le 2 + int32le id
#   UDP: 客户端绑随机端口，先发 int32le id 到 srv:65530，之后服务端推原始 PCM 数据报
#   心跳: 服务端 TCP 发 3，客户端原样回 3（5 s 内不回会被踢）
# 客户端源码 = rootfs/debian/audio-share/as-client.c（musl 静态交叉编译，设备侧零依赖）。
# **源码 SSOT = 上游 fork `xiaquwan1001/audio-share` 的 `linux-client/as-client.c`**（含 Makefile/unit/README）；
# 本仓同名文件是镜像，改客户端先改 fork 再同步回来（2026-11-24 收编，两份已逐字节对齐）。
#
# 主机侧配套（一次性，本脚本不代做）：
#   ① PC 服务：`%h/bin/as-cmd` 必须绑 **0.0.0.0**（历史手工实例只绑手机网段 192.168.42.97，
#      平板走 USB-NCM 192.168.7.0/24 连不进来）。实测用 user unit：
#        ~/.config/systemd/user/audio-share-server.service
#        ExecStart=%h/bin/as-cmd --bind=0.0.0.0 ; Restart=always ; WantedBy=default.target
#   ② 防火墙：`ufw allow from 192.168.7.0/24 to any port 65530 proto tcp` / `... proto udp`
#
# 用法：
#   scripts/as-client-deploy.sh --check        # 只读体检（二进制/单元/运行值/连通）
#   scripts/as-client-deploy.sh               # 真装（编译 → scp → 写 unit → enable --now）
#   AS_HOST=192.168.7.9 AS_PORT=65530 TAB=root@192.168.7.1 scripts/as-client-deploy.sh
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TAB=${TAB:-root@192.168.7.1}
AS_HOST=${AS_HOST:-192.168.7.9}    # 主机 USB-NCM 侧地址（NM 连接 elden-usb-gadget）
AS_PORT=${AS_PORT:-65530}
DEV_USER=${DEV_USER:-xuqianhui1001}
DEV_UID=${DEV_UID:-1001}
CC=${CC:-$HOME/toolchains/aarch64-linux-musl-cross/bin/aarch64-linux-musl-gcc}
SRC=$ROOT/rootfs/debian/audio-share/as-client.c
BIN=$ROOT/out/as-client-aarch64
MODE=apply

case "${1:-}" in
--check) MODE=check ;;
--apply|"") MODE=apply ;;
-h|--help) sed -n '2,32p' "$0"; exit 0 ;;
*) echo "未知参数 $1（--check / --apply）" >&2; exit 2 ;;
esac

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10 "$TAB")
say() { printf '%-6s %s\n' "$1" "$2"; }
ok() { say ok "$1"; }
no() { say MISS "$1"; }
fix() { say FIX "$1"; }

userctl() { "${SSH[@]}" "runuser -u $DEV_USER -- env XDG_RUNTIME_DIR=/run/user/$DEV_UID systemctl --user $*"; }

if [ "$MODE" = check ]; then
	bin=$("${SSH[@]}" 'test -x /usr/local/bin/as-client && echo 1 || echo 0')
	unit=$("${SSH[@]}" 'test -f /etc/systemd/user/audio-share-client.service && echo 1 || echo 0')
	act=$(userctl is-active audio-share-client 2>/dev/null || echo unknown)
	tags=$("${SSH[@]}" "runuser -u $DEV_USER -- env XDG_RUNTIME_DIR=/run/user/$DEV_UID journalctl --user-unit audio-share-client -n 40 --no-pager -q 2>/dev/null | grep -cE 'TCP 已连|播放会话' || true")
	[ "${bin:-0}" = 1 ] && ok "设备侧 /usr/local/bin/as-client 在" || no "设备侧没有 as-client"
	[ "${unit:-0}" = 1 ] && ok "user unit audio-share-client.service 在" || no "缺 user unit"
	[ "${act:-}" = active ] && ok "audio-share-client 运行中（连 $AS_HOST:$AS_PORT）" || no "audio-share-client 未运行（$act）"
	[ "${tags:-0}" -ge 1 ] && ok "日志里有连接/会话记录（$tags 行）" || no "日志里没有连上过的记录"
	exit 0
fi

[ -x "$CC" ] || { echo "缺交叉编译器：$CC" >&2; exit 1; }

echo "== 1) 交叉编译（musl 静态，设备侧零依赖）"
"$CC" -static -O2 -Wall -Wextra -o "$BIN" "$SRC"
ls -l "$BIN"

echo "== 2) 部署二进制 + user unit"
# ETXTBSY：直接 scp 覆盖正在运行的二进制会 "dest open: Failure" ⇒ 先传 /tmp 再 mv（rename 不受影响）
timeout -k 3 60 scp -o BatchMode=yes "$BIN" "$TAB:/tmp/as-client.new"
# unit 在本地生成再传：远端 heredoc 里嵌 $AS_HOST 会出现「双引号/单引号嵌套」老坑（实测踩过）
UNIT=$(mktemp)
trap 'rm -f "$UNIT"' EXIT
cat > "$UNIT" <<EOF
[Unit]
Description=Audio Share client (receive PC audio → device speaker)
Documentation=https://github.com/mkckr0/audio-share
After=pipewire.service wireplumber.service
Wants=pipewire.service

[Service]
Environment=AS_HOST=$AS_HOST
Environment=AS_PORT=$AS_PORT
EnvironmentFile=-/etc/default/audio-share-client
ExecStart=/bin/sh -c 'exec /usr/local/bin/as-client "\$AS_HOST" "\$AS_PORT"'
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
timeout -k 3 60 scp -o BatchMode=yes "$UNIT" "$TAB:/tmp/audio-share-client.service.new"
"${SSH[@]}" "set -e
chmod 755 /tmp/as-client.new; mv -f /tmp/as-client.new /usr/local/bin/as-client
chmod 644 /tmp/audio-share-client.service.new
mv -f /tmp/audio-share-client.service.new /etc/systemd/user/audio-share-client.service
systemctl daemon-reload
chown -R $DEV_USER:$DEV_USER /home/$DEV_USER/.config/systemd 2>/dev/null || true"
fix "已写 /usr/local/bin/as-client + /etc/systemd/user/audio-share-client.service"

echo "== 3) 以桌面用户启用（PipeWire 在同一 user manager 里）"
userctl daemon-reload >/dev/null
userctl enable --now audio-share-client.service >/dev/null
sleep 3
act=$(userctl is-active audio-share-client 2>/dev/null || true)
[ "$act" = active ] && fix "audio-share-client active（$AS_HOST:$AS_PORT）" || no "启用后仍未 active（$act）"

echo "== 4) 反向自检（最近日志）"
"${SSH[@]}" "runuser -u $DEV_USER -- env XDG_RUNTIME_DIR=/run/user/$DEV_UID journalctl --user-unit audio-share-client -n 6 --no-pager -q" | tail -6
echo "== 完成。主机侧记得：as-cmd 绑 0.0.0.0 + ufw 放行 192.168.7.0/24 的 $AS_PORT/tcp,udp"
