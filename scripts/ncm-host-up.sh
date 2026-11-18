#!/bin/sh
# ncm-host-up.sh — 主机侧把「设备的 USB-NCM 网卡」配成 192.168.7.3/24（幂等，需 root）。
#
# 为什么需要：设备 gadget 固定 192.168.7.1/24（/usr/local/sbin/usb-gadget + /etc/udhcpd.conf），
# 主机侧接口名是 enx021e5eede102（cdc_ncm 按 MAC 派生），且 **每次设备重启网卡都会重建**
# ⇒ 之前 add 的地址随之消失（2026-11-19 实测两次踩到，表现为「ping 不通、以为系统没起来」）。
#
# 用法：
#   sudo scripts/ncm-host-up.sh            # 配地址 + 打印 ssh 提示
#   sudo scripts/ncm-host-up.sh --check    # 只报告（有地址则 rc=0）
#
# 说明：地址用 .3 而不是 .2 —— 设备侧 udhcpd 的池是 192.168.7.2–20，静态 .2 可能和租约撞。
set -u
MAC_IFACE=${MAC_IFACE:-02:1e:5e:ed:e1:02}   # usb-gadget 里写死的 host_addr
ADDR=${ADDR:-192.168.7.3/24}
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

iface=""
for i in /sys/class/net/*; do
	n=$(basename "$i")
	[ "$n" = lo ] && continue
	m=$(cat "$i/address" 2>/dev/null) || continue
	[ "$m" = "$MAC_IFACE" ] && { iface=$n; break; }
done
[ -n "$iface" ] || { echo "MISSING: 没有 MAC=$MAC_IFACE 的网卡（设备 gadget 没枚举？lsusb | grep 1d6b:0104）" >&2; exit 1; }

have=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{print $4}')
if [ -n "$have" ]; then
	echo "OK      $iface 已有 $have"
	[ "$CHECK" = 1 ] && exit 0
else
	echo "当前    $iface 无 IPv4"
	[ "$CHECK" = 1 ] && { echo "WANT: $ADDR" >&2; exit 1; }
	ip link set "$iface" up || exit 1
	ip addr add "$ADDR" dev "$iface" || exit 1
	echo "ADDED   $iface $ADDR"
fi
echo "下一步: ssh -o StrictHostKeyChecking=no root@192.168.7.1"
echo "若 ssh 拒连但 ping 通 ⇒ 设备侧 sshd 没起（/init 的 lifeline 或 systemd ssh.service）"
