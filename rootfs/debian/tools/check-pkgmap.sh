#!/bin/bash
# check-pkgmap.sh — 校验 pkgmap.tsv 覆盖度 + Debian 侧包名可解析（离线），并生成 apt-list.txt
#
# 判据（任何一条 FAIL 即退出码 1）：
#   A 覆盖度：apk-world.txt 每一行（剥离 apk 签名后缀）在 pkgmap.tsv 里都有且仅有一行
#   B 可解析：每个 map/add 的 Debian 包名都能在 **sid 索引** 里查到（apt-cache，只读）
#   C 禁用项：不得映射到 linux-image-* / firmware-qcom-soc（会把 Debian 内核或错误固件带进来）
#   D 生成物：apt-list.txt = map/add 的 debian 去重并集（喂给 debootstrap/apt-get install）
#   E 服务运行时依赖（svc-deps.tsv）：provider 必须真的会装上；命令型条目必须真被引用
#     （E 段是 2026-10-26 补的：A–D 只管「apk world 那 120 行」，盖不住「服务用什么命令」）
#
# 用法：
#   bash rootfs/debian/tools/check-pkgmap.sh                    # 默认用 /opt/elden/arm64-sid 的索引
#   CHROOT=/path/to/sid-root bash rootfs/debian/tools/check-pkgmap.sh
#   bash rootfs/debian/tools/check-pkgmap.sh --list             # 只打印 apt-list.txt
#
# 为什么用 chroot 的 apt 索引而不是 packages.debian.org：
#   * 离线可跑、与真正会装进去的索引同源（sid 会滚动，网页查询会漂）
#   * 一次调用即可批量解析 130+ 包名，不需要网络
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
CHROOT=${CHROOT:-/opt/elden/arm64-sid}
MAP="$ROOT/rootfs/debian/pkgmap.tsv"
WORLD="$ROOT/rootfs/persistent-overlay/apk-world.txt"
OUT="$ROOT/rootfs/debian/apt-list.txt"
DEPS="$ROOT/rootfs/debian/svc-deps.tsv"
USERLAND="$ROOT/packaging/elden-userland"
OWNDEB="$ROOT/out/debian"

LIST_ONLY=0
[ "${1:-}" = "--list" ] && LIST_ONLY=1

[ -f "$MAP" ] || { echo "missing $MAP" >&2; exit 2; }
[ -f "$WORLD" ] || { echo "missing $WORLD" >&2; exit 2; }

apt_show() { # $1 = package
	apt-cache -o APT::Architecture=arm64 \
		-o Dir::State::Lists="$CHROOT/var/lib/apt/lists" \
		-o Dir::State::status="$CHROOT/var/lib/dpkg/status" \
		-o Dir::Etc::sourcelist="$CHROOT/etc/apt/sources.list" \
		-o Dir::Etc::sourceparts=/dev/null \
		show "$1" 2>/dev/null | awk '/^Version:/{print $2; exit}'
}

fail=0; warn=0
say()  { printf '%s\n' "$*"; }
bad()  { printf 'FAIL  %s\n' "$*"; fail=$((fail+1)); }
warnf(){ printf 'WARN  %s\n' "$*"; warn=$((warn+1)); }

# --- B/C: 可解析 + 禁用项 ---
tmp_apt=$(mktemp); trap 'rm -f "$tmp_apt"' EXIT
nmap=0; ndrop=0; nadd=0; nmiss=0
# 注意：不能用 IFS=$'\t' + read —— tab 是 IFS whitespace，空列会被吞掉（drop 行的空 debian 列
# 会把 note 读成包名）。这里先用 awk 换成分隔符 \x1f 再 read，保留空列。
while IFS=$'\x1f' read -r apk action debian note; do
	case "$apk" in ''|\#*) continue ;; esac
	case "$action" in
		map)   nmap=$((nmap+1))  ;;
		add)   nadd=$((nadd+1))  ;;
		drop)  ndrop=$((ndrop+1)); [ -z "${debian:-}" ] || warnf "drop 行仍写了 debian: $apk -> $debian" ;;
		*)     bad "未知 action '$action'（行: $apk）"; continue ;;
	esac
	[ "$action" = drop ] && continue
	[ -n "${debian:-}" ] || { bad "map/add 行缺少 debian 包名: $apk"; continue; }
	for p in $debian; do
		case "$p" in
			linux-image-*|firmware-qcom-soc*) bad "禁用包被映射进来: $apk -> $p"; continue ;;
		esac
		printf '%s\n' "$p" >> "$tmp_apt"
		v=$(apt_show "$p")
		if [ -z "$v" ]; then
			bad "sid 索引里不存在: $p（来自 $apk）"; nmiss=$((nmiss+1))
		fi
	done
done < <(awk -F'\t' 'BEGIN{OFS="\x1f"} !/^#/ && NF {print $1,$2,$3,$4}' "$MAP")

sort -u -o "$tmp_apt" "$tmp_apt"

# --- A: 覆盖度（apk-world 每行都必须有映射） ---
missing_rows=$(comm -23 \
	<(sed 's/>.*$//' "$WORLD" | grep -vE '^\s*$' | sort -u) \
	<(awk -F'\t' '$1 !~ /^#/ && $1 != "" {print $1}' "$MAP" | sort -u))
if [ -n "$missing_rows" ]; then
	while read -r m; do bad "apk-world 里的包没有映射行: $m"; done <<< "$missing_rows"
fi
# 反向：pkgmap 里 apk-world 以外的 map 行（可能是笔误）
extra_rows=$(comm -13 \
	<(sed 's/>.*$//' "$WORLD" | grep -vE '^\s*$' | sort -u) \
	<(awk -F'\t' '$1 !~ /^#/ && $2 == "map" {print $1}' "$MAP" | sort -u))
[ -n "$extra_rows" ] && while read -r m; do warnf "pkgmap 有 apk-world 中不存在的 map 行: $m"; done <<< "$extra_rows"

if [ "$LIST_ONLY" = 1 ]; then cat "$tmp_apt"; exit 0; fi

# --- D: 生成 apt-list.txt ---
{
	echo "# apt-list.txt — 由 rootfs/debian/tools/check-pkgmap.sh 从 pkgmap.tsv 生成，勿手改"
	echo "# 生成时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)  索引: $CHROOT"
	cat "$tmp_apt"
} > "$OUT"

say ""
say "统计: map=$nmap drop=$ndrop add=$nadd  解析失败=$nmiss  apt 包数=$(wc -l < "$tmp_apt")"
say "生成: ${OUT#$ROOT/}（$(grep -c -v '^#' "$OUT") 个包）"

# --- E: 服务运行时依赖（命令/路径 → 提供包 → 证据） ---
# 判据用的是「**空 dpkg status 的依赖闭包**」而不是「apt-list 里的字面包名」：
#   minbase 根上真正会被装的 = apt-get install $(apt-list) 解出来的闭包（含 Depends）。
#   拿 chroot 现成的 dpkg status 做模拟是错的 —— 那个 chroot 里已经有 build-essential，
#   会把「其实闭包会带」跟「真的缺」混为一谈（2026-10-26 就这么误判过 3 个包，已纠正）。
#   所以这里先把 status 指到一个空文件，再收集所有 `Inst <pkg>`。
if [ -f "$DEPS" ]; then
	say ""
	say "[E. 服务运行时依赖 svc-deps.tsv]"
	closure=$(mktemp); : > /tmp/elden-empty-status
	if command -v apt-get >/dev/null; then
		apt-get -s --no-install-recommends \
			-o Dir::Etc::sourcelist="$CHROOT/etc/apt/sources.list" \
			-o Dir::Etc::sourceparts=/dev/null \
			-o Dir::State::Lists="$CHROOT/var/lib/apt/lists" \
			-o Dir::State::status=/tmp/elden-empty-status \
			-o Dir::Cache=/tmp \
			-o APT::Architecture=arm64 -o APT::Architectures=arm64 \
			install $(cat "$tmp_apt") 2>/dev/null \
			| awk '/^Inst /{print $2}' | sort -u > "$closure"
	fi
	nC=$(wc -l < "$closure")
	if [ "$nC" -gt 0 ]; then
		say "  minbase 闭包 $nC 个包（空 status 模拟）"
		cat "$closure" >> "$tmp_apt"; sort -u -o "$tmp_apt" "$tmp_apt"
	else
		warnf "E 闭包模拟不可用（apt-get 缺失或索引不全），退回「字面包名」判据"
	fi
	nE=0
	while IFS=$'\x1f' read -r what providers evidence; do
		case "$what" in ''|\#*) continue ;; esac
		nE=$((nE + 1))
		[ -n "${providers:-}" ] || { bad "E 行缺 providers: $what"; continue; }
		for p in $providers; do
			case "$p" in
			own:*)
				name=${p#own:}
				if ! compgen -G "$OWNDEB/${name}_*.deb" >/dev/null; then
					warnf "E 自建包待建: $name（$what 需要；产物应为 out/debian/${name}_*.deb）"
				fi
				;;
			*)
				if ! grep -qx "$p" "$tmp_apt"; then
					bad "E 提供包不在 minbase 闭包里: $p（$what 需要）"
				fi
				;;
			esac
		done
		# E2：命令型条目必须真被 userland 引用（防表腐化）
		case "$what" in
		/*) : ;;
		*)
			if [ -d "$USERLAND" ] && ! grep -rqE "(^|[^[:alnum:]_./-])${what}([[:space:]]|$)" \
				"$USERLAND/files" "$USERLAND/extra" 2>/dev/null; then
				warnf "E 声明了但 userland 里没人用: $what（表腐了吗？）"
			fi
			;;
		esac
	done < <(awk -F'\t' 'BEGIN{OFS="\x1f"} !/^#/ && NF {print $1,$2,$3}' "$DEPS")
	[ "$nE" -gt 0 ] && say "  条目 $nE 条已核（provider ∈ minbase 闭包 ∪ 自建 deb；命令型条目在 userland 有引用）"
	rm -f "$closure" /tmp/elden-empty-status
else
	warnf "缺 $DEPS（服务运行时依赖门未启用）"
fi

if [ "$fail" -gt 0 ]; then
	say "结果: FAIL=$fail WARN=$warn"
	exit 1
fi
say "结果: FAIL=0 WARN=$warn"
