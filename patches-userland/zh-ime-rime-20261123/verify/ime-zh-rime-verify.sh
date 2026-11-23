#!/bin/sh
# ime-zh-rime-verify.sh — RIME 后端（A 方案）上机验证：判据 R1-1..R1-6 + 热启动 <100 ms
# 设备侧执行；只读 + 启动/停止本 lane 自己的守护。外部命令一律 timeout -k。
# 用法: sh ime-zh-rime-verify.sh [--apply]
set -u
APPLY=0; [ "${1:-}" = --apply ] && APPLY=1
U=${ELDEN_UID:-1001}
PASS=0; FAIL=0
ok()  { echo "OK   $*"; PASS=$((PASS+1)); }
bad() { echo "FAIL $*"; FAIL=$((FAIL+1)); }

echo "== R0 依赖与数据"
timeout -k 2 5 dpkg -l librime1 librime-data 2>/dev/null | grep -q '^ii' \
  && ok "librime1/librime-data 已装" || bad "缺 librime1/librime-data（apt install librime1 librime-data）"
timeout -k 2 5 test -f /usr/share/rime-data/luna_pinyin.dict.yaml \
  && ok "luna_pinyin 词库在位" || bad "/usr/share/rime-data 缺 luna_pinyin"

echo "== R1 判据主链: echo nihao | completer 出候选"
if [ "$APPLY" = 1 ]; then
  timeout -k 5 30 /usr/local/bin/librime-piped --oneshot nihao > /tmp/rime-verify.$$ 2>&1
else
  timeout -k 5 30 env ELDEN_RIME_SOCK=/run/user/$U/elden-rime.sock \
    sh -c 'echo nihao | /usr/local/bin/elden-rime-completer' > /tmp/rime-verify.$$ 2>&1
fi
N=$(grep -c . /tmp/rime-verify.$$ || true)
if [ "$N" -ge 1 ] && grep -q '你好' /tmp/rime-verify.$$; then
  ok "nihao → $N 个候选，含「你好」"
else
  bad "候选异常（$N 行，首行 $(head -1 /tmp/rime-verify.$$)）"
fi

echo "== R2 热启动 <100 ms（oneshot 第 2 次起算热，词库已编译进 user-data）"
T0=$(date +%s%N)
timeout -k 5 30 /usr/local/bin/librime-piped --oneshot nihao >/dev/null 2>&1
T1=$(date +%s%N)
T0=$(date +%s%N)
timeout -k 5 30 /usr/local/bin/librime-piped --oneshot nihao >/dev/null 2>&1
T1=$(date +%s%N)
MS=$(( (T1 - T0) / 1000000 ))
[ "$MS" -lt 100 ] && ok "热 oneshot = ${MS} ms (<100)" || bad "热 oneshot = ${MS} ms（≥100，查 user-data 是否命中缓存）"

echo "== R3 守护 + 薄客户端端到端"
if [ "$APPLY" = 1 ]; then
  timeout -k 2 5 env XDG_RUNTIME_DIR=/run/user/$U /usr/local/bin/librime-piped --idle-exit 60 >/dev/null 2>&1 &
  sleep 2
fi
timeout -k 3 10 env ELDEN_RIME_SOCK=/run/user/$U/elden-rime.sock \
  sh -c 'echo zhongwen | /usr/local/bin/elden-rime-completer' > /tmp/rime-verify2.$$ 2>&1
grep -q . /tmp/rime-verify2.$$ && ok "薄客户端经 socket 拿到候选" \
                                || bad "socket 路径无候选（守护没起或路径不一致）"
rm -f /tmp/rime-verify.$$ /tmp/rime-verify2.$$

echo "== R4 OSK 配置（R1 路线三行 gsettings）"
timeout -k 2 5 env XDG_RUNTIME_DIR=/run/user/$U \
  gsettings get sm.puri.phosh.osk completion-mode 2>/dev/null | grep -q always \
  && ok "completion-mode=always" || bad "completion-mode 非 always（OSK 平时不进补全模式）"
timeout -k 2 5 env XDG_RUNTIME_DIR=/run/user/$U \
  gsettings get sm.puri.phosh.osk.Completers default 2>/dev/null | grep -q pipe \
  && ok "Completers default=pipe" || bad "default ≠ pipe"

echo "== 结果: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = 0 ]
