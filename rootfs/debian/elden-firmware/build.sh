#!/bin/bash
# build.sh — 生成 elden-firmware_<ver>_all.deb（本机专属固件包，供 Debian/Mobian 根使用）
#
# 为什么要有这个包（不是"顺手打个 tar"）：
#   1. Debian 的 firmware-qcom-soc **没有 sm8750 目录** ⇒ 换发行版后 ADSP/CDSP/GPU/WiFi/BT/触屏/
#      触觉/功放/tplg 全部没固件，表现为"驱动 probe 失败"而不是"缺文件"（最难归因的一类）。
#   2. 固件的**路径**是 DT `firmware-name` 的契约；名字错一个字符，驱动只报 -ENOENT。
#      所以本脚本把「DTS 声明的固件名」当**门禁**：缺一个就 FAIL，不出包。
#   3. 音频 tplg（`qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin`，自编 16 860 B）只能靠本包分发。
#
# 用法：
#   bash build.sh --check                 # 只做 DTS↔源树 一致性检查（默认源 = 设备 /lib/firmware）
#   bash build.sh --stage                 # 从源树取文件到 out/debian/firmware-root/
#   bash build.sh --deb                   # 打 deb（隐含 --stage）
#   bash build.sh --all                   # check + stage + deb + 包内复核
#   SRC=/path/to/firmware bash build.sh --check          # 用本地目录当源（离线）
#   DEV=root@192.168.7.1 bash build.sh --all             # 换设备
#   bash build.sh --check --dts-only                     # 只检查 DT 列表（不查文件）
#
# 判据（--all 全过才 rc=0）：
#   A 每条 DT firmware-name 在包里都有（.mdt 需带 .bNN 分段；允许 .zst 压缩变体）
#   B 包里没有 *.bak / *.tmp
#   C dpkg-deb -c 的条目数 = 暂存文件数；`dpkg-deb -I` 的 Package/Architecture 正确
#   D 解包到临时目录后再跑一遍 A（防止"文件在暂存树里但没进包"）
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
OUT=${OUT:-$ROOT/out/debian}
STAGE=${STAGE:-$OUT/firmware-root}
DEV=${DEV:-root@192.168.7.1}
SRC=${SRC:-}                       # 留空 = 用设备
VERSION=${VERSION:-1.0~$(date -u +%Y%m%d)}
PKG=elden-firmware
DTS="$ROOT/build/vk151/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts"
DTSI="$ROOT/build/vk151/arch/arm64/boot/dts/qcom/sm8750.dtsi"
DTS_ONLY=0

say() { printf '%s\n' "$*"; }
die() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }

for a in "$@"; do case "$a" in
	--check) MODE=check ;;
	--dts-only) DTS_ONLY=1 ;;
	--stage) MODE=stage ;;
	--deb) MODE=deb ;;
	--all) MODE=all ;;
	-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
	*) die "未知参数 $a" ;;
esac; done
MODE=${MODE:-check}

# ---------- 源树访问抽象：设备 or 本地目录 ----------
src_find() { # 全部文件清单（相对 /lib/firmware 根）。只跑一次，后续在本地过滤。
	# 注意两件事：
	#   1. 不要把 find 的 -path 表达式拼进 ssh 命令 —— 远端 shell 会先展开通配符，
	#      出现 "paths must precede expression"。清单很小（本机 120 个），本地过滤更安全。
	#   2. **必须 ssh -n**：本函数会在 `while read … < paths.txt` 循环里被调用，
	#      不带 -n 的 ssh 会吞掉循环的 stdin ⇒ 只处理 paths.txt 的第一行（2026-10-26 实测：
	#      包里只剩 qcom/sm8750，ath12k/awinic/qca 静默缺失）。
	if [ -n "$SRC" ]; then
		( cd "$SRC" && find . -mindepth 1 -type f ) | sed 's|^\./||'
	else
		ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -n "$DEV" \
			"cd /lib/firmware && find . -mindepth 1 -type f" | sed 's|^\./||'
	fi
}
SRC_LIST_CACHE=""
src_list() { # 缓存版 src_find
	if [ -z "$SRC_LIST_CACHE" ]; then
		SRC_LIST_CACHE=$(mktemp); src_find > "$SRC_LIST_CACHE"
		trap 'rm -f "$SRC_LIST_CACHE"' EXIT
	fi
	cat "$SRC_LIST_CACHE"
}
src_fetch() { # $1 = 文件清单（相对路径，每行一个）；$2 = 目标目录；$3 = 源根前缀（默认 /lib/firmware）
	# 用 rsync --files-from 而不是 `tar -T -`：设备是 Alpine，busybox tar 对
	# `--files-from=-` 支持不完整（2026-10-26 实测：远端传输静默漏掉 ath12k/awinic/qca）。
	local list=$1 dst=$2 sub=${3:-/lib/firmware}
	mkdir -p "$dst"
	if [ -n "$SRC" ]; then
		rsync -a --files-from="$list" "$SRC/" "$dst/" || die "rsync(本地) 失败"
	else
		rsync -a --files-from="$list" -e 'ssh -o StrictHostKeyChecking=no' \
			"$DEV:$sub/" "$dst/" || die "rsync(设备) 失败"
	fi
}

# ---------- 第二内容树：/usr/share/qcom（传感器 DSP 文件，hexagonrpcd -R 的根）----------
# 为什么单列：它不在 /lib/firmware，且路径契约是 hexagonrpcd 的 -R（不是 DT firmware-name）。
# 缺失后果：iio-sensor-proxy 在 Debian 上拿不到任何传感器（本机 /sys/bus/iio 恒空）。
QCOM_SUB=/usr/share/qcom
qcom_stage() { # $1 = 暂存树根
	local stage=$1 list; list=$(mktemp)
	while read -r p; do
		case "$p" in ''|\#*) continue ;; esac
		case "$p" in
			*/) ( cd "$QCOM_SUB" 2>/dev/null && find "${p%/}" -type f 2>/dev/null ) \
				|| ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -n "$DEV" \
					"cd $QCOM_SUB && find ${p%/} -type f" 2>/dev/null ;;
			*)  : ;;
		esac
	done < "$HERE/paths-qcom.txt" | sed 's|^\./||' | grep -vE '\.(bak|tmp)$' | sort -u > "$list"
	[ -s "$list" ] || die "paths-qcom.txt 在源树上匹配到 0 个文件（传感器 DSP 文件缺失？）"
	say "  [qcom] 匹配 $(wc -l < "$list") 个文件"
	src_fetch "$list" "$stage$QCOM_SUB" "$QCOM_SUB"
	# 门禁 A'：传感器链的三个必备项（sensors/sns_reg.conf / sensors/config/ / sensors/registry/）
	# 注意层级：`-R` 根 = `.../TB322FC`，DSP 请求带 `sensors/` 前缀 ⇒ 文件在 `.../TB322FC/sensors/` 下
	# （设备实测：ls /usr/share/qcom/sm8750/LENOVO/TB322FC/sensors → sns_reg.conf + config/ + registry/）
	local miss=0 sens=sm8750/LENOVO/TB322FC/sensors
	for must in $sens/sns_reg.conf; do
		[ -f "$stage$QCOM_SUB/$must" ] || { say "  MISS(qcom) $must"; miss=$((miss+1)); }
	done
	for must in config registry; do
		if [ "$must" = registry ]; then
			# 设备侧 registry/ 是**空目录**（实测 2026-10-26：find → 1 = 只有目录本身），
			# 而 rsync --files-from 不会带空目录 ⇒ 显式落下目录本身，保持与设备布局一致
			# （DSP/sensorspd 可能往里写；`-R` 根下的相对路径不能凭空少一层）。
			mkdir -p "$stage$QCOM_SUB/$sens/registry"
		else
			compgen -G "$stage$QCOM_SUB/$sens/$must/*" >/dev/null \
				|| { say "  MISS(qcom) $sens/$must/ 为空"; miss=$((miss+1)); }
		fi
	done
	[ "$miss" = 0 ] || die "传感器 DSP 文件树不完整（缺 $miss 项）"
	rm -f "$list"
}

# ---------- A: DT firmware-name → 文件是否存在 ----------
dts_required() {
	python3 - "$DTS" "$DTSI" <<'PY'
import re, sys
names = []
for path in sys.argv[1:]:
    try:
        txt = open(path).read()
    except OSError:
        continue
    for m in re.finditer(r'firmware-name\s*=\s*"([^"]+)"', txt):
        names.append(m.group(1))
seen = []
for n in names:
    if n not in seen:
        seen.append(n)
print("\n".join(seen))
PY
}

check_files() { # $1 = local|remote ；$2 = 本地源树根（mode=local 时用）
	local mode=$1; local srcroot=${2:-}; local fail=0
	local avail
	avail=$(mktemp); trap 'rm -f "${avail:-}"' RETURN
	if [ "$mode" = local ]; then
		[ -n "$srcroot" ] || die "check_files local 需要源树根"
		( cd "$srcroot" && find . -mindepth 1 -type f ) | sed 's|^\./||' | sort > "$avail"
	else
		src_list | sort > "$avail"
	fi
	say "源树文件数: $(wc -l < "$avail")"
	while read -r fw; do
		[ -n "$fw" ] || continue
		# DT 名 → 驱动实际请求的路径（少数驱动在代码里加前缀/改写名字）。见 name-map.tsv。
		if [ -f "$HERE/name-map.tsv" ]; then
			mapped=$(awk -F'\t' -v k="$fw" '$1==k && $2!="" {print $2; exit}' "$HERE/name-map.tsv")
			[ -n "$mapped" ] && fw=$mapped
		fi
		case "$fw" in *.json|*/*.jsn) continue ;; esac
		# .mdt 需要分段；.mbn 可能以 .zst 分发
		local base=${fw%.zst}
		local ok=0
		if grep -qxF "$fw" "$avail" || grep -qxF "$base" "$avail" || grep -qxF "$base.zst" "$avail"; then
			ok=1
		fi
		case "$base" in
			*.mdt)
				local stem=${base%.mdt}
				grep -qE "^${stem}\.b[0-9]{2}$" "$avail" || ok=0
				;;
		esac
		if [ "$ok" = 1 ]; then
			say "  ok   $fw"
		else
			say "  MISS $fw"; fail=$((fail+1))
		fi
	done < <(dts_required)
	return $fail
}

stage() {
	say "== stage → ${STAGE#$ROOT/}"
	rm -rf "$STAGE"
	mkdir -p "$STAGE/lib/firmware" "$STAGE/DEBIAN"
	# 展开 paths.txt：目录递归 / 文件通配，排除 *.bak *.tmp
	local list; list=$(mktemp)
	while read -r p; do
		case "$p" in ''|\#*) continue ;; esac
		case "$p" in
			*/) src_list | grep -F "${p%/}/" ;;
			*)  src_list | grep -E "^${p//\*/.*}$" ;;
		esac
	done < "$HERE/paths.txt" | grep -vE '\.(bak|tmp)$' | sort -u > "$list"
	[ -s "$list" ] || die "paths.txt 在源树上匹配到 0 个文件"
	say "  匹配 $(wc -l < "$list") 个文件"
	src_fetch "$list" "$STAGE/lib/firmware"
	# 逐条校验：清单里每个文件都真的落到了暂存树
	local missing=0
	while read -r f; do
		[ -f "$STAGE/lib/firmware/$f" ] || { say "  MISS(stage) $f"; missing=$((missing+1)); }
	done < "$list"
	[ "$missing" = 0 ] || die "staging 缺 $missing 个文件"
	rm -f "$list"
	# 第二内容树：/usr/share/qcom（传感器 DSP）
	qcom_stage "$STAGE"
	# 校验清单（sha256，作为可复现证据；换机/换源可对账）
	( cd "$STAGE" && find . -type f ! -path './DEBIAN/*' -print0 | sort -z | xargs -0 sha256sum ) \
		> "$STAGE/usr-share-doc.sha256" 2>/dev/null
	mkdir -p "$STAGE/usr/share/doc/$PKG"
	mv "$STAGE/usr-share-doc.sha256" "$STAGE/usr/share/doc/$PKG/MANIFEST.sha256"
	cat > "$STAGE/usr/share/doc/$PKG/README" <<-EOF
	elden-firmware ${VERSION} — TB322FC / SM8750 专属固件（mainline Linux）
	内容清单见 MANIFEST.sha256；来源路径与来源设备见包内 DEBIAN/control 的 Description。
	不要用发行版的 firmware-qcom-soc 顶替：它没有 sm8750 目录。
	EOF
	local bytes; bytes=$(du -sb "$STAGE/lib/firmware" | cut -f1)
	local qbytes; qbytes=$(du -sb "$STAGE$QCOM_SUB" 2>/dev/null | cut -f1); qbytes=${qbytes:-0}
	cat > "$STAGE/DEBIAN/control" <<-EOF
	Package: $PKG
	Version: $VERSION
	Architecture: all
	Maintainer: elden project <elden@localhost>
	Installed-Size: $(( (bytes + qbytes) / 1024 ))
	Section: non-free-firmware
	Priority: optional
	Description: Lenovo Y700 Gen4 (TB322FC / SM8750) firmware for mainline Linux
	 ADSP/CDSP split images, Adreno 830 zap/sqe/gmu/aqe, ath12k PEACH (amss/board/m3),
	 QCA Bluetooth (brhbtfw/brhbtnv), Novatek NT36536 touch, Awinic haptic/speaker ACF,
	 and the self-built AudioReach topology (qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin).
	 .
	 Also ships the sensor DSP file tree ($QCOM_SUB/sm8750/LENOVO/TB322FC, -R root for
	 hexagonrpcd; payload under sensors/: sns_reg.conf + config/ + registry/), which is
	 NOT under /lib/firmware. Without it iio-sensor-proxy sees no sensors at all
	 (/sys/bus/iio is empty on this board; the 7 sensors live on the SSC).
	 .
	 Generated by rootfs/debian/elden-firmware/build.sh from ${SRC:-$DEV}.
	EOF
	say "  暂存大小 $(du -sh "$STAGE/lib/firmware" | cut -f1)"
}

deb() {
	local out="$OUT/${PKG}_${VERSION}_all.deb"
	mkdir -p "$OUT"
	say "== deb → ${out#$ROOT/}"
	dpkg-deb --root-owner-group -Zxz --build "$STAGE" "$out" >/dev/null || die "dpkg-deb 失败"
	say "  $(du -h "$out" | cut -f1)  sha256=$(sha256sum "$out" | cut -c1-16)…"
	# C: 条目数一致
	local n_stage n_deb
	n_stage=$(find "$STAGE" -type f ! -path "$STAGE/DEBIAN/*" | wc -l)
	n_deb=$(dpkg-deb -c "$out" | grep -c '^-')
	[ "$n_stage" = "$n_deb" ] || die "包内条目 $n_deb ≠ 暂存 $n_stage"
	say "  条目数 $n_deb ✓"
	# D: 解包后再跑一遍 DT 检查
	local ex; ex=$(mktemp -d)
	dpkg-deb -x "$out" "$ex"
	if check_files local "$ex/lib/firmware" >/dev/null 2>&1; then
		say "  解包后 DT 固件检查 ✓"
	else
		check_files local "$ex/lib/firmware"
		rm -rf "$ex"; die "解包后 DT 固件检查失败"
	fi
	# D'：解包后传感器 DSP 树仍在（防“进了暂存树但没进包”）
	[ -f "$ex$QCOM_SUB/sm8750/LENOVO/TB322FC/sensors/sns_reg.conf" ] \
		|| { rm -rf "$ex"; die "解包后缺 $QCOM_SUB/sm8750/LENOVO/TB322FC/sensors/sns_reg.conf"; }
	say "  解包后传感器 DSP 树检查 ✓"
	rm -rf "$ex"
	say "$out"
}

case "$MODE" in
check)
	if [ "$DTS_ONLY" = 1 ]; then dts_required; exit 0; fi
	[ -n "$SRC" ] && check_files local "$SRC" || check_files remote
	;;
stage) stage ;;
deb)   stage; deb ;;
all)   { [ -n "$SRC" ] && check_files local "$SRC" || check_files remote; } || die "DT 固件检查失败（先修 DT 名或补固件）"
       stage; deb ;;
esac
