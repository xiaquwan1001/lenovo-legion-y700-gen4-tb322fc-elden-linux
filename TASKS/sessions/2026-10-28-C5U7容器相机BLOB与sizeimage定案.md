# 2026-10-28 · C5/U7 容器相机第二轮：`metadata 为空` 被推翻，真卡点两级

- **主题**：用户「允许」后按顺序做 ② C5/U7（容器相机 App 预览）。
- **性质**：有设备写（容器重启、`modprobe/rmmod v4l2loopback`、相机栈 on/off），**未刷写、未重启整机**。
- **设备终态**：CAM-OFF、`v4l2loopback` 已卸、`/dev/video100` 不存在、容器停、`dpms=On`、blank idle=300。

## 数字结论

| 项 | 结果 |
|---|---|
| 上一版「external HAL static metadata 为空」 | ❌ **推翻**：`dumpsys media.camera` 显示 **55/55 entries, 768 bytes**；`metadata is null` 是 disconnect 后噪声 |
| 真卡点一：BLOB 输出流 | NV12 源 `availableStreamConfigurations` = 8 项/**格式 33(JPEG) 缺席** ⇒ `no picture sizes returned by getOutputSizes`；**MJPG 源 = 12 项，出现 `[33 1280 720 OUTPUT]`** |
| 真卡点二：`sizeimage` 超限 | loopback `.depth=32` ⇒ MJPEG `sizeimage=w*h*4=3686400`；HAL `kMaxBytesPerPixel=2` ⇒ 上限 `1843200` ⇒ `configureStreamsLocked` **-38** |
| 修复 | `depth 32→16` ⇒ `sizeimage=1843200`（`patches/extmod/0002-*`，deploy 脚本幂等打） |
| 上机验证 | `v4l2-ctl --get-fmt-video` → **`Size Image = 1843200`**；App 走到 `configureStreams` **通过**、`start V4L2 streaming` 成功 |
| 剩余（未收口） | `Convert V4L2 frame to YU12 failed! res 1` 刷屏 = `v4l2-ctl --stream-from` 按**固定 sizeimage** 切**变长 MJPEG**帧 ⇒ 写端须按真实 `bytesused` 逐帧提交 |

## 源码级证据

- HAL：`dl-cam/hw-interfaces/camera/device/3.4/default/include/ext_device_v3_4_impl/ExternalCameraDeviceSession.h:112`
  `static const uint32_t kMaxBytesPerPixel = 2;`
- HAL：`ExternalCameraDeviceSession.cpp:2094-2095`
  `expectedMaxBufferSize = kMaxBytesPerPixel * w * h; if (bufferSize==0 || bufferSize>expectedMaxBufferSize) return -EINVAL;`
- loopback：`v4l2loopback_formats.h` MJPEG/JPEG `.depth = 32`；`v4l2loopback.c:pix_format_set_size()`
  压缩格式 `f->sizeimage = (width*height*fmt->depth) >> 3`。

## 操作坑（PITFALLS #460）

1. 换 v4l2loopback 后**必须重启容器**：LXC `create=file` bind 指旧 inode（权限还是 `c---------`）⇒ HAL `open failed -32` / `input format list is empty`。
2. `lxc-stop -k` 常不生效（`lxc-ls` 仍 RUNNING）⇒ `kill -9 $(pgrep -f "lxc-start.*waydroid")`。
3. 容器 **FROZEN** 时 `lxc-attach`/`dumpsys`/`logcat` 会**挂死**（非命令慢）⇒ 先 `lxc-unfreeze`。
4. `v4l2-ctl --get-fmt-video` 在写端独占时返回空/`Invalid argument` ≠ 模块没加载。
5. `deploy-v4l2loopback.sh` 引用的 `patches/extmod/0001-*` 仓里本来不存在（改动只在 gitignore 的 `build/extmod/`）⇒ 已补回。

## 产物

- `patches/extmod/0001-v4l2loopback-min-4-buffers.patch`（补入库）
- `patches/extmod/0002-v4l2loopback-mjpeg-sizeimage-2bytes.patch`（新）
- `scripts/deploy-v4l2loopback.sh`（两枚补丁幂等）
- `reports/c5-u7-container-camera-20261028.md` §7–§11
- `PITFALLS/README.md` #460 + `PITFALLS/sessions/124-*.md`

## 下一步

写端按真实 `bytesused` 逐帧提交 MJPEG：
(a) `v4l2-ctl --set-fmt-video-out` 预置格式后改用 `gst ! v4l2sink`（本轮 v4l2sink 未发布格式，需先预置，未验证）；
(b) 自写写端（`VIDIOC_QBUF` 逐帧 `bytesused`），成本高但可控。
