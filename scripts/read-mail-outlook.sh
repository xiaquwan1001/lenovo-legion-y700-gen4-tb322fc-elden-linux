#!/bin/sh
# read-mail-outlook.sh — Outlook 通道只读快照（himalaya envelope list，不改已读态）
# 用法:
#   read-mail-outlook.sh --days N [--mailbox inbox|junk|sent|all] [--limit N]
#   read-mail-outlook.sh --check      # 自检: himalaya 存在 + token 可取 + 三箱可 SELECT
#   read-mail-outlook.sh --selftest   # stub 注入式反样本自检，不动真实账号
# 输出: 序号|日期 发件人|主题（每行一封，最近在前）
#
# 已知坑（不要改 ~/.config，属用户环境）:
#   ~/.config/himalaya/config.toml 里 `mailbox.alias.sent = "Sent Items"`，
#   而 Outlook 实际文件夹叫 `Sent`；himalaya 对 -m 的取值做大小写不敏感的
#   alias 匹配，所以 "sent"/"Sent"/"SENT" 全部被解析成不存在的 "Sent Items"。
#   规避: 本脚本把用户配置 sed 修正后写到临时文件，仅经 -c 传入，原文件不动。

set -u

CONFIG="$HOME/.config/himalaya/config.toml"
HIM=himalaya
TOKEN_CMD="ortie token show -a microsoft-imap-smtp"
TMO="60"                      # 单次外部调用上限（秒）
PAGE_SIZE=100

DAYS=7
MAILBOX=all
LIMIT=0

die() { echo "read-mail-outlook: $*" >&2; exit 2; }

# ---------- 参数 ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --days)    [ $# -ge 2 ] || die "--days 需要参数"; DAYS=$2; shift 2 ;;
    --mailbox) [ $# -ge 2 ] || die "--mailbox 需要参数"; MAILBOX=$2; shift 2 ;;
    --limit)   [ $# -ge 2 ] || die "--limit 需要参数"; LIMIT=$2; shift 2 ;;
    --check|--selftest) ACTION=$1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done

# ---------- himalaya 包装: 修正 sent alias + timeout ----------
# 返回 0 即配置修正文件就绪, $FIXCFG 为路径
make_fixed_config() {
  [ -f "$CONFIG" ] || { echo "配置不存在: $CONFIG" >&2; return 1; }
  FIXCFG=$(mktemp "${TMPDIR:-/tmp}/himalaya-outlook-fix.XXXXXX")
  # 只替换错误的 sent 别名; 若已是 "Sent" 则原样通过
  sed 's|mailbox\.alias\.sent = "Sent Items"|mailbox.alias.sent = "Sent"|' \
      "$CONFIG" > "$FIXCFG" || return 1
}

himalaya_run() {
  # $HIM 可被 PATH stub 替换（selftest 用）
  timeout -k 5 "$TMO" "$HIM" -c "$FIXCFG" "$@"
}

# ---------- 解析: envelope list 输出 → 序号|日期 发件人|主题 ----------
format_envelopes() {
  # 先去掉 unread 标记列 `*`：himalaya 把未读信渲染成 `<id>  *  <date> …`，
  # 不过滤会把整行丢掉 = 静默漏信（2026-11-28 实测：100 封只出 16 行）
  sed -E 's/^([[:space:]]*[0-9]+)[[:space:]]+\*[[:space:]]+/\1  /' \
  | sed -n -E 's/^[[:space:]]*([0-9]+)[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]+([0-9]{2}:[0-9]{2})[[:space:]]+(.*[^[:space:]])[[:space:]]*$/\1|\2 \3|\4/p' \
  | sed -E 's/^([^|]*\|[^|]*)[[:space:]]{2,}(.*)$/\1|\2/'
}

list_one() {
  # $1 = 实际 mailbox 名（sent 已由 FIXCFG alias 修正）
  mb=$1
  cutoff=$(date -d "-$DAYS days" +%Y-%m-%d 2>/dev/null) || cutoff=""
  page=1
  count=0
  while :; do
    out=$(himalaya_run envelope list -s "$PAGE_SIZE" -p "$page" -m "$mb" 2>&1)
    rc=$?
    [ $rc -eq 0 ] || { echo "read-mail-outlook: mailbox '$mb' SELECT/列出失败 (rc=$rc):" >&2
                       echo "$out" | sed 's/^/  /' >&2; return 1; }
    # 反「静默漏信」：广告行数 vs 解析行数必须相等（2026-11-28 踩过：`*` 未读列未处理时 100 封只出 16 行）
    raw_n=$(printf '%s\n' "$out" | grep -cE '^[[:space:]]*[0-9]+[[:space:]]+(\*[[:space:]]+)?[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
    parsed_n=$(printf '%s\n' "$out" | format_envelopes | grep -c . || true)
    [ "$raw_n" = "$parsed_n" ] || echo "read-mail-outlook: WARN mailbox '$mb' 第 $page 页解析 $parsed_n/$raw_n 行（himalaya 输出格式变了？）" >&2
    printf '%s\n' "$out" | format_envelopes | while IFS='|' read -r id dt rest; do
      [ -n "$id" ] || continue
      d=${dt%% *}
      # 越过窗口即停（日期字符串按字典序比较）
      [ -n "$cutoff" ] && [ "$d" \< "$cutoff" ] && continue
      echo "$id|$dt|$rest"
    done
    got=$(printf '%s\n' "$out" | format_envelopes | grep -c . )
    count=$((count + got))
    [ "$LIMIT" -gt 0 ] && [ "$count" -ge "$LIMIT" ] && break
    # 无下一页则停（只认真实格式 `Next page: --page N`；stub/残缺输出里的
    # 裸 `Next page:` 不算，否则分页会无限循环——2026-11-28 实测踩过 30 min 挂死）
    printf '%s\n' "$out" | grep -q "Next page: --page" || break
    page=$((page + 1))
    [ "$page" -le 200 ] || { echo "read-mail-outlook: 分页超过 200 页，中止" >&2; break; }
  done \
  | awk -F'|' -v lim="$LIMIT" 'lim==0 || NR<=lim { print }'
}

list_mailboxes() {
  case "$MAILBOX" in
    inbox|junk|sent) list_one "$MAILBOX" ;;
    all) for mb in inbox junk sent; do
           echo "# mailbox: $mb"
           list_one "$mb" || return 1
         done ;;
    *) die "未知 mailbox '$MAILBOX'（可用: inbox|junk|sent|all）" ;;
  esac
}

# ---------- --check ----------
do_check() {
  fail=0
  say() { echo "[$2] $1"; [ "$2" = PASS ] || fail=1; }
  if command -v himalaya >/dev/null 2>&1; then
    say "himalaya 存在: $(command -v himalaya)" PASS
  else
    say "himalaya 不存在" FAIL
  fi
  tok=$(timeout -k 5 "$TMO" $TOKEN_CMD 2>/dev/null | tr -d '[:space:]')
  if [ -n "$tok" ]; then
    say "XOAUTH2 token 可取 (ortie, len=${#tok})" PASS
  else
    say "token 取不到: $TOKEN_CMD" FAIL
  fi
  make_fixed_config || { say "配置修正失败" FAIL; return 1; }
  trap 'rm -f "$FIXCFG"' EXIT INT TERM
  for mb in inbox junk sent; do
    if himalaya_run envelope list -s 1 -m "$mb" >/dev/null 2>&1; then
      say "mailbox '$mb' 可 SELECT" PASS
    else
      say "mailbox '$mb' SELECT 失败" FAIL
    fi
  done
  [ $fail -eq 0 ] && echo "check: 全部通过" && return 0
  echo "check: 有 FAIL 项" >&2; return 1
}

# ---------- --selftest（stub 注入，不碰真实账号） ----------
do_selftest() {
  stub_dir=$(mktemp -d "${TMPDIR:-/tmp}/rmo-selftest.XXXXXX")
  FIXCFG=$(mktemp "${TMPDIR:-/tmp}/rmo-selftest-cfg.XXXXXX")
  trap 'rm -rf "$stub_dir" "$FIXCFG"' EXIT INT TERM
  export PATH="$stub_dir:$PATH"

  # stub himalaya: 读环境变量决定行为
  cat > "$stub_dir/himalaya" <<'EOF'
#!/bin/sh
mode=${RMO_STUB_MODE:-ok}
case "$mode" in
  dead)   echo "stub: account unavailable" >&2; exit 1 ;;
  ok)
    for a in "$@"; do
      case "$a" in
        bogus) echo "Error: IMAP mailbox 'bogus' not found" >&2; exit 1 ;;
      esac
    done
    mb=inbox; p=1; prev=""
    while [ $# -gt 0 ]; do case "$1" in -m) mb=$2; shift 2;; -p) p=$2; shift 2;; *) shift;; esac; done
    echo "Account: stub (imap)"; echo "Mailbox: $mb"; echo "Page: $p"
    if [ "$p" -eq 1 ]; then
      case "$mb" in
        sent) echo "  11  2020-01-01 08:00  me  ancient sent mail"
              echo "  12  2026-11-28 09:00  me  fresh sent mail" ;;
        *)    echo "  21  2020-01-01 08:00  alice  ancient old mail"
              echo "  22  2026-11-28 09:00  bob  fresh new mail"
              echo "  23  *  2026-11-28 10:00  carol  starred new mail" ;;
      esac
      echo "Next page: --page 2"
    fi ;;
esac
EOF
  chmod +x "$stub_dir/himalaya"
  cat > "$stub_dir/ortie" <<'EOF'
#!/bin/sh
echo "FAKE-TOKEN-0123456789"
EOF
  chmod +x "$stub_dir/ortie"
  printf 'mailbox.alias.sent = "Sent"\n' > "$FIXCFG"

  fails=0
  t() { if [ "$2" -eq 0 ]; then echo "[PASS] $1"; else echo "[FAIL] $1"; fails=$((fails+1)); fi }

  # 反样本 1: 账号不可用 ⇒ --check rc≠0
  RMO_STUB_MODE=dead sh "$0" --check >/dev/null 2>&1
  t "反样本1: 账号不可用 ⇒ check rc≠0" $([ $? -ne 0 ]; echo $?)

  # 反样本 2: 错误 mailbox 名 ⇒ 明确报错 rc≠0，不静默 0 封
  err=$(RMO_STUB_MODE=ok sh "$0" --mailbox bogus 2>&1); rc=$?
  [ $rc -ne 0 ] && printf '%s' "$err" | grep -q "bogus"
  t "反样本2: mailbox=bogus ⇒ rc≠0 且报错点名 bogus (rc=$rc)" $?

  # 反样本 3: --days 过滤排除已知旧信（2020-01-01）
  out=$(RMO_STUB_MODE=ok sh "$0" --days 3 --mailbox inbox); rc=$?
  printf '%s' "$out" | grep -q "ancient old mail" && bad=1 || bad=0
  printf '%s' "$out" | grep -q "fresh new mail" && good=1 || good=0
  t "反样本3: --days 3 排除 2020 旧信且保留新信 (rc=$rc)" $(( 1 - bad && good ? 0 : 1 ))

  # 反样本 4: 未读标记 `*` 行不能被静默丢弃（2026-11-28 实踩：100 封只出 16 行）
  out=$(RMO_STUB_MODE=ok sh "$0" --days 3 --mailbox inbox); rc=$?
  printf '%s' "$out" | grep -q "starred new mail"
  t "反样本4: 未读标记 * 的邮件行仍被列出 (rc=$rc)" $?

  # 附加: sent 别名修正后可列出
  out=$(RMO_STUB_MODE=ok sh "$0" --days 36500 --mailbox sent); rc=$?
  printf '%s' "$out" | grep -q "fresh sent mail"
  t "附加: sent 经临时配置修正可列出 (rc=$rc)" $?

  [ $fails -eq 0 ] && echo "selftest: 全部通过" && return 0
  echo "selftest: $fails 项失败" >&2; return 1
}

# ---------- 主流程 ----------
make_fixed_config || die "无法生成修正配置"
trap 'rm -f "$FIXCFG"' EXIT INT TERM

case "${ACTION:-}" in
  --check)    do_check ;;
  --selftest) do_selftest ;;
  *)          list_mailboxes ;;
esac
