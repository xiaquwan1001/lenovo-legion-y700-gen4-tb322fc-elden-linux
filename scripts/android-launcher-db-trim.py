#!/usr/bin/env python3
"""android-launcher-db-trim.py — 裁剪 /system/etc/launcher.db 的默认桌面布局（纯主机侧、不用 root）。

为什么：ZUI 首启会把 /system/etc/launcher.db（与 launcher_2layer.db）拷进 /data 作为默认布局；
布局里含 preinstall 池里的包（抖音/优酷/爱奇艺/WPS/Canva…）与 ZUI 自有池应用（图库/便签/天气/闹钟/
日历/录音机/换机）。池被删掉后这些入口没有对应 apk ⇒ 桌面出现「占位图标、点开提示无网络」。
本脚本按「要删的包清单」删 favorites 行，并清理因此变空的文件夹行，最后打印剩余布局供目视核对。

用法：
  scripts/android-launcher-db-trim.py --db <launcher.db> --drop-pkgs <pkgfile> [--out <new.db>] [--dry-run]

  --drop-pkgs 文件每行一个包名（# 开头为注释）；- 表示从 stdin 读
  --out 缺省时写 <db>.trimmed
不改原文件；--verify 打印剩余 39 类条目。
"""
import argparse
import re
import shutil
import sqlite3
import sys

FAV = "favorites"


def pkg_of(intent):
    if not intent:
        return None
    m = re.search(r"component=([^/;]+)/", intent) or re.search(r"package=([^;]+);", intent)
    return m.group(1) if m else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True)
    ap.add_argument("--drop-pkgs", required=True)
    ap.add_argument("--out")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()

    if a.drop_pkgs == "-":
        drop = {l.strip() for l in sys.stdin if l.strip() and not l.startswith("#")}
    else:
        drop = {l.strip() for l in open(a.drop_pkgs) if l.strip() and not l.startswith("#")}
    out = a.out or (a.db + ".trimmed")
    if not a.dry_run:
        shutil.copyfile(a.db, out)
    db = sqlite3.connect(a.db if a.dry_run else out)
    cur = db.cursor()
    try:
        rows = cur.execute("select _id,title,intent,itemType,container from %s" % FAV).fetchall()
    except sqlite3.Error as e:
        print("读 %s 失败: %s" % (FAV, e), file=sys.stderr)
        return 1
    ids, hits = [], []
    for _id, title, intent, itemtype, container in rows:
        p = pkg_of(intent)
        if p and p in drop:
            ids.append(_id)
            hits.append((title, p))
    if not a.dry_run:
        cur.executemany("delete from %s where _id=?" % FAV, [(i,) for i in ids])
        # 清理变空的文件夹（itemType=2 容器为文件夹的占位行）
        empties = []
        for _id, container in cur.execute("select _id,container from %s where itemType=2" % FAV):
            n = cur.execute("select count(*) from %s where container=?" % FAV, (_id,)).fetchone()[0]
            if n == 0:
                empties.append(_id)
        cur.executemany("delete from %s where _id=?" % FAV, [(i,) for i in empties])
        db.commit()
    else:
        empties = []
    print("db=%s 总行=%d 删除(包在清单内)=%d 空文件夹行删除=%d 剩余=%d"
          % (a.db if a.dry_run else out, len(rows), len(ids), len(empties),
             len(rows) - len(ids) - len(empties)))
    for t, p in hits:
        print("  - %-16s %s" % (t, p))
    if a.verify:
        print("\n剩余带 intent 的条目：")
        for title, intent in cur.execute(
                "select title,intent from %s where intent is not null and intent<>'' order by title" % FAV):
            print("  %-16s %s" % (title, pkg_of(intent) or intent[:40]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
