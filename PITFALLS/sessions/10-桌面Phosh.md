## 十、桌面 / Phosh（2026-09-29）

48. **Phosh 锁屏默认要 PIN**：`sm.puri.phosh.lockscreen require-unlock` 默认 `true`；
    本镜像 `/etc/pam.d/` 几乎为空（只有 `polkit-1`），**任何 PIN/密码都不可能通过** → 卡死在锁屏。
    解法：schema override 把 `require-unlock=false`（滑一下直接解锁）。
    产物：`/usr/share/glib-2.0/schemas/99_elden.gschema.override`（改后 `glib-compile-schemas`）。
    ⚠️ 直接 `gsettings set` 会失败：`Cannot autolaunch D-Bus without X11 $DISPLAY`——
    ssh 里没有 session bus；要设就 `export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/<phosh-pid>/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')`，
    **或者**干脆用 override 文件（会话无关、可持久）。

49. **gdk-pixbuf 2.44 全走 glycin，glycin 的 bwrap 沙箱会让 loader `exit 1` → GTK 断言 → phosh abort**。
    glycin 自检（`sandbox.rs check_bwrap_syscalls_blocked`）遇到 bwrap 返回 SIGSYS / stderr 含
    `Creating new namespace failed` 时**自动切 NotSandboxed**；因此给 `bwrap` 装个打印该串并 `exit 1` 的 shim 即可
    （`scripts/glycin-bwrap-shim.sh`；`/init` 开机自动装）。
    ⚠️ **bwrap 完全不存在反而被判为可用**，删 bubblewrap 无效；glycin 无「关沙箱」环境变量。

50. **apk 说已装 ≠ 文件在**：`mesa-gl` 在包库里是 installed，但 `/usr/lib/libGL.so.1` 实际缺失
    → `gnome-session-check-accelerated` 的 gl-helper abort（`Couldn't open libGL.so.1`）
    → 加速检查失败 → **shell 根本不启动**。
    诊断要用 `ls`/`ldd`，别只信 `apk list -I`。修复：从 `pkgs-phosh/mesa-gl-*.apk` `tar -xzf -C /` 补回。

51. **gnome-session 必需组件失败 → fail whale**：`org.gnome.SettingsDaemon.Power` 在无 UPower/logind 时
    `exit 1`、`respawning too quickly` → `Unrecoverable failure in required component`。
    解法：从 `/usr/share/gnome-session/sessions/phosh.session` 的 `RequiredComponents` 里删掉 `org.gnome.SettingsDaemon.Power`
    （原文件备份 `phosh.session.orig`）。

52. **★ `pkill -f <模式>` 会匹配到自己的 ssh 命令行**：远程执行的 `sh -c '... pkill -f gnome-session-failed ...'`
    里本身含该字符串 → pkill 杀死自己的 shell（甚至整个会话，导致 phoc/phosh 一起退出）。
    用 **`pkill -x <精确进程名>`**，或把脚本写成文件再跑，绝不在 `-f` 模式里包含自己命令行的文本。

53. **Phosh 会话起来后要的东西**：`udevd`（libinput 认触屏，否则 phoc 报无设备）、`seatd`（libseat 拿 DRM/输入 seat）、
    `XDG_RUNTIME_DIR` 指向专用目录。启动脚本见 `scripts/start-desktop.sh`。

54. **截图取证**：Phosh 内置截图可直接 D-Bus 调用（无需 grim/phosh-screenshot）：
    `DBUS_SESSION_BUS_ADDRESS=... gdbus call --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot --method org.gnome.Shell.Screenshot.Screenshot false false /tmp/x.png`。
    比看 DRM plane 更直观。

---

