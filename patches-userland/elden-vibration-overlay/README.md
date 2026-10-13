# elden-vibration-overlay — 让容器 Settings 出现「振动强度」调节

## 为什么需要

AOSP/LineageOS Settings 的强度滑杆按 **Settings 自己的资源** 决定档位数：

```
packages/apps/Settings/res/values/config.xml
    <integer name="config_vibration_supported_intensity_levels">1</integer>   <-- 默认 1
VibrationIntensityPreferenceController.getMax() = min(VIBRATION_INTENSITY_HIGH=3, 该资源)
getMin() = VIBRATION_INTENSITY_OFF = 0
```

设备通常由 **device overlay / RRO** 把它提到 3（或 5）。本树里没有任何覆盖 ⇒ 上限=1，滑杆退化成无效两档
（相册里看不到有意义的「强度」调节）。与 HAL 能力无关：我们的 AIDL HAL 已报 `CAP_AMPLITUDE_CONTROL`。

## 做法

一个 **静态 RRO**（`android:isStatic="true"`，放 `/vendor/overlay/`）：只覆盖 Settings 的这一个整数资源。
静态 overlay 会被 PackageManager 在开机时自动启用，不需要 `cmd overlay enable`。

## 编译 / 落盘

```bash
cp -r patches-userland/elden-vibration-overlay /mnt/Samsung/waydroid-build/vendor/extra/EldenVibrationOverlay
cd /mnt/Samsung/waydroid-build && source build/envsetup.sh && lunch lineage_waydroid_arm64_only-userdebug
mmm vendor/extra/EldenVibrationOverlay
ls out/target/product/waydroid_arm64_only/vendor/overlay/EldenVibrationOverlay.apk
```

然后由 `scripts/waydroid-haptics-bake-vendor.sh` 与 AIDL HAL、vintf fragment 一起写进 `vendor.img`。

## 验证（容器内）

```
waydroid shell cmd overlay list | grep -i elden          # [x] com.elden.vibration.overlay
waydroid shell settings get system vibration_intensity_touch   # -1/0..3（未设为 null）
```
Settings → 声音/无障碍 → 振动与触感：应出现 关/低/中/高 四档滑杆（每档对应马达不同幅值）。
