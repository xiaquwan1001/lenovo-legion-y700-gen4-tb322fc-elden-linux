# 研究：重力/自动旋转的用户级开关（2026-10-09）

> 只读调研，未动设备/领域层文件。前置事实：SSC/QRTR svc400 + iio-sensor-proxy 3.9 + phosh 0.55，
> 自动旋转已可用，开机竞态已持久化修复（`rootfs/persistent-overlay/iio-sensor-proxy.initd`）。

---

## 0. 一句话结论

**Phosh 0.55 已原生提供用户级开关（"方向锁定" tile）**——点按切 `orientation-lock`、长按切
`MODE_SENSOR`↔`MODE_OFF`。真正缺失的不是功能本身，而是 **可发现性** 与 **CLI/脚本级"硬关"能力**
（功耗管理、Waydroid 传感器门控）。推荐方案 = **gsettings 脚本包装 + 可选 OpenRC 服务开关**，
代价最低、无补丁。

---

## 1. 当前已有的用户级控制（Phosh 原生）

### 1.1 快速设置 tile（UI）

| 操作 | 效果 | 内部状态 |
|------|------|----------|
| **点按** rotate tile | 锁/解锁方向 | `gsettings org.gnome.settings-daemon.peripherals.touchscreen orientation-lock` ↔ true/false |
| **长按** rotate tile | 完全关闭/开启传感器 | rotation-manager `MODE_SENSOR` ↔ `MODE_OFF`；MODE_OFF 下 ReleaseAccelerometer |
| tile 置灰 | 传感器不可用 | `rotateinfo.present=false`（= mode==OFF 或无可旋转 builtin monitor） |

源码证据（phosh 0.55 main，前次调研已确证）：
- `rotation-manager.c`: `ORIENTATION_LOCK_SCHEMA_ID = "org.gnome.settings-daemon.peripherals.touchscreen"`,
  `ORIENTATION_LOCK_KEY = "orientation-lock"`; `g_settings_bind(... SYNC_CREATE|BIDIRECTIONAL)`。
- `rotateinfo.c`: `enabled = (mode==SENSOR && !orientation_locked)`; `present = !!get_monitor()`。
- `quick-settings.c`: `on_rotate_clicked` → 翻转 lock; `on_rotate_long_pressed` → 切 mode。
- tile `.ui` 中 `visible=1`（恒显示），`sensitive` 绑 `rotateinfo.present`。

### 1.2 gsettings key（CLI/脚本）

```sh
# 锁定（等价于关闭自动旋转）
gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock true
# 解锁
gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock false
# 查询当前状态
gsettings get org.gnome.settings-daemon.peripherals.touchscreen orientation-lock
```

注意：需以桌面会话用户身份执行（见 PITFALLS #140，root 直连会话总线被拒）。

### 1.3 模型语义 vs Android 心理模型

| Android | Phosh | 说明 |
|---------|-------|------|
| "自动旋转" 开/关 | tile 点按 = 锁定/解锁 | **语义相反**：Android 说"开"= Phosh `lock=false`；Android 说"关"= Phosh `lock=true` |
| 通知栏快捷开关 | 快速设置 tile | 等价，但 tile 需下拉 |
| 无"传感器物理关" | tile 长按 = MODE_OFF | Phosh 多一个层级 |

**用户感知问题**：tile 图标是旋转锁标志（不是"自动旋转开/关"文字），且语义反转，
对 Android 用户不直觉。

---

## 2. iio-sensor-proxy D-Bus 控制粒度

### 2.1 现有接口（系统总线 `net.hadess.SensorProxy`，对象 `/net/hadess/SensorProxy`）

| 成员 | 类型 | 说明 |
|------|------|------|
| `HasAccelerometer` | property (readonly) | true 当 SSC 后端绑定了加速度计 |
| `AccelerometerOrientation` | property (readonly) | 当前方向（需先 claim） |
| `AccelerometerTilt` | property (readonly) | tilt 角度（需先 claim） |
| `ClaimAccelerometer()` | method | 客户端声明使用，触发 polling |
| `ReleaseAccelerometer()` | method | 释放，停止 polling |

### 2.2 不可用的控制

- **无 `Enabled` 属性**：不能通过 D-Bus 禁用整个 proxy 或单个传感器类型。
- **无 `Suspend()` 方法**：proxy 无暂停/恢复语义。
- **`ReleaseAccelerometer()` 效果有限**：Phosh 在 `MODE_SENSOR` 下会自动重新 claim；
  只有当所有客户端都 release 后才停止硬件 polling。
- **无法动态移除 `HasAccelerometer`**：proxy 启动时探测一次，之后不会变 false
  （除非 kill 进程）。

### 2.3 进程级控制（OpenRC）

```sh
# 完全停止传感器服务（释放 SSC PD，省电）
rc-service iio-sensor-proxy stop
# 重启
rc-service iio-sensor-proxy restart
# 禁止开机自启
rc-update del iio-sensor-proxy default
```

效果：proxy 停止后 `net.hadess.SensorProxy` 服务名消失 → Phosh rotation-manager 收到
`PropertiesChanged(HasAccelerometer=false)` 或 D-Bus name owner changed → 回到 `MODE_OFF`
→ tile 置灰、停止旋转。重启 phosh 会话才能恢复（已知 phosh 不自动 re-discover 重新出现的 proxy）。

---

## 3. 方案对比（按代价升序）

### 方案 A：利用 Phosh 原生 tile（零代价，已存在）

- **做法**：无。tile 已经是用户级开关。
- **适用**：日常使用"今天不想让屏幕转"。
- **不足**：
  - 图标语义不直觉（是"锁"不是"开关"）
  - 无 CLI/API 入口（需桌面交互）
  - 不能停止硬件 polling（省电场景不适用）
  - 不影响 Waydroid（Waydroid 走 UDP 路径独立）

### 方案 B：gsettings 包装脚本（极低代价）

- **做法**：写一个 shell 脚本 `elden-rotate` 提供 `on`/`off`/`status` 子命令：
  ```sh
  #!/bin/sh
  KEY="org.gnome.settings-daemon.peripherals.touchscreen"
  FIELD="orientation-lock"
  # 以桌面会话用户身份执行 gsettings
  U=$(sed -n 's/^Uid:\s*\([0-9]*\).*/\1/p' /proc/$(pidof phoc)/status | head -1)
  A="unix:path=/run/user/$U/bus"
  run() { setpriv --reuid=$U --regid=$(sed -n 's/^Gid:\s*\([0-9]*\).*/\1/p' \
    /proc/$(pidof phoc)/status | head -1) --clear-groups \
    env DBUS_SESSION_BUS_ADDRESS=$A XDG_RUNTIME_DIR=/run/user/$U gsettings "$@"; }
  case "$1" in
    on)  run set $KEY $FIELD false ;;
    off) run set $KEY $FIELD true  ;;
    status) run get $KEY $FIELD ;;
    *) echo "Usage: $0 {on|off|status}" >&2; exit 1 ;;
  esac
  ```
- **代价**：1 个脚本（~20 行），放 `rootfs/persistent-overlay/`。
- **效果**：等同 tile 点按，可从 SSH/Termux/脚本调用。
- **限制**：只阻止 UI 旋转，传感器仍在 polling（ADSP SSC 仍耗电）。

### 方案 C：OpenRC 服务开关（低代价，硬关）

- **做法**：`rc-service iio-sensor-proxy stop/start` 包装成 `elden-rotate hard-off/on`：
  ```sh
  hard-off) rc-service iio-sensor-proxy stop ;;
  hard-on)  rc-service iio-sensor-proxy start ;;
  ```
- **代价**：扩展方案 B 脚本几行。
- **效果**：proxy 停止 → Phosh tile 置灰、SSC 停止 polling → ADSP 功耗降低。
- **限制**：
  - 重新 start 后 Phosh **不自动恢复** `MODE_SENSOR`（需重启会话，有 Q28 modeset 风险）
  - 除非 phosh 被证明能热感知 proxy 重新上线（待验证）
  - **建议**：stop 后提示"需重启 phosh 会话恢复"；或写个 `restart-rotation` 函数
    同时 restart proxy + 通知 phosh（通过 D-Bus 重连或 GApplication activate）。

### 方案 D：自定义 D-Bus 代理/拦截（中高代价）

- **做法**：写一个小 daemon 注册 `net.hadess.SensorProxy`（系统总线），
  转发请求到真实 proxy 但增加 `Enabled` 属性门控。
- **代价**：需开发 + 部署 + 维护一个 daemon；与 phosh 启动顺序耦合。
- **效果**：完整可编程控制，可暴露 `Enabled` 属性给任何 D-Bus 客户端。
- **不推荐**：当前规模下过度工程化；方案 B+C 覆盖 99% 需求。

### 方案 E：Phosh 补丁/Fork（高代价，上游化考量）

- **做法**：给 phosh 提 patch 使 tile 行为更符合 Android 用户预期：
  - 改 tile 图标 + tooltip 为"自动旋转：开/关"（正向语义）
  - 在 settings app 增加开关入口（若 phosh-settings 存在）
- **代价**：需 phosh 上游 PR 或本地 fork。
- **适用**：长期（G1 上游化阶段）。当前阶段方案 A 足够。

---

## 4. 对 Waydroid 传感器注入（C4）的影响

### 4.1 当前架构

```
[SSC/ADSP] → [libssc] → [iio-sensor-proxy] → D-Bus (system bus) → [Phosh]
                                                         (Phosh rotation-manager claim)

[另一单元 Termux:API] → UDP → [eldroid-sensord] → UDP:52012 → [Waydroid HAL]
                                                          (独立路径，不经过 iio-sensor-proxy)
```

### 4.2 影响分析

| 操作 | Phosh 旋转 | Waydroid 传感器 | 说明 |
|------|-----------|----------------|------|
| `orientation-lock=true`（方案 B） | ❌ 不转 | ✅ 不受影响 | Phosh 忽略方向值，不释放 claim |
| `rc-service iio-sensor-proxy stop`（方案 C） | ❌ tile 灰 | ✅ 不受影响 | Waydroid HAL 从 UDP 收值，与 iio proxy 无关 |
| `rc-service hexagonrpcd-adsp-sensorspd stop` | ❌ tile 灰 | ⚠️ 需确认 | 若 eldroid-sensord 未来改用 iio-sensor-proxy D-Bus 取真值，则受影响；当前走 Termux 转发不受 |

### 4.3 未来演进风险

若 C4 后续将 `eldroid-sensord` 数据源从"Termux 转发"改为"本机 iio-sensor-proxy D-Bus claim"
（降低对另一设备的依赖），则方案 C（停 proxy）会同时断掉 Waydroid 传感器。
**缓解**：脚本 `hard-off` 模式加注释提醒；或 eldroid-sensord 改为直接从 libssc/QRTR 取值
（绕过 iio-sensor-proxy），保持两条路独立。

### 4.4 Waydroid framework 锁旋转补丁（已知约束）

`waydroid.stub_sensors_hal=true` → framework 补丁 `mDefaultFixedToUserRotation=true` →
容器内自动旋转被锁死。我们用 **`waydroid.sensors.enabled`** 替代 prop 名避开此补丁。
用户侧"关闭自动旋转"不需要动容器内 prop——容器旋转跟随宿主 window rotation，
关掉宿主旋转 = 容器也不转（因为宿主 surface 不再 rotate）。

---

## 5. 推荐方案

**分阶段，按需求递进：**

| 阶段 | 方案 | 触发条件 |
|------|------|----------|
| **现在** | A：向用户说明 tile 操作方式 | 用户只是找不到开关 |
| **本周** | B：`elden-rotate` 脚本（`on`/`off`/`status`） | 需要 SSH/脚本/自动化控制 |
| **按需** | C：加 `hard-off`/`hard-on`（OpenRC） | 需要省电/完全禁用传感器 |
| **远期** | E：phosh tile 语义优化 | 上游化阶段改善 UX |

---

## 6. 实施步骤（方案 B 为基准）

### 6.1 新建脚本

文件：`rootfs/persistent-overlay/elden-rotate`（755 权限）

```sh
#!/bin/sh
# elden 自动旋转用户级开关
# 用法: elden-rotate {on|off|status|hard-off|hard-on}
PHOC=$(pidof phoc 2>/dev/null) || { echo "ERROR: phoc not running" >&2; exit 1; }
U=$(sed -n 's/^Uid:[[:space:]]*\([0-9]*\).*/\1/p' /proc/$PHOC/status | head -1)
G=$(sed -n 's/^Gid:[[:space:]]*\([0-9]*\).*/\1/p' /proc/$PHOC/status | head -1)
BUS="unix:path=/run/user/$U/bus"
SCHEMA="org.gnome.settings-daemon.peripherals.touchscreen"
KEY="orientation-lock"

gs() {
  setpriv --reuid=$U --regid=$G --clear-groups \
    env DBUS_SESSION_BUS_ADDRESS=$BUS XDG_RUNTIME_DIR=/run/user/$U \
    gsettings "$@"
}

case "${1:-status}" in
  on)
    gs set $SCHEMA $KEY false
    echo "Auto-rotation: ON (orientation-lock=false)"
    ;;
  off)
    gs set $SCHEMA $KEY true
    echo "Auto-rotation: OFF (orientation-lock=true, sensor still active)"
    ;;
  hard-off)
    gs set $SCHEMA $KEY true   # lock UI first
    rc-service iio-sensor-proxy stop
    echo "Auto-rotation: HARD OFF (proxy stopped, ADSP SSC polling halted)"
    echo "NOTE: To re-enable, run 'elden-rotate hard-on' and restart Phosh session."
    ;;
  hard-on)
    rc-service iio-sensor-proxy start
    gs set $SCHEMA $KEY false
    echo "Auto-rotation: ON (proxy started, orientation-lock cleared)"
    echo "NOTE: Phosh may need session restart to re-detect sensor (tile may stay grey)."
    ;;
  status)
    LOCK=$(gs get $SCHEMA $KEY 2>/dev/null)
    PROC=$(pgrep -f iio-sensor-proxy >/dev/null 2>&1 && echo running || echo stopped)
    HAS=$(busctl --system get-property net.hadess.SensorProxy \
      /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer 2>/dev/null)
    echo "proxy=$PROC  HasAccelerometer=$HAS  orientation-lock=$LOCK"
    ;;
  *)
    echo "Usage: $0 {on|off|status|hard-off|hard-on}" >&2
    exit 1
    ;;
esac
```

### 6.2 注册到 restore.sh

在 `rootfs/persistent-overlay/restore.sh` 追加：
```sh
echo "== elden-rotate user-level toggle =="
install -m755 elden-rotate /usr/local/bin/elden-rotate
```

### 6.3 安装到设备

```sh
# 开发时直接推
scp rootfs/persistent-overlay/elden-rotate root@<device>:/usr/local/bin/elden-rotate
ssh root@<device> chmod 755 /usr/local/bin/elden-rotate
```

---

## 7. 验收判据

| 序号 | 判据 | 方法 |
|------|------|------|
| V1 | 设备横放、开关 `on` → 画面旋转 | 物理横转 + 目视 |
| V2 | `elden-rotate off` → 横放不转 | SSH 执行 + 物理横转 |
| V3 | `elden-rotate on` → 恢复旋转 | SSH 执行 + 物理横转 |
| V4 | `elden-rotate status` 输出三字段正确 | `elden-rotate status` |
| V5 | `elden-rotate hard-off` → tile 置灰 + 不转 | `rc-service iio-sensor-proxy status` = stopped |
| V6 | `elden-rotate hard-on` → tile 恢复可交互（可能需重启会话） | 目视 |
| V7 | 以上不影响 Waydroid 容器内传感器 | Waydroid 容器 `dumpsys sensorservice` 正常 + UDP 事件不中断 |
| V8 | 开机默认：`orientation-lock=false` + proxy running + 能旋转 | 冷启后执行 `elden-rotate status` |

---

## 8. 不做什么

- **不创建** `/sys/bus/iio` 节点（本路线不产生 IIO 设备，proxy 经 libssc 用户态后端）
- **不改** phosh.session / RequiredComponents（无 gsd-orientation，加了会 fail-whale）
- **不引入** 自定义 D-Bus daemon（方案 D，过度工程化）
- **不改** iio-sensor-proxy 源码/补丁（claim-race.patch 是另一条线的事）
- **不动** Waydroid HAL prop（`waydroid.sensors.enabled` 已正确与 stub 解耦）

---

## 9. 未决 / 后续验证项

| # | 问题 | 影响 | 解法 |
|---|------|------|------|
| U1 | Phosh 0.55 是否能热感知 `net.hadess.SensorProxy` 重新上线（D-Bus NameOwnerChanged）| 决定方案 C 是否需要重启会话 | 设备实测 `rc-service iio-sensor-proxy stop && ...start`，观察 tile 是否自动恢复 |
| U2 | 未来 C4 若改为从本机 proxy D-Bus 取真值，hard-off 会同时断 Waydroid | C4 架构决策 | 届时 eldroid-sensord 改为直读 libssc（绕过 proxy）|
| U3 | `orientation-lock` gsettings schema 是否在 phosh-schemas 还是 gsd-schemas 包里 | 确认包依赖 | `apk info -L phosh-schemas \| grep gschema` 或 `gsettings list-sources` |
| U4 | 长按 tile（MODE_OFF）与 `orientation-lock` 的持久化差异 | MODE_OFF 不持久（session-scoped）；lock 持久（dconf） | 若需"永远关"，脚本用 `hard-off` + rc-update del |
