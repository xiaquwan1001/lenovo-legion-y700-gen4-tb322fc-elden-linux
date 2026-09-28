# 2026-08-08 evening: OEM super + stock-kernel testkey boot + fastboot unreliability

Follow-on to `tb321fu-mod-package-boot.md` (MOD combo passed prevent-flash). This file records
the next day's work: getting the OEM ZUI actually to boot, and the hard evidence that fastboot
writes silently fail on this machine.

## State after MOD combo flashed (start of this session tail)
All six partitions EDL-verified OK: boot_a, vendor_boot_a (MOD PRC), dtbo_a, init_boot_a
(OEM), vbmeta_a (MOD testkey), vbmeta_system_a (MOD OEM-key). super still held the hand-built
GSI super. Boot result: **passes fastboot → BL "未验证" warning → Qualcomm info flash → black
screen / reboot loop** = ABL fully passed, kernel started, system-stage failure.

## Blocker 1: black screen = boot kernel vs system mismatch
- With GSI-in-super + `pixel_pkg/boot.img` (GKI kernel, A1-era assembly): black screen.
- Root cause: **the OEM ZUI system/vendor (once OEM super is in) needs the OEM KERNEL, not the
  GKI kernel**. The MOD package's boot.img is precisely "OEM kernel + testkey footer" — and the
  local equivalent already existed: `repart/final/boot.img` = avbtool re-sign of `row/full/boot.img`
  (first 35,311,616 B hash identical to OEM boot = OEM kernel content, testkey footer, rollback
  1759622400). Verify equivalence before using: sha256 of the first `image_size` bytes vs the OEM
  image. Do NOT use a GSI project's GKI boot with an OEM system.

## Blocker 2 (the big one): fastboot silently fails to write
Sequence of evidence:
1. `fastboot flash boot_a repart/final/boot.img` → `Sending 98304 KB OKAY / Writing OKAY`.
2. EDL read-back of boot_a → hash MISMATCH; ABL logfs then showed
   `Loading Image boot_a Done : 0 ms, Image size : 4096 Bytes` — the partition was ~empty.
3. `fastboot flash super super_pad.img` (13.97 GB, `Sending sparse 'super' 14/14 OKAY`,
   270 s) → EDL read-back of the super head (first 1.3 GiB) mismatched EVERY sample point vs
   the local image; at the 218 MB LP-metadata offset the device held ASCII `get:` garbage.
Conclusion: **fastboot on this host/device pair prints OKAY without landing the data.** All
critical writes must go through EDL and be read-back-verified. (EDL `w` sessions did land —
boot_a/vendor_boot/vbmeta read-back-verified OK repeatedly.)

## EDL firehose sector-size gate (pad exactly, or edl refuses)
`edl.py w super <file>` validates file size against the FIREHOSE GPT:
- firehose reports block_size 4096; super = 3,407,872 sectors.
- Correct pad size = 3,407,872 × 4096 = **13,958,643,712 B**.
- `fastboot getvar partition-size:super` says 0x340000000 = 13,971,390,464 — **different
  caliber, do NOT use it for EDL** (file would be 3,112 sectors too big).
- Error when too big: `has 3410984 sectors but partition only has 3407872` (first attempt),
  then `has 3407875 sectors but partition only has 3407872` (off-by-3 after a bad
  multiplication). Exact arithmetic matters.
- Build pad files on DISK (`~/.../super_build/`), not /tmp — /tmp is tmpfs (14 G) and quota
  dies mid-write (`OSError: [Errno 122] Disk quota exceeded`).
- After a successful EDL write, `Connection detected, quiting.` often prints — that is the
  normal session-exit banner, NOT a failure; read back to confirm.

## QFIL super_1~8 split semantics (confirming the earlier note)
- `cat super_1.img ... super_8.img` = contiguous raw data (total ~10.6 GB < 13.97 GB partition;
  tail zero-padded). NOT Android-sparse (no 0xED26FF3A), NOT one LP image.
- LP markers in the concatenation at NON-standard offsets: `GEOM` @ ~218 MB, `LPML` @ ~3.3 GB
  (two occurrences ~3.45 GB apart = data coincidence, NOT metadata slots; a naive parse of
  those offsets yields garbage version fields — scan, don't assume AOSP head layout).
- OEM system is extractable from the concatenation with a custom LP parser (no lpunpack on the
  box), but flashing the whole OEM super via EDL is simpler and was done.

## Blocker 3: still fastboot-loop with everything OEM — logfs diagnosis
Full OEM combo (OEM-super + OEM-kernel testkey boot + MOD vendor_boot/vbmeta + OEM
vbmeta_system), `setactiveslot a` reset, all partitions EDL-read-back OK → STILL fastboot loop.
Latest logfs record (read via `edl.py r logfs`):
- pcba detection OK (`project_info is Prc_Kirby`) then **`Start EBS [ 7436]` with NO
  `Active Slot` / `Loading Image boot` lines in between** — the ABL gate rejects BEFORE boot
  loading, i.e. before AVB, at a stage that in earlier records DID show
  `Active Slot _a is bootable, retry count N` → `Booting from slot (_a)`.
- Recurring in every record: `Error read virtualab msg version:0 magic:0 not valid` — misc was
  `fastboot erase`d earlier in the session (all-zero 1 MiB), so the VAB (virtual A/B) message is
  gone. Suspect: ABL slot/retry handling degrades without it → direct EBS.
- Plan (in progress at session end): restore the backup misc (`edl.py w misc
  EDL/backup/lun0/misc.bin` — 8-06 state, ffbm-00, device was healthy then) + `setactiveslot a`
  + boot. If still looping, next experiment: OEM vbmeta_system back to MOD vbmeta_system
  (rollback 1754352000 — the combo that previously PASSED ABL with the BL warning).
- Note: `vbmeta_system` rollback anti-rollback was also seen failing in older records
  (`Image rollback index is less than the stored rollback index` for vbmeta_system_a) — OEM
  vbmeta_system rollback 1759622400 vs MOD 1754352000 vs whatever rpmb stores; mix carefully.

## Collaboration pattern (user preference, this session)
USB breakage made agent-driven tool loops wasteful. User switched to: **agent prints exact
commands; USER executes them in the shell and pastes output; agent only analyzes** (verify
writes, compare hashes, read logfs, decide next step). When fastboot/EDL links keep dying,
offer this split early instead of grinding through tool timeouts.
