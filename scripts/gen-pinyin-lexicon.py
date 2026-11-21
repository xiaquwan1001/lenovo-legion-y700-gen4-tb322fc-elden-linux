#!/usr/bin/env python3
"""gen-pinyin-lexicon.py — 从 CC-CEDICT 生成「拼音 → 词」候选词库（供 elden-pinyin-completer 用）。

为什么不用 librime（2026-11-21 决策）：librime 走 one-shot 时每键都要建 session + 载词库
（实测同量级词库 ~150–300 ms/次），而 pipe completer 是**每键 spawn**；CC-CEDICT 把词库
预编译成「音节串 → 前 N 个词」的分片 JSON，单键只需读 ~200–600 KB 的一个分片（~5–10 ms）。

用法：
  python3 scripts/gen-pinyin-lexicon.py --cedict /tmp/cedict.txt --out <dir> [--per-key 12] [--min-len 1]

产出：<dir>/shards/<首音节>.json（内容 = {"nihao": ["你好", ...], ...}）+ <dir>/META.json
  · 只保留简体、`GB2312` 可编码的字（与 helper 的单字过滤同口径，避免扩展区怪字）
  · 排序 = **词频降序**（给了 --freq 时，用 jieba dict.txt 的频次）→ 词长升序 → CEDICT 条目序
"""
import argparse
import json
import os
import re
import sys
from collections import defaultdict

TONE = str.maketrans({"ā": "a", "á": "a", "ǎ": "a", "à": "a",
                      "ē": "e", "é": "e", "ě": "e", "è": "e",
                      "ī": "i", "í": "i", "ǐ": "i", "ì": "i",
                      "ō": "o", "ó": "o", "ǒ": "o", "ò": "o",
                      "ū": "u", "ú": "u", "ǔ": "u", "ù": "u",
                      "ǖ": "v", "ǘ": "v", "ǚ": "v", "ǜ": "v", "ü": "v"})


def norm_syl(s):
    s = s.strip().translate(TONE).lower()
    s = re.sub(r"[0-9]", "", s)
    s = s.replace("u:", "v")
    return re.sub(r"[^a-z]", "", s)


def gb_level1(ch):
    try:
        b = ch.encode("gb2312")
    except UnicodeEncodeError:
        return False
    return len(b) == 2 and 0xB0 <= b[0] <= 0xD7


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cedict", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--per-key", type=int, default=12)
    ap.add_argument("--freq", help="词频表（jieba dict.txt 形状：`词 频次 词性`）；给了就按词频频次降序排序")
    ap.add_argument("--min-len", type=int, default=1)
    ap.add_argument("--max-len", type=int, default=6)
    a = ap.parse_args()

    freq = {}
    if a.freq:
        with open(a.freq, encoding="utf-8", errors="replace") as f:
            for ln in f:
                parts = ln.split()
                if len(parts) >= 2 and parts[1].isdigit():
                    freq[parts[0]] = int(parts[1])
        print("freq entries:", len(freq))

    key_words = defaultdict(list)
    seen = defaultdict(set)
    line_re = re.compile(r"^(\S+)\s+(\S+)\s+\[([^\]]+)\]\s+/(.*)/$")
    n_ok = n_skip = 0
    with open(a.cedict, encoding="utf-8") as f:
        for ln in f:
            if ln.startswith("#"):
                continue
            m = line_re.match(ln.strip())
            if not m:
                n_skip += 1
                continue
            _trad, simp, py, _defs = m.groups()
            if not (a.min_len <= len(simp) <= a.max_len):
                continue
            if not all(gb_level1(c) for c in simp):
                continue
            syls = [norm_syl(x) for x in py.split()]
            if not syls or not all(syls):
                continue
            key = "".join(syls)
            if len(simp) != len(syls):      # 只收「一字一音」的对齐条目（避免比例错位）
                continue
            if simp in seen[key]:
                continue
            seen[key].add(simp)
            fr = freq.get(simp, 0)
            key_words[key].append((-fr, len(simp), len(key_words[key]), simp))
            n_ok += 1

    shards = defaultdict(dict)
    total = 0
    for key, items in key_words.items():
        items.sort()
        words = [w for _fr, _l, _i, w in items[: a.per_key]]
        first = key[0]
        shards[first][key] = words
        total += 1

    sdir = os.path.join(a.out, "shards")
    os.makedirs(sdir, exist_ok=True)
    size = 0
    for first, d in shards.items():
        p = os.path.join(sdir, first + ".json")
        blob = json.dumps(d, ensure_ascii=False, separators=(",", ":")).encode()
        open(p, "wb").write(blob)
        size += len(blob)
    meta = {"source": "CC-CEDICT", "keys": total, "shards": len(shards),
            "bytes": size, "per_key": a.per_key, "entries_used": n_ok, "lines_skipped": n_skip}
    open(os.path.join(a.out, "META.json"), "w", encoding="utf-8").write(
        json.dumps(meta, ensure_ascii=False, indent=1) + "\n")
    print(json.dumps(meta, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
