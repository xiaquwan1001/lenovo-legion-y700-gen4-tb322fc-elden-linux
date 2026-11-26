# 双口同插「插着充不进电」定因与修复（2026-11-26，U1 在机）

> 场景（用户报告）：**长边 = USB 数据线连 PC（USB-NCM，SSH 链路）** + **短边 = PD 充电线**，默认设置下 battery 净放电。
> 结论一句话：**取电口被 ADSP 钉在长边（SDP），而 ADSP 对 SDP 默认只给 `input_current_limit = 100 mA`；仓里早就有把 ICL 顶到 `current_max` 的 `charge-watch` 服务，但它的 unit 从未装到设备上** ⇒ 没有人顶回，净放电 ≈ −0.77 A。
> 修复 = 装 unit（一条命令，已完成），ICL 顶到 900 mA ⇒ 转为 +0.13 A 充电。

## 1. 现场读数（默认状态，修复前）

`ssh elden-root`，30 s × 6 采样，值稳定：

| 面 | 值 |
|---|---|
| `qcom-battmgr-usb/online` | 1 |
| `qcom-battmgr-usb/usb_type` | `Unknown [SDP] …` ⇒ **现场值 = SDP**（`PITFALLS #726` 口径：方括号才是当前值） |
| `qcom-battmgr-usb/input_current_limit` | **100000**（ADSP 默认；配 `current_max = 900000`） |
| `qcom-battmgr-usb/current_now` / `voltage_now` | 403 mA / 5.52–5.58 V |
| `qcom-battmgr-bat/current_now` | **−748 … −804 mA**（= 净放电） |
| `qcom-battmgr-bat/status` | `Charging`（**该字段别信**，D14 已记） |
| `qcom-battmgr-bat/capacity` | 25%，`charge_control_end_threshold=80`（Battery Care 未生效于低电量，与本题无关） |
| `typec/port0-partner`（长边 = PC） | `supports_usb_power_delivery=no` |
| `typec/port1-partner`（短边 = PD 线） | `supports_usb_power_delivery=yes` |
| `ucsi-source-psy-pmic_glink.ucsi.02`（短边） | `usb_type = C [PD] PD_PPS`、**`current_max=0`、`voltage_now=0`** ⇒ PD 契约在，但**没有被取电** |
| dmesg | `PDR: Indication received from msm/adsp/charger_pd, state: 0x1fffffff`；无 `unknown message` |

⇒ 与 `reports/usb-ports-consolidation-20261125.md` §2 的 Q35 口径一致：**两口同插时 ADSP 只从长边取电**，短边 PD 契约保留但不取电。

## 2. 三个 ICL 档的 A/B（同一根线、同一台 PC，各 60–180 s）

`echo <uA> > /sys/class/power_supply/qcom-battmgr-usb/input_current_limit`（`-rw-r--r-- root`，本机内核**可写** ⇒ 与 `reports/m12-daily-already-writable-20261125.md` 一致）：

| ICL | USB 侧实际取电 | 电池 `current_now` | 结论 |
|---|---|---|---|
| 100000（默认） | 403 mA @ 5.53 V | **−770 mA** | 净放电（用户报的现象） |
| 500000（USB 规范 SDP 上限） | 494 mA @ 4.74 V | **−270 mA** | **仍然净放电** ⇒ 只按规范设 500 mA 不够 |
| 900000（= `current_max`） | 891 mA @ 4.52–4.57 V | **+126 … +137 mA** | 转正，稳定 180 s（cap 25% 未掉） |

三条工程事实：

1. **系统负载 ≈ 0.77–1.0 A** ⇒ 只要输入 < 0.77 A 就是净放电。500 mA 档不是「慢充」而是「仍掉电」，这是本轮新判据（此前只记 500/900 两档幅度差）。
2. **900 mA 档要超规范从 SDP 端口取电**（USB 2.0 SDP 只保证 500 mA），现场 `v_bus` 从 5.5 V 洼到 **4.52 V**（低于 4.75 V 规范下限）⇒ 该 PC 端口在超载。若换到限流更严的端口，可能被 OCP 掐断，需要按端口实测（`scripts/charge-watch.sh` 目前无电压洼地保护，记为已知风险）。
3. `dmesg | grep -c 'unknown message'` = **0** ⇒ ADSP 接受 `0x33` 写 opcode（M12 结论在现役日常核上同样成立）。

## 3. 真根因：服务存在，但 unit 从未部署（不是缺能力）

设备侧现状（修复前）：

```
$ systemctl is-enabled charge-watch.service ; systemctl is-active charge-watch.service
not-found
inactive
$ sha256sum /usr/local/sbin/charge-watch.sh /usr/local/sbin/charge-ctl.sh
4a8870f2dea620214a73361e427db74b312b704b4c0e7938d37a67063bf7aed7  /usr/local/sbin/charge-watch.sh
4757f6a9e8909b188329e98679a1d1d3cd4a04cea5ccd6cf3a7cb7326756e0b1  /usr/local/sbin/charge-ctl.sh
```

两个脚本**逐字节等于仓内 `scripts/`**（`scripts/charge-watch.sh`、`scripts/charge-ctl.sh`），但
`/etc/systemd/system/charge-watch.service` **不存在**、`/run/charge-watch.log` 不存在 ⇒ 脚本从来没被拉起。
`charge-watch.sh` 的注释还写着「Started by /init (see patch-init-charge.sh)」= **Alpine 期的启动路径**，并根到 Debian+systemd 之后没有任何东西接它（与 `PITFALLS #689/#700` 同族：并根丢的是「启动接线」，脚本还在）。

## 4. 修复（已执行，2026-11-26 10:58 CST）

```sh
scp packaging/elden-userland/out/units/systemd/charge-watch.service elden-root:/tmp/
ssh elden-root 'install -m 644 /tmp/charge-watch.service /etc/systemd/system/ && \
  systemctl daemon-reload && systemctl enable --now charge-watch.service'
```

验证：

- `is-enabled = enabled`、`is-active = active`；`/run/charge-watch.log` = `started` / `usb node appeared after 0 s` / `input_current_limit 100000 -> 900000 uA`
- **重插等价性**（手工把 ICL 按回 100000 模拟 ADSP 重插重置）：**≤2 s 内被顶回 900000**，日志记一行
- 电池从 −770 mA 变为 **+101 … +137 mA**（`charge-ctl.sh status` 亦可查）

## 5. 仍未解决 / 下一步

| 项 | 分类 | 说明 |
|---|---|---|
| 短边 PD 不取电 | `upstream-gated`（ADSP） | Q35 已判「不再投入」；AP 侧只能观测（`ucsi.02 current_max=0`），要改得 ADSP/厂商给选口接口 |
| 900 mA 超规范取电 + `v_bus` 4.52 V 洼地 | `local-actionable` | 候选：`charge-watch.sh` 加电压洼地保护（连续 N 次 < 4.60 V 就降到 700000），需先在 2–3 台不同 PC 端口采 `v_bus` 分布 |
| 日常化路径 | `local-actionable` | unit 已在设备但**不在** `deploy-desktop-shell.sh`/`stage.sh` 的部署面 ⇒ 重建根会再丢一次；应把 unit 装进部署脚本并加判据（`is-enabled` + `ICL == current_max`） |
| 更优物理组合（免改内核） | `human-gated`（要插拔） | 反向接法：**数据线插短边 + PD 线插长边**（`usb-ports-consolidation-20261125.md` §2 记录 ≈1.9 A、非快充）；或只插短边 PD（46 W，SSH 断） |

## 6. 常用只读命令

```sh
U=/sys/class/power_supply/qcom-battmgr-usb B=/sys/class/power_supply/qcom-battmgr-bat
cat $U/usb_type | grep -o '\[.*\]'     # 现场 usb_type
cat $U/input_current_limit $U/current_max
cat $B/current_now $B/capacity           # battery 电流 >0 = 充电
systemctl is-enabled charge-watch.service; tail -5 /run/charge-watch.log
```
