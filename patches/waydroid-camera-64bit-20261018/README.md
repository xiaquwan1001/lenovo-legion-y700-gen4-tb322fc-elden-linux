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

## 已知阻塞（下一步）

provider 注册成功后，**首笔 binder 事务 SIGSEGV**（`BHwBinder::transact`，`pc …fffe0`）= NDK libc++ 与平台 libc++ ABI 不一致。
修法：用 `external/libcxx/include` + `-nostdinc++ -isystem <libcxx>/include` 重编，然后重跑第 3、4 步。
验收：容器内 `dumpsys media.camera` 出 `Number of camera devices: 1`。
