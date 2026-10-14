# E3：WCN(WCN7861 Peach) 首探失败 —— dyndbg 时序取证（2026-10-14）

> 目的：回答 TASKS §7「未决① WCN 首探时序」——为何 ath12k 首次 PCI probe 的 MHI power-on 失败。
> 手段：**免重编**——复用基线镜像 + cmdline 加 `dyndbg="file pwrseq-qcom-wcn.c +p; file host/boot.c +p"`。
> 镜像 `out/boot-elden-e3-dyndbg.img`（sha `43e7b888…`，kernel/ramdisk/dtb 与 `m1-baseline` 逐字节同，仅 cmdline 多一个 dyndbg 参数）。
> 证据 `logs/arm-e3-dyndbg/`（dmesg.txt 3433 行）。**本发 = Q28 坏发（L2STORM）**，见下。

## 0. 数字结论（先看时间线）

| t (s) | 事件 |
|---|---|
| 3.925 | `pwrseq-qcom_wcn wcn7861-pmu` **probe**：AOSS QMP 4 条 `wlan_pdc` 消息 → `Configured WLAN PDC with 4 AOSS messages` |
| 3.972 | **pwrseq power-on**（T149=hci_qca/BT 线程触发）：投票+使能 7 路 rail（vdd/vddio/vddio1p2/vddaon/vdddig/vddrfa1p2/vddrfa1p8）；`Holding BT_EN low for 50 ms` |
| 4.026 | `Observed WLAN_EN=1 before BT_EN release` → `Released BT_EN` |
| 4.388 | qcom-pcie link up |
| 4.431 | **ath12k first probe**（T95） |
| 4.490 | `mhi mhi0: Requested to power ON` / `Power on setup success` |
| 4.563 | `Wait for device to enter SBL or Mission mode` |
| **7.655** | **MHI fail −110**（等待 2.75 s ≈ 3 s 超时）→ probe failed |
| 7.674 | `Run /init` |
| 35.148 | pwrseq **disable**：`Holding BT_EN low for 100 ms before regulator disable`（= WCN rail 掉电） |
| 86.218 | BT 重试 → pwrseq **re-enable** |
| 108.26 | `ath12k-retry: started`（被 Q28 vblank 风暴拖到这么晚） |
| 120.35 | retry bind（try 1）→ MHI ON 120.52 → **121.49 成功**（0.97 s）→ `chip_id 0x2` |
| 129.26 | `wlan0 associated` |

## 1. 结论

1. **WCN 在 ath12k 之前就已 power-sequence 完成**：pwrseq probe 3.925 s、rails 3.972 s、ath12k probe 4.431 s。
   即 `TASKS §7` 里「probe 过早、chip 还没上电」这一支**被否证**——上电早于探测 ~0.5 s。
2. `drivers/pci/pwrctrl/core.c` 静态确认：PCIe host 在 **枚举前** 调 `pci_pwrctrl_power_on_devices()`（pwrctrl 未 bind 则 `-EPROBE_DEFER`）⇒ 设计上保证「先上电、后枚举」。
3. 因此首探失败**不是**「没上电 / 上电太晚」，而是 **MHI/BHI 握手在首次 power-on 后未建立**。
   之后两次成功的 MHI power-on（re-probe）分别发生在 121.5 s（本发）与 23.1 s（`m1-baseline` 发）——**均非首探**。
4. ★ **悬而未决**：是 (H1) chip 需要更多时间（把 3 s 超时放大即可成功），还是 (H2) **首次 MHI power-on 必须被重发**（放大超时也无效，E1e 的 90 s 单样本指向 H2）。
5. **新观察（待核）**：35.1 s 时 pwrseq 被 **disable**（BT 侧释放）⇒ 若 WLAN 消费方（pci-pwrctrl）此时**没有持有引用**，则 WCN 会被 BT 的电源管理带掉电。需核 `refcount`。
   —— 这条若成立，会解释「坏发簇里 WiFi 起得特别晚」的现象。

## 2. 本发的副作用（记录）

- 本发 **Q28 坏发（L2STORM）**：`drm_crtc_wait_one_vblank` WARN 从 9.13 s 起多次刷屏（`drm_fb_helper_damage_work`），把 `ath12k-retry` 拖到 108 s 才起。
  ⇒ **WCN 时间线（3.9–7.7 s）与 Q28 无关**，但「retry 何时发生」受发质量影响。
- 复位类型：**warm**（`eldroid-bootctl reboot bootloader` = PSCI SYSTEM_RESET2）⇒ 见 §3。

## 3. 下一步（候选，按信息量/代价）

1. **E3a（决定性，需重编）**：基线树把 `MHI_TIMEOUT_DEFAULT_MS` 3000→30000，冷起看首探是否在 ~20 s 自行成功。
   - 成功 ⇒ H1（时间问题），可谈「延后 probe / 异步 probe」的正解；
   - 失败 ⇒ H2（必须重发 MHI），则「首探必败、retry 兜底」是结构性的，应转上游讨论 MHI/BHI 重试语义。
   （注：E1e 曾用 90 s 超时失败，但那发非单变量、证据链弱，需干净复测。）
2. **E3c（便宜）**：把 `/usr/local/sbin/ath12k-retry.sh` 的 `sleep 12` 调小，二分「最早何时 re-probe 能成功」= chip readiness 曲线。
3. **E3d（静态）**：核 `pwrseq` refcount 与 BT/WLAN 两消费方的持有关系（§1.5）。
4. 复位纪律：WCN 可能与复位类型相关 ⇒ 关键臂用**物理 POR 冷起**，本发 warm 结果仅作方向。

## 4. 原始证据

- `logs/arm-e3-dyndbg/dmesg.txt`（3433 行，含全部 pwrseq dyndbg 行）。
- 关键 grep：`dmesg | grep -iE "pwrseq|AOSS|mhi |ath12k|Run /init"`。

---

## 5. ★ E3a 决定性结果（2026-10-14 晚，30 s 超时单变量）

镜像 `out/boot-elden-e3a-mhi30.img`（sha `eebfe78a…`，kernel 仅改 `MHI_TIMEOUT_DEFAULT_MS 3000→30000`，ramdisk/dtb/其余 cmdline 与 `m1-baseline` 同；UTS 仍 `7.3.0-rc7-debug-ged6f232d10e3`）。
证据 `logs/arm-e3a-mhi30/dmesg.txt`。**本发 = Q28 好发（vblank/DMA 签名 0）。**

| t (s) | 事件 |
|---|---|
| 3.856 | pwrseq PDC 配置（4 AOSS） |
| 3.902 | pwrseq power-on（7 rail + BT_EN 时序） |
| 4.365 | ath12k first probe |
| 4.427 | MHI power ON |
| 4.513 | `Wait for device to enter SBL or Mission mode` |
| **35.817** | **仍 −110**（等待 31.3 s = 30 s 超时**用满**） → first probe failed |
| 32.206 | pwrseq **disable**（BT 释放，WCN 掉电）——**发生在首探等待窗口内** |
| 37.919 | pwrseq 重新 power-on |
| 50.067 | ath12k-retry fresh bind → MHI ON → **50.64 chip_id** → 55.62 phy0 up → 56.51 wlan0 associated |

### 结论（H1 vs H2）

- **H2 成立**：把 MHI 首探超时从 3 s 放大到 **30 s（用满）仍失败** ⇒ **首探失败不是「等得不够久」**。
  结合 E1e 的 90 s 单样本、`m1-baseline`（3 s）23 s 成功、本发 50 s 成功 ⇒ **成功只发生在「重新发起的 MHI power-on（re-probe）」上，而非延长同一个等待**。
- ⇒ 机制候选：**首次 MHI/BHI power-on 在 WCN 尚未 boot 完时发起后，设备不再对此后的状态就绪给出信号；只有重新发起（fresh power-on）才能握手成功。**
- **附带新观察**：首探等待窗口内（32 s）**WCN 被 pwrseq 掉电**（BT 侧释放引用）⇒ 首探的等待被电源中断**污染**。这条独立成立，需查 `refcount`（WLAN 消费方是否持引用）——可能是板级真 bug。

### 对 TASKS §7「未决①」的回答

**首探失败 ≠ 上电太晚**（上电 3.9 s，早于 probe 4.4 s）；**也 ≠ 等得不够久**（30 s 用满）。**是「首次 MHI power-on 不可用、必须重发」**。
⇒ 正路修法方向：让 ath12k probe **不再同步阻塞 init** + **自动重试**（而非单靠用户态 ath12k-retry）；并向上游报告「WCN MHI 首探不可恢复」这一行为。

### 剩余未做

- E3c：把 re-probe 提前（二分「fresh power-on 最早何时成功」）——现在价值降低（H2 已定），但可界定「重试要等多久」。
- E3d：pwrseq refcount / BT-WLAN 引用关系（§5 附带观察）。
- 复位类型：E3a 为 **warm**（PSCI）；关键结论若要与上游对齐，宜补一发**物理 POR 冷起**复现。

---

## 6. ★ E3c：fresh re-probe 最早成功时刻（2026-10-14 晚）

手段：把设备 `/usr/local/sbin/ath12k-retry.sh` 的 `sleep 12`→`sleep 1` 并在 `log()` 里加 `/proc/uptime` 时间戳（绕过 dmesg 轮转）；**测试后已恢复原脚本**（md5 `826c96e3…`，`sleep 12`）。
诊断结论：retry 不是 /init 拉起，而是 **OpenRC `/etc/local.d/elden-bringup.start`** ⇒ 启动时刻由 OpenRC 决定（好发 ~10 s；坏发可拖到 162 s），`sleep` 只是次要项。

**好发（本发 Q28 sig=0）实测：**

| uptime (s) | 事件 |
|---|---|
| 10.37 | ath12k-retry started (pid 1800) |
| 11.37 | try 1 bind |
| **11.92** | **bind write ok（0.55 s 成功）** |
| 16.92 | phy0 up（wlan0 已通） |

### 结论（闭合 §5 的 H1/H2）

- **fresh re-probe 在 ~11.4 s 即成功**；而**首次** MHI power-on（4.49 s 发起）等 3 s/30 s/90 s 全失败。
- ⇒ **不是「要等很久」，而是「首次 MHI power-on 一旦在芯片就绪前发起即作废，重发即刻可用」**。
- 上限/下限：最早成功样本 = **11.4 s**（受 OpenRC 拉起时刻限制；是否更早未测）。
- 未决子问题：把 fresh probe 放到 ~5–7 s 是否也成（区分「首次死」vs「需 ≥N 秒」）——需把探针放进 /init（RAM 侧），未做。

### 对修法的直接输入

- 用户态 retry ~11 s 已够（现网 daemon 已能达成，只是启动晚）。
- **正路**：让 `ath12k_pci_probe` 在 MHI 超时返回 `-EPROBE_DEFER`（或延迟 work 重探），由内核自动完成这次「重发」，从而 **不阻塞 init、不依赖用户态 daemon**。

---

## 7. ★ 冷起复核（物理 POR，2026-10-14 晚）

用户物理 POR → fastboot → 单条 `fastboot boot out/boot-elden-e3a-mhi30.img`（reset=**por**）。

| t (s) | 事件 |
|---|---|
| 3.924 | pwrseq PDC 配置（4 AOSS） |
| 3.971 | pwrseq 上电（7 rail，BT_EN 时序） |
| 4.492 | MHI power ON |
| 4.571 | Wait for device to enter SBL or Mission mode |
| 32.240 | pwrseq 下电（BT_EN low 100ms） |
| **35.815** | **−110（30 s 超时用满）** |
| 35.830 | Run /init |

**Q28 sig = 43（本发坏发）。** 结果与 warm 完全一致 ⇒ **首探失败与复位类型无关**（H2 结论不受 warm 偏置影响）。


---

## 8. 机制分析与修法选项（2026-10-14）

### 8.1 代码级机制（已核）

- `ath12k_pci_probe` → `ath12k_core_init` → `ath12k_pci_power_up` → `ath12k_mhi_start`：
  `ath12k_mhi_set_state(INIT)` = `mhi_prepare_for_power_up()`；`(POWER_ON)` = **`mhi_sync_power_up()`**。
- `mhi_sync_power_up()` = `mhi_async_power_up()`（BHI 建立；打印 “Requested to power ON / Power on setup success”）
  + `wait_event_timeout(state_event, MHI_IN_MISSION_MODE(ee) || MHI_PM_FATAL_ERROR, timeout_ms)`；
  超时 ⇒ `mhi_power_down()` + return **-ETIMEDOUT** ⇒ ath12k 打印 “failed to set mhi state: POWER_ON(2)”/“failed to start mhi: -110”。
- ⇒ host 等的是 **芯片进入 AMSS/mission mode**。首次（4.49 s）**芯片全程不宣告**（3/30/90 s）；**重新 power-on 0.5 s 内宣告**。

### 8.2 为什么首次布防无效（假设排序）

1. **H-pwrseq 竞态（最强）**：本树新增 `wcn7861-pmu` pwrseq 在 **3.97 s** 才给 WCN 上电（由 BT 触发 power_on）；首次 MHI 布防 4.49 s 只比上电晚 ~0.5 s —— 芯片自身 PBL/boot 尚未完成，且**已布防的 host 错过设备的状态跃迁**（chip 不向已布防的 host 重发 mission-mode 事件）。重新布防（power-down→power-up→重新武装）才命中。
   对照：**上游参考 DT 无 host 侧 pwrseq**（芯片由 bootloader 常供电、Linux probe 时已 boot）⇒ 无此竞态。
2. 冷/暖、复位类型：**已否证**（POR 与 warm 结果逐字同）。
3. 超时长度：**已否证**（3/30/90 s 皆失败）。
4. DT 供电/复位时序差异：本树 wifi 节点有 9 路 supply（消费者=ath12k？实为 pwrseq 输出），参考 DT 无 —— 待与 8.2.1 一并验证。

### 8.3 修法选项（按代价/风险）

| 选项 | 做法 | 评价 |
|---|---|---|
| **A. 内核内重试** | `ath12k_mhi_start` 失败(-ETIMEDOUT)时：`power_down` → `msleep` → 重新 INIT+POWER_ON，重试 N 次 | 直接命中病根（「重发」），~10 s 内成功；缺点：probe 同步阻塞（与现状同量级） |
| **B. -EPROBE_DEFER** | MHI 超时 ⇒ probe 返回 `-EPROBE_DEFER`，交 driver core 重探 | 干净，但重探触发时机不确定（依赖其它 driver/device 注册） |
| **C. 延迟 work 重探** | probe 失败后 `schedule_delayed_work` 经 `device_reprobe`/`pci_rescan` 重探 | 最接近现网**已验证可用**的用户态 daemon，且**不阻塞 init**；代价=补丁较大 |
| **D. 用户态 daemon 提前** | 把 `ath12k-retry.sh` 从 OpenRC local.d（~10 s 起、坏发可到 162 s）改由 **/init 早期**拉起（用现成 overlay 钩子机制） | 最小风险、零内核改动；已证 ~11.4 s 可成功 |
| **E. DT/pwrseq 侧** | 设法让 WCN 在首次 MHI 布防前就 boot 完（如保证上电早于 probe / 布防前留足以待时间） | 若 8.2.1 成立则最「正统」，但要动 pwrseq/DT，需更多验证 |

### 8.4 与 Q28 的关联（待验）

- 现有 5 发里 WCN 均首探失败，Q28 好/坏都有（E3a warm GOOD、冷起 BAD、E3c GOOD、E3 dyndbg BAD、E3c-bad BAD）⇒ **尚无因果证据**。
- 可判定实验：上 **D 或 C**（WCN 首次即成功）后，做 N≥6 发 Q28 好/坏统计，与现状对比。若 WCN 路径确实扰动 AOSS/dispcc 状态，则应见 Q28 坏发率变化。

---

## 9. ★ E4：首探延后 8 s（决定性反证，2026-10-14 晚）

镜像 `out/boot-elden-e4-probedelay.img`（sha `a3e00248…`）= baseline 内核**仅加** `msleep(8000)` 于 `ath12k_pci_probe` 的 `ath12k_core_init()` 之前（单变量），ramdisk/dtb/cmdline 与 E3 dyndbg 同。

| t (s) | 事件 |
|---|---|
| 3.977 | pwrseq 上电 |
| 4.444 | ath12k probe 起（BAR/MSI） |
| **12.575** | **MHI power ON（延后 8.6 s）** |
| 12.667 | Wait for device to enter SBL or Mission mode |
| **15.591** | **仍 −110（3 s 超时）** |
| 15.611 | Run /init |
| 87.8 / 99.9 / **109.5** | ath12k-retry started / try 1 / **bind ok**（后 0.4 s 出 chip_id）→ phy0 114.6 → wlan0 122.2 |

### 结论（否证「延后即可」）

- **把首次 probe 延到 12.6 s（芯片上电 8.6 s 之后）仍失败** ⇒ 首探失败**不是**「芯片还没准备好 / host 布防太早」。
- 结合 E3c：**11.37 s 成功的那个 probe 是「第 2 次」（首探已在 4.43 s 失败过）** ⇒ 真正的分类是 **「首次 vs 之后」**，不是「早 vs 晚」。
- ⇒ **首次 MHI power-on 必然失败；任何「重发」（重新 probe / 重新 power-on）都成功。** 机制候选：首次 `mhi_sync_power_up` 超时后 `mhi_power_down()` 把设备复位回可用态，或设备需要一次「握手尝试」才肯进 mission mode。
- **修法含义**：选项 **E/F（延后首探 / 晚加载）被否证**；必须走 **A（内核内重发）或 C（延迟 work 重探）**。

