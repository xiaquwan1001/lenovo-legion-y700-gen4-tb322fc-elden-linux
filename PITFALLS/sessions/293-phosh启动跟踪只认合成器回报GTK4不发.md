# 293 — phosh 0.59~rc1 的「应用启动跟踪」只认合成器回报，GTK4 客户端一条都不发

## #657 「打开 app 一直加载到超时」= phosh 0.59 的 `app-tracker` 等不到启动完成信号（GTK 4.24 不发）

- **现象（2026-11-14 用户报）**：从抽屉打开 app，加载指示器一直挂到约 **10 s**；日志签名
  `phosh[…]: Startup of app '文件' with startup id: '<32 hex>' timed out`（`软件`/`设置`/`文件` 均复现）。
- **源码定位（`phosh_0.59~rc1.orig.tar.xz`，Debian pool）**：`src/app-tracker.c` —— 应用启动后
  phosh 只认两条完成信号 `PHOSH_APP_TRACKER_STATE_FLAG_WL_LAUNCH` / `WL_STARTUP_ID`，
  注释原文：*"This happens via the xdg-activation or the GTK specific gtk_shell1 protocol.
  The compositor then notifies phosh via the phosh-private wayland protocol."*
  `on_startup_timeout()` 的 PID / D-Bus 名 / flatpak 三条分支**只用来「再等一会儿」**，从不判完成。
- **设备实测（`WAYLAND_DEBUG=1`，GTK3 vs GTK4 最小窗口 + `DESKTOP_STARTUP_ID`）**：
  - GTK3：`-> xdg_activation_v1#14.activate("probeABC", wl_surface#32)` ✅ 会报；
  - **GTK4（4.24.1）：只 `bind` 了 `xdg_activation_v1`，从不 `activate`，也不发 `gtk_shell1.set_startup_id`** ❌
  ⇒ phosh 0.59 对 GTK4 应用必然空等到超时。
- **反面证据（重要）**：把 phosh/`phosh-common`/`libphosh-0.45-0` **降级到 0.58.0-1 后，用户观察到的现象没有变化**
  （0.58 的源码里 `src/app-tracker.c` 根本不存在，只有 tests stub）⇒ **「0.59 新增跟踪器」这条推断不足以解释用户见到的全部现象**，
  机制仍开放；降级也已回滚/待定，别照抄成结论。
- **判据口径**：确认一条要 `journalctl -b | grep "Startup of app"`；别用「app 起得慢」当证据（启动本身 < 1 s）。
- **附带（同轮查到的会话事实）**：桌面会话 `loginctl show-session` 恒为 **`Class=greeter`**（greetd 起），
  日志里 phosh 报 `Failed to send locked hint: … Session does not support lock screen`；
  给 greetd `[initial_session]/[default_session]` 加 `service = "greetd"` 之后 PAM 服务名变了
  （`pam_unix(greetd:session)`）但 **class 仍是 greeter** ⇒ 改 PAM service 不是改「会话类」的口子。
