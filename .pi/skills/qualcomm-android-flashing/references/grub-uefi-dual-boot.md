# TB321FU (Lenovo Legion Y700 Gen3) — dual-boot reference

Device-specific notes from the 2026-08 working session. Companion to SKILL.md; use the class-level playbook for mechanics.

## Device facts
- Lenovo Legion Y700 Gen3 (2025), TB321FU, Snapdragon 8 Gen 3 (SM8650), codename `kirby`, UFS, 256GB model.
- Bootloader unlocked via `fastboot flash unlock sn.img` (Lenovo tool generates sn.img) or one-click unlocker (XDA 4746935).
- `fastboot getvar product` -> `kirby`; `factory-mode:1`; `parallel-download-flash:yes`.
- Real partition table (107 partitions, from `fastboot getvar all`, hex sizes):
  - userdata 218.47 GiB (234585665536 B), super 13.00 GiB (13958643712 B — exactly the size of the community GRUB FAT image)
  - boot_a/b, vendor_boot_a/b: 96 MiB each (100663296); init_boot_a/b: 8 MiB; recovery_a/b: 100 MiB; dtbo_a/b: 24 MiB; vbmeta_a/b: 64 KiB
  - No system/vendor/product partitions — they are dynamic inside super.

## Resource URLs (all verified reachable)
- Firmware mirrors: `mirrors.lolinet.com/firmware/lenowow/2024/Y700_2025/TB321FU/` (ROW) and `.../TB321FU_CN/` (CN). ROW 17.5.10.031 zip = 6,996,426,996 B.
- Engineering loader: inside every package at `image/xbl_s_devprg_ns.melf` (ROW 17.5.10.031 copy: 1,569,028 B, sha256 8cfc8c43...). Direct mirror: `archive.diablosat.cc/firmwares/amt-dumps/FirehoseLoaders/xbl_s_devprg_ns.melf` (1,551,412 B, older build). Loader index: temblast.com/ref/loaders.htm.
- XDA threads: hard-brick EDL recovery 4776965 (xbl_s_devprg_ns.melf + fixed contents.xml attachment 6172722); CN stock firmware 4706488 (Google Drive TB321FU_ZUI_16.1.10.027.7z); CN->ROW guide 4744907; bootloader unlocker 4746935.
- EDL guides: sites.google.com/view/qfilflash (JP), note.com/forsaken_love02/n/n088953566fb2, note.com/limzei89.
- TWRP: github.com/polygraphene/android_device_lenovo_TB321FU (b0006, portrait/landscape). Gen4 sibling repo (TB322FC) documents qdl-rs usage.
- LTBox: github.com/miner7222/LTBox — GUI flashing/root/region conversion; needs `xbl_s_devprg_ns.melf` in image/ folder; gen3 supported (2.1.7 recommended); Linux build available.

## GUF296 GRUB boot chain (ubuntu-y700-build-ci)
Repo: github.com/GUF296/ubuntu-y700-build-ci — GitHub Actions CI building Ubuntu rootfs + GRUB boot images for TB321FU.
Boot chain: ABL (UEFI) -> boot_a/b boot.img -> GRUB -> FAT partition -> `linux /Image` with `devicetree /dtb/sm8650-lenovo-tb321fu.dtb`, kernel args `root=PARTLABEL=userdata rw rootwait` (default) + stable args `drm_client_lib.active=none`.
- UEFI boot.img: Android boot image **header v3**, kernel section = **gzip'd GRUB EFI** (starts 1f 8b 08), **no ramdisk**, total size 100,663,296 = exactly boot_a/b size. Committed in repo at `source/boot-image/boot.img.7z` (2.4 MB).
- FAT image (default `BOOT_IMAGE_SIZE=14G`, label Y700GRUB): /Image (kernel ~56 MB), /dtb/sm8650-lenovo-tb321fu.dtb + /dtb/platform.dtb, /EFI/BOOT/BOOTAA64.EFI (outer GRUB), /EFI/BOOT/QCOMRAMP.EFI (direct-boot GRUB built with grub-mkstandalone, custom modules: `normal linuxdirect fdt fat part_gpt search search_fs_file reboot halt sleep rampartition`), /EFI/BOOT/grub.cfg + qcomramp.cfg, /boot/grub/arm64-efi/grub.cfg (daily menu).
- Release assets: boot.img.7z (UEFI), grub.img.7z, rootfs.img.7z; kernel artifacts release `bootstrap-y700-20260625` (kernel 7.1.1).
- Build script env knobs: BOOT_IMAGE_SIZE, BOOT_FAT_LABEL, ROOT_SELECTOR=partlabel|uuid|raw, ROOT_PARTLABEL, ROOTARGS, STABLEARGS, KERNEL_IMAGE, DTB_FILE, BOOTAA64_EFI(_URL), QCOMRAMP_EFI(_URL), GRUB_TIMEOUT.
- Rootfs script knobs relevant to desktop changes: `INSTALL_FCITX5_CHINESE` (default 1; fcitx5 suite incl. kde-config-fcitx5 — breaks Plasma Wayland virtual keyboard on touch), `DESKTOP_ENV` (default plasma-desktop), SDDM_AUTOLOGIN[_SESSION], `INSTALL_GNOME_SNAPSHOT`, sensor/haptics deb archives.

## Dual-boot design (adopted by user)
- super 13G -> restored from ZUI package `super_1.img..super_8.img` (split sparse; Android dynamic partitions) — Android (pixel GSI: Pixel-komodo-16_ext4_raw_Signed_V5.img = AVB-test-key-signed system image) keeps running.
- userdata 218.47G -> shrink to ~96G via GPT rewrite (EDL printgpt -> sgdisk rebuild -> write back; or QFIL w/ decrypted rawprogram).
- New partitions: `ubuntu` (ext4, ~96G, root=PARTLABEL=ubuntu) + `grubfat` (FAT32, 1G, label Y700GRUB, rebuilt with ROOT_PARTLABEL=ubuntu).
- boot_a = pixel boot.img; boot_b = GUF296 UEFI boot.img; switch via `fastboot set_active a|b` / `bootctl set-active-boot-slot b`.
- vbmeta: `fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img` (or AOSP-test-key signing; ABL trust cutoff ZUI 17.5.10.170 — current ROW 17.5.10.031 is inside).

## Local project layout (user machine)
`~/下载/刷机/`: [2026-08-10 已清理并归档——目录内容已删除，仅保留四份固件压缩包于 `~/下载/刷机-保留/archive/`，见其中 `归档索引.md`] `zui` = ROW 17.5.10.031 zip (6.99G, 已归档 ROW_ZUI.tar.zst), `pixel_pkg/` ..., `grub_extract/` ..., `y700-super-13G.img` (13G FAT32 label Y700BOOT — local GRUB FAT build), `make_fat.py` ..., `build-rootfs-image.sh` ..., `EDL/` ..., `guf296/` ...
