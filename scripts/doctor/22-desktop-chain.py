#!/usr/bin/env python3
"""22-desktop-chain.py — check-doctor §22：「零到桌面」链路的静态一致性门。

立此节的原因（2026-11-19，提交 57e915a6 / d11afc16）：
  那天从 EDL 一路走到可用桌面，链上五个坑（PITFALLS #681–#685）**全部是静默失败**——
  每一步的现象都指向下一层（像内核坏 / 像屏坏 / 像源坏），真因都在上一层。修复被固化在
  `scripts/deploy-desktop-shell.sh` + `RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md` 两处，
  但这两处与 PITFALLS 之间**没有任何机器校验**：
    · 有人从 `PKGS` 里删掉 `udev` / `phosh-osk-stub` ⇒ 设备侧 `--check` 仍会跑，
      但「缺少的那一项」本身不再被检查（udev 一度就只写在注释里，不在 PKGS）；
    · 有人改 `time-sync.sh` 去掉 `stop chronyd` 或 HTTP Date 兜底 ⇒ 冷起时钟回不来；
    · 有人重排 RUNBOOK 的 S 步 ⇒ 溯源表里的步号指向空。

本节只做**静态**检查（不连设备、不需要镜像），四类不变量：
  A 链件在且语法过：deploy-desktop-shell.sh（bash -n）/ time-sync.sh / ZERO-TO-DESKTOP.md
  B 每个静默失败坑在**可执行件**里有对应判据锚点（不是只在注释里提一句）
  C PITFALLS 索引里有 #681–#685，且 RUNBOOK S1–S12 连续、每步都有判据
  D 反作弊自检：把 `udev` / `phosh-osk-stub` 从 PKGS 副本里删掉，本节**必须** FAIL
    （门自己空转 = 比没有门更糟，口径同 §18/§19/§20）

用法：
  scripts/doctor/22-desktop-chain.py            # 人读（doctor 输出格式）
  scripts/doctor/22-desktop-chain.py --root DIR # 指定仓库根
  scripts/doctor/22-desktop-chain.py --selftest # 只跑 D（临时副本，不碰仓库）
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

ARGV = sys.argv[1:]
ROOT = os.environ.get('ROOT') or '.'
if '--root' in ARGV:
    ROOT = ARGV[ARGV.index('--root') + 1]
ROOT = os.path.abspath(ROOT)
SELFTEST = '--selftest' in ARGV          # 只跑反作弊
NO_SELFTEST = '--no-selftest' in ARGV    # 反作弊里的递归副本（防无限套娃）

SCRIPT = 'scripts/deploy-desktop-shell.sh'
TSYNC = 'packaging/elden-userland/files/usr/local/sbin/time-sync.sh'
RUNBOOK = 'RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md'
PITFALLS = 'PITFALLS/README.md'

fail = 0


def ok(msg):
    print('  [ok]   %s' % msg)


def bad(msg):
    global fail
    fail += 1
    print('  [FAIL] %s' % msg)


def warn(msg):
    print('  [warn] %s' % msg)


def read(rel):
    p = os.path.join(ROOT, rel)
    if not os.path.isfile(p):
        return None
    with open(p, 'r', encoding='utf-8', errors='replace') as f:
        return f.read()


# ---------------------------------------------------------------- A 链件 + 语法
def packages(text):
    m = re.search(r'^PKGS="([^"]*)"', text or '', re.M)
    return m.group(1).split() if m else []


# 包 → 为什么必须有（坑号）。删掉任何一个都是「静默失败回来」。
PKG_REQUIRED = [
    ('udev', '#681 模块零自动加载 ⇒ DPU 聚合永不 bind'),
    ('phosh-osk-stub', '#682 缺 sm.puri.OSK0 ⇒ gnome-session-failed + 黑底转圈'),
    ('libglib2.0-bin', 'gsettings 缺失 ⇒ gnome-session 环境探测报错'),
    ('phoc', '合成器本体'), ('phosh', 'shell 本体'),
    ('greetd', '显示管理器；无它 shell 不会起'), ('seatd', 'LIBSEAT_BACKEND=seatd 后端'),
]

# 坑号 → 必须有判据锚点的 (文件, 子串) 列表。子串必须出现在**可执行/可判读**的位置，
# 只在注释里出现不算（这是 #681 最初的真实缺陷）。
ANCHORS = [
    ('#681', SCRIPT, 'systemd-udevd', '服务状态判据（不是「装了就行」）'),
    ('#681', SCRIPT, '/dev/dri/card0', '显示链结果判据'),
    ('#681', SCRIPT, 'aggregate not bound', 'DPU 聚合判据'),
    ('#682', SCRIPT, 'phosh-osk-stub', '会话必需组件'),
    ('#683', SCRIPT, 'elden-soft-render', 'Mesa 不认 GPU 时的软合成开关'),
    ('#683', RUNBOOK, 'trixie-backports', '硬件渲染档（Mesa 26.1.6）'),
    ('#684', TSYNC, 'systemctl stop chronyd', '先停服务再 chronyd -q'),
    ('#684', TSYNC, 'flock', '冷起补跑串行化'),
    ('#684', TSYNC, 'date -u -s', 'HTTP Date 头落到系统时钟（NTP 全失败时）'),
    ('#685', SCRIPT, 'usb0-host-route', '默认路由常驻自愈'),
    ('#685', SCRIPT, 'resolved.conf.d', 'resolved 上游 DNS'),
]


def check_static():
    print('\n== 22. 零到桌面链路门（链件/坑号/手册步 / 静态） ==')
    # A1 件在
    for rel in (SCRIPT, TSYNC, RUNBOOK):
        if read(rel) is None:
            bad('缺链件 %s（§22 判据无处落地）' % rel)
    if fail:
        return
    # A2 bash 语法
    for rel in (SCRIPT, TSYNC):
        r = subprocess.run(['bash', '-n', os.path.join(ROOT, rel)],
                           capture_output=True, text=True)
        if r.returncode == 0:
            ok('%s bash -n 通过' % os.path.basename(rel))
        else:
            bad('%s 语法错：%s' % (rel, (r.stderr or '').strip().splitlines()[:1]))
    # A3 --check 契约（只报告 / 不改设备）
    script = read(SCRIPT)
    if '--check' in script and 'MODE=check' in script:
        ok('deploy-desktop-shell.sh 有 --check 只读档（MODE=check）')
    else:
        bad('deploy-desktop-shell.sh 缺 --check 只读档（收尾轮/上机前自检入口）')

    # B 包集 + 坑锚点
    pk = packages(script)
    missing = [p for p, _ in PKG_REQUIRED if p not in pk]
    if missing:
        bad('PKGS 缺必需包：%s（%s）' % (
            ' '.join(missing),
            '；'.join('%s=%s' % (p, why) for p, why in PKG_REQUIRED if p in missing)))
    else:
        ok('PKGS 含全部 %d 个必需包（udev/phosh-osk-stub 等）' % len(PKG_REQUIRED))
    for pid, rel, needle, why in ANCHORS:
        body = read(rel) or ''
        if needle in body:
            continue
        bad('%s 判据锚点丢了：%s 里没有 `%s`（%s）' % (pid, rel, needle, why))

    # C PITFALLS 索引 + RUNBOOK 步
    pit = read(PITFALLS) or ''
    # 索引惯例允许「一条目覆盖一段坑号」（第 317 行就是 #681–#685 合条），故区间也算命中。
    covered = set()
    for a, b in re.findall(r'#(\d+)\s*[–\-]\s*#(\d+)', pit):
        covered.update(range(int(a), int(b) + 1))
    absent = [n for n in range(681, 686) if ('#%d' % n) not in pit and n not in covered]
    if absent:
        bad('PITFALLS 索引缺 %s（§681–#685 是 §22 的锚点）'
            % ' '.join('#%d' % n for n in absent))
    else:
        ok('PITFALLS 索引含 #681–#685')

    rb = read(RUNBOOK) or ''
    steps = sorted({int(x) for x in re.findall(r'^### S(\d+)\b', rb, re.M)})
    if not steps:
        bad('%s 里找不到 `### SN` 步骤标题（溯源表会指向空）' % RUNBOOK)
    else:
        gaps = [n for n in range(steps[0], steps[-1] + 1) if n not in steps]
        if gaps:
            bad('RUNBOOK 步骤号不连续：缺 S%s' % '/S'.join(str(g) for g in gaps))
        else:
            ok('RUNBOOK S%d–S%d 连续（%d 步）' % (steps[0], steps[-1], len(steps)))
        # 每步都要有判据（「- 判据」或「判据：」）
        nojudge = []
        for i, n in enumerate(steps):
            start = rb.index('### S%d' % n)
            end = rb.index('### S%d' % steps[i + 1]) if i + 1 < len(steps) else len(rb)
            seg = rb[start:end]
            if '判据' not in seg:
                nojudge.append('S%d' % n)
        if nojudge:
            bad('RUNBOOK 步骤缺判据：%s' % ' '.join(nojudge))
        else:
            ok('RUNBOOK 每步都有「判据」段')
    # 速查/回退指向链件（防止手册与脚本脱钩）
    if 'deploy-desktop-shell.sh' in rb:
        ok('RUNBOOK 速查指向 deploy-desktop-shell.sh')
    else:
        bad('RUNBOOK 没有指向 deploy-desktop-shell.sh（脚本成孤儿）')

    # RUNBOOK 引用的仓内路径必须存在
    refs = sorted(set(re.findall(
        r'`((?:scripts|rootfs|packaging|RUNBOOK-BRINGUP|PITFALLS)/[A-Za-z0-9._/-]+)`', rb)))
    dead = [r for r in refs if not os.path.exists(os.path.join(ROOT, r))]
    if dead:
        bad('RUNBOOK 引用了不存在的仓内路径：%s' % ' '.join(dead[:4]))
    elif refs:
        ok('RUNBOOK 引用的 %d 个仓内路径都在' % len(refs))


# ---------------------------------------------------------------- D 反作弊自检
def drop_from_pkgs(text, pkg):
    """把 PKGS="…" 里的某个包删掉（首/中/尾位置都支持）。"""
    m = re.search(r'\nPKGS="([^"]*)"', text)
    if not m:
        return text
    toks = m.group(1).split()
    if pkg not in toks:
        return text
    toks.remove(pkg)
    return text[:m.start()] + '\nPKGS="%s"' % ' '.join(toks) + text[m.end():]



def run_gate(root):
    """在给定 root 上跑本门，返回 (fail数, 输出)。"""
    r = subprocess.run([sys.executable, os.path.abspath(__file__), '--root', root,
                        '--no-selftest'],
                       capture_output=True, text=True, timeout=120)
    m = re.search(r'\[FAIL\]', r.stdout)
    n = len(re.findall(r'^  \[FAIL\]', r.stdout, re.M))
    return n, r.stdout + r.stderr, bool(m)


def selftest():
    """合成副本：删掉 PKGS 里的 udev / phosh-osk-stub，本门必须 FAIL。"""
    print('\n== 22-selftest 反作弊（删包必被抓） ==')
    tmp = tempfile.mkdtemp(prefix='desk-chain-st.')
    try:
        # 合成副本：除链件本身外全部软链到真仓（RUNBOOK 的路径存在性判据也要能过）
        os.makedirs(os.path.join(tmp, 'scripts'))
        for name in os.listdir(ROOT):
            if name in ('.git', 'scripts'):
                continue
            src = os.path.join(ROOT, name)
            if os.path.exists(src):
                os.symlink(src, os.path.join(tmp, name))
        for name in os.listdir(os.path.join(ROOT, 'scripts')):
            if name == 'deploy-desktop-shell.sh':
                continue
            os.symlink(os.path.join(ROOT, 'scripts', name),
                       os.path.join(tmp, 'scripts', name))
        good = read(SCRIPT)
        if good is None:
            print('  SELFTEST FAIL 源脚本缺失，无法自检')
            return 1
        bad_count = 0
        cases = [('udev', '删 udev'),
                 ('phosh-osk-stub', '删 phosh-osk-stub')]
        for pkg, label in cases:
            mutated = drop_from_pkgs(good, pkg)
            if mutated == good:
                print('  SELFTEST FAIL %s：没改到 PKGS（正则失配，门口径变了）' % label)
                bad_count += 1
                continue
            with open(os.path.join(tmp, 'scripts', 'deploy-desktop-shell.sh'), 'w') as f:
                f.write(mutated)
            n, out, _ = run_gate(tmp)
            hit = [l for l in out.splitlines() if pkg in l and '[FAIL]' in l]
            if hit:
                print('  SELFTEST ok   %s ⇒ 抓到了：%s' % (label, hit[0].strip()))
            else:
                print('  SELFTEST FAIL %s ⇒ 副本漏过（FAIL=%d）' % (label, n))
                bad_count += 1
        # 干净副本必须过（否则门是「永远 FAIL」的死门）
        with open(os.path.join(tmp, 'scripts', 'deploy-desktop-shell.sh'), 'w') as f:
            f.write(good)
        n, out, _ = run_gate(tmp)
        if n == 0:
            print('  SELFTEST ok   未改副本 FAIL=0（门不是死门）')
        else:
            print('  SELFTEST FAIL 未改副本也 FAIL=%d：%s'
                  % (n, [l.strip() for l in out.splitlines() if '[FAIL]' in l][:2]))
            bad_count += 1
        if bad_count:
            print('  SELFTEST FAIL %d 例' % bad_count)
            return 1
        print('  SELFTEST OK 3/3')
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if SELFTEST:
    sys.exit(selftest())

def run_selftest_inline():
    """把 D 段的结果翻译成 doctor 行（本门自己也要被「坏副本必拒」证明有效）。"""
    import io
    from contextlib import redirect_stdout
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = selftest()
    for line in buf.getvalue().splitlines():
        line = line.strip()
        if not line or line.startswith('== '):
            continue
        if line.startswith('SELFTEST FAIL'):
            bad('反作弊自检：%s' % line[len('SELFTEST FAIL'):].strip())
        elif line.startswith('SELFTEST ok'):
            ok('反作弊自检：%s' % line[len('SELFTEST ok'):].strip())
        elif line.startswith('SELFTEST OK'):
            ok('反作弊自检通过（%s）' % line[len('SELFTEST OK'):].strip() or '3/3')
        else:
            warn('反作弊自检：%s' % line)
    return rc


check_static()
if not NO_SELFTEST:
    print()
    run_selftest_inline()
sys.exit(0 if fail == 0 else 1)
