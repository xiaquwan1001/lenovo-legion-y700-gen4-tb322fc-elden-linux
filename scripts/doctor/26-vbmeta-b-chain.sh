#!/bin/bash
# 26-vbmeta-b-chain.sh — §26 b 槽自签 AVB 链一致性门（委托 scripts/build-vbmeta-b.sh --check）。
# 立此节的原因（2026-11-21，TASKS §4 P1「AVB 债」）：
#   2026-10-18 换过自签 key（旧 fc1e3b33… → 现役 1e54e86e…），`boot_b` 跟着重签了，
#   设备上的 `vbmeta_b` 没跟着重签 ⇒ 自签链自身不自洽（顶层 key 与 chain boot:3 都指旧钥），
#   槽位启动只能靠 Flags=3「不解析描述符」绕过，`fastboot boot` 那条路必拒。
#   这类漂移**只会在换钥时复发**，靠人记不可靠 ⇒ 做成门：
#     ① `out/vbmeta-b/vbmeta_b-flags*.img` 与现役 `bootslot-b/avb.key` 自洽（顶层 + chain + flags + 大小）；
#     ② 与 `bootslot-b/boot_b.img` 的整链验签 rc=0；
#     ③ 反作弊：把件翻一个字节后同一验签必须被拒（门不空转）。
# 三态：`out/vbmeta-b/` 不存在 = warn SKIP（不装成 PASS）；件不自洽 = FAIL。
. "$(dirname "$0")/_lib.sh"

section '26. b 槽自签 AVB 链一致性（vbmeta_b ↔ avb.key ↔ boot_b）'

GEN="$HELPERS/build-vbmeta-b.sh"
OUTDIR="$ROOT/out/vbmeta-b"
KEY="$ROOT/bootslot-b/avb.key"
BOOT="$ROOT/bootslot-b/boot_b.img"

if [ ! -f "$GEN" ]; then
  bad "scripts/build-vbmeta-b.sh 缺失（本门的被委托件）"
  exit 0
fi
if [ ! -f "$KEY" ]; then
  bad "bootslot-b/avb.key 缺失 —— b 槽自签链无法复核"
  exit 0
fi
if [ ! -d "$OUTDIR" ]; then
  warnf "SKIP：out/vbmeta-b/ 不存在（未造件）→ 跑 scripts/build-vbmeta-b.sh 造件"
  exit 0
fi

# ---- 现有树实跑 ----
_rc=0
_out=$(timeout 300 bash "$GEN" --check --out-dir "$OUTDIR" 2>&1) || _rc=$?
if [ "$_rc" -eq 0 ]; then
  ok "现役件与 avb.key 自洽（顶层 key + chain boot:3 + Flags + 整链验签）"
else
  bad "vbmeta_b 自签链不自洽（rc=$_rc）→ 重跑 scripts/build-vbmeta-b.sh；摘自检：$(printf '%s' "$_out" | grep '\[FAIL\]' | head -2 | tr '\n' ' ')"
fi

# ---- 反作弊：翻一个字节后必须被判 FAIL ----
_d=$(mktemp -d "${TMPDIR:-/tmp}/vbmeta-b-gate.XXXXXX")
trap 'rm -rf "$_d"' EXIT INT TERM
_img=$(ls "$OUTDIR"/vbmeta_b-flags*.img 2>/dev/null | head -1)
if [ -z "$_img" ]; then
  bad "out/vbmeta-b/ 下没有 vbmeta_b-flags*.img（目录在、件不在）"
  exit 0
fi
cp -f "$_img" "$_d/$(basename "$_img")"
# 按位取反一个字节（写死写 0 在原本就是 0 的位置上等于没改 ⇒ 反作弊会假绿）
python3 - "$_d/$(basename "$_img")" <<'PYFLIP'
import sys
p = sys.argv[1]
with open(p, 'r+b') as f:
    f.seek(600)
    b = f.read(1)
    f.seek(600)
    f.write(bytes([b[0] ^ 0xff]))
PYFLIP
_rc=0
timeout 300 bash "$GEN" --check --out-dir "$_d" >/dev/null 2>&1 || _rc=$?
if [ "$_rc" -ne 0 ]; then
  ok "反作弊通过（翻字节 ⇒ --check rc=$_rc，门在读签名）"
else
  bad "反作弊失败：翻字节后 --check 仍 rc=0（门空转）"
fi
trap - EXIT INT TERM
rm -rf "$_d"
