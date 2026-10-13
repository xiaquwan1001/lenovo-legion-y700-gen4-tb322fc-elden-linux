# M3-4 display slice — nt36536 panel patches (2026-10-13)

Source tree: `build/m3-4-worktree` (detached @ 24a19b953e, Linux 7.3-rc7 pristine).
Baseline file: `drivers/gpu/drm/panel/panel-novatek-nt36536.c` (already in mainline,
only of_device_id = `csot,pp8807hb1-1`, `is_dual_dsi = true`).
Diff vs pristine: `1 file changed, 62 insertions(+), 18 deletions(-)` in 6 hunks.

## Series (4 patches, apply in order on 24a19b953e)

| # | file | logical change | status |
|---|---|---|---|
| 0001 | add-40Hz-and-24Hz-modes | panel mode data (40Hz + 24Hz) | upstream-ready |
| 0002 | finish-setup-before-attach | resolve backlight + set all DSI formats before attach | upstream-ready |
| 0003 | power-off-on-any-prepare-f | single `power_off:` exit, check `accum_err`, handle backlight error | upstream-ready (reviewer may question scope) |
| 0004 | reject-enable-when-prepare | .enable returns -EIO when prepare failed | upstream-ready (new pattern; see report §5) |

## NOT included: to_primary_dsi H1 (blocked)

The payload made `to_primary_dsi()` return `ctx->dsi[0]` unconditionally
(was `ctx->desc->is_dual_dsi ? ctx->dsi[1] : ctx->dsi[0]`). That is a board-level
fact (elden DSI wiring) applied to the only in-tree panel desc, so it changes the
DMA/command master of the existing `csot,pp8807hb1-1` panel. It is deliberately
left out of this series. Proposed design: a per-panel desc field
(`u8 primary_dsi;`) — see `../../reports/m3-4-display-slice-20261013.md` §5.

## Gates run

- `scripts/checkpatch.pl --strict --no-tree <each patch>`: 4/4 **0 errors, 0 warnings**.
- `make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/gpu/drm/panel/`: **rc=0**.
- No binding/DTS change ⇒ `dt-doc-validate` not applicable.

## Recipients (scripts/get_maintainer.pl --no-git-fallback --no-rolestats)

```
Neil Armstrong <neil.armstrong@linaro.org>
Jessica Zhang <jesszhan0024@gmail.com>
Maarten Lankhorst <maarten.lankhorst@linux.intel.com>
Maxime Ripard <mripard@kernel.org>
Thomas Zimmermann <tzimmermann@suse.de>
David Airlie <airlied@gmail.com>
Simona Vetter <simona@ffwll.ch>
dri-devel@lists.freedesktop.org
linux-kernel@vger.kernel.org
```

## Submit checklist (per patches/upstream/README.md 三问门)

- Q1 subsystem: DRM/KMS + drm_panel ✅
- Q2 same-class driver: extends existing novatek-nt36536 driver ✅
- Q3 hardware fact vs policy: mode timings are data; probe/enable ordering is
  driver policy (allowed in C) ✅
- No `module_param`/debug hooks, no cmdline workarounds, no DSI/dispcc experiment
  hooks mixed in ✅
