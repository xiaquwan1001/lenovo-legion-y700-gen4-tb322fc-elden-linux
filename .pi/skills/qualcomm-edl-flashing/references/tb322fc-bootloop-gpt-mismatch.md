# TB322FC (Y700 Gen4) bootloop forensics — GPT layout mismatch 120 vs 073 (2026-08-16)

Full diagnostic chain for: after flashing the complete 073 super + 073 boot chain, device
stuck at Lenovo logo, USB never enumerates, logfs shows EBS every boot. Root cause was
NOT partition content — it was a **GPT layout mismatch between firmware versions**.

## Symptom
- Device stuck at logo; `lsusb` shows nothing (no 17ef/adb, no 05c6 unless forced to EDL).
- `edl.py r logfs` → every POR segment ends the same way.

## logfs signature (parse POR segments split on `Log Type: B - Since Boot`, last = newest)
```
[2578]Booting from slot (_a)
[2578]Booting Into Mission Mode
[2579]Loading Image boot_a Done : 0 ms, Image size : 4096 Bytes     ← suspicious but NOT the cause
[2908]VB2: Authenticate complete! boot state is: orange            ← AVB PASSES
[2916]Loaded Partition: boot / pvmfw
[3726]ERROR: Failed to set keys detection Timer: Invalid Parameter
[3732]BootLinux: factory_build = 1                                 ← factory path
[3732]Failed to add memory space :0x8088F000 0x1000
[3733]DP DTB: No Valid DTB in image
[3740]Override DTB: GetBlkIOHandles failed loading user_dtbo!
[3995]Shutting Down UEFI Boot Services: 3995 ms
Start EBS        [ 3995]                                           ← ABL failure → stuck logo
```
Every image reports `Image size : 4096 Bytes` (dpm = 8192) — recovery/init_boot/pvmfw/boot
ALL of them — yet readback shows full partitions. "4096 Bytes" is a red herring for content
corruption; it's the ABL reading the WRONG GPT map.

## Verification steps (all passed except the GPT compare)
1. Read back ALL 8 boot-chain partitions, hash vs 073 package:
   `edl.py r boot_a|init_boot_a|vendor_boot_a|dtbo_a|recovery_a|vbmeta_a|vbmeta_system_a|pvmfw_a`
   → byte-identical. Content is fine.
2. HWID/region correct in logfs: `SM8750P_16+512_13`, `config = PRC`.
3. Cleared `misc` (held leftover `recovery --wipe_data --reason=MasterClearConfirm` from the
   unlock, never consumed) — backup first, write 1 MiB zeros. Did NOT fix EBS.
4. **The compare that matters**: device GPT vs package GPT per LUN.
   `edl.py rs 0 6 --lun=0|4 /tmp/lunN_gpt.bin` vs `image/gpt_main0.bin|gpt_main4.bin`.
   TB322FC: 120-era device GPT differed from 073 package in type GUIDs AND partition sizes
   (e.g. LUN4 first partition ending_lba 0xFFFFF/1GiB on 120 vs 0x67D18/415MiB on 073;
   LUN0: 11 differing 512B sectors incl. entry 24 GUID + entry 71 attributes). The 073 ABL
   resolves partition offsets from the wrong map → reads garbage → EBS.

## Why writing the package GPT alone is NOT enough
Partition CONTENT was written under the OLD layout (edl.py w <part> resolves offsets from
the then-current GPT). Once the new GPT activates, the content sits at the wrong offsets.
A full-package flash is required so every partition lands at its new-layout offset —
**LTBox "Flash Firmware" wizard** (user-operated GUI; device in fastboot NOT EDL — EDL
panics LTBox; keep PRC; enable Bypass Rollback Protection; select the 073 package dir).
BL-unlocked makes LTBox viable. (Session ended at this step — NOT yet verified booting.)

## Manual GPT write recipe (if needed)
- PrimaryGPT: `edl.py ws 0 gpt_mainN.bin --lun=N` (6 blocks)
- BackupGPT:  `edl.py ws <LUN_total_blocks-5> gpt_backupN.bin --lun=N` (5 blocks)
- Offsets per rawprogram XML: PrimaryGPT start_sector=0, 6 blocks; BackupGPT
  `NUM_DISK_SECTORS-5`, 5 blocks.
- Per-LUN total from GPT header last_usable (512B sectors): LUN0 61,390,875 ≈ 29.3GiB
  → backup @ block 7,673,854; LUN4 = 512MiB → backup @ 131,070.
- After GPT write the EDL session typically wedges (`Connection detected, quiting.` /
  USB Overflow) — the write may have landed; power-cycle back into EDL to verify.

## ⚠️ edl.py rs/ws LBA unit = 4096-byte blocks, NOT 512B sectors
`rs 723200 4096` lands at byte 723200×4096 (≈2.96GiB), not 723200×512 (370MiB) — readback
comes back 0xFF from an unrelated region, every hash "mismatches". Confirm by file size =
n × 4096. rawprogram XML agrees (SECTOR_SIZE_IN_BYTES="4096"). Compute LBAs with block
math (byte_offset // 4096). First sampling pass with 512B math produced all mismatches;
with block math all 5 super sample points matched source (HEAD LP-metadata region,
super_3|4 & super_4|5 stitch points, zero-fill start, partition tail).

## ⚠️ `edl.py gpt <dir>` dump can silently write NOTHING
Printed "Dumped ... to <dir>/gpt_mainN.bin" for all 6 LUNs but created zero files
(TB322FC 2026-08-16). Use `rs 0 6 --lun=N <outfile>` for per-LUN GPT reads instead.

## Related Gen4 facts (same evening)
- Gen4 073 super LP metadata @0PLA 12288 is NOT AOSP liblp v1.2 layout (flags=0x100;
  AOSP field offsets read garbage: tables_size@24=370885263, partitions@92=728,
  header_size@108=3; six 0PLA copies every 64KB). Do NOT hand-parse to learn system size —
  infer from super split sizes (super_4 ≈ 7.78GiB = system_a, plenty for a 3-4GiB GSI) and
  let fastbootd read the real metadata when flashing system.
- GSI source: Doze-off/lineage_treble release 2026-06-03 = LineageOS 23.2 A16 QPR2 Treble
  GSI UNOFFICIAL-signed; assets only via
  `api.github.com/repos/Doze-off/lineage_treble/releases/tags/2026-06-03` (HTML scrape
  shows nothing); VANILLA/MICROG/GAPPS variants; download via gh-proxy.com (≈3.8MB/s vs
  ~300-500KB/s local proxy; aria2 resumes across the URL switch via the .aria2 file).
