# C5/U7 容器相机：从「需装 APK」推进到「HAL 静态元数据为空」——真卡点换人（2026-10-28）

> 触发：`继续任务` 按顺序的第 3 项（C5/U7 容器相机 App 预览）。原口径「剩 App 侧停帧，需装 APK」。
> 性质：**有设备写**（容器重启、`modprobe/rmmod v4l2loopback`、`/usr/local/sbin/cam-mode.sh` 替换），**未刷写、未重启整机**。
> 收尾已把设备恢复日常态：CAM-OFF（相机模块 0）、`v4l2loopback` 已卸、`dpms=On`、seat0 会话 `c1`、失败单元 0。

## §0 结论（数字）

> ⚠️ **本节「metadata 为空」的结论已于同日第二轮被推翻**，权威结论见文末 **§7–§11**。

| 项 | 结果 |
|---|---|
| 是否需要装 APK | ❌ **不需要**：镜像里已有 `net.sourceforge.opencamera`（OpenCamera）与 `com.google.android.apps.googlecamera.fishfood` |
| 之前 `Number of camera devices: 0` 的真因 | **容器启动时主机没有 `/dev/video100`**，LXC 的 `create=file` bind 于是造了一个 **0 字节普通文件**（`----------`，不是字符设备）⇒ 容器里永远看不到相机；之后 `modprobe v4l2loopback` 也不会自愈，**必须重启容器** |
| 修好后 | `Number of camera devices: 1`；external provider `@2.4` 枚举出 `1280x720@30` |
| 三种像素格式 | NV12 → `initOutputCharsKeys: format NV12 is not supported!`；YUYV → `not supported!` + `advertising YUV streams for YUYV`（兜底分支）；**MJPG → 正常枚举、零告警** |
| App 行为（三格式都一样） | OpenCamera `Camera 200: Opened` 后**立刻 disconnect**，伴随 `E/camera_metadata: validate_camera_metadata_structure: metadata is null!` + `E/Camera2-Metadata: acquire: Failed to validate metadata structure 0x0` ⇒ **cameraserver 拿到的 static metadata 是空的** |
| ⇒ 真卡点（**★已被 §7 推翻，见下**） | ~~`getCameraCharacteristics` 返回空 metadata~~ → 实为 **BLOB 缺失 + v4l2loopback `sizeimage` 超 HAL 上限** |

## §1 复现链（可复跑）

```sh
# 1) 主机侧：造出 loopback 节点（buffers/格式按 scripts/cam-loopback.sh 头注释）
modprobe v4l2loopback video_nr=100 max_buffers=8 exclusive_caps=1
bash scripts/cam-loopback.sh start front 1280x720 30      # libcamerasrc → v4l2-ctl --stream-out-mmap=8
#    → 30.2 fps，`v4l2-ctl -d /dev/video100 --get-fmt-video` 显示 1280x720 NV12

# 2) 容器侧：**必须重启容器**才吃到新节点（见坑 1）
setsid nohup runuser -u <会话用户> -- env XDG_RUNTIME_DIR=/run/user/<uid> WAYLAND_DISPLAY=wayland-0 \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<uid>/bus waydroid session start &

# 3) 容器内取证（`waydroid shell` 传不了 `sh -c`，见坑 2）
lxc-attach -P /var/lib/waydroid/lxc -n waydroid -e -- /system/bin/sh -c 'dumpsys media.camera | grep -m1 Number'
lxc-attach ... -c 'logcat -d -v brief -s CamPrvdr@2.4-external:*'      # 枚举过程
lxc-attach ... -c 'am start -n net.sourceforge.opencamera/.MainActivity'
lxc-attach ... -c 'logcat -d -v brief' | grep -E 'Camera2-Metadata|Opened|disconnect'
```

## §2 三种格式的 HAL 行为（逐字日志）

| 生产者格式 | HAL 日志 | 结论 |
|---|---|---|
| NV12 | `W/ExtCamDev@3.4: initOutputCharsKeys: format NV12 is not supported!` | 该 HAL 的格式映射表**不含 NV12**（与 `cam-loopback.sh` 头注释「必须 NV12」的旧结论冲突，见 §4） |
| YUYV | `… format YUYV is not supported!` + `I/…: advertising YUV streams for YUYV` | 走 YUV **兜底**分支 |
| MJPG | 无告警，正常枚举 | 唯一「干净」分支 |

三种格式下 App 的结局相同（`metadata is null`）⇒ 换格式**不能**解决 C5/U7。

## §3 顺带修掉的两个真实缺陷（`scripts/cam-mode.sh`）

| 缺陷 | 后果 | 修法 |
|---|---|---|
| 会话用户写死 `uid 1000` / `xuqianhui1001` | Alpine 根是 `1000/xuqianhui`，**Debian 根是 `1001/xuqianhui1001`** ⇒ `find_bus` 永远空 | 现查：`loginctl list-sessions` 的 seat0 用户 + `id -u` |
| 提权工具写死 `sudo -u` | **Debian 根没有 `sudo`**（`command not found`）⇒ `GS()` 把 stderr 吞掉后只看 stdout ⇒ **blank 守卫静默变空操作**，而 status 照常打印 CAM-ON/CAM-OFF | 按可用性选 `sudo` / `runuser`，都没有则**明确报错**（守卫不静默） |

修前 `cam-mode.sh status`：`idle-delay = `（空）；修后：`idle-delay = uint32 300`。脚本已同步到设备。

## §4 旧结论更正

`scripts/cam-loopback.sh` 头注释写「★格式必须是 **NV12**：Android 的 external camera HAL 只把 NV12 映射成 YCbCr_420_888；YUYV 走兜底分支 ⇒ `generated preview size list is empty` ⇒ 相机打不开」。
本轮实测：**在本镜像（2026-10-19 构建，`camera.device@3.4-external-impl.so`）的 HAL 里 NV12 才是"不支持"的那个**，MJPG 枚举最干净。
⇒ 该注释的格式结论**与当前镜像不符**，下次动 loopback 前先按 §2 的方法重新测一遍，不要照抄。

## §5 下一步（C5/U7 真卡点的最短路径）

1. **打印缺失键**：用 AOSP `external camera HAL` 源码对照本镜像版本（`/vendor/lib64/hw/camera.device@3.4-external-impl.so`，2026-10-19），
   确认 `getCameraCharacteristics` 返回空是「某个必需键缺失」还是「HAL 直接回错误」。
2. **换 provider 版本**：镜像内同时有 `camera.provider@2.5-external.so`，但 `/vendor/bin/hw/` 只有 **2.4** 的 service 二进制、init rc 也只声明 2.4
   ⇒ 要么补 2.5 的 service，要么回退到镜像自带的 2.4 已知好组合（需确认 T22 当时那版镜像的行为）。
3. 备选：把 `ANDROID_SENSOR_INFO_*` / `SCALER_AVAILABLE_STREAM_CONFIGURATIONS` 通过 HAL 的 `--camera-id-list`/配置文件补进去（需先知道 HAL 支持的注入方式）。
4. 记住**顺序**：先确认 `Number of camera devices`，再看 `Camera2-Metadata`，最后才看 App —— 三者混在一起会误判成「App 停帧」。

## §6 产物

- 本报告；`scripts/cam-mode.sh`（会话用户/提权工具现查）；设备侧脚本已同步。
- 证据链日志：本轮 `logcat` 关键行已逐字引在 §2/§0（未落盘成文件；复跑命令见 §1）。

---

# 追加：C5/U7 第二轮（2026-10-28 下午）—— **真卡点再次换人，且已修到「只差写端帧切分」**

> 上一版（同日早间）结论「external HAL static metadata 为空」**被本轮推翻**。
> 实测 static metadata 是**满的（55 项）**，`metadata is null` 只是 disconnect 时的**症状噪声**，
> 真卡点是 **JPEG(BLOB) 输出流缺失**，根因落在 **v4l2loopback 的 `sizeimage` 计算**。

## §7 三轮定位（每轮都被真机日志推翻一次假设）

### 轮 1：metadata「为空」是误判

`dumpsys media.camera` 的 `Camera HAL device device@3.4/external/200` 段显示
**`Dumping camera metadata array: 55 / 55 entries, 768 / 768 bytes of extra data`**，键值齐全
（`info.supportedHardwareLevel=EXTERNAL`、`scaler.availableStreamConfigurations`、`jpeg.maxSize` 全在）。
⇒ 「static metadata 为空」不成立；`E/camera_metadata: metadata is null` 出现在
`Camera2ClientBase: start to disconnect` **之后**，是关闭路径的次生错误。

### 轮 2：真正的第一道门 = **没有 JPEG/BLOB 输出流**

NV12 源时的 `availableStreamConfigurations`：**8 项 / 只有 2 条流**
（`[35 w h OUTPUT]` = YUV_420_888、`[34 ...]` = IMPLEMENTATION_DEFINED），**格式 33（JPEG）缺席**。
OpenCamera 走 `CameraController2`，`E/CameraController2: no picture sizes returned by getOutputSizes`
⇒ 拿不到拍照尺寸 ⇒ 初始化即退出。

**换成 MJPG 源后**（`gst ... ! jpegenc ! v4l2-ctl --set-fmt-video-out=pixelformat=MJPG`）：
`availableStreamConfigurations` 变成 **12 项 / 3 条流**，多出 **`[33 1280 720 OUTPUT]`（JPEG）**。
⇒ 第一道门 = **源必须是 MJPEG**（HAL 只在压缩源下广告 BLOB），与 PITFALLS #438 一致。

### 轮 3：真卡点 = v4l2loopback 的 MJPEG `sizeimage` 违反 HAL 上限

源换成 MJPEG 后 App 能走到 `configureStreams`，但：

```
I/ExtCamDevSsn@3.4: configureV4l2StreamLocked: V4L2 buffer size is 3686400
E/ExtCamDevSsn@3.4: ... V4L2 buffer size: 3686400 looks invalid. Expected maximum size: 1843200
E/ExtCamDevSsn@3.4: V4L configuration failed!, format:MJPG, w 1280, h 720
E/Camera3-Device: Camera 200: configureStreamsLocked: Unable to configure streams with HAL: Function not implemented (-38)
```

**3686400 = 1280×720×4**，而 HAL 上限 `1843200 = 1280×720×2`。

源码级取证（本仓 `dl-cam/hw-interfaces/camera/device/3.4/default/`）：
- `ExternalCameraDeviceSession.h:112` → `static const uint32_t kMaxBytesPerPixel = 2;`
- `ExternalCameraDeviceSession.cpp:2094` → `expectedMaxBufferSize = kMaxBytesPerPixel * w * h`
- `:2095` → `if (bufferSize == 0 || bufferSize > expectedMaxBufferSize) return -EINVAL;`

而 `v4l2loopback` 侧（`v4l2loopback_formats.h`）MJPEG/JPEG 条目写的是 **`.depth = 32`**，
压缩格式（`FORMAT_FLAGS_COMPRESSED`）的 `sizeimage = (w * h * depth) >> 3 = w*h*4`
（`v4l2loopback.c:pix_format_set_size()`）⇒ 必然超上限 2 倍。

**修法** = `depth` 32 → **16** ⇒ `sizeimage = w*h*2 = 1843200`（正好等于 HAL 上限，远大于真实 720p JPEG 帧）。

## §8 修复落地

| 项 | 内容 |
|---|---|
| 补丁 | `patches/extmod/0002-v4l2loopback-mjpeg-sizeimage-2bytes.patch`（MJPEG + JFIF JPEG 两条 `depth = 32 → 16`，带成因注释） |
| 部署脚本 | `scripts/deploy-v4l2loopback.sh` 增 `$PATCH2`，幂等打补丁（`grep -q "depth = 16,"` 判已打） |
| 同时补回 | `patches/extmod/0001-v4l2loopback-min-4-buffers.patch`（此前只在 build/ 里未入库，脚本引用的路径本来不存在） |
| 设备实测 | 重编 `v4l2loopback.ko`（vermagic 逐字 `…-debug-vk172`）→ 加载 → `v4l2-ctl --get-fmt-video` **`Size Image = 1843200`** ✅ |

## §9 修完之后的下一道门（尚未解决，已定位）

修好后 `configureStreams` **通过**，`start V4L2 streaming` 也成功，App 不再因 BLOB 缺失退出；
但出流阶段报：

```
E/ExtCamDevSsn@3.4: threadLoop: Convert V4L2 frame to YU12 failed! res 1   （连续刷屏）
```

成因（已确认，非推测）：`v4l2-ctl --stream-from=-` **按固定 `sizeimage`**（现 1843200）切分输入流，
而 MJPEG 是**变长**帧（真实 720p JPEG 每帧远小于 1843200）⇒ 帧边界被打乱，
libyuv 解码必然失败。

⇒ 正确做法是用**能按真实 `bytesused` 逐帧写**的写端。两条候选：
1. `gst ... ! v4l2sink device=/dev/video100` —— 本轮试了，但它没有把 format 发布到设备
   （`v4l2-ctl --get-fmt-video` 返回空、HAL 枚举到 `trimSupportedFormats: input format list is empty!`），
   需先 `v4l2-ctl --set-fmt-video-out` 预置格式再让 v4l2sink 沿用，未验证。
2. 自写写端（按 `VIDIOC_QBUF` 逐帧 `bytesused` 提交），可控但成本高。

**结论口径**：C5/U7 = **未收口**。已推进两级真卡点（BLOB 缺失 → 已解；`sizeimage` 超限 → 已修并上机确认），
剩余 = **写端必须做变长 MJPEG 帧切分**。

## §10 设备终态

- `v4l2loopback` 已卸载、`/dev/video100` 不存在；`cam-mode.sh off`（相机模块 0、media 0、blank idle=300、`dpms=On`）。
- 容器已停（`lxc-stop`），无残留 `provider@2.4-external` 进程占用设备。
- 遗留：`system_heap` 常驻（正常）。

## §11 产物

- `patches/extmod/0001-v4l2loopback-min-4-buffers.patch`（补入库）
- `patches/extmod/0002-v4l2loopback-mjpeg-sizeimage-2bytes.patch`（**本轮新**）
- `scripts/deploy-v4l2loopback.sh`（两枚补丁幂等打）
- 本报告 §7–§10


---

# 追加二：写端变长 MJPEG 逐帧提交 —— **相机链路已打通**（2026-10-28 傍晚）

> 承接 §9「剩余 = 写端必须做变长 MJPEG 帧切分」。

## §12 结论（数字）

| 项 | 结果 |
|---|---|
| `v4l2-ctl --stream-from-hdr` 能否用 | ❌ **不能**：源码核对（`v4l-utils` `v4l2-ctl-streaming.cpp:read_fwht_frame()`）该头是 **`struct fwht_cframe_hdr`**（FWHT 专用，magic/version/colorspace 等 44 B），与 MJPEG 无关 |
| 正解 | 自写写端 `mjpgfeed`：从 stdin 按 **SOI(`FFD8`)/EOI(`FFD9`)** 切帧，`VIDIOC_QBUF` 时 `bytesused = 真实帧长` |
| 实测 | `frames=390+ dropped=0 last≈84.9 KB`（连续稳定，30 fps 生产者）；`v4l2-ctl --get-fmt-video` = `MJPG 1280x720 Size Image 1843200` |
| 容器侧 | `configureV4l2StreamLocked: start V4L2 streaming 1280x720@30.000000fps` ✅；**`Convert V4L2 frame to YU12 failed` 完全消失**（§9 的最后一门已过） |
| App 侧 | OpenCamera 打开相机、`Camera 200: Opened`、configureStreams 全通过；随后**崩在 `libhwui.so` RenderThread**（见 §13），**与相机无关** |

## §13 App 崩溃 = 容器 GPU/ANGLE 问题（新卡点，与本任务无关）

```
F/DEBUG: name: RenderThread >>> net.sourceforge.opencamera
F/DEBUG: signal 0 (SIGSEGV), code 1 (SEGV_MAPERR)
  #00 pc .../libhwui.so (__aarch64_ldadd4_acq_rel+16)
  #01 pc .../libhwui.so (GrBackendTexture::~GrBackendTexture()+56)
  #02 pc .../libhwui.so (AutoBackendTextureRelease::unref(bool)+220)
  #03 pc .../libhwui.so (SkImage::MakeFromTexture(...)+812)
```

即 **GrBackendTexture 析构时野指针**（`fault addr --------`、`ldadd4` 命中已释放对象），
属容器内 **HWUI + Adreno/ANGLE** 的组合问题（`E/OpenGLRenderer: Device claims wide gamut support,
cannot find matching config` 是同一族的先兆）。**相机栈侧没有任何错误**。

⇒ **C5/U7 的相机部分到此为止**：从「0 台相机」一路推到「预览流真的跑起来」，
剩余阻塞换成了**容器 GPU 渲染稳定性**（独立课题，属 G2 容器图形线，不在相机线）。

## §14 写端工具（产物）

`mjpgfeed`（本轮新写，C 静态 aarch64）：

```
gst ... ! jpegenc ! fdsink fd=1 | mjpgfeed /dev/video100 1280 720
```

- 源码要点：先 `VIDIOC_S_FMT` 定 MJPG + `VIDIOC_REQBUFS` 8 缓冲，全部 `QBUF` 后 `STREAMON`；
  主循环 `select(DQBUF)` → `memcpy` 真实帧 → `QBUF(bytesused=真实长度)`；
  帧超 `sizeimage` 时截断并计 `dropped`；每 30 帧打印进度。
- **未入库**（`/tmp/mjpgfeed`，源码 `/tmp/mjpgfeed.c`）—— 若要长期用，建议落到 `scripts/` 或 `tools/`。

## §15 操作坑补充（承接 §7 的坑列表）

- 容器**反复自动 FROZEN**（无窗口客户端时 Waydroid 省电）⇒ `lxc-attach` 会**静默挂死**；
  本次每次取证前都要先 `lxc-unfreeze -P /var/lib/waydroid/lxc -n waydroid`。
- **`lxc-stop -k` 常常不生效**（`lxc-ls` 仍 RUNNING）；可靠路径 = `kill -9 $(pgrep -f "lxc-start.*waydroid")`，
  再 `kill -9 $(pgrep -f "waydroid containe[r]")`（**这个 python 服务进程会残留并占住 dbus 名**）。
- `lxc.hook.post-stop = /dev/null` 在 stop 时会报 `exec: /dev/null: Permission denied` +
  `Failed to run lxc.hook.post-stop`，但**不影响启动**（是 stop 路径的噪声，别当成启动失败）。
- 容器内 `/dev/video100` 的 inode 是**容器启动时 bind 的快照**；主机重新 `modprobe` 后
  **必须让容器真正重启**（不是 freeze/unfreeze），否则仍是旧的 `c---------` 0 权限节点。

---

# 追加三：Binary Eye 实测 —— 相机链路对 App **可用**，卡点 = HAL 的 YU12 转换缓冲（2026-10-28 晚）

> 目的：绕开 OpenCamera 崩在 `libhwui.so` 的那条路，用 preview+analyze 类 App 证明相机链路可用。

## §16 结果（数字）

| 项 | 结果 |
|---|---|
| Binary Eye 是否已装 | ✅ 已在（`de.markusfisch.android.binaryeye`，`~/.local/share/waydroid/data/app/…`）；启动 Activity 是 **`.activity.SplashActivity`**（不是 `MainActivity`） |
| 相机链路 | ✅ `Camera 200: Opened` → `configureStreams` → **`configureV4l2StreamLocked: start V4L2 streaming 1280x720@30.000000fps`** |
| **真跑了帧** | ✅ `ProcessCaptureRequest latency histogram **(7) samples**`、`Stream 0 dequeueBuffer latency histogram (8) samples` ⇒ **确实产出了 7 个请求的帧** |
| 崩溃 | provider 进程 `android.hardware.camera.provider@2.4-external-service` **SIGSEGV**（`cameraserver: Camera provider 'external/0-0' has died; removing it`） |
| 崩溃线程/栈 | `ExtCamOut` → `libyuv.so CopyRow_NEON+8` ← `CopyPlane` ← **`I420Copy`** ← **`camera.device@3.4-external-impl.so formatConvert()`+244** ← `OutputThread::threadLoop()`+2212 |

## §17 根因（源码级）

`formatConvert()`（`dl-cam/hw-interfaces/camera/device/3.4/default/ExternalCameraUtils.cpp:303`）走
`V4L2_PIX_FMT_YUV420 → libyuv::I420Copy(in.y/in.cb/in.cr → out.y/out.cb/out.cr, sz)`
（`ExternalCameraDeviceSession.cpp:1652`）。`out` 来自 `sHandleImporter.lockYCbCr()`（gralloc 输出缓冲），
`in` 来自 `cropAndScaleLocked(mYu12Frame, …)`。

`CopyRow_NEON` 的 `SEGV_ACCERR`（fault addr `--------`）说明 **`out.cb`/`out.cr` 一侧地址不可写**：
即 gralloc 输出的 `YCbCrLayout`（`cStride`/`chromaStep`）与 HAL 假设的 I420 平面布局不一致 ——
**容器内 gralloc mapper 的 `lockYCbCr` 与 HAL 3.4 期望不匹配**（本镜像 2026-10-19 版）。

⇒ **与相机链路（camss→libcamera→gst→loopback→HAL 输入侧）无关**，是 **HAL 输出侧 + 容器 gralloc** 的问题。

## §18 结论

- **相机链路对 App 可用**：Binary Eye 拿到了 `STREAMING`、真产出 7 帧（latency histogram 有样本）。
  这与 OpenCamera 的表现一致（它也是 configureStreams 全过后才崩）。
- 现在阻塞 App 预览的两个崩溃**都不在相机线**：
  1. **OpenCamera** → `libhwui.so` `GrBackendTexture` 析构（容器 GPU / HWUI+Adreno）
  2. **Binary Eye / 任何走 YUV 输出的 App** → HAL `formatConvert` `I420Copy` 写输出 gralloc 缓冲时 `SEGV_ACCERR`
     （容器 gralloc `lockYCbCr` 布局不符）
- 两者的共同点：**相机已经出帧了，死在「把帧交给 Android 图形层」这一步**。

## §19 下一步（若要继续，属容器图形/gralloc 线）

1. 抓 `dumpsys media.camera` 里的 `Active Camera Clients` 与 `android.hardware.camera.provider` 的 gralloc 请求，
   核对 `cStride` / `chromaStep`（HAL 打印 `outLayout y/cb/cr/ystride/cstride/cstep` 的那行 ALOGV 可开 `debug` 级别取）。
2. 试 **`YV12` 输出**（`PixelFormat::YV12` 走同一 `I420Copy`，但 gralloc 布局常不同）或让 App 只请求
   `PixelFormat::BLOB`（拍照路径，已验证 `configureStreams` 的 JPEG 流可用）。
3. 或在容器侧换 `gralloc` 实现（Waydroid 的 `libgralloc` 与 Android 版本要匹配）。

## §20 设备终态

CAM-OFF（模块 0 / media 0 / video 0）、`v4l2loopback` 卸、`/dev/video100` 无、容器停、`dpms=On`、blank idle=300。
