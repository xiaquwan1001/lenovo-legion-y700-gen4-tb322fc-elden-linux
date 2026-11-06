#!/bin/bash
# 05e-manifest.sh — §5e manifest 完整性（构建产物身份可对账）。
# 正常 build-manifest.sh 始终写 config_sha256；缺号 = 手写 manifest 旁路。
# 2026-10-10 #162：vk81/82/83 死内核的 manifest 全缺号 → 事后无从对账。
# 历史事故见 versions/manifest-incomplete-allowlist.txt（白名单降 WARN）。
. "$(dirname "$0")/_lib.sh"

section '5e. manifest 完整性（构建产物身份可对账）'
_wf=versions/manifest-incomplete-allowlist.txt
declare -A _wfallow=()
if [ -f "$_wf" ]; then
  while read -r _name _rest; do
    [ -z "$_name" ] && continue
    case "$_name" in \#*) continue ;; esac
    _wfallow["$_name"]=1
  done < "$_wf"
fi
_miss=(); _waived=0; _hist=0
# 纪律起始日：2026-10-10（#162 事故当天 manifest 完整性纳入流程）。此前的 ad-hoc 构建
# 一律 grandfather，不再逐个白名单。
_CUTOFF="2026-10-10"
for _m in out/*.manifest; do
  [ -e "$_m" ] || continue
  grep -qE '^config_sha256=[0-9a-f]{64}' "$_m" && continue
  _b=$(basename "$_m")
  if [ -n "${_wfallow[$_b]:-}" ]; then _waived=$((_waived+1)); continue; fi
  _gen=$(grep -m1 '^generated=' "$_m" | cut -d= -f2 | cut -c1-10)
  if [ -n "$_gen" ] && [[ "$_gen" < "$_CUTOFF" ]]; then _hist=$((_hist+1)); continue; fi
  _miss+=("$_b")
done
if [ ${#_miss[@]} -eq 0 ]; then
  ok "所有 ≥$_CUTOFF 的 manifest 含 config_sha256（白名单 $_waived / 历史 grandfather $_hist）"
else
  bad "manifest 缺 config_sha256（应走 scripts/build-manifest.sh，勿手写）: ${_miss[*]}"
fi
