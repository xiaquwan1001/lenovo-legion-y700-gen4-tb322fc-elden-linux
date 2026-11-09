#!/bin/bash
# uefi-boot-trial.sh — 一次「UEFI 异类载荷 fastboot boot」上机实验的全过程取证（G1-29 线）
#
# 做什么（全部零写盘，除恢复时的 set_active）：
#   门禁 → SSH 前置态 → PSCI 进 fastboot → fastboot getvar 前置 → 后台 USB/ABL 采样
#   → `fastboot boot <img>` → 采样 60 s → 判「交棒 / 未交棒」
#   → 恢复（`fastboot continue` 优先：同一次 ABL 会话继续启动，能让 logfs 记下失败的这一发；
#      否则 `fastboot reboot`；若已回落 stock Android 则 adb 进 fastboot → set_active b）
#   → SSH 后置态 + **logfs 取证** → 落 trial record
#
# 用法：
#   scripts/uefi-boot-trial.sh --image <img> --label <label> [--outdir DIR] [--watch 60]
#
# 判据（与历史轮次一致）：
#   交棒(HANDOFF)   = fastboot 不再应答 / USB 设备消失（ABL gadget 销毁）
#   未交棒(NOJUMP)  = 60 s 内 fastboot 持续应答、bus/device 不变
#
# 纪律：fastboot 一律单条；设备锁串行；--reset warm（Linux→fastboot 是暖复位，本判据不依赖复位深度）。
#
# ★目标设备锁定（2026-11-08，PITFALLS #569）：总线上可能同时挂着**别的手机**的 fastboot。
#   旧版直接取 `fastboot devices` 的第一行当目标 —— 2026-11-08 21:42 的一发把 65 MB 的 UEFI
#   载荷 `fastboot boot` 发给了华为裸机（`product: kirin990`，被对方 `invalid command` 拒），
#   我们的板子（product=elden_prc_wifi）在总线上排第二 ⇒ 这一发根本没打到目标。
#   现行规则（与 `scripts/slot-switch.sh` 同一口径，PITFALLS #371）：
#     · 显式 `SER=<SN>` 优先；否则**按 product 匹配 `$PRODUCT_MATCH`（默认 elden）** 逐个探测，
#       恰好一个匹配才采用，0 个或多个匹配一律 FATAL；
#     · `fb()` 在 SER 为空时**直接拒绝执行**（不再“裸 fastboot”）；adb 侧永不猜设备。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TAB=${TAB:-root@192.168.7.1}
SER=${SER:-}
IMG=""; LABEL=""; OUTDIR=""; WATCH=${WATCH:-60}
PRODUCT_MATCH=${PRODUCT_MATCH:-elden}

while [ $# -gt 0 ]; do
	case "$1" in
		--image) IMG=$2; shift 2;;
		--label) LABEL=$2; shift 2;;
		--outdir) OUTDIR=$2; shift 2;;
		--watch) WATCH=$2; shift 2;;
		-h|--help) sed -n '2,20p' "$0"; exit 0;;
		*) echo "unknown arg: $1" >&2; exit 2;;
	esac
done
[ -n "$IMG" ] && [ -f "$IMG" ] || { echo "--image required (existing file)" >&2; exit 2; }
[ -n "$LABEL" ] || { echo "--label required" >&2; exit 2; }
IMG=$(cd "$(dirname "$IMG")" && pwd)/$(basename "$IMG")
SHA=$(sha256sum "$IMG" | awk '{print $1}')
OUTDIR=${OUTDIR:-$ROOT/reports/artifacts/uefi-boot-$(date +%Y%m%d-%H%M%S)}
mkdir -p "$OUTDIR"
LOG=$OUTDIR/run.log
exec > >( exec 9>&-; tee -a "$LOG" ) 2>&1   # 子 shell 里关掉锁 fd，否则 tee 会一直持有设备锁

. "$ROOT/scripts/lib-device-lock.sh"
device_lock_acquire

say() { echo "[$(date +%H:%M:%S)] $*"; }
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"
S() { timeout "${2:-20}" $SSH "$1" 2>/dev/null; }
fb_devices() { timeout 8 fastboot devices 2>/dev/null | awk 'NF{print $1}'; }
fb() {
	if [ -z "$SER" ]; then
		echo "[trial] ❌ 拒绝执行 \`fastboot $*\`：目标设备未锁定（PITFALLS #569）" >&2
		return 2
	fi
	timeout "${FBTO:-30}" fastboot -s "$SER" "$@" 2>&1
}
fb_product() { fb getvar product 2>&1 | awk -F': ' '/^product:/{print $2}'; }

# 选定目标设备：显式 SER，或 product 唯一匹配 $PRODUCT_MATCH
resolve_target() {
	[ -n "$SER" ] && return 0
	local list n ser prod hits="" hitp="" cnt=0
	list=$(fb_devices); n=$(printf '%s\n' "$list" | grep -c . || true)
	if [ "$n" -eq 0 ]; then
		echo "[trial] ❌ 总线上没有 fastboot 设备"
		return 1
	fi
	while read -r ser; do
		[ -n "$ser" ] || continue
		prod=$(timeout 8 fastboot -s "$ser" getvar product 2>&1 | awk -F': ' '/^product:/{print $2}')
		case "$prod" in
			*"$PRODUCT_MATCH"*) hits="$hits $ser"; hitp="$prod"; cnt=$((cnt+1));;
			*) echo "[trial] 跳过非目标 fastboot 设备：$ser (product=${prod:-?})";;
		esac
	done <<< "$list"
	if [ "$cnt" -ne 1 ]; then
		echo "[trial] ❌ 目标设备不唯一（match=$cnt，条件 product 含 '$PRODUCT_MATCH'）。请显式 SER=<SN>：见 `fastboot devices`" >&2
		return 1
	fi
	SER=$(printf '%s' "$hits" | tr -d ' ')
	echo "[trial] 自动锁定 fastboot 设备：$SER (product=$hitp)"
	return 0
}

# 在 fastboot 里且就是目标设备（product 复核过）
fb_ok() { resolve_target >/dev/null 2>&1 && [ -n "$SER" ] && [ -n "$(fb_product)" ]; }
# adb 只认显式 SER（永不用裸 adb：总线上别的手机也会答 device）
adbx() { [ -n "$SER" ] && timeout "${ADBTO:-15}" adb -s "$SER" "$@" 9>&- 2>/dev/null; }

say "===== trial START label=$LABEL image=$(basename "$IMG") sha=$SHA ====="
say "image_size=$(stat -c%s "$IMG")"

# ---------- 门禁（只读） ----------
bash "$ROOT/scripts/trial.sh" gate 2>&1 | tee "$OUTDIR/gate.txt" | tail -3

# ---------- 前置态 ----------
{
	echo "# ssh pre $(date -Is)"
	S 'cat /proc/sys/kernel/random/boot_id; uptime -p; cat /proc/cmdline; lsblk -o NAME,SIZE,PARTLABEL | grep -E "boot_b|logfs"'
} > "$OUTDIR/ssh-pre.txt" 2>&1
PRE_BOOTID=$(sed -n 2p "$OUTDIR/ssh-pre.txt")   # 第 1 行是 "# ssh pre <时间>" 表头（2026-11-07 修正）
say "pre boot_id=$PRE_BOOTID"
grep -q . "$OUTDIR/ssh-pre.txt" || say "WARN: ssh pre-state empty"

# ---------- 进 fastboot（PSCI vendor reset） ----------
if fb_ok; then
	say "already in fastboot"
else
	say "ssh -> reboot bootloader (eldroid-bootctl)"
	S 'sync; eldroid-bootctl reboot bootloader' >/dev/null 2>&1
	for i in $(seq 1 45); do
		sleep 2
		fb_ok && { say "fastboot up after ~$((i*2))s"; break; }
	done
	fb_ok || { say "FATAL: fastboot did not come up (PITFALLS #368: 复位后 ~11 s 内再 reboot2 需物理断电)"; exit 1; }
fi
resolve_target || { say "FATAL: 目标设备未锁定，拒绝发 fastboot 命令（PITFALLS #569）"; exit 1; }
say "SER=$SER"
{
	echo "# devices $(date -Is)"
	echo "## all fastboot devices"; fb_devices
	echo "## adb devices (仅供参考，不使用)"; timeout 8 adb devices 9>&- 2>/dev/null
} > "$OUTDIR/devices.txt" 2>&1

{
	echo "# fastboot pre $(date -Is)"
	fb getvar product
	fb getvar current-slot
	fb getvar slot-unbootable:b
	fb getvar bootloader
} > "$OUTDIR/fastboot-pre.txt" 2>&1
sed -n '1,40p' "$OUTDIR/fastboot-pre.txt"
PROD=$(awk -F': ' '/^product:/{print $2; exit}' "$OUTDIR/fastboot-pre.txt")
case "$PROD" in
	*"$PRODUCT_MATCH"*) say "product gate OK ($PROD)";;
	*) say "FATAL: product='$PROD' 不含 '$PRODUCT_MATCH' —— 目标设备不对，拒绝继续（PITFALLS #569）"; exit 1;;
esac

# ---------- 采样器 ----------
# 每秒 lsusb 计数（18d1:d00d），每 3 秒一次 fastboot getvar（证明 ABL 还活着），带时间戳
watch_usb() {
	local secs=$1 out=$2 i usb alive
	for i in $(seq 1 "$secs"); do
		usb=$(lsusb 2>/dev/null | grep -c '18d1:d00d')
		busdev=$(lsusb 2>/dev/null | awk '/18d1:d00d/{print $2"/"$4; exit}')
		if [ $((i % 3)) -eq 0 ]; then
			# 2026-11-09: 设备已不在 fastboot 时**不要**再发 getvar（会阻塞到 timeout，串行 90 次
			# 就是十几分钟挂在那里，2026-11-09 p62 那一发实测）——先确认总线上还有我们的 SN。
			if ! fb_devices | grep -qx "$SER"; then
				alive=gone
			elif FBTO=4 fb getvar product >/dev/null 2>&1; then alive=1; else alive=0; fi
		else alive="-"; fi
		printf '%3d usb=%s %s abalive=%s\n' "$i" "$usb" "${busdev:-none}" "$alive" >> "$out"
		sleep 1
	done
}
: > "$OUTDIR/usb-watch.txt"

# ---------- 打这一发 ----------
say "fastboot boot $(basename "$IMG")"
watch_usb "$WATCH" "$OUTDIR/usb-watch.txt" &
WPID=$!
sleep 1
T0=$(date +%s)
fb boot "$IMG" | tee "$OUTDIR/boot.txt"
T1=$(date +%s)
say "fastboot boot returned after $((T1-T0))s"
wait $WPID

USB_ALIVE=$(tail -1 "$OUTDIR/usb-watch.txt" | sed -n 's/.*usb=\([0-9]*\).*/\1/p')
N_OF=$(grep -c 'usb=1' "$OUTDIR/usb-watch.txt")
say "watch: usb_present_last=$USB_ALIVE samples_with_usb=$N_OF/$WATCH"

# ---------- 判定 ----------
if grep -q 'Booting FAILED' "$OUTDIR/boot.txt"; then V=HANDOFF
elif [ "${USB_ALIVE:-0}" = 0 ]; then V=HANDOFF
else V=NOJUMP; fi
# 2026-11-07 修正：`fastboot 无应答` 只说明 ABL 的 gadget 被销毁，**不证明 UEFI 交棒**
# （PITFALLS #549：跳转后复位、ABL 自己引导 boot_b 也会这样）。真正的排他判据是内核
# `/proc/cmdline` 里的 `elden_bootpath=uefi`（R43 起 UEFI 才写），所以候选判定只作记录。
V_CAND=$V
say "VERDICT(candidate)=$V_CAND"

# ---------- 恢复 ----------
say "recovering..."
if fb_ok; then
	say "ABL alive -> try 'fastboot continue'（同会话续启动，保留 logfs）"
	if ! fb continue > "$OUTDIR/continue.txt" 2>&1; then
		say "continue failed/unsupported -> fastboot reboot"
		fb reboot > "$OUTDIR/reboot.txt" 2>&1 || true
	fi
else
	say "ABL gone (handoff) -> wait for fallback (Android) or ABL watchdog"
fi

# 等 Linux 或 Android 出现（最多 240 s）
MODE=none
for i in $(seq 1 120); do
	if [ "$(S 'echo up' 6)" = up ]; then MODE=linux; break; fi
	if [ -n "$SER" ] && [ "$(adbx get-state | tr -d '\r')" = device ]; then MODE=android; break; fi
	if fb_ok; then
		# 又回到 fastboot（坠落）：直接 reboot 一次
		say "back in fastboot at ~$((i*2))s -> reboot"
		fb reboot >/dev/null 2>&1 || true
	fi
	sleep 2
done
say "post-OS mode=$MODE after ~$((i*2))s"
echo "mode=$MODE" > "$OUTDIR/post-mode.txt"

if [ "$MODE" = android ]; then
	say "in stock Android -> adb reboot bootloader + set_active b"
	adbx reboot bootloader > "$OUTDIR/android-recover.txt"
	for i in $(seq 1 30); do sleep 2; fb_ok && break; done
	fb --set-active=b >> "$OUTDIR/android-recover.txt" 2>&1
	fb reboot >> "$OUTDIR/android-recover.txt" 2>&1
	for i in $(seq 1 90); do sleep 2; [ "$(S 'echo up' 6)" = up ] && { MODE=linux; break; }; done
fi

# ---------- 后置态 + logfs ----------
{
	echo "# ssh post $(date -Is)"
	S 'cat /proc/sys/kernel/random/boot_id; uptime -p; cat /proc/cmdline; lsblk -o NAME,SIZE,PARTLABEL | grep -E "boot_b|logfs"'
} > "$OUTDIR/ssh-post.txt" 2>&1
POST_BOOTID=$(sed -n 2p "$OUTDIR/ssh-post.txt")
say "post boot_id=$POST_BOOTID mode=$MODE"

# ---------- 排他判据：UEFI 写入内核 cmdline 的令牌 ----------
#   R43+ 路线 A（EFI-stub 交棒）：elden_bootpath=uefi
#   R55+ 路线 B（ESP 侧 boot.img 由 Mu LinuxLoader 读起）：elden_bootloader=esp  ← 现行
TAG=absent; TAG_B=absent
if [ "$MODE" = linux ]; then
	grep -q "elden_bootpath=uefi"     "$OUTDIR/ssh-post.txt" && TAG=present
	grep -q "elden_bootloader=esp"    "$OUTDIR/ssh-post.txt" && TAG_B=present
fi
say "cmdline elden_bootpath=$TAG elden_bootloader=$TAG_B"
if [ "$MODE" != linux ]; then
	V=NOBOOT
elif [ "$TAG_B" = present ]; then
	V=ESPBOOT_TAGGED          # 路线 B 判据（ESP 侧的 boot.img 才是带 token 的那个）
elif [ "$TAG" = present ]; then
	V=HANDOFF_TAGGED          # 路线 A 判据
else
	# 内核起了但没有令牌 ⇒ 这一次内核不是 UEFI 路径起的（ABL 自己引导 boot_b）
	V=ABLBOOT_NOTAG
fi
say "VERDICT(final)=$V"

if [ "$MODE" = linux ]; then
	say "dump logfs (ABL/PBL log; 单文件 UEFILOG1.TXT，偏移 0x19 起 FAT)"
	S "dd if=/dev/disk/by-partlabel/logfs bs=1M count=8 2>/dev/null" > "$OUTDIR/logfs.img"
	python3 - "$OUTDIR/logfs.img" > "$OUTDIR/abl-log.txt" <<'PY' || true
import sys
img=open(sys.argv[1],'rb').read()
base=img.find(b'MSDOS5.0')
if base<0: sys.exit('no FAT')
base-=3
import struct
b=img[base:base+512]
bps,spc,rsvd,nfat,rootent=struct.unpack_from('<HBHBH',b,11)[0],b[13],struct.unpack_from('<H',b,14)[0],b[16],struct.unpack_from('<H',b,17)[0]
fatsz=struct.unpack_from('<H',b,22)[0]
root_off=base+(rsvd+nfat*fatsz)*bps
def fat(i):
    fat_off=base+rsvd*bps
    o=i*3//2
    v=struct.unpack_from('<H',img,fat_off+o)[0]
    return (v>>4) if i%2 else (v&0xfff)
for k in range(rootent):
    e=img[root_off+k*32:root_off+(k+1)*32]
    if e[0]==0: break
    if e[11] & 0x08: continue          # volume label
    if e[11] & 0x0f == 0x0f: continue  # LFN
    name=e[:8].decode('latin1').strip()+'.'+e[8:11].decode('latin1').strip()
    size=struct.unpack_from('<I',e,28)[0]; clus=struct.unpack_from('<H',e,26)[0]
    if not size: continue
    data_off=root_off+rootent*32
    out=b''
    while clus<0xff8 and len(out)<size:
        out+=img[data_off+(clus-2)*bps:data_off+(clus-1)*bps]
        clus=fat(clus)
    sys.stdout.write(f'===== {name} ({size} B) =====\n')
    sys.stdout.write(out[:size].decode('latin1'))
PY
	say "abl log lines: $(wc -l < "$OUTDIR/abl-log.txt")"
fi

# ---------- record ----------
bash "$ROOT/scripts/trial.sh" record --label "$LABEL" --image "$IMG" --reset warm \
	--deploy fastboot-boot --probe uefi-vis --verdict "$V" --logdir "$OUTDIR" \
	--note "verdict=$V（判据=内核 cmdline elden_bootpath：$TAG）; candidate=$V_CAND; usb-gone=$( [ "$V_CAND" = HANDOFF ] && echo yes || echo no ); post mode=$MODE boot_id=$POST_BOOTID/$(echo "$PRE_BOOTID" | cut -c1-8)" || true

say "===== trial END verdict=$V outdir=$OUTDIR ====="
