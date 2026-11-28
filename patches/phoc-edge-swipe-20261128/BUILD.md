# BUILD.md — phoc edge-swipe MR 构建记录（2026-11-28）

## 目标基线

- 上游浅克隆：`build/phoc-mr-20261128`（50 commits，`main` 头 = `51808950fc4f`，`meson.build` version = **0.59.0**）。
- 分支：`wip/edge-swipe-back`，单提交 `7f3feda cursor: Add an edge swipe back gesture`。

## 计划路线（未走通）

Debian sid arm64 chroot `/opt/elden/arm64-sid`（`scripts/build-phoc-arm64.sh` 同款做法）：
**chroot 根目录 root 属主、本 worker 无 sudo**（`sudo_exec` 提示需交互主会话），无法新建
`/opt/elden/arm64-sid/build-phoc-mr`，也不允许动既有 `build-phoc-src0591` 等目录 ⇒ **chroot 路线在本轮不可用**。

## 实际路线：宿主机 x86_64 全量构建（真编到链接成功）

```sh
cd build/phoc-mr-20261128
PKG_CONFIG_PATH=/tmp/wp-install/share/pkgconfig \
  meson setup build-host -Dembed-wlroots=enabled -Dwlroots:default_library=static \
    -Dwlroots:renderers=gles2 -Dxwayland=disabled -Dtests=false
PKG_CONFIG_PATH=/tmp/wp-install/share/pkgconfig ninja -C build-host src/phoc
# ⇒ [594/594] … Linking target src/phoc   （RC=0，0 warning）
```

宿主缺依赖的解法（均在 /tmp，不污染仓库与 /opt/elden）：

1. **wayland-protocols 1.49 本地 prefix `/tmp/wp-install`**（宿主 1.47 太旧：text-input v3 缺
   `preedit_hint`/`action`；wayland-protocols main 又把 color-management `WINDOWS_BT2100` 改名 `WINDOWS_SCRGB`，
   与内嵌 wlroots 0.20.x 不匹配 ⇒ 必须钉 1.49）。
2. 系统 `wayland-scanner` 过不了新版协议 strict-DTD，无法完整 meson 安装 wp ⇒ 手动布置：
   `share/wayland-protocols/{stable,unstable,staging}` + 手写 `wayland-protocols.pc`
   （`pkgdatadir` + `Cflags: -I${prefix}/include`，后者必须给——wlroots 头文件
   `#include <wayland-protocols/color-management-v1-enum.h>`，否则 enum 被系统旧头遮蔽）。
3. 用系统 `wayland-scanner enum-header`（不带 `--strict`）生成 58 个 `-enum.h` 到 `/tmp/wp-install/include/wayland-protocols/`。

## 关键日志（meson compile 尾部）

```
[1/3] Generating src/phoc-enum-types.h with a custom command
[2/3] Linking static target src/libphoc.a
[3/3] Linking target src/phoc
```

- `build-host/src/phoc` 产物 7,572,896 B，`ninja` RC=0。
- 全量日志：`/tmp/phoc-mr-build*.log`（最后一轮 `/tmp/phoc-mr-build-final.log`，`grep -ci warning` = 0）。
- 中途失败轮（已排除，均与 MR 代码无关）：① host wp 1.47 太旧；② wp main 改名 BT2100；③ 手写 pc 缺 `pkgdatadir`；④ enum 头遮蔽。
- 排错期间真实编译错误只两处，均已修：`G_DECLARE_FINAL_TYPE`→`DERIVABLE_TYPE`（phoc 房规）、`phoc_gesture_edge_swipe_new` 忘定义、`static` 与头文件声明冲突、`-Wswitch-default`。

## 未做

- 未跑 aarch64/chroot 交叉验证（无 root）；x86_64 内嵌 wlroots 全量链接通过已覆盖语法/链接层风险。
- 未动 `/opt/elden` 任何目录；`build-slot take y700-elden:phoc-mr` 已 take/drop（本轮实际未占用 CPU 构建）。

## 追加：aarch64（目标架构）真编 —— 2026-11-28 父代理

worker 无 sudo，故父代理用 `sudo_exec` 跑 `scripts/build-phoc-mr-arm64.sh`（chroot `/opt/elden/arm64-sid`，
wayland-protocols 1.50 / wlroots 0.20.2 / wayland-server 1.26 / xkbcommon 1.13.1 / meson 1.13.2）：

```
--- meson setup ---  embed-wlroots: enabled, wlroots subproject: YES
[523/523] Linking target src/phoc
```
（构建过程有 gvdb 静态分析器的 `-fanalyzer` 提示，属 subproject 既有告警，链接成功、与 MR 代码无关。）

产物 `out/phoc-edge-swipe-arm64-20261128/`：
- `phoc-edge-swipe` 7,483,056 B，sha256 `6aa46b3a5ab2571f7dff2a49a8ac9587ea8b2c965a6f92ca7e98ec8b60c807f7`
- `ELF 64-bit LSB pie executable, ARM aarch64`，max `GLIBC_2.38`（设备 2.41 ⇒ 兼容）
- `meta.txt`（branch/commit/sha/NEEDED）+ `build.log`（138 KB 全量）

⇒ **两架构编译证据齐**（x86_64 + aarch64）。设备侧安装验证（Firefox 内边缘滑动不透传）仍需一次重启窗，未做。
