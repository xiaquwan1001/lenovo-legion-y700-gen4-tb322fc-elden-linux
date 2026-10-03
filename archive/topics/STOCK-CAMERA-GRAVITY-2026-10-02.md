# STOCK-CAMERA-GRAVITY-2026-10-02 — 原厂相机 + 重力计(加速度计) 拆解与主线移植评估

> 设备：联想拯救者 Y700 四代 = **TB322FC** = `elden` = **SM8750（Snapdragon 8 Elite，"Sun"）**
> 主线内核：`linux/`（geekidos-linux，**Linux 7.2.0**，本项目自持树，DT 为 `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`）
> 方法：静态拆解（厂商 DT + 主线树 + 联想公开 GPL/固件仓）+ 只读上机核对（`ssh root@192.168.7.1`，未改任何东西）。
> 关联：`STOCK-DRIVERS-2026-09-30.md`、`STOCK-KERNEL-2026-09-30.md`、`INDEX.md`。

---

## 0. 一句话结论（先数字）

| 模块 | 器件 | 结论 | 工作量 |
|---|---|---|---|
| **相机·后** | **三星 S5KJNS**（50MP，QTech 模组） | 主线 camss **已支持 SM8750**，`s5kjns.c` 驱动已在树内；DT 已接好线。当前只是**内核 config 配错 + 模块未部署** | **小（1–2 天）** |
| **相机·前** | **GalaxyCore GC08A8**（8MP，Sunwin 模组） | `gc08a8.c` 驱动已在树内，DT 已接好，同上只差 config | **小** |
| **重力计/加速度计** | **ST LSM6DSO**（6 轴 IMU：加速度计+陀螺） | **挂在 SLPI/SSC 传感器核 I2C（非 AP I2C）**，主线无 QMI-SNS 栈 → IIO 摸不到 | **极大（不可短期落地）** |

**核心判断**：相机比任务预期乐观得多（主线 camss 对 SM8750 的"高度不成熟"是旧印象，本项目 7.2.0 树里 camss + 全部 sensor 驱动都已就位）；重力计比"写个 IIO 驱动"难一个数量级——它根本不在 AP 的 I2C 上，而是被 Snapdragon 传感器核（SLPI/SSC）吞掉了。

---

## 1. 相机 · 器件识别表

证据链：主线 DT（权威，作者已按厂商 DT 逆向填好）→ 厂商 dtbo `backup/stock-elden/elden.dts` → 联想固件仓 `proprietary_vendor_lenovo_elden` 的 camx sensor 模块（硬件最终裁决）。

### 1.1 器件与连接

| 项 | 后置（主摄） | 前置 |
|---|---|---|
| **sensor 型号** | **Samsung S5KJNS**（50MP） | **GalaxyCore GC08A8**（8MP） |
| camx 模块（固件实锤） | `com.qti.sensor.s5kjns_qtech_main.so` / `com.qti.sensormodule.s5kjns_qtech_main.bin` / `com.qti.eeprom.gt24p128e2csli_s5kjn1.so` | `com.qti.sensor.gc08a8_sunwin_front.so` / `com.qti.sensormodule.gc08a8_sunwin_front.bin` |
| 主线 DT 节点 | `&cci0_i2c0 camera@56`（`samsung,s5kjns`） | `&cci1_i2c0 camera@31`（`galaxycore,gc08a8`） |
| CCI（相机控制总线） | **CCI0**（`cci@ac7b000`），I2C 0x56 | **CCI1**（`cci@ac7c000`），I2C 0x31 |
| CSIPHY | **CSIPHY3**（厂商 `csiphy-sd-index=3`；主线 `port@3`） | **CSIPHY4**（`port@4`） |
| CSI 数据 lane | 4 lane（`data-lanes=<1 2 3 4>`） | 4 lane |
| link-frequency | **672 MHz** | **336 MHz** |
| MCLK | `CAM_BIST_MCLK_CC_MCLK3`，**19.2 MHz**（gpio 92 = 厂商 `CAMIF_MCLK3`） | `MCLK4`，19.2 MHz（gpio 93） |
| reset GPIO | tlmm **11**（厂商 `CAM_RESET0`） | tlmm **7**（`CAM_RESET4`） |
| 供电（WL2868C LDO） | dovdd=**LDO7**(1.8V)、dvdd=**LDO1**(1.128V)、avdd=**LDO4**(2.824V) | dovdd=LDO7、dvdd=**LDO2**(1.288V)、avdd=**LDO3**(2.816V) |
| AF 镜头 | **Giantec GT9764** VCM @ 0x0c（vdd=LDO5 2.808V） | —（定焦） |
| 闪光灯 | PM8550 flash0/flash3 + torch0/torch3（`qcom,camera-flash1`） | — |

> 主线 DT 证据：`geekidos-linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` 行 1556–1629（`&cci0_i2c0` / `&cci1_i2c0` 两个 sensor 节点 + `lens@c`）、行 1426（`willsemi,wl2868c` 相机 PMIC `pmic@2f` 及 LDO1–7 电压）。
> 厂商 DT 证据：`backup/stock-elden/elden.dts` 行 12524–12690（`qcom,cam-sensor0/1`、`qcom,actuator0`、`qcom,eeprom0/1`）、行 12506（`led_flash_rear`）。
> 固件实锤：`gh api …/proprietary_vendor_lenovo_elden/contents/proprietary/vendor/lib64/camera`（`com.qti.sensor.*.so` 列表，见上）。

### 1.2 上机现状（只读采集，`scripts/probe-camera-sensors.sh`）

```
DT 节点      : isp@ad27000 / cci@ac7b000 / cci@ac7c000 均在
CCI 下挂     : /soc@0/cci@ac7b000/i2c-bus@0/{lens@c,camera@56}
               /soc@0/cci@ac7c000/i2c-bus@0/camera@31
相机 PMIC    : 10-002f wl2868c（I2C 设备在，但 driver=NONE，未绑定）
V4L2/media   : 无任何 /dev/video* /dev/media*（camss 未加载）
内核 config  : CONFIG_VIDEO_QCOM_CAMSS=m  ✓
               CONFIG_VIDEO_S5KJN1=m     ✗（配错——应为 S5KJNS）
               # CONFIG_VIDEO_S5KJNS 未开 ✗
               # CONFIG_VIDEO_GC08A8 未开 ✗
               # CONFIG_VIDEO_GT9764 未开 ✗
               # CONFIG_REGULATOR_WL2868C 未开 ✗
模块部署     : /lib/modules 下无 camss/s5kj/gc08/gt9764/wl2868 *.ko（构建了但没装进 rootfs）
dmesg 早期   : "Fixed dependency cycle(s) with …/camera@56 ↔ isp@ad27000"（见 §3.2）
```

---

## 2. 重力计/加速度计 · 器件识别表

### 2.1 器件

| 项 | 值 |
|---|---|
| **芯片型号** | **ST LSM6DSO**（6 轴 MEMS IMU = 3 轴加速度计 + 3 轴陀螺仪，iNEMO 惯性模块） |
| 所属平台 | SLPI/SSC 传感器核的 **"pakala"** 平台（= SM8750 = "Sun"，`soc_id: ["618","639"]`，618=0x26a=Sun，639=0x27f=SunP） |
| 总线 | **SLPI/SSC 私有 I2C 总线实例 3**（`bus_type=1`(I2C)、`bus_instance=3`），**不在 AP 任何 I2C 上** |
| I3C 动态地址 | 10（`i3c_address=10`；I2C 标准地址 0x6A/0x6B） |
| 中断 | **DRI 数据就绪中断 = SLPI GPIO 80**（`dri_irq_num=80`、`irq_trigger_type=3`、`irq_is_chip_pin=1`） |
| 供电 | `vddio_rail = "/pmic/client/sensor_vddio"`（SLPI 侧 PMIC 客户端，非 AP regulator） |
| ODR | 20–500 Hz（`min_odr=20`、`max_odr=500`） |
| 安装朝向 | x=+x、y=-y、z=-z（`lsm6dso_0.orient`） |
| 附属流 | 同片 IMU 还出 `.ois_gyro/.ois_accel`（供后摄 OIS 用） |

> 证据路径（联想固件仓，`gh api` 只读拉取）：
> `proprietary_vendor_lenovo_elden/proprietary/vendor/etc/sensors/config/`
> - `json.lst`（列出所有 sensor 配置，`pakala_*` 排最前 = 本机平台）
> - `pakala_default_sensors.json`（`.sensor_temperature` attr_1 = `"lsm6dso"`，点名 IMU）
> - `pakala_lsm6dso_0.json`（LSM6DSO 全部物理参数，见上表）
> - `pakala_mmc56x3x_0.json`（磁力计 MEMSIC MMC56x3x，SLPI I2C 实例 2，`i3c_address=20`）
> - `pakala_power_0.json`（`enable_island=1`，传感器岛供电）

### 2.2 传感器全集（同属 SLPI，"pakala" 平台）

| 功能 | 芯片 | 证据文件 |
|---|---|---|
| 加速度计+陀螺 | **ST LSM6DSO**（本任务主角） | `pakala_lsm6dso_0.json`（备选 `lsm6dsv_0`、`icm4x6xa_0`） |
| 磁力计 | MEMSIC **MMC56x3x**（备选 QST QMC630x） | `pakala_mmc56x3x_0.json` |
| 气压计 | ST **LPS22DF** | `pakala_lps22df_0.json` |
| 温湿度 | Sensirion **SHT4x** | `pakala_sht4x_0.json` |
| SAR/接近 | Semtech **SX932x** | `pakala_sx932x_0.json` |
| 霍尔 | ROHM **BU52053NVX** | `pakala_bu52053nvx_0.json` |
| 光感/接近 | AMS **TMD3765** | `pakala_tmd3765_0.json` |

### 2.3 为什么 AP 上看不到它（关键架构事实）

1. 厂商**基础 DTB**（`backup/stock-elden/dtb/*_Sun_SoC.dtb`、`*_Kera_SoC.dtb`）与 **dtbo overlay**（`elden.dts`）里**都没有任何运动传感器 I2C 节点**——只有相机 MCLK pinctrl 与 thermal。
2. 上机 `ls /sys/bus/i2c/devices/` 只有 `i2c-5/6/9/10`：typec 复用(0x42/43/4f)、haptic(0x5a/5b)、音频功放(0x34/37)、相机 PMIC(0x2f)、背光(0x76)。**没有 IMU/磁力计地址**。
3. SM8750 的 **SLPI 与 ADSP 合并**（`adspslpi@9ee00000`，59 MiB 保留内存），传感器核由 `remoteproc_adsp` 一起拉起（上机 `remoteproc0 name=adsp state=running`）；传感器数据经 **glink 上的 QMI-SNS（Sensors）协议**回 AP。
4. 主线**没有** QMI-SNS / SLPI 传感器驱动栈（无 `qcom,sns` IIO 桥）。故 IIO 驱动 `st_lsm6dsx` 虽然**支持 `st,lsm6dso` 且本项目已开 `CONFIG_IIO_ST_LSM6DSX=m`**，也**永远匹配不到设备**（设备不在 AP I2C 上）。

---

## 3. 主线支持现状与移植方案

### 3.1 相机 —— 结论：能做，且比预期容易得多

**主线树（本项目 7.2.0）已具备全部部件：**

| 部件 | 主线路径 | compatible | 状态 |
|---|---|---|---|
| CAMSS 平台驱动 | `drivers/media/platform/qcom/camss/camss.c` | `qcom,sm8750-camss`（`sm8750_resources`，行 6089/6136） | ✅ 支持 SM8750 |
| 后摄驱动 | `drivers/media/i2c/s5kjns.c` | `samsung,s5kjns`（行 808） | ✅ 在树（`VIDEO_S5KJNS`） |
| 前摄驱动 | `drivers/media/i2c/gc08a8.c` | `galaxycore,gc08a8`（行 881） | ✅ 在树（`VIDEO_GC08A8`） |
| 镜头驱动 | `drivers/media/i2c/gt9764.c` | `giantec,gt9764`（行 237） | ✅ 在树（`VIDEO_GT9764`） |
| 相机 PMIC | `drivers/regulator/wl2868c-regulator.c` | `willsemi,wl2868c` | ✅ 在树（`REGULATOR_WL2868C`） |
| DT 接线 | `sm8750-lenovo-elden.dts`（`&camss`/`&cci0_i2c0`/`&cci1_i2c0`） | — | ✅ 已接（compatible 全对得上） |

**当前没起来的原因（3 个，全是小事）：**

1. **内核 config 配错/没开**：开了 `VIDEO_S5KJN1=m`（错误型号），真正需要的 `VIDEO_S5KJNS`、`VIDEO_GC08A8`、`VIDEO_GT9764`、`REGULATOR_WL2868C` 全是 `# not set`。→ 改 config。
2. **模块没部署**：`/lib/modules` 里没有任何 camera 相关 `.ko`（构建产物在 `geekidos-linux/drivers/media/…` 下，但没 `make modules_install` 进 rootfs）。→ 装模块 + `modprobe`。
3. **DT 依赖环告警**：dmesg 报 `camera@56/31 ↔ isp@ad27000` 的 "Fixed dependency cycle(s)"（fwnode graph 双向引用，通常是 sensor 与 camss 互相引用时钟/供电导致，**warning 非致命**，但会拖慢/打乱 probe 顺序）。→ 可选：sensor 节点去掉对 camss 的反向引用或加 `endpoint` 排序。

**工作量估计：1–2 天。** 步骤：

```
1. patches/config-* 里开：VIDEO_S5KJNS=m / VIDEO_GC08A8=m / VIDEO_GT9764=m /
   REGULATOR_WL2868C=y（或 m）
2. 重新 make + 把 *.ko 装进 rootfs（make modules_install / 手动 scp）
3. modprobe qcom-camss s5kjns gc08a8 gt9764（wl2868c 用 built-in 更稳）
4. 验证：/dev/video*、media-ctl -p 出现 csiphy3/4 + sensor pad
5. 若探不到 sensor：处理 §3.2 依赖环；确认 wl2868c LDO 电压被正确设置
```

> 现实提醒：SM8750 camss 的 **ISP/VFE 输出**在主线仍是"best effort"（能枚举、能出 CSI raw，但完整拍照流水线/3A 未必好用）；**拿到图像的最小目标（sensor 枚举 + 裸流）是可预期的**。不要指望主线相机达到 Android 拍照画质。

### 3.2 相机遗留小坑

- **依赖环**：`camera@56` 的 `power-domains = <&camcc CAM_CC_TITAN_TOP_GDSC>` 与 camss 的 GDSC/时钟形成 fwnode 环。真实根因是 sensor 与 isp 共享 titan_top_gdsc 且互为 endpoint。修法：让 sensor 通过 `remote-endpoint` 单向指向 camss，并把 GDSC 归属单一 owner（通常 camss 持有，sensor 用 `power-domains` 引用即可，kernel 会去重）。
- **WL2868C 电压**：主线 DT 已按厂商"含偏移"电压写死（LDO1=1.128V…），若换内置 wl2868c-regulator 驱动，注意其 `regulator_ops` 是否支持 set_voltage（该驱动很薄，见 `wl2868c-regulator.c` 行 34–41，只实现 enable/is_enabled），**实际电压可能靠 DT fixed 而非运行时设定**——对 sensor 上电已够用。

### 3.3 重力计 —— 结论：IIO 走不通，短期放弃

**主线 `st_lsm6dsx` 驱动支持 LSM6DSO（`st,lsm6dso`），且已编成模块**——但问题不在驱动，在**硬件拓扑**：芯片挂在 SLPI/SSC 的私有 I2C 上，AP 侧没有任何 I2C 脚连到它。

三条路：

| 方案 | 说明 | 工作量 | 可行性 |
|---|---|---|---|
| A. 完整 SLPI/QMI-SNS bring-up | 让 remoteproc 拉起 SLPI 传感器核 + 实现 QMI-SNS（Sensors）glink 服务 + IIO 桥 | **数周～数月**，且 SLPI 传感器固件是闭源 blob、QMI-SNS 协议栈无主线参照 | ❌ 不现实 |
| B. 硬件飞线/外挂 | 把 LSM6DSO 引到 AP 空闲 I2C（板级改线，不现实）或用 USB/SPI 外置 IMU | 硬件改动 / 外设 | ❌ 不合本机目标 |
| C. 维持现状 | 重力/陀螺在主线 Linux 上缺失，靠"屏幕自动旋转"等**改用内置 accel 不行，只能软件禁用** | 0 | ✅ 务实 |

**结论**：重力计在主线 Linux 上是**被架构卡死**，不是"移植一个 IIO 驱动"能解决的。除非有人完成 SLPI 传感器核的整条 bring-up（远超本任务范围），否则**不建议投入**。唯一低垂果实：若未来 SLPI/QMI 桥落地，`st_lsm6dsx` 驱动和 DT 写法现成可用（`st,lsm6dso`）。

---

## 4. 交付物与复现

- **本文档**：`STOCK-CAMERA-GRAVITY-2026-10-02.md`
- **只读探测脚本**：`scripts/probe-camera-sensors.sh`
  - 用法：`./scripts/probe-camera-sensors.sh`（主机 SSH 采集）或 `--local`（设备上直接跑）
  - 输出：DT 节点 / I2C 设备 / CCI / V4L2 / 模块 / kernel config / IIO / dmesg / remoteproc 十段只读状态。
  - 全程**零写入**：不 modprobe、不 mount、不动 /data、不重启。

### 关键证据速查（路径 + 行号）

| 事实 | 证据 |
|---|---|
| 后摄 S5KJNS + 前摄 GC08A8 | `geekidos-linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts:1566/1604`；固件 `proprietary_vendor_lenovo_elden/…/lib64/camera/com.qti.sensor.s5kjns_qtech_main.so`、`com.qti.sensor.gc08a8_sunwin_front.so` |
| camss 支持 SM8750 | `geekidos-linux/drivers/media/platform/qcom/camss/camss.c:6136` |
| 三 sensor 驱动在树 | `drivers/media/i2c/{s5kjns.c:808, gc08a8.c:881, gt9764.c:237}` |
| 相机 PMIC 驱动在树 | `drivers/regulator/wl2868c-regulator.c` |
| 加速度计 = LSM6DSO（SLPI I2C3） | `proprietary_vendor_lenovo_elden/…/vendor/etc/sensors/config/pakala_lsm6dso_0.json`（bus_instance=3, dri_irq_num=80） |
| pakala = SM8750 Sun | 同目录 `pakala_default_sensors.json`（soc_id 618/639 = 0x26a/0x27f） |
| 上机 config 现状 | `zcat /proc/config.gz`（见 §1.2 表） |
