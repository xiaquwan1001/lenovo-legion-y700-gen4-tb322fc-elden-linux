#!/usr/bin/env python3
"""B17: 拉取我方 patchwork 全部系列 + patch 状态 + 评论（可断点续跑）。

用法: python3 fetch_pw.py [--budget 秒]
缓存: 同目录 cache/<kind>-<id>.json
"""
import json, os, sys, time, urllib.request

BASE = "https://patchwork.kernel.org/api/1.2"
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "cache")
os.makedirs(CACHE, exist_ok=True)


def get(url, timeout=25, retries=2):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)
        except Exception as e:  # noqa: BLE001
            if i == retries - 1:
                return {"__error__": str(e)}
            time.sleep(1.5)


def cached(kind, ident, url):
    p = os.path.join(CACHE, f"{kind}-{ident}.json")
    if os.path.exists(p):
        try:
            return json.load(open(p))
        except Exception:
            pass
    d = get(url)
    if "__error__" not in d:
        json.dump(d, open(p + ".tmp", "w"))
        os.replace(p + ".tmp", p)
    return d


def main():
    budget = 300
    for a in sys.argv[1:]:
        if a.startswith("--budget"):
            budget = int(a.split("=")[1])
    t0 = time.time()
    series = json.load(open(os.path.join(HERE, "series.json")))
    # 去重：同名同版本跨项目只留 linux-arm-msm/dri-devel 之类主项目一份 + 全部分项目评论
    done = 0
    for s in series:
        if time.time() - t0 > budget:
            print(f"BUDGET STOP at {done}/{len(series)} series")
            return 2
        sd = cached("series", s["id"], f"{BASE}/series/{s['id']}/")
        if "__error__" in sd:
            print("ERR series", s["id"], sd["__error__"])
            continue
        for p in sd.get("patches", []):
            pd = cached("patch", p["id"], f"{BASE}/patches/{p['id']}/")
            cached("comments", p["id"], f"https://patchwork.kernel.org/api/patches/{p['id']}/comments/")
        cl = sd.get("cover_letter")
        if cl:
            cached("comments", cl["id"], f"https://patchwork.kernel.org/api/covers/{cl['id']}/comments/")
        done += 1
    print(f"OK {done} series in {time.time()-t0:.0f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
