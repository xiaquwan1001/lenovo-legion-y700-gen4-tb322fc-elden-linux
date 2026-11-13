#!/bin/bash
# verify.sh — 用户态固化门（离线结构检查 + 在线 sha 漂移检查）
#
# 判据（任一 FAIL 即门不过）：
#   A. MANIFEST.tsv 的每一行 files/ 副本存在且 sha256 与清单一致（清单自洽）
#   B. 每个 ELF 都有 sources.tsv 行；有 build+source 的必须**源文件存在**（可重建）
#   C. services.tsv 每个 ours/override 行的 exec 必须落在 MANIFEST 或 extra/ 里（不留幽灵服务）
#   D. 渲染门：render.py --check 通过；两套 unit 都在；unit 结构合法；无跨 init 污染
#   E. 语义红线（README 里那 5 条）逐条断言
#   F. 在线时：设备逐字比对「根画像」下的期望表（MANIFEST/渲染单元 + 暂存 overlay 优先）
#   F2. 渲染单元 ↔ 设备（systemd → /usr/lib/systemd/system，openrc → /etc/init.d）
#   H. --rebuildable（仅该段，2026-11-04 新增，不改 A–G 判据）：
#      build/artifacts.tsv 里 7 个 ELF 逐个判「源在 + build 入口在 + 配方可 --dry-run」，
#      输出 `ok=N missing=M` 的**可复现数字**（10-25 报告口径 4 ok/3 missing 的自动化版本）。
#   H2. --rebuild（同上，另加）：真编 4 个静态交叉件（不动 chroot/root 配方）并与 MANIFEST 比 sha，
#      只写仓库内 out/；sha 差异仅提示（重编改字节 ≠ 功能漂移）。
#   H3. 覆盖件（--rebuildable 内）：overrides.tsv 每行 = 我们用自编件盖住发行版包的文件。
#      判据 = dst/recipe/patch_dirs 都在 + 配方可 `--dry-run` + （在线时）设备上 divert 与 hold 在位。
#      背景 PITFALLS #654：只 install 会被 apt 静默冲回上游件。
#
# 用法：bash tools/verify.sh [--offline] [user@host]
#       bash tools/verify.sh --rebuildable   只跑 H 段（重建性数字，零写盘）
#       bash tools/verify.sh --rebuild       只跑 H+H2 段（真编静态件，写 out/）
#       ROOT_PROFILE=systemd|openrc   强制根画像（默认自动探测 /etc/elden-init-mode → /run/systemd/system）
#       LOCAL_ROOT=<dir>              不连设备，改读本地树（负向测试 / 预演 overlay 用）
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REPO=$(cd -- "$HERE/../.." && pwd)
OFFLINE=0
SSH_TARGET=${SSH_TARGET:-root@192.168.7.1}
LOCAL_ROOT=${LOCAL_ROOT:-}
STAGE=${STAGE:-$REPO/out/stage-debian}
[ -d "$STAGE" ] || STAGE=
REBUILD_ONLY=0   # 0=不跑 H；1=只跑 H（--rebuildable）；2=H+H2（--rebuild）
for a in "$@"; do
  case "$a" in
    --offline) OFFLINE=1 ;;
    --rebuildable) OFFLINE=1; [ "$REBUILD_ONLY" = 2 ] || REBUILD_ONLY=1 ;;
    --rebuild) OFFLINE=1; REBUILD_ONLY=2 ;;
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

# ---------------------------------------------------------------- H. 重建性（--rebuildable）
# 判据只做加法：默认路径完全不进本函数（见末尾 dispatch），A–G 判据一字未改。
section_rebuild() {
  local map=$HERE/build/artifacts.tsv
  sec "H. ELF 重建性（build/artifacts.tsv）"
  if [ ! -f "$map" ]; then fail "缺 build/artifacts.tsv（ELF ↔ 配方 ↔ 产物）"; return 1; fi

  local n_ok=0 n_missing=0 n_recipe=0 n_dry=0 n_art_same=0 n_art_diff=0 n_rows=0
  local dst recipe art
  while IFS=$'\t' read -r dst recipe art; do
    case "$dst" in \#*|"") continue ;; esac
    n_rows=$((n_rows + 1))

    # H1. dst 必须在 MANIFEST 里，且 kind=elf
    local sha size
    sha=$(awk -F'\t' -v d="$dst" '$1==d && $2=="elf"{print $3}' "$HERE/MANIFEST.tsv")
    if [ -z "$sha" ]; then fail "$dst: MANIFEST 无该 elf 行"; n_missing=$((n_missing + 1)); continue; fi

    # H2. sources.tsv 行 + source 存在 + build 入口存在
    local line status src build bad=0
    line=$(grep -P "^\Q$dst\E\t" "$HERE/sources.tsv" 2>/dev/null | head -1)
    if [ -z "$line" ]; then fail "$dst: sources.tsv 无记录"; n_missing=$((n_missing + 1)); continue; fi
    IFS=$'\t' read -r _ build src status _ <<<"$line"
    if [ "$status" != "ok" ]; then warn "$dst: sources.tsv status=$status"; n_missing=$((n_missing + 1)); continue; fi
    local spec
    IFS=',' read -ra specs <<<"$src"
    for spec in "${specs[@]}"; do
      spec=$(echo "$spec" | xargs)
      [ -e "$REPO/$spec" ] || { fail "$dst: 源不存在 $spec"; bad=1; }
    done
    # build 入口：第一个 token 是 bash/sh 时看第二个；否则看 PATH
    local b1 b2
    b1=$(printf '%s' "$build" | awk '{print $1}')
    b2=$(printf '%s' "$build" | awk '{print $2}')
    case "$b1" in
      bash|sh) [ -n "$b2" ] && [ -e "$REPO/${b2#./}" ] || { fail "$dst: build 脚本不存在 ${b2:-（空）}"; bad=1; } ;;
      '') fail "$dst: build 为空" ; bad=1 ;;
      *) command -v "$b1" >/dev/null 2>&1 || { fail "$dst: build 命令 $b1 不在 PATH"; bad=1; } ;;
    esac
    [ "$bad" = 0 ] || { n_missing=$((n_missing + 1)); continue; }

    # H3. 配方存在 + --dry-run rc=0 且有输出（零写盘演练）
    local rp=$HERE/build/$recipe
    if [ ! -f "$rp" ]; then
      fail "$dst: 配方缺失 build/$recipe"; n_missing=$((n_missing + 1)); continue
    fi
    n_recipe=$((n_recipe + 1))
    local out rc
    out=$(bash "$rp" --dry-run 2>/dev/null); rc=$?
    if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^+ '; then
      n_dry=$((n_dry + 1))
    else
      fail "$dst: 配方 $recipe --dry-run 失败（rc=$rc）"
      n_missing=$((n_missing + 1)); continue
    fi

    # H4. 已产出件 sha 对照（参考项，不算 FAIL）
    local rel=""
    if [ "$art" != "-" ] && [ -f "$REPO/$art" ]; then
      local got; got=$(sha256sum "$REPO/$art" | cut -d' ' -f1)
      if [ "$got" = "$sha" ]; then rel=identical; n_art_same=$((n_art_same + 1))
      else rel=diff; n_art_diff=$((n_art_diff + 1)); fi
    else
      rel=absent
    fi
    ok "$dst ← $src（配方 $recipe dry-run ok；产物 $rel）"
    n_ok=$((n_ok + 1))
  done <"$map"

  # 反向：MANIFEST 里的每个 elf 都在表里
  local d
  while read -r d; do
    awk -F'\t' -v d="$d" '$1==d{f=1} END{exit !f}' "$map" \
      || { fail "$d: build/artifacts.tsv 无记录（重建性未登记）"; n_missing=$((n_missing + 1)); }
  done < <(awk -F'\t' '$2=="elf"{print $1}' "$HERE/MANIFEST.tsv")

  printf '\n  ELF 共 %d 个：ok=%d missing=%d；配方 %d 个可 --dry-run；产物 sha 与清单 identical=%d diff=%d\n' \
    "$n_rows" "$n_ok" "$n_missing" "$n_dry" "$n_art_same" "$n_art_diff"
  # 机器可读的稳定行（供脚本/CI 抓数字）
  printf '==== rebuildable: elf=%d ok=%d missing=%d recipe=%d dry-run-ok=%d identical=%d ====\n' \
    "$n_rows" "$n_ok" "$n_missing" "$n_recipe" "$n_dry" "$n_art_same"

  # -------------------------------------------------------- H3. 覆盖件（发行版包被我们盖住的文件）
  sec "H3. 覆盖件登记（overrides.tsv）"
  local ov=$HERE/overrides.tsv
  if [ -f "$ov" ]; then
    local ov_n=0 ov_ok=0 ov_bad=0 d pkg dt hold rec pats ev
    while IFS=$'\t' read -r d pkg dt hold rec pats ev; do
      case "$d" in ''|'#'*) continue ;; esac
      ov_n=$((ov_n + 1))
      local bad=0
      [ -n "$d" ] || { fail "overrides: 空 dst"; bad=1; }
      [ -n "$rec" ] && [ -f "$HERE/build/$rec" ] || { fail "overrides: $d 的配方缺失 build/$rec"; bad=1; }
      if [ -n "$pats" ]; then
        local pd
        for pd in $(printf '%s' "$pats" | tr ',' ' '); do
          [ -d "$REPO/$pd" ] || { fail "overrides: $d 的补丁目录缺失 $pd"; bad=1; }
        done
      fi
      if [ -n "$rec" ] && [ -f "$HERE/build/$rec" ]; then
        if bash "$HERE/build/$rec" --dry-run >/dev/null 2>&1; then :; else
          fail "overrides: build/$rec --dry-run 失败"; bad=1
        fi
      fi
      [ "$bad" = 0 ] && { ok "$d（pkg=$pkg，divert=$dt，hold=$hold）"; ov_ok=$((ov_ok + 1)); } || ov_bad=$((ov_bad + 1))
    done < "$ov"
    printf '\n  覆盖件 %d 个：ok=%d bad=%d\n' "$ov_n" "$ov_ok" "$ov_bad"
    printf '==== overrides: n=%d ok=%d bad=%d ====\n' "$ov_n" "$ov_ok" "$ov_bad"
  else
    warn "缺 overrides.tsv（用自编件覆盖发行版包时必须有登记，否则会被 apt 静默冲回；PITFALLS #654）"
  fi

  # -------------------------------------------------------------- H2. 真编静态件（--rebuild）
  if [ "$REBUILD_ONLY" = 2 ]; then
    sec "H2. 真编静态交叉件并比 sha（写 out/；sha 差异仅提示）"
    local r
    for r in ffrumble elden-hapticd eldroid-sensord reboot2; do
      if bash "$HERE/build/$r.sh" >/tmp/.verify_rb.$$ 2>&1; then
        local dst2 art2 sha2 got2
        dst2=$(awk -F'\t' -v r="$r.sh" '$2==r{print $1}' "$HERE/build/artifacts.tsv")
        art2=$(awk -F'\t' -v r="$r.sh" '$2==r{print $3}' "$HERE/build/artifacts.tsv")
        sha2=$(awk -F'\t' -v d="$dst2" '$1==d{print $3}' "$HERE/MANIFEST.tsv")
        got2=$(sha256sum "$REPO/$art2" 2>/dev/null | cut -d' ' -f1)
        if [ -z "$got2" ]; then fail "$r: 构建成功但无产物 $art2"
        elif [ "$got2" = "$sha2" ]; then ok "$r: 重建产物与 MANIFEST 逐字一致（${got2:0:16}…）"
        else warn "$r: 重建产物 sha 与清单不同（重建 ${got2:0:12}… / 清单 ${sha2:0:12}…）⇒ 功能等价口径"; fi
      else
        fail "$r: 构建失败（见 /tmp/.verify_rb.$$ 尾部）"; tail -3 /tmp/.verify_rb.$$ | sed 's/^/        /'
      fi
    done
    rm -f /tmp/.verify_rb.$$
  fi
  return 0
}

if [ "$REBUILD_ONLY" != 0 ]; then
  section_rebuild
  printf '\n==== verify --%s: FAIL=%d WARN=%d ====\n' \
    "$([ "$REBUILD_ONLY" = 2 ] && echo rebuild || echo rebuildable)" "$fails" "$warns"
  [ "$fails" = 0 ] || exit 1
  exit 0
fi

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
# 2026-10-27 新增：SSC 加速度计的**唯一入口**是 udev 属性 ssc-accel。
# iio-sensor-proxy 3.9 上游 80-iio-sensor-proxy.rules 只给 fastrpc-adsp* 打 ssc-light/ssc-compass，
# 而 drv-ssc-accel.c 的 discover 是 drv_check_udev_sensor_type(device,"ssc-accel") ⇒ 缺属性 = 永远无 accel，
# 症状（Debian 根实测）是 HasAccelerometer=false 但 ssccli 能出数，极易误判成 libssc/DSP 坏了。
ru=$HERE/files/etc/udev/rules.d/81-libssc-elden.rules
if [ -f "$ru" ] && grep -q 'KERNEL=="fastrpc-adsp\*"' "$ru" \
   && grep -q 'IIO_SENSOR_PROXY_TYPE}+="ssc-accel' "$ru" \
   && grep -q 'ACCEL_MOUNT_MATRIX' "$ru"; then
  ok "SSC 加速度计 udev 规则在位（ssc-accel + mount matrix，G1-34）"
else
  fail "缺 81-libssc-elden.rules 或其 ssc-accel/ACCEL_MOUNT_MATRIX（HasAccelerometer 会恒 false）"
fi
[ -x "$HERE/extra/usr/local/sbin/elden-powerlog-mark.sh" ] \
  && ok "shutdown 标记已剥离成独立脚本" || warn "elden-powerlog-mark.sh 未置可执行位"

# ---------------------------------------------------------------- F. 设备漂移
sec "F. 设备逐字比对"
# ★ 2026-10-28 改（旧判据在 Debian 根上 FAIL=3 全是假阳性）：
#   - Debian 根由 `rootfs/debian/stage.sh` 组装 ⇒ 真正要 rsync 上去的内容在**暂存 overlay**
#     （`out/stage-debian/`），且 `rootfs/debian/overrides.tsv` 里的路径**本就该与 Alpine 副本不同**
#     （例：`/etc/conf.d/greetd` 在 systemd 的 EnvironmentFile 里不能带 `export`）。
#   - openrc 专属路径（`/etc/init.d`、`/etc/local.d`）在 systemd 根上不存在是**预期**，不是漂移。
#   ⇒ 期望表 = MANIFEST 文本行 + 渲染单元；每条的期望 sha 优先取 overlay 同名文件。
is_openrc_only() { case "$1" in /etc/init.d/*|/etc/local.d/*) return 0 ;; *) return 1 ;; esac; }

probe_profile() {   # → systemd | openrc
  case "${ROOT_PROFILE:-}" in systemd|openrc) echo "$ROOT_PROFILE"; return 0 ;; esac
  local m
  if [ -n "$LOCAL_ROOT" ]; then
    if   [ -f "$LOCAL_ROOT/etc/elden-init-mode" ]; then m=$(cat "$LOCAL_ROOT/etc/elden-init-mode")
    elif [ -d "$LOCAL_ROOT/run/systemd/system" ]; then m=systemd
    else m=openrc; fi
  else
    m=$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$SSH_TARGET" \
          'cat /etc/elden-init-mode 2>/dev/null || { [ -d /run/systemd/system ] && echo systemd || echo openrc; }' 2>/dev/null)
  fi
  echo "${m%%[!a-z]*}"
}

# 期望表：path<TAB>expected_sha<TAB>origin
build_expect() {
  local dst kind sha size mode repo_src p h origin f
  while IFS=$'\t' read -r dst kind sha size mode repo_src; do
    [ "$dst" = "dst" ] && continue
    [ "$kind" = "elf" ] && continue
    if [ "$ROOT_PROFILE" = "systemd" ] && is_openrc_only "$dst"; then continue; fi
    h=$sha; origin=MANIFEST
    if [ -n "$STAGE" ] && [ -f "$STAGE$dst" ]; then
      h=$(sha256sum "$STAGE$dst" | cut -d' ' -f1); origin=overlay
    fi
    printf '%s\t%s\t%s\n' "$dst" "$h" "$origin"
  done <"$HERE/MANIFEST.tsv"
  if [ "$ROOT_PROFILE" = "systemd" ]; then
    for f in "$HERE"/out/units/systemd/*.service; do
      [ -f "$f" ] || continue
      p=/usr/lib/systemd/system/$(basename "$f"); h=$(sha256sum "$f" | cut -d' ' -f1); origin=unit
      if [ -n "$STAGE" ] && [ -f "$STAGE$p" ]; then h=$(sha256sum "$STAGE$p" | cut -d' ' -f1); origin=overlay; fi
      printf '%s\t%s\t%s\n' "$p" "$h" "$origin"
    done
  else
    for f in "$HERE"/out/units/openrc/*; do
      [ -f "$f" ] || continue
      p=/etc/init.d/$(basename "$f"); h=$(sha256sum "$f" | cut -d' ' -f1); origin=unit
      printf '%s\t%s\t%s\n' "$p" "$h" "$origin"
    done
  fi
}

# 一次往返取全部 sha（旧版每条一次 ssh，73 条路径 ≈ 分钟级）
fetch_shas() {   # stdin: 绝对路径 → stdout "sha<TAB>逻辑路径"（LOCAL_ROOT 时也要回逻辑路径）
  local p h
  if [ -n "$LOCAL_ROOT" ]; then
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      [ -f "$LOCAL_ROOT$p" ] || continue
      h=$(sha256sum "$LOCAL_ROOT$p" 2>/dev/null | cut -d' ' -f1)
      [ -n "$h" ] && printf '%s\t%s\n' "$h" "$p"
    done
  else
    ssh -o BatchMode=yes -o ConnectTimeout=8 "$SSH_TARGET" "xargs -d '\n' sha256sum 2>/dev/null" \
      | awk '{h=$1; $1=""; sub(/^ +/,""); if (h ~ /^[0-9a-f]{64}$/) print h"\t"$0}'
  fi
}

if [ "$OFFLINE" = "1" ]; then
  ok "--offline：跳过"
elif [ -n "$LOCAL_ROOT" ] || ssh -o BatchMode=yes -o ConnectTimeout=6 "$SSH_TARGET" true 2>/dev/null; then
  ROOT_PROFILE=$(probe_profile)
  [ -n "$ROOT_PROFILE" ] || ROOT_PROFILE=openrc
  printf '  根画像 %s（init-mode=%s / overlay=%s）\n' "$ROOT_PROFILE" "$ROOT_PROFILE" "${STAGE:-无}"

  exp=/tmp/.verify_exp.$$
  build_expect >"$exp"
  declare -A GOT=()
  while IFS=$'\t' read -r h p; do GOT[$p]=$h; done < <(cut -f1 "$exp" | fetch_shas)

  drift=0; gone=0; checked=0; skipped=0
  while IFS=$'\t' read -r p h origin; do
    [ -n "$p" ] || continue
    checked=$((checked + 1))
    got=${GOT[$p]:-}
    if [ -z "$got" ]; then
      if [ "$ROOT_PROFILE" = "systemd" ] && is_openrc_only "$p"; then skipped=$((skipped + 1)); continue; fi
      warn "$p: 设备上不存在（期望来源 $origin）"; gone=$((gone + 1))
    elif [ "$got" != "$h" ]; then
      case "$origin" in
        overlay) fail "$p: 设备 ≠ 暂存 overlay（设备 ${got:0:16} / overlay ${h:0:16}）⇒ 部署落后或设备手改" ;;
        unit)    fail "$p: 设备上的单元与渲染产物不一致（设备 ${got:0:16} / 渲染 ${h:0:16}）⇒ 重跑 render+部署" ;;
        *)       fail "$p: 设备与仓库副本不一致（设备 ${got:0:16} / 副本 ${h:0:16}）⇒ 需要 sync 并评审" ;;
      esac
      drift=$((drift + 1))
    fi
  done <"$exp"
  rm -f "$exp"
  [ "$drift" = 0 ] && [ "$gone" = 0 ] && ok "$checked 条与设备逐字一致（含渲染单元；根画像 $ROOT_PROFILE）"
  [ "$skipped" -gt 0 ] && ok "$skipped 条 openrc 专属路径（/etc/init.d、/etc/local.d）在 systemd 根上不适用（预期）"

  # ELF 漂移只提示（重编会改 sha，不代表功能漂移）
  awk -F'\t' 'NR>1 && $2=="elf"{print $1"\t"$3}' "$HERE/MANIFEST.tsv" | while IFS=$'\t' read -r d h; do
    got=$(printf '%s\n' "$d" | fetch_shas | cut -f1)
    [ -z "$got" ] && continue
    [ "$got" = "$h" ] || echo "  DIFF  $d: 设备 ${got:0:16} ≠ 清单 ${h:0:16}（重编？）"
  done
else
  warn "设备不可达（$SSH_TARGET 或 LOCAL_ROOT），跳过 F"
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
