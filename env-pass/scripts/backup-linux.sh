#!/system/bin/sh
# 备份 Linux(sda17/linux17) 分区内容到 /data/local/tmp
MNT=/mnt/linux
OUT=/data/local/tmp/linux17-rootfs-20261002.tar.gz
INV=/data/local/tmp/linux17-inventory-20261002.txt
mkdir -p "$MNT"
mountpoint -q "$MNT" || mount -t ext4 -o ro /dev/block/sda17 "$MNT"

echo "[1/3] inventory ..."
{
  echo "# linux17 (sda17) inventory $(date)"
  echo "## df"; df -h "$MNT" 2>/dev/null
  echo "## top-level"; ls -la "$MNT"
  echo "## du -sh"; du -sh "$MNT"/* 2>/dev/null
  echo "## file count"; find "$MNT" 2>/dev/null | wc -l
  echo "## init backups"; ls -la "$MNT"/init* 2>/dev/null
  echo "## etc (top)"; ls "$MNT/etc" 2>/dev/null
  echo "## root (top)"; ls -la "$MNT/root" 2>/dev/null
  echo "## usr/local"; ls -la "$MNT/usr/local" 2>/dev/null
} > "$INV" 2>&1

echo "[2/3] tar ..."
tar -czf "$OUT" -C "$MNT" .
echo "tar rc=$?"
ls -l "$OUT" "$INV" 2>&1
echo "[3/3] done"
