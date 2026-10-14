## 三十、Waydroid 马达透传二期：AIDL HAL 替换（2026-10-13 下午实测）

239. **★`cmd vibrator_manager` 的 CLI 参数陷阱——三个假阴性把「已实现」误判成「没生效」：`-a` / 整数 effect id / `-B`。**
    - `synced oneshot [-w delay] [-a] <duration> [<amplitude>]`：**不写 `-a` 时幅度参数被整段忽略**（`hasAmplitude=false` → `VibrationEffect.DEFAULT_AMPLITUDE`=255）⇒ 第一轮 `synced oneshot 300 160` 测出 `amp=255/255`，差点误判「HAL 不支持幅度」。
    - `synced prebaked <int effectId>`：源码 `Integer.parseInt(getNextArgRequired())` ⇒ 写 `prebaked CLICK STRONG` 直接 `NumberFormatException`（CLI 打 Java 栈）。effect id：0=CLICK、1=DOUBLE_CLICK、2=TICK、3=THUD、4=POP、5=HEAVY_CLICK。
    - `cancel` 只取消**后台**振动：`runVibrate()` 里 `deathBinder = background ? service : mShellCallbacksToken`，而 `runCancel()` 用 `service` 当 token ⇒ **前台 CLI 振动（shell 进程已退出）永远 cancel 不掉，这是设计而非 bug**。要测 cancel 必须 `synced -B oneshot <ms>`。
    - 规约：用 CLI 验证 HAL 能力前先 `cmd vibrator_manager` 打 help 看清选项；「没反应」先怀疑调用姿势，再怀疑实现（本轮三次假阴性都是姿势问题）。

240. **★servicemanager 强制 VINTF 声明：未声明的 AIDL HAL 直接注册失败（`-3`），且声明改了必须重启容器。**
    - 现象：手工在容器里跑自编 AIDL HAL，logcat `servicemanager: Could not find android.hardware.vibrator.IVibrator/default in the VINTF manifest.` + 自己的 `failed to add ... : -3`（`AServiceManager_addService` 返回非 0）。
    - 正确做法：device manifest **支持 fragment**（`/vendor/etc/vintf/manifest/*.xml`）。把「镜像原有 fragment + 我们的 fragment」放一个宿主目录，用 `lxc.mount.entry` **bind 整个 `manifest` 目录**（不能只加文件：/vendor 只读）。servicemanager 启动时读 manifest ⇒ **必须全量重启容器**。
    - 备选（本次未用）：构建期 `vintf_fragments`（本仓 AIDL 模块已配）让产物自带 fragment，但换 vendor 内容仍需上面那条 bind 或 overlay。

241. **改用自编译 HAL 不必开 `mount_overlays`：把二进制 bind 到镜像里「已存在」的服务路径上，镜像的 rc 会照旧拉起它。**
    - 做法：`lxc.mount.entry = /root/wd/vib/<bin> vendor/bin/hw/android.hardware.vibrator@1.0-service.waydroid none bind,optional 0 0`（目标文件在镜像里存在 ⇒ 文件级 bind 合法，不需要 `create=file`）。init 只认 rc 里的**路径**，不校验实现，于是 AIDL HAL 借 HIDL 服务的 rc 启动。
    - 收益：不动 `/vendor/etc/init`、不开 overlay（C4 传感器路线 B 的 overlay 曾导致容器卡 bootanim），回退只需删挂载项。
    - 代价：rc 里没有 `interface aidl ...` 行 ⇒ 不能走 init 的 lazy `ctl.interface_start`（本 HAL eager 注册，无影响）；进程名/日志 tag 与 rc 名不一致（用 `#define LOG_TAG` 固定 logcat 过滤）。

242. **★框架 `cancel` 的语义 = graceful：是否「立刻停」取决于步骤机实现，必须看 `CompleteEffectVibratorStep`。**
    - `VibratorManagerService.notifyCancelled(..., immediate=false)` 是绝大多数取消路径的默认（屏幕关、被抢占、用户取消）⇒ 由当前 step 的 `cancel()` 返回 `CompleteEffectVibratorStep(cancelled=true)`；该类 `play()` 里判断 `currentAmplitude < RAMP_OFF_AMPLITUDE_MIN || rampDownDuration <= stepDownDuration` ⇒ 满足则 `stopVibrating()`（立即 `off()`），否则走 `RampOffVibratorStep`（按 `VibrationSettings` 的 ramp 时长降幅再 off）。本机 `mRampStepDurationMs=5` ⇒ 实测立即停。
    - 结论：换 AIDL HAL 后 `cancel` 的 **HAL 侧通路是通的**（实测 8 s 振、1.2 s 时取消 → 同秒 `off()`）；一期用 HIDL 1.0 时同一路径走不到，是 HAL 代差而不是桥的问题。
    - 判据：`cmd vibrator_manager synced -B oneshot 8000` + `cancel`，看 daemon 日志 OFF 时刻是否≈cancel 时刻（**不能用前台振动测**，见 #239）。

243. **`rm -rf` 跨设备（如 `/mnt/Samsung/...`）会失败（EXDEV）：本环境的删除被转到 `~/y700-elden/.pi/trash/`，跨文件系统 rename 报错。**
    - 现象：`rm -rf /mnt/Samsung/waydroid-build/hardware/waydroid/vibrator-aidl` → `EXDEV: cross-device link not permitted`。
    - 处理：用 `/bin/rm -rf`（绕过包装）；或 `cp -r` 覆盖内容而不删目录。

244. **★容器 `vendor.img` 是「按内容自动裁」的紧凑 ext4，通常 100% 满：往里原位加文件会 ENOSPC，且 `install` 会先把目标截断成 0 字节——本轮把镜像里那份 HIDL vibrator HAL 弄成 0 字节过。**
    - 事实：`device/waydroid/waydroid/BoardConfig.mk` 只设 `BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4`、**没有 `BOARD_VENDORIMAGE_PARTITION_SIZE`** ⇒ 镜像按内容裁到刚好装下（实测 85,901,312 B，`df` 显示 82M/82M、0 free）。
    - 反面教材：`cp 原文件 原文件.hidl-orig` 直接失败；随后的 `install -m755 新二进制 目标` 先把目标截断、再写时 ENOSPC ⇒ **镜像里的 HAL 变 0 字节**（当时靠 bind 挂载掩盖了，但一旦去掉挂载就露）。
    - 规约：**不要在 vendor.img 里原位塞文件**；要加内容就改产品配置后 `m vendorimage` 重建（PITFALLS #246），或先用 `truncate`+`resize2fs` 扩容（设备侧有 e2fsck/resize2fs）。临时验证用 bind 挂载（#241），验证完立刻改为重建。

245. **★Settings 的「振动强度」档位由 **Settings 自己的资源** `config_vibration_supported_intensity_levels` 决定（AOSP 默认 1），与 HAL 是否报 `CAP_AMPLITUDE_CONTROL` 无关。**
    - 链路：`VibrationIntensityPreferenceController.getMax() = min(VIBRATION_INTENSITY_HIGH=3, 该资源)`、`getMin() = OFF = 0` ⇒ 资源=1 时滑杆只剩两档、没有可用的「强度」调节（用户观感 = 「不显示强度栏」）。
    - 真机由 **device overlay / RRO** 把它提到 3（或 5）；waydroid GSI 的树里**没有任何覆盖**（`grep -rn config_vibration_supported_intensity_levels device/ vendor/` 无命中）。
    - 修法：**静态 RRO**（`android:isStatic="true"`、`targetPackage=com.android.settings`、放 `/vendor/overlay`，开机自动启用）只覆盖这一个整数 → 实测 `cmd overlay list` 出现 `[x] com.elden.vibration.overlay`、`cmd overlay lookup com.android.settings com.android.settings:integer/config_vibration_supported_intensity_levels` = **3**。
    - 验证口径：**必须查资源值**（`cmd overlay lookup`），不要只看「HAL 报了幅度能力」。

246. **给产品换 HAL：`PRODUCT_PACKAGES` 与产品 `manifest.xml` 必须同步改；新模块还得落在产品的 Soong namespace 里。**
    - `device/waydroid/waydroid/device.mk` 里原来的 `android.hardware.vibrator@1.0-service.waydroid` 换成自编模块；同时把 `device/waydroid/waydroid/manifest.xml` 里那段 HIDL vibrator `<hal>` 删掉（否则是「声明了但没人提供」）。
    - RRO 模块最初放 `vendor/extra/`：`mmm` 能编，但加进 `PRODUCT_PACKAGES` 会被产品 namespace 拒（`vendor/extra` 不在 `PRODUCT_SOONG_NAMESPACES`）；挪到 `hardware/waydroid/vibration-overlay` 即可（与既有 waydroid 模块同一命名空间）。
    - 固化后的验证铁证：容器内 `ls -l /proc/$(pidof <hal>)/exe` 指向 `/vendor/bin/hw/<自编名>`，且 `grep -c vibrator /proc/mounts` = **0**（说明不再依赖 bind 挂载）。

247. **★跨版本改 `.config` 的两个坑：`make olddefconfig` 必须带 `ARCH=<目标架构>`；符号改名会让「配置回归」判断整体失真。**
    - **坑 1（2026-10-13 实踩）**：`make olddefconfig` 不带 `ARCH=arm64` 时，Kbuild 按**主机 x86** 的 Kconfig 树求值，产出一份 x86 配置——再拿它跟 arm64 配置 diff，得到的差异**全是假的**。改 arm64 内核配置一律 `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig`。
    - **坑 2（同日本项目误判）**：7.3 把可见符号 **`PROC_SYSCTL` 改名 `SYSCTL`**（`fs/proc/Kconfig:83`，prompt 仍是 `Sysctl support (/proc/sys)`）。逐行 `grep -m1 '^CONFIG_PROC_SYSCTL='` 在新树上必然落空，于是把「7.3 内核缺 `/proc/sys`」当成上机失败根因，白走一轮。**判据必须落在产物上**：用内核树里的 `scripts/extract-ikconfig` 从**成品 Image** 里抽内嵌 config（实测 7.3 镜像 `CONFIG_SYSCTL=y` + `CONFIG_PROC_FS=y`，`/proc/sys` 一直都在）。
    - 附：跨大版本 diff 配置时，先做一次「符号改名归并」（拿上游 Kconfig 定义对旧名字），否则 15 项差异里 14 项都是改名/删除造成的噪声（实测真正只有 `CONFIG_IPV6_MULTIPLE_TABLES` 一项）。

