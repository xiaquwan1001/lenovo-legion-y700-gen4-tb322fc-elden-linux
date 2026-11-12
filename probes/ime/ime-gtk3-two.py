#!/usr/bin/env python3
"""双窗口 GTK3 探针：窗口 A 有 Entry（要打字），窗口 B 只有 Button（无输入控件）。

用途（G1-38 边角判据，见 reports/ime-osk-lifecycle-20261112.md §5 T-H1/T-H3）：
  * T-H1 Alt+Tab：A 的 Entry 获焦（OSK 弹）→ Alt+Tab 切到 B（无输入控件）⇒ 期望 OSK 收起；
        现栈（只认 Controller1.State==0）预期漏收 ⇒ Visible 仍 true。
  * T-H3 同窗换焦点：A 内 Tab 到 Button ⇒ 期望 ≤ idle 超时内收起。

窗口行为由 argv[1] 选择，方便脚本单步驱动：
  two      两个窗口都显示，A 的 Entry 自动获焦（默认）
  a-only   只显示窗口 A
  b-only   只显示窗口 B
运行到 stdin 收到 EOF 或 argv[2] 秒（默认 60）超时。

设备上以 GUI 用户身份运行：
  env XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus \
      WAYLAND_DISPLAY=wayland-0 GTK_IM_MODULE=fcitx \
      setpriv --reuid=1001 --regid=1001 --init-groups \
      python3 /tmp/ime-gtk3-two.py two 60
"""
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk

mode = sys.argv[1] if len(sys.argv) > 1 else "two"
life = int(sys.argv[2]) if len(sys.argv) > 2 else 60

# 窗口 A：有输入控件
win_a = Gtk.Window(title="ime-A-entry")
box_a = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
entry = Gtk.Entry()
entry.set_placeholder_text("A: entry (should raise OSK)")
btn_a = Gtk.Button(label="A: button (no input)")
box_a.pack_start(entry, False, False, 0)
box_a.pack_start(btn_a, False, False, 0)
win_a.add(box_a)

# 窗口 B：无输入控件
win_b = Gtk.Window(title="ime-B-noinput")
btn_b = Gtk.Button(label="B: only a button")
win_b.add(btn_b)

if mode in ("two", "a-only"):
    win_a.show_all()
if mode in ("two", "b-only"):
    win_b.show_all()

# 1.5 s 后让 A 的 Entry 拿焦点（等合成器 map 完）
if mode != "b-only":
    GLib.timeout_add(1500, lambda: (win_a.present(), entry.grab_focus(), False)[2])

GLib.timeout_add(life * 1000, lambda: (Gtk.main_quit(), False)[1])
Gtk.main()
