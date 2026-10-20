# T9 前置缺陷：`rtcwake`/RTC wakealarm **不能唤醒 s2idle**（2026-10-20 实测）

- **结论**：在本机 SM8750 上，`/sys/class/rtc/rtc0/wakealarm` 与 `rtcwake -m mem`
  都**无法**把设备从 `s2idle` 唤醒。T9 掉电率测量**必须由人按电源键**唤醒，
  或改 `mem_sleep=deep`（未验证是否支持 RTC 唤醒）。
- **影响**：`scripts/suspend-drain-rate.sh` 的「`sleep MIN*60` 后自动唤醒」设计不成立 —— 它只是
  本地 sleep，然后去 SSH，而设备还在睡。窗口时间仍可测（掉电率），但唤醒必须人工。

## 1. 实测记录

| # | 操作 | 结果 |
|---|---|---|
| 1 | 人工按键唤醒（17:00） | ✅ `PM: suspend exit`，`success=1`，`boot_id` 不变 |
| 2 | `rtcwake -m mem -s 30` | ⚠️ **只挂了 1.4 s** 就 exit（`success=2`） |
| 3 | 直写 `wakealarm = rtc_epoch + 45` | ❌ **6 分钟以上未醒**（截至 17:14 仍在挂起） |

第 2 条的短挂起暴露了第一个问题：**RTC 硬件时钟停在 1970**，而系统时间是 2026。
`rtcwake` 按 RTC 基准算唤醒点，算出的绝对时间早已「过去」⇒ 立刻返回。

```
系统: Tue Oct 20 09:07:47 UTC 2026
RTC : 1970-01-03 06:57:21 +0800
hwclock -w → ioctl(RTC_SET_TIME) failed: No such device
```

第 3 条改用**相对 RTC epoch**（`rtc_since_epoch + 45`）绕开时钟基准不一致，
`wakealarm` 写入成功（`169098000`），但**依然不醒**。

## 2. 原因（推断，待 deep 实验确认）

`s2idle` 是「CPU 空闲低功耗、SoC 不真正断电」的挂起，唤醒完全依赖 **SoC 中断**。
`RTC alarm` 是一个中断源，理论上应能唤醒；但：

- `rtc-pm8xxx` 的 alarm 中断在 s2idle 期间**可能未被配置为 wakeup source**；
- 或 PMIC RTC alarm 在 s2idle 下硬件上就不产生中断。

可用 `grep . /sys/kernel/debug/wakeup_sources` 在挂起前确认 `rtc0` 是否列为唤醒源。
**本轮未查**（设备挂在 s2idle 中，无法 SSH）。

## 3. 对 T9 的处置

**T9 仍可做，但必须人工唤醒。** 测量口径相应调整为：

```
scripts/suspend-drain-rate.sh MIN
  → 进入 suspend，脚本本地 sleep MIN 分钟
  → 提示「请按电源键唤醒」
  → 用户按键后才继续读数
  → 掉电率 = ΔSOC*60 / 实际挂起时长
```

**实际挂起时长必须用设备侧时间算，不能用宿主 sleep 时长**：
`suspend_stats` 无累计时长字段，改用 `rtc_since_epoch` 差值（RTC 在 s2idle 期间是否走，待本次唤醒后查）。

## 4. 可选改进（按价值排序）

1. **改用 `mem_sleep=deep`** 测一轮：deep 会真正下电，RTC alarm 通常能唤醒。若成立则 T9 可全自动。
2. 挂起前查 `/sys/kernel/debug/wakeup_sources` 确认 `rtc0` 是否在列 + `enabled` 是否 1。
3. 保留人工唤醒作为兜底（最可靠，但测量窗口受人工时间影响 ±几秒，对 %/h 影响可忽略）。

---

## 6. 关键更正（2026-10-20 17:20 唤醒后取证）

**上面说的「挂了 12 分钟」是错的。** 唤醒后读 `dmesg` 拿到真实时间线：

```
[822.272289] PM: suspend entry (s2idle)
[822.292444] Freezing user space processes
[822.294708] printk: Suspending console(s)
[823.732427] Restarting tasks: Done
[823.740780] PM: suspend exit          ← 只挂了 1.47 秒
[828.877093] wlan0: authenticate ...   ← 5 s 后 WiFi 重新关联
```

**真相**：设备进入 s2idle 后 **1.47 秒就退出了**（某个唤醒源弹出），之后一直醒着，
只是 **USB gadget 没恢复 + WiFi 重连中** ⇒ SSH 不可达，看起来像「还在挂起」。

⇒ 「RTC 唤不醒」这个结论**证据不足**：设备根本没睡那么久，无法证明 RTC alarm 失效。
本次真正证明的是**另一个更麻烦的问题**（见 §7）。

## 7. 真正的问题：s2idle 待不住（1.47 秒就被弹出）

`/sys/kernel/debug/wakeup_sources`（唤醒后）：

| 源 | active_count | event_count | wakeup_count | max_time |
|---|---|---|---|---|
| `gpio-keys` | 4 | 4 | 0 | 15 |
| `qcom-battmgr-bat` | 36 | 37 | 0 | 5 |
| `qcom-battmgr-usb` | 3 | 3 | 0 | 9 |
| `c400000.spmi:pmic@0:rtc@6100` | 32 | 32 | **0** | 0 |
| `mmc0` | 3 | 3 | 0 | 3 (expire) |

`rtc` **确实在** wakeup_sources 里（`event_count=32`），但 `wakeup_count=0` —— 它产生事件，
却未被记为「由它唤醒」。

最可疑的是 **`gpio-keys`（电源键）`active_count=4`**：每次写 `mem` 进 suspend 时，
电源键状态可能被当成「事件」立刻解除挂起。这可以解释 1.47 s。

**⇒ T9 的真正前置不是「RTC 能不能唤醒」，而是「为什么 s2idle 待不住」。**
在解决之前，任何 `%/h` 测量都毫无意义（挂 1.5 秒能耗 ≈ 0）。

## 8. 下一步（T9 修正后的路径）

1. **查 s2idle 为何 1.5 s 退出**：`echo mem > /sys/power/state` 同时用串口抓
   `dmesg`，开启 `no_console_suspend`（vk129 cmdline 已有 `panic=15` 等，
   但 `no_console_suspend` 未确认），才能看到 exit 前的最后几条。
2. 或者直接试 **`mem_sleep=deep`**：`echo deep > /sys/power/mem_sleep; echo mem > /sys/power/state`。
   deep 是真下电，`gpio-keys` 这种「状态误判」不会立刻弹出；RTC alarm 也通常能唤醒。
   **这是最快的判别实验**（一次上机就能分辨是 s2idle 特有问题还是通用问题）。
3. 在 1/2 解决之前，**不要记录任何掉电率数字**。

## 5. 关联

- `reports/vk129-abi-fix-verified-20261020.md` §3.5（首次挂起/唤醒实测）
- `scripts/suspend-drain-rate.sh`
- `TASKS/README.md` T9
