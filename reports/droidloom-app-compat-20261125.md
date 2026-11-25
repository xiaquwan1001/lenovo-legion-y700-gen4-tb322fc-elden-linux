# droidloom 应用兼容三问（GMS / Limbus Company / 小红书）——2026-11-25 静态取证

- **性质**：**纯静态 + 在线只读**。本轮**零设备动作**（设备不在线，未发 `ssh`/`adb`/`fastboot`，未装包、未写盘、未登录任何 Google/小红书账号）。
- **不重推的先例**（结论直接用，不重新论证）：
  - `reports/droidloom-feasibility-20261108.md`（形态/门槛基线，§1.1 M4 = 身份维度）；
  - `reports/droidloom-feasibility-20261110.md`（on-device doctor / L1–L4 定义）；
  - `reports/droidloom-status-20261111.md`（L1 ✓ L2 ✓ L3 ✓ L4 判据）；
  - `TASKS/README.md` **:99**（C12 行，全绿 + 已持久化 + 开机自启）与 **:261**（Q3 行）；
  - `reports/c3-pi-tiers-closeout-20261110.md`（PI 三档 + Widevine 上限）与 `reports/c3-spic-verdict-20261115.md`（`deviceRecognitionVerdict = []`）。
- **证据级别**：每条标 **实测**（本轮命令输出/原文）/ **静态**（读源码/包元数据/文档）/ **推断**（外推，未取证）。
- **在线材料基准日**：上游 `denialwm/droidloom` `main` @ `908aca0f`（2026-11-20T14:21Z，`pushed_at=2026-11-20`），release 最新 **`0.1.0-49`**（2026-11-20T14:33Z）。
- **本机在版**：`0.1.0-30`（2026-11-05）摊装在 `/opt/dl-test` + `/usr/bin` 软链，`/etc/droidloom/cell.json` 手铺（`TASKS/README.md:99`）。

---

## 0. 一页结论（3 个二值判断）

| # | 二值问题 | 判定 | 一句话依据 | 依据强度 |
|---|---|---|---|---|
| **J1** | droidloom 上的 GMS 是否「能用」 | **「能登 Google 账号」= 上游已在 ARM64 cell 上验证过；「过 Play Integrity」= 未验证且上游明文免责；「Play 商店装应用」= 需 certified 的设备才稳，本形态稳定落在 `uncertified`** | `docs/KNOWN_ISSUES.md@826368b1` L157–167（ARM64 Moto cell 登录 + Play Store 打开已验证）↔ 同文件 **L232**「On the Moto cell, **Play reports an uncertified device**」↔ `docs/threat-model-v2.md` L116–119「Protected media, hardware attestation, and **Play Integrity are not supported claims**」 | 实测（上游原文）+ 我方 C3 实测同向 |
| **J2** | 能否起 **Limbus Company**（`com.ProjectMoon.LimbusCompany`） | **本轮判定 = 「需先补 X」**：以现役 `0.1.0-30` + `droidloomctl install` 单一 APK 路径 **预期起不来**；补齐 3 项后「有真实机会起」 | ① 该 App 只发 **split 包**（base + `UnityDataAssetPack` + `config.arm64_v8a`，XAPK 1.4 GB），而 `droidloomctl install` **只收一个独立 APK**、明确「Split bundles … and separate game assets are not supported」（`docs/KNOWN_ISSUES.md@826368b1` L247–249 / `docs/INSTALL.md` §5）② Unity 游戏在 droidloom ARM64 上有**已知先例缺陷**（CPU 拓扑掩码导致的 job worker 起不来，L198–230），修复晚于我方在版 ③ 无 GMS ⇒ 首次运行的 Play 归因/许可路径缺 | 静态（包元数据 + 上游文档）为主，**零实测** |
| **J3** | 能否起 **小红书**（`com.xingin.xhs`） | **预期能起（浏览/搜索/私信）**；但**相机、定位、中文输入、推送**四项在现役装置上「缺组件」而非「坏」⇒ **不能替代手机完成拍摄/发布类动作** | 包元数据：`arm64-v8a` + `config.xxhdpi` 两个 split、minSdk 21、213.8 MB、**无 x86 ABI**（→ aarch64 原生，无需 Teto/Digitalis）；风控 = 自研 `libxyass.so` shield 签名 + MSA OAID（`libmsaoaidsec.so`）+ 反注入（`libSystemHealer.so`/`libcapahook.so`）+ 哨兵进程（`libtinyd.so`），**未发现第三方加固壳**、**未发现 Play Integrity 依赖** | 静态（第三方包元数据 + 独立逆向记录），**零实测** |

**共同天花板**：`reports/c3-pi-tiers-closeout-20261110.md` 的三档结论对 droidloom 同样成立（`STRONG` 结构性不可达；Widevine 连 L3 库都没有）。本轮没有任何证据能把上限抬高——上游只是把「登录 + 商店能开」写进了文档，并把 **integrity 明确留在"每台设备各自验证"**（`KNOWN_ISSUES@826368b1` L177–178、L243）。

---

## 1. Q1：GMS / 谷歌服务支持到哪一步

### 1.1 三句话分层（不要混着说）

| 层 | 现状 | 级别 |
|---|---|---|
| **能登 Google 账号** | **已验证（上游自述）**：*"Account sign-in and opening Play Store have been verified on the Moto ARM64 developer cell."*（`KNOWN_ISSUES@826368b1:161-162`）；x86_64 侧另有一次 *"native Play Services 24.23.37 and Play Store 41.3.25 … completed account sign-in with the Android 17 framework and configuration"*（`docs/BUILDING.md` §Optional Google apps） | 静态（上游原文，非我方实测） |
| **过 Play Integrity** | **没有承诺、也没有证据**；上游原话 *"Protected media, hardware attestation, and Play Integrity are **not supported claims**"*（`docs/threat-model-v2.md:116-119`）；另 *"Runtime DRM/integrity behavior **remains untested**"*（`KNOWN_ISSUES@826368b1:243`） | 静态 |
| **Play 商店装应用** | **有条件**：设备必须 certified，而本形态被 Play 明确判为 **uncertified**（`KNOWN_ISSUES@826368b1:232`）。上游记录的「装得上」案例都是在**手工修好声明**之后（补 `android.hardware.touchscreen.multitouch*`、补 Vulkan/GLES 版本、加通用 location/Bluetooth 声明、清 Play Store cache）——*"TikTok 46.8.3 became available after a device-local test added generic location and Bluetooth declarations … Play completed the base installation and six additional feature installs"*（L232–240），且 *"Catalog availability, app installation, push delivery and integrity checks require separate validation on each target"*（L177–178） | 静态 |

> 一句话：**登录 ≠ 认证 ≠ 商店可用**。droidloom 把「第一档」做到了，「第二档」按设计不做承诺，「第三档」取决于 Play 对 `uncertified` + 缺失 feature 声明的容忍度，**每台设备、每个 App 都要单独试**。

### 1.2 `droidloom-gapps` 的真实形状（这次逐字段核过）

| 项 | 事实 | 证据 |
|---|---|---|
| 官方供给 | *"Google apps are not included."*；可选 add-on 由**本机自备**的 **LiteGapps regular lite archive for Android 17/API 37** 构建（例：`LiteGapps-arm64-17.0.zip`） | `docs/INSTALL.md` §2；`docs/BUILDING.md` §Optional Google apps |
| 输入校验 | 归档必须含 `module.prop`（Magisk 模块形）、**≤ 512 MiB**、**必须显式给 `--sha256`**；*"The importer does not execute upstream installer scripts or resign APKs"* | `tools/droidloom-gapps/src/main.rs:36-42,101-110`（本轮实读）；`BUILDING.md` 同上段 |
| 输出的角色 | 只派生 **`product` + `system_ext`** 两个分区；`ADDON_ROLES = ["system_ext","product"]`，基线三角色 `system/system_ext/product` 全量哈希绑定 | `runtime/droidloom-contracts/src/gapps.rs:18-22`（本轮实读） |
| API 门 | `pub const SDK: u32 = 37;`（= Android 17），manifest `sdk` 不符直接 `unsupported GApps manifest or Android SDK` | 同上 `:16,:174-175` |
| 必须导入的 3 个 APK | `com.google.android.gsf`（`system_ext/priv-app/GoogleServicesFramework/…`）、`com.google.android.gms`（`product/priv-app/GmsCore/…`）、`com.android.vending`（`product/priv-app/Phonesky/…`）；替换 APK 必须同包名 + 同签名证书（或签名轮换谱系祖先） | 同上 `:103-116`；`BUILDING.md` |
| 激活条件 | cell.json 里加 `"gapps_dir": "/usr/lib/droidloom/addons/gapps"`；**首次激活要求全新 Android 数据**（`data_dir` 的 `data`/`metadata` 必须为空） | `BUILDING.md` 末段「First activation requires fresh Android data」 |
| 启动校验 | supervisor 每次启动校验 root 属主 + 全部 base/output 哈希，缓存 `/var/cache/droidloom/gapps-verified.json`；add-on 不匹配则**启动失败且不回退** | 同上 |
| 主机侧工具 | `bsdtar`/`xz`/`e2fsprogs`/`aapt2`/`apksigner`/Java；EROFS 还需 `erofs-utils`+`fakeroot`+`attr` | 同上 |
| 分发 | add-on **从不随 release 发布**（*"Optional Google apps are not published"*，`BUILDING.md:23`） | 静态 |

### 1.3 我方要做成 GMS，缺什么（按顺序）

1. **本地 `LiteGapps-arm64-17.0.zip`**（≤512 MiB，Magisk 模块形，需人工审阅并钉 sha256）——**未取**（设备上、仓库里都没有；`reports/droidloom-status-20261111.md` §2.2 已记「未做」）。
2. **一套能跑 `aapt2`/`apksigner` 的构建环境**（Java + Android SDK build-tools）。本机有 `adb`（`~/.local/opt/platform-tools`），**未核 aapt2/apksigner 是否在**（本轮未查，标未取证）。
3. **一份全新的 `data_dir`**（现役 cell 的 `/var/lib/droidloom/users/1001/data` 已 boot 过 ⇒ 按上游契约**必须换新目录**，否则 add-on 不会激活）。
4. **升级到 `0.1.0-49`**：`gapps_dir` 支持与「按 base 哈希绑定」是后加的；且 49 把 base 拆成独立包（`droidloom-base-0.1.0-49-aarch64` 903 MB + `droidloom-image-49-aarch64` 67 MB，`droidloom-runtime-49-aarch64` 11 MB），**旧装法（摊一个 image 包）不再等价**。

### 1.4 dex/ART 与 shared-kernel 形态下的已知坑（只列上游文档里有的）

| 坑 | 内容 | 出处 |
|---|---|---|
| **dex2oat 位数选择** | x86_64 的 64-bit-only base 没有 `dex2oat32` ⇒ ART 的后台/安装编译全部 `ENOENT`；修法 = `dalvik.vm.dex2oat64.enabled=true`（ARM64 镜像本来就有）。**我们不在 x86_64，此坑不适用于 G2** | commit `c5c36579`（2026-11-16） |
| **GMS 的 Wi-Fi 假设** | 老版 Play Services 的 `magictether.host.TetherListenerService` 在「无 Wi-Fi 服务」的 cell 里崩；桌面 workaround = `pm disable --user 0 …TetherListenerService`。**我们 cell 走 veth/NAT，没有 Wi-Fi 服务 ⇒ 同类崩溃要预期**（推断，未实测） | `BUILDING.md`、`KNOWN_ISSUES@826368b1:170-176` |
| **权限修复需要重装（保留数据与 splits）** | *"Existing apps may need an ordinary reinstall preserving their data and splits to acquire newly introduced normal Google permissions"*；NTE 的 licensing 连接就是靠这一步修好的 | `KNOWN_ISSUES@826368b1:167-170` |
| **root/调试属性投影 = 必要不充分** | supervisor 在 Android init 前投影 release 风格 build 元数据（清 `ro.debuggable`、替换 `userdebug`/`test-keys`/`dev-keys`），但原文紧随其后：*"It does not change image signing, SELinux enforcement or hardware attestation, and **cannot guarantee acceptance by every app or Play Integrity**"* | `KNOWN_ISSUES@826368b1:5-20` |
| **shared-kernel 的边界（非 App 层但决定"能不能有 TEE"）** | *"Android SELinux cannot install a private policy into a conventional shared host kernel. Protected media, hardware attestation, and Play Integrity are not supported claims."* | `docs/threat-model-v2.md:116-119` |
| **文档口径变化（引用纪律）** | `docs/KNOWN_ISSUES.md` **已于 2026-11-20 删除**（commit `908aca0f` 原文：*"docs/KNOWN_ISSUES.md is gone with every link to it: nothing is known broken, and its history of fixed issues misled readers."*）⇒ 本文引用的 L 号一律钉 `@826368b1`（删除前最后一版）。**今后引用上游"已知限制"必须钉 commit**，否则链接会 404（本轮 `raw/main/docs/KNOWN_ISSUES.md` 实测返回 **404**） | 实测（`curl` 404）+ 静态（commit message） |

---

## 2. Q2：能否起 Limbus Company（边狱公司）

### 2.1 App 侧真实技术需求（第三方包元数据，2026-11-19 版）

| 项 | 值 | 级别 |
|---|---|---|
| 包名 / 版本 | `com.ProjectMoon.LimbusCompany` / **1.119.1 (versionCode 494)**，2026-11-19 更新 | 静态（APKPure 页面） |
| minSdk | **Android 8.0（API 26）**（早期 1.105.0 是 API 24） | 静态 |
| ABI | **`arm64-v8a` 变体在**（另有 `armeabi-v7a` 变体）⇒ aarch64 宿主**原生执行，不需要 Teto/Digitalis 翻译** | 静态 |
| 分发形态 | **XAPK 1.4 GB**；`Base APK com.ProjectMoon.LimbusCompany.apk` + **split `UnityDataAssetPack`** + **split `config.arm64_v8a`** | 静态 |
| ⇒ 引擎/资源 | split 名 `UnityDataAssetPack` 就是 Unity 的 **Play Asset Delivery（install-time asset pack）** ⇒ ① 引擎 = Unity ② **资源在独立 asset pack 里，base APK 本身不含全部数据** | 静态（强） |
| Unity 具体版本 / 渲染后端 | **未取证**。Unity 移动端默认 GLES3，Vulkan 可选；两者在本机都没实测过 | 未取证 |
| 额外下载 | 未知（Unity + 体积从 660 MB→1.4 GB 的增长形态暗示有版本化资源包；首次启动是否再拉数据**未取证**） | 未取证 |
| 权限 | `INTERNET`、`VIBRATE`、`com.android.vending.BILLING`、`ACCESS_NETWORK_STATE`、`WAKE_LOCK`、`com.google.android.gms.permission.AD_ID`、`ACCESS_ADSERVICES_*`、`POST_NOTIFICATIONS`、`FOREGROUND_SERVICE(_DATA_SYNC)`、`READ_GSERVICES`、`GET_INSTALLED_APPS`、`com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE` | 静态 |
| Play 授权（LVL） | APKPure 对比表标 **"Google Play App License: Not Required"**（1.105.0 行）⇒ 不走 LVL 许可校验 | 静态（第三方标注） |
| 账号/DRM | **未取证**（是否需要 Google Play Games 登录、是否有 integrity 校验、是否有反作弊，均无证据） | 未取证 |

### 2.2 droidloom 能力面对照

| droidloom 能力 | 现状 | 对本 App 的影响 | 级别 |
|---|---|---|---|
| Android 版本 | **Android 17 / API 37** pinned（`gapps.rs:16`；cell 实跑 Android 17） | minSdk 26 ≪ 37 ⇒ 系统层通过 | 静态 |
| ABI | aarch64 宿主**原生**跑 arm64 | 无需翻译层，避开 Digitalis 那堆 PTRACE/BRK 缺陷 | 静态 |
| GPU | 宿主 `msm_dpu` + Mesa **freedreno**（GLES 原生）；Vulkan 在 Adreno 上有上游记录（*"Vulkan 1.4 and hardware level 1"*，但那是 OnePlus Pad 4 上另一次实验），**本机未取证** | Unity GLES3 路径「应该」能走；Vulkan 路径不确定 | 静态 + 未取证 |
| **APK 安装** | `droidloomctl install` **只收单一独立 APK**，*"Split bundles, drag-and-drop installation and separate game assets are not supported by the command"* | **直接阻断**：Limbus 是 base+2 splits，且资源在 asset pack | 静态（硬） |
| Play Store 路线 | GApps 可选 add-on（需全新 data + 本地 LiteGapps + 升级到 49）；即便装上，Play 对 **uncertified** 设备 + 缺 feature 声明的目录可见性要单独修 | 备选路径，成本高、成功率未知 | 静态 + 推断 |
| 内置 ADB | 上游自带 `adb -s device:droidloom`（`10.177.0.2:5555`，`ro.serialno=droidloom`） | **这是分片安装的实际可用旁路**（`adb install-multiple`） | 静态 |
| CPU 拓扑 | 上游记录过一次真实缺陷：*"Droidloom omitted CPU discovery masks from its synthetic sysfs, causing Bionic to report one CPU despite eight usable cores"* ⇒ Unity 的 job worker 起 0 个 → `UnsafeList.Realloc` 疯长 → `madvise/mprotect` 被内核拒 | **Unity 类游戏的头号风险**；修复在 2026-11 中旬之后，**晚于我方在版 `0.1.0-30`（11-05）**⇒ 按现役装置判「大概率仍在」 | 静态（上游原文）+ 推断（版本对齐） |
| 触觉/传感器/相机 | 现役无 broker；上游新版有 `droidloom-devices`（haptics/camera/fingerprint/location，DLDEV001）但相机要求宿主有 **braun**、定位要求 **dmail** | Limbus 只用到 `VIBRATE`（弱需求，不影响起） | 静态 |
| 窗口/输入 | 每个 App 一个 `xdg_toplevel`；`--resolution WIDTHxHEIGHT` 可在启动前定 task 尺寸（游戏常用） | 有利 | 静态 |

### 2.3 判断与依据强度

> **判定：需先补 X（不是"起不来"，也不是"能起"）。** 依据强度 **中下**（全部静态，零实测）。

必须补的三件（按性价比排序）：

- **X1 分片安装旁路**（必要条件）：`adb -s device:droidloom install-multiple base.apk config.arm64_v8a.apk split_UnityDataAssetPack.apk`。
  - **推断**：install-multiple 支持 split 与 install-time asset pack；`droidloomctl install` 明确不支持。**未实测**。
- **X2 升级到 `0.1.0-49`**（强烈建议，否则 X3 的失败原因无法归因）：拿到 CPU 掩码修复、GLES/Vulkan 运行时探测、syncobj 可选（回退到 DMA-BUF fence）、设备 broker 框架。
  - **副作用（对我们有利）**：presenter 变成 *"`linux-drm-syncobj` is optional since the presenter falls back to fences on the DMA-BUFs"*（`docs/architecture.md:122-124`，commit `908aca0f` README）⇒ 我们 2026-11-11 那张 phoc 补丁**在 49 上不再是硬前提**，回退空间更大。
- **X3 cell 出网 + 1.4 GB 落盘**：运行期版本化资源拉取必须通；cell 网络依赖 **`CONFIG_NF_TABLES`（vk187b）**，落盘走 `data_dir/data` 的宿主文件系统（20 GiB 级余量，设备 157 GiB 空闲，`reports/droidloom-feasibility-20261110.md` §3.5）。

**否证条件（出现任一即"判定被推翻"）**：
1. X1+X2 之后 `droidloomctl applications` 里出现包名但 `launch` 后无窗口 / `crashes` 报 `UnsatisfiedLinkError` on `libunity.so` → 转「起不来（引擎层）」。
2. `adb install-multiple` 直接报 `INSTALL_FAILED_INVALID_APK` / asset pack 被拒 → 分片旁路不成立，只剩 Play Store 一条路。
3. 首次启动后要求 Play 登录/许可而无法完成 → 归「需用户账号」（本轮禁区）。

---

## 3. Q3：能否起 小红书（REDnote / `com.xingin.xhs`）

### 3.1 App 侧真实技术需求

| 项 | 值 | 级别 |
|---|---|---|
| 包名 / 版本 | `com.xingin.xhs` / **9.55.1 (9551802)**，2026-11-19（Play 同名同包） | 静态 |
| minSdk | **Android 5.0（API 21）** | 静态 |
| ABI | **只有 `arm64-v8a` 与 `armeabi-v7a` 两个变体，无 x86/x86_64** ⇒ aarch64 原生可用 | 静态 |
| 分发形态 | **XAPK 213.8 MB**；base + `config.arm64_v8a` + `config.xxhdpi`（ABI 与密度两个 split，**无 asset pack**） | 静态 |
| 加固（壳） | 第三方逆向记录（2025-08，8.32.0.5）明确：*"使用 MT 管理器查看 app **并没有加固**，直接将 apk 文件拖入 jadx 反编译分析"* ⇒ **无第三方加固壳** | 静态（独立第三方，**非本轮实测**） |
| 自研风控/反注入栈 | 网络层 **Cronet**（`libcronet` + `libhttpengine`）；okhttp3 `CertificatePinner`；**`libSystemHealer.so`**（shadowhook 钩 ART `setStopped`）+ **`libcapahook.so`**（bytehook）反注入；**`libtinyd.so`** 哨兵进程（cmdline 同名、1 线程）；**`libmsaoaidsec.so`**（MSA OAID SDK，含 frida 检测）；**`libxyass.so`** 生成 `shield` 签名；`com.xingin.shield.http.XhsHttpInterceptor`；设备指纹 = `com.xingin.shield.http.ContextHolder.sDeviceId`（同机稳定 uuid）+ `sAppId` | 静态（同一第三方逆向记录） |
| 主进程改名 | `prctl(PR_SET_NAME)` 把 comm 改成 `rednote`（`cmdline` 仍是包名） | 静态 |
| GMS 依赖 | **未见必需依赖**：`com.google.android.c2dm.permission.RECEIVE` / `AD_ID` 只是可选推送/广告；中国版走自有推送。**Play 版与国内版同包名** | 静态 + 推断 |
| Play Integrity 依赖 | **无证据**（权限表无相应线索；其风控是自研 shield + OAID + 指纹，与 Play 认证正交） | 推断（否证条件见 §5） |
| 权限里值得注意的 | `CAMERA`、`RECORD_AUDIO`、`READ/WRITE_EXTERNAL_STORAGE`、`READ_MEDIA_IMAGES/VIDEO/AUDIO`、`ACCESS_FINE/COARSE_LOCATION`、`READ_CONTACTS`、`USE_BIOMETRIC`、`NFC`、`com.oplus.ocs.permission.third`、`com.xiaomi.security.permission.ACCESS_XSOF`、`com.hihonor.security.permission.ACCESS_THREAT_DETECTION`、`com.huawei.permission.ACCESS_HW_KEYSTORE`、`cn.org.ifaa.permission.USE_IFAA_MANAGER`、`com.xingin.xhs.matrix.permission.PROCESS_SUPERVISOR`、`com.xingin.xhs.manual.dump` | 静态 |

### 3.2 与 droidloom 能力面对照（逐项「能/不能/未取证」）

| 需求 | droidloom 现状 | 判定 | 级别 |
|---|---|---|---|
| arm64 原生代码（Cronet/shield/OAID 全在 arm64） | aarch64 宿主原生 | **能** | 静态 |
| 分片安装 | `droidloomctl install` 只收单 APK ⇒ 用 `adb -s device:droidloom install-multiple base.apk config.arm64_v8a.apk config.xxhdpi.apk` | **需走旁路**（推断可行） | 静态 + 推断 |
| 存储（相册/保存图片） | 上游 `share_user_folders` 把宿主 `Pictures/Download/Movies/…` 映成 Android 的 Pictures/Download/Movies 等集合（`runtime-layout-v1.md:158-170`） | **能**（走 MediaProvider + idmapped bind） | 静态 |
| **相机**（拍照/视频发布/扫码登录） | 现役 `0.1.0-30` **无相机 broker**；上游新版有 `droidloom-devices` 的 `camera.sock`，但*客户端要 braun 的相机与 session*，**本机没有 braun** | **不能**（缺组件） | 静态 |
| **麦克风** | 上游有 per-user audio broker（PipeWire 图 + cell capture，可选关） ⇒ 录音**有可能通**；我方从未测 | **未取证** | 静态 + 未取证 |
| **定位** | `droidloom-devices` 的 `location.sock` 依赖宿主 **dmail** 的 GNSS；本机无 dmail（无该栈） | **不能**（缺组件） | 静态 |
| **中文输入**（登录手机号/发帖/评论） | droidloom 的 IME 是 **cell 内部的 headless Android IME**（`com.android.droidloom.ime/.HostInputMethod`，`docs/contracts/text-input-v1.md:3-8`）⇒ **宿主 fcitx5/squeekboard 不参与**，必须在 cell 里装一个中文 IME APK 并设为默认 | **需先补**（装 IME） | 静态 |
| 推送 | 无 GMS 时 `c2dm` 拿不到；国内推送通道依赖 OEM 服务（`com.oplus.ocs`/`com.miui…`）⇒ 均不存在 | **不能**（弱需求） | 推断 |
| 设备指纹 / 风控 | 风控看 `sDeviceId`（自生成 uuid，稳定即可）+ OAID（`libmsaoaidsec.so` 取 MSA OAID，需 OAID provider ⇒ 无） + 反注入检测；droidloom 投影的 build 元数据是 **release 风格**（`KNOWN_ISSUES@826368b1:5-14`） | **未取证**：可能被降权/触发验证码，但**未见硬拦截证据** | 推断 |
| 网络 | cell 走宿主 NAT（vk187b + nftables）；上游无 Wi-Fi 服务 ⇒ 若 App 强校验 Wi-Fi 状态可能异常 | **未取证** | 推断 |

### 3.3 判断与依据强度

> **判定：预期能起（浏览/搜索/私信/收藏），但不能替代手机做拍摄/发布/直播。** 依据强度 **中**（包元数据 + 第三方逆向记录均为静态，零实测）。

**否证条件**：
1. `launch` 后 3–10 s 内 `crashes` 出现 `SIGSEGV`/`SIGILL` 且栈落在 `libSystemHealer.so`/`libcapahook.so`/`libmsaoaidsec.so` → 反注入/反调试在本形态直接杀进程 ⇒ 转「起不来」。
2. 首页请求全部返回风控错误（`logcat` 里出现 `shield` 相关 403/`-100` 类业务码）且无法完成基础浏览 → 转「指纹不过」。
3. 首次启动强制要求「非 root/真实设备」检测 → 同上。

---

## 4. 上机窗可执行验证序列（命令级，**本轮全部未执行**）

> 前置口径：设备 = `ssh root@192.168.7.1`（USB-NCM）；桌面会话用户 `xuqianhui1001`（`XDG_RUNTIME_DIR=/run/user/1001`）。
> 标记：**【K】** = 必须在 **`vk187b`** 内核上（`CONFIG_NF_TABLES`；现役 `boot_b` 已是 vk187b，`TASKS/README.md:99` 收尾段，**上机前须回读确认**）；**【S】** = 依赖 `droidloom.service` 已 `enable` 且在跑（已在 `graphical-session.target`，同上）。
> 每一步都套 `timeout -k 10 540`。

### 4.0 Step 0 — 只读前置（不改任何东西）

```sh
# 【K】【S】设备与运行时事实
timeout -k 10 60 ssh root@192.168.7.1 'uname -r; nft list ruleset >/dev/null && echo nft-ok; systemctl is-enabled droidloomd.service'
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 systemctl --user is-enabled droidloom.service
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 droidloomctl status
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 droidloomctl doctor     # 若该版有；否则 /opt/dl-test/usr/bin/droidloom-doctor --user 1001
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 droidloomctl --help | sed -n '1,40p'
```
判据：`uname -r` 含 `vk184`/`vk187b` 血统 + `nft-ok`；`status` 打印 `cell u1001 is running …; Android is ready`；`--help` 用来确认在版 `0.1.0-30` 到底有哪些子命令（`logs`/`crashes`/`install` 可能不存在）。

### 4.1 Step 1 — 取包（**主机侧**，勿在设备上下大文件）

```sh
mkdir -p ~/dl-apps && cd ~/dl-apps
# 小红书（arm64 变体 XAPK，213.8 MB）
#   来源：APKPure「REDnote 9.55.1 (9551802) / arm64-v8a」下载项（split: config.arm64_v8a, config.xxhdpi）
# Limbus Company（arm64 变体 XAPK，1.4 GB；split: UnityDataAssetPack, config.arm64_v8a）
#   ⚠ >1 GiB：按项目纪律需用户点头后再下
# 拿不到 XAPK 时的备选：Play 路线（需先做 §1.3 的 GApps），或 apkcombo 的 arm64 APK 单项
sha256sum *.xapk | tee SHA256SUMS           # 与站点页面的 SHA-256 逐字比对
unzip -l rednote.xapk | head -30            # 确认 base + config.* 的 split 名
unzip -l limbus.xapk  | head -30            # 确认 base + UnityDataAssetPack + config.arm64_v8a
```
判据：`unzip -l` 里的 split 名与 §2.1/§3.1 记录**逐字一致**；sha256 与站点一致（否则停）。

### 4.2 Step 2a — 单 APK 路线（只对**无 split** 的包；小红书/Limbus 都不适用，留作对照）

```sh
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 \
  timeout -k 10 540 droidloomctl install "$HOME/dl-apps/<single>.apk"
```

### 4.3 Step 2b — 分片路线（**本轮的主路径**）

```sh
cd ~/dl-apps && mkdir -p xhs && unzip -o rednote.xapk -d xhs        # 得 base.apk + config.*.apk
# 【K】【S】安装前先确认 runtime 在跑：droidloomctl status
adb devices -l | grep droidloom                                     # 期望 10.177.0.2:5555 / device:droidloom
timeout -k 10 300 adb -s device:droidloom install-multiple -r \
  xhs/base.apk xhs/config.arm64_v8a.apk xhs/config.xxhdpi.apk
# Limbus（>1 GiB 包，超时放宽）
cd ~/dl-apps && mkdir -p limbus && unzip -o limbus.xapk -d limbus
timeout -k 10 900 adb -s device:droidloom install-multiple -r \
  limbus/base.apk limbus/config.arm64_v8a.apk limbus/split_UnityDataAssetPack.apk
```
判据：`Success`；失败时**原样记录 `Failure [...]`**（这是 §2.3 否证条件 2 的直接证据）。
> 说明：`install-multiple` 走的是 droidloom **自带的 ADB 端点**（上游 `docs/INSTALL.md` §ADB access），不碰设备端的 Waydroid。

### 4.4 Step 3 — 启动与观察

```sh
# 【K】【S】轻量包先跑（小红书）
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 \
  timeout -k 10 300 droidloomctl launch com.xingin.xhs
# 页面/组件名不确定时先查：
adb -s device:droidloom shell cmd package resolve-activity --brief com.xingin.xhs

# 关键日志（另开一路，先起后抓）
timeout -k 10 120 adb -s device:droidloom logcat -v threadtime > /tmp/xhs.logcat &
grep -nE 'FATAL|ANR|SIGSEGV|SIGILL|UnsatisfiedLink|dlopen|shield|Cronet|libxyass|libtinyd|libSystemHealer|libmsahook|msaoaid' /tmp/xhs.logcat | head -50

# 游戏类：Unity/图形关键字
timeout -k 10 180 adb -s device:droidloom logcat -v threadtime > /tmp/limbus.logcat &
grep -nE 'Unity|il2cpp|libunity|Vulkan|GLES|EGL|GfxDevice|Job.Worker|madvise|mprotect|FATAL|tombstone' /tmp/limbus.logcat | head -80
```
判据（L4 同款口径，`TASKS/README.md:99`）：宿主出现**独立 `xdg_toplevel`** 且**用户目视确认可交互**；`logcat` 无 `FATAL`/无 `UnsatisfiedLinkError`。

### 4.5 Step 4 — 失败时抓什么（一次性抓全，别重启了才想起来）

```sh
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 droidloomctl logs -n 500   > /tmp/dl-logs.txt
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 droidloomctl crashes com.xingin.xhs > /tmp/dl-crash-xhs.txt
journalctl --user -u droidloom.service -n 200 --no-pager                                 > /tmp/dl-user.txt
journalctl -b -u droidloomd.service   -n 200 --no-pager                                  > /tmp/dl-droidloomd.txt
adb -s device:droidloom shell 'ls -l /data/tombstones/ 2>/dev/null | tail -5'
adb -s device:droidloom shell 'dumpsys activity activities | grep -m5 -i "topResumedActivity\|mResumed"'
ssh root@192.168.7.1 'dmesg | tail -80 | grep -iE "dpu|atomic|flip|timeout|iommu|gpu"' # 【K】
# 资源侧：CPU 拓扑是否被正确投影（Unity 类缺陷的判据）
adb -s device:droidloom shell 'cat /proc/cpuinfo | grep -c ^processor; getprop | grep -i abi'
```
判据：`/proc/cpuinfo` 的 processor 数 = 8（不是 1）；`ro.product.cpu.abilist` 含 `arm64-v8a`。

### 4.6 Step 5 — 回退（**零残留**）

```sh
# 卸包（保留数据用 -k，不需要就整卸）
adb -s device:droidloom uninstall com.xingin.xhs
adb -s device:droidloom uninstall com.ProjectMoon.LimbusCompany
# 停运行时（不影响 Phosh/Waydroid）
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 droidloomctl stop
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 systemctl --user stop droidloom.service
# 若只是要"回到今天的状态"：不动 phoc、不动 boot（vk187b 已在 boot_b）
```
> 本序列**不需要**碰 `out/phoc-syncobj-arm64-20261111/`（除非做 §2.3 X2 升级后要 A/B 它是否还需要）。

### 4.7 若走 X2 升级（49）——独立的第二个窗口，不与 4.2–4.6 同窗做

```sh
# 49 起 base 是独立包：base 903 MB + image 67 MB + runtime 11 MB（aarch64）
# 摊装到新目录而非覆盖 /opt/dl-test，用新的 /etc/droidloom/cell.json（含 data_dir 指向新目录）
# 判据：droidloom-doctor 仍 0 BLOCK；wayland-info 无 syncobj 也能起 presenter（architecture.md:122-124 的回退）
```

---

## 5. 未取证清单（不得当结论用）

1. **Limbus 的 Unity 版本、渲染后端（GLES3/Vulkan）、是否二次下载资源、是否有反作弊/integrity 校验** —— 全部未取证。
2. **`adb install-multiple` 在 droidloom 的 ADB 端点上能否接受 install-time asset pack** —— 推断可行，**未实测**。
3. **本机 cell 的 Vulkan 能力**（上游只在 OnePlus Pad 4 上记过 Vulkan 1.4/HL1；本机 `msm_dpu` 的 Turnip/Vulkan 状态没有任何记录）。
4. **小红书 shield/OAID 在 droidloom 上的实际判定**（能否只靠 `sDeviceId` 通过；OAID 缺失如何降级）。
5. **麦克风在 cell 内是否真的可用**（上游 audio broker 描述存在，我方从未测）。
6. **`0.1.0-30` 与 `0.1.0-49` 的 CLI 子命令差异**（`logs`/`crashes`/`install`/`backup` 的在版可用性以上机 `--help` 为准）。
7. **`aapt2`/`apksigner` 是否在宿主上**（做 GApps add-on 的前置；本轮未查）。
8. **`LiteGapps-arm64-17.0.zip` 的任何内容**（未下载、未审阅、未钉 sha256）——按纪律不下载、不代为选择来源。

---

## 6. 边界与本轮做了什么

- **做**：GitHub 只读 API/raw（droidloom `main` tree、`docs/{INSTALL,architecture,threat-model-v2,BUILDING}.md`、`docs/contracts/{runtime-layout-v1,text-input-v1}.md`、`runtime/droidloom-contracts/src/gapps.rs`、`tools/droidloom-gapps/src/main.rs`、`runtime/droidloom-supervisor/src/bin/droidloomctl.rs`、`docs/KNOWN_ISSUES.md@826368b1`、releases 资产清单、commit `908aca0f` 说明）；APKPure 两个 App 的包元数据；一份公开的小红书逆向记录（用于风控栈判定）。仓内先例 README/报告逐行核对（行号见正文）。
- **没做**：设备 `ssh`/`adb`/`fastboot`（**0 条**）、装包（0）、下载 >1 GiB 镜像（0；仅拉了 <60 KB 的文本文件）、登录任何账号（0）、改 `TASKS/DEVICE/INDEX/PITFALLS`（0）、发信（0）、全仓 `grep -r`（0）。
- **唯一写入**：本文件。
- **本轮对既有口径的增量**（供 SSOT 参考，**本文件不改 SSOT**）：
  1. `KNOWN_ISSUES.md` 已删除 ⇒ 所有"上游已知限制"引用须钉 commit（否则 404）。
  2. upstream **已在 2026-11-20 把 `linux-drm-syncobj` 变为可选**（presenter 回退到 DMA-BUF fence）⇒ 我们 `out/phoc-syncobj-arm64-20261111` 产物在 ≥49 上**不再是硬前提**（`TASKS/README.md:99` 的"真后端合成器"尾巴可据此降级）。
  3. upstream 已有 `droidloom-devices`（haptics/camera/fingerprint/location，DLDEV001），但**相机要 braun、定位要 dmail** ⇒ 本机这两项目前仍为「缺组件」，与 `reports/droidloom-feasibility-20261108.md` §1.2「相机 broker 不存在」相比是**口径更新**（从"不存在"→"存在但要宿主侧栈"）。

---

## 7. 父代理实物核对（2026-11-25 19:2x，用 vivo 机上真包，非 APKPure 元数据）

同日从 vivo `V2454A`（Android 17 / arm64-v8a）用 `pm path` + `adb pull` 提出真包，落在 `~/apk-20261125/`
（`MANIFEST.md` + `SHA256SUMS`）。用它校对本文 §2/§3 的第三方元数据：

| 项 | 本文（APKPure/第三方） | **机上实物** | 判读 |
|---|---|---|---|
| Limbus 版本 | 1.119.1 (494) | **1.118.0 (487)** | 以实物为准；结论不受影响 |
| Limbus 分片 | "只发 split 包" | **确认**：`base.apk` 32 089 880 B（**无 `lib/` 目录**）+ `split_config.arm64_v8a.apk` 63 989 568 B（19 个 `.so`）+ `split_UnityDataAssetPack.apk` 1 340 289 371 B | **坐实 J2 的「三件必须一起装」**；`droidloomctl install` 单包路径确实装不了 |
| Limbus 引擎 | 未取证 | **Unity IL2CPP**：`libil2cpp.so` / `libunity.so` / `libmain.so` + `assets/bin/Data` 在 base | 补齐 §5-① |
| Limbus 渲染面 | 未取证 | `libvkquality.so`（Unity Vulkan 质量选择）+ `libswappywrapper.so`（Android Frame Pacing / Game SDK）+ `libfmod.so`/`libfmodstudio.so`（音频） + `libresonanceaudio.so` | 至少**不只有 GLES**，Vulkan 路径存在；音频走 FMOD（对 cell 音频 broker 是硬需求） |
| Limbus GMS 耦合 | 未取证 | **`libFirebaseCppAnalytics/Auth/Crashlytics` + `libFirebaseCppApp-12_6_0` + `libcrashlytics*`**；base 的 `META-INF` 里有 **`androidx.credentials:credentials-play-services-auth`** | **新增风险**：无 GMS 时 Firebase 初始化/Auth/Crashlytics 与 Credential Manager 会报错或降级；是否「只刷日志不影响进游戏」需实测 ⇒ 记为 J2 的第 4 个未知 |
| 小红书版本/体积 | 9.49.x / 213.8 MB / 两 split | **9.49.1 (9491803) / 182 655 636 B 单 `base.apk`**（机上 `pm path` 只有 base；本机厂商包未拆 `config.xxhdpi`） | 差异 = 装机来源不同（vivo 应用商店整包 vs APKPure 拆包），**不影响 J3** |
| 小红书 ABI | arm64-v8a + config.xxhdpi | **`lib/` 只有 `arm64-v8a`，157 个 `.so`**，无 x86 目录 | 坐实「aarch64 原生」 |
| 小红书风控栈 | `libxyass` + `libmsaoaidsec` + `libSystemHealer`/`libcapahook` + `libtinyd` | **6 个逐字命中**：`libxyass.so`、`libmsaoaidauth.so`、`libmsaoaidsec.so`、`libSystemHealer.so`、`libcapahook.so`、`libtinyd.so`（另有 `libapkpatch.so`、`libCtaApiLib.so`） | 坐实 J3 的风控判定依据 |

**对 J2 的净影响**：从「3 个未知」变「4 个未知」，其中 **Firebase/Credential Manager 在无 GMS cell 上的行为** 是最可能挡住首启的一项
（比 Unity 拓扑掩码更早触发，因为它发生在 `Application` 初始化阶段）。上机窗验证序列应插一步：
`logcat -s FirebaseInitProvider:* FirebaseApp:* CrashlyticsCore:*` + `pm list packages | grep -c com.google` 作为前置判据。
