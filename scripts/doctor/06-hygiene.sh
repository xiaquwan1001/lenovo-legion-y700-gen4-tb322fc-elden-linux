#!/bin/bash
# 06-hygiene.sh — §6 静态卫生（防造轮回退）：设备锁单一真源 + bashism + 死脚本。
# 依据：.pi/plans/2026-10-07-造轮子审计.md（P0 防回归门）
#
# 2026-11-05 提速：bashism/死脚本扫描移进 scripts/static-scan.py（语料改 git 纳管文本，
# 死脚本用 grep -F 一次扫完）。实测本节 3.75 s → 0.11 s，判据不变。
. "$(dirname "$0")/_lib.sh"

SCAN="${ELF_STATIC_SCAN:-$HELPERS/static-scan.py}"

section '6. 静态卫生（重复 / 死代码 / bashism）'

# 6a. 设备锁必须单一真源：除 lib-device-lock.sh 外不得内联锁块
# 排除项 = 真源本身 + 本检查器自己（它把标记名当**搜索模式**写着，必然自命中）。
lockdup=$(grep -rl 'DEVICE_LOCK_HELD' --include='*.sh' scripts cycle.sh iterate.sh 2>/dev/null \
  | grep -v 'lib-device-lock.sh' | grep -v 'check-doctor.sh' | grep -v 'scripts/doctor/' || true)
if [ -n "$lockdup" ]; then
  bad "设备锁块被复制（应只用 scripts/lib-device-lock.sh）: $(echo $lockdup | tr '\n' ' ')"
else
  ok "设备锁单一真源（lib-device-lock.sh）"
fi

# 6b/6c. bashism 与死脚本
_static=$(python3 "$SCAN" --root "$ROOT" --tsv 2>/dev/null)
while IFS=$'\t' read -r st msg; do
  case "$st" in
    BASHISM) [ "$msg" = "-" ] && ok "#!/bin/sh 脚本无常见 bashism" || warnf "bashism 风险（改 #!/bin/bash 或改写法）: $msg" ;;
    DEAD)    [ "$msg" = "-" ] && ok "scripts/*.sh 无死脚本" || warnf "疑似死脚本（无任何活跃引用，核实后删/标 legacy）: $msg" ;;
  esac
done <<< "$_static"
[ -z "$_static" ] && warnf "静态扫描无输出（scripts/static-scan.py 缺失或失败）"
exit 0
