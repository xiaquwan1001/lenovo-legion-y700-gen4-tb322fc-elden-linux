# KernelSU LKM + CN ZUI/ZUXOS single-system flash prep (TB321FU, 2026-08-10)

Session: user dropped the task difficulty to a SINGLE system (CN Lenovo OS + KernelSU; no dual-boot, no EDL gymnastics). All offline prep completed and verified; **flash EXECUTED 2026-08-10 evening and hit the qfil silent partial-write trap — see §6 for the actual outcome + logfs diagnostic + fix** (user confirmed Pixel GSI + Kubuntu wipe is acceptable — the dual-boot path is fully documented elsewhere).

## 0. Package verification (two same-name downloads!)
- `TB321FU_CN_OPEN_USER_Q00011.0_V_ZUI_17.0.10.138_ST_250626.7z` AND `... (1).7z` — same size (6,107,012,514 B), same first-1MB sha256, but **tails differ**: the non-(1) copy ends in 12 zero bytes → preallocated-but-incomplete download; `7z l` on it → `Headers Error` / `Cannot open the file as [7z] archive`. The `(1)` copy lists fine (Type=7z, Method=LZMA2:25 BCJ, 3 blocks, 202 files, 9.4GB uncompressed).
- Lesson: for a large firmware zip that won't open, compare `tail -c 12` across duplicate downloads before assuming corruption — a zero tail = truncated download, not a bad archive. Extract with `7z x -o<dir>`.

## 1. Package contents (CN, inner dir `TB321FU_ZUX_1.1.10.138/`)
- image/: boot.img (100MB), init_boot.img (8MB, v4 ramdisk-only), vendor_boot.img (100MB), dtbo.img (25MB), recovery.img (100MB), lenovoraw.img, pvmfw.img, vbmeta.img (8KB), vbmeta_system.img (4KB), super_1..7.img (7.3GB total), xbl_s_devprg_ns.melf (1.5MB), vmlinux (343MB kernel ELF), rawprogram0-5.xml + patch0-5.xml (PLAINTEXT), gpt_main/backup/both/emptyN.bin, `运行我，刷机.bat` + tool/ (Windows QFIL, unused on Linux)
- Kernel (from `strings vmlinux | grep '^Linux version'`): `6.1.84-android14-11-maybe-dirty` → **KMI = android14-6.1.84**
- AVB inventory (avbtool info_image):
  - vbmeta.img: AOSP testkey (sha1 2597c218), rollback=0, flags=0; chain boot(recovery)→testkey, vbmeta_system→OEM (cdbb7717); **NO hash descriptors for init_boot/vendor_boot/dtbo** → init_boot is NOT AVB-checked (good for KSU patch)
  - vbmeta_system.img: OEM key, rollback=1746403200
  - boot.img: own testkey footer, rollback=**1746403200**
  - init_boot/vendor_boot/dtbo: NO footer (Algorithm NONE)
- Fingerprint prop: `ZUXOS_1.1.10.138_250626_PRC` = native PRC (no region conversion needed)

## 2. Anti-rollback analysis (the one real gate)
- rpmb stored rollback ≈ **1759622400** (ROW 17.5.10.031 boot.img rollback, flashed 8/10 and booted).
- Target CN boot rollback 1746403200 < 1759622400 → guaranteed ABL reject without intervention.
- Fix applied: replaced image/vbmeta.img + vbmeta_system.img with disable images from `mkvbmeta_disable.py` (AVB0, alg NONE, flags=2), then **padded each 4KB file to 64KB** (16 sectors × 4096) with `dd` to match the rawprogram partition size — qfil writes whole partitions.

## 3. XML edits (in image/ dir, via python ElementTree)
1. rawprogram0.xml: REMOVED the `super` entry (sparse=true referencing super.img which doesn't exist as a single file) — plan is `edl.py w super super_pad.img` separately.
2. rawprogram4.xml: `vm-bootsys_a` + `vm-persist` → `filename=""` (files absent from package; skipping write is harmless without dual-boot).
3. rawprogram4.xml: `init_boot_a` filename → `init_boot_ksu.img` (one-shot KSU boot — no second flash needed).
4. boot_a/vendor_boot_a/dtbo_a left stock (never touch — ABL/prevent-flash safe).
- Note: rawprogram0 also carries gpt_main0.bin (GPT rebuild → Pixel/Kubuntu partition entries erased = the intended single-system outcome). patch0.xml fixes up userdata size to end-of-disk.

## 4. super build
- `cat super_1.img super_2.img ... super_7.img > super_full.img` = 7,837,732,864 B
- pad: `dd if=/dev/zero of=super_pad.img bs=4096 count=3407872` then `dd if=super_full.img of=super_pad.img conv=notrunc` → **13,958,643,712 B** (matches rawprogram0 super num_partition_sectors=3407872)
- super is a PHYSICAL partition on LUN0.

## 5. KernelSU-Next v3.3.0 assets (saved to 05-工具链/KernelSU-Next/)
Release page: github.com/KernelSU-Next/KernelSU-Next/releases/tag/v3.3.0
- `android14-6.1_kernelsu.ko` (aarch64 ELF relocatable, 421KB) — the LKM module for KMI android14-6.1.x
- `KernelSU_Next_v3.3.0_33214-release.apk` (10MB) — Manager app
- `ksud-x86_64-unknown-linux-musl` (static PIE) — PC-side patcher
- Patch command (worked first try after fixing the -o dup):
  `./ksud-linux-x86_64 boot-patch -b <image>/init_boot.img -m ./android14-6.1_kernelsu.ko --kmi android14-6.1.84 -o <outdir> --out-name init_boot_ksu.img`
  - Output: 8MB Android bootimg, ANDROID! magic + v4 header preserved, ramdisk 2,099,419 → 2,496,803 B.
  - Pitfall: `-o` once only. `strings` on the image will NOT show ksud (ramdisk is compressed) — trust the ramdisk size delta + "Adding KernelSU LKM... Done!" output.

## 6. Flash execution — ACTUAL OUTCOME 2026-08-10 (qfil partial-write trap)
1-6. `edl.py qfil rawprogramN.xml patchN.xml image/` for N=0..5 (each LUN one qfil call) — **all exited 0**, super 100% (35 MB/s, ~14 min total incl. super).
7. `edl.py w super super_pad.img` — OK ("Wrote ... to sector 90504").
8. readback-verify phase FAILED with `Mode detected: error / Connection detected, quiting.` — EDL session wedged AFTER the writes (known benign pattern; the writes had landed, but verification was skipped — see §6a for the consequence).
9. fastboot: `erase userdata` OK (0.5s), `set_active a` OK, reboot → **stuck at Lenovo logo, twice**.

### 6a. Diagnostic: logfs triple-error = qfil silently SKIPPED the small partitions
`edl.py r logfs` + strings showed:
```
ERROR: boot_a: Image rollback index is less than the stored rollback index.
ERROR: dtbo_a: Hash of data does not match digest in descriptor.
ERROR: vendor_boot_a: Hash of data does not match digest in descriptor.
run into prevent flash verify!!!
Start EBS
```
**KEY INTERPRETATION**: boot/dtbo/vendor_boot errors mean those partitions DID get new content (checks run and fail), while **vbmeta_a / vbmeta_system_a / init_boot_a were silently NOT written** — they still held the PREVIOUS flash's content (8/10 MOD vbmeta / old ROW init_boot). The disable-vbmeta you prepped is exactly the small partition qfil tends to skip → the whole AVB chain still runs and dies at rollback+hash. Confirm by readback:
- `edl.py r vbmeta_a` → avbtool showed Algorithm SHA256_RSA4096 + pubkey 2597c218 (old MOD testkey), NOT the expected NONE/flags=2 disable image.
- `edl.py r vbmeta_system_a` → OEM cdbb7717 signed (old).
- `edl.py r init_boot_a` → hash 753bb5… ≠ KSU patched (bdd0406…) ≠ stock (c1ee918…); logfs had NO init_boot error = it was untouched (stale).
**Fix**: `edl.py w` single-partition rewrites (reliable for ≤8MB): `w vbmeta_a image/vbmeta.img`, `w vbmeta_system_a image/vbmeta_system.img` (both OK), then `w init_boot_a image/init_boot_ksu.img` → **hit USB Overflow mid-write (8MB!)** → power-cycle back into EDL and retry the same command (idempotent). Session ended awaiting this retry — boot test pending. Full lesson cross-ref: qualcomm-edl-flashing SKILL.md pitfall "qfil partial-write REPEATED on full 6-LUN CN flash (2026-08-10)".
