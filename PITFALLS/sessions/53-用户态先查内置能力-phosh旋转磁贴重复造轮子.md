# 53. 用户态改动前先查「发行版/上游是不是已经有了」——phosh 自动旋转磁贴重复造轮子

## #358：给 phosh 新增「自动旋转」快捷磁贴 = 重复实现，核心早已内置

**现象（2026-10-11 造的轮子，2026-10-19 用户裁定撤销）**：为 phosh 0.55.0 新增 in-tree 插件
`plugins/auto-rotation-quick-setting/`（`0003-phosh-auto-rotation-quick-setting.patch`），
读同一个 `org.gnome.settings-daemon.peripherals.touchscreen::orientation-lock` 提供「显式自动旋转开关」。
后被指出**原版已有**、功能重复。

**核实（2026-10-19，设备侧源码 `/root/build/phosh-0.55.0/src/quick-settings.c`）**：
phosh 0.55 的**核心**旋转快捷设置本就直接调用
`phosh_rotation_manager_get/set_orientation_locked()`——即「方向锁定/自动旋转」同一个开关，
不是插件、不需要额外实现。插件只是第二个入口。

**该记的纪律**：
- 写用户态代码前，先在**目标版本源码**里 `grep -i <功能关键词>` 一遍（`src/` 与 `plugins/` 都要），
   确认不是核心已实现、只是 UI 入口不同。发行版 override/默认键也要看（本机
   `/usr/share/glib-2.0/schemas/00_mobi.Phosh.gschema.override` 属 `:Phosh` profile，
   **只有 `GSETTINGS_PROFILE=Phosh` 才算生效**，直接 `gsettings get` 会看到上游默认值）。
- 插件清单键 `sm.puri.phosh.plugins quick-settings` 是**整体列表**：安装脚本若用
   `set "['<plugin>']"` 会覆盖用户/发行版原有的其它插件项，`reset` 才是干净回退。
- 撤销要**三处一起**：设备侧文件（`/usr/lib/phosh/plugins/*`）、dconf 键、仓库构建/安装脚本；
   只删二进制，下次 `install-on-device.sh` 会把重复插件装回来。

**产物**：`patches-userland/withdrawn/0003-...patch`（原文+撤销说明）、
`patches-userland/README.md`、`rootfs/persistent-overlay/userland-display/`（设备侧副本已同步）、
`reports/userland-auto-rotation-toggle-20261011.md`（历史记录，保留）。
