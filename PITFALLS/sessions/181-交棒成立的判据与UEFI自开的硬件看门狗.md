# 2026-11-07：UEFI 交棒**成立**的证据链 + 「UEFI 自开硬件看门狗咬掉交棒内核」

- 日期：2026-11-07（夜，p49→p53 六发零写盘）
- pi 会话 id：见 `.pi/sessions/*.jsonl`（关键词「pstore 归档 / wdog-off miss / 交棒成立」）
- 主题：一个**被自己写错的判据**差点让「交棒成立」这个里程碑再次被丢掉；以及 UEFI 侧开关与内核侧缺位的组合
- 结论：见下 `## #551`
- 证据指针：`reports/uefi-p52-p53-handoff-confirmed-20261107.md`、
  `reports/artifacts/uefi-p51-uefi-kernel-console/console-ramoops-0.bin`、
  `reports/artifacts/uefi-p53-wdog-console/console-ramoops-0.bin`、
  `reports/artifacts/uefi-boot-20261107-205704/logfs.img`
- ★SSOT 待并入：`PITFALLS/README.md` #551（已并入）；`TASKS` §1 G1-29 / §5、`INDEX` §3（已改）

## #551 交棒成立的判据 & 谁在 4 s 后复位整机

### 551-A 差点丢掉的里程碑：`/sys/fs/pstore` 空是**假阴性**

p49/p50 两发我判「内核连 printk 都没跑到」，依据是 `/sys/fs/pstore/` 空 + `journalctl --list-boots`
只多一条。用户当场看屏说「**JUMP-BANNER 之后屏幕全亮、开始进 Linux**」，复查发现：

- `systemd-pstore.service` 在**每次 boot** 把 `/sys/fs/pstore/*` **搬到 `/var/lib/systemd/pstore/`**
  并清空源目录 ⇒ 源目录空**什么都不说明**；
- 归档目录里的 `console-ramoops-0` 就是**那一发交棒内核自己的启动日志**，64 858 B，
  从 `[0.000000] Booting Linux` 到 `[4.122698] mmc0: sdhci: Host ctl2`，
  且 `Kernel command line:` 里**带 `elden_bootpath=uefi`**（R43 的 UEFI 独有令牌）。

⇒ **交棒成立**（内核侧排他证据），前一天「打通已撤回」的那条要先撤回来的，是**判据**而不是事实。

**规则**：ramoops 控制台是 64 KiB（本例 64 KiB~512 KiB）**环**：

- **文件头仍是 boot banner = 环没回绕 = 内核从此没再打印过** ⇒ 这就是精确的「停在哪一行」；
- 环回绕后（如带 `initcall_debug` 的 429 KB 记录）改看**尾部**，找最后一条没有配对
  `initcall … returned` 的 `calling`。

### 551-B 谁在 4 s 后复位整机：UEFI 自己开的 HW WDT

| 项 | 事实 |
|---|---|
| UEFI 侧 | logfs 里 `HW Wdog Setting from PCD : Enabled`（`QcomWDogDxe`，`DXE.inc:62`，30 份历史日志每次都有） |
| 内核侧 | **没有** `qcom_wdt`：`dmesg` 只有 lockup 检测器的 `watchdog: NMI not fully supported` / `Hard watchdog permanently disabled`，`/dev/watchdog*` 不存在 |
| 死点 | 5 次：`4.1227 / 4.0761 / 4.0375 / 9.9090 / 4.1450` s；现场分两类（`mmc0: ADMA error` 3 次 / glink+UCSI 超时 1 次）⇒ **不是某个驱动挂住，是时间到就复位** |
| 对照 | 同一内核由 ABL 引导完全正常（`mmc0: new high speed SDXC card` @3.96 s，跑到用户态） |

### 551-C 「想关它」这件事本身踩了两个坑

- **协议不在 FV 里**：R47/R48 用 `gBS->LocateProtocol(&gEfiKernelProtocolGuid)` 调
   `WDog->WdogDisable()`，上机拿到 **`[K] wdog-off miss loc=Not Found`** ——
   我们的 `DXE.inc` 不含 `KernelInterfaceDxe`，`Binaries/` 下也没有它的二进制。
   **教训**：结论行（`ok` / `miss loc=%r`）必须一行给全，否则「调用成功」与「压根没调」分不清；
   而且这类「先加调用再说」的补丁，**必须带一个能证伪的状态行**。
- **判据位置**：R47 那段放在 `SbDumpLog("preeb")` **之后** ⇒ logfs（那次转储的快照）里看不到；
   R48 前移后才拿到 `wdog-off miss`。**凡是要进 logfs 的结论行，必须排在 preeb 转储之前。**

### 551-D 下一刀（p54）

`EFI_WATCHDOG_TIMER_ARCH_PROTOCOL->SetTimer(0)`（UEFI 标准，`QcomWDogDxe` 多半装了它）；
不行再退到 SCM `TZ_SECURE_WDOG_DISABLE_ID`（`scm_sip_interface.h` 已有定义）。
判据：内核越过 10 s ⇒ `journalctl --list-boots` 多出**第二条**记录（UEFI 起的那个内核进了用户态），
且它的 `/proc/cmdline` 带 `elden_bootpath=uefi`。
