# droidloom 可行性规划（2026-10-30）

> 性质：**规划 + 只读核实**。不迁移、不构建、不下载大文件、不动设备。
> 入口指针：`TASKS/README.md` §5「2026-10-30 新增待办」的 *droidloom 可行性规划（未证实，主机侧可并行）* 一行。
> 基线文档：`RESOURCES/sessions/2026-10-26-denial-droidloom深度评估.md`（下称〔深读〕）、
> `reports/waydroid-droidloom-userland-interface-20261026.md`（下称〔接口〕）、
> `reports/android-compat-20261026.md`（下称〔兼容〕，含设备侧实测协议审计）。
> 口径：**只有「实测/静态」两种证据**；未观测一律写「未验证」。禁用词：可行、已支持（除引用上游原文时标注出处）。

## 0. 方法与上游快照

| 项 | 值 | 取得方式 |
|---|---|---|
| 上游读法 | `gh api`（contents/commits/releases/tags/search-code）+ `web` 仅用于列表元数据 | 只读；**未 clone、未下载任何包**（单文件最大读取 = 一份 71 KB 的 `docs/architecture.md`） |
| `denialwm/droidloom` 快照 | `main` @ `0af7b9b`（2026-10-28T18:59:15Z），`pushed_at` 2026-10-28T21:02Z | `gh api repos/.../commits` |
| `denialwm/denial` 快照 | `main` @ `c96375a`（2026-10-11T18:25Z），`pushed_at` 2026-10-28T22:12Z | 同上 |
| 本机现状引用 | 内核 `build/vk151/.config`；会话 = phoc 0.55.1 / phosh 0.55.0 / 内嵌 wlroots 0.20.0 | 静态读仓库文件；协议全局的实测数据来自〔兼容〕§4.1（2026-10-26 设备侧，本轮未复测） |

**本轮未做**（也不在规划内做）：任何设备动作（`ssh`/`adb`/`fastboot` 一条未发）、git 提交、上游发信/开 issue。

---

## 1. 上游现状核实（数字）

### 1.1 仓库规模与活跃度（2026-10-30 读数）

| 指标 | droidloom | denial |
|---|---|---|
| 星 / fork / open issues | **413 / 14 / 13** | 1372 / 43 / 59 |
| 创建日 | 2026-09-06 | 2026-07-17 |
| 提交总数 | **59**（单分支 `main`，**单一作者 `doctorlogix` 59/59**） | 179（自 2026-08-01 起） |
| 最后提交 | `0af7b9b` 2026-10-28（"Share folders into the running cell…"） | `c96375a` 2026-10-11 |
| 近 90 天提交 | **59**（= 全部；10 月 46 条，10-22…10-28 一周 38 条） | 179 |
| 仓库体积 | 3.4 MB | 38.6 MB |

判读：**活跃但极新、单点维护**（59 提交 / 52 天（09-06→10-28）/ 1 人）。近 90 天没有"停更"信号，也没有第二个维护者。

### 1.2 发布包与架构（决定性事实）

`gh api repos/denialwm/droidloom/releases` = **只有 1 个 release 条目**（tag `packages`，`updated_at` 2026-10-24T11:10Z），
资产为 6 个修订号 × 3 类，**全部 `x86_64`**：

| 资产类 | 文件名样例 | 大小 | 下载数 |
|---|---|---|---|
| image | `droidloom-image-0.1.0-25-x86_64.pkg.tar.zst` | **1 008 393 914 B（≈0.94 GiB）** | 78 |
| runtime | `droidloom-runtime-0.1.0-25-x86_64.pkg.tar.zst` | 6 236 891 B | 55 |
| source | `droidloom-source-0.1.0-25.tar.gz` | 2 924 909 B | 5 |

- **aarch64 资产数 = 0**（release 列表逐项检查；`tags` 只有 `packages` 一个）。
- 版本号 = **0.1.0-25**（`0.1.0` 是唯一版本线；修订号 19→25 共 7 个，release 条目于 2026-10-24 更新）。
- Denial 侧对照：`v0.5.1`（2026-10-11）资产 **全部 x86_64 / amd64**（`.pkg.tar.zst` / `.rpm` / `.deb` + 一个 `-r1.apk`），**同样 0 个 aarch64 包**；`v0.2.0…v0.5.1` 共 **21 个 release**（`?per_page=100` 计数）无一例外。

**⇒ 「aarch64 有一等产物」这一说法在本轮核实下不成立**（与〔深读〕§3.3 的口径需更正，见 §1.4）。

### 1.3 `--product droidloom_arm64` 到底是什么（易误读点）

`docs/BUILDING.md` 中 `droidloom_arm64` 出现 4 次，**全部是"在 x86_64 机器上构建 ARM64 Android 组件"**：

- L77–78：`framework-build --work .work/arch/build --product droidloom_arm64 --surfaceflinger-only`（"reuse a prepared ARM64 workspace"）；
- L564：`--product droidloom_arm64` 用于 ARM64 audio components；
- L761–762：`droidloom-gapps … -1-aarch64.pkg.tar.zst`（**GApps add-on** 的 aarch64 包，不是 runtime/image）。

而宿主包工作流在 `docs/BUILDING.md` §1 的原始标题是 **"Prepare an x86_64 build machine"**，正文：
*"The supported package workflow uses rootless Podman with an Arch build container."*

`docs/INSTALL.md` L3/L9：*"This guide covers the **x86_64** Arch Linux / Omarchy preview."* / *"An **x86_64** machine running Arch Linux or Omarchy, with a Wayland desktop."*

**AArch64 宿主在文档里的真实位置**：只在 `docs/KNOWN_ISSUES.md` / `BUILDING.md` 的**验证叙述**里出现，指作者私有的
"Pad 4 workspace"（例：L932 "On the Pad 4 both now return 8"、L947–949 "restarted the tablet … Evidence is in the **Pad 4 workspace** under `out/droidloom-optimization-20261014/…`"、
KNOWN_ISSUES L19 "the deployed **ARM64 supervisor** reports the expected properties"、L32 "The cached **ARM64 presenter** is installed and running on the tablet"）。
⇒ **ARM64 宿主二进制确实存在过并被作者在其平板上部署**，但：**无发布包、无镜像包、无文档化的 aarch64 宿主编译流程**。

### 1.4 对〔深读〕§3.3 的一处口径更正

〔深读〕写 "`android/device/droidloom_arm64/` 是**一等产品配置**（不是实验开关）"。本轮核实：该目录仍存在且内容是产品配置，
但 **`docs/BUILDING.md`/`INSTALL.md` 支持的交付面只有 x86_64**；"一等产品配置" ≠ "一等交付产物"。
建议后续引用一律写成：**ARM64 目标存在、作者真机跑过、不发布、不文档化宿主构建**。

### 1.5 稳定性声明（逐条原文，全部为上游自述）

| 出处 | 原文要点 | 含义 |
|---|---|---|
| `README.md` L11–12 | *"This is an **early preview**. The package workflow targets x86_64 Arch Linux and Omarchy with AMD or Intel graphics."* | 预览态 + 目标面限定 |
| `README.md` L14 | *"NVIDIA rendering is **not validated**."* | 显卡面自陈 |
| `docs/contracts/runtime-layout-v1.md` L7–10 | *"Production user-ID mapping, cgroup limits, general seccomp sandboxing, and complete packaging hardening **remain later work**"* | 隔离层未完成 |
| 同上 L13 | *"The mapping below is a **design requirement, not an implemented preview guarantee**."* | 契约=设计目标 |
| `docs/threat-model-v2.md` L116–119 | *"Android SELinux cannot install a private policy into a conventional shared host kernel. Protected media, hardware attestation, and **Play Integrity are not supported claims**."* | 身份/DRM 明确免责 |
| `docs/KNOWN_ISSUES.md` L10–18 | 属性投影 *"does not change image signing, SELinux enforcement or hardware attestation, and **cannot guarantee acceptance by every app or Play Integrity**"*；*"On the Moto cell, Play reports an **uncertified device**."*（L232） | 与〔兼容〕J2 同向 |
| `docs/KNOWN_ISSUES.md` L243 | *"Runtime **DRM/integrity behavior remains untested**."* | 未测 |
| `android/hardware/README.md` L7–8 | *"**Dedicated sensor, vibrator and camera brokers are not established preview features.**"* | 三类外设 broker 不存在 |
| `docs/audio-integration-proposal.md` L6–9 | *"Status: shared-pool bridge implemented; host loopback validated … **Microphone capture and wider device validation remain required**."* | 音频播放通、录音未验 |

**接口稳定性判读**：有 5 份 versioned 契约（`runtime-layout-v1`、`binderfs-v1`、`text-input-v1`、
`navigation-insets`、`frame-timeline-v1`）+ 一份私有线协议 `droidloom-host-v1`，全部带 v1 号；
但版本号 **0.1.0-25**（10-24 前已连发 7 个修订号 19→25）、单作者，**改动节奏 = 日更**。⇒ 契约"有版本号"，**内容稳定性未验证**；
本文件所有引用都钉 commit `0af7b9b`。

---

## 2. 硬门槛逐条判定

口径：**「有」= 有实测或配置证据；「缺」= 缺具体动作，且写明动作属于哪一层（上游/我们/两者都要）**。
判定只用三档：**过**（有正面证据）/ **未过**（有反面证据或缺件）/ **未验证**（无证据）。

### 2.1 宿主合成器：`linux-dmabuf` v4 feedback ＋ `linux-drm-syncobj` ＋ 私有协议

上游要求原文（`docs/architecture.md` L107–109，commit `0af7b9b`）：
> *"The presenter requires `xdg-shell`, `linux-dmabuf` v4 feedback and `linux-drm-syncobj` synchronization."*

| 子项 | 需要什么 | 我们现在有没有 | 缺什么 |
|---|---|---|---|
| `xdg-shell` | `xdg_wm_base` | **有**（〔兼容〕§4.1 实测 `xdg_wm_base` v6） | — |
| `linux-dmabuf` v4 feedback | `zwp_linux_dmabuf_v1` ≥4 | **有**（实测 **v5**，含 v4 feedback 语义） | — |
| `linux-drm-syncobj` | `wp_linux_drm_syncobj_manager_v1` 全局 | **未过**：实测 registry **无该全局**；静态：phoc 0.55.1 内嵌 wlroots 0.20.0 且 `strings /usr/bin/phoc` 命中 `wlr_linux_drm_syncobj_v1.c`，但**没有 create 调用**（〔兼容〕§4.1） | **合成器层缺一次 global 创建**：① phoc 侧加 `wlr_linux_drm_syncobj_manager_v1_create()`（内嵌 wlroots 已有该实现；能否只靠这一行成立 = 未验证）；或 ② 换到已创建该全局的合成器 —— `sway` 在 **1.12 发布标签**的 `sway/server.c` L299 就有该调用（静态，`gh api … ?ref=1.12`）；或 ③ Denial |
| 私有线协议 `droidloom-host-v1` / `droidloom-denial-protocol` | **我们不需要实现**：它是 Android Composer ↔ droidloom presenter 的内部协议；`protocol/README.md` 明确 *"The public presentation boundary is the compositor's normal xdg-shell, linux-dmabuf, and linux-drm-syncobj implementation."* | 有该"不需要实现"的正面证据 | 我们**必须接受**它：合成器之外的私有协议只存在于 droidloom 自己的进程对里 ⇒ 与 Waydroid 的 LXC/`config_nodes`/HIDL 经验**零复用** |
| 内核侧 syncobj eventfd | presenter 在"有 eventfd 支持"的内核上才走事件驱动，否则退化 4 ms 轮询（`docs/architecture.md` L206–209、L479–480） | `build/vk151/.config`：`CONFIG_SYNC_FILE=y`、`CONFIG_DRM=y`；`CONFIG_DRM_SYNCOBJ*` 未在 `.config` 出现（推断：隐藏符号由 `DRM` 选中） | **未验证**：需设备侧一次 `DRM_IOCTL_SYNCOBJ_EVENTFD` 探针（不在本规划内执行）|

**小结**：三项里 **2 项有实测正面证据、1 项（syncobj 全局）未过**。这一条是**唯一由"桌面栈选型"决定的门槛**，
不是容器层能消化的（〔兼容〕§4.2 同结论）。

### 2.2 Adreno 830 + freedreno：接口与配方分解

上游的图形后端三选（`graphics_backend`）：`drm`（原生 Freedreno/Turnip）、`kgsl_dma_heap`（分裂宿主）、`drm_dma_heap`（只暴露 dma-heap + render node）。

| 需要什么 | 我们现在有没有 | 缺什么 |
|---|---|---|
| 原生 freedreno DRM 路径（`msm` + Adreno a8xx） | **有**：`/dev/dri/card0 = qcom,sm8750-dpu`、`renderD128` 在；容器内 `GLES: freedreno, Adreno 830, Mesa 26.1.8` 为历史实测（〔兼容〕§1） | 与 droidloom 的 **Mesa 26.1.7 + 其 Android 专项补丁集**（`0012/0013/0016/0017/0018`）在 aarch64 上是否一致 —— **未验证**；我们的 `mesa-build.sh` 是 Waydroid 的 11 库配方，**不可直接复用**（版本与补丁集不同） |
| `graphics_backend=drm` 需要 `/dev/dma_heap/system`（媒体缓冲） | **有，但需显式加载**：`CONFIG_DMABUF_HEAPS_SYSTEM=m`（`build/vk151/.config`），宿主已靠 `modprobe system_heap` 造 `/dev/dma_heap/system`（`PITFALLS/sessions/24-Waydroid容器.md` #189；**不要** `cma_heap`，#130） | 无新增动作；需在 droidloom 侧确认它接受**模块化**的 system_heap（其契约只写"host has it"） |
| 线性 modifier only、单次分配 ≤1 GiB、单维 ≤16384 px、**拒绝 protected allocation**（`docs/architecture.md` L71–74） | 面板 = 1904×3040 @165 Hz（实测），单维已 3040 ≤16384 ✓；分配上限对本机无冲突 | **protected allocation 被拒绝** ⇒ 受保护视频通路（Widevine L1/L3 硬件路径）**结构性无解**；与本机"arm64 无 L3 库"叠加后不影响现状，但封死了将来走 TEE 的想象空间 |
| GPU 恢复（作者实测：GMU timeout + translation fault 后 Denial/SurfaceFlinger 无限等 fence、整桌面卡死；`docs/BUILDING.md` L942–948） | 我们的 Q24/Q28 已把"GPU/显示恢复"当作一等风险 | **无对策**：上游自己也写 *"No GPU recovery fix has been applied"*。这一条是长跑稳定性风险，不是门槛 |

**小结**：**「Adreno 830 能不能跑」= 未验证**（无本机型记录，也无同代 SM8750 第三方记录）；
但**接口层面不缺件**（freedreno DRM + dma_heap 都有），真正缺的是 **aarch64 上把 droidloom 的 Mesa 配方重编一次**（工作量未估）。

### 2.3 binder / SELinux 语义降级对 G2（Play Integrity / Widevine）的影响

| 需要什么 | 我们现在有没有 | 缺什么 |
|---|---|---|
| 宿主内核 binderfs（私有实例、三设备） | **有**：`CONFIG_ANDROID_BINDERFS=y`、`ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`（`build/vk151/.config`） | 无内核动作。droidloom 会**自建**私有 binderfs（只 3 个设备），与 Waydroid 共用宿主 binder 的做法不同 |
| Android SELinux LSM（把 binder transaction SID 翻成安全上下文） | **没有**：`build/vk151/.config` 里 `SELINUX` 一个字都没有（grep 0 命中） | **上游也无解**：`docs/threat-model-v2.md` L116–118 *"Android SELinux cannot install a private policy into a conventional shared host kernel"*；droidloom 用 `binder-compat/0001..0003` 做 PID-context 回退，安全边界改成「宿主沙箱」 |
| Play Integrity device/strong | **未过**（〔兼容〕J2 = FALSE；`test-keys`/`userdebug`；软 keymaster ⇒ STRONG 结构性否证） | **droidloom 明确不改善**：`threat-model-v2.md` *"Protected media, hardware attestation, and Play Integrity are not supported claims"*；`KNOWN_ISSUES.md` L232 Moto cell 上 Play 仍报 *"uncertified device"*。它唯一的增量是**init 前统一属性投影**（三处读取一致），属**必要不充分**，与 C3 结论同向 |
| Widevine（任一等级） | **无**（vendor `mediadrm/` 只有 ClearKey） | droidloom 侧无 L3 库、无 TEE keymaster；且其分配器**拒绝 protected allocation** ⇒ 即便将来有 L3 库，硬件保护路径也不在契约内 |

**小结**：binder 层**过**（内核件齐）；SELinux **降级不可避免**（上游自述）；**对 G2 的净影响 = 0 或负**——
它既不提供 SELinux 语义，也不提供硬件证明；属性投影那一条我们**可以脱离 droidloom 单独搬到 Waydroid**。

### 2.4 相机（V4L2 输入 + camera-provider 是否可复用）

| 需要什么 | 我们现在有没有 | 缺什么 |
|---|---|---|
| 宿主 V4L2 出流 | **有**：G1-5 前后摄 `v4l2-ctl --stream-mmap` 连续出帧（历史实测） | — |
| droidloom 侧把 V4L2 暴露给 Android | **未过（契约级）**：`docs/contracts/runtime-layout-v1.md` L138–144 设备白名单原文 —— *"No `card*`, KMS, physical input, framebuffer, **camera**, media, USB, Bluetooth, modem, block, raw memory, or host control node is allowed."* | 需要 droidloom **改契约**（放开 camera 节点 + 加 camera broker）；`android/hardware/README.md` L7–8 原文 *"Dedicated sensor, vibrator and camera brokers are **not established preview features**."* |
| 复用我们的 `camera-provider-2-4-ext` | **不可复用（未验证但结构性）**：它是 Waydroid **vendor 镜像内**的 HIDL external provider（7 文件补丁，`patches/waydroid-camera-64bit-20261018/`），输入 = `/dev/video100` 的 v4l2loopback | droidloom 用**自己的 Android 17 vendor 镜像**且无 `/dev/video*`；`v4l2loopback.ko` 当前 UTS 甚至不存在（〔兼容〕§0.1 附） |

**小结**：**未过**，且不是"配一下"的量级 —— 需要上游先建 camera broker + 放开设备白名单。

### 2.5 音频（宿主 buffered playback + APEX）

| 需要什么 | 我们现在有没有 | 缺什么 |
|---|---|---|
| 宿主 PipeWire + session policy | **有**（实测 `alsa_output.platform-sound.HiFi__Speaker__sink`） | — |
| droidloom 音频桥 | **上游自述已实现**：`runtime/droidloom-audio` 是 per-user PipeWire broker，Android 侧 HAL 静态链接，4 个 sealed memfd、PCM16/48 kHz，broker 走 PipeWire application-buffer API（零拷贝）；**x86_64 test cell 已验证播放**（`docs/audio-integration-proposal.md`） | **录音未验**（原文 *"Microphone capture … remain required"*）；aarch64 上未验证；需要它的 `audio` APEX 一起构建（`--product droidloom_arm64`） |
| 我们 Waydroid 的 4 层音频修补（`media.omx` 移除 / `ccodec=4` / C2 XML / `/dev/dma_heap`） | 有（历史实测） | **在 droidloom 下作废**（都是 Waydroid 镜像内部缺陷的补丁），不构成门槛，但也**不产生迁移价值** |

**小结**：播放**可能已具备**（上游 x86_64 实测，aarch64 未验证）；**录音未验证**；我们现有音频资产**不可迁移**。

### 2.6 传感器（宿主 IIO 而非 UDP HAL）

| 需要什么 | 我们现在有没有 | 缺什么 |
|---|---|---|
| 宿主传感器数据源 | **半有**：`/sys/bus/iio` **恒空**；真值走 SSC（QRTR svc 400）→ `hexagonrpcd` → `ssccli` → `ssc-udp-relay` UDP → 容器内 `waydroid-sensord`（HIDL 1.0）（`packaging/elden-userland/services.tsv:36,42`） | droidloom **没有 sensor broker**（`android/hardware/README.md` 原文），且其 `/sys` 是**合成只读投影**（只投电池/充电 + CPU 拓扑），**不投 IIO**。⇒ 宿主 IIO 这条路在 droidloom 契约里**不存在**，需要上游新增 broker + sysfs 投影项 |
| 复用 `waydroid-sensord`（UDP → HIDL） | **不可复用**：它是 Waydroid `hardware/waydroid/sensors` 的 HAL，靠 Waydroid 的 vendor 镜像与 hwbinder 拉活 | 需要 droidloom 侧等价的 AIDL/HIDL 注入通道（契约里没有） |

**小结**：**未过**。注意〔接口〕把"传感器数据源"列为可抽象点②；本轮核实给它的**紧迫性下调**：
droidloom 现在**连消费端都没有**，抽象数据源格式并不能让它跑起来。

### 2.7 触觉桥（无 `/sys` bind 面）

| 需要什么 | 我们现在有没有 | 缺什么 |
|---|---|---|
| 容器内 vibrator HAL → 宿主 `aw86927` FF_RUMBLE | **有**（C10 已验收：容器写 `/run/elden-haptic/leds/vibrator`，`elden-hapticd` 轮询转 FF_RUMBLE，amplitude 必须 255） | droidloom 侧：`/sys` 是只读合成投影、`/dev/input` 是空 tmpfs、**没有 vibrator broker**（原文同理）⇒ 现有"bind 一个目录进去"的挂载面**根本不存在** |
| 桥的语义 ABI（`activate`/`duration`/`state`/`amplitude`） | 有（我们自己的稳定 ABI） | 承载方式需改（〔接口〕A3 已设计 Unix socket 行协议，~30 行），**但消费端（Android vibrator HAL）仍要上游提供** |

**小结**：**未过**；我们的抽象（A3）只解决"宿主侧怎么收"，不解决"Android 侧怎么发"。

### 2.8 门槛汇总

| # | 门槛 | 判定 | 卡在哪一层 | 一句话 |
|---|---|---|---|---|
| G-A | `xdg-shell` + dmabuf v4 feedback | **过** | — | 实测 v6 / v5 |
| G-B | `linux-drm-syncobj` 全局 | **未过** | 合成器（我们可改 phoc 或换 sway/Denial） | 唯一"我们自己能单方面解掉"的门槛 |
| G-C | 私有协议接受度 | **过（但零复用）** | 架构 | 不需要我们实现，也不需要我们兼容 |
| G-D | Adreno 830 + freedreno | **未验证** | 上游 Mesa 配方 + 本机型无先例 | 接口不缺件，配方要重编 |
| G-E | binder / SELinux 降级 × PI/Widevine | **未过（对 G2 无净增益）** | 上游明确免责 | 属性投影可单独搬走 |
| G-F | 相机 | **未过（契约禁止）** | 上游新增 broker + 白名单 | 我们的 provider 不可复用 |
| G-G | 音频 | **部分过**（播放）/ 录音未验证 | 上游 + aarch64 未验 | 我们资产作废 |
| G-H | 传感器 | **未过** | 上游无 broker；二来我们 IIO 为空 | 现有 UDP HAL 不可复用 |
| G-I | 触觉桥 | **未过** | 上游无 broker | 抽象只解宿主侧 |

---

## 3. 与本机现有栈的冲突面

### 3.1 Phosh/phoc 能不能换（代价与回退）

现役桌面（〔深读〕+`reports/mobian-migration-plan-20261021.md` §1.4）：`greetd` + `phosh-session` + **phoc 0.55.1**（静态内嵌 **wlroots 0.20.0**）+ **phosh 0.55.0**，
外加我们**自维护的两枚用户态补丁**：

| 补丁 | 对象 | 内容 | 换合成器后的命运 |
|---|---|---|---|
| `patches-userland/0001-phoc-honor-any-mode.patch` | phoc `output.c`（1 行） | 165 Hz/自定义 mode 不再被 `mode->preferred` 覆盖 | **作废**（新合成器自带自己的 mode 逻辑；Denial 侧"运行时改缩放/模式要重启会话"） |
| 0002（phosh `monitor-manager.c` 缩放吸附） | phosh | 缩放直报无吸附 | **作废** |

三条候选路线与代价：

| 路线 | 具体动作 | 代价 | 回退 |
|---|---|---|---|
| **A. 给 phoc 补一次 global** | 在 phoc 构建分支里加 `wlr_linux_drm_syncobj_manager_v1_create(display, 1, …)`（内嵌 wlroots 0.20.0 已含实现，`strings` 命中；`sway` 1.12 的 `server.c` L299 是现成参照） | **最低**：一行级改动 + 重编 phoc（+ 一枚我们自己的补丁）；风险 = 显式同步语义在 msm DRM 上**未验证**（可能触发未预见 fence 等待/卡帧） | 保留旧 phoc 二进制，换回 `greetd` 会话文件即可 |
| **B. 换 sway/wlroots 系** | 桌面壳从 Phosh 换到 wlroots 系 | **高**：丢 Phosh 的手机形态（状态栏/OSK/旋转/锁屏/拨号无关但自适应布局）、丢 `iio-sensor-proxy` 旋转集成、丢 C11 中文输入法验收（phoc 的 text-input 路径）；G1 日常桌面全盘重验 | 需保留双会话；Phosh 包与配置不动 ⇒ 可回退，但**双桌面并存**期间两份状态（缩放/mode/输入法）要各自维护 |
| **C. 换 Denial** | 用 Denial 的 mobile profile | **最高**：Denial **无 aarch64 发布包**（21 个 release 全 x86_64/amd64），需自建 **pin 死的 Flutter 引擎 fork**；作者自陈两个**会话级致命坑**（GPU reset 终结会话；运行时改缩放直接 `GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT`）；direct scanout 未实现；不捆绑中文输入法 | 同 B（双会话），但 Denial 的构建体量/可复现性**未评估** |

**判读（一次正反判断）**：**A 是唯一"不动 G1 桌面栈"的路径**；B/C 都是**桌面选型变更**，属于 G1 决策，不能由 G2 的需求倒推。
且即便 A 成功，也只解掉 G-B 一项门槛 —— §2 里 G-F/G-H/G-I 三项仍卡在上游。

### 3.2 内核侧前置（逐项：现状 / 还缺什么）

证据源：`build/vk151/.config`（在役内核配置的仓库副本）。

| 前置 | 现状 | 还缺什么 |
|---|---|---|
| binderfs | `CONFIG_ANDROID_BINDERFS=y`、`ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"` | 无（droidloom 自建**私有** binderfs，反而比 Waydroid 少一次冲突） |
| cgroup v2 可委派（memory/pids/freezer） | `CGROUPS=y`、`MEMCG=y`、`CGROUP_PIDS=y`、`CGROUP_FREEZER=y`、`CGROUP_BPF=y`、`PSI=y` | **未验证**：设备上是否为 unified v2、`/sys/fs/cgroup` 是否可委派（droidloom 契约要求"new cgroup namespace + 宿主 cgroup 句柄"，其自身文档记录过 `CLONE_NEWCGROUP` 后再建 legacy hierarchy 会 `EPERM`） |
| 命名空间 | `USER_NS/PID_NS/NET_NS/UTS_NS/IPC_NS` 全 `=y` | 无 |
| seccomp | `SECCOMP=y` | 无（契约里"general seccomp sandboxing"是上游未完成项，不是我们的） |
| Android SELinux LSM | **无**（`.config` 里零命中） | 无法补（上游同结论），只能接受降级 |
| dma-heap | `DMABUF_HEAPS=y`、`SYSTEM=m`、`CMA=m` | 需 `system_heap` 已 `modprobe`（本机已有 `/etc/modules` 条目）；**不要** `cma_heap`（`PITFALLS #130`：造 `/dev/dma_heap/reserved` 干扰 libcamera） |
| syncobj eventfd | `SYNC_FILE=y`；`DRM_SYNCOBJ*` 未显式出现在 `.config`（推断：由 `DRM` 选中） | **未验证**：需一次 `DRM_IOCTL_SYNCOBJ_EVENTFD` 探针 |
| 输入 | 宿主 evdev/触屏/键盘齐 | droidloom 侧 `/dev/input` 是**空 tmpfs**（输入由宿主独占并注入），我们的触屏中文输入法验收**不可平移** |

### 3.3 服务管理形态冲突（新发现，〔深读〕未记）

droidloom 的交付形态是 **pacman + systemd**：`packaging/systemd/system/droidloomd.service`、`packaging/systemd/user/droidloom{,-audio,-recovery,-applications}.service`（**systemd 侧 5 个 unit**，另有 `packaging/arch/droidloom.service`；`gh` 代码检索 `extension:service` = 6 条，静态核实）。
本机现役是 **Alpine + OpenRC**（`packaging/elden-userland/services.tsv` 21 行，`render.py` 派生 openrc/systemd 两套）。
⇒ 换 droidloom = **再写一套 OpenRC 等价 unit**（或整体切到 Debian/systemd 线，属 `reports/modular-mobian-transition-20261026.md` 的范围）。

### 3.4 Waydroid 资产：哪些可迁移、哪些作废

| 资产 | 位置/体量 | 迁移判定 |
|---|---|---|
| **属性投影做法**（init 前统一投影、三处读取一致） | 概念（无文件） | **可迁移**：与 droidloom 无关，可单独落到 Waydroid 镜像 property overlay（〔接口〕A8） |
| 宿主 GPU 栈（freedreno/Turnip + Mesa 26.1.8） | Alpine apk（零编译） | **共用**：droidloom 的 `graphics_backend=drm` 走同一套宿主 DRM/freedreno（`packaging/cell-spec-arm64.json` L215 `"graphics_backend": "drm"`，静态） |
| Android 侧 Mesa 11 库配方（`scripts/mesa-build.sh`） | 2.5 KB 脚本 + 产物 | **作废**：droidloom 用 **Mesa 26.1.7 + 自己的 Android 补丁集**，版本/补丁集不同 |
| `camera-provider-2-4-ext` + 7 文件补丁 | `patches/waydroid-camera-64bit-20261018/`（92 KB） | **作废**（契约禁 camera 节点，且镜像不同） |
| 触觉 AIDL HAL 补丁 + `elden-hapticd` | `patches-userland/waydroid-haptics-aidl/`（52 KB）、`scripts/elden-hapticd.c`（13 KB） | **HAL 侧作废**；`elden-hapticd` **本体保留**（宿主 daemon 与容器无关），只需换输入承载（〔接口〕A3） |
| `waydroid-sensord` + `ssc-udp-relay` | `packaging/elden-userland/sources.tsv` | **HAL 侧作废**；`ssc-udp-relay` 作为**宿主数据源**保留（但 droidloom 无消费端） |
| LXC `config_nodes` 经验 / `waydroid-ipv6` 桥 / `waydroid_base.prop` / `show-full-ui` 单窗口 | `services.tsv:38,43`、`files/usr/local/sbin/waydroid-*.sh` | **全部作废**（droidloom 无 LXC、用 netns，窗口模型是 per-task toplevel） |
| LOS 20 / A13 arm64 镜像 + GApps 资产 | 设备侧 `linux18` | **作废**：droidloom 要求**自己的 Android 17 pinned 镜像 + LiteGapps arm64 add-on**（`--product droidloom_arm64`） |
| 三大抽象点（`container-backend`/`sensor-source`/`haptics-bridge`） | `deps.tsv:61–63` | **保留但下调优先级**：抽象本身没错，但 droidloom 现在**没有可插入的消费端**（§2.6/2.7），切后端在半年内不会发生 |

### 3.5 构建与磁盘冲突（数字）

| 项 | 上游要求 | 本机现状 | 冲突 |
|---|---|---|---|
| 构建机架构 | `docs/BUILDING.md` §1：**x86_64 build machine** + rootless Podman Arch 容器 | 主机 = x86_64 / 28 线程 / 60 GiB RAM / **430 GiB 空闲** | 架构满足，但**产物是 x86_64 包**，不能给 aarch64 设备用 |
| 峰值磁盘 | **120 GiB**（含源码/工具链/输出/暂存） | 主机 430 GiB 空闲 ✓；设备 `linux17` = **193 GiB**（`TASKS §5 Q7`，现役占用未知，本轮不可读） | 主机够；设备侧需先量占用 |
| aarch64 宿主编译 | **无文档化流程**（只在作者 "Pad 4 workspace" 出现过） | 无 | **这是最大的未知成本项**：要么在设备上装 Rust + 交叉编 Android 组件（Alpine/aarch64 上跑 Arch podman 容器 = 未验证），要么自建 x86_64→aarch64 cross 流程（未验证） |
| 交付格式 | `.pkg.tar.zst`（pacman）+ systemd unit | Alpine `apk` + OpenRC | 需转包 + 重写 unit（§3.3） |

---

## 4. 隔离试验设计（不改现有桌面）

**总原则**：① 一切实验**不写 boot 分区、不改 `greetd`/`phosh-session`、不动 `/usr`**；② 新东西只落 `/opt/droidloom-trial`、
独立宿主用户、独立 `image_dir`、独立 `XDG_RUNTIME_DIR`；③ 每步 `timeout -k 10 540`（<10 min），长构建拆成"启动作业 + 10 min 轮询"；
④ 任何一步出现与 `PITFALLS`/`RUNBOOK` 已知模式不符的错误即停（`AGENT-OPS` §1）。

### 4.1 分级实验（成本递增，每级都有独立否决权）

| 级 | 内容 | 需要的主机资源 | 单步上限 | 通过判据（二值） | 不通过则 |
|---|---|---|---|---|---|
| **L0** | 本文件 §1/§2 的静态复核（**已完成**） | 0（`gh api` 只读） | — | 已有结论 | — |
| **L1** | 现有桌面里的**协议探针**（只读）：`WAYLAND_DEBUG=1 wlr-randr` 抓 registry，确认 `xdg_wm_base` / `zwp_linux_dmabuf_v1` / `wp_linux_drm_syncobj_manager_v1` 三全局 | 设备 1 个 shell（**不重启、不改配置**） | 60 s | 三全局齐 = 是；否则 = 否（当前记录为**否**，见〔兼容〕§4.1） | 走 L2（补 phoc global） |
| **L2** | **phoc 单点实验**：在设备 `/opt` 另编一份 phoc（内嵌 wlroots 0.20.0 + 一行 `wlr_linux_drm_syncobj_manager_v1_create`），**只在该二进制的临时会话**里验证（`greetd` 会话文件不动） | 设备：phoc 源码树 + 编译工具链（一次性，估 ≤2 GiB）；编 phoc 时间**未估算**（内嵌 wlroots 静态编，估 10–30 min 量级） | 编译 540 s ×N（轮询） | 新会话里 `wayland-info` **出现该全局**，且 `wlr-randr`/合成画面无回归（面板有内容、165 Hz 不变） | 停：记"改 phoc 有回归"，本条线与换合成器一并关门（§4.4 E1） |
| **L3a** | **x86_64 构建门**（只为验证管线与我们的工具链，产物不用于设备）：`cargo run --locked -j 1 -p droidloom-package -- build` | 主机：**120 GiB** 峰值磁盘（现有 430 GiB 空闲 ✓）、Podman rootless、联网拉 pinned 输入 | 启动作业 `timeout -k 60 10800`（3 h 硬截止），轮询每 540 s 一次 | 产出 `dist/arch/0.1.0-*/{runtime,image}-*.pkg.tar.zst` 且 `droidloom-package check` 通过 | 连续 2 次（各自 ≤3 h）无诊断性失败 ⇒ 记"管线在本机不可复现"，**不启 L3b** |
| **L3b** | **aarch64 交付路径 spike**（上游无文档 ⇒ 必须先证） | 主机 + 设备：设备需 Rust 工具链；或主机 cross（未验证） | 每天 ≤1 个 spike，单个 540 s 步 | 产出一个**能 `pacman -Qp`/解包成功、且 `file` 显示 aarch64 ELF 的 runtime 包** | 1 个工作日内拿不到 ⇒ 判"aarch64 宿主编译路径不成立"，**直接进 §5 的"等上游"** |
| **L4** | **cell 运行门**（仅当 L1/L2 过 **且** L3b 出包）：独立宿主用户 `uid 1001`（`subordinate 300000..399999`，`packaging/cell-spec-arm64.json` 静态值）+ 独立 `image_dir` + **独立合成器会话**（L2 的 phoc 或 sway） | 设备：镜像 ~**0.95 GiB**（image 包）+ runtime 6 MB + `/data` 数 GiB | 540 s/步 | ① `droidloomctl start` 到 Android 就绪；② `launch com.android.settings` 出现**宿主 `xdg_toplevel`**；③ 原生桌面会话不受影响（原 Phosh 仍在跑） | 停在 L4 记录失败签名，不改宿主 |

### 4.2 明确**不做**的实验（避免走成迁移）

- 不把 droidloom 装进 `/usr`、不写 pacman 库、不改 `greetd`/`phosh-session`/`qbootctl`；
- 不为了 L4 去改 droidloom 的 `runtime-layout-v1` 设备白名单（那是上游契约，改了就不是"验证上游"而是"分叉"）；
- 不在设备上跑任何 `reboot`/`fastboot`/`ssh` 写操作（本轮与后续 L1–L2 都不需要）。

### 4.3 时间与磁盘账（估算，标注为估算）

| 项 | 估算 | 依据 |
|---|---|---|
| L1 | 2 min | 一条命令 |
| L2 | 0.5–1 天 | 编 phoc（现有 `patches-userland/build-phoc-phosh.sh` 已是同形态构建，可复用流程） |
| L3a | 3 h（上限）/ 1 次联网拉取 | 上游自述 120 GiB、32 GiB RAM/16 CPU 机跑过；本机 60 GiB/28 线程更强 |
| L3b | **未估算**（可能 0 也可能数天） | 上游**无** aarch64 宿主编译文档 ⇒ 这是最大不确定项 |
| L4 | 0.5–1 天（若前面都过） | 只需起动 + 装 APK + 观察 |

### 4.4 退出条件（满足任一即**放弃本条线**，不做"再试一次"）

1. **E1**：L2 在新 phoc 里造出全局，但 msm DRM 上出现可见回归（掉帧/黑屏/KMS commit 失败）且 2 次单变量试验无法收敛
   ⇒ "改 phoc"和"换合成器"两条都关门。
2. **E2**：L3b 在 1 个工作日内**拿不出 aarch64 runtime 包**，或需要改动宿主 boot/内核以外的东西超过 2 处
   ⇒ 交付路径不成立。
3. **E3**：上游在**连续 2 个 `packages` 修订**里仍无 aarch64 资产，且 `android/hardware/README.md` 的
   "sensor/vibrator/camera brokers are not established preview features" 仍成立 ⇒ 即使跑起来也只是"能开设置页"，
   对 G2 的验收用例 U3/U4/U7 无意义。
4. **E4**：任何一步要求我们**改 G1 日常桌面**（换合成器/换会话管理器/改 boot）才能继续 ⇒ 立即停（这不是试验成本，是产品决策）。

---

## 5. 结论与排序

### 5.1 三档结论（每条给"一句话理由 + 可复算判据"）

| # | 对象 | 裁决 | 一句话理由 | 可复算判据（命令/检查，只读） |
|---|---|---|---|---|
| **1** | **droidloom 替换 Waydroid 作 G2 主/备路线** | **等上游** | 9 项门槛里 3 项（相机/传感器/触觉 broker）是**上游明确未提供**、aarch64 交付路径**无文档**、且对 PI/Widevine **无净增益** | `gh api repos/denialwm/droidloom/releases --jq '[.assets[].name\|select(test("aarch64"))]\|length'` **= 0**（当前）；`android/hardware/README.md` 仍含 *"sensor, vibrator and camera brokers are not established preview features"* |
| **2** | **aarch64 自建（L3b）** | **不做**（现在） | 上游无文档化 aarch64 宿主流程，唯一证据是作者私有 "Pad 4 workspace"；投入即等于替上游做 port | `docs/BUILDING.md` §1 标题仍为 *"Prepare an **x86_64** build machine"*；`docs/INSTALL.md` L3 仍写 *"covers the **x86_64** … preview"* |
| **3** | **给 phoc 补 `linux-drm-syncobj` global（L2）** | **现在做（机会型，1 天，非阻塞）** | 这是**唯一由我们单方面解掉**的门槛（内嵌 wlroots 0.20.0 已含实现），且失败代价只有一份 `/opt` 二进制 | 判据 = L1 实测 registry 仍缺 `wp_linux_drm_syncobj_manager_v1`；L2 判据 = 新会话出现该全局且面板/165 Hz 无回归 |
| **4** | **Denial 作 G1 桌面** | **等上游** | 21 个 release **全部 x86_64/amd64**（0 个 aarch64），且作者自陈 GPU reset / 运行时改缩放两个**会话级致命坑** | `gh api repos/denialwm/denial/releases --jq '[.[].assets[].name\|select(test("aarch64"))]\|length'` **= 0** |
| **5** | **属性投影做法搬进 Waydroid 镜像** | **现在做（与本线解耦，排在 G2 主线之后）** | 与 droidloom 无关的**必要不充分**改进；上游自己也只主张"三处读取一致"，不主张过 PI | 判据 = C3 的 PI 三档回包取证（当前：`test-keys`/`userdebug` 直出 ⇒ device integrity 必失败） |
| **6** | **droidloom 的 AOSP/Mesa 补丁按需 cherry-pick** | **现在做（零成本参考）** | `0001/0009/0016` 直接对应我们 Waydroid 侧的 bpfload / netd PID-ns / Turnip HWUI 失败模式；搬的是**参考**不是代码 | 判据 = 先在 Waydroid 上复现对应失败签名，再 cherry-pick（无失败签名则不搬） |
| **7** | **〔接口〕A1/A2/A3 三大抽象** | **降级为"等上游出现 broker 再做"**（本轮不追加实现） | 抽象的前提是"有第二个真实候选"；本轮核实 droidloom **没有传感器/触觉的消费端** ⇒ 现在抽象只增维护面 | 判据 = 上游 hardware README 出现 sensor/vibrator broker 且发布 aarch64 资产 |
| **8** | **redroid（R1'）作为短期对照** | **不变**（仍为 R1 受阻时的备胎） | 与本线无关；但它是唯一"今天可跑"的第二容器形态 | 判据同 `TASKS §6` R1' 行 |

### 5.2 排序（若明天就要动手）

```
① L1 协议探针（2 min，零风险）→ ② L2 phoc 一元补丁（1 天，可回退）
③ 属性投影 byproduct（半天，独立小改进）
④ L3a x86_64 构建门（3 h 机时，只为验证管线；**不产出设备可用物**）
── 到此为止 ──  ⑤ L3b/L4 只有在 ① 过 且 上游出 aarch64 资产 且 broker 出现 时才启动
```

**一句话**：**唯一值得现在花的钱是"L2 一元补丁 + L1 探针"**（≤1 天，去掉我们唯一能自解的门槛）；
**其余等上游**（aarch64 资产 / 三个外设 broker / Denial 的 aarch64 包），**aarch64 自建现在不做**。

---

## 6. 未验证清单与边界

### 6.1 未验证（不得当结论使用）

| # | 项 | 状态 |
|---|---|---|
| 1 | Adreno 830 + freedreno 上 droidloom 的真实表现（帧率、fence、恢复） | **未验证**（本机型 0 记录；同代 SM8750 第三方 0 记录） |
| 2 | droidloom 的 Mesa 26.1.7 + 其 Android 补丁集在 aarch64 上能否编过/跑对 | **未验证** |
| 3 | 宿主内核 `DRM_SYNCOBJ` eventfd 支持（只知 `SYNC_FILE=y`，未跑 ioctl 探针） | **未验证** |
| 4 | phoc 补一次 global 后 msm DRM 的显式同步行为 | **未验证**（L2 的全部意义就是验证它） |
| 5 | 设备上 cgroup v2 是否可委派（契约要求 new cgroup ns + 宿主 cgroup 句柄） | **未验证** |
| 6 | aarch64 宿主包能否在本机现有工具链下产出 | **未验证**（上游无文档） |
| 7 | droidloom 的 `systemd` user unit 在 OpenRC 下的等价改写成本 | **未估算**（只知有 5 个 systemd unit + 1 个 arch unit） |
| 8 | 上游 `packages` 修订的发布节奏（release 条目 2026-10-24 更新、含 7 个修订号 19→25；无 release notes/changelog 文件） | **未验证**（只能看 commit message，单作者） |
| 9 | Denial ARM64 源码构建体量/可复现性（需自 pin Flutter 引擎 fork） | **未评估**（〔深读〕§7 同结论） |

### 6.2 与既有文档的口径差异（建议后续并入，不在本轮改文件）

1. **〔深读〕§3.3** 说 `android/device/droidloom_arm64/` 是"一等产品配置" ⇒ 本文件 §1.4 建议改为
   **"ARM64 目标存在、作者真机跑过、不发布、不文档化宿主构建"**（区别：产品配置 ≠ 交付产物）。
2. **〔兼容〕§4.1 G1** 写"需自行构建 + 转 pacman 包到本 rootfs" ⇒ 本轮补充：**宿主编译流程本身没有 aarch64 文档**，
   不只是"转包"问题。
3. **〔接口〕§3** 把 A2/A3 列为"现在必须抽象" ⇒ 本轮建议**下调**：消费端（Android 侧 broker）不存在，抽象无落点。

### 6.3 边界（本轮做了什么 / 没做什么）

- **做**：`gh api` 只读核实 droidloom（59 提交 / 413★ / 1 个 release / 0 个 aarch64 资产 / 7 份文档与契约原文）、
  Denial（21 个 release / 0 个 aarch64 资产 / 179 提交）、本机内核配置（`build/vk151/.config`）、
  主机资源（430 GiB 空闲 / 60 GiB RAM / 28 线程）。
- **没做**：`git clone`（**0 次**）、任何包下载（**0 B**）、设备动作（**ssh/adb/fastboot 一条未发**）、
  构建（**0 次编译**）、`TASKS/DEVICE/INDEX/PITFALLS/versions/README` 改动（**0 处**）、git 提交（**无**）、
  发邮件/开 issue（**无**）。
- **唯一写入**：本文件 `reports/droidloom-feasibility-plan-20261030.md`。
