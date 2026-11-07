# UEFI p51→p53：**交棒成立**（内核侧实锤），卡点是那个内核在 4–10 s 后整机硬复位

> 线：G1-29。承接 `reports/uefi-p49-p50-cmdline-witness-20261107.md`（该文 §0/§3 的两条结论已在其文首
> 「⛔ 更正」块作废：`/sys/fs/pstore` 空**不能**推出「内核没跑到 printk」，systemd 会归档并清空它）。
> 本轮 = **4 发零写盘**（p51/p52/p53 + p50 复跑），全部 `fastboot boot`，`boot_b`/槽位未动。
> 设备 = U2 `HA2EXB0E`。

---

## 0. 一句话结论（三条，逐条带证据）

1. **UEFI 交棒成立（这是本线第一次用内核自己的证据证明）**。
   失败那一发的内核 console 会被 `ramoops` 记住，下一次 boot 由 `systemd-pstore` 归档到
   `/var/lib/systemd/pstore/console-ramoops-0`，里面是那个内核自己的启动日志：

   ```
   [    0.000000][    T0] Linux version 7.3.1-debug-vk184-00003-gec74c4795a43 …
   [    0.000000][    T0] Machine model: Lenovo Legion Y700 Gen4
   …  Kernel command line: … elden_nocamera=1 elden_bootpath=uefi
   [    0.000000][    T0] Unknown kernel command line parameters "elden_root=LABEL=linux17
                           elden_nocamera=1 elden_bootpath=uefi", will be passed to user space.
   ```

   `elden_bootpath=uefi` 是 UEFI（R43）独有令牌 ⇒ **这个内核就是 UEFI 交棒的那个**（排他）。

2. **卡点 = 那个内核 4–10 s 后整机硬复位**（不是「跳不过去」、不是「EB 有问题」）：
   - 5 次记录的死点：`4.1227 / 4.0761 / 4.0375 / 9.9090 / 4.1450` s；
   - `ramoops` 环**未回绕**时文件头仍是 boot banner ⇒ 之后一条都没再打印 = 真的停在那里；
   - 死点附近的内容分两类：**`mmc0: ADMA error: 0x02000000`（3 次）** 或 **glink/UCSI 超时链**
     （`qcom-apm gprsvc: CMD timeout … 5496435 usecs` → `ucsi_glink … timeout`，1 次，撑到 9.9 s）；
   - 死亡后整机硬复位，下一次 ABL 启动记 `PM: Reset by PSHOLD / Reset Type: Hard Reset`；
     用户目视「明显二次启动」。
3. **最有希望的单一元凶 = UEFI 自己打开的硬件看门狗**：
   我们的 UEFI 日志里明确写 `HW Wdog Setting from PCD : Enabled`（`QcomWDogDxe`，30 次历史日志里
   每次都一样），而主线内核**没有** `qcom_wdt` 驱动去喂它（`dmesg` 只有内核 lockup 检测器的
   `watchdog: NMI not fully supported` / `Hard watchdog permanently disabled`）。
   `fastboot boot` 路径上 UEFI 一开、交给内核后无人 pet ⇒ 咬掉。

---

## 1. 四发的账（全部零写盘）

| 发 | 件（sha256 前 8） | 关键改动 | 死点 | 备注 |
|---|---|---|---|---|
| p50 复跑 | `uefi-preamble50-r1`（`9a7e22c1`） | 无（复现） | 4.0761 s | 与 r1 同型（4.1227 s）⇒ 侧证可复现 |
| p51 | `uefi-preamble51-r1`（`635f75b2`） | **R45** = cmdline 追加 `initcall_debug` | 4.0375 s | 记录 429 KB（环已回绕）；尾部是 `probe … -517` 链 |
| p52 | `uefi-preamble52-r1`（`57e02876`） | **R47** = 跳转前 `WDog->WdogDisable()` | 9.9090 s | 记录 403 KB；mmc0 这次**正常**（`probe … returned 0`），死在 glink/UCSI 超时 |
| p53 | `uefi-preamble53-r1`（`898e2a76`） | **R48** = bite 超时拉满 + Disable + ForcePet，并**前移到 `preeb` 转储之前** | 4.1450 s | logfs 拿到判据：**`[K] wdog-off miss loc=Not Found`** |

**p53 的判据（持久 logfs）**：
```
[K] wdog-off miss loc=Not Found
```
⇒ 我们的 FV 里**没有** `gEfiKernelProtocolGuid`（`KernelInterfaceDxe` 未包含在
`Device/lenovo-y700g4/DXE.inc`，`Binaries/` 下也没有该驱动的二进制）⇒ **R47/R48 的 WdogDisable
从未真正执行**；p52 的 4.1→9.9 s 只是「最后一次 pet 的时刻」不同，不是我们改出来的。

## 2. 为什么「看门狗」仍然是最强候选

| 证据 | 内容 |
|---|---|
| UEFI 侧明确开 | logfs 里 `HW Wdog Setting from PCD : Enabled`（`QcomWDogDxe`，APRIORI 第一梯队，`DXE.inc:62`） |
| 内核侧明确没有驱动 | `dmesg`: 只有 `watchdog: NMI not fully supported` / `Hard watchdog permanently disabled`（内核 lockup 检测器），无 `qcom_wdt`；`/dev/watchdog*` 不存在 |
| 死点形态 | 与具体驱动无关（同为 mmc ADMA 与 glink 超时两种现场），且**时间**高度集中（4.0–4.15 s，5 发中 4 发） |
| 对照 | 同一内核由 **ABL** 引导时完全正常（`mmc0: new high speed SDXC card` @3.96 s，跑到用户态） |

⇒ 下一步不再需要「猜」：**只要能把 WDT 关掉并留下持久判据，就能一刀切**。

## 3. 已知可用的三条关 WDT 通道（按可做性）

1. **`EFI_WATCHDOG_TIMER_ARCH_PROTOCOL`**（UEFI 标准，`SetTimer(0)` 即关）：`QcomWDogDxe` 通常
   会安装它（`QcomWDogDxe.inf` 是 DXE_DRIVER、`Depex=TRUE`）。比 `KernelInterface` 可用性高得多。
2. **SCM secure-wdog disable**：`Platforms/QcomModulePkg/Include/Protocol/scm_sip_interface.h` 里有
   `TZ_SECURE_WDOG_DISABLE_ID`（`@ref secure_wdog_disable`），走 SCM 调用关 secure wdog。
3. **补 `KernelInterfaceDxe` 进 FV**：设备包里没有该二进制 ⇒ 需要从别处取件（不优先）。

## 4. 判据纪律（本轮新增/修正，全部进 `PITFALLS #550/#551`）

- **`/sys/fs/pstore` 空 ≠ 内核没写记录** —— `systemd-pstore.service` 每 boot 把记录搬到
  `/var/lib/systemd/pstore/` 并清空源目录。**必须读归档目录**。
- **失败内核的完整早期日志是免费可得的两条通道**：`ramoops` 归档（内核自己写的 console）+
  自家 logfs/环（UEFI 写的 `[K]` 链）。前者以前一直没被用上。
- **判据必须落在 `SbDumpLog("preeb")` 之前**，否则不在 logfs 快照里（p53 修的就是这一条）。
- `[K] wdog-off …` 这种「结论行」要在**同一行**给 EFI_STATUS，否则分不清「调用成功」与「没调」。

## 5. 下一步（p54）

1. **R49**：跳转前用 `EFI_WATCHDOG_TIMER_ARCH_PROTOCOL->SetTimer(0)` 关 WDT（失败则退到 SCM
   `TZ_SECURE_WDOG_DISABLE_ID`），把 `loc/status` 一并打进环（放在 `preeb` 之前）。
2. 若内核越过 10 s 并进入用户态 ⇒ **G1-29 文件级目标达成**（`/proc/cmdline` 应带
   `elden_bootpath=uefi`，且 `journalctl --list-boots` 会多出第二条记录）。
3. 若仍死：按死点分两条查（`mmc0 ADMA` 分支 ⇒ SD 主控交接；`glink/UCSI` 分支 ⇒ PMIC RSC/ADSP 未初始化）。

## 6. 产物

| 项 | 路径 |
|---|---|
| 补丁 | `20261107R45-initcalldebug/`、`20261107R46-nosdcc/`（**备料未用**）、`20261107R47-wdogoff/`、`20261107R48-wdogstrong/` |
| 配方 | `p51-recipe.txt`(71)、`p52-recipe.txt`(72)、`p53-recipe.txt`(73) |
| 镜像 | `out/r21-sbstop-p5{1,2,3}/` |
| 构建归档 | `reports/artifacts/uefi-20261107R4{5,7,8}-p5{1,2,3}/` |
| 失败内核 console（**新通道**） | `reports/artifacts/uefi-p51-{uefi-kernel,initcall}-console/`、`uefi-p50-r2-console/`、`uefi-p5{2,3}-wdog-console/` |
| 上机证据 | `reports/artifacts/uefi-boot-20261107-{193644,195415,201047,202128,203058,204820,205704}/` |
| trial | `reports/trials/`：`…-uefi-p49-bootpath-tag` / `-p50-cmdline-witness` / `-p50-r2-repro-mmc` / `-p51-initcall-debug` / `-p52-wdog-off` / `-p53-wdog-strong` |
