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
| ⑥ 临时缓解 | `ambient-enabled` 曾临时 false 止血；**0003 上机后已恢复 true** | 见 §4 |

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

## §4 0003 平滑上机（2026-11-28 19:16，`3.9-3elden`）

- 装 `3.9-3elden`（中值5 + EMA α=0.20 + 滞回 `max(60 lux,30%)` + 快通道 150 lux）：`dpkg -l` = `3.9-3elden`，NEEDED 9/9、max GLIBC 2.38。
- 恢复 `ambient-enabled=true` 后，同一窗口实测：**背光写入 0 次 / 90 s**、`Emitted light changed` **0 次**（此前同口径 10 次背光写入）。
- journal 可见平滑生效：`Emitted light changed: from 0.000000 to 0.000000 (first reading)` → `… to 218.766817 (hysteresis)`（小数 = EMA 平滑值，不再是 16 lux 量化台阶）。
- 反演口径（子代理产出、我用真实 trace 复跑 `artifacts/sim-0003.py` 一致）：上报 worst-60 s **2**、背光写入 worst-60 s **2**；真实开关灯延迟 0.8–2.0 s。

## §5 phosh 侧缺口（用户 2026-11-28 报「状态栏没有 auto 档位」）

| 事实 | 证据 |
|---|---|
| **phosh 本 boot 从未 claim 加速度计** | 代理 journal 里 `ClaimAccelerometer` 只有 2 次，均为父代理 `sudo busctl … ClaimAccelerometer`（随后立即 Release）；phosh(pid 273289，18:04:41 启动) 一条都没有 |
| phosh 因此停在「锁定方向」模式 | `AccelerometerOrientation` 恒 `undefined`；把 `orientation-lock` 置 false 也不触发 claim（只影响下次启动） |
| 启动时的 `orientation-lock` = **true** | `gsettings get org.gnome.settings-daemon.peripherals.touchscreen orientation-lock`（子代理 §5 记录也显示原值 true） |
| 亮度 auto 消失是**我方副作用** | 部署时临时 `ambient-enabled=false`；0003 上机后已恢复 `true`（`gsettings get` 复核） |

⇒ 「状态栏没有 auto 档位」拆成两件事：**亮度 auto = 已恢复**；**方向 auto = phosh 0.46 不重连 SensorProxy**（代理重启/设置变更都不 re-claim，与 `#764` 同类：客户端侧缺重连）。
</br>修法候选：① UI 点一次旋转图标（若 phosh 走自己的 action 会切 SENSOR 模式并 claim）；② 重启一次会话（已知副作用：droidloom 不自启 = `T46`、Q28 modeset 风险）；③ 给 phosh 打「name-owner 变化即重建 proxy + 重新 claim」的补丁（永久修复，需交叉编 phosh + 一次会话重启）。

## §6 进一步措施：用户点旋转图标无效后，重启一次会话（2026-11-28 19:43）

- 先试过的**无效**路径（都留证据，省下次重试）：
  - `orientation-lock` true→false：phosh 不 claim（`set_orientation_locked` 里 `claimed==locked` 的早退路径没触发）。
  - `orientation-lock` true→false→**true→false**（强制走 `claim_or_release`）：仍不 claim。
  - 用户手动点快捷设置旋转图标：仍无 auto。
  - ⇒ 结论：phosh 进程内 `claimed` 状态已与真实不一致（代理重启后它以为还拿着 claim），**运行时无法自愈**。
- 采取措施：`systemctl restart greetd`（用户在场；回退路径 = 物理冷启，Q28 modeset 风险已知）。
- 结果（新 phosh pid `319310`）：
  ```
  19:43:23 iio-sensor-prox: Handling driver refcounting method 'ClaimAccelerometer' for accelerometer device
  19:43:23 iio-sensor-prox: Enabling sensor (7037…) in 'continuous' mode      ← 加速度计真的开始出流
  19:43:23 iio-sensor-prox: Enabling sensor (5230…) in 'on-change' mode       ← ALS 同时被 gsd claim
  ```
  ⇒ **phosh 在会话重建后立刻 claim 成功**，与「运行时无法自愈」的判断一致。
- 副作用（已复现并处置）：`T46` —— 会话重建后 **droidloom 不自启**（`droidloomctl status` = `stopped`），已手工 `systemctl --user -M xuqianhui1001@ start droidloom.service`，`Android is ready`、cell `u1001` running。
- 待用户目视两项：① 转动设备是否自动旋转（auto 档位是否回来）；② 竖持顶边朝上时 `AccelerometerOrientation` 应为 `left-up`/`right-up`（矩阵 M_A 定案）。

### 6.1 应报上游 / 待补的 phosh 缺陷（本次定因）

`phosh` 的 `PhoshRotationManager` 用 `GDBusProxy`（`sensor-proxy-manager.c`）连 `net.hadess.SensorProxy`，但只监听
`notify::has-accelerometer` 与 `notify::accelerometer-orientation`（`rotation-manager.c` 的 `constructed`）。
代理重启时 D-Bus 名字 owner 变化、但 `HasAccelerometer` 值不变 ⇒ **两个 notify 都不触发**，而 `self->claimed` 仍是 `TRUE`
⇒ 会话内**永久不重新 claim**，表现为：自动旋转消失、快捷设置只剩纵向/横向。
修法（待办）：监听 `notify::g-name-owner`（或 `g-signal` 的 NameOwnerChanged），把 `self->claimed = FALSE` 后按当前
`mode`/`orientation_locked` 重新走 `claim_or_release_accelerometer()`；顺带把 `set_orientation_locked` 的早退条件收紧。

## §7 矩阵第二次修正：`diag(1,-1,-1)`（用户 2026-11-28 19:4x 目视「竖屏正常、横屏颠倒」）

- 用户复验 `diag(1,1,-1)` 的结果：**竖屏正确、横屏 180° 颠倒**。
- 按 `src/orientation.c` 的判据反推（源码核对，非猜测）：
  - `portrait_rotation = atan2(x, √(y²+z²))`，`>0 → left-up(90°)`、`<0 → right-up(270°)`
  - `landscape_rotation = atan2(y, √(x²+z²))`，`>0 → bottom-up(180°)`、`<0 → normal(0°)`
  - 竖屏正确 ⇒ **x 符号正确**；横屏 180° 颠倒 ⇒ **y 符号反了** ⇒ 第 2 行取反
- ⇒ 定值 **`1, 0, 0; 0, -1, 0; 0, 0, -1`**（`det=+1`，绕 X 轴 180° 的真旋转；平放仍 `face-up`，已复核 `Tilt=s "face-up"`）。
- **诚实记录**：报告 §2.4 的候选表把 M_B（本值）预测成「画面仍 180° 反」，该预测**是错的**（当时把两条口述约束当成了充分条件）；现以用户实测 + `orientation.c` 源码为准。
- 上线动作（按顺序，一次做完）：改设备 udev → `udevadm trigger` → `systemctl restart iio-sensor-proxy`（矩阵在 discovery 时读取，必须重启代理）→ **再 `systemctl restart greetd` 一次**让 phosh 重新 claim（否则方向 auto 依旧消失，见 §6）。
- 复验状态：`phosh` 新 pid `322942`（19:45:44 启动）在 19:45:45 `ClaimAccelerometer` + 加速度计 continuous 出流；`droidloom` 已手工起到 `Android is ready`。**待用户目视**：横屏是否正立、竖屏是否仍正常。
