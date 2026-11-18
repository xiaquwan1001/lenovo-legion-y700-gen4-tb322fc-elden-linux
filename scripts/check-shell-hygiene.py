#!/usr/bin/env python3
"""check-shell-hygiene.py — 设备命令静态卫生门（2026-11-18，来自四板块脚本审查）

为什么有这个：同一类缺陷在 20+ 脚本里重复出现，每次都靠人工复读才发现。它只做**静态**扫描，
不执行任何设备命令。

规则（正则作用在「逻辑行」上：`\\` 续行已拼接、注释与 echo/printf 文案已剥离）：
  H1  adb/fastboot/ssh/scp/qdl 调用未套 `timeout`      （设备掉线 = 无限等，#584/#628）
  H2  大输出命令（boot/flash/getvar/oem/dumpsys/dmesg）直接进 `| grep -q`/`| head`（SIGPIPE，#584）
  H3  ssh/scp 命令行缺 `BatchMode`                      （首次连接等密码提示，#584 同族）
  H4  `pkill -f`/`pgrep -f` 用裸字面量                  （自匹配杀自己，技能 pkill-self-match）
  H5  `… | tee|tail|head` 的**下一行**取 `$?`           （管道 rc 恒为最后一段，PITFALLS #669）

豁免：`versions/shell-hygiene-baseline.txt`（一行一个 `path:规则号`，带理由注释）。
用法：scripts/check-shell-hygiene.py [--strict] [--file F] [--verbose]
  --strict  有未豁免命中即 rc=1（接 check-doctor 用）
"""
import argparse, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELF = os.path.relpath(os.path.abspath(__file__), ROOT)
BASE = os.path.join(ROOT, "versions", "shell-hygiene-baseline.txt")

CMD = r"(?:^|[;&|()`]\s*|\bthen\s+|\bdo\s+|\belse\s+|\|\|\s+|&&\s+)(adb|fastboot|ssh|scp|qdl)(?=\s|$)"
TIMEOUT = re.compile(r"\btimeout\b")
BIG = re.compile(r"\b(adb|fastboot)\b[^|]*(boot|flash|getvar|oem|dumpsys|dmesg|logcat)\b")
PIPE_Q = re.compile(r"\|\s*(grep\s+-q|head\b)")
SSHCMD = re.compile(r"\b(ssh|scp)\b")
PKGREP = re.compile(r"\b(pkill|pgrep)\b[^|;]*\s-f\b")
PIPE_LAST = re.compile(r"\|\s*(tee|tail|head)\b")
DOLLARQ = re.compile(r"\$\?")

def is_comment_or_print(line):
    s = line.strip()
    if s.startswith("#"):
        return True
    return bool(re.search(r"\b(echo|printf|say|log|emit|note)\b", s)) and '"' in s or s.startswith(("echo", "printf"))

def logical_lines(path):
    """yield (lineno_of_start, joined_line) — 拼接 `\\` 续行，剥离行尾注释。"""
    buf, start = "", None
    with open(path, encoding="utf-8", errors="replace") as f:
        for n, raw in enumerate(f, 1):
            line = raw.rstrip("\n")
            if start is None:
                start = n
            body = line
            # 去掉行尾注释（保守：只处理前面有空白、且不在引号内的 #）
            body = re.sub(r"(?<!\S)#.*$", "", body)
            if body.rstrip().endswith("\\"):
                buf += body.rstrip()[:-1] + " "
                continue
            buf += body
            yield start, buf
            buf, start = "", None
    if buf:
        yield start, buf

def load_baseline():
    out = set()
    if os.path.exists(BASE):
        for line in open(BASE, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            out.add(line.split()[0])
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--file")
    ap.add_argument("--verbose", action="store_true")
    a = ap.parse_args()

    if a.file:
        files = [os.path.abspath(a.file)]
    else:
        files = []
        for top in ("scripts", "rootfs", "packaging"):
            for dp, _, fns in os.walk(os.path.join(ROOT, top)):
                for fn in fns:
                    if fn.endswith((".sh", ".bash")):
                        files.append(os.path.join(dp, fn))
        files.sort()

    hits = {k: [] for k in ("H1", "H2", "H3", "H4", "H5")}
    for path in files:
        rel = os.path.relpath(path, ROOT)
        if rel == SELF:
            continue
        lines = list(logical_lines(path))
        for idx, (ln, body) in enumerate(lines):
            if not body.strip() or is_comment_or_print(body):
                continue
            m = re.search(CMD, body)
            if m and not TIMEOUT.search(body):
                # 包装定义（ADB=/SSH=/函数体第一行）不算调用点
                if not re.search(r"^\s*(\w+)=|^\s*\w+\s*\(\)", body):
                    hits["H1"].append((rel, ln, body.strip()[:120]))
            if BIG.search(body) and PIPE_Q.search(body):
                hits["H2"].append((rel, ln, body.strip()[:120]))
            if m and m.group(1) in ("ssh", "scp") and "BatchMode" not in body and not re.search(r"^\s*\w+=", body):
                hits["H3"].append((rel, ln, body.strip()[:120]))
            if PKGREP.search(body) and not re.search(r"['\"][^'\"]*\[", body):
                hits["H4"].append((rel, ln, body.strip()[:120]))
            if PIPE_LAST.search(body) and idx + 1 < len(lines):
                nxt = lines[idx + 1][1]
                if DOLLARQ.search(nxt) and "PIPESTATUS" not in nxt:
                    hits["H5"].append((rel, ln, f"{body.strip()[:70]} … 下一行取 $?"))

    base = load_baseline()
    total = unwaived = 0
    print(f"== 设备命令静态卫生：{len(files)} 个 .sh/.bash ==")
    for k in ("H1", "H2", "H3", "H4", "H5"):
        waived = [h for h in hits[k] if f"{h[0]}:{k}" in base and f"{h[0]}:{h[1]}:{k}" not in base]
        live = [h for h in hits[k] if f"{h[0]}:{h[1]}:{k}" not in base and f"{h[0]}:{k}" not in base]
        total += len(live); unwaived += len(live)
        print(f"  {k}: {len(live)}（已豁免 {len(hits[k]) - len(live)}）")
        for rel, ln, body in (live if a.verbose else live[:8]):
            print(f"    {rel}:{ln}: {body}")
    print(f"== 未豁免合计 {unwaived} 处 ==")
    if a.strict and unwaived:
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
