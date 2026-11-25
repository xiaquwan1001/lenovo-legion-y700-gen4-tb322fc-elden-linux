# droidloom 源码本地克隆与编译（2026-11-25 收尾轮）

> 用户指令：「直接把这个仓库克隆下来本地编译，我们之后还会用到」+「issue 里有链接，社区做了 Ubuntu 版，或许可以追」。

## 0. 一句话

- **源码已克隆到 `/home/xuqianhui/src/droidloom`**（`main` = `572e1c5 Package release 49`，`--depth 1` 17 MB），
  **x86_64 host 工具链编译通过**（`cargo +1.93.0 build --locked --release -j 12`，12.5 s，产物在 `target/release/`）。
- **aarch64 交叉编译未通**：缺 aarch64 版 `libwayland-server`（上游也是用 Arch ARM sysroot 做交叉），
  下一步要么装 Debian multiarch `:arm64` 开发包，要么复刻上游的 Arch ARM sysroot。
- **社区工作已定位并抓成本地分支**：`oodzchen` 的两个分支（host 兼容修复 + Fedora RPM 打包），
  **没有 Ubuntu/Debian 打包分支** —— 我们要的 deb 化只能照 Fedora 那套自己写。

## 1. 仓库现状与社区线索（issue #25 / #18）

| 项 | 事实 |
|---|---|
| 上游 | `denialwm/droidloom`，`main@572e1c5`（= release 49 的源码快照），**外部 PR 关闭** |
| issue #25「Support for Fedora and Ubuntu」 | `oodzchen` 2026-11-21 实测 **Fedora 45**（aarch64 Adreno 830 + x86_64 Iris Xe，KDE Wayland、SELinux Enforcing、firewalld）**两条都能起到 `Android is ready`**；`enYao39` 2026-11-25 复现成功 |
| 社区分支 1 | `oodzchen/droidloom` `pr/host-selinux-kernel-config`（tip `7b727c1`，两个补丁：① `0001-netbpfload-tolerate-shared-kernel-bpf-ids.patch` 放宽 `/sys/fs/bpf` SELinux 上下文差异 ② 无 `/proc/config.gz` 时把 `/boot/config-<release>` 只读 bind 到 `/droidloom/proc-config.gz`，并在 `libdroidloom_selinux_compat.so` 里 `ENOENT` 回落） |
| 社区分支 2 | `pr/fedora-rpm-packaging`（tip `9c4ca80`）：`packaging/fedora/`（runtime/image 两份 RPM spec + `droidloom_fedora.te` SELinux 策略 + firewalld zone + `dlh+` 出网策略 + Fedora 45 `Containerfile`）+ `droidloom-package build-rpm` 子命令 |
| 已抓进本地 | `git fetch fork pr/host-selinux-kernel-config` / `pr/fedora-rpm-packaging`（`git branch -r` 可见 `fork/pr_host-selinux-kernel-config`、`fork/pr_fedora-rpm-packaging`；因 `--depth 1` 只拿到 tip，要看 diff 需 `--depth 50`） |
| 对 Ubuntu/Debian | **没有任何社区 deb 分支**；Fedora 分支里的 `packaging/fedora/` 是 deb 化的**形状模板**（spec ↔ debian/ 一一对应：runtime/image 两包 + SELinux 策略 ↔ AppArmor/SELinux、firewalld ↔ nftables） |

## 2. 本机编译结果

```sh
cd /home/xuqianhui/src/droidloom
cargo +1.93.0 build --locked --release -j 12     # x86_64 宿主工具链
#   => Finished `release` profile [optimized] target(s) in 12.50s
```

- **工具链**：`rust-toolchain.toml` 钉 `1.93.0`（`profile=minimal` + clippy/rustfmt）；本机原先没有 1.93 ⇒ `rustup toolchain install 1.93.0`
  经代理装好（`https_proxy=http://127.0.0.1:7890`；**不带代理会卡在 component 下载**）。
- **唯一缺的系统依赖**：`glslangValidator`（`droidloom-gpu-server/build.rs:15` 用来编纹理解码器着色器）
  ⇒ 已 `apt-get install -y glslang-tools`（连带 `spirv-tools`，5.5 MB）。装完一次编过。
- **产物**：`target/release/` 下含 `droidloomctl`、`droidloom-wayland`、`droidloom-composer`、`droidloom-gpu-server`、
  `droidloom-applications`、`droidloom-package`、`droidloom-update`、`droidloom-image`、`droidloom-gapps` 等。
- **aarch64 交叉**（`--target aarch64-unknown-linux-gnu`）：rust-std 已装，但链接期
  `cannot find -lwayland-server`（宿主只有 x86_64 版）⇒ 与上游 BUILDING.md 的「需要 Arch Linux ARM sysroot（含 dev 头与 pkg-config）」一致。
  **两条可行路线**：① Debian multiarch（`dpkg --add-architecture arm64` + `libwayland-dev:arm64 libdrm-dev:arm64 …`，但会与宿主 x86_64 开发包打架，需谨慎）；
  ② 复刻上游 `sysroot/`（Arch Linux ARM rootfs + pkg-config 交叉文件），与 CI 一致、更干净。

## 3. 结论 / 下一步（droidloom 线）

1. **短期**（要在设备上跑）：继续用 release 49 的 pacman 包（`~/dl-droidloom-49/` 已备：`image` 66 862 311 B ✅、`runtime` 11 047 451 B ✅；
   `base` 903 MB 本轮下载被中断、需要重下 —— **注意 PITFALLS #729：落地必须 `zstd -t`**）。
2. **中期**（吃社区修）：`pr/host-selinux-kernel-config` 的两枚补丁对本机**只有一半价值** —— 2026-11-25 在机实测
   `/proc/config.gz` **存在**（`zcat /proc/config.gz | grep -c CONFIG_IKCONFIG_PROC` = 1）⇒ 补丁②（bind `/boot/config-<release>`）**本机不需要**；
   补丁①（`/sys/fs/bpf` SELinux 上下文）在 Debian 默认 AppArmor 下也大概率不触发 ⇒ **先不 cherry-pick，等真遇到 `system_server` crash loop 再取**。
3. **长期**（Debian/Mobian 化）：照 `packaging/fedora/` 写 `packaging/debian/`（runtime + image 两包 + 依赖映射 + udev/模块化规则），
   并把 `droidloom-package` 加 `build-deb` 子命令；这条与我们 §7 的 Mobian MR 线天然同源。
