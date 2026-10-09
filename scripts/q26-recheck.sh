#!/bin/bash
# q26-recheck.sh — Q26 vk62 单变量复核（主机侧，零写盘 fastboot boot）。
#
# 目的（.pi/plans/2026-10-08-Q26-static-prep.md §2.1）：静态已证 vk62↔vk63 内核+ramdisk
# 逐字节相同、DTB 差量不含 WiFi/PCIe/WCN ⇒ WiFi 行为在静态上必然一致；本脚本实测 vk62
# 的「关联→IPv4 时间 + beacon rx 速率 + bmiss 次数」，坐实「回归点在 vk61→vk62 的
# 内核+initramfs 更换、不在 DTB、不在 vk62→vk63」。
#
# 变量控制（out/boot-elden-vk62.manifest 已核实）：
#   kernel = out/Image-vk47clean.gz（与 vk63 同）、ramdisk = initramfs-full-elden.cpio.gz
#   （与 vk63 同）、DTB = cambist-h1（唯一与 vk63 差 1 处、不含 WiFi）、cmdline 含
#   elden_nocamera=1（相机无关）。fastboot boot 不写 boot_b ⇒ 不动启动次数、可反复。
#
# 设备侧采集经 SSH（主线上联 = usb0 NCM gadget root@192.168.7.1，见 net-up.sh /
# lib-device-lock.sh），**不是 adb**：主线 Alpine 不跑 adbd。adb 仅用于 stock/fastboot 取证。
# WiFi 栈 = NetworkManager + wpa_supplicant -u（net-up.sh 自动连已存 profile）。
#
# usage:
#   scripts/q26-recheck.sh                       # boot out/boot-elden-vk62.img
#   IMG=out/boot-elden-vk63.img scripts/q26-recheck.sh   # 复测对照（vk63 已知干净）
#   SSID="P40 Pro" OBSERVE=180 scripts/q26-recheck.sh
# Env: TAB(=root@192.168.7.1) IMG SSID OBSERVE(观察窗秒,默认180) LOGDIR
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
TAB=${TAB:-root@192.168.7.1}
IMG=${IMG:-$ROOT/out/boot-elden-vk62.img}
SSID=${SSID:-P40 Pro}
OBSERVE=${OBSERVE:-180}
SSHH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes)
S(){ timeout 25 "${SSHH[@]}" "$TAB" "$@" 2>/dev/null; }
TS=$(date +%Y%m%d-%H%M%S)
LOGDIR=${LOGDIR:-$ROOT/logs/q26-recheck-$(basename "$IMG" .img)-$TS}

# 串行化设备访问（与所有设备上脚本共用同一把锁）
. "$(dirname "$0")/lib-device-lock.sh"; device_lock_acquire

[ -f "$IMG" ] || { echo "[q26] 镜像不存在: $IMG（先 ls out/ 核实，勿猜路径）" >&2; exit 1; }
mkdir -p "$LOGDIR"
{ echo "image=$IMG"; sha256sum "$IMG"; } > "$LOGDIR/image.txt"
echo "[q26] logdir=$LOGDIR  img=$IMG"

# 0) 探测 fastboot 设备（不写死序列号）
FB=$(timeout 8 fastboot devices 2>/dev/null | awk 'NR==1{print $1}')
if [ -z "$FB" ]; then
	echo "[q26] 未见 fastboot 设备。若设备在 Linux：ssh $TAB 'sync; setsid /usr/local/sbin/reboot2 bootloader'"
	echo "[q26]   或物理 音量下+电源 进 fastboot；再重跑本脚本。"
	exit 1
fi
echo "[q26] fastboot serial=$FB"
timeout 8 fastboot devices > "$LOGDIR/fastboot-devices.txt" 2>&1

# 1) 零写盘启动指定镜像（fastboot -s 不写死序列号；fastboot boot 不写分区）
echo "[q26] fastboot -s $FB boot $IMG（零写盘）"
timeout 60 fastboot -s "$FB" boot "$IMG" > "$LOGDIR/fastboot-boot.log" 2>&1 || {
	echo "[q26] fastboot boot 失败，见 $LOGDIR/fastboot-boot.log"; exit 1; }

# 2) 等待起机（主线上联 = SSH；ping/SSH 二选一均可达即算起）
echo "[q26] 等待设备起机（SSH $TAB）…"
up=0
for i in $(seq 1 60); do
	sleep 3
	if S true; then echo "[q26] SSH 可达 (~$((i*3))s)"; up=1; break; fi
done
[ "$up" = 1 ] || { echo "[q26] 起机超时——若面板失败(Q28)请冷启后再试；见 $LOGDIR"; exit 1; }
S 'uname -a; cat /proc/cmdline; uptime' > "$LOGDIR/boot-info.txt" 2>&1

# 3) 等待 wlan0 出现并记录 t0（ath12k 由 ath12k-retry.sh 异步加载）
echo "[q26] 等待 wlan0…"
t0=""
for i in $(seq 1 60); do
	if S 'test -e /sys/class/net/wlan0'; then t0=$(S 'date +%s.%N'); break; fi
	sleep 2
done
[ -n "$t0" ] || { echo "[q26] wlan0 未出现（ath12k/WCN 未就绪）——直接看 $LOGDIR/dmesg.txt"; }
echo "[q26] wlan0 t0=$t0"

# 4) 观察窗内轮询「关联 + IPv4」时间
echo "[q26] 观察窗 ${OBSERVE}s：轮询关联状态与 IPv4…"
: > "$LOGDIR/timeline.txt"
assoc_t=""; ip_t=""
t_start=$(date +%s)
while :; do
	now=$(date +%s); el=$((now - t_start))
	[ "$el" -ge "$OBSERVE" ] && break
	link=$(S "iw dev wlan0 link 2>/dev/null | head -1 | tr -d '\r'")
	ip=$(S "ip -4 -o addr show wlan0 2>/dev/null | grep -o 'inet [0-9.]*' | head -1")
	[ -z "$assoc_t" ] && echo "$link" | grep -qiE 'Connected|SSID' && { assoc_t=$now; echo "ASSOC_EL=$((assoc_t - t_start))s link=$link"; }
	[ -z "$ip_t" ] && [ -n "$ip" ] && { ip_t=$now; echo "IPV4_EL=$((ip_t - t_start))s $ip  ← 关联→IPv4 ≈ $((ip_t - ${assoc_t:-t_start}))s"; }
	printf '%s assoc=%s ip=%s (%s)\n' "$el" "${assoc_t:-_}" "${ip:-_}" "$(date +%T)" >> "$LOGDIR/timeline.txt"
	sleep 3
done

# 5) 落盘：station dump（beacon rx）、dmesg(ath12k/beacon/bmiss/flush)、扫描结果数、NM/wpa 状态
S "iw dev wlan0 station dump"        > "$LOGDIR/station-dump.txt" 2>&1
S "dmesg"                            > "$LOGDIR/dmesg.txt" 2>&1
grep -iE 'ath12k|beacon|bmiss|flush transmit|roam|Connection to AP|failed to' "$LOGDIR/dmesg.txt" > "$LOGDIR/dmesg-wifi.txt" 2>&1
S "iw dev wlan0 scan 2>/dev/null | grep -c '^BSS '" > "$LOGDIR/scan-count.txt" 2>&1
S "nmcli -t -f GENERAL.STATE,IP4.ADDRESS device show wlan0; nmcli -t -f SSID,IN-USE dev wifi list | head -20" > "$LOGDIR/nmcli.txt" 2>&1
S "ps -eo args | grep -E 'wpa_supplicant|NetworkManager|iwd' | grep -v grep" > "$LOGDIR/supplicant.txt" 2>&1

# 6) 关键判据摘要
{
	echo "=== Q26 vk62 recheck summary  $(date -Is) ==="
	echo "img_sha=$(awk '/image_sha256=/{print}' "$ROOT/out/$(basename "$IMG" .img).manifest" 2>/dev/null)"
	echo "assoc_el=${assoc_t:+$((assoc_t - t_start))s}  ipv4_el=${ip_t:+$((ip_t - t_start))s}"
	echo "beacon_rx=$(grep -oE 'beacon rx: [0-9]+' "$LOGDIR/station-dump.txt" | head -1)"
	echo "bmiss_lines=$(grep -icE 'bmiss|BEACON_MISS|failed to flush transmit|Connection to AP .* lost' "$LOGDIR/dmesg-wifi.txt")"
	echo "scan_bss=$(cat "$LOGDIR/scan-count.txt" 2>/dev/null)"
} | tee "$LOGDIR/SUMMARY.txt"
echo "[q26] 完成。判读见 .pi/plans/2026-10-09-Q26-vk62-recheck-runbook.md 判定表；日志 $LOGDIR"
