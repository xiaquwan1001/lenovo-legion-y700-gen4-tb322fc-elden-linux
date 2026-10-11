# 桌面用户态收口：深色/主题（G1-26/27）与亮度滑块（G1-28）—— 上机复核（2026-10-11）

> 设备 U2（b 槽持久直启，vk64 `7.2.0-debug-vk64-gd02658e63cf6`）；会话 = greetd + phosh-session + phoc 0.55.1 / phosh 0.55.0。
> 复核手段：**设备侧 `grim` 截屏**（本轮首次用上，客观取证 GTK 主题与 UI 状态）+ 会话总线 gsettings + logind D-Bus。
> 证据截图：`reports/ui-20261011/`（`gcc-default.png`、`gcc-appearance-light.png`、`gcc-appearance-dark.png`、`ui-before.png`）。

## 0. 一句话结论

| 项 | 状态 | 证据 |
|---|---|---|
| **G1-26 深色模式** | ✅ **已可用** | 无头判据 + `g-c-c` 截屏：`color-scheme=default`→浅色、`prefer-dark`→深色、`prefer-light`→浅色（三者切换即时生效） |
| **G1-27 电源菜单图标反色** | ✅ 同源修复 | `gtk-theme='Adwaita'`（不再 `Adwaita-dark`）⇒ symbolic 图标取到深色模式前景；phosh shell 顶栏 WiFi/电池图标正常 |
| **G1-28 亮度滑块** | 🟡 **核心链路已通，仅缺 GUI 拖拽目视** | greetd 真 logind 会话下 `Session.SetBrightness backlight aw99706-backlight u 1200` **实测生效**（sysfs 160→1200）；phosh 0.55.1 背光**只有 logind 一条路径**（`src/backlight-sysfs.c`），滑块必然走通 |

## 1. G1-26 / G1-27 复核（截屏为准）

设备侧 gsettings 现状（会话总线）：`gtk-theme='Adwaita'`、`color-scheme` 随测试切换、`accent-color='blue'`。
即 **2026-10-05 定位的根因修复（主题名 `Adwaita-dark`→`Adwaita`）已持久落在设备 `/home/xuqianhui1001/.config/dconf/user`**。

**DBus portal 映射正确**（`org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme`）：

```
gsettings=default    -> portal uint32 0   (无偏好)
gsettings=prefer-dark-> portal uint32 1   (prefer-dark)
gsettings=prefer-light->portal uint32 2   (prefer-light)
```

**GTK4/libadwaita（gnome-control-center）截屏逐态**：

| color-scheme | 截屏 | 观感 |
|---|---|---|
| `default` | `reports/ui-20261011/gcc-default.png` | **浅色**（白底、深字、深色侧栏） |
| `prefer-light` | `reports/ui-20261011/gcc-appearance-light.png` | 浅色 |
| `prefer-dark` | `reports/ui-20261011/gcc-appearance-dark.png` | 深色 |

⇒ **深/浅即时切换成立**。Phosh 自带的「深色模式」磁贴（`plugins/dark-mode-quick-setting`）在 `default`↔`prefer-dark` 间翻转 `color-scheme`；现在 `default` 正确渲染浅色，磁贴才有可见效果（修复前 `Adwaita-dark` 回退浅色，磁贴怎么点都像没变）。

**G1-27**：symbolic 图标取主题前景色；`Adwaita` 解析成功 ⇒ 深色背景下图标为浅色。phosh 顶栏（WiFi/电池/锁）在前述 `ui-before.png` 中清晰可辨。

## 2. G1-28 亮度滑块复核

- **核心链路（2026-10-05 候选 A）确认在机生效**：
  ```
  $ busctl-call 之前用 dbus-send:
  $ dbus-send --system --print-reply --dest=org.freedesktop.login1 \
      /org/freedesktop/login1/session/c1 org.freedesktop.login1.Session.SetBrightness \
      string:backlight string:aw99706-backlight uint32:1200
  method return ...
  $ cat /sys/class/backlight/aw99706-backlight/brightness
  1200        # 原 160 ⇒ logind writer 生效（早期无会话时返回 EISDIR）
  ```
  `loginctl list-sessions` 现有 `c1`（user 1000 / seat0 / tty7 / active）⇒ greetd+pam_elogind 的会话已就绪。
- **phosh 侧唯一路径 = logind**：读 phosh 0.55.1 源码 `src/backlight-sysfs.c`，`phosh_backlight_sysfs_set_level()` 只调
  `phosh_dbus_login_session_call_set_brightness(..., "backlight", device_name, ...)`，**无 sysfs 直写后备**；`session_proxy` 空才直接返回。
  ⇒ 会话生效后滑块 `PhoshBacklight`→logind→sysfs 全链成立。
- **未完成项（诚实）**：**滑块拖拽的目视确认没做**——本机 `CONFIG_INPUT_UINPUT is not set`、无 `/dev/uinput`，无法注入触摸来打开 Phosh 快速设置并拖滑块；且显示处于 Q28 风险态。已用「同一 D-Bus 调用经 logind 改实际亮度」等价证明后端，UI 同步（udev `on_backlight_changed`→`g_object_notify`）为代码可推断，未经 GUI 实测。
- **附带发现**：`gnome-control-center` 的 Power 面板**没有亮度行**（`reports/ui-20261011/gcc-power.png`），因为 `gsd-power` 未导出 `org.gnome.SettingsDaemon.Power.Screen` 接口（其对象只导出 `...Keyboard`）。这是 **gsd-power 的另一条路径**，与 Phosh 自身滑块无关（Phosh 走 `PhoshBacklight`，不依赖 gsd-power）。不影响 G1-28 判据，但建议登记（见 `PITFALLS`）。

## 3. 回退 / 备注

- 深色测试结束后 `color-scheme` 保持设备原值 `'default'`（未改变用户状态）。
- 复现命令（主机侧，设备需已开 SSH）：
  ```bash
  # 截屏
  ssh root@192.168.7.1 'setpriv --reuid=1000 --regid=1000 --init-groups env \
    XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 grim /tmp/x.png'
  # 打开 g-c-c 某面板（需 GNOME 身份，否则它拒绝启动）
  ssh root@192.168.7.1 'setpriv --reuid=1000 --regid=1000 --init-groups env HOME=/home/xuqianhui1001 \
    XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DBUS_SESSION_BUS_ADDRESS=<会话总线> \
    GDK_BACKEND=wayland XDG_CURRENT_DESKTOP=GNOME XDG_SESSION_TYPE=wayland setsid nohup gnome-control-center power &'
  ```
