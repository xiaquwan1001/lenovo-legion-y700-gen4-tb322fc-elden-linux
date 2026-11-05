#!/usr/bin/env python3
"""out/*.img 归档器 —— out/ 只留在用件与取证件，历史镜像 mv 到 backup/out-history-<date>/。

为什么是 mv 而不是删
--------------------
每件 `out/*.img` 在 `versions/vk-kernel-identity.tsv` 都有身份行（号↔内核二进制↔源提交）。
删文件 = 永久失账（2026-10-17 换机事故的教训，`MEMORY.md`）；归档保留文件本体 + 逐件 sha。

与门禁的耦合（必须一起读）
--------------------------
`scripts/vk-identity.py` 扫描 `out/` **和** `backup/out-history-*/`；`.manifest` 一律留在
`out/`（已入库，是身份账），脚本回退到 `out/<basename>.manifest` 查找。因此：
  - 归档前后 `python3 scripts/vk-identity.py --all` 的 `C`（新鲜度）必须都是 0；
  - 归档后 `bash scripts/check-doctor.sh` 的 §5d 不得新增 FAIL/WARN。
**禁止**重跑 `scripts/vk-identity.py > versions/vk-kernel-identity.tsv`（换机后镜像缺失会
把整表清成 (no-payload)，见 `.pi/memory/MEMORY.md` 2026-10-17 条）。

用法
----
  python3 scripts/out-archive.py                 # dry-run：只打印清单与预估
  python3 scripts/out-archive.py --apply         # 真正 mv，并写归档账 + 回滚脚本
  python3 scripts/out-archive.py --apply --date 20261107

幂等：已在归档目录里的镜像不会再被处理；同名目标存在时跳过并报警（不覆盖）。
"""

import argparse
import glob
import hashlib
import os
import shutil
import sys
import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'out')

# 保留集：在机/在用线 + 可复现的最近线 + 取证锚点 + UEFI 唯一有效件。
# 判据与出处见 reports/out-archive-20261106.md §2；改动本表须同步该报告的「保留集」。
KEEP = {
    # build-boot.sh 默认产物（无版本号当前拷贝，每次构建重生）
    'boot-elden.img',
    # 在机/在用线：vk172（UTS 基准 + 设备 /lib/modules 匹配）、vk173、vk181-daily（复原件）、
    # vk182-camssv3、vk183-fastrpc（传感器/fastrpc 上机件）
    'boot-elden-vk172.img', 'boot-elden-vk173.img', 'boot-elden-vk181-daily.img',
    'boot-elden-vk182-camssv3.img', 'boot-elden-vk183-fastrpc.img',
    # M3-1 线（RESOURCES §3 / reports/m3v5-onboard-plan-20261030.md 在引）
    'boot-elden-m3v5-onboard.img', 'boot-elden-m3v5-onboard-b.img',
    'boot-elden-m3v5-f2.img',
    # 取证：2026-11-03 静默损坏件（PITFALLS #512 实物证据）
    'boot-elden-m3v5-daily.img',
    # UEFI：2026-11-03 DDR 黑匣子正控载荷（posctrl）
    'boot-elden-posctrl-20261103.img',
    # UEFI：唯一有效件 + TASKS §5 当前在引的三发
    'uefi-20261104R-r1.img', 'uefi-20261104-fixcopylen.img',
    'uefi-20261104R7-r1.img', 'uefi-20261104R21-hostdiag-r1.img',
}


def sha256(path, bufsize=1 << 20):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while True:
            b = f.read(bufsize)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def ledger_names():
    """vk-kernel-identity.tsv 里的 image 列（basename）。"""
    p = os.path.join(ROOT, 'versions', 'vk-kernel-identity.tsv')
    names = set()
    if os.path.exists(p):
        with open(p, errors='replace') as f:
            next(f, None)
            for line in f:
                c = line.rstrip('\n').split('\t')
                if len(c) > 1:
                    names.add(c[1])
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true', help='真正移动（默认 dry-run）')
    ap.add_argument('--date', default=None, help='归档批次日期（默认今天 YYYYMMDD）')
    args = ap.parse_args()

    date = args.date or datetime.date.today().strftime('%Y%m%d')
    dest = os.path.join(ROOT, 'backup', 'out-history-%s' % date)

    imgs = sorted(glob.glob(os.path.join(OUT, '*.img')))
    keep, arch = [], []
    for p in imgs:
        (keep if os.path.basename(p) in KEEP else arch).append(p)

    if not args.apply:
        print('== dry-run（未动盘）==')
        print('out/ 现有 *.img: %d' % len(imgs))
        print('保留: %d 件 / %.1f MiB' % (len(keep), sum(os.path.getsize(p) for p in keep) / 2**20))
        print('归档: %d 件 / %.1f MiB -> %s' % (
            len(arch), sum(os.path.getsize(p) for p in arch) / 2**20,
            os.path.relpath(dest, ROOT)))
        print('（同文件系统 rename ⇒ 净释放 0；要真回收空间需 tar.zst 或上云后删）')
        for p in keep:
            print('  KEEP   %-45s %6.1f MiB' % (os.path.basename(p), os.path.getsize(p) / 2**20))
        unlisted = [os.path.basename(p) for p in arch if os.path.basename(p) not in ledger_names()]
        if unlisted:
            print('  ⚠ 归档件不在身份表（无账可对）: %s' % ' '.join(unlisted))
        return 0

    os.makedirs(dest, exist_ok=True)
    led = ledger_names()
    rows, rolled = [], []
    for p in arch:
        base = os.path.basename(p)
        tgt = os.path.join(dest, base)
        if os.path.exists(tgt):
            print('SKIP（目标已存在，不覆盖）: %s' % base, file=sys.stderr)
            continue
        size = os.path.getsize(p)
        digest = sha256(p)                      # 先算后移：账本记的是迁移前的内容身份
        shutil.move(p, tgt)
        rows.append((digest, size, base, 'Y' if base in led else 'N',
                     os.path.relpath(tgt, ROOT)))
        rolled.append('mv "%s" "out/%s"' % (os.path.relpath(tgt, ROOT), base))
        print('mv %-45s %6.1f MiB' % (base, size / 2**20))

    if rows:
        tsv = os.path.join(dest, 'ARCHIVE.tsv')
        with open(tsv, 'w') as f:
            f.write('# out/ 历史镜像归档账（%s 生成；列=sha256/bytes/image/in_ledger/归档路径）\n'
                    % datetime.date.today().isoformat())
            f.write('# ⚠ 复核必须走 O_DIRECT（本机 2026-11-05 实测普通 read 会读到被位翻转的页缓存副本，'
                    '见 PITFALLS #513）：\n')
            f.write('#   grep -v \'^#\' ARCHIVE.tsv | while IFS=$\'\\t\' read -r s b n l path; do '
                    '[ "$(dd if="$path" iflag=direct bs=1M status=none | sha256sum | cut -d\' \' -f1)" = "$s" ] '
                    '|| echo "MISMATCH $path"; done\n')
            for r in rows:
                f.write('\t'.join(str(x) for x in r) + '\n')
        rb = os.path.join(dest, 'ROLLBACK.sh')
        with open(rb, 'w') as f:
            f.write('#!/bin/sh\n# 归档回滚（在仓库根执行）；生成于 %s\nset -e\ncd "$(dirname "$0")/../.."\n'
                    % datetime.date.today().isoformat())
            f.write('\n'.join(rolled) + '\n')
        os.chmod(rb, 0o755)
        print('\n归档 %d 件 / %.1f MiB -> %s' % (
            len(rows), sum(r[1] for r in rows) / 2**20, os.path.relpath(dest, ROOT)))
        print('账 = %s' % os.path.relpath(tsv, ROOT))
        print('回滚 = sh %s' % os.path.relpath(rb, ROOT))
    return 0


if __name__ == '__main__':
    sys.exit(main())
