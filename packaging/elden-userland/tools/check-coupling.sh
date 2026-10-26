#!/bin/bash
# check-coupling.sh — 「目标系统专属构造」门（发行版解耦硬门）
#
# 为什么需要（2026-10-26，T14 用户态去 Alpine 化）：
#   用户态层原来事实上是 Alpine/OpenRC 第一语言 —— 脚本里直接写 apk / rc-service /
#   /etc/local.d / musl loader。这些构造在 Debian/Mobian 上**不报错、只静默失效**
#   （rc-service not found 被 `|| true` 吞掉；musl interp 缺失被当成"文件没装"）。
#   本门把它们变成硬判据：**执行路径上的命中即 FAIL**，豁免必须可核查（见下）。
#
# 三级分类（这是本门最重要的设计，别简化成一条 grep）：
#   1. CODE     —— 会被执行的行（脚本/unit/配置里的非注释行）⇒ 命中 **FAIL**
#   2. MENTION  —— 注释行（行首 `#`）与文档/数据文件（*.md、*.tsv）⇒ 只计数，不 FAIL
#      理由：注释里写「apk 修不了」不会在 Debian 上坏事；把文档也判 FAIL 只会逼人写垃圾豁免。
#   3. SELF     —— 本门自身（check-coupling.sh / coupling-waivers.tsv）⇒ 跳过（它的正文必须
#      包含这些字面量，那是检测规则，不是调用）
#   另有两条**结构性**降级（都可在 --list 里看到，不是静默放过）：
#   · GUARDED  —— 同一行/上一行有 `command -v <tool>` 守卫 + 回退分支（跨 init 可移植写法）
#   · DETECT   —— 一行里同时出现 ≥3 种 token ⇒ 这是在**列举要拦的东西**（lint 规则/清单）
#
# 判据（任一 FAIL 即非 0 退出）：
#   W  豁免表合法：路径正则 + kind + stage + **理由非空**，正则可编译，kind/stage 在枚举内
#   X  豁免的**可核查性**（本门最关键的一条，防「为了过门乱加豁免」）：
#      stage=skip    ⇒ 文件必须同时列在 `rootfs/debian/debian-exclude.tsv`（= 承诺它不进 Debian 根）
#      stage=message ⇒ 该行 token 必须出现在引号内（= 只是提示语/字符串，不是调用）
#      stage=guarded ⇒ 该行或上一行必须有 `command -v` 守卫
#   A  rc-service / rc-update / rc-status（OpenRC 服务控制）
#   B  /etc/local.d（Alpine 专属 boot 钩子目录）
#   C  apk 包管理调用（add/del/fix/update/upgrade/world/info/list/policy/search）
#   D  /lib/ld-musl-*.so（musl 动态解释器路径）
#   E  emerge（Gentoo；同属"目标系统专属"，防止将来照抄）
#   F  #!/sbin/openrc-run shebang 出现在**非白名单位置**
#
# 用法：
#   bash tools/check-coupling.sh              # 扫「用户态面」（换发行版后仍要跑的东西）
#   bash tools/check-coupling.sh --all        # 加扫 scripts/ + rootfs/ + initramfs/（审计用）
#   bash tools/check-coupling.sh --list       # 逐条列出 CODE/MENTION/GUARDED，不判 FAIL
#   bash tools/check-coupling.sh --self-test  # 负向自测：注入 → 真 FAIL；移除 → 真 PASS
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)   # packaging/elden-userland
REPO=$(cd -- "$HERE/../.." && pwd)
WAIVERS="$HERE/tools/coupling-waivers.tsv"
EXCLUDE="$REPO/rootfs/debian/debian-exclude.tsv"
SELF_REL='packaging/elden-userland/tools/(check-coupling\.sh|coupling-waivers\.tsv)'

SCOPE=userland
SELF_TEST=0
LIST_ONLY=0
for a in "$@"; do case "$a" in
	--all) SCOPE=all ;;
	--self-test) SELF_TEST=1 ;;
	--list) LIST_ONLY=1 ;;
	-h|--help) sed -n '2,44p' "$0"; exit 0 ;;
	*) echo "未知参数 $a" >&2; exit 2 ;;
esac; done

fails=0
mentions=0
guarded_n=0
waived=0
ok()      { printf '  ok     %s\n' "$*"; }
bad()     { printf '  FAIL   %s\n' "$*"; fails=$((fails + 1)); }
mention() { mentions=$((mentions + 1)); }
wv()      { printf '  waiver %s\n' "$*"; waived=$((waived + 1)); }
sec()     { printf '\n[%s]\n' "$*"; }

# ---------------------------------------------------------------- 扫描范围
# 用户态面 = 「换发行版后仍要在板子上跑」的定义：用户态打包层 + Debian 目标根组装器。
# 默认**不含**：scripts/（主机侧一次性运维脚本，目标就是当前 Alpine 根）、
#   rootfs/persistent-overlay/（Alpine 现役根的归档副本）、initramfs/（PID1，架构中立）。
userland_paths() {
	printf '%s\n' \
		"$HERE/services.tsv" "$HERE/deps.tsv" "$HERE/provides.tsv" "$HERE/sources.tsv" \
		"$HERE/MANIFEST.tsv" "$HERE/README.md" "$HERE/templates" "$HERE/hooks" \
		"$HERE/extra" "$HERE/files" "$HERE/tools" "$REPO/rootfs/debian"
}
all_paths() {
	printf '%s\n' "$REPO/scripts" "$REPO/initramfs/init" "$REPO/rootfs"
}
SKIP_RE='(\.(gz|xz|zst|tar|deb|img|ko|bin|cpio|pyc|so|a|o)$|/out/units/(openrc|hooks)/|/\.git/)'
DOC_RE='\.(md|tsv)$'

collect_files() {
	{ if [ "$SCOPE" = all ]; then all_paths; else userland_paths; fi; } | while IFS= read -r p; do
		[ -e "$p" ] || continue
		if [ -d "$p" ]; then find "$p" -type f 2>/dev/null; else printf '%s\n' "$p"; fi
	done | grep -Ev "$SKIP_RE" | sort -u
}

# ---------------------------------------------------------------- 豁免表
# waiver 命中判定用 "rel:lineno"（不是纯路径）⇒ 同一文件里可以只豁免提示语那几行，
# 而真正的调用行仍然 FAIL。这是本表能做到「精确」的关键。
is_waived() { # $1 = "rel:lineno", $2 = kind ; 命中则把 stage 打到 stdout 并 rc=0
	local key="$1" kind="$2" pr k st r
	[ -f "$WAIVERS" ] || return 1
	while IFS=$'\x1f' read -r pr k st r; do
		case "$pr" in ''|\#*) continue ;; esac
		[ "$k" = all ] || [ "$k" = "$kind" ] || continue
		printf '%s\n' "$key" | grep -qE "$pr" || continue
		[ -n "${r// /}" ] || return 1      # 空理由 = 不算豁免（W 段另行报 FAIL）
		printf '%s\n' "$st"
		return 0
	done < <(awk -F'\t' 'BEGIN{OFS="\x1f"} !/^#/ && $1!="path_regex" && NF>=4 {print $1,$2,$3,$4}' "$WAIVERS")
	return 1
}

waiver_rows() { awk -F'\t' 'BEGIN{OFS="\x1f"} !/^#/ && $1!="path_regex" && NF>=4 {print $1,$2,$3,$4}' "$WAIVERS" 2>/dev/null; }

waiver_table_ok() {
	sec "W. 豁免表合法性（每条必须有理由且正则可编译）"
	if [ ! -f "$WAIVERS" ]; then ok "无豁免表"; return; fi
	local n=0 pr k st r
	while IFS=$'\x1f' read -r pr k st r; do
		case "$pr" in ''|\#*) continue ;; esac
		n=$((n + 1))
		case "$k" in
			all|rc-service|rc-update|rc-status|locald|apk|musl|emerge|openrc-shebang) : ;;
			*) bad "W 未知 kind=$k（行: $pr）" ;;
		esac
		case "$st" in
			skip|message|guarded) : ;;
			*) bad "W stage 必须是 skip/message/guarded（行: $pr，实际 '$st'）" ;;
		esac
		[ -n "${r// /}" ] || bad "W 豁免无理由：$pr ($k)"
		# 坏正则会静默豁免一切 = 比没豁免更糟，必须显式验证可编译。
		# grep 退出码：0=匹配 1=合法但无匹配 2=正则非法 ⇒ 只有 2 才是坏正则。
		printf '' | grep -qE "$pr" 2>/dev/null; local rc=$?
		[ "$rc" -le 1 ] || bad "W 正则无法编译（grep rc=$rc）：$pr"
	done < <(waiver_rows)
	[ "$n" -gt 0 ] && ok "$n 条豁免（理由均非空、正则均可编译）"
}

# X 段：豁免必须「可核查」——这是防滥用的核心
verify_waivers() {
	sec "X. 豁免可核查性（skip⇒进排除表 / message⇒在引号内 / guarded⇒有 command -v）"
	[ -f "$WAIVERS" ] || { ok "无豁免表，跳过"; return; }
	local pr k st r nskip=0 nmsg=0 nguard=0
	while IFS=$'\x1f' read -r pr k st r; do
		case "$pr" in ''|\#*) continue ;; esac
		case "$st" in
		skip)
			nskip=$((nskip + 1))
			if [ ! -f "$EXCLUDE" ]; then
				bad "X stage=skip 但缺 $EXCLUDE（$pr）"; continue
			fi
			# waiver 的 pr 形如 `packaging/elden-userland/files/usr/local/sbin/x\.sh:[0-9]+`
			# 排除表按**安装绝对路径**列（/usr/local/sbin/x.sh）⇒ 剥掉仓库前缀、
			# `files/|extra/`、行号后缀与转义反斜杠，再要求排除表里有一行精确等于它。
			local base
			base=$(printf '%s\n' "$pr" | sed -E 's/:\[[0-9]+\].*$//; s/:[0-9]+$//; s/:\$\)?.*$//; s/^\.\*//' \
				| sed 's|^packaging/elden-userland/||; s|^files/||; s|^extra/||; s|\\||g')
			case "$base" in /*) : ;; *) base="/$base" ;; esac
			if ! awk -F'\t' '!/^#/ && NF>=2 {print $1}' "$EXCLUDE" | grep -qxF "$base"; then
				bad "X stage=skip 但 $EXCLUDE 没列 \"$base\" ⇒ 该文件仍会被铺进 Debian 根"
			fi
			;;
		message)
			nmsg=$((nmsg + 1))
			# 「token 在引号内」的逐行证明在 emit_hits 的 X 段做（需要 body，这里只有正则）。
			# ⚠ 不要在这里 `grep -r "$REPO"`：仓库含 13 G 内核树 + build/out/backup，
			#   全仓递归 grep 会把门禁拖到分钟级（2026-10-26 实测 60 s 未返回）。
			;;
		guarded)
			nguard=$((nguard + 1))
			;;
		esac
	done < <(waiver_rows)
	[ "$nskip" -gt 0 ] && ok "skip 类 $nskip 条已对账 debian-exclude.tsv"
	[ "$nmsg" -gt 0 ] && ok "message 类 $nmsg 条（明细在 A/B/C 段的 --list 里核对）"
	[ "$nguard" -gt 0 ] && ok "guarded 类 $nguard 条"
}

# ---------------------------------------------------------------- 逐行判定
DETECT_TOKENS='rc-service|rc-update|rc-status|apk|apt-get|systemctl|local\.d'
count_tokens() { printf '%s\n' "$1" | grep -oE "$DETECT_TOKENS" | sort -u | grep -c . || true; }

emit_hits() { # $1=kind $2=regex $3=consequence [$4=被探测的可执行名]
	local kind="$1" rx="$2" cons="$3" probe="${4:-}"
	local f rel docy hit lineno body iscomment isdetect guarded prevline stage
	while IFS= read -r f; do
		rel=${f#"$REPO"/}
		printf '%s\n' "$rel" | grep -qE "$SELF_REL" && continue
		grep -Iq . "$f" 2>/dev/null || continue      # 跳过二进制
		docy=0; printf '%s\n' "$rel" | grep -qE "$DOC_RE" && docy=1
		while IFS= read -r hit; do
			[ -n "$hit" ] || continue
			lineno=${hit%%:*}; body=${hit#*:}
			iscomment=0
			case "$body" in [[:space:]]*'#'*|'#'*) iscomment=1 ;; esac
			isdetect=0
			[ "$(count_tokens "$body")" -ge 3 ] && isdetect=1
			guarded=0
			if [ -n "$probe" ]; then
				case "$body" in *command\ -v\ "$probe"*) guarded=1 ;; esac
				if [ "$guarded" = 0 ] && [ "$lineno" -gt 1 ]; then
					prevline=$(sed -n "$((lineno - 1))p" "$f" 2>/dev/null)
					case "$prevline" in *command\ -v*"$probe"*) guarded=1 ;; esac
				fi
			fi
			if [ "$docy" = 1 ] || [ "$iscomment" = 1 ] || [ "$isdetect" = 1 ] || [ "$guarded" = 1 ]; then
				mention
				[ "$guarded" = 1 ] && guarded_n=$((guarded_n + 1))
				if [ "$LIST_ONLY" = 1 ]; then
					if [ "$guarded" = 1 ]; then
						printf '  GUARDED %s:%s [%s] %s\n' "$rel" "$lineno" "$kind" "${body:0:140}"
					else
						printf '  MENTION %s:%s [%s] %s\n' "$rel" "$lineno" "$kind" "${body:0:140}"
					fi
				fi
				continue
			fi
			if [ "$LIST_ONLY" = 1 ]; then
				printf '  CODE    %s:%s [%s] %s\n' "$rel" "$lineno" "$kind" "${body:0:140}"
				continue
			fi
			if stage=$(is_waived "$rel:$lineno" "$kind"); then
				# ★ X 段事后核查：豁免必须**当场可证**，不是"写了就算"
				case "$stage" in
				message)
					# 把该行里所有引号内子串删掉后，正则必须**不再命中**
					# ⇒ 证明这个 token 只是用户可见提示语，不是被执行的命令
					if printf '%s\n' "$body" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" \
						| grep -qE "$rx"; then
						bad "$rel:$lineno [$kind] 豁免写 message 但 token 在引号外 ⇒ 是真调用（改 skip 或修代码）"
					else
						wv "$rel:$lineno [$kind/message] ${body:0:110}"
					fi
					;;
				skip)
					wv "$rel:$lineno [$kind/skip] ${body:0:110}"
					;;
				*)
					wv "$rel:$lineno [$kind/$stage] ${body:0:110}"
					;;
				esac
			else
				bad "$rel:$lineno [$kind] $cons :: ${body:0:130}"
			fi
		done < <(grep -nE "$rx" "$f" 2>/dev/null)
	done < <(collect_files)
}

scan_all() {
	local nf
	nf=$(collect_files | grep -c . || true)
	sec "0. 扫描范围"
	ok "扫了 $nf 个文件（scope=$SCOPE；CODE 判 FAIL，注释/文档/守卫/检测清单只计数）"

	sec "A. OpenRC 服务控制（rc-service / rc-update / rc-status）"
	emit_hits rc-service '(^|[^[:alnum:]_/.-])rc-service([^[:alnum:]_-]|$)' \
		"Debian 无 rc-service ⇒ not found，被 || true 吞掉 = 静默不生效" rc-service
	emit_hits rc-update '(^|[^[:alnum:]_/.-])rc-update([^[:alnum:]_-]|$)' \
		"Debian 无 rc-update ⇒ 服务不会被 enable，重启后不自启" rc-update
	emit_hits rc-service '(^|[^[:alnum:]_/.-])rc-status([^[:alnum:]_-]|$)' \
		"Debian 无 rc-status ⇒ 取证行丢内容（不致命，但 post-mortem 会空）" rc-status

	sec "B. /etc/local.d（Alpine 专属 boot 钩子目录）"
	emit_hits locald '/etc/local\.d([^[:alnum:]_-]|$)' \
		"Debian 无 local.d ⇒ 钩子永不执行，且无任何日志"

	sec "C. apk 包管理调用"
	emit_hits apk '(^|[^[:alnum:]_/.-])apk[[:space:]]+(add|del|fix|update|upgrade|world|info|list|policy|search)([^[:alnum:]_-]|$)' \
		"Debian 无 apk ⇒ 装包/修复整段失败，且提示语会误导排查方向" apk

	sec "D. musl 动态解释器路径"
	emit_hits musl '/lib/ld-musl-[a-z0-9_]+\.so' \
		"Debian 默认无 musl loader ⇒ 动态 musl ELF 报 not found（缺的是解释器，不是文件）"

	sec "E. Portage（emerge）"
	emit_hits emerge '(^|[^[:alnum:]_/.-])emerge[[:space:]]+-' \
		"Gentoo 专属；照抄到 Debian 上同样是 no such command"

	sec "F. openrc-run shebang 位置"
	while IFS= read -r f; do
		head -1 "$f" 2>/dev/null | grep -q '^#!/sbin/openrc-run' || continue
		rel=${f#"$REPO"/}
		case "$rel" in
			packaging/elden-userland/templates/*)
				wv "$rel:1 [openrc-shebang] 模板本体（渲染 OpenRC 投影用，不可直接安装）"; continue ;;
			packaging/elden-userland/files/etc/init.d/*|packaging/elden-userland/files/usr/local/sbin/*.initd)
				wv "$rel:1 [openrc-shebang] 设备副本 initd（MANIFEST kind=openrc-initd；*.initd 另见 debian-exclude）"; continue ;;
			scripts/*.initd|rootfs/persistent-overlay/*.initd|rootfs/persistent-overlay/etc-initd-*)
				wv "$rel:1 [openrc-shebang] Alpine 现役根归档副本 / 主机侧运维工件"; continue ;;
		esac
		if is_waived "$rel:1" openrc-shebang >/dev/null; then
			wv "$rel:1 [openrc-shebang] 豁免表命中"
		elif [ "$LIST_ONLY" = 1 ]; then
			printf '  CODE    %s:1 [openrc-shebang]\n' "$rel"
		else
			bad "$rel:1 [openrc-shebang] 被当作可安装脚本但解释器是 OpenRC ⇒ Debian 上 exec 直接 ENOENT"
		fi
	done < <(collect_files)
}

# ---------------------------------------------------------------- 负向自测
self_test() {
	sec "S. 负向自测（注入 → 必须 FAIL；移除 → 必须 PASS）"
	local probe="$HERE/extra/usr/local/sbin/.self-test-probe.sh" wbak
	wbak=$(mktemp) || { bad "S mktemp 失败"; return; }
	if [ -f "$WAIVERS" ]; then cp "$WAIVERS" "$wbak"; else : >"$wbak"; fi
	trap 'rm -f "${probe:-}" "${wbak:-}"; [ -s "${wbak:-}" ] && cat "$wbak" >"$WAIVERS" 2>/dev/null' EXIT

	if bash "$0" >/dev/null 2>&1; then ok "S0 干净树 PASS（rc=0）"
	else bad "S0 干净树应 PASS 却 FAIL（先修主判据）"; fi

	# S1/S2：注入一行 rc-service → 必须 FAIL；移除 → 必须 PASS
	printf '#!/bin/sh\nrc-service greetd restart\n' >"$probe"
	if bash "$0" >/dev/null 2>&1; then bad "S1 注入 rc-service 后仍 PASS ⇒ 门禁是坏的"
	else ok "S1 注入 rc-service → FAIL（rc≠0，符合预期）"; fi
	rm -f "$probe"
	if bash "$0" >/dev/null 2>&1; then ok "S2 移除注入 → PASS（门禁可逆、无残留）"
	else bad "S2 移除注入后仍 FAIL ⇒ 有残留副作用"; fi

	# S3：逐个构造类型都要被覆盖（每次只注入一行 → 必须 FAIL）
	local kind line
	for kind in rc-service rc-update locald apk musl emerge; do
		case "$kind" in
			rc-service) line='rc-service greetd restart' ;;
			rc-update)  line='rc-update add greetd default' ;;
			locald)     line='sh /etc/local.d/elden-bringup.start' ;;
			apk)        line='apk add bluez' ;;
			musl)       line='exec /lib/ld-musl-aarch64.so.1 ./x' ;;
			emerge)     line='emerge -av greetd' ;;
		esac
		printf '#!/bin/sh\n%s\n' "$line" >"$probe"
		if bash "$0" >/dev/null 2>&1; then bad "S3 注入 '$line' 后仍 PASS ⇒ 该类构造未被覆盖"
		else ok "S3 注入 '$line' → FAIL（覆盖 $kind）"; fi
		rm -f "$probe"
	done

	# S4：豁免表必须真的生效（否则豁免只是个摆设）—— 用 guarded 类（不需要排除表）
	printf '#!/bin/sh\nif command -v rc-service >/dev/null 2>&1; then rc-service greetd restart; fi\n' >"$probe"
	if bash "$0" >/dev/null 2>&1; then ok "S4 command -v 守卫的写法 → PASS（可移植写法被放行）"
	else bad "S4 带守卫的跨 init 写法被误判 FAIL"; fi
	rm -f "$probe"

	# S5：stage=skip 的豁免必须真的在 debian-exclude.tsv 里，否则 FAIL
	printf '#!/bin/sh\napk add bluez\n' >"$probe"
	printf 'extra/usr/local/sbin/[.]self-test-probe[.]sh:[0-9]+\tapk\tskip\tSELF-TEST: 未列入排除表，应被 X 段抓出\n' >>"$WAIVERS"
	if bash "$0" >/dev/null 2>&1; then bad "S5 stage=skip 未进排除表仍 PASS ⇒ X 段失效（豁免可被滥用）"
	else ok "S5 stage=skip 未进排除表 → FAIL（X 段有效）"; fi
	cat "$wbak" >"$WAIVERS" 2>/dev/null

	# S6：空理由豁免不能算数
	printf 'extra/usr/local/sbin/[.]self-test-probe[.]sh:[0-9]+\tapk\tguarded\t\n' >>"$WAIVERS"
	if bash "$0" >/dev/null 2>&1; then bad "S6 空理由豁免仍 PASS ⇒ 豁免可被滥用"
	else ok "S6 空理由豁免 → FAIL（W 段有效）"; fi
	cat "$wbak" >"$WAIVERS" 2>/dev/null
	rm -f "$probe"

	sec "S. 结果"
	[ "$fails" = 0 ] && printf '\n==== self-test: 全部通过（FAIL=0）====\n'
}

if [ "$SELF_TEST" = 1 ]; then
	waiver_table_ok
	self_test
else
	waiver_table_ok
	verify_waivers
	scan_all
	sec "R. 结果"
	printf '\n==== check-coupling: FAIL=%d MENTION=%d GUARDED=%d 豁免=%d（scope=%s）====\n' \
		"$fails" "$mentions" "$guarded_n" "$waived" "$SCOPE"
fi
[ "$fails" = 0 ] || exit 1
