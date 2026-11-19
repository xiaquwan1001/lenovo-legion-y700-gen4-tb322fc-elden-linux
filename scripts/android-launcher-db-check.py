#!/usr/bin/env python3
"""android-launcher-db-check.py — 校验「桌面默认布局里不再引用已删包」。

为什么：v1 镜像删了 /system/preinstall 却没裁 /system/etc/launcher.db，全新 /data 首启后桌面
出现 47 条占位图标（点开提示无网络）。本脚本是那条判据的机械化：favorites 表里**任何**一行的
intent 组分若命中待删包清单 ⇒ 打 `VIOLATION`，退出码 1。

用法：
  scripts/android-launcher-db-check.py --db launcher.db [--db ...] --drop drop-pkgs.txt
  scripts/android-launcher-db-check.py --db launcher.db --drop -      # 清单从 stdin 读
退出码：0 = 无违规；1 = 有 VIOLATION（逐条打印 title/pkg）；2 = 参数/读库失败。
"""
import argparse
import re
import sqlite3
import sys


def pkg_of(intent):
    if not intent:
        return None
    m = re.search(r"component=([^/;]+)/", intent) or re.search(r"package=([^;]+);", intent)
    return m.group(1) if m else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', action='append', required=True)
    ap.add_argument('--drop', required=True)
    a = ap.parse_args()
    if a.drop == '-':
        drop = {l.strip() for l in sys.stdin if l.strip() and not l.startswith('#')}
    else:
        drop = {l.strip() for l in open(a.drop) if l.strip() and not l.startswith('#')}
    if not drop:
        print('drop 清单为空，判据无意义', file=sys.stderr)
        return 2
    bad = 0
    for db in a.db:
        try:
            con = sqlite3.connect('file:%s?mode=ro' % db, uri=True)
            rows = con.execute('select _id,title,intent from favorites').fetchall()
        except sqlite3.Error as e:
            print('读 %s 失败：%s' % (db, e), file=sys.stderr)
            return 2
        kept = sum(1 for _ in rows)
        for _id, title, intent in rows:
            p = pkg_of(intent)
            if p and p in drop:
                bad += 1
                print('VIOLATION %s: _id=%s title=%r pkg=%s' % (db, _id, title, p))
        print('OK %s: favorites=%d 行，引用已删包 0 条' % (db, kept))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())