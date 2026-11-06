#!/bin/bash
# lib-wait.sh — 「等设备到某个状态」的单一实现（check-first + 指数退避 + 换代判据）
#
# 为什么有这个库（2026-11-05 脚本审计 P2）：
#   全仓有 6 处各写一遍的等待循环，模式都是 `for i in $(seq 1 N); do sleep 2; 探测; done`：
#     cycle.sh wait_fastboot/wait_linux、to-fastboot.sh(45×2 s)、kexec-boot.sh(60×3 s)、
#     flash-b.sh(90×2 s)、slot-switch.sh wait_fastboot/wait_adb/wait_linux(60×5 s)。
#   三个共同缺陷：
#     ① **先睡再判**：设备 3 s 就绪也要白等一整拍（每次实验都付）；
#     ② 固定间隔、无退避：冷启动前期最该密查，后期该放宽；
#     ③ **判据太弱**：`wait_linux` 只测 `ssh true`，重启前那一瞬间旧系统还在答
#        ⇒ 脚本以为「起来了」，其实新内核还没跑起来（假成功，比慢更糟）。
#   本库把这三件事一次解决，并提供换代判据（boot_id 变化才算换过启动）。
#
# 用法：
#   . "$(dirname "$0")/lib-wait.sh"
#   wait_until "描述" 90 ssh_alive            # 通用：probe 返回 0 = 就绪
#   wait_reboot ssh_alive 180                 # 换代：先取 boot 指纹，再等它变了且 probe 就绪
#   wait_fastboot 90 ; wait_linux 180 ; wait_adb <serial> 300
#
# 可选环境变量：
#   WAIT_QUIET=1          不打印每次重试的日志（默认打印）
#   WAIT_INTERVALS="..."  自定义退避序列（秒），默认 0.3 0.5 1 1 2 2 3（之后按 3 s）
#   TAB / TABLET          ssh 目标（默认 root@192.168.7.1）；TAB 优先
#   SSH_OPTS              ssh 选项（默认 BatchMode + 不查 known_hosts + ConnectTimeout 5）
# 依赖：timeout、ping、ssh、fastboot、adb（后两者仅对应 wrapper 用）。

: "${TAB:=${TABLET:-root@192.168.7.1}}"
: "${SSH_OPTS:=-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR}"
WAIT_INTERVALS=${WAIT_INTERVALS:-"0.3 0.5 1 1 2 2 3"}

_wait_log() { [ "${WAIT_QUIET:-0}" = 1 ] || printf '[wait] %s\n' "$*" >&2; }

# 毫秒时钟：$SECONDS 只有整秒精度，会让「超时预算 1 s」实际在 0.1–1.0 s 之间随机提前放弃
# （实测 807 ms 就退出）。EPOCHREALTIME 是 bash 5 内建，取不到时退回 date。
# "0.3" / "2" → 毫秒整数（纯 bash，不启 awk/浮点）
_sec_to_ms() {
	local i=${1%%.*} f=000
	case "$1" in *.*) f="${1#*.}" ;; esac
	printf '%s' $(( i * 1000 + 1${f:0:3} - 1000 ))
}

_now_ms() {
	if [ -n "${EPOCHREALTIME:-}" ]; then
		local t=${EPOCHREALTIME//[.,]/}
		printf '%s' $((t / 1000))
	else
		date +%s%3N
	fi
}

# wait_until <描述> <超时秒> <probe 命令...>
#   probe 的 stdout/stderr 一律丢弃（探测常带“连接被拒绝”之类噪声），只看返回码。
wait_until() {
	local label=$1 tmo=$2
	shift 2
	local t0 n i=0 ival_ms rem_ms elapsed
	t0=$(_now_ms)
	local ints=() _s
	# shellcheck disable=SC2206  # 有意按空格拆分
	for _s in $WAIT_INTERVALS; do ints+=("$(_sec_to_ms "$_s")"); done
	n=${#ints[@]}
	while :; do
		if "$@" >/dev/null 2>&1; then
			_wait_log "$label ok (~$((($(_now_ms) - t0) / 1000))s)"
			return 0
		fi
		elapsed=$((($(_now_ms) - t0) / 1000))
		if [ "$elapsed" -ge "$tmo" ]; then
			_wait_log "$label 超时 ${tmo}s"
			return 1
		fi
		# 退避 + 不超预算：最后一拍只睡「剩余预算」，避免「1 s 的超时实际等 1.8 s」
		ival_ms=${ints[$((i < n ? i : n - 1))]}
		i=$((i + 1))
		rem_ms=$((tmo * 1000 - ($(_now_ms) - t0)))
		[ "$ival_ms" -gt "$rem_ms" ] && ival_ms=$rem_ms
		[ "$ival_ms" -le 0 ] && continue
		sleep "$(printf '%d.%03d' $((ival_ms / 1000)) $((ival_ms % 1000)))"
	done
}

# ------------------------------------------------------------------ 探测原语
wa_ssh_alive() { [ "$(timeout 8 ssh $SSH_OPTS "$TAB" 'echo up' 2>/dev/null)" = up ]; }
wa_fastboot_alive() { timeout 6 fastboot devices 2>/dev/null | grep -q .; }
wa_adb_alive() { # $1 = 序列号（必填：PITFALLS #371，裸 get-state 会把别的手机当成本机）
	[ -n "${1:-}" ] && [ "$(timeout 8 adb -s "$1" get-state 2>/dev/null | tr -d '\r')" = device ]
}

wait_ssh() { wait_until "ssh $TAB 可达" "${1:-120}" wa_ssh_alive; }
wait_fastboot() { wait_until "fastboot 上线" "${1:-120}" wa_fastboot_alive; }
wait_adb() { # wait_adb <serial> [timeout]
	local ser=$1
	wait_until "adb $ser 上线" "${2:-300}" wa_adb_alive "$ser"
}

# ------------------------------------------------------------------ 换代判据
# 「新系统起来了」≠「有东西在答」。重启/换内核前先把设备启动指纹拍下来，之后只认**变了**。
#   boot_id 变          ⇒ 确实换过一次启动（首选判据）；
#   boot_id 取不到      ⇒ 退化为 uptime 明显变小（< 上次 - 5 s）。
DEV_BOOT_ID=""
DEV_UPTIME=0

wait_boot_capture() {
	local out
	out=$(timeout 8 ssh $SSH_OPTS "$TAB" \
		'cat /proc/sys/kernel/random/boot_id 2>/dev/null; cut -d. -f1 /proc/uptime' 2>/dev/null | tr '\n' ' ')
	DEV_BOOT_ID=${out%% *}
	DEV_UPTIME=${out##* }
	case "$DEV_UPTIME" in '' | *[!0-9]*) DEV_UPTIME=0 ;; esac
	_wait_log "captured boot_id=${DEV_BOOT_ID:-?} uptime=${DEV_UPTIME}s"
}

wa_boot_changed() {
	local out id up
	out=$(timeout 8 ssh $SSH_OPTS "$TAB" \
		'cat /proc/sys/kernel/random/boot_id 2>/dev/null; cut -d. -f1 /proc/uptime' 2>/dev/null | tr '\n' ' ')
	id=${out%% *}
	up=${out##* }
	case "$up" in '' | *[!0-9]*) up=0 ;; esac
	[ -n "$out" ] || return 1
	if [ -n "$DEV_BOOT_ID" ] && [ -n "$id" ]; then
		[ "$id" != "$DEV_BOOT_ID" ] || return 1
	else
		[ "$up" -gt 0 ] && [ "$DEV_UPTIME" -gt 0 ] && [ "$up" -lt $((DEV_UPTIME - 5)) ] || return 1
	fi
	wa_ssh_alive
}

# 「新鲜启动」判据：拿不到重启前指纹时（典型：从 fastboot 重启、或脚本刚起来就要判）
# 用 uptime 足够小来证明这是**这一次**开机，而不是「reboot 命令还没生效的旧系统」。
wa_uptime() { timeout 8 ssh $SSH_OPTS "$TAB" 'cut -d. -f1 /proc/uptime' 2>/dev/null | tr -dc '0-9'; }
wa_fresh_boot() { # $1 = 上限秒数
	local up
	up=$(wa_uptime)
	[ -n "$up" ] || return 1
	wa_ssh_alive && [ "$up" -lt "${1:-180}" ]
}

# wait_fresh_boot <超时秒> [uptime 上限秒]
#   等到「ssh 可达 且 uptime < 上限」。用于无重启前指纹的场景（切槽恢复、冷启动后回读）。
wait_fresh_boot() {
	local tmo=${1:-300} max=${2:-180}
	wait_until "新鲜启动（uptime<${max}s）" "$tmo" wa_fresh_boot "$max"
}

# wait_reboot <probe> <超时秒> [cwd 无关]
#   拍指纹 → 等 probe 就绪 且 启动指纹已变。第一次探测前先给 0.5 s 让远端真的开始重启，
#   避免把「重启命令还没生效、旧系统仍在答」判成成功。
wait_reboot() {
	local probe=$1 tmo=${2:-180}
	wait_boot_capture
	sleep 0.5
	wait_until "换启动完成（boot_id 变化）" "$tmo" wa_boot_changed && return 0
	# 换代判据不可用（如 RAM 变体不写 boot_id）时退化为单纯可达，但**明确告警**
	_wait_log "换代判据未满足 → 退化为可达性判定（仅供参考，勿据此判『新内核已跑』）"
	wait_until "回连（降级）" "$tmo" "$probe"
}
