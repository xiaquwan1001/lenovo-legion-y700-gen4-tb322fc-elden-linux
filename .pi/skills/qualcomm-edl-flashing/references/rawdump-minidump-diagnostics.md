# Kernel-stage crash forensics on Qualcomm Android (rawdump / logfs / EBS)

How to find out WHY a boot fails when the screen shows nothing (kernel cmdline
`console=ttynull` + `video=vfb:640x400` = zero kernel text on screen; ABL SilentBoot).
All three techniques verified 2026-08-07 on TB321FU.

## 1. rawdump partition = minidump with the FULL kernel dmesg
After a kernel-stage crash (Qualcomm CrashDump screen, or a silent "logo → fastboot loop"),
the device keeps a minidump in the `rawdump` partition (LUN 0, 256 MB, logfs shows
`Minidump : ON`). Read it via EDL — no boot needed:

```
edl.py --loader=<melf> r rawdump /tmp/rawdump.bin     # 268435456 B
strings /tmp/rawdump.bin | grep -iE 'panic|liblp|Kernel command line|init:|kernelsu|Modules linked'
```

It contains the kernel's dmesg INCLUDING the exact fatal line — e.g. the LP-geometry bug:
`[0.615320][T1] init: [liblp] Logical partition metadata has invalid geometry magic signature.`
Also visible: full kernel cmdline (confirm `console=ttynull`), module list, KernelSU boot lines.
This is the ONLY reliable kernel log source when there is no UART and the screen is silent.
**Caveat 2026-08-07 (GRUB direct-boot route): rawdump is only refreshed by ABL-launched
kernel panics.** A kernel panic under GUF296's GRUB/linuxdirect launch (custom UEFI env)
writes NO new minidump — the partition keeps the old ABL-boot dump (verify by `console=`
in its `Kernel command line:` line: ttynull = ABL boot / stale, ttyMSM0|tty0 = GRUB boot).
So \"no new rawdump\" after a GRUB-launched panic is EXPECTED, not a sign the panic was
milder.

## 2. logfs = ABL/XBL log, ring buffer of ~2-3 boots
Read: `edl.py r logfs /tmp/logfs.bin` (8 MB, LUN 0) or from booted Linux:
`sudo dd if=/dev/disk/by-partlabel/logfs bs=4096 count=2048 | strings`.
Key lines and meanings:
- `Start EBS [<ms>]` = ExitBootServices reached → **ABL passed; control handed to kernel**.
  Failure AFTER this is kernel-stage, not ABL.
- `Slot _a is unbootable, trying alternate slot` then `Active Slot _b is bootable, retry
  count N` / `Booting from slot (_b)` = ABL DOES auto-fall-back to the other slot.
- `avb_slot_verify.c: ERROR: boot_b: Image rollback index is less than the stored rollback
  index` = anti-rollback: a newer firmware raised the stored index; UEFI-path boot.img
  (GUF296-style) ignores it, Linux-path boots reject it (unless vbmeta flags=2).
- `Loading Image <part> Done : N ms, Image size : 4096 Bytes` = header-only probe read
  (normal) — do NOT misread as "partition is 4 KB".
- `Handling Cmd: flash:<part>` = fastboot sessions are logged too.
- **RING BUFFER TIMING**: a subsequent successful boot (e.g. Ubuntu) OVERWRITES the failed
  slot's record. Read logfs via EDL IMMEDIATELY after the failed boot (device still in
  EDL/fastboot), do NOT boot the other OS first. If you boot the other OS, the failure
  record is gone.
- CrashDump screen's 6-digit number + HW line (`986998 - UFS 256G` style) is just the
  ramdump-ID + hardware info — no diagnostic value; the error lives in rawdump/logfs.

## 3. EDL sector math (4096-byte sectors)
`edl.py rs <sector> <n> <file>` addresses by 4096-byte sector. Partition offset from
printgpt is hex BYTES: sector = offset / 4096. E.g. super `0x16188000` → 90504.
Wrong arithmetic reads neighboring data that looks like random ARM code — sanity-check the
dump's content (geometry magic `gDla` for super head, "EFI PART" for GPT, `ANDROID!` for
boot) before analyzing.

## 4. Readback-verify strategy
- Small writes into padded partitions: compare only the FIRST written bytes
  (`head -c 4096 | sha256sum`), not the whole readback (stale tail).
- Big partitions (boot/vendor_boot/init_boot/dtbo): `sudo sha256sum
  /dev/disk/by-partlabel/<part>` from booted Linux vs the source file — confirms fastboot
  writes really landed (they do, even after channel wedges).
