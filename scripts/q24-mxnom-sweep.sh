#!/bin/bash
# q24-mxnom-sweep.sh — Q24 熄屏×相机 ≥9 轮存活扫掠（vk71-mxnom，零写盘 fastboot boot）。
#
# 目标（.pi/plans/2026-10-09-Q24-变体与G1-34资产.md §1 / TASKS.md Q24=G1-22=G1-33）：
#   根因 = 单模块 cambistmclkcc-sm8750 × DT 电源域，熄屏触发间歇性硬复位（pstore/kmsg 无痕）。
#   vk71-mxnom = 现役 H2 的单变量差：把 cambist 的 MX corner 从 low_svs 抬到 nom
#   （power-domains=<&rpmhpd RPMHPD_MX> + required-opps nom level256）。cmdline 故意不含
#   elden_nocamera=1 ⇒ 相机模块照常加载 + 真实熄屏（与 vk63 规避态相反）。
#
# 每轮 = 保证跑该镜像 → 相机栈在位 → 熄屏(ScreenSaver.SetActive true) → 长时窗 →
#   唤醒(SetActive false) → 相机探针计数 → 存活判定。掉电 = 那条「熄屏后 echo ALIVE」
#   sentinel 不返回（硬复位、无 panic、pstore 无痕），与 sleep-sweep.sh 同判据。
#
# 变量控制（out/boot-elden-vk71-mxnom.manifest 已核实）：
#   image_sha256=877eeba3…；kernel=Image-vk47clean（与 vk63 同）、ramdisk=initramfs-full-elden
#   （与 vk63 同）、DTB=cambist-mxnom（dtb_sha 1da55c99，唯一变量）、cmdline 无 elden_nocamera。
#
# 交替对照建议：对 IMG=out/boot-elden-vk71-mxc.img 与 IMG=out/boot-elden-vk63.img 各跑同样 ≥9 轮，
#   与 vk71-mxnom 同口径比较（TASKS §6 下3 / Q24 plan §1.2）。
#
# usage:
#   scripts/q24-mxnom-sweep.sh [轮数=9]
#   IMG=out/boot-elden-vk63.img scripts/q24-mxnom-sweep.sh 9
# Env: TAB(=root@192.168.7.1) IMG BLANK_WAIT(熄屏长时窗秒,默认90) LOGDIR
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
TAB=${TAB:-root@192.168.7.1}
IMG=${IMG:-$ROOT/out/boot-elden-vk71-mxnom.img}
N=${1:-9}
BLANK_WAIT=${BLANK_WAIT:-90}
SSHH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes)
S(){ timeout $((BLANK_WAIT + 30)) "${SSHH[@]}" "$TAB" "$@" 2>/dev/null; }
Q(){ timeout 20 "${SSHH[@]}" "$TAB" "$@" 2>/dev/null; }          # 短命令
booted_into_variant=0
TS=$(date +%Y%m%d-%H%M%S)
LOGDIR=${LOGDIR:-$ROOT/logs/q24-sweep-$(basename "$IMG" .img)-$TS}

. "$(dirname "$0")/lib-device-lock.sh"; device_lock_acquire
[ -f "$IMG" ] || { echo "[q24] 镜像不存在: $IMG（先 ls out/ 核实，勿猜路径）" >&2; exit 1; }
mkdir -p "$LOGDIR"; { echo "image=$IMG"; sha256sum "$IMG"; echo "rounds=$N blank_wait=$BLANK_WAIT"; } > "$LOGDIR/setup.txt"
RES="$LOGDIR/results.tsv"; printf 'round\tverdict\tcam_media\tcam_video\tcambist\tuptime_after\tts\n' > "$RES"
echo "[q24] logdir=$LOGDIR  img=$IMG  N=$N"

fastboot_serial(){ timeout 8 fastboot devices 2>/dev/null | awk 'NR==1{print $1}'; }
boot_variant(){   # 每轮都重新 fastboot boot，确保当前跑的确实是该变体（fastboot boot 不写盘）
	local fb; fb=$(fastboot_serial)
	[ -n "$fb" ] || return 1
	echo "    (fastboot -s $fb boot $(basename "$IMG"))"
	timeout 60 fastboot -s "$fb" boot "$IMG" >/dev/null 2>&1 || return 1
	for i in $(seq 1 60); do sleep 3; Q true && return 0; done
	return 1
}
# 相机栈在位（vk71-mxnom 无 elden_nocamera ⇒ 开机自动加载；此处幂等补加载 + 探针）
cam_probe(){ Q 'sh /usr/local/sbin/camera-modules-load.sh >/dev/null 2>&1;
	echo "media=$(ls /dev/media* 2>/dev/null|wc -l) video=$(ls /dev/video* 2>/dev/null|wc -l) cambist=$(lsmod|grep -c cambistmclkcc)"'; }
# 真实熄屏 + 长时窗 + sentinel；返回 0=存活(ALIVE) 非0=掉电/失联
blank_round(){
	# sentinel：熄屏 → 等待 BLANK_WAIT → 唤醒 → echo ALIVE（掉电则这条 ssh 永不返回）
	local r
	r=$(Q "P=\$(pidof phoc || pidof phosh);
		export DBUS_SESSION_BUS_ADDRESS=\$(tr '\0' '\n' </proc/\$P/environ|sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p');
		export XDG_RUNTIME_DIR=/run/user/0;
		gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true >/dev/null 2>&1;
		sleep $BLANK_WAIT;
		gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive false >/dev/null 2>&1;
		sleep 2; echo ALIVE")
	[ "${r//$'\r'/}" = "ALIVE" ]
}

for r in $(seq 1 "$N"); do
	# 每轮保证跑变体（上一轮若掉电 → 落回 boot_b；若 fastboot → 重新 boot）
	if ! Q true || [ "$booted_into_variant" = 0 ]; then
		boot_variant && booted_into_variant=1 || { echo "R$r NOBOOT"; printf '%s\tNOBOOT\t-\t-\t-\t-\t%s\n' "$r" "$(date -Is)" >>"$RES"; booted_into_variant=0; continue; }
	fi
	cp=$(cam_probe)
	echo "R$r camera: $cp"
	if blank_round; then
		up=$(Q "cut -d' ' -f1 /proc/uptime" | tr -d '\r')
		echo "R$r ALIVE  uptime=$up"
		printf '%s\tALIVE\t%s\t%s\t%s\t%s\n' "$r" "$(echo "$cp"|grep -oE 'media=[0-9]+')" "$(echo "$cp"|grep -oE 'video=[0-9]+')" "$(echo "$cp"|grep -oE 'cambist=[0-9]+')" "$up" >>"$RES"
		booted_into_variant=1
	else
		echo "R$r DEAD(掉电/硬复位)"
		printf '%s\tDEAD\t%s\t%s\t%s\t-\n' "$r" "$(echo "$cp"|grep -oE 'media=[0-9]+')" "$(echo "$cp"|grep -oE 'video=[0-9]+')" "$(echo "$cp"|grep -oE 'cambist=[0-9]+')" >>"$RES"
		booted_into_variant=0   # 掉电后设备重启到 boot_b，下一轮需重新 fastboot boot
	fi
done

ALIVE=$(awk -F'\t' 'NR>1&&$2=="ALIVE"' "$RES" | wc -l)
DEAD=$(awk  -F'\t' 'NR>1&&$2=="DEAD"'   "$RES" | wc -l)
NOBOOT=$(awk -F'\t' 'NR>1&&$2=="NOBOOT"' "$RES" | wc -l)
{ echo "=== Q24 sweep $(basename "$IMG" .img)  $(date -Is) ==="
  echo "rounds=$N ALIVE=$ALIVE DEAD=$DEAD NOBOOT=$NOBOOT  (survival=$ALIVE/$N)"
  echo "判读：.pi/plans/2026-10-09-Q24-mxnom-sweep-runbook.md（阈值/基线）"
} | tee "$LOGDIR/SUMMARY.txt"
