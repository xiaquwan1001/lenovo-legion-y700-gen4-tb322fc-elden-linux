# G2 安卓兼容调查（lane F）— 2026-10-26

> 角色：`android-compat`（`.pi/agents/android-compat.md`），批次规划 lane F。
> 台架：**U?（SN 未读，见 §6 说明）**，在机 Linux `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163`，
> Alpine 3.24.2，`/` = `f2fs`（linux18）。设备经 `ssh root@192.168.7.1` **只读探测**：
> **未装包、未写盘配置、未重启、未登录 Google 账号、未启停 Waydroid 会话**。
> 唯一写入设备的是两条**探针临时文件**（`/tmp/.probe.{out,err}`，用于捕获 Wayland registry dump），**已删除**；无其它设备写。
>
> 分级口径：**【实测】** = 本轮在机命令原始输出；**【静态】** = 镜像/文件/源码/配置读出，未运行；
> **【推断】** = 由前两者推出、未直接观测。**未取证**一律写「未取证」。
>
> 承接：`TASKS/README.md` §2（C0–C11）、§5 Q1/Q3/Q29、§6；
> `RESOURCES/README.md` §1.3；`reports/{c3-identity-drm-20261013,container-audio-20261011,waydroid-camera-provider-rootcause-20261019,closeout-q29-backlight-camera-20261023,waydroid-droidloom-userland-interface-20261026,mail-triage-20261026}.md`；
> `PITFALLS/sessions/24-Waydroid容器.md` #189–#191。

---

## §0 一页结论

### 0.1 三个二值判断

| # | 判断 | 结论 | 依据级别 |
|---|---|---|---|
| **J1** | 「**不依赖 Android 宿主**」下 G2 日常可用性是否成立？ | **成立（TRUE）** | 实测 + 静态（历史实测汇总） |
| **J2** | 身份/完整性是否已达到「过 Play Integrity **device** 判定 + 拿到**任一** Widevine 等级」？ | **未达到（FALSE）**；且 **STRONG 结构性否证** | 实测（镜像/节点）+ 静态（HAL 实体） |
| **J3** | **droidloom** 现在是否应立项替换 Waydroid？ | **否（FALSE，维持「只跟踪」）** | 实测（合成器全局）+ 静态（发布包/上游验证范围） |

**附（本 lane 需记账的第 4 条）**：**C5/U7「相机 App 实开预览」未通（FALSE）** —— 卡点已换：
`config_nodes` 的 `/dev/video100` bind **已在**（静态），但**当前内核 UTS 没有 `v4l2loopback.ko`**（实测 `modinfo` 失败、`extra/` 不存在），
`/dev/video100` 根本不存在 ⇒ `optional` bind 静默跳过；且镜像内**无相机 APK**（静态）。

### 0.2 五维分数（口径同 `TASKS/README.md` §6 §1：1 不可用 / 3 可用有坑 / 4 日常够用 / 5 等同真机）

| 维度 | 分数 | 一句话证据（详见 §1） |
|---|---|---|
| 可用性（App 能装能跑） | **4.0** | GMS 登录 + Play 53.4.34 + 多 app 跑过（历史实测）；当前 `Session: STOPPED`，需手动起 |
| 图形 | **3.5** | freedreno/Mesa 26.1.8 真 GLES 3.2；宿主 165 Hz 在跑；**U6 游戏帧率未测**、单窗口 |
| 输入 | **3.5** | 触屏/键鼠透传 + 中文 IME（宿主侧已验收）；**容器内 IME 未验** |
| 音频 | **3.5** | 播放 + 录音通路均实测通；**延迟未量化** |
| 身份/完整性 | **2.0** | GMS 登录 4 分，但 **PI basic/device/strong 未取证或结构性不可达**、**Widevine 完全不存在** |
| **综合（等权）** | **3.3 / 5** | 与 `TASKS §0`「G2 ~65%」口径一致（不重算总账） |

---

## §1 五维评估（含「不依赖 Android 宿主」下的已通/未通）

> 形态 = **R1 Waydroid 容器（LOS 20 / A13 `lineage_waydroid_arm64_only`）+ 宿主 Phosh 0.55**，**a 槽不参与**（本轮未触碰）。

| 维度 | 已通（实测/历史实测） | 未通 / 有坑 | 级别 |
|---|---|---|---|
| **可用性** | 容器引导到 `sys.boot_completed=1`；GMS 26.37.37 / Play 53.4.34 登录；`waydroid app install` 可用；GMS/Play/Recorder/DeskClock 实际运行过 | 会话不随桌面自启（现在 `STOPPED`）；`waydroid status` 只报 Session/Vendor；App 兼容性问题（银行/强检测类）未做样本 | 历史实测 + 本轮实测（状态） |
| **图形** | `/dev/dri/card0` = `qcom,sm8750-dpu`（实测）；`renderD128` 在；宿主 `wlr-randr` = **1904×3040 @165 Hz current**（实测）；容器 `ro.hardware.egl=mesa`、`vulkan=freedreno`、`ro.opengles.version=196610`（静态）；历史实测 `GLES: freedreno, Adreno 830, OpenGL ES 3.2 Mesa 26.1.8` | **U6 游戏 30 fps 未测**；`show-full-ui` 单窗口（不满足 U9 多窗口）；Mesa bind 已按 Q29 收口（无 workaround） | 实测 + 静态 |
| **输入** | 宿主输入设备齐全：`NVTCapacitiveTouchScreen` / `pmic_pwrkey` / `gpio-keys` / `aw86927-haptics` ×2 / headset jack（**实测** `/proc/bus/input/devices`）；C11 触屏中文 IME 已上机验收（历史实测） | **容器内 IME 未验**（C11 记账）；`/dev/input` 透传依赖 LXC bind；droidloom 形态下输入所有权语义不同（§4） | 实测 + 历史实测 |
| **音频** | 宿主 PipeWire + wireplumber 在跑，`alsa_output.platform-sound.HiFi__Speaker__sink`（**实测** `pactl`）；容器播放（闹钟出声）+ 录音通路（`TestRecord` rms/peak 有数）已实测（`reports/container-audio-20261011.md`） | **延迟未量化**（U8 阈值 <100 ms 未判）；游戏级低延迟不做 | 实测 + 历史实测 |
| **身份/完整性** | GMS **登录成功**、gstatic 204（历史实测 2026-10-13） | **Widevine = 不存在**（本轮实测：vendor `mediadrm/` 仅 `libdrmclearkeyplugin.so`）；**build = userdebug + test-keys**（本轮实测镜像 build.prop）；**PI 三档回包未取证**；**STRONG 结构性不可达**（软 keymaster，见 §2） | 本轮实测 + 静态 |

**「不依赖 Android 宿主」判据复核（本轮）**：a 槽未被使用、容器镜像在 `linux18` 上、宿主栈全程主线（msm_dpu + freedreno + PipeWire + Phosh）⇒
该形态**不借用任何 Android 分区/服务**；上表「已通」项全部在此形态下取得。**唯一例外**：容器镜像自身是 Android 用户态（这是 R1 的定义，不是宿主依赖）。

---

## §2 身份 / DRM 判定表（含**否证条件**）

> 目标：不预设「不可能」、不承诺。每条给 **判定链 → 最小取证集 → 本机现状 → 判定 → 否证条件**。

### 2.1 最小取证集（命令清单，全部只读）

```bash
# A. 平台属性（容器内；本轮容器未运行 ⇒ 用镜像 build.prop 静态读出）
getprop ro.build.fingerprint; getprop ro.build.tags; getprop ro.build.type
getprop ro.debuggable; getprop ro.secure; getprop ro.build.version.security_patch
getprop ro.product.first_api_level; getprop ro.product.model; getprop ro.product.manufacturer
getprop ro.boot.verifiedbootstate; getprop ro.boot.flash.locked; getprop ro.boot.veritymode
getprop ro.boot.warranty_bit; getprop ro.vendor.build.fingerprint
# B. GMS / DroidGuard 面
pm list packages | grep -E 'com.google.android.gms$|com.android.vending|com.google.android.gsf$'
ps -A | grep -E 'gms|droidguard'
# C. Play Integrity 回包（需装检测 App，见 §2.4）
#    SPIC(herzhenr/spic-android) → BASIC / DEVICE / STRONG 三档 + requestHash
# D. 硬件密钥证明链（KeyAttestation）→ attestation 证书 issuer / root / securityLevel
# E. Widevine
ls -l /vendor/lib64/mediadrm/            # 是否只有 clearkey
ls /lib64/hw /vendor/bin/hw | grep -i drm
dumpsys media.drm ; lshal | grep -i drm  # 期望只有 drm-service-lazy.clearkey
# F. DRM info（第三方 App `com.androidfung.drminfo` 或 `dumpsys media.drm`）
```

**本轮已取到的最小集**（镜像静态 + 设备节点）：

| 项 | 值 | 级别 |
|---|---|---|
| system `ro.build.fingerprint` | `waydroid/lineage_waydroid_arm64_only/waydroid_arm64_only:13/TQ3A.230901.001/aleasto09270731:userdebug/test-keys` | 静态（`debugfs cat /system/build.prop`） |
| `ro.build.type` / `ro.build.tags` | `userdebug` / **`test-keys`** | 静态 |
| `ro.build.version.security_patch` | `2026-02-01` | 静态 |
| `ro.product.first_api_level` | `28` | 静态 |
| vendor `ro.vendor.build.fingerprint` | `…/xuqianhui100110131152:userdebug/test-keys` | 静态 |
| vendor `mediadrm/` | **仅 `libdrmclearkeyplugin.so`（59224 B）** | 静态（`debugfs ls -l`） |
| DRM HAL 服务 | **仅 `android.hardware.drm-service-lazy.clearkey`** | 静态 |
| keymaster HAL | `android.hardware.keymaster@4.0-service`（15568 B）+ `libpuresoftkeymasterdevice.so` | 静态 |
| gatekeeper | `android.hardware.gatekeeper@1.0-service` + `gatekeeper.waydroid.so` | 静态 |
| 宿主 DRM 设备 | `/dev/dri/card0`（`qcom,sm8750-dpu`）、`renderD128` | 实测 |

### 2.2 判定表

| 目标 | 判定链（必要条件的链路） | 本机现状 | 判定 | **否证条件**（出现即推翻本判定） |
|---|---|---|---|---|
| **PI `MEETS_BASIC_INTEGRITY`** | Play 认可的 build（属性自洽：fingerprint/model/机型与认证库匹配、非 test-keys）+ 账号 + DroidGuard 未见明显篡改 | build = `userdebug/test-keys` + Waydroid fingerprint ⇒ **原样必失败**；对策（PIF 指纹投影 / 未认证注册）**未取证** | **未取证**（不承诺） | 装 SPIC 后 `BASIC=true` 且**同一 build 属性**下 **3/3 复现**（≥72 h） |
| **PI `MEETS_DEVICE_INTEGRITY`** | BASIC **且** 设备侧判定通过（DroidGuard 结合 build 一致性；A13 上不再要求硬件证明，但要求「未被篡改的 Play 认证设备画像」） | 同上；`ro.boot.verifiedbootstate` 等 boot 属性在容器内由 Waydroid 生成，**未取证** | **未取证 / 结构性可行但不可承诺**（社区先例存在，稳定性依赖 Play 侧策略） | 同上：SPIC `DEVICE=true` 连续 3/3，且**不依赖**每次重启后重放内存中的伪装 |
| **PI `MEETS_STRONG_INTEGRITY`** | 硬件密钥证明：Keystore key attestation 证书链 → **Google Hardware Attestation Root**，`verifiedbootstate=green`、`deviceLocked`、`securityLevel ∈ {TEE, StrongBox}`、bootloader 锁 | 容器 keymaster = **AOSP 软实现**（`libpuresoftkeymasterdevice.so`），无 TEE/StrongBox；宿主侧主线 Linux 无 Android 的 TEE keymaster 通道 ⇒ 证明链根无法指到 Google 根 | **结构性不可达（静态否证）** —— 除非注入厂商 keybox（= 泄露密钥；**本仓不做**，且会被 Google 吊销） | 出现**能链到 Google 硬件根**的 attestation 证书（`securityLevel=TEE/StrongBox`，`deviceLocked=true`）并能被 SPIC 判 `STRONG=true` |
| **SafetyNet Attestation** | 已由 Google **停服**（2024 起 API 停用） | — | **不适用（静态）**：新请求无法获得有效 verdict，仅作历史对照（YASNAC） | Google 恢复该 API（无预期） |
| **Widevine L1** | libwvhidl/libwvdrm（arm64）+ **TEE 内密钥** + OEM 签发的 Widevine 设备证书（provisioning）+ `securityLevel=L1` | 库**不存在**；无 TEE；无 provisioning 通道 | **不可达（静态否证）** | 出现 L1 生效的 `dumpsys media.drm`（`securityLevel: L1`）且 HD 受保护流可播 |
| **Widevine L3** | libwvhidl/libwvdrm（arm64）+ 软件安全级 + **provisioned 设备证书**（Google 侧签发，绑定设备/OEM 证书） | 库**不存在**（`/vendor/lib64/mediadrm` 仅 clearkey；`/system/lib64` 无 `*wv*`）；社区先例：**arm64 prebuilt 仅 A11 有、A13 无**（`RESOURCES §1.3`） | **当前不可用（实测）**；「A13 arm64 是否可补齐」= **未取证** | 找到 arm64/A13 的 `libwvhidl.so`+`libwvdrmengine.so`，provision 成功、`drminfo` 显示 **L3**，且 YouTube/Disney+ 出 SD 以上受保护流 |
| **GMS 登录 / Play 授权**（身份的前置，非完整性） | 账号 + 连通（代理） | 已登录 `xuqianhui176@gmail.com`、Play 53.4.34、gstatic 204（历史实测 2026-10-13；本轮容器 STOPPED 未复测） | **已通** | 账号被踢 / 代理失效 |
| **对照：真机基线** | — | stock a 槽 **Widevine L1 / HDCP 2.3**（`reports/c0-android-baseline-20261011.md`，历史实测） | — | — |

### 2.3 「能做到哪一级」一句话结论

- **GMS 登录 / Play 商店**：**已通**（容器级，靠代理 + 已认证账号）。
- **PI BASIC / DEVICE**：**未取证**；结构性**可能**（纯软件伪装），但**稳定性不可承诺**、且随 Play 侧策略漂移。
- **PI STRONG**：**结构性不可达**（无 TEE，软 keymaster）——除非使用厂商 keybox（不做）。
- **Widevine L1**：**结构性不可达**。**Widevine L3**：**当前不可用**（无 arm64/A13 库）；补齐路径**未取证**。

### 2.4 PI 回包取证所需（**需要设备写 + 第三方 APK**，本轮未做）

```bash
# 宿主（可直连 GitHub，勿走代理）
curl -L -o /tmp/spic.apk https://github.com/herzhenr/spic-android/releases/download/v1.4.0/spic-v1.4.0.apk   # 11.2 MB
# 设备（容器 RUNNING 后）
waydroid app install /tmp/spic.apk
waydroid shell am start -n gr.nikolasspyr.integritycheck/.MainActivity
waydroid shell input tap <x> <y>                     # 或人工点「CHECK」
# 回包取证（截图 + 文本）
waydroid shell screencap -p /data/local/tmp/pi.png && adb pull /data/local/tmp/pi.png
```
> ⚠ 该步骤同时是「装 APK + 写 `/data`」，属**需要用户批准**的动作（§7）。

---

## §3 C5 / U7：相机 App 实开预览的剩余阻塞（逐条命令）

### 3.1 本轮改动后的卡点（已换，与 10-23 收尾不同）

| # | 卡点 | 本轮证据 | 级别 |
|---|---|---|---|
| **B1** | **`v4l2loopback.ko` 不在当前内核 UTS 的模块目录** ⇒ `/dev/video100` 不存在 | `modinfo v4l2loopback` → `ERROR: Module v4l2loopback not found`；`/lib/modules/$(uname -r)/extra/` **不存在**；`lsmod` 无该模块；`/dev/video100` `No such file` | **实测** |
| **B1'** | 旧 UTS 目录**有**该模块，但 **vermagic 不匹配**（`…-dirty` vs `…-dirty-debug-vk163`） | `modinfo …/…-dirty/extra/v4l2loopback.ko` → `version 0.15.4`、`vermagic 7.3.0-rc7-…-dirty SMP preempt mod_unload aarch64`；运行 UTS 带 `-debug-vk163` | **实测** |
| **B2** | 镜像内**无相机 APK** | `ls /root/*.apk /home/xuqianhui1001/*.apk /tmp/*.apk` → 只有 openssl 相关 apk；`/data` 下无应用目录可查（`/data/app` 不存在于宿主视图） | **实测** |
| — | `/dev/video100` bind **已在持久配置** | `config_nodes:23 lxc.mount.entry = /dev/video100 dev/video100 none bind,create=file,optional 0 0` | **静态**（本轮复核，10-23 的修法在位） |
| — | provider / 生产者侧依赖齐备 | 宿主 `gst-inspect-1.0 libcamerasrc/v4l2sink/v4l2src` 全 OK、`v4l2-ctl` 在；`/dev/media0` 在；`qcom_camss` 已加载（15 refs）；17 个 `/dev/video0..16` | **实测** |

**结论**：U7 现在是**两步**阻塞 —— ① 给当前内核补 `v4l2loopback.ko`（设备写）；② 装一个相机 APK（用户决定）。provider/HAL/bind 侧**已无缺件**。

### 3.2 逐条命令（**未执行**：涉及设备写 / 装 APK，待批）

```bash
# ── 主机侧：取源 + 交叉编译（模块很小；v0.15.4 与机上旧 .ko 同版本）
cd /home/xuqianhui/y700-elden
git clone --depth 1 --branch v0.15.4 https://github.com/v4l2loopback/v4l2loopback /tmp/v4l2loopback
# UTS 必须与在机内核逐字一致（在机：7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163）
make -C build/vk151 M=/tmp/v4l2loopback \
     LOCALVERSION='-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163' modules -j8
modinfo /tmp/v4l2loopback/v4l2loopback.ko | grep -E 'vermagic|version'   # 期望 = 在机 uname -r
# 说明：build/vk151/.config 为 `# CONFIG_MODVERSIONS is not set` / `# CONFIG_MODULE_SIG is not set`
#       ⇒ 只需 vermagic 一致即可加载（PITFALLS #367 的 ABI 漂移在这里不存在，但仍要复核 vermagic）

# ── 设备侧：部署模块（**写盘**，最小面：仅 /lib/modules/<UTS>/extra/ + depmod）
scp /tmp/v4l2loopback/v4l2loopback.ko root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'U=$(uname -r); mkdir -p /lib/modules/$U/extra && \
  cp /tmp/v4l2loopback.ko /lib/modules/$U/extra/ && depmod -a && \
  modprobe v4l2loopback exclusive_caps=1 video_nr=100 && ls -l /dev/video100'

# ── 设备侧：起生产者（repo 脚本，纯运行期）
scp scripts/cam-loopback.sh root@192.168.7.1:/root/
ssh root@192.168.7.1 'sh /root/cam-loopback.sh start front 1280x720 30 && sh /root/cam-loopback.sh test 10'
#   期望：frames 10 / Y mean ≈ 51.6–54.3（10-23 基线）

# ── 容器侧：起会话 + 装 APK + 授权 + 实开预览
ssh root@192.168.7.1 'waydroid session start & sleep 20; waydroid status'      # 起会话（写 /data 运行态）
waydroid app install /tmp/camera.apk                                            # ← 需用户提供 APK（§7）
waydroid shell pm grant <pkg> android.permission.CAMERA
waydroid shell am start -a android.media.action.STILL_IMAGE_CAMERA
waydroid shell dumpsys media.camera | grep -E 'Number of camera devices|Active Camera Clients'
waydroid shell dumpsys media.camera | grep -A3 'Active Camera Clients'          # 期望：非空
```
> APK 候选（**均 <15 MB**，需用户拍板）：AOSP `Camera2`（`platform/packages/apps/Camera2`）或 F-Droid `Open Camera`。
> 语义提醒（10-23 结论不变）：容器 external HAL 只有 **1 个 external 设备**，"前后摄切换" = 换 loopback 生产者
> （`cam-loopback.sh stop; start rear`），**不是**换 camera id。

---

## §4 droidloom 门槛复核与裁决

### 4.1 四条门槛（逐条实测/静态）

| # | 门槛（上游要求） | 本机/上游现状 | 结论 |
|---|---|---|---|
| **G1** | **aarch64 宿主可用**：需自构建（发布包只发 x86_64 Arch） | 上游 `android/device/droidloom_arm64/` 是一等产品配置，**但无发布包**（静态，`RESOURCES §1.3`） | **未过**：需自行构建 + 转 pacman 包到本 rootfs |
| **G2** | **合成器**：`xdg-shell` + `linux-dmabuf` **v4 feedback** + **`linux-drm-syncobj`** | 本轮**实测**（`WAYLAND_DEBUG=1 wlr-randr` 抓 registry）：`xdg_wm_base` v6 ✓、`zwp_linux_dmabuf_v1` **v5**（含 v4 feedback）✓、**`wp_linux_drm_syncobj_manager_v1` 全局缺失** ✗。附加静态：`wayland-protocols` 的 XML 在机（`/usr/share/wayland-protocols/staging/linux-drm-syncobj/`），phoc 内**确实编译进了** `wlr_linux_drm_syncobj_v1.c`（`strings /usr/bin/phoc` 命中），但**没有创建 global** | **未过**（Phosh/phoc 0.55.1 会话不暴露该全局） |
| **G3** | **机型验证范围** | 上游验证平台 = **OnePlus Pad 4**（Android 17）、Moto Edge 70；**TB322FC/SM8750 无验证记录**（静态） | **未过**（本机型无先例） |
| **G4** | **身份/DRM** | 上游**官方明确未验证 PI/Widevine**；Moto cell 上 Play 显示「未认证设备」；宿主无 Android SELinux LSM ⇒ binder SID 走 PID-context 回退（静态） | **未过**（且与 J2 同向，不改善身份上限） |

### 4.2 裁决

**现在不立项**（维持 `TASKS §5 Q3`「只跟踪」）。判据（合取，缺一即不立项）：

1. `J2` 或 `C5/U7` 在 Waydroid 上出现**不可解**阻塞（不是"有坑"，而是"结构性做不到"）；
2. droidloom 侧 **G1 与 G2 同时满足**（可获取 aarch64 构建产物；宿主侧有支持 `linux-drm-syncobj-v1` 且不摧毁当前 Phosh 桌面栈的方案）；
3. 有 sm8750/同代 arm64 机型的第三方跑通记录（降低 G3 风险）。

**复启条件（任一触发即重评，不自动立项）**：

- (a) droidloom 发布 **aarch64 包** 或 **CI 产物**；
- (b) 宿主侧出现 **`linux-drm-syncobj-v1` 的可用合成器路径**：① phoc 上游创建该 global（我们的 phoc 已含 wlroots 实现，理论上是"缺一次 create 调用"）；或 ② Denial 稳定到可替代 Phosh（注意 Denial 的两个**会话级致命坑**：GPU reset、运行时改缩放）；
- (c) Waydroid 侧出现「必须 per-task 窗口 / 必须 Android 独占输入 / 必须 release 属性投影」才可解的需求（如某目标 App 检测 `ro.debuggable` 或窗口形态）；
- (d) 上游给出 TB322FC 或 SM8750 的验证记录。

**不动手的原因（一句话）**：G2 门槛卡在**桌面栈选型**（换合成器 = 动 G1 的日常桌面），而 G1 侧收益为零、风险非零 —— 这不是容器层能消化的事。

---

## §5 方案对比（3 列：维护性 / 风控 / 工作量）

> 口径：本机现役 Linux 宿主、a 槽可弃、目标 = 「不依赖 Android 宿主」+ 身份/完整性尽量高。

| 维度 | **A. Waydroid OTA（现役 R1）** | **B. redroid（R1'）** | **C. GSI（devices-native，需 Android 宿主）** |
|---|---|---|---|
| 形态 | LXC + 容器内 Android 用户态 + 宿主 freedreno；`show-full-ui` 单窗口 | Docker/podman 容器 + arm64 官方镜像 + binderfs；display 走 **远程/软件或 gbm** | 刷 GSI 到 a 槽（真 Android 内核/宿主），Linux 走 kexec/双启 |
| **维护性** | **高**（本仓已固化 11 项：`config_nodes`/`waydroid_base.prop`/vendored HAL/自编 camera-provider/触觉 AIDL/Mesa bind；镜像有官方 OTA 通道 `waydroid.cfg` 指向本机 8800） | **中**：镜像来自社区（`redroid-script`/`CNflysky`），**HAL/显示/输入/音频无本仓固化产物**，等价于把 C1/C4/C5/C6/C10 的修复重做一遍 | **低（对我们是负）**：GSI 与我们主线内核无关；a 槽占用 = 违背「不依赖 Android 宿主」；每版 GSI 需重刷 + 重配 |
| **风控** | **低**：容器可整体删除；不触信任根；`test-keys` 但**不影响 G1** | **低**：同为容器可弃；但需宿主 kernel 的 binder + 网络命名空间调优 | **高**：占 a 槽、与 Q15（Widevine L1 已降级）绑定、回退靠 EDL；不满足「a 槽可弃」前提 |
| **身份/完整性上限** | PI BASIC/DEVICE **未取证**、STRONG **否证**、Widevine **无** | 同量级（同一 GMS 生态约束；无明显证据表明优于 Waydroid） | **仅此列可达真机级**（stock 基线：Widevine **L1**、HDCP 2.3、PI 视 BL 解锁态而定），但**代价 = 放弃前提** |
| **工作量（补齐到 U1–U10）** | **基准**（U8 已过；U7 差 2 步；U5 不可达；U3/U4/U6/U9/U10 待测） | **+ 重做 4 类修复**（图形/相机/音频/触觉）+ 网络模式差异；预计 ≥1 周并**不改善** U5 | **+ 每次 GSI 换代重配**；且与本项目主线（G1）无协同 |
| **结论** | **继续作主路线**（唯一有本仓固化资产 + 可单独卸载） | **只在 A 出现结构性阻塞时做对照验证**（保留为备胎，不投入固化） | **不作为 G2 路线**（仅在需要"临时校准真机行为"时借用，C0 已完成主体） |

**横向一句**：R1 的真瓶颈**不在容器技术**，而在 **Play/Google 的策略面 + arm64 无 Widevine 库**；换 B/C 都不解决这两个瓶颈（C 只解决"身份"，但代价是放弃 G2 前提）。

---

## §6 设备只读证据（本轮原始输出）

> 设备：`ssh root@192.168.7.1`；`uname -a` = `Linux elden 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163 #21 SMP PREEMPT Sun Oct 25 22:37:49 CST 2026 aarch64`；
> `os-release` = `Alpine Linux 3.24.2`；uptime 1:26。
> **未读 SN/未做身份判定**（`DEVICE/README.md` 的身份三元组本轮不需要）。

### 6.1 Waydroid 状态与镜像版本

```
$ waydroid status
Session:        STOPPED
Vendor type:    MAINLINE

$ waydroid --version        → 1.6.2
$ cat /var/lib/waydroid/waydroid.cfg
arch = arm64_only ; vendor_type = MAINLINE
system_datetime = 1790490369 ; vendor_datetime = 1790493416
mount_overlays = False ; auto_adb = False ; binder_protocol = aidl3
system_ota = http://192.168.7.2:8800/system/lineage/waydroid_arm64_only/GAPPS.json
vendor_ota = http://192.168.7.2:8800/vendor/waydroid_arm64_only/MAINLINE.json

$ ls -l /var/lib/waydroid/images/
system.img   2605989888   (lineage-20.0-20260927-GAPPS-waydroid_arm64_only)
vendor.img    268435456   mtime 2026-10-19 15:40  (2026-10-19 相机 bake 版)
+ 7 份 vendor.img.bak-*   （回退件齐全）

$ tail /var/lib/waydroid/waydroid.log
(8915) [Sun, 25 Oct 2026 20:10:34] Stopping container
(8915) […] % lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH   →  STOPPED
```
- **级别**：实测。**容器 2026-10-25 20:10:34 正常停止，无 crash 痕迹**（尾部只有 stop 序列）。
- OTA 侧版本（静态，`waydroid-ota/*.json`）：system `lineage-20.0-20260927-GAPPS…`（1 176 311 793 B）、
  vendor `lineage-20.0-20260927-MAINLINE…`（77 357 342 B），`version=20.0`。

### 6.2 内核能力面（binder / fuse / dma_heap / 相机）

```
$ grep -E "binder|fuse|overlay" /proc/filesystems
nodev   binder
        fuseblk
nodev   fuse
nodev   fusectl

$ mount | grep binder
binder on /dev/binderfs type binder (rw,relatime,max=1048576)
$ ls -l /dev/binderfs
crw------- 504,1 binder ; crw------- 504,0 binder-control ; crw------- 504,2 hwbinder ; crw------- 504,3 vndbinder
$ ls /dev/binder /dev/hwbinder /dev/vndbinder      →  No such file（顶层未建符号链接；容器启动时由 Waydroid 建）

$ zcat /proc/config.gz | grep -E "ANDROID_BINDER|CONFIG_FUSE|SYNC_FILE|CGROUP_BPF"
CONFIG_ANDROID_BINDER_IPC=y ; CONFIG_ANDROID_BINDERFS=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
CONFIG_FUSE_FS=m ; CONFIG_FUSE_PASSTHROUGH=y ; CONFIG_FUSE_IO_URING=y ; CONFIG_SYNC_FILE=y ; CONFIG_CGROUP_BPF=y

$ ls -l /dev/dma_heap        →  crw------- 248,0 system
$ lsmod | grep -E "binder|fuse|system_heap"
fuse 225280 3 ; system_heap 12288 0
```
- **级别**：实测。**D5（binderfs）、D14（fuse）、D13 层④（dma_heap/system）三项前提在机成立**。
- 关键点：`/dev/dma_heap/system` 与 `fuse` 模块**已加载**（PITFALLS #189 层④ / #191 的持久化在位）。

### 6.3 相机节点（C5 的现场）

```
$ ls /dev/video*            →  /dev/video0 … /dev/video16（17 个，mainline camss）
$ ls -l /dev/video100       →  No such file
$ ls /dev/media*            →  /dev/media0
$ lsmod | grep -E "qcom_camss|videodev"
qcom_camss 696320 15 ; videodev 335872 18
$ modinfo v4l2loopback      →  ERROR: Module v4l2loopback not found
$ ls /lib/modules/$(uname -r)/extra/    →  No such file or directory
$ for d in /lib/modules/*/; do ls $d/extra/*.ko; done
  → 只有 4 个**旧 UTS** 目录带 v4l2loopback.ko（version 0.15.4，vermagic `…-dirty`）
$ gst-inspect-1.0 libcamerasrc / v4l2sink / v4l2src   →  全部 OK
$ ls -l /lib/modules/$(uname -r)/build  →  指向 /home/xuqianhui/y700-elden/build/vk151（**在设备上为悬空链接**）
```
- **级别**：实测。⇒ **C5/U7 的 B1（模块缺失）+ B1'（vermagic 不匹配）成立**；生产者链路其余件齐备。
- `config_nodes` 静态复核：`23: lxc.mount.entry = /dev/video100 … optional`、`28: /dev/dma_heap`、`29: /dev/fuse`（均在位）。

### 6.4 图形 / 输入 / 音频（宿主侧，实测）

```
$ ls -l /dev/dri   → card0 (226,0) ; renderD128 (226,128)
$ cat /sys/class/drm/card0/device/uevent
DRIVER=msm_dpu ; OF_COMPATIBLE_0=qcom,sm8750-dpu ; OF_FULLNAME=/soc@0/display-subsystem@ae00000/display-controller@ae01000

$ su -s /bin/sh xuqianhui1001 -c "wlr-randr"
DSI-1 "(null) (null) (DSI-1)"  Physical size: 118x190 mm  Enabled: yes
  1904x3040 px, 165.000000 Hz (preferred, current)   … 144/120/90/60/40/30/24 Hz

$ grep -E "^N: Name" /proc/bus/input/devices
pmic_pwrkey / pmic_resin / gpio-keys / aw86927-haptics ×2 / NVTCapacitiveTouchScreen / Lenovo-Y700-Gen4 Headset Jack

$ pgrep -a pipewire  → /usr/bin/pipewire ; /usr/bin/pipewire-pulse ; /usr/bin/wireplumber
$ pactl list short sinks → 53 alsa_output.platform-sound.HiFi__Speaker__sink  PipeWire s16le 2ch 48000Hz SUSPENDED

$ dmesg | grep -i adreno  → gen80000_sqe.fw / gen80000_gmu.bin / gen80000_aqe.fw 全部 loaded
```
- **级别**：实测。⇒ 图形/输入/音频三维的**宿主侧**前提在机成立（容器侧结论见 §1，来自历史实测）。

### 6.5 合成器全局（droidloom 门槛 G2 的现场取证，本轮新增）

```
$ su -s /bin/sh xuqianhui1001 -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DEBUG=1 wlr-randr 2>&1 >/dev/null" | head -60
[ 624826.532] wl_registry#2.global(1, "wl_shm", 2)
[ 624826.540] wl_registry#2.global(2, "wl_drm", 2)
[ 624826.547] wl_registry#2.global(3, "zwp_linux_dmabuf_v1", 5)      ← v5（含 v4 feedback）
[ 624826.562] wl_registry#2.global(5, "wl_compositor", 6)
[ 624826.606] wl_registry#2.global(11, "xdg_wm_base", 6)             ← xdg-shell ✓
…（共 55 个 global，含 zwlr_layer_shell_v1 / phosh_private / gtk_shell1 / wp_fractional_scale_manager_v1 …）
# grep -o wp_linux_drm_syncobj_manager_v1  →  0 命中

$ strings /usr/bin/phoc | grep -i syncobj
../subprojects/wlroots/types/wlr_linux_drm_syncobj_v1.c      ← 实现已编译进 phoc
Failed to import drm_syncobj timeline
$ ls /usr/share/wayland-protocols/staging/linux-drm-syncobj/   → linux-drm-syncobj-v1.xml（协议 XML 在机）
$ apk list -I | grep -E "phoc|phosh|wayland-protocols" → phoc-0.55.1-r0 / phosh-0.55.0-r2 / wayland-protocols
```
- **级别**：**实测**（全局枚举）+ 静态（binary strings）。
- **判读**：**`linux-drm-syncobj-v1` 全局未暴露** ⇒ droidloom presenter 的硬门槛**当前不满足**；
  但 phoc **已含**该协议的 wlroots 实现（缺的是 `create()` 调用/条件）⇒ 复启条件 (b)① 有具体落点（上游 phoc 一行级改动），**不是重写桌面栈**。

### 6.6 容器镜像内容（静态，`debugfs` 只读）

```
$ debugfs -R "ls -l /lib64/mediadrm" vendor.img
458 100644 libdrmclearkeyplugin.so  59224          ← 仅 ClearKey
$ debugfs -R "ls /bin/hw" vendor.img | grep drm     → android.hardware.drm-service-lazy.clearkey
$ debugfs -R "ls /bin/hw" vendor.img
… audio.service / camera.provider@2.4-external / cas@1.2 / configstore@1.1 / drm-service-lazy.clearkey /
  gatekeeper@1.0 / allocator@2.0 / allocator@4.0.minigbm_gbm_mesa / composer@2.1 / health@2.0.waydroid /
  keymaster@4.0 / light@2.0.waydroid / memtrack@1.0 / power@1.0.waydroid / sensors@1.0.waydroid /
  vibrator-service.elden
$ debugfs -R "ls /lib64" vendor.img | grep -iE "keymaster|puresoft"
android.hardware.keymaster@3.0.so / @4.0.so / libkeymaster4.so / libkeymaster4support.so /
libkeymaster_messages.so / libkeymaster_portable.so / libpuresoftkeymasterdevice.so    ← 软 keymaster
$ debugfs -R "cat /etc/vintf/manifest.xml" vendor.img | grep -oE "<name>[A-Za-z0-9._@-]+</name>" | head
ICameraProvider / IComposer / IDevicesFactory / IGatekeeper / IKeymasterDevice / ISensors / …
```
- **级别**：静态（镜像内文件与声明）。⇒ **§2 的 two 个结构性判据（无 Widevine、软 keymaster）成立**。
- 与旧报告一致性：`reports/c3-identity-drm-20261013.md` 的 Widevine 结论**本轮用镜像直读复核，仍成立**（不是沿用旧结论）。

---

## §7 下一步（按「需要用户账号 / 需要设备写」分组）

### 7.1 需要**用户账号 / 用户决策**（零设备风险，但要拍板）

| # | 动作 | 为什么需要用户 | 产出 |
|---|---|---|---|
| U-A1 | 批准取用 **PI 检测 APK**（SPIC 11.2 MB / YASNAC 1.25 MB） | 第三方 APK 信任链 + 装进容器 | J2 的 **BASIC/DEVICE 回包**（是否可过 device 的第一手证据） |
| U-A2 | 批准 **未认证设备注册流程**（`google.com/android/uncertified` + 清 GMS 缓存） | 触及 Google 账号与设备注册 | 社区做法①的本机复现记录 |
| U-A3 | 拍板 **PIF 指纹投影**是否在范围内（`PlayIntegrityFork` v18 在手） | 属"伪装"类做法，需明确授权边界 | 社区做法②的结果（**不承诺**通过） |
| U-A4 | 指定 **相机 APK**（AOSP Camera2 / Open Camera） | 第三方 APK + 用户偏好 | U7 收官件 |

### 7.2 需要**设备写**（仅列出，未执行）

| # | 动作 | 写面（最小） | 回退 |
|---|---|---|---|
| D-A1 | 部署 `v4l2loopback.ko`（当前 UTS）+ `depmod` | `/lib/modules/<UTS>/extra/`（新增 1 文件 + depmod 缓存） | `rm` 该文件 + `depmod -a` |
| D-A2 | 起容器会话（`waydroid session start`） | 运行态 `/data`（**非镜像**） | `waydroid session stop` |
| D-A3 | 装 1 个相机 APK | 容器 `/data/app` | `waydroid app remove` |
| D-A4 | （可选）phoc 侧创建 `linux-drm-syncobj-v1` global 的**验证性补丁** | 需要重编 phoc + 重装（**动日常桌面**）⇒ **本轮不建议做**，只有 G2 立项后才做 | 保留原 phoc apk |

### 7.3 主机侧可继续（零设备）

1. **PI/DRM 判定脚本化**：把 §2.1 的最小取证集写成 `scripts/c3-identity-evidence.sh`（容器内只读 + 回包落盘），供每次镜像换代复跑。
   —— 需等 U-A1 拍板（脚本要装 APK 才能取回包；可先做"只读部分"）。
2. **v4l2loopback 交叉编译打通**（主机侧可先行验证 `vermagic` 与在机 UTS 逐字一致，不含设备写）。
3. **droidloom 复启监控**：跟踪 ① aarch64 发布包；② phoc 上游是否为 `linux-drm-syncobj-v1` 建 global（**本轮已把判据变成可 grep 的一行**：`WAYLAND_DEBUG=1` 抓 registry 里有无 `wp_linux_drm_syncobj_manager_v1`）。

### 7.4 未取证（必须诚实记账）

- **PI 三档回包**（basic/device/strong）—— 完全未取证（无 APK）。
- **`ro.boot.*` 在容器内的实际取值**（`verifiedbootstate` / `flash.locked` / `veritymode`）—— 容器 STOPPED，未取证。
- **Widevine 「arm64/A13 是否可补齐」** —— 未取证（只知当前库不存在 + 社区先例为 A11 有、A13 无）。
- **U4/U5/U6/U9/U10 用例**（视频通话 / 流媒体 DRM / 游戏帧率 / 多窗口 / 休眠唤醒）—— 未测。
- **容器内 IME**（C11 记账项）—— 未测。
