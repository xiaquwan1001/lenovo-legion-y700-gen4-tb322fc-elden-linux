# T44 · droidloom 用户态「直接 Ubuntu/Debian 编译」立项评估（2026-11-28）

裁决前提（用户 2026-11-28）：**不走 Arch ARM sysroot、不选 Arch 编译方式**。对象 = release 51 源码里的
`droidloom-wayland` / `droidloom-audio` / `droidloom-devices` / `droidloom-gpu-server` 4 件。
源码树确认存在：`build/droidloom-51-src/`（workspace members 含 `graphics/droidloom-wayland`、
`runtime/droidloom-{audio,devices,gpu-server}`，工具链 `rust-toolchain.toml` = 1.93.0）。

## 1. crate → 真 C 依赖（读 Cargo.toml + build.rs 实证）

| crate | 真实 C 依赖（出处） | 链接方式 | Debian/Ubuntu 包 |
|---|---|---|---|
| droidloom-wayland | `wayland-client`（wayland-sys 0.31.11 `build.rs`：非 dlopen 时 `pkg-config probe("wayland-client")`） | 链接 `libwayland-client` | `libwayland-dev` |
| droidloom-wayland | `gbm`→`gbm-sys 0.4.0` `#[link(name="gbm")]`（不用 bindgen feature，头已预生成） | 链接 `libgbm` | `libgbm-dev` |
| droidloom-wayland | `xkbcommon` crate 实为 `xkbcommon-dl`（`dlopen_external_library!("libxkbcommon.so.0")`）+ `ash 0.38`（dlopen `libvulkan.so.1`） | **运行时 dlopen，不参与链接** | 运行期要 `libxkbcommon0`（编译不需要 -dev） |
| droidloom-wayland | dev-deps `wayland-server 0.31.13`（仅 `cargo test` 用） | 链接 `libwayland-server` | `libwayland-dev`（同一包内含 wayland-server.pc） |
| droidloom-audio | `build.rs`：`pkg-config --cflags libpipewire-0.3` + `cc` 编 `src/pipewire.c`/`volume.c`，`rustc-link-lib=pipewire-0.3` | 链接 `libpipewire-0.3` | `libpipewire-0.3-dev` |
| droidloom-devices | 仅 `wayland-client`（同上 wayland-sys probe）；zbus 纯 Rust | 链接 `libwayland-client` | `libwayland-dev` |
| droidloom-gpu-server | `wayland-client`（同上）；`build.rs` 跑 **`glslangValidator`** 编 8 个 .comp → SPIR-V（产物与目标机架构无关，可在 x86 构建机跑） | 链接 `libwayland-client`；glslang 是构建工具 | `libwayland-dev` + `glslang-tools` |

净结论：**C 链接依赖只有 3 个库**（wayland-client〔+可选 wayland-server 仅测试〕、gbm、pipewire-0.3），
**+1 个构建期工具**（glslangValidator）。xkbcommon/Vulkan 都是运行期 dlopen，不挡编译。

## 2. 本机两处环境对照

| 依赖 | trixie sysroot `out/sysroot-trixie-arm64/` | sid chroot `/opt/elden/arm64-sid` |
|---|---|---|
| wayland-client.pc / 库 | **缺**（pc 目录仅 glib 系 19 个，无 wayland*） | **有**（pc Version 1.26.0，`libwayland-client.so`/`wayland-server.h` 全） |
| gbm.pc / libgbm.so | **缺** | **有**（`gbm.pc` Version 26.2.6-1，含 `gbm.h`） |
| libpipewire-0.3.pc | **缺** | **有**（Version 1.6.9，`libpipewire-0.3.so.0.1609.0`，含头） |
| xkbcommon.pc | **缺** | 有（1.13.1）——但编译不需要（dlopen） |
| cargo/rustc | 无（host 用 rustup 1.93.0 交叉编） | **无**（`/usr/bin` 无 cargo/rustc） |
| glibc | **2.41（deb13u5）= 设备同版 ✅** | **2.43-7 ⚠️ 高于设备 2.41** |

主机 x86_64 Ubuntu 已有 `aarch64-linux-gnu-gcc-15` 全套交叉工具与 `glslangValidator 16.2.0`。

### 一条命令装齐（Ubuntu/Debian arm64，原生机或 chroot 内）
```sh
apt install cargo pkg-config gcc libc6-dev \
  libwayland-dev libgbm-dev libpipewire-0.3-dev glslang-tools
```
包名均经 `apt-cache show` 实证存在（host Ubuntu 24.04 源：libpipewire-0.3-dev 1.6.2、
libwayland-dev 1.24.0、libgbm-dev 26.0.8、glslang-tools 16.2.0；Debian sid 同名）。
glslang-tools 装在**构建机**（x86 也行，SPIR-V 架构无关）。

## 3. 最小可编配方

**路线 A（推荐）：主机交叉编 + trixie sysroot 扩展**
sysroot 现缺 wayland/gbm/pipewire 的 .pc/.so/.h —— 从 sid chroot 或 `apt download`/`dpkg -x`
（libwayland-dev、libgbm-dev、libpipewire-0.3-dev 的 arm64 deb）拷入 sysroot 对应路径即可
（这些库自身依赖 glibc 符号 ≤2.41，trixie 2.41 基线不动）。
```sh
export PKG_CONFIG_ALLOW_CROSS=1 PKG_CONFIG_LIBDIR=/home/xuqianhui/y700-elden/out/sysroot-trixie-arm64/usr/lib/aarch64-linux-gnu/pkgconfig
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
cd build/droidloom-51-src
cargo build --release --locked --target aarch64-unknown-linux-gnu \
  -p droidloom-wayland -p droidloom-audio -p droidloom-devices -p droidloom-gpu-server
# 产物 target/aarch64-unknown-linux-gnu/release/{droidloom-wayland,droidloom-audio,droidloom-devices,droidloom-gpu-server}
```

**路线 B：原生 arm64 机（或 chroot 补装后）**
```sh
apt install cargo pkg-config libwayland-dev libgbm-dev libpipewire-0.3-dev glslang-tools
cargo build --release --locked -p droidloom-wayland -p droidloom-audio \
  -p droidloom-devices -p droidloom-gpu-server   # 产物 target/release/…
```
⚠️ chroot 现为 sid glibc 2.43 > 设备 2.41，原生编完后**必须过 glibc 判据**，超了就要改用 trixie 基
（如 Debian 13 arm64 容器/机器）。chroot 内没有 cargo，装包动作本轮被禁，未实装。

**glibc 兼容判据**（每件都跑，≤ 2.41 即可上设备）：
```sh
objdump -T <binary> | grep -o 'GLIBC_[0-9.]*' | sort -V | tail -1
```
现役 release 51 原件实测最高 `GLIBC_2.39`（BUILD.md §2），新编件以同一判据验收。

## 4. 风险与工作量 / 不编会卡住什么

- 工作量：**半天**。大头只是把 3 个 -dev 包的文件补进 trixie sysroot（机械 dpkg -x）+ 首轮编译修
  link 路径；4 件里无自写 C 绑定坑（gbm-sys 预生成、wayland-sys pkg-config、pipewire 自带 2 个 .c）。
- 风险：① sid chroot 路线 glibc 2.43 超标（判据会拦）；② sysroot 混入 sid 库时若其依赖符号 >
  2.41 需换 trixie 版 deb；③ rust-toolchain 1.93.0 需 rustup 目标 `aarch64-unknown-linux-gnu`
  （T43 已验证可交叉编路径存在，BUILD.md 记录 57 s 交叉编可抄）。
- **不编这 4 件会卡住 T43**：T43 要改 `graphics/droidloom-wayland/src/text_input.rs` 的
  disable/enable 路径并替换设备上的 `droidloom-wayland`；若该件编不出，T43 只能停在纸面。
  `droidloom-audio`/`-devices`/`-gpu-server` 暂无改动需求，属顺带解锁（与 wayland 同 workspace，
  编 wayland 时三者几乎零额外成本）。

本轮只读评估：零代码改动、未上设备、未 commit、未在 chroot 内安装任何包。

```acceptance-report
{
  "criteriaSatisfied": [
    {"id": "criterion-1", "status": "satisfied", "evidence": "本报告：crate→系统库→apt 包名全表（§1）、两环境对照（§2）、两条最小可编配方 + glibc 判据（§3）、半天工作量 + T43 阻塞结论（§4）"}
  ],
  "changedFiles": ["reports/t44-ubuntu-build-scoping-20261128.md"],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {"command": "git rev-parse --show-toplevel", "result": "passed", "summary": "确在 y700-elden 仓根"},
    {"command": "ls build/droidloom-51-src + workspace members grep", "result": "passed", "summary": "源码树存在，4 crate 在 workspace"},
    {"command": "cat 4 个 Cargo.toml + droidloom-audio/gpu-server build.rs + wayland-sys/gbm-sys/xkbcommon-dl registry 源码", "result": "passed", "summary": "C 依赖实锚：wayland-client/gbm/pipewire-0.3 链接，xkbcommon+ash dlopen"},
    {"command": "ls 两环境 pkgconfig/include/lib 目录", "result": "passed", "summary": "trixie sysroot 缺 3 pc；sid chroot 全有但无 cargo 且 glibc 2.43"},
    {"command": "apt-cache show libpipewire-0.3-dev libwayland-dev libgbm-dev glslang-tools", "result": "passed", "summary": "4 个包名全部实证存在"},
    {"command": "git status --porcelain", "result": "passed", "summary": "仅新增本报告"}
  ],
  "validationOutput": ["sid chroot pc 版本：wayland-server 1.26.0 / gbm 26.2.6-1 / xkbcommon 1.13.1 / libpipewire-0.3 1.6.9 / libdrm 2.4.134", "glibc：trixie sysroot 2.41-12+deb13u5（=设备），sid chroot 2.43-7（超设备 2.41）"],
  "residualRisks": ["未实际执行 cargo build（本轮只读评估，配方待 T44 落地轮验证）", "sid chroot 路线需 glibc 判据拦截 2.43 超标"],
  "noStagedFiles": true,
  "diffSummary": "仅新增评估报告 reports/t44-ubuntu-build-scoping-20261128.md（≤150 行，表格为主）",
  "reviewFindings": ["no blockers"],
  "manualNotes": "回执：C 依赖共 3 库 + 1 构建工具，对应 5 个 apt 包（cargo pkg-config libwayland-dev libgbm-dev libpipewire-0.3-dev + glslang-tools）。路线 A（交叉编 + trixie sysroot 补 3 个 -dev 包）推荐；路线 B（原生 arm64/chroot）可行但 sid chroot glibc 2.43>2.41 需判据拦截。T43 卡点：droidloom-wayland 编不出则 T43 做不了，本报告给出半天可落地的解锁路径。"
}
```

---

## 4. 实测落地（2026-11-28 父代理，路线 A 已打通）

**结论：4 件全部编出并上机验证依赖可解析 —— 不需要 Arch ARM sysroot，也不需要 arm64 真机。**

| 步骤 | 命令 | 结果 |
|---|---|---|
| 1. 建 trixie arm64 chroot | `debootstrap --arch=arm64 trixie /opt/elden/arm64-trixie` | Debian **13.8**，239 MB（只作「取 trixie 版 arm64 包」用，不在里面编 Rust） |
| 2. 补 sysroot | `sudo bash scripts/sysroot-add-droidloom-deps.sh` | 解入 12 个 trixie arm64 deb（`libwayland-dev`/`libgbm-dev`/`libpipewire-0.3-dev`/`libspa-0.2-dev`/`libdrm-dev`/`libxkbcommon-dev` + 各自运行时）；判据 `wayland-client=1.23.1 gbm=25.0.7 libpipewire-0.3=1.4.2` |
| 3. 交叉编 | `bash scripts/build-droidloom-userland-crates.sh` | **`Finished release profile in 18.23s`**，4 件全出 |
| 4. 设备依赖 | `scp` 到设备 `/tmp` 后 `ldd`（只读） | 4 件 **missing=0** |

产物（`build/droidloom-51-src/target/aarch64-unknown-linux-gnu/release/`）：

| 件 | 大小 | max GLIBC（设备 2.41） |
|---|---|---|
| `droidloom-wayland` | 8,039,960 B | 2.39 ✅ |
| `droidloom-audio` | 1,304,752 B | 2.38 ✅ |
| `droidloom-devices` | 5,771,048 B | 2.39 ✅ |
| `droidloom-gpu-server` | 1,606,312 B | 2.34 ✅ |

### 过程中踩到的三个坑（都已固化进脚本）

1. **`-lpipewire-0.3` 找不到**：只解 `-dev` 包不够，`.so` 是指向运行时 `.so.0` 的符号链接 ⇒ 必须同时解运行时包（`libpipewire-0.3-0t64`、`libgbm1`、`libwayland-client0` 等）。
2. **`libspa-0.2.pc` 缺失**：pipewire 的 `.pc` 有 `Requires: libspa-0.2`，它由 `libspa-0.2-dev`（不是 `libpipewire-0.3-dev`）提供。
3. **`cannot find /lib/aarch64-linux-gnu/libm.so.6`**：trixie 的 `libc.so`/`libm.so` 是 GNU ld script，里面写**绝对路径**；宿主交叉 gcc 的 sysroot 是 `/usr/aarch64-linux-gnu`，不会去我们的 sysroot ⇒ 必须用 wrapper 把 `--sysroot=$SYSROOT` 传给 **ld**（`scripts/build-droidloom-userland-crates.sh` 内置 `build/tools/aarch64-cc-sysroot.sh`）。同样的原因，仅给 `RUSTFLAGS=-Wl,--sysroot=` 不够（实测无效）。

### 对 T43 的意义

T43（改 `droidloom-wayland/src/text_input.rs` 修 IME dismiss/enable 状态机）**唯一的前置是编译**，现已解除：改完直接 `bash scripts/build-droidloom-userland-crates.sh droidloom-wayland`（单件）即可出件，替换设备 `/usr/lib/droidloom/runtime/…` 现役件（device 侧 `droidloomctl` 重拉）。

### 未做（留给下一步）

- 未替换设备现役 4 件（属写盘 + 重启用户态服务，需窗口）；
- `droidloom-gpu-server` 的 8 个 SPIR-V 由宿主 `glslangValidator 16.2.0` 编（架构无关，已验能出件）。
