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

## #440 `VIDIOC_REQBUFS expected 4 buffers, got 3 instead` —— 只能在**写端**解决

格式/打开都对之后的最后一道门：

```
I ExtCamDevSsn: configureStreams: request stream 1280x720
E ExtCamDevSsn: configureV4l2StreamLocked: VIDIOC_REQBUFS expected 4 buffers, got 3 instead
E ExtCamDevSsn: V4L configuration failed!, format:NV12, w 1280, h 720
E Camera3-Device: configureStreamsLocked: Unable to configure streams with HAL: Function not implemented (-38)
```

机理：`v4l2loopback` 的 buffer 队列是**设备级共享**的，先开的写端决定数量；
`gst v4l2sink` 只申请 **3** 个，后到的 HAL 要 4 个 ⇒ `vidioc_reqbufs()` 里
`if (has_other_owners() && used_buffer_count > 0) req_count = used_buffer_count;` 把它压到 3。

**试过两种驱动补丁，都失败（勿重复）**：
- 允许"请求更大"（`if (req_count < used) req_count = used;`）⇒ 两端数量不一致 ⇒ 写端拿到
  "没排队的 buffer" ⇒ 刷 `gstv4l2allocator.c: buffer N was not queued, this indicate a driver bug`
  并最终 **SIGSEGV**；
- 所有 owner 一律协商成 `dev->buffer_count` ⇒ 去掉共享分支后第二个 opener 直接 `EBUSY`；
  保留共享但抬下限到 4 ⇒ 写端仍按自己申请的 3 排 buffer，`got 3` 依旧。

**成功做法（stock 模块，零补丁）**：写端换成 `v4l2-ctl`，它可以显式给数量：

```sh
gst-launch-1.0 -q libcamerasrc camera-name=<CAM> ! videoconvert ! videoscale \
    ! video/x-raw,format=NV12,width=1280,height=720,framerate=30/1 ! fdsink fd=1 \
  | v4l2-ctl -d /dev/video100 --set-fmt-video-out=width=1280,height=720,pixelformat=NV12 \
      --stream-out-mmap=8 --stream-from=-
```

实测：**30.26–30.93 fps**、`not queued` 报错 **0**、`/dev/video100` = NV12 1280x720、
容器侧 `REQBUFS expected` 计数 **0**、`configureStreams` 通过、`start V4L2 streaming 1280x720@30fps`、
`StreamStateObserver: Preview stream state to STREAMING`、`Active Camera Clients` 见 App PID。
模块只需 `max_buffers=8`（≥ 两端要的数量）。

**部署脚本的坑**：`modprobe -r` 在模块仍被占用（生产者/容器开着设备）时会失败，而随后的
`modprobe` 是 no-op ⇒ 你以为换了新模块，实际还在跑旧的。`scripts/deploy-v4l2loopback.sh`
现在会在卸载失败时直接 FAIL 并打印占用者（实测已拦下一次静默失败）。

## #441 App 级停帧：框架侧一切正常，App 自己的分析器停了

成功配置之后（CameraX 日志齐全）：

```
D CameraStateMachine: New public camera state CameraState{type=OPEN, error=null}
D UseCaseAttachState: All use case: [id0-…, ey0-…]   # preview + analyze
D CaptureSession: CameraCaptureSession.onConfigured() mState=OPENED
D CaptureSession: CameraCaptureSession.onReady() OPENED
dumpsys media.camera: Device status: ACTIVE / Frames produced: 12 / Active Camera Clients: [PID … binaryeye]
```

但 `logcat | grep -c threadLoop` 在 **97 帧（≈3 s）后不再增长**，界面停在 App 自己的加载遮罩。
⇒ 不是 HAL/驱动的问题（HAL 在等 App 发新 request）；是 App 侧（Binary Eye 的 CameraX
analyze 用例）不再 request/consume。

**历史纠正**：之前把"生产者 SIGSEGV"当成独立缺陷，实际那是 #440 里"两端 buffer 数量不一致"补丁的副作用；
换成写端 `v4l2-ctl --stream-out-mmap=8` 后生产者连续跑 >120 s 无崩溃（`gst` 只抓帧 + fdsink）。
⇒ **`v4l2loopback` 保持 stock，不要打 buffer 数量补丁**。

**剩余待查**：97 帧后停 request 的原因（App 分析器阻塞 / YUV→NV12 CPU 拷贝太慢不够喂 30 fps /
Waydroid 的 `IMPLEMENTATION_DEFINED` 路径问题）。可用对照：换成只做 preview 的最小 App、
或抓 `dumpsys media.camera -v 1` 的 per-stream frame 计数看是"没 request"还是"request 了没出帧"。

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
