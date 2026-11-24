#!/usr/bin/env bash
# as-client-deploy.sh — 把 Audio Share 的 Linux 客户端（deb 包：as-client + GUI + 图标 + user unit）装到平板
#
# 现状（2026-11-24 起）：客户端以 **deb 包** 交付，源码在**上游 fork** `xiaquwan1001/audio-share`
# 的 `linux-client/`（本仓 `rootfs/debian/audio-share/as-client.c` 只是镜像）。本脚本 =
# 主机交叉编 deb → 推到平板 → `dpkg -i` → 写配置 → 起 user unit。
#
#   包内容：/usr/bin/as-client（musl 静态，零运行时库）
#           /usr/bin/audio-share-gui（GTK3 + python3-gi，桌面图标点开即用）
#           /usr/bin/audio-share-client-run（读 config.json 的 wrapper）
#           /usr/share/applications/audio-share-client.desktop + hicolor/scalable 图标
#           /usr/lib/systemd/user/audio-share-client.service（开机自连）
#   配置：/home/<dev-user>/.config/audio-share-client/config.json {host,port,target,latency,autostart}
#
# 为什么有自己实现的那一端（2026-11-20）：上游 mkckr0/audio-share 只发 Android 客户端，
# `as-cmd` 是服务端。协议逐字节依据 = 上游 Android 源码
# `android-app/.../service/{NetClient,NetworkIO}.kt`：
#   TCP: int32le CMD_GET_FORMAT(1) → int32le 1 + int32le size + protobuf AudioFormat
#        int32le CMD_START_PLAY(2) → int32le 2 + int32le id
#   UDP: 客户端绑随机端口，先发 int32le id 到 srv:65530，之后服务端推原始 PCM 数据报
#   心跳: 服务端 TCP 发 3，客户端原样回 3（5 s 内不回会被踢）
#
# 主机侧配套（一次性，本脚本不代做）：
#   ① PC 服务：`%h/bin/as-cmd` 必须绑 **0.0.0.0**（历史手工实例只绑手机网段 192.168.42.97，
#      平板走 USB-NCM 192.168.7.0/24 连不进来）。实测用 user unit：
#        ~/.config/systemd/user/audio-share-server.service
#        ExecStart=%h/bin/as-cmd --bind=0.0.0.0 ; Restart=always ; WantedBy=default.target
#   ② 防火墙：`ufw allow from 192.168.7.0/24 to any port 65530 proto tcp` / `... proto udp`
#   ③ 冷起无声判据：`as-cmd` 采集线程只在启动时枚举一次 sink，空则永久退出（服务照旧
#      listening、客户端照旧重连并刷 `AudioFormat 尺寸异常 0`）⇒ 确认 `as-cmd -l` 有 sink
#      后重启 audio-share-server。上游未修。
#
# 用法：
#   scripts/as-client-deploy.sh --check        # 只读体检（包/入口/GUI/单元/运行值/端到端）
#   scripts/as-client-deploy.sh               # 真装（建 deb → scp → dpkg -i → 配置 → 起服务）
#   AS_HOST=192.168.7.9 AS_PORT=65530 TAB=root@192.168.7.1 scripts/as-client-deploy.sh
#   FORK_DIR=~/forks/audio-share SKIP_BUILD=1 scripts/as-client-deploy.sh   # 复用现成 deb
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TAB=${TAB:-root@192.168.7.1}
AS_HOST=${AS_HOST:-192.168.7.9}    # 主机 USB-NCM 侧地址（NM 连接 elden-usb-gadget）
AS_PORT=${AS_PORT:-65530}
DEV_USER=${DEV_USER:-xuqianhui1001}
DEV_UID=${DEV_UID:-1001}
FORK_DIR=${FORK_DIR:-$HOME/forks/audio-share}
PKG=audio-share-client
MODE=apply

case "${1:-}" in
--check) MODE=check ;;
--apply|"") MODE=apply ;;
-h|--help) sed -n '2,42p' "$0"; exit 0 ;;
*) echo "未知参数 $1（--check / --apply）" >&2; exit 2 ;;
esac

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10 "$TAB")
say() { printf '%-6s %s\n' "$1" "$2"; }
ok() { say ok "$1"; }
no() { say MISS "$1"; }
fix() { say FIX "$1"; }

userctl() { "${SSH[@]}" "runuser -u $DEV_USER -- env XDG_RUNTIME_DIR=/run/user/$DEV_UID systemctl --user $*"; }

if [ "$MODE" = check ]; then
	pkg=$("${SSH[@]}" "dpkg -s $PKG >/dev/null 2>&1 && echo 1 || echo 0")
	ver=$("${SSH[@]}" "dpkg-query -W -f='\${Version}' $PKG 2>/dev/null || true")
	bin=$("${SSH[@]}" 'test -x /usr/bin/as-client && echo 1 || echo 0')
	gui=$("${SSH[@]}" 'test -x /usr/bin/audio-share-gui && echo 1 || echo 0')
	entry=$("${SSH[@]}" 'test -f /usr/share/applications/audio-share-client.desktop && echo 1 || echo 0')
	icon=$("${SSH[@]}" 'test -f /usr/share/icons/hicolor/scalable/apps/audio-share-client.svg && echo 1 || echo 0')
	unit=$("${SSH[@]}" 'test -f /usr/lib/systemd/user/audio-share-client.service && echo 1 || echo 0')
	legacy=$("${SSH[@]}" 'test -f /etc/systemd/user/audio-share-client.service && echo 1 || echo 0')
	cfg=$("${SSH[@]}" "cat /home/$DEV_USER/.config/audio-share-client/config.json 2>/dev/null | tr -d '\n ' || true")
	act=$(userctl is-active audio-share-client 2>/dev/null || echo unknown)
	tags=$("${SSH[@]}" "runuser -u $DEV_USER -- env XDG_RUNTIME_DIR=/run/user/$DEV_UID journalctl --user-unit audio-share-client -n 40 --no-pager -q 2>/dev/null | grep -cE 'TCP connected|play session' || true")
	pw=$("${SSH[@]}" "runuser -u $DEV_USER -- env XDG_RUNTIME_DIR=/run/user/$DEV_UID wpctl status 2>/dev/null | grep -c 'pw-cat' || true")

	[ "${pkg:-0}" = 1 ] && ok "包 $PKG 已装（${ver:-?}）" || no "未安装 $PKG（跑本脚本，或 dpkg -i dist/${PKG}_*_arm64.deb）"
	[ "${bin:-0}" = 1 ] && ok "/usr/bin/as-client 在" || no "缺 /usr/bin/as-client"
	[ "${gui:-0}" = 1 ] && ok "GUI 在（桌面图标点开即用）" || no "缺 /usr/bin/audio-share-gui"
	[ "${entry:-0}" = 1 ] && ok "桌面入口在" || no "缺 .desktop 入口"
	[ "${icon:-0}" = 1 ] && ok "图标在" || no "缺 hicolor 图标"
	[ "${unit:-0}" = 1 ] && ok "打包 user unit 在" || no "缺 /usr/lib/systemd/user 单元"
	[ "${legacy:-0}" = 0 ] && ok "无 /etc 旧单元覆盖" || no "存在 /etc/systemd/user 旧单元（覆盖包内单元，应删）"
	[ -n "${cfg:-}" ] && ok "配置：$cfg" || no "缺 config.json（GUI 第一次打开会生成）"
	[ "${act:-}" = active ] && ok "audio-share-client 运行中（连 $AS_HOST:$AS_PORT）" || no "audio-share-client 未运行（$act）"
	[ "${tags:-0}" -ge 1 ] && ok "日志里有连接/会话记录（$tags 行）" || no "日志里没有连上过的记录"
	[ "${pw:-0}" -ge 1 ] && ok "设备 PipeWire 里有 pw-cat 流（端到端通）" || no "设备 PipeWire 里没有 pw-cat 流"
	exit 0
fi

if [ "${SKIP_BUILD:-0}" != 1 ]; then
	[ -d "$FORK_DIR/linux-client" ] || { echo "缺 fork：$FORK_DIR（设 FORK_DIR=…）" >&2; exit 1; }
	echo "== 1) 建 deb（arm64，musl 静态 as-client + GTK GUI）"
	(cd "$FORK_DIR/linux-client" && ./deb/build-deb.sh) | tail -3
fi
DEB=$(ls -t "$FORK_DIR"/dist/${PKG}_*_arm64.deb 2>/dev/null | head -1)
[ -n "${DEB:-}" ] && [ -f "$DEB" ] || { echo "找不到 deb（$FORK_DIR/dist）" >&2; exit 1; }

echo "== 2) 推包 + dpkg -i"
timeout -k 3 120 scp -o BatchMode=yes -q "$DEB" "$TAB:/tmp/"
"${SSH[@]}" "dpkg -i /tmp/$(basename "$DEB") 2>&1 | tail -4"

echo "== 3) 迁到包内单元（清旧覆盖）+ 写配置"
"${SSH[@]}" "set -e
if [ -f /etc/systemd/user/audio-share-client.service ]; then
  mv /etc/systemd/user/audio-share-client.service /root/audio-share-client.service.pre-deb
fi
if [ -f /usr/local/bin/as-client ]; then
  mv /usr/local/bin/as-client /root/as-client.pre-deb
fi
install -d -o $DEV_USER -g $DEV_USER /home/$DEV_USER/.config/audio-share-client
printf '{\n  \"host\": \"%s\",\n  \"port\": %s,\n  \"target\": \"\",\n  \"latency\": \"\",\n  \"autostart\": true\n}\n' '$AS_HOST' '$AS_PORT' > /home/$DEV_USER/.config/audio-share-client/config.json
chown $DEV_USER:$DEV_USER /home/$DEV_USER/.config/audio-share-client/config.json"

echo "== 4) 以桌面用户启用（PipeWire 在同一 user manager 里）"
userctl daemon-reload >/dev/null
userctl enable audio-share-client.service >/dev/null
userctl restart audio-share-client.service >/dev/null
sleep 4
act=$(userctl is-active audio-share-client 2>/dev/null || true)
[ "$act" = active ] && fix "audio-share-client active（$AS_HOST:$AS_PORT）" || no "启用后仍未 active（$act）"

echo "== 5) 反向自检（最近日志）"
"${SSH[@]}" "runuser -u $DEV_USER -- env XDG_RUNTIME_DIR=/run/user/$DEV_UID journalctl --user-unit audio-share-client -n 6 --no-pager -q" | tail -6
echo "== 完成。主机侧记得：as-cmd 绑 0.0.0.0 + ufw 放行 192.168.7.0/24 的 $AS_PORT/tcp,udp"
