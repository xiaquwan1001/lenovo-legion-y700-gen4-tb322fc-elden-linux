# CN ZUXOS 1.1.10.138 flash + KernelSU — EXECUTION outcome (2026-08-10)

Companion to `kernelsu-lkm-zui-cn.md` (the prep recipe). This file records what ACTUALLY
happened when executing that plan on TB321FU, and CORRECTS two claims from the prep doc.

## What worked / final state
- Device now runs **CN ZUXOS 1.1.10.138** (fingerprint `ZUXOS_1.1.10.138_250626_PRC`,
  `ro.build.version.incremental = TB321FU_CN_OPEN_USER_Q00011.0_V_ZUI_17.0.10.138_ST_250626`,
  Android 15 — the avbtool "os_version 14" prop was misleading). Single system; previous
  dual boot (Pixel GSI a / Kubuntu b) destroyed by design — GPT rebuilt to stock.
- Flashed with **LTBox v3.2.2 full-flash wizard** (GUI, user-operated). Steps the agent
  must hand the user (LTBox has NO CLI):
  1. `ltbox` → confirm EDL 9008 device shown
  2. Pick firmware source = a directory with the FULL original package (use a fresh
     `cp -al image ltbox-image` copy + re-extract original vbmeta/vbmeta_system/
     rawprogram0/rawprogram4.xml from the 7z — do NOT point it at an edited prep dir)
  3. Target region: **keep PRC** (package is already PRC; do NOT convert)
  4. **Enable "Bypass Rollback Protection"** — this is the load-bearing option
  5. Full flash (GPT + LUN0-5 + super), then `fastboot erase userdata` +
     `fastboot set_active a` + `fastboot reboot`
- **KernelSU**: patched stock init_boot with KernelSU-Next v3.3.0 —
  `ksud-x86_64-unknown-linux-musl boot-patch -b init_boot.img -m android14-6.1_kernelsu.ko --kmi android14-6.1.112 --out-name init_boot_ksu_v2.img -o <dir>`
  → `adb reboot edl` → `edl.py w init_boot_a init_boot_ksu_v2.img` → readback verify
  (sha256 matched) → `edl.py reset` (prints USB IO Error = device rebooting, NORMAL) →
  system boots with KSU. Manager APK install + root verification pending at session end.

## Corrections to the prep doc (empirically disproven during execution)

### 1. disable-vbmeta anti-rollback swap = DEAD END on CN ABL
Prep doc said: swap vbmeta_a/vbmeta_system_a for flags=2 disable images to skip
rollback+hash. **False on CN 1.1.10.138 ABL.** After flashing all 6 LUNs via qfil with
disable vbmeta, boot → Lenovo logo → EBS/fastboot loop. logfs showed:
```
ERROR: boot_a: Image rollback index is less than the stored rollback index.
ERROR: dtbo_a: Hash of data does not match digest in descriptor.
ERROR: vendor_boot_a: Hash of data does not match digest in descriptor.
run into prevent flash verify!!!
Start EBS
```
avb_slot_verify RAN despite alg=NONE vbmeta, and an unsigned vbmeta counts as a
"modified chain" → prevent flash. **Only LTBox's Bypass Rollback Protection (official
toolchain re-sign) passes.** Lesson: on TB321FU, a cross-line DOWNGRADE (newer rpmb
than target package) cannot be done with manual avbtool chains — use LTBox full flash.

### 2. KMI source: vmlinux strings are STALE
`strings vmlinux | grep '^Linux version'` → `6.1.84-android14-11`, but the actually
booted kernel (LTBox-flashed stock boot.img) is **`6.1.112-android14-11`** (from
`adb shell uname -r`). The package vmlinux is a symbol file, not the shipped kernel.
Use `adb shell uname -r` (or unpack the package's OWN boot.img) for the KMI.
(Observation: patching with `--kmi android14-6.1.84` vs `--kmi android14-6.1.112`
yielded byte-identical init_boot output — same sha256 — so the flag is advisory;
the ksu.ko carries its own KMI.)

## qfil partial-write RECURRED (2nd occurrence)
`edl.py qfil rawprogram0-5.xml` all exited 0, but readback proved
**vbmeta_a / vbmeta_system_a / init_boot_a were NOT written** (kept prior MOD content)
while boot/dtbo/vendor_boot WERE written (hashes matched originals). Symptom path:
first boot fails → logfs shows rollback/hash/prevent-flash errors → readback each
partition and hash-compare to find which didn't land → re-flash individually with
`edl.py w <part> <file>` (small partitions are reliable; 8MB init_boot_a wrote fine,
one USB Overflow mid-write recovered by power-cycle back into EDL).

## Pitfalls worth remembering
- `edl.py reset` prints a USB IO Error and the device vanishes from lsusb — that IS the
  reset working; just wait and re-check `adb devices` after boot.
- Fresh CN flash: adb empty until user enables Developer options + USB debugging +
  MTP/file-transfer USB mode (udev rules were already correct for 17ef).
- CN package rawprogram0.xml references `super.img` (absent) → remove the entry and
  `edl.py w super super_pad.img` (13,958,643,712 B); rawprogram4.xml references
  `vm-bootsys.img`/`vm-persist.img` (absent) → clear filename="" (skip).
- vbmeta_a / vbmeta_system_a are 64KB (16-sector) partitions — pad hand-built images.
- Two same-name 7z downloads differed in tail bytes; zero-filled tail = incomplete
  preallocated download (`7z l` → "Headers Error"); the `(1)` copy was the good one.
