#!/bin/bash
# lib-fastboot.sh — fastboot / ssh 设备调用的安全封装（2026-11-09 工具挂死调查产物）
#
# 报告：reports/tooling-hang-investigation-20261109.md
# 三个根因，对应三条纪律：
#   ① 一条 shell 命令里**不同时**出现 ssh 与 fastboot —— 两次挂死实例的挂点都是
#      命令链开头的裸 ssh（板子 reboot 进 bootloader 后网络消失，已建立的 TCP
#      连接按 tcp_retries2=15 重传 ~15 分钟，timeout 包的是后面的 fastboot，
#      根本没执行到）。先 ssh 拿到结果，再单发 fastboot。
#   ② 所有 fastboot 必须包 `timeout -k 2 N`（-k 保证 SIGTERM 被忽略/D 状态时补
#      SIGKILL），且输出**永不进管道**（SIGPIPE 打断 bulk 通道，PITFALLS #584）。
#   ③ ssh 必须带 BatchMode + ConnectTimeout + ServerAlive*（见 sshc），
#      否则板子中途断网 = 挂 15 分钟。
#
# 用法：
#   . "$(dirname "$0")/lib-fastboot.sh"
#   SER=HA2EXB0E
#   fbx getvar product                 # → 落 $_FB_OUT，rc 可靠
#   fbdevices && echo "目标在线"       # 是否有目标 SN（SER 可空 = 任意设备）
#   sshc 'uptime'                      # 带全套超时的 ssh
#
# 环境变量：SER（目标序列号，fbx 必填）、FBTO（默认 30s）、TAB（ssh 目标，默认
#   root@192.168.7.1）。多设备总线必须显式 SER（PITFALLS #569）。

: "${TAB:=${TABLET:-root@192.168.7.1}}"
: "${FBTO:=30}"
_FB_TMPDIR=${FBTMPDIR:-${TMPDIR:-/tmp}}
_FB_OUT=""   # 最近一次 fbx 的 stdout（先落文件再读，绝不进管道）

# fbx <fastboot 子命令...>
#   等价 `timeout -k 2 $FBTO fastboot -s "$SER" "$@"`；stdout 存 $_FB_OUT。
#   rc: 0 成功；124/137 超时被杀；其余为 fastboot 自身错误码。
fbx() {
	[ -n "${SER:-}" ] || { echo "[fbx] SER 为空 — 拒绝裸 fastboot（#569）" >&2; return 64; }
	local f; f=$(mktemp "$_FB_TMPDIR/fbx.XXXXXX") || return 70
	timeout -k 2 "$FBTO" fastboot -s "$SER" "$@" >"$f" 2>&1
	local rc=$?
	_FB_OUT=$(cat "$f")
	[ -n "${FBX_KEEP:-}" ] || rm -f "$f"
	return $rc
}

# fbdevices [SN]
#   `timeout -k 2 10 fastboot devices`，返回 0 当且仅当列表里出现目标 SN
#   （省略 SN 时用 $SER；两者都空 = 只要有任何 fastboot 设备就算在线）。
#   结果在 $_FB_OUT（一行一设备："SN\t..."）。
fbdevices() {
	local sn=${1:-${SER:-}}
	local f; f=$(mktemp "$_FB_TMPDIR/fbd.XXXXXX") || return 70
	timeout -k 2 10 fastboot devices >"$f" 2>/dev/null
	local rc=$?
	_FB_OUT=$(cat "$f")
	rm -f "$f"
	[ $rc -eq 0 ] || return $rc
	if [ -n "$sn" ]; then
		case "$_FB_OUT" in *"$sn"*) return 0 ;; *) return 1 ;; esac
	fi
	[ -n "$_FB_OUT" ]
}

# sshc <远端命令...> [timeout]
#   带全套超时的 ssh：BatchMode（不挂密码提示）、ConnectTimeout=8（连不上 8 s 放弃）、
#   ServerAliveInterval=5 + CountMax=2（**已建立连接**对端消失后 ~10 s 判死，而不是
#   tcp_retries2 的 ~15 分钟 —— 这正是两次挂死的直接原因）。
sshc() {
	local tmo=${SSHC_TO:-20}
	# 最后一个纯数字参数当 timeout（可选）
	if [ $# -gt 1 ] && [[ "${@: -1}" =~ ^[0-9]+$ ]]; then
		tmo=${@: -1}; set -- "${@:1:$(($#-1))}"
	fi
	timeout -k 2 "$tmo" ssh -o BatchMode=yes -o ConnectTimeout=8 \
		-o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
		-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-o LogLevel=ERROR "$TAB" "$@"
}
