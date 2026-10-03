# Kernel crash on stock boot stack + GSI: root cause = corrupt LP geometry (2026-08-07)

Continuation of `abl-passes-kernel-crash.md`. The same-version ROW 17.5.10.031 set
(boot/vendor_boot/init_boot/dtbo all extracted from the COMPLETE ROM zip, hashes verified
on-device via `sudo sha256sum /dev/disk/by-partlabel/<part>`) + GSI system in a rebuilt
super still looped "logo → fastboot". This note records how the real cause was found and
fixed. **Do NOT repeat the dead ends**: version-mixing (already fixed) and "GSI-vs-stock
kernel incompatibility" (WRONG — see below) were both red herrings.

## The key evidence chain
1. **ABL was NOT the blocker.** logfs (EDL `r logfs`) showed `Start EBS [7425]` =
   ExitBootServices reached — control handed to kernel. Also seen:
   `Slot _a is unbootable, trying alternate slot` (ABL auto-falls-back), and for the
   GUF296 boot_b: `avb_slot_verify.c ERROR: boot_b: Image rollback index is less than the
   stored rollback index` (UEFI path ignores it).
2. **Screen is silent BY DESIGN**: kernel cmdline is `console=ttynull
   video=vfb:640x400,bpp=32,memsize=3072000` + ABL SilentBoot — no kernel text ever
   displays. Never ask the user to read a panic off the screen; pull the minidump.
3. **rawdump partition (LUN 0, 256 MB) holds the full kernel dmesg** from the crash:
   `edl.py r rawdump /tmp/rawdump.bin` then `strings | grep -iE 'liblp|panic|init:|Kernel command line'`.
   Fatal line found:
   `[0.615320][T1] init: [liblp] Logical partition metadata has invalid geometry magic signature.`
   Kernel died at init stage reading super — BEFORE userdata format (consistent with the
   lsblk "userdata still ext4" inference).
4. **Root cause layer 1 = our Python-lpmake builder wrote `LpMetadataGeometry` fields at
   WRONG OFFSETS** (`struct_size` @4 instead of @36, checksum @8-40 instead of @4-36). Header +
   tables SHA256s passed; geometry is validated separately by liblp and silently rejected.
   Correct v1.1 layout (52 B): magic@0 `0x616c4467` "gDla", checksum@4-36 (SHA256 of first
   52 B, checksum field zeroed), struct_size@36 (=52), metadata_slot_count@40,
   max_size@44, metadata_max_size@48.
5. **Root cause layer 2 (the ACTUAL blocker — field fix alone still did NOT boot)**: the
   super-LEVEL copy layout was wrong. liblp probes geometry positions in the first 3×4096 B
   and expects the metadata header at 12288; the builder wrote geometry@0 (single copy) +
   metadata@4096, so liblp read the metadata magic `0PLA` at a geometry position → same
   `invalid geometry magic signature`. Stock evidence: `supers/super_1.img` shows `gDla`
   @4096/@8192, `0PLA` @12288. Fix: 3 geometry copies @0/4096/8192, metadata @12288, data
   @1MiB, backup metadata+geometry at end — verified by re-reading the built image
   (gDla@0/4096/8192 + 0PLA@12288) and on-device (`edl.py rs 90504 32` — super offset
   0x16188000 / 4096 = sector 90504), re-flashed via `edl.py w super super_new.img`
   (~37 MB/s, ~6 min). **Android boot test PENDING at session end** (a-slot retry reset
   via `fastboot set_active a`, booting).
6. **Lesson**: when a kernel-stage crash follows a super rebuild, verify BOTH layers — LP
   geometry fields/checksum AND the super copy layout (geometry positions vs metadata start)
   — on the FLASHED super before suspecting GSI/kernel incompatibility. A 13 GB write cycle
   is wasted otherwise. See qualcomm-edl-flashing super-reconstruction step 3b/3c +
   `references/rawdump-minidump-diagnostics.md` (EDL sector math, readback rules).
7. **Old-vs-new rawdump discrimination** (avoided a false "still broken" conclusion): after
   an init-stage (non-panic) failure — e.g. the liblp reject above — NO new minidump is
   written; `edl.py r rawdump` returns the PREVIOUS dump. Tell old from new by (a) the
   `console=` in its `Kernel command line:` line (ttynull = ABL-boot old dump) and (b)
   matching fatal-line timestamps across dumps (identical `[0.615320]` liblp lines =
   same old dump, not a fresh crash). A fresh boot test that ends in fastboot with an
   unchanged rawdump means the failure was non-panic (init-stage), not "kernel never ran".

## Operational notes from the same session (reusable)
- **Tablet DHCP IP changes on EVERY reboot** — SSH host is never stable; get the fresh IP
  from the user (`ip addr show wlan0 | grep 'inet '`) each time. Transfer files
  tablet→PC with a tiny HTTP PUT server on the PC (`python3 upload_server.py` w/
  BaseHTTPRequestHandler) + `curl -T <file> http://<pc-ip>:8001/<name>` on the tablet.
- **Downloading large firmware zips (China network)**: local proxy 127.0.0.1:7890 works;
  aria2 -x16 got 94% at 22 MB/s then STALLED on stubborn ranges (0 bytes/15s; `du -sh`
  vs `du -sb` — a preallocated sparse file shows full size while holes remain). curl
  hole-filling was too slow (~200 KB/s). **Reliable finish: user's Motrix GUI
  downloader** completed the 7 GB zip. When aria2 stalls near the end, hand the URL to
  Motrix instead of writing more retry logic.
- Verify on-device partition contents from booted Linux: `sudo sha256sum
  /dev/disk/by-partlabel/boot_a` — fastboot writes were real even after channel wedges.
- vbmeta disable-verification (flags=2) readback: `sudo dd if=/dev/disk/by-partlabel/
  vbmeta_a bs=4096 count=1 | xxd` → flags at offset 0x78 must read `02 00 00 00`.
