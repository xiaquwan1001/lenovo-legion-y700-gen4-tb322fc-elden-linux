#!/usr/bin/env python3
"""rootfs-image-check.py — 磁盘根 ext4 镜像「能不能起 / 能不能登入」的写前门（主机侧，只读）

为什么有这支（2026-11-19，PITFALLS #680）：
  2026-11-18 的 minbase 镜像（`out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img`）
  **没有 `/init`**、`/usr/local/sbin` 空。它照样能过 build-rootfs.sh 的 GATE_MIN（那里只查
  `/sbin/init`），因为在设备上 systemd 会从 `/sbin/init` 起来 —— 症状于是变成「只有背光、
  USB 完全不枚举」，和「内核坏了」无法区分（`build-rootfs.sh` 里的 `rsync stage/ → ROOTDIR`
  只要 stage 少一件就静默少一件，退出码照样 0）。
  ⇒ 判据必须在**镜像**上核，而不是在 stage 目录上核。

做法：只用 `debugfs -R` 读（**不 loop mount、不 sudo、不需要 root**），逐个断言必需件的
存在性 / 类型 / 可执行位，再可选地核对 `/init` 是否仍与真源 `initramfs/init` 同字节
（防止磁盘 /init 分叉成第二份 init）。

用法：
  scripts/rootfs-image-check.py <img>                       # 默认档 minbase（起得来）
  scripts/rootfs-image-check.py <img> --profile net         # + 网络登入件（usb-gadget/udhcpd.conf）
  scripts/rootfs-image-check.py <img> --require /opt/x:exec  # 追加断言（path[:exec|:dir|:any]）
  scripts/rootfs-image-check.py <img> --expect-init initramfs/init --strict-init
  scripts/rootfs-image-check.py --selftest                  # 内置好/坏两个合成镜像自检
  scripts/rootfs-image-check.py <img> --json                # 机器可读

退出码：0 = 全 PASS（WARN 不阻塞）；1 = 有 FAIL；2 = 用法/环境错误。
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

DEBUGFS = shutil.which("debugfs") or "/usr/sbin/debugfs"

# 档位：path -> "exec" | "dir" | "any"
PROFILES = {
    # 「起得来」：initramfs 交接后磁盘根必须能接手
    "minbase": {
        "/init": "exec",
        "/sbin/init": "any",
    },
    # 「还能登入」：没有串口的机器上，usb-gadget + udhcpd.conf = 唯一远程入口（USB-NCM）
    "net": {
        "/init": "exec",
        "/sbin/init": "any",
        "/usr/local/sbin/usb-gadget": "exec",
        "/etc/udhcpd.conf": "any",
    },
}


class Res:
    def __init__(self):
        self.rows = []  # (level, msg)

    def ok(self, m):
        self.rows.append(("ok", m))

    def fail(self, m):
        self.rows.append(("FAIL", m))

    def warn(self, m):
        self.rows.append(("warn", m))

    def count(self, level):
        return sum(1 for lv, _ in self.rows if lv == level)


def _debugfs(img, cmd, timeout=120):
    p = subprocess.run([DEBUGFS, "-R", cmd, img], capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout, p.stderr


def stat_path(img, path):
    """返回 dict(kind, mode) 或 None（不存在）。只认 debugfs 的 stat 输出。"""
    rc, out, err = _debugfs(img, "stat %s" % path)
    txt = out + err
    if "File not found by ext2_lookup" in txt or "not found" in txt.lower():
        return None
    if "Inode:" not in txt:
        return None
    kind = None
    mode = None
    for line in txt.splitlines():
        line = line.strip()
        if "Type:" in line:
            f = line.split("Type:")[1].split()
            kind = f[0] if f else None
        if "Mode:" in line:
            tok = line.split("Mode:")[1].split()[0]
            try:
                mode = int(tok, 8)
            except ValueError:
                mode = None
    return {"kind": kind, "mode": mode}


def check(img, requires, expect_init=None, strict_init=False, res=None):
    res = res or Res()
    if not os.path.isfile(img):
        res.fail("镜像不存在：%s" % img)
        return res

    rc, out, err = _debugfs(img, "stats")
    if rc != 0 or "Filesystem volume name" not in (out + err):
        res.fail("不是可读的 ext2/3/4 镜像（debugfs stats 失败）：%s" % (err.strip() or out.strip())[:120])
        return res
    res.ok("ext4 可读（debugfs stats OK，%d B）" % os.path.getsize(img))

    for path, need in requires:
        st = stat_path(img, path)
        if st is None:
            res.fail("%s 缺失" % path)
            continue
        kind = st["kind"] or "?"
        mode = st["mode"]
        if need == "dir":
            if kind == "directory":
                res.ok("%s 是目录" % path)
            else:
                res.fail("%s 是 %s，需要目录" % (path, kind))
        elif need == "exec":
            if kind not in ("regular", "symlink"):
                res.fail("%s 是 %s，需要可执行文件" % (path, kind))
            elif mode is not None and not (mode & 0o111):
                res.fail("%s mode=%04o 无可执行位（0755 期望）" % (path, mode))
            else:
                res.ok("%s 存在且可执行（%s, mode %04o）" % (path, kind, mode or 0))
        else:  # any
            res.ok("%s 存在（%s, mode %04o）" % (path, kind, mode or 0))

    # /init 与真源同字节？（防「磁盘 /init 分叉」= 第二份 init）
    if expect_init:
        if not os.path.isfile(expect_init):
            res.warn("--expect-init 指向的 %s 不存在，跳过 /init 同源核对" % expect_init)
        else:
            st = stat_path(img, "/init")
            if st is None:
                pass  # 上面已经 FAIL 过
            else:
                with tempfile.TemporaryDirectory(prefix="rootfs-init-") as td:
                    dst = os.path.join(td, "init")
                    rc, out, err = _debugfs(img, "dump /init %s" % dst)
                    if rc != 0 or not os.path.isfile(dst):
                        res.warn("无法 dump /init 内容（%s），跳过同源核对" % err.strip()[:80])
                    else:
                        a = open(dst, "rb").read()
                        b = open(expect_init, "rb").read()
                        if a == b:
                            res.ok("/init == %s（%d B，同字节）" % (expect_init, len(a)))
                        elif strict_init:
                            res.fail("/init != %s（%d B vs %d B）⇒ 磁盘 /init 已分叉"
                                     % (expect_init, len(a), len(b)))
                        else:
                            res.warn("/init != %s（%d B vs %d B）—— 若是有意改的，把 initramfs/init 也更新"
                                     % (expect_init, len(a), len(b)))
    return res


def selftest():
    """合成两个 ext4：好件必须全 PASS，坏件（缺 /init）必须 FAIL。"""
    if not os.path.exists(DEBUGFS):
        print("SELFTEST FAIL: 找不到 debugfs", file=sys.stderr)
        return 2
    mke2fs = shutil.which("mke2fs") or "/usr/sbin/mke2fs"
    fails = []
    with tempfile.TemporaryDirectory(prefix="rootfs-chk-") as td:
        def make(name, files):
            src = os.path.join(td, name + ".d")
            os.makedirs(src)
            for rel, mode, data in files:
                p = os.path.join(src, rel.lstrip("/"))
                os.makedirs(os.path.dirname(p), exist_ok=True)
                with open(p, "w") as f:
                    f.write(data)
                os.chmod(p, mode)
            img = os.path.join(td, name + ".img")
            rc = subprocess.run([mke2fs, "-q", "-t", "ext4", "-F", "-L", "selftest",
                                 "-d", src, img, "8192"],
                                capture_output=True, text=True)
            if rc.returncode != 0:
                raise RuntimeError("mke2fs 失败：%s" % rc.stderr.strip()[:200])
            return img

        expect = os.path.join(td, "init.ref")
        with open(expect, "w") as f:
            f.write("#!/bin/sh\nexit 0\n")
        ref_bytes = open(expect).read()

        good = make("good", [("/init", 0o755, ref_bytes),
                             ("/sbin/init", 0o755, "stub"),
                             ("/usr/local/sbin/usb-gadget", 0o755, "stub"),
                             ("/etc/udhcpd.conf", 0o644, "start 192.168.7.2\n")])
        bad = make("bad", [("/sbin/init", 0o755, "stub"),
                           ("/etc/udhcpd.conf", 0o644, "start 192.168.7.2\n")])
        noexec = make("noexec", [("/init", 0o644, ref_bytes),
                                 ("/sbin/init", 0o755, "stub")])

        r = check(good, list(PROFILES["net"].items()), expect_init=expect, strict_init=True)
        if r.count("FAIL"):
            fails.append("好件被误判：%s" % [m for lv, m in r.rows if lv == "FAIL"])
        r = check(bad, list(PROFILES["net"].items()), expect_init=expect, strict_init=True)
        if not any("缺失" in m for lv, m in r.rows if lv == "FAIL"):
            fails.append("坏件（缺 /init）没被抓")
        if r.count("FAIL") < 2:
            fails.append("坏件只被抓到 %d 条（期望 ≥2：/init、/usr/local/sbin/usb-gadget）"
                         % r.count("FAIL"))
        r = check(noexec, list(PROFILES["minbase"].items()))
        if not any("可执行位" in m for lv, m in r.rows if lv == "FAIL"):
            fails.append("无执行位的 /init 没被抓")

    if fails:
        for f in fails:
            print("SELFTEST FAIL: %s" % f, file=sys.stderr)
        return 1
    print("SELFTEST OK（好件 PASS / 缺 /init 被抓 ≥2 条 / 无执行位被抓 / /init 分叉被抓）")
    return 0


def parse_require(items):
    out = []
    for it in items:
        path, _, kind = it.partition(":")
        kind = kind or "any"
        if kind not in ("exec", "dir", "any"):
            raise SystemExit("--require 的类型只能是 exec/dir/any：%s" % it)
        if not path.startswith("/"):
            raise SystemExit("--require 必须是绝对路径：%s" % it)
        out.append((path, kind))
    return out


def main(argv):
    ap = argparse.ArgumentParser(add_help=True, description="磁盘根 ext4 镜像写前门（只读 debugfs）")
    ap.add_argument("img", nargs="?")
    ap.add_argument("--profile", choices=sorted(PROFILES), default="minbase")
    ap.add_argument("--require", action="append", default=[], metavar="PATH[:exec|dir|any]")
    ap.add_argument("--expect-init", default=None, metavar="FILE")
    ap.add_argument("--strict-init", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args(argv)

    if a.selftest:
        return selftest()
    if not a.img:
        ap.error("需要镜像路径（或用 --selftest）")

    requires = list(PROFILES[a.profile].items()) + parse_require(a.require)
    # 去重（后面的 --require 覆盖档位里的同路径）
    seen = {}
    for p, k in requires:
        seen[p] = k
    requires = list(seen.items())

    res = check(a.img, requires, expect_init=a.expect_init, strict_init=a.strict_init)
    nf, nw = res.count("FAIL"), res.count("warn")
    if a.json:
        print(json.dumps({"img": a.img, "profile": a.profile, "fail": nf, "warn": nw,
                          "rows": [{"level": lv, "msg": m} for lv, m in res.rows]},
                         ensure_ascii=False, indent=1))
    else:
        print("== rootfs-image-check — %s（profile=%s）==" % (a.img, a.profile))
        for lv, m in res.rows:
            tag = {"ok": "[ok]  ", "FAIL": "[FAIL]", "warn": "[warn]"}[lv]
            print("  %s %s" % (tag, m))
        print("== %s: FAIL=%d  WARN=%d ==" % ("不通过" if nf else "通过", nf, nw))
    return 1 if nf else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
