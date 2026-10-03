# GPT surgery on Qualcomm UFS devices (verified on TB321FU)

Goal: shrink `userdata` and add partitions (e.g. `ubuntu` ext4 + `grubfat` FAT32) for dual-boot,
without touching `super` (Android dynamic partitions must stay intact).

## 1. Dump the original GPT
`edl.py rl <dir>` (full backup) saves per-LUN files: `<dir>/lun0/gpt_main0.bin` (primary GPT,
3×4096-byte sectors: MBR + header + entries) and `gpt_backup0.bin` (usually just the backup
ENTRIES sector). Also read the disk tail to learn the backup layout:
`edl.py rs <last_lba> 5 <file>` → inspect which sectors hold "EFI PART" (backup header) vs the
entry table. On TB321FU LUN0: primary at LBA0-2, backup entries at LBA 60884987, backup header
at LBA 60884991 (60884992 total sectors, 4096-byte sectors).

## 2. Parse (4096-byte sectors)
Header at offset 4096 in the dump (byte offset == LBA × 4096):
```
sig "EFI PART" @0 | rev @8 | hdr_size @12 | hdr_crc @16 | cur_lba @24 | backup_lba @32
| first_usable @40 | last_usable @48 | disk_guid @56 | part_entry_lba @72
| nents @80 | entsz @84 | entries_crc @88
```
Entry (128 B): type GUID (bytes_le) @0, unique GUID (bytes_le) @16, first_lba @32, last_lba @40,
flags @48, name UTF-16LE @56.

## 3. Modify
- Devices often use only 16 of 32 entry slots — append new partitions into FREE slots, no
  geometry change needed (nents/entries layout/CRCs stay in 1 sector).
- To shrink userdata: keep first_lba, set last_lba = first_lba + new_size_sectors − 1.
- New partitions: type GUID Linux-filesystem `0fc63daf-8483-4772-8e79-3d69d8477de4` (ext4 root)
  or EFI-System `c12a7328-f81f-11d2-ba4b-00a0c93ec93b` (FAT32); flags 0; fresh random unique GUID.
- PARTLABEL (kernel `root=PARTLABEL=xxx`) comes from the GPT NAME — type GUID is not consulted.

## 4. CRCs — ORDER MATTERS
```
entries_crc = binascii.crc32(entries_block) & 0xffffffff   # full 32×128 block
pack_into('<I', header, 88, entries_crc)                    # ① entries_crc FIRST
h2 = bytearray(header); pack_into('<I', h2, 16, 0)          # ② zero hdr_crc
hdr_crc = binascii.crc32(bytes(h2)) & 0xffffffff
pack_into('<I', header, 16, hdr_crc)                        # ③ hdr_crc LAST
```
Computing hdr_crc before writing entries_crc produces a silently invalid table. **Validate your
CRC code by recomputing the ORIGINAL device GPT and comparing with its stored CRCs before
trusting any new output.**

## 5. Backup GPT
Build as [entries(1 sector) + header(1 sector)]:
- header: sig, hdr_size=92, cur_lba = its own LBA, backup_lba = 1, first/last_usable same,
  disk_guid same, part_entry_lba = backup entries LBA, nents/entsz same, entries_crc same,
  hdr_crc computed last (same zero-then-crc trick).

## 6. Write & verify
```
edl.py --loader=<melf> ws 0            gpt_main0_new.bin     # primary at LBA0
edl.py --loader=<melf> ws 60884987     gpt_backup0_new.bin   # backup entries+header
edl.py --loader=<melf> printgpt                                # verify device-side
```
or after reboot: `fastboot getvar all` (new partitions appear as partition-size entries) or
`lsblk` from booted Linux. NEVER skip verification after a GPT write.

## Traps
- **sgdisk does NOT work** for 4096-byte-sector GPT on a plain image file: it assumes 512-byte
  sectors and misreads the table (empty partition list, wrong sizes). Edit entries in Python.
- `edl.py gpt <dir>` only DUMPS GPTs (and generates rawprogram XMLs) — it does not write.
  Writes are raw-sector `ws` or a QFIL-style rawprogram XML via `edl.py qfil/xml`.
- The GPT write itself is not the risky part; the risky part is an invalid CRC the device
  silently rejects. Verify CRCs both ways (recompute vs stored) before writing.
