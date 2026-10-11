# 调查：Waydroid 传感器『下一步到底做什么』（2026-10-11，只读）

> 前提（已核实）：本机 U2 现为 **vk64 内核 + vk94 DTB**（ADSP fastrpc 补 `qcom,non-secure-domain` 已刷）。
> 设备只读核实（ssh root@192.168.7.1，仅读）：
> - `/dev/fastrpc-adsp` **存在**；`hexagonrpcd -f /dev/fastrpc-adsp -d adsp -s` 在跑；
> - `net.hadess.SensorProxy` **HasAccelerometer = true** ⇒ **SSC 传感器用户态链路已恢复出数**。
> - `apk info -e`：`waydroid-sensors` **未装**（已回退）、`sensorfw` 已装。
>
> 外部证据：上游源码浅克隆 `github.com/waydroid/waydroid-sensors`（main 分支，2026-10-11 克隆到 `/tmp/waydroid-sensors`，行号以其为准）；本机自编 HAL 源 `/mnt/Samsung/waydroid-build/hardware/waydroid/sensors/`。

---

## 0. 结论（先数字）

1. **上游路线（waydroid-sensors + sensorfw）在本机拿不到数据，根因确定**：sensorfw 唯一数据源 = 内核 IIO sysfs 的 `iiosensorsadaptor`（Alpine sensorfw 0.15.1-r2 包内 **没有任何 libssc/SSC adaptor**，adaptor 全清单已核实）；本机内核 IIO 恒空（传感器走 SSC/libssc→D-Bus）⇒ sensorfw 永远空 ⇒ waydroid-sensord 只注册空列表 HAL。
2. **新发现（定位了 §10 的悬案）**：`waydroid-sensord` 的 **argv[1] = binder 设备路径**，缺省 `/dev/anbox-hwbinder`（`service.cpp:28,425-441`）；本机 `/dev/anbox-hwbinder` 虽存在但属 **anbox binderfs 独立域（minor 10）**，容器 hwservicemanager 用的是 **`/dev/hwbinder`（minor 6）** ⇒ 缺省运行会阻塞在 `gbinder_servicemanager_wait`、永不注册——与 §10 观测（只有 "Got new plugin"、无注册行）**逐条吻合**。修法 = **带参运行 `waydroid-sensord /dev/hwbinder`**。
3. **自编 HAL 卡死**：与「可启动」的 stub 对照，唯一 delta = 非空列表 + `poll` 无限停泊 binder 线程 + 缺 `SENSOR_FLAG_DATA_INJECTION`。**无单变量决定性证明**（嫌疑 2 条），但路线 B 对齐上游契约的具体改动点已全部定位（§2）。
4. **推荐路线 = C（gbinder 注入，不引 sensorfw、不碰 /vendor）**：上游 `service.cpp` 的 gbinder 注册段 + 我们的 UDP/libssc 数据源，正是上游同款设计；且**完全绕开 overlay/SELinux**（PITFALLS #185 那层）。可行性高，最小 PoC 4 步（§3）。

---

## 1. Q-a：上游数据源精确取证

**① waydroid-sensord → sensorfw：D-Bus（system bus `com.nokia.SensorService`）+ unix socket。**
- 证据（上游 clone）：`SensorFW.cpp:25-36`（`the_dbus_bus_address()` 取 **system bus**）、`:40-105`（逐个 `SensorfwAccelerometerSensor(dbus_address)` 等，10 类传感器全部走 sensorfw D-Bus）；`sensorfw-core/plugins/sensorfw_accelerometer_sensor.cpp:74-78`（数据到达 = `m_socket->read<AccelerationData>(values)`，即 sensorfw 的 **unix socket 流**）。

**② sensorfw → iiosensorsadaptor：直接读内核 `/sys/bus/iio`。**
- 证据（设备，ssh 只读）：`apk info -L sensorfw` 全部 adaptor = `libiiosensorsadaptor-qt6.so` 等 24 个 `.so`，**无任何 ssc/libssc/hybris adaptor**；`reports/research-waydroid-sensors-hal-20261011.md` §7.1（`ldd libiiosensorsadaptor-qt6.so` 只链 `libudev`+Qt6，SysfsAdaptor 基类；`primaryuse.conf` 全部指向 iiosensorsadaptor）。
- 上游 sensorfw 插件体系亦无 SSC 后端（clone 内 `sensorfw-core/plugins/` 全 14 个插件均 `sensorfw_*_sensor.cpp`，只包 D-Bus/socket 封装，无 libssc 链接）。
- **⇒ 路线 A 在本机拿不到数据的因果链（确定）**：内核 IIO 空 → iiosensorsadaptor 无设备 → sensorfw 无传感器 → waydroid-sensord 只能注册空列表 HAL。要救路线 A 必须给 sensorfw 写 SSC adaptor（等于路线 C 的工作量还多一层 sensorfw 集成）。

**③ 补充（决定性新证据）**：`service.cpp:425-441` —— `if (argc < 2) device = DEFAULT_DEVICE("/dev/anbox-hwbinder"); else device = argv[1];`，然后 `gbinder_servicemanager_new2(device, "hidl", "hidl")` + `gbinder_servicemanager_wait(sm, -1)`（`:441-443`）。本机核实（ssh）：`/dev/binderfs/` 中 **anbox-hwbinder minor=10**、**hwbinder minor=6**（不同 binder 域）；容器 hwservicemanager 在 `hwbinder`。⇒ 缺省运行 = 注册进空的 anbox 域（wait 阻塞、无输出），**这正是 §10 "waydroid-sensord 未注册" 的根因**。

---

## 2. Q-b：自编 HAL 卡死逐条对照（`/mnt/Samsung/waydroid-build/hardware/waydroid/sensors/`）

| # | 上游契约（clone 证据） | 我们的实现（行号） | 判定 |
|---|---|---|---|
| 1 | **每个传感器都带 `SENSOR_FLAG_DATA_INJECTION`**（`Sensors.cpp:315,341,367,393,419,445,445,471,497,523,550,576`——12 个 sensor 全带，如 `flags = SENSOR_FLAG_DATA_INJECTION \| …`） | `Sensors.cpp:56-76` kSensors flags = 0/2/3，**无 DATA_INJECTION(1<<4=0x10)** | **嫌疑（非决定因）**：framework 按 flag 走不同路径；可能仅影响注入/旋转行为，不至于卡死 |
| 2 | poll 无事件时**不占住 binder 线程**：`Sensors.cpp:626-667` `poll()` 在无 pending 时 `g_main_loop_run`（`Sensor.cpp:75-76` 无事件侧 `usleep(1000); return -EINVAL`），回复经 `g_idle_add` + `gbinder_remote_request_block` 从 GMainLoop 异步发出（`service.cpp:245-256`） | `Sensors.cpp:236-253` `gCv.wait(lk, []{ return !gQueue.empty(); })` **无限停泊一个 HIDL binder 线程** | **嫌疑（强）**：stub 的 poll **立即返回空**（`Sensors.cpp.orig:53-60`）且 boot 正常；我们 poll 永不返回时框架 event 线程被永久占住，线程池不足时其余调用排队——与观测一致（1 线程 lshal TIMED_OUT，4 线程仍卡 boot） |
| 3 | minDelay/maxDelay 齐全（`:310-314` 等，µs） | `Sensors.cpp:203-208` minDelay 齐；**HIDL 1.0 SensorInfo 无 maxDelay 字段**，无需补 | 确定差异但 1.0 里无从补，非因 |
| 4 | handle = 位掩码小索引 0..10（`ID_CHECK` `1U<<handle`） | `Sensors.cpp:56-76` handle 1,2,4,5,8（<32，位掩码合法） | 非因 |
| 5 | `configureRpcThreadpool` + join | `service.cpp:36-49` 已 4 线程 + join | 已修，非因 |
| 6 | flush 返回 OK 并排队 META_DATA_FLUSH_COMPLETE（`Sensors.cpp:671-698`） | `Sensors.cpp:271-274` 返回 INVALID_OPERATION | **嫌疑（弱）**：API 允许 INVALID_OPERATION，但 stub 返回 OK |
| 7 | 非空列表本身 | stub 空列表 boot ✅、我们 5 传感器 boot ❌ | **决定性 delta 的组成**：卡死一定在「非空列表 + flag/poll 语义」组合里 |

**路线 B 能否修好：判断 = 很可能能，改动 3 处（均为单点）**：
1. `Sensors.cpp:56-76`：kSensors 每项 flags `| 0x10`（`SENSOR_FLAG_DATA_INJECTION`）；prox 变 3\|0x10=19，light 2\|0x10=18，其余 16。
2. `Sensors.cpp:241`：`gCv.wait(lk, …)` → `gCv.wait_for(lk, std::chrono::milliseconds(100));`，超时且队列空则**立即回调 `Result::OK` + 空 vec 返回**（对齐 stub 行为，binder 线程永不长停泊；空返回被框架容忍——stub 全程如此）。
3. `Sensors.cpp:271-274` flush：返回 `Result::OK` 并 push 一条 `META_DATA_FLUSH_COMPLETE`（对齐上游 671-698），或在 A/B 时先保留、单变量验证 1+2 已够。
编译验证：`bash scripts/build-sensord.sh`（产物 → `out/sensord/`），再 `deploy-sensors-hal.sh`。

---

## 3. Q-c：路线 C（gbinder 注入，不引 sensorfw）——判断：**可行，且是本机最稳**

理由（4 条）：
- 不碰容器 `/vendor`、不依赖 overlay/SELinux（PITFALLS #185/#186 那层基础设施完全绕开；C4 里 overlay 已验证可用但引入了 SELinux/模块两处新面）；
- 与上游同款注册设计（`service.cpp` 的 gbinder HIDL 1.0 注册是上游维护、社区验证的），只是**把 sensorfw 数据源换成我们已验证的 UDP 通道**（`scripts/eldroid-sensord.c` selftest 7/7、环回 96 行/3s）；
- 数据侧已就绪：宿主 `HasAccelerometer=true`（vk94 链路实测），`apk search libssc` = **libssc 0.4.3 / libssc-dev 在 Alpine 源**（真值直连 SSC 的后备路径）；
- 装包副作用可控：装 `waydroid-sensors` → stub prop 关闭（`images.py:155`），此时由路线 C daemon 提供注册即不卡 boot（先起 daemon 再重启容器即可）。

**最小 PoC（4 步，一次性改动 = 新建 1 个宿主 daemon）**：
1. 拷上游 `service.cpp` 为基座（保留 `app_reply` 的 GET_SENSORS_LIST/ACTIVATE/POLL 分发、`gbinder_servicemanager_new2(argv[1],"hidl","hidl")`），**数据源替换**：删 `SensorFW.*` 依赖，加一个 UDP 收包线程（复用 `scripts/eldroid-sensord.c` 的文本协议 `acc x y z`…），按上游 `sensor_event_cb` 模式填 `d->sensors[]/pendingSensors` 并 `g_main_loop_quit(d->loop)` 唤醒 poll（上游 `Sensors.cpp:626-667` 的 waiting_for_data 机制原样保留）。
2. 编译：依赖仅 `libgbinder-dev libglibutil-dev glib2`（Droidian 同款构建；无 Qt、无 sensorfw）。
3. 上机：`apk add waydroid-sensors`（stub prop 关）→ `elden-sensord /dev/hwbinder &` → **先确认 `lshal` 有 `android.hardware.sensors@1.0::ISensors/default`** → 再重启容器。
4. 验证：容器 `dumpsys sensorservice` 列出传感器 → 宿主 `eldroid-sensord --send <容器IP> --fake --rate 100` → 事件计数增长/地图旋转（Q14 三未知 ①UDP 可达性 ②SELinux ③Termux 映射在路线 C 下只剩 ①，因 /vendor 不动）。

**路线 A/B/C 取舍一句话**：A 死于数据源（要写 sensorfw SSC adaptor，工作量 ≥ C）；B 改 3 处可试、仍是「往 /vendor overlay 自编 service」偏路；**C 是唯一既不碰 /vendor 又有现成数据通道的方案**。

---

## 4. 下一步清单（单条命令 / 单次改动）

1. **路线 C PoC 第 1 步（唯一真正的"写"）**：在 `/mnt/Samsung/waydroid-build/` 新建 `hardware/waydroid/sensorsd/`，上游 `service.cpp` + UDP 线程（删 SensorFW），编译出 `elden-sensord`。
2. 上机验证注册（只读+临时进程）：`apk add waydroid-sensors && elden-sensord /dev/hwbinder &` → `waydroid shell lshal | grep sensors`。
3. 若 C PoC 前想先低成本试探：直接跑已装的上游二进制带参——`apk add waydroid-sensors && waydroid-sensord /dev/hwbinder &` → `lshal` 应出现**空列表 HAL**（能单独证明 §1③ 的 argv 根因，容器可启动、只是无传感器）。
4. 备选（路线 B）：`Sensors.cpp` flags 加 0x10（:56-76）+ poll 改 `wait_for` 100ms 空返回（:241）→ `scripts/build-sensord.sh` → `deploy-sensors-hal.sh`，开 `mount_overlays=True` A/B 验证。
5. 无论 B/C：真值数据源接 libssc（`apk add libssc-dev`）替换/补充 `eldroid-sensord --fake`。

**本报告未改动任何 SSOT 文档、未写设备、未刷机。**

---

## 5. 编排者独立复核（2026-10-11，U2 vk64 GOOD 起，实机写操作）

> 复核方式：GOOD 启动（card0 在、phosh 在）下实测，非只读。结论：**§1③ 与「路线 A 死、路线 C 必需」均被实机证实**。

**a) 容器与 binder 节点现状（session start 后）**
```
$ ls /dev/anbox-hwbinder /dev/hwbinder
/dev/anbox-hwbinder        # 容器起后出现
/dev/hwbinder
$ waydroid status
Session: RUNNING  Container: RUNNING  IP 192.168.240.112
```

**b) 装上游包并带参运行（报告 §4 第 3 步）→ 实机结果：daemon 直接 abort，早于 servicemanager wait**
```
$ apk add --no-cache waydroid-sensors    # 0.2.0-r2
$ waydroid-sensord /dev/hwbinder
[waydroid-sensors-daemon] failed to call load_plugin:
  GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown:
  The name com.nokia.SensorService was not provided by any .service files
[waydroid-sensors-daemon] Failed to create SensorfwAccelerometerSensor: Could not create sensorfw backend
...（逐传感器同错）→ GLib-CRITICAL g_variant_unref → Aborted
```
⇒ **比子代理预测更强**：不是「用错 binder 设备导致 hang」，而是 **sensorfw D-Bus 服务不在（本机 sensorfw 包已装但 `com.nokia.SensorService` 未起）→ daemon 在建 backend 阶段就崩**。
即使把 sensorfw 起起来，其 `iiosensorsadaptor` 也因内核 IIO 为空而给不出传感器（§1②）⇒ **路线 A 确定性不可用**。

**c) 「装 waydroid-sensors ⇒ 容器卡 boot」实机复现**
```
$ apk add waydroid-sensors; waydroid session start
$ waydroid shell -- getprop sys.boot_completed      # 40 s+ 始终拿不到（shell 无输出）
```
（原因：`waydroid-sensors` 一装，`images.py:155` 不再设 `waydroid.stub_sensors_hal`，而能注册的 HAL 缺席 ⇒ sensorservice 起不来。）

**d) 回退后恢复**
```
$ apk del waydroid-sensors; （重启 container/session）
$ waydroid shell -- getprop sys.boot_completed      → 1
$ waydroid shell -- dumpsys sensorservice           → "No Sensors on the device"（stub）
$ waydroid shell -- ip route                        → default via 192.168.240.1 dev eth0
```
⇒ 现役可用态已恢复（stub HAL + workaround 默认路由），设备无残留。

**e) 复核裁决**：否掉「低成本试探路线 A」，**路线 C（gbinder 注入宿主数据源，不碰 /vendor）为本机唯一合理路径**；报告 §3 的最小 PoC 步骤成立（唯一步骤 3 的假设需更正为「sensorfw 未起会 abort，故必须先自建数据源」）。
