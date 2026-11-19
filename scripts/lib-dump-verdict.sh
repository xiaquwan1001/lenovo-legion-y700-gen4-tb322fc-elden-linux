#!/bin/sh
# lib-dump-verdict.sh — EDL/`dd` dump 的**三值判定**（present / absent / error）单一真源。
#
# 来源：2026-11-18 LTBox 评估 §1 P0-6（`dump_presence()` 只把 `PartitionNotFound` 当
# 「分区不存在」，其它一切 = 错误）。本文件只是 `scripts/dump-verdict.py` 的 POSIX sh 包装，
# 判据与自检全在 python 侧（`python3 scripts/dump-verdict.py --selftest`）。
#
# 用法（source 之后）：
#   . "$(dirname "$0")/lib-dump-verdict.sh"
#   dump_verdict boot_b "$rc" /tmp/read.log /tmp/b.bin 4194304 ; v=$?
#   # $? = 0 present / 10 absent / 1 error（其它非预期 = 工具自身故障，同样按 error 处理）
#
# 纪律：**只有 10 才允许走「这个分区没有」的分支**；1 必须中止或上报。
# 反向用法（禁止）：`cmd || true` 之后按「文件空/大小不对」推断分区不存在 —— 见 PITFALLS #669。
#
# 参数：
#   dump_verdict <part> <rc> <log> [<file>] [<expect-bytes>] [<expect-bytes-oneof>]
#     全部给满最严：file 存在且非空、长度精确（或命中 oneof 集合）。
#     expect-bytes 传空字符串表示不核对；oneof 形如 "17408,139264"（qdl 自探 512/4096 时用）。

: "${DUMP_VERDICT_PY:=$(cd "$(dirname "$0")" 2>/dev/null && pwd)/dump-verdict.py}"

dump_verdict() {
	_dv_part=$1; _dv_rc=$2; _dv_log=$3
	_dv_file=${4:-}; _dv_expect=${5:-}; _dv_oneof=${6:-}
	set -- --part "$_dv_part" --rc "$_dv_rc" --log "$_dv_log"
	[ -n "$_dv_file" ] && set -- "$@" --file "$_dv_file"
	[ -n "$_dv_expect" ] && set -- "$@" --expect-bytes "$_dv_expect"
	[ -n "$_dv_oneof" ] && set -- "$@" --expect-bytes-oneof "$_dv_oneof"
	if [ ! -f "$DUMP_VERDICT_PY" ]; then
		echo "VERDICT error part=$_dv_part reason=缺 dump-verdict.py（$DUMP_VERDICT_PY）"
		return 1
	fi
	timeout -k 5 30 python3 "$DUMP_VERDICT_PY" "$@"
}
