#!/usr/bin/env python3
"""serial-sysrq.py — 通过 USB 串口控制台发 SysRq（免物理断电复位/取栈）。

为什么需要：设备卡死时没有 SSH / 没有 fastboot，唯一还活着的是 USB 复合 gadget 的
CDC-ACM 控制台（/dev/ttyACM0）。本机内核 `CONFIG_MAGIC_SYSRQ=y`（默认 enable 0x1）
且 `CONFIG_MAGIC_SYSRQ_SERIAL=y` ⇒ 对该 tty 发 **BREAK** 后紧跟一个字符即等价
`echo <c> > /proc/sysrq-trigger`。

用法（需要 root 或在 dialout 组；当前用户不在 dialout，故用 sudo）：
    python3 scripts/serial-sysrq.py b            # 立即重启（回 boot_b）
    python3 scripts/serial-sysrq.py s            # 同步
    python3 scripts/serial-sysrq.py w            # 列出 D 状态任务
    python3 scripts/serial-sysrq.py b /dev/ttyACM0
"""
import os
import sys
import time
import termios

def send(port: str, cmd: str) -> int:
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        attrs = termios.tcgetattr(fd)
        attrs[0] = 0                                   # iflag
        attrs[1] = 0                                   # oflag
        attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
        attrs[3] = 0                                   # lflag
        attrs[4] = attrs[5] = termios.B115200
        attrs[6][termios.VMIN] = 0
        attrs[6][termios.VTIME] = 0
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
        time.sleep(0.2)
        termios.tcsendbreak(fd, 0)                      # BREAK
        time.sleep(0.35)
        os.write(fd, cmd.encode())
        os.write(fd, b"\n")
        time.sleep(0.2)
    finally:
        os.close(fd)
    return 0

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    p = sys.argv[2] if len(sys.argv) > 2 else "/dev/ttyACM0"
    if not os.path.exists(p):
        print(f"没有 {p}", file=sys.stderr)
        sys.exit(2)
    send(p, sys.argv[1])
    print(f"已向 {p} 发送 BREAK + '{sys.argv[1]}'")
