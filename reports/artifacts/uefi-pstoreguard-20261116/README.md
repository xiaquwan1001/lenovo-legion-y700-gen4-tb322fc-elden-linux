# uefi-pstoreguard-20261116 — pstore 守卫真机验证证据

- `dmesg-guard.txt`：a 槽 UEFI/GRUB 路径起进系统后的完整 dmesg（守卫 4 行在 267–270 行、`Unpacking initramfs` 在 462 行）。
- `guard-summary.txt`：cmdline / uname / uptime / 守卫行 / pstore / 四个件 sha / grubenv。
- `arming-pstoreguard.cfg`：本轮自打的嵌入菜单（G1 = `elden.dtb` 含 ramoops；G2 = `elden-noramoops.dtb` 对照）。
- EFI 不入库（9.5 MB，可重建）：`scripts/grub-arm64-arming-build.sh --cfg out/grub-arm64-arming-20261116/arming-pstoreguard.cfg --out <out>`；
  真机验证时装的那一枚 sha256 = `cc6391b3…`（全值见 `DEVICE/README.md` §1.1）。
- 账：`reports/pstore-ram-initrd-guard-20261116.md` §5。
