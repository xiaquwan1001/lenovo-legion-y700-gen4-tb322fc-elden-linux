# 用户态新增：自动旋转开/关快速设置磁贴（2026-10-11）

> 目标：给 Phosh 一个**明确标注「自动旋转」**的开关控件（不用记住「长按旋转磁贴」那套隐藏交互）。
> 做法 = 与之前同样的「改源码 → 设备重编 → 装机」，**只加一个 in-tree quick-setting 插件，不动核心**。
> 补丁 `patches-userland/0003-phosh-auto-rotation-quick-setting.patch`；构建/安装脚本已接入 `userland-display/`。

## 1. Phosh 0.55 的旋转模型（先厘清，避免做出重复控件）

- `PhoshRotationManager`（`src/rotation-manager.c`）：
  - `mode`（**不持久**）：`OFF`（不跟随传感器）/ `SENSOR`（跟随）。开机时若有加速度计就设 `SENSOR`。
  - `orientation-locked`（**持久**，绑 gsettings `org.gnome.settings-daemon.peripherals.touchscreen orientation-lock`）：
    锁定当前方向、不跟传感器。
- 内置**旋转磁贴**（`PhoshRotateInfo`）：短按 = 锁/解锁（= 自动旋转关/开），长按 = 切 `mode`。
  即「自动旋转开关」**本来就有**，只是入口隐藏、语义（旋转/锁定）不直观。

## 2. 设计（选项 A：新增插件，绑同一个持久 key）

- 新增插件 `auto-rotation-quick-setting`（`plugins/auto-rotation-quick-setting/`），照 `dark-mode-quick-setting` 模板。
- 读写与内置磁贴**同一个** gsettings key（`orientation-lock`）：
  - `active` = `!orientation_lock`（自动旋转开）；
  - 图标 `rotation-allowed-symbolic` / `rotation-locked-symbolic`（Adwaita `symbolic/status/`，设备已装）；
  - 文案 `Auto-rotation on/off`；
  - 点击 = 翻转该 key（持久）。
- **不改核心**：不新增 gsettings key、不用导出的 libphosh 符号（插件只用 `PhoshQuickSetting` 基类 + GSettings）。
- 启用：`gsettings set sm.puri.phosh.plugins quick-settings` 里加上插件名（安装脚本自动做，`append` 保留原有）。

## 3. 改动清单（补丁内含）

| 文件 | 作用 |
|---|---|
| `plugins/auto-rotation-quick-setting/{auto-rotation-quick-setting.c,.h}` | 插件控件：读 `orientation-lock`、点击翻转、`changed::` 同步 |
| `plugins/auto-rotation-quick-setting/phosh-plugin-auto-rotation-quick-setting.c` | GIO 扩展点注册（quick-setting-widget） |
| `.../qs.ui` + `.gresources.xml` | 模板 + 资源 |
| `.../auto-rotation-quick-setting.desktop.in.in` | `.plugin` 描述（`Name=Auto-rotation Quick Setting`） |
| `.../meson.build` | shared_module 目标 |
| `plugins/meson.build` | 把插件加进 `quick_setting_plugins` |

## 4. 构建 / 安装（已接入既有流水线）

- `patches-userland/build-phoc-phosh.sh`：phosh 段补上 **Alpine 两个补丁**（此前漏了：`use-after-free-fix`、`extend-timeout-with-pid`，现以 `alpine-*.patch` 形式随仓库走）+ `0002` + `0003`；构建后**断言**插件 `.so`/`.plugin` 存在。
- `patches-userland/install-on-device.sh`：除 phoc/phosh 二进制外，安装
  `/usr/lib/phosh/plugins/{libphosh-plugin-auto-rotation-quick-setting.so, auto-rotation-quick-setting.plugin}`，
  并用 `dbus-run-session`（不需真会话在跑）把插件名写进 `sm.puri.phosh.plugins::quick-settings`；marker 升到 `display2`。
- `rootfs/persistent-overlay/userland-display/` 同步了这些脚本 + 补丁（设备侧副本）。

## 5. 实测（2026-10-11，U2）

- 构建：插件编译通过（`libphosh-plugin-auto-rotation-quick-setting.so` 73,712 B）。
- 安装：`.so` + `.plugin` 落到 `/usr/lib/phosh/plugins/`；marker `…+display2`。
- 启用：`gsettings get sm.puri.phosh.plugins quick-settings` → `['auto-rotation-quick-setting']`；
  **`/proc/<phosh>/maps` 含 `auto-rotation-quick-setting.so`** ⇒ phosh 已加载该插件；
  dconf 落盘 `/home/xuqianhui1001/.config/dconf/user`；phosh 稳定（无 segfault / 无 dmesg 报错）。
- **待做（视觉确认）**：本 boot 是 Q28 坏样本（面板 init 失败、无画面），无法目视磁贴；等好 boot 再截图确认磁贴图标/点击行为。

## 6. 备注 / 上游

- 与内置旋转磁贴**功能重叠**（用户已知并选择 A）：一个短按锁定、一个新磁贴显式开关，两者读写同一 key，状态一致。
- 若日后要「真正禁掉传感器跟随且开机保持」（`mode` 持久化），需再加一个 `mobi.phosh.shell` 的 gsettings key 并改 `rotation-manager.c`。
- 该插件也是个**可上游**的小特性（Phosh 无独立「自动旋转」磁贴）；但上游提交仍受 `gitlab.gnome.org` IP 注册拦截阻塞（见 `patches-userland/upstream/README.md`）。
