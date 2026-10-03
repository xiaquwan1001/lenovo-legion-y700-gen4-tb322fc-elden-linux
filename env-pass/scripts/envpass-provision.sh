#!/bin/bash
# envpass-provision.sh — 把「过环境」隐藏栈装到**任一** stock+root 单元（A17，幂等）
#
# 设备无关（设备等价原则）：不绑定 U1/具体 SN；按**当前状态**预检。
# 可重复执行：产物缺失自动 repack；已装模块跳过；全程验证不看"传输完成"。
#
# 用法（主机）：
#   bash env-pass/scripts/envpass-provision.sh [--serial <adb序列号>] [--check]
#   --check   只做预检与产物校验，不推送不安装（干跑）
#
# 前置（任一单元，stock Android + root）：
#   - adb 可见设备（只一台时可省 --serial）
#   - KernelSU 已 root（/data/adb/ksu/bin/ksud 在）
# 装的内容（env-pass/）：
#   - 4 个 KSU 模块（deflate 重打包：Zygisk-Next / Shamiko(-patched) / PlayIntegrityFork / TrickyStore）
#   - envpass_props 伪装属性模块
#   - Shamiko whitelist 模式 + KSU selinux_hide
set -eu
cd "$(dirname "$0")/../.."   # → repo 根

SERIAL=""
CHECK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --serial) SERIAL="$2"; shift 2 ;;
    --check)  CHECK=1; shift ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done
ADB=(adb)
[ -n "$SERIAL" ] && ADB=(adb -s "$SERIAL")

fail(){ echo "[envpass] ✗ $*"; exit 1; }
ok(){ echo "[envpass] ✓ $*"; }

say(){ echo "[envpass] $*"; }

# ---------- 1. 本地产物校验（缺失自动 repack） ----------
say "1) 校验本地产物"
ASSETS=env-pass/assets
REPACKED=env-pass/assets/repacked
mkdir -p "$REPACKED"
MODULES="Zygisk-Next-1.5.0 Shamiko-v1.2.5-414 PlayIntegrityFork-v18 TrickyStore-v1.4.1"
for m in $MODULES; do
  if [ ! -f "$REPACKED/$m-deflate.zip" ]; then
    if [ -f "$ASSETS/$m.zip" ]; then
      say "  $m-deflate.zip 缺失 → repack"
      [ $CHECK = 1 ] || python3 env-pass/tools/repack_module_zip.py "$ASSETS/$m.zip" "$REPACKED/$m-deflate.zip"
    else
      fail "缺 $ASSETS/$m.zip（源 zip 不在，无法 repack）"
    fi
  else
    say "  $m-deflate.zip 在"
  fi
done
# Shamiko 必须 -patched（customize.sh 的 KSU_KERNEL_VER_CODE 校验会误 abort）
if [ ! -f "$REPACKED/Shamiko-v1.2.5-414-deflate-patched.zip" ] && [ -f "$REPACKED/Shamiko-v1.2.5-414-deflate.zip" ]; then
  say "  ⚠ Shamiko 无 -patched 版：customize.sh 的 KSU 版本校验可能 abort（见 PITFALLS 过环境节）"
fi
[ -f env-pass/modules/envpass_props/module.prop ] || fail "env-pass/modules/envpass_props/module.prop 不在"
ok "本地产物齐"

[ $CHECK = 1 ] && { say "--check 干跑结束（不推送不安装）"; exit 0; }

# ---------- 2. 设备预检（状态 = stock+root，与机器身份无关） ----------
say "2) 设备预检"
DEV_COUNT=$("${ADB[@]}" devices | grep -cw 'device$')
[ "$DEV_COUNT" -ge 1 ] || fail "adb 无在线设备（--serial 指定?）"
"${ADB[@]}" get-state >/dev/null 2>&1 || fail "设备不在 device 态"
# 是本机型（TB322FC 系）——按状态预检，不是绑机
PRODUCT=$("${ADB[@]}" shell getprop ro.product.product 2>/dev/null | tr -d '\r')
HW=$("${ADB[@]}" shell getprop ro.boot.hwboardid 2>/dev/null | tr -d '\r')
case "$HW" in
  TB322FC*) ok "机型匹配: $HW (product=$PRODUCT)" ;;
  *) fail "hwboardid=$HW 不是 TB322FC 系——不在此设备上装" ;;
esac
# root 可用（单条简单命令，避免 adb shell su -c 复合命令被吞）
SU_ID=$("${ADB[@]}" shell su -c id 2>/dev/null | tr -d '\r')
echo "$SU_ID" | grep -q 'uid=0' || fail "root 不可用（su -c id = '$SU_ID'）"
ok "root 可用"
KSUD=$("${ADB[@]}" shell su -c ls /data/adb/ksu/bin/ksud 2>/dev/null | tr -d '\r')
[ "$KSUD" = "/data/adb/ksu/bin/ksud" ] || fail "ksud 不在（KernelSU 未装?）"
ok "ksud 在"

# ---------- 3. 推送 env-pass 树 ----------
say "3) 推送 env-pass → /data/local/tmp/envpass"
"${ADB[@]}" shell mkdir -p /data/local/tmp/envpass >/dev/null 2>&1 || true
"${ADB[@]}" push -q "$REPACKED"/. /data/local/tmp/envpass/ >/dev/null
"${ADB[@]}" push -q env-pass/modules/envpass_props /data/local/tmp/envpass/ >/dev/null 2>&1 || \
  "${ADB[@]}" push -q env-pass/modules/envpass_props/. /data/local/tmp/envpass/envpass_props/ >/dev/null
"${ADB[@]}" push -q env-pass/scripts/envpass-ondevice.sh /data/local/tmp/envpass/ >/dev/null
# 读回校验（不看"传输完成"）
N_LOCAL=$(ls "$REPACKED"/*.zip | wc -l)
N_REMOTE=$("${ADB[@]}" shell ls /data/local/tmp/envpass/*.zip 2>/dev/null | wc -l)
[ "$N_REMOTE" -ge "$N_LOCAL" ] || fail "推送数不符: local=$N_LOCAL remote=$N_REMOTE"
ok "推送并读回校验（zip 数 $N_REMOTE ≥ $N_LOCAL）"

# ---------- 4. 执行（设备端脚本单条命令，幂等） ----------
say "4) 执行 envpass-ondevice.sh"
"${ADB[@]}" shell su -c "sh /data/local/tmp/envpass/envpass-ondevice.sh"

# ---------- 5. 完成后独立验证（不信任脚本输出） ----------
say "5) 独立验证"
sleep 2
MODS=$("${ADB[@]}" shell su -c ls /data/adb/modules/ 2>/dev/null | tr -d '\r')
say "  /data/adb/modules/: $MODS"
echo "$MODS" | grep -q 'envpass_props' && ok "props 模块已装" || fail "props 模块未装"
VP=$("${ADB[@]}" shell getprop ro.boot.verifiedbootstate 2>/dev/null | tr -d '\r')
say "  ro.boot.verifiedbootstate=$VP（resetprop 预览后值）"
say "done。重启后 Zygisk 生效；复跑本脚本安全（幂等）。"
