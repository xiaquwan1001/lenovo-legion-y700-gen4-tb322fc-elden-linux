## 七、Wayland / 桌面（weston）

35. **weston 14 的 drm-backend 不再接受 `--tty=1`**（VT 改由 libseat 管理）：
    报 `fatal: unhandled option: --tty=1`，**即使 DRM/输出/EGL 都已经初始化成功**——很迷惑。
    正确命令：`weston --backend=drm --idle-time=0`（配 `seatd -g root`）。
    （别信旧笔记里的 `--tty=1`，那是旧 weston 语法；`§17.1` 已改正。）

36. **`weston-screenshooter` 在无输入/无 shell 授权时返回 `Output capture error: unauthorized`**：
    weston 的 `weston_capture_v1` 需要 shell 授权，headless 下截图不通。
    要确认桌面是否真在显示，用 DRM debugfs（**权威**）：
    `cat /sys/kernel/debug/dri/0/state` → 看 `plane-0` 的 `allocated by = weston`、`crtc=crtc-0`、`format=XR24`、`size=1904x3040`。

37. **weston-terminal 需要真实字体**：只装 `fontconfig` 不够，必须装字体（`apk add font-dejavu`），
    否则 pango 无字形、终端一片空白。

38. **桌面自启**：磁盘 root 模式下（`on_initramfs=0`）`/init` 调用 `/usr/local/sbin/start-desktop.sh`
    取代 tty1 getty；RAM 模式仍保留 getty。
    **当前脚本拉起 Phosh**（`udevd` + `seatd` + `phosh-session` 循环；见 §十）。
    历史：早期是 weston（`/etc/xdg/weston/weston.ini`，`[core] require-input=false` 必须加，
    `--tty=1` 在 weston 14 已失效；旧脚本备份 `start-desktop.sh.weston.bak`）。

---

