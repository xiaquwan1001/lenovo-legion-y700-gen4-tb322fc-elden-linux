# Android GSI side of the dual boot (TB321FU, verified 2026-08-07)

Companion to `uefi-boot-chain-vm-bootsys.md`. Once the Ubuntu side boots from its own
partitions (vm-bootsys_a FAT + `ubuntu` LP partition), flash the Android side WITHOUT
touching Ubuntu — the two sides are fully isolated.

## Final slot layout
- `boot_a` = Pixel GSI Android, `boot_b` = GUF296 UEFI (Ubuntu).
- Switch: `fastboot set_active a|b`. Android root: `bootctl set-active-boot-slot b`.
- Ubuntu boot chain does NOT read super — re-flashing super is always safe for Ubuntu.

## GSI into the rebuilt super (Python lpmake)
- `super` = LP metadata + dynamic partitions. Rebuild with the GSI in the `system` slot:
  change the builder's `system` image from the OEM split image to the GSI raw ext4
  (e.g. `Pixel-komodo-16_ext4_raw_Signed_V5.img`, 3,758,096,384 B, `file` says
  "Linux rev 1.0 ext2 filesystem, volume name \"Pixel\"" — Android 16 GSI, AVB "Signed").
- Partition sizes auto-round up from image size (3.5G GSI < 5.2G OEM system slot; more
  free super space). LP partition name stays `system` (unsuffixed; fs_mgr falls back).
- Verify both metadata copies' SHA256s after rebuild (primary AND backup slots).
- Flash: `fastboot flash super super_new.img` (~235 s @ USB2) or `edl.py w super ...`.
  OEM vendor/product/system_ext/system_dlkm/vendor_dlkm/odm stay as the firmware's
  split images — GSI needs a matching-API vendor (SDK 36 vendor + Android 16 GSI OK).

## A-slot image set (from the GSI package)
```
fastboot flash boot_a           <pkg>/boot.img          (100,663,296 B, v4)
fastboot flash init_boot_a      <pkg>/init_boot.img     (8,388,608 B)
fastboot flash vendor_boot_a    <pkg>/vendor_boot.img   (100,663,296 B)
fastboot flash dtbo_a           <pkg>/dtbo.img          (25,165,824 B)
fastboot flash vbmeta_a         <pkg>/vbmeta.img        (8,192 B)
fastboot flash vbmeta_system_a  <pkg>/vbmeta_system.img (4,096 B)
fastboot set_active a && fastboot reboot
```
- First Android boot reformats userdata (f2fs) — the OLD Linux rootfs on userdata is
  wiped at that point (fine once the new rootfs lives on the `ubuntu` partition).

## AVB reality on this device
- Device vbmeta_a and the GSI package's vbmeta both parse with flags=0 (no
  disable-verification), yet the fully custom UEFI boot.img boots — AVB is effectively
  non-enforcing on this unlocked unit (empty vbmeta / lenient ABL). Do not assume this
  for other units; verify empirically (flash + boot attempt) or use
  `fastboot --disable-verity --disable-verification flash vbmeta_a <img>` preemptively.

## Pitfall: fastboot wedge mid-batch
- Multi-partition flash batches truncate output when the channel wedges (a flash prints
  "Writing..." then silence; following commands return nothing). Replug USB, then verify
  each partition landed (`getvar partition-size:<name>` unchanged + `fetch <part>` back
  and hash, or just re-run the flash — it is idempotent) before rebooting.
