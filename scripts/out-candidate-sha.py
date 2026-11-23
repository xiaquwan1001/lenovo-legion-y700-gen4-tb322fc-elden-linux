#!/usr/bin/env python3
"""out-candidate-sha.py — 「上机候选件」的 sha 账目门（out/ 生命周期账本 ↔ 件 ↔ 记录）。

为什么需要（2026-11-24）：`out/` 只有两道账本门（§23 大件必须有报告、§25 active/verified/
pending/superseded 状态 ↔ 磁盘），**没有一道门核对「账本里的件与它自己的 sha 记录是否一致」**。
上机前真正要看的是后者：本机 RAM 不稳（随机单字节翻转有取证记录），一枚 `boot*.img` / `esp*.img`
如果和它的 `.sha256` / `SHA256SUMS` 对不上，刷下去就是一次不可归因的失败。

判据（只认**机器可读**的记录，避免猜）：
  1. `<dir>/SHA256SUMS*`（非 .md）：经典 `sha  path`（两空格）或 TSV `path \\t size \\t sha`
  2. `<dir>/*.sha256` 侧车：`sha  path`（path 可写相对 dir 或仓库相对）
  3. 记录里的 path 解析：以 `out/` 开头 ⇒ 相对仓库根，否则相对该 dir
三态：记录存在且一致 = OK；记录存在但不一致 = **FAIL**；件存在但没有任何记录 = **WARN**；
      记录指向的件不存在 = WARN（记录腐坏，但不阻塞上机判断）。

用法：
  python3 scripts/out-candidate-sha.py --check     # 扫 versions/out-artifacts.tsv 里 active/pending/verified 的目录
  python3 scripts/out-candidate-sha.py --selftest  # 合成树自检（正例/反例/缺记录/腐坏记录）

退出码：0 = 无 FAIL；1 = 有 FAIL（sha 不一致）；2 = 用法错误。
"""
import hashlib
import os
import shutil
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEDGER = os.path.join(ROOT, "versions", "out-artifacts.tsv")
SHA_LEDGER = os.path.join(ROOT, "versions", "out-candidate-sha.tsv")
CANDIDATE_STATES = ("active", "pending", "verified")


def sha256_file(path, chunk=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def _looks_like_sha(s):
    return len(s) == 64 and all(c in "0123456789abcdef" for c in s)


def parse_records(dirpath, root=ROOT):
    """→ {abs_path: [(sha, source_line_label)]}；只收机器可读格式"""
    recs = {}
    names = []
    for n in sorted(os.listdir(dirpath)):
        p = os.path.join(dirpath, n)
        if not os.path.isfile(p):
            continue
        if n.startswith("SHA256SUMS") and not n.endswith(".md"):
            names.append(n)
        elif n.endswith(".sha256"):
            names.append(n)
    for n in names:
        p = os.path.join(dirpath, n)
        try:
            lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            continue
        for ln in lines:
            ln = ln.strip()
            if not ln or ln.startswith("#"):
                continue
            parts = ln.split()
            if len(parts) >= 3 and "\t" in ln:
                # TSV：path \t size \t sha
                path, _size, sha = ln.split("\t")[0], ln.split("\t")[1], ln.split("\t")[-1].strip()
            elif len(parts) >= 2 and _looks_like_sha(parts[0]):
                sha, path = parts[0], " ".join(parts[1:])
                path = path.lstrip("*")  # sha256sum -b 的二进制前缀
            else:
                continue
            if not _looks_like_sha(sha):
                continue
            ap = path if path.startswith("out/") else os.path.join(dirpath, path)
            ap = os.path.normpath(os.path.join(root, ap) if not os.path.isabs(ap) else ap)
            recs.setdefault(ap, []).append((sha, n))
    return recs


def parse_sha_ledger(path=SHA_LEDGER, root=ROOT):
    """versions/out-candidate-sha.tsv → {abs_path: sha}（入库的可追溯身份账；out/ 二进制本身不入库）"""
    recs = {}
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return recs
    for ln in lines:
        if not ln.strip() or ln.startswith("#"):
            continue
        f = ln.split("\t")
        if len(f) < 2:
            continue
        rel, sha = f[0].strip(), f[1].strip()
        if not _looks_like_sha(sha):
            continue
        recs[os.path.normpath(os.path.join(root, rel))] = sha
    return recs


def check(check_root=ROOT, ledger=LEDGER, verbose=True):
    fails, warns, oks = [], [], []
    dirs = []
    try:
        for ln in open(ledger, encoding="utf-8"):
            if ln.startswith("#") or not ln.strip():
                continue
            f = ln.rstrip("\n").split("\t")
            if len(f) >= 2 and f[1].strip() in CANDIDATE_STATES:
                dirs.append((f[0].strip(), f[1].strip()))
    except OSError as e:
        return None, [f"账本不可读：{e}"], 1
    if not dirs:
        return None, [f"账本里没有 {'/'.join(CANDIDATE_STATES)} 状态的目录"], 0

    for rel, state in dirs:
        d = os.path.join(check_root, rel)
        if not os.path.isdir(d):
            warns.append(f"{rel}（{state}）目录不在盘")
            continue
        recs = parse_records(d, check_root)
        for _ap, _sh in parse_sha_ledger(os.path.join(os.path.dirname(ledger), "out-candidate-sha.tsv"), check_root).items():
            if _ap.startswith(os.path.normpath(d) + os.sep):
                recs.setdefault(_ap, []).append((_sh, "versions/out-candidate-sha.tsv"))
        imgs = sorted(n for n in os.listdir(d) if n.endswith(".img") and os.path.isfile(os.path.join(d, n)))
        for n in imgs:
            ap = os.path.normpath(os.path.join(d, n))
            got = recs.get(ap)
            if not got:
                warns.append(f"{rel}/{n}：没有任何 sha 记录（.sha256 / SHA256SUMS*）")
                continue
            act = sha256_file(ap)
            # 多条记录（目录侧车 + 入库账本）之间也必须一致：任一条与实物不符即 FAIL
            bad = [(sh, src) for sh, src in got if sh != act]
            if not bad:
                srcs = ",".join(sorted({src for _sh, src in got}))
                oks.append(f"{rel}/{n}  sha={act[:16]}…（记录 {srcs}）")
            else:
                for sh, src in bad:
                    fails.append(f"{rel}/{n}  sha 不一致：件={act[:16]}… 记录={sh[:16]}…（{src}）")
        # 记录里指向 other 件的行：件在就必须一致（件不在只 WARN）
        for ap, lst in recs.items():
            if not ap.endswith(".img") or os.path.normpath(os.path.join(d, os.path.basename(ap))) in [
                os.path.normpath(os.path.join(d, x)) for x in imgs
            ]:
                continue
            if not os.path.exists(ap):
                warns.append(f"{rel}：记录指向不存在的 {os.path.relpath(ap, check_root)}（{lst[0][1]}）")
                continue
            act = sha256_file(ap)
            if act != lst[0][0]:
                fails.append(f"{os.path.relpath(ap, check_root)}  sha 不一致：件={act[:16]}… 记录={lst[0][0][:16]}…（{lst[0][1]}）")
            else:
                oks.append(f"{os.path.relpath(ap, check_root)}  sha={act[:16]}…（记录 {lst[0][1]}）")
    if verbose:
        for x in oks:
            print(f"  [ok]   {x}")
        for x in warns:
            print(f"  [warn] {x}")
        for x in fails:
            print(f"  [FAIL] {x}")
    return (oks, warns, fails), None, (1 if fails else 0)


def selftest():
    tmp = tempfile.mkdtemp(prefix="out-sha-selftest.")
    try:
        def mk(p, data=b"x"):
            ap = os.path.join(tmp, p)
            os.makedirs(os.path.dirname(ap), exist_ok=True)
            with open(ap, "wb") as f:
                f.write(data)
            return ap

        # 1) 正例：侧车 sha 正确
        d1 = os.path.join(tmp, "out/good-1")
        mk("out/good-1/boot.img", b"hello")
        good = hashlib.sha256(b"hello").hexdigest()
        mk("out/good-1/boot.img.sha256", f"{good}  boot.img\n".encode())
        # 2) 反例：侧车 sha 错
        d2 = os.path.join(tmp, "out/bad-1")
        mk("out/bad-1/boot.img", b"hello")
        mk("out/bad-1/boot.img.sha256", f"{'0'*64}  boot.img\n".encode())
        # 3) 缺记录 → WARN
        d3 = os.path.join(tmp, "out/norec-1")
        mk("out/norec-1/boot.img", b"hello")
        # 4) SHA256SUMS.tsv 正例（仓库相对路径）
        d4 = os.path.join(tmp, "out/tsv-1")
        mk("out/tsv-1/esp.img", b"esp")
        espsha = hashlib.sha256(b"esp").hexdigest()
        mk("out/tsv-1/SHA256SUMS.tsv", f"out/tsv-1/esp.img\t3\t{espsha}\n".encode())
        # 5) 记录指向不存在的件 → WARN
        d5 = os.path.join(tmp, "out/ghost-1")
        os.makedirs(d5, exist_ok=True)
        mk("out/ghost-1/SHA256SUMS", f"{'a'*64}  out/ghost-1/gone.img\n".encode())
        # 6) 经典两空格格式 + dir 相对路径
        d6 = os.path.join(tmp, "out/classic-1")
        mk("out/classic-1/boot.img", b"cl")
        csha = hashlib.sha256(b"cl").hexdigest()
        mk("out/classic-1/SHA256SUMS", f"{csha}  boot.img\n".encode())

        ledger = os.path.join(tmp, "ledger.tsv")
        with open(ledger, "w", encoding="utf-8") as f:
            f.write("# out/<dir>\t状态\t依据\n")
            for d in (d1, d2, d3, d4, d5, d6):
                f.write(f"{os.path.relpath(d, tmp)}\t{'verified' if 'good' in d or 'classic' in d or 'tsv' in d else 'pending'}\ttest\n")
            f.write("out/not-there\tpending\tmissing dir\n")

        res, err, rc = check(check_root=tmp, ledger=ledger, verbose=False)
        oks, warns, fails = res if res else ([], err or [], [])
        n_ok_good = sum(1 for x in oks if "good-1/boot.img" in x or "classic-1/boot.img" in x or "tsv-1/esp.img" in x)
        n_bad = sum(1 for x in fails if "bad-1/boot.img" in x)
        n_warn_nores = sum(1 for x in warns if "norec-1" in x)
        n_warn_ghost = sum(1 for x in warns if "ghost-1" in x)
        n_warn_missing_dir = sum(1 for x in warns if "not-there" in x)
        cases = [
            ("正例 3 件（侧车/经典/TSV）都判 OK", n_ok_good == 3),
            ("反例 1 件（sha 错）判 FAIL", n_bad == 1),
            ("缺记录判 WARN", n_warn_nores == 1),
            ("记录指向缺件判 WARN", n_warn_ghost == 1),
            ("账本里的 dir 不在盘判 WARN", n_warn_missing_dir == 1),
            ("有 FAIL ⇒ rc=1", rc == 1),
        ]
        ok_all = True
        for name, passed in cases:
            print(f"  [{'PASS' if passed else 'FAIL'}] {name}")
            ok_all = ok_all and passed
        print(f"== out-candidate-sha selftest {'PASS' if ok_all else 'FAIL'} ({sum(1 for _, p in cases if p)}/{len(cases)}) ==")
        return 0 if ok_all else 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main(argv):
    if "--selftest" in argv:
        return selftest()
    if "--check" in argv:
        res, err, rc = check()
        if err:
            for e in err:
                print(f"  [warn] {e}")
        if res:
            oks, warns, fails = res
            print(f"== 候选件 sha：OK={len(oks)} WARN={len(warns)} FAIL={len(fails)} ==")
        return rc
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
