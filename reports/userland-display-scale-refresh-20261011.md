# 用户态显示修正：刷新率固定 165 Hz + 非整数缩放显示 100%（2026-10-11）

> 设备 U2（b 槽持久直启，vk64）；会话 = greetd + phosh-session + phoc 0.55.1 / phosh 0.55.0。
> 两个用户态（非内核）问题：①刷新率恒 165 Hz 不可切换；②非整数比例在 Settings→Displays 恒显 100%。
> 结论：**均为源码级小 bug，已在设备上重编 phoc/phosh 修复并实测通过**。补丁与构建脚本见 `patches-userland/`。

---

## 0. 一句话结论

| 问题 | 组件 | 根因（源码） | 修复 | 实测 |
|---|---|---|---|---|
| 刷新率恒 165 Hz | **phoc 0.55.1** | `output.c` 把 output-manager 的 mode 转内部 config 时只认 `mode->preferred`；非 preferred 走 else 读空的 `custom_mode`(0x0@0) → 回退 preferred | `if (head->state.mode)`（1 行） | wlr-randr 可切 144/120/90/60…；`ApplyMonitorsConfig` 同路径生效 |
| 非整数比例显 100% | **phosh 0.55.0** | `GetCurrentState` 上报的 scale 来自 wl_fixed(1/256)×phoc(1/120) 量化值，与对外公布的 supported_scales（DPI 有理数）不相等；g-c-c 精确匹配失败→回退 100% | 上报前把 scale **吸附到最近的 supported scale**（误差 ≤0.01 才吸附） | 上报值 == supported 列表项（`supported matches reported: True`） |

**整数档（1.0/2.0/4.0）本来就落在 1/256 网格上 → 一直正常**，这解释了「只有整数比例能被记录」。

---

## 1. 复现与取证

设备：`uname -r = 7.2.0-debug-vk64-gd02658e63cf6`；`modetest -c` 暴露 **8 档** mode（165/144/120/90/60/40/30/24），
DRM 侧无限制 ⇒ 限制在合成器。

**问题 1**（修前）：
```
$ wlr-randr --output DSI-1 --mode 1904x3040@120.0   # rc=0 但无变化
$ wlr-randr | grep current
    1904x3040 px, 165.000000 Hz (preferred, current)
```
phoc 源码路径（`phoc_output_config_head_to_output_config`，修前）：
```c
if (head->state.mode && head->state.mode->preferred) {   // ← 非 preferred 落到 else
    ... head->state.mode ...
} else {
    ... head->state.custom_mode ...                     // ← 真 mode 时这里是 0x0@0
}
```
随后 `phoc_output_fill_state()`：`oc->mode.width==0` → `wlr_output_state_set_mode(preferred)`。
历史印证：`archive/topics/PANEL-REFRESH-2026-10-01.md` §0 早记「phoc 把 preferred 钉死，运行时 `wlr-randr` 切被忽略」，
当时绕法是把 165 Hz 移到 mode table 首位当 preferred（`patches/0008`）。

**问题 2**（修前）：
```
$ wlr-randr --output DSI-1 --scale 2.6667      # 有效
$ wlr-randr | grep Scale:  → 2.667969          # wl_fixed 1/256 量化
$ gdbus … GetCurrentState → logical scale 2.66796875
supported_scales = [1.0, 1.2307…, 1.4545…, 1.7778…, 2.0, 2.2857…, 2.6666667, 3.2, 4.0]  # 无 2.66796875
```
g-c-c `cc-display-config.c` 用 `G_APPROX_VALUE(current, supported, DBL_EPSILON)` 精确匹配；
`cc-display-settings.c` 无匹配项时下拉框回落到第 0 项 = 100%。

---

## 2. 修复内容

- `patches-userland/0001-phoc-honor-any-mode.patch`：`src/output.c` 一行。
- `patches-userland/0002-phosh-report-supported-scale.patch`：新增 `phosh_head_snap_to_supported_scale()`，
  在 `GetCurrentState` 构造 logical monitor 时使用。仅当与最近 supported scale 误差 ≤0.01 才吸附，
  真实应用的 scale 不变（phoc 仍按 1/120 取整到精确的 8/3，逻辑分辨率不糊）。
- 上游核对（2026-10-11）：phoc `main` 仍是旧写法；phosh `main` 未做吸附 ⇒ 两个都仍是上游未修 bug。

---

## 3. 实测结论（修后）

```
# 问题 1
wlr-randr --output DSI-1 --mode 1904x3040@90.0
  → 1904x3040 px, 90.000000 Hz (current)         ✅

# 问题 2（走 g-c-c 的真实 DBus 路径，method=2）
ApplyMonitorsConfig(scale=1.4545454978942871, mode=1904x3040@60)
  → after logical: (0, 0, 1.454545497894287)     ✅ 恰为 supported 项
  → current mode: 1904x3040@60 60.0              ✅
  → supported matches reported: True             ✅
```
（另：`scale=1.7777…`、`scale=2.0` 等亦逐一核对 `∈ supported_scales`。）

**关键坑（复现命令别踩）**：phosh 只在 `method == 2 (PERSISTENT)` 时真正应用配置；
`method=1 (TEMPORARY)` 只校验后直接返回 OK —— 用 DBus 模拟 g-c-c 必须传 2。

---

## 4. 产物与回退

- 设备新二进制：`/usr/bin/phoc`（2.16 MB，静态内嵌 wlroots）、`/usr/libexec/phosh`（2.7 MB）。
- 原始备份（持久根）：`/root/build/backup/phoc.0.55.1.orig`、`/root/build/backup/phosh.0.55.0.orig`。
- 源码/构建树保留在设备 `/root/build/`（**按用户指示：开发工具不删**）。
- 构建脚本：`patches-userland/build-phoc-phosh.sh`。

---

## 5. 设备侧编译依赖（已装，保留）

```
build-base meson ninja pkgconf patch
glib-dev gmobile-dev gnome-desktop-dev json-glib-dev libdrm-dev libinput-dev
libxkbcommon-dev mesa-dev pixman-dev wayland-dev wayland-protocols eudev-dev
glslang hwdata-dev libcap-dev libdisplay-info-dev libseat-dev libxcb-dev
xcb-util-image-dev xcb-util-renderutil-dev xcb-util-wm-dev xkeyboard-config-dev xwayland-dev
callaudiod-dev elogind-dev evince-dev evolution-data-server-dev feedbackd-dev gcr-dev
gettext-dev gnome-bluetooth-dev gtk+3.0-dev libadwaita-dev libgudev-dev libhandy1-dev
libsecret-dev linux-pam-dev modemmanager-dev networkmanager-dev polkit-elogind-dev
pulseaudio-dev qrcodegen-dev upower-dev
```

## 6. 备注

- 本修复是**用户态**改动，不进内核/DTB；重打 rootfs 会丢失（持久根目前无脚本化 rootfs 重建流程）。
  长期应把这些补丁纳入将来的 rootfs 构建，或向 phoc/phosh 上游提 MR。
- 涉及 `git` 边界：`patches-userland/` 是新增资产，应纳入版本管理。
