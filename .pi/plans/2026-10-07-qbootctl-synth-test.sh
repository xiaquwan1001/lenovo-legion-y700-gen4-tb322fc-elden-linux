#!/usr/bin/env bash
# qbootctl-synth-test.sh — 主机侧合成 GPT 冒烟：验证 qbootctl 在
# **4096 字节扇区** 下能读写 A/B slot 属性（= 本项目 slot-attr.py 的核心功能）。
#
# 目的：在碰真设备前，先排除「qbootctl 不认 4K 扇区 / 多盘」这一风险。
# 用法（需 root）：
#   sudo bash .pi/plans/2026-10-07-qbootctl-synth-test.sh
#
# 依赖：losetup(util-linux>=2.37)、sgdisk、git/meson/gcc（构建 qbootctl）。
# 会把 qbootctl 克隆/构建到 /tmp/qbootctl（若已存在则复用）。
set -euo pipefail

IMG=${IMG:-/tmp/qbootctl-synth.img}
SRC=${SRC:-/tmp/qbootctl}
QBT=${QBT:-$SRC/build/qbootctl}

if [ "$(id -u)" != 0 ]; then echo "需 root：sudo bash $0" >&2; exit 1; fi

# ---- 构建 qbootctl（可提前无 sudo 做：git clone + meson）----
if [ ! -x "$QBT" ]; then
	[ -d "$SRC/.git" ] || git clone -q --depth 1 https://gitlab.com/sdm845-mainline/qbootctl.git "$SRC"
	( cd "$SRC" && meson setup build >/dev/null 2>&1 && meson compile -C build >/dev/null 2>&1 )
fi
[ -x "$QBT" ] || { echo "qbootctl 构建失败: $QBT" >&2; exit 1; }
echo "[*] qbootctl = $QBT"

LOOP=""
cleanup() {
	set +e
	lb=$(basename "${LOOP:-none}")
	[ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null
	for p in boot_a boot_b dtbo_a dtbo_b; do
		case "$(readlink "/dev/disk/by-partlabel/$p" 2>/dev/null)" in
			*"$lb"*) rm -f "/dev/disk/by-partlabel/$p" ;;
		esac
	done
	rm -f "$IMG"
	echo "[*] cleaned up"
}
trap cleanup EXIT

# ---- 造 64 MiB 镜像 = 16384 个 4096B 扇区 ----
truncate -s 64M "$IMG"
LOOP=$(losetup -b 4096 -f --show "$IMG")
echo "[*] loop=$LOOP  logical_sector=$(blockdev --getss "$LOOP")  size=$(stat -c%s "$IMG")B"

# ---- boot_a/boot_b（+dtbo_a/b 供 -s 路径用）；boot_a 置 ACTIVE(bit50) ----
sgdisk -Z "$LOOP" >/dev/null
sgdisk \
	-n 1:256:+16M -c 1:boot_a -A 1:set:50 \
	-n 2:0:+16M   -c 2:boot_b \
	-n 3:0:+4M    -c 3:dtbo_a -A 3:set:50 \
	-n 4:0:+4M    -c 4:dtbo_b \
	"$LOOP" >/dev/null
echo "[*] GPT written (4K sectors):"; sgdisk -p "$LOOP" | sed -n '1,6p'

# 重新挂载以生成分区节点
losetup -d "$LOOP"
LOOP=$(losetup -b 4096 -P -f --show "$IMG")
udevadm settle 2>/dev/null || true

# by-partlabel 软链（udev 通常已建；缺失则手建）
for spec in "1 boot_a" "2 boot_b" "3 dtbo_a" "4 dtbo_b"; do
	set -- $spec
	dev="$(basename "$LOOP")p$1"
	if [ ! -e "/dev/disk/by-partlabel/$2" ]; then
		ln -sf "../../$dev" "/dev/disk/by-partlabel/$2"
		echo "[*] (manual symlink) $2 -> $dev"
	fi
done
ls -l /dev/disk/by-partlabel/boot_a /dev/disk/by-partlabel/boot_b

# 直接读原始镜像（不经过 loop），按字节偏移取 GPT 条目属性 byte6（偏移 +6）
attr_byte_off() { dd if="$IMG" bs=1 skip="$1" count=1 2>/dev/null | od -An -tx1 | tr -d ' \n'; }
TOTAL_SEC=$(( $(stat -c%s "$IMG") / 4096 ))
BK_ENTRY_LBA=$(( TOTAL_SEC - 33 ))          # 备份条目区起始 LBA
OFF_A_PRIMARY=$(( 2 * 4096 + 6 ))           # 主条目 1（boot_a）属性 byte
OFF_B_PRIMARY=$(( 2 * 4096 + 128 + 6 ))     # 主条目 2（boot_b）属性 byte
OFF_A_BACKUP=$(( BK_ENTRY_LBA * 4096 + 6 )) # 备条目 1（boot_a）属性 byte

echo
echo "==== 1) qbootctl dump（读路径）===="
"$QBT" || true

echo
echo "==== 2) 标记前 boot_a byte6：primary=0x$(attr_byte_off $OFF_A_PRIMARY)  backup=0x$(attr_byte_off $OFF_A_BACKUP)"
echo "====    qbootctl -n a（应 not successful）===="
"$QBT" -n a || true

echo
echo "==== 3) qbootctl -m a（写入：应同时改 primary+backup GPT）===="
"$QBT" -m a

echo
echo "==== 4) 标记后原始字节（独立校验）===="
echo "  boot_a primary byte6 = 0x$(attr_byte_off $OFF_A_PRIMARY)   backup byte6 = 0x$(attr_byte_off $OFF_A_BACKUP)"
echo "  boot_b primary byte6 = 0x$(attr_byte_off $OFF_B_PRIMARY)   （应不变）"

echo
echo "==== 5) 功能读回 ===="
"$QBT" -n a || true
"$QBT" -n b || true

echo
echo "[*] 判定：boot_a 两处 byte6 均含 0x40(bit6=SUCCESSFUL) ⇒ qbootctl 4K 扇区读写正确。"
echo "[*] 本测试未触 UFS BSG（-m/-n 纯 GPT）；-s 会走 UFS boot-LUN 切换，另测。"
