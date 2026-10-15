# WCN 首探修法：内核内自动重发（F1/F2/F3，2026-10-14/15）

> 承接 `reports/e3-wcn-dyndbg-20261014.md`（结论：首次 MHI power-on 必失败、重发即成功，分类 = 首次 vs 之后）。
> 目标：把「重发」做进内核，消除对用户态 `/usr/local/sbin/ath12k-retry.sh` 的依赖。
> 设备 U2 `HA2EXB0E`；三臂全部 `fastboot -s HA2EXB0E boot`（零写盘）；**单变量** = 只换内核 `Image.gz`，
> ramdisk（`4d4834e6`）/dtb（`c8018843`）/cmdline 与 `m1-baseline` **逐字节同**（已回读校验）。

## 0. 结论（数字先行）

| 臂 | 改动 | 首次 probe | 后续 | `Run /init` | wlan0 | 判定 |
|---|---|---|---|---|---|---|
| 基线 | — | 7.65 s **-110** | 用户态 retry 22.6 s 成功 | 7.67 s | 关联 ✓ | — |
| **F1** | `ath12k_mhi_start` 内循环重发（无 SoC 复位） | try1 **-110** | try2–6 全 **-5**（SBL 不是合法 EE） | **12.78 s**（+5.1 s） | 用户态 34.1 s | ❌ 否证 |
| **F2** | `ath12k_pci_power_up` 内循环：每轮 **先 `ath12k_pci_sw_reset(true)`** | try1 **-110** | **6/6 全 -110**（probe 最终失败） | **28.15 s** | probe 失败 | ❌ 否证 |
| **F3** | 失败改返 **`-EPROBE_DEFER`**（上限 4 次）让驱动 core 重跑整轮 probe | try1 7.65 s **-110** | 重探#2 **-110** → 重探#3 **11.78 s chip_id 成功** | **7.670 s**（零回归） | **19.1 s 关联** ✓ | ✅ **采纳** |

**一句话**：MHI 层怎么重发都不行（F1/F2）；**让驱动 core 重跑整轮 probe 才行**（F3），而且不阻塞 `/init`。


## 1. F1：同一 MHI 实例内重发 —— 否证

镜像 `out/boot-elden-f1-mhiretry.img`（sha `016d1823fc6e`），单一变量 = 内核 `Image.gz`（sha `668f428f`，分支 `m1-73/f1-mhiretry`）。

改动（`drivers/net/wireless/ath/ath12k/mhi.c`）：`ath12k_mhi_start()` 循环 6 次；失败即
`ath12k_mhi_set_state(DEINIT)` + `msleep(1000)` 后重新 INIT+POWER_ON。**不碰 SoC 复位**。

实测（dmesg，证据 `logs/arm-f1-mhiretry/dmesg.txt`）：

| t (s) | 事件 |
|---|---|
| 4.477 | try1 `Requested to power ON` / `Power on setup success` |
| 4.556 | `Wait for device to enter SBL or Mission mode` |
| **7.656** | **-110**（3 s 超时用满）→ `try 1/6 failed` |
| 8.679 | try2 → **`mhi0: SECONDARY BOOTLOADER is not a valid EE for power on`** → **-5** |
| 9.70 / 10.73 / 11.75 / 12.77 | try3–6 同 try2（**-5**，每次间隔 ~1.02 s） |
| 12.779 | probe 失败 `failed to create soc 0 core: -5` |
| **12.781** | `Run /init`（**比基线 7.67 s 慢 5.1 s**） |
| 27.65 | 用户态 `ath12k-retry` bind（fresh probe，含 sw_reset）→ 28.21 `chip_id` → 34.06 `wlan0 associated` |

**结论**：首次超时后设备停在 SBL（EE = SECONDARY BOOTLOADER），MHI core 拒绝为 SBL 重新布防 ⇒ **同一 controller 实例内的重发无效**；
F1 还引入 5 s 的 boot 回归，且最终仍靠用户态 daemon ⇒ **F1 方向作废**。

## 2. F2：重试时先做 SoC global reset —— 否证

镜像 `out/boot-elden-f2-socreset.img`（sha `0053004e…`，内核 `ed4ddd37…`，分支 `m1-73/f2-socreset` 提交 `7f163a797f`）。

改动（`drivers/net/wireless/ath/ath12k/pci.c`）：把「`ath12k_pci_sw_reset(true)` + `ath12k_mhi_start()`」放进 6 次循环；
失败则 `ath12k_mhi_deinit()`（新增公开包装，清驱动侧 MHI 状态位 = DEINIT）+ `msleep(1000)` 后整轮重来。

实测（`logs/arm-f2-socreset/dmesg.txt`，2026-10-15 01:0x UTC 发，Q28 坏发 L1=5）：

| t (s) | 事件 |
|---|---|
| 4.51 / 4.60 | try1 power on → `Wait for device to enter SBL or Mission mode` |
| **7.653** | **-110** → `failed to start mhi (try 1/6): -110, re-arming with SoC reset` |
| 8.73 → 11.75 | try2 同签名 **-110** |
| 12.83 → 15.84 | try3 **-110** |
| 16.92 → 19.94 | try4 **-110** |
| 21.02 → 24.04 | try5 **-110** |
| 25.11 → 28.13 | try6 **-110** → `failed to power up :-110` / `failed to create soc 0 core` |
| **28.15** | `Run /init`（**比基线 7.67 s 慢 3.7×**） |

**结论**：**6/6 全 -110**。与 F1 的 `-5` 不同 ⇒ **SoC 全局复位确实把设备从 SBL 拉回**（MHI core 接受了 6 次布防），
但芯片**仍然不应答已布防的 host**；`Run /init` 回归到 28 s，probe 最终失败（靠用户态 daemon 兜底）。
⇒ **设备侧复位不是缺失环节，整轮重探才是**；F2 方向作废。

## 3. F3：`-EPROBE_DEFER` 让驱动 core 重跑整轮 probe —— 通过（采纳）

镜像 `out/boot-elden-f3-defer.img`（sha `4303ac807c…`，内核 `7add4476…`，分支 `m1-73/f3-defer` 提交 `fba09b5385`，基于基线 tip `c7da05b1d8`）。

改动（`pci.c`，+22 行）：`ath12k_core_init()` 失败且 `ret == -ETIMEDOUT` 时，把返回值改成 `-EPROBE_DEFER`（`ATH12K_PCI_MAX_DEFER=4`，
probe 成功即 `atomic_set(…, 0)`）。probe 错误路径本就完成完整拆卸（`ath12k_mhi_unregister()` + `ath12k_core_free()`），
因此重探 = 与用户态 sysfs re-bind 等价的全新 probe（pci_enable/msi/irq/hal srng/ce pipes/mhi register 全跑）。

实测（`logs/arm-f3-defer/dmesg.txt`，Q28 坏发 L1=5/L2=125，与本次结论无关）：

| t (s) | 事件 |
|---|---|
| 4.42 / 4.49 | probe#1 power on → `Wait for device to enter SBL or Mission mode` |
| **7.654** | probe#1 **-110** → `elden F3: WCN silent on first probe, deferring for a fresh probe (1/4)` |
| **7.670** | `Run /init`（**与基线 7.670 s 逐字同 ⇒ 零启动回归**；重探线程 T172 与 init 线程 T1 并行） |
| 7.67 → 10.98 | probe#2（全序列重跑）仍 **-110** → defer (2/4) |
| 11.21 → **11.776** | probe#3：`chip_id 0x2 chip_family 0x4 board_id 0xff soc_id 0x40210200` / `fw_version 0x100effff` ⇒ **成功** |
| 18.0 / 19.0 / **19.105** | `wlan0` 认证 → `associated`（ustc-guest，5300 MHz，−62 dBm，RX 300 KB） |
| 21.76 | 用户态 `ath12k-retry` 醒来：`phy0 up (try 1)` ⇒ **兜底未被用到** |

**结论**：内核内自愈成立——**无需用户态 daemon、无 boot 回归**（`/init` 7.67 s，WCN 11.78 s 上线、wlan0 19.1 s 关联）。

## 4. 机制与纪律

- 判别量 = **有没有整轮重探**，不是「有没有复位/等得够久」。F1 停在 SBL（`-5`）、F2 复位后仍 `-110`，都说明 MHI 层重发无用。
- 内置驱动的 `-EPROBE_DEFER` 由 `deferred_probe_initcall`（late_initcall）立即重触发，**不阻塞 `/init`** ⇒ 不再需要 `CONFIG_ATH12K=m` + 后台 insmod 之类绕法（#259/#260）来躲 init 阻塞。
- 上限 4 次防死循环；成功即清零（下次冷起仍可从 defer(1/4) 开始）。
- **未做**：把 F3 并入功能基线 `m1-73/baseline`（当前 tip 仍 `c7da05b1d8`）、写 `boot_b`、以及上游报告（投递冻结中；F3 属本地件，上游正解仍是 firmware/MHI 侧修复）。
- 证据/资产：`logs/arm-f1-mhiretry/`、`logs/arm-f2-socreset/`、`logs/arm-f3-defer/`；镜像 + `.manifest`；经验条 `PITFALLS #264/#265`。
