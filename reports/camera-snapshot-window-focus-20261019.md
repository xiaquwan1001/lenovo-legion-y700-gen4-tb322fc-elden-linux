# 相机 App（GNOME Snapshot 50）一直转圈：真根因 = 窗口拿不到焦点（2026-10-19）

> **一句话**：相机栈全好、portal 权限也给了，但 **phoc 的 seat 没有键盘设备**，
> 客户端拿不到 `wl_keyboard.enter` ⇒ **GTK 的 `is-active` 恒为 false** ⇒
> Snapshot 的 `Camera::start()`（挂在 `connect_is_active_notify` 上）**永不触发** ⇒ 从不调用
> `portal.Camera.AccessCamera` ⇒ 设备提供者不启动 ⇒ 界面一直转圈。

## 0. 数字结论

| 检查 | 结果 |
|---|---|
| `org.gnome.Snapshot` 的 camera 权限 | `[yes]` ✅ |
| `portal.Camera.IsCameraPresent` | **true** ✅ |
| `portal.Camera.OpenPipeWireRemote` | 返回有效 fd ✅ |
| `gst-device-monitor Video/Source` | 2 台（`gc08a8` 前 / `s5kjns` 后，含 rotation 90/270）✅ |
| 裸 libcamera 出流 | 30 fps、AE 收敛 ✅（§46 已验收） |
| Snapshot 调用 `AccessCamera` | **0 次**（dbus-monitor 全程无）❌ |
| `wl_seat.capabilities` | **4**（只有 TOUCH）❌ |
| 最小 GTK 测试窗 `is-active` | **false** ❌ |
| 起 squeekboard 后 seat caps | **6 / 7**，`wl_keyboard.enter` 出现 ✅ |
| 起 squeekboard 后 `is-active` | **true** ✅ |
| 起 squeekboard 后 Snapshot | `AccessCamera` + `OpenPipeWireRemote` 调用，`Camera found`×2，`Device provider started`，camerabin `Playing`，**屏幕出现真动态预览** ✅ |

## 1. 完整链条

```
phoc seat 只有 libinput touch/pointer（本机没有物理键盘）
  ⇒ wl_seat.capabilities = 4（POINTER=2, KEYBOARD=1 都没有）
  ⇒ 客户端收不到 wl_keyboard.enter
  ⇒ GTK4 GtkWindow::is-active 恒 false
  ⇒ snapshot/src/widgets/window.rs 的 connect_is_active_notify 永不回调
  ⇒ camera.rs 的 Camera::start() → stream() → AccessCamera/OpenPipeWireRemote 从未执行
  ⇒ DeviceProvider 未 start ⇒ viewfinder 停在 Loading ⇒ Spinner 永远转
```

源码依据（snapshot 50.0，已下载 `snapshot-50.0.tar.gz` 核对）：

```rust
// src/widgets/window.rs
let is_active_handle = obj.connect_is_active_notify(|obj| {
    if !obj.is_active() { return; }
    ...
    obj.imp().camera.start().await;      // ← 唯一的入口
});
```

## 2. 复现与判据

```sh
# ① seat 能力（4=仅TOUCH / 6=+POINTER / 7=+KEYBOARD）
WAYLAND_DEBUG=1 <gtk4 app> 2>&1 | grep -oE "wl_seat#[0-9]+\.capabilities\([0-9]+\)"

# ② 最小复现器（20 行 GTK，比盯 Snapshot 快得多）
#    /tmp/acttest2.py：present() 后打印 is-active

# ③ 客户端是否真收到键盘
WAYLAND_DEBUG=1 <app> 2>&1 | grep -c "wl_keyboard.*\.enter"     # 本坑 = 0
```

⚠ 关键认知：**触控事件是照常送达的**（`wl_touch.down/up` 有记录，按钮也能点），
所以「手指点得动」**不能**证明「窗口有焦点」。GTK4 的 `is-active` 是 keyboard focus-in 驱动的。

## 3. 修法

```sh
squeekboard &          # 走 zwp_input_method_v2 ⇒ phoc 注册非 libinput 虚拟键盘
                       # seat_has_keyboard() 对非 libinput 键盘直接 return TRUE
```

生效判据：`seat caps 4 → 7`、`wl_keyboard.enter` 出现、`is-active=True`、
Snapshot 日志出现 `Camera page showing: starting stream`、屏幕出真图。

**持久化（未做）**：squeekboard 目前是手动起的。开机自启需走 `/etc/xdg/autostart`
或 phosh 的 OSK 配置；**不做持久化，重启后回到转圈状态**。

## 4. 现场证据

- `logs/cam-snapshot-20261019/`：转圈截图（`snap-*.png`、`cur.png`）、
  修好后真预览（`ga..gd.png`、`s1..s6.png`，逐张 md5 不同 = 动态流）
- Snapshot 日志关键行（`/tmp/snapF.log`、`/tmp/snapG.log` 在设备上）：

```
snapshot::widgets::camera: org.freedesktop.portal.Camera:IsCameraPresent: true
aperture::device_provider: Camera found: Built-in Front Camera, target-object: Some(474)
aperture::device_provider: Camera found: Built-in Back Camera,  target-object: Some(472)
aperture::viewfinder::imp: Viewfinder realized: starting stream
snapshot::widgets::camera: Device provider started
aperture::viewfinder: Trying to set camerabin state to Playing
```

## 5. 排除项 / 走过的弯路（给下一个会话）

1. **先按 UI 状态机分层**，别一头钻进相机栈：
   `窗口 active → 调 portal → 枚举设备 → START 流 → 出帧 → 帧正确`。
   本轮第一层就没过，但前两小时全花在 IPA/helper/帧内容上。
2. **20 行最小 GTK 窗当对照**（`acttest2.py`）是转折点：它同样 `is-active=False`，
   直接排除「Snapshot 特有 bug」。
3. **别用内核侧 `evtest` 证明"事件到了客户端"**：必须 `WAYLAND_DEBUG=1` 看客户端侧。
   本轮一度 grep 写错（`wl_touch.` vs `wl_touch#32.`），误判"客户端收不到触摸事件"。
4. **`gst-device-monitor` 能列出相机 ≠ Snapshot 能用**：它是设备侧的旁路检查，
   与 portal/焦点完全无关。
5. 早前 `pipewiresrc ! ... "target not found"` 的现象（#335）确实存在，
   但那只是**权限未授予时**的表现；授予之后 `pipewiresrc` 正常，剩下的门是焦点。

## 6. 关联

- `PITFALLS/sessions/50-相机App转圈真根因-phoc无键盘致is-active恒假.md`（#343）
- `reports/camera-app-portal-rootcause-20261018.md`（前置：portal 后端缺失）
- `PITFALLS` #335（Snapshot 只走 pipewiresrc）、#318（greetd）、§46（AE）
