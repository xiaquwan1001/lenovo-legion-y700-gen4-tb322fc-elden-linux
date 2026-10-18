# 相机 App（GNOME Snapshot 50）不出画面：根因 = Camera portal 缺后端（2026-10-18）

> **一句话**：`org.freedesktop.portal.Camera` 的 `IsCameraPresent = false`。
> 已装的 portal 后端 `xdg-desktop-portal-gtk` 与 `-wlr` **都不实现 Camera 接口**，
> 而 Snapshot 50 只走 `pipewiresrc`（= PipeWire camera = Camera portal）⇒ 拿不到任何设备。
> **相机驱动 / libcamera 全部正常**，这是纯用户态缺包问题。

## 0. 数字结论

| 检查 | 结果 | 判定 |
|---|---|---|
| `cam`（libcamera CLI）原生出流 | 30 fps，AE 自动收敛（后摄 mean 115 / 前摄 133） | ✅ 相机硬件+驱动+IPA 全好 |
| `libcamerasrc`（GStreamer 插件） | `gst-launch libcamerasrc ! … ! fakesink` 拿到 640×480 RGBA 30/1 | ✅ |
| `gst-device-monitor Video/Source` | 列出 2 台（`camera@56` `Model=s5kjns Rotation=270`、`camera@31` `Model=gc08a8 Rotation=90`） | ✅ 元数据完整（含朝向） |
| Snapshot 二进制里的 source 元素 | 只有 **`pipewiresrc`**（无 `libcamerasrc` / `v4l2src`） | ⚠️ 走 portal 路线 |
| `pipewiresrc ! …` 直测 | **`stream error: target not found`** | ❌ 无相机节点 |
| `org.freedesktop.portal.Camera` `IsCameraPresent` | **`false`** | ❌ **直接根因** |
| 已装后端实现的接口 | gtk: Access/Account/AppChooser/…（**无 Camera**）；wlr: 仅 ScreenCast/Screenshot | ❌ 无后端支持 |
| Alpine 仓库可用包 | **`xdg-desktop-portal-gnome-50.0-r0`** | ✅ 修法明确 |

## 1. 证据链（可复现）

```sh
# ① 相机本身没问题
cam -c /base/soc@0/cci@ac7b000/i2c-bus@0/camera@56 -C200 -s width=1280,height=720
gst-launch-1.0 -v libcamerasrc camera-name="..." ! videoconvert ! fakesink num-buffers=5

# ② Snapshot 只手认 pipewiresrc
strings /usr/bin/snapshot | grep -oE "pipewiresrc|libcamerasrc|v4l2src" | sort -u
#   -> pipewiresrc   （仅此一个）

# ③ 而 pipewiresrc 没有目标
gst-launch-1.0 -v pipewiresrc ! videoconvert ! fakesink num-buffers=3
#   -> ERROR: stream error: target not found

# ④ portal 说没有相机
busctl --user get-property org.freedesktop.portal.Desktop \
  /org/freedesktop/portal/desktop org.freedesktop.portal.Camera IsCameraPresent
#   -> b false

# ⑤ 后端没有 Camera 实现
busctl --user introspect org.freedesktop.impl.portal.desktop.gtk /org/freedesktop/portal/desktop
busctl --user introspect org.freedesktop.impl.portal.desktop.wlr /org/freedesktop/portal/desktop
```

## 2. 修法

```sh
apk add xdg-desktop-portal-gnome     # Alpine 仓库有 50.0-r0
# 需要 xdg-desktop-portal 重启（或重新登录）后生效
# 验收：IsCameraPresent = true，且 gst-launch pipewiresrc 能出帧
```

⚠️ 装包时踩到：USTC 镜像的 `APKINDEX.tar.gz` 返回 **`file format is invalid or inconsistent`**
（`apk update` 报 2 stale、`apk add` 找不到包）。换 tuna 源时网络中断未完成。
⇒ 下次先 `apk update` 确认索引干净，再 `apk add`。**（PITFALLS 已有"USTC 镜像瞬态错误重试即可"的记录，这次是持续失败，需换源。）**

## 3. 顺带查清的两件事

1. **`wireplumber` 当时没在跑**（只有 `pipewire` + `pipewire-pulse`）。
   `/etc/xdg/autostart/` 里只有 `pipewire.desktop`，但 `/usr/libexec/pipewire-launcher`
   末尾会 `exec /usr/bin/wireplumber`，所以正常会话起来时它应该被拉起 —— 本轮观察到的缺失
   属"该会话没走到 launcher"或已被杀，**不是包缺失**（`apk info -L wireplumber` 无 `*.desktop` 是上游设计）。
   实测手动起 wireplumber 后，其 **libcamera monitor 确实枚举到 2 台相机**（日志 `Adding camera` ×2），
   但 **pipewire 侧仍无 camera 节点** ⇒ 与 `IsCameraPresent=false` 一致：**节点要经 portal 才导出**。
2. **`libspa-libcamera.so` ABI 匹配**：`ldd` 指向 `libcamera.so.0.7`，未定义符号里缺的全是
   `libstdc++`/`libgcc` 的（`_ZNSo…`/`_Unwind_*`），**没有缺 libcamera 符号** ⇒ 不是 ABI 问题。

## 4. 与 7.2 时代"能跑通"的关系（重要）

2026-10-07 的记录是「Snapshot 50.0 + libcamera-gstreamer 实测预览/拍照/录像全通」。
本轮查明 **Snapshot 50.0 二进制里只有 `pipewiresrc`**，所以当年能通 ⇒ 当年 PipeWire camera
（或 Camera portal）是工作的。差异候选（**未验**）：

- 当年的 `xdg-desktop-portal-gnome` 可能曾装上、后续 `apk` 升级/清理被移除；
- 或当年 PipeWire 版本较老、camera 节点由 `wireplumber` 直接导出而不经 portal。

⇒ **下次第一件事**：`apk add xdg-desktop-portal-gnome` 后直接验 `IsCameraPresent`，
这一步只需 5 分钟，且**不需要动内核**。
