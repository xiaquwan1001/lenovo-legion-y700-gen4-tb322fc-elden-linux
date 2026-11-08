# 186 — GRUB/EFI 造件三坑：x86 发行版没有 arm64 模块、`strings` 验不了含中文的嵌入 cfg、判据通道自己没验证

日期：2026-11-08 · 线：G1-29 后半（启动菜单主机侧备料）· 正文：`reports/uefi-grub-menu-qemu-smoke-20261108.md`

## #556 x86 发行版**没有** arm64 GRUB 模块；但可以从 ubuntu-ports 的 arm64 deb 里解包交叉用；两个连带坑

**事实**：`apt-cache search grub-efi-arm64` 在本机（Ubuntu x86）**零结果**——`grub-efi-amd64-bin`/`ia32-bin` 有，
`arm64-bin` 不在 x86 源里（它是 arm64 架构包）。但**模块只是数据文件**：

```bash
curl -O https://mirrors.ustc.edu.cn/ubuntu-ports/pool/main/g/grub2-unsigned/grub-efi-arm64-bin_2.14-2ubuntu1_arm64.deb
dpkg-deb -x grub-efi-arm64-bin_*.deb root         # 得 root/usr/lib/grub/arm64-efi（244 个 .mod）
grub-mkstandalone -O arm64-efi -d root/usr/lib/grub/arm64-efi --modules="normal linux fdt ext2 …" \
  -o grubaa64.efi "boot/grub/grub.cfg=cfg"
```

**连带坑 1 — 别按想象的模块名写**：`efidisk.mod` **不存在**（GRUB 2.14 里磁盘驱动链已在 core/kernel 里，
`ls $MODDIR | grep -i efi` 只有 `efi_gop/efifwsetup/efinet/efitextmode`）。凭记忆写 `--modules "... efidisk ..."` ⇒
`无法打开 …/efidisk.mod` 直接失败。纪律：**先 `ls` 模块目录再写名单**。
（另：`qemu-system-aarch64 -drive file=fat:rw:<dir>` 的 vvfat 可当 ESP，免 root/免 `mformat`——
本机没装 mtools，这是唯一不需要 loop 设备的造 FAT 卷办法。）

**连带坑 2 — `strings | grep` 不能用来验证嵌入的 cfg**：`grub-mkstandalone` 的 memdisk 里 cfg 是**明文**，
但 cfg 里有中文（UTF-8 多字节）时 `strings` 只抓 ASCII 连续段，会把它截断 ⇒ 「marker 未命中」误报，
让人以为 cfg 没嵌进去。改判据 = **按字节搜 ASCII 令牌**（`python3 -c 'sys.exit(0 if b"set timeout=30" in blob and b"linux17" in blob else 1)'`）。

## #557 「判据通道自己没验证」又一次：GRUB 真把内核起来了，只是串口没输出

QEMU 第一次跑「设备形状」的 grub.cfg 时，倒计时结束**屏上什么都没有**，第一反应是「GRUB 没交接」。
真相：生成的 cmdline 是 `console=ttyGS0,115200 console=tty0`（设备上的 USB gadget 控制台 + 面板）——
QEMU virt 上既没有 `ttyGS0` 也没有面板 ⇒ **内核起来了但一个字都没地方打**。加 `console=ttyAMA0,115200`
后同一份 cfg 立刻打出 `Linux version 7.3.1-debug-vk184-…`。

教训：换测试载体（真机→QEMU）时，**先证「判据通道本身在这载体上有效」**（这里是「console 是否落在存在的 UART」），
再判「功能是否成立」；同族 = `#530`（屏显通道恒 NULL 却能藏很久）、`#551`（`/sys/fs/pstore` 空是假阴性）。
