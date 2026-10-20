#!/bin/bash
# kbuild-sanity.sh — 内核构建前后 mandatory 健康门（本机专用）。
#
# ★ 为什么需要（2026-10-20 定性）：
#   本机（PRIME Z790-P D4 / i7-14700KF / **无 ECC**）存在**内存侧位翻转**：
#   磁盘上的文件字节正确，但**内核页缓存里的副本**会被翻转。
#   实测证据：同一文件 `dd iflag=direct`（绕页缓存）读到官方 md5，
#   普通读读到另一个 md5，`posix_fadvise(DONTNEED)` 丢缓存后重读立刻恢复正确。
#   危害：编译器（cc1）、链接器读文件时拿到错字节 ⇒ 随机 ICE / 段错误 /
#   `bad reloc symbol index`；构建出的镜像也可能含翻转位而 sha 与预期不符。
#
# 判据（三级）：
#   1. 树完整性：git index 逐文件 sha1（`verify-tree-integrity.py`，能区分
#      「页缓存污染 (CACHE)」与「磁盘真坏 (CORRUPT)」——CACHE 不算失败）
#   2. 页缓存污染率：`detect-memory-corruption.py --tree` 三读法抽查（默认全树）
#   3. 工具链：`dpkg -V` 关键包 + 编译一个 hello 并校验产物可执行
#
# 用法：
#   scripts/kbuild-sanity.sh [内核树] [--before|--after] [--rounds N] [--allow-dirty]
#   退出码 0 = 可继续构建；非 0 = 停止（先处理内存/环境）
#
# 为什么 --rounds：单发阴性不算通过（位翻转是随机的）。默认前后各 2 轮，
#   任一轮报 MEMORY 即判失败并打印命中文件。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
KDIR=${ROOT}/build/m1-73
PHASE=check
ROUNDS=2
EXTRA=()
while [ $# -gt 0 ]; do
	case "$1" in
		--before) PHASE=before ;;
		--after) PHASE=after ;;
		--rounds) ROUNDS=$2; shift ;;
		--allow-dirty) EXTRA+=(--allow-dirty) ;;
		-*) echo "未知选项 $1" >&2; exit 64 ;;
		*) KDIR=$1 ;;
	esac
	shift
done

RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; RST=$'\e[0m'
ok() { echo "${GRN}[ok]${RST}   $*"; }
bad() { echo "${RED}[FAIL]${RST} $*"; }
warn() { echo "${YEL}[warn]${RST} $*"; }
fail_all=0

echo "== kbuild-sanity ($PHASE) tree=$KDIR rounds=$ROUNDS $(date -Is) =="

# ---- 1. 树完整性（磁盘真值）----
if [ -d "$KDIR/.git" ] || [ -f "$KDIR/.git" ]; then
	if out=$(python3 "$ROOT/scripts/verify-tree-integrity.py" "$KDIR" "${EXTRA[@]}" -q 2>&1); then
		ok "树完整性（磁盘真值）: ${out##*: }"
	else
		bad "树完整性（磁盘真值）有真损坏: ${out}"
		echo "$out" | sed 's/^/      /'
		fail_all=1
	fi
else
	warn "不是 git 树，跳过 index 校验"
fi

# ---- 2. 页缓存污染率（多轮，任一轮命中即失败）----
hit_total=0
for i in $(seq 1 "$ROUNDS"); do
	line=$(python3 "$ROOT/scripts/detect-memory-corruption.py" --tree "$KDIR" --quiet "${EXTRA[@]}" 2>&1 | head -1)
	n=$(echo "$line" | sed 's/.*page_cache_corrupt=\([0-9]*\).*/\1/')
	d=$(echo "$line" | sed 's/.*disk_suspect=\([0-9]*\).*/\1/')
	hit_total=$((hit_total + n))
	if [ "${d:-0}" -gt 0 ]; then
		bad "第 $i 轮：disk_suspect=$d（绕过页缓存仍错 ⇒ 磁盘真坏）"
		fail_all=1
	elif [ "${n:-0}" -gt 0 ]; then
		warn "第 $i 轮：页缓存污染 $n 个文件（磁盘真值仍正确，已被丢弃重读修正）"
	fi
done
if [ "$hit_total" -gt 0 ]; then
	bad "页缓存污染累计 $hit_total 处 ⇒ **内存位翻转已在工作**，本次构建不可信"
	fail_all=1
else
	ok "页缓存污染：$ROUNDS 轮全零"
fi

# ---- 3. 工具链 ----
if dpkg -V cpp-15-aarch64-linux-gnu binutils-aarch64-linux-gnu >/dev/null 2>&1; then
	ok "交叉工具链 dpkg 校验通过"
else
	# dpkg -V 也会读到翻位页缓存；这里只报警不判死（第 2 项才是权威）
	warn "dpkg -V 报差异（可能是页缓存翻位，复跑一次看是否消失）"
	dpkg -V cpp-15-aarch64-linux-gnu binutils-aarch64-linux-gnu 2>&1 | sed 's/^/      /' | head -5
fi
TMPD=$(mktemp -d)
if printf 'int main(void){return 0;}\n' > "$TMPD/h.c" \
	&& aarch64-linux-gnu-gcc -O2 "$TMPD/h.c" -o "$TMPD/h" 2>"$TMPD/err" \
	&& file "$TMPD/h" | grep -q 'ARM aarch64'; then
	ok "交叉编译探针（-O2 → aarch64 ELF）通过"
else
	bad "交叉编译探针失败: $(head -3 "$TMPD/err" 2>/dev/null)"
	fail_all=1
fi
rm -rf "$TMPD"

echo
if [ "$fail_all" -ne 0 ]; then
	echo "${RED}⇒ 环境不可信，停止构建。${RST}"
	echo "   若反复出现：这是**内存/硬件**问题（本机无 ECC，EDAC 不可用）。"
	echo "   处置顺序：① BIOS 关 XMP/EXPO、降内存频率到 JEDEC、放宽时序；② 单条内存排查；"
	echo "   ③ 跑 memtest86+；④ 长期方案 = 换 ECC 平台或换机器。"
	echo "   不要用「重写文件」当修复：重写同样经过内存，且会覆盖掉本来正确的磁盘副本。"
	exit 1
fi
echo "${GRN}⇒ 环境检查通过（$PHASE）${RST}"
exit 0
