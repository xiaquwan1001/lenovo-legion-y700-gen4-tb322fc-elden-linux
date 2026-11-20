#!/usr/bin/env python3
"""mail-draft-check.py — 投递前静态核对 `send-mail-ustc.py` 草稿（离线，零网络）。

为什么要有它（2026-11-17 实测发现）：`~/.local/bin/send-mail-ustc.py` 的首部解析是**逐行**的
（`if line.startswith("Cc:")` 只看第一行），**不认 RFC 822 的折行续行**。所以草稿里写成

    Cc: devicetree@vger.kernel.org, linux-kernel@vger.kernel.org,
     Konrad Dybcio <konrad.dybcio@oss.qualcomm.com>,

时，缩进续行上的收件人**会被静默丢掉**（dry-run 只报「收件人合计: 4 个」而不报错）。
`reports/upstream-status-20261113.md` 里「dry-run 已过」只核了行数与 ASCII，没核收件人集合。

本工具不做发送，只比对三种视角：
  A. RFC 合规解析（`email.message_from_bytes`，认折行）——「本该发给谁」；
  B. 逐行解析（复刻 `send-mail-ustc.py` 的规则）——「真会发给谁」；
  C. 硬性门禁：非 ASCII（该项目一律要求纯 ASCII）、Subject/To 缺失、回复件缺 `In-Reply-To`。
A ≠ B ⇒ **FAIL**（会被静默漏发）。

用法：
    scripts/mail-draft-check.py <draft.txt> [...]      # 退出码 0 = 全绿；1 = 有 FAIL
    scripts/mail-draft-check.py --quiet ...            # 只打 FAIL/WARN 行
"""
import argparse
import email
import email.utils
import sys


def parse_rfc(raw):
    msg = email.message_from_bytes(raw)
    def addrs(h):
        return [a for _, a in email.utils.getaddresses([h]) if a] if h else []
    return {
        "to": addrs(msg.get("To")),
        "cc": addrs(msg.get("Cc")),
        "subject": (msg.get("Subject") or "").strip(),
        "irt": (msg.get("In-Reply-To") or "").strip(),
        "folded": [h for h in ("To", "Cc", "Subject", "In-Reply-To", "References")
                   if msg.get(h) and _is_folded(raw, h)],
    }


def _is_folded(raw, header):
    """该首部在原文里是否跨行（续行 = 以空格/Tab 开头）。"""
    lines = raw.decode("utf-8", "replace").split("\n\n", 1)[0].splitlines()
    for i, line in enumerate(lines):
        if line.lower().startswith(header.lower() + ":"):
            nxt = lines[i + 1] if i + 1 < len(lines) else ""
            return bool(nxt[:1] in (" ", "\t"))
    return False


def parse_linewise(raw):
    """复刻 send-mail-ustc.py 的逐行规则（只取每类首部的第一行）。"""
    head = raw.decode("utf-8", "replace").split("\n\n", 1)[0]
    to, cc, subj, irt = [], [], None, None
    for line in head.splitlines():
        if line.startswith("To:"):
            to = [a.strip() for a in line[3:].split(",") if a.strip()]
        elif line.startswith("Cc:"):
            cc = [a.strip() for a in line[3:].split(",") if a.strip()]
        elif line.startswith("Subject:"):
            subj = line[8:].strip()
        elif line.startswith("In-Reply-To:"):
            irt = line[12:].strip()
    return {"to": to, "cc": cc, "subject": subj or "", "irt": irt or ""}


def addr_of(entry):
    """`Name <a@b>` → `a@b`（比较集合用）。"""
    _, a = email.utils.parseaddr(entry)
    return (a or entry).lower()


def check(path):
    raw = open(path, "rb").read()
    a, b = parse_rfc(raw), parse_linewise(raw)
    fails, warns, skips = [], [], []
    a_all = {addr_of(x) for x in a["to"] + a["cc"]}
    b_all = {addr_of(x) for x in b["to"] + b["cc"]}
    dropped = sorted(a_all - b_all)
    extra = sorted(b_all - a_all)
    head = raw.decode("utf-8", "replace").split("\n\n", 1)[0]
    if any(h + ":" in head for h in ("Received", "Authentication-Results", "ARC-Seal", "Return-Path")):
        # 收来的原始邮件（inbound dump），不是我们的草稿
        return {"path": path, "fails": [], "warns": [], "skips": ["首部有 Received:/ARC-* ⇒ 收来的原始邮件，跳过"],
                "n_rfc": len(a_all), "n_line": len(b_all), "n_body_lines": 0}
    if not a["to"] or not a["subject"]:
        skips.append("缺 To:/Subject: ⇒ 不是 `send-mail-ustc.py` 草稿（多半是正文片段/原始 mail dump），跳过")
        return {"path": path, "fails": [], "warns": [], "skips": skips,
                "n_rfc": len(a_all), "n_line": len(b_all), "n_body_lines": 0}
    if dropped:
        fails.append("折行续行上有 %d 个收件人只被 `git send-email` 认，"
                     "用 `send-mail-ustc.py` 投会**静默漏发**：%s" % (len(dropped), ", ".join(dropped)))
    if extra:
        fails.append("逐行解析多出收件人（不该发生，检查草稿首部）：%s" % ", ".join(extra))
    if a["folded"]:
        warns.append("折行首部：%s（即使收件人没丢，也建议压成单行再投）" % ", ".join(a["folded"]))
    body = raw.decode("utf-8", "replace").split("\n\n", 1)[1] if "\n\n" in raw.decode("utf-8", "replace") else ""
    na = sorted({c for c in body if ord(c) > 127})
    if na:
        fails.append("正文含非 ASCII 字符：%s" % " ".join(na[:10]))
    if a["subject"].lower().startswith("re:") and not a["irt"]:
        warns.append("Subject 是 `Re:` 但没有 In-Reply-To（回复会脱离原线程）")
    return {"path": path, "fails": fails, "warns": warns, "skips": [],
            "n_rfc": len(a_all), "n_line": len(b_all), "n_body_lines": body.count("\n") + 1}


def main():
    ap = argparse.ArgumentParser(add_help=True, description=__doc__.splitlines()[0])
    ap.add_argument("files", nargs="+")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()
    bad = 0
    for p in a.files:
        r = check(p)
        status = "FAIL" if r["fails"] else ("SKIP" if r["skips"] else ("WARN" if r["warns"] else "OK"))
        if r["fails"]:
            bad += 1
        if not a.quiet or status != "OK":
            print("%-6s %s  (RFC %d 收件人 / 逐行 %d / 正文 %d 行)" % (
                status, r["path"], r["n_rfc"], r["n_line"], r["n_body_lines"]))
            for f in r["fails"]:
                print("   ✗", f)
            for w in r["warns"]:
                print("   !", w)
            for k in r["skips"]:
                print("   -", k)
    print("\n合计 %d 份：FAIL %d 份" % (len(a.files), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
