# #621 GRUB `gfxterm` 字号有**硬上限**：≥40 列 × ≥12 行，否则整块终端退回 EFI 文本模式

> 索引行见 `PITFALLS/README.md` 第 276 行。首次取证：2026-11-12（QEMU 逐档实测 + 反汇编 `gfxterm.mod` 定判据）。
> 相关：`#620`（「菜单能显」≠「内核能显」）。

## 一、结论（先看这 5 行）

| 项 | 结论 |
|---|---|
| **现象** | 换大号 pf2 后菜单**没有变**，或干脆退回 EFI 文本模式（80×24 小字），串口打出 `error: font: glyphs too large to fit on screen.` |
| **真判据（反汇编 `gfxterm.mod` `grub_gfxterm_set_window`）** | `cols = width / max_ascii_glyph_width`、`rows = height / font_max_height`；**`cols ≤ 39` 或 `rows ≤ 11` ⇒ `grub_error(23)` + 终端初始化失败**（`cmp #0x27` / `cmp #0xb`） |
| **换算** | 单调等宽字体 advance≈`0.602em`（DejaVuSansMono）⇒ 允许的字号 `size ≤ width/(40×0.602) ≈ width/24`；同时 `size ≤ height/(12×1.17) ≈ height/14` |
| **本机（3040×1904 / 1904×3040）** | 横屏上限 ≈ **126 px**；竖屏（1904 宽）上限 ≈ **79 px**。**160 px 物理上不可能**，与面板 dpi 无关 |
| **处置** | 分级降级：`loadfont big` → `if terminal_output gfxterm; then … else loadfont med; terminal_output gfxterm; fi`（GRUB 用命令返回状态做条件，**没有 `!` 取反运算符**） |

## 二、可复现的判据来源

```
# 1) 报错字符串只在 gfxterm.mod 里
strings build/grub-arm64/usr/lib/grub/arm64-efi/gfxterm.mod | grep "glyphs too large"
#    font: glyphs too large to fit on screen

# 2) grub_gfxterm_set_window 的关键三条指令（aarch64）
aarch64-linux-gnu-objdump -d gfxterm.mod | sed -n '/<grub_gfxterm_set_window>:/,/<grub_gfxterm_fullscreen>:/p' \
  | grep -E "cmp\s+w0, #0x27|cmp\s+w1, #0xb|udiv"
#    1028: udiv w0, w0, w21      ; cols = width / max_glyph_width（0x20..0x7e 取最大）
#    102c: udiv w1, w1, w2       ; rows = height / font_max_height
#    1034: cmp  w0, #0x27        ; cols <= 39 ?
#    1044: cmp  w1, #0xb         ; rows <= 11 ?
#    ⇒ 任一成立就 grub_error(23)，gfxterm 不接管终端
```

## 三、QEMU 冒烟台（本机可复用，**不需要设备**）

QEMU 的 `vitio-gpu-pci` 支持 `xres= / yres=`，可以把 GOP 直接做成真面板几何：

```bash
# 1) 用 fat: 伪设备把主机目录当 ESP，免 mount/免 root
mkdir -p /tmp/espdir/EFI/BOOT && cp grubaa64.efi /tmp/espdir/EFI/BOOT/BOOTAA64.EFI
qemu-system-aarch64 -M virt -cpu cortex-a72 -m 2048 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -drive file=fat:rw:/tmp/espdir,format=raw,if=virtio \
  -display none -device virtio-gpu-pci,xres=3040,yres=1904 \
  -monitor unix:/tmp/mon.sock,server,nowait -serial file:/tmp/serial.log -no-reboot &

# 2) 22 s 后从 monitor 抓屏（screendump 出 ppm，用 ffmpeg/PIL 转 png）
printf 'screendump /tmp/shot.ppm\nquit\n' | socat - UNIX-CONNECT:/tmp/mon.sock    # 或 python socket
```

判读：`gfxterm` 成功时**串口没有任何菜单输出**（画面走 GOP）；失败才回落文本模式并把菜单打到串口
⇒ **别用「串口里有没有菜单」判断成功**，必须抓屏或看 `glyphs too large` 是否出现。

实测档位（3040×1904）：40/72/96 px 通过；96 px 终端 ≈ 52×17；120 px 通过但只剩 ~4 行视口（菜单要滚动）。

## 四、本轮落地的最终配方（`out/grub-20261112/v3b-bigfont.cfg`）

```
loadfont (memdisk)/boot/grub/fonts/big.pf2      # 96 px
set gfxmode=3040x1904x32,1904x3040x32,1920x1200x32,1280x800x32,1024x768x32,auto
if terminal_output gfxterm; then
  true
else
  loadfont (memdisk)/boot/grub/fonts/med.pf2    # 72 px（竖屏 1904 宽可用）
  if terminal_output gfxterm; then
    true
  else
    loadfont (memdisk)/boot/grub/fonts/small.pf2 # 40 px（1024×768 兜底）
    terminal_output gfxterm
  fi
fi
```

字体进 memdisk 靠显式 `路径=源文件` 参数：`grub-mkstandalone … "boot/grub/fonts/big.pf2=/tmp/f96.pf2"`；
**`GRUB_FONT_SIZE` 那种「只生成到 FONTDIR」的做法在没有 `--clean` 时不会进 memdisk**（v2 件即因此一直跑在文本模式，
用户看到的「小字」其实是 EFI 文本模式，不是 pf2）。
