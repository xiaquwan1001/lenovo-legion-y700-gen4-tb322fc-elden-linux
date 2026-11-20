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
DEVICE=${DEVICE:-${TAB:-root@192.168.7.1}}
ESP=/dev/sda18
ACT=stage
SSHOPT=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes
         -o ConnectTimeout=8 -o ServerAliveInterval=15 -o ServerAliveCountMax=3)
# 2026-11-18 审计 R4：设备侧 mount/cp/sha 都可能长时间不返回，一律套 timeout。
STMO=${STMO:-180}
# sha_direct <文件>：**O_DIRECT 直读**算 sha256（绕过页缓存），工具回退 buffered 时 shell 侧
# 兜底并打 WARN。为什么必须 O_DIRECT（2026-11-20 实测）：页缓存被污染时 buffered 连读多次
# 「稳定但错」（v1 件 637a9965… vs 真值 e3d0d26f…），旧「双 sha256 硬门」抓不到。
# 工具：scripts/odirect-sha.py（--tsv 第 3 列 = sha）；取证：reports/odirect-sha-gate-20261120.md。
ODIRECT_SHA=${ODIRECT_SHA:-$(cd "$(dirname "$0")/.." && pwd)/scripts/odirect-sha.py}
sha_direct() {
	local f=$1 out v
	[ -n "$f" ] && [ -e "$f" ] || { printf '%s\n' ""; return 0; }
	out=$(timeout -k 10 1800 python3 "$ODIRECT_SHA" --tsv "$f" 2>&1)
	v=$(printf '%s\n' "$out" | awk -F'\t' 'NR==1{print $3}')
	if [ -z "$v" ] || [ "${#v}" != 64 ]; then
		v=$(sha256sum "$f" | cut -d' ' -f1)
		echo "WARN sha_direct: $f 未走 O_DIRECT（$out），退回 buffered（结果可能被页缓存污染）" >&2
	fi
	printf '%s\n' "$v"
}


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
	sha=$(sha_direct "$EFI")
	[ -n "$TAG" ] || TAG=${sha:0:8}
	echo "[esp] 件 $EFI  sha256=$sha  tag=$TAG"
	timeout "$STMO" scp -q "${SSHOPT[@]}" "$EFI" "$DEVICE:/tmp/grub-$TAG.efi" || exit 1
fi

# 2026-11-18 审计 R4：写引导件前先核对 ESP 真的是那个 vfat 分区（GPT 重排后
# /dev/sda18 可能已是别的分区），并留够 8 MiB；否则 cp 半途 ENOSPC 把
# BOOTAA64.EFI 写残 —— ESP-first 路径同时失去旧件与完整新件 = 设备无引导。
timeout "$STMO" ssh "${SSHOPT[@]}" "$DEVICE" "set -e
[ -b $ESP ] || { echo '[esp] ERROR: $ESP 不是块设备（GPT 变了？）' >&2; exit 1; }
blkid -s TYPE -o value $ESP | grep -qx vfat || { echo '[esp] ERROR: $ESP 不是 vfat，拒绝写引导' >&2; exit 1; }
" || exit 1

timeout "$STMO" ssh "${SSHOPT[@]}" "$DEVICE" "set -e
mkdir -p /mnt/esp
mountpoint -q /mnt/esp || mount $ESP /mnt/esp
cd /mnt/esp
avail=\$(df -k . | awk 'NR==2{print \$4}')
[ \"\$avail\" -ge 8192 ] || { echo \"[esp] ERROR: ESP 剩余 \${avail}KiB < 8MiB\" >&2; umount /mnt/esp; exit 1; }

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
	# 先落 .new 再 rename：直接 cp 覆盖 BOOTAA64.EFI，掉电/ENOSPC 会留下半个引导件。
	cp EFI/grub/grub-$TAG.efi EFI/BOOT/BOOTAA64.EFI.new
	sync
	mv -f EFI/BOOT/BOOTAA64.EFI.new EFI/BOOT/BOOTAA64.EFI
	echo '[esp] 已切换 BOOTAA64.EFI'
	sha256sum EFI/BOOT/BOOTAA64.EFI
else
	echo '[esp] 仅 stage（未改 BOOTAA64.EFI）。要激活：本脚本加 --activate'
fi
sync
umount /mnt/esp
" || exit 1

# 写后校验（PITFALLS #669 同族：退出码 0 ≠ 内容对）：设备侧 sha 必须等于主机件 sha。
# 旧版只把 sha256sum 打在屏幕上，从不与主机 $sha 比对。
if [ "$ACT" = activate ]; then
	got=$(timeout "$STMO" ssh "${SSHOPT[@]}" "$DEVICE" "set -e
	  mountpoint -q /mnt/esp || mount $ESP /mnt/esp
	  sha256sum /mnt/esp/EFI/BOOT/BOOTAA64.EFI | awk '{print \$1}'
	  sync; umount /mnt/esp" 2>/dev/null | tr -d '\r')
	[ "$got" = "$sha" ] || { echo "[esp] FAIL: BOOTAA64.EFI 读回 sha=$got ≠ 主机 $sha" >&2
		echo "      回退：scripts/esp-install-grub.sh --rollback" >&2; exit 1; }
	echo "[esp] 读回 sha 一致（$got）"
fi
