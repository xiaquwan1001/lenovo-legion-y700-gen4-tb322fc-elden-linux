# C4 前提修正：Waydroid 传感器 HAL 是 stub，uinput 方案作废（2026-10-03 调查）

> 过程证据；结论以 `ANDROID-COMPAT.md` §2①、`TASKS.md` C4 为准。

## 1. 证据链（决定性，本机离线取证）

| 证据 | 位置 | 结论 |
|---|---|---|
| Waydroid 镜像里的 sensors service = 16 KB stub | `/tmp/waydroid-vendor/vendor.img` → `bin/hw/android.hardware.sensors@1.0-service.waydroid`（strings: `waydroid.stub_sensors_hal`） | 不是真 HAL |
| 上游实现源码 | waydroid/android_hardware_waydroid `sensors/Sensors.cpp`；本机树 `waydroid-build/hardware/waydroid/sensors/Sensors.cpp.orig` | `getSensorsList` 返回**空**、`poll` 无事件、`injectSensorData` = INVALID_OPERATION |
| service 入口 | `service.cpp`：`property_get_bool("waydroid.stub_sensors_hal", false)` 才启动 | prop 名即入口开关 |
| **uinput 方案作废** | HAL 不读 evdev（stub 根本不开任何设备） | 原"uinput + UDP sensord, evdev 层"设计**前提不成立** |
| framework 锁旋转补丁 | `vendor/extra/waydroid-patches/base-patches-33/frameworks/base/0027-*.patch`：`waydroid.stub_sensors_hal=true` ⇒ `mDefaultFixedToUserRotation=true` | **stub prop 不能复用**——会锁死自动旋转；真传感器路线必须换 prop 名 |
| 社区先例 | droidian/waydroid-sensors = waydroid/anbox-sensors 同码（sensorfw DBus → gbinder HAL） | Droidian 路线 = Qt5/sensorfw，Alpine 不现实；我们的 UDP 直达更轻 |

## 2. 新路径（已落地，主机侧完成）

1. **HAL 真实现**（本机 waydroid-build 树，已编译成功 32 s）：
   - `hardware/waydroid/sensors/Sensors.cpp`：UDP 后台线程收文本行（`acc x y z` / `gyr` / `mag` / `light` / `prox`）→
     `getSensorsList` 返回 5 个传感器（accel/mag/gyro/light/prox）→ `poll()` 阻塞等队列（HIDL poll 模型）。
   - `service.cpp`：入口 prop 改 **`waydroid.sensors.enabled`**（避开 0027 锁旋转补丁）。
   - `device/waydroid/waydroid/system.prop`：`waydroid.sensors.enabled=true` + `waydroid.sensors.udp_port=52012`。
   - 产物：`out/target/product/waydroid_arm64_only/vendor/bin/hw/android.hardware.sensors@1.0-service.waydroid`（25 KB）。
   - 原文件备份：同目录 `*.orig`。
2. **宿主侧数据源**（A14，已冒烟）：`scripts/eldroid-sensord.c`（fake 轨迹 / stdin 文本 → UDP；
   native + aarch64 static 双产物，selftest 7/7，环回 3 s 96 行）。
   - 真值来源：`env-pass/scripts/sensor-send-termux.sh`（另一单元 a 槽 Android 的 Termux:API 转发）。
3. **部署**（上机后）：`scripts/deploy-sensors-hal.sh` —— Waydroid **overlay** 方式
   （`/var/lib/waydroid/overlay/vendor/`，不改 vendor.img），附 `elden-sensors.rc` setprop。

## 3. C4 上机验证清单（占位，GAPS Q14）

1. `waydroid shell getprop waydroid.sensors.enabled` → true
2. `waydroid shell dumpsys sensorservice` → 列出 5 个 `elden * (UDP)` 传感器
3. 宿主 `sensord --send <容器IP> --fake --rate 100` → 容器内事件计数增长、地图旋转
4. 未知待验：① 容器 UDP 52012 从 waydroid0 网桥可达（防火墙）；② overlay 的 .rc/.so SELinux context；
   ③ Termux 转发器实际传感器名与映射
