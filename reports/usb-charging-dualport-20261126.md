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
| ~~900 mA 超规范取电 + `v_bus` 4.52 V 洼地~~ | ✅ **已做（2026-11-26 11:2x CST）** | `scripts/charge-watch.sh` 加 sag guard（见 §7）；**阈值口径被上机数据改过一次**（4.60 V → 4.40 V） |
| ~~日常化路径~~ | ✅ **已做（2026-11-26 11:2x CST）** | `deploy-desktop-shell.sh` **§17** 固化三件（脚本逐字节一致 + unit enabled/active + ICL 判据），`--check` 实测 **MISS 3 → 0**；重建根不会再丢 |
| 更优物理组合（免改内核） | `human-gated`（要插拔） | 反向接法：**数据线插短边 + PD 线插长边**（`usb-ports-consolidation-20261125.md` §2 记录 ≈1.9 A、非快充）；或只插短边 PD（46 W，SSH 断） |

## 6. 常用只读命令

```sh
U=/sys/class/power_supply/qcom-battmgr-usb B=/sys/class/power_supply/qcom-battmgr-bat
cat $U/usb_type | grep -o '\[.*\]'     # 现场 usb_type
cat $U/input_current_limit $U/current_max
cat $B/current_now $B/capacity           # battery 电流 >0 = 充电
systemctl is-enabled charge-watch.service; tail -5 /run/charge-watch.log
```

## 7. 洼地保护 + 部署面固化（2026-11-26 11:2x CST，本轮收尾）

### 7.1 阈值被上机数据改过：4.60 V 是**误判线**

第一版把「连续 3 次 `v_bus` < 4.60 V」当超载 ⇒ 上机立刻触发：

```
11:20:28 SAG v_bus=4470000 uV < 4600000 x3 -> drop ICL to 700000 uA
```

降档后实测 **电池 −284 mA（又变净放电）**，而同一根线 900 mA 档已稳定跑过 3 min（4.47–4.52 V 从未被 OCP 掐断）
⇒ **4.5 V 附近是本机 PC 端口在 891 mA 下的稳态 droop，不是塌陷**。改成：

| 参数 | 值 | 依据 |
|---|---|---|
| `SAG_UV` | **4 400 000**（4.40 V） | 只在真塌陷时降档（4.5 V 稳态必须放行） |
| `ICL_FLOOR` | **500 000** | 降档取 SDP 规范上限，端口优先；此档可能仍净放电 = 已知代价 |
| `RECOVER_UV` / `RECOVER_SAMPLES` | 4.60 V / 15 次（≈30 s） | 稳定恢复才抬回 |
| `MAX_TRIES` | 2 | 一次插着期最多试 2 次，避免反复顶档抖 |

改后实测（60 s × 12 采样）：`ICL=900000` 恒定、`v_bus` 4.445–4.475 V、电池 **+32…+75 mA**、**零降档记录**。

### 7.2 判据自证（`--selftest`，假 sysfs 驱动真状态机）

`bash scripts/charge-watch.sh --selftest` ⇒ **10 断言 / 7 组全 PASS**：首次顶档、3 次洼地降档、降档幂等、
恢复后抬回 + 尝试计数、二次降档/抬回、`MAX_TRIES` 用尽后保持 floor、拔线复位后重新顶档。
（用 `USB=`/`BAT=`/`LOG=` 环境变量指向 `mktemp -d` 假节点，不碰真硬件。）

### 7.3 部署面：`deploy-desktop-shell.sh` **§17**

三件判据（缺一即 MISS）：① 两脚本与仓内**逐字节一致** ② `charge-watch.service` enabled+active
③ online 时 `ICL ≥ 500000`。设备实测 **MISS 3 → 0**（补齐 `charge-watch.sh` 新版 + `charge-icl-fix.sh`
+ `rootfs/debian/udev/90-elden-charge.rules`），`--check` 复跑幂等 0。

⚠ 注意：`#734` 里「脚本在 ≠ 服务在」这个形态在 `--check` 上是**一条独立判据**（②），
不能靠 ① 或 ③ 兜住——① 只证明文件对，③ 只证明当下值对（手动写过一次也满足）。
