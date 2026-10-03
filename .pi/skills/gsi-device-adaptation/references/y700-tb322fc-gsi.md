# 案例：联想 Y700 四代 (TB322FC) + LineageOS 23.2 GSI

2026-08-17 调查实录。设备刷 GSI 后三个适配问题，全部在 adb 侧取证定位。

## 系统基线（关键属性）

```
ro.build.fingerprint: Lenovo/TB322FC_PRC/TB322FC:15/AQ3A.250129.001/ZUXOS_1.1.11.073_250612_PRC:user/release-keys
ro.build.description: lineage_gsi-user 16 BP4A.251205.006   (Android 16 / SDK 36)
ro.lineage.device:   tdgsi_arm64_ab, 23.2-20260603-UNOFFICIAL-gsi
内核: 6.6.56-android15-8-g38447e018c92  →  KMI = android15-6.6
ro.build.characteristics: device          ← 应为 tablet
ro.vendor.config.lgsi.device.type: pad / nettype: wifi / market_name: 拯救者平板 Y700
ro.boot.vendor.qspa.modem: enabled        ← vendor 暴露 modem 标志
slot: _a
```

## 问题 1：相机崩溃 = GCam fishfood 空壳（已解决）

- **系统默认相机是 Aperture**（`org.lineageos.aperture`），解析 `STILL_IMAGE_CAMERA`/`IMAGE_CAPTURE` 均指向它；进程存活、DropBox 无其崩溃记录。
- 崩的是 launcher 上的 "Google 相机" = `com.google.android.apps.googlecamera.fishfood`：DropBox 堆栈显示 `MainActivity.onCreate` 直接 `startActivity(googleapp://lens/...)`（跳 Google Lens），设备无 Google app → `ActivityNotFoundException` 秒崩。与摄像头硬件无关。
- 处置：`adb shell pm disable-user --user 0 com.google.android.apps.googlecamera.fishfood`。
- 佐证 HAL 正常：`dumpsys media.camera` events log 显示微信成功 CONNECT device 0/1；events 里 ADD/REMOVE 循环是 provider on-demand 生命周期，非崩溃。
- 噪音项：Aperture 启动有 `Failed to query component interface for required system resources: 6`（CameraX 组件查询），进程正常，暂无害。

## 问题 2：通话/移动数据 UI = GSI 全功能 telephony

- `service list` 有 phone/isms/isub/telephony.registry/telephony_ims 全套；`dumpsys telephony.registry` 显示 `mMaxActiveVoiceSubscriptions=1`、ServiceState OUT_OF_SERVICE（无 modem）。
- vendor 自认 wifi-only（`lgsi.device.nettype=wifi`），但 boot arg `ro.boot.vendor.qspa.modem=enabled` 让 GSI 启动了完整 phone 栈。
- 计划修复：`persist.sys.phh.disable_voice_call_in=true`（phh 属性，tdgsi 是否生效待实测）。

## 问题 3：QQ/TIM 不认平板（未完成，等待 KSU root 后修复）

- 11 寸屏 smallestScreenWidthDp ≥600（屏幕判定可过），但 `ro.build.characteristics=device` + framework 有电话能力 → 腾讯系判为手机，禁止手机/平板同时登录。
- 修复：KSU root 后 `resetprop ro.build.characteristics tablet` + disable_voice_call_in，用 KSU 模块 `/data/adb/modules/tablet-fix/post-fs-data.sh` 持久化。改后需清 TIM/QQ 数据重登验证。

## KSU-Next v3.3.0 重上流程（本机已验证 patch 部分）

```bash
# 资产（GitHub KernelSU-Next/KernelSU-Next releases v3.3.0）：
#   ksud-x86_64-unknown-linux-musl, android15-6.6_kernelsu.ko, KernelSU_Next_v3.3.0_33214-release.apk
# init_boot.img 取自原厂固件解包目录：
#   ~/下载/刷机-四代/firmware/TB322FC_073/TB322FU_ZUXOS_1.1.11.073/image/init_boot.img
ksud boot-patch -b init_boot.img -m android15-6.6_kernelsu.ko --kmi android15-6.6 \
  --out ./ --out-name init_boot_kernelsu.img
# 设备侧（用户亲刷）：fastboot flash init_boot_a init_boot_kernelsu.img
```

资产目录：`~/y700-gsi-root/`（原版 init_boot.img 备份、patched 镜像、APK、tablet-fix 模块）。
