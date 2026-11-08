# G1-29 后半：ESP + GRUB **菜单已出来、EFI-stub 交棒撞墙**（2026-11-08）

> 线：G1-29（拓展，非主线）。设备 = U2 `HA2EXB0E`。本轮**已写盘**（用户批准）：新建 ESP、写 `/boot`。
> 结论：链路的**前半段全部成为事实**（ESP→GRUB→菜单→LoadImage 内核），
> **后半段（EFI-stub 内核交接）在本平台失败**，且与同芯片另一项目记录的墙一致。

---

## 0. 四张屏照给出的硬事实（这一节是全部证据）

```
[K] esp blk=120                    ← R54 连接了 120 个 BlockIo 控制器
[K] esp fs=8                       ← 之后看到 8 个 SimpleFileSystem
[K] esp ld=Not Found i=0           ← i=0 是 modem_b 那个 FAT（必须不能自动启动）
[K] esp ld=Success i=1             ← i=1 = 我们的 ESP：LoadImage 成功
GNU GRUB  version 2.14             ← 菜单渲染出来（条目：Elden Linux / initcall_debug / UEFI / 关机）
[I] ? base=00000000C5D80000 size=03F40000   ← 63.4 MB = 我们的 /boot/Image 被当作 PE 映象装载
DBI dump table info not found, Status = (0x0)
App Log Flush : 0 ms
（随后整机复位/掉电）
```

- `DBI …/App Log Flush` 这两行出自 **Mu `CoreExitBootServices()` 的 native 尾部**
  （见 `external/ext-repos/sunuefi/docs/archive/linux-bringup/linux-efi-handoff-audit.md`）⇒
  **内核的 EFI stub 确实调用了 ExitBootServices**，之后就再没有任何输出。
- 之后：**SSH 90 s 未起、fastboot 不应答**；下次正常引导后 `/var/lib/systemd/pstore/` **没有新记录**
  ⇒ 内核连 `ramoops` 注册（约 0.08 s）都没到。
- `boot_b` sha 全程未变（`4e38bc2c…`）；两次失败后都靠 R54 的 fallback（LinuxLoader）自动回 Linux。

## 1. 为什么一点内核日志都看不到（这条决定了怎么继续）

| 通道 | 为什么没有 |
|---|---|
| 面板 console（fbcon） | 内核配置 `# CONFIG_SYSFB_SIMPLEFB is not set` ⇒ EFI 路径下 simpledrm/efifb **不注册**，tty0 无后端 |
| USB gadget（ttyGS0/ssh） | gadget 由 initramfs 起；内核没跑到 |
| `ramoops`/pstore | 注册在 ~0.08 s，早于此就死了 |
| UEFI 侧屏显 | `ConOut` 在本平台是 no-op（`PITFALLS #514/#515`），我们只能在 DXE 里用 `SerialPortWrite` 直涂面板 |

⇒ **要看内核早期死亡点，只有一条**：把 `CONFIG_SYSFB_SIMPLEFB=y` 编进内核（主机侧一次构建），
  然后 EFI 路径下 `tty0` 才有 fbcon（`FRAMEBUFFER_CONSOLE=y`/`DRM_FBDEV_EMULATION=y`/`DRM_SIMPLEDRM=y` 都已具备）。

## 2. 为什么很可能不是「我们的配置错」而是平台墙

同芯片另一项目（sunuefi，SM8750/Piano）对**同一条标准 EFI-stub 交接**的审查记录（本地 `external/`）：

- EFI74/EFI75：payload/initrd/FDT 交付全部正确，**最后都停在 `native DBI/App Log Flush`，无后续日志**；
- 该平台的 EFI 内存表里**唯一的 Conv 大块 = `DXE_Heap` 0xB90C0000 长 0x1D500000 ≈ 469 MiB**；
- `nokaslr` 下 `efi_kaslr_relocate_kernel()` 需要 2 MiB 对齐、要走 `EFI_LOADER_CODE` 重定位区。

本机**一模一样**：`Platforms/PakalaPkg/Device/lenovo-y700g4/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c`
里也只有 `DXE Heap … Conv`，其余 DDR 全是 `Reserv`（`"Kernel" 0xA8000000 +0x10000000` 也是 Reserv）。
raw DT（`elden.dtb`）里有 ~15 GiB memory 节点，而 EFI 路径只给内核 ~469 MiB。

## 2b. 面板按键事实（2026-11-08 用户确认，实测可用）

| 场景 | 按键 |
|---|---|
| GRUB 菜单 | **音量上 / 音量下 = 上下移动高亮**，**电源键 = 确认启动** |
| 超时 | `set timeout=8`（本轮就是超时自动选了第一项） |

⇒ 后续任何「菜单」方案（A 沿用 GRUB / B 自写 loader）都以这组按键为输入契约。

## 3. 三条可选路线（下一步需要选一条）

| # | 路线 | 要点 | 工作量 | 风险 |
|---|---|---|---|---|
| **A** | **改固件内存表**：把 DDR 大块按 Conv/WB 描述给内核（`PlatformMemoryMapLib`），重编 Mu | 解锁「GRUB/EFI-stub 正常启动」这条通用路线，菜单/多内核/免 boot.img 全到手 | 中（改表 + 重编 + 1-2 发） | 高：Mu 自己的分配/属性可能与新增可用区冲突；需逐块加、每发验证 |
| **B** | **自写 raw-jump loader**（读 ESP 的 kernel/initrd/dtb → 复用 LinuxLoader 已验证的交接口）| 绕开 EFI-stub：`PreparePlatformHardware()` + `LinuxKernel(dtb,0,0,0)`，与 p58 完全同一条路 | 中高（~200–300 行 + 1-2 发） | 低（走的正是现在能起来的那条路）；但**没有菜单 UI**（要菜单就得自己实现按键/选择，见 §2b） |
| **C** | 回退现状：内核仍走 `boot_b` | ESP+GRUB 留着；只是为了以后 (A)/(B) 铺路 | 0 | 0 |

补充事实（影响取舍）：
- **菜单在本机是可操作的（2026-11-08 用户实测确认）**：GRUB 下 **音量上/下 = 上下移动，电源键 = 确认**，
  不需要键盘、不需要触摸 ⇒ 「启动菜单」这半边其实已经拿到；本轮只用了超时自动选。
  这条同时说明 (B) 若自写 loader，**菜单不是白送的**（要自己接 EC 音量键/电源键事件），(A) 则直接沿用 GRUB 菜单。
- **B 只需要换内核文件就能迭代**：`/boot/Image` 在 linux17 上，改完 `scp` 过去即可，不碰 `boot_b`、不重打 boot.img。

## 4. 本轮已落地的资产（可复用，不回退）

- ESP：`/dev/sda18` `eldenesp` 512 MiB，GPT 尾部纯追加（`sgdisk -v` 干净；备份
  `backup/HA2EXB0E-16+512/gpt_before-esp-20261108-0934_{primary,backup}.bin`）；
  内含 `EFI/BOOT/BOOTAA64.EFI` = GRUB standalone（`7993adfc…`，可复现）。
- linux17 上：`/boot/{Image(63 443 456),initrd.img(64 622 358),elden.dtb(153 089),grub/grub.cfg}`；
  `grub.cfg` 由 `scripts/grub-bootfiles.sh` 生成（含 panel 参数、`androidboot.serialno`、`elden_bootmenu=grub` 令牌）。
- 固件：`p59` 世代（`p58` + `R54-espfirst`）= `patches/uefi/20261108R54-espfirst/`，
  镜像 `out/r21-sbstop-p59/uefi-preamble59-r1.img`（`cd73fbdc…`），`scripts/uefi-r21-p7-ladder.sh --gen p59 --verify` PASS。
  R54 的四轮演进（每轮的判据写在补丁头注释里）：入口扫描(fs=0 静默回退) → 入口 ConnectAll(同步异常、地址循环刷)
  → AfterConsole 扫描(仍 fs=0，MsCorePkg 的 AfterConsole 不 ConnectAll) → **按 BlockIo 定向 ConnectController（成）**。

## 5. 判据存档（若走 A 或 B，验收用这一条）

`/proc/cmdline` 含 **只在 `/boot/grub/grub.cfg` 里写**的令牌（`elden_bootmenu=grub`，B 路线换成 `elden_bootloader=esp`），
且 `boot_b` 分区 sha 未变，且 `findmnt /` = `/dev/sda17`。
