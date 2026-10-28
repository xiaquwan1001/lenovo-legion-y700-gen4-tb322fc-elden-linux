#!/usr/bin/env python3
"""g3-steam: fetch Steam linuxarm64 client packages per official manifest.

Derived from armadaos-freedom packages/steam-bootstrap/fetch.py (GPL-2.0-or-later,
github.com/mydanyi/armadaos-freedom). Differences: no version pin (uses whatever
the live steamdeck_stable channel manifest says), download root configurable.

usage: fetch.py <workdir> [manifest_url]
"""
import hashlib
import pathlib
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

MANIFEST = "steam_client_steamdeck_stable_linuxarm64"
CDN = "https://client-update.steamstatic.com"


def packages(contents):
    result = []
    for block in re.findall(r"\{([^{}]*)\}", contents):
        fields = dict(re.findall(r'"([^"\n]+)"\s+"([^"\n]+)"', block))
        if "file" not in fields:
            continue
        for name_key, hash_key in (("file", "sha2"), ("zipvz", "sha2vz")):
            if name_key not in fields:
                continue
            name, digest = fields[name_key], fields.get(hash_key, "")
            if not re.fullmatch(r"[a-zA-Z0-9_.-]+", name) or not re.fullmatch(r"[a-f0-9]{64}", digest):
                raise ValueError(f"bad name/hash: {name}")
            result.append((name, digest))
    if not result:
        raise ValueError("manifest has no packages")
    return result


def download(url, path, expected):
    if path.is_file():
        with path.open("rb") as source:
            if hashlib.file_digest(source, "sha256").hexdigest() == expected:
                print(f"cached {path.name}", flush=True)
                return path.stat().st_size
    tmp = path.with_name(path.name + ".partial")
    subprocess.run(["curl", "--retry", "5", "-fLsS", "-o", str(tmp), url], check=True)
    with tmp.open("rb") as source:
        got = hashlib.file_digest(source, "sha256").hexdigest()
    if got != expected:
        raise ValueError(f"SHA256 mismatch {path.name}: {got}")
    tmp.replace(path)
    print(f"verified {path.name} {path.stat().st_size}", flush=True)
    return path.stat().st_size


def main():
    work = pathlib.Path(sys.argv[1])
    url = sys.argv[2] if len(sys.argv) > 2 else f"{CDN}/{MANIFEST}"
    feed = work / "feed"
    feed.mkdir(parents=True, exist_ok=True)
    manifest = feed / MANIFEST
    subprocess.run(["curl", "--retry", "5", "-fLsS", "-o", str(manifest), url], check=True)
    text = manifest.read_text(errors="ignore")
    m = re.search(r'"version"\s+"(\d+)"', text)
    print(f"manifest_version={m.group(1) if m else '?'}")
    items = packages(text)
    with ThreadPoolExecutor(max_workers=6) as ex:
        sizes = list(ex.map(lambda it: download(f"{CDN}/{it[0]}", feed / it[0], it[1]), items))
    # seed package name for the arm64 client bootstrap
    seed = re.search(r"bins_linuxarm64_linuxarm64\.zip\.(?!vz\.)[^\"\s]+", text)
    print(f"packages={len(items)} bytes={sum(sizes)}")
    print(f"seed={seed.group(0) if seed else 'NOT-FOUND'}")
    (work / "version").write_text((m.group(1) if m else "") + "\n")


if __name__ == "__main__":
    main()
