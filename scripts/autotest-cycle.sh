#!/bin/bash
# autotest-cycle.sh — 「BL → 零写盘上机 → 跑测试 → 回 BL」的自主循环驱动（可无人值守连跑）
#
# 为什么（2026-11-25，用户出门前要求）：设备实验原先每轮都要人肉在 BL 交设备，
#   而两条腿其实都已成熟：
#     · Linux → BL：`systemctl reboot --reboot-argument=bootloader`（PITFALLS #722；实测 ~19 s）
#       封装 = 设备侧 `elden-to-bootloader` + 主机侧 `scripts/to-bootloader.sh`
#     · BL → Linux：`fastboot boot <img>`（零写盘，不碰任何槽；实测 ~21 s 到 SSH）
#   ⇒ 本脚本把它们串成一个可连跑的闭环，测试件只用 `fastboot boot` 投放，
#   **任何失败都不会污染 boot_b**：RAM 核 panic（cmdline 有 panic=15）会复位回 boot_b。
#
# 用法：
#   scripts/autotest-cycle.sh --image out/xxx.img [--test FILE] [--rounds N]
#   scripts/autotest-cycle.sh --image IMG --test probes/x.sh --rounds 3 --label m12-ab
#   scripts/autotest-cycle.sh --state          # 只报设备现在在哪（fastboot/linux/无）
#   scripts/autotest-cycle.sh --image IMG --stay-linux   # 跑完留在 Linux（便于人工接手）
#
# 参数：
#   --image IMG        必填。测试件（boot.img）；cmdline 必须 `elden_root=LABEL=<现盘标签>`
#                      （本机现盘标签 = `linux`；旧件写 `LABEL=linux17` 会挂不上根 ⇒ 脚本预检拦）
#   --test FILE        设备侧 POSIX sh 脚本，scp 到 /tmp 再 `sh`；不给则跑内置探针
#   --rounds N         轮数（默认 1）
#   --test-timeout S   单轮测试超时（默认 300）
#   --boot-timeout S   等 SSH 回来的预算（默认 120）
#   --settle S         SSH 到手后等系统就绪的预算（默认 90；判据 = systemd is-system-running）
#   --settle-min S     最短就绪等待（默认 45；early sshd 在 29 s 就答，但 DSI/WLAN 那时还没起）
#   --label L          日志目录名后缀（默认 image 名）
#   --stay-linux       每轮结束不回 BL（最后一轮留在 Linux）
#
# 退出码：0 全部轮次通过；10 = 某轮测试 rc≠0；11 = 某轮上机后 SSH 没回来（已自动判定
#         "回落 BL" 或 "无任何通道"）；12 = 起始状态不可用（既不在 BL 也不在 Linux）。
#
# 纪律（全局规则 3/14/17）：所有外部命令套 timeout -k；设备写动作走 device-lock 串行；
#   fastboot 一律显式 -s $SER（PITFALLS #371：裸命令会把别的手机当本机）。
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}
SER=${SER:-HA2EXB0E}
TAB=${TAB:-root@192.168.7.1}
FB=${FB:-$(command -v fastboot || echo "$HOME/.local/opt/platform-tools/fastboot")}

IMAGE=""; TESTF=""; ROUNDS=1; TEST_TMO=300; BOOT_TMO=120; SETTLE=90; LABEL=""; STAY=0; STATE_ONLY=0
while [ $# -gt 0 ]; do
	case "$1" in
		--image) IMAGE=${2:?--image 需要路径}; shift ;;
		--test) TESTF=${2:?--test 需要路径}; shift ;;
		--rounds) ROUNDS=${2:?}; shift ;;
		--test-timeout) TEST_TMO=${2:?}; shift ;;
		--boot-timeout) BOOT_TMO=${2:?}; shift ;;
		--settle) SETTLE=${2:?}; shift ;;
		--settle-min) SETTLE_MIN=${2:?}; shift ;;
		--label) LABEL=${2:?}; shift ;;
		--stay-linux) STAY=1 ;;
		--state) STATE_ONLY=1 ;;
		-h|--help) sed -n '2,40p' "$0"; exit 0 ;;
		*) echo "未知参数 $1（--help）" >&2; exit 2 ;;
	esac
	shift
done

SSH_OPTS=(ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o ConnectTimeout=5 -o LogLevel=ERROR "$TAB")
say() { printf '[autotest] %s\n' "$*" >&2; }
dev_run() { timeout -k 5 "${2:-60}" "${SSH_OPTS[@]}" "$1"; }

# ---- 状态判定（先判后动，不猜）----
fb_sn() { local d; d=$(timeout -k 2 8 "$FB" devices 2>/dev/null) || true; case "$d" in *"$SER"*) return 0 ;; *) return 1 ;; esac; }
linux_up() { [ "$(dev_run 'echo up' 12 2>/dev/null)" = up ]; }

state() {
	if fb_sn; then echo fastboot; elif linux_up; then echo linux; else echo none; fi
}

if [ "$STATE_ONLY" = 1 ]; then
	st=$(state); echo "state=$st"
	[ "$st" = linux ] && dev_run 'uname -r; uname -v; uptime -p' 20
	exit 0
fi

[ -n "$IMAGE" ] || { echo "--image 必填（--help）" >&2; exit 2; }
[ -f "$IMAGE" ] || { echo "找不到镜像 $IMAGE" >&2; exit 2; }

# ---- 镜像预检：根标签必须与现盘一致（不然上机必然挂不住根，浪费一轮）----
CMDLINE=$(timeout -k 5 90 python3 "$ROOT/scripts/boot-img-cmdline.py" "$IMAGE" 2>/dev/null \
	| awk -F': ' '/^cmdline/{print $2}')
case "$CMDLINE" in
	*elden_root=*) : ;;
	*) say "⚠ 镜像无 elden_root=（RAM-only 救援件？）；继续但测试脚本要能自理根";;
esac
ROOTLBL=$(printf '%s' "$CMDLINE" | tr ' ' '\n' | sed -n 's/^elden_root=LABEL=//p')
if [ -n "$ROOTLBL" ] && [ "$ROOTLBL" != "${EXPECT_ROOT_LABEL:-linux}" ]; then
	say "❌ 镜像根标签 LABEL=$ROOTLBL ≠ 现盘标签 ${EXPECT_ROOT_LABEL:-linux} ⇒ 会挂不上根（本机 2026-11-19 起盘标签是 linux）"
	exit 2
fi

IMG_SHA=$(timeout -k 5 120 sha256sum "$IMAGE" | cut -d' ' -f1)
TS=$(date -u +%Y%m%dT%H%M%SZ)
LOGD=${LOGD:-$ROOT/runs/autotest-$TS-${LABEL:-$(basename "$IMAGE" .img)}}
mkdir -p "$LOGD"

. "$ROOT/scripts/lib-device-lock.sh"
device_lock_acquire

echo "== autotest @ $TS ==" > "$LOGD/index.txt"
{
	echo "image    : $IMAGE"
	echo "img_sha  : $IMG_SHA"
	echo "cmdline  : $CMDLINE"
	echo "rounds   : $ROUNDS"
	echo "test     : ${TESTF:-<内置探针>}"
	echo "logdir   : $LOGD"
} | tee -a "$LOGD/index.txt"

# ---- 起点：必须能在 BL 或 Linux 上接住 ----
st=$(state)
say "起始状态: $st"
case "$st" in
	none) say "❌ 既不在 fastboot 也不在 Linux ⇒ 需人工上电/插线（不猜内核）"; exit 12 ;;
esac

# ---- 内置探针（不给 --test 时用）----
probe_builtin() {
	dev_run 'set -u
echo "UTS=$(uname -r)"
echo "BUILD=$(uname -v)"
echo "UPTIME=$(uptime -p)"
echo "ROOT=$(findmnt -no SOURCE,FSTYPE / | tr " " ":")"
echo "MODULES=$(ls /lib/modules | tr "\n" ",")"
echo "DSI=$(cat /sys/class/drm/card0-DSI-1/status 2>/dev/null)"
echo "WLAN=$(cat /sys/class/net/wlp1s0/operstate 2>/dev/null)"
echo "FASTRPC=$(ls /dev/fastrpc-* 2>/dev/null | tr "\n" " ")"
echo "FAILED_UNITS=$(systemctl --failed --no-legend 2>/dev/null | wc -l)"
echo "DMESG_WARN=$(dmesg | grep -ciE "call trace|BUG:|Oops")"
' "$TEST_TMO"
}

FAIL=0
for r in $(seq 1 "$ROUNDS"); do
	say "—— 第 $r/$ROUNDS 轮 ——"
	# 1) 若在 Linux 先回 BL（每轮都从 BL 起，保证同一投放路径）
	if [ "$(state)" = linux ]; then
		to_bl=$(timeout -k 5 $((BOOT_TMO + 60)) "$ROOT/scripts/to-bootloader.sh" 2>&1)
		if ! printf '%s' "$to_bl" | grep -q 'fastboot 上线'; then
			printf '%s\n' "$to_bl" | tee -a "$LOGD/index.txt"
			say "❌ Linux → BL 失败 ⇒ 收工（需人工）"; FAIL=11; break
		fi
	fi
	if ! fb_sn; then say "❌ 到不了 fastboot" | tee -a "$LOGD/index.txt"; FAIL=11; break; fi

	# 2) 零写盘投放
	t0=$(date +%s)
	timeout -k 5 180 "$FB" -s "$SER" boot "$IMAGE" >"$LOGD/round$r-fastboot.txt" 2>&1
	if ! grep -q '^Booting' "$LOGD/round$r-fastboot.txt"; then
		say "❌ fastboot boot 未执行（见 round$r-fastboot.txt）"; FAIL=11; break
	fi

	# 3) 等 SSH 回来（判据 = ssh 可达；从 BL 起没有"旧系统在答"的问题）
	up=0; waited=0
	while [ "$waited" -lt "$BOOT_TMO" ]; do
		if linux_up; then up=1; break; fi
		sleep 3; waited=$((waited + 3))
	done
	t_ssh=$(( $(date +%s) - t0 ))
	if [ "$up" = 0 ]; then
		# 判 "回落 BL"（内核 panic 后 ABL 起 boot_b 之外的路径）还是 "全无通道"
		if fb_sn; then
			say "❌ 第 $r 轮：${BOOT_TMO}s 未回 SSH，但设备已在 fastboot ⇒ 本轮判"投放核起不来/回落 BL""
			echo "round=$r result=NO_SSH_FELL_BACK_TO_BL wait=${waited}s" >> "$LOGD/index.txt"
			FAIL=11; break
		fi
		say "❌ 第 $r 轮：无 SSH 也无 fastboot ⇒ 可能真挂死，需人工（boot_b 未被改动，安全）"
		echo "round=$r result=NO_CHANNEL wait=${waited}s" >> "$LOGD/index.txt"
		FAIL=11; break
	fi

	# 3b) 等系统就绪（SSH 由 early sshd 提供，此时 DSI/WLAN/单元都还没起）
	st_waited=0; run_state=""
	while [ "$st_waited" -lt "$SETTLE" ]; do
		run_state=$(dev_run 'systemctl is-system-running 2>/dev/null' 15 2>/dev/null)
		case "$run_state" in
			running|degraded) [ "$st_waited" -ge "${SETTLE_MIN:-45}" ] && break ;;
		esac
		sleep 3; st_waited=$((st_waited + 3))
	done
	say "就绪等待 ${st_waited}s（systemd=${run_state:-未知}）"
	echo "round=$r settle=${st_waited}s systemd=${run_state:-unknown}" >> "$LOGD/index.txt"

	# 4) 跑测试
	if [ -n "$TESTF" ]; then
		timeout -k 5 30 scp -q -o BatchMode=yes -o StrictHostKeyChecking=no \
			-o UserKnownHostsFile=/dev/null "$TESTF" "$TAB:/tmp/autotest-round.sh" || true
		dev_run 'sh /tmp/autotest-round.sh' "$TEST_TMO" >"$LOGD/round$r-test.txt" 2>&1
		trc=$?
		say "第 $r 轮测试 rc=$trc（日志 round$r-test.txt）"
	else
		probe_builtin >"$LOGD/round$r-probe.txt" 2>&1
		trc=$?
		say "第 $r 轮内置探针 rc=$trc（$(grep -m1 '^UTS=' "$LOGD/round$r-probe.txt" 2>/dev/null)）"
	fi
	echo "round=$r result=TEST t_ssh=${t_ssh}s rc=$trc" >> "$LOGD/index.txt"

	# 5) 回 BL（下一轮起点；--stay-linux 或最后一轮时按需保留）
	if [ "$STAY" = 1 ] && [ "$r" = "$ROUNDS" ]; then
		say "按 --stay-linux 留在 Linux（UTS=$(dev_run 'uname -r' 15)）"
	else
		to_bl=$(timeout -k 5 $((BOOT_TMO + 60)) "$ROOT/scripts/to-bootloader.sh" 2>&1)
		if printf '%s' "$to_bl" | grep -q 'fastboot 上线'; then
			say "第 $r 轮已回 BL"
		else
			printf '%s\n' "$to_bl" | tee -a "$LOGD/index.txt"
			say "❌ 第 $r 轮回 BL 失败"; FAIL=11; break
		fi
	fi
	[ "$trc" -ne 0 ] && FAIL=10
done

say "日志目录：$LOGD"
say "结束（rc=$FAIL）"
exit "$FAIL"
