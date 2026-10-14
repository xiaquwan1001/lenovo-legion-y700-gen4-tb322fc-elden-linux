## 十六、自动旋转方向锁死 / 开关置灰 — iio-sensor-proxy 启动时序（2026-10-09 实测）
- **现象**：phosh 快速设置无可用“自动旋转”、方向锁死；实测拿起横过来不转。
- **非因**（逐一排除）：不是 gsd（gsd50 上游已无 orientation 组件，phosh 原生管旋转、连系统总线 `net.hadess.SensorProxy`）；不是 mount-matrix（那只管重力 180° 修正）；不是 D-Bus 总线错配（proxy 就在系统总线且 `HasAccelerometer=true`）。
- **真因**：iio-sensor-proxy 与 `hexagonrpcd-adsp-sensorspd` 同在 default runlevel 并行起；SSC 加速度计要 ADSP 起来出 svc400（冷启数十秒）。iio 3.9「只扫一次即放弃」（G1-34）→ 开机时 proxy 抢在 svc400 前起则整轮无加速度计 → phosh `rotation-manager` 停 `MODE_OFF`（tile 置灰/锁死）。
- **修复**：`/etc/init.d/iio-sensor-proxy` 加 `start_pre()` 等 `qrtr-lookup|grep -qw 400`（封顶 60s、超时照起不退化）+ `after hexagonrpcd-adsp-sensorspd`；仓库真源 `rootfs/persistent-overlay/iio-sensor-proxy.initd`（restore.sh 装包后覆盖）。诊断时临时 `rc-service iio-sensor-proxy restart`（svc400 已在则秒过）后 phosh 重启即恢复——但重启 phosh 会话会重跑一次完整 KMS modeset，Q28 bonded-DSI 有「背光亮无画面」复发风险（本次未触发），非必要不重启动 compositor。
- **UI 说明**：phosh 无独立“自动旋转”开关，只有单个“方向锁定”tile；自动旋转开着时不显示方向选择栏（phosh 正常模型，非 bug）。“开关去哪了”多为模型误解。

