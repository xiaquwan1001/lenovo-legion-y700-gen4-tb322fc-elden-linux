# Waydroid 容器侧 camera provider：64-bit 自编 + 烘进 vendor.img（vk127，2026-10-18）

> 任务 = `TASKS/README.md` C5 ②（容器侧 camera provider）。主机 PC 交叉编译，设备只做装载与验证。
> 上一轮（2026-10-17 晚）结论「镜像里根本没有 camera HAL 二进制」由本报告闭环到「**有，且能注册，但首笔 binder 事务即 SIGSEGV**」。
> 会话：pi `01a14c64`（2026-10-18T00:23Z 起）。未解决项见 §5，坑见 `PITFALLS` §44（#306–#313）。

---

## 1. 基线（已写盘、已读回校验）

| 项 | 值 |
|---|---|
| 在机内核 | `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`（`uname -r`，设备实读） |
| `boot_b` | 写盘 img = `bootslot-b/boot_b.img`，`sha256 83d4e08add88abd2…`，100 663 296 B（96 MiB 分区满幅） |
| AVB | 自签 **SHA256_RSA4096**；`avbtool info_image` Public key sha1 = **`1e54e86ef19fad73…`**（旧链 `fc1e3b33…` 作废） |
| 冷起 | Q28 连续 **7 发坏**（`panel init attempt 2 failed: -5`）后第 8 发 **GOOD**；`Run /init` 后正常进 Phosh、SSH 可达 |
| 模块树 | `/lib/modules/7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty/`（1497 `.ko`）已在持久根，vermagic 与 `uname -r` 逐字相等 |

> 本机 **`avbtool.py` 与 `bootslot-b/avb.key` 上一轮已丢失**（换机未随迁），本轮重建：`tools/avbtool.py` + 新 key。
> 新 key 必须与 `vbmeta_b` 的 chain descriptor 同步（`scripts/sign-boot-b.sh`）；公钥 sha1 变了 ⇒ 只重签 boot 不重签 vbmeta 会被 ABL 拒。

---

## 2. 根因链：arm64 容器为什么「一个相机都没有」

1. **上游 AOSP 的 external camera HAL 只出 32 位**：`camera/device/3.x/default/Android.bp` 里 `compile_multilib: "32"`。
   Waydroid 在 arm64 上只跑 64-bit binder 进程（`cameraserver` 是 64-bit）⇒ 32-bit `-impl.so` 无法被加载。
2. **Waydroid 通用镜像不含 camera provider**：`/vendor/bin/hw`、`/vendor/lib64/hw`、`/system/bin/hw`、`/system/lib64` 全无 camera 项，
   `/vendor/etc/vintf/manifest.xml` 也无 camera 条目（上一轮已核）。⇒ 必须自带 provider 二进制 + `external_camera_config.xml` + vintf 条目。
3. **本机 v4l2loopback 只给 YUYV**：上游 external HAL 的 `kSupportedFourCCs` 只有 `MJPEG`（+ `Z16`），
   YUYV/NV12 在格式协商阶段就被跳过（详见 §4）。

---

## 3. 本轮做成的事

### 3.1 交叉编译 64-bit provider（PC 侧）

- 工具链：NDK **r25c** + AOSP prebuilt **`aidl`**（`--lang=ndk --structured --stability=vintf --min_sdk_version=33`）+ `hidl-gen`（`hidl-gen_10.0.0+r36-3.1build1_amd64.deb`）。
- 源码：`hw-interfaces`（AOSP `hardware/interfaces`，基点 `fa455d8` = tm-release cherrypick merge）+
  `camera/device/3.4`、`3.5`、`3.6` 的 external device/session。
- 产物（`dl-cam/out-cam/`）：
  - `android.hardware.camera.provider@2.4-external-service`（main，注册 `external/0`）
  - `android.hardware.camera.provider@2.{4,5}-external.so`
  - `camera.device@3.{4,5,6}-external-impl.so`
- 构建脚本已入库：`patches/waydroid-camera-64bit-20261018/build-cam-provider.sh`、`gen-headers.sh`、`external-fetch-shim.cpp`。

### 3.2 烘进 vendor.img（`scripts/waydroid-camera-bake.sh`）

- 原镜像 **100% 满**（496 inode / 只剩 14）⇒ `debugfs write` 报 `Could not allocate inode`。
  治法：`mke2fs -N 8192 -d stage` 重建 + `debugfs sif` 恢复 SELinux `0:2000`（脚本内已固化）。
- 新镜像 128 MiB，装入 `/vendor/bin/hw/…-service`、`/vendor/lib64/hw/*`、`/vendor/etc/init/*.rc`、
  `/vendor/etc/permissions/android.hardware.camera.external.xml`、`/vendor/etc/vintf/manifest.xml`（camera.provider 2.4+2.5 `external`）。
- 容器内 `CANNOT LINK` 一度出现：vendor namespace 看不见 `/system/lib64` ⇒ 把 camera/graphics 相关 HIDL 库一并放进 `/vendor/lib64`。

### 3.3 证据链（容器内 logcat，逐跳）

```
External camera provider service is starting.
loadFromCfg: load external camera config succeed!
adding /dev/video100 to External Camera HAL!
advertising YUV streams for YUYV
Registration complete for android.hardware.camera.provider@2.4::ICameraProvider/external/0
```

即：**服务起来了、config 读了、设备节点认了、YUV 流公布了、provider 注册成功了** —— 只差最后一跳。

---

## 4. external HAL 的 YUYV/NV12 支持（自研补丁，已入库）

补丁 `patches/waydroid-camera-64bit-20261018/0001-external-camera-hal-raw-yuv-support.patch`（2 文件 +139/−7）：

| 位置 | 改动 | 为什么 |
|---|---|---|
| `ExternalCameraDevice.cpp` `kSupportedFourCCs` | 加入 `V4L2_PIX_FMT_YUYV`、`V4L2_PIX_FMT_NV12` | 否则列举阶段就过滤掉我们的 loopback 节点 |
| `initAvailableCapabilities` | YUYV/NV12 ⇒ `hasColor = true` | 能力位不置位 ⇒ 上层认为无彩色流 |
| `initOutputCharsKeys` | `hasColor` 拆成 `hasColorMjpeg` + 独立 `halFormatsYuv`（`YCbCr_420_888`、`IMPLEMENTATION_DEFINED`） | 原逻辑只在 MJPEG 分支置位 ⇒ `initOutputCharsKeys: format YUYV is not supported!` |
| `ExternalCameraDeviceSession.cpp` | 四cc 白名单加 YUYV/NV12/YUV420；新增 `YUY2ToI420`/`NV12ToI420`/`I420Copy` 转换分支 | 会话层原来只会 MJPEG 解码 |

配套**两处非补丁坑**（`PITFALLS` #310）：
- `cannot find suitable cropping type` 的第一因是 **v4l2loopback 不支持 `ENUM_FRAMESIZES`/`ENUM_FRAMEINTERVALS`**（`v4l2-ctl` 能显示尺寸是因为它回退到 `G_FMT`）⇒ 在 HAL 里加 `G_FMT`/`G_PARM` 回退（`ELDEN_FRAMESIZE_FALLBACK` / `ELDEN_FRAMERATE_FALLBACK`）。
- 第二因就是上表的 `kSupportedFourCCs`：修了回退也走不到，因为格式在更早一步被丢掉。**两个坑叠加，只修一个现象不变**。

MJPEG 生产者路线已否证：本机 `v4l2loopback` 无 `pixelformats` 模块参数，`v4l2-ctl --set-fmt-video pixelformat=MJPEG` 直接 `invalid`；
GStreamer `v4l2sink` 虽列 `image/jpeg`，但实际 `not-negotiated (-4)`（约 6 ms 即断）。

---

## 5. 未解决（C5 ② 当前唯一阻塞）

provider 进程在**首笔 binder 事务**里 SIGSEGV：

```
F libc   : invalid pointer 0xffff…3008 (page signature mismatch)
F DEBUG  : signal 0 (SIGSEGV), code 1 (SEGV_MAPERR)
F DEBUG  : pc ffffffffffffffe0  <unknown>
F DEBUG  : #01 libhidlbase.so (android::hardware::BHwBinder::transact(… std::__1::function<void (…Parcel&)>))
init.svc.vendor.camera-provider-2-4-ext = restarting
CameraProviderManager: tryToInitializeHidlProviderLocked: HIDL … 'external/0' is not actually available
```

**A/B 控制已做**：把 `/dev/video100` 绑定注释掉（`#TMPCAM#`）后重启，仍 4 次 crash ⇒
**崩在 provider 基座/注册路径，不在设备枚举**（不是我们那段 YUV 代码把设备搞崩的）。

假定根因 = **NDK libc++ 与平台 libc++ 的 ABI 不一致**（`std::function` 布局差异在 `BHwBinder::transact` 处爆掉；
`pc = …fffe0` 是典型的被 ABI 错位读成函数指针）。

两条下一步（按代价排序）：

| 选项 | 做法 | 风险/代价 |
|---|---|---|
| **B（推荐）** | 取 `external/libcxx/include`（android13-release），`-nostdinc++ -isystem <libcxx>/include` 重编，ABI 宏与平台一致（`_LIBCPP_ABI_NAMESPACE=__1` 等） | 只改工具链，代码零改；需重跑整条 bake |
| A | 用 donor 镜像里的 **AOSP 原生 64-bit** `android.hardware.camera.provider@2.5-service_64` + `camera.device@3.{2..5}-impl.so` | 该 prebuilt 的 `service.cpp` **只注册 `legacy/0`**（2.4/2.5），`external/0` 的 32-bit `provider@2.4-external` donor 里没有 ⇒ 还是要自编一个 64-bit main/或改 rc，收益小 |

> donor 侧已核：`los20-rpi5-ota` 里那份 `…provider@2.5-service_64` 确为 ELF64 aarch64，NEEDED 全在 donor `lib64` 内可满足。

---

## 6. 收尾状态（2026-10-18 11:1x）

- 设备：`vk127` 在机、`waydroid session STOPPED`（`container STOPPED`）、`v4l2loopback` 已卸载、`/dev/video*` 无残留、
  遗留 `gst-launch` 生产者进程已按 PID 杀掉（`pgrep -c gst-launch` = 0）、无 camera 模块加载（熄屏安全，Q24 口径）。
- 仓库：本报告 + `patches/waydroid-camera-64bit-20261018/` + `PITFALLS` §44 + C5/DEVICE 口径更新；
  `dl-cam/` 为构建工作区（8.7 G，不入 git，见 `.gitignore`）。
- 未做的：C5 ② 的 SIGSEGV 修复（选项 B）、以及 `dumpsys media.camera` 出现 `Number of camera devices: 1` 的验收。
