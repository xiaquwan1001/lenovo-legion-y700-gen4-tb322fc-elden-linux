# 2026-11-11 — phoc 广告 `linux-drm-syncobj-v1`（C12 L2）+ arm64 构建链的四个坑

- **日期**：2026-11-11
- **pi 会话 id**：本段会话（关键词「继续中断或未完成的任务，检查待办」）
- **主题**：phoc 补一行创建 `wp_linux_drm_syncobj_manager_v1`；主机侧 A/B 实证；aarch64 二进制（对系统 wlroots 0.20.2）产出
- **结论**：① `wlr_linux_drm_syncobj_manager_v1_create()` 在 `drm_fd` 无效时**直接返回 NULL**（不是只 warn），
  所以「只传 backend fd」在 headless/多后端下静默无全局，必须回落到 `wlr_renderer_get_drm_fd()`；
  ② phoc 的 wlroots subproject 目录名是 `wlroots-0.20.x`，`-Dembed-wlroots=enabled` 要求名为 `wlroots`，
  且 subproject 默认 `renderers=gles2,vulkan` 会因缺 `glslang` configure 失败 ⇒ 传 `-Dwlroots:renderers=gles2`；
  ③ 即使 `-Dxwayland=disabled`，wlroots 头仍 `#include <xcb/xcb_ewmh.h>` ⇒ 必须装 xcb 系列 dev；
  ④ 直接跑构建目录里的 phoc 必须 `GSETTINGS_SCHEMA_DIR=<builddir>/data`，否则缺 `mobi.phosh.phoc` schema 直接退出。
- **证据指针**：`reports/droidloom-l2-phoc-syncobj-20261111.md`、
  `reports/artifacts/droidloom-l2-phoc-20261111/{wayland-info-patched.txt,wayland-info-pristine.txt,phoc-patched-run.log}`、
  `patches/phoc-syncobj-20261111/0001-desktop-advertise-linux-drm-syncobj-v1.patch`、
  `scripts/build-phoc-arm64.sh`、`out/phoc-syncobj-arm64-20261111/{phoc,MANIFEST.md}`
- **★SSOT 待并入**：`PITFALLS/README.md` #609/#610/#611（已入）、`TASKS/README.md` §2 C12 行（已入）

## 条目定义（供 check-doctor §8e 锚点）

- **#609** `wlr_linux_drm_syncobj_manager_v1_create()` 在 `drm_fd` 无效时直接返回 NULL（`check_syncobj_eventfd` 不过就 `return NULL`，只打一行 WLR_INFO）⇒ 合成器必须回落到 `wlr_renderer_get_drm_fd()`；否则 headless/多后端下静默不广告（实测 `drm_fd=-1` ⇒ 54 个全局无 syncobj，补回落 ⇒ 55 个全局有）。
- **#610** phoc 主机侧构建三坑：`subprojects/wlroots-0.20.x` 需 `ln -s` 成 `wlroots`；subproject 默认 `renderers=gles2,vulkan` 缺 `glslang` ⇒ `-Dwlroots:renderers=gles2`；`-Dxwayland=disabled` 也躲不掉 `<xcb/xcb_ewmh.h>` ⇒ 需装 xcb 系列 dev；aarch64 chroot 另需 `gettext`(`msgfmt`)。
- **#611** 跑构建目录里的 phoc 必须 `GSETTINGS_SCHEMA_DIR=<builddir>/data`，否则缺 `mobi.phosh.phoc` schema 秒退（`phosh-common` 包不含该 schema）。

## 上机轮追加（2026-11-11 下午）

- **#612** 「设备在版 phoc 0.58.0 + 系统 libwlroots-0.20.2」**编不过**：0.58 源码用 wlroots 新 text-input API（单参 `wlr_text_input_manager_v3_create` + `events.show_input_panel`）；连自带的 `subprojects/wlroots-0.20.x`(0.20.2) 也不行 —— 必须套 **Debian 的 `debian/patches/Apply-upstream-patches.patch`**，并用 `-Dwlroots:default_library=static` 内嵌静态（Debian 自己就是这么打的；设备在版 phoc 的 `NEEDED` 里没有 libwlroots）。
- **#613** 判据分两层：`wayland-info` 出现全局 ≠ 客户端可用；本轮 ① 57 全局含 `wp_linux_drm_syncobj_manager_v1` v1、② `droidloom-wayland` 0 次 `bind failure` 且进入 `session mode: desktop`。`su -c` 起的客户端刷 `session bus disconnected` 属预期噪声。
