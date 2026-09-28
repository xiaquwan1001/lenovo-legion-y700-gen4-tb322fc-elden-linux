# TB321FU `prevent flash verify` — ABL rejects ALL modified boot chains (2026-08-08 evening)

Resolves the "fastboot-loop blocker" left open in `tb321fu-region-lock.md`. The region
gate (vendor_boot DTB PRC values) PASSED, but the device then fastboot-looped under every
image combination — root cause found: Lenovo ABL's **`prevent flash verify`** boot-chain
"officialness" check. Manual patching cannot boot a custom Android on this ABL.

## Symptom
- Region-converted PRC vendor_boot + any boot stack → device fastboot-loops (never EBS
  "不兼容" again — the region gate is behind you; a NEW gate fires).
- Screen shows the bootloader/fastboot interface; no kernel characters, no CrashDump.

## Decisive logfs evidence (5/5 boot records in the ring buffer ALL end `Start EBS`)
- Every record ends `Start EBS [<ms>]` — including the b-slot (GUF296 UEFI) attempt.
- The LAST boot (PixelOS GKI chain + PRC vendor_boot + disable vbmeta) shows NO
  `Booting from slot`, NO `Load Image boot_a` — ABL decided EBS BEFORE loading boot.
- Historical segment, the smoking gun, right before `Start EBS`:
  `run into prevent flash verify!!!`
- Segment with `Active Slot _b is bootable, retry count 6` / `Booting from slot (_b)` /
  `Loading Image boot_b ... Image size : 4096 Bytes` → also `prevent flash verify` → EBS.
- Segment `Slot _a is unbootable, trying alternate slot` + `FindBootableSlot() status:
  Load Error` (earlier state).

## Check chain (inferred order, empirical)
`region check (vendor_boot DTB region values)` → **`prevent flash verify` (boot-chain
officialness — fires on ANY modified image)** → `AVB` → load boot. Note the region check
comes FIRST: unpatched ROW images die at region ("不兼容"), patched images pass region then
die at prevent-flash.

## Elimination matrix (all six combos → fastboot loop)
| boot | vbmeta | outcome |
|---|---|---|
| ROW stock (EDL-flashed) | OEM enable | EBS "不兼容" (region gate) |
| fingerprint-PRC all 4 images | disable | EBS "不兼容" (fingerprints not the check target) |
| region-PRC vendor_boot + testkey re-signed rest | testkey enable | fastboot loop (prevent flash) |
| region-PRC vendor_boot | disable | fastboot loop |
| ROW stock boot + region-PRC vendor_boot | disable | fastboot loop |
| PixelOS GKI chain + region-PRC vendor_boot | disable | fastboot loop (no boot load at all) |

## Ruled out (with evidence)
- **Partition corruption**: EDL readback of boot_a / init_boot_a / recovery_a / pvmfw_a —
  all `ANDROID!` magic, full sizes (96/8/100/1 MB). The `Image size : 4096 Bytes` lines in
  logfs were HISTORICAL segments, not current state.
- **Panel mismatch**: dtbo_b == ROW dtbo == pixel_pkg dtbo (marker-identical; all contain
  boe + csot overlays, panel id 0x8000). `Dynamic-Detected panel Failed` appears in every
  segment (incl. ones that later booted) — treat as non-fatal noise, not the gate.
- **devinfo**: full 4096 B dump = `ANDROID-BOOT!\x01\x01` + one 0x01 at 0x90; nothing that
  could gate prevent-flash.
- **AVB enable vs disable**: both loop. **misc/ffbm-00**: erasing misc changed nothing.

## Conclusion & the only working path
Lenovo ABL's `prevent flash verify` rejects ANY non-official boot chain — manual region
patch, testkey re-sign, GKI kernel all trigger it. **Manual patching is a dead end for
booting a custom Android on this device.** The community-proven path is the OFFICIAL
toolchain: QFIL / Flash.cmd flashing of a pre-converted MOD firmware (ahnoriku's ROW→PRC
packages; the vendor_boot conversion done by the official `TB320FC_ROW_fastboot_prc_v2.x`
tool is accepted by ABL). Thread: XDA "Lenovo Y700 Gen 3 CN Rom to ROW Rom Guide" (4744907).

## PixelOS/GSI boot-chain package anatomy (pixel_pkg, A1-era, useful reference)
- `boot.img` 96 MB carries its OWN AVB footer: AOSP testkey (pubkey sha1 2597c218…),
  SHA256_RSA4096, rollback 1759622400 — the GSI ecosystem DOES sign boot with the testkey.
- `vbmeta.img` (testkey, flags=0): chain boot (loc3, testkey) / chain recovery (loc1,
  testkey) / chain vbmeta_system (loc2, OEM key cdbb7717…) / hash descriptors
  dtbo+init_boot+vendor_boot / hashtree descriptors odm+system_dlkm+vendor+vendor_dlkm
  (super logical partitions — fs_mgr verifies these at Android boot!).
- `vbmeta_system.img` (OEM key cdbb7717, RSA2048, rollback 1759622400, flags=0): ONLY a
  prop (os_version '16'), NO descriptors → system/vendor NOT verified.
- `vendor_boot.img` carries 4× `IROW` — same region markers as ROW stock → a GSI project's
  own boot stack is region-gated too (rejected at region before prevent-flash even matters).

## Session-end state
- b-slot Ubuntu normal (`fastboot set_active b` restores it; the two sides are isolated so
  a-slot experiments never touch Ubuntu).
- a-slot: mixed pixel_pkg state, harmless — will be overwritten by the MOD-package flash.
- Next step (user-owned): download ahnoriku MOD `ZUI 17.5.10.031 mod ROW→PRC` (6.63 GiB,
  Google Drive id `1X6OP5QoNBUsJyhRsSojN_Qm5RqT5Ws9q`), USB 2.0 cable + LONG-side USB-C
  port, official Flash.cmd / QFIL flow → stock PRC ZUI boots → NindoS GSI steps
  (erase system + flash GSI + wipe userdata).
