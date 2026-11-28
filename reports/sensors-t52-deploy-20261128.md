# T52 上机部署记录：iio-sensor-proxy 补丁 + ACCEL_MOUNT_MATRIX 改值（2026-11-28）

> 设备：`ssh elden`（唯一一台），在机 `7.3.1-debug-vk189-suspend-g4da9a8b69fc8-dirty`，Debian trixie arm64。
> 用户 2026-11-28 明确「可以部署」后执行。**回滚件**：`/etc/udev/rules.d/81-libssc-elden.rules.bak-20261128`、
> `dpkg` 3.9-1 可一条命令重装（`sh /tmp/deploy-iio-sensor-proxy-patches.sh --rollback`）。

## §0 结果

| 步骤 | 结果 | 判据 |
|---|---|---|
| ① 装 `iio-sensor-proxy 3.9-2elden`（补丁 0001 claim 延迟 + 0002 deadband） | ✅ 装上并重启代理 | `dpkg -l` = `3.9-2elden`；二进制 sha `e20e690d…`；`NEEDED` 9/9 与原件一致；max GLIBC 2.38 ≤ 2.41 |
| ② **claim 竞态已修**（本次部署的核心目标） | ✅ **两次重启代理都命中** | journal：`Turning deferred claim from ':1.1828' for ambient light sensor device into a real claim` → `Enabling sensor (…) in 'on-change' mode` → `Emitted light changed: from 0.000000 to 272.000000` |
| ③ `ACCEL_MOUNT_MATRIX` 改为 `1,0,0; 0,1,0; 0,0,-1` | ✅ 设备 + 仓内副本 + skill 三处同步 | `udevadm info -q property /dev/fastrpc-adsp` 读回新值；平放 `AccelerometerTilt` 从 `face-down` → **`face-up`** |
| ④ ALS 上报频次（0002 目标 ≤6 次/60 s） | ✅ 6 次/60 s（改前同一口径 282 次/60 s） | `journalctl … grep -c 'Emitted light changed'`；驱动样本 310/60 s（≈5 Hz）不变 |
| ⑤ 背光写入（目标 ≤2 次/60 s） | ❌ **10 次/60 s**（未达标） | 见 §2：ALS 上报与背光写入**逐条 1:1 对应**，属**传感器噪声幅度过大**（静止环境 96↔352 lux，≈3.7 倍），0002 的 `max(20 lux, 5%)` 阈值必然放行 |
| ⑥ 临时缓解 | `org.gnome.settings-daemon.plugins.power ambient-enabled` = **false**（原值 true，收口前恢复） | 与部署前**实际**行为等价（部署前 ALS 从不上报 ⇒ 自动亮度等同关闭），避免把用户的背光抖起来 |

## §1 关键原始输出

### 1.1 部署前（ALS 链路断，与 `#764` 定因一致）

```
window=2026-11-28T10:55:16Z..10:56:18Z
backlight_writes=0
emitted_light_changed=0
driver_samples=0
lightlevel=d 224          ← 缓存值，不是活数据
```

### 1.2 部署后（`--apply` 输出节选）

```
iio-sensor-proxy installed : 3.9-2elden
binary sha256              : e20e690d884aab7b8f889244e37e2c65bf9f387daddb3de23d28a83ecfcd584c
'Tuning deferred claim' / 'Turning deferred claim' since boot : 1
'Emitted light changed' last 60 s : 1
LightLevel                 : d 272        ← 活数据
```

### 1.3 部署后 60 s 实测

```
window=2026-11-28T10:58:41Z..10:59:43Z
backlight_writes=10
emitted_light_changed=6
driver_samples=310
lightlevel=d 112
```

### 1.4 抖动归因（1:1 对照，这是 0003 的立论）

```
ALS 19:01:17 192→160     BL 19:00:48 446→1024（前一次动作）
ALS 19:01:23 160→352     BL 19:01:23 446→810
ALS 19:01:26 352→96      BL 19:01:26 810→446
ALS 19:01:29 96→240      BL 19:01:29 446→1024
ALS 19:01:33 240→96      BL 19:01:33 1024→567
ALS 19:01:35 96→288      BL 19:01:35 567→364
```

⇒ 每次 `Emitted light changed` 后 ≤1 s 内背光就跟着跳；`96 ↔ 352` 对应亮度 `446 ↔ 1024`（2.3 倍）= **肉眼可见的闪**

### 1.5 矩阵验收（平放，root 临时 claim，读后立即 release）

```
ClaimAccelerometer → AccelerometerTilt = s "face-up"   ← 改前是 s "face-down"
（AccelerometerOrientation 平放时为 "undefined"，因为 x/y ≈ 0，属正常）
ReleaseAccelerometer → released
```

**仍待用户目视的一项**：竖持、顶边朝上 ⇒ 画面是否正立（区分 M_A / M_B / M_C）。这一步自动化判不了。

## §2 为什么 0002 不够、0003 要做什么

- 传感器层噪声：静止环境读数在 **96 ↔ 352 lux** 之间跳（16 lux 量化、≈5 Hz、301 s 内 31 个不同值、0–544 lux 全域）。
- gsd-power 48.1 只有 `ambient-enabled` 一个开关，**没有 deadband/曲线可调**（`strings /usr/libexec/gsd-power`）。
- ⇒ 相对 5% / 绝对 20 lux 的阈值对这种幅度必然放行。**0003 = 中值(5) + EMA(α≈0.2) + 强滞回 `max(60 lux, 30%)` + 大跳变(≥150 lux)立即放行 + ≤6 次/60 s 硬预算**，目标背光写入 ≤2 次/60 s。
- 0003 用设备真实 trace（1507 样本/301 s）反演验收，产物见 `patches-userland/iio-sensor-proxy-20261128/`。

## §3 复现

```sh
scp patches-userland/iio-sensor-proxy-20261128/artifacts/iio-sensor-proxy_3.9-2elden_arm64.deb \
    scripts/deploy-iio-sensor-proxy-patches.sh elden:/tmp/
ssh elden 'sudo -n sh /tmp/deploy-iio-sensor-proxy-patches.sh --check'
ssh elden 'sudo -n CONFIRM=yes sh /tmp/deploy-iio-sensor-proxy-patches.sh --apply \
           --deb /tmp/iio-sensor-proxy_3.9-2elden_arm64.deb \
           --expect-sha256 af9171823a2c3b1d396880552d02dc7abb827db5e2c99cc400e150b357513b05'
# 回滚
ssh elden 'sudo -n sh /tmp/deploy-iio-sensor-proxy-patches.sh --rollback'
```
