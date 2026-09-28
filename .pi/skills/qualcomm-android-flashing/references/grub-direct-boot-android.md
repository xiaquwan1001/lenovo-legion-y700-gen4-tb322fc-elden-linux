# GRUB direct-boot of Android (bypass ABL entirely) — "Plan B"

Status 2026-08-07 (END OF SESSION): DBI blocker root-caused and confirmed
KERNEL-IMAGE-dependent; **Plan B parked at a hard blocker** — linuxdirect is a prebuilt
binary, the custom source is NOT public, and the DBI data's location/format inside the
GUF296 kernel was not identified (see §7). Do NOT re-run this matrix. Findings:
1. **Standard `initrd` command is NOT usable** — errors `you need to load the kernel
   first` (GUF296 module set has NO initrd.mod: `--modules="normal linuxdirect fdt fat
   part_gpt search search_fs_file reboot halt sleep rampartition"` from
   scripts_lib_y700-direct-grub.sh; linuxdirect does not register the standard
   kernel-loaded state). The working command is **`initrddirect`** (`strings` in the EFI:
   `Load initrd for linuxdirect.`), a GUF296-custom sibling of linuxdirect:
   ```
   linuxdirect /android/Image ${acmd}
   initrddirect /android/initrd
   ```
2. `linuxdirect ... initrd /path` as an ARGUMENT → `synchronous error, recursive
   exception` (linuxdirect does not parse an initrd keyword). `--initrd /path` parses but
   is passed through to the kernel cmdline (no error, no initrd loaded).
3. **`DBI dump table info not found` — ROOT CAUSE FOUND**: NOT `qcomfdtmem` (persists
   without it) and not a misread string (absent from every component's strings: both
   EFIs, UEFI 7z dump, both kernels, both ramdisks). **GUF296's kernel Image is a
   PACKAGED format: kernel + embedded dtb (@28,847,552) + bootconfig (@34,247,372) +
   DBI table.** linuxdirect parses these appended segments; a bare Android kernel Image
   (35,289,600 B, no appended segments) → format-level failure, screen prints
   `DBI dump table info not found`, boot stops. Evidence: GUF296 /Image contains
   `d0 0d fe ed` @28,847,552 and `bootconfig` @34,247,372; its tail 1 MB holds 186,681
   non-zero bytes (not pure padding). Both dtbs tested (GUF296 dtb AND dtb#7 PineappleP)
   show the error with the bare Android kernel → kernel-Image-dependent, not dtb.
4. With initrddirect + no qcomfdtmem the bare-kernel menu boots "without error" but never
   reaches Android (screen sits on the DBI line, no CrashDump, no reboot loop).
5. **dtb pick was wrong in the first attempt**: the 11 vendor_boot dtbs are NOT all
   "cliffs" — models are Cliffs/Cliffs7/Cliffs7P/CliffsP/Pineapple×2/PineappleP×2/
   Volcano×3 (msm-ids 0x266…0x281). SM8650P (hwboardid=SM8650P_12+256_01) = **PineappleP**
   = dtb#7 (msm-id 0x241 0x10000); the old ABL-booted kernel log shows `qnoc-pineapple`
   ×28, proving ABL picked a pineapple-family dtb. **dtb#7 was tested — STILL DBI**, so
   dtb choice is definitively ruled out as the trigger (dtb#0 cliffs, dtb#7 PineappleP,
   and the GUF296 custom dtb all behave identically with the bare Android kernel).
6. **Experiment 3 (GUF296 kernel + Android initrd) — DBI GONE, kernel boots**: boot
   GUF296's own /Image (segments present) + GUF296 dtb + `qcomfdtmem source rampartition`
   + Android initrd via initrddirect. DBI error disappears, kernel starts, but screen
   stays black-with-backlight (display not initialized; kernel alive). Two consecutive
   boots identical.
7. **Experiment 4 (Android kernel + GUF296 dtb + qcomfdtmem) — STILL DBI** → qcomfdtmem
   definitively ruled out too. The trigger is ONLY the kernel Image itself (GUF296-built
   vs stock Android GKI).
8. **Debug-cmdline round (`console=tty0 panic=10 panic_on_oops=1 oops=panic`)** on the
   Experiment-3 route: black screen WITHOUT backlight + reboot into Ubuntu ~10 s later
   = the GUF296 (ubuntu, non-GKI) kernel PANICS running the Android rootfs (panic=10
   fired). **No new rawdump was written** — GRUB/linuxdirect-launched kernel panics do
   NOT produce a minidump (minidump setup is ABL-side), unlike ABL-launched panics.
   tty0 also produced no on-panel text (display never initialized before the panic).
   Open question resolved in the negative direction: a GUF296 ubuntu kernel does NOT
   get far running Android's rootfs, so "boot Android with the ubuntu kernel" is a dead
   end; and packaging the stock Android kernel in GUF296's segment format stays blocked
   (segment layout never reverse-engineered; GUF296 toolchain/source not public).

Config as of session end: dual menu (Ubuntu default + Android entries incl. the
initrddirect variants) staged in vm-bootsys_a — every Android entry currently parked;
the device boots Ubuntu normally. **Next step if Plan B resumes**: the ONLY untested
direction left is packaging the stock Android kernel Image in GUF296's appended-segment
format — requires reverse-engineering the segment layout (dtb@28,847,552 /
bootconfig@34,247,372 were FALSE positives — they are kernel .text/.data content, and
the ARM64 Image header @56, PE sections, and tail are byte-identical between the two
kernels; the DBI data's real location was never found) or obtaining GUF296's linuxdirect
source/toolchain. Higher-value: return to the ABL route — a-slot (stock ROW stack +
geometry-fixed super) last failed as a fastboot loop with NO rawdump read afterward;
a fresh `edl.py r rawdump` after that failure was never taken and would show whether
liblp passed (kernel-stage init issue) or failed.

## Why it works
On the GUF296-scheme chain the ABL only loads the custom UEFI env from the boot slot
(boot_b); GRUB then fully owns the machine (Ubuntu already boots this way). Booting the
ANDROID kernel from GRUB means the Lenovo ABL never inspects it → its rollback/hash/
version/"系统与固件不兼容" gates are all bypassed. Android does not care WHO loaded its
kernel as long as kernel + initrd + dtb + cmdline are right.

## Component extraction (from a complete ROW zip, unpack_bootimg.py)
- kernel: `boot.img` → unpack → `kernel` (35,289,600 B ARM64 Image; v4 boot has NO ramdisk)
- initrd: `init_boot.img` → unpack → `ramdisk` (2,099,608 B, LZ4 frame `02 21 4c 18`;
  keep as-is — kernel decompresses LZ4 initrd natively)
- dtb: `vendor_boot.img` → unpack → `dtb` (5,362,106 B = 11 concatenated dtbs,
  msm-ids 0x266/0x278/0x283/0x282/0x22d×2/0x241×2/0x27c/0x280/0x281, board-id all 0;
  models = Cliffs family + Pineapple family + Volcano family). **Pick by MODEL, not by
  first-entry**: SM8650P = "PineappleP" (msm-id 0x241 0x10000, dtb#7); confirm the family
  from the old ABL-booted rawdump kernel log (`qnoc-pineapple`). Split the concatenated
  dtbs with a magic scan (`d0 0d fe ed` totalsize walk), then `dtc -I dtb -O dts` each
  and grep `model =`.
- vendor ramdisk: NOT needed in initrd — Android init reads vendor_boot partition itself
  for second-stage ramdisk. Only init_boot ramdisk goes to GRUB.

## GRUB config (vm-bootsys_a `EFI/BOOT/qcomramp.cfg`, dual menu)
- **initrd MUST use the `initrddirect` command** (linuxdirect's sibling — standard `initrd`
  errors `you need to load the kernel first`; an `initrd`/`--initrd` keyword inside the
  linuxdirect args line either crashes (`synchronous error, recursive exception`) or is
  passed through as cmdline). Two lines:
  ```
  linuxdirect /android/Image ${acmd}
  initrddirect /android/initrd
  ```
- Keep `search --no-floppy --file /android/Image --set=root` + `devicetree`.
- **DO NOT add `qcomfdtmem source rampartition` to the Android entry** — the stock cliffs
  QRD dtb has no GUF296 rampartition node → `DBI dump table info not found` and boot stops.
- `set timeout=15; set default=0` — Ubuntu stays default, Android is a manual pick (safe).
- Long Android cmdline: store in a variable (`set acmd="..."`) to keep the menuentry short.

## Android cmdline assembly (source of truth = rawdump kernel log)
Start from the FULL cmdline the ABL actually passed (rawdump `Kernel command line:` line),
then:
- drop `console=ttynull` (silent) → `console=ttyMSM0,115200n8` (harmless; no UART wired)
- drop `bootconfig` flag — GRUB cannot place bootconfig data; instead append the
  bootconfig file's lines as plain args (`androidboot.hardware=qcom
  androidboot.memcg=1 androidboot.usbcontroller=a600000.dwc3
  androidboot.load_modules_parallel=true androidboot.hypervisor.protected_vm.supported=true
  androidboot.console=0`)
- add `androidboot.slot_suffix=_a androidboot.verifiedbootstate=orange` (ABL would have;
  GRUB doesn't)
- keep everything else verbatim (kvm-arm.mode=protected, fw_devlink, firmware_class.path,
  video=vfb:640x400, etc.)

## Flash & test
- Stage files into a copy of `EDL/backup/lun4/vm-bootsys_a.bin` with mtools
  (`mmd ::/android` + `mcopy`), replace `::/EFI/BOOT/qcomramp.cfg`, then either
  `edl.py w vm-bootsys_a <img> --lun=4` OR — verified — plain
  `fastboot flash vm-bootsys_a <img>` (physical partition on LUN 4, ~14 s, no EDL needed).
- Reboot on slot b → GRUB menu → pick Android. Diagnostics if it fails: rawdump
  (kernel dmesg — check it got past liblp/init this time), logfs ring buffer.

## Open questions → answered (session end)
- dtb#7 + initrddirect + no qcomfdtmem → **still DBI** (dtb ruled out).
- qcomfdtmem + GUF296 dtb + Android kernel → **still DBI** (qcomfdtmem ruled out).
- Does the GUF296 ubuntu kernel run Android rootfs? → **No** — panics ~10 s
  (black, no backlight; panic=10 reboot; no rawdump — GRUB-launched panics write no
  minidump). Distinguish stale-vs-new rawdump by `console=` in its kernel cmdline
  (ttynull=ABL boot, ttyMSM0/tty0=GRUB boot); a GRUB-boot failure may leave NO new dump.
- Can we patch linuxdirect? → **No public source**: `GUF296/grub2` GitHub repo is stock
  GRUB (no linuxdirect); CI pulls a prebuilt `GRUB_BUILD_ARCHIVE`/`QCOMRAMP_EFI_URL`.
  Rebuilding means obtaining GUF296's private toolchain.
- Memory-reservation interplay (rampartition vs Android dtb reserved-memory): never
  reached — kernel never booted with the stock Android Image (DBI blocks before load).
