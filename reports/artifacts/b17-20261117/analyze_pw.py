#!/usr/bin/env python3
"""B17: 从 cache/ 汇总我方 patchwork 系列状态与未回复意见。输出 JSON 到 pw-summary.json。"""
import json, os, glob, re, collections

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "cache")
ME = "xiaqinghuan@mail.ustc.edu.cn"
BOT_PAT = re.compile(r"sashiko|patchwork-bot|kernel-test-robot|lkp|syzbot|linux-next|robh\+linux|conor", re.I)


def load(kind, ident):
    p = os.path.join(CACHE, f"{kind}-{ident}.json")
    if not os.path.exists(p):
        return None
    try:
        return json.load(open(p))
    except Exception:
        return None


def is_me(c):
    return ((c.get("submitter") or {}).get("email") or "").lower() == ME


def is_bot(c):
    s = c.get("submitter") or {}
    txt = (s.get("email") or "") + " " + (s.get("name") or "")
    return bool(BOT_PAT.search(txt))


def main():
    series_list = json.load(open(os.path.join(HERE, "series.json")))
    groups = collections.OrderedDict()
    incomplete = []
    for s in series_list:
        sd = load("series", s["id"])
        if not sd:
            incomplete.append(s["id"])
            continue
        raw = re.sub(r"^\s*(\[[^\]]*\]\s*)+", "", sd["name"])
        key = re.sub(r"\s+", " ", raw.strip().lower())
        key = re.sub(r"\s*\(.*\)$", "", key)
        g = groups.setdefault(key, {"name": sd["name"], "instances": []})
        g["instances"].append(sd)

    out = []
    for key, g in groups.items():
        insts = g["instances"]
        latest_inst = max(insts, key=lambda x: (x.get("version") or 0, x["date"]))
        comments = {}
        states = collections.Counter()
        refs = []
        tags = collections.Counter()
        patch_meta = {}
        for sd in insts:
            for p in sd.get("patches", []):
                pd = load("patch", p["id"])
                if not pd:
                    incomplete.append(p["id"])
                    continue
                states[pd.get("state")] += 1
                if pd.get("commit_ref"):
                    refs.append((sd["project"]["link_name"], p["id"], pd["commit_ref"]))
                for t in (pd.get("tags") or {}):
                    for person in pd["tags"][t]:
                        tags[f"{t}: {person.get('name')}"] += 1
                tr = []
                for line in (pd.get("content") or "").splitlines():
                    m2 = re.match(r"^(Acked-by|Reviewed-by|Tested-by|Reported-by|Fixes):\s*(.+)$", line.strip())
                    if m2:
                        tr.append(f"{m2.group(1)}: {m2.group(2)}")
                patch_meta[p["id"]] = {"trailers": tr, "state": pd.get("state"), "name": pd.get("name"),
                                       "commit_ref": pd.get("commit_ref"),
                                       "project": sd["project"]["link_name"],
                                       "series_version": sd.get("version"), "date": pd.get("date")}
                for c in (load("comments", p["id"]) or []):
                    comments[c["id"]] = c
            cl = sd.get("cover_letter")
            if cl:
                for c in (load("comments", cl["id"]) or []):
                    comments[c["id"]] = c
        seq = sorted(comments.values(), key=lambda c: c["date"])
        mine = [c for c in seq if is_me(c)]
        last_mine = mine[-1]["date"] if mine else ""
        after = [c for c in seq if c["date"] > last_mine and not is_me(c)]
        after_human = [c for c in after if not is_bot(c)]
        last_other = seq[-1] if seq and not is_me(seq[-1]) else None
        # 最新版本对应的 patch 状态（只看最新版本实例）
        latest_states = collections.Counter()
        latest_trailers = []
        for p in latest_inst.get("patches", []):
            pm0 = patch_meta.get(p["id"])
            if pm0:
                latest_trailers += pm0["trailers"]
            pm = patch_meta.get(p["id"])
            if pm:
                latest_states[pm["state"]] += 1
        out.append({
            "name": g["name"],
            "latest_version": latest_inst.get("version"),
            "latest_date": latest_inst["date"],
            "latest_projects": sorted({i["project"]["link_name"] for i in insts if i.get("version") == latest_inst.get("version")}),
            "all_versions": sorted({i.get("version") for i in insts}),
            "instances": len(insts),
            "latest_patch_states": dict(latest_states),
            "all_patch_states": dict(states),
            "commit_refs": refs,
            "tags": dict(tags),
            "latest_trailers": sorted(set(latest_trailers)),
            "n_comments": len(seq),
            "n_mine": len(mine),
            "n_after_last_mine": len(after),
            "n_after_last_mine_human": len(after_human),
            "last_other": None if not last_other else {
                "date": last_other["date"],
                "who": last_other["submitter"].get("name") or last_other["submitter"].get("email"),
                "email": last_other["submitter"].get("email"),
                "bot": is_bot(last_other),
                "subject": last_other.get("subject", "")[:120],
                "snippet": re.sub(r"\s+", " ", last_other.get("content", ""))[:300],
            },
            "other_speakers": sorted({(c["submitter"].get("name") or c["submitter"].get("email") or "?") for c in seq if not is_me(c)}),
            "patches": list(patch_meta.values()),
        })
    out.sort(key=lambda x: x["latest_date"], reverse=True)
    json.dump(out, open(os.path.join(HERE, "pw-summary.json"), "w"), indent=1)
    print("groups", len(out), "incomplete", len(incomplete), incomplete[:6])
    for o in out[:8]:
        print(o["latest_date"], "v%s" % o["latest_version"], o["latest_patch_states"], "unrep=%d(h%d)" % (o["n_after_last_mine"], o["n_after_last_mine_human"]), o["name"][:55])


if __name__ == "__main__":
    main()
