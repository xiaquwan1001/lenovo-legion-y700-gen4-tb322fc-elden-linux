# #460 容器相机「BLOB 缺失 + v4l2loopback sizeimage 超 HAL 上限」两坑

## 结论（2026-10-28 实机取证）

- `metadata is null` 是噪声，不是根因。`dumpsys media.camera` 里 static metadata 满 55 项；
   该错误出现在 `Camera2ClientBase: start to disconnect` **之后**，属关闭路径次生错误。
   ⇒ 上一版「external HAL static metadata 为空」的结论**作废**。
- 真卡点一：HAL 只在 MJPEG 源下广告 JPEG(BLOB)。
   - NV12 源 ⇒ `availableStreamConfigurations` 只有 8 项 / 2 条流（格式 35=YUV_420_888、34=IMPLEMENTATION_DEFINED），
     **格式 33=JPEG 缺席** ⇒ OpenCamera `no picture sizes returned by getOutputSizes` ⇒ 初始化即退出。
   - MJPG 源 ⇒ 12 项 / 3 条流，**多出 `[33 1280 720 OUTPUT]`**。
   - 判据顺序：先看 `dumpsys media.camera` 的 `availableStreamConfigurations` 有没有 `33`，再看 App。
- 真卡点二（新）：v4l2loopback 的 MJPEG `sizeimage` 违反 Android HAL 上限。
   - HAL 源码（本仓 `dl-cam/hw-interfaces/camera/device/3.4/default/`）：
     `ExternalCameraDeviceSession.h:112` `kMaxBytesPerPixel = 2`；
     `ExternalCameraDeviceSession.cpp:2094-2095` `expectedMaxBufferSize = 2*w*h`，超了 `return -EINVAL`。
   - v4l2loopback `v4l2loopback_formats.h` 里 MJPEG/JPEG 是 `.depth = 32`，
     压缩格式 `sizeimage = (w*h*depth)>>3 = w*h*4` = 3686400（720p），**超上限一倍**。
   - 现象：`configureV4l2StreamLocked: V4L2 buffer size: 3686400 looks invalid. Expected maximum size: 1843200`
     → `configureStreamsLocked: Unable to configure streams with HAL: Function not implemented (-38)`。
   - **修法**：`depth 32 → 16` ⇒ `sizeimage = w*h*2 = 1843200`。补丁 `patches/extmod/0002-*.patch`。

## 剩余（未收口）

`sizeimage` 修好后 `configureStreams` 通过、`start V4L2 streaming` 成功，但
`Convert V4L2 frame to YU12 failed! res 1` 刷屏 —— 因为 `v4l2-ctl --stream-from=-` **按固定 sizeimage 切分**
输入流，而 MJPEG 帧是**变长**的 ⇒ 帧边界错乱，libyuv 必失败。
⇒ 写端必须按真实 `bytesused` 逐帧提交（`v4l2sink` 需先预置格式；或自写写端）。

## 操作坑（本轮新增）

- **换 v4l2loopback 模块后必须重启容器**：LXC `create=file` 的 bind 指向**旧 inode**，
  旧节点权限还是 `c---------`（0 权限）⇒ HAL `open /dev/video100 failed (-32)` 或 `input format list is empty`。
  `lxc-stop -k` 有时不生效（`lxc-ls` 仍 RUNNING）⇒ 需 `kill -9 $(pgrep -f "lxc-start.*waydroid")` 再起。
- **容器 FROZEN 时 `lxc-attach`/`dumpsys`/`logcat` 会挂死**（不是命令慢）：先 `lxc-unfreeze`，或起会触发解冻的前台会话。
- `v4l2-ctl --get-fmt-video` 在**写端独占**（`exclusive_caps=1` 且 producer 在跑）时返回空/`Invalid argument`，
  这**不代表模块没加载**，别误判。
- `deploy-v4l2loopback.sh` 原先引用的 `patches/extmod/0001-…` 在仓里根本不存在（改动只在 gitignore 的 `build/extmod/` 里）
  ⇒ 已补回 0001 并把两枚补丁都做成幂等打补丁。
