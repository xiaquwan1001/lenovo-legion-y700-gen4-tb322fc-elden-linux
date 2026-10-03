# Boot-chain corrections (TB321FU, verified 2026-08-07)

Two pitfalls in this skill's SKILL.md body were based on the pre-verification model and
are now KNOWN TO BE WRONG for TB321FU (GUF296 scheme). Full verified mechanism:
`../qualcomm-android-flashing/references/uefi-boot-chain-vm-bootsys.md`.

1. **"GRUB `search --file /Image` interference" (grubfat theory) — likely wrong.**
   A marker experiment (marked grub.cfg/qcomramp.cfg with `[NEO-OUTER]`/`[NEO2]`,
   timeout 15/10) proved the LUN-0 `grubfat` FAT is NEVER read. The real boot FAT is
   `vm-bootsys_a` on LUN 4 (sde19, 537 MB, label Y700BOOT). The recurring
   `slot-unbootable:yes` fastboot loop is instead **retry drain**: desktop Linux never
   marks the slot boot-successful, so ABL decrements `slot-retry-count` on EVERY boot
   and after 7 boots marks the slot unbootable — even though booting worked. Fix stays
   `fastboot set_active <slot>` (clears flag + resets retry to 7).

2. **"FAT-side GRUB config may be IGNORED ... plan to rebuild/byte-patch boot.img" —
   the fix is NOT boot.img surgery.** Root stayed `root=PARTLABEL=userdata` because
   vm-bootsys_a's `QCOMRAMP.EFI` was the EMBEDDED-config variant (root baked into the
   binary). The working fix: edit the vm-bootsys_a FAT image (mtools on the EDL backup
   `EDL/backup/lun4/vm-bootsys_a.bin` — it IS the Y700BOOT FAT), swap QCOMRAMP.EFI for
   the CONFIGFILE variant, write `EFI/BOOT/qcomramp.cfg` with the new root, then
   `edl.py --loader=<melf> w vm-bootsys_a <img> --lun=4` (`--lun` REQUIRED — the
   partition is on the bootloader LUN). Write-back is ~20 s at 35 MB/s.

Diagnostic shortcuts that worked:
- `lsblk -f` from the booted Linux lists every FAT (vfat rows) — the boot FAT was
  found as `sde19` this way; Linux partition numbering follows GPT entry order, not
  printgpt's offset-sorted display.
- Marker experiment pattern: add visible markers to each candidate config source,
  reboot once, see which appear. Kills theory branches at zero cost.
- Distinguish QCOMRAMP variants: `strings` for `root=PARTLABEL`/`userdata` (embedded)
  vs a `configfile` search for `qcomramp.cfg` (CONFIGFILE); sizes 4,013,880 vs
  4,018,176 B.
