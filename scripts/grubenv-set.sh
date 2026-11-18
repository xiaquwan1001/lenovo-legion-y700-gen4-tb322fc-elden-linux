#!/bin/bash
# grubenv-set.sh — 在**设备**上直接改 GRUB 的 grubenv（不依赖设备装 grub-editenv）
#
# 为什么：ESP 的嵌入菜单 GRUB 每次开机 `load_env` 读 linux17 的 /boot/grub/grubenv，
# 所以「用哪个臂」可以只改这个 1024 字节的文件，不必重打 EFI（Q28 冷起 A/B 就是这么切臂的）。
# grubenv 格式：若干 `key=value\n`，其余用 '#' 填满到 1024 B（GRUB 自己的 save_env 也这么写）。
#
# 用法（主机侧）：
#   scripts/grubenv-set.sh elden_arm=1
#   scripts/grubenv-set.sh elden_arm=0 elden_grub_log=reset
#   scripts/grubenv-set.sh --show
# 可选：DEV=root@192.168.7.1  GRUBENV=/boot/grub/grubenv
set -uo pipefail
DEV=${DEV:-root@192.168.7.1}
ENVF=${GRUBENV:-/boot/grub/grubenv}
SSHOPT=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=8)

if [ $# -eq 0 ] || [ "$1" = "--show" ]; then
	ssh "${SSHOPT[@]}" "$DEV" "grep -av '^#' $ENVF | grep -av '^$'"
	exit $?
fi

payload=$(printf '%s\n' "$@")
timeout "${GTMO:-60}" ssh "${SSHOPT[@]}" "$DEV" "python3 - '$ENVF'" <<PY
import sys, io, os
path = sys.argv[1]
pairs = """$payload""".strip().split("\\n")
data = io.open(path, "rb").read()
if len(data) != 1024:
    print("WARN: 现有 grubenv 长度 %d != 1024（已是坏文件？），继续" % len(data))
kv = {}
for line in data.decode("utf-8", "replace").splitlines():
    if not line or line.startswith("#"):
        continue
    if "=" in line:
        k, v = line.split("=", 1)
        kv[k] = v
for p in pairs:
    k, v = p.split("=", 1)
    kv[k] = v
out = "".join("%s=%s\\n" % (k, v) for k, v in kv.items()).encode()
if len(out) > 1024:
    sys.exit("REFUSE: grubenv 内容 %d B > 1024 B —— 写下去 GRUB load_env 会读坏: %s" % (len(out), path))
out += b"#" * (1024 - len(out))

# 2026-11-18 审计 R4：原来 io.open(path,"wb") 原地截断写 —— 掉电/写一半就是
# 下次开机 load_env 读到坏 env（切错臂或回默认）。改为 备份 → 同目录 tmp →
# fsync → 读回校验正好 1024 B → 原子 replace → 目录 fsync。
bak = path + ".bak-grubenv-set"
try:
    io.open(bak, "wb").write(data)
except OSError as e:
    print("WARN: 备份失败 %s: %s" % (bak, e))
tmp = path + ".new"
fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
try:
    os.write(fd, out)
    os.fsync(fd)
finally:
    os.close(fd)
back = io.open(tmp, "rb").read()
if len(back) != 1024 or back != out:
    sys.exit("FAIL: 读回校验不一致（len=%d），未覆盖 %s" % (len(back), path))
os.replace(tmp, path)
dfd = os.open(os.path.dirname(path) or ".", os.O_RDONLY)
try:
    os.fsync(dfd)
finally:
    os.close(dfd)
print("grubenv:", ", ".join("%s=%s" % (k, v) for k, v in kv.items()))
print("backup:", bak)
PY
