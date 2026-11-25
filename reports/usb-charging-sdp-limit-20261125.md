# 数据线（USB2 SDP）连主机时只有 100 mA 输入限流 ⇒ 净放电 0.8 A（2026-11-25 定因）

> 触发：用户观察到「数据线连接时没有拿到保底 500 mA 的充电标志」。本轮实测复现并定因。
> 设备：TB322FC / 在机 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0` / `/`=`/dev/sda17`。
>
> **⚠ 2026-11-25 晚更正（`PITFALLS #726`，`reports/m12-upstream-test-20261125.md` §4）**：本文件与
> `usb-charging-sdp-limit` 里「ADSP 把非 PD 源判成 `usb_type=Unknown`」这句**作废** —— sysfs 的
> `Unknown [SDP] DCP …` 是「可用集 + 方括号里的当前值」，现场值其实是 **`SDP`**。
> 保留的结论：「SDP 下固件默认 `input_current_limit=100000` ⇒ 必须显式抬限」，且 mainline 原本无写路径。

## 0. 一句话结论

**不是缺少充电标志，而是 ADSP（充电固件）把非 PD 的 Type‑C 源判成 `usb_type=Unknown`，
把输入限流钉在 100 mA（USB 未配置默认值）；而 USB 链路其实已经 `high-speed` + `configured`，
按 USB 2.0 规范此时允许 500 mA。** Linux 侧 `qcom-battmgr` 的 USB 电源对象**只读**
（无 `set_property`），mainline 没有任何路径能改写 ICL ⇒ 这是**上游充电控制链缺失**，
不是我们的 DT/驱动配错。

## 1. 实测证据（2026-11-25 09:5x–10:19，全部只读）

### 1.1 电量在掉（"Charging" 是假象）

| 时间 | capacity | charge_counter | current_now | voltage_now | status |
|---|---|---|---|---|---|
| 10:17:42 | 51 | 3527670 | −819 mA | 3.871 V | Charging |
| 10:18:22 | 51 | 3527670 | −894 mA | 3.869 V | Charging |
| 10:19:02 | **50** | 3527670 | −819 mA | 3.869 V | Charging |
| 10:19:22 | 50 | 3459000 | −826 mA | 3.867 V | Charging |

⇒ 100 s 掉 1 %、净放电 ≈0.8 A，`status=Charging` 与 `current_now<0` 自相矛盾
（battmgr 的 status 字段来自 ADSP 的"充电使能"状态，不代表净电流方向）。

### 1.2 USB 链路已配置完成（规范上应给 500 mA）

```
/sys/class/udc/a600000.usb  current_speed=high-speed  max_speed=super-speed-plus  state=configured
dmesg: configfs-gadget.g1 gadget.0: HOST MAC … ; [usb-gadget] bound to a600000.usb ; [init] usb0 up: 192.168.7.1
```

USB 2.0：**未配置 ≤100 mA，配置后 ≤500 mA（SDP）**。当前是已配置态。

### 1.3 ADSP 侧限流 = 100 mA，类型没认出来

```
/sys/class/power_supply/qcom-battmgr-usb/uevent
  POWER_SUPPLY_ONLINE=1
  POWER_SUPPLY_VOLTAGE_MAX=5000000
  POWER_SUPPLY_VOLTAGE_NOW=5510000
  POWER_SUPPLY_CURRENT_MAX=900000          ← ADSP 认为上限 900 mA（USB3 SDP 档）
  POWER_SUPPLY_CURRENT_NOW=403000
  POWER_SUPPLY_INPUT_CURRENT_LIMIT=100000  ← 实际限流钉在 100 mA
  POWER_SUPPLY_USB_TYPE=Unknown [SDP] DCP CDP ACA C PD PD_DRP PD_PPS BrickID
```

```
/sys/class/power_supply/ucsi-source-psy-pmic_glink.ucsi.01
  usb_type=[C] PD PD_PPS ; current_max=100000 ; current_now=100000 ; online=1 ; status=Charging
```

两个 100 mA 是**两个独立来源**，都等于 100 mA 属巧合级对齐：
- battmgr：ADSP 把适配器判 `Unknown` ⇒ 用 USB 未配置默认值；
- UCSI psy：mainline `drivers/usb/typec/ucsi/ucsi.h:525` `#define UCSI_TYPEC_DEFAULT_CURRENT 100`，
  `psy.c:172 ucsi_psy_get_current_max()` 在 `PWR_OPMODE` 非 PD/1.5A/3A 时**一律返回该 100**
  （源码：`build/elden-tree` = `v7.4-rc3`）。

### 1.4 Linux 侧无写入口（关键）

`build/elden-tree/drivers/power/supply/qcom_battmgr.c`：
- USB 电源对象 `sm8350_usb_psy_desc`（:1080）**只给了 `get_property`**，属性表里也没有可写项；
- 只有 **电池**对象是 writable（`:863/:864` `qcom_battmgr_bat_set_property` / `is_writeable`）。

⇒ `echo 500000 > /sys/class/power_supply/qcom-battmgr-usb/input_current_limit` 这条路不存在
（该属性在 USB 对象上根本没实现 set）。

## 2. 归因（按可证伪顺序）

| # | 假设 | 判据 | 结论 |
|---|---|---|---|
| H1 | 端口没识别成 SDP/DCP（PD 协商缺失，PC 主机不会 PD） ⇒ ADSP 走保守默认 | `usb_type=Unknown`、typec port0 `power_operation_mode` 非 PD；PD 充电器接上时 `status=Charging` + `current_now=+9.1 A`（本轮实测） | **成立**（主因） |
| H2 | mainline 缺 vendor 的 `qti_battery_charger`/`usbpd` 用户态→ADSP 配链 ⇒ ADSP 没有"这是 SDP、给 500 mA"的输入 | 7.4-rc3 树内 `rg -l "qti_battery_charger\|battery_charger"` 无驱动；PMIC glink 客户端只有 altmode/ucsi/pd/battmgr | **成立**（机制） |
| H3 | 我们 DT 写错（少 `usb-role-switch`/typec 方向/`role-switch` 默认） | 角色切换正常（`data_role=device`、gadget 绑定成功、NCM 通）；`remote wakeup not configured` 只是 gadget 侧 WARN | **否证** |
| H4 | 大电流是我们自己的负载（NCM + 桌面）叠加导致"看起来没充电" | 空载 CPUSS 40 °C、无失控进程；PD 充电器下净 +9.1 A | **部分**：100 mA 输入下，任何 >100 mA 的负载都会净放电；即使降到极低负载也只在 100 mA 附近徘徊 |

## 3. 影响与当前可用的规避

- 用 PD 充电器/PD 主机：`status=Charging`、`current_now=+9.1 A`（正常）。
- 用纯数据线（PC 的 SDP）：**净放电 ≈0.8 A，约 4–5 h 耗尽**；`status` 仍显示 Charging，**别信这个字段**。
- 需要长期挂着调试时：接 PD 供电的 USB‑C hub（若支持 data+power），或只在短时段插数据线。

## 4. 后续可选题（下一轮立项判据，不在本轮动手）

1. **上游是否已有 charger 控制链**：检索 lore/patchwork `pmic_glink` + `charger` +
   `qti_battery_charger` 是否有人在做 mainline 化；有就按它接。
2. **`qcom_battmgr` 能否加 writable ICL**：需要 PMIC glink 侧有对应 request
   （vendor 走 `QTI_PMIC_CHARGER_*` 命令）；先确认 7.4 的 `pmic_glink.h` 里有没有可发命令的通道。
3. **UCSI 默认值**：`UCSI_TYPEC_DEFAULT_CURRENT 100` 是否该随 `PWR_OPMODE_DEFAULT` + 已配置状态改成 500/900
   —— 只影响 Linux psy 的"上报值"，**不会改变 ADSP 实际限流**，属上游讨论项而非本机修复。
4. **验证 SDP 判定的独立实验**：把设备接到**另一个 SDP 主机**（不同 USB 控制器）看 `usb_type` 是否仍 `Unknown`
   —— 排掉"这台 PC 的端口 Rp/CC 行为特殊"。

## 5. 复现命令（只读）

```sh
ssh root@192.168.7.1 '
  cat /sys/class/udc/a600000.usb/{current_speed,state}
  cat /sys/class/power_supply/qcom-battmgr-usb/uevent
  grep -E "POWER_SUPPLY_(CURRENT_NOW|STATUS|CAPACITY|CHARGE_TYPE)" /sys/class/power_supply/qcom-battmgr-bat/uevent
'
```
