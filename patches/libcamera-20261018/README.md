# 设备上自编 libcamera 0.7.1（排查/修复软 ISP 黑帧）— 2026-10-18

> 结论请看 `reports/camera-linux-vk127-20261018.md` §7 与 `PITFALLS` §45（#322）。
> **一句话**：系统里 Alpine 的 `libcamera` 包（启用 libcrypto / IPA 签名 / 进程内 IPA）在这台机器上会让软 ISP
> 输出**第 1 帧之后全黑**；用**同一份 0.7.1 源码、但 meson 找不到 libcrypto（IPA 走隔离）**构建出来的库，
> 两摄都能出真实图像（AE 需要几帧爬升，后摄前 2 帧允许是 0）。

## 文件

| 文件 | 说明 |
|---|---|
| `0001-elden-probe-debayer-output.patch` | 在 `DebayerEGL::process()` 里加 PROBE：`glFinish()` 之后**直接 CPU 回读输出 dma-buf**（打印 `frame/outfd/offset/len/meanB`）。这是判定「ISP 有没有写」的金标准 |
| `build-on-device.sh` | 设备侧重编 + 安装脚本（**先 `apk del openssl-dev`**，否则 meson 会启用 libcrypto → 黑帧） |

## 复现（在设备上，root）

```sh
# 1) 取源码（0.7.1，与系统同版本）并解包
curl -sLo /root/lc.tar.gz https://github.com/libcamera-org/libcamera/archive/refs/tags/v0.7.1.tar.gz   # 需要网络（或用主机 scp）
tar -C /root -xzf /root/lc.tar.gz

# 2) 关键：让 meson 找不到 libcrypto（IPA 隔离）——这是「出图」的必要条件
apk del openssl-dev        # 只删 dev 头，不动运行时 libcrypto3/libssl3

# 3) 构建 + 安装到 /usr（会覆盖 Alpine 包文件；先备份！）
cd /root/libcamera-0.7.1
meson setup build -Dpipelines=simple -Dipas=simple -Dcam=enabled \
  -Dgstreamer=disabled -Dpycamera=disabled -Dtest=false -Ddocumentation=disabled -Dprefix=/usr
ninja -C build -j4 && ninja -C build install && ldconfig
```

备份（本次现场留下）：
- Alpine 原版：`/root/lc-bak-20261018/`（`libcamera.so.0.7.1`、`libcamera-base.so.0.7.1`、`ipa_soft_simple.so.installed`）
- 我们的 libcrypto 版（**黑帧**，留作对照）：`/root/lc-ours-20261018/`

## 验收

```sh
cam -c1 -C12 --file='/tmp/f_#.bin'
# 用 python 逐帧算帧首 mean：后摄 15.9, 0, 0, 37.6, 37.6, …（前 2 帧 AE 未生效）
# 前摄 21 → 35 → 44 → 67 …（AE 爬升）；全 0 ⇒ 又踩回黑帧构建
```
