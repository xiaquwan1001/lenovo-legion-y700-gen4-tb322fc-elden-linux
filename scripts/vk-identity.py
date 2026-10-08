#!/usr/bin/env python3
"""vk-identity.py — 构建号(vkN/语义名) ↔ 内核二进制 ↔ 内核源提交 的对齐表生成器。

为什么需要：`vkN` 由 scripts/lane.sh alloc 分配，本质是 **boot image 构建流水号**，
但历史上它同时被当作内核 LOCALVERSION 用。结果三种失真同时存在：
  同号不同内核（vk60/61/62/63 内核实为同一个 vk47clean 二进制）
  不同号同内核（vk42 == vk52-slim；vk54 == vk56/vk57-slim）
  同 UTS 串不同二进制（athm / wifi-* 沿用 vk47clean 的 LOCALVERSION 但重编过）
唯一可靠的「内核身份」= 镜像内核载荷解压后的 sha256。本脚本把它算出来并和
registry 号、manifest 记录、内核仓 ref 状态四列对齐，输出 TSV。

用法：  scripts/vk-identity.py > versions/vk-kernel-identity.tsv
        scripts/vk-identity.py --check    # 与已提交 TSV 比对，不一致退出 1（新鲜度门）
        scripts/vk-identity.py --gate     # check-doctor §5d 用：输出 OK/WARN/FAIL<TAB>消息

命名/溯源规则（2026-10-08 生效，只约束生效时刻之后新打的镜像）：
  硬错（FAIL，除非登记不可）：tree_drift dirty_drift src_missing src_unreachable
                                  uts_dup（同串不同二进制）num_ne_tag（源提交上无任何同名 vkNN ref）
                                  unversioned（无版本号的“当前拷贝”）
  软问题（WARN）：no_manifest tree_head_missing tree_head_diff src_no-sha kbin_shared unversioned
  生效时刻之前的存量一律汇总为 WARN（欠账清单就在表里，逐镜像登记在
  versions/vk-ledger-known-issues.tsv）。可用 VK_RULE_EPOCH 覆盖生效时刻。
"""
import collections
import glob
import hashlib
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'out')
REG = os.path.join(ROOT, 'versions', 'vk-registry.tsv')
KERNEL = os.path.join(ROOT, 'geekidos-linux')
TSV = os.path.join(ROOT, 'versions', 'vk-kernel-identity.tsv')
INFLIGHT = os.path.join(ROOT, 'versions', 'vk-identity-inflight.txt')

COLS = ['build', 'image', 'reg', 'img_uts', 'kbin_sha', 'src_sha', 'src_ref',
        'src_tag', 'tree_head', 'tree_state', 'flag']


def git(*a):
    return subprocess.run(('git', '-C', KERNEL) + a, capture_output=True,
                          text=True).stdout


def load_registry():
    nums = set()
    if os.path.exists(REG):
        for line in open(REG, errors='replace'):
            m = re.match(r'^vk(\d+)\t', line)
            if m:
                nums.add(int(m.group(1)))
    return nums


def inflight_images():
    """在途构建清单（被其它会话反复重建的镜像 basename）：不进新鲜度门，避免误击。"""
    if not os.path.exists(INFLIGHT):
        return set()
    return {l.split('#')[0].strip() for l in open(INFLIGHT)
            if l.strip() and not l.startswith('#')}


def kernel_refs():
    """(主线可达集, 任意 ref 可达集) —— 用来判定镜像内 sha 属于哪条线。"""
    return set(git('rev-list', 'HEAD').split()), set(git('rev-list', '--all').split())


def containing_refs(full):
    """非主线 sha 的归属 ref（只在少数儿上调）。archive/* 留档 tag 不算归属。"""
    out = git('for-each-ref', '--contains', full, '--format=%(refname:short)').split()
    return [r for r in out if not r.startswith('archive/')] or out


def _ref_deref(pattern):
    m = {}
    for line in git('for-each-ref', pattern,
                    '--format=%(refname:short)\t%(objectname)\t%(*objectname)').splitlines():
        parts = line.split('\t')
        if len(parts) != 3:
            continue
        name, obj, deref = parts
        sha = deref or obj          # annotated → 指向的 commit；lightweight/分支 → 就是 commit
        if sha:
            m.setdefault(sha, []).append(name)
    return m


def tag_map():
    """{commit: [tag名]}，**只 refs/tags**。annotated 走 %(*objectname)，
    **lightweight 只有 %(objectname)**，两者都得收（vk64 就是别的会话打的 lightweight tag）。"""
    return _ref_deref('refs/tags')


def points_at_map():
    """{commit: [ref名]} = 所有**指在**该提交上的 ref（分支头 + tag，archive/* 除外）。
    号↔源对齐用它：分支头也是证据（elden/vk53-hw 的头就是 vk64 提交）。"""
    m = {}
    for pat in ('refs/heads', 'refs/tags'):
        for sha, names in _ref_deref(pat).items():
            m.setdefault(sha, []).extend(n for n in names if not n.startswith('archive/'))
    return {k: sorted(set(v)) for k, v in m.items()}


def payload(path):
    """boot.img 的内核载荷：首段 gzip → (UTS release, 解压 Image 的 sha12)。"""
    try:
        import zlib
        d = open(path, 'rb').read()
        i = d.find(b'\x1f\x8b\x08')
        if i < 0:
            return None, ''
        k = zlib.decompressobj(wbits=16 + zlib.MAX_WBITS).decompress(d[i:], 128 << 20)
    except Exception:
        return None, ''
    m = re.search(rb'Linux version (\S+)', k)
    uts = m.group(1).decode('latin1').split(' ')[0] if m else ''
    return uts or None, hashlib.sha256(k).hexdigest()[:12]


def manifest(path):
    d = {}
    try:
        for line in open(path, errors='replace'):
            if '=' in line and not line.startswith('#'):
                k, v = line.rstrip('\n').split('=', 1)
                d[k.strip()] = v.strip()
    except OSError:
        pass
    return d


HARD = ('tree_drift', 'dirty_drift', 'payload_mismatch', 'src_missing', 'src_unreachable',
        'uts_dup', 'num_ne_tag')
# unversioned = out/boot-elden.img 这类**无版本号当前拷贝**。它是 scripts/build-boot.sh 的
# 默认输出名（-o $OUT/boot-elden.img），每次构建都会重生，不是人忘改名 —— 所以**不拦构建**，
# 只汇成一条 WARN 提请收口（改名/删除）。“号必须入名”靠命名规则约束，不靠罚这个兵物。
NOTE = ('unversioned',)
EPOCH = float(os.environ.get('VK_RULE_EPOCH', 1791388800))     # 2026-10-08 00:00 本地时区


def is_hard(flag):
    return any(flag.startswith(h) for h in HARD) and not flag.startswith(NOTE)


def gate(rows, skip_names):
    """只拦住新构建；存量欠账汇总成 WARN。输出契约同 check-doctor §5。"""
    new_hard, legacy, held, noted = [], 0, [], []
    for r in rows:
        img = os.path.join(OUT, r[1])
        name = r[0] if r[0] != '(unversioned)' else r[1]
        flags = r[10].split('|')
        if any(f.startswith(NOTE) for f in flags):
            noted.append(r[1])
        hard = [f for f in flags if is_hard(f)]
        if not hard:
            continue
        if r[1] in skip_names:
            held.append('%s(%s)' % (name, ','.join(hard)))
        elif os.path.exists(img) and os.path.getmtime(img) >= EPOCH:
            new_hard.append('%s: %s' % (name, ','.join(hard)))
        else:
            legacy += 1
    if new_hard:
        for s in new_hard:
            print('FAIL\t新构建踩到硬错（命名/溯源规则 2026-10-08）→ %s' % s)
    else:
        print('OK\t生效时刻之后的镜像无硬错（在途豁免 %d 个）' % len(held))
    if held:
        print('WARN\t在途豁免（收口后从 vk-identity-inflight.txt 删掉）：%s' % ' '.join(held))
    if legacy:
        print('WARN\t存量欠账 %d 个镜像有硬错（逐镜像见 vk-kernel-identity.tsv / '
              'vk-ledger-known-issues.tsv）' % legacy)
    if noted:
        print('WARN\t无版本号构建拷贝 %d 个（build-boot.sh 默认产物，不拦构建；收口时改名或删）：%s'
              % (len(noted), ' '.join(noted)))
    return 0


def main():
    check = '--check' in sys.argv[1:]
    skip_names = inflight_images()
    reg = load_registry()
    head, allrefs = kernel_refs()
    tags = tag_map()
    points = points_at_map()
    head12 = {x[:12] for x in head}
    all12 = {x[:12] for x in allrefs}

    def resolve(src):
        """短 sha → ('main'|'branch:..'|'unreachable'|'missing', full_sha)。"""
        if src in head12:
            return 'main', next(x for x in head if x.startswith(src))
        if src in all12:
            full = next(x for x in allrefs if x.startswith(src))
            return 'branch:' + ','.join(sorted(containing_refs(full))), full
        exists = subprocess.run(('git', '-C', KERNEL, 'cat-file', '-e',
                                 src + '^{commit}')).returncode == 0
        return ('unreachable', src) if exists else ('missing', '')

    dup = collections.defaultdict(list)      # kbin_sha -> [build]
    rows = []

    for img in sorted(glob.glob(os.path.join(OUT, '*.img'))):
        base = os.path.basename(img)
        if not base.startswith('boot-elden'):
            continue                          # dtbo-dummy 等：无内核载荷
        build = base[len('boot-elden'):-len('.img')].lstrip('-') or '(unversioned)'
        uts, kbin = payload(img)
        if not uts:
            rows.append([build, base, '-', '(无内核载荷)', kbin, '', 'no-payload',
                         '', '', '', 'skip'])
            continue
        dup[kbin].append(build)
        mf = manifest(img[:-len('.img')] + '.manifest')
        m = re.match(r'^vk(\d+)', build)
        num = int(m.group(1)) if m else None
        regr = 'vk%d' % num if num is not None and num in reg else '-'
        s = re.search(r'g([0-9a-f]{7,})(-dirty)?', uts)
        src = s.group(1) if s else ''
        dirty = bool(s and s.group(2))
        if not src:
            ref, full = 'no-sha', ''          # LOCALVERSION 里根本没有 git 串（sd-* 等）
        else:
            ref, full = resolve(src)
        tg = ','.join(sorted(tags.get(full, []))) if full else ''
        onref = ','.join(points.get(full, [])) if full else ''
        tree_head = mf.get('kernel_git_head', '')[:12]
        tree_state = mf.get('kernel_git_state', '')

        flags = []
        if build == '(unversioned)':
            flags.append('unversioned')       # 无版本号的当前拷贝，无法溯源
        if not mf:
            flags.append('no_manifest')
        if ref in ('no-sha', 'missing', 'unreachable'):
            flags.append('src_' + ref)
        t = re.search(r'g([0-9a-f]{7,})(-dirty)?', mf.get('kernel_release', '')) if mf else None
        if t and src and t.group(1) != src:
            flags.append('tree_drift')        # 打包内核 ≠ 构建时那棵树的内核（vk52 类事故）
        elif t and src and bool(t.group(2)) != dirty:
            flags.append('dirty_drift')       # 同 sha但 dirty 位不同
        if mf and src:
            if tree_head in ('', '(none)'):
                flags.append('tree_head_missing')
            elif not (tree_head == src or src.startswith(tree_head) or
                      tree_head.startswith(src)):
                flags.append('tree_head_diff')
        mp = mf.get('kernel_payload_sha256', '')
        if re.fullmatch(r'[0-9a-f]{16,}', mp or '') and mp[:12] != kbin:
            flags.append('payload_mismatch')   # manifest 自记的内核载荷≠镜像里的（伪造/错文件）
        # 号↔源 对齐：该源提交上的 ref（分支名 + tag 名）里**任何一个** vkNN 与本构建号相同即算对齐。
        # 不能只看第一个：主线分支叫 elden/vk53-hw，它携带了 vk40→vk64 所有构建，
        # 只比第一个会把 vk42/vk64 这种本来对齐的误判成错（早期版本就这么误判过）。
        nums = {int(x) for x in re.findall(r'vk(\d+)', onref)}
        if num is not None and onref and num not in nums:
            flags.append('num_ne_tag(%s)' % onref)   # 该源提交无同名号 ⇒ 复用了别的号的内核
        rows.append([build, base, regr, uts, kbin, src + ('-dirty' if dirty else ''),
                     ref, tg, tree_head, tree_state or '-',
                     'ok' if not flags else '|'.join(flags)])

    utsbins = collections.defaultdict(set)
    for r in rows:
        utsbins[r[3]].add(r[4])
    for r in rows:
        extra = []
        if len(dup[r[4]]) > 1:                  # 同一内核二进制被几个镜像复用
            extra.append('kbin_shared%d' % len(dup[r[4]]))
        if len(utsbins[r[3]]) > 1:              # 同一 UTS 串背后多个二进制（串不唯一）
            extra.append('uts_dup%d' % len(utsbins[r[3]]))
        if extra:
            r[10] += '|' + '|'.join(extra)

    body = '\n'.join('\t'.join(str(c) for c in r) for r in rows)
    text = '\t'.join(COLS) + '\n' + body + '\n'
    if '--gate' in sys.argv[1:]:
        return gate(rows, skip_names)
    if check:
        old = open(TSV).read() if os.path.exists(TSV) else ''

        def keep(line):
            p = line.split('\t')
            return len(p) < 2 or p[1] not in skip_names
        a = [keep(l) for l in old.split('\n', 1)[1].splitlines() if l]
        b = [keep(l) for l in text.split('\n', 1)[1].splitlines() if l]
        if a != b:
            print('vk-kernel-identity.tsv 过期：镜像/registry 变了但表未重生成', file=sys.stderr)
            return 1
        return 0
    sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
