#!/usr/bin/env bash
# check-userland-mirror.sh — 用户态镜像一致性门（arch-audit-20261127 A9/A10）
#
# 契约：packaging/elden-userland/files/** = 设备逐字快照（sync-from-device.sh 写入，禁止手改）；
#       scripts/** 与 rootfs/persistent-overlay/** = 权威源。同名副本应当同 sha；
#       同名不同 sha = 漂移（DRIFT）。漂移是否允许 = 白名单（待用户裁定权威归属）。
#
# 用法：
#   bash scripts/check-userland-mirror.sh [--check]   默认：只读比对，三态汇总
#   bash scripts/check-userland-mirror.sh --diff <名>  逐字 diff 一组漂移（按文件名）
#   bash scripts/check-userland-mirror.sh --selftest   临时目录造正/反样本自检
#
# 退出码（三态）：
#   0 = 全部同名副本同 sha，或漂移全部在白名单内（记 WARN）
#   1 = 存在白名单外的漂移，或已配对(同 sha)的对变成了不同内容
#   2 = SKIP（packaging/ 或 files/ 缺失、缺 sha256sum）—— SKIP 不得计成 PASS
#
# 只读保证：--check / --diff 不写任何文件（diff 走管道，sha 走内存）。
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
FILES_DIR="$REPO/packaging/elden-userland/files"
POOL_DIRS=("$REPO/scripts" "$REPO/rootfs/persistent-overlay" "$REPO/initramfs")

# ---------------------------------------------------------------------------
# 漂移白名单（按文件名）。每条都必须写「待用户裁定权威归属」。
# 判定依据：arch-audit-20261127.md §2.4 的 13 组同名不同内容（slot-attr.py 在
# files 内部 bin/sbin 两份同 sha，故 14 个漂移对 = 13 组）。
# 同内容对若日后变成不同内容而名字不在此表 ⇒ 直接 FAIL（防门空转）。
# ---------------------------------------------------------------------------
# 2026-11-27 已逐组裁定（13 组 → 全部同 sha；判据与证据 = reports/userland-mirror-adjudication-20261127.md）：
#   方向 A（scripts/ 权威 → files/ 刷成部署源，设备侧仍是旧版待部署）= scale.sh / slot-attr.py /
#     ath12k-load.sh / charge-watch.sh / openrc-enable.sh / q28-watchdog.sh / sleep-{bisect,cumulative}.sh；
#   方向 B（files/ == 设备，已上机验证的更新件回灌权威源）= net-up.sh / time-sync.sh /
#     q28-boot-watchdog.sh / camera-modules-load.sh / init（三处同 sha：files = initramfs = overlay）。
# 保留白名单条目：`sync-from-device.sh` 会把 files/ 拉回设备现态（方向 A 的那几件设备还是旧版），
# 届时应为 WARN「设备待部署」而不是 FAIL；同条目若再次漂移仍带着这条理由，人一眼能认出是已知面。
WHITELIST=(
  "init|files/init ↔ rootfs/persistent-overlay/init ↔ initramfs/init|已裁定 2026-11-27：SSOT = initramfs/init（== 设备 47af5f7d），overlay 副本已回灌同 sha；再漂移即 FAIL 面"
  "scale.sh|files/usr/local/bin ↔ scripts/|已裁定：scripts/ 权威（含 WAYLAND_DISPLAY + 非整数 scale 警告），设备待部署"
  "slot-attr.py|files/usr/local/{bin,sbin} ↔ scripts/|已裁定：scripts/ 权威（LUN 归属闸），设备待部署；bin/sbin 两份同步"
  "ath12k-load.sh|files/usr/local/sbin ↔ scripts/|已裁定：scripts/ 为 RETIRED 存根（真源 ath12k-retry.sh），设备旧版待清"
  "camera-modules-load.sh|files/usr/local/sbin ↔ scripts/|已裁定：files/ == 设备（带 readlink -f），已回灌 scripts/"
  "charge-watch.sh|files/usr/local/sbin ↔ scripts/|已裁定：scripts/ == 设备（sag guard 版，2026-11-26 已装），files/ 已刷成部署源"
  "net-up.sh|files/usr/local/sbin ↔ scripts/|已裁定：files/ == 设备（wifi_iface() 动态探测），已回灌 scripts/（旧 scripts 版写死 wlan0）"
  "openrc-enable.sh|files/usr/local/sbin ↔ scripts/|已裁定：scripts/ 权威（wifi-scan-refresh 进 DEFAULT），设备待部署（OpenRC 期件）"
  "q28-boot-watchdog.sh|files/usr/local/sbin ↔ rootfs/persistent-overlay/|已裁定：files/ == 设备（cardN 判据），已回灌 overlay"
  "q28-watchdog.sh|files/usr/local/sbin ↔ scripts/|已裁定：scripts/ 权威（2026-11-17 版），设备待部署"
  "sleep-bisect.sh|files/usr/local/sbin ↔ scripts/|已裁定：scripts/ 权威（LEGACY 头注），设备待部署"
  "sleep-cumulative.sh|files/usr/local/sbin ↔ scripts/|已裁定：scripts/ 权威（LEGACY 头注），设备待部署"
  "time-sync.sh|files/usr/local/sbin ↔ scripts/|已裁定：files/ == 设备（flock + 12×20 s 重试 + HTTP Date 兜底），已回灌 scripts/"
  "usb-gadget|files/usr/local/sbin ↔ initramfs/|已裁定 2026-11-27：initramfs/usb-gadget 权威（含 acm.GS1 OOB shell），files/ 已刷新为部署源；设备 GS1 尚未激活（/sys/class/tty 只有 1 个 ttyGS）"
)

wl_lookup() { # $1=文件名 → 命中打印表项，否则空
  local e
  for e in "${WHITELIST[@]}"; do
    [ "${e%%|*}" = "$1" ] && { printf '%s' "$e"; return 0; }
  done
  return 1
}

skip() { echo "SKIP: $*"; exit 2; }

collect_pool() { # 同名候选（相对 REPO 的路径）
  local n=$1 p
  for d in "${POOL_DIRS[@]}"; do
    [ -d "$d" ] || continue
    while IFS= read -r p; do printf '%s\n' "${p#$REPO/}"; done \
      < <(find "$d" -type f -name "$n")
  done
}

do_check() {
  [ -d "$FILES_DIR" ] || skip "缺 $FILES_DIR（未跑 sync-from-device.sh？）"
  command -v sha256sum >/dev/null 2>&1 || skip "缺 sha256sum"

  local ok=0 warn=0 fail=0 unpaired=0
  local first_fail=""
  printf '== 用户态镜像一致性门（files/** ↔ scripts/** + rootfs/persistent-overlay/**）==\n'

  local f n h1 c cp hc status entry
  while IFS= read -r f; do
    n=$(basename "$f")
    h1=$(sha256sum "$f" | cut -d' ' -f1)
    cands=$(collect_pool "$n")
    if [ -z "$cands" ]; then
      unpaired=$((unpaired + 1))
      continue
    fi
    status="none"
    for cp in $cands; do
      hc=$(sha256sum "$REPO/$cp" | cut -d' ' -f1)
      if [ "$hc" = "$h1" ]; then status="same"; break; fi
    done
    if [ "$status" = "same" ]; then
      ok=$((ok + 1))
      continue
    fi
    # 存在同名副本但全部不同 sha ⇒ 漂移
    entry=$(wl_lookup "$n") || entry=""
    if [ -n "$entry" ]; then
      warn=$((warn + 1))
      printf '  [warn] DRIFT(白名单) %s：files 副本 vs %s（%s）\n' \
        "$n" "$(echo "$cands" | tr '\n' ' ')" "${entry#*|}"
    else
      fail=$((fail + 1))
      [ -z "$first_fail" ] && first_fail="$n"
      printf '  [FAIL] DRIFT(未登记) %s：files 副本 vs %s 内容不同且不在白名单\n' \
        "$n" "$(echo "$cands" | tr '\n' ' ')"
    fi
  done < <(find "$FILES_DIR" -type f ! -name '*.pyc' ! -path '*__pycache__*')

  printf '\n汇总：同 sha 配对 %d ｜ 白名单漂移(WARN) %d ｜ 白名单外漂移(FAIL) %d ｜ 设备专有件(无副本) %d\n' \
    "$ok" "$warn" "$fail" "$unpaired"
  printf '退出码：0=配对/已豁免 1=未登记漂移 2=SKIP（本次见上）\n'
  if [ "$fail" -gt 0 ]; then
    printf '首个未登记漂移：%s（用 --diff %s 看差异；裁定后加进 WHITELIST 并注明归属）\n' "$first_fail" "$first_fail"
    exit 1
  fi
  exit 0
}

do_diff() {
  local n=$1
  [ -d "$FILES_DIR" ] || skip "缺 $FILES_DIR"
  local f cands cp found=0
  f=$(find "$FILES_DIR" -type f -name "$n" | head -1)
  [ -n "$f" ] || { echo "files/ 下没有 $n"; exit 2; }
  cands=$(collect_pool "$n")
  [ -n "$cands" ] || { echo "$n 在 scripts//rootfs/persistent-overlay/ 无同名副本（设备专有件）"; exit 2; }
  for cp in $cands; do
    if cmp -s "$f" "$REPO/$cp"; then
      echo "== $n：与 $cp 同 sha（无差异）"
    else
      found=1
      echo "== diff files/$n vs $cp =="
      diff -u "$f" "$REPO/$cp" || true
    fi
  done
  exit $found   # 1=确有漂移，便于脚本化
}

do_selftest() {
  local T
  T=$(mktemp -d /tmp/mirror-selftest.XXXXXX) || { echo "SKIP: mktemp 失败"; exit 2; }
  trap 'rm -rf "$T"' EXIT
  mkdir -p "$T/packaging/elden-userland/files/etc" "$T/scripts" "$T/rootfs/persistent-overlay"
  # 正样本 1：同 sha 配对
  echo same-a > "$T/packaging/elden-userland/files/etc/a.sh"
  echo same-a > "$T/scripts/a.sh"
  # 正样本 2：无副本（设备专有件，合法）
  echo device-only > "$T/packaging/elden-userland/files/etc/only-on-device.sh"
  # 反样本 1：同名不同内容且不在白名单 ⇒ 必须 FAIL
  echo packaged > "$T/packaging/elden-userland/files/etc/rogue.sh"
  echo scripted > "$T/scripts/rogue.sh"
  # 反样本 2：白名单内漂移 ⇒ 只 WARN，整门仍 PASS（exit 0）
  echo packaged > "$T/packaging/elden-userland/files/etc/charge-watch.sh"
  echo scripted > "$T/scripts/charge-watch.sh"

  # 用受控副本跑本脚本（替换 ROOT 指向临时树）
  local me="$REPO/scripts/check-userland-mirror.sh"
  sed "s|^REPO=.*|REPO=$T|" "$me" > "$T/gate.sh"

  local out rc
  out=$(bash "$T/gate.sh" --check 2>&1); rc=$?
  echo "--- selftest 反样本（未登记漂移 rogue.sh + 白名单漂移 charge-watch.sh）exit=$rc ---"
  echo "$out"
  if [ "$rc" != 1 ] || ! grep -q '\[FAIL\].*rogue' <<<"$out" || \
     ! grep -q '\[warn\].*charge-watch' <<<"$out"; then
    echo "SELFTEST FAIL：反样本未按预期 FAIL(1)"; exit 1
  fi

  # 修好 rogue.sh ⇒ 必须 PASS(0)，白名单漂移仍 WARN
  echo packaged > "$T/scripts/rogue.sh"
  out=$(bash "$T/gate.sh" --check 2>&1); rc=$?
  echo "--- selftest 正样本（rogue.sh 修成同 sha）exit=$rc ---"
  echo "$out"
  if [ "$rc" != 0 ] || ! grep -q '白名单外漂移(FAIL) 0' <<<"$out" || \
     ! grep -q '白名单漂移(WARN) 1' <<<"$out"; then
    echo "SELFTEST FAIL：正样本未按预期 PASS(0)"; exit 1
  fi
  echo "SELFTEST OK：反样本 FAIL=1 / 正样本 PASS=0，退出码符合契约"
  exit 0
}

case "${1:---check}" in
  --check) do_check ;;
  --diff)  [ -n "${2:-}" ] || { echo "用法：$0 --diff <文件名>"; exit 2; }; do_diff "$2" ;;
  --selftest) do_selftest ;;
  *) echo "用法：$0 [--check|--diff <名>|--selftest]"; exit 2 ;;
esac
