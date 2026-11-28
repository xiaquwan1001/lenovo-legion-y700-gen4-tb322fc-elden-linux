# #766 非 root 的 `dbus-monitor` 看不到单播 `PropertiesChanged` ⇒ 「lux 60 s 变化 12 次」这类口径作废

- **日期**：2026-11-28（lane S2 复核上一轮测量口径）

## 现象

上一轮用非 root 采到的「60 s 内 lux 变化 **12** 次」与本轮 `sudo` 口径的「SSC 输出 **286** 次跳变/60 s」
差一个数量级，看起来像两个世界。实际原因不是行为变了，而是**测量通道不同**：

- 非 root 的 `dbus-monitor --system` 只能 eavesdrop，**看不到** `net.hadess.SensorProxy` 发给自己客户端（gsd-power）的
  **单播** `PropertiesChanged` ⇒ 计数严重偏低甚至为 0；
- 传感器层本身（`ssccli --sensor light`）≈ 5 Hz、0–496 lux、16 lux 量化。

## 判据（正确测法）

```sh
# 代理上报次数（权威）
sudo journalctl -u iio-sensor-proxy --since "-1min" | grep -c "Emitted light changed"
# D-Bus 信号（必须 root）
sudo dbus-monitor --system "type='signal',sender='net.hadess.SensorProxy'"
# 传感器层真值（不经代理）
timeout -k 5 62 ssccli --sensor light --timeout 60 | awk 'NR>1&&$NF!=p{c++}{p=$NF}END{print c+0}'
```

推论：任何"频次/抖动量级"结论必须写明**采集通道 + 是否 root**，否则不可比。
细节 = `reports/sensors-orientation-als-20261128.md` §3.1/§4。
