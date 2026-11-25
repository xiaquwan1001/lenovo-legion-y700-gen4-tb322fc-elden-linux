# s2idle 驻留 + `pm_test` 三级试挂：首次上机通过（2026-11-25 19:5x–20:0x）

> 执行：父代理在设备窗内实做（设备当时在 BL，`fastboot boot` 后回到 `boot_b` 日常核）。
> 在机：`7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（vk192）。
> 原始日志：`reports/artifacts/devicewin-20261125/{pm-census.txt,console-reboot.log}`。
> 计划来源：`.pi/plans/2026-11-25-device-power-management.md` §3 S2 + `reports/power-on-demand-20261125.md` §4 阶段 1.5。

## 0. 一句话

**`pm_test` 三级（freezer / devices / platform）全部跑通、真 `s2idle` 驻留 ≈8 min 后被电源键正常唤醒，`suspend_stats = success 4 / fail 0`。**
这是本项目第一次「真挂起—真唤醒」闭环，PLAN 的「日常化电源键短按 = 挂起」从规划变成**已验证可行**。

## 1. 基线与方法

```sh
# 三级试挂（每级 5 s 自动返回，不真正掉电；`pm_print_times=1` 让每设备耗时可见）
echo 1 > /sys/power/pm_print_times
for lvl in freezer devices platform; do
  echo $lvl > /sys/power/pm_test
  ( echo mem > /sys/power/state ) &
  sleep 12
  dmesg | tail -25
done
echo none > /sys/power/pm_test
```

## 2. 结果

| 级 | `PM: suspend entry/exit` | 回调错误 | 说明 |
|---|---|---|---|
| `freezer` | 172.347 → 177.473（5.1 s） | 0 | 仅冻结用户态 |
| `devices` | 184.355 → 189.917（5.6 s） | 0 | 全设备 suspend/resume 回调真跑了一遍：`wiphy_resume returned 0 after 60039 usecs`、`rfkill_resume`、`input_dev_resume`、DSI 重新 modeset（`1904x3040@165Hz … bonded=1 dsc=1 wide=1`），面板固件重新下发（`novatek-nvt36xxx-spi … firmware boot-ready asserted`，version `1a.01`） |
| `platform` | 196.368 → 203.176（6.8 s） | 0 | 同上 + 平台级（timer/irq 基础设施）也过 |

**未见的失败**：`ath12k`（`-110`）、BT（`-110`）、`msm` 电源域超时在三级里都**没有**出现 —— 与 PLAN §7 担心的相反。
**注意**：WiFi 每次 resume 都会重新认证/关联（`wlan0: authenticate with …`），这是 ath12k 的固件行为，不是错误，但意味着**挂起会掉一次链路**（重连 ~1 s）。

## 3. 真 s2idle 驻留

| 项 | 值 |
|---|---|
| 发起 | 2026-11-25 19:56:5x（`echo mem > /sys/power/state`，detached） |
| 进入 | `PM: suspend entry (s2idle)` @ dmesg 235.152 |
| 唤醒 | 用户**短按电源键**；`PM: suspend exit` @ dmesg 236.881 |
| **驻留** | **≈8 min**（monotonic 在挂起期间不走，故 235.152→236.881 的 1.73 s 只是「醒着的时间差」；墙钟 19:56:56 → 20:05:0x） |
| `suspend_stats` | **success=4 / fail=0**（3 × pm_test + 1 次真挂起），`last_failed_*` 全空 |
| 唤醒源 | `/sys/power/pm_wakeup_irq = 23` → `/proc/interrupts` = `pmic_pwrkey`（`pmic_arb 1303109 Edge`） |
| 恢复后 | `card0-DSI-1=connected`、WiFi 已重新关联（DHCP/IPv6 正常）、触控 `event4` 在、`systemctl --failed` **空**、UDC `configured`、SSH 通 |

## 4. 这次暴露的两个工程事实（不是 bug）

1. **USB-NCM 是唯一通道 ⇒ 挂起必然失联**：`usb0` 随 gadget 一起挂起，SSH/ping 全断是**预期**，不是故障。设备窗里任何挂起实验必须**先约定唤醒手段**（电源键 = 人；`rtc0` 的 `wakealarm` 我这次参数写错成绝对值 `1` 导致无定时唤醒，等于只能靠人手）。
2. **`suspend_stats/{last,total,max}_hw_sleep` 恒 0** 已被现场再确认（与 `reports/power-on-demand-20261125.md` 的静态结论一致）⇒ **驻留时长只能用墙钟/`CLOCK_BOOTTIME`，不能用 dmesg 差值**。

## 5. 下一轮可直接做的三件事（都有本次判据兜底）

1. 把「电源键短按 = 挂起」做成日常（`logind` `HandleLidSwitch`/phosh 侧电源键动作），并把**唤醒后 WiFi 重连 ~1 s** 写进预期。
2. `pm_test devices` 已证明回调面干净 ⇒ 可以放心试 **`autosuspend`/`runtime PM` 相关 sysfs 调优**（先 GPU `min_freq`、再 UFS），失败只需 `echo on` 回退。
3. 若要做无人值守挂起实验，必须先解决唤醒源：`rtc0` 的 `wakealarm` 写法是 `echo +120 > /sys/class/rtc/rtc0/wakealarm`（**相对秒**，前导 `+`），本次踩的坑已记入本文件 §4。
