# T18 USB 充电图标/状态抖动 — 初查报告（只读）

日期：2026-11-11 20:02–20:55 ｜ lane：`.pi/lanes/20261111-t18-usb-charging.md`
全程只读（cat / dmesg / journalctl / ps），未重启、未 fastboot、未写分区、未 stop/start 服务。

## §0 结论速览

- **本轮 10 分钟采样窗（20:06–20:17）状态完全稳定**：`status=Charging`、`usb online=1`、`input_current_limit=3000000`、`charge_counter` 单调不降（+34320 µAh，4 次 +1% 台阶）、typec role/partner 零翻转。**未复现抖动**——抖动不是常态而是事件性。
- **现场抓到的翻转在 `charge-watch` 日志里**（设备 `/run/charge-watch.log`）：
  ```
  19:49:48 input_current_limit 0 -> 900000 uA
  19:50:38 input_current_limit 250000 -> 900000 uA
  19:50:48 input_current_limit 250000 -> 900000 uA
  ```
  即插线后 ADSP 把 `input_current_limit` 反复拉到 0/250 mA，用户态守护 10 s 轮询再顶回——两次修正之间的窗口就是「插着电但净放电 → UPower 显示 discharging → 图标跳」。
- **最可能根因（2 个，可并存）**：
  1. **ADSP 侧 ICL/在线状态在重插/协商期间抖动 + 用户态 10 s 轮询去抖不足**（charge-watch 每 10 s 才修一次，且只修 `online=1` 的情况）；AP 无控制面（Q35），只随动。
  2. **电池护理阈值 70/80 驻留**：`charge_control_{start,end}_threshold=70/80`，电量在 80% 附近时 ADSP 主动停充 → status 在 Charging↔Not charging/Discharging 间循环，直到掉回 70%。
- **要用户做的**：下次抖动时跑 §4 的 3 条现场命令（30 秒），即可在候选表中一锤定音。

## §1 现状快照（remoteproc / power_supply / typec）

命令：`for r in /sys/class/remoteproc/remoteproc*; do ... cat name/state; done`（20:02）

```
remoteproc0: adsp state=running
remoteproc1: cdsp state=running
```
→ PITFALLS #390 的「battmgr 全属性 -EAGAIN 因 ADSP/CDSP 没起」**不成立**（双双 running）。

power_supply 节点实际名（lane 里写的 battery/usb 是别名，设备上是）：
`qcom-battmgr-bat / qcom-battmgr-usb / qcom-battmgr-wls / ucsi-source-psy-pmic_glink.ucsi.{01,02}`

`qcom-battmgr-bat`（20:03 与 20:14 两次）：
```
status=Charging  capacity=62→68  charge_counter=4255680→4598880
current_now=+2090000 µA  voltage_now=4.122 V  health=Good
charge_control_start_threshold=70  charge_control_end_threshold=80
model_name=2195MAH_QRD_PAKALASKU1_2S_AVERAGED_MASTERSLAVE_SEPT26TH2023
```

`qcom-battmgr-usb`：
```
online=1  input_current_limit=3000000  current_now=2978000  voltage_now=4436000
current_max=3000000  usb_type=[SDP]   ← 注意：SDP 却给 3A，ADSP 上报口径异常（见 §3）
```

`ucsi-source-psy-pmic_glink.ucsi.01`（当前插的口）：`online=1 status=Charging usb_type=C [PD]`，但 `current_max=0 / charge_type=Trickle`（UCSI 视角自相矛盾，值不可信）。
`ucsi-source-psy-pmic_glink.ucsi.02`：`online=0 status="Not charging"`（空口，正常）。

typec：
```
port0: data_role=[device] power_role=[sink] partner=port0-partner(PD capable)
port1: data_role=[host]  power_role=[sink] partner 无
```

## §2 长时窗采样结果

CSV：`reports/artifacts/t18-sampling-20261111/t18-sampling.csv`（120 行 × 5 s，20:06–20:17，设备 `/tmp/t18-sample.sh` 采集后 scp 回仓）。

统计（python 对 CSV）：
```
bat_status flips=0    {'Charging'}
usb_online flips=0    {'1'}
usb_type   flips=0    {'SDP'}
ucsi1_online flips=0  ucsi2_online flips=0
port0/port1 role、partner flips=0
charge_counter: first=4324320 last=4598880  Δ=+34320（4 次正台阶 +68640，其余 0；无负台阶）
  → 每步 +68640 µAh = charge_full 的 1%（计数器按 1% 台阶更新，正常）
icl uniq=[3000000]  usb_i_now≈2.78–2.98 A  bat_i_now=+1.0–2.1 A（净充电）
```
**结论：本窗口内翻转与 charge_counter 符号无冲突可言（无翻转）；净电流为正，充电真实成立。**

伴随内核日志（同窗口）：
```
[三 11月 11 20:03:24 2026] [ C0] qcom_smd_qrtr 6800000.remoteproc:glink-edge.IPCRTR.-1.-1: invalid ipcrouter packet
…（20:03–20:13 共 13 条，约每 1–2 分钟 1 条；整个 boot 累计 122 条）
```
ADSP glink 链路上有持续的低频坏包，与 battmgr 属性瞬时 -EAGAIN 是同一类症状的候选源，但本窗口未造成可见属性翻转。

## §3 候选根因与区分判据表

| # | 机制假设 | 支撑证据 | 反对证据 | 一发判据（设备上看到什么） | 处置（优先非内核） |
|---|---|---|---|---|---|
| 1 | **PD/硬件重协商抖动** | — | 本窗 10 min typec role/partner/usb_type **零翻转**；整个 boot dmesg 无一条 role swap / PD contract 日志（grep `role swap\|power role\|pd contract\|vbus\|vconn` 仅启动期 dependency 噪声） | 抖动瞬间 `typec/port*/power_role` 或 `port*-partner` 出现/消失 | 若成立：显示层去抖即可，硬件问题另查线材 |
| 2 | **ADSP 选口/在线状态抖动（Q35）+ charge-watch 10 s 轮询修复间隙** | `/run/charge-watch.log` 19:49:48 `0→900000`、19:50:38/48 `250000→900000`；脚本注释自证「每次重插 ADSP 重置 ICL（甚至 100 mA）」；AP 无控制面 | 本窗 ICL 恒 3M 零翻转 | 抖动瞬间 `usb/online` 或 `input_current_limit` 突降（0/100000/250000/500000）且 `charge_counter` 出现负增量 | **charge-watch 改进**：轮询 10 s→2 s；`online=0` 时也记录/上报而不是跳过；UPower 侧对 line_power online 做 ≥15 s 去抖 |
| 3 | **净电流判定（PITFALLS #568）** | 历史报告 `reports/driver-ab-charging-20261008`：两条启动路径都曾卡 500 mA SDP 亮屏净放电 | **本次实测 ICL=3A、+1.6–2.1 A 净充电**，568 的 500 mA 现象此刻不复现（ charger/线/口不同？） | 抖动时 `input_current_limit`≤500000 且 `battery/current_now`<0 | udev 规则固化 ICL 下限（如 `ATTR{input_current_limit} < 500000 → 写 3000000`），不依赖轮询周期 |
| 4 | **battmgr -EAGAIN 间歇（glink 坏包）** | `qcom_smd_qrtr … invalid ipcrouter packet` 整 boot 122 条、本窗 13 条，与 ADSP 链路一致；ADSP/CDSP 均 running（#390 排除「没起」） | 本窗所有属性 cat 均成功，无 -EAGAIN 空值 | 抖动时对属性 `cat` 返回空/EIO，或 dmesg 坏包密度骤增 | 属内核/固件域（qcom_smd_qrtr/glink），短期只能显示层容忍；取证留 dmesg |
| 5 | **用户态去抖缺失（phosh/UPower）** | phosh 图标直接跟 UPower DisplayDevice state；upowerd 对 `POWER_SUPPLY_STATUS`/`online` 变化即时反映，无 hysteresis | upower journal 今日无异常条目 | 对比 upower History：抖动时 `upower -d` history 出现密集 charging↔discharging 交替（秒级） | UPower 无内置去抖 → 上面 #2/#3 的 udev/轮询方案在源头消化；或 GNOME 层忽略 <30 s 的 state 跳变 |
| 6 | **70/80 电池护理阈值驻留** | `charge_control_start/end_threshold=70/80`（存在且生效）；用户「以前也出现过」= 慢性现象 | 本窗 capacity 62→68 未到 80；`/etc/charge.conf` 不存在，`charge-watch` 未在管阈值（谁设的 70/80 待查，可能是 charge-ctl 手动历史值或 ADSP 默认） | 抖动时 `status=Not charging`/`Discharging` 且 `capacity` 在 78–81 区间徘徊 | 若确认：把 LIMIT 关掉或窗口调宽（start=65/end=85），一处配置，非内核 |

**排除项**：启动路径/模块加载（`reports/driver-ab-charging-20261008/20261108` 已证两路电源面一致）；ADSP/CDSP 未起（均 running）。

## §4 「重不上电」单独分析

**与 §2 抖动很可能同源**：charge-watch 日志显示插线后 ICL 被置 0（`19:49:48 input_current_limit 0 -> 900000`）——即 ADSP 检测到 VBUS 但没批准充电（online 可能仍为 1 或干脆 0）。若这次用户态也没把它顶回去（守护轮询间隔内恰逢条件不满足，或 `online=0` 直接被脚本跳过），就表现为「插着不充」。

区分判据（重不上电发生时）：
- `dmesg -T | grep -iE "new high-speed|new SuperSpeed|usb .*reset"` **有**枚举记录 → 硬件/PD 层 OK，是 **ADSP 没批准充电**（`usb/online=0` 或 `input_current_limit≈0/100000`）→ 候选 #2/#3。
- **无**枚举记录且 `typec/port*-partner` 不存在 → 物理口/线/CC 检测问题 → 换口/换线验证（与双口选口策略 Q35 交叉：另一口是否被 ADSP 判死）。

**用户现场检查 3 条**（重不上电时依次执行，只读）：
1. `cat /sys/class/power_supply/qcom-battmgr-usb/online /sys/class/power_supply/qcom-battmgr-usb/input_current_limit` —— online=0？ICL≈0/100000？
2. `dmesg -T | tail -30 | grep -iE "usb|typec"` —— 有没有 `new high-speed USB device` 枚举？
3. `tail -5 /run/charge-watch.log` —— charge-watch 最近有没有在做修正（时间戳对比当前时间）？

## §5 建议处置（按优先级）

1. **纯用户态，先做**：`scripts/charge-watch.sh` 轮询 10 s→2 s，并把 `online=0` 情况也写日志（当前直接跳过，丢证据）。风险零。
2. **纯用户态**：udev 规则兜底 ICL：`SUBSYSTEM=="power_supply", KERNEL=="qcom-battmgr-usb", ATTR{online}=="1", ATTR{input_current_limit}<="500000", ATTR{input_current_limit}="3000000"`（数值比较语法需在设备上试跑 dry-run， ACTION=="change"）。
3. **纯用户态/显示层**：确认 70/80 阈值来源后按需放宽（§3#6），或接受该抖动为电池护理预期行为并在文档登记口径。
4. **显示层去抖（phosh/UPower 不可配，需小补丁或 GNOME 扩展）**：仅当 1–3 落地后仍抖才做。
5. **内核域（暂不动）**：`qcom_smd_qrtr invalid ipcrouter packet`（glink 坏包）与 UCSI psy `current_max=0/Trickle` 矛盾——先持续取证，攒够再立项（可能与上游 sm8550+ 已知问题同源）。

## §6 未做/待用户动作

- **未复现抖动本身**（10 min 窗稳定）：候选表 #1/#2/#4/#5/#6 的「一发判据」都标注了抖动瞬间要看什么；需要用户下次抖动时执行（或授权一条后台只读监视脚本，本 lane 未获授权故未挂）。
- 未插拔、未换口（lane 禁止物理动作）；「重不上电」未发生，无法现场取证。
- `charge_control_*_threshold=70/80` 的设置来源未定位（`/etc/charge.conf` 不存在；charge-watch 未在管阈值）——下次可查 `journalctl` 历史 charge-ctl 调用。
- 采样 CSV 仅一窗；如需复核可再跑 `sh /tmp/t18-sample.sh`（脚本仍在设备 /tmp）。
