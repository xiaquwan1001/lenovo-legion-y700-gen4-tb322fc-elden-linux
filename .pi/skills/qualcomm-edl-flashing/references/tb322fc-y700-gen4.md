# Lenovo Legion Y700 Gen4 (TB322FC) — device & unlock/flash notes

SM8750 (Snapdragon 8 Elite / 8 Gen 4, Oryon), ZUXOS (Lenovo ZUI 16 line), A/B slots.
Collected 2026-08-15 from live device (adb) + XDA thread 4743906.

## Device facts (verified on live unit, ZUXOS 1.1.11.120)
- Model TB322FC_PRC (CN), Android 15, security patch 2025-06-05.
- Kernel: `6.6.56-android15-8-g38447e018c92-ab12829524-4k` (GKI 6.6, KMI line android15-6.6).
  Newer ROMs (1.5.10.229) ship `6.6.118-android15-8`. 297 vendor .ko in /vendor_dlkm.
- BL state: `ro.boot.flash.locked=1`, `ro.boot.vbmeta.device_state=locked`, verifiedbootstate=green.
- Active slot `_a`. bootload_sn (64 hex) via `adb shell getprop ro.boot.bootload_sn`
  (device: 5B9DC4A7...C584AA89; serialno HA2ABH62).
- UFS multi-LUN like Gen3: super = physical sda10 (LUN0), userdata = sda16 (~211 GiB),
  A/B boot set (boot/vendor_boot/init_boot/recovery/dtbo/vbmeta) on sde = LUN4.
- ⚠️ NO vm-bootsys partition (Gen3 had vm-bootsys_a/b on LUN4 holding the Linux boot FAT).
  fstab has a COMMENTED-OUT `vm-bootsys` entry → Gen4 Linux-boot chain differs from Gen3 GUF296 scheme.
- fstab IS GSI-ready: system mounts with
  `avb_keys=/avb/q-gsi.avbpubkey:/avb/r-gsi.avbpubkey:/avb/s-gsi.avbpubkey:/avb/t-gsi.avbpubkey:/avb/u-gsi.avbpubkey:/avb/v-gsi.avbpubkey`
  (same as Gen3) → GSI system images accepted once BL unlocked.
- No root on stock (uid=2000 shell). `ro.build.ab_update=true` (A/B).

## Bootloader unlock — version gates (XDA 4743906, multiple confirmations)

> **★★ TWICE-CONFIRMED ON TWO UNITS (2026-08-16 U1 `HA2ABH62` · 2026-10-03 U2 `HA2EXB0E`).**
> The gate below is the ONLY thing that matters; do NOT waste a turn hunting for an unlock file.
> 2026-10-03 (U2, stock 1.5.10.259/Android16, locked): 3rd-party signed blob → `flash unlock` OKAY
> but `oem unlock` FAILED; after full-flash downgrade to `TB322FU_ZUXOS_1.1.11.073` a bare
> `fastboot oem unlock` succeeded FIRST TRY (no sn.img needed) → `unlocked:yes` +
> `Device unlocked: true / critical unlocked: true`. Cross-version AVB params unchanged
> (top vbmeta + boot chain = AOSP testkey sha1 `2597c218`, boot rollback 1738713600,
> vbmeta rollback 0); only vbmeta flags and the vbmeta_system chain key differ
> (1.1 = `cdbb7717`, 1.5.10.259 = `8fcb864f`). 1.5.x blobs are DEAD — official, gen3 template,
> and signature services alike (gen4 ABL embeds a NEW key, cert not shipped in the blob).
> Cost paid: /data wiped + Widevine L1→L3 (take the locked baseline BEFORE unlocking).

- **1.1.11.120 (current on device) is a TRAP**: "looks unlocked but reverts; root impossible"
  (coey0814). Do NOT attempt unlock from .120.
- Unlock commands exist ONLY on ROM ≤ **1.1.11.073/.076**. Known-good downgrade target:
  `TB322FC_S200001_2506121310_250612_PRC` (= ZUXOS 1.1.11.073) from
  `mirrors.lolinet.com/firmware/lenowow/2025/Y700_4th_Gen/TB322FC_CN/` (6,738 MiB 7z).
  .076 is NOT on lolinet — get it via OTA from .073, or just unlock on .073.
- Proven path (qtotter, 2026-07): downgrade .229→.073 (LTBox or QFIL, loader
  `xbl_s_devprg_ns.melf` from package image/) → unlock → upgrade back to modern ROM →
  flash LineageOS 23.2 GSI → wipe userdata → boot. Full success report.
- Gen4 has NO rollback-index protection ("Downgrade rom version is allowed without
  unlocking, no rollback index protection for gen4, it's unique" — hitin911). Unique
  among Lenovo tablets; still use QFIL/LTBox full flash, not partial.
- Unlock mechanics: `fastboot flash unlock sn.img` + `fastboot oem unlock` (volume-down
  x2 + power to confirm). sn.img = official unlock file: either apply via ZUI site
  (m.zui.com/iunlock) or modify LoGen0110's sn.img template hex (Bootloader_SN Part1+Part2,
  jsfiddle.net/2uvz1fwn generator) — must match own bootload_sn.
  Error `Download is not allowed on locked devices` = wrong/newer ABL → downgrade first.
- ⚠️ Use ONLY lolinet/l官方 packages for downgrade: 4PDA-modified .073 builds changed the
  device serial AND bootload_sn and failed to boot (qtotter #129/#131).

## Root without unlock (LTBox route)
- LTBox (miner7222/LTBox) roots ANY ROM version with NO unlock: KernelSU-Next / SukiSU
  Ultra / APatch. hitin911: "Use LTBOX tool to get root with no unlock on any rom
  version, no unlock needed at all. Don't use magisk."
- Testkey vulnerability: locked devices on ZUI/ZUXOS ≤ **1.5.10.138** can be flashed via
  EDL without unlocking (TWRP README) — fastboot flash still refused while locked.

## TWRP (polygraphene/android_device_lenovo_TB322FC)
- Release: TWRP 3.7.1_16, `TWRP-3.7.1-16-TB322FC-2026-04-04-2-portrait/landscape.img`
  (~100 MB). Works: ADB, display, decryption, fastbootd, flashing, MTP, touch, OTG.
- Flash (locked): EDL via qdlrs + `xbl_s_devprg_ns.melf` from qpst ROM:
  `qdl-rs --loader-path xbl_s_devprg_ns.melf --storage-type ufs --backend serial
  --dev-path COMx --phys-part-idx 4 write recovery_a <twrp.img>` (also recovery_b), then `reset`.
- Windows-only qdlrs binary; edl.py (bkerler) should be equivalent on Linux.

## GSI / ROM status
- LineageOS 23.2 (Android 16) GSI confirmed working on TB322FC (qtotter).
  Source: Doze-off/lineage_treble GitHub releases (temporarily pulled 2026-07;
  Telegram @dozeoff_treble; MisterZtr/LineageOS_gsi as alternative).
- ColorOS 16 / HyperOS 3 / OnePlus Pad2 Pro ports exist via CN B站 scene
  (悲伤的压缩包 etc.), flashable without unlock via 9008; pick "不会tee损坏" builds.

## Linux-on-ARM outlook (differs from Gen3!) — CORRECTED 2026-08-16 (survey below supersedes)
- No GUF296-style project for TB322FC yet. No vm-bootsys partition → the Gen3 boot-FAT
  trick (vm-bootsys_a swap) does NOT carry over; SM8750 needs a fresh boot chain.
- **UEFI DOES exist for SM8750 (correcting the old "no UEFI project" claim)**: Project
  Silicium **Mu-Silicium** (github.com/Project-Silicium/Mu-Silicium, Project-Mu-based
  ARM64 UEFI) supports SM8750 OnePlus 13 (`dodge`)/13s (`pagani`); its Y700 entry is the
  2023 model (9707f), State: Inactive → TB322FC needs a per-device port (memory map /
  UFS / panel / touch) on the existing SM8750 base. Long-term dual-boot bootloader path:
  UEFI → EFISTUB/GRUB → mainline kernel.
- Mainline kernels to build from: `sm8750-mainline/linux` (org, master v6.16,
  OnePlus-13-WIP) + `renhiyama/pagani-linux` (Linux 7.1, OnePlus 13s "eliza": display
  DSC 1.2 / touch / ath12k WiFi working); postmarketOS oneplus-pagani booting=yes
  (kernel 7.1). TB322FC DT patch (Pengyu Luo, 2026-07) NOT merged; basic only.
- Fallback boot w/o UEFI: mkbootimg-pack mainline Image.gz+dtb+initramfs →
  `fastboot boot boot.img` (ABL acceptance on unlocked Gen4 UNTESTED).
- Windows on ARM: still NOT viable (no SM8750 WoA bring-up; Renegade dead).
- Full resource map + host toolchain (clang-21 / aarch64-gcc 15.2 / dtc / 644 GiB):
  `~/下载/刷机-四代/LINUX-DUALBOOT-RESOURCES-2026-08-16.md`.

## Resource list
- Firmware (CN): `https://mirrors.lolinet.com/firmware/lenowow/2025/Y700_4th_Gen/TB322FC_CN/`
  (S200001=.073 downgrade 6738MiB; 1.1.11.120; 1.1.11.263). lolinet throttles CN
  networks (~33KB/s direct) → aria2 -x16 via local proxy (127.0.0.1:7890) ≈ 22MB/s.
- XDA unlock thread: xdaforums.com/t/4743906 (LoGen0110 sn.img template + 9008.melf notes).
- XDA gen4 general: xdaforums.com/t/4731171.
- TWRP: github.com/polygraphene/android_device_lenovo_TB322FC (+ qdlrs build).
- LTBox: github.com/miner7222/LTBox.
- GSI: Doze-off/lineage_treble (t.me/dozeoff_treble), MisterZtr/LineageOS_gsi.
- Kernel CI mirror: qianmingzi7-coder/tb322fc-r2-kernel-public-build (GKI 6.6.111 ReSukiSU).
- ONFIX (CN, paid) hosts newer line-flash packs (TB322_ZUXOS_1.5.10.229).

## ✅ BL UNLOCK SUCCESS 2026-08-16 (TB322FC, LUN4=073 downgraded ABL)
**VERIFIED: `unlocked: yes` + `Device unlocked: true` + `Device critical unlocked: true`**
- Prereq: LUN4 fully downgraded to 073 (35/35 verified). The 073 ABL is what accepts the unlock flow; stock 120 ABL silently no-ops (`oem unlock-go` returns OKAY but `unlocked` stays `no` — TRAP, do not waste time on 120).
- Working sequence (NO reboot between flash and oem unlock!):
  1. `fastboot flash unlock sn_<64hex>.img` → OKAY (Warning "unlock partition size: 0" is NORMAL)
  2. `fastboot oem unlock` → OKAY, **device screen shows confirm UI** → user presses Vol-down ×2 + Power on the TABLET (host cannot do it)
  3. Verify `fastboot getvar unlocked` → `yes`; `oem device-info` → Device unlocked: true
  4. Critical lock: `fastboot flashing unlock_critical` → OKAY (device shows confirm UI AGAIN) → Vol-down ×2 + Power → `Device critical unlocked: true`
- Pitfalls: rebooting bootloader between flash & oem unlock kills the unlock auth (`oem unlock fail`); `flashing unlock` = `unknow command` on this ABL (use `flashing unlock_critical` only for critical); after unlock data wiped; `slot-unbootable:a:yes` expected (super half-written) — fix with `fastboot set_active a` after flashing.

## 🚀 POST-UNLOCK ROUTE CORRECTION 2026-08-16 (kills the EDL chunk-write grind)
**Unlocking BL changes EVERYTHING for the flash path — the 44×512MB EDL chunk-write + physical-restart loop was a LOCKED-STATE workaround only, NOT required for dual-boot.**
- Post-unlock, ALL large partition writes go through fastboot in ONE shot: `fastboot flash super super_full.img` (22GiB; fastboot has no per-session program limit like firehose; Gen3 proved 13G super via fastboot). No more chunking, no more per-chunk reboots.
- GPT surgery stays EDL (`edl.py ws` primary LBA0 + backup tail sectors) but it is a LIGHTWEIGHT op: 2 sectors, single session, seconds — NOT a big-partition write. See gpt-surgery.md.
- Remaining EDL uses after unlock: GPT write-back, full backup/restore, unbrick only.
- Full analysis (Gen3 vs Gen4 differences, GPT dual-boot feasibility, community resources): `~/下载/刷机-四代/BL-UNLOCK-AND-DUALBOOT-ANALYSIS-2026-08-16.md`.
- Gen4 super = 0x580000000 (22 GiB, vs Gen3 13 GiB); userdata 0x34D9E53000 (211.8 GiB); boot 96 MiB (same); 112 partitions (vs 107).

## ✅ LINEAGEOS GSI FLASHED 2026-08-16 (TB322FC, Doze-off LOS 23.2 A16 QPR2 VANILLA)
**VERIFIED: booted into LineageOS 23.2 GSI, userdata wiped, fully working.**
- GSI source: Doze-off/lineage_treble release 2026-06-03 (VANILLA 854MB xz → 2.8GB raw ext4). CN network: aria2 through gh-proxy.com prefix (3.8MB/s, resume works) >> local proxy (500KB/s).
- Working flash sequence (BL unlocked, all fastboot): `flash super super_full.img` (22GiB, 15×768MB sparse, 300s, all OKAY) → `set_active a` → bootloop diagnosis → **LTBox Simple Flasher full-flash 073** → `adb reboot fastboot` (→ bootloader fastboot, is-userspace:no) → **`fastboot reboot fastboot` (→ fastbootd, is-userspace:yes — REQUIRED for system logical partition)** → `erase system` → `flash system <GSI>` (auto Resize system_a, 75s) → `-w` → `reboot`.
- Full record: `~/下载/刷机-四代/GSI-FLASH-SUCCESS-2026-08-16.md`.

### ⚠️ GPT-version layout mismatch = "卡 logo" root cause (2026-08-16, big trap)
- Symptom: after flashing 073 super, device stuck at Lenovo logo; logfs shows ALL 10 PORs ending `Start EBS`, with `Loading Image boot_a ... Image size : 4096 Bytes` for EVERY boot-chain image + `BootLinux: factory_build = 1`. Yet AVB passed (`VB2: boot state: orange`), HWID/region correct (`SM8750P_16+512_13`, `config = PRC`), and **all 8 boot-chain partitions (boot/init_boot/vendor_boot/vbmeta/vbmeta_system/dtbo/recovery/pvmfw) read back hash-identical to the 073 package**.
- REAL root cause: device GPT was still the **120-era GPT** (8/15 downgrade wrote partition CONTENTS only, never the GPT). 120 vs 073 LUN4 GPT layouts DIFFER: entry 24 ending_lba 0x000FFFFF (1GB) vs 0x00067D18 (415MB) → partition positions shifted. The 073 ABL looks up boot_a by the 073 layout, reads the wrong location → "Image size 4096B" → EBS.
- Fix: flashing the 073 GPT alone is NOT enough (contents still sit at 120 positions) → **must re-flash ALL LUN partitions per the 073 layout = LTBox full flash** (or rawprogram0-5). LTBox Simple Flasher did it in one pass and the device booted into 073 immediately.
- Lesson: when downgrading/flashing, GPT and partition contents must share the SAME version layout; content-only flash with stale GPT = silent layout mismatch. Diagnose GPT: compare device GPT vs package `gpt_mainN.bin` via `edl.py rs 0 6 --lun=N` (the `gpt <dir>` dump can silently fail to write files after a wedge — prefer rs).

### ⚠️ LTBox Flash Firmware wizard model-check blocks; use Simple Flasher (2026-08-16)
- Flash Firmware wizard aborts at stage 3/9: `机型不匹配(设备: TB322FCADC, 固件: TB322FC_PRC)`. Gen4 has NO rollback protection, so the wizard's rollback handling is unnecessary anyway.
- Fix: **Advanced → Firmware Simple Flasher** (flash only, no checks/edits, = stock Flash.cmd equivalent). Flashed all LUNs clean, device booted.

### ⚠️ fastbootd entry on Gen4 ABL (2026-08-16)
- `adb reboot fastboot` lands in **bootloader fastboot** (ABL, `is-userspace: no`) — CANNOT flash system (logical partition inside super).
- **Must run `fastboot reboot fastboot` a SECOND time** → fastbootd (`is-userspace: yes`) → then `erase system` / `flash system` works (auto Resizes system_a for the GSI).
- `fastboot fetch` unsupported on this ABL (`Unable to get max-fetch-size`) — readback via EDL `rs`.
- EDL `rs` sector unit = **4096B block** (not 512B): LBA = byte_offset/4096. First attempt with 512B units read empty 0xFF regions (misleading mismatch).
- misc carried `--wipe_data --reason=MasterClearConfirm` (unlock leftover, never consumed); zeroing it is a valid interference-elimination step (was NOT the root cause here).

## 📐 GPT SURGERY / DUAL-BOOT FACTS (2026-08-16, measured)
- **LUN0 = 234.2 GiB** (sda 491,126,784 × 512B; GPT uses 4096B logical sectors — LBA = byte_offset/4096; a 512B-unit misread shows a phantom 29.3GB disk, don't trust that).
- Layout: proinfo@LBA6 → ... → super@90504 (22 GiB) → vbmeta_system/metadata/rawdump/pstoredump → **userdata@5972392 (211.2 GiB, LAST partition, ends at disk tail 61390842)**. userdata tail-shrink → ubuntu + grubfat is the Gen3-verified pattern; 16/32 GPT entry slots free.
- **⚠️ Lenovo gpt_mainN.bin/gpt_both0.bin in the 073 package are PLACEHOLDERS**: gpt_main0 describes only a 22.8 GiB disk with userdata size=0 (first 5972392 > last 5972391). The REAL device GPT (with full 211.2 GiB userdata) is generated from rawprogram_unsparse0.xml at flash time (LTBox Simple Flasher does this correctly — device boots fine). Never edit these placeholder files for surgery; dump the device GPT instead (`edl.py rs 0 6 --lun=0`, or Android `dd if=/dev/block/sda bs=4096 count=6` as root, or `fastboot getvar all`).
- GPT surgery method: `references/gpt-surgery.md` (Python edit, CRC order, EDL ws 0 + ws 61390843 backup, sgdisk N/A on 4096B).
- **Dual-boot plan A (to TEST)**: boot_b = mkbootimg(mainline Image.gz+dtb+initramfs), `fastboot flash boot_b` + `set_active b` — Gen4 ABL unlocked/orange may accept it (Gen3 rejected custom kernels but that was region-lock+prevent-flash; Gen4 is PRC+PRC+unlocked — UNTESTED). Zero-risk probe: `fastboot boot boot.img`. Plan B: Project Silicium Mu-Silicium UEFI port (SM8750 supported on OnePlus 13/13s, TB322FC needs panel/touch/UFS adaptation). Plan C: wait for TB322FC DT mainline merge (Pengyu Luo, v1 2026-07).
- Kernel sources: sm8750-mainline/linux (OnePlus-13-WIP, active), renhiyama/pagani-linux (Linux 7.1, display/touch/ath12k).
- **Known GSI issue (user-confirmed 2026-08-16)**: camera driver has bugs on LineageOS GSI (non-fatal).

## 2026-08-15 downgrade session — hard-won facts (full log: ~/下载/刷机-四代/SESSION-2026-08-15.md)
- **pyusb ZLP bug = root cause of "qfil partial write" / "even-numbered program fails"**:
  `Endpoint.write(b'')` never transfers (len==0 → return 0) → firehose block-end ZLP
  never sent → device-side data-stream desync. Fix: usblib.py b'' branch calls
  `self.EP_OUT._write(b"", 5000)` (real ZLP via backend). Verified: session-internal
  consecutive cmd_program calls all succeed after fix.
- **Device-side per-program size limit ~1GB**: <1GB writes OK (super_3 857MB), 8.35GB+
  FAIL even with real ZLP. Solution: split into ≤512MB chunks via cmd_program_buffer
  (super-write-split.py, 44 chunks for 22GiB super).
- **Write timeout**: usblib data path now `EP_OUT.write(data, timeout=30000)` — pyusb
  default None hangs forever when device wedges (observed: python blocked in do_wait
  21 min after device went unresponsive mid-chunk).
- **LTBox "heavy thread panicked" = run_heavy closure panic**; LTBox flash checks active
  slot via ADB/Fastboot ("检查设备与槽位内核") — **impossible in EDL mode** → panic.
  Run LTBox with device in fastboot or booted-Android mode; it auto-enters EDL to flash.
- **ZUXOS 1.1.11.120 ABL**: `fastboot set_active` → "Slot Change is not allowed in Lock
  State" (locked-state slot ops blocked) → fastboot recovery path dead, EDL only.
- **⚠️ ELECTROSTATIC WARNING**: tablet accumulates static after long EDL writes — treat
  as hardware stress signal; keep per-session write volume/time bounded.
- State at session end: LUN4 100% 073 (verified 35/35), vbmeta_system_a 073, super
  partial (44-chunk split mid-write), gpt_main0 still 120, LUN1/2/3/5 unverified.
  Resume = re-run super-write-split.py (idempotent) → verify → reset → unlock → GSI.

## 2026-08-16 evening — POST-UNLOCK flash execution (super 直刷实证 + GSI 资源)
- **22 GiB super via ONE fastboot flash: VERIFIED SUCCESS.** `fastboot flash super
  super_full.img` (cat of 8 splits + truncate to 0x580000000) = 15 auto-sparse chunks of
  ~786 MB (fastboot max-download-size=768 MiB), each Sending ~20.7 s / Writing ~0.01 s,
  TOTAL 299.9 s (~38 MB/s USB2), 15/15 OKAY, zero wedges mid-transfer. Confirms the
  POST-UNLOCK ROUTE CORRECTION: no EDL chunking needed.
- **User directive: skip super_full.img hash verification entirely** (2026-08-16). The
  11.4 GiB shard+tail verify is the OOM source (see SKILL OOM pitfall) and the splits are
  official-package output — `cat super_{1..8}.img > super_full.img; truncate -s 23622320128`
  takes 11 s and is trustworthy as-is. Do NOT re-verify; flash directly.
- **Post-flash fastboot wedge pattern**: after the 5-min 22 GiB flash, `set_active a`
  printed OKAY but EVERY subsequent getvar (product/current-slot/slot-unbootable) timed
  out (124) while `fastboot devices` still enumerated. Long-flash sessions leave the
  channel fragile — expect this, recover by physical USB replug (device stays in
  fastboot), then verify slot state and `fastboot reboot`.
- **Gen4 073 super LP metadata is NOT AOSP-layout** (parsed 2026-08-16): 0PLA header @12288
  shows flags=0x100 (virtual A/B) and AOSP field offsets read garbage (tables_size@24 =
  370885263, partitions@92 = 728, header_size@108 = 3); six 0PLA copies every 64 KB
  (12288..339968). DO NOT hand-parse Gen4 LP metadata to learn system size; infer from
  super split sizes instead (super_4 = 7.78 GiB ≈ system_a — plenty for any 3-4 GiB GSI)
  and let fastbootd read the real metadata when flashing system.
- **GSI resource (qtotter-verified line)**: Doze-off/lineage_treble release 2026-06-03 =
  **LineageOS 23.2 A16 QPR2 Treble GSI UNOFFICIAL-signed**, 3 variants: VANILLA
  (854 MB xz → 2.8 GB raw ext4), MICROG (932 MB), GAPPS (1.09 GB). Assets NOT visible on
  the HTML releases page — fetch via
  `api.github.com/repos/Doze-off/lineage_treble/releases/tags/2026-06-03` (works when the
  HTML scrape shows nothing). Download via gh-proxy.com channel (see
  firmware-download-china-net.md). Repo default branch = "23.2", still active (2026-08-11).
- **Linux dual-boot resource survey (2026-08-16, full report:
  ~/下载/刷机-四代/LINUX-DUALBOOT-RESOURCES-2026-08-16.md)**:
  - TB322FC mainline DT patches (Pengyu Luo, 2026-07, phoronix-reported) NOT yet merged
    into any kernel tree; basic function only, WLAN/BT missing.
  - SM8750 platform kernels: `sm8750-mainline/linux` (org, master v6.16, OnePlus-13-WIP
    branch) + `renhiyama/pagani-linux` (Linux 7.1, OnePlus 13s "eliza": display DSC 1.2 /
    touch / ath12k WiFi working). postmarketOS: oneplus-pagani booting=yes (kernel 7.1).
  - UEFI: Project Silicium **Mu-Silicium** supports SM8750 (OnePlus 13/13s) but NOT
    TB322FC — the Y700 entry is the 2023 model (9707f), State: Inactive. Porting needed
    (platform layer exists); alternative = mkbootimg-pack mainline kernel →
    `fastboot boot boot.img` (ABL acceptance UNTESTED on Gen4 — the Gen3 gate may or may
    not apply post-unlock).
  - Host toolchain ready: clang-21 ✅, aarch64-gcc 15.2 installable, dtc ✅, 644 GiB disk.

## ⚠️ 2026-08-16 evening (part 2) — BOOTLOOP: GPT layout mismatch 120 vs 073
After flashing the full 073 super + boot chain the device stuck at logo (EBS). Root cause:
the device GPT (LUN0 AND LUN4) was still the 120-era layout while everything else was 073 —
the 073 ABL resolves partition offsets from the wrong map. All 8 boot-chain partitions read
back byte-identical to 073 (content fine); logfs signature: `Image size : 4096 Bytes` +
`BootLinux: factory_build = 1` + `Start EBS` (AVB still orange-pass). Writing package GPT
alone is NOT enough (partition content was laid out under the old GPT) — full-package flash
required (LTBox wizard chosen; session ended before verification). **Full forensics +
`rs/ws` 4096B-block units + `gpt <dir>` silent-no-op + GPT write recipe:
`references/tb322fc-bootloop-gpt-mismatch.md`.**
