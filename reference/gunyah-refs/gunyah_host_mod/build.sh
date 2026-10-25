#!/usr/bin/env bash
# Build DroidVM's host-side gunyah kernel modules for each supported GKI KMI via the
# ddk-min docker images. Output layout: dist/<kmi>/<module>.ko
#
#   gunyah_host_share  SHARE_BLOB / GuestAccept   -> 6.6, 6.12 (upstream gunyah_*), 6.1 (gh_*)
#   gunyah_kvcalloc    large-guest >2GB OOM fix   -> 6.1                            (downstream gh_*)
#   udmabuf            provide/repair udmabuf     -> 6.1, 6.6, 6.12 (one portable source)
#
# Kbuild/modpost turns the '-' in the module name into '_' and keeps the '.', so the
# loaded name matches what the app's Kernel Module tab derives from the .ko filename.
# That tab lists EVERY .ko in usr/lib/modules/<kmi>/, so a KMI with two modules
# (6.1: host-share + kvcalloc) shows both; 6.6/6.12 show only host-share.
#
#   ./build.sh arm64     # all supported KMIs (modules are aarch64-only)
#
# Requires docker (the DDK images carry the kernel headers + clang per KMI).
#
# Every module vendors the gunyah private struct layout inline (or reads it by
# BTF-verified offset), so NO build needs the gunyah driver source tree -- any
# stock ddk-min image for the KMI is enough (no -I<kdir>/drivers/virt/gunyah).
set -euo pipefail
cd "$(dirname "$0")"
OUT=dist

# build_mod <kmi-tag> <ddk-image> <src-dir> <src-file> <mod-name>
build_mod() {
  local tag="$1" img="$2" srcdir="$3" srcfile="$4" mod="$5"
  echo ">>> building ${mod}.ko for ${tag}"
  mkdir -p "${OUT}/${tag}"
  docker run --rm \
    -v "${PWD}/${srcdir}:/src:ro" \
    -v "${PWD}/${OUT}/${tag}:/out" \
    -e MOD="${mod}" -e SRCFILE="${srcfile}" \
    "${img}" bash -lc '
      set -e
      K=/opt/ddk/kdir/$(ls /opt/ddk/kdir)
      export PATH=$(ls -d /opt/ddk/clang/clang-*)/bin:$PATH
      B=/tmp/build; mkdir -p "$B"
      cp "/src/${SRCFILE}" "$B/${MOD}.c"
      cp /src/*.h "$B/" 2>/dev/null || true
      printf "obj-m += %s.o\n" "$MOD" > "$B/Makefile"
      make -C "$K" -j"$(nproc)" M="$B" ARCH=arm64 LLVM=1 LLVM_IAS=1 modules
      llvm-strip -d "$B/${MOD}.ko"
      cp "$B/${MOD}.ko" "/out/${MOD}.ko"
    '
  [ -f "${OUT}/${tag}/${mod}.ko" ] || { echo "FAIL: ${tag}/${mod} produced no .ko" >&2; exit 1; }
  echo "OK: ${OUT}/${tag}/${mod}.ko ($(stat -c%s "${OUT}/${tag}/${mod}.ko") bytes)"
}

# Stage descr/ -- the "why is this needed" page for each module -- into dist/descr/.
# One self-contained HTML page per module carrying all three languages; the app picks
# one at display time (and injects the live theme colours), so nothing here is
# per-language or per-theme. The file name is the module-name PREFIX it applies to,
# so udmabuf.html covers udmabuf_gki_6.6 and friends.
#
# No JSON, no archive: these land in usr/lib/modules/descr/ inside the app's prebuilt
# tar.xz, which is already one compressed blob -- packing them again would only make
# them unreadable to whoever has to edit them. They are rendered by a WebView, so a
# page can use real CSS and inline SVG; open one straight in a browser to proofread
# it (all languages show at once, on the fallback palette in style.css).
build_descr() {
  echo ">>> staging descr/"
  rm -rf "${OUT}/descr"
  mkdir -p "${OUT}/descr"
  python3 - "${OUT}/descr" <<'EOF'
import pathlib, re, shutil, sys
src, dst = pathlib.Path("descr"), pathlib.Path(sys.argv[1])
LANGS = ("en", "zh-CN", "zh-TW")
pages = sorted(src.glob("*.html"))
if not pages:
    sys.exit("descr: no pages found")
for page in pages:
    text = page.read_text(encoding="utf-8")
    # Every page must carry every language: the app's fallback to English is a
    # safety net for old prebuilts, not a licence to ship a half-translated page.
    missing = [l for l in LANGS if f'data-lang="{l}"' not in text]
    if missing:
        sys.exit(f"descr/{page.name}: missing languages: {missing}")
    # The app swaps this link for the stylesheet inlined; without it the page would
    # render unstyled on device while still looking right in a browser.
    if not re.search(r'<link[^>]+style\.css[^>]*>', text):
        sys.exit(f"descr/{page.name}: no <link ... style.css> for the app to replace")
    # A figure sits inside its language's section, so its drawing is written once per
    # language. Only the caption may differ -- catch a diagram edited in one copy and
    # not the others, which no reader in the other two languages would ever report.
    # Comments first: one that mentions a tag by name would otherwise open a "match".
    svgs = re.findall(r'<svg\b.*?</svg>', re.sub(r'<!--.*?-->', '', text, flags=re.S), re.S)
    if len(set(svgs)) > 1:
        sys.exit(f"descr/{page.name}: its {len(svgs)} <svg> copies are not identical")
    shutil.copy2(page, dst / page.name)
print(f"OK: {len(pages)} page(s) -> {dst}")
EOF
}

# Stage match.json -- which devices each module is FOR, and what its card is titled. The
# KMI directory already says which kernel a .ko was built for; the "modules" rules say
# which SoC it makes sense on, so a Gunyah module stays off a MediaTek phone (and a
# MediaTek module, when one exists, stays off a Snapdragon). The "names" section maps the
# same module-name prefixes to display names (top-level, NOT a rule field: older apps
# fail a rule with a field they cannot judge, but ignore extra top-level keys). Rules and
# names are keyed by module-name prefix, same convention as descr/. The app reads it from
# usr/lib/modules/match.json; see the app's KernelModuleMatch for the schema.
#
# Every module built here must have a rule: an unmatched .ko is not listed at all, so a
# missing rule silently deletes a module from the UI. Fail the build instead. Names are
# optional (the app falls back to the name minus its _gki_X.Y tag), but a names key that
# covers no built .ko is a typo silently showing users the fallback -- fail on that too.
stage_match() {
  echo ">>> staging match.json"
  mkdir -p "${OUT}"
  cp -f match.json "${OUT}/match.json"
  python3 - "${OUT}" <<'EOF'
import json, pathlib, sys
out = pathlib.Path(sys.argv[1])
data = json.loads((out / "match.json").read_text(encoding="utf-8"))
rules = data["modules"]
# Kbuild turns '-' into '_' in the loaded name; that is what the app matches on.
kos = sorted({ko.stem.replace("-", "_") for ko in out.glob("*/*.ko")})
missing = [n for n in kos if not any(n.startswith(k) for k in rules)]
if missing:
    sys.exit(f"match.json: no rule covers {missing}")
names = data.get("names", {})
bad = [k for k, v in names.items() if not isinstance(v, str) or not v.strip()]
if bad:
    sys.exit(f"match.json: names must be non-empty strings: {sorted(bad)}")
stray = [k for k in names if not any(n.startswith(k) for n in kos)]
if stray:
    sys.exit(f"match.json: names for no built module (typo?): {sorted(stray)}")
print(f"OK: {len(rules)} rule(s), {len(names)} name(s) -> {out}/match.json")
EOF
}

case "${1:-arm64}" in
  descr) build_descr; stage_match; exit 0 ;;
  arm64|aarch64|all)
    # gunyah_host_share (6.6/6.12: upstream gunyah_* source; 6.1: downstream gh_* source).
    build_mod android15-6.6  ghcr.io/ylarod/ddk-min:android15-6.6  \
        gunyah_host_share/GKI6.6 gunyah_share_mod.c gunyah-host-share-gki-6.6
    build_mod android16-6.12 ghcr.io/ylarod/ddk-min:android16-6.12 \
        gunyah_host_share/GKI6.6 gunyah_share_mod.c gunyah-host-share-gki-6.12
    build_mod android14-6.1  ghcr.io/ylarod/ddk-min:android14-6.1  \
        gunyah_host_share/GKI6.1 gunyah_share_mod.c gunyah-host-share-gki-6.1
    # gunyah_kvcalloc (6.1 only, downstream gh_*).
    build_mod android14-6.1  ghcr.io/ylarod/ddk-min:android14-6.1  \
        gunyah_kvcalloc/GKI6.1 gunyah_kvcalloc_mod.c gunyah-kvcalloc-gki-6.1
    # gh_unmovable (non-movable pinnable mem for small GPU blobs; KMI-agnostic,
    # one source builds for all three via a struct-fd compat shim).
    build_mod android15-6.6  ghcr.io/ylarod/ddk-min:android15-6.6  \
        gh_unmovable/GKI6.6 gh_unmovable.c gh-unmovable-gki-6.6
    build_mod android16-6.12 ghcr.io/ylarod/ddk-min:android16-6.12 \
        gh_unmovable/GKI6.6 gh_unmovable.c gh-unmovable-gki-6.12
    build_mod android14-6.1  ghcr.io/ylarod/ddk-min:android14-6.1  \
        gh_unmovable/GKI6.6 gh_unmovable.c gh-unmovable-gki-6.1
    # udmabuf: registers /dev/udmabuf where the kernel has none (CONFIG_UDMABUF
    # unset, e.g. QCOM 6.1 kernel_platform), kprobe-repairs the built-in where it
    # still kmalloc_arrays its page-pointer array (all GKI 6.6 - order-6 alloc
    # fails on a fragmented phone), and where the kernel is already fixed still
    # raises its 64 MiB size cap, which no VkDeviceMemory blob fits under.
    # Safe to autostart on any device. One portable source for all three KMIs;
    # the per-KMI module name keeps /sys/module from clashing with a built-in
    # "udmabuf".
    build_mod android15-6.6  ghcr.io/ylarod/ddk-min:android15-6.6  \
        udmabuf udmabuf.c udmabuf-gki-6.6
    build_mod android16-6.12 ghcr.io/ylarod/ddk-min:android16-6.12 \
        udmabuf udmabuf.c udmabuf-gki-6.12
    build_mod android14-6.1  ghcr.io/ylarod/ddk-min:android14-6.1  \
        udmabuf udmabuf.c udmabuf-gki-6.1
    # nproc_guard: no-reboot rescue for the per-uid RLIMIT_NPROC ucounts counter
    # desyncing under DroidVM's root<->app real-uid switching (crosvm privilege
    # drop + daemon), which otherwise wedges the app ("won't open until reboot").
    # Loaded by the daemon with the app uid (insmod ... uid=<app uid>); a bare
    # insmod is inert. KMI-agnostic source; builds for all three GKI KMIs.
    build_mod android15-6.6  ghcr.io/ylarod/ddk-min:android15-6.6  \
        nproc_guard nproc_guard.c nproc-guard-gki-6.6
    build_mod android16-6.12 ghcr.io/ylarod/ddk-min:android16-6.12 \
        nproc_guard nproc_guard.c nproc-guard-gki-6.12
    build_mod android14-6.1  ghcr.io/ylarod/ddk-min:android14-6.1  \
        nproc_guard nproc_guard.c nproc-guard-gki-6.1
    ;;
  *) echo "usage: $0 [arm64|descr]" >&2; exit 2 ;;
esac
build_descr
stage_match
echo "Done. Modules in ${OUT}/"
