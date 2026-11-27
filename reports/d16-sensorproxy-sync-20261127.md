# D16 收尾：把「传感器出数后再起 iio-sensor-proxy」固化成单元（2026-11-27 晚，父代理上机）

- **性质**：仓库两件新文件 + `deploy-desktop-shell.sh` 新增 §19 四件判据；设备侧已装并**真重启**验证。
- **背景**：D16 记的竞态在本轮 vk197 上机时**原样复现** —— 冷启后 `HasAccelerometer=false`（`HasAmbientLight/Proximity=true`），手工 `systemctl restart iio-sensor-proxy` 才三 true。根因 = `iio-sensor-proxy`(3.9 ssc) 先于 hexagonrpcd 的 SSC attach 起来，启动时枚举不到 SSC 加速度计。

## 0. 结论

| # | 判据 | 结果 |
|---|---|---|
| 1 | 固化件在位且与仓内逐字节一致 | ✅ `/usr/local/sbin/elden-sensorproxy-sync.sh`（sha `3ddfaa2f…`）+ `/etc/systemd/system/elden-sensorproxy-sync.service` |
| 2 | 单元 enabled（重启后仍会跑） | ✅ `systemctl is-enabled` = `enabled` |
| 3 | **冷启动后无需人工** | ✅ 真重启后 24 s SSH 可达时**三属性已全 true**；journal = `elden-sensorproxy-sync: ready after 5s (HasAccelerometer=true)` / `Result=success` / `ExecMainStatus=0` |
| 4 | **失败路径也真能修**（不只happy path） | ✅ 手工 `systemctl stop iio-sensor-proxy` 后跑本单元：`after stop` 属性不可得 → 单元日志 `ready after 5s (HasAccelerometer=true)` → `after sync: b true`、代理 `active` |
| 5 | 门禁接入 | ✅ `deploy-desktop-shell.sh --check` 在装前报 **MISS=3**（脚本/单元/状态），装后 **MISS=0**；`verify.sh --offline` FAIL=0；`check-doctor` FAIL=0 |

## 1. 为什么不是「加 `After=elden-sensorspd.service`」

`elden-sensorspd.service` 是 `Type=oneshot` + `ExecStart=/usr/local/sbin/elden-sensorspd-start`（**exec 常驻 hexagonrpcd**）⇒ 该单元会一直停在 `activating`，oneshot 的「start 完成」永远不到。给它加 `After=` 会把同步器一直堵到自己的 `TimeoutStartSec`。

⇒ 改成**轮询真就绪**：每 5 s 跑一次 `ssccli --sensor accelerometer --timeout 3`，看到 `Accelerometer sensor measurement` 就认为 SSC 真在出数；此时若 `HasAccelerometer != true` 才 `systemctl restart iio-sensor-proxy`（一次），随后复读属性并打日志。上限 150 s，超时**不失败**（只在 stderr 说明，boot 不被拖死）。

## 2. 落地件

| 文件 | 作用 |
|---|---|
| `packaging/elden-userland/files/usr/local/sbin/elden-sensorproxy-sync.sh` | 同步器（POSIX sh，`sh -n` 过；已进 `MANIFEST.tsv`（script / 755 / sha `3ddfaa2f…`）） |
| `rootfs/debian/units-extra/elden-sensorproxy-sync.service` | `Type=oneshot` + `After=local-fs.target` + `WantedBy=multi-user.target`（stage.sh 会按 WantedBy 建 wants 软链 ⇒ 重建根后自动启用） |
| `scripts/deploy-desktop-shell.sh` §19 | 四件判据：脚本 sha / 单元 sha / enabled / `HasAccelerometer=true`（`--check` 只判不改；run 模式幂等装） |

## 3. 已知边界（诚实标注）

- 本轮冷战**没走到 restart 分支**（proxy 在 5 s 时已 true）⇒ 「冷启时必然 false」不是每次必现，属**时序依赖**；失败分支用「手工 stop 代理」单独证过（§0 判据 4）。
- 单元只重启代理**一次**；若 SSC 在 150 s 内都没出数，它不会循环重试（那时真因在传感器栈，不在代理）。
- `deploy-desktop-shell.sh` 的 run 模式本轮还顺带把 §17 charge-watch 与 §18 elden-wake.path 重新命中（幂等，无副作用）。

## 4. 复跑

```sh
bash scripts/deploy-desktop-shell.sh --check          # 期望 MISS=0
sudo systemctl stop iio-sensor-proxy                  # 失败路径演练
sudo systemctl start elden-sensorproxy-sync.service
sudo journalctl -u elden-sensorproxy-sync -n 5 --no-pager
busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer
```
