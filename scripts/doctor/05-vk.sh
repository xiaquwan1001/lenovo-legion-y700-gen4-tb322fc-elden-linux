#!/bin/bash
# 05-vk.sh — §5 vk 版本账 + §5d 内核身份表（同一次全量扫描产出两节）。
#
# 背景：vk52-slim 曾被静默打进 vk42 内核（manifest kernel_release 与镜像 UTS 自相矛盾），
# 当时无人校验。旧版此处内联 python + §5d 再调 --gate/--check，同一批镜像被 gzip 解压
# **三遍**（墙钟 ~110 s）。现在单次 `vk-identity.py --all` 同时产出 §5(L)/§5d(G)/新鲜度(C)，
# 且载荷解压走跨调用磁盘缓存（未变动的镜像零解压，2026-11-05）。
. "$(dirname "$0")/_lib.sh"

# 可覆盖的助手路径：验收 A/B 时用暂存副本替掉本仓版本（安装后无需设置）。
VKID="${ELF_VK_IDENTITY:-$HELPERS/vk-identity.py}"

section '5. vk 版本账（registry / manifest / 镜像内 UTS）'
# 单次调用：一次全量扫描同时产出 §5 结论、§5d 门禁、§5d 新鲜度。
_all=$(python3 "$VKID" --all 2>/dev/null)
_ledger_st=(); _ledger_msg=(); _gate_st=(); _gate_msg=(); _cst=""
while read -r _tag _st _msg; do
  case "$_tag" in
    L) _ledger_st+=("$_st"); _ledger_msg+=("$_msg") ;;
    G) _gate_st+=("$_st"); _gate_msg+=("$_msg") ;;
    C) _cst="$_st" ;;
  esac
done <<< "$_all"
if [ ${#_ledger_st[@]} -eq 0 ]; then
  # 反静默（2026-10-19 实测教训）：vk-identity.py 曾因一行语法错误而完全无法运行，
  # 而这里只报「python3 缺失？」的 warn ⇒ 整个 §5/§5d 静默失效，git 的 stat 缓存还让
  # 文件显示「未修改」，更难发现。现在先做语法自检，语法坏 = FAIL（不是 warn）。
  if ! python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$VKID" 2>/dev/null; then
    bad "scripts/vk-identity.py 有语法错误，vk 版本账/内核身份检查全部失效（跑 python3 scripts/vk-identity.py 看报错）"
  else
    warnf "vk 版本账检查未产出结果（python3 缺失或脚本运行失败，请手工跑 scripts/vk-identity.py --all 确认）"
  fi
else
  for _i in "${!_ledger_st[@]}"; do
    case "${_ledger_st[$_i]}" in
      OK)   ok   "${_ledger_msg[$_i]}" ;;
      WARN) warnf "${_ledger_msg[$_i]}" ;;
      FAIL) bad  "${_ledger_msg[$_i]}" ;;
    esac
  done
fi

# ---------------------------------------------------------------- 5d. 内核身份表
# §5 只看 boot-elden-vk*.img、且只比 manifest 内部两个同源字段（永远相等），抓不到
# 「同 UTS 串不同二进制」和「vk 号其实装的是别的号的内核」。这里补上。
section '5d. 内核身份表（号 ↔ 内核二进制 ↔ 源提交）'
if [ ${#_gate_st[@]} -eq 0 ]; then
  warnf "内核身份检查未产出结果（python3 / geekidos-linux 缺失？）"
else
  for _i in "${!_gate_st[@]}"; do
    case "${_gate_st[$_i]}" in
      OK)    ok   "${_gate_msg[$_i]}" ;;
      WARN)  warnf "${_gate_msg[$_i]}" ;;
      FAIL)  bad  "${_gate_msg[$_i]}" ;;
      *)     warnf "身份表检查输出无法解析：${_gate_st[$_i]} ${_gate_msg[$_i]}" ;;
    esac
  done
fi
# MIGRATION-LOST 例外（2026-10-17）：换机后 out/*.img 全部未随迁，身份表重生成只能产出
# (slot-dump)/(no-payload) 两行 ⇒ 新鲜度比对失去物理含义（比的是「镜像在不在」而非「表过期」）。
# 此时降级为 warn：表保留为历史账（它记录的镜像 sha 已不可再生成，删掉即永久失账）。
_img_n=$(ls out/boot-elden-*.img 2>/dev/null | wc -l)
if [ "$_cst" = "0" ]; then
  ok "versions/vk-kernel-identity.tsv 与当前镜像/registry/内核 ref 一致"
elif [ "$_img_n" -eq 0 ]; then
  warnf "内核身份表无法新鲜度比对：out/*.img 为 0（MIGRATION-LOST，见 reports/migration-rebuild-audit-20261017.md P4）——表按历史账保留、不重生成"
else
  bad "内核身份表已过期 → 跑 scripts/vk-identity.py > versions/vk-kernel-identity.tsv 并重提交"
fi
