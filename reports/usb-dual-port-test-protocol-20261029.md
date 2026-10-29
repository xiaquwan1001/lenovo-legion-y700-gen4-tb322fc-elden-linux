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

---

## 7. 附录：静态证据（编排者采集，2026-10-29，可复核）

lane F 在 21 轮后卡在长思考、未落盘（已记入会话总结），下列事实由编排者直接取自主机与设备，
均为「命令 + 原始输出」级证据。

### 7.1 内核是**逐口建模**的（已证）

设备侧（`ssh root@192.168.7.1`）：

```
# /sys/class/power_supply/ → qcom-battmgr-bat / -usb / -wls
#                            ucsi-source-psy-pmic_glink.ucsi.01 / .02
# ucsi.01: ONLINE=1  5000000 uV  current_max=100000   usb_type 当前=C
# ucsi.02: ONLINE=0        0 uV  current_max=0
# /sys/class/typec/ → port0, port0-partner, port1
# port0: data_role=device  power_role=sink  orientation=normal
```

DT 侧（`build/m1-73/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts:1287-1341`）：

```
pmic_glink: pmic-glink { compatible = "qcom,sm8750-pmic-glink", "qcom,sm8550-pmic-glink", "qcom,pmic-glink";
    connector@0 { compatible = "usb-c-connector"; reg = <0>; data-role = "dual"; ... }
    connector@1 { compatible = "usb-c-connector"; reg = <1>; data-role = "dual"; ... }
```

dmesg：`pmic-glink` 为 `connector@1` 记录 supplier `5-0042`、为 `connector@0` 记录 `5-0043`
（两颗 SMB1501），两者都挂 `a600000.usb`；另有 4 条
`Failed to create device link (0x180) with supplier … for /pmic-glink/connector@{0,1}`
（`0x180` 是 `dl_flags` 位组合，不是错误码；**是否影响两口并存未判**）。

⇒ 结论 1：**「内核只认一个口」不成立**——端口、连接器、充电 IC 都是逐口的。

### 7.2 充电功率在 ABI 层被压成单口（已证，属系统侧）

上游 `build/m1-73/drivers/power/supply/qcom_battmgr.c`：

```
322:	struct power_supply *bat_psy;
323:	struct power_supply *usb_psy;
324:	struct power_supply *wls_psy;
1788:	battmgr->usb_psy = devm_power_supply_register(dev, &sc8280xp_usb_psy_desc, ...);
1812:	battmgr->usb_psy = devm_power_supply_register(dev, &sm8350_usb_psy_desc, ...);
```

⇒ 每个 battmgr 实例**只注册一个 `usb_psy`**。设备上实测同理：只有 `qcom-battmgr-usb` 一个充电 psy，
两个口的状态落在两个 `ucsi-source-psy-*` 上，而 UCSI psy 的 `current_max` 只有 100 mA（并非实际充电通道）。

⇒ 结论 2：**即使 ADSP 支持双口，上游 ABI 也没有表达「第二口在充电」的位置**——这一半是系统限制。
但这不代表实测会落 C（见 §3 判据表：还要看 ADSP 是否把第二口上报）。

### 7.3 未证实的部分（不写结论）

- ADSP `battery_charger` 固件是否支持双口同时在线（厂商 `qti_battery_charger` 的 ABI 里是否有 port 概念）——
  需反汇编厂商 `vendor_dlkm/qti_battery_charger.ko` 或读 `reports/m2-a2-vendor-qbg-20261028.md` 的结论边界。
- 那 4 条 `Failed to create device link (0x180)` 的后果。
- 「短边插 PD 时 ADSP 是否升压」——只有 §2 的物理测试能定。

---

## 8. 实测结论（2026-10-29 20:13–20:24，用户物理插拔，采样脚本在机）

采样脚本每 2 s 记录一次（`/tmp/usbprobe.sh`，日志 `usbprobe.log` / `usbprobe2.log`）。
`bat` = `qcom-battmgr-bat/current_now`（正 = 充入），`u1/u2` = 两个 UCSI psy 的 `online`，
`usbv/usbi` = `qcom-battmgr-usb` 的电压/电流，`p1part` = `/sys/class/typec/port1-partner` 是否存在。

### 8.1 三段状态（原始读数节选）

| 时间 | 插法 | bat (µA) | u1 | u2 | usbv | usbi | 判读 |
|---|---|---|---|---|---|---|---|
| 20:13–20:15:33 | 长边=PC(SDP) + 短边=PD | 290 000–326 000 | 1 | 1（契约 3 A） | 5.05 V | 891 mA | 只吃长边那一路 |
| 20:15:35–20:19:26 | 拔掉短边 PD | 190 000–390 000 | 1 | 0 | 4.71 V | 891 mA | 同上，短边 PD 无贡献 |
| **20:19:28–20:20:08** | **拔掉长边 PC，只留短边 PD** | **199 000 → 12 210 000（40 s 内爬升）** | **0** | **1** | 1.0–1.2 V（异常读数，见 8.3） | 9–12 mA | **短边 PD 单独 = 真快充** |
| 20:24:23–20:24:38 | 长边 PC 插回 + 短边 PD | 184 000–191 000 | 1 | 1 | 4.72 V | 891 mA | **立刻回落到长边 0.9 A** |

电池容量侧证据：PD 单独供电那 4 分钟里 `capacity` 从 **19% → 27%**（≈ +600 mAh，与 12 A 峰值量级一致）。

### 8.2 结论（对应 §3 判据表）

- **落在 C 与 B 之间，且更靠近「固件选口」**：
  - **不是 A**（固件看不见第二口）——`ucsi.02` 上线、`port1-partner/pd0` 存在、PD 契约 3 A 谈成；
  - **不是 D**（两口可并存取电）——两口同时插时电池只有 0.19 A，短边 3 A 完全不用；
  - **物理能力上完全没问题**：短边 PD 单独跑出 **12.2 A / ≈46 W**，充速远超长边 SDP。
- ⇒ 「长边优先」= **ADSP `battery_charger` 的选口策略**：两口都在时选中长边，短边 PD 契约保留但不取电。
  AP 侧（内核）**没有任何控制面**能改这个选择：`qcom_battmgr-usb` 只是**只读地跟随被选中的那一口**
  （插 PD 时它报 5.05 V = PD 的 5 V 档；拔掉 PD 后报 4.71 V = PC SDP 实际电压）。
- ⇒ **归因 = 固件限制**（ADSP 策略），不是系统限制、也不是硬件单口。

### 8.3 已知异常（不解释成因）

只留短边 PD 时 `qcom-battmgr-usb` 的 `voltage_now` 读到 **1.0–1.2 V**、`current_now` 9–12 mA，
与「电池在吃 12 A」矛盾 ⇒ 该 psy 在此状态下报的**不是** VBUS，而是另一路（ADSP 未按口区分）。
**这是 `qcom_battmgr` 单 psy 结构的直接后果**：它只能表达"一口"，多口时读数归属不清。

### 8.4 实用建议（想同时要「数据 + 快充」）

1. **反过来接**：PD 插**长边**（USB3 口，PD 走长边充电）、数据线插**短边**。这样充电走 ADSP 选中的长边快充，
   数据走短边 USB2（对 SSH/网络足够）。**前提**：主线要把数据通路从"gpio29 固定长边"改成仲裁
   （`port-select-gpios`，即 M3-1 系列补丁）——这正好给 M3-1 增加了一个**用户可见的实用动机**。
2. 若坚持"PC 在长边 + PD 在短边"，则只能接受 **0.9 A（SDP）**，除非 ADSP 换策略（无 AP 接口）。
3. 可选内核改进（非必需）：把两个 `ucsi-source-psy-*` 聚合出一个"总输入功率"影子 psy，
   或在 `qcom_battmgr` 增加第二口 psy —— 只改善**可观测性**，不改变选口行为。
