#!/bin/bash
# lib-soft-bootloader.sh — Linux → bootloader 软路径（唯一实现；2026-11-24 按 PITFALLS #712 重写）
#
# ★ 2026-11-24 实机更正（**必须先看**）：现役根 systemd 257（Debian trixie）**移除了 `reboot` 的位置参数**，
#   `systemctl reboot bootloader` 直接报 `Too many arguments.`、rc=1、设备不动；正确写法是
#   `systemctl reboot --reboot-argument=bootloader`（同机实测 rc=0、~9 s 进 fastboot）。
#   本库据此**探测 systemctl 能力**再选形态（老 systemd 仍走位置参数），见 sb_reboot_cmd()。
#
# 判据来源：PITFALLS #712（2026-11-23 同启动内对照实测，`reports/linux-to-bl-vendor-reset-20261123.md` §0）
#   `sync; systemctl reboot bootloader`（= reboot(2) 带 cmd 串）在**无 PSCI vendor-reset 钩子**的
#   现役 vk192 上也进 fastboot（~21 s；同启动内无参 `systemctl reboot` 回 Linux 作对照）。
#   ⇒ PITFALLS #690/#701 的「Linux → BL 只能物理键 / 三条软路径全灭」**已作废**，
#     旧错因 = 静态判据（只比 kallsyms）+ 工具 fail-closed 从未真发命令。
#   本文件取代各脚本里「#701 ⇒ 拒绝发命令、直接要物理键」的旧门。
#
# 用法：
#   . "$(dirname "$0")/lib-soft-bootloader.sh"
#   soft_to_bootloader [wait_s]     # 0 = 目标 fastboot 上线；1 = 失败（调用方打物理键文案）
#
# Env：TAB（ssh 目标，默认 root@192.168.7.1）、SER（可选；给了就只认该 SN 上线）
#      SOFT_BL_WAIT（默认 90 s）
#
# 纪律：fastboot 输出一次取全再判（PITFALLS #584：`fastboot devices | grep -q` 会 SIGPIPE 打断
#       bulk 通道 ⇒ 只能物理 POR）；ssh 热复位不发 FIN（PITFALLS #628）⇒ rc=124 视为「命令已发出」。

SOFT_BL_WAIT=${SOFT_BL_WAIT:-90}

# ★ 2026-11-24 实机踩到：本机会话的 PATH 里**没有 fastboot**（在 ~/.local/opt/platform-tools），
#   旧代码用裸 `fastboot devices` ⇒ sb_fb_alive 恒假 ⇒ 明明进了 fastboot 也报「软路径失效」。
#   iPad式兜底：FB_BIN → PATH → 两个常见落点；都没有才退回裸名（由调用方报错）。
_sb_fb_bin() {
	[ -n "${_SB_FB_BIN:-}" ] && { printf '%s\n' "$_SB_FB_BIN"; return 0; }
	local c
	c=$(command -v fastboot 2>/dev/null || true)
	[ -n "$c" ] || c=""
	for c in "$c" "${HOME:-/root}/.local/opt/platform-tools/fastboot" /usr/lib/android-sdk/platform-tools/fastboot; do
		[ -n "$c" ] && [ -x "$c" ] && { _SB_FB_BIN=$c; printf '%s\n' "$c"; return 0; }
	done
	_SB_FB_BIN=fastboot
	printf '%s\n' fastboot
}

# sb_reboot_cmd —— 打印本机该用的「带 bootloader reason 的 reboot」命令
#   systemd ≥ 257 用 `--reboot-argument=`（位置参数已移除），老版本用位置参数；
#   探测走一次 ssh（结果缓存在 _SB_REBOOT_CMD，同一进程内只探一次）。
sb_reboot_cmd() {
	if [ -n "${_SB_REBOOT_CMD:-}" ]; then printf '%s\n' "$_SB_REBOOT_CMD"; return 0; fi
	local tab=${TAB:-root@192.168.7.1} probe
	if probe=$(timeout -k 5 15 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -o BatchMode=yes \
		"$tab" 'systemctl reboot --help 2>/dev/null | grep -c -- --reboot-argument' 2>/dev/null); then
		case "${probe:-0}" in
			0) _SB_REBOOT_CMD='sync; systemctl reboot bootloader' ;;
			*) _SB_REBOOT_CMD='sync; systemctl reboot --reboot-argument=bootloader' ;;
		esac
	else
		# 探不到（ssh 就没通）⇒ 给新形态；真正的失败由调用方按 rc 报
		_SB_REBOOT_CMD='sync; systemctl reboot --reboot-argument=bootloader'
	fi
	printf '%s\n' "$_SB_REBOOT_CMD"
}

# sb_fb_alive —— fastboot 通道上有（可选：指定 SN 的）设备
sb_fb_alive() {
	local d
	d=$(timeout 6 "$(_sb_fb_bin)" devices 2>/dev/null) || true
	if [ -n "${SER:-}" ]; then
		case "$d" in *"$SER"*) return 0 ;; *) return 1 ;; esac
	fi
	case "$d" in *fastboot*) return 0 ;; *) return 1 ;; esac
}

# soft_to_bootloader [wait_s]
soft_to_bootloader() {
	local wait_s=${1:-$SOFT_BL_WAIT} t=0 rc tab=${TAB:-root@192.168.7.1} cmd
	sb_fb_alive && return 0
	cmd=$(sb_reboot_cmd)
	echo "[soft-bl] Linux → bootloader：ssh $tab '$cmd'（#712 路径；systemd 257 用 --reboot-argument）" >&2
	timeout -k 5 12 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -o BatchMode=yes \
		"$tab" "$cmd" >/dev/null 2>&1
	rc=$?
	case "$rc" in
		0|124) : ;;   # 0 = 正常退出；124 = 热复位不发 FIN（#628），命令已发出
		*)
			echo "[soft-bl] ❌ ssh 复位失败 rc=$rc（设备不可达/未授权？先探活再判，别猜内核）" >&2
			return 1 ;;
	esac
	while [ "$t" -lt "$wait_s" ]; do
		sb_fb_alive && { echo "[soft-bl] ✅ fastboot 上线（${t}s）" >&2; return 0; }
		sleep 3; t=$((t + 3))
	done
	echo "[soft-bl] ❌ ${wait_s}s 内未进 fastboot（软路径本次失效 / USB 断开 / ABL 未采纳）" >&2
	return 1
}

# bl_phys_hint —— 软路径失败后的唯一正确文案（各脚本别各写一份）
bl_phys_hint() {
	echo "[soft-bl] 手动作业：长按电源 10 s 关机 → 按住【音量下 + 电源】至 fastboot 屏。" >&2
	echo "[soft-bl] 软路径判据 = PITFALLS #712；本次失败按上机实测记账，不要据此改回「只能物理键」结论。" >&2
}

# ---------------------------------------------------------------------------
# 自测（离线，打桩 ssh/fastboot；一键：bash scripts/lib-soft-bootloader.sh --selftest）
# 场景：①已在 fastboot ②ssh rc=0 且随后 fastboot 上线 ③ssh rc=124（热复位不发 FIN）视为已发出
#       ④ssh rc=255（不可达）⇒ 立刻失败 ⑤软路径发出但 fastboot 始终不上线 ⇒ 超时失败
_sb_selftest() {
	local tmp pass=0 total=0 d rc
	tmp=$(mktemp -d /tmp/sb-selftest.XXXXXX)
	mkdir -p "$tmp/bin"
	cat > "$tmp/bin/ssh" <<'EOF'
#!/bin/bash
echo "ssh-called" >> "$SB_LOG"
exit "$(cat "$SB_SSH_RC")"
EOF
	cat > "$tmp/bin/fastboot" <<'EOF'
#!/bin/bash
# 行为：$SB_FB_MODE = never|always|after
case "$SB_FB_MODE" in
	always) echo -e "HA2EXB0E\tfastboot" ;;
	after)  [ -f "$SB_FB_FLAG" ] && echo -e "HA2EXB0E\tfastboot" ;;
	*) : ;;
esac
EOF
	chmod +x "$tmp/bin/ssh" "$tmp/bin/fastboot"
	# 2026-11-27 提速（判据不变，实测单次 --selftest 6.1 s → 0.1 s）：最贵段 = 「软路径发出但
	# fastboot 始终不上线 ⇒ 超时失败」用例的固定 sleep 3 × 2 拍；打桩 no-op sleep 后走同样的
	# 轮询拍数/同一代码路径，断言不动。打桩目录就是本自测已有的 ssh/fastboot 桩目录。
	cat > "$tmp/bin/sleep" <<'EOF'
#!/bin/bash
:   # no-op（仅 selftest 用）
EOF
	chmod +x "$tmp/bin/sleep"
	run_case() { # $1=名字 $2=期望rc $3=fb_mode $4=ssh_rc $5=是否预置 fastboot 标记
		total=$((total + 1))
		: > "$tmp/log"; rm -f "$tmp/fbflag"
		[ "${5:-0}" = 1 ] && : > "$tmp/fbflag"
		set +e
		(
			PATH="$tmp/bin:$PATH"; export PATH
			SB_LOG="$tmp/log" SB_SSH_RC="$tmp/sshrc" SB_FB_MODE="$3" SB_FB_FLAG="$tmp/fbflag"
			SER=HA2EXB0E SOFT_BL_WAIT=6 TAB=root@127.0.0.1
			export SB_LOG SB_SSH_RC SB_FB_MODE SB_FB_FLAG SER SOFT_BL_WAIT TAB
			echo "$4" > "$tmp/sshrc"
			. "$0"; soft_to_bootloader 6
		) >"$tmp/out" 2>&1
		rc=$?
		set -e
		if [ "$rc" = "$2" ]; then pass=$((pass + 1)); echo "[selftest] $1 rc=$rc expect=$2 PASS"; else
			echo "[selftest] $1 rc=$rc expect=$2 FAIL"; sed 's/^/           | /' "$tmp/out"; fi
	}
	# ③ 需要 fastboot 在“shh 之后”上线：用 after + 一个后台 touch
	cat > "$tmp/bin/ssh2marker" <<'EOF'
#!/bin/bash
touch "$SB_FB_FLAG"; exit "$(cat "$SB_SSH_RC")"
EOF
	chmod +x "$tmp/bin/ssh2marker"
	# sb_reboot_cmd 的形态探测（不依赖 fastboot）
	cat > "$tmp/bin/ssh" <<'EOF2'
#!/bin/bash
echo "1"
EOF2
	chmod +x "$tmp/bin/ssh"
	c1=$( (PATH="$tmp/bin:$PATH"; export PATH; TAB=root@127.0.0.1; . "$0"; sb_reboot_cmd) )
	case "$c1" in *--reboot-argument=bootloader*) pass=$((pass+1)); echo "[selftest] reboot-cmd-new PASS" ;; *) echo "[selftest] reboot-cmd-new FAIL: $c1" ;; esac
	total=$((total+1))
	printf '#!/bin/bash\necho "0"\n' > "$tmp/bin/ssh"; chmod +x "$tmp/bin/ssh"
	c2=$( (PATH="$tmp/bin:$PATH"; export PATH; TAB=root@127.0.0.1; . "$0"; sb_reboot_cmd) )
	case "$c2" in *"reboot bootloader") pass=$((pass+1)); echo "[selftest] reboot-cmd-legacy PASS" ;; *) echo "[selftest] reboot-cmd-legacy FAIL: $c2" ;; esac
	total=$((total+1))
	cp "$tmp/bin/ssh2marker" "$tmp/bin/ssh" 2>/dev/null || true

	run_case "already-fastboot" 0 always 255 1
	cp "$tmp/bin/ssh2marker" "$tmp/bin/ssh"
	run_case "ssh-124-then-up"  0 after  124 0
	run_case "ssh-unreachable"  1 never  255 0
	run_case "no-fastboot-ever" 1 never  0   0
	rm -rf "$tmp"
	echo "== lib-soft-bootloader selftest $pass/$total PASS =="
	[ "$pass" = "$total" ]
}
if [ "${1:-}" = "--selftest" ]; then _sb_selftest; exit $?; fi
