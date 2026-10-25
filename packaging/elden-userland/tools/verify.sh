#!/bin/bash
# verify.sh — 用户态固化门（离线结构检查 + 在线 sha 漂移检查）
#
# 判据（任一 FAIL 即门不过）：
#   A. MANIFEST.tsv 的每一行 files/ 副本存在且 sha256 与清单一致（清单自洽）
#   B. 每个 ELF 都有 sources.tsv 行；有 build+source 的必须**源文件存在**（可重建）
#   C. services.tsv 每个 ours/override 行的 exec 必须落在 MANIFEST 或 extra/ 里（不留幽灵服务）
#   D. 渲染门：render.py --check 通过；两套 unit 都在；unit 结构合法；无跨 init 污染
#   E. 语义红线（README 里那 5 条）逐条断言
#   F. 在线时：设备逐字比对 files/（漂移只报 DIFF，不改）
#
# 用法：bash tools/verify.sh [--offline] [user@host]
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REPO=$(cd -- "$HERE/../.." && pwd)
OFFLINE=0
SSH_TARGET=${SSH_TARGET:-root@192.168.7.1}
for a in "$@"; do
  case "$a" in
    --offline) OFFLINE=1 ;;
    *@*) SSH_TARGET=$a ;;
  esac
done

fails=0
warns=0
ok()   { printf '  ok    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; fails=$((fails + 1)); }
warn() { printf '  WARN  %s\n' "$*"; warns=$((warns + 1)); }
sec()  { printf '\n[%s]\n' "$*"; }

[ -f "$HERE/MANIFEST.tsv" ] || { echo "verify: 先跑 tools/sync-from-device.sh"; exit 1; }

# ---------------------------------------------------------------- A. 清单自洽
sec "A. MANIFEST ↔ files/ 自洽"
n_a=0
while IFS=$'\t' read -r dst kind sha size mode repo_src; do
  [ "$dst" = "dst" ] && continue
  [ -n "$dst" ] || continue
  if [ "$repo_src" = "-" ]; then
    case "$kind" in elf) : ;; *) fail "$dst: kind=$kind 但无 repo_src" ; continue ;; esac
  else
    f="$HERE/$repo_src"
    [ -f "$f" ] || { fail "$dst: 缺副本 $repo_src"; continue; }
    got=$(sha256sum "$f" | cut -d' ' -f1)
    [ "$got" = "$sha" ] || fail "$dst: 副本 sha 与清单不符（$got != $sha）"
  fi
  n_a=$((n_a + 1))
done <"$HERE/MANIFEST.tsv"
ok "$n_a 行已核对"

# ---------------------------------------------------------------- B. 可重建
sec "B. ELF 可重建性（sources.tsv）"
if [ -f "$HERE/sources.tsv" ]; then
  while IFS=$'\t' read -r dst build src status note; do
    case "$dst" in \#*|"") continue ;; esac
    case "$status" in
      ok)
        [ "$build" != "-" ] || fail "$dst: status=ok 但无 build"
        IFS=',' read -ra specs <<<"$src"
        for s in "${specs[@]}"; do
          s=$(echo "$s" | xargs)
          [ -e "$REPO/$s" ] || fail "$dst: 源不存在 $s"
        done
        ok "$dst ← $src"
        ;;
      missing) warn "$dst: 不可重建（无源）— $note" ;;
      *) fail "$dst: 未知 status=$status" ;;
    esac
  done <"$HERE/sources.tsv"
  # 反向：MANIFEST 里每个 elf 都要有行
  awk -F'\t' 'NR>1 && $2=="elf"{print $1}' "$HERE/MANIFEST.tsv" | while read -r d; do
    grep -qP "^\Q$d\E\t" "$HERE/sources.tsv" || echo "  FAIL  $d: sources.tsv 无记录"
  done | tee /tmp/.verify_elf.$$ | grep -q FAIL && fails=$((fails + $(grep -c FAIL /tmp/.verify_elf.$$)))
  rm -f /tmp/.verify_elf.$$
else
  fail "缺 sources.tsv"
fi

# ---------------------------------------------------------------- C. 无幽灵服务
sec "C. services.tsv ↔ 资产对齐"
has_asset() {  # $1 = 绝对路径；命中 MANIFEST 或 extra/ 即真
  grep -qP "^$(printf '%s' "$1" | sed 's/[.[\\*^$/]/\\&/g')\t" "$HERE/MANIFEST.tsv" 2>/dev/null && return 0
  [ -f "$HERE/extra$1" ] && return 0
  return 1
}
while IFS=$'\t' read -r name init class desc exec args env log respawn need after before wantedby enabled; do
  case "$name" in \#*|""|name) continue ;; esac
  if [ "$init" = "package" ]; then ok "$name（package：unit 由发行版提供，不校验 exec）"; continue; fi

  case "$exec" in
    /usr/bin/python3|/usr/bin/python|/bin/sh|/usr/bin/env)
      # 解释器类：判据落在第一个脚本参数上
      script=$(printf '%s' "$args" | awk '{print $1}')
      if has_asset "$script"; then ok "$name → $exec $script（解释器 + 仓库脚本）"
      else fail "$name: 解释器脚本 $script 不在 MANIFEST/extra"; fi
      ;;
    *)
      if has_asset "$exec"; then ok "$name → $exec（$( [ -f "$HERE/extra$exec" ] && echo extra || echo 设备副本)）"
      elif [ "$init" = "override" ]; then ok "$name → $exec（包二进制，unit 被我们覆盖）"
      else fail "$name: exec $exec 既不在 MANIFEST 也不在 extra/"; fi
      ;;
  esac
done <"$HERE/services.tsv"

# ---------------------------------------------------------------- D. 渲染门
sec "D. 两套 unit 渲染"
if python3 "$HERE/tools/render.py" --check >/tmp/.verify_render.$$ 2>&1; then
  ok "render.py --check：$(tail -2 /tmp/.verify_render.$$ | head -1)"
else
  fail "render.py --check 失败：$(tail -3 /tmp/.verify_render.$$ | tr '\n' ' ')"
fi
rm -f /tmp/.verify_render.$$

if python3 "$HERE/tools/render.py" >/dev/null 2>&1; then
  nsvc=$(awk -F'\t' '$0 !~ /^#/ && NF==14 && $1!="name" && $2!="package"' "$HERE/services.tsv" | wc -l)
  nunit=$(ls "$HERE"/out/units/systemd/*.service 2>/dev/null | wc -l)
  ninit=$(ls "$HERE"/out/units/openrc/ 2>/dev/null | wc -l)
  [ "$nunit" = "$nsvc" ] && [ "$ninit" = "$nsvc" ] || fail "渲染数量不符（服务 $nsvc / unit $nunit / initd $ninit）"
  for f in "$HERE"/out/units/systemd/*.service; do
    for s in '[Unit]' '[Service]' '[Install]' 'ExecStart=' 'Description='; do
      grep -qF "$s" "$f" || fail "$(basename "$f"): 缺 $s"
    done
    grep -qE '^(systemctl|rc-service|apk|apt-get)' "$f" && fail "$(basename "$f"): 跨 init 调用"
  done
  for f in "$HERE"/out/units/openrc/*; do
    head -1 "$f" | grep -q '^#!/sbin/openrc-run' || fail "$(basename "$f"): 缺 openrc-run shebang"
    grep -q '^command=' "$f" || fail "$(basename "$f"): 缺 command="
    bash -n "$f" || fail "$(basename "$f"): sh 语法错误"
    grep -q 'systemctl' "$f" && fail "$(basename "$f"): 跨 init 调用"
  done
  ok "unit 结构检查完成（$nunit 个 systemd + $ninit 个 openrc）"
else
  fail "render.py 写盘失败"
fi

# ---------------------------------------------------------------- E. 语义红线
sec "E. 语义红线（README §服务迁移口径）"
grep -qP '^qbootctl\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t1$' "$HERE/services.tsv" \
  && ok "qbootctl 默认启用（PITFALLS #181）" || fail "qbootctl 必须 enabled=1"
awk -F'\t' '$1=="greetd"{exit !($9>0)}' "$HERE/services.tsv" \
  && ok "greetd 有 respawn（PITFALLS #318）" || fail "greetd 必须 respawn>0"
[ -f "$HERE/hooks/iio-sensor-proxy.pre" ] && grep -q 'qrtr-lookup' "$HERE/hooks/iio-sensor-proxy.pre" \
  && ok "iio-sensor-proxy 等 QRTR svc 400（G1-34）" || fail "缺 iio-sensor-proxy 的 QRTR 等待钩子"
iv=$(awk -F'\t' '$1=="wifi-scan-refresh"{for(i=1;i<=NF;i++) if($i ~ /^WIFI_SCAN_INTERVAL=/) {sub(/.*=/,"",$i); print $i}}' "$HERE/services.tsv")
if [ -n "$iv" ] && [ "$iv" -lt 180 ] 2>/dev/null; then ok "wifi-scan-refresh 间隔 ${iv}s < 180s（PITFALLS #354）"
else fail "wifi-scan-refresh 间隔缺失或 ≥180s（当前 '$iv'）"; fi
grep -q 'echo 255 > /run/elden-haptic/leds/vibrator/amplitude' "$HERE/hooks/elden-hapticd.pre" \
  && ok "elden-hapticd amplitude 默认 255（TASKS C10）" || fail "amplitude 默认必须是 255"
[ -x "$HERE/extra/usr/local/sbin/elden-powerlog-mark.sh" ] \
  && ok "shutdown 标记已剥离成独立脚本" || warn "elden-powerlog-mark.sh 未置可执行位"

# ---------------------------------------------------------------- F. 设备漂移
sec "F. 设备逐字比对"
if [ "$OFFLINE" = "1" ]; then
  ok "--offline：跳过"
elif ssh -o BatchMode=yes -o ConnectTimeout=6 "$SSH_TARGET" true 2>/dev/null; then
  drift=0; checked=0
  while IFS=$'\t' read -r dst kind sha size mode repo_src; do
    [ "$dst" = "dst" ] && continue
    [ "$kind" = "elf" ] && continue
    checked=$((checked + 1))
    got=$(ssh -n -o BatchMode=yes -o ConnectTimeout=6 "$SSH_TARGET" "sha256sum /${dst#/} 2>/dev/null | cut -d' ' -f1")
    if [ -z "$got" ]; then warn "$dst: 设备上已不存在（仓库副本保留）"
    elif [ "$got" != "$sha" ]; then
      fail "$dst: 设备与仓库副本不一致（设备 $got / 副本 $sha）⇒ 需要 sync 并评审"
      drift=$((drift + 1))
    fi
  done <"$HERE/MANIFEST.tsv"
  [ "$drift" = 0 ] && ok "$checked 条与设备逐字一致"

  # ELF 漂移只提示（重编会改 sha，不代表功能漂移）
  awk -F'\t' 'NR>1 && $2=="elf"{print $1"\t"$3}' "$HERE/MANIFEST.tsv" | while IFS=$'\t' read -r d h; do
    got=$(ssh -n -o BatchMode=yes -o ConnectTimeout=6 "$SSH_TARGET" "sha256sum $d 2>/dev/null | cut -d' ' -f1")
    [ -z "$got" ] && continue
    [ "$got" = "$h" ] || echo "  DIFF  $d: 设备 $got ≠ 清单 $h（重编？）"
  done
else
  warn "设备不可达（$SSH_TARGET），跳过 F"
fi

# ---------------------------------------------------------------- G. 第 4 处真源
sec "G. rootfs/build-rootfs.sh 白名单 ⊆ MANIFEST（防第 4 处漂移）"
list=$(awk '/^for s in /{flag=1} flag{sub(/\\$/,""); printf "%s ", $0} /do$/{if(flag){exit}}' \
         "$REPO/rootfs/build-rootfs.sh" 2>/dev/null | sed 's/^for s in //; s/ do$//')
if [ -z "$list" ]; then
  warn "未能解析 build-rootfs.sh 的 helper 白名单（脚本结构变了？）"
else
  miss=0
  for f in $(echo "$list" | tr ';' ' '); do
    case "$f" in do|""|for) continue ;; esac
    grep -qP "\t/\S*/\Q$f\E\t|/\Q$f\E\t" "$HERE/MANIFEST.tsv" \
      || { warn "白名单项 $f 不在 MANIFEST"; miss=$((miss + 1)); }
  done
  [ "$miss" = 0 ] && ok "白名单 $(echo "$list" | wc -w) 项全部在 MANIFEST 中"
fi

printf '\n==== verify: FAIL=%d WARN=%d ====\n' "$fails" "$warns"
[ "$fails" = 0 ] || exit 1
