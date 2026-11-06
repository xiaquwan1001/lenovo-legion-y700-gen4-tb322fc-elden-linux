#!/bin/bash
# 12-modular.sh — §12 驱动模块化门禁（锚点不回退 / olddefconfig 幂等 / tristate 自洽）。
# 立此节的原因（2026-10-27 收尾轮）：scripts/check-modular-config.sh 2026-10-26 就写好了，
# 但没有任何调用方 —— 与 §11 同类问题：门写在仓库里，实际从不执行。
#
# 2026-11-05 脚本审计两点调整：
#   ① 本节**移出 --staged-fast（pre-commit）档**：它只与内核 .config 有关，和文档/索引提交
#      完全无关，却是 fast 档里唯一的大头（实测 3.2 s / fast 档总 3.8 s）。
#      代价：pre-commit 不再拦「手改了 .config 又提交」；该情形由收尾轮的全量 doctor 兜住。
#   ② 委托脚本内部加了「结论缓存」（键 = .config + 锚点 + 脚本 + Kconfig 树最新 mtime），
#      稳态 3.2 s → 0.06 s，全量 doctor 也不再为同一份 config 反复跑 make olddefconfig。
. "$(dirname "$0")/_lib.sh"

MODCFG="${ELF_MODULAR_CFG:-$HELPERS/check-modular-config.sh}"

section '12. 驱动模块化门禁（锚点不回退 / olddefconfig 幂等 / tristate 自洽）'
_mcfg_tree=$(sed -e 's/#.*//' -e 's/[[:space:]]*$//' patches/current-tree 2>/dev/null | grep -v '^$' | head -1)
[ -z "${_mcfg_tree:-}" ] && _mcfg_tree=$(for _c in build/*/.config; do [ -f "$_c" ] && { echo "${_c%/.config}"; break; }; done)
if [ -z "${_mcfg_tree:-}" ] || [ ! -f "$_mcfg_tree/.config" ]; then
  warnf "无构建树可用（patches/current-tree = ${_mcfg_tree:-空}）→ 跳过模块化门禁（重建树后自动恢复；不影响入库）"
elif [ ! -f "$MODCFG" ]; then
  bad "scripts/check-modular-config.sh 缺失"
else
  if _mo=$(ROOT="$ROOT" bash "$MODCFG" 2>&1); then
    ok "模块化 config 门禁通过（$(printf '%s' "$_mo" | grep -c '^PASS:') 项 PASS）"
  else
    bad "模块化 config 门禁失败：$(printf '%s' "$_mo" | grep -E '^FAIL' | head -3 | tr '\n' ' ')"
  fi
fi
