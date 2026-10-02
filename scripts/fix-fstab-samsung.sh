#!/bin/bash
# fix-fstab-samsung.sh — 给 /mnt/Samsung 的 fstab 条目补 nofail（掉盘不卡开机）
# 用法： sudo bash ~/y700-elden/scripts/fix-fstab-samsung.sh
set -euo pipefail
UUID=1847ae03-b2ee-4ed4-af0e-ffd8b50a440b
MP=/mnt/Samsung
[ "$(id -u)" -eq 0 ] || { echo "请用 root：sudo bash $0"; exit 1; }
command -v findmnt >/dev/null

echo "== 当前条目 =="
grep -n "$UUID" /etc/fstab || { echo "❌ /etc/fstab 里没有 UUID=$UUID，先确认挂载方式"; exit 1; }

if grep "$UUID" /etc/fstab | grep -q nofail; then
  echo "✅ 已含 nofail，无需修改"
  exit 0
fi

cp -a /etc/fstab "/etc/fstab.bak-nofail-$(date +%Y%m%d-%H%M%S)"
echo "== 已备份 /etc/fstab.bak-nofail-* =="

# 只改这块盘的行的第 4 列（挂载选项），defaults -> defaults,nofail,x-systemd.device-timeout=10
sed -i "/UUID=$UUID/ s#\(\s\)defaults\(\s\)#\1defaults,nofail,x-systemd.device-timeout=10\2#" /etc/fstab

echo "== 修改后 =="
grep -n "$UUID" /etc/fstab
echo "== 语法/单元检查 =="
systemd-analyze verify /etc/fstab 2>&1 | head -5 || true
findmnt --verify --tab /etc/fstab 2>&1 | tail -6 || true
findmnt "$MP"
echo
echo "完成 ✅  回退：cp /etc/fstab.bak-nofail-* /etc/fstab && systemctl daemon-reload"
