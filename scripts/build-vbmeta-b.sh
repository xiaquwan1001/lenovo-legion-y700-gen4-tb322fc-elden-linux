#!/bin/bash
# build-vbmeta-b.sh — 重签 b 槽自签 AVB vbmeta（自签链，把 chain `boot` 指向**现役** avb.key）
#
# 立此脚本的原因（2026-11-21）：
#   b 槽 Linux 用「自签 AVB」：`boot_b` 带 hash footer（签 `bootslot-b/avb.key`），
#   `vbmeta_b` 带 chain 描述符 `boot` 指向**同一把** key。2026-10-18 换过 key
#   （旧 `fc1e3b33…` → 现役 `1e54e86e…`），但 `vbmeta_b` 没跟着重签 ⇒ 设备上出现
#   「顶层 vbmeta 与 boot 的签名 key 都不是我们这把」的不一致（`fastboot boot` 必拒、
#   槽位启动只能靠 Flags=3 关校验绕过）。本脚本把这条链做成**一个命令可复现**。
#
# 用法：
#   scripts/build-vbmeta-b.sh [--out-dir DIR] [--flags N] [--key KEY] [--boot IMG]
#   scripts/build-vbmeta-b.sh --check [--out-dir DIR]     # 只验已造件（doctor §26 委托此模式）
#
# 默认：out/vbmeta-b/，flags=3（= 现役形态：hashtree + verification 全关），
#       key=bootslot-b/avb.key，链上件=bootslot-b/boot_b.img。
#
# 判据（build 与 check 同一套，任一不过即 rc≠0）：
#   ① 件大小 = 65536（vbmeta_b 分区 64 KiB）；
#   ② `info_image` 顶层 key sha1 == 现役 avb.key 的 sha1；
#   ③ chain `boot:3` 的 key sha1 == 同一 sha1（**这就是 2026-10-18 那次漂移的点**）；
#   ④ flags 与文件名后缀一致（flags3 件必须 Flags: 3）；
#   ⑤ `verify_image --follow_chain_partitions` 对「vbmeta + boot 件」整链 rc=0；
#   ⑥ boot 件自身 footer 的 key sha1 == 同一 sha1；
#   ⑦ 反作弊：把件里翻一个字节后同一验签必须失败（否则门在空转）。
#
# 安全：本脚本**只造件**，不碰设备。上机刷写/回退命令写在产物 MANIFEST.md 里，由人/编排决定。
set -eu
cd "$(dirname "$0")/.."
ROOT=$(pwd)

OUTDIR=out/vbmeta-b
FLAGS=3
KEY=bootslot-b/avb.key
BOOT=bootslot-b/boot_b.img
MODE=build

die() { echo "[vbmeta-b] $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --out-dir) OUTDIR=${2:?--out-dir 需要目录}; shift ;;
    --flags) FLAGS=${2:?--flags 需要数字}; shift ;;
    --key) KEY=${2:?--key 需要路径}; shift ;;
    --boot) BOOT=${2:?--boot 需要镜像}; shift ;;
    --check) MODE=check ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) die "未知参数：$1（见 --help）" ;;
  esac
  shift
done

AVB="python3 $ROOT/tools/avbtool.py"
PART_SIZE=65536
# chain 里 boot 的 rollback slot 沿用原厂 vbmeta_b 的形状（3），不是 0。
CHAIN_SLOT=3

[ -f "$KEY" ] || die "找不到 key：$KEY"
[ -f "$ROOT/tools/avbtool.py" ] || die "找不到 tools/avbtool.py"

key_sha1() {
  _tmp=$(mktemp "${TMPDIR:-/tmp}/avbpub.XXXXXX")
  $AVB extract_public_key --key "$KEY" --output "$_tmp" >/dev/null 2>&1 || { rm -f "$_tmp"; die "extract_public_key 失败（$KEY 是 RSA 私钥吗？）"; }
  python3 - "$_tmp" <<'PY'
import hashlib, sys
print(hashlib.sha1(open(sys.argv[1], 'rb').read()).hexdigest())
PY
  rm -f "$_tmp"
}

KEY_SHA1=$(key_sha1)
[ -n "$KEY_SHA1" ] || die "算不出 key sha1"

# info_image 字段提取：$1=image $2=awk 键
info_field() {
  $AVB info_image --image "$1" 2>/dev/null | awk -v k="$2" 'index($0,k)==1 {sub(/^[^:]*:[ ]*/,""); print; exit}'
}

# 顶层 key / chain boot key（chain 段内第一处 Public key (sha1)）
top_key_sha1() { $AVB info_image --image "$1" 2>/dev/null | awk '/^Public key \(sha1\):/ {print $4; exit}'; }
chain_boot_sha1() {
  $AVB info_image --image "$1" 2>/dev/null | awk '
    /Chain Partition descriptor/ {inchain=1; next}
    inchain && /Partition Name:/ {name=$3}
    inchain && /Public key \(sha1\):/ {if (name=="boot") {print $4; exit}}'
}
boot_footer_sha1() { $AVB info_image --image "$1" 2>/dev/null | awk '/^Public key \(sha1\):/ {print $4; exit}'; }

# 整链验签（avbtool 在**被验 vbmeta 所在目录**里按描述符分区名找 <partition>.img
# ⇒ 把 vbmeta + boot 件一起拷进临时目录再验，才能真走到 chain 展开）
verify_chain() { # $1=vbmeta $2=boot img（可相对路径）
  _d=$(mktemp -d "${TMPDIR:-/tmp}/avbchain.XXXXXX")
  _ky=$(cd "$(dirname "$KEY")" && pwd)/$(basename "$KEY")
  cp -f "$1" "$_d/$(basename "$1")"
  cp -f "$2" "$_d/boot.img"
  _rc=0
  ( cd "$_d" && $AVB verify_image --image "$_d/$(basename "$1")" \
      --key "$_ky" --follow_chain_partitions ) >"$_d/out.txt" 2>&1 || _rc=$?
  cat "$_d/out.txt"
  rm -rf "$_d"
  return $_rc
}

check_artifact() { # $1=img ; 返回 0 = 全过
  _img=$1
  _name=$(basename "$_img")
  _rc=0
  [ -f "$_img" ] || { echo "  [FAIL] 缺件：$_img" >&2; return 1; }
  _size=$(stat -c %s "$_img")
  [ "$_size" = "$PART_SIZE" ] && echo "  [ok] 大小 $_size = $PART_SIZE" || { echo "  [FAIL] 大小 $_size ≠ $PART_SIZE" >&2; _rc=1; }

  _top=$(top_key_sha1 "$_img")
  [ "$_top" = "$KEY_SHA1" ] && echo "  [ok] 顶层 key = $_top（现役 avb.key）" \
    || { echo "  [FAIL] 顶层 key = ${_top:-?} ≠ 现役 avb.key $KEY_SHA1（key 旋转后没重签）" >&2; _rc=1; }

  _chain=$(chain_boot_sha1 "$_img")
  [ "$_chain" = "$KEY_SHA1" ] && echo "  [ok] chain boot:$CHAIN_SLOT key = $_chain" \
    || { echo "  [FAIL] chain boot:$CHAIN_SLOT key = ${_chain:-?} ≠ $KEY_SHA1（就是在机 vbmeta_b 的旧病）" >&2; _rc=1; }

  case "$_name" in
    *flags3*) _want=3 ;; *flags0*) _want=0 ;; *flags1*) _want=1 ;; *) _want="" ;;
  esac
  if [ -n "$_want" ]; then
    _got=$(info_field "$_img" "Flags:")
    [ "$_got" = "$_want" ] && echo "  [ok] Flags: $_got（与文件名一致）" \
      || { echo "  [FAIL] Flags: ${_got:-?} ≠ $_want（文件名 $_name）" >&2; _rc=1; }
  fi

  if [ -f "$BOOT" ]; then
    _bkey=$(boot_footer_sha1 "$BOOT")
    [ "$_bkey" = "$KEY_SHA1" ] && echo "  [ok] boot 件 footer key = $_bkey" \
      || { echo "  [FAIL] boot 件（$BOOT）footer key = ${_bkey:-?} ≠ $KEY_SHA1" >&2; _rc=1; }
    if _out=$(verify_chain "$_img" "$BOOT"); then
      echo "$_out" | sed 's/^/      /'
      echo "  [ok] 整链验签 rc=0（$_name → $BOOT）"
    else
      echo "$_out" | sed 's/^/      /'
      echo "  [FAIL] 整链验签失败（$_name → $BOOT）" >&2
      _rc=1
    fi
  else
    echo "  [warn] 无 boot 件（$BOOT），跳过整链验签" >&2
  fi

  # 反作弊：翻一个字节必须失败
  _bad=$(mktemp "${TMPDIR:-/tmp}/vbmeta-b-bad.XXXXXX")
  cp -f "$_img" "$_bad"
  printf '\x00' | dd of="$_bad" bs=1 seek=600 conv=notrunc status=none
  if _out=$(verify_chain "$_bad" "$BOOT" 2>&1); then
    echo "  [FAIL] 反作弊失败：翻字节后仍验签通过（门空转）" >&2
    _rc=1
  else
    echo "  [ok] 反作弊：翻字节 ⇒ 验签被拒"
  fi
  rm -f "$_bad"
  return $_rc
}

if [ "$MODE" = check ]; then
  echo "[vbmeta-b] --check：$OUTDIR（key=$KEY sha1=$KEY_SHA1）"
  found=0
  rc=0
  for img in "$OUTDIR"/vbmeta_b-flags*.img; do
    [ -f "$img" ] || continue
    found=1
    echo " - $(basename "$img")"
    check_artifact "$img" || rc=1
  done
  if [ "$found" = 0 ]; then
    echo "  [warn] $OUTDIR 下没有 vbmeta_b-flags*.img —— 跑 scripts/build-vbmeta-b.sh 造件" >&2
    exit 2
  fi
  [ "$rc" = 0 ] && echo "[vbmeta-b] --check 全绿" || echo "[vbmeta-b] --check 有 FAIL" >&2
  exit "$rc"
fi

# ---- build ----
mkdir -p "$OUTDIR"
PUBKEY="$OUTDIR/avb.avbpubkey"
OUT="$OUTDIR/vbmeta_b-flags$FLAGS.img"

$AVB extract_public_key --key "$KEY" --output "$PUBKEY" >/dev/null
[ "$(python3 -c 'import hashlib,sys;print(hashlib.sha1(open(sys.argv[1],"rb").read()).hexdigest())' "$PUBKEY")" = "$KEY_SHA1" ] \
  || die "avbpubkey 与 key 不自洽"

# flags=3：HASHTREE_DISABLED|VERIFICATION_DISABLED —— 描述符不参与校验，故只用显式 chain（不抄旧 dtbo hash 描述符，
# 那份 digest 对应的是历史 dtbo_b 内容，抄进来只会制造「描述符指向不明内容」的假账）。
$AVB make_vbmeta_image \
  --output "$OUT" \
  --key "$KEY" --algorithm SHA256_RSA4096 \
  --chain_partition "boot:$CHAIN_SLOT:$PUBKEY" \
  --flags "$FLAGS" --rollback_index 0 --rollback_index_location 0 \
  --padding_size "$PART_SIZE" >/dev/null

echo "[vbmeta-b] 造件完成：$OUT"
check_artifact "$OUT" || die "自检失败（见上）"

# O_DIRECT 硬门（AGENTS 硬规则 12 / A1：本机页缓存污染会让 buffered sha「稳定但错」）
if [ -f scripts/odirect-sha.py ]; then
  python3 scripts/odirect-sha.py "$OUT" "$PUBKEY" > "$OUTDIR/SHA256SUMS.tsv"
  awk -F'\t' '{print $3"  "$1}' "$OUTDIR/SHA256SUMS.tsv" > "$OUTDIR/SHA256SUMS"
else
  ( cd "$OUTDIR" && sha256sum "$(basename "$OUT")" "avb.avbpubkey" > SHA256SUMS )
fi

_revert=backup/vbmeta_b-20261110.img
if [ -f logs/forensics-20261120-2210/vbmeta_b.img ]; then
  _inplace='logs/forensics-20261120-2210/vbmeta_b.img'
else
  _inplace='（设备侧 dump，见 logs/forensics-*/vbmeta_b.img）'
fi
cat > "$OUTDIR/MANIFEST.md" <<EOF
# b 槽自签 vbmeta（flags=$FLAGS）— 造件账

- 生成器：\`scripts/build-vbmeta-b.sh\`（\`--check\` 可离线复核；doctor §26 委托该模式）
- key：\`$KEY\`（顶层 + chain \`boot:$CHAIN_SLOT\` 共用）公钥 sha1 = \`$KEY_SHA1\`
- 件：\`$(basename "$OUT")\`，$(stat -c %s "$OUT") B，flags=$FLAGS、rollback 0/0
- 链上件：\`$BOOT\`（footer key 同为 \`$KEY_SHA1\`）
- sha256（O_DIRECT）：见 \`SHA256SUMS\`

## 为什么有这个件

设备在机 \`vbmeta_b\` 是 2026-10-18 换 key **之前**签的：顶层 key \`fc1e3b33…\`、chain
\`boot:3\` 也指 \`fc1e3b33…\`，而 \`boot_b\` 的 footer 已经是新 key \`$KEY_SHA1\`。
⇒ 自签链自身不自洽（只能靠 Flags=3「不解析描述符」绕过）。

## 上机（需设备窗口；本脚本不执行）

\`\`\`bash
# 0) 留现场：设备侧 vbmeta_b 原件（已有一份 logs/forensics-20261120-2210/vbmeta_b.img）
#    在线判据见 DEVICE/README.md §1.6（EDL 读 / fastboot / ssh 任一中就算在线）
# 1) 刷前基线
timeout 15 fastboot getvar current-slot
# 2) 刷件
timeout 60 fastboot flash vbmeta_b $OUT
# 3) 验收动作（RAM 引导，不改槽）：
timeout 15 fastboot boot $BOOT
\`\`\`

## 回退

\`\`\`bash
timeout 60 fastboot flash vbmeta_b $_revert
\`\`\`
在机现役件（换成它 = 回到 2026-11-20 夜的状态）：\`$_inplace\`
EOF

echo "[vbmeta-b] 产物："
ls -l "$OUTDIR"
echo "[vbmeta-b] 账：$OUTDIR/MANIFEST.md"
