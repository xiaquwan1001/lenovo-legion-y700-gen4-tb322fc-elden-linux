# 2026-10-26 · denial + droidloom 深度评估

- **日期**：2026-10-26
- **pi 会话 id**：`01a17623-ca03-70c3-b81f-097c03742b05`
- **主题**：只读拆解同一作者（`denialwm` / Doctor Logix）的两个仓库——`denial`（Wayland 合成器）与 `droidloom`（shared-kernel Android 用户空间），判定对本仓 G1/G2/G3 的真实增量
- **结论（一句话）**：**G2 不换路线（Waydroid/redroid 仍是主线），但拿到 3 类可搬资产**——① droidloom 的 **19 个 AOSP/Mesa 共享内核补丁**（binder SID 回退、netd/bpfload 适配、cgroup 描述、Mali/Adreno 用户态）；② **「release 式构建属性投影」**（`ro.debuggable` 清零、`test-keys` 替换、secure ADB）这条对 C3/Play Integrity 的**必要不充分**对策；③ **Android 层直出 Wayland 子表面**的架构（跳过 SurfaceFlinger 合成，per-task `xdg_toplevel`）。同时 **G1 多一个 UI 候选**：Denial 已有 mobile 模式并在 Moto Edge 70 真机做过 FOD/双击唤醒/旋转锁定/insets，是唯一被同代手机+平板验证过的 Flutter 壳合成器。**两者都不进当前施工队列**（需自建 ARM64 包，且 droidloom 要求合成器支持 `linux-drm-syncobj`）。
- **证据指针**：本文件 §2–§5（逐节标出上游文件路径）；上游 == `github.com/denialwm/denial@c96375a`（main，2026-10-11）、`github.com/denialwm/droidloom@ffccef6`（main，2026-10-24）；总览行仍见 `RESOURCES/README.md` §1.3 与 `TASKS/README.md` §5 Q3
- **★SSOT 待并入**：✅ **已并入（2026-10-26，同会话）**：`TASKS/README.md` §5 **Q3**（arm64 从「官方目标但无公开包」→「aarch64 一等产品 + 合成器 `linux-drm-syncobj` 前置 + PI 未验证」）与 §5 **R3** 行；`RESOURCES/README.md` §1.3 droidloom 行（251★→406★）与**新增 `denialwm/denial` 行**（G1 UI 层候选）；另拆掉原 `Droid-VM/DroidVM、denial` 的错误合并行。

---

## 1. 两仓是什么（硬数字先给）

| | `denialwm/denial` | `denialwm/droidloom` |
|---|---|---|
| 定位 | **Wayland 合成器**（Rust + Smithay 管协议/输入/KMS；Flutter 画壳与窗口） | **Linux 上跑 Android 应用**（shared-kernel Android 用户空间，每个 task 一个普通 Wayland `xdg_toplevel`） |
| 星数 / 首个 commit | 1354★ / 2026-07-17 | 406★ / 2026-09-06 |
| 最近 push / commit 数 | 2026-10-24 / 212 | 2026-10-24 / 43（**日更**） |
| 许可 | GPL-3.0-or-later（原厂代码）+ 第三方各自许可 | 同上 |
| 二进制发布 | x86-64 首发包（Arch/Debian/Fedora/Alpine/NixOS）；**ARM64 只支持源码自建** | **只发 x86_64 Arch/Omarchy pacman 包**；**aarch64 有打包流水线但无发布包** |
| 状态 | 0.2.x 公开 beta（配置/接口 1.0 前可变） | 早期预览（`docs/KNOWN_ISSUES.md` 46 KB 全是限制） |
| 作者自述 | 「与 OpenAI Codex 持续对话生成代码，Doctor Logix 做设计与真机测试」 | 同 |

两仓是**一条栈**：droidloom 依赖 Denial 的私有协议（`graphics/droidloom-denial-protocol`、`droidloom-denial-ipc`），并且 droidloom 的 insets 协议版本 2 是为 Denial 新增的 `get_keyboard_inset` 而升的；Denial 的 `docs/MOBILE_APP_INSETS.md` 直接把 droidloom 的 Rust 调用当示例。作者的真机池同一个：**Moto Edge 70（`roadstr`）手机 + OnePlus Pad 4（ARM64 平板）**——正好是「同代高通/联发科手机+平板」这一类，与我们的研究对象同一档位但不是同一 SoC。

---

## 2. Denial：能为我们 G1 提供什么

### 2.1 架构（三层，都不神秘）

1. Rust + Smithay：Wayland 协议状态、原生资源、libinput/libseat/udev、DRM/KMS 呈现（自研 `volition` 提交原子 KMS，捕获并恢复「进入前」的 KMS 状态）、输出事务/热插拔。
2. Flutter 壳：桌面视觉与交互策略，走版本化的「合成器↔壳」契约（FlatBuffers 协议 + `denial_sdk` / `denial_flutter_sdk`）。
3. 参考壳 = 一堆**插件**（顶栏/启动器/时钟都已是插件），支持 `denialctl ui setup` 现场改 Dart 热重载、坏了 `denialctl ui restore` 回退。

### 2.2 mobile 模式（对 Y700 直接相关）

- 壳 profile 由 `DENIA_SHELL_PROFILE=mobile` **精确显式请求**才启用，默认仍是 desktop（fail-safe）——见 `CHANGELOG.md`。
- `docs/MOBILE_APP_INSETS.md`：移动合成器在应用内容上方保留 **48 逻辑像素**状态条，并新增可选全局 `denial_insets_manager_v1`；客户端在首帧 `set_self_managed(wl_surface)` 声明自管 insets，合成器不再替它垫。
- `docs/ROTATION_LOCK.md`：旋转锁由**原生**持有（锁「当前已应用朝向」，不是自然朝向），传感器读数持续但锁定时不应用，解锁用最近一次**有效**读数；策略存 `settings.json` 原生侧，壳只能请求 enabled。
- `docs/hardware/WAKE_GESTURES.md`：root 拥有的 `/etc/denial/wake-gesture.json` 走 evdev 硬件手势源（Moto Edge 70：双击节点 `BTN_TRIGGER_HAPPY6`=709、输出 DSI-1）；还需要触控控制器侧持久开关（Roadstr：`/sys/class/touchscreen/primary/gesture` 写十进制 49）。**原文明确「无需新内核」**——这条对我们「用主线内核 + 原厂触控驱动」的假设是正面证据。
- `docs/libeis_support_plan.md`、`docs/research/thread-inventory/*`（含 `2026-09-08-moto70.json`）：EIS 触控预测、线程清单实测。

**判读**：这是「把手机当桌面」的完整形态参考（状态条/旋转/唤醒手势/指纹 FOD 的权限模型），不是内核工作。它对我们 G1 的价值是**UI 层选型**（Denial vs Phosh vs GNOME Mobile），不是驱动。

### 2.3 已知硬坑（都要当真，别当宣传）

按 `docs/KNOWN_ISSUES.md`：

| 坑 | 后果 | 对我们的意义 |
|---|---|---|
| **GPU reset 会终结合成器会话** | AMDGPU ring timeout 后 EGL 上下文失效 → 整个桌面进程退出；作者承认「应做 reset-aware 上下文 + 重建渲染器」尚未做 | 移动 SoC 上 GPU 恢复（我们已在 Q/G1 侧踩过）同样是单点致命；任何选 Denial 的方案必须自评 GPU 恢复 |
| **运行时改显示缩放会结束会话** | `GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT (36054)`，需停机改 `outputs.conf` 再启动 | 与我们 165 Hz/自定义 mode 的场景直接冲突（缩放/模式切换必须重启会话） |
| 混合 GPU 无跨卡呈现回退 | 只能用「共享 modifier 的 DMA-BUF」跨卡；弱核显拥有面板时性能受限 | Y700 单 GPU，无此问题 |
| Impeller 动画层内存 | 4×MSAA + depth/stencil + resolve ≈ **36 B/px**（1080p 约 75 MiB，4K 约 300 MiB），引擎保 4 帧 | 平板 2.5K/3K 屏 + 玻璃模糊桌面要按此估内存 |
| X11 窗口必须保留服务端装饰 | Impeller blur 缺陷未修 | G3（Box64+Wine 走 Xwayland）时要留意 |
| 文本输入 | 内置键盘只对开 `zwp_text_input_v3` 的客户端能打任意 Unicode；X11/无 text-input 的客户端只有 US 键盘回退；**不捆绑中文输入法** | 中文输入需外挂 Fcitx5 走 `zwp_input_method_v2` |

### 2.4 与我们既有栈的关系

- 不依赖 systemd 以外的新服务（明确 non-goal：不替代 NetworkManager/BlueZ/PipeWire/logind）。
- 需要 DRM/KMS 原子提交 + GBM/EGL + `linux-dmabuf`；**direct scanout 尚未实现**（`docs/direct_scanout.md` 明说 "not implemented yet"），当前是全桌面 Flutter 图集合成。
- 源码 ARM64 构建受支持（`docs/BUILDING.md` / `CROSS_BUILDING.md`），Flutter 引擎是**自己 pin 的 fork**（`denial/3.47.5`），首次构建体量不小。

---

## 3. Droidloom：形态与硬约束

### 3.1 cell 形态（`docs/architecture.md`、`docs/contracts/runtime-layout-v1.md`）

- **一个已登录宿主 UID = 一个 cell**（ID `u<uid>`）；Android UID/GID `0..99999` 一对一映射到一组 ≥100000 的 subordinate ID。「Android root」是**非特权**子 UID，不是宿主 root。
- 命名空间：**new user / PID / mount / IPC / UTS / network / cgroup** 全给；`init` 在 PID 命名空间内是 1；supervisor 用 **pidfd + 宿主 cgroup 句柄**做生命周期权威（**不靠进程名/扫 PID**）。
- 挂载树（要点）：`/system` `/vendor` `/product` 只读 nodev；`/data`、`/metadata` 直接是宿主目录（rw,nosuid,nodev）；`/dev/binderfs` 是**私有 binderfs，只建三个设备**；`/dev/input` 是**空私有 tmpfs**（宿主独占物理输入，防止 ueventd 重建 evdev 绕过 Wayland 焦点）；`/proc` 私有且隐藏宿主进程；`/sys` 最小只读投影。
- **安全边界要说清楚**（`android/binder-compat/README.md` 原文）：宿主内核**没有 Android SELinux LSM**，无法把 binder transaction SID 翻译成 Android 安全上下文 ⇒ 用 3 个补丁只在 `DROIDLOOM_CELL` 存在时走 PID-context 回退；「**开发 cell 以宿主沙箱为安全边界，内核对+策略就位前不得声称 Android SELinux 隔离**」。

### 3.2 图形路径（这是它真正的创新点）

- Android 侧：每个顶层 task 对应**一个宿主托管的逻辑 display**；Composer（AIDL/HWC3）**永不打开 DRM card/KMS 节点**，只跟私有 Unix socket 说话；SurfaceFlinger 仍算事务/可见性/几何/输入，但 **task 的 GPU 合成可被跳过**，把原始 Android layer 作为**同步 Wayland 子表面**交给宿主合成（`surfaceflinger/0007-droidloom-wayland-layers.patch`，`persist.vendor.droidloom.direct_layers` 默认开）。
- 宿主侧 presenter（Rust）：**要求 `xdg-shell` + `linux-dmabuf` v4 feedback + `linux-drm-syncobj`**；用 DMA-BUF + 显式同步，release fence 真回传（`0008-release-fences`）；opaque 区域回传（`0004-opaque-content`）。
- **这条要求是我们的硬否决点**：Phosh/GNOME/Mutter 不满足 `linux-drm-syncobj`；能用的只有 Denial 自己或带 `linux-drm-syncobj-v1` 的 wlroots 系（Hyprland 是作者实测环境）。
- 分配器：minigbm 保留原生 handle ABI，RGB/HDR/YUV/blob 全程共享 DMA-BUF；**只接受线性 modifier**、单次分配、plane 不重叠，单维 ≤16384 px、单分配 ≤1 GiB，**拒绝 protected allocation**。
- 音频：宿主侧 buffered playback 客户端（`android/audio/`）+ 一个 APEX 化的 audio service；**通话/基带留在原生**（明确 non-goal）。

### 3.3 ARM64 的真实现状（对应 Q3）

- `android/device/droidloom_arm64/` 是**一等产品配置**（不是实验开关）：VINTF、overlay、`droidloom-composer.rc`、audio APEX、cgroup 描述全在。
- 图形后端三选（cell 配置项 `graphics_backend`）：
  - `drm`（默认）：原生 Freedreno/Panfrost，Vulkan Turnip；
  - `kgsl_dma_heap`：**给「显示走 DRM、GPU 走 KGSL」的分裂宿主**——私有暴露 `/dev/kgsl-3d0` 与 `/dev/dma_heap/system`（校验内核身份），选 Zink GLES + minigbm 线性 dma-heap 分配；
  - `drm_dma_heap`：只暴露 `/dev/dma_heap/system` + 选定 render node，Mesa 仍原生选驱动（Panthor 宿主用）。
- Mesa：自建 **Mesa 26.1.7** + 一套 Android 专项补丁（见 §4），含 **Panfrost v11（Mali-G615/G715）反向移植**、Adreno 722 device entry、Turnip HWUI 双队列、Zink-on-KGSL 匹配、纹理上传 span 修正、`libdrm` 空版本串（Panthor 空 date 会让 SurfaceFlinger 在 EGL 初始化时崩）。
- 真机证据（`docs/KNOWN_ISSUES.md`、`android/mesa/README.md`）：**OnePlus Pad 4 上跑 Android 17 + Play 登录 + 游戏安装**；ARM64 supervisor 的属性投影经 getprop 与分区文件双读验证；`droidloom-composer`/presenter 在其上已部署。作者另在 `arch.md` 提到 ARM64 构建以 `fastpath1` 部署。
- **仍然缺**：aarch64 的**发布包**（pacman 包只在 x86_64 仓库）；aarch64 GApps 包有打包目标（`dist/droidloom-gapps-<ver>-1-aarch64.pkg.tar.zst`）但需本地供给 LiteGapps arm64 归档；**NVIDIA 未验证**（我们无关）。

### 3.4 ARM64 APK 在 x86_64 上跑（Teto/Digitalis-Berberis）

独立于宿主架构的一条支线：x86_64 产品编入开源 NativeBridge `Teto`（源自 Digitalis/AOSP Berberis）+ 客户库闭包，`native x86_64 优先，ARM64 JNI 走翻译，Java/服务/Mesa 保持原生`，代理直接调原生 EGL/GLES/Vulkan（**不装模拟器图形驱动**）。明确**不支持 ARM32 / RenderScript / 独立 ARM ELF**。`KNOWN_ISSUES.md` 记了一长串翻译缺陷（FP 舍入、ptrace BRK 语义、JNI FindClass 回调跨架构…），全部在外部 Digitalis checkout 里修，**不在本仓**。

---

## 4. 可搬资产清单（本文件的核心产出）

### 4.1 AOSP 共享内核适配补丁（`android/aosp-patches/`，19 条）

| 补丁 | 作用 | 对我们（redroid/Waydroid on 主线） |
|---|---|---|
| `0001-netbpfload-tolerate-shared-kernel-bpf-ids` | netbpfload 容忍宿主内核已占用的 BPF map/prog ID | **直接相关**：主线内核 + 多次 cell 重启时的 `netd` BPF 冲突 |
| `0003-connectivity-offline-rcu` | connectivity 离线态 RCU 处理 | 无 netd 后端或网络未就绪时避免死循环 |
| `0006-netd-cell-kernel-policy` | netd 的 cell 内核策略 | 容器网络隔离的可参考实现 |
| `0009-netd-bpf-pid-namespace` | netd BPF 的 PID 命名空间适配（BPF map 里的 pid 与宿主 pid 不同） | **直接相关**：PID ns 内 `SO_PEERCRED`/uid 映射类问题 |
| `0002-audio-default-only-service` | 只保留一个默认 audio service | 少一个 HAL 冲突点 |
| `0004-libmeminfo-offline-gpu-accounting` | 无 GPU 驱动时 libmeminfo 记账不崩 | 我们 GPU 未就绪的早期启动阶段 |
| `0005-frameworks-base-vendor-only-ext` | frameworks/base 只认 vendor 扩展 | 裁剪 system_ext 时的兼容 |
| `0008-vold-preserve-shared-storage-submounts` | vold 保留共享存储 submount | `/data/media` 直接映射宿主目录时的坑 |
| `0007-minigbm-amdgpu-platform` | minigbm amdgpu 平台 | x86 侧，我们不用 |
| `0010-minigbm-dma-heap-images` | 线性 dma-heap 图像分配 + import 校验 + YV12 pitch 对齐 128 | **可搬**：dma-heap + 线性 modifier 的可行性证明 |
| `0011-mesa-zink-kgsl` | `msm_drm` 匹配失败时，仅在具备外部 DMA-BUF/修饰符扩展时选无 DRM 身份的 Turnip | **关键参考**：KGSL（无 DRM 身份）与 drm 双栈并存时 Mesa 如何选设备 |
| `0012-mesa-adreno722` | 上游 Adreno 722 device entry | 我们 Adreno 830 已有上游条目，仅参考 |
| `0013-mesa-texture-upload-span` | 纹理上传只拷有效 span（避免 guard-page 越界，Skia 字形图集 + Zink render-pass） | **可搬**：Android HWUI 走 Zink 时的崩溃源 |
| `0014-mesa-background-cpu-placement` | 后台队列（Zink cache-put）在最低优先级入队后按 `MESA_BACKGROUND_CPUS[ET]` 挪核并降为 SCHED_BATCH | 后台编译/cache 抢占 UI 的通用对策 |
| `0015-libdrm-empty-version-strings` | 空驱动版本串保留为空串（Panthor 空 date → `strdup(NULL)` 崩） | **可搬**：任何「驱动 version/date 为空」的 SoC |
| `0016-mesa-turnip-hwui-queues` | Turnip VM_BIND 图形家族给两个队列（render+upload），HWUI Vulkan 管线必需 | **直接相关**：Adreno 上 HWUI 走 Vulkan 的硬需求 |
| `0017-build-hwui-vulkan-unset` | 构建期 unset HWUI Vulkan | 与 0016 配套的构建侧开关 |
| `0018-mesa-ir3-alias-array-sources` | NIR alias.tex 替换 collect 时保留数组下标（错读/崩溃） | 上游 bug，按需 cherry-pick |
| `binder-compat/0001..0003` | 无 Android SELinux LSM 时的 binder SID 回退（context manager 不提权、servicemanager 用 PID-context、普通服务合成 dev-cell 上下文） | **直接相关**：我们主线内核同样没有 Android SELinux LSM；这解释了 Waydroid 侧 SELinux 为何只能 permissive/跳过 |
| `apex-compat/0001-droidloom-classpath-projection` | APEX 的 classpath 投影 | 自建 Android 镜像时用 |
| `framework/0001..0007` | 底部导航 insets、路由式触控配置、启动解析、window policy、authoritative tasks、直连宿主通道、检测到的 Vulkan 能力 | 只有「Android 层直出 Wayland」这条路才需要，**不走这条路不必搬** |
| `audio/0001-host-buffered-playback` | 宿主缓冲播放 | 宿主侧音频输出替代 AudioFlinger HAL 时的参考 |

### 4.2 release 式构建属性投影（对 C3/Play Integrity 的意义）

`docs/KNOWN_ISSUES.md` 第一条原文要点：supervisor 在 **init 加载属性区之前**把各分区属性文件投影成 release 元数据——清 `ro.debuggable` 与 boot debug 标志、开 secure ADB 默认、把 `userdebug/eng/test-keys/dev-keys` 换成 `user`/release keys；Java `Build` 字段、`getprop`、直接读 `build.prop` 三处一致；`adb root` 随之失效（宿主管理与 system-service UID 保留）；不改镜像签名、不改 SELinux 强制、**不做硬件证明**，因此**不保证任何 app 或 Play Integrity 通过**。作者还明确记录：**Moto cell 上 Play 显示「未认证设备」**、**DRM/integrity 行为未测**。

**判读**：这与我们 C3 已取证的事实一致（`reports/c3-identity-drm-20261013.md`：build=test-keys/userdebug ⇒ PI device integrity 必失败；arm64 A13 无 Widevine L3）。droidloom 提供的**唯一新东西**是「在 init 之前统一投影属性、三处读取一致」的**做法**（可移植到 Waydroid 镜像的 property overlay），以及「Google 可选 add-on 可离线构建并登录 Play」的先例——**不构成 PI/Widevine 的新解法**。

### 4.3 架构思路（不一定搬，但值得记）

- per-task 逻辑 display + HWC3 私有 socket + 原始 layer 走 Wayland 子表面（跳过 SF 合成）：这是 Waydroid 目前最痛的「整块 Android 桌面塞进一个窗口」之外的**第三条路**（第一条 = Waydroid 单窗口，第二条 = redroid + 独立 VNC/串流）。
- 输入所有权显式化：`/dev/input` 空挂 + 宿主独占物理输入 + 只转发受控事件（避免 ueventd 重建 evdev 绕过焦点）。
- cgroup 现实教训（`arch.md` §CPU placement）：`CLONE_NEWCGROUP` **之后**再建 legacy hierarchy 会 `EPERM`；v2 memory 不能在命名空间根之下再委派；Android 的 `/dev/cpuctl`、`/dev/cpuset` 只是空 tmpfs 时需要 `cgroups.json` 描述替换。任何「在容器里给 Android 做调度策略」的方案都会撞这些。

---

## 5. 对本项目的裁决（G1/G2/G3）

| 对象 | 裁决 | 理由（一句话） |
|---|---|---|
| **droidloom 作 G2 第二容器路线** | ❌ 不进队列（Q3 维持「只跟踪」） | 需自建 aarch64 包 + 宿主合成器必须支持 `linux-drm-syncobj`（Phosh 不满足）+ 只在两个非本机型单元上验证过；R1（Waydroid）并未受阻 |
| **droidloom 的 AOSP/Mesa 补丁** | ✅ 参考清单，按需 cherry-pick | `0001/0009/0016`（bpfload、netd PID ns、Turnip HWUI 双队列）与我们热搜的失败模式直接对应 |
| **release 属性投影做法** | ✅ 可搬进 Waydroid 镜像的 property overlay | 是 PI 的**必要不充分**步骤；与我们 C3 取证结论一致 |
| **per-task Wayland 直出架构** | 🟡 记录，不施工 | 需要改 SurfaceFlinger + 框架 + 自研 Composer，工作量级 = 一个新的兼容层 |
| **Denial 作 G1 的 UI 层候选** | 🟡 候选（不施工） | mobile 模式 + 旋转锁 + 唤醒手势 + insets 有真机证据；但 GPU reset/缩放改动的会话级致命坑，且 direct scanout 未实现 |
| **Denial 的 insets/text-input 协议** | ✅ 若 G2 要「Android 应用与 Linux 窗口同桌面」则需关注 | 它是 droidloom 与 Denial 之间的**事实标准**（v2 已加 `get_keyboard_inset`） |
| **NativeBridge（ARM64 APK on x86_64）** | ⛔ 不用 | 与我们 G3（x86 游戏在 ARM 上跑）方向相反；且翻译层缺陷一大片 |

---

## 6. 若将来真要验证（判据，不含上机步骤）

1. **合成器前置**：宿主会话必须是 `wlroots ≥ 带 linux-drm-syncobj-v1` 或 Denial；先用 `wayland-info` 确认 `zwp_linux_dmabuf_v1` v4 feedback 与 `wp_linux_drm_syncobj_*`。
2. **内核前置**（我们的 vk 线基本已满足，需逐条确认）：`CONFIG_ANDROID_BINDERFS`、cgroup v2 可委派（memory/pids/freezer）、`drm_syncobj` eventfd 支持（内核 ≥ 6.x 主线）、PID/mount/net/cgroup 命名空间、**无 user namespace 也能跑**（dev cell 就不开）。
3. **构建**：aarch64 需 `-p droidloom-update --product droidloom_arm64` + rootless podman + pin 死的 AOSP 稀疏闭包（磁盘与时间成本要先估算）；产物是 pacman 格式，本仓 rootfs（Alpine）需转包。
4. **验收**：`droidloomctl start` 到 "Android is ready" → 装 APK → **原生窗口**出现（不是 Android 内部渲染）→ 剪贴板/通知 → 之后才谈 GMS/PI。

---

## 7. 未取证 / 风险

- 未上机、未构建、未验证任何性能数字（两仓的帧时/延迟数据都是作者在其硬件上的自述）。
- droidloom 的 aarch64 自构建**是否干净**未知（作者流水线只在 x86_64 runner + 其平板工作区跑过）。
- Denial 的 ARM64 源码构建要编自 pin 的 Flutter 引擎 fork，**构建体量与可复现性未评估**。
- 两仓都是「AI 协作开发」的快速迭代产物（作者自述），接口/配置 1.0 前会变；引用时**必须带 commit**，不要引 main 的浮动状态。
- 许可：原厂代码 GPL-3.0-or-later，AOSP 补丁随 AOSP（Apache-2.0），Mesa 补丁随 Mesa（MIT）；搬补丁要保留来源与 SPDX，**不要**整仓 vendor（体量 3 MB 代码 + 数十 GB 构建产物）。

---

## 8. 证据指针（上游路径 → 本文件小节）

| 内容 | 上游文件 |
|---|---|
| Denial 三层架构 / 输入 / mobile 模式 | `denial/docs/architecture.md`（§Input 段） |
| Denial 已知坑 | `denial/docs/KNOWN_ISSUES.md` |
| Denial mobile insets | `denial/docs/MOBILE_APP_INSETS.md` |
| Denial 旋转锁 | `denial/docs/ROTATION_LOCK.md` |
| Denial 手机端渲染优化（Moto Edge 70） | `denial/docs/MOBILE_RENDERING_OPTIMIZATION.md` |
| Denial 唤醒手势 / FOD | `denial/docs/hardware/WAKE_GESTURES.md`、`roadstr-*.json` |
| Denial direct scanout（未实现） | `denial/docs/direct_scanout.md` |
| Denial 路线/非目标 | `denial/ROADMAP.md` |
| droidloom cell 架构 / 图形路径 / cgroup 教训 | `droidloom/docs/architecture.md` |
| droidloom 运行时/挂载/命名空间契约 | `droidloom/docs/contracts/runtime-layout-v1.md` |
| droidloom 安全边界（无 Android SELinux LSM） | `droidloom/android/binder-compat/README.md`、`docs/threat-model-v2.md` |
| droidloom 兼容性与 PI/Widevine 现状 | `droidloom/docs/KNOWN_ISSUES.md` |
| droidloom ARM64 产品与图形后端 | `droidloom/android/device/README.md`、`android/mesa/README.md` |
| droidloom 共享内核补丁 | `droidloom/android/aosp-patches/0001..0018-*.patch`、`binder-compat/`、`apex-compat/` |
| droidloom 安装/构建 | `droidloom/docs/INSTALL.md`、`docs/BUILDING.md` |
