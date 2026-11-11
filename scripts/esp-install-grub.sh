#!/usr/bin/env bash
# esp-install-grub.sh — 把主机侧造好的 standalone GRUB（arm64-efi）装上 ESP 的 \EFI\BOOT\BOOTAA64.EFI
#
# 为什么单独一个脚本：这一步会**改变下次开机的引导路径**（ESP-first），
#   所以默认只 stage（放到 \EFI\grub\ 下不改 BOOTAA64.EFI），要显式 --activate 才切换。
#
# 用法（主机侧）：
#   scripts/esp-install-grub.sh                       # stage：scp 到 \EFI\grub\grub-<tag>.efi，只读其它
#   scripts/esp-install-grub.sh --activate            # 切成 BOOTAA64.EFI（先备份为 BOOTAA64.EFI.<tag>.bak）
#   scripts/esp-install-grub.sh --rollback            # 用最近一次备份回滚 BOOTAA64.EFI
# 选项：--efi FILE（默认 build/grub-arm64/grubaa64.efi）、--tag NAME（默认取自 efi 的 sha 前 8 位）、
#       --device root@IP（默认 root@192.168.7.1）、--esp-part /dev/sda18
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
EFI=$ROOT/build/grub-arm64/grubaa64.efi
TAG=
DEVICE=root@192.168.7.1
ESP=/dev/sda18
ACT=stage
SSHOPT=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes)

while [ $# -gt 0 ]; do
	case "$1" in
		--efi) EFI=$2; shift 2;;
		--tag) TAG=$2; shift 2;;
		--device) DEVICE=$2; shift 2;;
		--esp-part) ESP=$2; shift 2;;
		--activate) ACT=activate; shift;;
		--rollback) ACT=rollback; shift;;
		-h|--help) sed -n '2,16p' "$0"; exit 0;;
		*) echo "esp-install-grub: 未知参数 $1" >&2; exit 1;;
	esac
done

if [ "$ACT" != rollback ]; then
	[ -r "$EFI" ] || { echo "读不到 $EFI" >&2; exit 1; }
	sha=$(sha256sum "$EFI" | cut -d' ' -f1)
	[ -n "$TAG" ] || TAG=${sha:0:8}
	echo "[esp] 件 $EFI  sha256=$sha  tag=$TAG"
	scp -q "${SSHOPT[@]}" "$EFI" "$DEVICE:/tmp/grub-$TAG.efi" || exit 1
fi

ssh "${SSHOPT[@]}" "$DEVICE" "set -e
mkdir -p /mnt/esp
mountpoint -q /mnt/esp || mount $ESP /mnt/esp
cd /mnt/esp

if [ '$ACT' = rollback ]; then
	bak=\$(ls -t EFI/BOOT/BOOTAA64.EFI.*.bak 2>/dev/null | head -1)
	[ -n \"\$bak\" ] || { echo '没有 .bak 可回滚'; exit 1; }
	cp -a \"\$bak\" EFI/BOOT/BOOTAA64.EFI
	echo \"[esp] 已回滚 BOOTAA64.EFI ← \$bak\"
	sha256sum EFI/BOOT/BOOTAA64.EFI
	exit 0
fi

cp /tmp/grub-$TAG.efi EFI/grub/grub-$TAG.efi
sha256sum EFI/grub/grub-$TAG.efi
if [ '$ACT' = activate ]; then
	[ -f EFI/BOOT/BOOTAA64.EFI ] && cp -a EFI/BOOT/BOOTAA64.EFI EFI/BOOT/BOOTAA64.EFI.$TAG.bak
	cp EFI/grub/grub-$TAG.efi EFI/BOOT/BOOTAA64.EFI
	echo '[esp] 已切换 BOOTAA64.EFI'
	sha256sum EFI/BOOT/BOOTAA64.EFI
else
	echo '[esp] 仅 stage（未改 BOOTAA64.EFI）。要激活：本脚本加 --activate'
fi
sync
umount /mnt/esp
" || exit 1
