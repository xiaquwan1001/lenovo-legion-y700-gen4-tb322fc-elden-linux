#!/bin/sh
# test-selftest.sh — 本机（x86 开发机）静态自检，不需要设备。
# 用法：bash packaging/keyboard-settings/test-selftest.sh
set -u
cd "$(dirname "$0")"
FAIL=0
ok()  { echo "PASS: $*"; }
bad() { echo "FAIL: $*"; FAIL=1; }

# 1. py_compile
if python3 -m py_compile elden-keyboard-settings.py 2>/tmp/selftest-pyc.log; then
    ok "python3 -m py_compile elden-keyboard-settings.py"
else
    bad "py_compile: $(cat /tmp/selftest-pyc.log)"
fi

# 2. sh -n
if sh -n files/usr/local/sbin/elden-keyboard-apply 2>/tmp/selftest-shn.log; then
    ok "sh -n files/usr/local/sbin/elden-keyboard-apply"
else
    bad "sh -n: $(cat /tmp/selftest-shn.log)"
fi

# 3. desktop-file-validate（没装就跳过并说明）
if command -v desktop-file-validate >/dev/null 2>&1; then
    if desktop-file-validate elden-keyboard-settings.desktop 2>/tmp/selftest-dfv.log; then
        ok "desktop-file-validate"
    else
        bad "desktop-file-validate: $(cat /tmp/selftest-dfv.log)"
    fi
else
    echo "SKIP: desktop-file-validate 未安装（本机无该工具，跳过）"
fi

# 4. conf 解析 + apply 幂等性测试（用临时沙盒目录，不碰真 /etc）
SB=$(mktemp -d) || exit 1
trap 'rm -rf "$SB"' EXIT
cp files/etc/elden-keyboard.conf "$SB/elden-keyboard.conf"
cat > "$SB/environment" <<'EOF'
PATH=/usr/local/bin:/usr/bin:/bin
ELDEN_OSK_HAPTIC_MS=99
ELDEN_OSK_HAPTIC_MAG=0x2000
EOF
sed -e "s|CONF=/etc/elden-keyboard.conf|CONF=$SB/elden-keyboard.conf|" \
    -e "s|ENV=/etc/environment|ENV=$SB/environment|" \
    files/usr/local/sbin/elden-keyboard-apply > "$SB/apply"
chmod +x "$SB/apply"

# --check 只读：不改变 environment
before=$(md5sum "$SB/environment" | cut -d' ' -f1)
"$SB/apply" --check > "$SB/check.out" 2>&1 || bad "--check 非零退出"
after=$(md5sum "$SB/environment" | cut -d' ' -f1)
[ "$before" = "$after" ] && ok "--check 只读不改文件" || bad "--check 改了文件"
grep -q "ELDEN_OSK_HAPTIC_MS=30" "$SB/check.out" || bad "--check 未解析出 HAPTIC_MS=30"

# 真跑一次 + 幂等（跑两遍结果一致）
"$SB/apply" > "$SB/run1.out" 2>&1 || bad "apply 第一次非零退出"
h1=$(md5sum "$SB/environment" | cut -d' ' -f1)
"$SB/apply" > "$SB/run2.out" 2>&1 || bad "apply 第二次非零退出"
h2=$(md5sum "$SB/environment" | cut -d' ' -f1)
[ "$h1" = "$h2" ] && ok "幂等：两遍 apply 结果一致" || bad "不幂等"
grep -q '^PATH=/usr/local/bin:/usr/bin:/bin$' "$SB/environment" \
    && ok "保留无关行 PATH" || bad "丢了无关行 PATH"
grep -q '^ELDEN_OSK_HAPTIC_MS=30$' "$SB/environment" \
    && ok "HAPTIC_MS=30 并入且覆盖旧值 99" || bad "HAPTIC_MS 并入失败"
grep -q '^ELDEN_OSK_HAPTIC_MAG=0x3333$' "$SB/environment" \
    && ok "HAPTIC_MAG=0x3333 并入" || bad "HAPTIC_MAG 并入失败"
grep -qv 'ELDEN_OSK_HAPTIC_MS=99' "$SB/environment" \
    && ok "旧值 99 已被替换" || bad "旧值 99 残留"

echo "-----"
[ "$FAIL" -eq 0 ] && echo "SELFTEST: ALL GREEN" || { echo "SELFTEST: FAILURES"; exit 1; }
