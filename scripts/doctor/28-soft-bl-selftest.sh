#!/bin/bash
# 28-soft-bl-selftest.sh — §28 Linux→bootloader 软路径门（lib-soft-bootloader 自检 + 反作弊 + 反回归）
# 立此节的原因（2026-11-24）：`scripts/lib-soft-bootloader.sh` 现在是**所有**「进 fastboot」脚本的唯一实现
# （PITFALLS #712 推翻 #690/#701 后的收口，2026-11-24 已接进 10+ 个脚本），但它自己的 --selftest 之前
# 不属于任何门 ⇒ 改坏了只有上机时才会发现（而「上机」正是最贵的环节）。
# 本门钉三件事：
#   ① 库自检必须 4/4 通过（已在 fastboot / rc=0 / rc=124 视为已发出 / 不可达 / 始终不上线）；
#   ② 反作弊：把库里「rc=124 视为已发出」那条删掉后自检**必须**变红（否则说明自检是死门）；
#   ③ 反回归：不许再有脚本调设备侧 `eldroid-bootctl reboot bootloader`（python3 件，现役 Debian 根无
#      python3 ⇒ `|| true` 静默 no-op；2026-11-24 已逐处换成软路径库）。
. "$(dirname "$0")/_lib.sh"

section '28. Linux→bootloader 软路径（lib-soft-bootloader 自检 + 反作弊 + 禁 eldroid-bootctl）'

LIB="$ROOT/scripts/lib-soft-bootloader.sh"
if [ ! -f "$LIB" ]; then
  bad "scripts/lib-soft-bootloader.sh 缺失（所有「进 fastboot」脚本的唯一实现）"
  exit 0
fi

# ① 库自检
_rc=0
_out=$(timeout 180 bash "$LIB" --selftest 2>&1) || _rc=$?
if [ "$_rc" -eq 0 ] && printf '%s' "$_out" | grep -q 'selftest 4/4 PASS'; then
  ok "自检 4/4 通过（已在 fastboot / rc=0 / rc=124 视已发出 / 不可达 / 始终不上线）"
else
  bad "lib-soft-bootloader --selftest 失败（rc=$_rc）：$(printf '%s' "$_out" | grep -E 'FAIL|ERROR' | head -2 | tr '\n' ' ')"
fi

# ② 反作弊：删掉「rc=124 视为已发出」后自检必须变红
_tmp=$(mktemp -d /tmp/soft-bl-cheat.XXXXXX)
sed 's/0|124) : ;;/0) : ;;/' "$LIB" > "$_tmp/lib-broken.sh"
if cmp -s "$LIB" "$_tmp/lib-broken.sh"; then
  bad "反作弊探针失效：没能改坏库（rc=124 分支的写法变了？同步更新本节）"
elif timeout 180 bash "$_tmp/lib-broken.sh" --selftest >"$_tmp/out" 2>&1; then
  bad "反作弊失败：把 rc=124 分支改坏后自检仍然全绿 ⇒ 自检是死门"
else
  ok "反作弊通过（改坏 rc=124 分支 ⇒ 自检变红）"
fi
rm -rf "$_tmp"

# ③ 反回归：不许再调设备侧 eldroid-bootctl 的 reboot（注释行不算）
_hits=$(grep -n 'eldroid-bootctl reboot' "$ROOT"/scripts/*.sh 2>/dev/null \
  | grep -v ':[0-9]*:[[:space:]]*#' | grep -v 'lib-soft-bootloader.sh:' || true)
if [ -n "$_hits" ]; then
  bad "仍有脚本调设备侧 eldroid-bootctl（现役根无 python3 ⇒ 静默 no-op）：$(printf '%s' "$_hits" | head -3 | cut -d: -f1 | tr '\n' ' ')"
else
  ok "没有脚本再调设备侧 eldroid-bootctl reboot（注释除外）"
fi
