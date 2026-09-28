# Safe stock-firmware reset of the Android side (protects dual-boot GPT)

Context: TB321FU dual-boot (b-slot Ubuntu on a custom LUN0 GPT tail: ubuntu 96G +
grubfat 1G entries live at the END of the LUN0 GPT). Goal: wipe/reset the Android
side back to stock PRC ZUI WITHOUT touching LUN0's GPT — because flashing
`gpt_main0.bin` erases the ubuntu/grubfat partition entries and bricks the Linux side.

## Core insight: which rawprogramN is safe?

Every Lenovo `rawprogramN.xml` carries PrimaryGPT + BackupGPT entries for its OWN
physical LUN (`physical_partition_number="N"`):

| XML | LUN | GPT file | Danger to dual-boot |
|---|---|---|---|
| rawprogram0 (+_unsparse0, +_save_persist*) | 0 | `gpt_main0.bin` | ⛔ **ERASES ubuntu/grubfat entries** (LUN0 GPT tail) — never flash |
| rawprogram1/2/3/5 | 1/2/3/5 | gpt_mainN.bin | no ubuntu entries there, but also no benefit — skip |
| **rawprogram4** | **4** | `gpt_main4.bin` | ✅ **SAFE** — LUN4 is the A/B bootloader+system LUN (uefi/abl/tz/.../boot/vendor_boot/recovery), no custom partitions |

**rawprogram4 is the "reset Android side" package.** It covers every partition in
the ABL bootability check chain (lenovoraw is LUN0, but recovery_a/init_boot_a/
pvmfw_a/boot_a are all LUN4) plus abl/uefi/tz/hyp/modem/etc.

Bonus protections inside rawprogram4 itself (verified 2026-08-08):
- `vm-bootsys_a` (the Ubuntu boot FAT, 537 MB Y700BOOT, LUN4) has `filename=""`
  → flasher skips it. **The Linux boot chain survives the Android reset.**
- ALL `_b`-slot entries have `filename=""` → skipped. boot_b (GUF296 UEFI
  firmware) is untouched.
- GPT entries are only `gpt_main4.bin`/`gpt_backup4.bin` (no ubuntu).

## Recipe (all local assets, zero downloads)

Precondition: MOD package assets already extracted (`02-MOD包资产/`:
`vendor_boot_prc.img`, `vbmeta.img` = AOSP testkey) + full stock image set
(`row/full/` from the official ROW 17.5.10.031 zip).

1. Build a mixed image dir from the stock set, then OVERWRITE the two files that
   must be the MOD versions (region lock + prevent flash + testkey trust):
   ```
   mkdir safe_image
   cp row/full/{uefi.elf,aop.mbn,...,boot.img,recovery.img,init_boot.img,dtbo.img,pvmfw.img,...} safe_image/
   cp row/full/gpt_main4.bin row/full/gpt_backup4.bin safe_image/
   cp 02-MOD包资产/vendor_boot_prc.img safe_image/vendor_boot.img   # ROW→PRC, passes prevent flash
   cp 02-MOD包资产/vbmeta.img safe_image/vbmeta.img                 # AOSP testkey (sha1 2597c218), ABL trusts
   ```
2. Copy `rawprogram4.xml` + `patch4.xml` → `rawprogram4_safe.xml` / `patch4_safe.xml`
   (no edits needed — already LUN4-only; the mixed dir supplies the right files).
3. Safety-verify the XML before flashing (see script pattern below): every entry
   PPN=4; GPT filenames only gpt_main4/gpt_backup4; `vm-bootsys_a` filename empty.
4. Flash via EDL:
   ```
   python edl/edl.py --loader=EDL/xbl_s_devprg_ns_row17510031.melf \
     qfil safe_image/rawprogram4_safe.xml safe_image/patch4_safe.xml safe_image/
   python edl/edl.py --loader=... w super 03-自制刷机方案/super_build/super_pad3.img
   ```
   super_pad3.img = stock `super_1..8` concatenated + zero-padded to exact GPT size
   (13,958,643,712 B) — same source as row/full/super_1 (first 64 KB byte-match
   verified). Contains stock ZUI system/vendor → boots after the reset.
5. Readback-verify EVERY partition after qfil — see "Execution-phase traps" below.
6. `fastboot set_active a && fastboot reboot`.

## Execution-phase traps (2026-08-08 live run)

**qfil silently writes only PART of the rawprogram.** `edl.py qfil ...` exited 0
with no error, but readback showed ~17/30 partitions actually written: the early
A-slot + boot-chain set (uefi/aop_config/hyp/bluetooth/dsp/qupfw/imagefv/cpucp/
xbl_ramdump/cpucp_dtb/spuservice/boot/vendor_boot/recovery/init_boot/vbmeta/dtbo)
landed; tz_a, modem_a, abl_a, aop_a, keymaster_a, devcfg_a, uefisecapp_a, shrm_a,
featenabler_a, storsec were NOT touched. There is no per-partition completion
log — the progress bar just moves; exit code is meaningless here. **Plan for
qfil + individual re-flash of every missed partition, verified by readback.**

**Leftover-content trap:** pvmfw_a and abl_a read back IDENTICAL to the 8/6 EDL
backup (ZUXOS 1.1.10.338-era content) — the reset did not touch them, leaving a
mixed-version bootloader chain. Check content (strings / avbtool), not just
"non-empty".

**Readback hash compare = local FILE size, not partition size.** `edl.py r <part>`
dumps the whole padded partition (vbmeta_a = 64K readback vs 8K file; pvmfw_a 1M).
Whole-partition sha256 never matches the file. Compare:
```
head -c $(stat -c%s local.img) readback.img | sha256sum
head -c $(stat -c%s local.img) local.img | sha256sum
```
A "mismatch" on vbmeta_a/pvmfw_a is often a false alarm from the padded tail —
check magic + `avbtool info_image` public-key sha1 first (e.g. vbmeta_a readback
showing AVB0 + pubkey 2597c218 = correct MOD testkey version despite differing
whole-file hash). boot_a (96M file == 96M partition) compares clean whole-file.

**EDL wedge mid-batch:** after a successful write the next `w` can fail with
`Connection detected, quiting.` (Sahara mode=error). **Physical replug does NOT
recover it (2026-08-08): the device-side USB controller is wedged too — lsusb
goes EMPTY. Power-cycle back into EDL** (off → hold Vol+ → plug long-side port),
verify the last write, continue remaining partitions one at a time.

**Idempotent marker script (the practical re-flash pattern, 2026-08-08):** with
per-write wedging, a plain loop dies after one partition. Keep a marker dir and
make the script resumable — replug, rerun, it skips everything already written:

```bash
MARK="safe_image/.flashed"; mkdir -p "$MARK"
for spec in "devcfg_a:devcfg.mbn" "uefisecapp_a:uefi_sec.mbn" "shrm_a:shrm.elf" \
            "featenabler_a:featenabler.mbn" "storsec:storsec.mbn" "abl_a:abl.elf"; do
  p="${spec%%:*}"; f="${spec##*:}"
  [ -f "$MARK/$p" ] && { echo "skip $p"; continue; }
  out=$(timeout 120 ./venv-edl/bin/python edl/edl.py $L --maxpayload=0x20000 w "$p" "safe_image/$f" 2>&1 | tail -1)
  if echo "$out" | grep -q Wrote; then touch "$MARK/$p"; echo "OK $p";
  else echo "WEDGE at $p — replug USB, rerun script"; exit 1; fi
done
```
Each run writes 1-2 partitions before wedging; the marker dir makes N replugs
into "rerun after each replug" with zero bookkeeping. (Readback verification
loops hit the same wedge — batch ~5 reads per replug, not 28.)

**`--maxpayload` needs an edl.py docopt patch:** qfil/w/r reject
`--maxpayload=0x20000` with a usage dump (docopt strict — the option is only on
the global usage line). Add `[--maxpayload=bytes]` to the qfil/w/r usage lines in
the LOCAL `edl/edl.py`; verify with a docopt-parse test before touching hardware.
0x20000 (128K) vs default 1M reduces per-packet load; the device `<configure>`
response can override MaxPayloadSizeToTargetInBytes anyway.

## vbmeta_system: use the ROW original, NOT the MOD one

`rawprogram4` does NOT touch vbmeta_system (it lives on LUN0 — another reason it's
safe). If you also flash vbmeta_system separately, choose carefully (avbtool output):
- MOD `vbmeta_system.img`: rollback index **1754352000** — LOWER than the device's
  committed rpmb value → `Image rollback index is less than the stored rollback index`.
- ROW `row/full/vbmeta_system.img`: rollback **1759622400** — matches/surpasses rpmb. ✓

## Signed-vbmeta parsing (avbtool, not hand offsets)

For SIGNED vbmeta (alg=2 SHA256_RSA4096, auth block 576 B): `rollback_index` is an
8-byte field @60, `flags` 4B @68, `rollback_index_location` @72 — NOT the
@120/@124 offsets used by the hand-rolled NONE-algorithm disable generator. Don't
hand-parse signed vbmeta; use `avbtool.py info_image --image X` (field names:
Rollback Index / Flags / Rollback Index Location, plus descriptor list). The MOD
main vbmeta has aux=0 (no hash/chain descriptors) — trust chain comes from the
per-partition testkey AVB footers.

## Script pattern (safety assertions)

```python
import re
d = open('rawprogram4.xml').read()
assert set(re.findall(r'physical_partition_number="(\d+)"', d)) == {'4'}
for m in re.finditer(r'<program [^>]*>', d):
    tag = m.group(0)
    if 'PrimaryGPT' in tag or 'BackupGPT' in tag:
        assert re.search(r'filename="([^"]*)"', tag).group(1) in ('gpt_main4.bin','gpt_backup4.bin')
    if re.search(r'label="([^"]*)"', tag).group(1) == 'vm-bootsys_a':
        assert re.search(r'filename="([^"]*)"', tag).group(1) == ''
```
