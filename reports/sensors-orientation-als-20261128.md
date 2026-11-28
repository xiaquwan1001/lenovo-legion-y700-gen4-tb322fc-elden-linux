# 传感器姿态（ACCEL_MOUNT_MATRIX）/ ALS 迟滞 / 代理 claim 竞态 — 2026-11-28（lane S2，接续中断的上轮）

> 设备：`ssh elden`（唯一一台），在机 `7.3.1-debug-vk189-suspend-g4da9a8b69fc8-dirty`，Debian trixie，
> `iio-sensor-proxy 3.9-1`、`phosh 0.46.0-3+deb13u1`、`gnome-settings-daemon 48.1-1`，本 boot 11:47:29 起。
> 授权边界：**只读诊断**。未改任何 udev/systemd/SSC 配置，未重启代理/会话/服务，未 kill 任何进程，未装包。
> 设备侧写入仅两处**瞬时** gsettings（已恢复原值，见 §5）。唯一仓库写入 = 本文件；原始取证在设备 `/tmp/sensor-orientation/`。

---

## §0 结论（一页）

| # | 派工项 | 结论 | 状态 |
|---|---|---|---|
| 1 | claim 丢失诊断 | **不是"客户端不重连"**：是代理**启动竞态**造成的**幽灵 claim**（claim 到达时代理还没发现该传感器 ⇒ 回成功但不启传感器）。gsd-power 根本不重试，后续所有 claim 变 no-op；`LightLevel` 本 boot **从未**发出（`Emitted light changed`=0） | **PASS（已定因，含反证唯一恢复路径）** |
| 2 | ACCEL_MOUNT_MATRIX | 现配置矩阵**实测 tilt 反向**（平放屏幕朝上却报 `face-down`）⇒ 第三行错；叠加用户"竖屏 180° 错向"⇒ 两约束联立**唯一解 `1, 0, 0; 0, 1, 0; 0, 0, -1`**（注意 det=−1，见 §2.4） | **PASS（数学唯一定解 + 1 步物理确认脚本）** |
| 3 | ALS 迟滞 | 抖动在**传感器层**（SSC 输出 ≈5 Hz、0–496 lux、**286 次跳变/60 s**、16 lux 量化），代理 3.9 `light_changed_func` **零迟滞零限频**直通，gsd-power 48.1 **无 deadband 可调**。最小落地 = 改代理层（1 函数、可回滚），不是改 gsd | **PASS（定位 + 最小修复 + 回滚 + 前后判据）** |
| 4 | 判据命令 | 见 §4（含一条**必须知道**的坑：非 root `dbus-monitor` 看不到单播 `PropertiesChanged`，上轮"lux 变化 12 次"口径不可比） | **PASS** |

**一句话**：ALS/背光断链的根因在 **iio-sensor-proxy 的 claim 竞态**（不是 gsd-power 迟滞）；姿态矩阵的现值是**错的**，正确值可由本轮实测加一条物理确认定案。

---

## §1 claim 丢失：真实机制 = 代理启动竞态 + 幽灵 claim

### 1.1 先纠两个问法错误（避免继续白查）

| 现象 | 事实 | 证据 |
|---|---|---|
| `systemctl --user is-active gsd-power` = inactive | **gsd-power 不是 user unit**，它是会话应用：`phoc(96236, session-117.scope) → gnome-session-binary(96264) → /usr/libexec/gsd-power(96406)` | `ps -eo pid,ppid,args`；`systemctl --user list-units` 无该项 |
| `systemctl --user is-active iio-sensor-proxy` = inactive | 它是**系统级** unit（`static`）：`systemctl is-active iio-sensor-proxy` = **active** | `systemctl is-active/is-enabled` |
| 因此"重启单个 user unit 让客户端重连" | **不存在这个 unit**，此路不通（见 §1.4 的安全路径） | 同上 |

### 1.2 claim 授权口径（决定了"为什么 ssh 里 monitor-sensor 一定失败"）

`/usr/share/polkit-1/actions/net.hadess.SensorProxy.policy`：`allow_any=no / allow_inactive=no / allow_active=yes`，
代理侧对应 `src/iio-sensor-proxy.c:check_claim_permission()`（action `net.hadess.SensorProxy.claim-sensor`）。

| 主体 | 实测结果 |
|---|---|
| ssh 会话（session 137，`user` 非 active）+ `monitor-sensor` | `AccessDenied: Not Authorized: Sensor claim not allowed` |
| `sudo busctl … ClaimLight`（uid 0） | **rc=0，授权通过** ⇒ 本轮用它做了"能出数吗"的对照实验 |
| phosh 会话（session 117，seat0，active）+ `gsd-power` | 授权通过 |

> 坑：`pkcheck --action-id … --process $$` 判的是 **shell 的 pid**（uid 1001），所以它对 root 也报
> "Not authorized"，**不可用来判 root**。用真实 `busctl … ClaimLight` 才准。

### 1.3 根因（逐条钉死，全 boot 计数）

代理本 boot（11:47:29 起）计数：`ClaimAccelerometer=1`、`ClaimLight=4`、`ReleaseAccelerometer=0`、
`ReleaseLight=1`、**`Emitted light changed=0`**、`Emitted tilt changed=1`、`Emitted orientation changed=0`、
**ALS 传感器 enable 次数 = 0**。

1. **16:57:40 代理被重启**（上一轮为"冷启无加速度计"做的 restart，见 `reports/d16-sensorproxy-sync-20261127.md`）。
   重启瞬间 `gsd-power` 见到名字重新出现**立刻**发 `ClaimLight`，而此时代理还在 `name_acquired_handler()` 里跑
   `find_sensors()`。日志顺序（同一秒内）证明 claim **早于**该类型被登记：
   ```
   16:57:40  Handling driver refcounting method 'ClaimLight' for ambient light sensor device
   16:57:40  Discovered 'proximity' sensor (...)
   16:57:40  Found device ... of type ambient light sensor at SSC light sensor     ← 晚于上面那条
   ```
   `handle_generic_method_call()`（src/iio-sensor-proxy.c:543）此时 `driver_type_exists(LIGHT)==FALSE`
   ⇒ 走 `else { return_value(); }` 分支：**claim 回成功、驱动一行都没启**。
2. 之后**每次** claim 都被这张表挡掉。17:51:38 的实证：
   ```
   Handling driver refcounting method 'ClaimLight' for ambient light sensor device
   Sender ':1.654' already claimed device, no-op
   ```
   `:1.654` = `GetConnectionUnixProcessID` → **pid 96406 = gsd-power**（幽灵 claim 持有者）。
3. 幽灵 claim 从不清除：它只在**持有者进程消失**时才被 `client_vanished_cb()` 释放；gsd-power 一直活着。
4. 传感器侧的 `ssc_light_set_polling()` 还有第二层锁死：`if (drv_data->measurement_id) return;`
   —— 一旦某次 enable 走了一半，后续 claim 永远不重试。

⇒ **`LightLevel` 恒 0 不是"代理不再上报"，而是代理**从未**开始采样 ALS。同理 accel：本 boot 唯一一次
`ClaimAccelerometer` 是**我们自己** 17:44:49 用 root 发的；phosh 在重启后没再 claim（客户端侧
`self->claimed` 仍是旧值 TRUE，0.46 的 `claim_or_release_accelerometer()` 因此直接返回）。

### 1.4 恢复路径：安全 / 有风险（**本轮均未执行有风险项**）

**A. 安全且真能修（推荐，需父代理决策"改代码"）** —— 代理侧补两处，然后 `systemctl restart iio-sensor-proxy`：

```c
/* (1) src/iio-sensor-proxy.c: handle_generic_method_call() 的 else-if 分支：
 *     驱动存在但没在跑时也要启，别因为"已有幽灵 claim"就 no-op */
} else if (... delayed ... || !driver_is_polling (sensor_device)) {
        g_ptr_array_add (... delayed ..., invocation);
        driver_set_polling (sensor_device, TRUE);
/* (2) name_acquired_handler() 末尾：discover/open 完成后，把已经存在 claim 的类型补启 */
for (i = 0; i < NUM_SENSOR_TYPES; i++)
        if (driver_type_exists (data, i) && g_hash_table_size (data->clients[i]) > 0)
                driver_set_polling (DEVICE_FOR_TYPE(i), TRUE);
```
- 不重启会话、不重启 greeter、不碰 SSC/#692；回滚 = 重装 pin 住的 `iio-sensor-proxy 3.9-1` deb。
- 判据：`sudo journalctl -u iio-sensor-proxy | grep -c "Enabling sensor (5230347032368999062 3046173514946711665)"` ≥ 1，
  且 `grep -c "Emitted light changed"` > 0，且 `busctl get-property … LightLevel` ≠ 0。

**B. 已本轮实测证伪的两条"看似安全"的路（别再试）**

| 路径 | 结果 | 证据 |
|---|---|---|
| `gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false→true`（让 gsd 释放再重 claim） | **无效**：窗口内代理零日志，无 Release/Claim | `journalctl -u iio-sensor-proxy --since 17:48:45 --until 17:49:40` → `-- No entries --`（gsd-power 48.1 只在启动时读该键，运行期不反应） |
| `gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock` true→false（触发 phosh 重 claim accel） | **无效**：`Claim/ReleaseAccelerometer` 均未出现 | 两次演练窗口（17:51:25–17:51:54、17:52:35–17:53:03）journal 无相应行；原因见 0.46 `rotation-manager.c:630-637` —— `claim_or_release_accelerometer()` 在 `claim == self->claimed` 时直接 return（且 `PHOSH_STATE_BLANKED` 会强制 `claim=FALSE`） |

**C. 有风险（**未执行**，交父代理/用户决策）**
1. `kill 96406`（gsd-power）清幽灵 claim → 依赖 gnome-session 是否 respawn；失去背光/空闲/挂起管理**且不保证自动回来**。
2. `systemctl restart iio-sensor-proxy` 再"碰运气"：**实测恰恰是它制造了幽灵 claim**（16:57:40 = 1/1 失败），
   对一个"见名字即 claim"的客户端几乎必然重演；且重启后 accel 也会因 phosh 客户端侧 `claimed=TRUE` 而挂掉。
3. 重启会话/greeter：派工单禁令，不做。

---

## §2 ACCEL_MOUNT_MATRIX：现值错在哪、正确值怎么定

### 2.1 代理侧的数学（先固定公式，别凭感觉）

- 取矩阵：`M` 三行按 `ACCEL_MOUNT_MATRIX="r0; r1; r2"` 逐行填，`a_app = (r0·a_raw, r1·a_raw, r2·a_raw)`
  （`src/accel-mount-matrix.c:apply_mount_matrix()`）；SSC 驱动 `scale=1.0`（`src/drv-ssc-accel.c:116`）⇒ 单位 m/s²。
- 判据（`src/orientation.c` + `src/test-orientation.c` 的期望值）：
  `portrait=atan2(x,√(y²+z²))`、`landscape=atan2(y,√(x²+z²))`，阈值 35°；
  `x>0→left-up`、`x<0→right-up`、`y>0→bottom-up`、`y<0→normal`(顶边朝上横屏)；
  `tilt=atan2(z,√(x²+y²))`，**`z>0` 才是 face-up**。
- phosh 映射（`phosh 0.46 src/rotation-manager.c:110-135`）：`normal→0°`、`right-up→270°`、`bottom-up→180°`、`left-up→90°`。

### 2.2 现配置 + 一次静态读数（本轮实测）

- 在机 udev 值（`udevadm info -q property /dev/fastrpc-adsp`）：
  `ACCEL_MOUNT_MATRIX=-1, 0, 0; 0, -1, 0; 0, 0, 1`（**即 M0 = diag(−1,−1,+1)**）。
- `ssccli --sensor accelerometer`（10 样本，静止平放）：`a_raw ≈ (−0.952, +0.354, −9.522)`，|a|=9.57 m/s²。
  姿态旁证 = **屏幕朝上**：同窗口 ALS 读到 64–496 lux（光敏面未被桌面遮挡）。
- 代入：`a_app = M0·a_raw = (+0.952, −0.354, −9.522)` ⇒ `tilt = atan2(−9.522, 1.017) = −84°` ⇒ **`face-down`**（矛盾！）
- 双向实证（不是推算）：
  - 代理日志 17:44:49：`Emitted tilt changed: from undefined to face-down`
  - `busctl get-property … AccelerometerTilt` → **`s "face-down"`**（缓存值，随时可复读）

⇒ **约束 R3（硬）**：`M·a_raw` 的 z 分量必须 > 0 ⇒ 第三行 = **`0, 0, -1`**。

### 2.3 定解

用户已实测"竖屏 180° 错向" ⇒ 面内两轴标签整体反号（left-up↔right-up、normal↔bottom-up）⇒ 前两行相对 M0 各取反：
**约束 R12**：第一行 `1, 0, 0`、第二行 `0, 1, 0`。

在"带符号置换"矩阵族（3!·2³=48 个）里，同时满足 R3 与 R12 的**只有一个**：

```
ENV{ACCEL_MOUNT_MATRIX}="1, 0, 0; 0, 1, 0; 0, 0, -1"        ← M_A（唯一解）
```

一行待应用改动（**本轮不应用**，交父代理决策）：
`/etc/udev/rules.d/81-libssc-elden.rules` 里该 ENV 行改为上式，然后
`udevadm control --reload && udevadm trigger --action=change /sys/class/misc/fastrpc-adsp && systemctl restart iio-sensor-proxy`
（仓内同步副本 `packaging/elden-userland/files/etc/udev/rules.d/81-libssc-elden.rules:17` 与 `verify.sh:320` 的期望串也需同步 —— 那属 SSOT 层）。

### 2.4 诚实标注：det(M_A) = −1（不是真旋转）

M_A 的行列式为 −1 ⇒ 它是**镜像**，物理含义＝"传感器原始帧相对屏幕帧是左手系"。iio-sensor-proxy 不校验 det，
orientation/tilt 判据都不受影响，所以**可用**；但若父代理坚持"必须真旋转"，则说明 R3 或 R12 有一条不成立，
候选退化为下表，用 §2.5 的**一次物理动作**即可区分：

| 候选 | 值 | 预期 flat `AccelerometerTilt` | 竖屏顶边朝上时 |
|---|---|---|---|
| M_A（推荐） | `1,0,0; 0,1,0; 0,0,-1` | face-up ✅ | 画面正立 |
| M_B | `1,0,0; 0,-1,0; 0,0,-1`（绕 X 180°） | face-up | 画面仍 180° 反 |
| M_C | `-1,0,0; 0,1,0; 0,0,-1`（绕 Y 180°） | face-up | 画面仍 180° 反 |
| M_D | `1,0,0; 0,1,0; 0,0,1`（只修 180°，不修 tilt） | **face-down** ❌ | 画面正立 |

### 2.5 一条命令做最终确认（父代理/用户各做一次即可）

```sh
# 应用候选矩阵后，平板竖持、屏幕朝向自己、顶边朝上，然后：
sudo busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy AccelerometerOrientation
# 期望：left-up 或 right-up，且画面相对"顶边朝上"是正的；平放时 AccelerometerTilt 必须是 face-up
```
注意：orientation/tilt 属性只有在**有 claim** 时才更新，而客户端现在不 claim（§1）——
所以这条确认**必须先解 §1（补丁 A）或用 `sudo monitor-sensor` 临时 claim**，否则读到的是缓存（`undefined`/`face-down`）。

> 历史对照：`reports/userland-auto-rotation-toggle-20261011.md` 与仓内规则注释沿用 Alpine 2026-10-09 标定的
> `diag(-1,-1,1)`，而**本轮实测该值在 tilt 上就是错的**。差异来源可解释：现在 SSC 的 registry/config 由
> `/usr/local/bin/hexagonrpcd-patched -R /var/lib/hrpcd-root/` 供给（与 Alpine 期环境不同）⇒ **旧标定值不可再直接沿用**，
> 需按本节重新定案。

---

## §3 ALS 抖动：在哪一层、最小怎么修

### 3.1 分层实测（本轮）

| 层 | 测量 | 数字 |
|---|---|---|
| SSC/传感器 | `ssccli --sensor light --timeout 60` | **303 样本/60 s（≈5 Hz）**，26 个不同值，**0–496 lux**，**286 次跳变/60 s**，量化步长 **16 lux** |
| iio-sensor-proxy 3.9 | `src/iio-sensor-proxy.c:906-917 light_changed_func()` | **任何**数值变化即 `send_dbus_event(PROP_LIGHT_LEVEL)` ⇒ 零迟滞、零限频、零平滑 |
| gsd-power 48.1 | `strings /usr/libexec/gsd-power` | 只有 `ambient-enabled` 一个开关；无 deadband/曲线可调；写入经 `GSD_BACKLIGHT_HELPER`（root 助手写 sysfs） |
| 宿主 sysfs | `aw99706-backlight`（max 4095） | 本 boot 链路断开 ⇒ 观察窗内写入 **0 次**（不是"没有抖动"，是"没人上报"） |

**结论**：抖动源 = **传感器 + 代理直通**；gsd-power 只是忠实把每个 lux 值变成一次背光写入。
👉 派工单里"gsd-power 无迟滞"这一半成立，但**改 gsd 无处可改**（无 key），且**光靠它也不会修复**（因为 LightLevel 根本没发出）。

### 3.2 最小可落地修复：改代理层（1 个函数）

- 落点：`src/iio-sensor-proxy.c:light_changed_func()`（3.9，仓外源码树 `/tmp/ssc-prep/iio-sensor-proxy` commit `0085ddf` = 3.9，与在机 3.9-1 同源）。
- 改什么：加 deadband + 保持时间，其余不动：
  ```c
  /* 只在变化够大、或保持 >1 s 且变化 ≥10 lux 时上报 */
  delta = ABS (readings->level - data->previous_level);
  thr   = MAX (20.0, data->previous_level * 0.05);
  if (delta < thr && !(elapsed > 1.0 && delta >= 10.0))
          return;               /* 仍要调 maybe_notify_sensor_startup_finished() 之前的读值缓存 */
  ```
  （`previous_level` 的更新与 `maybe_notify_sensor_startup_finished()` 的调用位置需保持原语义，避免 claim 首读延迟被 deadband 挡住 —— 实现要点：**第一次读数无条件上报**。）
- 产物：`patches-userland/0004-iio-sensor-proxy-light-deadband.patch` + 交叉构建 deb（父代理决定是否入仓）。
- 部署：`dpkg -i` 新包 → `systemctl restart iio-sensor-proxy`（**不需要**重启会话；但注意重启代理会重演 §1 竞态，所以 **§1 的补丁必须先落地**）。
- 回滚：`apt-get install --reinstall iio-sensor-proxy=3.9-1`（已有 pin/hold，见 `scripts/deploy-ssc-sensors.sh`）。
- **不推荐**先改 SSC 侧（`/var/lib/hrpcd-root/sensors/registry/…` 的 ambient_light rate/threshold）：生效需重启
  `hexagonrpcd-patched`，直接踩 #692 禁区。

### 3.3 修前 / 修后对比判据（同一 60 s 窗口、同一光照）

| 指标 | 采集命令 | 修前（本轮） | 目标 |
|---|---|---|---|
| SSC 层 lux 跳变次数 | `timeout -k 5 62 ssccli --sensor light --timeout 60 \| awk 'NR>1&&$NF!=p{c++}{p=$NF}END{print c+0}'` | **286** | 不变（传感器层不改） |
| 代理上报次数 | `sudo journalctl -u iio-sensor-proxy --since "-1min" \| grep -c "Emitted light changed"` | **0**（链路断） | **≤ 6** |
| `LightLevel` 唯一值数 | `busctl get-property … LightLevel` 轮询 / dbus 采集 | 0（恒 0） | ≤ 6 |
| 背光写入次数 | 100 ms 轮询 `/sys/class/backlight/aw99706-backlight/brightness` 计变化 | 0 | **≤ 2** |

判据口径：补 §1 之后重测"修前"应为 ~286 次上报 / 60 s（≈ 与 SSC 同频），修后必须落到 ≤6 次上报、≤2 次背光写入。

---

## §4 判据命令集（可复跑）

```sh
# 0) 客户端/代理到底是谁（别再用 --user is-active 误判）
ps -eo pid,ppid,args | grep -E 'gsd-power|iio-sensor-proxy' | grep -v grep
systemctl is-active iio-sensor-proxy            # 系统级；static

# 1) claim 链路（权威 = 代理 debug 日志，本机代理已开 debug）
sudo journalctl -u iio-sensor-proxy -b | grep -cE "ClaimLight|ClaimAccelerometer"
sudo journalctl -u iio-sensor-proxy -b | grep -E "already claimed|Enabling sensor|Emitted (light|tilt|orientation) changed" | tail

# 2) LightLevel 频次（★ 必须 root：非 root 的 dbus-monitor 只能 eavesdrop，看不到单播 PropertiesChanged）
sudo dbus-monitor --system "type='signal',sender='net.hadess.SensorProxy'"
#    上轮"60 s 内 lux 变化 12 次"用的是非 root/dbus 或慢速 ssccli 口径，与 286 次/60 s 不可比

# 3) 背光写入计数（100 ms 采样，60 s）
b0=$(cat /sys/class/backlight/aw99706-backlight/brightness); n=0
for i in $(seq 600); do b=$(cat /sys/class/backlight/aw99706-backlight/brightness)
  [ "$b" != "$b0" ] && { n=$((n+1)); b0=$b; }; sleep 0.1; done; echo "writes=$n"

# 4) 自动旋转 / 姿态输出（会自己 claim；非 active session 会被 polkit 拒 ⇒ 必须 sudo）
sudo timeout -k 3 30 monitor-sensor
busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy AccelerometerOrientation
busctl --system get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy AccelerometerTilt

# 5) 矩阵读回（改规则后必须 trigger 再读，只 reload 可能是旧值）
udevadm info -q property /dev/fastrpc-adsp | grep -E 'ACCEL_MOUNT_MATRIX|IIO_SENSOR_PROXY_TYPE'
```

---

## §5 边界、未做与残留

- **未做**：不改 udev/systemd/SSC registry；不重启代理/会话/greeter；不 kill 任何进程；不装包；未改 `TASKS/INDEX/RESOURCES/PITFALLS`；未碰信访件。
- **设备侧写入（全部已恢复）**：
  `ambient-enabled` true→false→**true**（原值 true）；`orientation-lock` true→false→true→false→**true**（原值 true）。
  两次均由 `gsettings get` 复核回原值（脚本输出 `orig=final=true`）。
- **留下的缓存副作用**：代理内 `previous_tilt`/`previous_orientation` 现为 `face-down`/`undefined`（无害，重启代理即清）。
- **未证实/未取到**：端到端（lux→背光）的抖动数字**取不到**，因为 ALS 本 boot 从未被 enable；必须先解 §1 才能验 §3.3 的"修前/修后"。
- **配置漂移（顺带发现，交 SSOT 层）**：`IIO_SENSOR_PROXY_TYPE=ssc-light ssc-compass ssc-accel ssc-proximity ssc-light ssc-compass`
  —— 发行版 80 规则与仓内 81 规则**同时命中**导致重复项；当前无害，但说明规则集合非"单写者"。
- **残留风险**：§2 的 M_A 依赖"竖屏 180° 错向"这条用户口述作为输入约束；若该描述实际指横屏或指面板原生朝向，
  需按 §2.4/§2.5 用 M_B/M_C/M_D 重新定案（一次物理动作即可）。
