#!/bin/bash
# zero-to-desktop-check.sh — 「起机 → 桌面」这一段（RUNBOOK S5–S12）的一条命令自检
#
# 为什么有这个脚本（2026-11-19）：`RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md` 的 S5–S12 各自都有判据，
# 但**散在手册里**：设备回来时要么逐条手抄命令，要么凭记忆跳步。已有一个
# `scripts/deploy-desktop-shell.sh --check`，但它只管 S11（桌面壳）本身——udev/路由/时钟/扩容/
# 基线/GPU 六步的判断仍在人脑里。本脚本把它们收成一条命令，输出「每步 ok/MISS + 一行原因」。
#
# 分工：
#   · 判据的**定义**仍以手册为准（本脚本每步注释里写明对应 S 步与坑号），改判据要同时改手册；
#   · 真大型收敛动作（装包/写配置）不在这里，仍由 `scripts/deploy-desktop-shell.sh`、
#     `scripts/mobian-daily-baseline.sh` 负责——本脚本**只读**，不改设备任何状态。
#
# 用法：
#   scripts/zero-to-desktop-check.sh            # 连设备跑全部步（只读）
#   scripts/zero-to-desktop-check.sh --dry-run  # 不连设备，只打印每步要跑的命令（主机侧可验）
#   scripts/zero-to-desktop-check.sh --list     # 列出步号/标题（机器可读，供 §22 门消费）
#   TAB=root@192.168.7.1 scripts/zero-to-desktop-check.sh
#
# 退出码：0 = 全 ok；1 = 有 MISS；3 = 设备不可达；2 = 用法错。
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
TAB=${TAB:-root@192.168.7.1}
T=${T:-8}
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout="$T" -o ConnectionAttempts=1 -o BatchMode=yes -b 0 "$TAB")
MODE=run
case "${1:-}" in
	--dry-run) MODE=dry ;;
	--list)    MODE=list ;;
	-h|--help) sed -n '2,26p' "$0"; exit 0 ;;
	"") ;;
	*) echo "未知参数 ${1:-}" >&2; exit 2 ;;
esac

miss=0
ok()   { printf '  ok    %s\n' "$*"; }
no()   { printf '  MISS  %s\n' "$*"; miss=$((miss + 1)); }
info() { printf '  --    %s\n' "$*"; }

# 每步 = 「步号|标题|S 步|坑号|远程命令|判据说明」。远程命令里禁止写操作。
#
# 说明为什么判据长这样（都是踩过的静默失败）：
#   S5  `ps -p1 -o comm=` 不是 systemd ⇒ 根里 /init 没跑到（#680）
#   S6  udevd 不 active ⇒ 模块零自动加载（#681）；要有 card0/fb0 才算显示链真起来
#   S7  设备侧默认网关是 usb0-host-route 自愈服务补的（#685）
#   S8  RTC 只读 ⇒ 只能比「与主机时间差」，不能比绝对日期（#684）
#   S9  6 GiB minbase 默认没扩容，df 会是 5.8G
#   S10 日用基线 49 包，MISS 由 mobian-daily-baseline.sh 报（不在本脚本重复判）
#   S11 桌面壳整段交给 deploy-desktop-shell.sh --check（单一判据源）
#   S12 renderD128 打开数 = GL 路径；0 表示 pixman 软合成（#683）
STEPS=(
"S5|起机（systemd 是 pid1，ssh 通）|S5|#680|ps -p1 -o comm="
"S6|显示（udevd active + card0/fb0 + DPU 聚合 bound）|S6|#681|systemctl is-active systemd-udevd; ls /dev/dri/card0 /dev/fb0 2>/dev/null | wc -l; grep -qs 'aggregate not bound' /sys/kernel/debug/device_component/*display-controller && echo NOTBOUND || echo BOUND"
"S7|网络（默认路由 + HTTPS 200）|S7|#685|ip route show default | head -1; timeout 15 curl -s -o /dev/null -w '%{http_code}' http://deb.debian.org/debian/"
"S8|时钟（与主机差 < 1 天）|S8|#684|date -u +%s"
"S9|根扩容（df / ≥ 100 GiB）|S9|—|df -BG --output=size / | tail -1 | tr -dc 0-9"
"S10|日用基线（49 包 MISS=0，委托 daily-baseline）|S10|—|@host:bash scripts/mobian-daily-baseline.sh --check"
"S11|桌面壳（greetd+三进程+截图，委托 deploy-desktop-shell）|S11|#682|@host:bash scripts/deploy-desktop-shell.sh --check"
"S12|GPU（phoc 打开 renderD128）|S12|#683|ls -l /proc/\$(pidof phoc)/fd 2>/dev/null | grep -c renderD128"
)

if [ "$MODE" = list ]; then
	for s in "${STEPS[@]}"; do IFS='|' read -r id title svc pit cmd <<<"$s"; printf '%s\t%s\t%s\n' "$id" "$title" "$pit"; done
	exit 0
fi

if [ "$MODE" = dry ]; then
	printf '== zero-to-desktop-check（--dry-run，不连设备）==\n'
	printf '  目标: %s\n' "$TAB"
	for s in "${STEPS[@]}"; do
		IFS='|' read -r id title svc pit cmd <<<"$s"
		case "$cmd" in
			@host:*) printf '  %-3s %-46s [主机] %s\n' "$id" "$title" "${cmd#@host:}" ;;
			*)       printf '  %-3s %-46s [设备] %s\n' "$id" "$title" "$cmd" ;;
		esac
	done
	printf '\n  %d 步；真跑请去掉 --dry-run（只读，不改设备）\n' "${#STEPS[@]}"
	exit 0
fi

echo "== 0) 设备可达性 =="
if ! out=$("${SSH[@]}" 'uname -r; . /etc/os-release; echo "$PRETTY_NAME"' 2>&1); then
	echo "  设备不可达（$TAB）：$out" >&2
	exit 3
fi
info "$(printf '%s' "$out" | paste -sd' ' -)"

for s in "${STEPS[@]}"; do
	IFS='|' read -r id title svc pit cmd <<<"$s"
	echo "== $id) $title（手册 $svc${pit:+，坑 $pit}）=="
	case "$cmd" in
		@host:*)
			# 委托已有主机侧驱动脚本：它们的尾行契约就是 MISS=n / 退出码 0。
			script=${cmd#@host:}
			if hout=$(cd "$ROOT" && timeout 300 bash -c "$script" 2>&1); then
				ok "$(printf '%s' "$hout" | tail -1)"
			else
				no "$(printf '%s' "$hout" | tail -1)（$script）"
			fi
			continue ;;
	esac
	r=$("${SSH[@]}" "$cmd" 2>/dev/null)
	case "$id" in
		S5) [ "$r" = systemd ] && ok "pid1=systemd" || no "pid1=${r:-空}（根里 /init 没跑到？#680）" ;;
		S6) act=$(printf '%s\n' "$r" | sed -n 1p)
		    n=$(printf '%s\n' "$r" | sed -n 2p)
		    dpu=$(printf '%s\n' "$r" | sed -n 3p)
		    [ "$act" = active ] && ok "systemd-udevd active" || no "systemd-udevd=$act（#681）"
		    [ "${n:-0}" -ge 2 ] 2>/dev/null && ok "card0+fb0 在" || no "card0/fb0 缺（$n/2）"
		    [ "$dpu" = BOUND ] && ok "DPU 聚合 bound" || no "DPU 聚合=$dpu" ;;
		S7) rt=$(printf '%s\n' "$r" | sed -n 1p); code=$(printf '%s\n' "$r" | sed -n 2p)
		    [ -n "$rt" ] && ok "默认路由: $rt" || no "无默认路由（usb0-host-route 在跑吗，#685）"
		    [ "$code" = 200 ] && ok "http 200" || no "http=$code（DNS/NAT 逐层查）" ;;
		S8) now=$(date -u +%s); d=$(( r > now ? r - now : now - r ))
		    [ "$d" -lt 86400 ] 2>/dev/null && ok "设备时间差 ${d}s" || no "设备时间差 ${d}s（time-sync 没跑成？#684）" ;;
		S9) [ "${r:-0}" -ge 100 ] 2>/dev/null && ok "根 ${r} GiB" || no "根 ${r} GiB（未扩容，S9 一条 resize2fs）" ;;
		S12) [ "${r:-0}" -ge 1 ] 2>/dev/null && ok "renderD128 打开 ${r} 次（GL）" || no "renderD128=0（pixman 软合成，或会话未起；#683）" ;;
		*) info "未实现判据（$id）" ;;
	esac
done

echo
if [ "$miss" -eq 0 ]; then echo "结果: 全 ok（S5–S12）"; exit 0; fi
echo "结果: MISS=$miss（逐条按手册对应 S 步处理）"; exit 1
