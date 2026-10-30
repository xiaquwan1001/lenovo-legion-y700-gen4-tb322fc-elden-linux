# droidloom 真实构建 + 上机计划（2026-10-31）

> 性质：**可执行计划 + 本轮已完成的只读静态核验 + 允许范围内的小资产实测**（source 包 / runtime 包真实下载并解包）。
> 前序：`reports/droidloom-feasibility-plan-20261030.md`（下称〔可研〕，其 §1.2 = "release 资产全 x86_64、aarch64 资产 0 枚"）。
> 上游快照：`denialwm/droidloom` `main` @ `0af7b9b`（2026-10-28T18:59:15Z）。
> 证据标签：`已证`（有原文/命令输出）/ `未证实`（推断）/ `未上机`（有产物无实测）。
> 设备纪律：本轮对设备**零写操作**（需用户在场的动作只在 §4 计划里标注）。

## #0 一页结论

**① 能不能建：能，但不是一条流水线，是两条不相干的路。**
- 宿主侧 aarch64 runtime（7 个 ELF）= **能，且零 AOSP 依赖**：纯 Rust、`unsafe_code="forbid"`、无内联汇编，
  `runtime/droidloom-contracts/src/lib.rs:26–33` 把 `aarch64` 写成与 `x86_64` 并列的一等枚举值（其它架构直接 `compile_error!`）。
- aarch64 Android 镜像 = **能，但上游只在 x86_64 主机上 cross 过（`build_proven`）**，需要 1.03 GiB ARM64 CI 基础包 + 225 个 AOSP 项目的稀疏检出 + Soong 编 vendor + Mesa 26.1.7 交叉编。
- **唯一卡死点是合成器**：本轮在设备上实测 phoc 0.58.0 的 registry **没有 `wp_linux_drm_syncobj_manager_v1`**，
  而 presenter 硬 bind 它（`graphics/droidloom-wayland/src/main.rs:3113`）。

**② 在哪建：**
- 宿主二进制 → **目标机原生编**（8 核/14 GiB/73 GiB 空闲，Rust 1.93 已确认可从 CDN 装）。不用主机交叉（主机虽有 `aarch64-linux-gnu-gcc` + qemu binfmt，但 `/usr/aarch64-linux-gnu/lib` 里**没有任何** wayland/drm/gbm/xkbcommon/pipewire 的 aarch64 库或头）。
- Android 镜像 → **主机 x86_64**（上游唯一 proven 的路径），不要 aarch64 容器（主机**没装 podman**，且 qemu-user 下 `makepkg`/`fakeroot` 风险高）。

**③ 多久：** D1 出**可上机的 aarch64 runtime 目录 + presenter 真实启动日志**（这是 3 天内可达的产物；
**前提 = 用户当天放行两个写操作**：设备 `apt install` 6 个编译前置 + `rustup` 装 1.93.0）；
**cell 启动 3 天内不可达**，瓶颈是 AOSP 225 项目同步 + Soong 编 vendor（上游自述整机 120 GiB 峰值）与 syncobj 全局两件叠加。

**④ 要不要下 0.94 GiB 的 image：不下。** 它是 x86_64 ABI 的分区镜像，对 aarch64 零复用；其内容构成已由源码静态定死
（3 个复用 AOSP 分区 + 自建 `vendor.img` + Mesa 驱动，`droidloom-image/src/lib.rs:22,194,225` + `droidloom-update/src/image_policy.rs:176–209`）。
省下的额度留给 aarch64 真正需要的 1.03 GiB CI 包。本轮实际只下了 **8.74 MiB**（source 2.9 MB + runtime 6.2 MB）。

**⑤ 形态定性（推翻「KVM 依赖」的遗留疑问）**：droidloom 是 **namespace 容器 cell**，不是 VM。
全树 `grep -rInE '/dev/kvm|\bkvm\b|qemu|tcg|virtio|hypervisor'` **0 命中**；runtime 包无 qemu/libvirt 依赖；
`docs/architecture.md:5` 自述 "namespaces, image mounts and networking"；设备侧 `# CONFIG_KVM is not set` 与 `/dev/kvm` 缺失**都不构成障碍**。

---

## 0. 本轮已确认事实（滚动追加）

### 0.1 环境与上游快照（`已证`）

| 项 | 值 | 取得方式 |
|---|---|---|
| 上游 HEAD | `0af7b9b` 2026-10-28T18:59:15Z `Share folders into the running cell, also on Android's first start` | `gh api repos/denialwm/droidloom/commits` |
| release 条目 | 唯一 tag `packages`；6 个修订号（19/20/22/23/24/25）× 3 类资产，**全部 `x86_64`** | 同上 `releases`（本轮复算，见下表） |
| 主机 | x86_64 / 28 线程 / 60 GiB RAM / `/` 393 GiB 可用 | `nproc`、`free -g`、`df -h` |
| 下载落点 | `/var/tmp/droidloom-20261031/`（非 tmpfs）+ 解包到 `build/droidloom/` | 本轮建立 |

release 资产实测（本轮 `gh api` 原文，`packages` tag）：

```
droidloom-image-0.1.0-25-x86_64.pkg.tar.zst     1008393914 B   (79 次下载)  2026-10-24T11:10:35Z
droidloom-runtime-0.1.0-25-x86_64.pkg.tar.zst      6236891 B   (56)        2026-10-24T11:09:49Z
droidloom-source-0.1.0-25.tar.gz                   2924909 B   ( 5)        2026-10-24T11:10:37Z
```

—— 以下各节按「每 3–5 条发现追加一次」滚动写入 ——

### 0.2 本轮实际下载（`已证`，遵守 3 GiB 上限，**本轮累计 8.74 MiB**）

落点 `/var/tmp/droidloom-20261031/`；下载方式 `gh api -H 'Accept: application/octet-stream' …/releases/assets/<id>` + `timeout 600`，
两个文件并行、`wait` 后一次性核体积与 sha256（无残留进程：`wait` 返回即进程结束）：

```
6236891  droidloom-runtime-0.1.0-25-x86_64.pkg.tar.zst   (-25 资产 API 声明 6236891，逐字节相符)
2924909  droidloom-source-0.1.0-25.tar.gz                (-25 资产 API 声明 2924909，逐字节相符)
sha256 a824294057267471f8db9b300e60035b13fb269699bcde0b19f83f5800e925c1  runtime
sha256 648cbb33f6a9bcb68772b3b28e384888cc9ecb8d9be51b1c17b34c7e9fa0c330  source
```

**上游未发布 sha256**：`gh api …/releases --jq '.[0].body'` 全文只有一句
*"Pacman package archives and matching source snapshots. Install using https://denialwm.github.io/droidloom/install.sh. Older archives are retained…"*，
**无 checksums 文件、无签名**。⇒ 上面的 sha256 只是我们自己的记录基准，不能证明"未被篡改"。

解包：source → `build/droidloom/droidloom/`（720 条目 / 8.1 MiB）；runtime → `/var/tmp/droidloom-20261031/rt/`（628 条目，含 7 个 ELF）。

---

## 1. 上游构建真相（Q1）

### 1.1 是什么形态：**namespace 容器 cell，零 KVM/QEMU**（`已证`）

| 检查 | 命令 | 结果 |
|---|---|---|
| 虚拟化关键词 | `grep -rInE '/dev/kvm\|\bkvm\b\|qemu\|tcg\|virtio\|hypervisor' --include='*.md' --include='*.rs' --include='*.toml' --include='*.json' --include='*.py' --include='*.sh' --include='*.bp' --include='*.bzl' .`（在 source 树根） | **0 命中** |
| runtime 包依赖 | `cat rt/.PKGINFO` | `depend = droidloom-image=0.1.0-25 glibc gcc-libs mesa libdrm wayland libxkbcommon libpipewire pipewire systemd polkit util-linux e2fsprogs iproute2 nftables iptables android-tools` —— **无 qemu/libvirt/kvm 系依赖** |
| 架构形态 | `docs/architecture.md:5` | *"…namespaces, image mounts and networking"* |
| cgroup 委托 | `docs/architecture.md:730–743` | 记录过 `CLONE_NEWCGROUP` 后再建 legacy hierarchy `EPERM`；cell 子树建在调用者 cgroup 之下 ⇒ **典型容器实现** |

⇒ **结论：droidloom 不是 VM 型（不是 QEMU/KVM、不是 crosvm），是 `mount ns + pid ns + net ns + cgroup ns + 私有 binderfs` 的容器型**，
Android 直接跑在**宿主内核**上。这一条直接推翻〔可研〕里遗留的"KVM 依赖"疑问：**没有 KVM 门槛，也就不存在"TCG 降级跑"这条路径**（无需 TCG）。

### 1.2 语言与构建系统（`已证`）

| 层 | 事实 | 证据 |
|---|---|---|
| 宿主侧 | **Rust**，workspace **34** 个 crate，`edition 2024`，`rust-version 1.85`，工具链 pin **1.93.0**（`rust-toolchain.toml`） | `Cargo.toml`、`rust-toolchain.toml` |
| 打包 | `cargo run --locked -j 1 -p droidloom-package -- build` → 在 **rootless Podman 的 Arch 容器**里跑 `makepkg`（`packaging/arch/Containerfile`：`FROM docker.io/library/archlinux:base-devel`） | `docs/BUILDING.md:306–350` |
| Android 侧 | AOSP 17（`android-17.0.0_r1`）+ Soong/`Android.bp` 稀疏构建；不是 `repo sync` 全树 | `android/manifest/source-lock.json`、`android/README.md:1–20` |
| 产物 | `droidloom-runtime` + `droidloom-image` 两个 pacman 包 + 4 个 libalpm hook + 6 个 systemd unit（5 user + 1 system） | `rt/usr/lib/systemd/**`、`rt/usr/share/libalpm/hooks/*` |

### 1.3 x86_64 是**硬编码门**，不是文档偏好（`已证`，这是 Q1 最关键的一条）

```
packaging/arch/version.json:  "architecture": "x86_64"
packaging/arch/PKGBUILD.in:6: arch=(x86_64)
tools/droidloom-package/src/main.rs:120-123:
        || version.release == 0
        || version.architecture != "x86_64"
    {
        return Err("invalid package version or architecture".into());
tools/droidloom-package/src/components.rs:197:
        || !text.lines().any(|s| s == "arch = x86_64")
```

⇒ **`droidloom-package build` 在 aarch64 上会直接 `Err("invalid package version or architecture")`**，
不是"改了 version.json 就能编"，还有 `PKGBUILD.in` 的 `arch=(x86_64)` 和 components 基线校验里的字面量断言。
**但**：这 3 处都是**字符串常量级**改动（无 ABI/逻辑耦合），属"1 行 × 3 文件"量级的 fork。

### 1.4 ARM64 在上游的真实位置：**产品层存在且比 x86_64 更早、更完整；交付层为 0**（`已证`）

| 证据 | 内容 |
|---|---|
| `android/device/droidloom-arm64-product.json:3-5` | `"status": "base_compatibility_and_development_executor_proven_device_boot_pending"`，`"product": "droidloom_arm64"`, `"architecture": "arm64"` |
| 同文件 `:67–70`（x86_64 侧无对应字段） | `"still_required": ["ARM64 cell boot and live SurfaceFlinger-to-Denial presentation"]` |
| 同文件 `:41–66` | `"build_proven_modules"`（20 项）明确含 **ARM64** 的 `android.hardware.graphics.composer3-service.droidloom`、`mapper.minigbm`、`libgallium_dri`、`vulkan.freedreno` 等 20 项 |
| `android/manifest/source-lock.json` | `"architecture": "aarch64"`, `selected_at 2026-08-14`（**早于** x86_64 lock 的 2026-08-30） |
| `android/manifest/source-lock.json#aosp_ci_base` | = **官方 ARM64 Android CI 镜像**（`android/manifest/README.md:22–31`："`aosp_ci_base` is the official **ARM64** Android CI image used as the reusable framework/system base"，"Only the checksum-identified `system`, `system_ext`, and `product` logical partitions are eligible"） |
| `android/device/droidloom_x86_64-product.json:3` | `"status": "x86_64_vendor_product_implementation_pending_build_validation"` |

**⇒ ARM64 的"Android 侧"不是空中楼阁**：基础分区直接来自官方 ARM64 CI 镜像（有 checksum），Droidloom 自己的 vendor/HAL 组件
（Composer V5 / allocator V3 / mapper V5 / Mesa Freedreno / Turnip）**在 ARM64 上 Soong 编过并组装出真实稀疏 ext4 `vendor.img`**（`android/manifest/README.md:34–52`）。
**缺的只是**：① 宿主侧 aarch64 runtime 二进制与 aarch64 包的构建门（§1.3 三处硬编码 + 无 aarch64 宿主机构建文档）；
② `still_required` 那条 —— **ARM64 cell 的真实启动与 SurfaceFlinger→Denial 呈现从未在这块板上跑过**。

### 1.5 `droidloom-image-*.pkg.tar.zst`（≈0.94 GiB）里到底是什么（`已证`，静态可定，**不需要下载**）

| 证据 | 结论 |
|---|---|
| `tools/droidloom-image/src/lib.rs:22` | `const REUSABLE_PARTITIONS: [&str; 3] = ["system_a", "system_ext_a", "product_a"];` |
| `tools/droidloom-image/src/lib.rs:194` | 调 `unzip`/`simg2img`/`lpunpack`/`dump.erofs` ⇒ **解包 AOSP CI 的 lpunpack 分区镜像** |
| `tools/droidloom-image/src/lib.rs:225` | `verify_build_properties(&staging.join("images/system.img"), lock)` — 校验 `ro.*` 属性与 lock 一致 |
| `tools/droidloom-update/src/image_policy.rs:176–209` | `mkfs.erofs` 重建 `system_ext.img`，**只删 4 个 legacy VNDK APEX**（31–34），保留其余内容/属主/权限/xattr 并独立复验 |
| `packaging/arch/PKGBUILD.in:29–33` | `package_droidloom-image()` = `install-tree --source payload/image`（**纯文件树安装，无编译**） |

⇒ image 包 = **Android 17 的 system / system_ext / product 三个逻辑分区镜像（erofs/ext4）+ Droidloom 自建 vendor.img（稀疏 ext4）+ Mesa 26.1.7 的 ARM64/x86 Android 驱动**。
**不含**：Linux 内核、boot.img、initrd、任何虚拟机磁盘、任何 KVM 配置。⇒ 它**不是**能被 aarch64 复用的资产（分区镜像是 x86_64 ABI）；
aarch64 版必须由 `source-lock.json#aosp_ci_base`（ARM64 CI 镜像）重新组装，**这正是上游已经声明支持且 build-proven 的那条路径**。

### 1.6 `runtime` 包（6.2 MB）做什么（`已证`）

7 个 ELF（`x86-64` 全部，`file` 逐个核过；`droidloom-wayland` 7.3 MB 最大）：

| 二进制 | 角色（来自 unit 文件 + 源码目录） |
|---|---|
| `droidloomd` | system 级生命周期 daemon（`droidloomd.service`，`OOMPolicy=continue`，`RuntimeDirectory=droidloom`） |
| `droidloom-wayland` | **per-session Wayland presenter**（`Type=notify`，`ExecStartPost=droidloomctl start --cell`，`TimeoutStartSec=150`） |
| `droidloom-supervisor` | cell 进程树监管（namespace/cgroup 建立、PID 映射） |
| `droidloom-audio` | per-user PipeWire broker（`droidloom-audio.socket`） |
| `droidloom-applications` | 应用目录/启动服务（`droidloom-applications.service`） |
| `droidloomctl` | CLI（start/stop cell、launch app） |
| `droidloom-doctor` | 自检（`droidloom-doctor`） |
| `droidloom-package-helper` | `/usr/lib/droidloom/` 下的安装期辅助（libalpm hook 调用） |

依赖面（`.PKGINFO`）：`mesa libdrm wayland libxkbcommon libpipewire pipewire systemd polkit e2fsprogs iproute2 nftables iptables android-tools`。
⇒ **与 Waydroid 的差异点**：需要 `systemd`（含 user session + `graphical-session.target`）、`polkit`、`nftables`/`iptables`（cell 网络）、`android-tools`（adb 到 cell）。

---

## 2. aarch64 缺件清单（Q1 的产出物，也是 Q3 的输入）

分三类：`已具备`（有证据在位）/ `缺·我们改`（我们能单方面做）/ `缺·上游`（fork 也难，属契约级）。

| # | 件 | 状态 | 证据 / 具体缺什么 |
|---|---|---|---|
| A1 | Android 17 **ARM64 基础分区**（system/system_ext/product） | **已具备（可下载，未下）** | `android/manifest/source-lock.json#aosp_ci_base`：`aosp_cf_arm64_only_phone-userdebug` build `15885347`，`artifact_size 1101172766`（1.03 GiB），`artifact_sha256 7317b69…aabf`，URL `ci.android.com`；三个分区单独 checksum（`partitions.system_a=7f55209f…`） |
| A2 | **ARM64 vendor.img 的构建配方**（Composer V5 / allocator V3 / mapper V5 / Health / Power / audio / minigbm / Mesa Freedreno+Turnip） | **已具备（build-proven）** | `android/manifest/README.md:43–44`（"…succeeds and assembles a real sparse ext4 `vendor.img`"）+ `m2-sparse-source-lock.json.status = "build_proven"`；`android/device/droidloom-arm64-product.json:41–66` 的 `build_proven_modules` 共 **20** 项，含 ARM64 的 `composer3-service.droidloom`、`vulkan.freedreno` |
| A3 | **宿主侧 aarch64 runtime 二进制**（7 个） | **缺·我们改（Rust 原生编，aarch64 是代码里的一等枚举值）** | `unsafe_code = "forbid"`（workspace lints）；`runtime/droidloom-contracts/src/lib.rs:26–33`：`#[cfg(target_arch="aarch64")] pub const TARGET_ARCHITECTURE: Architecture = Architecture::Aarch64;` + `compile_error!("Droidloom supports only aarch64 and x86_64 hosts")`；`grep -rnE 'asm!\|__m128\|core::arch' --include='*.rs'` **0 命中** ⇒ 无内联汇编/无 x86 intrinsic；x86_64 相关命中全部是 AOSP lock 文件名与 `BoardConfig.mk` 断言 |
| A4 | **打包门 arch=x86_64 三处硬编码** | **缺·我们改（3 文件字面量）** | `packaging/arch/version.json`、`packaging/arch/PKGBUILD.in:6`、`tools/droidloom-package/src/main.rs:121`、`components.rs:197`（共 4 处，含 1 处测试断言） |
| A5 | **AOSP 稀疏源码 225 个项目** | **缺·要拉（体量未核实）** | `m2-sparse-source-lock.json` `projects` = **225** 条（含 `art`/`bionic`/`frameworks/base`/`build/make`），`remote_base https://android.googlesource.com/`，每个都是 superproject 精确 gitlink；`policy.allow_unrestricted_repo_sync = false` |
| A6 | **Mesa 26.1.7 的 ARM64 Android 侧驱动**（guest 里跑的 `libgallium_dri`/`libEGL_mesa`/`vulkan.freedreno`） | **缺·要编（配方有，交叉编译可做）** | `source-lock.json#mesa`：`https://archive.mesa3d.org/mesa-26.1.7.tar.xz` sha256 `25e0a669…`；`build_proven_modules` 已含这些产物名 ⇒ 上游已做过一次 ARM64 Android 交叉编译 |
| A7 | **宿主 aarch64 链接期依赖**（mesa/libdrm/wayland/libxkbcommon/libpipewire 的 aarch64 头+库） | **部分具备** | 主机有 `aarch64-linux-gnu-gcc`、`qemu-aarch64` binfmt（`/proc/sys/fs/binfmt_misc/qemu-aarch64` = enabled, `interpreter /usr/bin/qemu-aarch64`），但 `/usr/aarch64-linux-gnu/lib` 只有 glibc/gcc 交叉运行库，**没有任何 wayland/drm/gbm/xkbcommon/pipewire 的 aarch64 .so 或头**；设备侧这些库的**运行库**全在位（见 §4.1），但 `-dev` 头包全缺（见 A7b） |
| A7b | **设备侧编译前置：`-dev` 头包 + C 编译器** | **全缺（本轮实测）** | 设备上 `dpkg-query -W`：`libgbm-dev` **MISSING**、`libdrm-dev` **MISSING**、`libwayland-dev` **MISSING**、`libxkbcommon-dev` **MISSING**、`libpipewire-0.3-dev` **MISSING**、`build-essential` **MISSING**、`clang` **MISSING**；`pkg-config 2.5.1-4` 在，但 `--modversion gbm/libdrm/wayland-client/xkbcommon/libpipewire-0.3` **全部 not found**。⇒ M1 前必须 apt 装这 6 个包（`runtime/droidloom-audio/build.rs` 硬依赖 `pkg-config --cflags libpipewire-0.3` 并用 `cc` 编 `src/pipewire.c`） |
| A8 | `linux-drm-syncobj` 全局（presenter 硬需求） | **缺·合成器侧** | 本轮**实测**（见 §4.1 探针）：phoc 0.58.0 的 registry **无** `wp_linux_drm_syncobj_manager_v1` |
| A9 | **ARM64 cell 首次真实启动 + SurfaceFlinger→Denial 呈现** | **缺·无人做过** | `android/device/droidloom-arm64-product.json:67–70` `"still_required": ["ARM64 cell boot and live SurfaceFlinger-to-Denial presentation"]` |
| A10 | 相机/传感器/触觉 broker | **缺·上游** | 同〔可研〕§2.4/2.6/2.7（`android/hardware/README.md:7–8`） |
| A11 | 包格式：pacman `.pkg.tar.zst` → 设备 Debian | **缺·我们改（成本低）** | 设备 = **Debian forky/sid + systemd**（运行 `cat /etc/os-release` + `ps -p 1 -o comm=` 实测）；`/` 无 pacman。但 systemd unit **可直接用** ⇒ 只需把 payload 树摊到 `/opt/droidloom` + 自写 3 个 unit 的 `ExecStart` 前缀（**注意**：这也推翻了〔可研〕§3.3 的"Alpine+OpenRC 需重写 unit"——设备已迁到 Debian/systemd） |

---

## 3. 构建在哪做（Q3）

### 3.1 两条路径对比

| 维度 | **路径 A：设备原生编宿主二进制 + 主机交叉编 Android 镜像** | **路径 B：主机单点（Arch aarch64 容器 + qemu-user binfmt）** |
|---|---|---|
| 可行性证据 | 设备 = Debian/systemd、8 核、14 GiB RAM、73 GiB 空闲（实测）；Rust 纯用户态无 arch 耦合；主机 binfmt `qemu-aarch64` 已 enabled | 主机有 `qemu-aarch64` + `aarch64-linux-gnu-gcc`，但 **无 podman/docker**（`which podman docker` 空） |
| 首次投入 | 设备装 6 个 `-dev`/`build-essential`（实测全缺）+ rustup 1.93.0（`rust-toolchain.toml` 强制）+ `cargo fetch` 227 个 crate | 主机装 podman + 拉 `archlinux:base-devel` aarch64 镜像 + 在 qemu-user 下跑 rustup/makepkg |
| 编译耗时 | 8 核原生 ≈ 线性；79k LOC Rust + 227 crate | **qemu-user ≈ 5–20× 慢**（每进程一条 qemu 主循环，`-j8` 并行也只是 8 条慢循环） |
| 磁盘 | 设备：toolchain ~1 GiB + `target/` 2–4 GiB（73 GiB 够） | 主机：容器 + target 数 GiB（393 GiB 够） |
| 陷阱 | 会在设备上装包（**需用户在场**，本轮未做）；设备 cgroup 上还要跑 Android | `makepkg` 在 qemu-user 下的 `fakeroot`/`strip` 已知不稳；Arch aarch64 上 `mesa/libpipewire` 头齐（比 A7 干净） |
| 能否出 Android 镜像 | **不能**（设备 8 核/14 GiB 跑 Soong + Mesa 交叉编不现实） | **主机 x86_64 直接 cross 到 aarch64 是上游 proven 路径**（`build_proven` 即此），且**不需要 aarch64 容器**——AOSP 与 Mesa 都是"x86_64 宿主 → aarch64 目标"的交叉编 |
| 结论 | ✅ 宿主二进制走这条 | ❌ 不用（为省 sysroot 反而引入 qemu 10× 与 fakeroot 风险） |

**关键洞察（本轮的判断依据）**：droidloom 的构建天然是**两个不相干的世界**——
① **宿主二进制**（Rust，目标 = 你桌面那颗 CPU，需要的是**运行期 .so**，不是 AOSP）；
② **Android 镜像**（Soong+Mesa 交叉编译，目标 = guest ABI，上游明确是"x86_64 主机 cross 出 ARM64 产物"）。
把它们塞进同一条流水线（上游 `droidloom-package build` 就是）在 aarch64 上反而更麻烦。

### 3.2 推荐（按里程碑拆，互不阻塞）

```
M1（Day 1，零 AOSP、零 podman）：设备原生 cargo build --release 出 7 个 aarch64 ELF
        → 摊到 /opt/droidloom/{bin,share,systemd} → droidloom-doctor 自检
        → 在现有 phoc 会话里跑 droidloom-wayland，看它卡在哪个 global
M2（Day 1–2，仅主机）：同步 3 处 arch 硬编码补丁（可选：不改上游、只在本地脚本里替换）
M3（Day 2+，主机，重量级）：按上游文档在 x86_64 主机建 aarch64 Android 镜像
        = 下 1.03 GiB CI zip + 225 项目稀疏 sync + Soong 编 vendor + Mesa 交叉编
        → 产出 aarch64 `droidloom-image` payload（tar，不做 pacman 包）
M4（M1+M3 之后）：设备上装 image payload 到 /var/lib/droidloom/images/current，起 cell
```

**M1 是唯一"3 天内必达"的目标**，且**不需要任何下载**（除 rustup 与 crates）——因为它绕开了
`droidloom-package`（其 `Compile` 子命令要求已有 package baseline，`build` 子命令强制 x86_64 且要 AOSP）。
M1 的命令与判据见 §4.2。

## 4. 上机测试执行单（Q4）

> 前置状态：本轮对设备**只发过只读命令**（`cat`/`ls`/`nm`/`readelf`/`systemctl show`/`loginctl`/`wayland` 客户端探针），
> 未装包、未写文件、未 reboot、未 `strace -p`、未改 `/sys`。下面凡标 **【需用户在场】** 的步骤本轮都没做。

### 4.1 设备现状实测（本轮只读，`已证`）

| 项 | 实测值 | 命令 |
|---|---|---|
| 发行版 / init | **Debian GNU/Linux forky/sid**，PID1 = `systemd` | `cat /etc/os-release`；`ps -p 1 -o comm=` |
| 内核 | `7.3.0-rc7-debug-vk127-…-dirty-debug-vk172`（自建，`+` 无签名标记） | `uname -a` |
| CPU / RAM / 盘 | **8 核**，14 GiB RAM（avail 10），`/` = 94 G，**可用 73 G** | `nproc`、`free -g`、`df -h /` |
| 桌面 | **phoc 0.58.0 / phosh 0.58.0**（〔可研〕记的 0.55.1 已过期），Mesa **26.2.5** | `phoc --version`、`dpkg-query -W` |
| 会话 | `c1` = uid 1001，`seat0`，`tty`，`Active=yes`，`Remote=no` | `loginctl list-sessions`、`loginctl show-session c1` |
| `/dev/dri` | `card0`（`root:video` 0660+ACL）、`renderD128`（0666） | `ls -l /dev/dri` |
| `/dev/dma_heap` | `system`（`crwxrwxrwx`）**在** | `ls -l /dev/dma_heap/` |
| `/dev/kvm` | **不存在**，且 `# CONFIG_KVM is not set` | `ls /dev/kvm`；`zcat /proc/config.gz \| grep KVM` |
| `/dev/udmabuf` | **不存在**，`# CONFIG_UDMABUF is not set`；**droidloom 不需要它**（源码里 0 处引用） | `grep -rhoE '"/dev/…"' --include='*.rs'` 全量清单里无 udmabuf |
| `/dev/fuse` | 在，`fuse` 模块已加载 | `ls -l /dev/fuse`、`lsmod` |
| cgroup | **unified v2**；`user@1001` 已 `Delegate=yes`，`DelegateControllers=cpu memory pids`；user slice 子树可控 `cpu memory pids` | `cat /sys/fs/cgroup/user.slice/user-1001.slice/cgroup.{controllers,subtree_control}`、`systemctl show user@1001.service -p Delegate*` |
| binderfs | 宿主 `/dev/binderfs` 已挂（Waydroid 的 `binder/hwbinder/vndbinder` + `anbox-*`）；`CONFIG_ANDROID_BINDERFS=y` | `ls -l /dev/binder*` |
| 内核 Android 件 | `USER_NS=y PSI=y MEMCG=y CGROUP_PIDS=y CGROUP_FREEZER=y DMABUF_HEAPS=y EROFS_FS=y FUSE_FS=m SYNC_FILE=y` | `zcat /proc/config.gz` 逐项 |
| Waydroid | `waydroid-container` **active**；`arch=arm64_only`，`vendor_type=MAINLINE`，`binder_protocol=aidl3` | `systemctl is-active waydroid-container`、`cat /var/lib/waydroid/waydroid.cfg` |
| 宿主依赖（runtime `.PKGINFO` 要求） | `pipewire 1.6.9` `wireplumber 0.5.18` `polkitd 128` `nftables 1.1.7` `iptables 1.8.13` `libdrm2 2.4.134` `libxkbcommon0 1.13.1` `adb 1.0.41(34.0.5)` `e2fsck/mkfs.ext4` 全在 | `dpkg-query -W` |
| 缺的宿主工具 | `mkfs.erofs`/`fsck.erofs`/`simg2img`/`lpunpack`/`dump.erofs` **全无**（只在建/装镜像时需要，`erofs-utils` + `android-sdk-libsparse-utils` 可解）；`rustc`/`cargo`/`podman` **全无** | `which` 批量 |
| 网络到 rustup CDN | `HTTP 200`（`static.rust-lang.org/dist/channel-rust-1.93.0.toml`） | `curl -s -o /dev/null -w %{http_code}` |
| **合成器全局（决定性）** | phoc 0.58.0 registry **无 `wp_linux_drm_syncobj_manager_v1`**；有 `xdg_wm_base v6`、`zwp_linux_dmabuf_v1 v5`、`wp_fractional_scale_manager_v1 v1`、`zwp_text_input_manager_v3 v2` | 见下方探针命令与输出 |

**syncobj 探针（本轮新做的实测，替换〔可研〕§L1 的旧结论）**：设备上没有 `wayland-info`/`weston-info`，改用「任意 Wayland 客户端 + `WAYLAND_DEBUG=1`」抓 registry：

```console
ssh root@192.168.7.1 'su - xuqianhui1001 -c "XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
  WAYLAND_DEBUG=1 grim /dev/null" 2>&1 \
  | grep -E "wl_registry.*global" \
  | sed -E "s/.*global\(([0-9]+), \"([a-z0-9_]+)\", ([0-9]+)\).*/\2 v\3/" | sort -u'
```

输出核对（本轮复跑，`sort -u` 后共 **56** 条全局；`grep -c syncobj` = **0**）：
```
$ … | sort -u | wc -l                    → 56
$ … | grep -c syncobj                    → 0
$ … | grep -E 'linux_drm|dmabuf|xdg_wm_base|fractional_scale_manager|output_power'
wp_fractional_scale_manager_v1 v1
xdg_wm_base v6
zwlr_export_dmabuf_manager_v1 v1
zwlr_output_power_manager_v1 v1
zwp_linux_dmabuf_v1 v5
```
（字母序上 `wp_linux_drm_syncobj_manager_v1` 应落在 `wp_fractional_scale_manager_v1` 与 `wp_presentation` 之间，**该位置为空**）
⇒ **G-B 门槛在 phoc 0.58.0 上仍未过**（与〔可研〕对 0.55.1 的静态判读一致，本轮由**运行期 registry** 直接证实）。

**presenter 硬 bind 的全局逐项核对**（`graphics/droidloom-wayland/src/main.rs:3104–3117` 全是无 fallback 的 `globals.bind(...)?`）：

| 代码行 | 需求 | phoc 0.58.0 registry 实测 | 结论 |
|---|---|---|---|
| `3104` `CompositorState::bind` | `wl_compositor` | 在（`grim` 能截图即证明） | ✓ |
| `3105` `XdgShell::bind` | `xdg_wm_base` | **v6** | ✓ |
| `3106` `WpViewporter` | `wp_viewporter` v1 | **v1** | ✓ |
| `3107` `WpFractionalScaleManagerV1` | `wp_fractional_scale_manager_v1` v1 | **v1** | ✓ |
| `3108–3112` `DmabufState` + `version() >= 4` | `zwp_linux_dmabuf_v1` ≥4 | **v5** | ✓ |
| `3113` `WpLinuxDrmSyncobjManagerV1` | `wp_linux_drm_syncobj_manager_v1` v1 | **缺失** | **✗ 唯一卡点** |
| `3114` `ZwlrOutputPowerManagerV1` | `zwlr_output_power_manager_v1` | **v1** | ✓ |
| `3121` `activation::Activation::new` | `xdg_activation_v1` | **v1** | ✓ |
| `3123` `shm` / `subcompositor` | `wl_shm` / `wl_subcompositor` | 在 | ✓ |

⇒ **除 syncobj 外的 7 项全部实测在位**，这就是"M1-e 的失败点可精确定位"的依据：不是猜，是逐项 registry 对表。

### 4.2 装在哪（M1 方案，**不动 Waydroid、不动 phoc、不动 boot**）

**隔离设计**：
- 代码与二进制落在 `/opt/droidloom/`（新建，`/opt` 现为空）；**不装进 `/usr`、不建 pacman 库、不装 `.pkg.tar.zst`**。
- 编译在 `xuqianhui1001`（uid 1001，已在）家里做，产物 hardlink 到 `/opt/droidloom/bin`。
- **M1 只跑 presenter（`droidloom-wayland`）+ doctor，不跑 `droidloomd`、不 `droidloomctl start --cell`**
  ⇒ 本轮方案里**没有任何 nftables/网络/cgroup/binderfs 写入**，这是刻意设计的安全边界：presenter 是**纯 Wayland 客户端**。
- 证据：`runtime/droidloom-supervisor/src/lib.rs:829–836`（`spec_rejects_card_nodes_and_host_uid_aliasing`）
  明确**拒绝 `render_node = "/dev/dri/card0"`**，只接受 render node ⇒ presenter 不需要 DRM master/KMS/seat 独占，
  可与 phoc 会话并存（同一 seat，作为普通 xdg_toplevel 客户端）。

#### 步骤 M1-a：把源码送上设备（`已证` 可做：rsync 已装？未核实 ⇒ 用 tar over ssh 兜底）

```console
# 主机侧，产物已在 build/droidloom/；不下载任何新东西
tar czf /var/tmp/droidloom-20261031/source-tree.tgz -C build/droidloom droidloom
timeout 600 ssh root@192.168.7.1 'mkdir -p /var/tmp/droidloom && tar xzf - -C /var/tmp/droidloom' \
  < /var/tmp/droidloom-20261031/source-tree.tgz
timeout 30 ssh root@192.168.7.1 'chown -R 1001:1001 /var/tmp/droidloom/droidloom && du -sh /var/tmp/droidloom'
```
【需用户在场】（写设备盘 ~8 MiB，无风险，但按纪律由用户点一次头）

#### 步骤 M1-b：装编译前置 + Rust 1.93.0（`已证`：CDN 可达、`/` 有 73 GiB）
【需用户在场】（apt 装包 + 装工具链；`-dev` 与头文件约 **未核实 40–80 MB**，rustup minimal 约 **未核实 150–250 MB**）

```console
# b1 编译前置（本轮实测这 6 个全部缺失，见 §2 A7b）
timeout 900 ssh root@192.168.7.1 'DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential pkg-config libpipewire-0.3-dev libwayland-dev libdrm-dev libgbm-dev libxkbcommon-dev'
timeout 60 ssh root@192.168.7.1 'for m in gbm libdrm wayland-client xkbcommon libpipewire-0.3; do \
  printf "%-18s" $m; pkg-config --modversion $m; done'
# 期望：每行都有版本号（gbm 26.x / libdrm 2.4.134 / wayland-client 1.26 / xkbcommon 1.13.1 / libpipewire-0.3 1.6.9）

# b2 Rust（rust-toolchain.toml pin 1.93.0）
timeout 1800 ssh root@192.168.7.1 'su - xuqianhui1001 -c \
  "curl -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal --default-toolchain 1.93.0"'
timeout 60 ssh root@192.168.7.1 'su - xuqianhui1001 -c "~/.cargo/bin/rustc -V && ~/.cargo/bin/cargo -V"'
# 期望：rustc 1.93.0 / cargo 1.93.0
```

**判据（二值）M1-b**：`pkg-config --modversion libpipewire-0.3` 有输出 **且** `rustc -V` = 1.93.0。

#### 步骤 M1-c：编 7 个 aarch64 二进制（本计划的**第一个真产物**）

```console
timeout 3600 ssh root@192.168.7.1 'su - xuqianhui1001 -c "cd /var/tmp/droidloom/droidloom && \
  ~/.cargo/bin/cargo build --locked --release -j 6 \
    -p droidloom-supervisor -p droidloom-wayland -p droidloom-audio \
    -p droidloom-applications -p droidloom-doctor"'
# 期望产物（对应 runtime 包 usr/bin/*）：
#   target/release/{droidloom-supervisor,droidloomctl,droidloomd,droidloom-wayland,
#                   droidloom-audio,droidloom-applications,droidloom-doctor}
timeout 60 ssh root@192.168.7.1 'cd /var/tmp/droidloom/droidloom/target/release && \
  ls -l droidloom* | head; file droidloom-wayland'
```
`-j 6`（保留 2 核给交互，符合项目构建纪律）。**耗时未核实**，估 10–25 min（8 核、227 crate、79k LOC）。

**判据（二值）M1-c**：`file target/release/droidloom-wayland` 输出含 `ELF 64-bit LSB …, ARM aarch64` 且 7 个二进制全部存在。

#### 步骤 M1-d：摊到 `/opt/droidloom` 并跑 doctor
【需用户在场】

```console
timeout 120 ssh root@192.168.7.1 'set -e; mkdir -p /opt/droidloom/{bin,share,systemd} && \
  cp /var/tmp/droidloom/droidloom/target/release/droidloom* /opt/droidloom/bin/ && \
  cp /var/tmp/droidloom/droidloom/packaging/cell-spec-arm64.json /opt/droidloom/share/cell-template.json && \
  chmod 755 /opt/droidloom/bin/*'
timeout 120 ssh root@192.168.7.1 '/opt/droidloom/bin/droidloom-doctor --help 2>&1 | head -30'
```
**判据（二值）M1-d**：`droidloom-doctor` 能打印帮助并退出 0（证明 aarch64 二进制在本机 glibc/依赖下能装载运行）。

#### 步骤 M1-e：presenter 首跑（**关键判据所在**）

```console
# 以会话用户跑，连到 phoc 的 wayland-0；不装 unit、不 systemctl
timeout 120 ssh root@192.168.7.1 'su - xuqianhui1001 -c \
  "XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
   RUST_BACKTRACE=1 /opt/droidloom/bin/droidloom-wayland; echo EXIT=\$?"' 2>&1 | tail -30
```
**预期输出（`未上机`，预测）**：退出非 0，日志含 `wp_linux_drm_syncobj_manager_v1`（来自
`graphics/droidloom-wayland/src/main.rs:3113` `globals.bind(&qh, 1..=1, ())?` 的绑定失败）⇒ **M1 的"负面判据"成立 = G-B 是唯一卡点**。
若它**竟然起来**（说明 0.58.0 有别的绑定路径），则直接进 M1-f。

**判据（二值）M1-e**：`EXIT != 0` 且日志含 `syncobj` ⇒ 记录为 **M1 通过（证明链路正确、缺件定位唯一）**；
`EXIT == 0` ⇒ 出现 `xdg_toplevel` 窗口 ⇒ 记录为 **M1 超预期通过**，进 M1-f。

#### 步骤 M1-f（仅当 M1-e 起得来）：presenter 出窗口
```console
# 另一个 shell 观察：只要有 toplevel 就说明 xdg-shell + dmabuf 通路成立
timeout 60 ssh root@192.168.7.1 'su - xuqianhui1001 -c \
  "XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 grim -g \"0,0 200x200\" /tmp/probe.png"'
```
【需用户在场】读取屏幕内容（一张 200×200 截图，不进仓库）。

### 4.3 M4（cell 启动）需要什么 —— 全部标 `需用户在场` / 依赖 M3 产物

| 需求 | 现状 | 动作 |
|---|---|---|
| Android 镜像（aarch64） | **无** | 必须先做完 M3（§3.2），产物解到 `/var/lib/droidloom/images/current` |
| `droidloomd`（root）建 cell | 需 root + mount/ns 权限 | `systemctl start droidloomd`（或直接跑二进制）；会挂**私有 binderfs 到 cell 内 `/dev/binderfs`**（`linux_plan.rs:735,799`、`development.rs:1823`），与宿主 Waydroid 的 `/dev/binderfs` **不冲突**（不同 mount ns） |
| cell 网络 | `nftables 1.1.7` + `iptables 1.8.13` 在位；droidloom 用私有 netns + 主机侧 nft 规则 | **高风险**：会在宿主 nft 表里插规则 ⇒ 建议先在 `nft list ruleset > /var/tmp/nft-before.txt` 备份，回退 `nft -f /var/tmp/nft-before.txt` |
| cgroup 委派 | `cpu memory pids` 已委派给 user@1001 ✓ | 无 |
| 图形 | `renderD128` ✓、`/dev/dma_heap/system` ✓、**`wp_linux_drm_syncobj_manager_v1` ✗** | **A8 必须先解**：给 phoc 补一次 global（〔可研〕§3.1 路线 A）或换合成器 |
| 音频 | pipewire 1.6.9 + wireplumber 0.5.18 ✓；droidloom 需 `droidloom-audio.socket`（user unit） | 装 unit 时改 `ExecStart` 指向 `/opt/droidloom/bin/*` |
| 输入 | 宿主 evdev 由 phoc 独占；presenter 作为客户端收 Wayland 输入 | `/dev/input` 在 cell 内是空 tmpfs（`/dev/input` 出现在代码里 3 次，均在白名单/投影逻辑），**不需额外权限** |
| gatekeeper / PI | 宿主无 Android SELinux；`threat-model-v2.md` 自陈不主张 PI | 无动作；**不预期改善** |

### 4.4 与 Waydroid / phoc 的冲突点（逐项，`已证` + 判读）

| 面 | 冲突 | 判据/处置 |
|---|---|---|
| 显示 | **无 DRM master 冲突**（presenter 只用 render node；`card0` 被 spec 明确拒绝） | 但**缺 syncobj 全局** ⇒ 现在必然起不来（4.1 实测） |
| binderfs | 宿主 `/dev/binderfs` 被 Waydroid 占用（`binder/hwbinder/vndbinder/anbox-*`）；droidloom 在**自己的 mount ns 里挂新实例** | 不冲突；验证判据 = cell 内 `ls /dev/binderfs` 恰好 3 个设备 |
| 网络 | droidloom 用私有 netns + 宿主 nft 规则；Waydroid 用 LXC 的 `lxc.net` + `waydroid-ipv6` | **潜在冲突在 nft 表**（都往宿主 `ip`/`inet` 表插规则）；判据 = 起 cell 前后 `nft list ruleset` diff 只增 droidloom 自己的链 |
| 音频 | droidloom 用 per-user PipeWire broker（application-buffer API，4×sealed memfd，PCM16/48k）；Waydroid 走 PulseAudio 兼容层 | **同一声卡两个客户端**：不冲突（都是 PipeWire client），但需 `wireplumber` 正常；判据 = `pw-top` 里出现 droidloom sink-input |
| `/dev/dma_heap` | 两者都要 `system` heap；`cma_heap` **两边都别加载**（`PITFALLS #130`） | 已满足（只有 `system`） |
| cgroup | Waydroid LXC 自建 cgroup；droidloom 在 user-1001 子树下再开 namespace | 已委派 `cpu memory pids` ⇒ 两套可并存；**未上机验证** |
| 磁盘 | 两边各 ~1 GiB 镜像 + data | 73 GiB 够 |

### 4.5 三个二值判据（M4 的验收，全部 `未上机`）

| # | 判据 | 命令 | 通过 = | 不过 = |
|---|---|---|---|---|
| C-1 | **能起窗口**：`com.android.settings` 成为宿主 `xdg_toplevel` | 起 cell 后 `droidloomctl launch com.android.settings`；另开 `WAYLAND_DEBUG=1 grim …` 或在 phoc 会话里看窗口列表（`zwlr_foreign_toplevel_manager_v1` 已在 registry，可用任意客户端枚举标题） | 出现标题含 `Settings` 的 toplevel 且非 0 尺寸 | 无 toplevel ⇒ 取 `journalctl -u droidloomd -n 200` + `droidloom-wayland` stderr |
| C-2 | **能跑一个 APK**：装并启动一个自备 arm64 APK（不走 Play） | `adb -s droidloom-… install x.apk`（cell 内 adb 端口由 supervisor 暴露，`android-tools 1.0.41` 已在）→ `droidloomctl launch <pkg>/<act>` | `adb shell pidof <pkg>` 非空 且窗口出现 | 有 pid 无窗口 = 呈现链路问题（syncobj/fence）；无 pid = ART/zygote 问题 |
| C-3 | **`logcat` 关键行**：`SurfaceFlinger` 起来且 Composer 走 droidloom 服务 | `adb logcat -d \| grep -E "SurfaceFlinger\|droidloom"` | 出现 `droidloom` composer service 绑定成功 + 无 `Failed to import`/`fence timeout` | 出现 `waitForever`/`fence` 超时 ⇒ 对应〔可研〕§2.2 的 GPU 恢复风险 |

### 4.6 回退（进程级 + 系统级）

| 级 | 触发 | 动作（全部可逆、不留痕） |
|---|---|---|
| P1 进程级 | presenter 卡住/黑屏/占满 CPU | `pgrep -x droidloom-wayland` → `kill <pid>`（**用 `-x` 精确名，避免 `pkill -f` 自杀**）；`droidloomctl stop --cell` |
| P2 进程级 | cell 起来后网络异常 | `droidloomctl stop --cell`；`nft list ruleset > after.txt`；若宿主网络仍异常 → `nft -f /var/tmp/nft-before.txt`（起 cell 前必须先存） |
| P3 会话级 | presenter 把 phoc 拖崩（理论上不会：纯客户端） | phoc 崩溃会自动重启会话；`loginctl terminate-session c1` 后重新登录 |
| S1 系统级 | 任何不可解释的异常 | **删 `/opt/droidloom` + `~1001/.rustup`、`~1001/.cargo`** 即完全回到今天状态（M1 不写 `/usr`、不写 boot、不建 systemd unit） |
| S2 系统级 | Waydroid 被影响 | `systemctl restart waydroid-container`（本轮不改其任何文件） |
| 禁止 | — | **不 reboot、不 fastboot、不 `qbootctl`、不写 `/sys`**（本轮计划里没有任何一步需要） |

---

## 5. 成本与排期（Q5）

### 5.1 数字账（`已核实` / `未核实` 分列）

| 项 | 数字 | 证据 |
|---|---|---|
| 本轮已下载 | **9 161 800 B（8.74 MiB）** | §0.2 sha256 与体积 |
| 上游 release 0.94 GiB image | **1 008 393 914 B** | `gh api releases` |
| aarch64 对应 CI 基础包 | **1 101 172 766 B（1.03 GiB）** `已核实`（HTTP HEAD 现测 `content-length: 1101172766`，与 lock 声明逐字节一致） | `curl -sI -L <ci.android.com…zip>` |
| Mesa 26.1.7 源码包 | **77 799 016 B（74.2 MiB）** `已核实`（HEAD） | `curl -sI https://archive.mesa3d.org/mesa-26.1.7.tar.xz` |
| AOSP 稀疏源码 225 项目 | **未核实**（估 8–25 GiB git 数据；`frameworks/base`/`art`/`bionic` 是大头） | 只能估算：lock 只给 gitlink，不给体积 |
| Soong `vendor` 构建 out | **未核实**（上游只说整机 build 峰值 **120 GiB**） | `docs/BUILDING.md:314–317` |
| rustup 1.93 minimal（设备） | **未核实**（估 150–250 MiB） | CDN 可达已测（HTTP 200） |
| crates.io 依赖（227 包） | **未核实**（估 60–150 MiB） | `Cargo.lock` 227 个 `[[package]]` |
| 主机磁盘 | 393 GiB 可用 | `df -h /` |
| 设备磁盘 | 73 GiB 可用 | `df -h /` |

**⚠ 额度**：M3 的下载（1.03 GiB + 74 MiB + 225 项目 ≥8 GiB）**必然突破本轮 3 GiB 会话上限** ⇒ 按纪律**不由本轮执行**，写进计划待父审批。

### 5.2 排期（3 天窗口，逐日可验收）

| 日 | 内容 | 谁做 | 产出（可验收） | 风险 |
|---|---|---|---|---|
| **D1 上午** | M1-a/b：源码上机 + `apt install build-essential libpipewire-0.3-dev libwayland-dev libdrm-dev libgbm-dev libxkbcommon-dev` + rustup 1.93 | **需用户在场**（装包 + 写设备） | `rustc 1.93.0`；`pkg-config --modversion libpipewire-0.3` 有输出 | 低（只加头文件/`-dev`，不替换系统运行库） |
| **D1 下午** | M1-c/d/e：编 7 个 aarch64 ELF → `/opt/droidloom` → doctor → presenter 首跑 | 代理（只读+自建目录） | **第一个可上机产物**：aarch64 runtime 目录树 + presenter 首跑日志 | 编译失败（`cc`/`pkg-config` 链接问题、`libwayland 1.26` 符号变动 —— U12）；**不是**缺 `-dev`（D1 上午已装） |
| **D2** | M2：`phoc` 补 `wp_linux_drm_syncobj_manager_v1` 全局（Debian 侧要 `apt-get source phoc` + 补丁 + 重编） | **需用户在场**（装 `-dev` 包/编 phoc） | 新 phoc 二进制在 `/opt`，**不改系统 phoc**；registry 出现该全局 | wlroots 版本/ABI 对齐；msm DRM 显式同步行为未知（〔可研〕E1） |
| **D3** | M3 起步：下载 CI zip + 225 项目 sync（长跑，可中断续传） | 代理（需父审批额度） | 源码树就绪 + `droidloom-update` 能校验 base 分区 checksum | 下载/同步是**唯一大块机器时间**，D3 结束**预期只能到"sync 完成"**，到不了 Soong 编译完 |

**结论：3 天内能出「可上机的 aarch64 runtime 目录 + presenter 真实启动日志」，出不了「cell 启动」**。
瓶颈排序（同一正反判断，只做一次）：

1. **A5 + Soong（机器时间，最硬）** —— 225 项目 + AOSP/Soong + Mesa 交叉编，上游自述整机 120 GiB 峰值；
   D3 一天**不可能**从零到 aarch64 `vendor.img`。
2. **A8 syncobj 全局（合成器改动，1–2 天，且是"我们单方面可解"的唯一项）** —— 不解决，presenter 连窗口都开不了，
   所有后续上机判据都无从谈起。
3. **A9 ARM64 cell 从未启动过（未知调试量）** —— 上游自己把这句写进 `still_required`；这不是"编译能过就行"的问题。
4. Mesa 26.1.7 ARM64 Android 侧交叉编（配方有、上游做过，属"照做"级）。

### 5.3 谁做 / 边界

- **D1 的编译与探针**：代理可全权做（只写 `/opt/droidloom`、`/var/tmp`）；**装 rustup / 装 `-dev` 包 / 编 phoc 需用户在场点头**。
- **D3 的下载**：需父审批额度（>3 GiB）。
- **不做**：换桌面、改 boot、改 Waydroid 镜像、往 `/usr` 装包、git 提交、上游提 PR/issue。

---

## 6. 未证实项（不得当结论使用）

| # | 项 | 状态 | 消除方式 |
|---|---|---|---|
| U1 | 设备缺哪些 `-dev` 头包 | **已证实（本轮）**：`libgbm-dev`/`libdrm-dev`/`libwayland-dev`/`libxkbcommon-dev`/`libpipewire-0.3-dev`/`build-essential` **全部 MISSING**；`pkg-config` 在但所有 module not found | 已消除；转为 M1-b 的一个 apt 步骤 |
| U2 | 7 个 Rust 二进制能否在 aarch64 上**零改动**编过 | **未证实**（无 asm、有 `Architecture::Aarch64` 枚举 ⇒ 预期能过） | M1-c |
| U3 | 编译时长（8 核 227 crate） | **未证实**（估 10–25 min） | M1-c 的 `time` |
| U4 | 225 个 AOSP 项目的 git 体积 | **未证实**（估 8–25 GiB） | M3 第一步 `droidloom-source` 边拉边记 |
| U5 | `phoc 0.58.0` 内嵌 wlroots 是否**已有** syncobj 实现（只差 create 调用） | **部分证实**：`strings /usr/bin/phoc \| grep -c linux_drm_syncobj` = **11**（实现字符串在）；`readelf -rW` 里的 syncobj 重定位全是 `drmSyncobj*`（libdrm），**没有** `wlr_linux_drm_syncobj_manager_v1_create` 的调用证据 | D2 读 phoc 0.58 源码 |
| U6 | msm DRM 上启用显式同步后的行为（卡帧/fence 死等） | **未证实** | D2 后 M1-e 复跑 |
| U7 | ARM64 cell 首次启动的失败签名 | **未证实**（上游只写 `still_required`） | M4 |
| U8 | droidloom 的 nft 规则与 Waydroid LXC 规则是否真的共存 | **未证实** | M4 前 `nft list ruleset` 基线 + 起 cell 后 diff |
| U9 | `droidloom-audio` 在 pipewire 1.6.9 上是否需要 Arch 特有 API（`.PKGINFO` 只写 `libpipewire`/`pipewire`） | **未证实** | M1-c 链接期即知 |
| U10 | Denial 的 aarch64 构建（presenter 的**替代**后端 `droidloom-denial-*` 是否必需） | **未证实**：presenter 是独立 Wayland 客户端（`graphics/droidloom-wayland`），Denial 只是 Composer 的 IPC 对端之一；M1 不需要 Denial | M1-e 若报 denial 缺失则再查 |
| U11 | `droidloom-image` 包在我们手上的**真实**文件清单（未下载，靠源码静态定死） | **静态已证**（§1.5），**未用包内容核对** | 若要核对：1.0 GiB 下载（本轮判断**不需要**，理由见 #0） |
| U12 | `libwayland 1.26` 移除了 `wl_display_get_registry` 导出（本轮实测：`nm -D` 无该符号）是否影响 phoc/presenter 所用 crate 的 ABI | **未证实** | M1-c 链接/运行期即知（Rust `wayland-client 0.31.14` 可能走 `wl_proxy_marshal_flags` 而非该符号） |

### 6.1 下载决策：0.94 GiB 的 `droidloom-image-*-x86_64` **不下**（本轮结论）

| 理由 | 证据 |
|---|---|
| 它是 **x86_64 ABI** 的 Android 分区镜像（system/system_ext/product 来自 `aosp_cf_x86_64_only_phone`，vendor.img 由 x86_64 Soong 编） | `source-lock-x86_64.json#aosp_ci_base.target = aosp_cf_x86_64_only_phone-userdebug`；`cpu_abi = x86_64` |
| 对 aarch64 目标**零复用价值**（分区镜像不可跨 ABI） | `droidloom-arm64-product.json` 用的是 `source-lock.json`（`cpu_abi = arm64-v8a`） |
| 它的**内容构成**已由源码唯一确定（3 个复用分区 + 自建 vendor.img + Mesa 驱动 + 4 个 VNDK APEX 被删） | §1.5 的 5 条 `lib.rs`/`image_policy.rs`/`PKGBUILD.in` 行号 |
| 下它只能验证"包结构"，而包结构已由 `PKGBUILD.in:29–33`（纯 `install-tree`）确定 | 同上 |

⇒ **省下 1 GiB 额度**，留给 M3 真正需要的 aarch64 CI zip（1.03 GiB）。

### 6.2 本轮边界（做了什么 / 没做什么）

- **做**：下载并解包 `source`（2 924 909 B）+ `runtime`（6 236 891 B）两个小资产并记 sha256；静态读源码（构建入口、ci lock、product json、image 组装、device spec、presenter 全局绑定）；设备侧只读侦察 6 批（系统/内核/cgroup/设备节点/包/Wayland registry 探针）；主机侧工具链侦察（cross gcc、qemu binfmt、podman）。
- **没做**：0.94 GiB image 下载（**0 B**，理由见 §6.1）；设备写操作（**0 次**：无 apt、无 `mkdir`、无 reboot/fastboot、无 `strace -p`、无改 `/sys`）；任何编译（**0 次**，M1-c 未执行）；SSOT 改动（`TASKS/INDEX/PITFALLS/DEVICE/AGENTS/versions` **0 处**）；git 提交（**无**）；上游 issue/邮件（**无**）；设备上任何持久文件（探针脚本用 `cat > /tmp/.wlprobe.py` 后**同一条命令内 `rm -f`**，registry 探针只用 `WAYLAND_DEBUG` 输出）。
- **唯一写入（项目内）**：本文件 `reports/droidloom-build-device-plan-20261031.md`；**唯一写入（项目外）**：`/var/tmp/droidloom-20261031/`（8.74 MiB 资产 + 解包 runtime 树 31 MiB）、`build/droidloom/droidloom/`（解包 source 树 8.1 MiB）。
DONE: reports/droidloom-build-device-plan-20261031.md 47715
