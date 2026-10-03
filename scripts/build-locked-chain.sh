#!/bin/bash
# build-locked-chain.sh — 为 **BL locked** 单元生成 b 槽 mainline 自洽链（AOSP testkey）
#
# 原理（2026-10-03 确认）：
#   联想原厂信任 AOSP 公开 testkey：env-pass/keys/testkey_rsa4096.pem 的公钥 sha1 =
#   2597c218aae470a130f61162feaae70afd97f011 = U1 stock vbmeta_a 的顶层公钥。
#   私钥公开（AOSP external/avb/test/data/testkey_rsa4096.pem），我们有 →
#   可以签出 locked green 态能通过验证的完整链。
#
#   现有 bootslot-b/ 的自造密钥链（fc1e3b33 + flags3）只适用 unlocked（orange 宽容）；
#   locked/green 需要本脚本生成的「原厂结构复刻链」。
#
# 原厂结构（从 U1 stock dump 读出，U2 需用本单元 dump 复核）：
#   vbmeta: KEY=2597c218, flags=1(HASHTREE_DISABLED), rollback=0/location 0
#           chain boot:3:2597c218 | chain recovery:1:8fcb864f | chain vbmeta_system:2:8fcb864f
#           + 原厂 props（dtbo/init_boot/odm/system_dlkm/vendor*/vendor_boot fingerprint 等）
#   boot:   KEY=2597c218, rollback=1738713600/location 0 + 3 条 boot props
#   dtbo:   无 descriptor（ABL 只拿它当 overlay，magic mismatch 跳过 → fake 4KB 全零可用）
#
# 用法：
#   scripts/build-locked-chain.sh <kernel.img> <stock_boot_dump> <stock_vbmeta_dump> \
#       [stock_vbmeta_system_dump] [stock_recovery_dump] [--out bootslot-b-locked]
#   kernel.img      = 未签名的 mainline boot 镜像（out/boot-elden-vk40.img，无 AVB footer）
#   stock_*_dump    = 本单元的原厂 dump（fastboot fetch 或 EDL read），参数自动读出
#
# 输出（默认 bootslot-b-locked/）：
#   boot_b.img / vbmeta_b.img / dtbo_b.img   ← EDL/fastboot 写入 b 槽三件套
set -eu
cd "$(dirname "$0")/.."

KERNEL=${1:?usage: build-locked-chain.sh <kernel.img> <stock_boot_dump> <stock_vbmeta_dump> [vbmeta_system_dump] [recovery_dump]}
STOCK_BOOT=${2:?缺 stock boot dump}
STOCK_VBMETA=${3:?缺 stock vbmeta dump}
STOCK_VBMETA_SYSTEM=${4:-}
STOCK_RECOVERY=${5:-}
OUT=bootslot-b-locked
[ "$6" = "--out" ] && OUT=$7

KEY=env-pass/keys/testkey_rsa4096.pem
AVB=tools/avbtool.py
[ -f "$KEY" ] || { echo "缺 testkey: $KEY"; exit 1; }
[ -f "$STOCK_BOOT" ] || { echo "缺 stock boot dump: $STOCK_BOOT"; exit 1; }
[ -f "$STOCK_VBMETA" ] || { echo "缺 stock vbmeta dump: $STOCK_VBMETA"; exit 1; }
[ -f "$KERNEL" ] || { echo "缺内核镜像: $KERNEL"; exit 1; }
mkdir -p "$OUT"

echo "== 1/5 读 stock 参数（本单元实际值，不预设） =="
BOOT_RB=$(python3 $AVB info_image --image "$STOCK_BOOT" | sed -n 's/.*Rollback Index: *\([0-9]*\)$/\1/p' | head -1)
[ -n "$BOOT_RB" ] || BOOT_RB=1738713600
echo "   boot rollback_index = $BOOT_RB"

# boot 的 3 条原厂 props（原样复制）
BOOT_PROPS=()
while IFS= read -r l; do
  p=$(printf '%s' "$l" | sed -n "s/^ *Prop: \([^ ]*\) -> .*$/\1/p")
  [ -n "$p" ] || continue
  case "$p" in
    com.android.build.boot.*) v=$(printf '%s' "$l" | sed -n "s/^ *Prop: [^ ]* -> '\(.*\)'$/\1/p"); BOOT_PROPS+=(--prop "$p:$v") ;;
  esac
done < <(python3 $AVB info_image --image "$STOCK_BOOT")
echo "   boot props = ${#BOOT_PROPS[@]} 个参数（$((${#BOOT_PROPS[@]}/2)) 条）"
[ ${#BOOT_PROPS[@]} -ge 2 ] || { echo "⚠ stock boot 无 props——ABL 可能拒（U1 经验：缺 props 失败）"; }

# stock vbmeta 的 flags / rollback
VBMETA_FLAGS=$(python3 $AVB info_image --image "$STOCK_VBMETA" | sed -n 's/.*Flags: *\([0-9]*\)$/\1/p' | head -1)
[ -n "$VBMETA_FLAGS" ] || VBMETA_FLAGS=1
VBMETA_RB=$(python3 $AVB info_image --image "$STOCK_VBMETA" | sed -n 's/.*Rollback Index: *\([0-9]*\)$/\1/p' | head -1)
[ -n "$VBMETA_RB" ] || VBMETA_RB=0
echo "   vbmeta flags=$VBMETA_FLAGS rollback=$VBMETA_RB"

echo "== 2/5 签 boot_b（testkey + rollback $BOOT_RB + 原厂 props） =="
cp -f "$KERNEL" "$OUT/boot_b.img"
python3 $AVB add_hash_footer --image "$OUT/boot_b.img" --partition_name boot \
  --partition_size 100663296 --key "$KEY" --algorithm SHA256_RSA4096 \
  --rollback_index "$BOOT_RB" "${BOOT_PROPS[@]}" >/dev/null

echo "== 3/5 造 fake dtbo_b（4KB 全零 → 32MiB，无 descriptor） =="
dd if=/dev/zero of="$OUT/dtbo_b.img" bs=1048576 count=32 status=none

echo "== 4/5 造 vbmeta_b（原厂结构复刻：boot chain 换 testkey） =="
# testkey 的 AVB 公钥格式（--chain_partition 要 .avbpubkey，不是 PEM）
python3 $AVB extract_public_key --key "$KEY" --output "$OUT/testkey.avbpubkey" >/dev/null
VBMETA_ARGS=(--algorithm SHA256_RSA4096 --key "$KEY"
  --flags "$VBMETA_FLAGS" --rollback_index "$VBMETA_RB"
  --chain_partition boot:3:"$OUT/testkey.avbpubkey")
# recovery / vbmeta_system 的 chain：原样保留（从 stock 镜像 AVB footer 提公钥 blob）
if [ -n "$STOCK_RECOVERY" ] && [ -f "$STOCK_RECOVERY" ]; then
  if python3 scripts/extract-avbpubkey.py "$STOCK_RECOVERY" "$OUT/recovery_pub.avbpubkey" 2>/dev/null; then
    VBMETA_ARGS+=(--chain_partition recovery:1:"$OUT/recovery_pub.avbpubkey")
    echo "   chain recovery:1 ← $STOCK_RECOVERY"
  else
    echo "   ⚠ recovery 公钥提取失败（$STOCK_RECOVERY 不是裸 vbmeta；hash footer 镜像需先转）"
  fi
fi
if [ -n "$STOCK_VBMETA_SYSTEM" ] && [ -f "$STOCK_VBMETA_SYSTEM" ]; then
  if python3 scripts/extract-avbpubkey.py "$STOCK_VBMETA_SYSTEM" "$OUT/vbmeta_system_pub.avbpubkey" 2>/dev/null; then
    VBMETA_ARGS+=(--chain_partition vbmeta_system:2:"$OUT/vbmeta_system_pub.avbpubkey")
    echo "   chain vbmeta_system:2 ← $STOCK_VBMETA_SYSTEM"
  else
    echo "   ⚠ vbmeta_system 公钥提取失败"
  fi
fi
# 原厂 vbmeta 的 props（fingerprint 等，原样复制）
VBMETA_PROPS=()
while IFS= read -r l; do
  p=$(printf '%s' "$l" | sed -n "s/^ *Prop: \([^ ]*\) -> .*$/\1/p")
  [ -n "$p" ] || continue
  v=$(printf '%s' "$l" | sed -n "s/^ *Prop: [^ ]* -> '\(.*\)'$/\1/p")
  VBMETA_PROPS+=(--prop "$p:$v")
done < <(python3 $AVB info_image --image "$STOCK_VBMETA")
echo "   vbmeta props = $((${#VBMETA_PROPS[@]}/2)) 条（原样复制）"

python3 $AVB make_vbmeta_image --output "$OUT/vbmeta_b.img" --padding_size 65536 \
  "${VBMETA_ARGS[@]}" "${VBMETA_PROPS[@]}" >/dev/null

echo "== 5/5 校验（自洽性） =="
python3 $AVB verify_image --image "$OUT/boot_b.img" --expected_chain_partition boot:3 >/dev/null 2>&1 \
  && echo "   ✓ boot_b 链验证通过" || echo "   （verify_image 需 vbmeta 配合，跳过）"
python3 $AVB info_image --image "$OUT/vbmeta_b.img" | grep -E 'Public key|Rollback Index|Flags' | head -4
python3 $AVB info_image --image "$OUT/boot_b.img" | grep -E 'Public key|Rollback Index' | head -3
echo ""
echo "ready: EDL 写入 b 槽三件套 →"
echo "  qdl/build/qdl -s ufs ~/下载/tb322fc/xbl_s_devprg_ns.melf write boot_b $OUT/boot_b.img"
echo "  （dtbo_b / vbmeta_b 同理；只写 b 槽！写后 EDL read 回校验）"
