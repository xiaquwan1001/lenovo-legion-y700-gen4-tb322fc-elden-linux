# patches-userland — 用户态（Phosh/phoc）补丁

> 这里放**已上机验证**的用户态补丁（内核补丁仍在 `patches/`）。
> 产物 = 设备上重编的 `/usr/bin/phoc` 与 `/usr/libexec/phosh`（Alpine 3.24 stable，aarch64）。
> 证据/根因记录见 `reports/userland-display-scale-refresh-20261011.md`、`PITFALLS.md` #77 / #182。

## 补丁清单

| 补丁 | 组件 | 版本 | 作用 |
|---|---|---|---|
| `0001-phoc-honor-any-mode.patch` | phoc | 0.55.1 | 运行时可切到**非 preferred** 刷新率（原来只认 preferred，切档被忽略，屏恒 165 Hz） |
| `0002-phosh-report-supported-scale.patch` | phosh | 0.55.0 | `GetCurrentState` 上报的 scale 吸附回 supported 列表，修复 g-c-c 非整数比例恒显 100% |
| `0003-phosh-auto-rotation-quick-setting.patch` | phosh | 0.55.0 | ~~新增「自动旋转」快速设置磁贴插件~~ **已撤销（2026-10-19）**：phosh 内置旋转磁贴已能开关自动旋转，属重复实现；原文移至 `withdrawn/` |
| `alpine-phosh-{use-after-free-fix,extend-timeout-with-pid}.patch` | phosh | 0.55.0-r2 | Alpine aports 的两个 phosh 补丁（保持与发行版包一致）；构建脚本会应用 |

0001/0002 是**行为修正**（不改协议/ABI）；0003 已撤销（重复实现，见 `withdrawn/README.md`）。

### 0001 根因（phoc）
`src/output.c: phoc_output_config_head_to_output_config()` 把 `zwlr_output_configuration_head_v1`
的 `state.mode` 转成内部 `PhocOutputConfig` 时判了 `head->state.mode->preferred`：
非 preferred 的 mode 走 else 分支读 **空的 `custom_mode`**（0x0@0），
随后 `phoc_output_fill_state()` 因 `oc->mode.width == 0` 回退 `preferred_mode` ⇒ 任何非 165 Hz 档被丢弃。
改成 `if (head->state.mode)` 即正确区分「真 mode」与「custom mode」。上游 main 仍是旧写法（2026-10-11 核对）。

### 0002 根因（phosh）
`GetCurrentState` 的 logical monitor scale 直接取 `head->scale`，而该值来自 wlroots
output-management 的 **24.8 定点**（`wl_fixed`）并叠加 phoc 的 1/120 取整；
phosh 通过 `phosh_util_calculate_supported_mode_scales()` 对外公布的 supported scales 却是
DPI 推导的有理数（如 8/3 → 2.6666667461395264）。二者不相等，而 gnome-control-center
用 `G_APPROX_VALUE(..., DBL_EPSILON)` **精确匹配**，匹配失败即回退显示 100%（整数档在网格上，故正常）。
补丁在 `GetCurrentState` 里把上报 scale **吸附到最近的 supported scale**（仅当误差 ≤0.01，即量化误差内），
不改变真实应用的 scale（phoc 侧仍是精确的 8/3，逻辑分辨率不糊）。

### 0003 自动旋转磁贴（phosh）— 已撤销 2026-10-19
~~新增 in-tree 插件 `plugins/auto-rotation-quick-setting/`~~（照 `dark-mode-quick-setting` 模板），
读写与内置旋转磁贴同一个持久 key `org.gnome.settings-daemon.peripherals.touchscreen::orientation-lock`。
**撤销原因**：phosh 0.55 核心的旋转快捷设置（`src/quick-settings.c`）本来就是同一个开关
（`phosh_rotation_manager_set_orientation_locked()`），额外插件只是第二个入口 ⇒ 重复。
设备侧已删除 `/usr/lib/phosh/plugins/*auto-rotation-quick-setting*` 并 `gsettings reset sm.puri.phosh.plugins quick-settings`。
原文/历史证据：`withdrawn/0003-phosh-auto-rotation-quick-setting.patch`、`reports/userland-auto-rotation-toggle-20261011.md`。

> 通用插件机制（下次再加插件时有用）：插件必须在 `plugins/meson.build` 的 `quick_setting_plugins` 列表里；
> 产物 = `/usr/lib/phosh/plugins/libphosh-plugin-<name>.so` + `<name>.plugin`；用 `gsettings`（`sm.puri.phosh.plugins`）启用；
> 插件**不链 libphosh**，符号由 phosh 可执行文件经 `--dynamic-list` 导出（所以未导出的 API，如 `phosh_shell_get_rotation_manager`，插件用不了）。

## 构建（设备上，aarch64 原生）

依赖（编译期，任务汇报后**保留不删**）见 `reports/userland-display-scale-refresh-20261011.md` §5。
一键脚本：`build-phoc-phosh.sh`（需设备已 `apk add` 上述依赖）。

```sh
# 源码（官方 release tarball，phoc 自带 wlroots 子项目）
#   https://sources.phosh.mobi/releases/phoc/phoc-0.55.1.tar.xz     (sha512 见 Alpine aports)
#   https://sources.phosh.mobi/releases/phosh/phosh-0.55.0.tar.xz   (sha512 42bddb9a…)
sh patches-userland/build-phoc-phosh.sh <src-dir>
```

关键选项：
- phoc：`--default-library=static --buildtype=release -Dembed-wlroots=enabled -Dman=false -Dtests=false`
  （必须 static，否则 phoc 动态依赖构建目录里的 `libwlroots-0.20.so`）。
- phosh：`--buildtype=release -Dphoc_tests=disabled -Dman=false -Dtests=false -Dbindings-lib=false`
  （只替换 `/usr/libexec/phosh`；它静态链 libphosh）。

## 部署 / 回退

```sh
# 置换成新二进制（先停会话，否则 Text file busy）
rc-service greetd stop
cp <build>/phoc  /usr/bin/phoc
cp <build>/phosh /usr/libexec/phosh
rc-service greetd start

# 插件（自动旋转磁贴）——已撤销，见 withdrawn/README.md；不要再安装

# 回退（设备上原始二进制已备份）
cp /root/build/backup/phoc.0.55.1.orig  /usr/bin/phoc
cp /root/build/backup/phosh.0.55.0.orig /usr/libexec/phosh
```

## 验证

```sh
# ① 运行时可切刷新率（问题 1）
su -s /bin/sh xuqianhui1001 -c "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
  wlr-randr --output DSI-1 --mode 1904x3040@120.0"
# -> Modes 列表里该档变成 (current)

# ② 非整数比例上报值 ∈ supported_scales（问题 2）
su -s /bin/sh xuqianhui1001 -c "… python3 /tmp/dc-apply.py <scale> 1904x3040@<hz>"
# -> "supported matches reported: True"
#    （g-c-c 的 ApplyMonitorsConfig 必须用 method=2/persistent 才会真正应用，method=1 只校验）
```

> ⚠️ phosh 只对 `method == PHOSH_MONITOR_MANAGER_CONFIG_METHOD_PERSISTENT (2)` 真正应用配置；
> method=1（temporary）只做校验后直接返回 OK。用 DBus 复现 g-c-c 行为时必须传 2。
