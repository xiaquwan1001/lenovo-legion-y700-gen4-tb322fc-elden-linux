# p62（R63 分区普查 + 按名定位 ESP）零写盘 `fastboot boot` 一发：链路仍然通，且把 logfs 的语义查清了（2026-11-09 傍晚）


<!-- pitfalls-entries -->
> **本报告承载的 PITFALLS 条目正文锚点**（索引行在 `PITFALLS/README.md`；此处给 #NNN 定义，避免索引悬空）：
> `#579`、`#580`、`#581`、`#582`、`#583`、`#584`

日期 2026-11-09 16:37–16:52 · 结论 **正结果（功能）/ 判据负结果（通道）** · 零写盘（不 flash、不动槽位）

## 0. 一句话

p62 = p61 + `20261109R63-pidicensus`（BdsDxe 里加：入口标记、`PartitionInfo`/`SimpleFileSystem` 普查、
按 GPT 名 `eldenesp` 直接定位 ESP 的兜底）。`fastboot boot` 形态下**一路走通到用户态**（内核
从 ESP 上的 `\boot\boot.img` 起，cmdline 带 `elden_bootloader=esp`），
同时把上一轮「`esp fs2=` 为什么不见」的通道疑问解决了：**logfs 只在 FV LinuxLoader 跑过时才被写**。

## 1. 硬件/主机侧前置

| 项 | 值 |
|---|---|
| 待试件 | `out/r21-sbstop-p62/uefi-preamble62-r1.img`（`f3459622…`，67 194 880 B，`--verify` rc=0） |
| 构建归档 | `reports/artifacts/uefi-20261109R63-p62/`（`SM8750_EFI.fd` 4 194 304 B，80 条补丁，`manifest.txt`） |
| 判据件复核 | FD **内层 FV**（LZMA 解压后）含 `esp in v=R63` / `pi n=%d` / `fs i=%d p=%d nm=%a` / `espb name=%d conn=%r n=%d` / `espb ld=%r`，且 boot.img 内核段里解压出的 FD **同一份**（`scripts/uefi-fv-strings.py`） |
| 设备 | `HA2EXB0E`（product `elden_prc_wifi`），起前 `boot_b` `retry=7 succ=1 unbootable=0`，`boot_a` = 备份 `d4772c11…` |

## 2. 结果

| 判据 | 读数 | 含义 |
|---|---|---|
| `fastboot boot` 应答 | `Sending 65620 KB OKAY` / `Booting OKAY 10.108s` | ABL 认件并跳进来 |
| 内核 | `7.3.1-debug-vk184-00002-g4da9a8b69fc8` | **不是** `boot_b` 的 `…vk184-00003` ⇒ 起的是 ESP 上的 `\boot\boot.img` |
| `/proc/cmdline` | `… elden_bootloader=esp …`（**无** `elden_bootpath=uefi`） | ESP loader 传的令牌 ⇒ 路线 B（ESP 侧 `boot.img`）成立 |
| `\efi\loader.log` | 新写：`[L] entry r59-menu`…`[L] menu timeout`→`[L] menu boot \boot\boot.img`→`pre-auth`→`post-auth st 0`→`pre-bootlinux` | ESP 上的菜单 loader 真的跑了（`espboot.force` 让它超时后自动挑默认项） |
| `\efi\espboot.log` | 新写：`[E] esp in` / `[E] esp boot 85594112` / `[E] esp boot 100663296` | 同上 |
| logfs 记录 | `tag=preeb`，8 KiB，**与 11-09 10:17 那次读回逐字节相同**（p61 flashed 那一发的记录） | FV LinuxLoader **没有**跑 ⇒ 不是回退路径送的 |

## 3. 顺带查清的通道语义（本轮最有用的一条）

`SbDumpLog()` 的两个调用点都在**FvModulePkg 的 `LinuxLoader`**里（`patches/uefi/20261106R31`）：
`LinuxLoader.c` 入口 `SbDumpLog("entry")`、`BootLinux()` 里 `SbDumpLog("preeb")`；**BdsDxe 自己不写 logfs**。

⇒ **判据推论（可直接用）**：

- R54 找到 ESP → `StartImage` 那个 loader → 它把内核起走 ⇒ **FV LinuxLoader 不跑 ⇒ logfs 保持上一次的旧记录**。
  所以「logfs 没变」在这里是**成功**的伴随现象，不是「什么都没发生」。
- R54 找不到 ESP → 回退 `R13StartLinuxLoader()` → LinuxLoader 在入口就把 RAM 环（含 R54 的
  `[K] esp …` 全部行）落到 logfs ⇒ **失败时才有新记录**，且记录里必然带 R54 的判据行。
- 这解释了两件旧事：① 11-09 p61 flashed 那发读到的 `esp fs=1 / ld=Not Found / none` **就是它自己**
  （因为它回退了，所以有记录）；② 今天这发成功却「logfs 没变」。
- ⚠️ 仍存的老问题：11-09 p61 那发的记录里**没有** `esp fs2=`，而同一份 FD 的内层 FV 确实含该串、
  反汇编可见 `cmp x8,#1 / b.hi` 之后的打印路径（`scripts/uefi-fv-strings.py` + `llvm-objdump`）。
  ⇒ 结论只能是「那台机的那一发没走到 R62 分支」或「8 KiB 环在两次打印之间被驱动 dispatch 刷爆」，
  两者用**下一发的 R63 普查行**分辨（R63 的普查/兜底行都在 `esp fs=` 之后，且失败时必落 logfs）。

## 4. 工具与脚本改动

- 新增 `scripts/uefi-fv-strings.py`：解 FD 的 LZMA 内层 FVMAIN 再搜字串（`grep -a SM8750_EFI.fd` 恒 0 命中，
  因为内层是压缩的）；`--dump` 可导出 12.8 MiB 内层 FV。
- `scripts/uefi-boot-trial.sh`：采样器在设备离开 fastboot 后**不再**逐次 `fastboot getvar`（原来会阻塞到
  timeout，90 采样串行十几分钟挂住，本轮实测）。
- `scripts/uefi-repack-v2aligned.py` 的默认 `--base`（`reports/artifacts/uefi-posctrl-20261103/boot_b-live.img`）
  **已被 11-05/11-09 的资产清理删掉** ⇒ 本轮改用 `--base out/r21-sbstop-p61/uefi-preamble61-r1.img`
  （与 p61 同基座，`only-kernel-differs` 断言通过）。后续世代要么显式给 `--base`，要么恢复该归档件。
- 世代入口：`scripts/uefi-r21-p7-ladder.sh --gen p62`（配方 `patches/uefi/p62-recipe.txt`，80 条）。

## 5. 上一轮那条「树不可再生」疑问的答案（顺带）

p61 构建时工作区是**脏的**（`manifest.worktree_after` 列了 29 个 M）：那不是基线，而是
`reset_tree()` 回滚失败留下的残留（`PITFALLS #545`）。本轮实测：把所有子模块 `git checkout -- .` 归零后，
**整套 80 条补丁在干净树上 100% 应用成功**（`patch≠apply` 0 条）⇒ 世代可逐条重放。
基线快照另存 `patches/uefi/20261109-treebase-localmods.patch`（= 旧脏树，仅作历史对照，重建不需要它）。

## 6. 下一步（唯一剩余动作 = 落地形态，需要用户批准写盘）

```bash
fastboot -s HA2EXB0E flash boot_a out/r21-sbstop-p62/uefi-preamble62-r1.img
fastboot -s HA2EXB0E --set-active=a
fastboot -s HA2EXB0E reboot
```

判定分支（两条都可自动兜底，`PITFALLS #572`）：

| 结果 | 判据 | 含义 / 下一步 |
|---|---|---|
| 成功 | `\efi\loader.log` 新写 + 内核 cmdline 带 `elden_bootloader=esp` + logfs **没有**新记录 | R63 兜底成立 ⇒ flashed 形态可用，进入「正式化（去 `espboot.force` / `BootIntoFastboot` 写死）+ 决定是否设默认启动」 |
| 失败 | logfs **有新记录**，里面有 `[K] esp in v=R63` + `[K] pi n=` / `[K] fs i=… nm=…` / `[K] espb name=…` | 按普查读数二选一：`pi n=0` ⇒ UFS/分区层没出来（下一步搬 retro98boy 的 `StorageConnect.c`：非可发现 UFS 设备 + 逐 LUN `ScsiIo` 连接，`Lun>=8` 跳过，并考虑 `UFSDxe` 在 `APRIORI.inc` 排到 `QRKSDxe` 之后）；`pi` 里有 `eldenesp` 但 `espb n=0` ⇒ Fat 没绑上（改直接读 FAT 引导扇区） |
| 设备进 fastboot / 回 `_b` | 与第 1 发同型 | 回灌 `backup/boot_a-pre-uefi-20261108.img`（`d4772c11…`）、`--set-active=b`、`mark-successful b` |

回滚（任一时刻）：

```bash
fastboot -s HA2EXB0E flash boot_a backup/boot_a-pre-uefi-20261108.img
fastboot -s HA2EXB0E --set-active=b
```

## 7. 原始件

`reports/artifacts/uefi-boot-20261109-163712/`：`run.log` `boot.txt` `gate.txt` `devices.txt`
`fastboot-pre.txt` `usb-watch.txt` `ssh-pre.txt` `logfs-whole.bin`（8 MiB，与 p61 那发记录逐字节同）。
ESP 侧证据：设备上 `/efi/loader.log`、`/efi/espboot.log`（2019 年时间戳 = RTC 未设，内容为准）。
