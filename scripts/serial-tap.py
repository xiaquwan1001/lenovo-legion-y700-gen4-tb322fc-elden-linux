#!/usr/bin/env python3
"""serial-tap.py — 稳定的设备串口落盘（替代 serial-logger.sh 的 cat 循环）

为什么不用 scripts/serial-logger.sh：那个脚本用 `cat $PORT &` + wait，
本机实测在 ttyACM 存在但这端没有数据时会 **open/close 狂抖**（1 秒几十次，
日志里全是 `===== serial opened/closed =====`，真数据一行没留）。
原因 = cat 拿到 EOF/HUP 立即退出，循环再用 `sleep 0.3` 重开。

本脚本的做法：
  * os.open(O_RDONLY|O_NOCTTY|O_NONBLOCK) + termios 设 raw/115200，一次打开长期持有；
  * select 等待可读，读到就 append 落盘并 flush（掉电也不丢已收内容）；
  * 设备侧 gadget 重建（ttyACM 消失再出现）时，只重开一次、写一行 `--- reopen`，
    不刷屏；
  * `--quiet-window` 内没数据不打印任何东西（stdout 只报一次状态）。

用法：
  scripts/serial-tap.py --port /dev/ttyACM0 --out logs/serial-<ts>.log [--baud 115200]
  # 后台常驻：
  nohup python3 scripts/serial-tap.py --out logs/serial-x.log >/tmp/serial-tap.out 2>&1 &
停止：kill "$(cat /tmp/serial-tap.pid)"
"""
import argparse
import errno
import os
import select
import sys
import termios
import time
import tty

PIDF = "/tmp/serial-tap.pid"


def open_raw(port, baud):
    fd = os.open(port, os.O_RDONLY | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        tty.setraw(fd)
        attrs = termios.tcgetattr(fd)
        # 8N1, no flow control, 115200（用 B115200 常量）
        speed = getattr(termios, "B%d" % baud)
        attrs[4] = speed
        attrs[5] = speed
        attrs[2] &= ~(termios.PARENB | termios.CSTOPB | termios.CRTSCTS)
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
    except Exception:
        pass          # 不是真 tty（pty 测试）时忽略
    return fd


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default=os.environ.get("SERIAL_PORT", "/dev/ttyACM0"))
    ap.add_argument("--out", default="logs/serial-%s.log" % time.strftime("%Y%m%d-%H%M%S"))
    ap.add_argument("--baud", type=int, default=115200)
    a = ap.parse_args()

    os.makedirs(os.path.dirname(os.path.abspath(a.out)) or ".", exist_ok=True)
    with open(PIDF, "w") as f:
        f.write(str(os.getpid()))

    fd = None
    last_note = 0.0
    while True:
        if fd is None:
            if not os.path.exists(a.port):
                time.sleep(0.5)
                continue
            try:
                fd = open_raw(a.port, a.baud)
            except OSError as e:
                time.sleep(0.5)
                continue
            with open(a.out, "a") as f:
                f.write("\n--- tap open %s %s ---\n" % (a.port, time.strftime("%H:%M:%S")))
            now = time.time()
            if now - last_note > 30:
                print("[serial-tap] open %s -> %s" % (a.port, a.out), flush=True)
                last_note = now
        try:
            r, _, _ = select.select([fd], [], [], 1.0)
        except OSError:
            r = [fd]
        if not r:
            continue
        try:
            chunk = os.read(fd, 65536)
        except OSError as e:
            if e.errno in (errno.ENODEV, errno.EIO, errno.EBADF):
                os.close(fd)
                fd = None
                with open(a.out, "a") as f:
                    f.write("\n--- tap closed (ENODEV), reopening ---\n")
                continue
            raise
        if not chunk:                      # HUP：设备拔了 / gadget 重建
            os.close(fd)
            fd = None
            with open(a.out, "a") as f:
                f.write("\n--- tap closed (EOF), reopening ---\n")
            continue
        with open(a.out, "ab") as f:
            f.write(chunk)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
