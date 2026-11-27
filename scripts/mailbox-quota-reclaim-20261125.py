#!/usr/bin/env python3
# RETIRED 2026-11-27：2026-11-25 用户授权的一次性邮箱回收（文件名即日期戳），规则与执行结果见该轮会话记录；可复核：reports/arch-audit-20261127.md
"""mailbox-quota-reclaim-20261125.py — 邮箱到 2 万封上限后的「按规则回收」（2026-11-25 用户授权）。

为什么新写而不是调 `mailbox-cleanup-20261102.py`：后者的 KEEP-HUMAN 用的是「发件域白名单」，
而 vger/kernel.org/patchwork 这些**列表流量也命中白名单** ⇒ 19 435 封里 14 903 封被判 KEEP，
quota 永远清不下来。本脚本改成「**直接发我 + 无 List-Id** 才算人类直发」。

分类（每条只落一类，只读 header）：
  PROTECT-OURS    我们的线程：References/In-Reply-To/Subject/Message-ID 命中 mail.ustc.edu.cn 或系列关键词
  PROTECT-HUMAN   直接发我：无 `List-Id`/`List-Post`，且 To/Cc 含本地址，且 From 不在机器人名单
  PROTECT-RECENT  Date 在 `--recent-days`（默认 14）以内
  PROTECT-PROJECT Mobian/phosh/GitLab/GitHub 通知（项目要跟的 MR/CI）
  DELETE          其余全部（列表流水 / 机器人通知 / 退信 / 订阅确认）

用法：
  python3 scripts/mailbox-quota-reclaim-20261125.py --stats          # 只统计（默认）
  python3 scripts/mailbox-quota-reclaim-20261125.py --stats --recent-days 7
  python3 scripts/mailbox-quota-reclaim-20261125.py --apply          # 真删（pending-delete 标记 + EXPUNGE）
  python3 scripts/mailbox-quota-reclaim-20261125.py --apply --limit 500   # 先小批试删

纪律：密码只从 GNOME keyring（secret-tool lookup service smtp）取；删除前把清单写成
`~/Mail/reclaim-<date>/manifest.tsv`（Message-ID/日期/大小/分类），可事后核对；
`--apply` 前脚本会先打印「将删 N 封 / 约 X MB」，必须带 `--yes` 才真正动服务器。
"""
import argparse
import email
import email.header
import email.utils
import imaplib
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone

HOST = "mail.ustc.edu.cn"
USER = "xiaqinghuan@mail.ustc.edu.cn"
FOLDERS = ["INBOX", "Junk E-mail", "Trash"]

OURS_TOKEN = ["mail.ustc.edu.cn", "xiaqinghuan"]
SERIES_KW = [
    "dwc3", "wl2868c", "aw86927", "pstore", "ramoops", "fastrpc", "mdss",
    "elden", "sm8750", "tb322fc", "csiphy", "camss", "battmgr", "input current",
    "qcom_battmgr", "g7", "v15", "v16", "v14", "v13", "v12",
]
PROJECT_KW = ["mobian", "droid-juicer", "gitlab", "github", "phosh", "phoc", "salsa.debian.org", "pipelines", "merge request", "issue #"]
BOT_HINTS = ["patchwork", "sashiko", "lore.kernel.org", "vger.kernel.org", "no-reply", "noreply", "mailer-daemon", "postmaster", "bounce", "bugzilla", "kernel test robot", "syzbot", "gitlab", "github"]

BATCH = 400


def keyring_password():
    try:
        out = subprocess.run(["secret-tool", "lookup", "service", "smtp"],
                             capture_output=True, text=True, timeout=20)
        pw = out.stdout.strip()
        if pw:
            return pw
    except Exception:
        pass
    for attr in ("service", "smtp", "mail"):
        try:
            out = subprocess.run(["secret-tool", "lookup", "service", attr, "user", USER],
                                 capture_output=True, text=True, timeout=20)
            if out.stdout.strip():
                return out.stdout.strip()
        except Exception:
            continue
    sys.exit("无法从 keyring 取密码（secret-tool lookup service smtp 为空）")


def dec(v):
    if not v:
        return ""
    try:
        return str(email.header.make_header(email.header.decode_header(v)))
    except Exception:
        return v


def classify(hdr, recent_days, now):
    subj = dec(hdr.get("Subject"))
    refs = " ".join(filter(None, [hdr.get("References") or "", hdr.get("In-Reply-To") or "", hdr.get("Message-ID") or ""]))
    frm = dec(hdr.get("From")).lower()
    tocc = (dec(hdr.get("To")) + " " + dec(hdr.get("Cc"))).lower()
    low = (subj + " " + refs).lower()

    if any(t in refs.lower() for t in OURS_TOKEN) or any(k in low for k in SERIES_KW):
        return "PROTECT-OURS"
    has_list = bool(hdr.get("List-Id") or hdr.get("List-Post") or hdr.get("Precedence") in ("list", "bulk"))
    is_bot = any(b in frm for b in BOT_HINTS)
    if not has_list and not is_bot and USER.split("@")[0] in tocc:
        return "PROTECT-HUMAN"
    if any(k in low for k in PROJECT_KW) or any(k in frm for k in ("gitlab", "github")):
        return "PROTECT-PROJECT"
    try:
        dt = email.utils.parsedate_to_datetime(hdr.get("Date"))
        if dt and dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        if dt and (now - dt) < timedelta(days=recent_days):
            return "PROTECT-RECENT"
    except Exception:
        pass
    return "DELETE"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stats", action="store_true")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--yes", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--recent-days", type=int, default=14)
    ap.add_argument("--outdir", default=os.path.expanduser("~/Mail/reclaim-%s" % datetime.now().strftime("%Y%m%d")))
    a = ap.parse_args()
    if not (a.stats or a.apply):
        a.stats = True

    pw = keyring_password()
    im = imaplib.IMAP4_SSL(HOST)
    im.login(USER, pw)
    os.makedirs(a.outdir, exist_ok=True)
    now = datetime.now(timezone.utc)
    counts, sizes, cand = {}, {}, {}

    for folder in FOLDERS:
        typ, _ = im.select('"%s"' % folder, readonly=not a.apply)
        if typ != "OK":
            continue
        typ, data = im.search(None, "ALL")
        ids = data[0].split()
        print("%s: total=%d" % (folder, len(ids)), flush=True)
        cand[folder] = []
        for i in range(0, len(ids), BATCH):
            chunk = ids[i:i + BATCH]
            setq = ",".join(x.decode() for x in chunk)
            typ, resp = im.fetch(setq, "(RFC822.SIZE BODY.PEEK[HEADER])")
            if typ != "OK":
                continue
            cur_id = None
            for part in resp:
                if isinstance(part, tuple):
                    cur_id = None
                    m = re.match(rb"(\d+) \(RFC822\.SIZE (\d+)", part[0])
                    if m:
                        cur_id, size = int(m.group(1)), int(m.group(2))
                    if cur_id is None:
                        continue
                    hdr = email.message_from_bytes(part[1])
                    cls = classify(hdr, a.recent_days, now)
                    counts[cls] = counts.get(cls, 0) + 1
                    sizes[cls] = sizes.get(cls, 0) + size
                    if cls == "DELETE":
                        cand[folder].append((cur_id, size, dec(hdr.get("Message-ID")), dec(hdr.get("Date")), dec(hdr.get("From"))[:60], dec(hdr.get("Subject"))[:90]))
        print("  done %s" % folder, flush=True)

    print("\nCLASS COUNTS:")
    for k in sorted(counts):
        print("  %-16s %6d  %8.1f MB" % (k, counts[k], sizes.get(k, 0) / 1e6))
    total = sum(counts.get(k, 0) for k in counts if k.startswith("DELETE"))
    tsize = sizes.get("DELETE", 0) / 1e6
    print("  %-16s %6d  %8.1f MB" % ("=> DELETE", total, tsize))

    manifest = os.path.join(a.outdir, "manifest.tsv")
    with open(manifest, "w", encoding="utf-8") as f:
        f.write("folder\tuid\tbytes\tdate\tfrom\tsubject\tmessage-id\n")
        for folder, rows in cand.items():
            for r in rows:
                f.write("%s\t%d\t%d\t%s\t%s\t%s\t%s\n" % (folder, r[0], r[1], r[3], r[4].replace("\t", " "), r[5].replace("\t", " "), r[2]))
    print("manifest -> %s" % manifest)

    if not a.apply:
        return
    if not a.yes:
        sys.exit("拒绝执行：--apply 需要同时给 --yes（先看上面的计数与 manifest）")

    n = 0
    for folder, rows in cand.items():
        if not rows:
            continue
        im.select('"%s"' % folder, readonly=False)
        ids = [str(r[0]) for r in rows]
        if a.limit:
            ids = ids[:a.limit]
        for i in range(0, len(ids), BATCH):
            chunk = ids[i:i + BATCH]
            im.store(",".join(chunk), "+FLAGS", "(\\Deleted)")
            n += len(chunk)
            print("  %s: marked %d/%d" % (folder, n, len(ids)), flush=True)
        im.expunge()
        print("%s: expunged (folder)" % folder, flush=True)
    print("deleted %d messages" % n)
    im.logout()


if __name__ == "__main__":
    main()
