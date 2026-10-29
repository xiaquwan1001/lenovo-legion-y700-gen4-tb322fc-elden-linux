# 双口（长边 USB3 / 短边 USB2）归因：一次接线就能判定的测试协议

> 编排者写，2026-10-29。lane F 的静态调查仍在进行（`reports/usb-dual-port-attribution-20261029.md`），
> 本文件先给出**结论只需一次物理接线就能定**的执行清单。
> 前提事实（本机 vk181 实测，2026-10-29）：
> - `boot_b` = vk181-daily，`uname -v #28`，根 = `ext4 linux17`（Debian），SSH `root@192.168.7.1` 经 USB-NCM（**走长边**）。
> - 内核**已经逐口建模**：`/sys/class/power_supply/` 有 `qcom-battmgr-usb` + `ucsi-source-psy-pmic_glink.ucsi.01/.02`；
>   `/sys/class/typec/` 有 `port0`、`port1`；dmesg 里 pmic-glink 有 `connector@0`（↔`smb1501@0x43`）与
>   `connector@1`（↔`smb1501@0x42`）两个节点，各自绑一颗充电 IC。
> - 当前状态：`qcom-battmgr-usb` ONLINE=1 / 4.728 V / 891 mA（PC SDP，长边）；`ucsi.01` ONLINE=1；
>   `ucsi.02` ONLINE=0（短边空着）。

## 0. 要回答的问题

「长边优先 ⇒ 长边跑数据时短边不能充电」是**固件**（ADSP `battery_charger` 的连接器策略）限制，
还是**系统**（内核/DT/ABI 只把充电接到了第一口）限制？

## 1. 基线（插任何东西之前先记一次）

```sh
ssh root@192.168.7.1 'for d in /sys/class/power_supply/*; do echo "== $d"; grep -E "^(POWER_SUPPLY_NAME|POWER_SUPPLY_ONLINE|POWER_SUPPLY_VOLTAGE_NOW|POWER_SUPPLY_CURRENT_MAX|POWER_SUPPLY_CURRENT_NOW|POWER_SUPPLY_USB_TYPE)=" $d/uevent; done; echo; ls /sys/class/typec/; cat /sys/class/typec/port*/data_role /sys/class/typec/port*/power_role 2>/dev/null'
```

把输出存成 `baseline.txt`。**判据锚点**：`ucsi.01/02` 的 ONLINE、`qcom-battmgr-usb` 的电压与电流。

## 2. 主测试：长边接 PC（保持 SSH 数据），短边接 PD 充电器

顺序很重要，按此执行：

1. 保持长边 USB 接主机（`ssh root@192.168.7.1` 必须一直可用，说明数据在长边）。
2. 短边插入 **PD 充电器**（墙插，不是 PC）。
3. 等 **20 s**（ADSP 连接器状态上报与 PD 协商需要时间；历史实测 PD 从 5 V 跳到 9.4 V 在 10 s 内完成）。
4. 立刻在同一 SSH 会话里跑第 1 节的同一条命令，存成 `after.txt`；再加三条：

```sh
ssh root@192.168.7.1 'dmesg -T | tail -60'
ssh root@192.168.7.1 'cat /sys/class/power_supply/qcom-battmgr-bat/current_now; cat /sys/class/power_supply/qcom-battmgr-bat/status'
ssh root@192.168.7.1 'ls /sys/class/typec/; cat /sys/class/typec/port*/power_role 2>/dev/null'
```

5. 拔出短边充电器，再记一次（可选，用于确认状态回落）。

## 3. 四种结果 → 四种归因（对照 `baseline.txt` 与 `after.txt`）

| # | 观测 | 归因 | 含义 |
|---|---|---|---|
| **A** | `ucsi.02` 仍 `ONLINE=0`、`/sys/class/typec/` 没有 `port1-partner`、`qcom-battmgr-usb` 的 `VOLTAGE_NOW` 不变（≈4.7–5 V） | **固件/硬件级单口** | ADSP 的连接器服务根本没把第二口当独立电源上报；原厂「长边优先」= 该策略的表述，内核无能为力（除逆向 ADSP） |
| **B** | `ucsi.02` 变 `ONLINE=1`，出现过 `port1-partner`，但 `qcom-battmgr-usb` 的**电压/电流不变**、`current_now` 无变化 | **固件策略拒绝**（充电侧不切换） | UCSI 看得见第二口，ADSP 的 charger 只认一口；属 ADSP 策略，非内核 ABI |
| **C** | `ucsi.02` ONLINE=1 且电压上到 9 V/更高，但 `CURRENT_MAX` 仍被压在 100 mA（= `ucsi` psy 的默认值）、`qcom-battmgr-usb` 只报长边的数 | **系统 ABI 单口化** | 内核结构（`qcom_battmgr` 只有一个 usb psy）没把第二口的功率接进来 ⇒ 可在内核侧修 |
| **D** | 短边正常 PD 快充（`qcom-battmgr-usb` 电压升到 9 V+ / `current_now` 明显转正）+ 长边 SSH 数据不断 | **两口可并存** | 原厂「优先」只是默认选择策略/UI 措辞；我们主线缺的只是仲裁与上报（`port-select-gpios` 从「最早者胜」改成「数据口固定长边、充电口任意」） |

## 4. 反向对照（建议同一轮做完，成本 1 分钟）

PC 接**短边**、PD 接**长边**：预期 SSH 断（数据通路固定长边，除非跑 `port-select` 仲裁补丁），
但可看 `ucsi.01`（长边）是否进入 PD、`qcom-battmgr-usb` 是否升压 ⇒ 用于区分「哪个口在 ADSP 眼里是主口」。

> 注意：断 SSH 后无法从主机侧观测，需在设备本地跑记录（`/root/usbprobe.sh` 循环写文件），
> 或用 WiFi（若已连）。本机当前只走 USB-NCM，**建议本轮不做反向对照**，避免失去观测通道。

## 5. 附加只读证据（不插拔也能做，已部分完成）

- `dmesg | grep -iE 'pmic_glink|ucsi|smb1501|aw35615|typec'`：`aw35615` 是 PD 控制器，看它报了几个 port。
- `grep -rn 'aw35615\|smb1501' arch/arm64/boot/dts/qcom/sm8750*.dtsi`（在 `build/m1-73`）：确认 DT 里两个 connector 各绑哪颗充电 IC。
- 厂商 `qti_battery_charger.ko` 的字符串里找 port 相关字段（判断 ADSP↔AP ABI 是否原生多口）。

## 6. 结论怎么用

- 落在 **A/B** ⇒ 双口并存**不可能**在我们这层实现，写进文档作为「固件限制」并关闭该方向；
  原厂 UI 的「长边优先」就是这条固件策略的表述。
- 落在 **C** ⇒ 可直接开工：给 `qcom_battmgr` 增加第二口的 psy（或把 `ucsi.02` 的功率接进
  `power_supply` 聚合），并在 `port-select` 仲裁里把「数据口」与「充电口」解耦。
- 落在 **D** ⇒ 只需改仲裁策略 + 文档澄清，无固件依赖。
