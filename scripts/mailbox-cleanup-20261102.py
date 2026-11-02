#!/usr/bin/env python3
"""USTC mailbox cleanup 2026-11-02.

Three stages:
  --backup    dump INBOX / Junk E-mail / Sent Items to ~/Mail/ustc-backup-20261102/<folder>.mbox (BODY.PEEK)
  --classify  classify all messages into KEEP-OURS / KEEP-HUMAN / KEEP-RECENT / DELETE, print counts
  --delete    EXPUNGE DELETE-class messages in batches of 500 (Trash/Junk first, then INBOX)
  --dry-run   with --delete: compute and log batches without issuing STORE/EXPUNGE
Password is taken from GNOME keyring (secret-tool lookup service smtp), never written anywhere.

Classification (one class per message):
  KEEP-OURS   References/In-Reply-To contains mail.ustc.edu.cn, or Subject/Message-ID hits our series keywords
  KEEP-HUMAN  From domain in maintainer whitelist and not a bot notification
  KEEP-RECENT Date within last 45 days
  DELETE      everything else (bulk list traffic / bot notices / bounces / subscribes / spam)
DELETE requires: not ours AND not a maintainer human AND older than 45 days.
"""
import argparse
import email
import email.header
import email.utils
import imaplib
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone

HOST = 'mail.ustc.edu.cn'
USER = 'xiaqinghuan@mail.ustc.edu.cn'
BACKUP_DIR = os.path.expanduser('~/Mail/ustc-backup-20261102')
STATE = os.path.expanduser('~/Mail/ustc-backup-20261102/classify-state.json')
BATCH = 500
RECENT_DAYS = 45

BACKUP_FOLDERS = ['INBOX', 'Junk E-mail', 'Sent Items']

OURS_PATTERNS = [
    'aw86927', 'camss', 'mdss', 'dwc3', 'battmgr', 'dispcc', 'wl2868c',
    'nt36536', 'B5', 'bonded', 'sm8750', 'elden', 'TB322FC', 'q6v5',
    'pcie', 'q28', 'q24', 'aw88461', 'mdss-common', 'cci',
]

HUMAN_DOMAINS = [
    'kernel.org', 'oss.qualcomm.com', 'linaro.org', 'baylibre.com',
    'sirena.org.uk', 'bootlin.com', 'collabora.com',
]

BOT_HINTS = [
    'mailer-daemon', 'no-reply', 'noreply', 'donotreply', 'bounces',
    'notifications@', 'noreply@', 'bounce+', 'list <', 'majordomo',
    'lists.', '-bounces@', 'bot', 'ci_notify', 'patchwork', 'lore+',
    'dmarc', 'postmaster',
]


def get_password():
    r = subprocess.run(['secret-tool', 'lookup', 'service', 'smtp'],
                       capture_output=True, text=True)
    pw = r.stdout.strip()
    if not pw:
        sys.exit('ERROR: keyring service=smtp returned empty password')
    return pw


def connect():
    m = imaplib.IMAP4_SSL(HOST, 993)
    m.login(USER, get_password())
    return m


def dec(s):
    if s is None:
        return ''
    if isinstance(s, bytes):
        s = s.decode('utf-8', 'replace')
    try:
        parts = email.header.decode_header(s)
        out = []
        for t, cs in parts:
            out.append(t.decode(cs or 'utf-8', 'replace') if isinstance(t, bytes) else t)
        return ' '.join(out)
    except Exception:
        return s


def parse_date(msg):
    d = msg.get('Date')
    if not d:
        return None
    try:
        dt = email.utils.parsedate_to_datetime(d)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


def ours_hit(blob):
    # word-boundary match; short tokens require case-sensitive form to avoid
    # matching inside random Message-IDs (e.g. 'b5' inside base64-ish ids)
    short = {'B5', 'cci', 'q24', 'q28'}
    for p in OURS_PATTERNS:
        flags = 0 if p in short else re.IGNORECASE
        if re.search(r'(?<![\w.-])' + re.escape(p) + r'(?![\w-])', blob, flags):
            return p
    return None


AGGRESSIVE = False
RECENT_OVERRIDE = None


def addressed_to_me(msg):
    hdr = ' '.join([dec(msg.get('To', '')), dec(msg.get('Cc', ''))])
    return 'xiaqinghuan@mail.ustc.edu.cn' in hdr.lower()


def classify_one(msg, now):
    """Return (klass, reason)."""
    refs = (msg.get('References') or '') + ' ' + (msg.get('In-Reply-To') or '')
    subject = dec(msg.get('Subject', ''))
    mid = (msg.get('Message-ID') or '')
    blob = subject + ' ' + mid
    if 'mail.ustc.edu.cn' in refs.lower():
        return 'KEEP-OURS', 'refs-ustc'
    kw = ours_hit(blob)
    if kw:
        return 'KEEP-OURS', f'kw:{kw}'
    frm = dec(msg.get('From', ''))
    fl = frm.lower()
    dt = parse_date(msg)
    human = False
    for dom in HUMAN_DOMAINS:
        if dom in fl and not any(h in fl for h in BOT_HINTS):
            human = True
            break
    # --aggressive (2026-11-02 第二轮)：维护者域名只说明「他方列表流水由维护者发出」，
    # 与我方无关时不保留；仅保留「直接发给我的」邮件。
    if human and (not AGGRESSIVE or addressed_to_me(msg)):
        return 'KEEP-HUMAN', 'maintainer'
    _rd = RECENT_OVERRIDE if RECENT_OVERRIDE is not None else RECENT_DAYS
    if dt and (now - dt) <= timedelta(days=_rd):
        return 'KEEP-RECENT', 'recent45'
    if human:
        return 'KEEP-HUMAN', 'maintainer-old'  # unreachable, kept for clarity
    return 'DELETE', 'stale-bulk'


def mbox_path(folder):
    safe = folder.replace(' ', '_').replace('/', '_')
    return os.path.join(BACKUP_DIR, safe + '.mbox')


def cmd_backup(args):
    m = connect()
    os.makedirs(BACKUP_DIR, exist_ok=True)
    for folder in BACKUP_FOLDERS:
        typ, cnt = m.select(f'"{folder}"', readonly=True)
        n = int(cnt[0])
        out = mbox_path(folder)
        tmp = out + '.part'
        written = 0
        with open(tmp, 'wb') as f:
            for start in range(1, n + 1, BATCH):
                end = min(start + BATCH - 1, n)
                typ, data = m.fetch(f'{start}:{end}',
                                    '(BODY.PEEK[] RFC822.SIZE)')
                for item in data:
                    if not isinstance(item, tuple):
                        continue
                    raw = item[1]
                    f.write(b'From MAILER-DAEMON %s\n' %
                            time.strftime('%a %b %e %H:%M:%S %Y').encode())
                    # mboxrd: escape body lines matching /^>*From /
                    raw = re.sub(rb'(\n|^)(>*From )', rb'\1>\2', raw)
                    f.write(raw)
                    f.write(b'\n')
                    written += 1
                print(f'  {folder}: {end}/{n}', flush=True)
        os.replace(tmp, out)
        # verify: server count == From lines
        with open(out, 'rb') as f:
            fromlines = sum(1 for ln in f if ln.startswith(b'From '))
        ok = 'OK' if fromlines == n else 'MISMATCH'
        print(f'{folder}: server={n} mbox_fromlines={fromlines} {ok} '
              f'size={os.path.getsize(out)}')
    m.logout()


def load_state(m):
    if os.path.exists(STATE):
        with open(STATE) as f:
            st = json.load(f)
        if st.get('counts_match'):
            return st
    raise SystemExit('classify state missing/stale; run --classify first')


def iter_classified(m, folder):
    typ, cnt = m.select(f'"{folder}"', readonly=True)
    n = int(cnt[0])
    now = datetime.now(timezone.utc)
    for start in range(1, n + 1, BATCH):
        end = min(start + BATCH - 1, n)
        typ, data = m.fetch(f'{start}:{end}',
                            '(UID BODY.PEEK[HEADER.FIELDS (MESSAGE-ID SUBJECT FROM DATE REFERENCES IN-REPLY-TO)])')
        for item in data:
            if not isinstance(item, tuple):
                continue
            mu = re.search(rb'UID (\d+)', item[0])
            uid = mu.group(1).decode() if mu else item[0].decode().split()[0]
            raw = item[1]
            msg = email.message_from_bytes(raw)
            klass, reason = classify_one(msg, now)
            mid = msg.get('Message-ID') or f'<no-mid-uid{uid}>'
            yield folder, int(uid), mid, klass, reason


def cmd_classify(args):
    m = connect()
    counts = {}
    per_folder = {}
    state = {'generated': datetime.now().isoformat(), 'folders': {}}
    for folder in ['INBOX', 'Junk E-mail', 'Trash']:
        typ, cnt = m.select(f'"{folder}"', readonly=True)
        n = int(cnt[0])
        per_folder[folder] = {'total': n, 'DELETE': 0}
        for _, seq, mid, klass, reason in iter_classified(m, folder):
            counts[klass] = counts.get(klass, 0) + 1
            if klass == 'DELETE':
                per_folder[folder]['DELETE'] += 1
                state['folders'].setdefault(folder, []).append([seq, mid])
        print(f'{folder}: total={n} delete={per_folder[folder]["DELETE"]}', flush=True)
    print('CLASS COUNTS:', json.dumps(counts, indent=1))
    state['counts'] = counts
    state['per_folder'] = per_folder
    state['counts_match'] = True
    with open(STATE, 'w') as f:
        json.dump(state, f)
    print('state ->', STATE)
    m.logout()


def cmd_delete(args):
    m = connect()
    st = load_state(m)
    batches = 0
    total_del = 0
    for folder in ['Junk E-mail', 'Trash', 'INBOX']:
        uids = [s for s, _ in st['folders'].get(folder, [])]
        if not uids:
            continue
        typ, cnt = m.select(f'"{folder}"', readonly=False)
        for i in range(0, len(uids), BATCH):
            chunk = uids[i:i + BATCH]
            uidset = ','.join(map(str, chunk))
            if args.dry_run:
                print(f'batch {batches+1} {folder}: would delete {len(chunk)} (uids)')
            else:
                typ, _ = m.uid('STORE', uidset, '+FLAGS', '(\\Deleted)')
                assert typ == 'OK', f'STORE failed {folder} {uidset}'
                m.expunge()
                total_del += len(chunk)
            batches += 1
            typ, cnt = m.select(f'"{folder}"')
            remaining = int(cnt[0])
            print(f'batch {batches} {folder}: planned={len(chunk)} '
                  f'deleted={len(chunk) if not args.dry_run else 0} remaining={remaining}')
    # close all folders with expunge
    for folder in ['Junk E-mail', 'Trash', 'INBOX']:
        m.select(f'"{folder}"')
        m.expunge()
        m.close()
    print(f'TOTAL deleted={total_del} batches={batches} dry_run={args.dry_run}')
    # final counts
    for folder in ['INBOX', 'Drafts', 'Sent Items', 'Trash', 'Junk E-mail', 'Virus Items']:
        typ, cnt = m.select(f'"{folder}"', readonly=True)
        print(f'  {folder}: {cnt[0].decode()}')
    m.logout()


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--backup', action='store_true')
    g.add_argument('--classify', action='store_true')
    g.add_argument('--delete', action='store_true')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--recent-days', type=int, default=None,
                    help='覆盖「非我方邮件保留天数」窗口（默认 45；配合 --aggressive 用 7）')
    ap.add_argument('--aggressive', action='store_true',
                    help='维护者域名≠保留：只保留直接发给我的（仍保留 45 天内与我方线程）')
    args = ap.parse_args()
    global AGGRESSIVE
    AGGRESSIVE = bool(getattr(args, 'aggressive', False))
    global RECENT_OVERRIDE
    RECENT_OVERRIDE = getattr(args, 'recent_days', None)
    if args.backup:
        cmd_backup(args)
    elif args.classify:
        cmd_classify(args)
    else:
        cmd_delete(args)


if __name__ == '__main__':
    main()
