# 2026-10-27 · G1-34 定案：`HasAccelerometer=false` 的真因是 udev 属性，不是 libssc 版本

- **日期**：2026-10-27
- **pi 会话 id**：`$PI_SESSION_ID`
- **主题**：按「掉电率最低优先、其余照做、设备可用」重启当轮工作，第一件 = 台账上的 G1-34 Debian 根传感器回归。
- **结论（数字）**
  1. **根因 = 缺 udev 属性 `ssc-accel`，不是 `libssc 0.4.4`**。`drv-ssc-accel.c` 的 discover 首行是
     `drv_check_udev_sensor_type (device, "ssc-accel", NULL)`，而上游与 Debian 的 `80-iio-sensor-proxy.rules`
     都只给 `fastrpc-adsp*` 打 `ssc-light ssc-compass` ⇒ accel 驱动**连 probe 都不进**。
     Debian 根实测 `/dev/fastrpc-adsp` 的 `IIO_SENSOR_PROXY_TYPE = ssc-light ssc-compass`（少 accel）。
  2. **修法 = 一条 udev 规则，30 s 生效**（无重启、无重编、无换包）：补
     `ssc-accel ssc-proximity ssc-light ssc-compass` + `ACCEL_MOUNT_MATRIX="-1, 0, 0; 0, -1, 0; 0, 0, 1"`
     → `udevadm control --reload` + `udevadm trigger --subsystem-match=misc --action=change`
     → `systemctl restart iio-sensor-proxy`。
  3. **判据全绿（设备实测）**：`HasAccelerometer=true` / `HasAmbientLight=true` / `HasProximity=true`，
     `AccelerometerTilt="face-up"`。⚠ `AccelerometerOrientation` 常态 `undefined`（需 claim + 倾角变化），
     **不可作判据** —— 本轮先被它误导过一次。
  4. **为什么只有 Debian 坏**：Alpine 根 2026-10-09 手写过同一份 `81-libssc-elden.rules`，换根时它属于
     设备侧黑资产（仓库无副本，正是 T14 要收敛的东西）⇒ 随根丢失，但症状长得像「库回归」。
  5. **顺手清掉一个「设备不干净」的假象**：`systemctl --failed` 的 `lxc-net.service` 是**旧 boot 的陈旧失败态**
     （unit 现已 `disabled`，且 `stage.sh` 本就把它 mask）⇒ `systemctl reset-failed` 后
     `is-system-running = running`、失败单元 **0**。
- **证据指针**：`PITFALLS #451`（`PITFALLS/sessions/114-SSC加速度计缺的是udev属性不是libssc版本.md`，含代码级机制与三条判据），
  `packaging/elden-userland/files/etc/udev/rules.d/81-libssc-elden.rules`。
- **★SSOT 已并入**：`TASKS/README.md` §1 G1-34 行（🟡 → ✅「两棵根都可用」，旧结论「回到 0.4.3」标注推翻）
  与 §0 的「上游化/未开始」格（`G1-34 已收口`）；`PITFALLS/README.md` 索引第 115 行。
- **固化（防再丢）**：规则进 `packaging/elden-userland/files/`；`MANIFEST.tsv` 新增 kind `udev-rule`；
  `verify.sh` §E 新增语义红线「SSC 加速度计 udev 规则在位」（负向测试：移走文件 → `FAIL=2`，放回 → `FAIL=0`）；
  `rootfs/debian/stage.sh` 重建 `out/stage-debian` 后 `FAIL=0 WARN=1`（WARN = T14 既有 `elden-hapticd` 二进制债务）。
- **未做**：`ACCEL_MOUNT_MATRIX` 未在 Debian 根上重新四姿态标定（沿用 Alpine 10-09 标定值，两棵根硬件相同）；
  Phosh 侧自动旋转的**交互验证**需看屏幕，留给用户目视；SLPI 原生 IIO 路线仍未开工（不在本轮范围）。
