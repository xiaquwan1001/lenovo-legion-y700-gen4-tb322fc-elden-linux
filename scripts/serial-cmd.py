#!/usr/bin/env python3
"""通过 /dev/ttyACM0 串口与设备 shell 交互：发一组命令，抓输出存文件。

用法: serial-cmd.py <logfile> <cmd1> <cmd2> ...
每条命令之间等待 wait 秒（默认 1.2）。
"""
import os, select, sys, time

LOG = sys.argv[1]
CMDS = sys.argv[2:]
WAIT = float(os.environ.get('SER_WAIT', '1.5'))
TOTAL = float(os.environ.get('SER_TOTAL', '25'))

fd = os.open('/dev/ttyACM0', os.O_RDWR | os.O_NOCTTY)
os.set_blocking(fd, False)
os.system('stty -F /dev/ttyACM0 115200 raw -echo -crtscts 2>/dev/null')

buf = b''
def drain(t):
    global buf
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try:
                d = os.read(fd, 65536)
            except BlockingIOError:
                continue
            if d:
                buf += d

drain(1.0)
for c in CMDS:
    os.write(fd, (c + '\r').encode())
    drain(WAIT)

drain(2.0)
os.close(fd)
text = buf.decode('utf-8', 'replace')
with open(LOG, 'ab') as f:
    f.write(b'\n===== serial-cmd ' + time.strftime('%FT%T').encode() + b' =====\n')
    f.write(text.encode())
print(text[-4000:])
