#!/bin/bash
# uefi-flashed-trial.sh — flashed 形态（写 boot_a）一发的**免屏计时判据**取证（G1-29 线）
#
# 为什么有它（2026-11-10）：
#   `p67` 之后 flashed 形态只剩两条判据通道 —— 屏（要人盯）与 BdsDxe 信标（BdsDxe 之前没有）。
#   `p69`（R70）在 PrePi 的 `[P00]`/`[P08]`/`[P10]` 各停 25 s ⇒「从 `fastboot reboot` 到 SSH
#   可用」的总耗时变成**分级判据**（0 / +25 / +50 / +75 s），不需要人、不需要串口。
#
# 做什么（唯一写盘 = boot_a；结束时**不自动回滚**，由调用者决定，避免脚本自己猜）：
#   前置态（uname/cmdline/分区 sha/槽位属性/logfs 快照）→ Linux→fastboot → flash boot_a
#   → set_active a → **t0: fastboot reboot** → 轮询 SSH（一有响应就返回）→ t1
#   → 后置态 + logfs 快照 + 槽位属性 → 落 trial record（含 T_total 与各判据）
#
# 用法：
#   scripts/uefi-flashed-trial.sh --image out/r21-sbstop-p69/uefi-preamble69-r1.img --label p69-r70-timing
#   scripts/uefi-flashed-trial.sh --image ... --label ... --expect-kernel 'vk184-0000'   # 落地内核断言（可选）
#   scripts/uefi-flashed-trial.sh --image ... --label ... --no-reboot   # 只刷不重启（备料核对用）
#   scripts/uefi-flashed-trial.sh --part vbmeta_a --image out/vbmeta-a-flags3/….img --label vbmeta-a-flags3
#                                                            # 2026-11-10 新增：不只 boot_a，任意 a 槽分区（默认 boot_a）
#
# 铁律（PITFALLS #569/#584/#585/#590）：
#   · 目标必须显式锁定：SER 或 product 唯一匹配 `elden`，0 个/多个一律 FATAL；
#   · fastboot 一律单发 + `timeout -k`，输出**不进管道**；
#   · 一条 shell 命令里不同时出现 ssh 与 fastboot（先 ssh 取结果，再单发 fastboot）；
#   · 总时限由 `--max-wait`（默认 300 s）兜住，超时即判 indeterminate 并落现场。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SER=${SER:-}
PRODUCT_MATCH=${PRODUCT_MATCH:-elden}
IMG=""; LABEL=""; OUTDIR=""; MAXWAIT=${MAXWAIT:-300}; DO_REBOOT=1; EXPECT_KERNEL=""; PART=${PART:-boot_a}

while [ $# -gt 0 ]; do
	case "$1" in
		--image)  IMG=$2; shift 2;;
		--part)   PART=$2; shift 2;;   # 刷哪个分区（默认 boot_a；2026-11-10 起也用于 vbmeta_a）
		--label)  LABEL=$2; shift 2;;
		--outdir) OUTDIR=$2; shift 2;;
		--max-wait) MAXWAIT=$2; shift 2;;
		--expect-kernel) EXPECT_KERNEL=$2; shift 2;;
		--no-reboot) DO_REBOOT=0; shift;;
		-h|--help) sed -n '2,30p' "$0"; exit 0;;
		*) echo "unknown arg: $1" >&2; exit 2;;
	esac
done
[ -n "$IMG" ] && [ -f "$IMG" ] || { echo "--image required (existing file)" >&2; exit 2; }
[ -n "$LABEL" ] || { echo "--label required" >&2; exit 2; }
IMG=$(cd "$(dirname "$IMG")" && pwd)/$(basename "$IMG")
IMGSHA=$(sha256sum "$IMG" | awk '{print $1}')
IMGSZ=$(stat -c %s "$IMG")
OUTDIR=${OUTDIR:-$ROOT/reports/artifacts/uefi-flashed-$(date +%Y%m%d-%H%M%S)-$LABEL}
mkdir -p "$OUTDIR"
LOG=$OUTDIR/run.log
exec > >( exec 9>&-; tee -a "$LOG" ) 2>&1

. "$ROOT/scripts/lib-device-lock.sh"
device_lock_acquire
. "$ROOT/scripts/lib-fastboot.sh"

say() { echo "[$(date +%H:%M:%S)] $*"; }
T0_ABS=""

# 槽位属性读数靠 device 侧 slot-attr.py（GPT 属性字节，不是分区内容）；不在就先送过去
ensure_slot_attr() {
	sshc 'test -f /tmp/slot-attr.py' 10 && return 0
	cat "$ROOT/scripts/slot-attr.py" | ssh -o BatchMode=yes -o ConnectTimeout=8 \
		-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$TAB" \
		'cat > /tmp/slot-attr.py && chmod +x /tmp/slot-attr.py' 2>/dev/null
}

# ---- 目标锁定（product 唯一匹配）----
resolve_target() {
	[ -n "$SER" ] && return 0
	local list ser prod hits="" cnt=0 f
	f=$(mktemp /tmp/fbd.XXXXXX)
	timeout -k 2 10 fastboot devices >"$f" 2>/dev/null
	list=$(cat "$f"); rm -f "$f"
	local n; n=$(printf '%s\n' "$list" | grep -c . || true)
	[ "$n" -ge 1 ] || { say "FATAL: 总线上没有 fastboot 设备"; return 1; }
	# ★ `fastboot devices` 每行是 "SN\tfastboot" 两列 —— 直接 `read -r ser` 会把整行当 SN
	#   （2026-11-10 实测：`-s "HA2EXB0E<TAB>fastboot"` ⇒ getvar 拿不到 product ⇒ 判定「没进 fastboot」，
	#   白等 9 min）。必须只取第一列。
	while read -r ser; do
		[ -n "$ser" ] || continue
		f=$(mktemp /tmp/fbp.XXXXXX)
		timeout -k 2 10 fastboot -s "$ser" getvar product >"$f" 2>&1
		prod=$(awk -F': ' '/^product:/{print $2}' "$f"); rm -f "$f"
		say "  bus: $ser product=${prod:-?}"
		case "$prod" in *"$PRODUCT_MATCH"*) hits+="$ser "; cnt=$((cnt+1));; esac
	done <<< "$(printf '%s\n' "$list" | awk 'NF{print $1}')"
	if [ "$cnt" -ne 1 ]; then
		say "FATAL: product 匹配 '$PRODUCT_MATCH' 的设备数 = $cnt（必须恰好 1；命中: ${hits:-无}）"
		return 1
	fi
	SER=$(echo $hits)
	say "目标锁定 SER=$SER"
}

# fastboot_devices_has_target —— 只读探测「目标是否已在 fastboot」（不进管道、有超时）
# SER 未定时退回 resolve_target（按 product 唯一匹配锁定并写回 SER），
# 否则「还没锁定 ⇒ 永远报不在」会把等待循环变成空转（2026-11-10 自查）。
fastboot_devices_has_target() {
	if [ -z "${SER:-}" ]; then
		resolve_target
		return $?
	fi
	local f l
	f=$(mktemp /tmp/fbd.XXXXXX)
	timeout -k 2 8 fastboot devices >"$f" 2>/dev/null
	l=$(awk 'NF{print $1}' "$f" | grep -x -- "$SER" || true)
	rm -f "$f"
	[ -n "$l" ]
}

# ---- 设备侧只读取证（一条 ssh 一次做完，绝不与 fastboot 同命令）----
snap() { # snap <tag>
	local tag=$1 f=$OUTDIR/$1.txt
	# 设备重启后 /tmp 是 tmpfs ⇒ 每次都要确认读端在场（2026-11-10 实测 post 快照为空）
	ensure_slot_attr
	{
		echo "## $tag  $(date -Is)"
		sshc 'uname -r; cat /proc/cmdline; uptime' 25 2>&1
		echo "-- boot partitions --"
		sshc "sha256sum /dev/disk/by-partlabel/boot_a /dev/disk/by-partlabel/boot_b \
			/dev/disk/by-partlabel/vbmeta_a /dev/disk/by-partlabel/vbmeta_b" 40 2>&1
		echo "-- slot attrs --"
		sshc 'python3 /tmp/slot-attr.py show 2>/dev/null | grep -E "^  boot_[ab] "' 40 2>&1
	} > "$f" 2>&1
	say "落 $f"
}

logfs_snap() { # logfs_snap <tag>
	# PITFALLS #587：先验字节数（8 MiB），否则读残片当全量会得出反结论。
	# 2026-11-10 补：USB-NCM 抖一下就会把 dd 截断（实测 8 355 840 B，紧接着连 ssh 都超时）
	# ⇒ 短读必须**重试**，不是只打个警告。
	local tag=$1 n=0 try
	for try in 1 2 3; do
		sshc 'dd if=/dev/disk/by-partlabel/logfs bs=1M 2>/dev/null' 90 > "$OUTDIR/logfs-$tag.bin" 2>/dev/null
		n=$(stat -c %s "$OUTDIR/logfs-$tag.bin" 2>/dev/null || echo 0)
		[ "$n" = "8388608" ] && break
		say "  ⚠ logfs 短读 $n B（第 $try 次），5 s 后重试"
		sleep 5
	done
	if [ "$n" = "8388608" ]; then say "logfs 快照 $tag = $n B ✔"; else say "⚠ logfs 快照 $tag = $n B（期望 8388608，已重试 3 次）"; fi
}

say "== 目标 $LABEL ; 件 $IMG"
say "   件 sha256=$IMGSHA size=$IMGSZ B"
say "   取证目录 $OUTDIR"

say "== [1/6] 前置态（Linux 侧只读）"
ensure_slot_attr
snap pre
logfs_snap pre

say "== [2/6] Linux → fastboot"
# 2026-11-10 修（第二轮）：旧版 `if sshc 'true'; then reboot; fi` 逻辑反了 ——
#   只要那次 ssh 因 USB-NCM 抖动超时（实测 logfs dd 被截断后紧跟一次 ssh 超时），
#   **reboot 就永远不发**，然后静默等 fastboot（用户看到「脚本没动」，只能 abort）。
# 现在：① 已在 fastboot 就跳过；② ssh 不通也记录并继续等；③ 轮询每 3 s 打一行状态。
if fastboot_devices_has_target; then
	say "  设备已在 fastboot（跳过 reboot）"
else
	if sshc 'true' 15; then
		say "  ssh 可达 → 发 reboot bootloader"
		sshc 'nohup /usr/local/bin/eldroid-bootctl reboot bootloader >/dev/null 2>&1 || true' 15 || true
	else
		say "  ⚠ ssh 不可达（设备不在 Linux，或 USB-NCM 刚抖过）——仍继续等 fastboot"
	fi
fi
ok=0
for i in $(seq 1 45); do
	if fastboot_devices_has_target; then ok=1; break; fi
	if timeout 3 ssh -o BatchMode=yes -o ConnectTimeout=2 -o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$TAB" true 2>/dev/null; then
		say "  [$(($i*3))s] 等 fastboot… 仍在 Linux"
	else
		say "  [$(($i*3))s] 等 fastboot… ssh 不通（重启中）"
	fi
	sleep 3
done
[ "$ok" = 1 ] || { say "FATAL: 135 s 内没进 fastboot"; echo "VERDICT=NOFASTBOOT" > "$OUTDIR/verdict.txt"; exit 3; }
resolve_target || exit 3
say "fastboot 在线: $(echo "$_FB_OUT")"

say "== [3/6] flash $PART"
t_flash0=$(date +%s.%N)
fbx flash "$PART" "$IMG"; rc=$?; t_flash1=$(date +%s.%N)
printf 'rc=%s\n%s\n' "$rc" "$_FB_OUT" > "$OUTDIR/flash.txt"
say "$_FB_OUT"
[ "$rc" = 0 ] || { say "FATAL: flash 失败 rc=$rc"; echo "VERDICT=FLASHFAIL" > "$OUTDIR/verdict.txt"; exit 4; }

say "== [4/6] set_active a（重置 _a 的 retry/unbootable）"
fbx set_active a; printf '%s\n' "$_FB_OUT" > "$OUTDIR/setactive.txt"; say "$_FB_OUT"

if [ "$DO_REBOOT" = 0 ]; then
	say "--no-reboot：停在 fastboot，未重启"
	echo "VERDICT=FLASHED_ONLY" > "$OUTDIR/verdict.txt"
	exit 0
fi

say "== [5/6] t0: fastboot reboot → 轮询 SSH（判据 = 总耗时）"
t0=$(date +%s.%N); T0_ABS=$(date -Is)
fbx reboot; printf '%s\n' "$_FB_OUT" > "$OUTDIR/reboot.txt"
up=0; tw=$SECONDS
while [ $((SECONDS - tw)) -lt "$MAXWAIT" ]; do
	if timeout 4 ssh -o BatchMode=yes -o ConnectTimeout=2 -o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$TAB" true 2>/dev/null; then up=1; break; fi
	sleep 2
done
t1=$(date +%s.%N)
T=$(python3 -c "print(f'{$t1-$t0:.1f}')")

say "== [6/6] 后置态 + 判据"
if [ "$up" = 1 ]; then
	snap post
	logfs_snap post
	K=$(sshc 'uname -r' 10 2>/dev/null | tail -1)
	SLOT=$(sshc 'cat /proc/cmdline' 10 2>/dev/null | tr ' ' '\n' | grep -m1 '^androidboot.slot_suffix=')
	{
		echo "T_total_s=$T"
		echo "t0=$T0_ABS"
		echo "image=$IMG sha256=$IMGSHA"
		echo "flash_s=$(python3 -c "print(f'{$t_flash1-$t_flash0:.1f}')")"
		echo "kernel_after=$K"
		echo "$SLOT"
	} > "$OUTDIR/timing.txt"
	if [ -n "$EXPECT_KERNEL" ] && ! printf '%s' "$K" | grep -q "$EXPECT_KERNEL"; then
		say "⚠ 落地内核 $K 不含期望串 $EXPECT_KERNEL"
	fi
	say "T_total = ${T}s   landed kernel = $K   $SLOT"
	echo "VERDICT=RECOVERED T_total_s=$T" > "$OUTDIR/verdict.txt"
else
	say "T_total >= ${MAXWAIT}s：SSH 未起（可能停在 payload 或没回落）"
	snap timeout-state || true
	{ echo "T_total_s=>=$MAXWAIT"; echo "image=$IMG sha256=$IMGSHA"; } > "$OUTDIR/timing.txt"
	echo "VERDICT=NO_RECOVERY" > "$OUTDIR/verdict.txt"
fi
say "== 结束。判读表见 patches/uefi/20261110R70-prepi-timing/0001-prepi-timing-bands.patch 头部"
case "$PART" in
	boot_a)   say "   回滚：fastboot flash boot_a backup/boot_a-pre-uefi-20261108.img && fastboot set_active b";;
	vbmeta_a) say "   回滚：fastboot flash vbmeta_a backup/vbmeta_a-orig-20261110.img（原厂 Flags=0）";;
	*)        say "   回滚：按 $PART 自行备份件";;
esac
