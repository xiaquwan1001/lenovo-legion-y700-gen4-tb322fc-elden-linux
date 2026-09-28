# AOSP liblp v1.2 metadata format (for rebuilding `super` in Python)

Source: `system/core/fs_mgr/liblp/include/liblp/metadata_format.h` (LineageOS/android_system_core,
lineage-22.2 — same as AOSP). All little-endian. **v1.2 uses SHA256 checksums, NOT CRC32** (CRC32
was the v1.0 format; Android 13+ reads v1.2).

ALL layouts below were VERIFIED end-to-end 2026-08-07 by: (a) PC-side liblp-parser
simulation (geometry→header→tables→partition sizes all round-trip), (b) EDL readback of the
flashed super (gDla@0/4096/8192 + 0PLA@12288), and (c) boot-time kernel liblp no longer
rejecting geometry. THREE separate mis-layout layers produced the SAME kernel symptom
(`[liblp] Logical partition metadata has invalid geometry magic signature` → silent reboot
loop, ABL already passed) — see PITFALLS below; fix all three or the boot keeps failing.

## Constants
- `LP_METADATA_GEOMETRY_MAGIC = 0x616c4467` ("gDla"), `LP_METADATA_HEADER_MAGIC = 0x414C5030` ("0PLA")
- `LP_SECTOR_SIZE = 512` — **extent sector units are 512 bytes** even on 4096-byte-sector UFS
- `LP_PARTITION_ATTR_READONLY = 1`, `LP_HEADER_FLAG_VIRTUAL_AB_DEVICE = 0x1`
- major_version = 10, minor_version = 2; metadata header region = 256 B
  (`kMetadataHeaderSize`); packed struct sizes: geometry 52, header struct 116, partition 52,
  extent 24, group 48, block device 68.

## Disk layout of `super` (VERIFIED against stock ZUI image 2026-08-07)
```
[0 .. 4096)                    geometry copy 1
[4096 .. 8192)                 geometry copy 2
[8192 .. 12288)                geometry copy 3
[12288 ...)                    metadata slot 0  (header 256B + tables)
...                            more slots if metadata_slot_count > 1
...                            partition DATA (1 MiB alignment is safe)
[super_size - n*slot_max ..)   backup metadata slots
[super_size-4096 .. super_size) backup geometry
```
Evidence from stock `supers/super_1.img` (ZUI LP-metadata extract): `gDla` @4096 and
@8192, `0PLA` header @12288. liblp scans the geometry positions 0/4096/8192 and accepts a
valid copy at any of them; the metadata header MUST start at 12288 (= 3 × 4096).
Non-A/B single-copy super: `metadata_slot_count = 1` → one primary + one backup slot.
`slot_max` = geometry.metadata_max_size (e.g. 65536).

## LpMetadataGeometry (52 B, packed)
```
0   magic u32 (0x616c4467)
4   checksum[32] SHA256        — of the first struct_size bytes with the checksum field zeroed
36  struct_size u32 (=52)      — v1.1+ includes metadata_max_size
40  metadata_slot_count u32
44  max_size u32               — primary metadata region size (e.g. 65536)
48  metadata_max_size u32      — backup metadata region size (e.g. 65536)
```

## LpMetadataHeader (256 B region; packed struct is 116 B)
```
0   magic u32 (0x414C5030)
4   major_version u16 (=10) | minor_version u16 (=2)
8   flags u32 (=0; VIRTUAL_AB=0x1)
12  padding[12]                (zeros)
24  tables_size u32            — total bytes of the tables blob
28  header_checksum[32]        — SHA256 of the 256-byte region with this field zeroed
60  tables_checksum[32]        — SHA256 of the tables blob
92  partitions_size u32        — count (NOT a descriptor!)
96  extents_size u32
100 groups_size u32
104 block_devices_size u32
108 header_size u32 (=116, packed struct size — lpmake writes sizeof(struct))
112 reserved[4]
```
**Ordering bug**: write `tables_checksum` (60-92) BEFORE computing `header_checksum`
(28-60, zeroed while hashing) — otherwise the stored header fails its own checksum.
**Tables region starts at offset 256 of the metadata slot** (after the 256B header), and
the descriptor-free counts above (92-104) drive how many entries liblp reads from it.

## Tables blob (contiguous; sizes = count × entry_size)
partitions (52B) → extents (24B) → groups (48B) → block_devices (68B). Partition SIZES are
derived from extents (num_sectors × 512), NOT stored in the partition entries.

## LpMetadataPartition (52 B)
```
name[36] (fixed, zero-padded) | attributes u32 (=1 READONLY) | first_extent_index u32
| num_extents u32 | group_index u32
```

## LpMetadataExtent (24 B) — LINEAR target
```
num_sectors u64 (512-byte units) | target_type u32 (0=LINEAR)
| target_data u64 (physical sector within super, 512-byte units) | target_source u32 (0)
```

## LpMetadataPartitionGroup (48 B)
```
name[36] | flags u32 (0) | maximum_size u64 (0 = unlimited)
```
One group named `main` (lpmake default), all partitions group_index=0.

## LpMetadataBlockDevice (68 B)
```
first_logical_sector u64 — (12288 + slot_max*slot_count) / 512  (end of metadata area!)
| alignment u64 (1MiB = 2048 × 512) | alignment_offset u32 (0)
| size u64 (super partition size in BYTES) | partition_name[36] ("super") | flags u32 (0)
```

## PITFALLS — three layers, same kernel symptom ("invalid geometry magic signature")
1. **Geometry FIELD offsets** (layer 1): an earlier builder wrote `magic|struct_size@4|checksum@8`
   — overwriting the checksum domain. Correct: struct_size@36, checksum@4-36 (see above).
2. **Super-level COPY layout** (layer 2): geometry@0 + metadata@4096 fails — liblp probes 4096
   as a geometry position, reads `0PLA` instead of `gDla`. Correct: geometry copies @0/4096/8192,
   metadata @12288.
3. **Header FIELD layout + block-device table** (layer 3 — fix 1+2 alone still did NOT boot):
   an earlier builder used header_size@8, tables_size@44, checksums@12-44/48-80 and
   LpMetadataTableDescriptor triples @80-116 → liblp reads tables_size@24 = 0. Correct AOSP
   offsets: flags@8, tables_size@24, header_checksum@28-60, tables_checksum@60-92, plain
   counts @92-104, header_size@108=116. BlockDevice is 68B with alignment u64
   (a 64B `<QII Q 36s I` layout with alignment u32 shifts every following field);
   first_logical_sector = (12288 + slot_max*slot_count)/512, NOT (4096 + slot_max)/512.
   **This file previously documented the WRONG header layout (the builder's bug) — the
   layout above supersedes it.**

## Verification pattern (do this BEFORE flashing; 13G EDL write ≈ 6 min + reboot cycles per attempt)
Write a Python parser that mirrors liblp exactly and run it on the built image:
1. geometry: for each of the 3 copies check magic, then checksum == SHA256(first struct_size
   bytes with field zeroed); fields at 36/40/44/48 sane.
2. header @12288: magic "0PLA", fields at 24/92-108 sane, header_checksum and
   tables_checksum round-trip.
3. tables: read partitions_size/extents_size/groups_size/block_devices_size from the header,
   parse each table at its offset inside the blob, print partition name + extent-derived
   size (GiB) — sizes must match the source images.
4. block device: first_logical_sector/alignment/size/name round-trip.
All green before writing. Also read back the flashed super via EDL `rs 90504 8` (or the
super start sector) to confirm gDla@0/4096/8192 + 0PLA@12288 landed.
Note: a stale `rawdump` is NOT evidence a new boot did nothing — minidump writes are
unreliable (GRUB-launched panics and even some ABL-launched panics never update it; the same
liblp-error line @0.615320 persisted across many boots). Check the dump's console=/timestamp
signature against the previous dump before trusting it.
