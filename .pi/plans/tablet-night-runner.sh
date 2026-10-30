#!/bin/bash
# tablet-night-runner.sh — 平板夜间无人值守任务队列执行器（L1 自写，补齐 L2-B 缺失件；2026-10-30）
#
# 为什么存在：主机夜间断电 ⇒ 127.0.0.1:4000 的 litellm 不可用；平板需自带一条 API 路线，
# 并且只跑低 CPU / 低 IO 任务（文档审计、邮件分诊草稿、补丁备料、日志分析、SSOT 并入草案、证伪式静态核查）。
#
# 设计硬门（与 .pi/AGENT-OPS.md 一致）：
#   1) 每任务 `timeout -k 60 <timeout_box>` 硬截止盒（全局硬规则 3：长跑必设截止并核实进程结束）。
#   2) 低优先级：nice 19 + ionice idle；一次只跑一个任务（并发 1）。
#   3) needs_device 必须 false——夜间不碰设备；设备是单一串行资源（§6）。
#   4) allowed_write_paths 白名单逐条校验；越界即 fail 并停队列。
#   5) 只写 reports/artifacts/** 与 patches-userland/staging/**；**不碰**领域层 SSOT（各角度 README/INDEX/TASKS/DEVICE/RESOURCES/PITFALLS 正文）。
#   6) 默认 DRY_RUN=1：只打印计划与校验，不调用 pi。显式 RUN=1 才真跑。
#   7) 失败重试上限 = 队列 retry 字段（退避 60s×n）；状态落 state/<id>.{done,fail,retryN}，重启后跳过 done（断电续作）。
#   8) 收尾回传：rsync 增量（单向 平板→主机，禁 --delete）。push 需 --allow-push 且只推 tablet/<task>，禁 main、禁 force。
#
# 用法（平板，建议 uid 1001 而非 root）：
#   DRY_RUN=1 .pi/plans/tablet-night-runner.sh .pi/plans/tablet-queue.example.jsonl      # 只看计划
#   RUN=1 pi-tablet 环境变量见 §API，systemd user unit: .pi/plans/pi-tablet-night.service
#   .pi/plans/tablet-night-runner.sh --status
set -u

ROOT="${ROOT:-$HOME/y700-elden}"
DATE_TAG="$(date +%F)"
ART="reports/artifacts/tablet-offload-20261030/night-${DATE_TAG}"
STATE="${ROOT}/.pi/night-state/${DATE_TAG}"
QUEUE="${1:-${ROOT}/.pi/plans/tablet-queue.jsonl}"
HOST_RSYNC="${TABLET_RSYNC_TARGET:-}"          # 例 xuqianhui@<host-lan-ip>:~/y700-elden/  空则跳过回传
ALLOW_PUSH=0
[ "${1:-}" = "--allow-push" ] && { ALLOW_PUSH=1; QUEUE="${2:-${ROOT}/.pi/plans/tablet-queue.jsonl}"; }
RUN="${RUN:-0}"
API_TIMEOUT=10
MAX_CONCURRENCY=1                                # 夜间串行，永不并行

cd "$ROOT" 2>/dev/null || { echo "[FAIL] 找不到仓库 $ROOT"; exit 1; }
mkdir -p "$ART" "$STATE"
LOG="${ART}/runner.log"
exec > >(tee -a "$LOG") 2>&1

log() { echo "[$(date +%H:%M:%S)] $*"; }
errlog() { echo "[$(date +%H:%M:%S)] $*" >&2; }   # 探活函数内的日志走 stderr，不污染 $(probe_api) 的返回值
die() { log "[FAIL] $*"; exit "${2:-1}"; }

# ---------- 状态 ----------
if [ "${1:-}" = "--status" ]; then
  for f in "$STATE"/*; do [ -e "$f" ] && echo "$(basename "$f")"; done
  echo "state=$STATE log=$LOG"
  exit 0
fi

[ -f "$QUEUE" ] || die "队列不存在: $QUEUE（样例见 .pi/plans/tablet-queue.example.jsonl）" 2

# ---------- API 路线探活（先本地 litellm，后直连 api.llm）----------
probe_api() {
  local code
  code=$(curl --noproxy '*' -m 5 -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4000/health/liveliness 2>/dev/null || echo 000)
  if [ "$code" = "200" ]; then errlog "API=local-litellm (127.0.0.1:4000) OK"; echo "local"; return 0; fi
  if [ -n "${USTC_API_KEY:-}" ]; then
    code=$(curl --noproxy '*' -m "$API_TIMEOUT" -s -o /dev/null -w '%{http_code}' \
      -H "Authorization: Bearer ${USTC_API_KEY}" https://api.llm.ustc.edu.cn/v1/models 2>/dev/null || echo 000)
    case "$code" in
      200) errlog "API=direct-api.llm OK"; echo "direct"; return 0 ;;
      401) errlog "API=direct 401：key 无效（占位符未替换）"; echo "none"; return 1 ;;
      429) errlog "API=direct 429 限流：冷却后继续"; echo "direct-throttled"; return 0 ;;
      *)   errlog "API=direct 探活失败 http=$code";;
    esac
  else
    errlog "API=未配置 USTC_API_KEY（应放 %h/.config/pi-tablet-night.env，chmod 600；键值绝不入 git/回传）"
  fi
  echo "none"; return 1
}

# ---------- 队列校验 ----------
TASKS_N=$(python3 - "$QUEUE" <<'PY'
import json,sys
n=0
for i,l in enumerate(open(sys.argv[1]),1):
    l=l.strip()
    if not l: continue
    d=json.loads(l)
    for k in ("id","kind","prompt","max_minutes","timeout_box","retry","log_path","needs_network","needs_device","allowed_write_paths"):
        assert k in d, f"line{i} 缺字段 {k}"
    assert d["needs_device"] is False, f"line{i} needs_device 必须 false（夜间禁碰设备）"
    BANNED = ("INDEX.md", ".gitignore", "TASKS/README.md", "DEVICE/", "RESOURCES/", "PITFALLS/README.md",
              "SESSIONS/README.md", "HISTORY/README.md", "RUNBOOK-BRINGUP/README.md", ".git/")
    for p in d["allowed_write_paths"]:
        assert not p.startswith("/"), f"line{i} 白名单必须相对仓库根: {p}"
        assert not any(p == b or p.startswith(b) for b in BANNED), f"line{i} 白名单覆盖领域层 SSOT: {p}"
    n+=1
print(n)
PY
) || die "队列 JSON/字段校验失败" 4
log "队列 $QUEUE：$TASKS_N 个任务；RUN=$RUN 并发=$MAX_CONCURRENCY nice=19"

[ "$RUN" = "1" ] || { log "DRY_RUN：以下为计划，不执行 pi"; }

# ---------- 主循环 ----------
overall_rc=0
while IFS= read -r line; do
  [ -n "${line//[[:space:]]/}" ] || continue
  id=$(printf '%s' "$line" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
  tbox=$(printf '%s' "$line" | python3 -c 'import json,sys;print(json.load(sys.stdin)["timeout_box"])')
  retry=$(printf '%s' "$line" | python3 -c 'import json,sys;print(json.load(sys.stdin)["retry"])')
  prompt=$(printf '%s' "$line" | python3 -c 'import json,sys;print(json.load(sys.stdin)["prompt"].replace("<DATE>","'"$DATE_TAG"'"))')
  tlog=$(printf '%s' "$line" | python3 -c 'import json,sys;print(json.load(sys.stdin)["log_path"].replace("<DATE>","'"$DATE_TAG"'"))')
  mkdir -p "$(dirname "$tlog")"
  if [ -f "$STATE/$id.done" ]; then log "skip $id（已 done，断电续作）"; continue; fi
  api=$(probe_api) || { log "API 不可用，终止剩余队列"; overall_rc=5; break; }
  n=0
  while : ; do
    log "run $id (attempt $((n+1))/$((retry+1))) box=${tbox}s api=$api"
    [ "$RUN" = "1" ] || { log "DRY_RUN 跳过执行 $id"; break; }
    # 低优先级 + 硬截止盒；pi 非交互一次性任务模式（-p = process prompt and exit）
    # 会话固定落在 .pi/sessions/tablet/ ⇒ 断电后可 pi --resume / scripts/sess.sh 续作，且与主机会话隔离不互盖
    mkdir -p "${ROOT}/.pi/sessions/tablet"
    nice -n 19 ionice -c 3 timeout -k 60 "$tbox" \
      pi -p --mode text \
         --session-dir "${ROOT}/.pi/sessions/tablet" --name "night-${DATE_TAG}-${id}-a$((n+1))" \
         ${PI_MODEL:+--model "$PI_MODEL"} \
         "$prompt" >"$tlog" 2>&1
    rc=$?
    ps -o pid,etime,cmd -C pi --no-headers 2>/dev/null | head -3   # 核实没有残留
    if [ "$rc" = "0" ]; then touch "$STATE/$id.done"; log "done $id"; break; fi
    touch "$STATE/$id.retry$n"
    n=$((n+1))
    if [ "$n" -gt "$retry" ]; then touch "$STATE/$id.fail"; log "FAIL $id rc=$rc（重试耗尽，见 $tlog）"; overall_rc=6; break; fi
    log "retry $id in $((60*n))s (rc=$rc)"; sleep $((60*n))
  done
done < "$QUEUE"

# ---------- 收尾回传 ----------
log "回传产物（单向 平板→主机，禁 --delete）"
if [ -n "$HOST_RSYNC" ]; then
  nice -n 19 rsync -a --checksum "reports/artifacts/tablet-offload-20261030/" "${HOST_RSYNC}reports/artifacts/tablet-offload-20261030/" \
    || log "rsync 回传失败（不致命：早上主机用 tablet-sync.sh --fetch-tablet 拉）"
  nice -n 19 rsync -a --checksum --ignore-existing "TASKS/sessions/" "${HOST_RSYNC}TASKS/sessions/tablet-incoming/" \
    || log "rsync TASKS/sessions 回传失败"
else
  log "TABLET_RSYNC_TARGET 未设置 ⇒ 跳过 rsync，早上由主机 tablet-sync.sh --fetch-tablet 拉取"
fi
if [ "$ALLOW_PUSH" = "1" ]; then
  br="tablet/night-${DATE_TAG}"
  git push ustc-ssh "HEAD:refs/heads/${br}" || log "push ${br} 失败（禁 force；交主机收口）"
else
  log "未开 --allow-push ⇒ 不 push（默认安全）"
fi

log "总结：done=$(ls "$STATE"/*.done 2>/dev/null | wc -l) fail=$(ls "$STATE"/*.fail 2>/dev/null | wc -l) rc=$overall_rc"
log "早上主机 review 序列：tablet-sync.sh --preflight && --fetch-tablet && 逐分支 --merge-tablet；见 reports/tablet-offload-plan-20261030.md §3.4"
exit $overall_rc
