# uefi-initrd-probe-20261115 — GRUB 路径 initrd 交接的内核侧取证件

## 用途

给「GRUB(arm64 standalone) → LoadFile2 → 内核 EFI stub → initramfs」这条链做内核侧取证：
在**内核读 initrd 的那一刻**采样内容（FNV-1a/8×4096，规则与 `scripts/lf2-expected.py` 逐字一致），
并在 panic 时用 panic_notifier 在栈底**重打一遍**（每行停 1.8 s，便于拍屏）。

## 内容

| 文件 | 作用 |
|---|---|
| `0001-initrd-probes-and-stub-prints.diff` | `build/daily` 工作区改动（5 文件）：`init/initramfs.c`（`elden_probe()` + `ELDEN[resv]/[unpack-in]/[unpack-out]/[diag]` + panic_notifier 重打）、`arch/arm64/mm/init.c`（`arm64_memblock_init()` 里打印 initrd 物理段与 `memblock.reserved` 重叠项）、`drivers/firmware/efi/libstub/{kaslr.c,efi-stub-helper.c}`（打印 KASLR 落点与 stub 给 initrd 分配的 buffer 地址） |
| `initramfs-dbg/init` | 诊断 init：**内建** initramfs（`CONFIG_INITRAMFS_SOURCE=/tmp/elden-dbg-initrd.cpio.gz`）里跑的脚本 —— 外部 initrd 解包失败时接管，等 `/dev/sda17`，把 `dmesg` 写 `/var/log/elden-uefi-probe.log`，然后 `poweroff -f`。**注意**：实测外部 initrd 解包失败会先毁掉 rootfs 里的 `/init` ⇒ 该通道在本例中被 `No working init found` 抢先，**未生效**（留档备后续用） |
| `arming-menu.cfg` | 上机用的嵌入菜单（大字：`big.pf2` 96 px + `gfxmode=3040x1904x32`；三条臂 = noramoops DTB / elden.dtb / 1 MB slim initrd） |

## 复现（主机侧）

```bash
# 1) 打进 build/daily（默认树指针）
git -C build/daily apply <此目录>/0001-initrd-probes-and-stub-prints.diff
# 2) 内建 initramfs（可选，用于解包失败后的持久化尝试）
mkdir -p /tmp/elden-dbg-initrd/{proc,sys,dev,mnt}; cp initramfs/busybox /tmp/elden-dbg-initrd/
cp <此目录>/initramfs-dbg/init /tmp/elden-dbg-initrd/init && chmod +x /tmp/elden-dbg-initrd/init
(cd /tmp/elden-dbg-initrd && find . -print0 | cpio --null -o -H newc | gzip -9 > /tmp/elden-dbg-initrd.cpio.gz)
sed -i 's|^CONFIG_INITRAMFS_SOURCE=.*|CONFIG_INITRAMFS_SOURCE="/tmp/elden-dbg-initrd.cpio.gz"|' build/daily/.config
rm -f build/daily/usr/{initramfs_data.cpio*,initramfs_data.o,.initramfs_inc_data}   # 不删不会重生成内建 initramfs
scripts/build-kernel.sh Image
# 3) 菜单件 + 装 ESP（ESP 满会「半成功」，装完必须核 sha，PITFALLS #664）
scripts/grub-arm64-arming-build.sh --cfg <此目录>/arming-menu.cfg --out out/grub-dbg.efi
scripts/esp-install-grub.sh --efi out/grub-dbg.efi --tag dbg --activate
```

判据：`ELDEN[unpack-in] sum=0x5c53688e tail=8eff7f5eb9feff01db29f8bf008ad60a` = 与主机期望值逐字相同。

## 结论（2026-11-15）

见 `reports/uefi-grub-initrd-rootcause-20261115.md`：**Mu UEFI 把 initrd buffer 分配在 DTB 的
`ramoops@c2000000`（8 MB, no-map）保留区内，内核 ramoops 控制台/环形缓冲在 t≈0.027 s 起就往那里写，
把 initrd 中间几 MB 覆盖掉** ⇒ `broken padding`。删掉 ramoops 节点的 DTB 一发生效（起进 SSH）。
