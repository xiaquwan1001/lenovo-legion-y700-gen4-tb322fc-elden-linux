## 三十五、WCN 首探修法：只有「整轮重探（fresh probe）」有效（2026-10-15 F1/F2/F3 实测）

> 承接 §34（首探必失败、重发即成功）。目标 = 把「重发」做进内核，去掉对用户态 `ath12k-retry` 的依赖。
> 设备 U2 `HA2EXB0E`，三臂全部 `fastboot boot` 零写盘；**单变量**：ramdisk `4d4834e6` / DTB `c8018843` / cmdline 与 `m1-baseline` **逐字节同**。
> 证据 `reports/f1-f3-wcn-firstprobe-20261014.md`、`logs/arm-{f1-mhiretry,f2-socreset,f3-defer}/`。

264. **★同一 MHI 实例内重发无效（连每轮 SoC 全局复位也无效）——必须让驱动 core 重跑整轮 probe。**

    - **F1**（`ath12k_mhi_start()` 内 6 次重发，不碰 SoC 复位）：try1 `-110`（3 s 超时用满），try2–6 全 **`-5`（`SECONDARY BOOTLOADER is not a valid EE for power on`）** ⇒ 首败后设备停在 SBL、MHI core 拒绝为 SBL 重新布防；`Run /init` **12.78 s**（比基线 7.67 s 更慢），最终仍靠用户态 daemon（27.7 s）。
    - **F2**（每轮先 `ath12k_pci_sw_reset(true)` 再 power-on，失败 `ath12k_mhi_deinit()` + `msleep(1000)`）：**6/6 全 `-110`**（不再是 `-5` ⇒ SoC 复位确实把设备拉出 SBL，但芯片**仍不应答 host 的布防**）；`Run /init` **28.15 s**、probe 最终失败。
    - ⇒ 判别量不是「有没有复位设备」，而是**有没有整轮重探**（`ath12k_pci_probe` 全序列重跑：pci_enable/msi/irq/hal srng/ce pipes/mhi register）。

265. **★内核内自愈的正确形态 = `-EPROBE_DEFER`（F3，实测通过）**：在 `ath12k_pci_probe()` 里 `ath12k_core_init()` 失败处，若 `ret == -ETIMEDOUT` 就改返回 `-EPROBE_DEFER`（计数上限 4 次，成功即清零）。probe 自身错误路径已做完整拆卸（`ath12k_mhi_unregister()` + `ath12k_core_free()`），驱动 core 的重探**等价于用户态 sysfs re-bind**。

    - 实测（`out/boot-elden-f3-defer.img` sha `4303ac80…`、内核 `7add4476…`、分支 `m1-73/f3-defer`）：try1 4.42→**7.65 s `-110`** → defer(1/4) → **`Run /init` 7.670 s（与基线逐字同 ⇒ 零回归）** → 重探#2 **10.98 s 仍 `-110`** → defer(2/4) → 重探#3 **11.78 s `chip_id 0x2 chip_family 0x4` 成功** ⇒ `wlan0` **19.1 s 关联 ustc-guest**（5300 MHz、−62 dBm）；用户态 `ath12k-retry` 21.8 s 醒来时 `phy0 up (try 1)` ⇒ **兜底未被用到**。
    - 机制：内置驱动 defer 后由 `deferred_probe_initcall`（late_initcall）立即重触发重探，**不阻塞 `/init`**（本发 init 线程 T1 与重探线程 T172 并行）⇒ 「把首探挪后 / 关掉 init 阻塞」都不再需要。
    - 纪律：修「WCN 首探不应答」类问题时**不要在 MHI 层重发**（F1/F2 均否证），直接在 probe 层让驱动 core 重跑；判据必须看 **probe 序号**（同 §34）。


## 本次留下的工具 / 资产

| 资产 | 说明 |
|---|---|
| `build/m1-73-f2` 分支 `m1-73/f1-mhiretry` / `f2-socreset` / `f3-defer` | 三臂源码（F3 = `fba09b5385`，基于基线 tip `c7da05b1d8`） |
| `out/boot-elden-{f1-mhiretry,f2-socreset,f3-defer}.img` + `.manifest` | 三臂零写盘镜像（f3 有 manifest） |
| `logs/arm-{f1-mhiretry,f2-socreset,f3-defer}/` | 每次上机的全量 `dmesg.txt` + meta |
