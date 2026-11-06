#!/bin/bash
# lib-ssh.sh — 设备 SSH 调用的单一实现（选项统一 + 一次往返批量取状态）
#
# 为什么有这个库（2026-11-05 脚本审计 P2）：
#   * 53 个脚本各自内联 `ssh -o StrictHostKeyChecking=...`，实测 7 种不同写法
#     （有的带 BatchMode=yes，有的带 UserKnownHostsFile=/dev/null，超时 4/5/6/8 s 不等）——
#     于是「同一台设备，不同脚本的连接行为不同」，其中「不带 BatchMode」的那些在首次连接
#     时会停下来等密码提示，把脚本挂死。
#   * 更贵的是**往返次数**：lib-boot-ready.sh 就绪判定原先发 4 条顺序 ssh
#     （echo up / uptime / phoc / phosh，可选第 5 条 dmesg），弱链路/忙设备上每条 0.3–15 s
#     ⇒ 最坏 40 s 才得出「能不能重启」；而它们完全可以合成**一条**远端命令，
#     还顺带获得「同一时刻快照」的语义（分开发 4 条，前后可能跨秒）。
#
# 用法：
#   . "$(dirname "$0")/lib-ssh.sh"
#   S 'uname -r' 8                     # 跑一条远端命令（stdout 原样返回；失败返回非 0）
#   S_alive || echo 设备不在 Linux
#   out=$(S_kv 'up=cut -d. -f1 /proc/uptime' 'phoc=ps -eo comm | grep -cx phoc')
#   up=$(S_kv_get "$out" up)           # 取一个键（缺省返回空）
#
# 约定：远端命令里**不要**再用单引号包整串（本库已经替你 quote）；多行脚本用 --stdin。
#   S --stdin 15 <<'EOS'
#   ...多行...
#   EOS
#
# 可覆盖环境变量：TAB / TABLET（默认 root@192.168.7.1）、SSH_OPTS、S_TIMEOUT（默认 10）
: "${TAB:=${TABLET:-root@192.168.7.1}}"
: "${SSH_OPTS:=-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR}"
: "${S_TIMEOUT:=10}"

# S <cmd> [timeout]     或     S --stdin [timeout]
S() {
	local tmo=$S_TIMEOUT
	if [ "${1:-}" = "--stdin" ]; then
		[ $# -ge 2 ] && tmo=$2
		timeout "$tmo" ssh $SSH_OPTS "$TAB" 'sh -s' 2>/dev/null
		return $?
	fi
	local cmd=$1
	[ $# -ge 2 ] && tmo=$2
	timeout "$tmo" ssh $SSH_OPTS "$TAB" "$cmd" 2>/dev/null
}

S_alive() { [ "$(S 'echo up' 8)" = up ]; }

# S_kv 'KEY=shell 片段' ... → 一次往返取多个状态，输出 `KEY=值` 每行一个。
# 片段里的引号由调用方自己负责（它就是远端 shell 片段），因此别放会吞掉输出的重定向。
S_kv() {
	local body="" pair
	for pair in "$@"; do
		body="$body printf '%s=' '$(_kv_key "$pair")'; $(_kv_cmd "$pair") 2>/dev/null; echo;"
	done
	S "$body" "${S_KV_TIMEOUT:-$S_TIMEOUT}"
}

_kv_key() { printf '%s' "${1%%=*}"; }
_kv_cmd() { printf '%s' "${1#*=}"; }

# S_kv_get '<KEY=值 多行>' KEY → 值（缺省空）
S_kv_get() {
	printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1
}
