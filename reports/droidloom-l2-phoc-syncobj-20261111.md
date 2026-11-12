# C12 L2：phoc 广告 `wp_linux_drm_syncobj_manager_v1`（主机侧全链打通 + aarch64 产物就位）


<!-- pitfalls-entries -->
> **本报告承载的 PITFALLS 条目正文锚点**（索引行在 `PITFALLS/README.md`；此处给 #NNN 定义，避免索引悬空）：
> `#609`、`#610`、`#612`、`#613`

- 日期：2026-11-11
- pi 会话 id：本段（关键词「继续中断或未完成的任务，检查待办」）
- 主题：把 droidloom 的合成器缺口（phoc 从不创建 linux-drm-syncobj 全局）从「一行 + 重编」推进到
  **补丁成型 + 主机侧 A/B 实证 + aarch64 二进制可部署**；设备上机留待下一轮（本轮无设备）。
- 结论：**三条全部达成（主机侧）**：① 补丁在 phoc 0.55.1 上编译通过；② headless 实跑 A/B
  证明全局从「无」变「有」（54→55 个全局，`wp_linux_drm_syncobj_manager_v1` v1 出现）；
  ③ aarch64 二进制已产出（对系统 libwlroots-0.20.2，同设备版本），只差上机替换。

## 1. 补丁内容（为什么是这一行，且比 sway 多一个 fd 兜底）

上游 phoc `src/desktop.c` 的全局创建清单**从不调用** `wlr_linux_drm_syncobj_manager_v1_create()`
（0.59.rc1 也没有）⇒ droidloom presenter 硬绑定该全局 ⇒ `Wayland global bind failure`。

补丁 `patches/phoc-syncobj-20261111/0001-desktop-advertise-linux-drm-syncobj-v1.patch`（57 行、4 个 hunk）：

1. `#include <wlr/types/wlr_linux_drm_syncobj_v1.h>` + `#include "render-private.h"`；
2. `PhocDesktopPrivate` 加一个指针字段（持有 manager）；
3. `phoc_desktop_constructed()` 里，紧跟 `wlr_presentation_create()` 之后：
   条件 = `wlr_renderer->features.timeline && wlr_backend->features.timeline`（与 sway/labwc 同条件），
   `drm_fd` 取 `wlr_backend_get_drm_fd()`，**为负时回落到 `wlr_renderer_get_drm_fd()`**，
   仍为负则不广告并打一行灰日志。

第 3 条的 fd 兜底是本轮实测**必需**的：wlroots 的 `wlr_linux_drm_syncobj_manager_v1_create()`
内部 `check_syncobj_eventfd(drm_fd)` 在 `drm_fd=-1` 时失败并直接返回 NULL（不是只 warn），
所以「照 sway 只传 backend fd」在 headless/多后端场景会静默不广告：
实测 host headless 下 `renderer timeline=1, backend timeline=1, drm_fd=-1` ⇒ 无全局；
补上 renderer fd 回落（host 上取到真实 GPU fd）后 ⇒ 全局出现。

## 2. 主机侧 A/B（判据：wayland-info 的全局清单）

同机同 wlroots（phoc 自带 `subprojects/wlroots-0.20.x`）、同后端（`WLR_BACKENDS=headless`、
`WLR_RENDERER=gles2`）、同配置：

| 臂 | 全局数 | 有 `wp_linux_drm_syncobj_manager_v1` | 证据 |
|---|---|---|---|
| 未打补丁 phoc 0.55.1 | 54 | **否** | `reports/artifacts/droidloom-l2-phoc-20261111/wayland-info-pristine.txt` |
| 打补丁 phoc 0.55.1 | **55** | **是（version 1）** | `.../wayland-info-patched.txt`、`.../phoc-patched-run.log` |

复现（本机，无需设备）：

```sh
meson setup /tmp/phoc-build -Dembed-wlroots=enabled -Dxwayland=disabled -Dwlroots:renderers=gles2
ninja -C /tmp/phoc-build src/phoc
export XDG_RUNTIME_DIR=/tmp/xdgphoc GSETTINGS_SCHEMA_DIR=/tmp/phoc-build/data
export WLR_BACKENDS=headless WLR_RENDERER=gles2
/tmp/phoc-build/src/phoc -C /tmp/phoc-test.ini --socket=phoc-proof -S &
WAYLAND_DISPLAY=phoc-proof wayland-info | grep syncobj
```

（`GSETTINGS_SCHEMA_DIR` 必须指向构建目录的 `data/`，否则 phoc 因缺 `mobi.phosh.phoc` schema 直接退出。）

## 3. aarch64 产物（本轮新增，可直接上机）

- 产线：主机 arm64 Debian **sid** chroot `/opt/elden/arm64-sid`（qemu-user binfmt），
  **对系统 `libwlroots-0.20-dev 0.20.2-1` 编**（= 设备在版的 0.20.2），`-Dembed-wlroots=disabled`，
  比内嵌 0.20.0 的行为差更小；脚本 `scripts/build-phoc-arm64.sh`（可重入）。
- 产物：`out/phoc-syncobj-arm64-20261111/phoc`（3 357 280 B，sha256
  `12f2777c8034d80ac46c7cdbd72b512a1081313998bb58f6845fd017e683ce18`，ELF aarch64 pie），
  同目录 `MANIFEST.md` 写上机与回退步骤。
- 与设备同版本源码（0.55.1）⇒ 只需替换 `/usr/bin/phoc`（phoc 二进制静态链了 `libphoc.a`，
  `NEEDED` 里没有 libphoc，**不必也不该动** `libphoc.so`）。

构建侧两个坑（已写进 PITFALLS #609/#610）：
① phoc 的 `subprojects/` 目录名是 `wlroots-0.20.x`，`-Dembed-wlroots=enabled` 要求名为 `wlroots`
   ⇒ 需 `ln -s wlroots-0.20.x subprojects/wlroots`；且 subproject 默认 `renderers=gles2,vulkan`
   会因缺 `glslang` 直接 configure 失败 ⇒ 传 `-Dwlroots:renderers=gles2`。
② wlroots 头文件即使 `-Dxwayland=disabled` 仍 `#include <xcb/xcb_ewmh.h>` ⇒ 必须装 xcb 系列 dev 包。

## 4. 未验证（不得当结论）

1. **msm_dpu 上显式同步的稳定性**：开启后 page-flip 走 timeline 分支，本机零先例 ⇒ 上机后要盯
   卡顿/花屏/suspend-resume（droidloom 报告 §5 第 2 条仍未变）。
2. **设备上 phoc 的安装路径**（本轮无设备，按 Debian 包布局推定 `/usr/bin/phoc`）。
3. droidloom presenter 是否**只差**这一个全局：headless sway 下已全绑定通过（11-10 报告 §8.2），
   真后端下的 bind 顺序仍未验。

## 5. 下一轮（设备回来后，一次做完）

1. `cp -a /usr/bin/phoc /usr/bin/phoc.orig-0.55.1` → `install -m0755 phoc /usr/bin/phoc`；
2. 重起桌面会话 → `wayland-info | grep syncobj`（判据一）；
3. `droidloom-wayland` 起停（判据二：不再 bind failure）；
4. 若 3 通过 → 才值得投 L3 的 0.90 GiB image（L3 另被 rootfs 属主契约挡住，见 C12 行）。

---

## 9. 2026-11-11 上机收口（L2 两条判据全绿）

设备通网/回 fastboot 后（`scripts/slot-switch.sh b --reboot` 从 UEFI 测试形态切回稳定 `_b`，
自动 `qbootctl -m b`；`current-slot=b`、Linux 起于 `/dev/sda17`、内核 `7.3.1-debug-vk184-00003`）。

**★先修正一件事实：设备在版 phoc 是 0.58.0（phosh 0.59~alpha1），不是 0.55.1。**
本节 §3 那个 0.55.1 产物因此**不能上机**（跨两代降级），改为按 0.58.0 重编：

| 尝试 | 结果 |
|---|---|
| 0.55.1 + 补丁（§3 的 `phoc`） | 只作主机 A/B 对照；**不上机** |
| 0.58.0 + 补丁，对**系统** libwlroots-0.20.2 | **编不过**：`wlr_text_input_manager_v3_create` 参数个数与 `events.show_input_panel` 都不存在于 0.20.2 ⇒ 0.58 要求更新的 wlroots |
| 0.58.0 + 补丁 + 内嵌 `subprojects/wlroots-0.20.x`(0.20.2) | 仍编不过，同样的 text-input 报错 |
| **0.58.0 + Debian 的 `Apply-upstream-patches.patch` + 我们的补丁 + 内嵌 wlroots 静态** | ✅ **编过且上机全绿**（这才是 Debian 自己的打包方式：`debian/patches` 给内嵌 wlroots 补 text-input 新 API，`-Dwlroots:default_library=static` 使 phoc 自包含、NEEDED 里没有 libwlroots） |

产物：`out/phoc-syncobj-arm64-20261111/phoc-0.58.0-syncobj`
（7 543 080 B，sha256 `863731b0b323bc5122ec8892d62acd72646f45198d47e4426b8083bc61fb7cb5`，
`readelf -h` = AArch64；上机步骤与回退见同目录 `MANIFEST.md`；构建脚本 `scripts/build-phoc-arm64.sh`）。

上机操作（零内核改动、零写槽；只换一个二进制 + 重起会话）：

```
cp -a /usr/bin/phoc /usr/bin/phoc.orig-0.58.0      # d36d9d94…（发行版原件）
install -m 0755 phoc-0.58.0-syncobj /usr/bin/phoc  # 863731b0…
systemctl restart greetd
```

**判据一（合成器广告）**：会话内 `wayland-info` = **57 个全局**，含
`interface: 'wp_linux_drm_syncobj_manager_v1', version: 1, name: 45`
（证据 `reports/artifacts/droidloom-l2-phoc-20261111/device-wayland-info-with-syncobj.txt`）。

**判据二（presenter 不再 bind 失败）**：`droidloom-wayland` 起停 **0 次** `bind failure`，
日志进入 `Droidloom session mode: desktop`、复制后端 = `ext-data-control`
（证据 `.../device-droidloom-wayland-bind.log`；其中 `session bus disconnected` 是 `su` 无会话总线导致的预期噪声）。

**桌面完好**：`grim` 截屏 = Phosh 锁屏（时钟/WiFi/BT/电量正常），phoc/phosh/phosh-osk-stevia 均在跑
（证据 `.../device-phosh-after-phoc-058-syncobj.png`）。

**仍未验证**（不得当结论）：msm_dpu 上显式同步的 page-flip 稳定性（长时间/熄屏唤醒未测）、
L3（droidloom cell）仍被 rootfs 属主契约挡住（`PITFALLS #608`）。
