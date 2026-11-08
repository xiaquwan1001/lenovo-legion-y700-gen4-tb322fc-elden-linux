# 持久化落地第一发（写 `boot_a` 承载 Mu 固件）：ABL 认这个件，但 flashed 形态下 ESP 枚举不到（2026-11-08 夜）

日期 2026-11-08 · 结论 **负结果 + 设备已完全恢复** · 零风险面：不碰任何引导分区（`uefi_a`/`imagefv_a`/`abl_a`/`xbl_a` 全未动）

## 0. 选路：为什么先试 `boot_a` 而不是 `uefi_a`

| 事实 | 数据 |
| --- | --- |
| `uefi_a` 里装的是 **XBL 加载的 ELF**，不是我们的 FD | 原厂 `uefi.elf` = 5 242 880 B，ELF64，`entry=0xa7000000`，单个 LOAD 段 `phys=0xa7000000 filesz=0x2a8000`；另配 `imagefv.elf`（2 MiB） |
| 我们的构建产物是 **4 MiB 裸 FD**，按 `0xFF300000` 布局，靠 BootShim 拷贝进去 | `manifest.txt`：`uefi_base=0xff300000 uefi_size=0x400000` |
| ⇒ 写 `uefi_a` = 重做一个 0xA7000000 形态的 ELF + 面对 XBL 可能的校验（`secure:yes`）+ 面对 vendor 的 core/imagefv 拆分 | 工作量与风险都远大于要验证的问题 |
| 而 `boot_a` 走的是**和 `fastboot boot` 完全同一条 ABL 路径**（ABL 把 boot.img 的 kernel 段跳进去） | 本轮实测：写入后 ABL 真的执行了我们的固件（见 §2 环形日志） |
| `boot_a` 可牺牲 | 当前 Linux 在 `boot_b`；`boot_a` 是 Android 槽 A 的内核（`ANDROID!`，36.7 MB），已 dd 备份 |

备份：`backup/boot_a-pre-uefi-20261108.img`（100 663 296 B，sha256 `d4772c11…`，与设备读回逐字节一致）。

## 1. 动作（零引导分区写盘，全程可回退）

```bash
fastboot -s HA2EXB0E flash boot_a out/r21-sbstop-p60/uefi-preamble60-r1.img   # 533f09a3… 67 194 880 B
fastboot -s HA2EXB0E --set-active=a
fastboot -s HA2EXB0E reboot
```

## 2. 结果：固件跑起来了，但**找不到 ESP**

ABL 日志（`logfs`）：`Booting from slot (_a)` → `Loading Image boot_a` → 跳到我们的件。
固件环形日志（`logfs` 尾部 16 KiB，tag=`preeb`）关键段：

```
[R54] [K] esp fs=1
      [K] esp ld=Not Found i=0
      [K] esp none
[R13 回退] [L] found=1 size=0x2E600
      [L] LoadImage=Success
      [L] cpu-hook=ok
      [K] cmdline len=308 tag=1 tail=… elden_bootpath=uefi …
      [K] preeb-go
```

- **`fs=1`**（而 `fastboot boot` 形态下是 `fs=8`）⇒ BDS 侧只连出 1 个 FAT 卷，**我们的 ESP（`/dev/sda18 eldenesp`）没出现**
  ⇒ R54 走 `esp none` 回退到 FV 内 LinuxLoader → 它去读 `boot_a` 里的「内核」（其实是我们的固件）→ 必然失败。
- ABL 的重试策略接管：`slot-retry-count:a` 从 7 递减到 **6** 时被判定 `slot-unbootable:a=yes`
  （实测 7 次尝试：我们的一次 `reboot` + 用户一次掉电 + ABL 自己的重试），随后**自动回退 `_b`**，
  `slot-successful:b=yes` ⇒ 现在的 Linux（`vk184-00003`，即 `boot_b`）就是这条回退链送上来的。
- ⇒ **不需要人工救砖**：槽 a 从未真正「刷坏」，坏的是它指向的件；ABL 判定不可用后自动切 b。

## 3. 恢复

```bash
fastboot -s HA2EXB0E flash boot_a backup/boot_a-pre-uefi-20261108.img   # 恢复原 Android 内核
fastboot -s HA2EXB0E reboot                                            # 仍 active=b
```
读回校验：`boot_a` sha `d4772c11…` = 备份；`slot a` 保持 `unbootable=yes`（**故意如此**：防止有人
`set_active a` 又踩同一坑；要用槽 a 先显式 `--set-active=a` 清标志）。
`uefi_a`/`imagefv_a`/`abl_a`/`xbl_a`/GPT **全程未改**。

## 4. 结论与下一步

- **「把固件写进 flash 的 boot 槽」这条落地路是通的**（ABL 接受我们的 67 MB 件并跳到它），
  **唯一缺口 = flashed 形态下 ESP 找不到（`fs=1` vs `8`）**。
- 缺口的两类候选解释（下一轮各一发即可分辨）：
  1. **枚举时机/顺序差异**：`fastboot boot` 前 ABL 刚走过一条 USB 大传输路径，而 flash 启动立即跳；
     若属此类，R54 加「二次重扫 / 等 LinkUp」即可。
  2. **ABL 传入的环境不同（DTB / `dtbo_a` / 槽相关变量）** 导致 Mu 只绑出 1 个 FAT 卷。
- 下一轮建议（都在主机侧先做，再一发上机）：
  - **R62**：R54 打印 `[K] esp blk=<n> fs=<n>` 的**逐句柄 DevicePath 摘要**（现在是裸计数），
    并在 `ConnectController` 后加一次 `Stall(200 ms)` + 二次 `LocateHandleBuffer` 重扫；
  - 把 ESP 定位从「扫 SimpleFileSystem」升级为「按 GPT 名 `eldenesp` 找 `BlockIo` → 手工读 FAT 引导扇区」，
    彻底绕开 ConnectController 时序；
  - 再发一次 `flash boot_a` + `--set-active=a`；判据 = `[K] esp fs>=8` 且出现 `[K] esp ld=Success i=n`。
