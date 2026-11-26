# Limbus Company × AppSealing（INKA v2.35.1.0）—— 「安卓上跑 Limbus」值不值得投（2026-11-26，lane D3）

> **来源**：lane D3（researcher / `custom.ustc-pool/ustc-dsf`）产出；**父代理已就地更正其机制判定**，见文末 §9「父代理更正」——真因是 **root 检测**，不是 emulator 检测。
> 性质：纯只读研究，零设备动作；未发信、未改 `TASKS/`/`INDEX.md`/`PITFALLS/`、未 commit。

- **性质**：纯只读研究。**零设备动作**（本子代理执行环境无 shell 工具，未发 `ssh`/`adb`，未装包、未改任何仓内文件、未 git commit）。结论由「仓内既有上机证据 + 上游/第三方公开材料」合成，**每条标证据级别**。
- **不重推的先例**：`reports/droidloom-deploy-20261126.md`（三 split 装成功、启动即被杀）、`reports/droidloom-app-compat-20261125.md`（J2/J3 静态）、`reports/c3-pi-tiers-closeout-20261110.md` + `reports/c3-spic-verdict-20261115.md`（完整性天花板）、`reports/android-compat-20261026.md`（Waydroid 现态五维）。
- **证据级别标记**：**[实测]** = 设备/本机命令原始输出（引仓内 artifact）；**[静态]** = 读包/源码/文档；**[推断]** = 由前两者外推、未取证。

---

## Summary

**判定：不投。** Limbus 的 Android 版在 droidloom 上被 AppSealing 杀，属于「结构性不可过」而不是「参数没调对」：droidloom 的 cell 是**共享宿主内核的容器**，`system/vendor/product` 按设计不可写且哈希绑定、SELinux 无法装私有策略（日志实测 `setenforce 0`）、无 TEE/验证启动，而 AppSealing 官方能力面明写「Emulator & Rooting Detection —— 直接封虚拟化环境」+ 硬件级 App Attestation。因此**若坚持过检测，必须动的是本项目的形态本身（换成 VM/整机可信链），不是配置**。Waydroid 走的是同一类信号面（同一台机的同一个未签名主线内核、LOS20 userdebug/test-keys、无 TEE、无 Widevine），社区先例是同类反作弊/RASP 直接拒绝 ⇒ **预期同样被杀**（未实测）。而「本机要用安卓跑 Limbus」这件事的**必要性本身不成立**：Steam 有官方 PC 版（ProtonDB/Deck 报 playable），且游戏内提供 **Steam↔mobile 账号 Merge Code**，进度可带过去，而 G3 线本来就在跑 Steam 游戏。

---

## 1. 它到底检什么（检测面清单 + 证据强度）

### 1.1 厂商口径的能力面（这是「上限」而不是「本例命中项」）

| 检测类 | 内容 | 证据 |
|---|---|---|
| **Rooting** | 官方文案："spot rooted devices trying to bypass security"；「Guarantees that any application cannot take the device's root access」 | [静态] [AppSealing/DoveRunner Android App Security 官方页](https://www.appsealing.com/android-app-security/) |
| **Emulator / 虚拟化环境** | 官方文案："**Emulator & Rooting Detection** — Block **emulated or virtualized environments**"；客户评价 "blocking apps on emulator completely" | [静态] 同上页（同一 URL） |
| **App Attestation（硬件背书）** | "New: App Attestation … hardware-backed Android **Key Attestation**"，"when device integrity checks fail (for example on a rooted or instrumented device), access … is denied" | [静态] 同上页 |
| Anti-debugging / Memory Access / Cheat tool / Network sniffing | 常规 RASP 项，非本例关键 | [静态] 同上页 |

> **判读**：厂商自己的功能表已经把「虚拟化环境」列为**一等检测对象**。这意味着「cell 不是 root（su 已被 mask）所以应该能过」这个假设**不成立**（也见 §2.3 的实证）。

### 1.2 具体检哪些文件/属性（第三方逆向记录，版本 2.32/2.33，与本机 2.35.1.0 同族）

| # | 检测面 | 细节 | 证据强度 |
|---|---|---|---|
| 1 | **Root**（弱） | `fopen /proc/self/mountstats`、`fopen /proc/self/environ`（查 su 环境变量）；**逆向作者用 KernelSU / KitsuneMagisk 实测均未被检出** ⇒ 其 root 检查很粗 | [静态] [Appsealing-Reversal](https://github.com/ARandomPerson7/Appsealing-Reversal)（Rooting 节） |
| 2 | 支付绕过 / 系统被改动 | `fopen/open /system/etc/hosts`（只看 hosts 是否被改） | [静态] 同上（Payment Bypass Detection 节） |
| 3 | Anti-debug | 只读 `/proc/<pid>/status` 的 `TracerPid` | [静态] 同上（Debugger Detection 节） |
| 4 | Frida | 扫 `/proc/self/task/<tid>/status` 的任务名 | [静态] 同上（Frida Detection 节） |
| 5 | **USB 调试 / 开发者选项** | 逆向作者明确列为「自解释」的检测项 | [静态] 同上（Others 节） |
| 6 | **按包名拉黑的应用清单** | `AndroidManifest.xml` 里直接列 `<package android:name="…">`（MT Manager、SSL 抓包类、作弊类），**不需要 `QUERY_ALL_PACKAGES`** | [静态] 同上（AndroidManifest 节） |
| 7 | **上报的设备画像**（本地测后上报 SQS） | Country / Package / AppVersion / AndroidVersion / **Model / Manufacturer / DeviceID / SDK / Hardware / CPU Arch / Kernel Version / Display / Brand** | [静态] 同上（Java 节） |
| 8 | **退出机制** | `AppSealingAlertDialog.showAlertDialog` 倒计时 → `killMyProcess`；native 侧 `kill`/`signal`/`alarm`，**2.33 起改用裸 `__NR_kill`+`__NR_exit` 系统调用** | [静态] 同上（Exit Routine + Update 节） |
| 9 | **本机可取证的中文明细文件** | 检测结果**明文**写到 `/data/user/0/<pkg>/.sealing_reports/<pkg>`（未加密） | [静态] 同上（Java 节） —— **这是本工单最便宜的决定性下一步（见 §5）** |

### 1.3 本机 logcat 直接读出的东西（[实测]，`reports/artifacts/droidloom-deploy-20261126/limbus-appsealing-log.txt`）

时间线（同一进程 2208，第二次启动）：

```
38.271 D AppSealing: [JAVA] AppSealingLoader ...
38.271 I AppSealing: BUILD VERSION : 2.35.1.0 / DATE : Sep 22 2025 03:34:21 / ASBA:0xfffc38e02000
38.282 I AppSealing: Initiate AppSealing Security : ARM64 (Core Version = C220605-002)
38.283 D nativeloader: Load .../lib/arm64/libcovault-appsec.so ... ok
38.400 E AppSealing: !!!!!!!!!!! Kill Process ..........................[20059]      ← ~117 ms 后
38.762 I ActivityTaskManager: START ... com.inka.appsealing.AppSealingAlertDialog
38.811 I Process : Sending signal. PID: 2208 SIG: 9                                ← 由 alert_dialog 进程执行
38.823 I ActivityManager: Process com.ProjectMoon.LimbusCompany (pid 2208) has died
```

由此可确证的 5 件事：

1. **触发在极早期**：`Initiate AppSealing Security` 后 ~117 ms，**早于** Unity/IL2CPP 起来（38.75 才 `IL2CPP: JNI_OnLoad`）⇒ 与引擎、CPU 拓扑、GPU、资产包**无关**。[实测]
2. **纯本地判定**：同段日志里 Firebase 全部因无网失败（`Unable to resolve host "firebase-settings.crashlytics.com"`）⇒ 杀掉发生在**没有任何服务端往返**之前 ⇒ **不是**服务端 attestation / 画像评分（这很重要，见 §2）。[实测]
3. **AppZygote 也被同一层接管**：`Process 2283 created for com.ProjectMoon.LimbusCompany_zygote` → `AppSealing: Initiate AppSealing Security : ARM64` → 由它 fork 出 `:ip_service`（isolated uid 90000）与 `:alert_dialog`；**杀主进程的正是 `:alert_dialog`**。[实测]
4. **cell 的三条「可疑环境」特征是日志直接可见的**：
   - `Zygote: seccomp disabled by setenforce 0`（每个 fork 的进程都打一行）⇒ **cell 处于 SELinux permissive**；[实测]
   - `E libprocessgroup: set_timerslack_ns write failed: Read-only file system` ⇒ 系统分区**只读**（与 threat model 一致）；[实测]
   - Unity 侧 `Device Model 'Lenovo Lenovo Legion Y700 Gen4'`, `OS 'Android OS 17 (API 37)'`（真机型号 + 非该机型的 Android 17）与 `PlayCore … Asset Pack Download Error(-11): The Play Store app is either not installed or not the official version` / `GooglePlayServicesUtil: requires the Google Play Store, but it is missing` ⇒ **无 GMS 且画像自相矛盾**。[实测]
5. **不是「APK 被改」**：`W n.LimbusCompany: Failed to find entry 'classes.dex': Entry not found` 出现在 base 进程与 alert 进程两边 —— 与逆向记录里「AppSealing 把 dex 封进 assets、由 `libcovault-appsec` 用 `InMemoryDexClassLoader` 解密加载」的描述**逐字吻合** ⇒ 这是封壳自身的形态，不是我们的安装把包改坏了（三件 sha256 与 `~/apk-20261125/SHA256SUMS` 一致，`droidloom-deploy-20261126.md` §1）。[实测 + 静态]

### 1.4 命中项排序（[推断]，按现有证据强弱）

| 排序 | 候选触发面 | 为什么怀疑 | 怎么证伪（只读命令） |
|---|---|---|---|
| 1 | **SELinux 非强制（permissive）** | 每个进程都打 `seccomp disabled by setenforce 0`；这是「自定义/被 root 过的 ROM」的经典判据，且**在共享宿主内核的容器里无法关闭**（§2.1） | `nsenter … getenforce` / `cat /sys/fs/selinux/enforce` |
| 2 | **容器/虚拟化痕迹** | 逆向记录里 root 检查第一个动作就是 `fopen /proc/self/mountstats`；droidloom 的挂载表（bind/合成 root、`/newroot` 前缀——上游 `libdroidloom_selinux_compat` 专门为它做 `readlink` 重写）与真机差异极大 | `nsenter … cat /proc/self/mountstats`、`cat /proc/1/mountinfo` |
| 3 | **USB 调试 / adb 端点** | droidloom **按设计自带 cell 内 adb 端点**（`10.177.0.2:5555`），`ADB_ENABLED` 类设置大概率是开的；AppSealing 明确列了 USB debugging 检测 | `nsenter … settings get global adb_enabled`、`getprop | grep -i debug` |
| 4 | 拉黑包清单命中 | Manifest 直接列包名；本 cell 只有 Files/Settings/droidloom-home 等少数包，**未见命中**，但要核 | `nsenter … pm list packages` + 与清单比对 |
| 5 | Widevine / DRM 缺失 | 本机容器连 L3 库都没有（`c3-pi-tiers-closeout §3`），但**没有证据**说明 Limbus 会因 DRM 自杀，且杀点早于任何媒体初始化 | 看 `.sealing_reports` 明细 |

> **诚实边界**：**具体命中的是哪一位，本轮没有证据可以钉死**（AppSealing 只在 native 里判、日志只打 `Kill Process`）。但**这不影响结论**——第 1、2 位都属于 droidloom 的形态事实（不是可调参数）。

---

## 2. droidloom 这条路：有没有可行解

### 2.1 cell 是「按设计带 root 且可写」吗

| 问题 | 答案 | 证据 |
|---|---|---|
| App 能拿到 root 吗 | **不能**。上游自 release **44 起每个 cell 用空目录覆盖 `/system/xbin`**，app 在 `PATH` 上找不到 `su`（issue #33 的官方回复） | [静态] [issue #33](https://github.com/denialwm/droidloom/issues/33)（2026-11-18 建、当日 close）；**本机印证**：`device-config-snapshot.txt` 的 `android_file_overrides` 里有 `compat/no-su → /system/xbin` [实测] |
| 那「root」在哪 | **Android 的 uid 0 = 宿主 root**（cell 跑在初始 user namespace，`/proc/<pid>/uid_map = 0 0 4294967295`）——即**特权面存在，但不给 app** | [静态] [issue #19](https://github.com/denialwm/droidloom/issues/19)（正文 Root cause 第 3 点） |
| 系统分区可写吗 | **不可写**（`system/vendor/product` 不可变 + 包签名 + 哈希绑定；`/data` 是唯一常规可写面）。改系统只能**在宿主侧重打镜像或加 `android_file_overrides`** | [静态] [threat-model-v2](https://raw.githubusercontent.com/denialwm/droidloom/main/docs/threat-model-v2.md) 强制控制 9 |
| 因此「与可调系统分区的设计冲突吗」 | **不冲突**：属性级伪装（build.prop、`/system` 文件覆盖）恰恰是上游已支持、我们也已经在用的机制 | 同上 + `device-config-snapshot.txt` 的 `overrides/vendor/build.prop` [实测] |

### 2.2 上游对反作弊/RASP 有先例吗

- GitHub issue 全库检索 `anti-cheat OR appsealing OR "root detection"` ⇒ **total_count = 1**，只有 #33（su 误报）。**没有任何 AppSealing/INKA/反作弊类被杀的先例**；#33 里唯一提到的受害 App 是 Golf Battle（root 门）。[静态] 实查 [GitHub Search API：issues?q=repo:denialwm/droidloom anti-cheat OR appsealing OR "root detection"](https://api.github.com/search/issues?q=repo%3Adenialwm%2Fdroidloom+anti-cheat+OR+appsealing+OR+%22root+detection%22&per_page=20) → `total_count:1`。
- 上游对这类诉求的定位是**明写不承诺**：*"Android SELinux cannot install a private policy into a conventional shared host kernel. **Protected media, hardware attestation, and Play Integrity are not supported claims**."* 以及 *"version 2 does **not** claim VM-equivalent containment"*。[静态] [threat-model-v2](https://raw.githubusercontent.com/denialwm/droidloom/main/docs/threat-model-v2.md)

### 2.3 要过检测必须隐藏哪些面、代价多大

| 面 | 能不能隐藏 | 代价 / 是否越界 |
|---|---|---|
| `su` 二进制 | ✅ 已做（≥44） | 0（已完成） |
| release 风格 build 元数据（`ro.debuggable`/`test-keys`/`dev-keys`/adb root） | ✅ 上游已在投影；不够还可以加 `android_file_overrides` | 低（小时级） |
| USB 调试 / 开发者选项 | ⚠️ 可关，但 **adb 端点正是我们装 split 的唯一通道**；且这是猫鼠项 | 中（要另找安装通道） |
| `/proc/self/mountstats` 等容器痕迹 | ❌ 基本不可能干净隐藏（挂载表就是容器形态；droidloom 还有 `/newroot` 合成路径） | 高（要改 Android framework/挂载投影，等于自研反-反作弊） |
| **SELinux 强制** | ❌ **形态级不可能**：宿主内核装不了私有策略 | 结构性 |
| **验证启动 / 镜像签名 / 认证 build** | ❌ 镜像是自建 AOSP（第三方构建，非 Google 认证） | 结构性 |
| **硬件背书 attestation（Key Attestation / TEE）** | ❌ 本机 EL2 归签名 Gunyah、BL 已解锁 ⇒ 整机层面就没有 green verified boot（`c3-pi-tiers-closeout` §2.3、`DEVICE/README.md` §1） | 结构性 |
| **AppSealing 自身的 kill 逻辑** | ❌ 要 patch native（Dobby/Xposed 或 NOP `svc`）——这正是「反篡改对抗」，**超出本项目边界**（`TASKS` §6「不做」+ 本轮派工单明写不做绕过） | 越界 |

### 2.4 二值结论

> **droidloom：❌ 不可行（无合规可行解）。**
> 理由：命中面上有 **3 项结构性不可关闭**（SELinux 强制 / 签名与验证启动 / 硬件背书 attestation），其余项即便全做也只是「把猫鼠游戏起点往后挪」，而 AppSealing 从 2.33 起用裸 `__NR_kill` 自杀、每次 OTA 都可能换判据；任何进一步手段都落到「patch 保护壳」= 反篡改对抗，已在项目边界之外。
> **代价量化**：不是「再花 1–2 天调参」的量级，而是**要改项目形态（换 VM + 可信启动链）**，与本机「整机已解锁、EL2 不归我们」直接冲突 ⇒ 投多少都不收敛。

---

## 3. Waydroid 对比：会不会一样被杀

### 3.1 先纠正一个前提

「AppSealing 只在 root 上触发」**不成立**：官方能力面把「emulated or **virtualized** environments」与 rooting 并列为一级检测项（§1.1）。所以「Waydroid 不是 root ⇒ 可能没事」这个推理链本身是错的。

### 3.2 我们已有的 Waydroid 现态（不重测，直接引用）

| 项 | 现态 | 来源 |
|---|---|---|
| 形态 | R1 容器：`lineage-20.0-…-GAPPS-waydroid_arm64_only`（**A13**）+ Phosh 宿主；会话**不随桌面自启**（`Session: STOPPED`，需手动起） | `reports/android-compat-20261026.md` §1（实测/历史实测） |
| GMS | **可用**：账号 `xuqianhui176@gmail.com` 已登录、`gstatic/generate_204`=204（经宿主代理） | `c3-pi-tiers-closeout` §0/§1 F2–F3 |
| 完整性 | **`deviceRecognitionVerdict = []`**（SPIC v1.4.0 一次回包，2026-11-15）⇒ BASIC/DEVICE/STRONG **全不满足** | `c3-spic-verdict-20261115.md`（引于 G2.md C3 行） |
| 属性 | `ro.build.type=userdebug`、`ro.build.tags=test-keys`、fingerprint = `waydroid/lineage_waydroid_arm64_only/…:userdebug/test-keys`；但 `ro.secure=1`、**`ro.debuggable=0`**；`first_api_level=28` | `c3-pi-tiers-closeout` §1 F1 [实测] |
| DRM | **Widevine 完全不存在**（`/vendor/lib64/mediadrm/` 只有 ClearKey）；keymaster 4.0 软实现（无 TEE） | 同上 §1 F4/F5 |
| 反作弊/强检测 App 样本 | **未做**（原文："App 兼容性问题（银行/强检测类）未做样本"） | `android-compat-20261026.md` §1 可用性行 |
| 网络 | **通**（`curl baidu=200`，netd 自建路由表） | `reports/wd-netd-route-20261011.md`、G2.md C1 行 |

### 3.3 两条路线逐项对比（谁更「像真机」）

| 维度 | droidloom（本机 0.1.0-49） | Waydroid（本机 LOS20/GAPPS） | 差异是否救得了 Limbus |
|---|---|---|---|
| ARM 转译 | 无（aarch64 宿主原生跑 arm64，无需 libhoudini/libndk） | 无（同上；ArchWiki 明写 Waydroid 不做架构翻译） | ❌ 两者都干净，不是区分项 |
| `ro.kernel.qemu` | 不是 QEMU（namespace 容器） | 不是 QEMU（LXC 容器） | ❌ 该项**两者都不会命中**（[推断]，未实测） |
| `ro.hardware*` | 上游用 `overrides/vendor/build.prop` 覆盖（本机 snapshot 可见） | 镜像里 `ro.hardware.egl=mesa`/`vulkan=freedreno`（`android-compat-20261026` §1 图形行），并可用 `waydroid prop set` / `waydroid.cfg [properties]` 覆盖（[官方 Prop 文档](https://docs.waydro.id/usage/waydroid-prop-options)） | ❌ 都能改，**不是结构性差异** |
| 构建标签 | 上游**投影 release 风格**（清 `ro.debuggable`、替 `userdebug/test-keys/dev-keys`、禁 adb root） | **实测仍旧 `userdebug` + `test-keys`**（`ro.debuggable=0` 已好一点） | ⚠️ Waydroid 这边**更差**，但可用 prop 覆盖补（社区脚本 [waydroid-small-cookie-fixer](https://github.com/ViviNoSmol/waydroid-small-cookie-fixer) 就是干这个） |
| SELinux | **permissive**（日志 `setenforce 0`，`libdroidloom_selinux_compat` 把策略操作全变 permissive/stub） | 同样非强制（宿主内核无 Android 策略） | ❌ 同一台机的同一个内核，**这一项两条路完全一样** |
| 内核签名 / 验证启动 | 无（自编 mainline `7.3.1-debug-vk189…`，BL 已解锁） | **同一个内核**，同样没有 | ❌ **结构性相同** |
| 硬件 attestation / TEE | 无 | 无（EL2 归签名 Gunyah） | ❌ 相同 |
| GMS / 网络 | 无 GMS、**cell 当前无网**（D2 lane） | 有 GMS、有网 | ⚠️ Waydroid 只在「过了检测之后」才有优势 |
| 已知先例 | issue #33（Golf Battle root 门，已修） | **多起**：NIKKE 反作弊报 rooted（[#1231](https://github.com/waydroid/waydroid/issues/1231)）、LIAPP「Api hooking … Debugging has been detected」（[#1060](https://github.com/waydroid/waydroid/issues/1060)）、Sky Go root 检测（#1060 评论） | ❌ Waydroid 的先例**更多、更近**本案 |

> 补充（[静态]，社区证据强度中等）：[AWAKE packer wiki](https://awakewiki.org/packers/) 说 AppSealing「generally workable in emulators **with basic evasion**」——那说的是**分析/脱壳可行性**，不是「开箱能过」；且我们的形态是「permissive SELinux 的共享内核容器」，不是主流模拟器。

### 3.4 二值结论

> **Waydroid：⚠️ 预期同样被杀（中高置信，未实测）。**
> 依据：① 同机同内核，SELinux/签名/TEE 这三项与 droidloom **完全一致**；② Waydroid 的 build 标签比 droidloom **更差**（`userdebug/test-keys` 实测）；③ 厂商把虚拟化环境列为一等检测项；④ Waydroid 社区同类检测先例多。
> **未取证项**：没有在 Waydroid 上真跑过 Limbus（本轮零设备动作，且 D3 派工单明写「别重测」现有 Waydroid 结论）。

---

## 4. 能否绕开（不违规的合法路径）

| 路径 | 可行吗 | 证据 |
|---|---|---|
| **官方包直装（单 APK，不走 split staging）** | ❌ **不存在这种包**。Limbus 只发 split 三件：`base.apk` 32 089 880 B（**无 `lib/` 目录**）+ `split_config.arm64_v8a.apk`（19 个 `.so`）+ `split_UnityDataAssetPack.apk` 1.34 GB。只装 base 必 `UnsatisfiedLinkError`（连 `libunity.so` 都不在） | [实测] `reports/droidloom-app-compat-20261125.md` §7 机上实物核对 |
| **官方 PC 版（Steam）** | ✅ **有，且在 Linux 上能跑**：Steam app **1973530**；ProtonDB 报 playable（"It should work with Proton from steam itself"），Steam Deck 用户反馈 playable，pcgame 判 "runs on Steam Deck with some adjustments" | [静态] [ProtonDB 1973530](https://www.protondb.com/app/1973530)、[Steam 商店页](https://store.steampowered.com/app/1973530/Limbus_Company/)、[Steam 讨论（Deck 可玩）](https://steamcommunity.com/app/1973530/discussions/0/509577488802798887/) |
| **账号/进度能不能带过去** | ✅ **能**：游戏内 `<Settings> → <Account> → Send Merge Code / Merge Code Input` 用于合并 Steam 与 mobile 账号；多名玩家确认两平台进度同步 | [静态] [Steam 讨论：cross saves](https://steamcommunity.com/app/1973530/discussions/0/3771239453235400980/)、[how does limbus save data on steam](https://steamcommunity.com/app/1973530/discussions/0/5950985868224042013/) |
| 我们这边跑 PC 版的基础 | ✅ G3 线（Box64 + Wine/Proton，Steam 游戏为验收载体）**已在跑**（Win-x86 PoC 已完成，`TASKS/G2.md` C-历史行）；本机有 Steam 生态与 Adreno/Mesa 图形栈 | [实测/历史] `TASKS/G2.md` §2 C-历史 |

**另一个「安卓路线天然更差」的点（[实测]）**：即使 AppSealing 放行，mobile 版还依赖 Play Store 的资产包服务 —— 日志里 `PlayCore: Asset Pack Download Error(-11): The Play Store app is either not installed or not the official version`、`GooglePlayServicesUtil: requires the Google Play Store, but it is missing`。在不装 GApps 的 cell 上这是一条独立风险；装了 GApps 也只是把它变成 `uncertified`（`droidloom-app-compat-20261125.md` §1.1）。

> **所以「本机要用安卓跑 Limbus」的边际价值 ≈ 0**：目的（玩 Limbus、保住进度）已被「Steam 版 + Merge Code」完全覆盖，且 G3 是项目正式目标线；安卓侧每前进一步都要跟 RASP 打猫鼠。

---

## 5. 结论（二选一）+ 最小下一步 + 止损

### 结论：**不投**（Limbus 不在 droidloom/Waydroid 上继续投入）

三条理由：
1. **结构性命中面不可关闭**：SELinux permissive（实测 `setenforce 0`）+ 无验证启动/签名 + 无 TEE/attestation —— 这三项是 droidloom 与 Waydroid **共有**、且威胁模型明写「不做承诺」的部分；想过检测要改项目形态（VM + 可信启动链），与本机「BL 已解锁、EL2 归签名 Gunyah」直接冲突。
2. **非结构性项也是无底洞**：容器挂载痕迹、adb/USB 调试、build 画像，每项都要跟一个「native 裸 `__NR_kill` 自杀 + 每次 OTA 换判据」的 RASP 赛跑；再往前一步就是 patch 保护壳 = **反篡改对抗**，已在项目边界外（派工单也明写不做绕过）。
3. **需求本身被更便宜的合法路径覆盖**：Steam 官方 PC 版 + 账号 Merge Code，G3 线已在跑；mobile 版还额外依赖 Play Store 资产包（实测 -11）。

### 若要留一行实测（可选，成本极低，按「先只读」做）

| 步 | 动作（只读） | 目的 |
|---|---|---|
| ① | `nsenter --target <cellpid> … cat /data/user/0/com.ProjectMoon.LimbusCompany/.sealing_reports/com.ProjectMoon.LimbusCompany` | **决定性**：明文报告里直接写着命中了哪些检测项（[静态] 逆向记录）——一条命令就能把 §1.4 的排序变成事实 |
| ② | 同上 `getenforce`、`settings get global adb_enabled`、`head -50 /proc/self/mountstats` | 把 §1.4 候选 1–3 逐个钉死/排除 |
| ③ | 若台账要一条 upstream 记录：把 §1.3 的 logcat 摘要 + `.sealing_reports` 明细提 issue 到 `denialwm/droidloom` | 上游 issue 库里**没有** AppSealing 先例（`total_count=1`），这条对上游有信息量；**不承诺修** |

### 止损条件（任一命中即收手，不再追加）

- 需要 patch `libcovault-appsec.so` / hook `kill`（= 反篡改对抗）；
- 需要改 SELinux 强制、镜像签名、attestation（= 项目形态变更，另立项且与解锁事实冲突）；
- 需要关 adb 端点（会切断我们唯一的 split 安装通道，成本大于收益）；
- AppSealing 版本一升（本机 2.35.1.0，Sep 22 2025 构建）就要重做一轮判据 —— 即「不收敛」信号。
- 时间箱：若要做 ①②，**一次上机窗（≤30 min）** 内做完；超出即按「不投」结项。

---

## Contradictions

1. **「AppSealing root 检查很弱」↔「我们被当场杀」**。逆向记录说 KernelSU/KitsuneMagisk 都没被检出（[Reversal](https://github.com/ARandomPerson7/Appsealing-Reversal)），而我们并非 root 却被杀 → **两者不矛盾**，但正好把「命中项不是 su/root」这一点钉住（本机也已 mask `/system/xbin`）。记录在此，防止后人用「root 检查弱」反推「应该能过」。
2. **「AppSealing 在模拟器里 basic evasion 就能分析」↔「我们开箱被杀」**。[AWAKE wiki](https://awakewiki.org/packers/) 说的是**脱壳分析**可行，不是**放行**；且我们的 SELinux permissive + 共享内核容器与 QEMU/主流模拟器画像不同。两者口径不同，不构成冲突，但引用时必须分清。
3. **本机日志一处细节需保留争议**：`Kill Process [20059]` 里的 20059 与当时的 PID（2208）**不一致**；第二次启动里真正杀主进程的是 `:alert_dialog` 进程的 `Process … SIG: 9`。⇒ 「Kill Process 行是 native 侧先手（先打日志再由 dialog 执行）」是**推断**，未取证。

## Missing evidence

1. **到底命中哪一项**：未拿到 `.sealing_reports` 明文报告（本轮无 shell 工具）。这是唯一能把 §1.4 变成事实的东西。
2. **cell 内 adb/开发者选项状态**：`settings get global adb_enabled`、`getprop | grep -i debug` 未取。
3. **cell 的属性全量 dump**：只有间接证据（Unity 打出的 Model/OS、`libprocessgroup: Read-only file system`、`setenforce 0`），没有 `getprop` 全量表，无法核 `ro.build.tags`/`ro.debuggable` 的实际投影值。
4. **Waydroid 上跑 Limbus 未实测**（本轮按派工单不重测；判「预期被杀」为中高置信推断）。
5. **Limbus mobile 是否强制 Play Store 资产包**：只有 `PlayCore -11` 报错这一条日志，是否致命未验证（反正已被 AppSealing 挡在前面）。
6. **AppSealing 2.35.1.0 的具体判据集**：逆向记录基于 2.32/2.33，虽同族但 2.35 是否新增 SELinux/容器判据**未取证**（`DATE Sep 22 2025` 比那份记录新）。

## Sources

- **Kept**
  - [denialwm/droidloom issue #33 — Root detection false positive `/system/xbin/su`](https://github.com/denialwm/droidloom/issues/33) — 唯一直接回答「cell 有没有 su / 上游遮了什么」的原文；含 release 44 的修复承诺。
  - [denialwm/droidloom issue #19 — FUSE abort](https://github.com/denialwm/droidloom/issues/19) — 唯一公开披露「cell 在初始 user namespace、Android uid 0 = 宿主 root」的原文（对「是否带 root」定性必需）。
  - [droidloom docs/threat-model-v2.md](https://raw.githubusercontent.com/denialwm/droidloom/main/docs/threat-model-v2.md) — 不可变系统/哈希绑定 + 「SELinux 装不了私有策略」「attestation/PI 不承诺」的权威出处。
  - [Appsealing-Reversal（第三方逆向）](https://github.com/ARandomPerson7/Appsealing-Reversal) — 检测面文件清单、退出机制（含 2.33 起裸 syscall kill）、`.sealing_reports` 明文报告位置；本案最有用的操作性线索。
  - [AppSealing / DoveRunner 官方 Android App Security 页](https://www.appsealing.com/android-app-security/) — 厂商自述「Emulator & Rooting Detection 封虚拟化环境」+ 硬件背书 App Attestation = 上限判定的权威依据。
  - [waydroid/waydroid #1231](https://github.com/waydroid/waydroid/issues/1231)、[#935](https://github.com/waydroid/waydroid/issues/935)、[#1060](https://github.com/waydroid/waydroid/issues/1060) — Waydroid 被 root/调试类检测拒绝的社区先例（含 NIKKE、LIAPP、Sky Go）。
  - [waydroid 官方 Prop 文档](https://docs.waydro.id/usage/waydroid-prop-options) — Waydroid 属性可覆盖（说明「属性伪装」两条路线都不构成护城河）。
  - [ProtonDB: Limbus Company](https://www.protondb.com/app/1973530) + [Steam 商店页](https://store.steampowered.com/app/1973530/Limbus_Company/) + [Steam 讨论（Deck 可玩 / Merge Code）](https://steamcommunity.com/app/1973530/discussions/0/3771239453235400980/) — 替代路径与进度迁移的依据。
- **Rejected / deprioritized**
  - [AWAKE packers wiki](https://awakewiki.org/packers/) — 只说「分析可行性」，容易被误读成「能过」；仅留作口径澄清（§Contradictions 2）。
  - [XDA AppPealing（Xposed 绕过模块）](https://xdaforums.com/t/mod-xposed-14-compatible-apppealing-bypass-disable-inka-appsealing.4678853/) — 属「反篡改对抗」，**按项目边界不采用**，仅作「这类保护壳确有公开绕过面」的背景。
  - waydroid-small-cookie-fixer / waydroid-helper 等 props 修改工具 — 只用于说明「属性层可改」，不作为方案。
  - 各类 SEO 型「root 检测已死」博客 — 无本机相关性，弃。

## Next steps

1. **（唯一有决定性的）** 一次 ≤30 min 只读上机窗：读 `.sealing_reports` 明文 + `getenforce` / `adb_enabled` / `mountstats`（命令见 §5 表）。这一步只服务「记录事实」，**不改变「不投」结论**。
2. 把 §1.3 的 logcat 摘要 + 上一步明细提 issue 到 `denialwm/droidloom`（上游 issue 库无 AppSealing 先例；与其说求修，不如说留档）。
3. 把 Limbus 的验收载体正式切到 **G3 / Steam + Proton（+ Merge Code 迁进度）**，安卓侧仅保留「小红书」这一条已上屏样例。

---

## §9 父代理更正 + 决定性新证据（2026-11-26T09:2xZ，设备只读现查）

**lane D3 的「结构性不可过」判定在机制上判错了层**：它把死因归到「emulator/虚拟化环境检测 + App Attestation」，
而设备上 AppSealing **自己写的明文检测报告**已经指名真因。

**证据**（只读，未改任何文件）：`/var/lib/droidloom/users/1001/data/data/data/com.ProjectMoon.LimbusCompany/.sealing_reports/com_ProjectMoon_LimbusCompany/`
下每轮启动一份 `.hkr/.ro/.str` 三件（未加密，`|*|` 分隔的 key`^`value 表）。三次启动（07:06:31 / 07:13:52 / 07:14:38 GMT）逐字：

```
Root_Detection^1
Emulator_Detection^            ← 空
Emulator_ProductName^          ← 空
Emulator_Version^              ← 空
HOUDINI_SYSTEM^                ← 空
KERNEL_VER^7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0
ErrCode^20059
msg^[20059] Launching the App on rooting device is not allowed. The APP will be closed.
hackingDetectedTimeFromLaunch^43 / 77 / 82   ← 毫秒级
```

**修正后的判读**：
1. **命中项 = `Root_Detection=1`**；emulator/Houdini 三项**全空** ⇒ 它不认为这是模拟器，是「root 设备」。D3 报告 §1.1 把厂商能力表当成本例命中项，**是错的**（能力表 ≠ 命中项）。
2. 因此 D3 的「必须换 VM/整机可信链才有解」不成立：这是**弱判据**（第三方逆向记录：它只看 `/proc/self/environ`、`/proc/self/mountstats`、`/system/etc/hosts`、`TracerPid`、任务名，且逆向作者用 KernelSU/KitsuneMagisk 实测**均未被检出**）。
3. 但这**不等于值得投**：cell 是按设计「宿主内核 + 可写系统分区 + permissive SELinux」的容器（`androidboot.selinux=permissive` 在 `/run/droidloom/cells/u1001/android-cmdline` 实测），要让 root 信号消失需要动形态本身；而 **Steam 版本来就能跑**（G3，`~/limbus-auto` + `limbus-switch` 已在用），游戏内还有 Steam↔mobile Merge Code 可带进度 ⇒ **结论仍是「不投」**，只是理由从「结构性不可过」改为「能绕但代价不合理」。
4. **可复核的下一步（不再派发）**：若要把它做成数据点，最便宜的实验是上面三个 root 信号逐个消掉后看 `Root_Detection` 是否变 0；成本 ≈ 一次设备窗，收益仅为「知道它到底看哪条」，**不产生可用能力**。
