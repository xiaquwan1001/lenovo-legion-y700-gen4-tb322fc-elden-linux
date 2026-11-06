#!/bin/bash
# 05f-abi.sh — §5f ABI 敏感项一致性（内核 ↔ 模块树）。
#
# 2026-10-23 实受：build/m1-73/.config 遗留 CONFIG_SUSPEND=y（vk128/vk129 失败实验未还原），
# 它把 struct device.of_node 从 624 推到 680；而 /lib/modules/<UTS> 当时指向 -abi-suspend
# 模块树（UTS 与内核逐字相同）⇒ vermagic 拦不住 ⇒ fastrpc 读 of_node=NULL → rpmsg 死循环、
# /dev/fastrpc-* 全缺、SSC 传感器全废；用该 config 编出的内核上机「背光亮一下即掉电」。
# 本节查两件事：(a) 构建树 .config 与 SSOT 的 ABI 敏感项；(b) vmlinux 里 of_node 偏移可读。
. "$(dirname "$0")/_lib.sh"

section '5f. ABI 敏感项一致性（内核 ↔ 模块树）'
_abi_trees=""
# 2026-11-05 清理后改为**动态发现**：任何 build/*/.config 或 linux/.config 都参与核对
# （原写死 build/m1-73 等，树被归档后会静默跳过 ⇒ 门禁失效）。
for _c in build/*/.config linux/.config; do
  [ -f "$_c" ] && _abi_trees="$_abi_trees ${_c%/.config}"
done
if [ -z "$_abi_trees" ]; then
  warnf "未找到任何内核树的 .config（build/*/ 或 linux/）→ 跳过（重建树后自动恢复核对）"
else
  for _t in $_abi_trees; do
    _abi_out=$(bash "$HELPERS/check-abi-config.sh" "$_t/.config" 2>&1)
    if [ $? -eq 0 ]; then
      ok "$_t/.config ABI 敏感项与 SSOT 一致"
    else
      _d=$(printf '%s\n' "$_abi_out" | grep -E '\[FAIL\]' | sed -E 's/^ +\[FAIL\] +//' | tr '\n' ';' | cut -c1-200)
      bad "$_t/.config ABI 敏感项漂移（与机内模块树不兼容）: $_d"
    fi
  done
fi

_of_tree=$(for _t in $_abi_trees; do [ -f "$_t/vmlinux" ] && { echo "$_t"; break; }; done)
if [ -n "${_of_tree:-}" ] && command -v pahole >/dev/null 2>&1; then
  _off=$(pahole -C device "$_of_tree/vmlinux" 2>/dev/null | awk '/struct device_node \* +of_node/{gsub(/\*/,"",$(NF-2)); print $(NF-2)}' | tr -d ';')
  if [ -n "$_off" ]; then
    ok "$_of_tree vmlinux: struct device.of_node @ $_off（部署的模块必须读同一偏移）"
  else
    warnf "$_of_tree/vmlinux 取不到 of_node 偏移（pahole 无该成员？）"
  fi
else
  [ -n "${_of_tree:-}" ] && warnf "缺 pahole 或 $_of_tree/vmlinux → 跳过 of_node 偏移核对"
fi
