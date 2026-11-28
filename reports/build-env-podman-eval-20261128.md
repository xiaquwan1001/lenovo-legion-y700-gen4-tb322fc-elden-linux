# 本机是否要装 podman —— 构建环境路线评估（2026-11-28，用户提问）

> 触发：今天连续三条 lane 里有 **2 条** 因「chroot 需要 root、子代理没有 sudo」被卡（phoc 0.46 回移、droidloom arm64 编）；
> 同时 T44 刚证明 **droidloom 4 个 C 依赖件根本不需要容器**（主机交叉编 18 s）。
> 问题 = 「以后还会常用的话，要不要本机装 podman」。

## 0. 一句话结论

**现在不装。** 今天的真实卡点是「arm64 构建要 root chroot」，**不是缺容器**；先做更便宜的修法（meson 交叉编，
不 chroot 也能出 aarch64 件），等同时满足「要重编 Android 镜像」或「几何级多发行版矩阵」再装 podman（那时它是必需品，不是可选项）。

## 1. 现查事实（可复核）

| 项 | 值 | 命令 |
|---|---|---|
| podman | **未安装**；候选 `5.7.0+ds2-3ubuntu1` | `which podman`；`apt-cache show podman` |
| 安装体积 | **Installed-Size 82 MB**（+ conmon/crun/netavark/gpgme 等依赖） | `apt-cache show podman` |
| 无 root 容器前提 | **已满足**：`/etc/subuid`、`/etc/subgid` 都有 `xuqianhui:100000:65536`；`kernel.unprivileged_userns_clone=1`；`max_user_namespaces=125130` | `grep /etc/subuid`；`sysctl` |
| 备选工具 | `bwrap`、`systemd-nspawn` **已在**（都无 rootless-arm64-构建的现成配方） | `which bwrap systemd-nspawn` |
| 现有 chroot | `arm64-sid` 3.0 GB、`arm64-trixie` 1.6 GB（root 属主，**`chroot(2)` 本身要 root**，chown 成用户也不行） | `du -sh /opt/elden/arm64-*` |
| 磁盘 | 281 GB 可用 | `df -h /` |

## 2. 会用到容器的四类活，逐类判「要不要」

| 活 | 需要容器吗 | 频次（按现状估） | 判据 |
|---|---|---|---|
| **A. droidloom 4 个 C 依赖件 / T43 IME 迭代** | **不需要**：`scripts/build-droidloom-userland-crates.sh` 已 18 s 出件 | 每次改 T43 / 每次换 release（52、53…）≈ 每月 1–3 次 | 容器只买到「可复现、不污染宿主」，而我们已用 sysroot 隔离 |
| **B. phoc / phosh 上游 MR 的设备件** | **当前需要 root chroot**，但这是**选择**：改成 meson 交叉编（sysroot + cross file）后**不需要容器也不需要 root** | 每个 MR 修订 1–3 次 | 缺的是 `libwlroots-0.18-dev` 等 dev 包进 trixie sysroot + 一个 cross file；**半天可验**（见 §3） |
| **C. AOSP / Android 镜像重编**（001 WifiProvisioning 自愈、`#65` 的 `onShowInputRequested`） | **需要容器**（droidloom 官方流程就是 podman + AOSP） | 一旦立项 = 长期常驻 | 但**决定性成本不是 podman**：AOSP 首编 ≈ 120 GiB 磁盘 + 数小时，且要维护 patch。用户 2026-11-27 已裁「暂缓」 |
| **D. Arch ARM sysroot / 其他发行版矩阵** | 不需要 | **已被用户裁决放弃**（T44：不走 Arch） | — |

## 3. 比装 podman 更便宜的修法（建议先做）

把「arm64 构建要 root」从流程里拿掉，而不是引入一个新的容器层：

1. 给 `out/sysroot-trixie-arm64` 再补 phoc 依赖（`libwlroots-0.18-dev`、`libgnome-desktop-3-dev`、`libgmobile-dev`、`libinput-dev`…，做法同 `scripts/sysroot-add-droidloom-deps.sh`）；
2. 写 `rootfs/cross-aarch64-phoc.ini`（c 编译器就填现有的 `aarch64-linux-gnu-gcc` + `--sysroot`，我们已在 `build-droidloom-userland-crates.sh` 里验证过这条路径可行）；
3. 判据：`meson setup --cross-file` 后 `ninja src/phoc` 产出的件与 trixie chroot 版 **NEEDED/GLIBC 判据一致**（我们已有 `out/phoc-046-edge-swipe-arm64-20261128/phoc` 做对照）。
   ⇒ 此后**任何 lane（含子代理）都能编 phoc，不需要 sudo**，也不需要 podman。

## 4. 装 podman 的触发条件（任一命中就装，别提前）

- **① 决定重编 Android 镜像**（001 自愈 / `#65` 安卓侧修复）——此时 podman 是官方流程的一部分，先装；
- **② 同时需要 ≥2 个不同发行版/glibc 基线的构建环境**（例如又要 trixie 2.41 又要更老基线），chroot 手工维护开始打架；
- **③ 子代理构建需求密度上来**：一周内 ≥2 次因「要 root chroot」被迫由父代理串行接管（今天正好 2 次，但已有 §3 的替代修法，先看它落不落地）。

## 5. 若将来要装，怎么做才不踩坑（先记下）

```sh
sudo apt install podman                      # 82 MB + 依赖
podman import <trixie-chroot.tar> elden-trixie-arm64:13   # 复用现有 chroot，不重新 debootstrap
podman build --platform linux/arm64 …        # 老版本 podman 对 --platform 支持弱，需 qemu binfmt（已装）
```
- rootless 默认 `fuse-overlayfs`，大编译会明显慢于 chroot/qemu-user 路径 ⇒ 只当「隔离与可复现」用，不当性能手段；
- 镜像里仍要钉 **trixie（glibc 2.41）**，否则产出的件上不了设备（今天已踩过 sid 2.43 的坑）；
- 镜像放在 `out/`（可归档、可删），别塞 `/var/lib/containers`（备份/清理口径不同）。

## 6. 结论

| 选项 | 代价 | 解决今天的问题吗 | 建议 |
|---|---|---|---|
| 不装，继续 chroot（现状） | 0 | 不解决（子代理不能编） | 仅作为过渡 |
| **不装 + 给 phoc 做 meson 交叉编（§3）** | 半天 | **解决**（无 root、无容器） | **推荐先做** |
| 装 podman（rootless） | 82 MB + ~1.5 GB 镜像 + subuid/网络排障 | 解决，但引入新层 | 命中 §4 触发条件再装 |
