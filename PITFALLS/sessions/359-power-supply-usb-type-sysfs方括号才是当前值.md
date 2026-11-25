# #726 power_supply 的 `usb_type` sysfs 是「方括号里才是当前值」，把首词当值会误判整条结论

> 2026-11-25 实例（M12 USB 充电限流）：设备接到 PC 的 USB2 SDP 上，`/sys/class/power_supply/qcom-battmgr-usb/usb_type`
> 读出 `Unknown [SDP] DCP CDP ACA C PD PD_DRP PD_PPS BrickID`，报告与任务台账据此写成「ADSP 把非 PD 源判成
> `usb_type=Unknown` ⇒ 走保守默认值」。**这个读法是错的**：现场值其实是 **`SDP`**。

## 根因

v7.4-rc3 `drivers/power/supply/power_supply_sysfs.c` 的 `power_supply_show_enum_with_available()`：

```c
available = available_values & BIT(i);
active = i == value;
if (available && active)  sysfs_emit_at(buf, count, "[%s] ", label);   /* ← 当前值 */
else if (available)       sysfs_emit_at(buf, count, "%s ", label);
```

即：**打印的是 `desc->usb_types` 声明的「可用集」，只有被方括号包住的才是当前值**；`value` 不在可用集里时
还会 `dev_warn_ratelimited("driver reporting unavailable enum value")` 并返回 `-EINVAL`。
所以 `Unknown [SDP] …` = 可用集里含 Unknown，**当前 = SDP**。同类属性（`CHARGE_TYPES`、`LOAD_SWITCH`、
`CHARGE_BEHAVIOUR`）都是这个格式。

## 判据 / 处置

- 读这类属性一律**按方括号取当前值**：`cat …/usb_type | tr ' ' '\n' | grep -o '\[.*\]'`；
  别 `cut -d' ' -f1`，也别把首词当结论。
- 连带影响已核：M12 的「SDP 下固件默认 100 mA、需要显式抬限」结论**不变**（`input_current_limit` 起点
  100000 是实测）；作废的只是「ADSP 判 Unknown」这条解释。
- 反例价值：Venkat `[PATCH v2 2/2]` 的 `usb_type ∈ {SDP,CDP,PD}` 门之所以在本机放行，
  正是因为这读法修正后现场值是 SDP（另有 `qcom_battmgr_usb_sm8350_update()` 在 set 前现读一次的通道）——
  若按错误读法，会误判「他的门会拒掉本机用例」。

## 指针

`reports/m12-upstream-test-20261125.md` §4（更正 + 源码位置）、`reports/usb-charging-sdp-limit-20261125.md`
（原结论页，已加更正块）。
