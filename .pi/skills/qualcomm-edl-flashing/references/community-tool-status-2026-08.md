# Community tool status for TB321FU dual-boot (2026-08-08)

Research snapshot: what the community tools look like NOW, vs. what the early session records assumed.

## LTBox v3.2.2 — from bare reverse-engineering source to full GUI tool

Repo: github.com/miner7222/LTBox (Rust, iced GUI; wiki: miner7222.github.io/ltbox/en/).
v3.2.2 current as of 2026-08-08; commits active (Aug 2, 2026). Previously the project was
referenced only as `region.rs`/`avb.rs` reverse-engineering source — it has since become a
complete flashing product.

### Supported devices (from wiki)
| Device | ZUXOS | ZUI |
|---|---|---|
| Legion Tab Y700 3rd Gen (TB321FU) | 1.5.10.236 and earlier | **17.5.10.170 and earlier** |
| Legion Tab Y700 2nd Gen | full | 17.0.339 and earlier |
| Xiaoxin Pad Pro GT / Yoga Tab 11.1 AI | 1.5.04.428 and earlier | 17.5.04.059 and earlier |
| Yoga Pad Pro AI / Yoga Tab Plus AI | 1.5.10.186 and earlier | 17.5.10.096 and earlier |
| Legion Tab Y700 4th Gen | 1.5.10.138 and earlier | NONE |
| Legion Tab Y700 5th Gen | full (GBL efisp path) | full |

Cutoff logic: devices above the cutoff replaced the `AvbRSAPublicKey` embedded in ABL from
AOSP test key to a new key. Our device firmware (ROW 17.5.10.031) is within range.

### Feature map (what it automates vs. our manual work)
- **Convert Region**: rewrite vendor_boot region code (`.PRC`↔`.ROW`, `IPRC`↔`IROW`) + rebuild
  matching vbmeta — the manual patch that triggers `prevent flash` when done by hand, but the
  official pipeline passes (matches our ahnoriku-MOD finding).
- **Rebuild vbmeta**: re-sign with embedded AOSP test key (avbtool-rs testkey_rsa2048/4096).
- **Bypass Rollback Protection**: tracks boot and vbmeta_system floors separately; since v3.1.4
  also handles target firmware that already fixed the testkey vuln (backup current abl → convert
  → re-sign needed chain → flash → restore old abl).
- **Convert X to XML**: decrypts official `.x` rawprogram files.
- **EDL ops**: read/write partitions by GPT name, dump/flash whole LUNs, Firmware Simple Flasher.
- **Root/Unroot**: KernelSU family, APatch, Magisk, etc. — with locked bootloader.

### Linux deployment (2026-08-08, done)
1. Download `LTBox-linux_x86_64-v3.2.2.tar.gz` + `.sha256` from GitHub releases; verify hash.
2. Extract to `~/.local/opt/LTBox-linux_x86_64-v3.2.2/`; symlink into `~/.local/bin/ltbox`.
3. `./ltbox --install-desktop` (user-level .desktop + icon).
4. `pkexec ./ltbox --install-udev` (writes `/etc/udev/rules.d/51-ltbox-qcom.rules` — uaccess
   + plugdev for Qualcomm 9008/Lenovo USB).
5. Config at `~/.config/ltbox/settings.json`.

### Pitfall: "Qualcomm kernel USB driver is missing" on Linux
- LTBox defaults `qcom_driver_mode: "kernel"` on Debian-style systems → it wants the **qud**
  package (qualcomm/qcom-usb-kernel-drivers release-lnx-v1.0.6.5 → `qud_1.0.6.5_all.deb`),
  a source-built kernel-module package (depends build-essential, linux-headers-generic).
- Loading `qcserial` (already loaded in stock kernels) does NOT satisfy the check.
- **Fix: set `"qcom_driver_mode": "userspace"` in settings.json** — libusb path, same as
  bkerler/edl.py, no qud install, no kernel rebuild. Verified: GUI runs stable, warning gone.

## DynoBox (companion CLI, miner7222)

github.com/miner7222/DynoBox — firmware re-sign + customization CLI:
`resign` (--boot-spl/--vendor-spl/--system-spl/--fuck-lgsi/--debloat/--plus), `repack`
(split super images), `info` (AVB metadata), `verify` (integrity + semantic), `integrity-keygen`.
Not deployed (功能重复，未装).

## TWRP for TB321FU

github.com/polygraphene/android_device_lenovo_TB321FU — device tree; releases tag **b0006**
(TWRP 3.7.1_12, twrp-12.1 manifest):
- `twrp-3.7.1_12-TB321FU-b0006-portrait.img` / `-landscape.img` (100 MB each, Android bootimg).
- /data decryption (gatekeeper + boot AIDL), work-profile decryption, landscape fix.
- Its release notes: flashing system from the GUI won't resize partition — use **fastbootd**
  for GSI (auto-resizes). Consistent with NindoS path (erase system + flash GSI + wipe).

## XDA community posts (current state)

- **4744907** — CN→ROW Guide (ahnoriku MOD packages: ZUI 17.5.10.031 mod ROW→PRC + 17.0.12.183/
  136); unlock tool + vendor_boot modification tooling (TB320FC_ROW_fastboot_prc_v2.x, hitin911).
- **4742843** — [Gen3] GSI/Custom rom/Root (NindoS): ROW ZUI 17 + **MUST NOT disable AVB** +
  erase system + flash GSI + wipe userdata; DSU-bootable ⇒ flashable. DT2W: `echo 1 > /proc/gesture_control`.
- **4706488** — CN stock firmware links (hitin911): TB321FU_ZUI_16.1.10.027, 16.1.11.187_UNOFFICIAL,
  ZUX_1.1.10.138; confirms prog_firehose_ddr.elf does NOT work on TB321FU — use xbl_s_devprg_ns.melf.
- **4775810** — hitin911 ZUXOS thread: CN is now ZUXOS 1.5 (Android 16); TB321FU_ZUX_1.5.10.106
  full-package official link. Region-conversion target changed from ZUI to ZUXOS on CN side.
- **4786388** — FFBM brick thread (same "系统与硬件不兼容" symptom); RSA tool trick + 3-key reboot recovery.
- **4509297** — QFIL unbrick guide (ALL rawprogram + ALL patch files required).

## Strategy note (2026-08-08 decision)
- Recommended: get stock **ZUI booting first** (a-slot, closest path — region/prevent-flash/AVB
  all cleared, only slot-judgment pending), THEN swap system → Pixel GSI via NindoS steps.
  Pixel GSI adds variables on top of an unverified boot chain; stock ZUI is the verified base.
- Boot management: keep ABL A/B slot mechanism; b-slot default (Ubuntu); switch via
  `fastboot set_active a/b` (reliable small op) / `bootctl set-active-boot-slot` (Android root)
  / misc-partition script from Ubuntu (avbtool set_ab_metadata).
- "Put GRUB directly in the UEFI boot slot" is NOT possible — ABL expects a boot.img whose
  kernel section is a Qualcomm Image/firmware volume; a bare PE GRUB would be rejected and a
  hand-patched boot_b triggers prevent flash. The working design already puts GRUB at the UEFI
  boot location: boot_b(GUF296 UEFI firmware) → vm-bootsys_a FAT → BOOTAA64.EFI(GRUB) → Ubuntu.
