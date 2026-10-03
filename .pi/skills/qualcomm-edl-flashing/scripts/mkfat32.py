#!/usr/bin/env python3
"""Empty FAT32 volume generator — pure Python, no mkfs needed (agent policy often blocks mkfs).

Verified on Lenovo Y700 Gen3 (TB321FU): 1G image, 512B sectors, 8 sectors/cluster (4K),
32 reserved, 2 FATs x 2048 sectors, root cluster 2, custom label. Flashed to a GPT partition
and booted GRUB from it.

Usage: python3 mkfat32.py <image> <size_bytes> <label>
After generating, populate with mtools (apt-get download mtools && dpkg -x ...; mcopy/mdir
run without root) or a tree-writer like make_fat.py (reads BPB from the image).
"""
import struct, sys

img_path = sys.argv[1]
size = int(sys.argv[2])
label = sys.argv[3].encode('ascii')[:11].ljust(11, b' ')

BPS = 512          # bytes per sector
SPC = 8            # sectors per cluster (4K clusters)
RSVD = 32          # reserved sectors
NFAT = 2
FATSZ = 2048       # FAT sectors (1MB per FAT, fits ~262k clusters; 1G volume)
TOT_SEC = size // BPS
ROOTCL = 2
DATA_START = RSVD + NFAT * FATSZ   # sector 4128 for 1G
NCLUST = 2 + (TOT_SEC - DATA_START) // SPC

assert NCLUST < 0x0FFFFFF0, "too many clusters for FAT32"
assert size % BPS == 0

img = bytearray(size)

def put(off, data):
    img[off:off+len(data)] = data

# --- boot sector (LBA0) ---
bs = bytearray(512)
bs[0:3] = b'\xEB\x58\x90'
bs[3:11] = b'MSDOS5.0'
struct.pack_into('<H', bs, 0x0B, BPS)          # bytes/sector
bs[0x0D] = SPC                                  # sectors/cluster
struct.pack_into('<H', bs, 0x0E, RSVD)         # reserved
bs[0x10] = NFAT                                 # fats
struct.pack_into('<H', bs, 0x11, 0)            # root entries (FAT32=0)
struct.pack_into('<H', bs, 0x13, 0)            # total16
bs[0x15] = 0xF8                                 # media
struct.pack_into('<H', bs, 0x16, 0)            # fatsz16
struct.pack_into('<H', bs, 0x18, 32)           # sectors/track
struct.pack_into('<H', bs, 0x1A, 64)           # heads
struct.pack_into('<I', bs, 0x1C, 0)            # hidden
struct.pack_into('<I', bs, 0x20, TOT_SEC)      # total32
struct.pack_into('<I', bs, 0x24, FATSZ)        # fat32 size
struct.pack_into('<H', bs, 0x28, 0)            # ext flags
struct.pack_into('<H', bs, 0x2A, 0)            # fs version
struct.pack_into('<I', bs, 0x2C, ROOTCL)       # root cluster
struct.pack_into('<H', bs, 0x30, 1)            # fsinfo sector
struct.pack_into('<H', bs, 0x32, 6)            # backup boot sector
bs[0x40] = 0x80                                # drive
bs[0x42] = 0x29                                # boot sig
struct.pack_into('<I', bs, 0x43, 0x12345678)   # volume id
bs[0x47:0x52] = label
bs[0x52:0x5A] = b'FAT32   '
bs[510:512] = b'\x55\xAA'
put(0, bs)
put(6*BPS, bs)  # backup boot sector

# --- FSInfo (LBA1) ---
fsi = bytearray(512)
struct.pack_into('<I', fsi, 0, 0x41615252)     # lead sig
struct.pack_into('<I', fsi, 484, 0x61417272)   # struc sig
struct.pack_into('<I', fsi, 488, NCLUST - 1)   # free clusters
struct.pack_into('<I', fsi, 492, 2)            # next free
struct.pack_into('<I', fsi, 508, 0xAA550000)   # trail sig
put(BPS, fsi)
put(7*BPS, fsi)  # backup FSInfo

# --- FAT tables ---
fat = bytearray(FATSZ * BPS)
def fat_set(c, v):
    struct.pack_into('<I', fat, c*4, v | 0x0F000000)
fat_set(0, 0xFFFFFF8)
fat_set(1, 0xFFFFFFF)
fat_set(2, 0xFFFFFFF)   # root cluster = EOC
put(RSVD * BPS, fat)
put((RSVD + FATSZ) * BPS, fat)  # FAT2

with open(img_path, 'wb') as f:
    f.write(img)
print(f"{img_path}: {size} bytes, TOT_SEC={TOT_SEC}, NCLUST={NCLUST}, data_start={DATA_START}, label={label!r}")
