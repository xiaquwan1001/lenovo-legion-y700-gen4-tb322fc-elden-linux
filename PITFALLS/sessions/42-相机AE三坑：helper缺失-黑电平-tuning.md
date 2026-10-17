# 四十二、相机 AE 三坑：软 ISP 无 sensor helper、黑电平、设备无外网

> 2026-10-17 晚实测（vk127 / 7.3 线，Q28 坏发 boot 下全走 SSH）。收录 **#296–#298**。
> 主报告 `reports/camera-vk127-20261017.md` §9–§12；补丁与 tuning 归档 `patches/camera-ae-fix-20261017/`。

## #296 libcamera 软 ISP **没有 sensor helper** ⇒ 把 V4L2 增益码当真实增益（AE 直接废掉）

- **现象**：`cam -c1`（后摄）AE 收敛到 "ExposureTime=3228 µs、AnalogueGain=1.0～32"，输出**全黑**
  （mean 0，max 28）；`cam --list` 只给两句 WARNING：
  `No static properties available for 's5kjns'` + `Failed to create camera sensor helper for 's5kjns'`。
- **根因**（libcamera 0.7.1 `src/ipa/simple/soft_simple.cpp:227`）：helper 为 null 时走
  `agc.againMin/againMax = V4L2 ctrl 的 min/max`（本机是 **32..2048**），
  `agc.again10 = def`，`againMinStep = 1.0` ⇒ AGC 认为「当前增益 32 倍」，
  于是**猛压曝光**；`processStats()` 里 `frameContext.sensor.gain = again`（原始码），
  同理把码当增益反馈给算法。
- **判定方法（30 秒）**：`cam --list 2>&1 | grep "sensor helper"`；命中即 AE 一定不准。
- **两种修法**：
  1. **上游正解**：`src/ipa/libipa/camera_sensor_helper.cpp` 加
     `CameraSensorHelperS5kjns`（`AnalogueGainLinear{1,0,0,32}`、`blackLevel_=4096`）
     与 `CameraSensorHelperGc08a8`（`{1,0,0,1024}`、`4096`），`REGISTER_CAMERA_SENSOR_HELPER("s5kjns"/"gc08a8")`。
  2. **本地临时**（本次采用）：让驱动把 `V4L2_CID_ANALOGUE_GAIN` 暴露成**真实增益单位**
     （范围 `1..64` / `1..16`，写寄存器时 ×32 / ×1024）——软 ISP 无 helper 时就按真实增益算。
     **必须同时把驱动语义写清**，否则后人会按「V4L2 码直写寄存器」理解而再次踩坑。
- **验证**：前摄修复后 `ExposureTime=32836 µs, AnalogueGain=5.0`，画面 mean 114/117/116（正常曝光）。

## #297 软 ISP 的**黑电平**只来自 helper 或 tuning 文件，默认 0 ⇒ pedestal 被当环境光

- **现象**：修好增益单位后 AE 仍偏暗（后摄 ExposureTime 从 3.2 ms 爬到 17.7 ms，画面几乎全黑）。
- **根因**：sensor 的 pedestal 是 **64（10-bit）**，但软 ISP 默认 `black.level = 0`
  （`soft_simple.cpp` 只在 helper 有 `blackLevel()` 时设置），AGC 直方图把 pedestal 当光。
- **修法（不用重编 libcamera）**：软 ISP 的 `BlackLevel` 算法会读 **tuning 文件**
  （`src/ipa/simple/algorithms/blc.cpp:29`：`tuningData["blackLevel"]`，16-bit 值再 `>>8` 变 8-bit）：
  ```yaml
  # /usr/share/libcamera/ipa/simple/<sensor>.yaml
  version: 1
  algorithms:
    - BlackLevel:
        blackLevel: 4096     # 64 @10bit 左移 6 位
    - Awb:
    - Adjust:
    - Agc:
  ```
  文件名 = sensor model（`s5kjns.yaml` / `gc08a8.yaml`），libcamera 会自动优先于 `uncalibrated.yaml`。
- **纪律**：黑电平换算 = `pedestal(10bit) << 6`（到 16-bit）。填错会整体偏灰/偏黑，且**不会有任何日志**。

## #298 设备（Alpine）有 `wlan0` IP 但**没有外网** ⇒ 就地装构建依赖这条路走不通

- **现象**：`ip route` 有 `default via 202.141.181.1 dev wlan0`、`wlan0` 有校内 IP，
  但 `ping 223.5.5.5` 100% 丢包、`wget https://mirrors.ustc.edu.cn/...` 失败、`apk update` 静默无输出。
- **后果**：想「在设备上就地重编 libcamera」拿不到 `apk` 依赖（gcc/meson/ninja 本来就有，缺 dev 头文件）。
- **可行路径**：
  1. **主机做 HTTP 代理**（`http_proxy` 给 `apk`/`wget`），最省事；
  2. 主机 `iptables MASQUERADE` 把 `usb0`(192.168.7.0/24) 伪装到有线出口；
  3. aarch64-**musl** 交叉工具链在主机编（注意设备是 Alpine/musl，不是 glibc）。
- **纪律**：报「设备没网」之前先看 `ip route` + `ping`（本项目 standing rule：先确认代理/上游链路，
  再判断站点不通）。本次是「有 IP 但无转发」——`ping` 比 `ip addr` 有诊断力。
