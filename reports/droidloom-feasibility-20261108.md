# droidloom 可行性复核（2026-11-08）——在线增量 + 四门槛判定

> 性质：**只读复核**（`gh api` / HTTP 只读 / 本机文件静态读）。本轮**零**设备动作、零装包、零构建、零桌面改动。
> 基线（不重推）：`reports/droidloom-feasibility-plan-20261030.md`（〔可研〕）、
> `reports/droidloom-build-device-plan-20261030.md`（〔构建机〕，2026-10-31，含设备只读实测）、
> `RESOURCES/sessions/2026-10-26-denial-droidloom深度评估.md`（〔深读〕）、
> `reports/waydroid-droidloom-userland-interface-20261026.md`（〔接口〕）、`TASKS/README.md` §5 Q3 / §6 R3。
> 证据标签：**实测**（本轮命令输出/在线 API 原文）/ **静态**（读源码、配置、包内文件）/ **推断**（未取证的合理外推）。
> 在线查询日期一律 **2026-11-08**（UTC）。

---

## 0. 结论（一页）

**判断 = 只跟踪（本轮不立项）**。一句话理由：**上游把"aarch64 无发布包"这条主要缺口补上了（修订 27 起，2026-10-31），
但 droidloom 对 G2 硬验收（Play Integrity / Widevine + 相机/传感器/触觉）仍无净增益，且落地上还压着三件具体事：
合成器一行 global、内核 `nf_tables` 一档配置、pacman 包到本机 rootfs 的装法。**

三个二值判断：

| # | 二值问题 | 判定 | 证据级别 |
|---|---|---|---|
| **J1** | **aarch64 宿主是否已有官方发布产物（本轮是否仍需自构建）** | **是（旧结论已翻转）**：`droidloom-image/runtime` 自修订 **27** 起有 **aarch64** 包，最新 **0.1.0-30**（2026-11-05）；`docs/INSTALL.md` 首段已写 *"…x86_64 Arch Linux and **aarch64 Arch Linux ARM** … Prebuilt packages for both"*；`docs/BUILDING.md` 有 `--architecture aarch64 --sysroot …` 交叉编流程 | **实测**（release 资产逐项 + 包内 `.PKGINFO` `arch = aarch64` + ELF `ARM aarch64`） |
| **J2** | **现役合成器（phoc 0.58.0）是否满足 presenter 的 `linux-drm-syncobj` 硬需求** | **否**（仍未满足；但缺口缩到**一行调用**）：phoc 0.58.0 源码**没有任何** `wlr_linux_drm_syncobj_manager_v1_create()` 调用；内嵌 wlroots 0.20.x 已含完整实现（含 eventfd 检查）；设备 2026-10-31 实测 registry 56 个全局里 `grep -c syncobj = 0` | **静态**（Debian sid `phoc_0.58.0.orig.tar.xz` 全树 grep）+ **实测**（〔构建机〕§4.1 registry 探针） |
| **J3** | **droidloom 是否仍是"namespace cell 而非 VM"** | **是**（全树 0 命中 kvm/qemu/virtio；本地 source 树与在线 code search 双向核对） | **静态**（本地 `build/droidloom/droidloom/` 8.1 MiB 全树 grep + `search/code` 三项均 0） |

分数化（沿用 §6 五维，droidloom 单独打分，见 §1.2）：**可用性 1/5、图形 2/5、输入 2/5、音频 3/5、身份/完整性 0/5**。

---

## 1. 四门槛判定表

### 1.1 主表

| # | 门槛 | 判定 | 一句话依据（级别） | 卡在哪一层 |
|---|---|---|---|---|
| **M1** | **上游交付形态**：aarch64 包 / 镜像 | **过（2026-10-31 起）** | 修订 27/28/29/30 各含 `image`+`runtime` 的 aarch64 包；`image-30-aarch64` = **964 196 458 B（0.90 GiB）**、`runtime-30-aarch64` = **6 598 150 B**（实测，`gh api releases`）。`android/device/droidloom_arm64/` 仍在（19 个条目，含 `droidloom_arm64.mk`/`audio-apex`/`droidloom-composer.rc`） | — |
| **M2** | **合成器**：`xdg-shell` + `linux-dmabuf` v4 feedback + `linux-drm-syncobj` | **部分过（1/3 缺）** | phoc 0.58.0：`xdg_wm_base v6` ✓、`zwp_linux_dmabuf_v1 **v5**`（`#define PHOC_LINUX_DMABUF_VERSION 5`，v4 feedback 语义 ⊂ v5）✓、**`wp_linux_drm_syncobj_manager_v1` 缺** ✗（静态：全树无 create 调用；实测：registry 0 命中） | **合成器层**（phoc 一行；或换 sway ≥1.12 / Denial） |
| **M3** | **内核前置**（binder/memfd/bpf/命名空间/syncobj/dma-heap/nftables） | **过 6 项 / 缺 1 组** | 现役 `build/daily/.config`（7.3.0-rc7）：`ANDROID_BINDERFS=y`、`ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`、`MEMFD_CREATE=y`、`USER_NS/PID_NS/NET_NS/UTS_NS/IPC_NS=y`、`BPF_SYSCALL=y`、`CGROUP_BPF=y`、`PSI=y`、`MEMCG=y`、`CGROUP_PIDS/FREEZER=y`、`SECCOMP_FILTER=y`、`DMABUF_HEAPS=y`+`SYSTEM=m`、`EROFS_FS=y`、`EXT4_FS=y`、`BLK_DEV_LOOP=y`、`FUSE_FS=m`、**syncobj 由 `DRM` 无条件编入**（`drivers/gpu/drm/Makefile:69`，无 Kconfig 开关）+ uapi 有 `DRM_IOCTL_SYNCOBJ_EVENTFD`；**缺：`# CONFIG_NF_TABLES is not set`**（连带 `NFT_CT/NFT_NAT/NF_TABLES_INET` 全无），而 cell 网络强制 `nft -f -` 建 `inet` filter + `ip` nat 表（`runtime/droidloom-supervisor/src/development_network.rs:152–186`，失败即 `start_development_cell` 直接 Err） | **我们**（内核配置一档 + 重编/刷写） |
| **M4** | **身份/完整性**：GMS / Play Integrity / Widevine | **未过（且无净增益）** | `docs/threat-model-v2.md:116–120` 原文未变：*"Android SELinux cannot install a private policy … **Protected media, hardware attestation, and Play Integrity are not supported claims**."*；`docs/KNOWN_ISSUES.md:232` 仍记 Moto cell *"Play reports an uncertified device"*；属性投影（清 `ro.debuggable`/`test-keys`→release）是**必要不充分**（〔接口〕X5 已裁决） | **上游明确免责**；与 C3 结论同向 |

### 1.2 五维打分（droidloom 形态，非 Waydroid 现状）

| 维 | 分 | 依据（级别） |
|---|---|---|
| 可用性 | **1/5** | 能开 Settings/单 APK（上游截图与 KNOWN_ISSUES 记述）；但**相机/传感器/触觉 broker 不存在**（`android/hardware/README.md` 2026-11-08 原文仍为 *"Dedicated sensor, vibrator and camera brokers are not established preview features"*），G2 的 U3/U4/U7 无落点（实测原文） |
| 图形 | **2/5** | 宿主侧接口齐（freedreno DRM + dma-heap + Mesa 26.2.5 在机）；`docs/INSTALL.md` 已把 **aarch64 原生 Adreno（`msm`）** 列为一等后端，提交 `130a211` *"Package setup takes a Qualcomm Adreno as a native GPU"*（2026-11-05）；**但**本机型/本内核上无任何实测，且 Phosh 侧 syncobj 缺（静态） |
| 输入 | **2/5** | 输入由宿主独占并注入（`/dev/input` 空 tmpfs），窗口级焦点可用；**中文输入法不可平移**（phoc text-input 验收作废），触屏语义另立（静态） |
| 音频 | **3/5** | 宿主 PipeWire broker 已实现、x86_64 播放验证过；录音上游自述 *"remain required"*；我们 Waydroid 4 层音频补丁作废（静态+上游自述） |
| 身份/完整性 | **0/5** | 见 M4（上游原文） |

---

## 2. 在线证据（查询日 2026-11-08，含 URL）

### 2.1 `denialwm/droidloom`（上游快照）

| 项 | 值 | 命令 / URL |
|---|---|---|
| HEAD | `a4fd422` *"Package release 30"* 2026-11-05T11:44Z | `gh api repos/denialwm/droidloom/commits` |
| 规模/活跃 | 452★ / 16 fork / 13 open issues / 4.8 MB；`pushed_at` 2026-11-05T11:44Z | `gh api repos/denialwm/droidloom` |
| release | 唯一 tag `packages`，**41 个资产**，`updated_at` 2026-11-05T11:51Z | `https://api.github.com/repos/denialwm/droidloom/releases` |
| aarch64 资产（逐项） | `image-27-aarch64` 964 192 463 B（10-31T19:01Z，4 次下载）；`-28` 964 192 278 B（11-01）；`-29` 964 196 509 B（11-05T11:43Z）；`-30` 964 196 458 B（11-05T11:51Z，15 次）；`runtime-27…30` 6.1–6.6 MB | 同上，`jq '.assets[]|select(.name|test("aarch64"))'` |
| 包内容（实测解包） | runtime 内含 `usr/bin/{droidloom-wayland,droidloomd,droidloomctl,droidloom-supervisor,droidloom-audio,droidloom-applications,droidloom-doctor}` + `usr/lib/systemd/{system,user}/*.service`；`.PKGINFO`：`arch = aarch64`，`depend = droidloom-image=0.1.0-30 glibc gcc-libs mesa libdrm wayland libxkbcommon libpipewire pipewire **systemd** polkit util-linux e2fsprogs iproute2 **nftables iptables** android-tools`；`file` = `ELF 64-bit ARM aarch64 … interpreter /lib/ld-linux-aarch64.so.1` | `https://github.com/denialwm/droidloom/releases/download/packages/droidloom-runtime-0.1.0-30-aarch64.pkg.tar.zst`（6 598 150 B，已下） |
| 安装形态 | `docs/INSTALL.md`：*"…x86_64 Arch Linux and **aarch64 Arch Linux ARM** … Prebuilt packages for both"*；队伍仍是 **pacman + systemd user session + polkit**；*"Google apps are not included"*；~975 MiB 下载 / 2.5 GiB 安装 / ≥20 GiB 数据 | `https://raw.githubusercontent.com/denialwm/droidloom/main/docs/INSTALL.md` |
| 交叉编 | `docs/BUILDING.md` §"cross-build the aarch64 pair"：`cargo run -p droidloom-package -- build --architecture aarch64 --sysroot <ARM64 rootfs>` | `…/main/docs/BUILDING.md` |
| 硬需求原文（未变） | `docs/architecture.md:107–108`：*"The presenter requires `xdg-shell`, `linux-dmabuf` v4 feedback and `linux-drm-syncobj` synchronization."*；代码里 `globals.bind(&qh, 1..=1, ())?` **无 fallback**（`graphics/droidloom-wayland/src/main.rs:3217`，2026-11-05 main） | `…/main/docs/architecture.md`、`…/main/graphics/droidloom-wayland/src/main.rs` |
| PI/Widevine 口径 | 见 §1.1 M4（`docs/threat-model-v2.md` 原文未变） | `…/main/docs/threat-model-v2.md` |
| 相机白名单 | `docs/contracts/runtime-layout-v1.md:142` 仍禁 *"physical input, framebuffer, **camera**, media, USB, Bluetooth, modem, block, raw memory"* | `…/main/docs/contracts/runtime-layout-v1.md` |

### 2.2 合成器侧（本轮的核心增量）

| 对象 | 事实 | 依据 |
|---|---|---|
| **phoc（我们的合成器）** | 版本 **0.58.0**（Debian sid `phoc 0.58.0-1`，设备实测亦 0.58.0）；**全树无 `syncobj`**；`src/desktop.c:719–753` 建 viewporter / fractional-scale / output-power，**没有** drm-syncobj；`src/server.c:43` `PHOC_LINUX_DMABUF_VERSION 5` | 静态：`https://deb.debian.org/debian/pool/main/p/phoc/phoc_0.58.0.orig.tar.xz`（842 960 B，已下） |
| **phoc 内嵌 wlroots** | `subprojects/wlroots-0.20.x`（依赖 `wlroots-0.20 >= 0.20.2`）；`types/wlr_linux_drm_syncobj_v1.c:443` 有 `wlr_linux_drm_syncobj_manager_v1_create(display, version, drm_fd)`，内部先查 `DRM_IOCTL_SYNCOBJ_EVENTFD`，不支持则只打日志返回 NULL | 同上 |
| ⇒ 缺口量级 | **一行**：`wlr_linux_drm_syncobj_manager_v1_create(display, 1, wlr_renderer_get_drm_fd(wlr_renderer))`；phoc 已有 `wlr_renderer` 与 `wlr_backend`（`wlr_backend_get_drm_fd()` 可用），且 `meson.build:11` 已带 `-DWLR_USE_UNSTABLE` | 静态（同上，函数签名与 phoc 变量作用域逐项核对） |
| **mutter** | **已支持** `linux-drm-syncobj-v1`：`NEWS` 46.1 *"Implement linux-drm-syncobj-v1 [Austin; !3300]"*；main（`51.1`）`src/wayland/meta-wayland.c:1027` 调 `meta_wayland_drm_syncobj_init()` | 静态：`https://github.com/GNOME/mutter`（`NEWS`、`src/wayland/meta-wayland.c`） |
| **sway / wlroots** | `sway/server.c:298–302`：仅当 `renderer->features.timeline && backend->features.timeline` 才创建该 global（master = `1.13-dev`；1.12 标签同形）；`features.timeline` 需 `DRM_CAP_SYNCOBJ_TIMELINE` + `EGL_ANDROID_native_fence_sync` + `EGL_KHR_wait_sync` | 静态：`https://github.com/swaywm/sway/blob/master/sway/server.c`、phoc 内嵌 `render/gles2/renderer.c:687–690` |
| **Denial（同作者合成器）** | 仍活跃：1422★ / 24 releases，最新 **v0.6.2（2026-11-04）**；**aarch64 已有** `pkg.tar.zst` / `.rpm` / `.deb`（同 release）；**但 Alpine APK 仍 x86-64 only**（`docs/INSTALL.md:17`）；两个会话级硬坑仍在（`docs/KNOWN_ISSUES.md`: GPU reset 终结会话、运行时改缩放 `GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT` 36054） | 实测/静态：`https://api.github.com/repos/denialwm/denial/releases`、`…/main/docs/{INSTALL,KNOWN_ISSUES}.md` |

### 2.3 "namespace cell 而非 VM"复核

| 检查 | 结果 |
|---|---|
| 本机 source 树（`build/droidloom/droidloom/`，0.1.0 源码 2026-10-24 解包）`grep -ril kvm|qemu|virtio` | **0 / 0 / 0 个文件**（静态） |
| 在线 `search/code?q={kvm,qemu,virtio}+repo:denialwm/droidloom` | `total_count` = **0 / 0 / 0**（实测，2026-11-08） |
| 反向正面证据 | `README.md`：*"Real Android, no VM. Android runs on the host kernel with a private binderfs"*；`docs/threat-model-v2.md:120` 把 VM 说成 *"separately designed hardened VM mode"*（未来项） |
| 内核侧不构成障碍 | 设备/配置 `CONFIG_KVM` 未设、无 `/dev/kvm`（〔构建机〕§4.1）——droidloom 不需要它 |

### 2.4 GMS / Play Integrity / Widevine 官方口径是否变化

| 项 | 2026-10-30 记录 | 2026-11-08 复核 | 变化 |
|---|---|---|---|
| PI/attestation | 明确"not supported claims" | **原文未变**（`threat-model-v2.md:116–120`） | **无** |
| GMS 供给 | 不随包提供；GApps 需本地供给 `LiteGapps` aarch64 | 未变：`INSTALL.md` *"Google apps are not included"*；`KNOWN_ISSUES.md:157–167` 记 ARM64 上 **Play 登录已验证**（Android 17 + 本地供给的 Play Services 24.23.37 / Play Store 41.3.25），随后 Play 自动升级到 26.33.32 | 无（仅使用体验细节增加） |
| 设备认证 | Moto cell 上 Play 报"未认证" | **未变**（`KNOWN_ISSUES.md:232`） | 无 |
| Widevine | vendor `mediadrm/` 只有 ClearKey | 未变（无 L1/L3 库、分配器仍拒 protected allocation，`architecture.md:74`） | 无 |

---

## 3. 本机前置缺口（只读核对，全部静态）

证据源：`build/daily/.config`（7.3.0-rc7，对应设备 `uname` 的 vk172 线）、`build/daily/` 源码树、`build/droidloom/droidloom/` 源码树。
**本轮未上机**（`ssh` 一条未发），设备侧数值引用〔构建机〕2026-10-31 的实测快照并标日期。

| # | 前置 | 现状 | 缺口 / 动作 | 谁做 |
|---|---|---|---|---|
| K1 | binderfs + 三设备 | `CONFIG_ANDROID_BINDERFS=y`、`ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"` | 无（droidloom 自建**私有** binderfs，比 Waydroid 少一次冲突） | — |
| K2 | memfd / ashmem | `CONFIG_MEMFD_CREATE=y`；`ASHMEM` 无（主线无该符号，Android 17 走 memfd） | 无 | — |
| K3 | 命名空间 + cgroup | `NAMESPACES/USER_NS/PID_NS/NET_NS/UTS_NS/IPC_NS=y`；`CGROUPS/MEMCG/CGROUP_PIDS/CGROUP_FREEZER/PSI=y` | 无（设备 cgroup v2 + `user@1001 Delegate=yes`，2026-10-31 实测） | — |
| K4 | BPF（netd/netbpfload） | `BPF_SYSCALL=y`、`CGROUP_BPF=y`、`BPF_JIT=y` | 无 | — |
| K5 | syncobj + eventfd | `DRM_SYNCOBJ` 不是 Kconfig 选项：`drivers/gpu/drm/Makefile:69` 随 `DRM` 无条件编入；`drm_syncobj.c` 有 `syncobj_eventfd_entry` 路径；uapi `DRM_IOCTL_SYNCOBJ_EVENTFD` 在 | **静态判"在"**；仍建议一次 ioctl 探针（未做，标**未取证**） | 我们（探针） |
| K6 | dma-heap | `DMABUF_HEAPS=y`、`SYSTEM=m`（`/dev/dma_heap/system` 需 `modprobe system_heap`，设备实测在） | 无 | — |
| K7 | 镜像挂载 | `EROFS_FS=y`、`EXT4_FS=y`、`BLK_DEV_LOOP=y`（`LOOP_MIN_COUNT=8`，内核按需动态分配；droidloom 私有 `/dev` 投影 256 个 minor） | 无硬缺口；`max_loop` 是否需要显式设 = **未验证** | 我们（上机时看） |
| K8 | **nftables**（cell 网络） | `# CONFIG_NF_TABLES is not set`；`NF_TABLES_INET/NFT_CT/NFT_NAT` 全无；`NF_CONNTRACK=y`、`NETFILTER_XTABLES=y`、`VETH=m` | **必须补**：`NF_TABLES`、`NF_TABLES_INET`、`NFT_CT`、`NFT_NAT`（masquerade 还要 `NFT_MASQ`/`NF_NAT`）；否则 `start_development_cell` 在 `DevelopmentNetwork::create` 直接失败 | 我们（内核配置 + 重编/刷写，需用户在场） |
| K9 | Android SELinux LSM | 无（`CONFIG_SECURITY=y` 但无 SELinux） | 不可补（上游同结论：宿主共享内核装不了私有策略），只能接受 PID-context 回退 | 无解 |
| K10 | 宿主服务形态 | 设备 = **Debian forky/sid + systemd**（2026-10-31 实测），含 `pipewire 1.6.9`、`polkitd 128`、`nftables 1.1.7`、`iptables 1.8.13`、`libdrm2`、`libxkbcommon0`、`adb`、`e2fsprogs` | 包是 **pacman** 格式（`arch = aarch64`，glibc）⇒ **摊开装到 `/opt` 或转 `.deb`**；systemd unit 可直接用（glibc/ABI 对得上）；缺 `mkfs.erofs`/`simg2img`/`lpunpack`（只在建/迁镜像时需要） | 我们（≤半天，无编译） |
| K11 | 桌面合成器 | phoc 0.58.0（Mesa 26.2.5）；`xdg_wm_base v6`、`zwp_linux_dmabuf_v1 v5`、`zwp_text_input_manager_v3 v2`、`zwlr_output_power_manager_v1 v1` 在；**`wp_linux_drm_syncobj_manager_v1` 缺** | 一行补丁 + 重编 phoc（1 天，含回退旧二进制）；或换 sway/Denial（= 动 G1 桌面，不做） | 我们（可选） |
| K12 | Waydroid 资产可迁移性 | 结论不变（〔可研〕§3.4）：属性投影做法可搬；相机 provider / 音频 4 层 / 传感器 HAL / LXC 经验**作废**；`elden-hapticd` 本体保留 | — | — |

**缺口排序（按"能否单方面解"）**：K8（内核一档）→ K10（装法）→ K11（一行）→ K5（探针）。四件全是**我们**能做的，**没有一件卡在上游**；上游卡我们的只剩 **broker（相机/传感器/触觉）** 与 **PI/Widevine 口径**。

---

## 4. 最小隔离试验路径与资源成本

**总原则**：不写 boot、不换 `greetd`/`phosh-session`、不动 `/usr`、不装 pacman 库；一切落 `/opt/droidloom-trial`；
每步 `timeout -k 10 540`；任何与 `PITFALLS` 已知模式不符的错误即停。

| 级 | 内容 | 判据（二值） | 资源/时间 | 前置 |
|---|---|---|---|---|
| **L0** | 本轮静态+在线复核（**已完成**） | 已有结论 | 0 | — |
| **L1** | **syncobj 探针**（只读）：`WAYLAND_DEBUG=1 <任意客户端>` 抓 registry（〔构建机〕§4.1 命令） | `grep -c wp_linux_drm_syncobj_manager_v1` = 0（当前） | 1 分 | 无 |
| **L2** | **phoc 一元补丁**：`/opt/phoc-syncobj` 另编（源码 + 一行 `wlr_linux_drm_syncobj_manager_v1_create`），只在**临时会话**验证 | 新会话出现该全局 **且** 面板有内容/165 Hz 不变/无 KMS commit 失败 | 设备一次性 ~2 GiB 源码+工具链；编译 10–30 min（估） | 设备有 `-dev` 头包（10-31 实测**缺** `libgbm-dev` 等 6 个）→ 需装包（写操作） |
| **L3** | **内核补 nftables**：`NF_TABLES`+`NF_TABLES_INET`+`NFT_CT`+`NFT_NAT`（+`NFT_MASQ`），走既有 vk 构建/`fastboot boot` 零写盘通道 | 设备 `nft list tables` 成功、`modprobe veth` 后 `nft -f -` 能建 inet/ip 表 | 一次配置 + 一次内核构建（既有流水线，1–2 h 机时）+ 零写盘启动 | **需用户放行**（刷/启动动作） |
| **L4** | **runtime 摊装**：`tar -xf droidloom-runtime-0.1.0-30-aarch64.pkg.tar.zst` → `/opt/droidloom`，改 unit `ExecStart` 前缀；只跑 `droidloom-doctor` + `droidloom-wayland` | presenter 能过 8 个 `globals.bind`（syncobj 由 L2 提供）并挂在会话里不崩 | 下载 **6 598 150 B**；落地 ~22 MiB；0 编译 | L2 过 |
| **L5** | **image + cell 首启**：image 包摊到 `/var/lib/droidloom/images`（或 `/opt` 私有 `image_dir`），`droidloomctl start` | `Android is ready` + `launch com.android.settings` 出宿主 `xdg_toplevel`；原 Phosh 会话不受影响；**ARM64 cell 首启 = 上游 `still_required` 项，从未有人跑过** | 下载 **964 196 458 B（0.90 GiB）**；装后 2.5 GiB + 镜像 ~1.5 GiB；设备 73 GiB 空闲（10-31 实测）足够 | L3+L4 过 |

**资源汇总（最小可判定路径 = L0→L4）**：下载 **≈0.90 GiB**（image）+ **6.6 MB**（runtime），均 <1 GiB/件；
磁盘 ≤ 5 GiB；机时 ≈ 2 天（L2 一天、L3 半天、L4 半天），**不含** L5。
**明确不做**：不装进 `/usr`/不建 pacman 库/不改 `greetd`/不跑 `droidloomctl start` 之外的写操作；
不为试验去改 droidloom 的设备白名单（等于分叉上游）。

---

## 5. 退出条件与复启判据

### 5.1 退出（满足任一即关门，不做"再试一次"）

| # | 条件 | 说明 |
|---|---|---|
| E1 | L2 造出全局但 msm/KMS 出现可见回归，且 2 次单变量试验不收敛 | 显式同步在 `msm` 上的未知行为是唯一"我们自造"的风险 |
| E2 | L3 之后 `DevelopmentNetwork::create` 仍失败，或修它需要 >2 项内核配置之外的改动 | 说明 cell 启动路径与我们的内核假设不符 |
| E3 | 上游再连发 **2 个 `packages` 修订**而 `android/hardware/README.md` 的 sensor/vibrator/camera 三句仍在 | 跑起来也只是"能开设置页"，对 U3/U4/U7 无意义 |
| E4 | 任一步要求**改 G1 日常桌面**（换合成器/换会话管理器/改 boot 归属） | 这是产品决策，不是试验成本 |
| E5 | L5 的 ARM64 cell 首启在 2 次尝试内拿不到 `Android is ready`，且日志落在上游 `KNOWN_ISSUES` 未列的新失败签名 | 等于替上游做 ARM64 首启 port，超出 G2 预算 |

### 5.2 复启判据（本项目"只跟踪"的翻牌条件，任一成立即重评）

| # | 触发 | 判据命令/检查（只读） |
|---|---|---|
| R-a | **上游出现外设 broker**（相机/传感器/触觉任一） | `gh api …/contents/android/hardware/README.md` 的 *"not established preview features"* 一句消失，或 `runtime-layout-v1.md` 的 camera 禁令消失 |
| R-b | **phoc 上游自己建 syncobj global**（或我们接受 L2 一元补丁） | `curl` Debian/sid phoc 源码全树 `grep -c syncobj`（当前 0）或设备 registry 出现该全局 |
| R-c | **PI/Widevine 官方口径变化** | `threat-model-v2.md` 的 *"Play Integrity are not supported claims"* 改动 |
| R-d | **Waydroid 主路线受阻**（`TASKS/README.md` §6 R1 由"可用"变"受阻"） | R1 行状态 |
| R-e | 上游发布 **GApps aarch64 add-on** 且 Play 认证状态改变（不再是 uncertified） | `KNOWN_ISSUES.md` 的 Moto cell 那条 |

> 注：**"aarch64 有没有发布包"这条已从复启判据中移除**（2026-10-31 起已满足，见 J1）——这是本轮对旧裁决的唯一翻转项。

---

## 6. 与既有文档的口径差异（建议总管并入，本文件不改 SSOT）

1. `TASKS/README.md` §5 **Q3**、§6 **R3 行**：`aarch64 仍无发布包`、`只发 x86_64 Arch` 已过期 ⇒ 应改为
   **"aarch64 包自 0.1.0-27（2026-10-31）起发布，2026-11-08 最新 0.1.0-30；仍未变的是 phoc 缺 syncobj global + 三 broker + PI/Widevine 无净增益"**。
2. 〔可研〕§1.2/§1.4、判决表 1/2/4 与 E2 中的"0 个 aarch64 资产"、"aarch64 自建不做" ⇒ 同上过期；
   〔可研〕§2.1 表里 `linux-drm-syncobj` 那一行的动作（"phoc 加一行"）**本轮被源码级确认可行**（phoc 0.58.0 + 内嵌 wlroots 0.20.x）。
3. 〔可研〕§2.3/§5 里 `Mutter 不满足` 的表述 ⇒ **mutter 自 46.1 起已实现 `linux-drm-syncobj-v1`**（本机宿主 GNOME 即满足；与 Phosh/phoc 是两个仓）。
4. 〔构建机〕§2 A3/A4/A5–A7、§3.2 M1–M4 的整条"自建"方案 ⇒ 因上游已发 aarch64 包，**M1 设备原生编、M3 手搓 image 都不再必要**；保留其**设备只读实测**与 **M1-e 失败点定位**作为本轮证据。
5. 本轮**新增**一条旧文档都没有的前置：**内核 `NF_TABLES` 未设**（cell 网络硬依赖，见 §3 K8）。

---

## 7. 边界（本轮做了什么/没做什么）

- **做**：`gh api` 只读核实 droidloom（41 资产 / 4 个 aarch64 修订 / INSTALL-BUILDING-KNOWN_ISSUES-threat-model 原文）、
  Denial（24 releases / v0.6.2 aarch64 资产 / INSTALL / KNOWN_ISSUES）、mutter（NEWS + `meta-wayland.c`）、sway（`server.c`）、
  phoc 0.58.0（Debian pool 源码 842 960 B，全树 grep + 一行补丁的可行性核对）、
  本机内核配置 `build/daily/.config`（7.3.0-rc7）逐项、内核 `drivers/gpu/drm/{Makefile,drm_syncobj.c}`、
  droidloom 源码树（本地 8.1 MiB）全树 grep。
- **下载**：`droidloom-runtime-0.1.0-30-aarch64.pkg.tar.zst` **6 598 150 B**（解包核对 ELF/PKGINFO）、
  `phoc_0.58.0.orig.tar.xz` **842 960 B**。**image 包（0.90 GiB）未下**（体积与用途不成正比，`-r 0-0` 只取 1 字节测可达性）。
- **没做**：`git clone`（0 次）、设备 `ssh/adb/fastboot`（**一条未发**）、装包（0）、构建（0 次编译）、
  `README/INDEX/TASKS/DEVICE/RESOURCES/PITFALLS/versions/` 改动（0 处）、发信/开 issue（0）。
- **唯一写入**：本文件 + `TASKS/sessions/2026-11-08-droidloom可行性.md`。
