# #719 设备 RTC 停在 1970 ⇒ `rtcwake -m mem -s 120` / `wakealarm +180` 都**立即醒**（1.6–1.9 s），别读成「s2idle 挂不住」

> 2026-11-25 上机实测（vk189，`s2idle`）。两次「suspend」都被当成了失败，实际是**唤醒源提前触发**。

## 现象

```sh
cat /sys/class/rtc/rtc0/date        # 1970-01-09      ← 系统时钟对，RTC 不对
rtcwake -m mem -s 120               # 打印 "wakeup from mem using /dev/rtc0 at Fri Jan  9 11:20:10 1970"，rc=0，约 7 s 返回
cat /sys/power/suspend_stats/success # 0 → 1（确实挂起过）
dmesg | grep -E 'PM: suspend (entry|exit)'
#   [40534.497992] PM: suspend entry (s2idle)
#   [40536.126215] PM: suspend exit      ← 只驻留 1.63 s
```

`echo +180 > /sys/class/rtc/rtc0/wakealarm`（读回 732089 = RTC 731909+180）同理：驻留 **1.91 s** 就 exit，
`success` 再 +1、`fail` 仍 0、`boot_id` 未变。

## 判据（分清三件事）

| 观察 | 含义 |
|---|---|
| `success` +1 且 `boot_id` 不变、dmesg 有 entry→exit | **挂起/恢复链路本身是通的**（vk189 实测成立） |
| 驻留只有 1–2 s | 唤醒源提前触发 —— 先查 RTC 是否 1970（`rtc0/date`）、再查 `pm_wakeup_irq` |
| 触摸屏重新下固件 + `wlan0` 重新 authenticate（`dmesg`） | 佐证真的走了一轮 suspend/resume（不是空转） |

## 处置

- 测「驻留能力」时不要用 RTC 短闹钟：改 `echo +600 > /sys/class/rtc/rtc0/wakealarm`（相对写法仍受 RTC 时基影响）
  之前先 `hwclock --systohc` 把 RTC 校准，或改用**外部唤醒源**（`rfkill` 事件、USB 插拔）并接受 SSH 断开。
- 记 `suspend_stats/last_failed_dev` 与 `pm_wakeup_irq`（本轮 `pm_wakeup_irq=22`）作为「谁把它叫醒的」证据。
- 真正的驻留时长判据 = `dmesg` 的 entry/exit 时间差，**不是**命令返回耗时。
