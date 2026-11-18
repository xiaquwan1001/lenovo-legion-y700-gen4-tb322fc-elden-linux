#!/bin/sh
# hide-android-partitions.sh — 让 GNOME/GTK 文件管理器（Nautilus、GTK 文件选择器、Phosh 栈里的任何
# GVolumeMonitor 使用者）侧栏只显示白名单分区；Android 的 system/vendor/persist/metadata/modem 等
# 只读分区不再出现。
#
# 原理（三层，细节见 reports/hide-android-partitions-20261119.md）：
#   a) udisks2：udev 属性 UDISKS_IGNORE=1 ⇒ Block.HintIgnore=TRUE
#      ⇒ gvfs-udisks2-volume-monitor 里 should_include_volume() 第一条判断就把它丢掉（"Block:Ignore trumps everything"）。
#      Nautilus 侧栏 / GTK places sidebar / gio mount -l 三者同源（GVolumeMonitor），一次生效。
#   b) fstab：/etc/fstab 里已有条目的挂载点也会被 gvfs-udisks2-volume-monitor 拿 libmount 读出来；
#      选项 x-gvfs-hide 让它不进列表（x-gvfs-show 优先级更高，两者都无时按 g_unix_is_mount_path_system_internal()
#      + /media、/run/media、$HOME 前缀判断）。
#   c) Nautilus 自身：GNOME 50 的 org.gnome.nautilus.gschema.xml 只有 11 个键，没有任何 volumes/mounts 相关键
#      ⇒ 没有受支持的 dconf 开关（老的 volumes-visible 早已删除）。所以只能从前两层做。
#
# 用法：
#   scripts/hide-android-partitions.sh [--check|--apply|--revert] [--dry-run]
#                                      [--keep LABEL[,LABEL...]] [--no-keep-removable]
#   默认 = --dry-run（只打印将做什么）。--check 只读报告，rc=0 表示已符合期望。
#
# 环境变量（用于离线自测，正常情况下不需要）：
#   HIDE_RULES_DIR   默认 /etc/udev/rules.d
#   HIDE_FSTAB       默认 /etc/fstab
#   HIDE_STATE_DIR   默认 /etc/udev      （记录我们改过的 fstab 行，供 --revert 精确回退）
#   HIDE_LSBLK       默认 lsblk          （可指向一个假 lsblk 包装）
#   HIDE_PARTLABELS  （仅自测）从该文件读 "NAME LABEL" 行，代替 lsblk 现查
#   HIDE_FAKE_ROOT   （仅自测）="1" 时跳过 --apply/--revert 的 uid==0 检查（写到上面几个 override 目录里）
#
# 回退：--revert（恢复 udev 规则文件（删我们生成的那份）+ 撤掉我们加的 x-gvfs-hide）
#
# 依赖：posix sh + lsblk(util-linux) + (可选用) udevadm。**不改动任何分区/文件系统内容，只写规则与选项。**

set -u

RULES_NAME="79-hide-android-partitions.rules"
MARKER="hide-android-partitions-v1"
DEFAULT_KEEP="linux17 eldenesp linux"

MODE="dry-run"
DRY_RUN=1
KEEP="$DEFAULT_KEEP"
KEEPR="1"
RULES_DIR="${HIDE_RULES_DIR:-/etc/udev/rules.d}"
FSTAB="${HIDE_FSTAB:-/etc/fstab}"
STATE_DIR="${HIDE_STATE_DIR:-/etc/udev}"
LSBLK="${HIDE_LSBLK:-lsblk}"
STATE_FILE="$STATE_DIR/hide-android-partitions.state"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
	cat <<'USAGE'
hide-android-partitions.sh — 让文件管理器（Nautilus / GTK places sidebar）侧栏只显示白名单分区

用法:
  hide-android-partitions.sh                # 默认 = --dry-run（只打印将做什么）
  hide-android-partitions.sh --check        # 只读报告，rc=0 = 已符合期望
  hide-android-partitions.sh --apply        # 需 root：写 udev 规则 + 给 fstab 条目补 x-gvfs-hide
  hide-android-partitions.sh --revert       # 需 root：撤销本脚本做的全部改动

选项:
  --dry-run              强制只打印（可与 --apply 组合做预演）
  --keep L1[,L2...]      追加白名单 PARTLABEL（默认: linux17 eldenesp linux）
  --no-keep-removable    连 TF 卡 / U 盘上的分区一起隐藏（默认保持可见）

回退: --revert；或删 /etc/udev/rules.d/79-hide-android-partitions.rules 后
      udevadm control --reload-rules && udevadm trigger --subsystem-match=block --action=change
USAGE
	exit 0
}

while [ $# -gt 0 ]; do
	case "$1" in
	--check) MODE="check"; DRY_RUN=1 ;;
	--apply) MODE="apply"; DRY_RUN=0 ;;
	--revert) MODE="revert"; DRY_RUN=0 ;;
	--dry-run) DRY_RUN=1 ;;
	--keep) shift; [ $# -gt 0 ] || { err "--keep 需要参数"; exit 2; }; KEEP="$KEEP $1" ;;
	--keep=*) KEEP="$KEEP ${1#--keep=}" ;;
	--no-keep-removable) KEEPR="0" ;;
	-h|--help) usage ;;
	*) err "未知参数: $1"; exit 2 ;;
	esac
	shift
done

# ---- 白名单词表（去重、校验字符集） --------------------------------------
# 两套表示：KEEP_CSV 给 shell 比对（**不能**用 '|'：dash/bash 会把它当 case 备选分隔符，
# 即使加引号也不可靠 —— 实测 `*"|x|"` 永不匹配），KEEP_ALT 给 udev 规则（'|' 是 udev 的或）。
KEEP_CSV=""
add_keep() {
	_l="$1"
	[ -n "$_l" ] || return 0
	printf '%s' "$_l" | grep -Eq '^[A-Za-z0-9_.:+-]+$' || {
		err "白名单标签字符集不安全（只允许字母数字和 _.:+-）: $_l"; exit 2; }
	case ",$KEEP_CSV," in
	*",$_l,"*) return 0 ;;
	esac
	if [ -z "$KEEP_CSV" ]; then KEEP_CSV="$_l"; else KEEP_CSV="$KEEP_CSV,$_l"; fi
}
for _k in $KEEP; do add_keep "$_k"; done
[ -n "$KEEP_CSV" ] || { err "白名单为空"; exit 2; }
KEEP_ALT="$(printf '%s' "$KEEP_CSV" | tr ',' '|')"

# keep_label <label> → rc=0 表示在白名单里
keep_label() {
	case ",$KEEP_CSV," in
	*",$1,"*) return 0 ;;
	esac
	return 1
}

# ---- 现查分区表（NAME PARTLABEL） ----------------------------------------
partlabels() {
	if [ -n "${HIDE_PARTLABELS:-}" ]; then
		awk 'NF>=1 {print $1, (NF>=2 ? $2 : "")}' "$HIDE_PARTLABELS"
		return 0
	fi
	# 用 -P（key="value" 成对输出）避开「空 PARTLABEL 把列挤掉」的解析坑；只看分区（TYPE=="part"），
	# 整盘（sda / nvme0n1）不参与判断 —— 生成的规则也只对 DEVTYPE=="partition" 生效。
	"$LSBLK" -pno NAME,PARTLABEL,TYPE -P 2>/dev/null | awk '
	{
		name = ""; label = ""; type = ""
		while (match($0, /[A-Z_]+="[^"]*"/)) {
			tok = substr($0, RSTART, RLENGTH)
			eq  = index(tok, "=")
			k   = substr(tok, 1, eq - 1)
			v   = substr(tok, eq + 2, length(tok) - eq - 2)
			if (k == "NAME") name = v
			else if (k == "PARTLABEL") label = v
			else if (k == "TYPE") type = v
			$0 = substr($0, RSTART + RLENGTH)
		}
		if (type == "part") print name, label
	}'
}

# ---- 生成 udev 规则 ------------------------------------------------------
# 关键顺序：60-persistent-storage.rules 设好 ID_PART_ENTRY_NAME 之后、udisks 读取之前（79 < 80）。
render_rules() {
	cat <<EOF
# 由 scripts/hide-android-partitions.sh 生成 — 请勿手工编辑（--revert 会整份删除）
# marker: $MARKER
#
# 白名单（可见）= $KEEP_ALT   ← 这些 PARTLABEL 保持对 udisks/gvfs 可见
# 其余整块分区 = UDISKS_IGNORE=1 ⇒ Block.HintIgnore=TRUE ⇒ gvfs-udisks2-volume-monitor
# 的 should_include_volume() 第一条判断丢弃它（Nautilus 侧栏 / GTK places sidebar / gio mount -l 同源）。
# 依据：man 8 udisks「DEVICE INFORMATION」；udisks src/udiskslinuxblock.c 的 UDISKS_* 覆盖段。

ACTION!="add|change", GOTO="hide_android_partitions_end"
SUBSYSTEM!="block", GOTO="hide_android_partitions_end"
ENV{DEVTYPE}!="partition", GOTO="hide_android_partitions_end"

# 白名单分区：放行
ENV{ID_PART_ENTRY_NAME}=="$KEEP_ALT", GOTO="hide_android_partitions_end"
EOF
	if [ "$KEEPR" = "1" ]; then
		cat <<'EOF'

# 可移动介质（TF 卡、U 盘）保持可见：它们是"用户感兴趣"的卷，不属于本脚本要治的固定分区
ENV{ID_DRIVE_FLASH_SD}=="1", GOTO="hide_android_partitions_end"
ENV{ID_DRIVE_FLASH_MMC}=="1", GOTO="hide_android_partitions_end"
ENV{ID_BUS}=="usb", GOTO="hide_android_partitions_end"
EOF
	fi
	cat <<'EOF'

# 其余一律隐藏（只影响 udisks 的呈现，不动内核分区、不 umount、不做权限变更）
ENV{UDISKS_IGNORE}="1"

LABEL="hide_android_partitions_end"
EOF
}

# ---- fstab：给指向隐藏分区的条目加 x-gvfs-hide ---------------------------
# 打印 "动作<TAB>行号<TAB>设备<TAB>挂载点"；动作 ∈ {HIDE, ALREADY, SKIP, UNRESOLVED}
fstab_plan() {
	[ -r "$FSTAB" ] || return 0
	_n=0
	while IFS= read -r _line || [ -n "$_line" ]; do
		_n=$((_n + 1))
		case "$_line" in
		''|\#*) continue ;;
		esac
		# dev mnt fstype opts [dump pass]
		set -- $_line   # 故意按空白拆字段（fstab 的字段分隔就是空白）
		_dev="${1:-}"; _mnt="${2:-}"; _opts="${4:-defaults}"
		[ -n "$_dev" ] && [ -n "$_mnt" ] || continue
		case "$_mnt" in
		/|/boot|/boot/efi|/boot/*|none|swap|/proc|/sys|/dev|/tmp|/var|/usr|/home) continue ;;
		esac
		case ",$_opts," in
		*,x-gvfs-hide,*) say "ALREADY	$_n	$_dev	$_mnt"; continue ;;
		esac
		_lbl=""
		case "$_dev" in
		/dev/disk/by-partlabel/*) _lbl="${_dev##*/}" ;;
		PARTLABEL=*) _lbl="${_dev#PARTLABEL=}"; _lbl="${_lbl%%[,\"]*}" ;;
		*) _lbl="$("$LSBLK" -no PARTLABEL "$_dev" 2>/dev/null | head -n1 | tr -d ' ')" ;;
		esac
		if [ -z "$_lbl" ]; then
			say "UNRESOLVED	$_n	$_dev	$_mnt"
			continue
		fi
		if keep_label "$_lbl"; then
			say "SKIP	$_n	$_dev	$_mnt"
		else
			say "HIDE	$_n	$_dev	$_mnt"
		fi
	done <"$FSTAB"
}

plan_fstab() { fstab_plan; }

count_action() { plan_fstab | awk -v a="$1" '$1==a' | wc -l | tr -d ' '; }

# ---- 动作实现 ------------------------------------------------------------
# 当前分区表的"可见/隐藏"预演（纯报告，不改任何东西）
report_partitions() {
	_pl="$(partlabels)"
	if [ -z "$_pl" ]; then
		say "[part] 未取到分区表（无 lsblk / 无权限），跳过清单"
		return 0
	fi
	say "[part] 当前分区表按白名单预演（keep = 保持可见）:"
	printf '%s\n' "$_pl" | while read -r _n _l; do
		[ -n "$_n" ] || continue
		if keep_label "$_l"; then _v="keep"; else _v="HIDDEN"; fi
		printf '    %-14s %-16s %s\n' "$_n" "${_l:-<no-partlabel>}" "$_v"
	done
}

backup_file() {
	_f="$1"
	[ -e "$_f" ] || return 0
	_b="$_f.bak-hideandroid-$STAMP"
	cp -a "$_f" "$_b" && say "  备份: $_b"
}

do_rules() {
	_target="$RULES_DIR/$RULES_NAME"
	_want="$(render_rules)"
	if [ -f "$_target" ] && [ "$(cat "$_target")" = "$_want" ]; then
		say "[udev] 已是最新，无需改动: $_target"
		return 0
	fi
	say "[udev] 将写入 $_target（$(printf '%s' "$_want" | wc -l | tr -d ' ') 行，含白名单 $KEEP_ALT）"
	if [ "$DRY_RUN" = "1" ]; then
		printf '%s\n' "$_want" | sed 's/^/    | /'
		return 0
	fi
	mkdir -p "$RULES_DIR"
	backup_file "$_target"
	printf '%s\n' "$_want" >"$_target" || { err "写 $_target 失败"; return 1; }
	say "  已写入。重载 udev 规则…"
	# udevadm 失败（例如在非 root 的离线自测里）只当作 WARN：规则已落盘，重启后一定生效
	if command -v udevadm >/dev/null 2>&1; then
		if udevadm control --reload-rules 2>/dev/null \
		   && udevadm trigger --subsystem-match=block --action=change 2>/dev/null; then
			say "  已 reload+trigger（udisksd 会在 change 事件里重读 HintIgnore）"
		else
			say "  WARN: udevadm reload/trigger 没成功（规则已落盘；重启后生效，或手动：udevadm control --reload-rules && udevadm trigger -s block -a change）"
		fi
	else
		say "  WARN: 无 udevadm，重启后生效"
	fi
}

do_fstab() {
	_hide="$(plan_fstab | awk -F'\t' '$1=="HIDE"{print $2}' | tr '\n' ' ' | sed 's/ *$//')"
	if [ -z "$_hide" ]; then
		say "[fstab] 无需改动（无指向隐藏分区的条目）"
		return 0
	fi
	say "[fstab] 需要加 x-gvfs-hide 的行: $(printf '%s' "$_hide" | tr '\n' ' ')"
	plan_fstab | awk -F'\t' '$1=="HIDE"{printf "    | 行 %s: %s → %s\n",$2,$3,$4}'
	if [ "$DRY_RUN" = "1" ]; then
		return 0
	fi
	mkdir -p "$STATE_DIR"
	backup_file "$FSTAB"
	# 逐行就地改写：只在我们计划里的行号上补选项，行内其他内容保持原样
	_tmp="$FSTAB.hideandroid.$$"
	# 只改第 4 个字段（opts），前 3 个字段/分隔符/行尾其余内容逐字节保留；
	# 行内注释与非常规行（字段 < 4）一律不动。
	awk -v HIDE=" $_hide " '
	{
		n++
		if (index(HIDE, " " n " ") == 0) { print; next }
		if (!match($0, /^[ \t]*[^ \t]+[ \t]+[^ \t]+[ \t]+[^ \t]+[ \t]+[^ \t]+/)) { print; next }
		head = substr($0, 1, RLENGTH)
		rest = substr($0, RLENGTH + 1)
		pre = head; sub(/[^ \t]+$/, "", pre)              # 前 3 字段 + 分隔符
		old = head; sub(/^.*[ \t]/, "", old)             # = 第 4 字段
		new = (old == "defaults") ? "defaults,x-gvfs-hide" : old ",x-gvfs-hide"
		print pre new rest
	}' "$FSTAB" >"$_tmp" || { err "生成新 fstab 失败"; rm -f "$_tmp"; return 1; }
	# 改写后行数必须与原文一致（防止 awk 误吞行）
	_before=$(wc -l <"$FSTAB")
	_after=$(wc -l <"$_tmp")
	if [ "$_before" != "$_after" ]; then
		err "改写前后行数不一致（$_before → $_after），已放弃，$FSTAB 未动"; rm -f "$_tmp"; return 1
	fi
	if ! mv "$_tmp" "$FSTAB"; then err "替换 $FSTAB 失败（临时件 $_tmp 保留）"; return 1; fi
	printf '%s\n' "$_hide" >"$STATE_FILE"
	say "  已改 $FSTAB，记录到 $STATE_FILE（供 --revert）"
}

do_revert() {
	_ok=0
	_target="$RULES_DIR/$RULES_NAME"
	if [ -f "$_target" ] && grep -q "$MARKER" "$_target" 2>/dev/null; then
		if [ "$DRY_RUN" = "1" ]; then
			say "[udev] 将删除 $_target"
		else
			backup_file "$_target"
			rm -f "$_target" && say "[udev] 已删除 $_target"
			if command -v udevadm >/dev/null 2>&1; then
				udevadm control --reload-rules 2>/dev/null \
					&& udevadm trigger --subsystem-match=block --action=change 2>/dev/null \
					|| say "  WARN: udevadm reload/trigger 没成功（重启后生效）"
			fi
		fi
		_ok=1
	else
		say "[udev] 没有本脚本生成的规则文件，跳过"
	fi
	if [ -f "$STATE_FILE" ]; then
		_lines="$(tr '\n' ' ' <"$STATE_FILE")"
		say "[fstab] 撤销行 $_lines 上的 x-gvfs-hide"
		if [ "$DRY_RUN" = "0" ]; then
			backup_file "$FSTAB"
			_prev=""
			for _l in $_lines; do _prev="$_prev -e ${_l}s/,x-gvfs-hide//g -e ${_l}s/x-gvfs-hide,//g"; done
			# shellcheck disable=SC2086
			sed -i $_prev "$FSTAB" && say "  已撤销" && rm -f "$STATE_FILE"
		fi
		_ok=1
	else
		say "[fstab] 无状态文件（说明 apply 没改过 fstab），跳过"
	fi
	[ "$_ok" = "1" ] || say "  没找到本脚本留下的东西 — 无需回退"
}

do_check() {
	rc=0
	_target="$RULES_DIR/$RULES_NAME"
	if [ -f "$_target" ] && grep -q "$MARKER" "$_target" 2>/dev/null; then
		if [ "$(cat "$_target")" = "$(render_rules)" ]; then
			say "OK  udev: $_target 存在且与期望一致（白名单 $KEEP_ALT）"
		else
			say "DIFF udev: $_target 存在但内容与期望不同（白名单或可移动策略变了）→ 需要 --apply"
			rc=1
		fi
	else
		say "MISS udev: 未安装 $_target → 需要 --apply"
		rc=1
	fi
	_h="$(count_action HIDE)"; _u="$(count_action UNRESOLVED)"; _a="$(count_action ALREADY)"
	if [ "$_h" != "0" ]; then
		say "TODO fstab: $_h 条指向隐藏分区的条目缺 x-gvfs-hide → 需要 --apply"
		rc=1
	else
		say "OK  fstab: 无缺口（已带 x-gvfs-hide: $_a 条，无法解析: $_u 条）"
	fi
	say ""
	say "运行时核对（只读，需在 Linux 桌面会话里跑）："
	say "  lsblk -o NAME,PARTLABEL,SIZE"
	say "  for d in \$(lsblk -lno NAME,TYPE | awk '\$2==\"part\"{print \$1}'); do printf '%s ' \$d; udisksctl info -b /dev/\$d 2>/dev/null | sed -n 's/^ *HintIgnore: *//p'; done"
	say "  gio mount -l"
	return $rc
}

# ---- 主流程 --------------------------------------------------------------
say "== hide-android-partitions.sh  mode=$MODE dry_run=$DRY_RUN"
say "   白名单(PARTLABEL): $KEEP_ALT"
say "   可移动介质保持可见: $([ "$KEEPR" = 1 ] && echo yes || echo no)"
say "   分区表来源: ${HIDE_PARTLABELS:-$LSBLK -pno NAME,PARTLABEL,TYPE -P（只看 TYPE=part）}"
say ""
case "$MODE" in
check) do_check; exit $? ;;
revert) do_revert; exit 0 ;;
apply|dry-run) ;;
esac

if [ "$DRY_RUN" = "0" ] && [ "$(id -u)" != "0" ] && [ "${HIDE_FAKE_ROOT:-0}" != "1" ]; then
	err "--apply/--revert 需要 root（本会话不允许 sudo，请由主代理执行：sudo $0 --apply）"
	exit 3
fi

do_rules || exit 1
report_partitions
do_fstab || exit 1

say ""
say "== 完成（mode=$MODE dry_run=$DRY_RUN）"
if [ "$DRY_RUN" = "1" ]; then
	say "   这是 dry-run：什么都没写。真正落地：sudo $0 --apply"
fi
say "   上机验收：见 reports/hide-android-partitions-20261119.md §5"
exit 0
