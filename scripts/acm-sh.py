#!/usr/bin/env python3
"""acm-sh.py — 通过 USB ACM 的 OOB root shell（/dev/ttyACM1）在设备上跑命令。

为什么需要：最小根/无网络时唯一的通道就是 /init 的 respawn getty（ttyGS1 → 主机 ttyACM1）。
不用 sudo（设备节点是 0666）、不依赖网络。

用法：
  scripts/acm-sh.py 'uname -r'                  # 单条，打印输出
  scripts/acm-sh.py -t 20 'systemctl --failed'  # 自定义超时
  printf 'cmd1\ncmd2\n' | scripts/acm-sh.py -     # 从 stdin 读多条（逐条发，一次性收集）
  scripts/acm-sh.py --check                     # 只探活
"""
import os
import select
import sys
import termios
import time

DEV = os.environ.get("ACM_DEV", "/dev/ttyACM1")


def open_dev(path=DEV):
    fd = os.open(path, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    attrs[3] &= ~(termios.ECHO | termios.ICANON)
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    return fd


def drain(fd, settle=0.4):
    out = b""
    while True:
        r, _, _ = select.select([fd], [], [], settle)
        if not r:
            break
        try:
            chunk = os.read(fd, 65536)
        except BlockingIOError:
            break
        if not chunk:
            break
        out += chunk
    return out


def run(commands, timeout=30.0, fd=None):
    own = fd is None
    if own:
        fd = open_dev()
    try:
        drain(fd, 0.2)
        blob = b""
        for cmd in commands:
            token = "__ACMDONE_%d__" % (int(time.time() * 1000) % 100000)
            os.write(fd, cmd.encode() + b"\n")
            os.write(fd, b"echo " + token.encode() + b"\n")
            deadline = time.time() + timeout
            while time.time() < deadline:
                r, _, _ = select.select([fd], [], [], 0.5)
                if not r:
                    continue
                try:
                    chunk = os.read(fd, 65536)
                except BlockingIOError:
                    continue
                if not chunk:
                    break
                blob += chunk
                if token.encode() in blob:
                    blob = blob.split(token.encode())[0]
                    break
            else:
                blob += b"\n[acm-sh] TIMEOUT after %ss\n" % timeout
        return blob.decode("utf-8", "replace")
    finally:
        if own:
            os.close(fd)


def main(argv):
    args = argv[1:]
    timeout = 30.0
    if args and args[0] == "--check":
        print(repr(run(["echo ACM-OK"], timeout=5)))
        return 0
    if args and args[0] in ("-t", "--timeout"):
        timeout = float(args[1])
        args = args[2:]
    if args and args[0] == "-":
        cmds = [ln.strip() for ln in sys.stdin if ln.strip()]
    else:
        cmds = [" ".join(args)] if args else []
    if not cmds:
        print(__doc__)
        return 2
    sys.stdout.write(run(cmds, timeout=timeout))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
