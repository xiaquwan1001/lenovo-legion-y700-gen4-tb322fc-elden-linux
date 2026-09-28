# TB321FU region lock — forensics & fix (2026-08-08)

Session evidence for the "系统与硬件不兼容" = ABL EBS = region-lock conclusion, and the
LTBox-method fix that was built but not yet boot-tested (USB channel failed before the
final flash completed).

## Symptom chain (what was actually observed)
1. Flashed ROW 17.5.10.031 full set (vbmeta enable) into slot a, `fastboot set_active a`, reboot.
2. Screen: "显示现在系统与硬件不兼容，将自动关机" (EBS).
3. logfs (`edl r logfs /tmp/logfs.bin`) ring buffer showed **5 boot records, ALL ending at
   `Start EBS [~13050]`** with identical tails:
   - `[2407]Fastboot=0, Recovery:0`
   - `[2497]Load Image dtbo_a total time: 6 ms`
   - `[2588]DP DTB: No Valid DTB in image` / `Override DTB: GetBlkIOHandles failed loading user_dtbo!`
   - `BootConfig[11]: androidboot.dtbo_idx=36` / `dtb_idx=6`
   - `Start EBS [13050]` ← then nothing. **No `Load Image boot_a` line ever appears.**
4. `edl r misc` → `ffbm-00` (factory-mode marker).
5. `edl r devinfo` → `ANDROID-BOOT!` + `01` = BL unlocked, no region data there.

Conclusion: the device never got past the ABL gate in ANY of attempts A2–A6. The earlier
"kernel-stage CrashDump / liblp invalid geometry" attribution was built on a STALE
rawdump from an earlier real boot (A2, version-mixed set) — minidump is first-panic-locked.

## Where the region marker lives
- vendor_boot.img (ROW 17.5.10.031) contains an FDT node named `product_region` whose
  property value is `PRC` or `ROW`. LTBox `detect_product_region()` walks FDT_PROP entries
  after `FDT_BEGIN_NODE "product_region\0"` and matches the value.
- **EMPIRICAL CORRECTION (2026-08-08): the literal node name `product_region` does NOT
  appear anywhere in TB321FU ROW 17.5.10.031 vendor_boot (0 hits).** The region markers
  are the FDT_PROP **property values** themselves: 4× `IROW` at 0xa079b8 / 0xa98b0a /
  0xb29cf8 / 0xbb9eae, each in the byte pattern `03 00 00 00 04 00 00 00 <nameoff> ... <val>\0`
  (= FDT_PROP token 0x03, len 4, value `IROW`). The vendor_boot has 11 FDT blobs; the
  markers sit inside them. So: **grep for `IROW`/`.ROW` byte values, not the node name.**
- Pattern set used for conversion (LTBox `RegionPatternSet`):
  - ROW→PRC: `.ROW`→`.PRC`, `IROW`→`IPRC`  (row_patterns)
  - PRC→ROW: `.PRC`→`.ROW`, `IPRC`→`IROW`  (prc_patterns)
- ROW 17.5.10.031 vendor_boot contains **4× `IROW`, 0× `.ROW`**. boot/init_boot/dtbo have
  **0 region markers** (verified) — region lives in vendor_boot only.
- **Fingerprint strings are NOT the check**: patching `ZUI_17.5.10.031_251125_ROW` →
  `ZUI_17.5.10.031_251125_PRC` in all four images (boot/vendor_boot/dtbo/init_boot) and
  re-flashing still produced the same EBS. Do not waste a cycle on fingerprint patching.

## Fix build (mirror of LTBox's `build_region_converted_avb_images`)
Artifacts in `~/下载/刷机/repart/final/` (boot/vendor_boot/init_boot/dtbo/vbmeta) — [已归档/清理 2026-08-10，原文件已随刷机目录删除；如需重构建此方案，原始固件解压自 `~/下载/刷机-保留/archive/`]
all testkey-signed, avbtool info_image verified (public key sha1 2597c218… = testkey_rsa4096).
1. vendor_boot: ROW stock → replace `.ROW`→`.PRC`, `IROW`→`IPRC` (4 replacements).
2. `avbtool.py add_hash_footer` (testkey_rsa4096.pem, SHA256_RSA4096, flags 0) on all 4:
   - boot: --partition_size 100663296 --rollback_index 1759622400 (OEM footer present; resign preserves original image_size 35311616)
   - vendor_boot: --partition_size 100663296 --rollback_index 0
   - init_boot: --partition_size 8388608 --rollback_index 0
   - dtbo: --partition_size 25165824 --rollback_index 0
3. `avbtool.py make_vbmeta_image --key testkey_rsa4096.pem --algorithm SHA256_RSA4096
   --rollback_index 0 --flags 0 --include_descriptors_from_image <boot> <vendor_boot>
   <init_boot> <dtbo>` → 4 hash descriptors, **no --chain_partition** (vbmeta_system left
   unreferenced; the flashed vbmeta_system_a stays flags=2 disable → system/vendor not verified).
4. Flashing: the EDL USB-Overflow wedge hit again mid-write, so **the remaining 4+1
   partitions were flashed via `fastboot flash boot_a/vendor_boot_a/init_boot_a/dtbo_a/vbmeta_a`
   — the fastboot channel completed all 5 writes with ZERO errors** (BL unlocked). Lesson:
   on this device EDL firehose wedges after 1–2 writes, fastboot is the reliable channel.

## Boot test result (2026-08-08) — region gate PASSED, follow-on blocker found
- Config A (testkey vbmeta flags=0 + PRC vendor_boot + resigned boot/dtbo/init_boot):
  reboot → **the "系统与硬件不兼容" EBS message is GONE** → instead **fastboot bootloop**.
- Config B (erase misc first — ffbm-00 removed): still fastboot bootloop.
- Config C (vbmeta → disable flags=2, same images): still fastboot bootloop.
- Config D (stock UNMODIFIED ROW boot.img + PRC vendor_boot + disable vbmeta): still
  fastboot bootloop.
- **Eliminated causes**: AVB validation (enable and disable both loop), boot.img content
  (stock boot loops), ffbm/misc marker, region gate (passed). **Root cause UNRESOLVED** —
  the device reaches the ABL boot chain but never loads boot_a into a kernel; logfs read
  (`edl r logfs`) immediately after the FIRST failed boot is the next diagnostic (retries
  overwrite the ring). Do NOT present this as a working end-to-end recipe yet.
- Device returned to working state: `fastboot set_active b` → Ubuntu (GRUB) boots normally
  (a/b isolation held; Android experiments never touched Ubuntu).

## NindoS GSI success counterpoint (open question)
XDA user NindoS flashed a GSI successfully on TB321FU with: ROW ZUI 17 stock + **MUST NOT
disable AVB** ("it would make your system unbootable") + `fastboot erase system` + flash
GSI + wipe userdata — i.e. stock vbmeta kept enabled, system-only swap, no super rebuild.
Our path instead rebuilds vbmeta_system as flags=2/unreferenced. Both cannot be fully right;
if the fastboot-loop blocker persists, testing the NindoS combination (stock vbmeta enable
+ stock super + system-only GSI) is the alternative that has one confirmed success.

## Ready-made MOD firmware (community, avoids all of the above)
XDA user **ahnoriku** (thread "Lenovo Y700 Gen 3 CN Rom to ROW Rom Guide", 4744907) ships
pre-converted full packages: **`ZUI 17.5.10.031 mod ROW->PRC`** (Google Drive id
`1X6OP5QoNBUsJyhRsSojN_Qm5RqT5Ws9q`, 6.63 GiB), plus `ZUI 17.0.12.183` and `17.0.12.136`
MODs. Each = complete EDL flash package (Flash.cmd + image/ + optional Magisk/KernelSU/SukSU
root, GPU undervolt). Guide's USB rule: **USB 2.0 port + USB 2.0 cable + device LONG-side
USB-C port** — "otherwise you will have difficulty detecting the device in fastboot and EDL
mode" (explains this session's EDL wedges). Other tools in that thread: decrypt_x_to_xml
(Breed43214, `pip install cryptography` + decrypt_batch.bat), `TB320FC_ROW_fastboot_prc_v2.x.zip`
(hitin911's vendor_boot modifier, 1.create_batch.bat), hitin911 modified XMLs
(contents.xml / rawprogram4_MOD.xml / rawprogram_save_persist_and_data_unsparse0.xml —
blanks metadata_1..7 and userdata_1..10 filenames to skip), QFIL v3 (Lenovo link).

## Google Drive large-file download without gdown (China network)
`pip install gdown` failed (PEP 668 + mirror 403 on soupsieve). Working substitute
(script `~/下载/刷机/mod/gdrive_dl.py`, pure stdlib) [已清理 2026-08-10，该脚本已随刷机目录删除]
1. GET `https://drive.google.com/uc?export=download&id=<ID>` with a cookie jar → virus-scan
   warning page.
2. Regex `name="uuid" value="([^"]+)"` (present on the warning page) and `name="confirm"`.
3. Download from `https://drive.usercontent.google.com/download?id=<ID>&export=download&confirm=t&uuid=<UUID>`
   (fall back to confirm=t when the page lacks a confirm field), stream to file.
Fetched 6.63 GiB successfully this way. Also: `curl` to drive.google.com intermittently
fails with SSL error 35 on this network — retry loop or python urllib handles it.

## Reference numbers (TB321FU ROW 17.5.10.031)
- Main vbmeta: SHA256_RSA4096, rollback 0, flags 0; chain: boot(loc3), recovery(loc1),
  vbmeta_system(loc2, OEM RSA2048 key sha1 cdbb7717…); hash descriptors for
  vendor_boot/dtbo/init_boot/odm/system_dlkm/vendor/vendor_dlkm; fingerprint props
  `Lenovo/TB321FU/TB321FU:14/UKQ1.240826.001/ZUI_17.5.10.031_251125_ROW:user/release-keys`.
- vbmeta_system: RSA2048, rollback 1759622400, hash/hashtree for pvmfw/system/vendor/product/system_ext.
- ZUI 17.5.10.031 = **Android 16** base (os_version=16) → Pixel-komodo-16 GSI is the matching generation.
- ABL: `UEFI Ver 6.0.251126.BOOT.MXF.2.1-01946-LANAI-1` (firmware 251125) — inside the
  ≤17.5.10.170 window where ABL trusts AOSP test keys.

## Community resources surfaced (MCP: firecrawl/tavily/exa)
- XDA "[GEN_3] Bricked Legion Tab Gen 3 – Hardware compatibility error / FFBM bootloop"
  (xdaforums.com/t/…4786388): same error; one success = RSA flash of stock ROM then in
  FFBM press all three buttons to reboot; a 2026-08-05 user on ROW 17.5.10.272 still stuck.
- "[GUIDE] Unbrick Lenovo Y700" (xdaforums.com/t/…4509297, gen2): QFIL must load **ALL**
  rawprogram + **ALL** patch files; "RSA trick" = swap target ROM images into
  `C:\ProgramData\RSA\Download\RomFiles\<model>` to make RSA flash a cross-region build.
- LTBox (github.com/miner7222/LTBox): Rust, region conversion + AVB rebuild + `.x`
  decrypt + rollback bypass; source is the authoritative reference for the mechanism.
- Korean ppomppu post (m.ppomppu.co.kr androidtab no=197457): Y700 gen2 "secondary
  country code" analysis — corroborates the country/region storage concept.
