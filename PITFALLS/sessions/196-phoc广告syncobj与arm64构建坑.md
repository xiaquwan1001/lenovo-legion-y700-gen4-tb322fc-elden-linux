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

## 索引回填（编号 264）：609 给合成器补 syncobj 时 drm_fd 必须有值

**#264** phoc 补 `linux-drm-syncobj-v1` 实现时 `drm_fd` 未初始化会导致渲染上下文拿不到 DRM fd（全局广告了但客户端 bind 后不工作）；初始化顺序上 drm_fd 要在合成器创建渲染上下文之前赋值。原文：reports/droidloom-l2-phoc-syncobj-20261111.md

## 索引回填（编号 265）：610 phoc 主机侧构建三个硬坑

**#265** ① subprojects 目录名是 `wlroots-0.20.x`，`-Dembed-wlroots=enabled` 要求名为 `wlroots`（改名或软链）；② arm64 交叉构建的 pkg-config 路径要显式指目标 sysroot；③ 构建目录里的 schema 见 #611。原文：reports/droidloom-l2-phoc-syncobj-20261111.md

## 索引回填（编号 266）：跑构建目录里的 phoc 要指 GSETTINGS_SCHEMA_DIR（611 同族）

**#266** phoc 启动即读 `mobi.phosh.phoc` schema，宿主没装 phosh 就 `GLib-GIO-ERROR **: Settings schema 'mobi.phosh.phoc' is not installed` 秒退；`phosh-common` 包不含该 schema（0.54 实测）。正解 = `GSETTINGS_SCHEMA_DIR=<builddir>/data`（meson 已把 `gschemas.compiled` 生成在那儿），不需要装任何 phosh 包。判据：`ls <builddir>/data/gschemas.compiled` 后带该变量起 phoc 不再秒退。

## 索引回填（编号 267）：612 编 phoc 时「设备在版版本」与「系统 wlroots」必须一起看

**#267** 设备上跑的 phoc 版本与宿主/构建时链接的 wlroots 版本要成对核对：协议全局是 phoc+wlroots 共同决定，只查一边会得出「版本够了」的假结论。原文：reports/droidloom-l2-phoc-syncobj-20261111.md

## 索引回填（编号 268）：换合成器二进制后判据分两层（613 同族）

**#268** `wayland-info` 里出现目标全局只证明「广告了」，还要看客户端能否 **bind 后继续跑**：① 57 个全局含 `wp_linux_drm_syncobj_manager_v1` v1；② `droidloom-wayland` 0 次 `bind failure` 且进入 `session mode: desktop`。另：`su <user> -c` 起的客户端没有 `DBUS_SESSION_BUS_ADDRESS` ⇒ 日志刷 `session bus disconnected; retrying` 是预期噪声，不是失败判据（别据此回滚）。原文：reports/droidloom-l2-phoc-syncobj-20261111.md
