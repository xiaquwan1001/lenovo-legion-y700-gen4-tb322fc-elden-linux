# Waydroid / droidloom × 用户态层：硬依赖清单与解耦裁决（2026-10-26）

> 纯主机侧只读。设备不可达（`ssh 192.168.7.1` 超时）⇒ 零设备操作、零写盘。
> 承接：`TASKS/README.md` §2（C-历史、C1–C11）、§5 Q3、§6、§0 的 R1/R1'/R3 表；
> `RESOURCES/sessions/2026-10-26-denial-droidloom深度评估.md`（droidloom/Denial 深读，上游 commit `ffccef6`/`c96375a`）；
> `packaging/elden-userland/{services.tsv,sources.tsv,MANIFEST.tsv,provides.tsv}`（用户态语义真源）；
> `PITFALLS/sessions/24-Waydroid容器.md`（#189/#190/#191）、`reports/{research-waydroid-sensors-hal,waydroid-sensors-next,waydroid-camera-provider-rootcause,waydroid-haptics,container-audio}-*.md`。
> **本报告只做「接口归属」判断，不启动任何抽象层实现。**

---

## 0. 结论（先看这里）

1. **Waydroid 对用户态层的硬依赖共 14 条**（§1 表），其中 **只有 6 条是"我们自己的代码"**（`services.tsv` 里的 `ours`），
   **其余 8 条是 Waydroid 包/镜像内部行为**（LXC 配置、`config_nodes`、`waydroid_base.prop`、vendor.img 里的 HAL）。
2. **droidloom 若替换 Waydroid，改变的接口共 7 类**（§2），其中 **4 类是我们**必须现在就想清楚的，**3 类只影响 Waydroid 自己的实现**。
3. **本轮「用户态去 Alpine 化」应当抽象的只有 3 个点**（§3 表标「是」）：
   **①容器后端（container backend）②传感器数据源 ③触觉桥**。
   其余一律**不抽象**（过度设计风险 > 收益），理由逐条给在 §3。
4. **关键判据**：**droidloom 不满足"现在就要支持"的门槛**——它要求宿主合成器支持
   `linux-drm-syncobj`（Phosh/Mutter **不支持**），且 aarch64 **无发布包**、只在 OnePlus Pad 4/Moto Edge 70 上验证过。
   ⇒ **本次迁移不为 droidloom 做任何前瞻性重构**（`TASKS/README.md` §5 Q3 已达成的裁决，本报告只做接口级落实）。

---

## 1. Waydroid 当前对用户态层的硬依赖（逐条带证据）

| # | 接口/依赖点 | Waydroid 当前实现 | 证据（文件:行 / 行名） |
|---|---|---|---|
| **D1** | **容器管理器进程** | `waydroid container start`，由 **lxc** 承载；崩了要有 respawn | `packaging/elden-userland/services.tsv:43` `waydroid-container`（`init=package`, `exec=/usr/bin/waydroid`, `args=container start`, `need=lxc`, `after=lxc`, `respawn=5`） |
| **D2** | **会话进程**（Wayland 客户端） | `waydroid session start`，必须继承**真实桌面会话**的 `WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR`/DBus | `files/usr/local/sbin/waydroid-session.sh`（`XDG_RUNTIME_DIR=/run/phosh`、`WAYLAND_DISPLAY=wayland-0`、`exec waydroid session start`）；全 UI 版 `waydroid-ui.sh`（`waydroid show-full-ui`） |
| **D3** | **netd / 策略路由**（内核能力） | 容器内 Android netd 需 `ip rule` + 多路由表；由内核 `CONFIG_IP_ADVANCED_ROUTER`/`IP_MULTIPLE_TABLES`/`IPV6_MULTIPLE_TABLES` 支撑，**不用任何 userspace workaround** | `TASKS/README.md` §2 C1（vk103/vk126-c1 实测：`table 1002` 自建 `default`、`curl baidu=200`）；`PITFALLS #184/#194` |
| **D4** | **IPv6 双栈（宿主侧额外服务）** | 宿主建 `waydroid0` 桥、`fd00:240::1/64` ULA、`ip6tables` MASQUERADE + FORWARD，并把默认路由写进容器 `eth0`/`eth0_local` 两张表 | `files/usr/local/sbin/waydroid-ipv6`（`BRIDGE=waydroid0`、`PREFIX=fd00:240`、`IP6T=ip6tables-legacy`）；`services.tsv:38` `waydroid-ipv6`（`need=waydroid-container`, `after=waydroid-container networkmanager`） |
| **D5** | **binderfs / binder 设备** | 容器用宿主内核的 binder，`CONFIG_ANDROID_BINDERFS=y` + `ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"` | `build/vk151/.config` 与 `build/m1-73/.config` 实测三行命中（本报告 §5 复现命令） |
| **D6** | **LXC 挂载项（`lxc.mount.entry`）** | 宿主把目录/设备 bind 进容器，逐条累积在 `/var/lib/waydroid/lxc/waydroid/config` | `scripts/waydroid-haptics-setup.sh:52,54`（`/run/elden-haptic` 与 `/run/elden-haptic/leds → sys/class/leds`） |
| **D7** | **`config_nodes`（设备节点 bind 清单）** | Waydroid 生成的「容器要挂哪些 `/dev/*`」列表；**漏一条 = 功能静默消失** | `/dev/video100` 相机（`TASKS/sessions/2026-10-23-收尾轮次-Q29背光下限容器相机.md`：根因 = bind **从未进持久 `config_nodes`**）；`/dev/fuse`（`PITFALLS #191`）；`/dev/dma_heap`（`PITFALLS #189` 层④） |
| **D8** | **传感器 relay（宿主 gbinder 注入 daemon）** | 我们自写 `waydroid-sensord`（HIDL `android.hardware.sensors@1.0`），由 Waydroid `container_manager.py` 自动以 `/dev/hwbinder` 拉起；数据源 = `ssc-udp-relay.py` 经 UDP 喂入 | `services.tsv:36` `ssc-udp-relay`（`exec=/usr/bin/python3 /usr/local/bin/ssc-udp-relay.py`, `after=dbus`）；`sources.tsv` 两行（`waydroid-sensord`/`-udp`，`status=ok`，glibc 产物 `out/sensord-host/`）；`TASKS/README.md` §2 C4 |
| **D9** | **传感器后端前提（不是 Waydroid 的，是我们的）** | `hexagonrpcd` attach sensorspd（QRTR svc 400）+ `iio-sensor-proxy`（SSC 后端）；`/sys/bus/iio` **恒空** | `services.tsv:42` `hexagonrpcd-adsp-sensorspd`（`init=package`，语义已按 J3 改为由 `hexagonrpcd.service` drop-in 承担）；`services.tsv:31` `iio-sensor-proxy`（`after=hexagonrpcd-adsp-sensorspd`）；`reports/modular-mobian-transition-20261026.md` §4 |
| **D10** | **相机 provider（容器内 HAL）** | 自编 `camera-provider-2-4-ext`（64 位指针/dev_t 修复），输入 = 宿主 `v4l2loopback` 的 `/dev/video100` | `patches/waydroid-camera-64bit-20261018/`（7 文件）；`scripts/cam-loopback.sh`（`LOOP=/dev/video100`）；`reports/waydroid-camera-provider-rootcause-20261019.md` |
| **D11** | **触觉桥（宿主 daemon + 一条 bind）** | 容器内 HAL 写 `leds`/`timed_output`（主线都没有）⇒ 宿主 `elden-hapticd` 轮询 `/run/elden-haptic/leds/vibrator` 转 `aw86927` `FF_RUMBLE`；容器 `/sys/class/leds` 被 bind 覆盖 | `services.tsv:27` `elden-hapticd`（`after=localmount`, `before=waydroid-container`, `HAPTIC_ARGS=--amp-a 0xffff --amp-b 0xffff`）；`hooks/elden-hapticd.pre`（amplitude **必须 255**）；`scripts/waydroid-haptics-setup.sh:52,54`；`patches-userland/waydroid-haptics-aidl/` |
| **D12** | **显示/窗口** | `waydroid show-full-ui` 把整个 Android 界面塞进**一个** Phosh 窗口；合成由**容器内 SurfaceFlinger + 宿主 Mesa/freedreno** 完成 | `files/usr/local/sbin/waydroid-ui.sh`；`TASKS/README.md` §2 C-历史（Mesa 26.1.8 解 A830）/ §5 Q29 |
| **D13** | **音频** | 容器 `AudioTrack → HAL → ALSA pulse plugin → 宿主 PipeWire`；需 4 条修（manifest 去 `media.omx`、`debug.stagefright.ccodec=4`、C2 codec XML、`/dev/dma_heap`） | `PITFALLS/sessions/24-Waydroid容器.md` #189（四层）；`reports/container-audio-20261011.md`；宿主 `/etc/modules` 需 `system_heap`（**不要** `cma_heap`，`PITFALLS #130`） |
| **D14** | **抽象存储 / emulated storage** | 需 `/dev/fuse` + `fuse` 模块；容器 `config_nodes` 必须在 `/dev/fuse` 存在**之后**生成 | `PITFALLS #191`（`emulated;0 mounted`） |

**分类小结**：`ours`（我们自己的代码/服务）= **D4、D8、D11（宿主侧）+ D9、D2/D10 的脚本层**；
`package/镜像内部` = D1、D5（内核）、D6、D7、D12、D13、D14；**内核能力** = D3、D5。

---

## 2. droidloom 若替换 Waydroid：改变的接口（7 类）

| # | 接口 | Waydroid 现状 | droidloom 要求 | 变化性质 |
|---|---|---|---|---|
| **X1** | **合成器前置（最硬的门槛）** | 无要求：`show-full-ui` 只要一个普通 `xdg_toplevel`，Phosh/Mutter 直接满足 | presenter 要求 `xdg-shell` + **`linux-dmabuf` v4 feedback** + **`linux-drm-syncobj`**；用它自己的私有协议（`droidloom-denial-protocol`） | **宿主合成器必须换**（Phosh 不满足；只有 Denial 或带 `linux-drm-syncobj-v1` 的 wlroots 系）。⇒ **这是"要不要动 G1 桌面栈"的决策，不是容器层的决策** |
| **X2** | **binder SID / SELinux** | 容器内 Android 有**自己一套** SELinux 策略（`/vendor/etc/selinux`），宿主内核**没有** Android LSM；Waydroid 靠 permissive/跳过 | 宿主内核同样没有 Android SELinux LSM ⇒ 用 3 个补丁在 `DROIDLOOM_CELL` 存在时走 **PID-context 回退**；作者明写「**开发 cell 以宿主沙箱为安全边界**，内核对+策略就位前**不得声称 Android SELinux 隔离**」 | **语义降级**：安全边界从「Android SELinux 策略」变成「宿主沙箱」。**对我们 G2 的 PI/Widevine 目标是负面**（社区惯例依赖 build 属性/策略一致性） |
| **X3** | **窗口模型** | 1 个 Android 桌面 = 1 个窗口；应用窗口在 Android 内部 | **每个 task 一个宿主 `xdg_toplevel`**（per-task 逻辑 display + HWC3 私有 socket，**跳过 SurfaceFlinger 的 GPU 合成**，原始 layer 当同步 Wayland 子表面交给宿主） | **产品级变化**：从"一个 Android 窗口"变成"Android 应用与 Linux 窗口同桌面"。这也正是 Denial 的 insets 协议 v2（`get_keyboard_inset`）存在的原因 |
| **X4** | **私有 binderfs / 空 `/dev/input`** | 宿主 binder 全量暴露（`binder,hwbinder,vndbinder`）；`/dev/input` 由 LXC 视需要 bind | **私有 binderfs，只建三个设备**；**`/dev/input` 是空私有 tmpfs**（宿主独占物理输入，防 `ueventd` 重建 evdev 绕过 Wayland 焦点） | **输入所有权显式化**。我们的**触觉桥 D11** 与**传感器 D8** 都靠「往容器里 bind 东西」⇒ **这两条在 droidloom 下无处可挂**（见 §3 抽象点） |
| **X5** | **属性投影（对 Play Integrity 的意义）** | Waydroid 镜像的 `waydroid_base.prop` + OTA 镜像里的 build 属性；**`test-keys`/`userdebug` 直出** ⇒ PI device integrity 必失败（C3 已取证） | supervisor 在 **init 加载属性区之前**把分区属性文件投影成 release 元数据：清 `ro.debuggable`、开 secure ADB、`userdebug/eng/test-keys` → `user`/release keys；**Java `Build`/`getprop`/直接读 `build.prop` 三处一致**；`adb root` 失效 | **新增一条我们对 PI 唯一可复用的做法**（但作者明确：**不改镜像签名、不做硬件证明、不保证 PI 通过**；Moto cell 上 Play 仍显示"未认证设备"）。⇒ **必要不充分**，与 C3 现有结论一致 |
| **X6** | **图形后端选择** | 只有一条路：容器内 SurfaceFlinger + 宿主 freedreno/Mesa | **三选一**（`graphics_backend`）：`drm`（原生 Freedreno/Turnip）/ `kgsl_dma_heap`（显示 DRM + GPU KGSL 分裂宿主）/ `drm_dma_heap`（只暴露 `/dev/dma_heap/system`） | **多了一个"我们没有的选项"**：我们的 GPU 是 freedreno DRM 路径 ⇒ `drm` 就够；`kgsl_dma_heap` **对本机无用**（我们不跑 KGSL），不构成动机 |
| **X7** | **音频** | 容器 HAL → 宿主 ALSA pulse → PipeWire（4 层修补） | 宿主侧 buffered playback 客户端 + **APEX 化 audio service**；**通话/基带明确 non-goal** | 接口形态不同（宿主侧服务 vs 容器 HAL），但**我们已修好的 4 层在 droidloom 下不适用** ⇒ 属"不做就不需要迁移"的资产 |

---

## 3. 用户态解耦清单（核心产出）

> 判据：**「现在是否必须抽象」= ① 是否已有 ≥2 个真实候选实现（不是假想）② 抽象成本是否 < 一次性重写成本 ③ 是否阻塞本次迁移（`linux17`/S6/S7）**。
> 三条全不满足 ⇒ **不抽象**（写清理由，避免"为未来设计"变成负资产）。

| # | 接口/抽象点 | 现在 Waydroid 的实现 | droidloom 的要求 | 现在是否必须抽象 | 理由 | 落到哪个文件 |
|---|---|---|---|---|---|---|
| **A1** | **容器后端（container backend）** | `waydroid container start`（`services.tsv:43`，`init=package`） | cells 由 `droidloomctl start` 起（supervisor + pidfd + 宿主 cgroup） | **是** | 这是**唯一**有第二个真实候选（redroid 已在 §0 R1' 表里作为备胎，且 `TASKS §6` 的架构图已画 `R1 ∪ R1'` 两条 lane）。抽象成本低：**把"起/停/状态"收敛成一个 3 动词 CLI + 一个 `services.tsv` 行**，不必抽象内部（LXC vs podman vs cell 的差异留在后端脚本里） | `packaging/elden-userland/services.tsv`（新增 `droid-backend` 语义行）+ 新 `files/usr/local/sbin/eldroid-backend`（3 动词：`start/stop/status`）；**`waydroid-ipv6` 与 `elden-hapticd` 的 `before/after` 改为依赖抽象名而非 `waydroid-container`** |
| **A2** | **传感器数据源（sensor source）** | `ssc-udp-relay.py`（ssccli→UDP）+ `waydroid-sensord`（UDP→HIDL） | droidloom **不需要** HIDL HAL：Android 直接跑在宿主内核上，传感器应走**宿主 IIO/`iio-sensor-proxy`**（或 droidloom 自己的属性/服务）。⇒ **UDP 协议这一层在 droidloom 下是死路** | **是**（但只抽**数据源**，不抽传输） | 现在已**实际换过一次数据源**（`eldroid-sensord --fake` / Termux 转发 / `ssccli` 三源，`TASKS §6` ①）。抽象点 = **"一个把传感器值推给消费者的进程"**，协议留 UDP（已有 HAL 只认 UDP）；**不要**抽成通用 IPC 框架 | `files/usr/local/bin/ssc-udp-relay.py`（加 `--format=udp|json` 输出选择，~20 行）；`packaging/elden-userland/sources.tsv` 已有两行可直接复用 |
| **A3** | **触觉桥（haptics bridge）** | 宿主 `elden-hapticd` 轮询 `/run/elden-haptic/leds/vibrator` + **一条 `sys/class/leds` bind**（`scripts/waydroid-haptics-setup.sh:54`） | droidloom 的容器**没有 `sys/class/leds` 可 bind**（`/sys` 是最小只读投影）、`/dev/input` 也是空 tmpfs ⇒ **桥的挂载面消失** | **是**（抽象"桥的暴露方式"，不抽象 daemon） | 桥的**语义**（`activate/duration/amplitude` 三文件）是我们自己的稳定 ABI；只是"如何让容器看见"会变（bind → 私有协议/Unix socket）。抽象成本极低：把 daemon 的**输入**从"文件轮询"改成"也接受 Unix socket 行协议"（~30 行），文件轮询保留 | `scripts/elden-hapticd.c`（新增 socket 输入，保留文件输入）；`hooks/elden-hapticd.pre` 不变（amplitude=255 语义不变）；`scripts/waydroid-haptics-setup.sh` 只改"挂载"段 |
| **A4** | 相机 provider | `camera-provider-2-4-ext`（容器内 HAL）+ `/dev/video100` loopback | droidloom 用 AOSP 原生 camera HAL，输入仍是宿主 V4L2 ⇒ **接口形态相同**（都是 V4L2 设备） | **否** | ① 无第二个真实候选（droidloom 尚未可用）；② 我们的 HAL 修补是**四层真缺陷**（IBinder 虚函数、WEAK 符号、hidl manager、`dev_t` 尺寸，`PITFALLS #344–#352`），抽象它 = 把已修好的东西重写；③ `/dev/video100` 这条接口**本身已经是抽象**（V4L2） | —（保持现状；仅把 `/dev/video100` 的 bind 从"写进 `config_nodes`"提升为"由 A1 后端负责注入"，属 A1 的副作用） |
| **A5** | 音频（4 层修补） | `media.omx` 移除 / `ccodec=4` / C2 codec XML / `/dev/dma_heap` | droidloom 走宿主 buffered playback + APEX audio service | **否** | 这 4 条**全部是 Waydroid 镜像内部缺陷的补丁**，不是我们的接口；在 droidloom 下天然不存在 ⇒ 抽象它们等于为"已废弃实现"做兼容层 | — |
| **A6** | 网络（`waydroid0` 桥 / ULA / NAT66） | `waydroid-ipv6`（`services.tsv:38`） | droidloom 用 **network namespace**，宿主不需要桥；`netd` 的 BPF/PID-ns 适配由 droidloom 补丁解决（`0001/0009`） | **否**（但**依赖方向**要改） | 抽象"网络后端"收益低：droidloom 若是网络 ns，`waydroid-ipv6` 整段无意义。**该做的只有一件事**：把 `waydroid-ipv6` 的 `need=waydroid-container` 改成依赖 **A1 的抽象名**，这样切后端时它会被自动跳过 | `packaging/elden-userland/services.tsv:38`（改 `need/after`） |
| **A7** | 显示/窗口 | `show-full-ui`（单窗口） | per-task `xdg_toplevel` + 合成器须支持 `linux-drm-syncobj` | **否** | 这是**桌面栈选型**（Denial vs Phosh），不是"用户态去 Alpine 化"的范围；且属于 `TASKS/README.md` §5 Q3「只跟踪」 | — |
| **A8** | 属性投影（PI） | 无（`test-keys`/`userdebug` 直出） | init 前统一投影 + 三处一致 | **否（现在做）= 是（可作为独立小改进）** | 它**不依赖** droidloom：可作为 Waydroid 镜像的 property overlay 单独落地（与 C3 现有结论一致：必要不充分）。**但本轮迁移不该做**（会往 `linux17` 首启验收里塞一个新变量） | 未来：`packages/…/property-overlay`（不存在）；**本轮不落文件** |
| **A9** | binderfs / `/dev/input` 所有权 | 宿主 binder 全量 + 按需 bind `/dev/input` | 私有 binderfs（3 设备）+ 空 `/dev/input` | **否** | 内核能力（`CONFIG_ANDROID_BINDERFS=y`）**两条路线共用**；差异只在"容器内怎么挂"，属 A1 后端的内部实现。现在抽象 = 猜 droidloom 的挂载细节（其契约仍在 0.x/日更） | — |
| **A10** | LXC `config_nodes` / `lxc.mount.entry` | 逐条累积在 `/var/lib/waydroid/lxc/waydroid/config`，**漏一条功能静默消失**（已两次中招：`/dev/video100`、`/dev/fuse`） | 不存在（无 LXC） | **否（不做通用抽象）**，但**必须加一条自检** | 抽象挂载清单 = 为 Waydroid 的内部格式做二次封装，收益低；**真问题是"漏项不可观测"**。⇒ 只要给 `verify.sh` 加一条**断言**：「容器内存在这些节点」清单化，**不做通用挂载管理器** | `packaging/elden-userland/tools/verify.sh`（新增一段"容器设备节点存在性"检查清单；**不新增抽象层**） |

**小结：必须抽象 = A1 / A2 / A3（3 条）；必须改依赖方向但不抽象 = A6；必须加自检但不抽象 = A10；明确不抽象 = A4/A5/A7/A9；暂不做 = A8。**

---

## 4. 回答用户的两个问题

### 4.1 本次「用户态去 Alpine 化」应当把哪些 Waydroid 专属的东西做成可插拔后端？

**只有 3 个**（且都是"薄壳"级，不是框架）：

1. **容器后端**（A1）：把 `waydroid container start/stop/status` 收敛成 `eldroid-backend <verb>`，
   `services.tsv` 里只留一行抽象语义。这样 **redroid / droidloom 切换 = 换后端脚本**，不动 unit 名与依赖图。
2. **传感器数据源**（A2）：`ssc-udp-relay` 的输出格式增加一个选项，使"数据源"与"消费者传输"解耦。
   注意**只抽源，不抽传输**——UDP 已有 HAL 消费方（`out/sensord-host/`），换协议等于重写 HAL。
3. **触觉桥的暴露方式**（A3）：`elden-hapticd` 的输入增加 Unix socket 通道，与现有文件轮询并存。
   语义（`activate/duration/state/amplitude`，amplitude 默认 255）**保持不变**——这是稳定 ABI。

**共同特征**：三条都是「**同一语义、第二种承载方式**」，都已经**真实存在第二种候选**（redroid / 传感器三源 / droidloom 无 bind 面），
且都**不需要**引入框架、插件注册表、配置文件 DSL。

### 4.2 哪些不要过度设计？

| 不要做 | 为什么（一句） |
|---|---|
| 通用"Android 兼容层驱动框架"（backend plugin API / 抽象基类） | 只有 2 个候选、其中 1 个（droidloom）**现在不可用且接口日更**（作者自述 0.x，46 KB KNOWN_ISSUES）⇒ 抽象会照着"猜的未来"写 |
| 抽象 camera provider / 音频四层修补 | 它们是**已修好的具体缺陷**（`PITFALLS #344–#352`、#189），不是接口；抽象 = 为废弃实现做兼容层 |
| 抽象 binderfs/`/dev/input` 挂载策略 | 内核能力两条路线共用；挂载细节属后端内部，现在抽 = 猜 droidloom 契约 |
| 抽象显示/窗口（per-task toplevel） | 属**桌面栈选型**（Denial vs Phosh），与"去 Alpine 化"正交；且 Denial 有 GPU reset / 缩放改动的会话级致命坑 |
| 现在就做属性投影（PI） | 与 droidloom 无关，可作为**独立小改进**；塞进本轮迁移会让 `linux17` 首启多一个变量 |
| 通用"挂载管理器" | 真问题是"漏项不可观测"，用 `verify.sh` 一条断言解决，不是造框架 |

---

## 5. 复现命令（只读）

```bash
# D5：内核 binder 能力（两条路线共用）
grep -E "CONFIG_(ANDROID_BINDERFS|ANDROID_BINDER_IPC|CGROUP_BPF|SYNC_FILE|USER_NS|PID_NS|NET_NS)" build/vk151/.config

# D1/D4/D8/D9/D11：服务语义真源（20 行，Waydroid 相关 5 行）
grep -n "waydroid\|haptic\|ssc-udp\|hexagonrpcd\|iio-sensor" packaging/elden-userland/services.tsv

# D6/D11：LXC 挂载项（触觉桥两条）
grep -n "lxc.mount.entry" scripts/waydroid-haptics-setup.sh

# D2：会话环境（继承桌面 Wayland/DBus）
cat packaging/elden-userland/files/usr/local/sbin/waydroid-session.sh

# D10：相机 loopback 节点与互斥约束
grep -n "^LOOP=\|互斥" scripts/cam-loopback.sh

# D8：传感器两条 ELF 的可重建来源
grep -n "waydroid-sensord" packaging/elden-userland/sources.tsv packaging/elden-userland/MANIFEST.tsv

# 判据：droidloom 的合成器前置（需人工读上游）
#   https://github.com/denialwm/droidloom  → docs/architecture.md, docs/contracts/runtime-layout-v1.md
#   本仓已做过深读：RESOURCES/sessions/2026-10-26-denial-droidloom深度评估.md §3.2
```

---

## 6. 未解 / 未证实（不编）

| # | 项 | 状态 |
|---|---|---|
| 1 | droidloom aarch64 自构建是否干净 | **未验证**（作者流水线只在 x86_64 runner + 其平板工作区跑过） |
| 2 | droidloom 在 **Adreno 830 + freedreno DRM** 上的实测表现 | **未验证**（作者真机是 OnePlus Pad 4 / Moto Edge 70，非本 SoC 同档验证） |
| 3 | 我们的 `camera-provider-2-4-ext` 在 droidloom 下是否可复用 | **未验证**（理论上都是 V4L2 输入，但其 camera HAL 走 AOSP 原生路径） |
| 4 | `elden-hapticd` 的 socket 输入是否属"必要" | **未证实**：只在 droidloom 真正可用后才需要；本报告判定"抽象成本 ~30 行 < 将来重写"，故列为"是"，但**不排期** |
| 5 | Waydroid 在 **Debian/sid 1.6.3** 上的行为差异（`mount_overlays`/`stub_sensors_hal`/`config_nodes`） | **未证实**（`reports/mobian-migration-plan-20261021.md` §6 U4，主机侧可做，本轮未做） |
| 6 | `services.tsv` 的 `hexagonrpcd-adsp-sensorspd` 行语义是否已按 J3 改写 | **需现查**（`reports/modular-mobian-transition-20261026.md` §4 说「语义要改写」，本轮只读未改，`services.tsv:42` 仍写 `init=package, exec=/usr/bin/hexagonrpcd-adsp-sensorspd`） |

---

## 7. 边界

- 未执行任何 `ssh`/`adb`/`fastboot`；**设备未触碰**。
- 未改 `packaging/elden-userland/**` 任何文件（**本报告只给"落到哪个文件"的建议，未落改动**）。
- 未改 `TASKS/README.md`、`DEVICE/README.md`、`INDEX.md`、`RESOURCES/README.md`、`PITFALLS/README.md`、`versions/`。
- 未 commit、未 `git add`；未发任何邮件、未访问上游网络。
