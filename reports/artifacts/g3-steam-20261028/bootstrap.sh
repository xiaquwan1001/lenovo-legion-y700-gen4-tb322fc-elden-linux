#!/bin/bash
# g3-steam bootstrap: build a native ARM64 Steam client tree from the official
# steamdeck_stable linuxarm64 channel (derived from armadaos-freedom
# packages/steam-bootstrap/generate.sh, GPL-2.0-or-later, minus the offline feed
# server + container bits: we have real network on the device).
#
# usage: bootstrap.sh <workdir> <runtime-tar.xz>
set -euxo pipefail
WORK=${1:?workdir}
RUNTIME=${2:?runtime tar.xz}

export HOME=/root/steam-home
STEAM="$HOME/.local/share/Steam"
DOT="$HOME/.steam"
MANIFEST_NAME=steam_client_steamdeck_stable_linuxarm64

rm -rf "$STEAM" "$DOT"
mkdir -p "$STEAM/package" "$DOT"

echo steamdeck_stable > "$STEAM/package/beta"
ln -sfn ../.local/share/Steam "$DOT/steam"
ln -sfn ../.local/share/Steam "$DOT/root"
ln -sfn ../.local/share/Steam/linuxarm64 "$DOT/sdkarm64"
ln -sfn ../.local/share/Steam/ubuntu12_32 "$DOT/bin32"
ln -sfn ../.local/share/Steam/ubuntu12_64 "$DOT/bin64"

cp -f "$WORK/feed/$MANIFEST_NAME" "$STEAM/package/$MANIFEST_NAME.manifest"
seed=$(grep -oP 'bins_linuxarm64_linuxarm64\.zip\.(?!vz\.)[^"]+' "$WORK/feed/$MANIFEST_NAME" | head -1)
echo "seed=$seed"
cp -f "$WORK/feed/$seed" "$STEAM/package/$seed"
unzip -q -o "$STEAM/package/$seed" -d "$STEAM"

# zip may lose the exec bit on launcher scripts: restore for ELF/scripts
python3 - "$STEAM" <<'PY'
import os, pathlib, stat, subprocess, sys
steam = pathlib.Path(sys.argv[1])
for path in steam.rglob("*"):
    if not path.is_file():
        continue
    try:
        head = path.open("rb").read(4)
    except OSError:
        continue
    is_elf = head == b"\x7fELF"
    is_script = head.startswith(b"#!") or head.startswith(b"#!/")
    if not (is_elf or is_script):
        continue
    mode = path.stat().st_mode
    path.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
PY

tar -xJf "$RUNTIME" -C "$STEAM"

ibus=$(find "$STEAM/steam-runtime-steamrt-arm64" -path '*/files/lib/aarch64-linux-gnu/libibus-1.0.so.5.*' -type f | sort | tail -1)
[ -n "$ibus" ] || { echo "ERROR: no runtime libibus shim" >&2; exit 1; }
mkdir -p "$STEAM/lib/aarch64-linux-gnu"
ln -sfn "../../${ibus#"$STEAM/"}" "$STEAM/lib/aarch64-linux-gnu/libibus-1.0.so.5"

test -f "$STEAM/steamrtarm64/steam" || { echo "ERROR: no steamrtarm64/steam" >&2; exit 1; }
echo "bootstrap tree ready: $(du -sh "$STEAM" | cut -f1)"
