#!/bin/bash
# test-lib-wait.sh — scripts/lib-wait.sh + lib-ssh.sh 的自检（不需要设备）
#
# 做法：在 $PATH 前面放一个**假的 ssh/fastboot/adb**（stub），由环境变量控制它们的回答；
# 这样就能在没有板子的情况下验证「等待语义」，尤其是最难用真机复现的两条：
#   ① 先判后睡：设备立刻可用时不应付出首拍延迟；
#   ② 换代判据：重启命令刚发出去、旧系统还在答 ssh 时，**不得**判定为「已起来」。
#
# 用法： scripts/test-lib-wait.sh        # 退出码 0 = 全绿
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
STUB=$(mktemp -d)
TAB_CTL=$(mktemp -d)
trap 'rm -rf "$STUB" "$TAB_CTL"' EXIT

fail=0
ok()   { printf '  [ok]   %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

# ---------------------------------------------------------------- stub：假 ssh
# 行为：把最后一个参数当远端命令**在本机执行**；boot_id 从 $TAB_CTL/boot_id 读，
# uptime 从 $TAB_CTL/uptime 读；$TAB_CTL/down 存在时模拟「不可达」（非 0 退出）。
cat > "$STUB/ssh" <<'EOS'
#!/bin/bash
echo x >> "$TAB_CTL/ssh_calls"
[ -e "$TAB_CTL/down" ] && exit 255
cmd=${!#}
# 把远端路径换成本地控制目录（模拟 /proc/sys/kernel/random/boot_id 与 /proc/uptime）
cmd=${cmd//\/proc\/sys\/kernel\/random\/boot_id/$TAB_CTL\/boot_id}
cmd=${cmd//\/proc\/uptime/$TAB_CTL\/uptime}
exec bash -c "$cmd"
EOS
cat > "$STUB/fastboot" <<'EOS'
#!/bin/bash
[ -e "$TAB_CTL/fb" ] && { echo "abc123	fastboot"; exit 0; }
exit 1
EOS
cat > "$STUB/adb" <<'EOS'
#!/bin/bash
# 只认 `adb -s <ser> get-state`：序列号不对就回 unknown（模拟 PITFALLS #371 场景）
if [ "$1" = "-s" ] && [ "$2" = "$TAB_CTL-ser" ] && [ "$3" = "get-state" ] && [ -e "$TAB_CTL/adb" ]; then
  echo device; exit 0
fi
echo unknown
EOS
chmod +x "$STUB"/*
export PATH="$STUB:$PATH"
export TAB_CTL
export TAB="root@127.0.0.1"

echo "A" > "$TAB_CTL/boot_id"
echo "500" > "$TAB_CTL/uptime"

# shellcheck disable=SC1091
. "$ROOT/scripts/lib-wait.sh"
. "$ROOT/scripts/lib-ssh.sh"

now() { date +%s%N; }
ms() { awk -v a="$1" -v b="$2" 'BEGIN{printf "%d", (b-a)/1000000}'; }

echo "== lib-ssh =="
[ "$(S 'echo up' 5)" = up ] && ok "S 执行远端命令" || bad "S 执行远端命令"
out=$(S_kv 'id=cat /proc/sys/kernel/random/boot_id' 'up=cut -d. -f1 /proc/uptime')
[ "$(S_kv_get "$out" id)" = A ] && ok "S_kv 一次往返取多键（id=A）" || bad "S_kv 取键失败: $out"
[ "$(S_kv_get "$out" up)" = 500 ] && ok "S_kv 第二键正确（up=500）" || bad "S_kv 第二键错: $out"
printf '%s' "$SSH_OPTS" | grep -q 'BatchMode=yes' && ok "SSH_OPTS 默认带 BatchMode=yes（不会卡在密码提示）" || bad "SSH_OPTS 缺 BatchMode"
S_alive && ok "S_alive 判定可达" || bad "S_alive"

echo "== lib-wait：先判后睡 =="
t0=$(now); wait_until "立刻就绪" 10 true; t1=$(now)
[ $(( $(ms "$t0" "$t1") )) -lt 250 ] && ok "就绪时不付出首拍延迟（$(ms "$t0" "$t1") ms）" || bad "首拍仍要等待（$(ms "$t0" "$t1") ms）"

echo "== lib-wait：超时 =="
t0=$(now); WAIT_QUIET=1 wait_until "永不就绪" 1 false; rc=$?; t1=$(now)
[ "$rc" = 1 ] && ok "超时返回非 0" || bad "超时应返回非 0（实际 $rc）"
d=$(ms "$t0" "$t1")
[ "$d" -ge 900 ] && [ "$d" -lt 2500 ] && ok "超时时长合理（${d} ms ≈ 1 s 预算）" || bad "超时时长异常（${d} ms）"

echo "== lib-wait：换代判据（关键回归）=="
# 场景：ssh 一直答（旧系统还没重启），但 boot_id 未变 ⇒ 不得判「已起来」
wait_boot_capture
t0=$(now)
( sleep 1.2; echo "B" > "$TAB_CTL/boot_id"; echo "1" > "$TAB_CTL/uptime" ) &
bg=$!
WAIT_QUIET=1 wait_reboot wa_ssh_alive 10; rc=$?
t1=$(now); wait "$bg"
d=$(ms "$t0" "$t1")
[ "$rc" = 0 ] && ok "换代后返回 0（${d} ms）" || bad "换代后应返回 0（rc=$rc）"
[ "$d" -ge 1000 ] && ok "boot_id 未变期间**没有**误判成功（等到 ${d} ms 才返回）" || bad "误判：boot_id 未变就返回成功（${d} ms）"
[ "$(cat "$TAB_CTL/boot_id")" = B ] && ok "boot_id 已切到 B" || bad "boot_id 未切"

echo "== lib-wait：新鲜启动判据 =="
echo "900" > "$TAB_CTL/uptime"
WAIT_QUIET=1 wait_fresh_boot 1 180 && bad "旧系统（uptime=900）不该算新鲜启动" || ok "uptime 大时正确拒绝（旧系统还在答）"
echo "20" > "$TAB_CTL/uptime"
WAIT_QUIET=1 wait_fresh_boot 5 180 && ok "uptime 小时认作本次开机" || bad "uptime=20 应判为新鲜启动"

echo "== lib-wait：fastboot / adb wrapper =="
touch "$TAB_CTL/fb"
WAIT_QUIET=1 wait_fastboot 5 && ok "wait_fastboot 认到设备" || bad "wait_fastboot"
rm -f "$TAB_CTL/fb"
WAIT_QUIET=1 wait_fastboot 1 && bad "fastboot 不在时不应返回 0" || ok "无 fastboot 时正确失败"
touch "$TAB_CTL/adb"
WAIT_QUIET=1 wait_adb "$TAB_CTL-ser" 5 && ok "wait_adb 认到正确序列号" || bad "wait_adb"
WAIT_QUIET=1 wait_adb "wrong-serial" 1 && bad "wait_adb 不该认可错误序列号（PITFALLS #371）" || ok "wait_adb 拒绝错误序列号"

echo "== lib-boot-ready：一次往返 + 各判据 =="
# shellcheck disable=SC1091
. "$ROOT/scripts/lib-boot-ready.sh"
echo "20" > "$TAB_CTL/uptime"; rm -f "$TAB_CTL/ssh_calls"
( BOOT_READY_ALLOW_NODESKTOP=1 BOOT_READY_MIN_UPTIME=10 boot_ready_or_die ) >/dev/null 2>&1
rc=$?
calls=$(wc -l < "$TAB_CTL/ssh_calls" 2>/dev/null || echo 0)
[ "$rc" = 0 ] && ok "就绪时放行（uptime=20）" || bad "就绪时应放行（rc=$rc）"
[ "$calls" = 1 ] && ok "就绪判定只发 1 条 ssh（旧版 4 条，弱链路省 3 个往返）" || bad "就绪判定发了 $calls 条 ssh（应为 1）"
echo "600" > "$TAB_CTL/uptime"
( BOOT_READY_ALLOW_NODESKTOP=1 BOOT_READY_MIN_UPTIME=1200 boot_ready_or_die ) >/dev/null 2>&1
[ $? = 4 ] && ok "uptime 未达门槛时拒绝（exit 4）" || bad "uptime 未达门槛时应 exit 4"
echo "20" > "$TAB_CTL/uptime"
( BOOT_READY_MIN_UPTIME=90 boot_ready_or_die ) >/dev/null 2>&1
[ $? = 4 ] && ok "桌面未起（无 phoc/phosh）时拒绝（exit 4）" || bad "桌面未起时应 exit 4"
touch "$TAB_CTL/down"
( BOOT_READY_ALLOW_NODESKTOP=1 boot_ready_or_die ) >/dev/null 2>&1
[ $? = 3 ] && ok "SSH 不通时拒绝（exit 3）" || bad "SSH 不通时应 exit 3"
rm -f "$TAB_CTL/down"

echo
if [ "$fail" = 0 ]; then echo "== test-lib-wait: ALL PASS =="; exit 0; fi
echo "== test-lib-wait: FAIL=$fail =="; exit 1
