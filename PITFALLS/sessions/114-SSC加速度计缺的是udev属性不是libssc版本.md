## #451 「`HasAccelerometer=false` 但 `ssccli` 能出数」缺的是 **udev 属性**，不是 libssc 版本 / 内核 / DSP

> 2026-10-27。Debian 根（`linux17` ext4，UTS `…vk172`）上 G1-34 回归。
> 台账当时的结论是「回到 libssc 0.4.3 即可」——**这条是错的**，本轮当场推翻并修好。

### 一、症状与错误归因链

| 观测 | 当时的推断 | 实际 |
|---|---|---|
| `qrtr-lookup` 有 `400 = Snapdragon Sensor Core service` | SSC 注册了 | ✅ 对 |
| `ssccli --sensor accelerometer --timeout 6` 连续出 `Z≈9.6 m/s²` | 数据源正常 | ✅ 对 |
| `iio-sensor-proxy -v` 只 `Discovering sensor UID for data type 'rotv' / 'ambient_light'` | 「libssc 0.4.4 的 discover/类型命名变了」 | ❌ **accel 这条驱动根本没被调用** |
| Alpine 根 libssc 0.4.3 时 `HasAccelerometer=true` | 「0.4.4 回归」 | ❌ 两棵根真正的差异是 udev 规则 |

差值不在库，在**设备属性**：

```bash
# Debian 根（坏）
udevadm info --query=property /dev/fastrpc-adsp | grep SSC
#   IIO_SENSOR_PROXY_TYPE=ssc-light ssc-compass        ← 少 ssc-accel
```

### 二、机制（代码级）

`iio-sensor-proxy` 3.9 的 SSC 驱动按属性「认领设备」，不是按能力探测：

```c
/* src/drv-ssc-accel.c */
static gboolean
ssc_accelerometer_discover (GUdevDevice *device)
{
    if (!drv_check_udev_sensor_type (device, "ssc-accel", NULL))
        return FALSE;      /* ← 没有这个属性，函数到此为止 */
    ...
}
```

而属性由发行版的 `80-iio-sensor-proxy.rules` 给，**上游 3.9 与 Debian 3.9-1 都只给了两种**：

```
SUBSYSTEM=="misc", KERNEL=="fastrpc-adsp*", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-light ssc-compass"
SUBSYSTEM=="misc", KERNEL=="fastrpc-sdsp*", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-light ssc-compass"
```

⇒ `drv_ssc_accel` 连 `probe` 都不进，`libssc` 的 `accel` 类型发现自然一次都不会被请求。
所以日志里「只有 rotv / ambient_light」**不是库缺能力**，是**上层没问**。

`ssccli` 直连 libssc，走 `data-type 'accel'` 自己发现 ⇒ 它能出数，恰恰证明库没问题（这也是最容易把人带偏的一条证据）。

### 三、修法（一条 udev 规则，30 秒生效，不用重启/重编）

```bash
cat > /etc/udev/rules.d/81-libssc-elden.rules <<'EOF'
SUBSYSTEM=="misc", KERNEL=="fastrpc-adsp*", \
  ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-accel ssc-proximity ssc-light ssc-compass", \
  ENV{ACCEL_MOUNT_MATRIX}="-1, 0, 0; 0, -1, 0; 0, 0, 1"
EOF
udevadm control --reload && udevadm trigger --subsystem-match=misc --action=change
systemctl restart iio-sensor-proxy
```

判据（三条同时成立才算修好）：

```bash
busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy \
  net.hadess.SensorProxy HasAccelerometer HasAmbientLight HasProximity
# → b true / b true / b true
busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy \
  net.hadess.SensorProxy AccelerometerTilt   # → s "face-up"（平放）
```

⚠ `AccelerometerOrientation` 常态是 `undefined`（需要客户端 claim 且有倾角变化才更新），
**不要**拿它当「没修好」的判据；`AccelerometerTilt` 才是稳定可判的那一个。

### 四、为什么 Alpine 好、Debian 坏（同一块板、同一套包版本）

Alpine 根在 2026-10-09 布传感器时就手写过这条规则
（`/etc/udev/rules.d/81-libssc-elden.rules`，同一份值、同一个 `ACCEL_MOUNT_MATRIX`），
换到 Debian 根时**它是设备侧资产、仓库无副本**（正是 T14「黑资产收敛」要解决的问题），
于是随根一起丢了 —— 但症状长得像「库回归」，把人引向版本 bisect。

### 五、固化（本轮已做）

| 动作 | 落点 |
|---|---|
| 规则进仓库 | `packaging/elden-userland/files/etc/udev/rules.d/81-libssc-elden.rules` |
| 进清单（stage.sh 会铺） | `packaging/elden-userland/MANIFEST.tsv` 新 kind `udev-rule` |
| 门禁（防再丢） | `verify.sh` §E 新增红线：规则必须存在且含 `ssc-accel` + `ACCEL_MOUNT_MATRIX`（负向测试：移走文件 → `FAIL=2`） |
| 端到端 | `rootfs/debian/stage.sh` 重建 `out/stage-debian`，`FAIL=0 WARN=1`（WARN = T14 既有债务） |

### 六、教训

① **「数据源能用」与「上层能看到」是两件事**：libssc/ssccli 通 ≠ 桌面通；中间的 udev 属性是一条**静默门**（缺了只表现为「日志里少一条」）。
② **跨根迁移时，设备侧小文件比包更危险**：包版本可以对照，`/etc/udev/rules.d/8x-*.rules` 这种「一个文件决定一条能力」的东西丢了毫无提示。
   ⇒ 凡是我们手写过、能让某个能力从死到活的**单文件**，必须进 MANIFEST + 门禁。
③ **归因顺序**：先比「上层有没有问」（`grep` 属性 / `strace` / `-v` 日志里出现的是哪种类型），再比库版本。
   本轮把「缺 libssc 0.4.3」写进台账并当作待办，代价是一次多余的版本回退计划。
