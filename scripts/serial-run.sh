#!/usr/bin/env bash
# serial-run.sh — 通过设备 USB CDC-ACM 串口 (/dev/ttyACM0) 执行一条命令并打印回显
# 用法: bash serial-run.sh '命令'   或   bash serial-run.sh   (交互读 5 秒)
# 依赖：设备侧已有一个 shell 挂在 /dev/ttyGS0（见 setup-serial-shell 说明）
set -euo pipefail
DEV="${SERIAL_DEV:-/dev/ttyACM0}"
WAIT="${SERIAL_WAIT:-5}"
CMD="${*:-}"
exec python3 - "$DEV" "$WAIT" "$CMD" <<'PY'
import os, sys, select, time, termios
dev, wait, cmd = sys.argv[1], float(sys.argv[2]), sys.argv[3]
fd = os.open(dev, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
try:
    attrs = termios.tcgetattr(fd)
    attrs[0] = attrs[0] & ~(termios.ICRNL | termios.IXON | termios.IXOFF)
    attrs[1] = attrs[1] & ~(termios.ECHO | termios.ICANON)
    attrs[3] = attrs[3] & ~(termios.ECHO | termios.ICANON | termios.ISIG)
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
except Exception:
    pass
def drain(t):
    out = b""
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try:
                d = os.read(fd, 8192)
            except OSError:
                break
            if not d:
                break
            out += d
    return out
time.sleep(0.3)
drain(0.3)
if cmd:
    os.write(fd, b"\n")
    time.sleep(0.1)
    os.write(fd, cmd.encode() + b"\n")
    sys.stdout.buffer.write(drain(wait))
    sys.stdout.write("\n[--- end ---]\n")
else:
    sys.stdout.buffer.write(drain(wait))
os.close(fd)
PY
