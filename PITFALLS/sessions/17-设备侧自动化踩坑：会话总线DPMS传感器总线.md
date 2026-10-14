## 十七、设备侧自动化踩坑：会话总线 / DPMS / 传感器总线（2026-10-09 实测）

140. **★greetd 起的桌面会话跑在 UID 1000，其临时 session bus 拒绝 root 连接**：
    root 直接 `gdbus call --session …`（哪怕从 phoc 的 `/proc/<pid>/environ` 里取到
    `DBUS_SESSION_BUS_ADDRESS`）报 `Error connecting: The connection is closed`（迷惑点：地址是对的、
    socket 还是 `srwxrwxrwx`）。⇒ 所有要走会话总线的操作（真实熄屏 = `org.gnome.ScreenSaver.SetActive`、
    gsettings、phosh D-Bus）必须降权到会话属主：
    `U=$(sed -n 's/^Uid:[[:space:]]*\([0-9]*\).*/\1/p' /proc/$(pidof phoc)/status | head -1);
     setpriv --reuid=$U --regid=$(…Gid…) --clear-groups env DBUS_SESSION_BUS_ADDRESS=$A XDG_RUNTIME_DIR=/run/user/$U gdbus …`。
    **旧脚本 `scripts/sleep-sweep.sh` 里 root 直连的写法在新会话形态下会静默失效 ⇒ 假样本**：
    任何「熄屏类」自动化必须先做 `PATHCHECK`（实测 `dpms` 真变 Off 再变 On）再开始计数。
141. **root 写 `/sys/class/drm/card0-DSI-1/dpms` = `Permission denied`（DRM 拒绝，和 uid 无关）**：
    所以熄屏**没有 sysfs 退路**，唯一真实路径是会话总线 `ScreenSaver.SetActive`（`modetest -w :DPMS:` 也是空操作，
    见 G1-22 记录）。判「有没有画面」用 `dpms` + dmesg `vblank timeout`，不要用亮度节点（背光在坏发里也亮）。
142. **`iio-sensor-proxy` 的能力属性挂在管理器对象本身**：`/net/hadess/SensorProxy` 上的
    `HasAccelerometer / HasAmbientLight / HasProximity / AccelerometerOrientation`（罗盘另在
    `/net/hadess/SensorProxy/Compass`）。**不存在** `net.hadess.SensorProxy.Accelerometer` 接口，
    照文档抄 `busctl get-property … net.hadess.SensorProxy.Accelerometer HasAccelerometer` 会
    `No such interface`（`gdbus Properties.Get` 同样报错，容易误判成「传感器又没了」）。
    正确做法：先 `busctl --system tree net.hadess.SensorProxy` + `introspect` 看真实接口再取值；
    且它在**系统总线**（会话总线上查会 `ServiceUnknown`）。

143. **`reboot2 bootloader`（PSCI SYSTEM_RESET2 vendor reason）偶发把设备打进「USB 完全消失」态**：
    2026-10-09 从 RAM 诊断内核发起，90 s 内既无 fastboot 设备、SSH 不通、`lsusb` 也没有任何
    18d1/05c6（连 EDL 9008 都没有）、ping 不通 ⇒ 远程通道全断，只能长按电源 20 s 强制关机再短按开机
    （**别带音量键，否则又进 fastboot**）。所以自动化温启循环必须：① 每轮失败即停，不连打；
    ② 明确「90 s 无 fastboot = 交给用户物理冷启」，别把等待时间堆到几分钟。

