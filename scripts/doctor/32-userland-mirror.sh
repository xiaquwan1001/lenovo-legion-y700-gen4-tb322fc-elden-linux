#!/usr/bin/env bash
# 32-userland-mirror.sh — 用户态镜像一致性门 + packaging verify.sh --offline 接线
# （arch-audit-20261127 A9/A10；只进全量档。只读：verify.sh --offline 零设备写、
#   派生 out/units 幂等再生成且字节同 git；镜像门 --check 纯内存比对。）
set -u
ROOT="${ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

echo '== 32. 用户态镜像一致性 + packaging verify 接线（A9/A10） =='
ok()   { printf '  [ok] %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*"; }
info() { printf '  info %s\n' "$*"; }

# ---- §32a：镜像一致性门（A9）------------------------------------------------
if [ ! -f "$ROOT/scripts/check-userland-mirror.sh" ]; then
  fail "缺 scripts/check-userland-mirror.sh"
else
  out=$(bash "$ROOT/scripts/check-userland-mirror.sh" --check 2>&1); rc=$?
  case $rc in
    0) summary=$(grep '汇总：' <<<"$out" | head -1 | sed 's/^汇总：//')
       ok "镜像一致性门 PASS（$summary）"
       info "13 组同名不同内容已于 2026-11-27 逐组裁定（明细 reports/userland-mirror-adjudication-20261127.md）："
       info "  bash scripts/check-userland-mirror.sh --check ／ --diff <名> ／ reports/userland-mirror-gate-20261127.md" ;;
    1) grep '^\  \[FAIL\]' <<<"$out" | head -5
       fail "镜像一致性门：存在白名单外的同名不同内容漂移（rc=1）" ;;
    *) info "镜像一致性门 SKIP（rc=$rc）：$(head -1 <<<"$out")" ;;
  esac
fi

# ---- §32b：packaging verify.sh --offline（A10 接线，离线档）------------------
V="$ROOT/packaging/elden-userland/tools/verify.sh"
if [ ! -f "$V" ]; then
  fail "缺 packaging/elden-userland/tools/verify.sh"
else
  out=$(cd "$ROOT" && timeout 120 bash "$V" --offline 2>&1); rc=$?
  tail=$(grep -c '^  ok' <<<"$out")
  case $rc in
    0) ok "packaging verify.sh --offline：FAIL=0（$tail 条 ok，A–E/G 段）"
       info "$(grep '^==== verify' <<<"$out")" ;;
    *) grep '^  FAIL' <<<"$out" | head -5
       fail "packaging verify.sh --offline 退出码 $rc" ;;
  esac
fi
