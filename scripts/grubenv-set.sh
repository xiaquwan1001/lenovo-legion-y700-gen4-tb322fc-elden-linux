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
ssh "${SSHOPT[@]}" "$DEV" "python3 - '$ENVF'" <<PY
import sys, io
path = sys.argv[1]
pairs = """$payload""".strip().split("\\n")
data = io.open(path, "rb").read()
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
out += b"#" * (1024 - len(out))
io.open(path, "wb").write(out)
print("grubenv:", ", ".join("%s=%s" % (k, v) for k, v in kv.items()))
PY
