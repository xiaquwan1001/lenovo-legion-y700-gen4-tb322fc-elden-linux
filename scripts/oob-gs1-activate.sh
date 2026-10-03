#!/bin/sh
# oob-gs1-activate.sh — 在设备上把 USB gadget 重新 bind，启用第二个 ACM(acm.GS1)
# 作为带外 root shell 通道，并自愈 NCM 网络（重启 gadget 会打断 usb0/SSH）。
#
# 用法（设备上 root 执行；建议 detach 运行，因为执行中会瞬时断网）：
#   nohup setsid /root/wd/oob-gs1.sh >/dev/null 2>&1 &
#
# 前提：/usr/local/sbin/usb-gadget 与 /init 已更新为含 acm.GS1 的版本
#       （见 initramfs/usb-gadget、initramfs/init）。
exec >>/root/wd/oob-gs1.log 2>&1
echo "[oob] $(date) restarting gadget"
sleep 1
/usr/local/sbin/usb-gadget restart

# 自愈 NCM：usb0 会随重 bind 出现/消失，重设 IP + DHCP
i=0
while [ ! -d /sys/class/net/usb0 ] && [ $i -lt 150 ]; do sleep 0.1; i=$((i+1)); done
ip link set usb0 up 2>/dev/null
ip addr replace 192.168.7.1/24 dev usb0 2>/dev/null
killall udhcpd 2>/dev/null
sleep 0.3
udhcpd -S /etc/udhcpd.conf 2>/dev/null

# 等 GS1 tty 出现，挂一个 root shell
j=0
while [ ! -c /dev/ttyGS1 ] && [ $j -lt 150 ]; do sleep 0.1; j=$((j+1)); done
setsid sh -c "exec sh </dev/ttyGS1 >/dev/ttyGS1 2>&1" &
echo "[oob] done ttys: $(ls /dev/ttyGS* 2>/dev/null | tr '\n' ' ') usb0=$(cat /sys/class/net/usb0/operstate 2>/dev/null)"
