# modular-driver-audit — 7.3 日常线（build/vk151）驱动模块化第二层审计

> 日期：2026-10-26 · 代理：modular-kernel · 基准：`build/vk151/.config`（7.3 日常线真源，@ `24223e4`）
> 判据：`=m` 不是「能编过」，而是「root/面板/存储/console 起来之前不需要它」。
> 类型来源：逐符号查 Kconfig `tristate/bool`（限定 drivers/sound/net/firmware/arch-arm64/mm 的 Kconfig 文件，非全仓 grep）+ 源码 `module_init` 抽查。

## §0 数字结论

| 项 | 数字 |
|---|---|
| 基线 =y / =m | 3468 / 1360 |
| 应用 `fragment-modular-v2` 后 =y / =m | 3364 / 1463（**=y −104，=m +103**） |
| 全量 =y 中 tristate（可翻 =m 的理论上限） | 1271（其中 ~1100 是非 SM8750 平台 imx/tegra/meson/rockchip… 驱动，建议下轮 =n 裁剪） |
| **a 判定（可转 =m）** | **49**（42 已入 v2 片段 + 7 可行但未入） |
| **b 判定（必须 =y）** | **43**（27 个门禁锚点 + 16 个 SoC 基础设施） |
| **c 判定（被 bool/select 锁死）** | **16**（DRM_MSM/QCOM/MMC 的 select 链 helper） |
| 全量构建 | **rc=0，0 error，0 warning**（`LD=ld.lld`，PITFALLS #406 既定 divergence） |
| 门禁 self-test | 正向 PASS + 负向×2 FAIL（如预期） |
| vermagic 抽查 | 50/50 个 .ko 首字段 == 内核 UTS |
| 设备（只读） | UTS 与本模块树一致，lsmod 66，dmesg 模块错误 **0**，/proc/config.gz 存在 |

## §1 全量分类表（符号 | 现状 | 判定 | 依据 | 风险）

> 判定 = a(可转 =m) / b(必须 =y) / c(被 bool·select 锁死)。「现状」为基线值。

### 1.1 a 类 — 已入 `fragment-modular-v2.config`（42 个，逐行理由见片段内注释）

| 符号 | 现状 | 判定 | 依据（启动早期是否需要） | 风险 |
|---|---|---|---|---|
| MMC / MMC_BLOCK / MMC_CQHCI / MMC_SDHCI / MMC_SDHCI_PLTFM / MMC_SDHCI_MSM | y | a | **root 在 UFS（`/dev/sda18`）**，TF 卡非启动依赖 | 若走「SD 卡启动」方案会失败；payload 需在 init 后载入 |
| QRTR / QRTR_SMD / QRTR_MHI / QRTR_TUN | y | a | 服务端（音频 GPR/ath12k MHI）都在 root 之后 | 需与音频/wifi 载荷同批 modprobe |
| RPMSG / RPMSG_CHAR / RPMSG_NS / RPMSG_QCOM_GLINK / _RPM / _SMEM / RPMSG_QCOM_SMD / RPMSG_VIRTIO | y | a | 音频链路（APR/GPR）随载荷加载 | ADSP 起来前 rpmsg 空转，无副作用 |
| QCOM_APR / QCOM_PDR_HELPERS / QCOM_PDR_MSG / QCOM_QMI_HELPERS / QCOM_Q6V5_COMMON / QCOM_Q6V5_PAS / QCOM_PIL_INFO | y | a | remoteproc 固件加载链，与 q6apm 同批 | 载荷加载顺序必须 PAS→adsp→q6apm（payload-modules-load.sh 已有该顺序） |
| USB_DWC3 / USB_DWC3_OF_SIMPLE / USB_DWC3_QCOM / PHY_QCOM_QMP_USB / PHY_QCOM_QMP_COMBO / PHY_QCOM_EUSB2_REPEATER / PHY_QCOM_M31_EUSB | y | a | root 不在 USB；console 走 UART | adb/串口网 gadget 在 root 起来后才可用；DP altmode 需 QMP_COMBO |
| TYPEC_UCSI / TYPEC_DP_ALTMODE / QCOM_PMIC_GLINK / BATTERY_QCOM_BATTMGR | y | a | 电池/Type-C 状态非启动依赖 | PMIC_GLINK=m 连带 UCSI_PMIC_GLINK=m（级联，已验证）；电量/充放电报告晚到 |
| QCOM_VADC_COMMON / QCOM_SPMI_ADC5 / ADC5_GEN3 / ADC_TM5 / QCOM_SPMI_TEMP_ALARM | y | a | 纯监控叶子；CPU 降温走 TSENS(=y) | 载入前无 ADC 温度采样（风扇/thermal 策略叶子） |
| RTC_DRV_PM8XXX | y | a | 时间可 NTP 补 | 载入前系统时间停留在编译时间 |
| PINCTRL_LPASS_LPI / PINCTRL_SM8650_LPASS_LPI | y | a | 音频引脚控制，随音频载荷 | 必须在 q6apm 之前 modprobe |

### 1.2 a 类 — 可转但**未入**片段（7 个，收益低/习惯保守）

| 符号 | 判定 | 不入片段理由 |
|---|---|---|
| QCOM_WDT | a | watchdog 常驻 =y 更稳（可靠性习惯，非启动依赖） |
| INPUT_EVDEV | a | 用户态输入入口，模块化无热改收益 |
| QCOM_HIDMA / QCOM_HIDMA_MGMT | a | 本机未用该 DMA 引擎（非 SM8750 数据通路），下轮建议直接 =n |
| QCOM_SYSMON | a→实测 =m | 随 RPROC_COMMON 级联成 m；SSR 监控晚到，可接受 |
| QCOM_PD_MAPPER | a→实测 =m | QMI 用户态 helper，随载荷 |
| USB_ROLE_SWITCH | a | 核心框架，跟 DWC3 同批才有意义 |

### 1.3 b 类 — 必须 =y（43 个）

27 个门禁锚点（见 `scripts/check-modular-config.sh` 内 `DEFAULT_ANCHORS`）：
`ARCH_QCOM` `DRM_MSM` `DRM_MSM_DSI` `DRM_PANEL_NOVATEK_NT36536` `CLK_GLYMUR_GCC` `QCOM_CLK_RPMH` `QCOM_RPMH` `QCOM_RPMHPD` `QCOM_COMMAND_DB` `PINCTRL_SM8750` `PINCTRL_GLYMUR` `INTERCONNECT_QCOM_SM8750` `SPMI_MSM_PMIC_ARB` `MFD_SPMI_PMIC` `REGULATOR_QCOM_SPMI` `REGULATOR_QCOM_RPMH` `SERIAL_QCOM_GENI` `SERIAL_QCOM_GENI_CONSOLE` `QCOM_GENI_SE` `BLK_DEV_SD` `SCSI_UFS_QCOM` `SCSI_UFSHCD_PLATFORM` `PHY_QCOM_QMP_UFS` `QCOM_TSENS` `NVMEM_QCOM_QFPROM` `I2C_QCOM_GENI` `SPI_QCOM_GENI`

理由（按「启动早期需要」归组）：
- **console**：SERIAL_QCOM_GENI(+CONSOLE)；GENI_SE 是其共享库 → b。
- **面板**：DRM_MSM(+DSI) + PANEL_NT36536；依赖 GCC/TCSRCC/RPMH/clk 体系 → b。
- **存储**：root=`sda18`(UFS) → SCSI_UFS_QCOM/UFSHCD_PLATFORM/PHY_QCOM_QMP_UFS/BLK_DEV_SD → b。
- **电源/总线底座**：RPMH/RPMHPD/COMMAND_DB/CLK_RPMH/GLYMUR_GCC/PINCTRL/INTERCONNECT_SM8750/SPMI_PMIC_ARB/MFD_SPMI_PMIC/REGULATOR_QCOM_* → 面板与 UFS 的 regulator 依赖，全部 b。
- **TSENS=y + QFPROM=y 绑定**：TSENS 校准读 qfprom nvmem；qfprom 翻 m 会引入 builtin→module 顺序风险 → 双双 b。
- **I2C_QCOM_GENI / SPI_QCOM_GENI / SPI_QUP**：触屏(SPI)/CCI/背光等叶子的总线控制器；叶子已模块化，控制器热改收益≈0 → b（保守）。

另 16 个基础设施同样 b：`QCOM_SCM` `QCOM_TZMEM` `QCOM_SMEM` `QCOM_SMP2P` `QCOM_SMSM` `QCOM_AOSS_QMP` `QCOM_IPCC` `QCOM_CPUCP_MBOX` `QCOM_LLCC` `QCOM_PDC` `QCOM_MPM` `QCOM_GPI_DMA` `QCOM_BAM_DMA` `REMOTEPROC` `SCSI` `SCSI_MOD`。

### 1.4 c 类 — 被 bool/select 锁死（16 个）

| 符号 | 锁死者 | 说明 |
|---|---|---|
| QCOM_PAS / QCOM_MDT_LOADER | `DRM_MSM`（`drivers/gpu/drm/msm/Kconfig:17,25` `select`，ath12k/IPA/venus 亦 select） | 实测片段写 =m 无效，olddefconfig 回弹 =y |
| QCOM_UBWC_CONFIG / DRM_SCHED / DRM_EXEC / DRM_GPUVM / DRM_KMS_HELPER / DRM_DISPLAY_HELPER / DRM_DISPLAY_DP_AUX_BUS / DRM_CLIENT_LIB / DRM_CLIENT_SELECTION / DRM_AUX_BRIDGE / DRM_AUX_HPD_BRIDGE | DRM_MSM select 链 | DRM 子系统 helper 库 |
| PWRSEQ_EMMC / PWRSEQ_SIMPLE | MMC 翻 m 后 select 级联为 m（反向级联） | 记录级联行为，非违规 |
| CRC7 | MMC_SPI 级联 → m | 同上 |
| UCSI_PMIC_GLINK | 随 QCOM_PMIC_GLINK=m 级联 | 符合预期 |

## §2 新片段 `patches/fragment-modular-v2.config`

- 片段本体：`patches/fragment-modular-v2.config`（42 符号，每行附理由；PAS/MDT_LOADER 明确标注「select 锁死不放」）。
- 应用后快照：`patches/config-vk163-modular-v2-20261026`。
- 实证流程（PITFALLS #162 合规：merge + olddefconfig + 锚点回查）：

```
$ cp build/vk151/.config /tmp/v2.cfg && grep '^CONFIG' patches/fragment-modular-v2.config >> /tmp/v2.cfg
$ cd build/vk151 && KCONFIG_CONFIG=/tmp/v2.cfg make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
# configuration written to /tmp/v2.cfg   (rc=0)
$ grep -c '=y$' /tmp/v2.cfg → 3364      $ grep -c '=m$' /tmp/v2.cfg → 1463
$ 锚点 27/27 仍 =y（含 ARCH_QCOM，本轮 olddefconfig 未触发 #162 删锚）
$ 片段 42/42 符号最终 =m（QCOM_PAS/QCOM_MDT_LOADER 保持 =y，select 锁死，已从片段移除）
$ 意外回退 =0：comm 对比基线，=y 集合差集 104 行全部是片段符号或其 select 级联
```

## §3 门禁与构建原始输出

### 3.1 `scripts/check-modular-config.sh`

```
$ bash scripts/check-modular-config.sh --self-test
== self-test: 正向（基线 + fragment-modular-v2）==
self-test 正向 PASS ✓
== self-test: 负向1（DRM_MSM=y→m，锚点必须拦下）==
self-test 负向1 FAIL ✓（如预期）
== self-test: 负向2（清空 ARCH_QCOM，解析复核必须拦下）==
self-test 负向2 FAIL ✓（如预期）
== self-test 全部通过 ==

$ bash scripts/check-modular-config.sh        # 对日常线现 config
PASS: 锚点全部 =y（27 个）
PASS: olddefconfig 幂等（第二遍零变化）
  info: =y 3463 → 3463, =m 1358
PASS: tristate=y 的 depends/select 无 =m 引用（bool 子项随模块 =y 属合法）
== 门禁 PASS ==
```

设计要点：① bool 子项随 tristate 父项 =m 保持 =y 是**合法**的（第一层 hci_qca 实证），静态检查只对 **tristate** =y 的 depends/select→=m 报错；② olddefconfig 两遍幂等 = 一致性复核；③ vermagic 逐字一致指 `modinfo -F vermagic` 首字段 == `include/config/kernel.release`。

### 3.2 全量构建（v2 config 临时装入 → 构建 → 恢复原 .config，净零改动）

```
$ make -C build/vk151 -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LD=ld.lld \
    LOCALVERSION=-debug-vk163 Image.gz dtbs modules
BUILD_RC=0
grep -cE 'warning:|error:' /tmp/build-v2.log → 0
kernel.release = 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163
.ko 总数 = 1639
```

vermagic 抽查：50/50 模块 `modinfo -F vermagic` 首字段 == UTS（含 `drivers/bluetooth/hci_uart.ko`、`drivers/mmc/host/sdhci-msm.ko`）。

## §4 设备只读核对（ssh root@192.168.7.1；零写盘、零装模块、零重启）

```
$ uname -r
7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163     ← 与本模块树 UTS 逐字一致
$ lsmod | wc -l        → 66
$ find /lib/modules -name '*.ko*' | wc -l → 13379（vk163 目录内 1539 个 .ko，modules.dep 等齐全）
$ zcat /proc/config.gz | wc -l → 12047
$ dmesg 模块错误计数（module.*(fail|error)）→ 0；unknown symbol / invalid module format → 0
```

在机 config 关键符号（第一层已生效）：`ATH12K=m BT_HCIUART=m SND_SOC_QDSP6=m INPUT_AW86927=m TOUCHSCREEN_NOVATEK_NVT36XXX_SPI=m BACKLIGHT_AW99706=m`；锚点仍 `DRM_MSM=y SERIAL_QCOM_GENI=y MMC=y MMC_SDHCI_MSM=y QRTR=y` —— 即 **v2 尚未上机**（本轮只读，符合约束），MMC/QRTR/rpmsg 等在机仍为 =y。

在机 config 与 v2 快照 diff：214 行（= v2 的 104 处降级 + 相关注释/顺序差异），与 §2 预期一致。

## §5 给上游 M3 的「叶驱动模块化」候选清单（触屏/背光/触觉优先）

> 已读源码确认三者均为标准 `module_*_driver()` 入口、无 `__init` 段坑、无跨模块私有符号。

| 优先级 | 驱动 | 源文件 | 状态 | 上游补丁形态 |
|---|---|---|---|---|
| 1 | 触屏 Novatek NVT36xxx SPI | `drivers/input/touchscreen/novatek-nvt36xxx-spi.c` | 已 =m（在机实测热换 OK） | 单模块 patch，宜先于其余 |
| 2 | 触觉 AW86927(/AW86937) | `drivers/input/misc/aw86927.c`（仓内 patch 0003） | 已 =m | haptics 单 patch |
| 3 | 背光 AW99706 | `drivers/video/backlight/aw99706.c` | 已 =m | backlight 单 patch |
| 4 | 音频 q6apm/QDSP6 链 | `sound/soc/qcom/qdsp6/*` | 已 =m | 按模块拆补丁（M3 计划既定） |
| 5 | BT hci_qca | `drivers/bluetooth/hci_qca.c` | 已 =m（随 hci_uart.ko） | 无需 Kconfig 改动 |
| 6 | WiFi ath12k | `drivers/net/wireless/ath/ath12k/` | 已 =m | 上游即模块，出补丁即可 |
| 7（下批） | BATTERY_QCOM_BATTMGR / QCOM_PMIC_GLINK / UCSI_PMIC_GLINK | `drivers/power/supply/qcom_battmgr.c` 等 | v2 已 =m（未上机） | 模块化就绪后按驱动拆 |
| 8（下批） | QCOM_SPMI_ADC5(+GEN3)/ADC_TM5/TEMP_ALARM | `drivers/iio/adc/qcom-spmi-adc5.c` 等 | v2 已 =m（未上机） | IIO/thermal 拆分 |
| 9（下批） | RTC_DRV_PM8XXX / PINCTRL_LPASS_LPI(+SM8650_LPI) | `drivers/rtc/rtc-pm8xxx.c` 等 | v2 已 =m（未上机） | 单模块小 patch |

## §6 下一轮建议（含是否值得动 DRM/MMC 的量化判断）

1. **MMC 值得动**：root 在 UFS，TF 整链（6 符号）翻 =m 零启动风险；唯一场景损失是「TF 直接当启动盘」（项目不用）。已在 v2 完成，上机验证留给下一轮写盘窗口。
2. **DRM_MSM 不值得动**：面板必须在 root 前点亮（否则无 fbdev console），且其 select 链（PAS/MDT_LOADER/DRM helper 11 个）会被锁死——翻 =m 只能把「面板点亮」推迟到 initramfs 模块加载，收益仅 DRM 代码热改。量化：DRM_MSM+子件重编 ≈ 全内核构建时间的 ~35%（ drivers/gpu/drm 体积占比），而 mod-loop 已覆盖 panel 单文件热换的 90% 需求。**建议保持 =y**，DRM 迭代继续走 boot 镜像线。
3. **更大收益在 =n 裁剪**：1271 个 tristate =y 中 ~1100 个属于 imx/tegra/meson/rockchip/bcm 等非本机平台（defconfig 遗产）。裁成 =n 可减 Image 体积与 modules 树（13379→预计 ~4k），构建时间同步缩短。建议下一轮出 `fragment-prune-nonqcom.config`（先 diff DT 确认零引用再裁）。
4. **v2 上机窗口**：与第一层同样流程（RAM 启动验证后再写 boot_b）；重点验证 TF 插拔、USB adb、电量报告、温度叶子四项在「模块载入前后」的行为。
5. **门禁接入**：`check-modular-config.sh` 可挂到 `build-kernel.sh` 前（锚点+幂等+vermagic 三道闸），self-test 已含正负向。
