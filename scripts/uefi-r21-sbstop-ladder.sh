#!/bin/bash
# uefi-r21-sbstop-ladder.sh — R21 诊断阶梯：**宿主侧**定位 DXE→BootLinux 的随机同步异常落点
#
# 为什么有它：屏上三条通道（ConOut / 帧缓冲串口 / NV 变量）全部作废，取证只能靠拍屏。
# R20/R21 把停机点做成「cmdline 令牌 `sbstop=N`」+「fastboot 响应回传最后一条标记」，
# 于是判据变成宿主可读字符串：`diag st=Aborted last=[K] stop=N`。
#
# 判据（不需要拍照）：
#   REACHED       收到 `last=[K] stop=N`            ⇒ BootLinux 走到第 N 阶段
#   CRASH_BEFORE  命令超时 + USB 消失               ⇒ 崩在第 N 阶段之前
#   HUNG          命令超时但设备仍在枚举            ⇒ 卡在第 N 阶段之前（未崩）
#   OTHER_STAGE   收到 `stop=M` 且 M≠N              ⇒ 镜像/cmdline 串了，作废这一发
#   INCONC        其他（无输出但设备活着等）        ⇒ 重跑
#
# 阶段语义（patches/uefi/20261104R20-stage-bisect）：
#   1,2 分区表/BaseMem   3 参数装填完(GZip 前)   4 DTBImgCheckAndAppendDT 后
#   5 LoadAddrAndDTUpdate 后   6 FreeVerifiedBootResource 后   7 跳内核前
#
# 纪律：**零写盘** —— 全程只用 `fastboot boot`（ABL 侧载 UEFI + UEFI 侧载内存镜像），
#       不 flash、不 set_active、不碰 boot_b/GPT/槽位。设备锁见 scripts/lib-device-lock.sh。
#       每条 fastboot 都套 `timeout -k`（全局规则 3：长跑必须自截止）。
#
# 用法：
#   scripts/uefi-r21-sbstop-ladder.sh --mkimg-only                 # 只造 4 个 sbstop 件（主机侧）
#   scripts/uefi-r21-sbstop-ladder.sh --dry-run                    # 造件 + 打印排产，不碰设备
#   scripts/uefi-r21-sbstop-ladder.sh                              # 默认：5,3,4,2 × 3 次
#   scripts/uefi-r21-sbstop-ladder.sh --stages 5,3,6,4,2 --repeats 2
#   scripts/uefi-r21-sbstop-ladder.sh --control                    # 先跑基线（未改动的 R21 件）再跑阶梯
#   scripts/uefi-r21-sbstop-ladder.sh --no-setup                   # UEFI 侧 fastboot 已在，跳过 ABL 载入
#   scripts/uefi-r21-sbstop-ladder.sh --keep-going                 # 卡死也继续（默认遇 NO_SERVICE/HUNG 即停，等物理断电）
#
# 环境变量：UEFI_SER（默认 51318dc0 = UEFI 侧 fastboot 序列号）、ABL_SER、TAB（SSH 目标）、
#           UEFI_SIZE/… 与本脚本无关；R21_IMG 可覆盖源镜像路径。
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=${R21_IMG:-$ROOT/out/uefi-20261104R21-hostdiag-r1.img}
STAGES=${STAGES:-5,3,4,2}
REPEATS=${REPEATS:-3}
UEFI_SER=${UEFI_SER:-51318dc0}
ABL_SER=${ABL_SER:-}
TAB=${TAB:-root@192.168.7.1}
SETUP_TIMEOUT=${SETUP_TIMEOUT:-240}    # ABL 载 UEFI 后等 UEFI 侧 fastboot 出现
CMD_TIMEOUT=${CMD_TIMEOUT:-45}         # 单条 `fastboot boot` 的硬上限（含 -k 强杀）
KEEP_GOING=${KEEP_GOING:-0}            # 崩在 dump 循环里（设备卡死）时默认停下，不留一堆废发
OUTDIR=${OUTDIR:-}
MODE=run

while [ $# -gt 0 ]; do
	case "$1" in
		--mkimg-only) MODE=mkimg; shift;;
		--dry-run)    MODE=dry; shift;;
		--no-setup)   NO_SETUP=1; shift;;
		--stages)     STAGES=$2; shift 2;;
		--repeats)    REPEATS=$2; shift 2;;
		--src)        SRC=$2; shift 2;;
		--outdir)     OUTDIR=$2; shift 2;;
		--uefi-serial) UEFI_SER=$2; shift 2;;
		--abl-serial)  ABL_SER=$2; shift 2;;
		--cmd-timeout) CMD_TIMEOUT=$2; shift 2;;
		--selftest)   MODE=selftest; shift;;
		--control)    CONTROL=1; shift;;
		--keep-going) KEEP_GOING=1; shift;;
		-h|--help) sed -n '2,32p' "$0"; exit 0;;
		*) echo "unknown arg: $1" >&2; exit 2;;
	esac
done
NO_SETUP=${NO_SETUP:-0}
CONTROL=${CONTROL:-0}

say()  { echo "[$(date +%H:%M:%S)] $*"; }
warn() { echo "[$(date +%H:%M:%S)] WARN: $*" >&2; }
die()  { echo "[$(date +%H:%M:%S)] FATAL: $*" >&2; exit 1; }

[ -f "$SRC" ] || die "源镜像不存在: $SRC（应为 out/uefi-20261104R21-hostdiag-r1.img）"
SRC=$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC")
SRC_SHA=$(sha256sum "$SRC" | awk '{print $1}')

OUTDIR=${OUTDIR:-$ROOT/reports/artifacts/uefi-r21-sbstop-$(date +%Y%m%dT%H%M%SZ)}
# 镜像（67 MB/件）落 out/（.gitignore，按 out 归档策略管理）；记录/判据落 reports/artifacts（入库）
# 变体镜像放 out/ 的**子目录**：`vk-identity.py` 扫的是 `out/*.img`，顶层放 UEFI 实验件会把
# versions/vk-kernel-identity.tsv 判成过期（check-doctor §5d FAIL）。子目录不进该 glob。
IMGDIR=${IMGDIR:-$ROOT/out/r21-sbstop}
mkdir -p "$OUTDIR" "$IMGDIR"
MANIFEST=$OUTDIR/manifest.tsv
# 注：**不要**往 out/ 写 *.manifest —— check-doctor §5e 要求 config_sha256（build-manifest.sh 格式），
# 手写 manifest 会被判 FAIL。指纹随 records 目录（reports/artifacts，入库）一起提交即可。
LOG=$OUTDIR/run.log
# 把全程 tee 到 run.log；子 shell 里关掉锁 fd（fd 9），否则 tee 会一直持有设备锁
exec > >( exec 9>&-; tee -a "$LOG" ) 2>&1

IFS=',' read -r -a STAGE_LIST <<< "$STAGES"

# ---------- 判据分类（纯字符串，主机侧；--selftest 会用它跑合成样本） ----------
# USB_ALIVE_OVERRIDE：仅 selftest 用（无设备时 lsusb 恒空，会把 CRASH_BEFORE 误判成 HUNG）
# 两种 VID 都要认：ABL fastboot = 18d1:d00d，**UEFI 侧 fastboot = 045e:0c2f**（2026-11-05 实测，
# 换手时设备会先 disconnect 再以新 VID 重新枚举）。
usb_gone() {
	if [ -n "${USB_ALIVE_OVERRIDE:-}" ]; then [ "$USB_ALIVE_OVERRIDE" = 1 ] && return 1 || return 0; fi
	! lsusb 2>/dev/null | grep -qE '18d1:d00d|045e:0c2f'
}
# 设备枚举着 ≠ 固件还在应答：递归 sync-exception dump 会把 fastboot 主循环卡死，
# 此时 `fastboot devices` 仍能看到序列号，但 getvar 永远没有输出（实测 rc=124）。
# 注意：不能用"有输出"当活着的判据 —— 端点已 shutdown 时 fastboot 会打印
# `getvar:product FAILED (reap_urb(0) failed … transport endpoint shutdown)`，那是有输出但已死。
svc_ok() {
	[ -n "${SVC_OVERRIDE:-}" ] && return "$((1-SVC_OVERRIDE))"
	local o
	o=$(timeout -k 3 8 fastboot -s "${1:-$UEFI_SER}" getvar product 2>&1)
	printf '%s' "$o" | grep -q '^product:'
}
# 端点被 shutdown = 固件真的死了（宿主仍缓存设备描述符，`fastboot devices` 还会列出序列号）
svc_dead() {
	local o
	o=$(timeout -k 3 8 fastboot -s "${1:-$UEFI_SER}" getvar product 2>&1)
	printf '%s' "$o" | grep -qiE 'endpoint shutdown|No such device|LIBUSB_ERROR_NO_DEVICE'
}
classify() { # $1=stage $2=raw output file $3=rc
	local n=$1 f=$2 rc=$3 marker st
	marker=$(grep -o 'diag st=[^ ]* last=\[[^]]*\]' "$f" 2>/dev/null | tail -1)
	st=$(grep -o 'diag st=[A-Za-z]*' "$f" 2>/dev/null | tail -1 | sed 's/diag st=//')
	if grep -qE "last=\[[^]]*\] stop=$n( |\$)" "$f" 2>/dev/null; then
		echo "REACHED|$marker|"
	elif grep -qE 'last=\[[^]]*\] stop=[0-9]+' "$f" 2>/dev/null; then
		echo "OTHER_STAGE|$marker|"
	elif [ "$rc" = 124 ] || [ "$rc" = 137 ]; then
		if usb_gone; then echo "CRASH_BEFORE|-|timeout ${CMD_TIMEOUT}s + USB 消失"
		elif [ -n "$st" ]; then echo "INCONC|$marker|timeout 但收到 st=$st"
		elif svc_ok; then echo "HUNG|-|timeout 但 fastboot 仍应答（卡在命令里）"
		elif svc_dead; then echo "CRASH_BEFORE|-|USB 端点 shutdown（固件已死，宿主仍缓存描述符）"
		else echo "NO_SERVICE|-|枚举着但 getvar 无应答（递归 dump 死循环）"; fi
	elif [ -n "$st" ]; then
		echo "INCONC|$marker|st=$st 但无 stop 标记"
	else
		echo "INCONC|$marker|无 diag 输出"
	fi
}

if [ "$MODE" = selftest ]; then
	T=$(mktemp -d); pass=0; fail=0
	t() { # $1=期望 $2=stage $3=rc $4=内容
		printf '%s\n' "$4" > "$T/o.txt"
		got=$(classify "$2" "$T/o.txt" "$3" | cut -d'|' -f1)
		if [ "$got" = "$1" ]; then pass=$((pass+1)); printf 'ok   %-13s stage=%s rc=%s\n' "$got" "$2" "$3";
		else fail=$((fail+1)); printf 'FAIL want=%s got=%s stage=%s rc=%s out=%q\n' "$1" "$got" "$2" "$3" "$4"; fi
	}
	t REACHED      5 1 'Sending 1.496 s\nBooting OKAY 10.1 s\ndiag st=Aborted last=[K] stop=5 \nFAILED (remote: diag)'
	t REACHED      7 1 'diag st=Aborted last=[K] stop=7'
	t OTHER_STAGE  5 1 'diag st=Aborted last=[K] stop=3'
	USB_ALIVE_OVERRIDE=0; t CRASH_BEFORE 5 124 ''
	USB_ALIVE_OVERRIDE=1; SVC_OVERRIDE=1; t HUNG       5 124 'waiting for device'
	USB_ALIVE_OVERRIDE=1; SVC_OVERRIDE=0; t NO_SERVICE 5 124 'Booting'
	unset USB_ALIVE_OVERRIDE SVC_OVERRIDE
	t INCONC       5 0 'FAILED (remote: device not found)'
	t INCONC       5 1 'diag st=Success last=[V] x'
	rm -rf "$T"
	echo "selftest: pass=$pass fail=$fail"
	[ "$fail" = 0 ] || exit 1
	exit 0
fi

say "===== r21 sbstop ladder START mode=$MODE ====="
say "src  $SRC"
say "sha  $SRC_SHA"
say "stages=${STAGE_LIST[*]} repeats=$REPEATS uefi_ser=$UEFI_SER abl_ser=${ABL_SER:-auto} cmd_timeout=${CMD_TIMEOUT}s"
say "records $OUTDIR"
say "images  $IMGDIR"

# ---------- 1) 头校验（源） ----------
python3 "$ROOT/scripts/uefi-sbstop-patch.py" --check "$SRC" > "$OUTDIR/header-src.txt" 2>&1 \
	|| { cat "$OUTDIR/header-src.txt"; die "源镜像头校验失败"; }
sed -n '1,8p' "$OUTDIR/header-src.txt"

# ---------- 2) 造 sbstop 件（主机侧，零设备接触） ----------
: > "$OUTDIR/manifest.tsv"
printf 'stage\ttoken\tfile\tsha256\tsize\tdiff_bytes\n' > "$MANIFEST"
declare -A IMGOF
for n in "${STAGE_LIST[@]}"; do
	dst="$IMGDIR/r21-stop$n.img"
	out=$(python3 "$ROOT/scripts/uefi-sbstop-patch.py" "$SRC" "$n" "$dst" 2>&1)
	rc=$?
	echo "$out" > "$OUTDIR/patch-stage$n.txt"
	if [ $rc -ne 0 ]; then cat "$OUTDIR/patch-stage$n.txt"; die "stage $n 打补丁失败"; fi
	cnt=$(printf '%s\n' "$out" | sed -n 's/.*changed_bytes \([0-9]*\).*/\1/p')
	sha=$(printf '%s\n' "$out" | sed -n 's#^dst   .* sha256 \([0-9a-f]\{64\}\).*#\1#p')
	IMGOF[$n]=$dst
	printf '%d\tsbstop=%d \t%s\t%s\t%s\t%s\n' "$n" "$n" "$(basename "$dst")" "$sha" "$(stat -c%s "$dst")" "${cnt:-?}" \
		>> "$OUTDIR/manifest.tsv"
done
say "造件完成 ${#STAGE_LIST[@]} 件："
column -t -s$'\t' "$MANIFEST" 2>/dev/null || cat "$MANIFEST"
{ echo "# r21 sbstop variants — src $SRC_SHA"; echo "# $(date -Is)"; cat "$MANIFEST"; } > "$OUTDIR/variants.sha256.tsv"
say "镜像指纹 $OUTDIR/variants.sha256.tsv"

if [ "$MODE" = mkimg ] || [ "$MODE" = dry ]; then
	{
		echo "# 排产（$MODE）"
		echo "1) fastboot ${ABL_SER:+-s $ABL_SER} boot $SRC          # ABL 侧载 UEFI（零写盘）"
		echo "2) 等 UEFI 侧 fastboot 出现（序列号 $UEFI_SER，上限 ${SETUP_TIMEOUT}s）"
		for n in "${STAGE_LIST[@]}"; do
			echo "3) for r in 1..$REPEATS: fastboot -s $UEFI_SER boot ${IMGOF[$n]}   # 判据 diag st=… last=[K] stop=$n"
		done
	} | tee "$OUTDIR/plan.txt"
	[ "$MODE" = mkimg ] && say "mkimg-only 完成（未碰设备）"
	[ "$MODE" = dry ] && say "dry-run 完成（未碰设备）"
	exit 0
fi

# ---------- 3) 设备侧：锁 + fastboot 原语 ----------
[ "$(date +%s)" ] >/dev/null
command -v fastboot >/dev/null || die "fastboot 不在 PATH"
. "$ROOT/scripts/lib-device-lock.sh"
device_lock_acquire

fb() { timeout -k 5 "$CMD_TIMEOUT" fastboot ${ABL_SER:+-s "$ABL_SER"} "$@" 2>&1; }
fb_uefi() { timeout -k 5 "$CMD_TIMEOUT" fastboot -s "$UEFI_SER" "$@" 2>&1; }
devices() { timeout -k 3 8 fastboot devices 2>/dev/null | awk 'NF{print $1}'; }
have_ser() { devices | grep -qx "$1"; }

ensure_abl_fastboot() {
	have_ser "${ABL_SER:-$(devices | head -1)}" && return 0
	# 若设备还在 Linux（U2），用项目既有入口切 fastboot；不在 Linux 就不猜，直接报错
	if timeout -k 3 8 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=6 "$TAB" true 2>/dev/null; then
		say "ssh 可用 ⇒ reboot bootloader"
		timeout -k 5 20 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$TAB" 'sync; eldroid-bootctl reboot bootloader' >/dev/null 2>&1
		for i in $(seq 1 45); do sleep 2; devices | grep -q . && { say "fastboot 起来 ~$((i*2))s"; return 0; }; done
	fi
	devices | grep -q . && return 0
	return 1
}

ensure_uefi_fastboot() {
	[ "$NO_SETUP" = 1 ] && { have_ser "$UEFI_SER" && return 0; return 1; }
	say "ABL 侧载 UEFI: fastboot boot $(basename "$SRC")"
	fb boot "$SRC" | tee "$OUTDIR/abl-boot-$1.txt"
	local t0=$(date +%s)
	while [ $(( $(date +%s) - t0 )) -lt "$SETUP_TIMEOUT" ]; do
		have_ser "$UEFI_SER" && { say "UEFI 侧 fastboot 出现（$UEFI_SER，~$(( $(date +%s) - t0 ))s）"; return 0; }
		sleep 2
	done
	warn "UEFI 侧 fastboot 未在 ${SETUP_TIMEOUT}s 内出现（可能崩在 DXE 之前/AUTORUN 未起）"
	return 1
}

ensure_abl_fastboot || die "拿不到 ABL fastboot：设备既不在 fastboot 也不在可 SSH 的 Linux（PITFALLS #368：复位后 ~11s 内再 reboot2 需物理断电）"

# ---------- 4) 阶梯 ----------
: > "$OUTDIR/results.tsv"
printf 'stage\trun\tverdict\telapsed_s\tmarker\tnote\n' >> "$OUTDIR/results.tsv"

run_one() { # $1=stage $2=run
	local n=$1 r=$2 img=${IMGOF[$1]} f="$OUTDIR/run-s${n}-r${r}.txt"
	local t0 t1 el out res v note mk
	if ! have_ser "$UEFI_SER"; then
		warn "stage $n run $r：UEFI 侧 fastboot 不在，重做 ABL 载入"
		ensure_uefi_fastboot "re-s$n-r$r" || { printf '%d\t%d\tSETUP_FAIL\t-\t-\tUEFI fastboot 未出现\n' "$n" "$r" >> "$OUTDIR/results.tsv"; return; }
	fi
	t0=$(date +%s)
	fb_uefi boot "$img" > "$f" 2>&1; local rc=$?
	t1=$(date +%s); el=$((t1-t0))
	res=$(classify "$n" "$f" "$rc")
	v=${res%%|*}; rest=${res#*|}; mk=${rest%%|*}; note=${rest#*|}
	printf '%d\t%d\t%s\t%s\t%s\t%s\n' "$n" "$r" "$v" "$el" "${mk:--}" "${note:--}" >> "$OUTDIR/results.tsv"
	say "stage $n run $r → $v (${el}s) ${mk:--} ${note:--}"
	# 判据样本同时落一份精简日志，方便事后取证
	grep -E 'diag st=|stop=|Booting|FAILED|Err' "$f" | tail -5 >> "$OUTDIR/diag-tail.txt" 2>/dev/null
}

# ---------- 4a) 基线对照：未改动的 R21 件走同一条 UEFI 侧 `boot` 路径 ----------
# 目的：证明「卡死」不是我们注入的 `sbstop=N ` 令牌造成的（令牌只改 8 字节 cmdline，
# 但判据必须能排除它）。基线也卡死 ⇒ 卡死是 R21 件本身的随机异常，令牌无关。
if [ "$CONTROL" = 1 ]; then
	if ! have_ser "$UEFI_SER"; then ensure_uefi_fastboot "control" || die "基线：UEFI 侧 fastboot 没起来"; fi
	f="$OUTDIR/run-control.txt"; t0=$(date +%s)
	fb_uefi boot "$SRC" > "$f" 2>&1; rc=$?; t1=$(date +%s); el=$((t1-t0))
	if grep -q 'diag st=' "$f" 2>/dev/null; then v=CONTROL_ALIVE; mk=$(grep -o 'diag st=[^ ]* last=\[[^]]*\]' "$f" | tail -1)
	elif usb_gone; then v=CRASH_BEFORE; mk=-
	elif svc_ok; then v=HUNG; mk=-
	else v=NO_SERVICE; mk=-; fi
	printf '0	1	%s	%s	%s	%s
' "$v" "$el" "$mk" "control=未改动 R21 件" >> "$OUTDIR/results.tsv"
	say "control（未改动 R21）→ $v (${el}s)"
	if [ "$v" = NO_SERVICE ] || [ "$v" = HUNG ]; then
		warn "基线也卡死 ⇒ 与 sbstop 令牌无关；设备需要物理断电后才能跑阶梯。"
		[ "$KEEP_GOING" = 1 ] || exit 0
	fi
fi

STUCK=0
for n in "${STAGE_LIST[@]}"; do
	for r in $(seq 1 "$REPEATS"); do
		run_one "$n" "$r"
		# 设备卡进 dump 循环后必须物理断电才能继续 ⇒ 默认不再往下浪费
		case "$(tail -1 "$OUTDIR/results.tsv" | cut -f3)" in
			NO_SERVICE|HUNG) [ "$KEEP_GOING" = 1 ] || { STUCK=1; break 2; };;
		esac
		sleep 2
	done
done
if [ "$STUCK" = 1 ]; then
	warn "设备已卡死（枚举着但 fastboot 不应答）⇒ 需要**物理断电**再开机才能继续（这一步只能你来）。"
	warn "恢复后重跑：按 SUMMARY 里已取到的最大应答档位继续，或先用 --control 跑基线。"
fi

# ---------- 5) 汇总 ----------
say "===== 汇总 ====="
column -t -s$'\t' "$OUTDIR/results.tsv" 2>/dev/null || cat "$OUTDIR/results.tsv"

python3 - "$OUTDIR/results.tsv" <<'PY' | tee "$OUTDIR/SUMMARY.md"
import sys, collections
rows=[l.rstrip('\n').split('\t') for l in open(sys.argv[1]) if l.strip()]
rows=[r for r in rows[1:] if len(r)>=3]
by=collections.defaultdict(lambda: collections.Counter())
for r in rows: by[int(r[0])][r[2]]+=1
print("| stage | 语义 | REACHED | CRASH_BEFORE | HUNG | INCONC | 判读 |")
print("|---|---|---|---|---|---|---|")
sem={1:'分区/BaseMem',2:'分区/BaseMem',3:'参数装填完',4:'DTB 校验+追加后',5:'LoadAddrAndDTUpdate 后',6:'释放 VB 资源后',7:'跳内核前'}
for st in sorted(by, reverse=True):
    c=by[st]
    reached=c.get('REACHED',0); tot=sum(c.values())
    verdict = "到达（该段无事）" if reached==tot else ("崩/卡在该段之前" if c.get('CRASH_BEFORE',0) else "不确定性，需重跑")
    print("| %d | %s | %d | %d | %d | %d | %s |" % (st, sem.get(st,'?'), reached,
          c.get('CRASH_BEFORE',0), c.get('HUNG',0), c.get('INCONC',0)+c.get('OTHER_STAGE',0), verdict))
print()
print("原始：`%s`" % sys.argv[1])
PY

say "产物目录 $OUTDIR"
say "设备安全态核对（零写盘）：boot_b 应仍未变；如需回 Linux 走你惯用的恢复动作，本脚本不写盘"
say "===== ladder DONE ====="
