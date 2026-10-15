#!/bin/bash
# trial.sh — 统一的「一次设备实验」闸门与记录（无 record 不得写 verdict）。
#
# 解决的既有事故（PITFALLS #150–#168 一类）：
#   - 设备健康前置门缺位 → boot_b `succ=0` 静默进入倒计时（#152）
#   - 复位类型不声明 → 暖复位粘 NOCARD 污染 A/B（#166）
#   - 结论不落盘 → 样本无原始证据、事后不可复核（DOSSIER §g-3）
#
# 子命令：
#   gate                          设备健康门（只读）：读 boot_b succ/retry/unbootable
#                                 退码 0=OK，3=WARN，1=FAIL；--fix 则先 mark-successful b
#   record --label L --image IMG --reset por|cold|warm --verdict V
#          [--deploy D] [--probe P] [--logdir DIR] [--note ...]
#                                 写一条机器可读 record（JSON + index.tsv），不碰设备
#   run --label L --image IMG --reset T [--deploy none|fastboot-boot] [--probe q28|raw]
#          [--note ...] [--force]
#                                 门 → 部署 → 探针 → 落 record（完整编排）
#   selftest                      离线自测（不碰设备）
#
# 约定：reset 必须显式声明；verdict 只允许在 record 里出现。
# Env: TAB(root@192.168.7.1) OUT(=<repo>/out) TRIALS_DIR(=<repo>/reports/trials)
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
OUT=${OUT:-$ROOT/out}
TAB=${TAB:-root@192.168.7.1}
TDIR=${TRIALS_DIR:-$ROOT/reports/trials}
INDEX=$TDIR/index.tsv
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"
S() { timeout "${2:-25}" $SSH "$1" 2>/dev/null; }
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

usage() { sed -n '2,26p' "$0"; }

require_reset() {
	case "${1:-}" in
		por|cold|warm) return 0 ;;
		*) echo "[trial] ❌ --reset 必须是 por|cold|warm（暖复位样本对复位敏感问题无效，见 PITFALLS #166）" >&2; exit 2 ;;
	esac
}

# 从 manifest 取字段（值里可能含 '='，用 sub 剥掉键）
mfval() { awk -F= -v k="$1" '$1==k{sub(/^[^=]*=/,""); print; exit}' "$2" 2>/dev/null; }

# 设备健康门；回显一行 GATE=...，退码 0/3/1
device_gate() {
	local fix=${1:-0}
	local reach
	reach=$(S 'echo up' 12)
	if [ "$reach" != "up" ]; then
		echo "[trial] GATE=FAIL 设备不可达（$TAB）——先起 SSH 通道（elden-net.sh）" >&2
		return 1
	fi
	if [ "$fix" = 1 ]; then
		echo "[trial] --fix：mark-successful b（写槽属性）"
		S 'python3 /usr/local/sbin/slot-attr.py mark-successful b' 40 || true
	fi
	local show
	show=$(S 'python3 /usr/local/sbin/slot-attr.py show' 25)
	local line succ retry unboot
	line=$(printf '%s\n' "$show" | grep -E 'boot_b ' | head -1)
	succ=$(printf '%s' "$line" | grep -oE 'succ=[0-9]+' | head -1 | cut -d= -f2)
	retry=$(printf '%s' "$line" | grep -oE 'retry=[0-9]+' | head -1 | cut -d= -f2)
	unboot=$(printf '%s' "$line" | grep -oE 'unbootable=[0-9]+' | head -1 | cut -d= -f2)
	if [ -z "$retry" ]; then
		echo "[trial] GATE=WARN 读不到 boot_b 槽属性（slot-attr.py 缺失？）line='$line'" >&2
		return 3
	fi
	echo "[trial] boot_b: succ=${succ:-?} retry=${retry} unbootable=${unboot:-?}"
	if [ "${unboot:-0}" = 1 ]; then
		echo "[trial] GATE=FAIL boot_b 已 UNBOOTABLE——先用 fastboot boot 救援并 mark-successful b" >&2
		return 1
	fi
	if [ "${succ:-0}" = 1 ]; then
		echo "[trial] GATE=OK"
		return 0
	fi
	if [ "${retry:-0}" -ge 3 ]; then
		echo "[trial] GATE=WARN succ=0（每次真开机倒计时）→ 建议先 `trial.sh gate --fix`" >&2
		return 3
	fi
	echo "[trial] GATE=FAIL succ=0 且 retry=${retry}<3——再几次真开机将置 UNBOOTABLE；停止循环、先救援" >&2
	return 1
}

write_record() {
	# 由 env 传字段：LABEL IMAGE RESET DEPLOY PROBE VERDICT LOGDIR NOTE
	mkdir -p "$TDIR"
	# manifest 命名 = 镜像 basename 去 .img（不依赖 vk 号：m1-baseline-f3 / armA-nobonded
	# 等描述性镜像名同样有 manifest，旧的 "$(_vk …)" 推导会得到空名 ⇒ 身份字段全丢）
	local mf="${IMAGE%.img}.manifest"
	local img_sha kernel_uts kernel_payload config_sha dtb_sha
	img_sha=$([ -e "$IMAGE" ] && sha256sum "$IMAGE" | cut -d' ' -f1 || echo "(absent)")
	if [ -f "$mf" ]; then
		kernel_uts=$(mfval kernel_uts "$mf")
		kernel_payload=$(mfval kernel_payload_sha256 "$mf")
		config_sha=$(mfval config_sha256 "$mf")
		dtb_sha=$(mfval dtb_packed_sha256 "$mf")
	else
		mf=""; kernel_uts=""; kernel_payload=""; config_sha=""; dtb_sha=""
	fi
	local stamp json rec
	stamp=$(date -u +%Y%m%dT%H%M%SZ)
	rec="$TDIR/${stamp}-${LABEL}.json"
	json=$(LABEL="$LABEL" TS="$(ts)" VK="$(_vk "$IMAGE")" IMAGE="$IMAGE" IMG_SHA="$img_sha" \
		MANIFEST="$mf" UTS="$kernel_uts" KPAYLOAD="$kernel_payload" CONFIG_SHA="$config_sha" \
		DTB_SHA="$dtb_sha" RESET="$RESET" DEPLOY="$DEPLOY" PROBE="$PROBE" VERDICT="$VERDICT" \
		LOGDIR="$LOGDIR" NOTE="$NOTE" python3 - <<'PY'
import json, os
k = {k.lower(): v for k, v in os.environ.items()}
print(json.dumps({
    "label": k["label"], "ts": k["ts"], "vk": k["vk"],
    "image": k["image"], "image_sha256": k["img_sha"], "manifest": k["manifest"],
    "kernel_uts": k["uts"], "kernel_payload_sha256": k["kpayload"],
    "config_sha256": k["config_sha"], "dtb_packed_sha256": k["dtb_sha"],
    "reset_type": k["reset"], "deploy": k["deploy"], "probe": k["probe"],
    "verdict": k["verdict"], "log_dir": k["logdir"], "note": k["note"],
}, ensure_ascii=False, indent=2))
PY
)
	printf '%s\n' "$json" > "$rec"
	[ -s "$rec" ] || { echo "[trial] ❌ record 写入失败：$rec" >&2; return 1; }
	# index 追加（时间倒序阅读用 tail；TSV 便于 rg/awk）
	[ -s "$INDEX" ] || printf 'ts\tlabel\tvk\treset\tdeploy\tverdict\timage_sha\tlog_dir\n' > "$INDEX"
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$(ts)" "$LABEL" "$(_vk "$IMAGE")" "$RESET" "$DEPLOY" "$VERDICT" "${img_sha:0:12}" "$LOGDIR" >> "$INDEX"
	echo "[trial] RECORD=$rec"
	echo "[trial] VERDICT=$VERDICT  reset=$RESET vk=$(_vk "$IMAGE")"
}

_vk() { basename "${1:-}" .img | grep -oE 'vk[0-9]+[A-Za-z0-9._-]*' | head -1; }

# ---------------------------------------------------------------- subcommands
cmd=${1:-}; shift || true
case "$cmd" in
	gate)
		fix=0
		while [ $# -gt 0 ]; do case "$1" in --fix) fix=1 ;; esac; shift; done
		device_gate "$fix"; exit $? ;;

	record)
		LABEL=""; IMAGE=""; RESET=""; VERDICT=""; DEPLOY="none"; PROBE="none"; LOGDIR=""; NOTE=""
		while [ $# -gt 0 ]; do
			case "$1" in
				--label) LABEL=$2; shift ;;
				--image) IMAGE=$2; shift ;;
				--reset) RESET=$2; shift ;;
				--verdict) VERDICT=$2; shift ;;
				--deploy) DEPLOY=$2; shift ;;
				--probe) PROBE=$2; shift ;;
				--logdir) LOGDIR=$2; shift ;;
				--note) NOTE=$2; shift ;;
			esac
			shift
		done
		[ -n "$LABEL" ] || { echo "[trial] ❌ record 需要 --label" >&2; exit 2; }
		[ -n "$VERDICT" ] || { echo "[trial] ❌ record 需要 --verdict" >&2; exit 2; }
		require_reset "$RESET"
		write_record ;;

	run)
		LABEL=""; IMAGE=""; RESET=""; DEPLOY="none"; PROBE="none"; NOTE=""; FORCE=0
		while [ $# -gt 0 ]; do
			case "$1" in
				--label) LABEL=$2; shift ;;
				--image) IMAGE=$2; shift ;;
				--reset) RESET=$2; shift ;;
				--deploy) DEPLOY=$2; shift ;;
				--probe) PROBE=$2; shift ;;
				--note) NOTE=$2; shift ;;
				--force) FORCE=1 ;;
			esac
			shift
		done
		[ -n "$LABEL" ] && [ -n "$IMAGE" ] || { echo "[trial] ❌ run 需要 --label 与 --image" >&2; exit 2; }
		require_reset "$RESET"
		. "$ROOT/scripts/lib-device-lock.sh"; device_lock_acquire

		device_gate 0; gate_rc=$?
		if [ "$gate_rc" = 1 ] && [ "$FORCE" != 1 ]; then
			echo "[trial] gate FAIL —— 中止（--force 可越权，但请先处理槽位）" >&2; exit 1
		fi

		case "$DEPLOY" in
			none) : ;;
			fastboot-boot)
				fastboot devices 2>/dev/null | grep -q . || {
					echo "[trial] ❌ 不在 fastboot。冷起需物理 POR + 按键进 fastboot（用户动作）。" >&2
					echo "        若只是想在已启动设备上取证，用 --deploy none。" >&2; exit 1; }
				echo "[trial] fastboot boot $IMAGE"
				timeout 180 fastboot boot "$IMAGE" 2>&1 | tail -3 || true
				;;
			*) echo "[trial] ❌ 未知 --deploy $DEPLOY" >&2; exit 2 ;;
		esac

		# 等 SSH 回来（部署后）
		ok=0; for _ in $(seq 1 30); do [ "$(S 'echo up' 6)" = up ] && { ok=1; break; }; sleep 5; done
		if [ "$ok" != 1 ]; then
			VERDICT="NOROUTE"; LOGDIR="$TDIR/$(date -u +%Y%m%dT%H%M%SZ)-$LABEL"; mkdir -p "$LOGDIR"
			echo "[trial] 设备未起 SSH（150s）" > "$LOGDIR/README.txt"
			write_record; exit 1
		fi

		LOGDIR="$TDIR/$(date -u +%Y%m%dT%H%M%SZ)-$LABEL"; mkdir -p "$LOGDIR"
		S 'uname -a; cat /proc/uptime; cat /proc/cmdline' >"$LOGDIR/env.txt" 2>&1
		S 'dmesg' >"$LOGDIR/dmesg.txt" 2>&1
		VERDICT="RAW"
		case "$PROBE" in
			q28)
				$SSH 'sh -s' < "$ROOT/scripts/q28-devprobe.sh" >"$LOGDIR/probe.txt" 2>&1 || true
				VERDICT=$(grep -oE 'VERDICT=[A-Z]+' "$LOGDIR/probe.txt" | head -1 | cut -d= -f2)
				[ -n "$VERDICT" ] || VERDICT="UNKNOWN"
				;;
			none) : ;;
			*) echo "[trial] 未知 --probe $PROBE（按 raw 记录）" >&2 ;;
		esac
		write_record ;;

	selftest)
		tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
		if ! TRIALS_DIR=$tmp bash "$0" record --label selftest --image "$OUT/boot-elden-vk64.img" \
			--reset por --verdict GOOD --note selftest >/dev/null; then
			echo "selftest FAIL: record 失败"; exit 1
		fi
		f1=$(ls "$tmp"/*.json 2>/dev/null | head -1)
		[ -n "$f1" ] || { echo "selftest FAIL: 无 JSON"; exit 1; }
		python3 -c "import json; d=json.load(open('$f1')); assert d['reset_type']=='por' and d['verdict']=='GOOD', d; print('selftest OK json:', d['label'], d['vk'])" || exit 1
		[ -s "$tmp/index.tsv" ] && echo "selftest OK index: $(wc -l < "$tmp/index.tsv") 行" || { echo "selftest FAIL index"; exit 1; }
		if TRIALS_DIR=$tmp bash "$0" record --label x --image i --reset bogus --verdict GOOD >/dev/null 2>&1; then
			echo "selftest FAIL: 非法 reset 未被拒"; exit 1
		fi
		echo "selftest PASS" ;;

	*)
		usage; exit 2 ;;
esac
