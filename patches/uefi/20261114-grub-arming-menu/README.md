# 2026-11-14 UEFI 复测用的 GRUB 嵌入菜单（arming）

**为什么有它**：ESP 上的 `\EFI\BOOT\BOOTAA64.EFI`（v3b-bigfont，sha `244c5f65…`）是**嵌入菜单件**，
二进制里含 6 个 `menuentry`、**不含** `configfile …/boot/grub/grub.cfg` 桩 ⇒ **改 linux17 的
`/boot/grub/grub.cfg` 对 a 槽启动无效**（2026-11-14 只读复核定案）。要换默认臂只能重打 EFI。

**改了什么**（相对现役 v3b-bigfont）：
- `default=0` = **A2' 臂**：真 DTB（`elden.dtb`，不是 `nopstorecons`）+ `earlycon=efifb keep_bootcon` + `panic=0`；
- 每步写 `/boot/grub/grubenv` 的 `elden_grub_log`（`31-A2p-*` / `3A-*FAIL`）⇒ 不拍屏也能判「GRUB 走到哪」；
- 保留三档字体自动降级（96/72/40 px，`PITFALLS #621`）、`A2 panic=15` 对照臂、`A 基线（无 earlycon）` 单变量对照、
  `D Loader.efi` 链式对照、`reboot`/`poweroff`。

**构建/装机**：
```sh
scripts/grub-arm64-arming-build.sh          # → out/grub-20261114/grubaa64-arming-v6.efi（自校验 PE/menuentry/字体）
scripts/esp-install-grub.sh --efi out/grub-20261114/grubaa64-arming-v6.efi --tag arming-v6 --activate
# 回滚：scripts/esp-install-grub.sh --rollback（或把 BOOTAA64.EFI.v3b-restore.bak 拷回去）
```

**自校验实测**：`machine=0xaa64 menuentry=6 size=9527296`，sha256
`45632c799aa2b679a300f6e5e1a635ce6a26210a20510f91915504b0b0cc209d`。

**未上机**（2026-11-14 21:5x：隔壁项目 13 个孤儿 `fastboot` 进程抢 USB，设备通道不可用）。
