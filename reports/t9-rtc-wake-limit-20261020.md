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

## 5. 关联

- `reports/vk129-abi-fix-verified-20261020.md` §3.5（首次挂起/唤醒实测）
- `scripts/suspend-drain-rate.sh`
- `TASKS/README.md` T9
