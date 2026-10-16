# Waydroid + Mesa 26.1 构建 — 进度与恢复（2026-10-01）

> 📦 **2026-10-02 迁盘**：本树现位于 **`/mnt/Samsung/waydroid-build`**（1T PM9A1，ext4，UUID `1847ae03-…`）。
> 旧路径 `~/waydroid-build`、`/mnt/data` **已不存在**（无符号链接）；
> 脚本默认值已改：`y700-elden/scripts/mesa-build.sh`、`extract-mesa-libs.sh`、`wd.sh`、本目录 `space-watch2.sh`。
> 完整性校验（全部 1219 个 git 对象库 `fsck` 通过）见 `~/y700-elden/AOSP-MIGRATE-CHECK-2026-10-02.md`。
> 本树唯一一处本地修改（`device/waydroid/waydroid/waydroid_arm64_only/BoardConfig.mk`，只留 freedreno）
> 已另存为 `~/y700-elden/patches/waydroid-boardconfig-freedreno-only.patch`。

> 停机加盘前的状态存档。**继续时先读本文件。**

## 0. 目标
给 Y700 四代（elden / SM8750 / Adreno 830 / 主线 Linux / Alpine musl）的 **Waydroid 容器**
换一份支持 **Adreno Gen8 主线 DRM** 的 Mesa（**≥26.1**）。当前官方镜像自带的 Mesa 26.0.8
只在 KGSL 下标了 A830 的 chip id，主线 DRM 下 GPU 会 hang。

## 1. 已完成（结论）
- 根因：容器 `libgallium_dri.so`(Mesa 26.0.8) 设备表只有 `chip_id=0x44050000`(KGSL)；
  内核主线 DRM 上报 `chip_id=0xe844050000`；DRM 用的表项 `0xffff44050000` 是 **Mesa 26.1 才加**。
- 宿主 Alpine Mesa 26.1.6 正常 → 证明内核没问题，是容器 Mesa 版本问题。
- **临时绕过**（已上机）：把容器 `libgallium_dri.so` 偏移 `0x1f7bf90` 的 8 字节
  `0x44050000 → 0xffff44050000`（bind-mount 覆盖）。效果：SurfaceFlinger 从崩溃循环 → `running`，
  GBM/EGL 报错消失；但 GPU 仍 `hangcheck lockup`（26.0.8 的 Gen8 实现不完整）。
- 源码树已在下载：`~/waydroid-build`（LineageOS 20.0 / Android 13）。
  Mesa 已改指向 **`WayDroid-ATV/android_external_mesa3d@lineage-18.1-mesa-26.1` = Mesa 26.1.8**。
- `repo sync` **未完成**：已下 ~43G，在 `android.googlesource.com` 的 rust crates 上
  `GnuTLS handshake failed`（代理中断）。可断点续传。

## 2. 关键路径 / 配置（随目录迁移，别丢）
- 源码树：`~/waydroid-build`（含 `.repo`，43G）
- 本地清单：`~/waydroid-build/.repo/local_manifests/`
  - `00-remotes.xml`（ghub/gitlab）
  - `01-removes.xml`
  - `02-waydroid.xml` ← **第 17 行**是 Mesa 覆写：
    ```xml
    <project path="external/mesa" name="WayDroid-ATV/android_external_mesa3d"
             remote="ghub" revision="refs/heads/lineage-18.1-mesa-26.1" />
    ```
- 工具：`~/bin/repo`、`~/bin/git-lfs`（重装系统需重下）
- 续传脚本：`sync-resume.sh`（去代理 + 自动重试）；看门狗：`space-watch.sh`（根分区 <20G 自动停 sync）
- git 全局：`http.proxy/https.proxy=http://127.0.0.1:7897`、`user.*`、`http.postBuffer=500M`

## 2.5 网络路径（2026-10-01 重启后实测，重要）
本机 Clash 代理 `127.0.0.1:7897` 当时**已失效**：所有 https 经它都返回 000，
表现就是 git 报 `GnuTLS, handshake failed: The TLS connection was non-properly terminated`
（googlesource / github 都中招）。**直连却可用**：

| 目标 | 直连 | 经代理 |
|---|---|---|
| github.com | ✅ 200 | ❌ 000 |
| gitlab.com | ✅ 301 | ❌ 000 |
| storage.googleapis.com | ✅ 200 | ❌ |
| raw.githubusercontent.com | ✅ 301 | ❌ |
| android.googlesource.com | ❌ 超时 | ❌ |
| mirrors.tuna.tsinghua.edu.cn (AOSP) | ✅ 200 | — |

因此续传脚本 `sync-resume.sh` 的做法：**清空 http(s)_proxy 环境变量 + unset git 全局
`http.proxy`/`https.proxy`**（git 的 config 代理优先级高于 env），
AOSP 走 TUNA 镜像（`url.*.insteadOf` 已配）。

> 恢复代理后若想要回原状：`git config --global http.proxy http://127.0.0.1:7897` 等，
> 备份在 `~/.gitconfig.bak-*`。

## 3. 重启 / 加盘后恢复步骤
1. **迁移目录到新盘**（保留 `.repo`，43G 不白下）：
   ```bash
   mv ~/waydroid-build /mnt/<newdisk>/waydroid-build     # 或用新盘挂到 /home 下
   ```
   `repo` 支持任意路径。
2. 恢复工具/代理（若重装系统）：
   ```bash
   mkdir -p ~/bin
   curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o ~/bin/repo && chmod +x ~/bin/repo
   # git-lfs 见 v3.8.0 release
   git config --global http.proxy http://127.0.0.1:7897
   git config --global https.proxy http://127.0.0.1:7897
   ```
3. **aosp 走清华镜像**（解决 googlesource TLS 失败）：
   ```bash
   git config --global url."https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/".insteadOf "https://android.googlesource.com/"
   ```
   （已验证该镜像 `info/refs` 返回 200）
4. **继续同步**（可反复执行，断点续传；降并发更稳）：
   （可选）同时开空间看门狗，根分区 <20G 时自动停 sync：
   ```bash
   setsid nohup ./space-watch.sh > space-watch.log 2>&1 &
   ```
   ```bash
   cd <tree>
   nohup ./sync-resume.sh >> sync.log 2>&1 &
   tail -f sync.log
   ```
   `sync-resume.sh` 已含「去代理 + 自动重试 20 次 + 断点续传」逻辑。
5. **构建**：
   ```bash
   . build/envsetup.sh
   apply-waydroid-patches
   lunch lineage_waydroid_arm64_only-userdebug
   make vendorimage -j16
   ```

## 4. 构建产物部署（二选一）
- **A. 整块 vendor**：`waydroid init -f` 用新 `vendor.img`（system 沿用官方 lineage-20）。
- **B. 只换 Mesa 库**：从新 `vendor.img` 取
  `/vendor/lib64/{libgallium_dri.so,libgbm_mesa.so,dri_gbm.so,libgbm_mesa_wrapper.so,libminigbm_gralloc_gbm_mesa.so}`、
  `/vendor/lib64/egl/*_mesa.so`、`/vendor/lib64/hw/{*minigbm*,vulkan.freedreno.so}`、`dri_gbm.so`
  → 放到设备 `/root/wd/` 并更新 `config_nodes` bind-mount。
  ⚠️ **换新 Mesa 后必须去掉旧的 8 字节 chip-id 补丁**，否则会用到错误的 `fd_dev_info`。

## 5. 设备端现状（Y700 rootfs，持久；主机重启不影响）
- 内核 **vk27（#22）**，`/init` 开机挂 `cgroup2` + `binderfs`。
- `/root/wd/libgallium_dri.so`（打了 8 字节 chip-id 补丁）、`/root/wd/allocator.rc`
  （给 allocator 加了 `setenv MINIGBM_DEBUG 1`）。
- `/var/lib/waydroid/lxc/waydroid/config_nodes` 追加 3 条 bind-mount：
  `card0`、`allocator.rc`、`libgallium_dri.so`（备份 `config_nodes.orig`）。
- Waydroid 镜像：官方 lineage-20 arm64_only（system 1.63G + vendor 236M），本地 OTA 源脚本
  `~/y700-elden/scripts/waydroid-ota-serve.sh`。
- **回退**：删掉那 3 条 bind-mount → 恢复原状。

## 6. 资源
- 主机：16 核 / 61G 内存 / 根分区 468G（已用 251G）。**1T 新盘即将加入**。
- 预计整树 sync 还需几十 GB；`make vendorimage` 另需 ~50-100GB + 数小时。

---

## 7. 并行准备（2026-10-01 晚）——脚本 + 修正后的构建路线

### 7.1 结论：NDK 快路径**不可行**，改为「定向模块构建」
- `dl.google.com`（NDK 下载源）**直连 000、代理 7897 也 000** → 拿不到 NDK。
- 且 Mesa 的 Android 构建走 **AOSP make 驱动 meson**（`android/Android.mk` +
  `mesa3d_cross.mk`），依赖 AOSP 内的 `libdrm/llvm-project/minigbm/zstd/libc++`，
  **无法用 NDK 独立编**。→ 放弃 NDK，回到树内构建。
- **优化**：不必 `make vendorimage`（1–3h），只 make 需要的模块（通常十几分钟）：
  ```
  libgallium_dri libEGL_mesa libGLESv1_CM_mesa libGLESv2_mesa libGLES_mesa
  libgbm_mesa dri_gbm libgbm_mesa_wrapper gralloc.minigbm_gbm_mesa gralloc.gbm vulkan.freedreno
  ```

### 7.2 已备好的脚本（主机 `~/y700-elden/scripts/`）
| 脚本 | 作用 |
|---|---|
| `mesa-build.sh` | envsetup + lunch `lineage_waydroid_arm64_only-userdebug` + 定向 make + ccache |
| `extract-mesa-libs.sh` | 从 `out/target/product/waydroid_arm64_only/vendor/lib64/` 抽库，校验 `0xffff44050000`，打包 tar |
| `mesa-deploy.sh` | scp 到设备 `root@192.168.7.1` 并调用设备端脚本 |
| `waydroid-mesa-swap.sh` | **设备端**：bind-mount 换库 + **移除 8 字节补丁** + `rollback` 回退 |

ccache 已配：`/mnt/Samsung/ccache`，上限 100G（`mesa-build.sh` 里默认值已随迁盘改好）。

### 7.3 库清单 ↔ 安装路径（vendor/lib64 下，来自 Android.mk 的 `LOCAL_VENDOR_MODULE`）
```
libgallium_dri.so
libgbm_mesa.so
dri_gbm.so
libgbm_mesa_wrapper.so
egl/{libEGL_mesa,libGLESv1_CM_mesa,libGLESv2_mesa,libGLES_mesa}.so
hw/{vulkan.freedreno,gralloc.minigbm_gbm_mesa,gralloc.gbm}.so
```
设备端落点 `/root/wd/mesa/`，通过 `config_nodes` 标记块（`>>> waydroid-mesa-swap BEGIN`）bind-mount。

### 7.4 关键认知
- **8 字节补丁必须移除**：`/root/wd/libgallium_dri.so` 里 `0x44050000 → 0xffff44050000`
  （偏移 `0x1f7bf90`）是为骗过 26.0.8；新库自带正确表项，**旧补丁 bind-mount 会覆盖新库**。
- 设备端 `config_nodes` 在 `/var/lib/waydroid/lxc/waydroid/config_nodes`。
