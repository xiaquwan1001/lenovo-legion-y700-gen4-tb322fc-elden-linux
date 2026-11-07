# 2026-11-07 深夜：EB 之后「缓存 BlkIo 写盘」结构性不可用；arm64 外部模块必须显式 ARCH

- 日期：2026-11-07（深夜）
- pi 会话 id：见 `.pi/sessions/`
- 主题：UEFI（G1-29）打通内核交棒的过程中定案的两条硬事实
- 结论：① `ExitBootServices()` 之后 `BlkIo->WriteBlocks` 读出 0 ⇒ `blr 0`；EB 后**任何**用缓存协议
  实例的写盘都不可行，EB 后取证只能靠屏/共享环；② 在 x86_64 宿主上给 arm64 内核编外部模块**必须**
  显式 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`，否则 Kbuild 按 `uname -m` 选 `arch/x86`。
- 证据指针：`reports/uefi-p46-kernel-boot-success-20261107.md` §2/§3/§5、
  `reports/artifacts/uefi-p46-boot-success/ring-0xE3F80000-32k.bin`、
  `patches/uefi/20261107R41-noebdump/`
- ★SSOT 待并入：`PITFALLS/README.md` #546（已并入）

## #546 EB 之后缓存的 `BlkIo` 协议实例已失效：`WriteBlocks` 读出 0 ⇒ `blr 0`

- **现象**：p45 屏上 `[K] posteb-go` 之后 `[K] FLT pc=00000000 esr=86000007`（IABT），
  `x03=00004000`、`x04=<静态缓冲指针>`；p46 删掉这次转储后，同一路径**一路走通并起了内核**。
- **归因**：`SbDumpLogNoBs()` 内联 `SbWriteLogWindowNoBs()`，`0x4c14: blr x9`，
  `x9 = ldr [x20, #0x20]` = `EFI_BLOCK_IO_PROTOCOL.WriteBlocks`。EB 之后该字段为 **0**。
- **机制**：`ExitBootServices()` 释放 boot-services 拥有的内存并卸载非 runtime 映像 ⇒
  R32 缓存的 `BlkIo`（`m_SbLogBlkIo`）指向的协议实例失效。**不是补丁能修的**。
- **纪律**：
  1. EB 之前的落盘（`preeb`）照旧可用（p45 实测 `dump-tag=preeb cached=Success` + `preeb-ok`）；
  2. EB 之后的取证只走**屏**（R39 屏显标记 + R40 不清屏）或**共享环**（`0xE3F80000`，用
     `blackbox.ko` 从 Linux 侧读回）；
  3. 任何「EB 之后仍能持久化」的假设，必须先证明该协议实例/缓冲区**不是** BS 内存。

## #546b（同文件，编号沿用 #546 的说明）arm64 外部模块在 x86_64 宿主上要显式 `ARCH`

- **现象**：`make -C wt/reb-731 M=/tmp/bbmod modules` 报
  `include/linux/compiler_types.h:187: fatal error: asm/compiler.h: 没有那个文件或目录`。
- **根因**：Kbuild 按宿主 `uname -m` 推 `SRCARCH` ⇒ 走了 `arch/x86/include...`，
  而 `arch/arm64/include/asm/compiler.h` 自然找不到。
- **修法**：`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -C <kdir> M=<moddir> modules`
  （跨架构编模块时 `ARCH` 不能省；只编内核本体时项目脚本已带）。
- **旁证**：`-I` 列表里一旦出现 `arch/x86/include`，就是这个坑（`V=1` 可直接看）。

## #547 UEFI 路径的 cmdline 来自 `boot_b` 头部，不是 `fastboot boot` 那份 boot.img

- **现象**：p45/p46 的镜像是用 `scripts/uefi-sbstop-patch.py` 加了 `sbstop=26 sbprobe=3` 前缀的件，
  但内核起来后 `/proc/cmdline` 里**没有**这些前缀，也没有 `elden_early_gadget` 之外的改动痕迹。
- **根因**：UEFI 侧的 `LinuxLoader` 读的是 **`boot_b` 分区里 boot.img 头部的 cmdline**，
  再经 `UpdateCmdLine()` 追加 `androidboot.*`/`elden_root=` 等；我们 `fastboot boot` 送进去的是
  **UEFI 载荷本身**，它的命令行只对 UEFI 生效，传不到内核。
- **纪律**：
  1. 走 UEFI 路径时，`sbstop=N` / `sbprobe=N` 这类「改内核行为」的令牌**一律无效**，
     要改行为得改 `boot_b`（写盘）或改 UEFI 侧代码；
  2. 判断「内核从哪条路起来」时，`/proc/cmdline` 不足以区分 UEFI 与 ABL（两者都会注入
     `androidboot.*`）⇒ 用**自家探针**（DDR 共享环 `0xE3F80000` / `logfs` 里的 `[K]` 链）；
  3. `boot_b` 的内核身份可用 `uname -r` 对齐 `out/boot-elden-<vk>.manifest` 的 `kernel_release`
     （注意 vk 标签与 uname 里的 `vk1xx` 可能不同号：`vk185-adsp` 的 uname 是 `vk184-…`）。
