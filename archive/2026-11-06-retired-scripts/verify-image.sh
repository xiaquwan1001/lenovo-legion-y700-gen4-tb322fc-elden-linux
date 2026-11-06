#!/bin/bash
# Confirm every fix is present in the Ubuntu image before it is archived.
R=${1:-/mnt/rootfs}
LIB=lib/aarch64-linux-gnu
ok() { printf '  [ok]   %s\n' "$1"; }
no() { printf '  [FAIL] %s\n' "$1"; }

echo "== ssh"
[ ! -e "$R/etc/systemd/system/ssh.service.requires/ssh.socket" ] &&
	ok "ssh.socket not required by ssh.service" || no "ssh.socket still required"
[ ! -e "$R/etc/systemd/system/sockets.target.wants/ssh.socket" ] &&
	ok "ssh.socket not enabled" || no "ssh.socket still enabled"
[ -e "$R/etc/systemd/system/multi-user.target.wants/ssh.service" ] &&
	ok "ssh.service enabled" || no "ssh.service missing"
[ -e "$R/etc/systemd/system/ssh.service.d/10-elden.conf" ] &&
	ok "ssh drop-in" || no "ssh drop-in missing"

echo "== usb network"
[ -L "$R/usr/local/libexec/udhcpd" ] &&
	ok "udhcpd symlink -> $(readlink "$R/usr/local/libexec/udhcpd")" || no "udhcpd symlink missing"
grep -q 'exec /usr/local/libexec/udhcpd' "$R/usr/local/sbin/elden-usb-network" &&
	ok "launcher calls udhcpd by applet name" || no "launcher still calls elden-busybox"

echo "== mesa"
[ -f "$R/opt/mesa-a830/$LIB/libgallium-26.1.6.so" ] &&
	ok "libgallium 26.1.6" || no "libgallium missing"
[ -f "$R/opt/mesa-a830/$LIB/libvulkan_freedreno.so" ] &&
	ok "turnip" || no "turnip missing"
[ -L "$R/opt/mesa-a830/runtime/libgallium-26.1.6.so" ] &&
	ok "libgallium reachable via LD_LIBRARY_PATH" || no "libgallium not in runtime/"
[ -f "$R/opt/mesa-a830/runtime/libxcb-keysyms.so.1.0.0" ] &&
	ok "libxcb-keysyms bundled" || no "libxcb-keysyms missing"
[ -f "$R/opt/mesa-a830/share/vulkan/icd.d/freedreno_icd.aarch64.json" ] &&
	ok "vulkan icd" || no "vulkan icd missing"
grep -q 'VK_DRIVER_FILES=.*mesa-a830' "$R/etc/environment" &&
	ok "session env points at mesa-a830" || no "session env not set"
[ -e "$R/etc/systemd/system/gdm3.service.d/50-mesa-a830.conf" ] &&
	ok "gdm3 drop-in" || no "gdm3 drop-in missing"
[ -e "$R/etc/systemd/system/gdm.service.d/50-mesa-a830.conf" ] &&
	ok "gdm drop-in" || no "gdm drop-in missing"

echo "== desktop"
grep -q 'AutomaticLogin=elden' "$R/etc/gdm3/custom.conf" &&
	ok "autologin elden" || no "autologin missing"
[ -f "$R/var/lib/AccountsService/users/elden" ] &&
	ok "accountsservice session" || no "accountsservice missing"

echo "== sizes"
du -sh "$R/opt/mesa-a830" 2>/dev/null
df -h "$R" | tail -1
