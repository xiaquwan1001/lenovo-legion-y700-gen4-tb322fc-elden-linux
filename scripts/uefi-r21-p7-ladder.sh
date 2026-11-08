#!/bin/bash
# uefi-r21-p7-ladder.sh — UEFI R21「p7 / preamble7」一族镜像的**唯一重建入口**（G1-29 线，纯主机侧）
#
# 为什么有它（2026-11-06 整理轮）：11-06 的判据阶梯（`reports/uefi-vsstop-and-fbconsole-20261106.md` §6）
# 直接 `fastboot boot` 这四件——
#     out/r21-sbstop/uefi-preamble7-r1.img   （ABL 侧载 UEFI 的入场件）
#     out/r21-sbstop/p7-m3-stop34.img / stop27.img  （窗口上下界）
#     out/r21-sbstop/p7-s26-pb3.img          （sbprobe=3 通道基件）
# 而它们的产出方式是**手敲命令**：`grep -rn 'p7-m3\|preamble7' scripts/` 当时零命中
# ⇒ 活线基线事实上不可再生（`reports/out-uefi-trim-20261106.md` §0/§3）。
#
# 本脚本把三步固化成命令：
#   1) 构建 UEFI 变体 R7（probe-markonly / mode 3）—— 配方 = `patches/uefi/p7-recipe.txt`
#      （从 `reports/artifacts/uefi-20261105R7-markonly/manifest.txt` 逐字导出，35 个补丁按序）
#   2) `uefi-repack-v2aligned.py` 打成 boot v2（base 0）⇒ `uefi-preamble7-r1.img`
#      （实测：用既有 R7 构建目录 repack ⇒ sha256 与在盘件**逐字节相同**）
#   3) `uefi-sbstop-patch.py --probe 3` 逐档写 cmdline 前缀 ⇒ `p7-*` 各件
#      （实测：`sbstop=26 sbprobe=3 ` 前缀 ⇒ 与在盘 `p7-s26-pb3.img`/`p7-m3-stop34.img` 逐字节相同）
#
# 用法：
#   scripts/uefi-r21-p7-ladder.sh --list                  # 列出本脚本会产出的件与判据
#   scripts/uefi-r21-p7-ladder.sh --verify                # 只重建镜像段，与在盘件比对 sha（不构建）
#   scripts/uefi-r21-p7-ladder.sh --mkimg-only [--outdir DIR]   # 默认用**归档的 R7 构建目录** re-pack（秒级、逐字节复现）
#   scripts/uefi-r21-p7-ladder.sh --mkimg-only --rebuild        # 从配方重建 UEFI（~5-10 min；sha 必变，见 PITFALLS #510）
#   scripts/uefi-r21-p7-ladder.sh --mkimg-only --build-dir DIR  # 指定别的变体目录
#   STAGES="26 34" scripts/uefi-r21-p7-ladder.sh --mkimg-only   # 只造指定档
#   scripts/uefi-r21-p7-ladder.sh --gen p58 --verify            # 按「世代」一键复现（见下）
#
# 世代（--gen，2026-11-08 新增）：把「配方 + 构建归档 + 在盘指纹」绑成一个名字，
#   避免每次手敲 PFX/RECIPE/BUILD_DIR/KEPT 四件套（敲漏 BUILD_DIR 会退回 R7 归档、静默造错件）：
#     p7  → patches/uefi/p7-recipe.txt  + reports/artifacts/uefi-20261105R7-markonly
#            + reports/artifacts/uefi-r21-sbstop-trim-20261106/KEPT.sha256（= 历史默认）
#     p54 → patches/uefi/p54-recipe.txt + reports/artifacts/uefi-20261107R49-p54
#            + patches/uefi/p54-kept.sha256（p58 的前一代，留作对照）
#     p58 → patches/uefi/p58-recipe.txt + reports/artifacts/uefi-20261107R46R53-p58
#            + patches/uefi/p58-kept.sha256  ← **当前有效世代**（UEFI 交棒打通那一发）
#   环境变量 PFX/RECIPE/BUILD_DIR/KEPT 显式给出时优先于 --gen。
#
# 世代（2026-11-06 新增）：默认为 p7 世代（R7 配方 + 在盘件 sha 比对）。后续世代用环境变量切：
#   PFX=p8 RECIPE=patches/uefi/p8-recipe.txt OUTDIR=out/r21-sbstop-p8 \
#     scripts/uefi-r21-p7-ladder.sh --mkimg-only --rebuild
#   （非 p7 世代件名 = $PFX-*.img / uefi-preamble<N>-r1.img，默认不比对 p7 的在盘指纹）
#   BUILD_ARCHIVE=<dir> 可把变体构建目录落到持久位置（否则临时目录随 trap 删掉，只留镜像）。
#
# 判据与「可复现」的精确含义（2026-11-06 实测）：
#   · **镜像段可逐字节复现**：以归档的 R7 构建目录（`reports/artifacts/uefi-20261105R7-markonly/`，FD 已入 git）
#     为基点，repack + 前缀改写后的 4 件 sha256 与在盘件**完全相同**（`--verify` rc=0）。
#   · **构建段不逐字节可复现**：`--rebuild` 两次构建 FD 必不同（差 `__DATE__`/`__TIME__` 及其立即数，
#     `PITFALLS #510`）⇒ 重建后**不要比 sha**，只验「关键字串在、逐块 diff 只落在时间字符串区」。
#     ⇒ 默认不重建；`--rebuild` 只用于「归档 FD 丢了/要改补丁」的场合。
#
# 纪律：**零写盘** —— 本脚本只写 `out/`（或 --outdir），不碰设备、不 flash、不改 GPT/槽位。
#       上机部分仍按 `reports/uefi-vsstop-and-fbconsole-20261106.md` §6 手打（每崩一次要物理断电）。
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RECIPE=${RECIPE:-$ROOT/patches/uefi/p7-recipe.txt}
BUILD_DIR=${BUILD_DIR:-}
OUTDIR=${OUTDIR:-$ROOT/out/r21-sbstop}
STAGES=${STAGES:-"26 27 30 31 32 33 34 5 7"}
PROBE=${PROBE:-3}
KEPT=${KEPT:-$ROOT/reports/artifacts/uefi-r21-sbstop-trim-20261106/KEPT.sha256}
# 2026-11-06: 世代前缀。p7 = R7 基线（在盘件，KEPT 逐字节可复现）；
# p8 = p7 配方 + VS_STOP(35..38) 尾段二分；p9 = p8 + out: 诊断写按 SbProbeMode 门控。
# 非 p7 世代默认不比对在盘指纹（件名不同，比也无意义），要双跑比对请显式 KEPT=…。
PFX=${PFX:-p7}
PREAMBLE=uefi-preamble${PFX#p}-r1.img
if [ "$PFX" != p7 ] && [ "$KEPT" = "$ROOT/reports/artifacts/uefi-r21-sbstop-trim-20261106/KEPT.sha256" ]; then
	KEPT=/dev/null
fi
DEFAULT_BUILD_DIR=$ROOT/reports/artifacts/uefi-20261105R7-markonly
MODE=list
REBUILD=0
GEN=${GEN:-}

die() { echo "uefi-r21-p7-ladder: $*" >&2; exit 1; }
note() { echo "[p7] $*" >&2; }   # 一律 stderr：build_variant 用 stdout 回传路径

# 件名：26 用历史名 s26-pb3（阶段基件），其余 m3-stopN
piece_name() {
	case "$1" in
		26) echo "$PFX-s26-pb3.img" ;;
		*)  echo "$PFX-m3-stop$1.img" ;;
	esac
}

while [ $# -gt 0 ]; do
	case "$1" in
		--list)       MODE=list
REBUILD=0; shift;;
		--verify)     MODE=verify; shift;;
		--mkimg-only) MODE=mkimg; shift;;
		--outdir)     OUTDIR=$2; shift 2;;
		--build-dir)  BUILD_DIR=$2; shift 2;;
		--rebuild)    REBUILD=1; shift;;
		--stages)     STAGES=$2; shift 2;;
		--probe)      PROBE=$2; shift 2;;
		--gen)        GEN=$2; shift 2;;
		-h|--help)    sed -n '2,40p' "$0"; exit 0;;
		*) die "unknown option: $1";;
	esac
done

# ---------- 0. 世代表（--gen）：只填「未显式给出」的那几项 ----------
if [ -n "$GEN" ]; then
	case "$GEN" in
		p7)  _rec=patches/uefi/p7-recipe.txt;  _bd=uefi-20261105R7-markonly;         _kept=reports/artifacts/uefi-r21-sbstop-trim-20261106/KEPT.sha256; _out=r21-sbstop;;
		p54) _rec=patches/uefi/p54-recipe.txt; _bd=uefi-20261107R49-p54;               _kept=patches/uefi/p54-kept.sha256; _out=r21-sbstop-p54;;
		p58) _rec=patches/uefi/p58-recipe.txt; _bd=uefi-20261107R46R53-p58;            _kept=patches/uefi/p58-kept.sha256; _out=r21-sbstop-p58;;
		*) die "--gen 只认 p7/p54/p58（见脚本头部）；收到: $GEN";;
	esac
	[ -n "${PFX_EXPLICIT:-}" ] || PFX=$GEN
	[ -n "${RECIPE_EXPLICIT:-}" ] || RECIPE=$ROOT/$_rec
	[ -n "${BUILD_DIR:-}" ] || BUILD_DIR=$ROOT/reports/artifacts/$_bd
	[ -n "$_kept" ] && { [ -n "${KEPT_EXPLICIT:-}" ] || KEPT=$ROOT/$_kept; }
	# 无指纹的代次：清掉可能残留的 p7 指纹，否则会拿 p7 件去比而误报 FAIL
	[ -z "$_kept" ] && [ -z "${KEPT_EXPLICIT:-}" ] && KEPT=/dev/null
	note "世代 $GEN ⇒ 配方 $_rec / 构建 $_bd / 指纹 ${_kept:-（无）}"
	PREAMBLE=uefi-preamble${PFX#p}-r1.img   # 必须在改完 PFX 后重算（否则仍叫 preamble7）
fi

[ -r "$RECIPE" ] || die "缺配方 $RECIPE"

# ---------- 1. 构建（仅 --mkimg-only 且未指定 --build-dir 时） ----------
build_variant() {
	local out=$1 args=() kind val
	while IFS=$'\t' read -r kind val; do
		case "$kind" in
			''|\#*) continue;;
			patch)  args+=(--patch "$ROOT/$val");;
			scale)  args+=(--scale "$val");;
			shim)   args+=(--shim "$val");;
			ufsdxe) args+=(--ufsdxe "$val");;
			rmvmdxe) args+=(--rmvmdxe "$val");;
			base)   export UEFI_BASE=$val;;
			size)   export UEFI_SIZE=$val;;
			*) die "配方里有未知字段: $kind";;
		esac
	done < "$RECIPE"
	note "构建变体 → $out"
	# 注意：uefi-build-variant.sh 自己会往 stdout 打 sha256 清单 ⇒ 必须改道 stderr，
	# 否则 build_variant 的「回传路径」会被污染（2026-11-06 实测踩到，见 PITFALLS #520 同族问题）。
	bash "$ROOT/scripts/uefi-build-variant.sh" "$out" "${args[@]}" --clean >&2 || die "构建失败（见 $out/build.log）"
	[ -f "$out/SM8750_EFI.fd" ] || die "构建无产物 SM8750_EFI.fd"
	BUILT_DIR=$out
}

# ---------- 2. repack → preamble7 ----------
repack_preamble() {
	local bd=$1 dst=$2
	[ -f "$bd/BootShim.bin" ] && [ -f "$bd/SM8750_EFI.fd" ] || die "$bd 不是 uefi-build-variant.sh 的产物目录"
	python3 "$ROOT/scripts/uefi-repack-v2aligned.py" --build-dir "$bd" -o "$dst" || die "repack 失败"
}

case "$MODE" in
	list)
		echo "配方: $RECIPE"
		echo "在盘判据: $KEPT"
		echo "产出目录: $OUTDIR"
		printf '会产出: %s' "$PREAMBLE"
		for s in $STAGES; do printf ' + %s' "$(piece_name "$s")"; done
		echo
		echo "档位语义: 5/7 = BootLinux 内停机点（mode 3 也崩）; 26..34 = CmdBoot 窗口二分; 27 = GUARD 之后（崩）"
		[ -f "$KEPT" ] && { echo "--- 在盘指纹 ---"; cat "$KEPT"; }
		;;
	verify|mkimg)
		WORK=$(mktemp -d /tmp/p7-ladder.XXXXXX) || die "mktemp 失败"
		trap 'rm -rf "$WORK"' EXIT
		bd=${BUILD_DIR:-}
		if [ -z "$bd" ]; then
			if [ "$REBUILD" = 1 ]; then
				build_variant "${BUILD_ARCHIVE:-$WORK/build}"
				bd=$BUILT_DIR
				note "⚠ --rebuild：FD 与归档件不同是预期（PITFALLS #510），下面的 sha 比对将失败，属正常"
			else
				bd=$DEFAULT_BUILD_DIR
				note "用归档 R7 构建目录 $bd（默认；逐字节可复现）"
			fi
		fi
		[ -d "$bd" ] || die "变体目录不存在: $bd"
		repack_preamble "$bd" "$WORK/$PREAMBLE"
		for s in $STAGES; do
			python3 "$ROOT/scripts/uefi-sbstop-patch.py" "$WORK/$PREAMBLE" "$s" \
				"$WORK/$(piece_name "$s")" --probe "$PROBE" >/dev/null \
				|| die "patch stage=$s 失败"
		done
		rc=0
		if [ -f "$KEPT" ]; then
			note "与在盘件比对（$KEPT）"
			while read -r want name; do
				[ -n "${want:-}" ] || continue
				p=${name#*/}
				got=$(sha256sum "$WORK/$p" 2>/dev/null | cut -d' ' -f1)
				if [ -z "$got" ]; then
					# 在盘指纹里的件本脚本未产出（不在 STAGES 里）⇒ 不算错，只提示
					note "SKIP $p（不在本次 STAGES）"
				elif [ "$got" = "$want" ]; then
					echo "  [ok]   $p  $got"
				else
					echo "  [FAIL] $p  期望 $want  实测 $got" >&2
					rc=1
				fi
			done < "$KEPT"
		else
			note "无在盘指纹文件（$KEPT），只列产物 sha："
			sha256sum "$WORK"/"$PREAMBLE" "$WORK"/$PFX-*.img 2>/dev/null
		fi
		if [ "$MODE" = mkimg ]; then
			mkdir -p "$OUTDIR"
			cp -f "$WORK"/"$PREAMBLE" "$WORK"/$PFX-*.img "$OUTDIR"/ || die "拷贝到 $OUTDIR 失败"
			note "已写入 $OUTDIR"
			sha256sum "$OUTDIR"/"$PREAMBLE" "$OUTDIR"/$PFX-*.img | sed 's|.*/|  |'
		fi
		[ "$rc" = 0 ] && { [ -f "$KEPT" ] && note "PASS（镜像段可逐字节复现，与 $KEPT 逐件相同）" || note "PASS（未提供指纹，仅产出；可比对请给 KEPT=…）"; } || note "FAIL（见上）"
		exit "$rc"
		;;
esac
