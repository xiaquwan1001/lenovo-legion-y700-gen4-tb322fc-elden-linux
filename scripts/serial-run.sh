#!/usr/bin/env bash
# serial-run.sh — 通过设备 USB CDC-ACM 串口 (/dev/ttyACM0) 执行一条命令并打印回显
# 用法: bash serial-run.sh '命令'   或   bash serial-run.sh   (交互读 5 秒)
# 依赖：设备侧已有一个 shell 挂在 /dev/ttyGS1（见 initramfs/usb-gadget 与 initramfs/init 的 respawn）
# ★ 2026-11-27 改默认口：ttyGS0(=/dev/ttyACM0) 是**内核 console**，磁盘根时 systemd 会在它上面起
#   serial-getty@ttyGS0（登录提示）⇒ 往里写命令会变成「用户名 + 密码」。设计上的 out-of-band
#   root shell 是 ttyGS1 = /dev/ttyACM1。旧默认（ttyACM0）能用，只是因为 init 也在 ttyGS0 上多
#   respawn 了一个 shell（两个读者抢输入；已修，见 initramfs/init 同注释）。读内核日志仍用 ttyACM0。
set -euo pipefail
DEV="${SERIAL_DEV:-/dev/ttyACM1}"
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
