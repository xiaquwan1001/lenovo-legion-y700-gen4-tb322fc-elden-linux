#!/usr/bin/env python3
# ssc-udp-relay — feed *real* Qualcomm SSC sensor values into the route-C
# Waydroid sensor HAL (patches-userland/waydroid-sensord-udp), 2026-10-11.
#
# It runs one `ssccli --sensor <s> --timeout N` stream per sensor and
# translates libssc's human-readable lines into the UDP text protocol the HAL
# listens on (default udp://127.0.0.1:52012):
#
#   acc <x> <y> <z> | gyr <x> <y> <z> | mag <x> <y> <z> | light <v> | prox <v>
#
# Requires: libssc (ssccli), python3. Run on the Linux host next to
# waydroid-sensord. Supervised restart per sensor stream.
#
# Usage: ssc-udp-relay.py [--host 127.0.0.1] [--port 52012] [--timeout 3600]
#                         [--sensors accelerometer,gyroscope,magnetometer,light,proximity]

import argparse
import re
import socket
import subprocess
import sys
import threading
import time

XYZ = re.compile(r"X=(-?\d+(?:\.\d+)?)\s+Y=(-?\d+(?:\.\d+)?)\s+Z=(-?\d+(?:\.\d+)?)")
SCALAR = re.compile(r"measurement:\s*(-?\d+(?:\.\d+)?)")
PROX = re.compile(r"measurement:\s*(FAR|NEAR)", re.I)

DEFAULT_SENSORS = ["accelerometer", "gyroscope", "magnetometer", "light", "proximity"]


def log(msg):
    print(f"[ssc-udp-relay] {msg}", flush=True)


def parse(sensor, line):
    """Return a protocol line for a raw ssccli stdout line, or None."""
    if sensor in ("accelerometer", "gyroscope", "magnetometer"):
        m = XYZ.search(line)
        if not m:
            return None
        tag = {"accelerometer": "acc", "gyroscope": "gyr", "magnetometer": "mag"}[sensor]
        return f"{tag} {m.group(1)} {m.group(2)} {m.group(3)}"
    if sensor == "light":
        m = SCALAR.search(line)
        return f"light {m.group(1)}" if m else None
    if sensor == "proximity":
        m = PROX.search(line)
        # 0 cm = near, 5 cm = far (matches the HAL's is_near threshold)
        return "prox 0" if m and m.group(1).upper() == "NEAR" else "prox 5" if m else None
    return None


def stream(sensor, sock, dest, timeout, stop):
    while not stop.is_set():
        try:
            p = subprocess.Popen(
                ["ssccli", "--sensor", sensor, "--timeout", str(timeout)],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)
        except FileNotFoundError:
            log("FATAL: ssccli not found (apk add libssc)")
            stop.set()
            return
        log(f"{sensor}: streaming (pid {p.pid})")
        for line in p.stdout:
            if stop.is_set():
                break
            out = parse(sensor, line)
            if out:
                try:
                    sock.sendto(out.encode(), dest)
                except OSError as e:
                    log(f"{sensor}: send failed: {e}")
        p.terminate()
        try:
            p.wait(timeout=3)
        except subprocess.TimeoutExpired:
            p.kill()
        if not stop.is_set():
            log(f"{sensor}: stream ended, restarting")
            time.sleep(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=52012)
    ap.add_argument("--timeout", type=int, default=3600, help="ssccli --timeout seconds")
    ap.add_argument("--sensors", default=",".join(DEFAULT_SENSORS))
    args = ap.parse_args()

    sensors = [s.strip() for s in args.sensors.split(",") if s.strip()]
    dest = (args.host, args.port)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    stop = threading.Event()
    log(f"relaying {sensors} -> udp://{args.host}:{args.port}")

    threads = [threading.Thread(target=stream, args=(s, sock, dest, args.timeout, stop),
                                daemon=True) for s in sensors]
    for t in threads:
        t.start()
    try:
        while any(t.is_alive() for t in threads):
            time.sleep(1)
    except KeyboardInterrupt:
        stop.set()
    log("bye")


if __name__ == "__main__":
    main()
