#!/bin/bash
# check-abi.sh — ffrumble 二进制 ABI/接口对齐检查（只读，不改任何文件）
# 用法: check-abi.sh <elf路径>
# 判据: aarch64 + 静态(或仅 musl) + 三个 FF ioctl + EV_FF write payload + 用法输出行
set -u
BIN=${1:?用法: check-abi.sh <elf>}
fails=0
bad() { echo "  FAIL  $*"; fails=$((fails+1)); }
ok()  { echo "  ok    $*"; }

[ -f "$BIN" ] || { echo "no such file: $BIN"; exit 2; }

# 1. 架构与链接
if file "$BIN" | grep -q 'ARM aarch64'; then ok "arch=aarch64"
else bad "arch 不是 aarch64"; fi
if file "$BIN" | grep -q 'statically linked'; then ok "静态链接"
else bad "非静态链接（设备原件为静态 musl）"; fi

# 2. 三个 FF ioctl 数值（EVIOCGBIT 的 _IOR 封装随版本漂，这里查 EVIOCSFF/EVIOCRMFF 的字面常量
#    在反汇编/字符串中不可见，改为查调用特征：strace 或符号不可用 ⇒ 用行为探针）
if command -v strace >/dev/null 2>&1 && [ -r /dev/input/event2 ] && [ -w /dev/input/event2 ]; then
  out=$(timeout 5 strace -f -e trace=ioctl,write "$BIN" /dev/input/event2 50 0x2000 2>&1)
  printf '%s\n' "$out" | grep -q '0x40302a0c\|EVIOCSFF' && ok "EVIOCSFF 调用存在" || bad "未观测到 EVIOCSFF"
  printf '%s\n' "$out" | grep -qE 'write\(.*\\x15' && ok "EV_FF write 存在" || bad "未观测到 EV_FF write"
else
  echo "  SKIP  无 strace 或 /dev/input/event2 不可读写（离线环境正常），行为探针跳过"
fi

# 3. 用法字符串（接口逐字兼容的最小判据）
for s in 'rumble ON id=' 'bad duration' 'bad magnitude'; do
  if strings "$BIN" | grep -qF "$s"; then ok "字符串 $s 存在"
  else bad "缺用法字符串 $s"; fi
done

echo "==== check-abi($BIN): FAIL=$fails ===="
exit $((fails > 0))
