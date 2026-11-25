#!/bin/bash
# deploy-ssc-sensors.sh — 在 Y700 (TB322FC, Debian trixie) 上部署 SSC 传感器用户态栈
# （libssc2 + libssc-bin + iio-sensor-proxy 3.9 ssc 版 + 81-libssc-elden.rules），让
# net.hadess.SensorProxy HasAccelerometer=true。
#
# 背景：reports/sensor-claim-verify-20261126.md（缺口全在用户态）+
#       reports/sensor-libssc-prep-20261126.md（路线 A = Debian testing/unstable 官方包直装）。
# 关键坑：iio-sensor-proxy 3.9 官方 udev 规则仍只打 ssc-light/ssc-compass，
#         没有 ssc-accel ⇒ 必须补仓内 81-libssc-elden.rules（PITFALLS #451）。
#
# 用法：
#   TARGET=root@192.168.7.1 bash scripts/deploy-ssc-sensors.sh --check
#   TARGET=root@192.168.7.1 bash scripts/deploy-ssc-sensors.sh --from-debian        # Debian pool 官方包
#   TARGET=root@192.168.7.1 PKG_DIR=/tmp/ssc-prep/out bash scripts/deploy-ssc-sensors.sh --pkg-dir "$PKG_DIR"
#   ... --dry-run        # 只打印将执行的命令
#   ... --rollback [--orig-pkg-dir DIR]   # 回滚：unhold + 删 pin + 装回原包
#
# ⛔ 硬禁令（#692 硬崩风险，PITFALLS/README.md #325）：
#    本脚本绝不 enable/start/mask/unmask 任何 hexagonrpcd* unit，不动内核/DTB/模块。
#    libssc 走 AF_QIPCRTR socket，不需要 hexagonrpcd。执行前只对 hexagonrpcd 的
#    enabled 状态做只读 warn，不擅自修改。
#
# 回退说明（设备上手工执行）：
#   1) rm /etc/udev/rules.d/81-libssc-elden.rules
#      udevadm control --reload-rules && udevadm trigger --subsystem-match=misc
#      systemctl restart iio-sensor-proxy      ⇒ 立即回到无 accel 状态
#   2) 或整包回滚：bash scripts/deploy-ssc-sensors.sh --rollback [--orig-pkg-dir DIR]
#      （等价于：apt-mark unhold iio-sensor-proxy libssc2 libssc-bin;
#        rm /etc/apt/preferences.d/elden-iio-sensor-proxy.pref;
#        dpkg -i <原 iio-sensor-proxy 3.7-3 包>；libssc2/libssc-bin 可 dpkg -r 留给用户决定）
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET=${TARGET:-root@192.168.7.1}
SSH_OPTS=${SSH_OPTS:--o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR}
RULE_SRC=$ROOT/packaging/elden-userland/files/etc/udev/rules.d/81-libssc-elden.rules
PIN_FILE=/etc/apt/preferences.d/elden-iio-sensor-proxy.pref
MODE="exec"
FROM_DEBIAN=0
PKG_DIR=${PKG_DIR:-}
ORIG_PKG_DIR=${ORIG_PKG_DIR:-}

# Debian pool 官方包（testing/forky；sha256 见 reports/sensor-libssc-prep-20261126.md §3.4）
DEBIAN_POOL=http://deb.debian.org/debian/pool/main
DEB_IIO=iio-sensor-proxy_3.9-1_arm64.deb
DEB_LIBSSC2=libssc2_0.4.4-2.1_arm64.deb
DEB_LIBSSCBIN=libssc-bin_0.4.4-2.1_arm64.deb
SHA_IIO=a72d111ca58c22dd7f2b71ed20001425fc180a5581df8c07c0420aaaeba61415
SHA_LIBSSC2=a05d3fb33323183b847e9264f57485b278fbc42f9854119edfdcd20db1b589d0
SHA_LIBSSCBIN=b1c2b9c0a3232f2b79b0fb7fbf517283c5c36d5662bb95974752ea4b82f592a8

say() { printf '[ssc-deploy] %s\n' "$*"; }
die() { say "FATAL: $*"; exit 1; }
usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [ $# -gt 0 ]; do
	case $1 in
	--check) MODE=check ;;
	--dry-run) MODE=dryrun ;;
	--rollback) MODE=rollback ;;
	--from-debian) FROM_DEBIAN=1 ;;
	--pkg-dir) PKG_DIR=${2:?}; shift ;;
	--orig-pkg-dir) ORIG_PKG_DIR=${2:?}; shift ;;
	--help|-h) usage ;;
	*) die "未知参数 $1（--help 看用法）" ;;
	esac
	shift
done

# rsh：所有设备侧命令套 timeout -k（全局硬规则 3），失败不静默
rsh() { timeout -k 5 "${STMO:-120}" ssh $SSH_OPTS "$TARGET" "$@"; }
# dry-run 下 exec 用 rd 代替 rsh：打印不执行
DRY=0; [ "$MODE" = dryrun ] && DRY=1
rd() {
	if [ "$DRY" = 1 ]; then say "[dry-run] ssh $TARGET: $*"; return 0; fi
	rsh "$@"
}

[ -f "$RULE_SRC" ] || die "仓内规则缺失：$RULE_SRC"

case $MODE in

# ---------------------------------------------------------------- --check（只读）
check)
	FAIL=0
	row() { # row <PASS|FAIL> <名称> <细节>
		printf '%-5s %-34s %s\n' "$1" "$2" "$3"
		[ "$1" = FAIL ] && FAIL=1
		return 0
	}
	say "== 只读体检矩阵 TARGET=$TARGET =="
	printf '%-5s %-34s %s\n' RESULT ITEM DETAIL

	# hexagonrpcd 状态（只读；masked = 安全态）
	# 注意：`systemctl is-enabled` 对 masked 单元返回 rc=1（≠ disabled 的 rc=1 也用同值），
	# 所以只能判字串，不能判 rc（2026-11-26 实测：旧版判 rc ⇒ masked 反被判 FAIL）。
	hstate=$(rsh 'systemctl is-enabled hexagonrpcd 2>&1')
	if [ "$hstate" = masked ]; then row PASS hexagonrpcd masked
	else row FAIL hexagonrpcd "state=$hstate（非 masked，有 #692 崩溃面，勿 start）"; fi

	# 三个包版本
	for p in iio-sensor-proxy libssc2 libssc-bin; do
		v=$(rsh "dpkg-query -W -f='\${Version}' $p 2>/dev/null")
		if [ -n "$v" ]; then row PASS "pkg:$p" "$v"; else row FAIL "pkg:$p" 未安装; fi
	done

	# libssc so 是否在 ldconfig
	ldc=$(rsh 'ldconfig -p 2>/dev/null | grep -c libssc.so.2')
	if [ "${ldc:-0}" -ge 1 ]; then row PASS libssc.so.2 "ldconfig 命中 $ldc"; else row FAIL libssc.so.2 未注册; fi

	# qrtr svc 400
	q4=$(rsh 'qrtr-lookup 2>/dev/null | grep -cE "^ *400 "')
	if [ "${q4:-0}" -ge 1 ]; then row PASS qrtr-svc-400 在册; else row FAIL qrtr-svc-400 缺失; fi

	# udev 规则在位 + 属性
	ur=$(rsh 'test -f /etc/udev/rules.d/81-libssc-elden.rules && echo yes')
	if [ "$ur" = yes ]; then row PASS udev-81-libssc-elden.rules 在位; else row FAIL udev-81-libssc-elden.rules 缺失; fi
	up=$(rsh 'udevadm info -q property /dev/fastrpc-adsp 2>/dev/null | grep -c IIO_SENSOR_PROXY_TYPE')
	if [ "${up:-0}" -ge 1 ]; then row PASS udev-IIO_SENSOR_PROXY_TYPE 已打; else row FAIL udev-IIO_SENSOR_PROXY_TYPE 缺; fi
	um=$(rsh 'udevadm info -q property /dev/fastrpc-adsp 2>/dev/null | grep -c ACCEL_MOUNT_MATRIX')
	if [ "${um:-0}" -ge 1 ]; then row PASS udev-ACCEL_MOUNT_MATRIX 已打; else row FAIL udev-ACCEL_MOUNT_MATRIX 缺; fi

	# D-Bus 三轴
	ha=$(rsh 'timeout -k 3 15 busctl get-property --system net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer 2>/dev/null')
	hl=$(rsh 'timeout -k 3 15 busctl get-property --system net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAmbientLight 2>/dev/null')
	hp=$(rsh 'timeout -k 3 15 busctl get-property --system net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasProximity 2>/dev/null')
	ha=${ha:-absent}; hl=${hl:-absent}; hp=${hp:-absent}
	case $ha in *true*) row PASS HasAccelerometer "$ha" ;; *) row FAIL HasAccelerometer "$ha" ;; esac
	case $hl in *true*) row PASS HasAmbientLight "$hl" ;; *) row FAIL HasAmbientLight "$hl" ;; esac
	case $hp in *true*) row PASS HasProximity "$hp" ;; *) row FAIL HasProximity "$hp" ;; esac

	# pin/hold 防回滚
	pf=$(rsh "test -f $PIN_FILE && echo yes")
	if [ "$pf" = yes ]; then row PASS apt-pin 在位; else row FAIL apt-pin "$PIN_FILE 缺（apt upgrade 会回滚到 3.7-3）"; fi
	hd=$(rsh 'apt-mark showhold 2>/dev/null | grep -cE "iio-sensor-proxy|libssc"')
	if [ "${hd:-0}" -ge 3 ]; then row PASS apt-hold "hold 数=$hd"; else row FAIL apt-hold "hold 数=${hd:-0}（需 3）"; fi

	say "== 结果：$([ $FAIL -eq 0 ] && echo ALL-PASS || echo HAS-FAIL) =="
	exit $FAIL
	;;

# ---------------------------------------------------------------- --rollback
rollback)
	say "回滚：unhold + 删 pin + 装回原包"
	ORIG=""
	if [ -n "$ORIG_PKG_DIR" ]; then
		[ -d "$ORIG_PKG_DIR" ] || die "--orig-pkg-dir $ORIG_PKG_DIR 不是目录"
		ORIG=$(ls "$ORIG_PKG_DIR"/iio-sensor-proxy_*_arm64.deb 2>/dev/null | head -1)
		[ -n "$ORIG" ] || die "$ORIG_PKG_DIR 里没有 iio-sensor-proxy_*_arm64.deb"
		say "原包：$ORIG"
		# shellcheck disable=SC2086
		timeout -k 5 60 scp $SSH_OPTS "$ORIG" "$TARGET:/tmp/iio-orig.deb" || die "scp 原包失败"
	fi
	rd 'apt-mark unhold iio-sensor-proxy libssc2 libssc-bin 2>/dev/null; echo unheld'
	rd "rm -f $PIN_FILE && echo pin-removed"
	if [ -n "$ORIG" ]; then
		rd 'dpkg -i /tmp/iio-orig.deb && rm -f /tmp/iio-orig.deb' || die "装回原包失败"
		rd 'systemctl restart iio-sensor-proxy'
		say "已装回原包。libssc2/libssc-bin 仍保留（dpkg -r libssc-bin libssc2 可删，用户决定）"
	else
		say "未给 --orig-pkg-dir ⇒ 请手工装回 iio-sensor-proxy=3.7-3（apt install iio-sensor-proxy=3.7-3）"
	fi
	rd 'rm -f /etc/udev/rules.d/81-libssc-elden.rules; udevadm control --reload-rules && udevadm trigger --subsystem-match=misc && systemctl restart iio-sensor-proxy && echo ROLLBACK-OK'
	;;

# ---------------------------------------------------------------- 默认执行 / --dry-run
exec|dryrun)
	say "TARGET=$TARGET MODE=$MODE"
	# ⛔ 硬禁令自证：只读检查 hexagonrpcd，不动它
	hstate=$(rsh 'systemctl is-enabled hexagonrpcd 2>&1')
	if [ "$hstate" = masked ]; then
		say "hexagonrpcd=masked（安全态，保持不动；本脚本全程不碰 hexagonrpcd*）"
	elif [ "$DRY" = 1 ]; then
		say "[dry-run] hexagonrpcd state=$hstate（真实执行时会 warn）"
	else
		say "WARN: hexagonrpcd state=$hstate 非 masked —— 有 #692 硬崩风险面。本脚本不会启它，但首次 SSC QMI 与其同一条 DSP 唤醒链，风险不能排除。继续（不修改该 unit 状态）。"
	fi

	# ① 备齐三个 deb（缺件明确报错，绝不半装）
	stage=/tmp/ssc-deploy
	if [ "$FROM_DEBIAN" = 1 ]; then
		say "① 从 Debian pool 取官方 arm64 包（设备侧 curl，timeout 包裹）"
		rd "rm -rf $stage && mkdir -p $stage && cd $stage && \
curl -fsSL --retry 2 -o $DEB_IIO $DEBIAN_POOL/i/iio-sensor-proxy/$DEB_IIO && \
curl -fsSL --retry 2 -o $DEB_LIBSSC2 $DEBIAN_POOL/libs/libssc/$DEB_LIBSSC2 && \
curl -fsSL --retry 2 -o $DEB_LIBSSCBIN $DEBIAN_POOL/libs/libssc/$DEB_LIBSSCBIN && echo DOWNLOADED" \
			|| die "Debian pool 下载失败"
		# sha256 校验（官方包固定值，防半截下载/替换）
		rd "cd $stage && echo '$SHA_IIO  $DEB_IIO' '$SHA_LIBSSC2  $DEB_LIBSSC2' '$SHA_LIBSSCBIN  $DEB_LIBSSCBIN' | sha256sum -c -" \
			|| die "sha256 校验失败"
	elif [ -n "$PKG_DIR" ]; then
		[ -d "$PKG_DIR" ] || die "--pkg-dir $PKG_DIR 不是目录"
		DEBS=""
		for pat in libssc2_ libssc-bin_ iio-sensor-proxy_; do
			f=$(ls "$PKG_DIR"/${pat}*_arm64.deb 2>/dev/null | head -1)
			[ -n "$f" ] || die "缺件：$PKG_DIR 里没有 ${pat}*_arm64.deb"
			DEBS="$DEBS $f"
		done
		say "① 用本地 deb：$DEBS"
		# shellcheck disable=SC2086
		if [ "$DRY" = 1 ]; then
			for f in $DEBS; do say "[dry-run] scp $f $TARGET:$stage/"; done
		else
			rd "mkdir -p $stage" || die "mkdir 失败"
			# shellcheck disable=SC2086
			timeout -k 5 120 scp $SSH_OPTS $DEBS "$TARGET:$stage/" || die "scp 失败"
		fi
	else
		die "未指定安装源：用 --from-debian 或 --pkg-dir DIR（如 /tmp/ssc-prep/out）"
	fi

	# ② 一次 dpkg -i 装三件（同命令内互相解依赖；失败即整体失败，不留半装）
	say "② dpkg -i 三件套（libssc2 libssc-bin iio-sensor-proxy）"
	rd "dpkg -i $stage/libssc2_*_arm64.deb $stage/libssc-bin_*_arm64.deb $stage/iio-sensor-proxy_*_arm64.deb" \
		|| die "dpkg -i 失败（依赖不齐则不装，禁止 apt-get install 跨套件拉依赖）"

	# ③ udev 规则 + reload + trigger + 重启 proxy
	say "③ 装 81-libssc-elden.rules + udev reload/trigger + restart iio-sensor-proxy"
	# shellcheck disable=SC2086
	if [ "$DRY" = 1 ]; then
		say "[dry-run] scp $RULE_SRC $TARGET:/etc/udev/rules.d/"
		rd "install -m 0644 /etc/udev/rules.d/81-libssc-elden.rules /etc/udev/rules.d/81-libssc-elden.rules; udevadm control --reload-rules && udevadm trigger --subsystem-match=misc && systemctl restart iio-sensor-proxy && echo UDEV-OK"
	else
		# shellcheck disable=SC2086
		timeout -k 5 30 scp $SSH_OPTS -q "$RULE_SRC" "$TARGET:/etc/udev/rules.d/81-libssc-elden.rules" || die "scp 规则失败"
		rd 'install -m 0644 /etc/udev/rules.d/81-libssc-elden.rules /etc/udev/rules.d/81-libssc-elden.rules; udevadm control --reload-rules && udevadm trigger --subsystem-match=misc && systemctl restart iio-sensor-proxy && echo UDEV-OK' \
			|| die "udev/proxy 步骤失败"
	fi

	# ④ 等 ≤10 s 判 HasAccelerometer
	say "④ 等 ≤10 s 读 net.hadess.SensorProxy"
	if [ "$DRY" = 1 ]; then
		rd 'for i in 1 2 3 4 5; do sleep 2; busctl get-property --system net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer && break; done'
	else
		OK=""
		for _ in 1 2 3 4 5; do
			sleep 2
			out=$(rsh 'timeout -k 3 10 busctl get-property --system net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer 2>/dev/null')
			case $out in *true*) OK=1; break ;; esac
		done
		if [ -n "$OK" ]; then say "PASS: HasAccelerometer=true"; else
			die "10 s 内 HasAccelerometer 未变 true —— 跑 bash $0 --check 看矩阵分诊（大概率 udev 属性或 SSC QMI 面问题，见 reports/sensor-libssc-prep-20261126.md §4.4）"
		fi
	fi

	# ⑤ 防回滚：pin + hold
	say "⑤ 写 pin + apt-mark hold（防 apt upgrade 回滚到 3.7-3）"
	rd "printf 'Package: iio-sensor-proxy\nPin: version 3.9*\nPin-Priority: 1001\n' > $PIN_FILE && apt-mark hold iio-sensor-proxy libssc2 libssc-bin && echo PIN-HOLD-OK" \
		|| die "pin/hold 失败"

	say "完成。复检：bash $0 --check"
	;;
esac
