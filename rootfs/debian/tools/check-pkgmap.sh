#!/bin/bash
# check-pkgmap.sh — 校验 pkgmap.tsv 覆盖度 + Debian 侧包名可解析（离线），并生成 apt-list.txt
#
# 判据（任何一条 FAIL 即退出码 1）：
#   A 覆盖度：apk-world.txt 每一行（剥离 apk 签名后缀）在 pkgmap.tsv 里都有且仅有一行
#   B 可解析：每个 map/add 的 Debian 包名都能在 **sid 索引** 里查到（apt-cache，只读）
#   C 禁用项：不得映射到 linux-image-* / firmware-qcom-soc（会把 Debian 内核或错误固件带进来）
#   D 生成物：apt-list.txt = map/add 的 debian 去重并集（喂给 debootstrap/apt-get install）
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
if [ "$fail" -gt 0 ]; then
	say "结果: FAIL=$fail WARN=$warn"
	exit 1
fi
say "结果: FAIL=0 WARN=$warn"
