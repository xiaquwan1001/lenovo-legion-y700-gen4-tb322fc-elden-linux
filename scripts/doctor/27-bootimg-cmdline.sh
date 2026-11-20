#!/bin/bash
# 27-bootimg-cmdline.sh — §27 boot/vendor_boot cmdline 改写器自检门（委托脚本自带 --selftest）。
# 立此节的原因（2026-11-21）：S5「console=ttyGS0 取证件」依赖 scripts/boot-img-cmdline.py 的
# 等长原地改写（v3/v4 boot + vendor_boot v3/v4）。这类「只写窗口、窗口外必须逐字节不变」的
# 工具**没有门就只靠人记**：2026-11-20 上线时只有一次性验证（reports/bootimg-v4-cmdline-20261120.md），
# 2026-11-21 加 vendor_boot 支持时同样只能靠手跑。本门把 4 正例 + 4 反例固化成一次运行：
#   正例：boot v3/v4、vendor_boot v3/v4 —— `--verify` 逐字节全等 + `--append` 后窗口外不变
#   反例：坏 header_size / 截断件 / 坏 magic / 超长 cmdline 必须被拒
# 三态：脚本缺 ⇒ FAIL；环境缺 python3 ⇒ warn SKIP（不装成 PASS）；selftest rc≠0 ⇒ FAIL。
. "$(dirname "$0")/_lib.sh"

section '27. boot/vendor_boot cmdline 改写器（等长原地改写，含反例自检）'

TOOL="$HELPERS/boot-img-cmdline.py"
if [ ! -f "$TOOL" ]; then
  bad "scripts/boot-img-cmdline.py 缺失（S5 取证件链的被委托件）"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf '  [warn] SKIP：环境缺 python3，无法跑 --selftest\n'
  exit 0
fi

_rc=0
_out=$(timeout 180 python3 "$TOOL" --selftest 2>&1) || _rc=$?
if [ "$_rc" -eq 0 ] && printf '%s' "$_out" | grep -q 'selftest PASS'; then
  ok "$(printf '%s' "$_out" | grep 'selftest PASS' | head -1)"
else
  bad "boot-img-cmdline --selftest 失败（rc=$_rc）：$(printf '%s' "$_out" | grep -E '\[FAIL\]|ERROR' | head -2 | tr '\n' ' ')"
fi

# 产物侧：S5 的两个件若在位，必须能 --verify（缺件只 warn，件在但不自洽 = FAIL）
for f in "$ROOT/out/android-v3-bringup-20261120/boot-ttygs0-boot.img" \
         "$ROOT/out/android-v3-bringup-20261120/boot-ttygs0-vendor_boot.img"; do
  [ -f "$f" ] || { warnf "产物缺件：${f#$ROOT/}（S5 要用时按报告一键造，非阻塞）"; continue; }
  _rc=0
  _out=$(timeout 300 python3 "$TOOL" "$f" --verify 2>&1) || _rc=$?
  if [ "$_rc" -eq 0 ] && printf '%s' "$_out" | grep -q 'verify PASS'; then
    ok "$(basename "$f")：往返逐字节全等"
  else
    bad "$(basename "$f")：--verify 失败（rc=$_rc）→ 重造该件"
  fi
done
