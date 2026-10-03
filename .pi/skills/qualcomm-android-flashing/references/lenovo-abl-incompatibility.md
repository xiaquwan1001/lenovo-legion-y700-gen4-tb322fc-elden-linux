# Lenovo ABL "系统与固件不兼容" (system incompatible with firmware) — TB321FU

Device: Lenovo Legion Y700 Gen3 / TB321FU (SM8650 "cliffs"), BL unlocked, current ABL =
`TB321FU_CN_OPEN_USER_Q00002.0_W_DF_1.5.10.038` (CN ZUXOS, "DF" build) — read from
`fastboot getvar build.display.id` (ALWAYS check this; the local ROM zip may be ROW while
the device ABL is CN, and the two behave differently).

## Symptom
After flashing a Pixel GSI's standard boot.img set (boot_a, init_boot_a, vendor_boot_a,
dtbo_a, vbmeta_a, vbmeta_system_a) into a rebuilt super (GSI in the `system` LP slot) and
`fastboot set_active a`, the tablet shows:

> 当前系统与固件不兼容，系统会自动关机 (The current system is not compatible with the
> firmware; the device will shut down automatically)

...then powers off. Each failed attempt decrements slot retry → after 7, `slot-unbootable:a:yes`,
"启动次数用尽", device only enters fastboot. Reset with `fastboot set_active a` (clears
unbootable, retry back to 7).

## Ruled out (all validated negative results — do not re-test)
1. **AVB / vbmeta** — the inoki ABL series (blog.inoki.cc ABL(3), 2024-04-20) shows
   `LoadImageAndAuth` only verifies when the bootloader is LOCKED. Unlocked → `LoadImageNoAuth`.
   Confirmed empirically: custom `avbtool`-style disable-verification vbmeta
   (AVB0 magic, algorithm NONE, flags=2 @ offset 0x78) flashed to vbmeta_a + vbmeta_system_a
   changed nothing. Also `os_version` field is 0x0 on BOTH the working GUF296 boot.img and the
   failing GSI boot.img (offset 0x24), so it is not an os-version gate.
2. **DTB board-id / msm-id** — unpacked the GSI vendor_boot.img (unpack_bootimg.py) and the
   OEM vendor_boot_a (EDL backup): both carry the SAME 11-dtb blob (5,362,106 bytes),
   generic "Qualcomm Technologies, Inc. Cliffs SoC" dtbs, `qcom,msm-id` 0x266/0x278/0x283/
   0x282/0x22d/0x241/0x27c/0x280/0x281 (x 0x10000/0x20000), `qcom,board-id = <0x00 0x00>`
   on every one. A dedicated TB321FU dtb (grub_extract/`sm8650-lenovo-tb321fu.dtb`) carries
   NO board-id property at all. Same dtb set boots OEM Android, so board-id is not the gate.
3. **init_boot / ramdisk format** — OEM and GSI init_boot are both v4, kernel 0, ramdisk
   ~2-2.5 MB. Not the discriminator.
4. **vbmeta "empty" theory** — OEM vbmeta_a is a real AVB image (SHA256_RSA2048, flags=0,
   "avbtool 1.3.0" public-key metadata); irrelevant since unlocked skips verification anyway.

## What DOES boot (the bypass)
GUF296's boot.img "kernel" segment is NOT a Linux kernel: gzip→7z extracts a complete
Qualcomm UEFI firmware environment (EDK2 DXE: BdsDxe, DxeCore, LinuxLoader.efi (= ABL
variant), RamPartitionDxe, Fat.efi, UFSDxe...), ARM64 Image magic 0x10000381. ABL loads it
as a UEFI application, which never enters the "Android kernel" compatibility check → Ubuntu
boots fine. So: **standard-Linux-kernel boot.img = gated by the Lenovo check; UEFI-firmware
boot.img = bypass.**

## Corroboration
Reddit r/androidtablets: Lenovo Tab P11 Pro Gen2 (TB132FU) shows the same message after
flashing a mismatched system; "刷回出厂版本系统后可以正常工作" (restore factory system →
works). Confirms a Lenovo custom-ABL system/ROM gate, not a Qualcomm-stock behavior.

## Root cause found — the GSI project's OWN flash procedure (2026-08-07)
The GSI came from **CharlesGool/TB321FU_PixelOS_16_Komodo** (Mystic-GSI base, Pixel 9 Pro XL
"Komodo" GSI adapted for TB321FU). Its README states:
- "已签名；可直接启动，无需关闭 vbmeta 验证" — the GSI is already signed (AOSP test key),
  no vbmeta disabling needed.
- Flash procedure: **1) flash the latest OFFICIAL system, 2) reboot to fastbootd,
  3) flash like a normal GSI: `fastboot flash system <Pixel-komodo-16_ext4_raw_Signed_V5.img>`**.

So the intended setup is **STOCK boot stack (boot/vendor_boot/init_boot/dtbo/vbmeta/vbmeta_system
all OEM) + GSI in system only**. The session's failure was caused by flashing the GSI
project's OWN boot.img/vendor_boot.img/init_boot.img/dtbo.img into the A slot — those
self-made standard-Linux-kernel images are exactly what the Lenovo ABL gate rejects.
The OEM kernel's boot.img passes the check (it is the factory system), and the OEM kernel
is fully capable of booting the GSI system (stock kernel + GSI = standard GSI practice).

## Fix applied at end of session (boot test pending)
- Extracted stock `image/boot.img` (100,663,296 B, v4) + `image/abl.elf` from the ROW
  17.5.10.031 zip using the local-header scan recipe (see
  `firmware-zip-partial-extract.md`) — the 7 GB zip download was incomplete/holey, only the
  needed entries were pulled.
- Re-flashed A slot: `boot_a` = stock ROW boot.img, `vendor_boot_a`/`init_boot_a`/`dtbo_a`/
  `vbmeta_a`/`vbmeta_system_a` = stock images from the EDL backup
  (`EDL/backup/lun4/*.bin`, `EDL/backup/lun0/vbmeta_system_a.bin`) — the backup's A slot was
  the pre-GUF296 OEM state (hashes differ from the GSI package's images).
- super kept the GSI-in-system rebuild. `set_active a` + reboot = the test.
- **ABL swap (below) is now the FALLBACK**, only if stock-boot-stack + GSI still trips the
  gate.

## Fallback direction (was "open", now demoted — DO NOT jump to it first)
Swap ABL to ROW ZUI 17.5.10.031 (`abl.elf` from the ROW zip) — ROW ABL trusts AOSP test
keys within ≤17.5.10.170.
- Flash BOTH `fastboot flash abl_a abl.elf` + `abl_b` (A/B).
- ALWAYS back up current abl_a/b first (EDL `rl` — already at `EDL/backup/lun4/abl_*.bin`).
- abl hosts the fastboot server: a bad abl flash costs fastboot (EDL 9008 remains reachable
  via the engineering loader, so it is recoverable).
- Risk: ROW ABL must still accept the GUF296 UEFI boot.img (Ubuntu side). Verify by
  `set_active b` + reboot AFTER the swap; rollback = flash the CN abl backup.

## Tooling notes (all worked)
- `unpack_bootimg.py` / `mkbootimg.py`: LineageOS `android_system_tools_mkbootimg`
  branch `lineage-22.2` (gh-proxy raw URL — aosp-mirror/LineageOS `platform_external_avb`
  avbtool raw URLs 404; avbtool was NOT needed, see vbmeta note in qualcomm-edl-flashing).
- DTB analysis: `apt-get download device-tree-compiler` → `dpkg -x` → `dtc -I dtb -O dts`
  (no root). Vendor_boot dtb blob = concatenated dtbs; split on `\xd0\x0d\xfe\xed` magic.
- GSI raw image: `Pixel-komodo-16_ext4_raw_Signed_V5.img` = ext4, volume name "Pixel",
  3.5 GB, no AVB footer on the paired boot.img ("boot.img signature size: 0").
  [已归档 2026-08-10 → `~/下载/刷机-保留/archive/pixel.tar.zst`]
