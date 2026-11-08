# 189 — 路线 B（ESP-first）打通路上踩到的三个坑：`BootIntoFastboot` 写死、`extra_cmdline` 不生效、面板不是证据通道

日期：2026-11-08 · 线：G1-29 · 正文：`reports/uefi-espboot-r58b-success-20261108.md`

## #565 本树 `LinuxLoader` 把 `BootIntoFastboot = TRUE` **写死**，`fastboot boot` 起的 UEFI 件永远进不了 `BootLinux`

- 代码位置：`Platforms/QcomModulePkg/Application/LinuxLoader/LinuxLoader.c:295` —— `GetKeyPress` 那段被注释掉后，
  留下**裸的** `BootIntoFastboot = TRUE;`（不在任何 `if` 里）。
- 后果：用 `fastboot boot <uefi.img>` 上机时，`if (!BootIntoFastboot)` 整块被跳过 ⇒
  `LoadImageAndAuth()`/`BootLinux()` **一次都没执行**。历史记录里的「漏发 `fastboot continue`」正是它的表现层。
- 判据（机器可读）：在入口/各阶段写日志，出现 `bootfastboot 1` → `to-fastboot` 而**没有** `pre-auth` 即命中。
- 实验处置：ESP 上放开关文件（本项目 `\espboot.force`），存在即强制 `BootIntoFastboot = FALSE`。
  **只能用于实验**；正式落地必须改那行写死赋值或走正常启动路径，别把开关当产品。

## #566 `extra_cmdline`（boot.img 头偏移 **608**）不会被 Mu 拼进内核 cmdline ⇒ 令牌必须写**主 cmdline**（偏移 64）

- 本平台 Mu 的 `boot_img_hdr_v0` 用 `UINT32 id[8]`（32 B），所以 `extra_cmdline` 在 **608**；AOSP 的 `id[8]` 是 8 B ⇒ 584。
  本项目 `scripts/mkbootimg.py` / `scripts/grub-bootfiles.sh` 都用 608，与 Mu 一致。
- 但实测：令牌写在 extra 区时，`/proc/cmdline` **干净无令牌**；改写到主 cmdline（64..576，512 B 内）后立刻出现。
- 纪律：**判据令牌一律写主 cmdline**（并核对 `cat /proc/cmdline`），别假设 extra 会被拼上。

## #567 面板（`SerialPortWrite`）**不是**可靠证据通道；掉电也不丢的证据 = 落盘到 ESP 的日志文件

- 同一份 loader（R56）某一发能在面板打出 `[E] esp …`，另一发直接 `ASSERT String.c +37` 然后掉电 ⇒ 面板通道随时可能没。
- 做法：在**入口第一件事**打开自身卷上的日志（`\loader.log`），每个阶段 `Write`+`Flush` 一行；
  失败也会留在 FAT 上，重启回 Linux 后 `mount` 一下 `cat` 即可 —— 两发之内就把「哪一步没执行」定位了。
- 连带坑：想「先删旧日志再建新的」时，`Root->Open(Root, NULL, path, READ|WRITE, 0)` **并不会删除**文件
  （要拿句柄再 `File->Delete()`）⇒ 日志可能残留上一发内容，误判成「这一发写过」。**每次上机前先从 Linux 侧 `rm` 掉**。
