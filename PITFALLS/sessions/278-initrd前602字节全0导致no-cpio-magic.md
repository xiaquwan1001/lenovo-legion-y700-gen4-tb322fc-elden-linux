# #623 initrd 前 602 字节全 0 ⇒ `Initramfs unpacking failed: no cpio magic` ⇒ 没有 initramfs、没有 USB gadget/SSH

> 索引行见 `PITFALLS/README.md` 第 278 行。取证：2026-11-12 屏上日志（#622 的 A2 发）+
> 主机侧对 `out/ramdisk-vk181-daily.cpio.gz` 的字节分析。相关：`#622`。

## 一、结论（先看这 5 行）

| 项 | 结论 |
|---|---|
| **现象** | 内核 `[31.05 s] Initramfs unpacking failed: no cpio magic`，`[37.09 s] Freeing initrd memory: 63104K` 后无 init ⇒ **没有 `/init`、没有 usb-gadget、没有 SSH、没有 ttyGS0** |
| **根因** | `out/ramdisk-vk181-daily.cpio.gz`（64 595 425 B）**前 602 字节是 0x00**，真正的 gzip 流从偏移 602 开始（`1f8b0800`）⇒ 内核按「非 gzip/非 cpio」判定 |
| **不是解包脚本的锅** | 该前缀**就在 boot.img 里**（v2 头 `ramdisk_size` 段首字节也是 0）⇒ 源文件本身坏了 |
| **为什么 b 槽还能正常启动** | b 槽用的是 `boot_b` 里**早就烧进去的另一份 ramdisk**，与 `out/ramdisk-vk181-daily.cpio.gz` 无关 ⇒ 「b 槽能起来」**不能**证明这个 ramdisk 可用 |
| **处置** | 换 `out/ramdisk-vk181-working.cpio.gz`（**同一尺寸 64 595 425 B，偏移 0 = `1f8b`**，`gzip -t` 通过、解压 181 832 192 B、内层 `070701` newc cpio）；已重打 `out/boot-elden-vk188b.img`，并按 GRUB 路径把 `/boot/initrd.img` 换成该文件（旧件留 `initrd.img.zeros602.bak`）。**待上机验证** |

## 二、判据（贴进任何「initrd 能不能用」的检查）

```bash
# 必须命中第一条；第二条必须静默
head -c4 FILE | xxd -p            # 期望 1f8b0800（gzip）或 070701（newc cpio）
gzip -t FILE && echo gzip-ok      # 失败 = 流被截断/前缀污染
python3 -c "import sys;d=open(sys.argv[1],'rb').read();print('first-nonzero',next((i for i,b in enumerate(d) if b),None))" FILE
#   ↑ 期望 0；非 0 就是本坑（602 那次就是这个）
```

## 三、影响面与教训

- 任何「GRUB 直启」（`/boot/initrd.img`）只要用了这份坏文件，**必然没有 userspace**；
  症状是「屏上滚到 Freeing initrd memory 就没了 / 或者干脆黑」，很容易被误判成「内核死了」。
- 反过来也给了一条干净的判据：**看到 `Initramfs unpacking failed` 就不用再查显示/驱动**，
  因为连 `/init` 都没有，后面的 SSH/串口必然全空。
- 本轮同时确认：`Initramfs unpacking failed` 之后内核**不会** panic（`panic=0` 下会继续找 `root=LABEL=linux17`），
  所以「没网、没串口、屏也不动」三件事同时出现时，先看有没有这一行。
