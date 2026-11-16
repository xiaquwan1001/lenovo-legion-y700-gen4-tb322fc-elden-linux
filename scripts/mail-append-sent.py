#!/usr/bin/env python3
"""mail-append-sent.py — 把「已发出但 Sent Items 没有账」的邮件补写进 IMAP `Sent Items`。

为什么需要：`~/.local/bin/send-mail-ustc.py` 走 `smtplib`，发送成功后**不做 IMAP `APPEND`**
（Coremail 不会自动把 Bcc/自发件放进 Sent Items 时尤其明显）⇒ `mdss v5` 那批四封在 Sent Items
里查不到，邮件账与 lore 归档对不上（`reports/q28-dossier-B-mail-external.md` §⑤-3、`PITFALLS #…`）。
本工具只写**自己的** Sent Items，不改变已发出的任何邮件，零外部副作用。

用法（默认 dry-run，不联网、不登录）：
    scripts/mail-append-sent.py <file> [...]            # 打印计划：每个文件的 Subject / Message-ID / 动作
    scripts/mail-append-sent.py --check <file> [...]    # 联网只读：Sent Items 里按 Subject 查，列出缺哪些
    scripts/mail-append-sent.py --apply <file> [...]    # 联网只写：APPEND 缺的那些（已有的自动跳过）
    scripts/mail-append-sent.py --self-test             # 离线自测（stub IMAP，验证解析/去重/跳过逻辑）

输入可以是：
  * `.mbox`（多封，`From ` 分隔）/ 单封 `.eml`；
  * `git send-email` 生成的 `.patch`（RFC822-ish，有 From/Date/Subject）；
  * `send-mail-ustc.py` 的草稿（首部 `To:`/`Cc:`/`Subject:`/`In-Reply-To:`，空行后正文）。

判据/坑：
  * **去重靠 Subject**：`git send-email` 与 `send-mail-ustc.py` 的 Message-ID 都是发送时才生成，
    件里一般没有，所以「是否已在 Sent Items」用 `SEARCH HEADER Subject` 判定；`--apply` 时若件里
    没有 Message-ID 就现生成一个（会在输出里标明 `(new mid)`）—— 这只影响你本地存档的 MID，
    不影响收件人看到的线程（他们看的是真发出那封的 MID）。
  * IMAP 主机 = `mail.ustc.edu.cn:993`（`imap.ustc.edu.cn` 无 DNS）；`Sent Items` 必须带引号。
  * 凭据：环境 `MAILPW` / `USTC_MAIL_PW` → `--pw-stdin` → `keyring`（service=`smtp`,
    user=`xiaqinghuan@mail.ustc.edu.cn`，**5 s 预算**）→ `git credential fill`（10 s 预算）。
    **无桌面会话时 keyring 会无限阻塞等解锁提示**（2026-11-17 实测 `keyring.get_password` >25 s 无返回），
    所以给了预算并提示改用 `MAILPW=...`；`--check/--apply` 必须能登录 IMAP。
"""
import argparse
import email
import email.message
import email.utils
import imaplib
import re
import subprocess
import sys

HOST, PORT = "mail.ustc.edu.cn", 993
USER = "xiaqinghuan@mail.ustc.edu.cn"
FOLDER = '"Sent Items"'


# ---------------------------------------------------------------- 凭据
def get_pw(arg_stdin=False):
    """按序取密码：环境变量 → stdin → keyring(5 s 预算) → git credential(10 s 预算)。

    无桌面会话时 keyring 会一直阻塞等解锁提示（实测 `keyring.get_password` >25 s 无返回）
    ⇒ 一律加预算，超时就报错并提示用 `MAILPW=...`。
    """
    import os
    for k in ("MAILPW", "USTC_MAIL_PW"):
        if os.environ.get(k):
            return os.environ[k]
    if arg_stdin:
        pw = sys.stdin.readline().strip()
        if pw:
            return pw
    try:  # 2026-10-17：优先 GNOME keyring（service="smtp"），与桌面 keyring CLI 同一份
        import keyring
        import threading
        box = {}

        def _get():
            try:
                box["pw"] = keyring.get_password("smtp", USER)
            except Exception:
                box["pw"] = None

        t = threading.Thread(target=_get, daemon=True)
        t.start()
        t.join(5)
        if box.get("pw"):
            return box["pw"]
        if t.is_alive():
            print("[warn] keyring 5 s 未返回（多半是没解锁的 keyring）⇒ 跳过", file=sys.stderr)
    except Exception:
        pass
    inp = "protocol=smtp\nhost=smtp.ustc.edu.cn:465\nusername=%s\n\n" % USER
    try:
        c = subprocess.run(["git", "credential", "fill"], input=inp,
                           capture_output=True, text=True, timeout=10)
    except subprocess.TimeoutExpired:
        c = None
    if c is not None and c.returncode == 0:
        d = dict(l.split("=", 1) for l in c.stdout.strip().splitlines() if "=" in l)
        if "password" in d:
            return d["password"]
    sys.exit("取不到凭据：无桌面 keyring 时请 `MAILPW=... scripts/mail-append-sent.py --check …`")


# ---------------------------------------------------------------- 解析
def split_entries(raw):
    """把文件切成若干封原始字节。mbox 按行首 `From ` 切；否则整文件算一封。"""
    if raw.lstrip().startswith(b"From "):
        parts = re.split(rb"(?m)^From [^\n]*\n", raw)
        out = [p for p in parts if p.strip()]
        return out or [raw]
    return [raw]


def headers_of(raw):
    """返回 (subject, message_id, in_reply_to, date_raw)。容错：非标准草稿也能拿到首部。"""
    msg = email.message_from_bytes(raw)
    subj = msg.get("Subject")
    mid = msg.get("Message-ID") or msg.get("Message-Id")
    irt = msg.get("In-Reply-To")
    date = msg.get("Date")
    if not subj:
        for line in raw.split(b"\n\n", 1)[0].decode("utf-8", "replace").splitlines():
            if line.lower().startswith("subject:"):
                subj = line.split(":", 1)[1].strip()
    return (subj or "").strip(), mid, irt, date


def norm_subj(s):
    return re.sub(r"\s+", " ", (s or "").strip())


def search_key(subject):
    """去重用的检索串：剥掉所有开头的 `[...]` 标签（`[PATCH v5 1/3]` / `[PATCH]` / `[RFC]` …）。

    存原件里常常没有 `vN`（`git format-patch` 不带 `-v5` 就没有），而真发出去的有
    ⇒ 直接整串比对会假阴性；剥掉标签后取正文前缀，`HEADER Subject` 是子串匹配，跨版本前缀都能命中。
    """
    s = re.sub(r"^(re|fwd?|aw)\s*:\s*", "", norm_subj(subject), flags=re.I)
    s = re.sub(r"^(\[[^\]]*\]\s*)+", "", s).strip()
    return s[:80] or norm_subj(subject)[:80]


def load_files(paths):
    entries = []
    for p in paths:
        raw = open(p, "rb").read()
        for i, ent in enumerate(split_entries(raw)):
            subj, mid, irt, date = headers_of(ent)
            entries.append({"path": p, "idx": i, "raw": ent,
                            "subject": norm_subj(subj), "mid": (mid or "").strip(),
                            "irt": (irt or "").strip(), "date": date})
    return entries


def ensure_headers(raw):
    """给缺 Message-ID/Date 的件补上（只影响本地存档副本）。"""
    msg = email.message_from_bytes(raw)
    changed = False
    if not msg.get("Message-ID"):
        msg["Message-ID"] = email.utils.make_msgid(domain="mail.ustc.edu.cn")
        changed = True
    if not msg.get("Date"):
        msg["Date"] = email.utils.formatdate(localtime=True)
        changed = True
    if not changed:
        return raw, False
    return msg.as_bytes(policy=email.message_from_bytes(raw).policy), True


# ---------------------------------------------------------------- 动作
def fake_imap_factory(state):
    """self-test 用的极简 IMAP stub。state = {"sent": [subject,...], "appended": [...]}"""
    class FakeIMAP:
        def __init__(self, *a, **k):
            pass

        def login(self, u, p):
            return ("OK", [b"logged in"])

        def select(self, box, readonly=False):
            state["selected"] = box
            state["readonly"] = readonly
            return ("OK", [b"1"])

        def search(self, charset, *criteria):
            # criteria = ('HEADER', 'Subject', '<subj>')
            want = (criteria[2].decode() if isinstance(criteria[2], bytes) else criteria[2])
            hits = [str(i + 1).encode() for i, s in enumerate(state["sent"])
                    if want.lower() in norm_subj(s).lower()]
            return ("OK", [b" ".join(hits)])

        def append(self, box, flags, date_time, msg):
            state["appended"].append({"box": box, "bytes": len(msg)})
            msg_subj = norm_subj(email.message_from_bytes(msg).get("Subject") or "")
            state["sent"].append(msg_subj)
            return ("OK", [b"appended"])

        def logout(self):
            return ("BYE", [b""])

    return FakeIMAP


def run(entries, mode, imap_cls=None, state=None, pw_stdin=False):
    plan = []
    if mode in ("check", "apply"):
        pw = "self-test" if imap_cls else get_pw(pw_stdin)
        M = imap_cls(HOST, PORT) if imap_cls else imaplib.IMAP4_SSL(HOST, PORT, timeout=30)
        M.login(USER, pw)
        M.select(FOLDER, readonly=(mode == "check"))
    for e in entries:
        present = None
        if mode in ("check", "apply"):
            typ, data = M.search(None, "HEADER", "Subject",
                                search_key(e["subject"]).encode("utf-8"))
            present = bool(data and data[0].strip())
        action = "would-append"
        note = ""
        if present is True:
            action, note = "skip", "already in Sent Items (subject match)"
        elif present is False:
            action = "append-missing"
        plan.append((e, action, note))
        if mode == "apply" and action == "append-missing":
            raw, added = ensure_headers(e["raw"])
            M.append(FOLDER, None, None, raw)
            note = "appended" + (" (new mid)" if added else " (kept mid)")
            plan[-1] = (e, "appended", note)
    if mode in ("check", "apply"):
        M.logout()
    return plan


def report(plan, mode):
    width = max([len(e["path"]) for e, _, _ in plan] + [10])
    for e, action, note in plan:
        subj = e["subject"][:78] + ("…" if len(e["subject"]) > 78 else "")
        print("%-*s [%s] %-15s %s" % (width, e["path"], e["idx"], action, subj))
        if e["mid"]:
            print("    mid  : %s" % e["mid"])
        if e["irt"]:
            print("    reply: %s" % e["irt"])
        if note:
            print("    note : %s" % note)
    miss = [x for x in plan if x[1] == "append-missing"]
    if mode == "dry-run":
        print("\n合计 %d 封待核对（dry-run：未联网，是否缺账需 --check 才知）" % len(plan))
        print("下一步：`--check` 只读核对 → `--apply` 补写。")
    else:
        print("\n合计 %d 封：Sent Items 缺账 %d 封（已写入 %d 封）" % (
            len(plan), len(miss), len([x for x in plan if x[1] == "appended"])))


def self_test():
    entries = [
        {"path": "stub-a.patch", "idx": 0, "raw": b"From: a\nSubject: [PATCH v5 1/3] one\n\nbody\n",
         "subject": "[PATCH v5 1/3] one", "mid": "", "irt": "", "date": None},
        {"path": "stub-a.patch", "idx": 1, "raw": b"From: a\nSubject: [PATCH v5 2/3] two\n\nbody\n",
         "subject": "[PATCH v5 2/3] two", "mid": "", "irt": "", "date": None},
    ]
    state = {"sent": ["[PATCH v5 2/3] two"], "appended": []}  # 存原件无 vN 也要能命中
    imap = fake_imap_factory(state)
    plan = run(entries, "check", imap_cls=imap, state=state)
    assert plan[0][1] == "append-missing", plan
    assert plan[1][1] == "skip", plan
    plan = run(entries, "apply", imap_cls=imap, state=state)
    assert plan[0][1] == "appended", plan
    assert plan[1][1] == "skip", plan
    assert len(state["appended"]) == 1, state
    assert state["selected"] == '"Sent Items"', state
    # 再跑一次 apply：这次全都该跳过（幂等）
    plan = run(entries, "apply", imap_cls=imap, state=state)
    assert all(p[1] == "skip" for p in plan), plan
    assert len(state["appended"]) == 1, state
    # 解析器：单封 .patch / mbox 多封 / 缺 Date
    raw = b"From x Mon Jan  1 00:00:00 2026\nFrom: a\nSubject: s1\n\nb1\nFrom x Mon Jan  1 00:00:01 2026\nFrom: a\nSubject: s2\n\nb2\n"
    assert len(split_entries(raw)) == 2, split_entries(raw)
    assert len(split_entries(b"From: a\nSubject: s\n\nb\n")) == 1
    fixed, added = ensure_headers(b"From: a\nSubject: s\n\nb\n")
    assert added is True and b"Message-ID:" in fixed and b"Date:" in fixed
    print("self-test: PASS (解析/去重/幂等/补头 4 组)")


def main():
    ap = argparse.ArgumentParser(add_help=True, description=__doc__.splitlines()[0])
    ap.add_argument("files", nargs="*")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--check", action="store_true", help="只读：列出 Sent Items 缺哪些")
    g.add_argument("--apply", action="store_true", help="补写缺的那些（幂等）")
    g.add_argument("--self-test", action="store_true", help="离线自测")
    ap.add_argument("--pw-stdin", action="store_true", help="从 stdin 读密码（默认试 keyring/git credential）")
    a = ap.parse_args()
    if a.self_test:
        self_test()
        return
    if not a.files:
        sys.exit(__doc__)
    entries = load_files(a.files)
    mode = "apply" if a.apply else ("check" if a.check else "dry-run")
    report(run(entries, mode, pw_stdin=a.pw_stdin), mode)


if __name__ == "__main__":
    main()
