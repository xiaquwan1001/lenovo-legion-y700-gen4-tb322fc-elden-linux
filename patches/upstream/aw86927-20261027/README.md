# aw86927 firmware waveform series (draft, 2026-10-27)

> **⛔ 已被取代（2026-10-27 晚）：见 `../aw86927-20261027-v2/`。**
> 对 linux-next 核对后决定**先不交固件波形**（上游自带驱动内正弦表，来自 `df53055c540f`），
> 该系列重切为 5 枚无固件提交（并从中拆出 `Fixes:` 单枚）。本目录保留作过程记录，
> **不要再按这里投递**。原因与判据见 `reports/aw86927-series-v2-20261027.md` §2。

Pristine base: `24a19b953` (Linux 7.3-rc7).  Branch in `build/aw-series`:
`aw86927-upstream-series`, 5 commits, tip `409beee0a`.

**Status: draft only — not posted, not pushed.**  Report:
`reports/aw86927-series-20261027.md`.

## Why a series and not a single patch

Upstream `drivers/input/misc/aw86927.c` (882 lines) hardcodes one sine
waveform in a static array and has no `request_firmware()` path.  Every
change below only makes sense once the waveform can come from an image, so
splitting it into a series keeps each commit reviewable and buildable while
never adding data with no consumer.

## Commits

| # | Patch | Purpose | checkpatch --strict | aw86927.o |
|---|---|---|---|---|
| 1 | `0001-dt-bindings-input-awinic-aw86927-...` | `awinic,aw86937`, `firmware-name`, `awinic,ram-waveform-index` (+ `firmware-name` required for AW86937) | 0E/0W/0C, 42 lines | n/a (`dt-doc-validate` rc=0) |
| 2 | `0002-input-aw86927-describe-the-parts-...` | per-chip data table (chipid / model / SRAM window), `detect()` becomes a lookup, AW86937 recognised | 0E/0W/0C, 132 lines | rc=0, W=1 0 warning |
| 3 | `0003-input-aw86927-load-the-RAM-waveform...` | firmware image load: checksum, base/first-waveform validation, indexed waveform selection, FIFO upload + read-back verify; `select FW_LOADER` | 0E/0W/0C, 186 lines | rc=0, W=1 0 warning |
| 4 | `0004-input-aw86927-handle-the-AW8693X-...` | AW8693X two-step stop, PLAYCFG3 bit2 auto-boost, PLAYCFG1 bit5 BST mode, VBAT mode, 7 V code `0x11`→`0x09` | 0E/0W/0C, 114 lines | rc=0, W=1 0 warning |
| 5 | `0005-input-aw86927-stop-playback-over-...` | suspend/resume + shutdown, `suspended` gate, `READ_ONCE/WRITE_ONCE` on level | 0E/0W/0C, 140 lines | rc=0, W=1 0 warning |

Every commit was checked out and rebuilt from a removed `aw86927.o`
(`make ... W=1 drivers/input/misc/aw86927.o`, `CCACHE_DISABLE=1`,
`CC=aarch64-linux-gnu-gcc`): all 5 rc=0, 0 warnings.  Applying
`0001..0005` in order onto pristine `24a19b953` succeeds with `git apply`.

## Risks (what a reviewer is likely to push back on)

1. **`awinic,ram-waveform-index` in DT** — a "which waveform inside my
   firmware blob" index is arguably firmware payload description, not
   hardware description; Krzysztof may ask for it to move to a firmware
   header or to be dropped in favour of "first waveform in the image".
2. **Firmware loading at all** — Rob/Dmitry may argue the in-driver sine is
   enough and a vendor blob loader does not belong in the driver.  Commit 3
   is the one to defend with the AW86937 (no built-in waveform) argument.
3. **AW8693X stop/BST values** — commit 4 encodes vendor-driver behaviour
   (two-step stop, bit positions, 7 V code).  Needs datasheet-backed prose
   rather than "the vendor does this"; the 7 V arithmetic in the commit
   message is currently derived from the vendor `set_bst_vol()` formula and
   should ideally cite the AW8693X datasheet register table.

## Suggested recipients

```
To:      Dmitry Torokhov <dmitry.torokhov@gmail.com>
Cc:      linux-input@vger.kernel.org
Cc:      devicetree@vger.kernel.org
Cc:      Rob Herring <robh@kernel.org>
Cc:      Krzysztof Kozlowski <krzk+dt@kernel.org>
Cc:      Conor Dooley <conor+dt@kernel.org>
```

Commit 1 is a binding-only patch: if the binding thread stalls, send
`0001` alone as `[PATCH]` and the rest as a dependent series later.
