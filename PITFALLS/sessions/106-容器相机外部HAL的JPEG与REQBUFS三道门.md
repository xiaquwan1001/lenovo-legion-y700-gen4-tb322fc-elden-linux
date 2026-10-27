# #438 external camera HAL 的 JPEG 只在 MJPEG 源下存在；#439 必须 NV12；#440 REQBUFS 被压到 3

- **日期**：2026-10-27
- **场景**：Debian 根 + Waydroid 容器，要让**容器内 App 实开相机预览**（C5/U7）。
  主机侧链路已通（mainline 相机 → libcamera → gst → `/dev/video100`），容器里
  `Number of camera devices: 1`、`Device 0 maps to "200"`，但 App 一直"打不开相机"。

## #438 需要"拍照尺寸"的 App 打不开：HAL 不给 JPEG（BLOB）

OpenCamera 的报错只有一行（在 app pid 上）：

```
E CameraController2: no picture sizes returned by getOutputSizes
```

HAL 侧同时给出原因：

```
V ExtCamDev@3.4: initOutputCharsKeys: format YUYV is not supported!
I ExtCamDev@3.4: initOutputCharsKeys: advertising YUV streams for YUYV
…
android.scaler.availableStreamConfigurations: [35 1280 720 OUTPUT] [34 1280 720 OUTPUT]
```

35 = `YCbCr_420_888`、34 = `IMPLEMENTATION_DEFINED`，**没有 33 = BLOB(JPEG)**。
AOSP 的 external camera HAL 只在 V4L2 源支持 **MJPEG** 时才把 MJPEG 直通成 BLOB，
而 `v4l2loopback 0.15.4` **不支持任何压缩格式**（源码里没有 MJPG 条目）。
⇒ 走 loopback 这条路，**静态拍照永远没有尺寸**，OpenCamera/Simple Camera 这类
"先建 photo session" 的 App 一律在初始化阶段就退出（连视频模式都进不去，
因为它先算 photo sizes）。

**绕法（已实测）**：用**只做 preview + analyze** 的 App —— QR/条码扫描器
（本轮用 F-Droid `de.markusfisch.android.binaryeye`）。它可以完全不碰 BLOB。

## #439 源格式必须 NV12；`exclusive_caps` 必须 1

- `YUYV`：HAL 只当"YUV 兜底"，`cameraserver` 的 legacy 参数层报
  `Camera2-Parameters: generated preview size list is empty` ⇒ `unable to build defaults (-22)`
  ⇒ `connectHelper: Could not initialize client from HAL`。**OpenCamera 默认还走 Camera1 API**，
  正好命中这一层（把它切到 Camera2：`preference_camera_api=preference_camera_api_camera2`）。
- `NV12`：映射成 `YCbCr_420_888`，Camera2 路径可直接用（推荐）。
- `exclusive_caps=0`（想让 ENUM_FMT 列出全部 59 种格式、从而拿到 MJPEG）**不可行**：
  HAL 打开设备时报 `initCameraCharacteristics: v4l2 device open /dev/video100 failed`、
  `Camera3-Device: Could not open camera session: Broken pipe (-32)`。

## #440 `VIDIOC_REQBUFS expected 4 buffers, got 3 instead`

格式/打开都对之后的最后一道门：

```
I ExtCamDevSsn: configureStreams: request stream 1280x720
E ExtCamDevSsn: configureV4l2StreamLocked: VIDIOC_REQBUFS expected 4 buffers, got 3 instead
E ExtCamDevSsn: V4L configuration failed!, format:NV12, w 1280, h 720
E Camera3-Device: configureStreamsLocked: Unable to configure streams with HAL: Function not implemented (-38)
```

两个原因叠加：
① `v4l2loopback` 默认 `max_buffers=2` ⇒ 必须 `modprobe … max_buffers=8`；
② 即使 `max_buffers=8` 仍只给 3：`vidioc_reqbufs()` 里
   `if (has_other_owners() && used_buffer_count > 0) req_count = used_buffer_count;`
   —— 写端 `gst v4l2sink` 默认只申请 **3** 个 buffer，后开的后端（HAL 要 4 个）被**强制压到 3**。
   修法 = `patches/extmod/0001-v4l2loopback-allow-grow-reqbufs.patch`（只保底、允许放大到
   `max_buffers`），重编 `out/extmod-vk172/v4l2loopback.ko`（vermagic 必须逐字等于目标 UTS）。
   **一条命令可复现**：`bash scripts/deploy-v4l2loopback.sh`（自动读设备 UTS → 打补丁 →
   临时改 `kernel.release`/`utsrelease.h` 编 → 核对 vermagic → 部署 → `modprobe … max_buffers=8`；
   实测输出 `vermagic OK` + `/dev/video100` + `max_buffers=8`）。

过了这道门才有：

```
I ExtCamDevSsn: configureV4l2StreamLocked: start V4L2 streaming 1280x720@30.000000fps
V ExtCamDevSsn: threadLoop: converting to format NV12
D StreamStateObserver: Update Preview stream state to STREAMING
→ dumpsys media.camera: Active Camera Clients: [Camera ID: 200 … Package Name: de.markusfisch.android.binaryeye]
```

## #441 生产者 `gst-launch` 会 SIGSEGV，帧一停 App 就卡 spinner

```
/tmp/cam-nv12.log: Caught SIGSEGV
                   exec gdb failed: No such file or directory
                   Spinning.  Please run 'gdb gst-launch-1.0 <pid>' …
```

判据：`logcat | grep -c threadLoop` **不再增长**（HAL 没有新帧），而
`dumpsys media.camera` 仍显示 client active ⇒ 界面停在加载圈。
**未定位**（不是配置问题；`pkill` 后重起生产者可复现/恢复）。排查建议：
`GST_DEBUG=3` 抓崩溃前最后的 element、或改用 `v4l2src`/`ffmpeg` 侧写端对照。

## 本轮顺带确认的依赖（Debian 根）

`gstreamer1.0-tools/plugins-base/plugins-good` + `gstreamer1.0-libcamera`（`libcamerasrc`）
+ `v4l-utils`（`v4l2-ctl`）+ `libcamera-tools`（`cam -l`）；缺任一件时表现为
"no element libcamerasrc" 或 `cam` 命令不存在。已进 `pkgmap.tsv`（`camera-loopback` 行）。

## 附带发现：`verify.sh` 的 F 段前提变了（设备已换根）

设备现在跑 **Debian 根**，而 `packaging/elden-userland/MANIFEST.tsv` 是**从 Alpine 根 sync 出来的**，
所以 `verify.sh` 的 F 段（设备逐字比对）会把整批 openrc/`conf.d` 条目判成 FAIL/不存在：

```
FAIL  /etc/conf.d/greetd: 设备与仓库副本不一致（… ≠ …）
WARN  /etc/init.d/backlog-floor: 设备上已不存在（仓库副本保留）
```

这不是漂移事故，是**判据前提**变了（同一份清单不能同时描述两种 init 的根）。
当前口径：**Debian 根上用 `verify.sh --offline`（FAIL=0 WARN=0）**；F 段只在 Alpine 根上有效。
将来若 Debian 根成为日常线，应把 MANIFEST 拆成 根×init 两套（或按 root label 分支），不要直接 sync 覆盖。
