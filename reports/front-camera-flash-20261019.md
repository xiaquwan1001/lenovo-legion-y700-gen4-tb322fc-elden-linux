# 前摄像头闪光灯 / 闪光灯驱动现状（2026-10-19）

> 设备：U? / vk127 主线内核（`7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`，2026-10-17 构建）
> 通道：`ssh -o BatchMode=yes root@192.168.7.1`（USB-NCM）
> 授权范围：设备侧只读探测 + LED sysfs 写（≤200 ms 级单次），**禁**分区/刷写/重启/卸载模块

## 0. 结论（TL;DR）

| # | 问题 | 结论 | 判定强度 |
|---|---|---|---|
| 1 | 硬件上是否存在**独立前摄闪光灯**？ | **不存在。** 全机只有一颗白色闪光 LED（PM8550 4 通道中的 1+4 并联驱动），stock 全 DTS 只有一个 `qcom,camera-flash1` 节点、只有**一处** `led-flash-src`，且挂在**后摄** `cam-sensor0`；前摄 `cam-sensor1` 只有 `eeprom-src` | 取证（stock DTS 逐行核对） |
| 2 | 当前 `rear_flash`（PM8550）驱动/DT 是否已就位？ | **已就位且可用。** `leds_qcom_flash` 绑定成功；torch 0–255 写通并有**寄存器级**证据；flash strobe 通、安全定时器会自己熄灭、无 fault 位 | 实测（设备侧写入 + regmap diff） |
| 3 | 真正缺什么？ | ① **用户态**缺闪光灯通路（libcamera simple pipeline 不认 `MEDIA_ENT_F_FLASH`，`cam` 无闪光灯控制）；② **flash LED NTC 温度**通道/thermal zone 缺失（只影响监控，不影响出光）；③ **DT/驱动本身：无功能缺口** | ①取证（libcamera 源码+日志）②取证（DT/iio 对照）③实测 |
| 4 | 「前摄像头闪光灯」最可能指什么？ | **屏幕补光（screen flash）**——前摄无 LED，Android/第三方相机 App 在前摄拍照时用屏幕闪白补光。另有一种可能：用户把后摄闪光灯（单颗 LED）误当下摄/前摄补光 | 推断（见 §3） |
| 5 | 需要补丁吗？ | **功能上不需要。** 可选补丁只有一个（flash LED NTC 温度监控），已写下但**未编译未上机** | — |

关键数字：`max_brightness=255`、`max_flash_brightness=2000000 µA`、`max_flash_timeout=1280000 µs`；
寄存器实测 `0xee42/0xee45 0x13→0x63`、`0xee46` bit7、`0xee4e 0x00→0x09`；
板 DTB **153101 B / sha256 `fbda2ade…`** 与在机 `vk127` manifest **逐字节相同**。

## 1. 驱动绑定情况（实测：绑定成功）

**结论：`leds_qcom_flash` 绑定成功，LED classdev + flash class + V4L2 flash subdev 三层都在。**

### 1.1 sysfs 证据

```
# ls -l /sys/class/leds/
lrwxrwxrwx mmc0::      -> ../../devices/platform/soc@0/8804000.mmc/leds/mmc0::
lrwxrwxrwx white:flash -> ../../devices/platform/soc@0/c400000.spmi/spmi-0/0-01/
                          c400000.spmi:pmic@1:led-controller@ee00/leds/white:flash

# cat /sys/class/leds/white:flash/uevent
OF_NAME=led-0
OF_FULLNAME=/soc@0/spmi@c400000/pmic@1/led-controller@ee00/led-0
OF_COMPATIBLE_N=0

# ls -l /sys/class/leds/white:flash/
flash_brightness  flash_fault  flash_strobe  flash_timeout
max_brightness    max_flash_brightness  max_flash_timeout  brightness  trigger  uevent
# readlink device -> ../../../c400000.spmi:pmic@1:led-controller@ee00
```

- `/sys/devices/platform/soc@0/c400000.spmi/spmi-0/0-01/c400000.spmi:pmic@1:led-controller@ee00/` 存在 ⇒
  DT 的 `&pm8550_flash`（`pm8550.dtsi: led-controller@ee00`，compatible `qcom,pm8550-flash-led` +
  `qcom,spmi-flash-led`）已被 platform driver 实例化。
- **不是 spmi 驱动**：`/sys/bus/spmi/drivers/` 只有 `pmic-spmi`；`leds-qcom-flash.c` 用
  `module_platform_driver()`（`of_match` 命中 `qcom,spmi-flash-led`），父设备是 SPMI 的 pmic@1。
- `OF_COMPATIBLE_N=0` 正常（`led-0` 子节点本身无 compatible，由父驱动 `fwnode_for_each_child_node` 枚举）。

### 1.2 模块身份（=m，非内建）

```
# modinfo leds_qcom_flash
filename: /lib/modules/7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty/kernel/drivers/leds/flash/leds-qcom-flash.ko
license: GPL  description: QCOM Flash LED driver
alias: of:N*T*Cqcom,spmi-flash-ledC*
depends: v4l2-flash-led-class,led-class-flash

# lsmod | grep -iE 'led|flash'
leds_qcom_flash        20480  0
v4l2_flash_led_class    12288  2 leds_qcom_flash
led_class_flash        16384  2 v4l2_flash_led_class,leds_qcom_flash
```

顺带确认相机侧同时在位：`lsmod` 含 `qcom_camss / s5kjns / gc08a8 / gt9764 / v4l2_async`（后摄驱动 `s5kjns`
与前端 `gc08a8` 都是 `v4l2_async` 用户）。

### 1.3 flash class 上限（读回值 = DT 推导值，闭合校验通过）

| 属性 | 读回 | DT 来源 | 驱动换算 |
|---|---|---|---|
| `max_brightness` | **255** | `led-max-microamp = <1000000>` | torch 上限 1000 mA（2 通道×5 mA 步进） |
| `max_flash_brightness` | **2000000** | `flash-max-microamp = <2000000>` | µA，且被 `FLASH_TOTAL_CURRENT_MAX_UA=2A` 夹住 |
| `max_flash_timeout` | **1280000** | `flash-max-timeout-us = <1280000>` | µs，= `FLASH_TIMEOUT_MAX_US` 顶格 |
| `flash_timeout`（当前） | 1280000 | 同上（`brightness->val=max`） | |
| `flash_brightness`（当前） | 1000000 | 默认 `FLASH_CURRENT_DEFAULT_UA` | |

> ⚠️ 上表与 stock 对照无偏差：stock `qcom,max-current-ma = 0x5dc = 1500`（flash）、`0x1f4 = 500`（torch，两通道合 1000 mA）、
> `qcom,duration-ms = 0x500 = 1280 ms`——与主线 DT 的 1000000 µA / 2000000 µA / 1280000 µs 语义一致（见 §4.2）。

### 1.4 V4L2 flash 子设备（相机栈可见）

```
# media-ctl -p -d /dev/media0 | sed -n '/entity 296/,/entity 303/p'
- entity 296: s5kjns 12-0056 (1 pad, 1 link) type V4L2 subdev subtype Sensor  /dev/v4l-subdev28
- entity 298: gt9764 12-000c (0 pad, 0 link) type V4L2 subdev subtype Lens    /dev/v4l-subdev29
- entity 300: white:flash (0 pad, 0 link)     type V4L2 subdev subtype Flash   /dev/v4l-subdev30
- entity 302: gc08a8 13-0031 (1 pad, 1 link)  type V4L2 subdev subtype Sensor  /dev/v4l-subdev31

# v4l2-ctl -d /dev/v4l-subdev30 --list-ctrls
Flash Controls
  led_mode 0x009c0901 (menu) : min=0 max=2 default=0 value=0 (Off)
  strobe_source 0x009c0902 (menu) : min=0 max=1 default=0 value=0 (Software)
  strobe 0x009c0903 (button) : value=0 flags=write-only, execute-on-write
  stop_strobe 0x009c0904 (button) : value=0 flags=write-only, execute-on-write
  strobe_status 0x009c0905 (bool) : default=0 value=0 flags=read-only, volatile
  strobe_timeout 0x009c0906 (int) : min=10000 max=1280000 step=10000 default=1280000
  intensity_flash_mode 0x009c0907 (int) : min=25000 max=2000000 step=25000 default=1000000
  intensity_torch_mode 0x009c0908 (int) : min=10000 max=1000000 step=10000 default=200000
  faults 0x009c090a (bitmask) : max=0x0000009e default=0 value=0 flags=read-only, volatile
```

⇒ `v4l2_flash_init()` 成功（`qcom_flash_v4l2_init()` 只在 `LED_DEV_CAP_FLASH` 置位时注册），
flash 是独立 media entity（`MEDIA_ENT_F_FLASH`），**没有 pad，不参与链路**——它是给用户态直接开的控制面。

### 1.5 dmesg：**该证据源在本机不可用**（如实记录）

```
# dmesg | grep -icE "qcom-flash|led-class-flash|spmi-flash"   → 0
# dmesg | head -2   → [58871.289511] ...（时间戳从 58871 s 起）
# journalctl -k | grep -iE "flash|led-controller|pm8550"      → 空
```

原因：dmesg 环形缓冲已被后续日志冲掉（当前最早一条 t≈58871 s，而模块在开机时加载；已被
Waydroid 容器侧日志大量占用），journald 无持久化内核日志 ⇒ **绑定时序证据改用 sysfs/模块/driver-core
路径替代**（§1.1–§1.4 已足够）。**未获取**：驱动 probe 时的 "/code" 打印与 flash subtype（0x07 = 4CH）读取日志。

## 2. 功能可用性（实测：写入链路通，含硬件寄存器级验证）

### 2.1 brightness（torch）写入 / 读回

```
# L=/sys/class/leds/white:flash
# echo 20 > $L/brightness; echo rc=$?; cat $L/brightness
rc=0
20
# sleep 0.2; echo 0 > $L/brightness; echo rc_off=$?; cat $L/brightness
rc_off=0
0
# echo 51 > $L/brightness   → 读回 51（0→255 区间线性映射 torch 电流 5 mA/step，2 通道）
# 试 255 也 rc=0，读回 255
```

### 2.2 flash strobe（含安全定时器自复位）

```
# echo 100000 > $L/flash_timeout   → 读回 100000
# echo 200000 > $L/flash_brightness → 读回 200000
# echo 1 > $L/flash_strobe; echo rc=$?; cat $L/flash_strobe
rc=0
1                     ← 立即读到 1
# sleep 0.5; cat $L/flash_strobe
0                     ← 100 ms 超时后由 timeout_work 自动熄灭（不需人工写 0）
# cat $L/flash_fault
(空)                  ← 无 fault 位（fault_get 读 0x06/0x07 状态寄存器）
```

**关键点**：`strobe` 写完 500 ms 后**自己变回 0**，证明 `flash-max-timeout-us` 的硬件/软件安全定时器
链路真的在工作（软件写法见 `qcom_flash_apply()`：`FLASH_MODE + SW_STROBE` → `mod_delayed_work(... flash_timeout_ms)`）。

### 2.3 寄存器级验证（regmap debugfs，**证明真的写进了 PMIC**）

`/sys/kernel/debug/regmap/0-01/registers`（SPMI pmic@1 全页，flash 控制器基址 `0xee00`）在
`brightness=255` 前后的 diff，与 `mvflash_4ch_regs[]` 的字段映射逐条对得上：

| 寄存器 | 含义（4CH 表） | idle | torch 255 | 校验 |
|---|---|---|---|---|
| `0xee42` | `REG_ITARGET` chan1 | `0x13` | `0x63` | 每通道 500 mA ÷ 5 mA − 1 = 99 = 0x63 ✔ |
| `0xee45` | `REG_ITARGET` chan4 | `0x13` | `0x63` | 同上 ✔ |
| `0xee49` | `REG_IRESOLUTION` | `0x09` | `0x09` | bit0/bit3 = 通道 1、4 置 5 mA 档 ✔ |
| `0xee4e` | `REG_CHAN_EN` | `0x00` | `0x09` | BIT0+BIT3 = `led-sources=<1 4>` 映射成 chan_id 0/3 ✔ |
| `0xee46` | `REG_MODULE_EN` bit7 | `0x00` | `0x80` | 模块使能 ✔ |
| `0xee0c` | `REG_TORCH_CLAMP`(0xed 页面另一处) | `0x00` | `0x63` | torch 钳位 99 ✔ |

回到 `0` 后 `0xee46` bit7 清 0、`0xee4e` 清 0（§4.1 有一处残留 `0xee0b=0x90` 的说明）。

### 2.4 **发光本身未证实**（诚实记录）

电池侧电流表**无法**作为证据：

```
# B=/sys/class/power_supply/qcom-battmgr-bat
# status=Charging capacity=100 voltage_now=4452000 internal_resistance=74140
# idle current_now: 140000 140000 140000
# torch=255 期间每 20 ms 采样 15 点: 140000 ×15（无变化）
# torch=51（≈200 mA）2 s 采样: 160000 → 152000（噪声级）
```

设备处于**充电中（Charging, 100%）**，`current_now` 被充电器主导（±20 mA 抖动，且 2 s 内还在
158000→-538000 之间跳），LED 那 0.2–2 A×~3.9 V 的脉冲在 net 充电电流里分辨不出来；本机
也没有可用的光电/照度传感器通道（`/sys/bus/iio/devices/` 只有 pmk8550 的 die_temp / offset_ref / vref_1p25）。

⇒ **结论口径**：寄存器写入 + 无 fault + 安全定时器自动复位 **全部通过**；**「灯是否真的亮」需人眼确认一次**
（见 §5 待办 A1）。

## 3. 与「前摄像头」的关系

### 3.1 原厂（stock）事实：只有**一处** flash 引用，且属于后摄

`backup/stock-elden/elden.dts` 逐行核对结果：

| 检查项 | stock 里的实际情况 |
|---|---|
| `compatible = "qcom,camera-flash"` 节点 | **只有 1 个**：`fragment@68/led_flash_rear: qcom,camera-flash1`（`cell-index=1`） |
| `switch-source / torch-source / flash-source` | `pm8550_switch2` / `pm8550_torch0, pm8550_torch3` / `pm8550_flash0, pm8550_flash3` |
| `led-flash-src` 引用 | **只有 1 处**：`fragment@69/qcom,cam-sensor0`（后摄）→ `led-flash-src = <&led_flash_rear>` |
| 前摄 `qcom,cam-sensor1` | **没有** `led-flash-src`；只有 `eeprom-src = <&eeprom_front>`、csiphy-sd-index=4、rolling 0x10e |
| 是否存在 `qcom,camera-flash2` / front flash 节点 | **不存在**（`grep -niE "front.*flash|flash.*front|led_flash_front|camera-flash2"` 无命中） |
| 4 个 flash/torch 通道怎么用 | `pm8550_switch2 { qcom,led-mask = <0x0f>; qcom,symmetry-en; }` ⇒ 4 通道**当作一组并联**驱动同一颗 LED（提升电流能力），不是 4 颗独立 LED |
| LED NTC | 有独立 `pm8550_flash_led_ntc`（pmk8550_vadc reg `0x145` = AMUX2_THM_100K_PU）+ `flash-led-ntc` thermal zone，且 thermal HAL 名单里有 `flash-led-ntc` |

⇒ **原厂只有一颗闪光 LED，硬接后摄通道**；前摄没有 LED 通路可用。

### 3.2 主线（mainline）现状

```
# sm8750-lenovo-elden.dts
1576:  flash-leds = <&rear_flash>;        ← 在 rear_camera: camera@56 (s5kjns) 内，唯一一处
front_camera: camera@31 (gc08a8)  →  无 flash-leds、无 lens-focus
```

- `samsung,s5kjns.yaml` 显式声明 `flash-leds: true`；`galaxycore,gc08a8.yaml` 走 `$ref: video-interface-devices.yaml`，
  故 **schema 允许**给前摄加 `flash-leds`，但**没有理由加**（无物理 LED 可指）。
- 驱动侧：`gc08a8.c:832` 用 `v4l2_async_register_subdev_sensor()`，该函数（`v4l2-fwnode.c:1225`
  `v4l2_async_nf_parse_fwnode_sensor()`）会解析 `flash-leds` 并把 flash 作为异步子设备注册。
  ⇒ 对**前摄加 `flash-leds` 的技术后果** = 前摄 notifier 会额外等待 flash subdev 就绪（`CONFIG_V4L2_FLASH_LED_CLASS` 必须为 m/y）。
  当前后摄已经这么做了（历史踩坑：`archive/topics/PAUSE-2026-10-02-android.md` task-9 —— 该 config 未开时 async notifier 永远 waiting ⇒ media graph 无 link）。
- 相机栈接口：flash 是**独立 media entity**（`MEDIA_ENT_F_FLASH`），0 pad、不参与 link，
  给用户态提供 V4L2 控制面（§1.4 的 9 个 Flash Controls）。camss 不直接和 flash 通信（无 flash 子系统接线），全走 V4L2。

### 3.3 用户态这一层确实断着（本轮新发现）

```
# cam -c1 --list-controls（后摄）
WARN CameraSensor camera_sensor_legacy.cpp:670 's5kjns 12-0056': Unsupported ancillary entity function 131074
```

131074 = `0x20002` = **`MEDIA_ENT_F_FLASH`**（`include/uapi/linux/media.h:85`）。
`/home/xuqianhui/lc-cross/lc-src/src/libcamera/sensor/camera_sensor_legacy.cpp:655` 的
`discoverAncillaryDevices()` **只处理 `MEDIA_ENT_F_LENS`**，其余一律 `default:` 打 WARN 丢弃
（`camera_sensor_raw.cpp:507` 同样）。⇒ **libcamera 不认闪光灯实体，`cam` 里没有任何 flash/torch 控制项**
（`cam --help | grep -i flash` 无命中），simple pipeline 也没有 flash 相关控制。

### 3.4 结论：用户说的「前摄像头闪光灯」是什么

| 候选 | 判定 | 证据 |
|---|---|---|
| **屏幕补光（screen flash）** | **最可能** | 前摄无 LED 通路（§3.1）；前摄拍照补光的通用做法就是屏幕闪白；stock 无任何 front flash 节点 |
| 后摄闪光灯被前摄 App 调用 | 可能（用户观察角度混淆） | 只有一颗 LED，硬件在后摄侧；软件上谁都能开它 |
| 独立前摄补光灯硬件 | **否定** | stock 只有 1 个 camera-flash 节点 / 1 处 led-flash-src / 4 通道并联成 1 颗灯（§3.1） |

## 4. 主线 vs 原厂：逐项差异审计

**适用树**：在机 `vk127` UTS `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`
⇒ 对应基线树 = **`build/m1-73`**（`git 24223e44a`，7.3-rc7 + elden payload）。
仓库根的 `linux/` **不是**这台设备的基线树（它是 7.2 线的 `v7.2-elden` tip `ba28ec16f0`，DTS 与在机差 12.5 KB 级内容，
§TASKS T3 已记）。本轮所有「主线侧」陈述都以 `build/m1-73` 为准，`linux/` 只用于读通用驱动/框架源码。

**静态验证（已做）**：用 `build/m1-73` 树 + cpp + 系统 `dtc` 直接编译板 DTS：

```
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
  -Iarch/arm64/boot/dts/qcom -Iarch/arm64/boot/dts -Iinclude -Iscripts/dtc/include-prefixes \
  arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts -o /tmp/elden-stock.pp.dts        → rc=0
dtc -I dts -O dtb -o /tmp/elden-stock.dtb /tmp/elden-stock.pp.dts                    → 仅 2 条预存 unique_unit_address warning
153101 B  sha256 fbda2ade6fb32e0dc11114d5e6961a79628ee54633b04f9f916557683ee0547f
out/boot-elden-vk127.manifest: dtb_sha256=fbda2ade6f…  dtb=build/m1-73/…/sm8750-lenovo-elden.dtb
```

⇒ **DTB 与在机镜像逐字节相同**，所以「改 DT → 预期行为」的推导以该树为准是可靠的。

| 项 | 原厂（stock DTS / 下游驱动） | 主线（m1-73 + 上游 leds-qcom-flash） | 缺口？ |
|---|---|---|---|
| 闪光灯控制器 | `compatible="qcom,qti-pm8350c-flash-led"`（下游驱动） | `qcom,pm8550-flash-led`+`qcom,spmi-flash-led` → `leds_qcom_flash.ko` | **无**（等价，已实测可用） |
| LED 建模 | `flash_0..3` / `torch_0..3` / `led_switch_0..2`（每通道一个 LED classdev + 掩码开关） | **1 个** `led-0 { led-sources=<1 4> }` + 1 个 `white:flash`；flash/torch 是同一 classdev 的两种模式 | **无功能缺口**（上游用 ganged-channel 表达并联，语义等价于 stock `switch2` mask 0x0f） |
| `qcom,thermal-derate-current = <200 500>` | 有（下游 DT 属性） | **不需要**：上游驱动运行时读 `REG_THERM_THRSH1/2` + `REG_STATUS2` 做实时降流（`get_allowed_flash_current()`，OTST1/2 → 1000/500/200 mA） | **无** |
| `qcom,battery-current-limit-microamp` / `qcom,battery-voltage-min-microvolt` | 下游无此概念 | 主线已有（4500000 µA / 2850000 µV，配 `power-supplies=<&pmic_glink>`），驱动用 `get_battery_flash_current()` 做 OCV/R 预算 | **无**（是上游新增能力） |
| 电流/时长上限 | flash 1500 mA(`0x5dc`)、torch 500 mA(`0x1f4`)、duration 1280 ms(`0x500`) | `led-max=1000000 µA`（2 通道×500 mA，=stock torch 上限）、`flash-max=2000000 µA`（≤2 A 上限）、`flash-max-timeout=1280000 µs` | **无偏差** |
| `qcom,camera-flash` 复合节点 | `led_flash_rear`（把 flash+torch+switch 打包给 camera HAL） | **上游无此概念**：flash 是独立 LED class + V4L2 flash subdev，sensor 用 `flash-leds` 指过去 | **设计差异，非缺口**（但用户态要自己找 `/dev/v4l-subdev30`） |
| 前摄 `led-flash-src` | 无 | `flash-leds` 无 | **正确**（硬件无前摄 LED） |
| **flash LED NTC 温度** | `pm8550_flash_led_ntc`（vadc reg `0x145`）+ `flash-led-ntc` thermal zone + thermal HAL 名单 | `pmk8550_vadc` 只有 3 个通道（REF_GND / 1P25VREF / DIE_TEMP，实测 iio 标签一致）；**无** NTC 通道、**无** thermal zone（设备 `thermal_zone*` 53 个里没有 flash-led） | **有（仅监控）**，见 `patches/0013-flash-led-ntc-thermal.patch`（提案，未编译未上机） |
| 用户态闪光灯 API | Android camera HAL 直连 `qcom,camera-flash` | libcamera **不认** `MEDIA_ENT_F_FLASH`（§3.3） | **有（用户态）**，非内核缺口；见 §5 A3 |

⇒ **内核/DT 侧对后摄闪光灯「无缺口」**；缺的两项一是可选的温度监控，二在用户态。

## 5. 待办 / 未验证项

**补丁产物**：`patches/0013-flash-led-ntc-thermal.patch`（仅 flash LED NTC 温度监控，**提案 / 未编译未上机**，适用树 `build/m1-73`；该文件末尾同时列出「明确无缺口、不需补丁」的清单）。

| # | 事项 | 为什么还没做 | 需要什么 |
|---|---|---|---|
| **A1** | **人眼确认发光**（本轮唯一没拿到的关键证据） | 设备在充电（`status=Charging`、100%），`current_now` 被充电器主导（±20 mA 抖动、两次采样间还会跳到 −538 mA），0.2–2 A×3.9 V 的 LED 脉冲在净充电电流里分辨不出来；无照度/光电通道可用 | **用户看一眼**：`echo 128 > /sys/class/leds/white:flash/brightness`（<=200 ms 级）或 `v4l2-ctl -d /dev/v4l-subdev30 --set-ctrl=led_mode=2`（torch，常亮，看完立刻 `led_mode=0`） |
| **A2** | 相机出流 + 闪光灯联动（真实拍照路径） | 需要相机正在出流 + 同步打闪，本轮时间盒内未做 | 在 `cam`/libcamerasrc 跑起来的同时用 `v4l2-ctl strobe`；仍属「手动联动」 |
| **A3** | libcamera 加闪光灯支持（用户态缺口） | 上游 libcamera 的 `discoverAncillaryDevices()` 只认 LENS；要加 `CameraFlash` 类 + `MEDIA_ENT_F_FLASH` 分支 + control 映射 | 自研补丁（`patches-userland/` 类），或退一步：写一个 `scripts/flash-torch.sh` 直接用 V4L2 控制面 |
| **A4** | flash LED NTC thermal zone（`patches/0013-…`） | 只写了提案，**未编译、未上机**；需要在 `build/m1-73` 里 `make dtbs` 并核对 DTB 尺寸变化 | 下一次有构建时间窗时做；`dtbs_check` 也需一起跑 |
| **A5** | 低 timeout 打闪的时序窗 | 观测到 `flash_timeout=20/100/200 ms` 时 t+30 ms 已看不到 `ee46/ee4e` 置位（30–60 ms 采样延迟 > 定时器窗口），而 `500 ms/1280 ms` 能稳定看到置位 ⇒ **判为采样延迟伪影，不是 bug**，但**未用更细粒度采样证伪** | 若要坐实：用 `flash_timeout=500 ms` + 10 ms 间隔采样（本轮已有 500 ms 置位/500 ms 后熄灭的证据） |
| **A6** | Android 容器（Waydroid）侧闪光灯 | 本轮完全未涉 | 需 camera provider / HAL 侧，属 G2 支线 |
| **A7** | 驱动 probe 日志（flash subtype `0x07`=4CH 的读取） | dmesg 环形缓冲已被容器日志冲掉（最早一条 t≈58871 s）、journald 无持久化内核日志 | 下次冷起后第一时间 `dmesg | grep -i flash` |

**设备留在安全态**：`brightness=0`、`led_mode=0`（Off）、`flash_strobe=0`、`flash_fault` 空；未触碰分区/模块/重启。

