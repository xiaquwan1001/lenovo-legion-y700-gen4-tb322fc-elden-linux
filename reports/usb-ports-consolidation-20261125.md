# 双口 USB（长边/短边）事实总账 —— 单一可核对表（2026-11-25）

> 汇总件：只做归并，不新增结论。标注口径：`[实测]` = 原始读数/命令级证据；`[文档]` = 既有文档转述；
> `[推测]` = 本件推断，无独立证据。设备不在线，本轮零上机命令、零写设备。
> 上游事实正文：`DEVICE/README.md` §1.4（本表与之冲突时不改它，见文末冲突清单）。

## 1. 口位事实表

命名：**长边** = `usb@a600000` + QMP SS PHY + DP altmode（USB3 口）；**短边** = `usb_dwc3_hs2`（USB2 口）。
`[文档]` DEVICE/README.md §1.4；DT 节点 `connector@0`/`@1` 各绑一颗 SMB1501
（`[实测]` dmesg supplier `5-0042`/`5-0043`，`usb-dual-port-test-protocol-20261029.md` §7.1；
`[文档]` 2026-11-21 更正：live FDT 里 `0x42/0x43` 是 `fcs,fsa4480` SBU mux，SMB1501 实为 `@68/@69`，两颗是否存在降级为未证 —— DEVICE/README.md §1.4）。

| 维度 | 长边（USB3） | 短边（USB2） | 证据 |
|---|---|---|---|
| **充电（PD）** | PD 可用：反向接法 `.01` 报 PD、`qcom-battmgr-usb` 8.81–8.87 V / 1.46–1.62 A（与 SDP/PD 标识不一致，归属未证） | 单独插 PD = 真快充：电池 0.199→12.21 A（40 s），capacity 19%→27%（≈46 W） | [实测] DEVICE/README.md §1.4（2026-10-30 反向接法段；2026-10-29 表）；protocol §8.1 |
| **充电（SDP）** | PC SDP：`qcom-battmgr-usb` 4.71–5.05 V / 891 mA；两口同插时 ADSP 只吃长边这一路 | `usb_type` 现场值 `[SDP]`（PITFALLS #726：方括号才是当前值）；固件默认 `input_current_limit=100000`（配 `current_max=900000`），链路 `high-speed`+`configured` 规范允许 500 mA ⇒ 净放电 ≈0.8 A | [实测] protocol §8.1；[实测] usb-charging-sdp-limit-20261125.md §1.2/1.3 |
| **充电（CDP）** | 未取证 | 未取证 | — |
| **ICL 可写** | backport 后两口共用同一写入口：`echo 500000|900000 > qcom-battmgr-usb/input_current_limit` 回读一致、`unknown message`=0 | 同左；A/B 实测 500 档电池电流 ~100–166 mA、900 档 ~480–527 mA | [实测] m12-upstream-test-20261125.md §0/§2（be5e7367bceb 与 Venkat v2） |
| **数据** | fastboot/ABL/bootloader 阶段**只有长边**枚举（短边 `fastboot devices` 空、无 18d1）；Linux 期未单独取证长边主机模式 | 反向接法（数据线插短边）SSH 可用；具体速率未取证 | [实测] DEVICE/README.md §1.4 ★段；[实测] DEVICE/README.md §1.4 反向段 |
| **gadget（日常 SSH 链路）** | 当前日常链路走长边：NCM `usb0` = 192.168.7.1，gadget 绑 `a600000.usb`，`current_speed=high-speed`、`state=configured` | 短边 gadget 枚举：未取证（仅确认反向接法数据通，推断走 hs2 路径） | [实测] protocol §0/§7.1；[实测] usb-charging-sdp-limit-20261125.md §1.2 |
| **gadget（NCM 网段 / 串口）** | `usb0` 192.168.7.1（NCM，`scripts/ncm-host-up.sh`）；`ttyGS0` 串口 = `scripts/acm-sh.py`（口位归属未分口取证） | 同左 | [文档] DEVICE/README.md §1.6 ①/③ |
| **显示（DP altmode）** | 走**长边**：`mdss_dp0` + `card0-DP-1` connected/enabled，EDID `F27G32Q Pro` 2560×1440@180 preferred，`typec/port0-partner` 出现 | 无 DP altmode（hs2 无 SS PHY 路径） | [实测] TASKS §1 G1-9（dp5 实机判据全过）；[文档] DEVICE/README.md §1.4 |
| **role switch / typec 编号** | `usb@a600000-port0-role-switch`（`waiting_for_supplier=0`）；`/sys/class/typec/port0`（G7 轮 `orientation=reverse`，早期轮 `normal`）；`data_role=host [device]`（无 partner 常态） | `a600000.usb-port1-role-switch`（同 0）；`/sys/class/typec/port1`；换口→mux 由 GPIO29 电平代理（`out low`↔`out high`），mux_state 无 sysfs 观测面 | [实测] g7-routeA-dtfix-20261123.md §7 表/§104–108/§177–185 |

DP 真根因链（G1-9 / Q11，[实测]）：`PPM init failed` = `ucsi_init` EPROBE_DEFER 20 次放弃 ← role switch 未注册 ← `dwc3_drd_init` 仅 `dr_mode=otg` 才跑而 DTS 写死 `peripheral` 且被 `/delete-property/ usb-role-switch` 强制回 peripheral。修复 = `dr_mode=otg` + `usb-role-switch` + `mdss_dp0 okay` 三处同批（内核 `6c1376907`）。**与 ADSP UCSI 无关。**

## 2. 双口策略（Q35 定案口径）

**「物理可行、被 ADSP 选口策略挡住」的确切含义**（[实测] protocol §8.2）：
- 被选的口 = **长边**：两口同插时 ADSP 只从长边取电（SDP 891 mA），短边 PD 契约保留但不取电（电池仅 0.19 A）。
- 反向接法（PD 插长边 + 数据线插短边）观察到的现象：SSH 数据可用 + 充电并存（100%、~1.9 A），但非快充；原「需 M3-1 仲裁才有数据」被此观察推翻，热切换/启动期仲裁未验证（TASKS §7 M3-1）。
- AP 侧只读证据：`qcom-battmgr-usb` 只读跟随被选中口（插 PD 报 5.05 V，拔掉报 4.71 V）；两口同插时 `ucsi.01/02` 均 online、`port1-partner/pd0` 存在 ⇒ 不是「内核只认一口」（两 `typec/port*` + 两 `ucsi-source-psy-*`）。

**当前可用组合**（[实测]）：
1. 长边 PC(SDP) 数据 + 短边 PD 快充——被选口策略挡住：实际只吃长边 0.9 A（= 明确不可用支，列出供对照）。
2. 短边 PD 单独 = 46 W 快充（无数据）。
3. 长边 SDP 单独 = 数据 + 0.9 A 慢充（ICL 100 mA 档时为净放电，见 §3）。
4. 反向接法：短边数据 + 长边充电并存（已证非快充档；热切换未验）。

**明确不可用组合**：
1. 长边数据 + 短边快充（两口同插取电被 ADSP 钉在长边）——除非 ADSP 提供选口接口（Q35 判「不再投入」）。
2. 短边进 fastboot（ABL/bootloader 只认长边数据）——自建 BL 归远期。
3. 短边 DP altmode（无 SS/DP 硬件路径）。

## 3. SDP 100 mA 链（现象 → 根因 → 上游 → backport）

1. **现象**（[实测] usb-charging-sdp-limit-20261125.md §1）：`usb_type=Unknown [SDP] …`（现场值 = **SDP**，PITFALLS #726）、`input_current_limit=100000`、`current_max=900000`；`capacity` 51→50 / 100 s、`current_now`≈−820 mA 而 `status` 仍 Charging（该字段别信）。
2. **根因**（[实测] §1.4 + D14）：mainline `qcom_battmgr` 的 USB psy 只读（`qcom_battmgr.c:1080` 无 `set_property`）⇒ 无写入口；缺 vendor `qti_battery_charger`/`usbpd`→ADSP 链（PMIC glink 客户端只有 altmode/ucsi/pd/battmgr）⇒ 固件默认 ICL 100 mA。UCSI `UCSI_TYPEC_DEFAULT_CURRENT=100` 只是上报值，不影响实际限流。
3. **上游已覆盖**（[实测] m12-upstream-test-20261125.md）：Joonhoe Kim 的实现被 Sebastian 收录为 **`be5e7367bceb`**（30 行）；Venkat v2 补「早下发 + 只对 SDP/CDP/PD」。上机 A/B：两件均写 900000↔500000 回读一致、`unknown message`=0；500 mA 档电池电流 ~100–166 mA vs 900 档 ~480–527 mA（方向一致可重复；900 档被该 PC 的 SDP 端口顶在 ~500 mA）。⚠ `current_now` 在本板不可作限流判据（500 mA 档读到 +1.14 A 物理不可能）。
4. **backport 最小动作**（[文档] M12 行 + patches README ⛔ 裁决）：
   - 30 行 = `be5e7367bceb`：`sm8350_usb_psy_desc` 加 `.set_property`/`.property_is_writeable`（只放行 `INPUT_CURRENT_LIMIT`）+ 写走 `BATTMGR_USB_PROPERTY_SET(0x33)`/`USB_INPUT_CURR_LIMIT(5)` + 变体回调两处 switch 各补 `case BATTMGR_USB_PROPERTY_SET: battmgr->error = 0; break;`（否则报 `unknown message 0x33`，`qcom_battmgr.c:1387/1591`）。参考件：`patches/upstream/charger-icl-20261125/upstream-be5e7367bceb.patch`。
   - `current_now` 不可作判据的原因：500 mA 档读 +1.14 A 超端口物理能力 ⇒ 该属性在本板不是干净的电池侧电流；判「落地」用电池电流幅度（A/B 两档幅度差）+ 回读值 + `unknown message`=0。
   - 验证判据：`echo 500000 > …/input_current_limit` 回读 500000、`dmesg | grep -c 'unknown message'` = 0。

## 4. 缺口与下一步（三分类）

**主机侧可做**
- 定期跑 §5 只读速查块，把两口状态归档进 artifact——判据：每次插拔后 `ucsi.01/02` online 与 GPIO29 电平成对变化。
- 「数据+充电」长期挂机一律用反向接法（数据短边 + 供电长边/PD hub）——判据：SSH 保持 + `capacity` 不降。
- 限流落地复测时用电池电流幅度而非 `current_now`——判据：500/900 两档幅度差 ≥3 倍且可重复。

**需设备窗（人工插拔/上机）**
- 反向接法的热切换与启动期仲裁取证（M3-1 残留问题）——判据：插拔期间 `scripts/g7-mux-probe.sh --watch 60` 记录 GPIO29 翻转 + SSH 不断。
- 判据 3（换口→mux 切换）正式采数——判据：GPIO29 `out low`↔`out high` 随插拔翻转。
- backport 进日常线后一次 SDP A/B 复测——判据：§3.4 三条全过。
- 另一台 SDP 主机复核 `usb_type` 仍 `[SDP]`——判据：非本机 PC 端口上同读数。

**需上游**
- Venkat v2 1/2「早下发」路径无样本（`limit_boot` 未被抬过）——需真机在 `service_up=false` 时序写入，属上机时序题，暂缓。
- `current_now` 口径问题已随 Tested-by 回信告知 Venkat（MID 179559445186.3708843…，lore 摄取未到）——判据：lore 出现该 MID。
- 可选：`be5e7367bceb` 之上的 clamp 小补丁——先看 Venkat v2 结局再定（[文档] patches README）。

## 5. 一页速查命令块（设备侧只读）

```sh
# 全部走 SSH（192.168.7.1）；设备不在线时禁止执行。timeout -k 已按纪律示例。
# ⚠ 会自断（USB-NCM 单通道：role/数据面写或端口相关操作会断 SSH）的标 [自断]：
#   写 data_role [自断]——角色一切换 usb0 上的 ssh 通道就断（g7 §7 教训）。只读不受影响。

timeout -k 5 15 ssh root@192.168.7.1 '
  # A. 口位/电源（全只读，安全）
  for d in /sys/class/power_supply/*; do echo "== $d"; grep -E "^(POWER_SUPPLY_NAME|POWER_SUPPLY_ONLINE|POWER_SUPPLY_VOLTAGE_NOW|POWER_SUPPLY_CURRENT_MAX|POWER_SUPPLY_CURRENT_NOW|POWER_SUPPLY_INPUT_CURRENT_LIMIT|POWER_SUPPLY_USB_TYPE)=" $d/uevent; done
  # B. usb_type 取当前值（方括号才是当前值，PITFALLS #726）
  grep -o "\[.*\]" /sys/class/power_supply/qcom-battmgr-usb/usb_type
  # C. typec / role / orientation
  ls /sys/class/typec/; cat /sys/class/typec/port*/data_role /sys/class/typec/port*/power_role 2>/dev/null
  cat /sys/class/usb_role/*role-switch/waiting_for_supplier
  # D. gadget / 链路态
  cat /sys/class/udc/a600000.usb/current_speed /sys/class/udc/a600000.usb/state; ip addr show usb0
  # E. DP 判据
  for c in /sys/class/drm/card0-DP-*; do echo "$c: $(cat $c/status)"; done
  # F. mux 代理观测（换口前后各跑一次，GPIO29 翻转 = 切口）
  sudo gpioget gpiochip0 29   # 或脚本 scripts/g7-mux-probe.sh（--watch 60 观察插拔）
  # G. 电池侧净电流（幅度口径，勿用 current_now 判限流落地）
  cat /sys/class/power_supply/qcom-battmgr-bat/current_now /sys/class/power_supply/qcom-battmgr-bat/capacity
  dmesg | grep -c "unknown message"   # backport 后应恒为 0
'
```

## 6. 冲突清单（不改既有文档，仅记录）

| # | 冲突 | 建议 |
|---|---|---|
| 1 | `usb-dual-port-test-protocol-20261029.md` §7.1 / DEVICE §1.4 旧段写 SMB1501 `@0x43/@0x42`，2026-11-21 更正判定这两地址是 `fsa4480`，SMB1501 = `@68/@69`（是否两颗都在未证） | DEVICE §1.4 已自带更正段；下次触碰 protocol 时在 §7.1 加一行指针即可 |
| 2 | protocol §8.4 建议「PD 插长边、数据插短边」**需 M3-1 仲裁**；DEVICE §1.4 反向实测已推翻该必需条件 | 以 DEVICE §1.4 为准；M3-1 的必要性降级为「热切换未验」 |
| 3 | 早期报告「ADSP 把非 PD 源判 `usb_type=Unknown`」作废（现场值 = SDP，PITFALLS #726）；「长边 SDP 891 mA 下 ICL 是多少」在新证据下未单独复测（A/B 是在 100→500/900 写入档做的） | 口径以 m12-upstream-test §4 为准；下个设备窗顺手记录一口纯 SDP 的 `input_current_limit` 原值 |
| 4 | protocol §8.4 称「数据通路 gpio29 固定长边」为当前事实；g7 轮后 mux 由 `usb_hs_mux` + mux-state 驱动、GPIO29 仅观测代理 | 口径以 g7-routeA-dtfix-20261123.md §7 为准 |
