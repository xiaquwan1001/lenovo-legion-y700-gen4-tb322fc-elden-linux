# #442 缺 `qrtr-tools` ⇒ 自写 pre hook 白等 60 s 且日志误报"SSC 没起来"；#443 SSC 真的在，但 iio-sensor-proxy 发现不到 accel

- **日期**：2026-10-27
- **场景**：G1-34（SLPI/SSC 传感器）在 Debian 根上收口。旧记录写「SSC svc 400 未在 QRTR 注册」，
  本轮实测**该结论不成立**（见 #443）。

## #442 `qrtr-lookup` 属于 `qrtr-tools`，`libqrtr` 里没有

我们自己的 `iio-sensor-proxy.pre`（防止 iio-sensor-proxy 抢跑、永久没有加速度计）判据是：

```sh
qrtr-lookup 2>/dev/null | grep -qw 400
```

Debian 根上 **`qrtr-lookup` 不存在**（包 `qrtr-tools` 没进 apt-list，只装了 `libqrtr*` 运行时），
于是 pre hook 每次都循环 60 次、白等满 **60 s**，然后打一行

```
elden: iio-sensor-proxy: QRTR svc 400 (SSC) not seen after 60s; starting anyway
```

—— 这行字在日志里极易被读成「SSC 没起来」，而实际是**判据工具缺失**。冷起还白多 1 分钟。

**修法**：① `pkgmap.tsv` 加 `qrtr-tools`；② pre hook 先 `command -v qrtr-lookup`，
缺就立刻退出（不再白等）；③ 顺带给 hook 补 `#!/bin/sh`（**缺 shebang 时 systemd 报
`Failed to execute …: Exec format error` / `203/EXEC`**，`stage.sh` 会补，但直接 scp 部署时不会）。

装完立即验证：

```sh
$ qrtr-lookup | awk '$1==400'
      400       1        0    5    21 Snapdragon Sensor Core service
```

## #443 SSC 存在且可用；卡点在 iio-sensor-proxy 的**传感器发现**

- `ssccli --sensor accelerometer --timeout 2` → `X=-0.081 Y=0.282 Z=9.648 m/s²`（真值，连续）
  ⇒ ADSP/SSC 的数据通路、libssc、QRTR 客户端全都正常。
- `iio-sensor-proxy -v`（`G_MESSAGES_DEBUG=all`）里能看到它**连上了 SSC** 并逐条发现：

```
[qrtr] added server on 5:21 -> service 400, version 1, instance 0
'registry' sensor available, discovering sensor now
Discovered 'rotv' sensor (…)   → name: Rotation Vector / vendor: QTI / sample-rate: 5 Hz
```

但 `busctl get-property net.hadess.SensorProxy … HasAccelerometer HasAmbientLight` = **`false / true`
（加速度计没有）**，发现的只有 `rotv`（和一个 `mn`），**没有 `accel`**。

进一步取证（本轮做得比上一版更细，**推翻"iio-sensor-proxy 发现逻辑坏了"的笼统说法**）：

| 根 | iio-sensor-proxy | libssc | 结果 |
|---|---|---|---|
| Alpine（2026-10-09 工作态，`linux18`） | **3.9-r2** | **0.4.3-r0** | `HasAccelerometer/HasAmbientLight/HasProximity = true`（历史记录） |
| Debian（现在，`linux17`） | **3.9**（二进制里 accel/light/compass 相关字符串与 Alpine 版**逐条相同**） | **0.4.4** | `rotv` + `mn` 被发现，**没有 accel** ⇒ `HasAccelerometer=false` |

⇒ 同一台设备、同一个 iio-sensor-proxy 主版本，唯一显著差异是 **libssc 0.4.3 → 0.4.4**；
而 `ssccli`（**也是** libssc 0.4.4）读 accelerometer 正常，说明 DSP/注册表本身没问题，
可疑点是 **libssc 0.4.4 的 discover 路径/数据类型命名**（iio 走 discover，ssccli 走直接属性查询）。
⇒ 结论：**不是**内核/DSP/固件/QRTR 注册，也**不是** iio-sensor-proxy 的 accel 代码缺失，
而是 Debian 侧 libssc 版本差。下一轮实验（按成本排）：① 给 iio-sensor-proxy 加日志打印它请求的
data-type 串；② 用 libssc 0.4.3 交叉验证（Alpine 包可解包/libssc 源码编 0.4.3）；③ 必要时在
iio 侧把 `accelerometer` 显式加入请求列表。

## 判据速查（本轮固化）

| 想确认 | 命令 |
|---|---|
| QRTR 服务表里有没有 SSC | `qrtr-lookup \| awk '$1==400'`（需 `qrtr-tools`） |
| SSC 数据能不能读 | `ssccli --sensor accelerometer --timeout 2`（需 `libssc-bin`） |
| 桌面看到几个传感器 | `busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer HasAmbientLight` |
| 它到底连没连上 SSC | `systemctl stop iio-sensor-proxy; G_MESSAGES_DEBUG=all /usr/libexec/iio-sensor-proxy -v` |
