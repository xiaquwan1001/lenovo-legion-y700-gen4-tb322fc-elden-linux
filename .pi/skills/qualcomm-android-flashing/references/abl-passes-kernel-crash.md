# ABL gate passed — GSI still crashes at kernel stage (TB321FU, 2026-08-07)

Session state as of the end of 2026-08-07. The Android side of the dual boot is NOT yet
working; this documents exactly what was tried, what each attempt proved, and the
diagnostic techniques that worked. Do not treat the Android side as solved.

## Attempt timeline (each attempt = full A-slot flash + `set_active a` + reboot)

| # | boot_a | vendor_boot/init_boot/dtbo | vbmeta_a/vbmeta_system_a | Result |
|---|--------|---------------------------|--------------------------|--------|
| 1 | pixel project's boot.img | pixel project's (custom) | pixel's (flags=0) | "系统与固件不兼容，系统会自动关机" (ABL gate) |
| 2 | pixel project's boot.img | pixel project's (custom) | disable (flags=2) | still ABL gate — **vbmeta flags are NOT the gate** |
| 3 | stock ROW 17.5.10.031 boot.img | stock from EDL backup | stock OEM (flags=0) | **passes ABL** → kernel-stage Qualcomm CrashDump (6-digit code screen), retry drains |
| 4 | stock ROW boot.img | stock from EDL backup | disable (flags=2, EDL-written) | still kernel CrashDump |
| 5 | stock ROW boot.img | **ROW 17.5.10.031 full set** (extracted from COMPLETE zip) | disable (flags=2) | **logo→fastboot loop** (user report; no kernel chars, no CrashDump) — kernel-stage attribution UNVERIFIED; first-boot logfs never captured before retry drained |

Key inference: the Lenovo ABL gate is purely "is boot_a an OEM-standard boot.img".
Anything custom → "不兼容" before AVB even matters. Stock boot → ABL passes → the GSI
kernel crash is a DIFFERENT problem (kernel/init level).

## ROOT CAUSE FOUND (late session): boot-stack VERSION MIXING

Attempts #3/#4 used "stock from EDL backup" for vendor_boot/init_boot/dtbo — but the
EDL backup A-slot is NOT ROW 17.5.10.031. Unpacking the backed-up init_boot_a ramdisk
proved it: `ro.bootimage.build.version.incremental=TB321FU_CN_OPEN_USER_Q00011.0_V_ZUI_17.0.10.338_ST_251126`
(**CN ZUI 17.0.10.338**, Android 15 era) while boot_a was ROW ZUI 17.5.10.031 (Android
16). So attempts #3/#4 booted a **mixed-version stack** (ROW kernel + CN 17.0.10.338
initrd/vendor ramdisk + 17.5.10.031 vendor in super) — the likely kernel-crash cause.
The whole boot stack (boot/vendor_boot/init_boot/dtbo/vendor-in-super) must be ONE
firmware version. Rule: never assume an EDL backup A-slot matches the ROM zip you are
pulling boot.img from — the device has a long mixed flash history (abl=CN ZUXOS
1.5.10.038, A-slot=CN ZUI 17.0.10.338, super vendor=17.5.10.031).

### UPDATE (session end): same-version set was assembled — STILL fails (earlier stage)
Attempt #5 flashed the complete same-version ROW 17.5.10.031 stack (boot/vendor_boot/
init_boot/dtbo all extracted from the full ROM zip; vbmeta_a/vbmeta_system_a = flags=2;
super = GSI system + 17.5.10.031 vendor). User report: **logo → fastboot loop** —
an ABL-stage failure signature (no kernel characters, no CrashDump), NOT a confirmed
kernel CrashDump like attempts #3/#4. The first real boot's logfs record was never
captured (retry drained before reading logfs), so the exact failure image is still
unknown. **Version-mixing was a real bug (fixed) but not the sole cause.** The GSI
system itself is now the prime suspect (GSI-vs-stock-kernel incompatibility). Open
candidates: (1) restore STOCK ZUI system into super (baseline: proves whether stock
boot + stock system boots at all, isolating GSI-vs-kernel); (2) ROW-ABL swap (abl.elf
extracted, never fired); (3) kernel log of the crash itself (minidump is ON per logfs;
EDL `rawdump` read is the candidate). Next time: capture logfs IMMEDIATELY after the
first failed boot of a fresh slot (set_active resets retry; read logfs from Ubuntu, not
from fastboot).

### Verify a boot stack's version WITHOUT booting it (LZ4 ramdisk recipe)
- Android 12+ init_boot/vendor_boot ramdisks are **LZ4 frame** format (magic
  `02 21 4c 18`), NOT gzip and NOT legacy LZ4 (`18 4c 21 02`). `file` says "LZ4
  compressed data (v0.1-v0.9)".
- `unpack_bootimg.py --boot_img <img> --out <dir>` → then
  `lz4 -d <dir>/ramdisk <out.cpio>` (frame-aware CLI handles it; hand-rolled legacy-LZ4
  python does not) → `cpio -id < out.cpio` → version lives in
  `ramdisk/system/etc/ramdisk/build.prop`:
  `grep ro.bootimage.build.version.incremental .../build.prop`.
- Same recipe applies to vendor_boot's `vendor_ramdisk00` (contains only
  first_stage_ramdisk/lib, no build.prop — version check goes through init_boot).

## CrashDump screen: what the digits mean
- The CrashDump screen is NOT an error code. "986998 - UTFS 256G" = RAMDUMP ID +
  hardware-config line (UFS size etc.). No diagnostic value on screen; the real
  failure reason lives in logfs / minidump (see diagnostics above). Don't ask the
  user to read more off the screen — read logfs/rawdump instead.

## Diagnostics that worked

- **logfs (ABL/XBL boot log, 8 MB)**: `edl.py r logfs /tmp/logfs.bin` from EDL after a
  CrashDump, then `strings | grep -iE 'error|fail|panic|rollback|hash'`. Also readable
  from a booted Ubuntu WITHOUT EDL: `sudo dd if=/dev/disk/by-partlabel/logfs bs=4096
  count=2048 | strings ...` — then ship the file back with the upload-server trick
  (`curl -T file http://<pc>:8001/`; python BaseHTTPRequestHandler PUT sink, see
  uefi-boot-chain-vm-bootsys.md).
- Seen in logfs: `boot_a: Image rollback index is less than the stored rollback index`
  (a NEWER firmware — CN ZUXOS 1.5.10.038 — previously flashed raised the stored
  rollback index, so even OEM 17.5.10.031 boot.img is rejected at the AVB layer) and
  `init_boot_a: Hash of data does not match digest in descriptor` (vbmeta descriptors
  drifted from partition contents after mixed flash history). disable-verification
  vbmeta (flags=2) skips BOTH at the AVB layer.
- **CrashDump = kernel/HLOS stage**: ABL already passed; ABL-stage failures instead log
  to logfs and drop to fastboot. After CrashDump, EDL still works (read logfs, rawdump).
- **userdata-untouched inference**: boot the other OS (Ubuntu) and check
  `lsblk -f /dev/sda16` — if userdata is STILL the old ext4 rootfs (label "Ubuntu"), the
  Android kernel died BEFORE userdata format/init (very early kernel crash). If Android
  had reached init, userdata would be f2fs.
- **Don't reboot into the broken slot**: after `set_active a` with a crashing Android,
  `fastboot reboot` drains another retry for nothing. Instead `set_active b` → Ubuntu →
  diagnose from there. (Each failed boot: `slot-retry-count` decrements; 7 → unbootable.)

## ROW 17.5.10.031 package contents (partial, from local-header scan)

- `dl/ROW_ZUI_17.5.10.031.zip` (~7 GB, aria2 -x16 via local 7890 proxy ≈ 20+ MB/s;
  lolinet direct = slow/blocked). [已归档 2026-08-10 → `~/下载/刷机-保留/archive/ROW_ZUI.tar.zst`]
- Extracted with the local-header scan + `zlib.decompress(data,-15)` (method=8) recipe:
  - `image/boot.img` → 100,663,296 B (stock boot, flashed OK)
  - `image/abl.elf` → 241,464 B (for the ROW-ABL-swap fallback; NOT yet flashed)
  - `image/contents.x` (encrypted XML, method=0 store)
- Scanned regions contained ONLY 14 image/ entries — no vendor_boot.img / init_boot.img /
  dtbo.img / vbmeta.img local headers in the downloaded regions. The stock A-slot
  vendor_boot/init_boot/dtbo/vbmeta came from the EDL full backup
  (`EDL/backup/lun4/{vendor_boot_a,init_boot_a,dtbo_a,vbmeta_a}.bin`,
  `EDL/backup/lun0/vbmeta_system_a.bin`) — verified NOT identical to the pixel project's
  images (hash differs), i.e. they are genuine OEM.
- Stock ROW boot.img unpacks as: header v4, kernel 35,289,600 B, ramdisk 0, os_version 0,
  no AVB footer (signature size 0). GUF296 UEFI boot.img: header v3, kernel 2,413,234 B
  gzip'd UEFI env.

## Next-step candidates (re-ordered after attempt #5 — same-version set is DONE, failed)

0. **DONE 2026-08-07**: same-version ROW 17.5.10.031 full set + GSI → still crashes.
   Do not re-run this combination expecting a different result.
1. **Restore STOCK ZUI system into super as a baseline** (top candidate): proves
   whether stock boot + stock system boots at all — isolates GSI-vs-kernel
   compatibility. Rebuild super via the Python-lpmake builder with the OEM system image
   (super_4 was backed up; supers/ split images were deleted with the zui package — need
   to re-extract from the ROM zip or use the earlier super build artifacts).
2. **ROW-ABL swap**: flash `repart/ROW_abl.elf` to abl_a + abl_b (current CN ZUXOS ABL is
   backed up in EDL backup). Rationale: CN ZUXOS ABL may apply extra checks beyond the
   ROW one; ROW ≤17.5.10.170 trusts AOSP test keys. Risk: abl is the fastboot server —
   a bad flash costs fastboot (EDL still works).
3. Kernel log capture for the CrashDump itself (minidump enabled per logfs `Minidump: ON`
   — EDL `rawdump` read is a candidate).
4. Re-read logfs after the latest attempt (from booted Ubuntu:
   `sudo dd if=/dev/disk/by-partlabel/logfs bs=4096 count=2048 | strings | grep -iE
   'error|fail|rollback|hash|boot_a|init_boot|vendor_boot|dtbo|load'`) — the newest boot
   error may name the failing image directly.

## Firmware zip download mechanics (lolinet behind a local proxy)
- `aria2c -x16 -s16 -k1M --all-proxy=http://127.0.0.1:7890` hits ~20+ MB/s for the
  first ~94% then WEDGES (proxy concurrency on the last pieces). Resume with
  `-c --max-tries=0 --retry-window=3600`. Direct (no proxy) is ~33 KB/s — unusable.
- **Completion check**: aria2 preallocates the full size, so `du -sb` / file size lie.
  The zip is only complete when `PK\x05\x06` (EOCD) appears in the last 64–128 KB
  (`tail.rfind(b'PK\x05\x06')`); otherwise local-header scan + `zlib.decompress(data,-15)`
  per file is the partial-extract path (see firmware-zip-partial-extract.md).
- curl per-range hole filling is ~10× slower than aria2 (~200 KB/s total at 4 parallel)
  — the proxy throttles fresh connections; not a viable full-package fallback.
- **RESOLVED 2026-08-07 — have the USER download it**: Motrix (GUI aria2-core
  downloader) completed the full 6,996,426,996 B zip where CLI aria2 and fill_holes both
  wedged. Ask the user to run Motrix (or their usual download manager) on the lolinet
  URL, then point extraction at their file (`~/下载/...zip`). The full zip yields ALL
  image files cleanly: `unzip -l ... | grep -iE 'image/(boot|vendor_boot|init_boot|dtbo|vbmeta|abl)'`
  — incl. `vendor_boot-debug.img` (debug variant — do NOT flash) and plain
  `vendor_boot.img` / `init_boot.img` / `dtbo.img` / `vbmeta.img` / `vbmeta_system.img`
  (all 2025-12-03 dated, stock). boot.img from the full zip hash-matches the earlier
  partial-extract (`095b90ca...`) — validates the local-header scan recipe.

## Verify-before-boot discipline (session-tail additions, 2026-08-07)

- **fastboot flash can LIE (OKAY printed, nothing written)** — the wedge bug can fake a
  successful write. After any critical flash, verify from a booted Ubuntu WITHOUT
  re-entering fastboot: `sudo sha256sum /dev/disk/by-partlabel/<part>` vs the source
  file's hash (init_boot_a was verified good this way: 8 MiB + `ANDROID!` magic; boot_a
  readback was the pending check when the session ended). Partition labels work from
  Linux (`/dev/disk/by-partlabel/`) on this device.
- **vbmeta flags readback from Ubuntu (no EDL needed)**: `sudo dd if=/dev/disk/by-partlabel/vbmeta_a bs=4096 count=1 | xxd` — offset 0x78 must read `02 00 00 00` (= flags=2, verification disabled). Same for vbmeta_system_a. This validates an EDL-written vbmeta in seconds; also proves the EDL "Connection detected, quiting" Sahara error did not silently skip the write (replug USB to recover the Sahara session).
- **logfs reading guide (avoid misdiagnosis)**: `Image size : 4096 Bytes` for a partition is the ABL *header-only* read — NORMAL, NOT corruption (init_boot_a was 8 MiB on disk). `Slot _a is unbootable, trying alternate slot` = ABL DOES auto-fallback to the other slot; only when BOTH slots are drained do you get `FindBootableSlot() status: Load Error` + `LoadImageAndAuth failed: Load Error` → permanent fastboot. `Error read virtualab msg version:0 magic:0 not valid` recurs on EVERY flash command and on boot — misc contains only `ffbm-00` + zeros (no VAB message); treat it as benign noise, not the failure cause.
- **Don't re-boot a crashing slot after resetting it**: `set_active a` + `fastboot reboot` just drains another retry for nothing if Android still crashes. Instead `set_active b` → Ubuntu → read logfs → only then decide the next A-slot experiment.

## Sudo-rs NOPASSWD trap (kubuntu rootfs = Ubuntu 24.04)

- The rootfs uses **sudo-rs 0.2.13**, which does NOT honor NOPASSWD rules in
  `/etc/sudoers.d/` even at mode 440 (`sudo -n true` keeps failing with "interactive
  authentication is required").
- Fix: append to the MAIN `/etc/sudoers`:
  `sudo sh -c 'echo "user ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers'` — verify with
  `sudo -n true`.
- A typo (`ALL-` instead of `ALL=`) breaks ALL sudo (parse error, password sudo too).
  Recovery without sudo: `pkexec sh -c "sed -i '/^user /d' /etc/sudoers && echo 'user
  ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers"` (pkexec auth is independent of sudoers;
  run from the desktop terminal so the polkit prompt shows).
