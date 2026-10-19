# user-autostart — 用户级自启项（`~/.config/autostart/`）

还原（设备上以 `xuqianhui1001` 身份）：

```sh
install -d -o xuqianhui1001 -g xuqianhui1001 ~xuqianhui1001/.config/autostart
install -o xuqianhui1001 -g xuqianhui1001 -m644 squeekboard.desktop \
        ~xuqianhui1001/.config/autostart/squeekboard.desktop
```

## 为什么必须有 squeekboard

**不是"想要软键盘"，而是 seat 必须有键盘设备**（`PITFALLS` §50 / #343）：

- 本机无物理键盘 ⇒ phoc 的 seat 只有 libinput 的 touch/pointer ⇒ `wl_seat.capabilities = 4`（只有 TOUCH）
- ⇒ 客户端收不到 `wl_keyboard.enter`
- ⇒ **GTK4 `GtkWindow::is-active` 恒为 false**
- ⇒ 依赖 `is-active` 启动的重活全部不执行。已实测受害：**GNOME Snapshot 50 的相机永不启动**（一直转圈）

squeekboard 走 `zwp_input_method_v2`，phoc 会给它注册一个**非 libinput 的虚拟键盘**，
而 `seat_has_keyboard()` 对非 libinput 键盘直接返回 TRUE ⇒ caps 变 7。

**判据**（改了这里要复核）：

```sh
WAYLAND_DEBUG=1 <任意 GTK4 程序> 2>&1 | grep -oE "wl_seat#[0-9]+\.capabilities\([0-9]+\)"
# 必须看到 (7)；(4) 就是坏的
```

⚠️ 历史上 `sm.puri.OSK0.desktop` 已在 `/etc/xdg/autostart/`，但**它会与 fcitx5 抢同一个
input-method set 的唯一 slot**（`phoc-input-method-relay` 日志 "Attempted to connect second
input method to a seat"），且 `PITFALLS` §48 #337 记录过 phoc 0.55.1 在这条路径上有 NULL 解引用崩溃。
所以这里**不**依赖那条 autostart，而是单独放一份**显式**的 autostart 项，便于独立开关与排障。
