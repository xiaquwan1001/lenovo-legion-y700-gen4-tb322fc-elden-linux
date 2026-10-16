#!/bin/bash
# setup-newdisk.sh — 把 1T Samsung (MZVL41T0HBLB, SN S6B7NF0TA34973) 分区/格式化/挂载到 /mnt/nvme0
#
# 用法（需要 root，一条命令，只输一次密码）：
#     sudo bash ~/waydroid-build/setup-newdisk.sh
#
# 设计要点：
#   * 按 **序列号** 定位磁盘，不用 /dev/nvmeXn1（本机重启后 nvme0/nvme1 会互换！）
#   * 多重安全检查：容量必须是 ~954G、不能是系统盘、不能有已挂载分区
#   * 幂等：已有该标签的 ext4 就直接挂载，不重复格式化

set -euo pipefail

SERIAL="S6B7NF0TA34973"          # MZVL41T0HBLB-00BH1
LABEL="waydroid"
MOUNTPOINT="/mnt/nvme0"
EXPECTED_SECTORS_MIN=$((1900*1000*1000))   # 949,000,000 扇区下限
EXPECTED_SECTORS_MAX=$((2100*1000*1000))   # 上限

log()  { echo -e "\033[1;36m[setup-newdisk]\033[0m $*"; }
warn() { echo -e "\033[1;33m[setup-newdisk] ⚠️  $*\033[0m"; }
die()  { echo -e "\033[1;31m[setup-newdisk] ❌ $*\033[0m" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "请用 root 运行：sudo bash $0"

# --- 1. 按序列号解析磁盘 ---
DISK=""
for d in /sys/block/nvme*n1; do
  [ -r "$d/serial" ] || continue
  if [ "$(cat "$d/serial")" = "$SERIAL" ]; then DISK="/dev/$(basename "$d")"; break; fi
done
[ -n "$DISK" ] || die "找不到序列号为 $SERIAL 的磁盘（是否已插好/通电？）"

SIZE_SEC=$(cat "/sys/block/$(basename "$DISK")/size")
log "目标磁盘: $DISK  (serial=$SERIAL, $((SIZE_SEC*512/1024/1024/1024)) GiB)"
[ "$SIZE_SEC" -ge "$EXPECTED_SECTORS_MIN" ] && [ "$SIZE_SEC" -le "$EXPECTED_SECTORS_MAX" ] \
  || die "容量异常（$SIZE_SEC 扇区），与 1T 盘不符，中止以防误伤"

# --- 2. 安全检查：不能是系统盘 / 不能有已挂载分区 ---
ROOT_SRC="$(findmnt -no SOURCE / 2>/dev/null || true)"
case "$ROOT_SRC" in "$DISK"*) die "$DISK 是当前系统盘，中止";; esac
if lsblk -nrpo MOUNTPOINT "$DISK" | grep -q .; then
  warn "$DISK 上有已挂载的分区："
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "$DISK"
  die "请先手动卸载再运行"
fi
log "安全检查通过（非系统盘、无已挂载分区）"

# --- 3. 幂等：若已有同名 ext4 分区，直接挂载 ---
EXIST_PART=$(blkid -t "LABEL=$LABEL" -o device 2>/dev/null | head -1 || true)
if [ -n "$EXIST_PART" ]; then
  log "已存在标签为 $LABEL 的分区: $EXIST_PART，跳过格式化"
  PART="$EXIST_PART"
else
  log "擦除 $DISK 上的旧签名…"
  wipefs -a "$DISK" >/dev/null

  log "建立 GPT + 单个分区…"
  parted -s -a optimal "$DISK" mklabel gpt
  parted -s -a optimal "$DISK" mkpart "$LABEL" ext4 0% 100%

  partprobe "$DISK" 2>/dev/null || true
  udevadm settle --timeout=30 2>/dev/null || true
  sleep 1

  PART="$(lsblk -nrpo NAME "$DISK" | sed -n '2p')"    # 第一个分区
  [ -n "$PART" ] || die "分区未生成"
  log "分区: $PART"

  log "格式化为 ext4 (label=$LABEL)…"
  mkfs.ext4 -L "$LABEL" -m 1 "$PART"
fi

# --- 4. 挂载 ---
UUID=$(blkid -s UUID -o value "$PART")
[ -n "$UUID" ] || die "取不到 UUID"
mkdir -p "$MOUNTPOINT"

if mountpoint -q "$MOUNTPOINT"; then
  log "$MOUNTPOINT 已在挂载状态"
else
  mount "$PART" "$MOUNTPOINT"
fi
chown 1000:1000 "$MOUNTPOINT"

# --- 5. 写 /etc/fstab（按 UUID，只写一次） ---
if ! grep -q "UUID=$UUID" /etc/fstab 2>/dev/null; then
  cp /etc/fstab "/etc/fstab.bak-$(date +%s)"
  printf 'UUID=%s  %s  ext4  defaults,nofail,x-systemd.device-timeout=10  0  2\n' "$UUID" "$MOUNTPOINT" >> /etc/fstab
  log "已写入 /etc/fstab（备份 /etc/fstab.bak-*）"
fi

# --- 6. 汇总 ---
log "完成 ✅"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DISK"
df -h "$MOUNTPOINT"
echo
log "下一步（无需 root）："
echo "    mv ~/waydroid-build $MOUNTPOINT/ && cd $MOUNTPOINT/waydroid-build && nohup ./sync-resume.sh >> sync.log 2>&1 &"
