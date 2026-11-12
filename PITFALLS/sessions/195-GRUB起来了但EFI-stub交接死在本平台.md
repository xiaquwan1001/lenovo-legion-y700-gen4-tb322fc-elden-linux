# 195 — GRUB 起来了、内核也被 PE 装载了，但 EFI-stub 交接在本平台死掉（且一点日志都没有）

日期：2026-11-08 · 线：G1-29 后半 · 正文：`reports/uefi-grub-esp-handoff-wall-20261108.md`

## #558 从 GRUB 走「EFI-stub 内核」在本平台会在 ExitBootServices 之后立即死，**四通道同时静默**

> ⚠️ **口径已收紧（2026-11-11/12）**：「EBS 之后**立即**死」不再成立——#617 实测内核在 EFI 路径下能走完数百个 `device_initcall`；「四通道同时静默」的真机制 = ramoops 落盘地址错（见 **#620** 第四节），即**通道没坏、取证面坏了**。本条保留价值 = R54 定向连接判据与 `CoreExitBootServices()` 尾巴两行的识别法。

**事实链**（屏照 + 下一次引导的对账）：
- R54 的定向连接有效：`[K] esp blk=120` / `fs=8` / `ld=Not Found i=0`（modem_b，绝不能被当默认项）/ `ld=Success i=1`。
- GRUB 2.14 菜单渲染出来；选中条目后 `[I] ? base=00000000C5D80000 size=03F40000`（= 63.4 MB 的内核 PE）。
- 紧接 **`DBI dump table info not found` + `App Log Flush : 0 ms`** —— 这两行是 Mu `CoreExitBootServices()`
   的 native 尾巴（同芯片项目 `external/ext-repos/sunuefi/docs/archive/linux-bringup/linux-efi-handoff-audit.md` 亦有记），
   即「内核的 EFI stub 确实调了 EB」，然后**再无任何输出**、整机复位。
- 四条取证通道同时空：面板无输出（`# CONFIG_SYSFB_SIMPLEFB is not set` ⇒ EFI 路径不注册 simpledrm/efifb）、
   SSH 90 s 不起（gadget 由 initramfs 起）、`ramoops` 无新记录（注册在 ~0.08 s，死在其前）、UEFI `ConOut` 是 no-op。
- 平台差异（与同芯片项目审查一致）：`PlatformMemoryMapLib.c` 里**只有 `DXE Heap`(0xB90C0000 +0x1D500000 ≈ 469 MiB) 是 Conv**，
   其余 DDR 全 `Reserv`；而 raw DT 声明 ~15 GiB ⇒ 走 EFI 时内核只看见几百 MiB。

**纪律/教训**：
- 「GRUB 菜单出来」「内核被 LoadImage」**都不能当作交接成功**；本线的成功判据只能是
  `/proc/cmdline` 里出现**只写在 ESP 侧配置里**的令牌 + `boot_b` sha 未变（见正文 §5）。
- 要在 EFI 路径上看内核早期输出，**必须先有 fbcon**：`CONFIG_SYSFB_SIMPLEFB=y`（本线当前未开）；
  否则一次失败只能靠人眼回忆，白烧一轮设备。
- 「BdsEntry 入口扫 SimpleFileSystem = 0」「入口 ConnectAll 会同步异常」「本平台 AfterConsole 不 ConnectAll」
  三条都已踩过，正确做法 = **对每个 BlockIo 句柄 `ConnectController(..., TRUE)` 再扫**（R54 现行实现）。
