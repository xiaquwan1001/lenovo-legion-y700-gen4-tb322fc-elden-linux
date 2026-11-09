#!/usr/bin/env python3
"""fcitx5-indicator — 顶栏输入法状态指示（Phosh 没有 SNI 托盘，所以自绘一个 layer-shell 小组件）

为什么需要它（2026-11-09）：Phosh/phoc 不实现 StatusNotifierItem，fcitx5 的托盘图标永远不显示
（`kimpanel` 只能等一个 SNI 宿主）；`classicui` 在 Wayland 下只有 0.59 的 phosh 才可能给出面板，
实测「Created classicui for wayland display:」之后屏上没有任何东西。⇒ 用 GTK4 + layer-shell
自己画一个贴顶栏右下的小胶囊，显示 中/英，点一下 = `fcitx5-remote -t`。

判据（自己就能查）：
  * 进程在：`pgrep -af fcitx5-indicator`
  * layer surface 已建：进程不退出且 `journalctl --user -u fcitx5-indicator` 无 "layer shell" 报错
  * 点击生效：`~/.local/state/fcitx5-ime-toggle.log` 多一行 after=2/1

依赖：`python3-gi gir1.2-gtk-4.0 libgtk4-layer-shell0 gir1.2-gtk4layershell-1.0`
"""
import os
import subprocess
import sys

import gi

gi.require_version("Gtk", "4.0")

try:
    gi.require_version("Gtk4LayerShell", "1.0")
    from gi.repository import Gtk4LayerShell as LayerShell
    HAVE_LAYER = True
except (ValueError, ImportError):  # 没有 layer-shell 就退化成普通窗口（不会挡屏，但也不贴边）
    HAVE_LAYER = False

from gi.repository import GLib, Gtk

ENV = dict(os.environ)
ENV.setdefault("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
ENV.setdefault("DBUS_SESSION_BUS_ADDRESS", f"unix:path={ENV['XDG_RUNTIME_DIR']}/bus")

LOG = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
                   "fcitx5-indicator.log")


def log(msg: str) -> None:
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(msg + "\n")
    except OSError:
        pass


def remote(*args: str) -> str:
    try:
        out = subprocess.run(["fcitx5-remote", *args], capture_output=True, text=True,
                             timeout=2, env=ENV)
        return (out.stdout or "").strip()
    except (OSError, subprocess.SubprocessError):
        return ""


class Indicator(Gtk.Window):
    def __init__(self) -> None:
        super().__init__()
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_can_focus(False)

        self.label = Gtk.Label()
        self.label.set_margin_top(2)
        self.label.set_margin_bottom(2)
        self.label.set_margin_start(10)
        self.label.set_margin_end(10)
        self.set_child(self.label)

        css = Gtk.CssProvider()
        css.load_from_data(b"""
        window { background: alpha(#1b1b1f, 0.72); border-radius: 11px; }
        label  { font-size: 13px; font-weight: 600; color: #f5f5f7; }
        """)
        Gtk.StyleContext.add_provider_for_display(self.get_display(), css,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        click = Gtk.GestureClick()
        click.connect("released", self.on_click)
        self.add_controller(click)

        if HAVE_LAYER:
            LayerShell.init_for_window(self)
            LayerShell.set_namespace(self, "fcitx5-indicator")
            LayerShell.set_layer(self, LayerShell.Layer.TOP)
            # 贴在顶栏下方右端：不占独享区（exclusive zone = 0）⇒ 不会把 Phosh 顶栏挤走
            LayerShell.set_anchor(self, LayerShell.Edge.TOP, True)
            LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
            LayerShell.set_margin(self, LayerShell.Edge.TOP, self._top_bar_height())
            LayerShell.set_margin(self, LayerShell.Edge.RIGHT, 8)
            LayerShell.set_exclusive_zone(self, 0)
            LayerShell.set_keyboard_mode(self, LayerShell.KeyboardMode.NONE)
        else:
            log("warn: no Gtk4LayerShell -> plain window")

        self.refresh()
        GLib.timeout_add_seconds(1, self.refresh)

    @staticmethod
    def _top_bar_height() -> int:
        # Phosh 顶栏高度随缩放/字号变（0.4x：~32px@1x）；经验值 + 余量，避免压住快速设置按钮
        try:
            from gi.repository import Gdk  # noqa: F401
        except Exception:
            pass
        return 42

    def refresh(self) -> bool:
        state = remote()
        name = remote("-n")
        # state: 2=active(中文) / 1=inactive(英文) / 0=closed（fcitx5 不接管按键，等价英文）
        if state == "2":
            text = "中" if name != "rime" else "中·rime"
        elif state in ("1", "0", ""):
            text = "EN"
        if self.label.get_text() != text:
            self.label.set_text(text)
        return True

    def on_click(self, *_args) -> None:
        remote("-t")
        GLib.timeout_add(300, lambda: (self.refresh(), False)[1])


def main() -> int:
    win = Indicator()
    win.present()
    log("indicator shown (layer=%s)" % HAVE_LAYER)
    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
