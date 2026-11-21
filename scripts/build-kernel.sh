#!/bin/bash
# build-kernel.sh — rebuild kernel/DTB for TB322FC (elden), with ccache.
#
# usage:
#   scripts/build-kernel.sh                 # Image.gz + dtbs  (default)
#   scripts/build-kernel.sh Image.gz        # kernel only (skip DT)
#   scripts/build-kernel.sh dtbs            # DTB only (seconds)
#   scripts/build-kernel.sh modules         # build all =m modules
#   TARGETS="Image.gz dtbs" scripts/build-kernel.sh
#   scripts/build-kernel.sh --selftest      # 只跑符号守卫自测（合成 System.map，不编译）
#
# Env: JOBS=<n> (default nproc), CCACHE_DIR, CCACHE_MAXSIZE, SMP=<System.map 路径>.
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}

# ---------------------------------------------------------------------------
# 打包后符号守卫（FAILURE 2026-10-10；两类假判都受过：死内核放过 / 上游好件判死）
#
# 为什么要有：一份被 olddefconfig 去掉 ARCH_QCOM 的 .config 仍能编过，但产物里
# qcom 平台符号为零 ⇒ 死内核（vk81/82/83）。所以发件前断言平台真的链进去了。
#
# 三个分支（2026-11-21 补第 2 条：D5；此前只认 B5 重构名 ⇒ pristine 上游树假阳性）：
#   1) B5/daily：msm_dsi_host_bonded_cmd_{trigger,xfer}（2026-10-27 重构后对外名）
#      或 file-static 的 dsi_bonded_cmd_trigger。
#   2) 上游等价：pristine 上游树（如 7.4-rc3，未叠 patches/local/b5-resoc-20261027）
#      没有 bonded 名，但有上游 DSI 锚点（msm_dsi_host_init / msm_dsi_modeset_init / …）
#      ⇒ 视为通过。
#   3) 都没有 ⇒ DEAD（DRM_MSM 没进）。
# 语义：qcom 平台两项仍是**子串**匹配（gcc_sm8750 实际符号是 gcc_sm8750_probe）；
# DSI 项一律 ERE 且锁到「空白 + 行尾」，避免误命中更长的名字。
SYM_DSI_B5='msm_dsi_host_bonded_cmd_trigger|msm_dsi_host_bonded_cmd_xfer|dsi_bonded_cmd_trigger'
SYM_DSI_UP='msm_dsi_host_init|msm_dsi_host_modeset_init|msm_dsi_modeset_init|msm_dsi_host_xfer_commit|dsi_dev_probe'
SYM_DSI_UP_NAMES='msm_dsi_host_init msm_dsi_host_modeset_init msm_dsi_modeset_init msm_dsi_host_xfer_commit dsi_dev_probe'

# sym_hit <System.map> <ERE 备选> —— System.map 第 3 列是符号名，锁「空白 + 行尾」。
sym_hit() { grep -qE "[[:space:]]($2)\$" "$1"; }

# guard_symbols <System.map> —— 0 = 通过（分支 1/2），1 = 判死（分支 3）。
guard_symbols() {
  local smp=$1 s first=""
  if ! grep -qF 'gcc_sm8750' "$smp" || ! grep -qF 'rpmh' "$smp"; then
    echo "ERROR: qcom platform symbols (gcc_sm8750 / rpmh) MISSING in $smp -> .config lost ARCH_QCOM/DRM_MSM (olddefconfig?). This Image is DEAD (no QCOM drivers). Restore .config from $ROOT/patches/config-before-fragment-*.bak and rebuild." >&2
    return 1
  fi
  if sym_hit "$smp" "$SYM_DSI_B5"; then
    echo "[build] symbol guard OK: gcc_sm8750 / DSI bonded（旧名或 B5 重构后名）/ rpmh present in $smp"
    return 0
  fi
  for s in $SYM_DSI_UP_NAMES; do
    if sym_hit "$smp" "$s"; then first=$s; break; fi
  done
  if [ -n "$first" ]; then
    echo "[build] symbol guard OK: 上游等价 DSI 锚点（$first）+ gcc_sm8750 / rpmh present in $smp（pristine 上游树，无 B5 重构）"
    return 0
  fi
  echo "ERROR: DSI anchor MISSING in $smp —— 既无 B5 名（$SYM_DSI_B5）也无上游锚点（$SYM_DSI_UP）⇒ DRM_MSM 没编进去，This Image is DEAD。查 .config 的 CONFIG_DRM_MSM 并 restore 自 $ROOT/patches/config-before-fragment-*.bak。" >&2
  return 1
}

# 合成 System.map 三（+1 附加）场景自测；一键：bash scripts/build-kernel.sh --selftest
selftest() {
  local tmp rc pass=0 total=0 verdict
  tmp=$(mktemp -d /tmp/build-kernel-selftest.XXXXXX)
  # 场景 1：daily（B5 重构树）——同时含上游名，用来证明 B5 分支优先
  cat > "$tmp/daily.map" <<'EOF'
ffff800080010000 T start_kernel
ffff800080c30588 t gcc_sm8750_probe
ffff800080cc2068 t rpmh_rsc_probe
ffff800080c40000 T msm_dsi_host_bonded_cmd_xfer
ffff800080c40040 t dsi_bonded_cmd_trigger
ffff800080c41000 T msm_dsi_host_init
ffff800080c41100 T msm_dsi_modeset_init
EOF
  # 场景 2：pristine 上游（7.4-rc3 形态）——无 B5 名，只有上游锚点
  cat > "$tmp/upstream.map" <<'EOF'
ffff800080010000 T start_kernel
ffff800080c30588 t gcc_sm8750_probe
ffff800080c305c8 t gcc_sm8750_regs_configure
ffff800080cc2068 t rpmh_rsc_probe
ffff800080c41000 T msm_dsi_host_init
ffff800080c41100 T msm_dsi_modeset_init
ffff800080c41200 T msm_dsi_host_xfer_commit
EOF
  # 场景 3：真死内核（ARCH_QCOM 被 olddefconfig 剥掉）
  cat > "$tmp/dead.map" <<'EOF'
ffff800080010000 T start_kernel
ffff800080020000 T dump_stack
ffff800080030000 T do_exit
EOF
  # 场景 4（附加）：平台在但 DRM_MSM 丢 —— 必须仍判死（证明不是「有 gcc 就放行」）
  cat > "$tmp/nodrm.map" <<'EOF'
ffff800080010000 T start_kernel
ffff800080c30588 t gcc_sm8750_probe
ffff800080cc2068 t rpmh_rsc_probe
EOF
  run_case() { # $1=名字 $2=map $3=期望 rc
    total=$((total + 1))
    set +e
    guard_symbols "$2" >"$tmp/$1.log" 2>&1
    rc=$?
    set -e
    if [ "$rc" = "$3" ]; then pass=$((pass + 1)); verdict=PASS; else verdict=FAIL; fi
    printf '[selftest] %-9s guard rc=%s expect=%s %s\n' "$1" "$rc" "$3" "$verdict"
    sed 's/^/           | /' "$tmp/$1.log"
  }
  run_case daily    "$tmp/daily.map"    0
  run_case upstream "$tmp/upstream.map" 0
  run_case dead     "$tmp/dead.map"     1
  run_case nodrm    "$tmp/nodrm.map"    1
  rm -rf "$tmp"
  echo "== selftest $pass/$total PASS =="
  [ "$pass" = "$total" ]
}

if [ "${1:-}" = "--selftest" ]; then
  selftest
  exit $?
fi

. "$ROOT/scripts/env-build.sh"

# Guard: olddefconfig can silently drop CONFIG_ARCH_QCOM and brick the image.
grep -q '^CONFIG_ARCH_QCOM=y' "$KDIR/.config" || {
	echo "ERROR: CONFIG_ARCH_QCOM missing in .config (corrupted by olddefconfig?)" >&2
	exit 1
}

TARGETS=("${@:-Image.gz dtbs}")
[ $# -eq 0 ] && TARGETS=(Image.gz dtbs)

echo "[build] CROSS_COMPILE=$CROSS_COMPILE"
echo "[build] targets: ${TARGETS[*]}"
kbuild "${TARGETS[@]}"

ls -la "$KDIR/arch/arm64/boot/Image.gz" \
       "$KDIR/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb" 2>/dev/null || true

# Post-build symbol guard（分类逻辑见文件头 guard_symbols()）。
# SMP 可覆盖（拿既有树的 System.map 复核时不必重编）。
SMP=${SMP:-$KDIR/System.map}
if [ -f "$SMP" ]; then
  guard_symbols "$SMP" || exit 1
fi

command -v ccache >/dev/null 2>&1 && ccache -s 2>/dev/null | sed -n '1,6p' || true
