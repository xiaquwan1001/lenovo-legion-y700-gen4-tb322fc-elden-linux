#!/bin/bash
# host-mem-build-stress.sh — 用真实内核构建压测宿主内存（无 ECC 机器专用）
#
# 背景：本机（PRIME Z790-P D4 / i7-14700KF / 61 GiB DDR4 无 ECC）2026-10-20 定性为
#   **内存侧位翻转**（页缓存副本被改写，磁盘真值正确）。判据与工具见
#   `reports/host-memory-bitflip-rootcause-20261020.md`、`scripts/kbuild-sanity.sh`。
#
# 本脚本 = 把「待测且未编译的树」变成内存测试负载：
#   ① 前置体检门（kbuild-sanity.sh --before）
#   ② 并行跑 stressapptest（持续写+校验，暴露 DRAM 单元错误）
#   ③ 并行跑页缓存污染探针（每 120 s 一轮三读法，暴露内核页缓存翻转）
#   ④ 真实构建（默认 arm64 `Image dtbs`，最重的通用负载之一）
#   ⑤ 构建日志里统计 ICE/段错误/Object 损坏/链接器错误
#   ⑥ 后置体检门（kbuild-sanity.sh --after）
#
# 用法：
#   scripts/host-mem-build-stress.sh [选项]
#     --tree DIR        内核树（默认 build/m3v2-7.3rc7）
#     --target "... "   make 目标（默认 "Image dtbs"）
#     --jobs N          make -j（默认 nproc）
#     --stress-mb N     stressapptest 占用 MB（默认 20000；0=不跑）
#     --stress-threads N  stressapptest 线程（默认 12）
#     --rounds N        体检门轮数（默认 2）
#     --timeout SEC     每轮构建硬超时（默认 3600，脚本内 timeout -k）
#     --repeats N       构建轮数（默认 1；>1 时自动开启产物 sha256 比对）
#     --clean-between   每轮之间 make clean（强制全量重编，测得更满）
#     --no-digest       关闭产物 sha256 比对
#     --no-gate         跳过前后体检门（仅冒烟用）
#     --label STR       日志目录名后缀
#
# 退出码：0 = 构建成功且前后门通过；1 = 体检门失败/构建失败；
#         2 = 构建成功但检出 ICE/段错误等内存嫌疑；3 = 超时。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TREE=${ROOT}/build/m3v2-7.3rc7
TARGET="Image dtbs"
JOBS=$(nproc)
STRESS_MB=20000
STRESS_THREADS=12
ROUNDS=2
TIMEOUT=3600
REPEATS=1
CLEAN_BETWEEN=0
DIGEST=1
GATE=1
LABEL=""
PROBE_EVERY=120
CROSS=aarch64-linux-gnu-

while [ $# -gt 0 ]; do
	case "$1" in
		--tree) TREE=$2; shift ;;
		--target) TARGET=$2; shift ;;
		--jobs) JOBS=$2; shift ;;
		--stress-mb) STRESS_MB=$2; shift ;;
		--stress-threads) STRESS_THREADS=$2; shift ;;
		--rounds) ROUNDS=$2; shift ;;
		--timeout) TIMEOUT=$2; shift ;;
		--repeats) REPEATS=$2; DIGEST=1; shift ;;
		--clean-between) CLEAN_BETWEEN=1 ;;
		--no-digest) DIGEST=0 ;;
		--no-gate) GATE=0 ;;
		--label) LABEL=$2; shift ;;
		-h|--help) sed -n '2,32p' "$0"; exit 0 ;;
		*) echo "未知选项 $1" >&2; exit 64 ;;
	esac
	shift
done

TREE=$(cd "$TREE" && pwd) || { echo "树不存在: $TREE" >&2; exit 64; }
TS=$(date +%Y%m%d-%H%M%S)
LOG=${ROOT}/logs/memstress-${TS}${LABEL:+-$LABEL}
mkdir -p "$LOG"
RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; RST=$'\e[0m'
say() { printf '%s [%s] %s\n' "$(date +%H:%M:%S)" "$1" "$2" | tee -a "$LOG/run.log"; }

say info "tree=$TREE target='$TARGET' jobs=$JOBS stress=${STRESS_MB}MB/${STRESS_THREADS}t timeout=${TIMEOUT}s log=$LOG"
say info "uname=$(uname -r) uptime=$(uptime -p) mem=$(LC_ALL=C free -m | awk '/^Mem:/{print int($2/1024)"G total "int($7/1024)"G avail"}')"

# ---- ① 前置门 ----
if [ "$GATE" = 1 ]; then
	say gate "before"
	"$ROOT/scripts/kbuild-sanity.sh" "$TREE" --before --rounds "$ROUNDS" --allow-dirty 2>&1 | tee "$LOG/gate-before.log"
	if [ "${PIPESTATUS[0]}" -ne 0 ]; then
		say FAIL "前置体检门未通过 ⇒ 环境不可信，未开始构建（详见 $LOG/gate-before.log）"
		exit 1
	fi
fi

pids=()

# ---- ② stressapptest ----
if [ "$STRESS_MB" -gt 0 ]; then
	SAT_SECS=$((TIMEOUT * REPEATS + 120))
	say info "stressapptest -M $STRESS_MB -m $STRESS_THREADS -s $SAT_SECS"
	stressapptest -M "$STRESS_MB" -m "$STRESS_THREADS" -s "$SAT_SECS" -l "$LOG/stressapptest.log" \
		>>"$LOG/stressapptest.out" 2>&1 &
	pids+=($!)
fi

# ---- ③ 页缓存污染探针 ----
(
	round=0
	while :; do
		sleep "$PROBE_EVERY"
		round=$((round + 1))
		line=$(python3 "$ROOT/scripts/detect-memory-corruption.py" --tree "$TREE" --quiet --allow-dirty 2>&1 | head -1)
		echo "$(date +%H:%M:%S) round=$round $line" >>"$LOG/cache-probe.log"
	done
) &
PROBE_PID=$!
pids+=("$PROBE_PID")

# ---- ④ 构建 ----
say build "make -j$JOBS ARCH=arm64 CROSS_COMPILE=$CROSS $TARGET ×${REPEATS}$([ "$CLEAN_BETWEEN" = 1 ] && echo ' (clean between)')"
rc=0
dur=0
for r in $(seq 1 "$REPEATS"); do
	if [ "$CLEAN_BETWEEN" = 1 ]; then
		( cd "$TREE" && make -s clean ) >>"$LOG/build-$r.log" 2>&1
	fi
	say build "round $r/$REPEATS 开始"
	t0=$(date +%s)
	( cd "$TREE" && exec timeout -k 60 "$TIMEOUT" make -j"$JOBS" ARCH=arm64 CROSS_COMPILE="$CROSS" $TARGET ) \
		>"$LOG/build-$r.log" 2>&1
	rrc=$?
	t1=$(date +%s)
	rdur=$((t1 - t0))
	dur=$((dur + rdur))
	say build "round $r make rc=$rrc 墙钟=${rdur}s"
	if [ "$rrc" -ne 0 ] && [ "$rc" -eq 0 ]; then rc=$rrc; fi
	if [ "$DIGEST" = 1 ]; then
		# 已知非确定性对象不参与比对：version-timestamp.o / utsversion.o / compile.h（构建时间）、
		# usr/initramfs_data.o（嵌入 cpio 含 mtime）、vmlinux.o（链接了上述对象）
		( cd "$TREE" && find . \( -name '*.o' -o -name '*.a' -o -name '*.dtb' \) -type f -print0 \
			| sort -z | xargs -0 -r sha256sum | awk '!/version-timestamp\.o/ && !/utsversion\.o/ && !/compile\.h/ && !/\/usr\/initramfs_data\.o/ && !/vmlinux\.o/' | LC_ALL=C sort ) \
			>"$LOG/digest-$r.sha"
		say build "round $r digest: $(wc -l <"$LOG/digest-$r.sha") 个产物"
	fi
done

# ---- 收尾后台任务（按 PID，不按 -f 模式，避免误杀自身）----
for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done
sleep 1
for p in "${pids[@]}"; do kill -9 "$p" 2>/dev/null; done
wait 2>/dev/null

# ---- ⑤ 日志里的内存嫌疑信号 ----
: >"$LOG/suspect-signals.txt"
for f in "$LOG"/build-*.log; do
	[ -f "$f" ] || continue
	grep -niE "internal compiler error|Segmentation fault|Killed signal|signal 11|signal 6|Bus error|bad reloc symbol index|member .* not an object|Error [12]$" \
		"$f" | sed "s|^|$(basename "$f"):|" >>"$LOG/suspect-signals.txt" 2>/dev/null
	grep -niE "corrupt|invalid literal|checksum mismatch" "$f" | sed "s|^|$(basename "$f"):|" >>"$LOG/suspect-signals.txt" 2>/dev/null
done
n_sig=$(wc -l <"$LOG/suspect-signals.txt")
say scan "构建日志嫌疑信号：$n_sig 行"

# ---- ⑤b 产物可重现性：多轮 sha256 逐对象比对 ----
digest_bad=0
digest_diff_files=""
if [ "$DIGEST" = 1 ] && [ "$REPEATS" -gt 1 ]; then
	for r in $(seq 2 "$REPEATS"); do
		d=$(comm -3 "$LOG/digest-1.sha" "$LOG/digest-$r.sha" | wc -l)
		if [ "$d" -gt 0 ]; then
			digest_bad=$((digest_bad + d))
			digest_diff_files+=" round$r:$d"
			comm -3 "$LOG/digest-1.sha" "$LOG/digest-$r.sha" >"$LOG/digest-diff-1-vs-$r.txt"
		fi
	done
	if [ "$digest_bad" -eq 0 ]; then
		say scan "产物可重现性：$REPEATS 轮 $(wc -l <"$LOG/digest-1.sha") 个对象 sha256 全一致"
	else
		say scan "产物可重现性：差异行 $digest_bad（$digest_diff_files）⇒ 有对象字节不同/缺失"
	fi
fi

# stressapptest 数据比对失败 = DRAM 单元错（最强证据）
sat_bad=0
if [ -f "$LOG/stressapptest.out" ]; then
	# 只看真错：MISCOMPARE 行 + "with N hardware incidents, M errors" 里 N/M > 0
	sat_bad=$(grep -c "MISCOMPARE" "$LOG/stressapptest.out" || true)
	inc=$(awk '{for(i=1;i<=NF;i++){
		if($i=="hardware" && $(i+1) ~ /^incidents,?$/) s+=$(i-1)+0
		if($i ~ /^errors,?$/) s+=$(i-1)+0}} END{print s+0}' "$LOG/stressapptest.out")
	sat_bad=$((sat_bad + ${inc:-0}))
	say scan "stressapptest 硬件事件+错误：$sat_bad（$([ -f "$LOG/stressapptest.log" ] && grep -c Stats "$LOG/stressapptest.log") 行统计）"
fi

# 页缓存探针命中
probe_hits=0
if [ -f "$LOG/cache-probe.log" ]; then
	probe_hits=$(awk '{for(i=1;i<=NF;i++) if($i ~ /^page_cache_corrupt=/){split($i,a,"="); s+=a[2]}} END{print s+0}' "$LOG/cache-probe.log")
	say scan "页缓存污染累计：$probe_hits 处（$(( $(wc -l <"$LOG/cache-probe.log") )) 轮）"
fi

# 内核侧异常（本进程树的段错误 / oops / MCE）
journalctl -k --since "-$((dur + 300))s" --no-pager 2>/dev/null \
	| grep -iE "general protection fault|BUG: |Oops|mce|Machine check|segfault" >>"$LOG/kernel-suspect.txt" 2>/dev/null

# ---- ⑥ 后置门 ----
gate_rc=0
if [ "$GATE" = 1 ]; then
	say gate "after"
	"$ROOT/scripts/kbuild-sanity.sh" "$TREE" --after --rounds "$ROUNDS" --allow-dirty 2>&1 | tee "$LOG/gate-after.log"
	gate_rc=${PIPESTATUS[0]}
fi

# ---- 汇总 ----
{
	echo "tree=$TREE"
	echo "target=$TARGET jobs=$JOBS stress_mb=$STRESS_MB"
	echo "make_rc=$rc wall_seconds=$dur"
	echo "suspect_signals=$n_sig"
	echo "digest_mismatch_lines=$digest_bad"
	echo "stressapptest_errors=$sat_bad"
	echo "page_cache_corrupt=$probe_hits"
	echo "gate_after_rc=$gate_rc"
} >"$LOG/summary.txt"

echo
say RESULT "make_rc=$rc 墙钟=${dur}s 嫌疑信号=$n_sig 产物差异=$digest_bad stressapptest异常=$sat_bad 页缓存污染=$probe_hits 后置门rc=$gate_rc"
if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
	say FAIL "构建超时（timeout ${TIMEOUT}s）"; exit 3
fi
if [ "$n_sig" -gt 0 ] || [ "$sat_bad" -gt 0 ] || [ "$probe_hits" -gt 0 ] || [ "$digest_bad" -gt 0 ]; then
	say FAIL "检出内存/环境嫌疑 ⇒ 本次构建产物不可信。证据：$LOG"
	exit 2
fi
if [ "$rc" -ne 0 ] || [ "$gate_rc" -ne 0 ]; then
	say FAIL "构建或体检门失败（make=$rc gate=$gate_rc）"; exit 1
fi
say OK "构建成功，前后门通过，无内存嫌疑信号 ⇒ 该轮内存表现合格（单轮不等于终判）"
exit 0
