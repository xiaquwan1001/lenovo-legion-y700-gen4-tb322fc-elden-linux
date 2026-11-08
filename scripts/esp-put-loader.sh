#!/bin/bash
# esp-put-loader.sh — 把一份 Loader.efi（Mu LinuxLoader 变体）放到设备 ESP 的 /EFI/elden/，
#                    并（可选）覆盖 ESP 上的 /boot/boot.img。零分区表写入，只动 FAT 文件。
#
# 为什么需要它（G1-29 路线 B）：每次迭代要换 ESP 上的 Loader.efi / boot.img，
# 手工 mount→cp→sync→umount 曾留下 FAT dirty bit（2026-11-08 实测），所以把
# 「同步 + 只读校验 + fsck」固定进脚本。
#
# 用法：
#   scripts/esp-put-loader.sh --loader out/espboot-20261108/Loader-r56.efi
#   scripts/esp-put-loader.sh --loader <efi> --boot-img out/espboot-20261108/boot-elden-vk184-espb.img
#   scripts/esp-put-loader.sh --verify                 # 只读：列 ESP 内容 + sha
#   scripts/esp-put-loader.sh --loader <efi> --dry-run
#
# 判据（脚本自己核）：
#   1) 写后读回 sha 与主机件逐字节一致；
#   2) umount 后 `fsck.vfat -n` 干净（不自动修，脏就报错并给出修复命令）；
#   3) ESP 剩余空间 ≥ 待写总大小 + 16 MiB。
#
# 不做什么：不建 ESP、不改 GPT、不 fastboot、不重启。
set -uo pipefail

TAB=${TAB:-root@192.168.7.1}
ESP_PART=${ESP_PART:-/dev/sda18}
ESP_MNT=${ESP_MNT:-/mnt/esp}
ESP_LABEL=${ESP_LABEL:-ELDENESP}
LOADER=
BOOTIMG=
MODE=put
DRY=0

say() { echo "[esp-put] $*" >&2; }
die() { echo "[esp-put] ERROR: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
	case "$1" in
		--loader)   LOADER=$2; shift 2;;
		--boot-img) BOOTIMG=$2; shift 2;;
		--tab)      TAB=$2; shift 2;;
		--verify)   MODE=verify; shift;;
		--dry-run)  DRY=1; shift;;
		-h|--help)  sed -n '2,24p' "$0"; exit 0;;
		*) die "unknown arg: $1";;
	esac
done

SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"
$SSH true 2>/dev/null || die "ssh 不通：$TAB（设备是否在 Linux？）"

# ---- 只读模式：列内容 + sha ------------------------------------------------
if [ "$MODE" = verify ]; then
	# 注意：脏 FAT 上 `mount -o ro` 会直接失败（"would change RO state"），
	# 所以先 fsck -n 报状态，再用 rw 短暂挂载读取、随即 umount。
	$SSH "
	  set -e
	  fsck.vfat -n $ESP_PART 2>&1 | tail -2 || true
	  if ! mountpoint -q $ESP_MNT; then mount $ESP_PART $ESP_MNT; fi
	  ls -l $ESP_MNT/EFI/elden $ESP_MNT/boot 2>/dev/null || true
	  sha256sum $ESP_MNT/EFI/elden/*.efi $ESP_MNT/boot/*.img 2>/dev/null || true
	  df -h $ESP_MNT | tail -1
	  sync; umount $ESP_MNT 2>/dev/null || true
	"
	exit $?
fi

[ -n "$LOADER" ] || die "缺 --loader（或用 --verify 只读检查）"
[ -r "$LOADER" ] || die "读不到 $LOADER"
L_SHA=$(sha256sum "$LOADER" | awk '{print $1}')
L_SZ=$(stat -c %s "$LOADER")
TOTAL=$L_SZ
if [ -n "$BOOTIMG" ]; then
	[ -r "$BOOTIMG" ] || die "读不到 $BOOTIMG"
	B_SHA=$(sha256sum "$BOOTIMG" | awk '{print $1}')
	B_SZ=$(stat -c %s "$BOOTIMG")
	TOTAL=$((TOTAL + B_SZ))
fi
say "loader=$LOADER ($L_SZ B, ${L_SHA:0:16}…)${BOOTIMG:+ boot=$BOOTIMG ($B_SZ B, ${B_SHA:0:16}…)}"

if [ "$DRY" = 1 ]; then
	say "干跑：将写入 $ESP_MNT/EFI/elden/Loader.efi${BOOTIMG:+ 与 $ESP_MNT/boot/boot.img}"
	exit 0
fi

# ---- 1. 前置：空间检查 + 清掉可能残留的挂载 ---------------------------------
$SSH "
  set -e
  umount $ESP_MNT 2>/dev/null || true
  mountpoint -q $ESP_MNT && { echo 'ESP 仍被占用' >&2; exit 1; }
  mount $ESP_PART $ESP_MNT
  avail=\$(df --output=avail -k $ESP_MNT | tail -1)
  echo \"[esp-put] avail=\${avail}KiB need=$(( (TOTAL/1024) + 16384 ))KiB\"
  [ \"\$avail\" -ge $(( (TOTAL/1024) + 16384 )) ] || { echo '[esp-put] ERROR: ESP 空间不足' >&2; umount $ESP_MNT; exit 1; }
  mkdir -p $ESP_MNT/EFI/elden $ESP_MNT/boot
" || die "ESP 挂载/空间检查失败"

# ---- 2. 传文件（先落到 /tmp 再 cp，避免 scp 直接写 FAT 中断留脏）-----------
scp -q -o BatchMode=yes -o StrictHostKeyChecking=no "$LOADER" "$TAB:/tmp/esp-loader.efi" || die "scp loader 失败"
if [ -n "$BOOTIMG" ]; then
	scp -q -o BatchMode=yes -o StrictHostKeyChecking=no "$BOOTIMG" "$TAB:/tmp/esp-boot.img" || die "scp boot.img 失败"
fi

$SSH "
  set -e
  cp -f /tmp/esp-loader.efi $ESP_MNT/EFI/elden/Loader.efi
  ${BOOTIMG:+cp -f /tmp/esp-boot.img $ESP_MNT/boot/boot.img}
  sync
  echo '--- 读回校验 ---'
  sha256sum $ESP_MNT/EFI/elden/Loader.efi${BOOTIMG:+ $ESP_MNT/boot/boot.img}
  rm -f /tmp/esp-loader.efi${BOOTIMG:+ /tmp/esp-boot.img}
  sync
  umount $ESP_MNT
" || die "写入/卸载失败"

# ---- 3. 后置：sha 对账 + FAT 干净 ------------------------------------------
GOT=$($SSH "mount $ESP_PART $ESP_MNT >/dev/null 2>&1; sha256sum $ESP_MNT/EFI/elden/Loader.efi | awk '{print \$1}'; sync; umount $ESP_MNT 2>/dev/null || true")
[ "$GOT" = "$L_SHA" ] || die "Loader.efi 读回 sha 不一致：host=$L_SHA dev=$GOT"
if [ -n "$BOOTIMG" ]; then
	GOTB=$($SSH "mount $ESP_PART $ESP_MNT >/dev/null 2>&1; sha256sum $ESP_MNT/boot/boot.img | awk '{print \$1}'; sync; umount $ESP_MNT 2>/dev/null || true")
	[ "$GOTB" = "$B_SHA" ] || die "boot.img 读回 sha 不一致：host=$B_SHA dev=$GOTB"
fi
say "sha 对账 PASS"

FSCK=$($SSH "fsck.vfat -n $ESP_PART 2>&1 | tail -2")
case "$FSCK" in
	*"Leaving filesystem unchanged"*) say "fsck 干净" ;;
	*) echo "$FSCK" >&2; die "FAT 不干净（先跑：ssh $TAB 'fsck.vfat -a $ESP_PART'）" ;;
esac

say "完成。下一步（需用户批准上机）：fastboot boot <p59 镜像>，GRUB 单条目会自动 chainload 它"
say "  回退：scripts/esp-put-loader.sh --loader out/espboot-20261108/Loader.efi   # 旧件"
