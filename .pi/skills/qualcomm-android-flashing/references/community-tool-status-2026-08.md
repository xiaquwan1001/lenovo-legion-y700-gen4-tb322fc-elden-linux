# Community tool status & new resources (researched 2026-08-08)

Research-only session (dual-boot work paused by user): re-checked the whole toolchain used for
the TB321FU project. Key result: several tools that were previously just source-code references
have matured into ready-made tools, and new firmware/recovery resources exist.
**Follow-up same day: LTBox + TWRP DEPLOYED (see deployment sections below).**

## LTBox (miner7222) — now a full GUI tool, not just reverse-engineering source

Repo: github.com/miner7222/LTBox (Rust/iced, GPLv3, **v3.2.2**, very active — commits 2026-08-02).
The local clone at `/tmp/LTBox` is ALREADY the latest main (commit cfcd848, 2026-08-02), NOT compiled.
Layout: `ltbox-core` / `ltbox-device` / `ltbox-patch` / `ltbox-gui` (sidebar wizard app; `iced`).
Wiki: https://miner7222.github.io/ltbox/en/ (index / connecting-a-device / install-other-region-firmware / install-same-region-firmware / how-it-works / troubleshooting).

Capabilities — map directly onto what this project did by hand:
- **Convert Region**: rewrites the vendor_boot region code (PRC↔ROW) and rebuilds the paired
  vbmeta — the manual `.ROW`→`.PRC` patch + avbtool rebuild job, done end-to-end.
- **AVB**: obtain image info, detect rollback protection, **bypass rollback protection**
  (tracks SEPARATE floors for `boot` and `vbmeta_system` — matches our 1759622400 finding),
  rebuild vbmeta. Bundled AOSP test-key specs (avbtool-rs) — no external key file needed.
- **EDL ops**: **Convert X to XML** (decrypts official `.x` firmware — no more hunting for
  plaintext XMLs!), read/write partitions by GPT name, dump/flash whole LUNs, simple flasher.
- **Flash Firmware wizard**: region → target (same/other) → wipe/keep data → country code →
  folder → confirm → flash, "with region conversion and rollback handled end-to-end".
- **Boot Recovery** (System Updates tab): revives a region-converted device that won't boot
  after an OTA — directly relevant to our "Android side won't boot" state.
- **Root**: KernelSU / KernelSU Next / SukiSU Ultra / ReSukiSU / APatch / FolkPatch / Magisk.

Supported devices (wiki table): **Legion Tab Y700 3rd Gen (TB321FU): ZUI ≤ 17.5.10.170 supported**
— our ROW 17.5.10.031 is in-window. Cutoff = OTAs that replaced the ABL-embedded AvbRSAPublicKey.
2026+ hardware patched; Y700 5th Gen supported via a GBL/efisp exploit instead (unsigned code).
Since **v3.1.4** LTBox also handles the case where the TARGET firmware already fixed the test-key
vuln: backs up the device's current abl, converts region, re-signs only the needed AVB chain
partitions, flashes, then overlays the re-signed partitions and restores the backed-up abl.

### ✅ DEPLOYED 2026-08-08 (prebuilt tarball route)

Official prebuilt `LTBox-linux_x86_64-v3.2.2.tar.gz` (24 MB) → `~/.local/opt/LTBox-linux_x86_64-v3.2.2/ltbox`,
PATH symlink `~/.local/bin/ltbox` (`~/.local/bin` already on PATH). Install sequence:
1. Download + verify: `curl -sL .../releases/download/v3.2.2/LTBox-linux_x86_64-v3.2.2.tar.gz`
   + the `.sha256` file, `sha256sum -c`.
2. Extract to `~/.local/opt/` (works from any cwd; desktop entry records the absolute Exec path).
3. `./ltbox --install-desktop` → `~/.local/share/applications/io.github.miner7222.LTBox.desktop`
   + SVG icon (no root). Re-run if the binary is later moved.
4. `pkexec ./ltbox --install-udev` → **graphical auth popup on screen** (user must click OK) →
   `/etc/udev/rules.d/51-ltbox-qcom.rules` (Qualcomm 9008 EDL + Lenovo USB `uaccess`/plugdev
   grants, ModemManager opt-out). Non-root run prints the exact sudo/pkexec command.
5. GUI health check on Wayland: `timeout 8 ./ltbox; echo $?` → **exit 124 = ran until killed,
   healthy** (no crash output). Blank stdout is normal.

Chose prebuilt over `cargo build` because the machine had NO Rust toolchain and iced takes hours
to compile (user has since installed Rust — a source build is now possible, but the prebuilt
remains the fast path). Linux runtime deps (Debian): libusb-1.0-0 libudev1 libxkbcommon0 libxkbcommon-x11-0
libwayland-client0 libxcb1 libxcb-render0 libxcb-shape0 libxcb-xfixes0 libfontconfig1 xdg-utils
(installed before launch if GUI won't start).

### ⚠️ "Qualcomm kernel USB driver is missing" warning — FIX: userspace mode, do NOT install qud

LTBox on Debian defaults to `"qcom_driver_mode": "kernel"` in `~/.config/ltbox/settings.json`.
In kernel mode it checks for the **qud** package (Qualcomm USB Kernel Drivers,
github.com/qualcomm/qcom-usb-kernel-drivers) and warns "Qualcomm kernel USB driver is missing"
when absent. Investigation 2026-08-08:
- `qcserial`/`usb_wwan`/`usbserial` being loaded (`lsmod`) does NOT satisfy LTBox — it wants the
  qud package specifically.
- qud's release asset is a **source-compiled** package (`qud_1.0.6.5_all.zip` → `qud_1.0.6.5_all.deb`;
  Depends: build-essential, linux-headers-generic; postinst compiles modules for the RUNNING
  kernel). On a very new HWE kernel (e.g. 7.0.0-29) that compile is a real failure risk, and it
  needs root + reboot. Not worth it.
- **Correct fix**: edit `~/.config/ltbox/settings.json` → `"qcom_driver_mode": "userspace"`.
  Userspace mode uses libusb directly — the SAME transport the project's bkerler/edl chain has
  used successfully all along. LTBox docs: non-Debian defaults to userspace; switchable anytime
  in Settings → Qualcomm USB driver. No root, no compile, no reboot.
- Verify: relaunch LTBox (`timeout 10 ./ltbox` — blank stdout + exit 124 = GUI ran healthy), the
  dashboard banner should no longer demand the kernel driver. Kill leftover GUI instances with
  `pkill -f 'opt/LTBox.*ltbox'` (a test instance left running will linger past `timeout`).
- Keep the downloaded `qud_1.0.6.5_all.zip` in /tmp only if a future need for kernel-mode EDL
  arises; userspace covers EDL partition/LUN flash and .x→XML conversion fine.

## DynoBox (miner7222) — firmware re-signing CLI

github.com/miner7222/DynoBox (Rust, Apache-2.0, ~186 commits). For when LTBox's Flash aborts at
the LenovoRSA gate (`Flash: a LenovoRSA-key device only accepts same-region, non-downgrade
LenovoRSA-key firmware - aborting`): re-sign the firmware and replace its `abl` with an older
version → test-key vuln restored.
Commands: `dynobox resign` (re-sign/customize; flags `--boot-spl --vendor-spl --system-spl
--fuck-lgsi --debloat --plus`), `dynobox repack` (**rebuild split super images** — our super
concat/pad job), `dynobox info` (AVB metadata), `dynobox verify` (integrity; output manifests
record full-file SHA-256s), `dynobox integrity-keygen`.
**NOT deployed 2026-08-08** — CLI-only, needed only if LTBox actually hits the LenovoRSA gate.
Pull + compile it then, not proactively.

## TWRP for TB321FU — ✅ downloaded (we didn't have it)

polygraphene/android_device_lenovo_TB321FU — device tree + releases: **b0006 (TWRP 3.7.1_12)**,
portrait + landscape builds; /data decryption (gatekeeper + boot AIDL), work-profile decryption.
**Downloaded 2026-08-08 → `~/下载/刷机/05-工具链/TWRP/`** [该目录已随刷机数据清理 2026-08-10 删除；TWRP 不在保留固件内]
(`twrp-3.7.1_12-TB321FU-b0006-{portrait,landscape}.img`, 100 MB each, `file` = "Android bootimg" ✓).
**Release tag is literally `b0006`** (not the long release title) — assets are listed under
`releases/expanded_assets/b0006`.
Flash: `fastboot flash recovery twrp-....img` — BUT on this device fastboot flash is untrustworthy
→ EDL `edl.py w recovery_a <img>` preferred. TWRP caveat: flashing system from its GUI does NOT
resize partitions (bigger image fails; smaller may corrupt AVB footer) — use **fastbootd** for
system (auto-resizes). Sibling trees: TB320FC (gen2), TB322FC (gen4).

## XDA / community status (2026-08-08)

- **CN region is now ZUXOS, not ZUI**: "Row is zui, cn is ZuXOS now" (hitin911). CN firmware seen:
  `TB321FU_ZUX_1.5.10.106` (official Lenovo server link in XDA 4775810), 1.5.10.109 (paywalled CN
  filehost 123云盘), plus older `ZUX_1.1.10.138` / `ZUI_16.1.10.027` / `16.1.11.187_UNOFFICIAL` in
  XDA 4706488. Region-conversion targets for the CN side should use ZUXOS builds now.
- XDA 4706488 (CN Stock Firmware) reconfirms: **prog_firehose_ddr.elf does NOT work on TB321FU —
  must use xbl_s_devprg_ns.melf** (we already use this); default contents.xml references
  non-existent images (vm-bootsys) → needs hitin911's modified one.
- XDA 4742843 (GSI/Custom rom/Root, NindoS): success path = ROW ZUI 17 + **do NOT disable AVB**
  (system unbootable otherwise) + erase system + flash GSI + wipe userdata; "if any GSI boots with
  DSU, it's possible to flash"; DT2W = `echo 1 > /proc/gesture_control`. Consistent with our GSI
  conclusions (AVB disable irrelevant/not the fix).
- XDA 4775810 (hitin911 ZUXOS thread, 47 replies / 10K views) — official CN full-package links.
- bkerler/edl still actively maintained (652 commits, ©2026) — local copy from 2026-05-14 can
  `git pull`.

## Deployment techniques that generalize (learned this session)

- **iced / Rust-GUI binaries swallow `--help`**: `ltbox --help` exits 0 with NO output. Discover
  hidden CLI flags with `strings <bin> | grep -iE 'install|udev|desktop'` instead.
- **GitHub API rate-limit escape**: when `api.github.com` 403s (shared-IP rate limit), scrape the
  HTML release pages: `curl -sL <repo>/releases/latest` → follow the redirect for the tag name;
  `curl -s <repo>/releases/expanded_assets/<tag>` → `grep -oE 'href="[^"]*download[^"]*"'` for
  asset URLs. Tags containing spaces must be URL-encoded (`%20`); if expanded_assets is empty,
  grep the main releases page for `/releases/tag/<tag>` links to discover the real short tag.
- **GUI health check without a display**: `timeout 8 <app>; echo $?` — 124 = survived until
  timeout (healthy); any other exit = startup crash.
- **Verify downloaded firmware/recovery images** with `file <img>` (expect "Android bootimg")
  before flashing or archiving.

## Notes for the next work session

- LTBox's "Flash Firmware" wizard is the most promising ready-made path for the Android-side boot
  failure (region + rollback + EDL in one flow; "Boot Recovery" covers post-OTA non-boot states).
  Start it with the tablet in ADB/Bootloader/EDL and read the Dashboard (model/RAM/slot/rollback/
  firmware) before choosing a wizard.
- ✅ DONE same day: LTBox deployed, TWRP downloaded, `00-资源总览.md` 工具链/社区资源 sections
  updated (rows for LTBox/DynoBox/TWRP + new XDA links). DynoBox intentionally left undeployed.
