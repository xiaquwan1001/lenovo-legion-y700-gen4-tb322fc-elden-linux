# S3 其他驱动补全盘点：vendor vs 主线缺口（elden / TB322FC / SM8750P）

> 调研 2026-10-09，只读。口径 = G1「正常驱动原厂全部固件」。
> 对照物：`backup/stock-elden/vendor_dlkm`（≈230 个 .ko）、`system_dlkm`（≈90 个，标准内核模块）、
> 本机构建主线树 `geekidos-linux` = **Linux 7.2.0**（Makefile VERSION 7.2，作 mainline 覆盖对照）。

## 结论（≤10 行）
- 在 Linux 7.2 工作树下，SM8750 的**基础 SoC + GPU/显示 + 音频 codec + WiFi + 触屏 + NFC + 基础 thermal**
  都已有主线等价驱动（多数已在用），vendor_dlkm 里很大比例属「有主线对应、只需使能/回灌/校验」（A 档）。
- 真正**厂商私有无主线对应**的，集中在：温控 OEM 层（lenovo_sys_temp/thermal_control）、电池/充电 glink BMS
  （qti_battery_charger）、相机 IPA/3A + camx（camera.ko）、私有传感器（qti_qmi_sensor_v2）、Awinic HV 触觉
  （awinic,haptic_hv + swr_haptics）、以及 IPA/WWAN（本树无 ipa）。这些是**残余硬骨头**。
- **✗ 不投入**与任务排除一致：TEE/QSEE/SPU、Gunyah/gzvm、ST54、FM、FSA4480、PMIH010x-hv-haptics、debug/minidump 类。
- 前景排序（影响×把握）：**音频整机(tplg/ADSP) > 电池电量 > WiFi/BT 变体校验 > 相机采集 > 温控 OEM 层**；WWAN/触觉/传感器靠后或暂缓。

## 证据（带可核对 URL / 本地路径）
1. **相机 IFE/IPE 主线无驱动**（CAMSS 仅出 raw Bayer via RDI）。直接证据（同类高通手机项目结论）：
   aaronsb/sm-x800-linux issue #27「the IFE/IPE processing pipeline has no mainline driver」。https://github.com/aaronsb/sm-x800-linux/issues/27
   背景（Titan/CAMSS 上游进度）：https://memcpy.io/upstream-camera-support-for-qualcomm-platforms.html
   → 与本项目「libcamera simple 无 s5kjns 3A 标定」残余一致。
2. **GPU/显示已在主线树**。`geekidos-linux/drivers/gpu/drm/msm/`：`adreno/a8xx_gpu.c`、`a8xx_preempt.o`（gen8=Adreno 830）、
   `msm_mdss.c` 有 `qcom,sm8750-mdss`/`qcom,sm8750-dsi-phy-3nm`、`dpu_hw_dsc_1_2.c` 注「SM8750 DPU 12.x」。
   → 故 vendor `msm_kgsl.ko`/`msm_drm.ko` 有 freedreno/msm 对应（A 档，已在工作树）。
3. **音频 codec/machine 已在主线树**。`sound/soc/codecs/wcd939x.c` 存在；`sound/soc/qcom/sc8280xp.c:227`
   `{.compatible="qcom,sm8750-sndcard"}`，并含 `qdsp6/`、`lpass-cpu/cdc`、`sdw.c`。
   → vendor wcd939x/wcd938x/wsa884x/machine_dlkm 有主线对应，残余主要是 ADSP 音频图 + tplg/topology（B 档）。
4. **WiFi WCN7850/FC7800 = ath12k（主线）**。`geekidos-linux/drivers/net/wireless/ath/ath12k/`；文档 https://wireless.docs.kernel.org/en/latest/en/users/drivers/ath12k.html
   命中型号是 WCN7850（17cb:1107）；本板 vendor 是 qca_cld3_wcn7750/peach/kiwi（闭源）→ 需确认 7861↔ath12k 变体（B 档）。
5. **触屏有主线对应**。`elden.dts:3516` `compatible="novatek,NVT-ts-spi"`；主线 `input/touchscreen/Kconfig` 有
   `novatek-nvt36xxx-spi` / `novatek-nvt-ts`，另有 `atmel_mxt_ts`/`goodix`/`focaltech`（A/B 档）。
6. **WWAN/IPA 缺**。`geekidos-linux/drivers/net/ethernet/qualcomm/` 仅有 `rmnet/`、`emac/`、`qca_7k*`，**无 `ipa/`**
   → vendor `ipam/ipanetm/rmnet_offload` 无对应主线 IPA（本树）；WWAN 需回灌/新代上游 IPA（低优先，确认是否 WiFi-only）。
7. **温控 OEM 私有**。主线有 `thermal/qcom/tsens-v2.c`+`lmh.c`(含 BCL)；但 vendor `lenovo_sys_temp.ko`/
   `lenovo_thermal_control.ko` 为 Lenovo 私有，无主线对应（C 档）。
8. **电池/充电私有**。`geekidos-linux/drivers/power` 无 qcom sm8750 充电驱动；`qti_battery_charger.ko`/
   `qti_battery_debug.ko`/`charger-ulog-glink`/`qti_pmic_glink` 属 glink BMS 私有栈（C 档，基础电压/电量可 PMIC ADC 近似）。
9. SM8750 基础支持上游起点（6.14 引入）：https://www.phoronix.com/news/Linux-6.14-SoCs ；
   高通对 8 Elite Gen5 同日上游化的声明（口径参考，注意与 8Eg4/SM8750 区分）：
   https://www.qualcomm.com/developer/blog/2025/10/same-day-snapdragon-8-elite-gen-5-upstream-linux-support

## 候选路线（代价 × 把握排序）
**A｜有主线等价，只需使能/回灌/校验（低代价·高把握）**
- GPU/显示（a8xx + sm8750 mdss/dpu，已树内）；触屏 novatek-nvt；音频 codec（wcd939x/38x/wsa884x+macros+sdw）；
  WiFi ath12k；NFC nxp-nci；基础 SoC（q6v5/pas、smp2p、glink、qrtr、smd、smem）；pinctrl-spmi、nvmem_qfprom、
  qcom-rng/qrng、hwmon、pm8941-pwrkey、leds-qcom-lpg/flash、adc5-gen3、spmi-temp-alarm、tsens/LMH/BCL；
  aw882xx（aw88395）、lt9611uxc/nb7vpq904m（若有显示桥）；coresight/stm 全家（调试，非日常）。

**B｜部分上游，需回灌 + DT + 固件（中代价·中把握）**
- **音频整机**：ADSP q6/q6apm 音频 reach + machine(sc8280xp sm8750-sndcard) + **tplg/topology**（最硬）。
- **WiFi/BT 变体**：确认 WCN7861 与 ath12k/btqca 的 PCI-ID/固件匹配（vendor qca_cld3 与 bt 系是闭源替代）。
- **相机采集**：camss/CSIPHY 出 raw + 传感器上电时序（务实目标=预览/raw，非 3A）。
- **面板/AMOLED**：nt37801/amoled 面板 + qcom-amoled-regulator/qti_amoled_ecm（panel/DRM bridge + DT）。
- **WWAN**：mainline rmnet 在、ipa 缺 → 回灌 IPA 或等新代上游（若为 WiFi-only SKU 可放弃）。

**C｜厂商私有无主线对应（高代价·需自研或长期搁置）**
- 相机全量 camx/CHI + IFE/IPE + 传感器标定；温控 OEM 层（lenovo_sys_temp/thermal_control，可自建薄 thermal zone）；
  电池/充电 glink BMS（qti_battery_charger）；私有传感器 qti_qmi_sensor_v2（QMI/SLPI，iio 无对应）；
  Awinic HV 触觉（awinic,haptic_hv I2C 0x5A/0x5B + swr_haptics，主线无）；h q_*（Lenovo dock/USB 网络私有）；
  统计/调试（bwmon/memlat/llcc_*/mpam*/sysstats/boot_stats/minidump）。

**D｜✗ 不投入（安全域/虚拟化/已冻结）**
- TEE/QSEE/SPU：qsee_ipc_irq_bridge/qseecom_proxy/smcinvoke/tmecom-intf/hdcp_qseecom/qce50/qcedev/qcrypto/gsim；
- Gunyah/gzvm：gh_*/hvc_gunyah/gzvm（属拓展线非 G1）；ST54：stm_st54se_gpio；FM：radio-i2c-rtc6226-qca/bt_fm_swr；
- FSA4480：fsa4480-i2c/sub-i2c（硬件缺失冻结）；PMIH010x hv-haptics（任务列入不投入）；eud/evacc/qfprom-sys 等调试/JTAG。

## 落地步骤
1. 用 `modules.load`/`modules.alias` 交叉当前启动配置，列出「vendor .ko 中已被主线接管」vs「仍缺」的实际差集（先跑差集，别再按名字猜）。
2. 差集里按 A→B→C 优先级：先验证 GPU/触屏/WiFi/音频 codec 是否真 probe（dmesg + lsmod + /sys/class）。
3. 音频：先让 sc8280xp(sm8750-sndcard) + wcd 栈 probe，再攻 tplg/ADSP 图（最大可用性收益）。
4. 电池：先用 PMIC ADC/`qcom-spmi-adc5-gen3` 给近似电量（power_supply），充电控制单列长线。
5. 相机：CSIPHY/camss probe 出 raw，3A/标定列为 C 档长线（不阻塞 G1 其它项）。
6. 对 C/D 明确「不投入」项写清理由，冻结（复用 FSA/ST54/FM 既有冻结口径）。

## 风险与未证实点
- **版本口径**：本树为 Linux **7.2.0**（比常规上游超前）；「主线有」= 本工作树含，回灌/上游化须以官方发布分支复核，勿据此断言稳定上游已含。
- **WCN7861≠WCN7850**：搜索命中是 7850=ath12k；7861 是否同驱动/同固件未证（B 档风险）。
- **IPA 是否真无**：仅查 `drivers/net/ethernet/qualcomm` 无 `ipa/`；上游可能在别处有新代 IPA，未穷尽。
- **电池近似可行性**：PMIC ADC 能否给可用百分比、快充协商能否，未证。
- **分类基于命名 + 树内检索 + 经验推断（inference）**，未逐个确认全部 ≈230 个 vendor .ko 的实际绑定。

## 需父进程在设备上验证的项
1. 本板是否 **WiFi-only**（有无 modem/WWAN 需求）→ 决定 IPA/WWAN 是否彻底放弃。
2. 当前 Linux（7.2 树）开机后 **lsmod/modprobe**：vendor 功能中已被主线接管的实际清单（GPU/触屏/WiFi/音频/充电 现状）。
3. WiFi/BT：ath12k 是否 bind WCN7861（`lspci` PCI-ID、`dmesg` 固件加载）；btqca 固件是否加载。
4. 触屏实际绑 I2C 还是 SPI（`/proc/device-tree` 下 novatek compatible），主线 novatek-nvt-ts/nvt36xxx-spi 能否 bind。
5. 电量/充电现状：现在 power_supply/uevent 电量读数来源与准确度。
6. ALS/自动亮度/罗盘走 PMIC ADC 还是 qti_qmi_sensor（SLPI）→ 决定私有传感器是否必须移植。
7. 相机 CSIPHY/camss 是否 probe、raw 是否出流（决定 B/C 分界）。
