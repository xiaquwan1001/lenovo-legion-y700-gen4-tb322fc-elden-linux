# 设备侧驱动缺口审计 — 2026-11-27（只读）

> lane：`driver-gap-device-audit` ｜ 方式：`ssh elden` + 只读 `/sys`、`dmesg`、`lsmod`、`/sbin/modprobe -R`（**只解析 alias，不加载**）
> 环境：`Linux elden 7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0 #32 SMP PREEMPT Mon Nov 16 10:55:25 CST 2026 aarch64`，Debian 13 (trixie)，audit 时 uptime **3:35**，`/proc/device-tree/model = "Lenovo Legion Y700 Gen4"`
> 未做：编译、`modprobe`、任何写 `/sys`、任何重启。`dmesg` 行号指本次采集（1111 行）的行号，全部可用同一条命令复现（见 §5）。

---

## 0. 一页结论：有硬件但驱动没上（按功能重要性排序）

| # | 功能块 | 硬件证据（`/sys` / DT） | 驱动侧现状 | 判定 |
|---|---|---|---|---|
| 1 | **摄像头整栈**（ISP/CAMSS + 2×CCI + wl2868c + 闪光灯 + 对焦 + 2 颗 sensor） | `/sys/bus/platform/devices/ad27000.isp`（`qcom,sm8750-camss`，**无 driver 链接**）、`ac7b000.cci`/`ac7c000.cci`（`qcom,sm8750-cci`，无 driver）、`/sys/bus/i2c/devices/10-002f`（`willsemi,wl2868c`，无 driver）、`c400000.spmi:pmic@1:led-controller@ee00`（`qcom,pm8550-flash-led`，无 driver） | **驱动在树内但未加载**：`qcom-camss.ko` / `i2c-qcom-cci.ko` / `wl2868c-regulator.ko` / `leds-qcom-flash.ko` / `camcc-sm8750.ko` / `cambistmclkcc-sm8750.ko`；开机 9.0–9.26s 曾全部加载成功（dmesg L820–838（`[camera] loaded …` ×10，末行 L838 `[camera] done: 1 media, 17 video nodes`）），随后被 **`cam-mode-off.service`（`enabled`）** 主动卸载 | **已部署、默认停机**（不是“缺驱动”）。当前 `/dev/video*`=0、`/dev/media*`=0 是策略态，不是缺失 |
| 2 | **NFC**（ST21NFCA） | DT `soc@0/geniqup@ac0000/i2c@a80000/nfc@8`（`st,st21nfca-i2c`，含 `enable-gpios`/`interrupts`/`pinctrl`） | ① 父 i2c 适配器 `i2c@a80000` **DT `status=disabled`**（`/proc/device-tree/.../i2c@a80000/status`），故 `/sys/bus/i2c/devices` 里根本没有该总线；② 树内**没有 st21nfca 驱动**：`/lib/modules/<kver>/kernel/drivers/nfc/` 只有 `nxp-nci/`、`s3fwrn5/` | **驱动没部署**（+ DT 关闭）。双重缺口 |
| 3 | **硬件 TRNG** | `/sys/bus/platform/devices/10c3000.rng`（`qcom,sm8750-trng`）**无 driver**，`/sbin/modprobe -R of:N*Cqcom,sm8750-trng` → 无解 | 树内无 `qcom_trng` 驱动（`find /lib/modules/<kver> -name "*trng*"` 只有 xilinx/airoha/exynos/arm-smccc）；当前 `/sys/class/misc/hw_random/rng_current = smccc_trng` | **驱动没部署**；功能面由 SMC 兜底，不阻塞 |
| 4 | **QCE 硬件加密引擎** | `/sys/bus/platform/devices/1dfa000.crypto`（`qcom,sm8750-qce` / `qcom,sm8150-qce`）**无 driver** | 树内无 `qce` 驱动（`find -name "*qce*"` 空，`modules.builtin` 无命中） | **驱动没部署** → 无 crypto offload（纯软算） |
| 5 | **CTCU**（相机测试控制单元） | `/sys/bus/platform/devices/10001000.ctcu`（`qcom,sm8750-ctcu`）**无 driver** | 无 `ctcu` 驱动在树内 | **驱动没部署**（相机子系统附加块） |
| 6 | **Coresight TPDM / TNOC**（21+1 个诊断源） | `/sys/bus/amba/devices/` 下 21 个 `*.tpdm`/`*.tpda` 与 `109ab000.tn`（`qcom,coresight-tpdm` / `qcom,coresight-tnoc`）全部 `NODRIVER`；dmesg L1014 `amba 109ab000.tn: deferred probe pending` | `coresight-tpdm.ko` / `coresight-tnoc.ko` **树内不存在**（coresight 目录只有 stm/tmc/cti/funnel/replicator/catu/tpiu/etb10/cpu-debug） | **驱动没部署**（诊断能力缺口，非用户功能） |
| 7 | **传感器（加速度/陀螺/磁力/ALS）** | 遍历 `/proc/device-tree/**/compatible` 匹配 `accel|gyro|magn|invensense|bosch|st,lsm*|sensor` → **0 命中**；`/sys/bus/iio/devices` 只有 1 个 `spmi-adc5-gen3`（PMIC ADC）；无 `/sys/bus/i3c` | 无“在册但未绑定”的 sensor 设备 | **未找到**（DT 无节点 ⇒ 可能是 DT 未写或传感器挂 SLPI/sensor-hub）。**不能断言“没有硬件”** |
| 8 | **扬声器功放（WSA88xx）** | `soundwire@6ad0000`/`@7630000` 下只有 `codec@0,4` / `codec@0,3`（均为 `0217:010e` = WCD9390）；DT 内 `wsa88*` 0 命中 | `wsa_macro` 2 个已绑定；dmesg L783 `qcom-soundwire 7630000.soundwire: dout-ports (0) mismatch with controller (1)` | **未找到**（若硬件是 WSA884x，则 SDW 从设备未在 DT 描述） |
| 9 | **GPU GMU 子节点** | `/sys/bus/platform/devices/3d37000.gmu` 无 driver | 由 `adreno` 直接管：dmesg L`[drm] Loaded GMU firmware v5.1.25`、`/sys/class/devfreq/3d00000.gpu` 工作（cur 525MHz / max 1100MHz） | **正常**（上游设计如此），**不是缺口** |
| 10 | **WiFi（ath12k）** | `/sys/bus/pci/devices/0000:01:00.0` → driver `ath12k_wifi7_pci`，`wlan0` up | 开机 probe 失败：dmesg L792–798 `failed to start mhi: -110` / `probe with driver ath12k_wifi7_pci failed with error -110`；后由 `/usr/local/sbin/ath12k-load.sh` 恢复（`phy0` 时间戳 14:03:27，journal 14:03:43 有安装该脚本记录） | **已部署**，属启动竞态/自动恢复，不是缺驱动 |

### 已核对且无缺口的功能面（各一条硬证据）

| 功能 | 证据 |
|---|---|
| GPU | `/sys/devices/platform/soc@0/3d00000.gpu` → `adreno`；`/sys/class/devfreq/3d00000.gpu/cur_freq=525000000`、`max_freq=1100000000` |
| 显示 DPU/DSI/panel/背光 | `ae00000.display-subsystem`→`msm-mdss`，`ae01000.display-controller`→`msm_dpu`，`ae94000.dsi`/`ae96000.dsi`→`msm_dsi`，`ae95000/ae97000.phy`→`msm_dsi_phy`；`/sys/class/drm/card0-DSI-1/status=connected`，`card0-DP-1=disconnected`；`/sys/class/backlight/aw99706-backlight/{brightness=1024,max=4095}` |
| 音频编解码 | `/proc/asound/cards` 有 `card 0 [LenovoY700Gen4]`；`wcd939x_codec audio-codec: bound sdw:2:0:0217:010e:00:4` / `sdw:3:0:...:00:3`（dmesg L784–785）；`wsa_macro`×2、`va_macro`、`rx_macro`、`tx_macro` 全部绑定；`snd-sc8280xp` 绑定 |
| 蓝牙 | `/sys/class/bluetooth/hci0`（`hci_uart`→`serial0-0`），dmesg L780 `QCA Downloading qca/brhbtfw20.tlv` |
| USB / Type-C | `a600000.usb`→`dwc3-qcom`，dmesg L`[usb-gadget] bound to a600000.usb`；`/sys/class/typec/port0`、`port1`（`port0-partner` 在册）；`/sys/class/power_supply/ucsi-source-psy-*` ×2；`usb0` 网卡 up |
| 存储 UFS | `1d84000.ufs`→`ufshcd-qcom`（+`qcom-qmp-ufs-phy`），`/dev/sda 472.5G KLUFG8RHKF-F0H1` |
| 热 | `/sys/class/thermal/thermal_zone0..54`（55 个）、`cooling_device0..3`（`cpufreq-cpu0`/`cpufreq-cpu6`/`devfreq-3d00000.gpu`/`ath12k_thermal`）；`qcom-tsens`×4（`c228000`–`c22b000`）+ 7×`spmi-temp-alarm` |
| 触屏 | `/sys/bus/spi/devices/spi0.0`→`novatek-nvt36xxx-spi`；`/dev/input/event4` = `NVTCapacitiveTouchScreen` |
| 触觉 | `/sys/bus/i2c/devices/6-005a`、`6-005b`→`aw86927-haptics`；`/dev/input/event2`、`event3` = `aw86927-haptics` |
| 充电/电量 | `/sys/class/power_supply/qcom-battmgr-bat`（`status=Full`,`capacity=100`）、`qcom-battmgr-usb`、`qcom-battmgr-wls` |
| 电源/时钟/互连 | `qcom-rpmh-regulator`×6、`reg-fixed-voltage`×4、`clk-rpmh`、`gcc-sm8750`、`disp_cc-sm8750`、`video_cc-sm8750`、`gpucc 3d90000`、`qnoc-sm8750`×14 全部绑定 |
| 显示输出音/耳机检测 | `hdmi-audio-codec.2.auto`；`/dev/input/event6` = `Lenovo-Y700-Gen4 Headset Jack` |
| 远程处理器 | `/sys/class/remoteproc/remoteproc0=adsp running`、`remoteproc1=cdsp running`；`fastrpc` 绑定 17 个 `qcom,fastrpc-cb` |

---

## 1. 总线枚举（设备 → driver）

`/sys/bus/*/devices` 逐设备读 `driver` 符号链接；`drv` 为空记 `NODRIVER`。总数：

```
## bus=i2c devices=14 drivers=35      ## bus=platform devices=177 drivers=1170
## bus=spi devices=1 drivers=8        ## bus=usb devices=0 drivers=5
## bus=pci devices=2 drivers=20       ## bus=serio devices=0 drivers=2
## bus=iio devices=1 drivers=0        ## bus=regulator devices=2 drivers=1
## bus=typec devices=0 drivers=1      ## bus=rpmsg devices=18 drivers=10
## bus=soundwire devices=4 drivers=1  ## bus=spmi devices=9 drivers=1
## bus=mmc devices=1 drivers=1        ## bus=nvmem devices=2 drivers=0
## bus=amba devices=41 drivers=16     ## bus=mdio MISSING  ## bus=leds MISSING
## bus=thermal MISSING  ## bus=clk MISSING  ## bus=extcon MISSING
## bus=v4l2 MISSING  ## bus=remoteproc MISSING  ## bus=fastrpc MISSING
```
（`MISSING` = 编译期未开该总线类型，非“掉设备”。`thermal`/`leds`/`extcon`/`v4l2` 走 `/sys/class/*`，见 §0。）

### 1.1 i2c（14 设备 / 35 驱动）

```
10-002f  | NODRIVER   <- willsemi,wl2868c（相机 PMIC；模块 wl2868c_regulator 存在未加载）
10-0076  | aw99706    <- awinic,aw99706（背光）
5-0042   | fsa4480 | 5-0043 | fsa4480   <- fcs,fsa4480（2× typec mux）
5-004f   | ptn3222                       <- nxp,ptn3222（redriver）
6-005a   | aw86927-haptics | 6-005b | aw86927-haptics  <- awinic,aw86937
9-0034   | aw88461 | 9-0037 | aw88461   <- awinic,aw88461（smart PA）
i2c-5/6/9/10 | NODRIVER   <- Geni-I2C 适配器本身（a94000/a98000/884000/888000），适配器无 driver 属正常
i2c-13   | NODRIVER       <- name=dpu_dp_aux（DP AUX 通道，正常）
```
DT 里另有 `i2c@10`/`i2c@9`/`i2c@6`/`i2c@5` 之外的适配器全部 `status=disabled`，其中 **`i2c@a80000`（NFC 父总线）disabled** 是唯一挂了真实外设的（`nfc@8`）。

### 1.2 platform（177 设备，161 已绑定 / 16 未绑定）

已绑定按驱动聚合（数量×驱动）：
`qcom,fastrpc-cb×17, qnoc-sm8750×14, qcom-spmi-gpio×8, spmi-temp-alarm×7, qcom-rpmh-regulator×6, reg-fixed-voltage×4, qcom-tsens×4, geni_i2c×4, qcom_smp2p×3, wsa_macro×2, qcom_q6v5_pas×2, qcom-soundwire×2, qcom-bwmon×2, pm8941-pwrkey×2, msm_dsi_phy×2, msm_dsi×2, gpi×2, geni_se_qup×2, arm-smmu×2`，其余单例：`adreno, gcc-sm8750, msm_dpu, msm-mdss, msm-dp-display, disp_cc-sm8750, video_cc-sm8750, sm8750-gpucc, gxclkctl-kaanapali, tcsr_cc-sm8750, clk-rpmh, rpmh, bcm_voter, qcom-rpmhpd, qcom-pcie, qcom-qmp-pcie-phy, qcom-qmp-combo-phy, qcom-qmp-ufs-phy, qcom-ice, qcom-llcc, ufshcd-qcom, sdhci_msm, dwc3-qcom, qcom-m31eusb2-phy, qcom-eusb2-repeater, qcom_geni_serial, qcom_geni_se (×2 计), qcom_cpucp_mbox, qcom-ipcc, qcom_aoss_qmp, qcom-pdc, qcom_hwspinlock, qcom_scm, qcom-smem, qcom_stats, cmd-db, ramoops, sram, sm8750-tlmm, qcom-sm8650-lpass-lpi-pinctrl, spi_geni_qcom, geni_spi, q6apm-dai, q6apm-lpass-dais, q6prm-lpass-clock, rx_macro, tx_macro, va_macro, wcd939x_codec, snd-sc8280xp, hdmi-audio-codec, wcn7861-pmu(pwrseq-qcom_wcn), pci-pwrctrl-pwrseq, qcom-spmi-adc5-gen3, qcom,spmi-sdam, qcom,qfprom, rtc-pm8xxx, qcom-pon, nvmem-reboot-mode, qcom-socinfo, qcomtee, qcom_pmic_glink, simple-pm-bus, soc@0, arm-scmi, scmi_mailbox_transport, smccc_trng, gpio-keys, kgdboc, serial8250, alarmtimer, arch-timer-mmio, armv8-pmu, psci-cpuidle, psci-cpuidle-domain, pmic-glink`

未绑定（16，全部附 `modalias` 与 `/sbin/modprobe -R` 解析结果）：

| 设备 | modalias | alias 解析 | 说明 |
|---|---|---|---|
| `ad27000.isp` | `of:NispT(null)Cqcom,sm8750-camss` | `qcom_camss` | 相机 ISP，模块未加载 |
| `ac7b000.cci` / `ac7c000.cci` | `of:NcciT(null)Cqcom,sm8750-cciCqcom,msm8996-cci` | `i2c_qcom_cci` | 相机 CCI，模块未加载 |
| `10-002f`(i2c) | `of:NpmicT(null)Cwillsemi,wl2868c` | `wl2868c_regulator` | 相机 PMIC，模块未加载 |
| `c400000.spmi:pmic@1:led-controller@ee00` | `of:Nled-controllerT(null)Cqcom,pm8550-flash-ledCqcom,spmi-flash-led` | `leds_qcom_flash` | 闪光灯，模块未加载 |
| `ade0000.clock-controller` | `of:Nclock-controllerT(null)Cqcom,sm8750-camcc` | `camcc_sm8750` | 相机 CC，模块未加载 |
| `1760000.clock-controller` | `of:Nclock-controllerT(null)Cqcom,sm8750-cambistmclkcc` | `cambistmclkcc_sm8750` | 相机 bit-clock CC，模块未加载 |
| `10001000.ctcu` | `of:N…Cqcom,sm8750-ctcuCqcom,sa8775p-ctcu` | **NONE** | 树内无驱动 |
| `10c3000.rng` | `of:N…Cqcom,sm8750-trngCqcom,trng` | **NONE** | 树内无驱动 |
| `1dfa000.crypto` | `of:N…Cqcom,sm8750-qce…` | **NONE** | 树内无驱动 |
| `3d37000.gmu` | `of:N…Cqcom,adreno-gmu-830.1…` | **NONE** | 由 `adreno` 直接管，正常 |
| `gunyah-wdt` | （platform 无 of） | **NONE** | Gunyah 看门狗，无驱动；本机无 Gunyah 客户机 |
| `qcom_llcc_edac` | — | **NONE** | 无 EDAC 驱动 |
| `timer` / `tpdm-cdsp-llm` / `tpdm-cdsp-llm2` / `tpdm-modem1` | — | **NONE** | 诊断类 |

### 1.3 amba（41 设备 / 16 绑定）— Coresight 大洞

```
绑定: 10002000.stm(coresight-stm), 10041000/10804000/10987000/10b04000.funnel,
      10046000/1004e000/10b06000.replicator, 10048000/1004f000/10b05000.tmc,
      1080b000/1098b000.cti
未绑定 21 个: 10004000.tpda, 1000f000.tpdm, 10800000.tpdm, 10803000.tpda, 1082c000.tpdm,
      10841000.tpdm, 1084e000.tpdm, 1084f000.tpdm, 10850000.tpdm, 10851000.tpda,
      10980000.tpdm, 10986000.tpda, 109a3000/109a4000/109a5000/109a6000/109a7000/
      109a8000/109a9000/109aa000.tpdm, 109ab000.tn, 109d0000.tpdm,
      10b08000.tpda, 10b09000/10b0a000/10b0b000/10b0c000/10b0d000.tpdm  (+tpdm-cdsp-*/
      tpdm-modem1 = platform 侧同族)
```
根因：`/lib/modules/<kver>/kernel/drivers/hwtracing/coresight/` **没有 `coresight-tpdm.ko`、`coresight-tnoc.ko`**（只有 stm/tmc/cti/funnel/replicator/catu/tpiu/etb10/cpu-debug），DPLL 缺驱动。

### 1.4 其它总线

```
## spi (1):    spi0.0 | novatek-nvt36xxx-spi
## pci (2):    0000:00:00.0 | pcieport ; 0000:01:00.0 | ath12k_wifi7_pci (17CB:110E, wifi@0)
## mmc (1):    mmc0:b368 | mmcblk
## regulator (2): regulator.9.bdev / regulator.10.bdev | regulator-bus-drv
## nvmem (2):  qfprom0 | NODRIVER ; spmi_sdam1 | NODRIVER   （消费者按 phandle 用，属正常）
## serio (0) ; typec devices=0（走 /sys/class/typec）; usb devices=0（host 无设备，gadget 模式）
## soundwire (4): sdw:2:0:0217:010e:00:4 | wcd9390-codec ; sdw:3:0:0217:010e:00:3 | wcd9390-codec
##              sdw-master-2-0 / sdw-master-3-0 | NODRIVER（master，正常）
## spmi (9):   0-00,0-01,0-03,0-05,0-06,0-07,0-08,0-09 | pmic-spmi ; spmi-0 | NODRIVER（控制器本体）
## iio (1):    iio:device0 | NODRIVER  -> name=spmi-adc5-gen3（IIO 子设备无独立 driver，正常）
```

rpmsg（18；未绑定 10 个均为 DSP 侧 GLINK 通道名，无对应驱动属正常，**不是缺口**）：
```
qcom,fastrpc ×2 ; qcom_smd_qrtr ×2 ; rpmsg_ctrl ×2 ; qcom,apr(adsp_apps) ; qcom_glink_ssr ; qcom_pmic_glink_rpmsg
NODRIVER: cdsprmglink-apps-dsp, cvp-glink-apps-dsp, LOOPBACK_CTL_CDSP, LOOPBACK_CTL_LPASS,
          bt_cp_ctrl, mhi_sat, pcie_drv, PMIC_LOGS_ADSP_APPS, sleepmonglink-apps-adsp
```

---

## 2. dmesg 失败面归并（`dmesg` 1111 行中 **61 行**命中 `fail|error|unsupported|not found|defer|timeout`；分桶合计 61）

| # | 行数 | 归并键（驱动/组件） | 首次行 | 摘录 |
|---|---|---|---|---|
| 1 | 24 | `drm:dpu_kms_wait_for_commit_done:531` + `drm:dpu_encoder_phys_vid_wait_for_commit_done:550` | L1067 | `[dpu error]vblank timeout: 400000` / `wait for commit done returned -110`（L1067–1110 反复出现） |
| 2 | 8 | `PLL(0) lock failed` / `DSI PLL(0) lock failed, status=0x00000000` | L586 | 显示 PLL 探测期噪声（L586–596 共 8 条） |
| 3 | 7 | `qcom_pmic_glink pmic-glink: Failed to create device link (0x180)` | L603 | supplier `88e8000.phy`、`5-0042`/`5-0043`(fsa4480)、`a600000.usb` → connector@0/@1（L603/615/616/697/698/943/955） |
| 4 | 6 | `ath12k_wifi7_pci 0000:01:00.0` | L792 | `failed to set mhi state: POWER_ON(2)` → `failed to start mhi: -110` → `failed to probe` （后被 `ath12k-load.sh` 恢复） |
| 5 | 4 | `disp_cc_mdss_{pclk0,pclk1,byte0,byte1}_clk_src: orphan reparent failed` | L588 | `-110`，PLL 未锁的连带（L588/591/594/597） |
| 6 | 2 | `adreno 3d00000.gpu: supply vdd{,cx} not found, using dummy regulator` | L963 | 无实际 VDD 描述符（L963/964），功能不受阻 |
| 7 | 2 | `regulatory.db`（`faux_driver regulatory` / `cfg80211`） | L710 | `Direct firmware load for regulatory.db failed with error -2`（L710/711） |
| 8 | 1 | `msm_dsi ae94000.dsi` | L600 | `Failed to create device link (0x180) with supplier ae96000.dsi for .../panel@0` |
| 9 | 1 | `ufshcd-qcom 1d84000.ufs` | L641 | `MCQ resource not found in device tree` |
| 10 | 1 | `snd-sc8280xp sound` | L788 | `ASoC: Parent card not yet available, widget card binding deferred` |
| 11 | 1 | `qcom-apm gprsvc:service:2:3` | L781 | `CMD timeout for [1001021] opcode` |
| 12 | 1 | `arm-scmi arm-scmi.1.auto` | L512 | `SCMI max-rx-timeout: 30ms ...`（阈值提示，非错误） |
| 13 | 1 | `amba 109ab000.tn` | L1014 | `deferred probe pending: (reason unknown)`（coresight TNOC 无驱动） |
| 14 | 1 | `/usr/local/sbin/payload-modules-load.sh` | L842 | `[init] WARNING: payload-modules-load failed/timed out`（脚本 `30: Bad substitution`，**非驱动问题**） |
| 15 | 1 | `efi:` | L7 | `UEFI not found`（非 EFI 引导，正常） |

> 未计入本表但值得记录的非 `fail/error` 行：`[drm] Loaded GMU firmware v5.1.25`；`rx_macro/wsa_macro: Driver needs fixing: Unsorted reg_defaults`（L782/786/787，代码质量）；`qcom-soundwire 7630000.soundwire: dout-ports (0) mismatch with controller (1)`（L783）；`fastrpc compute-cb SMR mask out of range for SMMU` ×22（L931–953，功能未受阻）；`gcc-sm8750/gxclkctl/gpucc sync_state() pending due to 3d37000.gmu`（L20.706，GMU 子树未挂 driver 的连带）。
> 全量 dmesg 只有 **1** 条 `deferred probe pending` ⇒ 无 `-EPROBE_DEFER` 循环。

---

## 3. 模块面

### 3.1 已加载（`lsmod` 31 行 = 30 模块）

```
qcom_iris v4l2_mem2mem videobuf2_dma_contig videobuf2_v4l2 videobuf2_memops videobuf2_common
v4l2_async videodev mc                                   <- 视频解码(venus/iris)，非相机
af_alg uinput fsa4480 rpmsg_ctrl fastrpc icc_bwmon
stm_p_basic coresight_stm stm_core coresight_cti coresight_funnel coresight_tmc
coresight_replicator coresight coresight(stm 依赖) qcomtee
bridge stp llc fuse led_class_flash system_heap
```
注：`aw88461`/`aw86927`/`aw99706`/`ptn3222`/`novatek_nvt36xxx_spi`/`snd_soc_wcd939x`/`qcom_camss` 等**不在 lsmod 中但设备已绑定** ⇒ 这些驱动是**内建（built-in，`modules.builtin` 命中）**，与“未加载模块”无关。

### 3.2 树内存在但未加载、且 alias 能对上本机在册硬件的模块（6 个，全部属相机栈）

方法：对 `/sys/bus/*/devices/*/modalias` + `/sys/class/*/*/device/modalias` 全量跑 `/sbin/modprobe -R`（**仅解析，不加载**），得到 351 条 (module, device) 对；再保留“`.ko` 文件存在且不在 `lsmod` 里”的。

| 模块 | `.ko` 路径（`/lib/modules/<kver>/`） | 对应 /sys 设备 | 状态 |
|---|---|---|---|
| `qcom_camss` | `kernel/drivers/media/platform/qcom/camss/qcom-camss.ko` | `platform/ad27000.isp` | 未加载（cam-mode-off 卸载） |
| `i2c_qcom_cci` | `kernel/drivers/i2c/busses/i2c-qcom-cci.ko` | `platform/ac7b000.cci`、`ac7c000.cci` | 同上 |
| `wl2868c_regulator` | `kernel/drivers/regulator/wl2868c-regulator.ko` | `i2c/10-002f` | 同上 |
| `leds_qcom_flash` | `kernel/drivers/leds/flash/leds-qcom-flash.ko` | `platform/c400000.spmi:pmic@1:led-controller@ee00` | 同上 |
| `camcc_sm8750` | `kernel/drivers/clk/qcom/camcc-sm8750.ko` | `platform/ade0000.clock-controller` | 同上 |
| `cambistmclkcc_sm8750` | `kernel/drivers/clk/qcom/cambistmclkcc-sm8750.ko` | `platform/1760000.clock-controller` | 同上 |

另有 3 个相机子模块（`s5kjns.ko`、`gc08a8.ko`、`gt9764.ko`）只在相机栈加载时才有对应 i2c 设备（CCI 总线不存在时无处可绑），dmesg L835–837 证明它们曾成功绑定。

### 3.3 未加载模块总量

`find /lib/modules/<kver> -name "*.ko*" | wc -l` = **1510**；`lsmod` = **30** ⇒ 未加载 **1480**。
这 1480 个中的绝大多数与本机无关（x86/其它 SoC/测试驱动）；本报告只对“能 alias 到本机当前在册 `/sys` 设备”的做严格匹配（上表 6 个），**不对无设备可绑的模块逐个断言**。

### 3.4 树内**没有**对应驱动（真“未部署”）

| 硬件 | 需要的驱动 | 检查命令结果 |
|---|---|---|
| `qcom,sm8750-trng` | `qcom_trng` | `find /lib/modules/<kver> -name "*trng*"` → 仅 xilinx/airoha/exynos/arm-smccc；无 alias 命中 |
| `qcom,sm8750-qce` | `qce` | `find -name "*qce*"` → 空 |
| `qcom,sm8750-ctcu` | `ctcu` | `find -name "*ctcu*"` → 空 |
| `qcom,coresight-tpdm` / `qcom,coresight-tnoc` | `coresight-tpdm` / `coresight-tnoc` | coresight 目录 10 个 `.ko`，无这两个 |
| `st,st21nfca-i2c` | `st21nfca` | `find -name "*st21*"` → 空；`kernel/drivers/nfc/` 仅 `nxp-nci`、`s3fwrn5` |
| `gunyah-wdt` | `qcom` gunyah watchdog | 无对应驱动模块 |
| `qcom_llcc_edac` | `qcom_edac` | `kernel/drivers/edac/` 仅 versal/layerscape/zynqmp |

---

## 4. 结论与建议（不动手，仅记录）

1. **“还有哪些驱动没部署”真正的答案只有 5 类**：`qcom_trng`、`qce`、`ctcu`、`coresight-tpdm`/`coresight-tnoc`、`st21nfca`（+`gunyah-wdt`/`qcom_edac` 边缘项）。
2. **相机不是缺口**：驱动齐、开机验证过 17 个 video 节点，`cam-mode-off.service`（enabled）是刻意的安全策略（避免 cam-in-place + 亮屏的 Q24 掉电组合）。要在报告里改写任何“相机没驱动”的表述。
3. **NFC 是双重缺口**：DT 的 `i2c@a80000` 仍 `disabled`，且树内无 `st21nfca`。
4. **WiFi 的 -110 属启动竞态**，已有 `ath12k-load.sh` 兜底；建议后续把“重试”做成服务依赖而不是人工脚本（本次不改）。
5. **`payload-modules-load.sh` 第 30 行 `Bad substitution`** 是 shell 语法 bug，会让 payload 模块批量加载整段失效 —— 如果相机栈依赖它，未来开相机时会踩。属脚本缺陷，不是驱动缺失。

---

## 5. 复现命令（全部只读）

```bash
# 1) 总线表
ssh elden 'for b in i2c spi platform usb pci iio rpmsg soundwire spmi mmc nvmem; do d=/sys/bus/$b; \
  echo "## $b $(ls $d/devices|wc -l)/$(ls $d/drivers 2>/dev/null|wc -l)"; \
  for x in $d/devices/*; do [ -L $x/driver ] && echo "  $(basename $x) | $(basename $(readlink $x/driver))" || echo "  $(basename $x) | NODRIVER"; done; done'

# 2) 未绑定设备 -> 模块 alias 反查（不加载）
ssh elden 'for d in /sys/bus/*/devices/*; do [ -L $d/driver ] && continue; m=$(cat $d/modalias 2>/dev/null); \
  [ -n "$m" ] && echo "$d | $m | $(/sbin/modprobe -R "$m" | tr "\n" ,)"; done'

# 3) 树内存在但未加载
ssh elden 'K=$(uname -r); for m in qcom_camss i2c_qcom_cci wl2868c_regulator leds_qcom_flash; do \
  find /lib/modules/$K -name "${m//_/-}.ko*"; done; lsmod'

# 4) 功能面
ssh elden 'ls /sys/class/drm/*/status -d; cat /sys/class/drm/card0-DSI-1/status; ls /dev/video* /dev/media*; \
  cat /proc/asound/cards; ls /sys/class/bluetooth /sys/class/net /sys/class/typec; \
  cat /sys/class/power_supply/qcom-battmgr-bat/status; ls /sys/class/thermal | wc -l; ls /dev/input/; ls /sys/class/iio 2>/dev/null; ls /sys/bus/iio/devices'

# 5) 相机栈策略态
ssh elden 'systemctl is-enabled cam-mode-off.service; dmesg | grep -n "\[camera\]"'
```

---

## 6. 局限（必须与结论一起读）

- 只对**当前内核在册**的 `/sys` 设备做判定。“DT 里没有”≠“硬件没有”（传感器、扬声器功放即属此类，本报告写“未找到”）。
- `platform` 设备未绑定项里，`3d37000.gmu`、`i2c-N`（适配器）、`spmi-0`、`sdw-master-*`、`nvmem/*` 属上游设计正常的“无 driver 节点”，已在表中标注，不计入缺口。
- `modprobe -R` 只解析 alias，不含 amba 名字匹配设备的 `MODALIAS=amba:d001F0E04` 之外的路径；coresight 的缺口是用“`.ko` 是否存在 + `dmesg deferred`”两条证据独立确认的。
- 未加载的 1480 个模块未做全量语义分类（只做 alias 严格命中），因此“某模块属本机硬件但当前无设备可绑定”的情况可能被低估。
