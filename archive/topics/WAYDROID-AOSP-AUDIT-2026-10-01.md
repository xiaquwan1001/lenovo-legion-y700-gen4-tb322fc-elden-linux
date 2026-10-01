# Waydroid 卡点审计 — 阻塞链条与本地编译 AOSP 的必要性（2026-10-01）

> 来源：会话 `01a0f7cd`（`audit(waydroid): 卡点与本地编译 AOSP 必要性`，2026-10-01 22:10–23:04）。
> 该会话完成了只读审计并在结束时口头答复"可以，写文档"，但**文档未及落盘**——本文即补写归档。
> 审计性质：**纯只读核查**，未执行任何构建/刷写/改动。所有数字为审计时点快照。
> 技术前史（如何卡到这里）见 `WAYDROID-2026-10-01.md` §3/§6；构建进度存档见 `~/waydroid-build/PROGRESS.md`。

---

## 0. 一句话结论

卡点是 **"为拿 bionic 版 Mesa ≥26.1 而全量拉 AOSP 树，被 GitHub 代理 TLS 拖死"**，
不是技术死胡同。本地编译 AOSP 里的 Mesa **有必要、且是拿到 bionic Mesa 26.1 的唯一路径**，
但**只需几十个工程、定向 make 十几个模块**；现有 535 GB 全树属**过度下载**，
且 **`repo sync` 不跑完也能开编**。建议：收窄为 **freedreno-only** 最小构建先做出声验证。

---

## 1. 关键数字（审计时点 2026-10-01 22:40）

| 项 | 实测值 | 取证方法 |
|---|---|---|
| `~/waydroid-build` 体积（在 `/mnt/data`） | **535 GB**（`.repo/project-objects` 独占 **432 G**） | `du` |
| `/mnt/data` 余量 | 356 G（看门狗 `space-watch2.sh` 停止阈值 70 G，安全） | `df` |
| manifest 工程数 | 1081；已检出 **1070**；缺 **11** | `default.xml` + `02-waydroid.xml` 对照目录 |
| 下载耗时 | 约 **10.5 h**（12:00 起）仍不收敛，卡在 GitHub 代理 TLS 重试（attempt 3/20） | `sync2.log` |
| **是否构建过** | **否**：无 `out/`；ccache 使用 **0.0%** | `ls out/`、`ccache -s` |
| Mesa 源码状态 | `external/mesa` @ `6ba7c2f4ce2` **= manifest 目标 revision**；`VERSION=26.1.8`；分支 `ghub/lineage-18.1-mesa-26.1` | `git rev-parse` 对照 manifest |
| A830 DRM chip-id 修复 | `48be91d`（`0xffff44050000`）**已在**该 revision 内 | `git log`/`git show` |
| 官方 vendor.img 的 Mesa | **26.0.8**（`lineage-20.0-20260927-MAINLINE-waydroid_arm64_only`） | 解包 `vendor.img` + `strings` |

---

## 2. 卡点链条（真正的"卡"在哪）

前后两次"卡"，性质不同。

### 2.1 技术卡点（已定位到底，非阻塞项）

1. 基础设施**全通**：镜像下载（curl 走代理，Motrix/aria2 直连 SourceForge 被 403）、
   内核 netfilter（vk27）、iptables-legacy、cgroup2/binderfs、LXC + pulse 占位，
   `Container/Session: RUNNING`，composer/health/light/power/sensors HAL + zygote64 + system_server 全起。
2. SurfaceFlinger abort `output buffer not gpu writeable` → RenderEngine 建 EGL image 失败
   （`skia: Could not create EGL image, err = (0x3000)`）。
3. 开 `MINIGBM_DEBUG` 抓到真因：Mesa GBM `fd_pipe_new2: unsupported GPU id 0xe844050000`。
   - 容器 Mesa **26.0.8** 的 A830 表项只有 KGSL 的 `0x44050000`；
   - 主线 DRM 上报的 `0xffff44050000` 是 **Mesa 26.1 才加**（上游 commit
     `48be91d` "freedreno/common: Fix upstream a830 chip_id"，MR 40458，补 fuse bits）。
4. **8 字节二进制补丁**绕过查表（`libgallium_dri.so` 偏移 `0x1f7bf90`：
   `0x44050000 → 0xffff44050000`）→ SF 从崩溃循环变 `running`，但随即
   `hangcheck detected gpu lockup`（offending task = RenderEngine）→ 26.0.8 的 Gen8/主线 DRM
   支持不完整，**必须 Mesa ≥ 26.1**。
5. 宿主 Alpine Mesa 26.1.6（musl）同 GPU 正常，但容器库依赖 bionic `libc.so`，
   **无法把宿主 Mesa 绑进容器**——跨 libc 不可换。

### 2.2 资源/依赖卡点（当前停滞处，即本审计对象）

- 拿不到 bionic Mesa 26.1 成品 → 转自编 → `repo sync` 拉整个 LineageOS 20 树
  → **GitHub 代理 TLS 不稳**（`GnuTLS recv error (-9)` / handshake failed 反复，~0.5–1.5 MB/s）
  → 10.5 h 后仍剩 ~14 个大仓反复失败（`chromium-webview_prebuilt_*`、`external_skia`、`armnn`、
  `prebuilts_*`、`build_soong`、`hardware_qcom_{audio,media}` 等），**构建从未开始**。

> 换句话说：卡的不是"编不过"，是**为拿十几个 .so 拖了 535 GB 且网络收尾不了**。

---

## 3. 本地装/编 AOSP 是否必要？（三路径核查，均已取证）

**结论：要拿到 bionic Mesa 26.1，自编是唯一可行路径 →"编"有必要；但"装整个 AOSP"完全没必要。**

| 路径 | 判定 | 证据 |
|---|---|---|
| 找成品 arm64 bionic Mesa 26.1 | **不存在** | 官方 `waydroid_arm64_only` 最新 20260927 = **26.0.8**（解包 strings 确认）；WayDroid-ATV arm64 最新 20250913 = **25.2.1**；更新的 Mesa（26.1.x/26.3.0）只给了 x86_64 / 非容器 Android 场景 |
| NDK 独立编 Mesa | **死路** | 树里 `prebuilts/ndk` 只有 72 MB 平台 stub；Mesa 的 `android/mesa3d_cross.mk` 由 **AOSP make 驱动 meson + AOSP sysroot/crt**（`$(my_target_crtbegin_so_o)` 等），无法脱离树用裸 NDK 复现 |
| 树内定向构建 | **可行且是正解** | 所需源码工程几乎全在本地（见 §3.1），mesa 已在正确 revision |

### 3.1 定向构建的量化依据

- 全树 1081 工程里，**真正参与 Mesa 构建的只有约 20–40 个**
  （`android/Android.mk` 依赖：libdrm、libc++/libcxx、libxml2、libexpat、libelf、libzstd、
  libsync、libnativewindow、gralloc mapper、bionic、clang prebuilts、build/soong、prebuilts/{go,build-tools,rust,jdk} 等）。
  已逐项核查存在性：mesa ✅ / libdrm ✅ / llvm-project ✅(2.4G) / minigbm ✅ / bionic ✅ /
  libcxx ✅ / zstd ✅ / clang host ✅(2.2G) / build-tools ✅ / soong ✅ / go ✅ / misc ✅ / rust ✅ / sdk ✅ /
  build-make ✅ / blueprint ✅ / boringssl ✅ / protobuf ✅ / jdk11 ✅；仅 `external/libselinux` 缺（不在 Mesa 依赖图核心，报错再补）。
  → **全量 sync 属过度下载**。
- 缺失的 11 个工程与本目标**无关**：`external/mesa3d`、`prebuilts/vndk/v28-30` 被
  `local_manifests/01-removes.xml` **主动移除**（mesa3d 被 Waydroid 自己的 `external/mesa` 替代）；
  其余是 `tools/idea|base|studio|swt|motodev` 等 IDE 项；唯一可能相关的 `system/extras`
  缺失，但大概率不进 Mesa 模块依赖图。
- `repo sync` 失败只是 **fetch ref 失败**，各失败工程的 worktree 仍在正确 revision
  （抽查 libxml2/libpng/libdrm/json-c/libvpx 等 HEAD 日期与 manifest 一致）
  → **`repo sync` 无须跑完就能开编**。

### 3.2 构建时间优化：关 LLVM stub（小时级 → 十几分钟级）

- `external/mesa/android/Android.mk`：当驱动表含 `i915/r300` 或 `llvmpipe/swrast`（无 FORCE_SOFTPIPE）
  或 zink 时置 `MESON_GEN_LLVM_STUB := true` → `-Dllvm=enabled`，**强制构建/链接 `libLLVM22`（极耗时）**。
- Waydroid 基础 `device/waydroid/waydroid/BoardConfig.mk` 恰含 `llvmpipe swrast radeonsi`（GALLIUM）
  + `swrast virtio amd`（VULKAN）→ 默认会拖进 LLVM。
- 本设备只需 **freedreno**：`waydroid_arm64_only/BoardConfig.mk` 已 `+= freedreno`
  （GALLIUM 与 VULKAN 各自）。把基础 BoardConfig 的驱动表**收窄为 freedreno 单驱动**即可绕开 LLVM stub。
- 已有配套脚本（audit 时确认存在）：
  - `scripts/mesa-build.sh`：`lunch lineage_waydroid_arm64_only-userdebug` 后**只 make**
    `libgallium_dri libEGL_mesa libGLESv{1_CM,2}_mesa libGLES_mesa libgbm_mesa dri_gbm
    libgbm_mesa_wrapper gralloc.minigbm_gbm_mesa gralloc.gbm vulkan.freedreno`
    （ccache `/mnt/data/ccache` 100G），完成后自动抽库；
  - `scripts/extract-mesa-libs.sh`、`scripts/waydroid-mesa-swap.sh`（bind-mount 进容器替换）。

---

## 4. 必须提示的风险（推断 ≠ 实测）

- **"升到 Mesa 26.1 就能不 hang"是推断，不是实测。**
  反例：dri-devel 2026-08 线程《drm/msm: unrecoverable a8xx hang-recovery loop on Glymur》
  报告 Snapdragon X2 Elite（chip id `0x44070041`）+ **Mesa 26.1.5** 仍有 a8xx GPU hang
  恢复死循环；Rob Clark 怀疑在 OPP/供电路径而非 Mesa 版本。
- 支持证据（对**本设备**可信度中等偏高）：
  1. 本机 Alpine **Mesa 26.1.6**（musl，宿主侧）同 GPU 日常使用正常（GLES/Vulkan 工作）；
  2. 已 diff 验证：26.1.6（`Y700-elden-linux/mesa-26.1.6` 参考树）与树内 26.1.8 的
     **A830 表项逐字节相同**；
  3. 二进制补丁实验已把失败点从"查表失败"推进到"Gen8 命令路径 hang"，与版本缺口解释自洽。
- 可备用的调优点（若 26.1.8 仍 hang）：社区 A8xx Turnip 分支（ShineeX1/A8xx-Mesa-Turnip）
  对 A830 设 `has_fs_tex_prefetch = False`（上游 TODO 注明 A830 是唯一从 A7xx 继承 `True`
  的例外，其余 A8xx 均已关）；树内 `freedreno_devices.py` 的 A830 块同样未覆盖该项。
- 网络侧唯一外因：GitHub 代理节点对大传输不稳（换更稳 Clash 节点即解，与脚本/URL 无关）。

---

## 5. 建议路线（性价比排序）

1. **停止无意义的全量 sync 重试**；直接按 §3.1 判断**开编**（失败工程 worktree 已在位）。
2. 把 `BOARD_MESA3D_{GALLIUM,VULKAN}_DRIVERS` 收窄为 **freedreno-only** → 关 LLVM stub
   → 用 `scripts/mesa-build.sh` 做**最小定向构建**（预计十几分钟级）。
3. 产物经 `waydroid-mesa-swap.sh` 上机做**一次出声/不 hang 验证**，再决定是否做完整 vendor 镜像。
4. 若仍 hang：先试 `has_fs_tex_prefetch=False` 单行改动重编，再回头怀疑内核 OPP/供电路径（对照 Glymur 线程）。

---

## 6. 证据与文件清单

| 资产 | 位置 / 说明 |
|---|---|
| 本审计会话全文 | `.pi/sessions/2026-10-01T14-10-51-607Z_01a0f7cd-*.jsonl` |
| 构建进度/恢复手册 | `~/waydroid-build/PROGRESS.md`（断点续传、清华 AOSP 镜像、部署与回退） |
| 同步脚本（双路 precheck） | `~/waydroid-build/sync-resume2.sh`（github 走代理 + AOSP 走清华镜像直连） |
| 空间看门狗 | `space-watch2.sh`（<120G 警告、<70G 停 sync） |
| 定向构建/换库脚本 | `scripts/mesa-build.sh`、`scripts/extract-mesa-libs.sh`、`scripts/waydroid-mesa-swap.sh` |
| 官方镜像（Mesa 26.0.8 证据） | `~/下载/lineage-20.0-20260927-{VANILLA…-system,MAINLINE…-vendor}.zip`；`debugfs`/`strings` 可读 `26.0.8` |
| A830 chip-id 上游修复 | mesa `48be91d14ba`（freedreno/common: Fix upstream a830 chip_id，MR 40458） |
| 二进制补丁（临时绕过，已在机） | 容器 `/root/wd/libgallium_dri.so` 偏移 `0x1f7bf90` |
| **新构建脚本（已跑通）** | `scripts/mesa-build.sh`（含 PATH/`set +u`/补丁非致命）、`scripts/extract-mesa-libs.sh`、`scripts/mesa-deploy.sh`、`scripts/waydroid-mesa-swap.sh` |
| **新产物** | `~/mesa-out/mesa-vendor-26.1.8_waydroid_arm64_only.tar.gz` |
| **带外控制通道** | 见 `OOB-CONSOLE-2026-10-02.md`（USB CDC-ACM 串口 / ramoops） |

---

## 9. 容器黑屏根因与修复（2026-10-02）

**症状**：点 Waydroid 图标黑屏；`waydroid status` = `Session: STOPPED`。

**根因**（`lxc-start -l TRACE` 抓到唯一 ERROR）：
```
ERROR utils: safe_mount: No such file or directory - Failed to mount
      "/run/phosh/pulse/native" onto ".../run/xdg/pulse/native"
ERROR conf: lxc_setup:3820 - Failed to setup mount entries
```
`config_session` 的 pulse 条目默认 `rbind,create=file 0 0`（非 optional），宿主 phosh 会话没跑 pulse → 源文件不存在 → 容器拒绝启动。

**修复**（设备侧，已备份 `.bak-y700`）：`/usr/lib/waydroid/tools/helpers/lxc.py:207`
```python
make_entry(pulse_host_socket, pulse_container_socket[1:],
           options="rbind,create=file,optional 0 0")
```

**另一个操作坑**：`waydroid container start` 是**常驻 DBus 守护**（`container_manager.start()` 起 mainloop），不是一次性命令；必须先在后台常驻，再由 `waydroid session start`（在 phosh 会话 env 下）通过 DBus 触发 `ContainerManager.Start → do_start → lxc.start`。顺序反了会报 `WayDroid container is not listening` / `Container service is already running`。
| 参考 mesa 树（版本对照） | `Y700-elden-linux/mesa-26.1.6/`（含 `a830-chip-id.patch`） |
| 外部线程 | dri-devel 2026-08《a8xx hang-recovery loop on Glymur》；WayDroid-ATV releases；ShineeX1/A8xx-Mesa-Turnip `v26.3.0-…-a830-tuned` |

---

## 7. 与现有文档的衔接 / 状态更新

- `WAYDROID-2026-10-01.md` §6 记录根因与"选自编"的决定；本文回答**"为什么必须编、要不要全量装、怎么编最快"**。
- 审计后状态（2026-10-02 补记）：`repo sync` 进程已停（未跑完，按本文结论无需跑完）。

---

## 8. 执行结果（2026-10-02，§5 路线已全部落地）

**§0/§3 的结论得到验证：确实不需要全量 sync，定向构建十几分钟即可。**

| 步骤 | 结果 |
|---|---|
| §5-1 停全量 sync | ✅ 早已停止，`repo sync` 无须跑完即开编（失败工程 worktree 在位） |
| §5-2 freedreno-only 最小构建 | ✅ **成功，`#### build completed successfully (05:34 mm:ss) ####`**，远快于预计 |
| §5-3 产物上机验证 | ✅ **通过**：容器内 `GLES: freedreno, Adreno (TM) 830, OpenGL ES 3.2 Mesa 26.1.8`；`GPU missed frame count: 0`；无 `output buffer not gpu writeable`；无 hangcheck/gpu lockup；`sys.boot_completed=1` |

**产出**：`~/mesa-out/mesa-vendor-26.1.8_waydroid_arm64_only.tar.gz`（6.9 M，11 库 + manifest 校验和，aarch64/bionic，无 libLLVM 依赖）；`libgallium_dri.so` 含 A830 DRM chip id 字节 `0xffff44050000`。已 scp 到设备并经 `waydroid-mesa-swap.sh install` bind-mount 进容器（可 rollback）。

**构建期新增的 4 个坑（本文 §3.1/§5 未预见）**：

1. **缺 `external/python/mako`** —— LineageOS20 manifest 无此工程，而 WayDroid-ATV 的 `external/mesa/Android.bp` 的 `vk_icd_gen` 依赖 soong 模块 `mako` → 从清华 AOSP 镜像浅克隆到 `external/python/mako`。
2. **`repo` 不在 PATH** —— `vendor/extra/waydroid-patches/apply-patches.sh` 用 `repo info` 判断补丁是否已应用；缺 `repo` 会把全部补丁误判为冲突（脚本需 `export PATH=$HOME/bin:$PATH`）。
3. **meson ≥1.10 拒绝空值** —— `mesa3d_cross.mk` 无条件传 `-Dgallium-va=` / `-Dvideo-codecs=`；空值对 feature/array 选项报错 → arm64 BoardConfig 加 `BOARD_MESA3D_GALLIUM_VA := disabled`、`BOARD_MESA3D_VIDEO_CODECS := all_free`。
4. **`glslangValidator` 缺失 + AOSP PATH interposer 拦截** —— `with_bvh = ... or with_freedreno_vk` 为真 → 需要 native glslang；放到 `~/.cargo/bin/`（在 `out/.path` interposer 之前，否则被 AOSP 的 "not allowed to be used" 拦截）。

**收窄驱动改动**：`device/waydroid/waydroid/waydroid_arm64_only/BoardConfig.mk` 用 `:=` 覆盖
`BOARD_MESA3D_{GALLIUM,VULKAN}_DRIVERS := freedreno`，从而 `MESON_GEN_LLVM_STUB` 不置位、`-Dllvm=disabled`（节省小时级 libLLVM 构建）。

> **⚠️ 一个重要的旁证纠正**：用户报告的"点 Waydroid 黑屏"与本次 Mesa 无关。真因是 **LXC 容器启动失败**：`config_session` 里非 optional 的 `/run/phosh/pulse/native` 挂载源不存在 → `Failed to mount ...` → `container failed to start`。修复见 §9。
