#!/bin/sh
# q28-disp-ab-sample.sh — 取「一发」Q28 显示初始化补丁 A/B 冷起样本。
#
# 背景：armadaos-freedom 的 0154（dispcc probe 复位活显示 BCR）+ 0155（DSI PHY
# DIGTOP_PWRDN_B 随 PLL bias 置/清），均只对 lenovo,elden 生效。见
# reference/upstream-armadaos-freedom/README.md §5.1、reports/q28-disp-init-ab-20261022.md
#
# 用法：
#   scripts/q28-disp-ab-sample.sh base|exp|only0154|only0155|daily|exp73|o155_73|daily73 ["备注"]
#
# 前提（物理动作只能由用户执行，冷起必须真实 POR）：
#   1. 长按电源键 ~10 s 关机（真断电；`reboot bootloader` 是暖复位，会粘 NOCARD，不能当冷起台架）
#   2. 按住音量键 + 短按电源开机 → 进 fastboot（`fastboot devices` 能看到 HA2EXB0E）
#   3. 再跑本脚本（--deploy fastboot-boot 零写盘）
#
# 产出：reports/trials/<UTC>-q28disp-<arm>.json + 同目录 dmesg/probe/env.txt，
#       并在 reports/trials/index.tsv 追加一行。
set -eu
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
# 设备 usb0 的 IPv6 链路本地地址由 gadget MAC 02:1e:5e:ed:e1:01 推出，固定不变。
TAB=${TAB:-root@fe80::1e:5eff:feed:e101%enx021e5eede102}

arm=${1:-}
note=${2:-}
case "$arm" in
	base)    label=q28disp-base;     img=$ROOT/out/boot-elden-vk137-q28base.img ;;
	only0154) label=q28disp-0154only; img=$ROOT/out/boot-elden-vk144-q28only0154.img ;;
	exp)     label=q28disp-exp;      img=$ROOT/out/boot-elden-vk138-q28disp.img ;;
	only0155) label=q28disp-0155only; img=$ROOT/out/boot-elden-vk139-q28only0155.img ;;
	daily)   label=q28disp-daily;  img=$ROOT/out/boot-elden-vk127.img ;;
	exp73)   label=q28disp-exp73;  img=$ROOT/out/boot-elden-vk142-q28disp73dt.img ;;
	o155_73) label=q28disp-0155only73; img=$ROOT/out/boot-elden-vk143-q28-73-0155only.img ;;
	daily73) label=q28disp-daily73; img=$ROOT/out/boot-elden-vk145-q28daily.img ;;
	*) echo "usage: $0 base|exp|only0154|only0155|daily|exp73|o155_73|daily73 [note]" >&2; exit 2 ;;
esac
[ -f "$img" ] || { echo "缺镜像 $img（见 reports/q28-disp-init-ab-20261022.md 重建配方）" >&2; exit 2; }

if ! fastboot devices 2>/dev/null | grep -q .; then
	echo "❌ 设备不在 fastboot：先物理断电，再按住音量键 + 电源开机进 fastboot。" >&2
	exit 1
fi

echo "[sample] arm=$arm image=$(basename "$img")  —— fastboot boot（零写盘）"
exec env TAB="$TAB" bash "$ROOT/scripts/trial.sh" run \
	--label "$label" --image "$img" --reset por --deploy fastboot-boot \
	--probe q28 --force --note "0154+0155 冷起 A/B；$note"
