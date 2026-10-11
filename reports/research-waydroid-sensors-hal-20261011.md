# 调研：Waydroid 传感器 HAL 的社区/上游经验（2026-10-11）

> 触发：C4 自编 HIDL 传感器 HAL 上机后框架 `SensorService` 卡死、卡 bootanim（见 `archive/topics/C4-SENSORS-2026-10-11.md`）。
> 本报告只汇总外部经验与可选路线，不改设备。

## 1. 上游官方方案 = `waydroid/waydroid-sensors`（★关键）

| 项 | 内容 |
|---|---|
| 仓库 | `github.com/waydroid/waydroid-sensors`（GPL-3.0；原属 Hybris/Jolla，现纯 GLib/C++，**去掉了 Qt**） |
| 产物 | `waydroid-sensord`（**宿主侧守护进程**） |
| 架构 | **用 `libgbinder` 直接向容器的 `hwservicemanager` 注册 `ISensors` HIDL 服务**，数据来自**宿主 `sensorfw`**（D-Bus 会话 + Unix socket 流）；**不是**往 `/vendor` 放一个自编 service 二进制 |
| 依赖 | `libgbinder >= 1.1.20`、`libglibutil`、`glib2`、`sensorfw`（CMake 构建） |
| 与我们的差异 | 我们是「自编 HIDL service 二进制 + overlay 进 `/vendor` + init 拉起」；上游是「宿主 daemon 用 gbinder 注入」——**后者不碰容器 `/vendor`、不依赖容器 init**，天然避开我们遇到的 boot 卡死 |

**Alpine 官方仓库有现成包（本机就是 Alpine！）**：
- `waydroid-sensors 0.2.0-r2`（community；aarch64 39.8 KiB；provides `cmd:waydroid-sensord`；sub-package `waydroid-sensors-systemd`）
- `sensorfw`（community；依赖 **`iio-sensor-proxy`** + Qt5Core/DBus/Network + elogind + udev）
- 本机 `iio-sensor-proxy` **已在用**（G1-34 重力/自动旋转已通）⇒ `sensorfw` 的 iio 后端有数据源。

## 2. 上游 HAL 的契约细节（对照我们的实现，解释为何我们卡）

`waydroid-sensors` 的 `Sensors.cpp`：

1. **所有传感器都带 `SENSOR_FLAG_DATA_INJECTION`**（+ 各自 `CONTINUOUS_MODE`/`ON_CHANGE_MODE`/`WAKE_UP`）。
   → 这是「注入型 HAL」的标志；Waydroid 的 framework 补丁按此识别。**我们的 HAL 若没加这个 flag，框架处理路径不同**（很可能就是卡死诱因之一）。
2. **`poll`/取事件是「非阻塞 + 小睡」**：没有待发事件时 `usleep(1000)` 后返回 `-EINVAL`，靠 `GMainLoop` 在数据到达时 `quit` 唤醒。
   → **我们的 HAL 用 `std::condition_variable::wait` 无限阻塞直到有事件**；若无数据（或 UDP 没真正送达），调用线程永久占用，配合 RPC 线程数不足就会让框架调用超时/卡住。
3. `getSensorsList` 用**小 handle 索引（0..10）**、`minDelay`/`maxDelay`（µs）齐全、`fifo*EventCount=0`。

## 3. 相关踩坑（社区）

- **StackOverflow「Android HAL makes system stuck in poll() function」**：HAL 的 `poll()` **无节流地狂返事件** → 框架线程被饿死 → **卡在 bootanimation**。接受答案：在 poll 里加延迟节流。教训：HAL 的 poll 必须**给别的线程留调度时间**，既不能狂返也不能无限阻塞。
- **Waydroid issue #293**：`init: Could not find 'android.hardware.sensors@1.0::ISensors/default' for ctl.interface_start`。
- **XDA「Service sensorservice didn't start」**：通用 Android 启动期 SensorService 起不来 → 卡 boot。
- **Android 13 传感器 HAL**：A13 引入 **AIDL Sensors HAL（基于 2.1）**；HIDL 自 Android 10 起 deprecated。本机镜像 `ro.vndk.lite=true`。原版 stub（HIDL 1.0、返回空列表）能让 `sensorservice` 注册成功 ⇒ 1.0 路径没被移除；**我们卡死不是“1.0 不被支持”，而是 HAL 行为/契约问题**。
- `waydroid.stub_sensors_hal`：Waydroid framework 0027 补丁见到它会默认 `fix-to-user-rotation`（锁死自动旋转）——上游刻意改用别的 prop；我们用的 `waydroid.sensors.enabled` 方向正确。

## 4. 两条可行路线

### 路线 A（推荐）：装上游 `waydroid-sensors`
```sh
# 设备（Alpine，mainline root）
apk add waydroid-sensors sensorfw            # 会拉 iio-sensor-proxy 等
# 起 sensorfw + waydroid-sensord（具体 OpenRC 服务名/手工 nohup 待查包内容）
waydroid-sensord &                            # 注册 ISensors 到容器
```
- 优点：上游维护、不碰 `/vendor`、不靠 overlay、与 framework 补丁同源。
- 待验证：`sensorfw` 在 mainline+iio-sensor-proxy 上的后端配置（sensorfw 常见后端有 hybris/Android，需确认有纯 iio/`iio-sensor-proxy` 插件并配好）；包是否含 OpenRC 服务（Alpine 只列了 `cmd:` 与一个 systemd 子包）。

### 路线 B：修我们自编的 HAL（若不想引 sensorfw/Qt5）
对齐上游契约，最小改动：
1. `getSensorsList` 的 `flags` **加 `SENSOR_FLAG_DATA_INJECTION`**（保留 mode flag）。
2. `poll` **改为非阻塞/带节流**：无事件时 `usleep(1000)`（或短超时）返回空/`-EINVAL`，不要无限 `gCv.wait`。
3. `minDelay`/`maxDelay` 填齐；handle 用 0..N。
4. 保留 `configureRpcThreadpool(≥2)`（我们已改 4）。
5. 打开 `mount_overlays=True` 才生效（overlay 基础设施已修：见 `PITFALLS #185`）。

## 5. 结论

- 我们**不该继续用「自编 HIDL service + 覆盖 /vendor」这条偏路**；社区有**官方 `waydroid-sensors`（Alpine 已打包）**，且本机 `iio-sensor-proxy` 已在跑 ⇒ **路线 A 是首选**，路线 B 作为备选（改动小、可控）。
- 无论哪条，**`SENSOR_FLAG_DATA_INJECTION` + poll 不无限阻塞**是共性要点，很可能就是我们 boot 卡死的直接原因。

## 6. 链接

- upstream: https://github.com/waydroid/waydroid-sensors ；DeepWiki 架构：https://deepwiki.com/waydroid/waydroid-sensors
- Alpine 包：https://pkgs.alpinelinux.org/package/edge/community/aarch64/waydroid-sensors ；https://pkgs.alpinelinux.org/package/v3.20/community/armhf/sensorfw
- AOSP：Sensors HAL 1.0 / AIDL / Multi-HAL；A13 release notes（AIDL sensors HAL）
- SO poll 卡死：https://stackoverflow.com/questions/46482127/android-hal-makes-system-stuck-in-poll-function

---

## 7. 上机实测结论（2026-10-11，U2 vk64）

**做了**：设备是 Alpine 3.24（USTC 源）；`apk add waydroid-sensors sensorfw` **成功**（`waydroid-sensors 0.2.0-r2` + `sensorfw 0.15.1-r2` + `sensorfw-openrc`）；`/etc/init.d/sensorfw` 可起（`com.nokia.SensorService` 上系统总线）。

**卡点（两层）**：

1. **数据源不匹配（上游路线根因）**：
   - `ldd /usr/bin/waydroid-sensord` → 只链 `libgbinder/libgio/glib/glibutil`；它的数据源是 **sensorfw**（D-Bus `com.nokia.SensorService` + unix socket，`g_socket_client_connect`）。
   - `sensorfw` 的 `libiiosensorsadaptor-qt6.so` 是基于 **`SysfsAdaptor`**（`ldd` 只链 `libudev`+Qt6，**无 libiio、无 D-Bus**）⇒ 读 **内核 IIO sysfs `/sys/bus/iio/devices/iio:device*`**；`/etc/sensorfw/primaryuse.conf` 也把全部 adaptor 指向 `iiosensorsadaptor`。
   - **本机 `/sys/bus/iio/devices/` 恒为空**（传感器在 ADSP/SSC 上、经 **libssc → iio-sensor-proxy 的 D-Bus** 暴露，无内核 IIO 节点；见技能 `y700-adsp-ssc-sensors-bringup`）⇒ **sensorfw 找不到任何传感器** ⇒ `waydroid-sensord` 只会注册一个「空列表」HAL（与原 stub 等价）。
   - **⇒ 上游 `waydroid-sensors`（sensorfw 版）在本机拿不到数据。** 要用上游，必须给它接一个 libssc/iio-sensor-proxy 的数据源（等于给 sensorfw 写新 adaptor）。

2. **更底层：SSC 传感器源当前不通（G1-34 回退/前置）**：
   - `/dev/fastrpc-adsp`（非 secure）**不存在**，只有 `/dev/fastrpc-adsp-secure`、`/dev/fastrpc-cdsp`。
   - 根因（源码级确认）：`arch/arm64/boot/dts/qcom/sm8750.dtsi` 的 **ADSP fastrpc 节点（label="adsp"，L2268）缺 `qcom,non-secure-domain`**，而 **CDSP 节点（L6407）有** ⇒ 内核 `secure_dsp=!of_property_read_bool(node,"qcom,non-secure-domain")` ⇒ ADSP 只出 secure 节点。这与技能 `y700-adsp-ssc-sensors-bringup` 的 Pitfall **完全一致**。
   - `hexagonrpcd-adsp-sensorspd` 的 initd 硬编码 `command_args="-f /dev/fastrpc-adsp -d adsp -s"` ⇒ 依赖该节点。
   - 实测：即使 `hexagonrpcd-adsp-sensorspd start`（`qrtr svc 400` 出现）+ `iio-sensor-proxy restart` + 等 40 s，**`net.hadess.SensorProxy` 仍 `HasAccelerometer=false` / `HasAmbientLight=false`**。
   - ⇒ **任何 Waydroid 传感器路线（上游或自编）都先要修好这条链**（属 G1-34）。

**现状**：上游包已装（保留，待用）；`sensorfw` 未纳入开机；`mount_overlays=False`；容器回到原可用态。

## 8. 修正后的建议

1. **先修 ADSP fastrpc 非 secure 节点**（DT 给 `sm8750.dtsi` 的 `label="adsp"` fastrpc 节点加 `qcom,non-secure-domain`；重编 DTB/内核）⇒ 让 `/dev/fastrpc-adsp` 出现、SSC 源真的出数（`HasAccelerometer=true`）。这是 C4 与 G1-34 的共同前置。
2. **再选 HAL 实现**：
   - **A（最贴近上游）**：保留上游 `waydroid-sensord` 的 gbinder 注册，**把数据源从 sensorfw 换成 libssc / `net.hadess.SensorProxy` D-Bus**（需改 `waydroid-sensors` 源码，中等工作量）。
   - **B（小改自编）**：修我们的 UDP HAL 以对齐上游契约——所有 sensor 加 `SENSOR_FLAG_DATA_INJECTION` + `poll` 非阻塞/节流；数据源同样接 libssc/iio-sensor-proxy。
   - 两条都以「libssc/iio-sensor-proxy → HAL」这段桥为核心工作量。

---

## 9. 本地检索：有「传感器完备版本」，且修复是 1 行、上游一致（2026-10-11）

**问**：本地是否有传感器完备（ADSP fastrpc 非 secure 节点在）的版本？

**答：有。**

| 证据 | 内容 |
|---|---|
| **传感器完备的 DTB** | `out/sm8750-lenovo-elden-adsp-nonsec.dtb`（2026-10-09 08:56，sha256 `5d658a2c…`）——**ADSP fastrpc 节点带 `qcom,non-secure-domain`**（`cdsp` 也有） |
| **对应的 boot 版本** | **vk72**：`out/boot-elden-vk72.manifest` 明写 `dtb_packed_from=out/sm8750-lenovo-elden-adsp-nonsec.dtb`（image sha `e112ea01…`，kernel_uts=`…-vk64-gd02658e63cf6`）。即 **vk64 内核 + adsp-nonsec DTB** = G1-34 当时的传感器工作版本 |
| 与现役 DTB 的差 | `out/sm8750-lenovo-elden-adsp-nonsec.dtb` vs 现构建 `sm8750-lenovo-elden.dtb` **只差 1 行**：在 ADSP fastrpc 节点加 `qcom,non-secure-domain;`（`diff` 计 1 行） |
| 现存资产 | DTB 在；`out/boot-elden-vk72.img` **已被 out 清理删除**（只剩 manifest）；回退资产 `backup/HA2EXB0E-16+512/boot_b-before-vk72-20261009.img` 在 |
| 全 ref 源码 | **22 个 ref 的 `sm8750.dtsi` 都缺该行** ⇒ 这行是当年**未提交的本地 DT 改动**，在 2026-10-10「clean/base」重置时丢失（DTB 产物留下） |

**上游一致性（关键）**：Linux 上游**其它 Qualcomm SoC 的 ADSP fastrpc 节点都带 `qcom,non-secure-domain`**（eliza / sc8280xp / agatti / sdm630 / sdm660 等的 DTSI patch 均如此）。⇒ 给 `sm8750.dtsi` 的 `label="adsp"` 节点补这一行是**上游风格、几乎无下游味**的修法。

**结论/建议**：把 `qcom,non-secure-domain;` 加进 `arch/arm64/boot/dts/qcom/sm8750.dtsi` 的 ADSP fastrpc 节点（源级、1 行），重编 DTB→boot_b，即可让 `/dev/fastrpc-adsp` 出现、SSC 源出数（`HasAccelerometer=true`），恢复 G1-34 并解锁 C4 前置。**优先于任何 HAL 侧改动**。

---

## 10. 实测：装上游包会**破坏容器启动**（2026-10-11，已复现+已恢复）

### 10.1 机制（Waydroid 工具源码级）

`/usr/lib/waydroid/tools/helpers/images.py:155`（生成 `/var/lib/waydroid/waydroid.prop` 时）：
```python
if which("waydroid-sensord") is None:
    props.append("waydroid.stub_sensors_hal=1")
```
镜像里的 stub `android.hardware.sensors@1.0-service.waydroid`（16136 B，Android 33）**只在 `waydroid.stub_sensors_hal=1` 时才注册**（`strings` 见 `waydroid.stub_sensors_hal`；否则 `main()` 直接 `return 0` 秒退）。

**⇒ 装了 `waydroid-sensors`（提供 `waydroid-sensord`）后**：Waydroid 不再设 stub prop，期望 `waydroid-sensord` 自己提供 HAL。若 `waydroid-sensord` 没注册 → 镜像 stub 秒退 → 框架 `SensorService` 永远等不到 `ISensors/default` → **卡 LineageOS bootanim**（`boot_completed` 恒空）。

### 10.2 实测：`waydroid-sensord` 在本机**未注册 HAL**

- 已起 `sensorfw`（`com.nokia.SensorService` 在总线）+ 容器在跑，跑 `/usr/bin/waydroid-sensord`：
  - 日志只有 `Got new plugin for accelerometersensor/gyroscopesensor/alssensor/magnetometersensor/orientationsensor/pressuresensor/proximitysensor`（sensorfw 插件），**无任何注册/hwservicemanager 行**；
  - 容器 `lshal` 始终**无 sensors HAL**；`service list` 无 `sensorservice`。
- `/dev/binder`、`/dev/hwbinder`、`/dev/vndbinder` 都在（binderfs 符号链接），不是缺设备。
- 结论：**当前未定位 `waydroid-sensord` 不注册的原因**（可能需要特定 env/服务方式，或与数据源/容器上下文有关）。

### 10.3 恢复 + 结论

- 恢复：`apk del waydroid-sensors`（+ `rc-service sensorfw stop`）→ Waydroid 重设 `waydroid.stub_sensors_hal=1` → 容器正常：`boot_completed=1`、`sensorservice: [android.gui.SensorServer]`（stub，无传感器）。
- **结论（方案 A 现状）**：上游 `waydroid-sensors` 在**本机不可直接用**——① 数据源不匹配（sensorfw 读内核 IIO，本机是 libssc），② 装了它就不再有 stub prop，而 `waydroid-sensord` 又不注册 HAL ⇒ 容器根本起不来。要再试上游，必须**先让 waydroid-sensord 真正注册**（并解决数据源）。
- 反面知识（有用）：镜像 stub 的开关 = **`waydroid.stub_sensors_hal=1`**；`waydroid.prop` 每次 session start 由工具重生成，手改无效，必须走 `images.py` 的条件或 `waydroid prop set`（需 session 运行）。
