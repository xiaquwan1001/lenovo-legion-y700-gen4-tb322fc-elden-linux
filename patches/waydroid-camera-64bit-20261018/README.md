# Waydroid 容器侧 64-bit external camera provider（2026-10-18，vk127）

> 对应任务 `TASKS/README.md` C5 ②a；报告 `reports/waydroid-camera-provider-64bit-20261018.md`；
> 坑 `PITFALLS` §44（#306–#313）。**这不是上游补丁**，是给 AOSP `hardware/interfaces` 树打的本地设备补丁。

## 文件

| 文件 | 说明 |
|---|---|
| `0001-external-camera-hal-raw-yuv-support.patch` | external HAL（camera/device/3.4）支持 **YUYV/NV12** 原始 YUV：四cc 白名单 + 能力位 + 独立 YUV 流公布数组 + 会话层 I420 转换。基点 = `hw-interfaces` `fa455d8`（tm-release cherrypick merge）。**唯一必须保留的上游树改动** |
| `build-cam-provider.sh` | 交叉编译脚本（NDK r25c 工具链 + `sysroot` + per-version include；产物落 `out-cam/`） |
| `gen-headers.sh` | 由 `hidl-gen` 生成 `/vendor` HIDL 头 + AIDL NDK 头（`--lang=ndk --structured --stability=vintf --min_sdk_version=33`） |
| `external-fetch-shim.cpp` | 补 `HIDL_FETCH_ICameraProvider`（否则 `Could not get passthrough implementation`），装成 `@2.4-impl.so` |
| `vendor-manifest-cam.xml` | 烘入 `/vendor/etc/vintf/manifest.xml` 的 camera provider 条目（2.4 + 2.5，实例 `external`） |
| `cam-producer.sh` / `wd-restart.sh` | 设备侧测试用：loopback 测试画面生产者 / 带 PID 过滤的容器重启（避免 `pkill -f` 自杀） |
| `gen-src.sh` | `hidl-gen -Lc++-sources` 生成 **Bn/Bp**（51 个 .cpp）到 `gen-src/`（与 `gen-headers.sh` 同一包清单） |
| `external-service-direct.cpp` | 自写 main：`impl->registerAsService("external/0")` 直接在纯接口上注册，**绕开** legacy 的 `getRawServiceInternal`+`dlopen(-impl.so)`（`DIRECT=1`） |
| `hidl-smoke.cpp` | **最小 HIDL 客户端冒烟**（只有 `ProcessState::initWithDriver("/dev/vndbinder")` + `IServiceManager::getService()`）。判定「崩溃是否与业务代码无关」的第一件工具（`SMOKE=1`） |
| `iface-compat.h` | 补 `gServicePrioMap`/`gServiceSidMap` 声明（hidl-gen 10.0.0+r36 生成的代码会引用，tm-release 的 `hidl/Static.h` 没声明，符号由 libhidlbase 导出） |
| `libcxx-__config_site` | 手写平台 libc++ config site（`_LIBCPP_ABI_VERSION 1` + `_LIBCPP_ABI_NAMESPACE __1`），配合 `PLATFORMLIBCXX=1` 用 |

### 构建开关（`build-cam-provider.sh`）

| 开关 | 作用 |
|---|---|
| `SELFIFACE=1` | 用 `gen-src/` 生成的 Bn/Bp 代替 donor 的 `android.hardware.camera.*` interface 库（`NEEDED` 里不再有 camera iface 库） |
| `DIRECT=1` | 用 `external-service-direct.cpp` 作 main（不走 passthrough） |
| `PLATFORMLIBCXX=1` | 用 `libcxx-__config_site` + AOSP `external/libcxx` 头（`-nostdinc++ -isystem libcxx/src`） |
| `SMOKE=1` | 额外产出 `hidl-smoke`（最小客户端） |

**执行顺序**（在 `~/y700-elden` 下，工作区 `dl-cam/` 已 ignore）：

```bash
# 1) 准备（一次性）：NDK r25c、hw-interfaces 克隆、hidl-gen/aidl deb 安装
#    deb: hidl-gen_10.0.0+r36-3.1build1_amd64.deb, aidl_1%3a10.0.0+r36-4_amd64.deb,
#         android-lib{base,log,utils,cutils,backtrace,boringssl}_*.deb
# 2) 打补丁（若 dl-cam/hw-interfaces 是干净克隆）
git -C dl-cam/hw-interfaces apply /home/xuqianhui/y700-elden/patches/waydroid-camera-64bit-20261018/0001-external-camera-hal-raw-yuv-support.patch
# 3) 编译
dl-cam/gen-headers.sh && dl-cam/build-cam-provider.sh
# 4) 烘进 vendor.img + 推设备（inode 扩容、SELinux 0:2000、vintf 都在脚本里）
scripts/waydroid-camera-bake.sh
```

## 已知阻塞（2026-10-18 晚，已定性但未解）

**与 camera 无关**：任何用这套工具链编出来的 64-bit 进程，只要碰 `getRawServiceInternal` 就在
`hidl_string::~hidl_string → free(0x30)` 处 abort（`Pointer tag … was truncated`）。
最小复现 = `hidl-smoke`（3 行）。已排除：`__ndk1` 命名空间、`hidl_string` 布局（16 B 逐字一致）、
NDK/平台两套 libc++ 头、donor interface 库（`SELFIFACE=1`）、legacy passthrough 路径（`DIRECT=1`）、VINTF 白名单。

**下一步**：按容器 VNDK33（`TQ3A.230901.001`）的 AOSP tag 重取 `system/libhidl` / `system/libhwbinder` /
`system/core` / `frameworks/native` 头重编（我们现用 `tm-release` 快照 ≠ 容器 tag），再用 `hidl-smoke` 二分
（`defaultServiceManager()` → `sm->get()`）收敛到具体结构体。验收口径不变：`dumpsys media.camera` → `Number of camera devices: 1`。
详见 `reports/waydroid-camera-provider-64bit-20261018.md` §8/§9、`PITFALLS` #314–#317。
