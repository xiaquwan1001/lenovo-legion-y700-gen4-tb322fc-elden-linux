# 驱动主线覆盖审计 — TB322FC "elden"（2026-10-02）

> 入口 `INDEX.md`。回答一个问题：**用主线 Linux 跑这台机器，还有哪些驱动没有进主线？**
> 方法：厂商 DT（`backup/stock-elden/dtb/*.dtb` → dtc 反编译 + `elden.dts` overlay）
> ＋ 厂商 `vendor_dlkm/` 297 个 `.ko` ＋ 联想公开 GPL 源码（`stock-src/`）
> 与主线树（`linux/`，7.2.0）逐一比对；关键项做**驱动级**（`rg` 匹配 `drivers/ sound/ net/`）核实。
> 关联：`STOCK-CAMERA-GRAVITY-2026-10-02.md`、`STOCK-DRIVERS-2026-09-30.md`、`CHARGE-2026-09-30.md`、`ROADMAP-dep-2026-09-30.md`。

---

## 0. 结论先行（数字）

- 厂商覆盖：**529 个 compatible / 297 个 `.ko` 模块**（其中有大量 kera/tuna 等其它 SoC 变体，与本机无关）。
- 主线对 **SM8750 SoC 本体**支持已相当完整：`sm8750.dtsi + sm8750-pmics.dtsi + sm8750-lenovo-elden.dts` 共 **146 个 compatible**，涵盖时钟/NOC/显示/GPU/相机/USB/PCIe/UFS/音频宏/PMIC 等。
- **真正"主线完全没有"的驱动分三类**：
  1. **SLPI/SSC 传感器栈**（一整类外设全灭：IMU/磁力/气压/温湿度/SAR/霍尔/光感）——架构性缺失，最严重；
  2. **Lenovo / Qualcomm OEM 私有**（外壳温控、QMI cooling、BCL、PMIH010x PMIC、Gunyah、SPU、TEE、hw-fence 等）；
  3. **少量外设**（FM 收音 RTC6226、ST54 安全元件、SWR haptics）。
- 用户点名的四项里：**重力计** → 类别 1（不可落地）；**温控** → 主体在主线，缺 OEM/QMI 层；**旁路供电** → 主线 `qcom_battmgr` 已完整支持（**不算缺失**）；**DP 输出** → 驱动在主线，板级被主动 `disabled`（ADSP altmode 未通，属 bring-up 缺口）。

---

## 1. 已进主线、本机只需接线/开 config（**不是缺失**）

这些在厂商 DT 里是私有 compatible，但主线早有对应**通用驱动**；本项目多已接线或极易接线。

| 功能 | 厂商（私有） | 主线驱动 | 本机状态 |
|---|---|---|---|
| 触屏 Novatek NT36536 | `novatek,NVT-ts-spi` | `novatek,nt36536-ts` | ✅ 已接线可用 |
| 背光 AW99706 | `i2c-backlight`（联想私有） | `drivers/video/backlight/aw99706.c` | ✅ 已接线 |
| 双马达触觉 AW86937 | `awinic,haptic_hv_l/r` | `drivers/input/misc/aw86927.c` | ✅ 已用（+ 反汇编 CONT 补丁） |
| 智能功放 AW88461 ×2 | `awinic,aw882xx_smartpa` | `sound/soc/codecs/aw88461.c` | ✅ 驱动在，卡 tplg |
| USB-C 中继 NXP PTN3222 | `nxp,eusb2-repeater` / `hq_ptn3222_repeater.ko`（联想） | `drivers/phy/phy-nxp-ptn3222.c` | ✅ 已接线 |
| USB-C SBU mux FSA4480 | `fsa4480-i2c` | `drivers/usb/typec/mux/fsa4480.c` | ✅ 已接线 |
| 相机 PMIC WL2868C | `will,wl2868c` | `drivers/regulator/wl2868c-regulator.c` | ⚠️ config 未开 |
| 后摄 S5KJNS / 前摄 GC08A8 / VCM GT9764 | `qcom,cam-sensor` 等 | `drivers/media/i2c/{s5kjns,gc08a8,gt9764}.c` + `camss` | ⚠️ config/模块部署问题 |
| 相机闪光灯 | `qcom,qti-pm8350c-flash-led` | `drivers/leds/flash/leds-qcom-flash.c` | ✅ |
| 风扇 MAX31760（通用，本机未见风扇节点） | — | `drivers/hwmon/max31760.c` | ✅ 主线在 |
| DP→HDMI 桥 LT9611UXC / DP redriver NB7VPQ904M（外接 dongle） | `lt9611uxc.ko` / `nb7vpq904m.ko` | `drivers/gpu/drm/bridge/lontium-lt9611uxc.c`、`drivers/usb/typec/mux/nb7vpq904m.c` | ✅ 主线在 |
| 充电 / 旁路供电 | `qti_battery_charger.ko` | `drivers/power/supply/qcom_battmgr.c`（`qcom,sm8750-pmic-glink`） | ✅ 双旋钮已实测（见 §4.3） |
| WLAN WCN7861 "PEACH" | `qca_cld3_peach.ko` | `ath12k`（WCN7850 hw 通路） | ✅ 可用（本树有 MHI timeout 补丁） |
| 蓝牙 WCN7861 | `btpower.ko` | `drivers/bluetooth/hci_qca.c` + `btqca.c` | ✅ 可用（IBS workaround 补丁） |
| UFS / PCIe / USB3 / 显示 / GPU / 视频解码 | qcom sde/kgsl/msm_video | `ufshc`、`pcie-qcom`、`dwc3-qcom`、`msm_drm`、`msm` GPU、`iris` | ✅ 主线在（GPU 需 freedreno 用户态） |

> 结论：**这一层的"缺失"基本都是 config/DT/用户态，不是驱动本身**。相机是典型例子（见 `STOCK-CAMERA-GRAVITY`）。

---

## 2. ★ 主线完全没有的驱动（真缺失）

### 2.1 类别 1 — SLPI/SSC 传感器栈（最严重，一整个外设类死掉）

| 器件 | 型号 | 厂商配置证据 |
|---|---|---|
| 加速度计+陀螺（**重力计**） | ST **LSM6DSO** | `pakala_lsm6dso_0.json` |
| 磁力计 | MEMSIC **MMC56x3x** | `pakala_mmc56x3x_0.json` |
| 气压计 | ST **LPS22DF** | `pakala_lps22df_0.json` |
| 温湿度 | Sensirion **SHT4x** | `pakala_sht4x_0.json` |
| SAR / 接近 | Semtech **SX932x** | `pakala_sx932x_0.json` |
| 霍尔 | ROHM **BU52053NVX** | `pakala_bu52053nvx_0.json` |
| 光感 / 接近 | AMS **TMD3765** | `pakala_tmd3765_0.json` |

- 缺失的**不是 IIO 驱动**（`st_lsm6dsx` 等主线都有），而是整条 **QMI-SNS（Sensors）glink 桥 + SLPI 传感器核 remoteproc bring-up**（厂商模块 `qti_qmi_sensor_v2.ko`）。
- 芯片挂在 **SLPI 私有 I2C（bus_instance=3）**，AP 侧无任何 I2C 引脚连到它；厂商基础 DTB / dtbo 里都没有这些传感器节点。
- **可行性：极低**（SLPI 固件闭源、QMI-SNS 无主线参照）。详见 `STOCK-CAMERA-GRAVITY-2026-10-02.md` §2/§3.3。

### 2.2 类别 2 — Lenovo / Qualcomm OEM 与专有子系统

| 缺失项 | 厂商模块 / compatible | 作用 | 我们现状 |
|---|---|---|---|
| **外壳温度聚合** | `lenovo_sys_temp.ko` / `lenovo,sys-temp` | 汇总 NTC → 前/后/用户壳温 | 无（`drivers/thermal/lenovo_sys_temp.c`，未公开主线） |
| **OEM 温控策略** | `lenovo_thermal_control.ko` | Lenovo 动态调频/降耗策略 | 无 |
| QCOM thermal 配置 | `thermal_config.ko`（`drivers/thermal/qcom/thermal_config.c`） | OEM 热区/限流配置表 | 无（主线有通用 thermal 框架） |
| **QMI cooling** | `qti_qmi_cdev.ko`、`qti_qmi_sensor_v2.ko`、`qti_userspace_cdev.ko` | 依 ADSP 传感器/基带温度做 cooling | 无（依赖 SLPI，类别 1） |
| **BCL（电池电流限制）** | `bcl_soc.ko` / `qcom,bcl-v5`、`qcom,msm-bcl-soc`、`qcom,pm8550-bcl-v5` | 紧急限流防过放 | 无（主线无 `qcom,bcl` 驱动） |
| DDR / CPU MPAM 降耗 | `ddr_cdev.ko`、`cpu_mpam.ko`、`mpam*.ko` | 内存带宽/缓存限制 | 无 |
| **PMIH010x / PMD802x PMIC** | `pinctrl/pmih010x*`、`pmih010x_eusb2_repeater`、`pmih010x_haptics` | SM8750 主 PMIC 的 GPIO/BCL/SWR-haptics/eusb2/temp-alarm | **主线 SM8750 PMIC 集合里完全没有**（0 命中）|
| PM8010（外置相机 PMIC） | `pm8010m_tz` / `pm8010n_tz` | 相机供电/测温 | 无专用驱动 |
| **SWR haptics** | `swr_haptics_dlkm.ko` / `qcom,pmih010x-swr-haptics` | SoundWire 触觉 | 无（本机用 I2C AW86937 替代） |
| **Gunyah 虚拟化** | `gh_*.ko`、`hvc_gunyah.ko`、`qcom,qrtr-gunyah` | 高通 Hypervisor | 无（EL2 也被签名 Gunyah 占，见 `EL2-VIRT`） |
| **SPU / SPSS 安全处理器** | `spcom.ko`、`spss_utils.ko`、`qcom,sun-spss-pas` | 安全协处理器 | 无 |
| **TEE / 密钥** | `qseecom_proxy.ko`、`smcinvoke_dlkm.ko`、`tz_log_dlkm.ko` | 高通 TEE | 无（主线走 OP-TEE） |
| `mem-buf` / `mem-share` | `mem_object.ko`、`msm_memshare.ko`、`heap_mem_ext_v01.ko` | 跨子系统内存共享 | 无 |
| **hw-fence / synx / ext-disp** | `msm_hw_fence.ko`、`synx-driver.ko`、`msm_ext_display.ko` / `qcom,msm-hw-fence`、`qcom,msm-ext-disp` | 显示/视频帧同步、外接显示 | 无（主线用 dma-fence + 原生 DP） |
| HDCP | `hdcp_qseecom_dlkm.ko` / `qcom,msm-hdcp` | DP HDCP | 无 |
| EVA（视频分析） | `msm-eva.ko` | 计算机视觉加速 | 无 |
| 其它调试/统计 | `qcom_edac`、`qcom_va_minidump`、`dmesg_dumper`、`cpucp_log`、`qts.ko` | ECC/minidump/日志/触摸热 | 无（非必需） |
| Lenovo 私有 USB 网 | `hq_usbnet.ko`、`hq_mii.ko`、`hq_smsc.ko`、`hqsysfs.ko` | USB 网卡/sysfs | 主线 `smsc95xx` 已够用 |

### 2.3 类别 3 — 少量外设芯片

| 缺失项 | 厂商模块 / compatible | 说明 | 可行性 |
|---|---|---|---|
| **FM 收音** | `radio-i2c-rtc6226-qca.ko` | Silicon Labs **RTC6226** I2C FM 调谐器 | 主线**没有**该驱动（曾提审未合并）；价值低 |
| **NFC + 安全元件** | `stm_nfc_i2c.ko`、`stm_st54se_gpio.ko`、`nxp-nci.ko` | ST **ST21NFC** + **ST54** SE | 主线有 `st21nfca`（但 compatible 为 `st,st21nfca-i2c`，与厂商 `st,st21nfc` 不同，DT 改一行即可）；**ST54 SE glue 主线缺失** |
| **SD 卡（TF）** | —— | `sdhci-msm` 主线**有**，但本机 buffered 写有 flush/cache bug | 有驱动，需修 bug（见 `TF卡-2026-09-30.md`） |

---

## 3. 主线"有驱动但板级没打通"（bring-up 缺口，常被误认为缺驱动）

| 项 | 现状 | 根因 |
|---|---|---|
| **DP 输出** | 主线 `qcom,sm8750-dp` + `qcom,sm8750-qmp-usb3-dp-phy` **都在树**；但 `sm8750-lenovo-elden.dts` 里 `&mdss_dp0 { status = "disabled"; }` | `msm_dp` 是 DRM 组件，缺 ADSP（pmic-glink altmode / QMP DP PHY 未就绪）会永久 defer → 拖垮 `msm_drm_bind` 黑屏。故作者主动关掉。**属 ADSP/altmode bring-up，不是缺驱动** |
| **PD / UCSI / altmode** | `pmic_glink_ucsi ... PPM init failed`；无 `/sys/class/typec/`、`/sys/class/ucsi/` | `pmic_glink` → ADSP UCSI owner 注册失败；但 **PD 快充由 ADSP 固件独立完成（实测 9.4V/5A）**，只影响 altmode（外接 DP） |
| **音频出声** | 驱动（AW88461、LPASS 宏、q6apm）都在，tplg 已修到设备子图注册 | ADSP 拒绝 `APM_CMD_GRAPH_OPEN` → 需同步 linux-piano PR #16 的 43 个 AudioReach 上游 commit（见 `AUDIO-2026-10-02.md`） |
| **165Hz 刷新率** | panel 驱动在主线，缺 per-mode PLL/DCS 序列 | 见 `PANEL-REFRESH-2026-10-01.md`、`patches/` |

---

## 4. ★ 用户点名项逐条回答

### 4.1 重力计（以及全部运动/环境传感器）
**主线没有 → 且基本不可能有。** 见 §2.1。所有 7 颗传感器都在 SLPI 传感器核的私有总线上，需要整条 QMI-SNS 栈。**不建议投入**。

### 4.2 温控
- **主线已有**：`qcom,sm8750-tsens`（CPU/GPU junction）、`qcom,spmi-temp-alarm`（PMIC die）、CPU `/thermal` 与 GPU devfreq cooling，本项目还加了分级 trips（`patches/0010`）。
- **主线缺失**：Lenovo **外壳温度聚合**（`lenovo,sys-temp`）、OEM 温控策略（`lenovo_thermal_control`）、**QMI cooling**（`qti_qmi_cdev`，依赖 SLPI）、**BCL 电池限流**、PMIH010x die-temp。
- 影响：**CPU/GPU 过热保护是完整的**；缺的是"感知机身温度后做精细降耗"和"电池电流紧急限制"这类 OEM 增强。若只要不烧机，**可接受**。

### 4.3 旁路供电
**已解决，不算缺失。** 主线 `qcom_battmgr`（SM8750 PMIC-GLINK）已提供两个旋钮并实测有效：
- **旁路** = `charge_control_end_threshold`（设到 ≤ 当前电量 → 整机改吃适配器，电池停充）；
- **功率** = `input_current_limit`（默认 100 mA 导致净掉电，拉到 `current_max` 即正常充电）。
工具 `scripts/charge-ctl.sh` / `charge-watch.sh`。详见 `CHARGE-2026-09-30.md`。

### 4.4 DP 输出
**驱动在主线，板级被禁用。** 见 §3 第一行：`mdss_dp0` 与 QMP DP PHY 都已 upstream，但需要 **ADSP 侧 altmode/UCSI** 先就绪，否则 DRM 绑定失败黑屏。要恢复外接显示，方向是修 `pmic_glink` UCSI/altmode，而不是写驱动。

---

## 5. 优先级建议（若继续投入）

| 优先级 | 项 | 理由 | 前置 | 工作量 |
|---|---|---|---|---|
| **P0** | 相机（camss + 3 sensor + wl2868c） | 驱动全在主线，只差 config/模块部署，**性价比最高** | 内核 config | 小（1–2 天） |
| **P1** | 音频 `APM_CMD_GRAPH_OPEN` | 同步上游 AudioReach commit | 内核 + tplg | 中 |
| **P1** | DP/altmode（`pmic_glink` UCSI） | 解锁外接显示；DPU/PHY 已就绪 | ADSP bring-up | 中 |
| **P2** | NFC（ST21NFC） | 主线驱动在，改 compatible 即可 | DT + config | 小 |
| **P3** | 温控 OEM 增强 / BCL | 可自行用 `thermal` 框架近似，无需移植 OEM | 无 | 中 |
| **✗ 不做** | 重力计/磁力/气压等 SLPI 传感器 | 架构性不可落地 | — | 极大 |
| **✗ 不做** | 私有 TEE/Gunyah/SPU/hw-fence/mem-buf | 与主线架构冲突，且无使用场景 | — | 极大 |
| **✗ 不做** | FM 收音 RTC6226 | 价值低、驱动要自写 | — | 中 |

---

## 6. 复现方法与证据

```bash
# 厂商 DT → 文本
DTC=~/y700-elden/geekidos-linux/scripts/dtc/dtc
for f in backup/stock-elden/dtb/*.dtb; do
  $DTC -I dtb -O dts -o /tmp/$(basename $f .dtb).dts "$f"; done
# 厂商模块清单
find backup/stock-elden/vendor_dlkm -name '*.ko' | sed 's#.*/##' | sort
# compatible 对比（vendor vs 主线 drivers）
grep -hoE 'compatible = "[^"]+"' /tmp/vendt/*.dts backup/stock-elden/elden.dts \
  | sed -E 's/compatible = "//; s/"$//' | sort -u > /tmp/vendor-comp.txt
rg -F -o -f /tmp/vendor-comp.txt -g '*.c' -g '*.h' drivers sound net \
  | sed -E 's/^[^:]*://' | sort -u > /tmp/vendor-in-mainline.txt
```

| 关键事实 | 证据 |
|---|---|
| 厂商 297 个 `.ko`、529 个 compatible | `backup/stock-elden/vendor_dlkm/`、`/tmp/vendor-comp.txt` |
| 主线 SM8750 支持集合 | `linux/arch/arm64/boot/dts/qcom/sm8750{,-pmics}.dtsi` + `sm8750-lenovo-elden.dts` |
| PMIH010x/PMD802x 主线缺失 | `rg -l pmih010x linux/drivers linux/arch/arm64/boot/dts/qcom` → 0 |
| BCL 主线缺失 | `rg -l "qcom,bcl" linux/drivers` → 0 |
| SLPI 传感器 | `STOCK-CAMERA-GRAVITY-2026-10-02.md` §2 |
| DP 驱动在树但禁用 | `linux/.../sm8750-lenovo-elden.dts:2281` |
| 旁路供电已通 | `CHARGE-2026-09-30.md` §3/§8 |
| 私有驱动源码未公开 | `qti_battery_charger/qti_qmi_sensor_v2/lenovo_sys_temp` 仅 `.ko`，`stock-src/` 无源码 |

---

## 7. 一句话总结

**这台机器的主线适配已经"越过 SoC 层"了**——CPU/GPU/显示/USB/PCIe/UFS/网络/触控/触觉/背光/相机/音频编解码都有主线驱动。真正还缺的不是 SoC 驱动，而是三类：**① SLPI 传感器核（架构性，放弃）**；**② OEM/QCOM 私有子系统（TEE/Gunyah/SPU/hw-fence/PMIH010x/BCL，非必需）**；**③ 个别外设（FM 收音、ST54 SE）**。用户关心的**旁路供电主线已完整支持**，**DP 是 bring-up 而非缺驱动**，**温控主保护在主线、只缺 OEM 增强**。
