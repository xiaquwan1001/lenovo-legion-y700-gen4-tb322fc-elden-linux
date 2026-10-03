# TB321FU verified UEFI boot chain (empirically proven 2026-08-07)

Corrects the earlier "boot.img = gzip'd GRUB EFI" model. Discovered by marker experiments:
a grubfat FAT with visibly-marked configs (`[NEO-OUTER]` menu, timeout=15) was COMPLETELY
ignored — the booted root stayed `root=PARTLABEL=userdata` no matter what was written to
LUN-0 FATs.

## The real chain
```
XBL -> ABL -> boot_a/b boot.img -> Qualcomm UEFI environment (DXE) -> BDS boot manager
     -> FAT on BOOTLOADER LUN (vm-bootsys_a) -> EFI/BOOT/BOOTAA64.EFI (outer GRUB)
     -> reads EFI/BOOT/grub.cfg (outer menu) -> chainloads EFI/BOOT/QCOMRAMP.EFI
     -> QCOMRAMP runs `linuxdirect /Image root=PARTLABEL=...` (Qualcomm modules
        linuxdirect / rampartition / qcomfdtmem, direct-boot from rampartition memory)
```

### boot.img payload = full Qualcomm UEFI firmware env, NOT GRUB
- Android boot header v3; kernel section gzip'd; decompresses to 4,194,416 B.
- Payload magic `0x10000381` (not ARM64 Image `0x644d5241`, not PE/MZ at offset 0);
  `file` misidentifies it; `7z x` on the decompressed payload WORKS -> ~224 files /
  12.9 MB = EDK2 DXE driver set: BdsDxe.efi, DxeCore.efi, LinuxLoader.efi (ABL variant:
  strings contain "Bootloader Version", unlock warnings, "Boot to FFBM"),
  RamPartitionDxe.efi, Fat.efi, UFSDxe.efi, VariableRuntimeDxe.efi, uefiplat.cfg.raw ...
- The UEFI env's BDS then loads GRUB from a FAT it finds on the bootloader LUN.

### The real boot FAT: vm-bootsys_a (not grubfat!)
- `vm-bootsys_a` on LUN 4 = 537 MB FAT32, label `Y700BOOT`, GPT type 0x7b034c58,
  shown as `sde19` in Linux (lsblk numbering follows GPT entry order).
- GUF296 repurposed the Android VM-bootsys partition as the GRUB boot FAT.
- Contents: `EFI/BOOT/BOOTAA64.EFI` (753,664 B outer GRUB), `EFI/BOOT/QCOMRAMP.EFI`,
  `EFI/BOOT/grub.cfg` (291 B outer menu: timeout=3, "Continue boot" chainloads
  QCOMRAMP.EFI), `dtb/`, `Image` (kernel, 56 MB), BOOT-INFO.txt, SHA256SUMS.txt.
- `boot/grub/` on this FAT is EMPTY — outer GRUB reads `EFI/BOOT/grub.cfg`, not
  `/boot/grub/grub.cfg` (do not waste time placing configs under /boot/grub).

### QCOMRAMP.EFI: two variants, root is decided HERE
- EMBEDDED variant (what ships in vm-bootsys_a by default): config baked into the EFI —
  `strings` shows `menuentry "Qualcomm direct boot (RamPartition memory, userdata root)"`
  and `linuxdirect /Image root=PARTLABEL=userdata ...`. This is why root stayed userdata
  no matter what FAT configs said.
- CONFIGFILE variant (GUF296 release `QCOMRAMP-CONFIGFILE.EFI`, 4,018,176 B): embedded
  script is only `set timeout=0 ... search --no-floppy --file /EFI/BOOT/qcomramp.cfg
  --set=root; configfile /EFI/BOOT/qcomramp.cfg` — reads an external config.
- Distinguish: grep embedded payload for `userdata` / `root=PARTLABEL` (embedded) vs
  `qcomramp.cfg` configfile search (CONFIGFILE). Also compare size (4,013,880 vs
  4,018,176).

## Changing the booted root (verified recipe)
1. Take the EDL backup copy of the FAT: `EDL/backup/lun4/vm-bootsys_a.bin` (it IS the
   Y700BOOT FAT, serial matches `sde19`).
2. Edit in place with mtools (no root, no mount):
   `mdel -i vm-bootsys_fix.bin ::/EFI/BOOT/QCOMRAMP.EFI`
   `mcopy -i vm-bootsys_fix.bin QCOMRAMP-CONFIGFILE.EFI ::/EFI/BOOT/QCOMRAMP.EFI`
   `mcopy -i vm-bootsys_fix.bin qcomramp.cfg ::/EFI/BOOT/qcomramp.cfg`
   where qcomramp.cfg = direct-boot config with `root=PARTLABEL=ubuntu rw rootwait
   drm_client_lib.active=none` (+ `qcomfdtmem source rampartition` + disable-reserved
   paths for qdss/splash/trust-ui/oem). Keep the outer grub.cfg untouched (it already
   chainloads QCOMRAMP.EFI).
3. Write back over EDL (partition lives on bootloader LUN — `--lun` REQUIRED):
   `edl.py --loader=<melf> w vm-bootsys_a vm-bootsys_fix.bin --lun=4`
   (537 MB @ ~35 MB/s ≈ 20 s). Then `edl.py reset`.
4. Boot verification: outer menu appears (timeout=3) -> if QCOMRAMP now reads
   qcomramp.cfg, a second menu with the config's title appears (set timeout=10 in the
   cfg to make it visible); root should mount the new PARTLABEL. Check with
   `df -h /` + `cat /proc/cmdline` from the booted OS.
- Rollback: re-flash the untouched `EDL/backup/lun4/vm-bootsys_a.bin`.

## Marker experiment pattern (general)
To determine which config source a boot chain actually reads: add unmistakable markers
(menu title suffix like `[NEO-OUTER]`, `[NEO2]`, changed `timeout=`) to each candidate
source, reboot once, and see which markers appear. Zero-cost, kills entire theory
branches. On TB321FU: grubfat markers never appeared -> grubfat not in chain.

## A/B slot retry drain (why "boot loops" happen with Linux)
- Desktop-Linux rootfs never marks the slot boot-successful (that's bootctl/Android
  behavior), so ABL decrements `slot-retry-count` on EVERY boot, successful included.
- After 7 boots: `slot-unbootable:<slot>:yes`, device drops to fastboot though booting
  worked. `fastboot getvar slot-retry-count:<slot>` shows the drain.
- Fix: `fastboot set_active <slot>` (clears unbootable, retry back to 7). Recurring
  issue every session until the rootfs runs a slot-marking service.

## Device control & file transfer without adbd (desktop-Linux rootfs)
- SSH: `sshpass -p 1234 ssh GUF296@<ip>` (sshpass via `apt-get download sshpass &&
  dpkg -x`). NOPASSWD sudo: write `/etc/sudoers.d/guf296` with
  `GUF296 ALL=(ALL) NOPASSWD: ALL` — file MUST be mode 440 (sudo silently ignores
  644/666 sudoers.d files -> "interactive authentication is required" despite the rule).
  Note: the agent must NOT pipe passwords to `sudo -S` (hard-blocked); the user sets
  NOPASSWD once.
- Pull files FROM the device: run a tiny HTTP PUT receiver on the PC
  (BaseHTTPRequestHandler do_PUT saving to /tmp/up), then on the tablet
  `curl -T <file> http://<pc-ip>:8001/<name>`.
- Find FAT partitions / map Linux numbers: `lsblk -f` (vfat rows) — Linux partition
  numbering follows GPT entry order, not printgpt's offset-sorted display; cross-check
  the actual name with `lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL /dev/sdXN`.
