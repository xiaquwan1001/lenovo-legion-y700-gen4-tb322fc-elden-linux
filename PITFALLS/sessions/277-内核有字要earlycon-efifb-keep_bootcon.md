# #622 UEFI 路径上「内核有字」的充要条件 = `earlycon=efifb keep_bootcon`；打开 `SYSFB_SIMPLEFB` 单独不够

> 索引行见 `PITFALLS/README.md` 第 277 行。取证：2026-11-12 上机 A/A2 双条目对照（用户屏上截图 7 张，我读原图判读，未用 OCR）
> + `grubenv` 机器可读留痕交叉核对。相关：`#620`（判读作废）、`#621`（GRUB 字号上限）。

## 一、结论（先看这 5 行）

| 项 | 结论 |
|---|---|
| **A 臂**（`SYSFB_SIMPLEFB=y` 的 vk188，cmdline 只有 `console=ttyGS0 console=tty0`） | **全程无字**：0 s→37 s 屏上只有背光/白 |
| **A2 臂**（同一内核，cmdline 加 `earlycon=efifb keep_bootcon`） | **从 `0.000000` 就有字**，一路滚到 `37.09 s` 的 `Freeing initrd memory` |
| **机制** | `simpledrm`/`fbcon` 接管 EFI framebuffer 的时刻**远晚于** `start_kernel`，且 `msm` DPU/DSI probe（~9 s）接管显示控制器后，**GOP 那块 buffer 不再被扫描出屏** ⇒ 只有 `earlycon`（直接往 EFI fb 写）能保证「最早 + 持续」可见；`keep_bootcon` 防止 bootconsole 在正式 console 注册后被摘掉 |
| **判据纪律** | 「`SYSFB_SIMPLEFB` 开了 ⇒ 能看见内核日志」**不成立**。要取证一律带 `earlycon=efifb keep_bootcon` |
| **配套纪律** | 想知道「是 panic 还是挂死」，把 `panic=0` 写进 cmdline；`panic=15` 会让它在十几秒后自动重启，**看起来和掉电一模一样**（本夜「十多秒掉电」就是这个） |

## 二、证据（A2 屏上原文，逐字）

```
Kernel command line: BOOT_IMAGE=(hd5,gpt17)/boot/Image console=ttyGS0,115200 console=tty0
  earlycon=efifb keep_bootcon loglevel=8 ignore_loglevel printk.devkmsg=on panic=0
  clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17
  androidboot.slot_suffix=_b elden_nocamera=1 root=LABEL=linux17 elden_bootmenu=grub-A2
[ 4.577892] pstore: Registered ramoops as persistent store backend
[ 4.716631] ramoops: using 0x800000@0xc2000000, ecc: 0          ← A2 用 no-console-size 变体 DTB，没再注册 ramoops console
[ 7.6 …11.6 s] /soc/...: Fixed dependency cycle(s) …            （已知噪声，不是错）
[ 15.220839] Unpacking initramfs...
[ 31.057583] Initramfs unpacking failed: no cpio magic           ← 见 #623
[ 37.092797] Freeing initrd memory: 63104K
```

命令行走的是 `(hd5,gpt17)/boot/Image`（= linux17 的 ext4，GRUB 的盘号），可用来确认「真正被加载的是哪一份 Image」。

## 三、机器可读通道（不拍屏也能知道走到哪）

**GRUB 阶段** = 把标记写进 `/boot/grub/grubenv`（ext4 env 块，`save_env -f …`）：

```
set elden_grub_log="11-A2-selected"; save_env -f ($root)/boot/grub/grubenv elden_grub_log
# 每步 ok/FAIL 各写一条：11-A2-dtb-ok / 11-A2-linux-ok / 11-A2-initrd-ok-booting / 1B-A2-*-FAIL
```

Linux 起来后 `cat /boot/grub/grubenv` 直接读。**实测有效**：A2 崩掉回落到 b 槽后，文件里留下
`elden_grub_log=11-A2-initrd-ok-booting` —— 「GRUB 确实跑到 A2 且三件都装上了」是文件证据，不是拍屏推测。

**内核阶段** = `console=ttyGS0` 的 USB gadget（`/dev/ttyACM0`）—— 但**只在 initramfs 跑起来之后**存在，
且 `scripts/serial-logger.sh` 那种 `cat &` 循环在本机 **open/close 狂抖**（每秒几十次、真数据一行不留）。
改用 `scripts/serial-tap.py`（一次 open 长期持有 + select + 断线重开一次，pty 冒烟已过）。

**UEFI/GRUB 阶段没有串口**：本板 `ttyGS0` 是 Linux gadget；物理 UART 未接线。所以 GRUB 的字**只能上屏**——
这也是为什么把它写进 `grubenv` 比换串口更实际。

## 四、可复用的取证配方

```bash
# 1) GRUB 菜单/字体：QEMU 里 30 s 一轮（配方见 PITFALLS 276 号条目）
# 2) 内核早期日志：条目里必须带
#    earlycon=efifb keep_bootcon panic=0 loglevel=8 ignore_loglevel
# 3) 判定「GRUB 走到哪」：cat /boot/grub/grubenv
# 4) 判定「内核跑没跑」：ping 192.168.7.1 / ls /dev/ttyACM* / fastboot devices
#    三者全空 = 内核没到 userspace（不是"掉电"，panic=0 时会一直挂着）
```
