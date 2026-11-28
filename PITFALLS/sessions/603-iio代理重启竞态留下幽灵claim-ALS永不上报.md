# #764 `iio-sensor-proxy` 重启竞态留下「幽灵 claim」⇒ ALS 永不上报、`LightLevel` 恒 0

- **日期**：2026-11-28（lane S2 定因，父代理复核）
- **机器/版本**：Y700 四代 TB322FC，Debian trixie，`iio-sensor-proxy 3.9-1`、`gnome-settings-daemon 48.1-1`、phosh 0.46

## 现象

`restart iio-sensor-proxy`（或任何代理重启）之后，宿主读不到环境光：`busctl … LightLevel` 恒 `d 0`，
`journalctl -u iio-sensor-proxy -b | grep -c "Emitted light changed"` = **0**，gsd-power 侧也不再有背光动作。
此时**不是**「客户端不重连」——gsd-power 由 `gnome-session-binary` 拉起（不是 user unit，`systemctl --user` 查不到），
它只 claim 一次、失败即不再重试。

## 机制（本 boot 实证）

代理启动/重启时客户端立刻发 `ClaimLight`，而这个 claim **早于**代理完成 `find_sensors()`：

```
16:57:40 Handling driver refcounting method 'ClaimLight' for ambient light sensor device
16:57:40 Discovered 'proximity' sensor (...)
16:57:40 Found device /sys/devices/virtual/misc/fastrpc-adsp of type ambient light sensor at SSC light sensor   ← 晚于 claim
```

于是 claim 走 `driver_type_exists=false` 分支**静默回成功但不启采样**，后续该客户端的再 claim 全变 no-op：

```
17:51:38 Sender ':1.654' already claimed device, no-op        # :1.654 = pid 96406 = gsd-power
```

全 boot 计数：`ClaimLight=4`、`ReleaseLight=1`、**`Emitted light changed=0`**、ALS 传感器 enable（由 gsd 侧触发）= **0**。

## 判据（可复跑）

```sh
sudo journalctl -u iio-sensor-proxy -b | grep -E "already claimed|Enabling sensor|Found device.*ambient light"
sudo journalctl -u iio-sensor-proxy -b | grep -c "Emitted light changed"     # 0 = 链路断
busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy LightLevel   # d 0
ps -eo pid,ppid,args | grep -E 'gsd-power|iio-sensor-proxy'                  # 确认谁是客户端、谁是系统级 unit
```

## 处置

- **根治** = 代理侧补丁：claim 在对应传感器 `Discovered` 之前挂起/可重试（`patches-userland/iio-sensor-proxy-20261128/` 的 `0001`；部署 = `scripts/deploy-iio-sensor-proxy-patches.sh`，实测反演见 `reports/iio-proxy-patches-20261128.md`）。
- **临时恢复**：`sudo busctl … ClaimLight`（root 授权可过）或重开一次会话让 gsd-power 重新 claim；
  **`ambient-enabled` / `orientation-lock` 翻转等"看似安全"的路子已实测无效**（journal `-- No entries --`、无 Claim/Release 记录）。
- 相关：`#765`（同一轮的矩阵错值）、`#766`（测量口径坑）；细节与全部原始计数 = `reports/sensors-orientation-als-20261128.md` §1。
