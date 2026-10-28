# M2-A2 供电/电量栈重新评估（厂商真源码，纯主机）

> lane 子代理产出。范围：**只读上游源码 + 本机树 grep**，不上机、不发邮件、不碰设备。
> 触发：`reports/dispcc-battmgr-20261028.md` §B 推翻旧结论「drop 不含 battery/QBG」。
> 取件：GitHub raw 单文件（`lenovo-basements/android_kernel_lenovo_sm8750` @ `main` = `210981a0ad74`），
> 片段落 `reference/vendor-qbg-20261028/`。
> 结论口径：**已证 / 未证实 / 未上机**。

## §0 结论（先数字）

- 依赖面：**15 项中 upstream 已有 4、缺 11**；缺项全部随件可得，但 8 项属跨子系统 ABI（非搬文件可通）。**已证**（`rg` 实查）。
- **致命互斥**：厂商 `MSG_OWNER_BC` = 32778 = 上游 `PMIC_GLINK_OWNER_BATTMGR` ⇒ `qti_battery_charger` 与 `qcom_battmgr` **不能共存**。**已证**（常量比对）。
- 落点推荐：**B（扩展 upstream `qcom_battmgr`）> C（只搬 profile 数据）> A（移植 downstream）**。理由与判据见 §4。
- 上游已有 `qcom,sm8750-pmic-glink` 变体，本机无需自造 SoC 分支。**已证**。

## §1 取件与本地基线

- 取件：`raw.githubusercontent.com/lenovo-basements/android_kernel_lenovo_sm8750/main` 单文件；直连先成 1 个后全失败（`curl (7)`），改 `https_proxy=127.0.0.1:7890` 后 5/5 成功。共取 16 个文件（12 全件 + 4 片段），片段 ≤100 行落 `reference/vendor-qbg-20261028/`（52 KB）。
- 本地基线：`geekidos-linux` @ `ba28ec16f01f`（v7.2.0，含本地 battmgr SM8750 POWER_NOW 补丁）；`drivers/power/supply/qcom/` **目录不存在**，`include/linux/soc/qcom/` 只有 `pmic_glink.h`。
- 配置基线：`arch/arm64/configs/qcom-battery.config:7` = `CONFIG_BATTERY_QCOM_BATTMGR=y`；厂商真通道 `sun_perf/sun_le.config` = `CONFIG_QTI_BATTERY_CHARGER=m`（上轮已证，本轮未复核）。

## §2 Q1 依赖面

基线：本地 `geekidos-linux` @ `ba28ec16f01f`（v7.2.0 + battmgr 本地补丁，`drivers/power/supply/qcom/` 不存在）。
`rg` 实查口径：`HAVE`=本地树有同名头/符号，`MISS`=无。厂商件均为 `drivers/power/supply/{qti_battery_charger.c, qcom/qti-qbg.c}`。

| # | 依赖（符号 / 头） | 厂商 `file:line` | 上游 | 说明 |
|---|---|---|---|---|
| 1 | `include/linux/soc/qcom/qti_pmic_glink.h` | qti_battery_charger.c:23 | **MISS** | 上游只有 `pmic_glink.h`，API 不同族 |
| 2 | `pmic_glink_register_client()` | qti_battery_charger.c:2577 | **MISS** | 上游为 `devm_pmic_glink_client_alloc`+`pmic_glink_client_register` |
| 3 | `pmic_glink_write()` | qti_battery_charger.c:379,419 | **MISS** | 上游同名语义 = `pmic_glink_send()` |
| 4 | `struct pmic_glink_client_data`（name/id/msg_cb/state_cb） | qti_battery_charger.c:2522 | **MISS** | 上游 alloc 直接收 cb 参数，无此结构 |
| 5 | `struct pmic_glink_hdr` | qti_battery_charger.c:149,157 | HAVE | `include/linux/soc/qcom/pmic_glink.h:18` |
| 6 | `MSG_OWNER_BC` = 32778 | qti_battery_charger.c:27 | HAVE(值) | **与 `PMIC_GLINK_OWNER_BATTMGR` 同号** ⇒ 与 upstream battmgr 互斥 |
| 7 | `include/linux/soc/qcom/battery_charger.h` | qti_battery_charger.c:24 | **MISS** | 内含 `qti_battery_charger_get/set_prop` 导出 |
| 8 | `include/linux/soc/qcom/panel_event_notifier.h` | qti_battery_charger.c:25 | **MISS** | `panel_event_notifier_register()` :2464，全树 0 命中 |
| 9 | `POWER_SUPPLY_PROP_*`（30 个，含 `CHARGE_CONTROL_START/END_THRESHOLD`、`TIME_TO_FULL_NOW`、`VOLTAGE_OCV`） | qti_battery_charger.c 全篇 | HAVE | 逐个核 `include/linux/power_supply.h`：30/30 存在 |
| 10 | `include/linux/qti_power_supply.h` | qcom/qti-qbg.c:27 | **MISS** | 厂商 USB/HVDCP type 扩展枚举 |
| 11 | `include/dt-bindings/iio/qti_power_supply_iio.h` | qcom/qti-qbg.c:36 | **MISS** | QBG 私有 IIO channel 枚举（binding 侧） |
| 12 | `include/uapi/linux/qbg.h` / `qbg-profile.h` | qcom/qti-qbg.c:38,39 | **MISS** | ioctl 4 个 + SDAM 偏移表，纯数据定义 |
| 13 | `battery-profile-loader.h` + `qbg-{core,iio,sdam,battery-profile}.h` | qcom/qti-qbg.c:40-44 | **MISS** | 驱动自带私有头（随件搬，非跨子系统） |
| 14 | `qbg_sdam_*()`（9 个函数，regmap bulk rw 之上） | qcom/qbg-sdam.h:34-46 | **MISS** | 自带实现，仅依赖 `regmap` |
| 15 | `iio_channel_get`/`iio_read_channel_processed`、`regmap_bulk_*`、`devm_nvmem_cell_get`、`rtc_class_open` | qti-qbg.c:200,222,163,2715,2841 | HAVE | 上游子系统 API 齐备 |
| — | `pmic-voter` / `qcom_scm` | — | — | **两文件 0 命中**（votable 只在 `qcom/battery.c`，不在本次两驱动内） |

**统计：15 项依赖中，upstream 已有 4，缺 11。**
缺的 11 项全部可从同一 vendor drop 自带；但 #1–#4、#7、#8、#10、#11 是**跨子系统 ABI**（glink 客户端注册 / panel notifier / IIO binding 枚举），
不是搬文件就能通——需自建 Kconfig + 适配上游 `pmic_glink` 回调形态。

## §3 Q2 SM8750 变体

- upstream `qcom_battmgr.c:1721` 已有 `qcom,sm8750-pmic-glink` → `QCOM_BATTMGR_SM8750`，`:1800` 选 `sm8750_bat_psy_desc`（= SM8550 props 去掉 `POWER_NOW`）。**已证**。
- 厂商 `qti-qbg.c` 无 SoC 分支，只有通用 `compatible = "qcom,qbg"`；SoC 差异全在 DT/ADC 通道。**已证**。

## §4 Q3 落点建议

三问门（`reports/upstream-policy-20261013.md` §1）：Q1 power_supply 子系统 **有**；Q2 同类芯片 `qcom_battmgr` **有**（且已支持 SM8750）；Q3 profile/阈值属**硬件事实**→应进 DT。

| 序 | 方案 | 一句理由 | 改动面 | 最小验证判据 |
|---|---|---|---|---|
| **1** | **B. 扩展 upstream `qcom_battmgr` + 厂商 DT profile** | 三问门 Q1/Q2 全「有」，直接过门；battmgr 已认 SM8750，协议族与 `MSG_OWNER_BC` 同号同栈 | **小**：1 个 DT 节点（`qcom,sm8750-pmic-glink`）+ 可能 1 个电池 profile 数据节点；C 代码 0～30 行 | 见下「共同判据」；额外：`capacity` 随放电单调下降、`charge_full_design` 非 0 |
| **2** | **C. 只搬 QBG profile 数据，驱动仍用 upstream** | B 的纯数据子集；若 battmgr 已从 ADSP 拿到 `charge_full*`/`cycle_count`，则本方案退化为 0 改动 | **极小**：DT 数据表（`qbg-profile` 格式）+ 一个 parser 或直接换算成 battmgr 已用属性 | 仅 `charge_full_design`/`charge_full`/`cycle_count` 三项与厂商标称一致 |
| **3** | **A. 移植 downstream `qti_battery_charger` + `qti-qbg`** | **与上游 battmgr 抢 glink owner 32778，二选一**；且 8 项跨子系统 ABI 要自建，上游永不收（D 类） | **大**：11 文件 ≈250 KB + 4 个新 Kconfig（`QTI_PMIC_GLINK`/`QTI_BATTERY_CHARGER`/`QBG`/`IIO_QTI_PS`）+ 2 个 DT 节点 + 必须先卸 `BATTERY_QCOM_BATTMGR` | 见下「共同判据」；额外：`/dev/qbg*` 出现、`QBGIOCXCFG` ioctl 可读 |

**共同判据（B/C 验证用，`/sys/class/power_supply/qcom-battmgr-bat/`）**：
`status` ∈ {Charging,Discharging} 且随插拔翻转；`capacity` 0–100 且非恒定值；`voltage_now` 3.3e6–4.6e6 µV；
`current_now` ≠ 0；`temp` 200–450（0.1 °C）；`charge_counter` 单调；`model_name` 非空；
`ac`/`usb` psy 的 `online` 随插拔 0↔1。
**判 B 失败**：`capacity` 恒 0 或 `voltage_now` 返回 `-ENODATA`/`-EIO` ⇒ ADSP glink 不应答，退 A。
（以上均为**未上机**判据，本轮未执行。）

**附注（影响 B 的可行性，未证实）**：`reference/stock-elden.dts` 里**查不到** `qcom,battery-charger` / `qcom,qbg` / `pmic-glink` 节点，
只有 `pmih010x_vbat_sns_qbg` ADC 通道（:2095）。厂商电池节点可能在独立 overlay/`*-batt.dtsi` 中，本轮未取 ⇒ B 的 DT 来源需下一轮确认。

## §5 未证实 / 未上机

- **未上机**：§4 全部验证判据、A 方案 owner 冲突的运行时表现、QBG SDAM FIFO 是否真被 ADSP 写入。
- **未证实**：① 厂商电池/QBG DT 节点位置（stock dts 未见，疑在独立 overlay，本轮未取）；② `qcom,battery-charger` 是否真在本机 DT 中启用；③ ADSP 固件版本是否实现 battmgr 协议（B 方案的前置假设）。
- **未证实**：`panel_event_notifier`（#8）在厂商树由哪个驱动提供，本轮只取到调用方，未取实现侧。
