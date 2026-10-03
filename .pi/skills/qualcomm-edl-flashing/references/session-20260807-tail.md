# 2026-08-07 session tail — two new techniques

## Both-slots-drained fastboot loop (slot bookkeeping, not a flash failure)
After repeated failed boots the user sees only the bootloader menu ("卡在 bootloader").
logfs signature (`edl.py r logfs` — see rawdump-minidump-diagnostics.md §2):

```
Slot _a is unbootable, trying alternate slot
Err: line:1860 FindBootableSlot() status: Load Error
Err: line:2169 LoadImageAndAuth() status: Load Error
```
with NO `Booting from slot (_b)` line → **BOTH slots are drained**. b's retry exhausts
from repeated Ubuntu boots because the Linux rootfs never marks the slot boot-successful
(every boot costs one retry). Fix: `fastboot set_active <a-or-b>` resets that slot's retry
(verify `getvar slot-retry-count:<slot>`). Do NOT re-flash anything — check this signature
first when a previously-working slot "stops booting".

## vendor_boot v4 cmdline injection (get kernel text on screen for the NEXT boot)
Android kernel cmdline is composed by ABL from vendor_boot's command line (+ bootconfig +
ABL's own args). To add console/panic args without rebuilding the image: the v4
vendor_boot.img header keeps its command line as a NUL-terminated string starting at
offset 28 (0x1C) — binary-patch in place (find `video=vfb:...` and prepend):

```
console=tty0 panic=10 panic_on_oops=1 oops=panic video=vfb:640x400,bpp=32,memsize=3072000 nosoftlockup bootconfig
```

Re-flash vendor_boot_a, `fastboot set_active a`, reboot. Effects:
- `console=tty0` shows kernel text once fb/DRM initializes (early boot still silent —
  Android panels init late, so a very-early panic still shows black).
- `panic=10` forces reboot ~10 s after a panic → observable reboot cadence + a window to
  capture state; the watchdog-bite tail in rawdump also identifies panics
  (`gh-watchdog ... Causing a QCOM Apps Watchdog bite!`, `vWdog-expired status: 1`).

Caveat: ABL may append its own `console=ttynull` AFTER the vendor cmdline (kernel takes the
last console=), so screen output is not guaranteed — check the composed cmdline in rawdump's
`Kernel command line:` line after the attempt.
