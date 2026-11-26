#!/bin/bash
# deploy-desktop-shell.sh — 把「minbase 根」补成能起 Phosh 桌面的 appliance（主机侧驱动，幂等）
#
# 为什么有这个脚本（2026-11-19）：11-19 下午的 root = 6 GiB minbase（Debian 13 trixie，165 包，
# 没有 udev/桌面包）。手工把桌面拉起来时踩到四个点，全部在此固化：
#   ① 缺 `udev` → 模块零加载（该坑已在 11-19 另一条 session 落账；本脚本 2b) 已机械化）
#   ② `phosh` 0.46 的 gnome-session 会话**必须**有 `sm.puri.OSK0`（Debian 包名
#      `phosh-osk-stub`），缺它 = `Unable to find required component 'sm.puri.OSK0'`
#      → `gnome-session-failed` → 屏上只有黑底转圈；
#   ③ Debian trixie 的 Mesa 25.0.7 freedreno 不认识 Adreno 830
#      （`MESA: error: fd_pipe_new2: unsupported GPU id 0x0 / chip id 0xe844050000`）
#      → phoc GL 后端起不来 → greetd 5 次 start-limit-hit；
#      处置 = `/etc/elden-soft-render`（pixman 软合成，见 elden-session-user）；
#   ④ `gsettings`（`libglib2.0-bin`）缺失 → gnome-session 的环境探测脚本报错。
#
# 用法（主机侧，设备已在 USB-NCM 上可达）：
#   scripts/deploy-desktop-shell.sh            # 真跑
#   scripts/deploy-desktop-shell.sh --check    # 只报告（不改设备）
#   TAB=root@192.168.7.1 scripts/deploy-desktop-shell.sh
#
# 判据（--check 退出码 0 = 已达标）：
#   a) 包齐：udev phosh phoc greetd seatd gnome-session-bin phosh-osk-stub libglib2.0-bin
#      gnome-settings-daemon upower dbus-x11
#   a2) systemd-udevd = active + /dev/dri/card0 + /dev/fb0 + DPU 聚合 bound（PITFALLS #681：
#      装有 udev 但服务没起来 = 零模块加载，症状与「显示链坏」无法区分）
#   b) 桌面用户 xuqianhui1001 存在；/usr/local/sbin/elden-session-user 与仓内逐字节相同
#   c) `systemctl is-active greetd` = active；`phoc`+`phosh`+`phosh-osk-stub` 三进程在
#   d) `grim` 截图 > 20 KB（黑底转圈那种只有 ~33 KB 且**没有顶栏**，靠人眼/字节双门，
#      脚本只判字节；顶栏判据见 PITFALLS 新增条）
#   e) 「返回」关窗链在位（§15）：`wm.keybindings close` 解析后含 'XF86Back' + lisgd + uinput-back
#
# 回归门：scripts/doctor/22-desktop-chain.py（check-doctor §22）静态校验「包集/服务/坑号/手册步」
#   四者不漂移——例如有人从 PKGS 里删掉 udev 或 phosh-osk-stub，§22 立刻 FAIL。
#
# 纪律：设备写入走 scripts/device-lock.sh 串行；apt 只装不升级；不动机器人内核/引导。
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
TAB=${TAB:-root@192.168.7.1}
T=${T:-8}
# 桌面会话用户（耳机/音频/触觉的 user unit 都跑在它下面；重建根实测 uid=1001）
DEV_USER=${DEV_USER:-xuqianhui1001}
DEV_UID=${DEV_UID:-1001}
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout="$T" -o ConnectionAttempts=1 -o BatchMode=yes -b 0 "$TAB")
SCP=(scp -o StrictHostKeyChecking=no -o ConnectTimeout="$T" -o BatchMode=yes -q)
SESS_USER=$ROOT/packaging/elden-userland/files/usr/local/sbin/elden-session-user
ENSURE_USER=$ROOT/rootfs/debian/ensure-desktop-user.sh
PKGS="udev phosh phoc greetd seatd gnome-session-bin phosh-osk-stub libglib2.0-bin gnome-settings-daemon upower dbus-x11"
MODE=run
case "${1:-}" in
	--check) MODE=check ;;
	-h|--help) sed -n '2,35p' "$0"; exit 0 ;;
	"") ;;
	*) echo "未知参数 ${1:-}" >&2; exit 2 ;;
esac
missing=0
ok()  { printf '  ok    %s\n' "$*"; }
no()  { printf '  MISS  %s\n' "$*"; missing=$((missing + 1)); }
fix() { printf '  FIX   %s\n' "$*"; }

[ -f "$SESS_USER" ] || { echo "缺 $SESS_USER" >&2; exit 2; }
[ -f "$ENSURE_USER" ] || { echo "缺 $ENSURE_USER" >&2; exit 2; }

echo "== 1) 设备可达性 =="
"${SSH[@]}" 'uname -r; . /etc/os-release; echo "$PRETTY_NAME"' || { echo "设备不可达（$TAB）" >&2; exit 3; }

echo "== 2) 包盘点 =="
for p in $PKGS; do
	st=$("${SSH[@]}" "dpkg-query -W -f='\${Status}' $p 2>/dev/null")
	case "$st" in
		# ★2026-11-24：`apt-mark hold` 会把 Status 首字段从 `install` 变成 `hold`
		# （我们用 divert+hold 装自编 osk-stub/phoc，PITFALLS #654）⇒ 只锁 `" ok installed"`，
		# 否则每日门会因「我们自己做的正确动作」常红（实测 phosh-osk-stub 假 MISS）。
		*" ok installed") ok "$p" ;;
		*)
			if [ "$MODE" = check ]; then no "$p"; else
				"${SSH[@]}" "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $p >/tmp/apt-$p.log 2>&1" \
					&& fix "$p 已装" || no "$p 安装失败（/tmp/apt-$p.log）"
			fi ;;
	esac
done

# 2b) udev —— minbase 根的头号坑（PITFALLS #681）：没有 systemd-udevd 时**任何**模块都不会
# 被 modalias 自动加载（fastrpc/ath12k/音频/DP bridge 全缺），DP 组件一直 defer 拖死 DPU
# 聚合 ⇒ 症状是「只有背光 + /sys/class/drm 里只有 version」，看起来像 DTB/DP 布线坏。
# 判据 = 服务 active + card0/fb0 在；不是「包装了」就算过（装了没启用照样零加载）。
echo "== 2b) udev / 模块自动加载（#681）=="
udev_st=$("${SSH[@]}" 'systemctl is-active systemd-udevd 2>/dev/null')
if [ "$udev_st" = active ]; then
	ok "systemd-udevd active"
elif [ "$MODE" = check ]; then
	no "systemd-udevd 非 active（模块不会自动加载 ⇒ 无 /dev/dri）"
else
	"${SSH[@]}" 'systemctl enable --now systemd-udevd >/dev/null 2>&1; systemctl is-active systemd-udevd' >/dev/null \
		&& fix "已 enable --now systemd-udevd" || no "起 systemd-udevd 失败"
fi
ndri=$("${SSH[@]}" 'ls /dev/dri/card0 /dev/fb0 2>/dev/null | wc -l' 2>/dev/null)
if [ "${ndri:-0}" -ge 2 ] 2>/dev/null; then
	ok "/dev/dri/card0 + /dev/fb0 在（GPU/显示已 bind）"
else
	no "缺 /dev/dri/card0 或 /dev/fb0（显示链没起来；查 dmesg 与 device_component）"
fi
# DPU 聚合 = 「显示到底通没通」的唯一结构性判据（#681 就是靠它定位的）。
dpu=$("${SSH[@]}" 'test -d /sys/kernel/debug/device_component || { echo NODEBUGFS; exit 0; }; \
	if grep -qs "aggregate not bound" /sys/kernel/debug/device_component/*display-controller; then echo NOTBOUND; else echo BOUND; fi')
case "$dpu" in
	BOUND)    ok "DPU 组件聚合已 bound（ae01000.display-controller）" ;;
	NOTBOUND) no "DPU 聚合 aggregate not bound（某组件在 defer；先看 dmesg | grep -c bound）" ;;
	*)        no "device_component debugfs 不可读，无法判定 DPU 聚合（挂 debugfs 后重跑）" ;;
esac

echo "== 3) 桌面用户 =="
if "${SSH[@]}" 'getent passwd xuqianhui1001 >/dev/null'; then ok "xuqianhui1001 存在"
elif [ "$MODE" = check ]; then no "缺桌面用户 xuqianhui1001"
else
	"${SCP[@]}" "$ENSURE_USER" "$TAB:/tmp/ensure-desktop-user.sh" &&
		"${SSH[@]}" 'sh /tmp/ensure-desktop-user.sh >/tmp/ensure-user.log 2>&1' &&
		fix "已建 xuqianhui1001（/tmp/ensure-user.log）" || no "建用户失败"
fi

echo "== 3b) 账户接入面（authorized_keys + sudo 免密）=="
# 为什么单列一节（PITFALLS #689）：重建最小根只恢复「包 + 桌面」，**账户接入面不属包**，
# 于是 root 有公钥、`xuqianhui1001` 没有 ⇒ 文档默认入口 `ssh elden` 直接 Permission denied，
# 表现为「ssh 不通 / 设备丢了」，而 root@ 一直好用。
PUBF=${PUBKEY:-$HOME/.ssh/id_rsa.pub}
if [ ! -f "$PUBF" ]; then
	ok "无 $PUBF（跳过接入面检查）"
else
	PUBH=$(sha256sum < "$PUBF" | cut -d' ' -f1)
	DEVH=$("${SSH[@]}" 'sha256sum /home/xuqianhui1001/.ssh/authorized_keys 2>/dev/null | cut -d" " -f1')
	if [ "$DEVH" = "$PUBH" ]; then ok "xuqianhui1001 authorized_keys == 主机公钥（ssh elden 可用）"
	elif [ "$MODE" = check ]; then no "xuqianhui1001 无主机公钥 ⇒ 文档默认入口 ssh elden 会被拒（只有 root@ 可登）"
	else
		"${SSH[@]}" 'install -d -m700 -o xuqianhui1001 -g xuqianhui1001 /home/xuqianhui1001/.ssh' &&
			"${SCP[@]}" "$PUBF" "$TAB:/tmp/elden-pub" &&
			"${SSH[@]}" 'install -m600 -o xuqianhui1001 -g xuqianhui1001 /tmp/elden-pub /home/xuqianhui1001/.ssh/authorized_keys && rm -f /tmp/elden-pub' &&
			fix "已把主机公钥装给 xuqianhui1001" || no "装公钥失败"
	fi
	if [ "$("${SSH[@]}" 'su -s /bin/sh xuqianhui1001 -c "sudo -n true" >/dev/null 2>&1 && echo ok')" = ok ]; then
		ok "xuqianhui1001 sudo -n 免密可用"
	elif [ "$MODE" = check ]; then no "xuqianhui1001 sudo -n 不可用（桌面/维护脚本全靠它，会伴提密码卡住）"
	else
		"${SSH[@]}" 'printf "%s\n" "xuqianhui1001 ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/010-xuqianhui1001 && chmod 440 /etc/sudoers.d/010-xuqianhui1001 && visudo -c >/dev/null && usermod -aG sudo xuqianhui1001' &&
			fix "已加 sudo 免密 + sudo 组" || no "加 sudoers 失败"
	fi
fi

echo "== 4) 会话包装脚本 =="
if [ "$("${SSH[@]}" 'sha256sum /usr/local/sbin/elden-session-user 2>/dev/null | cut -d" " -f1')" = "$(sha256sum "$SESS_USER" | cut -d' ' -f1)" ]; then
	ok "elden-session-user 与仓内一致"
elif [ "$MODE" = check ]; then no "elden-session-user 缺/与仓内不一致"
else
	"${SCP[@]}" "$SESS_USER" "$TAB:/tmp/euser" &&
		"${SSH[@]}" 'sh -n /tmp/euser && install -m755 /tmp/euser /usr/local/sbin/elden-session-user' &&
		fix "已装 elden-session-user" || no "装 elden-session-user 失败"
fi

echo "== 4b) 时间同步脚本（RTC 写不了 ⇒ 每次冷起都要补时钟）=="
TSYNC=$ROOT/packaging/elden-userland/files/usr/local/sbin/time-sync.sh
if [ -f "$TSYNC" ]; then
	if [ "$("${SSH[@]}" 'sha256sum /usr/local/sbin/time-sync.sh 2>/dev/null | cut -d" " -f1')" = "$(sha256sum "$TSYNC" | cut -d' ' -f1)" ]; then
		ok "time-sync.sh 与仓内一致"
	elif [ "$MODE" = check ]; then no "time-sync.sh 缺/与仓内不一致（冷起时钟不会补）"
	else
		"${SCP[@]}" "$TSYNC" "$TAB:/tmp/tsync" &&
			"${SSH[@]}" 'sh -n /tmp/tsync && install -m755 /tmp/tsync /usr/local/sbin/time-sync.sh' &&
			fix "已装 time-sync.sh" || no "装 time-sync.sh 失败"
	fi
fi

echo "== 5) greetd appliance 配置 =="
CFG=$(cat <<'EOF'
# /etc/greetd/config.toml — auto-login xuqianhui1001, appliance mode.
# GENERATED by scripts/deploy-desktop-shell.sh — 覆盖 Debian 包默认的 agreety greeter。
[terminal]
vt = 7

[initial_session]
command = "/usr/local/sbin/elden-session-user"
user = "xuqianhui1001"

[default_session]
command = "/usr/local/sbin/elden-session-user"
user = "xuqianhui1001"
EOF
)
if [ "$("${SSH[@]}" 'grep -c "elden-session-user" /etc/greetd/config.toml 2>/dev/null')" -ge 2 ] 2>/dev/null; then
	ok "config.toml 已是 appliance 模式"
elif [ "$MODE" = check ]; then no "config.toml 不是 appliance 模式（会停在 agreety 文本 greeter）"
else
	printf '%s\n' "$CFG" | "${SSH[@]}" 'cat > /etc/greetd/config.toml' && fix "已写 config.toml" || no "写 config.toml 失败"
fi
# 覆盖 Debian greetd-phrog 的 drop-in（图形 greeter → phrog，本机要 phosh）
if "${SSH[@]}" 'test -f /etc/systemd/system/greetd.service.d/zz-elden.conf'; then ok "greetd drop-in 在"
elif [ "$MODE" = check ]; then no "缺 greetd drop-in（若装了 greetd-phrog 会只出登录界面）"
else
	"${SSH[@]}" 'mkdir -p /etc/systemd/system/greetd.service.d && printf "%s\n" "# GENERATED by scripts/deploy-desktop-shell.sh" "[Service]" "ExecStart=" "ExecStart=/usr/sbin/greetd --config /etc/greetd/config.toml" > /etc/systemd/system/greetd.service.d/zz-elden.conf' &&
		fix "已写 greetd drop-in" || no "写 drop-in 失败"
fi

echo "== 6) 软件合成开关（Mesa 不认 Adreno 830 时）=="
if "${SSH[@]}" 'test -e /etc/elden-soft-render'; then ok "/etc/elden-soft-render 在（pixman 软合成）"
elif "${SSH[@]}" 'journalctl -b -t phoc --no-pager 2>/dev/null | grep -q fd_pipe_new2'; then
	if [ "$MODE" = check ]; then no "phoc 起不来（fd_pipe_new2）但缺 /etc/elden-soft-render"
	else "${SSH[@]}" 'touch /etc/elden-soft-render' && fix "已 touch /etc/elden-soft-render" || no "touch 失败"; fi
else
	ok "无 fd_pipe_new2 证据（保持 GL 路径；若桌面仍黑屏再手动 touch 该开关）"
fi

echo "== 7) 网络前置（usb0 默认路由 + DNS）=="
# 设备侧 usb0 只有 192.168.7.1/24 静态地址、**不发也不设默认网关**（stage.sh 的 udhcpd 只发地址）。
# 主机侧配好 NAT（`iptables -t nat -A POSTROUTING -s 192.168.7.0/24 -j MASQUERADE`）后，
# 设备要自己把默认路由指向宿主 192.168.7.3，否则 apt/curl 全 `Network is unreachable`。
# 2026-11-19 实测两次踩坑：① 一次性 oneshot 在「宿主地址还没配好」时跑空就再也不补
#   （重启后 20 s 判据太短）；② 主机侧 `ip addr add` 会随 gadget 重建而消失 ⇒ 改成**常驻
#   自愈循环**（Type=simple，每 15 s 检查缺默认路由就补，宿主可达才补）。
ROUTE_UNIT=/etc/systemd/system/usb0-host-route.service
if [ "$MODE" = check ]; then
	"${SSH[@]}" "test -f $ROUTE_UNIT" && ok "usb0-host-route.service 已装" || no "缺 usb0-host-route.service（重启后默认路由会丢）"
else
	"${SSH[@]}" 'cat > /usr/local/sbin/usb0-host-route.sh <<"EOS"
#!/bin/sh
# usb0-host-route.sh — USB-NCM 设备侧「默认路由到宿主」的自愈循环（幂等、常驻）。
# 只在宿主 192.168.7.3 真可达时才加，避免把一台脱网设备搞得更脱网。
set -u
HOST=${HOST:-192.168.7.3}
DEV=${DEV:-usb0}
INTERVAL=${INTERVAL:-15}
while :; do
	if ! ip route show default 2>/dev/null | grep -q .; then
		if ip -4 addr show "$DEV" 2>/dev/null | grep -q "inet " && ping -c1 -W1 "$HOST" >/dev/null 2>&1; then
			ip route replace default via "$HOST" dev "$DEV" && echo "[usb0-route] default via $HOST dev $DEV"
			# 网络一来就补时钟（RTC 写不了 ⇒ 每次冷起系统时间都是镜像构建日，
			# 起来时若还没有默认路由，开机那次 time-sync 早已放弃；这里补跑一次）。
			if [ -x /usr/local/sbin/time-sync.sh ]; then
				setsid /usr/local/sbin/time-sync.sh >/dev/null 2>&1 &
			fi
		fi
	fi
	sleep "$INTERVAL"
done
EOS
chmod 755 /usr/local/sbin/usb0-host-route.sh
cat > /etc/systemd/system/usb0-host-route.service <<"EOS"
[Unit]
Description=USB-NCM host default route (192.168.7.3), self-healing
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/usb0-host-route.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload
systemctl enable usb0-host-route.service >/dev/null 2>&1
systemctl restart usb0-host-route.service' && fix "已装/重启 usb0-host-route.service（自愈循环）" || no "装 usb0-host-route 失败"
fi
if "${SSH[@]}" 'ip route show default 2>/dev/null | grep -q .'; then
	ok "当前默认路由：$("${SSH[@]}" 'ip route show default | head -1')"
else
	no "当前无默认路由（宿主不可达？journalctl -u usb0-host-route）"
fi
# DNS：minbase 根只有 systemd-resolved stub，没有上游 ⇒ 解析全空（getent 返回空）。
if "${SSH[@]}" 'test -f /etc/systemd/resolved.conf.d/99-usb-dns.conf'; then ok "resolved 上游 DNS 已配"
elif [ "$MODE" = check ]; then no "缺 resolv 上游 DNS（resolvectl query 会失败）"
else
	"${SSH[@]}" 'mkdir -p /etc/systemd/resolved.conf.d && printf "[Resolve]\nDNS=223.5.5.5 202.38.64.18\nFallbackDNS=1.1.1.1\n" > /etc/systemd/resolved.conf.d/99-usb-dns.conf && systemctl restart systemd-resolved' \
		&& fix "已写 resolved DNS 上游" || no "写 DNS 配置失败"
fi

echo "== 8) GPU devfreq 固化（T19 首绘卡顿）=="
# daily-baseline.sh §5 只在跑的那一刻写 sysfs（重启即回默认 160 MHz / 50 ms）⇒
# 桌面每次冷起都先吃一段爬频延迟。这里固化成开机 oneshot。
GPU_UNIT=/etc/systemd/system/gpu-devfreq-tune.service
GPU_SCRIPT=/usr/local/sbin/gpu-devfreq-tune.sh
# 2026-11-20 实测坑（本脚本旧版）：只 `test -f $GPU_UNIT` 就报 ok ⇒ 出现「unit 在、
# 脚本被删掉、运行值仍是默认 160 MHz / 50 ms」的三处不一致，门照样绿。
# 现在四件一起验：脚本在 + unit enabled + min_freq>=525MHz + polling==10。
GPU_OK=$("${SSH[@]}" 's=0; [ -f /usr/local/sbin/gpu-devfreq-tune.sh ] || s=$((s+1)); systemctl is-enabled gpu-devfreq-tune.service >/dev/null 2>&1 || s=$((s+1)); m=$(cat /sys/class/devfreq/3d00000.gpu/min_freq 2>/dev/null || echo 0); p=$(cat /sys/class/devfreq/3d00000.gpu/polling_interval 2>/dev/null || echo 0); [ "${m:-0}" -ge 525000000 ] 2>/dev/null || s=$((s+1)); [ "${p:-0}" = 10 ] || s=$((s+1)); echo $s')
if [ "${GPU_OK:-9}" = 0 ]; then
	ok "gpu-devfreq-tune 已生效（脚本+unit+min_freq>=525MHz+polling=10）"
elif [ "$MODE" = check ]; then
	no "gpu-devfreq-tune 未真正生效（$GPU_OK/4 项不满足：脚本缺 / unit 未 enabled / min_freq<525MHz / polling!=10）"
else
	"${SSH[@]}" 'cat > /usr/local/sbin/gpu-devfreq-tune.sh <<"EOS"
#!/bin/sh
# gpu-devfreq-tune.sh — T19：把 msm GPU devfreq 调到「负载上升能被快速发现」。
# min_freq 525 MHz（默认 160 MHz）消灭首绘卡顿；polling_interval 10 ms（默认 50 ms）。
# 代价 = 空闲略耗电；要「完全不卡」可把 min_freq 抬到 1100000000（见 daily-baseline.sh §5）。
set -u
G=/sys/class/devfreq/3d00000.gpu
[ -d "$G" ] || { echo "[gpu-tune] $G missing" >&2; exit 0; }
echo 10 > "$G/polling_interval" 2>/dev/null || true
cur=$(cat "$G/min_freq" 2>/dev/null || echo 0)
[ "${cur:-0}" -ge 525000000 ] 2>/dev/null || echo 525000000 > "$G/min_freq" 2>/dev/null || true
EOS
chmod 755 /usr/local/sbin/gpu-devfreq-tune.sh
cat > /etc/systemd/system/gpu-devfreq-tune.service <<"EOS"
[Unit]
Description=Tune msm GPU devfreq (T19 first-paint jank)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/gpu-devfreq-tune.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload; systemctl enable gpu-devfreq-tune.service >/dev/null 2>&1; systemctl restart gpu-devfreq-tune.service; systemctl is-active gpu-devfreq-tune.service; cat /sys/class/devfreq/3d00000.gpu/min_freq' \
		| tail -2 | paste -sd' ' - | { read -r act mn
		if [ "$act" = active ] && [ "${mn:-0}" -ge 525000000 ] 2>/dev/null; then
			fix "已装+启用 gpu-devfreq-tune.service（min_freq=$mn）"
		else
			no "装 gpu-devfreq-tune 后仍不达标（active=$act min_freq=$mn）"
		fi; }
fi

echo "== 8b) 启动队列不卡（#691：卡住的 job 会让桌面永远起不来，屏上停在开机服务日志）=="
# 2026-11-19 实测两次：重装后的最小根里，启动队列被两个「我们用不上的包」卡住时，
#   `systemctl is-system-running` = starting，graphical.target 永远 inactive，
#   greetd 卡在 `Job: … start waiting`，而屏幕就是 tty0 上那屏 systemd 输出。
#   ① droid-juicer.service（Debian-on-phone 的 Android 固件抽取：扫分区/解 super，会卡很久）
#   ② plymouth-quit-wait.service（plymouthd 退不掉 ⇒ boot 永不完结；我们没有 splash 需求）
# 判据 = 两个都 masked + graphical.target active；真跑模式直接 mask。
STUCK_UNITS='droid-juicer.service plymouth-start.service plymouth-quit.service plymouth-quit-wait.service plymouth-switch-root.service'
BAD=$("${SSH[@]}" 'n=0; for u in '$STUCK_UNITS'; do [ "$(systemctl is-enabled $u 2>/dev/null)" = masked ] || n=$((n+1)); done; echo $n')
if [ "${BAD:-9}" = 0 ]; then ok "启动队列阻塞件已全部 mask（$STUCK_UNITS）"
elif [ "$MODE" = check ]; then no "启动队列仍有 $BAD 个未 mask 的阻塞件 ⇒ graphical.target 可能永远 waiting（#691）"
else
	"${SSH[@]}" 'for u in '$STUCK_UNITS'; do systemctl disable --now $u >/dev/null 2>&1; systemctl mask $u >/dev/null 2>&1; done' &&
		fix "已 disable+mask droid-juicer / plymouth*（队列解锁，greetd 才能起）" || no "mask 阻塞件失败"
fi
if [ "$("${SSH[@]}" 'systemctl is-active graphical.target')" = active ]; then ok "graphical.target active（启动队列已走完）"
else no "graphical.target 未激活（queue 有 job 在跑/等；先看 systemctl list-jobs）"; fi

echo "== 9) 会话现态 =="

if [ "$MODE" = check ]; then
	"${SSH[@]}" 'systemctl is-active greetd; ps -eo comm 2>/dev/null | grep -cE "^(phoc|phosh|phosh-osk-stub)$"' | paste -sd' ' - | {
		read -r act n
		[ "$act" = active ] && ok "greetd active" || no "greetd=$act"
		[ "${n:-0}" -ge 3 ] && ok "phoc/phosh/osk 三进程在（$n）" || no "会话进程数=$n（<3）"
	}
else
	"${SSH[@]}" 'systemctl reset-failed greetd 2>/dev/null; systemctl enable greetd >/dev/null 2>&1; systemctl restart greetd; sleep 20; systemctl is-active greetd'
	act=$("${SSH[@]}" 'systemctl is-active greetd')
	n=$("${SSH[@]}" 'ps -eo comm 2>/dev/null | grep -cE "^(phoc|phosh|phosh-osk-stub)$"')
	[ "$act" = active ] && ok "greetd active" || no "greetd=$act（journalctl -u greetd）"
	[ "${n:-0}" -ge 3 ] && ok "会话进程在（$n）" || no "会话进程数=$n（<3）"
	"${SSH[@]}" 'runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 grim /tmp/desk-deploy.png' &&
		sz=$("${SSH[@]}" 'stat -c %s /tmp/desk-deploy.png 2>/dev/null') &&
		[ "${sz:-0}" -gt 20000 ] && ok "grim 截图 ${sz}B（/tmp/desk-deploy.png）" || no "grim 截图失败/过小（$sz）"
fi

echo "== 10) 音频（tplg + UCM2 + 路由；重建根必丢，2026-11-20 实测） =="
# 为什么要在本脚本里（2026-11-20）：重建的 minbase 根里 /lib/firmware/qcom/sm8750/
# 没有自编 tplg、UCM2 下标也没装 ⇒ 卡片能注删但 PipeWire 只有「虚拟输出」(auto_null)，
# dmesg 出 `MultiMedia1 Playback: no backend DAIs enabled … possibly missing … UCM profile`。
# 判据四件：tplg 在 + UCM 两文件在 + `wpctl` 的 Sink 名含 Speaker（不是虚拟输出）+ amixer 可用。
AUDIO_STATE=$("${SSH[@]}" 'set -e
c=0
[ -f /lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin ] || c=$((c+1))
[ -f /usr/share/alsa/ucm2/Qualcomm/sm8750/Lenovo-Y700-Gen4/HiFi.conf ] || c=$((c+1))
[ -f /usr/share/alsa/ucm2/conf.d/sm8750/Lenovo-Y700-Gen4.conf ] || c=$((c+1))
command -v amixer >/dev/null 2>&1 || c=$((c+1))
echo $c')
SINK=$("${SSH[@]}" 'runuser -u '"$DEV_USER"' -- env XDG_RUNTIME_DIR=/run/user/'"$DEV_UID"' wpctl status 2>/dev/null | sed -n "/Sinks:/,/Sources:/p" | grep -vE "Sinks:|Sources:" | head -3 | tr -s " "' 2>/dev/null || true)
if [ "${AUDIO_STATE:-9}" = 0 ] && printf '%s' "$SINK" | grep -qi 'Speaker'; then
	ok "音频就绪（tplg + UCM2 + amixer，Sink=$(printf '%s' "$SINK" | tr -d '\n'))"
elif [ "$MODE" = check ]; then
	no "音频未就绪（缺件数=$AUDIO_STATE，Sink=$(printf '%s' "$SINK" | tr -d '\n')）"
else
	timeout -k 3 60 scp -r "$ROOT/scripts/audio-ucm" "$TAB:/usr/local/sbin/audio-ucm" >/dev/null 2>&1 || true
	timeout -k 3 60 scp "$ROOT/scripts/audio-tplg/out/Lenovo-Y700-Gen4-tplg.bin" "$TAB:/lib/firmware/qcom/sm8750/" >/dev/null 2>&1 || true
	timeout -k 3 60 scp "$ROOT/scripts/audio-alsa-init.sh" "$TAB:/usr/local/sbin/audio-alsa-init.sh" >/dev/null 2>&1 || true
	"${SSH[@]}" 'set -e
chmod +x /usr/local/sbin/audio-ucm/install.sh /usr/local/sbin/audio-alsa-init.sh
sh /usr/local/sbin/audio-ucm/install.sh >/dev/null
command -v amixer >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y alsa-utils >/dev/null 2>&1 || true
sh /usr/local/sbin/audio-alsa-init.sh >/dev/null 2>&1 || true
runuser -u '"$DEV_USER"' -- env XDG_RUNTIME_DIR=/run/user/'"$DEV_UID"' systemctl --user restart wireplumber pipewire >/dev/null 2>&1 || true
sleep 4' 
	SINK=$("${SSH[@]}" 'runuser -u '"$DEV_USER"' -- env XDG_RUNTIME_DIR=/run/user/'"$DEV_UID"' wpctl status 2>/dev/null | sed -n "/Sinks:/,/Sources:/p" | grep -vE "Sinks:|Sources:" | head -3 | tr -s " "' 2>/dev/null || true)
	printf '%s' "$SINK" | grep -qi 'Speaker' \
		&& fix "音频已就绪（Sink=$(printf '%s' "$SINK" | tr -d '\n')）" \
		|| no "装了 tplg/UCM 但 Sink 仍不是 Speaker（$(printf '%s' "$SINK" | tr -d '\n')）"
fi

echo "== 11) 触觉（aw86927 FF 两个马达 + ffrumble 取证工具） =="
# 硬件 = AW86937（驱动为 aw86927 + 上游 haptics-v3 系列），内核注册两枚 input FF 设备。
# 判据：≥ 2 个 aw86927-haptics 的 event 节点 + /usr/local/bin/ffrumble 在（宿主基线工具）。
HAP=$("${SSH[@]}" 'n=0; for e in /sys/class/input/event*; do [ "$(cat $e/device/name 2>/dev/null)" = aw86927-haptics ] && n=$((n+1)); done; echo $n')
HAPTOOL=$("${SSH[@]}" 'test -x /usr/local/bin/ffrumble && echo 1 || echo 0')
if [ "${HAP:-0}" -ge 2 ] && [ "${HAPTOOL:-0}" = 1 ]; then
	ok "触觉就绪（aw86927-haptics ×$HAP + ffrumble）"
elif [ "$MODE" = check ]; then
	no "触觉未就绪（haptics 节点=$HAP，ffrumble=$HAPTOOL）"
else
	[ -x "$ROOT/out/ffrumble/ffrumble" ] || bash "$ROOT/scripts/build-ffrumble.sh" >/dev/null 2>&1 || true
	[ -x "$ROOT/out/ffrumble/ffrumble" ] && timeout -k 3 60 scp "$ROOT/out/ffrumble/ffrumble" "$TAB:/usr/local/bin/ffrumble" >/dev/null 2>&1 && "${SSH[@]}" 'chmod 755 /usr/local/bin/ffrumble' || true
	HAPTOOL=$("${SSH[@]}" 'test -x /usr/local/bin/ffrumble && echo 1 || echo 0')
	[ "${HAP:-0}" -ge 2 ] && [ "$HAPTOOL" = 1 ] && fix "触觉就绪（aw86927-haptics ×$HAP + ffrumble）" \
		|| no "触觉仍缺（haptics=$HAP ffrumble=$HAPTOOL）"
fi

echo "== 12) T9 资源采样器（重启根必丢：脚本 + timer + /var/lib/elden，2026-11-21 实测） =="
# 为什么在本脚本里：T9 = 「同一设备同一软件跨 suspend 周期」的资源趋势采样（用户 2026-11-13 口径，
# 不追精密电流）。它由 scripts/suspend-resource-sample.sh + 两枚手写单元
# （rootfs/debian/units-extra/elden-resource-sample.{service,timer}）组成，**都不是包**：
# 11-19 重建根后脚本/单元/数据目录三样全无 ⇒ 设备上"没有数据"被读成"还没到下结论的时候"。
# 判据四件：脚本在且与仓内逐字节相同 + timer enabled + timer active + TSV ≥1 行（含表头）。
T9_TSV=/var/lib/elden/suspend-resource.tsv
T9_SHA_LOCAL=$(sha256sum "$ROOT/scripts/suspend-resource-sample.sh" 2>/dev/null | awk '{print $1}')
T9_STATE=$("${SSH[@]}" 'set -e
c=0
[ -x /usr/local/sbin/suspend-resource-sample.sh ] || c=$((c+1))
systemctl is-enabled elden-resource-sample.timer 2>/dev/null | grep -qx enabled || c=$((c+1))
systemctl is-active elden-resource-sample.timer 2>/dev/null | grep -qx active || c=$((c+1))
[ -s /var/lib/elden/suspend-resource.tsv ] || c=$((c+1))
echo $c' 2>/dev/null || echo 9)
T9_SHA_DEV=$("${SSH[@]}" 'sha256sum /usr/local/sbin/suspend-resource-sample.sh 2>/dev/null | awk "{print \$1}"' 2>/dev/null || true)
if [ "${T9_STATE:-9}" = 0 ] && [ -n "$T9_SHA_LOCAL" ] && [ "$T9_SHA_DEV" = "$T9_SHA_LOCAL" ]; then
	ok "T9 采样器就绪（timer active，表 $(ssh -o BatchMode=yes "$TAB" "wc -l < $T9_TSV" 2>/dev/null) 行）"
elif [ "$MODE" = check ]; then
	no "T9 采样器未就绪（缺件数=$T9_STATE，脚本 sha 设备=${T9_SHA_DEV:-无} 仓内=${T9_SHA_LOCAL:-无}）"
else
	timeout -k 3 60 scp "$ROOT/scripts/suspend-resource-sample.sh" "$TAB:/usr/local/sbin/suspend-resource-sample.sh" >/dev/null 2>&1 || true
	timeout -k 3 60 scp "$ROOT/rootfs/debian/units-extra/elden-resource-sample.service" \
		"$ROOT/rootfs/debian/units-extra/elden-resource-sample.timer" "$TAB:/etc/systemd/system/" >/dev/null 2>&1 || true
	"${SSH[@]}" 'set -e
chmod 755 /usr/local/sbin/suspend-resource-sample.sh
mkdir -p /var/lib/elden
systemctl daemon-reload
systemctl enable --now elden-resource-sample.timer >/dev/null 2>&1
# 立刻采一行，让判据当场有数（不等 10 min OnBootSec）
/bin/sh /usr/local/sbin/suspend-resource-sample.sh tick' \
		&& fix "T9 采样器已装（timer enabled+active，已采首行）" || no "T9 采样器安装失败"
	T9_STATE=$("${SSH[@]}" 'c=0
[ -x /usr/local/sbin/suspend-resource-sample.sh ] || c=$((c+1))
systemctl is-enabled elden-resource-sample.timer 2>/dev/null | grep -qx enabled || c=$((c+1))
systemctl is-active elden-resource-sample.timer 2>/dev/null | grep -qx active || c=$((c+1))
[ -s /var/lib/elden/suspend-resource.tsv ] || c=$((c+1))
echo $c')
	T9_SHA_DEV=$("${SSH[@]}" 'sha256sum /usr/local/sbin/suspend-resource-sample.sh 2>/dev/null | awk "{print \$1}"')
	[ "${T9_STATE:-9}" = 0 ] && [ "$T9_SHA_DEV" = "$T9_SHA_LOCAL" ] \
		&& fix "T9 采样器就绪（脚本 sha 与仓内一致，timer active）" \
		|| no "T9 采样器仍缺（缺件数=$T9_STATE）"
fi

echo "== 13) A/B 槽自动 mark-successful（重启体检；不置位 ~7 次重启卡 fastboot #181/#697） =="
# 为什么在本脚本里：SUCCESSFUL 位不置 ⇒ ABL 每次启动扣 tries_remaining，扣到 0 把槽标
# UNBOOTABLE，设备停在 fastboot（#181），11-20 的「重启又回 fastboot」正是这条（#697）。
# 件 = scripts/fix-ab-mark-successful.sh（运行期 `--mark-once`，读回校验、不吞错）
#      + rootfs/debian/units-extra/ab-mark-successful.service（oneshot，Authored 走 /bin/sh 前缀）。
# 判据五件（--check 只读）：脚本在且 sha 与仓内一致 / 单元在 / is-enabled=enabled /
#   上一次 Result≠failed / 当前 active 槽 `qbootctl -n` = marked successful。
# 与 distro 的 qbootctl.service 关系：同语义另一份实现，两者幂等（本单元先只读、已成功零写盘）。
ABC_SHA_LOCAL=$(sha256sum "$ROOT/scripts/fix-ab-mark-successful.sh" 2>/dev/null | awk '{print $1}')
ABC_STATE=$("${SSH[@]}" 'c=0
[ -x /usr/local/sbin/ab-mark-successful ] || c=$((c+1))
[ -f /etc/systemd/system/ab-mark-successful.service ] || c=$((c+1))
[ "$(systemctl is-enabled ab-mark-successful.service 2>/dev/null)" = enabled ] || c=$((c+1))
[ "$(systemctl show -p Result --value ab-mark-successful.service 2>/dev/null)" != failed ] || c=$((c+1))
s=$(qbootctl -a 2>/dev/null | sed -n "s/.*_\([ab]\)[[:space:]]*$/\1/p" | head -1); s=${s:-b}
qbootctl -n "$s" 2>/dev/null | grep -q ": is marked successful" || c=$((c+1))
echo "$c"' 2>/dev/null || echo 9)
ABC_SHA_DEV=$("${SSH[@]}" 'sha256sum /usr/local/sbin/ab-mark-successful 2>/dev/null | awk "{print \$1}"' 2>/dev/null || true)
ABC_SLOT=$("${SSH[@]}" 'qbootctl -a 2>/dev/null | sed -n "s/.*_\([ab]\)[[:space:]]*$/\1/p" | head -1' 2>/dev/null || true)
if [ "${ABC_STATE:-9}" = 0 ] && [ -n "$ABC_SHA_LOCAL" ] && [ "$ABC_SHA_DEV" = "$ABC_SHA_LOCAL" ]; then
	ok "A/B mark-successful 就绪（单元 enabled、active 槽 _${ABC_SLOT:-?} successful、脚本 sha 与仓内一致）"
elif [ "$MODE" = check ]; then
	no "A/B mark-successful 未就绪（缺件数=$ABC_STATE，脚本 sha 设备=${ABC_SHA_DEV:-无} 仓内=${ABC_SHA_LOCAL:-无}，active 槽 _${ABC_SLOT:-?}）"
else
	timeout -k 3 60 scp "$ROOT/scripts/fix-ab-mark-successful.sh" "$TAB:/usr/local/sbin/ab-mark-successful" >/dev/null 2>&1 || true
	timeout -k 3 60 scp "$ROOT/rootfs/debian/units-extra/ab-mark-successful.service" \
		"$TAB:/etc/systemd/system/ab-mark-successful.service" >/dev/null 2>&1 || true
	"${SSH[@]}" 'set -e
chmod 755 /usr/local/sbin/ab-mark-successful
systemctl daemon-reload
systemctl enable --now ab-mark-successful.service >/dev/null 2>&1
systemctl start ab-mark-successful.service >/dev/null 2>&1 || true
systemctl is-enabled ab-mark-successful.service
systemctl show -p Result --value ab-mark-successful.service' \
		&& fix "A/B mark-successful 已装（enable --now + 当场跑一次；日志 journalctl -u ab-mark-successful）" \
		|| no "A/B mark-successful 安装失败（journalctl -u ab-mark-successful）"
	ABC_SHA_DEV=$("${SSH[@]}" 'sha256sum /usr/local/sbin/ab-mark-successful 2>/dev/null | awk "{print \$1}"' 2>/dev/null || true)
	ABC_SLOT=$("${SSH[@]}" 'qbootctl -a 2>/dev/null | sed -n "s/.*_\([ab]\)[[:space:]]*$/\1/p" | head -1' 2>/dev/null || true)
	[ "$ABC_SHA_DEV" = "$ABC_SHA_LOCAL" ] \
		&& fix "A/B mark-successful 就绪（脚本 sha 与仓内一致，active 槽 _${ABC_SLOT:-?}）" \
		|| no "A/B mark-successful 装后仍缺（sha 设备=${ABC_SHA_DEV:-无} 仓内=${ABC_SHA_LOCAL:-无}）"
fi

# ---------------------------------------------------------------------------
# 14) 输入法候选后端（RIME / B 案件）—— PITFALLS #713
# 为什么要有：B 案 rime 件装好后「打字零候选」的**唯一**原因是
#   `sm.puri.phosh.osk.Completers.Rime user-data` 是空串 ⇒ 我们的 completer 把空值原样塞给
#   `RimeTraits.user_data_dir` ⇒ librime 每次 `deployment_tasks.cc:90 Error creating user data dir:`，
#   schema 从未建成。UI 上没有任何报错，只有 journal 里那一行（冒号后为空 = 空路径指纹）。
# 判据三件（缺一即 MISS）：
#   ① 用户目录存在且属主 = 会话用户（`~/.local` 在重建根后可能是 root，见 #713 连带项）
#   ② gsettings `user-data` = 该目录（dconf 持久化，冷启动存活）
#   ③ 部署产物在（`<user-data>/build/*.prism.bin` 至少一个）——这是「librime 真跑过」的痕迹，
#      只看 gsettings 会把「设了但一次没跑」当成好。
#   ④ **`org.gnome.desktop.a11y.applications screen-keyboard-enabled` = true**
#      （2026-11-24 实测：false 时 osk-stub 的 `set_surface_prop_surface_visible()` 无条件把
#       visible 置 FALSE ⇒ 收到 `zwp_input_method_v2.activate` 也不弹，用户报「键盘唤不起来」的
#       真根因；重建根后该项默认 false，所以必须进日常门）
# 注意：查 gsettings 必须用会话用户 + 会话总线；以 root 无总线查会得到假值（''）。
IME_RIME_USERDIR=""
IME_RIME_TAB=$("${SSH[@]}" 'echo "$(id -un 1001 2>/dev/null):$(id -u 1001 2>/dev/null)"' 2>/dev/null || true)
IME_RIME_U=${IME_RIME_TAB%%:*}; IME_RIME_UID=${IME_RIME_TAB##*:}
if [ -z "$IME_RIME_U" ] || [ -z "$IME_RIME_UID" ]; then
	ime_state=9; ime_dir=""; ime_set=""
else
	ime_dir="/home/$IME_RIME_U/.local/share/rime"
	ime_state=$("${SSH[@]}" "c=0
[ -d '$ime_dir' ] && [ \"\$(stat -c %U '$ime_dir')\" = '$IME_RIME_U' ] || c=\$((c+1))
v=\$(su -l $IME_RIME_U -c 'XDG_RUNTIME_DIR=/run/user/$IME_RIME_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$IME_RIME_UID/bus gsettings get sm.puri.phosh.osk.Completers.Rime user-data' 2>/dev/null | tr -d \"'\")
[ \"\$v\" = '$ime_dir' ] || c=\$((c+1))
ls '$ime_dir'/build/*.prism.bin >/dev/null 2>&1 || c=\$((c+1))
ske=\$(su -l $IME_RIME_U -c 'XDG_RUNTIME_DIR=/run/user/$IME_RIME_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$IME_RIME_UID/bus gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled' 2>/dev/null | tr -d \"'\")
[ \"\$ske\" = true ] || c=\$((c+1))
echo \$c" 2>/dev/null || echo 9)
	ime_set=$("${SSH[@]}" "su -l $IME_RIME_U -c 'XDG_RUNTIME_DIR=/run/user/$IME_RIME_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$IME_RIME_UID/bus gsettings get sm.puri.phosh.osk.Completers.Rime user-data' 2>/dev/null" 2>/dev/null || true)
fi
echo "== 14) 输入法候选后端（RIME；#713：user-data 空串 ⇒ 候选静默为空）=="
if [ "${ime_state:-9}" = 0 ]; then
	ok "RIME 候选后端就绪（$ime_dir 属主正确、gsettings 指它、build/*.prism.bin 在、screen-keyboard-enabled=true）"
elif [ "$MODE" = check ]; then
	no "RIME 候选后端未就绪（缺件数=${ime_state:-9}，gsettings user-data=${ime_set:-查不到}，应为 ${ime_dir:-?}）"
else
	"${SSH[@]}" "install -d -o $IME_RIME_U -g $IME_RIME_U '$ime_dir'
su -l $IME_RIME_U -c 'XDG_RUNTIME_DIR=/run/user/$IME_RIME_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$IME_RIME_UID/bus gsettings set sm.puri.phosh.osk.Completers.Rime user-data $ime_dir'
su -l $IME_RIME_U -c 'XDG_RUNTIME_DIR=/run/user/$IME_RIME_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$IME_RIME_UID/bus gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true'
pkill -x phosh-osk-stub || true" >/dev/null 2>&1 || true
	fix "RIME 候选后端已配（目录+属主+gsettings；osk-stub 已重启，phosh 按需重拉后 build/ 会出现）"
fi

# ---------------------------------------------------------------------------
# 15) 「返回」关窗链（lisgd → uinput-back → KEY_BACK → wm close）—— 2026-11-25 实机验通
# 为什么要有：phoc 0.46 **没有**内置「返回」手势，关当前窗口的唯一入口是 gsettings
#   `org.gnome.desktop.wm.keybindings close`，而它的出厂默认值只有 `['<Alt>F4']`
#   （平板上没有 Alt+F4 这枚键 ⇒ 等于「关不掉」）。
#   链 = lisgd（边缘滑动，apt trixie `0.3.7-1+b1`）→ /usr/local/bin/uinput-back
#   （uinput 发 KEY_BACK）→ xkb 把 KEY_BACK 映射成 `XF86Back` → phoc 执行 close。
#   实测指纹：XF86Back **不在** close 里时同一次按键窗口不关；幂等并入后同一次按键 foot 1→0。
#   ⇒ 三件缺任何一件，「滑动返回关窗」都是静默失效（没有任何界面报错），所以进日常门。
# 判据三件（缺一即 MISS）：
#   ① close 绑定**解析后**含 'XF86Back'。判据读 gsettings 输出后用 python3 按 GVariant
#      **列表元素**比对；不做全文 grep：`['<Alt>F4']` 这类默认值/改写串很容易假命中，
#      而 `['<Control>XF86BackX']` 这种「字串里带 XF86Back 但按出来不是它」的也必须算 MISS。
#   ② `command -v lisgd`（手势事件源；运行态归会话管，本脚本只判「在位」）
#   ③ `command -v uinput-back`（真正发 KEY_BACK 的件；源件 = out/tools/uinput-back，
#      由 tools/uinput-back-build.sh 产出）
command -v python3 >/dev/null 2>&1 || { echo "缺主机 python3（§15 判据要解析 gsettings 输出）" >&2; exit 2; }

# close_has_xf86back — 判据①的纯函数：stdin 吃 `gsettings get … close` 的原始文本，
# 退出码 0=列表里有 XF86Back / 1=没有 / 2=读不懂（读不懂**不算**命中）。
close_has_xf86back() {
	python3 -c '
import ast, sys
raw = sys.stdin.read().strip()
if raw.startswith("@as "):        # gsettings 空数组会打成 `@as []`
    raw = raw[4:].strip()
try:
    val = ast.literal_eval(raw)
except Exception:
    sys.exit(2)
if not isinstance(val, (list, tuple)):
    sys.exit(2)
sys.exit(0 if "XF86Back" in [str(v) for v in val] else 1)
'
}

# xf86back_judge_selftest — 反例自检（对齐本仓「判据必须能被反例打红」的口径）：
# 合成样本、纯内存、临时变量，**不碰设备真值**。必须同时证明：
#   正例 `['<Alt>F4', 'XF86Back']` → 0；
#   反例 出厂默认 `['<Alt>F4']` / 空 `@as []` / 子串 `['<Control>XF86BackX']` → 1（=判据会报 MISS）；
#   垃圾输入 `not-a-list` → 2（读不懂不得当成命中）。
xf86back_judge_selftest() {
	local bad=0 s exp got
	while IFS='|' read -r s exp; do
		got=$(printf '%s' "$s" | close_has_xf86back >/dev/null 2>&1; echo $?)
		if [ "$got" != "$exp" ]; then
			printf '  FAIL 判据反例：样本=%s 期望退出码=%s 实得=%s\n' "$s" "$exp" "$got"
			bad=$((bad + 1))
		fi
	done <<'EOSELF'
['<Alt>F4', 'XF86Back']|0
['<Alt>F4']|1
@as []|1
['<Control>XF86BackX']|1
not-a-list|2
EOSELF
	echo "$bad"
}
JUDGE_BAD=$(xf86back_judge_selftest)
if [ "${JUDGE_BAD:-1}" = 0 ]; then
	ok "§15 判据反例自检通过（1 正例 + 4 反例：默认 ['<Alt>F4'] / 空 / 子串 / 垃圾都必须非 0）"
else
	no "§15 判据反例自检失败（$JUDGE_BAD 个样本判错 ⇒ close_has_xf86back 本身坏了，先修脚本）"
fi

# dev_gsettings — 以**会话用户 + 会话总线**查/写 gsettings（root 无会话总线会得到假值，见 §14）
dev_gsettings() {
	"${SSH[@]}" "su -l $DEV_USER -c 'XDG_RUNTIME_DIR=/run/user/$DEV_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$DEV_UID/bus gsettings $1'" 2>/dev/null || true
}
# WM_CLOSE_SH — 设备侧幂等写回件：已有 'XF86Back' 就**零写盘**，否则把默认值里的 `@as` 前缀
# 与方括号剥掉再追加一枚（不改写用户已有的其它绑定）。设备侧 POSIX sh（整文件写入后 `sh` 跑）。
# 写回口径（幂等）：`gsettings set org.gnome.desktop.wm.keybindings close "[<原有项>, 'XF86Back']"`。
WM_CLOSE_SH=$(cat <<'EOS'
#!/bin/sh
# /tmp/elden-wm-close-back.sh — 幂等：把 XF86Back 并入 org.gnome.desktop.wm.keybindings close。
set -eu
KEY=org.gnome.desktop.wm.keybindings
cur=$(gsettings get "$KEY" close)
case "$cur" in
	*"'XF86Back'") echo "already=1 $cur"; exit 0 ;;
esac
inner=$(printf '%s' "$cur" | sed -e 's/^@as //' -e 's/^\[//' -e 's/\]$//')
if [ -z "$inner" ]; then new="['XF86Back']"; else new="[$inner, 'XF86Back']"; fi
gsettings set "$KEY" close "$new"
echo "already=0 $new"
EOS
)
echo "== 15) 「返回」关窗链（§15：wm close 含 XF86Back + lisgd + uinput-back）=="

# ① close 绑定
CLOSE_RAW=$(dev_gsettings 'get org.gnome.desktop.wm.keybindings close')
printf '%s' "$CLOSE_RAW" | close_has_xf86back >/dev/null 2>&1; close_ok=$?
if [ "$close_ok" = 0 ]; then
	ok "wm close 解析后含 XF86Back（现 $CLOSE_RAW）"
elif [ "$MODE" = check ]; then
	no "wm close 解析后不含 XF86Back（现 ${CLOSE_RAW:-查不到}，close_ok=$close_ok）⇒ 返回键关不了窗"
else
	printf '%s\n' "$WM_CLOSE_SH" | "${SSH[@]}" 'cat > /tmp/elden-wm-close-back.sh' &&
		"${SSH[@]}" "su -l $DEV_USER -c 'XDG_RUNTIME_DIR=/run/user/$DEV_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$DEV_UID/bus sh /tmp/elden-wm-close-back.sh'" >/tmp/elden-wm-close-back.log 2>&1 || true
	CLOSE_RAW=$(dev_gsettings 'get org.gnome.desktop.wm.keybindings close')
	printf '%s' "$CLOSE_RAW" | close_has_xf86back >/dev/null 2>&1; close_ok=$?
	if [ "$close_ok" = 0 ]; then
		fix "已把 XF86Back 并入 wm close（现 $CLOSE_RAW；$(tail -1 /tmp/elden-wm-close-back.log 2>/dev/null)）"
	else
		no "并入 XF86Back 后仍不达标（现 ${CLOSE_RAW:-查不到}；主机 /tmp/elden-wm-close-back.log）"
	fi
fi

# ② lisgd（apt；trixie = 0.3.7-1+b1）
LISGD_BIN=$("${SSH[@]}" 'command -v lisgd 2>/dev/null' 2>/dev/null || true)
if [ -n "$LISGD_BIN" ]; then
	ok "lisgd 在位（$LISGD_BIN）"
elif [ "$MODE" = check ]; then
	no "缺 lisgd（滑动返回的事件源；apt 包 lisgd，trixie 0.3.7-1+b1）"
else
	"${SSH[@]}" 'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends lisgd >/tmp/apt-lisgd.log 2>&1' || true
	LISGD_BIN=$("${SSH[@]}" 'command -v lisgd 2>/dev/null' 2>/dev/null || true)
	[ -n "$LISGD_BIN" ] && fix "已装 lisgd（$LISGD_BIN）" || no "装 lisgd 失败（设备 /tmp/apt-lisgd.log）"
fi

# ③ uinput-back（仓内自编件，不是包）
UIBC=$ROOT/out/tools/uinput-back
UIB_BIN=$("${SSH[@]}" 'command -v uinput-back 2>/dev/null' 2>/dev/null || true)
if [ -n "$UIB_BIN" ]; then
	ok "uinput-back 在位（$UIB_BIN）"
elif [ "$MODE" = check ]; then
	no "缺 uinput-back（发 KEY_BACK 的那一半；应由本脚本从 out/tools/uinput-back 装）"
elif [ ! -f "$UIBC" ]; then
	no "缺源件 $UIBC ⇒ 先跑 tools/uinput-back-build.sh 再重跑本脚本（拒绝装占位件）"
else
	"${SCP[@]}" "$UIBC" "$TAB:/usr/local/bin/uinput-back" &&
		"${SSH[@]}" 'chmod 755 /usr/local/bin/uinput-back && command -v uinput-back >/dev/null 2>&1' &&
		fix "已装 /usr/local/bin/uinput-back（源 $UIBC）" || no "装 uinput-back 失败"
fi

# ---------------------------------------------------------------------------
# 16) 「键盘设置」GUI（D18：震动时长/幅度 + 词库引擎切换）—— 2026-11-25 实机验通
# 为什么要有：这两项以前只存在于 README/会话里（改 /etc/environment 手写、gsettings 手敲），
#   用户侧没有入口；而 /etc/environment 是 root 文件，桌面用户改不了 ⇒ 面板 + 幂等 apply 分离。
# 三件判据（缺一即 MISS）：
#   ① 四个文件在位（app / apply / .desktop / conf），且 app 的 sha 与仓内一致（防半装）
#   ② `elden-keyboard-apply --check` rc=0（conf 可解析、能算出要写的键值）
#   ③ 应用 import 得动 GTK4 + Adw（缺 gir1.2-gtk-4.0 / gir1.2-adw-1 时界面起不来，且报错只在 stderr）
KS_DIR=$ROOT/packaging/elden-userland/files
KS_APP_SHA=$(sha256sum "$KS_DIR/usr/local/bin/elden-keyboard-settings" 2>/dev/null | awk '{print $1}')
_ks_bad=$("${SSH[@]}" 'for f in /usr/local/bin/elden-keyboard-settings /usr/local/sbin/elden-keyboard-apply /usr/share/applications/elden-keyboard-settings.desktop /etc/elden-keyboard.conf; do [ -e "$f" ] || echo "MISS $f"; done; command -v python3 >/dev/null || echo "MISS python3"' 2>/dev/null || true)
_ks_sha=$("${SSH[@]}" 'sha256sum /usr/local/bin/elden-keyboard-settings 2>/dev/null | awk "{print \$1}"' 2>/dev/null || true)
_ks_apply=$("${SSH[@]}" 'sh /usr/local/sbin/elden-keyboard-apply --check >/dev/null 2>&1; echo $?' 2>/dev/null || echo 1)
_ks_gi=$("${SSH[@]}" 'python3 -c "import gi;gi.require_version(\"Gtk\",\"4.0\");gi.require_version(\"Adw\",\"1\")" >/dev/null 2>&1; echo $?' 2>/dev/null || echo 1)
if [ -z "$_ks_bad" ] && [ "$_ks_sha" = "$KS_APP_SHA" ] && [ "$_ks_apply" = 0 ] && [ "$_ks_gi" = 0 ]; then
	ok "键盘设置就绪（四件在位 + app sha 一致 + apply --check rc=0 + GTK4/Adw 可导入）"
elif [ "$MODE" = check ]; then
	[ -n "$_ks_bad" ] && no "键盘设置缺件：$_ks_bad"
	[ "$_ks_sha" != "$KS_APP_SHA" ] && no "键盘设置 app 与仓内不一致（设备 ${_ks_sha:-空} / 仓内 ${KS_APP_SHA:-空}）⇒ 重跑本脚本"
	[ "$_ks_apply" != 0 ] && no "elden-keyboard-apply --check 失败（conf 语法或权限）"
	[ "$_ks_gi" != 0 ] && no "缺 GTK4/Adw 的 gir（apt install gir1.2-gtk-4.0 gir1.2-adw-1 python3-gi-cairo）"
else
	"${SSH[@]}" 'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gir1.2-gtk-4.0 gir1.2-adw-1 python3-gi-cairo >/tmp/apt-gtk4.log 2>&1' || true
	"${SCP[@]}" "$KS_DIR/usr/local/bin/elden-keyboard-settings" "$TAB:/usr/local/bin/elden-keyboard-settings" &&
	"${SCP[@]}" "$KS_DIR/usr/local/sbin/elden-keyboard-apply" "$TAB:/usr/local/sbin/elden-keyboard-apply" &&
	"${SCP[@]}" "$KS_DIR/usr/share/applications/elden-keyboard-settings.desktop" "$TAB:/usr/share/applications/elden-keyboard-settings.desktop" &&
	"${SCP[@]}" "$KS_DIR/etc/elden-keyboard.conf" "$TAB:/etc/elden-keyboard.conf" &&
	"${SSH[@]}" 'chmod 755 /usr/local/bin/elden-keyboard-settings /usr/local/sbin/elden-keyboard-apply; chmod 644 /etc/elden-keyboard.conf /usr/share/applications/elden-keyboard-settings.desktop' &&
		fix "已装键盘设置四件（app/apply/.desktop/conf）" || no "装键盘设置失败"
fi


# ---------------------------------------------------------------------------
# 17) 充电链（ICL self-heal）—— 2026-11-26 实机定因（PITFALLS #734）
# 为什么要有：ADSP 对 SDP 默认 `input_current_limit = 100000`（100 mA），而系统负载 ≈0.8 A
#   ⇒ 「插着线净放电 −770 mA」。仓里早有 `charge-watch.sh`（轮询顶回 `current_max`）与
#   `charge-icl-fix.sh`（udev 事件一次性顶回），但并根到 Debian+systemd 后**没有任何 unit /
#   udev 规则接它们**（脚本在、接线丢）⇒ 默认状态就是净放电。本节点把接线补齐并加判据。
# 三件判据（缺一即 MISS）：
#   ① 两脚本在位且与仓内**逐字节相同**（防「半装旧版」：旧版没有洼地保护）
#   ② `charge-watch.service` = enabled + active（脚本存在 ≠ 服务在跑）
#   ③ online 时 `input_current_limit == current_max`（或已按洼地保护降到 floor 且日志有记录）
CW_DEV=/usr/local/sbin/charge-watch.sh
CICL_DEV=/usr/local/sbin/charge-icl-fix.sh
CWRULE=/etc/udev/rules.d/90-elden-charge.rules
CW_SHA=$(sha256sum "$ROOT/scripts/charge-watch.sh" | awk '{print $1}')
CICL_SHA=$(sha256sum "$ROOT/rootfs/debian/usr-local-sbin/charge-icl-fix.sh" | awk '{print $1}')
echo "== 17) 充电链（#734：charge-watch + udev 事件路，缺一即净放电）=="
_cw_sha=$("${SSH[@]}" "sha256sum $CW_DEV 2>/dev/null | awk '{print \$1}'" 2>/dev/null || true)
_cicl_sha=$("${SSH[@]}" "sha256sum $CICL_DEV 2>/dev/null | awk '{print \$1}'" 2>/dev/null || true)
_cw_en=$("${SSH[@]}" 'systemctl is-enabled charge-watch.service 2>/dev/null' 2>/dev/null || true)
_cw_ac=$("${SSH[@]}" 'systemctl is-active charge-watch.service 2>/dev/null' 2>/dev/null || true)
_rule=$("${SSH[@]}" "[ -f $CWRULE ] && echo yes || echo no" 2>/dev/null || true)
_icl=$("${SSH[@]}" 'echo "$(cat /sys/class/power_supply/qcom-battmgr-usb/input_current_limit 2>/dev/null) $(cat /sys/class/power_supply/qcom-battmgr-usb/current_max 2>/dev/null) $(cat /sys/class/power_supply/qcom-battmgr-usb/online 2>/dev/null)"' 2>/dev/null || true)
set -- $_icl; ICL_NOW=${1:-}; ICL_MAX=${2:-}; USB_ONLINE=${3:-}
if [ "$MODE" = check ]; then
	[ "$_cw_sha" = "$CW_SHA" ] && ok "charge-watch.sh 与仓内一致（${CW_SHA%${CW_SHA#???????}}…）" || no "charge-watch.sh 与仓内不一致（设备 ${_cw_sha:-缺} / 仓内 $CW_SHA）⇒ 顶不回 ICL 或没有洼地保护"
	[ "$_cicl_sha" = "$CICL_SHA" ] && ok "charge-icl-fix.sh 与仓内一致" || no "charge-icl-fix.sh 缺或与仓内不一致（udev 事件路）"
	[ "$_rule" = yes ] && ok "$CWRULE 在位" || no "缺 udev 规则 $CWRULE（插拔后 1 s 内不会顶回）"
	if [ "$_cw_en" = enabled ] && [ "$_cw_ac" = active ]; then ok "charge-watch.service enabled+active"
	else no "charge-watch.service 状态 = ${_cw_en:-?}/${_cw_ac:-?}（脚本在但没人跑 = 就是 #734 的现场）"; fi
	if [ "$USB_ONLINE" = 1 ]; then
		if [ -n "$ICL_NOW" ] && [ -n "$ICL_MAX" ] && [ "$ICL_NOW" -ge 500000 ]; then
			ok "ICL=$ICL_NOW（max=$ICL_MAX）⇒ 插着线应净充电（>500 mA 档；100 mA 档必净放电）"
		else no "online 但 ICL=${ICL_NOW:-?} < 500000 ⇒ 净放电（见 reports/usb-charging-dualport-20261126.md）"; fi
	else ok "USB 未接（online=$USB_ONLINE），不判 ICL"; fi
else
	need_restart=0
	if [ "$_cw_sha" != "$CW_SHA" ]; then
		"${SCP[@]}" "$ROOT/scripts/charge-watch.sh" "$TAB:$CW_DEV" && \
			"${SSH[@]}" "chmod 755 $CW_DEV" && { fix "已更新 charge-watch.sh"; need_restart=1; } || no "更新 charge-watch.sh 失败"
	fi
	if [ "$_cicl_sha" != "$CICL_SHA" ]; then
		"${SCP[@]}" "$ROOT/rootfs/debian/usr-local-sbin/charge-icl-fix.sh" "$TAB:$CICL_DEV" && \
			"${SSH[@]}" "chmod 755 $CICL_DEV" && fix "已更新 charge-icl-fix.sh" || no "更新 charge-icl-fix.sh 失败"
	fi
	if [ "$_rule" != yes ]; then
		"${SSH[@]}" 'mkdir -p /etc/udev/rules.d' &&
			"${SCP[@]}" "$ROOT/rootfs/debian/udev/90-elden-charge.rules" "$TAB:$CWRULE" &&
			"${SSH[@]}" 'udevadm control --reload-rules >/dev/null 2>&1 || true' &&
			fix "已装 udev 规则 $CWRULE（源 rootfs/debian/udev/）并 reload" || no "装 udev 规则失败"
	fi
	"${SSH[@]}" 'install -m 644 /dev/stdin /etc/systemd/system/charge-watch.service' <"$ROOT/packaging/elden-userland/out/units/systemd/charge-watch.service" &&
		"${SSH[@]}" 'systemctl daemon-reload; systemctl enable charge-watch.service >/dev/null 2>&1; systemctl restart charge-watch.service' &&
		fix "charge-watch.service 已装/启用/重启（含洼地保护版）" || no "装/启用 charge-watch.service 失败"
	[ "$need_restart" = 0 ] || fix "（脚本已更新，服务已随上面 restart 生效）"
	sleep 3
	_icl=$("${SSH[@]}" 'echo "$(cat /sys/class/power_supply/qcom-battmgr-usb/input_current_limit 2>/dev/null) $(cat /sys/class/power_supply/qcom-battmgr-usb/current_max 2>/dev/null) $(cat /sys/class/power_supply/qcom-battmgr-usb/online 2>/dev/null)"' 2>/dev/null || true)
	set -- $_icl; ICL_NOW=${1:-}; ICL_MAX=${2:-}; USB_ONLINE=${3:-}
	if [ "$USB_ONLINE" = 1 ] && [ -n "$ICL_NOW" ] && [ "$ICL_NOW" -ge 500000 ]; then
		ok "ICL 已顶到 $ICL_NOW（max=$ICL_MAX）"
	else
		[ "$USB_ONLINE" = 1 ] && no "online 但 ICL 仍 ${ICL_NOW:-?}（查 /run/charge-watch.log）" || ok "USB 未接（online=$USB_ONLINE），不判 ICL"
	fi
fi

echo
if [ "$missing" -eq 0 ]; then echo "结果: 达标（MISS=0）"; exit 0; fi
echo "结果: 未达标（MISS=$missing）"; exit 1
