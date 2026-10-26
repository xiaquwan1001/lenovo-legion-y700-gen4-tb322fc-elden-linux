# M2 A2 前置：Konrad 给的 vendor repo 只读核对（2026-10-26）

> 触发：Konrad Dybcio 2026-10-23T13:57Z 给 `github.com/lenovo-basements/android_kernel_lenovo_sm8750`，暗示「自己去看厂商怎么做」。
> 方式：`git clone --filter=blob:none --depth 1 --sparse`（3.4 GB repo，只取 `drivers/power/supply` + `arch/arm64/configs`），**只在主机，未碰设备**。

## 0. 结论（先数字）

| 问题 | 答案 |
|---|---|
| 是不是本地 GPL drop 的血统 | **是**（同 `geekidos/stock-src` 血统的 Android 15 / 6.6 `sun` 树，default branch `main`，最后 push 2025-11-09） |
| 含 `drivers/power/supply` 吗 | **含**（54 个文件在 `drivers/power/supply/qcom/`：`qbg-*`、`battery.c`、`pmic-voter.c`、`step-chg-jeita.c`、`smb1390-charger-psy.c` …） |
| 含 `qcom_battmgr.c` 吗 | **含**，但它是**更旧的上游副本**：`enum qcom_battmgr_variant` 只有 `SC8280XP / SM8350`，**没有 `SM8750`**；也没有 `BATT_CHG_CTRL_EN/START_THR/END_THR`、`NOTIF_BAT_CHARGING_STATE` |
| 厂商真正用的 charger 通道 | **`drivers/power/supply/qti_battery_charger.c`（downstream）** —— `sun_perf.config` / `sun_le.config`（= SM8750「sun」）里 **`CONFIG_QTI_BATTERY_CHARGER=m`**；`CONFIG_BATTERY_QCOM_BATTMGR=m` 只出现在通用 `defconfig` |
| 该通道能报 `power_now` 吗 | **能**（`grep POWER_SUPPLY_PROP_POWER_NOW` 命中 `qti_battery_charger.c`） |
| 我们树能不能直接用它 | **不能**：该文件依赖 `linux/soc/qcom/qti_pmic_glink.h`、`linux/soc/qcom/battery_charger.h`、`panel_event_notifier.h`；`build/vk151` 与 `build/base-7.2` **均无** `qti_battery_charger.c`、也没有这些头（上游从未收） |

## 1. 对 A2 论据的更正（重要）

- 旧论据「**无厂商通道**」**不成立**：厂商通道存在，就是 downstream `qti_battery_charger`（PMIC GLINK 下游驱动族）。
- 正确的论据是：「**厂商通道是 downstream-only**（依赖 `qti_pmic_glink`/`battery_charger`/`panel_event_notifier` 三个上游不收的接口族），**上游 `qcom_battmgr` 无法复用它**；且厂商自己的 `qcom_battmgr.c` 是更旧的副本、**不含 SM8750 variant** ⇒ 上游评审要求的『先看 vendor 怎么做』在技术上没有可参考实现。」
- 顺带事实：`BATT_POWER_NOW=22` 这条 property id **我们树里已有处理**（`build/vk151/drivers/power/supply/qcom_battmgr.c:1548`），A2 若只是「补 power_now」需先确认与上游现状的重复面（下一步 = A2 补丁 vs `linux-next` 逐 hunk 比对，1 h，无设备）。

## 2. 复现命令

```sh
git clone --filter=blob:none --depth 1 --sparse https://github.com/lenovo-basements/android_kernel_lenovo_sm8750 /tmp/lenovo-msm-check
cd /tmp/lenovo-msm-check && git sparse-checkout set drivers/power/supply
git sparse-checkout add arch/arm64/configs
grep -n "QTI_BATTERY_CHARGER\|QCOM_BATTMGR" arch/arm64/configs/vendor/sun_*.config
grep -rln POWER_SUPPLY_PROP_POWER_NOW drivers/power/supply/
diff -u /home/xuqianhui/y700-elden/build/vk151/drivers/power/supply/qcom_battmgr.c drivers/power/supply/qcom_battmgr.c | head -60
```
