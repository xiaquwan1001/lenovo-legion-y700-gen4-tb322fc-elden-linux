---
name: gsi-device-adaptation
description: "GSI device misidentified/crashing? adb forensics, KSU fixes."
---

# GSI 设备适配：调查与修复

刷了 GSI 的机器常见三类适配问题，根因几乎都出在 **GSI 通用 framework × 原厂 vendor** 的错配，而不是硬件。按本流程调查，证据先行，再动手。

## 1. 属性基线（第一步必做）

```bash
adb devices -l
adb shell getprop | grep -E "ro\.build\.characteristics|ro\.product\.(device|model|manufacturer)|ro\.build\.version|ro\.boot\.hardware"
adb shell getprop | grep -iE "phh|gsi|treble|lgsi|qspa|modem"
```

重点判读：
- `ro.build.characteristics`：GSI 默认 `device`/`default`；平板应改 `tablet`。**国产 app（QQ/TIM/微信）平板识别的关键信号之一**。
- `ro.vendor.config.*`（联想/部分厂商）：vendor 自己知道设备底细（如 `lgsi.device.type=pad`、`lgsi.device.nettype=wifi`），与 GSI 表现对照可定位错配在 framework 还是 vendor。
- `ro.boot.vendor.qspa.modem=enabled` 之类 boot arg：vendor 把"有 modem"暴露给 GSI → 全功能 telephony framework 启动 → 平板出现不可用的通话/移动数据 UI。
- `ro.lineage.device`/`ro.build.flavor` 确认 GSI 来源与构建。

## 2. 相机问题：先分清"哪个才是系统相机"

**launcher 图标 ≠ 系统默认相机**。先解析系统 intent：

```bash
adb shell cmd package resolve-activity --brief -a android.media.action.STILL_IMAGE_CAMERA
adb shell cmd package resolve-activity --brief -a android.media.action.IMAGE_CAPTURE
```

### 空壳 app 识别（常见坑）
- 包存在、有 MAIN activity，但 `resolve-activity` 失败 / `am start` 秒退。
- 特征：MainActivity.onCreate 直接 `startActivity` 第三方 intent（典型：`googleapp://lens/` 跳 Google Lens，无 GMS 必崩）。
- 处置：`adb shell pm disable-user --user 0 <pkg>`（可逆，无 root 可做）。

### DropBox 崩溃记录器（核心技巧）
`logcat -b crash` 会滚动丢失，**DropBox 保留历史崩溃**，是最可靠的破案证据源：

```bash
adb shell dumpsys dropbox --print data_app_crash | tail -120   # 或 system_app_crash
adb shell dumpsys dropbox | grep -iE "crash|anr|watchdog"      # 先看条目清单
```

堆栈会给出确切根因（如 `ActivityNotFoundException` + 触发行）。

### camera provider 生命周期解读
```bash
adb shell dumpsys media.camera   # events log 在底部
```
- camera provider 是 **on-demand 服务**：平时不驻留（`ps` 看不到正常），客户端来了才拉起。
- events log 里 device ADD/REMOVE/CONNECT/DISCONNECT 循环 = 正常生命周期，**不是崩溃**。
- 第三方 app（微信等）能连前后摄 → HAL 链路通，问题在系统相机 app 本身。

## 3. 平板身份 / telephony 判定

```bash
adb shell dumpsys telephony.registry | grep -iE "mPhoneCapability|mServiceState"
adb shell service list | grep -iE "telephony|phone|radio|ims"
```
- `mMaxActiveVoiceSubscriptions=1` + phone/ims/SIM 服务全在 → framework 认为可打电话（`isVoiceCapable=true`）→ 腾讯系 app 判为手机，禁止手机/平板同时登录。
- 屏幕尺寸判定（smallestScreenWidthDp≥600）通常能过（11 寸平板必过），问题出在 characteristics + telephony 信号。

## 4. KSU-Next root 重上（GKI 设备，已验证流程）

刷 GSI 会清 data、root 丢失（`su: not found`，`ro.debuggable=0` 无 adb root）。重上 root：

1. **KMI 推导**：`adb shell getprop ro.build.version.release` + 内核版本 `uname -r`（如 `6.6.56-android15-8` → KMI = `android15-6.6`）。KSU-Next GitHub Release 资产按 KMI 命名（`android15-6.6_kernelsu.ko` 等）。
2. **取 init_boot.img**：GKI 设备 patch 的是 init_boot（含 ramdisk，不含内核）。来源 = 原厂固件包解包目录 `image/init_boot.img`（版本要与设备指纹一致，如 `ZUXOS_1.1.11.073_250612_PRC`）。
3. **本机 patch**（Linux 用 `ksud-x86_64-unknown-linux-musl`）：
   ```bash
   ksud boot-patch -b init_boot.img -m android15-6.6_kernelsu.ko --kmi android15-6.6 --out ./ --out-name init_boot_kernelsu.img
   ```
4. **用户亲自刷**（fastboot 小镜像 8MB 可靠；KSU 只改 init_boot 不触发 prevent flash）：
   ```bash
   adb reboot bootloader
   fastboot getvar current-slot     # 确认 a/b
   fastboot flash init_boot_<slot> init_boot_kernelsu.img
   fastboot reboot
   adb shell su -c id               # 期望 uid=0
   ```
   安全网：KMI 不匹配只会导致 su 不生效（系统照常开机），`fastboot flash init_boot_<slot> <原版>` 一步回滚。

## 5. 属性修复与持久化

```bash
adb shell su -c "resetprop ro.build.characteristics tablet"
adb shell su -c "setprop persist.sys.phh.disable_voice_call_in true"
```
- `resetprop` 对 ro. 属性**不持久**，重启回原值。
- 持久化 = KSU/Magisk 模块：`/data/adb/modules/<id>/post-fs-data.sh` 里放 resetprop/setprop（zygote 前生效），`module.prop` 声明元数据。
- `persist.sys.phh.*` 是 phh 兼容层属性；在 LineageOS tdgsi 上是否生效需实测（用 `getprop` 确认，不行就只靠 characteristics）。

## Pitfalls
- **adb 枚举为空时，先 lsusb 再怀疑一切**：`lsusb` 里设备在不在？在 → 查 USB 角色（`lsusb -v` 看 bInterfaceClass：PTP/仅充电 = ADB 接口未暴露，去设备端 USB 通知选"文件传输/调试"，不是 PTP）；角色正常仍连不上 → 才轮到线/口——坏线案例（老 USB overflow + OTA 后 adb/fastboot 全断、lsusb 正常但角色 PTP，换线即愈，TB322FC 2026-08-17）完整诊断顺序见 qualcomm-android-flashing。
- **设备 RTC 错乱**：GSI 刚开机时钟可能先走错值、联网后 NTP 纠正，导致 logcat 主 buffer 与 crash buffer 时间戳差数小时——先 `adb shell date` 确认再信时间线。
- crash buffer 里可能只有无关崩溃（如 vendor wifi HAL 的 ubsan），别被带偏。
- 改 `ro.build.characteristics=tablet` 后国产 app 可能缓存设备指纹，需清数据/重登才生效。
- 大镜像（boot/super）fastboot 传输会静默损坏，但 8MB 级 init_boot 属可靠区间（分界线经验见 qualcomm-android-flashing）。

## 参考
- `references/y700-tb322fc-rom-ecosystem.md` — Y700 四代 (TB322FC) 全部可刷镜像生态（官方 043/073/096/1.5 系、GSI 线 tdgsi/MisterZtr/microG/官方 A16、移植 ROM 澎湃OS3.0.307.0 + ColorOS16 金标[作者 GUF296/兰微卡鱼]、TWRP、开发中内核/UEFI；资源入口 bszip.me + ROM乐园 + B站悲伤的压缩包）。
- `references/y700-tb322fc-gsi.md` — 联想 Y700 四代 (TB322FC) 完整案例：三问题根因、关键属性值、验证命令。
