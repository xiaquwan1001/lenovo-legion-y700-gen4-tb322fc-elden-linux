# C3 身份/DRM 取证（Waydroid 容器 / lineage_waydroid_arm64_only A13）— 2026-10-13

> 任务：`TASKS.md` §2 C3 / §5 Q1（取证判定，**不预设结论**）。
> 台架：U2 `HA2EXB0E`，`fastboot boot out/boot-elden-vk126-c1.img`（GOOD 冷起 boot_id `ed4a3391-…`，hangcheck=0），
> 容器 = GAPPS `lineage-20.0-20260927-GAPPS-waydroid_arm64_only`，`sys.boot_completed=1`。
> 全部为**容器内只读取证**；未安装任何 APK、未改镜像。

## 0. 结论（先数字）

| 维度 | 结论 | 依据 |
|---|---|---|
| **Build 身份** | `userdebug` + **`test-keys`**，fingerprint = `waydroid/lineage_waydroid_arm64_only/waydroid_arm64_only:13/TQ3A.230901.001/…:userdebug/test-keys`；`ro.secure=1`、`ro.debuggable=0`、security_patch 2026-02-01、first_api_level 28 | `getprop` |
| **GMS 登录** | ✅ 已登录 `xuqianhui176@gmail.com`（type=com.google）；GMS `26.37.37`、Play Store `53.4.34`、GSF 在跑 | `dumpsys account`、`dumpsys package`、`ps -A` |
| **Google 连通性** | ✅ 经宿主代理（容器 `http_proxy=192.168.7.9:7897`）：`https://www.gstatic.com/generate_204` = **204**；`www.google.com` = 000（该域名未走通，非致命） | `curl` |
| **Widevine** | ❌ **本机不存在**：`/vendor/lib64/mediadrm/` **只有 `libdrmclearkeyplugin.so`**（ClearKey），全 `/vendor`+`/system` `find` 无任何 `*wv*`/`*widevine*`；DRM HAL 只有 `android.hardware.drm-service-lazy.clearkey` | `ls`/`find`/`ls /vendor/bin/hw` |
| **Play Integrity / SafetyNet** | ⏳ **未取得 API 回包**（需容器内跑检测 App）：前置条件已可判定 —— `test-keys`+userdebug 的 Waydroid build **不是 Google 认证 build**，不做指纹伪装/PIF 则 device integrity 必失败；SafetyNet 已弃用（2024 起停服） | 上表 + 社区先例（`RESOURCES.md` §1.3） |

## 1. 原始证据

```
# 身份
ro.build.fingerprint = waydroid/lineage_waydroid_arm64_only/waydroid_arm64_only:13/TQ3A.230901.001/eng.aleast.20260927.073220:userdebug/test-keys
ro.product.model      = Lenovo Legion Y700 Gen4
ro.product.manufacturer = Waydroid
ro.build.version.release = 13
ro.build.tags = test-keys ; ro.build.type = userdebug ; ro.debuggable = 0 ; ro.secure = 1
ro.vendor.build.fingerprint = waydroid/lineage_waydroid_arm64_only/waydroid_arm64_only:13/TQ3A.230901.001/xuqianhui100110131152:userdebug/test-keys
ro.product.first_api_level = 28 ; ro.build.version.security_patch = 2026-02-01

# DRM（关键）
ls -la /vendor/lib64/mediadrm/      -> libdrmclearkeyplugin.so   （仅此一个）
find /vendor /system -iname '*wv*' -o -iname '*widevine*'   -> （空）
ls /vendor/bin/hw/ | grep -i drm    -> android.hardware.drm-service-lazy.clearkey (+ .rc)
dumpsys media.drm                   -> Can't find service: media.drm   （lazy，未拉起）

# GMS / 账号 / 连通
pm list packages | grep -E 'com.google.android.gms$|com.android.vending|com.google.android.gsf$'
  package:com.google.android.gms ; package:com.android.vending ; package:com.google.android.gsf
versionName com.google.android.gms = 26.37.37 (190400-994713346)
versionName com.android.vending    = 53.4.34-31
Account {name=xuqianhui176@gmail.com, type=com.google}
ps -A | grep -E 'gms|vending'  -> com.google.android.gms / gms.unstable(DroidGuard) / com.android.vending(:background,:quick_launch)
curl -m12 https://www.gstatic.com/generate_204  -> 204
```

## 2. 判读

1. **Widevine = 不存在（不是「等级低」而是「没有」）**。这与社区先例一致（`RESOURCES.md` §1.3：arm64 prebuilt 仅 Android 11 有、A13 无；WayDroid-ATV 亦只 x86-64 有）。
   ⇒ 预期 U5（YouTube/Disney+ 高清 DRM 播放）**在 L3 路径上不可用**；YouTube 大概率回落非 DRM 路径（需播放实测确认，不在本次取证范围）。
2. **GMS 可用（登录 + 连通）**，即 C2 的门槛已过；本次吃到账号 = 用户此前人工验证的延续。
3. **Play Integrity 尚无回包**。可判定的只有前置：`test-keys` + userdebug + Waydroid fingerprint ⇒ 不加对策时 **MEETS_DEVICE_INTEGRITY 必失败**；社区对策 = `PlayIntegrityFork`(pif.json) / 认证指纹伪装，属"逐条复现并记录"，**不预设成功**。

## 3. 下一步（C3 收口所需）

1. **装检测 App 取真实回包**（本次未做）：容器内 `waydroid app install <apk>`，
   建议 `Play Integrity API Checker`（basic/device/strong 三档）+ `YASNAC`（SafetyNet 历史对照）。
   ⇒ 需要把 APK 取到宿主（走代理下载）——**这一步涉及第三方 APK 获取，等用户确认**。
2. 若 PI 失败：按社区三条做法**各变一个变量**复现并记录（PIF 指纹、未认证注册 `google.com/android/uncertified`、清 GMS 缓存）。
3. 回填 `TASKS.md` §6 §1 的 C2 维度分与 §5 Q1。

## 4. 与其它文档的关系

- `TASKS.md` §0（G2 ~65%）、§2 C3、§5 Q1、§6 §1 C2 维度。
- `reports/c9-cases-20261013.md`（U5 判据）。
- `RESOURCES.md` §1.3（社区先例）。

## 5. 附：检测 App 下载候选（**留待用户处理**，2026-10-13）

自动下载未采用（避免在会话内引入第三方 APK 获取/信任链）；已定位可直接取用的 release：

| 用途 | 项目 | 直链 | 大小 |
|---|---|---|---|
| **Play Integrity 三档**（首选） | `herzhenr/spic-android`（SPIC, 456★, Apache-2.0） | `https://github.com/herzhenr/spic-android/releases/download/v1.4.0/spic-v1.4.0.apk` | 11.2 MB |
| SafetyNet（已停服，仅历史对照） | `RikkaW/YASNAC` | `https://github.com/RikkaW/YASNAC/releases/download/v1.1.5/yasnac-v1.1.5.r65.15110ef310-release.apk` | 1.25 MB |

- 备注：GitHub **直连可达**（`curl --noproxy '*' api.github.com` = 200）；走宿主代理（`127.0.0.1:7897`）会 **403**。1nikolas 的 `play-integrity-checker-app` **无 GitHub release**（无资产）。
- 安装：设备侧 `waydroid app install <apk>`（容器需 RUNNING）；运行需 phosh 会话（当前 GOOD 发在；掉电回 vk94 日常后要重抽 GOOD 发）。
