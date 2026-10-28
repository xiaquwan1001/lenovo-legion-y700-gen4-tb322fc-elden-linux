# mjpgfeed — 变长 MJPEG 帧喂给 v4l2loopback

## 为什么

`v4l2-ctl --stream-from=-` 按**固定 `sizeimage`** 切分输入流。MJPEG 是**变长**帧
（720p 真实帧 ≈ 85 KB，而 `sizeimage` = 1 843 200），因此帧边界必然错乱 ⇒
Android external camera HAL 报 `Convert V4L2 frame to YU12 failed! res 1`。

`v4l2-ctl --stream-from-hdr` **不能**用：它的头是 `struct fwht_cframe_hdr`
（FWHT 专用；见 v4l-utils `utils/v4l2-ctl/v4l2-ctl-streaming.cpp:read_fwht_frame()`）。

## 用法

```sh
# 设备上（静态 aarch64 二进制）
gst-launch-1.0 -q libcamerasrc camera-name='<entity>' \
  ! videoconvert ! video/x-raw,format=NV12,width=1280,height=720,framerate=30/1 \
  ! jpegenc ! fdsink fd=1 | ./mjpgfeed /dev/video100 1280 720
```

## 构建

```sh
aarch64-linux-gnu-gcc -O2 -static -o mjpgfeed mjpgfeed.c
```

## 实现要点

- `VIDIOC_S_FMT` 定 MJPG + 目标宽高；`VIDIOC_REQBUFS` 8 个 mmap buffer；全部 `QBUF` 后 `STREAMON`。
- 主循环：从 stdin 按 **SOI `FFD8` / EOI `FFD9`** 切帧 → `select()` 等可写 → `DQBUF`
  → `memcpy` 真实帧 → `QBUF(bytesused = 真实帧长)`。
- 帧超 `sizeimage` 时截断并计入 `dropped`（正常不会发生）。
- 每 30 帧打印 `frames=/dropped=/last=` 进度到 stderr。

## 相关

- 配套内核侧修复：`patches/extmod/0002-v4l2loopback-mjpeg-sizeimage-2bytes.patch`
  （v4l2loopback 压缩格式 `.depth` 32 → 16，否则 `sizeimage = w*h*4` 超 Android HAL 的
  `kMaxBytesPerPixel = 2` 上限）。
- 背景与取证：`reports/c5-u7-container-camera-20261028.md` §7–§15、`PITFALLS #460`。
