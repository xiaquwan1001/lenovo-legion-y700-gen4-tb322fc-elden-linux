# 2026-11-08 · droidloom 可行性专项（复核 + 在线增量）

- **派工**：droidloom 可行性专项 —— 上游最新形态、四门槛、namespace cell 复核、GMS/PI/Widevine 口径、本机前置、隔离试验与退出条件。
- **产物**：`reports/droidloom-feasibility-20261108.md`
- **时间盒**：本轮 ≈ 45 min（≤110 min 预算内）
- **证据级别**：本书全部标 **实测 / 静态 / 推断**；共 **实测** 项以命令输出为准，**静态** 项以源码/配置/包内文件为准。
- **纪律**：零设备动作（`ssh` 一条未发）、零装包、零构建、零下载 >1 GiB、未改 SSOT。
  本轮下载合计：`droidloom-runtime-0.1.0-30-aarch64.pkg.tar.zst` 6 598 150 B +
  `phoc_0.58.0.orig.tar.xz` 842 960 B ≈ **7.1 MiB**；image 包（0.90 GiB）**未下**（只 `-r 0-0` 探可达性，HTTP 206）。

---

## 1. 结论（一句话 + 三个二值判断）

**只跟踪（不立项）** —— 上游已把「aarch64 无发布包」补上，但对 G2 硬验收（PI/Widevine + 相机/传感器/触觉）无净增益，
落地仍压着三件"我们自己能干的小事"：合成器一行 global、内核 `nf_tables` 一档配置、pacman 包的装法。

| # | 问题 | 判定 | 级别 |
|---|---|---|---|
| J1 | aarch64 有没有官方发布包 | **有**（0.1.0-27 起，2026-10-31；最新 -30，2026-11-05）| 实测 |
| J2 | phoc 0.58.0 是否满足 `linux-drm-syncobj` 硬需求 | **否**（缺一行 `wlr_linux_drm_syncobj_manager_v1_create`）| 静态 + 10-31 设备 registry 实测 |
| J3 | 是否仍是 namespace cell（非 VM） | **是**（kvm/qemu/virtio 全树 0 命中，双向核对）| 静态 |

五维（droidloom 形态）：可用性 **1/5**、图形 **2/5**、输入 **2/5**、音频 **3/5**、身份/完整性 **0/5**。

## 2. 本轮新增的硬事实（相对 2026-10-30 两份基线）

1. **aarch64 交付翻转**：`packages` release 41 资产，修订 27/28/29/30 各含 aarch64 `image`+`runtime`；
   `image-30-aarch64` 964 196 458 B（0.90 GiB）、`runtime-30-aarch64` 6 598 150 B。`INSTALL.md` 首段已写
   x86_64 + aarch64 Arch Linux ARM 双支持；`BUILDING.md` 有 `--architecture aarch64 --sysroot` 交叉流程。
   ⇒ 〔可研〕判决 1/2/4 与 E2 中"0 个 aarch64 资产""aarch64 自建不做"全部过期。
2. **runtime 包是 glibc + systemd + pacman**：`.PKGINFO` `arch = aarch64`，依赖
   `glibc gcc-libs mesa libdrm wayland libxkbcommon libpipewire pipewire systemd polkit util-linux e2fsprogs iproute2 nftables iptables android-tools`；
   7 个 ELF，`interpreter /lib/ld-linux-aarch64.so.1`。设备是 Debian forky/sid + systemd（10-31 实测）⇒ **ABI 对得上，只需摊装/转包**。
3. **合成器缺口的量级被钉死**：phoc 0.58.0（Debian sid 源码）全树 **无** syncobj；内嵌 wlroots 0.20.x
   有 `wlr_linux_drm_syncobj_manager_v1_create(display, version, drm_fd)`，内部先检 `DRM_IOCTL_SYNCOBJ_EVENTFD`。
   phoc 的 `desktop.c`/`server.c` 已有 `wlr_display`、`wlr_backend`、`wlr_renderer` 与 `-DWLR_USE_UNSTABLE` ⇒ **一行可补**。
4. **mutter 早已支持**该协议（NEWS 46.1 *"Implement linux-drm-syncobj-v1"*，main 51.1 里 `meta_wayland_drm_syncobj_init`），
   〔可研〕"Mutter 不满足"是**对 Phosh/phoc 的误记到 Mutter 头上**。
5. **新发现的内核缺口（旧文档没有）**：`build/daily/.config`（7.3.0-rc7）`# CONFIG_NF_TABLES is not set`，
   而 droidloom 的 `DevelopmentNetwork::setup_rules()` 强制 `nft -f -` 建 `inet` filter + `ip` nat（masquerade），
   失败即 `start_development_cell` 返回 Err ⇒ **cell 起不来的第一硬阻塞在内核配置，不在 AOSP**。
   其余（binderfs/memfd/ns/bpf/cgroup/PSI/seccomp/dma-heap/EROFS/EXT4/loop/FUSE）逐项在。
6. **PI/Widevine 口径零变化**：`threat-model-v2.md:116–120` 原文未变（PI/attestation/protected media "not supported claims"）；
   `KNOWN_ISSUES.md:232` Moto cell 仍"uncertified"；分配器仍拒 protected allocation。
7. **Denial 也发了 aarch64**（v0.6.2，2026-11-04：pkg/rpm/deb），**但 Alpine APK 仍 x86-64 only**；两个会话级硬坑（GPU reset、运行时改缩放）仍在。

## 3. 判定表（四门槛）

| 门槛 | 判定 | 卡在谁 |
|---|---|---|
| M1 上游交付形态（aarch64 包） | **过**（2026-10-31 起） | — |
| M2 合成器（xdg-shell / dmabuf v4 feedback / syncobj） | **部分过 2/3** | 我们（phoc 一行）；换合成器 = 动 G1，不做 |
| M3 内核前置 | **过 6 组 / 缺 nf_tables 一组** | 我们（配置 + 重编） |
| M4 GMS/PI/Widevine | **未过（无净增益）** | 上游明确免责 |

## 4. 最小隔离路径（未执行，仅设计）

L1 registry 探针（1 min）→ L2 phoc 一元补丁（1 天，需装 6 个 `-dev` 头包）→ L3 内核补 nftables + 零写盘启动（半天）→
L4 runtime 摊装 `/opt` 只跑 presenter/doctor（半天，下载 6.6 MB）→ L5 image + cell 首启（下载 0.90 GiB，装后 2.5 GiB）。
退出 E1–E5、复启 R-a…R-e 见报告 §5；**"aarch64 有无发布包"已从复启判据移除**。

## 5. 边界

- 在线只读：`gh api`（droidloom 41 资产、denial 24 releases、mutter NEWS/源码、sway server.c）、
  `raw.githubusercontent.com`（docs/源码）、`deb.debian.org`（phoc 0.58.0 源码 842 960 B）。
- 本机只读：`build/daily/.config`（7.3.0-rc7）、`build/daily/drivers/gpu/drm/{Makefile,drm_syncobj.c}`、
  `build/droidloom/droidloom/`（2026-10-24 解包源码 8.1 MiB）。
- **未做**：设备 `ssh/adb/fastboot`、装包、构建、`git clone`、改任何 SSOT 文件、发信。
- 未取证项（不得当结论）：`DRM_IOCTL_SYNCOBJ_EVENTFD` 设备侧 ioctl 探针；`max_loop` 是否需显式设；
  msm 上显式同步的实际行为；ARM64 cell 首启（上游自述 `still_required`，从无人跑过）。
