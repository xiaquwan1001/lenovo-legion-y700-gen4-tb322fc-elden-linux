#!/usr/bin/env python3
"""最小 GTK3 Entry 测试窗：拿到焦点，6–9 s 后自动关闭。

用于 IME/OSK 判据：
  * `GTK_IM_MODULE=fcitx`  ⇒ 客户端不发 `zwp_text_input_v3.enable`（OSK 只能靠 focusd 桥弹）；
  * `GTK_IM_MODULE=wayland` 或 `env -u GTK_IM_MODULE` ⇒ 走 text-input-v3，phoc 转发 activate。

配合 `WAYLAND_DEBUG=1` 抓包，判据计数见 `reports/ime-osk-firefox-rootcause-20261112.md` §2。
在设备上以 GUI 用户身份运行：

    env XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus \
      WAYLAND_DISPLAY=wayland-0 GTK_IM_MODULE=fcitx \
      setpriv --reuid=1001 --regid=1001 --init-groups \
      WAYLAND_DEBUG=1 python3 ime-gtk3-entry.py
"""
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk

win = Gtk.Window(title="ime-gtk3-entry")
entry = Gtk.Entry()
win.add(entry)
win.show_all()

# 1.5 s 后抢焦点（等合成器完成 mapping），9 s 后退出
GLib.timeout_add(1500, lambda: (entry.grab_focus(), False)[1])
GLib.timeout_add(9000, lambda: (Gtk.main_quit(), False)[1])

Gtk.main()
