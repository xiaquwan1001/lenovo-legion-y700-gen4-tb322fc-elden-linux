#!/usr/bin/env python3
"""uefi-usb-gap.py — 用 USB 出现/消失时刻给「fastboot boot 之后到底发生了什么」计时。

判读原理：`fastboot boot` 一开始 ABL 就拆掉 fastboot gadget（主机侧看到 `usb_read failed`），
之后设备从 USB 完全消失，直到下一个能被枚举的东西出现：
  * 若载荷被执行并自旋 ⇒ 只有看门狗能打断它（数个 tick），间隙 = 看门狗超时 + XBL/ABL 初始化；
  * 若载荷未被执行、ABL 直接去启动槽位 ⇒ 间隙 ≈ XBL/ABL 初始化（明显更短）。
用法：脚本自己执行 `fastboot boot <img>`，只做观测，不写盘。
    scripts/uefi-usb-gap.py --image X.img --label ctrl --timeout 90
"""
import argparse, glob, os, subprocess, sys, time

WATCH = {"18d1": "google", "05c6": "quallcomm-edl", "1d6b": "gadget-linux"}

def scan():
    seen = []
    for d in glob.glob("/sys/bus/usb/devices/*"):
        try:
            vid = open(os.path.join(d, "idVendor")).read().strip()
            pid = open(os.path.join(d, "idProduct")).read().strip()
        except OSError:
            continue
        seen.append("%s:%s" % (vid, pid))
    return sorted(set(seen))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", required=True)
    ap.add_argument("--label", default="shot")
    ap.add_argument("--timeout", type=float, default=90)
    ap.add_argument("--pre", type=float, default=1.5)
    a = ap.parse_args()

    base = set(scan())
    t0 = time.monotonic()
    p = subprocess.Popen(["fastboot", "boot", a.image], stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, text=True)
    events = []
    last = None
    while time.monotonic() - t0 < a.timeout:
        cur = set(scan())
        key = tuple(sorted(cur - base))
        if key != last:
            events.append((time.monotonic() - t0, key))
            last = key
        if p.poll() is not None and time.monotonic() - t0 > 3 and not cur - base:
            # 命令已结束且仍无新设备，继续等到 timeout（回落需要时间）
            pass
        time.sleep(0.05)
    out = p.stdout.read() if p.stdout else ""
    p.wait(timeout=5)
    print("# label=%s image=%s" % (a.label, os.path.basename(a.image)))
    print("# fastboot 输出：%s" % " ".join(out.split())[:200])
    for t, key in events:
        print("  t=%6.2fs  new_usb=%s" % (t, ",".join(key) if key else "-"))
    if len(events) >= 2:
        first_gone = next((t for t, k in events if not k), None)
        first_back = next((t for t, k in events if k and t > (first_gone or 0)), None)
        if first_gone is not None and first_back is not None:
            print("  >>> USB 黑屏间隙 = %.2f s (消失 %.2fs → 重现 %.2fs)" % (first_back - first_gone, first_gone, first_back))

if __name__ == "__main__":
    main()
