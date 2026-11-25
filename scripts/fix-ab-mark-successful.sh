#!/bin/sh
# fix-ab-mark-successful.sh — 让设备每次启动都把自己所在的 A/B 槽标记为「启动成功」。
#
# 为什么（2026-10-11 实测，PITFALLS #181）：
#   Alpine rootfs 自带 /etc/init.d/qbootctl（command="qbootctl" command_args="-m"），
#   但 **它不在任何 runlevel 里** ⇒ BOOT_SUCCESSFUL 位永远不置位 ⇒ ABL 每次启动都把
#   当前槽的 tries_remaining 减 1 ⇒ ~7 次重启后计数归零、槽被标 UNBOOTABLE，
#   设备直接停在 fastboot（表现为「启动次数用尽卡 fastboot」）。
#   受 Q28 所迫频繁重启的机器必然踩到。
#   另一个小坑：原脚本用 `command=`/`default_start`，对一个「跑完即退」的命令，
#   OpenRC status 会报 **crashed**（无 pidfile）——功能上仍会标记，但状态误导；
#   本脚本改成显式 start(){ ebegin/eend }，status 正常显示 started。
#
# 2026-11-22 重写（现役根是 Debian/systemd，不是 Alpine/OpenRC）：
#   · 运行期逻辑收进本脚本的 `--mark-once`（被 systemd 单元
#     rootfs/debian/units-extra/ab-mark-successful.service 调用），单元本身不再内联
#     `/bin/sh -c '…'`（旧版把 sed 正则 + python3 调用塞进 ExecStart 的引号层里，
#     既无法 `systemd-analyze verify` 细看，也把错误全吞在 `|| true` 后面）。
#   · 槽位判据改为 **`qbootctl -a` 的 active 槽**。旧版读 /proc/cmdline 的
#     `androidboot.slot_suffix`：那个值烤死在 boot.img 头里（PITFALLS #601），
#     从 boot_a 起来也照样显示 `_b` ⇒ 会给错的槽置成功、真槽继续扣 retry。
#   · 不再写 LUN4 的 GPT 属性（旧版 `slot-attr.py --device /dev/sde --allow-wrong-lun`）：
#     `--allow-wrong-lun` 恰好**关掉**了「LUN 不对就拒写」的自检（scripts/slot-attr.py
#     :403/:431），而现役 Debian 根**没有 python3**（PITFALLS #525/#400 同族；#690 是 psci 钩子，别再引）⇒ 那一段在本机
#     从来是静默 no-op。retry 补写降级为显式 `--retry-topup`（见下）。
#   · 失败可见：`--mark-once` 写后**读回校验**，不调用 `|| true`；失败 rc≠0 ⇒
#     oneshot 单元 failed ⇒ `systemctl --failed` / deploy §13 都能看见。
#
# 语义边界（重要）：
#   `qbootctl -m` 只置 BOOT_SUCCESSFUL 位；本机实测**不动 tries_remaining**
#   （PITFALLS #672 正文：「succ=0 retry=3 跑服务 → succ=1（retry 不动）」）。
#   ⇒ 置位后 ABL 不再把槽标 UNBOOTABLE（11-20 三次冷起实测），但 retry 计数不一定回满；
#      需要回满时用 `--retry-topup`（需 python3 + /usr/local/bin/slot-attr.py，默认不开）。
#
# 用法：
#   设备上（root）：
#     ab-mark-successful --mark-once        # 单元调用的运行期路径（幂等，读回校验）
#     ab-mark-successful --check            # 只读体检（rc=0 = 单元已启用且 active 槽 successful）
#     ab-mark-successful --install          # Debian：装自身 + 单元 + enable（需仓内单元文件）
#     ab-mark-successful --uninstall        # 回退：停用并删单元（不碰 distro qbootctl.service）
#     ab-mark-successful --alpine-install   # 历史路径（Alpine/OpenRC 根）
#   主机侧（从仓库跑）：
#     sh scripts/fix-ab-mark-successful.sh --install
#
# 回退：`--uninstall`（单元与软链删除；distro `qbootctl.service` 仍在 ⇒ 语义不丢）。
#       再往上一级回退 = 该根重建（本单元不写 GPT、不写 misc，破坏面为零）。
set -u

SELF=$0
HERE=$(cd "$(dirname "$SELF")" 2>/dev/null && pwd || echo /)
QBOOTCTL=${QBOOTCTL:-qbootctl}
CMDLINE=${CMDLINE:-/proc/cmdline}
UNIT_DIR=${UNIT_DIR:-/etc/systemd/system}
SBIN_DIR=${SBIN_DIR:-/usr/local/sbin}
UNIT_NAME=ab-mark-successful.service
UNIT_PATH=$UNIT_DIR/$UNIT_NAME
TARGET=$SBIN_DIR/ab-mark-successful
TAG=${TAG:-ab-mark-successful}

say()  { printf '[%s] %s\n' "$TAG" "$*"; }
warn() { printf '[%s] WARN %s\n' "$TAG" "$*" >&2; }
die()  { printf '[%s] FAIL %s\n' "$TAG" "$*" >&2; exit "${2:-1}"; }

# ---- 槽位判据：active 槽（ABL 权威），回退 cmdline，最后回退 b ----
# 2026-11-25 加固：开机早期 `qbootctl -a` 可能给出**与 cmdline 矛盾**的答案（实测读到 _a 而实际在 _b，
# 见 D17）。槽位判错会去标「另一个槽」的 SUCCESSFUL 位，比不标危险 ⇒ 这里做三件事：
#   ① 连续读 2 次要求一致（去掉瞬时错读）；② 与 cmdline 交叉校验；③ 矛盾时不写、只报警。
cur_slot_cmdline() {
	[ -r "$CMDLINE" ] || return 0
	sed -n 's/.*androidboot\.slot_suffix=_\?\([ab]\).*/\1/p' "$CMDLINE" 2>/dev/null | head -1
}
cur_slot() {
	_prev= _s=
	_i=0
	while [ "$_i" -lt 3 ]; do
		_s=$($QBOOTCTL -a 2>/dev/null | sed -n 's/.*_\([ab]\)[[:space:]]*$/\1/p' | head -1)
		[ -n "$_s" ] && [ "$_s" = "$_prev" ] && break
		_prev=$_s
		_i=$((_i + 1))
		[ "$_i" -lt 3 ] && sleep 2
	done
	if [ -z "$_s" ]; then
		_s=$(cur_slot_cmdline)
	fi
	[ -n "$_s" ] || _s=b
	printf '%s' "$_s"
}

# `qbootctl -n SLOT` 的原文是 "SLOT _b: is marked successful" / "…: is not marked successful"
slot_marked() { # $1 = a|b ; rc=0 表示**已**标记成功
	_o=$($QBOOTCTL -n "$1" 2>&1) || true
	case $_o in
		*": is not marked successful"*) return 1 ;;
		*": is marked successful"*)     return 0 ;;
		*) warn "无法判读 qbootctl -n $1 的输出：${_o:-（空）}"; return 2 ;;
	esac
}

# 等 /dev/disk/by-partlabel 出现（udev 竞态：PITFALLS #102 的 "No slots found"）
wait_partlabel() { # $1 = a|b ; 最多 PARTLABEL_WAIT 秒（默认 10，测试可置 0）
	_i=0
	while [ "$_i" -lt "${PARTLABEL_WAIT:-10}" ]; do
		[ -e "/dev/disk/by-partlabel/boot_$1" ] && return 0
		_i=$((_i + 1))
		sleep 1
	done
	return 1
}

# ---- 运行期：标记 + 读回校验（systemd 单元 ExecStart 调这个）----
do_mark_once() {
	RETRY_TOPUP=${RETRY_TOPUP:-0}
	command -v "$QBOOTCTL" >/dev/null 2>&1 || die "找不到 $QBOOTCTL（Debian 装 qbootctl 包）" 4
	command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] || warn "不在 systemd 下运行（仅提示）"

	s=$(cur_slot)
	_clslot=$(cur_slot_cmdline)
	say "active 槽 = _$s（判据: $QBOOTCTL -a，回退 $CMDLINE，末位回退 b；cmdline 说 _${_clslot}）"
	if [ -n "${_clslot}" ] && [ "${_clslot}" != "$s" ]; then
		# 宁可这一次不置位（下一轮启动会再试），也不要标错槽 —— 标错槽 = 把坏槽标成 good。
		warn "槽位判据自相矛盾（qbootctl -a = _$s，cmdline = _${_clslot}）⇒ **本次不写**，请查 GPT 槽属性/qbootctl（D17）"
		return 0
	fi

	wait_partlabel "$s" || warn "10 s 内没等到 /dev/disk/by-partlabel/boot_$s（分区表/udev 异常）"

	slot_marked "$s" && { say "SLOT _$s 已是 successful ⇒ 本次零写盘（幂等）"; return 0; }

	_out=$($QBOOTCTL -m "$s" 2>&1); _rc=$?
	say "qbootctl -m $s rc=$_rc：${_out:-（无输出）}"
	[ "$_rc" = 0 ] || die "qbootctl -m $s 失败（槽位标记未写成功）" 5

	slot_marked "$s"
	_rc=$?
	[ "$_rc" = 0 ] || die "写后读回校验失败：SLOT _$s 仍未 successful（状态保留，请查 qbootctl / GPT）" 6
	say "读回校验通过：SLOT _$s successful"

	if [ "$RETRY_TOPUP" = 1 ]; then
		# tries_remaining 补满（`qbootctl -m` 不动 retry，见文件头）。
		# 仅在用户显式打开时执行；**绝不**传 --allow-wrong-lun（那会关掉 LUN 自检）。
		SA=${SLOT_ATTR_PY:-/usr/local/bin/slot-attr.py}
		if command -v python3 >/dev/null 2>&1 && [ -f "$SA" ]; then
			python3 "$SA" set "$s" --retry 7 || warn "slot-attr retry 补写失败（不影响 successful 位）"
			python3 "$SA" show 2>/dev/null | grep -E '^  boot_[ab] ' | sed 's/^/  /' || true
		else
			warn "RETRY_TOPUP=1 但缺 python3 或 $SA ⇒ 跳过（现役根无 python3；见 PITFALLS #525/#400）"
		fi
	fi
	return 0
}

# ---- 只读体检（deploy-desktop-shell.sh §13 / 人工）----
do_check() {
	_miss=0
	if command -v "$QBOOTCTL" >/dev/null 2>&1; then
		say "ok   $QBOOTCTL 在（$(command -v "$QBOOTCTL")）"
	else
		say "MISS $QBOOTCTL 不在"; _miss=$((_miss + 1))
	fi
	if [ -f "$UNIT_PATH" ]; then
		say "ok   单元在 $UNIT_PATH"
	else
		say "MISS 单元不在 $UNIT_PATH"; _miss=$((_miss + 1))
	fi
	if command -v systemctl >/dev/null 2>&1; then
		_en=$(systemctl is-enabled "$UNIT_NAME" 2>/dev/null || true)
		if [ "$_en" = enabled ]; then say "ok   单元 enabled"; else say "MISS 单元 is-enabled=$_en"; _miss=$((_miss + 1)); fi
		_res=$(systemctl show -p Result --value "$UNIT_NAME" 2>/dev/null || true)
		case $_res in
			failed) say "MISS 上一次运行 Result=failed（journalctl -u $UNIT_NAME）"; _miss=$((_miss + 1)) ;;
			*)      say "ok   Result=${_res:-（未运行）}" ;;
		esac
	else
		say "MISS 无 systemctl"; _miss=$((_miss + 1))
	fi
	if command -v "$QBOOTCTL" >/dev/null 2>&1; then
		_s=$(cur_slot)
		if slot_marked "$_s"; then
			say "ok   active 槽 _${_s} = successful"
		else
			say "MISS active 槽 _${_s} 未 successful"; _miss=$((_miss + 1))
		fi
		_distro=$(systemctl is-enabled qbootctl.service 2>/dev/null || true)
		say "info distro qbootctl.service = ${_distro:-absent}（同语义的另一份实现，两者幂等）"
	fi
	say "MISS=$_miss"
	[ "$_miss" = 0 ] || return 1
	return 0
}

# ---- Debian 安装（单元文件是 SSOT，本脚本不内联拷贝一份）----
find_unit_src() {
	for _c in "$HERE/../rootfs/debian/units-extra/$UNIT_NAME" \
	          "${ELDEN_REPO:-/nonexistent}/rootfs/debian/units-extra/$UNIT_NAME"; do
		[ -f "$_c" ] && { printf '%s' "$_c"; return 0; }
	done
	return 1
}

do_install() {
	command -v systemctl >/dev/null 2>&1 || die "不是 systemd 根（用 --alpine-install）" 3
	command -v "$QBOOTCTL" >/dev/null 2>&1 || die "找不到 $QBOOTCTL（apt install qbootctl）" 4
	SRC=$(find_unit_src) || die "找不到单元源 $UNIT_NAME；从仓库跑本脚本，或用 hosts 侧
       scripts/deploy-desktop-shell.sh（§13 会把单元与脚本一起推上去）" 3

	mkdir -p "$UNIT_DIR" "$SBIN_DIR" || die "建目录失败" 3
	# 1) 自身装成运行期入口
	if [ "$(readlink -f "$SELF" 2>/dev/null || echo "$SELF")" != "$(readlink -f "$TARGET" 2>/dev/null || echo "$TARGET")" ]; then
		install -m 755 "$SELF" "$TARGET" || die "拷贝 $TARGET 失败" 3
		say "已安装运行期入口：$TARGET"
	fi
	# 2) 单元（内容不同才覆盖，覆盖前留 .bak-<时间戳> 便于回退）
	if [ -f "$UNIT_PATH" ] && ! cmp -s "$SRC" "$UNIT_PATH"; then
		_bak=$UNIT_PATH.bak-$(date +%Y%m%d-%H%M%S)
		cp -a "$UNIT_PATH" "$_bak" && say "原单元已备份：$_bak"
	fi
	install -m 644 "$SRC" "$UNIT_PATH" || die "写 $UNIT_PATH 失败" 3
	# 3) 启用 + 当场跑一次（幂等；已成功则零写盘）
	systemctl daemon-reload || die "daemon-reload 失败" 3
	systemctl enable --now "$UNIT_NAME" || die "enable --now $UNIT_NAME 失败" 3
	systemctl start "$UNIT_NAME" 2>/dev/null || true
	say "--- 复核 ---"
	systemctl is-enabled "$UNIT_NAME"
	systemctl show -p Result --value "$UNIT_NAME" 2>/dev/null | sed 's/^/Result=/'
	"$QBOOTCTL" 2>/dev/null | sed -n '1,8p'
	do_check || die "装完自检未通过（见上 MISS 行）" 7
	return 0
}

do_uninstall() {
	command -v systemctl >/dev/null 2>&1 || die "不是 systemd 根" 3
	systemctl disable --now "$UNIT_NAME" >/dev/null 2>&1 || true
	rm -f "$UNIT_PATH" || die "删 $UNIT_PATH 失败" 3
	systemctl daemon-reload || true
	say "已停用并删除 $UNIT_PATH（$TARGET 保留，可手工再装）"
	say "回退后语义仍由 distro qbootctl.service 兜（is-enabled=$(systemctl is-enabled qbootctl.service 2>/dev/null || echo absent)）"
	rm -f "$TARGET" 2>/dev/null || true
	return 0
}

# ---- Alpine/OpenRC 分支（历史路径，2026-11-12 审计判「只适用 Alpine」）----
do_alpine_install() {
	INIT=/etc/init.d/qbootctl
	[ -e "$INIT" ] || die "$INIT 不存在（不是 Alpine/OpenRC 根？）" 3
	command -v qbootctl >/dev/null 2>&1 || die "找不到 qbootctl" 4
	[ -e "$INIT.orig" ] || cp -a "$INIT" "$INIT.orig"
	cat > "$INIT" <<'EOF'
#!/sbin/openrc-run
# Mark the current A/B slot successful on every boot.
# 2026-11-22 fix (see scripts/fix-ab-mark-successful.sh): this service existed but was
# NOT in any runlevel -> BOOT_SUCCESSFUL never set -> ABL decremented tries_remaining
# once per boot -> after 7 reboots the device stopped at fastboot.  Enabled in runlevel
# `default`; explicit start() so OpenRC status reports `started`.
description="Mark current boot as successful in Android A/B interface"

start() {
	ebegin "Marking current A/B slot successful"
	# 槽位取 active（ABL 权威）；cmdline 的 suffix 烤死在 boot.img 里，不能当判据（#601）
	_s=$(qbootctl -a 2>/dev/null | sed -n 's/.*_\([ab]\)[[:space:]]*$/\1/p' | head -1)
	[ -n "$_s" ] || _s=$(sed -n 's/.*androidboot\.slot_suffix=_\?\([ab]\).*/\1/p' /proc/cmdline | head -1)
	[ -n "$_s" ] || _s=b
	qbootctl -m "$_s"
	eend $?
}
EOF
	chmod 755 "$INIT"
	rc-update add qbootctl default >/dev/null 2>&1 || true
	rc-service qbootctl --quiet restart >/dev/null 2>&1 || rc-service qbootctl start >/dev/null 2>&1 || true
	say "--- 复核（必须 started + BOOT_SUCCESSFUL）---"
	rc-service qbootctl status 2>&1 | head -1
	_s=$(qbootctl -a 2>/dev/null | sed -n 's/.*_\([ab]\)[[:space:]]*$/\1/p' | head -1)
	qbootctl -n "${_s:-b}" 2>&1 | head -1
	echo "runlevel: $(ls -l /etc/runlevels/default/qbootctl 2>/dev/null || echo '未启用！')"
	return 0
}

MODE=auto
RETRY_TOPUP=${RETRY_TOPUP:-0}
for a in "$@"; do
	case "$a" in
		--mark-once)          MODE=mark ;;
		--check)              MODE=check ;;
		--install)            MODE=install ;;
		--uninstall)          MODE=uninstall ;;
		--alpine-install)     MODE=alpine ;;
		--retry-topup)        RETRY_TOPUP=1 ;;
		-h|--help)            sed -n '2,46p' "$SELF"; exit 0 ;;
		*) die "未知参数 $a（--help）" 2 ;;
	esac
done
export RETRY_TOPUP

if [ "$MODE" = auto ]; then
	if [ -d /run/systemd/system ]; then MODE=install; else MODE=alpine; fi
fi

case "$MODE" in
	mark)      do_mark_once ;;
	check)     do_check ;;
	install)   do_install ;;
	uninstall) do_uninstall ;;
	alpine)    do_alpine_install ;;
esac
